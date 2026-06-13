`timescale 1ns/1ps

module tb_prbs_gen;

  logic        clk = 0;
  logic        rst_n;
  logic [1:0]  mode;
  logic        en;
  logic        prbs_out;
  logic [30:0] lfsr_state;

  prbs_gen dut (.*);

  always #5 clk = ~clk;

  localparam int NBITS = 1 << 15;

  logic [6:0]  g7;
  logic [14:0] g15;
  logic [30:0] g31;
  int          pass_cnt;

  function automatic logic [6:0] step7(logic [6:0] s);
    step7 = {s[5:0], 1'b0} ^ (s[6] ? 7'h41 : 7'h0);
  endfunction
  function automatic logic [14:0] step15(logic [14:0] s);
    step15 = {s[13:0], 1'b0} ^ (s[14] ? 15'h4001 : 15'h0);
  endfunction
  function automatic logic [30:0] step31(logic [30:0] s);
    step31 = {s[29:0], 1'b0} ^ (s[30] ? 31'h10000001 : 31'h0);
  endfunction

  task automatic run_mode(input logic [1:0] m);
    mode = m;
    en   = 0;
    rst_n = 0;
    g7 = 7'b1; g15 = 15'b1; g31 = 31'b1;
    repeat (4) @(posedge clk);
    @(negedge clk);
    rst_n = 1;
    @(negedge clk);
    en = 1;
    for (int i = 0; i < NBITS; i++) begin
      logic golden;
      case (m)
        2'b00: golden = g7[6];
        2'b01: golden = g15[14];
        default: golden = g31[30];
      endcase
      if (prbs_out !== golden) begin
        $error("mode %0d bit %0d: dut=%b golden=%b", m, i, prbs_out, golden);
        $fatal(1);
      end
      pass_cnt++;
      g7 = step7(g7); g15 = step15(g15); g31 = step31(g31);
      @(negedge clk);
    end
    en = 0;
  endtask

  initial begin
    pass_cnt = 0;
    run_mode(2'b00);
    run_mode(2'b01);
    run_mode(2'b10);
    $display("tb_prbs_gen PASS: %0d bits verified across PRBS7/15/31", pass_cnt);
    $finish;
  end

endmodule
