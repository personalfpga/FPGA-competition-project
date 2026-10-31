# Z15: clock Y14 fixed 3.3 V, reset PL_KEY1/H5, LED E4.
# Physical Bank35 MUST be 1.8 V for these digital I/O constraints.
set_property -dict {PACKAGE_PIN Y14 IOSTANDARD LVCMOS33} [get_ports clk]
create_clock -name sys_clk -period 20.000 [get_ports clk]
set_property -dict {PACKAGE_PIN H5 IOSTANDARD LVCMOS18} [get_ports rst_n]
set_property -dict {PACKAGE_PIN E4 IOSTANDARD LVCMOS18} [get_ports led]
set_property PACKAGE_PIN L12 [get_ports vp_in]
set_property PACKAGE_PIN M11 [get_ports vn_in]
# Only the reset synchronizer sees this asynchronous board input directly.
# Reset release for the rest of the design is synchronized in ecg_top.
set_false_path -from [get_ports rst_n]
set_false_path -to [get_ports led]
