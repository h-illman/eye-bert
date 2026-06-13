# Contributing

Contributions welcome — this project aims to be the open, scriptable answer to
vendor-locked transceiver test GUIs.

## Before opening a PR

1. `make -C sim all` — all six RTL testbenches must pass under Icarus Verilog.
2. `pytest software/tests/` — Python unit tests must pass.
3. Run the end-to-end check without hardware:
   `python software/python/sweep.py --mode ber_swing --sim --bits 2e8`

CI runs all three on every push.

## Where help is wanted

- Parallel-datapath PRBS/checker (32/64-bit per cycle) for real line rates
- Buildroot config and device tree for the DE25-Standard HPS
- Reconfiguration Controller address maps for swing/emphasis/CTLE/PI writes
- Support for other boards (any Agilex/Stratix HSMC board, or a Xilinx port)
- Measured hardware results for `docs/bringup_log.md`

## Style

RTL: compact SystemVerilog, comments only where the code can't speak.
Python: stdlib + numpy/matplotlib/scipy only; no vendor tool subprocess calls.
