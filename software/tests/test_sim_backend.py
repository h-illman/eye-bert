import sys, os, time
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "python"))
from bert_ctrl import BertCtrl
from sim_backend import SimMem
import sweep


def make():
    return BertCtrl(backend=SimMem(seed=42))


def test_reset_values_and_field_rmw():
    with make() as c:
        assert c.field_read("tx_swing") == 0x0F
        assert c.field_read("ctle_gain") == 0x08
        c.field_write("prbs_mode", 2)
        assert c.field_read("prbs_mode") == 2
        assert c.field_read("bert_en") == 0  # RMW must not clobber neighbors
        c.field_write("bert_en", 1)
        assert c.field_read("prbs_mode") == 2


def test_counters_monotonic_and_snapshot_gated():
    with make() as c:
        c.field_write("bert_en", 1)
        c.reset_counters()
        time.sleep(0.02)
        b1, e1 = c.get_ber()
        time.sleep(0.02)
        b2, e2 = c.get_ber()
        assert b2 > b1 > 0
        assert e2 >= e1 >= 0
        # without a new snapshot, raw reads must not move
        lo1 = c.read(0x44)
        time.sleep(0.01)
        assert c.read(0x44) == lo1


def test_ber_improves_with_swing():
    with make() as c:
        c.field_write("bert_en", 1)
        lo = sweep._measure_sim_point(c, 0)
        hi = sweep._measure_sim_point(c, 31)
        assert hi < lo


def test_status_dict():
    with make() as c:
        s = c.get_status()
        assert set(s) == {"pll_lock", "rx_aligned", "bert_active", "eye_busy", "snap_busy"}
        assert s["pll_lock"]


def test_eye_sweep_shape_and_content():
    with make() as c:
        c.write(0x0C, (8 << 6) | 8)
        c.write(0x10, 1000)
        h = sweep.sweep_eye(c)
        assert h.shape == (8, 8)
        assert h.max() > 0
        assert h[0, 0] > h[4, 4]  # crossing region hotter than eye center
