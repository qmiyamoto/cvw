module rounding(input logic  [1:0]  roundmode,
                input logic sticky_bit,
                input logic  [43:0] normalized_fraction_sum,
                input logic [5:0] exponent_sum1,
                input logic [15:0] result_sum,
                output logic [15:0] result_rounded,
                output logic special_case);

    
    logic overflow;
    logic sign_sum;
    logic [4:0] exponent_sum;
    logic [9:0] fraction_sum;
    logic rz, rne, rp, rn;
    logic least_significant_bit, guard_bit, rounding_bit;

    logic sticky_bit2;

    always_comb
    begin
        if (sticky_bit)
            sticky_bit2 = sticky_bit;
        else
            sticky_bit2 = |normalized_fraction_sum[19:0];
    end

    assign {sign_sum, exponent_sum, fraction_sum} = result_sum;



    assign least_significant_bit = normalized_fraction_sum[22];
    assign guard_bit = normalized_fraction_sum[21];
    assign rounding_bit = normalized_fraction_sum[20];


    assign rz = (roundmode == 2'b00);
    assign rne = (roundmode == 2'b01);
    assign rp = (roundmode == 2'b10);
    assign rn = (roundmode == 2'b11);
    

    logic [15:0] truncated;
    logic [15:0] rounded;
    logic maximum_fraction;

    // default
    assign truncated = result_sum;

    logic [11:0] prepended_rounded, fraction_rounded;
    logic [4:0] exponent_rounded;

    logic [15:0] rounded_result;

    // add spapce for overflow + add one for prepended
    assign prepended_rounded = {1'b0, 1'b1, fraction_sum};

    assign fraction_rounded = prepended_rounded + 12'b1;

    logic overflow_fraction_rounded;

    assign overflow = (exponent_sum1[5] & (exponent_sum1[4:0] == 5'b0));

// changed logic!!
    assign overflow_fraction_rounded = fraction_rounded[11];

    always_comb
    begin
        if (overflow_fraction_rounded)
            exponent_rounded = exponent_sum + 5'b1;

        else
            exponent_rounded = exponent_sum;
    end

    assign rounded = {sign_sum, exponent_rounded, fraction_rounded[9:0]};

    logic use_rounded;




// GRT - Action
// 0xx - round down = do nothing (x means any bit value, 0 or 1)
// 100 - this is a tie: round up if the mantissa's bit just before G is 1, else round down=do nothing
// 101 - round up
// 110 - round up
// 111 - round up
    logic [2:0] g_r_t;
    assign g_r_t = {guard_bit, rounding_bit, sticky_bit2};

    always_comb
    begin
        if (g_r_t == 3'b100)
        begin
            if (least_significant_bit)
                use_rounded = 1'b1;
            else
                use_rounded = 1'b0;
        end
        else if ((g_r_t == 3'b101) | (g_r_t == 3'b110) | ((g_r_t == 3'b111) & ~exponent_sum[0] & (&fraction_sum)))
            use_rounded = 1'b1;
        else
            use_rounded = 1'b0;
    end

    logic even_rounded;
    assign even_rounded = (rounded[0] == 1'b0);




// always_comb
//     begin
//         if ((sign_sum == 1'b0) & (overflow == 1'b0))
//         begin
//             if ((guard_bit == 1'b0) & ((rounding_bit | sticky_bit2) == 1'b0))
//                 begin result_rounded = truncated;
//                 special_case = 1'b0; end

//             else if ((guard_bit == 1'b0) & (rounding_bit | sticky_bit2))
//             begin
//                 if (rp)
//                     begin result_rounded = rounded;
//                     special_case = 1'b0; end 

//                 else
//                     begin result_rounded = truncated;
//                     special_case = 1'b0; end
//             end

//             else if ((least_significant_bit == 1'b0) & guard_bit & ((rounding_bit | sticky_bit2) == 1'b0))
//             begin
//                 // does this actually work????
//                 if (rp)
//                     begin result_rounded = rounded;
//                     special_case = 1'b0; end

//                 else
//                     begin result_rounded = truncated;
//                     special_case = 1'b0; end
//             end
            
//             else if (least_significant_bit & guard_bit & ((rounding_bit | sticky_bit2) == 1'b0))
//             begin
//                 if (rne | rp)
//                     begin 
//                         if (use_rounded)
//                             begin result_rounded = rounded;
//                             special_case = 1'b0; end
//                         else 
//                         begin result_rounded = truncated;
//                             special_case = 1'b0; end
//                             end

//                 else
//                     begin result_rounded = truncated;
//                     special_case = 1'b0; end
//             end

//             else if (guard_bit & (rounding_bit | sticky_bit2))
//             begin
//                 if (rne | rp)
//                     begin 
//                         if (use_rounded)
//                             begin result_rounded = rounded;
//                             special_case = 1'b0; end
//                         else 
//                         begin result_rounded = truncated;
//                             special_case = 1'b0; end
//                             end

//                 else
//                     begin result_rounded = truncated;
//                     special_case = 1'b0; end
//             end

//             else
//                 begin result_rounded = truncated;
//                 special_case = 1'b0; end

//         end

//         else if ((sign_sum == 1'b0) & overflow)
//         begin
//             if (rne | rp)
//                 begin result_rounded = 16'b0111110000000000;
//                 // result_rounded = rounded;
//                 special_case = 1'b1; end

//             // FIX THIS
//             else
//                 begin result_rounded = 16'b0111111111111111;
//                 special_case = 1'b1; end
//         end

//         else if (sign_sum & (overflow == 1'b0))
//         begin
//             if ((guard_bit == 1'b0) & ((rounding_bit | sticky_bit2) == 1'b0))
//                 begin result_rounded = truncated;
//                 special_case = 1'b0; end

//             else if ((guard_bit == 1'b0) & (rounding_bit | sticky_bit2))
//             begin
//                 if (rn)
//                     begin result_rounded = rounded;
//                     special_case = 1'b0; end

//                 else
//                     begin result_rounded = truncated;
//                     special_case = 1'b0; end
//             end

//             else if ((least_significant_bit == 1'b0) & guard_bit & ((rounding_bit | sticky_bit2) == 1'b0))

//             // why does this work now?????
//             begin
//                 // if ((rne & sticky_bit2) | rn)
//                 if (rne | rn)
//                     begin 
//                         // if (use_rounded)
//                         //     begin result_rounded = rounded;
//                         //     special_case = 1'b0; end
//                         // else 
//                         // begin result_rounded = truncated;
//                         //     special_case = 1'b0; end
//                         result_rounded = truncated;
//                         special_case = 1'b0;
//                     end

//                 else
//                     begin result_rounded = rounded;
//                     special_case = 1'b0; end
//             end

//             else if (least_significant_bit & guard_bit & ((rounding_bit | sticky_bit2) == 1'b0))
//             begin
//                 if (rne | rn)
//                     begin 
//                         if (use_rounded)
//                             begin result_rounded = rounded;
//                             special_case = 1'b0; end
//                         else 
//                         begin result_rounded = truncated;
//                             special_case = 1'b0; end
//                             end

//                 else
//                     begin result_rounded = truncated;
//                     special_case = 1'b0; end
//             end

//             else if (guard_bit & (rounding_bit | sticky_bit2))
//             begin

//             // changes here?????

//                 if (rne  | rn)
//                     begin 
//                         if (use_rounded)
//                             begin result_rounded = rounded;
//                             special_case = 1'b0; end
//                         else 
//                         begin result_rounded = truncated;
//                             special_case = 1'b0; end
//                             end

//                 else
//                     begin result_rounded = truncated;
//                     special_case = 1'b0; end
//             end

//             else
//                 begin result_rounded = truncated;
//                 special_case = 1'b0; end
//         end

//         else if (sign_sum & overflow)
//         begin
//             if (rne | rn)
//                 begin result_rounded = 16'b1111110000000000;
//                 // result_rounded = rounded;
//                 special_case = 1'b1; end
            
//             // FIX THIS
//             else
//                 begin result_rounded = 16'b1111111111111111;
//                 special_case = 1'b1; end
//         end

//         else
//            begin  result_rounded = truncated;
//             special_case = 1'b0; end

//     end
   
// endmodule







    always_comb
    begin
        if ((sign_sum == 1'b0) & (overflow == 1'b0))
        begin
            if ((guard_bit == 1'b0) & ((rounding_bit | sticky_bit2) == 1'b0))
                begin result_rounded = truncated;
                special_case = 1'b0; end

            else if ((guard_bit == 1'b0) & (rounding_bit | sticky_bit2))
            begin
                if (rp)
                    begin result_rounded = rounded;
                    special_case = 1'b0; end 

                else
                    begin result_rounded = truncated;
                    special_case = 1'b0; end
            end

            else if ((least_significant_bit == 1'b0) & guard_bit & ((rounding_bit | sticky_bit2) == 1'b0))
            begin
                // does this actually work????
                if (rp)
                    begin result_rounded = rounded;
                    special_case = 1'b0; end

                else
                    begin result_rounded = truncated;
                    special_case = 1'b0; end
            end
            
            else if (least_significant_bit & guard_bit & ((rounding_bit | sticky_bit2) == 1'b0))
            begin
                if (rne | rp)
                    begin result_rounded = rounded;
                    special_case = 1'b0; end

                else
                    begin result_rounded = truncated;
                    special_case = 1'b0; end
            end

            // FAILING FOR TWO CASES
            else if (guard_bit & (rounding_bit | sticky_bit2))
            begin
                if (rne | rp)
                    begin result_rounded = rounded;
                    special_case = 1'b0; end

                else
                    begin result_rounded = truncated;
                    special_case = 1'b0; end
            end

            else
                begin result_rounded = truncated;
                special_case = 1'b0; end

        end

        else if ((sign_sum == 1'b0) & overflow)
        begin
            if (rne | rp)
                begin result_rounded = 16'b0111110000000000;
                // result_rounded = rounded;
                special_case = 1'b1; end

            // FIX THIS
            else
                begin result_rounded = 16'b0111111111111111;
                special_case = 1'b1; end
        end

        else if (sign_sum & (overflow == 1'b0))
        begin
            if ((guard_bit == 1'b0) & ((rounding_bit | sticky_bit2) == 1'b0))
                begin result_rounded = truncated;
                special_case = 1'b0; end

            else if ((guard_bit == 1'b0) & (rounding_bit | sticky_bit2))
            begin
                if (rn)
                    begin result_rounded = rounded;
                    special_case = 1'b0; end

                else
                    begin result_rounded = truncated;
                    special_case = 1'b0; end
            end

            else if ((least_significant_bit == 1'b0) & guard_bit & ((rounding_bit | sticky_bit2) == 1'b0))

            // why does this work now?????
            begin
                // if ((rne & sticky_bit2) | rn)
                if (rn) // rne | rn
                    begin result_rounded = rounded;
                    special_case = 1'b0; end

                else
                    begin result_rounded = truncated;
                    special_case = 1'b0; end
            end

            else if (least_significant_bit & guard_bit & ((rounding_bit | sticky_bit2) == 1'b0))
            begin
                if (rne | rn)
                    begin result_rounded = rounded;
                    special_case = 1'b0; end

                else
                    begin result_rounded = truncated;
                    special_case = 1'b0; end
            end

            else if (guard_bit & (rounding_bit | sticky_bit2))
            begin

            // changes here?????

                if ((rne & sticky_bit2)  | rn)
                    begin result_rounded = rounded;
                    special_case = 1'b0; end

                else
                    begin result_rounded = truncated;
                    special_case = 1'b0; end
            end

            else
                begin result_rounded = truncated;
                special_case = 1'b0; end
        end

        else if (sign_sum & overflow)
        begin
            if (rne | rn)
                begin result_rounded = 16'b1111110000000000;
                // result_rounded = rounded;
                special_case = 1'b1; end
            
            // FIX THIS
            else
                begin result_rounded = 16'b1111111111111111;
                special_case = 1'b1; end
        end

        else
           begin  result_rounded = truncated;
            special_case = 1'b0; end

    end
   
endmodule