# Bomb Rush (ECE241 Project)

A timed FPGA game for the DE1-SoC board. The player completes five mini-games to
"defuse the bomb" before a 1-3 minute countdown reaches 0.

**Planned mini-games:** binary conversion, memory match, reaction test, maze, number guesser.
**Inputs:** switches, keys, PS/2 keyboard. **Outputs:** LEDs, HEX displays, VGA.

## Current status
Main FSM, countdown timer and game progression through all five games to WIN / LOSE.
**Game 1 (decimal to binary) and game 4 (maze) are built.** Games 2, 3 and 5 are not built yet:
pressing KEY[2] acts as a fake "game solved" signal for those.

### Game 1: decimal to binary
After START, the VGA screen shows "GAME 1:" with "CONVERT TO BINARY" under it, then a random decimal number from 1 to 100.
Set that number in binary on SW[6:0] (SW[0] = least significant bit, SW[6] = most significant).
As soon as the switches match, the game is solved and the FSM moves on to game 2.

### Game 4: maze
A cyan cube starts in the top-left cell of a fixed 15 x 15 thin-wall maze. Move it with the
keyboard arrow keys, one cell per press, to the green exit cell in the bottom-right corner.
The shortest way out is 54 moves, and the maze has 61 dead ends, so most players need
roughly 20-40 seconds. Reaching the exit solves the game and moves on to game 5.
The walls are stored in `maze_vrow` / `maze_hrow` (inside `game4_maze.v`) and drawn by `vga_display.v`.

## Controls
| Control | Function |
|---|---|
| KEY[0] | Reset (active low) |
| SW[6:0] | Answer for game 1 (binary). Only read while game 1 is running |
| KEY[2] | "Solve" games 2, 3 and 5 (placeholder) |
| Keyboard **arrow keys** | Move the cube in game 4 (maze) |
| Keyboard **Enter** | Start the game (on HOME) |
| Keyboard **1 / 2 / 3** | Difficulty on HOME: 1 = HARD (1 min), 2 = MEDIUM (2 min), 3 = EASY (3 min). Default is MEDIUM |
| Keyboard **R** | Restart (on WIN / LOSE, back to HOME) |

The keyboard plugs into the PS/2 port of the DE1-SoC (top-row digits, keypad digits and
keypad Enter all work). KEY[1], KEY[3] and SW[1:0] are no longer used.

| Output | Shows |
|---|---|
| HEX5 | Current game number (blank outside a game) |
| HEX3:HEX2:HEX1 | Minutes : tens : ones of seconds (difficulty as M:00 in HOME) |
| LEDR[4:0] | Progress bar, one LED per solved game |
| LEDR[7] | Timer running |
| LEDR[8] / LEDR[9] | LOSE / WIN |
| VGA | Name of the current state (HOME, GAME 1-5, WIN, LOSE); game 4 shows the maze. HOME shows "PRESS ENTER TO BEGIN", the 1/2/3 hint and the chosen difficulty (EASY 3 MINUTES / MEDIUM 2 MINUTES / HARD 1 MINUTE). WIN / LOSE show "PRESS R TO RESTART". Game 1 shows the number to convert |

## Files
| File | What it does | Owner |
|---|---|---|
| `bomb_rush.v` | Top level: wires everything together, picks HEX / VGA / LED outputs | Both |
| `main_game_fsm.v` | Main state machine (HOME, GAME1-5, WIN, LOSE) | Teammate A |
| `key_pulse.v` | Turns a button press into a one-clock-cycle pulse | Teammate A |
| `keyboard_input.v` | Reads the PS/2 keyboard: one-cycle pulses for Enter, R, 1, 2, 3 and the arrow keys | Teammate A |
| `game4_maze.v` | Game 4: maze walls, cube movement, exit detection | Teammate A |
| `PS2_Controller/` | Course PS/2 IP core (3 files), used by `keyboard_input.v` | Course |
| `game1_binary.v` | Game 1: random number 1-100, checks the switches against it | Teammate A |
| `countdown_timer.v` | BCD countdown timer with difficulty input | Teammate B |
| `seg7.v` | Digit to 7-segment decoder | Teammate B |
| `vga_display.v` | VGA wrapper and text drawing (`vga_display`, `vga_screen`) | Teammate B |

`vga_display.v` also needs the course files `vga_adapter.v`, `vga_controller.v`,
`vga_pll.v`, `vga_address_translator.v` and `black_160_9.mif` in the project.

## Signals between modules
`timer_load` and `timer_run` (FSM to timer), `time_up` (timer to FSM),
`home`, `win`, `lose`, `current_game` (FSM to displays and VGA), `difficulty` (top level to timer and VGA),
`active[0]` / `done[0]` (FSM to and from game 1), `g1_target` (game 1 to VGA, the number to show),
`active[3]` / `done[3]` (FSM to and from game 4), `g4_x` / `g4_y` (game 4 to VGA, the cube position).
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
