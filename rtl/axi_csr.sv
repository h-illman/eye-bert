module axi_csr (
  input  logic        clk,
  input  logic        resetn,

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
  input  logic        s_axi_rready,

  output logic        bert_en,
  output logic        cnt_rst,
  output logic        loopback_en,
  output logic        eye_en,
  output logic [1:0]  prbs_mode,
  output logic [4:0]  tx_swing,
  output logic [4:0]  tx_pre,
  output logic [4:0]  tx_post,
  output logic [4:0]  ctle_gain,
  output logic [4:0]  vga_gain,
  output logic [5:0]  phase_steps,
  output logic [5:0]  volt_bins,
  output logic [31:0] dwell_cycles,
  output logic        snap_trig,

  input  logic        pll_lock,
  input  logic        rx_aligned,
  input  logic        bert_active,
  input  logic        eye_busy,
  input  logic        snap_busy,
  input  logic [63:0] bit_cnt,
  input  logic [63:0] err_cnt,
  input  logic [31:0] max_burst,
  output logic [11:0] eye_rd_addr,
  input  logic [31:0] eye_rd_data
);

  localparam logic [7:0] A_CTRL     = 8'h00;
  localparam logic [7:0] A_TX_CFG   = 8'h04;
  localparam logic [7:0] A_RX_CFG   = 8'h08;
  localparam logic [7:0] A_EYE_CFG  = 8'h0C;
  localparam logic [7:0] A_DWELL    = 8'h10;
  localparam logic [7:0] A_SNAP     = 8'h14;
  localparam logic [7:0] A_STATUS   = 8'h40;
  localparam logic [7:0] A_BIT_LO   = 8'h44;
  localparam logic [7:0] A_BIT_HI   = 8'h48;
  localparam logic [7:0] A_ERR_LO   = 8'h4C;
  localparam logic [7:0] A_ERR_HI   = 8'h50;
  localparam logic [7:0] A_BURST    = 8'h54;
  localparam logic [7:0] A_EYE_ADDR = 8'h58;
  localparam logic [7:0] A_EYE_DATA = 8'h5C;

  logic [7:0] waddr_q, raddr_q;
  logic [31:0] wv;
  logic       aw_hs, w_hs, wr_pend_a, wr_pend_d;
  logic [31:0] wdata_q;
  logic [3:0]  wstrb_q;
  logic        do_write;

  assign aw_hs = s_axi_awvalid & s_axi_awready;
  assign w_hs  = s_axi_wvalid  & s_axi_wready;

  always_ff @(posedge clk or negedge resetn) begin
    if (!resetn) begin
      s_axi_awready <= 1'b1;
      s_axi_wready  <= 1'b1;
      s_axi_bvalid  <= 1'b0;
      wr_pend_a     <= 1'b0;
      wr_pend_d     <= 1'b0;
      waddr_q       <= '0;
      wdata_q       <= '0;
      wstrb_q       <= '0;
    end else begin
      if (aw_hs) begin
        waddr_q       <= s_axi_awaddr[7:0];
        wr_pend_a     <= 1'b1;
        s_axi_awready <= 1'b0;
      end
      if (w_hs) begin
        wdata_q      <= s_axi_wdata;
        wstrb_q      <= s_axi_wstrb;
        wr_pend_d    <= 1'b1;
        s_axi_wready <= 1'b0;
      end
      if (do_write) begin
        s_axi_bvalid <= 1'b1;
        wr_pend_a    <= 1'b0;
        wr_pend_d    <= 1'b0;
      end
      if (s_axi_bvalid & s_axi_bready) begin
        s_axi_bvalid  <= 1'b0;
        s_axi_awready <= 1'b1;
        s_axi_wready  <= 1'b1;
      end
    end
  end

  assign do_write    = wr_pend_a & wr_pend_d & ~s_axi_bvalid;
  assign s_axi_bresp = 2'b00;

  function automatic logic [31:0] strb_merge(logic [31:0] old, logic [31:0] nw, logic [3:0] strb);
    for (int i = 0; i < 4; i++) strb_merge[8*i +: 8] = strb[i] ? nw[8*i +: 8] : old[8*i +: 8];
  endfunction

  always_ff @(posedge clk or negedge resetn) begin
    if (!resetn) begin
      bert_en      <= 1'b0;
      cnt_rst      <= 1'b0;
      loopback_en  <= 1'b0;
      eye_en       <= 1'b0;
      prbs_mode    <= 2'b00;
      tx_swing     <= 5'h0F;
      tx_pre       <= 5'h00;
      tx_post      <= 5'h00;
      ctle_gain    <= 5'h08;
      vga_gain     <= 5'h04;
      phase_steps  <= 6'd32;
      volt_bins    <= 6'd32;
      dwell_cycles <= 32'd1000000;
      eye_rd_addr  <= '0;
      snap_trig    <= 1'b0;
    end else begin
      cnt_rst   <= 1'b0;
      snap_trig <= 1'b0;
      if (do_write) begin
        unique case (waddr_q)
          A_CTRL: begin
            wv = strb_merge({26'b0, prbs_mode, eye_en, loopback_en, 1'b0, bert_en}, wdata_q, wstrb_q);
            bert_en     <= wv[0];
            cnt_rst     <= wv[1];
            loopback_en <= wv[2];
            eye_en      <= wv[3];
            prbs_mode   <= wv[5:4];
          end
          A_TX_CFG: begin
            wv = strb_merge({17'b0, tx_post, tx_pre, tx_swing}, wdata_q, wstrb_q);
            tx_swing <= wv[4:0];
            tx_pre   <= wv[9:5];
            tx_post  <= wv[14:10];
          end
          A_RX_CFG: begin
            wv = strb_merge({22'b0, vga_gain, ctle_gain}, wdata_q, wstrb_q);
            ctle_gain <= wv[4:0];
            vga_gain  <= wv[9:5];
          end
          A_EYE_CFG: begin
            wv = strb_merge({20'b0, volt_bins, phase_steps}, wdata_q, wstrb_q);
            phase_steps <= wv[5:0];
            volt_bins   <= wv[11:6];
          end
          A_DWELL:    dwell_cycles <= strb_merge(dwell_cycles, wdata_q, wstrb_q);
          A_SNAP:     snap_trig    <= 1'b1;
          A_EYE_ADDR: eye_rd_addr  <= strb_merge({20'b0, eye_rd_addr}, wdata_q, wstrb_q);
          default: ;
        endcase
      end
    end
  end

  always_ff @(posedge clk or negedge resetn) begin
    if (!resetn) begin
      s_axi_arready <= 1'b1;
      s_axi_rvalid  <= 1'b0;
      s_axi_rdata   <= '0;
      raddr_q       <= '0;
    end else begin
      if (s_axi_arvalid & s_axi_arready) begin
        raddr_q       <= s_axi_araddr[7:0];
        s_axi_arready <= 1'b0;
        s_axi_rvalid  <= 1'b1;
        unique case (s_axi_araddr[7:0])
          A_CTRL:     s_axi_rdata <= {26'b0, prbs_mode, eye_en, loopback_en, 1'b0, bert_en};
          A_TX_CFG:   s_axi_rdata <= {17'b0, tx_post, tx_pre, tx_swing};
          A_RX_CFG:   s_axi_rdata <= {22'b0, vga_gain, ctle_gain};
          A_EYE_CFG:  s_axi_rdata <= {20'b0, volt_bins, phase_steps};
          A_DWELL:    s_axi_rdata <= dwell_cycles;
          A_STATUS:   s_axi_rdata <= {27'b0, snap_busy, eye_busy, bert_active, rx_aligned, pll_lock};
          A_BIT_LO:   s_axi_rdata <= bit_cnt[31:0];
          A_BIT_HI:   s_axi_rdata <= bit_cnt[63:32];
          A_ERR_LO:   s_axi_rdata <= err_cnt[31:0];
          A_ERR_HI:   s_axi_rdata <= err_cnt[63:32];
          A_BURST:    s_axi_rdata <= max_burst;
          A_EYE_ADDR: s_axi_rdata <= {20'b0, eye_rd_addr};
          A_EYE_DATA: s_axi_rdata <= eye_rd_data;
          default:    s_axi_rdata <= 32'hDEAD_BEEF;
        endcase
      end
      if (s_axi_rvalid & s_axi_rready) begin
        s_axi_rvalid  <= 1'b0;
        s_axi_arready <= 1'b1;
      end
    end
  end

  assign s_axi_rresp = 2'b00;

endmodule
