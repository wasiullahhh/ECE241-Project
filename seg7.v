// ============================================================================
// BCD to 7-segment decoder for the DE1-SoC (segments are active low: {g,f,e,d,c,b,a}).
// Any value above 9 (use 4'hF) turns the display off.
// ============================================================================
module seg7 (bcd, hex);
    input  [3:0] bcd;
    output reg [6:0] hex;

    always @(*) begin
        case (bcd)
            4'd0: begin
                hex = 7'b1000000;
            end
            4'd1: begin
                hex = 7'b1111001;
            end
            4'd2: begin
                hex = 7'b0100100;
            end
            4'd3: begin
                hex = 7'b0110000;
            end
            4'd4: begin
                hex = 7'b0011001;
            end
            4'd5: begin
                hex = 7'b0010010;
            end
            4'd6: begin
                hex = 7'b0000010;
            end
            4'd7: begin
                hex = 7'b1111000;
            end
            4'd8: begin
                hex = 7'b0000000;
            end
            4'd9: begin
                hex = 7'b0010000;
            end
            default: begin
                hex = 7'b1111111;   // blank
            end
        endcase
    end
endmodule
