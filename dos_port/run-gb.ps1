# dos_port/run-gb.ps1 — Windows counterpart of dos_port/run-gb.
#
# Emulates a PC with a Creative CMS / Game Blaster: Sound Blaster and AdLib
# OFF, the CMS pair ON, and /GB on the game's command line. The CMS latch is
# write-only, so the flag IS the detection — see src/audio/cms_shim.asm.
# Music + SFX play on the SAA1099 pair; the Pikachu cry falls through to the
# PC-speaker PWM player (the SAA has no DAC). The PC speaker stays enabled as
# the PCM fallback path.
#
#   .\run-gb.ps1 DEBUG_AUDIO=1

. (Join-Path $PSScriptRoot 'run-common.ps1')

$gb = @"
[sblaster]
sbtype  = gb
oplmode = none

[speaker]
pcspeaker = true
"@

Invoke-Run -Arguments $args -ExtraExeArgs @('/GB') -ExtraConf $gb
