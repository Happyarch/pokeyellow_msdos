# dos_port/run-common.ps1 — shared implementation behind run.ps1 and build.ps1.
# Dot-source it; do not invoke it directly.
#
# run.ps1 is the ONE Windows launcher (the per-device run-<x>.ps1 wrappers are
# gone — they were the same file with a different conf snippet, mirroring the
# bash wrappers that were folded into dos_port/run). The device table lives
# here in Get-DeviceConf so sh and ps1 stay in step; see dos_port/run for the
# canonical argument namespaces.
#
# These are the Windows counterparts of the bash `run*` scripts, and they differ
# from them in ONE structural way that matters:
#
#   bash:  make image  ->  imgmount c PKMN.IMG -t hdd -fs fat
#   here:  make PKMN.EXE ->  mount c <staging dir>
#
# PKMN.IMG is built with sfdisk + mkfs.fat + mcopy, none of which exist on
# Windows. So C: is a real host directory instead of an isolated FAT image.
# That is a genuine loss of containment -- see Show-IsolationWarning below and
# docs/glitch_safety.md. The staging directory keeps the blast radius as small
# as it can be: the game sees ONLY PKMN.EXE, CWSDPMI.EXE and its own save,
# never the repository.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:DosPort = Split-Path -Parent $PSCommandPath
$script:RepoRoot = Split-Path -Parent $script:DosPort
$script:Toolchain = Join-Path $script:RepoRoot '.toolchain'
# Files the game writes that we want back on the host after a run.
$script:DumpFiles = @('FRAME.BIN', 'DUMP.BIN', 'GBSTATE.BIN', 'PERF.BIN',
                      'SEAMLOG.BIN', 'PAL.BIN', 'POKEMON.DSV')

function Split-RunArgs {
    <#
      Three argument namespaces, matching the bash dos_port/run:
        /FLAG         -> PKMN.EXE inside DOS            (Exe)
        -FLAG --FLAG  -> DOSBox-X itself                (Host)
        name / name=  -> make                           (Make)
        --            -> everything after goes to make
        --help        -> Help ;  --dry-run -> DryRun
      A host flag's value is the next token when it has no '=' (so
      `-c "mount c ."` works):
        run.ps1 SKIP_TITLE=1 DEBUG_AUDIO=1 /LOOP -fullscreen
    #>
    param([string[]]$Arguments = @())
    $exe = @(); $make = @(); $hostArgs = @()
    $sep = $false; $hostValue = $false; $help = $false; $dry = $false
    foreach ($a in $Arguments) {
        if ($sep) { $make += $a; continue }
        if ($a -eq '--')        { $sep = $true;  continue }
        if ($a -eq '--help')    { $help = $true; continue }
        if ($a -eq '--dry-run') { $dry = $true;  continue }
        if ($a.StartsWith('/')) { $exe += $a; $hostValue = $false; continue }
        if ($a.StartsWith('-')) { $hostArgs += $a; $hostValue = $true; continue }
        if ($hostValue -and ($a -notmatch '=')) { $hostArgs += $a } else { $make += $a }
        $hostValue = $false
    }
    return @{ Exe = $exe; Make = $make; Host = $hostArgs; Help = $help; DryRun = $dry }
}

$script:DeviceFlags = @('MT32', 'TANDY', 'INNOVA', 'COVOX', 'GB', 'PAS', 'IMFC', 'SPK')

function Show-RunUsage {
    Write-Host @'
dos_port/run.ps1 — build + launch PKMN.EXE in DOSBox-X.

  .\run.ps1 [make args] [/EXE flags] [-dosbox-x flags]

  /FLAG          passed to PKMN.EXE inside DOS (e.g. /LOOP /NOENH)
  -FLAG --FLAG   passed to DOSBox-X itself (e.g. -fullscreen)
  name=value     passed to make (e.g. SKIP_TITLE=1 DEBUG_AUDIO=1)
  --             everything after this goes to make, verbatim

  /MT32 /TANDY /INNOVA /COVOX /GB /PAS /IMFC /SPK   pick a hardware config
  --dry-run      print the generated conf + emulator command, do not launch
  --help         this message
'@
}

function Resolve-Device {
    <# First device flag in $ExeArgs wins; two different ones is an error.
       /SPK is a launcher selector only and is NOT forwarded (the game's own
       /SPK would force the speaker shim and take music off the AdLib). #>
    param([string[]]$ExeArgs = @())
    $name = ''
    foreach ($a in $ExeArgs) {
        if ($a.Length -lt 2 -or $a[0] -ne '/') { continue }
        $tok = $a.Substring(1)
        if ($script:DeviceFlags -contains $tok) {
            $cand = $tok.ToLower()
            if ($name -and $name -ne $cand) {
                throw "two device flags given: /$($name.ToUpper()) and /$tok - a machine has one sound card"
            }
            $name = $cand
        }
    }
    $kept = $ExeArgs
    if ($name -eq 'spk') { $kept = @($ExeArgs | Where-Object { $_ -ne '/SPK' }) }
    return @{ Name = $name; ExeArgs = $kept }
}

function Get-DeviceConf {
    <# The device half of the conf, mirroring dos_port/run's `case $device`.
       New-RunConf inserts a blank line before this, exactly like the bash
       heredocs' leading blank line. #>
    param([string]$Device)
    switch ($Device) {
        '' { return '' }
        'gb' { return @"
[sblaster]
sbtype  = gb
oplmode = none

[speaker]
pcspeaker = true
"@ }
        'covox' { return @"
[sblaster]
sbtype  = none
oplmode = none

[speaker]
disney = true
pcspeaker = true
"@ }
        'imfc' { return @"
[imfc]
imfc        = true
imfc_base   = 2a20
imfc_irq    = 3
imfc_filter = on
"@ }
        'innova' { return @"
[sblaster]
sbtype  = none
oplmode = none

[speaker]
pcspeaker = true

[innova]
innova     = true
sidbase    = 280
samplerate = 22050
quality    = 0
"@ }
        'pas' { return @"
[sblaster]
sbtype  = pas16
oplmode = auto

[speaker]
pcspeaker = true
"@ }
        'spk' {
            $opl = if ($env:SPK_ONLY) { 'none' } else { 'opl3' }
            return @"
[sblaster]
sbtype  = none
oplmode = $opl
"@ }
        'tandy' { return @"
[sblaster]
sbtype  = none
oplmode = none

[speaker]
tandy = on
"@ }
        'mt32' {
            $romDir = if ($env:MT32_ROMDIR) { $env:MT32_ROMDIR }
                      else { Join-Path $script:DosPort 'mt32-roms' }
            return @"
[midi]
mpu401      = intelligent
mididevice  = mt32
mt32.romdir = $romDir
"@ }
        default { throw "unknown device: $Device" }
    }
}

function Enable-LocalToolchain {
    <# Put .toolchain\ on PATH for this process if the tools aren't already
       there, so the run scripts work without a separate activate step. #>
    if (-not (Test-Path $script:Toolchain)) { return }
    foreach ($sub in @('nasm', 'rgbds\bin', 'djgpp\bin')) {
        $d = Join-Path $script:Toolchain $sub
        if ((Test-Path $d) -and ($env:PATH -notlike "*$d*")) {
            $env:PATH = "$d;$env:PATH"
        }
    }
}

function Find-DosBoxX {
    <# dosbox-x on PATH, else the usual install locations. #>
    $cmd = Get-Command 'dosbox-x' -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    foreach ($p in @(
        "$env:ProgramFiles\DOSBox-X\dosbox-x.exe",
        "${env:ProgramFiles(x86)}\DOSBox-X\dosbox-x.exe",
        "$env:LOCALAPPDATA\Programs\DOSBox-X\dosbox-x.exe"
    )) { if (Test-Path $p) { return $p } }

    throw @"
dosbox-x not found.

Install DOSBox-X (https://dosbox-x.com/) and either put it on PATH or let this
script find it in a default install directory. Plain DOSBox will NOT work --
this project requires DOSBox-X's accuracy and debugger.
"@
}

function Find-Cwsdpmi {
    <# The DPMI host. Gitignored, so look where setup_toolchain.py puts it. #>
    foreach ($p in @(
        (Join-Path $script:DosPort 'CWSDPMI.EXE'),
        (Join-Path $script:Toolchain 'cwsdpmi\bin\CWSDPMI.EXE')
    )) { if (Test-Path $p) { return $p } }

    throw @"
CWSDPMI.EXE not found -- PKMN.EXE cannot start without a DPMI host.

Fetch it with:
    python dos_port\tools\setup_toolchain.py
or download csdpmi7b.zip from
http://www.delorie.com/pub/djgpp/current/v2misc/ and put CWSDPMI.EXE in dos_port\.
"@
}

function Invoke-Build {
    <# Build PKMN.EXE only. The default `all` target also builds PKMN.IMG,
       which needs Linux-only tools. LD= is required because the Makefile
       defaults to the i386- name that no prebuilt toolchain ships. #>
    param([string[]]$MakeArgs)

    Enable-LocalToolchain
    if (-not (Get-Command 'make' -ErrorAction SilentlyContinue)) {
        throw "make not found. MSYS2: pacman -S make (or GnuWin32 make)."
    }
    $ld = if ($env:LD) { $env:LD } else { 'i586-pc-msdosdjgpp-ld' }

    & make -C $script:DosPort PKMN.EXE "LD=$ld" @MakeArgs
    if ($LASTEXITCODE -ne 0) { throw "build failed (make exited $LASTEXITCODE)" }
}

function New-StagingDir {
    <# The directory mounted as C:. Only PKMN.EXE + CWSDPMI.EXE go in, so a
       stray write from the game lands here and not in the repository. Saves
       persist across runs, matching the bash scripts' PKMN.IMG behaviour. #>
    $stage = Join-Path $script:DosPort 'rundir'
    New-Item -ItemType Directory -Force -Path $stage | Out-Null

    # Self-isolating, same as .toolchain\: everything in here is a build
    # artifact or a save, and none of it is ever committable. Written before
    # anything is copied in, so an interrupted run leaves nothing untracked.
    Set-Content -Path (Join-Path $stage '.gitignore') -Encoding ASCII -Value @(
        '# Written by dos_port/run-common.ps1 -- DOSBox-X staging dir.',
        '# Build output + saves; never commit any of it.',
        '*'
    )

    Copy-Item (Join-Path $script:DosPort 'PKMN.EXE') $stage -Force
    Copy-Item (Find-Cwsdpmi) (Join-Path $stage 'CWSDPMI.EXE') -Force

    # Stale dumps lie: a previous run's FRAME.BIN read as this run's output is
    # a documented way to lose an hour. Clear them, but never the save.
    foreach ($f in $script:DumpFiles) {
        if ($f -eq 'POKEMON.DSV') { continue }
        $p = Join-Path $stage $f
        if (Test-Path $p) { Remove-Item $p -Force }
    }
    return $stage
}

function Show-IsolationWarning {
    Write-Host ''
    Write-Host 'NOTE: C: is a mounted host directory, not the isolated PKMN.IMG' -ForegroundColor Yellow
    Write-Host '      the Linux scripts use (that image needs sfdisk/mkfs.fat/mcopy).' -ForegroundColor Yellow
    Write-Host "      The game can write anywhere under $((Join-Path $script:DosPort 'rundir'))." -ForegroundColor Yellow
    Write-Host '      Read docs/glitch_safety.md before exploring glitches here.' -ForegroundColor Yellow
    Write-Host ''
}

function New-RunConf {
    <#
      Copy the tracked dosbox-x.conf, swap the imgmount autoexec for a mount of
      the staging dir, append any EXE flags to the PKMN.EXE line, and append
      extra conf sections. Returns the temp conf path.
    #>
    param(
        [string]$StageDir,
        [string[]]$ExeArgs = @(),
        [string]$ExtraConf = ''
    )
    $src = Join-Path $script:DosPort 'dosbox-x.conf'
    if (-not (Test-Path $src)) { throw "missing $src" }

    $exeLine = 'PKMN.EXE'
    if ($ExeArgs.Count -gt 0) { $exeLine = "PKMN.EXE $($ExeArgs -join ' ')" }

    $out = New-Object System.Collections.Generic.List[string]
    foreach ($line in (Get-Content $src)) {
        if ($line -match '^\s*imgmount\s+c\s') {
            $out.Add("mount c `"$StageDir`"")
        } elseif ($line -match '^\s*PKMN\.EXE\s*$') {
            $out.Add($exeLine)
        } else {
            $out.Add($line)
        }
    }
    if ($ExtraConf) { $out.Add(''); $out.Add($ExtraConf) }

    $conf = Join-Path ([System.IO.Path]::GetTempPath()) `
                      ("pkmn-$([System.IO.Path]::GetRandomFileName()).conf")
    Set-Content -Path $conf -Value $out -Encoding ASCII
    return $conf
}

function Invoke-Run {
    <# The whole flow: classify, pick the device, build, stage, write conf,
       launch, clean up. Mirrors dos_port/run. #>
    param([string[]]$Arguments = @())

    $split = Split-RunArgs $Arguments
    if ($split.Help) { Show-RunUsage; return }

    $dev = Resolve-Device -ExeArgs $split.Exe
    $exeArgs = @($dev.ExeArgs)

    if ($dev.Name -eq 'mt32' -and -not $split.DryRun) {
        $romDir = if ($env:MT32_ROMDIR) { $env:MT32_ROMDIR }
                  else { Join-Path $script:DosPort 'mt32-roms' }
        if (-not (Test-Path (Join-Path $romDir 'MT32_CONTROL.ROM'))) {
            throw "run: no MT32_CONTROL.ROM in $romDir (set MT32_ROMDIR)"
        }
    }

    if (-not $split.DryRun) { Invoke-Build -MakeArgs $split.Make }

    # Joystick selection (make-namespace, ALSA pattern): JOYSTICKTYPE=... shapes
    # [joystick] only, never reaches PKMN.EXE. Unset = no section (defaults).
    # Invoke-Run also seeds a missing rundir\POKEMON.CFG with device=gamepad
    # when this is set (anything but none) — create-only, mirroring make image.
    $joystickType = $env:JOYSTICKTYPE
    foreach ($m in $split.Make) {
        if ($m -like 'JOYSTICKTYPE=*') { $joystickType = $m.Substring('JOYSTICKTYPE='.Length) }
    }
    $joystickConf = ''
    if ($joystickType) {
        $valid = @('auto','2axis','4axis','4axis_2','fcs','ch','none')
        if ($valid -notcontains $joystickType) { throw "run: bad JOYSTICKTYPE='$joystickType' (want $($valid -join '|'))" }
        $joystickConf = @"
[joystick]
joysticktype = $joystickType
timed        = false
"@
    }

    $dosbox = try { Find-DosBoxX } catch { '<dosbox-x not found>' }
    $stage  = New-StagingDir
    if ($joystickType -and $joystickType -ne 'none' -and -not (Test-Path (Join-Path $stage 'POKEMON.CFG'))) {
        Set-Content -Path (Join-Path $stage 'POKEMON.CFG') -Encoding ASCII -Value @(
            '[keyboard]'
            'device = gamepad'
        )
    }
    $extra = Get-DeviceConf -Device $dev.Name
    if ($joystickConf) {
        if ($extra) { $extra += "`n" }
        $extra += $joystickConf
    }
    $conf = New-RunConf -StageDir $stage -ExeArgs $exeArgs `
                        -ExtraConf $extra

    if ($split.DryRun) {
        $name = if ($dev.Name) { $dev.Name } else { 'base' }
        Write-Host "run: device   = $name"
        Write-Host "run: make     = $($split.Make -join ' ')"
        Write-Host "run: exe      = $($exeArgs -join ' ')"
        Write-Host "run: dosbox-x = $($split.Host -join ' ')"
        Write-Host "run: emulator = $dosbox"
        Write-Host "run: conf:"
        Get-Content $conf | ForEach-Object { Write-Host "    $_" }
        Remove-Item $conf -Force -ErrorAction SilentlyContinue
        return
    }

    Show-IsolationWarning
    try {
        # -defaultconf ignores the user's own dosbox-x config so nothing it
        # mounts leaks in; our -conf still applies on top. Host args go after
        # -conf so they can override the defaults.
        $argv = @('-defaultdir', $script:DosPort, '-defaultconf', '-conf', $conf) + $split.Host
        & $dosbox @argv
    } finally {
        Remove-Item $conf -Force -ErrorAction SilentlyContinue
    }

    $produced = $script:DumpFiles |
        ForEach-Object { Join-Path $stage $_ } |
        Where-Object { Test-Path $_ }
    if ($produced) {
        Write-Host 'Files written by the game (in rundir\):'
        $produced | ForEach-Object { Write-Host "  $(Split-Path -Leaf $_)" }
    }
}
