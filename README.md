# MIPS Snake-Style Grid Game

A small terminal-style game written entirely in **MIPS assembly** for the **MARS simulator**. It uses **Memory-Mapped I/O (MMIO)** for both keyboard input and screen output, with no syscalls for I/O (syscalls are used only for random numbers and exiting).

The project comes in two versions:

| Version | File | Description |
|---|---|---|
| **Part 1** | `part1_game.asm` | Collection game: move the player `P`, pick up rewards `R`, avoid the walls |
| **Part 2** | `part2_game.asm` | Part 1 plus a chasing enemy `E` that hunts the player |

---

## Table of Contents

- [Gameplay](#gameplay)
- [Screenshot / Example Output](#screenshot--example-output)
- [Requirements](#requirements)
- [How to Run](#how-to-run)
- [Controls](#controls)
- [Game Rules](#game-rules)
- [Project Structure](#project-structure)
- [How It Works](#how-it-works)
  - [Memory Layout (Data Segment)](#memory-layout-data-segment)
  - [Program Flow](#program-flow)
  - [MMIO Registers](#mmio-registers)
  - [Function Reference](#function-reference)
  - [Enemy AI (Part 2)](#enemy-ai-part-2)
- [Design Challenges and Solutions](#design-challenges-and-solutions)
- [Known Limitations](#known-limitations)
- [Possible Improvements](#possible-improvements)
- [Differences Between Part 1 and Part 2](#differences-between-part-1-and-part-2)
- [References](#references)

---

## Gameplay

You control a player (`P`) on a 9×9 board surrounded by a wall of `#` characters. A reward (`R`) appears at a random position inside the playable 7×7 area. Walk onto it to score **5 points**, and a new reward spawns elsewhere. Reach **100 points** to finish the game.

In **Part 2**, an enemy (`E`) starts in the bottom-right corner and moves one step toward you every time you move. If it catches you, the game is over.

## Screenshot / Example Output

Each frame is redrawn in the MMIO display window:

```
Score: 15
#########
#       #
#   R   #
#       #
#   P   #
#       #
#       #
#     E #
#########
```

When the game ends:

```
GAME OVER
Final Score: 15
```

## Requirements

- **[MARS MIPS Simulator](http://courses.missouristate.edu/kenvollmar/mars/)** (v4.5 or newer recommended)
- Java Runtime Environment (needed to run MARS)

## How to Run

1. Open MARS and load `src/part1_game.asm` or `src/part2_game.asm` (**File → Open**).
2. Assemble the program (**Run → Assemble**, or press `F3`).
3. Open the MMIO tool: **Tools → Keyboard and Display MMIO Simulator**.
4. In the tool window, click **Connect to MIPS**.
5. Run the program (**Run → Go**, or press `F5`).
6. Click inside the **Keyboard** text area at the bottom of the MMIO window so it has focus, then press the control keys. The board is drawn in the **Display** area at the top.

> **Tip:** Make the Display area tall enough to show the whole board (about 50 rows). The screen is "cleared" by printing 40 newlines, so a small window will scroll.

## Controls

| Key | Action |
|---|---|
| `W` | Move up |
| `A` | Move left |
| `S` | Move down |
| `D` | Move right |

Use lowercase letters. Any other key is ignored and the game keeps waiting for valid input.

## Game Rules

- The board is **9×9** (coordinates `0..8`). The border cells are walls; the playable area is **1..7** on both axes.
- The player starts at **(4, 4)**.
- A reward spawns at a random cell in **(1..7, 1..7)**.
- Collecting a reward gives **+5 points** and spawns a new reward.
- **Win:** the game ends when the score reaches **100 or more** (20 rewards).
- **Lose:** moving into a wall ends the game immediately.
- **Lose (Part 2 only):** the enemy landing on the player's cell ends the game immediately.
- The game is turn-based: nothing moves until you press a valid key.

## Project Structure

```
.
├── src/
│   ├── part1_game.asm    # Part 1: player + rewards + walls
│   └── part2_game.asm    # Part 2: Part 1 + chasing enemy
├── docs/
│   └── technical_report.pdf  # Design notes and problems/solutions
├── LICENSE
└── README.md
```

## How It Works

### Memory Layout (Data Segment)

| Label | Type | Initial value | Purpose |
|---|---|---|---|
| `scoreText` | `.asciiz` | `"Score: "` | Prefix printed before the score |
| `gameOver` | `.asciiz` | `"GAME OVER\nFinal Score: "` | End-of-game message |
| `newline` | `.asciiz` | `"\n"` | Newline string |
| `px`, `py` | `.word` | `4`, `4` | Player position |
| `rx`, `ry` | `.word` | `1`, `1` | Reward position (randomised at start) |
| `score` | `.word` | `0` | Current score |
| `ex`, `ey` | `.word` | `7`, `7` | Enemy position (**Part 2 only**) |
| `MMIO_BASE` | `.word` | `0xffff0000` | MMIO base address (documentation; code uses `lui`) |

### Program Flow

```
main
 └─ spawn_reward            # place the first reward
    game_loop:
      ├─ draw_screen        # clear + score + 9x9 board
      ├─ read_and_process_input
      │    ├─ wait for key (polling)
      │    ├─ validate move / crash on wall
      │    ├─ move_enemy          (Part 2)
      │    └─ check_reward        # enemy collision (Part 2) + reward pickup
      ├─ check_game_over    # score >= 100 ?
      └─ j game_loop
```

Every frame is rendered cell by cell. For each `(row, column)` the draw loop picks a character in this priority order:

1. `#` if the cell is on the border
2. `P` if it matches the player
3. `E` if it matches the enemy (Part 2)
4. `R` if it matches the reward
5. a space otherwise

### MMIO Registers

The game polls the device instead of using interrupts.

| Address | Register | Used for |
|---|---|---|
| `0xffff0000` | Receiver Control | Bit 0 = a key is ready |
| `0xffff0004` | Receiver Data | ASCII code of the pressed key |
| `0xffff0008` | Transmitter Control | Bit 0 = display is ready for a character |
| `0xffff000c` | Transmitter Data | Write a character here to display it |

### Function Reference

| Function | Description |
|---|---|
| `main` | Spawns the first reward, then enters the game loop |
| `draw_screen` | Clears the display, prints the score line, and renders the 9×9 board |
| `print_char_mmio` | Waits for the transmitter to be ready, then writes the character in `$t9` |
| `print_string_mmio` | Prints a null-terminated string whose address is in `$a0` |
| `print_int_mmio` | Prints a non-negative integer (supports 0–9999) with no leading zeros |
| `clear_screen_mmio` | Prints 40 newlines to push the old frame off screen |
| `read_and_process_input` | Polls for a key, handles `w/a/s/d`, updates the player, triggers enemy movement and reward checks |
| `move_enemy` | *(Part 2)* One greedy step of the enemy toward the player |
| `check_reward` | *(Part 2)* Detects enemy collision, then handles reward pickup and scoring |
| `spawn_reward` | Picks a random `(rx, ry)` in `1..7` using syscall 42 |
| `check_game_over` | Ends the game if `score >= 100` |
| `crash` | Prints `GAME OVER` and the final score, then exits |
| `end_game` | Prints the end screen on a win (`score >= 100`) and exits |

**Calling convention notes:** functions that call other functions (`draw_screen`, `print_string_mmio`, `print_int_mmio`, `clear_screen_mmio`, `read_and_process_input`, `move_enemy`, `spawn_reward`) save `$ra` (and any `$s` registers they use) on the stack and restore them before returning. Characters to print are passed in `$t9`.

### Enemy AI (Part 2)

`move_enemy` implements a **greedy pursuit** strategy that needs no pathfinding:

1. If the enemy's `x` differs from the player's `x`, move one step horizontally toward the player.
2. Otherwise, if the `y` differs, move one step vertically toward the player.
3. If both match, stay in place.

The enemy moves exactly **one step per valid player move**, so the player can outmaneuver it, but only by planning ahead. After the enemy moves, `check_reward` compares its position with the player's and triggers `crash` if they are the same.

## Design Challenges and Solutions

Summarised from the project's technical report.

**Display flicker and artifacts.** Early versions left a trail of `P` characters and stacked frames at the bottom of the display. `clear_screen_mmio` fixes this by printing 40 newlines before each frame, giving every redraw a clean slate.

**Register preservation and call depth.** The call chain is deep (`game_loop → draw_screen → print_char_mmio`), and early versions crashed because `$ra` was overwritten. Every non-leaf function now has a proper prologue/epilogue that adjusts `$sp` and saves/restores `$ra`.

**Enemy movement and collision (Part 2).** Adding the enemy risked it passing through walls or the player. `move_enemy` aligns the enemy on the `x` axis first, then the `y` axis, and `check_reward` was extended to crash on overlap of `P` and `E`.

**Multi-digit scores.** The MMIO display accepts one character at a time, so `print_int_mmio` splits the score into digits using `div`/`mflo`/`mfhi`, converts each to ASCII by adding `'0'` (`0x30`), and transmits them individually.

## Known Limitations

- **Random spawn overlap:** a new reward can spawn on the player's current cell or on the enemy; in that case the reward is not collected until the player steps off and back on.
- **Draw priority hides the reward:** if the enemy stands on the reward's cell, `E` is drawn and `R` is hidden.
- **No restart:** after a win or crash, the program exits and must be re-run.
- **Lowercase keys only:** uppercase `W/A/S/D` are ignored.
- **Window size:** clearing by newlines depends on the MMIO display height; a very small Display window will show scrolling.
- **Win and loss share one message:** both print `GAME OVER` and the final score.
- **Comment mismatches:** a few comments in the source still say "7×7" / "1..5" where the code uses a 9×9 board with a `1..7` playable range. The behaviour is correct.

## Possible Improvements

- Prevent rewards from spawning on the player or the enemy
- Add a distinct "YOU WIN" message
- Add a restart option
- Accept uppercase keys
- Make the enemy move only every other turn (difficulty levels)
- Add obstacles and smarter enemy pathfinding (BFS)
- Add a growing snake tail for a true Snake game

## Differences Between Part 1 and Part 2

| Feature | Part 1 | Part 2 |
|---|---|---|
| Player, walls, rewards | Yes | Yes |
| Enemy `E` | No | Yes, starts at (7, 7) |
| `move_enemy` function | No | Yes |
| Enemy collision check | No | Yes, in `check_reward` |
| Ways to lose | Wall | Wall or enemy |
| Draw order | `#` → `P` → `R` | `#` → `P` → `E` → `R` |
| Source comments | Heavily commented | Lightly commented |

## References

1. Patterson, D.A. and Hennessy, J.L. (2017) *Computer Organization and Design: The Hardware/Software Interface (MIPS Edition)*. 5th ed. Cambridge, MA: Morgan Kaufmann.
2. Sweetman, D. (2010) *See MIPS Run*. 2nd ed. Burlington, MA: Morgan Kaufmann.
3. Kann, C.W. (2016) *Introduction to MIPS Assembly Language Programming*. Seattle: CreateSpace Independent Publishing Platform.

---

*Developed as an exercise in hardware/software interfacing using MIPS assembly and memory-mapped I/O.*
