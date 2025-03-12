///////////////////////////////////////////
// mul.sv
//
// Written: David_Harris@hmc.edu 16 February 2021
// Modified: 
//
// Purpose: Integer multiplication
// 
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
// 
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Licensed under the Solderpad Hardware License v 2.1 (the “License”); you may not use this file 
// except in compliance with the License, or, at your option, the Apache License version 2.0. You 
// may obtain a copy of the License at
//
// https://solderpad.org/licenses/SHL-2.1/
//
// Unless required by applicable law or agreed to in writing, any work distributed under the 
// License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, 
// either express or implied. See the License for the specific language governing permissions 
// and limitations under the License.
////////////////////////////////////////////////////////////////////////////////////////////////

module mul #(parameter XLEN) (
  input  logic                clk, reset,
  input  logic                StallM, FlushM,
  input  logic [XLEN-1:0]     ForwardedSrcAE, ForwardedSrcBE, // source A and B from after Forwarding mux
  input  logic [2:0]          Funct3E,                        // type of multiply
  output logic [XLEN*2-1:0]   ProdM                           // double-widthproduct
);

    logic [XLEN*2-1:0]  PP1M, PP2M, PP3M, PP4M;               // registered partial products
    logic [(XLEN * 2 - 1):0] PP1E, PP2E, PP3E, PP4E;          // partial products
    
    // creates new logic variables to make the following math clearer
    logic A_m, B_m, P_m;
    logic [(XLEN - 2):0] A_prime, B_prime, PA, PB;
    logic [(2 * XLEN - 3):0] P_prime;
    

  //////////////////////////////
  // Execute Stage: Compute partial products
  //////////////////////////////

  // assigns values to aforementioned variables
  assign {A_m, A_prime} = ForwardedSrcAE;
  assign {B_m, B_prime} = ForwardedSrcBE;
  assign PA = B_m * A_prime;
  assign PB = A_m * B_prime;
  assign P_m = A_m * B_m;
  assign P_prime = A_prime * B_prime;

  // sets P1 = P', as that is the same for every case
  assign PP1E = {2'b0, P_prime};      // P1 = P'

  always_comb
    begin
      // calculates components for unsigned multiplication
      if ((Funct3E == 3'b000) | (Funct3E == 3'b011))
        begin
          PP2E = {2'b0, PA, {(XLEN - 1){1'b0}}};          // P2 = PA
          PP3E = {2'b0, PB, {(XLEN - 1){1'b0}}};          // P3 = PB
          PP4E = {1'b0, P_m, {(2 * XLEN - 2){1'b0}}};     // P4 = Pm << 2N - 2
        end
      
      // calculates components for signed multiplication
      else if (Funct3E == 3'b001)
        begin
          PP2E = {2'b0, ~PA, {(XLEN - 1){1'b0}}};                         // P2 = ~PA
          PP3E = {2'b0, ~PB, {(XLEN - 1){1'b0}}};                         // P3 = ~PB
          PP4E = {1'b1, P_m, {(XLEN - 3){1'b0}}, 1'b1, {(XLEN){1'b0}}};   // P4 = Pm << 2N - 2 + 1 << 2N - 1 + 1 << N
        end

      // calculates components for signed x unsigned multiplication
      else if (Funct3E == 3'b010)
        begin
          PP2E = {2'b0, PA, {(XLEN - 1){1'b0}}};                                // P2 = PA
          PP3E = {2'b0, ~PB, {(XLEN - 1){1'b0}}};                               // P3 = ~PB
          PP4E = {1'b1, ~P_m, {(XLEN - 2){1'b0}}, 1'b1, {(XLEN - 1){1'b0}}};    // P4 = ~Pm << 2N - 2 + 1 << 2N - 1 + 1 << N - 1
        end

      // sets default case
      else
        begin 
          PP2E = 'b0;
          PP3E = 'b0;
          PP4E = 'b0;
        end
    end


  // Memory Stage: Sum partial proudcts
  //////////////////////////////

  flopenrc #(XLEN*2) PP1Reg(clk, reset, FlushM, ~StallM, PP1E, PP1M); 
  flopenrc #(XLEN*2) PP2Reg(clk, reset, FlushM, ~StallM, PP2E, PP2M); 
  flopenrc #(XLEN*2) PP3Reg(clk, reset, FlushM, ~StallM, PP3E, PP3M); 
  flopenrc #(XLEN*2) PP4Reg(clk, reset, FlushM, ~StallM, PP4E, PP4M); 

  // add up partial products; this multi-input add implies CSAs and a final CPA
  assign ProdM = PP1M + PP2M + PP3M + PP4M; //ForwardedSrcAE * ForwardedSrcBE;
 endmodule
