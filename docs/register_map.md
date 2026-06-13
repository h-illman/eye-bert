# Eyebert Register Map

All registers are accessed over the HPS lightweight HPS-to-FPGA AXI-Lite bridge at
base address `0xFF200000`. Data width is 32 bits, addresses are word-aligned. Control
registers live in the `hps_clk` domain and are synchronized into the transceiver
recovered clock domain with 2FF synchronizers; status registers travel the opposite
direction the same way. The `cnt_rst` bit is self-clearing — write 1 and the hardware
generates a single-cycle pulse.

## Control Registers (HPS write, FPGA read)

| Offset | Name    | Bits    | Field          | Reset       | R/W | Description                              |
|--------|---------|---------|----------------|-------------|-----|------------------------------------------|
| 0x00   | CTRL    | [0]     | `bert_en`      | 0           | RW  | Enable BERT operation                    |
| 0x00   | CTRL    | [1]     | `cnt_rst`      | 0           | W1P | Pulse-reset BER counters (auto-clears)   |
| 0x00   | CTRL    | [2]     | `loopback_en`  | 0           | RW  | Enable internal analog loopback          |
| 0x00   | CTRL    | [3]     | `eye_en`       | 0           | RW  | Enable eye diagram sweep mode            |
| 0x00   | CTRL    | [5:4]   | `prbs_mode`    | 0           | RW  | 00=PRBS7, 01=PRBS15, 10=PRBS31           |
| 0x04   | TX_CFG  | [4:0]   | `tx_swing`     | 5'h0F       | RW  | TX voltage swing (Native PHY units)      |
| 0x04   | TX_CFG  | [9:5]   | `tx_pre`       | 5'h00       | RW  | TX pre-emphasis                          |
| 0x04   | TX_CFG  | [14:10] | `tx_post`      | 5'h00       | RW  | TX post-emphasis                         |
| 0x08   | RX_CFG  | [4:0]   | `ctle_gain`    | 5'h08       | RW  | CTLE gain                                |
| 0x08   | RX_CFG  | [9:5]   | `vga_gain`     | 5'h04       | RW  | VGA gain                                 |
| 0x0C   | EYE_CFG | [5:0]   | `phase_steps`  | 6'd32       | RW  | Phase interpolator steps per sweep       |
| 0x0C   | EYE_CFG | [11:6]  | `volt_bins`    | 6'd32       | RW  | Voltage bins per phase step              |
| 0x10   | DWELL   | [31:0]  | `dwell_cycles` | 32'd1000000 | RW  | Bit periods per eye sample point         |
| 0x14   | SNAP    | [0]     | `snap`         | 0           | W1P | Trigger atomic counter snapshot          |

## Status Registers (FPGA write, HPS read)

| Offset | Name     | Bits   | Field            | R/W | Description                              |
|--------|----------|--------|------------------|-----|------------------------------------------|
| 0x40   | STATUS   | [0]    | `pll_lock`       | RO  | Native PHY PLL locked                    |
| 0x40   | STATUS   | [1]    | `rx_aligned`     | RO  | PRBS receiver aligned (BER lock)         |
| 0x40   | STATUS   | [2]    | `bert_active`    | RO  | BERT running                             |
| 0x40   | STATUS   | [3]    | `eye_busy`       | RO  | Eye sweep in progress                    |
| 0x40   | STATUS   | [4]    | `snap_busy`      | RO  | Snapshot handshake in flight             |
| 0x44   | BIT_LO   | [31:0] | `bit_cnt[31:0]`  | RO  | Bit counter low word                     |
| 0x48   | BIT_HI   | [31:0] | `bit_cnt[63:32]` | RO  | Bit counter high word                    |
| 0x4C   | ERR_LO   | [31:0] | `err_cnt[31:0]`  | RO  | Error counter low word                   |
| 0x50   | ERR_HI   | [31:0] | `err_cnt[63:32]` | RO  | Error counter high word                  |
| 0x54   | BURST    | [31:0] | `max_burst`      | RO  | Longest consecutive error run            |
| 0x58   | EYE_ADDR | [11:0] | `eye_rd_addr`    | RW  | Histogram read address `{phase[5:0], volt[5:0]}` |
| 0x5C   | EYE_DATA | [31:0] | `eye_rd_data`    | RO  | Histogram bin at `eye_rd_addr`           |

## Access Notes

- Counter reads are snapshot-based: write 1 to `SNAP`, poll `STATUS.snap_busy`
  until clear (a few hundred nanoseconds), then read `BIT_*`/`ERR_*`/`BURST`.
  The snapshot crosses clock domains with a req/ack toggle handshake, so the
  64-bit values are atomic and tear-free. `BertCtrl.get_ber()` does this
  automatically.
- The eye histogram readback is two-step: write the bin address to `EYE_ADDR`,
  then read `EYE_DATA`. The address crosses into the recovered clock domain, the
  BRAM read is registered, and the data crosses back; the AXI bridge round-trip
  time exceeds the synchronizer latency, so back-to-back accesses are safe.
