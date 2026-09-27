module pin_hash (
    input  wire        clk,
    input  wire        rst_n,

    // Control
    input  wire        start,
    input  wire [31:0] pin_input,
    input  wire [7:0]  pin_len,
    input  wire [63:0] salt,

    // Outputs
    output reg         valid,
    output reg [31:0]  pin_hash  // truncated SHA-256 (top 32 bits of digest)
);

    // ============================================================
    // FSM STATES
    // ============================================================

    localparam IDLE     = 3'd0;
    localparam PREP     = 3'd1;
    localparam COMPUTE  = 3'd2;
    localparam FINALIZE = 3'd3;
    localparam DONE     = 3'd4;

    reg [2:0] state;
    reg [2:0] next_state;

    // ============================================================
    // SHA-256 REGISTERS
    // ============================================================

    reg [6:0] round_cnt;

    reg [511:0] msg_block;
    reg [255:0] hash_state;

    reg [31:0] w [0:63];

    reg [31:0] a;
    reg [31:0] b;
    reg [31:0] c;
    reg [31:0] d;
    reg [31:0] e;
    reg [31:0] f;
    reg [31:0] g;
    reg [31:0] h;

    // ============================================================
    // SHA-256 INITIAL HASH VALUES
    // ============================================================

    localparam [255:0] SHA256_IV = {
        32'h6a09e667,
        32'hbb67ae85,
        32'h3c6ef372,
        32'ha54ff53a,
        32'h510e527f,
        32'h9b05688c,
        32'h1f83d9ab,
        32'h5be0cd19
    };

    // ============================================================
    // SHA-256 ROUND CONSTANT FUNCTION
    // ============================================================

    function [31:0] K;
        input [6:0] round;
        begin
            case (round)
                7'd0:  K = 32'h428a2f98;
                7'd1:  K = 32'h71374491;
                7'd2:  K = 32'hb5c0fbcf;
                7'd3:  K = 32'he9b5dba5;
                7'd4:  K = 32'h3956c25b;
                7'd5:  K = 32'h59f111f1;
                7'd6:  K = 32'h923f82a4;
                7'd7:  K = 32'hab1c5ed5;
                7'd8:  K = 32'hd807aa98;
                7'd9:  K = 32'h12835b01;
                7'd10: K = 32'h243185be;
                7'd11: K = 32'h550c7dc3;
                7'd12: K = 32'h72be5d74;
                7'd13: K = 32'h80deb1fe;
                7'd14: K = 32'h9bdc06a7;
                7'd15: K = 32'hc19bf174;

                7'd16: K = 32'he49b69c1;
                7'd17: K = 32'hefbe4786;
                7'd18: K = 32'h0fc19dc6;
                7'd19: K = 32'h240ca1cc;
                7'd20: K = 32'h2de92c6f;
                7'd21: K = 32'h4a7484aa;
                7'd22: K = 32'h5cb0a9dc;
                7'd23: K = 32'h76f988da;
                7'd24: K = 32'h983e5152;
                7'd25: K = 32'ha831c66d;
                7'd26: K = 32'hb00327c8;
                7'd27: K = 32'hbf597fc7;
                7'd28: K = 32'hc6e00bf3;
                7'd29: K = 32'hd5a79147;
                7'd30: K = 32'h06ca6351;
                7'd31: K = 32'h14292967;

                7'd32: K = 32'h27b70a85;
                7'd33: K = 32'h2e1b2138;
                7'd34: K = 32'h4d2c6dfc;
                7'd35: K = 32'h53380d13;
                7'd36: K = 32'h650a7354;
                7'd37: K = 32'h766a0abb;
                7'd38: K = 32'h81c2c92e;
                7'd39: K = 32'h92722c85;
                7'd40: K = 32'ha2bfe8a1;
                7'd41: K = 32'ha81a664b;
                7'd42: K = 32'hc24b8b70;
                7'd43: K = 32'hc76c51a3;
                7'd44: K = 32'hd192e819;
                7'd45: K = 32'hd6990624;
                7'd46: K = 32'hf40e3585;
                7'd47: K = 32'h106aa070;

                7'd48: K = 32'h19a4c116;
                7'd49: K = 32'h1e376c08;
                7'd50: K = 32'h2748774c;
                7'd51: K = 32'h34b0bcb5;
                7'd52: K = 32'h391c0cb3;
                7'd53: K = 32'h4ed8aa4a;
                7'd54: K = 32'h5b9cca4f;
                7'd55: K = 32'h682e6ff3;
                7'd56: K = 32'h748f82ee;
                7'd57: K = 32'h78a5636f;
                7'd58: K = 32'h84c87814;
                7'd59: K = 32'h8cc70208;
                7'd60: K = 32'h90befffa;
                7'd61: K = 32'ha4506ceb;
                7'd62: K = 32'hbef9a3f7;
                7'd63: K = 32'hc67178f2;

                default: K = 32'h00000000;
            endcase
        end
    endfunction

    // ============================================================
    // SHA-256 FUNCTIONS
    // ============================================================

    function [31:0] ROTR2;
        input [31:0] x;
        begin
            ROTR2 = (x >> 2) | (x << 30);
        end
    endfunction

    function [31:0] ROTR13;
        input [31:0] x;
        begin
            ROTR13 = (x >> 13) | (x << 19);
        end
    endfunction

    function [31:0] ROTR22;
        input [31:0] x;
        begin
            ROTR22 = (x >> 22) | (x << 10);
        end
    endfunction

    function [31:0] ROTR6;
        input [31:0] x;
        begin
            ROTR6 = (x >> 6) | (x << 26);
        end
    endfunction

    function [31:0] ROTR11;
        input [31:0] x;
        begin
            ROTR11 = (x >> 11) | (x << 21);
        end
    endfunction

    function [31:0] ROTR25;
        input [31:0] x;
        begin
            ROTR25 = (x >> 25) | (x << 7);
        end
    endfunction

    function [31:0] ROTR7;
        input [31:0] x;
        begin
            ROTR7 = (x >> 7) | (x << 25);
        end
    endfunction

    function [31:0] ROTR18;
        input [31:0] x;
        begin
            ROTR18 = (x >> 18) | (x << 14);
        end
    endfunction

    function [31:0] ROTR3;
        input [31:0] x;
        begin
            ROTR3 = (x >> 3) | (x << 29);
        end
    endfunction

    function [31:0] ROTR17;
        input [31:0] x;
        begin
            ROTR17 = (x >> 17) | (x << 15);
        end
    endfunction

    function [31:0] ROTR19;
        input [31:0] x;
        begin
            ROTR19 = (x >> 19) | (x << 13);
        end
    endfunction

    function [31:0] ROTR10;
        input [31:0] x;
        begin
            ROTR10 = (x >> 10) | (x << 22);
        end
    endfunction

    function [31:0] Sigma0;
        input [31:0] x;
        begin
            Sigma0 = ROTR2(x) ^ ROTR13(x) ^ ROTR22(x);
        end
    endfunction

    function [31:0] Sigma1;
        input [31:0] x;
        begin
            Sigma1 = ROTR6(x) ^ ROTR11(x) ^ ROTR25(x);
        end
    endfunction

    // FIX: SHA-256's lowercase sigma0/sigma1 use a plain right SHIFT for
    // their third term, not a rotate. The old ROTR3/ROTR10-based versions
    // produced a non-standard, non-interoperable hash.
    function [31:0] sigma0;
        input [31:0] x;
        begin
            sigma0 = ROTR7(x) ^ ROTR18(x) ^ (x >> 3);
        end
    endfunction

    function [31:0] sigma1;
        input [31:0] x;
        begin
            sigma1 = ROTR17(x) ^ ROTR19(x) ^ (x >> 10);
        end
    endfunction

    function [31:0] Ch;
        input [31:0] x;
        input [31:0] y;
        input [31:0] z;
        begin
            Ch = (x & y) ^ ((~x) & z);
        end
    endfunction

    function [31:0] Maj;
        input [31:0] x;
        input [31:0] y;
        input [31:0] z;
        begin
            Maj = (x & y) ^ (x & z) ^ (y & z);
        end
    endfunction

    // ============================================================
    // MESSAGE BLOCK CREATION
    //
    // Assumption:
    // pin_input contains packed BCD digits.
    //
    // Example:
    // 4-digit PIN 1234 -> pin_input = 32'h00001234
    // 6-digit PIN 123456 -> pin_input = 32'h00123456
    // 8-digit PIN 12345678 -> pin_input = 32'h12345678
    //
    // Message:
    //     SALT || PIN || SHA-256 padding || message length
    // ============================================================

    reg [511:0] prep_block;

    always @* begin

        prep_block = 512'd0;

        // First 8 bytes = salt
        prep_block[511:448] = salt;

        case (pin_len)

            // 4 digits = 16 bits
            8'd4: begin
                prep_block[447:432] = pin_input[15:0];
                prep_block[431:424] = 8'h80;
                prep_block[63:0]    = 64'd80;
            end

            // 5 digits = 20 bits
            8'd5: begin
                prep_block[447:428] = pin_input[19:0];
                prep_block[427:420] = 8'h80;
                prep_block[63:0]    = 64'd84;
            end

            // 6 digits = 24 bits
            8'd6: begin
                prep_block[447:424] = pin_input[23:0];
                prep_block[423:416] = 8'h80;
                prep_block[63:0]    = 64'd88;
            end

            // 7 digits = 28 bits
            8'd7: begin
                prep_block[447:420] = pin_input[27:0];
                prep_block[419:412] = 8'h80;
                prep_block[63:0]    = 64'd92;
            end

            // 8 digits = 32 bits
            8'd8: begin
                prep_block[447:416] = pin_input[31:0];
                prep_block[415:408] = 8'h80;
                prep_block[63:0]    = 64'd96;
            end

            // Default to 8-digit PIN format
            default: begin
                prep_block[447:416] = pin_input[31:0];
                prep_block[415:408] = 8'h80;
                prep_block[63:0]    = 64'd96;
            end

        endcase

    end

    // ============================================================
    // CURRENT MESSAGE SCHEDULE WORD
    // ============================================================

    reg [31:0] w_current;
    reg [31:0] temp1_current;
    reg [31:0] temp2_current;

    reg [31:0] a_next;
    reg [31:0] b_next;
    reg [31:0] c_next;
    reg [31:0] d_next;
    reg [31:0] e_next;
    reg [31:0] f_next;
    reg [31:0] g_next;
    reg [31:0] h_next;

    always @* begin

        // First 16 message schedule words
        case (round_cnt)

            7'd0:  w_current = msg_block[511:480];
            7'd1:  w_current = msg_block[479:448];
            7'd2:  w_current = msg_block[447:416];
            7'd3:  w_current = msg_block[415:384];
            7'd4:  w_current = msg_block[383:352];
            7'd5:  w_current = msg_block[351:320];
            7'd6:  w_current = msg_block[319:288];
            7'd7:  w_current = msg_block[287:256];
            7'd8:  w_current = msg_block[255:224];
            7'd9:  w_current = msg_block[223:192];
            7'd10: w_current = msg_block[191:160];
            7'd11: w_current = msg_block[159:128];
            7'd12: w_current = msg_block[127:96];
            7'd13: w_current = msg_block[95:64];
            7'd14: w_current = msg_block[63:32];
            7'd15: w_current = msg_block[31:0];

            default: begin
                w_current =
                    sigma1(w[round_cnt - 7'd2]) +
                    w[round_cnt - 7'd7] +
                    sigma0(w[round_cnt - 7'd15]) +
                    w[round_cnt - 7'd16];
            end

        endcase

        // SHA-256 temporary values
        temp1_current =
            h +
            Sigma1(e) +
            Ch(e, f, g) +
            K(round_cnt) +
            w_current;

        temp2_current =
            Sigma0(a) +
            Maj(a, b, c);

        // Next working variables
        h_next = g;
        g_next = f;
        f_next = e;
        e_next = d + temp1_current;
        d_next = c;
        c_next = b;
        b_next = a;
        a_next = temp1_current + temp2_current;

    end

    // ============================================================
    // STATE REGISTER
    // ============================================================

    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin
            state <= IDLE;
        end
        else begin
            state <= next_state;
        end

    end

    // ============================================================
    // NEXT STATE LOGIC
    // ============================================================

    always @* begin

        next_state = state;

        case (state)

            IDLE: begin
                if (start)
                    next_state = PREP;
            end

            PREP: begin
                next_state = COMPUTE;
            end

            COMPUTE: begin
                if (round_cnt == 7'd63)
                    next_state = FINALIZE;
            end

            FINALIZE: begin
                next_state = DONE;
            end

            DONE: begin
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end

        endcase

    end

    // ============================================================
    // MAIN SHA-256 PROCESS
    // ============================================================

    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            round_cnt  <= 7'd0;
            msg_block  <= 512'd0;
            hash_state <= 256'd0;

            a <= 32'd0;
            b <= 32'd0;
            c <= 32'd0;
            d <= 32'd0;
            e <= 32'd0;
            f <= 32'd0;
            g <= 32'd0;
            h <= 32'd0;

            pin_hash <= 128'd0;
            valid    <= 1'b0;

        end
        else begin

            // Default: valid is a one-clock pulse
            valid <= 1'b0;

            case (state)

                // ------------------------------------------------
                // IDLE
                // ------------------------------------------------

                IDLE: begin
                    round_cnt <= 7'd0;
                end

                // ------------------------------------------------
                // PREPARE MESSAGE
                // ------------------------------------------------

                PREP: begin

                    // Load prepared message
                    msg_block <= prep_block;

                    // Initialize SHA-256 state
                    hash_state <= SHA256_IV;

                    a <= SHA256_IV[255:224];
                    b <= SHA256_IV[223:192];
                    c <= SHA256_IV[191:160];
                    d <= SHA256_IV[159:128];
                    e <= SHA256_IV[127:96];
                    f <= SHA256_IV[95:64];
                    g <= SHA256_IV[63:32];
                    h <= SHA256_IV[31:0];

                    round_cnt <= 7'd0;

                end

                // ------------------------------------------------
                // 64 SHA-256 ROUNDS
                // ------------------------------------------------

                COMPUTE: begin

                    // Store current message schedule word
                    w[round_cnt] <= w_current;

                    // Update working variables
                    a <= a_next;
                    b <= b_next;
                    c <= c_next;
                    d <= d_next;
                    e <= e_next;
                    f <= f_next;
                    g <= g_next;
                    h <= h_next;

                    if (round_cnt == 7'd63) begin

                        // FIX: SHA-256 finalization requires EIGHT independent
                        // 32-bit additions (mod 2^32 each, no carry crossing
                        // between words) -- not one 256-bit addition, which lets
                        // carries from low words corrupt high words.
                        hash_state[255:224] <= hash_state[255:224] + a_next;
                        hash_state[223:192] <= hash_state[223:192] + b_next;
                        hash_state[191:160] <= hash_state[191:160] + c_next;
                        hash_state[159:128] <= hash_state[159:128] + d_next;
                        hash_state[127:96]  <= hash_state[127:96]  + e_next;
                        hash_state[95:64]   <= hash_state[95:64]   + f_next;
                        hash_state[63:32]   <= hash_state[63:32]   + g_next;
                        hash_state[31:0]    <= hash_state[31:0]    + h_next;

                    end
                    else begin

                        round_cnt <= round_cnt + 7'd1;

                    end

                end

                // ------------------------------------------------
                // OUTPUT 128-BIT TRUNCATED SHA-256
                // ------------------------------------------------

                FINALIZE: begin

                    // 32 bits is plenty against a 4-8 digit PIN space (10^4-10^8
                    // possibilities) while keeping the stored field compact.
                    pin_hash <= hash_state[255:224];

                end

                // ------------------------------------------------
                // DONE
                // ------------------------------------------------

                DONE: begin

                    valid <= 1'b1;

                end

                default: begin
                    round_cnt <= 7'd0;
                end

            endcase

        end

    end

endmodule