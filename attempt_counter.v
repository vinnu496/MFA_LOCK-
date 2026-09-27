`timescale 1ns/1ps
`default_nettype none

// Counts failed authentication transactions. The counter saturates so a
// long-held error indication can never wrap around and clear a lockout.
module attempt_counter #(
    parameter [3:0] MAX_ATTEMPTS = 4'd5
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       increment,
    input  wire       clear,
    output reg  [3:0] count,
    output wire       lockout_flag,
    output wire       under_limit
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            count <= 4'd0;
        else if (clear)
            count <= 4'd0;
        else if (increment && (count < MAX_ATTEMPTS))
            count <= count + 4'd1;
    end

    assign lockout_flag = (count >= MAX_ATTEMPTS);
    assign under_limit  = (count < MAX_ATTEMPTS);

endmodule

`default_nettype wire
