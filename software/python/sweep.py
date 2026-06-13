import argparse
import os
import time

import numpy as np

import csr_map
from bert_ctrl import BertCtrl

RESULTS_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                           "..", "..", "results")


def _measure(ctrl, bits_per_point):
    ctrl.reset_counters()
    line_rate = 10e9
    time.sleep(max(bits_per_point / line_rate, 0.05))
    bit, err = ctrl.get_ber()
    while bit < bits_per_point:
        time.sleep(0.05)
        bit, err = ctrl.get_ber()
    return err / bit if bit else float("nan")


def _measure_sim_point(ctrl, swing):
    ctrl.set_tx_cfg(swing)
    ctrl.reset_counters()
    time.sleep(0.02)
    bit, err = ctrl.get_ber()
    return err / bit if bit else float("nan")


def sweep_tx_swing(ctrl, swings, bits_per_point=1e9):
    ctrl.field_write("bert_en", 1)
    out = {}
    for s in swings:
        ctrl.set_tx_cfg(s, ctrl.field_read("tx_pre"), ctrl.field_read("tx_post"))
        out[s] = _measure(ctrl, bits_per_point)
        print(f"tx_swing={s:2d}  BER={out[s]:.3e}")
    return out


def sweep_ctle(ctrl, gains, bits_per_point=1e9):
    ctrl.field_write("bert_en", 1)
    out = {}
    for g in gains:
        ctrl.set_rx_cfg(g, ctrl.field_read("vga_gain"))
        out[g] = _measure(ctrl, bits_per_point)
        print(f"ctle_gain={g:2d}  BER={out[g]:.3e}")
    return out


def sweep_eye(ctrl):
    phase_steps = ctrl.field_read("phase_steps")
    volt_bins = ctrl.field_read("volt_bins")
    ctrl.field_write("eye_en", 1)
    time.sleep(0.01)
    while ctrl.get_status()["eye_busy"]:
        time.sleep(0.05)
    ctrl.field_write("eye_en", 0)
    hist = np.zeros((phase_steps, volt_bins), dtype=np.uint32)
    for p in range(phase_steps):
        for v in range(volt_bins):
            hist[p, v] = ctrl.read_eye_bin((p << 6) | v)
    return hist


def main():
    ap = argparse.ArgumentParser(description="Eyebert sweep runner")
    ap.add_argument("--mode", choices=["ber_swing", "ber_ctle", "eye"], required=True)
    ap.add_argument("--bits", type=float, default=1e9)
    ap.add_argument("--sim", action="store_true",
                    help="run against the behavioral model — no hardware needed")
    ap.add_argument("--seed", type=int, default=None)
    args = ap.parse_args()
    backend = None
    if args.sim:
        from sim_backend import SimMem
        backend = SimMem(seed=args.seed)
    os.makedirs(RESULTS_DIR, exist_ok=True)
    ts = time.strftime("%Y%m%d_%H%M%S")
    path = os.path.join(RESULTS_DIR, f"sweep_{ts}.npz")
    with BertCtrl(backend=backend) as ctrl:
        if args.mode == "ber_swing":
            res = sweep_tx_swing(ctrl, list(range(0, 32, 2)), args.bits)
            np.savez_compressed(path, mode="ber_swing",
                                param=np.array(list(res.keys())),
                                ber=np.array(list(res.values())))
        elif args.mode == "ber_ctle":
            res = sweep_ctle(ctrl, list(range(0, 32, 2)), args.bits)
            np.savez_compressed(path, mode="ber_ctle",
                                param=np.array(list(res.keys())),
                                ber=np.array(list(res.values())))
        else:
            hist = sweep_eye(ctrl)
            np.savez_compressed(path, mode="eye", hist=hist)
    print(f"saved {path}")


if __name__ == "__main__":
    main()
