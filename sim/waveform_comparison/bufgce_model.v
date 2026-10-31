`timescale 1ns / 1ps
// Zero-delay behavioral BUFGCE model for this functional comparison.
// Latch the enable while the input clock is low; no device timing model.
module BUFGCE (output O, input CE, input I);
    reg enable_q = 1'b0;
    always @(I or CE) if (!I) enable_q = CE;   // latch CE while clock is low
    assign O = I & enable_q;
endmodule
