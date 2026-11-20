// ============================================================================
// Turns an active-low pushbutton into a one-clock-cycle pulse on each press
// (two flip-flops to synchronize the button, one more to detect the falling edge).
// ============================================================================
module key_pulse (clock, resetn, key_n, pulse);
    input  clock, resetn, key_n;
    output pulse;
    reg sync, prev;

    always @(posedge clock) begin
        if (!resetn) begin
            sync <= 1'b1;
            prev <= 1'b1;
        end else begin
            sync <= key_n;
            prev <= sync;
        end
    end

    assign pulse = prev & ~sync;
endmodule
