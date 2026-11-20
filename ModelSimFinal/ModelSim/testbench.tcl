# ModelSim script for the main game FSM.
# Usage (in the ModelSim transcript):   cd <folder with these files>
#                                       do testbench.tcl

# start from a clean library every time
if {[file exists work]} {
    vdel -lib work -all
}
vlib work
vmap work work

# compile the design and the testbench
vlog -work work main_game_fsm.v
vlog -work work testbench.v

# load the testbench (+acc keeps internal signals such as U1/y_Q visible)
vsim -t 1ns -voptargs=+acc work.testbench

# add the waveforms, run until the testbench stops itself, then fit the whole run in the window
do wave.do
run -all
wave zoom full
