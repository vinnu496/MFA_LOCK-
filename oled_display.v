module oled_display (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        sda_in,
    input  wire        scl,

    input  wire        display_en,
    input  wire [3:0]  cmd_code,
    input  wire [7:0]  cmd_data,

    output reg  [7:0]  vga_color,
    output reg         vga_hs,
    output reg         vga_vs,

    output reg  [63:0] display_text
);

localparam CMD_CLEAR = 4'd0;
localparam CMD_HOME  = 4'd1;
localparam CMD_WRITE = 4'd2;
localparam CMD_GOTO  = 4'd3;
localparam CMD_ADMIN = 4'd4;

localparam OLED_IDLE = 4'd0;
localparam OLED_CMD  = 4'd1;
localparam OLED_DATA = 4'd2;
localparam OLED_DONE = 4'd3;

reg [3:0] oled_state_reg;
reg [3:0] oled_state_next;

reg [7:0] cmd_shift_reg;
reg [3:0] cmd_bit_cnt;
reg [63:0] text_buf;

// State register
// FIX: cmd_shift_reg/cmd_bit_cnt/text_buf used to be reset HERE *and* in
// the command/data processing block below -- two always blocks driving
// the same regs is a multiply-driven-net error at synthesis. They're now
// reset only in the block that actually owns them (below).
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        oled_state_reg <= OLED_IDLE;
    else
        oled_state_reg <= oled_state_next;
end

// Next-state logic
always @* begin
    oled_state_next = oled_state_reg;

    case (oled_state_reg)

        OLED_IDLE: begin
            if (display_en)
                oled_state_next = OLED_CMD;
        end

        OLED_CMD: begin
            oled_state_next = OLED_DATA;
        end

        OLED_DATA: begin
            oled_state_next = OLED_DONE;
        end

        OLED_DONE: begin
            oled_state_next = OLED_IDLE;
        end

        default: begin
            oled_state_next = OLED_IDLE;
        end

    endcase
end

// Command/data processing
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cmd_shift_reg <= 8'd0;
        cmd_bit_cnt   <= 4'd0;
        text_buf      <= 64'd0;
    end
    else begin

        case (oled_state_reg)

            OLED_CMD: begin
                cmd_shift_reg <= cmd_data;
                cmd_bit_cnt   <= 4'd0;
            end

            OLED_DATA: begin
                case (cmd_code)

                    CMD_CLEAR: begin
                        text_buf <= 64'd0;
                    end

                    CMD_HOME: begin
                        // Home operation
                    end

                    CMD_WRITE: begin
                        text_buf <= {text_buf[55:0], cmd_data};
                    end

                    CMD_GOTO: begin
                        // Cursor positioning
                    end

                    CMD_ADMIN: begin
                        // Admin menu
                    end

                    default: begin
                        text_buf <= text_buf;
                    end

                endcase
            end

            default: begin
            end

        endcase
    end
end

// Outputs
always @* begin
    display_text = text_buf;

    vga_color = 8'd0;
    vga_hs    = 1'b0;
    vga_vs    = 1'b0;
end

endmodule