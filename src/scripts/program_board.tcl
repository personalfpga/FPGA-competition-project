# Volatile JTAG configuration only. No flash write and no wiring changes.
# Use only with artificial signals, never with electrodes attached to a person.
set root [file normalize [file join [file dirname [info script]] .. ..]]
set tag adc
if {[llength $argv]>0} {set tag [lindex $argv 0]}
if {$tag ne "adc" && ![regexp {^mode[0-9]$} $tag]} {error "Expected adc or mode0..mode9"}
if {[version -short] ne "2025.2"} {error "Use Vivado 2025.2"}
set bitfile $root/build/bitstreams/${tag}_release.bit
set evidence_tag $tag
if {$tag eq "mode7"} {set evidence_tag gated}
set evidence $root/build/reports/$evidence_tag/release_checks.txt
if {![file exists $bitfile] || ![file exists $evidence]} {error "Missing bitstream or validation report"}
set f [open $evidence r];set proof [read $f];close $f
if {![regexp {WNS=([0-9.]+) WHS=([0-9.]+)} $proof -> wns whs] || $wns<=0 || $whs<=0} {error "No passing timing evidence"}
if {![string match *debug_cells=0* $proof] || ![string match *DRC_errors=0* $proof]} {error "Release checks failed"}
if {![regexp {gain_q8=([0-9]+)} $proof -> actual_gain]} {error "Gain missing from release configuration"}
set reportdir $root/build/reports/hardware
file mkdir $reportdir
open_hw_manager
connect_hw_server -url localhost:3121
set targets [get_hw_targets]
if {[llength $targets]!=1} {error "Expected exactly one connected JTAG target: $targets"}
current_hw_target [lindex $targets 0]
open_hw_target
set devices [get_hw_devices -filter {PART == xc7z015}]
if {[llength $devices]!=1} {error "Expected exactly one XC7Z015: $devices"}
set dev [lindex $devices 0]
current_hw_device $dev
set f [open $reportdir/${tag}_program_check.txt w]
puts $f "started=[clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S %z}]"
puts $f "device=xc7z015 target=<JTAG_TARGET> bitstream=build/bitstreams/${tag}_release.bit"
puts $f "programming=volatile_JTAG_only no_flash_write=1 wiring_changed=0"
set_property PROGRAM.FILE $bitfile $dev
set_property PROBES.FILE {} $dev
set_property FULL_PROBES.FILE {} $dev
program_hw_devices $dev
refresh_hw_device $dev
set done [get_property REGISTER.IR.BIT5_DONE $dev]
set ilas [get_hw_ilas -quiet -of_objects $dev]
set vios [get_hw_vios -quiet -of_objects $dev]
puts $f "DONE=$done ILA_count=[llength $ilas] VIO_count=[llength $vios]"
if {$done!=1 || [llength $ilas]!=0 || [llength $vios]!=0} {close $f;error "Hardware release checks failed"}
set sysmons [get_hw_sysmons -of_objects $dev]
if {$tag eq "adc"} {
    if {[llength $sysmons]!=1} {close $f;error "XADC sysmon not found"}
    set sm [lindex $sysmons 0]
    set c [open $reportdir/adc_vpvn_readback.csv w]
    puts $c "index,raw_hex,adc_code,estimated_vp_minus_vn_V"
    for {set k 0} {$k<32} {incr k} {
        set raw [get_hw_sysmon_reg $sm 03]
        scan $raw %x value
        set code [expr {($value>>4)&4095}]
        puts $c "$k,$raw,$code,[format %.7f [expr {$code/4096.0}]]"
        after 50
    }
    close $c
    puts $f "XADC_readback=PASS register=03 samples=32"
    puts $f "Readback confirms ADC register access, not analog ECG accuracy or signal-generator calibration."
}
puts $f "gain_q8=$actual_gain candidate_gain=[expr {$actual_gain/256.0}]x calibration=NOT_PERFORMED"
puts $f "verification_scope=JTAG_DONE_debug_core_removal_ADC_register_access_only"
puts $f "external_signal_generator_connected=NOT_VERIFIED R_T_amplitude_targets=NOT_VERIFIED"
puts $f "status=PASS board_left=$tag"
close $f
puts "BOARD_PROGRAM_PASS tag=$tag DONE=$done ILA_count=[llength $ilas] VIO_count=[llength $vios]"
close_hw_target
disconnect_hw_server
close_hw_manager
