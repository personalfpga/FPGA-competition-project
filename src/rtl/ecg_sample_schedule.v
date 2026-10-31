`timescale 1ns/1ps
// Mirrors the unchanged core's 1kHz divider using the same clock and reset.
// Latch/condition a sample eight clocks before the core consumes its sample.
module ecg_sample_schedule #(
    parameter integer CLK_FREQ_HZ=50_000_000
)(input wire clk, input wire rst_n, output wire prepare_sample);
    localparam integer DIV=CLK_FREQ_HZ/1000;
    reg [31:0] counter;
    assign prepare_sample = (counter == DIV-8);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) counter <= 0;
        else if (counter >= DIV-1) counter <= 0;
        else counter <= counter+1'b1;
    end
endmodule
