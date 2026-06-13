module bert_top (
  input  logic        hps_clk,
  input  logic        hps_resetn,
  input  logic        xcvr_refclk_p,
  input  logic        xcvr_refclk_n,
  output logic        tx_serial_p,
  output logic        tx_serial_n,
  input  logic        rx_serial_p,
  input  logic        rx_serial_n,

  input  logic [31:0] s_axi_awaddr,
  input  logic        s_axi_awvalid,
  output logic        s_axi_awready,
  input  logic [31:0] s_axi_wdata,
  input  logic [3:0]  s_axi_wstrb,
  input  logic        s_axi_wvalid,
  output logic        s_axi_wready,
  output logic [1:0]  s_axi_bresp,
  output logic        s_axi_bvalid,
  input  logic        s_axi_bready,
  input  logic [31:0] s_axi_araddr,
  input  logic        s_axi_arvalid,
  output logic        s_axi_arready,
  output logic [31:0] s_axi_rdata,
  output logic [1:0]  s_axi_rresp,
  output logic        s_axi_rvalid,
  input  logic        s_axi_rready
);

  logic xcvr_rx_clk, xcvr_tx_clk;
  logic pll_lock_phy, rx_lockedtodata;
  logic prbs_tx_bit, rx_bit;

  logic        bert_en_h, cnt_rst_h, loopback_en_h, eye_en_h;
  logic [1:0]  prbs_mode_h;
  logic [4:0]  tx_swing_h, tx_pre_h, tx_post_h, ctle_gain_h, vga_gain_h;
  logic [5:0]  phase_steps_h, volt_bins_h;
  logic [31:0] dwell_cycles_h;
  logic [11:0] eye_rd_addr_h;

  logic        aligned_x, eye_busy_x;
  logic [63:0] bit_cnt_x, err_cnt_x;
  logic [31:0] max_burst_x;
  logic [31:0] eye_rd_data_x;

  // hps_clk -> xcvr_rx_clk config synchronizers (2FF, quasi-static)
  logic [1:0]  bert_en_s, cnt_rst_s, eye_en_s;
  logic [1:0]  prbs_mode_s [1:0];
  logic [5:0]  phase_steps_s [1:0];
  logic [5:0]  volt_bins_s [1:0];
  logic [31:0] dwell_cycles_s [1:0];
  logic [11:0] eye_rd_addr_s [1:0];
  logic        cnt_rst_x_q, cnt_rst_pulse;

  always_ff @(posedge xcvr_rx_clk) begin
    bert_en_s         <= {bert_en_s[0], bert_en_h};
    cnt_rst_s         <= {cnt_rst_s[0], cnt_rst_h};
    eye_en_s          <= {eye_en_s[0],  eye_en_h};
    prbs_mode_s[1]    <= prbs_mode_s[0];    prbs_mode_s[0]    <= prbs_mode_h;
    phase_steps_s[1]  <= phase_steps_s[0];  phase_steps_s[0]  <= phase_steps_h;
    volt_bins_s[1]    <= volt_bins_s[0];    volt_bins_s[0]    <= volt_bins_h;
    dwell_cycles_s[1] <= dwell_cycles_s[0]; dwell_cycles_s[0] <= dwell_cycles_h;
    eye_rd_addr_s[1]  <= eye_rd_addr_s[0];  eye_rd_addr_s[0]  <= eye_rd_addr_h;
    cnt_rst_x_q       <= cnt_rst_s[1];
  end
  assign cnt_rst_pulse = cnt_rst_s[1] & ~cnt_rst_x_q;

  // xcvr_rx_clk -> hps_clk status synchronizers
  logic [1:0]  pll_lock_s, aligned_s, eye_busy_s;
  logic [31:0] eye_rd_data_s [1:0];

  always_ff @(posedge hps_clk) begin
    pll_lock_s       <= {pll_lock_s[0], pll_lock_phy};
    aligned_s        <= {aligned_s[0],  aligned_x};
    eye_busy_s       <= {eye_busy_s[0], eye_busy_x};
    eye_rd_data_s[1] <= eye_rd_data_s[0]; eye_rd_data_s[0] <= eye_rd_data_x;
  end

  // counter snapshot: req/ack toggle handshake, data stable by protocol
  logic        snap_trig_h, snap_busy_h, req_tgl_h;
  logic [1:0]  ack_sync_h;
  logic        ack_seen_h;
  logic [63:0] bit_snap_h, err_snap_h;
  logic [31:0] burst_snap_h;
  logic [1:0]  req_sync_x;
  logic        req_seen_x, ack_tgl_x;
  logic [63:0] bit_snap_x, err_snap_x;
  logic [31:0] burst_snap_x;

  always_ff @(posedge hps_clk or negedge hps_resetn) begin
    if (!hps_resetn) begin
      req_tgl_h   <= 1'b0;
      snap_busy_h <= 1'b0;
      ack_sync_h  <= '0;
      ack_seen_h  <= 1'b0;
      bit_snap_h  <= '0;
      err_snap_h  <= '0;
      burst_snap_h<= '0;
    end else begin
      ack_sync_h <= {ack_sync_h[0], ack_tgl_x};
      ack_seen_h <= ack_sync_h[1];
      if (snap_trig_h & ~snap_busy_h) begin
        req_tgl_h   <= ~req_tgl_h;
        snap_busy_h <= 1'b1;
      end
      if (ack_sync_h[1] ^ ack_seen_h) begin
        bit_snap_h   <= bit_snap_x;
        err_snap_h   <= err_snap_x;
        burst_snap_h <= burst_snap_x;
        snap_busy_h  <= 1'b0;
      end
    end
  end

  always_ff @(posedge xcvr_rx_clk or negedge rstn_x) begin
    if (!rstn_x) begin
      req_sync_x <= '0;
      req_seen_x <= 1'b0;
      ack_tgl_x  <= 1'b0;
      bit_snap_x <= '0;
      err_snap_x <= '0;
      burst_snap_x <= '0;
    end else begin
      req_sync_x <= {req_sync_x[0], req_tgl_h};
      req_seen_x <= req_sync_x[1];
      if (req_sync_x[1] ^ req_seen_x) begin
        bit_snap_x   <= bit_cnt_x;
        err_snap_x   <= err_cnt_x;
        burst_snap_x <= max_burst_x;
        ack_tgl_x    <= ~ack_tgl_x;
      end
    end
  end

  // reset sync into recovered clock domain
  logic [1:0] rstn_x_s;
  logic       rstn_x;
  always_ff @(posedge xcvr_rx_clk or negedge hps_resetn) begin
    if (!hps_resetn) rstn_x_s <= 2'b00;
    else             rstn_x_s <= {rstn_x_s[0], 1'b1};
  end
  assign rstn_x = rstn_x_s[1];

  logic [9:0]  reconfig_addr;
  logic        reconfig_rd, reconfig_wr, reconfig_wait;
  logic [31:0] reconfig_wdata, reconfig_rdata;

  prbs_gen u_prbs_gen (
    .clk        (xcvr_rx_clk),
    .rst_n      (rstn_x),
    .mode       (prbs_mode_s[1]),
    .en         (bert_en_s[1]),
    .prbs_out   (prbs_tx_bit),
    .lfsr_state ()
  );

  ber_counter u_ber_counter (
    .clk       (xcvr_rx_clk),
    .rst_n     (rstn_x),
    .rx_bit    (rx_bit),
    .mode      (prbs_mode_s[1]),
    .en        (bert_en_s[1]),
    .cnt_rst   (cnt_rst_pulse),
    .aligned   (aligned_x),
    .bit_cnt   (bit_cnt_x),
    .err_cnt   (err_cnt_x),
    .max_burst (max_burst_x)
  );

  eye_sampler u_eye_sampler (
    .clk          (xcvr_rx_clk),
    .rst_n        (rstn_x),
    .rx_bit       (rx_bit),
    .en           (eye_en_s[1]),
    .phase_steps  (phase_steps_s[1]),
    .volt_bins    (volt_bins_s[1]),
    .dwell_cycles (dwell_cycles_s[1]),
    .busy         (eye_busy_x),
    .rd_addr      (eye_rd_addr_s[1]),
    .rd_data      (eye_rd_data_x)
  );

  axi_csr u_axi_csr (
    .clk           (hps_clk),
    .resetn        (hps_resetn),
    .s_axi_awaddr  (s_axi_awaddr),
    .s_axi_awvalid (s_axi_awvalid),
    .s_axi_awready (s_axi_awready),
    .s_axi_wdata   (s_axi_wdata),
    .s_axi_wstrb   (s_axi_wstrb),
    .s_axi_wvalid  (s_axi_wvalid),
    .s_axi_wready  (s_axi_wready),
    .s_axi_bresp   (s_axi_bresp),
    .s_axi_bvalid  (s_axi_bvalid),
    .s_axi_bready  (s_axi_bready),
    .s_axi_araddr  (s_axi_araddr),
    .s_axi_arvalid (s_axi_arvalid),
    .s_axi_arready (s_axi_arready),
    .s_axi_rdata   (s_axi_rdata),
    .s_axi_rresp   (s_axi_rresp),
    .s_axi_rvalid  (s_axi_rvalid),
    .s_axi_rready  (s_axi_rready),
    .bert_en       (bert_en_h),
    .cnt_rst       (cnt_rst_h),
    .loopback_en   (loopback_en_h),
    .eye_en        (eye_en_h),
    .prbs_mode     (prbs_mode_h),
    .tx_swing      (tx_swing_h),
    .tx_pre        (tx_pre_h),
    .tx_post       (tx_post_h),
    .ctle_gain     (ctle_gain_h),
    .vga_gain      (vga_gain_h),
    .phase_steps   (phase_steps_h),
    .volt_bins     (volt_bins_h),
    .dwell_cycles  (dwell_cycles_h),
    .snap_trig     (snap_trig_h),
    .pll_lock      (pll_lock_s[1]),
    .rx_aligned    (aligned_s[1]),
    .bert_active   (bert_en_h),
    .eye_busy      (eye_busy_s[1]),
    .snap_busy     (snap_busy_h),
    .bit_cnt       (bit_snap_h),
    .err_cnt       (err_snap_h),
    .max_burst     (burst_snap_h),
    .eye_rd_addr   (eye_rd_addr_h),
    .eye_rd_data   (eye_rd_data_s[1])
  );

  native_phy_xcvr u_native_phy (
    .tx_pll_refclk        (xcvr_refclk_p),
    .rx_cdr_refclk        (xcvr_refclk_p),
    .reset                (~hps_resetn),
    .tx_coreclkin         (xcvr_tx_clk),
    .rx_coreclkin         (xcvr_rx_clk),
    .tx_clkout            (xcvr_tx_clk),
    .rx_clkout            (xcvr_rx_clk),
    .tx_parallel_data     (prbs_tx_bit),
    .rx_parallel_data     (rx_bit),
    .tx_serial_data       (tx_serial_p),
    .rx_serial_data       (rx_serial_p),
    .tx_serial_data_n     (tx_serial_n),
    .rx_serial_data_n     (rx_serial_n),
    .rx_seriallpbken      (loopback_en_h),
    .pll_locked           (pll_lock_phy),
    .tx_ready             (),
    .rx_ready             (),
    .rx_is_lockedtodata   (rx_lockedtodata),
    .reconfig_address     (reconfig_addr),
    .reconfig_read        (reconfig_rd),
    .reconfig_write       (reconfig_wr),
    .reconfig_writedata   (reconfig_wdata),
    .reconfig_readdata    (reconfig_rdata),
    .reconfig_waitrequest (reconfig_wait)
  );

  xcvr_reconfig_ctrl u_xcvr_reconfig (
    .mgmt_clk         (hps_clk),
    .mgmt_resetn      (hps_resetn),
    .mgmt_address     ('0),
    .mgmt_read        (1'b0),
    .mgmt_write       (1'b0),
    .mgmt_writedata   ('0),
    .mgmt_readdata    (),
    .mgmt_waitrequest (),
    .xcvr_address     (reconfig_addr),
    .xcvr_read        (reconfig_rd),
    .xcvr_write       (reconfig_wr),
    .xcvr_writedata   (reconfig_wdata),
    .xcvr_readdata    (reconfig_rdata),
    .xcvr_waitrequest (reconfig_wait)
  );

endmodule
