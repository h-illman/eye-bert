"""Behavioral model of the Eyebert register map for hardware-free operation.

Models a lossy serial channel: BER improves with TX swing, has an optimal
CTLE setting, and the eye histogram reflects the same channel quality. Lets
the full sweep/analysis toolchain run on any machine — no FPGA required.
"""
import math
import random
import time

import numpy as np

import csr_map

LINE_RATE = 10e9
EYE_SWEEP_SECONDS = 0.2


class SimMem:
    def __init__(self, seed=None):
        self._rng = random.Random(seed)
        self._regs = {
            0x00: 0x0,
            0x04: 0x0F,
            0x08: (0x04 << 5) | 0x08,
            0x0C: (32 << 6) | 32,
            0x10: 1_000_000,
            0x58: 0x0,
        }
        self._t0 = time.monotonic()
        self._snap = (0, 0, 0)
        self._eye_done_at = None
        self._hist = None

    def _field(self, name):
        offset, mask, shift = csr_map.field(name)
        return (self._regs.get(offset, 0) & mask) >> shift

    def channel_ber(self):
        swing = self._field("tx_swing")
        ctle = self._field("ctle_gain")
        ctle_penalty = ((ctle - 12) / 6.0) ** 2
        log_ber = -1.0 - 0.42 * swing + 0.8 * ctle_penalty
        return min(10 ** log_ber, 0.5)

    def _counters(self):
        if not self._field("bert_en"):
            return self._snap
        elapsed = time.monotonic() - self._t0
        bits = int(elapsed * LINE_RATE)
        lam = bits * self.channel_ber()
        if lam > 1e6:
            errs = int(self._rng.gauss(lam, math.sqrt(lam)))
        else:
            errs = self._poisson(lam)
        errs = max(0, min(errs, bits))
        burst = 0 if errs == 0 else (1 if self.channel_ber() < 1e-3 else self._rng.randint(1, 6))
        return bits, errs, burst

    def _poisson(self, lam):
        if lam <= 0:
            return 0
        if lam > 50:
            return max(0, int(self._rng.gauss(lam, math.sqrt(lam))))
        L, k, p = math.exp(-lam), 0, 1.0
        while True:
            p *= self._rng.random()
            if p <= L:
                return k
            k += 1

    def _make_eye(self):
        P = max(self._field("phase_steps"), 1)
        V = max(self._field("volt_bins"), 1)
        dwell = max(self._regs.get(0x10, 1), 1)
        ber = self.channel_ber()
        closure = min(math.log10(max(ber, 1e-15)) / -15.0, 1.0)
        jitter = 0.012 + 0.05 * (1 - closure)
        noise = 0.02 + 0.08 * (1 - closure)
        p, v = np.meshgrid(np.linspace(0, 1, P), np.linspace(-1, 1, V), indexing="ij")
        h = (np.exp(-(p ** 2) / jitter) + np.exp(-((p - 1) ** 2) / jitter)
             + 0.6 * np.exp(-((v - 0.85) ** 2) / noise)
             + 0.6 * np.exp(-((v + 0.85) ** 2) / noise))
        h = h * dwell * 0.5 + self._rng.random() * 2
        self._hist = h.astype(np.uint32)

    def read(self, offset):
        if offset == csr_map.reg("STATUS"):
            eye_busy = self._eye_done_at is not None and time.monotonic() < self._eye_done_at
            s = 0x1
            if self._field("bert_en"):
                s |= 0x2 | 0x4
            if eye_busy:
                s |= 0x8
            return s
        if offset == csr_map.reg("BIT_LO"):
            return self._snap[0] & 0xFFFFFFFF
        if offset == csr_map.reg("BIT_HI"):
            return self._snap[0] >> 32
        if offset == csr_map.reg("ERR_LO"):
            return self._snap[1] & 0xFFFFFFFF
        if offset == csr_map.reg("ERR_HI"):
            return self._snap[1] >> 32
        if offset == csr_map.reg("BURST"):
            return self._snap[2]
        if offset == csr_map.reg("EYE_DATA"):
            if self._hist is None:
                return 0
            addr = self._regs.get(0x58, 0)
            p, v = (addr >> 6) & 0x3F, addr & 0x3F
            if p < self._hist.shape[0] and v < self._hist.shape[1]:
                return int(self._hist[p, v])
            return 0
        return self._regs.get(offset, 0)

    def write(self, offset, value):
        value &= 0xFFFFFFFF
        if offset == csr_map.reg("CTRL"):
            prev_eye = self._field("eye_en")
            if value & 0x2:
                self._t0 = time.monotonic()
            self._regs[0x00] = value & ~0x2
            if (value & 0x8) and not prev_eye:
                self._make_eye()
                self._eye_done_at = time.monotonic() + EYE_SWEEP_SECONDS
            return
        if offset == 0x14:
            self._snap = self._counters()
            return
        self._regs[offset] = value

    def close(self):
        pass
