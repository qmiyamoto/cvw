module multiply(input logic [15:0] x, y,
                output logic [15:0] result);

    logic sign_x, sign_y, sign_result;
    logic [4:0] exponent_x, exponent_y, exponent_result;
    logic [9:0] fraction_x, fraction_y, fraction_result;
    logic [10:0] prepended_x, prepended_y;
    logic [21:0] prepended_result;
    logic overflow;

    // use bit swizzling to segment the half-precision floating point numbers accordingly
    assign {sign_x, exponent_x, fraction_x} = x;
    assign {sign_y, exponent_y, fraction_y} = y;

    // prepend the one to both fraction bits
    assign prepended_x = (fraction_x + 0'b10000000000);
    assign prepended_y = (fraction_y + 0'b10000000000);

    // multiply the fraction bits
    assign prepended_result = (prepended_x * prepended_y);

    // check the MSB for any overflow
    // (if the MSB is one, there is overflow)
    assign overflow = prepended_result[21];

    always_comb
    begin
        // if there's overflow, drop the MSB and take the next ten as the fraction
        if (overflow == 1)
            begin
                // increment the exponent by one and account for the exponent's bias
                // (the bias for half-precision numbers is 15)
                exponent_result = ((exponent_x + exponent_y - 5'd15) + 0'b00001);

                // set the fraction bits
                fraction_result = prepended_result[20:11];
            end

        // if there's no overflow, drop the two MSBs and take the next ten as the fraction    
        else 
            begin
                // account for the exponent's bias
                // (the bias for half-precision numbers is 15)
                exponent_result = (exponent_x + exponent_y - 5'd15);

                // set the fraction bits
                fraction_result = prepended_result[19:10];
            end
    end

    // determine the sign of the result, accounting for negatives
    assign sign_result = (sign_x ^ sign_y);

    // return the result in half-precision floating point format
    assign result = {sign_result, exponent_result, fraction_result};

endmodule