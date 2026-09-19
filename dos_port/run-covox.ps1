# dos_port/run-covox.ps1 — Windows counterpart of dos_port/run-covox.
#
# Emulates a sound-card-less machine with a Covox Speech Thing / Disney Sound
# Source on LPT1: Sound Blaster and AdLib OFF, the LPT DAC ON, and /COVOX on
# the game's command line. The DAC is write-only, so the flag IS the detection
# — see src/audio/covox_shim.asm. Music + SFX render as PCM on the DAC; the
# Pikachu cry resamples its blob to the DAC too (g_covox_rate, default 7 kHz).
# The PC speaker stays enabled as the PCM fallback path.
#
#   .\run-covox.ps1 DEBUG_AUDIO=1

. (Join-Path $PSScriptRoot 'run-common.ps1')

$covox = @"
[sblaster]
sbtype  = none
oplmode = none

[speaker]
disney = true
pcspeaker = true
"@

Invoke-Run -Arguments $args -ExtraExeArgs @('/COVOX') -ExtraConf $covox
