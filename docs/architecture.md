# Eyebert Architecture

## 1. Block Diagram

```
HPS (Linux, Cortex-A55/A76)
  └─ /dev/mem mmap @ 0xFF200000
       └─ lightweight HPS-to-FPGA bridge (AXI-Lite)
            │
            ▼                          hps_clk domain
       ┌─────────────┐
       │  axi_csr.sv │  CTRL / TX_CFG / RX_CFG / EYE_CFG / DWELL
       └──────┬──────┘  STATUS / BIT / ERR / BURST / EYE_*
              │  2FF synchronizers (both directions)
══════════════╪══════════════════════ clock domain boundary ═══
              │                        xcvr_rx_clk domain
   ┌──────────┼───────────────┬──────────────────┐
   ▼          ▼               ▼                  ▼
┌─────────┐ ┌──────────────┐ ┌───────────────┐
│prbs_gen │ │ ber_counter  │ │  eye_sampler  │
└────┬────┘ └──────▲───────┘ └───────▲───────┘
     │tx_bit       │rx_bit           │rx_bit
     ▼             └────────┬────────┘
┌──────────────────────────────────────────────┐
│        Native PHY IP (u_native_phy)          │
│  serializer · TX driver · CDR · CTLE · DFE   │
└───┬──────────────────────────────────▲───────┘
    │ tx_serial_p/n        rx_serial_p/n
    ▼                                  │
   SMA ──────[external loopback]───────┘
        (XTS-HSMC breakout card)
```

The Transceiver Reconfiguration Controller (`u_xcvr_reconfig`) sits beside the
Native PHY and is driven by the HPS to retune analog parameters (TX swing,
emphasis, CTLE, phase interpolator position) between measurement points.

## 2. Clock Domain Crossing Strategy

Two clock domains exist: `hps_clk` (100 MHz, AXI-Lite CSR) and `xcvr_rx_clk`
(transceiver recovered clock, all measurement logic).

- Every config signal crossing HPS → XCVR passes through a 2FF synchronizer.
  Multi-bit config buses (PRBS mode, sweep geometry, dwell count) are
  quasi-static: software changes them only while the consuming logic is idle
  (`bert_en`/`eye_en` low), so per-bit 2FF synchronization is safe — no value
  is consumed mid-transition.
- `cnt_rst` is converted to a single-cycle pulse in the destination domain by
  edge detection after the synchronizer.
- Status flags crossing XCVR → HPS use the same 2FF approach. The 64-bit
  counters are free-running, so naive synchronization could tear a value
  mid-update; instead they cross via a **req/ack toggle handshake snapshot**.
  Writing the `SNAP` register toggles a request into the recovered clock
  domain, hardware latches `{bit_cnt, err_cnt, max_burst}` into snapshot
  registers and toggles an acknowledge back, and the HPS side captures the
  (now provably stable) values and clears `snap_busy`. Data is stable by
  protocol: a new request cannot fire until the previous acknowledge has been
  observed.
- Reset into the recovered clock domain is asynchronous-assert,
  synchronous-deassert via a 2FF reset synchronizer.

## 3. PRBS Lock Acquisition Algorithm

The checker in `ber_counter.sv` is **self-synchronizing**: it exploits the
fact that every PRBS sequence satisfies the linear recurrence of its
generator polynomial — for p(x) = xᴺ + xᴹ + 1, every bit obeys
b[n] = b[n−(N−M)] ⊕ b[n−N].

1. **Hunt.** Received bits shift into a 31-bit history register. Each cycle
   the recurrence predicts the next bit from history; the prediction is
   compared against the actual received bit. Matches increment a counter,
   any mismatch zeroes it.
2. **Lock.** After `LOCK_THRESH = 64` consecutive matches (false-lock
   probability on random data: 2⁻⁶⁴), `aligned` asserts. Lock is acquired
   within ~N + 64 bits **from any phase offset** — measured at 65 cycles in
   `tb_stress` — because the reference is seeded directly from the received
   stream rather than searched for.
3. **Count.** The history register now free-runs on its own predictions (so
   bit errors cannot corrupt the reference). Every bit increments `bit_cnt`;
   every mismatch increments `err_cnt` and the burst tracker.
4. **Loss of lock.** A leaky-bucket level rises +4 per error and decays −1
   per clean bit. Sustained error density above ~25% (cable pulled, rate
   mismatch) drives the level past `LOL_THRESH = 96`, drops `aligned`, and
   returns to hunt — verified in `tb_bert_top` by holding the loopback
   corrupted, observing lock drop, then automatic relock on recovery.

An earlier revision used slip-based alignment (hold the reference LFSR one
cycle per mismatch). The system-level testbench exposed its flaw: slip only
converges when the reference *leads* the received stream, so recovery after
a long corruption event required wrapping the entire 2³¹−1 sequence. The
self-synchronizing design replaced it; the failure and fix are documented in
`docs/technical_report.md`.

## 4. Eye Diagram Sweep Methodology

The eye is rasterized as a `phase_steps × volt_bins` histogram (max 64×64,
4096 × 32-bit BRAM). For each point:

1. HPS positions the receiver sampling point via the Reconfiguration
   Controller — phase interpolator code for the horizontal axis, DFE/slicer
   offset for the vertical axis.
2. The RTL FSM in `eye_sampler.sv` dwells for `dwell_cycles` bit periods,
   accumulating the popcount of sampled ones, then adds it into the BRAM bin
   addressed by `{phase_idx, volt_bin}` with a read-modify-write.
3. `busy` deasserts when the full raster completes; it restarts immediately if
   `eye_en` is still high (continuous accumulation deepens the histogram).

The RTL sweep is purely counter-driven; physical sampling-point movement is
software's responsibility between steps. HPS reads bins back through
`EYE_ADDR`/`EYE_DATA` and `software/analysis/plot_eye.py` renders the heatmap
and extracts the maximal contiguous open region as eye width/height.

## 5. AXI-Lite Access from Linux

No kernel driver is required. `bert_ctrl.py` opens `/dev/mem` with `O_SYNC`
and `mmap`s a 4 KB page at `0xFF200000` with `MAP_SHARED`. Register reads and
writes are 32-bit little-endian `struct` pack/unpack operations into the
mapped buffer. Each access becomes a single AXI-Lite transaction on the
lightweight bridge. The class is a context manager so the mapping and file
descriptor are released cleanly.

This requires root (or `CAP_SYS_RAWIO`) and a kernel built without
`CONFIG_STRICT_DEVMEM`, which the project Buildroot config provides.

## 6. HPS-to-FPGA Bridge Address Map

The Agilex 5 HPS exposes the lightweight HPS-to-FPGA bridge window at physical
`0xFF200000` (4 KB used here). In Platform Designer the `axi_csr` slave is
attached to the `lwhps2fpga` master at offset `0x0000_0000` within the window,
so CSR offset `0x00` lands at absolute `0xFF200000`. The full-bandwidth
`hps2fpga` bridge is left unused; the CSR traffic is low-rate and the
lightweight bridge keeps the fabric interconnect minimal. The bridge must be
released from reset by the boot software (handled by the generated U-Boot
handoff) before any access, otherwise the read hangs the AXI master.
