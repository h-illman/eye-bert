`timescale 1ns/1ps

module tb_bert_top;

  logic clk = 0, resetn;
  always #5 clk = ~clk;

  logic [31:0] awaddr, wdata, araddr, rdata_w;
  logic awvalid, awready, wvalid, wready, bvalid, bready, arvalid, arready, rvalid, rready;
  logic [3:0]  wstrb;
  logic [1:0]  bresp, rresp;
  logic [31:0] rdata;
  logic tx_p, tx_n;

  bert_top dut (
    .hps_clk(clk), .hps_resetn(resetn),
    .xcvr_refclk_p(1'b0), .xcvr_refclk_n(1'b1),
    .tx_serial_p(tx_p), .tx_serial_n(tx_n),
    .rx_serial_p(tx_p), .rx_serial_n(tx_n),
    .s_axi_awaddr(awaddr), .s_axi_awvalid(awvalid), .s_axi_awready(awready),
    .s_axi_wdata(wdata), .s_axi_wstrb(wstrb), .s_axi_wvalid(wvalid), .s_axi_wready(wready),
    .s_axi_bresp(bresp), .s_axi_bvalid(bvalid), .s_axi_bready(bready),
    .s_axi_araddr(araddr), .s_axi_arvalid(arvalid), .s_axi_arready(arready),
    .s_axi_rdata(rdata), .s_axi_rresp(rresp), .s_axi_rvalid(rvalid), .s_axi_rready(rready)
  );

  task automatic wr(input [31:0] a, input [31:0] d);
    @(negedge clk); awaddr=a; awvalid=1; wdata=d; wstrb=4'hF; wvalid=1;
    wait(bvalid); @(negedge clk); awvalid=0; wvalid=0; bready=1;
    @(negedge clk); bready=0;
  endtask

  task automatic rd(input [31:0] a, output [31:0] d);
    @(negedge clk); araddr=a; arvalid=1;
    wait(rvalid); d=rdata; @(negedge clk); arvalid=0; rready=1;
    @(negedge clk); rready=0;
  endtask

  task automatic snapshot(output [63:0] bits, output [63:0] errs, output [31:0] burst);
    logic [31:0] s, lo, hi;
    wr(32'h14, 32'h1);
    do rd(32'h40, s); while (s[4]);
    rd(32'h44, lo); rd(32'h48, hi); bits = {hi, lo};
    rd(32'h4C, lo); rd(32'h50, hi); errs = {hi, lo};
    rd(32'h54, burst);
  endtask

  logic [31:0] v;
  logic [63:0] b0, e0, b1, e1;
  logic [31:0] mb;
  int timeout;

  initial begin
    resetn=0; awvalid=0; wvalid=0; bready=0; arvalid=0; rready=0;
    repeat(10) @(negedge clk); resetn=1;
    repeat(10) @(negedge clk);

    // bring-up: PRBS31, enable BERT, wait for PLL lock then alignment
    wr(32'h00, 32'h0000_0021);
    timeout = 0;
    do begin rd(32'h40, v); timeout++; if (timeout > 5000) begin $error("no pll_lock"); $fatal(1); end end while (!v[0]);
    $display("pll_lock observed");
    timeout = 0;
    do begin rd(32'h40, v); timeout++; if (timeout > 5000) begin $error("no rx_aligned"); $fatal(1); end end while (!v[1]);
    $display("rx_aligned through serial loopback (delay=30 bits)");

    // clean counting via snapshot handshake
    wr(32'h00, 32'h0000_0023);  // cnt_rst pulse, keep en+prbs31
    repeat(2000) @(negedge clk);
    snapshot(b0, e0, mb);
    if (b0 == 0)  begin $error("snapshot bits==0"); $fatal(1); end
    if (e0 != 0)  begin $error("snapshot errs=%0d expected 0", e0); $fatal(1); end
    $display("clean run: bits=%0d errs=0", b0);

    // snapshot atomicity: two snapshots must be monotonic
    snapshot(b1, e1, mb);
    if (b1 <= b0) begin $error("counter not monotonic across snapshots"); $fatal(1); end

    // inject 5 errors in the PHY model, verify exact count
    repeat(5) begin
      @(negedge dut.u_native_phy.clk_int); dut.u_native_phy.inject = 1;
      @(negedge dut.u_native_phy.clk_int); dut.u_native_phy.inject = 0;
      repeat(10) @(negedge dut.u_native_phy.clk_int);
    end
    repeat(100) @(negedge clk);
    snapshot(b1, e1, mb);
    if (e1 != 5)  begin $error("errs=%0d expected 5", e1); $fatal(1); end
    if (mb != 1)  begin $error("max_burst=%0d expected 1", mb); $fatal(1); end
    $display("error injection through full stack: errs=5 max_burst=1");

    // loss of lock: hold inject (rx = inverted-ish garbage), expect aligned drop, then relock
    dut.u_native_phy.inject = 1;
    timeout = 0;
    do begin rd(32'h40, v); timeout++; if (timeout > 5000) begin $error("no loss of lock"); $fatal(1); end end while (v[1]);
    $display("loss of lock detected under sustained corruption");
    dut.u_native_phy.inject = 0;
    timeout = 0;
    do begin rd(32'h40, v); timeout++; if (timeout > 5000) begin $error("no relock"); $fatal(1); end end while (!v[1]);
    $display("relock after corruption removed");

    // eye sweep through CSR: 2x2 raster, dwell 64
    wr(32'h0C, {20'b0, 6'd2, 6'd2});
    wr(32'h10, 32'd64);
    wr(32'h00, 32'h0000_0029);  // eye_en + bert_en
    timeout = 0;
    do begin rd(32'h40, v); timeout++; if (timeout > 5000) begin $error("eye never busy"); $fatal(1); end end while (!v[3]);
    wr(32'h00, 32'h0000_0021);  // drop eye_en, single sweep
    timeout = 0;
    do begin rd(32'h40, v); timeout++; if (timeout > 20000) begin $error("eye stuck busy"); $fatal(1); end end while (v[3]);
    for (int p = 0; p < 2; p++)
      for (int q = 0; q < 2; q++) begin
        wr(32'h58, (p << 6) | q);
        rd(32'h5C, v);
        if (v == 0) begin $error("eye bin [%0d][%0d] zero", p, q); $fatal(1); end
      end
    $display("eye sweep via CSR: 4/4 bins populated");

    $display("tb_bert_top PASS");
    $finish;
  end

endmodule
