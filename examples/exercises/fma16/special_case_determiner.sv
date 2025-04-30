///////////////////////////////////////////////
// File: special_case_determiner.sv
//
// Written: Quinn Miyamoto, qmiyamoto@g.hmc.edu
// Created: April 13, 2025
//
// Purpose: Handle FMA operations with special cases
///////////////////////////////////////////////

module special_case_determiner(input logic  [15:0] x, y, z,                                 // original inputs to the FMA unit
                               input logic  [1:0]  roundmode,                               // original input to the FMA unit, sets the rounding mode
                               input logic  [15:0] result_rounded,                          // intermediate result after accounting for rounding
                               input logic         sign_x, sign_y, sign_z, sign_product,    // signs of the original inputs, and the intermediate product
                               input logic  [4:0]  exponent_x, exponent_y, exponent_z,      // exponential bits of the original inputs
                               input logic  [5:0]  exponent_sum,                            // exponential bits of the intermediate sum
                               input logic  [9:0]  fraction_x, fraction_y, fraction_z,      // fractional bits of the original inputs
                               input logic         kill_z, kill_product,                    // signals to zero out either z or the product
                               output logic [15:0] result,                                  // final result after accounting for special cases
                               output logic        invalid,                                 // invalid flag
                               output logic        special_case                             // flag signifying the result of the rounding unit being overwritten
                              );
    
    logic nan_x, nan_y, nan_z,                                                                          // signals for the presence of NaN
          signaling_nan_x, signaling_nan_y, signaling_nan_z,                                            // signals for the presence of sNaN
          zero_x, zero_y, zero_z,                                                                       // signals for the presence of zero
          positive_infinity_x, positive_infinity_y, positive_infinity_z, positive_infinity_product,     // signals for the presence of positive infinity
          negative_infinity_x, negative_infinity_y, negative_infinity_z, negative_infinity_product;     // signals for the presence of negative infinity

    logic overflow;     // overflow flag

    logic rn;     // round toward negative infinity

    // determine whether x, y, and z are nan or not
    assign nan_x = ((exponent_x == 5'd31) & (|fraction_x));
    assign nan_y = ((exponent_y == 5'd31) & (|fraction_y));
    assign nan_z = ((exponent_z == 5'd31) & (|fraction_z));

    // additionally, determine whether x, y, and z are signaling nans or not
    // if the given input is nan and the MSB of its fractional bits is zero, it's a signaling nan
    assign signaling_nan_x = (nan_x & (x[9] == 1'b0));
    assign signaling_nan_y = (nan_y & (y[9] == 1'b0));
    assign signaling_nan_z = (nan_z & (z[9] == 1'b0));

    // detect overflow when the MSB of the exponent is one, or when its lower bits are all one
    assign overflow = (exponent_sum[5] | (exponent_sum[4:0] == 5'b11111));

    // determine whether x, y, and z are (some sort of) zero or not
    assign zero_x = (x[14:0] == 15'b0);
    assign zero_y = (y[14:0] == 15'b0);
    assign zero_z = (z[14:0] == 15'b0);

    // determine whether x, y, and z are positive infinity or not
    assign positive_infinity_x = ((sign_x == 1'b0) & (exponent_x == 5'd31) & (fraction_x == 10'b0));
    assign positive_infinity_y = ((sign_y == 1'b0) & (exponent_y == 5'd31) & (fraction_y == 10'b0));
    assign positive_infinity_z = ((sign_z == 1'b0) & (exponent_z == 5'd31) & (fraction_z == 10'b0));

    // determine whether x, y, and z are negative infinity or not
    assign negative_infinity_x = ((sign_x) & (exponent_x == 5'd31) & (fraction_x == 10'b0));
    assign negative_infinity_y = ((sign_y) & (exponent_y == 5'd31) & (fraction_y == 10'b0));
    assign negative_infinity_z = ((sign_z) & (exponent_z == 5'd31) & (fraction_z == 10'b0));
    
    // determine whether the product is positive infinity, negative infinity, or neither
    assign positive_infinity_product = ((sign_product == 1'b0) & (positive_infinity_x | positive_infinity_y | negative_infinity_x | negative_infinity_y));
    assign negative_infinity_product = (sign_product & (positive_infinity_x | positive_infinity_y | negative_infinity_x | negative_infinity_y));

    // set the invalid flag when at least one of the following is true...
    assign invalid = ((((zero_x & (positive_infinity_y | negative_infinity_y)) | (zero_y & (positive_infinity_x | negative_infinity_x))) |    // (x * y) = (zero * infinity)
                       ((positive_infinity_product & negative_infinity_z) | (negative_infinity_product & positive_infinity_z))) |             // ((x * y) - z) = (infinity - infinity)
                        (signaling_nan_x | signaling_nan_y | signaling_nan_z)) ?                                                              // any of the inputs are snans
                     1'b1 : 1'b0;

    // signify whether the rounding mode is rn or not
    assign rn = (roundmode == 2'b10);

    // overwrite the value stored in result, depending on the presence of special cases
    always_comb
    begin
        // if there's at least one quiet or signaling nan, the output is also nan
        if (nan_x | nan_y | nan_z)
        begin
            result = 16'b0111111000000000;
            special_case = 1'b1;
        end
    
        // if (x * y) = (zero * infinity), the output is nan
        else if ((zero_x & (positive_infinity_y | negative_infinity_y)) |
                 (zero_y & (positive_infinity_x | negative_infinity_x)))
        begin
            result = 16'b0111111000000000;
            special_case = 1'b1;
        end
        
        // if we are adding two infinities with different signs, the output is nan
        else if ((positive_infinity_product & negative_infinity_z) |
                 (negative_infinity_product & positive_infinity_z))
        begin
            result = 16'b0111111000000000;
            special_case = 1'b1;
        end

        // if we add positive infinity to z, or our product to positive infinity, the output is positive infinity
        else if ((((negative_infinity_x | negative_infinity_y) == 1'b0) & positive_infinity_z) |
                   (positive_infinity_product & (negative_infinity_z == 1'b0)))
        begin
            result = 16'b0111110000000000;
            special_case = 1'b1;
        end

        // if we add negative infinity to z, or our product to negative infinity, the output is negative infinity
        else if ((((positive_infinity_x | positive_infinity_y) == 1'b0) & negative_infinity_z) |
                 (negative_infinity_product & (positive_infinity_z == 1'b0)))
        begin
            result = 16'b1111110000000000;
            special_case = 1'b1;
        end

        // if we multiply two zeros together, the output changes depending on their signs (as well as the sign of z)
        else if (zero_x & zero_y)
        begin
            // case: (+0 * -0)
            if (((sign_x == 1'b0) & sign_y) | (sign_x & (sign_y == 1'b0)))
            begin
                // case: ((+0 * -0) + -0) = -0
                if (zero_z & sign_z)
                begin
                    result = 16'b1000000000000000;
                    special_case = 1'b1;
                end

                // case: ((+0 * -0) + +0)
                else if (zero_z & (sign_z == 1'b0))
                begin
                    result = {rn, 15'b0};
                    special_case = 1'b1;
                end

                // default: ((+0 * -0) + z) = z
                else
                begin
                    result = z;
                    special_case = 1'b0;
                end
            end
                
            // case: (-0 * -0)
            else if (sign_x & sign_y)
            begin
                // case: ((-0 * -0) + 0)
                if (zero_z)
                begin
                    if (rn)
                    begin
                        result = {sign_z, 15'b0};
                        special_case = 1'b1;
                    end

                    else
                    begin
                        result = 16'b0000000000000000;
                        special_case = 1'b1;
                    end
                end

                // default: ((+0 * -0) + z) = z
                else
                begin
                    result = z;
                    special_case = 1'b0;
                end
            end

        // case: (+0 * +0)
            else if ((sign_x == 1'b0) & (sign_y == 1'b0))
            begin
                // case: ((+0 * +0) + 0)
                if (zero_z)
                begin
                    if (rn)
                    begin
                        result = {sign_z, 15'b0};
                        special_case = 1'b1;
                    end

                    else
                    begin
                        result = 16'b0000000000000000;
                        special_case = 1'b1;
                    end
                end
                    
                // default: ((+0 * +0) + z) = z
                else
                begin
                    result = z;
                    special_case = 1'b0;
                end
            end

            // default: return the result garnered from rounding
            else
            begin
                result = result_rounded;
                special_case = 1'b0;
            end
        end

        // if we are multiplying by at least one negative zero, the output changes depending on the situations below
        else if ((zero_x & sign_x) | (zero_y & sign_y))
        begin
            // case: ((x * -0) + -0), or ((-0 * y) + -0)
            if (zero_z & sign_z)
            begin
                if (rn == 1'b0)
                begin
                    result = {sign_product, 15'b0};
                    special_case = 1'b1;
                end

                else
                begin
                    result = 16'b1000000000000000;
                    special_case = 1'b1;
                end
            end

            // case: ((x * -0) + +0), or ((-0 * y) + +0)
            else if (zero_z & (sign_z == 1'b0))
            begin
                if (rn)
                begin
                    result = {sign_product, 15'b0};
                    special_case = 1'b1;
                end

                else
                begin
                    result = 16'b0000000000000000;
                    special_case = 1'b1;
                end
            end

            // default: (x * -0) + z) = z, or ((-0 * y) + z) = z
            else
            begin
                result = z;
                special_case = 1'b0;
            end
        end

        // if we are multiplying by at least one positive zero, the output changes depending on the situations below
        else if ((zero_x & (sign_x == 1'b0)) | (zero_y & (sign_y == 1'b0)))
        begin
            // case: ((x * +0) + -0), or ((+0 * y) + -0)
            if (zero_z & sign_z)
            begin
                if (rn == 1'b0)
                begin
                    result = {sign_product, 15'b0};
                    special_case = 1'b1;
                end

                else
                begin
                    result = 16'b1000000000000000;
                    special_case = 1'b1;
                end
            end

            // case: ((x * +0) + +0), or ((+0 * y) + +0)
            else if (zero_z & (sign_z == 1'b0))
            begin
                if (rn)
                begin
                    result = {sign_product, 15'b0};
                    special_case = 1'b1;
                end

                else
                begin
                    result = 16'b0000000000000000;
                    special_case = 1'b1;
                end
            end

            // default: ((x * +0) + z) = z, or ((+0 * y) + z) = z
            else
            begin
                result = z;
                special_case = 1'b0;
            end
        end

        // if we are both killing z and the product, the output is zero (of some sort)
        else if (kill_z & kill_product)
        begin
            // if the product is positive and z is negative, the output is positive zero
            if ((sign_product == 1'b0) & sign_z)
            begin
                result = 16'b0000000000000000;
                special_case = 1'b1;
            end

            // if both the product and z are negative, the output is negative zero
            else if (sign_product & sign_z)
            begin
                result = 16'b1000000000000000;
                special_case = 1'b1;
            end

            // if both the product and z are positive, the output is positive zero
            else if ((sign_product == 1'b0) & (sign_z == 1'b0))
            begin
                result = 16'b0000000000000000;
                special_case = 1'b1;
            end

            // if the product is negative and z is positive, the output is negative zero
            else if (sign_product & (sign_z == 1'b0))
            begin
                result = 16'b1000000000000000;
                special_case = 1'b1;
            end

            // otherwise, return the result garnered from rounding
            else
            begin
                result = result_rounded;
                special_case = 1'b0;
            end
        end

        // otherwise, we can just return the result we previously calculated
        else
        begin
            result = result_rounded;
            special_case = 1'b0;
        end
    end

endmodule