`default_nettype none
`timescale 1ns / 1ps

module buzzer_driver_tb;
    // Test signals
    reg clk;
    reg rst_n;
    // Control inputs
    reg deny_pulse;
    reg intrusion;
    reg lockout;
    reg mute;
    // Output
    wire buzzer;
    
    // Instantiate the unit under test
    buzzer_driver uut (
        .clk(clk),
        .rst_n(rst_n),
        .deny_pulse(deny_pulse),
        .intrusion(intrusion),
        .lockout(lockout),
        .mute(mute),
        .buzzer(buzzer)
    );
    
    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;  // 100MHz clock
    
    initial begin
        // Initialize inputs
        rst_n = 0;
        deny_pulse = 0;
        intrusion = 0;
        lockout = 0;
        mute = 0;
        
        // Reset period
        #100;
        rst_n = 1;
        #100;
        
        // ==================== TEST 1: Deny pulse ====================
        $display("TEST 1: Deny pulse");
        deny_pulse = 1;
        #200;
        deny_pulse = 0;
        #200;
        
        // ==================== TEST 2: Lockout alarm ====================
        $display("\nTEST 2: Lockout alarm");
        lockout = 1;
        #500;
        lockout = 0;
        
        // ==================== TEST 3: Intrusion alarm ====================
        $display("\nTEST 3: Intrusion alarm");
        intrusion = 1;
        #500;
        intrusion = 0;
        
        // ==================== TEST 4: Mute ====================
        $display("\nTEST 4: Mute all output");
        mute = 1;
        deny_pulse = 1;
        #200;
        deny_pulse = 0;
        mute = 0;
        
        // ==================== SUMMARY ====================
        $display("\n=========================================");
        $display("BUZZER_DRIVER TEST SUMMARY");
        $display("=========================================");
        $display("All buzzer driver tests completed");
        $display("=========================================");
        
        #100;
        $finish;
    end
endmodule
`default_nettype wire