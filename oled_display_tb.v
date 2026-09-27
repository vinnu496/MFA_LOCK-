`default_nettype none
`timescale 1ns / 1ps

module oled_display_tb;
    // Test signals
    reg clk;
    reg rst_n;
    // I2C-like control signals
    reg sda_in;
    reg scl;
    // Control signals
    reg display_en;
    reg [3:0] cmd_code;
    reg [7:0] cmd_data;
    // Outputs
    wire [7:0] vga_color;
    wire vga_hs;
    wire vga_vs;
    wire [63:0] display_text;
    
    // Instantiate the unit under test
    oled_display uut (
        .clk(clk),
        .rst_n(rst_n),
        .sda_in(sda_in),
        .scl(scl),
        .display_en(display_en),
        .cmd_code(cmd_code),
        .cmd_data(cmd_data),
        .vga_color(vga_color),
        .vga_hs(vga_hs),
        .vga_vs(vga_vs),
        .display_text(display_text)
    );
    
    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;  // 100MHz clock
    
    initial begin
        // Initialize inputs
        rst_n = 0;
        sda_in = 0;
        scl = 0;
        display_en = 0;
        cmd_code = 4'd0;
        cmd_data = 8'd0;
        
        // Reset period
        #100;
        rst_n = 1;
        #100;
        
        // ==================== TEST 1: Clear display ====================
        $display("TEST 1: Clear display command");
        display_en = 1;
        cmd_code = 4'd0;  // CMD_CLEAR
        cmd_data = 8'd0;
        #100;
        
        // ==================== TEST 2: Write text ====================
        $display("\nTEST 2: Write admin menu text");
        cmd_code = 4'd2;  // CMD_WRITE
        cmd_data = 8'h41; // 'A'
        #100;
        cmd_data = 8'h44; // 'D'
        #100;
        cmd_data = 8'h4d; // 'M'
        #100;
        cmd_data = 8'h49; // 'I'
        #100;
        cmd_data = 8'h4e; // 'N'
        #100;
        display_en = 0;
        
        // Check display text
        #100;
        
        $display("Display text buffer: %h", display_text);
        
        // ==================== TEST 3: Admin menu command ====================
        $display("\nTEST 3: Admin menu command");
        display_en = 1;
        cmd_code = 4'd4;  // CMD_ADMIN
        cmd_data = 8'd0;
        #100;
        display_en = 0;
        
        $display("After admin cmd, text: %h", display_text);
        
        // ==================== SUMMARY ====================
        $display("\n=========================================");
        $display("OLED_DISPLAY TEST SUMMARY");
        $display("=========================================");
        $display("OLED display tests completed");
        $display("=========================================");
        
        #100;
        $finish;
    end
endmodule
`default_nettype wire