#!/usr/bin/env python3
"""Bootstrap the Windows build toolchain for the Pokemon Yellow DOS port.

Fetches NASM and a Windows-hosted DJGPP cross-binutils into a project-local
`.toolchain/` directory, verifies every download against a pinned SHA-256, and
writes `activate.bat` / `activate.ps1` that put them on PATH for one shell.

Nothing is installed system-wide, no registry keys are touched, and no
environment variable outside the activated shell is modified. Delete
`.toolchain/` to uninstall.

Usage (from anywhere in the repo):

    python dos_port/tools/setup_toolchain.py            # download + install
    python dos_port/tools/setup_toolchain.py --check    # what is already here
    python dos_port/tools/setup_toolchain.py --print-only
    python dos_port/tools/setup_toolchain.py --force    # re-download

LICENSING: this script DOWNLOADS from each project's own distribution server at
the time you run it; it does not redistribute anything. You receive NASM,
binutils and friends directly from their publishers under their own licenses
(NASM: BSD-2-Clause; binutils: GPLv3). That is the whole reason the toolchain
is fetched rather than vendored into this repository -- see the "Legal note"
section in README.md. Do not "simplify" this by committing the archives.
"""

from __future__ import annotations

import argparse
import hashlib
import os
import platform
import shutil
import subprocess
import sys
import tarfile
import tempfile
import urllib.error
import urllib.request
import zipfile
from pathlib import Path

# --------------------------------------------------------------------------
# Pinned upstream artifacts.
#
# Every hash below was computed by downloading the file (2026-08-09) and
# running sha256sum on it -- they are measured, not transcribed from a
# checksum page. To bump a version: change url/sha256/size together, re-run
# with --force, and confirm the post-install `--check` still passes.
# --------------------------------------------------------------------------

PACKAGES = {
    "nasm": {
        "desc": "NASM 3.02 assembler (win64)",
        "url": "https://www.nasm.us/pub/nasm/releasebuilds/3.02/win64/nasm-3.02-win64.zip",
        "sha256": "161d0bfaff53c2f9e9f3e69fd0672323ebabafd1268976a5cec11be92a19aee7",
        "size": 641314,
        "license": "BSD-2-Clause",
        # Directory inside the archive whose contents become <root>/nasm/.
        "strip_prefix": "nasm-3.02/",
        # Relative to the package dir; also what lands on PATH.
        "bindir": "",
        "probe": "nasm.exe",
    },
    "rgbds": {
        # Needed to BOOTSTRAP a fresh clone, not to rebuild the EXE: the 585
        # .2bpp tileset graphics and ~693 of the 714 dos_port/assets/*.inc are
        # generated, not committed. Version is pinned by .rgbds-version (1.0.2);
        # upstream tags it v1.0.2+hotfix.
        "desc": "rgbds 1.0.2 (win64) -- assembles the reference ROM + renders .2bpp",
        "url": (
            "https://github.com/gbdev/rgbds/releases/download/"
            "v1.0.2%2Bhotfix/rgbds-win64.zip"
        ),
        "sha256": "51d5371ebf86c18c136a5c7616dd2fb350f537abd13f5603c7fb56b3e73fa4da",
        "size": 1104438,
        "license": "MIT",
        "strip_prefix": "",
        "bindir": "bin",
        "probe": "rgbasm.exe",
    },
    "cwsdpmi": {
        # The DPMI host the DJGPP stub auto-loads. Needed to RUN, not to build,
        # and it is gitignored rather than committed -- so a Windows user has no
        # copy at all until this fetches one. The binary here is byte-identical
        # to the CWSDPMI.EXE this repo has been running against (verified by
        # sha256 2026-08-09).
        "desc": "CWSDPMI r7 (DPMI host -- required to run PKMN.EXE)",
        "url": "http://www.delorie.com/pub/djgpp/current/v2misc/csdpmi7b.zip",
        "sha256": "deacda0488e1cdd7c4a9f32fab45662b34c0ed6b2d7d4d13bc07041b62004a8c",
        "size": 71339,
        "license": "GPL, or binary redistribution under the terms in cwsdpmi.doc",
        "strip_prefix": "",
        "bindir": "bin",
        "probe": "CWSDPMI.EXE",
        # A DOS executable: it belongs next to PKMN.EXE inside the emulator,
        # not on the Windows PATH.
        "on_path": False,
    },
    "djgpp": {
        # binutils version is what `ld --version` reports, not what the
        # archive name suggests (the gcc1220 in the filename is the *gcc*
        # version; the bundled ld is 2.30).
        "desc": "DJGPP cross-binutils 2.30 (MinGW-hosted, build-djgpp v3.4)",
        "url": (
            "https://github.com/andrewwutw/build-djgpp/releases/download/"
            "v3.4/djgpp-mingw-gcc1220-standalone.zip"
        ),
        "sha256": "6f88b531d216f4d92668c960b5cde9a829b5611e06d2c3e431041e33f01c1a52",
        "size": 126821837,
        "license": "GPLv3 (binutils)",
        "strip_prefix": "djgpp/",
        "bindir": "bin",
        "probe": "i586-pc-msdosdjgpp-ld.exe",
    },
}

# Linux/WSL needs only rgbds from here: nasm and binutils-djgpp are packaged by
# every mainstream distro, but rgbds is NOT in Ubuntu's repos, and where a distro
# does package it the version is wrong -- .rgbds-version pins 1.0.2 exactly.
# These are statically-linked binaries, so they run on any x86-64 distro.
LINUX_PACKAGES = {
    # CWSDPMI is a DOS binary -- the host OS is irrelevant, DOSBox-X runs it
    # either way -- and `make image` needs it to build PKMN.IMG. Leaving it out
    # of this set (until 2026-08-09) meant a Linux user got all the way to
    # "Built: PKMN.EXE" and then hit
    #     make: *** No rule to make target 'CWSDPMI.EXE', needed by 'image'.
    "cwsdpmi": {
        "desc": "CWSDPMI r7 (DPMI host -- required to run PKMN.EXE)",
        "url": "http://www.delorie.com/pub/djgpp/current/v2misc/csdpmi7b.zip",
        "sha256": "deacda0488e1cdd7c4a9f32fab45662b34c0ed6b2d7d4d13bc07041b62004a8c",
        "size": 71339,
        "license": "GPL, or binary redistribution under the terms in cwsdpmi.doc",
        "strip_prefix": "",
        "bindir": "bin",
        "probe": "CWSDPMI.EXE",
        "on_path": False,
    },
    "rgbds": {
        "desc": "rgbds 1.0.2 (linux x86_64, static)",
        "url": (
            "https://github.com/gbdev/rgbds/releases/download/"
            "v1.0.2%2Bhotfix/rgbds-linux-x86_64.tar.xz"
        ),
        "sha256": "b13d97db79095fb99372fab8e75d024b7bffbd9485b3cd1d0a6cbf2d2badfbf9",
        "size": 1401412,
        "license": "MIT",
        "strip_prefix": "",
        "bindir": "",          # the tarball is flat -- binaries at the root
        "probe": "rgbasm",
    },
}

# The Makefile's LD default is `i386-pc-msdosdjgpp-ld`, but every prebuilt
# toolchain ships only the `i586-` names. OBJDUMP's default is already `i586-`.
MAKE_OVERRIDES = {"LD": "i586-pc-msdosdjgpp-ld"}

CHUNK = 1 << 16


def repo_root() -> Path:
    """dos_port/tools/setup_toolchain.py -> repository root."""
    return Path(__file__).resolve().parent.parent.parent


def human(n: int) -> str:
    for unit in ("B", "KB", "MB", "GB"):
        if n < 1024 or unit == "GB":
            return f"{n:.0f} {unit}" if unit == "B" else f"{n:.1f} {unit}"
        n /= 1024.0
    return f"{n:.1f} GB"


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for block in iter(lambda: fh.read(CHUNK), b""):
            h.update(block)
    return h.hexdigest()


def download(url: str, dest: Path, expect_size: int) -> None:
    """Stream `url` to `dest`, showing progress. Writes via a temp file."""
    dest.parent.mkdir(parents=True, exist_ok=True)
    tmp = dest.with_suffix(dest.suffix + ".part")
    req = urllib.request.Request(url, headers={"User-Agent": "pokeyellow-dos-setup"})
    with urllib.request.urlopen(req) as resp, tmp.open("wb") as out:
        total = int(resp.headers.get("Content-Length") or expect_size or 0)
        done = 0
        while True:
            block = resp.read(CHUNK)
            if not block:
                break
            out.write(block)
            done += len(block)
            if total and sys.stdout.isatty():
                pct = 100.0 * done / total
                print(f"\r    {pct:5.1f}%  {human(done)} / {human(total)}", end="")
        if total and sys.stdout.isatty():
            print()
    tmp.replace(dest)


def fetch_verified(name: str, pkg: dict, cache: Path, force: bool) -> Path:
    """Return a path to the archive, downloading it if needed. Verifies SHA-256."""
    archive = cache / pkg["url"].rsplit("/", 1)[-1]

    if archive.exists() and not force:
        print(f"  cached   {archive.name}")
    else:
        print(f"  fetching {pkg['desc']}")
        print(f"           {pkg['url']}")
        try:
            download(pkg["url"], archive, pkg["size"])
        except urllib.error.URLError as exc:
            raise SystemExit(
                f"\nerror: could not download {name}: {exc}\n"
                f"       URL: {pkg['url']}\n"
                f"       Download it by hand into {cache} and re-run."
            )

    actual = sha256_file(archive)
    if actual != pkg["sha256"]:
        archive.unlink(missing_ok=True)
        raise SystemExit(
            f"\nerror: checksum mismatch for {archive.name} -- discarded.\n"
            f"       expected {pkg['sha256']}\n"
            f"       actual   {actual}\n"
            "       Either upstream re-cut the release (bump the pin in this\n"
            "       script after verifying by hand) or the download is corrupt\n"
            "       or tampered with. Not extracting."
        )
    print(f"  verified sha256 {actual[:16]}...")
    return archive


def extract(archive: Path, target: Path, strip_prefix: str) -> None:
    """Extract `archive` into `target`, stripping a leading directory.

    Extraction goes to a temp dir next to the target and is then moved into
    place, so an interrupted run never leaves a half-populated toolchain that
    a later --check would call healthy.
    """
    if target.exists():
        shutil.rmtree(target)
    target.parent.mkdir(parents=True, exist_ok=True)
    staging = Path(tempfile.mkdtemp(dir=target.parent, prefix=".stage-"))
    try:
        if archive.name.endswith((".tar.xz", ".tar.gz", ".tar.bz2")):
            _extract_tar(archive, staging, strip_prefix)
            staging.replace(target)
            return
        with zipfile.ZipFile(archive) as zf:
            for info in zf.infolist():
                name = info.filename
                if strip_prefix:
                    if not name.startswith(strip_prefix):
                        continue
                    name = name[len(strip_prefix):]
                if not name:
                    continue
                # Refuse absolute paths and traversal (zip-slip).
                out = (staging / name).resolve()
                if not str(out).startswith(str(staging.resolve())):
                    raise SystemExit(f"error: unsafe path in {archive.name}: {info.filename}")
                if info.is_dir():
                    out.mkdir(parents=True, exist_ok=True)
                    continue
                out.parent.mkdir(parents=True, exist_ok=True)
                with zf.open(info) as src, out.open("wb") as dst:
                    shutil.copyfileobj(src, dst)
                # Zip has no POSIX bits on Windows; restore the exec bit
                # elsewhere so a Linux smoke-test of this script behaves.
                if os.name != "nt" and (info.external_attr >> 16) & 0o111:
                    out.chmod(out.stat().st_mode | 0o755)
        staging.replace(target)
    finally:
        if staging.exists():
            shutil.rmtree(staging, ignore_errors=True)


def _extract_tar(archive: Path, staging: Path, strip_prefix: str) -> None:
    """Tar counterpart of extract(), same zip-slip refusal, modes preserved.

    Unix modes matter here in a way they don't for the zips: the rgbds tarball
    carries the executable bit, and without it the binaries are unrunnable.
    """
    with tarfile.open(archive) as tf:
        for member in tf.getmembers():
            name = member.name
            if strip_prefix:
                if not name.startswith(strip_prefix):
                    continue
                name = name[len(strip_prefix):]
            if not name:
                continue
            out = (staging / name).resolve()
            if not str(out).startswith(str(staging.resolve())):
                raise SystemExit(f"error: unsafe path in {archive.name}: {member.name}")
            if member.isdir():
                out.mkdir(parents=True, exist_ok=True)
                continue
            if not member.isfile():
                continue          # skip links/devices rather than trust them
            out.parent.mkdir(parents=True, exist_ok=True)
            src = tf.extractfile(member)
            if src is None:
                continue
            with src, out.open("wb") as dst:
                shutil.copyfileobj(src, dst)
            out.chmod(member.mode & 0o777)


def bin_path(root: Path, name: str, pkg: dict) -> Path:
    return root / name / pkg["bindir"] if pkg["bindir"] else root / name


def probe_path(root: Path, name: str, pkg: dict) -> Path:
    return bin_path(root, name, pkg) / pkg["probe"]


def write_self_ignore(root: Path) -> Path:
    """Make the toolchain directory ignore its own contents.

    The repo's root .gitignore already lists `.toolchain/`, but this does not
    depend on it: a self-ignoring directory stays isolated even when installed
    somewhere else via --dest, when the root rule is edited, or when someone
    copies this script into another tree. `*` matches everything here
    including this file, so nothing under the toolchain root is ever
    committable -- which is the whole point, since these are third-party GPL
    and BSD binaries we download rather than redistribute.
    """
    root.mkdir(parents=True, exist_ok=True)
    ignore = root / ".gitignore"
    ignore.write_text(
        "# Written by dos_port/tools/setup_toolchain.py.\n"
        "# Downloaded third-party toolchain -- never commit any of it.\n"
        "# See the \"Legal note\" in README.md.\n"
        "*\n",
        encoding="ascii",
    )
    return ignore


def write_activators(root: Path, order: list[str]) -> tuple[Path, Path]:
    """Write activate.bat / activate.ps1 that prepend the tool dirs to PATH."""
    dirs = [
        bin_path(root, n, PACKAGES[n])
        for n in order
        if PACKAGES[n].get("on_path", True)
    ]

    bat = root / "activate.bat"
    bat.write_text(
        "@echo off\r\n"
        "REM Generated by dos_port/tools/setup_toolchain.py -- do not edit.\r\n"
        "REM Adds the project-local toolchain to PATH for THIS shell only.\r\n"
        + "".join(f'set "PATH={d};%PATH%"\r\n' for d in dirs)
        + "echo Toolchain active. Build with:\r\n"
        f"echo     make -C dos_port PKMN.EXE {fmt_overrides()}\r\n",
        encoding="ascii",
    )

    ps1 = root / "activate.ps1"
    ps1.write_text(
        "# Generated by dos_port/tools/setup_toolchain.py -- do not edit.\n"
        "# Adds the project-local toolchain to PATH for THIS session only.\n"
        + "".join(f'$env:PATH = "{d};" + $env:PATH\n' for d in dirs)
        + 'Write-Host "Toolchain active. Build with:"\n'
        f'Write-Host "    make -C dos_port PKMN.EXE {fmt_overrides()}"\n',
        encoding="ascii",
    )
    return bat, ps1


def fmt_overrides() -> str:
    return " ".join(f"{k}={v}" for k, v in MAKE_OVERRIDES.items())


def check(root: Path, verbose: bool = True) -> bool:
    """Report which components are present and runnable. Returns True if all are."""
    ok = True
    for name, pkg in PACKAGES.items():
        exe = probe_path(root, name, pkg)
        if not exe.exists():
            if verbose:
                print(f"  [ ] {name:<7} missing ({pkg['desc']})")
            ok = False
            continue
        ver = ""
        if platform.system() == "Windows":
            try:
                out = subprocess.run(
                    [str(exe), "--version"],
                    capture_output=True, text=True, timeout=30,
                )
                ver = (out.stdout or out.stderr).splitlines()[0].strip() if (
                    out.stdout or out.stderr
                ) else ""
            except (OSError, subprocess.SubprocessError, IndexError):
                ver = "(present, but would not run --version)"
        if verbose:
            print(f"  [x] {name:<7} {ver or exe}")
    return ok


def check_host_tools() -> list[str]:
    """Things this script deliberately does NOT install. Returns missing names.

    These are all system-wide installs (a package manager, a compiler toolchain,
    pip into the user's environment). Fetching a pinned archive into a local
    directory is one thing; mutating the user's system is another, and this
    script does not do the second. It reports instead.
    """
    missing = []
    for tool, hint in (
        ("make", "MSYS2: pacman -S make   (or GnuWin32 make)"),
        ("git", "https://git-scm.com/download/win"),
        # Only needed to bootstrap assets on a fresh clone: pret's Makefile
        # builds tools/gfx, tools/scan_includes and tools/make_patch from C.
        ("gcc", "MSYS2: pacman -S gcc     (fresh-clone asset build only)"),
    ):
        if shutil.which(tool) is None:
            missing.append(f"{tool:<7} -- {hint}")

    # The complete third-party set the asset build imports, measured by walking
    # every generator dos_port/Makefile invokes -- PIL decodes the font/HUD
    # PNGs, numpy builds the Pikachu PCM, yaml reads the audio sidecars. numpy
    # was missing from this list until 2026-08-09 and imports unguarded in
    # tools/audio/gen_pika_pcm.py, so its absence was a raw traceback.
    for mod, hint in (
        ("PIL", "pip install pillow       (fresh-clone asset build only)"),
        ("numpy", "pip install numpy        (fresh-clone asset build only)"),
        ("yaml", "pip install pyyaml       (fresh-clone asset build only)"),
    ):
        try:
            __import__(mod)
        except ImportError:
            missing.append(f"{mod:<7} -- {hint}")
    return missing


def assets_present() -> bool | None:
    """Best-effort: does this clone already have generated assets?

    Returns None if the layout can't be inspected. Used only to decide which
    advice to print -- never to skip work.
    """
    gen = repo_root() / "dos_port" / "assets"
    if not gen.is_dir():
        return None
    # 21 .inc files are tracked; a bootstrapped tree has hundreds.
    return len(list(gen.rglob("*.inc"))) > 50


def print_plan(root: Path) -> None:
    print("This script would download, verify and extract:\n")
    total = 0
    for name, pkg in PACKAGES.items():
        total += pkg["size"]
        print(f"  {name}")
        print(f"    {pkg['desc']}")
        print(f"    url      {pkg['url']}")
        print(f"    sha256   {pkg['sha256']}")
        print(f"    size     {human(pkg['size'])}")
        print(f"    license  {pkg['license']}")
        print(f"    into     {root / name}")
        print()
    print(f"Total download: {human(total)}")
    print(f"Nothing is installed system-wide. Remove {root} to uninstall.")


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Install the Windows build toolchain for the DOS port.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    ap.add_argument("--dest", type=Path, default=None,
                    help="install root (default: <repo>/.toolchain)")
    ap.add_argument("--print-only", action="store_true",
                    help="show what would be downloaded, from where, and exit")
    ap.add_argument("--check", action="store_true",
                    help="report what is already installed and exit")
    ap.add_argument("--force", action="store_true",
                    help="re-download and re-extract even if present")
    ap.add_argument("--keep-archives", action="store_true",
                    help="keep the downloaded .zip files in .toolchain/downloads")
    ap.add_argument("--skip-platform-check", action="store_true",
                    help="run on a non-Windows host (for testing this script)")
    args = ap.parse_args()

    root = (args.dest or (repo_root() / ".toolchain")).resolve()

    # Pick the package set BEFORE --print-only / --check, so those report what
    # this host would actually install rather than always the Windows set.
    global PACKAGES
    if platform.system() == "Linux" and not args.skip_platform_check:
        PACKAGES = LINUX_PACKAGES

    if args.print_only:
        print_plan(root)
        return 0

    if args.check:
        print(f"Toolchain root: {root}")
        allgood = check(root)
        missing = check_host_tools()
        if missing:
            print("\nNot provided by this script (install separately):")
            for m in missing:
                print(f"  - {m}")
        return 0 if allgood else 1

    system = platform.system()

    # MSYS2 / Cygwin Python reports MSYS_NT-* / CYGWIN_NT-* / MINGW*, not
    # "Windows", and its pathlib emits POSIX paths (/c/Users/...). Forcing it
    # through would write an activate.bat full of paths cmd.exe cannot use, so
    # this is a hard stop with the right instruction rather than the Linux
    # advice below -- which is what a bare `!= "Windows"` check used to print.
    if system.startswith(("MSYS", "MINGW", "CYGWIN")):
        print(
            f"Detected {system} Python (MSYS2/Cygwin).\n"
            "\n"
            "Run this with WINDOWS Python from PowerShell or cmd instead:\n"
            "    python dos_port\\tools\\setup_toolchain.py\n"
            "\n"
            "It installs Windows binaries and writes Windows paths into\n"
            "activate.bat / activate.ps1; MSYS2 Python would write POSIX paths\n"
            "(/c/Users/...) that cmd.exe cannot use.\n"
            "\n"
            "Use your MSYS2 shell for the `make` steps -- that is where the\n"
            "build needs python3 and gcc, which Windows Python does not provide.",
            file=sys.stderr,
        )
        return 2

    if system == "Linux" and not args.skip_platform_check:
        # Linux/WSL: nasm and binutils-djgpp come from the distro, but rgbds
        # does NOT -- it is absent from Ubuntu's repos entirely, and any distro
        # that does package it ships a version other than the pinned 1.0.2.
        # So install just that, rather than refusing and leaving the user to
        # hand-assemble a tarball.
        print(
            "Linux/WSL detected. Install these from your package manager:\n"
            "    Debian/Ubuntu:  sudo apt install nasm binutils-djgpp python3 "
            "gcc make python3-pil python3-yaml\n"
            "    Other distros:  https://github.com/andrewwutw/build-djgpp "
            "for the DJGPP cross-toolchain\n"
            "\n"
            "rgbds is NOT packaged by Ubuntu and must match .rgbds-version"
            " (1.0.2),\nso this script fetches it below.\n"
        )

    elif system != "Windows" and not args.skip_platform_check:
        print(
            "This script installs the *Windows* toolchain.\n"
            "\n"
            "On macOS: https://github.com/andrewwutw/build-djgpp (osx release),\n"
            "and rgbds 1.0.2 from https://github.com/gbdev/rgbds/releases\n"
            "\n"
            "Pass --skip-platform-check to run it here anyway.",
            file=sys.stderr,
        )
        return 2

    cache = root / "downloads"
    print(f"Installing the DOS-port toolchain into {root}\n")

    # Before the first byte is downloaded, so a partial or interrupted run can
    # never leave un-ignored archives lying around inside the repo.
    write_self_ignore(root)

    order = list(PACKAGES)
    for name in order:
        pkg = PACKAGES[name]
        exe = probe_path(root, name, pkg)
        print(f"{name}: {pkg['desc']}")
        if exe.exists() and not args.force:
            print(f"  present  {exe}")
            print("  (--force to reinstall)\n")
            continue
        archive = fetch_verified(name, pkg, cache, args.force)
        print(f"  extracting -> {root / name}")
        extract(archive, root / name, pkg["strip_prefix"])
        if not exe.exists():
            raise SystemExit(
                f"error: {pkg['probe']} not found after extracting {archive.name}.\n"
                "       The archive layout changed upstream; the strip_prefix/bindir\n"
                "       pins in this script need updating."
            )
        if not args.keep_archives:
            archive.unlink(missing_ok=True)
        print()

    print("Installed:")
    check(root)

    if system == "Linux":
        # No .bat/.ps1 here -- give the shell line that actually works.
        dirs = [bin_path(root, n, PACKAGES[n]) for n in order
                if PACKAGES[n].get("on_path", True)]
        print("\nPut it on PATH for this shell:")
        print(f"    export PATH=\"{':'.join(str(d) for d in dirs)}:$PATH\"")
        print("\nThen bootstrap the assets and build:")
        print("    make                     # renders the .2bpp via rgbds")
        print("    make -C dos_port assets")
        print("    make -C dos_port")
    else:
        bat, ps1 = write_activators(root, order)
        print("\nActivate the toolchain for a shell:")
        print(f"    cmd.exe:      {bat}")
        print(f"    PowerShell:   . {ps1}")
        print("\nThen build:")
        print(f"    make -C dos_port PKMN.EXE {fmt_overrides()}")
        print("\nCopy PKMN.EXE and CWSDPMI.EXE into your DOSBox-X mount and run PKMN.")

    missing = check_host_tools()
    if missing:
        print("\nStill needed (this script does not install these):")
        for m in missing:
            print(f"  - {m}")

    if assets_present() is False:
        print(
            "\nNOTE: this clone has no generated assets yet, so `make PKMN.EXE`\n"
            "      will fail with \"unable to open include file 'assets/...'\".\n"
            "      The .2bpp graphics and most assets/*.inc are generated, not\n"
            "      committed. Bootstrap them first (needs make + gcc + Pillow +\n"
            "      PyYAML, all above):\n"
            "          git submodule update --init --recursive\n"
            "          make                       # renders the .2bpp via rgbds\n"
            "          make -C dos_port assets\n"
            "      That chain is the least-tested part of the native Windows\n"
            "      route -- WSL is the reliable way to do a first bootstrap.\n"
            "      Once assets exist, rebuilding PKMN.EXE natively is fine."
        )

    print(f"\nAll of it is git-ignored ({root / '.gitignore'} ignores `*`).")
    print(f"To uninstall, delete {root}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
