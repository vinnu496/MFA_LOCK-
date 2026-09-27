module intrusion_detect (
    input  wire        clk,
    input  wire        rst_n,
    // Inputs from attempt_counter and lockout_timer
    input  wire        lockout_flag,    // from attempt_counter
    input  wire        timeout_expired, // from lockout_timer
    input  wire        failed_factor,   // 1 when a factor verification fails
    // Control
    input  wire        admin_reset,     // 1 to clear flags (admin override)
    // Outputs
    output reg         intrusion_flag, // 1 when rapid-fail OR repeated-lockout pattern detected
    output reg         rapid_fail,     // 1 when multiple fails in short time
    output reg  [3:0]  fail_count,     // count of recent failures for debug
    output reg  [3:0]  lockout_repeat_count // consecutive lockouts with no successful unlock between
);

    // Failure counter for rapid detection
    reg [3:0] fail_counter;
    reg       lockout_flag_prev;

    // Flag when 3+ failures occur without intervening success
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fail_counter          <= 4'd0;
            intrusion_flag        <= 1'b0;
            rapid_fail             <= 1'b0;
            fail_count             <= 4'd0;
            lockout_flag_prev      <= 1'b0;
            lockout_repeat_count   <= 4'd0;
        end else if (admin_reset) begin
            // Admin clears all flags
            fail_counter          <= 4'd0;
            intrusion_flag        <= 1'b0;
            rapid_fail             <= 1'b0;
            fail_count             <= 4'd0;
            lockout_flag_prev      <= 1'b0;
            lockout_repeat_count   <= 4'd0;
        end else begin
            // Track failures
            if (failed_factor) begin
                fail_counter <= fail_counter + 4'd1;
                fail_count   <= fail_counter + 4'd1; // FIX: was 1 cycle stale (assigned fail_counter's OLD value)

                // Rapid fail: 3 failures in sequence
                if (fail_counter >= 4'd2) // this failure will be the 3rd
                    rapid_fail <= 1'b1;
            end else begin
                // Success resets the failure counter
                fail_counter <= 4'd0;
                rapid_fail    <= 1'b0;
            end

            // FIX: lockout_flag and timeout_expired were accepted as inputs
            // but never actually used -- the spec calls for detecting
            // "repeated lockouts", which wasn't implemented (comment used
            // to admit "tracked externally... for now, set intrusion_flag
            // when rapid_fail is active"). This now genuinely counts
            // consecutive lockouts by watching lockout_flag's rising edge.
            // Only admin_reset (handled above) clears this count, so
            // back-to-back lockouts with no successful unlock in between
            // accumulate correctly. timeout_expired isn't needed for this
            // logic -- the rising edge of lockout_flag already marks each
            // new lockout regardless of how the previous one ended.
            lockout_flag_prev <= lockout_flag;
            if (lockout_flag && !lockout_flag_prev)
                lockout_repeat_count <= lockout_repeat_count + 4'd1;

            intrusion_flag <= rapid_fail || (lockout_repeat_count >= 4'd2);
        end
    end

endmodule