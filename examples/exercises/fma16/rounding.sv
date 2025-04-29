///////////////////////////////////////////////
// File: rounding.sv
//
// Written: Quinn Miyamoto, qmiyamoto@g.hmc.edu
// Created: April 21, 2025
//
// Purpose: Handles FMA operations with different rounding modes enabled
///////////////////////////////////////////////

module rounding(input logic  [1:0]  roundmode,                  // original input to the FMA unit, sets the rounding mode
                input logic  [6:0]  A_count,
                input logic         kill_product,
                input logic         sign_z, sign_product,
                input logic  [9:0]  fraction_z,
                input logic  [21:0] prepended_product,
                input logic         abbreviated_sticky_bit,     // sticky bit calculated with the main FMA's abbreviated logic
                input logic  [43:0] normalized_fraction_sum,    // 
                input logic  [5:0]  original_exponent_sum,      // exponential bits of the intermediate sum
                input logic  [15:0] result_sum,                 // fractional bits of the intermediate sum
                output logic [15:0] result_rounded,             // 
                output logic        overflow, inexact
               );
    
    logic       sign_sum;        // sign of sum
    logic [4:0] exponent_sum;    // 
    logic [9:0] fraction_sum;    // 

    logic sticky_bit;                                        // 
    logic initial_overflow;                                  // 
    logic least_significant_bit, guard_bit, rounding_bit;    //
    logic rz, rne, rp, rn;                                   // 

    logic [11:0] prepended_rounded, fraction_rounded;    // 
    logic [5:0]  exponent_rounded;                       // 
    logic [15:0] rounded_result;                         // 
    logic        overflow_fraction_rounded;              // 

    logic [15:0] truncated;           // 
    logic [15:0] rounded;             // 
    logic        maximum_fraction;    // 

    logic maximum_number_set;

    // use bit-swizzling to segment the result of addition accordingly
    assign {sign_sum, exponent_sum, fraction_sum} = result_sum;


    // determine the values of L, G, and R 
    assign least_significant_bit = normalized_fraction_sum[22];
    assign guard_bit = normalized_fraction_sum[21];
    assign rounding_bit = normalized_fraction_sum[20];




    // determine the value of T
    // essentially, if sticky_bit hadn't already been set with the adder's abbreviated logic...
    // ...take the OR of all of the bits following it and assign the result to the variable
    always_comb
    begin
        if (abbreviated_sticky_bit)
            sticky_bit = abbreviated_sticky_bit;
        
        else
            sticky_bit = |normalized_fraction_sum[19:0];
    end

    // detect whether overflow has occurred at any point during the multiplication/addition process
    assign initial_overflow = (original_exponent_sum[5] | (original_exponent_sum[4:0] == 5'b11111));

    // make it more easily apparent which rounding mode is being enabled
    assign rz = (roundmode == 2'b00);
    assign rne = (roundmode == 2'b01);
    assign rp = (roundmode == 2'b11);
    assign rn = (roundmode == 2'b10);


    logic negative_sticky_bit;
    assign negative_sticky_bit = (~(|fraction_z) & rne & kill_product & (A_count == 7'b1111111) & prepended_product[21] & ~(sign_product == sign_z));


    // kill G to set G equal to zero

    // prepend a one to the fractional bits of sum
    // additionally, provide space for potential overflow
    assign prepended_rounded = {1'b0, 1'b1, fraction_sum};

    // calculate the result of rounding by adding a one to the prepended sum
    assign fraction_rounded = prepended_rounded + 12'b1;

    // detect whether or not overflow has occurred from the above addition
    assign overflow_fraction_rounded = fraction_rounded[11];

    // determine what the exponent of the rounded result would be
    always_comb
    begin
        if (overflow_fraction_rounded)
            // if the addition of a one has indeed caused overflow, increment the exponent, as well
            exponent_rounded = {1'b0, exponent_sum} + 6'b1;

        else
            // otherwise, keep the exponent the same
            exponent_rounded = {1'b0, exponent_sum};
    end

    // assemble the overall result of rounding
    assign rounded = {sign_sum, exponent_rounded[4:0], fraction_rounded[9:0]};

    // determine the result of truncation
    // note that this is the default output of the FMA
    assign truncated = result_sum;

    // select what to return, depending on the current rounding mode
    always_comb
    begin
        // Sign = 0, Overflow = 0
        if ((sign_sum == 1'b0) & (initial_overflow == 1'b0))
        begin
            // L = X, G = 0, R | T = 0
            if ((guard_bit == 1'b0) & ((rounding_bit | sticky_bit) == 1'b0))
            begin
                result_rounded = truncated;
                maximum_number_set = 1'b0;
            end

            // L = X, G = 0, R | T = 1
            else if ((guard_bit == 1'b0) & (rounding_bit | sticky_bit))
            begin
                if (rp)
                begin
                    result_rounded = rounded;
                    maximum_number_set = 1'b0;
                end

                else
                begin
                    result_rounded = truncated;
                    maximum_number_set = 1'b0;
                end
            end

            // L = 0, G = 1, R | T = 0
            else if ((least_significant_bit == 1'b0) & guard_bit & ((rounding_bit | sticky_bit) == 1'b0))
            begin
                if (rp)
                begin
                    result_rounded = rounded;
                    maximum_number_set = 1'b0;
                end

                else
                begin
                    result_rounded = truncated;
                    maximum_number_set = 1'b0;
                end
            end
            
            // L = 1, G = 1, R | T = 0
            else if (least_significant_bit & guard_bit & ((rounding_bit | sticky_bit) == 1'b0))
            begin
                if (rne | rp)
                begin
                    result_rounded = rounded;
                    maximum_number_set = 1'b0;
                end

                else
                begin
                    result_rounded = truncated;
                    maximum_number_set = 1'b0;
                end
            end

            // L = X, G = 1, R | T = 1
            else if (guard_bit & (rounding_bit | sticky_bit))
            begin
                if ((rne & ~negative_sticky_bit) | rp)
                begin
                    result_rounded = rounded;
                    maximum_number_set = 1'b0;
                end

                else
                begin
                    result_rounded = truncated;
                    maximum_number_set = 1'b0;
                end
            end

            // default case
            else
            begin
                result_rounded = truncated;
                maximum_number_set = 1'b0;
            end
        end

        // Sign = 0, Overflow = 1
        else if ((sign_sum == 1'b0) & initial_overflow)
        begin
            if (rne | rp)
            begin
                // positive infinity
                result_rounded = 16'b0111110000000000;
                maximum_number_set = 1'b0;
            end

            else
            begin
                // positive maximum number
                result_rounded = 16'b0111101111111111;
                maximum_number_set = 1'b1;
            end
        end

        // Sign = 1, Overflow = 0
        else if (sign_sum & (initial_overflow == 1'b0))
        begin
            // L = X, G = 0, R | T = 0
            if ((guard_bit == 1'b0) & ((rounding_bit | sticky_bit) == 1'b0))
            begin
                result_rounded = truncated;
                maximum_number_set = 1'b0;
            end

            // L = X, G = 0, R | T = 1
            else if ((guard_bit == 1'b0) & (rounding_bit | sticky_bit))
            begin
                if (rn)
                begin
                    result_rounded = rounded;
                    maximum_number_set = 1'b0;
                end

                else
                begin
                    result_rounded = truncated;
                    maximum_number_set = 1'b0;
                end
            end
            
            // L = 0, G = `1, R | T = 0
            else if ((least_significant_bit == 1'b0) & guard_bit & ((rounding_bit | sticky_bit) == 1'b0))
            begin
                // if ((rne & sticky_bit) | rn)
                if (rn) // rne | rn
                begin
                    result_rounded = rounded;
                    maximum_number_set = 1'b0;
                end

                else
                begin
                    result_rounded = truncated;
                    maximum_number_set = 1'b0;
                end
            end

            // L = 1, G = 1, R | T = 0
            else if (least_significant_bit & guard_bit & ((rounding_bit | sticky_bit) == 1'b0))
            begin
                if (rne | rn)
                begin
                    result_rounded = rounded;
                    maximum_number_set = 1'b0;
                end

                else
                begin
                    result_rounded = truncated;
                    maximum_number_set = 1'b0;
                end
            end

            // L = X, G = 1, R | T = 1
            else if (guard_bit & (rounding_bit | sticky_bit))
            begin
            // changes here?????
                if ((rne & ~negative_sticky_bit) | rn)
                begin
                    result_rounded = rounded;
                    maximum_number_set = 1'b0;
                end

                else
                begin
                    result_rounded = truncated;
                    maximum_number_set = 1'b0;
                end
            end

            // default case
            else
            begin
                result_rounded = truncated;
                maximum_number_set = 1'b0;
            end
        end

        // Sign = 1, Overflow = 1
        else if (sign_sum & initial_overflow)
        begin
            if (rne | rn)
            begin
                // negative infinity
                result_rounded = 16'b1111110000000000;
                maximum_number_set = 1'b0;
            end
            
            else
            begin
                // negative maximum number
                result_rounded = 16'b1111101111111111;
                maximum_number_set = 1'b1;
            end
        end

        // default case
        else
        begin
            result_rounded = truncated;
            maximum_number_set = 1'b0;
        end
    end

    assign overflow = ((original_exponent_sum > 6'd30) | (overflow_fraction_rounded & (exponent_rounded > 6'd30)))
    & (~maximum_number_set);

    assign inexact = (rounding_bit | guard_bit | sticky_bit | overflow);
   
endmodule