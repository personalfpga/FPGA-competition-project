`timescale 1ns/1ps
// A common synthetic input verifies the new controlled-ablation switches.
module power_variants_tb;
    reg clk=0, rst_n=0, feed=0;
    always #5 clk=~clk;
    integer cycles=0;
    wire [15:0] sample=(feed && ((cycles/100)%800)<15) ? 16'd4095 : 16'd1000;
    always @(posedge clk) if(rst_n) cycles<=cycles+1;
    wire [7:0] hb,hf,hg;
    wire pb,pf,pg;
    ecg_core #(.CLK_FREQ_HZ(100000),.ENABLE_ADAPTIVE(0),.USE_CLK_GATE(0)) b
      (.clk(clk),.rst_n(rst_n),.test_mode(4'd7),.use_adc(1'b1),.adc_ecg(sample),.heart_rate(hb),.proc_en(pb));
    ecg_core #(.CLK_FREQ_HZ(100000),.ENABLE_ADAPTIVE(1),.USE_CLK_GATE(0)) f
      (.clk(clk),.rst_n(rst_n),.test_mode(4'd7),.use_adc(1'b1),.adc_ecg(sample),.heart_rate(hf),.proc_en(pf));
    ecg_core #(.CLK_FREQ_HZ(100000),.ENABLE_ADAPTIVE(1),.USE_CLK_GATE(1)) g
      (.clk(clk),.rst_n(rst_n),.test_mode(4'd7),.use_adc(1'b1),.adc_ecg(sample),.heart_rate(hg),.proc_en(pg));
    integer eb=0,ef=0,eg=0,prior;
    always @(posedge b.clk_g) if(rst_n) eb=eb+1;
    always @(posedge f.clk_g) if(rst_n) ef=ef+1;
    always @(posedge g.clk_g) if(rst_n) eg=eg+1;
    initial begin
        repeat(10) @(negedge clk);rst_n=1;
        repeat(310000) @(negedge clk);
        if(pb!==1 || pf!==0 || pg!==0) $fatal(1,"baseline must process while adaptive variants sleep");
        if(eb!=ef || eg>20) $fatal(1,"ungated and gated clock behavior incorrect");
        feed=1;
        repeat(500000) @(negedge clk);
        if(hb!=75 || hf!=75 || hg!=75 || pf!==1 || pg!==1) $fatal(1,"common 75BPM input mismatch");
        feed=0;
        repeat(400000) @(negedge clk);
        if(pb!==1 || pf!==0 || pg!==0) $fatal(1,"adaptive variants did not sleep after loss");
        prior=eg;repeat(1000) @(negedge clk);
        if(eg!=prior || eb!=ef || eg>=ef) $fatal(1,"gated clock did not stop");
        $display("POWER_VARIANTS_PASS baseline_always_process=PASS FSM_sleep=PASS gate_stop=PASS common_75bpm=PASS");
        $finish;
    end
endmodule
