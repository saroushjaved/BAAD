`timescale 1ns/1ps
module tb_snapshot_packet;
reg clk=0;always #5 clk=~clk;
reg rst=0,flush=0,enable=0,decision=0,ready=0;
reg [15:0] requested=1;
wire [63:0] data;wire [7:0] keep;wire valid,last;
wire [31:0] emitted,dropped;
integer words=0,packets=0,seed=73,n;
reg stalled=0;reg [63:0] held;reg heldlast;
reg [31:0] oldcycle,oldemitted,olddropped;
dma_debug_frame_packer dut(.clk(clk),.rst_n(rst),.capture_flush(flush),
 .capture_enable(enable),.capture_summary_enable(1'b1),.capture_cic_enable(1'b0),.capture_psd_input_enable(1'b0),
 .packet_record_count(requested),.cic_sample_interval(16'd1),.psd_input_sample_interval(16'd1),
 .estimate_valid(1'b0),.frame_id(32'd7),.frame_error(1'b0),.active_found(1'b1),.overflow_seen(1'b0),
 .frame_bin_count(12'd2048),.active_bin_count(12'd8),.overflow_count(12'd0),.low_bin(11'd1),.high_bin(11'd8),
 .low_signed_bin(13'sd1),.high_signed_bin(13'sd8),.bw_span_bins(12'd7),.bw_edge_bins(12'd8),
 .peak_bin(11'd4),.peak_signed_bin(13'sd4),.peak_power(33'd10000),.min_power(33'd0),.total_power(45'd20000),.active_power(45'd19000),
 .decision_valid(decision),.decision_frame_id(32'd7),.decimation_factor_m(16'd16),.candidate_factor_m(16'd16),
 .m_changed(1'b0),.decision_error(1'b0),.no_active(1'b0),.decision_edge_bins(12'd8),.stable_count(16'd2),
 .m_i(16'sd100),.m_q(-16'sd200),.m_valid(1'b0),.active_decimation_factor(16'd16),.active_gain_shift(8'd12),
 .rate_changed(1'b0),.settling(1'b0),.cfg_error(1'b0),.cic_overflow(1'b0),
 .psd_input_i(16'sd100),.psd_input_q(-16'sd200),.psd_input_valid(1'b0),
 .m_axis_tdata(data),.m_axis_tkeep(keep),.m_axis_tvalid(valid),.m_axis_tready(ready),.m_axis_tlast(last),
 .records_emitted(emitted),.records_dropped(dropped));
always @(posedge clk) if(rst && !flush) begin
 if(stalled && (!valid || data!==held || last!==heldlast)) $fatal(1,"snapshot changed while stalled");
 stalled=valid&&!ready;held=data;heldlast=last;
 if(valid&&ready) begin
  if(keep!==8'hff) $fatal(1,"snapshot keep");
  if(words%12==0 && data[63:32]!==32'hbaad0101) $fatal(1,"summary header");
  words=words+1;
  if(last) begin
   if(words%12) $fatal(1,"early snapshot TLAST");
   packets=packets+1;
  end
 end
end else stalled=0;
task run_packet(input integer count);
integer beforewords,beforepackets;
begin
 @(negedge clk);enable=0;decision=0;ready=0;flush=1;
 repeat(3) @(negedge clk);flush=0;requested=count;enable=1;
 beforewords=words;beforepackets=packets;
 for(n=0;n<1000;n=n+1) begin @(negedge clk);decision=1;ready=($random(seed)&3)!=0;end
 decision=0;
 if(words-beforewords!=12*count || packets-beforepackets!=1) $fatal(1,"packet count or extra packets");
 if(emitted!=(words/12)) $fatal(1,"record telemetry mismatch");
end endtask
initial begin
 repeat(4) @(negedge clk);rst=1;
 run_packet(1);run_packet(4);
 @(negedge clk);enable=0;ready=0;decision=0;
 @(negedge clk);enable=1;decision=1;
 wait(valid);@(negedge clk);decision=0;flush=1;
 oldcycle=dut.cycle_counter;oldemitted=emitted;olddropped=dropped;
 repeat(10) @(negedge clk);
 if(valid || emitted!=oldemitted || dropped!=olddropped || dut.cycle_counter-oldcycle!=10)
  $fatal(1,"flush must cancel output, retain telemetry and count real clocks");
 flush=0;
 run_packet(1);
 if(dropped==0) $fatal(1,"backpressure drops not reported");
 $display("PASS: bounded snapshot packets, stalls, dropped telemetry, flush and real clock counter");$finish;
end
initial begin #100000;$fatal(1,"snapshot timeout");end
endmodule
