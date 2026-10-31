# Build and verify

Use Vivado 2025.2, xc7z015clg485-2, the 20 ns clock constraint and the supplied Q8 gain setting. Run the 17-result digital regression before RTL changes are accepted. Build release variants with `vivado -mode batch -source src/scripts/build_all.tcl` from the root. Keep generated project caches out of version control.

Require nonnegative setup and hold slack, no DRC errors and no debug cores in release images. Compare baseline, fsm_only and gated using the same mode 7 chain; ROM modes and VIO debug hardware have different resource costs. Recalculate report/resource_power_values.json only from the included or freshly regenerated reports. Run src/scripts/bit_compare.py and check_release.py after publication hashes are regenerated.
