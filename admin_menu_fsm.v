`timescale 1ns / 1ps
//=====================================================================
// admin_menu_fsm.v (rewritten)
// - Old version had THREE separate always blocks all driving
//   current_state/next_state/wr_en/menu_active/action_done at once --
//   multiply-driven regs, would not synthesize.
// - Old write interface (wr_addr + one packed 128-bit wr_data + wr_en)
//   did not match user_db.v's actual interface at all (cmd/cmd_valid
//   plus separate typed fields: in_user_id, in_is_admin, in_factor_req,
//   in_pin_hash, in_nfc_uid, in_otp_seed, in_bio_template_id). Rewired
//   to drive user_db.v directly.
// - Old ADD_USER/REMOVE_USER always wrote to hardcoded address 0 with
//   zero data (placeholder). Now takes the target fields as inputs
//   (menu_in_*) so a real admin-entry front-end -- keypad + OLED menu,
//   still to be built -- can feed real values in.
//=====================================================================
module admin_menu_fsm (
    input  wire        clk,
    input  wire        rst_n,

    // Control inputs (from access_control_fsm.v / keypad UI)
    input  wire        enter_menu,       // level: FSM is in S_ADMIN_MENU
    input  wire  [1:0] menu_action,      // 00=ADD 01=REMOVE 10=EDIT (selected via keypad UI)
    input  wire        confirm_req,      // pulse: admin confirmed the pending action
    input  wire        exit_req,         // pulse: admin requests exit

    // Fields for the target user, supplied by the keypad/OLED admin UI
    input  wire [7:0]  menu_in_user_id,
    input  wire        menu_in_is_admin,
    input  wire [3:0]  menu_in_factor_req,
    input  wire [31:0] menu_in_pin_hash,
    input  wire [31:0] menu_in_nfc_uid,
    input  wire [15:0] menu_in_otp_seed,
    input  wire [7:0]  menu_in_bio_template_id,

    // ---- user_db.v command interface (matches user_db.v exactly) ----
    output reg          db_cmd_valid,
    output reg  [1:0]   db_cmd,          // 01=ADD 10=REMOVE 11=EDIT
    input  wire         db_busy,
    input  wire         db_done,
    input  wire         db_result_ok,
    output reg  [7:0]   db_in_user_id,
    output reg          db_in_is_admin,
    output reg  [3:0]   db_in_factor_req,
    output reg  [31:0]  db_in_pin_hash,
    output reg  [31:0]  db_in_nfc_uid,
    output reg  [15:0]  db_in_otp_seed,
    output reg  [7:0]   db_in_bio_template_id,

    // ---- Status back to access_control_fsm.v ----
    output reg          menu_active,
    output reg  [3:0]   menu_state,     // debug
    output reg          action_done,    // pulses 1 cycle when a write completes
    output reg          action_ok,      // result of the last write (valid alongside action_done)
    output reg          request_exit    // pulses when ready to leave S_ADMIN_MENU
);

    localparam MENU_IDLE    = 4'd0,
               MENU_STAGE   = 4'd1, // action selected, waiting for confirm_req
               MENU_ISSUE   = 4'd2, // db_cmd_valid pulsed, waiting for db_busy to rise
               MENU_WAIT    = 4'd3, // waiting for db_done
               MENU_DONE    = 4'd4; // 1-cycle: report result, then back to idle or exit

    reg [3:0] current_state, next_state;

    // ---- State register ----
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            current_state <= MENU_IDLE;
        else
            current_state <= next_state;
    end

    // ---- Next-state logic ----
    always @* begin
        next_state = current_state;
        case (current_state)
            MENU_IDLE: begin
                if (!enter_menu)
                    next_state = MENU_IDLE; // stay parked until FSM puts us in admin mode
                else if (confirm_req)
                    next_state = MENU_STAGE;
            end

            MENU_STAGE: begin
                if (exit_req)
                    next_state = MENU_IDLE;
                else if (confirm_req)
                    next_state = MENU_ISSUE;
            end

            MENU_ISSUE: begin
                next_state = MENU_WAIT;
            end

            MENU_WAIT: begin
                if (db_done)
                    next_state = MENU_DONE;
            end

            MENU_DONE: begin
                next_state = exit_req ? MENU_IDLE : MENU_STAGE;
            end

            default: next_state = MENU_IDLE;
        endcase
    end

    // ---- Output logic ----
    always @* begin
        db_cmd_valid          = 1'b0;
        db_cmd                = 2'b00;
        db_in_user_id          = menu_in_user_id;
        db_in_is_admin         = menu_in_is_admin;
        db_in_factor_req       = menu_in_factor_req;
        db_in_pin_hash         = menu_in_pin_hash;
        db_in_nfc_uid          = menu_in_nfc_uid;
        db_in_otp_seed         = menu_in_otp_seed;
        db_in_bio_template_id  = menu_in_bio_template_id;

        menu_active   = (current_state != MENU_IDLE);
        menu_state    = current_state;
        action_done   = 1'b0;
        action_ok     = 1'b0;
        request_exit  = 1'b0;

        case (current_state)
            MENU_ISSUE: begin
                db_cmd_valid = 1'b1;
                case (menu_action)
                    2'b00:   db_cmd = 2'b01; // ADD
                    2'b01:   db_cmd = 2'b10; // REMOVE
                    2'b10:   db_cmd = 2'b11; // EDIT
                    default: db_cmd = 2'b00; // SEARCH (no-op safeguard)
                endcase
            end
            MENU_DONE: begin
                action_done  = 1'b1;
                action_ok    = db_result_ok;
                request_exit = exit_req;
            end
            default: ;
        endcase
    end

endmodule