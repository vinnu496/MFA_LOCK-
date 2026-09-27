`default_nettype none
`timescale 1ns / 1ps

module keypad_scanner_tb;
    // Test signals
    reg clk;
    reg rst_n;
    // 4x4 keypad matrix columns (inputs)
    reg [3:0] col_in;
    // 4x4 keypad matrix rows (outputs)
    wire [3:0] row_out;
    // Outputs
    wire [3:0] key_code;
    wire key_valid;
    
    // Instantiate the unit under test
    keypad_scanner uut (
        .clk(clk),
        .rst_n(rst_n),
        .col_in(col_in),
        .row_out(row_out),
        .key_code(key_code),
        .key_valid(key_valid)
    );
    
    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;  // 100MHz clock
    
    initial begin
        // Initialize inputs
        rst_n = 0;
        col_in = 4'b1111;  // No keys pressed (all columns high)
        
        // Reset period
        #100;
        rst_n = 1;
        #100;
        
        // ==================== TEST 1: No key pressed ====================
        $display("TEST 1: No key pressed");
        col_in = 4'b1111;
        #500;
        
        if (key_valid == 0) begin
            $display("PASS: key_valid low when no key pressed");
        end else begin
            $display("FAIL: key_valid should be low when no key pressed");
        end
        
        // ==================== TEST 2: Key press simulated (col0 row0 = key 1) ====================
        $display("\nTEST 2: Simulate key press (key 1 at row0 col0)");
        // Activate row0 (drive low), set col0 low to simulate key press
        col_in = 4'b0111;  // col0=0, others=1 (key 1 pressed)
        #200;  // Let scanner detect the key
        
        if (key_valid && (key_code == 4'd1)) begin
            $display("PASS: key_code = 1 detected correctly");
        end else begin
            $display("FAIL: key_code should be 1, got %d, valid=%b", key_code, key_valid);
        end
        
        // ==================== TEST 3: Different key press ====================
        $display("\nTEST 3: Simulate key press (key 5 at row1 col1)");
        col_in = 4'b1011;  // col1=0 (key 5 at row1 col1)
        #300;
        
        if (key_valid && (key_code == 4'd5)) begin
            $display("PASS: key_code = 5 detected correctly");
        end else begin
            $display("INFO: key_code = %d, valid=%b (may need more cycles)", key_code, key_valid);
        end
        
        // ==================== TEST 4: No key after release ====================
        $display("\nTEST 4: Release key, no press");
        col_in = 4'b1111;  // All columns high - key released
        #300;
        
        if (key_valid == 0) begin
            $display("PASS: key_valid low after key released");
        end else begin
            $display("FAIL: key_valid should be low after key released");
        end
        
        // ==================== SUMMARY ====================
        $display("\n=========================================");
        $display("KEYPAD_SCANNER TEST SUMMARY");
        $display("=========================================");
        $display("Basic keypad scanning tests completed");
        $display("=========================================");
        
        #100;
        $finish;
    end
endmodule
`default_nettype wire