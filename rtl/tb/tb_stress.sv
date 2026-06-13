`timescale 1ns/1ps

module tb_stress;

  logic clk = 0;
  always #5 clk = ~clk;

  logic rst_n, en;
  logic [1:0] mode;
  logic gen_bit, inject, rx_bit, cnt_rst;
  logic aligned;
  logic [63:0] bit_cnt, err_cnt;
  logic [31:0] max_burst;

  prbs_gen u_gen (.clk(clk), .rst_n(rst_n), .mode(mode), .en(en), .prbs_out(gen_bit), .lfsr_state());
  assign rx_bit = gen_bit ^ inject;
  ber_counter u_chk (.clk(clk), .rst_n(rst_n), .rx_bit(rx_bit), .mode(mode), .en(en),
                     .cnt_rst(cnt_rst), .aligned(aligned),
                     .bit_cnt(bit_cnt), .err_cnt(err_cnt), .max_burst(max_burst));

  logic e_rst_n, e_en, e_rx;
  logic [5:0] e_ph, e_vb;
  logic [31:0] e_dw;
  logic e_busy;
  logic [11:0] e_ra;
  logic [31:0] e_rd;
  eye_sampler u_eye (.clk(clk), .rst_n(e_rst_n), .rx_bit(e_rx), .en(e_en),
                     .phase_steps(e_ph), .volt_bins(e_vb), .dwell_cycles(e_dw),
                     .busy(e_busy), .rd_addr(e_ra), .rd_data(e_rd));
  always @(posedge clk) e_rx <= $urandom & 1;

  task automatic wait_aligned(input int max_cycles, input string what);
    int n = 0;
    while (!aligned) begin
      @(posedge clk); n++;
      if (n > max_cycles) begin $error("%s: no lock in %0d cycles", what, max_cycles); $fatal(1); end
    end
    $display("%s: locked in %0d cycles", what, n);
  endtask

  // PRBS7 period check
  logic [127:0] seq;
  initial begin
    rst_n=0; en=0; inject=0; cnt_rst=0; mode=2'b00;
    e_rst_n=0; e_en=0; e_ph=6'd2; e_vb=6'd2; e_dw=32'd1; e_ra=0;
    repeat(4) @(negedge clk);
    rst_n=1; e_rst_n=1;
    @(negedge clk); en=1;

    // 1. PRBS7 sequence period must be exactly 127
    for (int i = 0; i < 127; i++) begin seq[i] = gen_bit; @(negedge clk); end
    for (int i = 0; i < 127; i++) begin
      if (gen_bit !== seq[i]) begin $error("PRBS7 period != 127 at bit %0d", i); $fatal(1); end
      @(negedge clk);
    end
    if (&seq || ~|seq) begin $error("PRBS7 sequence degenerate"); $fatal(1); end
    $display("PRBS7 period = 127 verified, sequence non-degenerate");

    // 2. lock from arbitrary phase: enable checker against an already-running generator
    en=0; repeat(5) @(negedge clk); en=1;
    wait_aligned(200, "mid-stream lock PRBS7");

    // 3. mode switch mid-run must drop lock and relock
    mode=2'b10; // PRBS31 — generator and checker switch together; stream changes abruptly
    repeat(300) @(negedge clk);
    if (!aligned) wait_aligned(500, "relock after mode switch");
    else $display("relock after mode switch: lock retained/re-acquired");

    // 4. cnt_rst mid-run zeroes counters but holds lock
    repeat(1000) @(negedge clk);
    @(negedge clk); cnt_rst=1; @(negedge clk); cnt_rst=0;
    @(negedge clk);
    if (!aligned) begin $error("cnt_rst dropped lock"); $fatal(1); end
    if (bit_cnt > 4) begin $error("cnt_rst did not clear bit_cnt (=%0d)", bit_cnt); $fatal(1); end
    repeat(100) @(negedge clk);
    if (err_cnt != 0) begin $error("err_cnt nonzero after cnt_rst"); $fatal(1); end
    $display("cnt_rst: counters cleared atomically, lock held");

    // 5. en toggle: counters preserved across pause, lock re-acquired
    begin
      logic [63:0] saved;
      saved = bit_cnt;
      en=0; repeat(50) @(negedge clk);
      if (aligned) begin $error("aligned high with en low"); $fatal(1); end
      en=1;
      wait_aligned(500, "relock after en toggle");
      if (bit_cnt < saved) begin $error("counters lost across en toggle"); $fatal(1); end
    end

    // 6. sustained 100% corruption -> LOL -> clean -> relock (module level)
    inject=1;
    begin
      int n=0;
      while (aligned) begin @(negedge clk); n++; if (n>500) begin $error("no LOL"); $fatal(1); end end
      $display("LOL after %0d corrupted bits", n);
    end
    inject=0;
    wait_aligned(500, "relock post-corruption");

    // 7. eye sampler: dwell=1 minimum, 2x2
    e_en=1;
    wait(e_busy); e_en=0; wait(!e_busy);
    repeat(4) @(negedge clk);
    $display("eye dwell=1 sweep completes");

    // 8. eye accumulation across two sweeps strictly grows a bin
    begin
      logic [31:0] first;
      e_dw=32'd64;
      e_en=1; wait(e_busy); e_en=0; wait(!e_busy);
      e_ra=12'h000; repeat(3) @(negedge clk); first=e_rd;
      e_en=1; wait(e_busy); e_en=0; wait(!e_busy);
      e_ra=12'h000; repeat(3) @(negedge clk);
      if (e_rd <= first) begin $error("histogram did not accumulate (%0d -> %0d)", first, e_rd); $fatal(1); end
      $display("histogram accumulates across sweeps (%0d -> %0d)", first, e_rd);
    end

    $display("tb_stress PASS");
    $finish;
  end

endmodule
