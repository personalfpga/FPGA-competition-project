# XSim mode 7 comparison

From the repository root, run `& ./sim/waveform_comparison/run_xsim.ps1` in a Vivado 2025.2 configured PowerShell environment. Optionally pass -VivadoBin with your local bin directory. Generated outputs are written under this folder's run/ directory. The testbench reads the same internal mode 7 input in two instances: adaptive/gating parameters 0/0 and 1/1. Its main clock is 100 kHz with 1 kHz sampling for accelerated functional verification; the physical release target uses 50 MHz. The included zero-delay behavioral BUFGCE model is not a routed timing model.

The checked steady cycle counts are 2280000 main edges and 1850604 gated edges, or 18.8331579 percent less processing-clock activity. Input mismatches and stable-sleep gated edges must both be zero. Log STATE time_ns labels contain picoseconds due to the original 1 ps print precision.

Open a saved native view after generating its database with `vivado -mode gui -source sim/waveform_comparison/open_baseline.tcl`, or use open_gated.tcl instead. Saved window geometry may require adjusting the visible interval to 18.0..23.943141254463 seconds. Final native captures are in `../../report/waveforms/`.
