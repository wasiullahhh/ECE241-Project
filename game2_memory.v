// ============================================================================
// Game 2: memory match (like "Simon").
//
// The VGA screen flashes a sequence of digits (1, 2 or 3), one at a time. The player then repeats
// the sequence with the pushbuttons KEY[1] / KEY[2] / KEY[3] (or keyboard keys 1 / 2 / 3).
// There are 3 rounds: the sequence is 3, then 4, then 5 digits long (each round adds one digit to
// the same sequence). Get all 3 rounds right and `done` goes high, and the main FSM moves on to game 3.
// A wrong press shows "WRONG" for one second and then replays the same round.
//
// How the random sequence is made: a 24-bit LFSR steps on every clock while the game is NOT
// active, and the sequence is copied from it. The copy freezes the moment the game starts (the
// instant the player solved game 1), so it is effectively random.
// Each digit is (4-bit field mod 3) + 1, so 1, 2 and 3 are almost equally likely (6/16, 5/16, 5/16).
//
// Ports:
//   clock, resetn : 50 MHz clock, synchronous active-low reset
//   active        : 1 while game 2 is running (active[1] from main_game_fsm)
//   b1, b2, b3    : one-clock-cycle pulses for buttons 1, 2, 3
//   done          : 1 when all rounds are solved (connect to done[1] of main_game_fsm)
//   phase         : what is happening now (for the VGA screen and HEX0), see P_xxx below
//   digit         : the digit being shown (1-3), valid while phase == P_ON
//   count         : how many digits the player has entered correctly in this round
//   len           : length of the current round (3, 4 or 5)
// ============================================================================
module game2_memory (clock, resetn, active, b1, b2, b3, done, phase, digit, count, len);
    parameter CLK_PER_SEC = 50_000_000;
    parameter START_LEN   = 3'd3;          // first round length
    parameter MAX_LEN     = 3'd5;          // last round length (at most 5)

    input        clock, resetn, active;
    input        b1, b2, b3;
    output       done;
    output reg [2:0] phase;
    output     [1:0] digit;
    output reg [2:0] count;
    output reg [2:0] len;

    // phases (also used by vga_games.v - keep the numbers the same there)
    parameter P_PAUSE = 3'd0,   // blank screen before a round, "WATCH THE SEQUENCE"
              P_ON    = 3'd1,   // a digit is shown
              P_OFF   = 3'd2,   // short gap between two digits
              P_INPUT = 3'd3,   // player types the sequence back
              P_WRONG = 3'd4,   // wrong press: "WRONG" for 1 second
              P_DONE  = 3'd5;   // all rounds solved

    // durations in clock cycles
    localparam [31:0] T_PAUSE = CLK_PER_SEC;              // 1 s
    localparam [31:0] T_ON    = (CLK_PER_SEC / 10) * 6;   // 0.6 s
    localparam [31:0] T_OFF   = CLK_PER_SEC / 4;          // 0.25 s
    localparam [31:0] T_WRONG = CLK_PER_SEC;              // 1 s

    // ---------------- random sequence ----------------
    reg [23:0] lfsr;
    always @(posedge clock) begin
        if (!resetn) begin
            lfsr <= 24'hACE1_23;
        end else if (!active) begin
            // taps 24, 23, 22, 17 (maximal length)
            lfsr <= {lfsr[22:0], lfsr[23] ^ lfsr[22] ^ lfsr[21] ^ lfsr[16]};
        end
    end

    reg [9:0] seq;           // 5 digits, 2 bits each; digit i is seq[2*i +: 2]
    always @(posedge clock) begin
        if (!resetn) begin
            seq <= 10'b11_10_01_10_01;
        end else if (!active) begin
            seq <= {mod3p1(lfsr[19:16]), mod3p1(lfsr[15:12]), mod3p1(lfsr[11:8]),
                    mod3p1(lfsr[7:4]),   mod3p1(lfsr[3:0])};
        end
    end

    function [1:0] mod3p1;               // (v mod 3) + 1  ->  1, 2 or 3
        input [3:0] v;
        begin
            mod3p1 = (v % 3) + 2'd1;
        end
    endfunction

    // ---------------- state machine ----------------
    reg [2:0]  idx;          // which digit is being shown / expected next
    reg [31:0] timer;        // counts down the time left in the current phase

    wire       pressed = b1 | b2 | b3;
    wire [1:0] pval    = b1 ? 2'd1 : (b2 ? 2'd2 : 2'd3);
    wire [1:0] want    = seq[{idx, 1'b0} +: 2];

    always @(posedge clock) begin
        if (!resetn || !active) begin
            phase <= P_PAUSE;
            len   <= START_LEN;
            idx   <= 3'd0;
            count <= 3'd0;
            timer <= T_PAUSE;
        end else begin
            case (phase)
                P_PAUSE: begin
                    if (timer == 32'd0) begin
                        phase <= P_ON;
                        idx   <= 3'd0;
                        timer <= T_ON;
                    end else begin
                        timer <= timer - 1'b1;
                    end
                end

                P_ON: begin
                    if (timer == 32'd0) begin
                        phase <= P_OFF;
                        timer <= T_OFF;
                    end else begin
                        timer <= timer - 1'b1;
                    end
                end

                P_OFF: begin
                    if (timer == 32'd0) begin
                        if (idx + 1'b1 == len) begin     // whole round shown: player's turn
                            phase <= P_INPUT;
                            idx   <= 3'd0;
                            count <= 3'd0;
                        end else begin                   // next digit
                            phase <= P_ON;
                            idx   <= idx + 1'b1;
                            timer <= T_ON;
                        end
                    end else begin
                        timer <= timer - 1'b1;
                    end
                end

                P_INPUT: begin
                    if (pressed) begin
                        if (pval != want) begin          // mistake: replay this round
                            phase <= P_WRONG;
                            timer <= T_WRONG;
                        end else if (idx + 1'b1 == len) begin   // round complete
                            count <= count + 1'b1;
                            if (len == MAX_LEN) begin
                                phase <= P_DONE;
                            end else begin
                                len   <= len + 1'b1;
                                phase <= P_PAUSE;
                                timer <= T_PAUSE;
                            end
                        end else begin                   // correct, keep going
                            idx   <= idx + 1'b1;
                            count <= count + 1'b1;
                        end
                    end
                end

                P_WRONG: begin
                    if (timer == 32'd0) begin
                        phase <= P_PAUSE;
                        count <= 3'd0;
                        timer <= T_PAUSE;
                    end else begin
                        timer <= timer - 1'b1;
                    end
                end

                default: begin                           // P_DONE: hold until the FSM moves on
                    phase <= P_DONE;
                end
            endcase
        end
    end

    assign digit = want;
    assign done  = active && (phase == P_DONE);
endmodule
