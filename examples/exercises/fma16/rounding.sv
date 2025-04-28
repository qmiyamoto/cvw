///////////////////////////////////////////////
// File: rounding.sv
//
// Written: Quinn Miyamoto, qmiyamoto@g.hmc.edu
// Created: April 21, 2025
//
// Purpose: _______________
///////////////////////////////////////////////

module rounding(input logic   [1:0] roundmode,
                input logic         abbreviated_sticky_bit,
                input logic  [43:0] normalized_fraction_sum,
                input logic  [5:0]  original_exponent_sum,
                input logic  [15:0] result_sum,
                output logic [15:0] result_rounded);
    
    logic       sign_sum;
    logic [4:0] exponent_sum;
    logic [9:0] fraction_sum;

    logic sticky_bit;
    logic overflow;
    logic least_significant_bit, guard_bit, rounding_bit;
    logic rz, rne, rp, rn;

    logic [11:0] prepended_rounded, fraction_rounded;
    logic [4:0]  exponent_rounded;
    logic [15:0] rounded_result;
    logic        overflow_fraction_rounded;

    logic [15:0] truncated;
    logic [15:0] rounded;
    logic        maximum_fraction;

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
    assign overflow = (original_exponent_sum[5] | (original_exponent_sum[4:0] == 5'b11111));

    // make it more easily apparent which rounding mode is being enabled
    assign rz = (roundmode == 2'b00);
    assign rne = (roundmode == 2'b01);
    assign rp = (roundmode == 2'b11);
    assign rn = (roundmode == 2'b10);

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
            exponent_rounded = exponent_sum + 5'b1;

        else
            // otherwise, keep the exponent the same
            exponent_rounded = exponent_sum;
    end

    // assemble the overall result of rounding
    assign rounded = {sign_sum, exponent_rounded, fraction_rounded[9:0]};

    // determine the result of truncation
    // note that this is the default output of the FMA
    assign truncated = result_sum;

    // select what to return, depending on the current rounding mode
    always_comb
    begin
        // Sign = 0, Overflow = 0
        if ((sign_sum == 1'b0) & (overflow == 1'b0))
        begin
            // L = X, G = 0, R | T = 0
            if ((guard_bit == 1'b0) & ((rounding_bit | sticky_bit) == 1'b0))
                result_rounded = truncated;

            // L = X, G = 0, R | T = 1
            else if ((guard_bit == 1'b0) & (rounding_bit | sticky_bit))
            begin
                if (rp)
                    result_rounded = rounded;

                else
                    result_rounded = truncated;
            end

            // L = 0, G = 1, R | T = 0
            else if ((least_significant_bit == 1'b0) & guard_bit & ((rounding_bit | sticky_bit) == 1'b0))
            begin
                if (rp)
                    result_rounded = rounded;

                else
                    result_rounded = truncated;
            end
            
            // L = 1, G = 1, R | T = 0
            else if (least_significant_bit & guard_bit & ((rounding_bit | sticky_bit) == 1'b0))
            begin
                if (rne | rp)
                    result_rounded = rounded;

                else
                    result_rounded = truncated;
            end

            // L = X, G = 1, R | T = 1
            else if (guard_bit & (rounding_bit | sticky_bit))
            begin
                if (rne | rp)
                    result_rounded = rounded;

                else
                    result_rounded = truncated;
            end

            // default case
            else
                result_rounded = truncated;
        end

        // Sign = 0, Overflow = 1
        else if ((sign_sum == 1'b0) & overflow)
        begin
            if (rne | rp)
                // positive infinity
                result_rounded = 16'b0111110000000000;

            else
                // positive maximum number
                result_rounded = 16'b0111101111111111;
        end

        // Sign = 1, Overflow = 0
        else if (sign_sum & (overflow == 1'b0))
        begin
            // L = X, G = 0, R | T = 0
            if ((guard_bit == 1'b0) & ((rounding_bit | sticky_bit) == 1'b0))
                result_rounded = truncated;

            // L = X, G = 0, R | T = 1
            else if ((guard_bit == 1'b0) & (rounding_bit | sticky_bit))
            begin
                if (rn)
                    result_rounded = rounded;

                else
                    result_rounded = truncated;
            end
            
            // L = 0, G = `1, R | T = 0
            else if ((least_significant_bit == 1'b0) & guard_bit & ((rounding_bit | sticky_bit) == 1'b0))
            begin
                // if ((rne & sticky_bit) | rn)
                if (rn) // rne | rn
                    result_rounded = rounded;

                else
                    result_rounded = truncated;
            end

            // L = 1, G = 1, R | T = 0
            else if (least_significant_bit & guard_bit & ((rounding_bit | sticky_bit) == 1'b0))
            begin
                if (rne | rn)
                    result_rounded = rounded;

                else
                    result_rounded = truncated;
            end

            // L = X, G = 1, R | T = 1
            else if (guard_bit & (rounding_bit | sticky_bit))
            begin
            // changes here?????
                if (rne  | rn)
                    result_rounded = rounded;

                else
                    result_rounded = truncated;
            end

            // default case
            else
                result_rounded = truncated;
        end

        // Sign = 1, Overflow = 1
        else if (sign_sum & overflow)
        begin
            if (rne | rn)
                // negative infinity
                result_rounded = 16'b1111110000000000;
            
            else
                // negative maximum number
                result_rounded = 16'b1111101111111111;
        end

        // default case
        else
            result_rounded = truncated;
    end
   
endmodule