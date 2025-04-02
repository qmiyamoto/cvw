module priority_encoder(input logic [43:0] pre_normalized_fraction_sum,
                        output logic [5:0] leading_one);

    integer i;

    // search for and return the location of a given fraction's leading one
    // all results are zeroed at the LSB to the very right
    // (in terms of actual hardware, note that the for loop implies the presence of a priority encoder)
    always_comb
    begin
        // set a default case for the value of leading_one
        leading_one = 6'b0;

        // continue looping through the various bits of the fraction until a one is found
        for (i = 0; i < 34; i++)
            begin
                if (pre_normalized_fraction_sum[i])
                    // once the leading one has been found, return the integer i as a binary result
                    leading_one = i[5:0];
            end
    end 

endmodule