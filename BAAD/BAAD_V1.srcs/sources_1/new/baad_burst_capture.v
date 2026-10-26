`timescale 1ns/1ps
// Bounded capture in the DSP clock domain, followed by a stalled-safe BRAM
// drain. The DSP source is never backpressured. UART speed cannot lose samples.
module baad_burst_capture #(
 parameter MAX_SAMPLES=8192, parameter SAMPLE_RATE_HZ=62000000
)(
 input wire clk, input wire rst_n,
 input wire [31:0] control, input wire [15:0] sample_count,
 input wire signed [15:0] psd_i,psd_q,cic_i,cic_q,
 input wire psd_valid,cic_valid,settling,rate_changed,cfg_error,cic_overflow,
 input wire decision_valid,decision_error,
 input wire [15:0] active_m, input wire [7:0] gain_shift,
 input wire [31:0] frame_id,
 output wire [31:0] status, output reg [31:0] capture_id=0,
 input wire [63:0] s_axis_tdata,input wire [7:0] s_axis_tkeep,
 input wire s_axis_tvalid,s_axis_tlast,output wire s_axis_tready,
 output wire [63:0] m_axis_tdata,output wire [7:0] m_axis_tkeep,
 output wire m_axis_tvalid,m_axis_tlast,input wire m_axis_tready
);
 localparam IDLE=0,WAIT_STABLE=1,CAPTURE=2,HEADER=3,READ=4,SEND=5,TRAILER=6,CRC=7,DONE=8;
 reg [3:0] state=IDLE;
 (* ram_style="block" *) reg [63:0] samples[0:MAX_SAMPLES-1];
 reg [63:0] read_data;
 reg [63:0] cycle=0,start_cycle,end_cycle;
 reg [15:0] count,requested,flags,cap_m;
 reg [7:0] cap_shift;
 reg source;
 reg [31:0] cap_frame;
 reg [1:0] stable_frames;
 reg [15:0] observed_m;
 reg [31:0] wait_cycles;
 reg [12:0] read_index;
 reg [3:0] header_index;
 reg [31:0] crc;
 reg [63:0] word;
 wire owned=(state!=IDLE) || control[0];
 wire source_valid=source ? cic_valid : psd_valid;
 wire [31:0] iq=source ? {cic_q,cic_i} : {psd_q,psd_i};
 wire [31:0] cycle_offset=(count==0) ? 32'd0 : cycle-start_cycle;
 localparam [31:0] RATE_HZ=SAMPLE_RATE_HZ;
 wire output_valid=(state==HEADER || state==SEND || state==TRAILER || state==CRC);
 assign status={flags,8'd0,state,4'd0};
 assign s_axis_tready=!owned && m_axis_tready;
 assign m_axis_tvalid=owned ? output_valid : s_axis_tvalid;
 assign m_axis_tdata=owned ? word : s_axis_tdata;
 assign m_axis_tkeep=owned ? 8'hff : s_axis_tkeep;
 assign m_axis_tlast=owned ? (state==CRC) : s_axis_tlast;
 function [31:0] crc_word;
 input [31:0] old; input [63:0] data;
 reg [31:0] c; integer b;
 begin c=old; for(b=0;b<64;b=b+1) c=(c[0]^data[b]) ? (c>>1)^32'hedb88320 : c>>1; crc_word=c; end
 endfunction
 always @* begin
 word=0;
 case(state)
 HEADER: case(header_index)
  0:word={16'hbaad,8'h02,8'h04,(requested+16'd10),flags};
  1:word={capture_id,16'd0,requested};
  2:word=start_cycle;
  3:word=end_cycle;
  4:word={RATE_HZ,cap_m,cap_shift,7'd0,source};
  5:word={cap_frame,32'd0};
  6:word=64'h0000000100000008; // layout version 1; sample stride 8
  7:word=0;
 endcase
 SEND:word=read_data;
 TRAILER:word={32'h454e4421,count,flags};
 CRC:word={32'h43524332,~crc};
 endcase
 end
 // Synchronous BRAM read (kept separate from the asynchronously reset FSM).
 always @(posedge clk) if(state==READ) read_data<=samples[read_index];
 always @(posedge clk) if(state==CAPTURE && source_valid)
   samples[count[12:0]]<={cycle_offset,iq};
 always @(posedge clk or negedge rst_n) begin
 if(!rst_n) begin
 state<=IDLE;cycle<=0;capture_id<=0;count<=0;requested<=0;flags<=0;
 stable_frames<=0;observed_m<=0;wait_cycles<=0;start_cycle<=0;end_cycle<=0;
 cap_m<=1;cap_shift<=0;source<=0;cap_frame<=0;read_index<=0;header_index<=0;crc<=32'hffffffff;
 end else begin
 cycle<=cycle+1'b1;
 if(control[1]) begin state<=IDLE;flags<=16'h0008;stable_frames<=0;end
 else case(state)
 IDLE: if(control[0]) begin
 capture_id<=capture_id+1'b1;requested<=sample_count;source<=control[8];count<=0;flags<=0;
 stable_frames<=0;observed_m<=active_m;wait_cycles<=0;
 if(sample_count<256 || sample_count>MAX_SAMPLES) begin flags<=16'h0010;state<=DONE;end
 else state<=WAIT_STABLE;
 end
 WAIT_STABLE: begin
 wait_cycles<=wait_cycles+1'b1;
 if(settling || rate_changed || active_m!=observed_m || decision_error) begin
 stable_frames<=0;observed_m<=active_m;
 end else if(decision_valid && stable_frames<2) stable_frames<=stable_frames+1'b1;
 if(stable_frames==2 && !settling && !rate_changed && !decision_error && source_valid) begin
 cap_m<=active_m;cap_shift<=gain_shift;cap_frame<=frame_id;
 start_cycle<=cycle+1'b1;state<=CAPTURE;wait_cycles<=0;
 end
 if(wait_cycles>=SAMPLE_RATE_HZ/20) begin flags<=16'h0020;state<=DONE;end
 end
 CAPTURE: begin
 wait_cycles<=wait_cycles+1'b1;
 flags<=flags | ((rate_changed || active_m!=cap_m || settling) ? 16'h0001 : 16'd0)
              | ((cfg_error || cic_overflow || decision_error) ? 16'h0002 : 16'd0);
 if(source_valid) begin
 count<=count+1'b1;
 if(count==0) start_cycle<=cycle;
 if(count==requested-1'b1) begin
 end_cycle<=cycle;header_index<=0;crc<=32'hffffffff;state<=HEADER;
 end
 end
 if(wait_cycles>=SAMPLE_RATE_HZ/20) begin flags<=flags|16'h0020;state<=DONE;end
 end
 HEADER:if(m_axis_tready) begin
 crc<=crc_word(crc,word);
 if(header_index==7) begin read_index<=0;state<=READ;end
 else header_index<=header_index+1'b1;
 end
 READ:state<=SEND;
 SEND:if(m_axis_tready) begin
 crc<=crc_word(crc,word);
 if(read_index==requested-1'b1) state<=TRAILER;
 else begin read_index<=read_index+1'b1;state<=READ;end
 end
 TRAILER:if(m_axis_tready) begin crc<=crc_word(crc,word);state<=CRC;end
 CRC:if(m_axis_tready) state<=DONE;
 DONE:if(!control[0]) state<=IDLE;
 default:state<=IDLE;
 endcase
 end
 end
endmodule
