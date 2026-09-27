`default_nettype none
`timescale 1ns / 1ps

module nfc_interface_tb;
    // Test signals
    reg clk;
    reg rst_n;
    // UART interface from uart_rx
    reg rx_valid;
    reg [7:0] rx_data;
    // User database interface
    reg [7:0] claimed_user_id;
    reg [127:0] user_ram_data;
    // Outputs
    wire nfc_match;
    wire [31:0] nfc_uid;
    
    // Instantiate the unit under test
    nfc_interface uut (
        .clk(clk),
        .rst_n(rst_n),
        .rx_valid(rx_valid),
        .rx_data(rx_data),
        .claimed_user_id(claimed_user_id),
        .user_ram_data(user_ram_data),
        .nfc_match(nfc_match),
        .nfc_uid(nfc_uid)
    );
    
    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;  // 100MHz clock
    
    initial begin
        // Initialize inputs
        rst_n = 0;
        rx_valid = 0;
        rx_data = 8'd0;
        claimed_user_id = 8'd0;
        user_ram_data = 128'd0;
        
        // Reset period
        #100;
        rst_n = 1;
        #100;
        
        // ==================== TEST 1: NFC match ====================
        $display("TEST 1: NFC UID match");
        // Set up user 1 with nfc_uid = 32'hAABBCCDD
        claimed_user_id = 8'd1;
        // user_ram_data[97:65] = nfc_uid (bits 97 down to 65)
        user_ram_data = {16'd0, 32'hAABBCCDD, 16'd0, 64'd0};  // adjust bit positions
        
        // Receive 4 bytes over UART to form UID: AABBCCDD
        // Byte order: first byte goes to highest bits
        rx_valid = 1;
        rx_data = 8'hAA;
        #50;
        rx_data = 8'hBB;
        #50;
        rx_data = 8'hCC;
        #50;
        rx_data = 8'hDD;
        #50;
        rx_valid = 0;
        
        // Check for match
        #100;
        
        if (nfc_match) begin
            $display("PASS: NFC UID matched successfully");
        end else begin
            $display("FAIL: NFC UID should match");
        end
        
        // ==================== TEST 2: NFC mismatch ====================
        $display("\nTEST 2: NFC UID mismatch");
        // Change to wrong UID
        claimed_user_id = 8'd1;
        user_ram_data = {16'd0, 32'h11223344, 16'd0, 64'd0};  // different UID
        
        // Receive same UID: AABBCCDD
        rx_valid = 1;
        rx_data = 8'hAA;
        #50;
        rx_data = 8'hBB;
        #50;
        rx_data = 8'hCC;
        #50;
        rx_data = 8'hDD;
        #50;
        rx_valid = 0;
        
        #100;
        
        if (!nfc_match) begin
            $display("PASS: NFC UID mismatch detected");
        end else begin
            $display("FAIL: NFC UID should not match");
        end
        
        // ==================== SUMMARY ====================
        $display("\n=========================================");
        $display("NFC_INTERFACE TEST SUMMARY");
        $display("=========================================");
        $display("NFC interface tests completed");
        $display("=========================================");
        
        #100;
        $finish;
    end
endmodule
`default_nettype wire