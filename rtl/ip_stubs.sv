(* black_box *)
module native_phy_xcvr (
  input  logic        tx_pll_refclk,
  input  logic        rx_cdr_refclk,
  input  logic        reset,
  input  logic        tx_coreclkin,
  input  logic        rx_coreclkin,
  output logic        tx_clkout,
  output logic        rx_clkout,
  input  logic [0:0]  tx_parallel_data,
  output logic [0:0]  rx_parallel_data,
  output logic        tx_serial_data,
  input  logic        rx_serial_data,
  output logic        tx_serial_data_n,
  input  logic        rx_serial_data_n,
  input  logic        rx_seriallpbken,
  output logic        pll_locked,
  output logic        tx_ready,
  output logic        rx_ready,
  output logic        rx_is_lockedtodata,
  input  logic [9:0]  reconfig_address,
  input  logic        reconfig_read,
  input  logic        reconfig_write,
  input  logic [31:0] reconfig_writedata,
  output logic [31:0] reconfig_readdata,
  output logic        reconfig_waitrequest
);
endmodule

(* black_box *)
module xcvr_reconfig_ctrl (
  input  logic        mgmt_clk,
  input  logic        mgmt_resetn,
  input  logic [9:0]  mgmt_address,
  input  logic        mgmt_read,
  input  logic        mgmt_write,
  input  logic [31:0] mgmt_writedata,
  output logic [31:0] mgmt_readdata,
  output logic        mgmt_waitrequest,
  output logic [9:0]  xcvr_address,
  output logic        xcvr_read,
  output logic        xcvr_write,
  output logic [31:0] xcvr_writedata,
  input  logic [31:0] xcvr_readdata,
  input  logic        xcvr_waitrequest
);
endmodule

