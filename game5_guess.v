// ============================================================================
// Game 5: crack the code (number guesser).
//
// The bomb has a secret code from 1 to 99. Type a guess on the keyboard (digits 0-9, top row or
// keypad), BACKSPACE to fix a typo, ENTER to submit. The screen then says GO HIGHER or GO LOWER.
// Guess the code and `done` goes high: the main FSM goes to WIN (this is the last game).
// With halving (50, 25 / 75, ...) any code takes at most 7 guesses.
//
// How the secret is made: same idea as game 1. A counter runs 1..99 on every clock and the
// secret copies it while the game is NOT active, so it freezes at the instant game 5 starts.
//
// Ports:
//   clock, resetn : 50 MHz clock, synchronous active-low reset
//   active        : 1 while game 5 is running (active[4] from main_game_fsm)
//   digit_p       : one-clock-cycle pulse when a digit key is pressed, digit_val = which digit
//   bksp_p        : BACKSPACE pressed (pulse)
//   enter_p       : ENTER pressed (pulse)
//   done          : 1 when the guess equals the secret (connect to done[4] of main_game_fsm)
//   d1, d0        : the digits typed so far (d1 = tens, d0 = ones), ndig = how many (0-2).
//                   With one digit typed, it is in d0.
//   hint          : result of the last guess: 0 = none yet, 1 = GO HIGHER, 2 = GO LOWER
//   last          : the last guess (0-99)
//   tries         : number of guesses submitted (stops at 15)
// ============================================================================
module game5_guess (clock, resetn, active, digit_p, digit_val, bksp_p, enter_p,
                    done, d1, d0, ndig, hint, last, tries);
    input        clock, resetn, active;
    input        digit_p, bksp_p, enter_p;
    input  [3:0] digit_val;
    output       done;
    output reg [3:0] d1, d0;
    output reg [1:0] ndig;
    output reg [1:0] hint;
    output reg [6:0] last;
    output reg [3:0] tries;

    // ---------------- secret code 1..99 ----------------
    reg [6:0] cnt;
    always @(posedge clock) begin
        if (!resetn || cnt == 7'd99) begin
            cnt <= 7'd1;
        end else begin
            cnt <= cnt + 1'b1;
        end
    end

    reg [6:0] secret;
    always @(posedge clock) begin
        if (!resetn) begin
            secret <= 7'd50;
        end else if (!active) begin
            secret <= cnt;
        end
    end

    // ---------------- the typed guess ----------------
    wire [6:0] guess = (ndig == 2'd2) ? (d1 * 4'd10 + d0) : {3'b000, d0};

    reg solved;
    always @(posedge clock) begin
        if (!resetn || !active) begin
            d1     <= 4'd0;
            d0     <= 4'd0;
            ndig   <= 2'd0;
            hint   <= 2'd0;
            last   <= 7'd0;
            tries  <= 4'd0;
            solved <= 1'b0;
        end else if (!solved) begin
            if (digit_p) begin
                if (ndig == 2'd0) begin
                    d0   <= digit_val;
                    ndig <= 2'd1;
                end else if (ndig == 2'd1) begin
                    d1   <= d0;
                    d0   <= digit_val;
                    ndig <= 2'd2;
                end
                // a third digit is ignored
            end else if (bksp_p) begin
                if (ndig == 2'd2) begin
                    d0   <= d1;
                    ndig <= 2'd1;
                end else begin
                    ndig <= 2'd0;
                end
            end else if (enter_p && ndig != 2'd0) begin
                last <= guess;
                ndig <= 2'd0;
                if (tries != 4'd15) begin
                    tries <= tries + 1'b1;
                end
                if (guess == secret) begin
                    solved <= 1'b1;
                end else if (guess < secret) begin
                    hint <= 2'd1;           // GO HIGHER
                end else begin
                    hint <= 2'd2;           // GO LOWER
                end
            end
        end
    end

    assign done = active && solved;
endmodule
