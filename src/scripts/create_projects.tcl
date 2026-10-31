# vivado -mode batch -source src/scripts/create_projects.tcl
source [file join [file dirname [info script]] project_config.tcl]
set build_root $ecg::root/build
if {[llength $argv]} {set build_root [file normalize [lindex $argv 0]]}
foreach tag {adc mode7 mode8 mode9 baseline fsm_only gated} {
    ecg::open_design $tag 5120 $build_root
    close_project
    puts "PROJECT_CREATED tag=$tag"
}
