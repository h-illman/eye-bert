`timescale 1ns/1ps

module native_phy_xcvr #(
  parameter int LOOP_DELAY = 30
) (
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

  logic clk_int = 0;
  always #1.6 clk_int = ~clk_int;
  assign tx_clkout = clk_int;
  assign rx_clkout = clk_int;

  logic [LOOP_DELAY-1:0] pipe;
  logic inject = 0;

  always_ff @(posedge clk_int) begin
    if (reset) pipe <= '0;
    else       pipe <= {pipe[LOOP_DELAY-2:0], tx_parallel_data[0]};
  end
  assign rx_parallel_data[0] = pipe[LOOP_DELAY-1] ^ inject;
  assign tx_serial_data   = tx_parallel_data[0];
  assign tx_serial_data_n = ~tx_parallel_data[0];

  int lock_ctr = 0;
  always_ff @(posedge clk_int) begin
    if (reset) lock_ctr <= 0;
    else if (lock_ctr < 50) lock_ctr <= lock_ctr + 1;
  end
  assign pll_locked         = (lock_ctr >= 20);
  assign rx_is_lockedtodata = (lock_ctr >= 40);
  assign tx_ready           = pll_locked;
  assign rx_ready           = rx_is_lockedtodata;
  assign reconfig_readdata    = '0;
  assign reconfig_waitrequest = 1'b0;

endmodule

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
  assign mgmt_readdata    = xcvr_readdata;
  assign mgmt_waitrequest = xcvr_waitrequest;
  assign xcvr_address     = mgmt_address;
  assign xcvr_read        = mgmt_read;
  assign xcvr_write       = mgmt_write;
  assign xcvr_writedata   = mgmt_writedata;
endmodule
