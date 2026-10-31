`timescale 1ns/1ps
// All snapshots are held in the always-on domain until the next toggle request.
// The falling-edge observation matches the stable CE sampled by BUFGCE.
module ecg_activity_counter(
    input wire clk, input wire rst_n, input wire clk_en,
    input wire [1:0] state_in, input wire [7:0] bpm_in,
    input wire abnormal_in, input wire snapshot_toggle, input wire clear_toggle,
    output reg [31:0] total_cycles, output reg [31:0] gated_cycles,
    output reg [31:0] snapshot_total, output reg [31:0] snapshot_gated,
    output reg [1:0] snapshot_state, output reg [7:0] snapshot_bpm,
    output reg snapshot_abnormal, output reg [31:0] snapshot_seq,
    output reg snapshot_overflow,
    output wire [1:0] state, output wire [7:0] bpm, output wire abnormal
);
    reg gate_active;
    reg snapshot_seen, clear_seen, overflow;
    wire snap_event = snapshot_toggle != snapshot_seen;
    wire clear_event = clear_toggle != clear_seen;
    wire wrap_now = (&total_cycles) || (gate_active && (&gated_cycles));
    assign state=state_in;
    assign bpm=bpm_in;
    assign abnormal=abnormal_in;
    always @(negedge clk or negedge rst_n)
        if(!rst_n) gate_active<=0;
        else gate_active<=clk_en;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            total_cycles<=0;gated_cycles<=0;
            snapshot_total<=0;snapshot_gated<=0;snapshot_state<=0;
            snapshot_bpm<=0;snapshot_abnormal<=0;snapshot_seq<=0;
            snapshot_seen<=0;clear_seen<=0;overflow<=0;snapshot_overflow<=0;
        end else begin
            snapshot_seen<=snapshot_toggle;
            clear_seen<=clear_toggle;
            total_cycles<=total_cycles+1'b1;
            gated_cycles<=gated_cycles+gate_active;
            overflow<=overflow || wrap_now;
            if(snap_event)begin
                snapshot_total<=total_cycles+1'b1;
                snapshot_gated<=gated_cycles+gate_active;
                snapshot_state<=state_in;snapshot_bpm<=bpm_in;
                snapshot_abnormal<=abnormal_in;
                snapshot_seq<=snapshot_seq+1'b1;
                snapshot_overflow<=overflow || wrap_now;
            end
            if(clear_event)begin
                total_cycles<=0;gated_cycles<=0;overflow<=0;
            end
        end
    end
endmodule
