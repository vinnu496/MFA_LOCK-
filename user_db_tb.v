`default_nettype none
`timescale 1ns / 1ps

module user_db_tb;
    // Test signals
    reg clk;
    reg rst_n;
    // Write interface
    reg wr_en;
    reg [7:0] wr_addr;
    reg [127:0] wr_data;
    // Read interface
    reg [7:0] rd_addr;
    wire [127:0] rd_data;
    // Search interface
    reg [127:0] search_key;
    wire [7:0] search_addr;
    wire search_found;
    
    // Convenience wires for user fields
    wire [7:0] db_user_id = rd_data[127:120];
    wire db_valid = rd_data[119];
    wire db_is_admin = rd_data[118];
    wire [3:0] db_factor_req = rd_data[117:114];
    wire [15:0] db_pin_hash = rd_data[113:98];
    wire [31:0] db_nfc_uid = rd_data[97:65];
    wire [15:0] db_otp_seed = rd_data[64:49];
    wire [7:0] db_bio_template_id = rd_data[48:41];
    
    // Test coverage
    reg test_passed;
    reg [7:0] test_fail_count;
    
    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;  // 100MHz clock
    
    // Instantiate the unit under test
    user_db uut (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(wr_en),
        .wr_addr(wr_addr),
        .wr_data(wr_data),
        .rd_addr(rd_addr),
        .rd_data(rd_data),
        .search_key(search_key),
        .search_addr(search_addr),
        .search_found(search_found)
    );
    
    initial begin
        // Initialize inputs
        rst_n = 0;
        wr_en = 0;
        wr_addr = 0;
        wr_data = 0;
        rd_addr = 0;
        search_key = 0;
        
        // Reset period
        #100;
        rst_n = 1;
        #100;
        
        test_passed = 1;
        test_fail_count = 0;
        
        // ==================== TEST 1: Initialize and read empty slots ====================
        $display("TEST 1: Initialize and read empty slots");
        // After reset, all slots should have user_id = 255 (empty)
        rd_addr = 8'h00;
        #10;
        if (db_user_id != 8'hFF) begin
            $display("FAIL: Slot 0 should be empty (user_id=FF), got %h", db_user_id);
            test_passed = 0;
            test_fail_count = test_fail_count + 1;
        end else begin
            $display("PASS: Slot 0 is empty (user_id=FF)");
        end
        
        // Check slot 1 also empty
        rd_addr = 8'h01;
        #10;
        if (db_user_id != 8'hFF) begin
            $display("FAIL: Slot 1 should be empty (user_id=FF), got %h", db_user_id);
            test_passed = 0;
            test_fail_count = test_fail_count + 1;
        end else begin
            $display("PASS: Slot 1 is empty (user_id=FF)");
        end
        
        // ==================== TEST 2: Add admin user ====================
        $display("\nTEST 2: Add admin user");
        wr_en = 1;
        wr_addr = 8'h00;  // admin slot
        // Create admin record: user_id=0, valid=1, is_admin=1, factor_req=0, pin_hash=0, nfc_uid=0, otp_seed=0, bio_template_id=0
        wr_data = {8'h00, 1'b1, 1'b1, 4'h0, 16'h0, 32'h0, 16'h0, 8'h0};
        #10;
        wr_en = 0;
        
        rd_addr = 8'h00;
        #10;
        if (db_user_id != 8'h00) begin
            $display("FAIL: Admin user_id should be 00, got %h", db_user_id);
            test_passed = 0;
            test_fail_count = test_fail_count + 1;
        end else begin
            $display("PASS: Admin user_id is 00");
        end
        if (db_is_admin != 1'b1) begin
            $display("FAIL: Admin is_admin should be 1, got %b", db_is_admin);
            test_passed = 0;
            test_fail_count = test_fail_count + 1;
        end else begin
            $display("PASS: Admin is_admin is 1");
        end
        if (db_valid != 1'b1) begin
            $display("FAIL: Admin valid should be 1, got %b", db_valid);
            test_passed = 0;
            test_fail_count = test_fail_count + 1;
        end else begin
            $display("PASS: Admin valid is 1");
        end
        
        // ==================== TEST 3: Add regular user (guest) ====================
        $display("\nTEST 3: Add regular user (guest)");
        wr_addr = 8'h01;  // guest slot 1
        // Create user record: user_id=1, valid=1, is_admin=0, factor_req=NFC|PIN (bit0|bit1 = 3), pin_hash=1234, nfc_uid=56789012, otp_seed=abcd, bio_template_id=1
        wr_data = {8'h01, 1'b1, 1'b0, 4'h3, 16'h1234, 32'h56789012, 16'habcd, 8'h1};
        #10;
        wr_en = 0;
        
        rd_addr = 8'h01;
        #10;
        if (db_user_id != 8'h01) begin
            $display("FAIL: User1 user_id should be 01, got %h", db_user_id);
            test_passed = 0;
            test_fail_count = test_fail_count + 1;
        end else begin
            $display("PASS: User1 user_id is 01");
        end
        if (db_is_admin != 1'b0) begin
            $display("FAIL: User1 is_admin should be 0, got %b", db_is_admin);
            test_passed = 0;
            test_fail_count = test_fail_count + 1;
        end else begin
            $display("PASS: User1 is_admin is 0");
        end
        if (db_factor_req != 4'h3) begin
            $display("FAIL: User1 factor_req should be 3 (NFC|PIN), got %h", db_factor_req);
            test_passed = 0;
            test_fail_count = test_fail_count + 1;
        end else begin
            $display("PASS: User1 factor_req is 3 (NFC|PIN)");
        end
        if (db_pin_hash != 16'h1234) begin
            $display("FAIL: User1 pin_hash should be 1234, got %h", db_pin_hash);
            test_passed = 0;
            test_fail_count = test_fail_count + 1;
        end else begin
            $display("PASS: User1 pin_hash is 1234");
        end
        if (db_nfc_uid != 32'h56789012) begin
            $display("FAIL: User1 nfc_uid should be 56789012, got %h", db_nfc_uid);
            test_passed = 0;
            test_fail_count = test_fail_count + 1;
        end else begin
            $display("PASS: User1 nfc_uid is 56789012");
        end
        
        // ==================== TEST 4: Add another user with different factors ====================
        $display("\nTEST 4: Add user 2 with OTP+BIOMETRIC factors");
        wr_addr = 8'h02;
        // user_id=2, valid=1, is_admin=0, factor_req=bit2|bit3 = OTP|BIOMETRIC = 12, pin_hash=5678, nfc_uid=0, otp_seed=1111, bio_template_id=5
        wr_data = {8'h02, 1'b1, 1'b0, 4'hC, 16'h5678, 32'd0, 16'h1111, 8'h5};
        #10;
        wr_en = 0;
        
        rd_addr = 8'h02;
        #10;
        if (db_factor_req != 4'hC) begin
            $display("FAIL: User2 factor_req should be C (OTP|BIOMETRIC), got %h", db_factor_req);
            test_passed = 0;
            test_fail_count = test_fail_count + 1;
        end else begin
            $display("PASS: User2 factor_req is C (OTP|BIOMETRIC)");
        end
        if (db_bio_template_id != 8'h5) begin
            $display("FAIL: User2 bio_template_id should be 5, got %h", db_bio_template_id);
            test_passed = 0;
            test_fail_count = test_fail_count + 1;
        end else begin
            $display("PASS: User2 bio_template_id is 5");
        end
        
        // ==================== TEST 5: Search functionality ====================
        $display("\nTEST 5: Search functionality");
        // Search for user with user_id=1
        search_key = {8'h01, 1'b1, 1'b0, 4'h0, 16'h0, 32'h0, 16'h0, 8'h0};  // user_id=1, valid=1
        #10;
        if (search_found && (search_addr == 8'h01)) begin
            $display("PASS: Found user 1 at address %h", search_addr);
        end else begin
            $display("FAIL: Should find user 1 at address 01, found=%b addr=%h", search_found, search_addr);
            test_passed = 0;
            test_fail_count = test_fail_count + 1;
        end
        
        // Search for non-existent user (user_id=255 = empty)
        search_key = {8'hFF, 1'b0, 1'b0, 4'h0, 16'h0, 32'h0, 16'h0, 8'h0};
        #10;
        if (!search_found && (search_addr == 8'hFF)) begin
            $display("PASS: Correctly not found empty user");
        end else begin
            $display("FAIL: Should not find empty user slot");
            test_passed = 0;
            test_fail_count = test_fail_count + 1;
        end
        
        // Search for user 2
        search_key = {8'h02, 1'b1, 1'b0, 4'hC, 16'h0, 32'h0, 16'h0, 8'h0};
        #10;
        if (search_found && (search_addr == 8'h02)) begin
            $display("PASS: Found user 2 at address %h", search_addr);
        end else begin
            $display("FAIL: Should find user 2 at address 02");
            test_passed = 0;
            test_fail_count = test_fail_count + 1;
        end
        
        // ==================== TEST 6: Edit user factors ====================
        $display("\nTEST 6: Edit user factors (change factor_req)");
        wr_en = 1;
        wr_addr = 8'h01;
        // Change user 1's factors from NFC|PIN (3) to PIN|OTP (5 = bit1|bit2)
        wr_data = {8'h01, 1'b1, 1'b0, 4'h5, 16'h1234, 32'h56789012, 16'habcd, 8'h1};
        #10;
        wr_en = 0;
        
        rd_addr = 8'h01;
        #10;
        if (db_factor_req != 4'h5) begin
            $display("FAIL: User1 factor_req should be 5 after edit, got %h", db_factor_req);
            test_passed = 0;
            test_fail_count = test_fail_count + 1;
        end else begin
            $display("PASS: User1 factor_req edited to 5 (PIN|OTP)");
        end
        
        // ==================== TEST 7: Remove user (set to empty) ====================
        $display("\nTEST 7: Remove user (set slot to empty)");
        wr_en = 1;
        wr_addr = 8'h02;
        // Write empty user_id=255 to slot 2
        wr_data = {8'hFF, 1'b0, 1'b0, 4'h0, 16'h0, 32'h0, 16'h0, 8'h0};
        #10;
        wr_en = 0;
        
        rd_addr = 8'h02;
        #10;
        if (db_user_id != 8'hFF) begin
            $display("FAIL: Slot 2 should be empty after removal, got %h", db_user_id);
            test_passed = 0;
            test_fail_count = test_fail_count + 1;
        end else begin
            $display("PASS: Slot 2 removed (user_id=FF)");
        end
        if (db_valid != 1'b0) begin
            $display("FAIL: Slot 2 valid should be 0 after removal, got %b", db_valid);
            test_passed = 0;
            test_fail_count = test_fail_count + 1;
        end else begin
            $display("PASS: Slot 2 valid is 0 after removal");
        end
        
        // ==================== TEST 8: Search after removal ====================
        $display("\nTEST 8: Search after removal");
        search_key = {8'h02, 1'b1, 1'b0, 4'h0, 16'h0, 32'h0, 16'h0, 8'h0};
        #10;
        if (!search_found && (search_addr == 8'hFF)) begin
            $display("PASS: Correctly not found removed user");
        end else begin
            $display("FAIL: Should not find removed user");
            test_passed = 0;
            test_fail_count = test_fail_count + 1;
        end
        
        // ==================== SUMMARY ====================
        $display("\n=========================================");
        $display("TEST SUMMARY");
        $display("=========================================");
        if (test_passed) begin
            $display("ALL TESTS PASSED!");
        end else begin
            $display("FAILURES: %d", test_fail_count);
        end
        $display("=========================================");
        
        #100;
        $finish;
    end
endmodule
`default_nettype wire