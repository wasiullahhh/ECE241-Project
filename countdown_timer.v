// ============================================================================
// Countdown timer (BCD). load: set to difficulty minutes : 00.
// Counts down once per second while run = 1, stops at 0:00. time_up is high whenever the count is 0.
// difficulty: 01 -> 1 min, 10 -> 2 min, 11 -> 3 min, 00 -> 1 min.
// ============================================================================
module countdown_timer (clock, resetn, load, run, difficulty, minutes, sec_tens, sec_ones, time_up);
    parameter CLK_PER_SEC = 50_000_000;

    input        clock, resetn, load, run;
    input  [1:0] difficulty;
    output reg [3:0] minutes, sec_tens, sec_ones;
    output       time_up;

    // one-second tick generator (restarts at the beginning of each game)
    reg [31:0] cnt;
    wire tick = run & (cnt == CLK_PER_SEC - 1);

    always @(posedge clock) begin
        if (!resetn || load || !run || tick) begin
            cnt <= 32'd0;
        end else begin
            cnt <= cnt + 1'b1;
        end
    end

    reg [3:0] start_min;
    always @(*) begin
        if (difficulty == 2'b11) begin
            start_min = 4'd3;
        end else if (difficulty == 2'b10) begin
            start_min = 4'd2;
        end else begin
            start_min = 4'd1;
        end
    end

    always @(posedge clock) begin
        if (!resetn) begin
            minutes  <= 4'd0;
            sec_tens <= 4'd0;
            sec_ones <= 4'd0;
        end else if (load) begin
            minutes  <= start_min;
            sec_tens <= 4'd0;
            sec_ones <= 4'd0;
        end else if (tick) begin
            if (sec_ones != 4'd0) begin
                sec_ones <= sec_ones - 1'b1;
            end else if (sec_tens != 4'd0) begin
                sec_tens <= sec_tens - 1'b1;
                sec_ones <= 4'd9;
            end else if (minutes != 4'd0) begin
                minutes  <= minutes - 1'b1;
                sec_tens <= 4'd5;
                sec_ones <= 4'd9;
            end
            // else: already 0:00, hold
        end
    end

    assign time_up = (minutes == 4'd0) & (sec_tens == 4'd0) & (sec_ones == 4'd0);
endmodule
