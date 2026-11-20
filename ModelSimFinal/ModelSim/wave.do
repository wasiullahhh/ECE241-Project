onerror {resume}
quietly WaveActivateNextPane {} 0

# readable state names for y_Q (3-bit state codes from main_game_fsm.v)
radix define MainStates {
    3'b000 "HOME",
    3'b001 "GAME1",
    3'b010 "GAME2",
    3'b011 "GAME3",
    3'b100 "GAME4",
    3'b101 "GAME5",
    3'b110 "WIN",
    3'b111 "LOSE",
    -default unsigned
}

add wave -noupdate -divider {Inputs}
add wave -noupdate /testbench/clock
add wave -noupdate /testbench/resetn
add wave -noupdate /testbench/start
add wave -noupdate -radix binary /testbench/done
add wave -noupdate /testbench/time_up
add wave -noupdate /testbench/restart

add wave -noupdate -divider {State}
add wave -noupdate -radix MainStates /testbench/U1/y_Q
add wave -noupdate -radix MainStates /testbench/U1/Y_D

add wave -noupdate -divider {Outputs}
add wave -noupdate -radix binary /testbench/active
add wave -noupdate -radix unsigned /testbench/current_game
add wave -noupdate -radix unsigned /testbench/games_done
add wave -noupdate /testbench/timer_run
add wave -noupdate /testbench/timer_load
add wave -noupdate /testbench/home
add wave -noupdate /testbench/win
add wave -noupdate /testbench/lose

TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ns} 0}
configure wave -namecolwidth 150
configure wave -valuecolwidth 70
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ns} {700 ns}
