# dos_port/run-mt32.ps1 — Windows counterpart of dos_port/run-mt32.
#
# Launches with /MT32 and routes the game's MPU-401 output into DOSBox-X's
# BUILT-IN MUNT emulation (mididevice=mt32) — the same mechanism the bash
# script uses, and it is cross-platform. SFX and cries stay on the emulated
# OPL3, exactly like a real MT-32 + Sound Blaster rig.
#
# Needs the MT-32 ROM pair (MT32_CONTROL.ROM / MT32_PCM.ROM). These are Roland
# copyright: supply your own, nothing here can fetch them. Set MT32_ROMDIR, or
# drop them in dos_port\mt32-roms\.
#
#   $env:MT32_ROMDIR = 'C:\roms\mt32'
#   .\run-mt32.ps1 DEBUG_AUDIO=1 /LOOP        # music-only loop on MT-32

. (Join-Path $PSScriptRoot 'run-common.ps1')

$romDir = if ($env:MT32_ROMDIR) { $env:MT32_ROMDIR }
          else { Join-Path $PSScriptRoot 'mt32-roms' }

if (-not (Test-Path (Join-Path $romDir 'MT32_CONTROL.ROM'))) {
    throw @"
No MT32_CONTROL.ROM in $romDir

Set MT32_ROMDIR to the directory holding MT32_CONTROL.ROM and MT32_PCM.ROM,
or place them in dos_port\mt32-roms\. They are Roland copyright and are not
distributed with this project.
"@
}

$midi = @"
[midi]
mpu401      = intelligent
mididevice  = mt32
mt32.romdir = $romDir
"@

Invoke-Run -Arguments $args -ExtraExeArgs @('/MT32') -ExtraConf $midi
