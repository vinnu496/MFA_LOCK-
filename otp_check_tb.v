`default_nettype none
`timescale 1ns / 1ps

module otp_check_tb;
    // Test signals
    reg clk;
    reg rst_n;
    // OTP check control
    reg start;
    // UART receive interface (stimulus)
    reg rx_valid;
    reg [7:0] rx_data;
    // User OTP seed from user_db
    reg [15:0] otp_seed;
    // Outputs
    wire otp_match;
    wire otp_valid;
    
    // Instantiate the unit under test
    otp_check uut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .rx_valid(rx_valid),
        .rx_data(rx_data),
        .otp_seed(otp_seed),
        .otp_match(otp_match),
        .otp_valid(otp_valid)
    );
    
    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;  // 100MHz clock
    
    initial begin
        // Initialize inputs
        rst_n = 0;
        start = 0;
        rx_valid = 0;
        rx_data = 8'd0;
        otp_seed = 16'hABCD;
        
        // Reset period
        #100;
        rst_n = 1;
        #100;
        
        // ==================== TEST 1: OTP match ====================
        $display("TEST 1: OTP match simulation");
        start = 1;
        #100;
        // After some cycles, provide a matching OTP
        rx_valid = 1;
        rx_data = 8'h57;  // expected OTP value (depends on seed + counter)
        #100;
        rx_valid = 0;
        
        if (otp_match) begin
            $display("PASS: OTP matched successfully");
        end else begin
            $display("FAIL: OTP should match");
        end
        
        if (otp_valid) begin
            $display("PASS: otp_valid pulse generated");
        end else begin
            $display("FAIL: otp_valid should be high after check");
        end
        
        // ==================== TEST 2: OTP mismatch ====================
        $display("\nTEST 2: OTP mismatch");
        start = 1;
        #100;
        rx_valid = 1;
        rx_data = 8'hAB;  // wrong OTP value
        #100;
        rx_valid = 0;
        
        if (!otp_match) begin
            $display("PASS: OTP mismatch detected");
        end else begin
            $display("FAIL: OTP should not match with wrong value");
        end
        
        // ==================== SUMMARY ====================
        $display("\n=========================================");
        $display("OTP_CHECK TEST SUMMARY");
        $display("=========================================");
        $display("OTP check tests completed");
        $display("=========================================");
        
        #100;
        $finish;
    end
endmodule
`default_nettype wire