`timescale 1ns/1ps
module activity_counter_tb;
  reg clk=0, rst_n=0, gate=0, snap=0, clear=0;
  reg [1:0] state=0;
  reg [7:0] bpm=0;
  reg abnormal=0;
  always #10 clk=~clk;
  wire [31:0] total,gated,st,sg,seq;
  wire [1:0] ss,cs;
  wire [7:0] sb,cb;
  wire sa,ca,ov;
  ecg_activity_counter dut(.clk(clk),.rst_n(rst_n),.clk_en(gate),
    .state_in(state),.bpm_in(bpm),.abnormal_in(abnormal),
    .snapshot_toggle(snap),.clear_toggle(clear),
    .total_cycles(total),.gated_cycles(gated),.snapshot_total(st),
    .snapshot_gated(sg),.snapshot_state(ss),.snapshot_bpm(sb),
    .snapshot_abnormal(sa),.snapshot_seq(seq),.snapshot_overflow(ov),
    .state(cs),.bpm(cb),.abnormal(ca));
  integer i;
  reg [31:0] held_t,held_g,held_s;
  task ticks(input integer n); begin repeat(n) @(negedge clk); #1; end endtask
  task request; begin snap=~snap; ticks(1); end endtask
  initial begin
    ticks(3);rst_n=1; ticks(100);
    if(total!=100 || gated!=0) $fatal(1,"sleep count mismatch");
    request(); if(st!=101 || sg!=0 || ss!=0) $fatal(1,"snapshot edge mismatch");
    held_t=st;held_g=sg;held_s=seq;
    gate=1;state=1;bpm=75;ticks(100);
    if(st!=held_t || sg!=held_g || seq!=held_s) $fatal(1,"snapshot must remain held");
    request(); if(ss!=1 || sb!=75 || sa!=0 || st-sg<100) $fatal(1,"normal metadata mismatch");
    state=2;bpm=120;abnormal=1;ticks(100);request();
    if(ss!=2 || sb!=120 || !sa || gated<199) $fatal(1,"alert count mismatch");
    // Both requests on one edge: include that edge in the snapshot, then clear.
    held_t=total;held_g=gated;snap=~snap;clear=~clear;ticks(1);
    if(st!=held_t+1 || sg!=held_g+1 || total!=0 || gated!=0) $fatal(1,"atomic snapshot clear mismatch");
    ticks(17);request(); if(st!=18 || sg!=18) $fatal(1,"clear interval lost cycles");
    // Explicit overflow flag prevents a wrapped interval being shown as valid.
    @(negedge clk); dut.total_cycles=32'hffffffff;dut.gated_cycles=32'hffffffff;
    ticks(1);request();if(!ov) $fatal(1,"missing wrap flag");
    clear=~clear;ticks(1);request();if(ov) $fatal(1,"clear did not reset wrap flag");
    if(cs!=state || cb!=bpm || ca!=abnormal) $fatal(1,"live metadata mismatch");
    $display("ACTIVITY_COUNTER_PASS sleep normal alert held_snapshot atomic_clear wrap metadata");
    $finish;
  end
endmodule
