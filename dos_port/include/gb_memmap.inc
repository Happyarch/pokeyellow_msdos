; gb_memmap.inc — EBP-relative offsets for the emulated Game Boy address space.
; Source of truth: constants/hardware.inc and the GB memory map specification.
; Emitted as %define (a preprocessor MACRO), not equ. NASM emits every `equ` as a
; local ABSOLUTE COFF symbol -- without `global`, and whether or not the file uses
; it -- so a shared constants header lands its whole contents in EVERY object that
; includes it. Measured 2026-08-19: that was ~2.05M symbol entries and 39 MB of a
; 41 MB PKMN.EXE, against ~2.4 MB of real .text+.data. A %define expands textually,
; emits no symbol, and generates byte-identical code. Constants are not code
; addresses: none of them ever appeared in pkmn.sym, so nothing debuggable is lost.
; All offsets are relative to EBP (the base of the DPMI allocation sized by GB_TOTAL_SIZE in boot/entry.asm).
; See docs/references/pandocs/Memory_Map.md for the authoritative address table.

%ifndef GB_MEMMAP_INC
%define GB_MEMMAP_INC

; ---------------------------------------------------------------------------
; GB address space regions (EBP + offset)
; ---------------------------------------------------------------------------

; VRAM bank 0 — $8000–$9FFF (8 KB)
; Contains tile data (chars) and BG tilemaps. Accessible by CPU except during
; PPU Mode 3 (Drawing). CGB has a second bank (GB_VRAM1 below).
%define GB_VRAM0                     0x8000

; VRAM tile-data sub-regions (pret labels vChars0/1/2). Each is 128 tiles.
; The font is loaded to vFont ($8800); in $8800-signed addressing (LCDC_DEFAULT)
; tile index C ('A'=$80) -> $9000 + sext8(C)*16 = $8800 + (C-$80)*16 = vFont.
; So char codes index tiles directly — a string drops straight into a tilemap.
%define GB_VCHARS0                   0x8000   ; vChars0  — sprite/overworld tiles
%define GB_VFONT                     0x8800   ; vFont / vChars1 — text font (char $80 = 'A')
%define GB_VCHARS2                   0x9000   ; vChars2 / vTileset — tileset, box graphics

; BG tilemap 0 — $9800–$9BFF (1 KB)
; 32x32 tile indices; each byte is an index into the tile data.
; Matches TILEMAP0 (0x9800) in constants/hardware.inc.
%define GB_TILEMAP0                  0x9800

; BG tilemap 1 — $9C00–$9FFF (1 KB)
; Matches TILEMAP1 (0x9C00) in constants/hardware.inc.
%define GB_TILEMAP1                  0x9C00

; pret's own spellings for the VRAM region (ram/vram.asm), as ALIASES alongside
; the GB_* names above rather than in place of them — the "Preserve pret Labels"
; rule's prescribed form. The GB_* names are load-bearing across the port and its
; tools; these exist so pret source that names a VRAM label translates without
; the reader having to know the port renamed it. vSprites/vFont are pret UNION
; overlays of vChars0/vChars1, which is why they share addresses.
%define vChars0                      0x8000
%define vChars1                      0x8800
%define vNPCSprites2                 (vChars1)   ; pret ram/vram.asm overworld UNION arm — same bytes
%define vChars2                      0x9000
%define vSprites                     0x8000   ; NEXTU battle/menu — overlays vChars0
%define vFont                        0x8800   ; NEXTU battle/menu — overlays vChars1
%define vBGMap0                      0x9800
%define vBGMap1                      0x9C00

; --- Unified window-compositor descriptor (see docs/current_plan_window_compositor.md) ---
; An ordered painter's-order list of window-layer boxes. render_window draws ONE
; descriptor per call; src/home/vblank.asm loops g_window_count of them (later
; entries draw on top). These are field offsets within one descriptor; the actual
; storage (g_windows[]/g_window_count) and the set_single_window helper live in
; src/ppu/ppu.asm. A screen fully (re)defines the list on entry/state-change.
%define WIN_WX                       0   ; dd: window left edge in WX units (screen-left col = WX-7)
%define WIN_WY                       4   ; dd: window top edge (screen-Y px); >= RENDER_H hides it
%define WIN_CLIP_W                   8   ; dd: visible width in px (cols blitted from row_buf)
%define WIN_MAX_Y                    12   ; dd: first screen row the box stops drawing at (exclusive)
%define WIN_TILEMAP                  16   ; dd: EBP-relative tilemap base (GB_TILEMAP0 / GB_TILEMAP1)
%define WIN_START_ROW                20   ; dd: tilemap row that WLY=0 maps to (the box's first src row)
; Fine SOURCE scroll offsets, in pixels, default 0 (docs/ui_projection.md).
; They move the SOURCE the window samples, never the projected destination
; rectangle. Sampling wraps modulo 256 px / 32 tiles WITHIN the single tilemap
; WIN_TILEMAP names — exactly what the GB PPU does; it never walks past the map
; boundary into the adjacent tilemap. Cinematic BG scrolling (the title bounce
; via hSCY, Yellow-intro cloud/bar scrolling via hSCX) is presented through
; these; whole-tile remirroring would quantize the motion and moving the
; destination would expose content outside the projected surface.
; At 0/0 render_window takes its original unwrapped path, so every descriptor
; that predates this feature is pixel- and cost-identical.
%define WIN_SRC_X                    24   ; dd: horizontal source offset, px (0..255)
%define WIN_SRC_Y                    28   ; dd: vertical source offset, px (0..255)
%define WIN_DESC_SIZE                32   ; bytes per descriptor (8 dwords)
%define MAX_WINDOWS                  6   ; bag needs <=4 simultaneously (list + sub-menu/qty + dialog)

; WRAM bank 0 — $C000–$CFFF (4 KB)
; Always available. General-purpose work RAM.
%define GB_WRAM0                     0xC000
%define W_PARTY_MON4_MOVES           0xD1F6
%define wPlayerMoney                 0xD346   ; 3-byte BCD (trainer-card money display)
%define wObtainedBadges              0xD355
; wTrainerCardBadgeAttributes — pret ram/wram.asm. READ ONLY by
; HandleBadgeFaceAttributes, and pret never writes it under this name: it is a
; UNION member sharing these bytes with the misc battle-data block
; (wEnemyBideAccumulatedDamage / wEnemyNumHits) and with wPikaPicUsedGFXCount /
; wPikaPicUsedGFX. The port models GB memory FLAT, so that aliasing reproduces
; itself here for free — same byte, same address, exactly as on hardware.
%define wTrainerCardBadgeAttributes  0xCC5D
%define wObtainedHiddenItemsFlags    0xD6EF
%define wRivalStarter                0xD714
; --- Surfing Minigame WRAM data (pret ram/wram.asm:222-264) ---
; Addresses read from pokeyellow.sym (00:c5d0-00:c637), never inferred.
%define wSurfingMinigameData         0xC5D0   ; db
%define wSurfingMinigameRoutineNumber 0xC5D1   ; db
%define wSurfingMinigamePikachuState 0xC5D2   ; db
%define wSurfingMinigameWaveFunctionNumber 0xC5D3   ; dw
%define wSurfingMinigameWaveRandomValue 0xC5D5   ; db
%define wSurfingMinigamePikachuHP    0xC5D6   ; dw (little-endian BCD)
%define wSurfingMinigameRadnessMeter 0xC5D9   ; db (number of consecutive tricks)
%define W_SURFING_MINIGAME_RADNESS_MTR (wSurfingMinigameRadnessMeter)   ; legacy alias
%define wSurfingMinigameRadnessScore 0xC5DA   ; dw (little-endian BCD)
%define W_SURFING_MINIGAME_RADNESS_SCR (wSurfingMinigameRadnessScore)   ; legacy alias
%define wSurfingMinigameTotalScore   0xC5DC   ; dw (little-endian BCD)
%define wSurfingMinigameBoardAngleOffset 0xC5DE   ; db
%define wSurfingMinigameBoardAngleDecreasing 0xC5DF   ; db
%define wSurfingMinigameBoardAngleTimer 0xC5E0   ; db
%define wSurfingMinigameCrashTimer   0xC5E1   ; db
%define wSurfingMinigameUnusedToggle 0xC5E2   ; db
%define wSurfingMinigamePikachuSpeed 0xC5E3   ; dw (little-endian)
%define wSurfingMinigameDistance     0xC5E5   ; ds 3 (big-endian)
%define wSurfingMinigameWaveHeightBuffer 0xC5E8   ; dw
%define wSurfingMinigamePikachuObjectHeight 0xC5EA   ; db
%define wSurfingMinigameWaterSprayCounter 0xC5EB   ; db
%define wSurfingMinigameJumpArcMagnitude 0xC5EC   ; db
%define wSurfingMinigameJumpDescending 0xC5ED   ; db
%define wSurfingMinigameJumpArcFraction 0xC5EE   ; db
%define wSurfingMinigameBGMapReadBuffer 0xC5EF   ; ds 1 tiles + 24 = 40 bytes
%define wSurfingMinigameSCX          0xC617   ; db
%define wSurfingMinigameSCX2         0xC618   ; db
%define wSurfingMinigameSCXHi        0xC619   ; db
%define wSurfingMinigameWaveHeight   0xC61A   ; ds SCREEN_WIDTH (20 bytes)
%define wSurfingMinigameXOffset      0xC62E   ; db
%define wSurfingMinigameTrickFlags   0xC62F   ; db
%define wSurfingMinigameGameOver     0xC630   ; db
%define wSurfingMinigameGameOverDelay 0xC631   ; db
%define wSurfingMinigameRoutineDelay 0xC632   ; db
%define wSurfingMinigameIntroAnimationFinished 0xC633   ; db
; Shared with Yellow intro (unioned in pret)
%define wSurfingMinigameMusicTempoEnabled 0xC634   ; db
%define wSurfingMinigameCloudScrollFraction 0xC635   ; db
%define wSurfingMinigameDataEnd      0xC637   ; extent end
%define wSurfingMinigameHiScore      0xD494   ; ds 3 (BCD)

%define wSlotMachineWheel2Offset     0xCD3F
%define wSlotMachineWheel3Offset     0xCD40
%define wSlotMachineWheel1BottomTile 0xCD41
%define wSlotMachineWheel1MiddleTile 0xCD42
%define wSlotMachineWheel1TopTile    0xCD43
%define wSlotMachineWheel2BottomTile 0xCD44
%define wSlotMachineWheel2MiddleTile 0xCD45
%define wSlotMachineWheel2TopTile    0xCD46
%define wSlotMachineWheel3BottomTile 0xCD47
%define wSlotMachineWheel3MiddleTile 0xCD48
%define wSlotMachineWheel3TopTile    0xCD49
%define wSlotMachineFlags            0xCD4C
%define wSlotMachineWheel1SlipCounter 0xCD4D
%define wSlotMachineWheel2SlipCounter 0xCD4E
%define wSlotMachineAllowMatchesCounter 0xD095

; --- pret-named aliases for the slots / hidden-event bytes above -------------
; The W_SLOT_MACHINE_* names are the port's legacy convention and stay as the
; primary spelling for the files already using them; these are the pret labels
; for the SAME addresses, so engine/slots/ can be a literal pret mirror. Adding
; alongside, never renaming (CLAUDE.md "Preserve pret Labels").
; Addresses verified against pokeyellow.sym, not inferred.
%define wSlotMachineSevenAndBarModeChance 0xCC5B   ; == wSlotMachineSevenAndBarModeChance
%define wSlotMachineSavedROMBank     0xCC5E
%define wLuckySlotHiddenEventIndex   0xCD05
%define wHiddenEventIndex            0xCD3F   ; == wSlotMachineWheel2Offset (union)
%define wSpritePlayerStateData1ImageIndex 0xC102   ; player sprite slot, +2 = ImageIndex

; *** wHiddenEventFunctionArgument and wCanPlaySlots ARE THE SAME BYTE ($CD3D),
; and the slots path depends on reading one BEFORE the other overwrites it. ***
; StartSlotMachine reads wHiddenEventFunctionArgument to pick the out-of-order /
; out-to-lunch / someone's-keys message, THEN calls AbleToPlaySlotsCheck, whose
; every exit does `ld [wCanPlaySlots], a` — clobbering the byte it just read.
; That ordering is pret's and is correct there because the argument is spent by
; then; it is recorded because a reordering that looks harmless is not.
; wDayCareStartLevel (below) is a third alias of the same address.
%define wHiddenEventFunctionArgument 0xCD3D
%define wCanPlaySlots                0xCD3D
%define W_LOADED_MON_EXP             0xCFA5

; ---------------------------------------------------------------------------
; Pokémon data engine — lowercase pret-name aliases (Pokémon data/stats plan).
; CLAUDE.md mandates pret names; the engine drafts (add_mon/load_mon_data/
; calc_stats/…) reference these lowercase labels. Addresses derived from the
; verified anchors above (wCurSpecies $D0B4, wPartyCount $D162) + the struct
; layout in macros/ram.asm. wMonHeader region (no overlaps) added first; the
; loaded/enemy/box/daycare aliases land in Stage 5 once a pokeyellow.sym confirms
; their cross-section addresses.
; ---------------------------------------------------------------------------
%define wCurSpecies                  0xD0B4
; wMonHeader region — addresses now pinned to pokeyellow.sym (symbols branch).
; The whole block was previously off by one (too high): wMonHeader read $D0B8,
; but the sym (and hand-derivation from ram/wram.asm) put it at $D0B7. The error
; was masked because every CalcStats/GetMonHeader/add_party_mon validation
; harness is self-contained (the writer and reader share the same constant), so
; the computed stats were correct in isolation while the absolute placement was
; one byte high — i.e. it would corrupt the byte past wMonHeaderEnd and read the
; wrong cells once integrated with real game WRAM. Corrected here.
%define wMonHeader                   0xD0B7
%define wMonHIndex                   0xD0B7
%define wMonHBaseStats               0xD0B8
%define wMonHBaseHP                  0xD0B8
%define wMonHBaseAttack              0xD0B9
%define wMonHBaseDefense             0xD0BA
%define wMonHBaseSpeed               0xD0BB
%define wMonHBaseSpecial             0xD0BC
%define wMonHTypes                   0xD0BD
%define wMonHType1                   0xD0BD
%define wMonHType2                   0xD0BE
%define wMonHCatchRate               0xD0BF
%define wMonHBaseEXP                 0xD0C0
%define wMonHSpriteDim               0xD0C1
%define wMonHFrontSprite             0xD0C2
%define wMonHBackSprite              0xD0C4
%define wMonHMoves                   0xD0C6
%define wMonHGrowthRate              0xD0CA   ; sym-verified; NOT $D0CB (see wMonHGrowthRate note above)
%define wMonHLearnset                0xD0CB
%define wCurEnemyLevel               0xD126   ; CalcStat level input
%define wCurPartySpecies             0xCF90
%define wWhichPokemon                0xCF91
%define wMonDataLocation             0xCC49
%define wRemoveMonFromBox            0xCF94   ; = wRemoveMonFromBox (0=party, !=0=box)
%define wLearningMovesFromDayCare    0xCEE9   ; WriteMonMoves daycare gate (0 = normal)
%define wDayCareStartLevel           0xCD3D   ; WriteMonMoves daycare min-level check
%define wPokedexNum                  0xD11D   ; SetPartyMonTypes input (sym)
%define wPartyCount                  0xD162
%define wPartySpecies                0xD163   ; wPartyCount+1; 6 species + $FF sentinel
%define wPartyMons                   0xD16A
%define wPartyMonOT                  0xD272
%define wEnemyMonOT                  0xD9AB   ; enemy OT-name list (NamePointers ENEMYOT; sym)
%define wPartyMonNicks               0xD2B4
%define wPartyMonNicksEnd            0xD2F6
%define wPlayerName                  0xD157   ; = wPlayerName (OT name source)

; Predef register save slots (home/predef.asm:GetPredefRegisters). Big-endian:
; [addr] = high byte, [addr+1] = low byte.
%define wPredefHL                    0xCC4F
%define wPredefDE                    0xCC51
%define wPredefBC                    0xCC53

; --- item bag / PC inventory (engine/items/inventory.asm) ---
; An inventory is: db count, then (item id, quantity) pairs, then $FF terminator.
%define wNumBagItems                 0xD31C
%define wBagItems                    0xD31D
%define wNumBoxItems                 0xD539   ; PC item storage
%define wBoxItems                    0xD53A
%define wCurItem                     0xCF90   ; = wCurPartySpecies (shared "current" slot)
%define wItemQuantity                0xCF95
%define wMaxItemQuantity             0xCF96
; --- item-use effect scratch (engine/items/item_effects.asm) ---
; --- battle-transition scratch (engine/battle/battle_transitions.asm) ---
; All on the established 0xCD3D union scratch lane (modal transition, nothing
; else on the lane is live while it runs); pret ram/wram.asm:812-827 places them
; in the same NEXTU union.
%define wBattleTransitionCircleScreenQuadrantY 0xCD3D   ; 0 = upper half, 1 = lower half
%define wBattleTransitionCircleScreenQuadrantX 0xCD3E   ; CIRCLE_LEFT / CIRCLE_RIGHT
%define wBattleTransitionCopyTilesOffset 0xCD3D   ; dw — offset to the next row/column to copy
%define wInwardSpiralUpdateScreenCounter 0xCD3D   ; counts down (port: from 19) between TransferDelay3s
%define wBattleTransitionSpiralDirection 0xCD47   ; 0 = outward, 1 = inward (pret: union +10)
; wOutwardSpiralTileMapPointer: pret splits the tilemap pointer over two db
; stores (h/l). The port stores it as ONE 16-bit GB tilemap offset word (the
; wMenuCursorLocation precedent, window.asm) at pret's address — same 2-byte
; footprint 0xD099-0xD09A pret's `+ 1` stores use.
%define wOutwardSpiralTileMapPointer 0xD099
%define wOutwardSpiralCurrentDirection 0xD09E   ; pret union slot (= wNewTileBlockID lane)
%define wPPRestoreItem               0xCD3D   ; which Ether/Elixer item is being used
%define wWereAnyMonsAsleep           0xCD3D   ; Poke Flute: set if a party mon woke (aliased)
%define wChargeMoveNum               0xCD3D   ; charge move number (aliased union lane)
%define wDexMaxSeenMon               0xCD3D   ; pokedex.asm: highest seen dex # (aliased union lane, S8)
%define wBoxNumString                0xCD3D   ; bills_pc.asm: 3-byte "##"/spaces box-number text spliced into MonWasStoredText (aliased union lane, pret ram/wram.asm:809)
%define wRodResponse                 0xCD3D   ; fishing: 0 no bite, 1 bite, 2 no fish (aliased
                                    ; union lane — unions with wPPRestoreItem above and
                                    ; the wFlyAnimUsingCoordList / wPlayerSpin* scratch;
                                    ; promoted from a player_animations.asm local shadow,
                                    ; backlog #25)
%define wMaxPP                       0xD11D   ; max PP of the move being PP-restored
; --- item-use dispatch state (engine/items/item_effects.asm:UseItem_) ---
%define wPseudoItemID                0xD151   ; nonzero = a move/field action is impersonating
                                    ; an item (Softboiled/Dig/Surf); suppresses the
                                    ; item consumption + menu teardown in ItemUse*
%define wUsedItemOnWhichPokemon      0xCF06   ; party index the item was applied to (the party
                                    ; menu's own wWhichPokemon is restored after)
; Menu state these routines reset (plain WRAM writes; the rendering is elsewhere).
%define wListScrollOffset            0xCC36
%define wTopMenuItemY                0xCC24   ; cursor Y of menu item id 0
%define wTopMenuItemX                0xCC25   ; cursor X of menu item id 0
%define wCurrentMenuItem             0xCC26
%define wTileBehindCursor            0xCC27   ; tile the cursor overwrote (for erase)
%define wBagSavedMenuItem            0xCC2C
%define wSavedListScrollOffset       0xD07D   ; = wSavedListScrollOffset
%define wListCount                   0xD129   ; = wListCount
%define wMaxMenuItem                 0xCC28
%define wMenuWatchedKeys             0xCC29   ; bit mask of keys the menu responds to
%define wLastMenuItem                0xCC2A   ; previously selected menu item
%define wMenuItemToSwap              0xCC35   ; SELECT-swap selection (0 = none); 1-based
%define wBattleAndStartSavedMenuItem 0xCC2D   ; remembered battle/START cursor (reset each battle)

; Loaded-mon + enemy / current-box / daycare aliases — the Stage 1 cross-section
; deferrals, now resolved against pokeyellow.sym (symbols branch).
%define wLoadedMon                   0xCF97   ; LoadMonData_ destination (party_struct)
%define wEnemyPartyCount             0xD89B
%define wLinkEnemyTrainerName        0xD886
%define wEnemyPartySpecies           0xD89C   ; PARTY_LENGTH+1 species + $FF sentinel
%define wEnemyMons                   0xD8A3
%define wDayCareMon                  0xDA5E   ; box_struct (wDayCareMonSpecies = first byte)
%define wDayCareMonSpecies           0xDA5E
%define wDayCareMonExp               0xDA6C   ; wDayCareMon + MON_EXP (3-byte big-endian EXP; IncrementDayCareMonExp)
%define wBoxCount                    0xDA7F
%define wBoxSpecies                  0xDA80   ; MONS_PER_BOX+1 species + $FF sentinel
%define wBoxMons                     0xDA95
%define wBoxMon1                     0xDA95   ; = wBoxMons (pikachu_status alias)
%define wBoxMon2                     0xDAB6   ; wBoxMon1 + BOXMON_STRUCT_LENGTH (33)
%define wBoxMon1CatchRate            0xDA9C   ; = wBoxMon1 + MON_CATCH_RATE (Gen-2 held-item slot)
%define wBoxMonOT                    0xDD29
%define wBoxMon1OT                   0xDD29   ; = wBoxMonOT (first OT-name slot; SendNewMonToBox)
%define wBoxMonNicks                 0xDE05
%define wBoxMon1Nick                 0xDE05   ; = wBoxMonNicks (first nickname slot; SendNewMonToBox)
%define wBoxMonNicksEnd              0xDEE1
%define wNumSafariBalls              0xDA46   ; Safari Zone ball count (ItemUseBall decrements it)
%define wSafariZoneGateCurScript     0xD61E   ; Safari gate script index (ItemUseEscapeRope resets it
                                    ; to SCRIPT_SAFARIZONEGATE_DEFAULT) — sym-verified

; --- ItemUseBall (catching) scratch, pret wram.asm ---
%define wCapturedMonSpecies          0xD11B   ; species just caught (0 = nothing caught this throw)
%define wPokeBallAnimData            0xD11D   ; the throw's outcome/shake code ($10/$20/$61-$63/$43)
%define wPokeBallCaptureCalcTemp     0xD11D   ; = wPokeBallAnimData (pret unions them; X is stashed
                                    ; here only across the failed-capture shake math, which
                                    ; writes wPokeBallAnimData afterwards — never both live)

; ===========================================================================
; Battle engine WRAM aliases (current_plan_battle_engine.md)
; All sym-pinned (git show origin/symbols:pokeyellow.sym, bank 00).
; ===========================================================================

; --- selected / used moves and per-side move scratch ($CCxx) ---
%define wPlayerMoveListIndex         0xCC2E
%define wPlayerMonNumber             0xCC2F   ; party index of the active player mon
%define wPlayerSubstituteHP          0xCCD7
%define wEnemySubstituteHP           0xCCD8
%define wMoveMenuType                0xCCDB
%define wPlayerSelectedMove          0xCCDC
%define wEnemySelectedMove           0xCCDD
%define wEnemyMoveListIndex          0xCCE2
; The enemy mon's HP when it (or the current player mon) was last switched in,
; whichever was more recent — big-endian word, pret ram/wram.asm:619. Read only
; by PlayerMon2Text, which turns the drop since then into the switch-out message
; (Enough / Come back / OK! / Good). ADDRESS VERIFIED against pokeyellow.sym
; (`00:cce3 wLastSwitchInEnemyMonHP`), not inferred from its neighbours.
%define wLastSwitchInEnemyMonHP      0xCCE3   ; dw
%define wTotalPayDayMoney            0xCCE5   ; Pay Day running total (BCD, 3 bytes)
%define wTransformedEnemyMonOriginalDVs 0xCCEB   ; Transform: saved target DVs (word)
%define wPlayerDisabledMoveNumber    0xCCEE
%define wEnemyDisabledMoveNumber     0xCCEF
%define wInHandlePlayerMonFainted    0xCCF0
%define wPlayerUsedMove              0xCCF1
%define wEnemyUsedMove               0xCCF2
%define wEnemyMonMinimized           0xCCF3
%define wMonIsDisobedient            0xCCED
%define wMoveDidntMiss               0xCCF4
%define wPlayerMonMinimized          0xCCF7

; --- enemy "Bide"/multi-hit accumulators ($CD05) ---
%define wEnemyBideAccumulatedDamage  0xCD05
%define wEnemyNumHits                0xCD05

; --- unmodified (pre-stat-stage) stats, player ($CD0F) ---
%define wPlayerMonUnmodifiedLevel    0xCD0F
%define wPlayerMonUnmodifiedMaxHP    0xCD10
%define wPlayerMonUnmodifiedAttack   0xCD12
%define wPlayerMonUnmodifiedDefense  0xCD14
%define wPlayerMonUnmodifiedSpeed    0xCD16
%define wPlayerMonUnmodifiedSpecial  0xCD18
; --- player stat-stage modifiers (6 bytes, base value 7) ---
%define wPlayerMonStatMods           0xCD1A
%define wPlayerMonAttackMod          0xCD1A
%define wPlayerMonDefenseMod         0xCD1B
%define wPlayerMonSpeedMod           0xCD1C
%define wPlayerMonSpecialMod         0xCD1D
%define wPlayerMonAccuracyMod        0xCD1E
%define wPlayerMonEvasionMod         0xCD1F
%define wPlayerMonStatModsEnd        0xCD22

; --- in-game trade scratch ($CD0F, NEXTU with the unmodified-stats block) ---
; pret ram/wram.asm unions the in-game-trade working set over the battle
; stat-stage scratch above: a trade and a battle never run at once. Addresses are
; rgblink's, read from pokeyellow.sym, not inferred. NAME_LENGTH is 11, which is
; what spaces the three name buffers ($CD13 -> $CD1E -> $CD29 -> $CD34).
%define wInGameTradeGiveMonSpecies   0xCD0F
%define wInGameTradeTextPointerTablePointer 0xCD10
%define wInGameTradeTextPointerTableIndex 0xCD12
%define wInGameTradeGiveMonName      0xCD13
%define wInGameTradeReceiveMonName   0xCD1E
%define wInGameTradeMonNick          0xCD29
%define wInGameTradeReceiveMonSpecies 0xCD34

; --- unmodified stats, enemy ($CD23) ---
%define wEnemyMonUnmodifiedLevel     0xCD23
%define wEnemyMonUnmodifiedMaxHP     0xCD24
%define wEnemyMonUnmodifiedAttack    0xCD26
%define wEnemyMonUnmodifiedDefense   0xCD28
%define wEnemyMonUnmodifiedSpeed     0xCD2A
%define wEnemyMonUnmodifiedSpecial   0xCD2C
%define wEngagedTrainerClass         0xCD2D
%define wEngagedTrainerSet           0xCD2E
; --- enemy stat-stage modifiers ---
%define wEnemyMonStatMods            0xCD2E
%define wEnemyMonAttackMod           0xCD2E
%define wEnemyMonDefenseMod          0xCD2F
%define wEnemyMonSpeedMod            0xCD30
%define wEnemyMonSpecialMod          0xCD31
%define wEnemyMonAccuracyMod         0xCD32
%define wEnemyMonEvasionMod          0xCD33
%define wEnemyMonStatModsEnd         0xCD36

%define wNumMovesMinusOne            0xCD6C
%define wBattleMenuCurrentPP         0xCD6D   ; PrintMenuItem's scratch copy of the highlighted
                                    ; move's current PP (PrintNumber source). Aliased
                                    ; onto the same scratch union as wMoveData below —
                                    ; that is pret's own layout (wram.asm:1091).
%define wMoveData                    0xCD6D   ; 6-byte scratch move record (GetMoveData)
%define wPayDayMoney                 0xCD6D   ; Pay Day scratch (BCD, 3 bytes; aliased scratch union)
%define wNormalMaxPPList             0xCD78   ; 4-byte scratch: each move's normal max PP (RestoreBonusPP)

; --- per-side current-move struct ($CFCB enemy / $CFD1 player) ---
%define wEnemyMoveNum                0xCFCB
%define wEnemyMoveEffect             0xCFCC
%define wEnemyMovePower              0xCFCD
%define wEnemyMoveType               0xCFCE
%define wEnemyMoveAccuracy           0xCFCF
%define wEnemyMoveMaxPP              0xCFD0
%define wPlayerMoveNum               0xCFD1
%define wPlayerMoveEffect            0xCFD2
%define wPlayerMovePower             0xCFD3
%define wPlayerMoveType              0xCFD4
%define wPlayerMoveAccuracy          0xCFD5
%define wPlayerMoveMaxPP             0xCFD6
%define wEnemyMonSpecies2            0xCFD7
%define wBattleMonSpecies2           0xCFD8

; --- enemy battle-mon struct ($CFE4, 29-byte battle_struct) ---
%define wEnemyMonNick                0xCFD9   ; NAME_LENGTH bytes
%define wEnemyMon                    0xCFE4
%define wEnemyMonSpecies             0xCFE4
%define wEnemyMonHP                  0xCFE5   ; word, big-endian
%define wEnemyMonBoxLevel            0xCFE7
%define wEnemyMonPartyPos            0xCFE7
%define wEnemyMonStatus              0xCFE8
%define wEnemyMonType                0xCFE9
%define wEnemyMonType1               0xCFE9
%define wEnemyMonType2               0xCFEA
%define wEnemyMonCatchRate           0xCFEB
%define wEnemyMonMoves               0xCFEC   ; 4 bytes
%define wEnemyMonDVs                 0xCFF0   ; word
%define wEnemyMonLevel               0xCFF2
%define wEnemyMonMaxHP               0xCFF3   ; word
%define wEnemyMonStats               0xCFF3
%define wEnemyMonAttack              0xCFF5
%define wEnemyMonDefense             0xCFF7
%define wEnemyMonSpeed               0xCFF9
%define wEnemyMonSpecial             0xCFFB
%define wEnemyMonPP                  0xCFFD   ; 4 bytes
%define wEnemyMonBaseStats           0xD001
%define wEnemyMonActualCatchRate     0xD006
%define wEnemyMonBaseExp             0xD007

; Safari Zone battle state (sym-verified vs origin/symbols:pokeyellow.sym).
; Read by the Safari battle's flee/catch roll; written by BAIT / ROCK.
%define wSafariEscapeFactor          0xCCE8
%define wSafariBaitFactor            0xCCE9

; --- player battle-mon struct ($D013, 29-byte battle_struct) ---
%define wBattleMonNick               0xD008   ; NAME_LENGTH bytes
%define wBattleMon                   0xD013
%define wBattleMonSpecies            0xD013
%define wBattleMonHP                 0xD014   ; word, big-endian
%define wBattleMonBoxLevel           0xD016
%define wBattleMonPartyPos           0xD016
%define wBattleMonStatus             0xD017
%define wBattleMonType               0xD018
%define wBattleMonType1              0xD018
%define wBattleMonType2              0xD019
%define wBattleMonCatchRate          0xD01A
%define wBattleMonMoves              0xD01B   ; 4 bytes
%define wBattleMonDVs                0xD01F   ; word
%define wBattleMonLevel              0xD021
%define wBattleMonMaxHP              0xD022   ; word
%define wBattleMonStats              0xD022
%define wBattleMonAttack             0xD024
%define wBattleMonDefense            0xD026
%define wBattleMonSpeed              0xD028
%define wBattleMonSpecial            0xD02A
%define wBattleMonPP                 0xD02C   ; 4 bytes

%define wTrainerClass                0xD030
%define wTrainerName                 0xD049
%define wForcePlayerToChooseMon      0xD11E   ; set on failed escape; read by multi-mon switch-in (pret wram.asm:1781)
%define wNumRunAttempts              0xD11F   ; run-from-battle attempt count (escape-odds boost)
%define wIsInBattle                  0xD056   ; 0 none, 1 wild, 2 trainer ($FF = lost)
%define wBattleType                  0xD059
%define wDamageMultipliers           0xD05A   ; bit 7 = STAB, low bits = type-eff numerator
%define wCriticalHitOrOHKO           0xD05D
%define wMoveMissed                  0xD05E
%define wPlayerStatsToDouble         0xD05F   ; pret wBattleStatusData: always 0; cleared on send-out
%define wBattleStatusData            0xD05F   ; pret alias (start of the 0x18-byte battle-status block)
%define wBattleStatusDataEnd         0xD077   ; end (exclusive) of wBattleStatusData; EndOfBattle clears the range
%define wPlayerStatsToHalve          0xD060   ; always 0
%define wPlayerBattleStatus1         0xD061
%define wPlayerBattleStatus2         0xD062
%define wPlayerBattleStatus3         0xD063
%define wEnemyStatsToDouble          0xD064   ; pret: always 0; cleared on faint / send-out
%define wEnemyStatsToHalve           0xD065   ; always 0
%define wEnemyBattleStatus1          0xD066
%define wEnemyBattleStatus2          0xD067
%define wEnemyBattleStatus3          0xD068
%define wPlayerNumAttacksLeft        0xD069
%define wPlayerConfusedCounter       0xD06A
%define wPlayerDisabledMove          0xD06C
%define wEnemyNumAttacksLeft         0xD06E
%define wEnemyConfusedCounter        0xD06F
%define wEnemyDisabledMove           0xD071
%define wPlayerBideAccumulatedDamage 0xD073
%define wPlayerNumHits               0xD073

%define wDamage                      0xD0D6   ; word, big-endian
%define wTypeEffectiveness           0xD11D   ; shared scratch byte (=wPokedexNum union)
%define wMoveType                    0xD11D   ; scratch (AdjustDamageForMoveType); shares $D11D
%define wLinkState                   0xD12A   ; LINK_STATE_*; non-link single-player = 0
%define wLoadedMonSpeedExp           0xCFAE   ; wLoadedMon + MON_SPD_EXP (GetEnemyMonStat)
; party-mon stat fields (wPartyMons base $D16A + MON_* offsets) used by crit recompute
%define wPartyMon1Attack             0xD18E
%define wPartyMon1Defense            0xD190
%define wPartyMon1Special            0xD194
%define wEnemyMon1Stats              0xD8C5   ; link-battle enemy party stats (GetEnemyMonStat)
; party-mon struct (pret wPartyMon1* = wPartyMons base $D16A; DecrementPP/GainExp)
%define wPartyMon1                   0xD16A
%define wPartyMon1HP                 0xD16B   ; party-mon struct HP word (pikachu_status)
%define wPartyMon1MaxHP              0xD18C   ; = wPartyMons + MON_MAXHP (Softboiled's 1/5 max HP)
%define wPartyMon1Status             0xD16E
%define wPartyMon1OTID               0xD176   ; party-mon struct OT id word (pikachu_status)
%define wPartyMon1PP                 0xD187
%define wPartyMon2                   0xD196   ; wPartyMon1 + PARTYMON_STRUCT_LENGTH (44)
%define wPartyGainExpFlags           0xD057   ; bitfield: which party mons gain exp this battle

; --- Wave-1 backend aliases (sym-pinned, origin/symbols:pokeyellow.sym) ---
; exp/level-up flow (GainExperience, src/engine/battle/experience.asm)
%define wBoostExpByExpAll            0xCC5B   ; (union wUnusedFlag / slot-machine scratch)
%define wExpAmountGained             0xCF4A   ; word (union wStringBuffer region)
%define wGainBoostedExp              0xCF4C
%define wTempByteValue               0xD11D
%define wPartyFoughtCurrentEnemyFlags 0xCCF5
; Set when the player has already won, so DrawPlayerHUDAndHPBar must not re-arm
; the red-HP alarm. Address from pokeyellow.sym (00:ccf6), not inferred.
%define wLowHealthAlarmDisabled      0xCCF6
%define wLearnMoveMonName            0xD035
; UNION with wLearnMoveMonName (ram/wram.asm) — ItemUseTMHM parks the move name here
; across DisplayPartyMenu, which overwrites wStringBuffer.
%define wTempMoveNameBuffer          0xD035
; The TM/HM number under TMToMove / CanLearnTM. Unions with the D11D scratch cluster
; (wPokedexNum / wMaxPP / wTempByteValue), exactly as pret does.
%define wTempTMHM                    0xD11D
; evolution (src/engine/movie/evolution.asm)
%define wCanEvolveFlags              0xCCD3
%define wForceEvolution              0xCCD4
%define wEvoOldSpecies               0xCEE9   ; (union wHPBarMaxHP scratch)
%define wEvoNewSpecies               0xCEEA
%define wEvoMonTileOffset            0xCEEB   ; [2b] palette-flash morph scratch (deferred)
%define wEvoCancelled                0xCEEC   ; EvolveMon sets 1 on B-cancel → CF
%define wEvoStoneItemID              0xD155
; Bill's PC (src/engine/pokemon/bills_pc.asm)
%define wMoveMonType                 0xCF94   ; = wMoveMonType (union wRemoveMonFromBox)
; residual damage (src/engine/battle/residual_damage.asm)
%define wAnimationType               0xCC5B   ; (union wUnusedFlag)
%define wPlayerToxicCounter          0xD06B
%define wEnemyToxicCounter           0xD070
; GainExperience (src/engine/battle/experience.asm)
%define wPlayerID                    0xD358   ; word (player trainer id)
%define wCalculateWhoseStats         0xD11D   ; = wTempByteValue (union)
; battle init / front-end (Wave 2, src/engine/battle/init_battle*.asm)
%define wPartyAndBillsPCSavedMenuItem 0xCC2B
%define wMiscBattleData              0xCCD3   ; = wCanEvolveFlags (first byte of the block)
%define wMiscBattleDataEnd           0xCD0F
%define wActionResultOrTookBattleTurn 0xCD6A
%define wBattleResult                0xCF0B
%define wPlayerHPBarColor            0xCF1C
%define wEnemyHPBarColor             0xCF1D
%define wCurOpponent                 0xD058
%define wEscapedFromBattle           0xD077
%define wLowHealthAlarm              0xD082   ; nonzero = low-HP alarm enabled; EndOfBattle disables it
%define wChannelSoundIDs             0xC026   ; per-sound-channel active sound IDs (NUM_CHANNELS bytes)
%define wSavedTileAnimations         0xD0D3
%define wMapPalOffset                0xD35C
; trainer AI + read_trainer_party (src/engine/battle/trainer_ai.asm, read_trainer_party.asm)
%define wAILayer2Encouragement       0xCCD5
%define wAICount                     0xCCDF
%define wBuffer                      0xCEE9   ; (union wHPBarMaxHP, 30B scratch)
%define wAIItem                      0xCF05
%define wTrainerBaseMoney            0xD045   ; word, BCD
%define wLoneAttackNo                0xD05B
%define wTrainerNo                   0xD05C
%define wAmountMoneyWon              0xD078   ; 3 bytes, BCD
%define wAnimationID                 0xD07B   ; current battle-animation id (= wMenuItemOffset/wDefaultMap union)
%define wFirstMonsNotOutYet          0xD11C

; --- battle animation engine (src/engine/battle/animations.asm) — sym-pinned vs golden ---
; pret ram/wram.asm unions its special-effect scratch heavily; every address below is
; the golden pokeyellow.sym value. $D089/$D08A are a shared per-effect scratch pair
; (also wCoordAdjustmentAmount / mon-icon wAnimCounter); $CD3D is the same scratch
; lane battle_transitions.asm parks its port-only vars on (transition runs before the
; battle, ball shakes run inside it — lifetimes are disjoint by construction).
%define wAnimSoundID                 0xCF07   ; move-1 sound index for current anim command; NO_MOVE-1 = none
%define wAnimPalette                 0xCC79   ; OBP0 value staged for the animation (SGB-aware)
%define wTempTilesetNumTiles         0xD07C   ; tile count for LoadMoveAnimationTiles' CopyVideoData
%define wBaseCoordX                  0xD080   ; current frame block base X (GB pixel space)
%define wBaseCoordY                  0xD081   ; current frame block base Y (GB pixel space)
%define wdef4                        0xDEF4   ; DrawFrameBlock off-screen-adjust scratch (pret's address-named placeholder label, kept verbatim)
%define wFBTileCounter               0xD083   ; DrawFrameBlock per-entry loop counter
%define wSubAnimFrameDelay           0xD085   ; frames between frame blocks (command byte bits 0-5)
%define wSubAnimCounter              0xD086   ; remaining subentries in the current subanimation
%define wNumFBTiles                  0xD088   ; sprite-entry count of the current frame block
%define wSubAnimTransform            0xD08A   ; SUBANIMTYPE_* applied by DrawFrameBlock (union wAnimCounter/wSpiralBallsBaseX)
%define wSubAnimAddrPtr              0xD093   ; word: address of the current subanim's pointer (big-endian pair as pret stores it)
%define wSubAnimSubEntryAddr         0xD095   ; word: address of the current 3-byte subentry
%define wUnusedMoveAnimByte          0xD09A   ; golden 00:d09a — MoveAnimation write-only scratch, unread (pret ram/wram.asm:wUnusedMoveAnimByte). UNION with wTownMapSpriteBlinkingEnabled/wPartyMenuAnimMonEnabled at 0xD09A; disjoint lifetimes (battle anim vs town map / party menu).
%define wFBDestAddr                  0xD09B   ; word: running wShadowOAM write cursor (big-endian)
%define wFBMode                      0xD09D   ; FRAMEBLOCKMODE_* post-frame-block behavior
%define wWhichBattleAnimTileset      0xD09E   ; 0/1/2 -> MoveAnimationTilesPointers row
%define wTempSCX                     0xCD3D   ; golden 00:cd3d — ShakeEnemyHUD_ShakeBG's saved scroll value. Same $CD3D scratch lane as the entries below.
%define wFallingObjectsMovementData  0xCD3D   ; golden 00:cd3d — ds 20, one movement byte per falling object (AnimationFallingObjects). Head of the same $CD3D scratch lane as wSavedY / wNumShakes / wWhichTownMapLocation; pret unions them the same way and only one battle animation runs at a time.
%define wSavedY                      0xCD3D   ; golden 00:cd3d — AnimationShootManyBallsUpward's per-pillar Y. Same $CD3D scratch lane as wNumShakes / wWhichTownMapLocation below; lifetimes disjoint (one battle anim at a time).
%define wNumShakes                   0xCD3D   ; ball-shake count (low nybble of wPokeBallAnimData; transitions scratch lane union)
%define wDownscaledMonSize           0xCD6C   ; 0 = 5x5, 1 = 3x3 (send-out/recall downscale)
; per-effect scratch unions at $D089 (comment-only aliases resolve to the same byte):
%define wSpiralBallsBaseY            0xD089
%define wFallingObjectMovementByte   0xD089
%define wFlashScreenLongCounter      0xD089
%define wNumShootingBalls            0xD089
%define wSpiralBallsBaseX            0xD08A   ; (= wSubAnimTransform; effects that use it do not run inside a transformed subanim)
%define wNumFallingObjects           0xD08A
%define wSlideMonDelay               0xD08A   ; golden 00:d08a — V-blanks per tile of _AnimationSlideMonOff. Same pret $D08A union as above (wSubAnimTransform / wSpiralBallsBaseX / wNumFallingObjects); pret aliases them on hardware too, so the collision is reproduced, not introduced.
%define wDropletTile                 0xD09E   ; golden 00:d09e — tile id of the Surf/Mist/Toxic droplet. Same pret $D09E union as the two below.
%define wSquishMonCurrentDirection   0xD09E   ; golden 00:d09e — 0 = left, 1 = right, read by _AnimationSquishMonPic. Same pret $D09E union as the two below.
%define wSlideMonUpBottomRowLeftTile 0xD09E   ; golden 00:d09e — tile id seeding _AnimationSlideMonUp's refilled bottom row. UNION with wWhichBattleAnimTileset / wOutwardSpiralCurrentDirection at 0xD09E, as in pret; the slide never calls LoadMoveAnimationTiles, so the lifetimes are disjoint.
%define wUnusedWaterDropletsByte     0xD089   ; golden 00:d089 — written by AnimationWaterDropletsEverywhere, never read (pret name says so). Same $D089 union lane as the aliases above.
%ifndef wCoordAdjustmentAmount
%define wNewSlotMachineBallTile      0xD089   ; SlotMachine_UpdateBallTiles (same $D089 union lane)
%define wCoordAdjustmentAmount       0xD089   ; AdjustOAMBlock* signed delta (was locally %ifndef-defined in animations.asm/dust_smoke.asm)
%endif
%define wEnemyMon1HP                 0xD8A4
%define wEnemyMon1Status             0xD8A7
%define wEnemyMon1Moves              0xD8AB
%define wEnemyMon1PP                 0xD8C0   ; enemy party struct base 0xD8A3 + MON_PP (0x1D); used by IncrementMovePP (mirror_move.asm)

; --- HP-bar update scratch (UpdateHPBar / used by drain_hp etc.) — sym-pinned ---
; ChangeMonPic staging (pret animations.asm). Golden 00:cee9/00:ceea — the same
; $CEE9/$CEEA shared scratch lane as wHPBarMaxHP / wEvoOldSpecies / wBuffer /
; wTownMapCoords above, unioned in pret exactly as here; a mon-pic change and an
; HP-bar update are never live at once.
%define wChangeMonPicEnemyTurnSpecies 0xCEE9
%define wChangeMonPicPlayerTurnSpecies 0xCEEA
%define wHPBarMaxHP                  0xCEE9   ; word
%define wHPBarOldHP                  0xCEEB   ; word
%define wHPBarNewHP                  0xCEED   ; word
%define wHPBarDelta                  0xCEEF
%define wHPBarTempHP                 0xCEF0   ; word
%define wHPBarHPDifference           0xCEFD   ; word
%define wHPBarType                   0xCF93

; --- battle math / turn aliases (lowercase, for pret-faithful drafts) ---
; hWhoseTurn: 0 on player's turn, 1 on enemy's turn.
%define hWhoseTurn                   0xFFF3
%define hMultiplicand                0xFF96   ; 3 bytes
%define hMultiplier                  0xFF99
%define hDividend                    0xFF95   ; 4 bytes (overlaps hProduct/hQuotient)
%define hQuotient                    0xFF95
%define hDivisor                     0xFF99
%define hRemainder                   0xFF99
%define hProduct                     0xFF95   ; 4 bytes (= hQuotient/hDividend; Multiply/Divide result)
%define hEnemySpeed                  0xFF8D   ; 2 bytes — enemy speed scratch (TryRunningFromBattle)
%define hRandomAdd                   0xFFD3   ; PRNG output byte 1 (wild encounter rate compare)
%define hRandomSub                   0xFFD4   ; PRNG output byte 2 (wild encounter slot select)
%define hTextID                      0xFF8C   ; DisplayTextID input
%define hSpriteIndex                 (hTextID)   ; ASSERT hSpriteIndex == hTextID (same HRAM slot)
; The rest of hSpriteIndex's HRAM union (ram/hram.asm:64-68). hSpriteDataOffset is
; the member offset GetPointerWithinSpriteStateData{1,2} adds to slot*$10; the
; three at $FF8D are pret aliases of one byte, named for the caller's intent.
; Sym-verified, matching the local equs the emitted map scripts had been carrying.
%define hSpriteDataOffset            0xFF8B
%define hSpriteImageIndex            0xFF8D
%define hSpriteFacingDirection       (hSpriteImageIndex)
%define hSpriteMovementByte2         (hSpriteImageIndex)
; Oak's Aide HRAM (ram/hram.asm:303-307). Result and Requirement are pret aliases
; of ONE byte — the caller writes the requirement, the routine writes its result
; back over it. Sym-verified; these had been file-local equs in the emitted map
; scripts, which also kept _OaksAideHiText ungeneratable: its `text_decimal
; hOaksAideRequirement` needs the address resolvable from gb_memmap.inc.
%define wElevatorWarpMaps            0xCC5B   ; ram/wram.asm:503 `ds 11*2` — NEXTU union with
                                    ; wOaksAideRewardItemName below, hence the shared address
%define wOaksAideRewardItemName      0xCC5B   ; ram/wram.asm:500 (ds ITEM_NAME_LENGTH) — the
                                    ; item name _OaksAideHiText text_rams into its line
%define hOaksAideResult              0xFFDB
%define hOaksAideRequirement         0xFFDB   ; same byte as hOaksAideResult (written literal:
                                    ; the asset generators' memmap reader takes only literals)
%define hOaksAideRewardItem          0xFFDC
%define hOaksAideNumMonsOwned        0xFFDD
%define hItemPrice                   0xFF8B
%define hLoadedROMBank               0xFFB8
%define hFrameCounter                0xFFD5
%define hAutoBGTransferEnabled       0xFFBA
%define hWY                          0xFFB0
%define hJoyHeld                     0xFFB4
%define hItemAlreadyFound            0xFFEB   ; CheckForHiddenEventOrBookshelfOrCardKeyDoor result: 0 = handled, $ff = fall through
%define hToggleableObjectIndex       0xFFDB   ; PickUpItem scratch (pret hram union; == hInteractedWithBookshelf slot)
; hSavedMapTextPtr — 2 bytes, Set/RestoreMapTextPointer's save slot.
; golden 00:ffec, i.e. this takes pret's OWN address; 0xFFEC-0xFFED was free in the
; port's remapped HRAM, and the neighbour hItemAlreadyFound above already sits at
; pret's 0xFFEB, so this region tracks pret.
; *** THIS REPLACES A PLACEHOLDER THAT COLLIDED. *** m1_3_pending_symbols.inc
; carried `hSavedMapTextPtr equ 0xFF8E ; PLACEHOLDER`, with a comment asking the
; root to allocate a real pair, and nobody did. As a 2-byte slot it ran to 0xFF8F
; = hSpriteOffset2, which PrepareOAMData writes once per sprite EVERY FRAME from
; the vblank pipeline. So the saved pointer's high byte was overwritten with a
; sprite slot offset between any save and its restore, and RestoreMapTextPointer
; handed ChangeBox a corrupt wCurMapTextPtr across SaveGameData. Both routines are
; linked; the flow is gated behind the Bill's-PC stubs, so it was latent, not live.
%define hSavedMapTextPtr             0xFFEC   ; golden 00:ffec (dw)

; Sprite state data — 16 slots × $10 bytes each, two parallel arrays.
; wSpriteStateData1 ($C100) and wSpriteStateData2 ($C200) — sym-verified.
; The high byte of a pointer in one array +1 reaches the other (the engine
; relies on this; in the flat model we use the explicit base constants).
%define wSpriteStateData1            0xC100   ; wSpriteStateData1 (slot 0 = player)
%define wSpriteStateData2            0xC200   ; wSpriteStateData2
%define SPRITESTATEDATA_STRUCT_SIZE  0x10
%define NUM_SPRITE_SLOTS             16
%define wSprite01StateData1          0xC110   ; golden 00:c110 — slot 1 (first non-player sprite)
%define wSprite01StateData2OrigFacingDirection 0xC219   ; wSprite01StateData2 + SPRITESTATEDATA2_ORIGFACINGDIRECTION
; pret-named aliases (constants/map_object_constants.asm / macros/wram.asm) —
; canonical here as of menus S2. (m1_3_pending_symbols.inc used to carry
; %ifndef-guarded copies; that scaffold was dissolved 2026-07-27.)
%define NUM_SPRITESTATEDATA_STRUCTS  (NUM_SPRITE_SLOTS)
%define PIKACHU_SPRITE_INDEX         (NUM_SPRITESTATEDATA_STRUCTS - 1)   ; = 15 (pret map_object_constants.asm)
%define SPRITESTATEDATA1_LENGTH      (SPRITESTATEDATA_STRUCT_SIZE)

; Player slot (slot 0) field aliases — data1 ($C10x).
; Step vectors are signed bytes (+1/-1/0) read each frame by AdvancePlayerSprite.
%define wSpritePlayerStateData1PictureID 0xC100   ; wSpritePlayerStateData1PictureID (0 = slot unused)
%define W_SPRITE_PLAYER_Y_STEP_VECTOR 0xC103   ; wSpritePlayerStateData1YStepVector
%define W_SPRITE_PLAYER_Y_PIXELS     0xC104   ; wSpritePlayerStateData1YPixels (fixed screen Y, $3c)
%define W_SPRITE_PLAYER_X_STEP_VECTOR 0xC105   ; wSpritePlayerStateData1XStepVector
%define W_SPRITE_PLAYER_X_PIXELS     0xC106   ; wSpritePlayerStateData1XPixels (fixed screen X, $40)
%define W_SPRITE_PLAYER_INTRA_ANIM   0xC107   ; wSpritePlayerStateData1IntraAnimFrameCounter
%define W_SPRITE_PLAYER_ANIM_FRAME   0xC108   ; wSpritePlayerStateData1AnimFrameCounter
%define W_SPRITE_PLAYER_FACING_DIR   0xC109   ; wSpritePlayerStateData1FacingDirection (SPRITE_FACING_*)
; Player slot fields — data2 ($C20x).
%define wSpritePlayerStateData2WalkAnimationCounter 0xC200   ; wSpritePlayerStateData2WalkAnimationCounter
%define W_SPRITE_PLAYER_GRASS_PRIORITY 0xC207   ; wSpritePlayerStateData2GrassPriority ($80 = under grass)
%define W_SPRITE_PLAYER_IMAGE_BASE_OFFSET 0xC20E   ; wSpritePlayerStateData2ImageBaseOffset (player = 1)

; Sprite-engine struct field offsets (within a $10-byte slot).
%define SPRITESTATEDATA1_PICTUREID   0x0
%define SPRITESTATEDATA1_MOVEMENTSTATUS 0x1   ; 0=uninit, 1=ready, 2=delayed, 3=walking
%define SPRITESTATEDATA1_IMAGEINDEX  0x2
%define SPRITESTATEDATA1_YPIXELS     0x4
%define SPRITESTATEDATA1_XPIXELS     0x6
%define SPRITESTATEDATA1_INTRAANIMFRAMECOUNTER 0x7
%define SPRITESTATEDATA1_ANIMFRAMECOUNTER 0x8
%define SPRITESTATEDATA1_FACINGDIRECTION 0x9
%define SPRITESTATEDATA1_YSTEPVECTOR 0x3   ; step vector for Y (-1/0/+1 → 0xFF/0x00/0x01)
%define SPRITESTATEDATA1_XSTEPVECTOR 0x5   ; step vector for X
%define SPRITESTATEDATA1_YADJUSTED   0xA   ; adjusted Y for collision ((YPIXELS+4+B)&0xF0|C)
%define SPRITESTATEDATA1_XADJUSTED   0xB   ; adjusted X for collision ((XPIXELS+B)&0xF0|C)
%define SPRITESTATEDATA1_COLLISIONDATA 0xC   ; collision direction bits (accumulated)
%define SPRITESTATEDATA1_COLLISIONBITMAP_HI 0xE   ; collision bitmap high byte (slots 8-15)
%define SPRITESTATEDATA1_COLLISIONBITMAP_LO 0xF   ; collision bitmap low byte (slots 0-7)
%define SPRITESTATEDATA2_YDISPLACEMENT 0x2   ; Y displacement (init 8)
%define SPRITESTATEDATA2_XDISPLACEMENT 0x3   ; X displacement (init 8)
%define SPRITESTATEDATA2_MAPY        0x4   ; map Y position (metatile units, origin+4)
%define SPRITESTATEDATA2_MAPX        0x5   ; map X position (metatile units, origin+4)
%define SPRITESTATEDATA2_WALKANIMCOUNTER 0x0   ; 8-frame countdown while walking (0=standing)
; movement-byte-2 (dir constraint) and masked text-id relocated to wMapSpriteData
; (pret home/overworld.asm:LoadSprite) by OW-A.2 P2 — they were at pret-unused struct
; bytes 0x1 / 0x0A. See wMapSpriteData (map_sprites.asm) + WMSD_* indexing helper below.
%define SPRITESTATEDATA2_MOVEMENTDELAY 0x8   ; frames until next random walk attempt (pret 0x08)
%define SPRITESTATEDATA2_MOVEMENTBYTE1 0x6   ; $ff=STAY, $fe=WALK(random), <$fe=scripted
%define SPRITESTATEDATA2_GRASSPRIORITY 0x7   ; $80=under grass (set by CheckSpriteAvailability)
%define SPRITESTATEDATA2_ISTRAINER   0xA   ; port istrainer flag (DIVERGENCE: pret has no such field);
                                                ; OW-A.2 P2 moved it off ORIGFACINGDIRECTION@0x9 into pret-unused 0x0A
%define SPRITESTATEDATA2_IMAGEBASEOFFSET 0xE
%define SPRITESTATEDATA2_ORIGFACINGDIRECTION 0x9   ; pret ORIGFACINGDIRECTION (OW-A.2 restores; was bespoke ISTRAINER)
%define SPRITESTATEDATA2_PICTUREID   0xD   ; pret SPRITESTATEDATA2_PICTUREID

%define BIT_FACE_PLAYER              7   ; bit 7 of SPRITESTATEDATA1_MOVEMENTSTATUS

; --- Sprite-set constants (pret constants/sprite_set_constants.asm) -------------
; Consumed by the map_sprites.asm sprite-set machinery (OW-A.2) + data/maps/sprite_sets.
%define SPRITE_SET_LENGTH            11   ; 9 walking + 2 still sprites per set
%define MAX_OBJECT_EVENTS            16   ; pret constants/map_data_constants.asm (wMapSpriteData/ExtraData = *2)
%define SPRITE_PIKACHU               0x3D   ; pret constants/sprite_constants.asm (loaded separately in each set)
%define FIRST_STILL_SPRITE           0x47   ; first 4-tile "still" sprite id (SPRITE_POKE_BALL)
%define EAST_WEST                    1
%define NORTH_SOUTH                  2
; SpriteSets indices (values for MapSpriteSets / SplitMapSpriteSets)
%define SPRITESET_PALLET_VIRIDIAN    0x01
%define SPRITESET_PEWTER_CERULEAN    0x02
%define SPRITESET_LAVENDER           0x03
%define SPRITESET_VERMILION          0x04
%define SPRITESET_CELADON            0x05
%define SPRITESET_INDIGO             0x06
%define SPRITESET_SAFFRON            0x07
%define SPRITESET_SILENCE_BRIDGE     0x08
%define SPRITESET_CYCLING_ROAD       0x09
%define SPRITESET_FUCHSIA            0x0A
%define NUM_SPRITE_SETS              10
; Split sprite set ids (index SplitMapSpriteSets; also values for MapSpriteSets)
%define FIRST_SPLIT_SET              0xF1
%define SPLITSET_ROUTE_2             0xF1
%define SPLITSET_ROUTE_10            0xF2
%define SPLITSET_ROUTE_11            0xF3
%define SPLITSET_ROUTE_12            0xF4
%define SPLITSET_ROUTE_15            0xF5
%define SPLITSET_ROUTE_16            0xF6
%define SPLITSET_ROUTE_18            0xF7
%define SPLITSET_ROUTE_20            0xF8
%define SPLITSET_ROUTE_5             0xF9
%define SPLITSET_ROUTE_6             0xFA
%define SPLITSET_ROUTE_7             0xFB
%define SPLITSET_ROUTE_8             0xFC
%define NUM_SPLIT_SETS               12

; Scratch WRAM for a TX command stream COMPOSED AT RUN TIME. Only the battle text
; composers use it (used_move_text.asm: DisplayUsedMoveText; core.asm:
; ComposeStatIntro), because they
; splice a nickname / a TX_RAM operand together byte-by-byte and the result has to
; live somewhere addressable. They enter the printer at PrintTextStaged.
;
; This is NOT the old staging buffer. Every *static* stream is flat program-image
; data and TextCommandProcessor walks it in place; nothing copies a stream here to
; print it any more. Copying a flat stream in was a workaround for TCP's old
; EBP-relative stream pointer, and it silently truncated anything past 256 bytes
; (four real dialogs rendered garbage). Don't route a flat stream through here.
%define NPC_DIALOG_BUF               0xCB00   ; composed-stream scratch (≤256 B)
%define NPC_DIALOG_LEN               256   ; its capacity

; NPC movement-byte sentinel values (constants/map_object_constants.asm)
%define WALK                         0xFE   ; random movement
%define STAY                         0xFF   ; stationary

; NPC direction constraint values (movement byte 2 / pret wMapSpriteData byte 0)
; constants/map_object_constants.asm: ANY_DIR=0x00, UP_DOWN=0x01, LEFT_RIGHT=0x02
; Forced single-direction: DOWN=0xD0, UP=0xD1, LEFT=0xD2, RIGHT=0xD3, NONE=0xFF
%define NPC_DIR_ANY                  0x00   ; any random direction (pret: ANY_DIR)
%define NPC_DIR_UPDOWN               0x01   ; constrained to up/down only (pret: UP_DOWN)
%define NPC_DIR_LR                   0x02   ; constrained to left/right only (pret: LEFT_RIGHT)
%define NPC_DIR_DOWN                 0xD0   ; forced down (pret: DOWN)
%define NPC_DIR_UP                   0xD1   ; forced up
%define NPC_DIR_LEFT                 0xD2   ; forced left
%define NPC_DIR_RIGHT                0xD3   ; forced right
%define NPC_DIR_NONE                 0xFF   ; STAY NPC (no movement constraint)
%define UP_DOWN                      (NPC_DIR_UPDOWN)
%define LEFT_RIGHT                   (NPC_DIR_LR)

; NPC random movement direction thresholds (high 2 bits of hRandomAdd)
; constants/sprite_data_constants.asm
%define NPC_MOVEMENT_DOWN            0x00   ; hRandomAdd in [0x00,0x3F] → go down
%define NPC_MOVEMENT_UP              0x40   ; hRandomAdd in [0x40,0x7F] → go up
%define NPC_MOVEMENT_LEFT            0x80   ; hRandomAdd in [0x80,0xBF] → go left
%define NPC_MOVEMENT_RIGHT           0xC0   ; hRandomAdd in [0xC0,0xFF] → go right

; Named WRAM symbols (subset needed by translated routines).
; Offsets from pokeyellow.sym (bank 00).
%define wShadowOAM                   0xC300   ; wShadowOAM — 40 sprites × 4 bytes
; Town map (engine/items/town_map.asm) — pret-real addresses, replacing the
; PLACEHOLDER block that file carried while it was dangling (its 0xDE00 base
; collided with wBoxMonNicks 0xDE05).
; RELOCATED (port-only): pret puts wShadowOAMBackup at 0xC508. It cannot live there
; here — the port's wTileMap is 40x25 = 1000 bytes (the GB's is 20x18 = 360), so
; wTileMap spans 0xC3A0-0xC787 and SWALLOWS 0xC508. At pret's address the town map's
; OAM backup wrote raw sprite bytes straight into tilemap rows 9-12 (visible as a band
; of garbage glyphs across the map). It goes in the Echo region instead, with the other
; buffers that outgrew their pret slots (wSurroundingTiles, wOverworldMap,
; wTileMapBackup2 — which ends at 0xF4E8).
%define wShadowOAMBackup             0xF500   ; 160 B (OAM_COUNT * 4), ends 0xF59F
%define wTownMapSpriteBlinkingEnabled 0xD09A
%define wTownVisitedFlag             0xD70A   ; = wTownVisitedFlag (2 bytes)
; The three below are aliased-scratch lanes, like every other 0xCD3D/0xCEE9 user
; above — the town map is a modal screen, so nothing else is live while it runs.
%define wWhichTownMapLocation        0xCD3D
%define wFlyAnimUsingCoordList       0xCD3D
%define wFlyLocationsList            0xCD3E   ; NUM_CITY_MAPS + 2
%define wTownMapCoords               0xCEE9

; Battle-HUD scratch — pret ram/wram.asm:863-868, another lane of the same
; $CD3E union. Addresses CONFIRMED against the ROM symbol file (pokeyellow.sym),
; not inferred from the union's ordering.
;
; THE OVERLAP WITH wBattleTransitionCircleScreenQuadrantX ($CD3E, above) IS
; FAITHFUL, NOT A COLLISION, AND THAT WAS MEASURED RATHER THAN ASSUMED:
; pokeyellow.sym lists BOTH names at 00:cd3e, i.e. the real hardware aliases them
; in the same union (pret wram.asm:815 and :863 are separate NEXTU lanes). The
; transition animation completes before the battle HUD and the pokeball rows are
; drawn, which is exactly why the original could share the byte.
%define wHUDPokeballGfxOffsetX       0xCD3E   ; signed X delta between adjacent pokeballs
%define wHUDGraphicsTiles            0xCD3F   ; 3-byte table copied from ROM per HUD side
%define wHUDUnusedTopTile            0xCD3F   ; [0] unused — $73 is hardcoded in PlaceHUDTiles
%define wHUDCornerTile               0xCD40   ; [1] corner tile of the HUD underline
%define wHUDTriangleTile             0xCD41   ; [2] triangle tile at the far end
%define wHUDGraphicsTilesEnd         0xCD42
%define wShadowOAMEnd                0xC3A0
%define W_SHADOW_OAM_SIZE            0xA0   ; 160 bytes
%define wTileMap                     0xC3A0   ; wTileMap — 40×25 screen tile buffer
%define W_TILEMAP_SIZE               1000   ; SCREEN_TILES_W * SCREEN_TILES_H

; WRAM bank 1 — $D000–$DFFF (4 KB)
; On CGB: banks 1–7 are switchable via rWBK ($FF70).
; For now, bank 1 is the only one allocated here. CGB banking TBD.
%define GB_WRAM1                     0xD000

; Echo RAM region — $E000–$FDFF
; The pret source never addresses this range, so we use it for expanded
; DOS-port-only buffers (wSurroundingTiles, wOverworldMap, redraw scratch,
; wTileMapBackup2) that grew beyond their original WRAM0/1 slots.
; All addresses are within the DPMI allocation (EBP + 0xE000 is valid).
%define GB_ECHO                      0xE000

; OAM — $FE00–$FE9F (160 bytes = 40 sprites × 4 bytes each)
; Format per sprite: Y, X, tile ID, flags. See constants/hardware.inc OAM constants.
%define GB_OAM                       0xFE00
%define GB_OAM_SIZE                  160   ; 40 * 4

; I/O register shadow area — $FF00–$FF7F (128 bytes)
; Holds emulated values of GB I/O registers. Written by game logic;
; read by the software renderer and input handler.
%define GB_IO                        0xFF00

; H-flag shadow — placed at $FF7E (unused by original GB, within our IO block)
; Lazy H-flag storage for DAA/CPL/etc. Only valid immediately before those instructions.
; See docs/register_map.md for the H-flag protocol.
%define hf_shadow                    0xFF7E

; HRAM — $FF80–$FFFE (127 bytes)
; High RAM; used by the game for fast-access variables (see ram/hram.asm).
%define GB_HRAM                      0xFF80
%define GB_HRAM_SIZE                 127

; Named HRAM variables (subset needed by translated routines).
; All offsets verified from pokeyellow.sym (bank 00).
%define H_DOWN_ARROW_COUNT1          0xFF86   ; hDownArrowBlinkCount1 — frame countdown (ON→OFF phase)
%define H_DOWN_ARROW_COUNT2          0xFF87   ; hDownArrowBlinkCount2 — compat; 1 in 60 Hz blink mode
%define hSoftReset                   0xFF8A   ; hSoftReset
; 0xFF8B is a UNION of hMapStride / hNorthSouthConnectionStripWidth / hPreviousTileset
%define hMapStride                   0xFF8B   ; hMapStride (= map block row stride = width + 2*MAP_BORDER)
%define hPreviousTileset             0xFF8B   ; hPreviousTileset (HRAM union with hMapStride)
%define hROMBankTemp                 0xFF8B   ; golden 00:ff8b — PlayAnimation writes 0, unread ("nothing reads this"); no ROM banking in the flat model. UNION with hMapStride/hItemPrice at 0xFF8B; disjoint lifetimes (battle anim entry vs map load / item price).
%define hBaseTileID                  0xFF8B   ; golden 00:ff8b — base tile ID added by CopyTileIDs (ram/hram.asm). Same $FF8B union as above, and pret intends it: PlayAnimation zeroes hROMBankTemp at entry, CopyPicTiles then writes hBaseTileID and CopyTileIDs reads it back — one byte, ordered, exactly as on hardware.
%define hWarpDestinationMap          0xFF8B   ; ram/hram.asm — SAME UNION byte as hBaseTileID/hOAMTile/
                                        ; hROMBankTemp/hPreviousTileset/hRLEByteValue. pret writes it in
                                        ; WarpFound1 and reads it a few instructions later in WarpFound2
                                        ; (.indoorMaps/.goBackOutside); the port mirrors that short window.
; 0xFF8C is a UNION of hMapWidth / hNorthSouthConnectedMapWidth
%define hMapWidth                    0xFF8C   ; hMapWidth (= wCurMapWidth, stored for row-copy inner loop)
%define hSerialConnectionStatus      0xFFAA   ; hSerialConnectionStatus
; Link-menu / serial exchange scratch (menus S8 package I — link_menu.asm).
; Sym-verified vs origin/symbols:pokeyellow.sym; the 0xCC3D/0xCC42 pairs are
; union-aliased (send/receive buffer overlaps the nybble-exchange lanes).
%define wLinkMenuSelectionReceiveBuffer 0xCC3D   ; wram.asm:425 (dw)
%define wSerialSyncAndExchangeNybbleReceiveData 0xCC3D   ; wram.asm:437 (db; aliases recv buf)
%define wSerialExchangeNybbleReceiveData 0xCC3E   ; wram.asm:439 (db)
%define wLinkMenuSelectionSendBuffer 0xCC42   ; wram.asm:428 (dw)
%define wSerialExchangeNybbleSendData 0xCC42   ; wram.asm:442 (db; aliases send buf)
%define wUnknownSerialCounter        0xCC47   ; wram.asm:444 (dw; aliases wEnteringCableClub)
%define wEnteringCableClub           0xCC47   ; wram.asm:430 (db; sym 00:cc47)
%define wUnusedLinkMenuByte          0xCD37   ; wram.asm:754 (db; was worker 0xCC83)
%define hSerialSendData              0xFFAC   ; hram.asm:193 (db)
%define hSerialReceiveData           0xFFAD   ; hram.asm:194 (db)
%define hSCX                         0xFFAE   ; hSCX — shadow of rSCX
%define hSCY                         0xFFAF   ; hSCY — shadow of rSCY
; Scripted-NPC-anim scratch (pret hSpriteVRAMSlotAndFacing / hSpriteAnimFrameCounter).
; Port-assigned to free hram; transient scratch within the DoScriptedNPCMovement anim
; chain only (write+read same call), never persisted/cross-referenced — exact pret
; hram address not load-bearing.
%define hSpriteVRAMSlotAndFacing     0xFFC0   ; hSpriteVRAMSlotAndFacing
%define hSpriteAnimFrameCounter      0xFFC1   ; hSpriteAnimFrameCounter
; hLCDCPointer — pret's per-scanline LCDC pointer (STAT-ISR driven). The port
; does not emulate per-scanline LCDC, so this is an inert HRAM byte; the intro
; writes 0 (disabled) at scene starts. Port-assigned to free HRAM (exact pret
; address not load-bearing here). If per-scanline effects are ever emulated
; (surfing-wobble scenes 6/7), this needs the real STAT mechanism, not this byte.
%define hLCDCPointer                 0xFFC2   ; hLCDCPointer (inert in the port)
; Generic VBlank tile-transfer request (yellow-intro scenes 7/11 +
; Request7TileTransferFromC810ToC710). INERT: the port has no generic VBlank tile
; copy (only VBlankCopyBgMap handles BG-map rows), so these request bytes are
; written faithfully but never consumed — the intro's LY-wave / cloud tile
; animation does not play. Free HRAM slots 0xFFC6-0xFFCA.
%define hVBlankCopySize              0xFFC6   ; db
%define hVBlankCopySource            0xFFC7   ; dw
%define hVBlankCopyDest              0xFFC9   ; dw
%define hAutoBGTransferDest          0xFFBC   ; hAutoBGTransferDest (2 bytes, lo/hi)
%define hRedrawMapViewRowOffset      0xFFBE   ; hRedrawMapViewRowOffset
%define hVBlankOccurred              0xFFD6   ; hVBlankOccurred
%define hTileAnimations              0xFFD7   ; lowercase pret-name alias

; The two vTileset (GB_VCHARS2) tiles UpdateMovingBgTiles rewrites in place while
; hTileAnimations is nonzero (pret home/vcopy.asm). These IDs are RESERVED: any
; port screen that parks its own graphics in vTileset must steer clear of them, or
; the animator will scribble water/flower patterns over that screen's tiles
; whenever animations are on. (This bit the party-menu mon icons, which used to be
; BG tiles parked here; they are OBJ in vSprites now — engine/gfx/mon_icons.asm,
; docs/plans/party_icons_oam.md — so the reservation no longer has a live claimant.
; It still binds ANY other screen that parks graphics in vTileset.)
%define ANIM_FLOWER_TILE_ID          0x03
%define ANIM_WATER_TILE_ID           0x14
%define H_REDRAW_ROW_COL_MODE        0xFFD0   ; hRedrawRowOrColumnMode
%define hRedrawRowOrColumnMode       (H_REDRAW_ROW_COL_MODE)
%define H_REDRAW_ROW_COL_DEST        0xFFD1   ; hRedrawRowOrColumnDest
%define hRedrawRowOrColumnDest       (H_REDRAW_ROW_COL_DEST)
%define wRedrawRowOrColumnSrcTiles   0xCBFC   ; ds SCREEN_WIDTH * 2 (40 bytes)
%define hUILayoutFlags               0xFFFA   ; hUILayoutFlags
%define hItemToRemoveID              0xFFDB   ; RemoveItemByID: item id to remove
%define hItemToRemoveIndex           0xFFDC   ; RemoveItemByID: running bag index

%define BIT_SINGLE_SPACED_LINES      2   ; hUILayoutFlags bit (gfx_constants.asm)

; Joypad HRAM ($FFB1-$FFB7) — order confirmed by hram.asm + hSCX=$FFAE anchor
%define hJoyPressed                  0xFFB3   ; hJoyPressed — buttons just pressed this frame
%define hJoy5                        0xFFB5   ; hJoy5 — JoypadLowSensitivity output (Wave 3/M3.2)
%define hJoy6                        0xFFB6   ; hJoy6 — low-sens flag: 0 = suppress repeat while A/B held
%define hJoy7                        0xFFB7   ; hJoy7 — low-sens flag: 0 = newly-pressed only, 1 = held+delay

; The two joypad bytes that live OUTSIDE that run, up with hWhoseTurn ($FFF3).
; Addresses read straight out of pokeyellow.sym (00:fff5, 00:fff8) — the port's
; HRAM map is uniformly +$0A from a naive walk of ram/hram.asm, so these are NOT
; derived by counting. Added in chunk 18, when src/engine/joypad.asm was repaired
; into live source: pret's ReadJoypad_ and _Joypad are the only readers.
%define hJoyInput                    0xFFF5   ; hJoyInput — raw poll result (ReadJoypad_ output)
%define hDisableJoypadPolling        0xFFF8   ; hDisableJoypadPolling — nonzero: ReadJoypad_ returns early

; Sprite-engine HRAM temporaries (PrepareOAMData / _UpdateSprites) — sym-verified.
%define hSpriteOffset2               0xFF8F   ; hSpriteOffset2 (current slot offset in PrepareOAMData loop)
%define hOAMBufferOffset             0xFF90   ; hOAMBufferOffset (write cursor into wShadowOAM)
%define hSpriteScreenX               0xFF91   ; hSpriteScreenX
%define hSpriteScreenY               0xFF92   ; hSpriteScreenY
%define hTilePlayerStandingOn        0xFF93   ; hTilePlayerStandingOn
%define hSpritePriority              0xFF94   ; hSpritePriority (BG-priority bit for current sprite)
%define hMoney                       0xFF9F
%define hDivideBuffer                0xFF9A
%define hDivideBCDDivisor            0xFFA2
%define hDivideBCDQuotient           0xFFA2
%define hDivideBCDBuffer             0xFFA5
; hSpriteIndex is a sprite SLOT number (1-based); hCurrentSpriteOffset is slot<<4.
; The port's sprite helpers (GetSpriteMovementByte2Pointer / MoveSprite) select on
; the latter, while pret threads the former — see push_boulder.asm's header note.
; Canonical here as of overworld-events Stage 4; the hidden_events.asm /
; push_boulder.asm copies are %ifndef-guarded so both include orders stay safe.
%define hCurrentSpriteOffset         0xFFDA   ; hCurrentSpriteOffset (_UpdateSprites loop index)
%define hPikachuSpriteVRAMOffset     0xFFFC   ; hPikachuSpriteVRAMOffset (added to tile id $80+; 0 for now)

; Named WRAM symbols — all addresses verified from pokeyellow.sym.

; ---------------------------------------------------------------------------
; Audio engine WRAM — pret "Audio RAM" section, $C000-$C0F4 (ram/wram.asm).
; Per-channel arrays are NUM_CHANNELS(8) bytes: CHAN1-4 music, CHAN5-8 SFX.
; Pointer pairs (command/return) are 16-bit little-endian GB pointers into
; the audio banks (the port dereferences them through the AudioRom blob).
; ---------------------------------------------------------------------------
%define wUnusedMusicByte             0xC000
%define wSoundID                     0xC001
%define wMuteAudioAndPauseMusic      0xC002   ; bit 7 = muted; 1-127 = mute+pause
%define wDisableChannelOutputWhenSfxEnds 0xC003
%define wStereoPanning               0xC004
%define wSavedVolume                 0xC005
%define wChannelCommandPointers      0xC006   ; 8 x dw
%define wChannelReturnAddresses      0xC016   ; 8 x dw
; wChannelSoundIDs 0xC026 defined above (overworld block)
%define wChannelFlags1               0xC02E   ; BIT_PERFECT_PITCH..BIT_ROTATE_DUTY_CYCLE
%define wChannelFlags2               0xC036   ; BIT_EXECUTE_MUSIC
%define wChannelDutyCycles           0xC03E
%define wChannelDutyCyclePatterns    0xC046
%define wChannelVibratoDelayCounters 0xC04E
%define wChannelVibratoExtents       0xC056
%define wChannelVibratoRates         0xC05E   ; hi nibble reload, lo nibble counter
%define wChannelFrequencyLowBytes    0xC066
%define wChannelVibratoDelayCounterReloadValues 0xC06E
%define wChannelPitchSlideLengthModifiers 0xC076
%define wChannelPitchSlideFrequencySteps 0xC07E
%define wChannelPitchSlideFrequencyStepsFractionalPart 0xC086
%define wChannelPitchSlideCurrentFrequencyFractionalPart 0xC08E
%define wChannelPitchSlideCurrentFrequencyHighBytes 0xC096
%define wChannelPitchSlideCurrentFrequencyLowBytes 0xC09E
%define wChannelPitchSlideTargetFrequencyHighBytes 0xC0A6
%define wChannelPitchSlideTargetFrequencyLowBytes 0xC0AE
%define wChannelNoteDelayCounters    0xC0B6   ; integer part (frac below)
%define wChannelLoopCounters         0xC0BE
%define wChannelNoteSpeeds           0xC0C6
%define wChannelNoteDelayCountersFractionalPart 0xC0CE
%define wChannelOctaves              0xC0D6
%define wChannelVolumes              0xC0DE
%define wMusicWaveInstrument         0xC0E6
%define wSfxWaveInstrument           0xC0E7
%define wMusicTempo                  0xC0E8   ; dw, stored hi-then-lo (big-endian!)
%define wSfxTempo                    0xC0EA   ; dw, stored hi-then-lo (big-endian!)
%define wSfxHeaderPointer            0xC0EC   ; dw, stored hi-then-lo (big-endian!)
%define wNewSoundID                  0xC0EE   ; pret alias
%define wAudioROMBank                0xC0EF   ; pret alias
%define wAudioSavedROMBank           0xC0F0   ; pret alias
%define wFrequencyModifier           0xC0F1   ; cry pitch modifier
%define wTempoModifier               0xC0F2   ; cry tempo modifier

; Audio fade-out block ($CFC6) + map-music vars ($D35A)
%define wAudioFadeOutControl         0xCFC6   ; = wAudioFadeOutControl below
%define wAudioFadeOutCounterReloadValue 0xCFC7
%define wAudioFadeOutCounter         0xCFC8
%define wLastMusicSoundID            0xCFC9
%define wMapMusicSoundID             0xD35A
%define wMapMusicROMBank             0xD35B
%define wGymLeaderNo                 0xD05B   ; union with wLoneAttackNo (pret)
%define hDexRatingNumMonsOwned       0xFFDC   ; HRAM (pokedex rating SFX)
%define BIT_NO_AUDIO_FADE_OUT        1   ; wStatusFlags2 bit 1

; Virtual APU — GB sound registers, live in emulated GB memory. The
; translated engine writes them like the SM83 did; the device shim reads
; them once per tick (NRx4 bit 7 "restart" is consumed by the shim: the
; engine never reads it back, so the shim clears it after processing).
%define rAUD1SWEEP                   0xFF10   ; NR10
%define rAUD1LEN                     0xFF11   ; NR11 duty/length
%define rAUD1ENV                     0xFF12   ; NR12 envelope
%define rAUD1LOW                     0xFF13   ; NR13 freq lo
%define rAUD1HIGH                    0xFF14   ; NR14 restart/len-enable/freq hi
%define rAUD2LEN                     0xFF16   ; NR21
%define rAUD2ENV                     0xFF17   ; NR22
%define rAUD2LOW                     0xFF18   ; NR23
%define rAUD2HIGH                    0xFF19   ; NR24
%define rAUD3ENA                     0xFF1A   ; NR30 wave on/off (bit 7)
%define rAUD3LEN                     0xFF1B   ; NR31
%define rAUD3LEVEL                   0xFF1C   ; NR32
%define rAUD3LOW                     0xFF1D   ; NR33
%define rAUD3HIGH                    0xFF1E   ; NR34
%define rAUD4LEN                     0xFF20   ; NR41
%define rAUD4ENV                     0xFF21   ; NR42
%define rAUD4POLY                    0xFF22   ; NR43
%define rAUD4GO                      0xFF23   ; NR44
%define rAUDVOL                      0xFF24   ; NR50 master volume
%define rAUDTERM                     0xFF25   ; NR51 stereo routing
%define rAUDENA                      0xFF26   ; NR52 sound on/off
%define _AUD3WAVERAM                 0xFF30   ; $FF30-$FF3F
%define AUD3WAVE_SIZE                16
%define AUD1RAM                      0xFF10   ; per-channel register file bases
%define AUD2RAM                      0xFF15
%define AUD3RAM                      0xFF1A
%define AUD4RAM                      0xFF1F
%define AUD1SWEEP_DOWN               0x08
%define AUD3ENA_OFF                  0x00
%define AUD3ENA_ON                   0x80
%define AUDENA_ON                    0x80
%define AUD1HIGH_LENGTH_ON           0x40
%define AUDTERM_ALL_1                0x11   ; ch1 left|right
%define AUDTERM_ALL_2                0x22
%define AUDTERM_ALL_3                0x44
%define AUDTERM_ALL_4                0x88

; Audio engine bit/flag constants (constants/audio_constants.asm)
%define CHAN1                        0
%define CHAN2                        1
%define CHAN3                        2
%define CHAN4                        3
%define CHAN5                        4
%define CHAN6                        5
%define CHAN7                        6
%define CHAN8                        7
%define NUM_MUSIC_CHANS              4
%define NUM_CHANNELS                 8
%define REG_DUTY_SOUND_LEN           1
%define REG_VOLUME_ENVELOPE          2
%define REG_FREQUENCY_LO             3
%define BIT_PERFECT_PITCH            0
%define BIT_SOUND_CALL               1
%define BIT_NOISE_OR_SFX             2
%define BIT_VIBRATO_DIRECTION        3
%define BIT_PITCH_SLIDE_ON           4
%define BIT_PITCH_SLIDE_DECREASING   5
%define BIT_ROTATE_DUTY_CYCLE        6
%define BIT_EXECUTE_MUSIC            0   ; wChannelFlags2
%define BIT_MUTE_AUDIO               7   ; wMuteAudioAndPauseMusic
%define BIT_LOW_HEALTH_ALARM         7   ; wLowHealthAlarm
%define LOW_HEALTH_TIMER_MASK        0x7F
%define DISABLE_LOW_HEALTH_ALARM     0xFF

; Map ids used by CheckForNoBikingMusicMap (constants/map_constants.asm)
%define MAP_ID_INDIGO_PLATEAU        0x09
%define MAP_ID_ROUTE_23              0x22
%define MAP_ID_VICTORY_ROAD_1F       0x6C
%define MAP_ID_VICTORY_ROAD_2F       0xC2
%define MAP_ID_VICTORY_ROAD_3F       0xC6

; Misc WRAM ($CC–$CFC range)
%define wUnusedFlag                  0xCC5B   ; wUnusedFlag

; Title-screen state ($CD3D)
%define wTitleScreenScene            0xCD3D   ; wTitleScreenScene (byte; +1 = timer)
%define wTitleScreenTimer            0xCD3E   ; wTitleScreenTimer

; Name buffers (WRAM1) — sym-verified
%define wRivalName                   0xD349   ; wRivalName  — 11 bytes, '@'-terminated

; ---------------------------------------------------------------------------
; Save / options / naming WRAM (menus S7) — all sym-pinned
; (git show origin/symbols:pokeyellow.sym, bank 00). The save-region boundary
; symbols name the exact WRAM ranges pret's SaveMainData/SaveCurrentBoxData/
; SavePartyAndDexData serialize; src/save/dsv_io.asm writes/reads that set.
; ---------------------------------------------------------------------------
%define wSaveFileStatus              0xD087   ; 1 = no save, 2 = save present
%define wOptionsInitialized          0xD089   ; InitOptions gate (main_menu.asm)
%define wLetterPrintingDelayFlags    0xD357   ; text-speed delay flags (InitOptions)
; save-serialized WRAM ranges (pret ram/wram.asm section boundaries)
%define wMainDataStart               0xD2F6   ; = wPokedexOwned (main data block)
%define wMainDataEnd                 0xDA7F   ; = wBoxDataStart (1929 bytes)
%define wSpriteDataStart             0xC100   ; = wSpriteStateData1 (sprite block)
%define wSpriteDataEnd               0xC300   ; = wShadowOAM (512 bytes)
%define wBoxDataStart                0xDA7F   ; current-box block
%define wBoxDataEnd                  0xDEE1   ; (1122 bytes)
%define wPartyDataStart              0xD162   ; = wPartyCount (party block)
%define wPartyDataEnd                0xD2F6   ; = wMainDataStart (404 bytes)
%define wPokedexOwnedEnd             0xD309   ; = wPokedexSeen (owned-mon bitset end)
%define wPokedexSeenEnd              0xD31C   ; seen bitset end
; play time (main data; PrintPlayTime, main_menu.asm)
%define wPlayTimeHours               0xDA40
%define wPlayTimeMinutes             0xDA42
; box-change UI (save.asm ChangeBox)
%define wCurrentBoxNum               0xD59F   ; current PC box (low 7 bits) + changed-box bit 7
%define wBoxMonCounts                0xCD3D   ; NUM_BOXES scratch (GetMonCountsForAllBoxes)
%define wPikachuHappiness            0xD46F   ; saved by SavePartyAndDexData tail
; status-flag bytes (main_menu.asm / save.asm) — not previously aliased
%define wStatusFlags5                0xD72F   ; BIT_NO_TEXT_DELAY lives here
%define wStatusFlags6                0xD731   ; BIT_GAME_TIMER_COUNTING, special-warp bits
; new-game player-data init (engine/movie/oak_speech/init_player_data.asm) —
; addresses sym-verified against origin/symbols:pokeyellow.sym (2026-07-03).
%define wUnusedObtainedBadges        0xD356   ; wObtainedBadges+1 (wObtainedBadges = 0xD355)
%define wGameProgressFlags           0xD5EF   ; event-flag bit array
%define wGameProgressFlagsEnd        0xD6B7   ; one past the last event flag byte
%define wUnusedPlayerDataByte        0xD71A   ; set to $ff by InitPlayerData2
; naming screen (engine/menus/naming_screen.asm, package C)
%define wNamingScreenNameLength      0xCEE9
%define wNamingScreenSubmitName      0xCEEA
%define wAlphabetCase                0xCEEB
%define wNamingScreenLetter          0xCEED
%define wNamingScreenType            0xD07C   ; PLAYER/RIVAL/MON/BOX select
; main_menu.asm (E) / save.asm (H) — sym-verified (origin/symbols:pokeyellow.sym)
%define wDefaultMap                  0xD07B   ; boot default map (main_menu clears it)
%define wDestinationMap              0xD719   ; special-warp destination (HoF continue path)
%define wCableClubDestinationMap     0xD72C   ; SpecialEnterMap clears it (= wStatusFlags3 union)
%define wNumSetBits                  0xD11D   ; CountSetBits result byte (shared 0xD11D scratch)
%define wChangeBoxSavedMapTextPointer 0xCD3D   ; ChangeBox saves/restores wCurMapTextPtr here

; Tile-map save/restore buffers — relocated to echo RAM ($E000+) to avoid
; overlapping pret WRAM1 symbols.  All via constants; no hardcoded addresses
; in translated code.
; Layout in echo RAM ($E000–$F4E7, all within the DPMI allocation):
;   $E000  wSurroundingTiles / wTileMapBackup   1728 B ($6C0) → $E6BF
;   $E800  wOverworldMap                        2304 B ($900) → $F0FF   (MAP_BORDER=7)
;   $F100  wTileMapBackup2                      1000 B ($3E8) → $F4E7
; Next used symbol is GB_OAM ($FE00), so there is 2328 B of headroom above.
; NB: LoadTileBlockMap fills W_OVERWORLD_MAP_SIZE bytes UNCONDITIONALLY, so
; wOverworldMap's *declared* size — not the current map's footprint — is what
; must not overlap the next buffer. Growing MAP_BORDER 6→7 pushed wOverworldMapEnd
; from $F000 to $F100 and silently clobbered wTileMapBackup2's first 256 bytes
; until it was moved here.
%define wTileMapBackup               0xE000   ; wTileMapBackup (= wSurroundingTiles, see below)
%define wTileMapBackup2              0xF100   ; wTileMapBackup2 (1000 B)

; Overworld surrounding-tiles buffer (alias for wTileMapBackup)
; 48×36 = 1728 bytes; DrawTileBlock writes here before crop to wTileMap.
%define wSurroundingTiles            0xE000   ; wSurroundingTiles = wTileMapBackup

; --- Animated-object engine (menu-intro B1: engine/gfx/animated_objects.asm) ---
; RELOCATED (port-only): pret places this WRAM0 union branch at 0xC508 (the
; "OAM Buffer"/"Tilemap" union, 4th NEXTU: wAnimatedObjectsData). The port's
; wTileMap is 40x25 = 1000 bytes and SWALLOWS 0xC508 (wTileMap spans
; 0xC3A0-0xC787), so — exactly as wShadowOAMBackup did — the block goes to free
; echo RAM instead. It is intro-cinematic-only and never live at the same time
; as the overworld buffers below it. 200 bytes: 0xF600-0xF6C7.
;   Struct (16 B x 10, wAnimatedObject0..9), byte offsets used as raw literals in
;   the engine (pret does the same): 0 Index, 1 FramesetID, 2 AnimSeqID(callback),
;   3 TileID(VTileOffset), 4 XCoord, 5 YCoord, 6 XOffset, 7 YOffset, 8 Duration,
;   9 DurationOffset, a FrameIndex, b..f FieldB..FieldF.
; The engine indexes wShadowOAM (0xC300, kept at the pret address) by a LOW-byte
; offset in wCurrentAnimatedObjectOAMBufferOffset — page-aligned, so the offset
; adds directly to wShadowOAM in x86.
; Pointer model (menu-intro B1/B3): the Spawn/Frames/OAMData tables are pure
; DATA (2-/3-byte GB-pointer structures). B3 generates them into a GB-space blob
; so the engine's pointer arithmetic (add hl,de x2/x3, 16-bit pointer reads)
; stays byte-identical to pret — those three stay 16-bit GB pointers (dw). The
; JUMPTABLE is different: its entries are callback CODE addresses, which in the
; port are 32-bit flat x86 labels (link-time, not bakeable into a GB data blob),
; so wAnimatedObjectJumptablePointer holds a 32-bit FLAT pointer and
; ExecuteCurrentAnimatedObjectCallback dispatches with a x4 stride
; (data-model DEVIATION, annotated in animated_objects.asm). Widening that one
; slot 2->4 bytes grows the block 200->202 B; safe — this is engine-internal
; runtime scratch, not Gen-1 save/party data (the byte-identical rule is scoped
; to mon structs).
%define wAnimatedObjectsData         0xF600   ; wAnimatedObjectsData (block base)
%define W_ANIMATED_OBJECTS_DATA_SIZE 0xCA   ; 202 B, ends 0xF6CA (wAnimatedObjectsDataEnd)
%define wAnimatedObjectStartTileOffsets 0xF600   ; ds 10*2 (20 B)
%define wAnimatedObjectDataStructs   0xF614   ; wAnimatedObject0 (10 x 16 = 160 B)
%define wNumLoadedAnimatedObjects    0xF6B4   ; db — running spawn counter → struct Index
%define wCurrentAnimatedObjectOAMBufferOffset 0xF6B5   ; ds 3 (LOW-byte shadow-OAM cursor)
%define wAnimatedObjectSpawnStateDataPointer 0xF6B8   ; dw → per-set spawn table (GB blob)
%define wAnimatedObjectFramesDataPointer 0xF6BA   ; dw → per-set frame-script table (GB blob)
%define wAnimatedObjectJumptablePointer 0xF6BC   ; dd → per-set callback jumptable (FLAT, port)
%define wAnimatedObjectOAMDataPointer 0xF6C0   ; dw → per-set OAM template table (GB blob)
%define wCurAnimatedObjectOAMAttributes 0xF6C2   ; db — flip/prio/pal scratch for current frame
%define wCurrentAnimatedObjectVTileOffset 0xF6C3   ; db
%define wCurrentAnimatedObjectXCoord 0xF6C4   ; db
%define wCurrentAnimatedObjectYCoord 0xF6C5   ; db
%define wCurrentAnimatedObjectXOffset 0xF6C6   ; db
%define wCurrentAnimatedObjectYOffset 0xF6C7   ; db
%define wAnimatedObjectGlobalYOffset 0xF6C8   ; db
%define wAnimatedObjectGlobalXOffset 0xF6C9   ; db
; Yellow-intro scene state (menu-intro B3 will grow this; the engine already
; reads wYellowIntroCurrentScene in UpdateCurrentAnimatedObjectFrame: cp $7
; skips the per-OBJ attribute write during scene 7).
; RELOCATED: pret 0xC634 is inside the port's extended wTileMap too.
; pret's old wc634/wc635 aliases are gone as of upstream 51cb4a12, which also
; unions these two bytes with wSurfingMinigameMusicTempoEnabled /
; wSurfingMinigameCloudScrollFraction.
%define wYellowIntroCurrentScene     0xF6CA   ; db
%define wYellowIntroSceneTimer       0xF6CB   ; db
; saved struct base of the scene's current animated object (2 bytes; RELOCATED
; with the rest of the intro scene state). Free echo gap 0xF6CC-0xF6FF (before
; the anim-data blob at 0xF700).
%define wYellowIntroAnimatedObjectStructPointer 0xF6CC   ; dw

; --- Yellow-intro animated-object DATA region (menu-intro B1) ---
; The Frames/OAM/Spawn tables (pret data/sprite_anims/intro_frames.asm +
; intro_oam.asm + intro_yellow.asm's spawn table) are pure GB-pointer data. Per
; the B1 pointer model they stay 16-bit GB pointers, so each table is assembled
; flat with GB-base-relative internal pointers (its W_INTRO_* base + offset) and
; copied flat->GB once at intro init (CopyYellowIntroAnimatedObjectData,
; engine/movie/intro_yellow.asm), which composes the three mirrors back-to-back
; here — frames then OAM contiguous exactly as pret ROM lays them out
; ($fa0ea-$fa35a), spawn appended after. Each data mirror carries a `times`
; static assert that its assembled size matches these region deltas, so the
; fixed bases cannot silently drift from the tables. 657 B total; reserved
; 0x2A0. Intro-cinematic-only, echo RAM, never live with the overworld buffers.
%define W_INTRO_ANIM_DATA            0xF700   ; whole-region base (= W_INTRO_FRAMES_DATA)
%define W_INTRO_ANIM_DATA_SIZE       0x2A0   ; reservation (actual 0x291), ends <= 0xF9A0
%define W_INTRO_FRAMES_DATA          (W_INTRO_ANIM_DATA)   ; 0xF700, size 0x53 (src/data/sprite_anims/intro_frames.asm)
%define W_INTRO_OAM_DATA             (W_INTRO_ANIM_DATA + 0x53)   ; 0xF753, size 0x21D (src/data/sprite_anims/intro_oam.asm)
%define W_INTRO_SPAWN_DATA           (W_INTRO_OAM_DATA + 0x21D)   ; 0xF970 (engine/movie/intro_yellow.asm spawn table)
%define W_INTRO_SPAWN_DATA_SIZE      0x21   ; staged image ends 0xF991, inside the 0x2A0 reservation
; wLYOverrides / wLYOverridesBuffer — the intro's LY-override staging buffers (surfing wobble).
; Located in free echo RAM: wLYOverrides at 0xF500-0xF600, wLYOverridesBuffer at 0xF9A0-0xFAA0.
; The port does NOT emulate per-scanline LY overrides, but VBlankCopy transfers the data
; faithfully between them on Request7TileTransferFromC810ToC710.
%define wLYOverrides                 0xF500   ; wLYOverrides (ds 0x100)
%define W_LY_OVERRIDES_SIZE          0x100   ; 256 B, ends 0xF600 (< wAnimatedObjectsData 0xF600)
%define wLYOverridesEnd              (wLYOverrides + 0x100)   ; 0xF600
%define wLYOverridesBuffer           0xF9A0   ; wLYOverridesBuffer (ds 0x100)
%define W_LY_OVERRIDES_BUFFER_SIZE   0x100   ; 256 B, ends 0xFAA0 (< W_SURF_ANIM_DATA 0xFB00)
%define wLYOverridesBufferEnd        (wLYOverridesBuffer + 0x100)   ; 0xFAA0

; --- Surfing-Pikachu animated-object DATA region (Chunk 1) ---
; The Frames and OAM tables (pret data/sprite_anims/surfing_pikachu_frames.asm +
; surfing_pikachu_oam.asm) are pure GB-pointer data. As with the Yellow intro,
; they stay 16-bit GB pointers, assembled flat with GB-base-relative internal
; pointers (its W_SURF_* base + offset) and copied flat->GB at minigame init,
; composed back-to-back (frames then OAM, 258 + 446 = 704 bytes).
; Located in free echo RAM at 0xFB00 (after wLYOverridesBuffer 0xFA00-0xFB00,
; before GB_OAM 0xFE00).
%define W_SURF_ANIM_DATA             0xFB00   ; whole-region base (= W_SURF_FRAMES_DATA)
%define W_SURF_ANIM_DATA_SIZE        0x2C0   ; 704 bytes (0x102 frames + 0x1BE OAM), ends 0xFDCE <= 0xFE00
%define W_SURF_FRAMES_DATA           (W_SURF_ANIM_DATA)   ; 0xFB00, size 0x102 (src/data/sprite_anims/surfing_pikachu_frames.asm)
%define W_SURF_OAM_DATA              (W_SURF_ANIM_DATA + 0x102)   ; 0xFC02, size 0x1BE (src/data/sprite_anims/surfing_pikachu_oam.asm)


; Overworld map block buffer (2304 bytes). Worst case is Route 17 / Route 23 (10x72):
; (10 + 2*7) * (72 + 2*7) = 24 * 86 = 2064 bytes at MAP_BORDER=7, which overflows the old
; 2048. Grown to 0x900; end = 0xF100, and nothing is used until GB_OAM at 0xFE00.
%define wOverworldMap                0xE800   ; wOverworldMap
%define W_OVERWORLD_MAP_SIZE         0x900   ; wOverworldMapEnd − wOverworldMap (2304 bytes)

; Turn-delay state (pret: wCheckFor180DegreeTurn / wPlayerLastStopDirection)
; W_CHECK_FOR_TURN=1 means "first direction press changes facing only; walk starts on hold".
; Reset to 0 on the first press (so subsequent frames in same direction walk).
; Restored to 1 when no direction is held (.noDirection path).
%define W_CHECK_FOR_TURN             0xCADD   ; wCheckFor180DegreeTurn (1=check next press)
%define wPlayerLastStopDirection     0xCFAE   ; wPlayerLastStopDirection (dir held when player last stopped)

; Walk/sprite state
%define wFontLoaded                  0xCFC3
%define wWalkCounter                 0xCFC4   ; wWalkCounter
%define wTileInFrontOfPlayer         0xCFC5   ; wTileInFrontOfPlayer (collision check result)

; Sprite-engine scratch WRAM — sym-verified.
%define wSavedSpriteImageIndex       0xD5CC   ; wSavedSpriteImageIndex (PrepareOAMData scratch / VRAM base tile)
; Bit indices for wMovementFlags (pret: constants/ram_constants.asm)
%define BIT_STANDING_ON_DOOR         0   ; set by warp arrival; triggers auto-walk-off
%define BIT_EXITING_DOOR             1   ; set by PlayerStepOutFromDoor (door tile); player is auto-walking off door
%define BIT_STANDING_ON_WARP         2   ; edge-detect: 1 = player was on a warp tile last step
; bits 3–5 unused in Yellow

; Bit indices for wStatusFlags5 (pret: constants/ram_constants.asm)
%define BIT_UNKNOWN_5_1              1   ; cleared on entry to PlayerStepOutFromDoor (pret)
%define BIT_DISABLE_JOYPAD           5   ; input suppressed; CountDownIgnoreInputBitReset clears it
%define BIT_SCRIPTED_MOVEMENT_STATE  7   ; simulated joypad active (door exit / scripted walk)

; Map-tileset copies
%define wUnusedCurMapTilesetCopy     0xD118   ; wUnusedCurMapTilesetCopy
%define wWalkBikeSurfStateCopy       0xD119   ; = wWalkBikeSurfStateCopy (pret name)

; Joypad/input control
                                          ; (golden 00:cd6b; was wrongly 0xCCB7 — inside the 180-byte
                                          ;  wNPCMovementDirections buffer, clobbered by scripted moves)
%define wSimulatedJoypadStatesEnd    0xCCD3   ; wSimulatedJoypadStatesEnd — PAD_* byte queued by scripts
                                          ; (golden sym 00:ccd3; was wrongly 0xCC5B, colliding with
                                          ;  wNPCMovementDirections so MoveSprite zeroed step[0] — OW-2.2 fix)
%define wSimulatedJoypadStatesIndex  0xCD38   ; wSimulatedJoypadStatesIndex — steps remaining (0=done)
                                          ; (golden 00:cd38; was wrongly 0xCC84 — inside wNPCMovementDirections)
%define wUnusedSimulatedJoypadStatesMask 0xCD39   ; wUnusedSimulatedJoypadStatesMask (golden 00:cd39)
                                          ; Written (zeroed) by ItemUseSurfboard's .makePlayerMoveForward and
                                          ; never read — "Unused" is pret's own name for it, not a port note.
                                          ; Kept because the write is part of the routine's WRAM footprint and
                                          ; the golden compares it.
%define wIgnoreInputCounter          0xD139   ; wIgnoreInputCounter — counts down 30→0; clears BIT_DISABLE_JOYPAD

; Current-map script flags
%define wCurrentMapScriptFlags       0xD125   ; wCurrentMapScriptFlags

; Letter-printing delay and text speed options (text engine)
; Pret ref: constants/ram_constants.asm, engine/menus/main_menu.asm:InitOptions
%define wInitListType                0xD11A   ; pret sym d11a; InitList's selector (engine/battle/misc.asm)
%define wItemPrices                  0xCF8E   ; pret sym cf8e; InitList stashes the ItemPrices pointer here
%define wOptions                     0xD354   ; pret-name alias (bit 6 = battle style, 7 = battle anim)

; wOptions high-bit indices (pret ref: constants/ram_constants.asm BIT_BATTLE_*)
%define BIT_BATTLE_SHIFT             6   ; 0=SHIFT, 1=SET battle style
%define BIT_BATTLE_ANIMATION         7   ; 1=battle animations OFF (skip → fixed delay)
%define SOUND_MASK                   0x30   ; wOptions bits 4-5 = sound/earphone setting (S6 pkg D)

; Menus S6 package D (options) — sym-verified (origin/symbols:pokeyellow.sym).
; wOptionsCursorLocation is another lane of the 0xCD3D scratch union (aliases the
; badge/HoF/field-move/swap bytes; the OPTION menu is modal, never concurrent).
%define wOptionsCursorLocation       0xCD3D   ; highlighted OPTION row (0..7)
%define wPrinterSettings             0xD497   ; GB-Printer brightness value (stored, not sent)

; wLetterPrintingDelayFlags bit indices
%define BIT_FAST_TEXT_DELAY          0   ; 1=read speed from wOptions; 0=always 1 frame/char
%define BIT_TEXT_DELAY               1   ; 1=delay enabled; TextCommandProcessor sets this per session

; wStatusFlags5 bit for text delay suppression
%define BIT_NO_TEXT_DELAY            6   ; 1=skip all per-char delay (cutscenes, auto-scroll)

; wOptions text speed values (pret ref: constants/ram_constants.asm TEXT_DELAY_*)
%define TEXT_DELAY_FAST              1   ; 1 frame per character
%define TEXT_DELAY_MEDIUM            3   ; 3 frames per character (default)
%define TEXT_DELAY_SLOW              5   ; 5 frames per character
%define TEXT_DELAY_MASK              0x0F   ; bits 3-0 of wOptions hold text speed

; Current map identity
%define W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR 0xD35E   ; wCurrentTileBlockMapViewPointer (2 bytes)
%ifndef wNewTileBlockID
%define wNewTileBlockID              0xD09E   ; wNewTileBlockID (golden 00:d09e; ReplaceTileBlock)
%endif
%ifndef wBoulderSpriteIndex
%define wBoulderSpriteIndex          0xD717   ; golden 00:d717 (boulder push subsystem)
%endif
%ifndef wNumSprites
%define wNumSprites                  0xD4E0   ; golden 00:d4e0 (dup: overworld.asm, home/overworld.asm)
%endif
%define wTextPredefFlag              0xCF11   ; BIT_TEXT_PREDEF gates PrintPredefTextID text table
%define wSpriteIndex                 0xCF13   ; DisplayTextID stores hTextID/hSpriteIndex here
%define wItemList                    0xCF7A   ; mart item-list scratch
%define wItemListPointer             0xD127   ; big-endian pointer to current mart item list
%define wYCoord                      0xD360   ; wYCoord (player map Y, in tiles)
%define wXCoord                      0xD361   ; wXCoord (player map X, in tiles)
%define wYBlockCoord                 0xD362   ; wYBlockCoord
%define wXBlockCoord                 0xD363   ; wXBlockCoord
%define W_D433                       0xD433   ; wd433 — Pikachu collision direction (set by sprite collision engine)
; --- Overworld-Pikachu WRAM block (OW-A.11: promoted from pikachu.asm file-local placeholders).
; pokeyellow-real addresses, consistent with the existing Pikachu symbols here (W_D433,
; wPikachuHappiness $D46F, wPikachuMood $D470). Absolute anchoring rides the deferred gb_memmap
; Red-vs-Yellow decision (see memory gb_memmap-anchoring); the block is internally consistent
; (correct relative offsets) so it moves as a unit if the layout is ever re-anchored.
%define wPikachuOverworldStateFlags  0xD42F   ; bit1=following, bit2=moved, bit3=draw-disabled, bit5/7=hide
%define wPikachuSpawnState           0xD430   ; where/how Pikachu (re)spawns next (golden 00:d430; promoted from player_animations.asm local, OW-A.6)
%define wPikachuCollisionCounter     0xD434   ; post-turn grace frames before Pikachu-collision reactions (golden 00:d434)
; Pikachu follow-command ring, pret ram/wram.asm:2022-2023. Addresses read from
; pokeyellow.sym, not inferred. Promoted here 2026-08-18 from nine file-local
; `equ`s that each re-typed the same address.
%define wPikachuFollowCommandBufferSize 0xD436
%define wPikachuFollowCommandBuffer  0xD437   ; ds 16
%define wd435                        0xD435   ; golden 00:d435; unnamed in pret. Set to $ff by
                                        ; IsSpriteInFrontOfPlayer when the sprite faced is Pikachu.
%define wExpressionNumber            0xD447   ; pret ram/wram.asm:2025
%define wPikaPicAnimNumber           0xD448   ; pret ram/wram.asm:2026

%define wPikachuMovementScriptBank   0xD449   ; ROM bank of the active Pikachu movement script
%define wPikachuMovementScriptAddress 0xD44A   ; dw: cursor into the movement script
%define wSpritePikachuStateData1MovementStatus 0xC1F1   ; slot-15 data1+1 (wSpriteStateData1 $C100 + 15*$10 +1)
%define wSpritePikachuStateData1ImageIndex 0xC1F2   ; slot-15 data1+2 ($ff = off screen/hidden)
%define wLastMap                     0xD364   ; wLastMap

; Fixed map header (wCurMapHeader = wCurMapTileset at $D366)
; This is a contiguous 10-byte region that LoadMapHeader copies into from the ROM header.
; Layout: tileset(1) + height(1) + width(1) + dataptr(2) + textptr(2) + scriptptr(2) + connections(1)
%define wCurMapHeader                0xD366   ; wCurMapHeader (start of fixed header copy target)
%define BIT_NO_PREVIOUS_MAP          7   ; wCurMapTileset bit 7 (constants/ram_constants.asm) — set by save-load, LoadMapHeader res's it
%define wCurMapHeight                0xD367   ; wCurMapHeight
%define wCurMapWidth                 0xD368   ; wCurMapWidth
%define wCurMapDataPtr               0xD369   ; wCurMapDataPtr (2 bytes, LE)
%define wCurMapTextPtr               0xD36B
%define wCurMapScriptPtr             0xD36D   ; wCurMapScriptPtr (2 bytes, LE)
%define wCurMapConnections           0xD36F   ; wCurMapConnections (NORTH|SOUTH|WEST|EAST bits)
%define wCurMapHeaderEnd             0xD370   ; wCurMapHeaderEnd (byte after connections)
%define W_CUR_MAP_HEADER_SIZE        (wCurMapHeaderEnd - wCurMapHeader)   ; = 10 bytes

; lowercase aliases (pret-faithful wild-encounter / battle drafts)
%define wCurMap                      0xD35D   ; = wCurMap
%define wCurMapTileset               0xD366   ; = wCurMapTileset

; --- wild encounter WRAM (sym-pinned, origin/symbols:pokeyellow.sym) ---
; wGrassMons/wWaterMons each hold WILDDATA_LENGTH-1 (=20) bytes: 10×(level,species).
%define wGrassRate                   0xD886
%define wGrassMons                   0xD887
%define wWaterRate                   0xD8A3
%define wWaterMons                   0xD8A4
%define wRepelRemainingSteps         0xD0DA
%define wMoves                       0xD0DB   ; 4 move ids for FormatMovesString
%define wMoveNum                     0xD0DF
%define wMovesString                 0xD0E0   ; NUM_MOVES*MOVE_NAME_LENGTH (56), <NEXT>-joined
%define wNPCMovementScriptPointerTableNum 0xCC57
%define wMovementFlags               0xD735
%define wStringBuffer                0xCF4A   ; PrintStatText destination (Stage 5)
%define wGrassTile                   0xD534   ; = wGrassTile (tall-grass tile id)
%define wPartyMon1Level              0xD18B   ; lead party mon level (repel check)
%define wNameListIndex               0xD0B4   ; selected name id (GetName input; sym)
; --- name lookup (GetName / NamePointers; sym-pinned) ---
%define wNameListType                0xD0B5   ; which NamePointers list (MONSTER_NAME..TRAINER_NAME)
%define wPredefBank                  0xD0B6   ; ROM bank of the name list (flat port: ignored)
%define wNamedObjectIndex            0xD11D   ; resolved name index (=wPokedexNum/wMoveType union)
%define wNameBuffer                  0xCD6D   ; NAME_BUFFER_LENGTH dest (=wMoveData scratch union)
%define wUnusedNamePointer           0xCF8C   ; faithful: GetName stores last name ptr here
%define wPalletTownCurScript         0xD5F0   ; Pallet Town _Script state index (sym)
%define wAutoTextBoxDrawingControl   0xCF0C   ; bit BIT_NO_AUTO_TEXT_BOX: 0=auto-draw boxes
%define wDoNotWaitForButtonPressAfterDisplayingText 0xCC3C
%define wStatusFlags7                0xD732   ; = wStatusFlags7 (BIT_TEST_BATTLE)
%define wTestBattlePlayerSelectedMove 0xCCD9   ; debug TestBattle forced move

; --- Sprite (mon-pic) decompressor scratch (home/uncompress.asm) ---
; The 20-byte decompressor var block sits immediately before wCurSpecies ($D0B4)
; in pret's wram.asm (10 bytes + 5 words). Derived: $D0B4 - 0x14 = $D0A0; the block
; ends exactly at wCurSpecies (verifies the count). $D0A0-$D0B3 is otherwise unused.
%define wSpriteCurPosX               0xD0A0
%define wSpriteCurPosY               0xD0A1
%define wSpriteWidth                 0xD0A2   ; pixels (tiles*8)
%define wSpriteHeight                0xD0A3   ; pixels (tiles*8)
%define wSpriteInputCurByte          0xD0A4
%define wSpriteInputBitCounter       0xD0A5
%define wSpriteOutputBitOffset       0xD0A6   ; 3..0 → which 2-bit column of the output byte
%define wSpriteLoadFlags             0xD0A7   ; bit0 = use buffer2, bit1 = last chunk
%define wSpriteUnpackMode            0xD0A8
%define wSpriteFlipped               0xD0A9
%define wSpriteInputPtr              0xD0AA   ; dw
%define wSpriteOutputPtr             0xD0AC   ; dw
%define wSpriteOutputPtrCached       0xD0AE   ; dw
%define wSpriteDecodeTable0Ptr       0xD0B0   ; dw
%define wSpriteDecodeTable1Ptr       0xD0B2   ; dw

; Sprite buffers + save SRAM — pret ram/sram.asm, with port-resident banks.
; DEVIATION{class=banking; pret=ram/sram.asm:sGameData; behavior=SRAM banks 1 through 3 are resident at fixed EBP-relative offsets above the GB window rather than switched through A000-BFFF; evidence=current_plan_sram_pc_storage resident SRAM design and audited CopyData destination truncation require full 32-bit SRAM addresses; lifetime=permanent flat SRAM model}
; Bank 0 stays in the hardware SRAM window because the pic decoder stores its input
; pointer in the 2-byte GB slot wSpriteInputPtr. Banks 1-3 are contiguous after
; the back buffer at the next 0x1000-aligned address, so the eventual 32 KiB disk
; image is assembled from bank 0 at $A000 plus banks 1-3 at $22000..$27FFF.
%define GB_SRAM                      0xA000
%define GB_SRAM_BANK0                0xA000
%define GB_SRAM_BANK_SIZE            0x2000   ; one MBC5 SRAM bank
%define GB_SRAM_BANK1                0x22000
%define GB_SRAM_BANK2                0x24000
%define GB_SRAM_BANK3                0x26000
%define GB_SRAM_END                  0x28000

; Bank 0: ram/sram.asm "Sprite Buffers".
%define sSpriteBuffer0               0xA000
%define sSpriteBuffer0_SIZE          0x0188
%define sSpriteBuffer1               0xA188
%define sSpriteBuffer1_SIZE          0x0188
%define sSpriteBuffer2               0xA310
%define sSpriteBuffer2_SIZE          0x0188
%define sHallOfFame                  0xA598   ; after ds $100 following sSpriteBuffer2
%define sHallOfFame_SIZE             0x12C0   ; HOF_TEAM * HOF_TEAM_CAPACITY = 96 * 50

; PIC_STAGE — port-only GB scratch holding the COMPRESSED pic stream that
; UncompressSpriteData reads via wSpriteInputPtr.
; DEVIATION{class=data-model; pret=home/uncompress.asm:UncompressSpriteData; behavior=port-only compressed-pic scratch lives in bank 0 unused tail at B860 instead of the old A4A0 slot that overlapped sHallOfFame; evidence=ram/sram.asm puts sHallOfFame at A598 through B858 and current_plan_sram_pc_storage measured the largest compressed pic as 599 bytes; lifetime=until the pic decoder no longer stages through the 16-bit wSpriteInputPtr}
; The bytes are unused by a real save and ride along in the future raw SRAM image
; as harmless garbage. Headroom: $B860..$BFFF = 1952 bytes.
%define PIC_STAGE                    0xB860
%define PIC_STAGE_SIZE               0x07A0

; Bank 1: ram/sram.asm "Save Data" at SRAM bank 1, with the leading ds $598.
%define sGameData                    0x22598
%define sPlayerName                  0x22598
%define sPlayerName_SIZE             0x000B
%define sMainData                    0x225A3
%define sMainData_SIZE               0x0789
%define sSpriteData                  0x22D2C
%define sSpriteData_SIZE             0x0200
%define sPartyData                   0x22F2C
%define sPartyData_SIZE              0x0194
%define sCurBoxData                  0x230C0
%define sCurBoxData_SIZE             0x0462
%define sTileAnimations              0x23522
%define sTileAnimations_SIZE         0x0001
%define sGameDataEnd                 0x23523
%define sMainDataCheckSum            0x23523
%define sMainDataCheckSum_SIZE       0x0001

; Banks 2 and 3: ram/sram.asm "Saved Boxes 1" / "Saved Boxes 2".
%define sBox1                        0x24000
%define sBox1_SIZE                   0x0462
%define sBox2                        0x24462
%define sBox2_SIZE                   0x0462
%define sBox3                        0x248C4
%define sBox3_SIZE                   0x0462
%define sBox4                        0x24D26
%define sBox4_SIZE                   0x0462
%define sBox5                        0x25188
%define sBox5_SIZE                   0x0462
%define sBox6                        0x255EA
%define sBox6_SIZE                   0x0462
%define sBank2AllBoxesChecksum       0x25A4C
%define sBank2AllBoxesChecksum_SIZE  0x0001
%define sBank2IndividualBoxChecksums 0x25A4D
%define sBank2IndividualBoxChecksums_SIZE 0x0006

%define sBox7                        0x26000
%define sBox7_SIZE                   0x0462
%define sBox8                        0x26462
%define sBox8_SIZE                   0x0462
%define sBox9                        0x268C4
%define sBox9_SIZE                   0x0462
%define sBox10                       0x26D26
%define sBox10_SIZE                  0x0462
%define sBox11                       0x27188
%define sBox11_SIZE                  0x0462
%define sBox12                       0x275EA
%define sBox12_SIZE                  0x0462
%define sBank3AllBoxesChecksum       0x27A4C
%define sBank3AllBoxesChecksum_SIZE  0x0001
%define sBank3IndividualBoxChecksums 0x27A4D
%define sBank3IndividualBoxChecksums_SIZE 0x0006

; Connection-strip headers (each 11 bytes: map, strip-src, strip-dst, length, map-width, Y-align, X-align, view-ptr)
%define wNorthConnectedMap           0xD370   ; wNorthConnectedMap ($FF = none)
%define W_SOUTH_CONNECTED_MAP        0xD37B   ; wSouthConnectedMap
%define W_WEST_CONNECTED_MAP         0xD386   ; wWestConnectedMap
%define W_EAST_CONNECTED_MAP         0xD391   ; wEastConnectedMap

; Sprite/object data
%define wSpriteSet                   0xD39C   ; wSpriteSet (SPRITE_SET_LENGTH = 11 bytes, precedes wSpriteSetID)
%define wSpriteSetID                 0xD3A7   ; wSpriteSetID
%define W_OBJECT_DATA_PTR_TEMP       0xD3A8   ; wObjectDataPointerTemp (2 bytes)

; Map object header (follows connections in object data)
%define wMapBackgroundTile           0xD3AC   ; wMapBackgroundTile (border block ID for wOverworldMap)
%define wNumberOfWarps               0xD3AD   ; wNumberOfWarps
%define wWarpEntries                 0xD3AE   ; wWarpEntries (MAX_WARP_EVENTS * 4 bytes max)
%define wDestinationWarpID           0xD42E   ; pret alias of wDestinationWarpID
%define wUnknownSerialFlag_d499      0xD499   ; GB-Stadium-link flag; restricts Sleep counter reroll range when set (0 on real HW/this port)

; Sign/BG event data
%define wNumSigns                    0xD4AF   ; wNumSigns
%define wSignCoords                  0xD4B0   ; wSignCoords (MAX_BG_EVENTS * 2 bytes: Y, X pairs)
%define wSignTextIDs                 0xD4D0   ; wSignTextIDs (MAX_BG_EVENTS bytes)

%define MAX_WARP_EVENTS              32
%define MAX_BG_EVENTS                16

; Special-warp step offsets (incremented as the block-map pointer crosses
; block boundaries; faithful bookkeeping, not yet consumed by warp logic).
%define wYOffsetSinceLastSpecialWarp 0xD4E1   ; wYOffsetSinceLastSpecialWarp
%define wXOffsetSinceLastSpecialWarp 0xD4E2   ; wXOffsetSinceLastSpecialWarp

; Edge detection thresholds (height*2 / width*2) — used by CheckMapConnections
%define wCurrentMapHeight2           0xD523   ; wCurrentMapHeight2 = wCurMapHeight * 2
%define wCurrentMapWidth2            0xD524   ; wCurrentMapWidth2 = wCurMapWidth * 2

; Map-view VRAM pointer and player facing
%define wMapViewVRAMPointer          0xD525   ; wMapViewVRAMPointer (Stage A Note: dropped/unused after native renderer)
%define wPlayerMovingDirection       0xD527   ; wPlayerMovingDirection (PLAYER_DIR_*)
%define wPlayerDirection             0xD529   ; wPlayerDirection (PLAYER_DIR_*)

; Active tileset WRAM (set from tileset header by LoadTilesetHeader)
; LoadTilesetHeader copies 11 bytes here from the tileset header table,
; then reads the 12th byte (animations) to hTileAnimations.
%define wTilesetBank                 0xD52A   ; wTilesetBank (1 byte)
%define wTilesetBlocksPtr            0xD52B   ; wTilesetBlocksPtr (2 bytes, LE)
%define wTilesetGfxPtr               0xD52D   ; wTilesetGfxPtr   (2 bytes, LE)
%define wTilesetCollisionPtr         0xD52F   ; wTilesetCollisionPtr (2 bytes, LE; passable-tile list)
%define wTilesetTalkingOverTiles     0xD531   ; wTilesetTalkingOverTiles (3 bytes: counter tiles)
; NOTE: wTilesetGrassTile ($D534) is the same address as wGrassTile.
; LoadTilesetHeader copies it as part of the 11-byte block.
%define W_TILESET_HEADER_COPY_SIZE   11   ; bytes copied from tileset header to wTilesetBank
%define W_TILESET_HEADER_FULL_SIZE   12   ; full tileset header entry size (11 + animations)

; Walk/bike/surf state
%define wWalkBikeSurfState           0xD6FF   ; = wWalkBikeSurfState (pret name)

%define wUnusedCardKeyGateID         0xD71E   ; ItemUseCardKey's gate id (pret: "never checked")

; Status flags (game-state bitfields)
%define wStatusFlags1                0xD727   ; = wStatusFlags1 (pret name)
%define wStatusFlags2                0xD72B   ; pret alias of wStatusFlags2
%define wStatusFlags4                0xD72D   ; wStatusFlags4
%define wElite4Flags                 0xD733   ; wElite4Flags

; wStatusFlags bit indices (constants/ram_constants.asm) — consumed by EnterMap (OW-A.4).
; Some of these are ALSO defined (same value) in gb_constants.inc or under a local
; %ifndef in a consumer; NASM permits an `equ` redefinition to the
; identical value (verified 2026-07-27: same value assembles, a differing one is a hard
; "inconsistently redefined" error), so a file including both is fine. Duplicated here so
; overworld.asm (which includes only gb_memmap.inc + gb_macros.inc) sees them.
; The m8_2 and m1_3 copies were folded in 2026-07-27 when both scaffolds were deleted;
; no pending-symbol include remains.
%define BIT_WILD_ENCOUNTER_COOLDOWN  0   ; wStatusFlags2 bit 0 — grants 3 no-battle steps (dup: gb_constants.inc)
%define BIT_NO_NPC_FACE_PLAYER       5   ; wStatusFlags3 bit 5 — suppress NPC-face-player on this entry
%define BIT_TALKED_TO_TRAINER        6   ; wStatusFlags3 bit 6 — talked to a trainer this encounter (OW-A.6)
%define BIT_TRAINER_BATTLE           3   ; wStatusFlags7 bit 3 — current battle is a trainer battle (OW-A.6)
%define BIT_NO_BATTLES               4   ; wStatusFlags4 bit 4 — suppress wild battles
%define BIT_BATTLE_OVER_OR_BLACKOUT  5   ; wStatusFlags4 bit 5 — set on battle/blackout return
%define BIT_FLY_OR_DUNGEON_WARP      2   ; wStatusFlags6 bit 2 — entered via Fly OR dungeon warp
%define BIT_DEBUG_MODE               1   ; wStatusFlags6 bit 1 — debug-mode encounter override
%define BIT_FLY_WARP                 3   ; wStatusFlags6 bit 3 — entered via Fly warp (dup: items/town_map.asm)
%define BIT_DUNGEON_WARP             4   ; wStatusFlags6 bit 4 — entered via dungeon warp
%define BIT_ESCAPE_WARP              6   ; wStatusFlags6 bit 6 — Escape Rope / blackout warp
%ifndef BIT_NO_MAP_MUSIC
%define BIT_NO_MAP_MUSIC             1   ; wStatusFlags7 bit 1 — suppress this map's default music
%endif
%define BIT_CUR_MAP_LOADED_1         5   ; wCurrentMapScriptFlags bit 5 (dup: main_menu.asm, specific_script_flags.asm)
%define BIT_CUR_MAP_LOADED_2         6   ; wCurrentMapScriptFlags bit 6 (dup: specific_script_flags.asm)
%define BIT_CUR_MAP_USED_ELEVATOR    0x7   ; constants/ram_constants.asm:30 (const_def 5, third)
; Folded in from m8_2_pending_symbols.inc 2026-07-27 (constants/ram_constants.asm).
%define BIT_SEEN_BY_TRAINER          0   ; wMiscFlags bit 0 — ram_constants.asm:8
%define BIT_PRINT_END_BATTLE_TEXT    7   ; wStatusFlags3 bit 7
%define BIT_UNKNOWN_4_1              1   ; wStatusFlags4 bit 1 (dup: start_sub_menus.asm)
%define BIT_UNKNOWN_5_4              4   ; wStatusFlags5 bit 4
%define BIT_USE_CUR_MAP_SCRIPT       4   ; wStatusFlags7 bit 4

; Screen-area size constant (used by save/restore functions).
%define SCREEN_AREA                  (SCREEN_TILES_W * SCREEN_TILES_H)   ; 40 * 25 = 1000

; pret-compatible name aliases (hardware.inc uses SCREEN_WIDTH/HEIGHT, TILEMAP_WIDTH)
%define SCREEN_WIDTH                 (SCREEN_TILES_W)   ; 40
%define SCREEN_HEIGHT                (SCREEN_TILES_H)   ; 25
%define TILEMAP_WIDTH                (TILEMAP_W)   ; 32

; Overworld map geometry (constants/gfx_constants.asm + map_data_constants.asm)
%define BLOCK_WIDTH                  4   ; tiles per map block, X
%define BLOCK_HEIGHT                 4   ; tiles per map block, Y
%define SCREEN_BLOCK_WIDTH           12   ; blocks visible per screen row
%define SCREEN_BLOCK_HEIGHT          9   ; blocks visible per screen column
%define SURROUNDING_WIDTH            (SCREEN_BLOCK_WIDTH  * BLOCK_WIDTH)   ; 48 tiles wide
%define SURROUNDING_HEIGHT           (SCREEN_BLOCK_HEIGHT * BLOCK_HEIGHT)   ; 36 tiles tall
; MAP_BORDER must satisfy BOTH:
;     MAP_BORDER >= SCREEN_BLOCK_WIDTH  / 2 + 1   (= 7)
;     MAP_BORDER >= SCREEN_BLOCK_HEIGHT / 2 + 1   (= 5)
; The +1 is the slack a single step consumes: MoveTileBlockMapPointer{West,East,North,South}
; advances the view pointer at the START of a step, before wXCoord/wYCoord wrap and before
; CheckMapConnections runs. At 6 the horizontal slack was ZERO, so a west step at x=0 drove
; view_col to -1; since the pointer is a FLAT offset, that wrapped into the previous row's
; last column and the camera jumped a row (the long-standing E/W seam jutter). See
; docs/current_plan_overworld_port.md Stage B.
%define MAP_BORDER                   7   ; block-unit border around map in wOverworldMap

; Player movement direction bits (constants/sprite_data_constants.asm wPlayerDirection)
%define PLAYER_DIR_RIGHT             1
%define PLAYER_DIR_LEFT              2
%define PLAYER_DIR_DOWN              4
%define PLAYER_DIR_UP                8

; Sprite facing direction values (constants/sprite_data_constants.asm SPRITE_FACING_*)
%define SPRITE_FACING_DOWN           0x00
%define SPRITE_FACING_UP             0x04
%define SPRITE_FACING_LEFT           0x08
%define SPRITE_FACING_RIGHT          0x0C

; Dialog ▼ advance arrow (home/window.asm:HandleDownArrowBlinkTiming)
%define CHAR_DOWN_ARROW              0xEE   ; '▼' charmap code (constants/charmap.asm)
%define ARROW_ON_FRAMES              30   ; frames ▼ stays visible  (0.5 s at 60 Hz)
%define ARROW_OFF_FRAMES             8   ; frames ▼ stays hidden   (0.13 s at 60 Hz)
%define DIALOG_ARROW_TILEMAP_OFFSET  (4 * 32 + 18)   ; GB_TILEMAP1 row 4, col 18 = offset 146

; hJoyHeld bit positions (constants/hardware.inc B_PAD_*; active-high in hJoyHeld)
%define PAD_A                        (1 << 0)   ; B_BTN_A    = 0 (button byte low nibble)
%define PAD_B                        (1 << 1)   ; B_BTN_B    = 1
%define PAD_SELECT                   (1 << 2)   ; B_BTN_SELECT = 2
%define PAD_START                    (1 << 3)   ; B_BTN_START  = 3
%define PAD_RIGHT                    (1 << 4)   ; B_PAD_RIGHT = 4
%define PAD_LEFT                     (1 << 5)   ; B_PAD_LEFT  = 5
%define PAD_UP                       (1 << 6)   ; B_PAD_UP    = 6
%define PAD_DOWN                     (1 << 7)   ; B_PAD_DOWN  = 7

; Map object NPC flags (constants/map_object_constants.asm)
%define TRAINER_FLAG                 0x40   ; 1 << BIT_TRAINER
%define ITEM_FLAG                    0x80   ; 1 << BIT_ITEM

; RedrawRowOrColumn modes (constants/gfx_constants.asm)
%define REDRAW_COL                   1
%define REDRAW_ROW                   2

; LCDC bits the OBJ renderer reads (constants/hardware.inc)
%define LCDCF_OBJ_ON                 (1 << 1)   ; B_LCDC_OBJS  = 1 (sprites enabled)
%define LCDCF_OBJ_SIZE               (1 << 2)   ; B_LCDC_OBJ_SIZE = 2 (0 = 8×8, 1 = 8×16)

; OAM attribute byte bits (constants/hardware.inc)
%define OAM_PRIO                     (1 << 7)   ; OBJ drawn below BG colors 1-3
%define OAM_YFLIP                    (1 << 6)
%define OAM_XFLIP                    (1 << 5)
%define OAM_PAL1                     (1 << 4)   ; DMG: 0 = OBP0, 1 = OBP1
%define B_OAM_PAL1                   4   ; bit position of the OBP select bit

; SpriteFacingAndAnimationTable attribute markers (constants/oam_constants.asm).
; These are engine-internal bits in the facing tables, NOT hardware OAM bits.
%define BIT_SPRITE_UNDER_GRASS       1   ; tile drawn with BG priority when in grass
%define UNDER_GRASS                  (1 << BIT_SPRITE_UNDER_GRASS)   ; $02
%define FACING_END                   (1 << 0)   ; $01 — last OAM entry of a facing block
; CGB: OAM palette numbers %100-%111 select OBP1 (constants/oam_constants.asm).
%define OAM_HIGH_PALS                (1 << 2)   ; $04

; Player/sprite logic constants.
%define MAP_TILESET_SIZE             0x60   ; tile IDs >= $60 are text-box tiles, not map tiles
%define BIT_FONT_LOADED              0   ; wFontLoaded bit 0
%define BIT_SPINNING                 7   ; wMovementFlags (constants/ram_constants.asm)
%define BIT_LEDGE_OR_FISHING         6   ; wMovementFlags (constants/ram_constants.asm)
%define PLAYER_DIR_BIT_RIGHT         0
%define PLAYER_DIR_BIT_LEFT          1
%define PLAYER_DIR_BIT_DOWN          2
%define PLAYER_DIR_BIT_UP            3

; ROM-window area for embedded overworld assets.
; The unused ROM area ($0000–$7FFF, below VRAM) holds asset data that faithful
; routines (LoadTilesetTilePatternData, DrawTileBlock, LoadTileBlockMap,
; LoadMapHeader, LoadTilesetHeader) read via 16-bit pointers stored in WRAM.
; The whole layout is ALLOCATED by tools/generators/gen_map_headers.py and emitted to
; assets/rom_window.inc — do not hand-write addresses here again. The old
; hand-maintained table had silently overflowed: the map-headers blob ran
; $5400-$8D72, across INDOOR_BLK_GBADDR ($7600) and 3442 bytes into VRAM ($8000).
; The generator now hard-errors instead of warning. Addresses defined there:
;   OW_GFX_GBADDR / OW_BLOCKS_GBADDR / OW_COLL_GBADDR   (tileset windows)
;   OW_<MAP>_BLK_GBADDR                                 (resident outdoor .blk)
;   INDOOR_BLK_GBADDR / INDOOR_BLK_SLOT_SIZE            (shared indoor .blk slot)
;   OW_TILESET_HDR_GBADDR / OW_MAP_HEADERS_GBADDR       (the header blob)
;   OW_MAP_GBADDR (legacy alias), FIRST_INDOOR_MAP_ID
%include "assets/rom_window.inc"

; Connection-strip header field offsets (added to W_{NORTH,SOUTH,WEST,EAST}_CONNECTED_MAP;
; struct is 11 bytes — see map_connection_struct in macros/ram.asm).
%define CONN_STRIP_SRC               1   ; ConnectionStripSrc  (dw) — src in connected map's blocks
%define CONN_STRIP_DEST              3   ; ConnectionStripDest (dw) — dest in wOverworldMap border
%define CONN_STRIP_LENGTH            5   ; ConnectionStripLength (db)
%define CONN_MAP_WIDTH               6   ; ConnectedMapWidth (db)
%define CONN_Y_ALIGN                 7   ; ConnectedMapYAlignment (db)
%define CONN_X_ALIGN                 8   ; ConnectedMapXAlignment (db)
%define CONN_VIEW_PTR                9   ; ConnectedMapViewPointer (dw)
%define CONN_HEADER_SIZE             11   ; total connection header struct size

; Connection direction bits (constants/map_data_constants.asm)
%define CONNECTION_NORTH             (1 << 3)   ; bit 3 = $08
%define CONNECTION_SOUTH             (1 << 2)   ; bit 2 = $04
%define CONNECTION_WEST              (1 << 1)   ; bit 1 = $02
%define CONNECTION_EAST              (1 << 0)   ; bit 0 = $01

; Map IDs (constants/map_constants.asm — subset for implemented maps)
%define MAP_ID_PALLET_TOWN           0x00
%define MAP_ID_OAKS_LAB              0x28   ; pret OAKS_LAB (constants/map_constants.asm:72)
%define MAP_ID_ROUTE_1               0x0C
%define MAP_ID_ROUTE_21              0x20
%define MAP_NO_CONNECTION            0xFF   ; sentinel: no connected map in this direction

; IE register shadow — $FFFF (1 byte)
; Emulated Interrupt Enable register. Not functionally used by the DOS port
; (interrupts are handled by the PIT ISR and input handler directly).
%define GB_IE                        0xFFFF

; VRAM bank 1 (CGB only) — placed at offset $10000 (past the 64 KB GB window)
; The allocation in entry.asm covers this plus the back buffer and resident SRAM banks.
; CGB tile attribute data and extra tile graphics live here.
%define GB_VRAM1                     0x10000
%define GB_VRAM1_SIZE                0x2000   ; 8 KB

; Back buffer — 320×200 pixels, 8bpp (one byte per pixel, palette index)
; Placed just after VRAM bank 1. The tile-blitter writes here; present() copies to VGA.
; Size: 320 * 200 = 64000 bytes
%define GB_BACKBUF                   0x12000
%define GB_BACKBUF_SIZE              64000   ; RENDER_W * RENDER_H

; --- VRAM sub-regions the port names explicitly (pret ram/vram.asm battle union) ---
; vSprites $8000 (128 tiles) + vFont $8800 (128) then the two pic canvases.
%define vFrontPic                    0x9000   ; PIC_SIZE tiles (49*16 = 784 B), ends 0x9310
%define vBackPic                     0x9310   ; PIC_SIZE tiles, ends 0x9620

; RELOCATED (port-only): pret puts wTempPic at $C6E8. It cannot live there here —
; the port's wTileMap is 40x25 = 1000 bytes (the GB's is 20x18 = 360), so
; wTileMap spans 0xC3A0-0xC787 and SWALLOWS 0xC6E8, exactly as it swallows
; 0xC508 (wShadowOAMBackup / wAnimatedObjectsData above). Unlike those two it does
; NOT fit in echo RAM: 784 bytes are needed and the largest remaining echo gap is
; 768 (0xFB00-0xFDFF, after wLYOverridesBuffer). It goes in the unused 1536-byte
; gap between the back buffer (ends 0x21A00) and the emulated SRAM banks
; (0x22000) instead — still inside the single DPMI allocation and still
; EBP-relative, so FillMemory and every [ebp+esi] write address it unchanged.
; Its only consumers are the battle-animation mon-pic routines
; (AnimationMinimizeMon, AnimationSlideMonDownAndHide, CopyTempPicToMonPic and
; the Stage 5 substitute/transform pair), none of which needs a GB-visible
; address. CopyTempPicToMonPic passes `lea edx, [ebp + wTempPic]` because the
; port's CopyVideoData takes a FLAT source by design.
%define wTempPic                     0x21A00   ; PIC_SIZE tiles (784 B), ends 0x21D10
%define wTempPic_SIZE                0x310   ; 784 = PIC_SIZE * TILE_SIZE (hex so audit_memmap.py's EQU_RE picks it up)

; ---------------------------------------------------------------------------
; I/O register shadow offsets (EBP + IO_* = emulated register byte)
; Named to match constants/hardware.inc for cross-reference.
; ---------------------------------------------------------------------------

; Joypad ($FF00) — read-only from game; written by our INT 9h handler
%define IO_JOYP                      0xFF00   ; rJOYP

; Serial ($FF01/$FF02) — isolated; network HAL not yet implemented
%define IO_SB                        0xFF01   ; rSB  — TODO-HW: network HAL (Phase 4)
%define IO_SC                        0xFF02   ; rSC  — TODO-HW: network HAL (Phase 4)

; Divider / Timer — not translated; PIT-based main loop handles timing
%define IO_DIV                       0xFF04   ; rDIV  — not emulated (read returns 0)
%define IO_TIMA                      0xFF05   ; rTIMA — TODO-HW: not emulated
%define IO_TMA                       0xFF06   ; rTMA  — TODO-HW: not emulated
%define IO_TAC                       0xFF07   ; rTAC  — TODO-HW: not emulated

; Audio ($FF10–$FF26) — LIVE. See the "Virtual APU" block above: the GB sound
; registers live in emulated GB memory and the device shim reads them once per
; tick. Translate APU writes literally; do NOT emit a TODO-HW for them.
; (The "not yet implemented" header and the TODO-HW tag below were stale from
; the Phase-3 audio landing until 2026-08-02.)
%define IO_APU_BASE                  0xFF10   ; rAUD1SWEEP

; LCD Control ($FF40) — read by software renderer
%define IO_LCDC                      0xFF40   ; rLCDC — TODO-HW: renderer reads this
%define IO_STAT                      0xFF41   ; rSTAT — TODO-HW: renderer writes mode bits
%define IO_SCY                       0xFF42   ; rSCY  — TODO-HW: renderer
%define IO_SCX                       0xFF43   ; rSCX  — TODO-HW: renderer
%define IO_LY                        0xFF44   ; rLY   — TODO-HW: renderer emulates scanline counter
%define IO_LYC                       0xFF45   ; rLYC  — TODO-HW: renderer
%define IO_DMA                       0xFF46   ; rDMA  — TODO-HW: OAM DMA (software emulated)
%define IO_BGP                       0xFF47   ; rBGP  — DMG palette mapping
%define IO_OBP0                      0xFF48   ; rOBP0 — DMG sprite palette 0
%define IO_OBP1                      0xFF49   ; rOBP1 — DMG sprite palette 1
%define IO_WY                        0xFF4A   ; rWY   — TODO-HW: renderer
%define IO_WX                        0xFF4B   ; rWX   — TODO-HW: renderer

; CGB registers — palette, VRAM bank, WRAM bank, HDMA
%define IO_VBK                       0xFF4F   ; rVBK  — VRAM bank select (CGB)
%define IO_BGPI                      0xFF68   ; rBGPI — BG palette index (CGB)
%define IO_BGPD                      0xFF69   ; rBGPD — BG palette data (CGB)
%define IO_OBPI                      0xFF6A   ; rOBPI — OBJ palette index (CGB)
%define IO_OBPD                      0xFF6B   ; rOBPD — OBJ palette data (CGB)
%define IO_WBK                       0xFF70   ; rWBK  — WRAM bank select (CGB)

; ---------------------------------------------------------------------------
; Derived geometry constants (for PPU and renderer use)
; ---------------------------------------------------------------------------

; Tile dimensions (from constants/hardware.inc)
%define TILE_WIDTH                   8
%define TILE_HEIGHT                  8
%define TILE_SIZE                    16   ; 2 bits/pixel × 8×8 = 16 bytes per tile

; Logical GB screen dimensions (game-code uses these for tile addressing).
; NOTE: SCREEN_W/H are logical pixel dimensions; RENDER_W/H are the actual
; back-buffer/VGA dimensions (320×200 native, no scaling).
%define SCREEN_W                     160   ; logical pixels (kept for game-logic comparisons)
%define SCREEN_H                     144   ; logical pixels
%define SCREEN_TILES_W               40   ; viewport width in tiles (= RENDER_W / TILE_WIDTH)
%define SCREEN_TILES_H               25   ; viewport height in tiles (= RENDER_H / TILE_HEIGHT)

; --- per-cell BG attribute layer (src/ppu/ppu.asm) ---------------------------
; The CGB BG attribute byte, as carried by the port's per-cell override plane.
; These live here rather than in ppu.asm because a SCREEN publishing overrides
; (via SetBGCellAttrFlat) needs them as much as the compositor consuming them.
; The full rationale — why the full CGB format, which bits are implemented, and
; why the sentinel is a bit rather than a magic value — is at ppu.asm's
; BG_ATTR_PRESENT block. Keep the two in step.
%define BG_ATTR_PAL_MASK             0x07   ; bits 0-2  palette 0-7            IMPLEMENTED
%define BG_ATTR_BANK                 0x08   ; bit 3     tile pattern bank      RESERVED (Gen 2)
%define BG_ATTR_PRESENT              0x10   ; bit 4     port-only "override present" sentinel;
                               ;           unused by the CGB hardware format, so
                               ;           0 = no override and BSS zero-fill is
                               ;           the inert state by construction
%define BG_ATTR_XFLIP                0x20   ; bit 5                            IMPLEMENTED
%define BG_ATTR_YFLIP                0x40   ; bit 6                            IMPLEMENTED
%define BG_ATTR_PRIORITY             0x80   ; bit 7     BG-over-OBJ            RESERVED

; Player standing tile in wTileMap — derived from render_sprites +36/+96 shift and
; the Pallet Town view pointer (bg_scy=32, bg_scx=32 → sprite feet at bg_surface Y=143).
%define PLAYER_STANDING_ROW          17   ; wTileMap row containing player's feet
%define PLAYER_STANDING_COL          24   ; wTileMap col containing player's feet

; Native render dimensions (back buffer and VGA output)
%define RENDER_W                     320   ; back buffer / VGA width in pixels
%define RENDER_H                     200   ; back buffer / VGA height in pixels
%define RENDER_TILES_W               40   ; RENDER_W / TILE_WIDTH
%define RENDER_TILES_H               25   ; RENDER_H / TILE_HEIGHT

; Tilemap dimensions
%define TILEMAP_W                    32   ; tiles (256/8)
%define TILEMAP_H                    32   ; tiles (256/8)
%define TILEMAP_AREA                 1024   ; 32*32 bytes

; OAM entry layout (from constants/hardware.inc OAMA_* offsets)
%define OAM_Y_OFS                    16   ; subtract to get real screen Y
%define OAM_X_OFS                    8   ; subtract to get real screen X
%define OAM_ENTRY_SIZE               4   ; bytes per sprite entry
%define OAM_COUNT                    40

; VGA output geometry (Mode 13h, 320x200)
%define VGA_W                        320
%define VGA_H                        200
%define VGA_FRAMEBUF                 0xA0000   ; linear address of VGA framebuffer (flat DS)

; Tile-blitter writes directly to a 320×200 back buffer; present() is a
; straight rep movsd of 16,000 dwords.  No scaling, no letterbox.

; ---------------------------------------------------------------------------
; Wave 3 (home-rectification M3.3) — simulated-joypad + scripted-NPC movement +
; pathfinding. Addresses from pret ram/wram.asm + ram/hram.asm; the joypad HRAM
; chain is verified consecutive with the mapped hJoyPressed=0xFFB3/hJoyHeld=0xFFB4.
; wNPCMovementDirections (0xCC5B, ds 180) is the union base; wSimulatedJoypadStatesEnd
; (0xCCD3) and wNPCMovementDirections2 (0xCC97) overlay it at fixed pret offsets
; (used at disjoint times). No collisions with existing symbols (checked at integration).
; ---------------------------------------------------------------------------
%define hJoyLast                     0xFFB1   ; hJoyLast (also mapped locally in joypad.asm)
%define hJoyReleased                 0xFFB2   ; hJoyReleased (shared: joypad.asm + simulate_joypad.asm)
%define hRLEByteValue                0xFF81   ; hRLEByteValue (union base)
%define hStartTileID                 0xFFE1   ; hStartTileID — first tile id CopyUncompressedPicToTilemap places
%define hDividend2                   0xFFE5   ; hDividend2
%define hDivisor2                    0xFFE6   ; hDivisor2
%define hQuotient2                   0xFFE7   ; hQuotient2
%define wNPCMovementDirections       0xCC5B   ; wNPCMovementDirections (union base; sim-joypad end/dirs2 overlay it)
%define wUnusedOverrideSimulatedJoypadStatesIndex 0xCD3A   ; wUnusedOverrideSimulatedJoypadStatesIndex (golden 00:cd3a; was 0xCC86)
%define wOverrideSimulatedJoypadStatesMask 0xCD3B   ; wOverrideSimulatedJoypadStatesMask (golden 00:cd3b; was 0xCC87)
%define wRLEByteCount                0xCCD2   ; wRLEByteCount
%define wNPCNumScriptedSteps         0xCF0F   ; wNPCNumScriptedSteps
%define wNPCMovementScriptFunctionNum 0xCF10   ; wNPCMovementScriptFunctionNum
%define wNPCMovementScriptBank       0xCC58   ; wNPCMovementScriptBank (scripted-dispatch, macro-gated)
%define BIT_SCRIPTED_NPC_MOVEMENT    0   ; wStatusFlags5 bit — MoveSprite scripted NPC walk
; DoScriptedNPCMovement chain (OW-2.1) — pret engine/overworld/movement.asm
%ifndef wNPCMovementDirections2
%define wNPCMovementDirections2      0xCC97   ; 10-byte scripted-move direction buffer
                                          ; (golden sym 00:cc97 — unions with wNPCMovementDirections;
                                          ;  was wrongly 0xCF08. OW-2.2 fix)
%endif
%define wNPCMovementDirections2Index 0xCD37   ; = wUnusedLinkMenuByte (pret alias)
%define wNPCMovementScriptSpriteOffset 0xCF17   ; sprite offset controlled by NPC move script
%define wScriptedNPCWalkCounter      0xCF18   ; 8→0 per scripted step
%define BIT_INIT_SCRIPTED_MOVEMENT   7   ; wStatusFlags4 bit 7 — scripted move initialised

; wDefaultPaletteCommand (golden sym 00:cf1b) — the SET_PAL_* command that
; RunDefaultPaletteCommand / SET_PAL_DEFAULT resolves to. pret's _RunPaletteCommand
; substitutes it for SET_PAL_DEFAULT; SetPal_Overworld / SetPal_Battle /
; SetPal_GameFreakIntro publish it (engine/gfx/palettes.asm).
%define wDefaultPaletteCommand       0xCF1B

; wOnSGB (golden sym 00:cf1a) — pret's "running on SGB (or CGB)" flag, published by
; LoadSGB. The port sets it to 1 in home/init.asm: the DOS port IS colour hardware
; (VGA DAC, CGB-style slot palettes), and on real CGB hardware LoadSGB sets wOnSGB
; (measured in mGBA on the golden ROM: hOnCGB=1 AND wOnSGB=1), so every wOnSGB
; branch takes the colour/SGB path. Files that also carry a local %ifndef fallback
; for this address now resolve it from here.
%define wOnSGB                       0xCF1A

; FindPathToPlayer / CalcPositionOfPlayerRelativeToNPC (OW-2.2, pret engine/overworld/
; pathfinding.asm). HRAM addresses from golden sym (pret ram/hram.asm union at 0xFF95).
; hNPCMovementDirections2Index / hNPCSpriteOffset / hNPCPlayerYDistance overlay 0xFF95.
%define hNPCMovementDirections2Index 0xFF95   ; hNPCMovementDirections2Index (union @ FF95)
%define hNPCSpriteOffset             0xFF95   ; hNPCSpriteOffset (union @ FF95)
%define hNPCPlayerYDistance          0xFF95   ; hNPCPlayerYDistance (union @ FF95)
%define hNPCPlayerXDistance          0xFF96   ; hNPCPlayerXDistance
%define hFindPathNumSteps            0xFF97   ; hFindPathNumSteps
%define hFindPathFlags               0xFF98   ; hFindPathFlags (BIT_PATH_FOUND_Y/X)
%define hFindPathYProgress           0xFF99   ; hFindPathYProgress
%define hFindPathXProgress           0xFF9A   ; hFindPathXProgress
%define hNPCPlayerRelativePosPerspective 0xFF9B   ; hNPCPlayerRelativePosPerspective (0=player→NPC,1=NPC→player)
%define hNPCPlayerRelativePosFlags   0xFF9D   ; hNPCPlayerRelativePosFlags (BIT_PLAYER_LOWER_Y/X)
%define BIT_PATH_FOUND_Y             0   ; hFindPathFlags bit 0
%define BIT_PATH_FOUND_X             1   ; hFindPathFlags bit 1
%define BIT_PLAYER_LOWER_Y           0   ; hNPCPlayerRelativePosFlags bit 0 (target north)
%define BIT_PLAYER_LOWER_X           1   ; hNPCPlayerRelativePosFlags bit 1 (target west)
%ifndef wWhichPewterGuy
%define wWhichPewterGuy              0xD12E   ; PewterGuys selector (golden 00:d12e; unions
                                          ; wDungeonWarpDataEntrySize/wGymGateTileBlock/wWhichPrizeWindow)
%endif
; auto_movement.asm (OW-2.3) — Pallet Oak-walk / Pewter guide movement scripts
%ifndef wNumStepsToTake
%define wNumStepsToTake              0xCCA1   ; golden 00:cca1 (right after wNPCMovementDirections2)
%endif
%ifndef NO_INPUT
%define NO_INPUT                     0   ; constants/misc_constants.asm
%endif
%ifndef NPC_CHANGE_FACING
%define NPC_CHANGE_FACING            0xE0   ; constants/sprite_data_constants.asm
%endif
%ifndef TOGGLE_PALLET_TOWN_OAK
%define TOGGLE_PALLET_TOWN_OAK       0   ; constants/toggle_constants.asm (index 0)
%endif

; ---------------------------------------------------------------------------
; Wave 4 (home-rectification) — menu framework (yes_no / list_menu / window).
; Addresses from pret ram/wram.asm + ram/hram.asm; cross-checked against existing
; memmap anchors at integration (all new names, no collisions). Members also carry
; identical-value local placeholders (NASM allows same-value equ redef); these
; canonical defs are the single source of truth.
; ---------------------------------------------------------------------------
%define wMenuWrappingEnabled         0xCADC   ; HandleMenuInput up/down wrap gate
%define wMenuCursorLocation          0xCC30   ; dw — tile addr under the menu cursor (EraseMenuCursor)
%define wMenuJoypadPollCount         0xCC34   ; menu input timeout countdown (0 = disabled)
%define wMenuWatchMovingOutOfBounds  0xCC37   ; return up/down at list edge so caller can scroll
%define wListPointer                 0xCF8A   ; dw — source list for DisplayListMenuID
%define wCurListMenuItem             0xCF90   ; = wCurItem — id of highlighted list entry
%define wPrintItemPrices             0xCF92   ; list menu: append item price column
%define wListMenuID                  0xCF93   ; ITEMLISTMENU / MOVESLISTMENU / PRICED / PC-box
%define wLoadedMonBoxLevel           0xCF9A   ; wLoadedMon + 3 (box_struct BoxLevel; pret sym cf9a).
                                         ; Was 0xCFB3 (= wLoadedMon + 28, DV byte 2) until the
                                         ; bills_pc_ops golden caught the PC list printing a DV
                                         ; byte as the box level (want $0F got $76 at wLoadedMon
                                         ; level after the release-list entry print).
%define wLoadedMonLevel              0xCFB8   ; loaded-mon level
%define wIsKeyItem                   0xD123   ; set by IsKeyItem_ (list menu / toss)
%define wTextBoxID                   0xD124   ; DisplayTextBoxID dispatcher selector
%define wTwoOptionMenuID             0xD12B   ; YES_NO_MENU / WIDE_YES_NO / HEAL_CANCEL / ...
%define wChosenMenuItem              0xD12C   ; menu result: chosen item index
%define wMenuExitMethod              0xD12D   ; CHOSE_MENU_ITEM / CANCELLED_MENU
; HRAM — swap-items scratch (root-allocated free bytes after hDivideBCDBuffer 0xFFA5-A7)
%define hHalveItemPrices             0xFFA8   ; list_menu priced path
%define hSwapItemID                  0xFFA9   ; item-list SELECT swap scratch
%define hSwapItemQuantity            0xFFAA   ; item-list SELECT swap scratch
; ---------------------------------------------------------------------------
; Menus S2 (text_box / display_text_id_init) — pret ram/wram.asm + ram/hram.asm.
; wFieldMoves is golden-sym verified (00:cd3d): it shares the 0xCD3D+ scratch
; union (wTrainerSpriteOffset / slot-machine / HoF lanes — disjoint use). The
; earlier chain off wSimulatedJoypadStatesIndex put it at 0xCC89, inside the
; wNPCMovementDirections buffer (wrong). wMiscFlags counted back from
; wActionResultOrTookBattleTurn 0xCD6A (db ×5 + ds 9 between them);
; hFieldMoveMonMenuTopMenuItemX sits between hUILayoutFlags 0xFFFA and
; hPikachuSpriteVRAMOffset 0xFFFC.
; ---------------------------------------------------------------------------
%define wFieldMoves                  0xCD3D   ; 4 bytes — current mon's field-move name indices (golden 00:cd3d)
%define wNumFieldMoves               0xCD41   ; count of entries in wFieldMoves (golden 00:cd41)
%define wFieldMovesLeftmostXCoord    0xCD42   ; GB X of leftmost field-move name (golden 00:cd42)
%define wLastFieldMoveID             0xCD43   ; unused in pret (bookkeeping kept faithful; golden 00:cd43)
%define wMiscFlags                   0xCD60   ; bit BIT_NO_SPRITE_UPDATES: skip UpdateSprites in DisplayTextIDInit
; wMiscFlags bits (constants/ram_constants.asm:9-15). The boulder bits are canonical
; here as of overworld-events Stage 4; push_boulder.asm's copies are %ifndef-guarded.
%define BIT_BOULDER_DUST             1   ; boulder dust animation is running
%define BIT_NO_SPRITE_UPDATES        4   ; wMiscFlags bit (constants/ram_constants.asm)
%define BIT_TRIED_PUSH_BOULDER       6   ; player has tried pushing once (needs twice)
%define BIT_PUSHED_BOULDER           7   ; a boulder was pushed this frame
%define BIT_TURNING                  2   ; wMiscFlags bit — player is turning in place this frame (constants/ram_constants.asm)
%define BIT_USING_GENERIC_PC         3   ; wMiscFlags bit — HoF/Bill's/generic PC hosts the menu (S6 pkg F)
%define BIT_NO_MENU_BUTTON_SOUND     5   ; wMiscFlags bit — suppress the menu A-press SFX
%define wParentMenuItem              0xCCD3   ; players_pc parent-menu selection (= wAddedToParty; sym-verified, S6 pkg F)
%define hFieldMoveMonMenuTopMenuItemX 0xFFFB   ; GB X of the field-move menu cursor column

; ---------------------------------------------------------------------------
; Menus S5 (party menu realign) — pret ram/wram.asm + ram/hram.asm.
; Chained off verified anchors:
;   wSwitchPartyMonTempBuffer = union base 0xCC5B (= wNPCMovementDirections /
;     wAnimationType branch heads) + `ds 60` NEXTU lane (wram.asm:546).
;   wPartyMenuHPBarColors = wEnemyHPBarColor 0xCF1D + 1; wWhichPartyMenuHPBar =
;     +PARTY_LENGTH +1 (wStatusScreenHPBarColor) + ds 7 (wram.asm:1230-1237).
;   wPartyMenuTypeOrMessageID = wAnimationID 0xD07B + 1 (same db as
;     wNamingScreenType/wTempTilesetNumTiles); cross-checked forward to
;     wSlotMachineAllowMatchesCounter 0xD095 = +25 (wram.asm:1530-1615).
;   wPartyMenuAnimMonEnabled = 0xD095-union ENDU +2 (dw lane) + ds 2 +
;     wOutwardSpiralTileMapPointer db (wram.asm:1618-1629).
;   wSwappedMenuItem aliases the wChargeMoveNum 0xCD3D union byte (wram.asm:1016).
;   wLoadedMonStatus = wLoadedMon 0xCF97 (= wLoadedMonHP - MON_HP) + MON_STATUS.
;   hPartyMonIndex aliases hTextID 0xFF8C (ram/hram.asm:19-21); hSwapTemp heads
;     the hExperience 0xFF96 union lane (ram/hram.asm:166-168).
; ---------------------------------------------------------------------------
%define wSwitchPartyMonTempBuffer    0xCC97   ; 44 bytes — party-mon swap staging (union lane)
%define wPartyMenuHPBarColors        0xCF1E   ; PARTY_LENGTH bytes — 0 green / 1 yellow / 2 red
%define wWhichPartyMenuHPBar         0xCF2C   ; running index while RedrawPartyMenu_ colors bars
; The SGB BLK packet, and the CGB attribute buffer that IS the same bytes.
;
; ram/wram.asm:1256-1266 puts wCopyingSGBTileData / wWhichPartyMenuHPBar /
; wPalPacket on ONE `db` at 0xCF2C, so the 49-byte UNION opens at 0xCF2D, and
; wPartyHPBarAttributes heads that union's `ds 9` lane at +9.
;
; THIS ALIAS IS LOAD-BEARING, NOT AN ACCIDENT. UpdatePartyMenuBlkPacket writes
; `wPartyMenuBlkPacket + 8 + 1` with stride 6 (AddNTimes, indexed by
; wWhichPartyMenuHPBar); HandlePartyHPBarAttributes reads wPartyHPBarAttributes
; with stride 6. Same address, same stride — the SGB producer's writes ARE the
; CGB consumer's input, and the encodings interlock so that the low two bits of
; the SGB colour ((1<<2)|1, (2<<2)|2, (3<<2)|3) are the CGB palette index the
; reader recovers with `and $3`. The port models GB memory flat, so the union
; reproduces itself for free — exactly as it does for wTrainerCardBadgeAttributes.
; Cross-check: the union's `ds 29` lane gives wStringBuffer = 0xCF2D + 29 =
; 0xCF4A, which is the address already recorded for it below.
%define wPartyMenuBlkPacket          0xCF2D   ; $30 bytes — SGB BLK packet (union base)
%define wPartyHPBarAttributes        0xCF36   ; = wPartyMenuBlkPacket + 9; PARTY_LENGTH entries, stride 6
%define wPartyMenuTypeOrMessageID    0xD07C   ; NORMAL/USE_ITEM/BATTLE/TMHM/SWAP/EVO_STONE_PARTY_MENU
%define wPartyMenuAnimMonEnabled     0xD09A   ; nonzero ($40) while the selected mon's icon animates
%define wSwappedMenuItem             0xCD3D   ; = wChargeMoveNum union byte; SwitchPartyMon result
%define hPartyMonIndex               0xFF8C   ; = hTextID (ram/hram.asm union)
%define hSwapTemp                    0xFF95   ; byte-swap scratch (overlaps hDividend lane)

; --- screen-shake scratch (battle_animations Stage 3b) ----------------------
; Addresses MEASURED against the golden ROM symbol table, not derived from the
; port's HRAM (which root-allocates in this region — see hSwapItemID below):
;   00:ff96 hMutateWY   00:ff97 hMutateWX   00:d09f wDisableVBlankWYUpdate
; hMutateWY/WX sit in pret's ram/hram.asm NEXTU lane that also carries
; hExperience ($FF96-98), so the overlap is pret's own union, not a collision:
; the shake predefs and the experience math never run concurrently.
%define hMutateWY                    0xFF96   ; PredefShakeScreenVertically xor-walk state
%define hMutateWX                    0xFF97   ; PredefShakeScreenHorizontally xor-walk state
; Also spelled W_DISABLE_VBLANK_WY_UPDATE locally in src/home/vblank.asm, which
; is the consumer (commit_shadow_regs skips the WY commit when nonzero).
%define wDisableVBlankWYUpdate       0xD09F

; ---------------------------------------------------------------------------
; Menus S6 package B (draw_badges) — trainer-card badge scratch. All four sit
; in the big NEXTU union at ram/wram.asm:772 (badge lane at :959), so they
; alias the S5 wSwappedMenuItem / wChargeMoveNum union byte at 0xCD3D. Addresses
; taken verbatim from the authoritative origin/symbols:pokeyellow.sym bank 00
; (wBadgeNumberTile cd3d, wBadgeNameTile cd3e, wBadgeOrFaceTiles cd3f,
; wTempObtainedBadgesBooleans cd49); wObtainedBadges already present as
; wObtainedBadges 0xD355 (sym-confirmed). DrawBadges writes every scratch byte
; before reading it, so the union overlap is safe.
; ---------------------------------------------------------------------------
%define wBadgeNumberTile             0xCD3D   ; tile id of the badge number being drawn
%define wBadgeNameTile               0xCD3E   ; first tile id of the name being drawn
%define wBadgeOrFaceTiles            0xCD3F   ; ds NUM_BADGES+1 (+1 byte read by the back-shift)
%define wTempObtainedBadgesBooleans  0xCD49   ; ds NUM_BADGES (0=not obtained, 1=obtained)

; ---------------------------------------------------------------------------
; Party-mon icons (engine/gfx/mon_icons.asm + the OAM writers pret keeps in
; engine/items/town_map.asm). All five verbatim from origin/symbols:pokeyellow.sym
; bank 00 — see docs/plans/party_icons_oam.md.
;
; wMonPartySpritesSavedOAM is the frame-1 reference copy AnimatePartyMon flips back
; to. Its 96 bytes sit on the ram/wram.asm:772 NEXTU union base (0xCC5B), i.e. they
; alias wHallOfFame / wSwitchPartyMonTempBuffer / wNPCMovementDirections — that
; aliasing is pret's, not the port's; those lanes are not live during the party menu.
; wOAMBaseTile likewise aliases wStandingOnWarpPadOrHole / wGymTrashCanIndex (0xCD5B),
; exactly the union pret declares.
; ---------------------------------------------------------------------------
%define wMonPartySpritesSavedOAM     0xCC5B   ; OBJ_SIZE * 4 * PARTY_LENGTH (96) — icon frame-1 copy
%define wOAMBaseTile                 0xCD5B   ; = wStandingOnWarpPadOrHole (pret union)
%define wSymmetricSpriteOAMAttributes 0xCD5C   ; WriteSymmetricMonPartySpriteOAM's X-flip toggle
%define wMonPartySpriteSpecies       0xCD5D   ; WriteMonPartySpriteOAMBySpecies' input (naming screen)
%define wAnimCounter                 0xD08A   ; V-blanks elapsed in the icon's current frame

; ---------------------------------------------------------------------------
; Menus S6 package A (league_pc / oaks_pc) — Hall-of-Fame reader state. All
; addresses verbatim from origin/symbols:pokeyellow.sym bank 00. The HoF scalars
; sit in the ram/wram.asm:772 NEXTU union (same lane family as the badge/field-
; move/swap scratch), so wHoFMonSpecies/wHoFTeamIndex alias 0xCD3D; wHallOfFame
; (96 = HOF_TEAM bytes) aliases the wSwitchPartyMonTempBuffer union base 0xCC5B.
; The whole cluster is only live once the S7 save layer feeds LoadHallOfFameTeams;
; PKMNLeaguePC guards its team loop off while wNumHoFTeams==0, so it is dead now.
; ---------------------------------------------------------------------------
%define wHallOfFame                  0xCC5B   ; ds HOF_TEAM (96) — current team's mon records
%define wHoFMonSpecies               0xCD3D   ; = wHoFTeamIndex (union byte 0)
%define wHoFTeamIndex                0xCD3D
%define wHoFPartyMonIndex            0xCD3E
%define wHoFMonLevel                 0xCD3F
%define wHoFMonOrPlayer              0xCD40
%define wHoFTeamIndex2               0xCD41
%define wHoFTeamNo                   0xCD42
%define wWholeScreenPaletteMonSpecies 0xCF1C   ; species for SET_PAL_POKEMON_WHOLE_SCREEN
%define wNumHoFTeams                 0xD5A1   ; total recorded HoF teams (0 until S7)

; ---------------------------------------------------------------------------
; Wave 5 (home-rectification) — pokemon/item data (add_party_mon / add_mon /
; pokemon / give / money). Lowercase Dex aliases onto existing W_POKEDEX_*;
; new WRAM from pret ram/wram.asm chained off verified anchors.
; ---------------------------------------------------------------------------
%define wPokedexOwned                0xD2F6   ; 0xD2F6 (lowercase alias)
%define wPokedexSeen                 0xD309   ; 0xD309 (lowercase alias)
%define wUnusedAlreadyOwnedFlag      0xD152   ; pret dead store (write-only)
%define wEnemyMonNicks               0xD9ED   ; enemy party nicknames
; ClearVariablesOnEnterMap map-entry scratch (OW-1.1; sym-verified vs origin/symbols:pokeyellow.sym)
%define wWhichTrade                  0xCD3D   ; (union w/ wDayCareStartLevel scratch region)
%define wStandingOnWarpPadOrHole     0xCD5B   ; end of the FillMemory clear range from wWhichTrade
; Trade-animation exchange record ($CD3D, 30-byte UNION over the same scratch
; wWhichTrade lives in — pret ram/wram.asm:775-783). InGameTrade_PrepareTradeData
; fills it before the trade animation runs. Addresses read from pokeyellow.sym.
%define wTradedPlayerMonSpecies      0xCD3D
%define wTradedEnemyMonSpecies       0xCD3E
%define wTradedPlayerMonOT           0xCD41   ; ds NAME_LENGTH
%define wTradedPlayerMonOTID         0xCD4C   ; dw, big-endian as all GB IDs are
%define wTradedEnemyMonOT            0xCD4E   ; ds NAME_LENGTH
%define wTradedEnemyMonOTID          0xCD59   ; dw
%define wCompletedInGameTradeFlags   0xD736   ; dw, one bit per TRADE_FOR_* constant
%define wStepCounter                 0xD13A
%define wNumberOfNoRandomBattleStepsLeft 0xD13B   ; EnterMap grants 3 on WILD_ENCOUNTER_COOLDOWN (promoted from wild_encounter_check.asm, OW-A.4)
%define wUnusedMapVariable           0xD5A2
%define wCardKeyDoorY                0xD73E
%define wCardKeyDoorX                0xD73F   ; = wCardKeyDoorY + 1
%define wWhichDungeonWarp            0xD71D   ; which dungeon warp in the source map was used
%define wDayCareInUse                0xDA47   ; 1 = a mon is in the day-care (IncrementDayCareMonExp gate)
%define wDayCareMonName              0xDA48   ; day-care mon nickname
%define wDayCareMonOT                0xDA53   ; day-care mon OT name
%define wPlayerCoins                 0xD5A3   ; Game Corner coins (BCD, dw)
%define hCoins                       0xFFA0   ; hCoins (dw; union w/ hMoney area)

; Lowercase pret-name aliases onto pre-existing UPPERCASE defs (CLAUDE.md: keep
; pret labels for cross-referenceability). engine/pokemon label-rename pass.
%define hExperience                  0xFF96   ; 0xFF96 (alias of hProduct+1)
%define wLoadedMonSpecies            0xCF97   ; 0xCF97
%define wLoadedMonExp                (W_LOADED_MON_EXP)   ; 0xCFA5
%define wUpdateSpritesEnabled        0xCFCA   ; 0xCFCA

; engine/pokemon behavior layer (evolution/learn-move/status-screen). All
; sym-verified via origin/symbols:pokeyellow.sym; promoted from evolution.asm's
; in-file %ifndef self-aliases (docs/current_plan_pokemon_behavior.md Stage 0).
%define wLoadedMonHP                 0xCF98   ; wLoadedMon + MON_HP
%define wLoadedMonStatus             0xCF9B   ; wLoadedMon + MON_STATUS (PrintStatusCondition input)
%define wLoadedMonHPExp              0xCFA8   ; wLoadedMon + MON_STAT_EXP (HP stat-exp)
%define wLoadedMonMaxHP              0xCFB9   ; wLoadedMon + MON_MAXHP (first computed stat)
%define wLoadedMonStats              0xCFB9   ; = wLoadedMonMaxHP (stats block starts at MaxHP)
; Status/summary screen inputs (sym-verified vs origin/symbols; Stage 4).
%define wLoadedMonMoves              0xCF9F   ; wLoadedMon + MON_MOVES (4 move ids)
%define wLoadedMonOTID               0xCFA3   ; wLoadedMon + MON_OTID (2 bytes, big-endian)
%define wLoadedMonAttack             0xCFBB   ; stats block: MaxHP,Atk,Def,Spd,Spc (2 bytes each)
%define wLoadedMonDefense            0xCFBD
%define wLoadedMonSpeed              0xCFBF
%define wLoadedMonSpecial            0xCFC1
%define wStatusScreenHPBarColor      0xCF24   ; GetHealthBarColor output (cosmetic; palette Phase 5)
%define wStatusScreenCurrentPP       0xCD71   ; scratch: current move PP for StatusScreen2 PrintNumber
; GetMaxPP scratch + per-source move lists (sym-verified vs origin/symbols; Stage 4).
%define wPPUpCountAndMaxPP           0xCD73   ; = wMoveData + MOVE_PP + 1 (AddBonusPP work byte)
%define wUsingPPUp                   0xD11D   ; (union wMaxPP/wPokedexNum scratch — see GetMaxPP order)
%define wPartyMon1Moves              0xD172   ; party mon 0 move-id list (GetSelectedMoveOffset base)
%define wBoxMon1Moves                0xDA9D
%define wDayCareMonMoves             0xDA66
%define wEvolutionOccurred           0xD120   ; set when a mon evolved this EvolutionAfterBattle
%define wPikachuMood                 0xD470
%define wPikachuSpawnStateFlags      0xD471   ; pret ram/wram.asm:2075 (golden 00:d471)
%define wPikachuMapScriptFlags       0xD492
%define wPikachuEmotionModifier      0xD49B

; ---------------------------------------------------------------------------
; Trainer-header / trainer-sight / emotion-bubble / toggleable-object scratch.
;
; Folded in 2026-07-27 from the retired include/m8_2_pending_symbols.inc scaffold
; (M8.2, trainer-header engine), which was its own header's step 1: "move every
; WRAM/HRAM symbol into gb_memmap.inc and every constant into gb_constants.inc,
; then DELETE this include". Every address was resolved against the golden
; pokeyellow.sym during the M8.2 promotion (2026-07-24); those citations are kept
; verbatim below, because they are what makes each one checkable.
;
; Two of the scaffold's symbols were dropped rather than folded in — both had
; zero users:
;   * wEventFlags — superseded by wEventFlags + its alias below.
;   * wMapSpriteExtraData equ 0xD503 — a TRAP, deliberately not reinstated. The
;     port's array is flat .bss (src/engine/overworld/map_sprites.asm), and that
;     equ shadowed the real label's pret name with an emulated-WRAM address the
;     port never writes. It cost two silent bugs (EngageMapTrainer, PickUpItem;
;     the route3_sight golden caught the first). With the scaffold gone, the pret
;     name reaches the real array again — do not redefine it here.
; ---------------------------------------------------------------------------
%define wJoyIgnore                   0xCD6B   ; golden 00:cd6b (pret alias)
%define wStatusFlags3                0xD72C   ; golden 00:d72c (pret alias)
%define wEventFlags                  0xD746   ; golden 00:d746 (pret alias)
%define wCurMapScript                0xDA38   ; golden 00:da38
%define wTrainerHeaderFlagBit        0xCC55   ; golden 00:cc55
%define wEnemyMonOrTrainerClass      0xD712   ; golden 00:d712 — pret keeps this as a copy
                                           ;  SEPARATE from wCurOpponent precisely because
                                           ;  wCurOpponent is cleared before
                                           ;  EndTrainerBattle reads the class back
; The end-battle text slots are flat-adapted (dd, 4 bytes each), so only the win
; pointer keeps its golden base; lose/bank shift by the +2/+4 widening. All three
; land in the golden gap d08b..d094 (wOptionsInitialized 0xD089,
; wSlotMachineAllowMatchesCounter 0xD095 — no overlap).
%define wEndBattleWinTextPointer     0xD08B   ; golden 00:d08b (dw)   ** flat-adapted: 4 bytes **
%define wEndBattleLoseTextPointer    0xD08F   ; golden 00:d08d +2     ** flat-adapted: 4 bytes **
%define wEndBattleTextRomBank        0xD093   ; golden 00:d091 +2
%define wGymCityName                 0xCF5E   ; golden 00:cf5e
%define wGymLeaderName               0xCF6F   ; golden 00:cf6f
%define wToggleableObjectIndex       0xCC4D   ; golden 00:cc4d
%define wToggleableObjectList        0xD5CD   ; golden 00:d5cd (ds 16*2+1)
; golden 00:d032, but the flat dd widening (4 bytes) would overlap wLearnMoveMonName
; (0xD035); the port keeps its slot in the free d048..d04b gap (wTrainerBaseMoney
; 0xD045 word below, wIsInBattle 0xD056 above — no overlap).
%define wTrainerPicPointer           0xD048   ; port flat slot ** flat-adapted: 4 bytes **
; Trainer-sight / emotion scratch — the shared 0xCD3D+ union (slot-machine / HoF /
; badges / options), golden-sym verified 2026-07-09. The earlier guesses put the
; union base at 0xCD37, uniformly 6/7 bytes low, colliding with
; wNPCMovementDirections2Index and the sim-joypad control bytes.
%define wTrainerSpriteOffset         0xCD3D   ; golden 00:cd3d
%define wTrainerEngageDistance       0xCD3E   ; golden 00:cd3e
%define wTrainerFacingDirection      0xCD3F   ; golden 00:cd3f
%define wTrainerScreenY              0xCD40   ; golden 00:cd40
%define wTrainerScreenX              0xCD41   ; golden 00:cd41
%define wEmotionBubbleSpriteIndex    0xCD4F   ; golden 00:cd4f
%define wWhichEmotionBubble          0xCD50   ; golden 00:cd50
%define wSlotMachineBet              0xCD50   ; golden 00:cd50 — same union lane as the above


; ---------------------------------------------------------------------------
; Every remaining pret WRAM/HRAM label, generated from rgblink's own symbol file
; (tools/generators/gen_pret_ram.py -> assets/pret_ram.inc).
;
; INCLUDED LAST, ON PURPOSE. Every equ in there is %ifndef-guarded, so anything
; defined ABOVE in this file keeps its value and the port's deliberate
; relocations (wOverworldMap grown for MAP_BORDER=7, wLYOverrides, the
; wAnimatedObject* block, the `flat-adapted: 4 bytes` pointer widenings) are
; untouched. This only fills the gaps.
;
; Before this existed, a label this file lacked got re-declared ad hoc in
; whichever .asm needed it. NASM `equ` is FILE-LOCAL, so two files could disagree
; about an address and still assemble, link and pass every gate. That is how six
; wrong addresses shipped. Add new pret RAM symbols by regenerating, not by hand.
; ---------------------------------------------------------------------------
%include "assets/pret_ram.inc"

%endif ; GB_MEMMAP_INC
