module solenoid_driver (
    input  wire        clk,
    input  wire        rst_n,
    // Control input from FSM (S_GRANT state)
    input  wire        unlock_pulse, // 1 pulse to unlock solenoid
    // Output - solenoid control
    output reg         solenoid,    // 1 = unlock solenoid activated
    output reg         unlock_done  // 1 when pulse complete
    
    // Internal
);

// Fixed duration for unlocked state
// At 100MHz, 500_000 cycles = 5ms, 50_000 = 0.5ms, etc.
localparam UNLOCK_DURATION = 20_000; // ~0.2ms for simulation, change as needed

reg [19:0] duration_counter;
reg solenoid_pulsing;
reg unlock_pulse_d;

// Solenoid pulse logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        solenoid <= #1 1'b0;
        unlock_done <= #1 1'b0;
        duration_counter <= #1 20'd0;
        solenoid_pulsing <= #1 1'b0;
        unlock_pulse_d <= #1 1'b0;
    end else begin
        unlock_done <= #1 1'b0; // default: not done
        unlock_pulse_d <= #1 unlock_pulse;
        
        if (solenoid_pulsing) begin
            // Count down duration
            if (duration_counter == 20'd0) begin
                solenoid <= #1 1'b0;   // turn off solenoid
                unlock_done <= #1 1'b1; // pulse complete
                solenoid_pulsing <= #1 1'b0;
            end else begin
                duration_counter <= #1 duration_counter - 20'd1;
            end
        end else if (unlock_pulse && !unlock_pulse_d) begin
            // Start solenoid pulse
            solenoid <= #1 1'b1;   // turn on solenoid
            duration_counter <= #1 UNLOCK_DURATION - 20'd1;
            solenoid_pulsing <= #1 1'b1;
        end
    end
end

// Initialize
initial begin
    solenoid <= #1 1'b0;
end

endmodule
