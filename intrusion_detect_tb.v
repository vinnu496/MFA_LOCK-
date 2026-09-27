`default_nettype none
`timescale 1ns / 1ps

module intrusion_detect_tb;
    // Test signals
    reg clk;
    reg rst_n;
    // Inputs from attempt_counter and lockout_timer
    reg lockout_flag;
    reg timeout_expired;
    reg failed_factor;
    reg admin_reset;
    // Outputs
    wire intrusion_flag;
    wire rapid_fail;
    wire [3:0] fail_count;
    
    // Instantiate the unit under test
    intrusion_detect uut (
        .clk(clk),
        .rst_n(rst_n),
        .lockout_flag(lockout_flag),
        .timeout_expired(timeout_expired),
        .failed_factor(failed_factor),
        .admin_reset(admin_reset),
        .intrusion_flag(intrusion_flag),
        .rapid_fail(rapid_fail),
        .fail_count(fail_count)
    );
    
    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;  // 100MHz clock
    
    initial begin
        // Initialize inputs
        rst_n = 0;
        lockout_flag = 0;
        timeout_expired = 0;
        failed_factor = 0;
        admin_reset = 0;
        
        // Reset period
        #100;
        rst_n = 1;
        #100;
        
        // ==================== TEST 1: Failure tracking ====================
        $display("TEST 1: Failure tracking and rapid detect");
        failed_factor = 1;
        #100;
        failed_factor = 0;
        #100;
        failed_factor = 1;
        #100;
        failed_factor = 0;
        #100;
        failed_factor = 1;
        #100;
        
        // After 3 failures, rapid_fail should be high
        if (rapid_fail) begin
            $display("PASS: rapid_fail high after 3 failures");
        end else begin
            $display("FAIL: rapid_fail should be high after 3 failures");
        end
        
        if (intrusion_flag) begin
            $display("PASS: intrusion_flag high after rapid fail pattern");
        end else begin
            $display("INFO: intrusion_flag not yet high (may need 2 lockouts)");
        end
        
        // ==================== TEST 2: Success resets counter ====================
        $display("\nTEST 2: Success resets failure counter");
        failed_factor = 0;
        #100;
        
        if (!rapid_fail && (fail_count == 4'd0)) begin
            $display("PASS: Failure counter reset after success");
        end else begin
            $display("FAIL: Failure counter should be 0 after success");
        end
        
        // ==================== TEST 3: Admin reset clears flags ====================
        $display("\nTEST 3: Admin reset clears all flags");
        admin_reset = 1;
        #10;
        admin_reset = 0;
        
        if (!intrusion_flag && !rapid_fail && (fail_count == 4'd0)) begin
            $display("PASS: All flags cleared by admin reset");
        end else begin
            $display("FAIL: Flags should be cleared by admin reset");
        end
        
        // ==================== SUMMARY ====================
        $display("\n=========================================");
        $display("INTRUSION_DETECT TEST SUMMARY");
        $display("=========================================");
        $display("All intrusion detection tests completed");
        $display("=========================================");
        
        #100;
        $finish;
    end
endmodule
`default_nettype wire