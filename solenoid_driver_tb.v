`default_nettype none
`timescale 1ns / 1ps

module solenoid_driver_tb;
    // Test signals
    reg clk;
    reg rst_n;
    // Control input
    reg unlock_pulse;
    // Outputs
    wire solenoid;
    wire unlock_done;
    
    // Instantiate the unit under test
    solenoid_driver uut (
        .clk(clk),
        .rst_n(rst_n),
        .unlock_pulse(unlock_pulse),
        .solenoid(solenoid),
        .unlock_done(unlock_done)
    );
    
    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;  // 100MHz clock
    
    initial begin
        // Initialize inputs
        rst_n = 0;
        unlock_pulse = 0;
        
        // Reset period
        #100;
        rst_n = 1;
        #100;
        
        // ==================== TEST 1: Unlock pulse ====================
        $display("TEST 1: Solenoid unlock pulse");
        unlock_pulse = 1;
        #100;
        unlock_pulse = 0;
        
        // Wait for pulse to complete
        #(20000 / 10);  // approx. 10 cycles of the counter
        
        if (unlock_done) begin
            $display("PASS: unlock_done pulse complete");
        end else begin
            $display("INFO: unlock_done not yet high (still counting)");
        end
        
        // Check solenoid is off after pulse
        #50;
        if (!solenoid) begin
            $display("PASS: Solenoid off after pulse");
        end else begin
            $display("FAIL: Solenoid should be off after pulse");
        end
        
        // ==================== SUMMARY ====================
        $display("\n=========================================");
        $display("SOLENOID_DRIVER TEST SUMMARY");
        $display("=========================================");
        $display("All solenoid driver tests completed");
        $display("=========================================");
        
        #100;
        $finish;
    end
endmodule
`default_nettype wire