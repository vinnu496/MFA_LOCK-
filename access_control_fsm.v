`timescale 1ns/1ps
`default_nettype none

// Main transaction controller. It consumes explicit, one-cycle factor result
// events rather than treating a level signal as a credential.
module access_control_fsm (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       login_start,
    input  wire       factor_valid,
    input  wire       factor_pass,
    input  wire       factor_accepted,
    input  wire       all_factors_done_now,
    input  wire       user_is_admin,
    input  wire       max_attempts_reached,
    input  wire       lockout_expired,
    input  wire       solenoid_done,
    input  wire       admin_exit,
    input  wire       admin_reset,
    output reg        session_active,
    output reg        session_start,
    output reg        denial_pulse,
    output reg        attempt_increment,
    output reg        lockout_start,
    output reg        unlock_request,
    output reg        admin_menu,
    output reg        lockout,
    output reg [3:0]  state
);

    localparam S_INIT           = 4'd0;
    localparam S_READY          = 4'd1;
    localparam S_ID_CAPTURE     = 4'd2;
    localparam S_FACTOR1_VERIFY = 4'd3;
    localparam S_FACTOR2_WAIT   = 4'd4;
    localparam S_FACTOR2_VERIFY = 4'd5;
    localparam S_GRANT          = 4'd6;
    localparam S_ADMIN_MENU     = 4'd7;
    localparam S_DENY           = 4'd8;
    localparam S_ATTEMPT_CHECK  = 4'd9;
    localparam S_LOCKOUT        = 4'd10;

    reg [3:0] next_state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= S_INIT;
        else
            state <= next_state;
    end

    always @* begin
        next_state = state;
        case (state)
            S_INIT:           next_state = S_READY;
            S_READY:          if (login_start) next_state = S_ID_CAPTURE;
            S_ID_CAPTURE:     next_state = S_FACTOR1_VERIFY;

            S_FACTOR1_VERIFY: begin
                if (factor_valid) begin
                    if (factor_pass && factor_accepted)
                        next_state = S_FACTOR2_WAIT;
                    else
                        next_state = S_DENY;
                end
            end

            S_FACTOR2_WAIT: begin
                if (factor_valid) begin
                    if (!factor_pass || !factor_accepted)
                        next_state = S_DENY;
                    else if (all_factors_done_now) begin
                        if (user_is_admin)
                            next_state = S_ADMIN_MENU;
                        else
                            next_state = S_GRANT;
                    end
                end
            end

            // Retained in the public state encoding for compatibility with
            // existing debug documentation. Results are acted on in WAIT so
            // a one-clock event cannot be missed.
            S_FACTOR2_VERIFY: next_state = S_FACTOR2_WAIT;

            S_GRANT:          if (solenoid_done) next_state = S_READY;
            S_ADMIN_MENU:     if (admin_exit) next_state = S_READY;
            S_DENY:           next_state = S_ATTEMPT_CHECK;
            S_ATTEMPT_CHECK:  if (max_attempts_reached) next_state = S_LOCKOUT;
                              else next_state = S_READY;
            S_LOCKOUT:        if (lockout_expired || admin_reset) next_state = S_READY;
            default:          next_state = S_INIT;
        endcase
    end

    always @* begin
        session_active   = (state == S_FACTOR1_VERIFY) ||
                           (state == S_FACTOR2_WAIT) ||
                           (state == S_FACTOR2_VERIFY);
        session_start    = (state == S_READY) && login_start;
        denial_pulse     = (state == S_DENY);
        attempt_increment = (state == S_DENY);
        lockout_start    = (state == S_ATTEMPT_CHECK) && max_attempts_reached;
        unlock_request   = (state == S_GRANT);
        admin_menu       = (state == S_ADMIN_MENU);
        lockout          = (state == S_LOCKOUT);
    end

endmodule

`default_nettype wire
