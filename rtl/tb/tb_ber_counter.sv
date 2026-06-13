`timescale 1ns/1ps

module tb_ber_counter;

  logic        clk = 0;
  logic        rst_n;
  logic [1:0]  mode = 2'b10;
  logic        en;
  logic        gen_bit;
  logic        inject;
  logic        rx_bit;
  logic        cnt_rst = 0;
  logic        aligned;
  logic [63:0] bit_cnt, err_cnt;
  logic [31:0] max_burst;

  prbs_gen u_gen (
    .clk(clk), .rst_n(rst_n), .mode(mode), .en(en),
    .prbs_out(gen_bit), .lfsr_state()
  );

  assign rx_bit = gen_bit ^ inject;

  ber_counter dut (
    .clk(clk), .rst_n(rst_n), .rx_bit(rx_bit), .mode(mode), .en(en),
    .cnt_rst(cnt_rst), .aligned(aligned),
    .bit_cnt(bit_cnt), .err_cnt(err_cnt), .max_burst(max_burst)
  );

  always #5 clk = ~clk;

  task automatic inject_errors(input int n);
    @(negedge clk);
    inject = 1;
    repeat (n) @(negedge clk);
    inject = 0;
  endtask

  initial begin
    rst_n = 0; en = 0; inject = 0;
    repeat (4) @(posedge clk);
    @(negedge clk);
    rst_n = 1;
    @(negedge clk);
    en = 1;

    wait (aligned);
    $display("aligned after reset");

    repeat (1_000_000) @(posedge clk);
    if (bit_cnt == 0)  begin $error("bit_cnt stuck at zero"); $fatal(1); end
    if (err_cnt != 0)  begin $error("err_cnt=%0d in clean loopback", err_cnt); $fatal(1); end
    $display("clean run: bit_cnt=%0d err_cnt=0", bit_cnt);

    repeat (3) begin
      inject_errors(1);
      repeat (20) @(posedge clk);
    end
    if (err_cnt != 3)   begin $error("err_cnt=%0d expected 3", err_cnt); $fatal(1); end
    if (max_burst != 1) begin $error("max_burst=%0d expected 1", max_burst); $fatal(1); end
    $display("single-bit injection: err_cnt=3 max_burst=1");

    inject_errors(8);
    repeat (20) @(posedge clk);
    if (err_cnt != 11)  begin $error("err_cnt=%0d expected 11", err_cnt); $fatal(1); end
    if (max_burst != 8) begin $error("max_burst=%0d expected 8", max_burst); $fatal(1); end
    $display("burst injection: err_cnt=11 max_burst=8");

    $display("tb_ber_counter PASS");
    $finish;
  end

endmodule
