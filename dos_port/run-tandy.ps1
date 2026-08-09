# dos_port/run-tandy.ps1 — Windows counterpart of dos_port/run-tandy.
#
# Emulates a Tandy 1000: Sound Blaster and AdLib OFF, the SN76489 3-voice PSG
# ON, and /TANDY on the game's command line. The PSG is write-only, so the flag
# IS the detection — see src/audio/tandy_shim.asm. Music + SFX play on the PSG;
# the Pikachu cry falls through to the PC-speaker PWM player (a real Tandy has
# no DSP).
#
#   .\run-tandy.ps1 DEBUG_AUDIO=1

. (Join-Path $PSScriptRoot 'run-common.ps1')

$tandy = @"
[sblaster]
sbtype  = none
oplmode = none

[speaker]
tandy = on
"@

Invoke-Run -Arguments $args -ExtraExeArgs @('/TANDY') -ExtraConf $tandy
