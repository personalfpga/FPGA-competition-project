`timescale 1ns / 1ps
// Z15 / XC7Z015, 50 MHz. Simulation/demo only; not for medical use.
// USE_ADC=1: XADC VP/VN -> 1 kHz DC removal/gain/offset/clamp -> core.
// USE_ADC=0: preserve supplied test modes 0..9, including MIT-BIH ROM.
module ecg_top #(
    parameter integer CLK_FREQ_HZ = 50_000_000,
    parameter integer USE_ADC = 1,
    parameter [3:0] TEST_MODE = 4'd7,
    parameter integer SLEEP_TIMEOUT = 2500,
    parameter integer USE_CLK_GATE = 1,
    parameter integer ENABLE_ADAPTIVE = 1,
    parameter [15:0] ADC_GAIN_Q8 = 16'd5120, // 20.0 candidate only; MUST calibrate with a signal generator
    parameter integer ADC_AUTO_DC = 1,
    parameter [11:0] ADC_FIXED_DC = 12'd2048,
    parameter integer WARMUP_SAMPLES = 256
)(
    input wire clk, input wire rst_n,
    input wire vp_in, input wire vn_in,
    output wire led
);
    (* ASYNC_REG = "TRUE" *) reg [1:0] reset_pipe = 2'b00;
    always @(posedge clk or negedge rst_n)
        if (!rst_n) reset_pipe <= 2'b00;
        else reset_pipe <= {reset_pipe[0], 1'b1};

    // Keep the XADC in reset for 1 ms after configuration.
    localparam integer POR_CYCLES = CLK_FREQ_HZ / 1000;
    reg [31:0] por_count = 0;
    always @(posedge clk or negedge reset_pipe[1])
        if (!reset_pipe[1]) por_count <= 0;
        else if (por_count < POR_CYCLES) por_count <= por_count + 1'b1;
    wire reset_n = reset_pipe[1] && ((USE_ADC == 0) || (por_count >= POR_CYCLES));

    wire [15:0] adc_ecg;
    wire conditioned_ready;
    wire [11:0] dc_estimate;
    wire [31:0] conditioned_count;
    generate if (USE_ADC != 0) begin : g_adc
        wire [15:0] drp_data, adc_word;
        wire [11:0] adc_code;
        wire [6:0] daddr;
        wire [4:0] channel;
        wire eoc, drdy, den, pending, sample_valid, adc_seen;
        wire [31:0] sample_count;
        xadc_vpvn adc_hw (
            .dclk_in(clk), .reset_in(!reset_n), .daddr_in(daddr),
            .den_in(den), .dwe_in(1'b0), .di_in(16'd0),
            .do_out(drp_data), .drdy_out(drdy), .vp_in(vp_in), .vn_in(vn_in),
            .channel_out(channel), .eoc_out(eoc), .eos_out(), .busy_out()
        );
        xadc_reader reader (
            .clk(clk), .rst_n(reset_n), .eoc(eoc), .channel(channel),
            .drdy(drdy), .drp_data(drp_data), .den(den), .daddr(daddr),
            .pending(pending), .adc_word(adc_word), .adc_code(adc_code),
            .sample_valid(sample_valid), .adc_seen(adc_seen), .sample_count(sample_count)
        );
        wire prepare_sample;
        ecg_sample_schedule #(.CLK_FREQ_HZ(CLK_FREQ_HZ)) schedule (
            .clk(clk), .rst_n(reset_n), .prepare_sample(prepare_sample)
        );
        reg [31:0] last_adc_count;
        wire fresh_adc = adc_seen && (sample_count != last_adc_count);
        always @(posedge clk or negedge reset_n)
            if (!reset_n) last_adc_count <= 0;
            else if (prepare_sample) last_adc_count <= sample_count;

        ecg_adc_conditioner #(.WARMUP_SAMPLES(WARMUP_SAMPLES)) condition (
            .clk(clk), .rst_n(reset_n), .sample_ce(prepare_sample), .raw_valid(fresh_adc),
            .raw_code(adc_code), .gain_q8(ADC_GAIN_Q8),
            .auto_dc(ADC_AUTO_DC != 0), .fixed_dc(ADC_FIXED_DC),
            .adc_ecg(adc_ecg), .ready(conditioned_ready), .dc_estimate(dc_estimate),
            .conditioned_count(conditioned_count)
        );
    end else begin : g_test
        assign adc_ecg = 16'd1000;
        assign conditioned_ready = 1'b0;
        assign dc_estimate = 12'd0;
        assign conditioned_count = 32'd0;
    end endgenerate

    wire r_peak, abnormal, low_power, proc_en;
    wire [7:0] heart_rate;
    wire [1:0] state;
    ecg_core #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ), .SLEEP_TIMEOUT(SLEEP_TIMEOUT),
        .USE_CLK_GATE(USE_CLK_GATE), .ENABLE_ADAPTIVE(ENABLE_ADAPTIVE)
    ) core (
        .clk(clk), .rst_n(reset_n), .test_mode(TEST_MODE),
        .use_adc(USE_ADC != 0), .adc_ecg(adc_ecg),
        .r_peak(r_peak), .heart_rate(heart_rate), .abnormal(abnormal),
        .low_power(low_power), .state(state), .proc_en(proc_en), .led(led)
    );
endmodule
