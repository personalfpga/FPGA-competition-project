# Data sources and transformations

MIT-BIH Arrhythmia Database v1.0.0, Moody G and Mark R, PhysioNet (2005).
DOI: 10.13026/C2F305. Source: https://physionet.org/content/mitdb/1.0.0/
Contains information from the MIT-BIH Arrhythmia Database, made available
under the Open Data Commons Attribution License v1.0:
https://opendatacommons.org/licenses/by/1-0/

Mode 8: record 119, start 1551.350 s, duration 30 s, MLII.
Mode 9: record 100, start 31.724 s, duration 30 s, MLII.
Existing derived data were resampled to 1 kHz, DC removed, baseline set to
1000, scaled at 1500 counts/mV and clipped to 0..4095. No windows or sample
values were changed during packaging. See src/rtl/ecg_rom.v and
sim/ecg_rom.v.counts.csv. The code MIT license does not replace the data license.
Demonstration only; not a clinical device.
