# dos_port/run-imfc.ps1 — Windows counterpart of dos_port/run-imfc.
#
# Launches with /IMFC and routes the game's music to DOSBox-X's
# BUILT-IN IMFC emulation. SFX and cries stay on the emulated
# OPL3, exactly like a real IMFC + Sound Blaster rig.
#
#   .\run-imfc.ps1 DEBUG_AUDIO=1 TRACK=MUSIC_PALLET_TOWN /LOOP

. (Join-Path $PSScriptRoot 'run-common.ps1')

$imfc = @"
[imfc]
imfc        = true
imfc_base   = 2a20
imfc_irq    = 3
imfc_filter = on
"@

Invoke-Run -Arguments $args -ExtraExeArgs @('/IMFC') -ExtraConf $imfc
