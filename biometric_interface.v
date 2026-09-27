module biometric_interface (
    input  wire        clk,
    input  wire        rst_n,
    // UART interface from uart_rx
    input  wire        rx_valid,    // 1 when valid data byte received
    input  wire [7:0]  rx_data,   // received data byte
    // Outputs - biometric match result
    output wire         bio_pass,    // 1 when biometric match accepted
    output wire         bio_checked, // 1 when a full transaction completed (match or not)
    output wire  [7:0]  bio_template_id  // template ID from sensor
);

// Biometric sensor interface
// First byte = status (bit0=match), second byte = template ID

reg [7:0] status_reg;
reg [7:0] template_id_reg;
reg bio_pass_reg;
reg bio_checked_reg;
reg [1:0] byte_cnt;

// Process UART bytes
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        status_reg       <= #1 8'd0;
        template_id_reg  <= #1 8'd0;
        bio_pass_reg      <= #1 1'b0;
        bio_checked_reg    <= #1 1'b0;
        byte_cnt          <= #1 2'd0;
    end else begin
        // Default assignments
        bio_pass_reg    <= #1 1'b0;
        bio_checked_reg  <= #1 1'b0;

        if (rx_valid) begin
            case (byte_cnt)
                2'd0: begin
                    // First byte: status byte, just stash it -- do NOT
                    // assert bio_pass/bio_checked yet, we haven't received
                    // the template ID (2nd byte) that completes this
                    // transaction.
                    status_reg <= #1 rx_data;
                    byte_cnt   <= #1 2'd1;
                end
                2'd1: begin
                    // Second byte: template ID -- transaction is complete
                    // here regardless of match result, so bio_checked
                    // always pulses; bio_pass only pulses on an actual match.
                    template_id_reg <= #1 rx_data;
                    bio_pass_reg     <= #1 status_reg[0];
                    bio_checked_reg   <= #1 1'b1;
                    byte_cnt          <= #1 2'd0;
                end
                default: byte_cnt <= #1 2'd0;
            endcase
        end
    end
end

assign bio_pass    = bio_pass_reg;
assign bio_checked = bio_checked_reg;
assign bio_template_id = template_id_reg;

endmodule