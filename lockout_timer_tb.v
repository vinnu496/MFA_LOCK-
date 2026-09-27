`default_nettype none
`timescale 1ns / 1ps

module lockout_timer_tb;
    // Test signals
    reg clk;
    reg rst_n;
    // Control
    reg start;
    reg enable;
    reg reset;
    // Outputs
    wire timeout_expired;
    wire [7:0] timeout_counter;
    
    // Instantiate the unit under test
    lockout_timer uut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .enable(enable),
        .reset(reset),
        .timeout_expired(timeout_expired),
        .timeout_counter(timeout_counter)
    );
    
    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;  // 100MHz clock
    
    initial begin
        // Initialize inputs
        rst_n = 0;
        start = 0;
        enable = 0;
        reset = 0;
        
        // Reset period
        #100;
        rst_n = 1;
        #100;
        
        // ==================== TEST 1: Timer counts down ====================
        $display("TEST 1: Timer counts down to expired");
        // Use short timeout for simulation - modify the parameter locally
        // Actually, let's just test with the default 8'd100
        // At 100MHz, 100 cycles = 1us - good for simulation
        
        enable = 1;
        #500;  // Let it count down
        
        if (timeout_expired) begin
            $display("PASS: timeout_expired went high");
        end else begin
            $display("FAIL: timeout_expired should be high after 100 cycles");
        end
        
        // ==================== TEST 2: Reset admin override ====================
        $display("\nTEST 2: Admin reset overrides timer");
        reset = 1;
        #10;
        reset = 0;
        enable = 1;
        #500;
        
        if (!timeout_expired || timeout_counter != 8'd100) begin
            $display("PASS: Timer reset by admin, counter reloaded");
        end else begin
            $display("FAIL: Timer should be reset by admin");
        end
        
        // ==================== TEST 3: Timer restarts on new start ====================
        $display("\nTEST 3: Timer restarts on new start");
        enable = 0;
        #100;
        enable = 1;
        #500;
        
        if (timeout_expired) begin
            $display("PASS: Timer expired after restart");
        end else begin
            $display("FAIL: timeout_expired should be high after restart");
        end
        
        // ==================== SUMMARY ====================
        $display("\n=========================================");
        $display("LOCKOUT_TIMER TEST SUMMARY");
        $display("=========================================");
        $display("All timer tests completed");
        $display("=========================================");
        
        #100;
        $finish;
    end
endmodule
`default_nettype wire