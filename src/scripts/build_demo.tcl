set root [file normalize [file join [file dirname [info script]] ../..]]
if {[version -short] ne "2025.2"} {error "Vivado 2025.2 required"}
if {![file exists $root/build/demo_reports/demo_tests.json]} {error "Use the competition package with archived demo evidence, or run and supply fresh demo validation first"}
set f [open $root/build/demo_reports/demo_tests.json r];set tested [read $f];close $f
if {![string match *activity_top* $tested]} {error "Run the demo wrapper test first"}
if {![file exists $root/build/reports/simulation/results.json]} {error "Run release regression first"}
set build [file normalize [lindex $argv 0]]
set_param general.maxThreads 3
create_project ecg_activity $build -part xc7z015clg485-2 -force
set_property target_language Verilog [current_project]
add_files [glob $root/src/demo/rtl/*.v]
foreach file {ecg_bpm_divider.v ecg_pattern_gen.v ecg_rom.v} {add_files $root/src/rtl/$file}
set f [open $root/src/constraints/ecg_board.xdc r];set constraints [read $f];close $f
set out [open $build/demo.xdc w]
foreach line [split $constraints \n] {if {![string match *vp_in* $line] && ![string match *vn_in* $line]} {puts $out $line}}
close $out
add_files -fileset constrs_1 $build/demo.xdc
create_ip -name vio -vendor xilinx.com -library ip -version 3.0 -module_name ecg_activity_vio
set_property -dict [list CONFIG.C_NUM_PROBE_IN {7} CONFIG.C_NUM_PROBE_OUT {4} \
 CONFIG.C_EN_PROBE_IN_ACTIVITY {0} \
 CONFIG.C_PROBE_IN0_WIDTH {32} CONFIG.C_PROBE_IN1_WIDTH {32} \
 CONFIG.C_PROBE_IN2_WIDTH {2} CONFIG.C_PROBE_IN3_WIDTH {8} \
 CONFIG.C_PROBE_IN4_WIDTH {1} CONFIG.C_PROBE_IN5_WIDTH {32} CONFIG.C_PROBE_IN6_WIDTH {1} \
 CONFIG.C_PROBE_OUT0_WIDTH {4} CONFIG.C_PROBE_OUT0_INIT_VAL {0x7} \
 CONFIG.C_PROBE_OUT1_WIDTH {1} CONFIG.C_PROBE_OUT2_WIDTH {1} CONFIG.C_PROBE_OUT3_WIDTH {1} \
 CONFIG.C_PROBE_OUT1_INIT_VAL {0x0} CONFIG.C_PROBE_OUT2_INIT_VAL {0x0} CONFIG.C_PROBE_OUT3_INIT_VAL {0x0}] [get_ips ecg_activity_vio]
generate_target all [get_ips ecg_activity_vio]
set_property top ecg_activity_top [get_filesets sources_1]
update_compile_order -fileset sources_1
launch_runs synth_1 -jobs 3
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {error "Demo synthesis failed"}
launch_runs impl_1 -to_step write_bitstream -jobs 3
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {error "Demo implementation failed"}
open_run impl_1
set report $root/build/demo_reports
report_timing_summary -file $report/demo_timing.rpt
report_utilization -hierarchical -file $report/demo_utilization.rpt
report_drc -file $report/demo_drc.rpt
report_power -file $report/demo_power.rpt
set wns [get_property SLACK [get_timing_paths -max_paths 1]]
set whs [get_property SLACK [get_timing_paths -delay_type min -max_paths 1]]
if {$wns<0 || $whs<0 || [llength [get_drc_violations -quiet -filter {SEVERITY == Error}]]} {error "Demo timing/DRC failed"}
file mkdir $root/build/bitstreams
write_debug_probes -force $root/build/bitstreams/ecg_activity.ltx
file copy -force $build/ecg_activity.runs/impl_1/ecg_activity_top.bit $root/build/bitstreams/ecg_activity.bit
set f [open $report/demo_build_checks.txt w]
puts $f "DEMO_BUILD_PASS WNS=$wns WHS=$whs debug=VIO only no_extra_pins=1 no_flash_write=1"
close $f
close_project
