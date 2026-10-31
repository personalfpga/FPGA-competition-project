set scripts [file normalize [file dirname [info script]]]
set build_root [file normalize [file join $scripts .. .. build]]
if {[llength $argv]>0} {set build_root [file normalize [lindex $argv 0]]}
foreach variant {baseline fsm_only gated adc mode8 mode9} {
    set argv [list $variant 5120 $build_root]
    source [file join $scripts build_vivado.tcl]
}
puts "ALL_RELEASE_BUILDS_PASS variants=6 Vivado=2025.2"
