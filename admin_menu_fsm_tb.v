`default_nettype none
`timescale 1ns / 1ps

module admin_menu_fsm_tb;
    // Test signals
    reg clk;
    reg rst_n;
    // Control inputs
    reg enter_menu;
    reg exit_menu;
    reg add_user_req;
    reg remove_user_req;
    reg edit_factors_req;
    reg confirm_req;
    // User DB write interface
    wire [7:0] wr_addr;
    wire [127:0] wr_data;
    wire wr_en;
    // Output flags
    wire menu_active;
    wire [3:0] menu_state;
    // Output: action completed
    wire action_done;
    
    // Instantiate the unit under test
    admin_menu_fsm uut (
        .clk(clk),
        .rst_n(rst_n),
        .enter_menu(enter_menu),
        .exit_menu(exit_menu),
        .add_user_req(add_user_req),
        .remove_user_req(remove_user_req),
        .edit_factors_req(edit_factors_req),
        .confirm_req(confirm_req),
        .wr_addr(wr_addr),
        .wr_data(wr_data),
        .wr_en(wr_en),
        .menu_active(menu_active),
        .menu_state(menu_state),
        .action_done(action_done)
    );
    
    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;  // 100MHz clock
    
    initial begin
        // Initialize inputs
        rst_n = 0;
        enter_menu = 0;
        exit_menu = 0;
        add_user_req = 0;
        remove_user_req = 0;
        edit_factors_req = 0;
        confirm_req = 0;
        
        // Reset period
        #100;
        rst_n = 1;
        #100;
        
        // ==================== TEST 1: Enter admin menu ====================
        $display("TEST 1: Enter admin menu from S_ADMIN_MENU");
        enter_menu = 1;
        #100;
        enter_menu = 0;
        
        if (menu_active) begin
            $display("PASS: Admin menu is active");
        end else begin
            $display("FAIL: Admin menu should be active");
        end
        
        // ==================== TEST 2: Add user action ====================
        $display("\nTEST 2: Add user action");
        add_user_req = 1;
        #100;
        add_user_req = 0;
        confirm_req = 1;
        #100;
        
        if (action_done) begin
            $display("PASS: Add user action completed");
        end else begin
            $display("FAIL: Add user action should complete");
        end
        
        // ==================== TEST 3: Remove user action ====================
        $display("\nTEST 3: Remove user action");
        remove_user_req = 1;
        #100;
        remove_user_req = 0;
        confirm_req = 1;
        #100;
        
        if (action_done) begin
            $display("PASS: Remove user action completed");
        end else begin
            $display("FAIL: Remove user action should complete");
        end
        
        // ==================== TEST 4: Edit factors action ====================
        $display("\nTEST 4: Edit factors action");
        edit_factors_req = 1;
        #100;
        edit_factors_req = 0;
        confirm_req = 1;
        #100;
        
        if (action_done) begin
            $display("PASS: Edit factors action completed");
        end else begin
            $display("FAIL: Edit factors action should complete");
        end
        
        // ==================== TEST 5: Exit admin menu ====================
        $display("\nTEST 5: Exit admin menu");
        exit_menu = 1;
        #100;
        exit_menu = 0;
        
        if (!menu_active) begin
            $display("PASS: Admin menu exited");
        end else begin
            $display("FAIL: Admin menu should be exited");
        end
        
        // ==================== SUMMARY ====================
        $display("\n=========================================");
        $display("ADMIN_MENU_FSM TEST SUMMARY");
        $display("=========================================");
        $display("All admin menu FSM tests completed");
        $display("=========================================");
        
        #100;
        $finish;
    end
endmodule
`default_nettype wire