---
name: z15-ecg-reproduce
description: Reproduce and audit the Z15 ECG three-state gating design, including simulation, resources, timing, activity and power evidence.
---

# Z15 ECG reproduction and evidence audit

English adaptation of the supplied skill/skill.md. Commands and directory roles
are in ../readme.md. This is guidance, not an interaction transcript.

First establish the target mode and claim. AI may propose RTL, script or report
changes; verify them using actual files, commands and human review. Read
../ai_records/readme.md for historical-record boundaries; current source and
evidence take precedence over unsupported historical statements.

- Compare baseline, fsm_only and gated with the same processing chain, mode 7,
  50 MHz and tool version; vary ENABLE_ADAPTIVE and USE_CLK_GATE only. Report
  ROM modes 8/9 and the VIO demo separately because they add different resources.
- Check startup wake, peak detection through result recovery and quiet-state
  clock stopping. Retain the original four-clock flush and registered clk_en
  design, and rerun relevant regression for any change.
- Calculate aggregate activity reduction as 1-sum(gated_cycles)/sum(total_cycles).
  State the interval; do not average interval percentages. Approximately 18.8%
  simulation, 18.66% offline model and 18.28% board figures have distinct scopes.
- Fixed-temperature/fixed-I/O release power endpoints are retained in
  ../build/demo_reports/release_power/ and summarized by power_comparison.json. Approximately
  1.36mW is a modeled dynamic-power endpoint difference, not measured board
  savings. Debug/demo endpoints need separate configuration.
- Archived XADC evidence establishes consistency of 4096 stored conversions,
  not complete current-release AD8232 acquisition, analog gain calibration or
  whole-board power acceptance.

Associate every claim with commands, result paths, versions and configuration.
Distinguish rereading historical evidence from a new execution. Preserve failure
logs and diagnose them; never write expected results into evidence. Historical
"passed" wording must not label a new run unless that run actually succeeds.
