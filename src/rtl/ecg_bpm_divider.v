`timescale 1ns / 1ps
// Exact unsigned 60000 / RR calculation, one quotient bit per clock.
// The 8-bit output keeps the original heart_rate truncation behavior.
module ecg_bpm_divider (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] rr_samples,
    output reg busy,
    output reg valid,
    output reg [7:0] bpm
);
    reg [31:0] divisor;
    reg [32:0] remainder;
    reg [15:0] dividend;
    reg [7:0] quotient;
    reg [4:0] bit_count;
    wire [32:0] trial_remainder = {remainder[31:0], dividend[15]};
    wire take_bit = trial_remainder >= {1'b0, divisor};
    wire [32:0] next_remainder = take_bit ?
        trial_remainder - {1'b0, divisor} : trial_remainder;
    wire [7:0] next_quotient = {quotient[6:0], take_bit};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            divisor <= 0;
            remainder <= 0;
            dividend <= 0;
            quotient <= 0;
            bit_count <= 0;
            busy <= 0;
            valid <= 0;
            bpm <= 0;
        end else begin
            valid <= 0;
            if (start && !busy) begin
                if (rr_samples == 0) begin
                    bpm <= 0;
                    valid <= 1;
                end else begin
                    divisor <= rr_samples;
                    remainder <= 0;
                    dividend <= 16'd60000;
                    quotient <= 0;
                    bit_count <= 0;
                    busy <= 1;
                end
            end else if (busy) begin
                remainder <= next_remainder;
                dividend <= {dividend[14:0], 1'b0};
                quotient <= next_quotient;
                if (bit_count == 15) begin
                    bpm <= next_quotient;
                    busy <= 0;
                    valid <= 1;
                end else begin
                    bit_count <= bit_count + 1'b1;
                end
            end
        end
    end
endmodule
