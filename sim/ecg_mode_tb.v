`timescale 1ns / 1ps
// Multi-mode testbench: runs one test_mode for RUN_MS milliseconds (model time)
// and prints a summary line. Accelerated clock (100 kHz): 1 sample = 100 clocks.
module ecg_mode_tb;
    parameter [3:0] MODE   = 4'd0;
    parameter integer RUN_MS = 20000;
    parameter integer ST = 2500;
    reg clk = 0;
    reg rst_n = 0;
    wire led;
    ecg_top #(.CLK_FREQ_HZ(100_000), .USE_ADC(0), .TEST_MODE(MODE), .SLEEP_TIMEOUT(ST)) dut (.clk(clk), .rst_n(rst_n), .led(led));
    always #5000 clk = ~clk;
    initial begin #100000; rst_n = 1; end

    wire [1:0] state = dut.state;
    wire [7:0] hr = dut.heart_rate;
    wire abn = dut.abnormal;
    integer t_ms = 0, n_sleep = 0, n_normal = 0, n_alert = 0, trans = 0;
    integer n_rpeak = 0, hr_min = 255, hr_max = 0, first_alert = -1, first_sleep = -1;
    reg [1:0] sp = 0;
    reg rp_q = 0;
    parameter integer PRINT_PEAKS = 0;
    integer c = 0;
    always @(posedge clk) if (rst_n) begin
        c = c + 1;
        if (c == 100) begin
            c = 0; t_ms = t_ms + 1;
            case (state) 0: n_sleep = n_sleep + 1; 1: n_normal = n_normal + 1; default: n_alert = n_alert + 1; endcase
            if (hr != 0 && hr < hr_min) hr_min = hr;
            if (hr > hr_max) hr_max = hr;
            if (state == 2 && first_alert < 0) first_alert = t_ms;
            if (state == 0 && first_sleep < 0) first_sleep = t_ms;
        end
        if (state != sp) begin trans = trans + 1; if (PRINT_PEAKS) $display("STATE ms=%0d %0d -> %0d", t_ms, sp, state); sp = state; end
        if (dut.r_peak && !rp_q) n_rpeak = n_rpeak + 1; // Count heartbeat edges, not held clock cycles.
        if (dut.r_peak && !rp_q && PRINT_PEAKS) $display("RPEAK ms=%0d bpm=%0d state=%0d", t_ms, hr, state);
        rp_q = dut.r_peak;
        if (t_ms >= RUN_MS) begin
            $display("MODE=%0d ms=%0d sleep=%0d normal=%0d alert=%0d trans=%0d rpeaks=%0d hr_min=%0d hr_max=%0d first_alert=%0d first_sleep=%0d",
                     MODE, t_ms, n_sleep, n_normal, n_alert, trans, n_rpeak, hr_min, hr_max, first_alert, first_sleep);
            $finish;
        end
    end
endmodule
