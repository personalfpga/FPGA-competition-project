`timescale 1ns/1ps
// Protocol stimulus ONLY. Never add this model to synthesis sources.
module xadc_vpvn(input wire dclk_in,reset_in,input wire[6:0]daddr_in,
 input wire den_in,dwe_in,input wire[15:0]di_in,output reg[15:0]do_out,
 output reg drdy_out,input wire vp_in,vn_in,output wire[4:0]channel_out,
 output reg eoc_out,output wire eos_out,output wire busy_out);
 reg[11:0]injected_code=1475;
 reg[3:0]cycle=0;reg[1:0]latency=0;
 assign channel_out=5'h03;assign eos_out=eoc_out;assign busy_out=1'b0;
 always@(posedge dclk_in)begin
  if(reset_in)begin cycle<=0;latency<=0;eoc_out<=0;drdy_out<=0;do_out<=0;end
  else begin
   eoc_out<=0;drdy_out<=0;
   if(cycle==9)begin cycle<=0;eoc_out<=1;end else cycle<=cycle+1'b1;
   if(den_in)begin
    if(daddr_in!=3||dwe_in)$fatal(1,"DRP must read VP/VN only");
    latency<=2;
   end
   else if(latency!=0)begin
    latency<=latency-1'b1;
    if(latency==1)begin do_out<={injected_code,4'b0};drdy_out<=1;end
   end
  end
 end
endmodule
