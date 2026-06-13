import glob
import os
import sys
import time

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.patches as patches
import numpy as np

RESULTS_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                           "..", "..", "results")

plt.rcParams.update({
    "font.family": "sans-serif",
    "font.size": 11,
    "figure.dpi": 100,
})


def latest_npz(modes=("eye",)):
    files = sorted(glob.glob(os.path.join(RESULTS_DIR, "sweep_*.npz")), reverse=True)
    for f in files:
        if str(np.load(f)["mode"]) in modes:
            return f
    sys.exit(f"no sweep results with mode in {modes} found in results/")


def find_eye_opening(hist):
    norm = hist.astype(float) / max(hist.max(), 1)
    open_mask = norm < 0.05
    best = (0, 0, 0, 0, 0)
    P, V = open_mask.shape
    for p0 in range(P):
        for v0 in range(V):
            if not open_mask[p0, v0]:
                continue
            pmax = p0
            while pmax + 1 < P and open_mask[pmax + 1, v0]:
                pmax += 1
            vmax = v0
            while vmax + 1 < V and open_mask[p0:pmax + 1, vmax + 1].all():
                vmax += 1
            area = (pmax - p0 + 1) * (vmax - v0 + 1)
            if area > best[0]:
                best = (area, p0, v0, pmax, vmax)
    return best[1:]


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else latest_npz()
    data = np.load(path)
    if str(data["mode"]) != "eye":
        sys.exit(f"{path} is not an eye sweep")
    hist = data["hist"]
    P, V = hist.shape

    fig, ax = plt.subplots(figsize=(7, 5.5))
    im = ax.imshow(hist.T, origin="lower", aspect="auto", cmap="inferno",
                   extent=[0, 1, -1, 1], interpolation="nearest")
    fig.colorbar(im, ax=ax, label="Hit count")

    p0, v0, p1, v1 = find_eye_opening(hist)
    eye_width = (p1 - p0 + 1) / P
    eye_height = (v1 - v0 + 1) / V
    rect = patches.Rectangle((p0 / P, 2 * v0 / V - 1),
                             eye_width, 2 * eye_height,
                             linewidth=1.5, edgecolor="#00E5FF",
                             facecolor="none", linestyle="--")
    ax.add_patch(rect)

    ax.set_xlabel("Phase (UI)")
    ax.set_ylabel("Voltage (normalized)")
    ax.set_title(f"Eye diagram — width {eye_width:.2f} UI, height {eye_height:.2f} FS")
    fig.tight_layout()

    ts = time.strftime("%Y%m%d_%H%M%S")
    out = os.path.join(RESULTS_DIR, f"eye_diagram_{ts}.png")
    fig.savefig(out, dpi=300)
    print(f"eye_width={eye_width:.3f} UI  eye_height={eye_height:.3f} FS")
    print(f"saved {out}")


if __name__ == "__main__":
    main()
