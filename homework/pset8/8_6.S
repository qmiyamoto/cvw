/* Write a RV32I trap handler to emulate the mul instruction.  If the hart attempts to execute 
mul, it will throw an Illegal Instruction exception.  Assume the core writes the instruction into 
mtval. The trap handler should detect that the instruction is mul, compute the result using 
integer instructions, place the answer in the destination register, and return to the next 
instruction without disturbing any other registers.  For any other trap, the trap handler should 
call write 3 to write_tohost to terminate the program with prejudice. Also write the startup code 
to set the trap vector and point mscratch to a trap stack.  Write a sample program to execute mul 
with 7 * 9, and simulate it and check that it triggers the trap handler and produces the right 
result. */
# my attempt:

// [from trap.S]
// Demonstrates setting up traps and invoking a trap handler.
// The trap handler accepts timer interrupts and ecalls.
// Saves cause and mtval into the signature
// Ecall takes one argument in a0
//   0: change privilege mode to user
//   1: change privilege mode to supervisor
//   3: change privilege mode to machine
//   4: exit program with write tohost

.EQU MTIME,    0x200bff8
.EQU MTIMECMP, 0x2004000

.global rvtest_entry_point

rvtest_entry_point:
    la sp, topofstack   # Initialize stack pointer (not used)
    la s6, begin_signature  # s6 points to signature

    # Set up timer
    jal set_timecmp

    # Set up interrupts
    la t0, trap_handler
    csrw mtvec, t0      # Initialize MTVEC to trap_handler
    csrw mideleg, zero  # Don't delegate interrupts
    csrw medeleg, zero  # Don't delegate exceptions
    li t0, 0x080       
    csrw mie, t0        # Enable machine timer interrupt
    la t0, topoftrapstack 
    csrw mscratch, t0   # MSCRATCH holds trap stack pointer
    csrsi mstatus, 0x8  # Turn on mstatus.MIE global interrupt enable

main:
    # Change to user mode
    li a0, 0            # a0 = 0: argument to enter user mode
    ecall               # System call to enter user mode

    # Wait for timer interrupts
    li t0, 0x1000       # loop counter start value
loop: 
    addi t0, t0, -1     # decrement counter
    bne t0, zero, loop  # and repeat until zero

done:
    li a0, 4            # argument to finish program    
    ecall               # system call to finish program
    j self_loop         # wait forever (not taken)

set_timecmp:            # Set timer compare to 800 ticks later
    la t0, MTIME
    la t1, MTIMECMP
    ld t0, 0(t0)        # Read current timer
    addi t0, t0, 0x60   # Increment timer
    sd t0, 0(t1)        # Set MTIMECMP = MTIME + 0x800
    ret

.align 4                # trap handlers must be aligned to multiple of 4
trap_handler:
    # Load trap handler stack pointer tp
    csrrw tp, mscratch, tp  # swap MSCRATCH and tp
    sd t0, 0(tp)        # Save t0 and t1 on the stack
    sd t1, -8(tp)
    csrr t0, mcause     # Check the cause
    csrr t1, mtval      # And the trap value
    sd t0, 0(s6)        # Save MCAUSE and MTVAL in the signature
    sd t1, 8(s6)            
    addi s6, s6, 16     
    bgez t0, exception  # if msb is clear, it is an exception

interrupt:              # must be a timer interrupt 
    jal set_timecmp     # Increment compare for next timer interrupt
    j trap_return       # clean up and return

exception:
    csrr t1, mepc   # add 4 to MEPC to determine return Address
    addi t1, t1, 4
    csrw mepc, t1
    li t1, 8            # is it an ecall trap?
    andi t0, t0, 0xFC # if CAUSE = 8, 9, or 11
    bne t0, t1, trap_return # ignore other exceptions

ecall:
    li t0, 3
    beq a0, t0, write_tohost    # call 3: terminate program with prejudice
    bltu a0, t0, changeprivilege    # calls 0-3: change privilege level
    j trap_return       # ignore other ecalls

changeprivilege:
    li t0, 0x00001800   # mask off mstatus.MPP in bits 11-12
    csrc mstatus, t0
    andi a0, a0, 0x003  # only keep bottom two bits of argument
    slli a0, a0, 11     # move into mstatus.MPP position
    csrs mstatus, a0    # set mstatus.MPP with desired privilege

trap_return:            # return from trap handler
    ld t1, -8(tp)       # restore t1 and t0
    ld t0, 0(tp)
    csrrw tp, mscratch, tp  # restore tp
    mret                # return from trap

write_tohost:
    la t1, tohost
    li t0, 1            # 1 for success, 3 for failure
    sd t0, 0(t1)        # send success code

self_loop:
    j self_loop         # wait
    
.section .tohost 
tohost:                 # write to HTIF
    .dword 0
fromhost:
    .dword 0

.EQU XLEN,64
begin_signature:
    .fill 6*(XLEN/32),4,0xdeadbeef    # 
end_signature:

# Initialize stack with room for 512 bytes
.bss
    .space 512
topofstack:
# And another stack for the trap handler
.bss   
    .space 512
topoftrapstack:



# actual solution:
rvtest_entry_point:

    # set up trap trap_handler
    la t0, trap_handler # address of trap trap_handler
    csrw mtvec, t0      # mtvec = pointer to trap handler
    la t0, trapstack    # address of trap stack
    csrw mscratch, t0   # mscratch = pointer to trap stack

    li t0, 7        
    li t1, 9
    mul t2, t0, t1      # try 7 * 9.  It will trap and invoke trap handler

self_loop:
    j self_loop


trap_handler:
    csrrw tp, mscratch, tp  # swap tp and mscratch to put a trap stack pointer in tp

    # save all registers on trap stack.  We will need to index into them to 
# find the arguments to emulate multiply
    sw x0, 0(tp)            # x0 is 0, but we might want to use it
    sw x1, 4(tp)
    sw x2, 8(tp)
    sw x3, 12(tp)
    sw x4, 16(tp)
    sw x5, 20(tp)
    sw x6, 24(tp)
    sw x7, 28(tp)
    sw x8, 32(tp)
    sw x9, 36(tp)
    sw x10, 40(tp)
    sw x11, 44(tp)
    sw x12, 48(tp)
    sw x13, 52(tp)
    sw x14, 56(tp)
    sw x15, 60(tp)
    sw x16, 64(tp)
    sw x17, 68(tp)
    sw x18, 72(tp)
    sw x19, 76(tp)
    sw x20, 80(tp)
    sw x21, 84(tp)
    sw x22, 88(tp)
    sw x23, 92(tp)
    sw x24, 96(tp)
    sw x25, 100(tp)
    sw x26, 104(tp)
    sw x27, 108(tp)
    sw x28, 112(tp)
    sw x29, 116(tp)
    sw x30, 120(tp)
    sw x31, 124(tp)

    csrr t0, mcause         # check cause of trap
    li t1, 2                # cause 2 is illegal instruction
    bne t0, t1, exit        # exit for any other trap than illegal instruction

    # check if instruction is mul (op = 0110011, funct3 = 000, funct7 = 0000001)
    csrr t0, mtval          # fetch instruction that caused trap
    andi t1, t0, 127        # get op field (instr[7:0])
    xori t1, t1, 0b0110011  # set to 0 if op is 0110011
    srli t2, t0, 12         # get funct3 field (instr[14:12])
    andi t2, t2, 7          # mask off other bits.  Should be 0 if funct3 = 000
    srli t3, t0, 25         # get funct7 field (instr[31:25]).  No need to mask
    xori t3, t3, 0b0000001  # set to 0 if funct7 = 0000001
    or t1, t1, t2           # nonzero if op or funct3 mismatch
    or t1, t1, t3           # nonzero if instruction is not mul
    bnez t1, exit           # exit for any other instruction than mul

    # emulate mul: fetch arguments
    srli t1, t0, 15         # extract rs1 from instr[19:15]
    andi t1, t1, 31         # mask off other bits
    slli t1, t1, 2          # multiply rs1 by 4 to make it a word index
    add t1, tp, t1          # find location of rs1 on trap stack
    lw t1, 0(t1)            # read value of rs1
    srli t2, t0, 20         # extract rs2 from instr[24:20]
    andi t2, t2, 31         # mask off other bits
    slli t2, t2, 2          # multiply rs2 by 4 to make it a word index
    add t2, tp, t2          # find location of rs2 on trap stack
    lw t2, 0(t2)            # read value of rs2

    # emulate mul p = x * y: shift and add
    # x in t1, y in t2, p in t3
    // p = 0
    // while (y != 0)) {     # iterate until all bits of y are consumed
    //   if (y%2) p = p + x  # add x to running total
    //   y = y >> 1          # go on to next bit
    //   x = x << 1          # shift x to double
    // }

    li t3, 0                # p = 0
mulloop:
    beqz t2, muldone        # done if y == 0
    andi t4, t2, 1          # t4 = y % 2
    beqz t4, skipadd        # don't increment p if y%2 == 0
    add t3, t3, t1          # otherwise p = p + x0
skipadd:
    srli t2, t2, 1          # y = y >> 1
    slli t1, t1, 1          # x = x << 1
    j mulloop               # repeat until done
muldone:

    # find rd and put result there
    srli t1, t0, 7          # extract rd from instr[11:7]
    andi t1, t1, 31         # mask off other bits
    slli t1, t1, 2          # multiply rd by 4 to make it a word index
    add t1, tp, t1          # find location of rd on trap stack
    sw t3, 0(t1)            # store result into rd storage on trap stack

    # return to next instruction

    csrr t0, mepc           # read mepc
    addi t0, t0, 4          # mepc + 4
    csrw mepc, t0           # mepc = mpec + 4 (return to next instruction)
    # restore all of the registers from the trap stack (rd could be in any one)
    lw x1, 4(tp)
    lw x2, 8(tp)
    lw x3, 12(tp)
    lw x4, 16(tp)
    lw x5, 20(tp)
    lw x6, 24(tp)
    lw x7, 28(tp)
    lw x8, 32(tp)
    lw x9, 36(tp)
    lw x10, 40(tp)
    lw x11, 44(tp)
    lw x12, 48(tp)
    lw x13, 52(tp)
    lw x14, 56(tp)
    lw x15, 60(tp)
    lw x16, 64(tp)
    lw x17, 68(tp)
    lw x18, 72(tp)
    lw x19, 76(tp)
    lw x20, 80(tp)
    lw x21, 84(tp)
    lw x22, 88(tp)
    lw x23, 92(tp)
    lw x24, 96(tp)
    lw x25, 100(tp)
    lw x26, 104(tp)
    lw x27, 108(tp)
    lw x28, 112(tp)
    lw x29, 116(tp)
    lw x30, 120(tp)
    lw x31, 124(tp)
    csrrw tp, mscratch, tp  # restore tp and trap stack pointer
    mret

exit:
    la t1, tohost
    li t0, 3            # 1 for success, 3 for failure
    sw t0, 0(t1)        # send fail code
    j self_loop         # wait
    
.section .tohost 
tohost:                 # write to HTIF
    .dword 0

trapstack:
    .fill 32, 4             # room to save registers