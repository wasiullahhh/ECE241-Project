`timescale 1ns/1ns
// ModelSim testbench for main_game_fsm (module name "testbench", DUT instance "U1").
// 10 ns clock. Scenarios: win run, timeout loss, time_up/done tie, reset mid-game, timer_load pulse.
module testbench;
    reg clock = 0, resetn = 0, start = 0, time_up = 0, restart = 0;
    reg [4:0] done = 0;
    wire [4:0] active;
    wire [2:0] current_game, games_done;
    wire timer_run, timer_load, win, lose, home;

    main_game_fsm U1 (clock, resetn, start, done, time_up, restart,
                      active, current_game, games_done, timer_run, timer_load,
                      win, lose, home);

    always #5 clock = ~clock;

    integer errors = 0, i;

    task tick; begin @(negedge clock); end endtask

    task check;
        input cond;
        input [8*40:1] msg;
        begin
            if (!cond) begin errors = errors + 1; $display("FAIL: %0s (t=%0t)", msg, $time); end
        end
    endtask

    task pulse_start;   begin start = 1;   tick; start = 0;   tick; end endtask
    task pulse_restart; begin restart = 1; tick; restart = 0; tick; end endtask
    task solve;
        input integer n;
        begin done = 5'b1 << n; tick; done = 0; tick; end
    endtask

    initial begin
        // ---- reset ----
        tick; tick; resetn = 1; tick; tick;
        check(home && !timer_run && games_done == 0, "home after reset");

        // ---- scenario 1: win through all five games ----
        pulse_start;
        for (i = 0; i < 5; i = i + 1) begin
            check(current_game == i+1 && active == (5'b1 << i) && timer_run, "game active");
            check(games_done == i, "games_done counts up");
            tick; tick;
            solve(i);
        end
        check(win && !lose && games_done == 5 && !timer_run, "win state");
        tick; tick;
        pulse_restart;
        check(home && games_done == 0, "restart to home");

        // ---- scenario 2: timeout in game 3 ----
        pulse_start; solve(0); solve(1);
        check(current_game == 3, "reached game 3");
        done = 5'b00001; tick; done = 0;               // done from an inactive game is ignored
        check(current_game == 3, "ignores done from wrong game");
        tick; tick;
        time_up = 1; tick; time_up = 0; tick;
        check(lose && !win && games_done == 2, "lose keeps progress");
        tick; tick;
        pulse_restart;
        check(home, "restart after lose");

        // ---- scenario 3: time_up and done on the same cycle -> loss ----
        pulse_start; solve(0);
        time_up = 1; done = 5'b00010; tick; time_up = 0; done = 0; tick;
        check(lose && games_done == 1, "time_up beats done");
        tick;
        pulse_restart;

        // ---- scenario 4: reset in the middle of a game ----
        pulse_start; solve(0); tick; tick;
        resetn = 0; tick; resetn = 1; tick; tick;
        check(home && games_done == 0, "reset mid-game");

        // ---- scenario 5: timer_load only pulses when leaving HOME ----
        start = 1; #1 check(timer_load, "timer_load on start in HOME"); tick; start = 0; tick;
        start = 1; #1 check(!timer_load, "no timer_load while playing"); tick; start = 0;
        tick; tick;

        if (errors == 0) $display("ALL PASS"); else $display("%0d ERRORS", errors);
`ifdef __ICARUS__
        $finish;
`else
        $stop;      // keep the simulation open in ModelSim so you can look at the waveform
`endif
    end
endmodule
