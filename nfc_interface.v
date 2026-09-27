module nfc_interface (
    input  wire        clk,
    input  wire        rst_n,
    // UART interface from uart_rx
    input  wire        rx_valid,   // 1 when valid data byte received
    input  wire [7:0]  rx_data,    // received data byte (NFC UID bytes)
    // Claimed user's stored UID, wired directly from user_db.out_nfc_uid --
    // no packed bus, so no field-boundary bit-width bugs are possible.
    input  wire [31:0] stored_nfc_uid,
    // Outputs
    output reg         nfc_match,   // 1-cycle pulse: full UID matched
    output reg         nfc_checked, // 1-cycle pulse: full UID received & compared (match or not)
    output reg  [31:0] nfc_uid_rx   // last fully-received UID, for debug
);

reg [31:0] uid_reg;
reg [1:0]  byte_cnt;       // counts 0-3 for 4 bytes
reg        compare_pending; // set the cycle after the 4th byte lands

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        uid_reg         <= #1 32'd0;
        byte_cnt         <= #1 2'd0;
        nfc_match        <= #1 1'b0;
        nfc_checked      <= #1 1'b0;
        nfc_uid_rx       <= #1 32'd0;
        compare_pending  <= #1 1'b0;
    end else begin
        nfc_match   <= #1 1'b0;  // default: only asserted the cycle we compare
        nfc_checked <= #1 1'b0;

        // Compare ONE CYCLE AFTER the 4th byte lands, so uid_reg has
        // already been fully updated with all 4 bytes before we read it.
        if (compare_pending) begin
            nfc_uid_rx      <= #1 uid_reg;
            nfc_match       <= #1 (uid_reg == stored_nfc_uid);
            nfc_checked     <= #1 1'b1;
            compare_pending <= #1 1'b0;
        end

        if (rx_valid) begin
            uid_reg <= #1 {uid_reg[23:0], rx_data};
            if (byte_cnt == 2'd3) begin
                byte_cnt        <= #1 2'd0;
                compare_pending <= #1 1'b1;
            end else begin
                byte_cnt <= #1 byte_cnt + 2'd1;
            end
        end
    end
end

endmodule
