`timescale 1ns/1ps
`default_nettype none

//=====================================================================
// mfa_lock_phase2_tb.v
//
// Phase-2 system-level verification for the CURRENT MFA_LOCK RTL.
//
// This testbench intentionally does NOT modify the DUT RTL.
// It verifies the combinations that the current top-level wiring can
// actually exercise, and explicitly exposes architectural limitations.
//
// Tests:
//   P2-01  NFC + OTP, correct OTP             -> expected PASS
//   P2-02  NFC + OTP, wrong OTP               -> expected DENY
//   P2-03  NFC + BIO, matching status         -> expected PASS
//   P2-04  NFC + BIO, wrong status             -> expected DENY
//   P2-05  NFC + BIO, wrong template + match  -> expected DENY
//                                             -> CURRENT RTL FAIL
//   P2-06  PIN-first authentication           -> expected PASS
//                                             -> CURRENT RTL LIMITATION
//   P2-07  OTP-first authentication           -> expected PASS
//                                             -> CURRENT RTL LIMITATION
//   P2-08  invalid factor configuration       -> expected DENY
//   P2-09  duplicate NFC factor               -> must NOT unlock
//
// IMPORTANT:
//   The current otp_check.v is a seed/time-slot XOR checker, not the
//   RFC-4226 HOTP module. Therefore this TB uses the actual current
//   otp_check.v behavior: OTP = seed[7:0] ^ seed[15:8] ^ time_slot.
//   With seed AB-CD immediately after reset, time_slot = 0, so OTP=66.
//=====================================================================

module mfa_lock_phase2_tb;

    parameter CLK_FREQ_HZ  = 1_152_000;
    parameter BAUD_RATE    = 115200;
    parameter LOCKOUT_SECS = 1;
    parameter MAX_ATTEMPTS = 5;

    reg clk;
    reg rst_n;
    reg [3:0] keypad_col;
    wire [3:0] keypad_row;

    reg nfc_uart_rx_in;
    reg bio_uart_rx_in;
    reg otp_uart_rx_in;

    wire uart_tx_out;
    wire [1:0] led_green, led_red;
    wire buzzer, solenoid;
    wire [3:0] fsm_state;
    wire [3:0] factor_status;

    integer errors;
    reg [31:0] captured_pin_hash;

    localparam [3:0] S_READY   = 4'd1;
    localparam [3:0] S_GRANT   = 4'd6;
    localparam [3:0] S_DENY    = 4'd8;
    localparam [3:0] S_LOCKOUT = 4'd10;

    mfa_lock_top #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE(BAUD_RATE),
        .LOCKOUT_SECONDS(LOCKOUT_SECS),
        .MAX_ATTEMPTS(MAX_ATTEMPTS)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .keypad_col(keypad_col),
        .keypad_row(keypad_row),
        .nfc_uart_rx_in(nfc_uart_rx_in),
        .bio_uart_rx_in(bio_uart_rx_in),
        .otp_uart_rx_in(otp_uart_rx_in),
        .uart_tx_out(uart_tx_out),
        .led_green(led_green),
        .led_red(led_red),
        .buzzer(buzzer),
        .solenoid(solenoid),
        .fsm_state(fsm_state),
        .factor_status(factor_status)
    );

    // 1.152 MHz / 115200 = exactly 10 clocks/bit.
    always #(500_000_000 / CLK_FREQ_HZ) clk = ~clk;

    localparam integer BIT_NS = 1_000_000_000 / BAUD_RATE;

    //=============================================================
    // Common helpers
    //=============================================================

    task check;
        input cond;
        input [255:0] msg;
        begin
            if (cond)
                $display("  PASS: %s", msg);
            else begin
                $display("  FAIL: %s (time=%0t)", msg, $time);
                errors = errors + 1;
            end
        end
    endtask

    task uart_send_byte;
        input [7:0] data;
        input integer which; // 0=NFC, 1=BIO, 2=OTP
        integer i;
        begin
            case (which)
                0: nfc_uart_rx_in = 1'b0;
                1: bio_uart_rx_in = 1'b0;
                2: otp_uart_rx_in = 1'b0;
            endcase
            #(BIT_NS);

            for (i = 0; i < 8; i = i + 1) begin
                case (which)
                    0: nfc_uart_rx_in = data[i];
                    1: bio_uart_rx_in = data[i];
                    2: otp_uart_rx_in = data[i];
                endcase
                #(BIT_NS);
            end

            case (which)
                0: nfc_uart_rx_in = 1'b1;
                1: bio_uart_rx_in = 1'b1;
                2: otp_uart_rx_in = 1'b1;
            endcase
            #(BIT_NS);
        end
    endtask

    task send_nfc;
        begin
            uart_send_byte(8'hDE, 0);
            uart_send_byte(8'hAD, 0);
            uart_send_byte(8'hBE, 0);
            uart_send_byte(8'hEF, 0);
        end
    endtask

    task send_bio_match;
        input [7:0] template_id;
        begin
            uart_send_byte(8'h01, 1); // status bit0 = match
            uart_send_byte(template_id, 1);
        end
    endtask

    task send_bio_no_match;
        input [7:0] template_id;
        begin
            uart_send_byte(8'h00, 1); // status bit0 = no match
            uart_send_byte(template_id, 1);
        end
    endtask

    task send_otp;
        input [7:0] otp_value;
        begin
            uart_send_byte(otp_value, 2);
        end
    endtask

    // Direct keypad injection is deliberate. The keypad scanner has its
    // own unit test; this TB isolates authentication-system behavior.
    task keypad_press;
        input [3:0] key_code_val;
        begin
            @(posedge clk);
            force dut.key_code  = key_code_val;
            force dut.key_valid = 1'b1;
            @(posedge clk);
            release dut.key_valid;
            @(posedge clk);
            release dut.key_code;
            repeat (4) @(posedge clk);
        end
    endtask

    task enter_pin_1234;
        begin
            keypad_press(4'd1);
            keypad_press(4'd2);
            keypad_press(4'd3);
            keypad_press(4'd4);
            keypad_press(4'd14); // #
        end
    endtask

    task capture_pin_hash;
        begin
            @(posedge clk);
            force dut.pin_hash_inst.pin_input = 32'h00001234;
            force dut.pin_hash_inst.pin_len   = 8'd4;
            force dut.pin_hash_inst.start     = 1'b1;
            @(posedge clk);
            release dut.pin_hash_inst.start;
            wait (dut.pin_hash_valid == 1'b1);
            captured_pin_hash = dut.pin_hash_out;
            @(posedge clk);
            release dut.pin_hash_inst.pin_input;
            release dut.pin_hash_inst.pin_len;
        end
    endtask

    task preload_user;
        input [3:0] factor_req;
        input [15:0] otp_seed;
        input [7:0] bio_id;
        begin
            dut.user_db_inst.valid_mem[0]        = 1'b1;
            dut.user_db_inst.is_admin_mem[0]     = 1'b0;
            dut.user_db_inst.factor_req_mem[0]   = factor_req;
            dut.user_db_inst.nfc_uid_mem[0]       = 32'hDEADBEEF;
            dut.user_db_inst.pin_hash_mem[0]      = captured_pin_hash;
            dut.user_db_inst.otp_seed_mem[0]      = otp_seed;
            dut.user_db_inst.bio_id_mem[0]        = bio_id;
        end
    endtask

    task reset_and_preload;
        input [3:0] factor_req;
        input [15:0] otp_seed;
        input [7:0] bio_id;
        begin
            rst_n = 1'b0;
            repeat (4) @(posedge clk);
            rst_n = 1'b1;
            repeat (4) @(posedge clk);
            preload_user(factor_req, otp_seed, bio_id);
            repeat (3) @(posedge clk);
        end
    endtask

    // Wait for the second factor to be recorded.
    task wait_for_factor;
        input [3:0] expected_status;
        begin
            wait (factor_status == expected_status);
        end
    endtask

    task wait_ready;
        begin
            wait (fsm_state == S_READY);
            repeat (5) @(posedge clk);
        end
    endtask

    //=============================================================
    // TEST 1: NFC + OTP, correct OTP
    //=============================================================
    task test_nfc_otp_pass;
        begin
            $display("\n-- P2-01: NFC + OTP, correct OTP --");
            reset_and_preload(4'b0101, 16'hABCD, 8'h05);

            send_nfc;
            wait_for_factor(4'b0001);

            // AB ^ CD = 66, time_slot=0 immediately after reset.
            send_otp(8'h66);

            wait (fsm_state == S_GRANT);
            check(solenoid == 1'b1, "NFC+OTP unlocks with correct OTP");
            check(factor_status == 4'b0101, "factor status records NFC+OTP");

            wait_ready;
        end
    endtask

    //=============================================================
    // TEST 2: NFC + OTP, wrong OTP
    //=============================================================
    task test_nfc_otp_fail;
        begin
            $display("\n-- P2-02: NFC + OTP, wrong OTP --");
            reset_and_preload(4'b0101, 16'hABCD, 8'h05);

            send_nfc;
            wait_for_factor(4'b0001);
            send_otp(8'h00);

            wait (dut.attempt_count == 4'd1);
            check(solenoid == 1'b0, "wrong OTP does not unlock");
            check(dut.attempt_count == 4'd1, "wrong OTP increments attempt counter");
            wait_ready;
        end
    endtask

    //=============================================================
    // TEST 3: NFC + BIO, matching status and correct template
    //=============================================================
    task test_nfc_bio_pass;
        begin
            $display("\n-- P2-03: NFC + BIO, matching status --");
            reset_and_preload(4'b1001, 16'h0000, 8'h05);

            send_nfc;
            wait_for_factor(4'b0001);
            send_bio_match(8'h05);

            wait (fsm_state == S_GRANT);
            check(solenoid == 1'b1, "NFC+BIO unlocks with biometric match");
            check(factor_status == 4'b1001, "factor status records NFC+BIO");
            wait_ready;
        end
    endtask

    //=============================================================
    // TEST 4: NFC + BIO, status says no match
    //=============================================================
    task test_nfc_bio_fail;
        begin
            $display("\n-- P2-04: NFC + BIO, no biometric match --");
            reset_and_preload(4'b1001, 16'h0000, 8'h05);

            send_nfc;
            wait_for_factor(4'b0001);
            send_bio_no_match(8'h05);

            wait (dut.attempt_count == 4'd1);
            check(solenoid == 1'b0, "biometric no-match does not unlock");
            check(dut.attempt_count == 4'd1, "biometric no-match increments attempts");
            wait_ready;
        end
    endtask

    //=============================================================
    // TEST 5: NFC + BIO, WRONG TEMPLATE but MATCH status
    //
    // Intended security behavior: DENY.
    // Current biometric_interface/top-level only forwards bio_pass;
    // it does not compare bio_template_id against user_db.bio_id_mem.
    // Therefore this test is expected to expose the current RTL gap.
    //=============================================================
    task test_nfc_bio_wrong_template;
        begin
            $display("\n-- P2-05: NFC + BIO, wrong template with match status --");
            reset_and_preload(4'b1001, 16'h0000, 8'h05);

            send_nfc;
            wait_for_factor(4'b0001);
            send_bio_match(8'h99);

            #50000;
            check(solenoid == 1'b0,
                  "WRONG biometric template must not unlock (known RTL gap)");
            check(fsm_state != S_GRANT,
                  "WRONG biometric template must not reach GRANT (known RTL gap)");

            // If current RTL grants, the checks above intentionally report
            // failures. This is a security defect, not a TB defect.
            if (solenoid == 1'b1)
                $display("  INFO: current RTL accepted BIO status=match without template-ID comparison.");
        end
    endtask

    //=============================================================
    // TEST 6: PIN first for PIN + OTP
    //
    // Intended behavior: should be a valid first factor.
    // Current top-level starts the session on the first key event and
    // clears pin_entry_active in the same clock, so the first digit is
    // lost. This test exposes that integration limitation.
    //=============================================================
    task test_pin_first_limitation;
        begin
            $display("\n-- P2-06: PIN first for PIN + OTP --");
            reset_and_preload(4'b0110, 16'hABCD, 8'h05);

            enter_pin_1234;

            #50000;
            check(solenoid == 1'b1,
                  "PIN-first should unlock for valid PIN+OTP (known top-level limitation)");
            if (solenoid == 1'b0)
                $display("  INFO: first PIN digit is lost when it starts the session; DB search cannot identify the user.");
        end
    endtask

    //=============================================================
    // TEST 7: OTP first for OTP + NFC
    //
    // Intended behavior: factor order should be allowed.
    // Current top-level cannot establish user identity from OTP first,
    // and otp_check is gated by session_active, so the OTP event can be
    // missed while the FSM is in ID_CAPTURE.
    //=============================================================
    task test_otp_first_limitation;
        begin
            $display("\n-- P2-07: OTP first for OTP + NFC --");
            reset_and_preload(4'b0101, 16'hABCD, 8'h05);

            send_otp(8'h66);
            #50000;

            check(solenoid == 1'b1,
                  "OTP-first should be accepted for OTP+NFC (known top-level limitation)");
            if (solenoid == 1'b0)
                $display("  INFO: OTP-first cannot identify the user in current top-level flow.");
        end
    endtask

    //=============================================================
    // TEST 8: Invalid factor configuration
    //=============================================================
    task test_invalid_config;
        begin
            $display("\n-- P2-08: invalid factor configuration --");
            reset_and_preload(4'b0000, 16'hABCD, 8'h05);

            send_nfc;
            wait (dut.attempt_count == 4'd1);

            check(solenoid == 1'b0, "invalid factor configuration does not unlock");
            check(dut.factor_match_inst.invalid_configuration == 1'b1,
                  "invalid_configuration is asserted");
            wait_ready;
        end
    endtask

    //=============================================================
    // TEST 9: duplicate NFC factor must not complete authentication
    //=============================================================
    task test_duplicate_nfc;
        begin
            $display("\n-- P2-09: duplicate NFC factor --");
            reset_and_preload(4'b0011, 16'h0000, 8'h05);

            send_nfc;
            wait_for_factor(4'b0001);

            // Same NFC again. Current top-level deliberately suppresses a
            // repeated UID search, so it must not count as PIN.
            send_nfc;
            #100000;

            check(solenoid == 1'b0, "duplicate NFC cannot unlock as second factor");
            check(factor_status == 4'b0001,
                  "duplicate NFC does not add a second factor");
        end
    endtask

    //=============================================================
    // MAIN
    //=============================================================
    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        keypad_col = 4'b1111;
        nfc_uart_rx_in = 1'b1;
        bio_uart_rx_in = 1'b1;
        otp_uart_rx_in = 1'b1;
        errors = 0;
        captured_pin_hash = 32'h0;

        repeat (4) @(posedge clk);
        rst_n = 1'b1;
        repeat (4) @(posedge clk);

        $display("====================================================");
        $display("        MFA LOCK PHASE-2 SYSTEM TESTBENCH");
        $display("====================================================");
        $display("Capturing actual PIN hash for 1234...");

        capture_pin_hash;
        $display("Captured PIN hash = %h", captured_pin_hash);

        test_nfc_otp_pass;
        test_nfc_otp_fail;
        test_nfc_bio_pass;
        test_nfc_bio_fail;
        test_nfc_bio_wrong_template;
        test_pin_first_limitation;
        test_otp_first_limitation;
        test_invalid_config;
        test_duplicate_nfc;

        $display("\n====================================================");
        $display("PHASE-2 TESTBENCH FINISHED");
        $display("Total errors = %0d", errors);
        if (errors == 0)
            $display("ALL PHASE-2 CHECKS PASSED");
        else
            $display("PHASE-2 FOUND %0d ISSUE(S) - SEE TEST OUTPUT ABOVE", errors);
        $display("====================================================");
        $finish;
    end

    // Hard safety timeout.
    initial begin
        #1_300_000_000;
        $display("TIMEOUT: Phase-2 testbench did not finish.");
        $finish;
    end

endmodule

`default_nettype wire
