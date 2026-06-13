# Eyebert timing constraints

create_clock -name xcvr_refclk -period 6.400 [get_ports xcvr_refclk_p]
create_clock -name hps_clk     -period 10.000 [get_ports hps_clk]

create_generated_clock -name xcvr_rx_clk \
    -source [get_ports xcvr_refclk_p] \
    [get_pins u_native_phy|rx_clkout]

create_generated_clock -name xcvr_tx_clk \
    -source [get_ports xcvr_refclk_p] \
    [get_pins u_native_phy|tx_clkout]

set_clock_groups -asynchronous \
    -group [get_clocks hps_clk] \
    -group [get_clocks {xcvr_rx_clk xcvr_tx_clk xcvr_refclk}]

set_false_path -from [get_ports hps_resetn]
set_false_path -to [get_registers *rstn_x_s*]

set_output_delay -clock xcvr_tx_clk -max 0.5 [get_ports {tx_serial_p tx_serial_n}]
set_output_delay -clock xcvr_tx_clk -min -0.5 [get_ports {tx_serial_p tx_serial_n}]
set_input_delay  -clock xcvr_rx_clk -max 0.5 [get_ports {rx_serial_p rx_serial_n}]
set_input_delay  -clock xcvr_rx_clk -min -0.5 [get_ports {rx_serial_p rx_serial_n}]
