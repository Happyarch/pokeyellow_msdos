#!/usr/bin/env python3
"""revisions.py — Disk-persisted revision tracking for music enhancement YAMLs.

Stores snapshots in dos_port/tools/audio/.revisions/<Song>/ to guarantee
zero work is lost across session exits, crashes, or multi-agent git churn.
"""

from __future__ import annotations

import datetime
import hashlib
from pathlib import Path
import shutil

AUDITION_DIR = Path(__file__).resolve().parent
AUDIO_DIR = AUDITION_DIR.parent
REVISIONS_DIR = AUDIO_DIR / ".revisions"
ENHANCE_DIR = AUDIO_DIR / "enhancements"


def get_revision_dir(song_name: str) -> Path:
    rdir = REVISIONS_DIR / song_name
    rdir.mkdir(parents=True, exist_ok=True)
    return rdir


def list_revisions(song_name: str) -> list[tuple[int, str, Path]]:
    """Returns sorted list of (rev_id, timestamp, path)."""
    rdir = get_revision_dir(song_name)
    revs = []
    for p in rdir.glob("*.yaml"):
        parts = p.stem.split("_", 2)
        if len(parts) >= 2 and parts[0].isdigit():
            rev_id = int(parts[0])
            ts = parts[1]
            revs.append((rev_id, ts, p))
    revs.sort(key=lambda r: r[0])
    return revs


def get_latest_revision(song_name: str) -> tuple[int, Path] | None:
    revs = list_revisions(song_name)
    if not revs:
        return None
    return revs[-1][0], revs[-1][2]


def save_snapshot(song_name: str, content: str, note: str = "") -> tuple[int, Path]:
    """Saves a snapshot if content differs from the latest stored revision."""
    rdir = get_revision_dir(song_name)
    revs = list_revisions(song_name)
    content_hash = hashlib.sha256(content.encode("utf-8")).hexdigest()

    if revs:
        last_id, _, last_path = revs[-1]
        last_hash = hashlib.sha256(last_path.read_bytes()).hexdigest()
        if last_hash == content_hash:
            return last_id, last_path
        next_id = last_id + 1
    else:
        next_id = 1

    now_str = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    note_slug = f"_{note}" if note else ""
    filename = f"{next_id:04d}_{now_str}{note_slug}.yaml"
    out_path = rdir / filename
    out_path.write_text(content, encoding="utf-8")
    return next_id, out_path


def get_revision_content(song_name: str, rev_id: int) -> str | None:
    rdir = get_revision_dir(song_name)
    matches = list(rdir.glob(f"{rev_id:04d}_*.yaml"))
    if not matches:
        return None
    return matches[0].read_text(encoding="utf-8")


def revert_to_revision(song_name: str, rev_id: int) -> bool:
    """Restores the YAML file on disk from a specific revision."""
    rdir = get_revision_dir(song_name)
    matches = list(rdir.glob(f"{rev_id:04d}_*.yaml"))
    if not matches:
        return False
    target = ENHANCE_DIR / f"{song_name}.yaml"
    shutil.copyfile(matches[0], target)
    return True
