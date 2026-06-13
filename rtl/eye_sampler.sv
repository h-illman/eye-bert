module eye_sampler (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        rx_bit,
  input  logic        en,
  input  logic [5:0]  phase_steps,
  input  logic [5:0]  volt_bins,
  input  logic [31:0] dwell_cycles,
  output logic        busy,
  input  logic [11:0] rd_addr,
  output logic [31:0] rd_data
);

  typedef enum logic [2:0] {IDLE, DWELL, RD, WR, STEP} state_t;
  state_t state;

  logic [31:0] mem [0:4095];
  logic [5:0]  phase_idx, volt_idx;
  logic [31:0] dwell_ctr, acc;
  logic [31:0] rmw_data;
  logic [11:0] wr_addr;

  initial for (int i = 0; i < 4096; i++) mem[i] = '0;

  assign wr_addr = {phase_idx, volt_idx};

  always_ff @(posedge clk) begin
    rd_data <= mem[rd_addr];
    if (state == RD) rmw_data <= mem[wr_addr];
    if (state == WR) mem[wr_addr] <= rmw_data + acc;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state     <= IDLE;
      busy      <= 1'b0;
      phase_idx <= '0;
      volt_idx  <= '0;
      dwell_ctr <= '0;
      acc       <= '0;
    end else begin
      unique case (state)
        IDLE: if (en) begin
          phase_idx <= '0;
          volt_idx  <= '0;
          dwell_ctr <= '0;
          acc       <= '0;
          busy      <= 1'b1;
          state     <= DWELL;
        end
        DWELL: begin
          acc       <= acc + {31'b0, rx_bit};
          dwell_ctr <= dwell_ctr + 32'd1;
          if (dwell_ctr == dwell_cycles - 32'd1) state <= RD;
        end
        RD: state <= WR;
        WR: state <= STEP;
        STEP: begin
          dwell_ctr <= '0;
          acc       <= '0;
          if (volt_idx == volt_bins - 6'd1) begin
            volt_idx <= '0;
            if (phase_idx == phase_steps - 6'd1) begin
              busy  <= 1'b0;
              state <= IDLE;
            end else begin
              phase_idx <= phase_idx + 6'd1;
              state     <= DWELL;
            end
          end else begin
            volt_idx <= volt_idx + 6'd1;
            state    <= DWELL;
          end
        end
        default: state <= IDLE;
      endcase
    end
  end

endmodule
