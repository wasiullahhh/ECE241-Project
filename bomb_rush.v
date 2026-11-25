// ============================================================================
// Bomb Rush - top level (bomb_rush). It connects main_game_fsm, countdown_timer, key_pulse,
//            seg7 (HEX decoder), the five mini-games, keyboard_input and vga_display. LED outputs
//            are driven here too. Also needs the course vga_adapter and PS2_Controller files.
//
// Formatting note: Verilog uses "begin ... end" where C uses "{ ... }".
// (In Verilog, { } means "join signals together", e.g. {5{done_p}}.)
//
// Board controls (DE1-SoC):
//   KEY[0] = reset (active low)
//   SW[6:0] = the answer for game 1 (decimal to binary), SW[0] is the least significant bit
//   KEY[1] / KEY[2] / KEY[3] = buttons 1 / 2 / 3 in game 2 (memory match)
//   PS/2 keyboard (keyboard_input.v):
//     Enter     = start the game (on HOME); submit a guess in game 5
//     1 / 2 / 3 = difficulty on HOME: 1 = HARD (1 min), 2 = MEDIUM (2 min), 3 = EASY (3 min);
//                 also buttons 1 / 2 / 3 in game 2
//     Space     = game 3 (reaction test)
//     Arrow keys = move the cube in game 4 (maze)
//     0-9, Backspace = type a guess in game 5 (crack the code)
//     R         = restart (on WIN / LOSE, back to HOME)
//
// Outputs:
//   HEX5 = current game (1-5, blank otherwise)   HEX3:HEX2:HEX1 = minutes : tens : ones of seconds
//   (in HOME the selected difficulty is shown as M:00)   HEX4 = off
//   HEX0 = game 2: the digit being flashed / game 3: hits so far / game 5: number of guesses (blank otherwise)
//   LEDR[4:0] = progress bar (one LED per solved game)
//   LEDR[6] / LEDR[5] = game 5 hint: go higher / go lower
//   LEDR[7] = timer running, LEDR[8] = LOSE, LEDR[9] = WIN
//   VGA = every screen (drawn by vga_display.v + vga_games.v; needs the course vga_adapter files
//         + black_160_9.mif)
//
// CLK_PER_SEC = clock cycles per second. 50,000,000 for the board.
// Use a small value (e.g. 4) in ModelSim and something like 1000-100000 in DESim.
// If DESim's top.v connects the ports by position, reorder the port list of bomb_rush to match it.
// ============================================================================

module bomb_rush (CLOCK_50, SW, KEY, LEDR, HEX0, HEX1, HEX2, HEX3, HEX4, HEX5,
                  VGA_R, VGA_G, VGA_B, VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK,
                  PS2_CLK, PS2_DAT);
    parameter CLK_PER_SEC = 50_000_000;

    input        CLOCK_50;
    input  [9:0] SW;
    input  [3:0] KEY;
    output [9:0] LEDR;
    output [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;
    output [7:0] VGA_R, VGA_G, VGA_B;
    output       VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK;
    inout        PS2_CLK, PS2_DAT;       // PS/2 keyboard

    wire clock  = CLOCK_50;
    wire resetn = KEY[0];

    // ---------------- key presses -> one-cycle pulses ----------------
    // Pushbuttons KEY[1..3] are the three buttons of game 2 (memory match).
    wire btn1_p, btn2_p, btn3_p;
    key_pulse K1 (clock, resetn, KEY[1], btn1_p);
    key_pulse K2 (clock, resetn, KEY[2], btn2_p);
    key_pulse K3 (clock, resetn, KEY[3], btn3_p);

    wire start_p, restart_p, key1_p, key2_p, key3_p;      // Enter, R, 1, 2, 3
    wire up_p, down_p, left_p, right_p;                   // arrow keys (game 4)
    wire space_p, bksp_p, digit_p;                        // Space (game 3), Backspace / digits (game 5)
    wire [3:0] digit_val;
    keyboard_input KB (clock, resetn, PS2_CLK, PS2_DAT, start_p, restart_p, key1_p, key2_p, key3_p,
                       up_p, down_p, left_p, right_p, space_p, bksp_p, digit_p, digit_val);

    // ---------------- main game FSM ----------------
    wire [4:0] active;
    wire [2:0] current_game, games_done;
    wire       timer_run, timer_load, win, lose, home, time_up;

    // ---------------- mini-games ----------------
    // Each game resets itself while its active bit is 0 and raises its done bit when solved.
    // (The FSM only looks at the done bit of the game that is active.)

    // Game 1 (decimal to binary): SW[6:0] must equal the number shown on the VGA screen.
    wire       g1_done;
    wire [6:0] g1_target;      // the decimal number game 1 asks for (1-100)
    game1_binary G1 (clock, resetn, active[0], SW[6:0], g1_done, g1_target);

    // Game 2 (memory match): repeat the flashed digits with KEY[1..3] or keyboard 1 / 2 / 3.
    wire       g2_done;
    wire [2:0] g2_phase, g2_count, g2_len;
    wire [1:0] g2_digit;
    game2_memory #(CLK_PER_SEC) G2 (clock, resetn, active[1],
                                    btn1_p | key1_p, btn2_p | key2_p, btn3_p | key3_p,
                                    g2_done, g2_phase, g2_digit, g2_count, g2_len);

    // Game 3 (reaction test): press Space while the marker is in the green zone, 3 times in a row.
    wire       g3_done;
    wire [7:0] g3_pos, g3_zlo, g3_zhi;
    wire [1:0] g3_hits, g3_flash;
    game3_reaction #(CLK_PER_SEC) G3 (clock, resetn, active[2], space_p,
                                      g3_done, g3_pos, g3_zlo, g3_zhi, g3_hits, g3_flash);

    // Game 4 (maze): arrow keys move the cube, reaching the exit solves it.
    wire       g4_done;
    wire [3:0] g4_x;           // cube position, shown on the VGA screen
    wire [3:0] g4_y;
    game4_maze G4 (clock, resetn, active[3], up_p, down_p, left_p, right_p, g4_x, g4_y, g4_done);

    // Game 5 (crack the code): type guesses 1-99, the screen says higher / lower.
    wire       g5_done;
    wire [3:0] g5_d1, g5_d0, g5_tries;
    wire [1:0] g5_ndig, g5_hint;
    wire [6:0] g5_last;
    game5_guess G5 (clock, resetn, active[4], digit_p, digit_val, bksp_p, start_p,
                    g5_done, g5_d1, g5_d0, g5_ndig, g5_hint, g5_last, g5_tries);

    wire [4:0] done = {g5_done, g4_done, g3_done, g2_done, g1_done};

    main_game_fsm FSM (clock, resetn, start_p, done, time_up, restart_p,
                       active, current_game, games_done, timer_run, timer_load,
                       win, lose, home);

    // Difficulty (set with keys 1/2/3 while on HOME): 01 = 1 min (hard), 10 = 2 min (medium),
    // 11 = 3 min (easy). Starts on MEDIUM after a reset.
    reg [1:0] difficulty;
    always @(posedge clock) begin
        if (!resetn) begin
            difficulty <= 2'b10;
        end else if (home) begin
            if (key1_p) begin
                difficulty <= 2'b01;
            end else if (key2_p) begin
                difficulty <= 2'b10;
            end else if (key3_p) begin
                difficulty <= 2'b11;
            end
        end
    end

    // ---------------- countdown timer ----------------
    wire [3:0] t_min, t_tens, t_ones;
    countdown_timer #(CLK_PER_SEC) TMR (clock, resetn, timer_load, timer_run, difficulty,
                                        t_min, t_tens, t_ones, time_up);

    // ---------------- HEX displays ----------------
    // In HOME show the selected difficulty (M:00); otherwise show the timer.
    reg [3:0] sel_min;
    always @(*) begin
        if (difficulty == 2'b11) begin
            sel_min = 4'd3;
        end else if (difficulty == 2'b10) begin
            sel_min = 4'd2;
        end else begin
            sel_min = 4'd1;
        end
    end

    reg [3:0] d_min, d_tens, d_ones;
    always @(*) begin
        if (home) begin
            d_min  = sel_min;
            d_tens = 4'd0;
            d_ones = 4'd0;
        end else begin
            d_min  = t_min;
            d_tens = t_tens;
            d_ones = t_ones;
        end
    end

    reg [3:0] d_game;   // 4'hF = blank
    always @(*) begin
        if (current_game == 3'd0) begin
            d_game = 4'hF;
        end else begin
            d_game = {1'b0, current_game};
        end
    end

    // HEX0: extra info for the current game (works even without a VGA monitor)
    reg [3:0] d_info;
    always @(*) begin
        if (active[1] && g2_phase == 3'd1) begin       // game 2: the digit being flashed
            d_info = {2'b00, g2_digit};
        end else if (active[2]) begin                  // game 3: hits so far
            d_info = {2'b00, g3_hits};
        end else if (active[4]) begin                  // game 5: guesses so far (shows 9 for 9+)
            d_info = (g5_tries > 4'd9) ? 4'd9 : g5_tries;
        end else begin
            d_info = 4'hF;
        end
    end

    seg7 H5 (d_game, HEX5);
    seg7 H4 (4'hF,   HEX4);
    seg7 H3 (d_min,  HEX3);
    seg7 H2 (d_tens, HEX2);
    seg7 H1 (d_ones, HEX1);
    seg7 H0 (d_info, HEX0);

    // ---------------- LED outputs ----------------
    assign LEDR[0] = (games_done > 3'd0);
    assign LEDR[1] = (games_done > 3'd1);
    assign LEDR[2] = (games_done > 3'd2);
    assign LEDR[3] = (games_done > 3'd3);
    assign LEDR[4] = (games_done > 3'd4);
    assign LEDR[6] = active[4] && (g5_hint == 2'd1);  // game 5: go higher
    assign LEDR[5] = active[4] && (g5_hint == 2'd2);  // game 5: go lower
    assign LEDR[7] = timer_run;
    assign LEDR[8] = lose;
    assign LEDR[9] = win;

    // ---------------- VGA: show the name of the current state (see vga_display.v) ----------------
    // screen code: 0 = HOME, 1-5 = GAME 1-5, 6 = WIN, 7 = LOSE
    reg [2:0] screen;
    always @(*) begin
        if (home) begin
            screen = 3'd0;
        end else if (win) begin
            screen = 3'd6;
        end else if (lose) begin
            screen = 3'd7;
        end else begin
            screen = current_game;
        end
    end

    // game 1 also shows its decimal number under the title; games 2, 3, 5 pass their state
    // packed into one bus each (layout documented at the top of vga_games.v)
    wire [10:0] g2_vis = {g2_phase, g2_digit, g2_count, g2_len};
    wire [27:0] g3_vis = {g3_flash, g3_hits, g3_pos, g3_zlo, g3_zhi};
    wire [22:0] g5_vis = {g5_hint, g5_ndig, g5_d1, g5_d0, g5_last, g5_tries};

    vga_display VD (clock, resetn, screen, active[0], g1_target, difficulty, g4_x, g4_y,
                    g2_vis, g3_vis, g5_vis,
                    VGA_R, VGA_G, VGA_B, VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK);
endmodule
