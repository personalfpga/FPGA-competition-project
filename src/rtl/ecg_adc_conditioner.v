`timescale 1ns/1ps
// Always-on 1kHz signal adapter. Simulation/demo only, not for medical use.
// Signed math: raw - DC -> programmable Q8 gain -> +1000 -> saturate.
module ecg_adc_conditioner #(
    parameter integer WARMUP_SAMPLES = 256,
    parameter integer DC_TRACK_SHIFT = 10
)(
    input wire clk, input wire rst_n,
    input wire sample_ce, input wire raw_valid,
    input wire [11:0] raw_code,
    input wire [15:0] gain_q8,
    input wire auto_dc, input wire [11:0] fixed_dc,
    output reg [15:0] adc_ecg,
    output reg ready,
    output wire [11:0] dc_estimate,
    output reg [31:0] conditioned_count
);
    reg signed [31:0] dc_q16;
    reg [31:0] warm_sum, warm_count;
    reg auto_dc_q;
    wire signed [31:0] raw_signed = $signed({20'b0, raw_code});
    wire signed [31:0] raw_q16 = raw_signed <<< 16;
    wire signed [31:0] dc_signed = auto_dc ? ((dc_q16 + 32'sd32768) >>> 16) : $signed({20'b0,fixed_dc});
    wire signed [31:0] delta = raw_signed - dc_signed;
    wire signed [31:0] gain_signed = $signed({16'b0,gain_q8});
    wire signed [63:0] product = delta * gain_signed;
    // Round to nearest, symmetrically for positive and negative differences.
    wire signed [63:0] scaled = (product >= 0) ?
        ((product + 64'sd128) >>> 8) : -(((-product) + 64'sd128) >>> 8);
    wire signed [63:0] shifted = scaled + 64'sd1000;
    wire [31:0] accumulated_sum = warm_sum + {20'b0,raw_code};
    assign dc_estimate = dc_signed[11:0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dc_q16 <= 0; warm_sum <= 0; warm_count <= 0;
            auto_dc_q <= 1; adc_ecg <= 16'd1000;
            ready <= 0; conditioned_count <= 0;
        end else if (sample_ce) begin
            auto_dc_q <= auto_dc;
            if (auto_dc != auto_dc_q) begin
                // Reacquire the offset after an explicit mode change.
                warm_sum <= 0; warm_count <= 0; ready <= 0;
                adc_ecg <= 16'd1000;
            end else if (!raw_valid) begin
                // No synthetic fallback on ADC loss; present a neutral baseline.
                adc_ecg <= 16'd1000; ready <= 0;
                // Reacquire DC after a gap: stale offset must not be amplified.
                warm_sum <= 0; warm_count <= 0;
            end else if (auto_dc && warm_count < WARMUP_SAMPLES) begin
                warm_sum <= accumulated_sum;
                warm_count <= warm_count + 1'b1;
                adc_ecg <= 16'd1000;
                if (warm_count == WARMUP_SAMPLES-1) begin
                    dc_q16 <= $signed(accumulated_sum / WARMUP_SAMPLES) <<< 16;
                    ready <= 1;
                end
            end else begin
                if (auto_dc)
                    dc_q16 <= dc_q16 + ((raw_q16 - dc_q16) >>> DC_TRACK_SHIFT);
                ready <= 1;
                conditioned_count <= conditioned_count + 1'b1;
                if (shifted < 0) adc_ecg <= 16'd0;
                else if (shifted > 4095) adc_ecg <= 16'd4095;
                else adc_ecg <= shifted[15:0];
            end
        end
    end
endmodule
