///////////////////////////////////////////////
// File: special_case_determiner.sv
//
// Written: Quinn Miyamoto, qmiyamoto@g.hmc.edu
// Created: April 13, 2025
//
// Purpose: _______________
///////////////////////////////////////////////

module special_case_determiner(input logic  [15:0] x, y, result_rounded,
                               input logic         sign_x, sign_y, sign_z, sign_product,
                               input logic  [4:0]  exponent_x, exponent_y, exponent_z,
                               input logic  [9:0]  fraction_x, fraction_y, fraction_z,
                               output logic [15:0] result);
    
    logic nan_x, nan_y, nan_z,
          positive_infinity_x, positive_infinity_y, positive_infinity_z, positive_infinity_product,
          negative_infinity_x, negative_infinity_y, negative_infinity_z, negative_infinity_product;

    // determine whether x, y, and z are nan or not
    assign nan_x = ((exponent_x == 5'd31) & (|fraction_x));
    assign nan_y = ((exponent_y == 5'd31) & (|fraction_y));
    assign nan_z = ((exponent_z == 5'd31) & (|fraction_z));

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
    
        // if (x * y) = (zero * infinity) AND z is a valid number, the output is nan
        else if ((((x == 16'b0) & (positive_infinity_y | negative_infinity_y)) |
                  ((y == 16'b0) & (positive_infinity_x | negative_infinity_x))) & 
                  ((nan_z | positive_infinity_z | negative_infinity_z) == 1'b0))
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

        // otherwise, we can just return the result we previously calculated
        else
            result = result_rounded;

    end

endmodule