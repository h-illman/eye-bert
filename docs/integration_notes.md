# Eyebert Integration Notes

## Wiring bert_top into Platform Designer

1. Create a new Platform Designer system containing the **Agilex 5 HPS**
   component. Enable the **lightweight HPS-to-FPGA bridge** (AXI-Lite, 32-bit)
   and the SDMMC/UART peripherals needed for the Linux boot flow.
2. Add `bert_top` as a custom component (Component Editor → import
   `rtl/*.sv`). Map its `s_axi_*` ports to a single AXI4-Lite slave interface,
   `hps_clk`/`hps_resetn` to clock and reset sinks.
3. Connect `lwhps2fpga.master` → `bert_top.s_axi` at offset `0x0000_0000`
   so the CSR block lands at physical `0xFF200000`.
4. Export `xcvr_refclk_p/n`, `tx_serial_p/n`, `rx_serial_p/n` to the top level.
   Clock `bert_top.hps_clk` from the HPS user clock (100 MHz).
5. Remove `rtl/ip_stubs.sv` from the synthesis fileset once the real IP is
   generated — the stubs exist only so the RTL elaborates standalone
   (simulation uses `rtl/tb/phy_bfm.sv` behavioral models instead). Replace
   the instantiations' module names with the generated IP names, or name the
   generated IP to match.

## Native PHY IP Parameters

Generate **Agilex 5 Transceiver Native PHY** from the IP catalog:

- Data rate: start at **3.125 Gbps** for bring-up, raise after clean BER.
- Reference clock: **156.25 MHz** from `HSMC_CLKOUT_p1` (matches the SDC).
- PCS/PMA width: the scaffold RTL consumes one bit per `xcvr_rx_clk` cycle.
  For real line rates configure a parallel width (e.g. 32 or 64) and add a
  gearbox, or run the PRBS/checker datapath at the parallel width — this is
  the main Phase 2 RTL task. The register map and software do not change.
- Enable the **serial loopback** control input and tie it to `loopback_en`
  (CTRL[2]) — this is the pre-SMA sanity path.
- Enable the **reconfiguration interface** and connect it to the
  Transceiver Reconfiguration Controller for runtime swing/emphasis/CTLE and
  phase interpolator writes.

## First Compile

```
cd sim && make all        # all three testbenches must pass first
cd ../platform
quartus_sh --flow compile bert_top
```

`make all` runs all six testbenches under Icarus Verilog — unit, stress, and
the full-system `tb_bert_top` with behavioral PHY; `make lint` elaborates the
full hierarchy. Only then is a multi-hour Quartus compile worth starting. Program
with `scripts/program_fpga.ps1`.

## First BER Check from Linux

1. Build the Buildroot image (`software/hps/`), write to SD, boot the HPS.
   Confirm U-Boot releases the lwhps2fpga bridge from reset.
2. Copy `software/python/` to the target (or NFS-mount the repo).
3. Run:

```python
from bert_ctrl import BertCtrl
with BertCtrl() as c:
    c.field_write("loopback_en", 1)   # internal serial loopback first
    c.set_prbs_mode(2)                # PRBS31
    c.field_write("bert_en", 1)
    print(c.get_status())             # expect pll_lock, then rx_aligned
    c.reset_counters()
    import time; time.sleep(1)
    bit, err = c.get_ber()
    print(f"bits={bit:,} errors={err} BER={err/bit:.2e}")
```

Expected: `rx_aligned=True`, `err=0` in internal loopback. Then move to the
SMA external loopback (`loopback_en=0`, cables on the XTS-HSMC card) and run
`python sweep.py --mode ber_swing`.

## Signal Tap Probes for Phase 2 Bring-up

Probe in the `xcvr_rx_clk` domain, triggered on `rx_aligned` rising:

- `u_ber_counter.aligned`, `match_cnt`, `mismatch` — watch lock acquisition
  and slip behavior; a match counter that repeatedly nears 64 and resets
  indicates marginal signal integrity, not phase offset.
- `u_native_phy.rx_is_lockedtodata` and `pll_locked` — CDR health before
  blaming the digital logic.
- `rx_bit` raw stream — confirm activity and rough transition density.
- `u_eye_sampler.state`, `phase_idx`, `volt_idx`, `busy` — verify the raster
  walks and terminates.
- In the `hps_clk` domain, a second instance on `axi_csr.do_write` and
  `waddr_q` confirms register traffic from Linux is arriving.
