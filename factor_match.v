`timescale 1ns/1ps
`default_nettype none

// Tracks the two configured factors for one authentication session. Factors
// may arrive in either order, but a duplicate factor cannot complete a login.
module factor_match (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [3:0] factor_req,
    input  wire       session_start,
    input  wire       factor_valid,
    input  wire [1:0] factor_type,
    input  wire       factor_pass,
    output reg  [3:0] factors_seen,
    output wire       factor_accepted,
    output wire       all_factors_done,
    output wire       all_factors_done_now,
    output wire       invalid_configuration
);

    wire [3:0] factor_mask;
    wire [3:0] seen_with_event;
    wire       two_factor_configuration;

    assign factor_mask = (factor_type == 2'd0) ? 4'b0001 :
                         (factor_type == 2'd1) ? 4'b0010 :
                         (factor_type == 2'd2) ? 4'b0100 : 4'b1000;

    // The only permitted values have exactly two one bits.
    assign two_factor_configuration = (factor_req == 4'b0011) ||
                                      (factor_req == 4'b0101) ||
                                      (factor_req == 4'b0110) ||
                                      (factor_req == 4'b1001) ||
                                      (factor_req == 4'b1010) ||
                                      (factor_req == 4'b1100);
    assign invalid_configuration = !two_factor_configuration;

    assign factor_accepted = factor_valid && factor_pass &&
                             two_factor_configuration &&
                             ((factor_mask & factor_req) != 4'd0) &&
                             ((factor_mask & factors_seen) == 4'd0);
    assign seen_with_event = factors_seen | (factor_accepted ? factor_mask : 4'd0);
    assign all_factors_done_now = two_factor_configuration &&
                                  ((seen_with_event & factor_req) == factor_req);
    assign all_factors_done = two_factor_configuration &&
                              ((factors_seen & factor_req) == factor_req);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            factors_seen <= 4'd0;
        else if (session_start)
            factors_seen <= 4'd0;
        else if (factor_accepted)
            factors_seen <= seen_with_event;
    end

endmodule

`default_nettype wire
