module add(input logic [15:0]  x, y, z,
           input logic         mul, add, negp, negz, 
           input logic [1:0]   roundmode,
           output logic [15:0] result,
           output logic [3:0]  flags);

    logic        sign_x, sign_y, sign_z, sign_product, sign_sum;
    logic [4:0]  exponent_x, exponent_y, exponent_z;
    logic [5:0]  exponent_sum;
    logic [6:0]  exponent_product;
    logic [9:0]  fraction_x, fraction_y, fraction_z, fraction_sum;
    logic [10:0] prepended_x, prepended_y;
    logic [21:0] prepended_product;
    
    logic        sign_addend, sticky_bit;
    logic [6:0]  A_count;
    logic [32:0] fraction_addend, fraction_killed_product;
    logic [43:0] preshifted_z, shifted_z;
    logic        kill_z, kill_product, invert_addend;
    logic [33:0] inverted_fraction_addend, pre_sum, negative_pre_sum;
    logic [43:0] pre_normalized_fraction_sum, normalized_fraction_sum;
    logic        negative_sum;
    logic [5:0]  leading_one, corrected_index;
    logic [15:0] result_sum;

    logic invalid, overflow, underflow, inexact;

    // --------------------

    // MULTIPLICATION LOGIC:
    // use bit swizzling to segment the half-precision floating point numbers accordingly
    assign {sign_x, exponent_x, fraction_x} = x;
    assign {sign_y, exponent_y, fraction_y} = y;
    assign {sign_z, exponent_z, fraction_z} = z;

    // prepend a one to both fraction bits of x and y
    assign prepended_x = (fraction_x + 11'd1024);
    assign prepended_y = (fraction_y + 11'd1024);

    // multiply the fraction bits
    assign prepended_product = (prepended_x * prepended_y);

    // compute the exponent of the product
    always_comb
    begin
        if ((x == 16'b0) | (y == 16'b0))
            // keep the exponent at zero if either x or y has exponents equivalent to such
            exponent_product = 7'b0;

        else
            // otherwise, add the exponent bits of the two and account for bias
            // (the bias for half-precision numbers is 15)
            exponent_product = ({2'b0, exponent_x} + {2'b0, exponent_y} - 7'd15);
    end

    // determine the sign of the product, accounting for negatives
    assign sign_product = (sign_x ^ sign_y);

    // --------------------

    // ADDITION LOGIC:
    // set the alignment shift amount
    assign A_count = (exponent_product - {2'b0, exponent_z} + 7'd12);

    // if z is too small to affect anything but the sticky bit, kill it
    // (in other words, assert kill_z if A_count > (3N_f + 3) or if z is zero)
    assign kill_z = (($signed(A_count) > 33) | (z == 16'b0));
    
    // preshift the fraction bits of z so as to eradicate the need for (more complicated) bidirectional shifting
    // place z in the uppermost bits and prepend a one
    assign preshifted_z = {1'b1, fraction_z, 33'b0};
    
    // if the product is too small to affect anything but the sticky bit, kill it
    // (in other words, assert kill_product if A_count is negative, or if either x or y are zero)
    assign kill_product = (($signed(A_count) < 0) | (x == 16'b0) | (y == 16'b0));

    // perform a variable-alignment shift on z to the right
    always_comb
    begin
        if (kill_product)
            // if killing the product, leave the fraction bits of z alone
            shifted_z = {12'b0, 1'b1, fraction_z, 21'b0};

        else if (kill_z)
            // if killing z, zero it all out
            shifted_z = 44'b0;

        else
            // otherwise, shift z by A_count
            shifted_z = (preshifted_z >> A_count);
    end

    // set the sticky bit for the adder
    // (if the shifts performed on either z or the product pass a one through the sticky bit, it stays one forever)
    // (in other words, setting the sticky bit signals inaccuracy in the final result)
    always_comb
    begin
        if (kill_product)
            // when killing the product, set the sticky bit if both x and y are not zero
            sticky_bit = ~((x == 16'b0) | (y == 16'b0));
        
        else if (kill_z)
            // when killing z, set the sticky bit if z is not zero
            sticky_bit = ~(z == 16'b0);
        
        else
            // otherwise, set the sticky bit if any the fraction bits of z are nonzero
            sticky_bit = |shifted_z[9:0];
    end

    // align z to create a proper addend
    // ignore the bottom N_f bits
    assign fraction_addend = shifted_z[43:11];

    // set the sign of the addend via detection of an effective negative sign
    assign sign_addend = (sign_z ^ negz);

    // determine whether or not to perform effective subtraction
    // (in other words, determine whether or not the product and addend have opposite signs)
    assign invert_addend = (sign_product ^ sign_addend);

    // invert the addend during effective subtraction
    always_comb
    begin
        if (invert_addend)
            // if the product and addend have opposite signs, invert the latter and sign extend the negative
            inverted_fraction_addend = {1'b1, ~fraction_addend};

        else
            // otherwise, keep the addend the same and sign extend a zero
            inverted_fraction_addend = {1'b0, fraction_addend};
    end

    // zero out the fraction bits of the product when killing it and append two zeros to align with the addend
    assign fraction_killed_product = (~kill_product) ? {11'b0, prepended_product} : 33'b0;

    // optimize addition and subtraction with the use of two adders
    // perform addition or subtraction between the addend and product, with correction for a negative (addend) sticky bit
    // (first adder)
    assign pre_sum = ({1'b0, fraction_killed_product} + inverted_fraction_addend + {33'b0, ((~sticky_bit | kill_product) & invert_addend)});
    // subtract the product from the addend, with correction for a negative (product) sticky bit
    // (second adder)
    assign negative_pre_sum = ({1'b0, fraction_addend} + ~{1'b0, fraction_killed_product} + {33'b0, (~sticky_bit | ~kill_product)});
    
    // the result of subtracting the addend from the product is negative
    assign negative_sum = pre_sum[33];

    // determine the sign of the final sum, accounting for negatives
    assign sign_sum = (sign_product ^ negative_sum);
    
    // determine the magnitude of the fraction bits of the sum
    always_comb
    begin
        if (negative_sum)
            // if subtracting the addend from the product yields a negative, set the result to be the addend minus the product
            pre_normalized_fraction_sum = {10'b0, negative_pre_sum};
        
        else
            // otherwise, take the result to be that garnered from the first adder
            // this is essentially the same as doing pre_normalized_fraction_sum = (pre_sum >> 10), but without the expensive hardware
            // this also prevents an accidental shifting out of important, non-trivial digits
            pre_normalized_fraction_sum = {10'b0, pre_sum};
    end

    // use a priority encoder to determine the location of the leading one in the fraction bits of the pre-normalized sum  
    priority_encoder prior_enc(pre_normalized_fraction_sum, leading_one);

    // note that the priority encoder counts from right to left, so there must be some correction
    assign corrected_index = 6'd20 - leading_one;

    // calculate the exponent of the sum before normalization
    always_comb
    begin
        if (kill_product)
            // if killing the product, the exponent of the sum is equal to that of z
            // note again that we need to account for the corrected index from the priority encoder
            // in this case, subtracting the output location from 2N_f garners the right result
            exponent_sum = {1'b0, (exponent_z - corrected_index[4:0])};
        
        else
            // otherwise, the exponent of the sum is equal to that of the product minus the amount shifted by
            // again, there is a correction of 2N_f - leading_one
            exponent_sum = {exponent_product - {1'b0, corrected_index}}[5:0];
    end

    // normalize the fraction of the sum by shifting the pre-normalized fraction bits by N_f + (2N_f - leading_one)
    // by doing so, the leading one will always be in the same place no matter which number is being taken under consideration
    assign normalized_fraction_sum = (pre_normalized_fraction_sum << (32 - leading_one));

    // select the desired bits of the now-normalized sum to get the finalized components of the sum fraction
    // (acquiring said desired bits involves ignoring the first N_f + 2 and last 2N_f + 1 bits)
    assign fraction_sum = normalized_fraction_sum[31:22];

    // assemble the overall result of both the multiplication and addition
    assign result_sum = {sign_sum, exponent_sum[4:0], fraction_sum};

    // check for special cases and return the correct result accordingly
    special_case_determiner scd(x, y, result_sum, sign_x, sign_y, sign_z, sign_product, exponent_x, exponent_y, exponent_z, fraction_x, fraction_y, fraction_z, result);

    // --------------------

    // ROUNDING LOGIC:
    // 
    
    // --------------------

    // FLAG LOGIC:
    // determine which flags should be raised based on the above arithmetic
    // for the fmul_2.tv tests, we don't need to handle invalid numbers
    assign invalid = 1'b0;
    // if the intermediate exponent is greater than the maximum possible value of the resultant exponent, there's overflow    
    assign overflow = (exponent_product > 7'd31);
    // if there is rounding or overflow, the product must be inexact
    assign inexact = (|prepended_product[9:0] | overflow);
    // for this project, we don't need to handle cases with underflow
    assign underflow = 1'b0;

    // return the flags accordingly (in the order of NV, OF, UF, NX)
    assign flags = {invalid, overflow, underflow, inexact};

endmodule