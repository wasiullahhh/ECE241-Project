// Main game FSM for Bomb Rush
// HOME -> GAME1 -> GAME2 -> GAME3 -> GAME4 -> GAME5 -> WIN, and any GAME state -> LOSE on time_up.
// WIN / LOSE -> HOME on restart. resetn (active low, synchronous) -> HOME.

module main_game_fsm (clock, resetn, start, done, time_up, restart,
                      active, current_game, games_done, timer_run, timer_load,
                      win, lose, home);
    input        clock, resetn;
    input        start;        // player starts the game (one-cycle pulse)
    input  [4:0] done;         // done[i] = 1 when mini-game i+1 is solved
    input        time_up;      // countdown timer reached 0
    input        restart;      // go back to HOME from WIN or LOSE (one-cycle pulse)

    output [4:0] active;       // one-hot: which mini-game is running
    output [2:0] current_game; // 0 in HOME, 1-5 while playing
    output reg [2:0] games_done; // number of mini-games completed (0-5)
    output       timer_run;    // 1 while a mini-game is running
    output       timer_load;   // pulse when leaving HOME: load the timer with the chosen difficulty
    output       win, lose, home;

    reg [2:0] y_Q, Y_D;        // y_Q = current state, Y_D = next state

    parameter HOME = 3'd0, GAME1 = 3'd1, GAME2 = 3'd2, GAME3 = 3'd3, GAME4 = 3'd4,
              GAME5 = 3'd5, WIN = 3'd6, LOSE = 3'd7;

    // State table. In every GAME state, time_up is checked before done (a tie is a loss).
    always @(*)
    begin: state_table
        case (y_Q)
            HOME:  if (start) Y_D = GAME1;
                   else       Y_D = HOME;

            GAME1: if (time_up)      Y_D = LOSE;
                   else if (done[0]) Y_D = GAME2;
                   else              Y_D = GAME1;

            GAME2: if (time_up)      Y_D = LOSE;
                   else if (done[1]) Y_D = GAME3;
                   else              Y_D = GAME2;

            GAME3: if (time_up)      Y_D = LOSE;
                   else if (done[2]) Y_D = GAME4;
                   else              Y_D = GAME3;

            GAME4: if (time_up)      Y_D = LOSE;
                   else if (done[3]) Y_D = GAME5;
                   else              Y_D = GAME4;

            GAME5: if (time_up)      Y_D = LOSE;
                   else if (done[4]) Y_D = WIN;
                   else              Y_D = GAME5;

            WIN:   if (restart) Y_D = HOME;
                   else         Y_D = WIN;

            LOSE:  if (restart) Y_D = HOME;
                   else         Y_D = LOSE;

            default: Y_D = HOME;
        endcase
    end // state_table

    // State flip-flops (synchronous active-low reset)
    always @(posedge clock)
    begin: state_FFs
        if (!resetn) y_Q <= HOME;
        else         y_Q <= Y_D;
    end // state_FFs

    // Progress counter: counts solved mini-games, holds its value in WIN/LOSE so the LEDs
    // still show how far the player got. Cleared in HOME.
    always @(posedge clock)
    begin: progress
        if (!resetn || y_Q == HOME)
            games_done <= 3'd0;
        else if (!time_up &&
                 ((y_Q == GAME1 && done[0]) || (y_Q == GAME2 && done[1]) ||
                  (y_Q == GAME3 && done[2]) || (y_Q == GAME4 && done[3]) ||
                  (y_Q == GAME5 && done[4])))
            games_done <= games_done + 1'b1;
    end // progress

    // FSM outputs
    assign active[0] = (y_Q == GAME1);
    assign active[1] = (y_Q == GAME2);
    assign active[2] = (y_Q == GAME3);
    assign active[3] = (y_Q == GAME4);
    assign active[4] = (y_Q == GAME5);

    assign current_game = (y_Q == GAME1) ? 3'd1 :
                          (y_Q == GAME2) ? 3'd2 :
                          (y_Q == GAME3) ? 3'd3 :
                          (y_Q == GAME4) ? 3'd4 :
                          (y_Q == GAME5) ? 3'd5 : 3'd0;

    assign timer_run  = |active;
    assign timer_load = (y_Q == HOME) & start;
    assign win        = (y_Q == WIN);
    assign lose       = (y_Q == LOSE);
    assign home       = (y_Q == HOME);
endmodule