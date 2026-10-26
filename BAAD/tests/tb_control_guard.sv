`timescale 1ns/1ps
module tb_control_guard;
reg clk=0; always #5 clk=~clk;
reg rst_n=0, valid=0, active=1, error=0;
reg [11:0] edge_bins=0;
wire [15:0] m, candidate;
wire dv, de, fallback;
decimation_decision_control #(.ESTIMATE_TIMEOUT_CYCLES(40)) dut(
 .clk(clk),.rst_n(rst_n),.estimate_valid(valid),.frame_id(32'd7),
 .active_found(active),.frame_error(error),.overflow_seen(1'b0),
 .bw_edge_bins(edge_bins),.bw_span_bins(12'd0),.decimation_factor_m(m),
 .candidate_factor_m(candidate),.decision_valid(dv),.decision_error(de),.safety_fallback(fallback));
task drive_frame(input integer edge_value,input integer wanted);
 begin
 @(negedge clk); edge_bins=edge_value; valid=1;
 @(posedge clk); #1;
 if(m!==wanted || !dv) $fatal(1,"FAIL guard edge=%0d expected=%0d actual=%0d",edge_value,wanted,m);
 @(negedge clk); valid=0;
 end
endtask
initial begin
 repeat(3) @(negedge clk); rst_n=1;
 drive_frame(40,1); drive_frame(40,16);
 drive_frame(51,16); drive_frame(52,8); // no outward hysteresis beyond strict guard
 drive_frame(42,8); drive_frame(42,8); // ten-bin inward margin required
 drive_frame(41,8); drive_frame(41,16);
 drive_frame(103,4); drive_frame(205,2); drive_frame(410,1);
 drive_frame(180,1); drive_frame(180,4);
 repeat(40) @(posedge clk); #1;
 if(m!==1 || !de) $fatal(1,"FAIL missing estimate fallback");
 drive_frame(40,1); drive_frame(40,16);
 active=0; drive_frame(40,1);
 active=1; drive_frame(40,1); drive_frame(40,16);
 error=1; drive_frame(40,1);
 $display("PASS strict guard, asymmetric hysteresis, qualification, timeout, fallback"); $finish;
end
initial begin #100000; $fatal(1,"FAIL test timeout"); end
endmodule
