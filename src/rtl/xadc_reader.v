`timescale 1ns/1ps
// Read-only DRP bridge. The only accepted source is dedicated VP/VN (03h).
module xadc_reader (
    input wire clk, input wire rst_n,
    input wire eoc, input wire [4:0] channel,
    input wire drdy, input wire [15:0] drp_data,
    output reg den, output wire [6:0] daddr,
    output reg pending,
    output reg [15:0] adc_word, output reg [11:0] adc_code,
    output reg sample_valid, output reg adc_seen,
    output reg [31:0] sample_count
);
    assign daddr = 7'h03;
    always @(posedge clk) begin
        if (!rst_n) begin
            den <= 0; pending <= 0; adc_word <= 0; adc_code <= 0;
            sample_valid <= 0; adc_seen <= 0; sample_count <= 0;
        end else begin
            den <= 0;
            sample_valid <= 0;
            if (pending) begin
                if (drdy) begin
                    adc_word <= drp_data;
                    adc_code <= drp_data[15:4];
                    sample_valid <= 1;
                    adc_seen <= 1;
                    sample_count <= sample_count + 1'b1;
                    pending <= 0;
                end
            end else if (eoc && channel == 5'h03 && !drdy) begin
                den <= 1;
                pending <= 1;
            end
        end
    end
endmodule
