# Resource and power scope

Reported processing-clock activity reduction: approximately 18.8% in RTL simulation, 18.66% in the offline model and 18.28% over a particular archived board interval. These are separate datasets. The approximately 1.36 mW endpoint difference is a controlled Vivado power estimate, not measured whole-board savings. Resource comparisons require the same mode 7 processing chain, 50 MHz, target and tool configuration.

## Archived Vivado report values

| Variant | LUT | FF | BRAM | DSP | Dynamic W | Total W |
|---|---:|---:|---:|---:|---:|---:|
| baseline | 311.0 | 334.0 | 0.0 | 0.0 | 0.002 | 0.104 |
| fsm_only | 387.0 | 363.0 | 0.0 | 0.0 | 0.002 | 0.105 |
| gated | 389.0 | 364.0 | 0.0 | 0.0 | 0.003 | 0.105 |
| adc | 653.0 | 526.0 | 0.0 | 2.0 | 0.006 | 0.108 |
| mode8 | 334.0 | 327.0 | 24.0 | 0.0 | 0.004 | 0.108 |
| mode9 | 335.0 | 326.0 | 24.0 | 0.0 | 0.018 | 0.122 |
