`timescale 1ns / 1ps
// Simulation-only stand-in for the Xilinx BUFGCE primitive (iverilog).
// Vivado already has the real one in UNISIM. Do not add this file to Vivado.
module BUFGCE (output O, input CE, input I);
    reg enable_q = 1'b0;
    always @(I or CE) if (!I) enable_q = CE;   // latch CE while clock is low
    assign O = I & enable_q;
endmodule
