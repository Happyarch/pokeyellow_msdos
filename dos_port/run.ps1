# dos_port/run.ps1 — Windows counterpart of dos_port/run.
#
# Builds PKMN.EXE and launches it in DOSBox-X. This is the ONE Windows
# launcher: the per-device run-<x>.ps1 wrappers are gone, folded into the
# device table in run-common.ps1 (Get-DeviceConf), exactly as the bash
# run-<x> wrappers were folded into dos_port/run.
#
# Three argument namespaces, same as bash:
#   /FLAG         -> PKMN.EXE inside DOS
#   -FLAG --FLAG  -> DOSBox-X itself
#   name=value    -> make
#   --            -> everything after goes to make
#   --help / --dry-run
#
#   .\run.ps1 SKIP_TITLE=1
#   .\run.ps1 DEBUG_AUDIO=1 /LOOP /NOENH
#   .\run.ps1 /MT32 DEBUG_AUDIO=1 /LOOP
#   .\run.ps1 /GB -fullscreen
#
# Devices: /MT32 /TANDY /INNOVA /COVOX /GB /PAS /IMFC /SPK. (PAS needs a
# DOSBox-X build with PAS support; the system build may not have it.)
#
# Unlike the bash `run`, C: is a mounted staging directory rather than the
# isolated PKMN.IMG — see run-common.ps1 for why, and docs/glitch_safety.md
# for what that costs.

. (Join-Path $PSScriptRoot 'run-common.ps1')
# Guard the launch so this file can be dot-sourced for testing without starting
# DOSBox-X (dot-sourcing sets InvocationName to '.').
if ($MyInvocation.InvocationName -ne '.') {
    Invoke-Run -Arguments $args
}
