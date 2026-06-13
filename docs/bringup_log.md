# Bring-up Log

## Phase 1 — RTL + verification + sim-mode toolchain (complete, simulation)

- 6/6 SystemVerilog testbenches passing under Icarus Verilog 12
  (`make -C sim all`): unit (prbs/ber/eye/axi), stress, and full-system
  with behavioral PHY and 30-bit serial loopback.
- Key measured-in-sim numbers: lock from any phase in 65 cycles; loss of
  lock after 26 fully-corrupted bits; relock in 65; PRBS7 period verified
  exactly 127; exact error counts through the full AXI→loopback stack.
- 8/8 pytest unit tests; end-to-end `--sim` sweeps and both plot scripts
  green in CI.
- One architecture redesign during verification: slip alignment → self-
  synchronizing checker (see technical report §4.2).

## Phase 2 — Transceiver bring-up

_Pending hardware. Record Native PHY parameters, PLL lock, data rates,
parallel-datapath gearing notes, and Signal Tap captures here._

## Phase 3 — External SMA loopback

_Pending hardware. First hardware BER waterfall replaces docs/img sim figure._

## Phase 4 — Eye diagram

_Pending hardware + Reconfiguration Controller address map._
