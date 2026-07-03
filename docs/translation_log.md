# Translation Log

Running notes on routines translated from SM83 to x86. One entry per routine.
Use this to document non-obvious decisions, flag edge cases found, and track
which H-flag situations were encountered.

Format:
```
## RoutineName
- Source: <file>:<label>
- Translated: <dos_port file>
- Date: YYYY-MM-DD
- H-flag: <involved / not involved / lazy>
- Bug tags: <none / BUG(critical) / BUG(cosmetic) / GLITCH>
- Divergences: <none (faithful) | each allowlist divergence + a one-line why,
  e.g. "PlayCurrentMoveAnimation → no-op: literal subanim deferred (ANIMATION=OFF, §2.1)">
- Notes: <decisions and edge cases>
```

For move-effect bodies, "Divergences" is mandatory and must list every allowed-divergence
(docs/move_translation_divergence.md §2) the body took, with a brief reason; "none (faithful)"
if it took none. This is the swarm's divergence audit trail.

---

## menus-port Session 7 — swarm wave 2 (root integration)

Root (integrator) session. Root-first prework: NEW `src/save/dsv_io.asm` (the
`.dsv` save HAL — DsvFileExists/DsvWriteSave/DsvReadSave; DOSV magic+version+16-bit
additive checksum + "minimal real" payload = exactly the WRAM ranges pret's
Save{Main,CurrentBox,PartyAndDex}Data serialize; self-contained DPMI INT 31h/0300h
file I/O mirroring debug_dump.asm), NEW `tools/gen_alphabets.py` → `assets/alphabets.inc`
(package C data), 4 sidecar UI elements (UI_MAIN_MENU/UI_CONTINUE_INFO/UI_NAMING_SCREEN/
UI_CHANGE_BOX) + 2 added at integration (UI_SAVE_INFO, UI_CHANGE_BOX_INFO), and
sym-verified save/naming/options WRAM in gb_memmap.inc. Committed as prework 95606760.

- **Package E — main_menu** — Source: pret `engine/menus/main_menu.asm`. Translated:
  NEW `dos_port/src/engine/menus/main_menu.asm`. Faithful line-for-line: MainMenu's
  save-present/no-save branch + the `.skipInc` menu-item-number normalization, InitOptions
  (writes wOptions/wLetterPrintingDelayFlags/wPrinterSettings + wOptionsInitialized —
  D deferred it), Func_5cc1 (dead-branch comment), StartNewGame(Debug)→SpecialEnterMap,
  DisplayContinueGameInfo/PrintSaveScreenText, PrintNumBadges/OwnedMons/PlayTime,
  CheckForPlayerNameInSRAM. x86 flag discipline verified (`test al,al` for `and a`,
  `test al,PAD_B` for `bit`, CF polarity via DsvFileExists). TODO-HW ×4 (palette no-op,
  joypad→DelayFrame, SRAM→DsvFileExists). DEVIATION ×8 (window-compositor bridge:
  MainMenuShowWindow/mirrors, g_bg_whiteout, add_window disjoint GB_TILEMAP1 bands).
- **E integration:** gb_memmap gains wDefaultMap 0xD07B / wDestinationMap 0xD719 /
  wCableClubDestinationMap 0xD72C / wNumSetBits 0xD11D (all sym-verified). Promoted
  `count_set_bits.asm` (now %includes gb_memmap for wNumSetBits, dropped the extern) +
  `reset_player_sprite.asm` to HOME_SRCS. NEW `main_menu_stubs.asm` (OakSpeech /
  DisplayTitleScreen / PrepareForSpecialWarp integration stubs — seams not yet ported;
  MainMenu is not the boot path yet). DEBUG_MAINMENU FRAME.BIN renders the CONTINUE/
  NEW GAME/OPTION menu + ▶ cursor + PLAYER/BADGES/#DEX/TIME panel; the full-screen
  bg-whiteout bleeds the overworld behind (window-compositor plumbing — S10 polish).
- **Package H — save.asm** — Source: pret `engine/menus/save.asm`. Translated: NEW
  `dos_port/src/engine/menus/save.asm` (full pret label parity: SaveMenu/SaveGameData/
  Save{Main,CurrentBox,PartyAndDex}Data/CalcCheckSum, TryLoadSaveFile/Load{Main,CurrentBox,
  PartyAndDex}Data, ChangeBox family, LoadHallOfFameTeams et al). Every SRAM byte-copy /
  rRAMG/rBMODE/rRAMB write collapses onto DsvWriteSave/DsvReadSave/DsvFileExists or a
  flag-preserving no-op (49 TODO-HW SRAM). CF=1 from DsvReadSave maps exactly onto pret's
  `.badsum`/CheckSumFailed branch. Messages drawn-whole (DEVIATION(text)); SAVE yes/no on
  the S3 driver. Wired StartMenu_SaveReset→SaveMenu (start_sub_menus.asm; link-RESET guard
  deferred to S8 as DEVIATION). LoadHallOfFameTeams real → deleted A's league_pc_stubs.asm
  ret-stub (kept Func_7033f). DEBUG_SAVE FRAME.BIN renders "<PLAYER> saved the game!" over
  Pallet Town — clean.
- **H+E link coupling:** committed as one wave (H's SaveMenu→PrintSaveScreenText lives in
  E; E's TryLoadSaveFile lives in H — a genuine mutual link dependency). Extracted
  SetMapTextPointer/RestoreMapTextPointer to NEW `src/home/map_text_pointer.asm` (predef_text.asm
  externs them) so ChangeBox links without the script engine. Dropped town_map.asm's
  now-redundant wDestinationMap placeholder (NASM inconsistent-equ redefinition). `make` +
  `make check` green.

## menus-port Session 6 — swarm wave 1 (root integration)

Root (integrator) session. Four Opus workers in seeded worktrees produced the
leaf screens; root did the shared prework, gated each package (pret control-flow
diff → tag audit → PROJ-cites-UI_* → make+check → TODO-HW contract), derived new
WRAM against the authoritative `origin/symbols:pokeyellow.sym`, wired Makefile +
harness, and committed each package alone.

- **Root prework (shared, package B + wave):** NEW `tools/gen_badge_tiles.py`
  (Tier-1 passthrough of `gfx/trainer_card/badges.2bpp` → `assets/badge_tiles.inc`:
  `badge_face_tiles` / `BADGE_FACE_TILE_COUNT`=64 / `BADGE_TILE_BYTES`=16) + its
  Makefile `assets` rule. Three new sidecar UI elements (seeded from pret GB
  rects, standard anchors, root edit between waves): `UI_TRAINER_CARD_BADGES`
  (B; GB(2,11) 16×6 center/top), `UI_OPTIONS` (D; full 20×18 center/top),
  `UI_PLAYERS_PC_MENU` (F; GB(0,0) 16×10 center/top).
- **Package B — DrawBadges** — Source: pret `engine/menus/draw_badges.asm`.
  Translated: NEW `dos_port/src/engine/menus/draw_badges.asm`. Faithful pret
  loop shape line-for-line: `.FaceBadgeTiles`→`wBadgeOrFaceTiles` stage, the
  `srl`/carry `wObtainedBadges` walk with the +4 owned-badge offset, the
  `$d8`/`$60` number/name seed, and the two-row `.DrawBadgeRow`/`.DrawBadge`
  draw incl. the back-shift `CopyData` that reads the reserved `+1` byte.
  Port-mechanical (not deviations, plainly commented): the `.FaceBadgeTiles`
  `CopyData` is a flat→GB `rep movsb` (code-space source, no `[ebp+ESI]` bias);
  the INCBIN'd sheet becomes `assets/badge_tiles.inc` + NEW `LoadBadgeTiles`
  (copies 64 tiles to vChars2 so face 0 = VRAM tile $20 = $9200, below the box
  tiles at $9600 and in the card-unused overworld-tileset region; sets
  `g_tilecache_dirty`). Zero `; TODO-HW` (pure tilemap writes); one `; PROJ`
  (harness window, cites `UI_TRAINER_CARD_BADGES_*`).
- **WRAM (B):** gb_memmap.inc gains `wBadgeNumberTile` 0xCD3D,
  `wBadgeNameTile` 0xCD3E, `wBadgeOrFaceTiles` 0xCD3F, `wTempObtainedBadgesBooleans`
  0xCD49 — all verbatim from `origin/symbols:pokeyellow.sym` bank 00 (badge NEXTU
  lane of the ram/wram.asm:772 union, so 0xCD3D aliases the S5 wSwappedMenuItem/
  wChargeMoveNum union byte; DrawBadges writes every scratch byte before reading,
  so the overlap is safe). `wObtainedBadges` reused as existing `W_OBTAINED_BADGES`
  0xD355 (sym-confirmed).
- **Makefile/harness (B):** draw_badges.asm → GAME_SRCS; `assets/badge_tiles.inc`
  rule + `draw_badges.o` dep + `assets` aggregate; `DEBUG_DRAWBADGES` flag block
  (harness seeds its own badges, so no debug_party); `RunDrawBadgesTest` hook in
  overworld.asm.
- **Gate (B):** `make` + `make check` green (draw_badges.o links dead until S9's
  StartMenu_TrainerInfo). DEBUG_DRAWBADGES FRAME.BIN (seed wObtainedBadges=%10100101)
  renders the 4×2 grid — owned badges show badge gfx, unowned show gym-leader
  faces + number/name glyphs — confined to the `UI_TRAINER_CARD_BADGES` window
  (content bbox x[104..215] y[96..135] inside wx=103/wy=88/clip=128/maxy=136).
  **FAITHFUL EXCEPT: none.**
- **Pre-existing finding (out of S6 scope, flagged to user):** the port's
  `W_SIMULATED_JOYPAD_STATES_INDEX` (0xCC84) and the `wFieldMoves` family
  (0xCC89/0xCC8D) are off by 0xB4 vs the sym (0xCD38/0xCD3D/0xCD41) — a latent
  S2-era derivation error against a wrong anchor. Not fixed here (S2/S5 gated
  green; needs a dedicated fix).

## menus-port Session 6 package F — players_pc (root integration)
- **Date:** 2026-07-02
- **PlayerPC / PlayerPCMenu / ExitPlayerPC / PlayerPCDeposit / PlayerPCWithdraw /
  PlayerPCToss** — Source: pret `engine/menus/players_pc.asm`. Translated: NEW
  `dos_port/src/engine/menus/players_pc.asm`. The **flagship 2nd caller of the
  generic DisplayListMenuID** after the bag — deposit/withdraw/toss point
  wListPointer at wNumBagItems / wNumBoxItems with ITEMLISTMENU, proving the
  driver generalizes to the PC item box. Deposit/Withdraw/Toss/Exit verified
  line-for-line vs pret (incl. Toss's `wCurItem`/IsItemHM fold, the `and a`
  empty-inventory guards, AddItemToInventory CF room check, and the
  wListScrollOffset save on exit so the bag's saved scroll doesn't desync).
  Parent menu on TextBoxBorder(0,0,8,14) + PlaceString(PlayersPCMenuEntries) +
  HandleMenuInput (watched A|B), wParentMenuItem cursor memory.
- **Port model:** parent box drawn box-relative (stride-20) → GB_TILEMAP0 via
  pc_menu_mirror (menu_redraw_cb, live ▶ cursor) + window at UI_PLAYERS_PC_MENU;
  SaveScreenTilesToBuffer1/LoadScreenTilesFromBuffer2 → RefreshCollisionTileMap +
  hide_window (S4 start-menu precedent, since UpdateSprites runs). 14 dialogs
  drawn whole (DEVIATION(text), exact data/text/text_3.asm wording) into scratch
  rows 12-17 + UI_MESSAGE_BOX; `prompt` texts get ▼+A/B wait, `done` texts show
  under the list. TODO-HW ×4: SFX_TURN_ON/OFF_PC + SFX_WITHDRAW_DEPOSIT audio
  no-ops. DEVIATION: explicit BIT_SINGLE_SPACED_LINES clear so <NEXT> double-
  spaces deterministically (pret relies on the ambient overworld default). One
  `; PROJ` cites UI_PLAYERS_PC_MENU.
- **WRAM (F):** gb_memmap.inc gains wParentMenuItem 0xCCD3 (= wAddedToParty,
  sym-verified), BIT_USING_GENERIC_PC 3, BIT_NO_MENU_BUTTON_SOUND 5 (wMiscFlags
  bits). wNumBoxItems/wBoxItems (0xD539/0xD53A) reused (already present).
- **Makefile/harness (F):** players_pc → GAME_SRCS; DEBUG_PLAYERSPC gate
  (+ debug_party for PrepareNewGameDebug); RunPlayersPCTest hook in overworld.asm.
- **Gate (F):** `make` + `make check` green. DEBUG_PLAYERSPC FRAME.BIN (seed
  party+bag + 2 box items, generic PC) renders the parent menu
  (▶WITHDRAW/DEPOSIT/TOSS ITEM / LOG OFF) **and** the "What do you want to do?"
  message box together over Pallet Town — two simultaneous windows, faithful.
  **FAITHFUL EXCEPT:** dialogs drawn-whole [DEVIATION(text)]; buffer save→window
  model [DEVIATION]; SFX [TODO-HW]; explicit single-spaced-lines clear [DEVIATION].

## menus-port Session 6 package D — options (root integration)
- **Date:** 2026-07-02
- **DisplayOptionMenu_ / InitOptionsMenu / OptionsControl / GetOptionPointer +
  OptionMenuJumpTable + the six row handlers + OptionsMenu_UpdateCursorPosition**
  — Source: pret `engine/menus/options.asm`. Translated: NEW
  `dos_port/src/engine/menus/options.asm`. Line-for-line mirror: the own
  JoypadLowSensitivity/3×DelayFrame loop (NOT HandleMenuInput), the `jp hl`
  jump table (port `jmp [tbl+eax*4]`), the `sla/rl` bit-extract idioms
  (`shl`+`rcl`), `swap a`→`rol al,4`, GetTextSpeed/GetGBPrinterBrightness
  neighbor-delay tables, and OptionsControl's printer→cancel dummy-row skip +
  top/bottom wrap (verified identical to pret). Charmap strings + jump table are
  hand-authored Tier-2 code data.
- **TODO-HW ×2:** OptionsMenu_SpeakerSettings skips pret's `xor a / ldh [rAUDTERM]`
  (audio HAL, Phase 3) but still stores the wOptions sound bits; OptionsMenu_
  GBPrinterBrightness stores wPrinterSettings but transmits nothing (no serial).
  Both keep the row + value write + pret's fall-through — contract preserved.
- **Port plumbing (not deviations):** text_row_stride=20 reset (party-menu home
  driver precedent); the OPTION screen is a full-screen takeover shown via
  options_mirror (stride-20 scratch rows 0-17 → GB_TILEMAP1) + OptionsShowWindow
  (single UI_OPTIONS window + g_bg_whiteout), the hAutoBGTransferEnabled analog;
  options_mirror is called once per loop (pret's BGMap-transfer slot) so the
  in-place value-row redraw + ▶ reach the window. Two `; PROJ` cite UI_OPTIONS.
- **WRAM (D):** gb_memmap.inc gains wOptionsCursorLocation 0xCD3D (**corrected
  from the worker's 0xD029** to the sym address — another lane of the 0xCD3D
  scratch union, modal so non-concurrent), wPrinterSettings 0xD497, and
  SOUND_MASK 0x30. wOptions reused (existing W_OPTIONS 0xD354). OPT_*/NUM_*/
  PRINTER_BRIGHTNESS_* kept local (options-only index enums, two-tier rule).
- **Makefile/harness (D):** options → GAME_SRCS; DEBUG_OPTIONS gate;
  RunOptionsTest hook in overworld.asm.
- **Gate (D):** `make` + `make check` green. DEBUG_OPTIONS FRAME.BIN (seed
  MID/ON/SHIFT/MONO/NORMAL) renders the full OPTION screen — border box,
  "TEXT SPEED :MID / ANIMATION :ON / BATTLESTYLE:SHIFT / SOUND:MONO /
  PRINT:NORMAL / CANCEL" with ▶ on TEXT SPEED — matching pret's layout exactly.
  **FAITHFUL EXCEPT: none** (only the two TODO-HW register pokes skipped).

## menus-port Session 6 package A — oaks_pc + league_pc (root integration)
- **Date:** 2026-07-02
- **OpenOaksPC** — Source: pret `engine/menus/oaks_pc.asm:OpenOaksPC`. Translated:
  NEW `dos_port/src/engine/menus/oaks_pc.asm`. Faithful flow (accessed→get-rated
  dialogs → YesNoChoice → wCurrentMenuItem `and a`/jnz skip → DisplayDexRating →
  closed dialog → restore). DEVIATION(text): the three dialogs
  (_AccessedOaksPCText 2 pages incl. its `para`, _GetDexRatedText which stays
  visible under YesNoChoice, _ClosedOaksPCText + the wrapper's `text_waitbutton`)
  drawn whole into scratch rows 12-17 + UI_MESSAGE_BOX (pret data/text/text_3.asm
  wording verified byte-for-byte, incl. #=POKé expansion). DEVIATION:
  SaveScreenTilesToBuffer2/LoadScreenTilesFromBuffer2 → g_window_count save/restore.
  STUB(S8-pokedex): `predef DisplayDexRating` branch kept, call no-oped.
- **PKMNLeaguePC / LeaguePCShowTeam / LeaguePCShowMon** — Source: pret
  `engine/menus/league_pc.asm`. Translated: NEW
  `dos_port/src/engine/menus/league_pc.asm`. AccessedHoFPCText drawn whole
  (2 pages, verified wording). Live state kept verbatim: BIT_NO_TEXT_DELAY
  set/res, wUpdateSpritesEnabled + hTileAnimations push/pop, the >capacity
  first-team math, the team loop (LoadHallOfFameTeams/LeaguePCShowTeam CF
  contract, wHoFTeamIndex2 walk), and the CopyData team-buffer shift + `cp $ff`
  end + B-exit `scf`. LeaguePCShowMon full-screen front-pic + "HALL OF FAME No"
  box + PrintNumber + `jmp Func_7033f` ported for label parity.
  DEVIATION/STUB(S7-save): pret unconditionally enters `.loop` (relies on the
  ActivatePC caller gating on a non-empty HoF; a 0-team entry shows a garbage
  mon). The port adds one tagged `test bh,bh / jz .doneShowingTeams` guard so the
  no-save 0-team state exits clean after the dialog — the brief's intended
  behavior; dead once S7 seeds wNumHoFTeams>0. TODO-HW: RunPaletteCommand /
  RunDefaultPaletteCommand palette-HAL no-ops (Phase 5).
- **Forward-dep stubs** — NEW `src/engine/menus/league_pc_stubs.asm`: `ret`-only
  LoadHallOfFameTeams (S7 save layer) + Func_7033f (HoF movie), referenced at
  link by the dead team loop; delete each when its real routine lands
  (overworld_stubs precedent).
- **WRAM (A):** gb_memmap.inc gains wHallOfFame 0xCC5B, wHoFMonSpecies/
  wHoFTeamIndex 0xCD3D, wHoFPartyMonIndex 0xCD3E, wHoFMonLevel 0xCD3F,
  wHoFMonOrPlayer 0xCD40, wHoFTeamIndex2 0xCD41, wHoFTeamNo 0xCD42,
  wWholeScreenPaletteMonSpecies 0xCF1C, wNumHoFTeams 0xD5A1 — all verbatim from
  origin/symbols:pokeyellow.sym (the worker's placeholder 0xD640-block was wrong;
  the real cluster is union-aliased into the 0xCD3D badge/field-move/swap lane
  and the 0xCC5B wSwitchPartyMonTempBuffer union base — safe, dead until S7).
  gb_constants.inc gains HOF_MON/HOF_TEAM/HOF_TEAM_CAPACITY (0x10/96/50) +
  SET_PAL_POKEMON_WHOLE_SCREEN 0x0B.
- **Makefile/harness (A):** oaks_pc + league_pc + league_pc_stubs → GAME_SRCS;
  DEBUG_OAKSPC / DEBUG_LEAGUEPC flag blocks; RunOaksPCTest / RunLeaguePCTest hooks
  in overworld.asm. The temporary s6a_pending_symbols.inc scaffold was stripped
  (its symbols migrated to the canonical includes).
- **Gate (A):** `make` + `make check` green (both files link; the HoF loop is
  dead until S7). DEBUG_OAKSPC FRAME.BIN shows "Accessed PROF. / OAK's PC." and
  DEBUG_LEAGUEPC shows "Accessed POKéMON / LEAGUE's site." in the UI_MESSAGE_BOX
  dialog over Pallet Town — pret wording exact.
  **FAITHFUL EXCEPT:** dialogs drawn-whole [DEVIATION(text)]; buffer2 save →
  window-list [DEVIATION]; DisplayDexRating no-op [STUB S8]; HoF team loop +
  0-team guard + ret-stubs [STUB S7]; palette no-ops [TODO-HW]; LeaguePCShowMon
  full-screen coord math unverified until S7 wires+gates it (dead now).

## menus-port Session 5 — party_menu realigned onto the generic drivers
- **Date:** 2026-07-02
- **Plan:** docs/current_plan_menus.md, Session 5. Bespoke
  `src/engine/menus/party_menu.asm` (self-contained input loop, its own pop-up
  and swap code) **rewritten** as the faithful pret split: home driver +
  engine renderer + StartMenu_Pokemon dispatcher (direct overwrite, S4
  precedent; gated by before/after FRAME.BIN diff).
- **DisplayPartyMenu / GoBackToPartyMenu / PartyMenuInit /
  HandlePartyMenuInput / DrawPartyMenu / RedrawPartyMenu** — Source: pret
  `home/pokemon.asm:187-334`. Translated: `dos_port/src/home/pokemon.asm`
  (appended). Faithful incl. the cross-routine hTileAnimations push/pop (the
  swap re-entries keep it pushed, exactly pret's `jp`s), wForcePlayerToChooseMon
  watched-keys narrowing, wPartyAndBillsPCSavedMenuItem round-trip, and the
  CF-return contract (CF=0 chosen / CF=1 none). Runs on the generic
  HandleMenuInput with `menu_item_step`=2 rows, stride 20, wMenuWrappingEnabled,
  and `menu_redraw_cb`=PartyMenuAnimCB. STUB(pikachu-follow): the
  IsThisPartyMonStarterPikachu / CheckPikachuFollowingPlayer sleeping-Pikachu
  refusal; every mon takes the .asm_1258 path.
- **PrintStatusCondition / DrawHPBar** — Source: pret `home/pokemon.asm:336` /
  `home/pokemon.asm:1`. Translated: `dos_port/src/home/pokemon.asm`. Faithful
  ("FNT" from the HP bytes at status−2/−3; the $6d/$6c bar cap from
  wHPBarType).
- **PrintStatusAilment** — Source: pret `engine/pokemon/status_ailments.asm`.
  Translated: `dos_port/src/engine/pokemon/status_ailments.asm` (replaces the
  unwired-skeleton "intentionally skipped" note; now in POKEMON_SRCS).
- **HPBarLength / GetHPBarLength** — Source: pret `engine/gfx/hp_bar.asm`.
  Translated: NEW `dos_port/src/engine/gfx/hp_bar.asm`. Keeps pret's observable
  truncations (product>>2 and divisor>>2 with a byte divisor when maxHP ≥ 256)
  in native arithmetic. GLITCH-safety: divisor 0 clamps to a full bar instead
  of a native #DE fault (pret's byte Divide doesn't fault).
- **DrawHP / DrawHP2 / DrawHP_** — Source: pret
  `engine/pokemon/status_screen.asm:1-62`. Translated:
  `dos_port/src/engine/menus/party_menu.asm` — hosted there until
  pokemon_behavior's StatusScreen lands (that plan owns the file); pret names
  kept, moves verbatim. hUILayoutFlags BIT_PARTY_MENU_HP_BAR steers the
  fraction right-of-bar (+9) vs below-bar (+SCREEN_WIDTH+1). Leaves the bar
  pixel count in DL (pret leaves it in `e`) — consumed by
  SetPartyMenuHPBarColor.
- **DrawPartyMenu_ / RedrawPartyMenu_ / SetPartyMenuHPBarColor** — Source: pret
  `engine/menus/party_menu.asm`. Translated:
  `dos_port/src/engine/menus/party_menu.asm` (full rewrite). Entry loop is
  pret line-for-line (GetPartyMonName+PlaceString at (3,0)+2 rows,
  wMenuItemToSwap ▷ at col 0, PrintStatusCondition +14, DrawHP2 +21 under the
  BIT_PARTY_MENU_HP_BAR set/res pair, SetPartyMenuHPBarColor →
  wPartyMenuHPBarColors (RunPaletteCommand = TODO-HW), PrintLevel +10,
  hPartyMonIndex/wWhichPokemon bookkeeping, wWhichPartyMenuHPBar reset+inc,
  SWAP_MONS_PARTY_MENU direct-to-.printMessage). STUB(items-plan):
  TMHM/EVO_STONE "ABLE/NOT ABLE" columns (branches kept). STUB(items-plan):
  .printItemUseMessage. DEVIATION(icons): WriteMonPartySpriteOAMByPartyIndex /
  LoadMonPartySpriteGfxWithLCDDisabled → BG-tile 2×2 icons
  (WritePartyMonIconTiles / LoadMonPartySpriteGfx, assets/mon_icons.inc) with
  PartyMenuAnimCB frame-swapping VRAM, paced by wPartyMenuHPBarColors
  (6/17/33 vblanks). DEVIATION(text): PartyMenuMessagePointers texts drawn
  whole (S4 toss-dialog precedent), pret data/text/text_3.asm wording incl.
  the not-yet-reachable ItemUse/Battle/UseTM lines. Port model: PartyMenuMirror
  (scratch rows 0-17 → GB_TILEMAP1) is the hAutoBGTransferEnabled analog —
  frame.asm's do_bg_transfer is canvas-scoped (stride 40; its 20×18 comments
  are stale) and title.asm's ClearScreen both targets the canvas and re-arms
  that transfer mid-draw, so the clear is a direct 360-byte FillMemory and the
  mirror is explicit. Windows: UI_PARTY_PANEL (mon rows 0-11; max_y=12*8 —
  message rows route to UI_MESSAGE_BOX so they aren't shown twice) +
  UI_MESSAGE_BOX (rows 12-17); g_bg_whiteout = the full-screen takeover field.
- **StartMenu_Pokemon (full dispatcher) / ErasePartyMenuCursors /
  SwitchPartyMon / SwitchPartyMon_ClearGfx / SwitchPartyMon_InitVarOrSwapData**
  — Source: pret `engine/menus/start_sub_menus.asm:9-121,303-313,678-826`.
  Translated: `dos_port/src/engine/menus/start_sub_menus.asm`. Dispatcher
  faithful: count guard, DisplayPartyMenu / GoBackToPartyMenu loop,
  FIELD_MOVE_MON_MENU via DisplayTextBoxID (S2's canvas
  DisplayFieldMoveMonMenu), the wFieldMoves menu-var walk (max item / top Y),
  HandleMenuInput on the canvas (stride 40, cursor coords projected by the
  same FM_ROW/COL shifts the box was drawn with), CANCEL/SWITCH/STATS/move
  routing incl. the party<2 re-entry. Pop-up window bridge: fm_show_window
  recovers the dynamic box rect from wFieldMoves + wFieldMovesLeftmostXCoord
  (wNumFieldMoves is consumed by the draw) and right/bottom-anchors it at
  UI_FIELD_MOVE_MON_MENU (W=9,H=7 lands exactly on the frozen WX/WY);
  fm_mirror doubles as menu_redraw_cb; SaveScreenTilesToBuffer1 /
  LoadScreenTilesFromBuffer1 collapse to window append/drop (the canvas box
  bytes ≥360 never alias the stride-20 panel scratch). SwitchPartyMon family
  faithful (hSwapTemp species swap, wSwitchPartyMonTempBuffer 3-way CopyData
  of structs/OT/nicks, wSwappedMenuItem bookkeeping); ClearGfx clears the two
  scratch rows (DEVIATION(icons): pret also parks OAM; SFX_SWAP = TODO-HW).
  STUB(field-effects): .choseOutOfBattleMove selections re-enter the party
  menu (UsedCut/ChooseFlyDestination/UseItem/… unported; refusal-path shape).
  STUB(pokemon_behavior): .choseStats (plan Stage 4 still open). Exit restores:
  g_bg_whiteout off + LoadTilesetTilePatternData (DEVIATION(icons): BG icons
  clobber the map tileset where pret's OAM icons clobber sprite VRAM).
- **PrintNumber endianness fix** — `dos_port/src/home/print_num.asm` read
  multi-byte values LITTLE-endian; pret PrintNumber is BIG-endian
  (hNumToPrint staged MSB-first). Every pre-S5 linked caller was 1-byte
  (identical either way), so nothing observable changed before; the party
  menu's 2-byte HP fractions exposed it (Jigglypuff 62 → $3E00 = 15872 →
  garbage-tile "U72"). Also silently fixes any future text_decimal words.
- **WRAM/HRAM:** gb_memmap.inc gains wSwitchPartyMonTempBuffer $CC97,
  wPartyMenuHPBarColors $CF1E, wWhichPartyMenuHPBar $CF2C,
  wPartyMenuTypeOrMessageID $D07C, wPartyMenuAnimMonEnabled $D09A,
  wSwappedMenuItem $CD3D, wLoadedMonStatus $CF9B, hPartyMonIndex $FF8C,
  hSwapTemp $FF95 — each derived+cross-checked against two verified anchors
  (derivations in the include block comment). gb_constants.inc gains the
  *_PARTY_MENU message ids + FIRST_PARTY_MENU_TEXT_ID + BIT_PARTY_MENU_HP_BAR.
- **Gate:** DEBUG_PARTYMENU FRAME.BIN (harness now enters through the real
  StartMenu_Pokemon) vs the bespoke baseline: HP bars, HP fractions, status
  column, icons, names, message box **byte-identical**; the only diffs are the
  two intended fidelity fixes — level digits now pret LEFT_ALIGN at col 14
  (bespoke right-aligned in 3), and the ▶ cursor (bespoke pre-drew it on the
  name row; pret's cursor lives on the HP rows, drawn by HandleMenuInput,
  which the dump runs before). Overworld DEBUG_TRANSITION baseline renders
  clean. `make` + `make check` green. Interactive pop-up/SWITCH pass needs a
  human (no key injection); formal sweep is S10.
- **H-flag:** not involved. **Bug tags:** GLITCH-safety div-0 clamp in
  GetHPBarLength (noted above).
- **Live-pass follow-up (same day):** user's interactive pass (via
  `DEBUG_BAGMENU_LIVE=1` seed) LGTM'd nav/pop-up/SWITCH; caught a few frames
  of garbled HP bars (",CLLLLLLM") on menu exit — .exitMenu ran LoadGBPal
  while the party windows were still listed but Restore… had already reloaded
  box patterns over the HP-bar tiles ($62-$7F). Fixed by dropping the party
  windows + whiteout (pret restores screen content during the whiteout via
  LoadScreenTilesFromBuffer2; window-model analog) before LoadGBPal.

## menus-port Session 4 — start_menu + bag realigned onto the generic drivers
- **Date:** 2026-07-02
- **Plan:** docs/current_plan_menus.md, Session 4. Bespoke
  `src/engine/menus/start_menu.asm` + `bag_menu.asm` **deleted**; faithful pret
  mirrors replace them (direct overwrite per user direction; single revertible
  commit gated by before/after FRAME.BIN diffs).
- **DisplayStartMenu / RedisplayStartMenu(_DoNotDrawStartMenu) / CloseStartMenu**
  — Source: pret `home/start_menu.asm`. Translated: NEW
  `dos_port/src/home/start_menu.asm` (HOME_SRCS). Faithful UP/DOWN manual wrap
  (wLastMenuItem guard, EVENT_GOT_POKEDEX counts 6/7, EraseMenuCursor),
  wBattleAndStartSavedMenuItem save at .buttonPressed, dispatch `cp 0..5` with
  EXIT falling through to CloseStartMenu. Divergences: SFX_START_MENU = TODO-HW;
  PrintSafariZoneSteps = STUB(safari); SaveScreenTilesToBuffer2 not needed
  (window-overlay model, DEVIATION-tagged: START window dropped while a
  sub-menu is open, redrawn on return); `jp CloseTextDisplay` folded into
  CloseStartMenu (port opens the menu from OverworldLoop, not DisplayTextID —
  CloseTextDisplay pops DisplayTextID's saved bank); port font swap-in/out
  (vFont time-share) kept from the bespoke preamble; CloseStartMenu calls
  LoadTextBoxTilePatterns faithfully and restores text_row_stride=20.
- **DrawStartMenu / PrintStartMenuItem** — Source: pret
  `engine/menus/draw_start_menu.asm`. Translated: NEW
  `dos_port/src/engine/menus/draw_start_menu.asm`. Canvas model: box at
  UI_START_MENU_(COL,ROW) stride 40, items at (COL+2, ROW+2k), cursor
  (COL+1, ROW+2); labels from generated `menu_strings.inc` (+ NEW sm_str_reset;
  gen_menu_strings.py extended) with pret-name equ aliases; SAVE<->RESET branch
  on wStatusFlags4 BIT_LINK_CONNECTED. wMaxMenuItem = item COUNT (pret's
  one-past-max quirk preserved; RedisplayStartMenu's wrap handles the phantom
  row). Port bridge: StartMenuShowWindow mirrors the canvas rect ->
  GB_TILEMAP1 rows 0-15 + set_single_window(UI_START_MENU_WX/WY/CLIP,
  rows*8); sm_canvas_mirror = menu_redraw_cb. gen_ui_layout.py now wraps the
  coord table in `%ifndef UI_LAYOUT_EQUATES_ONLY` so secondary consumers can
  include just the equates (frozen values unchanged).
- **ItemMenuLoop / StartMenu_Item + StartMenu_* seams** — Source: pret
  `engine/menus/start_sub_menus.asm`. Translated: NEW
  `dos_port/src/engine/menus/start_sub_menus.asm`. The bag now runs the real
  DisplayListMenuID(ITEMLISTMENU) over wListPointer=wNumBagItems with
  wBagSavedMenuItem cursor memory — SELECT-swap therefore live through
  swap_items.asm:HandleItemListSwapping. .choseItem erases the pret cursor
  cells (box-rel (1,2/4/6/8)) + PlaceUnfilledArrowMenuCursor + list_mirror
  (now exported). USE/TOSS box via wTextBoxID=USE_TOSS_MENU_TEMPLATE ->
  DisplayTextBoxID (S2 canvas dispatcher) + ut_show_window canvas->window
  bridge (GB_TILEMAP0 rows 21-25, UI_USE_TOSS_MENU_TEMPLATE_* descriptor);
  HandleMenuInput at stride 40, cursor (TX-1, TY), step 2*40. Divergences:
  USE = STUB(items-plan) -> ItemMenuLoop; CannotUseItemsHere/CannotGetOffHere
  texts = STUB(text) with control flow preserved; ItemMenuLoop's
  LoadScreenTilesFromBuffer2DisableBGTransfer/RunDefaultPaletteCommand
  subsumed by DisplayListMenuID's window-list rebuild (TODO-HW: palettes).
  StartMenu_Pokemon = wPartyCount guard + bespoke DisplayPartyMenu seam
  (STUB(S5) for field-move/SWITCH/STATS routing); Pokedex/TrainerInfo/
  SaveReset/Option = STUB(S6-S9) -> RedisplayStartMenu.
- **TossItem / TossItem_** — Source: pret `home/item.asm` +
  `engine/items/item_effects.asm:TossItem_`. Translated: NEW
  `dos_port/src/home/item.asm` (wrapper; banking = TODO-HW) + TossItem_
  appended to `src/engine/items/item_effects.asm`; NEW RemoveItemFromInventory
  home wrapper in `inventory.asm`. Faithful chain: IsItemHM -> IsKeyItem ->
  GetItemName/CopyToStringBuffer -> yes/no at pret (14,7) via
  InitYesNoTextBoxParameters + wTextBoxID=TWO_OPTION_MENU + DisplayTextBoxID
  (**first live wiring of the interactive 0x14 path**) -> CHOSE_SECOND_ITEM ->
  scf, else RemoveItemFromInventory + "Threw away". DEVIATION(text): the three
  dialogs (IsItOKToToss/ThrewAway/TooImportant, pret data/text/text_9.asm
  wording incl. wStringBuffer/wNameBuffer substitution) are drawn whole into
  the message box + appended as a window (UI_MESSAGE_BOX_* descriptor) with a
  down-arrow A/B prompt wait — PrintText_Overworld would collapse the window
  list and hide the item list; revisit when engine far-text streams exist as
  GB-space assets and dialog printing can composite with live windows.
- **Port-model sprite guard** — RedisplayStartMenu and CloseStartMenu call
  RefreshCollisionTileMap (newly exported from overworld.asm) — the analog of
  pret's screen-buffer save/restore: W_TILEMAP doubles as the
  CheckSpriteAvailability text-box-tile mirror, so it is scrubbed back to map
  tiles before the box redraw / after close. The canvas box at cols 30-39
  lands in the mirror at exactly its on-screen tile position, reproducing
  pret's NPC-hidden-under-menu behavior; list/dialog stride-20 scratch writes
  still alias mirror rows 0-9 during bag sub-flows (windows occlude correctly
  regardless — the compositor draws windows last; NPCs are frozen under
  BIT_FONT_LOADED; self-heals at the next RedisplayStartMenu/step).
- **Constants/includes:** gb_constants.inc + BICYCLE, BIT_LINK_CONNECTED,
  BIT_ALWAYS_ON_BIKE.
- **Harnesses:** DEBUG_BAGMENU hook moved into DisplayListMenuIDLoop
  (list_menu.asm) — RunBagMenuTest now drives the faithful StartMenu_Item;
  DEBUG_STARTMENU hook in RedisplayStartMenu; DEBUG_BAGMENU_CONFIRM deleted
  with the bespoke (interactive confirm now reachable via DEBUG_BAGMENU_LIVE).
- **Verification:** DEBUG_BAGMENU FRAME.BIN byte-identical to the bespoke
  baseline; DEBUG_STARTMENU menu-box region (x>=240) pixel-identical — the 262
  stray pixels outside are the wandering-NPC first-tick InitializeSpriteStatus
  transient (IMAGEINDEX=$ff for one tick) surfaced by the faithful
  UpdateSprites call, reachable only in the harness (menu opened straight from
  EnterMap before OverworldLoop's first tick; diagnosed via a temporary
  wSpriteStateData DUMP.BIN capture); overworld DEBUG_TRANSITION+BASELINE
  byte-identical; DEBUG_LISTMENU=3 render matches the bag; `make` +
  `make check` green.

## menus-port Session 3 — generic list/yes-no/swap drivers wired live
- **Date:** 2026-07-02
- **Plan:** docs/current_plan_menus.md, Session 3.
- **PrintLevel / PrintLevelFull / PrintLevelCommon** — Source: pret
  `home/pokemon.asm:363-389`. Translated: `dos_port/src/home/pokemon.asm`.
  H-flag: not involved. Bug tags: none. Divergences: none (faithful).
  Notes: '<LV>' = tile $6E; PrintNumber flags = (1<<BIT_LEFT_ALIGN)|1 byte in
  BH, digits in BL per the port PrintNumber convention.
- **list_menu.asm faithful completions** (pret `home/list_menu.asm`):
  `.pokemonList`/`.pokemonPCMenu` party-vs-box nick base — pret's `cp l`
  low-byte compare of [wListPointer] vs wPartyCount picks
  wPartyMonNicks/wBoxMonNicks (ESI) before GetPartyMonName; level path now
  saves/restores wNamedObjectIndex (pret push af/pop af) and copies
  wLoadedMonBoxLevel→wLoadedMonLevel for BOX_DATA. Divergences: none beyond
  the existing ; PROJ window projection.
- **list_menu call-convention fixes** (latent — file was check-only):
  (1) PlaceString was called with pret's DE register convention; the port
  takes EAX = FLAT source ptr (names + the quantity-menu spacer never drew).
  (2) The priced path read the entry id from EDX after PlaceString clobbered
  it (pret does `pop de` first) — now peeks the saved ptr at [esp+4].
- **list_menu port-model wiring:** new `list_mirror`/`qty_mirror` copy the
  staged boxes W_TILEMAP(stride 20)→GB_TILEMAP0(stride 32) regions —
  do_bg_transfer targets GB_TILEMAP1 per init.asm, so the add_window
  descriptors never saw the box; `menu_redraw_cb = list_mirror` during
  HandleMenuInput (same mechanism as yes_no's yn_mirror); the quantity box
  moved to its own scratch+tilemap region (QTY_SROW=12, matching bag_menu's
  distinct-start-row scheme) — it previously collided with the list box at
  scratch row 0.
- **CableClub_TextBoxBorder / CableClub_DrawHorizontalLine** — Source: pret
  `engine/link/cable_club.asm:944/974`. Translated: NEW
  `dos_port/src/engine/link/cable_club.asm`. Divergences: row advance uses
  [text_row_stride] (port TextBoxBorder convention) instead of hardcoded 20.
  Notes: $76-$7D border tile gfx (TrainerInfoTextBoxTileGraphics →
  LoadTrainerInfoTextBoxTiles) deferred to S8/I1 with its callers.
- **yes_no.asm** — TRADE_CANCEL_MENU now branches to CableClub_TextBoxBorder
  (pret text_box.asm:255-262). FIXED latent EBX corruption: `mov bh,[ebx+
  TOMD_INT_H]` rewrote bits 8-15 of the descriptor pointer before the
  int_w read and the option-string loads (geometry now staged via AX; EBX
  pushed around the border call). S2's FRAME.BIN gate only ran non-interactive
  ids, so the 0x14 path had never executed; first live exercise comes with
  S4's bag realign. Also added pret's pre-HandleMenuInput clears
  (wTwoOptionMenuID=0, res BIT_NO_TEXT_DELAY; teardown's clear kept as a
  no-op backstop).
- **Makefile:** list_menu.asm → HOME_SRCS; swap_items.asm → GAME_SRCS
  (out of ITEMS_CHECK_SRCS); cable_club.asm → GAME_SRCS. New
  `DEBUG_LISTMENU=<mode>` gate (debug_dump.asm:RunListMenuTest) drives
  DisplayListMenuID input-free via the Old-Man-battle auto-select branch;
  modes 0 (party nicks + :L levels), 2 (price column), 3 (bag ×qty +
  IsKeyItem suppression) verified by FRAME.BIN render.
- **Gate:** baseline FRAME.BINs byte-identical before/after (overworld
  DEBUG_TRANSITION+BASELINE, DEBUG_STARTMENU, DEBUG_BAGMENU); `make` +
  `make check` green. No live caller invokes the generic drivers yet — that
  starts in S4.

## menus-port Session 2 — DisplayTextBoxID_ + DisplayTextIDInit
- **Date:** 2026-07-02
- **Plan:** docs/current_plan_menus.md, Session 2.
- **`DisplayTextBoxID_` family** — Source: pret `engine/menus/text_box.asm` +
  `data/text_boxes.asm`. Translated: `dos_port/src/engine/menus/text_box.asm`
  (full rewrite of the old scaffold; now LINKED via GAME_SRCS). Dispatcher +
  SearchTextBoxTable + GetTextBoxIDCoords/GetTextBoxIDText/
  GetAddressOfScreenCoords + DisplayMoneyBox/DoBuySellQuitMenu/
  DisplayFieldMoveMonMenu/GetMonFieldMoves. Divergences: canvas model — tables
  hold UI_*-projected 40×25 coords from the generated `ui_layout_menus.inc`
  (`; PROJ` tags); `text_row_stride` forced to 40 for the dispatch and restored
  flags-safely at `.done`; function-table stride 3→5 and text+coord 9→11 (dd
  flat ptrs); GetTextBoxIDText returns the text ptr in EAX not DE (flat ptr);
  TWO_OPTION_MENU dispatches to yes_no.asm's `DisplayTwoOptionMenu` (ONE impl,
  port takes box coords from yes_no state — DEVIATION tagged); JP_* rows
  omitted (matches S1 seeder). H-flag: not involved.
- **`DisplayTextBoxID` wrapper** — Source: pret `home/textbox.asm`. Translated:
  new `dos_port/src/home/textbox.asm` (HOME_SRCS). `homecall_sf` collapses to a
  plain call (flat memory); supersedes the interim def in `text_script.asm`
  (now extern there; its line-61/89 TODOs marked RESOLVED). H-flag: not involved.
- **`DisplayTextIDInit`** — Source: pret `engine/menus/display_text_id_init.asm`.
  Translated: new `dos_port/src/engine/menus/display_text_id_init.asm`
  (GAME_SRCS). Divergences: both borders draw at pret GB coords into the
  stride-20 W_TILEMAP scratch (overworld window-composited model; dialog cell =
  text.asm MSG_BOX_ESI, idempotent double-draw as pret); `ldh [hWY],0` is a
  TODO-HW comment with NO write — H_WY is the port's dialog-open gate
  (sync_dialog_window) and set_single_window owns it; `ld b,HIGH(vBGMap1)` kept
  for register parity into the port's 3-DelayFrame CopyScreenTileBufferToVRAM.
  pret's bit-then-res-then-branch on wMiscFlags reproduced via AH copy. Sprite
  loops faithful: facing→orig-facing copy slot 1..15 (+0x100 = pret `inc h`),
  stand-still `and $fc` over 16 image indices ($ff skip). H-flag: not involved.
- **yes_no.asm promotion** — moved HOME_CHECK_SRCS→HOME_SRCS (all externs
  resolve; `DisplayTwoOptionMenu` now global). No collisions (grep-verified).
- **Includes** — `gb_memmap.inc`: + wFieldMoves/wNumFieldMoves/
  wFieldMovesLeftmostXCoord/wLastFieldMoveID/wMiscFlags 0xCD60/
  BIT_NO_SPRITE_UPDATES/hFieldMoveMonMenuTopMenuItemX (derivations noted
  in-file; no .sym exists) + pret aliases NUM_SPRITESTATEDATA_STRUCTS/
  SPRITESTATEDATA1_LENGTH. `gb_constants.inc`: all missing wTextBoxID ids.
  **Fixed `m8_2_pending_symbols.inc`: its wMiscFlags 0xD72E was pokered's
  wd72e — wrong; canonical 0xCD60 now in gb_memmap.inc** (trainer_engine.asm
  check-only consumer inherits the fix).
- **Verification** — new `DEBUG_TEXTBOXID=<id>` harness (Makefile flag →
  `RunTextBoxIDTest` in debug_dump.asm, hooked in EnterMap): seeds the debug
  party, enters flat-canvas mode (InitBattle's sequence), blanks W_TILEMAP to
  TILE_SPC, draws the box via the real DisplayTextBoxID, dumps FRAME.BIN. All
  14 non-interactive table ids byte-verified by a scripted border-corner pixel
  check (coord 0x01/0x03/0x07/0x0D/0x10/0x11; text+coord 0x06/0x0B/0x1B/0x0C/
  0x0E/0x0F; function 0x13 money box + 0x04 field-move menu, whose dynamic
  4-field-move growth landed exactly at pret's math projected +20/+7:
  box (29,9)-(39,24), names rows 11/13/15/17). 0x14/0x15 are interactive
  (HandleMenuInput) — 0x15's box template verified via 0x0E. `make` +
  `make check` green.

## home/ rectification swarm — WAVE 0 (silent-wrong bugs & build landmines)
- **Date:** 2026-07-01
- **Plan:** docs/plans/home_rectification.md, Wave 0 (M0.1–M0.5).
- **M0.1 `Random_` PRNG double-add fix** — Source: pret `engine/math/random.asm:1-13`.
  Translated: `dos_port/src/engine/math/random.asm`. Bug tags: fixes an UNFAITHFUL
  divergence (no BUG_FIX_LEVEL guard — the reliance on the caller's leftover carry is
  a faithful Gen-1 quirk, so the fix keeps it). Divergences: none (faithful). Notes: the
  port did `add al,bl` then `adc al,bl`, double-adding DIV and clobbering the caller's
  incoming carry (result `hRandomAdd + 2*DIV + carry` vs pret's `+ DIV + carry_in`).
  Fixed to a single `adc al,bl`; the caller's carry is snapshotted with `pushf` at entry
  (before the CF-clobbering `+0x25` DIV churn) and restored with `popf` right before the
  adc. The `+0x25` DIV churn is retained (documented faithful adaptation — no free-running
  DIV in the port).
- **M0.2 Bankswitch symbols** — Source: pret `home/bankswitch2.asm:BankswitchCommon`,
  `home/bankswitch.asm:BankswitchHome/BankswitchBack`. Translated: new
  `dos_port/src/home/bankswitch.asm` (added to Makefile `HOME_SRCS`). Divergences:
  faithful-by-design no-op (flat EBP model has no MBC banks). Notes: records the requested
  bank in `H_LOADED_ROM_BANK` (0xFFB8) for faithful read-back; the `rROMB` write is a
  `; TODO-HW` no-op. Resolves the dangling `BankswitchCommon` extern. The dead twin
  `src/home/copy.asm` (its only caller) was deleted (M0.5).
- **M0.3 `GetMachineName` restore** — Source: pret `home/names.asm:57,96-97`. Translated:
  `dos_port/src/home/names.asm`. Divergences: none (faithful). Notes: HM path left
  `id + NUM_HMS` in `wNamedObjectIndex`; now `push eax` on entry / `pop eax`+write-back at
  the single `ret` (mirrors pret push af/pop af). Verified single push/pop balance (no early
  ret; all branches fall through). Assembles at BUG_FIX_LEVEL 0 and 2.
- **M0.4 `GBPalWhiteOut` sprites** — Source: pret `home/palettes.asm:34-43`. Translated:
  `dos_port/src/movie/title.asm`. Divergences: CGB `UpdateCGBPal_*` commit deferred (Phase 5,
  same status as the pre-existing BGP stub). Notes: white-out now zeroes `IO_OBP0`/`IO_OBP1`
  in addition to `IO_BGP`, so sprites white out too. Follow-up (logged, not done): confirm
  `render_sprites` reads OBP0/OBP1 per-OBJ so the effect is visible.
- **M0.5 build hygiene** — deleted dead `src/home/copy.asm` (superseded twin of
  `copy_data.asm`; colliding CopyData/FarCopyData globals, unique routines unreferenced).
  Added `count_set_bits.asm` as **check-only** (`HOME_CHECK_SRCS`) — linking it breaks the
  build on undefined `wNumSetBits` (no memmap alias / no caller yet); follow-up: add
  `wNumSetBits` alias + move to HOME_SRCS when a caller lands. Kept+annotated (still out of
  build): `src/engine/predefs.asm` (undefined `PredefPointers` table), `src/engine/joypad.asm`
  (superseded by HAL `src/input/joypad.asm`; ends in undefined `Joypad`),
  `src/engine/menus/swap_items.asm` (undefined `DisplayListMenuIDLoop`; Wave 4 M4.2 wires it in).
  Deferred to M5.2: the duplicate `AddPartyMon_WriteMovePP` global (only bites when `add_mon.asm`
  is linked, which it isn't yet). Result: `make -C dos_port` links `PKMN.EXE`; `make check` clean.

## home/ rectification swarm — WAVE 1 (text engine)
- **Date:** 2026-07-01
- **Plan:** docs/plans/home_rectification.md, Wave 1 (M1.1–M1.3).
- **M1.1 `TX_FAR` ($17) recursive far-text** — Source: pret `home/text.asm:TextCommand_FAR (~L601)`.
  Translated: `dos_port/src/text/text.asm` (`.cmd_far`). H-flag: n/a. Divergences: none (faithful).
  Notes: was `add esi,3 / jmp .next_cmd` (dropped the far text → blank box). Now reads the
  little-endian GB pointer + bank byte, saves outer ESI (GB stream ptr) and `hLoadedROMBank`,
  sets the far pointer, recurses through the public `TextCommandProcessor` (matching pret's
  push hl / recurse / pop hl and double delay-flag save/restore), then restores and resumes.
  EBX (tile cursor) carries forward per pret. **Correct-but-dormant:** no live caller currently
  stages `TX_FAR` bytes into EBP space — follow-up (non-home glue): a far-text data-staging pass
  laying pret far-text bodies at fixed GB offsets and switching DEFERRED/hand-fused sites to
  emit real `$17 lo hi bank` operands. Composite `text_far`+`text_asm` sites (e.g. charge.asm)
  additionally need the still-skipped TX_START_ASM ($08) splice.
- **M1.2 text control codes** — Source: pret `home/text.asm` (TextCommand_PAUSE/DOTS/
  PROMPT_BUTTON/WAIT_BUTTON, _ContText, PageChar). Translated: `dos_port/src/text/text.asm`.
  Divergences (documented): (1) timed waits (TX_PAUSE 30f, TX_DOTS ~10f/glyph, `<PAGE>` 20f)
  use bounded `DelayFrame` loops, NOT pret's set-`hFrameCounter`-and-spin idiom — that would
  deadlock until Wave 2/M2.1 lands the `hFrameCounter` decrementer; revisit then. (2) arrow
  suppression via a new module byte `mts_hide_arrow` guarding the ▼ in `manual_text_scroll`.
  Notes: TX_DOTS now animates `…` glyphs advancing the cursor; TX_PROMPT_BUTTON vs
  TX_WAIT_BUTTON split on `wLinkState == LINK_STATE_BATTLING` (arrow vs none); `<_CONT>` ($4B,
  wait+scroll) split from `<SCROLL>` ($4C); `<PAGE>` ($49) implemented incl. `BIT_PAGE_CHAR_IS_NEXT`
  (hUILayoutFlags bit3 → run the `<NEXT>` body); `hClearLetterPrintingDelayFlags` folded into the
  TCP prologue. Constants (`BIT_PAGE_CHAR_IS_NEXT`, `H_CLEAR_LETTER_PRINTING_DELAY_FLAGS`,
  `LINK_STATE_BATTLING`, `CHAR_DOTS_GLYPH`) kept local to text.asm so the patch is standalone.
- **M1.3 `DisplayTextID` dispatch tree** — Source: pret `home/text_script.asm` + `home/predef_text.asm`.
  Translated: new `dos_port/src/home/text_script.asm` + `predef_text.asm` (**check-only**; added to
  `HOME_CHECK_SRCS`). New globals: `DisplayTextID` (was extern-only, now defined), `CloseTextDisplay`,
  `HoldTextDisplayOpen`, `AfterDisplayingTextID`, `DisplayPokemartDialogue`, `LoadItemList`,
  `DisplayTextBoxID`, `FarPrintText`, `PrintPredefTextID`, `Set`/`RestoreMapTextPointer`. Faithful
  skeleton; non-home/not-yet-ported deps left as `extern` with `; TODO(home-rectify M1.3 follow-up)`
  markers (menu/PC/mart special cases → Wave 4; Pikachu emotion → Wave 9; `TextPredefs` Tier-2 table;
  far-text data labels → M1.1 staging). Caveats flagged in-source: map text-pointer addressing model
  (port has no 16-bit ROM text-pointer table; uses 32-bit flat labels), Safari-blackout event gate.
  **Integration decision:** the ~40 missing WRAM/HRAM/constant symbols the agent needed are
  heuristic-derived (a +0x2EC clean-vs-branch WRAM correction) with one placeholder HRAM slot
  (`hSavedMapTextPtr`). Rather than inject unverified `equ`s into the canonical `gb_memmap.inc`/
  `gb_constants.inc` (included by every file) for a not-yet-linked unit, they live in an isolated,
  `%ifndef`-guarded scaffold `dos_port/include/m1_3_pending_symbols.inc` that only these two files
  include. **Follow-up (when a later wave links these routines):** validate the addresses, allocate a
  real `hSavedMapTextPtr` HRAM pair in the port scheme, migrate into the canonical includes, and drop
  the scaffold `%include`.

## home/ rectification swarm — WAVES 2 & 3 (frame/VBlank + input)
- **Date:** 2026-07-01
- **Plan:** docs/plans/home_rectification.md, Waves 2–3 (M2.1, M2.2, M3.1, M3.2, M3.3).
- **Renderer-integrity gate:** a hard constraint was injected mid-flight — ported VBlank/BG/WY
  routines must NOT assume the GB 32×32 torus geometry against the port's native-width
  44×32 `wSurroundingTiles` surface / 40×25 battle canvas. Verified by static diff
  (render_bg/render_sprites/present/present_windows untouched; WY gate byte-identical when
  the new `wDisableVBlankWYUpdate` is 0; new DelayFrame calls are pure insertions to
  self-gating inert routines) and a live DOSBox-X run (user-confirmed render intact).
  See memory `renderer-native-viewport-invariant`.
- **M2.1 frame/VBlank timers** — Source: pret `home/vblank.asm` + `home/play_time.asm`.
  Translated: `dos_port/src/video/frame.asm` + new `dos_port/src/util/play_time.asm` (LINK).
  Added: guarded `dec hFrameCounter` in DelayFrame (unblocks pret's set-and-spin idiom);
  `TrackPlayTime` (frames→s→m→h + maxed, gated on `BIT_GAME_TIMER_COUNTING`) called per frame;
  `CountDownIgnoreInputBitReset` global (re-arm + `hJoyPressed`/`hJoyHeld` clear);
  `wDisableVBlankWYUpdate` WY-commit gate (default 0 = unchanged). **Integration fix:** removed
  the inline `wIgnoreInputCounter` countdown at overworld.asm (was a double-decrement now that
  `CountDownIgnoreInputBitReset` runs each frame; the DelayFrame path also clears hJoyPressed).
- **M2.2 BG animation/transfer** — Source: pret `home/vcopy.asm`. Translated: new
  `dos_port/src/video/bg_anim.asm` (LINK). `UpdateMovingBgTiles` (self-gated on hTileAnimations;
  mutates only vChars pattern bytes + sets `g_tilecache_dirty`) and `VBlankCopyBgMap` (self-gated
  on its row-count low byte; copies with GB width-20/stride-32, NOT the port's SCREEN_WIDTH=40).
  Both inert until armed; `rLY` in-vblank guard dropped as `; TODO-HW` (DelayFrame is the port's
  vblank). Flower frames embedded as `db`; native-surface wiring is a documented follow-up if
  ever armed.
- **M3.1 joypad edge/mask** — Source: pret `engine/joypad.asm` (`_Joypad`/`DiscardButtonPresses`/
  `TrySoftReset`) + `home/init.asm:SoftReset`. Translated: `dos_port/src/input/joypad.asm`.
  Added `hJoyLast`/`hJoyReleased`/`hJoyPressed` edges, `wJoyIgnore` mask, `DiscardButtonPresses`
  (BIT_DISABLE_JOYPAD gate), and the A+B+Start+Select combo → new non-fatal `pad_reset` global
  (Esc-quit untouched). Follow-up: wire `pad_reset` to an in-process SoftReset (StopAllSounds→
  white-out→re-Init) once a re-init entry exists. Bit order confirmed identical to pret PAD_*.
- **M3.2 `JoypadLowSensitivity`** — Source: pret `home/joypad2.asm:16-53`. Translated: new
  `dos_port/src/input/joypad_lowsens.asm` (LINK, HAL_SRCS); wired into title.asm (dropped the
  old local stub) + town_map.asm (check-only). 30-frame initial delay, 5-frame auto-repeat,
  A/B-held suppression via hJoy6/hJoy7; uses the M2.1 `hFrameCounter` decrementer.
- **M3.3 simulated joypad + scripted-NPC movement** — Source: pret `home/overworld.asm`,
  `home/map_objects.asm`, `home/npc_movement.asm`, `home/pathfinding.asm`. Translated: new
  `dos_port/src/engine/overworld/simulate_joypad.asm` (LINK) + `pathfinding.asm` (CHECK) +
  overworld.asm patch. `AreInputsSimulated`/`GetSimulatedInput`/`StartSimulatingJoypadStates`
  (full buffer/index/override-mask) generalize the door-exit hack — the verified door auto-walk
  now routes through the faithful system (live-confirmed render OK). `MoveSprite`/`CalcDifference`/
  `DivideBytes`/RLE decode in pathfinding.asm. Scripted-NPC dispatch half added to
  `RunNPCMovementScript` behind `%ifdef NPC_MOVEMENT_SCRIPTS_LINKED` (inert; per-map tables +
  M6.2 `_UpdateSprites` slot dispatch are follow-ups). New memmap symbols added canonically
  (sim-joypad WRAM + hJoy/div2 HRAM + BIT_SCRIPTED_NPC_MOVEMENT); `W_NPC_MOVEMENT_DIRECTIONS`
  aliases the existing `W_SIMULATED_JOYPAD_STATES_END` union base 0xCC5B.
- **Memmap follow-up (logged):** M2.1/M3.1 flagged a `W_JOY_IGNORE` address question
  (memmap 0xCCB7 vs sym 0xCD6B) — pre-existing, not changed this wave; revisit separately.

## home/ rectification swarm — WAVE 4 (menus)
- **Date:** 2026-07-01
- **Plan:** docs/plans/home_rectification.md, Wave 4 (M4.1, M4.2, M4.3).
- **M4.1 YES/NO framework** — Source: pret `home/yes_no.asm`. Translated: new
  `dos_port/src/home/yes_no.asm` (CHECK-only; no live caller yet). `YesNoChoice`,
  `TwoOptionMenu`, `DisplayYesNoChoice`, `WideYesNoChoice`, `YesNoChoicePokeCenter`,
  `InitYesNoTextBoxParameters`; faithful carry contract (CF=0 → YES/first item). **UI
  projection (user requirement):** box drawn box-relative into stride-20 `W_TILEMAP` and
  shown via the existing bag `add_window` descriptor pipeline (reused, not reinvented) —
  no raw GB coords hit the display. Per-context anchor via `yn_proj_mode`: mode 0
  (overworld, top-right X+20) default; mode 1 (battle center X+10/Y+3) exposed but
  UNVERIFIED (no battle caller). `; PROJ` tags at placements; registered in
  `docs/ui_projection.md`.
- **M4.2 generic list menu** — Source: pret `home/list_menu.asm`. Translated: new
  `dos_port/src/home/list_menu.asm` (CHECK) + `swap_items.asm` wired in (CHECK, its
  pre-existing assembly failure fixed). `DisplayListMenuID`/`DisplayListMenuIDLoop`/
  `DisplayChooseQuantityMenu` keyed on `wListMenuID`. **UI projection:** reuses
  bag_menu's exact LIST_* anchor + `add_window` so a list via the generic driver lands
  where the bespoke bag list does; `; PROJ` tags + registry rows. Deferred (TODO):
  PC-box/battle/mart anchors + `ClearScreenArea`/`LoadGBPal`/`PrintLevel` deps (no
  caller). bag/party menus stay bespoke; converging them onto this driver is a follow-up.
- **M4.3 menu-input fidelity** — Source: pret `home/window.asm`. Translated:
  `dos_port/src/home/window.asm`. Added gated `wMenuWrappingEnabled` wrap,
  `wMenuJoypadPollCount` timeout, `wMenuWatchMovingOutOfBounds`; `wMenuCursorLocation`-
  backed cursor; new `EraseMenuCursor`/`PlaceUnfilledArrowMenuCursor`/two-phase
  `HandleDownArrowBlinkTiming` globals. Default behavior byte-identical for existing
  battle callers (all new paths flag-gated to 0). **De-dup:** the single-phase
  `HandleDownArrowBlinkTiming` in `text.asm` was removed and re-pointed (`extern`) to
  window.asm's canonical two-phase version (fixes a latent spurious-arrow draw).
- **Integration / dedup (per user guidance "match upstream + deduplicate"):** all menu
  WRAM/HRAM/constants added canonically to `gb_memmap.inc`/`gb_constants.inc`; the members'
  local placeholder `equ` blocks were stripped (identical-value dups removed); list_menu's
  lowercase HRAM aliases re-pointed to the canonical `H_*`/`W_*` symbols. `H_JOY5/6/7`
  promoted to canonical memmap (completing a Wave-3/M3.2 follow-up). PKMN.EXE links,
  `make check` clean.

## home/ rectification swarm — WAVE 5 (pokemon / item data correctness)
- **Date:** 2026-07-01
- **Plan:** docs/plans/home_rectification.md, Wave 5 (M5.1–M5.4).
- **M5.1 `_AddPartyMon` completeness** — Source: pret `engine/pokemon/add_mon.asm:_AddPartyMon`.
  `dos_port/src/engine/pokemon/add_party_mon.asm`. Added: Pokédex owned/seen `FlagAction`
  (flat `IndexToPokedex`); in-battle wild-catch path (copy enemy DVs/HP/status + enemy
  MaxHP stat block instead of fresh `CalcStats`); trainer fixed IVs; real OTID from
  `wPlayerID`. **Struct offset-7 (MON_CATCH_RATE / Gen-2 held item) preserved verbatim.**
- **M5.2 party/box movement + dup fix** — Source: pret `home/move_mon.asm` + `home/pokemon.asm`.
  `add_mon.asm` now **LINKS** (POKEMON_SRCS) — the M0.5-deferred duplicate `AddPartyMon_WriteMovePP`
  resolved by **deleting** add_mon's unreferenced dead copy (canonical stays sole in
  write_moves.asm); also fixed 3× illegal `movzx reg,word <equ>` → `mov` (which incidentally
  fixes a latent 16-bit-wrap bug). `_MoveMon`/`_AddEnemyMonToPlayerParty` full-struct copies
  preserve offset-7. `GetPartyMonName`/`GetPartyMonName2` implemented in home/pokemon.asm
  (removed the `ret`-stub in battle_exp_stubs.asm). `GetMonHeader` fossil/ghost sprite-ID
  guards added (skip OOB BaseStats index).
- **M5.3 give / money** — Source: pret `home/give.asm` + `home/money.asm` + `home/inventory.asm`.
  New `dos_port/src/home/give.asm` (`GiveItem`/`GivePokemon`) + `money.asm` (`HasEnoughMoney`/
  `HasEnoughCoins`/`AddAmountSoldToMoney`) — CHECK-only (deps `_GivePokemon`/`DisplayTextBoxID`
  not yet linked). `subtract_paid_money.asm`: restored the money-box redraw + dropped the magic
  `wTextBoxID` (now canonical). `global CopyToStringBuffer` added in core.asm for graduation.
- **M5.4 HM/key-item predicates** — Source: pret `home/names.asm`/`home/item.asm`/`home/map_objects.asm`.
  New `dos_port/src/home/item_predicates.asm` (CHECK): `IsItemHM`/`IsMoveHM`/`HMMoves` (Tier-2 db
  list)/`IsItemInBag`/`IsKeyItem`/`IsKeyItem_` (sets `wIsKeyItem`), via the established
  `FlagAction` predef-slot convention. Follow-up: converge bag_menu's inlined `.is_key_item`.
- **Integration/dedup:** Wave-5 WRAM/HRAM/constants added canonically (incl. lowercase Dex
  aliases, `wPlayerCoins`/`hCoins`, `MONEY_BOX`, box-move + fossil/ghost constants); members'
  local placeholder blocks stripped; `gb_constants.inc` include added where needed. PKMN.EXE
  links, `make check` clean.

## home/ rectification swarm — WAVE 6 (sprites & pics)
- **Date:** 2026-07-01
- **Plan:** docs/plans/home_rectification.md, Wave 6 (M6.1–M6.3).
- **M6.1 OAM/sprite reloaders** — Source: pret `home/oam.asm`/`reload_sprites.asm`/
  `reset_player_sprite.asm`/`reload_tiles.asm`. New (CHECK): `oam.asm` (`WriteOAMBlock` → writes
  the shadow-OAM array `W_SHADOW_OAM`, NOT GB-OAM geometry), `reset_player_sprite.asm`
  (`ResetPlayerSpriteData` full two-block FillMemory zero-clear + value-set), `reload_tiles.asm`
  (`ReloadMapData`/`ReloadTilesetTilePatterns`), `reload_sprites.asm` (`ReloadMapSpriteTilePatterns`).
  Zero missing memmap symbols. Follow-up: `SetupPlayerSprite` (overworld boot scaffold) could call
  `ResetPlayerSpriteData`.
- **M6.2 `_UpdateSprites` branches** — Source: pret `engine/overworld/sprite_collisions.asm`.
  `dos_port/src/engine/overworld/movement.asm`. Added slot-$f0 → `SpawnPikachu` dispatch and
  scripted-NPC → `DoScriptedNPCMovement` dispatch, both **gated so default behavior is byte-identical**
  (neither trigger is armed in the live build). Documented divergence: gated on M3.3's
  `BIT_SCRIPTED_NPC_MOVEMENT` (bit 0) vs pret's exact bit-7/`wNPCMovementScriptSpriteOffset` split —
  reconcile when the stepper is ported.
- **M6.3 mon front-pic dispatch** — Source: pret `home/pics.asm`/`home/pokemon.asm`.
  `dos_port/src/gfx/pics.asm` (LINK-safe by default). `LoadFrontSpriteByMonIndex`/
  `LoadFlippedFrontSpriteByMonIndex` (internal-index→dex via `IndexToPokedex`, faithful Rhydon trap),
  `LoadMonFrontSprite`, `UncompressMonSprite` (reuses the existing decompressor + merge pipeline;
  `uncompress.asm` unchanged). The Gen-1 front-pic pointer lives in the base-stats record (zeroed in
  the flat port), so the port resolves via a dex-keyed `MonFrontPics` table — **Tier-1 generated data
  follow-up** (turnkey `gen_mon_pics.py` + `mon_pics.asm` wrapper validated via partial link; enabled
  with `-D MON_FRONT_PICS`). Default build falls back to the embedded debug pic; debug `.pic` stubs
  retained (still used by `debug_dump.asm`), marked superseded.
- **Integration stubs:** `SwitchToMapRomBank` added faithfully to `bankswitch.asm` (flat bank record;
  unblocks reload_tiles/text_script/run_map_script); `SpawnPikachu` (→ Wave 9) + `DoScriptedNPCMovement`
  ret-stubs in new `overworld_stubs.asm` (LINK) so the live movement.asm jumps resolve. PKMN.EXE links,
  `make check` clean.

## home/ rectification swarm — WAVE 7 (overworld gameplay systems)
- **Date:** 2026-07-01
- **Plan:** docs/plans/home_rectification.md, Wave 7 (M7.1–M7.5).
- **Integration note:** a concurrent worker's `git checkout` reset `overworld.asm` to HEAD
  mid-wave, wiping the session's M3.3 reroute + double-decrement fix + M7.1 hook. Recovered
  from M3.3's full-file preview (verified HEAD→preview delta was exactly the M3.3 reroute,
  no pre-session loss) and re-applied all edits via manual `Edit`. See memory
  `swarm-workers-must-not-touch-git`. All four `overworld.asm` routine hooks integrated by
  manual insertion (not `git apply`) since workers forked at different times.
- **M7.1 wild encounters + steps** — new `wild_encounter_check.asm` (LINK). `StepCountCheck`
  wired live in `OverworldLoop` (safe — only decrements WRAM counters); `NewBattle`/
  `AllPokemonFainted` behind `WILD_ENCOUNTERS_LIVE` (inlines pret's DetermineWildOpponent gate,
  since the port's InitBattle is screen-setup only). `AnyPartyAlive` party-HP scan.
- **M7.2 signs + hidden events** — new `hidden_events.asm` (LINK subset: `CopySignData`/`SignLoop`/
  `ArePlayerCoordsInArray`/`CheckCoords`; deep routines behind `M72_HIDDEN_EVENTS_DEEP`) +
  `overworld_text.asm` (CHECK). `CopySignData` wired into `LoadMapHeader` (guarded on wNumSigns=0 →
  byte-identical for sign-less maps). Sign A-press wire is a logged follow-up.
- **M7.3 ledges + tile-pairs** — new `ledges.asm` (CHECK). `CheckForJumpingAndTilePairCollisions`/
  `CheckForTilePairCollisions{,2}`/`HandleLedges`/`HandleMidJump`; `CollisionCheckOnLand` hook
  behind `OVERWORLD_LEDGES` (off by default → land collision byte-identical). Needs `HandleMidJump`
  per-frame wire + renderer Y-pixel honor before going live.
- **M7.4 warp fidelity** — new `warp_check.asm` (LINK). Faithful `ExtraWarpCheck` function-1
  (`IsPlayerFacingEdgeOfMap`) / function-2 (`IsWarpTileInFrontOfPlayer`) per-map dispatch replaces
  the hardcoded "facing DOWN" test; working bottom-row door exits verified preserved (all interior
  tilesets → fn1 at the same coordinate). `CheckIfInOutsideMap` provided.
- **M7.5 player-gfx + bike/surf** — new `player_gfx.asm` (CHECK). `LoadWalkingPlayerSpriteGraphics`
  family + `LoadPlayerSpriteGraphicsCommon`, `IsBikeRidingAllowed`, `ForceBikeOrSurf`,
  `DoBikeSpeedup`, `StopBikeSurf`. Follow-up: replace the overworld.asm walking-only scaffold +
  generate RedBike/Seel/SurfingPikachu sprites when promoted to LINK.

## Move-effect swarm scaffold (S2–S4) + PoisonEffect_
- **Source:** pret `engine/battle/core.asm:3294-3436` (array-gated dispatch),
  `engine/battle/effects.asm` (PoisonEffect, PrintStatText, ConditionalPrintButItFailed,
  PrintButItFailedText_, PrintDidntAffectText, PrintMayNotAttackText, CheckTargetSubstitute),
  `home/array2.asm:IsInArray`, `data/battle/stat_mod_names.asm`.
- **Translated:** `src/home/array.asm` (IsInArray global); `src/engine/battle/core.asm`
  (ExecutePlayerMove/ExecuteEnemyMove faithful 6-checkpoint dispatch); `src/engine/battle/
  move_effect_helpers.asm` (shared helpers + faithful-anim hooks); `src/engine/battle/
  move_effects/poison.asm` (PoisonEffect_, the gold-standard reference handler); `effects.asm`
  (JumpMoveEffect live, table re-pointed); tooling: `tools/build_index` + `tools/work_queue`
  (`move` category).
- **Date:** 2026-06-30
- **H-flag:** Not involved (flags via instruction choice; IsInArray returns CF, the dispatch
  branches on it).
- **Bug tags:** PoisonEffect_ carries `BUG(cosmetic)` for the Gen-1 1/256 miss inherited via
  MoveHitTest (fix, if any, lives in MoveHitTest under BUG_FIX_LEVEL, not the handler).
- **Divergences (PoisonEffect_):** `PlayBattleAnimation2` / `PlayCurrentMoveAnimation2` → no-op
  stubs: literal move subanimation deferred (ANIMATION=OFF path, §2.1). Everything else faithful
  (status byte, Toxic branch, accuracy split, text via the real PrintText).
- **Notes:** `JumpMoveEffect` is now LIVE (effects.asm MoveEffectPointerTable); the core_stubs
  stub was dropped. Only StatModifierUp/DownEffect + PoisonEffect_ are wired; every other entry
  → `UnportedMoveEffect` no-op (battle can't crash on an unported move) until the swarm (S5)
  audits + the master wires each. Link-cascade resolutions: the overworld `PrintText` (text.asm)
  was renamed `PrintText_Overworld` so the bare `PrintText` is the battle printer the swarm
  bodies extern (only linked overworld caller, map_sprites.asm, was updated); `CheckTargetSub-
  stitute` is now the faithful helper (battle_stubs no-op removed → MoveHitTest's substitute
  check is real); `stat_mod_effects`/`badge_boosts`/`status_penalties` moved BATTLE_SRCS→
  FRONTEND_SRCS, and the duplicate battle_exp_stubs badge/penalty stubs were deleted.
  `DelayFrames`/`PlayApplyingAttackAnimation` reuse the live frame.asm/animations.asm globals.
  Verified: build green (`SKIP_TITLE=1 DEBUG_BATTLE_LIVE=1`, `make check`), and the enemy-move
  dispatch path ran end-to-end in DOSBox-X (DEBUG_BATTLE_ENEMYHIT) without hang/crash.

## InitBattle (Wave 2 Stage 1a — battle frame + intro text)
- **Source:** front-end scaffold (no single pret label); mirrors the battle screen
  build order in `engine/battle/init_battle.asm` / `core.asm`.
- **Translated:** `dos_port/src/engine/battle/init_battle.asm`
- **Date:** 2026-06-28
- **H-flag:** Not involved.
- **Bug tags:** none.
- **Notes:** Stage 1a renders the battle screen on the **full 320×200 (40×25)
  widescreen canvas** (user direction 2026-06-28: use the wide screen, center the
  default GB UI now, extend elements outward later). Layout: blank the whole 40×25
  `W_TILEMAP` → hand-draw the bottom dialog box at canvas (10,15) → fixed intro text
  "Wild POKéMON / appeared!". The GB 20×18 default layout is centered via col-offset
  10 = (40−20)/2 and row-offset 3 ≈ (25−18)/2.
  **Render path (key, reusable):** the battle screen is the BG plane. `render_bg`'s
  non-overworld branch already decodes the whole 40×25 `W_TILEMAP` straight to the
  back buffer (the title/menu path); it only renders the overworld when
  `wCurrentTileBlockMapViewPointer` is nonzero. So `InitBattle` zeroes that pointer
  + `IO_SCX`/`IO_SCY` and `hide_window`s, and `frame.asm` just calls `render_bg`
  (the Stage-0.5 `clear_backbuffer_battle` + centered-window descriptor are gone).
  No new full-screen renderer was needed.
  **Text-helper constraint:** `TextBoxBorder`/`PlaceString` hardcode a 20-wide
  stride (`text.asm: SCREEN_W_TILES equ 20`), so they cannot lay out into the
  40-wide canvas. The dialog box is hand-drawn with the box-border charmap tiles
  ($79–$7E) at stride 40; single-line text (no `<NEXT>`/`<LINE>`) is
  stride-agnostic, so `PlaceString` still works for HUD names later. The fixed
  intro is raw glyph tile-bytes (renderable glyphs $60+ map 1:1 to tile IDs).
  Also clears `wUpdateSpritesEnabled` so the per-frame `update_oam`/`PrepareOAMData`
  rebuild stops re-showing the overworld player sprite after `ClearSprites`.
  (Superseded the first Stage-0.5/1a centered 20×18 window approach, which hit two
  now-moot gotchas — the stride-20 build and the `wx=87` GB `WX−7` centering.)

## DrawBattleHUDs (Wave 2 Stage 1b — battle HUD boxes + HP bars)
- **Source:** `engine/battle/core.asm` (`DrawEnemyHUDAndHPBar`/`DrawPlayerHUDAndHPBar`)
  + `home/pokemon.asm:DrawHPBar`/`PrintLevel`; logic mirrored from the shipped port
  renderer `src/engine/menus/party_menu.asm`.
- **Translated:** `dos_port/src/engine/battle/battle_hud.asm`
- **Date:** 2026-06-28
- **H-flag:** Not involved.
- **Bug tags:** none.
- **Notes:** Draws enemy HUD (upper-left) + player HUD (lower-right) into the 40×25
  widescreen W_TILEMAP canvas: name (`PlaceString` from `wEnemyMonNick`/`wBattleMonNick`),
  ":L"+level (`print_num2`), 6-segment HP bar (`draw_hp_bar`, fill =
  `calc_hp_pixels` = curHP*48/maxHP, ≥1 sliver if alive), and the player's cur/max HP
  fraction (`print_num3`). Centered = GB coords + (10col, 3row). All writes are linear
  within a row → stride-agnostic, so they work on the 40-wide canvas (vs the
  stride-20-locked TextBoxBorder/multi-line PlaceString). HP-bar gauge tiles ($62-$71,
  ":L"=$6e) loaded by `LoadHpBarAndStatusTilePatterns` (added to `InitBattle`); tiles
  $79-$7F are byte-identical between the box and battle tile sets, so that load does NOT
  clobber the dialog box (load_font.asm's "OVERWRITES $79-$7E" comment is over-cautious —
  verified by comparing the .2bpp bytes). Reads the battle-mon structs; the DEBUG_BATTLE
  harness seeds them until `LoadBattleMonFromParty` lands (Stage 2/3). Deferred: HP-bar
  color (Phase 5 palette), status text, decorative HUD frame/pokeballs.

## FillMemory

- **Source:** `home/copy2.asm:137–155`
- **Translated:** `dos_port/src/util/fill_memory.asm`
- **pret cross-ref:** `FillMemory` (home/copy2.asm)
- **H-flag:** Not involved — pure store loop, no arithmetic.
- **Bug tags:** None. FillMemory is clean.

### Summary

Fills `BC` bytes at `HL` with byte `A`.

### SM83 Analysis

The original uses a double-loop to handle the full 16-bit count in two nested
8-bit decrements. This exists because on the SM83, 16-bit register
decrements (`dec bc`) do not set the Zero flag, so you can't branch on them.
The workaround:

1. If `B == 0`: use C as an 8-bit count directly (less than 256 bytes).
2. If `B != 0 && C == 0`: it's an exact multiple of 256; loop B times without
   incrementing B.
3. If `B != 0 && C != 0`: increment B first, then loop `B+1` times (each inner
   loop does 256 bytes, but the last iteration runs only C bytes before C wraps).

### x86 Translation Decision

`movzx ecx, bx` zero-extends the full 16-bit count into ECX, and `rep stosb`
handles any value 0–65535 correctly. The double-loop trick is not needed.

Edge cases verified:
| BX | SM83 path | x86 ECX | Correct? |
|----|-----------|---------|----------|
| 0x0000 | B=0, C=0, copies 256 bytes (!!) | 0 — no-op | x86 is correct; SM83 has a subtle bug here: if B=0 AND C=0, it enters `.eightbitcopyamount`, increments B to 1, then loops 256 times with dec C starting at 0, which wraps to 255 and counts 256 bytes. **This is a latent SM83 bug.** The game presumably never calls FillMemory with BC=0, but it's worth noting. |
| 0x00FF | B=0, C=255, 8-bit path | 255 — correct | ✓ |
| 0x0100 | B=1, C=0, exact 256 path | 256 — correct | ✓ |
| 0x0101 | B=1, C=1, B incremented to 2 | 257 — correct | ✓ |
| 0xFFFF | B=255, C=255, large count | 65535 — correct | ✓ |

**Edge case: BX=0x0000** — the SM83 FillMemory actually copies 256 bytes when
called with BC=0 (it falls through to the 8-bit path, increments B from 0 to 1,
then loops with C starting at 0 which wraps to 255 after first dec). This is
arguably a SM83 bug. The x86 translation (rep stosb with ECX=0) does nothing
instead. Since the game never calls FillMemory with BC=0 in practice
(confirmed by pret source review), this difference is acceptable. Tagged as:

```nasm
; BUG(cosmetic): BC=0 edge case — SM83 writes 256 bytes; x86 writes 0.
; pret ref: home/copy2.asm:FillMemory
; Game never passes BC=0 in practice. Fixed by /FIXALL for purity.
; %if BUG_FIX_LEVEL >= 2 ... handle BC=0 as no-op ... %endif
; (Currently: x86 behavior is the "fixed" behavior; the SM83 behavior is the bug.)
```

### Register Use

- `EDI`: scratch destination pointer (per register map convention for secondary pointer)
- `ECX`: loop counter — clobbered (callee must not rely on it)
- `ESI`: **preserved** — contains the GB address (HL) unchanged after return
- `EBX`: **preserved** — contains BC (count) unchanged after return
- `EAX`: **preserved** — AL = fill byte, unchanged after return

---

---

## LoadTextBoxTilePatterns

- **Source:** `home/load_font.asm:LoadTextBoxTilePatterns`
- **Translated:** `dos_port/src/gfx/load_font.asm`
- **Date:** 2026-06-13
- **H-flag:** Not involved.
- **Bug tags:** None.

### Summary

Copies the 2bpp box-drawing + extra-character tile data (`gfx/font/font_extra.png`,
32 tiles, chars $60–$7F) to vChars2+$60 at EBP offset $9600.

### Translation Notes

The GB original loads from ROM via FarCopyData/CopyVideoData into VRAM. In the
DOS port, the tile data is embedded as a committed NASM data file
(`assets/font_extra_2bpp.inc`, generated by `tools/gen_font_extra_inc.py`) and
copied directly to the emulated VRAM region with `rep movsd`. No bank-switching
needed. Destination = `GB_VCHARS2 + 0x60 * TILE_SIZE = $9600`.

---

## TextCommandProcessor / PrintText / PlaceString (extended)

- **Source:** `home/text.asm`, `home/window.asm:PrintText`
- **Translated:** `dos_port/src/text/text.asm`
- **Date:** 2026-06-13
- **H-flag:** Not involved.
- **Bug tags:** None.

### Summary

Full two-level text engine:

**Level 1 — TextCommandProcessor**: reads TX_* command bytes (TX_START, TX_BOX,
TX_MOVE, TX_LOW, TX_FAR, TX_END, plus stubs for TX_SCROLL/TX_PROMPT/TX_PAUSE/
sound/dots). TX_FAR skips 3 bytes (no ROM bank switching in flat model). Register
mapping: ESI = command stream (HL), EBX = tile cursor (BC).

**Level 2 — PlaceString extension**: all 20 dictionary control codes added
($00–$5F):

| Code | Name | Implementation |
|------|------|----------------|
| $00 | `<NULL>` | Silent terminator |
| $49 | `<PAGE>` | Skip (stub) |
| $4A | `<PKMN>` | Print "PK MN" ($E1,$E2) |
| $4B | `<_CONT>` | Scroll stub |
| $4C | `<SCROLL>` | Scroll stub |
| $51 | `<PARA>` | Paragraph stub |
| $52 | `<PLAYER>` | Loop-copy wPlayerName ($D158, TODO: verify) |
| $53 | `<RIVAL>` | Loop-copy wRivalName ($D34A, TODO: verify) |
| $54 | `#` | Print "POKé" |
| $55 | `<CONT>` | Scroll stub |
| $56 | `<……>` | Print "……" |
| $57 | `<DONE>` | Terminate via DONE_SENTINEL_WRAM |
| $58 | `<PROMPT>` | Stub |
| $59 | `<TARGET>` | Skip |
| $5A | `<USER>` | Skip |
| $5B | `<PC>` | Print "PC" |
| $5C | `<TM>` | Print "TM" |
| $5D | `<TRAINER>` | Print "TRAINER" |
| $5E | `<ROCKET>` | Print "ROCKET" |
| $5F | `<DEXEND>` | Print ".", terminate |

**PrintText**: draws MESSAGE_BOX border (interior 18×4 at tile coord (0,12)),
sets cursor to (1,14), tail-calls TextCommandProcessor.

### Key Phase 2 Stubs

- `manual_text_scroll`: returns immediately (no button wait). Full
  implementation needs joypad polling integrated into text flow.
- `scroll_text_up`: no-op. Full implementation needs tile-buffer row copy.
- TX_FAR: skips 3 bytes. Full implementation needs ROM data staged in EBP
  space so inline far-text can be read.
- `<PLAYER>`/`<RIVAL>` addresses (W_PLAYER_NAME=$D158, W_RIVAL_NAME=$D34A)
  must be verified against pokeyellow.sym when ROM build is available.

### CHAR_DONE ($57) Mechanism

`<DONE>` needs to terminate TextCommandProcessor from inside PlaceString.
The SM83 does this via a `ld de, .stop-1; ret` pattern that unwinds the call
chain. In x86, PlaceString returns to TextCommandProcessor's `.cmd_start`
handler with EDX pointing at a sentinel. A two-byte TX_END sequence at
`DONE_SENTINEL_WRAM` (= $C0F0) lets TextCommandProcessor exit cleanly:
- PlaceString sets EDX = DONE_SENTINEL_WRAM, returns
- `.cmd_start` does `mov esi, edx; inc esi` → ESI = $C0F1
- `.next_cmd` reads `[ebp + $C0F1]` = TX_END → done

`text_engine_init` writes the two TX_END bytes at startup.

### Inline Substitution Strings

Static strings (POKé, TM, PC, TRAINER, ROCKET, ……, PK/MN, ".") live in DS and
are written by `place_flat_str`, which reads via `[EAX]` (flat) rather than
`[EBP + EDX]` (GB-relative). Player/rival names use a dedicated EBP-relative
loop since they live in WRAM.

*Add new entries below as routines are translated.*

---

## PrepareTitleScreen / DisplayTitleScreen

- **Source:** `engine/movie/title.asm:PrepareTitleScreen`, `engine/movie/title_yellow.asm`
- **Translated:** `dos_port/src/movie/title.asm`
- **Date:** 2026-06-13
- **H-flag:** Not involved.
- **Bug tags:** None in the translated code; original glitches (Pikachu eye blink timer 0/$80/$90) preserved faithfully.

### Summary

Full title screen: graphics load, bounce animation, blink state machine, input idle loop.

### Key decisions

**Two-tilemap bounce trick:** Physical tilemap 0 ($9800) is used in two configurations,
selected by `hAutoBGTransferDest` hi byte ($98 = row 0, $9B = row 24). `do_bg_transfer`
in `frame.asm` copies the 20-wide `wTileMap` shadow into the 32-wide physical tilemap
with stride handling and 1 KB wrap. The bounce animation starts with `hSCY=64` (showing
row 8 of the physical tilemap downward), bouncing to `hSCY=0` to reveal the full logo.

**Pikachu appearance:** After the bounce settles, `LoadScreenTilesFromBuffer1` restores
the logo+pikachu map and `DelayFrames(36)` commits it via auto-BG transfer.

**Asset loading:** All title graphics come from `.inc` files generated by
`tools/gen_title_gfx_inc.py` (PNG→2bpp). `FarCopyData` is not used for program-image
sources; direct `rep movsb` is used instead (CopyData/FarCopyData add EBP which would
corrupt flat pointers).

**VRAM layout (signed tile mode, LCDC_DEFAULT=$E3, bit4=0, base $9000):**

| Address   | Content                        | Tile indices used    |
|-----------|--------------------------------|----------------------|
| $8800     | Pikachu BG tiles (64 tiles)    | $80–$BF (signed −)   |
| $8E00     | Nintendo copyright (5 tiles)   | $E0–$E4 (signed −)   |
| $8E50     | GameFreak inc. logo (9 tiles)  | $E5–$ED (signed −)   |
| $8EE0     | Nine tile (1 tile)             | $EE (signed −)       |
| $8F00     | Pikachu OBJ sprites (12 tiles) | $F0–$FB (signed −)   |
| $8FD0     | Logo corner tiles (3 tiles)    | $FD–$FF (signed −)   |
| $9000     | Pokemon logo (128 tiles)       | $00–$7F (signed +)   |

**Phase stubs:** Audio (PlaySound, StopAllMusic, PCM), CGB palette (RunPaletteCommand,
UpdateCGBPal_OBP0), SRAM (FillSpriteBuffer0WithAA), OAM renderer (sprite eye blink
writes are correct but invisible until Phase 1 OAM pass), MainMenu (→ EnterMap Phase 2).

---

## Overworld Engine (Phase 2)

- **Sources:** `home/overworld.asm` — ResetMapVariables, CopyMapViewToVRAM, DrawTileBlock,
  LoadCurrentMapView, LoadTilesetTilePatternData, LoadTileBlockMap, LoadScreenRelatedData,
  LoadMapData; Phase 2 scaffold: EnterMap/SetupPalletTown/OverworldLoop
- **Translated:** `dos_port/src/engine/overworld/overworld.asm`
- **Date:** 2026-06-13
- **H-flag:** Not involved — all pure data movement.
- **Bug tags:** None.

### Key decisions

**Asset layout in ROM window ($4000–$4EFF):** The original reads tileset GFX,
blockset, and map data from ROM banks via FarCopyData. In the flat model, Phase 2
embeds these as NASM `.rodata` and copies them to `[EBP + $4000]` at map load.
`wTilesetGfxPtr = $4000`, `wTilesetBlocksPtr = $4600`, `wCurMapDataPtr = $4E00`.
Faithful routines index off these 16-bit pointers unchanged.

**Tileset addressing:** `vTileset = $9000` (sym-confirmed). LCDC bit 4 = 0
(signed mode). Tile IDs 0–93 map to $9000 + id×16. Font at $8800 coexists
(IDs $80–$FF, negative signed). `LoadTilesetTilePatternData` copies $600 bytes;
the trimmed .2bpp (1504 B) uses the remaining 32 bytes as DPMI-zeroed blanks.

**DrawTileBlock:** SM83 `swap a` / mask to compute `blockID × 16` replaced with
`shl eax, 4` — semantically identical, cleaner.

**Connection strips:** Phase 2 sets all connected maps to $FF; strip-load code
is translated but skipped. TODOs in place for player movement phase.

**WRAM address corrections (2026-06-13):** gb_memmap.inc updated with all
sym-verified addresses. Key corrections: `wPlayerName` ($D158→$D157),
`wRivalName` ($D34A→$D349), `wTileMapBackup2` ($D300→$CD81),
`wTitleScreenScene` ($D200→$CD3D), and ~8 audio/status variables relocated
from placeholder $D20x range to their true WRAM0 addresses. Title screen
unaffected (zeroed wrong WRAM before; correct zeroing now, same visual result).

---

## Player movement — `src/engine/overworld/overworld.asm` (2026-06-14)

Translated the movement-relevant subset of `home/overworld.asm:OverworldLoop` /
`OverworldLoopLessDelay` plus the helpers from
`engine/overworld/advance_player_sprite.asm`, `home/vcopy.asm:RedrawRowOrColumn`,
and the collision path (`CollisionCheckOnLand` → `_GetTileAndCoordsInFrontOfPlayer`
→ `_IsTilePassable`).

### Routines

- **OverworldLoop / OverworldLoopLessDelay** — joypad state machine. Two
  `DelayFrame`s per iteration (matches the original ~16-frame/step cadence). Idle:
  sample `hJoyHeld`, set the X/Y step vector + facing + `wPlayerDirection`,
  collision-check, and arm `wWalkCounter = 8`. Mid-step: `AdvancePlayerSprite`.
- **AdvancePlayerSprite** (`_AdvancePlayerSprite`) — on the first step frame
  (counter == 7) slides `wMapViewVRAMPointer` by 2 tiles, crosses a block via
  `MoveTileBlockMapPointer{East,West,South,North}`, rebuilds the view with
  `LoadCurrentMapView`, and schedules the exposed edge. Every frame scrolls
  `hSCX`/`hSCY` by ±2 px.
- **RedrawRowOrColumn** + **Schedule{North,South}RowRedraw** /
  **Schedule{East,West}ColumnRedraw** + helpers — the sliding-window VRAM update.
  `RedrawRowOrColumn` is exported and called from `frame.asm:DelayFrame` (the GB
  VBlank-order slot), so only the 2 freshly exposed rows/cols are rewritten per
  step while `hSCX`/`hSCY` grow unbounded (renderer wraps the 32×32 VRAM at 256 px).
- **CollisionCheckOnLand / GetTileInFrontOfPlayer / IsTilePassable** — land
  passability only. `GetTileInFrontOfPlayer` reads `wTileMap` at the fixed
  per-facing screen coords; `IsTilePassable` scans the `$FF`-terminated list at
  `wTilesetCollisionPtr`.

### Key decisions

- **Auto-BG transfer off in the overworld:** `H_AUTO_BG_TRANSFER_EN = 0` in
  `SetupPalletTown`. Otherwise `do_bg_transfer` re-blits `wTileMap` to `$9800`
  every frame and fights `RedrawRowOrColumn` (matches the original, which disables
  auto-transfer while walking).
- **Collision data embedded:** `gen_overworld_assets.py` now parses
  `data/tilesets/collision_tile_ids.asm` for `Overworld_Coll` →
  `assets/overworld_coll.inc`, copied to ROM window `OW_COLL_GBADDR` ($4F00);
  `wTilesetCollisionPtr` points there.
- **Player marker placeholder:** `draw_player_marker` (ppu.asm) paints a 16×16
  two-tone box at the fixed player screen center, gated by `g_player_marker_on`
  (set in the overworld, off on the title). Stands in until the OAM sprite
  renderer (Phase 1 open item) lands.
- **32-bit gotcha:** `dil`/`sil` byte registers do not exist outside long mode;
  low-byte-of-EDI arithmetic uses `mov eax, edi` / `and eax, 0xFF` instead.

### Phase 2 omissions vs. pret

OAM sprite-shift loop, `IsSpinning`, ledges, tile-pair collisions, sprite
collisions, warps, `CheckMapConnections`, NPCs, battles, and scripted movement.

### Verification

Built `SKIP_TITLE=1`; verified in DOSBox-X and user-confirmed: walking in all
four directions scrolls Pallet Town smoothly with correct tiles at the newly
exposed edges, trees/buildings block movement, and the placeholder marker tracks
the screen center.

---

## OAM sprite renderer + player sprite — `src/ppu/ppu.asm`, `src/engine/overworld/overworld.asm` (2026-06-14)

HAL renderer (not a pret translation) plus an overworld scaffold to drive it.

### Routines

- **render_sprites** (ppu.asm) — DMG OBJ emulation in 8×8 mode. Reads the 40 OAM
  entries at `$FE00` (Y, X, tile, attr), blits each 8×8 tile from the OBJ tile
  area (`$8000`, unsigned), honoring X/Y flip, OBP0/OBP1 (color 0 = transparent),
  and the BG-priority bit (attr bit 7 → draw only over back-buffer shade 0, which
  equals BG color 0 under the standard `BGP=$E4`). Called from
  `frame.asm:DelayFrame` right after `render_bg`.
- **LoadPlayerSpriteGraphics** (overworld.asm, scaffold) — copies the 24-tile Red
  sprite (`gfx/sprites/red.2bpp`, embedded via `gen_overworld_assets.py` →
  `assets/player_sprite.inc`) to `$8000` and zeroes OAM. Called from `LoadMapData`
  where pret calls the real `LoadPlayerSpriteGraphics`.
- **UpdatePlayerOAM** (overworld.asm, scaffold) — writes the player's four OAM
  entries each frame for the current facing, composing the 16×16 standing pose
  from tiles 0–11 via `player_oam_table` (derived from `data/sprites/facings.asm`).
  Player is camera-locked at screen pixel (64,64); the BG scrolls under it.

### Key decisions / gotchas

- **OAM byte order** is Y, X, tile, attr (verified against `PrepareOAMData`'s read
  sequence — the "attributes, tile index" comment in `facings.asm` is mislabeled).
- DMG sprite priority is simplified to **reverse-OAM-order draw** (lower index on
  top) — honors the index tiebreak but not the smaller-X-wins rule; no
  10-per-scanline limit; 8×16 OBJ size unhandled (overworld/menus use 8×8).
- The earlier `draw_player_marker` placeholder is now disabled
  (`g_player_marker_on = 0`) but kept as a gated fallback.

### Verification

`SKIP_TITLE=1`: the Red player sprite renders camera-locked at screen center over
Pallet Town and faces the direction of movement.

---

## Sprite engine — `src/gfx/sprite_oam.asm`, `src/engine/overworld/movement.asm` (2026-06-15)

Replaced the `UpdatePlayerOAM` / `player_oam_table` scaffold with a faithful
translation of the Yellow sprite engine, so the player renders through the real
shadow-OAM pipeline driven by `wSpriteStateData1/2` (slots 0–15). NPC slots are
inert (picture ID 0) but the loop, priority, and tile logic are the real engine,
so NPCs render the moment a map fills their slots.

### Routines

- **PrepareOAMData** (sprite_oam.asm) — faithful translation of
  `engine/gfx/sprite_oam.asm:PrepareOAMData` (Yellow). Iterates the 16 sprite
  slots; for each visible sprite (picture ID ≠ 0, image index ≠ `$ff`) it indexes
  `SpriteFacingAndAnimationTable` by `imageIndex & $f`, reads `Y/X` from the slot,
  and writes the pose's OAM entries into `wShadowOAM` (`$C300`). Handles the
  under-grass BG-priority bit, OBP0/OBP1 → CGB high-palette mapping, the `$80+`
  tile → Pikachu-VRAM-offset path, the OAM-overflow guard, and clearing unused
  entries to `Y=$a0`. Plus `GetSpriteScreenXY` and `Func_4a7b` (VRAM base tile).
  The full `SpriteFacingAndAnimationTable` + facing data is embedded (a `dd` table
  of absolute label addresses, indexed `*4`, vs pret's `dw` of GB addresses).
- **UpdateSprites / _UpdateSprites / UpdatePlayerSprite** (movement.asm) — faithful
  translation of the player path of `home/update_sprites.asm` +
  `engine/overworld/sprite_collisions.asm:_UpdateSprites` +
  `engine/overworld/movement.asm:UpdatePlayerSprite` (with `Func_4e32`,
  `Func_5274`). Sets the player's facing from `wPlayerMovingDirection`, advances
  the walk-animation counters (intra-anim → anim-frame every 4 ticks), recomputes
  the image index (`facing + animFrame`), and sets grass priority. Called once per
  `OverworldLoop` iteration.
- **frame.asm:update_oam** — runs `PrepareOAMData` then DMA-copies `wShadowOAM` →
  OAM (`$FE00`) each `DelayFrame`, gated on `wUpdateSpritesEnabled` (mirrors the GB
  VBlank `PrepareOAMData` + `hDMARoutine`; gating keeps the title screen's own
  shadow-OAM writes from being force-copied).
- **LoadPlayerSpriteGraphics** (overworld.asm) — now loads Red's standing tiles
  (0–11) to `$8000` (OBJ `$00–$0B`) and walking tiles (12–23) to `$8800`
  (OBJ `$80–$8B`), the layout the engine indexes; walking tiles time-share vChars1
  with the text font exactly as on the GB.

### Key decisions / gotchas

- **Stub boundaries:** `DetectCollisionBetweenSprites` (no NPCs to collide) and
  `UpdateNonPlayerSprite` (NPC engine) are no-ops; the spinning-tile path is inert
  (`wMovementFlags` stays 0). All marked `; TODO`.
- **32-bit register trap:** `sil`/`dil` are not byte-addressable without REX, so
  slot-offset byte stores go through `al` (mov eax, esi / mov [..], al).
- **Player screen position** is the original's fixed `YPixels=$3c`, `XPixels=$40`
  (slightly above geometric center), per `home/reset_player_sprite.asm`.

### Verification

`SKIP_TITLE=1 DEBUG_DUMP=1` with a one-shot `UpdateSprites`+`PrepareOAMData` before
the dump: `wSpritePlayerStateData1` = pictureID 1 / imageIndex 0 / Y `$3c` / X
`$40` / facing 0; `wSpriteStateData2` imageBaseOffset 1; shadow OAM slot 0 holds
the four StandingDown entries `($4c,$48,$00) ($4c,$50,$01) ($54,$48,$02)
($54,$50,$03)` (attrs masked to 0, not in grass) and entry 4 = `$a0` (hidden);
standing tiles present at `$8000`, distinct walking tiles at `$8800`. Default and
`SKIP_TITLE=1` builds link clean.

---

## BG scanline rewrite + DrawTileBlock clamp — `src/ppu/ppu.asm`, `src/engine/overworld/overworld.asm` (2026-06-15)

- **Sources:** HAL renderer (`render_bg`, not a pret translation); `DrawTileBlock`
  (`home/overworld.asm`).
- **H-flag:** Not involved.
- **Bug tags:** None (fixes to our own port code, not pret bugs).

### render_bg — pixel-smooth scrolling

Replaced the tile-blitter (each tile written to a fixed `tile_col*8` / `tile_row*8`
slot) with a **scanline renderer**. Per output scanline: compute
`world_y = (y + SCY) & 0xFF`, derive the tilemap row + `(world_y & 7)*2` source-row
offset, decode 41 tiles (40 visible + 1 for the sub-tile shift) into a virtual line
buffer (`bg_scanline_buf`), then `rep movsb` 320 px starting at `bg_fine_x = SCX & 7`
into the back buffer.

- **Why:** the blitter applied neither `SCX & 7` (horizontal scroll only moved on
  8-px boundaries) nor a per-scanline tilemap-row fetch (its single-tile 8-row
  decode overflowed into the next *VRAM* tile, not the next *tilemap* row). Both
  axes are now pixel-smooth.
- **Cost:** ~200×41 tile-row decodes/frame vs. the blitter's 1000 tile decodes —
  more work, traded for correctness. (Note: this runs counter to the perf goal of
  the open "VGA-native renderer" refactor in TODO.md Phase 2; revisit there.)
- `stosb`/`rep movsb` to/from the flat `.bss` line buffer mirror `decode_win_row` /
  `render_window` (ES base == DS base after `setup_flat_access`).

### DrawTileBlock — out-of-range block clamp (TEMPORARY)

Added a clamp: if `wTilesetBlocksPtr + blockID*16` lands past the embedded blockset
(`OW_BLOCKS_GBADDR + OVERWORLD_BLOCKS_SIZE`), substitute block 0.

- **Why:** the extended 40×25-tile viewport draws a larger area than the original
  20×18, so the camera can reach into uninitialized `wOverworldMap` padding and
  hand `DrawTileBlock` a block ID past the 128-block embedded blockset; the read
  then walks off the blockset and paints garbage. No GB equivalent (there the
  blockset fills a bank and map data is bounded by the loader).
- **Temporary:** this is a stopgap. The plan is to **extend the map data** so those
  regions hold real blocks (no blank area from the extended draw), after which the
  clamp is dead code and should be deleted. Tracked in TODO.md (Phase 2) and noted
  in CLAUDE.md + a code comment at the clamp site.

### render_window — bottom-of-screen garbage fix (2026-06-15)

Symptom: red/green vertical lines at the bottom-right of the overworld (pixel
values >3, indexing the leftover `test_palette` ramps). Two compounding causes:

- `LCDC_DEFAULT_VAL = 0xE3` enables the window (bit 5) — the real Pokémon value.
  The game parks it at `WY=144` to hide it on the 144-px GB screen, but our
  viewport is 200 px, so rows 144–199 rendered the parked (uninitialized) window.
  **Fix:** bound the window scanline loop at `SCREEN_H` (144), not `RENDER_H`
  (200), preserving the GB park semantics. (A textbox for the full 200-px viewport
  is future window-layer work.)
- The `wx_adj ≥ 0` copy path lacked a length clamp (the left-clip path has one) and
  copied up to `RENDER_W` (320) bytes from the 256-byte `row_buf`, spilling into
  adjacent BSS. **Fix:** clamp the copy to 256.

Verified 2026-06-15 in DOSBox-X: initial render clean; single-step scroll in all
four directions clean. See docs/session_handoff.md for the remaining open items
(render speed, map connections, facing-down collision ±1-vs-±2).

### render_bg — decoded-tile cache optimization (2026-06-15)

`render_bg` previously bit-decoded 41 tiles × 200 scanlines (2bpp→8bpp via a
`shl`/`rcl` loop) **every frame** — ~65k px/frame of per-pixel decode, the
overworld's hot path. Replaced with a **pre-decoded tile cache**:

- `tile_cache` (BSS, 384 tiles × 64 B = 24 KB) holds the whole BG/window
  tile-data region ($8000-$97FF) decoded to 8bpp, BGP shade baked in.
- `rebuild_tile_cache` decodes all 384 tiles in one linear pass and records the
  BGP used. `render_bg` calls it only when `g_tilecache_dirty` is set **or**
  `IO_BGP` changed since the last build — so a static, scrolling map reuses the
  cache and does ~zero decode work. The per-tile inner loop is now two 4-byte
  `mov`-pair copies (`tile_cache → bg_scanline_buf`); the `SCX & 7` scanline
  buffer + 320 px copy for smooth horizontal scroll is unchanged.
- `g_tilecache_dirty` lives in `.data` initialized to 1 (first frame builds the
  cache) and is set by every VRAM tile-data writer: `LoadFontTilePatterns`,
  `LoadTextBoxTilePatterns`, `LoadYellowTitleScreenGFX`,
  `LoadTilesetTilePatternData`, `LoadPlayerSpriteGraphics`,
  `SetupPalletTownNPCs`, `ClearVram`. BGP/palette changes are auto-detected.

Faithful to behavior (cache is a pure decode of the same VRAM + BGP the
per-pixel path read). Follows docs/386_optimization_strategy.md (cache decode
out of the hot loop, 32-bit moves, scaled-index addressing). Verified
pixel-identical to the pre-optimization Pallet Town render (SKIP_TITLE
screenshot, 2026-06-15). **Invariant for future work:** any new routine that
writes VRAM tile data must set `g_tilecache_dirty`.

### Renderer — raw color indices + DAC palette (Tier 2 step 1, 2026-06-15)

The PPU renderer no longer bakes BGP/OBP shades into framebuffer pixels. It writes
**raw GB color indices** and the VGA DAC maps them: BG/window color 0-3 → DAC 0-3,
sprite OBP0 → 4+color (DAC 4-7), OBP1 → 8+color (DAC 8-11). New `commit_palette`
(boot/video.asm) programs DAC 0-11 from BGP/OBP0/OBP1 (consecutive regs
$FF47-49) using `dmg_palette`, skipping when unchanged; called per frame in
`DelayFrame` after `commit_shadow_regs`. Dropped `bgp_tab`/`obp_tab`/
`g_tilecache_bgp` and the BGP-driven tile-cache rebuild — `tile_cache` now holds
raw color and depends only on `g_tilecache_dirty`. A palette fade/flash is now a
DAC reprogram, not a tile re-decode (cheaper + more faithful). Byte-identical
output at the normal BGP/OBP (identity) mapping; verified via `./test_render.sh`
(BG + player/NPC sprites correct). **Invariant:** code that writes the back buffer
directly must use the raw-index convention, not shade values. Part of the Tier 2
plan (docs/render_tier2_plan.md); progress tracked in docs/render_opt_handoff.md.

### render_bg — direct-to-backbuffer assembly (Tier 2 step 2, 2026-06-15)

Removed the redundant per-scanline copy. `render_bg` previously decoded 41 tiles
into `bg_scanline_buf` then `rep movsb`-copied 320 px into the back buffer at the
`SCX&7` offset; now it assembles each scanline **directly into the back buffer**
in one pass (~192 KB → ~128 KB frame traffic). The fine offset is handled by
writing each tile at `dest_pos = tile_col*8 - fine_x` with per-tile left/right
clipping (`bg_row_ptr` = row start): tile 0 left-clips `fine_x` px, the last tile
right-clips to remaining room; `fine_x=0` → 40 full tiles, `fine_x>0` → tiles 0
and 40 partial = exactly 320 px. Kept the back buffer + `present` (window/sprite
compositing stays in fast RAM; avoids slow VGA reads for sprite BG-priority).
Removed BSS `bg_scanline_buf` and dead `bg_fine_y2`; added `bg_row_ptr`. Verified
pixel-correct (sub-tile fine offset intact) via `./test_render.sh`.

### render_bg — offscreen surface mirror + viewport blit (Tier 2 step 3, 2026-06-15)

`render_bg` no longer resolves tiles per scanline. A `bg_surface` (256×256 chunky
raw-color, BSS) mirrors the *decoded* BG tilemap torus; each frame the renderer
(1) diffs the live VRAM tilemap against `bg_tilemap_shadow` and re-decodes only
changed tiles into the surface (`sync_surface_diff` → `surf_decode_tile`), with a
full `rebuild_surface_full` on `g_tilecache_dirty` or a tilemap-base switch, then
(2) blits a 320×200 window at `(SCX,SCY)` with 256-px torus wrap (1–2 `rep movsb`
per row). Eliminates the per-frame per-tile addressing and the 40-into-32 fold;
sampling matches the old renderer (BG pixel (x,y) = surface ((SCX+x)&255,
(SCY+y)&255)). **Decoupled** — we mirror by VRAM tilemap *address*, so the
faithful sliding-window scroll + `RedrawRowOrColumn` edge redraw need no changes
(their tilemap writes show up in the diff). `tile_cache` kept as the decoded
tile-data source the surface copies from. New BSS: `bg_surface` (64 KB),
`bg_tilemap_shadow` (1 KB), `surf_last_base`; removed the per-scanline scratch.
Verified: clean-boot render matches known-good Pallet Town; user-driven scrolling
renders clean aligned tiles with no stale strips/seams (only the pre-existing
missing-connector junk remains). Completes the Tier 2 render-opt quest
(docs/render_opt_handoff.md).

### LoadTileBlockMap connection strips + Load{NS,EW}ConnectionsTileMap (2026-06-15)

Un-stubbed the map-connection logic in `LoadTileBlockMap` and translated
`LoadNorthSouthConnectionsTileMap` / `LoadEastWestConnectionsTileMap` (pret:
home/overworld.asm). For each connected direction (≠ $FF) the strip header
(src/dest/length/connected-map-width) is loaded and the connected map's edge is
copied into the wOverworldMap border: N/S copies MAP_BORDER rows × strip-width,
E/W copies strip-length rows × MAP_BORDER cols; src advances by the connected map
width, dest by the wOverworldMap stride (wCurMapWidth + 2·MAP_BORDER).
`SwitchToMapRomBank` is a no-op (flat model); 16-bit pointer math becomes plain
32-bit `add` on the GB-offset registers. The hNorthSouthConnectionStripWidth /
connected-map-width HRAM reuse H_MAP_STRIDE/H_MAP_WIDTH (faithful unions).

Scaffold wiring (SetupPalletTown, NOT a faithful LoadMapHeader): Pallet Town
connects north→Route1, south→Route21. Route1.blk (10×18) / Route21.blk (10×45)
are embedded (tools/gen_overworld_assets.py → assets/route1_blk.inc,
route21_blk.inc) and copied to OW_ROUTE1_BLK_GBADDR ($5000) /
OW_ROUTE21_BLK_GBADDR ($5200). The connection-struct field values (strip
src/dest, length, width, Y/X-align, view-ptr) were precomputed from the pret
`connection` macro (macros/scripts/maps.asm) for offset-0 connections and set as
constants. Connection-struct field offsets added to gb_memmap.inc (CONN_*).

Dump-verified (2026-06-15): wOverworldMap north border rows 0-2 cols 3-12 ==
Route 1 rows 15-17; south border rows 12-14 cols 3-12 == Route 21 rows 0-2;
connection structs at $D370/$D37B match the computed bytes. Boot render
unchanged (strips are off-screen until you walk to the edge). **Scope:** this is
strip *loading* only — the map-*transition* trigger (crossing into the connected
map) is a separate follow-on; the DrawTileBlock clamp stays (E/W + past-map-end).

## Native-width BG renderer (Stage A)

- **Sources:** `dos_port/src/ppu/ppu.asm`, `dos_port/src/engine/overworld/overworld.asm`
- **Date:** 2026-06-16
- **H-flag:** Not involved.
- **Bug tags:** None.

### Summary

Rewrote `render_bg` to naturally decode `wSurroundingTiles` (44x32) into a native 352x256 surface, eliminating the 256px GB VRAM torus wrap and duplicated columns.
Smooth fine-scroll is now applied natively via offset to the viewport blit using `+ signed(H_SCX/H_SCY)`.
Removed dead VRAM-ring scroll routines (`CopyMapViewToVRAM`, `FillExtraVRAMRows`, `RedrawRowOrColumn`) and simplified `AdvancePlayerSprite`.

*Add new entries below as routines are translated.*

---

## Movement delay + door-exit logic fixes — `src/engine/overworld/overworld.asm` (2026-06-20)

- **Sources:** `home/overworld.asm` (OverworldLoop / WarpFound2.done),
  `engine/overworld/movement.asm` (UpdatePlayerSprite/.handleDirectionButtonPress),
  `engine/overworld/auto_movement.asm` (PlayerStepOutFromDoor)
- **Date:** 2026-06-20
- **H-flag:** Not involved.
- **Bug tags:** None (port correctness fixes, not pret bugs).

### Bug 1 — Movement delay (`.startWalk` → `jmp OverworldLoop`)

**Symptom:** holding any direction felt "discrete" — each step had a visible pause
before the first pixel moved, making smooth scrolling feel sluggish.

**Root cause:** after setting `wWalkCounter = 8`, the port jumped back to
`OverworldLoop`, passing through another `UpdateSprites` + 2×`DelayFrame` (2 extra
frames) before reaching the first `AdvancePlayerSprite`. In the original, `.noCollision`
falls straight to `.moveAhead2` (AdvancePlayerSprite) in the same iteration:
`ld a, 8 / ld [wWalkCounter], a / callfar Func_fcc08 / jr .moveAhead2`.

**Fix:** `.startWalk` now jumps to `.moveAhead` (the port's equivalent of `.moveAhead2`)
instead of `OverworldLoop`. First pixel movement happens in the same loop iteration as
the step is armed, matching the original's 16-frame/step cadence exactly. This also
fixes the door-exit step delay (same code path).

### Bug 2 — Door-exit iteration skipped (`jmp OverworldLoop.lessDelay`)

**Symptom:** after a warp arrival the player stood still for an extra loop iteration
(2 frames) before the auto-walk fired.

**Root cause:** `.warpTransition` jumped to `OverworldLoop.lessDelay`, skipping
`RunNPCMovementScript` on the first post-warp iteration. In the original,
`WarpFound2.done` calls `jp EnterMap` which falls into `OverworldLoop` (top), so
`RunNPCMovementScript` → `PlayerStepOutFromDoor` fires on the very first frame.

**Fix:** `.warpTransition` now jumps to `OverworldLoop` (top). Map state is fully
loaded by `LoadWarpDestination` before the jump, so this is safe.

### Bug 3 — Scripted movement didn't bypass 180° turn-delay

**Root cause:** the port's `.handleDirection` applied the turn-delay check even during
scripted movement (door auto-walk). The original has an explicit guard:
`bit BIT_SCRIPTED_MOVEMENT_STATE / jr nz, .noDirectionChange`. The previous port
worked around this by priming `wPlayerLastStopDirection = PLAYER_DIR_DOWN` in
`PlayerStepOutFromDoor` — fragile and wrong.

**Fix:** added `test BIT_SCRIPTED_MOVEMENT_STATE / jnz .walkStart` at the top of
`.handleDirection`, before the turn-delay check. Removed the `wPlayerLastStopDirection`
prime from `PlayerStepOutFromDoor`.

### `LoadCurrentMapView` in `CollisionCheckOnLand` — why it's required

`LoadCurrentMapView` rebuilds `wSurroundingTiles` from the block map AND copies a
sub-block-offset viewport into `wTileMap` based on `W_Y_BLOCK_COORD`/`W_X_BLOCK_COORD`.
`AdvancePlayerSprite` only calls it on block-boundary crossings. Between crossings
YBC/XBC can advance 0→1 without triggering a rebuild, leaving `wTileMap` at the
previous sub-block viewport offset. `GetTileInFrontOfPlayer` then reads the wrong tile.

Symptom: walking toward a 2×2 cluster of impassable tiles (route 1 bushes, building
outer walls, ledges) sporadically passes through — at the half-block sub-step the
tile read lands on the adjacent passable tile instead of the correct one. The call is
retained in `CollisionCheckOnLand`. A future optimisation could split out just the
viewport-copy step (lines 1114–1135) since `wSurroundingTiles` is already current.

### Also in this commit

- **`gb_memmap.inc`:** added `BIT_STANDING_ON_DOOR`, `BIT_EXITING_DOOR`,
  `BIT_STANDING_ON_WARP`, `BIT_DISABLE_JOYPAD`, `BIT_SCRIPTED_MOVEMENT_STATE`
  constants; `W_JOY_IGNORE`, `W_SIMULATED_JOYPAD_STATES_END`,
  `W_SIMULATED_JOYPAD_STATES_INDEX`, `W_IGNORE_INPUT_COUNTER` addresses.
- **`assets/map_headers.inc`:** removed `IF DEF(_DEBUG)` debug warps from
  `REDS_HOUSE_2F` (those 4 extra warp entries only exist in a debug build of the
  original; the port is not a debug build).

---

## Math (Multiply / Divide)

- **Source:** `home/math.asm`
- **Translated:** `dos_port/home/math.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

Implemented as wrapper skeletons (`Multiply`, `Divide`) that call external implementations (`_Multiply`, `_Divide`). Preserves SM83 caller state around the external calls via stack pushes.

---

## CountSetBits

- **Source:** `home/count_set_bits.asm`
- **Translated:** `dos_port/home/count_set_bits.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

Loop structure preserved, counts bits in a string of bytes. Shift-and-carry approach retained using `shr` and `adc`.

---

## StringCmp

- **Source:** `home/compare.asm`
- **Translated:** `dos_port/home/compare.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

Uses standard `cmp` loop comparing bytes at ESI and EDX (representing HL and DE).

---

## Random

- **Source:** `home/random.asm`
- **Translated:** `dos_port/home/random.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

Wrapper skeleton. Calls `Random_` and then fetches `hRandomAdd` to return random value in AL. Preserves caller state.

---

## Copy Routines (FarCopyData / CopyData)

- **Source:** `home/copy.asm`
- **Translated:** `dos_port/home/copy.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

- **CopyData** implements a 32-bit block move optimization. Instead of an 8-bit copy loop, it processes the copy in 4-byte (`DWORD`) chunks where possible via a `cmp ecx, 4` sub-loop, dropping to 1-byte copies for the remainder. This significantly reduces memory bus utilization per the 386 optimization strategy.
- Video copy routines (`CopyVideoDataAlternate`, `CopyVideoDataDoubleAlternate`) check LCDC bit 7 to selectively branch to `CopyVideoData` or `CopyVideoDataDouble` with register preservation and bit manipulation intact.
- Far routines (`FarCopyData`) wrap bankswitching with pushes.

---

## Array Operations (SkipFixedLengthTextEntries / AddNTimes)

- **Source:** `home/array.asm`
- **Translated:** `dos_port/home/array.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

**Excellent strength reduction.** The original SM83 looped AL times doing `add HL, BC`. The x86 translation replaces the iterative loops with a single `imul ecx, eax` followed by `add esi, ecx`, converting an O(N) loop into an O(1) mathematical operation. This perfectly aligns with the performance goals of the 386 port strategy.

---

## Multiply / Divide Logic (_Multiply / _Divide)

- **Source:** `main.asm` (math routines)
- **Translated:** `dos_port/src/util/multiply_divide.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

- `_Multiply` discards the original 8-bit iterative addition loop and leverages the native 386 hardware `mul` instruction. It reconstructs the 24-bit multiplicand into a 32-bit register (`EAX`), multiplies by the 8-bit multiplier (`ECX`), and cleanly writes the 32-bit product back to `H_PRODUCT` in big-endian format. Perfect O(1) cycle implementation.
- `_Divide` maintains faithful step-by-step subtraction logic to accurately preserve Game Boy memory side-effects and byte alignments for `hDividend` and `hDivideBuffer`, but caches the operations in 32-bit registers (`EAX`, `EDI`, `EDX`) to avoid heavy memory access penalties.

---

## BCD Math (AddBCD / SubBCD / DivideBCD)

- **Source:** `main.asm` (BCD routines)
- **Translated:** `dos_port/src/util/bcd.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

**Brilliant hardware optimization:** The translated `AddBCD` and `SubBCD` completely replace the Game Boy's manual Binary-Coded Decimal correction logic by utilizing the native x86 `DAA` (Decimal Adjust AL after Addition) and `DAS` (Decimal Adjust AL after Subtraction) instructions. This pairs natively with `adc` and `sbc` for massive cycle savings while remaining 100% behaviorally accurate. `DivideBCD` also uses an optimized shift-and-subtract approach.

---

## Random Number Generator (Random_)

- **Source:** `main.asm` (random logic)
- **Translated:** `dos_port/src/util/random.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

Accurately preserves the SM83 carry flag chain. The Game Boy original uses `adc b` and later `sbc b` without clearing flags, meaning it relies on the residual carry from the caller and previous instructions. The x86 translation perfectly mirrors this by keeping the exact sequence using `adc al, bl` and `sbb al, bl`.

---

*Add new entries below as routines are translated.*

## Text Box Coordinates (GetAddressOfScreenCoords)

- **Source:** `engine/menus/text_box.asm`
- **Translated:** `dos_port/engine/menus/text_box.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

**Brilliant hardware optimization:** The Game Boy's `GetAddressOfScreenCoords` typically requires iterative looping to calculate the tilemap offset (`row * 20 + col`). In the x86 translation, this loop has been entirely replaced by an O(1) calculation using the 32-bit hardware `imul eax, 20` instruction. This dramatically reduces cycles by converting an O(N) iterative addition loop into a single optimized instruction perfectly aligned with the 386 optimization strategy.

---

## PC / Item Swap Menus (RemoveItemByID / HandleItemListSwapping)

- **Source:** `engine/menus/pc.asm`, `engine/menus/swap_items.asm`
- **Translated:** `dos_port/engine/menus/pc.asm`, `dos_port/engine/menus/swap_items.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

Provides fully unwired skeletons for inventory management, abstracting iterative array scanning and item recombination. `HandleItemListSwapping` makes heavy use of 32-bit offset additions (e.g. `movzx ecx, al; add esi, ecx`) to calculate base pointers for the list cursor offset rather than the native 8-bit pointer advancement strategies, drastically reducing pressure on pointer manipulation loops.

---

## Save System (SaveMainData / CalcCheckSum)

- **Source:** `engine/menus/save.asm`
- **Translated:** `dos_port/engine/menus/save.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

Maintains faithful SRAM boundaries and checksum calculation. `CalcCheckSum` leverages a fast 32-bit `movzx ecx, cx` loop register countdown to rapidly sum the SRAM state. 

---

## Text Engine Base (text.asm)

- **Source:** `text.asm`
- **Translated:** `dos_port/text.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

Ported as a section-based include skeleton for later text data insertion.

---

*Add new entries below as routines are translated.*

## Item Inventory (AddItemToInventory_ / RemoveItemFromInventory_)

- **Source:** `engine/items/inventory.asm`
- **Translated:** `dos_port/src/items/inventory.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

Replaces the Game Boy's iterative 8-bit pointer advancement for item slot offsets with native 32-bit math. In `AddItemToInventory_`, the target memory address for the new item slot is computed instantly via `lea edx, [esi + 1 + ecx]`, completely eliminating loop-based pointer math perfectly aligned with the 386 strategy.

---

## Get Bag Item Quantity

- **Source:** `engine/items/get_bag_item_quantity.asm`
- **Translated:** `dos_port/src/items/get_bag_item_quantity.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

A clean, unwired translation of `GetQuantityOfItemInBag`. Standard array scanning returning item quantity.

---

## Pokemon Experience / Level Up 

- **Source:** `engine/pokemon/experience.asm`, `engine/battle/experience.asm`
- **Translated:** `dos_port/engine/pokemon/experience.asm`, `dos_port/engine/battle/experience.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

Heavily utilizes native 32-bit registers to streamline operations. The original 24-bit experience comparisons and arithmetic that required complex byte-by-byte manual cascades are instead highly optimized using the native capabilities of x86 32-bit registers to execute wide comparisons directly.

---

## Remove Pokemon

- **Source:** `engine/pokemon/remove_mon.asm`
- **Translated:** `dos_port/src/pokemon/remove_mon.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

A faithful array-shift implementation for PC and Party deletions. It capitalizes on the previously documented `imul` optimized `AddNTimes` routine to rapidly calculate struct boundaries (`PARTYMON_STRUCT_LENGTH` / `BOXMON_STRUCT_LENGTH`) and employs `CopyDataUntil` with seamless 32-bit addressing.

---

## Decrement PP

- **Source:** `engine/battle/decrement_pp.asm`
- **Translated:** `dos_port/engine/battle/decrement_pp.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

Optimizes battle status bit-checking. The original Game Boy logic required checking individual bits sequentially. The x86 translation compresses this into a single 32-bit mask test (`test al, (1 << STORING_ENERGY) | (1 << THRASHING_ABOUT) | (1 << ATTACKING_MULTIPLE_TIMES)`), saving multiple cycles.

---

## Pikachu Status Verification

- **Source:** `engine/pikachu/pikachu_status.asm`
- **Translated:** `dos_port/engine/pikachu/pikachu_status.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

Highly optimized struct verification for `IsThisPartyMonStarterPikachu` and `IsThisBoxMonStarterPikachu`. Heavy use of the O(1) `imul`-powered `AddNTimes` to immediately jump into `wBoxMon` or `wPartyMon` sub-arrays, instantly bridging OT Names, OT IDs, and Species fields without manual array traversal.

---

*Add new entries below as routines are translated.*

## Flag Action (FlagActionPredef / FlagAction)

- **Source:** `engine/flag_action.asm`
- **Translated:** `dos_port/engine/flag_action.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

**Native Bitwise Optimization:** `FlagAction` eliminates the Game Boy's bit-shifting loop required to generate a bitmask. By loading the bit index into `cl` and using the native x86 `shl dl, cl` instruction, the bitmask is generated in a single cycle. Additionally, the byte offset within the flag array is computed instantly via `shr al, 3` and directly added to the 32-bit base pointer (`add esi, eax`), fully optimizing array access.

---

## Joypad Input Handling (_Joypad / ReadJoypad_)

- **Source:** `engine/joypad.asm`
- **Translated:** `dos_port/engine/joypad.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

Accurately simulates the Game Boy hardware `IO_JOYP` polling logic. The state-transition calculations (deriving newly pressed and released keys from the previous state) heavily leverage hardware register cascades (e.g., `xor`, `and`, `not`) to compute `hJoyPressed` and `hJoyReleased` natively without unnecessary memory swapping. Applies the `wJoyIgnore` mask via an efficient inverted bitwise `and`.

---

## Predef Pointers (GetPredefPointer)

- **Source:** `engine/predefs.asm`
- **Translated:** `dos_port/engine/predefs.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

**`LEA` Multiplier Optimization:** The `PredefPointers` table relies on a 3-byte struct (1 byte for Bank, 2 bytes for Address). To access the nth element, the original Game Boy loops or does complex additions to multiply the index by 3. The x86 translation resolves this natively using the 32-bit `lea` (Load Effective Address) instruction: `lea ecx, [ecx + ecx*2]`. This instantly multiplies the index by 3 and elegantly offsets into the table in O(1) time.

---

*Add new entries below as routines are translated.*

---

## Debug State / Party (PrepareNewGameDebug / SetDebugNewGameParty)

- **Source:** `engine/debug/debug_party.asm`
- **Translated:** `dos_port/src/debug/debug_party.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

A pure data-setup unwired skeleton. Rapidly bypasses legacy loops and directly injects optimal state flags, utilizing optimized division-by-8 loop generation to cleanly populate Pokedex bit fields natively (`NUM_POKEMON / 8` and `(1 << (NUM_POKEMON % 8)) - 1`).

---

## Surfing Pikachu Minigame Math (SurfingMinigame_AddPointsToTotal / SurfingMinigame_Deduct1HP)

- **Source:** `engine/minigame/surfing_pikachu.asm`
- **Translated:** `dos_port/src/minigame/surfing_pikachu.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

**Native BCD Minigame Logic:** Completely detaches the minigame score calculations from graphical state logic. BCD addition and subtraction points scoring are perfectly optimized utilizing the native 386 hardware `DAA` (addition) and `DAS` (subtraction) instructions, natively maintaining a constant cap limitation (`0x9999`) without manual software correction arrays.

---

## Slot Machine Arrays & RNG (SlotMachine_FindWheel1Wheel2Matches / SlotMachine_CheckForMatch)

- **Source:** `engine/slots/slot_machine.asm`
- **Translated:** `dos_port/src/slots/slot_machine.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

Isolates the 3x3 slot machine reel array mapping and random number generation from graphical rendering routines. The logic relies on clean 32-bit `ESI`/`EDI` pointer offset indexing to verify slot layout rows directly, elegantly replacing convoluted 8-bit mapping pointers.

---

*Add new entries below as routines are translated.*

## Itemfinder / Hidden Items (HiddenItemNear)

- **Source:** `engine/items/itemfinder.asm`
- **Translated:** `dos_port/src/items/itemfinder.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

Coordinate delta logic optimally resolved utilizing simple `add` and native carry boundary logic (`jc` / `jnc`) avoiding multi-step conditional branching.

---

## BCD Transaction Subtraction (SubtractAmountPaidFromMoney_)

- **Source:** `engine/items/subtract_paid_money.asm`
- **Translated:** `dos_port/src/items/subtract_paid_money.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

Expertly handles 3-byte BCD array math using native 32-bit registers, deferring pointer iteration to the ultra-fast `StringCmp` and hardware-accelerated `SubBCDPredef` (which relies on native `DAS`). This guarantees instant, safe monetary transactions exactly adhering to GB constraints.

---

## Super Rod Encounters & PRNG (GenerateRandomFishingEncounter)

- **Source:** `engine/items/super_rod.asm`
- **Translated:** `dos_port/src/items/super_rod.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

Effectively maintains the glitch-accurate pseudo-random (PRNG) boundary constraints (`0x66`, `0xB2`, `0xE5`) corresponding to specific Pokemon encounters. Slot array iteration skips iterative counts by advancing pointers directly in `add esi, 8` intervals.

---

## TM Pricing Arrays (GetMachinePrice)

- **Source:** `engine/items/tm_prices.asm`
- **Translated:** `dos_port/src/items/tm_prices.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

BCD packed array access elegantly transformed. The Game Boy's `swap a` macro is replaced by efficient 32-bit native register manipulation (`shl cl, 4; shr al, 4; or al, cl`). The array indexing utilizes `movzx ecx, al; add esi, ecx` natively detaching the pointer array math from 8-bit registers.

---

*Add new entries below as routines are translated.*

## Town Map Data Extraction (LoadTownMapEntry / TownMapCoordsToOAMCoords)

- **Source:** `engine/items/town_map.asm`
- **Translated:** `dos_port/engine/items/town_map.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

**Graphical Independence:** Completely extracts the map array lookups, duplicate-filtering, and OAM conversion logic out from the visual map drawing routines. Uses clean 32-bit `lea` instructions (`lea esi, [esi + ecx*2]`) for pointer resolution, avoiding scaling loops entirely.

---

## TM/HM Base Engine (CheckIfMoveIsKnown / CanLearnTM)

- **Source:** `engine/items/tmhm.asm`, `engine/items/tms.asm`
- **Translated:** `dos_port/engine/items/tmhm.asm`, `dos_port/engine/items/tms.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

Unwired array scanners for validating if a Pokemon possesses the capacity to learn a move or if the move is currently active in the party move structures.

---

## Item Effects Engine (ApplyHealingItem / RestorePPAmount / Func_d85d)

- **Source:** `engine/items/item_effects.asm`
- **Translated:** `dos_port/engine/items/item_effects.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** GLITCH (Preserved original `MAX_ETHER` PP mask bypass).

### Notes

**UI Abstraction & Native Math:**
- `Func_d85d` completely abstracts evolution stone logic away from UI loops.
- `ApplyHealingItem` optimally handles 16-bit Big-Endian potion and revive logic. It seamlessly utilizes the native x86 `sub` and `sbc` chain to verify maximum bounds boundaries and natively divides by 2 (`shr al, 1; rcr al, 1`) for Half-HP Revival logic.
- `RestorePPAmount` accurately ports the legacy Max Ether glitch where upper bits (PP Up increments) bypass masking.

---

*Add new entries below as routines are translated.*

## Bill's PC Headless Logic (BillsPCDepositLogic / BillsPCWithdrawLogic / BillsPCReleaseLogic / KnowsHMMove)

- **Source:** `engine/pokemon/bills_pc.asm`
- **Translated:** `dos_port/src/pokemon/bills_pc.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** GLITCH (Preserved original unreachable logic in `KnowsHMMove`).

### Notes

**Headless PC Abstraction:**
Worker expertly separated the core box transaction operations (Depositing, Withdrawing, and Releasing) entirely from their UI and graphics wrappers. The translated functions operate as headless bounds-checking APIs returning strict carry-flag conditions (`CF=1` for box full/party empty errors) before safely triggering underlying `MoveMon` / `RemovePokemon` algorithms.

**HM Move Parsing:**
`KnowsHMMove` converts multi-cycle structure traversal natively using the O(1) `imul` arithmetic to instantly seek to the Pokemon's move array. It resolves HM applicability using the 32-bit bounded `IsInArray` function passing a data-driven `HMMoveArray`, cleanly optimizing move verification. Note that the original Game Boy codebase contained an unreachable path attempting to parse Box Mon structs; this has been preserved for bug-compatibility.

---

*Add new entries below as routines are translated.*

## Pokemon Array Router (_MoveMon / _AddEnemyMonToPlayerParty / AddPartyMon_WriteMovePP)

- **Source:** `engine/pokemon/add_mon.asm`
- **Translated:** `dos_port/engine/pokemon/add_mon.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

**Massive Structural Abstraction:** Worker successfully routed the enormous `_MoveMon` Pokemon structural data transfer logic. It seamlessly handles moving complex `BOXMON` and `PARTYMON` structs between the Box, Party, and Daycare boundaries headless of any UI interaction. The implementation optimally extracts structural constraints utilizing 32-bit offset arithmetic and `AddNTimes` to instantly resolve pointer targets without legacy iterative pointer increments. 
`AddPartyMon_WriteMovePP` and `_AddEnemyMonToPlayerParty` perfectly optimize array routing while handling Pokédex flag writes natively.

---

## Mon Data Structural Loaders (LoadMonData_ / GetMonSpecies)

- **Source:** `engine/pokemon/load_mon_data.asm`
- **Translated:** `dos_port/engine/pokemon/load_mon_data.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

**Headless Pointers:** Cleanly isolates Pokemon data pointer parsing (`LoadMonData_`) and indexing (`GetMonSpecies`) away from the UI-dependent `learn_move.asm` graphics logic. The data fetching seamlessly relies on ultra-fast native 32-bit structural jumping (`add esi, edx`) resolving list index queries instantly.

---

*Add new entries below as routines are translated.*

---

## Evolutions & Learnsets Engine (EvolutionAfterBattle / LearnMoveFromLevelUp / WriteMonMoves)

- **Source:** `engine/pokemon/evos_moves.asm`
- **Translated:** `dos_port/engine/pokemon/evos_moves.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

**Headless Iteration:** The `EvosMovesPointerTable` structural parsers were perfectly mapped out, extracting the pure logical sequences out of `EvolutionAfterBattle` and `LearnMoveFromLevelUp`. Legacy text-box UI routines, extensive string prints, and pure graphical evolution routines were strictly carved out, leaving behind an optimized 32-bit array traversal engine using fast pointers (`add esi, ecx`) and `AddNTimes` for base stat recalculations and pointer data routing (`WriteMonMoves_ShiftMoveData`).

---

## GetTrainerName_

- **Source:** `engine/battle/get_trainer_name.asm:GetTrainerName_`
- **Translated:** `dos_port/src/engine/battle/get_trainer_name/GetTrainerName_.asm`
- **Date:** 2026-06-20
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** HL→ESI, DE→EDX, BC→BX, A→AL
- **Notes:** W_RIVAL_NAME equ 0xD349 used; defined dummy constants for RIVAL1, etc.

---

## FormatMovesString

- **Source:** `engine/battle/misc.asm:FormatMovesString`
- **Translated:** `dos_port/src/engine/battle/misc/FormatMovesString.asm`
- **Date:** 2026-06-20
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** HL->ESI for move array and name buf, DE->EDX for out string, B->BH
- **Notes:** used EDX for DE ptr; mapped '@' to 0x50, '<NEXT>' to 0x4E based on text.asm

---

## InitList

- **Source:** `engine/battle/misc.asm:InitList`
- **Translated:** `dos_port/src/engine/battle/misc/InitList.asm`
- **Date:** 2026-06-20
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** A->AL, BC->BX, DE->DX, HL->ESI
- **Notes:** Used EAX to extract L and H from ESI. Used 32-bit relocations for externs to satisfy COFF.

---

## ConversionEffect_

- **Source:** `engine/battle/move_effects/conversion.asm:ConversionEffect_`
- **Translated:** `dos_port/src/engine/battle/move_effects/conversion/ConversionEffect_.asm`
- **Date:** 2026-06-20
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** HL→ESI, DE→EDX, A→AL
- **Notes:** removed Bankswitch logic, evaluated INVULNERABLE to 6

---

## CallBankF

- **Source:** `engine/battle/move_effects/conversion.asm:CallBankF`
- **Translated:** `dos_port/src/engine/battle/move_effects/conversion/CallBankF.asm`
- **Date:** 2026-06-20
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** B→BH
- **Notes:** loaded BANK_PrintButItFailedText_ via EAX to avoid 8-bit relocation error

---

*Add new entries below as routines are translated.*

## ConvertedTypeText

- **Source:** `engine/battle/move_effects/conversion.asm:ConvertedTypeText`
- **Translated:** `dos_port/src/engine/battle/move_effects/conversion.asm`
- **Date:** 2026-06-20
- **H-flag:** (not recorded)
- **Bug tags:** none
- **Registers:** (not recorded)
- **Notes:** Emitted as raw byte stream (0x17, dummy addr/bank, 0x50). COFF rejects 16-bit relocations, so dw 0 is used for the far pointer; TextCommandProcessor skips 3 bytes anyway.

---

## PrintButItFailedText

- **Source:** `engine/battle/move_effects/conversion.asm:PrintButItFailedText`
- **Translated:** `dos_port/src/engine/battle/move_effects/conversion.asm`
- **Date:** 2026-06-20
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** HL→ESI
- **Notes:** Flat memory model simplifies CallBankF to a simple jmp esi.

---

## DrainHPEffect_

- **Source:** `engine/battle/move_effects/drain_hp.asm:DrainHPEffect_`
- **Translated:** `dos_port/src/engine/battle/move_effects/drain_hp.asm`
- **Date:** 2026-06-20
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** HL→ESI, BC→EBX, DE→EDX, A→AL
- **Notes:** hlcoord converted to W_TILEMAP offsets.

---

## SuckedHealthText

- **Source:** `engine/battle/move_effects/drain_hp.asm:SuckedHealthText`
- **Translated:** `dos_port/src/engine/battle/move_effects/drain_hp.asm`
- **Date:** 2026-06-20
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** none
- **Notes:** Translated as text data block (TX_FAR skipped, TX_END).

---

## DreamWasEatenText

- **Source:** `engine/battle/move_effects/drain_hp.asm:DreamWasEatenText`
- **Translated:** `dos_port/src/engine/battle/move_effects/drain_hp.asm`
- **Date:** 2026-06-20
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** none
- **Notes:** Translated as text data block (TX_FAR skipped, TX_END).

---

## FocusEnergyEffect_

- **Source:** `engine/battle/move_effects/focus_energy.asm:FocusEnergyEffect_`
- **Translated:** `dos_port/src/engine/battle/move_effects/focus_energy.asm`
- **Date:** 2026-06-20
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** HL→ESI for status ptr, A→AL, C→CL
- **Notes:** used bt/bts for GETTING_PUMPED, text macros commented out

---

## GettingPumpedText

- **Source:** `engine/battle/move_effects/focus_energy.asm:GettingPumpedText`
- **Translated:** `dos_port/src/engine/battle/move_effects/focus_energy.asm`
- **Date:** 2026-06-20
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** none
- **Notes:** Translated text macros to data bytes, used dd for 32-bit far pointer

---

## HazeEffect_

- **Source:** `engine/battle/move_effects/haze.asm:HazeEffect_`
- **Translated:** `dos_port/src/engine/battle/move_effects/haze.asm`
- **Date:** 2026-06-20
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** A->AL, BC->BX, DE->EDX, HL->ESI
- **Notes:** Translated all Haze functions. defined local constants. commented out text_far.

---

## CureVolatileStatuses

- **Source:** `engine/battle/move_effects/haze.asm:CureVolatileStatuses`
- **Translated:** `dos_port/src/engine/battle/move_effects/haze.asm`
- **Date:** 2026-06-20
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** HL→ESI, A→AL
- **Notes:** Used AND with bitmasks for RES bit manipulation

---

## ResetStatMods

- **Source:** `engine/battle/move_effects/haze.asm:ResetStatMods`
- **Translated:** `dos_port/src/engine/battle/move_effects/haze.asm`
- **Date:** 2026-06-20
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** A→AL, B→BH, HL→ESI
- **Notes:** Straightforward translation

---

## ResetStats

- **Source:** `engine/battle/move_effects/haze.asm:ResetStats`
- **Translated:** `dos_port/src/engine/battle/move_effects/haze.asm`
- **Date:** 2026-06-20
- **H-flag:** (not recorded)
- **Bug tags:** none
- **Registers:** (not recorded)
- **Notes:** (none)

---


## StatusChangesEliminatedText

- **Source:** `engine/battle/move_effects/haze.asm:StatusChangesEliminatedText`
- **Translated:** `dos_port/src/engine/battle/move_effects/haze.asm`
- **Date:** 2026-06-20
- **H-flag:** (not recorded)
- **Bug tags:** none
- **Registers:** (not recorded)
- **Notes:** (none)

---


## HealEffect_

- **Source:** `engine/battle/move_effects/heal.asm:HealEffect_`
- **Translated:** `dos_port/src/engine/battle/move_effects/heal.asm`
- **Date:** 2026-06-20
- **H-flag:** (not recorded)
- **Bug tags:** none
- **Registers:** (not recorded)
- **Notes:** (none)

---


## StartedSleepingEffect

- **Source:** `engine/battle/move_effects/heal.asm:StartedSleepingEffect`
- **Translated:** `dos_port/src/engine/battle/move_effects/heal.asm`
- **Date:** 2026-06-20
- **H-flag:** (not recorded)
- **Bug tags:** none
- **Registers:** (not recorded)
- **Notes:** (none)

---


## FellAsleepBecameHealthyText

- **Source:** `engine/battle/move_effects/heal.asm:FellAsleepBecameHealthyText`
- **Translated:** `dos_port/src/engine/battle/move_effects/heal.asm`
- **Date:** 2026-06-20
- **H-flag:** (not recorded)
- **Bug tags:** none
- **Registers:** (not recorded)
- **Notes:** (none)

---


## RegainedHealthText

- **Source:** `engine/battle/move_effects/heal.asm:RegainedHealthText`
- **Translated:** `dos_port/src/engine/battle/move_effects/heal.asm`
- **Date:** 2026-06-20
- **H-flag:** (not recorded)
- **Bug tags:** none
- **Registers:** (not recorded)
- **Notes:** (none)

---


## LeechSeedEffect_

- **Source:** `engine/battle/move_effects/leech_seed.asm:LeechSeedEffect_`
- **Translated:** `dos_port/src/engine/battle/move_effects/leech_seed.asm`
- **Date:** 2026-06-20
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** HL→ESI, DE→EDI, A→AL, C→CL
- **Notes:** used 1<<7 for SEEDED, 22 for GRASS type

---

## WasSeededText

- **Source:** `engine/battle/move_effects/leech_seed.asm:WasSeededText`
- **Translated:** `dos_port/src/engine/battle/move_effects/leech_seed.asm`
- **Date:** 2026-06-20
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** none (text data)
- **Notes:** expanded text_far macro explicitly as requested

---

## EvadedAttackText

- **Source:** `engine/battle/move_effects/leech_seed.asm:EvadedAttackText`
- **Translated:** `dos_port/src/engine/battle/move_effects/leech_seed.asm`
- **Date:** 2026-06-20
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** none
- **Notes:** expanded text_far and text_end macros

---

## MistEffect_

- **Source:** `engine/battle/move_effects/mist.asm:MistEffect_`
- **Translated:** `dos_port/src/engine/battle/move_effects/mist.asm`
- **Date:** 2026-06-20
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** HL→ESI for status pointer, A→AL for turn
- **Notes:** translated text_far and text_end to db 0x17, dd pointer, db 0x50

---

## ShroudedInMistText

- **Source:** `engine/battle/move_effects/mist.asm:ShroudedInMistText`
- **Translated:** `dos_port/src/engine/battle/move_effects/mist.asm`
- **Date:** 2026-06-20
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** none (data only)
- **Notes:** expanded text_far and text_end macros to manual db/dd

---


## OneHitKOEffect_

- **Source:** `engine/battle/move_effects/one_hit_ko.asm:OneHitKOEffect_`
- **Translated:** `dos_port/src/engine/battle/move_effects/one_hit_ko.asm`
- **Date:** 2026-06-20
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** A->AL, HL->ESI, DE->EDI, B->BL
- **Notes:** straight translation, basic branching and 16-bit cmp via 8-bit sub/sbb

---

## ParalyzeEffect_

- **Source:** `engine/battle/move_effects/paralyze.asm:ParalyzeEffect_`
- **Translated:** `dos_port/src/engine/battle/move_effects/paralyze.asm`
- **Date:** 2026-06-20
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** HL→ESI, DE→EDI, A→AL, BC→EBX
- **Notes:** callfar -> call, jpfar -> jmp, ld c -> mov bl for DelayFrames

---

## PayDayEffect_

- **Source:** `engine/battle/move_effects/pay_day.asm:PayDayEffect_`
- **Translated:** `dos_port/src/engine/battle/move_effects/pay_day.asm`
- **Date:** 2026-06-20
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** A->AL, HL->ESI, DE->EDI, BC->EBX
- **Notes:** used ebx/bl for B and C counts; rol al, 4 for swap a

---

## CoinsScatteredText

- **Source:** `engine/battle/move_effects/pay_day.asm:CoinsScatteredText`
- **Translated:** `dos_port/src/engine/battle/move_effects/pay_day.asm`
- **Date:** 2026-06-20
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** not involved
- **Notes:** macro expansion of text_far _CoinsScatteredText

---

## OverworldLoop warp bug fixes

- **Source:** `home/overworld.asm` (warp resolution logic)
- **Translated:** `dos_port/src/engine/overworld/overworld.asm`
- **Date:** 2026-06-20
- **H-flag:** not involved
- **Bug tags:** none (regression fixes, not known original bugs)

### Four bugs fixed in this session

**Bug 1 — W_LAST_MAP unconditional update (multi-floor warp corruption)**

`.warpTransition` always wrote `W_CUR_MAP → W_LAST_MAP` before switching to the
destination map. Going 1F → 2F → 1F would set `W_LAST_MAP = Red's House 2F`; the
next 0xFF warp resolution would then land the player in 2F instead of Pallet Town.
Fix: only update `W_LAST_MAP` when the source map is outdoor (`W_CUR_MAP < FIRST_INDOOR_MAP_ID = 0x25`).
This mirrors pret's `CheckIfInOutsideMap` guard in `WarpFound2`.

**Bug 2 — BIT_STANDING_ON_WARP never set at spawn**

`LoadWarpDestination` placed the player at spawn coords but never checked whether
those coords match a warp entry in the destination map's `W_WARP_ENTRIES`. As a
result, `BIT_STANDING_ON_WARP` was always 0 after a warp transition, making the
collision-exit guard (`test BIT_STANDING_ON_WARP; jz OverworldLoop`) permanently
skip door exits. Fix: after `LoadCurrentMapView`, call `CheckWarpTile` and set
`BIT_STANDING_ON_WARP` if CF=1. Mirrors pret's `IsPlayerStandingOnWarp` called
from `EnterMap`.

**Bug 3 — BIT_EXITING_DOOR suppressed collision-exit (regression from 445c6a3a)**

Commit 445c6a3a added `test BIT_EXITING_DOOR; jnz OverworldLoop` to the
collision-exit path. Pret does NOT have this guard: `BIT_EXITING_DOOR` marks the
auto-walk state, it does not suppress subsequent exit attempts. Combined with Bug 2
(BIT_STANDING_ON_WARP=0 at spawn), all door exits via the collision path were
completely broken — the player could not exit any building by pressing DOWN at the
door. Fix: remove the `test BIT_EXITING_DOOR` guard entirely. The `BIT_STANDING_ON_WARP`
guard is sufficient (it's only set when the player is actually on a warp tile).

**Bug 4 — BIT_SCRIPTED_MOVEMENT_STATE bypass was dead code**

`PlayerStepOutFromDoor` sets `BIT_SCRIPTED_MOVEMENT_STATE` to inject a scripted
PAD_DOWN that should bypass the 180°-turn-delay and immediately fire the
collision-exit. However, the flag was being CLEARED at the simulated-input dispatch
point (before reaching `.handleDirection`) — so `.handleDirection`'s bypass check
always saw 0. Fix: remove the early clear; instead, `.handleDirection` now clears
the flag (after testing it), making the bypass live. Scripted movement now bypasses
`W_CHECK_FOR_TURN` and goes straight to `.walkStart`, which hits the blocked wall
and fires the collision-exit via the now-fixed path.

### Combined effect

After all four fixes: entering a building correctly sets `W_LAST_MAP` only if
coming from outdoors; spawning at the door tile sets `BIT_STANDING_ON_WARP`;
`PlayerStepOutFromDoor` injects a scripted south-step that fires `.walkStart →
CollisionCheckOnLand → collision-exit → warp out` in one frame (bypassing
both the turn-delay and the ignore-input window, which only blocks manual input).
Stair transitions are unaffected: `IsPlayerStandingOnDoorTile` returns CF=0 for
stair tiles, so `PlayerStepOutFromDoor` takes `.notStandingOnDoor`, clears
`BIT_STANDING_ON_DOOR`, and no scripted step is injected.

---

## gen_map_headers.py — IF DEF(_DEBUG) pointer desync bug (2026-06-22)

**Not a translation bug — a tooling bug in the asset generator.**

### What broke

All indoor map warps to maps with ID > `0x26` (BLUES_HOUSE and beyond) were
broken: entering those buildings loaded garbage header data (wrong tileset, wrong
dimensions, wrong warp table). Outdoor→outdoor map transitions were fine.

### Root cause

In commit `445c6a3a`, the `REDS_HOUSE_2F` section of `dos_port/assets/map_headers.inc`
was **hand-edited** to remove 4 `IF DEF(_DEBUG)` warp entries from the object
data. However, the `MapHeaderPointers` table (hardcoded absolute addresses
computed at generation time) was NOT updated. It was still generated assuming 5
warps for REDS_HOUSE_2F (5 × 4 = 20 bytes of warp data). With only 1 warp in the
blob (4 bytes), every pointer for maps after 0x26 pointed 16 bytes too far into
the data blob.

This was invisible locally because `make` sees the committed `.inc` as up to date
and skips regeneration. A fresh clone + regenerate on another machine produced a
consistent (5-warp) file and worked correctly — the discrepancy is what exposed it.

### Fix

`tools/gen_map_headers.py` now calls `strip_debug_blocks()` before parsing each
object file. This strips `IF DEF(_DEBUG) ... ENDC` blocks (with nesting depth
tracking) so the generator produces the same 1-warp layout as the hand-edit —
but also recomputes all the `MapHeaderPointers` correctly. Regenerating the file
closes the 16-byte gap.

### Rule going forward

**Never hand-edit generated files.** If content in `map_headers.inc` or any
other `assets/*.inc` file needs to change, fix the **generator** and regenerate.
The pointer tables are computed at generation time and cannot be partially updated.
If you need to exclude RGBASM-conditional content, add a filter to the generator.

---

## CureVolatileStatuses

- **Source:** `engine/battle/move_effects/haze.asm:CureVolatileStatuses`
- **Translated:** `dos_port/src/engine/battle/move_effects/haze.asm`
- **Date:** 2026-06-23
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** HL->ESI for battle status ptr, A->AL
- **Notes:** none

---

## ResetStatMods

- **Source:** `engine/battle/move_effects/haze.asm:ResetStatMods`
- **Translated:** `dos_port/src/engine/battle/move_effects/haze.asm`
- **Date:** 2026-06-23
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** HL→ESI, B→BH, A→AL
- **Notes:** straight translation; gb memory access via ebp+esi

---

## FocusEnergyEffect_

- **Source:** `engine/battle/move_effects/focus_energy.asm:FocusEnergyEffect_`
- **Translated:** `dos_port/src/engine/battle/move_effects/focus_energy.asm`
- **Date:** 2026-06-23
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** HL->ESI for status ptr, A->AL for turn
- **Notes:** used OR/TEST for GETTING_PUMPED, DelayFrames count in cl

---

## HazeEffect_

- **Source:** `engine/battle/move_effects/haze.asm:HazeEffect_`
- **Translated:** `dos_port/src/engine/battle/move_effects/haze.asm`
- **Date:** 2026-06-23
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** HL->ESI, DE->EDX, A->AL, B->BH
- **Notes:** used EDX for DE to support 32-bit flat EBP addressing

---

## ResetStats

- **Source:** `engine/battle/move_effects/haze.asm:ResetStats`
- **Translated:** `dos_port/src/engine/battle/move_effects/haze.asm`
- **Date:** 2026-06-23
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** HL->ESI for source stat ptr, DE->EDI for dest stat ptr, B->BH for loop counter, A->AL
- **Notes:** added NUM_STATS equ 7 to allow assembly; used EBP memory model

---

## StatusChangesEliminatedText

- **Source:** `engine/battle/move_effects/haze.asm:StatusChangesEliminatedText`
- **Translated:** `dos_port/src/engine/battle/move_effects/haze.asm`
- **Date:** 2026-06-23
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** none
- **Notes:** text macro translation

---

## HealEffect_

- **Source:** `engine/battle/move_effects/heal.asm:HealEffect_`
- **Translated:** `dos_port/src/engine/battle/move_effects/heal.asm`
- **Date:** 2026-06-23
- **H-flag:** not involved
- **Bug tags:** BUG(cosmetic): most significant bytes comparison is ignored
- **Registers:** HL→ESI, DE→EDI, A→AL, B→BH, C→BL
- **Notes:** expanded hlcoord macro manually; translated predef UpdateHPBar2 as call UpdateHPBar2

---

## FellAsleepBecameHealthyText

- **Source:** `engine/battle/move_effects/heal.asm:FellAsleepBecameHealthyText`
- **Translated:** `dos_port/src/engine/battle/move_effects/heal.asm`
- **Date:** 2026-06-23
- **H-flag:** (not recorded)
- **Bug tags:** none
- **Registers:** (not recorded)
- **Notes:** (none)

---

## RegainedHealthText

- **Source:** `engine/battle/move_effects/heal.asm:RegainedHealthText`
- **Translated:** `dos_port/src/engine/battle/move_effects/heal.asm`
- **Date:** 2026-06-23
- **H-flag:** (not recorded)
- **Bug tags:** none
- **Registers:** (not recorded)
- **Notes:** Translated text macro using db byte constants (TX_FAR, TX_END) and dd for flat far pointer.

---

## StartedSleepingEffect

- **Source:** `engine/battle/move_effects/heal.asm:StartedSleepingEffect`
- **Translated:** `dos_port/src/engine/battle/move_effects/heal.asm`
- **Date:** 2026-06-23
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** none
- **Notes:** Text macro converted to db 0x17, dd pointer, db 0x50

---

## LeechSeedEffect_

- **Source:** `engine/battle/move_effects/leech_seed.asm:LeechSeedEffect_`
- **Translated:** `dos_port/src/engine/battle/move_effects/leech_seed.asm`
- **Date:** 2026-06-23
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** HL->ESI, DE->EDI, A->AL, C->CL
- **Notes:** Translated purely; EDI used for DE, CL for C.

---

## WasSeededText

- **Source:** `engine/battle/move_effects/leech_seed.asm:WasSeededText`
- **Translated:** `dos_port/src/engine/battle/move_effects/leech_seed.asm`
- **Date:** 2026-06-23
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** none
- **Notes:** explicit byte directives for text_far and text_end

---

## EvadedAttackText

- **Source:** `engine/battle/move_effects/leech_seed.asm:EvadedAttackText`
- **Translated:** `dos_port/src/engine/battle/move_effects/leech_seed.asm`
- **Date:** 2026-06-23
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** none
- **Notes:** Translated text_far and text_end macros into byte directives.

---

## ShroudedInMistText

- **Source:** `engine/battle/move_effects/mist.asm:ShroudedInMistText`
- **Translated:** `dos_port/src/engine/battle/move_effects/mist.asm`
- **Date:** 2026-06-23
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** none
- **Notes:** explicit byte directives for text_far and text_end

---

## OneHitKOEffect_

- **Source:** `engine/battle/move_effects/one_hit_ko.asm:OneHitKOEffect_`
- **Translated:** `dos_port/src/engine/battle/move_effects/one_hit_ko.asm`
- **Date:** 2026-06-23
- **H-flag:** computed
- **Bug tags:** none
- **Registers:** HL->ESI, DE->EDI, A->AL, B->BH
- **Notes:** Translated exactly matching 8-bit operations.

---

## GettingPumpedText

- **Source:** `engine/battle/move_effects/focus_energy.asm:GettingPumpedText`
- **Translated:** `dos_port/src/engine/battle/move_effects/focus_energy.asm`
- **Date:** 2026-06-23
- **H-flag:** (not recorded)
- **Bug tags:** none
- **Registers:** (not recorded)
- **Notes:** Translated text macro

---

## MistEffect_

- **Source:** `engine/battle/move_effects/mist.asm:MistEffect_`
- **Translated:** `dos_port/src/engine/battle/move_effects/mist.asm`
- **Date:** 2026-06-23
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** HL->ESI, A->AL
- **Notes:** used test/or with 1<<PROTECTED_BY_MIST for bit/set since it's a bit index

---

## PrepareOAMData — extended viewport + walk-offset NPC tracking

- **Source:** `engine/overworld/movement.asm:PrepareOAMData`
- **Translated:** `dos_port/src/gfx/sprite_oam.asm:PrepareOAMData`
- **Date:** 2026-06-23
- **H-flag:** not involved
- **Bug tags:** none

### Summary

Extended `PrepareOAMData` and `render_sprites` to handle the DOS 320×200 viewport
(44×32 visible blocks), replacing 8-bit OAM coordinate arithmetic that overflowed for
NPCs beyond ~8 blocks from the player.

### Changes

**Problem:** The original `render_sprites` derived the screen position of each sprite
by sign-extending the 8-bit OAM Y/X bytes (`movsx eax, byte [ebp + esi]`), then adding
a fixed letterbox offset. For NPCs whose `(MAPY - wYCoord) * 16 - 4` overflows 8 bits
(≥ 8 blocks from the camera), the OAM byte wraps (e.g., MAPY=18, wYCoord=8 → 0xAC),
producing a wildly wrong screen Y in `render_sprites`. Simultaneously, culling used
`cmp al, 0xA0; jae .nextSprite` (GB convention for inactive entries), which falsely
culled any NPC whose OAM Y byte was ≥ 0xA0 even when the computed DOS position was on-screen.

**Fix — 32-bit position tables:**
- Added BSS globals in `ppu.asm`: `spr_dos_sy[40]`, `spr_dos_sx[40]` (one dword per OAM
  entry), and `spr_oam_valid` (count of entries PrepareOAMData wrote this frame).
- `PrepareOAMData` computes a 32-bit `dos_base_y/x` using a hybrid formula:
  - Slot 0 (player): `movsx(H_SPRITE_SCREEN_Y) + 36` / `movsx(H_SPRITE_SCREEN_X) + 96`
    (safe; YPIXELS ≤ 127 for the player).
  - NPC slots 1–15: `(MAPY - wYCoord) * 16 + 32` and `(MAPX - wXCoord) * 16 + 96`
    (full 32-bit; no overflow regardless of map size).
- In `tileLoop`, `edx = (edi - W_SHADOW_OAM) >> 2` (OAM entry index 0–39). Each tile's
  dos_base + tableY/X offset is written to `spr_dos_sy[edx*4]` and `spr_dos_sx[edx*4]`.
- At `.ret`, `spr_oam_valid = H_OAM_BUFFER_OFFSET / 4`.
- `render_sprites` now reads from the tables instead of recomputing from 8-bit OAM bytes.
  The `cmp al, 0xA0` cull is replaced by `cmp ecx, [spr_oam_valid]; jae .nextSprite`.

**Fix — walk-offset NPC smoothing:**
The 32-bit MAPY-based dos_base is block-aligned (constant across a walk step). The BG
scrolls 2 px/frame via `bg_scy`/`bg_scx`. Without compensation, NPCs drift 2 px/frame
against BG tiles and then snap 16 px at the block boundary. Fix: after `.dos_base_done`,
for NPC slots only, subtract `YSTEP_VECTOR * (8 - walk_counter) * 2` (and same for X)
from `dos_base_y/x_tmp`. This is an exact reverse of the BG scroll already applied, so
NPCs track BG tiles smoothly throughout all 8 walk frames.

### Key constants

- `W_SPRITE_PLAYER_Y_STEP_VECTOR = 0xC103` — signed byte; +1 south, -1 north
- `W_SPRITE_PLAYER_X_STEP_VECTOR = 0xC105` — signed byte; +1 east, -1 west
- `W_WALK_COUNTER = 0xCFC4` — 8-frame countdown during a walk step (0 = standing)
- `spr_dos_sy / spr_dos_sx` — BSS arrays declared in `ppu.asm`, externs in `sprite_oam.asm`

---

## render_sprites — extended viewport culling

- **Source:** (DOS-only; no GB equivalent — PPU software renderer)
- **Translated:** `dos_port/src/ppu/ppu.asm:render_sprites`
- **Date:** 2026-06-23
- **H-flag:** not involved
- **Bug tags:** none

### Summary

`render_sprites` was rewritten to use the `spr_dos_sy/sx` position tables filled by
`PrepareOAMData` (see entry above) instead of recomputing positions from 8-bit OAM
bytes. Entry validity is now checked via `spr_oam_valid` count rather than the GB-style
`cmp al, 0xA0` OAM-Y sentinel, which falsely culled on-screen NPCs whose 8-bit OAM Y
had wrapped past 0xA0 due to the extended viewport distance.

The symptom that surfaced the bug: walking RIGHT kept NPCs visible (only X changed;
Y-byte stable). Walking UP/DOWN/LEFT triggered premature NPC disappearance because
those directions changed the Y-byte across the 0xA0 threshold.

---

## InitMapSprites / LoadNPCSpriteTiles

- **Source:** `engine/overworld/map_sprites.asm:InitMapSprites` + `LoadMapSpriteTilePatterns`
- **Translated:** `dos_port/src/engine/overworld/map_sprites.asm`
- **Date:** 2026-06-23
- **H-flag:** not involved
- **Bug tags:** none

### Summary

Implements the data pipeline from map object binary → NPC sprite slots → VRAM:

1. Clears NPC slots 1–15 in `wSpriteStateData1/2`.
2. Reads `sprite_count` + per-NPC 6-byte records from the GB address pointed to
   by `W_OBJECT_DATA_PTR_TEMP` (set by `LoadMapHeader`).
3. Populates `PICTUREID`, `MAPY/MAPX`, `MOVEMENTBYTE1/2`, `MOVEMENTDELAY`,
   `IMAGEBASEOFFSET`, and `ISTRAINER` for each slot.
4. Trainer NPCs: reads extra 2 bytes (trainer_class, trainer_num) and sets ISTRAINER=1.
5. `FindOrAssignVramSlot`: deduplicates sprite types; each unique type gets a
   `imageBaseOffset` (3, 4, 5, …); slots 1=player, 2=Pikachu are reserved.
6. `LoadNPCSpriteTiles`: copies 192 bytes (12 still tiles) per unique sprite type to
   `[EBP + GB_VCHARS0 + (imageBaseOffset-1)*192]`; sets `g_tilecache_dirty=1`.

NPC assets (`npc_oak_still.inc`, `npc_girl_still.inc`, `npc_fisher_still.inc`) are
embedded in `.data` section of `map_sprites.asm` via `NpcSpriteAssets` lookup table.

---

## CheckSpriteAvailability — DOS viewport culling fix

- **Source:** `engine/overworld/movement.asm:CheckSpriteAvailability`
- **Translated:** `dos_port/src/engine/overworld/movement.asm:CheckSpriteAvailability`
- **Date:** 2026-06-23
- **H-flag:** not involved
- **Bug tags:** none (DOS-port adaptation, not a GB bug)

### Summary

The original pret visibility range test used 8-bit unsigned byte arithmetic:
`cmp wYCoord, MAPY; jae .invisible` (lower bound) + `add wYCoord, SCREEN_HEIGHT/2-1; jb .invisible` (upper). With `SCREEN_HEIGHT=25` (DOS) this gave `MAPY ∈ [wYCoord, wYCoord+11]`. Due to the `origin+4` offset stored in `MAPY/MAPX`, the actual-tile-delta visible range was `[-4, +7]` Y and `[-4, +15]` X — badly asymmetric with the DOS 320×200 viewport needing `[-6, +6]` Y and `[-10, +9]` X.

**Symptom:** NPCs disappeared 5–7 metatile columns too early to the west (X) and ~2 rows too early to the north (Y). One-sided culling was the fingerprint that isolated this to `CheckSpriteAvailability` rather than the symmetric `render_sprites` or `dos_base` formulas.

**Fix:** Two-sided 32-bit signed range comparisons replacing the old `jae`/`jb` pair:
- Y: `MAPY ∈ [wYCoord−3, wYCoord+11]` → actual delta `[−7, +7]` (1-tile buffer)
- X: `MAPX ∈ [wXCoord−7, wXCoord+14]` → actual delta `[−11, +10]` (1-tile buffer)

**Critical:** Lower-bound subtraction must use 32-bit signed registers — `sub al, 3` wraps to `0xFC` when `wYCoord=0`, culling every NPC. Fix: `movzx eax; lea ecx,[eax-N]; cmp ecx,edx; jg .invisible`.

---

## UpdateNonPlayerSprite / NPC walk state machine

- **Source:** `engine/overworld/movement.asm:UpdateNPCSprite` and helpers (pret lines 99–370, 556–666, 990–1016)
- **Translated:** `dos_port/src/engine/overworld/movement.asm`
- **Date:** 2026-06-23
- **H-flag:** not involved
- **Bug tags:** BUG(cosmetic) Yellow south-displacement fix applied (see below)

### Summary

Full NPC random-walk state machine: status dispatch, delay countdown, direction selection with UP_DOWN/LEFT_RIGHT/forced-dir constraints, tile passability + collision + displacement bounds check, walk-pixel interpolation, and animation counter.

### Functions translated

| Pret label | DOS label | Notes |
|---|---|---|
| `UpdateNPCSprite` | `UpdateNonPlayerSprite` | Status 0→init, 1→ready, 2→delay, 3→walk; BIT_FACE_PLAYER stub |
| `Func_5337` | `Func_5337` | Write FACINGDIRECTION/YSTEPVECTOR/XSTEPVECTOR to sprite slot |
| `Func_5349` | `Func_5349` | Advance MAPY/MAPX to destination at walk START (not end) |
| `TryWalking` | `TryWalking` | Call Func_5337 → CanWalkOntoTile → Func_5349 → STATUS=3 |
| `CanWalkOntoTile` | `CanWalkOntoTile` | IsTilePassable + STAY check + displacement bounds + DetectCollision |
| `UpdateSpriteMovementDelay` | `UpdateSpriteMovementDelay` | Decrement MOVEMENTDELAY; 0 → STATUS=1, fall into NotYetMoving |
| `NotYetMoving` | `NotYetMoving` | Reset ANIMFRAMECOUNTER, UpdateSpriteImage |
| `UpdateSpriteInWalkingAnimation` | `UpdateSpriteInWalkingAnimation` | pixel-interpolation (YPIXELS/XPIXELS += YSTEP/XSTEP), WALKANIMCOUNTER |
| `Random` | `Random` | Thin wrapper: saves/restores EBX, calls `Random_`, returns H_RANDOM_ADD in AL |

### SPRITESTATEDATA2 constants bug fixed

`gb_memmap.inc` had MOVEMENTDELAY at offset 0x1 (unused slot) and MOVEMENTBYTE2 at 0x8 (the real MOVEMENTDELAY slot). This caused map_sprites.asm to write direction constraints to slot 0x8 and delays to slot 0x1. Fix: swap them to match pret (MOVEMENTBYTE2=0x1, MOVEMENTDELAY=0x8). Because map_sprites.asm uses symbolic constants, the write offsets corrected automatically.

### Func_5349 timing — teleport-prevention

Pret advances MAPY/MAPX to the **destination** at walk **start** (inside `TryWalking`, before the first pixel step). PrepareOAMData's `dos_base_npc` formula therefore subtracts `YSTEP × WALKANIMCOUNTER` and `XSTEP × WALKANIMCOUNTER` to interpolate back to the source position, counting down to 0 at walk end. Without this, NPCs would appear to teleport one metatile and slide back.

### wMapSpriteData indirection eliminated

Pret's `UpdateNPCSprite` reads the direction constraint (`wCurSpriteMovement2`) via a separate `wMapSpriteData` pointer array. The DOS port stores the constraint directly in `SPRITESTATEDATA2[MOVEMENTBYTE2]` (offset 0x1), set by `InitMapSprites`. No separate array needed.

### Yellow south-displacement fix

Red/Blue had a bug: the south-displacement upper bound used `cmp a, 5; jnc .blocked` — the same condition as the north lower bound — which meant NPCs could only move 4 tiles south of their starting position. Yellow fixed this by removing the south upper bound check. The DOS port follows Yellow behavior (no south or east upper bound).

### Random_ / IO_DIV

`random.asm`'s LCG reads `IO_DIV` (at `[EBP + 0xFF04]`). Previously always 0 (emulated but not driven). Fixed by incrementing `IO_DIV` once per frame inside `commit_shadow_regs` (`frame.asm`) so the LCG has changing input. Verified live: NPCs walk with varied directions and delays.

---

## Script engine — event-flag system (Stage 1)

- **Source:** `macros/scripts/events.asm` (CheckEvent/SetEvent/ResetEvent), `constants/event_constants.asm`
- **Translated:** `dos_port/include/events.inc` + `dos_port/assets/event_constants.inc` (generated by `tools/gen_event_constants.py`)
- **Date:** 2026-06-25
- **H-flag:** Not involved.
- **Bug tags:** None.

`gen_event_constants.py` parses the rgbds `const_def`/`const`/`const_skip`/`const_next`
enumeration into `EVENT_* equ <bit index>` (522 events, `NUM_EVENTS=2560` = 320 bytes).
`events.inc` converts an index into `(byte offset, bit mask)` at assembly time
(`EVENT_BYTE`/`EVENT_MASK`; modulo written as `i-(i/8)*8` to avoid NASM's `%`
preprocessor character) and provides `CheckEvent`/`SetEvent`/`ResetEvent` over
`W_EVENT_FLAGS` (0xD746), which `InitMapSprites` already zeroes. All three clobber AL;
`CheckEvent` sets ZF with pret's polarity (ZF=1 ⇒ flag clear, matching `bit n,[hl]` →
`jr z`). Header-level NASM macros, so not a `translation.db` queue row. Verified:
Pallet Town event values spot-checked against the source; a harness exercising all
three macros assembles clean (`nasm -f coff`).

---

## Script engine — text_asm dispatch + Pallet Town reference (Stages 2–4)

- **Source:** `home/text_script.asm:DisplayTextID` (dispatch concept), `scripts/PalletTown.asm:PalletTownOakText`
- **Translated:** `dos_port/src/scripts/pallet_town.asm`, `dos_port/src/engine/overworld/map_sprites.asm` (`ShowTextStream` + dispatch), `dos_port/tools/gen_npc_dialogs.py` (`SCRIPT_OVERRIDES`)
- **Date:** 2026-06-25
- **H-flag:** Not involved.
- **Bug tags:** None.

**Design (divergence from pret, documented):** gen-1 marks a `text_asm` entry with a
`TX_START_ASM` (0x08) byte at the head of the text stream and `jp hl` past it. The DOS
port's map TextTable already stores `(flat ptr, size)` per slot and copies streams into
`NPC_DIALOG_BUF` (WRAM) because `PrintText` wants EBP-relative pointers. So instead of an
in-stream marker, a **SCRIPT entry** is `dd <routine>, 0xFFFFFFFF` — the sentinel size
tells `CheckNPCInteraction` to CALL the flat `text_asm` routine. A new shared
`ShowTextStream` (ESI=flat stream, ECX=count → copy to `NPC_DIALOG_BUF`, `PrintText`,
`npc_dialog_wait_impl`) serves both the plain path and scripts. The font load was moved
ahead of the dispatch (both paths need it); `LoadFontTilePatterns` preserves EDI and
leaves EBX untouched, so the flat ptr/size survive it.

`gen_npc_dialogs.py:SCRIPT_OVERRIDES` maps a pret text-pointer label → a hand-written
NASM script label; matching slots emit the SCRIPT entry + `extern`.
`PalletTownOakText` (reference) gates on `EVENT_GOT_POKEBALLS_FROM_OAK` via the Stage 1
`CheckEvent` macro and shows one of two branches. The full intro (wOakWalkedToPlayer
variants, Oak walk-up cutscene, Pikachu battle) is deferred — recorded as `stubs` on
queue row 4398 (kinds: battle, misc).

**Status:** builds + links (default and `DEBUG_OAK_EVENT=1`). **Not yet visually
verified** — Oak does not spawn into Pallet Town until the intro/spawn-gating exists, so
the dialog is unreachable in-game for now. Verify once Oak is spawned.

---

## Pokémon engine — Stage 5 tail (load/set-types/remove) + sym-pinned addresses

- **Source:** `engine/pokemon/load_mon_data.asm` (LoadMonData_/GetMonSpecies),
  `engine/pokemon/set_types.asm` (SetPartyMonTypes), `home/move_mon.asm`
  (RemovePokemon→_RemovePokemon, CopyDataUntil), `home/predef.asm` (GetPredefRegisters)
- **Translated:** `dos_port/src/engine/pokemon/{load_mon_data,set_types,remove_mon}.asm`,
  `dos_port/src/home/{predef.asm,copy_data.asm (+CopyDataUntil)}`,
  `dos_port/include/gb_memmap.inc` (address fixes + aliases),
  `dos_port/tools/gen_growth_rates.py` (new generator)
- **Date:** 2026-06-25
- **H-flag:** Not involved.
- **Bug tags:** None new; fixed a latent address bug (below).

**Address correction (sym-pinned).** `origin/symbols:pokeyellow.sym` revealed the
lowercase `wMonHeader` block in `gb_memmap.inc` was off by one (too high):
`wMonHeader` was $D0B8, sym says $D0B7; the whole block shifted down one byte to
match (`wMonHBaseHP` $D0B8, `wMonHType1` $D0BD, … `wMonHLearnset` $D0CB). A prior
pass had also "corrected" `W_MON_H_GROWTH_RATE`/`wMonHGrowthRate` $D0CA→$D0CB on
the false premise wMonHeader was $D0B8 — reverted to the sym's $D0CA. The error
was invisible to the existing native harnesses because each is self-contained
(the writer and reader share the same constant); the new `load_mon_data` test
reads real Bulbasaur base stats back through `GetMonHeader` at the corrected
addresses, so writer/reader now agree on absolute placement too. Added the
previously-deferred cross-section aliases (`wLoadedMon`, `wPokedexNum`, enemy/box/
daycare, `wPredefHL/DE/BC`, `wPartyMonNicksEnd`, `wRemoveMonFromBox`) from the sym.

**Draft bugs fixed.** (1) Wrong include paths (`dos_port/include/...` → `-I`
relative). (2) Register contract: `AddNTimes`/`CopyDataUntil` read **BX** (the
bc pair), but `remove_mon` passed strides and CopyDataUntil end-pointers in
`ECX`, which those helpers ignore — every party/box shift was driven by garbage.
Rewrote `remove_mon` faithfully using BX. `load_mon_data`'s data-location
dispatch relies on `mov` not touching EFLAGS between `cmp` and `jz/jc` (faithful
to SM83 `ld hl,…` between `cp` and `jr`) — kept and commented.

**New support routines.** `CopyDataUntil` (copies `[HL,BC)`→`DE`, 16-bit end
compare via `cmp si,bx`). `GetPredefRegisters` (restores HL/DE/BC from the
big-endian `wPredef*` slots); only this predef leaf is ported — `SetPartyMonTypes`
is its sole caller and harnesses populate `wPredefHL` directly (full predef
dispatch deferred).

**Reproducibility fix.** `assets/growth_rates.inc` was hand-authored, but
`dos_port/assets/` is gitignored, so a fresh clone couldn't assemble
`pokemon_data.asm`. Now generated by `tools/gen_growth_rates.py` from
`data/growth_rates.asm` (dn/sign-magnitude macro logic) and wired into the
Makefile `assets` target alongside `gen_base_stats.py`.

**Status / validation.** All POKEMON_SRCS assemble (`-f coff`). A djgpp partial
link (`ld -r`) of the full pokemon closure succeeds with **zero unresolved
externals**. Native ELF harness (nasm `-f elf32` + `gcc -m32`, EBP→64KB buffer)
PASSES all three: `_RemovePokemon` (party-of-3, remove idx 1 → count 2, species
`[10,30,FF]`, structs/OT/nicks shifted, untouched mon intact), `LoadMonData_`
(party mon 0 Bulbasaur $99 → struct copied to wLoadedMon, base stats HP $2D /
Grass $16 / Poison $03), `SetPartyMonTypes` (writes Grass/Poison to MON_TYPE).
The full `make` link is blocked only by the unrelated rgbds map-asset bootstrap
(`*_blk.inc` ← `.2bpp`), which affects `overworld.o`, not pokemon code.

---

## Pokémon engine — Stage 6 learnset/moves core (data + WriteMonMoves + integration)

- **Source:** `engine/pokemon/evos_moves.asm` (GetMonLearnset, WriteMonMoves,
  WriteMonMoves_ShiftMoveData), `engine/pokemon/add_mon.asm`
  (AddPartyMon_WriteMovePP + the _AddPartyMon move/PP path), `data/moves/moves.asm`,
  `data/pokemon/evos_moves.asm`
- **Translated:** `dos_port/src/engine/pokemon/write_moves.asm`,
  `dos_port/src/engine/pokemon/add_party_mon.asm` (integration + WriteMovePP),
  `dos_port/tools/gen_moves.py`, `dos_port/tools/gen_evos_moves.py`,
  `dos_port/src/data/pokemon_data.asm` (+globals), `gb_constants.inc` (MOVE_*),
  `gb_memmap.inc` (wLearningMovesFromDayCare/wDayCareStartLevel)
- **Date:** 2026-06-25
- **H-flag:** Not involved.
- **Bug tags:** None.

**Data (generated, never hand-authored).** `gen_moves.py` emits `Moves`
(165 × MOVE_LENGTH=6: anim,effect,power,type,acc,pp; the rgbds `percent` macro is
`* $ff / 100`). `gen_evos_moves.py` emits `EvosMovesPointerTable` + per-mon blobs
(evolution entries, db 0, level/move learnset pairs, db 0), resolving every db
operand against a merged EVOLVE_*/species/item/move constant table. **DOS
divergence:** the pointer table is flat 32-bit `dd` (program-image labels), not
pret's 16-bit `dw` bank pointers — so `GetMonLearnset` indexes it ×4 and reads a
32-bit pointer. Both wired into `pokemon_data.asm` and the Makefile `assets` target.

**Routines.** `GetMonLearnset` rewritten for the flat table (the draft read a
16-bit pointer and used it as a flat address — unusable). `WriteMonMoves` +
`WriteMonMoves_ShiftMoveData`: the learnset cursor (hl→ESI) is a FLAT program
pointer read with `[esi]`, while the mon's move slots (de→EDX) are GB WRAM read
`[ebp+edx]`; inside the shift branch ESI is reloaded from EDX and is a WRAM
offset. The day-care branch (`wLearningMovesFromDayCare != 0`) is translated but
unreachable today (no day-care system); its PP write reads the flat `Moves`
table directly (like GetMonHeader) rather than via EBP-relative FarCopyData —
TODO-DAYCARE. `AddPartyMon_WriteMovePP` likewise reads base PP straight from the
flat `Moves` table.

**Integration.** `_AddPartyMon`'s move/PP stubs are replaced: after writing the
level-1 base moves it sets `wPredefDE` = MON_MOVES base (the predef contract
`WriteMonMoves` restores via GetPredefRegisters) and calls `WriteMonMoves`, then
`AddPartyMon_WriteMovePP` for real PP.

**Validation (native ELF32 + gcc -m32 harness).** L15 Bulbasaur →
Tackle/Growl/Leech Seed/Vine Whip, PP 35/40/10/10 (base + L7/L13 learnset). L48
Bulbasaur exercises the slot-shift: base moves pushed out, final slots
Razor Leaf/Growth/Sleep Powder/SolarBeam, PP 25/…/10 — exact vs Gen-1. A djgpp
partial link (`ld -r`) of the full pokemon closure resolves with zero unresolved
externals. (Full `make` link still gated only by the unrelated rgbds map-asset
bootstrap.) DEFERRED: evolution flow, MonsterNames, bills_pc, TM/HM learnset bits.

---

## Pokémon engine — Stage 6 data: TM/HM bitfield + MonsterNames + default nickname

- **Source:** base_stats `tmhm` macro (macros/data.asm) + constants/item_constants.asm
  (TMNUM order); data/pokemon/names.asm + constants/charmap.asm; engine/pokemon/
  add_mon.asm (the AskName default-name behaviour)
- **Translated/generated:** `tools/gen_base_stats.py` (TM/HM bitfield now filled),
  `tools/gen_monster_names.py` (new), `src/data/pokemon_data.asm` (+MonsterNames),
  `src/engine/pokemon/add_party_mon.asm` (default nickname)
- **Date:** 2026-06-25
- **H-flag / Bug tags:** none.

**TM/HM bitfield.** `gen_base_stats.py` no longer zeroes the 7-byte field at +20:
it parses each species' `tmhm` move list (joining `\`-continued lines) and sets
bit (TMNUM-1) per move, where TMNUM is built from `item_constants.asm`'s `add_tm`
order (1..50) + `add_hm` order (51..55). Verified against the hand-computed
Bulbasaur field `A4 03 38 C0 03 08 06`. Consumers (TM-item usage) remain deferred.

**MonsterNames.** `gen_monster_names.py` encodes data/pokemon/names.asm with the
GB charmap (reusing the gen_npc_dialogs loader pattern) into 190 × 10-byte
'@'-padded records, internal-index order. Verified RHYDON / NIDORAN♂ (♂=0xEF).

**Default nickname (UI stub).** `_AddPartyMon` writes the species name from
MonsterNames into the new mon's nick slot — the non-UI outcome of pret's
`predef AskName`. STUB documented at `add_party_mon.asm:.nickCopy`: the
interactive naming screen is deferred; when built it should branch on
wMonDataLocation==0 and fall back to this default. MonsterNames is a flat table,
so it's read directly (not via EBP-relative CopyData). Native harness: gift
Bulbasaur nickname encodes to "BULBASAUR" (81 94 8B 81 80 92 80 94 91 50 50).

---

## Items engine — Stage 1: bag/PC inventory bookkeeping (no UI)

- **Source:** engine/items/inventory.asm (AddItemToInventory_, RemoveItemFromInventory_)
- **Translated:** dos_port/src/engine/items/inventory.asm (replaces the swarm draft),
  + WRAM aliases / BAG_ITEM_CAPACITY/PC_ITEM_CAPACITY in gb_memmap.inc/gb_constants.inc
- **Date:** 2026-06-25
- **H-flag / Bug tags:** none.

Pure data manipulation of a bag/PC inventory (count, then (id,qty) pairs, then
$FF). No UI. `RemoveItemFromInventory_` resets a few menu-state bytes (scroll/
cursor) — plain WRAM writes; the rendering that consumes them is UI elsewhere.

**Draft bug fixed:** the swarm draft advanced hl before the empty-inventory
zero-count test (pret's `ld a,[hli]` reads the count THEN increments), so a fresh
`00 FF` bag tested the wrong byte and misbehaved. The SM83 `push af`/`pop bc`
trick that stashes wItemQuantity is replaced by an explicit save/restore.

**Native validation (ELF32 + gcc -m32):** add-new, stack-existing, ≥100 overflow
(99 in slot + leftover in a new slot), bag-full rejection (CF clear), remove-
partial, and remove-to-zero (slot dropped, following slots shifted up) — all exact.

---

## Items engine — Stage 2 (partial): item names + prices data

- **Source:** data/items/names.asm (ItemNames), data/items/prices.asm (ItemPrices)
- **Generated:** dos_port/tools/gen_items.py -> assets/items.inc;
  src/data/item_data.asm (globals ItemNames/ItemPrices)
- **Date:** 2026-06-25 — pure data, no UI.

ItemNames: 97 names, GB-charmap encoded and '@'-terminated ($50), variable length
(as pret's `li` macro). ItemPrices: 97 x 3-byte BCD (pret's bcd3: nibble-packed
6-digit). Verified POKé BALL encoding (8F 8E 8A BA 7F 81 80 8B 8B 50) and prices
(MASTER_BALL 0, ULTRA_BALL 1200 -> 00 12 00, POKE_BALL 200 -> 00 02 00). No
consumer yet (mart/bag UI deferred); foundational data for those.

---

## Pokémon engine — Gen-2 forward-compat: held item in the catch-rate byte

- **Source:** engine/pokemon/add_mon.asm (the KADABRA / TWISTEDSPOON_GSC case)
- **Translated:** dos_port/src/engine/pokemon/add_party_mon.asm; constants +
  forward-compat notes in gb_constants.inc; CLAUDE.md "Gen 2 Forward-Compatibility".
- **Date:** 2026-06-25.

Restored the pret behaviour my _AddPartyMon rewrite had dropped: the
MON_CATCH_RATE byte (struct offset 7) is Gen 2's held-item slot across the Time
Capsule, so Kadabra (internal idx $26) is written holding TWISTEDSPOON_GSC ($60)
there. Documented that the party (44) / box (33) struct layout must stay
byte-identical to Gen 1 for the planned Gen 2 port — no shrinking/repurposing,
and party↔box/trade/save paths must carry offset 7 verbatim. Native harness:
Bulbasaur keeps catch rate 0x2D in +7; Kadabra shows 0x60.

---

## Overworld START menu — DisplayStartMenu

- **Source:** home/start_menu.asm (DisplayStartMenu), engine/menus/draw_start_menu.asm
- **Translated:** dos_port/src/engine/menus/start_menu.asm; trigger in
  src/engine/overworld/overworld.asm (OverworldLoop START-press); window
  generalization in src/ppu/ppu.asm; place_flat_str export in src/text/text.asm;
  LoadNPCSpriteTiles export in src/engine/overworld/map_sprites.asm.
- **Date:** 2026-06-25.

The corner menu box renders through the **GB window layer** (same path as the NPC
dialog box), not the BG: the box + item labels are drawn into wTileMap (the text
engine's 20-wide scratch grid, unused for BG in the overworld) with TextBoxBorder /
place_flat_str, then the 10×{14,16} box rect is copied into GB_TILEMAP1 and shown
by render_window. render_window gained two box-bound globals — **g_win_clip_w**
(blit width) and **g_win_max_y** (bottom row) — defaulting to SCREEN_W / RENDER_H
so the existing full-width bottom dialog box is byte-for-byte unchanged; the menu
narrows them to an 80px × {112,128}px corner box at WX=167 (the centered GB col 10).

**Font-swap gotcha (the whole reason text first rendered as garbage):** vFont
($8800) is time-shared with the player's/NPCs' walk tiles in the overworld, so the
glyphs are not resident until loaded. DisplayStartMenu mirrors the dialog path —
force the player to a standing pose, set BIT_FONT_LOADED (freezes NPC movement),
call LoadFontTilePatterns before drawing, and on close restore the walk tiles
(LoadNPCSpriteTiles + LoadPlayerSpriteGraphics). Input uses H_JOY_PRESSED (reliable
here: this loop calls DelayFrame exactly once per iteration, unlike OverworldLoop's
double-delay idle path). Pokédex slot is event-gated (EVENT_GOT_POKEDEX → 7 vs 6
items). All sub-menus are no-op stubs returning to the menu — **SAVE is an
intentional dead-end** (no save system) and the rest are hooks for the item / party
/ options UIs; EXIT / B / START close. Verified via the DEBUG_STARTMENU harness
(FRAME.BIN dump): box, border, cursor, and "POKéMON / ITEM / NINTEN / SAVE / OPTION
/ EXIT" all render correctly over Pallet Town; dialog box + baseline overworld
unaffected.

---

## Item effects (heal / cure / PP / wake / vitamin / rare candy) + mart data

- **Source:** `engine/items/item_effects.asm` (the `.addHealAmount` / `.cureStatusAilment`
  / `.restorePP` / `.useVitamin` / `.useRareCandy` cores), `data/items/marts.asm`
- **Translated:** `dos_port/src/engine/items/item_effects.asm`,
  `dos_port/tools/gen_items.py` → `assets/items.inc`
- **Date:** 2026-06-26
- **H-flag:** Not involved (8/16-bit add/sub with CF carried into `sbb`/`rcr`; no DAA/CPL).
- **Bug tags:** GLITCH(faithful) — Max-Ether/Max-Elixer PP-Up bug reproduced (full
  PP-restore path doesn't mask the upper two PP-Up bits, so a maxed move with PP Ups
  isn't detected as "no effect").

### Summary

Items-plan Stage 3 (non-UI effect math) + Stage 2 finish (mart inventories).

**Effects.** Lifted the pure WRAM-mutation cores out of the `ItemUse*` handlers,
dropping the surrounding text/menu/animation/in-battle-stat-copy (UI boundary).
Caller passes the target pointer (ESI) + amount (BL); CF returns had-effect.
Replaces the swarm draft, which (a) declared every constant `extern` instead of
`%include`-ing the const headers, and (b) had a 16-bit `mov dx,/mov bx,` width bug
in the evo-stone path. `ApplyHealingItem` keeps the big-endian HP layout and the
exact branch order (REVIVE → half-max; current≥max → clamp; FULL_RESTORE/MAX_POTION
/MAX_REVIVE → force max). x86 note: `dec`/`inc` preserve CF, so the borrow from the
`sub`/`sbb` HP compare and the `shr`→`rcr` half-max rotate survive the pointer
arithmetic between them.

`ApplyVitamin` adds 2560 stat exp (256*10) to the chosen stat's big-endian
stat-exp word MSB, capped when the MSB already reaches 100 (25600); the dead +255
clamp from pret is kept faithfully. `RareCandyLevelUp` is the data core of
`.useRareCandy`: +1 level (no-op at MAX_LEVEL), `CalcExperience` → set experience
to the new level's minimum, `CalcStats` recalc, then add (new max HP − old max HP)
to current HP. Ordering note: the experience write must precede CalcStats because
`H_EXPERIENCE` aliases `H_MULTIPLICAND` (CalcStats scratch). Both reuse the existing
pokemon-engine `CalcStats`/`CalcExperience`; the move-learn / evolution / stats-box
/ party-menu redraw tail is deferred (engine + UI).

**Deferred:** `Func_d85d` (evo-stone applicability) reads `EvosMovesPointerTable`,
which the DOS port stores with its own flat addressing (`evos_moves.asm`); the pret
`add hl,bc` ×2 / copy-2-bytes-as-a-pointer logic isn't a verbatim carry-over, so it
belongs with the evolution path. The X-stat / X-Accuracy / Guard Spec / Dire Hit
items are battle-engine integration (set a `wPlayerBattleStatus2` bit / call
`StatModifierUpEffect`), deferred to the battle work.

**Marts.** `gen_items.py` parses `script_mart ITEM, …` lines (resolving constant
names → ids from the `; $XX` comments in `item_constants.asm`, incl. `add_tm`/`add_hm`
→ `TM_`/`HM_`) and emits `MartInventories` (16 marts, each `db count, ids, $FF` —
the `script_mart` body minus the TX_SCRIPT_MART dispatch byte) + a flat `MartPointers`
dd-table + `NUM_MARTS`.

### Validation

Native ELF32 + `gcc -m32`, 38 checks all pass: potion partial/overheal-clamp,
revive half-max, antidote hit/miss + full-heal-any, ether +10/cap/already-full +
max-ether PP-Up bug, party sleep-clear + wake-flag set/clear, vitamin
add/cap/other-stat-untouched/last-stat (Calcium), and rare-candy
level+exp+new-maxHP+HP-delta + max-level no-op. The rare-candy test stubs
`CalcExperience`/`CalcStats` to inject known values (the real ones need the full
growth-rate / base-stat subsystems), so it validates this routine's pointer
arithmetic and HP-delta math; the production build links the real engine routines.
Mart bytes spot-checked vs pret (Viridian, Celadon-2F TM clerk). Full
`make SKIP_TITLE=1` links with `item_effects.asm` wired into `ITEMS_SRCS`.

---

## Mart money math + GetItemPrice (SubtractAmountPaidFromMoney_ / AddAmountSoldToMoney_ / GetItemPrice)

- **Source:** `engine/items/subtract_paid_money.asm`, `home/inventory.asm`
  (AddAmountSoldToMoney), `home/item_price.asm`, `data/items/tm_prices.asm`
- **Translated:** `dos_port/src/engine/items/subtract_paid_money.asm`,
  `dos_port/src/engine/items/item_price.asm`, `dos_port/tools/gen_items.py`
  (TechnicalMachinePrices)
- **Date:** 2026-06-26
- **H-flag:** Not involved (BCD via x86 `daa`/`das`; H is consumed inside the BCD
  helpers, not by these callers).
- **Bug tags:** None new. Reproduces the GB BCD overflow saturation (fill 0x99).

### Summary

Items-plan Stage 4: the non-UI buy/sell money math + item price lookup.

**Money.** `SubtractAmountPaidFromMoney_` BCD-compares wPlayerMoney vs hMoney
(MSB→LSB, `StringCmp`) and, if affordable, subtracts (`SubBCD`), returning CF=0
success / CF=1 can't-afford. `AddAmountSoldToMoney_` BCD-adds the sale total
(`AddBCD`). The MONEY text-box redraw + SFX_PURCHASE are UI, dropped. The prior
swarm draft fed `StringCmp` the operands in EDI/CL, but the port's StringCmp reads
EDX (de) and BL (c) — so the compare ran on stale registers; fixed, and the
`*Predef` wrappers (which reload args from predef regs) swapped for direct
`AddBCD`/`SubBCD` since we set the registers ourselves. Linking these also pulled
in `engine/math/bcd.asm` for the first time, surfacing a latent `sbc`→`sbb`
NASM-syntax error in SubBCD (fixed).

**Price.** `GetItemPrice` indexes the flat `ItemPrices` table for regular items
(`ItemPrices + 3*(id-1)`, big-endian BCD → hItemPrice) and tail-calls
`GetMachinePrice` for TMs/HMs (id ≥ HM01; HMs are priceless and leave hItemPrice
untouched). pret's ROM-bank juggling and the `wListMenuID == MOVESLISTMENU`
price-by-move special case are bank/UI concerns and dropped. `gen_items.py` now
emits `TechnicalMachinePrices` (50 TM prices in thousands, nybble-packed two-per-
byte high-first, matching rgbds `nybble_array`); `HM01`/`TM01` added to
gb_constants.inc.

### Validation

Native ELF32 + `gcc -m32`, 14 checks all pass: GetItemPrice for Poké Ball (200),
Ultra Ball (1200), Master Ball (0), TM01 (3000), TM02 (2000), priceless HM01
(hItemPrice untouched); subtract afford/can't-afford/exact (CF + money); add
normal + 999999 overflow saturation. Full `make SKIP_TITLE=1` links with the three
item files + shared compare.asm/bcd.asm wired into `ITEMS_SRCS`.

---

## Bag TOSS confirmation: in-window YES/NO menu (bag_menu.asm)

- **Source:** engine/items/item_effects.asm (TossItem_ confirm flow), home/item.asm
- **Translated:** `dos_port/src/engine/menus/bag_menu.asm`
- **Date:** 2026-06-26
- **H-flag:** Not involved.
- **Bug tags:** None.

### Summary

The bag's TOSS already had a quantity chooser + key-item guard + a direct
`RemoveItemFromInventory_` call ("logic complete"). This adds the missing
confirmation UI: a reusable in-window **YES/NO two-option menu** (`.yes_no_menu` /
`.draw_yes_no`) — a small bordered box drawn into the bag's window (wTileMap →
GB_TILEMAP1), UP/DOWN to move the ▶ cursor, A confirms, B = NO, default YES (top).
The `.render` copy loop was factored into a reusable `.copy_window` the menu shares.

Toss flow now: choose quantity → "THROW AWAY?" prompt + YES/NO → YES removes the
items, NO/B returns to the list. Selecting a key item or HM (which can't be tossed)
now shows a "TOO IMPORTANT!" notice (`.key_item_notice`) instead of the previous
silent no-op. Strings are inline charmap glyphs (letters $80+(c-'A'), '?'=$E6,
'!'=$E7), matching the existing `bm_str_cancel` pattern.

The USE branch remains deferred (most item effects are battle/UI coupled).

### Validation

Visual via the deterministic FRAME.BIN harness: `DEBUG_BAGMENU` confirms the list
still renders after the `.copy_window` refactor (no regression), and the new
`DEBUG_BAGMENU_CONFIRM` flag overlays the prompt + YES/NO box — verified the box,
border, "YES"/"NO" labels, cursor, and "THROW AWAY?" prompt render correctly over
the bag list. Production `make SKIP_TITLE=1` builds clean.

---

## 2026-06-26 — Battle Stage 9: wild-encounter generation (`LoadWildData`, `TryDoWildEncounter`)

Battle engine plan, Stage 9. New generator `tools/gen_wild_encounters.py` parses
`data/wild/` (the `WildDataPointers` order, the per-map `def_grass_wildmons` /
`def_water_wildmons` blobs, and `probabilities.asm`) and emits
`assets/wild_data.inc`: a flat `dd` `WildDataPointers` table (249 = NUM_MAPS,
mirroring the port's EvosMovesPointerTable pointer model), 60 unique map blobs
(`[grass_rate (+20 mon bytes iff !=0)][water_rate (+20 iff !=0)]`, species names
resolved to internal indices via `pokemon_constants.asm`), and the 10-entry
`WildMonEncounterSlotChances` cumulative table. Exposed by `src/data/wild_data.asm`.

`LoadWildData` (`src/engine/overworld/wild_mons.asm`) — faithful port of
`engine/overworld/wild_mons.asm`. Indexes `WildDataPointers[wCurMap]` (flat ×4),
reads the grass rate, copies 20 grass-mon bytes to `wGrassMons` (flat→WRAM inline
loop, since CopyData biases the source by EBP and the table is flat), then the
water rate + 20 water bytes. Preserves the faithful no-clear behaviour: a rate-0
section leaves the prior map's mon buffer untouched.

`TryDoWildEncounter` (`src/engine/battle/wild_encounters.asm`) — faithful port of
`engine/battle/wild_encounters.asm`. Gate bytes → standing-tile grass/water rate
select → `hRandomAdd` rate compare → `WildMonEncounterSlotChances` slot walk with
`hRandomSub` → species/level pick → repel check. Returns Z = encounter. The
overworld helpers (door/warp, just-outside-map, repel text) are deferred externs
(the overworld step *trigger* is the consumer), and the player-standing-tile read
is a `; TODO-OVERWORLD` placeholder (the port's 40-wide viewport differs from the
GB's 20-wide centred screen).

### Validation

Freestanding ELF32 harnesses (link the real `wild_data.o`; stub the overworld
externs). `LoadWildData`: PALLET all-zero, ROUTE_1 rate 25 / mons [3,36(PIDGEY),
4,36], ROUTE_19 water rate 5 / mons [5,24(TENTACOOL),…], plus the stale-retention
case. `TryDoWildEncounter`: rate-fail no-encounter; grass slot 0/1 → PIDGEY L3/L4;
water slot 0 → TENTACOOL L5; repel blocks (wild<lead) with step 3→2; indoor rate-0
no-encounter. All exact. Added `gcc-multilib` + `nasm` to the fresh container.

---

## 2026-06-26 — Battle Stage 5: stat-stage modifier effects (`StatModifierUpEffect` / `StatModifierDownEffect`)

Battle engine plan, Stage 5. Faithful translation of `engine/battle/effects.asm`'s
two stat-stage move-effect handlers into `src/engine/battle/stat_mod_effects.asm`,
with all their flow-control helpers (UpdateStat/UpdateStatDone, RestoreOriginal-
StatModifier, PrintNothingHappenedText, UpdateLoweredStat/Done, CantLowerAnymore
[_Pop], MoveMissed). Wired into BATTLE_SRCS.

The handlers bump the relevant stat-mod by ±1/±2 (clamped to the 1..13 stage
range — can't pass +6 or −6) and recompute the affected battle stat from the
unmodified stat via `StatModifierRatios` (the HRAM Multiply/Divide contract,
capping at 999 / flooring at 1, and reverting the mod bump when the stat is
already 999). Care points carried over faithfully: the `hProduct+2 == hMultiplicand+1`
overlap the GB relies on for the 999-cap write; the big-endian stat-pointer
arithmetic; the `StatModifierRatios` entry index = mod−1; the down-effect's
enemy-turn 25%/side-effect 33% rolls (`× $ff / 100` ⇒ 64 / 85).

The presentation tail — PrintStatText, PlayCurrentMoveAnimation(2), the
substitute/minimize Bankswitch dance, and the rose/fell/nothing-happened text —
is the deferred battle front end (declared `extern`, like the move_effects/*
files), so the file assembles (and all BATTLE_SRCS assemble) but does not yet link
into the EXE. `ApplyBadgeStatBoosts` (the third routine the Stage-5 plan line
names) was already done + validated earlier. There is no `GetStatMod` in pret; the
"unmodified-stat recompute helpers" the plan referenced are this inline recalc.

### Validation

Freestanding ELF32 harness linking the **real** Multiply/Divide + StatModifierRatios
(battle_data.o), stubbing the UI externs. Six cases, all exact: Up Atk +1 → mod 8 /
stat 150 (100×1.5); Up Atk +2 → mod 9 / 200; Up at mod 13 → no-op, stat untouched;
Up with stat already 999 → mod bump reverted; Down Atk −1 → mod 6 / 66 (100×0.66);
Down to mod 1 with unmod 1 (0.25×→0) → floored to 1.

---

## 2026-06-26 — Battle Stage 7: HandleBuildingRage

Battle engine plan, Stage 7 (one of the named remaining items). Faithful translation
of `engine/battle/core.asm:HandleBuildingRage` into `src/engine/battle/building_rage.asm`.
When the mon being attacked is under Rage, it flips hWhoseTurn, temporarily rewrites
the target's move to a null move with ATTACK_UP1_EFFECT, calls `StatModifierUpEffect`
(the new Stage-5 routine) to raise its Attack one stage, then restores the Rage move
number and the turn flag. PrintText/BuildingRageText are the deferred front end (extern).

Validated natively end to end (links the real StatModifierUpEffect + Multiply/Divide
+ StatModifierRatios): raging enemy-turn case → player Attack mod 7→8, stat 100→150,
wPlayerMoveNum restored to RAGE (63) / effect cleared / hWhoseTurn restored; no-op when
the target isn't raging or its Attack mod is already +6 (13). Wired into BATTLE_SRCS.

---

## 2026-06-26 — Battle: GetCurrentMove (move-record load backend)

Battle engine plan (a listed deferred backend item). Faithful translation of
`engine/battle/core.asm:GetCurrentMove` into `src/engine/battle/get_current_move.asm`.
Loads the selected move's 6-byte record (anim, effect, power, type, accuracy, pp)
from the flat `Moves` table into wPlayerMove*/wEnemyMove*, picked by hWhoseTurn,
including the debug TestBattle forced-move override. Like LoadWildData, it indexes
the flat table (esi = Moves + (id-1)*MOVE_LENGTH) and copies flat→WRAM inline,
since the port's FarCopyData/CopyData bias the source by EBP (for GB WRAM) whereas
Moves is a flat program-image table. wNameListIndex is set (the non-UI half); the
GetMoveName name fetch is the deferred UI tail.

This is the move-record load `MoveHitTest`, `CalculateDamage`, and the trainer-AI
move-scoring (`ReadMove`) all consume — so it unblocks the AI layer. Wired into
BATTLE_SRCS. Native-validated (links the generated Moves table): player move 1 →
[01,00,28,00,FF,23] + wNameListIndex 1; enemy move 2 → [02,00,32,00,FF,19];
TestBattle-forced move 3 → [03,1D,0F,00,D8,0A]. All exact.

---

## 2026-06-26 — Script engine Stage 5: RunMapScript dispatch skeleton

Script engine plan, Stage 5 (+ Stage 6 stub conventions). New
`tools/gen_map_scripts.py` → `assets/map_scripts.inc`: `MapScriptPointers`, a
flat `dd` table (249 = NUM_MAPS) indexed by `wCurMap`, each entry a map's `_Script`
(default `DefaultMapScript`, a no-op), with a `SCRIPT_OVERRIDES` registry naming the
ported maps (currently `PALLET_TOWN → PalletTown_Script`) — the same flat-pointer +
registry pattern as WildDataPointers and gen_npc_dialogs' SCRIPT_OVERRIDES. Exposed
by `src/data/map_scripts.asm`.

`RunMapScript` (`src/engine/overworld/run_map_script.asm`) — faithful translation of
home/overworld.asm:RunMapScript: runs the current map's `_Script` each overworld
frame via `MapScriptPointers[wCurMap]`. Boulder push / dust animation,
`RunNPCMovementScript` (already called at the top of OverworldLoop), and
`SwitchToMapRomBank` are deferred (no-op, see header). `CallFunctionInTable` is the
flat-`dd` port of home/scripting.asm:CallFunctionInTable (16-bit table → flat dd,
index ×4) that every map `_Script` uses to dispatch on its current-script index.
Wired into `OverworldLoop` (one `call RunMapScript` after `RunNPCMovementScript`).

`PalletTown_Script` (`src/scripts/pallet_town.asm`) — faithful skeleton of
scripts/PalletTown.asm:PalletTown_Script: the `EVENT_GOT_POKEBALLS_FROM_OAK` →
`EVENT_PALLET_AFTER_GETTING_POKEBALLS` event-gate, then `CallFunctionInTable` on
`wPalletTownCurScript` over `PalletTown_ScriptPointers` (flat dd, 10 states). The
cutscene states (Oak walk-up, Pikachu battle, Daisy) are recorded stubs
(`; STUB(battle,misc)`) deferred to the movement + battle milestone; state 0's Oak-
intro trigger is a `; STUB(misc)` no-op so the player moves freely.

### Validation

Freestanding ELF32 harness (links the real RunMapScript + CallFunctionInTable +
MapScriptPointers + PalletTown_Script; stubs ShowTextStream): CallFunctionInTable
dispatches index 0/1/2 to the matching routine; the Pallet event-gate sets
EVENT_PALLET_AFTER only when GOT_POKEBALLS is set; RunMapScript dispatches through
all 10 Pallet states and returns cleanly; a default map (ROUTE_1) → DefaultMapScript
no-op leaves scratch untouched. Script bundle partial-links (only ShowTextStream
external); overworld.asm assembles with the new call.

---

## 2026-06-26 — Script engine: EnableAutoTextBoxDrawing + faithful DefaultMapScript

Faithful translation of home/text.asm:EnableAutoTextBoxDrawing /
DisableAutoTextBoxDrawing (src/text/auto_textbox.asm): set wAutoTextBoxDrawingControl
(bit BIT_NO_AUTO_TEXT_BOX) and clear wDoNotWaitForButtonPressAfterDisplayingText.
Used by map _Scripts (and the wild-encounter repel message). Made the script
dispatch faithful: DefaultMapScript is now `jmp EnableAutoTextBoxDrawing` (most pret
map scripts that do nothing else are exactly that), and PalletTown_Script calls it
before CallFunctionInTable, matching pret. Added the two WRAM aliases +
BIT_NO_AUTO_TEXT_BOX; wired into GAME_SRCS. Native-validated: RunMapScript on a
default map sets wAutoTextBoxDrawingControl to 0 (auto-draw on).

---

## 2026-06-27 — Move data layer: names dispatcher, category helper, field moves

Covers move-data-plan Stages 3–5 (`docs/current_plan_moves.md`).

### Names (Stage 3) — `src/home/names.asm`
Faithful merge of `home/names.asm` + `home/names2.asm`. `GetName` dispatches on
`wNameListType` through a flat `NamePointers` `dd` table (**mixed addressing**:
Monster/Move/Unused/Item/Trainer names are flat data pointers walked via `[esi]`;
`wPartyMonOT`/`wEnemyMonOT` are WRAM, walked via `[ebp+esi]`). `MONSTER_NAME` →
`GetMonName` (fixed-width `AddNTimes`, faithful to pret — mon names stay fixed-width
by design); name types 2–7 walk `$50`-terminated source strings and `CopyData` a
**bounded** `NAME_BUFFER_LENGTH` (20) into `wNameBuffer`. Wrappers `GetMoveName`/
`GetItemName`/`GetMachineName`. `BUG` tag on the `cp HM01` machine-name branch (pret
`names2.asm:22`, range-guarded) and a `GLITCH` tag on the bounded name-walk
(out-of-range ids walk garbage source but the 20-byte destination copy can't
overflow → no ACE); `%if BUG_FIX_LEVEL >= 2` adds an index-validation placeholder.

### Category helper (Stage 4) — `src/engine/battle/move_category.asm`
`IsTypeSpecial` (AL = type id) and `IsMoveSpecial` (AL = move id; reads `MOVE_TYPE`
from the flat `Moves` table). Both return AL=1/CF=1 for special, AL=0/CF=0 for
physical — the `cp SPECIAL` / `jae` split pret uses inline in `core.asm`. Native-
validated (POUND → physical, FIRE PUNCH → special).

### Field moves (Stage 5) — `tools/gen_field_moves.py`, `src/engine/menus/field_moves.asm`
`gen_field_moves.py` emits `assets/field_moves.inc`: `FieldMoveDisplayData` (3-byte
records: move id, `FieldMoveNames` index, leftmost tile col; `$FF`-terminated) and
`FieldMoveNames` (`@`-terminated, 1-based index order) from
`data/moves/field_moves.asm` + `field_move_names.asm`, resolving move ids from
`constants/move_constants.asm`. `IsFieldMove` (AL = move id) is the linear scan from
pret `engine/menus/text_box.asm:GetMonFieldMoves` `.fieldMoveLoop`: walk the
`$FF`-terminated table, on a match take the 1-based name index and skip that many
`@`-terminated strings → CF=1 + flat `FieldMoveNames` pointer (CF=0/EAX=0 otherwise);
preserves EBX/ECX/EDX/ESI so party_menu's slot loop keeps its live registers.
`party_menu.asm` was rewired off its inline `MV_*` equ block, baked `fm_str_*`
strings, and `.field_move_name` cmp-chain to call `IsFieldMove` + the shared tables.
Lives in GAME_SRCS (linked) because party_menu calls it and `battle_data.asm`
(BATTLE_SRCS) is not yet linked. Native ELF32 harness: CUT/SOFTBOILED/FLASH → name,
POUND → not-found, ANIM_B4 → empty (unused slot); encoded name bytes byte-identical
to the removed baked strings; `DEBUG_PARTYMENU` `FRAME.BIN` party list unchanged.
`GetMonFieldMoves` (the `wFieldMoves[]` array fill) deferred — no caller yet and it
needs the not-yet-pinned `wFieldMoves` union WRAM aliases (see the plan).

### Effect-category arrays (Stage 6) — `tools/gen_effect_categories.py`
`gen_effect_categories.py` emits `assets/effect_categories.inc` from `data/battle/`:
`ResidualEffects1`, `ResidualEffects2`, `SpecialEffects` + `SpecialEffectsCont`
(the original's fallthrough with a single `$FF` terminator), `AlwaysHappenSideEffects`,
`SetDamageEffects` — each a `$FF`-terminated byte list of move-effect ids, resolved
from `constants/move_effect_constants.asm` (handles `const_def`/`const`/`const_skip`).
Exposed as globals via `battle_data.asm` (BATTLE_SRCS, not yet linked). DATA ONLY —
no `MoveEffectPointerTable`, whose handler pointers would dangle until the effect
handlers are ported. The battle engine scans these linearly to classify a move's
effect (residual / special / always-happens-on-faint / sets-damage).

### PlayMoveAnimation stub (Stage 7) — `src/engine/battle/animations.asm`
Faithful skeleton of pret `engine/battle/animations.asm:MoveAnimation`'s
`.moveAnimation` decision. Only the strictly-needed branch is implemented: when
battle animations are OFF in the options (`bit BIT_BATTLE_ANIMATION, [wOptions]`
set), substitute a flat 30-frame `DelayFrames` so message pacing matches the
original. With animations ON the real playback (ShareMoveAnimations + PlayAnimation
+ PlayApplyingAttackAnimation screen shake) is a `; TODO-HW:` no-op deferred to the
battle-animation HAL. Added `BIT_BATTLE_ANIMATION`(=7)/`BIT_BATTLE_SHIFT`(=6) and a
`wOptions` pret-name alias (= `W_OPTIONS` = `$D354`) to `gb_memmap.inc`. In
BATTLE_SRCS; `make check` + full `SKIP_TITLE=1` link clean.

**Move data layer plan (`docs/current_plan_moves.md`) complete** — archived to
`docs/plans/moves.md`.

---

## Wave 1 — Unblocked Backend (headless, native-ELF32-validated)

Branch `wave1-battle-backend`. Parallel sonnet subagents authored each dedicated
.asm + native harness; orchestrator (opus) audited + integrated serially.

### Bill's PC box logic — `src/engine/pokemon/bills_pc.asm` (task 1)
Faithful port of pret `engine/pokemon/bills_pc.asm`: `KnowsHMMove`,
`BillsPCDepositLogic` (fail if party≤1 / box full → `_MoveMon` PARTY_TO_BOX +
`_RemovePokemon` from party), `BillsPCWithdrawLogic` (fail if box empty / party
full → `_MoveMon` BOX_TO_PARTY [CalcStats recompute] + `_RemovePokemon` from box),
`BillsPCReleaseLogic`. Audit vs draft: externs corrected `MoveMon`/`RemovePokemon`
→ `_MoveMon`/`_RemovePokemon`; `push/pop bx`→`ebx`; redundant local %defines
dropped for the gb_constants includes; a local `IsInArray` added (array.asm lacks
it). Gen-2 forward-compat: MON_CATCH_RATE (offset 7) preserved by deposit (copies
33B verbatim) and withdraw (CalcStats starts at MON_STATS=$22) — verified in
harness. Native ELF32: 24/24 assertions (HM detection, deposit/withdraw/release
success+fail paths, counts, species list, offset-7 retention). **Check-only**
(POKEMON_CHECK_SRCS): not linked — needs a link-ready `_MoveMon` (the `add_mon.asm`
draft has a duplicate `AddPartyMon_WriteMovePP` + extern-constant errors). PC menu
UI deferred.

### JumpMoveEffect dispatch seam — `src/engine/battle/effects.asm` (task 6)
Faithful port of pret `engine/battle/effects.asm` (`JumpMoveEffect`/`_JumpMoveEffect`)
+ `data/moves/effects_pointers.asm` (`MoveEffectPointerTable`). Reads `hWhoseTurn`
→ selects `wPlayerMoveEffect`/`wEnemyMoveEffect`, `dec`→×4 index into an 86-entry
flat `dd` table, `jmp dword [esi]` tail-call (handler `ret` → `mov bh,1; ret`).
pret `dw` (16-bit bank-relative) → `dd` (32-bit flat); index ×2 → ×4. A NASM `%if`
arity guard `%fatal`s on table drift from 86 entries. 14 handlers wired
(StatModifierUp/Down, PayDay_, Conversion_, Haze_, OneHitKO_, Mist_, FocusEnergy_,
Recoil_, Heal_, Paralyze_, LeechSeed_, + DrainHP_ at $03/$08 after promoting
`DrainHPEffect_` to `global` in drain_hp.asm); the remaining ~72 effects route to a
shared `UnportedMoveEffect` no-op (header lists each + its pret handler for Wave 2).
Native ELF32: 17/17 dispatch tests (index math, player/enemy path, first/last
boundary, BH=1 postcondition, Unported no-clobber). BATTLE_SRCS (check-only, not
linked until the Wave-2 loop calls it).

### Residual damage — `src/engine/battle/residual_damage.asm` (task 2)
Faithful port of pret `engine/battle/core.asm` `HandlePoisonBurnLeechSeed`
(+`_DecreaseOwnHP`/`_IncreaseEnemyHP`). End-of-turn Poison/Burn = 1/16 maxHP
(min 1); Toxic multiplies by an escalating counter; Leech Seed drains the seeded
mon and heals the opposing mon (overheal clamped to maxHP). Two pret glitches
carried (no BUG_FIX_LEVEL guard, neither independently fixable): the Leech-Seed +
Toxic counter interaction (counter bumped per DecreaseOwnHP call, incl. the Leech
path) and the overkill heal (BX uncapped when HP < drain). Deferred UI externs
(stubbed in the harness): PrintText, PlayMoveAnimation, DrawHUDsAndHPBars,
DelayFrames, UpdateCurMonHPBar (must preserve BX), HurtBy{Poison,Burn,LeechSeed}Text.
Aliases added in PREP: wAnimationType/wPlayerToxicCounter/wEnemyToxicCounter,
ABSORB/BURN_PSN_ANIM. Native ELF32: 10/10 (poison/burn 1/16+min-1, toxic
escalation, overkill, leech drain+heal, overheal clamp, faint/alive flags, 16-bit
maxHP, enemy-turn heal). BATTLE_SRCS check-only.

### GainExperience — `src/engine/battle/experience.asm` (task 4)
Audited + fixed the battle-side EXP draft (NOT the pokemon-side CalcExperience,
which was already done). 10 fixes vs the swarm draft: hExperience→H_EXPERIENCE;
wPlayerID/wCalculateWhoseStats added to includes; PIKAHAPPY_LEVELUP/
LEVEL_UP_STATS_BOX defined; FlagActionPredef→FlagAction at all 4 sites (the predef
variant clobbers ESI via GetPredefRegisters); `dec esi`→`sub esi,2` in the max-EXP
overwrite path (reach the high byte at MON_EXP, not the middle); CopyData dest is
EDX not EDI; CallBattleCore `call BattleCore`→`call esi; ret` (flat function-pointer
dispatch); full extern decls. Headless math (stat-exp gain w/ 0xFFFF cap, exp award
×baseExp×level/7, BoostExp ×1.5, DivideExpDataByNumMonsGainingExp) native-validated
6/6. Deferred Wave-2 externs: PrintText, GetPartyMonName, LoadMonData,
ModifyPikachuHappiness, PrintStatsBox, WaitForTextScrollButtonPress,
Save/LoadScreenTilesFromBuffer1, PrintEmptyString, LearnMoveFromLevelUp, and the
CallBattleCore targets (CalculateModifiedStats, ApplyBurnAndParalysisPenalties-
ToPlayer, ApplyBadgeStatBoosts, DrawPlayerHUDAndHPBar). BATTLE_SRCS check-only.

### Trainer AI + read_trainer_party — `src/engine/battle/{trainer_ai,read_trainer_party}.asm` (task 3)
trainer_ai.asm: AIEnemyTrainerChooseMoves, AIMoveChoiceModification1/2/3/4 +
AIMoveChoiceModificationFunctionPointers (flat dd), TrainerClassMoveChoiceModifications,
StatusAilmentMoveEffects, ReadMove, TrainerAI/TrainerAIPointers (dd 5B/entry vs pret
dbw), AICheckIfHPBelowFraction/AICureStatus/DecrementAICount; AIUseX*/AIRecoverHP/
switch actions with UI parts stubbed as local no-ops. SM83 `ret z/nz`→`jnz/jz+ret`;
`~(1<<BADLY_POISONED)` byte mask. **AUDIT (orchestrator): the draft's item-id equs
were WRONG** (SUPER_POTION/FULL_RESTORE/GUARD_SPEC/DIRE_HIT/X_* off); replaced with
correct constants/item_constants.asm values in gb_constants.inc (X_ACCURACY_ITEM→
X_ACCURACY). read_trainer_party.asm: ReadTrainer — link-battle skip, flat/special
level blob parse, SpecialTrainerMoves override loop, prize-money via AddBCDPredef
(stubbed). Both native-validated (7/7 + 3/3; item-use branches not exercised — hence
the audit). BATTLE_SRCS check-only. DEFERRED (reported): `TrainerDataPointers` +
`SpecialTrainerMoves` need a `tools/gen_trainer_parties.py` generator + a
battle_data global; `AddBCDPredef` needs the predef BCD adder. Aliases added:
12 WRAM (wAICount/wAIItem/wBuffer/wEnemyMon1*/wTrainer*/…) + EFFECT_01/
XSTATITEM_DUPLICATE_ANIM/NUM_TRAINERS + 10 item ids.

### Evolution + level-up move learning — `src/engine/pokemon/evolution.asm` (task 5)
Authored by the (killed) sonnet subagent; completed + audited + validated by the
orchestrator. Routines: TryEvolvingMon, EvolutionAfterBattle, EvolveMon (UI stub),
RenameEvolvedMon, CancelledEvolution, LearnMoveFromLevelUp, GetMonLearnset_Evo[_BlobStart].
**Orchestrator fixes:**
1. Include paths `dos_port/include/...` → `gb_memmap.inc`/`gb_constants.inc` (the
   documented swarm bug; only "assembled" before because it was tested from repo root).
2. **Real flag bug in LearnMoveFromLevelUp**: `cmp al,bh` (level match) was followed
   by `mov al,[esi]` + `inc esi` before `jne` — x86 `inc` clobbers ZF (SM83 `inc hl`
   does not), so the level compare was destroyed and NO move was ever learned. Fixed
   `inc esi`→`lea esi,[esi+1]` (flags-preserving). This was the killed agent's
   unresolved "Test 5" failure (its own harness also linked a STUB EvosMovesPointerTable,
   masking the data path).
3. Exported GetMonLearnset_Evo_BlobStart (global) for reuse/validation.
**Native ELF32 (real pokemon_data.o table, 3/3):** GetMonLearnset_Evo_BlobStart(Bulbasaur
=0x99) → evo entry [EVOLVE_LEVEL,16,IVYSAUR=0x09] (i.e. Bulbasaur L16→Ivysaur);
GetMonLearnset_Evo → learnset start [7,LEECH_SEED]; LearnMoveFromLevelUp@L13 → Vine Whip
written to the empty slot.
**KNOWN BUG deferred to Wave 2 (documented in-file):** EvolutionAfterBattle's
evolution-success path has a stack imbalance (double-pop consumes the function-saved
DE; species write uses a wrong pointer). It only triggers on an actual evolution,
which needs the deferred deps (FlagActionPredef/LoadMonData_/CalcStats) — so it's
unvalidated and must be fixed+validated end-to-end in Wave 2.
POKEMON_CHECK_SRCS (check-only): evolution depends on GetName (check-only names.asm),
FlagActionPredef, and pikachu, so it isn't linked into the EXE yet.

### Sprite decompressor — `src/gfx/uncompress.asm` (Wave 2, Stage 1c-i, 2026-06-29)
Faithful 1:1 port of `home/uncompress.asm` (the runtime SM83 sprite decompressor):
UncompressSpriteData/`_UncompressSpriteData`/UncompressSpriteDataLoop,
MoveToNextBufferPosition, WriteSpriteBitsToBuffer, ReadNextInputBit/Byte, UnpackSprite,
SpriteDifferentialDecode, DifferentialDecodeNybble, XorSpriteChunks, ReverseNybble,
ResetSpriteBufferPointers, UnpackSpriteMode2, StoreSpriteOutputPointer + the 5 const
tables. Decodes the RLE + length-encoded bit stream into two column-major 1bpp planes
(sSpriteBuffer1/2), then differential-decodes / XOR-merges per the stream's unpack mode.
Ported faithfully (not a build-time PNG→2bpp shortcut) so Gen-1 sprite/ACE glitches that
depend on the decoder's behavior on malformed data survive (user directive 2026-06-28).
**Control-flow fidelity:** the GB ends its "endless" decode loop by popping the loop's
return address off the stack (`MoveToNextBufferPosition .allColumnsDone: pop hl`); the
port keeps this verbatim as `pop esi`, so the coupled cluster (`_UncompressSpriteData`,
the Loop, MoveToNext, UnpackSprite, SpriteDifferentialDecode, XorSpriteChunks,
UnpackSpriteMode2) carries **no register-saving prologue** — durable state lives in the
WRAM vars, registers are transient (GB model). Leaf helpers are balanced.
**Addressing:** GB state ($D0A0+ scratch), the input stream, and the 3 sprite buffers
($A188/$A310) are EBP-relative; the const decode/reverse/offset tables are flat `.data`;
the per-call differential table is held in flat 32-bit `.bss` selectors `sp_dtbl0/1`
(the 16-bit `wSpriteDecodeTable*Ptr` GB vars can't hold a flat address — left unused).
**Native byte-exact validation (`gcc -m32` harness):** an asm shim sets EBP=GB base and
calls UncompressSpriteData; the harness reassembles buffer1(even)/buffer2(odd) +
`transpose_tiles` exactly as `tools/pkmncompress.c` does, then compares to the canonical
`.2bpp`. **353/353 committed pics byte-exact** — front 153, back 151, trainers 46,
battle 3 — covering all unpack modes (0/1/2) and both plane orders. The flipped path
(back pics) runs deterministically; its byte-exact check belongs to Stage 1c-ii, where
`InterlaceMergeSpriteBuffers`'s nybble-swap completes the horizontal flip. Linked via
FRONTEND_SRCS (only extern = FillMemory). Note: `pkmncompress -u <pic>` == the committed
`.2bpp` (verified), so it is the canonical decode oracle. Harness is ephemeral (scratchpad).

### Mon-pic merge/scale + placement — `src/gfx/pics.asm` (Wave 2, Stage 1c-ii, 2026-06-29)
Ports home/pics.asm (LoadUncompressedSpriteData, AlignSpriteDataCentered, ZeroSpriteBuffer,
InterlaceMergeSpriteBuffers) + engine/battle/scale_sprites.asm (ScaleSpriteByTwo and helpers
ScaleFirstThreeSpriteColumnsByTwo / ScaleLastSpriteColumnByTwo / ScalePixelsByTwo +
DuplicateBitsTable). Pairs with the validated decoder (uncompress.asm): front pics are
centered in a 7x7 buffer (AlignSpriteDataCentered), back pics are 2x-scaled from 4x4→7x7
(ScaleSpriteByTwo); both then InterlaceMergeSpriteBuffers interleaves the two 1bpp planes
(buffer0=MSB, buffer1=LSB) into the 2bpp sprite, nybble-swaps if wSpriteFlipped, and the
port copies the 49 tiles (784 B) from sSpriteBuffer1 to VRAM + sets g_tilecache_dirty.
**Placement:** the battle BG uses SIGNED tile addressing (LCDC bit4=0), so tile IDs $00-$7F
map to VRAM $9000-$97F0; PlacePicTilemap fills a 7x7 W_TILEMAP block column-major (ID =
base + col*7 + row), matching the merged buffer's tile order (faithful to
CopyUncompressedPicToTilemap). Enemy front pic → VRAM $9000 (tile $00), canvas (22,3);
player back pic → VRAM $9310 (tile $31), canvas (11,8). The back pic's tile range $31-$61
(VRAM $9310-$961F) abuts the HP-bar tiles at $9620; the 2-tile overlap at IDs $60/$61 hits
only the box set's unused font_extra glyphs, so it is cosmetically safe. **Verified:**
FRAME.BIN renders a full faithful battle screen (Pidgey front + Pikachu back) — user
signed off both sprites. Test stubs (DrawEnemyFrontPic_Stub/DrawPlayerBackPic_Stub) embed
pidgey/pikachub .pic via incbin and are driven from the DEBUG_BATTLE harness; the real
species→pic-pointer path is a Stage 2/3 data-layer task. Wired into FRONTEND_SRCS.

### Enemy turn + wild AI + wild moveset generation (Wave 2, Stage 2b, 2026-06-29)
Three linked pieces extending the player-attack path into a full battle round.

**Enemy turn** (`src/engine/battle/battle_menu.asm`): `ExecutePlayerTurn` is now a full-round
handler — choose the enemy move (`SelectEnemyMove`), order the two battlers by speed
(player first if wBattleMonSpeed >= wEnemyMonSpeed; Quick Attack/Counter priority + random
tie-break deferred), run the faster one's attack, and if its target faints the round ends
(no retaliation). New `DoEnemyAttackDamage` (mirror of `DoPlayerAttackDamage`: hWhoseTurn=1,
GetCurrentMove → GetDamageVarsForEnemyAttack → CalculateDamage → AdjustDamageForMoveType →
RandomizeDamage, drains wBattleMonHP), `RenderEnemyTurn` ("Enemy <nick> / used <move>!", the
faithful `<USER>`="Enemy "+nick on the enemy's turn per home/text.asm:PlaceMoveUsersName),
`ShowPlayerFainted`. Step helpers `PlayerAttackStep`/`EnemyAttackStep` return CF=1 on a
battle-ending faint. Accuracy/MoveHitTest still deferred (always hits); crit forced off.

**Wild AI** — `src/engine/battle/select_enemy_move.asm`: faithful port of
engine/battle/core.asm:SelectEnemyMove. The WILD random-move path (25% per slot, re-roll on
disabled/empty) is the whole enemy move choice AND the default stub for every opponent
(trainer-AI scoring `AIEnemyTrainerChooseMoves` deferred — both wild + trainer fall into
.chooseRandomMove). Forced-move early-outs (recharge/charge/thrash/freeze/sleep/trap/bide)
ret without choosing. Link path = TODO-HW (Phase 4). `percent` macro = n*$ff/100.

**Wild moveset generation** — `src/engine/battle/load_enemy_moves.asm` (`LoadWildMonMoves`):
faithful port of LoadEnemyMonData's `.copyStandardMoves`+`.loadMovePPs` — copy the 4 base
moves from the mon header (wMonHMoves), WriteMonMoves fills the level-up learnset
(assets/evos_moves.inc, already generated) up to the level, LoadMovePPs writes base PP.
Also ported `LoadMovePPs`/`AddPartyMon_WriteMovePP` into `src/engine/pokemon/write_moves.asm`
(flat-`Moves` PP read, like its daycare branch). Sets wCurPartySpecies (GetMonLearnset key)
+ wCurEnemyLevel + wPredefDE/HL for the two predef calls. NOTE (Gen 1): enemy PP is loaded
for parity but never decremented; TM/HM moves are not part of wild generation (player-only
learnset category). All three wired into FRONTEND_SRCS.

**Validation (headless DUMP.BIN via DEBUG_BATTLE_ENEMYHIT, a new scripted one-shot gate):**
PIDGEY ($24) L3 → wEnemyMonMoves=[GUST $10,0,0,0], wEnemyMonPP[0]=35 (GUST base PP);
SelectEnemyMove picks GUST; wEnemyMove*=[$10,$00,$28(40),$FF(100%)]; GUST deals 5 (STAB,
neutral) → player HP 11→6. Level-up fill proven at L13 → [GUST,SAND_ATTACK $1c,QUICK_ATTACK
$62,0], matching PidgeyEvosMoves. Live FRAME.BIN sign-off pending (enemy turn already
visually confirmed by the user).

### HP-drain animation — `src/engine/battle/battle_hud.asm` (Wave 2, Stage 2b, 2026-06-29)
The port's stride-agnostic stand-in for pret UpdateHPBar (engine/gfx/hp_bar.asm). The battle
HUD already replaces pret's tile-based DrawHPBar with draw_hp_bar/calc_hp_pixels (the 40-wide
canvas needs stride-agnostic drawing), so the animation replicates the BEHAVIOR rather than
porting DrawHPBar: `AnimateEnemyHPBar`/`AnimatePlayerHPBar` tick the displayed HP from a passed
old value (ECX) toward the final value in WRAM one unit at a time, redrawing the gauge on each
PIXEL change with a 2-frame DelayFrame wait (pret's cadence); the player HUD's "cur" digits tick
alongside via print_num3. Factored `hp_to_pixels` (HP value in EAX) out of calc_hp_pixels so the
loop can price an arbitrary ticking HP. Loop state kept in BSS so draw_hp_bar/print_num3/DelayFrame
clobbering can't corrupt it; the entries take registers. RenderPlayerTurn/RenderEnemyTurn reordered:
DrawBattleHUDs at PRE-attack HP → print "<mon> used <move>!" → DoXAttackDamage → animate the
defender's bar (so the gauge starts full and drains). A 0-difference (status move / miss) animates
nothing. User signed off the live drain.

### Battle terminal states (Stage 2c) — `src/engine/battle/battle_menu.asm` (Wave 2, 2026-06-29)
Clean win/lose termination so the battle loop ends instead of re-looping the menu forever. New
`wBattleOver` flag (0 ongoing / 1 win / 2 lose): ExecutePlayerTurn sets it from which side fainted
(PlayerAttackStep CF=1 → enemy fainted → win; EnemyAttackStep CF=1 → active mon fainted → lose),
DisplayBattleMenu's FIGHT path breaks its `jmp DisplayBattleMenu` loop when it is nonzero, and the
DEBUG_BATTLE_LIVE harness resets it at battle start, polls it after each menu turn, and on end calls
new `EndBattleScreen` (blank the canvas + present) as a clean terminal. DEFERRED: multi-mon
switch-in (any active-mon faint currently ends the battle as a loss — pret would prompt to send out
another party mon) and the real exit path — Stage 3 returns to the overworld and runs the victory
EXP screen (Wave-1 GainExperience). EndBattleScreen's blank canvas is the placeholder for that.
Live sign-off pending.

### Turn-order quirks (Quick Attack priority + speed-tie) — battle_menu.asm (Wave 2, Stage 2b, 2026-06-29)
Replaced ExecutePlayerTurn's speed-only ordering with the faithful pret order (engine/battle/
core.asm:.noLinkBattle): Quick Attack ($62) takes priority; Counter ($44) always moves last;
otherwise compare wBattleMonSpeed vs wEnemyMonSpeed (big-endian), with a 50/50 BattleRandom break
on a tie (`50 percent + 1` = 128). pret's internal-clock tie invert is link-battle only → TODO-HW
(Phase 4). Added QUICK_ATTACK to gb_constants.inc (COUNTER was already there). Observable in the
DEBUG_BATTLE_LIVE demo: when the random wild AI rolls QUICK ATTACK and the player picks a non-QA
move, "Enemy PIDGEY used QUICK ATTACK!" resolves before the player's move despite Pikachu being
faster. Live sign-off pending.

### FIGHT-menu cursor persistence — battle_menu.asm + init_battle.asm (Wave 2, Stage 2a polish, 2026-06-29)
Fidelity fix (user observation, confirmed vs pret): the FIGHT move-list cursor must remember the
last-highlighted move across move uses AND menu exits for the whole battle, cleared only at battle
start. pret keeps it in wPlayerMoveListIndex: MoveSelectionMenu (.menuset, core.asm:2645) inits the
cursor from it, and core.asm:2745 writes it on BOTH select (A) and back (B) — which is why backing
out preserves it too. The port previously hardcoded wCurrentMenuItem=0 in DrawMoveList every open
(always snapped to the first move). Now: DrawMoveList restores wCurrentMenuItem from
wPlayerMoveListIndex (clamped to the real move count); MoveSelectionMenu writes wPlayerMoveListIndex
= wCurrentMenuItem after WideHandleMenuInput (covers A and B); InitBattle clears wPlayerMoveListIndex
at battle start (it sits outside InitBattleVariables' clear block — a deliberate port-side clear).
wPlayerMoveListIndex was already aliased ($CC2E). Live sign-off pending.

### Battle intro: real mon name + blinking ▼ — init_battle.asm + battle_menu.asm (Wave 2, intro polish, 2026-06-29)
Intro polish (user, software-native battle-entry pass, order text→balls→slide). (1) intro text now
pulls the real mon name: "Wild <wEnemyMonNick>" / "appeared!" (faithful _WildMonAppearedText) instead
of the fixed "Wild POKéMON". (2) The intro is now actually SHOWN: it was drawn by InitBattle then
instantly covered by the menu; the live flow waits for A/B on it first (faithful PrintBeginningBattleText
pausing before the menu). (3) WaitForAPress now BLINKS the ▼ text-advance arrow (tile $EE) at the dialog
box's bottom-right interior (canvas 28,19), toggling vs space every ~20 frames — the port's take on
WaitForTextScrollButtonPress/HandleDownArrowBlinkTiming; applies to every battle text wait (intro/attack/
faint). New DEBUG_BATTLE_INTRO FRAME hook dumps the intro screen (verified: "Wild PIDGEY appeared!" + ▼).
Next: party-status pokéballs (DrawAllPokeballs) + a placeholder Bug Catcher trainer to test the enemy ball row.

### Battle-intro party pokéballs (OAM) — pokeballs.asm + sprite_oam.asm + battle_hud.asm (Wave 2, 2026-06-29)
Step 2 of the battle-entry polish (user: OAM sprites like pret, intro-only). New pokeballs.asm =
faithful DrawAllPokeballs/SetupPokeballs/PickPokeball/WritePokeballOAMData: balls.2bpp (ok/status/
fainted/empty) loads into the free OBJ tile area ($8000 tiles $00-$03), the party-status row is written
as OAM entries (PickPokeball: HP==0→fainted, status!=0→status, else ok; past count→empty), and a new
ppu helper PrepareStaticOAM fills render_sprites' DOS position tables straight from $FE00 (DOS=OAM-16/-8)
so the balls composite without the wSpriteStateData/PrepareOAMData path (update_oam is gated off in
battle). DrawBattlePokeballs sets IO_OBP0=$E4 + LCDCF_OBJ_ON; HideBattlePokeballs (HideSprites + clear
OBJ) hands off to the HP-bar HUD. Faithful sequencing: DrawBattleHUDs split into DrawEnemyHUD/DrawPlayerHUD;
InitBattle now draws only the enemy HUD (intro shows player balls, not the player HP bar), and the live
intro does DrawBattlePokeballs → WaitForAPress → HideBattlePokeballs before the menu draws the player HP bar.
Positions = pret OAM coords + the battle centering (+80,+24). Wild = player row only; trainer (wIsInBattle==2)
adds the enemy row at OAM entries 6-11. VERIFIED (DEBUG_BATTLE_INTRO FRAME histogram + PNG): 6 balls at the
player position, no player HP bar. Remaining: Bug Catcher test trainer (enemy ball row) + status-variety seed.

### Battle HUD frame tiles + persistent shelf — LoadHudTilePatterns + gen_battle_hud_inc.py (Wave 2, 2026-06-29)
Root-caused the "missing divider" the user flagged: pret's LoadHudAndHpBarAndStatusTilePatterns is TWO
loads — LoadHpBarAndStatusTilePatterns (font_battle_extra → $62, ported) AND LoadHudTilePatterns
(BattleHudTiles1 → vChars2 $6d, BattleHudTiles2+3 → $73), which OVERWRITE the font_extra "ID No."
placeholders at $73/$74 with the real HUD frame pieces ($73 vertical, $74/$77 corners, $76 line,
$78/$6f triangles). The port only ported the first load, so $73/$74 kept "ID No." (confirmed: generated
.inc == source .2bpp, so no generator/load bug — the tiles simply were never loaded). FIX (generator,
per project rule — never hand-edit tiles): new tools/gen_battle_hud_inc.py emits assets/battle_hud_2bpp.inc
from gfx/battle/battle_hud_{1,2,3}.png (1bpp expanded 1bpp→2bpp doubled, = FarCopyDataDouble); new
LoadHudTilePatterns (src/gfx/load_font.asm) loads tiles1 @ $6d and tiles23 @ $73; InitBattle calls it
after LoadHpBarAndStatusTilePatterns. Re-applied the faithful PlaceHUDTiles port (DrawEnemyHUDFrame/
DrawPlayerHUDFrame/place_hud_frame in battle_hud.asm). PERSISTENCE FIX (user): pret draws the player
shelf in BOTH the pokéball intro (SetupOwnPartyPokeballs) AND the HP-bar HUD (DrawPlayerHUDAndHPBar), so
it survives the send-out; the port now calls DrawPlayerHUDFrame from DrawPlayerHUD too. To give the shelf
its own row, the player HUD shifted up one row (name/lv/bar/frac canvas rows 10-13, +3 centering like the
enemy; shelf row 14) — the port previously used +4, colliding the frac with pret's shelf row. Also this
thread: intro text pulls the real mon name + blinking ▼ arrow (WaitForAPress); party pokéballs as OAM
sprites (pokeballs.asm + PrepareStaticOAM). User-signed-off live. Remaining: Bug Catcher enemy ball row +
fainted/status ball variety; darkened silhouette slide-in.

### Trainer sprite data generator — gen_trainer_pics.py + trainer_pics.asm (Wave 2, 2026-06-29)
Generated all trainer battle graphics up front (user, saves time before trainer battles).
New tools/gen_trainer_pics.py → assets/trainer_pics.inc: parses gfx/pics.asm (pic label → .pic
file, incl. bare-alias labels like ChiefPic reusing ScientistPic) + data/trainers/pic_pointers_money.asm
(class-ordered pic_money) → emits 45 unique `incbin "../gfx/trainers/*.pic"` blobs, TrainerPicPointers
(flat dd, 47 classes, index = trainer class - 1, mirroring pret TrainerPicAndMoneyPointers), and
TrainerBaseMoney (bcd3 prize money). The .pic blobs are the same compressed format uncompress.asm
already validated byte-exact on all trainers, so a class's sprite loads like a wild mon's front pic.
Tier-2 wrapper src/data/trainer_pics.asm (section .data + globals) wired into FRONTEND_SRCS; Makefile
assets rule + `make assets` dep added. Links clean (18 KB data). Consumer (trainer _LoadTrainerPic
path) is Stage 4 / the Bug Catcher test. assets/*.inc is gitignored→force-track on commit (git add -f).

### Battle-entry silhouette slide-in — SlideBattlePicsIn (pics.asm) + faithful init flow (Wave 2, 2026-06-29)
Software-native port of pret SlidePlayerAndEnemySilhouettesOnScreen (its per-scanline SCX raster
trick can't be expressed in the tile renderer; user OK'd a software-native slide). Restructured the
battle-entry flow to match pret _InitBattleCommon order: InitBattle split into setup/clear vs new
DrawBattleIntroBox (box + "Wild <nick> appeared!" + enemy HUD); pic stubs made decode-only (VRAM only).
SlideBattlePicsIn clears the canvas + redraws both decoded pic blocks (PlacePicSlide, clipped to the
40-wide canvas, column-major tile IDs) at shifted columns each frame — enemy front slides in from the
right (col 22+step), player back from the left (col 11-step), step 18→0, 2 frames each — under a
silhouette BGP ($FC: color 0→light, 1-3→dark), then restores normal BGP at the final position. Harness
flow now: InitBattle → decode pics → SlideBattlePicsIn → DrawBattleIntroBox → pokeballs → menu.
Silhouette color: TODO(palette) — faithful = CGB SET_PAL_BATTLE_BLACK (Phase 5); stopgap (user-OK'd)
forces dmg_palette shade 3 → RGB black during the slide (saved/restored), so non-transparent pixels go
true black. dmg_palette made global. User signed off the slide ("looks decent enough"); black-tweak live.

### Player battle sprites (slide-in trainer + send-out) — gen_trainer_pics.py + pics.asm (Wave 2, 2026-06-29)
Fix (user): the wild slide-in showed Pikachu on the player side, but faithfully the PLAYER TRAINER back
sprite slides in (pret LoadPlayerBackPic → RedPicBack); the mon's back pic only appears after send-out.
Added PlayerPicFront (gfx/player/red.pic) + PlayerPicBack (gfx/player/redb.pic) to gen_trainer_pics.py
(generated data, globals in trainer_pics.asm). For the test harness, DrawPlayerRedBackPic_Stub decodes the
Red back (redb.pic, embedded; 4x4 like a mon back → LoadMonBackPicToVRAM) to VRAM $31 for the slide;
DrawPlayerBackPic_Stub (Pikachu) now runs at the intro→battle transition as the send-out (straight VRAM
swap over the same $31-$61 tilemap block, no grow animation yet — simplified AnimateSendingOutMon).
Verified (FRAME): intro shows the Red/Yellow trainer back + wild PIDGEY (user signed off). Also added a
TODO(glitch) to uncompress.asm: real mons stay in their dims box, but the GB decoder can write past it for
glitch sprites (MissingNo) — not separately exercised (the port decoded all real pics byte-exact).

### Bug Catcher trainer test + player party-status balls — debug_dump.asm + pics.asm (Wave 2, 2026-06-29)
Test harness for the enemy pokéball row + ball-status variety (user). New DEBUG_BATTLE_TRAINER seed
(combine with DEBUG_BATTLE_INTRO/LIVE): wIsInBattle=2, wEnemyPartyCount=3 with status variety (mon0 ok,
mon1 fainted HP=0, mon2 statused) + player party variety (mon1 fainted, mon2 statused), and loads the Bug
Catcher trainer sprite (DrawBugCatcherPic_Stub — 7x7 front-style via LoadMonPicToVRAM; embedded for the
test, real path = generated TrainerPicPointers). DrawBattleIntroBox now draws the enemy HUD only for wild
(wIsInBattle==1); a trainer shows the enemy ball row instead. VERIFIED (FRAME): Bug Catcher + player-trainer
back + BOTH ball rows (enemy top Y41-47, player bottom Y105-111) with ok/fainted/status/empty tiles.
Known rough edges (noted): trainer intro text still "Wild <nick> appeared!" (should be "<class> wants to
fight!"); a live trainer battle needs the enemy send-out + AI (Stage 4). Send-out (user note): faithfully
the trainer slides OUT then the mon comes in — starter PIKACHU just slides (no ball/grow, Yellow special),
others get ball-throw+grow; port does a straight VRAM swap for now (TODO(send-out) in code).

### RUN flow — TryRunningFromBattle (Wave 2, Stage 3, 2026-06-29)
Wired the battle menu's RUN option (was a no-op stub that re-opened the menu). Faithful port of pret's
`TryRunningFromBattle` + `BattleMenu_RunWasSelected` (engine/battle/core.asm) into `battle_menu.asm`
(`RunWasSelected`/`TryRunningFromBattle`/`PrintRunLine`). Wild-mon escape odds:
`(playerSpeed*32) / ((enemySpeed/4) % 256)`, +30 per prior run attempt, vs a `BattleRandom` roll;
playerSpeed ≥ enemySpeed → guaranteed escape; (enemySpeed/4)%256==0 or quotient>255 → escape. Uses the
real `Multiply`/`Divide` HRAM pipeline (hMultiplicand/hProduct/hDividend/hDivisor/hQuotient) byte-for-byte.
Outcomes: escape → "Got away safely!" + `wBattleOver=3` (new "ran" terminal, ends the harness `.live`
loop via the same path as win/lose); wild fail → `wActionResultOrTookBattleTurn=1`, "Can't escape!", then
the enemy gets its free attack (may KO → loss); trainer (`wIsInBattle==2`) → "No! There's no / running from
a / trainer battle!" (3-line, single-spaced), no turn consumed → re-menu. New aliases pinned from
origin/symbols: `wNumRunAttempts`=$D11F, `hEnemySpeed`=$FF8D (2B). Ghost/safari/run/link "always-escape"
special cases omitted (unreachable in the wild/trainer harness — TODO if those battle types are added).
Assembles + links clean into PKMN.EXE (FRONTEND_SRCS). Harness seeds PIKACHU spd 40 ≥ PIDGEY spd 21 → RUN
reliably escapes; the can't-escape branch needs a faster enemy to exercise. GATE: awaiting live user sign-off.

### Victory EXP screen — wire GainExperience live (Wave 2, Stage 3, 2026-06-29)
On enemy faint (`ExecutePlayerTurn.enemyFainted`) the front end now runs the Wave-1 `GainExperience`
(validated EXP/stat-exp/level math) and shows "<nick> gained / N EXP. Points!" via wide_text
(`battle_menu.asm:BattleWonGiveExp` + `print_dec`; N = `wExpAmountGained`). To LINK the previously
check-only `experience.asm` into PKMN.EXE: moved it from BATTLE_SRCS → FRONTEND_SRCS, added
`flag_action.asm` (fixed its include path: `dos_port/include/...`→`gb_memmap.inc`, added gb_constants
for FLAG_TEST + GetPredefRegisters extern), and added `battle_exp_stubs.asm` — link-only `ret` stubs
for GainExperience's deferred UI/display externs (GetPartyMonName, PrintStatsBox, Save/LoadScreenTiles
ToBuffer1, PrintEmptyString, WaitForTextScrollButtonPress, ModifyPikachuHappiness, CalculateModified
Stats, DrawPlayerHUDAndHPBar, ApplyBadgeStatBoosts, ApplyBurnAndParalysisPenaltiesToPlayer,
LearnMoveFromLevelUp, LoadMonData, + GainExpPrintStub). `experience.asm`'s two deferred `call PrintText`
display sites now call `GainExpPrintStub` (no-op) — the port's PrintText is the stride-20 OVERWORLD
renderer and would corrupt the 40-wide battle canvas; the display is done by the front end instead.
LEVEL-UP DATA is still updated by the real CalcStats inside GainExperience; only the level-up DISPLAY
(stats box / "grew to level N" / move learn) is deferred (stubs). LATENT COLLISION documented: when the
level-up-display step wires the real ApplyBadgeStatBoosts/ApplyBurnAndParalysis/LearnMoveFromLevelUp
(check-only backend) in, the matching stubs here must be deleted. Harness seeds PIDGEY base stats + base
exp 55 + party-slot-0 gain flag; expected "PIKACHU gained 102 EXP. Points!" (55*13/7, wild=no boost).
Links clean (FRONTEND_SRCS). GATE: awaiting live user sign-off. NOTE: harness battle-mon (PIKACHU,
seeded directly) ≠ party slot 0 (SNORLAX L80, from DEBUG_PARTY) — the LoadBattleMonFromParty-deferred
gap; the displayed name is wBattleMonNick (PIKACHU) and the EXP number is enemy-derived, so both read
correct on screen even though slot 0 receives the points.

### Level-up display — grew-text + level-up stats box (Wave 2, Stage 3, 2026-06-29)
The deferred half of the victory flow. GainExperience's per-mon display tail now calls real front-end
routines instead of stubs (battle_menu.asm): ShowGainedExpText ("<nick> gained / N EXP. Points!", waits),
ShowGrewLevelText ("<nick> grew / to level N!", no wait — pret GrewLevelText), PrintStatsBox (the level-up
stats box: ATTACK/DEFENSE/SPEED/SPECIAL with right-aligned values, pret PrintStatsBox.LevelUpStatsBox),
and WaitForTextScrollButtonPress (= WaitForAPress). This matches pret's per-mon order (gained → grew + box
→ one A-press), so the gained-EXP text moved from BattleWonGiveExp INTO GainExperience's loop (BattleWonGiveExp
is now just `call GainExperience`). The display reads the leveled PARTY mon directly (wPartyMon1 +
wWhichPokemon*PARTYMON_STRUCT_LENGTH stats / wPartyMonNicks nick / wCurEnemyLevel), so LoadMonData/
GetPartyMonName stay stubbed (no wLoadedMon dependency). New helpers print_num3 (3-digit right-aligned,
space-padded) + get_party_nick. Removed PrintStatsBox/WaitForTextScrollButtonPress/GainExpPrintStub from
battle_exp_stubs.asm (now real). Coords use pret CONTENT (the 4 stat labels + values) but wide-canvas
PLACEMENT (level-up box at canvas (26,2), 12x4) is a first pass to ITERATE with the user per the battle-UI
placement convention. Harness: gain flag moved slot 0 → slot 3 (PIKACHU L5 + 102 EXP → L6) so the leveling
mon matches the on-screen PIKACHU and exercises the level-up path. Builds + links clean (FRONTEND_SRCS).
The level-up stats box is the BATTLE one (distinct from the party-menu status screen — user note). GATE:
awaiting live user sign-off (+ placement iteration). Deferred still: move learning (LearnMoveFromLevelUp
stub), the in-battle modified-stat recompute stubs (irrelevant post-victory), faint-sprite clear (the enemy
pic lingers under the box). LATENT COLLISION reminder stands in battle_exp_stubs.asm for the remaining stubs.

### Battle text char-by-char reveal + centered level-up box (Wave 2, Stage 3, 2026-06-29)
Two user-flagged fixes to the level-up display:
1. PLACEMENT (user: battle UI is drawn to the centered GB viewport, not the widescreen margins). The
   level-up stats box now uses pret PrintStatsBox.LevelUpStatsBox's exact GB coords mapped by the
   battle-UI (+10,+3) projection offset: box GB(9,2)→canvas(19,5) 9x8; labels GB(11,3/5/7/9), values
   GB(15,4/6/8/10) — label-row then value-row, as the GB renders it. (Was a wrong (26,2) margin guess.)
2. TIMING (user: battle text was instant — an oversight; the overworld already reveals char-by-char,
   and pret uses the SAME function for both). wide_text now SHARES the overworld's PrintLetterDelay:
   added a `wide_reveal` flag; when set, WidePlaceString (and battle_menu print_dec) call PrintLetterDelay
   per glyph (per-letter frame delay from wOptions speed, A/B-held skips) — faithful to pret (PlaceString
   = instant menus/HUD/stats-box; the PrintText char loop = delayed dialog). InitBattle enables the delay
   flags (W_LETTER_PRINTING_DELAY |= BIT_TEXT_DELAY|BIT_FAST_TEXT_DELAY; wOptions speed = MEDIUM/3). The
   dialog routines set wide_reveal=1 (attack text, faint, gained-EXP, grew-level, run/no-run); the instant
   routines clear it (DrawBattleMenu, PrintStatsBox); HUD names use the stride-agnostic PlaceString (no
   WidePlaceString) so they're unaffected. DEFERRED: the battle INTRO ("Wild <nick> appeared!",
   DrawBattleIntroBox) still hand-draws via rep movsb (a separate path) → still instant; convert to reveal
   later for full consistency. Builds + links clean. GATE: awaiting live sign-off (incl. reveal speed feel).

### CORRECTION — battle text reveal gated by BIT_TEXT_DELAY, not a separate flag (2026-06-29)
The earlier `wide_reveal` flag was wrong: it only gated wide_text's WidePlaceString, but the battle HUD
draws mon names with text.asm's PlaceString — and the port's PlaceNextChar calls PrintLetterDelay just like
pret. Enabling BIT_TEXT_DELAY globally in InitBattle therefore made the HUD names type out too. Faithful
fix (matches pret exactly): BIT_TEXT_DELAY (wLetterPrintingDelayFlags) is THE single gate, shared by
PlaceString and WidePlaceString (both call PrintLetterDelay unconditionally, like PlaceNextChar). It is OFF
by default (InitBattle only sets BIT_FAST_TEXT_DELAY + wOptions speed) and turned ON only while a dialog
MESSAGE prints (faithful to TextCommandProcessor): the message routines `or` it on; the instant text
routines (DrawBattleHUDs, DrawBattleMenu, DrawMoveList, PrintMoveInfoBox, PrintStatsBox) `and` it off.
Dropped the `wide_reveal` global entirely. Result: only dialog messages (attack/faint/gained/grew/run) type
out; menu, move names, TYPE/PP, level-up stats box, and the HUD mon names + HP are instant — as in Gen 1.

### Level-up move learning — LearnMoveFromLevelUp (Wave 2, Stage 3, 2026-06-29)
Faithful port of pret evos_moves.asm:LearnMoveFromLevelUp into battle_menu.asm (replaces the
battle_exp_stubs no-op; GainExperience's level-up tail now calls the real one). Sets wCurPartySpecies =
wPokedexNum (internal index — EvosMovesPointerTable is internal-index-ordered, same as the working
WriteMonMoves path), GetMonLearnset → flat [level,moveID] pairs, finds a move taught at wCurEnemyLevel
(the new level); if not already known and a free (id 0) move slot exists, writes the move + its base PP
(Moves table) and shows "<nick> learned / <move>!" (dialog message → char-by-char). Full-moveset
"forget a move?" menu is DEFERRED (move not learned when all 4 slots full) — TODO. Reads/writes the PARTY
mon (wPartyMon1 + wWhichPokemon*PARTYMON_STRUCT_LENGTH), pret-faithful. Harness demo: PIKACHU slot 3 L5→L6
learns TAIL WHIP (Yellow Pikachu learnset L6) into its free slot (base Thundershock/Growl + debug SURF).
Builds + links clean. GATE: awaiting live sign-off.

### PP system (player-only) — decrement / 0-PP block / Struggle (Wave 2, Stage 3, 2026-06-29)
Faithful to pret (user: PP applies to the PLAYER only — Gen 1 never decrements the enemy AI's PP).
Three parts in battle_menu.asm:
1. DecrementPlayerPP (pret DecrementPP) — `DoPlayerAttackDamage` decrements the used move's PP in
   wBattleMonPP[wPlayerMoveListIndex] (skips Struggle). Party-struct PP sync deferred with
   LoadBattleMonFromParty (harness battle mon is seeded directly; wBattleMonPP backs the menu/TYPE-PP box).
   Multi-turn-status skips (Rage/Thrash/etc) not modelled (those moves aren't wired).
2. 0-PP move block (pret SelectMenuItem) — A on a move whose PP&PP_MASK==0 → ShowNoPP ("No PP left for /
   this move!") → RestoreBattleScreen → re-show the move menu (cursor preserved), can't be chosen.
3. Forced Struggle (pret AnyMoveToSelect) — before the move menu, CheckAllMovesNoPP; if every move's
   PP==0, set wPlayerSelectedMove=STRUGGLE (0xA5), ShowNoMovesLeft ("<nick> has no / moves left!"), and
   run the turn with Struggle (skips the menu). Struggle's recoil effect is deferred (move-effects).
PP text strings added (pret _MoveNoPPText / _NoMovesLeftText). TEMP PP-test harness seed (REVERT noted):
PIKACHU move PP = 2/1/1/1 and enemy HP bumped 35→200 so all 4 moves can be depleted to reach Struggle.
Builds + links clean. GATE: awaiting live sign-off.

---

## 2026-06-30 — Text engine completed game-wide (pret-aligned dynamic commands)

Plan: docs/current_plan_battle_pret_alignment.md Stage 0. The port's
TextCommandProcessor/PlaceString (src/text/text.asm, used by overworld NPC dialog)
already had the layout commands + `<PLAYER>`/`<RIVAL>` name tokens, but the
operand-bearing dynamic commands were skip-stubs. Implemented faithfully:

- **TX_RAM ($01)** — was `.cmd_skip2`. Now reads the 2-byte WRAM pointer and
  PlaceString's it at the cursor (pret home/text.asm:TextCommand_RAM). Enables
  nicknames / arbitrary RAM strings in any text stream.
- **TX_NUM ($09 / text_decimal)** — was `.cmd_skip3`. Reads addr + format byte
  (`(bytes<<4)|digits`), forces LEFT_ALIGN, calls PrintNumber (pret
  TextCommand_NUM).
- **TX_BCD ($02 / text_bcd)** — was `.cmd_skip3`. Reads addr + flags|length,
  calls PrintBCDNumber (pret TextCommand_BCD). For money.
- **`<TARGET>`/`<USER>` ($59/$5A)** — added to PlaceNextChar dispatch. Per
  hWhoseTurn (TARGET = ^1): player side → wBattleMonNick; enemy side → "Enemy " +
  wEnemyMonNick (pret PlaceMoveTargetsName / PlaceMoveUsersName). Manual glyph
  copy matching the existing `<PLAYER>`/`<RIVAL>` handlers.

New files mirroring pret's tree (file-for-file):
- **src/home/print_num.asm** — `PrintNumber` (mirrors home/print_num.asm). Pret's
  3-byte power-of-ten subtraction is computed with native 32-bit DIV (value ≤ 24
  bits); observable behaviour identical — same digits + leading-zero /
  LEFT_ALIGN / space-pad + pointer-advance rules (.PrintLeadingZero / .NextDigit).
- **src/home/print_bcd.asm** — `PrintBCDNumber` + `PrintBCDDigit` (faithful
  transliteration; calls PrintLetterDelay; note bit 7 = *suppress* leading zeroes,
  inverted vs PrintNumber, per pret).

Text flag bits (BIT_MONEY_SIGN/LEFT_ALIGN/LEADING_ZEROES) added to
gb_constants.inc (BIT_LEFT_ALIGN also defined locally in text.asm, which doesn't
include gb_constants). Both new files added to the Makefile GAME_SRCS beside
text.asm (always linked). Assembles + links clean.

Not yet exercised live: nothing emits TX_RAM/TX_NUM yet (overworld dialog uses
line/para/done only) — proof comes when the Stage-2 battle-text generator routes a
message (nick + EXP number) through it. The ad-hoc print_dec/print_num3 copies in
battle_menu/battle_hud/party_menu remain; retire them onto PrintNumber alongside
Stage 2.

---

## 2026-06-30 — Text engine UNIFIED (deleted the stride-40 wide_text.asm fork)

Plan: docs/current_plan_battle_pret_alignment.md Stage 0.5 (user-approved). The
port had forked pret's single stride-20 text engine into a parallel stride-40
clone (src/text/wide_text.asm: WidePlaceString/WideTextBoxBorder/
WideHandleMenuInput/WidePlaceMenuCursor) so battle could draw into the 40-wide
full-screen W_TILEMAP. pret has no such split (hardware is 20-wide everywhere) —
it was pure divergence (double maintenance, and would have forced cloning the
whole TextCommandProcessor too). Unified onto the ONE engine:

- text.asm parameterized on a runtime `text_row_stride` (.data, default 20).
  TextBoxBorder's row-advance and PlaceNextChar's `<NEXT>` now read it instead of
  the SCREEN_W_TILES literal. Overworld unchanged (stays 20).
- PlaceString now takes its source pointer in EAX (port calling convention; logic
  byte-identical to pret, which uses DE). Updated every caller: TextCommandProcessor
  (.cmd_start/.cmd_ram), battle_hud (2), party_menu, start_menu.
- Menu input relocated to new pret-mirrored src/home/window.asm as HandleMenuInput
  / PlaceMenuCursor (+ menu_item_step / menu_redraw_cb), stride-aware via
  text_row_stride. (These are home/window.asm routines in pret.)
- battle_menu.asm migrated off Wide*: WidePlaceString→PlaceString + `mov esi,ebx`
  (PlaceString returns the end cursor in EBX = pret's BC; identical position to
  Wide's returned ESI, so chaining is preserved), WideTextBoxBorder→TextBoxBorder,
  WideHandleMenuInput→HandleMenuInput, wide_line_step→menu_item_step,
  wide_menu_redraw_cb→menu_redraw_cb.
- InitBattle sets text_row_stride=40; EndBattleScreen resets it to 20 (so a future
  overworld return can't inherit the battle stride; full clean exit is Stage 3).
- src/text/wide_text.asm DELETED; removed from Makefile; src/home/window.asm added.
  type_names.asm (data table WideTypeNames) and init_battle.asm had no Wide *calls*
  (only a data label / comment) — left as-is.

Builds + links clean (DEBUG_BATTLE_LIVE). This is a behavior-preserving refactor;
needs a live regression check that the battle UI (HUD names, FIGHT/PKMN/ITEM/RUN
menu + cursor, move list + TYPE/PP box, attack/EXP/level messages) renders
exactly as before. The Stage-0 dynamic commands (TX_RAM/TX_NUM/<USER>) now reach
battle text via this one engine, but aren't *emitted* yet — that's Stage 2.

## 2026-06-30 (fix) — unification regression: PlaceString source addressing

After unifying the text engine, battles page-faulted and the FIGHT/PKMN/ITEM/RUN
labels were blank (overworld was fine). Root cause: the deleted WidePlaceString
read its source string FLAT (`[eax]`), while the unified PlaceString read it
EBP-relative (`[ebp+edx]`). battle_menu passes FLAT-LINEAR source pointers
(`mov eax, str_x` for .data labels, `lea eax,[ebp+nick]` for GB strings), so
PlaceString did `[ebp + flat_ptr]` → garbage; with no `$50` in the garbage,
PlaceNextChar walked off the mapped pages → page fault. (HUD names worked because
battle_hud passed a GB *offset*.)

Fix: PlaceString now reads its source FLAT-LINEAR (`[edx]`, no EBP) — matching
place_flat_str and the DJGPP flat model — so battle_menu's 49 sites need no change.
Updated the callers that passed GB offsets to pass flat-linear instead:
TextCommandProcessor .cmd_start (`lea eax,[ebp+esi]` in; `sub esi,ebp` after to get
the GB offset back for TCP) and .cmd_ram (`lea eax,[ebp+edx]`); the `<DONE>` handler
returns `lea edx,[ebp+DONE_SENTINEL_WRAM]` (flat) so the sentinel round-trips;
battle_hud (2), party_menu, start_menu now `lea eax,[ebp+...]`. The internal
`<PLAYER>`/`<RIVAL>`/`<USER>` handlers still read GB WRAM via `[ebp+edx]` (unchanged).
Static FRAME.BIN confirms FIGHT/PKMN/ITEM/RUN render. Re-touches the overworld
TCP/`<DONE>` path → needs an overworld NPC-dialog re-check.

## 2026-06-30 — Faithful battle core.asm orchestration written (Stage 3, assembles)

dos_port/src/engine/battle/core.asm — a structure-for-structure translation of pret
engine/battle/core.asm replacing the bespoke battle_menu.asm orchestration. Assembles
clean (standalone; not yet linked). Routines: MainInBattleLoop, DisplayBattleMenu (two-
column input + FIGHT/PKMN/ITEM/RUN dispatch), MoveSelectionMenu + AnyMoveToSelect
(faithful FormatMovesString → '-' empty slots, 0-PP/disabled/Struggle), ExecutePlayer/
EnemyMove (faithful core damage path), DisplayUsedMoveText (<USER> used <MOVE>!),
ApplyAttackTo{Enemy,Player}Pokemon, PrintBattleText + RunBattleTextStream, HandleEnemy/
PlayerMonFainted (+ GainExperience), BattleMenu_RunWasSelected, ReadPlayerMonCurHPAndStatus,
CheckNumAttacksLeft, BattlePromptWait. %includes the generated battle_text.inc.

Text engine parameterized (text.asm) for the battle box: text_line2 (<LINE> target),
text_arrow_pos + text_prompt_hook (battle ▼ in W_TILEMAP), and <PROMPT> now faithfully
draws ▼ → waits → TERMINATES (pret PromptText→DoneText) — data-driven ▼ (prompt=arrow,
done/text_end=none), fixing the earlier "▼ on every battle message" issue.

New gb_memmap symbols: wMenuItemToSwap CC35, wBattleAndStartSavedMenuItem CC2D,
wAnimationID D07B, wMonIsDisobedient CCED.

TODO(faithful) deepening, clearly marked in-source (translate next; not silent
divergences): CheckPlayer/EnemyStatusConditions (sleep/freeze/para/confusion/flinch/
Bide/Thrash/Rage), CheckForDisobedience, the IsInArray effect-array gating (currently
JumpMoveEffect runs once after damage), HandleCounterMove, multi-hit, Mirror/Metronome,
PrintCriticalOHKOText/DisplayEffectiveness, SlideDownFaintedMonPic + faint SFX, trainer
multi-mon/prize/blackout, GetCurrentMove move-name-buffer tail. Move animation = HP-bar
placeholder; audio = no-op (agreed).

NEXT (Stage 5 integration): alias battle_menu draw helpers to pret names (DrawHUDsAndHPBars
/Save+LoadScreenTilesToBuffer1/DrawBattleMenuBox/DrawEmptyDialogBox), add BattleItemMenu/
BattlePartyMenu deferred stubs, GUT battle_menu.asm's bespoke orchestration (keep only
draw helpers), wire JumpMoveEffect→effects.asm (remove battle_stubs stub, link the backend
live), point the DEBUG_BATTLE harness at MainInBattleLoop, add core.asm to the Makefile,
build + FRAME/live verify.

---

## 2026-06-30 — Stage 5 integration: faithful core.asm battle loop goes LIVE

The faithful `engine/battle/core.asm` translation is now LINKED and drives the battle
(replacing the bespoke battle_menu.asm orchestration). `make SKIP_TITLE=1
DEBUG_BATTLE_LIVE=1` builds; the static `DEBUG_BATTLE=1` FRAME dump confirms the HUD
(PIDGEY :L13 — E_LV fix), both sprites, the FIGHT/PKMN/ITEM/RUN menu and ▼ render.

Changes:
- **battle_menu.asm rewritten** to DRAW HELPERS + EXP/level-up display + run-odds only.
  Bespoke orchestration removed (DisplayBattleMenu, MoveSelectionMenu, ExecutePlayerTurn,
  Render*/Do*AttackDamage, the fainted/no-PP/run message draws). Kept: Save/LoadScreen-
  TilesToBuffer1 (+ SaveBattleScreen/RestoreBattleScreen aliases), DrawHUDsAndHPBars
  (→DrawBattleHUDs), DrawEmptyDialogBox/DrawBattleMenuBox/DrawBattleMenu, WaitForAPress,
  TryRunningFromBattle, ShowGainedExp/GrewLevel/Learned text, PrintStatsBox,
  LearnMoveFromLevelUp, FindMoveName, PrintMoveInfoBox. Added BattleItemMenu/
  BattlePartyMenu deferred stubs. DoEnemyAttackDamage kept as DEBUG_BATTLE_ENEMYHIT
  scaffold only.
- **animations.asm**: PlayMoveAnimation now ALWAYS takes pret's ANIMATION=OFF path
  (DelayFrames(30) + PlayApplyingAttackAnimation), per the user directive — the prior
  version gated on the wOptions bit, whose default (animations ON) skipped the delay
  entirely. PlayApplyingAttackAnimation is faithfully gated on wAnimationType; the visible
  shake/blink (rWX/OBJ-palette) is a marked TODO-HW. HP-bar drop is the separate
  DrawHUDsAndHPBars step, not the animation.
- **core.asm**: CriticalHit → CriticalHitTest (real core_damage.asm global).
- **core_stubs.asm (new, LINKED)**: faithful FormatMovesString (copy of misc.asm output —
  names via the flat FindMoveName walk since GetName/names.asm is not link-ready;
  TrainerNames undefined — and the '-' empty-slot tile is correctly 0xE3, vs misc.asm's
  latent ASCII-0x2D bug), plus no-op/faithful stubs for JumpMoveEffect,
  HandlePoisonBurnLeechSeed (ZF=0), TrainerAI (CF=0) — the deep effect/residual/AI
  closures aren't link-ready.
- **battle_stubs.asm**: JumpMoveEffect stub removed (now in core_stubs); CheckTarget-
  Substitute stub kept.
- **battle_exp_stubs.asm**: Save/LoadScreenTilesToBuffer1 stubs removed (battle_menu now
  provides the real ones — the EXP display gets real screen save/restore).
- **debug_dump.asm**: the DEBUG_BATTLE_LIVE `.live` loop now calls MainInBattleLoop
  (returns on win/lose/ran), replacing the bespoke DisplayBattleMenu/wBattleOver loop.
- **Makefile**: core.asm + core_stubs.asm + decrement_pp.asm + animations.asm linked
  (FRONTEND_SRCS); BATTLE_SRCS stays check-only.

Deferred (clearly marked TODO(faithful) in core.asm / core_stubs.asm): move effects
(JumpMoveEffect), residual poison/burn/leech, trainer AI + multi-mon/prize, status
conditions (sleep/freeze/para/confusion), CheckForDisobedience, multi-hit/charging/Counter,
the visible screen-shake. These are later waves — the loop STRUCTURE is faithful and live.

### 2026-06-30 — follow-up fixes (live-test bugs)
- **Blank FIGHT move names**: core_stubs.asm FormatMovesString kept the wMovesString write
  cursor in EDX across `call FindMoveName`, which clobbers DL → cursor corrupted, names
  written off-target. Fixed: push/pop EDX around the call.
- **"X used MOVE!" overflowed the box**: DisplayUsedMoveText composed the message on ONE
  line; pret's _ActorNameText + _UsedMove1Text put the actor name on line 1 and `line
  "used "` (a break) before the move name. Fixed: str_used_grammar now leads with <LINE>
  ($4F).
- **Level-up showed "grew to level 1"** (pre-existing engine bug, never live-tested — NOT a
  harness artifact): GainExperience adds EXP to the party struct, then (faithfully) calls
  LoadMonData so CalcLevelFromExperience can read the loaded-mon scratch
  (W_LOADED_MON_SPECIES/EXP). But LoadMonData was a no-op stub (battle_exp_stubs.asm), so
  wLoadedMon stayed stale → level computed off garbage (≈1). This would break a real battle
  too. FAITHFUL FIX: wired the home wrapper `LoadMonData` (new, load_mon_data.asm) →
  `LoadMonData_` (already linked; copies the full party mon into wLoadedMon + sets wMonHeader),
  and removed the stub — exactly pret's flow (load mon, then calc level). An earlier targeted
  hand-copy of just species+exp into wLoadedMon was reverted in favour of this. (The stat
  recompute reads the party struct directly, so it was unaffected.) Separately, the harness
  seeds the on-screen battle mon (L18) independently of the gaining party slot 3 (PIKACHU L5),
  so the display reads the L5→L6 party mon, not the L18 on-screen mon — a HARNESS seam (real
  battles LoadBattleMonFromParty), distinct from the engine bug above.

### 2026-06-30 — battle data generators (4) + move-effect text de-duplication
Added 4 Tier-1 generators (one per Sonnet subagent, reviewed against pret):
- gen_battle_text.py EXTENDED: now scans engine/battle/move_effects/*.asm for effect text
  wrappers and emits `global <Label>` per stream (103→123 labels). Taught it `text_pause`
  ($0A) so GettingPumpedText generates. (building_rage/residual_damage paths are port-only
  splits with no pret root file — harmless no-ops; that text lives in core.asm.)
- gen_trainer_parties.py NEW → TrainerDataPointers (47 dd, class-1 indexed) + rosters (both
  fixed-level and $FF per-mon formats) + SpecialTrainerMoves (358 B, $FF-term). Species =
  internal index (matches gen_wild_encounters/add_party_mon).
- gen_trainer_names.py NEW → TrainerNames (47, '@'-terminated, GetName-walked).
- gen_move_grammar.py NEW → MoveGrammar (4 groups, db -1/db 0 pret-literal; vestigial in
  English but carried for faithfulness).
Wired: gen_all_assets.py chains all 4; Makefile asset rules; new linked data objects
src/data/trainer_data.asm (+trainer_parties/_names.inc) and src/data/move_grammar.asm.
Build green (DEBUG_BATTLE_LIVE) + make check clean.

De-duplicated move-effect text (per the "text data is generated" rule): 10 move_effects/*.asm
hand-authored their text streams in code (e.g. focus_energy `GettingPumpedText`), colliding
with the now-generated battle_text labels and carrying dangling `extern _XxxText`. Stripped
the inline definitions + `global` + dangling externs; each now `extern`s the generated label.
KNOWN GAP: heal.asm's `StartedSleepingEffect` is a text wrapper that doesn't end in "Text",
so gen_battle_text's `*Text:` regex doesn't capture it — it's now an undefined extern (fine
check-only; needs the regex widened to `*Effect` text wrappers, or stays hand-authored, when
move_effects get linked for JumpMoveEffect).

Type-id handling verified correct end-to-end (Gen-1 gap): gb_constants NORMAL=0..GHOST=0x08,
gap 0x09-0x13, SPECIAL=FIRE=0x14..DRAGON=0x1A; WideTypeNames is a 27-entry raw-id-indexed
table (gap→tn_normal); damage split is `cmp al, SPECIAL(0x14)/jae .special`. (WideTypeNames
is still hand-authored — candidate for a future gen_type_names.)

---

# Move-effect swarm — S5 integration entries (2026-06-30)

The move-effect bodies below were integrated by the master into
`MoveEffectPointerTable` (effects.asm) across the S5 integration batches (a first
batch, then the second-half bodies + the re-translated drafts) and verified (build
green). Together with the StatModifier* shared bodies and the PoisonEffect_
reference handler logged earlier, they complete **all 34 non-NULL move effects**
(the swarm is done — see `docs/plans/move_swarm.md`; the 7 NULL-in-pret effects
correctly stay `UnportedMoveEffect`). Each is a faithful translation of the named
`engine/battle/effects.asm` label per `docs/plans/move_translation_divergence.md`.
The mandatory **Divergences** field lists every §2 allowlist item the body took
(§2.1 = literal move subanimation →
ANIMATION=OFF no-op; §2.4 = bank switching dropped in the flat DPMI model).
`PoisonEffect_` (the S4 reference handler) is logged in the swarm-scaffold entry
near the top of this file. Earlier draft-era `## <Name>Effect_` entries (dated
2026-06-20, no Divergences field) predate the swarm convention and are kept as
historical notes; these are the authoritative integration entries.

## SplashEffect_ (move-swarm S5)
- **Source:** `engine/battle/effects.asm:SplashEffect`
- **Translated:** `dos_port/src/engine/battle/move_effects/splash.asm` (`$55`)
- **Date:** 2026-06-30
- **H-flag:** Not involved.
- **Bug tags:** none.
- **Divergences:** `PlayCurrentMoveAnimation` → no-op: literal move subanimation
  deferred (ANIMATION=OFF path, §2.1). Splash otherwise does nothing (no accuracy
  test, no substitute check, no WRAM writes) — fully faithful.
- **Notes:** The simplest handler: subanim then unconditional "But nothing
  happened!" via the real PrintText.

## FlinchSideEffect_ (move-swarm S5)
- **Source:** `engine/battle/effects.asm:FlinchSideEffect`
- **Translated:** `dos_port/src/engine/battle/move_effects/flinch_side.asm` (`$1F`/`$25`)
- **Date:** 2026-06-30
- **H-flag:** Not involved.
- **Bug tags:** none.
- **Divergences:** none (faithful).
- **Notes:** 10%/30% flinch roll sets the FLINCHED bit on the move's target; calls
  the shared `ClearHyperBeam` helper (added to move_effect_helpers.asm during
  integration) once before the roll and again on a successful flinch, per pret.
  Silent (side effects never print).

## ConfusionEffect_ / ConfusionSideEffect_ (move-swarm S5)
- **Source:** `engine/battle/effects.asm:ConfusionEffect`, `:ConfusionSideEffect`
  (+ `ConfusionSideEffectSuccess` / `ConfusionEffectFailed`; one contiguous pret block)
- **Translated:** `dos_port/src/engine/battle/move_effects/confusion.asm`
  (`ConfusionEffect_` `$31`, `ConfusionSideEffect_` `$4C`; merged file)
- **Date:** 2026-06-30
- **H-flag:** Not involved.
- **Bug tags:** none.
- **Divergences:** `PlayCurrentMoveAnimation2` → no-op: literal move subanimation
  deferred (ANIMATION=OFF path, §2.1).
- **Notes:** Both entry points kept (the $4C side-effect rolls 10% then falls
  through to the shared confusion-apply tail), faithful to pret's fall-through.

## SleepEffect_ (move-swarm S5)
- **Source:** `engine/battle/effects.asm:SleepEffect`
- **Translated:** `dos_port/src/engine/battle/move_effects/sleep.asm` (`$01`/`$20`)
- **Date:** 2026-06-30
- **H-flag:** Not involved.
- **Bug tags:** `BUG(cosmetic)` — Hyper Beam recharge bypasses ALL hit-tests for a
  status move (already-asleep / already-statused / accuracy), preserved as pret's
  behavior; the fix lives in a `%if BUG_FIX_LEVEL >= 2` block, original (buggy)
  behavior in `%else`.
- **Divergences:** `PlayCurrentMoveAnimation2` → no-op: literal move subanimation
  deferred (ANIMATION=OFF path, §2.1).
- **Notes:** 1–7 turn sleep counter with the Stadium-link reroll-restriction tail,
  faithful.

## FreezeBurnParalyzeEffect_ (move-swarm S5)
- **Source:** `engine/battle/effects.asm:FreezeBurnParalyzeEffect`
- **Translated:** `dos_port/src/engine/battle/move_effects/freeze_burn_paralyze.asm`
  (`$04`/`$05`/`$06`/`$22`/`$23`/`$24`)
- **Date:** 2026-06-30
- **H-flag:** Not involved.
- **Bug tags:** `BUG(cosmetic)` — the `.freeze2` path resets Hyper Beam recharge
  asymmetrically (only the player's side via the `.freeze1`/`.freeze2` ClearHyperBeam
  split), preserved as pret behavior under a `%if BUG_FIX_LEVEL >= 2` guard
  (original in `%else`).
- **Divergences:** `PlayBattleAnimation` / `PlayBattleAnimation2` → no-op: literal
  move subanimation deferred (ANIMATION=OFF path, §2.1).
- **Notes:** The chance-on-hit status (Body Slam paralysis, Ice Beam freeze, etc.),
  NOT the accuracy-tested dedicated status moves.

## ConversionEffect_ (move-swarm S5)
- **Source:** `engine/battle/effects.asm:ConversionEffect`
- **Translated:** `dos_port/src/engine/battle/move_effects/conversion.asm` (`$18`)
- **Date:** 2026-06-30
- **H-flag:** Not involved.
- **Bug tags:** none.
- **Divergences:** bank-call dropped — the `CallBankF` bank load was removed and the
  flat target called directly (no banks in the DPMI model, §2.4).
- **Notes:** Copies the target's type into the user's type bytes; INVULNERABLE
  evaluated as the constant.

## HazeEffect_ (move-swarm S5)
- **Source:** `engine/battle/effects.asm:HazeEffect`
- **Translated:** `dos_port/src/engine/battle/move_effects/haze.asm` (`$19`)
- **Date:** 2026-06-30
- **H-flag:** Not involved.
- **Bug tags:** none.
- **Divergences:** bank-call dropped (flat model, §2.4); `PlayCurrentMoveAnimation`
  → no-op: literal move subanimation deferred (ANIMATION=OFF path, §2.1).
- **Notes:** Resets both sides' stat stages / status / volatile flags, faithful.

## OneHitKOEffect_ (move-swarm S5)
- **Source:** `engine/battle/effects.asm:OneHitKOEffect`
- **Translated:** `dos_port/src/engine/battle/move_effects/one_hit_ko.asm` (`$26`)
- **Date:** 2026-06-30
- **H-flag:** Not involved.
- **Bug tags:** none.
- **Divergences:** none (faithful).
- **Notes:** Speed-gated OHKO; sets damage to max HP and the one-hit-KO message flag.

## MistEffect_ (move-swarm S5)
- **Source:** `engine/battle/effects.asm:MistEffect`
- **Translated:** `dos_port/src/engine/battle/move_effects/mist.asm` (`$2E`)
- **Date:** 2026-06-30
- **H-flag:** Not involved.
- **Bug tags:** none.
- **Divergences:** bank-calls dropped (flat model, §2.4); literal move subanimation
  → no-op (ANIMATION=OFF path, §2.1).
- **Notes:** Sets the PROTECTED_BY_MIST bit; "But it failed!" when already misted.

## FocusEnergyEffect_ (move-swarm S5)
- **Source:** `engine/battle/effects.asm:FocusEnergyEffect`
- **Translated:** `dos_port/src/engine/battle/move_effects/focus_energy.asm` (`$2F`)
- **Date:** 2026-06-30
- **H-flag:** Not involved.
- **Bug tags:** none (the Gen-1 Focus Energy *crit-reduction* quirk lives in the
  crit-rate calc, not in this setup handler).
- **Divergences:** bank-calls dropped (flat model, §2.4); literal move subanimation
  → no-op (ANIMATION=OFF path, §2.1).
- **Notes:** Sets the GETTING_PUMPED bit; "But it failed!" if already pumped.

## ParalyzeEffect_ (move-swarm S5)
- **Source:** `engine/battle/effects.asm:ParalyzeEffect`
- **Translated:** `dos_port/src/engine/battle/move_effects/paralyze.asm` (`$43`)
- **Date:** 2026-06-30
- **H-flag:** Not involved.
- **Bug tags:** none.
- **Divergences:** bank-calls dropped (flat model, §2.4); literal move subanimation
  → no-op (ANIMATION=OFF path, §2.1).
- **Notes:** Accuracy-tested paralysis (MoveHitTest), sets PARALYZED status +
  QuarterSpeedDueToParalysis, faithful.

## LeechSeedEffect_ (move-swarm S5)
- **Source:** `engine/battle/move_effects/leech_seed.asm:LeechSeedEffect_`
- **Translated:** `dos_port/src/engine/battle/move_effects/leech_seed.asm` (`$54`)
- **Date:** 2026-06-30
- **H-flag:** Not involved.
- **Bug tags:** none.
- **Divergences:** (1) literal move subanimation → no-op (`PlayCurrentMoveAnimation`,
  ANIMATION=OFF path, §2.1); (2) bank flattening — pret's `callfar MoveHitTest` and
  `callfar PlayCurrentMoveAnimation` become flat `call`s (§2.4, no banks in DPMI).
- **Notes:** Sets the SEEDED bit on the target (Grass-type immunity + already-seeded
  guards), faithful.

## ExplodeEffect_ (move-swarm S5)
- **Source:** `engine/battle/effects.asm:ExplodeEffect`
- **Translated:** `dos_port/src/engine/battle/move_effects/explode.asm` (`$07`)
- **Date:** 2026-06-30
- **H-flag:** Not involved.
- **Bug tags:** none.
- **Divergences:** none (faithful).
- **Notes:** Zeroes the user's own HP and status and clears the user's SEEDED bit.
  The "effect activates even on a miss" + damage-formula defense-halving special-casing
  lives in core.asm (cp EXPLODE_EFFECT sites), not in this body.

## BideEffect_ (move-swarm S5)
- **Source:** `engine/battle/effects.asm:BideEffect`
- **Translated:** `dos_port/src/engine/battle/move_effects/bide.asm` (`$1A`)
- **Date:** 2026-06-30
- **H-flag:** Not involved.
- **Bug tags:** none.
- **Divergences:** `PlayBattleAnimation2` → no-op: literal move subanimation deferred
  (ANIMATION=OFF path, §2.1).
- **Notes:** Setup-only: sets STORING_ENERGY, zeroes the accumulated-damage word,
  clears both move-effect bytes (literal pret behavior), rolls a 2–3 turn counter.
  Damage accumulation/release lives in core.asm.

## TwoToFiveAttacksEffect_ (move-swarm S5)
- **Source:** `engine/battle/effects.asm:TwoToFiveAttacksEffect`
- **Translated:** `dos_port/src/engine/battle/move_effects/two_to_five_attacks.asm`
  (`$1D`/`$1E`/`$2C`/`$4D`)
- **Date:** 2026-06-30
- **H-flag:** Not involved.
- **Bug tags:** none (the Twineedle register-reuse is a faithful pret quirk, noted in
  the file, not a bug).
- **Divergences:** none (faithful).
- **Notes:** Sets ATTACKING_MULTIPLE_TIMES, decides the hit count (2 for Double Kick /
  Twineedle / Attack-Twice, 2–5 distribution for the multi-hit moves) and writes both
  the counter and hit-count bytes.

## RageEffect_ (move-swarm S5)
- **Source:** `engine/battle/effects.asm:RageEffect`
- **Translated:** `dos_port/src/engine/battle/move_effects/rage.asm` (`$51`)
- **Date:** 2026-06-30
- **H-flag:** Not involved.
- **Bug tags:** none.
- **Divergences:** none (faithful).
- **Notes:** Sets the USING_RAGE bit on the user's side (hWhoseTurn-selected); no
  accuracy test, text, or animation.

## ChargeEffect_ (move-swarm S5)
- **Source:** `engine/battle/effects.asm:ChargeEffect`
- **Translated:** `dos_port/src/engine/battle/move_effects/charge.asm` (`$27`/`$2B`)
- **Date:** 2026-06-30
- **H-flag:** Not involved.
- **Bug tags:** none.
- **Divergences:** literal move subanimation → no-op (`PlayBattleAnimation`,
  ANIMATION=OFF path, §2.1); bank-call dropped (flat model, §2.4); pret's
  `ChargeMoveEffectText` uses `text_far` + `text_asm` (the generated text path
  cannot emit a `text_asm` callback), so the displayed two-line
  "`<MON>`\n`<message>!`" stream was reproduced as **6 hand-built local composite
  text streams** (one per charge move) — a Tier-2 text reconstruction, not a
  generated `battle_text.inc` entry.
- **Notes:** Setup-turn handler for the two-turn moves (Razor Wind, Solar Beam,
  Skull Bash, Sky Attack, Fly, Dig). Sets CHARGING_UP, clears the move animation,
  selects the per-move "dug a hole" / "is glowing" / etc. message, and (for the
  invulnerable moves) sets the INVULNERABLE bit. The 6 composite text streams keep
  the per-move flavor without a `text_asm` runtime callback.

## MimicEffect_ (move-swarm S5)
- **Source:** `engine/battle/effects.asm:MimicEffect`
- **Translated:** `dos_port/src/engine/battle/move_effects/mimic.asm` (`$52`)
- **Date:** 2026-06-30
- **H-flag:** Not involved.
- **Bug tags:** `GLITCH` — the player (move chosen from the target's move list) vs
  AI (move chosen at random) move-pick asymmetry is preserved as pret behavior.
- **Divergences:** literal move subanimation → no-op (ANIMATION=OFF path, §2.1).
- **Notes:** Copies a target move into the user's Mimic slot. The choose-vs-random
  branch is intentionally left asymmetric per the original; accuracy/substitute
  guards faithful.
- **Runtime gap (faithful translation ≠ faithful in-game behavior yet):** the
  non-link **player** path sets `wMoveMenuType = 1` and calls `MoveSelectionMenu`
  to let the human pick *which of the foe's* moves to copy — but the live
  `MoveSelectionMenu` (core.asm) does not yet implement the `wMoveMenuType=1`
  (mimic) mode; it always lists the player's own moves. So `MimicEffect_` itself is
  a faithful port, but until that menu mode lands, the human-player Mimic UI shows
  the wrong move list. The AI/link random-pick path is unaffected. (Tracked as a
  `TODO(master)` in mimic.asm and a deferred item in `MoveSelectionMenu`.)

## SwitchAndTeleportEffect_ (move-swarm S5)
- **Source:** `engine/battle/effects.asm:SwitchAndTeleportEffect`
- **Translated:** `dos_port/src/engine/battle/move_effects/switch_and_teleport.asm` (`$1C`)
- **Date:** 2026-06-30
- **H-flag:** Not involved.
- **Bug tags:** none.
- **Divergences:** literal move subanimation → no-op (ANIMATION=OFF path, §2.1).
- **Notes:** Teleport (player) / Whirlwind-Roar (run from wild). The deliberate
  pret asymmetry is preserved: the player branch prints via `PrintButItFailedText_`
  while the enemy branch goes through `ConditionalPrintButItFailed` — kept verbatim,
  not normalized.

## DisableEffect_ (move-swarm S5)
- **Source:** `engine/battle/effects.asm:DisableEffect`
- **Translated:** `dos_port/src/engine/battle/move_effects/disable.asm` (`$56`)
- **Date:** 2026-06-30
- **H-flag:** Not involved.
- **Bug tags:** `BUG(cosmetic)` — in non-link battles the random move pick can skip
  a move with 0 PP test differently than link, preserved as pret behavior under a
  `%if BUG_FIX_LEVEL >= 2` guard (original in `%else`).
- **Divergences:** literal move subanimation → no-op (ANIMATION=OFF path, §2.1).
- **Notes:** Picks a target move, rolls a 1–8 turn disable counter, writes the
  disabled-move id + counter. The non-link PP-skip quirk is the only bug tag.

## TrappingEffect_ (move-swarm S5)
- **Source:** `engine/battle/effects.asm:TrappingEffect`
- **Translated:** `dos_port/src/engine/battle/move_effects/trapping.asm` (`$2A`)
- **Date:** 2026-06-30
- **H-flag:** Not involved.
- **Bug tags:** none.
- **Divergences:** none (faithful).
- **Notes:** Wrap / Bind / Fire Spin / Clamp lock-in. Sets ATTACKING_MULTIPLE_TIMES,
  rolls the 2–5 turn distribution, and calls the shared `ClearHyperBeam` helper.

## HyperBeamEffect_ (move-swarm S5)
- **Source:** `engine/battle/effects.asm:HyperBeamEffect`
- **Translated:** `dos_port/src/engine/battle/move_effects/hyper_beam.asm` (`$50`)
- **Date:** 2026-06-30
- **H-flag:** Not involved.
- **Bug tags:** none.
- **Divergences:** none (faithful).
- **Notes:** Sets the NEEDS_TO_RECHARGE bit on the user's side (hWhoseTurn-selected);
  no text/animation in the body.

## ThrashPetalDanceEffect_ (move-swarm S5)
- **Source:** `engine/battle/effects.asm:ThrashPetalDanceEffect`
- **Translated:** `dos_port/src/engine/battle/move_effects/thrash_petal_dance.asm` (`$1B`)
- **Date:** 2026-06-30
- **H-flag:** Not involved.
- **Bug tags:** none.
- **Divergences:** literal move subanimation → no-op (ANIMATION=OFF path, §2.1).
- **Notes:** Setup for the lock-in rampage moves: sets THRASHING_ABOUT, rolls a
  2–3 turn counter. Confusion-on-end + forced-move lives in core.asm.

## DrainHPEffect_ (move-swarm S5, re-translated)
- **Source:** `engine/battle/effects.asm:DrainHPEffect`
- **Translated:** `dos_port/src/engine/battle/move_effects/drain_hp.asm` (`$03`/`$08`)
- **Date:** 2026-06-30
- **H-flag:** Not involved.
- **Bug tags:** none.
- **Divergences:** `predef UpdateHPBar` → direct `UpdateCurMonHPBar` call (no predef
  table in the flat model, §2.4); `callfar` dropped → flat call (§2.4).
- **Notes:** Absorb / Mega Drain / Leech Life (`$03`) and Dream Eater (`$08`). Heals
  the user by half the damage dealt (min 1), capped at max HP, and shows the right
  drain message. **Re-translated** after a failed audit of the original draft, which
  used the wrong `DREAM_EATER_EFFECT` constant and stride-20 HP-bar coordinates; the
  rewrite uses the correct effect id and the widescreen HUD HP-bar path.

## ReflectLightScreenEffect_ (move-swarm S5, re-translated)
- **Source:** `engine/battle/effects.asm:ReflectLightScreenEffect`
- **Translated:** `dos_port/src/engine/battle/move_effects/reflect_light_screen.asm`
  (`$40`/`$41`)
- **Date:** 2026-06-30
- **H-flag:** Not involved.
- **Bug tags:** none.
- **Divergences:** literal move subanimation → no-op (ANIMATION=OFF path, §2.1);
  bank-call dropped (flat model, §2.4).
- **Notes:** Sets the user's REFLECT (`$41`) / LIGHT_SCREEN (`$40`) bit; "But it
  failed!" when already active. **Re-translated** — the prior draft's body was
  missing and it wrongly redefined `EffectCallBattleCore`; the rewrite externs the
  shared helper.

## RecoilEffect_ (move-swarm S5, re-translated)
- **Source:** `engine/battle/effects.asm:RecoilEffect`
- **Translated:** `dos_port/src/engine/battle/move_effects/recoil.asm` (`$30`)
- **Date:** 2026-06-30
- **H-flag:** Not involved.
- **Bug tags:** none.
- **Divergences:** `predef UpdateHPBar` → direct `UpdateCurMonHPBar` call (flat
  model, §2.4).
- **Notes:** Take Down / Double-Edge / Submission recoil = damage/4 (min 1) off the
  user. **Re-translated** — the prior draft used `wTileMap` stride-20 coordinates and
  an undefined `predef_UpdateHPBar2`; the rewrite uses `UpdateCurMonHPBar`.

## PayDayEffect_ (move-swarm S5, re-translated)
- **Source:** `engine/battle/effects.asm:PayDayEffect`
- **Translated:** `dos_port/src/engine/battle/move_effects/pay_day.asm` (`$10`)
- **Date:** 2026-06-30
- **H-flag:** Not involved.
- **Bug tags:** none.
- **Divergences:** `AddBCDPredef` → direct flat `AddBCD` (no predef table, §2.4).
- **Notes:** Accumulates level×2 coins into `wTotalPayDayMoney` (3-byte BCD) and
  prints "Coins scattered everywhere!". **Re-translated** — the prior draft had the
  wrong `Divide` `BH` register setup and bad `AddBCD` register wiring; the rewrite
  fixes the Divide divisor and the BCD operand registers.

## SubstituteEffect_ (move-swarm S5, re-translated)
- **Source:** `engine/battle/effects.asm:SubstituteEffect`
- **Translated:** `dos_port/src/engine/battle/move_effects/substitute.asm` (`$4F`)
- **Date:** 2026-06-30
- **H-flag:** Not involved.
- **Bug tags:** `BUG(cosmetic)` — the self-KO "carry-only" branch (Substitute at
  exactly 1/4 HP setting up and fainting the user) is preserved as pret behavior
  under a `%if BUG_FIX_LEVEL >= 2` guard (original in `%else`).
- **Divergences:** `AnimationSubstitute` / literal subanimation → no-op stubs
  (ANIMATION=OFF path, §2.1; the real pic-swap substitute graphic is deferred);
  bank-call dropped (flat model, §2.4).
- **Notes:** Builds the Substitute doll (HP/4 cost, sets HAS_SUBSTITUTE_UP), with the
  already-up and not-enough-HP guards. **Re-translated.**

## HealEffect_ (move-swarm S5, re-translated)
- **Source:** `engine/battle/effects.asm:HealEffect`
- **Translated:** `dos_port/src/engine/battle/move_effects/heal.asm` (`$38`)
- **Date:** 2026-06-30
- **H-flag:** Not involved.
- **Bug tags:** `BUG(cosmetic)` — the MSB-only full-HP comparison can mis-detect
  "already at full HP" (the Gen-1 Recover/Softboiled HP-check quirk), preserved under
  a `%if BUG_FIX_LEVEL >= 2` guard (original in `%else`).
- **Divergences:** literal move subanimation → no-op (ANIMATION=OFF path, §2.1);
  `predef UpdateHPBar` → direct `UpdateCurMonHPBar` call (flat model, §2.4).
- **Notes:** Recover / Softboiled / Rest. Rest's sleep-then-full-heal flag
  persistence is reproduced via a `.bss` `isRestStash` byte (stands in for pret's
  reuse of a battle-status register across the Rest path). **Re-translated.**

## TransformEffect_ (move-swarm S5, re-translated)
- **Source:** `engine/battle/effects.asm:TransformEffect`
- **Translated:** `dos_port/src/engine/battle/move_effects/transform.asm` (`$39`)
- **Date:** 2026-06-30
- **H-flag:** Not involved.
- **Bug tags:** **two** `BUG(cosmetic)` tags, both preserved under
  `%if BUG_FIX_LEVEL >= 2` guards (originals in `%else`): (1) `hWhoseTurn` is
  clobbered before the INVULNERABLE check, so the wrong side's invulnerability can be
  read; (2) the code writes `wPlayerBattleStatus1` where it should test
  `wEnemyBattleStatus1` (wrong target's battle-status byte).
- **Divergences:** literal subanimation / `HideSubstitute` / `ReshowSubstitute` /
  `AnimationTransformMon` → no-op stubs (ANIMATION=OFF path, §2.1; the transform pic
  swap is deferred); bank-calls dropped (flat model, §2.4).
- **Notes:** Copies the target's species/types/moves/DVs/stat-stages into the user
  (Ditto/Mew Transform), stashing `wTransformedEnemyMonOriginalDVs`. **Re-translated**
  — the prior draft was missing.

## Move-swarm S5 — shared support added during second-half integration
- **Date:** 2026-06-30
- During integration of the second-half handlers the shared scaffold gained:
  `move_effect_helpers.asm` — `ClearHyperBeam` (global; Flinch / FreezeBurnParalyze /
  Trapping), `PrintDoesntAffectText`, and the `AnimationSubstitute` /
  `AnimationTransformMon` / `PlayBattleAnimation` no-op stubs (faithful
  ANIMATION=OFF). `gb_memmap.inc` — `wPlayerConfusedCounter` / `wEnemyConfusedCounter`,
  `wUnknownSerialFlag_d499`, `wTotalPayDayMoney` / `wPayDayMoney`,
  `wTransformedEnemyMonOriginalDVs`. `gb_constants.inc` — `XSTATITEM_ANIM`,
  `SHRINKING_SQUARE_ANIM`, `SLIDE_DOWN_ANIM`, and the move-anim ids `RAZOR_WIND` /
  `ROAR` / `SOLARBEAM` / `SKULL_BASH` / `SKY_ATTACK`.
- Tooling: `tools/gen_battle_text.py` was fixed to emit `StartedSleepingEffect` (its
  label regex only matched `*Text` names, dropping the `*Effect` text labels);
  regenerating also restored a stale-missing `PickUpPayDayMoneyText`.
- **Honesty caveat on the `PlayBattleAnimation` / `…2` no-op stubs:** §2.1 sanctions
  no-op'ing the *literal move subanimation*, but several handlers
  (FreezeBurnParalyze, Bide, ThrashPetalDance) route the **HUD-shake** anims
  (`ENEMY_HUD_SHAKE_ANIM`, `SHAKE_SCREEN_ANIM`) through these same stubs — and §3
  lists "the screen shakes when a move lands" as faithful ANIMATION=OFF behavior
  that *should* still happen. So today those status-infliction shakes do **not**
  appear: the handlers call the right anim id, but the stub swallows it. The
  translations are faithful (they invoke the shake exactly where pret does); the
  shared *stub* is the incomplete part. This is the same deferred bucket as the
  gradual HP-bar drain and the real Substitute pic-swap — to be filled in during
  the PPU pass, at which point the calls light up with no handler changes. Logged
  here so the "no-op = faithful" shorthand elsewhere isn't read as "the shake is
  already happening."
- **`BUG(cosmetic)` vs `BUG(critical)` labeling:** the port uses the 2-level scheme
  from `gb_macros.inc` — `critical` = memory-unsafe (crash / corruption / ACE),
  everything else (including outcome-affecting Gen-1 quirks like Substitute's
  self-KO or Sleep's hit-test bypass) = `cosmetic`. So "cosmetic" here means
  "not memory-unsafe," **not** "no gameplay effect." All such bugs are gated by
  `%if BUG_FIX_LEVEL >= 2` either way; the label only picks which `/FIXCRIT` vs
  `/FIXALL` tier turns the fix on.

# Battle turn-loop: status conditions + residual damage (2026-06-30)

Wiring the *consumers* of the move-effect swarm's output (the effects were write-only).
Faithful ports from pret `engine/battle/core.asm`; each branch cites its pret line in the
source. pret is the spec. Build green at BUG_FIX_LEVEL 0 and 2.

## HandlePoisonBurnLeechSeed (residual damage) — WIRED LIVE
- **Source:** `engine/battle/core.asm:479` (already translated in `residual_damage.asm`).
- **Change:** moved `residual_damage.asm` BATTLE_SRCS→FRONTEND_SRCS and dropped the
  link-only stub in `core_stubs.asm`; already called at `core.asm` MainInBattleLoop.
- **Divergences:** none (faithful) — the UI calls (PrintText/UpdateCurMonHPBar/
  DrawHUDsAndHPBars/DelayFrames) are live; PlayMoveAnimation is the ANIMATION=OFF stub.
- **Glitch preservation:** the Leech Seed + Toxic-counter interaction and the Leech Seed
  overkill-heal GLITCHes are carried faithfully (intentional Gen-1, no BUG_FIX guard).
- **Verified:** ZF-on-faint return contract matches pret `:533-541` and the loop's
  `jz Handle*MonFainted`.

## CheckPlayerStatusConditions / CheckEnemyStatusConditions — the keystone
- **Source:** `engine/battle/core.asm:3499` (player) + `:5859` (enemy).
- **Translated:** `dos_port/src/engine/battle/core.asm` (replaced the two "no condition" stubs).
- **Behavior:** sleep countdown/wake, freeze, held-in-place (foe's trapping move), flinch,
  Hyper-Beam recharge, Disable countdown, confusion (decrement → 50% typeless self-hit),
  disabled-move block, 25% full-paralysis, and the bide/thrash/charge/trap-clear on
  self-hit/full-para. Multi-turn lock-ins (Bide/Thrash/Trapping/Rage) are `TODO(Stage 3)`.
- **Continuation idiom:** pret `ld hl, X` / `.returnToHL: xor a; ret` / caller `jp hl`
  → port sets **ESI = continuation**, returns ZF; callers (`ExecutePlayerMove`/
  `ExecuteEnemyMove`) do `jnz .noCondition / jmp esi`.
- **Divergences:** none (faithful); status/confusion anims route through the
  `PlayMoveAnimation` ANIMATION=OFF stub (§2.1-style, deferred).

## HandleSelfConfusionDamage (`:3843`) + PrintMoveIsDisabledText (`:3821`)
- Typeless 40-BP self-hit via the live damage pipeline (defense-swap; player-side a
  helper, enemy-side inlined per pret); disabled-move text clears CHARGING_UP (both sides).
- **Divergences:** none (faithful). Anim via the deferred PlayMoveAnimation stub.
- Added constants (from `constants/move_constants.asm`): `POUND` $01, `STATUS_AFFECTED_ANIM`
  $A7, `SLP_PLAYER_ANIM` $BC, `SLP_ANIM` $BD, `CONF_PLAYER_ANIM` $BE, `CONF_ANIM` $BF.

## Stage 2.5 + 3 — faithful dispatchers + multi-turn moves (2026-06-30)
- **ExecutePlayerMove** (pret `core.asm:3244`) + **ExecuteEnemyMove** (`:5639`): rebuilt from
  the simplified checkpoint flow into pret's faithful structure, exposing every re-entry
  label (Player/Enemy: CanExecuteChargingMove, CheckIfNeedsToChargeUp, CanExecuteMove,
  CalcMoveDamage, HandleIfMoveMissed, GetAnimationType, CheckIfFlyOrChargeEffect,
  MirrorMoveCheck, multi-hit loop). Deferred leaves are explicit flag-faithful stub CALLs
  (core_stubs.asm): PrintGhostText, HandleCounterMove, MirrorMoveCopyMove, MetronomePickMove,
  PrintCriticalOHKOText, DisplayEffectiveness, HandleExplodingAnimation. HandleBuildingRage
  is real (linked). **Divergences:** enemy PP not decremented (project scope); enemy anim
  redraw uses DrawHUDsAndHPBars (DrawEnemyHUDAndHPBar not yet ported); leaf routines stubbed.
- **Multi-turn lock-ins** (pret player `:3652-3750`, enemy `:6038-6133`): Bide (accumulate
  wDamage; release 2× → HandleIf*MoveMissed), Thrash/Petal Dance
  (force THRASH, confuse 2-5 turns at end → *CalcMoveDamage), Wrap/Bind/Fire Spin/Clamp (force,
  last-hit damage → Get*AnimationType), Rage (force, GetMoveName+CopyToStringBuffer → *CanExecuteMove).
  Helpers `SwapPlayerAndEnemyLevels` (`:6370`) + `CopyToStringBuffer` (`home/copy_string.asm`) ported.
  Added constants THRASH $25, BIDE $75, ANIMATIONTYPE_BLINK_ENEMY_MON_SPRITE/…_SHAKE_…_LIGHT.
- **Divergences (corrected 2026-07-01 by the triage pass, see below):** the original
  entry claimed "none beyond the leaf stubs" — that was inaccurate. Two real divergences were
  present and are fixed in the triage: (1) the Bide-unleash blocks added an unmatched
  `call SwapPlayerAndEnemyLevels` (pret `.UnleashEnergy` has none) → permanent level corruption;
  (2) `ExecuteEnemyMove` omitted pret's `inc [wAILayer2Encouragement]` (`:5656`). Also
  `CheckForDisobedience` was a bare `ret` that failed its ZF contract. Build green (levels 0/2).

## Battle-engine fidelity triage (2026-07-01, branch `battle-triage`)

Post-audit surgical corrections (see `docs/battle_audit_findings.md`). pret is the spec;
Gen-1 bugs preserved under `%if BUG_FIX_LEVEL` where a fix exists.

- **CheckForDisobedience** (pret `core.asm:4001`, stubbed): was a bare `ret`; the caller reaches
  it with ZF=1 from the preceding `CHARGING_UP` test, so `jz ExecutePlayerMoveDone` fired for
  every non-charging move (whole turn no-op). Now sets ZF=0 ("obeys"), matching sibling stubs.
- **Bide orphaned swap**: deleted the unmatched `call SwapPlayerAndEnemyLevels` in both
  `CheckPlayerStatusConditions` and `CheckEnemyStatusConditions` Bide-unleash paths (pret has none).
- **wAILayer2Encouragement**: added the missing `inc` in `ExecuteEnemyMove` (pret `:5656-5657`).
- **ApplyAttackToEnemyPokemon** (pret `:4783`) / **ApplyAttackToPlayerPokemon** (`:4902`): ported
  the full effect dispatch — Super Fang (½ target HP, min 1), Special Damage (Seismic Toss/Night
  Shade = level, Sonic Boom 20, Dragon Rage 40, Psywave rand — player `[1,b)`, enemy `[0,b)` Gen-1
  asymmetry preserved), 0-BP skip, overkill `wDamage` correction, and populate `wHPBar{Old,New,Max}HP`.
  `ApplyDamage{Enemy,Player}Pokemon` split out as the confusion-self-hit entry (skips the dispatch).
  **AttackSubstitute** (pret `:5020`) added, shared by both sides; the "wDamage not updated on
  substitute break" Gen-1 behavior is preserved (BUG(faithful)). Divergences (allowlist): the
  substitute-break anim (`Func_79929`) and the gradual `UpdateHPBar2` drain stay as placeholders
  (Master B); the instant HP subtract is retained but `wHPBar*` are faithfully populated.
  Move-id constants SONICBOOM/SEISMIC_TOSS/DRAGON_RAGE/NIGHT_SHADE/PSYWAVE added to gb_constants.inc.
- **MonsStatsRose / MonsStatsFell** (pret `MonsStatsRoseText` `effects.asm:552` / `MonsStatsFellText`
  `:754`): these are `text_far` intro + `text_asm` suffix, which the generator silently truncated
  (`gen_battle_text.py` now skips text_far+text_asm labels with a stderr note). Composed in code
  (like `DisplayUsedMoveText`): "<USER/TARGET>'s<LINE><stat> [greatly] rose!/fell!"<PROMPT>, branch
  on the attacker's move effect (Rose `>= ATTACK_DOWN1_EFFECT`; Fell `[BIDE_EFFECT, ATTACK_DOWN_SIDE_EFFECT)`).
  Live scroll/pacing of the "greatly" line is deferred to Master B. `stat_mod_effects.asm` repointed.
- **DelayFrames register bug**: `mov cl,N` → `mov bl,N` at 6 sites (focus_energy, leech_seed,
  swap_items ×2, evos_moves ×2); `DelayFrames` reads BL only (`frame.asm:213`).
- **battle_hud.asm**: level ≥100 now uses a 3-digit path (pret `PrintLevel`); the Gen-1 maxHP≥256
  lossy ÷4 HP-bar quirk (`GetHPBarLength`) restored as default, exact division gated at
  `BUG_FIX_LEVEL >= 2` (`BUG(cosmetic)`).
- **TryRunningFromBattle**: added the guaranteed-escape short-circuits (Safari/BATTLE_TYPE_RUN/link;
  Ghost is a TODO pending Master-A `IsGhostBattle`) and `wForcePlayerToChooseMon`=1 on failed escape
  (pret `:1536-1546`, `:1620-1622`). Added `wForcePlayerToChooseMon` (`$D11E`) to gb_memmap.inc.
- **LearnMoveFromLevelUp**: syncs a newly-learned move into `wBattleMonMoves`/`wBattleMonPP` when the
  leveling mon is the active battle mon (pret `learn_move.asm:56-73`).
- **SwitchEnemyMon**: restored pret's link-state `CF=0` guard (`trainer_ai.asm:618-622`).
- Build: all battle objects compile at BUG_FIX_LEVEL 0 and 2; every triage symbol links (the only
  unresolved reference in the tree is the unrelated, unported `DisplayTextBoxID` from the items layer).

## Town map + TM/rod/money item routines (2026-07-01)

Faithful ports of `engine/items/town_map.asm` (full, ~20 routines) plus five small
sibling files that a prior bespoke pass got wrong. All translated 1:1 from pret;
verified with standalone `nasm -f coff -I include/ -I . -o /dev/null`.

- **town_map.asm** (`src/engine/items/town_map.asm`) — DisplayTownMap, LoadTownMap
  (incl. the RLE decoder: high-nibble tile `+$60`, low-nibble run, `$00`-term),
  LoadTownMap_Fly, LoadTownMap_Nest, ExitTownMap, BuildFlyLocationsList,
  DrawPlayerOrBirdSprite, DisplayWildLocations, TownMapCoordsToOAMCoords,
  Write{PlayerOrBird,TownMapSprite,Asymmetric/SymmetricMonPartySprite}OAM,
  ZeroOutDuplicatesInList, LoadTownMapEntry, TownMapSpriteBlinkingAnimation.
  DANGLING (not in the Makefile / main loop). Preserved quirks: Cerulean-Cave
  nest-icon skip (`cp $19`), the unused dup Pallet Town external entry, the
  `inc d`/`inc [hl]` OAM-writer quirks; dropped the unreferenced `Func_70f87`.
  - **Port adaptations:** (1) *Centering* — the 20x18 GB screen is drawn centered
    in the 40x25 `W_TILEMAP` via `TOWNMAP_COL_OFFSET`(10)/`ROW_OFFSET`(3),
    `text_row_stride`=40 during the screen, an RLE decoder that wraps at width 20,
    and OAM pixel coords shifted col*8/row*8. Pixel origin to be re-verified when
    wired into the renderer. (2) *Widened name pointers* — entries store 4-byte host
    labels (`dd`), so LoadTownMapEntry strides are 5 (external) / 6 (internal) vs
    pret's 3/4; lookup logic unchanged. (3) *Charmap* — `'@'`→$50, space→$7F,
    `'▲'`→$ED, `'▼'`→$EE (not ASCII); inline texts moved to the generator.
  - **Deferred deps (extern, resolve when ported):** RunPaletteCommand /
    RunDefaultPaletteCommand, GBPalWhiteOut*, ClearScreenArea, CopyVideoData /
    CopyVideoDataDouble / FarCopyDataDouble, JoypadLowSensitivity,
    FindWildLocationsOfMon. Town-map WRAM the port hasn't allocated (wTownMapCoords,
    wWhichTownMapLocation, wFlyLocationsList, wShadowOAMBackup, …) is `extern`
    (TODO: allocate in gb_memmap.inc when wiring in). SFX_TINK/SFX_HEAL_AILMENT are
    TODO-HW(audio) placeholders (PlaySound is a stub).
  - **Data generator:** `tools/gen_town_map.py` → `assets/town_map_data.inc`
    (ExternalMapEntries 37, InternalMapEntries 61+term, TownMapOrder 47, 53 region
    names, 3 inline texts — all charmap-encoded via the shared charmap) and
    `assets/town_map_gfx.inc` (CompressedMap / WorldMapTileGraphics / cursor /
    up-arrow / nest-icon blobs). Asserts entry counts against FIRST_INDOOR_MAP /
    NUM_INDOOR_MAP_GROUPS.

- **tms.asm** — CanLearnTM, TMToMove. `predef_jump FlagActionPredef` collapses to a
  tail `jmp FlagAction` (index CL, array ESI, action BH=FLAG_TEST=2; result CL),
  bypassing GetPredefRegisters since we set the registers directly.
  `TechnicalMachines` (TM/HM → move-id list, 55+`-1`) added to `assets/items.inc`
  via a `gen_items.py` extension (its Makefile target already exists).
- **tmhm.asm** — CheckIfMoveIsKnown + AlreadyKnowsText (`text_far` redirect to the
  unported `_AlreadyKnowsText`, extern). Fixed the prior bug (`mov cx` → `mov bx`
  for AddNTimes' count).
- **tm_prices.asm** — GetMachinePrice, re-sourced `TM01` from gb_constants.inc
  (was a magic `%define`); logic already faithful, kept.
- **super_rod.asm** — ReadSuperRodData + GenerateRandomFishingEncounter. Fixed the
  prior register bug (`mov ch`/`edx` → `dl`/`dh`, result in DX). `SuperRodFishingSlots`
  generated by new `tools/gen_super_rod.py` (internal-index species, reusing the
  gen_wild_encounters constant model), embedded via `%include`.
- **subtract_paid_money.asm** — faithful SubtractAmountPaidFromMoney_ (StringCmp,
  SubBCD, MONEY_BOX + DisplayTextBoxID redraw, `and a`). Restored the
  `DisplayTextBoxID` call the prior bespoke version dropped, and removed the
  out-of-file `AddAmountSoldToMoney_` (belongs to home/inventory.asm; unreferenced).
  **CAVEAT:** per the user's "fully faithful, extern it" choice + "don't touch the
  Makefile", this file (linked via ITEMS_SRCS) now references the still-unported
  `DisplayTextBoxID` — the same symbol already noted as the tree's one unresolved
  reference. A full linked `make` will not resolve it until DisplayTextBoxID is
  ported or the file is moved to a check-only tier (one Makefile line).

### Follow-up (2026-07-01): unimplemented externs commented out, files link clean

Per request, every dependency with **no implementation in the tree** (which would
halt a link) is now commented out and marked `; TODO(unimplemented):` rather than
left as a live `extern`. All five item files now assemble **and link** with zero
unresolved symbols (verified against the full object set + `make` + `make check`).

- **item_data.asm**: added `global TechnicalMachines` (it was emitted into items.inc
  but not exported, so `tms.o` couldn't resolve it — the one real bug found).
- **town_map.asm**: commented out the `extern`s + call/reference sites for
  `BirdSprite`, `GBPalWhiteOut`/`GBPalWhiteOutWithDelay3`, `RunPaletteCommand`/
  `RunDefaultPaletteCommand` (the `jp` tail → `ret`), `ClearScreenArea`,
  `FarCopyDataDouble`, `CopyVideoData`/`CopyVideoDataDouble`, `JoypadLowSensitivity`,
  `FindWildLocationsOfMon`. The 11 unallocated town-map WRAM symbols became
  PLACEHOLDER `equ` offsets (`TOWNMAP_WRAM_PLACEHOLDER`, TODO: allocate in
  gb_memmap.inc). Faithful lines are preserved verbatim in the TODO comments.
- **subtract_paid_money.asm**: commented out `extern DisplayTextBoxID` + its call
  (confirmed missing — not even in pret's `home/`; needs porting). Resolves the
  earlier caveat: the file now links, so it no longer needs to sit outside the link
  for that reason (kept in the check tier alongside the others for now).
- **tmhm.asm**: commented out `extern _AlreadyKnowsText`; `AlreadyKnowsText` is now
  a placeholder empty text (`text_end`) until that far text is ported.

Restoring any of these = uncomment the `extern` + the `; TODO(unimplemented):` line(s)
once the routine/data exists.

## Trainer-header engine (M8.2 — home-rectification)
- Source: home/trainers.asm, home/trainers2.asm, engine/overworld/trainer_sight.asm,
  engine/overworld/emotion_bubbles.asm
- Translated: dos_port/src/engine/overworld/trainer_engine.asm (CHECK-only)
- Date: 2026-07-01
- H-flag: not involved
- Bug tags: none
- Divergences: FLAT-pointer model — trainer header stored as a flat 32-bit host ptr in
  `w_trainer_header_ptr` (.bss), superseding pret's emulated 2-byte `wTrainerHeaderPtr`
  (matches the port precedent `w_map_text_table_ptr`); split flat TrainerPicPointers /
  TrainerBaseMoney tables instead of pret's interleaved TrainerPicAndMoneyPointers;
  end-battle-text pointers widened to 4-byte flat slots. Persistent `TrainerFlagAction`
  (→ home `FlagAction`) is the faithful replacement for map_sprites.asm's non-persistent
  `npc_beaten_flags`.
- Notes: Completes the 33-member home/ rectification swarm (33/33). Assembles clean via
  the isolated scaffold include/m8_2_pending_symbols.inc (m1_3 convention); its
  union/event-region addresses are worker-estimated and tagged VERIFY — fold into
  canonical includes only after .sym verification. Fixed two integration bugs from the
  interrupted worker: (1) `mov [ebp+esi+ebx]` three-register sentinel store rewritten as
  `[ebp+ebx+wNPCMovementDirections2]` (esi==const here); (2) added canonical aliases for
  wStatusFlags3/5, hLoadedROMBank, wUpdateSpritesEnabled that the scaffold had missed.
  CHECK-only: no runtime caller until the trainer-header data generator + M8.1 wiring land.

## Battle special-move leaves (battle-swarm-A — turn execution & special-move mechanics)
- Date: 2026-07-01
- Branch: battle-swarm-A. Sonnet worker/auditor swarm, Opus integration.
- Sources: pret engine/battle/core.asm (HandleCounterMove :4718, MirrorMoveCopyMove :5132,
  ReloadMoveData :5167, IncrementMovePP :5214, MetronomePickMove :5184, PrintGhostText :3452,
  IsGhostBattle :3480, PrintMoveFailureText :3889, PrintCriticalOHKOText :3967,
  HandleExplodingAnimation :6787) and engine/battle/display_effectiveness.asm.
- Replaces the seven `core_stubs.asm` leaf stubs (deleted) with faithful new files under
  src/engine/battle/; core.asm's existing `extern`s resolve to them. Builds green at
  BUG_FIX_LEVEL 0 and 2 (SKIP_TITLE=1 DEBUG_BATTLE_LIVE=1); `make check` clean.
- H-flag: not involved in any unit.

Per-unit:
- **counter.asm** (HandleCounterMove). Faithful; uses live `MoveHitTest`. Divergences: none.
  Gen-1 quirk preserved (comment, no fix gate): Counter doubles whatever stale `wDamage`
  holds (shared player/enemy/switched-out), and the link move-selection-cursor desync.
  MovePower→type read via `[ebp+edx+1]` (wPlayer/EnemyMoveType immediately follow MovePower).
- **mirror_move.asm** (MirrorMoveCopyMove + ReloadMoveData + IncrementMovePP; last two `global`,
  consumed by metronome.asm). Divergences: (1) allowlist bank drop — `ld a, BANK(Moves)`
  removed (flat model). (2) `Moves` is a FLAT program-image table, so the pret `call FarCopyData`
  would double-bias the source through EBP (FarCopyData/CopyData do `lea esi,[ebp+esi]`); replaced
  with an inline 6-byte flat-src→WRAM-dst copy, matching the existing get_current_move.asm precedent.
  (3) the port's home/names.asm:GetMoveName omits pret's `ld de, wNameBuffer` tail, so ReloadMoveData
  sets `edx = wNameBuffer` before CopyToStringBuffer (local compensation; names.asm untouched —
  a latent gap flagged for a future names.asm fix). Added `wEnemyMon1PP equ 0xD8C0` to gb_memmap.inc.
- **metronome.asm** (MetronomePickMove). `extern ReloadMoveData` (mirror_move.asm). Divergence:
  allowlist subanim — `call PlayMoveAnimation(METRONOME)` kept as the faithful ANIMATION=OFF call.
- **print_critical_ohko.asm** (PrintCriticalOHKOText). Structural port adaptation (not behavioral):
  pret `dw`/×2 pointer table → `dd`/×4 for 32-bit flat text addresses; `DelayFrames` count in BL.
- **display_effectiveness.asm** (DisplayEffectiveness). Divergence: SuperEffective/NotVeryEffective
  text hand-authored inline in .data (Tier-2) — not emitted by gen_battle_text.py (its SRC_FILES
  omits display_effectiveness.asm; that generator is Owner C). Bytes are pret-charmap faithful.
- **print_move_failure.asm** (PrintMoveFailureText). Wired at both inline miss-sites in core.asm
  (replaced the `AttackMissedText`/`PrintBattleText` stand-in). Divergence: allowlist predef→flat —
  `predef PredefShakeScreenHorizontally` → `call PredefShakeScreenHorizontally` (a new no-op stub in
  core_stubs.asm; TODO-HW real shake, consistent with ANIMATION=OFF). GLITCH preserved (comment, no
  gate): Jump Kick/Hi Jump Kick crash recoil is always exactly 1 HP (wDamage=0 → damage/8 → min-1).
  Added `global ApplyDamageTo{Enemy,Player}Pokemon` in core.asm (tail targets for the recoil).
- **ghost.asm** (PrintGhostText + IsGhostBattle). Faithful instruction-for-instruction; `IsItemInBag`
  (BH=item id, ZF=1 if absent) matches pret polarity exactly. Divergences: none. Linked its closure:
  moved home/item_predicates.asm from check-only into the EXE and added engine/items/get_bag_item_quantity.asm.
- **exploding_animation.asm** (HandleExplodingAnimation). Tail-jumps the port's PlayMoveAnimation
  (ANIMATION=OFF) with MEGA_PUNCH (==ANIMATIONTYPE_SHAKE_SCREEN_HORIZONTALLY_LIGHT). Preserved pret's
  quirk of reading wEnemyBattleStatus1 in BOTH turn branches (verbatim + comment). Divergence: anim allowlist.

Verify-only (no code change; confirmed correct end-to-end):
- **EXPLODE self-faint**: ExplodeEffect_ (move_effects/explode.asm, faithful) is dispatched via
  AlwaysHappenSideEffects ($07) from the core `.notDone` path, so Explosion/Self-Destruct faints the
  user on both hit and miss.
- **Charging-move flow**: CheckIfNeedsToChargeUp → JumpMoveEffect → ChargeEffect_ ($27 CHARGE / $2B FLY)
  on turn 1; PlayerCanExecuteChargingMove clears CHARGING_UP/INVULNERABLE on turn 2. Structurally wired
  and untouched by these leaves (full 2-turn live playthrough still the remaining confidence gap).

## Battle text & HUD pacing (battle-swarm B — message-overrun / HP-bar drain)
- Source: engine/battle/core.asm (UpdateCurMonHPBar / ApplyAttackTo{Enemy,Player}Pokemon
  drain tails / PrintCriticalOHKOText), engine/gfx/hp_bar.asm (UpdateHPBar/UpdateHPBar2
  drain loop), engine/battle/display_effectiveness.asm, data/text/text_2.asm
  (_SuperEffectiveText / _NotVeryEffectiveText)
- Translated: dos_port/src/engine/battle/battle_hud.asm (AnimateHPBar, DrawEnemyHUDAndHPBar),
  move_effect_helpers.asm (UpdateCurMonHPBar), core.asm (ApplyAttackTo* tails),
  core_stubs.asm (PrintCriticalOHKOText, DisplayEffectiveness + the two effectiveness streams)
- Date: 2026-07-01
- H-flag: not involved
- Bug tags: none new. Preserves the existing Gen-1 maxHP>=256 lossy-÷4 HP-bar quirk
  (battle_hud.asm hp_to_pixels, BUG_FIX_LEVEL<2 gate) unchanged.
- Divergences (allowlist / hardware): DrawEnemyHUDAndHPBar drops pret's
  hAutoBGTransferEnabled bracket (gates the dropped GB torus-tilemap DMA the native
  render_bg doesn't use; the overworld keeps it disabled — forcing it on would run a
  pointless per-frame copy) and pret's leading ClearScreenArea (home/copy2.asm not linked
  into the battle EXE; only relevant to enemy-name-length changes on a multi-mon switch,
  unreachable in a wild battle). CenterMonName (never ported → short enemy names print
  flush-left), status-condition-vs-level on the enemy HUD (status_ailments.asm is an empty
  placeholder → always prints level), and the GetBattleHealthBarColor/RunPaletteCommand
  recolor tail (Phase-5 palette deferral) remain pre-existing tracked gaps.
- Notes: Fixes "battle messages run over each other / the menu races the last line."
  Root cause was three stubbed inter-message pauses: (1) UpdateCurMonHPBar redrew the bar
  instantly (jmp DrawHUDsAndHPBars); now selects the bar by hWhoseTurn and drains via the
  gradual Animate{Player,Enemy}HPBar (reading wHPBarOldHP, populated by every caller). The
  direct-attack path (ApplyAttackTo{Enemy,Player}Pokemon) previously fell through to a bare
  ret; now drains its own side + jp DrawHUDsAndHPBars, matching pret. (2) AnimateHPBar was
  made faithful to pret UpdateHPBar cadence: it now walks every intermediate pixel (2 frames
  each) instead of jumping to the final pixel, ticks the HP number every HP unit with a
  per-unit DelayFrame (player HUD), and adds the trailing Delay3 settle; a genuine zero-delta
  call still no-ops. (3) PrintCriticalOHKOText and DisplayEffectiveness were no-op stubs —
  pret shows AND button-waits on "Critical hit!"/"One-hit KO!"/"It's super effective!"/
  "...not very effective..." as acknowledged beats between the used-move line and the next
  mon's move; both now print via the shared PrintText (<PROMPT> wait) with pret's 20-frame
  settle. SuperEffectiveText/NotVeryEffectiveText are hand-authored in code (Tier-2; the
  generator does not emit them) with the exact pret charmap bytes. The <PROMPT>/BattlePromptWait
  plumbing and the between-message text-box clear were audited and already faithful — no change.
- FLAGGED for Master A (out of pacing lane): observed on this isolated branch that MoveHitTest
  (core_damage.asm) makes ~all attacks miss on BOTH sides, which blocks watching the HP-drain
  pacing end-to-end here. The accuracy compare itself is faithful (BattleRandom >= accuracy ->
  miss); the likely root cause is the move-accuracy value scale (Gen-1 stores 100% as byte 255
  via `percent` = *255/100; if the move data or CalcHitChance leaves it as raw percent 100,
  random 0-255 >= 100 misses ~61%). This is Master A's damage-core lane and A is running
  concurrently — it is likely already fixed on A's branch and will resolve on merge; branch B
  is off pre-swarm master and simply lacks A's fixes. No pacing-side change needed.
- INTEGRATION (battle-swarm-integration, 2026-07-01): PrintCriticalOHKOText and
  DisplayEffectiveness were implemented identically by BOTH A (dedicated files
  print_critical_ohko.asm / display_effectiveness.asm) and B (inline in core_stubs.asm) —
  a duplicate-global collision. Resolved in A's favor (its file-per-leaf lane per the swarm
  partition); B's inline copies + inline Super/NotVeryEffectiveText streams were dropped as
  byte-identical redundant. B's genuine pacing work (HP-bar drain in battle_hud.asm /
  UpdateCurMonHPBar in move_effect_helpers.asm / the ApplyAttackTo* drain tails in core.asm)
  is unaffected. The <PROMPT> beats B intended are delivered by A's identical routines.
- INTEGRATION FIX (crash, live-verify): battle-swarm-C faint_leaves.asm AnyEnemyPokemonAliveCheck
  widened pret's 8-bit loop counter (`ld b,a` / `dec b`) to 32-bit `dec ecx`. On a wild faint
  (wEnemyPartyCount==0) `dec ecx` wraps 0→0xFFFFFFFF → ~4 billion iterations, walking ESI off the
  ~96 KB GB allocation → page fault (register-confirmed: ebp=0x70000, esi=0x22010, cr2=0x10092010,
  ecx=0xfffff88f, eip in AnyEnemyPokemonAliveCheck). Fixed to `dec cl` (8-bit wrap at 256, bounded
  in GB RAM), matching pret and the sibling ChooseNextMon's `dec bl`. SECONDARY (open): a wild
  battle should not reach this routine at all — HandleEnemyMonFainted's `wIsInBattle; dec al; jz`
  guard fell through (wIsInBattle != 1 at faint despite init_battle.asm:88); needs a runtime read.

---

## Battle swarm — SUBSYSTEM C (faint/switch lifecycle, multi-mon, AI wiring, obedience)
- **Date:** 2026-07-01
- **Branch:** battle-swarm-C. Opus master + Sonnet worker/auditor swarm.
- **Build:** green at BUG_FIX_LEVEL 0 and 2 (`make SKIP_TITLE=1 DEBUG_BATTLE_LIVE=1`) + `make check`.

### CheckForDisobedience — Yellow traded-mon obedience
- Source: pret `engine/battle/core.asm:4001-4178`. Translated: `dos_port/src/engine/battle/core.asm`.
- H-flag: not involved. Bug tags: none (faithful).
- Divergences: none (faithful). Text via PrintBattleText (EAX ptr); HandleSelfConfusionDamage
  is core.asm-local.
- Notes: full badge/level ladder + RNG-consumption order preserved. **Audit-caught CRITICAL,
  fixed:** the `.monDoesNothing` flavor-text selector loaded `mov eax,<TextLabel>` (clobbering
  AL, which held the BattleRandom roll) before testing it — on SM83 `ld hl,imm16` leaves A
  intact. Fixed by parking the roll in DL and testing DL. Local equs (wObtainedBadges=0xD355,
  wPartyMon1OTID, badge bits) kept file-local (badge_boosts.asm also defines wObtainedBadges).

### HandleEnemyMonFainted / HandlePlayerMonFainted — faint/switch state machines
- Source: pret `engine/battle/core.asm:708-739` / `981-1012`. Translated: `core.asm`.
- Divergences: ANIMATION=OFF/audio/palette leaves stubbed (§2). Player switch-in uses an
  auto-pick-first-live-mon stand-in for the deferred interactive BattlePartyMenu.
- Notes: AnyPartyAlive returns alive-flag in DH; double-KO player-switch sub-branch (pret
  725-731) ported faithfully (audit finding 2). No double EXP/print — FaintEnemyPokemon owns both.

### FaintEnemyPokemon (+ EXP-ALL) — enemy-faint state
- Source: pret `engine/battle/core.asm:741-867`. Translated: `dos_port/src/engine/battle/faint_enemy.asm`.
- Bug tags: BUG(critical) — Gen-1 half-zeroed wPlayerBideAccumulatedDamage (high byte only)
  preserved at level 0, both bytes zeroed at BUG_FIX_LEVEL>=1.
- Divergences: SlideDownFaintedMonPic (ANIMATION=OFF), faint SFX/victory music (audio HAL, §2).
- Notes: trainer party-slot HP zero via AddNTimes; full EXP-ALL dispatch (halve base stats,
  award to fought mons, re-award whole party). Auditor verified offset-7 untouched.

### LoadBattleMonFromParty / AnyEnemyPokemonAliveCheck — `faint_leaves.asm`
### LoadEnemyMonFromParty — `load_enemy_from_party.asm`
- Source: pret `core.asm:1667-1708 / 883-900 / 1711-1762`. Divergences: none (faithful).
- Notes: chunked CopyData with the `add hl, MON_DVS - MON_OTID` skip preserved verbatim —
  the party struct's offset-7 (MON_CATCH_RATE / Gen-2 held item) is read-only source, never
  written back (auditor-verified against pret struct layout).

### EnemySendOut / ReplaceFaintedEnemyMon / TrainerBattleVictory — `faint_sendout.asm`
- Source: pret `core.asm:1315-1482 / 901-927 / 929-963`.
- Divergences: §2 — battle-"shift" switch prompt treated as SET (no prompt, no SwitchPlayerMon);
  SlideTrainerPicOffScreen / AnimateSendingOutMon / PlayCry / DrawEnemyPokeballs (ANIMATION=OFF);
  RunPaletteCommand (palette HAL); victory music (audio); TrainerDefeatedText not yet generated.
  Prize money via flat AddBCD (predef bank call dropped, §2 item 4).
- Notes: next-live-enemy-mon scan faithful; control flow correct once ReadTrainer seeds full
  enemy party structs (DEBUG_BATTLE_TRAINER harness seeds only HP).

### SelectEnemyMove → AIEnemyTrainerChooseMoves wiring; TrainerAI/ReadTrainer linked
- Source: pret `core.asm:3138-3141`. Translated: `select_enemy_move.asm`; Makefile.
- Divergences: none (faithful). Notes: trainer_ai.asm + read_trainer_party.asm moved from
  check-only into the live EXE (their closures resolve); the core_stubs.asm TrainerAI stub
  removed (superseded by the real class-based AI). AddBCDPredef_stub → real AddBCD (prize money).
  copy2.asm/item_predicates.asm/get_bag_item_quantity.asm promoted to LINK_SRCS (faint_enemy
  consumers landed). ESI carries the AI's move-candidate buffer into the random pick (audit-confirmed).
