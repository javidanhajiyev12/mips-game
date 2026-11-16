# Snake-like mini-game using Keyboard and Display MMIO Simulator
# 9×9 grid (playable area 7×7 inside borders)

# DATA SECTION

.data                                                    # Beginning of the data section, where variables and strings are allocated
scoreText:    .asciiz "Score: "                          # A null-terminated string meant for printing before displaying the score
gameOver:     .asciiz "GAME OVER\nFinal Score: "         # The message displayed when the game is terminated
newline:      .asciiz "\n"                               # A newline string stored in memory

px: .word 4                                              # The game tracks the starting location of the player by storing the starting X position in memory
py: .word 4                                              # It also tracks the starting Y position in memory
rx: .word 1                                              # The reward’s X position is stored in memory
ry: .word 1                                              # The reward’s Y position is stored in memory as well
score: .word 0                                           # There is a variable storing the player’s score

# MMIO base address
MMIO_BASE: .word 0xffff0000                              # The base memory address is reserved for the keyboard/display MMIO device

# TEXT SECTION

.text                                                    # Start of the instruction section
.globl main

main:
    jal spawn_reward                                     # Call the spawn reward function to create the initial reward.

game_loop:                                               # Label to indicate the beginning of the main game loop.
    jal draw_screen                                      # Call the function to redraw the screen and grid.
    jal read_and_process_input                           # Call the function that waits for keyboard input and moves the player.
    jal check_game_over                                  # Call the function that checks if the win condition is met.
    j game_loop                                          # Repeat from the top of the program to keep the game running.

# DRAW SCREEN - using MMIO display

draw_screen:                                             # Function that draws the board and the current score
    addi $sp, $sp, -4                                    # Decrease the stack pointer to reserve space for saving registers.
    sw $ra, 0($sp)                                       # The plan is to put the return address on the stack.

    jal clear_screen_mmio                                #Then, call the function to clear the screen by printing a bunch of newline characters.

    # Print "Score: " using MMIO
    la $a0, scoreText                                    #Next, put the address of the "Score: " string in register $a0.
    jal print_string_mmio                                #Finally, call the function to write this string to the display.

    # Print score value using MMIO (simple decimal conversion)
    lw $a0, score                                        #Retrieve the score value from memory and transfer it to register $a0.
    jal print_int_mmio                                   # Call the function that prints the score as a decimal number.

    # Newline
    li $t9, '\n'                                        #The newline character is loaded into the output register.
    jal print_char_mmio                                 #The newline character is output to advance to the next line.

    # Draw 7×7 grid
    li $t0, 0                                           # The row counter(y) is initialized to zero.
row_loop:                                               # The start of row iteration is marked with a label.
        li $t1, 0                                       # The column counter is initialized to zero.

col_loop:                                               # The start of column iteration is marked with a label.
    li $t9, ' '                                         #  The default character is a space.

    # Walls (borders)
    li $t8, '#'                                         # Load the character representing the wall into register $t8.
    beq $t0, 0, set_char                                # Check if the current row equals 0. Since this represents the top border, draw the character representing the wall.
    beq $t0, 8, set_char                                # Check if the current row equals 8. Since this represents the bottom border, draw the character representing the wall.
    beq $t1, 0, set_char                                # Check if the current column equals 0. Since this represents the left border, draw the character representing the wall.
    beq $t1, 8, set_char                                # Check if the current column equals 8. Since this represents the right border, draw the character representing the wall.

    # Player
    lw $t2, px                                          # Load the X-coordinate of the player from memory.
    lw $t3, py                                          # Load the Y-coordinate of the player from memory.
    bne $t1, $t2, no_player                             # Check if the current column does not equal the X-coordinate of the player. Since this is not the player's column, do not draw the player.
    bne $t0, $t3, no_player                             # Check if the current row does not equal the Y-coordinate of the player. Since this is not the player's row, do not draw the player.
    li $t8, 'P'                                         # When both coordinates align, assign the character 'P'.
    j set_char                                          # Proceed to the section responsible for outputting the representation.

no_player:                                              # Label applied when the current cell is not the player.

    # Reward
    lw $t4, rx                                         # Load the X coordinate of the reward
    lw $t5, ry                                         # Load the Y coordinate of the reward
    bne $t1, $t4, no_reward                            # If the column is not related to reward X, skip the reward drawing process
    bne $t0, $t5, no_reward                            # If the row is not related to reward Y, skip the reward drawing process
    li $t8, 'R'                                        # If they match, assign it to R
    j set_char                                         # Proceed to the section for printing
    
no_reward:                                             # Label assigned in the absence of any reward
    j print_it                                         # Proceed to output the default character

set_char:                                              # Label corresponding to the preparation of the selected character for output
    move $t9, $t8                                      # Transfer the selected character into the printing register

print_it:                                              # Label corresponding to the printing operation of the character
    jal print_char_mmio                                # Call the MMIO printing function

    addi $t1, $t1, 1                                   # Move on to the next column
    blt $t1, 9, col_loop                               # If the current column is less than 7, continue iterating over columns

    # Newline after each row
    li $t9, '\n'                                       # Load a newline character to start a new row
    jal print_char_mmio                                # Prints a newline character

    addi $t0, $t0, 1                                   # Move to the next row
    blt $t0, 9, row_loop                               # If the current row index is less than 7, continue with the row iteration

    lw $ra, 0($sp)                                     # Restore the return address from stack
    addi $sp, $sp, 4                                   # Restore the stack pointer
    jr $ra                                             # Return to the caller

# Print string to MMIO (one char at a time)

print_string_mmio:                                     # Function responsible for printing a null-terminated string.
    addi $sp, $sp, -8                                  # Stack Space Allocation
    sw $ra, 4($sp)                                     # Saving the Return Address
    sw $a0, 0($sp)                                     # Saving the String Pointer
str_loop:                                              # Initiation of the string output loop.
    lb $t9, 0($a0)                                     # Load a single character from the string.
    beqz $t9, str_done                                 # If the character loaded is the null terminator, the process should be terminated.
    jal print_char_mmio                                # Print the character loaded from the string.
    addi $a0, $a0, 1                                   # Move pointer to the next character in the sequence
    j str_loop                                         # Repeat the process for all characters in the sequence
str_done:                                              # Terminate the string printing process.
    lw $a0, 0($sp)                                     # Restore the original pointer
    lw $ra, 4($sp)                                     # Restore the return address.
    addi $sp, $sp, 8                                   # Restore the stack pointer.
    jr $ra                                             # Return


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
    div $s0, $s1                          # Divide number by 1000
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

print_char_mmio:                   # Function that outputs a single character using memory-mapped I/O (MMIO)
    lui $t8, 0xffff                # Load the upper portion of the MMIO base address
wait_tx_ready:                     # Wait for the transmitter to be ready
    lw $t7, 8($t8)                 # Read the transmitter control register
    andi $t7, $t7, 1               # Check the ready bit
    beq $t7, $zero, wait_tx_ready  # If the transmitter is not ready, keep waiting
    sb $t9, 12($t8)                # Write the character to the transmitter data register
    jr $ra                         # Return to the caller.


clear_screen_mmio:                 # Function that clears screen by printing many newlines
    addi $sp, $sp, -8              # Allocate the stack space
    sw $ra, 4($sp)                 # Save the return address
    sw $s0, 0($sp)                 # Save the register s0

    li $s0, 40                     # Number of newline characters to print

clear_loop:                        # Loop for printing newlines.
    li $t9, '\n'                   # Load the newline character.
    jal print_char_mmio
    addi $s0, $s0, -1              # Decrease counter
    bnez $s0, clear_loop           # The program continue until counter reaches zero.

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
    j    check_reward

try_down:
    lw   $t2, py
    addi $t2, $t2, 1
    bgt $t2, 7, crash    
    sw   $t2, py
    j    check_reward

try_left:
    lw   $t1, px
    addi $t1, $t1, -1
    blt  $t1, 1, crash        
    sw   $t1, px
    j    check_reward

try_right:
    lw   $t1, px
    addi $t1, $t1, 1
    bgt $t1, 7, crash      
    sw   $t1, px
    j    check_reward


check_reward:
    
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

# Spawn reward at random position (1..7)

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
