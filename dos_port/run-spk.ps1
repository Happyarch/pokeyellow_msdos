# dos_port/run-spk.ps1 — Windows counterpart of dos_port/run-spk.
#
# Sound Blaster emulation OFF, so the Pikachu PCM path falls through to the
# PC-speaker PWM player (spk_pcm.asm). The AdLib at 388h stays by default —
# music/SFX keep playing on FM and only the cry moves to the speaker, which is
# the useful A/B against run.ps1's SB direct-mode cry.
#
# SPK_ONLY=1 removes the OPL too: a true speaker-only machine, silent except
# the PWM cry.
#
#   .\run-spk.ps1 DEBUG_AUDIO=1
#   $env:SPK_ONLY = '1'; .\run-spk.ps1 DEBUG_AUDIO=1

. (Join-Path $PSScriptRoot 'run-common.ps1')

$oplMode = if ($env:SPK_ONLY) { 'none' } else { 'opl3' }

$sb = @"
[sblaster]
sbtype  = none
oplmode = $oplMode
"@

Invoke-Run -Arguments $args -ExtraConf $sb
