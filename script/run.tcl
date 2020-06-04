set_param general.maxThreads 32

set_part xc7z100ffg900-2

read_verilog [glob ../design/*.v]
read_verilog [glob ../design/ip/i2c_master/*.v]

file mkdir ./ip/sys_pll
file copy -force ../ip/sys_pll.xci ./ip/sys_pll/
read_ip ./ip/sys_pll/sys_pll.xci
synth_ip [get_ips sys_pll]

read_xdc [glob ../constr/*.xdc]
synth_design -top top
write_checkpoint -force post_synth.dcp
report_timing_summary -file timing_syn.rpt

opt_design
read_checkpoint -incremental post_route.dcp
place_design
write_checkpoint -force post_place.dcp
report_timing -file timing_place.rpt
phys_opt_design
route_design
write_checkpoint -force post_route.dcp
report_timing_summary -file timing_summary.rpt
write_bitstream -force output.bit
