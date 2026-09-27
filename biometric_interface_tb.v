`default_nettype none
`timescale 1ns / 1ps

module biometric_interface_tb;
    // Test signals
    reg clk;
    reg rst_n;
    // UART interface
    reg rx_valid;
    reg [7:0] rx_data;
    // Outputs
    wire bio_pass;
    wire [7:0] bio_template_id;
    
    // Instantiate the unit under test
    biometric_interface uut (
        .clk(clk),
        .rst_n(rst_n),
        .rx_valid(rx_valid),
        .rx_data(rx_data),
        .bio_pass(bio_pass),
        .bio_template_id(bio_template_id)
    );
    
    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;  // 100MHz clock
    
    initial begin
        // Initialize inputs
        rst_n = 0;
        rx_valid = 0;
        rx_data = 8'd0;
        
        // Reset period
        #100;
        rst_n = 1;
        #100;
        
        // ==================== TEST 1: Biometric match ====================
        $display("TEST 1: Biometric match accepted");
        rx_valid = 1;
        rx_data = 8'd1;  // status byte, bit0=1 = match
        #50;
        rx_data = 8'h05; // template ID = 5
        #50;
        rx_valid = 0;
        
        #100;
        
        if (bio_pass) begin
            $display("PASS: biometric match accepted (bio_pass=1)");
        end else begin
            $display("FAIL: bio_pass should be 1 for match");
        end
        
        if (bio_template_id == 8'h5) begin
            $display("PASS: bio_template_id = 5");
        end else begin
            $display("FAIL: bio_template_id should be 5, got %h", bio_template_id);
        end
        
        // ==================== TEST 2: Biometric no match ====================
        $display("\nTEST 2: Biometric no match rejected");
        rx_valid = 1;
        rx_data = 8'd0;  // status byte, bit0=0 = no match
        #50;
        rx_data = 8'h00; // template ID = 0 (doesn't matter since no match)
        #50;
        rx_valid = 0;
        
        #100;
        
        if (!bio_pass) begin
            $display("PASS: biometric no match rejected (bio_pass=0)");
        end else begin
            $display("FAIL: bio_pass should be 0 for no match");
        end
        
        // ==================== SUMMARY ====================
        $display("\n=========================================");
        $display("BIOMETRIC_INTERFACE TEST SUMMARY");
        $display("=========================================");
        $display("Biometric interface tests completed");
        $display("=========================================");
        
        #100;
        $finish;
    end
endmodule
`default_nettype wire