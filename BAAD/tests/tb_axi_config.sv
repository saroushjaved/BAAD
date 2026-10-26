`timescale 1ns/1ps
module tb_axi_config;
reg clk=0; always #5 clk=~clk;
reg rst=0;
reg [7:0] awaddr=0,araddr=0;
reg [31:0] wd=0;
reg [3:0] strb=0;
reg awv=0,wv=0,bready=0,arv=0,rready=0,ddsready=0;
wire awready,wready,bvalid,arready,rvalid,dvalid,flush,capreset;
wire [31:0] rd,dd,bctrl;
wire [15:0] bcount;
wire [1:0] bresp,rresp;
dds_axi_config_regs dut(
 .s_axi_aclk(clk),.s_axi_aresetn(rst),
 .s_axi_awaddr(awaddr),.s_axi_awprot(3'd0),.s_axi_awvalid(awv),.s_axi_awready(awready),
 .s_axi_wdata(wd),.s_axi_wstrb(strb),.s_axi_wvalid(wv),.s_axi_wready(wready),
 .s_axi_bresp(bresp),.s_axi_bvalid(bvalid),.s_axi_bready(bready),
 .s_axi_araddr(araddr),.s_axi_arprot(3'd0),.s_axi_arvalid(arv),.s_axi_arready(arready),
 .s_axi_rdata(rd),.s_axi_rresp(rresp),.s_axi_rvalid(rvalid),.s_axi_rready(rready),
 .dds0_s_axis_config_tdata(dd),.dds0_s_axis_config_tvalid(dvalid),.dds0_s_axis_config_tready(ddsready),
 .dds1_s_axis_config_tready(1'b1),.dds2_s_axis_config_tready(1'b1),.dds3_s_axis_config_tready(1'b1),
 .dds4_s_axis_config_tready(1'b1),.dds5_s_axis_config_tready(1'b1),
 .cfg_burst_control(bctrl),.cfg_burst_sample_count(bcount),.capture_flush(flush),.capture_resetn(capreset),
 .burst_status(32'h12340080),.burst_capture_id(32'd7),.records_emitted(32'd17),.records_dropped(32'd3));
task write_reg(input [7:0] addr,input [31:0] data,input [3:0] bytes,input integer awdelay,input integer wdelay);
begin
 fork
  begin repeat(awdelay) @(negedge clk); @(negedge clk); awaddr=addr; awv=1;
   do @(posedge clk); while(!awready); @(negedge clk); awv=0; end
  begin repeat(wdelay) @(negedge clk); @(negedge clk); wd=data; strb=bytes; wv=1;
   do @(posedge clk); while(!wready); @(negedge clk); wv=0; end
 join
 wait(bvalid); repeat(3) begin @(negedge clk); if(!bvalid || bresp) $fatal(1,"write response not held"); end
 bready=1; @(negedge clk); bready=0;
end endtask
task read_reg(input [7:0] addr,input [31:0] expected);
begin
 @(negedge clk); araddr=addr; arv=1;
 do @(posedge clk); while(!arready); @(negedge clk); arv=0;
 wait(rvalid); repeat(3) begin @(negedge clk);
  if(!rvalid || rresp || rd!==expected) $fatal(1,"read %h got %h expected %h",addr,rd,expected); end
 rready=1; @(negedge clk); rready=0;
end endtask
initial begin
 repeat(4) @(negedge clk); rst=1;
 read_reg(8'h0c,32'h26091301); read_reg(8'h4c,4096);
 write_reg(8'h48,32'h12345678,4'hf,0,4); read_reg(8'h48,32'h12345678);
 write_reg(8'h48,32'h00ab0000,4'h4,4,0); read_reg(8'h48,32'h12ab5678);
 write_reg(8'h4c,32'hffff2000,4'hf,0,0); read_reg(8'h4c,8192);
 write_reg(8'h4c,32'h00000001,4'h1,0,0); read_reg(8'h4c,8193);
 read_reg(8'h50,32'h12340080); read_reg(8'h54,17); read_reg(8'h58,3); read_reg(8'h5c,7);
 write_reg(8'h38,32'h10,4'h1,2,0); if(!flush || capreset) $fatal(1,"flush reset");
 write_reg(8'h38,0,4'h2,0,2); if(!flush) $fatal(1,"ignored byte changed flush");
 write_reg(8'h38,0,4'h1,0,0); if(flush || !capreset) $fatal(1,"flush release");
 write_reg(8'h10,123,4'hf,0,0);
 write_reg(8'h00,1,4'h0,0,0); if(dvalid) $fatal(1,"zero strobe applied DDS");
 write_reg(8'h00,1,4'h1,0,0); if(!dvalid || dd!==123) $fatal(1,"DDS apply");
 write_reg(8'h10,456,4'hf,0,0); if(!dvalid || dd!==123) $fatal(1,"stalled DDS data changed");
 write_reg(8'h00,1,4'h1,0,0); if(dd!==123) $fatal(1,"repeat apply replaced stalled data");
 @(negedge clk); ddsready=1; @(negedge clk); ddsready=0;
 if(dvalid) $fatal(1,"DDS config did not complete");
 write_reg(8'h00,1,4'h1,0,0); if(!dvalid || dd!==456) $fatal(1,"next DDS apply");
 $display("PASS: AXI independent AW/W, byte strobes, response stalls, telemetry, DDS stable payload"); $finish;
end
initial begin #100000; $fatal(1,"AXI test timeout"); end
endmodule
