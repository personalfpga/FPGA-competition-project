`timescale 1ns/1ps
module ecg_activity_vio(input clk,input [31:0] probe_in0,probe_in1,
 input [1:0] probe_in2,input [7:0] probe_in3,input probe_in4,
 input [31:0] probe_in5,input probe_in6,
 output reg [3:0] probe_out0=7,output reg probe_out1=0,probe_out2=0,probe_out3=0);
endmodule
module activity_top_tb;
 reg clk=0,rst_n=0;always #5000 clk=~clk;wire led;
 ecg_activity_top #(.CLK_FREQ_HZ(100000)) dut(.clk(clk),.rst_n(rst_n),.led(led));
 initial begin
   repeat(10)@(negedge clk);rst_n=1;
   repeat(100000)@(negedge clk);
   dut.vio.probe_out1=1;
   repeat(4)@(negedge clk);
   if(dut.snapshot_seq!=1 || dut.snapshot_total<99990 || dut.snapshot_gated==0)$fatal(1,"vio snapshot path mismatch");
   dut.vio.probe_out3=1;repeat(10)@(negedge clk);
   if(dut.snapshot_seq!=0)$fatal(1,"debug reset path mismatch");
   dut.vio.probe_out0=9;dut.vio.probe_out1=0;dut.vio.probe_out3=0;
   repeat(300000)@(negedge clk);
   dut.vio.probe_out1=1;repeat(4)@(negedge clk);
   if(dut.snapshot_state!=1 || dut.snapshot_bpm<60 || dut.snapshot_bpm>100 || led)$fatal(1,"mit mode9 wrapper mismatch");
   $display("ACTIVITY_TOP_PASS vio_snapshot debug_reset mit_mode9 normal_bpm led");$finish;
 end
endmodule
