import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "python"))
import csr_map


def test_field_math():
    assert csr_map.field("prbs_mode") == (0x00, 0x30, 4)
    assert csr_map.field("tx_post") == (0x04, 0x7C00, 10)
    assert csr_map.field("dwell_cycles") == (0x10, 0xFFFFFFFF, 0)
    assert csr_map.field("snap_busy") == (0x40, 0x10, 4)


def test_fields_within_32_bits():
    for name, (off, msb, lsb) in csr_map.FIELDS.items():
        assert 0 <= lsb <= msb <= 31, name
        assert off in csr_map.REGS.values(), name


def test_no_field_overlap_within_register():
    by_off = {}
    for name, (off, msb, lsb) in csr_map.FIELDS.items():
        mask = ((1 << (msb - lsb + 1)) - 1) << lsb
        assert (by_off.get(off, 0) & mask) == 0, f"{name} overlaps"
        by_off[off] = by_off.get(off, 0) | mask
