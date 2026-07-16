#!/usr/bin/env python3
"""buildprobe — ask GNU Make itself what the build is (label-DB plan S1).

The one source of truth for "which sources link" and "which NASM defines are
active". Both facts come from the SAME Make evaluation, so they cannot diverge
by construction (a NASM-only define with unchanged source membership is exactly
the divergence this design forbids).

Never parse the Makefile. Make evaluates its own conditionals, its own
`$(shell …)` computations (PIT_DIVISOR) and its own quoting; a second partial
Make evaluator is the same class of bug as the NASM one this plan fixes.

    probe()                      -> the default shipping config
    probe(['DEBUG_PARTY=1'])     -> an alternate config (report-only)

Mechanics:
  * `make --eval` injects a print target that exports the resolved LINK_SRCS /
    ALL_SRCS / NASMFLAGS into the recipe environment; a fixed helper recipe
    (no Make interpolation of the values) emits them as JSON. Nothing
    re-parses the values on the way out — `printf "$(NASMFLAGS)"` would strip
    the nested quoting from PLAYER_NAME="'NINTEN'".
  * The probe runs with a scrubbed environment so an ambient DEBUG_* or
    MAKEFLAGS cannot alter the shipping result.
  * Any probe failure, missing variable or unparsable -D token is a hard error:
    if the Makefile refactors its variable names the tool must break loudly,
    not drift.
"""

import json
import os
import re
import shlex
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DOS_PORT = os.path.normpath(os.path.join(HERE, '..'))
REPO_ROOT = os.path.normpath(os.path.join(HERE, '..', '..'))

PROBE_VARS = ('link', 'all', 'nasmflags')

# Injected makefile syntax. Recursive (`=`) assignment: --eval is evaluated
# BEFORE the makefile is read, so `:=` would capture the variables while they
# are still empty. Exported, so the recipe never interpolates their contents.
PROBE_MK = """
__probe_link = $(LINK_SRCS)
__probe_all = $(ALL_SRCS)
__probe_nasmflags = $(NASMFLAGS)
export __probe_link
export __probe_all
export __probe_nasmflags
__probe:
\t@$(__PROBE_PY) $(__PROBE_HELPER)
"""

IDENT_RE = re.compile(r'^[A-Za-z_?][A-Za-z0-9_?$#@~.]*$')


class ProbeError(RuntimeError):
    """The build configuration could not be resolved. Never recovered from."""


class BuildConfig:
    """One resolved build configuration.

    link      tuple of repo-relative paths that link into PKMN.EXE
    check     tuple of repo-relative paths that are assembled but not linked
    defines   {NAME: value} exactly as NASM receives them (valueless -> '1')
    includes  tuple of -I directories, in NASM search order
    """

    def __init__(self, link, all_srcs, nasmflags, defines, includes, config):
        self.link = link
        self.all = all_srcs
        self.check = tuple(p for p in all_srcs if p not in set(link))
        self.nasmflags = nasmflags
        self.defines = defines
        self.includes = includes
        self.config = tuple(config)

    @property
    def is_default(self):
        return not self.config


def _helper_main():
    """Recipe-side: dump the exported probe variables as JSON. No shell parsing."""
    out = {}
    for var in PROBE_VARS:
        key = '__probe_' + var
        if key not in os.environ:
            sys.exit(f'buildprobe: make did not export {key}')
        out[var] = os.environ[key]
    json.dump(out, sys.stdout)


def _run_make(config):
    env = {'PATH': '/usr/bin:/bin:/usr/local/bin', 'LC_ALL': 'C'}
    # The recipe is run by /bin/sh, so the two paths are shell-quoted here (the
    # repository path may contain spaces). The *probed values* never pass
    # through the shell — they travel in the environment.
    cmd = ['make', '-C', DOS_PORT, '-f', 'Makefile', '-s', '--no-print-directory',
           '--eval=' + PROBE_MK,
           '__PROBE_PY=' + shlex.quote(sys.executable),
           '__PROBE_HELPER=' + shlex.quote(os.path.join(HERE, 'buildprobe.py'))
           + ' --emit',
           *config, '__probe']
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, env=env)
    except OSError as exc:
        raise ProbeError(f'could not run make: {exc}') from exc
    if proc.returncode != 0:
        raise ProbeError('make probe failed (rc=%d): %s' %
                         (proc.returncode, (proc.stderr or proc.stdout).strip()))
    try:
        return json.loads(proc.stdout)
    except ValueError as exc:
        raise ProbeError('make probe emitted unparsable output: %r'
                         % proc.stdout[:400]) from exc


def parse_nasmflags(nasmflags):
    """Resolved NASMFLAGS -> ({define: value}, (include dirs,)).

    shlex.split is not a guess: Make hands the recipe to /bin/sh, so the shell
    is exactly what turns -D PLAYER_NAME="'NINTEN'" into NASM's argv entry
    -D PLAYER_NAME='NINTEN'. Anything shlex cannot split, nasm would not
    receive either.
    """
    try:
        tokens = shlex.split(nasmflags)
    except ValueError as exc:
        raise ProbeError(f'unparsable NASMFLAGS {nasmflags!r}: {exc}') from exc
    defines, includes = {}, []
    pending = None      # '-D' / '-I' awaiting its separate-token argument
    for tok in tokens:
        if pending:
            flag, pending = pending, None
            _take(flag, tok, defines, includes)
            continue
        if tok in ('-D', '-I', '-U'):
            pending = tok
        elif tok[:2] in ('-D', '-I', '-U') and len(tok) > 2:
            _take(tok[:2], tok[2:], defines, includes)
    if pending:
        raise ProbeError(f'NASMFLAGS ends with a bare {pending} token: {nasmflags!r}')
    return defines, tuple(includes)


def _take(flag, arg, defines, includes):
    if flag == '-I':
        includes.append(arg)
        return
    name, eq, value = arg.partition('=')
    if not IDENT_RE.match(name):
        raise ProbeError(f'unparsable {flag} token {arg!r} in NASMFLAGS')
    if flag == '-U':
        defines.pop(name, None)
        return
    # A valueless -D NAME is NASM-truthy: it defines NAME as 1.
    defines[name] = value if eq else '1'


def probe(config=()):
    """Resolve a build configuration by asking Make. Raises ProbeError."""
    raw = _run_make(list(config))
    for var in PROBE_VARS:
        if var not in raw:
            raise ProbeError(f'make probe did not report {var}')
    link = tuple('dos_port/' + p for p in raw['link'].split())
    all_srcs = tuple('dos_port/' + p for p in raw['all'].split())
    if not link:
        raise ProbeError('make probe reported an empty LINK_SRCS')
    if not set(link) <= set(all_srcs):
        missing = sorted(set(link) - set(all_srcs))
        raise ProbeError('LINK_SRCS is not a subset of ALL_SRCS: %s' % missing[:3])
    defines, includes = parse_nasmflags(raw['nasmflags'])
    if not includes:
        raise ProbeError('make probe reported no -I include directories')
    return BuildConfig(link, all_srcs, raw['nasmflags'], defines, includes,
                       config)


if __name__ == '__main__':
    if '--emit' in sys.argv:
        _helper_main()
    else:
        cfg = probe(sys.argv[1:])
        print('link: %d  check: %d' % (len(cfg.link), len(cfg.check)))
        print('includes: %s' % (cfg.includes,))
        print('defines: %s' % json.dumps(cfg.defines, indent=2, sort_keys=True))
