# Board and power evidence

Read board/readme.md and docs/ad8232_status.md before interpreting a capture. The XADC evidence demonstrates register access and decoded conversions, not complete analog ECG validation. Keep the 50 MHz release clock separate from the 100 kHz accelerated functional testbench clock.

For activity counters, state the interval and use 1-sum(gated_cycles)/sum(total_cycles), not an average of percentages. Distinguish RTL, offline model and board figures. The approximately 1.36 mW endpoint difference is from controlled vectorless Vivado estimates with low confidence, not from a current sensor. Do not use differing resource designs or unqualified static-power differences as evidence of savings.
