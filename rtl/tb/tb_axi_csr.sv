`timescale 1ns/1ps
module tb_axi_csr;
  logic clk=0, resetn;
  always #5 clk=~clk;
  logic [31:0] awaddr, wdata, araddr, rdata;
  logic awvalid, awready, wvalid, wready, bvalid, bready, arvalid, arready, rvalid, rready;
  logic [3:0] wstrb;
  logic [1:0] bresp, rresp;
  logic bert_en, cnt_rst, loopback_en, eye_en, snap_trig;
  logic [1:0] prbs_mode;
  logic [4:0] tx_swing, tx_pre, tx_post, ctle_gain, vga_gain;
  logic [5:0] phase_steps, volt_bins;
  logic [31:0] dwell_cycles;
  logic [11:0] eye_rd_addr;

  axi_csr dut (
    .clk(clk), .resetn(resetn),
    .s_axi_awaddr(awaddr), .s_axi_awvalid(awvalid), .s_axi_awready(awready),
    .s_axi_wdata(wdata), .s_axi_wstrb(wstrb), .s_axi_wvalid(wvalid), .s_axi_wready(wready),
    .s_axi_bresp(bresp), .s_axi_bvalid(bvalid), .s_axi_bready(bready),
    .s_axi_araddr(araddr), .s_axi_arvalid(arvalid), .s_axi_arready(arready),
    .s_axi_rdata(rdata), .s_axi_rresp(rresp), .s_axi_rvalid(rvalid), .s_axi_rready(rready),
    .bert_en(bert_en), .cnt_rst(cnt_rst), .loopback_en(loopback_en), .eye_en(eye_en),
    .prbs_mode(prbs_mode), .tx_swing(tx_swing), .tx_pre(tx_pre), .tx_post(tx_post),
    .ctle_gain(ctle_gain), .vga_gain(vga_gain), .phase_steps(phase_steps), .volt_bins(volt_bins),
    .dwell_cycles(dwell_cycles), .snap_trig(snap_trig),
    .pll_lock(1'b1), .rx_aligned(1'b1), .bert_active(bert_en), .eye_busy(1'b0), .snap_busy(1'b0),
    .bit_cnt(64'h1122334455667788), .err_cnt(64'h00000000000000AA), .max_burst(32'd7),
    .eye_rd_addr(eye_rd_addr), .eye_rd_data(32'hCAFE0001));

  task automatic wr(input [31:0] a, input [31:0] d, input [3:0] strb = 4'hF);
    @(negedge clk); awaddr=a; awvalid=1; wdata=d; wstrb=strb; wvalid=1;
    wait(bvalid); @(negedge clk); awvalid=0; wvalid=0; bready=1;
    @(negedge clk); bready=0;
  endtask
  task automatic rd(input [31:0] a, output [31:0] d);
    @(negedge clk); araddr=a; arvalid=1;
    wait(rvalid); d=rdata; @(negedge clk); arvalid=0; rready=1;
    @(negedge clk); rready=0;
  endtask

  logic [31:0] v;
  logic saw_cnt_rst=0, saw_snap=0;
  always @(posedge clk) begin
    if (cnt_rst) saw_cnt_rst<=1;
    if (snap_trig) saw_snap<=1;
  end

  initial begin
    resetn=0; awvalid=0; wvalid=0; bready=0; arvalid=0; rready=0;
    repeat(4) @(negedge clk); resetn=1;

    rd(32'h10, v); if (v !== 32'd1000000) begin $error("DWELL reset %h", v); $fatal(1); end
    rd(32'h04, v); if (v !== 32'h0000000F) begin $error("TX_CFG reset %h", v); $fatal(1); end
    $display("reset values verified");

    wr(32'h00, 32'h0000_0017);
    if (bert_en!==1 || loopback_en!==1 || prbs_mode!==2'b01) begin $error("CTRL fields"); $fatal(1); end
    rd(32'h00, v); if (v[0]!==1'b1 || v[5:4]!==2'b01) begin $error("CTRL readback %h", v); $fatal(1); end

    wr(32'h00, 32'h0000_0002);
    repeat(3) @(posedge clk); #1;
    if (!saw_cnt_rst) begin $error("cnt_rst not pulsed"); $fatal(1); end
    if (cnt_rst!==1'b0) begin $error("cnt_rst stuck"); $fatal(1); end
    $display("cnt_rst one-cycle pulse verified");

    wr(32'h14, 32'h1);
    repeat(3) @(posedge clk); #1;
    if (!saw_snap) begin $error("snap_trig not pulsed"); $fatal(1); end
    if (snap_trig!==1'b0) begin $error("snap_trig stuck"); $fatal(1); end
    $display("snap_trig one-cycle pulse verified");

    wr(32'h04, {17'b0, 5'd3, 5'd2, 5'd31});
    if (tx_swing!==5'd31 || tx_pre!==5'd2 || tx_post!==5'd3) begin $error("TX_CFG"); $fatal(1); end

    // byte-strobe partial write: only byte 0 of DWELL
    wr(32'h10, 32'hFFFF_FF42, 4'b0001);
    rd(32'h10, v);
    if (v !== ((32'd1000000 & 32'hFFFFFF00) | 32'h42)) begin $error("strobe write %h", v); $fatal(1); end
    $display("byte-strobe partial write verified");

    rd(32'h44, v); if (v!==32'h55667788) begin $error("BIT_LO %h", v); $fatal(1); end
    rd(32'h48, v); if (v!==32'h11223344) begin $error("BIT_HI %h", v); $fatal(1); end
    rd(32'h54, v); if (v!==32'd7) begin $error("BURST %h", v); $fatal(1); end
    rd(32'h40, v); if (v[1:0]!==2'b11 || v[2]!==bert_en) begin $error("STATUS %h", v); $fatal(1); end

    wr(32'h58, 32'h0000_0ABC);
    if (eye_rd_addr!==12'hABC) begin $error("EYE_ADDR"); $fatal(1); end
    rd(32'h5C, v); if (v!==32'hCAFE0001) begin $error("EYE_DATA %h", v); $fatal(1); end

    // back-to-back transactions
    for (int i = 0; i < 8; i++) begin
      wr(32'h08, i);
      rd(32'h08, v);
      if (v[4:0] !== i[4:0]) begin $error("b2b iteration %0d: %h", i, v); $fatal(1); end
    end
    $display("8 back-to-back write/read pairs verified");

    rd(32'hF0, v); if (v!==32'hDEAD_BEEF) begin $error("unmapped read %h", v); $fatal(1); end
    $display("unmapped address returns sentinel");

    $display("tb_axi_csr PASS");
    $finish;
  end
endmodule
