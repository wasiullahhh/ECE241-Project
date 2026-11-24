// ============================================================================
// Game 1: decimal to binary conversion.
//
// While the game is active, a random decimal number from 1 to 100 is shown on the VGA screen
// (the number comes out of this module as `target`). The player builds that number in binary on
// SW[6:0] (SW[0] is the least significant bit, SW[6] the most significant). As soon as the
// switches equal the number, `done` goes high and the main FSM moves on to game 2.
//
// How the random number is made: a counter runs 1, 2, ... 100, 1, 2, ... on every clock
// (50 million steps per second) and `target` copies it for as long as the game is NOT active.
// The copy is frozen the moment the game starts, so the number depends on the exact instant the
// player pressed start, which is effectively random. Every number from 1 to 100 is equally likely.
//
// A match that is already present when the game starts does not count until the switches have
// been seen to differ from the number once (for example, if the difficulty switches happened to
// spell out the number). So the player always has to set the answer on purpose.
//
// Ports:
//   clock, resetn : 50 MHz clock, synchronous active-low reset
//   active        : 1 while game 1 is running (active[0] from main_game_fsm)
//   sw            : the 7 answer switches, SW[6:0]
//   done          : 1 when the switches equal the number (connect to done[0] of main_game_fsm)
//   target        : the number to show on the VGA screen (1-100)
// ============================================================================
module game1_binary (clock, resetn, active, sw, done, target);
    input        clock, resetn;
    input        active;
    input  [6:0] sw;
    output       done;
    output reg [6:0] target;

    // ---------------- free-running counter 1..100 ----------------
    reg [6:0] cnt;
    always @(posedge clock) begin
        if (!resetn) begin
            cnt <= 7'd1;
        end else if (cnt == 7'd100) begin
            cnt <= 7'd1;
        end else begin
            cnt <= cnt + 1'b1;
        end
    end

    // ---------------- pick the number: follow the counter until the game starts ----------------
    always @(posedge clock) begin
        if (!resetn) begin
            target <= 7'd1;
        end else if (!active) begin
            target <= cnt;
        end
        // while active: hold the number
    end

    // ---------------- synchronize the switches (two flip-flops) ----------------
    reg [6:0] sw_meta, sw_sync;
    always @(posedge clock) begin
        sw_meta <= sw;
        sw_sync <= sw_meta;
    end

    // ---------------- check the answer ----------------
    wire match = (sw_sync == target);

    reg armed;      // becomes 1 once the switches have differed from the number
    always @(posedge clock) begin
        if (!resetn || !active) begin
            armed <= 1'b0;
        end else if (!match) begin
            armed <= 1'b1;
        end
    end

    assign done = active & armed & match;
endmodule
