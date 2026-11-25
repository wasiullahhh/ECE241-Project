// ============================================================================
// Game 3: reaction test.
//
// A white marker sweeps back and forth along a bar on the VGA screen. Part of the bar is a green
// target zone. Press SPACE on the keyboard while the marker is inside the green zone.
// Three hits in a row solve the game (`done` goes high, the main FSM moves on to game 4).
// Every hit makes the marker faster and the zone narrower, and moves the zone somewhere new.
// A miss resets the hits to 0. After any press the marker freezes for a moment (0.4 s after a hit,
// 0.75 s after a miss) and presses are ignored, so mashing SPACE does not work.
//
// The bar is 150 positions wide (0-149). vga_games.v draws position p at screen column 5 + p.
//
// Ports:
//   clock, resetn : 50 MHz clock, synchronous active-low reset
//   active        : 1 while game 3 is running (active[2] from main_game_fsm)
//   space         : one-clock-cycle pulse when SPACE is pressed (keyboard_input.v)
//   done          : 1 after the third hit (connect to done[2] of main_game_fsm)
//   pos           : marker position 0-149
//   zlo, zhi      : first and last position of the green zone
//   hits          : hits in a row so far (0-3)
//   flash         : 0 = nothing, 1 = "HIT" message, 2 = "MISS" message (only during the freeze)
// ============================================================================
module game3_reaction (clock, resetn, active, space, done, pos, zlo, zhi, hits, flash);
    parameter CLK_PER_SEC = 50_000_000;
    parameter HITS_NEEDED = 2'd3;

    input        clock, resetn, active, space;
    output       done;
    output reg [7:0] pos;
    output reg [7:0] zlo;
    output     [7:0] zhi;
    output reg [1:0] hits;
    output reg [1:0] flash;

    localparam [7:0] LAST = 8'd149;                // last bar position

    // marker speed: clock cycles per 1-position step (faster with every hit)
    reg [31:0] step_cycles;
    always @(*) begin
        case (hits)
            2'd0:    step_cycles = CLK_PER_SEC / 110;   // about 1.4 s per sweep
            2'd1:    step_cycles = CLK_PER_SEC / 150;   // about 1.0 s per sweep
            default: step_cycles = CLK_PER_SEC / 200;   // about 0.75 s per sweep
        endcase
    end

    // zone width (narrower with every hit)
    reg [7:0] zwidth;
    always @(*) begin
        case (hits)
            2'd0:    zwidth = 8'd24;
            2'd1:    zwidth = 8'd16;
            default: zwidth = 8'd10;
        endcase
    end
    assign zhi = zlo + zwidth - 8'd1;

    // free-running counter used to place the zone at a random spot (0-99)
    reg [6:0] rnd;
    always @(posedge clock) begin
        if (!resetn || rnd == 7'd99) begin
            rnd <= 7'd0;
        end else begin
            rnd <= rnd + 1'b1;
        end
    end

    localparam [31:0] T_HIT  = (CLK_PER_SEC / 10) * 4;    // 0.4 s freeze after a hit
    localparam [31:0] T_MISS = (CLK_PER_SEC / 4) * 3;     // 0.75 s freeze after a miss

    reg        dir;            // 1 = moving right
    reg [31:0] step_cnt;       // counts clock cycles until the next step
    reg [31:0] freeze;         // > 0 while frozen

    wire inside = (pos >= zlo) && (pos <= zhi);

    always @(posedge clock) begin
        if (!resetn || !active) begin
            pos      <= 8'd0;
            dir      <= 1'b1;
            step_cnt <= 32'd0;
            freeze   <= 32'd0;
            hits     <= 2'd0;
            flash    <= 2'd0;
            zlo      <= 8'd100;         // first zone: towards the right end
        end else if (hits == HITS_NEEDED) begin
            // solved: hold everything until the FSM moves on
        end else if (freeze != 32'd0) begin
            freeze <= freeze - 1'b1;
            if (freeze == 32'd1) begin
                flash <= 2'd0;
            end
        end else if (space) begin
            if (inside) begin
                hits   <= hits + 1'b1;
                flash  <= 2'd1;
                freeze <= T_HIT;
                zlo    <= 8'd15 + {1'b0, rnd};       // new zone somewhere in 15 .. 114
            end else begin
                hits   <= 2'd0;
                flash  <= 2'd2;
                freeze <= T_MISS;
            end
        end else if (step_cnt >= step_cycles) begin
            step_cnt <= 32'd0;
            if (dir) begin
                if (pos == LAST) begin
                    dir <= 1'b0;
                    pos <= pos - 1'b1;
                end else begin
                    pos <= pos + 1'b1;
                end
            end else begin
                if (pos == 8'd0) begin
                    dir <= 1'b1;
                    pos <= pos + 1'b1;
                end else begin
                    pos <= pos - 1'b1;
                end
            end
        end else begin
            step_cnt <= step_cnt + 1'b1;
        end
    end

    assign done = active && (hits == HITS_NEEDED);
endmodule
