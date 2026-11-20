# Bomb Rush (ECE241 Project)

A timed FPGA game for the DE1-SoC board. The player completes five mini-games to
"defuse the bomb" before a 1-3 minute countdown reaches 0.

**Planned mini-games:** binary conversion, memory match, reaction test, maze, number guesser.
**Inputs:** switches, keys, PS/2 keyboard. **Outputs:** LEDs, HEX displays, VGA.

## Current status: Milestone 1
Main FSM, countdown timer and game progression through all five games to WIN / LOSE.
The mini-games are not built yet. Pressing KEY[2] acts as a fake "game solved" signal.

## Board controls
| Control | Function |
|---|---|
| KEY[0] | Reset (active low) |
| KEY[1] | Start game (from HOME) |
| KEY[2] | "Solve" current mini-game (placeholder) |
| KEY[3] | Restart (from WIN / LOSE back to HOME) |
| SW[1:0] | Difficulty: 01 = 1 min, 10 = 2 min, 11 = 3 min, 00 = 1 min |

| Output | Shows |
|---|---|
| HEX5 | Current game number (blank outside a game) |
| HEX3:HEX2:HEX1 | Minutes : tens : ones of seconds (difficulty as M:00 in HOME) |
| LEDR[4:0] | Progress bar, one LED per solved game |
| LEDR[7] | Timer running |
| LEDR[8] / LEDR[9] | LOSE / WIN |
| VGA | Name of the current state (HOME, GAME 1-5, WIN, LOSE) |

## Files
| File | What it does | Owner |
|---|---|---|
| `bomb_rush.v` | Top level: wires everything together, picks HEX / VGA / LED outputs | Both |
| `main_game_fsm.v` | Main state machine (HOME, GAME1-5, WIN, LOSE) | Teammate A |
| `key_pulse.v` | Turns a button press into a one-clock-cycle pulse | Teammate A |
| `countdown_timer.v` | BCD countdown timer with difficulty select | Teammate B |
| `seg7.v` | Digit to 7-segment decoder | Teammate B |
| `vga_display.v` | VGA wrapper and text drawing (`vga_display`, `vga_screen`) | Teammate B |

`vga_display.v` also needs the course files `vga_adapter.v`, `vga_controller.v`,
`vga_pll.v`, `vga_address_translator.v` and `black_160_9.mif` in the project.

## Signals between modules
`timer_load` and `timer_run` (FSM to timer), `time_up` (timer to FSM),
`home`, `win`, `lose`, `current_game` (FSM to displays and VGA).
Tell each other before renaming or changing any of these.

## Opening in Quartus
1. Open the `.qpf` file in this folder.
2. Project > Add/Remove Files in Project, and make sure every `.v` file above is listed.
3. Set `bomb_rush` as the top-level entity, then compile.

## Simulation (ModelSim)
`CLK_PER_SEC` in `bomb_rush` is 50,000,000 for the board. Set it to a small value
(e.g. 4) in ModelSim so a "second" takes only a few clock cycles.

## Git workflow
Pull before you start, work only in your own files, then commit and push.
Tell each other before editing `bomb_rush.v` (shared).
