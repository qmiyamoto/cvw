// 0000000080000994

.global fir
fir:
    // a0 = x[0]
    // a1 = c[0]
    // a2 = y[0]
    // a3 = n
    // a4 = m

    addi sp, sp, -8    // make space in the stack
    sw s0, 0(sp)        // save s0
    sw s1, 4(sp)        // save s1

    addi s0, x0, 0      // j = 0

    sub a3, a3, a4      // n - m
    addi a3, a3, 1      // (n - m) + 1

    addi a4, a4, -1     // m - 1

    slli t1, a4, 2      // 4 * (m - 1)
    add t1, a0, t1      // address of x[j - i + (m - 1)] = x[m - 1]

    add t2, x0, a2      // address of y[0]

    for1: bgt s0, a3, done1    // if j <= (n - m + 1)
          addi s1, x0, 0       // i = 0

          add t0, x0, a1       // address of c[0]

    for2: bgt s1, a4, done2    // if i <= (m - 1)
          // mul_q31
          lw t3, 0(t0)         // load c[i]
          addi t0, t0, 4       // update address to c[i + 1]

          lw t4, 0(t1)         // load x[j - i + (m - 1)]
          addi t1, t1, -4      // update address to x[j - i + (m - 1) + 1]

          mul t3, t3, t4       // c[i] * x[j - i + (m - 1)]
          slli t3, t3, 1       // (c[i] * x[j - i + (m - 1)]) << 1
          srli t3, t3, 32      // ((c[i] * x[j - i + (m - 1)]) << 1) >> 32

          // add_q31
          lw t4, 0(t2)         // load y[j]
          add t3, t4, t3       // y[j] = y[j] + mul_q31(c[i], x[j - i + (m - 1)])
          sw t3, 0(t2)         // store y[j]

          addi s1, s1, 1       // i++
          j for2

    done2:
        addi s0, s0, 1      // j++

        slli t5, s1, 2      // i * 4
        add t1, t1, t5      // restores i values lost in loop
        addi t1, t1, 4      // update address of x[j - i + (m - 1)]

        addi t2, t2, 4      // update address to y[j + 1]
        j for1

    done1:

    lw s1, 4(sp)        // restore s1
    lw s0, 0(sp)        // restore s0
    addi sp, sp, 8     // deallocate space in the stack
    ret

// -O2 optimization mcycle = 1147

/*
My hand-coded assembly cycle count is slower than my C code cycle count, when comparing their
mcycle after running -O2 optimization (1147 for assembly vs. 892 for C).  This is because the
latter's object dump is far more concise and minimized redundancies (i.e. the number of times 
certain lines of code would have to repeat), thus making it faster.
*/