`timescale 1ns / 1ps

module and_6_to_1(
input valid1,
input valid2, 
input valid3,
input valid4, 
input valid5,
input valid6,
output valid_out 
    );
    
    assign valid_out = valid1 & valid2 & valid3 & valid4 & valid5 & valid6;
    
endmodule
