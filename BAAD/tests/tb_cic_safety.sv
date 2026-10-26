`timescale 1ns/1ps
module tb_cic_safety;
reg clk=0;always #5 clk=~clk;
reg rst_n=0,cv=0;reg [15:0] cfg=1;
wire [15:0] m;wire ce,mv;wire signed [15:0] i,q;
rate_controlled_cic_decimator dut(.clk(clk),.rst_n(rst_n),.s_i(16'sd1000),.s_q(-16'sd500),.s_valid(1'b1),
 .cfg_decimation_factor(cfg),.cfg_valid(cv),.active_decimation_factor(m),.cfg_error(ce),.m_valid(mv),.m_i(i),.m_q(q));
task command(input integer rate);
 begin @(negedge clk);cfg=rate;cv=1;@(negedge clk);cv=0;end
endtask
initial begin
 repeat(3) @(negedge clk);rst_n=1;
 command(16);repeat(150) @(negedge clk);
 if(m!=16) $fatal(1,"FAIL M16");
 command(3);repeat(33) @(negedge clk);
 if(m!=1) $fatal(1,"FAIL invalid must fallback: m=%0d pending=%0d update=%0d count=%0d",m,dut.pending_decimation_factor,dut.pending_update,dut.decim_count);
 command(8);repeat(100) @(negedge clk);
 command(0);repeat(17) @(negedge clk);if(m!=1) $fatal(1,"FAIL zero fallback");
 $display("PASS CIC invalid command safe boundary fallback");$finish;
end
initial begin #100000;$fatal(1,"FAIL watchdog");end
endmodule
