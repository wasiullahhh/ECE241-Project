// ============================================================================
// vga_games.v - draws the screens of game 2 (memory), game 3 (reaction) and game 5 (crack the code).
//
// vga_screen (in vga_display.v) scans the 160x120 screen and asks this module for the colour of
// pixel (sx, sy). It is used only while screen is 2, 3 or 5; for the other screens vga_screen draws
// everything itself. This module has its own 5x7 font with all of A-Z, 0-9 and : - ! ? . _ * /
// so new text can be added without touching the glyph table in vga_display.v.
//
// Text can be drawn at 3 sizes: scale 0 = 1x (6-pixel cells, 7 rows tall),
// scale 1 = 2x (12-pixel cells, 14 rows tall), scale 2 = 4x (24-pixel cells, 28 rows tall).
// Every line is centred horizontally. Only one line of text may sit on any scan row.
//
// Packed inputs (built in bomb_rush.v):
//   g2_vis = {phase[2:0], digit[1:0], count[2:0], len[2:0]}             from game2_memory
//   g3_vis = {flash[1:0], hits[1:0], pos[7:0], zlo[7:0], zhi[7:0]}      from game3_reaction
//   g5_vis = {hint[1:0], ndig[1:0], d1[3:0], d0[3:0], last[6:0], tries[3:0]}   from game5_guess
// Colours are 9-bit {R[2:0], G[2:0], B[2:0]}, same as the rest of the VGA code.
// ============================================================================
module vga_games (sx, sy, screen, g2_vis, g3_vis, g5_vis, color);
    input  [7:0]  sx;
    input  [6:0]  sy;
    input  [2:0]  screen;
    input  [10:0] g2_vis;
    input  [27:0] g3_vis;
    input  [22:0] g5_vis;
    output [8:0]  color;

    // ---- colours ----
    localparam [8:0] BLACK  = 9'b000_000_000, WHITE  = 9'b111_111_111,
                     YELLOW = 9'b111_111_000, GREEN  = 9'b000_111_000,
                     RED    = 9'b111_000_000, CYAN   = 9'b000_111_111,
                     ORANGE = 9'b111_100_000, BLUE   = 9'b001_011_111,
                     GRAY   = 9'b010_010_010, LGRAY  = 9'b100_100_100;

    // ---- unpack ----
    wire [2:0] g2_phase = g2_vis[10:8];
    wire [1:0] g2_digit = g2_vis[7:6];
    wire [2:0] g2_count = g2_vis[5:3];
    wire [2:0] g2_len   = g2_vis[2:0];

    wire [1:0] g3_flash = g3_vis[27:26];
    wire [1:0] g3_hits  = g3_vis[25:24];
    wire [7:0] g3_pos   = g3_vis[23:16];
    wire [7:0] g3_zlo   = g3_vis[15:8];
    wire [7:0] g3_zhi   = g3_vis[7:0];

    wire [1:0] g5_hint  = g5_vis[22:21];
    wire [1:0] g5_ndig  = g5_vis[20:19];
    wire [3:0] g5_d1    = g5_vis[18:15];
    wire [3:0] g5_d0    = g5_vis[14:11];
    wire [6:0] g5_last  = g5_vis[10:4];
    wire [3:0] g5_tries = g5_vis[3:0];

    // game 2 phases (same numbers as game2_memory.v)
    localparam P_PAUSE = 3'd0, P_ON = 3'd1, P_OFF = 3'd2, P_INPUT = 3'd3, P_WRONG = 3'd4, P_DONE = 3'd5;

    // ---- numbers -> ASCII ----
    wire [3:0] last_t = g5_last / 10;
    wire [3:0] last_o = g5_last % 10;
    wire [3:0] try_t  = (g5_tries >= 4'd10) ? 4'd1 : 4'd0;
    wire [3:0] try_o  = (g5_tries >= 4'd10) ? (g5_tries - 4'd10) : g5_tries;

    function [7:0] asc;                 // digit 0-9 -> ASCII
        input [3:0] d;
        begin
            asc = 8'h30 + {4'h0, d};
        end
    endfunction

    function rowin;                     // is scan row y inside [y0, y0 + h) ?
        input [6:0] y, y0, h;
        begin
            rowin = (y >= y0) && (y < y0 + h);
        end
    endfunction

    // ========================================================================
    // Which line of text is on this scan row?  ly0 = its top row, lsc = scale,
    // llen = number of characters, lstr = the characters (last char in the low byte),
    // lcol = colour.
    // ========================================================================
    reg         l_on;
    reg  [6:0]  ly0;
    reg  [1:0]  lsc;
    reg  [4:0]  llen;
    reg  [8*24-1:0] lstr;
    reg  [8:0]  lcol;
    reg  [4:0]  pi;                     // game 2 progress: displayed character index
    integer     p;

    always @(*) begin
        l_on = 1'b0;
        ly0  = 7'd0;
        lsc  = 2'd0;
        llen = 5'd1;
        lstr = {24{8'h20}};
        lcol = WHITE;
        pi   = 5'd0;

        case (screen)
            // -------------------------------- GAME 2: MEMORY --------------------------------
            3'd2: begin
                if (rowin(sy, 7'd3, 7'd7)) begin
                    l_on = 1'b1;  ly0 = 7'd3;  llen = 5'd14;  lcol = YELLOW;
                    lstr = "GAME 2: MEMORY";
                end else if (rowin(sy, 7'd16, 7'd7)) begin
                    l_on = 1'b1;  ly0 = 7'd16;
                    if (g2_phase == P_INPUT) begin
                        llen = 5'd20;  lstr = "REPEAT IT: KEY 1 2 3";
                    end else if (g2_phase == P_WRONG) begin
                        llen = 5'd18;  lstr = "WRONG! WATCH AGAIN";  lcol = RED;
                    end else if (g2_phase == P_DONE) begin
                        llen = 5'd8;   lstr = "CORRECT!";            lcol = GREEN;
                    end else begin
                        llen = 5'd18;  lstr = "WATCH THE SEQUENCE";
                    end
                end else if (rowin(sy, 7'd28, 7'd7)) begin
                    l_on = 1'b1;  ly0 = 7'd28;  llen = 5'd12;  lcol = CYAN;
                    lstr = {"ROUND ", asc({1'b0, g2_len} - 4'd2), " OF 3"};
                end else if (rowin(sy, 7'd42, 7'd28)) begin
                    // the big flashing digit
                    l_on = (g2_phase == P_ON);  ly0 = 7'd42;  lsc = 2'd2;  llen = 5'd1;
                    lstr = asc({2'b00, g2_digit});
                    lcol = (g2_digit == 2'd1) ? RED : ((g2_digit == 2'd2) ? GREEN : BLUE);
                end else if (rowin(sy, 7'd84, 7'd14)) begin
                    // progress "* * _ _ _": one slot per digit of this round
                    l_on = (g2_phase == P_INPUT) || (g2_phase == P_WRONG);
                    ly0  = 7'd84;  lsc = 2'd1;  llen = {g2_len, 1'b0} - 5'd1;
                    lcol = (g2_phase == P_WRONG) ? RED : WHITE;
                    for (p = 0; p < 9; p = p + 1) begin
                        pi = llen - 5'd1 - p[4:0];               // character index of byte p
                        if (pi[0])
                            lstr[8*p +: 8] = " ";
                        else if (pi[4:1] < {1'b0, g2_count})
                            lstr[8*p +: 8] = "*";
                        else
                            lstr[8*p +: 8] = "_";
                    end
                end
            end

            // -------------------------------- GAME 3: REACTION --------------------------------
            3'd3: begin
                if (rowin(sy, 7'd3, 7'd7)) begin
                    l_on = 1'b1;  ly0 = 7'd3;  llen = 5'd16;  lcol = YELLOW;
                    lstr = "GAME 3: REACTION";
                end else if (rowin(sy, 7'd14, 7'd7)) begin
                    l_on = 1'b1;  ly0 = 7'd14;  llen = 5'd24;
                    lstr = "PRESS SPACE IN THE GREEN";
                end else if (rowin(sy, 7'd72, 7'd14)) begin
                    l_on = 1'b1;  ly0 = 7'd72;  lsc = 2'd1;  llen = 5'd9;  lcol = CYAN;
                    lstr = {"HITS: ", asc({2'b00, g3_hits}), "/3"};
                end else if (rowin(sy, 7'd96, 7'd7)) begin
                    ly0 = 7'd96;
                    if (g3_hits == 2'd3) begin
                        l_on = 1'b1;  llen = 5'd7;   lstr = "SOLVED!";            lcol = GREEN;
                    end else if (g3_flash == 2'd1) begin
                        l_on = 1'b1;  llen = 5'd9;   lstr = "NICE HIT!";          lcol = GREEN;
                    end else if (g3_flash == 2'd2) begin
                        l_on = 1'b1;  llen = 5'd17;  lstr = "MISSED! BACK TO 0";  lcol = RED;
                    end
                end
            end

            // -------------------------------- GAME 5: CRACK THE CODE --------------------------------
            3'd5: begin
                if (rowin(sy, 7'd3, 7'd7)) begin
                    l_on = 1'b1;  ly0 = 7'd3;  llen = 5'd22;  lcol = YELLOW;
                    lstr = "GAME 5: CRACK THE CODE";
                end else if (rowin(sy, 7'd14, 7'd7)) begin
                    l_on = 1'b1;  ly0 = 7'd14;  llen = 5'd21;
                    lstr = "GUESS 1-99 THEN ENTER";
                end else if (rowin(sy, 7'd28, 7'd28)) begin
                    // what the player has typed so far, big
                    l_on = 1'b1;  ly0 = 7'd28;  lsc = 2'd2;  llen = 5'd2;
                    if (g5_ndig == 2'd2)
                        lstr = {asc(g5_d1), asc(g5_d0)};
                    else if (g5_ndig == 2'd1)
                        lstr = {asc(g5_d0), "_"};
                    else
                        lstr = "__";
                end else if (rowin(sy, 7'd64, 7'd7)) begin
                    l_on = (g5_hint != 2'd0);  ly0 = 7'd64;  lcol = LGRAY;
                    if (last_t == 4'd0) begin
                        llen = 5'd13;  lstr = {"LAST GUESS: ", asc(last_o)};
                    end else begin
                        llen = 5'd14;  lstr = {"LAST GUESS: ", asc(last_t), asc(last_o)};
                    end
                end else if (rowin(sy, 7'd76, 7'd14)) begin
                    l_on = (g5_hint != 2'd0);  ly0 = 7'd76;  lsc = 2'd1;
                    if (g5_hint == 2'd1) begin
                        llen = 5'd9;  lstr = "GO HIGHER";  lcol = GREEN;
                    end else begin
                        llen = 5'd8;  lstr = "GO LOWER";   lcol = ORANGE;
                    end
                end else if (rowin(sy, 7'd104, 7'd7)) begin
                    l_on = 1'b1;  ly0 = 7'd104;  lcol = CYAN;
                    if (try_t == 4'd0) begin
                        llen = 5'd8;  lstr = {"TRIES: ", asc(try_o)};
                    end else begin
                        llen = 5'd9;  lstr = {"TRIES: ", asc(try_t), asc(try_o)};
                    end
                end
            end

            default: begin
                l_on = 1'b0;
            end
        endcase
    end

    // ========================================================================
    // Text renderer: where is this pixel inside the line?
    // ========================================================================
    reg [7:0] lx0, lw;                  // left edge and width of the line
    always @(*) begin
        case (lsc)
            2'd0: begin
                lx0 = 8'd80 - {3'b000, llen} * 8'd3;
                lw  = {3'b000, llen} * 8'd6 - 8'd1;
            end
            2'd1: begin
                lx0 = 8'd80 - {3'b000, llen} * 8'd6;
                lw  = {3'b000, llen} * 8'd12 - 8'd2;
            end
            default: begin
                lx0 = 8'd80 - {3'b000, llen} * 8'd12;
                lw  = {3'b000, llen} * 8'd24 - 8'd4;
            end
        endcase
    end

    wire [7:0] dx = sx - lx0;
    wire [6:0] dy = sy - ly0;

    reg [4:0] ci;                       // which character
    reg [2:0] col, row;                 // font column (5 = gap) and row
    always @(*) begin
        case (lsc)
            2'd0: begin
                ci  = dx / 6;
                col = dx % 6;
                row = dy[2:0];
            end
            2'd1: begin
                ci  = dx / 12;
                col = (dx % 12) >> 1;
                row = dy[3:1];
            end
            default: begin
                ci  = dx / 24;
                col = (dx % 24) >> 2;
                row = dy[4:2];
            end
        endcase
    end

    wire [7:0]  tch   = lstr[8*(llen - 5'd1 - ci) +: 8];
    wire [34:0] tglyp = font(tch);
    wire [4:0]  tbits = tglyp[34 - 5*row -: 5];
    wire        t_on  = l_on && (sx >= lx0) && (dx < lw) && (col < 3'd5) && tbits[3'd4 - col];

    // ========================================================================
    // Game 3 graphics: the bar (positions 0-149 at screen columns 5-154), the green zone
    // and the marker.
    // ========================================================================
    wire       is_g3   = (screen == 3'd3);
    wire [7:0] bx      = sx - 8'd5;                               // bar position of this column
    wire       in_barx = (sx >= 8'd5) && (sx <= 8'd154);
    wire       in_bar  = is_g3 && in_barx && (sy >= 7'd48) && (sy <= 7'd57);
    wire       frame   = is_g3 && (sx >= 8'd4) && (sx <= 8'd155) && (sy >= 7'd47) && (sy <= 7'd58) && !in_bar;
    wire       in_zone = in_bar && (bx >= g3_zlo) && (bx <= g3_zhi);
    wire       marker  = is_g3 && in_barx && (bx == g3_pos || bx == g3_pos + 8'd1) &&
                         (sy >= 7'd44) && (sy <= 7'd61);
    wire [8:0] mk_col  = (g3_flash == 2'd2) ? RED : ((g3_flash == 2'd1) ? GREEN : WHITE);

    assign color = marker  ? mk_col :
                   in_zone ? GREEN  :
                   in_bar  ? GRAY   :
                   frame   ? LGRAY  :
                   t_on    ? lcol   : BLACK;

    // ========================================================================
    // 5x7 font. 7 rows of 5 bits, top row first, leftmost pixel = bit 4 of each row.
    // ========================================================================
    function [34:0] font;
        input [7:0] a;
        begin
            case (a)
                "A": font = 35'b01110_10001_10001_11111_10001_10001_10001;
                "B": font = 35'b11110_10001_10001_11110_10001_10001_11110;
                "C": font = 35'b01110_10001_10000_10000_10000_10001_01110;
                "D": font = 35'b11110_10001_10001_10001_10001_10001_11110;
                "E": font = 35'b11111_10000_10000_11110_10000_10000_11111;
                "F": font = 35'b11111_10000_10000_11110_10000_10000_10000;
                "G": font = 35'b01110_10001_10000_10111_10001_10001_01111;
                "H": font = 35'b10001_10001_10001_11111_10001_10001_10001;
                "I": font = 35'b01110_00100_00100_00100_00100_00100_01110;
                "J": font = 35'b00111_00010_00010_00010_00010_10010_01100;
                "K": font = 35'b10001_10010_10100_11000_10100_10010_10001;
                "L": font = 35'b10000_10000_10000_10000_10000_10000_11111;
                "M": font = 35'b10001_11011_10101_10101_10001_10001_10001;
                "N": font = 35'b10001_10001_11001_10101_10011_10001_10001;
                "O": font = 35'b01110_10001_10001_10001_10001_10001_01110;
                "P": font = 35'b11110_10001_10001_11110_10000_10000_10000;
                "Q": font = 35'b01110_10001_10001_10001_10101_10010_01101;
                "R": font = 35'b11110_10001_10001_11110_10100_10010_10001;
                "S": font = 35'b01111_10000_10000_01110_00001_00001_11110;
                "T": font = 35'b11111_00100_00100_00100_00100_00100_00100;
                "U": font = 35'b10001_10001_10001_10001_10001_10001_01110;
                "V": font = 35'b10001_10001_10001_10001_10001_01010_00100;
                "W": font = 35'b10001_10001_10001_10101_10101_10101_01010;
                "X": font = 35'b10001_10001_01010_00100_01010_10001_10001;
                "Y": font = 35'b10001_10001_10001_01010_00100_00100_00100;
                "Z": font = 35'b11111_00001_00010_00100_01000_10000_11111;
                "0": font = 35'b01110_10001_10011_10101_11001_10001_01110;
                "1": font = 35'b00100_01100_00100_00100_00100_00100_01110;
                "2": font = 35'b01110_10001_00001_00010_00100_01000_11111;
                "3": font = 35'b11111_00010_00100_00010_00001_10001_01110;
                "4": font = 35'b00010_00110_01010_10010_11111_00010_00010;
                "5": font = 35'b11111_10000_11110_00001_00001_10001_01110;
                "6": font = 35'b00110_01000_10000_11110_10001_10001_01110;
                "7": font = 35'b11111_00001_00010_00100_01000_01000_01000;
                "8": font = 35'b01110_10001_10001_01110_10001_10001_01110;
                "9": font = 35'b01110_10001_10001_01111_00001_00010_01100;
                ":": font = 35'b00000_01100_01100_00000_01100_01100_00000;
                "-": font = 35'b00000_00000_00000_11111_00000_00000_00000;
                "!": font = 35'b00100_00100_00100_00100_00100_00000_00100;
                "?": font = 35'b01110_10001_00001_00010_00100_00000_00100;
                ".": font = 35'b00000_00000_00000_00000_00000_01100_01100;
                "_": font = 35'b00000_00000_00000_00000_00000_00000_11111;
                "*": font = 35'b00000_00100_10101_01110_10101_00100_00000;
                "/": font = 35'b00000_00001_00010_00100_01000_10000_00000;
                default: font = 35'd0;          // space and anything unknown
            endcase
        end
    endfunction
endmodule
