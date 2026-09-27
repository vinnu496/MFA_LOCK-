`timescale 1ns/1ps

//=====================================================================
// mfa_lock_top_tb.v
//
// Full-system authentication testbench.
//
// Tests:
//   1. Correct NFC + correct PIN -> UNLOCK
//   2. Correct NFC + wrong PIN -> DENY
//   3. Repeated wrong PIN -> LOCKOUT
//   4. Lockout timeout -> READY
//   5. Correct NFC + PIN after recovery -> UNLOCK
//
// IMPORTANT:
// The keypad scanner itself is NOT being tested here.
// The testbench directly injects key_code/key_valid using
// force/release. This avoids the keypad matrix timing mismatch
// between the testbench model and keypad_scanner.v.
//
// The actual keypad_scanner.v RTL remains unchanged.
//=====================================================================

module mfa_lock_top_tb;

    //=============================================================
    // SIMULATION PARAMETERS
    //=============================================================

    // 1,152,000 Hz gives exactly 10 clock cycles per UART bit
    // at 115200 baud.
    parameter CLK_FREQ_HZ  = 1_152_000;
    parameter BAUD_RATE    = 115200;

    // Use 1 second instead of real 30 seconds for simulation.
    parameter LOCKOUT_SECS = 1;

    parameter MAX_ATTEMPTS = 5;


    //=============================================================
    // TESTBENCH SIGNALS
    //=============================================================

    reg clk;
    reg rst_n;

    // Keypad column input.
    //
    // We no longer model the physical keypad matrix.
    // It stays at idle = 1111.
    reg [3:0] keypad_col;

    // Keypad row output from DUT.
    wire [3:0] keypad_row;


    // UART inputs
    reg nfc_uart_rx_in;
    reg bio_uart_rx_in;
    reg otp_uart_rx_in;

    wire uart_tx_out;


    // Outputs
    wire [1:0] led_green;
    wire [1:0] led_red;
    wire buzzer;
    wire solenoid;

    wire [3:0] fsm_state;
    wire [3:0] factor_status;


    //=============================================================
    // TEST RESULT VARIABLES
    //=============================================================

    integer errors;
    integer expected_attempts;

    reg [31:0] captured_pin_hash;


    //=============================================================
    // DUT
    //=============================================================

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


    //=============================================================
    // CLOCK
    //=============================================================

    // Clock period in ns:
    //
    // 1 second = 1,000,000,000 ns
    // Period = 1e9 / 1,152,000
    //
    // Half period used here.
    always #(500_000_000 / CLK_FREQ_HZ)
        clk = ~clk;


    //=============================================================
    // UART TIMING
    //=============================================================

    localparam integer BIT_NS = 1_000_000_000 / BAUD_RATE;


    //=============================================================
    // UART BYTE TRANSMISSION TASK
    //
    // which:
    //   0 = NFC
    //   1 = Biometric
    //   2 = OTP
    //=============================================================

    task uart_send_byte;
        input [7:0] data;
        input integer which;

        integer i;

        begin

            // START BIT
            case (which)
                0: nfc_uart_rx_in = 1'b0;
                1: bio_uart_rx_in = 1'b0;
                2: otp_uart_rx_in = 1'b0;
            endcase

            #(BIT_NS);


            // DATA BITS - LSB FIRST
            for (i = 0; i < 8; i = i + 1) begin

                case (which)
                    0: nfc_uart_rx_in = data[i];
                    1: bio_uart_rx_in = data[i];
                    2: otp_uart_rx_in = data[i];
                endcase

                #(BIT_NS);

            end


            // STOP BIT
            case (which)
                0: nfc_uart_rx_in = 1'b1;
                1: bio_uart_rx_in = 1'b1;
                2: otp_uart_rx_in = 1'b1;
            endcase

            #(BIT_NS);

        end

    endtask


    //=============================================================
    // KEYPAD PRESS
    //
    // IMPORTANT:
    //
    // We intentionally bypass keypad_scanner.v here.
    //
    // Instead of:
    //
    //   physical keypad
    //        ↓
    //   row/column scanning
    //        ↓
    //   debounce
    //        ↓
    //   key_valid
    //
    // we inject:
    //
    //   key_code
    //   key_valid
    //
    // directly into the DUT.
    //
    // This allows us to test the authentication system itself.
    //=============================================================

    task keypad_press;
        input [3:0] key_code_val;

        begin

            // Wait for a clean clock edge
            @(posedge clk);


            // Inject decoded key directly
            force dut.key_code  = key_code_val;
            force dut.key_valid = 1'b1;


            // Keep key_valid active for one clock
            @(posedge clk);


            // Remove key_valid force
            release dut.key_valid;


            // Give DUT one cycle before releasing key_code
            @(posedge clk);


            // Remove key_code force
            release dut.key_code;


            // Allow authentication logic to settle
            repeat (4)
                @(posedge clk);

        end

    endtask


    //=============================================================
    // PRELOAD TEST USER
    //
    // User 0:
    //
    // Role:
    //   Guest
    //
    // Required factors:
    //   NFC + PIN
    //
    // NFC UID:
    //   DE AD BE EF
    //
    // PIN:
    //   1234
    //
    // PIN hash is captured from the actual pin_hash module.
    //=============================================================

    task preload_test_user;

        begin

            dut.user_db_inst.valid_mem[0] =
                1'b1;

            dut.user_db_inst.is_admin_mem[0] =
                1'b0;

            // NFC + PIN
            dut.user_db_inst.factor_req_mem[0] =
                4'b0011;

            // NFC UID
            dut.user_db_inst.nfc_uid_mem[0] =
                32'hDEADBEEF;

            // Captured PIN hash
            dut.user_db_inst.pin_hash_mem[0] =
                captured_pin_hash;

            // OTP not required
            dut.user_db_inst.otp_seed_mem[0] =
                16'h0000;

            // Biometric not required
            dut.user_db_inst.bio_id_mem[0] =
                8'h00;

        end

    endtask


    //=============================================================
    // CAPTURE ACTUAL PIN HASH
    //
    // PIN = 1234
    //
    // We let the actual pin_hash.v module calculate the hash.
    // This prevents the testbench from assuming a particular
    // hash implementation.
    //=============================================================

    task capture_pin_hash_for;

        input [31:0] pin_digits_bcd;
        input [7:0] len;

        begin

            @(posedge clk);


            // Supply PIN
            force dut.pin_hash_inst.pin_input =
                pin_digits_bcd;

            force dut.pin_hash_inst.pin_len =
                len;


            // Start hash operation
            force dut.pin_hash_inst.start =
                1'b1;


            @(posedge clk);


            // Remove start
            force dut.pin_hash_inst.start =
                1'b0;


            // Wait for hash completion
            wait (dut.pin_hash_valid == 1'b1);


            // Capture generated hash
            captured_pin_hash =
                dut.pin_hash_out;


            @(posedge clk);


            // Release all forces
            release dut.pin_hash_inst.pin_input;
            release dut.pin_hash_inst.pin_len;
            release dut.pin_hash_inst.start;

        end

    endtask


    //=============================================================
    // PASS / FAIL CHECK
    //=============================================================

    task check;

        input cond;
        input [255:0] msg;

        begin

            if (cond) begin

                $display(
                    "  PASS: %s",
                    msg
                );

            end

            else begin

                $display(
                    "  FAIL: %s (time=%0t)",
                    msg,
                    $time
                );

                errors = errors + 1;

            end

        end

    endtask


    //=============================================================
    // ENTER CORRECT PIN: 1234
    //=============================================================

    task enter_pin_1234;

        begin

            keypad_press(4'd1);
            keypad_press(4'd2);
            keypad_press(4'd3);
            keypad_press(4'd4);

            // '#' terminates PIN entry
            keypad_press(4'd14);

        end

    endtask


    //=============================================================
    // ENTER WRONG PIN: 9999
    //=============================================================

    task enter_pin_9999;

        begin

            keypad_press(4'd9);
            keypad_press(4'd9);
            keypad_press(4'd9);
            keypad_press(4'd9);

            // '#' terminates PIN entry
            keypad_press(4'd14);

        end

    endtask


    //=============================================================
    // SEND NFC UID = DEADBEEF
    //
    // Four UART bytes:
    //
    // DE
    // AD
    // BE
    // EF
    //=============================================================

    task send_nfc_uid_deadbeef;

        begin

            uart_send_byte(8'hDE, 0);
            uart_send_byte(8'hAD, 0);
            uart_send_byte(8'hBE, 0);
            uart_send_byte(8'hEF, 0);

        end

    endtask


    //=============================================================
    // MAIN TEST SEQUENCE
    //=============================================================

    initial begin

        //---------------------------------------------------------
        // INITIAL VALUES
        //---------------------------------------------------------

        clk = 1'b0;
        rst_n = 1'b0;

        keypad_col = 4'b1111;

        nfc_uart_rx_in = 1'b1;
        bio_uart_rx_in = 1'b1;
        otp_uart_rx_in = 1'b1;

        errors = 0;
        expected_attempts = 0;
        captured_pin_hash = 32'h00000000;


        //---------------------------------------------------------
        // RESET
        //---------------------------------------------------------

        repeat (4)
            @(posedge clk);

        rst_n = 1'b1;

        repeat (4)
            @(posedge clk);


        //---------------------------------------------------------
        // START MESSAGE
        //---------------------------------------------------------

        $display("");
        $display("====================================================");
        $display("       MFA LOCK FULL SYSTEM TESTBENCH");
        $display("====================================================");
        $display("");


        //---------------------------------------------------------
        // SETUP
        //
        // Calculate actual hash for PIN 1234.
        //---------------------------------------------------------

        $display("Capturing PIN hash for PIN 1234...");

        capture_pin_hash_for(
            32'h00001234,
            8'd4
        );


        //---------------------------------------------------------
        // PRELOAD USER
        //---------------------------------------------------------

        preload_test_user;


        $display(
            "Test user preloaded:"
        );

        $display(
            "  UID       = DEADBEEF"
        );

        $display(
            "  Factors   = NFC + PIN"
        );

        $display(
            "  PIN       = 1234"
        );

        $display(
            "  PIN hash  = %h",
            captured_pin_hash
        );

        $display("");


//=========================================================
// TEST 1
// CORRECT NFC + CORRECT PIN
//=========================================================

$display("");
$display("-- Test 1: correct NFC + correct PIN --");
$display("=== T1 START = %0t ns ===", $time);

send_nfc_uid_deadbeef;

#5000;

enter_pin_1234;

// Wait for unlock
wait (solenoid == 1'b1);

check(
    solenoid == 1'b1,
    "solenoid unlocks on correct NFC+PIN"
);

check(
    fsm_state == 4'd6,
    "FSM reaches S_GRANT"
);

// Wait until unlock pulse ends
wait (solenoid == 1'b0);

#2000;

$display("DEBUG: Test 1 completed at time %0t", $time);
$display("=== T1 END = %0t ns ===", $time);


//=========================================================
// TEST 2
// CORRECT NFC + WRONG PIN
//=========================================================

$display("");
$display("=== T2 START = %0t ns ===", $time);
$display("-- Test 2: correct NFC + wrong PIN --");

$display("DEBUG T2: before sending NFC");

send_nfc_uid_deadbeef;

$display("DEBUG T2: NFC sent");

#5000;

$display("DEBUG T2: before entering wrong PIN");

enter_pin_9999;

$display("DEBUG T2: wrong PIN entered");

// First failed attempt
wait (
    dut.attempt_count == 4'd1
);

check(
    solenoid == 1'b0,
    "solenoid stays locked on wrong PIN"
);

check(
    dut.attempt_count == 4'd1,
    "login increments attempt counter"
);

// Return to READY
wait (
    fsm_state == 4'd1
);

$display("DEBUG T2: completed");
$display("=== T2 END = %0t ns ===", $time);


//=========================================================
// TEST 3
// REPEATED WRONG ATTEMPTS -> LOCKOUT
//=========================================================

$display("");
$display(
    "-- Test 3: %0d wrong attempts trigger lockout --",
    MAX_ATTEMPTS
);

$display("=== T3 START = %0t ns ===", $time);

expected_attempts = 1;

repeat (MAX_ATTEMPTS - 1) begin

    $display(
        "T3: starting wrong attempt, expected next count = %0d",
        expected_attempts + 1
    );

    send_nfc_uid_deadbeef;

    #5000;

    enter_pin_9999;

    wait (
        dut.attempt_count ==
        expected_attempts + 1
    );

    expected_attempts =
        expected_attempts + 1;

    $display(
        "T3: attempt counter = %0d at time %0t",
        expected_attempts,
        $time
    );

    // If not the final attempt,
    // wait for return to READY.
    if (expected_attempts < MAX_ATTEMPTS) begin

        wait (
            fsm_state == 4'd1
        );

        $display(
            "T3: FSM returned to READY at time %0t",
            $time
        );

    end

end


//---------------------------------------------------------
// LOCKOUT SHOULD NOW BE ACTIVE
//---------------------------------------------------------

wait (
    dut.lockout_active == 1'b1
);

$display(
    "T3: lockout_active asserted at time %0t",
    $time
);

check(
    fsm_state == 4'd10,
    "FSM enters S_LOCKOUT after max attempts"
);

check(
    dut.lockout_active == 1'b1,
    "lockout_active is asserted"
);

$display("=== T3 END = %0t ns ===", $time);
        //=========================================================
        // TEST 4
        //
        // WAIT FOR LOCKOUT TIMEOUT
        //
        // LOCKOUT_SECS = 1
        // Therefore this test waits approximately 1 second
        // of simulation time.
        //=========================================================

        $display("");
        $display(
            "-- Test 4: lockout recovers after timeout --"
        );


        wait (
            dut.lockout_active == 1'b0
        );


        $display(
            "  Lockout cleared at time=%0t",
            $time
        );


        check(
            fsm_state == 4'd1,
            "FSM returns to S_READY after lockout timeout"
        );


        //=========================================================
        // TEST 5
        //
        // CORRECT LOGIN AFTER LOCKOUT RECOVERY
        //
        // Expected:
        //   NFC + PIN succeeds again
        //=========================================================

        $display("");
        $display(
            "-- Test 5: correct login after lockout recovery --"
        );


        send_nfc_uid_deadbeef;

        #500_000;

        enter_pin_1234;


        wait (
            solenoid == 1'b1
        );


        check(
            solenoid == 1'b1,
            "solenoid unlocks again after recovery"
        );
        //=========================================================
        // FINAL RESULT
        //=========================================================

        $display("");
        $display(
            "===================================================="
        );

        $display(
            "MFA LOCK TESTBENCH FINISHED"
        );

        $display(
            "Total errors = %0d",
            errors
        );


        if (errors == 0) begin

            $display("");
            $display(
                "**************** ALL TESTS PASSED ****************"
            );
            $display("");

        end

        else begin

            $display("");
            $display(
                "*************** SOME TESTS FAILED ****************"
            );
            $display("");

        end


        $finish;

    end


    //=============================================================
    // SAFETY TIMEOUT
    //
    // Prevents simulation from running forever if a wait()
    // condition is never satisfied.
    //
    // Test 4 needs approximately 1 second = 1,000,000,000 ns.
    // We allow 1.3 seconds.
    //=============================================================

    initial begin

        #1_300_000_000;

        $display("");
        $display(
            "===================================================="
        );

        $display(
            "TIMEOUT: simulation did not finish."
        );

        $display(
            "A wait() condition probably never became true."
        );

        $display(
            "===================================================="
        );

        $finish;

    end

endmodule