import glob
import os
import sys
import time

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

RESULTS_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                           "..", "..", "results")
BER_FLOOR = 1e-14

plt.rcParams.update({
    "font.family": "sans-serif",
    "font.size": 11,
    "axes.spines.top": False,
    "axes.spines.right": False,
    "axes.grid": True,
    "axes.grid.axis": "y",
    "grid.alpha": 0.3,
    "xtick.minor.visible": False,
    "figure.dpi": 100,
})


def latest_npz(modes=("ber_swing", "ber_ctle")):
    files = sorted(glob.glob(os.path.join(RESULTS_DIR, "sweep_*.npz")), reverse=True)
    for f in files:
        if str(np.load(f)["mode"]) in modes:
            return f
    sys.exit(f"no sweep results with mode in {modes} found in results/")


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else latest_npz()
    data = np.load(path)
    mode = str(data["mode"])
    if mode not in ("ber_swing", "ber_ctle"):
        sys.exit(f"{path} is mode={mode}, not a BER sweep")
    param = data["param"]
    ber = np.maximum(data["ber"].astype(float), BER_FLOOR)
    xlabel = "TX swing (Native PHY units)" if mode == "ber_swing" else "CTLE gain"

    fig, ax = plt.subplots(figsize=(7, 5))
    ax.semilogy(param, ber, "o-", color="#1565C0", linewidth=1.5, markersize=5)
    ax.set_xlabel(xlabel)
    ax.set_ylabel("Bit error rate")
    ax.set_ylim(BER_FLOOR / 2, 1)
    ax.set_title(f"BER waterfall — {mode}")
    fig.tight_layout()

    ts = time.strftime("%Y%m%d_%H%M%S")
    out = os.path.join(RESULTS_DIR, f"ber_waterfall_{ts}.png")
    fig.savefig(out, dpi=300)
    print(f"saved {out}")


if __name__ == "__main__":
    main()
