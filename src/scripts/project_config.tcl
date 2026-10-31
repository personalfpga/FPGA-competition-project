namespace eval ecg {
    variable root [file normalize [file join [file dirname [info script]] .. ..]]
}
proc ecg::config {tag gain} {
    if {![string is integer -strict $gain] || $gain<0 || $gain>65535} {error "gain_q8 must be 0..65535"}
    switch -- $tag {
        adc      {return [list 1 7 1 1]}
        mode7 - gated {return [list 0 7 1 1]}
        mode8    {return [list 0 8 1 1]}
        mode9    {return [list 0 9 1 1]}
        baseline {return [list 0 7 0 0]}
        fsm_only {return [list 0 7 1 0]}
        default  {error "Expected adc, mode7, mode8, mode9, baseline, fsm_only or gated"}
    }
}
proc ecg::open_design {tag gain build_root} {
    variable root
    if {[version -short] ne "2025.2"} {error "Use Vivado 2025.2 for comparable reports"}
    lassign [ecg::config $tag $gain] adc mode adaptive gate
    set dir [file normalize [file join $build_root $tag]]
    if {[file exists $dir/ecg.xpr]} {
        open_project $dir/ecg.xpr
    } else {
        create_project ecg $dir -part xc7z015clg485-2
        set_property target_language Verilog [current_project]
        add_files [glob $root/src/rtl/*.v]
        add_files -fileset constrs_1 $root/src/constraints/ecg_board.xdc
        if {$adc} {add_files -norecurse $root/src/ip/xadc_vpvn/xadc_vpvn.xci}
    }
    set_property top ecg_top [get_filesets sources_1]
    set_property generic "ADC_GAIN_Q8=$gain USE_ADC=$adc TEST_MODE=$mode ENABLE_ADAPTIVE=$adaptive USE_CLK_GATE=$gate" [get_filesets sources_1]
    update_compile_order -fileset sources_1
    return $dir
}
proc ecg::publish_report {private_path public_path} {
    variable root
    set f [open $private_path r];fconfigure $f -encoding utf-8;set text [read $f];close $f
    # Only paths/host identifiers are redacted. Numerical report data is unchanged.
    set text [string map [list $root {<PROJECT_ROOT>} [string map {/ \\} $root] {<PROJECT_ROOT>}] $text]
    regsub -all -nocase {[A-Z]:[/\\]Users[/\\][^/\\\s|]+[^\r\n|]*} $text {<LOCAL_BUILD_PATH>} text
    regsub -all -line {(^\| Host[ ]*:[ ]*)[^|\r\n]*} $text {\1<BUILD_HOST> } text
    set f [open $public_path w];fconfigure $f -encoding utf-8;puts -nonewline $f $text;close $f
}
