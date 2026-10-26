`timescale 1ns/1ps
module tb_burst_capture;
reg clk=0;always #5 clk=~clk;
reg rst_n=0;
reg [31:0] control=0;
reg [15:0] requested=256;
reg [15:0] value=0;
reg ready=0,changed=0;
wire [63:0] data;
wire valid,last;
wire [31:0] status,id;
integer words=0,first_sample,expected_count=256,run_count=0;
reg [31:0] crc=32'hffffffff;
reg [63:0] previous;
reg stalled=0;
baad_burst_capture dut(.clk(clk),.rst_n(rst_n),.control(control),.sample_count(requested),
 .psd_i(value),.psd_q(~value),.cic_i(value),.cic_q(~value),
 .psd_valid(1'b1),.cic_valid(1'b1),.settling(1'b0),.rate_changed(changed),
 .cfg_error(1'b0),.cic_overflow(1'b0),.decision_valid(1'b1),.decision_error(1'b0),
 .active_m(16'd4),.gain_shift(8'd6),.frame_id(32'd42),.status(status),.capture_id(id),
 .s_axis_tdata(64'd0),.s_axis_tkeep(8'hff),.s_axis_tvalid(1'b0),.s_axis_tlast(1'b0),
 .m_axis_tdata(data),.m_axis_tkeep(),.m_axis_tvalid(valid),.m_axis_tlast(last),.m_axis_tready(ready));
function automatic [31:0] crc64(input [31:0] c0,input [63:0] d);
 reg [31:0] c;integer i;
 begin c=c0;for(i=0;i<64;i=i+1) c=(c[0]^d[i]) ? (c>>1)^32'hedb88320 : c>>1;crc64=c;end
endfunction
always @(negedge clk) begin value<=value+1;ready<=($urandom_range(0,3)!=0);end
always @(posedge clk) if(rst_n) begin
 if(stalled && (!valid || data!==previous)) $fatal(1,"FAIL unstable AXIS under backpressure");
 previous=data;stalled=valid && !ready;
 if(valid && ready) begin
 if(words==0 && (data[63:32]!==32'hbaad0204 || data[31:16]!=expected_count+10)) $fatal(1,"FAIL header");
 if(words==8) first_sample=data[15:0];
 if(words>=8 && words<expected_count+8) begin
 if(data[15:0]!==16'(first_sample+words-8) || data[31:16]!==~data[15:0] || data[63:32]!=words-8)
 $fatal(1,"FAIL noncontiguous sample index=%0d data=%h",words-8,data);
 end
 if(words==expected_count+9) begin
 if(!last || data!={32'h43524332,~crc}) $fatal(1,"FAIL CRC/TLAST");
 end else begin
 if(last) $fatal(1,"FAIL early TLAST");
 crc=crc64(crc,data);
 end
 words=words+1;
 end
end
task run(input integer n,input integer source);
 begin
 @(negedge clk);words=0;crc=32'hffffffff;requested=n;expected_count=n;control=1|(source<<8);
 wait(status[7:4]==8); @(negedge clk);
 if(words!=n+10 || status[31:16]!=0) $fatal(1,"FAIL completion");
 control=0; repeat(3) @(negedge clk);
 end
endtask
initial begin
 repeat(3) @(negedge clk);rst_n=1;
 run(256,0);run(8192,1);
 control=1;wait(status[7:4]==2);changed=1;@(negedge clk);changed=0;
 // Abort mid acquisition, then demonstrate a clean subsequent capture.
 control=2;repeat(3) @(negedge clk);control=0;repeat(3) @(negedge clk);
 run(256,0);
 $display("PASS bounded burst counts, sample continuity, backpressure, CRC, abort/restart");$finish;
end
initial begin #2000000;$fatal(1,"FAIL watchdog");end
endmodule
