`default_nettype none
`timescale 1ns / 1ps

module factor_match_tb;
    // Test signals
    reg clk;
    reg rst_n;
    // User's required factor bitmask (exactly 2 bits set)
    reg [3:0] factor_req;
    // Individual factor verification results
    reg nfc_valid;
    reg pin_valid;
    reg otp_valid;
    reg bio_valid;
    // Control
    reg reset_factors;
    // Outputs
    wire factor1_done;
    wire factor2_done;
    wire unlock_allowed;
    
    // Instantiate the unit under test
    factor_match uut (
        .clk(clk),
        .rst_n(rst_n),
        .factor_req(factor_req),
        .nfc_valid(nfc_valid),
        .pin_valid(pin_valid),
        .otp_valid(otp_valid),
        .bio_valid(bio_valid),
        .reset_factors(reset_factors),
        .factor1_done(factor1_done),
        .factor2_done(factor2_done),
        .unlock_allowed(unlock_allowed)
    );
    
    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;  // 100MHz clock
    
    initial begin
        // Initialize inputs
        rst_n = 0;
        factor_req = 4'd0;
        nfc_valid = 0;
        pin_valid = 0;
        otp_valid = 0;
        bio_valid = 0;
        reset_factors = 0;
        
        // Reset period
        #100;
        rst_n = 1;
        #100;
        
        // ==================== TEST 1: NFC | PIN combination ====================
        $display("TEST 1: NFC | PIN combination (factor_req=3)");
        factor_req = 4'd3;  // bit0=NFC, bit1=PIN
        reset_factors = 1;
        #10;
        reset_factors = 0;
        
        // Wait for both factors to pass
        #100;
        nfc_valid = 1;
        #100;
        pin_valid = 1;
        #100;
        
        // Check results
        if (unlock_allowed) begin
            $display("PASS: unlock_allowed after NFC+PIN both passed");
        end else begin
            $display("FAIL: unlock_allowed should be high after NFC+PIN both passed");
        end
        
        // Reset and test with only one factor
        reset_factors = 1;
        #10;
        reset_factors = 0;
        nfc_valid = 0;
        pin_valid = 0;
        
        // ==================== TEST 2: Only first factor passes ====================
        $display("\nTEST 2: Only first factor passes (NFC only)");
        factor_req = 4'd3;  // NFC | PIN
        nfc_valid = 1;
        pin_valid = 0;
        #100;
        
        if (!unlock_allowed) begin
            $display("PASS: unlock_allowed remains low with only NFC passed");
        end else begin
            $display("FAIL: unlock_allowed should be low with only NFC passed");
        end
        
        // Now apply PIN
        pin_valid = 1;
        #100;
        
        if (unlock_allowed) begin
            $display("PASS: unlock_allowed after PIN also passed");
        end else begin
            $display("FAIL: unlock_allowed should be high after PIN passed");
        end
        
        // ==================== TEST 3: OTP | BIOMETRIC combination ====================
        $display("\nTEST 3: OTP | BIOMETRIC combination (factor_req=12)");
        factor_req = 4'd12;  // bit2=OTP, bit3=BIOMETRIC
        nfc_valid = 0; pin_valid = 0;
        otp_valid = 0; bio_valid = 0;
        reset_factors = 1;
        #10;
        reset_factors = 0;
        
        otp_valid = 1;
        #100;
        if (!unlock_allowed) begin
            $display("PASS: unlock_allowed remains low after only OTP passed");
        end
        
        bio_valid = 1;
        #100;
        if (unlock_allowed) begin
            $display("PASS: unlock_allowed after BIOMETRIC also passed");
        end else begin
            $display("FAIL: unlock_allowed should be high after BIOMETRIC passed");
        end
        
        // ==================== TEST 4: Reset between attempts ====================
        $display("\nTEST 4: Reset between attempts");
        factor_req = 4'd5;  // NFC | OTP
        nfc_valid = 0; pin_valid = 0; otp_valid = 0; bio_valid = 0;
        reset_factors = 1;
        #10;
        reset_factors = 0;
        
        nfc_valid = 1;
        #100;
        if (!unlock_allowed) begin
            $display("PASS: unlock_allowed low after reset, only NFC passed");
        end
        
        otp_valid = 1;
        #100;
        if (unlock_allowed) begin
            $display("PASS: unlock_allowed after OTP also passed (reset was applied earlier)");
        end else begin
            $display("FAIL: unlock_allowed should be high");
        end
        
        // ==================== SUMMARY ====================
        $display("\n=========================================");
        $display("FACTOR_MATCH TEST SUMMARY");
        $display("=========================================");
        $display("All factor combination tests completed");
        $display("=========================================");
        
        #100;
        $finish;
    end
endmodule
`default_nettype wire