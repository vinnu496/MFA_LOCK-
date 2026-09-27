module debounce (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        raw_signal,  // asynchronous raw input (e.g., button press)
    output reg         debounced  // clean, debounced output
);

// Parameters set via generate or defparam
// Typical: DEPTH = 8 for 256clk @ 100MHz ~ 2.5ms debounce
parameter integer DEPTH = 8;

// Shift register for sampling
reg [DEPTH-1:0] shift_reg;

// Always block: shift register on every clock edge
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        shift_reg <= #1 {DEPTH{1'b0}};
        debounced <= #1 1'b0;
    end else begin
        // Shift in the raw signal
        shift_reg <= #1 {shift_reg[DEPTH-2:0], raw_signal};

        // FIX: check for all-1s or all-0s directly instead of comparing
        // each bit to its neighbor (which compared the top bit against a
        // hardcoded 0 and could never report a stable HIGH).
        if (shift_reg == {DEPTH{1'b1}})
            debounced <= #1 1'b1;
        else if (shift_reg == {DEPTH{1'b0}})
            debounced <= #1 1'b0;
        // else: mid-transition, not yet stable -- hold previous value
    end
end

// Function to compute default debounce time
// At 100MHz, DEPTH=8 gives ~1ms, DEPTH=16 gives ~6.5ms, DEPTH=20 gives ~65ms
// User can override with: defparam debounce_inst.DEPTH = 12;

endmodule