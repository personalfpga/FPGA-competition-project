`timescale 1ns/1ps
module conditioner_tb;
 reg clk=0,rst_n=0,ce=0,raw_valid=1,auto_dc=0;
 reg [11:0] raw_code=1475,fixed_dc=1475;
 reg [15:0] gain_q8=7680;
 wire [15:0] adc_ecg;
 wire ready;wire[11:0]dc_estimate;wire[31:0]count;
 integer vectors=0;
 ecg_adc_conditioner #(.WARMUP_SAMPLES(8)) dut(clk,rst_n,ce,raw_valid,raw_code,gain_q8,auto_dc,fixed_dc,adc_ecg,ready,dc_estimate,count);
 always #5 clk=~clk;
 task sample(input integer value);
  @(negedge clk);raw_code=value;ce=1;
  @(posedge clk);#1;
  @(negedge clk);ce=0;
 endtask
 task check(input bit ok,input string why);if(!ok)$fatal(1,"CONDITIONER_FAIL %s",why);endtask
 function integer reference_value(input integer code,input integer gain);
  longint signed p,v;
  begin
   p=(code-1475)*gain;
   v=(p>=0)?((p+128)>>>8):-(((-p)+128)>>>8);
   v=v+1000;
   reference_value=(v<0)?0:(v>4095)?4095:v;
  end
 endfunction
 initial begin
  repeat(3)@(posedge clk);
  @(negedge clk);rst_n=1;
  sample(1475);sample(1475);
  check(adc_ecg==1000&&ready,"manual baseline");
  for(integer g=0;g<5;g=g+1)begin
   case(g)0:gain_q8=0;1:gain_q8=256;2:gain_q8=7680;3:gain_q8=8064;4:gain_q8=65535;endcase
   for(integer c=0;c<4096;c=c+1)begin
    sample(c);check(adc_ecg==reference_value(c,gain_q8),"signed gain saturation exhaustive");
    vectors=vectors+1;
   end
  end
  gain_q8=7680;
  sample(1575);check(adc_ecg==4000,"R peak 100 counts *30 +1000");
  sample(0);check(adc_ecg==0,"negative clamp");
  sample(4095);check(adc_ecg==4095,"positive clamp");
  raw_valid=0;sample(1475);check(adc_ecg==1000&&!ready,"invalid ADC neutral baseline");
  raw_valid=1;auto_dc=1;
  sample(1475);
  for(integer k=0;k<8;k=k+1)begin
   sample(1475);check(adc_ecg==1000,"warmup inhibits offset amplification");
  end
  check(ready&&dc_estimate==1475,"auto DC warmup average");
  sample(1575);check(adc_ecg==4000,"auto DC scaled pulse");
  repeat(20000)sample(1600);
  check(dc_estimate==1600&&adc_ecg==1000,"DC tracker converges and baseline is 1000");
  raw_valid=0;sample(1600);
  check(!ready&&adc_ecg==1000,"loss after tracking inhibits output");
  raw_valid=1;
  repeat(8)begin sample(1800);check(adc_ecg==1000,"reacquire offset after gap");end
  check(ready&&dc_estimate==1800,"reacquired offset");
  sample(1905);check(adc_ecg==4095,"R is above 4000 after recovery");
  $display("CONDITIONER_PASS exhaustive_vectors=%0d gain_cases=5 signed=PASS saturation=PASS warmup=PASS stale=PASS dc_track=PASS",vectors);
  $finish;
 end
 initial begin #10000000;$fatal(1,"timeout");end
endmodule
