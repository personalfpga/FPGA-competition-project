`timescale 1ns/1ps
// Independent debug top. No ADC path or extra board pins are used.
module ecg_activity_top #(parameter integer CLK_FREQ_HZ=50000000)(
  input wire clk,input wire rst_n,output wire led
);
  wire [3:0] mode;
  wire snap_toggle,clear_toggle,reset_hold;
  (* ASYNC_REG="TRUE" *) reg [1:0] reset_pipe=0;
  always @(posedge clk or negedge rst_n)
    if(!rst_n)reset_pipe<=0;else reset_pipe<={reset_pipe[0],1'b1};
  wire core_reset_n=reset_pipe[1] && !reset_hold;
  wire ce,cg,abnormal;
  wire [1:0] state;
  wire [7:0] bpm;
  ecg_core_observed #(.CLK_FREQ_HZ(CLK_FREQ_HZ)) core(
    .clk(clk),.rst_n(core_reset_n),.test_mode(mode),.use_adc(1'b0),.adc_ecg(16'd1000),
    .led(led),.state(state),.heart_rate(bpm),.abnormal(abnormal),
    .observe_clk_en(ce),.observe_clk_g(cg));
  wire [31:0] snapshot_total,snapshot_gated,snapshot_seq;
  wire [1:0] snapshot_state;
  wire [7:0] snapshot_bpm;
  wire snapshot_abnormal,snapshot_overflow;
  ecg_activity_counter counter(
    .clk(clk),.rst_n(core_reset_n),.clk_en(ce),
    .state_in(state),.bpm_in(bpm),.abnormal_in(abnormal),
    .snapshot_toggle(snap_toggle),.clear_toggle(clear_toggle),
    .snapshot_total(snapshot_total),.snapshot_gated(snapshot_gated),
    .snapshot_state(snapshot_state),.snapshot_bpm(snapshot_bpm),
    .snapshot_abnormal(snapshot_abnormal),.snapshot_seq(snapshot_seq),
    .snapshot_overflow(snapshot_overflow));
  ecg_activity_vio vio(.clk(clk),
    .probe_in0(snapshot_total),.probe_in1(snapshot_gated),.probe_in2(snapshot_state),
    .probe_in3(snapshot_bpm),.probe_in4(snapshot_abnormal),.probe_in5(snapshot_seq),
    .probe_in6(snapshot_overflow),.probe_out0(mode),.probe_out1(snap_toggle),
    .probe_out2(clear_toggle),.probe_out3(reset_hold));
endmodule
