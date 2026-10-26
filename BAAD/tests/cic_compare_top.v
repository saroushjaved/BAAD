// Synthesis-only scope comparison using the same authored CIC. No board I/O.
module cic_compare_top #(parameter FIXED_M=0)(
 input clk,rst_n,input signed [15:0] si,sq,input sv,
 input [15:0] requested_m,input cfg_valid,
 output signed [15:0] oi,oq,output ov,
 output [15:0] active_m,output [7:0] gain,
 output changed,settling,cfg_error,overflow);
 reg initial_config;
 always @(posedge clk or negedge rst_n)
  if(!rst_n) initial_config<=1; else initial_config<=0;
 rate_controlled_cic_decimator core(.clk(clk),.rst_n(rst_n),.s_i(si),.s_q(sq),.s_valid(sv),
  .cfg_decimation_factor(FIXED_M==0 ? requested_m : FIXED_M[15:0]),
  .cfg_valid(FIXED_M==0 ? cfg_valid : initial_config),.m_i(oi),.m_q(oq),.m_valid(ov),
  .active_decimation_factor(active_m),.active_gain_shift(gain),.rate_changed(changed),
  .settling(settling),.cfg_error(cfg_error),.overflow(overflow));
endmodule
