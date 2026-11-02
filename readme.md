# Z15 ECG adaptive clock-gating demonstration

Digital ECG processing with SLEEP, NORMAL and ALERT states on the Z15 / Zynq-7000 XC7Z015. The processing clock is gated by BUFGCE after the processing-chain state is flushed; an always-on monitor triggers wake-up when the input exceeds the wake threshold. Valid heart rates below 60 or above 100 BPM activate the alert LED.

The release target is xc7z015clg485-2 with a 50 MHz input clock, using Vivado 2025.2. Inputs are built-in test patterns and MIT-BIH data replay. Complete AD8232 acquisition and analog gain calibration remain incomplete. Demonstration and teaching use only; not a medical device.

## Repository contents

| Directory | Contents |
|---|---|
| src/ | RTL, XADC IP, board constraints, release/debug build and verification scripts |
| sim/ | Testbenches, ROM reference counts, regression guide and XSim comparison |
| build/ | Release/debug bitstreams and archived implementation, regression and power reports |
| board/ | XADC verification summary and representative activity-counter capture |
| data/ | MIT-BIH-derived replay samples with provenance and attribution |
| skill/ | Main reproduction workflow and build, board and power guidance |
| report/ | Resource/power comparison, technical PDF, native waveform images and videos |
| ai_records/ | Redacted public selections from Codex and Claude collaboration records |
| docs/ | Data license, AD8232 status, contents index and integrity evidence |

See [contents index](docs/included_checklist.md) and [technical report](report/technical_report.pdf).

## Reproduce

Use Python 3, numpy, Icarus Verilog (iverilog and vvp), and Vivado 2025.2. Run from the repository root:

```text
python src/scripts/privacy_scan.py
python src/scripts/check_release.py
python src/scripts/bit_compare.py
python src/scripts/run_tests.py
vivado -mode batch -source src/scripts/build_all.tcl
```

The digital regression has 17 declared results, including complete-loop ROM comparisons. Archived PASS logs are historical evidence; executing the test command produces a new run. To recalculate resource values from the implementation reports, run `python src/scripts/summarize_reports.py`.

### Select modes and build release images

```text
vivado -mode batch -source src/scripts/build_vivado.tcl -tclargs gated 5120
vivado -mode batch -source src/scripts/build_vivado.tcl -tclargs mode8 5120
vivado -mode batch -source src/scripts/build_vivado.tcl -tclargs mode9 5120
```

| Mode | Input | Bitstream |
|---|---|---|
| 7 | Synthetic activity sequence | build/bitstreams/mode7_release.bit |
| 8 | MIT-BIH record 119 replay | build/bitstreams/mode8_release.bit |
| 9 | MIT-BIH record 100 replay | build/bitstreams/mode9_release.bit |

Mode 7 and gated_release.bit are byte-identical. Release mode selection is fixed by the selected image. In Vivado Hardware Manager, connect the matching Z15 board and program the corresponding bitstream. The volatile-JTAG helper can also be used:

```text
vivado -mode batch -source src/scripts/program_board.tcl -tclargs mode7
```

Substitute mode8 or mode9 as required. These commands need matching connected hardware. The separate ecg_activity.bit debug design uses ecg_activity.ltx and a four-bit VIO probe_out0 mode control: commit 0x7, 0x8 or 0x9. Release and debug images have different interfaces. Rebuild the debug image with:

```text
vivado -mode batch -source src/scripts/build_demo.tcl -tclargs build/debug_work
```

## Results and measurement scope

In the specified archived board interval, on-board cycle counters measured approximately 18.28% less processing-clock activity relative to the always-running baseline. The RTL steady-cycle reduction is approximately 18.8%; the offline-model result is approximately 18.66%. These figures use separate datasets and intervals.

The approximately 1.36 mW figure is a controlled Vivado dynamic-power endpoint estimate, not measured whole-board power savings. Compared with the same mode 7 processing-chain baseline, the gated design uses 78 additional LUTs and 30 additional FFs. See [resource and power scope](report/resource_power_summary.md).

### Waveform simulation scope

**Accelerated functional simulation: 100 kHz simulation clock, 1 kHz sampling. The physical release clock is 50 MHz.** The waveform comparison is a functional RTL test with a zero-delay behavioral BUFGCE model, not routed timing simulation or a live board capture.

The paired XSim test reproduces 2,280,000 main-clock edges versus 1,850,604 gated-clock edges over a 22.8-second steady cycle: 18.8331579% less processing-clock activity. See [comparison instructions](sim/waveform_comparison/readme.md), report/waveforms/metrics.json and report/waveforms/xsim_result.txt.

Native JPG captures and baseline_10s.mp4, gated_10s.mp4 and comparison_10s.mp4 are in report/waveforms/. Each clip is 10 seconds, H.264, 1080p at 30 fps. When reproducing these waveforms in a video, figure or document, retain the caption: **Accelerated functional simulation (100 kHz); hardware release clock: 50 MHz.**

## Known limitation after an abnormal rate

The heart-rate register updates only when a new valid BPM result is available.
If the input becomes flat after an abnormal rate and no further valid R peaks
are detected, the last abnormal heart-rate value can remain held. The design
then stays in ALERT: the no-R-peak sleep timer is cleared in ALERT, the LED
remains on, and the processing clock continues to run. Automatic sleep after
signal loss is therefore limited to the NORMAL-state path in this version.

The archived regression and the reported mode 7 activity-reduction interval
do not establish behavior for abnormal-rate-to-flat input. The 18.28% result
applies to its stated captured interval, not to all possible input sequences.
A future revision should define and test signal-loss handling in ALERT,
including a no-R-peak timeout and explicit treatment of a stale BPM value.

## AI collaboration and licenses

The public selections in ai_records/ include prompts, model responses and correction examples from the supplied Codex and Claude records. Source notes and redaction details are in ai_records/readme.md. Historical model responses are not validation evidence; use the source, tests and reports to assess technical claims.

Code license: [MIT](license). Replay data retain their separate Open Data Commons Attribution License notice; see [data provenance and license](docs/data_sources_and_license.md).

## Included bitstream SHA-256

- `build/bitstreams/adc_release.bit`: `81137e0fcf338ac7f29a90ba6374b0efd1d2c6bd4ae49ed515fd08c80f87c792`
- `build/bitstreams/baseline_release.bit`: `8147e6e4badb18643f0424d24b7fdd9ad29a1a44285df46380cda8cc1d076e57`
- `build/bitstreams/ecg_activity.bit`: `e064e6b83704904647ceec0f52be7a0eb23baa5c41153befea9a86ba94b96318`
- `build/bitstreams/fsm_only_release.bit`: `92de232834061933212650b09f50946778f82d6f8b345ae0861c97ee74a1ae19`
- `build/bitstreams/gated_release.bit`: `814534356866243254ecdb6626e6e0be5d414e8b0aef15bb8c8e307a7e2594c6`
- `build/bitstreams/mode7_release.bit`: `814534356866243254ecdb6626e6e0be5d414e8b0aef15bb8c8e307a7e2594c6`
- `build/bitstreams/mode8_release.bit`: `e614c0d7dac8571c90af4dae4c279d4bde12b02c82ce9085b3db40d642750f08`
- `build/bitstreams/mode9_release.bit`: `ef179125cabbea35022ff50c9585bf05bd95c11cb0329d66f8a5c5dc280193ef`

Each bitstream is approximately 3.51 MB. File hashes are recorded in release_manifest.json.
