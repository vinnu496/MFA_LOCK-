`timescale 1ns / 1ps
//=====================================================================
// tb_hotp_rfc4226.v
// Verifies hotp_rfc4226.v against RFC 4226 Appendix D's official test
// vectors, using the standard test secret "12345678901234567890" (ASCII,
// 20 bytes).
//=====================================================================
module tb_hotp_rfc4226;

    reg         clk = 0;
    reg         rst_n;
    reg         start;
    reg  [63:0] counter;
    reg  [159:0] secret_key;

    wire        valid;
    wire [19:0] hotp_value;

    integer errors = 0;

    hotp_rfc4226 dut (
        .clk(clk), .rst_n(rst_n),
        .start(start), .counter(counter), .secret_key(secret_key),
        .valid(valid), .hotp_value(hotp_value)
    );

    always #5 clk = ~clk;

    task run_case(input [63:0] ctr, input [19:0] expected);
        begin
            counter = ctr;
            start   = 1'b1;
            @(posedge clk);
            start   = 1'b0;
            wait (valid == 1'b1);
            @(posedge clk); // let valid pulse clear before next case

            if (hotp_value === expected) begin
                $display("  PASS: counter=%0d -> hotp=%06d (expected %06d)", ctr, hotp_value, expected);
            end else begin
                $display("  FAIL: counter=%0d -> hotp=%06d (expected %06d)", ctr, hotp_value, expected);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        $display("=== tb_hotp_rfc4226 starting (RFC 4226 Appendix D vectors) ===");

        // ASCII "12345678901234567890", 20 bytes
        secret_key = 160'h3132333435363738393031323334353637383930;

        rst_n = 0; start = 0; counter = 64'd0;
        repeat (2) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        // RFC 4226 Appendix D table (first 3 of 10 entries -- enough to catch
        // a wrong counter encoding or a chaining bug between calls)
        run_case(64'd0, 20'd755224);
        run_case(64'd1, 20'd287082);
        run_case(64'd2, 20'd359152);

        $display("\n=== tb_hotp_rfc4226 finished: %0d error(s) ===", errors);
        if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED -- do not trust hotp_rfc4226.v until this is 0");

        $finish;
    end

endmodule