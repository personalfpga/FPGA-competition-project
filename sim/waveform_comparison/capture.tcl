foreach instance {baseline gated} {
 foreach signal {state clk_en clk_g r_peak heart_rate ecg_data} {
  log_wave /comparison_tb/$instance/$signal
 }
}
log_wave /comparison_tb/clk
run all
quit
