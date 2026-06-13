module ber_counter #(
  parameter int LOCK_THRESH = 64,
  parameter int LOL_THRESH  = 96
) (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        rx_bit,
  input  logic [1:0]  mode,
  input  logic        en,
  input  logic        cnt_rst,
  output logic        aligned,
  output logic [63:0] bit_cnt,
  output logic [63:0] err_cnt,
  output logic [31:0] max_burst
);

  // self-synchronizing checker: hunt by seeding history from rx, free-run when locked
  // recurrence b[n] = b[n-(N-M)] ^ b[n-N] for p(x) = x^N + x^M + 1
  logic [30:0] hist;
  logic        pred, mismatch;
  logic [6:0]  match_cnt;
  logic [7:0]  lol_lvl;
  logic [31:0] cur_burst;

  always_comb begin
    unique case (mode)
      2'b00:   pred = hist[0] ^ hist[6];    // PRBS7:  b[n-1] ^ b[n-7]
      2'b01:   pred = hist[0] ^ hist[14];   // PRBS15: b[n-1] ^ b[n-15]
      default: pred = hist[2] ^ hist[30];   // PRBS31: b[n-3] ^ b[n-31]
    endcase
  end

  assign mismatch = rx_bit ^ pred;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      hist      <= '0;
      aligned   <= 1'b0;
      match_cnt <= '0;
      lol_lvl   <= '0;
      bit_cnt   <= '0;
      err_cnt   <= '0;
      max_burst <= '0;
      cur_burst <= '0;
    end else if (!en) begin
      aligned   <= 1'b0;
      match_cnt <= '0;
      lol_lvl   <= '0;
      cur_burst <= '0;
    end else begin
      hist <= {hist[29:0], aligned ? pred : rx_bit};
      if (cnt_rst) begin
        bit_cnt   <= '0;
        err_cnt   <= '0;
        max_burst <= '0;
        cur_burst <= '0;
      end else if (aligned) begin
        bit_cnt <= bit_cnt + 64'd1;
        if (mismatch) begin
          err_cnt   <= err_cnt + 64'd1;
          cur_burst <= cur_burst + 32'd1;
          if (cur_burst + 32'd1 > max_burst) max_burst <= cur_burst + 32'd1;
          // leaky bucket: +4 per error, -1 per clean bit; sustained density >25% drops lock
          lol_lvl <= (lol_lvl > 8'd251) ? 8'd255 : lol_lvl + 8'd4;
        end else begin
          cur_burst <= '0;
          if (lol_lvl != 0) lol_lvl <= lol_lvl - 8'd1;
        end
        if (lol_lvl >= LOL_THRESH) begin
          aligned   <= 1'b0;
          match_cnt <= '0;
          lol_lvl   <= '0;
          cur_burst <= '0;
        end
      end
      if (!aligned) begin
        if (mismatch)                          match_cnt <= '0;
        else if (match_cnt == LOCK_THRESH - 1) aligned   <= 1'b1;
        else                                   match_cnt <= match_cnt + 7'd1;
      end
    end
  end

endmodule
