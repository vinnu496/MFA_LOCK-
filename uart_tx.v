module uart_tx (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       tx_en,
    input  wire [7:0] d_in,
    input  wire       tick,

    output reg        tx,
    output reg        tx_done
);

localparam TX_IDLE  = 2'd0;
localparam TX_START = 2'd1;
localparam TX_DATA  = 2'd2;
localparam TX_STOP  = 2'd3;

reg [1:0] state;
reg [7:0] shift_reg;
reg [2:0] bit_counter;

always @(posedge clk or negedge rst_n) begin

    if (!rst_n) begin
        state      <= TX_IDLE;
        shift_reg  <= 8'd0;
        bit_counter <= 3'd0;
        tx         <= 1'b1;
        tx_done    <= 1'b0;
    end

    else begin

        // Default
        tx_done <= 1'b0;

        // UART only advances on baud tick
        if (tick) begin

            case (state)

                TX_IDLE: begin
                    tx <= 1'b1;

                    if (tx_en) begin
                        shift_reg   <= d_in;
                        bit_counter <= 3'd0;
                        state       <= TX_START;
                    end
                end

                TX_START: begin
                    tx    <= 1'b0;
                    state <= TX_DATA;
                end

                TX_DATA: begin
                    tx <= shift_reg[0];

                    shift_reg <= shift_reg >> 1;

                    if (bit_counter == 3'd7) begin
                        bit_counter <= 3'd0;
                        state       <= TX_STOP;
                    end
                    else begin
                        bit_counter <= bit_counter + 3'd1;
                    end
                end

                TX_STOP: begin
                    tx      <= 1'b1;
                    tx_done <= 1'b1;
                    state   <= TX_IDLE;
                end

                default: begin
                    state <= TX_IDLE;
                    tx    <= 1'b1;
                end

            endcase
        end
    end
end

endmodule