# Board evidence

`xadc_20261013/verification_result.json` and `sysmon_registers.txt` preserve the small archived XADC summary: 4096 samples, code range 4..3033. Large raw ILA captures remain outside the public repository.

`counters/mode7_capture.csv` is a small existing mode 7 counter capture. Its total_cycles and gated_cycles columns describe per-window counts. Calculate aggregate reduction with 1-sum(gated_cycles)/sum(total_cycles) over a stated interval. Transition-crossing windows may contain mixed activity; state metadata is sampled at the end. See `../build/demo_reports/board_activity_checks.json` for the saved check scope.

The corresponding hardware demonstration used LED state indication and a separate VIO debug build. No new physical-board measurement or photograph was created while assembling this repository. Analog ECG accuracy and measured board-power savings remain unverified; see `../docs/ad8232_status.md`.

## Counter evidence for 18.28%

The [archived capture](counters/board_1792401376269930700.csv) contains 437 windows.
The reported 18.28% uses the first 396 windows, ending at host time 424.074 s:
`1 - sum(gated_cycles) / sum(total_cycles) = 18.2785813%`.
This interval differs from the short `mode7_capture.csv` example and from the
current-session statistics shown in the demonstration video.
See the [calculation notes](counters/board_1792401376269930700_readme.md).
Run `python board/counters/calc_18_28.py` from the repository root to reproduce it.
This is processing-clock activity reduction, not measured board-power savings.
