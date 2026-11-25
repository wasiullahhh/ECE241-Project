// ============================================================================
// keyboard_input.v - turns the PS/2 keyboard into one-clock-cycle key pulses.
//
// The course PS2_Controller module does the electrical work (PS2_CLK / PS2_DAT) and gives one
// byte at a time, with received_data_en = 1 for one clock when a byte arrives. The byte is a
// "scan code". A keyboard sends:
//     press   : the key's scan code            (e.g. 5A for Enter)
//     release : F0, then the key's scan code   (the "break" code)
//     extended keys (keypad Enter, arrows...) have an E0 byte in front
// This module acts only on a press. F0 means "ignore the next code" (it is the release of a key).
//
// Outputs (each is high for exactly one clock cycle when the key is pressed):
//   enter_p   Enter (main or keypad)         r_p   R
//   one_p / two_p / three_p   the keys 1, 2, 3 (top row or keypad)
//   up_p / down_p / left_p / right_p   the arrow keys (used by game 4, the maze). Arrow keys are
//                                      "extended" keys: their code (75 72 6B 74) comes after an E0 byte.
//                                      The keypad 8 / 2 / 4 / 6 send the same codes WITHOUT E0, so
//                                      keypad 2 is a digit 2 and never a down arrow.
//   space_p   SPACE (game 3, reaction test)      bksp_p   BACKSPACE (game 5)
//   digit_p   any digit 0-9 (top row or keypad), digit_val = which digit (game 5).
//             Keys 1 / 2 / 3 give both one_p / two_p / three_p AND digit_p.
// ============================================================================
module keyboard_input (clock, resetn, PS2_CLK, PS2_DAT,
                       enter_p, r_p, one_p, two_p, three_p,
                       up_p, down_p, left_p, right_p,
                       space_p, bksp_p, digit_p, digit_val);
    input  clock, resetn;
    inout  PS2_CLK, PS2_DAT;
    output reg enter_p, r_p, one_p, two_p, three_p;
    output reg up_p, down_p, left_p, right_p;
    output reg space_p, bksp_p, digit_p;
    output reg [3:0] digit_val;

    wire [7:0] code;        // byte received from the keyboard
    wire       code_en;     // 1 for one clock when 'code' is new

    // We never send anything to the keyboard (command = 0, send_command = 0).
    // PS2_Controller's reset is active high, ours (resetn) is active low.
    PS2_Controller KB (.CLOCK_50(clock), .reset(~resetn),
                       .the_command(8'h00), .send_command(1'b0),
                       .PS2_CLK(PS2_CLK), .PS2_DAT(PS2_DAT),
                       .command_was_sent(), .error_communication_timed_out(),
                       .received_data(code), .received_data_en(code_en));

    // scan codes (scan code set 2, what every PS/2 keyboard sends)
    parameter SC_ENTER = 8'h5A, SC_R = 8'h2D,
              SC_1 = 8'h16,  SC_2 = 8'h1E,  SC_3 = 8'h26,        // top row
              SC_K1 = 8'h69, SC_K2 = 8'h72, SC_K3 = 8'h7A,       // keypad
              SC_UP = 8'h75, SC_DOWN = 8'h72, SC_LEFT = 8'h6B, SC_RIGHT = 8'h74,   // arrows (after E0)
              SC_BREAK = 8'hF0, SC_EXT = 8'hE0,
              SC_SPACE = 8'h29, SC_BKSP = 8'h66;

    // digit keys: top row 0-9 and keypad 0-9 (keypad keys are NOT extended)
    reg       is_digit;
    reg [3:0] dval;
    always @(*) begin
        is_digit = 1'b1;
        case (code)
            8'h45, 8'h70: dval = 4'd0;
            8'h16, 8'h69: dval = 4'd1;
            8'h1E, 8'h72: dval = 4'd2;
            8'h26, 8'h7A: dval = 4'd3;
            8'h25, 8'h6B: dval = 4'd4;
            8'h2E, 8'h73: dval = 4'd5;
            8'h36, 8'h74: dval = 4'd6;
            8'h3D, 8'h6C: dval = 4'd7;
            8'h3E, 8'h75: dval = 4'd8;
            8'h46, 8'h7D: dval = 4'd9;
            default: begin
                dval     = 4'd0;
                is_digit = 1'b0;
            end
        endcase
    end

    reg skip;               // 1 = the next code is a key release, ignore it
    reg ext;                // 1 = an E0 prefix came before this code (extended key)

    always @(posedge clock) begin
        // default: no pulse
        enter_p <= 1'b0;
        r_p     <= 1'b0;
        one_p   <= 1'b0;
        two_p   <= 1'b0;
        three_p <= 1'b0;
        up_p    <= 1'b0;
        down_p  <= 1'b0;
        left_p  <= 1'b0;
        right_p <= 1'b0;
        space_p <= 1'b0;
        bksp_p  <= 1'b0;
        digit_p <= 1'b0;

        if (!resetn) begin
            digit_val <= 4'd0;
            skip <= 1'b0;
            ext  <= 1'b0;
        end else if (code_en) begin
            if (code == SC_BREAK) begin
                skip <= 1'b1;                       // next byte is a released key
            end else if (code == SC_EXT) begin
                ext <= 1'b1;                        // prefix only, keep waiting for the real code
            end else begin
                skip <= 1'b0;
                ext  <= 1'b0;
                if (!skip) begin                    // a key press
                    if (code == SC_ENTER)                     enter_p <= 1'b1;   // main or keypad Enter
                    if (!ext) begin                           // normal keys (not the extended ones)
                        if (code == SC_R)                     r_p     <= 1'b1;
                        if (code == SC_1 || code == SC_K1)    one_p   <= 1'b1;
                        if (code == SC_2 || code == SC_K2)    two_p   <= 1'b1;
                        if (code == SC_3 || code == SC_K3)    three_p <= 1'b1;
                        if (code == SC_SPACE)                 space_p <= 1'b1;
                        if (code == SC_BKSP)                  bksp_p  <= 1'b1;
                        if (is_digit) begin
                            digit_p   <= 1'b1;
                            digit_val <= dval;
                        end
                    end else begin                            // extended keys: the arrows
                        if (code == SC_UP)                    up_p    <= 1'b1;
                        if (code == SC_DOWN)                  down_p  <= 1'b1;
                        if (code == SC_LEFT)                  left_p  <= 1'b1;
                        if (code == SC_RIGHT)                 right_p <= 1'b1;
                    end
                end
            end
        end
    end
endmodule
