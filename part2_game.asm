# Snake-like mini-game using Keyboard and Display MMIO Simulator
# 9×9 grid (playable area 7×7 inside borders)

# DATA SECTION

.data
scoreText:    .asciiz "Score: "
gameOver:     .asciiz "GAME OVER\nFinal Score: "
newline:      .asciiz "\n"

px: .word 4          # player starting x (1..5)
py: .word 4          # player starting y (1..5)
rx: .word 1
ry: .word 1

score: .word 0

ex: .word 7      # enemy x
ey: .word 7      # enemy y

# MMIO base address
MMIO_BASE: .word 0xffff0000

# TEXT SECTION

.text
.globl main

main:
    jal spawn_reward

game_loop:
    jal draw_screen
    jal read_and_process_input
    jal check_game_over
    j game_loop

# DRAW SCREEN - using MMIO display

draw_screen:
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    jal clear_screen_mmio

    # Print "Score: " using MMIO
    la $a0, scoreText
    jal print_string_mmio

    # Print score value using MMIO (simple decimal conversion)
    lw $a0, score
    jal print_int_mmio

    # Newline
    li $t9, '\n'
    jal print_char_mmio

    # Draw 7×7 grid
    li $t0, 0           # row (y)
row_loop:
    li $t1, 0           # column (x)
col_loop:
    li $t9, ' '         # default = space

    # Walls (borders)
    li $t8, '#'
    beq $t0, 0, set_char
    beq $t0, 8, set_char
    beq $t1, 0, set_char
    beq $t1, 8, set_char

    # Player
    lw $t2, px
    lw $t3, py
    bne $t1, $t2, no_player
    bne $t0, $t3, no_player
    li $t8, 'P'
    j set_char
no_player:

    #Check for enemy collision

    lw $t6, ex
    lw $t7, ey
    bne $t1, $t6, no_enemy
    bne $t0, $t7, no_enemy
    li $t8, 'E'
    j set_char
no_enemy:
    # Reward
    lw $t4, rx
    lw $t5, ry
    bne $t1, $t4, no_reward
    bne $t0, $t5, no_reward
    li $t8, 'R'
    j set_char
no_reward:
    j print_it

set_char:
    move $t9, $t8

print_it:
    jal print_char_mmio

    addi $t1, $t1, 1
    blt $t1, 9, col_loop

    # Newline after each row
    li $t9, '\n'
    jal print_char_mmio

    addi $t0, $t0, 1
    blt $t0, 9, row_loop

    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

# Print string to MMIO (one char at a time)

print_string_mmio:
    addi $sp, $sp, -8
    sw $ra, 4($sp)
    sw $a0, 0($sp)
str_loop:
    lb $t9, 0($a0)
    beqz $t9, str_done
    jal print_char_mmio
    addi $a0, $a0, 1
    j str_loop
str_done:
    lw $a0, 0($sp)
    lw $ra, 4($sp)
    addi $sp, $sp, 8
    jr $ra


# Print integer to MMIO (very simple - supports 0–9999)

print_int_mmio:
    addi $sp, $sp, -12
    sw $ra, 8($sp)
    sw $s0, 4($sp)
    sw $s1, 0($sp)

    move $s0, $a0
    li $s1, 1000

    # Skip leading zeros for numbers < 1000
    blt $s0, 10, print_single
    blt $s0, 100, print_tens
    blt $s0, 1000, print_hundreds

print_thousands:
    div $s0, $s1
    mflo $t9
    addi $t9, $t9, '0'
    jal print_char_mmio
    mfhi $s0
    li $s1, 100

print_hundreds:
    li $s1, 100
    div $s0, $s1
    mflo $t9
    addi $t9, $t9, '0'
    jal print_char_mmio
    mfhi $s0

print_tens:
    li $s1, 10
    div $s0, $s1
    mflo $t9
    addi $t9, $t9, '0'
    jal print_char_mmio
    mfhi $s0

print_single:
    addi $t9, $s0, '0'
    jal print_char_mmio

    lw $s1, 0($sp)
    lw $s0, 4($sp)
    lw $ra, 8($sp)
    addi $sp, $sp, 12
    jr $ra

# Print one character to MMIO display (waits for ready)

print_char_mmio:
    lui $t8, 0xffff         # 0xffff0000
wait_tx_ready:
    lw $t7, 8($t8)          # transmitter control 0xffff0008
    andi $t7, $t7, 1
    beq $t7, $zero, wait_tx_ready
    sb $t9, 12($t8)         # transmitter data 0xffff000c
    jr $ra

# ───────────────────────────────────────────────
# Clear screen by printing many newlines
# ───────────────────────────────────────────────
clear_screen_mmio:
    addi $sp, $sp, -8
    sw $ra, 4($sp)
    sw $s0, 0($sp)

    li $s0, 40              # adjust if needed

clear_loop:
    li $t9, '\n'
    jal print_char_mmio
    addi $s0, $s0, -1
    bnez $s0, clear_loop

    lw $s0, 0($sp)
    lw $ra, 4($sp)
    addi $sp, $sp, 8
    jr $ra


# READ INPUT - waits for key, only accepts w a s d

read_and_process_input:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    lui  $t8, 0xffff

wait_key:
    lw   $t7, 0($t8)          
    andi $t7, $t7, 1
    beq  $t7, $zero, wait_key

    lb   $t0, 4($t8)          

    beq  $t0, 'w', try_up
    beq  $t0, 'a', try_left
    beq  $t0, 's', try_down
    beq  $t0, 'd', try_right
    j    wait_key            

try_up:
    lw   $t2, py
    addi $t2, $t2, -1
    blt  $t2, 1, crash        
    sw   $t2, py
    jal move_enemy
    j    check_reward

try_down:
    lw   $t2, py
    addi $t2, $t2, 1
    bgt  $t2, 7, crash        
    sw   $t2, py
    jal move_enemy
    j    check_reward

try_left:
    lw   $t1, px
    addi $t1, $t1, -1
    blt  $t1, 1, crash        
    sw   $t1, px
    jal move_enemy
    j    check_reward

try_right:
    lw   $t1, px
    addi $t1, $t1, 1
    bgt  $t1, 7, crash        
    sw   $t1, px
    jal move_enemy
    j    check_reward
    
move_enemy:
    addi $sp,$sp,-4                # Allocate 4 bytes on the stack
    sw $ra,0($sp)                  # Save the return address

    lw $t0, px                     # Load the player's x position
    lw $t1, py                     # Load the player's y position
    lw $t2, ex                     # Load the enemy's x position
    lw $t3, ey                     # Load the enemy's x position

    beq $t0,$t2,enemy_y            # If the enemy and player are in the same column, move vertically

    blt $t2,$t0,enemy_right        # If the enemy's x is less than the player's x, the enemy should move right
    
enemy_left:
    addi $t2,$t2,-1                # Decrease the enemy's x to move left
    j save_enemy                   # Jump to store the updated position

enemy_right:
    addi $t2,$t2,1                 # Increase the enemy's x to move right
    j save_enemy                   # Jump to store the updated position

enemy_y:
    beq $t1,$t3,save_enemy         #If the enemy is already aligned with the player, there will be no vertical movement.

    blt $t3,$t1,enemy_down         #If the enemy’s y-coordinate is less than the player’s y-coordinate, the enemy will move down.
enemy_up:
    addi $t3,$t3,-1                # Decrease the enemy’s y to move up
    j save_enemy                   # Jump to save the updated position

enemy_down:
    addi $t3,$t3,1                 #Increase the enemy’s y to move down

save_enemy:
    sw $t2, ex                     #Store the new enemy x coordinate.
    sw $t3, ey                     #Store the new enemy y coordinate.
    lw $ra,0($sp)                  #Restore the return address
    addi $sp,$sp,4                 #Restore the stack pointer
    jr $ra                         #Return to the caller
    

check_reward:

    # Enemy collision check
    lw $t6, ex                     #Load enemy x position
    lw $t7, ey                     #Load enemy y position
    lw $t1, px                     #Load player x position
    lw $t2, py                     #Load player y position
    bne $t1, $t6, skip_enemy       #If the player x is not equal to the enemy x, then there is no collision
    bne $t2, $t7, skip_enemy       #If the player y is not equal to the enemy y, then there is no collision 
    j crash                        #If the x and y are the same, then the game is over
skip_enemy:
 

  
    lw   $t1, px
    lw   $t2, py
    lw   $t3, rx
    lw   $t4, ry
    bne  $t1, $t3, input_done
    bne  $t2, $t4, input_done

 
    lw   $t5, score
    addi $t5, $t5, 5
    sw   $t5, score
    jal  spawn_reward
    j    input_done


crash:
    
    jal  clear_screen_mmio
    la   $a0, gameOver
    jal  print_string_mmio
    lw   $a0, score
    jal  print_int_mmio
    li   $t9, '\n'
    jal  print_char_mmio

    li   $v0, 10
    syscall                   

input_done:
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra

# Spawn reward at random position (1..5)

spawn_reward:
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    # random x (1-7)
    li $v0, 42
    li $a0, 0
    li $a1, 7
    syscall
    addi $a0, $a0, 1
    sw $a0, rx

    # random y (1-7)
    li $v0, 42
    li $a0, 0
    li $a1, 7
    syscall
    addi $a0, $a0, 1
    sw $a0, ry

    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

# Check win condition (score >= 100)

check_game_over:
    lw $t0, score
    bge $t0, 100, end_game
    jr $ra

# END GAME (win condition - score >= 100)
end_game:
    jal clear_screen_mmio

    la $a0, gameOver
    jal print_string_mmio

    lw $a0, score
    jal print_int_mmio

    li $t9, '\n'
    jal print_char_mmio

    li $v0, 10
    syscall
