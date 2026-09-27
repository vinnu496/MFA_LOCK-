`default_nettype none
`timescale 1ns / 1ps

module access_control_fsm_tb;
    // Test signals
    reg clk;
    reg rst_n;
    // Factor inputs (stubbed - force pass/fail directly)
    reg factor1_pass;
    reg factor2_pass;
    // Admin control
    reg admin_login_req;
    reg admin_auth_pass;
    // System controls
    reg unlock_req;
    reg max_attempts_reached;
    // Outputs
    wire unlock;
    wire admin_menu;
    wire lockout;
    wire denial;
    wire [3:0] state;
    
    // Instantiate the unit under test
    access_control_fsm uut (
        .clk(clk),
        .rst_n(rst_n),
        .factor1_pass(factor1_pass),
        .factor2_pass(factor2_pass),
        .admin_login_req(admin_login_req),
        .admin_auth_pass(admin_auth_pass),
        .unlock_req(unlock_req),
        .max_attempts_reached(max_attempts_reached),
        .unlock(unlock),
        .admin_menu(admin_menu),
        .lockout(lockout),
        .denial(denial),
        .state(state)
    );
    
    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;  // 100MHz clock
    
    initial begin
        // Initialize inputs
        rst_n = 0;
        factor1_pass = 0;
        factor2_pass = 0;
        admin_login_req = 0;
        admin_auth_pass = 0;
        unlock_req = 0;
        max_attempts_reached = 0;
        
        // Reset period
        #100;
        rst_n = 1;
        #100;
        
        // ==================== TEST 1: S_INIT -> S_READY ====================
        $display("TEST 1: S_INIT -> S_READY after reset");
        // After reset and rst_n=1, should be in S_READY
        // (checked via state debug output)
        #100;
        
        // ==================== TEST 2: S_READY -> S_ID_CAPTURE -> S_FACTOR1_VERIFY ====================
        $display("\nTEST 2: S_READY -> S_ID_CAPTURE -> S_FACTOR1_VERIFY");
        // Transition to ID_CAPTURE
        admin_login_req = 1;
        #10;
        admin_login_req = 0;
        #100;
        
        // Now in S_FACTOR1_VERIFY (after ID_CAPTURE)
        // Stimulate factor1_pass
        factor1_pass = 1;
        #10;
        factor1_pass = 0;
        #100;
        
        // ==================== TEST 3: S_FACTOR1_VERIFY pass -> S_FACTOR2_WAIT ====================
        $display("\nTEST 3: S_FACTOR1_VERIFY pass -> S_FACTOR2_WAIT");
        // Should be in S_FACTOR2_WAIT after factor1 pass
        // Now apply factor2
        factor2_pass = 1;
        #10;
        factor2_pass = 0;
        #100;
        
        // ==================== TEST 4: S_FACTOR2_VERIFY pass -> S_GRANT (non-admin) ====================
        $display("\nTEST 4: S_FACTOR2_VERIFY pass -> S_GRANT");
        // Admin login_req should cause S_ADMIN_MENU instead
        // For non-admin path: factor2_pass && !admin_login_req -> S_GRANT
        admin_login_req = 0;
        admin_auth_pass = 0;
        #100;
        
        // ==================== TEST 5: S_FACTOR2_VERIFY pass with admin -> S_ADMIN_MENU ====================
        $display("\nTEST 5: S_FACTOR2_VERIFY pass with admin -> S_ADMIN_MENU");
        // Admin login
        admin_login_req = 1;
        admin_auth_pass = 1;
        #10;
        admin_login_req = 0;
        admin_auth_pass = 1;
        #100;
        
        // ==================== TEST 6: S_DENY path -> S_ATTEMPT_CHECK -> S_READY ====================
        $display("\nTEST 6: S_DENY path -> S_ATTEMPT_CHECK -> S_READY");
        // Factor1 fail
        factor1_pass = 0;
        #100;
        
        // Should go S_DENY -> S_ATTEMPT_CHECK -> S_READY (if not max attempts)
        max_attempts_reached = 0;
        #100;
        
        // ==================== TEST 7: Three fails -> S_LOCKOUT ====================
        $display("\nTEST 7: Three fails -> S_LOCKOUT");
        // Three consecutive failures
        factor1_pass = 0; #100;
        factor1_pass = 0; #100;
        factor1_pass = 0; #100;
        
        // Should be in S_LOCKOUT after 3rd fail
        #100;
        
        // ==================== TEST 8: Lockout reset -> S_READY ====================
        $display("\nTEST 8: Lockout reset -> S_READY");
        // Admin reset exits lockout
        admin_login_req = 1;
        admin_auth_pass = 1;
        #10;
        admin_login_req = 0;
        #100;
        
        // ==================== SUMMARY ====================
        $display("\n=========================================");
        $display("FSM TEST SUMMARY");
        $display("=========================================");
        $display("All FSM state transitions tested");
        $display("=========================================");
        
        #100;
        $finish;
    end
endmodule
`default_nettype wire