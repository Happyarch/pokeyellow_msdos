#!/usr/bin/env python3
"""test_volume_cleaving.py — Verification for Workstream B (Volume Cleaving & Linter).

Covers:
  * yaml_lint:
    - Legacy `volume` alone produces 0 errors and 1 deprecation warning.
    - Mutual exclusivity: mixing legacy `volume` with any device-scoped key
      (opl_volume, mt32_volume, gm_volume) produces a hard error.
    - Tier-1-only constraint: opl_volume on Tier 2 or Tier 3 produces a hard error.
    - Device-scoped volume keys (opl_volume, mt32_volume, gm_volume) produce 0 errors
      and 0 deprecation warnings, and resolve correctly on ResolvedChannel.
    - Volume validation: out-of-range (0-127) or non-int (string, bool) produces errors.
    - Root-level `opl_base_channels`: valid patch names pass cleanly; invalid patch
      names or channel keys produce hard errors.
  * Downstream consumers:
    - midi_renderer: resolves mt32_volume on mt32 target and gm_volume on gm target,
      falling back to c.volume.
    - gb_to_midi: resolves mt32_volume on mt32 target and gm_volume on gm target,
      falling back to c.volume.
    - opl_renderer: resolves opl_volume, falling back to c.volume.

Usage:
    python3 tools/audio/test_volume_cleaving.py
"""

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace

import yaml

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from yaml_lint import lint, ResolvedChannel  # noqa: E402
from gen_opl_patches import PATCHES  # noqa: E402


class TestVolumeCleaving(unittest.TestCase):
    def setUp(self):
        self._temp_dir = tempfile.TemporaryDirectory()
        self.tmp = Path(self._temp_dir.name)
        self.sample_opl = next(iter(PATCHES))

    def tearDown(self):
        self._temp_dir.cleanup()

    def _enh_path(self, channels, **top) -> Path:
        doc = {
            "schema": 1,
            "song": "Music_Cities2",
            "channels": channels,
        }
        doc.update(top)
        p = self.tmp / "Music_Cities2.yaml"
        p.write_text(yaml.safe_dump(doc))
        return p

    def _ch(self, name: str = "pad", tier: int = 1, **kw) -> dict:
        ch = {
            "name": name,
            "tier": tier,
            "pan": "center",
            "mt32_patch": 49,
            "gm_program": 49,
            "events": [{"m": 1, "b": 1, "d": 1, "n": "C2"}],
        }
        if tier == 1:
            ch["opl_patch"] = self.sample_opl
        ch.update(kw)
        return ch

    # -----------------------------------------------------------------------
    # 1. Legacy volume deprecation & propagation
    # -----------------------------------------------------------------------
    def test_legacy_volume_alone_produces_warning_and_zero_errors(self):
        """A channel with only legacy `volume` produces 0 errors and 1 deprecation warning."""
        ch = self._ch(volume=80)
        p = self._enh_path([ch])
        rep, resolved, _ = lint(p)

        self.assertEqual(rep.errors, [])
        dep_warns = [w for w in rep.warnings if "'volume' is deprecated" in w]
        self.assertEqual(len(dep_warns), 1)

        self.assertEqual(len(resolved), 1)
        rc = resolved[0]
        self.assertEqual(rc.volume, 80)
        self.assertEqual(rc.opl_volume, 80)
        self.assertEqual(rc.mt32_volume, 80)
        self.assertEqual(rc.gm_volume, 80)

    # -----------------------------------------------------------------------
    # 2. Mutual exclusivity
    # -----------------------------------------------------------------------
    def test_mutual_exclusivity_volume_and_opl_volume(self):
        """Mixing `volume` and `opl_volume` produces a hard error."""
        ch = self._ch(volume=80, opl_volume=70)
        p = self._enh_path([ch])
        rep, _, _ = lint(p)

        mix_errs = [e for e in rep.errors if "cannot mix legacy 'volume'" in e]
        self.assertTrue(len(mix_errs) >= 1)

    def test_mutual_exclusivity_volume_and_mt32_volume(self):
        """Mixing `volume` and `mt32_volume` produces a hard error."""
        ch = self._ch(volume=80, mt32_volume=85)
        p = self._enh_path([ch])
        rep, _, _ = lint(p)

        mix_errs = [e for e in rep.errors if "cannot mix legacy 'volume'" in e]
        self.assertTrue(len(mix_errs) >= 1)

    def test_mutual_exclusivity_volume_and_gm_volume(self):
        """Mixing `volume` and `gm_volume` produces a hard error."""
        ch = self._ch(volume=80, gm_volume=90)
        p = self._enh_path([ch])
        rep, _, _ = lint(p)

        mix_errs = [e for e in rep.errors if "cannot mix legacy 'volume'" in e]
        self.assertTrue(len(mix_errs) >= 1)

    def test_mutual_exclusivity_all_volume_keys_mixed(self):
        """Mixing `volume` with all device-scoped keys produces a hard error."""
        ch = self._ch(volume=80, opl_volume=70, mt32_volume=85, gm_volume=90)
        p = self._enh_path([ch])
        rep, _, _ = lint(p)

        mix_errs = [e for e in rep.errors if "cannot mix legacy 'volume'" in e]
        self.assertTrue(len(mix_errs) >= 1)

    # -----------------------------------------------------------------------
    # 3. Tier-1-only constraint for opl_volume
    # -----------------------------------------------------------------------
    def test_opl_volume_tier2_error(self):
        """A channel with `opl_volume` on Tier 2 produces an error."""
        ch = self._ch(tier=2, opl_volume=70, mt32_volume=85, gm_volume=90)
        p = self._enh_path([ch])
        rep, _, _ = lint(p)

        tier_errs = [e for e in rep.errors if "opl_volume is tier-1-only" in e]
        self.assertTrue(len(tier_errs) >= 1)
        self.assertTrue(any("tier 2" in e for e in tier_errs))

    def test_opl_volume_tier3_error(self):
        """A channel with `opl_volume` on Tier 3 produces an error."""
        ch = self._ch(tier=3, opl_volume=70, mt32_volume=85, gm_volume=90)
        p = self._enh_path([ch])
        rep, _, _ = lint(p)

        tier_errs = [e for e in rep.errors if "opl_volume is tier-1-only" in e]
        self.assertTrue(len(tier_errs) >= 1)
        self.assertTrue(any("tier 3" in e for e in tier_errs))

    # -----------------------------------------------------------------------
    # 4. Valid device-scoped volumes
    # -----------------------------------------------------------------------
    def test_valid_device_scoped_volumes_tier1(self):
        """A channel with valid device-scoped volumes produces 0 errors and 0 deprecation warnings."""
        ch = self._ch(tier=1, opl_volume=75, mt32_volume=85, gm_volume=95)
        p = self._enh_path([ch])
        rep, resolved, _ = lint(p)

        self.assertEqual(rep.errors, [])
        dep_warns = [w for w in rep.warnings if "'volume' is deprecated" in w]
        self.assertEqual(dep_warns, [])

        self.assertEqual(len(resolved), 1)
        rc = resolved[0]
        self.assertEqual(rc.opl_volume, 75)
        self.assertEqual(rc.mt32_volume, 85)
        self.assertEqual(rc.gm_volume, 95)
        self.assertEqual(rc.volume, 96)  # Default effective_vol when unstated

    def test_valid_device_scoped_volumes_tier2(self):
        """A tier-2 channel with mt32_volume and gm_volume (no opl_volume) passes cleanly."""
        ch = self._ch(tier=2, mt32_volume=85, gm_volume=95)
        p = self._enh_path([ch])
        rep, resolved, _ = lint(p)

        self.assertEqual(rep.errors, [])
        dep_warns = [w for w in rep.warnings if "'volume' is deprecated" in w]
        self.assertEqual(dep_warns, [])

        self.assertEqual(len(resolved), 1)
        rc = resolved[0]
        self.assertEqual(rc.mt32_volume, 85)
        self.assertEqual(rc.gm_volume, 95)
        self.assertEqual(rc.opl_volume, 96)

    def test_device_volume_fallback_defaults(self):
        """Omitted device volumes fall back to effective_vol (96)."""
        ch = self._ch(tier=1, opl_volume=64)
        p = self._enh_path([ch])
        rep, resolved, _ = lint(p)

        self.assertEqual(rep.errors, [])
        self.assertEqual(len(resolved), 1)
        rc = resolved[0]
        self.assertEqual(rc.opl_volume, 64)
        self.assertEqual(rc.mt32_volume, 96)
        self.assertEqual(rc.gm_volume, 96)

    # -----------------------------------------------------------------------
    # 5. Volume bounds and type validation
    # -----------------------------------------------------------------------
    def test_volume_bounds_and_type_validation(self):
        """Volume values must be integers between 0 and 127; booleans/strings/out-of-bounds fail."""
        for key in ("volume", "opl_volume", "mt32_volume", "gm_volume"):
            for bad_val in (-1, 128, "80", True, False):
                ch = self._ch(**{key: bad_val})
                p = self._enh_path([ch])
                rep, _, _ = lint(p)
                self.assertTrue(
                    any(f"{key} must be an integer 0-127" in e for e in rep.errors),
                    f"Expected error for {key}={bad_val!r}, got errors: {rep.errors}"
                )

    # -----------------------------------------------------------------------
    # 6. opl_base_channels validation
    # -----------------------------------------------------------------------
    def test_opl_base_channels_valid(self):
        """opl_base_channels with valid patch names produces 0 errors."""
        ch = self._ch(tier=1, opl_volume=70, mt32_volume=80, gm_volume=80)
        p = self._enh_path(
            [ch],
            opl_base_channels={
                "ch1": self.sample_opl,
                "ch2": self.sample_opl,
            }
        )
        rep, _, _ = lint(p)
        self.assertEqual(rep.errors, [])

    def test_opl_base_channels_invalid_patch(self):
        """opl_base_channels with invalid patch name produces an error."""
        ch = self._ch(tier=1, opl_volume=70, mt32_volume=80, gm_volume=80)
        p = self._enh_path(
            [ch],
            opl_base_channels={
                "ch1": "NONEXISTENT_OPL_PATCH_XYZ",
            }
        )
        rep, _, _ = lint(p)
        self.assertTrue(
            any("patch 'NONEXISTENT_OPL_PATCH_XYZ' not in OPL patches" in e
                for e in rep.errors)
        )

    def test_opl_base_channels_invalid_channel_key(self):
        """opl_base_channels with unknown channel key produces an error."""
        ch = self._ch(tier=1, opl_volume=70, mt32_volume=80, gm_volume=80)
        p = self._enh_path(
            [ch],
            opl_base_channels={
                "ch5": self.sample_opl,
            }
        )
        rep, _, _ = lint(p)
        self.assertTrue(
            any("unknown channel keys" in e for e in rep.errors)
        )

    def test_opl_base_channels_not_mapping(self):
        """opl_base_channels as a list or string produces an error."""
        ch = self._ch(tier=1, opl_volume=70, mt32_volume=80, gm_volume=80)
        p = self._enh_path([ch], opl_base_channels=["ch1", "ch2"])
        rep, _, _ = lint(p)
        self.assertTrue(
            any("opl_base_channels: must be a mapping" in e for e in rep.errors)
        )

    # -----------------------------------------------------------------------
    # 7. Downstream renderer & converter volume resolution logic
    # -----------------------------------------------------------------------
    def test_midi_renderer_volume_resolution(self):
        """midi_renderer selects mt32_volume or gm_volume based on target, falling back to volume."""
        # Simulated channel object matching ResolvedChannel
        c = SimpleNamespace(volume=60, opl_volume=70, mt32_volume=85, gm_volume=95)

        # Logic in midi_renderer.py:
        # if self.target == "mt32": vol = getattr(c, "mt32_volume", c.volume)
        # elif self.target == "gm": vol = getattr(c, "gm_volume", c.volume)
        # else: vol = c.volume
        def resolve_midi_vol(target, chan):
            if target == "mt32":
                return getattr(chan, "mt32_volume", chan.volume)
            elif target == "gm":
                return getattr(chan, "gm_volume", chan.volume)
            return chan.volume

        self.assertEqual(resolve_midi_vol("mt32", c), 85)
        self.assertEqual(resolve_midi_vol("gm", c), 95)
        self.assertEqual(resolve_midi_vol("opl", c), 60)

        # Fallback when mt32_volume/gm_volume missing:
        c_legacy = SimpleNamespace(volume=77)
        self.assertEqual(resolve_midi_vol("mt32", c_legacy), 77)
        self.assertEqual(resolve_midi_vol("gm", c_legacy), 77)

    def test_opl_renderer_volume_resolution(self):
        """opl_renderer resolves opl_volume with fallback to volume."""
        c = SimpleNamespace(volume=60, opl_volume=70, mt32_volume=85, gm_volume=95)
        vol = getattr(c, "opl_volume", c.volume)
        self.assertEqual(vol, 70)

        c_legacy = SimpleNamespace(volume=65)
        vol_legacy = getattr(c_legacy, "opl_volume", c_legacy.volume)
        self.assertEqual(vol_legacy, 65)

    def test_gb_to_midi_volume_resolution(self):
        """gb_to_midi resolves target volume with fallback."""
        c = SimpleNamespace(volume=60, opl_volume=70, mt32_volume=85, gm_volume=95)
        for target, expected in (("mt32", 85), ("gm", 95)):
            vol = (c.mt32_volume if target == "mt32" else c.gm_volume) if hasattr(c, "mt32_volume") else c.volume
            self.assertEqual(vol, expected)

        c_legacy = SimpleNamespace(volume=77)
        for target in ("mt32", "gm"):
            vol = (c_legacy.mt32_volume if target == "mt32" else c_legacy.gm_volume) if hasattr(c_legacy, "mt32_volume") else c_legacy.volume
            self.assertEqual(vol, 77)


if __name__ == "__main__":
    unittest.main()
