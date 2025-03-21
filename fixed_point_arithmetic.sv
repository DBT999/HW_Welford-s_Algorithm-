`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/22/2024 09:31:58 AM
// Design Name: 
// Module Name: fp_math
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`include "constants.v"

package fixed_point_functions;


integer fp_out_mag;

reg [`N-1:0] max_num_mult;

/*
convert_to_real -- Used for printing out fixed point numbers in debug statements, ('real' does not synthesize)
*/
function real convert_to_real(input [`N-1:0] a);
real y;
begin
  if(a[`N-1] == 1)
  begin
      y = real'(-1*a)/(2.0**`Q);
      y = -1*y;
  end
  else
     y = real'(a)/(2.0**`Q);
  convert_to_real = y;
end 
endfunction


/*
abs -- Fixed point absolute value
*/
function [`N-1:0] abs(input [`N-1:0] a);
begin
    abs = (a[`N-1]==1) ? -a : a;
end
endfunction

/*
absmax -- Fixed point absolute value
*/
function [`N-1:0] absmax(input [`N-1:0] a, input [`N-1:0] b);
reg [`N-1:0] y;
begin
if (abs(a) > abs(b))
    y = abs(a);
else
    y = abs(b);
absmax = y;
end
endfunction

/*
clz -- Counts the number of leading zeros of the input
*/
function [5:0] clz(input [`N-1:0] a);
   integer i;
   begin
   clz = 0;
   i = 0;
   while((a[`N-1-i] == 0) && (i<(`N-1)))
    begin
      i = i + 1;
      clz = clz + 1;
    end 
   end
endfunction

/*
Function to square the input
*/
function [`N-1:0] square(input [`N-1:0] a);
begin
   square = mult(a,a);
end
endfunction

/*
Function to multiply the two inputs
*/
function [`N-1:0] mult(input [`N-1:0] a, input [`N-1:0] b);
reg [2*`N-1:0] y;
reg [`N-1:0] mag_a;
reg [`N-1:0] mag_b;
reg s_a;
reg s_b;
begin
   y = 0;
   if((a != 0) && (b != 0))
       begin

       s_a = a[`N-1];
       s_b = b[`N-1];

       mag_a = abs(a);
       mag_b = abs(b);
       
       y = mag_a * mag_b;
       if(y[2*`N-1:`Q] == 0)
       begin
           $fwrite(fp_out_mag, "In mult -- zero-after-mult - a: %b, b: %b, y: %b, discarded-y: %b\n", mag_a, mag_b, y[2*`N-1:`Q], y[`Q-1:0]);
       end
       y = y >> `Q;
       

      if((s_a ^ s_b) == 1)
      begin
         y[`N-1:0] = -y[`N-1:0];
      end
   end
   max_num_mult = absmax(max_num_mult, y[`N-1:0]);
   mult = y[`N-1:0];// >> Q;
end
endfunction


/*
ext_mult - Function to multiply the two inputs and return the result prior to shifting
*/
function [2*`N-1:0] ext_mult(input [`N-1:0] a, input [`N-1:0] b);
reg [2*`N-1:0] y;
reg [`N-1:0] mag_a;
reg [`N-1:0] mag_b;
reg s_a;
reg s_b;
begin
   y = 0;
   
   if((a != 0) && (b != 0))
   begin
       s_a = a[`N-1];
       s_b = b[`N-1];
       
       mag_a = abs(a);
       mag_b = abs(b);
       
       y = mag_a * mag_b;
       if(y[2*`N-1:`Q] == 0)
       begin
           $fwrite(fp_out_mag, "In mult -- zero-after-ext-mult - a: %b, b: %b, y: %b\n", mag_a, mag_b, y[2*`N-1:`Q]);
       end
           
    
      if((s_a ^ s_b) == 1)
      begin
         y = -y;
      end
   end
   max_num_mult = absmax(max_num_mult, y[`N-1:0]);
   ext_mult = y;
end
endfunction

/*
Function to approximate fixed point division
Implements Equation 3.14 from [1]
*/
function [`N-1:0] div (input [`N-1:0] u, input [`N-1:0] a);
    reg [`N-1:0] quotient;
    reg [`N-1:0] mag_a;
    reg [`N-1:0] mag_u;
    reg [`N-1:0] recip_s;
    reg q;
    reg [6:0] msb_fraction;
    reg [5:0] num_leading_zeros;
    reg [8:0] s;
    reg [2*`N:0] tmp2;
    reg quotient_sign;
    integer nr_idx;
    begin
       if(a == `FIXED_POINT_VALUE_ONE)
       begin
          div = u;
       end
       else
       begin

        // FP Q12.8 - one sign bit, 12 before decimal point, 8 after decimal point
        // LUT has values of 1/s with s in range of 1 to 2
        
        // 21 bit fixed point multiplication 
        
        quotient = 0;

        
        msb_fraction = 0;
        
        quotient_sign = a[`N-1] ^ u[`N-1];
        
        mag_a = abs(a);
        mag_u = abs(u);
        
//        if (a[`N-1] == 1)
//        begin
//           mag_a = -mag_a;
//        end
        
//        if(u[`N-1] == 1)
//        begin
//           mag_u = -mag_u;
//        end
        
     
        // Get the number of leading zeroes
        num_leading_zeros = clz(mag_a);
        
        // Shift according to the number of zeroes
        if(num_leading_zeros > (`N-`Q-1))
        begin
            mag_a = mag_a << (num_leading_zeros-(`N-`Q-1));
        end
        else if(num_leading_zeros == (`N-`Q-1))
        begin
          // no shift
        end
        else
        begin
            mag_a = mag_a >> ((`N-`Q-1)-num_leading_zeros);
        end
        
        
        case(`Q)
           8: msb_fraction = mag_a[`Q-1:`Q-3];
          16: msb_fraction = mag_a[`Q-1:`Q-4];
          20: msb_fraction = mag_a[`Q-1:`Q-7];
        endcase
        // Extract three MSB of the fractional parts of s for the code in the LUT
        // s = 1.b7 b6 b5 b4 b3 b2 b1 b0
        // msb_fraction = s[7:5];
        //
        // 
        //
        // Subintervals of S ranging from 1 to 2 in 1/8 increments
        //  1	1.125	1.25	1.375	1.5	1.625	1.75	1.875	2
        //
        // Geometric means of subintervals
        // s = [1.0625	1.1875	1.3125	1.4375	1.5625	1.6875	1.8125	1.9375]
        // 
        //  Range of reciprocal of s
        //  0.5 <= 1/s <= 1
        // 
        //  Fixed point version of s representing values as 01.XXXXXXXX to get LUT indicies, stored in msb_fraction
        //     0100010000	0100110000	0101010000	0101110000	0110010000	0110110000	0111010000	0111110000
        // idx   ---          ---         ---         ---         ---         ---         ---         ---
        //       000          001         010         011         100         101         110         111
        // 
        // Reciprocal of geometric means
        // 1/s = 0.941176471	0.842105263	0.761904762	0.695652174	0.64	0.592592593	0.551724138	0.516129032
        //
        // 1/s Quantized to 8 fractional points
        // 1/s = [0.9375	0.83984375	0.76171875	0.6953125	0.63671875	0.58984375	0.55078125	0.515625]
        //
        // recip_s = 1/s is shown below in LUT
        
        // LUT implementation for reciprocal of s
        recip_s = 0;
        
        if(`Q==8)
        begin
        case(msb_fraction)
            3'b000: recip_s[`Q-1:0] = 8'b11110000;
            3'b001: recip_s[`Q-1:0] = 8'b11010111;
            3'b010: recip_s[`Q-1:0] = 8'b11000011;
            3'b011: recip_s[`Q-1:0] = 8'b10110010;
            3'b100: recip_s[`Q-1:0] = 8'b10100011;
            3'b101: recip_s[`Q-1:0] = 8'b10010111;
            3'b110: recip_s[`Q-1:0] = 8'b10001101;
            3'b111: recip_s[`Q-1:0] = 8'b10000100;
        endcase
        end
        else if(`Q==16)
        begin
        case(msb_fraction)
            4'b0000: recip_s[`Q-1:0]=16'b1111100000111110;
            4'b0001: recip_s[`Q-1:0]=16'b1110101000001110;
            4'b0010: recip_s[`Q-1:0]=16'b1101110101100111;
            4'b0011: recip_s[`Q-1:0]=16'b1101001000001101;
            4'b0100: recip_s[`Q-1:0]=16'b1100011111001110;
            4'b0101: recip_s[`Q-1:0]=16'b1011111010000010;
            4'b0110: recip_s[`Q-1:0]=16'b1011011000001011;
            4'b0111: recip_s[`Q-1:0]=16'b1010111001001100;
            4'b1000: recip_s[`Q-1:0]=16'b1010011100101111;
            4'b1001: recip_s[`Q-1:0]=16'b1010000010100000;
            4'b1010: recip_s[`Q-1:0]=16'b1001101010010000;
            4'b1011: recip_s[`Q-1:0]=16'b1001010011110010;
            4'b1100: recip_s[`Q-1:0]=16'b1000111110111000;
            4'b1101: recip_s[`Q-1:0]=16'b1000101011011000;
            4'b1110: recip_s[`Q-1:0]=16'b1000011001001011;
            4'b1111: recip_s[`Q-1:0]=16'b1000001000001000;
          endcase
        end
        else if(`Q==20)
        begin
          case(msb_fraction)
          7'b0000000: recip_s[`Q-1:0]=20'b11111111000000001111;
          7'b0000001: recip_s[`Q-1:0]=20'b11111101000010001110;
          7'b0000010: recip_s[`Q-1:0]=20'b11111011000110001000;
          7'b0000011: recip_s[`Q-1:0]=20'b11111001001011111011;
          7'b0000100: recip_s[`Q-1:0]=20'b11110111010011100011;
          7'b0000101: recip_s[`Q-1:0]=20'b11110101011101000000;
          7'b0000110: recip_s[`Q-1:0]=20'b11110011101000001101;
          7'b0000111: recip_s[`Q-1:0]=20'b11110001110101001000;
          7'b0001000: recip_s[`Q-1:0]=20'b11110000000011110000;
          7'b0001001: recip_s[`Q-1:0]=20'b11101110010100000000;
          7'b0001010: recip_s[`Q-1:0]=20'b11101100100101111001;
          7'b0001011: recip_s[`Q-1:0]=20'b11101010111001010110;
          7'b0001100: recip_s[`Q-1:0]=20'b11101001001110010110;
          7'b0001101: recip_s[`Q-1:0]=20'b11100111100100110111;
          7'b0001110: recip_s[`Q-1:0]=20'b11100101111100110110;
          7'b0001111: recip_s[`Q-1:0]=20'b11100100010110010011;
          7'b0010000: recip_s[`Q-1:0]=20'b11100010110001001010;
          7'b0010001: recip_s[`Q-1:0]=20'b11100001001101011010;
          7'b0010010: recip_s[`Q-1:0]=20'b11011111101011000001;
          7'b0010011: recip_s[`Q-1:0]=20'b11011110001001111110;
          7'b0010100: recip_s[`Q-1:0]=20'b11011100101010001111;
          7'b0010101: recip_s[`Q-1:0]=20'b11011011001011110001;
          7'b0010110: recip_s[`Q-1:0]=20'b11011001101110100100;
          7'b0010111: recip_s[`Q-1:0]=20'b11011000010010100101;
          7'b0011000: recip_s[`Q-1:0]=20'b11010110110111110100;
          7'b0011001: recip_s[`Q-1:0]=20'b11010101011110001110;
          7'b0011010: recip_s[`Q-1:0]=20'b11010100000101110011;
          7'b0011011: recip_s[`Q-1:0]=20'b11010010101110100000;
          7'b0011100: recip_s[`Q-1:0]=20'b11010001011000010101;
          7'b0011101: recip_s[`Q-1:0]=20'b11010000000011010000;
          7'b0011110: recip_s[`Q-1:0]=20'b11001110101111001111;
          7'b0011111: recip_s[`Q-1:0]=20'b11001101011100010010;
          7'b0100000: recip_s[`Q-1:0]=20'b11001100001010010111;
          7'b0100001: recip_s[`Q-1:0]=20'b11001010111001011101;
          7'b0100010: recip_s[`Q-1:0]=20'b11001001101001100011;
          7'b0100011: recip_s[`Q-1:0]=20'b11001000011010100111;
          7'b0100100: recip_s[`Q-1:0]=20'b11000111001100101001;
          7'b0100101: recip_s[`Q-1:0]=20'b11000101111111100111;
          7'b0100110: recip_s[`Q-1:0]=20'b11000100110011100000;
          7'b0100111: recip_s[`Q-1:0]=20'b11000011101000010011;
          7'b0101000: recip_s[`Q-1:0]=20'b11000010011110000000;
          7'b0101001: recip_s[`Q-1:0]=20'b11000001010100100101;
          7'b0101010: recip_s[`Q-1:0]=20'b11000000001100000000;
          7'b0101011: recip_s[`Q-1:0]=20'b10111111000100010010;
          7'b0101100: recip_s[`Q-1:0]=20'b10111101111101011001;
          7'b0101101: recip_s[`Q-1:0]=20'b10111100110111010101;
          7'b0101110: recip_s[`Q-1:0]=20'b10111011110010000100;
          7'b0101111: recip_s[`Q-1:0]=20'b10111010101101100101;
          7'b0110000: recip_s[`Q-1:0]=20'b10111001101001111000;
          7'b0110001: recip_s[`Q-1:0]=20'b10111000100110111100;
          7'b0110010: recip_s[`Q-1:0]=20'b10110111100100110000;
          7'b0110011: recip_s[`Q-1:0]=20'b10110110100011010011;
          7'b0110100: recip_s[`Q-1:0]=20'b10110101100010100100;
          7'b0110101: recip_s[`Q-1:0]=20'b10110100100010100011;
          7'b0110110: recip_s[`Q-1:0]=20'b10110011100011001111;
          7'b0110111: recip_s[`Q-1:0]=20'b10110010100100100111;
          7'b0111000: recip_s[`Q-1:0]=20'b10110001100110101011;
          7'b0111001: recip_s[`Q-1:0]=20'b10110000101001011001;
          7'b0111010: recip_s[`Q-1:0]=20'b10101111101100110010;
          7'b0111011: recip_s[`Q-1:0]=20'b10101110110000110011;
          7'b0111100: recip_s[`Q-1:0]=20'b10101101110101011110;
          7'b0111101: recip_s[`Q-1:0]=20'b10101100111010110000;
          7'b0111110: recip_s[`Q-1:0]=20'b10101100000000101011;
          7'b0111111: recip_s[`Q-1:0]=20'b10101011000111001011;
          7'b1000000: recip_s[`Q-1:0]=20'b10101010001110010010;
          7'b1000001: recip_s[`Q-1:0]=20'b10101001010101111111;
          7'b1000010: recip_s[`Q-1:0]=20'b10101000011110010001;
          7'b1000011: recip_s[`Q-1:0]=20'b10100111100111000111;
          7'b1000100: recip_s[`Q-1:0]=20'b10100110110000100001;
          7'b1000101: recip_s[`Q-1:0]=20'b10100101111010011111;
          7'b1000110: recip_s[`Q-1:0]=20'b10100101000100111111;
          7'b1000111: recip_s[`Q-1:0]=20'b10100100010000000010;
          7'b1001000: recip_s[`Q-1:0]=20'b10100011011011100111;
          7'b1001001: recip_s[`Q-1:0]=20'b10100010100111101100;
          7'b1001010: recip_s[`Q-1:0]=20'b10100001110100010011;
          7'b1001011: recip_s[`Q-1:0]=20'b10100001000001011010;
          7'b1001100: recip_s[`Q-1:0]=20'b10100000001111000001;
          7'b1001101: recip_s[`Q-1:0]=20'b10011111011101000111;
          7'b1001110: recip_s[`Q-1:0]=20'b10011110101011101100;
          7'b1001111: recip_s[`Q-1:0]=20'b10011101111010110000;
          7'b1010000: recip_s[`Q-1:0]=20'b10011101001010010010;
          7'b1010001: recip_s[`Q-1:0]=20'b10011100011010010001;
          7'b1010010: recip_s[`Q-1:0]=20'b10011011101010101101;
          7'b1010011: recip_s[`Q-1:0]=20'b10011010111011100111;
          7'b1010100: recip_s[`Q-1:0]=20'b10011010001100111100;
          7'b1010101: recip_s[`Q-1:0]=20'b10011001011110101110;
          7'b1010110: recip_s[`Q-1:0]=20'b10011000110000111011;
          7'b1010111: recip_s[`Q-1:0]=20'b10011000000011100100;
          7'b1011000: recip_s[`Q-1:0]=20'b10010111010110100111;
          7'b1011001: recip_s[`Q-1:0]=20'b10010110101010000101;
          7'b1011010: recip_s[`Q-1:0]=20'b10010101111101111100;
          7'b1011011: recip_s[`Q-1:0]=20'b10010101010010001110;
          7'b1011100: recip_s[`Q-1:0]=20'b10010100100110111001;
          7'b1011101: recip_s[`Q-1:0]=20'b10010011111011111101;
          7'b1011110: recip_s[`Q-1:0]=20'b10010011010001011001;
          7'b1011111: recip_s[`Q-1:0]=20'b10010010100111001110;
          7'b1100000: recip_s[`Q-1:0]=20'b10010001111101011011;
          7'b1100001: recip_s[`Q-1:0]=20'b10010001010100000000;
          7'b1100010: recip_s[`Q-1:0]=20'b10010000101010111100;
          7'b1100011: recip_s[`Q-1:0]=20'b10010000000010010000;
          7'b1100100: recip_s[`Q-1:0]=20'b10001111011001111010;
          7'b1100101: recip_s[`Q-1:0]=20'b10001110110001111010;
          7'b1100110: recip_s[`Q-1:0]=20'b10001110001010010001;
          7'b1100111: recip_s[`Q-1:0]=20'b10001101100010111110;
          7'b1101000: recip_s[`Q-1:0]=20'b10001100111100000000;
          7'b1101001: recip_s[`Q-1:0]=20'b10001100010101011000;
          7'b1101010: recip_s[`Q-1:0]=20'b10001011101111000101;
          7'b1101011: recip_s[`Q-1:0]=20'b10001011001001000110;
          7'b1101100: recip_s[`Q-1:0]=20'b10001010100011011100;
          7'b1101101: recip_s[`Q-1:0]=20'b10001001111110000111;
          7'b1101110: recip_s[`Q-1:0]=20'b10001001011001000101;
          7'b1101111: recip_s[`Q-1:0]=20'b10001000110100011000;
          7'b1110000: recip_s[`Q-1:0]=20'b10001000001111111101;
          7'b1110001: recip_s[`Q-1:0]=20'b10000111101011110110;
          7'b1110010: recip_s[`Q-1:0]=20'b10000111001000000011;
          7'b1110011: recip_s[`Q-1:0]=20'b10000110100100100010;
          7'b1110100: recip_s[`Q-1:0]=20'b10000110000001010011;
          7'b1110101: recip_s[`Q-1:0]=20'b10000101011110010111;
          7'b1110110: recip_s[`Q-1:0]=20'b10000100111011101101;
          7'b1110111: recip_s[`Q-1:0]=20'b10000100011001010101;
          7'b1111000: recip_s[`Q-1:0]=20'b10000011110111001111;
          7'b1111001: recip_s[`Q-1:0]=20'b10000011010101011010;
          7'b1111010: recip_s[`Q-1:0]=20'b10000010110011110111;
          7'b1111011: recip_s[`Q-1:0]=20'b10000010010010100100;
          7'b1111100: recip_s[`Q-1:0]=20'b10000001110001100011;
          7'b1111101: recip_s[`Q-1:0]=20'b10000001010000110010;
          7'b1111110: recip_s[`Q-1:0]=20'b10000000110000010010;
          7'b1111111: recip_s[`Q-1:0]=20'b10000000010000000010;

          endcase
          
        end

        //
        // Newton-Raphson Reciprocal Iteration
        // x_{n+1} = x_{n} * (2 - a*x_{n})
        //  
        for(nr_idx = 0; nr_idx < `NUM_NR_ITERATIONS; nr_idx = nr_idx + 1)
        begin
            recip_s = mult((2 << `Q) - mult(recip_s, mag_a), recip_s);
        end
                
        tmp2 = mult(mag_u, recip_s);
        
        if(num_leading_zeros > (`N-`Q-1))
        begin
            quotient = tmp2 << (num_leading_zeros - (`N-`Q-1));
        end
        else if(num_leading_zeros == (`N-`Q-1))
        begin
            // no shift
            quotient = tmp2;
        end
        else
        begin
            quotient = tmp2 >> ((`N-`Q-1) - num_leading_zeros);
        end
        
        if(quotient_sign == 1)
        begin
            quotient = -1 * quotient;
        end
        

        div = quotient;

      end
    end


endfunction
    
/*
    Round to the nearest integer
*/
function [`N-1:0] round_to_nearest_integer(input [`N-1:0] a);
reg [`N-1:0] y;
begin
    y = a;
    
    // If a is negative, invert the sign
    if(a[`N-1] == 1)
    begin
       y = -y;
    end
    
    // If the MSB of the fractional components is 1, then frac(a) >= 0.5, so round up
    if(y[`Q-1] == 1)
    begin
        y[`N-1:`Q] = y[`N-1:`Q] + 1; 
    end
    
    // Zero out the fractional components
    y[`Q-1:0] = 0;
        
    // If a is negative, revert the sign back
    if(a[`N-1] == 1)
    begin
       y = -y;
    end
    
    // Set the output of the function
    round_to_nearest_integer = y;
end
endfunction

    
endpackage
