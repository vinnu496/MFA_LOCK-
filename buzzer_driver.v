module buzzer_driver (
    input  wire        clk,
    input  wire        rst_n,
    // Control inputs from FSM
    input  wire        deny_pulse,  // 1 for deny tone
    input  wire        intrusion,   // 1 for intrusion alarm
    input  wire        lockout,     // 1 for lockout alarm
    input  wire        mute,        // 1 to mute all output
    // Output - PWM to buzzer
    output reg         buzzer       // PWM output to buzzer driver
    
    // Internal
);

// Tone frequency parameters
localparam TICKS_PER_BEAT = 20_000; // ~20kHz at 100MHz, adjusted for audible tone

reg [17:0] tick_counter;
reg buzzer_internal;

// PWM generator - creates audible tone when enabled
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tick_counter <= #1 18'd0;
        buzzer_internal <= #1 1'b0;
        buzzer <= #1 1'b0;
    end else if (mute) begin
        buzzer_internal <= #1 1'b0;
        buzzer <= #1 1'b0;
    end else begin
        // Count ticks for PWM period
        if (tick_counter == 18'd0) begin
            tick_counter <= #1 TICKS_PER_BEAT - 18'd1;
            buzzer_internal <= #1 ~buzzer_internal;
        end else begin
            tick_counter <= #1 tick_counter - 18'd1;
        end
        
        // Determine buzzer state based on active alarm
        // FIX: was a plain `case`, where 'x' in a case item is matched
        // LITERALLY (only matches an actual X value on the wire), not as a
        // don't-care. Since intrusion/lockout/deny_pulse are always driven
        // 0/1, the 3'b1xx / 3'b01x patterns never matched and both alarms
        // silently fell through to default. `casez` treats 'x'/'?' as
        // don't-care bits, which is what these patterns were meant to do.
        casez ({intrusion, lockout, deny_pulse})
            3'b1xx: begin // Intrusion takes priority
                buzzer_internal <= #1 1'b1; // constant high for alarm
            end
            3'b01x: begin // Lockout
                if (tick_counter < TICKS_PER_BEAT / 2)
                    buzzer_internal <= #1 1'b1;
                else
                    buzzer_internal <= #1 1'b0;
            end
            3'b001: begin // Deny (short pulse)
                if (tick_counter < TICKS_PER_BEAT / 4)
                    buzzer_internal <= #1 1'b1;
                else
                    buzzer_internal <= #1 1'b0;
            end
            default: begin
                buzzer_internal <= #1 1'b0;
            end
        endcase
        
        buzzer <= #1 buzzer_internal;
    end
end

// Initialize
initial begin
    tick_counter <= #1 18'd0;
end

endmodule