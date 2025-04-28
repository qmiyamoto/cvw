///////////////////////////////////////////////
// File: priority_encoder.sv
//
// Written: Quinn Miyamoto, qmiyamoto@g.hmc.edu
// Created: March 30, 2025
//
// Purpose: Search for and return the location of a given fraction's leading one
///////////////////////////////////////////////

module priority_encoder(input logic  [43:0] pre_normalized_fraction_sum,    // resulting fraction from addition, pre-normalization shift
                        output logic [5:0]  leading_one                     // bit number at which the leading one is stored
                       );

    integer i;  // index that may be incremented for a loop

    // return the location of a given fraction's leading one
    // all results are zeroed at the LSB to the very right
    // (in terms of actual hardware, note that the for loop implies the presence of a priority encoder)
    always_comb
    begin
        // set a default case for the value of leading_one
        leading_one = 6'b0;

        // continue looping through the various bits of the fraction until a one is found
        for (i = 0; i < 43; i++)
            begin
                if (pre_normalized_fraction_sum[i])
                    // once the leading one has been found, return the integer i as a binary result
                    leading_one = i[5:0];
            end
    end 

endmodule