# savegen — PKHeX-backed golden save-fixture generator

Builds `dos_port/tests/fixtures/yellow_boxes_full.sav` from
`yellow_100.sav` by filling all 12 PC boxes to 20 mons.

```sh
cd dos_port/tools/savegen
dotnet run -- ../../tests/fixtures/yellow_100.sav ../../tests/fixtures/yellow_boxes_full.sav
```

Needs the .NET SDK and network access on first run (restores `PKHeX.Core` from
NuGet). It is **not** part of `make` — fixtures are committed, and this exists so
a committed binary has a reproducible source rather than being an opaque blob.

## Why PKHeX and not another Python generator

The repo already knows the pret save layout well enough to write these bytes by
hand. What it does not have is Gen-1 *semantics*: per-species EXP growth curves,
legal level-up movesets, and the dex-number → GB-internal-index mapping. Those
are exactly the things a hand-rolled generator gets subtly and silently wrong, so
`PKHeX.Core` supplies them.

## PKHeX does not write the Gen-1 PC-box checksums — and the game never reads them

Measured, not assumed. After editing boxes and calling `SAV1.Write()`, PKHeX
updates `sMainDataCheckSum` but leaves **all 14** bank-2/3 checksums
(`sBank{2,3}AllBoxesChecksum` and the six per-box bytes each) stale — verified on
the very first run of this tool, where the 15th (main data) was correct and the
other 14 were wrong.

*** That is harmless to the game, and an earlier version of this file was wrong
to say otherwise. *** In the whole pret tree those 14 bytes are **write-only**:
`sMainDataCheckSum` is read and `cp`-compared at 5 sites in
`engine/menus/save.asm` (with a compute-compare-recompute-compare retry), while
the box checksums have **0** read sites — every reference is a store, the
destination pointer in `CalcIndividualBoxCheckSums`, or the `ram/sram.asm`
declaration. Confirmed at runtime: a save with all 14 inverted loads in mGBA
identically to a correct one (party 6, `wBoxCount` 20). The port mirrors pret, so
it does not read them either. The game recomputes them on the next box write, so
a player who simply re-saves fixes them for free.

`Program.cs` recomputes them anyway, for two reasons that are about the FIXTURE,
not the game: a real cartridge save always has them consistent (the game writes
them on every box operation), so a fixture that does not is unlike real hardware;
and an internally inconsistent fixture is a landmine for anything that *does*
validate — `saveconv.py`, the port's own checker, or a future test. It uses
pret's `CalcCheckSum` rule (the ones' complement of the byte sum over the region)
with offsets from `ram/sram.asm`.

Two lessons, and the second is the one that cost time here: verify a library's
output with an independent checker rather than its own read-back — but then also
verify what a mismatch actually *causes*, instead of assuming a checksum that
exists must be enforced.

## Determinism is required, not incidental

There is no RNG anywhere: species, level and DVs are pure functions of the slot
index. A golden fixture that changes between runs is worthless, so re-running
must reproduce the file byte for byte. `cmp` the output against the committed
fixture after any change.
