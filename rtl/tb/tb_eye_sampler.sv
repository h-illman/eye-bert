`timescale 1ns/1ps

module tb_eye_sampler;

  logic        clk = 0;
  logic        rst_n;
  logic        rx_bit;
  logic        en;
  logic [5:0]  phase_steps = 6'd4;
  logic [5:0]  volt_bins   = 6'd4;
  logic [31:0] dwell_cycles = 32'd16;
  logic        busy;
  logic [11:0] rd_addr;
  logic [31:0] rd_data;

  eye_sampler dut (.*);

  always #5 clk = ~clk;

  always @(posedge clk) rx_bit <= $urandom & 1;

  initial begin
    rst_n = 0; en = 0; rd_addr = 0;
    repeat (4) @(posedge clk);
    rst_n = 1;
    @(posedge clk);
    en = 1;

    wait (busy);
    en = 0;  // single sweep
    wait (!busy);
    repeat (4) @(posedge clk);

    for (int p = 0; p < 4; p++) begin
      for (int v = 0; v < 4; v++) begin
        rd_addr = {p[5:0], v[5:0]};
        repeat (2) @(posedge clk);
        #1;
        if (rd_data == 0) begin
          $error("bin[%0d][%0d] is zero", p, v);
          $fatal(1);
        end
        $display("bin[%0d][%0d] = %0d", p, v, rd_data);
      end
    end

    $display("tb_eye_sampler PASS: 16/16 bins populated");
    $finish;
  end

endmodule
