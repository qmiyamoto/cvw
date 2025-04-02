module priority_encoder(input logic [43:0] pre_normalized_fraction_sum,
                        output logic [5:0] leading_one);

    integer i;

    // leading one........... imply priority encoder
    always_comb
    begin
        leading_one = 6'b0;

        for (i = 0; i < 34; i++)
            begin
                if (pre_normalized_fraction_sum[i])
                    leading_one = i[5:0];
            end
    end 

endmodule