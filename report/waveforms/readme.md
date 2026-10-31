# Native waveform captures

**Accelerated functional simulation (100 kHz); hardware release clock: 50 MHz.**

The images and videos display saved Vivado XSim functional waveforms, not live physical-board measurements or routed timing simulation. Both instances receive the same internal mode 7 input. Baseline uses ENABLE_ADAPTIVE=0 / USE_CLK_GATE=0; gated uses 1 / 1. The visible interval includes sleep entry and wake-up.

baseline_10s.mp4 and gated_10s.mp4 are separate 10-second recordings; comparison_10s.mp4 switches between the two configurations. Preserve the caption above whenever reusing a capture. See metrics.json, xsim_result.txt and ../../sim/waveform_comparison/readme.md for reproduction details.
