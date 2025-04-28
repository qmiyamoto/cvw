///////////////////////////////////////////////
// File: special_case_determiner.sv
//
// Written: Quinn Miyamoto, qmiyamoto@g.hmc.edu
// Created: April 13, 2025
//
// Purpose: Handle FMA operations with special cases
///////////////////////////////////////////////

module special_case_determiner(input logic  [15:0] x, y, z, result_product, result_sum,                                 // original inputs to the FMA unit
                               input logic  [15:0] result_rounded,                          // intermediate result after accounting for rounding
                               input logic         sign_x, sign_y, sign_z, sign_product,    // signs of the original inputs and the intermediate product
                               input logic  [4:0]  exponent_x, exponent_y, exponent_z,      // exponential bits of the original inputs
                               input logic [5:0] exponent_sum,
                               input logic  [9:0]  fraction_x, fraction_y, fraction_z,      // fractional bits of the original inputs
                               input logic kill_z, kill_product,
                               output logic [15:0] result                                   // final result after accounting for special cases
                              );
    
    logic nan_x, nan_y, nan_z,                                                                          // signals for the presence of NaN
          zero_x, zero_y, zero_z,                                                                       // signals for the presence of zero
          positive_infinity_x, positive_infinity_y, positive_infinity_z, positive_infinity_product,     // signals for the presence of positive infinity
          negative_infinity_x, negative_infinity_y, negative_infinity_z, negative_infinity_product;     // signals for the presence of negative infinity

    // determine whether x, y, and z are nan or not
    assign nan_x = ((exponent_x == 5'd31) & (|fraction_x));
    assign nan_y = ((exponent_y == 5'd31) & (|fraction_y));
    assign nan_z = ((exponent_z == 5'd31) & (|fraction_z));

    // determine whether x, y, and z are (some sort of) zero or not
    assign zero_x = (x[14:0] == 15'b0);
    assign zero_y = (y[14:0] == 15'b0);
    assign zero_z = (z[14:0] == 15'b0);



    logic overflow;
    assign overflow = (exponent_sum[5] | (exponent_sum[4:0] == 5'b11111));




    logic maximum_number_x, negative_maximum_number_x, maximum_number_y, negative_maximum_number_y, maximum_number_z, negative_maximum_number_z;

    assign maximum_number_x = (x == 16'b0111101111111111);
    assign negative_maximum_number_x = (x == 16'b1111101111111111);
    assign maximum_number_y = (y == 16'b0111101111111111);
    assign negative_maximum_number_y = (y == 16'b1111101111111111);
    assign maximum_number_z = (z == 16'b0111101111111111);
    assign negative_maximum_number_z = (z == 16'b1111101111111111);

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

    always_comb
    begin
        // if there's at least one quiet or signaling nan, the output is also nan
        if (nan_x | nan_y | nan_z)
            result = 16'b0111111000000000;
    
        // if (x * y) = (zero * infinity), the output is nan
        else if ((zero_x & (positive_infinity_y | negative_infinity_y)) |
                  (zero_y & (positive_infinity_x | negative_infinity_x)))
            result = 16'b0111111000000000;
        
        // if we are adding two infinities with different signs, the output is nan
        else if ((positive_infinity_product & negative_infinity_z) |
                 (negative_infinity_product & positive_infinity_z))
            result = 16'b0111111000000000;

        // if we add positive infinity to z, or our product to positive infinity, the output is positive infinity
        else if ((((negative_infinity_x | negative_infinity_y) == 1'b0) & positive_infinity_z) |
                   (positive_infinity_product & (negative_infinity_z == 1'b0)))
            result = 16'b0111110000000000;

        // if we add negative infinity to z, or our product to negative infinity, the output is negative infinity
        else if ((((positive_infinity_x | positive_infinity_y) == 1'b0) & negative_infinity_z) |
                 (negative_infinity_product & (positive_infinity_z == 1'b0)))
            result = 16'b1111110000000000;

        // +0 * -0 = +0
        else if (zero_x & zero_y)
        begin
            // positive zero multiplied by negative zero
            if (((sign_x == 1'b0) & sign_y) | (sign_x & (sign_y == 1'b0)))
            begin
                if (zero_z & sign_z)
                    result = 16'b1000000000000000;

                else if (zero_z & (sign_z == 1'b0))
                    result = 16'b0000000000000000;

                else
                    result = z;
            end

            // negative zero multiplied by negative zero
            else if (sign_x & sign_y)
            begin
                if (zero_z)
                    result = 16'b0000000000000000;

                else
                    result = z;
            end

            // positive zero multiplied by positive zero
            else if ((sign_x == 1'b0) & (sign_y == 1'b0))
            begin
                if (zero_z)
                    result = 16'b0000000000000000;
                
                else
                    result = z;
            end

            else
                result = result_rounded;
        end

        // multiplying by one negative zero
        else if ((zero_x & sign_x) | (zero_y & sign_y))
        begin
            // adding to negative zero
            if (zero_z & sign_z)
            begin
                // if the product is negative,
                if (sign_product)
                    result = 16'b1000000000000000;
                    
                else
                    result = 16'b0000000000000000;
            end

            else if (zero_z & (sign_z == 1'b0))
                result = 16'b0000000000000000;

            else
                result = z;
        end

        // multiplying by positive zero
        else if ((zero_x & (sign_x == 1'b0)) | (zero_y & (sign_y == 1'b0)))
        begin
            // adding to negative zero
            if (zero_z & sign_z)
            begin
                // if the product is negative,
                if (sign_product)
                    result = 16'b1000000000000000;
                    
                else
                    result = 16'b0000000000000000;
            end

            else if (zero_z & (sign_z == 1'b0))
                result = 16'b0000000000000000;

            else
                result = z;
        end

        else if (kill_z & kill_product)
        begin
            if (~sign_product & sign_z)
                result = 16'b0000000000000000;

            else if (sign_product & sign_z)
                result = 16'b1000000000000000;

            else if (~sign_product & ~sign_z)
                result = 16'b0000000000000000;

            else if (sign_product & ~sign_z)
                result = 16'b1000000000000000;

            else
                result = result_rounded;
        end

        
        // else if (maximum_number_x | maximum_number_y | negative_maximum_number_x | negative_maximum_number_y)
        // begin
        //     if ((maximum_number_x & negative_maximum_number_y) | (negative_maximum_number_x & maximum_number_y))
        //         result = 16'b1111101111111111;

        //     else if ((maximum_number_x & maximum_number_y) | (negative_maximum_number_x & negative_maximum_number_y))
        //         result = 16'b0111101111111111;

        //     // else if (overflow)
        //     // begin
        //     //     if (sign_product)
        //     //         result = 16'b1111101111111111;

        //     //     else
        //     //         result = 16'b0111101111111111;
        //     // end
         

        // //     else if (sign_product & maximum_number_z)
        // //     begin
        // //         // if (result_sum < 16'b0111101111111111)
        // //         if (overflow == 1'b0)
        // //             result = result_rounded;
                
        // //         else
        // //             result = 16'b1111101111111111;
        // //     end
            
        // //     else if (sign_product & negative_maximum_number_z)
        // //         result = 16'b1111101111111111;

        // //     else if ((sign_product == 1'b0) & negative_maximum_number_z)
        // //     begin
        // //         // if (result_sum > 16'b1111101111111111)
        // //         if (overflow == 1'b0)
        // //             result = result_rounded;
                
        // //         else
        // //             result = 16'b0111101111111111;
        // //     end

        // //     else if ((sign_product == 1'b0) & maximum_number_z)
        // //         result = 16'b0111101111111111;

        //     else
        //         result = result_rounded;
        // end

        // else if ((~zero_x & ~zero_y) & (zero_z & sign_z))
        //      result = result_rounded;

        // otherwise, we can just return the result we previously calculated
        else
            result = result_rounded;

    end

endmodule