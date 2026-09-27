`default_nettype none
`timescale 1ns / 1ps

module attempt_counter_tb;
    // Test signals
    reg clk;
    reg rst_n;
    // Control
    reg inc_enable;
    reg reset;
    // max_count is derived internally from counter value
    // Outputs
    wire [3:0] count;
    wire lockout_flag;
    wire under_limit;
    
    // Instantiate the unit under test
    attempt_counter uut (
        .clk(clk),
        .rst_n(rst_n),
        .inc_enable(inc_enable),
        .reset(reset),
        .lockout_flag(lockout_flag),
        .under_limit(under_limit),
        .count(count)
    );
    
    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;  // 100MHz clock
    
    initial begin
        // Initialize inputs
        rst_n = 0;
        inc_enable = 0;
        reset = 0;
        
        // Reset period
        #100;
        rst_n = 1;
        #100;
        
        // ==================== TEST 1: Counter increments ====================
        $display("TEST 1: Counter increments on failed factors");
        inc_enable = 0;
        reset = 0;
        #100;
        
        // Increment 5 times
        inc_enable = 1;
        #10;
        inc_enable = 0;
        #100;
        
        inc_enable = 1;
        #10;
        inc_enable = 0;
        #100;
        
        inc_enable = 1;
        #10;
        inc_enable = 0;
        #100;
        
        inc_enable = 1;
        #10;
        inc_enable = 0;
        #100;
        
        inc_enable = 1;
        #10;
        inc_enable = 0;
        #100;
        
        // Count should be 5
        if (count == 4'd5) begin
            $display("PASS: count is 5 after 5 increments");
        end else begin
            $display("FAIL: count should be 5, got %d", count);
        end
        
        // ==================== TEST 2: Lockout at 15 ====================
        $display("\nTEST 2: Lockout at 15 attempts");
        // Reset counter
        reset = 1;
        #10;
        reset = 0;
        
        // Increment until lockout
        for (integer i = 0; i < 20; i = i + 1) begin
            inc_enable = 1;
            #10;
            inc_enable = 0;
            #10;
        end
        
        // After 15 increments, lockout_flag should be high
        if (lockout_flag) begin
            $display("PASS: lockout_flag high at 15 attempts");
        end else begin
            $display("FAIL: lockout_flag should be high at 15 attempts, got %b", lockout_flag);
        end
        
        // under_limit should be low at 15
        if (!under_limit) begin
            $display("PASS: under_limit low at 15 attempts");
        end else begin
            $display("FAIL: under_limit should be low at 15 attempts");
        end
        
        // ==================== TEST 3: Admin reset exits lockout ====================
        $display("\nTEST 3: Admin reset exits lockout");
        // At this point lockout_flag should be high
        reset = 1;
        #10;
        reset = 0;
        
        if (count == 4'd0 && !lockout_flag) begin
            $display("PASS: Counter reset to 0, lockout_flag low after admin reset");
        end else begin
            $display("FAIL: Counter should be 0 and lockout_flag low after reset");
        end
        
        // ==================== SUMMARY ====================
        $display("\n=========================================");
        $display("ATTEMPT_COUNTER TEST SUMMARY");
        $display("=========================================");
        $display("All counter tests completed");
        $display("=========================================");
        
        #100;
        $finish;
    end
endmodule
`default_nettype wire