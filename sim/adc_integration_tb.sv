`timescale 1ns/1ps
// Digital XADC protocol model, NOT an analog/front-end or on-board test.
module adc_integration_tb;
    parameter integer GAIN_Q8 = 5120;
    localparam integer R_RAW = 1475 + (3600*256)/GAIN_Q8;
    localparam integer T_RAW = 1475 + (600*256)/GAIN_Q8;
    reg clk=0, rst_n=0;
    wire led;
    ecg_top #(.CLK_FREQ_HZ(100_000), .WARMUP_SAMPLES(32), .ADC_GAIN_Q8(GAIN_Q8)) dut(
        .clk(clk), .rst_n(rst_n), .vp_in(1'b0), .vn_in(1'b0), .led(led));
    always #5 clk=~clk;
    integer tick=0, last_prepare=-1, last_core=-1;
    integer prepared=0, consumed=0, saw75=0, saw120=0, saw_r_high=0, saw_t_low=0;
    integer phase=0, period_ms=800;
    integer raw_value=1475;
    integer dc_before, expected, delta, product;
    reg [15:0] held_sample=1000;
    // Update on the falling edge well before the next 1kHz preparation tick.
    always @(negedge clk) if(dut.reset_n) begin
        period_ms=(consumed<6500)?800:500;
        phase=consumed%period_ms;
        raw_value=1475;
        if(phase>=195 && phase<210) raw_value=R_RAW; // Synthetic delta maps to about 3600 output counts
        else if(phase>=300 && phase<380) raw_value=T_RAW; // Synthetic delta maps to about 600 output counts
        dut.g_adc.adc_hw.injected_code=raw_value;
    end
    always @(posedge clk) begin
        tick=tick+1;
        if(dut.reset_n) begin
            if(dut.g_adc.prepare_sample) begin
                if(last_prepare>=0 && tick-last_prepare!=100) $fatal(1,"prepare rate !=1 kHz");
                last_prepare=tick;prepared=prepared+1;
                dc_before=dut.dc_estimate;
                delta=dut.g_adc.adc_code-dc_before;
                product=delta*GAIN_Q8;
                expected=(product>=0)?((product+128)/256):-(((-product)+128)/256);
                expected=expected+1000;
                if(expected<0) expected=0;
                if(expected>4095) expected=4095;
                if(!dut.conditioned_ready) expected=1000;
                #1;
                if(dut.adc_ecg!==expected) $fatal(1,"conditioning arithmetic mismatch");
                held_sample=dut.adc_ecg;
                if(raw_value==R_RAW && dut.adc_ecg>4000) saw_r_high=1;
                if(raw_value==T_RAW && dut.adc_ecg<=2500) saw_t_low=1;
                if(prepared>1000 && raw_value==R_RAW && dut.adc_ecg<=4000) $fatal(1,"R below calibration target");
                if(prepared>1000 && raw_value==T_RAW && dut.adc_ecg>2500) $fatal(1,"T exceeds threshold");
            end else if(dut.core.sample_en) begin
                if(last_core>=0 && tick-last_core!=100) $fatal(1,"core rate !=1 kHz");
                if(tick-last_prepare!=8) $fatal(1,"conditioner/core phase mismatch");
                if(dut.core.ecg_data!==held_sample) $fatal(1,"ADC not connected to core");
                last_core=tick;consumed=consumed+1;
                if(dut.heart_rate==75) saw75=1;
                if(dut.heart_rate==120 && dut.abnormal && led) saw120=1;
                if(consumed>3000 && consumed<6000 && (dut.heart_rate!=75 || dut.state!=1)) $fatal(1,"75 BPM stability");
                if(consumed>9000 && (dut.heart_rate!=120 || dut.state!=2)) $fatal(1,"120 BPM stability");
                if(led!==(dut.state==2)) $fatal(1,"LED must indicate ALERT");
                if(dut.adc_ecg>4095) $fatal(1,"12 bit clamp");
                if(consumed==12000) begin
                    if(!saw75 || !saw120 || !saw_r_high || !saw_t_low) $fatal(1,"missing waveform/heart-rate coverage");
                    $display("ADC_INTEGRATION_PASS samples=%0d interval_clocks=100 prepare_lead=8 75bpm=PASS 120bpm=PASS LED=PASS R_gt4000=PASS T_le2500=PASS",consumed);
                    $finish;
                end
            end
        end
    end
    initial begin repeat(4) @(negedge clk); rst_n=1; end
    initial begin #13000000; $fatal(1,"integration timeout"); end
endmodule
