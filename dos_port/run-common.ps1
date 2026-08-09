# dos_port/run-common.ps1 — shared implementation behind run.ps1, run-mt32.ps1,
# run-spk.ps1 and run-tandy.ps1. Dot-source it; do not invoke it directly.
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
      Same convention as the bash scripts: '/...' tokens are PKMN.EXE flags,
      everything else is a make argument.
        run.ps1 SKIP_TITLE=1 DEBUG_AUDIO=1 /LOOP /NOENH
    #>
    param([string[]]$Arguments = @())
    $exe = @(); $make = @()
    foreach ($a in $Arguments) {
        if ($a.StartsWith('/')) { $exe += $a } else { $make += $a }
    }
    return @{ Exe = $exe; Make = $make }
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
    <# The whole flow: build, stage, write conf, launch, clean up. #>
    param(
        [string[]]$Arguments = @(),
        [string[]]$ExtraExeArgs = @(),
        [string]$ExtraConf = ''
    )
    $split = Split-RunArgs $Arguments
    Invoke-Build -MakeArgs $split.Make

    $dosbox = Find-DosBoxX
    $stage  = New-StagingDir
    $exeArgs = @($ExtraExeArgs) + @($split.Exe)
    $conf = New-RunConf -StageDir $stage -ExeArgs $exeArgs -ExtraConf $ExtraConf

    Show-IsolationWarning
    try {
        # -defaultconf ignores the user's own dosbox-x config so nothing it
        # mounts leaks in; our -conf still applies on top.
        & $dosbox -defaultdir $script:DosPort -defaultconf -conf $conf
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
