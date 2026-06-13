REGS = {
    "CTRL":     0x00,
    "TX_CFG":   0x04,
    "RX_CFG":   0x08,
    "EYE_CFG":  0x0C,
    "DWELL":    0x10,
    "SNAP":     0x14,
    "STATUS":   0x40,
    "BIT_LO":   0x44,
    "BIT_HI":   0x48,
    "ERR_LO":   0x4C,
    "ERR_HI":   0x50,
    "BURST":    0x54,
    "EYE_ADDR": 0x58,
    "EYE_DATA": 0x5C,
}

FIELDS = {
    "bert_en":      (0x00, 0, 0),
    "cnt_rst":      (0x00, 1, 1),
    "loopback_en":  (0x00, 2, 2),
    "eye_en":       (0x00, 3, 3),
    "prbs_mode":    (0x00, 5, 4),
    "tx_swing":     (0x04, 4, 0),
    "tx_pre":       (0x04, 9, 5),
    "tx_post":      (0x04, 14, 10),
    "ctle_gain":    (0x08, 4, 0),
    "vga_gain":     (0x08, 9, 5),
    "phase_steps":  (0x0C, 5, 0),
    "volt_bins":    (0x0C, 11, 6),
    "dwell_cycles": (0x10, 31, 0),
    "snap":         (0x14, 0, 0),
    "pll_lock":     (0x40, 0, 0),
    "rx_aligned":   (0x40, 1, 1),
    "bert_active":  (0x40, 2, 2),
    "eye_busy":     (0x40, 3, 3),
    "snap_busy":    (0x40, 4, 4),
    "bit_lo":       (0x44, 31, 0),
    "bit_hi":       (0x48, 31, 0),
    "err_lo":       (0x4C, 31, 0),
    "err_hi":       (0x50, 31, 0),
    "max_burst":    (0x54, 31, 0),
    "eye_rd_addr":  (0x58, 11, 0),
    "eye_rd_data":  (0x5C, 31, 0),
}


def field(name):
    offset, msb, lsb = FIELDS[name]
    mask = ((1 << (msb - lsb + 1)) - 1) << lsb
    return offset, mask, lsb


def reg(name):
    return REGS[name]
