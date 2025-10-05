
create_clock -period 20.000 -waveform {0.000 10.000} [get_ports clk_30MHz]
set_input_delay -clock [get_clocks clk_30MHz] -min -add_delay 0.000 [get_ports {control_sel[*]}]
set_input_delay -clock [get_clocks clk_30MHz] -max -add_delay 2.000 [get_ports {control_sel[*]}]
set_input_delay -clock [get_clocks clk_30MHz] -min -add_delay 0.000 [get_ports {s00_axis_0_tdata[*]}]
set_input_delay -clock [get_clocks clk_30MHz] -max -add_delay 2.000 [get_ports {s00_axis_0_tdata[*]}]
set_input_delay -clock [get_clocks clk_30MHz] -min -add_delay 0.000 [get_ports m00_axis_0_tready]
set_input_delay -clock [get_clocks clk_30MHz] -max -add_delay 2.000 [get_ports m00_axis_0_tready]
set_input_delay -clock [get_clocks clk_30MHz] -min -add_delay 0.000 [get_ports reset]
set_input_delay -clock [get_clocks clk_30MHz] -max -add_delay 2.000 [get_ports reset]
set_input_delay -clock [get_clocks clk_30MHz] -min -add_delay 0.000 [get_ports s00_axis_0_tvalid]
set_input_delay -clock [get_clocks clk_30MHz] -max -add_delay 2.000 [get_ports s00_axis_0_tvalid]
set_output_delay -clock [get_clocks clk_30MHz] -min -add_delay 0.000 [get_ports {m00_axis_0_tdata[*]}]
set_output_delay -clock [get_clocks clk_30MHz] -max -add_delay 0.000 [get_ports {m00_axis_0_tdata[*]}]
set_output_delay -clock [get_clocks clk_30MHz] -min -add_delay 0.000 [get_ports m00_axis_0_tlast]
set_output_delay -clock [get_clocks clk_30MHz] -max -add_delay 0.000 [get_ports m00_axis_0_tlast]
set_output_delay -clock [get_clocks clk_30MHz] -min -add_delay 0.000 [get_ports m00_axis_0_tvalid]
set_output_delay -clock [get_clocks clk_30MHz] -max -add_delay 0.000 [get_ports m00_axis_0_tvalid]
set_output_delay -clock [get_clocks clk_30MHz] -min -add_delay 0.000 [get_ports s00_axis_0_tready]
set_output_delay -clock [get_clocks clk_30MHz] -max -add_delay 0.000 [get_ports s00_axis_0_tready]
set_property IOSTANDARD HSLVDCI_15 [get_ports clk_30MHz]



