# Eyebert

A hardware SerDes bit error rate tester (BERT) built on the **Terasic DE25-Standard**
development board (Intel Agilex 5 SoC, A5ED013BB32AE4S, 138K LEs). External loopback
testing is done via a **Terasic XTS-HSMC** SMA breakout card connected to the board's
HSMC connector, exposing 4 physical transceiver channels.

---

## What it does

The FPGA generates a known pseudo-random bit sequence (PRBS) and transmits it through
a high-speed transceiver. The same FPGA receives the signal back over an SMA loopback
cable, regenerates the expected PRBS locally, and compares every received bit against
the expected pattern. Mismatches are counted as bit errors.

By sweeping TX/RX parameters (voltage swing, pre-emphasis, CTLE gain) and counting
errors at each operating point, the system builds **BER waterfall curves**. A phase
interpolator sweep accumulates a 2D histogram of the received signal, rendered as an
**eye diagram heatmap**.

The HPS ARM core (Linux, Cortex-A55/A76) acts as the controller, writing config
registers and reading BER counters over an AXI-Lite bridge, running Python sweep
scripts, and rendering results with Matplotlib.

---

## Hardware modules

| Module | Description |
|---|---|
| PRBS generator | LFSR-based, PRBS-7 / PRBS-15 / PRBS-31 |
| TX/RX transceiver | Agilex 5 Native PHY IP — serializer, CDR, DFE, CTLE, PLL |
| BER counter | 64-bit bit counter, 64-bit error counter, burst error length tracker |
| Eye diagram sampler | 2D histogram `[phase_steps][volt_bins]` in BRAM, read out by HPS |
| AXI-Lite CSR map | HPS-writable config registers and HPS-readable status registers |

---

## Tech stack

- **RTL** — SystemVerilog
- **Synthesis & P&R** — Intel Quartus Pro
- **System integration** — Platform Designer (Qsys), HPS + FPGA fabric + AXI bridges
- **Transceiver IP** — Agilex 5 Native PHY + Transceiver Reconfiguration Controller
- **HPS OS** — Linux via Buildroot (Cortex-A55/A76)
- **HPS control** — Python over `/dev/mem` AXI-Lite register access
- **Analysis** — Python, NumPy, Matplotlib
- **On-chip debug** — Signal Tap Logic Analyzer

---

## Project phases

```
Phase 0  (Weeks 1–2)    Environment setup
                         Quartus Pro, Platform Designer, Buildroot toolchain,
                         Agilex 5 device support, Linux on HPS

Phase 1  (Weeks 3–5)    PRBS core + digital loopback
                         Verify BER = 0 in simulation and digital loopback
                         before touching the transceiver

Phase 2  (Weeks 6–9)    Transceiver bring-up + analog loopback
                         Native PHY IP, PLL lock, BER vs. data rate sweep

Phase 3  (Weeks 10–14)  External near-end loopback
                         SMA cables + XTS-HSMC card, TX swing sweep,
                         attenuator-simulated channel loss, BER waterfall curves

Phase 4  (Weeks 15–19)  Eye diagram sampler
                         Phase interpolator sweep, 2D histogram,
                         Matplotlib heatmap, eye width/height metrics

Phase 5  (Weeks 20–22)  Repo polish + blog post
                         README, architecture diagram, self-test mode,
                         real measured BER curves and eye diagram screenshots

Phase 6  (Future)       Two-board far-end loopback
```

---

## Repository layout

```
rtl/              SystemVerilog source — PRBS, BER counter, eye sampler, CSR, top
rtl/tb/           Testbenches for each module
ip/               Quartus IP catalog instantiation files (Native PHY, Reconfig)
platform/         Quartus project (.qpf/.qsf), Platform Designer (.qsys), SDC
software/hps/     Buildroot config, device tree, Linux target
software/python/  AXI-Lite control scripts (bert_ctrl.py, sweep.py, csr_map.py)
software/analysis/  BER and eye diagram plotting (plot_ber.py, plot_eye.py)
docs/             Architecture notes, register map, bring-up log
scripts/          Shell/PowerShell helpers — program FPGA, flash Linux image
sim/              Simulation working directory
```

---

## Build requirements

- Intel Quartus Pro (free license included with DE25-Standard)
- Buildroot ≥ 2024.02
- Python ≥ 3.11

```powershell
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

---

## Status

| Phase | Status |
|---|---|
| Phase 0 — environment setup | 🔄 In progress |
| Phase 1 — PRBS core | ⬜ Not started |
| Phase 2 — transceiver bring-up | ⬜ Not started |
| Phase 3 — external loopback | ⬜ Not started |
| Phase 4 — eye diagram | ⬜ Not started |
| Phase 5 — polish & blog | ⬜ Not started |
