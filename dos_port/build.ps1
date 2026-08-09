# dos_port/build.ps1 — Windows counterpart of dos_port/build.
#
# Usage: .\build.ps1 [BUG_FIX_LEVEL=0|1|2] [make args...]
#
# Builds PKMN.EXE only, NOT the default `all` target: `all` also builds
# PKMN.IMG, which needs sfdisk/mkfs.fat/mcopy and cannot run on Windows.
# Puts .toolchain\ on PATH if setup_toolchain.py installed one, and supplies
# the LD= override the Makefile needs (its default is the i386- name that no
# prebuilt toolchain ships). Override with $env:LD.

. (Join-Path $PSScriptRoot 'run-common.ps1')

Invoke-Build -MakeArgs $args
Write-Host "Built: $(Join-Path $PSScriptRoot 'PKMN.EXE')"
