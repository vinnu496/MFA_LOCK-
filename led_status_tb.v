`default_nettype none
`timescale 1ns / 1ps

module led_status_tb;
    // Test signals
    reg clk;
    reg rst_n;
    // Control inputs from FSM
    reg unlock_ok;
    reg denial;
    reg lockout;
    reg admin_menu;
    // LEDs
    wire [1:0] led_green;
    wire [1:0] led_red;
    
    // Instantiate the unit under test
    led_status uut (
        .clk(clk),
        .rst_n(rst_n),
        .unlock_ok(unlock_ok),
        .denial(denial),
        .lockout(lockout),
        .admin_menu(admin_menu),
        .led_green(led_green),
        .led_red(led_red)
    );
    
    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;  // 100MHz clock
    
    initial begin
        // Initialize inputs
        rst_n = 0;
        unlock_ok = 0;
        denial = 0;
        lockout = 0;
        admin_menu = 0;
        
        // Reset period
        #100;
        rst_n = 1;
        #100;
        
        // ==================== TEST 1: Ready state (green) ====================
        $display("TEST 1: Ready state - green LED");
        #200;
        
        if (led_green == 2'd1 && led_red == 2'd0) begin
            $display("PASS: Green LED on for ready state");
        end else begin
            $display("FAIL: Green LED should be on for ready state");
        end
        
        // ==================== TEST 2: Denial (red) ====================
        $display("\nTEST 2: Denial - red LED");
        denial = 1;
        #200;
        
        if (led_red == 2'd1 && led_green == 2'd0) begin
            $display("PASS: Red LED on for denial");
        end else begin
            $display("FAIL: Red LED should be on for denial");
        end
        
        // ==================== TEST 3: Unlock (green) ====================
        $display("\nTEST 3: Unlock - green LED");
        denial = 0;
        unlock_ok = 1;
        #200;
        
        if (led_green == 2'd1) begin
            $display("PASS: Green LED on for unlock");
        end else begin
            $display("FAIL: Green LED should be on for unlock");
        end
        
        // ==================== TEST 4: Lockout (red) ====================
        $display("\nTEST 4: Lockout - red LED");
        unlock_ok = 0;
        lockout = 1;
        #200;
        
        if (led_red == 2'd1) begin
            $display("PASS: Red LED on for lockout");
        end else begin
            $display("FAIL: Red LED should be on for lockout");
        end
        
        // ==================== TEST 5: Admin menu (green) ====================
        $display("\nTEST 5: Admin menu - green LED");
        lockout = 0;
        admin_menu = 1;
        #200;
        
        if (led_green == 2'd1) begin
            $display("PASS: Green LED on for admin menu");
        end else begin
            $display("FAIL: Green LED should be on for admin menu");
        end
        
        // ==================== SUMMARY ====================
        $display("\n=========================================");
        $display("LED_STATUS TEST SUMMARY");
        $display("=========================================");
        $display("All LED status tests completed");
        $display("=========================================");
        
        #100;
        $finish;
    end
endmodule
`default_nettype wire