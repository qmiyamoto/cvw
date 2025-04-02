module multiply(input logic [15:0] x, y,
                output logic [15:0] product,
                output logic [3:0] flags);

    logic sign_x, sign_y, sign_product;
    logic [4:0] exponent_x, exponent_y;
    logic [5:0] exponent_product;
    logic [9:0] fraction_x, fraction_y, fraction_product;
    logic [10:0] prepended_x, prepended_y;
    logic [21:0] prepended_product;
    logic prepended_overflow;
    logic invalid, overflow, underflow, inexact;

    // use bit swizzling to segment the half-precision floating point numbers accordingly
    assign {sign_x, exponent_x, fraction_x} = x;
    assign {sign_y, exponent_y, fraction_y} = y;

    // prepend the one to both fraction bits
    assign prepended_x = (fraction_x + 11'd1024);
    assign prepended_y = (fraction_y + 11'd1024);

    // multiply the fraction bits
    assign prepended_product = (prepended_x * prepended_y);

    // check the MSB for any overflow
    // (if the MSB is one, there is overflow)
    assign prepended_overflow = prepended_product[21];

    always_comb
    begin
        // if there's (prepended) overflow, drop the MSB and take the next ten as the fraction
        if (prepended_overflow == 1)
            begin
                // increment the exponent by one and account for the exponent's bias
                // (the bias for half-precision numbers is 15)
                exponent_product = ((exponent_x + exponent_y - 5'd15) + 1'b1);

                // set the fraction bits
                fraction_product = prepended_product[20:11];
            end

        // if there's no (prepended) overflow, drop the two MSBs and take the next ten as the fraction    
        else 
            begin
                // account for the exponent's bias
                // (the bias for half-precision numbers is 15)
                exponent_product = (exponent_x + exponent_y - 5'd15);

                // set the fraction bits
                fraction_product = prepended_product[19:10];
            end
    end

    // determine the sign of the product, accounting for negatives
    assign sign_product = (sign_x ^ sign_y);

    // return the product in half-precision floating point format
    assign product = {sign_product, exponent_product[4:0], fraction_product};

    // determine which flags should be raised based on the above arithmetic
    // for the fmul_2.tv tests, we don't need to handle invalid numbers
    assign invalid = 1'b0;
    // if the intermediate exponent is greater than the maximum possible value of the resultant exponent, there's overflow    
    assign overflow = (exponent_product > 6'd31);
    // if there is rounding or overflow, the product must be inexact
    assign inexact = (|prepended_product[9:0] | overflow);
    // for this project, we don't need to handle cases with underflow
    assign underflow = 1'b0;

    // return the flags accordingly (in the order of NV, OF, UF, NX)
    assign flags = {invalid, overflow, underflow, inexact};

endmodule