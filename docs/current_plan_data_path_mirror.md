# current_plan_data_path_mirror — mirror pret `data/` paths, retire the `aux_misplaced` exception

**Owner:** one Opus agent, end to end.
**Worktree:** `../pokeyellow_msdos-data-paths`, branch `data-path-mirror`, already
created and built clean from prework commit `c1ea70331`.
**Build order in a worktree is load-bearing:** `make -j$(nproc)` in the **repo
root** first (pret side), then `make -C dos_port -j$(nproc)`. Doing it the other
way fails twice with errors that name neither cause — see
[[agent-fanout-worktree-setup]].
**Parallelism:** runs concurrently with `current_plan_script_transpiler`.
**Must NOT run concurrently with** `current_plan_memmap_pret_names` — that
workstream rewrites symbol references inside the very files this one splits, and
git sees a split as delete+add so those edits do not follow into the new files.

---

## Why

`dos_port/tools/lint_pret_labels:374-410` treats pret source dirs asymmetrically:

- `audio/` — the port mirrors pret's path **exactly** (measured 22/22 conformant)
- `data/` — only requires the label live *somewhere* under `dos_port/src/data/`,
  on the stated grounds that "the port groups by SUBSYSTEM … so a path mirror
  would be wrong"
- `gfx/`, `ram/` — exempt (generated assets / WRAM addresses owned by
  `gb_memmap.inc`)

That middle case is the exception to retire. Collapsing it gives the tree **one
placement rule**: a pret label lives at `dos_port/src/<pret path>`, or in a
generated `assets/*.inc`. `home/`+`engine/` (the `mirror` rule) and `audio/`
already work that way.

## Scope (measured 2026-08-16 from `translation.db`)

1,159 pret `data/` labels are defined in the port:

| where | count | action |
|---|---|---|
| generated `assets/*.inc` | 1,095 | exempt — do not move |
| hand-written `src/data/` | 64 | 20 already conformant, **44 must move** |
| elsewhere (violations) | 0 | — |

Representative moves:

```
src/data/card_key_data.asm   → src/data/events/card_key_coords.asm
src/data/battle_data.asm     → src/data/battle/special_effects.asm
src/data/tileset_data.asm    → src/data/tilesets/pair_collision_tile_ids.asm
src/data/audio_data.asm      → src/data/pokemon/cries.asm
```

## Stages

- [ ] Enumerate all 44 moves from `translation.db` into a checked-in mapping list
      (source label → current file → mirrored destination)
- [ ] Capture the `pkmn.sym` baseline: `make -C dos_port && cp dos_port/pkmn.sym /tmp/sym.A.before`
- [ ] `dos_port/tools/fidelity_gate --move-baseline <dir> <files...>` **before** any edit
- [ ] Perform the splits, one destination group at a time
- [ ] Makefile: replace each old path with the N new paths in its owning `_SRCS`
      variable, keeping them **adjacent and in order** (list order is link order)
- [ ] Makefile: re-point every explicit per-object asset prerequisite naming an
      old `.o` (the hand-written lines in the `2903-3599` block)
- [ ] Add `global`/`extern` for labels now crossing a file boundary
- [ ] Delete orphaned `.o` files by hand (they drop out of `ALL_OBJS`, so
      `make clean` will not remove them)
- [ ] `dos_port/tools/fidelity_gate --move-verify <dir> --to <each new file> --gates auto`
- [ ] `diff /tmp/sym.A.before dos_port/pkmn.sym`: expect **zero VMA changes**, and
      only `t`→`T` kind flips on labels that newly became `global`
- [ ] Manual contiguity review against pret's file boundaries (see Traps)
- [ ] **Commit 1** — the moves alone (still passes the current weak rule)
- [ ] Tighten `aux_misplaced` in `lint_pret_labels` to require exact path mirroring
      for `data/`, and delete the "a path mirror would be wrong" exemption comment
- [ ] **Commit 2** — the rule change
- [ ] `make -C dos_port static_gate` green at the `{}` baseline
- [ ] Archive: `git mv docs/current_plan_data_path_mirror.md docs/plans/data_path_mirror.md`

## Traps

**This is file-SPLITTING, not renaming.** `src/data/battle_anims.asm` alone
scatters to five destinations (`moves/animations.asm`,
`battle_anims/base_coords.asm`, `battle_anims/frame_blocks.asm`, `moves/sfx.asm`,
`battle_anims/subanimations.asm`). ~15 files become ~30. `_SRCS` list order **is**
link order (`LINK_OBJS` feeds `ld` in order, `dos_port/Makefile:3699`), so keep new
entries adjacent and ordered or the layout shifts.

**Every destination needs its own `--to`.** `fidelity_gate:322-336`
(`rename_targets`) only auto-discovers git's single best rename match; one file
becoming several yields at most one `R` status. Omitting a destination fails
loudly — the 2026-07-28 "0 moved, 69 dropped" mode — which is the desired
behaviour, not a problem.

**`move-verify`'s blind spot needs human cover.** The move classification is
LINE-level, not block-level (`fidelity_gate:77-81`): it cannot prove the moved
lines are contiguous, in the same order, or in the file you intended. Check
`[4/5]` prints a port_file change *dim, not red*, so a routine landing in the
**wrong new file still PASSES**. The `pkmn.sym` VMA check above is the mechanical
half of the cover; read the splits against pret's own file boundaries for the rest.

**Rule-change ordering is load-bearing.** `static_gate`'s baseline is `{}` — every
class at zero — and the ratchet is **bidirectional**, so an unexplained *shrink*
also fails. Move first (findings stay 0 under the weak rule), then tighten
(findings stay 0 under the strict rule). Tightening first creates 44 findings and
fails the pre-commit hook.

**Symbol-table bloat is expected and harmless.** Each `.o` re-embeds the full
`equ` set (a 3 KB source yields a ~53 KB object with ~1500 absolute symbols), so
~15 files becoming ~30 grows `PKMN.EXE`'s symbol table. `gen_symfile.py` already
filters absolutes out of `pkmn.sym`, so the VMA check is unaffected.

## Evidence

- Rule and its exemption comment: `dos_port/tools/lint_pret_labels:374-410`
- Move battery: `dos_port/tools/fidelity_gate:426` (`move_baseline`), `:524`
  (`move_verify`), blind spot documented at `:77-81`, `--to` rationale at `:822-826`
- Makefile pattern rule `:3790-3791`, `_SRCS` block `:455-2607`, link order `:3699`
- Counts from `dos_port/tools/translation.db` (`aux_labels` ⋈ `port_defs`), 2026-08-16
