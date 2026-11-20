// ============================================================================
// vga_display.v - everything VGA for Bomb Rush.
//   vga_display : wrapper used by the main file. Takes the screen code, drives the VGA pins.
//   vga_screen  : scans the 160x120 screen and works out the colour of each pixel.
// Needs the course files vga_adapter.v, vga_controller.v, vga_pll.v, vga_address_translator.v
// and black_160_9.mif in the project.
// ============================================================================

// screen: 0 = "HOME", 1..5 = "GAME 1".."GAME 5", 6 = "WIN", 7 = "LOSE"
module vga_display (clock, resetn, screen,
                    VGA_R, VGA_G, VGA_B, VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK);
    input        clock;            // 50 MHz
    input        resetn;
    input  [2:0] screen;
    output [7:0] VGA_R, VGA_G, VGA_B;
    output       VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK;

    wire [7:0] vga_x;
    wire [6:0] vga_y;
    wire [8:0] vga_color;
    wire       vga_write;

    vga_screen SCR (clock, resetn, screen, vga_x, vga_y, vga_color, vga_write);

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
// vga_adapter. The colour of every pixel is worked out from the current screen code,
// so the picture updates by itself within one frame (about 0.4 ms) of a state change.
//
//   screen: 0 = "HOME", 1..5 = "GAME 1".."GAME 5", 6 = "WIN", 7 = "LOSE"
//
// Text is drawn with a 5x7 font, each font pixel is 3x3 screen pixels, and each character
// cell is 16 pixels wide, so 'which character' is just dx[6:4]. Text is centred on screen.
// Colours are 9-bit {R[2:0], G[2:0], B[2:0]}.
// ============================================================================
module vga_screen (clock, resetn, screen, x, y, color, write);
    input        clock, resetn;
    input  [2:0] screen;
    output reg [7:0] x;
    output reg [6:0] y;
    output reg [8:0] color;
    output reg       write;

    parameter Y0 = 7'd50;               // top row of the text (text is 21 pixels tall)

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

    // ---- text size and position ----
    wire [3:0] len = (screen == 3'd0) ? 4'd4 :          // HOME
                     (screen == 3'd6) ? 4'd3 :          // WIN
                     (screen == 3'd7) ? 4'd4 : 4'd6;    // LOSE : GAME n
    wire [7:0] x0    = 8'd80 - {len, 3'b000};           // 80 - 8*len  (centres 16*len pixels)
    wire [7:0] width = {len, 4'b0000} - 8'd1;           // 16*len - 1
    wire [7:0] dx    = sx - x0;
    wire [6:0] dy    = sy - Y0;

    wire in_x = (sx >= x0) && (dx < width);
    wire in_y = (sy >= Y0) && (dy < 7'd21);

    wire [2:0] ci  = dx[6:4];                           // which character
    wire [3:0] cx  = dx[3:0];                           // pixel inside the 16-pixel cell
    wire [2:0] col = cx / 3;                            // font column 0..4 (5 = gap)
    wire [2:0] row = dy / 3;                            // font row 0..6

    wire [4:0] ch   = char_at(screen, ci);
    wire [4:0] bits = glyph(ch, row);
    wire       on   = in_x && in_y && (col < 3'd5) && bits[3'd4 - col];

    // ---- colours ----
    wire [8:0] fg = (screen == 3'd0) ? 9'b000_111_111 :   // HOME: cyan
                    (screen == 3'd6) ? 9'b000_111_000 :   // WIN : green
                    (screen == 3'd7) ? 9'b111_000_000 :   // LOSE: red
                                       9'b111_111_000;    // GAME: yellow
    wire [8:0] bg = 9'b000_000_000;                       // black

    // ---- register the pixel before sending it to the adapter ----
    always @(posedge clock) begin
        x     <= sx;
        y     <= sy;
        color <= on ? fg : bg;
        write <= resetn;
    end

    // ---- character codes: 0 space, 1 H, 2 O, 3 M, 4 E, 5 G, 6 A, 7 W, 8 I, 9 N, 10 L, 11 S,
    //      12..16 = digits 1..5 ----
    function [4:0] char_at;
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
                          default: char_at = 5'd0;
                      endcase
            endcase
        end
    endfunction

    // ---- 5x7 font: one row of a character, leftmost pixel in bit 4 ----
    function [4:0] glyph;
        input [4:0] c;
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
                default: glyph = 5'b00000;   // space
            endcase
        end
    endfunction
endmodule
