// ============================================================================
// Game 4: maze. A cube (the player) starts in the top-left cell of a fixed 15 x 15 maze and must
// reach the exit cell in the bottom-right corner. Each arrow key press moves the cube one cell,
// unless there is a wall in the way. When the cube reaches the exit, done goes high and the main
// FSM moves on to game 5.
//
//   active           1 while game 4 is the current game (the cube returns to the start when 0)
//   up/down/left/right   one-clock-cycle pulses from keyboard_input.v (arrow keys)
//   px, py           cube position (cell column 0-14, row 0-14), shown on the VGA screen
//   done             1 while the cube is on the exit cell
//
// The maze is stored as walls between cells (thin walls, like a printed maze):
//   V row y, bit for line x (x = 0..15): wall on the LEFT side of cell (x, y)   (line 15 = right edge)
//   H row y, bit for line x (x = 0..14): wall on the TOP  side of cell (x, y)   (row 15 = bottom edge)
// The shortest way out is 54 moves. The maze has 61 dead ends.
// ============================================================================
module game4_maze (clock, resetn, active, up, down, left, right, px, py, done);
    input        clock, resetn, active;
    input        up, down, left, right;
    output reg [3:0] px;
    output reg [3:0] py;
    output       done;

    parameter START_X = 4'd0,  START_Y = 4'd0;
    parameter EXIT_X  = 4'd14, EXIT_Y  = 4'd14;

    // the walls around the cube's current cell
    wire [15:0] vrow;                 // vertical walls of row py
    wire [14:0] hrow_top, hrow_bot;   // horizontal walls above row py and below it (= above row py + 1)
    maze_vrow VR (py, vrow);
    maze_hrow HT (py, hrow_top);
    maze_hrow HB (py + 1'b1, hrow_bot);

    wire wall_left  = vrow[4'd15 - px];
    wire wall_right = vrow[4'd14 - px];
    wire wall_up    = hrow_top[4'd14 - px];
    wire wall_down  = hrow_bot[4'd14 - px];

    always @(posedge clock) begin
        if (!resetn || !active) begin
            px <= START_X;
            py <= START_Y;
        end else if (up && !wall_up) begin
            py <= py - 1'b1;
        end else if (down && !wall_down) begin
            py <= py + 1'b1;
        end else if (left && !wall_left) begin
            px <= px - 1'b1;
        end else if (right && !wall_right) begin
            px <= px + 1'b1;
        end
    end

    assign done = active && (px == EXIT_X) && (py == EXIT_Y);
endmodule


// ============================================================================
// The maze walls (also used by vga_display to draw the maze).
// maze_vrow: the 16 vertical wall lines of cell row y (bit 15 = line 0 = left edge of the maze).
// maze_hrow: the 15 horizontal walls on the line above cell row y, y = 0..15 (bit 14 = column 0).
// ============================================================================
module maze_vrow (y, row);
    input  [3:0] y;
    output reg [15:0] row;
    always @(*) begin
        case (y)
            4'd0: row = 16'b1000000110001101;
            4'd1: row = 16'b1100101100111001;
            4'd2: row = 16'b1001000110001101;
            4'd3: row = 16'b1010010010011101;
            4'd4: row = 16'b1101101101110011;
            4'd5: row = 16'b1001111011000111;
            4'd6: row = 16'b1000000100011101;
            4'd7: row = 16'b1010110011100101;
            4'd8: row = 16'b1101110110011001;
            4'd9: row = 16'b1110111000110101;
            4'd10: row = 16'b1000010100010011;
            4'd11: row = 16'b1011101001011001;
            4'd12: row = 16'b1010000111000111;
            4'd13: row = 16'b1110110110101101;
            4'd14: row = 16'b1001100001001001;
            default: row = 16'hFFFF;
        endcase
    end
endmodule

module maze_hrow (y, row);
    input  [3:0] y;
    output reg [14:0] row;
    always @(*) begin
        case (y)
            4'd0: row = 15'b111111111111111;
            4'd1: row = 15'b001110100101010;
            4'd2: row = 15'b110111000110010;
            4'd3: row = 15'b110010100110011;
            4'd4: row = 15'b000011010100000;
            4'd5: row = 15'b011010110011100;
            4'd6: row = 15'b110100001101001;
            4'd7: row = 15'b110100111010110;
            4'd8: row = 15'b001001000010011;
            4'd9: row = 15'b000100101101110;
            4'd10: row = 15'b101111101110100;
            4'd11: row = 15'b100011001110011;
            4'd12: row = 15'b011010000100110;
            4'd13: row = 15'b101001011101100;
            4'd14: row = 15'b010001100010001;
            4'd15: row = 15'b111111111111111;
            default: row = 15'h7FFF;
        endcase
    end
endmodule
