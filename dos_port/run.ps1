# dos_port/run.ps1 — Windows counterpart of dos_port/run.
#
# Builds PKMN.EXE and launches it in DOSBox-X. Args split by prefix: '/...'
# tokens become PKMN.EXE flags, everything else goes to make:
#   .\run.ps1 SKIP_TITLE=1
#   .\run.ps1 DEBUG_AUDIO=1 /LOOP /NOENH
# EXE flags: /NOSOUND /MT32 /GM /TANDY /INNOVA /COVOX /GB /PAS /SPK /NOENH /LOOP /NODMA
# (bug-fix level is a BUILD-time make flag, BUG_FIX_LEVEL=1|2 — there is no runtime flag)
# (see boot/entry.asm parse_cmdline).
#
# Unlike the bash `run`, C: is a mounted staging directory rather than the
# isolated PKMN.IMG — see run-common.ps1 for why, and docs/glitch_safety.md
# for what that costs.

. (Join-Path $PSScriptRoot 'run-common.ps1')
Invoke-Run -Arguments $args
