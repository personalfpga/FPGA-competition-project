`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////
// ecg_core.v - adaptive low-power version with clock gating
//
// Two clock domains, both derived from the same input clock:
//   clk   : always on.  Sample tick, simulated ECG source, wake monitor,
//           power state machine, clock-enable logic, rate check.
//   clk_g : gated by a BUFGCE.  Processing chain only: moving-average filter,
//           R-peak detector, RR measurement, BPM divider.
//           In SLEEP the BUFGCE stops clk_g, so those flip-flops see no
//           clock edge at all.
//
// Power states (decided once per sample, 1 kHz):
//   SLEEP  : only the wake monitor runs. clk_g is stopped.
//   NORMAL : full processing chain runs.
//   ALERT  : heart rate out of range (abnormal = 1), chain keeps running.
//
// Transitions:
//   SLEEP  -> NORMAL : raw sample > WAKE_THR            (fast wake-up)
//   NORMAL -> ALERT  : abnormal = 1
//   NORMAL -> SLEEP  : no R peak for SLEEP_TIMEOUT samples (slow, hysteresis)
//   ALERT  -> NORMAL : abnormal = 0 for ALERT_HOLD samples
//
// Clock-gate sequencing:
//   * Wake-up: state becomes NORMAL, clk_en rises one clock later. The first
//     sample is processed about one sample period later, so clk_g is running
//     long before it is needed.
//   * Going to sleep: the chain is cleared (flush) for FLUSH_CYCLES clocks
//     while clk_g still runs, then clk_en falls and clk_g stops.
//
// USE_CLK_GATE = 0 connects clk_g directly to clk (no gating). This gives the
// "state machine only" version for a fair A/B comparison.
//
// The built-in simulated ECG has three phases:
//   8 beats at 75 BPM, 8 beats at 120 BPM, 8 beats at 75 BPM,
//   then IDLE_SAMPLES samples of flat signal (no heartbeat).
//
// Demo only, not a medical diagnosis.
//////////////////////////////////////////////////////////////////////////////
module ecg_core #(
    parameter integer CLK_FREQ_HZ   = 50_000_000,
    parameter integer WAKE_THR      = 2000,  // raw amplitude that wakes the chain
    parameter integer SLEEP_TIMEOUT = 2500,  // samples without R peak -> SLEEP (must exceed the slowest RR, 45 BPM = 1333)
    parameter integer ALERT_HOLD    = 1500,  // normal samples before leaving ALERT
    parameter integer IDLE_SAMPLES  = 6000,  // length of the flat phase in the simulated ECG
    parameter integer ENABLE_ADAPTIVE = 1,    // 0 = controlled always-processing baseline
    parameter integer USE_CLK_GATE  = 1      // 1 = BUFGCE gating, 0 = no gating
)(
    input  wire clk,
    input  wire rst_n,

    // signal source selection
    input  wire [3:0]  test_mode,   // 0..6 test signal library, 7 = demo sequence, 8.. = real ECG replay (ecg_rom)
    input  wire        use_adc,     // 1 = use adc_ecg (real acquisition path)
    input  wire [15:0] adc_ecg,     // conditioned ADC sample, same scale as the test signals

    output reg  r_peak,
    output reg  [7:0] heart_rate,
    output reg  abnormal,
    output wire low_power,
    output reg  [1:0] state,
    output wire proc_en,
    output wire led
);

localparam [1:0] S_SLEEP  = 2'd0;
localparam [1:0] S_NORMAL = 2'd1;
localparam [1:0] S_ALERT  = 2'd2;

localparam [2:0] FLUSH_CYCLES = 3'd4;

//==========================================================
// 1. Sample enable (1 kHz)                       [clk, always on]
//==========================================================
localparam integer SAMPLE_RATE = 1000;
localparam integer SAMPLE_DIV  = CLK_FREQ_HZ / SAMPLE_RATE;

reg [31:0] sample_cnt;
reg        sample_en;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sample_cnt <= 0;
        sample_en  <= 0;
    end else begin
        if (sample_cnt >= SAMPLE_DIV - 1) begin
            sample_cnt <= 0;
            sample_en  <= 1;
        end else begin
            sample_cnt <= sample_cnt + 1;
            sample_en  <= 0;
        end
    end
end

//==========================================================
// 2. Simulated ECG source                        [clk, always on]
//    stim_mode: 0 = 75 BPM, 1 = 120 BPM, 2 = flat (no heartbeat)
//==========================================================
localparam integer NORMAL_PERIOD   = 800;  // 800 ms  -> 75 BPM
localparam integer ABNORMAL_PERIOD = 500;  // 500 ms  -> 120 BPM

reg [31:0] beat_counter;
reg [4:0]  beat_number;
reg [1:0]  stim_mode;
reg [31:0] idle_cnt;
reg [15:0] legacy_ecg;   // built-in demo sequence (test_mode 7)

wire [31:0] cur_period = (stim_mode == 2'd1) ? ABNORMAL_PERIOD : NORMAL_PERIOD;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        beat_counter <= 0;
        beat_number  <= 0;
        stim_mode    <= 2'd0;
        idle_cnt     <= 0;
        legacy_ecg    <= 0;
    end else if (sample_en) begin
        if (stim_mode == 2'd2) begin
            // flat phase
            legacy_ecg <= 16'd1000;
            if (idle_cnt >= IDLE_SAMPLES - 1) begin
                idle_cnt     <= 0;
                stim_mode    <= 2'd0;
                beat_counter <= 0;
                beat_number  <= 0;
            end else begin
                idle_cnt <= idle_cnt + 1;
            end
        end else begin
            // beat timing
            if (beat_counter >= cur_period - 1) begin
                beat_counter <= 0;
                beat_number  <= beat_number + 1'b1;
                if (beat_number == 5'd7)
                    stim_mode <= 2'd1;
                else if (beat_number == 5'd15)
                    stim_mode <= 2'd0;
                else if (beat_number == 5'd23) begin
                    stim_mode <= 2'd2;
                    idle_cnt  <= 0;
                end
            end else begin
                beat_counter <= beat_counter + 1'b1;
            end

            // waveform: baseline, P, Q, R, S, T
            if (beat_counter < 50)
                legacy_ecg <= 16'd1000;
            else if (beat_counter < 100)
                legacy_ecg <= 16'd1200;   // P wave
            else if (beat_counter < 180)
                legacy_ecg <= 16'd1000;
            else if (beat_counter < 195)
                legacy_ecg <= 16'd700;    // Q wave
            else if (beat_counter < 210)
                legacy_ecg <= 16'd4000;   // R wave
            else if (beat_counter < 225)
                legacy_ecg <= 16'd600;    // S wave
            else if (beat_counter < 300)
                legacy_ecg <= 16'd1000;
            else if (beat_counter < 380)
                legacy_ecg <= 16'd1500;   // T wave
            else
                legacy_ecg <= 16'd1000;
        end
    end
end

//----------------------------------------------------------
// Signal source select: real ADC, test signal library, or demo sequence
//----------------------------------------------------------
wire [15:0] pat_ecg;
ecg_pattern_gen pat_gen (
    .clk(clk), .rst_n(rst_n), .sample_en(sample_en),
    .mode(test_mode[2:0]), .ecg(pat_ecg)
);

// Real ECG replay (test_mode 8, 9 ...): one 30 s record per slot, looped.
localparam integer ROM_REC_LEN = 30000;               // must match gen_rom.py
wire        rom_sel = (test_mode >= 4'd8);
reg  [14:0] rom_idx;
reg  [3:0]  rom_mode_q;
reg  [16:0] rom_base;
wire [11:0] rom_dout;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rom_idx    <= 0;
        rom_mode_q <= 0;
        rom_base   <= 0;
    end else begin
        rom_mode_q <= test_mode;
        rom_base   <= (test_mode == 4'd9) ? ROM_REC_LEN : 0;
        if (test_mode != rom_mode_q)
            rom_idx <= 0;
        else if (sample_en)
            rom_idx <= (rom_idx == ROM_REC_LEN - 1) ? 15'd0 : rom_idx + 1'b1;
    end
end
ecg_rom rom_i (.clk(clk), .addr(rom_base + rom_idx), .dout(rom_dout));

wire [15:0] ecg_data = use_adc ? adc_ecg :
                       (test_mode == 4'd7) ? legacy_ecg :
                       rom_sel ? {4'b0000, rom_dout} : pat_ecg;

//==========================================================
// 3. Power state machine and clock enable        [clk, always on]
//    flush is held for FLUSH_CYCLES clocks after entering SLEEP. It clears
//    the processing chain so the next wake-up starts from a clean state.
//    clk_en keeps clk_g running until the flush is finished.
//==========================================================
reg [15:0] quiet_cnt;   // samples since last R peak (NORMAL)
reg [15:0] hold_cnt;    // normal samples counted in ALERT
reg [2:0]  flush_cnt;
reg        clk_en = 1'b1;

wire flush = (ENABLE_ADAPTIVE != 0) && (flush_cnt != 3'd0);

assign proc_en   = (ENABLE_ADAPTIVE == 0) || (state != S_SLEEP);
assign low_power = (ENABLE_ADAPTIVE != 0) && (state == S_SLEEP);
assign led       = (ENABLE_ADAPTIVE != 0) ? (state == S_ALERT) : abnormal;

generate if (ENABLE_ADAPTIVE != 0) begin : g_adaptive
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state     <= S_SLEEP;
        quiet_cnt <= 0;
        hold_cnt  <= 0;
        flush_cnt <= 3'd0;
    end else begin
        if (flush_cnt != 3'd0)
            flush_cnt <= flush_cnt - 1'b1;
        if (sample_en) begin
            case (state)
                S_SLEEP: begin
                    quiet_cnt <= 0;
                    hold_cnt  <= 0;
                    if (ecg_data > WAKE_THR)
                        state <= S_NORMAL;
                end
                S_NORMAL: begin
                    hold_cnt <= 0;
                    if (abnormal)
                        state <= S_ALERT;
                    else if (r_peak)
                        quiet_cnt <= 0;
                    else if (quiet_cnt >= SLEEP_TIMEOUT - 1) begin
                        state     <= S_SLEEP;
                        quiet_cnt <= 0;
                        flush_cnt <= FLUSH_CYCLES;
                    end else
                        quiet_cnt <= quiet_cnt + 1'b1;
                end
                S_ALERT: begin
                    quiet_cnt <= 0;
                    if (abnormal)
                        hold_cnt <= 0;
                    else if (hold_cnt >= ALERT_HOLD - 1) begin
                        state    <= S_NORMAL;
                        hold_cnt <= 0;
                    end else
                        hold_cnt <= hold_cnt + 1'b1;
                end
                default: state <= S_SLEEP;
            endcase
        end
    end
end

// Clock enable for the gated domain. Registered, so the BUFGCE sees a clean
// signal launched from clk. Reset value 1 keeps clk_g alive during reset.
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        clk_en <= 1'b1;
    else
        clk_en <= (state != S_SLEEP) || (flush_cnt != 3'd0);
end

end else begin : g_baseline
    // Same signal generator/filter/detector/divider, processing never sleeps.
    // Unused sleep counters and controller are removed during synthesis.
    always @* begin
        state = abnormal ? S_ALERT : S_NORMAL;
        quiet_cnt = 0;
        hold_cnt = 0;
        flush_cnt = 0;
        clk_en = 1'b1;
    end
end endgenerate

//==========================================================
// 4. Gated clock for the processing chain
//==========================================================
wire clk_g;

generate
    if (USE_CLK_GATE != 0) begin : g_gate
        BUFGCE bufg_proc (.O(clk_g), .CE(clk_en), .I(clk));
    end else begin : g_nogate
        assign clk_g = clk;
    end
endgenerate

//==========================================================
// 5. Filter: 4-point moving average              [clk_g, gated]
//==========================================================
reg [15:0] x0, x1, x2, x3;
reg [17:0] filter_sum;
reg [15:0] filtered_ecg;

always @(posedge clk_g or negedge rst_n) begin
    if (!rst_n) begin
        x0 <= 0; x1 <= 0; x2 <= 0; x3 <= 0;
        filter_sum   <= 0;
        filtered_ecg <= 0;
    end else if (flush) begin
        x0 <= 0; x1 <= 0; x2 <= 0; x3 <= 0;
        filter_sum   <= 0;
        filtered_ecg <= 0;
    end else if (sample_en && proc_en) begin
        x3 <= x2;
        x2 <= x1;
        x1 <= x0;
        x0 <= ecg_data;
        filter_sum   <= x0 + x1 + x2 + x3;
        filtered_ecg <= filter_sum >> 2;
    end
end

//==========================================================
// 6. R peak detection: threshold plus refractory [clk_g, gated]
//==========================================================
localparam integer R_THRESHOLD = 2500;
localparam integer REFRACTORY  = 250;

reg [15:0] refractory_cnt;

always @(posedge clk_g or negedge rst_n) begin
    if (!rst_n) begin
        r_peak         <= 0;
        refractory_cnt <= 0;
    end else if (flush) begin
        r_peak         <= 0;
        refractory_cnt <= 0;
    end else if (sample_en && proc_en) begin
        r_peak <= 0;
        if (refractory_cnt > 0)
            refractory_cnt <= refractory_cnt - 1'b1;
        else if (filtered_ecg > R_THRESHOLD) begin
            r_peak         <= 1;
            refractory_cnt <= REFRACTORY;
        end
    end
end

//==========================================================
// 7. RR interval and BPM divider                 [clk_g, gated]
//==========================================================
reg [31:0] rr_counter;
reg        first_r_detected;
reg        bpm_start;
reg [31:0] bpm_rr;
wire       bpm_busy;
wire       bpm_valid;
wire [7:0] bpm_result;

ecg_bpm_divider bpm_divider (
    .clk(clk_g), .rst_n(rst_n), .start(bpm_start),
    .rr_samples(bpm_rr), .busy(bpm_busy),
    .valid(bpm_valid), .bpm(bpm_result)
);

always @(posedge clk_g or negedge rst_n) begin
    if (!rst_n) begin
        rr_counter       <= 0;
        first_r_detected <= 0;
        bpm_start        <= 0;
        bpm_rr           <= 0;
    end else if (flush) begin
        bpm_start        <= 0;
        rr_counter       <= 0;
        first_r_detected <= 0;
    end else begin
        bpm_start <= 0;
        if (sample_en && proc_en) begin
            rr_counter <= rr_counter + 1'b1;
            if (r_peak) begin
                if (!first_r_detected) begin
                    first_r_detected <= 1;
                end else if (rr_counter != 0 && !bpm_busy) begin
                    bpm_rr    <= rr_counter;
                    bpm_start <= 1;
                end
                rr_counter <= 0;
            end
        end
    end
end

//==========================================================
// 8. Heart rate and rate check                   [clk, always on]
//    60..100 BPM is normal, anything else abnormal
//    (demo only, not a medical standard)
//==========================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        heart_rate <= 0;
    else if (bpm_valid)
        heart_rate <= bpm_result;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        abnormal <= 0;
    else if (heart_rate == 0)
        abnormal <= 0;
    else if ((heart_rate < 60) || (heart_rate > 100))
        abnormal <= 1;
    else
        abnormal <= 0;
end

endmodule
