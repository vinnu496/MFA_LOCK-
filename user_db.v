`timescale 1ns / 1ps
//=====================================================================
// user_db.v
// Writable user database. 6 slots (1 admin + 5 guests, per team decision).
// Typed individual fields, not a packed bus -- this is what admin_menu_fsm.v
// and nfc_interface.v are built against.
//
// pin_hash widened from 16 -> 32 bits: this is the field that actually
// has to hold pin_hash.v's real SHA-256-derived output. A packed-128-bit-
// per-record design (as an alternate version of this file explored)
// cannot fit a real hash alongside every other field in 128 bits total --
// that's why this module keeps each field as its own typed port instead
// of one packed word.
//=====================================================================

module user_db #(
    parameter NUM_USERS = 6
)(
    input  wire        clk,
    input  wire        rst,          // synchronous, active high

    // ---- Command interface ----
    input  wire        cmd_valid,    // pulse high for 1 cycle to issue a command
    input  wire [1:0]  cmd,          // 00=SEARCH, 01=ADD, 10=REMOVE, 11=EDIT
    output reg         busy,
    output reg         done,         // pulses high 1 cycle when result is ready
    output reg         result_ok,

    // ---- Search input ----
    input  wire [31:0] search_nfc_uid,
    input  wire [31:0] search_pin_hash,
    input  wire        search_by_id,
    input  wire [7:0]  search_user_id,

    // ---- Record fields (ADD / EDIT input, and SEARCH output) ----
    input  wire [7:0]  in_user_id,
    input  wire        in_is_admin,
    input  wire [3:0]  in_factor_req,    // bit0=NFC bit1=PIN bit2=OTP bit3=BIO
    input  wire [31:0] in_pin_hash,      // truncated SHA-256, from pin_hash.v
    input  wire [31:0] in_nfc_uid,
    input  wire [15:0] in_otp_seed,
    input  wire [7:0]  in_bio_template_id,

    output reg  [7:0]  out_user_id,
    output reg         out_valid,
    output reg         out_is_admin,
    output reg  [3:0]  out_factor_req,
    output reg  [31:0] out_pin_hash,
    output reg  [31:0] out_nfc_uid,
    output reg  [15:0] out_otp_seed,
    output reg  [7:0]  out_bio_template_id
);

    localparam CMD_SEARCH = 2'b00;
    localparam CMD_ADD    = 2'b01;
    localparam CMD_REMOVE = 2'b10;
    localparam CMD_EDIT   = 2'b11;

    reg               valid_mem       [0:NUM_USERS-1];
    reg               is_admin_mem    [0:NUM_USERS-1];
    reg  [3:0]        factor_req_mem  [0:NUM_USERS-1];
    reg  [31:0]        pin_hash_mem    [0:NUM_USERS-1];
    reg  [31:0]        nfc_uid_mem     [0:NUM_USERS-1];
    reg  [15:0]        otp_seed_mem    [0:NUM_USERS-1];
    reg  [7:0]         bio_id_mem      [0:NUM_USERS-1];

    integer i;
    reg [7:0] found_idx;
    reg       found;

    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < NUM_USERS; i = i + 1) begin
                valid_mem[i]      <= 1'b0;
                is_admin_mem[i]   <= 1'b0;
                factor_req_mem[i] <= 4'b0000;
                pin_hash_mem[i]   <= 32'h0;
                nfc_uid_mem[i]    <= 32'h0;
                otp_seed_mem[i]   <= 16'h0000;
                bio_id_mem[i]     <= 8'h00;
            end
            busy      <= 1'b0;
            done      <= 1'b0;
            result_ok <= 1'b0;
            out_user_id <= 8'h00;
            out_valid   <= 1'b0;
            out_is_admin <= 1'b0;
            out_factor_req <= 4'b0000;
            out_pin_hash   <= 32'h0;
            out_nfc_uid    <= 32'h0;
            out_otp_seed   <= 16'h0000;
            out_bio_template_id <= 8'h00;
        end else begin
            done <= 1'b0;

            if (cmd_valid && !busy) begin
                case (cmd)
                    CMD_SEARCH: begin
                        found     = 1'b0;
                        found_idx = 8'hFF;
                        if (search_by_id) begin
                            if (search_user_id < NUM_USERS && valid_mem[search_user_id]) begin
                                found     = 1'b1;
                                found_idx = search_user_id;
                            end
                        end else begin
                            for (i = 0; i < NUM_USERS; i = i + 1) begin
                                if (valid_mem[i] &&
                                    ((search_nfc_uid  != 32'h0 && nfc_uid_mem[i]  == search_nfc_uid) ||
                                     (search_pin_hash != 32'h0 && pin_hash_mem[i] == search_pin_hash))) begin
                                    found     = 1'b1;
                                    found_idx = i[7:0];
                                end
                            end
                        end

                        result_ok <= found;
                        if (found) begin
                            out_user_id          <= found_idx;
                            out_valid            <= valid_mem[found_idx];
                            out_is_admin         <= is_admin_mem[found_idx];
                            out_factor_req       <= factor_req_mem[found_idx];
                            out_pin_hash         <= pin_hash_mem[found_idx];
                            out_nfc_uid          <= nfc_uid_mem[found_idx];
                            out_otp_seed         <= otp_seed_mem[found_idx];
                            out_bio_template_id  <= bio_id_mem[found_idx];
                        end else begin
                            out_valid <= 1'b0;
                        end
                        done <= 1'b1;
                    end

                    CMD_ADD: begin
                        if (in_user_id < NUM_USERS && !valid_mem[in_user_id]) begin
                            valid_mem[in_user_id]      <= 1'b1;
                            is_admin_mem[in_user_id]   <= in_is_admin;
                            factor_req_mem[in_user_id] <= in_factor_req;
                            pin_hash_mem[in_user_id]   <= in_pin_hash;
                            nfc_uid_mem[in_user_id]    <= in_nfc_uid;
                            otp_seed_mem[in_user_id]   <= in_otp_seed;
                            bio_id_mem[in_user_id]     <= in_bio_template_id;
                            result_ok <= 1'b1;
                        end else begin
                            result_ok <= 1'b0;
                        end
                        done <= 1'b1;
                    end

                    CMD_REMOVE: begin
                        if (in_user_id < NUM_USERS && valid_mem[in_user_id]) begin
                            valid_mem[in_user_id]      <= 1'b0;
                            is_admin_mem[in_user_id]   <= 1'b0;
                            factor_req_mem[in_user_id] <= 4'b0000;
                            pin_hash_mem[in_user_id]   <= 32'h0;
                            nfc_uid_mem[in_user_id]    <= 32'h0;
                            otp_seed_mem[in_user_id]   <= 16'h0000;
                            bio_id_mem[in_user_id]     <= 8'h00;
                            result_ok <= 1'b1;
                        end else begin
                            result_ok <= 1'b0;
                        end
                        done <= 1'b1;
                    end

                    CMD_EDIT: begin
                        if (in_user_id < NUM_USERS && valid_mem[in_user_id]) begin
                            is_admin_mem[in_user_id]   <= in_is_admin;
                            factor_req_mem[in_user_id] <= in_factor_req;
                            pin_hash_mem[in_user_id]   <= in_pin_hash;
                            nfc_uid_mem[in_user_id]    <= in_nfc_uid;
                            otp_seed_mem[in_user_id]   <= in_otp_seed;
                            bio_id_mem[in_user_id]     <= in_bio_template_id;
                            result_ok <= 1'b1;
                        end else begin
                            result_ok <= 1'b0;
                        end
                        done <= 1'b1;
                    end
                endcase
            end
        end
    end

endmodule