`timescale 1ns / 1ps

module and_2_to_1(
input valid1,
input valid2, 
output valid_out 
    );
    
    assign valid_out = valid1 & valid2;
    
endmodule
