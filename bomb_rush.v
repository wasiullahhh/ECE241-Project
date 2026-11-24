// ============================================================================
// Bomb Rush - Milestone 1 (single file)
// This file: top level (bomb_rush). It connects main_game_fsm, countdown_timer, key_pulse,
//            seg7 (HEX decoder), game1_binary (game 1), keyboard_input and vga_display. LED outputs
//            are driven here too. Also needs the course vga_adapter and PS2_Controller files.
//
// Formatting note: Verilog uses "begin ... end" where C uses "{ ... }".
// (In Verilog, { } means "join signals together", e.g. {5{done_p}}.)
//
// Board controls (DE1-SoC):
//   KEY[0] = reset (active low)
//   KEY[2] = "solve" games 2, 3 and 5 (placeholder until those games are built)
//   Arrow keys = move the cube in game 4 (maze)
//   SW[6:0] = the answer for game 1 (decimal to binary), SW[0] is the least significant bit
//   PS/2 keyboard (keyboard_input.v):
//     Enter     = start the game (on HOME)
//     1 / 2 / 3 = difficulty on HOME: 1 = HARD (1 min), 2 = MEDIUM (2 min), 3 = EASY (3 min)
//     R         = restart (on WIN / LOSE, back to HOME)
//
// Outputs:
//   HEX5 = current game (1-5, blank otherwise)   HEX3:HEX2:HEX1 = minutes : tens : ones of seconds
//   (in HOME the selected difficulty is shown as M:00)   HEX4, HEX0 = off
//   LEDR[4:0] = progress bar (one LED per solved game)
//   LEDR[7] = timer running, LEDR[8] = LOSE, LEDR[9] = WIN
//   VGA = the name of the current state: HOME, GAME 1 ... GAME 5, WIN, LOSE
//         (drawn by vga_display.v; needs the course vga_adapter files + black_160_9.mif)
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
    // KEY[2] (pushbutton) still solves games 2-5; start / restart / difficulty come from the keyboard.
    wire done_p;
    key_pulse K2 (clock, resetn, KEY[2], done_p);

    wire start_p, restart_p, key1_p, key2_p, key3_p;      // Enter, R, 1, 2, 3
    wire up_p, down_p, left_p, right_p;                   // arrow keys (game 4)
    keyboard_input KB (clock, resetn, PS2_CLK, PS2_DAT, start_p, restart_p, key1_p, key2_p, key3_p,
                       up_p, down_p, left_p, right_p);

    // ---------------- main game FSM ----------------
    wire [4:0] active;
    wire [2:0] current_game, games_done;
    wire       timer_run, timer_load, win, lose, home, time_up;

    // ---------------- mini-games ----------------
    // Game 1 (decimal to binary) is real: SW[6:0] must equal the number shown on the VGA screen.
    // Game 4 (maze) is real: arrow keys move the cube to the exit.
    // Games 2, 3 and 5 are still placeholders: pressing KEY[2] "solves" them.
    // (The FSM only looks at the done bit of the game that is active.)
    wire       g1_done;
    wire [6:0] g1_target;      // the decimal number game 1 asks for (1-100)
    game1_binary G1 (clock, resetn, active[0], SW[6:0], g1_done, g1_target);

    // Game 4 (maze): arrow keys move the cube, reaching the exit solves it.
    wire       g4_done;
    wire [3:0] g4_x;           // cube position, shown on the VGA screen
    wire [3:0] g4_y;
    game4_maze G4 (clock, resetn, active[3], up_p, down_p, left_p, right_p, g4_x, g4_y, g4_done);

    wire [4:0] done = {done_p, g4_done, done_p, done_p, g1_done};

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

    seg7 H5 (d_game, HEX5);
    seg7 H4 (4'hF,   HEX4);
    seg7 H3 (d_min,  HEX3);
    seg7 H2 (d_tens, HEX2);
    seg7 H1 (d_ones, HEX1);
    seg7 H0 (4'hF,   HEX0);

    // ---------------- LED outputs ----------------
    assign LEDR[0] = (games_done > 3'd0);
    assign LEDR[1] = (games_done > 3'd1);
    assign LEDR[2] = (games_done > 3'd2);
    assign LEDR[3] = (games_done > 3'd3);
    assign LEDR[4] = (games_done > 3'd4);
    assign LEDR[6:5] = 2'b00;
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

    // game 1 also shows its decimal number under the title
    vga_display VD (clock, resetn, screen, active[0], g1_target, difficulty, g4_x, g4_y,
                    VGA_R, VGA_G, VGA_B, VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK);
endmodule
