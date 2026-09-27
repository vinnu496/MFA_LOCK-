`default_nettype none
`timescale 1ns / 1ps

module debounce_tb;
    // Test signals
    reg clk;
    reg rst_n;
    reg raw_signal;
    wire debounced;
    
    // Instantiate the unit under test with DEPTH=8
    debounce #(.DEPTH(8)) uut (
        .clk(clk),
        .rst_n(rst_n),
        .raw_signal(raw_signal),
        .debounced(debounced)
    );
    
    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;  // 100MHz clock
    
    initial begin
        // Initialize inputs
        rst_n = 0;
        raw_signal = 0;
        
        // Reset period
        #100;
        rst_n = 1;
        #100;
        
        // ==================== TEST 1: Stable high signal ====================
        $display("TEST 1: Stable high signal");
        raw_signal = 1;
        #500;  // Stable for 50us - should debounce to 1
        
        if (debounced == 1) begin
            $display("PASS: debounced output is 1 for stable high input");
        end else begin
            $display("FAIL: debounced should be 1 for stable high input");
        end
        
        // ==================== TEST 2: Stable low signal ====================
        $display("\nTEST 2: Stable low signal");
        raw_signal = 0;
        #500;
        
        if (debounced == 0) begin
            $display("PASS: debounced output is 0 for stable low input");
        end else begin
            $display("FAIL: debounced should be 0 for stable low input");
        end
        
        // ==================== TEST 3: Signal transition with noise ====================
        $display("\nTEST 3: Signal transition with noise");
        raw_signal = 0;
        #100;
        // Add some noise (quick toggles)
        raw_signal = 1; #10;
        raw_signal = 0; #10;
        raw_signal = 1; #10;
        raw_signal = 0; #10;
        raw_signal = 1; #10;
        raw_signal = 0; #10;
        // Now stabilize high
        raw_signal = 1;
        #500;
        
        if (debounced == 1) begin
            $display("PASS: debounced correctly filtered noise and stabilized");
        end else begin
            $display("FAIL: debounced should stabilize to 1 after noise");
        end
        
        // ==================== SUMMARY ====================
        $display("\n=========================================");
        $display("DEBOUNCE TEST SUMMARY");
        $display("=========================================");
        $display("All debounce tests completed");
        $display("=========================================");
        
        #100;
        $finish;
    end
endmodule
`default_nettype wire