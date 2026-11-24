// ============================================================================
// vga_display.v - everything VGA for Bomb Rush.
//   vga_display : wrapper used by the main file. Takes the screen code, drives the VGA pins.
//   vga_screen  : scans the 160x120 screen and works out the colour of each pixel.
//
// Screens (all text is drawn with the 5x7 font; "big" = 3x3 pixels per font pixel, "small" = 1x1):
//   HOME  : big "HOME", small "PRESS ENTER TO BEGIN", small "PRESS 1 2 3: DIFFICULTY",
//           then the selected difficulty in big letters (EASY / MEDIUM / HARD, green / yellow / red)
//           with its time in small letters under it (3 MINUTES / 2 MINUTES / 1 MINUTE).
//   GAME 1: big "GAME 1:", small "CONVERT TO BINARY", and the decimal number (1-100) in big white.
//   GAME 4: the maze (15 x 15 cells of 7x7 pixels, thin white walls), the cube (cyan) and the exit (green), with the
//           small title "GAME 4: ESCAPE" above it.
//   GAME 2, 3, 5, WIN, LOSE: big title; WIN and LOSE also show small "PRESS R TO RESTART".
// Needs the course files vga_adapter.v, vga_controller.v, vga_pll.v, vga_address_translator.v
// and black_160_9.mif in the project.
// ============================================================================

// screen: 0 = "HOME", 1..5 = "GAME 1".."GAME 5", 6 = "WIN", 7 = "LOSE"
module vga_display (clock, resetn, screen, show_number, game_number, difficulty, maze_x, maze_y,
                    VGA_R, VGA_G, VGA_B, VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK);
    input        clock;            // 50 MHz
    input        resetn;
    input  [2:0] screen;
    input        show_number;      // 1 = game 1 layout (number + "CONVERT TO BINARY")
    input  [6:0] game_number;      // decimal number to show, 1-100
    input  [1:0] difficulty;       // 11 = EASY (3 min), 10 = MEDIUM (2 min), 01 / 00 = HARD (1 min)
    input  [3:0] maze_x;           // game 4: cube position (column 0-14)
    input  [3:0] maze_y;           // game 4: cube position (row 0-14)
    output [7:0] VGA_R, VGA_G, VGA_B;
    output       VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK;

    wire [7:0] vga_x;
    wire [6:0] vga_y;
    wire [8:0] vga_color;
    wire       vga_write;

    vga_screen SCR (clock, resetn, screen, show_number, game_number, difficulty, maze_x, maze_y,
                    vga_x, vga_y, vga_color, vga_write);

    vga_adapter VGA (.resetn(resetn), .clock(clock),
                     .color(vga_color), .x(vga_x), .y(vga_y), .write(vga_write),
                     .VGA_R(VGA_R), .VGA_G(VGA_G), .VGA_B(VGA_B),
                     .VGA_HS(VGA_HS), .VGA_VS(VGA_VS), .VGA_BLANK_N(VGA_BLANK_N),
                     .VGA_SYNC_N(VGA_SYNC_N), .VGA_CLK(VGA_CLK));
        defparam VGA.RESOLUTION       = "160x120";
        defparam VGA.COLOR_DEPTH      = 9;
        defparam VGA.BACKGROUND_IMAGE = "./black_160_9.mif";
endmodule


// ============================================================================
// VGA screen drawer. Continuously scans all 160x120 pixels and writes each one to the
// vga_adapter. The colour of every pixel is worked out from the current inputs, so the
// picture updates by itself within one frame (about 0.4 ms) of any change.
//
// Big text: 5x7 font, each font pixel is 3x3 screen pixels, 16-pixel character cells.
// Small text: 5x7 font at 1x, 6-pixel character cells. Everything is centred on screen.
// Colours are 9-bit {R[2:0], G[2:0], B[2:0]}.
//
// Three kinds of text:
//   title  (big)   : HOME / GAME n / GAME 1: / WIN / LOSE
//   row 2  (big)   : the number (game 1) or the difficulty word (HOME)
//   small lines    : the messages M_xxx below, picked by which row the scan is on
// ============================================================================
module vga_screen (clock, resetn, screen, show_num, num, diff, mx_cube, my_cube, x, y, color, write);
    input        clock, resetn;
    input  [2:0] screen;
    input        show_num;
    input  [6:0] num;
    input  [1:0] diff;
    input  [3:0] mx_cube;               // game 4: cube column
    input  [3:0] my_cube;               // game 4: cube row
    output reg [7:0] x;
    output reg [6:0] y;
    output reg [8:0] color;
    output reg       write;

    // ---- vertical layout (top row of each piece of text) ----
    parameter Y0      = 7'd50;          // title of GAME 2-5 / WIN / LOSE (text is 21 pixels tall)
    parameter Y0_HOME = 7'd6;           // title of HOME
    parameter Y0_TOP  = 7'd24;          // title of game 1 ("GAME 1:")
    parameter SUB_Y0  = 7'd54;          // game 1: "CONVERT TO BINARY"
    parameter NUM_Y0  = 7'd76;          // game 1: the number
    parameter H_L1_Y  = 7'd34;          // HOME: "PRESS ENTER TO BEGIN"
    parameter H_L2_Y  = 7'd46;          // HOME: "PRESS 1 2 3: DIFFICULTY"
    parameter H_DIF_Y = 7'd62;          // HOME: EASY / MEDIUM / HARD (big)
    parameter H_MIN_Y = 7'd88;          // HOME: "3 MINUTES" ...
    parameter E_L1_Y  = 7'd80;          // WIN / LOSE: "PRESS R TO RESTART"
    parameter M_TITLE_Y = 7'd3;         // GAME 4: small title
    parameter MAZE_X0 = 8'd27;          // GAME 4: left edge of the maze (15 cells * 7 + 1 = 106 pixels wide)
    parameter MAZE_Y0 = 7'd13;          // GAME 4: top edge of the maze (106 pixels tall)

    // ---- the small messages (ASCII) ----
    localparam [8*20-1:0] M_BEGIN = "PRESS ENTER TO BEGIN";      // 20 letters, id 1
    localparam [8*23-1:0] M_DIFF  = "PRESS 1 2 3: DIFFICULTY";   // 23 letters, id 2
    localparam [8*9-1:0]  M_MIN3  = "3 MINUTES";                 //  9 letters, id 3
    localparam [8*9-1:0]  M_MIN2  = "2 MINUTES";                 //  9 letters, id 4
    localparam [8*8-1:0]  M_MIN1  = "1 MINUTE";                  //  8 letters, id 5
    localparam [8*18-1:0] M_RESTART = "PRESS R TO RESTART";      // 18 letters, id 6
    localparam [8*17-1:0] M_CONV  = "CONVERT TO BINARY";         // 17 letters, id 7
    localparam [8*14-1:0] M_G4    = "GAME 4: ESCAPE";            // 14 letters, id 8
    localparam [8*4-1:0]  W_EASY   = "EASY";
    localparam [8*6-1:0]  W_MEDIUM = "MEDIUM";
    localparam [8*4-1:0]  W_HARD   = "HARD";

    wire is_home = (screen == 3'd0);
    wire is_end  = (screen == 3'd6) || (screen == 3'd7);
    wire is_maze = (screen == 3'd4);
    wire is_easy    = (diff == 2'b11);
    wire is_med  = (diff == 2'b10);

    // ---- scan counters ----
    reg [7:0] sx;
    reg [6:0] sy;
    always @(posedge clock)
        if (!resetn) begin sx <= 8'd0; sy <= 7'd0; end
        else if (sx == 8'd159) begin
            sx <= 8'd0;
            sy <= (sy == 7'd119) ? 7'd0 : sy + 1'b1;
        end
        else sx <= sx + 1'b1;

    // ---- title (big) ----
    wire [3:0] len = (screen == 3'd0) ? 4'd4 :          // HOME
                     (screen == 3'd6) ? 4'd3 :          // WIN
                     (screen == 3'd7) ? 4'd4 :          // LOSE
                     show_num         ? 4'd7 : 4'd6;    // "GAME 1:" (with colon) : GAME n
    wire [7:0] x0    = 8'd80 - {len, 3'b000};           // 80 - 8*len  (centres 16*len pixels)
    wire [7:0] width = {len, 4'b0000} - 8'd1;           // 16*len - 1
    wire [7:0] dx    = sx - x0;
    wire [6:0] ty0   = show_num ? Y0_TOP : (is_home ? Y0_HOME : Y0);   // where the title starts
    wire [6:0] dy    = sy - ty0;

    wire in_x = (sx >= x0) && (dx < width);
    wire in_y = (sy >= ty0) && (dy < 7'd21);

    wire [2:0] ci  = dx[6:4];                           // which character
    wire [3:0] cx  = dx[3:0];                           // pixel inside the 16-pixel cell
    wire [2:0] col = cx / 3;                            // font column 0..4 (5 = gap)
    wire [2:0] row = dy / 3;                            // font row 0..6

    wire [5:0] ch   = char_at(screen, ci);
    wire [4:0] bits = glyph(ch, row);
    wire       on   = !is_maze && in_x && in_y && (col < 3'd5) && bits[3'd4 - col];   // (no big title on the maze)

    // ---- small text: which message (if any) is on this scan row ----
    reg [3:0] sid;                                      // 0 = none, 1..7 = the messages above
    reg [6:0] sy0;                                      // top row of that message
    always @(*) begin
        sid = 4'd0;
        sy0 = 7'd0;
        if (is_home) begin
            if (sy >= H_L1_Y && sy < H_L1_Y + 7'd7) begin
                sid = 4'd1;  sy0 = H_L1_Y;
            end else if (sy >= H_L2_Y && sy < H_L2_Y + 7'd7) begin
                sid = 4'd2;  sy0 = H_L2_Y;
            end else if (sy >= H_MIN_Y && sy < H_MIN_Y + 7'd7) begin
                sid = is_easy ? 4'd3 : (is_med ? 4'd4 : 4'd5);  sy0 = H_MIN_Y;
            end
        end else if (is_end) begin
            if (sy >= E_L1_Y && sy < E_L1_Y + 7'd7) begin
                sid = 4'd6;  sy0 = E_L1_Y;
            end
        end else if (is_maze) begin
            if (sy >= M_TITLE_Y && sy < M_TITLE_Y + 7'd7) begin
                sid = 4'd8;  sy0 = M_TITLE_Y;
            end
        end else if (show_num) begin
            if (sy >= SUB_Y0 && sy < SUB_Y0 + 7'd7) begin
                sid = 4'd7;  sy0 = SUB_Y0;
            end
        end
    end

    reg [4:0] slen;                                     // number of letters in message sid
    always @(*) begin
        case (sid)
            4'd1:    slen = 5'd20;
            4'd2:    slen = 5'd23;
            4'd3:    slen = 5'd9;
            4'd4:    slen = 5'd9;
            4'd5:    slen = 5'd8;
            4'd6:    slen = 5'd18;
            4'd7:    slen = 5'd17;
            4'd8:    slen = 5'd14;
            default: slen = 5'd1;
        endcase
    end

    wire [7:0] sx0    = 8'd81 - {2'b00, slen, 1'b0} - {3'b000, slen};   // 81 - 3*slen (centred)
    wire [7:0] swidth = {2'b00, slen, 1'b0} * 8'd3 - 8'd1;              // 6*slen - 1
    wire [7:0] sdx    = sx - sx0;
    wire [6:0] sdy    = sy - sy0;
    wire       s_in_x = (sx >= sx0) && (sdx < swidth);
    wire [4:0] sci    = sdx / 6;                        // which letter
    wire [2:0] scol   = sdx % 6;                        // 0..4 = font column, 5 = gap

    wire [7:0] sasc   = msg_byte(sid, sci);
    wire [4:0] sbits  = glyph(ascii_code(sasc), sdy[2:0]);
    wire       son    = (sid != 4'd0) && s_in_x && (scol < 3'd5) && sbits[3'd4 - scol];

    // ---- row 2 (big): the digits of num (game 1) or the difficulty word (HOME) ----
    wire [6:0] n_rest = (num == 7'd100) ? 7'd0 : num;   // 0..99 (100 is handled separately)
    wire [3:0] n_tens = n_rest / 10;
    wire [3:0] n_ones = n_rest % 10;
    wire [3:0] nd     = (num >= 7'd100) ? 4'd3 :        // number of digits
                        (num >= 7'd10)  ? 4'd2 : 4'd1;
    wire [3:0] wl     = is_med ? 4'd6 : 4'd4;           // letters in the difficulty word
    wire [3:0] rlen   = is_home ? wl : nd;
    wire [6:0] r2y    = is_home ? H_DIF_Y : NUM_Y0;
    wire       r2_en  = is_home || show_num;

    wire [7:0] nx0    = 8'd80 - {rlen, 3'b000};         // centred, like the title
    wire [7:0] nwidth = {rlen, 4'b0000} - 8'd1;
    wire [7:0] ndx    = sx - nx0;
    wire [6:0] ndy    = sy - r2y;

    wire n_in_x = (sx >= nx0) && (ndx < nwidth);
    wire n_in_y = (sy >= r2y) && (ndy < 7'd21);

    wire [2:0] nci  = ndx[6:4];                         // which digit / letter
    wire [3:0] ncx  = ndx[3:0];
    wire [2:0] ncol = ncx / 3;
    wire [2:0] nrow = ndy / 3;

    reg [3:0] digit;                                    // the digit in this cell
    always @(*) begin
        if (nd == 4'd3) begin
            digit = (nci == 3'd0) ? 4'd1 : 4'd0;        // 100
        end else if (nd == 4'd2) begin
            digit = (nci == 3'd0) ? n_tens : n_ones;
        end else begin
            digit = n_ones;
        end
    end

    wire [7:0] wasc  = is_easy ? W_EASY[8*(3 - nci) +: 8] :
                       is_med ? W_MEDIUM[8*(5 - nci) +: 8] : W_HARD[8*(3 - nci) +: 8];
    wire [5:0] nch   = is_home ? ascii_code(wasc) : digit_code(digit);
    wire [4:0] nbits = glyph(nch, nrow);
    wire       non   = r2_en && n_in_x && n_in_y && (ncol < 3'd5) && nbits[3'd4 - ncol];

    // ---- colours ----
    wire [8:0] fg = (screen == 3'd0) ? 9'b000_111_111 :   // HOME: cyan
                    (screen == 3'd6) ? 9'b000_111_000 :   // WIN : green
                    (screen == 3'd7) ? 9'b111_000_000 :   // LOSE: red
                                       9'b111_111_000;    // GAME: yellow
    wire [8:0] dcol = is_easy   ? 9'b000_111_000 :           // EASY: green
                      is_med ? 9'b111_111_000 :           // MEDIUM: yellow
                               9'b111_000_000;            // HARD: red
    wire [8:0] white = 9'b111_111_111;
    wire [8:0] bg    = 9'b000_000_000;                    // black
    wire [8:0] scolor = (sid == 4'd7 || sid == 4'd8) ? fg :   // game 1 subtitle, game 4 title
                        (sid >= 4'd3 && sid <= 4'd5) ? dcol : // "N MINUTES" matches the difficulty
                        white;                                // instructions
    wire [8:0] ncolor = is_home ? dcol : white;               // difficulty word / number

    // ---- game 4: the maze. Cells are 7x7 pixels; wall lines are 1 pixel wide and sit on pixel
    //      columns / rows 0, 7, 14 ... 105 of the maze area. Inside a cell (6x6 pixels) are the cube and the exit.
    wire [7:0] mdx = sx - MAZE_X0;
    wire [6:0] mdy = sy - MAZE_Y0;
    wire       m_in = is_maze && (sx >= MAZE_X0) && (mdx < 8'd106) && (sy >= MAZE_Y0) && (mdy < 7'd106);
    wire [3:0] m_ci = mdx / 7;                         // wall line / cell column 0..15
    wire [2:0] m_a  = mdx % 7;                         // 0 = on a vertical wall line
    wire [3:0] m_cj = mdy / 7;                         // wall line / cell row 0..15
    wire [2:0] m_b  = mdy % 7;                         // 0 = on a horizontal wall line

    wire [15:0] vr_cur, vr_up;                         // vertical walls of this row / the row above
    wire [14:0] hr_cur;                                // horizontal walls on the line above this row
    maze_vrow MV0 (m_cj, vr_cur);
    maze_vrow MV1 (m_cj - 1'b1, vr_up);
    maze_hrow MH0 (m_cj, hr_cur);

    wire v_here = (m_cj < 4'd15) && vr_cur[4'd15 - m_ci];      // wall segment on this line, this row
    wire v_up   = (m_cj > 4'd0)  && vr_up [4'd15 - m_ci];      // ... the row above (for corner pixels)
    wire h_here = (m_ci < 4'd15) && hr_cur[4'd14 - m_ci];      // wall on this line, this column
    wire h_left = (m_ci > 4'd0)  && hr_cur[4'd15 - m_ci];      // ... the column to the left (for corners)

    wire m_wall = (m_a != 3'd0 && m_b != 3'd0) ? 1'b0 :        // inside a cell
                  (m_a == 3'd0 && m_b != 3'd0) ? v_here :      // on a vertical line
                  (m_a != 3'd0 && m_b == 3'd0) ? h_here :      // on a horizontal line
                                                 (v_here || v_up || h_here || h_left);   // corner
    wire m_cube = (m_ci == mx_cube) && (m_cj == my_cube) &&    // the cube: 4x4 pixels in the middle of its cell
                  (m_a >= 3'd2) && (m_a <= 3'd5) && (m_b >= 3'd2) && (m_b <= 3'd5);
    wire m_exit = (m_ci == 4'd14) && (m_cj == 4'd14) && (m_a != 3'd0) && (m_b != 3'd0);   // the exit cell
    wire [8:0] mcolor = m_wall ? white :                         // wall: white
                        m_cube ? 9'b000_111_111 :                // cube: cyan
                        m_exit ? 9'b000_111_000 :                // exit: green
                                 bg;

    // ---- register the pixel before sending it to the adapter ----
    always @(posedge clock) begin
        x     <= sx;
        y     <= sy;
        color <= m_in ? mcolor : (on ? fg : (son ? scolor : (non ? ncolor : bg)));
        write <= resetn;
    end

    // ---- which message letter: ASCII byte i (0 = first letter) of message id ----
    function [7:0] msg_byte;
        input [3:0] id;
        input [4:0] i;
        begin
            case (id)
                4'd1:    msg_byte = M_BEGIN  [8*(19 - i) +: 8];
                4'd2:    msg_byte = M_DIFF   [8*(22 - i) +: 8];
                4'd3:    msg_byte = M_MIN3   [8*(8 - i) +: 8];
                4'd4:    msg_byte = M_MIN2   [8*(8 - i) +: 8];
                4'd5:    msg_byte = M_MIN1   [8*(7 - i) +: 8];
                4'd6:    msg_byte = M_RESTART[8*(17 - i) +: 8];
                4'd7:    msg_byte = M_CONV   [8*(16 - i) +: 8];
                4'd8:    msg_byte = M_G4     [8*(13 - i) +: 8];
                default: msg_byte = 8'h20;
            endcase
        end
    endfunction

    // ---- ASCII -> character code used by glyph() ----
    function [5:0] ascii_code;
        input [7:0] a;
        begin
            case (a)
                "H": ascii_code = 6'd1;   "O": ascii_code = 6'd2;   "M": ascii_code = 6'd3;
                "E": ascii_code = 6'd4;   "G": ascii_code = 6'd5;   "A": ascii_code = 6'd6;
                "W": ascii_code = 6'd7;   "I": ascii_code = 6'd8;   "N": ascii_code = 6'd9;
                "L": ascii_code = 6'd10;  "S": ascii_code = 6'd11;
                "1": ascii_code = 6'd12;  "2": ascii_code = 6'd13;  "3": ascii_code = 6'd14;
                "4": ascii_code = 6'd15;  "5": ascii_code = 6'd16;  "6": ascii_code = 6'd17;
                "7": ascii_code = 6'd18;  "8": ascii_code = 6'd19;  "9": ascii_code = 6'd20;
                "0": ascii_code = 6'd21;
                "C": ascii_code = 6'd22;  "V": ascii_code = 6'd23;  "R": ascii_code = 6'd24;
                "T": ascii_code = 6'd25;  "B": ascii_code = 6'd26;  "Y": ascii_code = 6'd27;
                ":": ascii_code = 6'd28;
                "P": ascii_code = 6'd29;  "D": ascii_code = 6'd30;  "U": ascii_code = 6'd31;
                "F": ascii_code = 6'd32;
                default: ascii_code = 6'd0;   // space
            endcase
        end
    endfunction

    // ---- character codes: 0 space, 1 H, 2 O, 3 M, 4 E, 5 G, 6 A, 7 W, 8 I, 9 N, 10 L, 11 S,
    //      12..20 = digits 1..9, 21 = digit 0, 22 C, 23 V, 24 R, 25 T, 26 B, 27 Y, 28 ':',
    //      29 P, 30 D, 31 U, 32 F ----
    function [5:0] digit_code;
        input [3:0] d;
        begin
            if (d == 4'd0) digit_code = 6'd21;
            else           digit_code = 6'd11 + {2'b00, d};
        end
    endfunction

    function [5:0] char_at;
        input [2:0] scr;
        input [2:0] idx;
        begin
            case (scr)
                3'd0: case (idx)                      // HOME
                          3'd0: char_at = 5'd1;  3'd1: char_at = 5'd2;
                          3'd2: char_at = 5'd3;  3'd3: char_at = 5'd4;
                          default: char_at = 5'd0;
                      endcase
                3'd6: case (idx)                      // WIN
                          3'd0: char_at = 5'd7;  3'd1: char_at = 5'd8;
                          3'd2: char_at = 5'd9;
                          default: char_at = 5'd0;
                      endcase
                3'd7: case (idx)                      // LOSE
                          3'd0: char_at = 5'd10; 3'd1: char_at = 5'd2;
                          3'd2: char_at = 5'd11; 3'd3: char_at = 5'd4;
                          default: char_at = 5'd0;
                      endcase
                default: case (idx)                   // GAME n  (n = screen code 1..5)
                          3'd0: char_at = 5'd5;  3'd1: char_at = 5'd6;
                          3'd2: char_at = 5'd3;  3'd3: char_at = 5'd4;
                          3'd4: char_at = 5'd0;
                          3'd5: char_at = 5'd11 + {2'b00, scr};   // 12..16
                          3'd6: char_at = 5'd28;                  // ':' (only drawn when show_num)
                          default: char_at = 5'd0;
                      endcase
            endcase
        end
    endfunction

    // ---- 5x7 font: one row of a character, leftmost pixel in bit 4 ----
    function [4:0] glyph;
        input [5:0] c;
        input [2:0] r;
        begin
            case (c)
                5'd1:  case (r)   // H
                    3'd0: glyph = 5'b10001; 3'd1: glyph = 5'b10001; 3'd2: glyph = 5'b10001;
                    3'd3: glyph = 5'b11111; 3'd4: glyph = 5'b10001; 3'd5: glyph = 5'b10001;
                    default: glyph = 5'b10001; endcase
                5'd2:  case (r)   // O
                    3'd0: glyph = 5'b01110; 3'd1: glyph = 5'b10001; 3'd2: glyph = 5'b10001;
                    3'd3: glyph = 5'b10001; 3'd4: glyph = 5'b10001; 3'd5: glyph = 5'b10001;
                    default: glyph = 5'b01110; endcase
                5'd3:  case (r)   // M
                    3'd0: glyph = 5'b10001; 3'd1: glyph = 5'b11011; 3'd2: glyph = 5'b10101;
                    3'd3: glyph = 5'b10101; 3'd4: glyph = 5'b10001; 3'd5: glyph = 5'b10001;
                    default: glyph = 5'b10001; endcase
                5'd4:  case (r)   // E
                    3'd0: glyph = 5'b11111; 3'd1: glyph = 5'b10000; 3'd2: glyph = 5'b10000;
                    3'd3: glyph = 5'b11110; 3'd4: glyph = 5'b10000; 3'd5: glyph = 5'b10000;
                    default: glyph = 5'b11111; endcase
                5'd5:  case (r)   // G
                    3'd0: glyph = 5'b01110; 3'd1: glyph = 5'b10001; 3'd2: glyph = 5'b10000;
                    3'd3: glyph = 5'b10111; 3'd4: glyph = 5'b10001; 3'd5: glyph = 5'b10001;
                    default: glyph = 5'b01111; endcase
                5'd6:  case (r)   // A
                    3'd0: glyph = 5'b01110; 3'd1: glyph = 5'b10001; 3'd2: glyph = 5'b10001;
                    3'd3: glyph = 5'b11111; 3'd4: glyph = 5'b10001; 3'd5: glyph = 5'b10001;
                    default: glyph = 5'b10001; endcase
                5'd7:  case (r)   // W
                    3'd0: glyph = 5'b10001; 3'd1: glyph = 5'b10001; 3'd2: glyph = 5'b10001;
                    3'd3: glyph = 5'b10101; 3'd4: glyph = 5'b10101; 3'd5: glyph = 5'b11011;
                    default: glyph = 5'b10001; endcase
                5'd8:  case (r)   // I
                    3'd0: glyph = 5'b01110; 3'd1: glyph = 5'b00100; 3'd2: glyph = 5'b00100;
                    3'd3: glyph = 5'b00100; 3'd4: glyph = 5'b00100; 3'd5: glyph = 5'b00100;
                    default: glyph = 5'b01110; endcase
                5'd9:  case (r)   // N
                    3'd0: glyph = 5'b10001; 3'd1: glyph = 5'b11001; 3'd2: glyph = 5'b10101;
                    3'd3: glyph = 5'b10011; 3'd4: glyph = 5'b10001; 3'd5: glyph = 5'b10001;
                    default: glyph = 5'b10001; endcase
                5'd10: case (r)   // L
                    3'd0: glyph = 5'b10000; 3'd1: glyph = 5'b10000; 3'd2: glyph = 5'b10000;
                    3'd3: glyph = 5'b10000; 3'd4: glyph = 5'b10000; 3'd5: glyph = 5'b10000;
                    default: glyph = 5'b11111; endcase
                5'd11: case (r)   // S
                    3'd0: glyph = 5'b01111; 3'd1: glyph = 5'b10000; 3'd2: glyph = 5'b10000;
                    3'd3: glyph = 5'b01110; 3'd4: glyph = 5'b00001; 3'd5: glyph = 5'b00001;
                    default: glyph = 5'b11110; endcase
                5'd12: case (r)   // 1
                    3'd0: glyph = 5'b00100; 3'd1: glyph = 5'b01100; 3'd2: glyph = 5'b00100;
                    3'd3: glyph = 5'b00100; 3'd4: glyph = 5'b00100; 3'd5: glyph = 5'b00100;
                    default: glyph = 5'b01110; endcase
                5'd13: case (r)   // 2
                    3'd0: glyph = 5'b01110; 3'd1: glyph = 5'b10001; 3'd2: glyph = 5'b00001;
                    3'd3: glyph = 5'b00010; 3'd4: glyph = 5'b00100; 3'd5: glyph = 5'b01000;
                    default: glyph = 5'b11111; endcase
                5'd14: case (r)   // 3
                    3'd0: glyph = 5'b11110; 3'd1: glyph = 5'b00001; 3'd2: glyph = 5'b00001;
                    3'd3: glyph = 5'b01110; 3'd4: glyph = 5'b00001; 3'd5: glyph = 5'b00001;
                    default: glyph = 5'b11110; endcase
                5'd15: case (r)   // 4
                    3'd0: glyph = 5'b00010; 3'd1: glyph = 5'b00110; 3'd2: glyph = 5'b01010;
                    3'd3: glyph = 5'b10010; 3'd4: glyph = 5'b11111; 3'd5: glyph = 5'b00010;
                    default: glyph = 5'b00010; endcase
                5'd16: case (r)   // 5
                    3'd0: glyph = 5'b11111; 3'd1: glyph = 5'b10000; 3'd2: glyph = 5'b11110;
                    3'd3: glyph = 5'b00001; 3'd4: glyph = 5'b00001; 3'd5: glyph = 5'b10001;
                    default: glyph = 5'b01110; endcase
                5'd17: case (r)   // 6
                    3'd0: glyph = 5'b00110; 3'd1: glyph = 5'b01000; 3'd2: glyph = 5'b10000;
                    3'd3: glyph = 5'b11110; 3'd4: glyph = 5'b10001; 3'd5: glyph = 5'b10001;
                    default: glyph = 5'b01110; endcase
                5'd18: case (r)   // 7
                    3'd0: glyph = 5'b11111; 3'd1: glyph = 5'b00001; 3'd2: glyph = 5'b00010;
                    3'd3: glyph = 5'b00100; 3'd4: glyph = 5'b01000; 3'd5: glyph = 5'b01000;
                    default: glyph = 5'b01000; endcase
                5'd19: case (r)   // 8
                    3'd0: glyph = 5'b01110; 3'd1: glyph = 5'b10001; 3'd2: glyph = 5'b10001;
                    3'd3: glyph = 5'b01110; 3'd4: glyph = 5'b10001; 3'd5: glyph = 5'b10001;
                    default: glyph = 5'b01110; endcase
                5'd20: case (r)   // 9
                    3'd0: glyph = 5'b01110; 3'd1: glyph = 5'b10001; 3'd2: glyph = 5'b10001;
                    3'd3: glyph = 5'b01111; 3'd4: glyph = 5'b00001; 3'd5: glyph = 5'b00010;
                    default: glyph = 5'b01100; endcase
                5'd21: case (r)   // 0
                    3'd0: glyph = 5'b01110; 3'd1: glyph = 5'b10001; 3'd2: glyph = 5'b10011;
                    3'd3: glyph = 5'b10101; 3'd4: glyph = 5'b11001; 3'd5: glyph = 5'b10001;
                    default: glyph = 5'b01110; endcase
                5'd22: case (r)   // C
                    3'd0: glyph = 5'b01110; 3'd1: glyph = 5'b10001; 3'd2: glyph = 5'b10000;
                    3'd3: glyph = 5'b10000; 3'd4: glyph = 5'b10000; 3'd5: glyph = 5'b10001;
                    default: glyph = 5'b01110; endcase
                5'd23: case (r)   // V
                    3'd0: glyph = 5'b10001; 3'd1: glyph = 5'b10001; 3'd2: glyph = 5'b10001;
                    3'd3: glyph = 5'b10001; 3'd4: glyph = 5'b10001; 3'd5: glyph = 5'b01010;
                    default: glyph = 5'b00100; endcase
                5'd24: case (r)   // R
                    3'd0: glyph = 5'b11110; 3'd1: glyph = 5'b10001; 3'd2: glyph = 5'b10001;
                    3'd3: glyph = 5'b11110; 3'd4: glyph = 5'b10100; 3'd5: glyph = 5'b10010;
                    default: glyph = 5'b10001; endcase
                5'd25: case (r)   // T
                    3'd0: glyph = 5'b11111; 3'd1: glyph = 5'b00100; 3'd2: glyph = 5'b00100;
                    3'd3: glyph = 5'b00100; 3'd4: glyph = 5'b00100; 3'd5: glyph = 5'b00100;
                    default: glyph = 5'b00100; endcase
                5'd26: case (r)   // B
                    3'd0: glyph = 5'b11110; 3'd1: glyph = 5'b10001; 3'd2: glyph = 5'b10001;
                    3'd3: glyph = 5'b11110; 3'd4: glyph = 5'b10001; 3'd5: glyph = 5'b10001;
                    default: glyph = 5'b11110; endcase
                5'd27: case (r)   // Y
                    3'd0: glyph = 5'b10001; 3'd1: glyph = 5'b10001; 3'd2: glyph = 5'b01010;
                    3'd3: glyph = 5'b00100; 3'd4: glyph = 5'b00100; 3'd5: glyph = 5'b00100;
                    default: glyph = 5'b00100; endcase
                5'd28: case (r)   // :
                    3'd0: glyph = 5'b00000; 3'd1: glyph = 5'b00100; 3'd2: glyph = 5'b00100;
                    3'd3: glyph = 5'b00000; 3'd4: glyph = 5'b00100; 3'd5: glyph = 5'b00100;
                    default: glyph = 5'b00000; endcase
                5'd29: case (r)   // P
                    3'd0: glyph = 5'b11110; 3'd1: glyph = 5'b10001; 3'd2: glyph = 5'b10001;
                    3'd3: glyph = 5'b11110; 3'd4: glyph = 5'b10000; 3'd5: glyph = 5'b10000;
                    default: glyph = 5'b10000; endcase
                5'd30: case (r)   // D
                    3'd0: glyph = 5'b11110; 3'd1: glyph = 5'b10001; 3'd2: glyph = 5'b10001;
                    3'd3: glyph = 5'b10001; 3'd4: glyph = 5'b10001; 3'd5: glyph = 5'b10001;
                    default: glyph = 5'b11110; endcase
                5'd31: case (r)   // U
                    3'd0: glyph = 5'b10001; 3'd1: glyph = 5'b10001; 3'd2: glyph = 5'b10001;
                    3'd3: glyph = 5'b10001; 3'd4: glyph = 5'b10001; 3'd5: glyph = 5'b10001;
                    default: glyph = 5'b01110; endcase
                6'd32: case (r)   // F
                    3'd0: glyph = 5'b11111; 3'd1: glyph = 5'b10000; 3'd2: glyph = 5'b10000;
                    3'd3: glyph = 5'b11110; 3'd4: glyph = 5'b10000; 3'd5: glyph = 5'b10000;
                    default: glyph = 5'b10000; endcase
                default: glyph = 5'b00000;   // space
            endcase
        end
    endfunction
endmodule
