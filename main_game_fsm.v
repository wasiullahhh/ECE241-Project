// ============================================================================
// Main game FSM: HOME -> GAME1 -> ... -> GAME5 -> WIN, any GAME -> LOSE on time_up.
// WIN / LOSE -> HOME on restart. resetn (active low, synchronous) -> HOME.
// ============================================================================
module main_game_fsm (clock, resetn, start, done, time_up, restart,
                      active, current_game, games_done, timer_run, timer_load,
                      win, lose, home);
    input        clock, resetn;
    input        start;        // player starts the game (one-cycle pulse)
    input  [4:0] done;         // done[i] = 1 when mini-game i+1 is solved
    input        time_up;      // countdown timer reached 0
    input        restart;      // back to HOME from WIN or LOSE (one-cycle pulse)

    output [4:0] active;       // one-hot: which mini-game is running
    output reg [2:0] current_game; // 0 in HOME, 1-5 while playing
    output reg [2:0] games_done;   // number of mini-games completed (0-5)
    output       timer_run;    // 1 while a mini-game is running
    output       timer_load;   // pulse when leaving HOME: load the timer
    output       win, lose, home;

    reg [2:0] y_Q, Y_D;        // y_Q = current state, Y_D = next state

    parameter HOME = 3'd0, GAME1 = 3'd1, GAME2 = 3'd2, GAME3 = 3'd3, GAME4 = 3'd4,
              GAME5 = 3'd5, WIN = 3'd6, LOSE = 3'd7;

    // State table. In every GAME state time_up is checked before done (a tie is a loss).
    always @(*) begin: state_table
        case (y_Q)
            HOME: begin
                if (start) begin
                    Y_D = GAME1;
                end else begin
                    Y_D = HOME;
                end
            end

            GAME1: begin
                if (time_up) begin
                    Y_D = LOSE;
                end else if (done[0]) begin
                    Y_D = GAME2;
                end else begin
                    Y_D = GAME1;
                end
            end

            GAME2: begin
                if (time_up) begin
                    Y_D = LOSE;
                end else if (done[1]) begin
                    Y_D = GAME3;
                end else begin
                    Y_D = GAME2;
                end
            end

            GAME3: begin
                if (time_up) begin
                    Y_D = LOSE;
                end else if (done[2]) begin
                    Y_D = GAME4;
                end else begin
                    Y_D = GAME3;
                end
            end

            GAME4: begin
                if (time_up) begin
                    Y_D = LOSE;
                end else if (done[3]) begin
                    Y_D = GAME5;
                end else begin
                    Y_D = GAME4;
                end
            end

            GAME5: begin
                if (time_up) begin
                    Y_D = LOSE;
                end else if (done[4]) begin
                    Y_D = WIN;
                end else begin
                    Y_D = GAME5;
                end
            end

            WIN: begin
                if (restart) begin
                    Y_D = HOME;
                end else begin
                    Y_D = WIN;
                end
            end

            LOSE: begin
                if (restart) begin
                    Y_D = HOME;
                end else begin
                    Y_D = LOSE;
                end
            end

            default: begin
                Y_D = HOME;
            end
        endcase
    end // state_table

    // State flip-flops (synchronous active-low reset)
    always @(posedge clock) begin: state_FFs
        if (!resetn) begin
            y_Q <= HOME;
        end else begin
            y_Q <= Y_D;
        end
    end // state_FFs

    // Counts solved games; keeps its value in WIN/LOSE; cleared in HOME.
    always @(posedge clock) begin: progress
        if (!resetn || y_Q == HOME) begin
            games_done <= 3'd0;
        end else if (!time_up &&
                     ((y_Q == GAME1 && done[0]) || (y_Q == GAME2 && done[1]) ||
                      (y_Q == GAME3 && done[2]) || (y_Q == GAME4 && done[3]) ||
                      (y_Q == GAME5 && done[4]))) begin
            games_done <= games_done + 1'b1;
        end
    end // progress

    // FSM outputs
    assign active[0] = (y_Q == GAME1);
    assign active[1] = (y_Q == GAME2);
    assign active[2] = (y_Q == GAME3);
    assign active[3] = (y_Q == GAME4);
    assign active[4] = (y_Q == GAME5);

    always @(*) begin: current_game_logic
        case (y_Q)
            GAME1: begin
                current_game = 3'd1;
            end
            GAME2: begin
                current_game = 3'd2;
            end
            GAME3: begin
                current_game = 3'd3;
            end
            GAME4: begin
                current_game = 3'd4;
            end
            GAME5: begin
                current_game = 3'd5;
            end
            default: begin
                current_game = 3'd0;
            end
        endcase
    end // current_game_logic

    assign timer_run  = |active;
    assign timer_load = (y_Q == HOME) & start;
    assign win        = (y_Q == WIN);
    assign lose       = (y_Q == LOSE);
    assign home       = (y_Q == HOME);
endmodule
