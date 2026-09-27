module otp_check (
    input  wire        clk,
    input  wire        rst_n,
    // OTP validation control
    input  wire        start,      // 1 to start OTP check
    input  wire        rx_valid,   // 1 when valid data byte received over UART
    input  wire [7:0]  rx_data,  // received data byte (OTP value)
    // User OTP seed from user_db
    input  wire [15:0] otp_seed, // user's OTP seed
    // Outputs
    output reg         otp_match, // 1 when received OTP matches expected
    output reg         otp_valid  // 1 when OTP check completed
    
    // Internal
);

    // OTP counter - generates expected OTP value based on seed and time
    // Simple: use lower 8 bits of (seed + counter) as OTP
    reg [15:0] otp_counter;
    reg [7:0] expected_otp;
    
    // Time-based OTP generation (simplified)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            otp_counter <= #1 16'd0;
            expected_otp <= #1 8'd0;
            otp_match <= #1 1'b0;
            otp_valid <= #1 1'b0;
        end else if (start) begin
            // Start OTP check - increment counter to generate expected OTP
            otp_counter <= #1 otp_counter + 16'd1;
            expected_otp <= #1 otp_counter[15:8];  // use upper byte as OTP
            
            // Check if received OTP matches expected
            if (rx_valid) begin
                if (rx_data == expected_otp) begin
                    otp_match <= #1 1'b1;
                end else begin
                    otp_match <= #1 1'b0;
                end
                otp_valid <= #1 1'b1;
            end
        end else begin
            // Not actively checking - hold values
            otp_valid <= #1 1'b0;
        end
    end

endmodule