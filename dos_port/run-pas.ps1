# dos_port/run-pas.ps1 — Windows counterpart of dos_port/run-pas.
#
# Emulates a PC with a Pro Audio Spectrum 16: Sound Blaster and AdLib OFF,
# and /PAS on the game's command line. The card's mixer is write-only from
# the driver's chair, so the flag IS the detection — see
# src/audio/pas_shim.asm. Music + SFX play on the card's OPL3 at 0x388; the
# Pikachu cry falls through to the PC-speaker PWM player (the G1 tick voices
# FM only, no PCM path). The PC speaker stays enabled as the PCM fallback path.
#
#   .\run-pas.ps1 DEBUG_AUDIO=1

. (Join-Path $PSScriptRoot 'run-common.ps1')

$pas = @"
[sblaster]
sbtype  = none
oplmode = none

[speaker]
pcspeaker = true
"@

Invoke-Run -Arguments $args -ExtraExeArgs @('/PAS') -ExtraConf $pas
