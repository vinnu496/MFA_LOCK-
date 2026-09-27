`timescale 1ns / 1ps
//=====================================================================
// keypad_scanner.v (fixed -- two bugs corrected)
//
// Bug 1 - Detection polarity was inverted:
//   Old: if (|(col_sync & ~(4'd1 << row_sel)))
//   Active-low matrix means col=0 is PRESSED, col=1 is NOT pressed.
//   col_sync=4'b1111 (nothing pressed) gave: 4'b1111 & mask -> nonzero
//   -> FALSE DETECT every single idle cycle.
//   Fixed: if (|(~col_sync)) -- detect LOW bits (any column at 0 = pressed)
//   col_sync=4'b1111 (idle) -> ~4'b1111 = 4'b0000 -> no detect. Correct.
//   col_sync=4'b1110 (col0 pressed) -> ~4'b1110 = 4'b0001 -> detect. Correct.
//
// Bug 2 - No HOLD_LOW state:
//   After CAPTURE, scanner went directly back to SCAN while key was still
//   physically held. This caused immediate re-detection and key repeat.
//   Fixed: HOLD_LOW state waits until col_sync == 4'b1111 (all released).
//=====================================================================
module keypad_scanner (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [3:0]  col_in,   // columns, active-low (0=pressed)
    output wire [3:0]  row_out,  // rows, active-low (0=currently scanning)
    output reg  [3:0]  key_code,
    output reg         key_valid // 1-cycle pulse on valid key capture
);

    localparam SCAN     = 2'd0;
    localparam DEBOUNCE = 2'd1;
    localparam CAPTURE  = 2'd2;
    localparam HOLD_LOW = 2'd3;

    reg [1:0] state;
    reg [1:0] row_sel;
    reg [3:0] col_sync;
    assign row_out = ~(4'b0001 << row_sel);

    // Combinational decode avoids stale-read from an intermediate register
    reg [3:0] key_decoded;
    always @* begin
        case (row_sel)
            2'd0: case (col_sync)
                    4'b1110: key_decoded = 4'd1;
                    4'b1101: key_decoded = 4'd2;
                    4'b1011: key_decoded = 4'd3;
                    4'b0111: key_decoded = 4'd10; // A
                    default: key_decoded = 4'd0;
                  endcase
            2'd1: case (col_sync)
                    4'b1110: key_decoded = 4'd4;
                    4'b1101: key_decoded = 4'd5;
                    4'b1011: key_decoded = 4'd6;
                    4'b0111: key_decoded = 4'd11; // B
                    default: key_decoded = 4'd0;
                  endcase
            2'd2: case (col_sync)
                    4'b1110: key_decoded = 4'd7;
                    4'b1101: key_decoded = 4'd8;
                    4'b1011: key_decoded = 4'd9;
                    4'b0111: key_decoded = 4'd12; // C
                    default: key_decoded = 4'd0;
                  endcase
            2'd3: case (col_sync)
                    4'b1110: key_decoded = 4'd13; // *
                    4'b1101: key_decoded = 4'd0;
                    4'b1011: key_decoded = 4'd14; // #
                    4'b0111: key_decoded = 4'd15; // D
                    default: key_decoded = 4'd0;
                  endcase
            default: key_decoded = 4'd0;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= SCAN;
            row_sel   <= 2'd0;
            col_sync  <= 4'b1111;
            key_valid <= 1'b0;
            key_code  <= 4'd0;
        end else begin
            key_valid <= 1'b0; // default; only CAPTURE pulses it

            case (state)
                SCAN: begin
                    col_sync <= col_in;

                    // FIX: detect LOW bits (active-low pressed column)
                    if (|(~col_in)) begin
                        state <= DEBOUNCE;
                    end else begin
                        row_sel <= (row_sel == 2'd3) ? 2'd0 : row_sel + 2'd1;
                    end
                end

                DEBOUNCE: begin
                    col_sync <= col_in;
                    if (|(~col_sync))
                        state <= CAPTURE;   // confirmed
                    else
                        state <= SCAN;      // noise, released too fast
                end

                CAPTURE: begin
                    key_code  <= key_decoded;
                    key_valid <= 1'b1;
                    state     <= HOLD_LOW;
                end

                HOLD_LOW: begin
                    col_sync <= col_in;
                    if (col_sync == 4'b1111) begin
                        row_sel <= 2'd0;
                        state   <= SCAN;
                    end
                end

                default: state <= SCAN;
            endcase
        end
    end

endmodule
