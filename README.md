# Bomb Rush (ECE241 Project)

A timed FPGA game for the DE1-SoC board. The player completes five mini-games to
"defuse the bomb" before a 1-3 minute countdown reaches 0.

**Planned mini-games:** binary conversion, memory match, reaction test, maze, number guesser.
**Inputs:** switches, keys, PS/2 keyboard. **Outputs:** LEDs, HEX displays, VGA.

## Current status
Main FSM, countdown timer and game progression through all five games to WIN / LOSE.
**All five mini-games are built** and connected to the main FSM. The KEY[2] "fake solve"
placeholder is gone: KEY[1..3] are now the buttons of game 2.

### Game 1: decimal to binary
After START, the VGA screen shows "GAME 1:" with "CONVERT TO BINARY" under it, then a random decimal number from 1 to 100.
Set that number in binary on SW[6:0] (SW[0] = least significant bit, SW[6] = most significant).
As soon as the switches match, the game is solved and the FSM moves on to game 2.

### Game 2: memory match
The screen flashes a sequence of digits (1, 2 or 3; red / green / blue), one at a time (HEX0 shows
them too). Repeat it with KEY[1] / KEY[2] / KEY[3] or keyboard 1 / 2 / 3. Three rounds: 3, then 4,
then 5 digits (each round adds one digit to the same sequence). A wrong press shows "WRONG" for
one second and replays the round. The sequence is random (LFSR frozen when the game starts).

### Game 3: reaction test
A white marker sweeps back and forth along a bar with a green target zone. Press SPACE while the
marker is in the green zone. Three hits in a row solve it; each hit speeds the marker up, narrows
the zone and moves it. A miss resets the hits to 0. After each press the marker freezes briefly
(0.4 s hit / 0.75 s miss), so mashing SPACE does not work. HEX0 shows the hits.

### Game 4: maze
A cyan cube starts in the top-left cell of a fixed 15 x 15 thin-wall maze. Move it with the
keyboard arrow keys, one cell per press, to the green exit cell in the bottom-right corner.
The shortest way out is 54 moves, and the maze has 61 dead ends, so most players need
roughly 20-40 seconds. Reaching the exit solves the game and moves on to game 5.
The walls are stored in `maze_vrow` / `maze_hrow` (inside `game4_maze.v`) and drawn by `vga_display.v`.

### Game 5: crack the code
The bomb has a secret code from 1 to 99. Type a guess on the keyboard (0-9, BACKSPACE to fix),
press ENTER, and the screen says GO HIGHER or GO LOWER (also LEDR[6] / LEDR[5]). It shows the
last guess and the number of tries (HEX0 too). Halving finds any code in at most 7 guesses.
Guessing the code solves the last game: WIN.

## Controls
| Control | Function |
|---|---|
| KEY[0] | Reset (active low) |
| SW[6:0] | Answer for game 1 (binary). Only read while game 1 is running |
| KEY[1] / KEY[2] / KEY[3] | Buttons 1 / 2 / 3 in game 2 (memory match) |
| Keyboard **1 / 2 / 3** | Difficulty on HOME: 1 = HARD (1 min), 2 = MEDIUM (2 min), 3 = EASY (3 min). Default is MEDIUM. Also buttons 1 / 2 / 3 in game 2 |
| Keyboard **Space** | Game 3 (reaction test) |
| Keyboard **arrow keys** | Move the cube in game 4 (maze) |
| Keyboard **0-9, Backspace, Enter** | Type and submit a guess in game 5 |
| Keyboard **Enter** | Start the game (on HOME) |
| Keyboard **R** | Restart (on WIN / LOSE, back to HOME) |

The keyboard plugs into the PS/2 port of the DE1-SoC (top-row digits, keypad digits and
keypad Enter all work). SW[9:7] are not used.

| Output | Shows |
|---|---|
| HEX5 | Current game number (blank outside a game) |
| HEX3:HEX2:HEX1 | Minutes : tens : ones of seconds (difficulty as M:00 in HOME) |
| HEX0 | Game 2: digit being flashed. Game 3: hits. Game 5: number of guesses. Blank otherwise |
| LEDR[4:0] | Progress bar, one LED per solved game |
| LEDR[6] / LEDR[5] | Game 5: go higher / go lower |
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
| `game2_memory.v` | Game 2: memory match (3 rounds, sequence of 1/2/3) | Teammate A |
| `game3_reaction.v` | Game 3: reaction test (sweeping marker, green zone, 3 hits) | Teammate B |
| `game5_guess.v` | Game 5: crack the code (guess 1-99, higher / lower) | Teammate B |
| `vga_games.v` | VGA screens of games 2, 3, 5 (own full A-Z font), used by `vga_screen` | Both |
| `countdown_timer.v` | BCD countdown timer with difficulty input | Teammate B |
| `seg7.v` | Digit to 7-segment decoder | Teammate B |
| `vga_display.v` | VGA wrapper and text drawing (`vga_display`, `vga_screen`) | Teammate B |

`vga_display.v` also needs the course files `vga_adapter.v`, `vga_controller.v`,
`vga_pll.v`, `vga_address_translator.v` and `black_160_9.mif` in the project.

## Signals between modules
`timer_load` and `timer_run` (FSM to timer), `time_up` (timer to FSM),
`home`, `win`, `lose`, `current_game` (FSM to displays and VGA), `difficulty` (top level to timer and VGA),
`active[0]` / `done[0]` (FSM to and from game 1), `g1_target` (game 1 to VGA, the number to show),
`active[3]` / `done[3]` (FSM to and from game 4), `g4_x` / `g4_y` (game 4 to VGA, the cube position),
`active[1]` / `done[1]`, `active[2]` / `done[2]`, `active[4]` / `done[4]` (games 2, 3, 5), and
`g2_vis` / `g3_vis` / `g5_vis` (games 2, 3, 5 to VGA, packed buses; layout at the top of `vga_games.v`).
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
