module prbs_gen (
  input  logic        clk,
  input  logic        rst_n,
  input  logic [1:0]  mode,
  input  logic        en,
  output logic        prbs_out,
  output logic [30:0] lfsr_state
);

  localparam logic [6:0]  POLY7  = 7'h41;
  localparam logic [14:0] POLY15 = 15'h4001;
  localparam logic [30:0] POLY31 = 31'h10000001;

  logic [6:0]  r7;
  logic [14:0] r15;
  logic [30:0] r31;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      r7  <= 7'b1;
      r15 <= 15'b1;
      r31 <= 31'b1;
    end else if (en) begin
      r7  <= {r7[5:0],  1'b0} ^ (r7[6]   ? POLY7  : '0);
      r15 <= {r15[13:0],1'b0} ^ (r15[14] ? POLY15 : '0);
      r31 <= {r31[29:0],1'b0} ^ (r31[30] ? POLY31 : '0);
    end
  end

  always_comb begin
    unique case (mode)
      2'b00:   begin prbs_out = r7[6];   lfsr_state = {24'b0, r7};  end
      2'b01:   begin prbs_out = r15[14]; lfsr_state = {16'b0, r15}; end
      default: begin prbs_out = r31[30]; lfsr_state = r31;          end
    endcase
  end

endmodule
