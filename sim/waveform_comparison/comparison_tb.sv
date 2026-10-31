`timescale 1ns/1ps
module comparison_tb;
reg clk=0, rst_n=0;
always #5000 clk=~clk;
wire [1:0] bs,gs;wire [7:0] bh,gh;wire br,gr;
ecg_core #(.CLK_FREQ_HZ(100000),.ENABLE_ADAPTIVE(0),.USE_CLK_GATE(0)) baseline
(.clk(clk),.rst_n(rst_n),.test_mode(4'd7),.use_adc(1'b0),.adc_ecg(16'd0),.state(bs),.heart_rate(bh),.r_peak(br));
ecg_core #(.CLK_FREQ_HZ(100000),.ENABLE_ADAPTIVE(1),.USE_CLK_GATE(1)) gated
(.clk(clk),.rst_n(rst_n),.test_mode(4'd7),.use_adc(1'b0),.adc_ecg(16'd0),.state(gs),.heart_rate(gh),.r_peak(gr));
integer f,main_edges=0,b_edges=0,g_edges=0,wakes=0,snap_main=0,snap_gate=0,cycle_main=0,cycle_gate=0;
reg [1:0] previous=0;integer errors=0;integer stopped_edges=0;integer quiet_clocks=0;
always @(posedge clk) if(rst_n) begin
main_edges=main_edges+1;
if(gs==0) quiet_clocks=quiet_clocks+1;else quiet_clocks=0;
end
always @(posedge baseline.clk_g) if(rst_n) b_edges=b_edges+1;
always @(posedge gated.clk_g) if(rst_n) begin
g_edges=g_edges+1;if(quiet_clocks>6) stopped_edges=stopped_edges+1;
end
always @(negedge clk) if(rst_n) begin
if(baseline.ecg_data!==gated.ecg_data) errors=errors+1;
if(gs!=previous) begin
$display("STATE time_ns=%0t from=%0d to=%0d",$time,previous,gs);
if(previous==0 && gs==1) begin
wakes=wakes+1;
if(wakes==2) begin snap_main=main_edges;snap_gate=g_edges;end
if(wakes==3) begin cycle_main=main_edges-snap_main;cycle_gate=g_edges-snap_gate;
$display("CYCLE main_edges=%0d gated_edges=%0d reduction=%.9f",cycle_main,cycle_gate,1.0-cycle_gate*1.0/cycle_main);end
end
previous=gs;
end
if(gated.sample_en) $fdisplay(f,"%0t,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",$time,bs,baseline.clk_en,bh,br,gs,gated.clk_en,gh,gr,gated.ecg_data);
end
initial begin
f=$fopen("samples.csv","w");$fdisplay(f,"time_ps,baseline_state,baseline_clk_en,baseline_bpm,baseline_r_peak,gated_state,gated_clk_en,gated_bpm,gated_r_peak,input_ecg");
$dumpfile("comparison.vcd");$dumpvars(0,clk,rst_n,bs,gs,bh,gh,br,gr,baseline.clk_en,gated.clk_en,baseline.clk_g,gated.clk_g);$dumpoff;
#55000 rst_n=1;
#(64'd18_702_800_000);$dumpon;
#(64'd400_000);$dumpoff;
#(64'd4_293_400_000);$dumpon;
#(64'd800_000);$dumpoff;
#(64'd24_100_000_000);
$fclose(f);
$display("TOTAL main=%0d baseline=%0d gated=%0d sleep_edges=%0d input_errors=%0d",main_edges,b_edges,g_edges,stopped_edges,errors);
if(errors || stopped_edges || b_edges!=main_edges || cycle_main!=2280000 || cycle_gate!=1850604) $fatal(1,"COMPARISON_FAILED");
$display("COMPARISON_PASS");$finish;
end
endmodule
