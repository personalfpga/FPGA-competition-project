set root [file dirname [file normalize [info script]]]
open_wave_database [file join $root run comparison.wdb]
open_wave_config [file join $root gated.wcfg]
