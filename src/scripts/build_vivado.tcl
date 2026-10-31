# vivado -mode batch -source src/scripts/build_vivado.tcl -tclargs gated 5120
# Optional third argument: private local build directory (not for the repository).
source [file join [file dirname [info script]] project_config.tcl]
set tag gated
set gain 5120
set build_root $ecg::root/build
if {[llength $argv]>0} {set tag [lindex $argv 0]}
if {[llength $argv]>1} {set gain [lindex $argv 1]}
if {[llength $argv]>2} {set build_root [file normalize [lindex $argv 2]]}
if {$tag eq "mode7"} {set tag gated}
set root $ecg::root
set_param general.maxThreads 3
set project_dir [ecg::open_design $tag $gain $build_root]
lassign [ecg::config $tag $gain] adc mode adaptive gate
reset_run synth_1
if {$adc} {generate_target all [get_ips xadc_vpvn]}
launch_runs synth_1 -jobs 3
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {error "Synthesis failed $tag"}
launch_runs impl_1 -to_step write_bitstream -jobs 3
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {error "Implementation failed $tag"}
open_run impl_1
set private $project_dir/private_reports
set public $root/build/reports/$tag
file mkdir $private $public
report_timing_summary -file $private/timing_summary.rpt
report_utilization -file $private/utilization.rpt
report_power -file $private/power_estimate.rpt
report_drc -file $private/drc.rpt
report_clock_utilization -file $private/clock_utilization.rpt
report_io -file $private/io.rpt
foreach name {timing_summary utilization power_estimate drc clock_utilization io} {
    ecg::publish_report $private/$name.rpt $public/$name.rpt
}
set wns [get_property SLACK [get_timing_paths -max_paths 1]]
set whs [get_property SLACK [get_timing_paths -delay_type min -max_paths 1]]
set debug [get_cells -hier -filter {REF_NAME =~ *ila* || REF_NAME =~ *vio* || REF_NAME =~ *dbg_hub*}]
set gate_cells [get_cells -quiet -hier -filter {NAME =~ *bufg_proc*}]
set drc [get_drc_violations -quiet -filter {SEVERITY == Error}]
if {$wns<0 || $whs<0 || [llength $drc] || [llength $debug]} {error "Release checks failed $tag"}
if {$gate && [llength $gate_cells]!=1} {error "Clock gate missing $tag"}
if {!$gate && [llength $gate_cells]!=0} {error "Unexpected clock gate $tag"}
if {$tag eq "baseline" && [llength [get_cells -quiet -hier -regexp {.*(quiet_cnt|hold_cnt|flush_cnt)_reg.*}]]} {error "Baseline controller did not optimize out"}
file mkdir $root/build/bitstreams
file copy -force $project_dir/ecg.runs/impl_1/ecg_top.bit $root/build/bitstreams/${tag}_release.bit
set f [open $public/release_checks.txt w]
puts $f "vivado=2025.2 tag=$tag part=xc7z015clg485-2 clock_hz=50000000"
puts $f "gain_q8=$gain use_adc=$adc test_mode=$mode ENABLE_ADAPTIVE=$adaptive USE_CLK_GATE=$gate SLEEP_TIMEOUT=2500"
puts $f "WNS=$wns WHS=$whs debug_cells=0 DRC_errors=0 gate_cells=[llength $gate_cells]"
puts $f "power_method=post_route_vectorless_no_SAIF common_tool_defaults_not_measured_power"
puts $f "calibration=NOT_PERFORMED analog_input_accuracy=NOT_VERIFIED"
puts $f "hardware_download=NOT_CLAIMED_BY_BUILD_SCRIPT"
close $f
if {$tag eq "gated"} {file copy -force $root/build/bitstreams/gated_release.bit $root/build/bitstreams/mode7_release.bit}
close_project
puts "RELEASE_BUILD_PASS tag=$tag WNS=$wns WHS=$whs gain_q8=$gain"
