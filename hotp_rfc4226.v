`timescale 1ns / 1ps
//=====================================================================
// hotp_rfc4226.v (rewritten -- real implementation)
//
// Old version was a scaffold: FSM shape and constants were right, but
// SHA1_ROUND/SHA1_FINAL/TRUNCATE were all placeholders and hotp_value
// always came out 0. Separately, the HMAC key handling was wrong: HMAC
// requires the key zero-padded to a FULL 64-byte block before XORing
// with ipad/opad (RFC 2104), not XORing the raw 20-byte key with a
// 20-byte ipad constant.
//
// This version implements the real thing:
//   - Key is zero-padded to 512 bits, then XORed with 512-bit ipad/opad.
//   - Inner hash = SHA1(key_padded^ipad || counter), which is 512+64=576
//     bits of data -> requires 2 SHA-1 blocks after padding.
//   - Outer hash = SHA1(key_padded^opad || inner_hash), 512+160=672 bits
//     of data -> also 2 SHA-1 blocks after padding.
//   - Standard Merkle-Damgard chaining across blocks within each phase,
//     with the running hash state (h0..h4) starting fresh at SHA1_IV
//     for the inner phase and again for the outer phase.
//   - Real 80-round SHA-1 compression: message schedule extension via
//     ROTL1, correct f/K selection per round range, and the finalization
//     add done as 5 INDEPENDENT 32-bit additions (not one 160-bit add --
//     same class of bug fixed in pin_hash.v).
//   - Real RFC 4226 dynamic truncation and mod-1,000,000.
//
// Verify against RFC 4226's own test vector before trusting this in a
// demo: secret_key = ASCII "12345678901234567890" (20 bytes) zero-
// extended into the 160-bit secret_key port, counter = 0 -> expected
// HOTP = 755224. Counter = 1 -> 287082, counter = 2 -> 359152, etc.
// (RFC 4226 Appendix D has the full 0-9 table.)
//=====================================================================
module hotp_rfc4226 (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        start,
    input  wire [63:0] counter,       // 8-byte counter, big-endian value
    input  wire [159:0] secret_key,   // 160-bit (20-byte) secret key

    output reg         valid,
    output reg  [19:0] hotp_value     // 6-digit HOTP, 0-999999
);

    localparam S_IDLE       = 3'd0,
               S_BLOCK_INIT = 3'd1, // load W[0..15] source for this block, set up a..e
               S_ROUND      = 3'd2, // 80 rounds of compression
               S_BLOCK_DONE = 3'd3, // chain a..e into h0..h4
               S_TRUNCATE   = 3'd4,
               S_DONE       = 3'd5;

    reg [2:0] state, next_state;
    reg [6:0] round_cnt;   // 0-79
    reg       block_idx;   // 0 = first block of this phase, 1 = second
    reg       phase;       // 0 = inner hash, 1 = outer hash

    reg [31:0] w [0:79];
    reg [31:0] a, b, c, d, e;
    reg [31:0] h0, h1, h2, h3, h4; // chaining state, carried across blocks within a phase

    reg [159:0] inner_hash_reg;
    reg [159:0] outer_hash_reg;

    // ---- SHA-1 constants ----
    localparam [31:0] K0 = 32'h5A827999; // rounds 0-19
    localparam [31:0] K1 = 32'h6ED9EBA1; // rounds 20-39
    localparam [31:0] K2 = 32'h8F1BBCDC; // rounds 40-59
    localparam [31:0] K3 = 32'hCA62C1D6; // rounds 60-79

    localparam [31:0] H0_IV = 32'h67452301;
    localparam [31:0] H1_IV = 32'hEFCDAB89;
    localparam [31:0] H2_IV = 32'h98BADCFE;
    localparam [31:0] H3_IV = 32'h10325476;
    localparam [31:0] H4_IV = 32'hC3D2E1F0;

    // ---- HMAC key padding (RFC 2104): zero-pad 160-bit key to a full 512-bit block ----
    localparam [511:0] IPAD_512 = {64{8'h36}};
    localparam [511:0] OPAD_512 = {64{8'h5c}};
    wire [511:0] key_padded    = {secret_key, 352'd0};
    wire [511:0] key_ipad_blk  = key_padded ^ IPAD_512;
    wire [511:0] key_opad_blk  = key_padded ^ OPAD_512;

    // ---- Second blocks (message + SHA-1 padding), built once inputs are known ----
    // Inner message = key_ipad_blk(512) || counter(64) = 576 bits total.
    wire [511:0] inner_block2 = {counter, 8'h80, 376'd0, 64'd576};
    // Outer message = key_opad_blk(512) || inner_hash(160) = 672 bits total.
    wire [511:0] outer_block2 = {inner_hash_reg, 8'h80, 280'd0, 64'd672};

    // ---- Select the 512-bit block currently being compressed ----
    wire [511:0] current_block = (phase == 1'b0 && block_idx == 1'b0) ? key_ipad_blk  :
                                  (phase == 1'b0 && block_idx == 1'b1) ? inner_block2  :
                                  (phase == 1'b1 && block_idx == 1'b0) ? key_opad_blk  :
                                                                           outer_block2;
    wire [3:0]  trunc_offset = outer_hash_reg[3:0];
    wire [31:0] trunc_bytes  = outer_hash_reg[(159 - 8*trunc_offset) -: 32];
    wire [31:0] trunc_binary = trunc_bytes & 32'h7FFFFFFF;

    // ---- Rotate helpers ----
    function [31:0] ROTL1;  input [31:0] x; ROTL1  = (x << 1)  | (x >> 31); endfunction
    function [31:0] ROTL5;  input [31:0] x; ROTL5  = (x << 5)  | (x >> 27); endfunction
    function [31:0] ROTL30; input [31:0] x; ROTL30 = (x << 30) | (x >> 2);  endfunction

    // ---- Message schedule word for the current round (combinational) ----
    reg [31:0] w_current;
    always @* begin
        if (round_cnt < 7'd16) begin
            case (round_cnt)
                7'd0:  w_current = current_block[511:480];
                7'd1:  w_current = current_block[479:448];
                7'd2:  w_current = current_block[447:416];
                7'd3:  w_current = current_block[415:384];
                7'd4:  w_current = current_block[383:352];
                7'd5:  w_current = current_block[351:320];
                7'd6:  w_current = current_block[319:288];
                7'd7:  w_current = current_block[287:256];
                7'd8:  w_current = current_block[255:224];
                7'd9:  w_current = current_block[223:192];
                7'd10: w_current = current_block[191:160];
                7'd11: w_current = current_block[159:128];
                7'd12: w_current = current_block[127:96];
                7'd13: w_current = current_block[95:64];
                7'd14: w_current = current_block[63:32];
                default: w_current = current_block[31:0]; // 15
            endcase
        end else begin
            w_current = ROTL1(w[round_cnt-7'd3] ^ w[round_cnt-7'd8] ^ w[round_cnt-7'd14] ^ w[round_cnt-7'd16]);
        end
    end

    // ---- f/K selection and working-variable update (combinational) ----
    reg [31:0] f_val, k_val, temp_val;
    reg [31:0] a_next, b_next, c_next, d_next, e_next;
    always @* begin
        if (round_cnt < 7'd20) begin
            f_val = (b & c) | ((~b) & d);
            k_val = K0;
        end else if (round_cnt < 7'd40) begin
            f_val = b ^ c ^ d;
            k_val = K1;
        end else if (round_cnt < 7'd60) begin
            f_val = (b & c) | (b & d) | (c & d);
            k_val = K2;
        end else begin
            f_val = b ^ c ^ d;
            k_val = K3;
        end

        temp_val = ROTL5(a) + f_val + e + k_val + w_current;

        a_next = temp_val;
        b_next = a;
        c_next = ROTL30(b);
        d_next = c;
        e_next = d;
    end

    // ---- State register ----
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= S_IDLE;
        else        state <= next_state;
    end

    // ---- Next-state logic ----
    always @* begin
        next_state = state;
        case (state)
            S_IDLE:       next_state = start ? S_BLOCK_INIT : S_IDLE;
            S_BLOCK_INIT: next_state = S_ROUND;
            S_ROUND:      next_state = (round_cnt == 7'd79) ? S_BLOCK_DONE : S_ROUND;
            S_BLOCK_DONE: begin
                if (block_idx == 1'b0)
                    next_state = S_BLOCK_INIT; // more blocks left in this phase
                else if (phase == 1'b0)
                    next_state = S_BLOCK_INIT; // inner phase done, start outer phase
                else
                    next_state = S_TRUNCATE;   // outer phase done -> have full HMAC
            end
            S_TRUNCATE: next_state = S_DONE;
            S_DONE:     next_state = S_IDLE;
            default:    next_state = S_IDLE;
        endcase
    end

    // ---- Main datapath ----
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            round_cnt      <= 7'd0;
            block_idx      <= 1'b0;
            phase          <= 1'b0;
            a <= 32'd0; b <= 32'd0; c <= 32'd0; d <= 32'd0; e <= 32'd0;
            h0 <= 32'd0; h1 <= 32'd0; h2 <= 32'd0; h3 <= 32'd0; h4 <= 32'd0;
            inner_hash_reg <= 160'd0;
            outer_hash_reg <= 160'd0;
            hotp_value     <= 20'd0;
            valid          <= 1'b0;
        end else begin
            valid <= 1'b0; // default; only S_DONE pulses it

            case (state)
                S_IDLE: begin
                    if (start) begin
                        phase     <= 1'b0;
                        block_idx <= 1'b0;
                        round_cnt <= 7'd0;
                        h0 <= H0_IV; h1 <= H1_IV; h2 <= H2_IV; h3 <= H3_IV; h4 <= H4_IV;
                    end
                end

                S_BLOCK_INIT: begin
                    // Start this block's compression from the current chaining state
                    a <= h0; b <= h1; c <= h2; d <= h3; e <= h4;
                    round_cnt <= 7'd0;
                end

                S_ROUND: begin
                    w[round_cnt] <= w_current;
                    a <= a_next; b <= b_next; c <= c_next; d <= d_next; e <= e_next;
                    round_cnt <= round_cnt + 7'd1;
                end

                S_BLOCK_DONE: begin
                    // NOTE: a/b/c/d/e already hold round 79's finalized result here
                    // (they were updated on the clock edge that moved us from
                    // S_ROUND into this state) -- use them directly, NOT
                    // a_next/b_next/etc, which would recompute a bogus "round 80"
                    // using whatever round_cnt currently is.
                    //
                    // FIX (same class as pin_hash.v): 5 independent 32-bit adds,
                    // not one 160-bit add.
                    h0 <= h0 + a;
                    h1 <= h1 + b;
                    h2 <= h2 + c;
                    h3 <= h3 + d;
                    h4 <= h4 + e;

                    if (block_idx == 1'b0) begin
                        block_idx <= 1'b1; // move to this phase's 2nd block, keep chaining state
                    end else if (phase == 1'b0) begin
                        // Inner phase complete -- stash result, start outer phase fresh
                        inner_hash_reg <= {h0 + a, h1 + b, h2 + c, h3 + d, h4 + e};
                        phase          <= 1'b1;
                        block_idx      <= 1'b0;
                        h0 <= H0_IV; h1 <= H1_IV; h2 <= H2_IV; h3 <= H3_IV; h4 <= H4_IV;
                    end else begin
                        // Outer phase complete -- this is the final HMAC-SHA1 result
                        outer_hash_reg <= {h0 + a, h1 + b, h2 + c, h3 + d, h4 + e};
                    end
                end

                S_TRUNCATE: begin
                    // RFC 4226 dynamic truncation: low nibble of the last byte selects
                    // a 4-byte window; mask off the top bit; mod 10^6 for 6 digits.
                    hotp_value <= trunc_binary % 32'd1_000_000;
                end

                S_DONE: begin
                    valid <= 1'b1;
                end

                default: ;
            endcase
        end
    end

endmodule
