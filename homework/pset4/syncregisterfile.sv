/* Write SystemVerilog for a 32-entry x 64-bit synchronous register file with four read ports, 
two write ports, and register 0 hardwired to 0. */

// module regfile (
//   input logic clk,
//   input logic [4:0] a0, a1, a2, a3, a4, a5,
//   input logic we4, we5,
//   input logic [63:0] wd4, wd5
//   output logic [63:0] rd0, rd1, rd2, rd3,
// );
  
//   bit [63:0] mem[31:0];

//   always @(posedge clk) begin
//     rd0 <= (a0 == 0) ? 0 : mem[a0];
//     rd1 <= (a1 == 0) ? 0 : mem[a1];
//     rd2 <= (a2 == 0) ? 0 : mem[a2];
//     rd3 <= (a3 == 0) ? 0 : mem[a3];
//     if (we4) mem[a4] <= wd4;
//     if (we5) mem[a5] <= wd5;
//   end
// endmodule

// WRONG!!
module syncregfile #(parameter M = 5, N = 32) (
  input  logic         clk,
  input  logic         we5, we6,
  input  logic [M-1:0] a1, a2, a3, a4, a5, a6,
  input  logic [N-1:0] wd5. wd6,
  output logic [N-1:0] rd1, rd2, rd3, rd4);

  logic [N-1:0] mem[2**M];  // logic (not bit) to model uninitialized regs

  // asynchronous read on ports 1, 2, 3, and 4
  assign rd1 = mem[a1];
  assign rd2 = mem[a2];
  assign rd3 = mem[a3];
  assign rd4 = mem[a4];

  // synchronous write on ports 5 through 6
  always_ff @(posedge clk)
    if (we5) mem[a5] <= wd5;
    if (we6) mem[a6] <= wd6;
endmodule