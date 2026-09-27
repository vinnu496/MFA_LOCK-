module led_status (
    input  wire        clk,
    input  wire        rst_n,
    // Control inputs from FSM
    input  wire        unlock_ok,    // 1 when unlock granted
    input  wire        denial,       // 1 when access denied
    input  wire        lockout,      // 1 when in lockout state
    input  wire        admin_menu,   // 1 when admin menu active
    // LED outputs
    output reg  [1:0]  led_green,   // green LED status
    output reg  [1:0]  led_red      // red LED status
    
    // Internal
);

// LED state machine
// Green: normal operation, Red: error/deny/lockout
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        led_green <= #1 2'd0;
        led_red <= #1 2'd0;
    end else begin
        // Default: all LEDs off
        led_green <= #1 2'd0;
        led_red <= #1 2'd0;
        
        case ({unlock_ok, denial, lockout, admin_menu})
            4'b1000: begin // Unlock granted - green
                led_green <= #1 2'd1; // green on
            end
            4'b0100: begin // Denied - red
                led_red <= #1 2'd1; // red on
            end
            4'b0010: begin // Lockout - fast red blink (simulated as steady)
                led_red <= #1 2'd1;
            end
            4'b0001: begin // Admin menu - green slow blink (simulated as steady)
                led_green <= #1 2'd1;
            end
            default: begin // Normal ready state - green
                if (!unlock_ok && !denial && !lockout && !admin_menu)
                    led_green <= #1 2'd1;
            end
        endcase
    end
end

endmodule