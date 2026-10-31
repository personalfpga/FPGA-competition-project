`timescale 1ns/1ps
module activity_integration_tb;
  parameter integer MODE=7;
  parameter integer RUN_MS=47000;
  reg clk=0,rst_n=0,snap=0,clear=0;
  always #5000 clk=~clk;
  wire ce,cg,led,ab,rp;
  wire [1:0] state;
  wire [7:0] bpm;
  ecg_core_observed #(.CLK_FREQ_HZ(100000)) core(
    .clk(clk),.rst_n(rst_n),.test_mode(MODE[3:0]),.use_adc(1'b0),.adc_ecg(16'd1000),
    .state(state),.heart_rate(bpm),.abnormal(ab),.r_peak(rp),.led(led),
    .observe_clk_en(ce),.observe_clk_g(cg));
  wire [31:0] total,gated,st,sg,seq;
  wire [1:0] ss;
  wire [7:0] sb;
  wire sa,ov;
  ecg_activity_counter monitor(.clk(clk),.rst_n(rst_n),.clk_en(ce),
    .state_in(state),.bpm_in(bpm),.abnormal_in(ab),.snapshot_toggle(snap),.clear_toggle(clear),
    .total_cycles(total),.gated_cycles(gated),.snapshot_total(st),.snapshot_gated(sg),
    .snapshot_state(ss),.snapshot_bpm(sb),.snapshot_abnormal(sa),.snapshot_seq(seq),.snapshot_overflow(ov));
  integer main_edges=0,gate_edges=0,ns=0,nn=0,na=0;
  integer cs=0,cn=0,ca=0,gs=0,gn=0,ga=0;
  integer wake_n=0,base_t=0,base_g=0,ct=0,cgated=0,cycle_saved=0;
  integer fd,k,j,last_t=0,last_g=0;
  reg [1:0] prev=0;
  reg old_ce;
  reg [1023:0] csv_path;
  always @(posedge clk) if(rst_n) begin
    main_edges=main_edges+1;
    case(state)
      0:begin cs=cs+1;if(monitor.gate_active)gs=gs+1;end
      1:begin cn=cn+1;if(monitor.gate_active)gn=gn+1;end
      2:begin ca=ca+1;if(monitor.gate_active)ga=ga+1;end
    endcase
    if(prev==0 && state==1)begin
      wake_n=wake_n+1;
      if(wake_n==2)begin base_t=main_edges;base_g=gate_edges;end
      if(wake_n==3)begin ct=main_edges-base_t;cgated=gate_edges-base_g;cycle_saved=1000000.0*(ct-cgated)/ct;end
    end
    prev=state;
  end
  always @(posedge cg) if(rst_n)gate_edges=gate_edges+1;
  initial begin
    if(!$value$plusargs("csv=%s",csv_path))csv_path="activity.csv";
    fd=$fopen(csv_path,"w");
    $fdisplay(fd,"time_s,total_cycles,gated_cycles,state,bpm,abnormal,ecg,seq,source,clock_hz,overflow");
    repeat(10)@(negedge clk);rst_n=1;
    // One snapshot every 20 ms; scale hardware cycle counts to 50 MHz for display.
    for(k=0;k<RUN_MS/20;k=k+1)begin
      repeat(2000)@(negedge clk);snap=~snap;
      @(negedge clk);#1;
      if(st!=total || sg!=gated || ov) $fatal(1,"snapshot consistency failure");
      if(gated!=gate_edges || total!=main_edges) $fatal(1,"counter disagrees with actual clock edges");
      $fdisplay(fd,"%0.6f,%0d,%0d,%0d,%0d,%0d,%0d,%0d,offline_simulation,50000000,0",
        st/100000.0,(st-last_t)*500,(sg-last_g)*500,ss,sb,sa,core.ecg_data,seq);
      last_t=st;last_g=sg;
    end
    if(MODE==7)begin
      if(ct==0 || cycle_saved<185000 || cycle_saved>192000)$fatal(1,"mode7 cycle clock saving mismatch %0d",cycle_saved);
      if(gs>100 || cn-gn>100 || ca-ga>100)$fatal(1,"per-state clock activity mismatch");
      $display("ACTIVITY_INTEGRATION_PASS mode=7 sleep_edges=%0d/%0d normal_edges=%0d/%0d alert_edges=%0d/%0d cycle_total=%0d cycle_gated=%0d saved_ppm=%0d",gs,cs,gn,cn,ga,ca,ct,cgated,cycle_saved);
    end else $display("ACTIVITY_INTEGRATION_PASS mode=%0d actual_clock_edges_match=1 total=%0d gated=%0d",MODE,total,gated);
    $fclose(fd);$finish;
  end
endmodule
