`timescale 1ns / 1ps
// Testbench for the adaptive (SLEEP / NORMAL / ALERT) version.
// The clock is accelerated: CLK_FREQ_HZ = 100 kHz, so one sample = 100 clocks
// and model time equals simulated time.
//
// Expected state sequence (time windows in ms):
//   #0 NORMAL  ~  200   first R wave wakes the chain
//   #1 ALERT   ~ 7100  first 500 ms RR gives 120 BPM
//   #2 NORMAL  ~12900  75 BPM again plus 1500 ms hold
//   #3 SLEEP   ~17400  flat signal, no R peak for 1200 ms
//   #4 NORMAL  ~23000  next beat wakes the chain
//   #5 ALERT   ~29900
//   #6 NORMAL  ~35700
//   #7 SLEEP   ~40200
module ecg_tb;
    reg clk = 0;
    reg rst_n = 0;
    wire led;
    ecg_top #(.CLK_FREQ_HZ(100_000), .USE_ADC(0)) dut (
        .clk(clk), .rst_n(rst_n), .led(led)
    );
    wire       r_peak     = dut.r_peak;
    wire [7:0] heart_rate = dut.heart_rate;
    wire       abnormal   = dut.abnormal;
    wire       low_power  = dut.low_power;
    wire [1:0] state      = dut.state;
    wire       proc_en    = dut.proc_en;

    integer errors = 0;
    integer saw_75 = 0;
    integer saw_120 = 0;
    integer sample_count = 0;
    integer cycles_since_sample = 0;
    integer n_sleep = 0;
    integer n_normal = 0;
    integer n_alert = 0;
    integer sleep_run = 0;
    integer trans_idx = 0;
    integer t_ms;
    integer main_edges = 0;
    integer gated_edges = 0;
    integer gated_in_sleep = 0;
    reg [1:0] state_prev = 2'd0;

    integer exp_lo [0:8];
    integer exp_hi [0:8];
    reg [1:0] exp_state [0:8];

    initial begin
        exp_state[0] = 2'd1; exp_lo[0] =   100; exp_hi[0] =   400;
        exp_state[1] = 2'd2; exp_lo[1] =  6900; exp_hi[1] =  7400;
        exp_state[2] = 2'd1; exp_lo[2] = 12400; exp_hi[2] = 13400;
        exp_state[3] = 2'd0; exp_lo[3] = 18500; exp_hi[3] = 19000;
        exp_state[4] = 2'd1; exp_lo[4] = 22800; exp_hi[4] = 23300;
        exp_state[5] = 2'd2; exp_lo[5] = 29700; exp_hi[5] = 30200;
        exp_state[6] = 2'd1; exp_lo[6] = 35300; exp_hi[6] = 36100;
        exp_state[7] = 2'd0; exp_lo[7] = 41300; exp_hi[7] = 41900;
        exp_state[8] = 2'd1; exp_lo[8] = 45500; exp_hi[8] = 46100;
    end

    always #5000 clk = ~clk;

    // Steady-state cycle measurement: edges between two consecutive SLEEP -> NORMAL wake-ups
    integer wake_n = 0, snap_main = 0, snap_gated = 0, cyc_main = 0, cyc_gated = 0;
    reg [1:0] st_q = 2'd0;
    always @(posedge clk) begin
        st_q <= state;
        if (st_q == 2'd0 && state == 2'd1) begin
            wake_n = wake_n + 1;
            if (wake_n == 2) begin snap_main = main_edges; snap_gated = gated_edges; end
            if (wake_n == 3) begin
                cyc_main = main_edges - snap_main; cyc_gated = gated_edges - snap_gated;
                $display("CYCLE_GATING: main_edges=%0d gated_edges=%0d saved_per_mille=%0d",
                         cyc_main, cyc_gated, (cyc_main - cyc_gated) * 1000 / cyc_main);
            end
        end
    end

    // Edge counters: main clock vs gated clock of the processing chain.
    // After the flush window (sleep_run > 6) clk_g must not toggle at all.
    always @(posedge clk) if (dut.reset_pipe[1]) main_edges = main_edges + 1;
    always @(posedge dut.core.clk_g) begin
        if (dut.reset_pipe[1]) begin
            gated_edges = gated_edges + 1;
            if (sleep_run > 6) gated_in_sleep = gated_in_sleep + 1;
        end
    end

    initial begin
        #55000 rst_n = 1;
        #(64'd47_000_000_000);
        $display("STATS: sleep_samples=%0d normal_samples=%0d alert_samples=%0d",
                 n_sleep, n_normal, n_alert);
        $display("CLOCK_GATING: main_edges=%0d gated_edges=%0d gated_edges_in_sleep=%0d saved_per_mille=%0d",
                 main_edges, gated_edges, gated_in_sleep,
                 (main_edges - gated_edges) * 1000 / main_edges);
        if (gated_in_sleep != 0) begin
            $display("ECG_TEST_FAIL: clk_g toggled %0d times during SLEEP", gated_in_sleep);
            errors = errors + 1;
        end
        if (gated_edges >= main_edges) begin
            $display("ECG_TEST_FAIL: no clock edges saved");
            errors = errors + 1;
        end
        if (errors != 0 || trans_idx != 9 || !saw_75 || !saw_120 || sample_count < 46900) begin
            $display("ECG_TEST_FAIL: errors=%0d transitions=%0d saw_75=%0d saw_120=%0d samples=%0d",
                     errors, trans_idx, saw_75, saw_120, sample_count);
        end else begin
            $display("ECG_TEST_PASS: transitions=%0d saw_75=%0d saw_120=%0d samples=%0d",
                     trans_idx, saw_75, saw_120, sample_count);
        end
        $finish;
    end

    always @(negedge clk) begin
        if (!dut.reset_pipe[1]) begin
            cycles_since_sample = 0;
        end else begin
            t_ms = $time / 1000000;
            cycles_since_sample = cycles_since_sample + 1;

            // sample interval must be exactly 100 clocks
            if (dut.core.sample_en) begin
                if (sample_count > 0 && cycles_since_sample != 100) begin
                    $display("ECG_TEST_FAIL: sample interval=%0d", cycles_since_sample);
                    $finish;
                end
                cycles_since_sample = 0;
                sample_count = sample_count + 1;
                if (state == 2'd0) n_sleep  = n_sleep  + 1;
                if (state == 2'd1) n_normal = n_normal + 1;
                if (state == 2'd2) n_alert  = n_alert  + 1;
            end

            // state transitions against the expected list
            if (state !== state_prev) begin
                $display("STATE: time_ms=%0d %0d -> %0d", t_ms, state_prev, state);
                if (trans_idx < 9) begin
                    if (state !== exp_state[trans_idx] ||
                        t_ms < exp_lo[trans_idx] || t_ms > exp_hi[trans_idx]) begin
                        $display("ECG_TEST_FAIL: unexpected transition #%0d (expected state %0d between %0d and %0d ms)",
                                 trans_idx, exp_state[trans_idx], exp_lo[trans_idx], exp_hi[trans_idx]);
                        errors = errors + 1;
                    end
                end else begin
                    $display("ECG_TEST_FAIL: extra transition #%0d", trans_idx);
                    errors = errors + 1;
                end
                trans_idx = trans_idx + 1;
                state_prev = state;
            end

            // output consistency
            if (led !== (state == 2'd2)) begin
                $display("ECG_TEST_FAIL: led differs from ALERT state");
                errors = errors + 1;
            end
            if (low_power !== (state == 2'd0)) begin
                $display("ECG_TEST_FAIL: low_power differs from SLEEP state");
                errors = errors + 1;
            end
            if (proc_en !== (state != 2'd0)) begin
                $display("ECG_TEST_FAIL: proc_en differs from state");
                errors = errors + 1;
            end

            // while sleeping, the processing chain must be quiet
            if (state == 2'd0) sleep_run = sleep_run + 1; else sleep_run = 0;
            if (sleep_run > 5) begin
                if (dut.core.x0 !== 0 || dut.core.x1 !== 0 || dut.core.x2 !== 0 ||
                    dut.core.x3 !== 0 || dut.core.filtered_ecg !== 0 || r_peak !== 0) begin
                    $display("ECG_TEST_FAIL: processing chain not quiet in SLEEP at %0d ms", t_ms);
                    errors = errors + 1;
                end
            end

            // heart rate seen
            if (heart_rate == 75) saw_75 = 1;
            if (heart_rate == 120 && abnormal) saw_120 = 1;
        end
    end

    always @(heart_rate) if (rst_n) $display("HEART_RATE: time=%0t BPM=%0d", $time, heart_rate);
endmodule
