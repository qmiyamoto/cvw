/* Write your own program similar to the one in Figure 7.15 that also has at least one register forwarded from 
the Memory stage, one register forwarded from the Writeback stage, one register that doesn’t require 
forwarding, one stall, and one flush on a taken branch.  Use different instructions in a different order 
than 7.15.  Sketch a diagram like 7.15 showing what each pipeline stage does in each cycle while handling 
each */

addi t0, zero, 42
ori t1, t0, 1
lb t2, 0(t0)
and t3, t2, t0
beq t3, zero, else      // forwarded from

sb t3, 0(t0)
xori t4, t3, 1

// ...

else: sub t5, t1, t4    // forwarded to