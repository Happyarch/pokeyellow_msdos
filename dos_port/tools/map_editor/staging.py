"""staging.py — the editor's write layer (edits are staged until Ctrl+S).

A map-editor edit must not touch the repository. A paint stroke, an NPC drag, a
warp move, a route byte or a map expansion is written to a scratch copy and only
reaches the tree when the user saves. That is the whole point of this module:
the commands keep their `write=True` contract ("this edit is persisted"), and
the PATH LAYER decides where "persisted" lands.

Without a session (the CLI, the asset generators, the tests that only read) the
layer is transparent: reads and writes go straight to the repository.

Every path here is REPO-RELATIVE, so the scratch tree mirrors the repository and
a commit is a plain copy-back. Three trees are staged:

    dos_port/assets/map_overrides/*.json    schema-2 map diffs
    dos_port/assets/map_borders/*.json      border-ring paint
    dos_port/src/scripts/*.asm              port scripts (route + coordinate edits)

Writes materialise the file first, so a command that reads-then-writes a file
(scan a script, rewrite a route byte) sees the staged copy both times and the
commit compares like with like. Deleting an override (an emptied sidecar) is
tracked explicitly, because "the scratch copy is gone" and "the tree file must
go" are not the same statement.
"""
from __future__ import annotations

import os
from pathlib import Path
import shutil
import tempfile

ROOT = Path(__file__).resolve().parents[3]

OVERRIDES_DIR = "dos_port/assets/map_overrides"
BORDERS_DIR = "dos_port/assets/map_borders"
SCRIPTS_DIR = "dos_port/src/scripts"


def overrides_rel(pascal: str) -> str:
    return f"{OVERRIDES_DIR}/{pascal}.json"


def borders_rel(const: str) -> str:
    return f"{BORDERS_DIR}/{const}.json"


def script_rel(label: str) -> str:
    return f"{SCRIPTS_DIR}/{label}.asm"


class Staging:
    """Read/write over `root`, with an optional scratch tree in front of it.

    `root` defaults to the module ROOT, resolved on each call so a test can
    redirect the whole layer by patching `staging.ROOT`.
    """

    def __init__(self, root: Path | None = None, tmp: Path | None = None):
        self._root = Path(root) if root is not None else None
        self.tmp = Path(tmp) if tmp is not None else None
        self.deleted: set[str] = set()

    @property
    def root(self) -> Path:
        return self._root if self._root is not None else ROOT

    # ── paths ────────────────────────────────────────────────────────────────
    def real_path(self, rel: str) -> Path:
        return self.root / rel

    def staged_path(self, rel: str) -> Path | None:
        return None if self.tmp is None else self.tmp / rel

    def read_path(self, rel: str) -> Path | None:
        """The file to READ: the staged copy, else the tree file, else None."""
        if rel in self.deleted:
            return None
        staged = self.staged_path(rel)
        if staged is not None and staged.exists():
            return staged
        real = self.real_path(rel)
        return real if real.exists() else None

    def write_path(self, rel: str) -> Path:
        """The file to WRITE, materialising the tree copy when one exists.

        Materialising on write (not on read) keeps a plain scan from littering
        the scratch tree, while making a read-modify-write command consistent:
        the copy it edits is the copy the commit will compare.
        """
        staged = self.staged_path(rel)
        if staged is None:
            real = self.real_path(rel)
            real.parent.mkdir(parents=True, exist_ok=True)
            return real
        if not staged.exists():
            real = self.real_path(rel)
            if real.exists():
                staged.parent.mkdir(parents=True, exist_ok=True)
                staged.write_bytes(real.read_bytes())
        staged.parent.mkdir(parents=True, exist_ok=True)
        self.deleted.discard(rel)
        return staged

    def remove(self, rel: str) -> None:
        """Delete the staged copy, and remember that the tree file must go too."""
        staged = self.staged_path(rel)
        if staged is None:
            real = self.real_path(rel)
            if real.exists():
                real.unlink()
            return
        if staged.exists():
            staged.unlink()
        if self.real_path(rel).exists():
            self.deleted.add(rel)

    # ── inspection ───────────────────────────────────────────────────────────
    def staged_files(self) -> list[str]:
        if self.tmp is None or not self.tmp.exists():
            return []
        return sorted(p.relative_to(self.tmp).as_posix()
                      for p in self.tmp.rglob("*") if p.is_file())

    def changed(self) -> list[str]:
        """Repo-relative paths that a commit would actually touch."""
        result = []
        for rel in self.staged_files():
            real = self.real_path(rel)
            if not real.exists() or real.read_bytes() != (self.tmp / rel).read_bytes():
                result.append(rel)
        result.extend(sorted(self.deleted))
        return result

    def pending(self) -> int:
        return len(self.changed())

    # ── commit / discard ─────────────────────────────────────────────────────
    def commit(self) -> list[str]:
        """Copy the staged files into the tree; return what was written.

        Each file is replaced through a sibling temp file, so an interrupted
        save cannot leave a half-written sidecar (or a half-written script).
        """
        written = []
        for rel in self.changed():
            real = self.real_path(rel)
            staged = self.tmp / rel
            if staged.exists():
                real.parent.mkdir(parents=True, exist_ok=True)
                temp = real.with_name(real.name + ".staging-tmp")
                temp.write_bytes(staged.read_bytes())
                os.replace(temp, real)
            elif real.exists():
                real.unlink()
            written.append(rel)
        self.deleted.clear()
        # A staged copy identical to the tree is not an edit any more: drop it so
        # the next commit starts from a clean slate (and reads fall through).
        for rel in self.staged_files():
            real = self.real_path(rel)
            staged = self.tmp / rel
            if real.exists() and real.read_bytes() == staged.read_bytes():
                staged.unlink()
        return written

    def discard(self) -> None:
        if self.tmp is not None:
            shutil.rmtree(self.tmp, ignore_errors=True)
        self.tmp = None
        self.deleted.clear()


_NULL = Staging()
_CURRENT: Staging | None = None


def current() -> Staging:
    """The active staging layer (transparent when no session is open)."""
    return _CURRENT if _CURRENT is not None else _NULL


def begin(root: Path | None = None) -> Staging:
    """Open a session: every edit from now on lands in a scratch tree."""
    global _CURRENT
    if _CURRENT is not None:
        _CURRENT.discard()
    _CURRENT = Staging(root, Path(tempfile.mkdtemp(prefix="map_editor-")))
    return _CURRENT


def end() -> None:
    """Close the session, discarding anything not committed."""
    global _CURRENT
    if _CURRENT is not None:
        _CURRENT.discard()
    _CURRENT = None
