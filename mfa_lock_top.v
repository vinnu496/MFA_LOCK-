`timescale 1ns / 1ps

module mfa_lock_top #(
    parameter CLK_FREQ_HZ     = 100_000_000,
    parameter BAUD_RATE       = 115200,
    parameter LOCKOUT_SECONDS = 30,
    parameter MAX_ATTEMPTS    = 4'd5
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [3:0]  keypad_col,
    output wire [3:0]  keypad_row,
    input  wire        nfc_uart_rx_in,
    input  wire        bio_uart_rx_in,
    input  wire        otp_uart_rx_in,
    output wire        uart_tx_out,
    output wire [1:0]  led_green,
    output wire [1:0]  led_red,
    output wire        buzzer,
    output wire        solenoid,
    output wire [3:0]  fsm_state,
    output wire [3:0]  factor_status
);

    localparam BAUD_DIV = CLK_FREQ_HZ / BAUD_RATE;
    localparam KEY_HASH = 4'd14;
    localparam KEY_STAR = 4'd13;
    reg [15:0] baud_cnt;
    wire baud_tick;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            baud_cnt <= 16'd0;
        else if (baud_cnt == BAUD_DIV - 1)
            baud_cnt <= 16'd0;
        else
            baud_cnt <= baud_cnt + 16'd1;
    end
    assign baud_tick = (baud_cnt == BAUD_DIV - 1);

    wire [3:0] key_code;
    wire key_valid;
    keypad_scanner keypad_inst (
        .clk(clk), .rst_n(rst_n), .col_in(keypad_col), .row_out(keypad_row),
        .key_code(key_code), .key_valid(key_valid)
    );

    wire [7:0] nfc_rx_data;
    wire nfc_rx_valid;
    wire [7:0] bio_rx_data;
    wire bio_rx_valid;
    wire [7:0] otp_rx_data;
    wire otp_rx_valid;
    uart_rx #(.CLKS_PER_BIT(BAUD_DIV)) nfc_uart_inst (
        .clk(clk), .rst_n(rst_n), .rx(nfc_uart_rx_in), .tick(baud_tick),
        .d_out(nfc_rx_data), .d_valid(nfc_rx_valid)
    );
    uart_rx #(.CLKS_PER_BIT(BAUD_DIV)) bio_uart_inst (
        .clk(clk), .rst_n(rst_n), .rx(bio_uart_rx_in), .tick(baud_tick),
        .d_out(bio_rx_data), .d_valid(bio_rx_valid)
    );
    uart_rx #(.CLKS_PER_BIT(BAUD_DIV)) otp_uart_inst (
        .clk(clk), .rst_n(rst_n), .rx(otp_uart_rx_in), .tick(baud_tick),
        .d_out(otp_rx_data), .d_valid(otp_rx_valid)
    );
    assign uart_tx_out = 1'b1;

    wire login_start;
    wire factor_valid_top;
    wire factor_pass_top;
    wire [1:0] factor_type_top;
    wire factor_accepted;
    wire all_factors_done_now;
    wire max_attempts_reached_w;
    wire lockout_expired_w;
    wire solenoid_done_w;
    wire admin_exit_w;
    wire admin_reset_w;
    wire session_active;
    wire session_start;
    wire denial_pulse;
    wire attempt_increment;
    wire lockout_start;
    wire unlock_request;
    wire admin_menu_active;
    wire lockout_active;

    wire [7:0] out_user_id;
    wire out_valid;
    wire out_is_admin;
    wire [3:0] out_factor_req;
    wire [31:0] out_pin_hash;
    wire [31:0] out_nfc_uid;
    wire [15:0] out_otp_seed;
    wire [7:0] out_bio_template_id;

    access_control_fsm fsm_inst (
        .clk(clk), .rst_n(rst_n), .login_start(login_start),
        .factor_valid(factor_valid_top), .factor_pass(factor_pass_top),
        .factor_accepted(factor_accepted), .all_factors_done_now(all_factors_done_now),
        .user_is_admin(out_is_admin), .max_attempts_reached(max_attempts_reached_w),
        .lockout_expired(lockout_expired_w), .solenoid_done(solenoid_done_w),
        .admin_exit(admin_exit_w), .admin_reset(admin_reset_w),
        .session_active(session_active), .session_start(session_start),
        .denial_pulse(denial_pulse), .attempt_increment(attempt_increment),
        .lockout_start(lockout_start), .unlock_request(unlock_request),
        .admin_menu(admin_menu_active), .lockout(lockout_active), .state(fsm_state)
    );

    assign login_start = key_valid | nfc_rx_valid | bio_rx_valid | otp_rx_valid;

    wire nfc_match;
    wire nfc_checked;
    wire [31:0] nfc_uid_rx;
    nfc_interface nfc_inst (
        .clk(clk), .rst_n(rst_n), .rx_valid(nfc_rx_valid), .rx_data(nfc_rx_data),
        .stored_nfc_uid(out_nfc_uid), .nfc_match(nfc_match),
        .nfc_checked(nfc_checked), .nfc_uid_rx(nfc_uid_rx)
    );

    wire bio_pass;
    wire bio_checked;
    wire [7:0] bio_template_id_w;
    biometric_interface bio_inst (
        .clk(clk), .rst_n(rst_n), .rx_valid(bio_rx_valid), .rx_data(bio_rx_data),
        .bio_pass(bio_pass), .bio_checked(bio_checked), .bio_template_id(bio_template_id_w)
    );

    wire otp_match;
    wire otp_valid;
    otp_check otp_inst (
        .clk(clk), .rst_n(rst_n), .start(session_active),
        .rx_valid(otp_rx_valid), .rx_data(otp_rx_data), .otp_seed(out_otp_seed),
        .otp_match(otp_match), .otp_valid(otp_valid)
    );

    reg [31:0] pin_input_reg;
    reg [7:0] pin_len_reg;
    reg pin_hash_start;
    reg pin_entry_active;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pin_input_reg <= 32'd0;
            pin_len_reg <= 8'd0;
            pin_hash_start <= 1'b0;
            pin_entry_active <= 1'b0;
        end else begin
            pin_hash_start <= 1'b0;
            if (session_start) begin
                pin_input_reg <= 32'd0;
                pin_len_reg <= 8'd0;
                pin_entry_active <= 1'b1;
            end else if (pin_entry_active && key_valid) begin
                if (key_code == KEY_HASH) begin
                    pin_hash_start <= 1'b1;
                    pin_entry_active <= 1'b0;
                end else if (pin_len_reg < 8'd8) begin
                    pin_input_reg <= {pin_input_reg[27:0], key_code};
                    pin_len_reg <= pin_len_reg + 8'd1;
                end
            end
        end
    end

    wire pin_hash_valid;
    wire [31:0] pin_hash_out;
    localparam [63:0] PIN_SALT = 64'hA5A5_5A5A_1234_5678;
    pin_hash pin_hash_inst (
        .clk(clk), .rst_n(rst_n), .start(pin_hash_start),
        .pin_input(pin_input_reg), .pin_len(pin_len_reg), .salt(PIN_SALT),
        .valid(pin_hash_valid), .pin_hash(pin_hash_out)
    );

    wire db_cmd_valid_menu;
    wire [1:0] db_cmd_menu;
    wire db_busy;
    wire db_done;
    wire db_result_ok;
    wire [7:0] db_in_user_id_menu;
    wire db_in_is_admin_menu;
    wire [3:0] db_in_factor_req_menu;
    wire [31:0] db_in_pin_hash_menu;
    wire [31:0] db_in_nfc_uid_menu;
    wire [15:0] db_in_otp_seed_menu;
    wire [7:0] db_in_bio_template_id_menu;

    reg search_pending;
    reg search_inflight;
    reg [1:0] search_factor_type;
    reg [31:0] search_nfc_uid_reg;
    reg [31:0] search_pin_hash_reg;
    reg [31:0] last_nfc_uid;
    reg search_by_id_reg;
    reg [7:0] search_user_id_reg;
    reg db_factor_valid;
    reg db_factor_pass;
    reg [1:0] db_factor_type;

    wire cmd_valid_final = db_cmd_valid_menu | search_pending;
    wire [1:0] cmd_final = db_cmd_valid_menu ? db_cmd_menu : 2'b00;
    wire [7:0] in_user_id_final = db_cmd_valid_menu ? db_in_user_id_menu : 8'd0;

    user_db #(.NUM_USERS(6)) user_db_inst (
        .clk(clk), .rst(~rst_n), .cmd_valid(cmd_valid_final), .cmd(cmd_final),
        .busy(db_busy), .done(db_done), .result_ok(db_result_ok),
        .search_nfc_uid(search_nfc_uid_reg), .search_pin_hash(search_pin_hash_reg),
        .search_by_id(search_by_id_reg), .search_user_id(search_user_id_reg),
        .in_user_id(in_user_id_final), .in_is_admin(db_in_is_admin_menu),
        .in_factor_req(db_in_factor_req_menu), .in_pin_hash(db_in_pin_hash_menu),
        .in_nfc_uid(db_in_nfc_uid_menu), .in_otp_seed(db_in_otp_seed_menu),
        .in_bio_template_id(db_in_bio_template_id_menu), .out_user_id(out_user_id),
        .out_valid(out_valid), .out_is_admin(out_is_admin), .out_factor_req(out_factor_req),
        .out_pin_hash(out_pin_hash), .out_nfc_uid(out_nfc_uid), .out_otp_seed(out_otp_seed),
        .out_bio_template_id(out_bio_template_id)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            search_pending <= 1'b0;
            search_inflight <= 1'b0;
            search_factor_type <= 2'd0;
            search_nfc_uid_reg <= 32'd0;
            search_pin_hash_reg <= 32'd0;
            last_nfc_uid <= 32'd0;
            search_by_id_reg <= 1'b0;
            search_user_id_reg <= 8'd0;
            db_factor_valid <= 1'b0;
            db_factor_pass <= 1'b0;
            db_factor_type <= 2'd0;
        end else begin
            search_pending <= 1'b0;
            db_factor_valid <= 1'b0;
            if (session_start)
                last_nfc_uid <= 32'd0;
            if (!db_busy && !search_inflight &&
                (((nfc_uid_rx != 32'd0) && (nfc_uid_rx != last_nfc_uid)) || pin_hash_valid)) begin
                search_pending <= 1'b1;
                search_inflight <= 1'b1;
                search_factor_type <= (nfc_uid_rx != last_nfc_uid) ? 2'd0 : 2'd1;
                search_nfc_uid_reg <= (nfc_uid_rx != last_nfc_uid) ? nfc_uid_rx : 32'd0;
                search_pin_hash_reg <= pin_hash_valid ? pin_hash_out : 32'd0;
                last_nfc_uid <= nfc_uid_rx;
                search_by_id_reg <= 1'b0;
            end
            if (search_inflight && db_done) begin
                search_inflight <= 1'b0;
                db_factor_valid <= 1'b1;
                db_factor_pass <= db_result_ok;
                db_factor_type <= search_factor_type;
            end
        end
    end

    reg [1:0] factor_type_top_r;
    always @* begin
        if (db_factor_valid) factor_type_top_r = db_factor_type;
        else if (otp_valid) factor_type_top_r = 2'd2;
        else factor_type_top_r = 2'd3;
    end
    assign factor_type_top = factor_type_top_r;
    assign factor_valid_top = db_factor_valid | otp_valid | bio_checked;
    assign factor_pass_top = db_factor_valid ? db_factor_pass :
                             otp_valid ? otp_match :
                             bio_checked ? bio_pass : 1'b0;

    wire [3:0] factors_seen;
    wire invalid_configuration;
    factor_match factor_match_inst (
        .clk(clk), .rst_n(rst_n), .factor_req(out_factor_req),
        .session_start(session_start), .factor_valid(factor_valid_top),
        .factor_type(factor_type_top), .factor_pass(factor_pass_top),
        .factors_seen(factors_seen), .factor_accepted(factor_accepted),
        .all_factors_done(), .all_factors_done_now(all_factors_done_now),
        .invalid_configuration(invalid_configuration)
    );
    assign factor_status = factors_seen;

    wire [3:0] attempt_count;
    wire lockout_flag_w;
    wire under_limit_w;
    attempt_counter #(.MAX_ATTEMPTS(MAX_ATTEMPTS)) attempt_counter_inst (
        .clk(clk), .rst_n(rst_n), .increment(attempt_increment),
        .clear(lockout_expired_w | admin_reset_w | solenoid_done_w),
        .count(attempt_count), .lockout_flag(lockout_flag_w), .under_limit(under_limit_w)
    );
    assign max_attempts_reached_w = lockout_flag_w;

    wire lockout_active_timer;
    wire lockout_timeout_expired;
    wire [31:0] lockout_counter_dbg;
    lockout_timer #(.CLK_FREQ_HZ(CLK_FREQ_HZ), .LOCKOUT_SECONDS(LOCKOUT_SECONDS)) lockout_timer_inst (
        .clk(clk), .rst_n(rst_n), .start(lockout_start), .enable(lockout_active),
        .clear(admin_reset_w), .active(lockout_active_timer),
        .timeout_expired(lockout_timeout_expired), .timeout_counter(lockout_counter_dbg)
    );
    assign lockout_expired_w = lockout_timeout_expired;

    wire intrusion_flag_w;
    wire rapid_fail_w;
    wire [3:0] fail_count_w;
    wire [3:0] lockout_repeat_count_w;
    intrusion_detect intrusion_inst (
        .clk(clk), .rst_n(rst_n), .lockout_flag(lockout_flag_w),
        .timeout_expired(lockout_timeout_expired), .failed_factor(denial_pulse),
        .admin_reset(admin_reset_w), .intrusion_flag(intrusion_flag_w),
        .rapid_fail(rapid_fail_w), .fail_count(fail_count_w),
        .lockout_repeat_count(lockout_repeat_count_w)
    );

    assign admin_reset_w = lockout_active && key_valid && (key_code == KEY_STAR);
    assign admin_exit_w = admin_menu_active && key_valid && (key_code == KEY_STAR);

    wire menu_action_confirm = admin_menu_active && key_valid && (key_code == KEY_HASH);
    wire [1:0] menu_action_sel = key_code[1:0];
    admin_menu_fsm admin_menu_inst (
        .clk(clk), .rst_n(rst_n), .enter_menu(admin_menu_active),
        .menu_action(menu_action_sel), .confirm_req(menu_action_confirm), .exit_req(admin_exit_w),
        .menu_in_user_id(pin_input_reg[7:0]), .menu_in_is_admin(1'b0),
        .menu_in_factor_req(pin_input_reg[3:0]), .menu_in_pin_hash(pin_input_reg),
        .menu_in_nfc_uid(pin_input_reg), .menu_in_otp_seed(pin_input_reg[15:0]),
        .menu_in_bio_template_id(pin_input_reg[7:0]), .db_cmd_valid(db_cmd_valid_menu),
        .db_cmd(db_cmd_menu), .db_busy(db_busy), .db_done(db_done), .db_result_ok(db_result_ok),
        .db_in_user_id(db_in_user_id_menu), .db_in_is_admin(db_in_is_admin_menu),
        .db_in_factor_req(db_in_factor_req_menu), .db_in_pin_hash(db_in_pin_hash_menu),
        .db_in_nfc_uid(db_in_nfc_uid_menu), .db_in_otp_seed(db_in_otp_seed_menu),
        .db_in_bio_template_id(db_in_bio_template_id_menu), .menu_active(), .menu_state(),
        .action_done(), .action_ok(), .request_exit()
    );

    solenoid_driver solenoid_inst (
        .clk(clk), .rst_n(rst_n), .unlock_pulse(unlock_request),
        .solenoid(solenoid), .unlock_done(solenoid_done_w)
    );
    buzzer_driver buzzer_inst (
        .clk(clk), .rst_n(rst_n), .deny_pulse(denial_pulse),
        .intrusion(intrusion_flag_w), .lockout(lockout_active), .mute(1'b0), .buzzer(buzzer)
    );
    led_status led_inst (
        .clk(clk), .rst_n(rst_n), .unlock_ok(unlock_request), .denial(denial_pulse),
        .lockout(lockout_active), .admin_menu(admin_menu_active),
        .led_green(led_green), .led_red(led_red)
    );

endmodule
