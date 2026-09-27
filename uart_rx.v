module uart_rx #(
    parameter CLKS_PER_BIT = 868
)(
    input wire clk,
    input wire rst_n,
    input wire rx,
    input wire tick,
    output reg [7:0] d_out,
    output reg d_valid
);

    localparam IDLE  = 2'd0;
    localparam START = 2'd1;
    localparam DATA  = 2'd2;
    localparam STOP  = 2'd3;

    reg [1:0] state;
    reg [15:0] sample_count;
    reg [2:0] bit_counter;
    reg [7:0] shift_reg;
    reg rx_sync1, rx_sync2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync1 <= 1'b1;
            rx_sync2 <= 1'b1;
        end else begin
            rx_sync1 <= rx;
            rx_sync2 <= rx_sync1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            sample_count <= 16'd0;
            bit_counter <= 3'd0;
            shift_reg <= 8'd0;
            d_out <= 8'd0;
            d_valid <= 1'b0;
        end else begin
            d_valid <= 1'b0;
            case (state)
                IDLE: if (!rx_sync2) begin
                    state <= START;
                    sample_count <= 16'd0;
                end
                START: if (sample_count == (CLKS_PER_BIT / 2) - 1) begin
                    sample_count <= 16'd0;
                    if (!rx_sync2) begin
                        state <= DATA;
                        bit_counter <= 3'd0;
                    end else
                        state <= IDLE;
                end else
                    sample_count <= sample_count + 16'd1;
                DATA: if (sample_count == CLKS_PER_BIT - 1) begin
                    sample_count <= 16'd0;
                    shift_reg[bit_counter] <= rx_sync2;
                    if (bit_counter == 3'd7)
                        state <= STOP;
                    else
                        bit_counter <= bit_counter + 3'd1;
                end else
                    sample_count <= sample_count + 16'd1;
                STOP: if (sample_count == CLKS_PER_BIT - 1) begin
                    if (rx_sync2) begin
                        d_out <= shift_reg;
                        d_valid <= 1'b1;
                    end
                    sample_count <= 16'd0;
                    state <= IDLE;
                end else
                    sample_count <= sample_count + 16'd1;
            endcase
        end
    end
endmodule
