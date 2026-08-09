# dos_port/run.ps1 — Windows counterpart of dos_port/run.
#
# Builds PKMN.EXE and launches it in DOSBox-X. Args split by prefix: '/...'
# tokens become PKMN.EXE flags, everything else goes to make:
#   .\run.ps1 SKIP_TITLE=1
#   .\run.ps1 DEBUG_AUDIO=1 /LOOP /NOENH
# EXE flags: /NOSOUND /MT32 /GM /TANDY /SPK /NOENH /LOOP /FIXALL /FIXCRIT
# (see boot/entry.asm parse_cmdline).
#
# Unlike the bash `run`, C: is a mounted staging directory rather than the
# isolated PKMN.IMG — see run-common.ps1 for why, and docs/glitch_safety.md
# for what that costs.

. (Join-Path $PSScriptRoot 'run-common.ps1')
Invoke-Run -Arguments $args
