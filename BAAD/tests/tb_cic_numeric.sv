`timescale 1ns/1ps
// Independent FIR-convolution oracle, not a copy of the RTL integrator/comb.
module tb_cic_numeric;
reg clk=0; always #5 clk=~clk;
reg rst=0,sv=0,cv=0;
reg signed [15:0] si=0,sq=0;
reg [15:0] cfg=1;
wire signed [15:0] oi,oq;
wire ov,changed,settling,overflow,bad_boundary;
wire [15:0] active;
wire [7:0] shift;
integer hi[0:47],hq[0:47],coef[0:47];
integer checks=0,seed=32'h1234abcd,valid_since=0,last_rate=1,k,a,b,c;
longint signed sum_i,sum_q,expect_i,expect_q;
rate_controlled_cic_decimator dut(.clk(clk),.rst_n(rst),.s_i(si),.s_q(sq),.s_valid(sv),
 .cfg_decimation_factor(cfg),.cfg_valid(cv),.m_i(oi),.m_q(oq),.m_valid(ov),
 .active_decimation_factor(active),.active_gain_shift(shift),.rate_changed(changed),
 .settling(settling),.overflow(overflow),.switch_boundary_error(bad_boundary));
always @(posedge clk) begin
 #1;
 if(!rst || changed) begin
  for(k=0;k<48;k=k+1) begin hi[k]=0;hq[k]=0;coef[k]=0;end
  last_rate=active; valid_since=0;
  for(a=0;a<active;a=a+1) for(b=0;b<active;b=b+1) for(c=0;c<active;c=c+1)
   coef[a+b+c]=coef[a+b+c]+1;
 end else if(sv) begin
  for(k=47;k>0;k=k-1) begin hi[k]=hi[k-1];hq[k]=hq[k-1];end
  hi[0]=$signed(si);hq[0]=$signed(sq);valid_since=valid_since+1;
  if(ov) begin
   sum_i=0;sum_q=0;
   for(k=0;k<48;k=k+1) begin sum_i=sum_i+longint'(hi[k])*coef[k];sum_q=sum_q+longint'(hq[k])*coef[k];end
   expect_i=(sum_i+(shift ? (64'sd1<<(shift-1)) : 0))>>>shift;
   expect_q=(sum_q+(shift ? (64'sd1<<(shift-1)) : 0))>>>shift;
   if($signed(oi)!==expect_i || $signed(oq)!==expect_q)
    $fatal(1,"CIC convolution M%0d I %0d/%0d Q %0d/%0d",active,$signed(oi),expect_i,$signed(oq),expect_q);
   if(overflow || bad_boundary) $fatal(1,"unexpected CIC saturation/boundary error");
   checks=checks+1;
  end
 end else if(ov) $fatal(1,"output with no input sample");
end
task run_rate(input integer rate_value,input integer mode);
integer n;
begin
 @(negedge clk);cfg=rate_value;cv=1;sv=1;
 @(negedge clk);cv=0;
 for(n=0;n<6000;n=n+1) begin
  @(negedge clk);sv=($random(seed)&7)!=0;
  case(mode)
   0:begin si=32767;sq=-32768;end
   1:begin si=(n==100 ? 32767 : 0);sq=(n==200 ? -32768 : 0);end
   default:begin si=$random(seed);sq=$random(seed);end
  endcase
 end
end endtask
integer m,mode;
initial begin
 repeat(4) @(negedge clk);rst=1;
 for(mode=0;mode<3;mode=mode+1) begin
  for(m=1;m<=16;m=m*2) run_rate(m,mode);
  for(m=8;m>=1;m=m/2) run_rate(m,mode);
 end
 @(negedge clk);sv=0;
 if(checks<10000) $fatal(1,"insufficient comparisons");
 $display("PASS: %0d independent CIC convolution checks, full-scale DC, impulses, random IQ, valid gaps and up/down switches",checks);
 $finish;
end
initial begin #3000000;$fatal(1,"numeric timeout");end
endmodule
