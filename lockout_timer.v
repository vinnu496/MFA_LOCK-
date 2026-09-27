`timescale 1ns/1ps
`default_nettype none

// One-shot lockout timer. A start pulse loads the counter; expiry is a
// one-clock pulse and never reloads until another explicit start request.
module lockout_timer #(
    parameter [31:0] CLK_FREQ_HZ    = 32'd100_000_000,
    parameter [31:0] LOCKOUT_SECONDS = 32'd30
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire        enable,
    input  wire        clear,
    output reg         active,
    output reg         timeout_expired,
    output reg [31:0]  timeout_counter
);

    localparam [31:0] TIMEOUT_CYCLES = CLK_FREQ_HZ * LOCKOUT_SECONDS;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            active          <= 1'b0;
            timeout_expired <= 1'b0;
            timeout_counter <= 32'd0;
        end else begin
            timeout_expired <= 1'b0;

            if (clear) begin
                active          <= 1'b0;
                timeout_counter <= 32'd0;
            end else if (start && !active) begin
                active          <= 1'b1;
                timeout_counter <= TIMEOUT_CYCLES;
            end else if (active && enable) begin
                if (timeout_counter <= 32'd1) begin
                    active          <= 1'b0;
                    timeout_counter <= 32'd0;
                    timeout_expired <= 1'b1;
                end else begin
                    timeout_counter <= timeout_counter - 32'd1;
                end
            end
        end
    end

endmodule

`default_nettype wire
