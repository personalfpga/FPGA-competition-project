`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////
// ecg_pattern_gen.v - built-in test signal library (simulated ECG)
//
// One value per sample_en tick (1 kHz). Scale matches the algorithm:
// baseline about 1000, R wave 4000.
//
//   mode 0 : normal rhythm, 75 BPM  (RR 800 ms)
//   mode 1 : tachycardia, 120 BPM   (RR 500 ms)
//   mode 2 : bradycardia, 45 BPM    (RR 1333 ms)
//   mode 3 : irregular rhythm, RR = 500, 900, 700 ms repeating
//   mode 4 : no heartbeat, flat baseline
//   mode 5 : 75 BPM with noise and baseline wander (below the detector threshold)
//   mode 6 : noise and baseline wander only, no heartbeat
//   mode 7 : not used here (ecg_core uses its own demo sequence for mode 7)
//
// Demo only, not a medical signal.
//////////////////////////////////////////////////////////////////////////////
module ecg_pattern_gen (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        sample_en,
    input  wire [2:0]  mode,
    output reg  [15:0] ecg
);
    reg [15:0] bc;          // sample counter inside the current beat
    reg [1:0]  seq;         // rhythm position for the irregular mode
    reg [2:0]  mode_q;
    reg [15:0] lfsr;
    reg [10:0] w_cnt;       // baseline wander phase

    wire [15:0] period =
        (mode == 3'd1) ? 16'd500  :
        (mode == 3'd2) ? 16'd1333 :
        (mode == 3'd3) ? ((seq == 2'd0) ? 16'd500 : (seq == 2'd1) ? 16'd900 : 16'd700) :
                         16'd800;

    // PQRST shape, same as the built-in demo generator
    reg [15:0] beat_val;
    always @(*) begin
        if      (bc < 16'd50 ) beat_val = 16'd1000;
        else if (bc < 16'd100) beat_val = 16'd1200;   // P
        else if (bc < 16'd180) beat_val = 16'd1000;
        else if (bc < 16'd195) beat_val = 16'd700;    // Q
        else if (bc < 16'd210) beat_val = 16'd4000;   // R
        else if (bc < 16'd225) beat_val = 16'd600;    // S
        else if (bc < 16'd300) beat_val = 16'd1000;
        else if (bc < 16'd380) beat_val = 16'd1500;   // T
        else                   beat_val = 16'd1000;
    end

    // noise +-128 and wander +-128 (triangle)
    wire signed [10:0] noise  = $signed({3'b000, lfsr[7:0]}) - 11'sd128;
    wire        [9:0]  tri_w    = w_cnt[10] ? ~w_cnt[9:0] : w_cnt[9:0];
    wire signed [10:0] wander = $signed({3'b000, tri_w[9:3]}) - 11'sd64;   // +-64 ... scaled below
    wire signed [12:0] extra  = noise + (wander <<< 1);

    reg signed [15:0] v;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bc <= 0; seq <= 0; mode_q <= 0;
            lfsr <= 16'hACE1; w_cnt <= 0; ecg <= 16'd1000;
        end else begin
            mode_q <= mode;
            if (mode != mode_q) begin
                bc <= 0; seq <= 0;
            end else if (sample_en) begin
                lfsr  <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
                w_cnt <= w_cnt + 1'b1;
                if (bc >= period - 1) begin
                    bc <= 0;
                    seq <= (seq == 2'd2) ? 2'd0 : seq + 1'b1;
                end else
                    bc <= bc + 1'b1;

                case (mode)
                    3'd4:    v = 16'sd1000;
                    3'd5:    v = $signed({1'b0, beat_val[14:0]}) + extra;
                    3'd6:    v = 16'sd1000 + extra;
                    default: v = $signed({1'b0, beat_val[14:0]});
                endcase
                if (v < 0)         ecg <= 16'd0;
                else if (v > 4095) ecg <= 16'd4095;
                else               ecg <= v[15:0];
            end
        end
    end
endmodule
