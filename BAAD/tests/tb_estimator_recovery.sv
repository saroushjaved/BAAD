`timescale 1ns/1ps
module tb_estimator_recovery;
reg clk=0; always #5 clk=~clk;
reg rst_n=0, valid=0,last=0;
reg [2:0] bin=0;
wire ev,err;
wire [3:0] count;
bandwidth_estimator #(.NFFT(8),.BIN_WIDTH(3),.SIGNED_BIN_WIDTH(5),.FRAME_IDLE_TIMEOUT_CYCLES(16)) dut(
 .clk(clk),.rst_n(rst_n),.psd_bin(bin),.psd_power(33'd100),.psd_valid(valid),.psd_last(last),
 .psd_overflow(1'b0),.cfg_power_threshold(33'd50),.estimate_valid(ev),.frame_error(err),.frame_bin_count(count));
task frame(input integer missing);
 integer i;
 begin
 for(i=0;i<8;i=i+1) begin
 @(negedge clk); valid=1;bin=i;last=(i==7 && !missing);
 @(posedge clk); #1;
 end
 if(!ev || err!==missing[0] || count!=8) $fatal(1,"FAIL frame missing=%0d err=%0d count=%0d",missing,err,count);
 @(negedge clk); valid=0;last=0;
 end
endtask
initial begin
 repeat(3) @(negedge clk); rst_n=1;
 frame(0);frame(1);frame(0);
 @(negedge clk);valid=1;bin=0;
 @(negedge clk);valid=0;
 wait(ev); #1;if(!err) $fatal(1,"FAIL partial timeout");
 frame(0);
 $display("PASS estimator missing TLAST and stalled partial frame recovery");$finish;
end
initial begin #100000; $fatal(1,"FAIL timeout");end
endmodule
