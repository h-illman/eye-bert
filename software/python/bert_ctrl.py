import mmap
import os
import struct
import time

import csr_map

MAP_SIZE = 0x1000


class DevMem:
    def __init__(self, base):
        self._fd = os.open("/dev/mem", os.O_RDWR | os.O_SYNC)
        self._mem = mmap.mmap(self._fd, MAP_SIZE, mmap.MAP_SHARED,
                              mmap.PROT_READ | mmap.PROT_WRITE, offset=base)

    def read(self, offset):
        return self._be.read(offset)

    def write(self, offset, value):
        self._be.write(offset, value)

    def close(self):
        self._be.close()


class BertCtrl:
    def __init__(self, base=0xFF200000, backend=None):
        self.base = base
        self._be = backend if backend is not None else DevMem(base)

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        self.close()
        return False

    def read(self, offset):
        return self._be.read(offset)

    def write(self, offset, value):
        self._be.write(offset, value)

    def field_read(self, name):
        offset, mask, shift = csr_map.field(name)
        return (self.read(offset) & mask) >> shift

    def field_write(self, name, value):
        offset, mask, shift = csr_map.field(name)
        cur = self.read(offset)
        self.write(offset, (cur & ~mask) | ((value << shift) & mask))

    def reset_counters(self):
        self.field_write("cnt_rst", 1)

    def snapshot(self, timeout=0.1):
        self.write(csr_map.reg("SNAP"), 1)
        deadline = time.monotonic() + timeout
        while self.field_read("snap_busy"):
            if time.monotonic() > deadline:
                raise TimeoutError("counter snapshot handshake timed out")
            time.sleep(1e-5)

    def get_ber(self):
        self.snapshot()
        bit = self.read(csr_map.reg("BIT_LO")) | (self.read(csr_map.reg("BIT_HI")) << 32)
        err = self.read(csr_map.reg("ERR_LO")) | (self.read(csr_map.reg("ERR_HI")) << 32)
        return bit, err

    def get_status(self):
        s = self.read(csr_map.reg("STATUS"))
        return {
            "pll_lock":    bool(s & 0x1),
            "rx_aligned":  bool(s & 0x2),
            "bert_active": bool(s & 0x4),
            "eye_busy":    bool(s & 0x8),
            "snap_busy":   bool(s & 0x10),
        }

    def set_prbs_mode(self, mode: int):
        self.field_write("prbs_mode", mode)

    def set_tx_cfg(self, swing, pre=0, post=0):
        self.write(csr_map.reg("TX_CFG"),
                   (swing & 0x1F) | ((pre & 0x1F) << 5) | ((post & 0x1F) << 10))

    def set_rx_cfg(self, ctle, vga):
        self.write(csr_map.reg("RX_CFG"), (ctle & 0x1F) | ((vga & 0x1F) << 5))

    def read_eye_bin(self, addr):
        self.write(csr_map.reg("EYE_ADDR"), addr & 0xFFF)
        time.sleep(1e-5)
        return self.read(csr_map.reg("EYE_DATA"))

    def close(self):
        self._be.close()
