; debug_dump.asm — runtime ground-truth memory dump (debug builds only).
;
; DEVIATION{class=HAL; pret=home/vblank.asm:VBlank; behavior=debug-only routines exfiltrate emulated GB memory and the back buffer to host files and drive scripted input, none of which exists in the Game Boy; evidence=this translation unit is assembled only into DEBUG_ harness builds and its labels are port-only diagnostics with no pret counterpart, writing via DPMI INT 31h AX=0300h because a protected-mode int 21h pointer is not translated under CWSDPMI; lifetime=permanent, the debug harness is port infrastructure not game code}
;
; Exfiltrates selected windows of emulated GB memory to a host file ("DUMP.BIN")
; so they can be hexdumped on the host. This bypasses the PPU/palette/blit
; entirely — the values written are the literal bytes in the GB address space,
; with no visual interpretation.
;
; Channel: DOS file I/O via the DPMI "Simulate Real Mode Interrupt" service
; (INT 31h AX=0300h). Under CWSDPMI a protected-mode `int 21h` with a DS:DX
; pointer is NOT auto-translated, so we allocate a conventional (<1 MB) DOS
; buffer (DPMI fn 0100h), stage the filename + data there, and reflect INT 21h
; AH=3Ch/40h/3Eh into real mode with the buffer's real-mode segment in DS.
;
; Wired in only under -D DEBUG_DUMP (see Makefile + overworld.asm EnterMap).
; After dumping, the program exits via INT 21h AH=4Ch — no game loop runs.
;
; Build: nasm -f coff -I include/ -I . -o debug_dump.o src/debug/debug_dump.asm

bits 32

%include "gb_memmap.inc"
%include "gb_macros.inc"
%include "gb_constants.inc"
%ifdef DEBUG_MAPSCRIPT_SIGHT
; Trainer-flow WRAM addresses the shared memmap has not absorbed yet (M8.2 scaffold).
%endif

extern ds_base
extern pal_rgb_table, bg_slot_pal, obj_slot_pal
extern tile_pal
%ifdef DEBUG_CALCSTATS
extern GetMonHeader
extern CalcStats
global RunCalcStatsTest
%endif
%ifdef DEBUG_PARTY
extern PrepareNewGameDebug
global RunPartySeedTest
%endif
%ifdef DEBUG_BAGMENU
extern PrepareNewGameDebug
extern LoadFontTilePatterns
extern StartMenu_Item
extern text_row_stride          ; text.asm — seeded to 40 to mirror the live path
global RunBagMenuTest
%endif
%ifdef DEBUG_PARTYMENU
extern PrepareNewGameDebug
extern LoadFontTilePatterns
extern StartMenu_Pokemon
global RunPartyMenuTest
%endif
%ifdef DEBUG_TEXTBOXID
extern PrepareNewGameDebug
extern LoadFontTilePatterns
extern DisplayTextBoxID
extern ClearSprites
extern hide_window
extern DelayFrame
global RunTextBoxIDTest
%endif
%ifdef DEBUG_TEXT
extern LoadFontTilePatterns
extern LoadTextBoxTilePatterns
extern PrintText                 ; src/home/window.asm — the one text printer
%if DEBUG_TEXT == 9
extern ShowTextStream            ; engine/overworld/map_sprites.asm — the NPC dialog entry
%endif
extern DelayFrame
global RunTextTest
%endif
%ifdef DEBUG_LISTMENU
extern PrepareNewGameDebug
extern LoadFontTilePatterns
extern DisplayListMenuID
%ifdef DEBUG_LISTMENU_QTY
extern DisplayChooseQuantityMenu        ; src/home/list_menu.asm
%endif
extern DelayFrame
global RunListMenuTest
%endif
%ifdef DEBUG_YESNO
global RunYesNoTest
extern YesNoChoice               ; src/home/yes_no.asm
extern YesNoChoicePokeCenter
extern LoadFontTilePatterns
extern LoadTextBoxTilePatterns
%endif
%ifdef DEBUG_ITEMBALL
extern UseItem                  ; home/item.asm — the pret home wrapper for UseItem_
%endif
%ifdef DEBUG_ITEMTM
extern PrepareNewGameDebug
extern LoadFontTilePatterns
extern LoadTextBoxTilePatterns
extern UseItem                  ; home/item.asm — the pret home wrapper for UseItem_
global RunTMHMTest
%endif
%ifdef DEBUG_ITEMPP
extern PrepareNewGameDebug
extern LoadFontTilePatterns
extern LoadTextBoxTilePatterns
extern UseItem                  ; home/item.asm — the pret home wrapper for UseItem_
global RunPPRestoreTest
%endif
%ifdef DEBUG_SURF
extern PrepareNewGameDebug
global RunSurfTestSeed
%endif
%ifdef DEBUG_LEDGE
extern PrepareNewGameDebug
global RunLedgeTestSeed
%endif
%ifdef DEBUG_FISH
extern PrepareNewGameDebug
global RunFishTestSeed
%endif
%ifdef DEBUG_TRAINER_ROUTE
%ifndef DEBUG_FISH
extern PrepareNewGameDebug
%endif
global RunTrainerRouteTestSeed
%endif
%ifdef DEBUG_ITEMSTONE
extern PrepareNewGameDebug
extern LoadFontTilePatterns
extern LoadTextBoxTilePatterns
extern UseItem                  ; home/item.asm — the pret home wrapper for UseItem_
global RunStoneTest
%endif
%ifdef DEBUG_BATTLE
extern PrepareNewGameDebug
extern LoadFontTilePatterns
extern LoadTextBoxTilePatterns
extern InitBattleCanvas
extern InitBattle                ; init_battle.asm — the pret wild/trainer dispatcher.
                                 ; The trainer oracles call it directly to stand in for
                                 ; OverworldLoop's wCurOpponent poll (Stage 1b).
extern DrawBattleIntroBox
extern SlideBattlePicsIn
extern DebugLoadEmbeddedEnemyFrontPic
extern LoadPlayerBackPic
extern DebugLoadEmbeddedTrainerPic
extern LoadEmbeddedBackPicFallback
extern DrawBattleMenu
extern MainInBattleLoop          ; core.asm — faithful battle loop (replaces bespoke DisplayBattleMenu loop)
extern MoveSelectionMenu         ; core.asm — the FIGHT sub-menu (DEBUG_MOVEMENU)
extern SaveBattleScreen          ; src/home/tilemap.asm — alias of the Buffer1 pair
extern RestoreBattleScreen       ; src/home/tilemap.asm — alias of the Buffer1 pair
extern EndBattleScreen
extern EndOfBattle               ; end_of_battle.asm — post-battle evolution + state reset
extern wBattleOver
extern WaitForAPress
extern DrawBattlePokeballs
extern HideBattlePokeballs
extern DrawBattleHUDs
extern DoEnemyAttackDamage
extern LoadWildMonMoves
extern SelectEnemyMove
extern GetCurrentMove                 ; engine/battle/core.asm — move record -> wPlayerMove*/wEnemyMove*
extern GetDamageVarsForPlayerAttack   ; engine/battle/core.asm
extern GetDamageVarsForEnemyAttack    ; engine/battle/core.asm
extern CalculateDamage                ; engine/battle/core.asm (ZF if 0 BP)
extern AdjustDamageForMoveType        ; engine/battle/core.asm
extern RandomizeDamage                ; engine/battle/core.asm
extern DelayFrame
%ifdef DEBUG_TRAINER_INIT
extern StartTrainerBattle
%endif
%ifdef DEBUG_TRAINER_RESULT
extern StartTrainerBattle
%endif
%ifdef DEBUG_TRAINER_RESULT
extern StoreTrainerHeaderPointer
extern ReadTrainerHeaderInfo
extern EndTrainerBattle
extern FinalizeTrainerBattleOutcome
extern Route3TrainerHeader0
extern ExecutePlayerMove
extern GainExperience
extern TrainerBattleVictory
extern ExecuteEnemyMove
extern HandlePlayerBlackOut
extern ResetStatusAndHalveMoneyOnBlackout
%endif
%ifdef DEBUG_BATTLE_GOLDEN
; --- Stage 2 golden gate: the REAL loaders replace the synthetic seed ---
extern LoadEnemyMonData               ; engine/battle/core.asm — real wild loader
extern CalcStats                 ; home/move_mon.asm — stat recompute from the spec DVs
extern CopyData                  ; home/copy.asm
extern LoadFrontSpriteByMonIndex ; src/home/pokemon.asm — real enemy front pic
extern LoadBattleMonFromParty         ; engine/battle/core.asm — real send-out loader
extern FlagAction                ; flag_action.asm
extern DisplayBattleMenu         ; core.asm — real menu (parks in HandleMenuInput)
extern LoadMonBackPic            ; src/engine/battle/init_battle.asm — sent-out mon's back pic
extern LoadScreenTilesFromBuffer1 ; src/home/tilemap.asm
extern DrawHUDsAndHPBars         ; engine/battle/core.asm
extern DrawEmptyDialogBox        ; battle_menu.asm
extern SaveScreenTilesToBuffer1  ; src/home/tilemap.asm
extern DrawBattleMenuBox         ; battle_menu.asm
%ifdef DEBUG_BATTLE_FAINT
extern ExecutePlayerMove         ; core.asm — the real player-turn/damage pipeline
extern HandleEnemyMonFainted     ; core.asm — faint + EXP chain (FaintEnemyPokemon, GainExperience)
%endif
%ifdef DEBUG_BATTLE_BLACKOUT
extern ExecuteEnemyMove          ; core.asm — the real enemy-turn/damage pipeline
extern HandlePlayerMonFainted    ; core.asm — RemoveFaintedPlayerMon + the black-out branch
%endif
%endif
global RunBattleTest
%endif
%ifdef DEBUG_LEARNMOVE
extern PrepareNewGameDebug
extern LoadFontTilePatterns
extern LoadTextBoxTilePatterns
extern InitBattleCanvas
extern LearnMoveFromLevelUp
extern DelayFrame
global RunLearnMoveTest
%endif
%ifdef DEBUG_STATUS
extern PrepareNewGameDebug
extern LoadFontTilePatterns
extern StatusScreen
%ifdef DEBUG_STATUS_PAGE2
extern StatusScreen2
%endif
global RunStatusScreenTest
%endif
%ifdef DEBUG_AUDIO
%include "assets/audio_constants.inc"
extern PlayMusic
extern PlaySound
extern DelayFrame
extern opl_dbg_snapshot
extern midi_dbg_snapshot
extern PlayPikachuSoundClip
extern pika_dbg_snapshot
extern hal_dbg_snapshot
extern tandy_dbg_snapshot
extern spk_dbg_snapshot
extern enh_dbg_snapshot
extern g_cfg_musicloop            ; src/audio/audio_hal.asm — /LOOP
global RunAudioTest
%endif
%ifdef DEBUG_PALLET_OAK
extern PalletTownDefaultScript
extern PalletTownPikachuBattleScript
extern PalletTownOakNotSafeComeWithMeScript
extern RunNPCMovementScript         ; src/home/npc_movement.asm
extern UpdateSprites
extern DelayFrame
global RunOakIntroTest
%endif
%ifdef DEBUG_MAPSCRIPT_SIGHT
extern RunMapScript
%ifndef DEBUG_PALLET_OAK
extern UpdateSprites
extern DelayFrame
%endif
global RunMapScriptSightTest
%endif

global DebugDumpMemory
global DumpBackbuffer
global DumpGBState
global DumpPalette
%ifdef DEBUG_NPC_WALK
global DumpNpcLog
global npc_log
global npc_log_n
global dbg_destTile
%endif
%ifdef DEBUG_SEAM
global SeamLogRecord
global DumpSeamLog
%endif

; Each window is WIN_SIZE bytes copied from [EBP + window_offset].
; The host-side layout is simply these windows concatenated in table order.
WIN_SIZE     equ 0x40
NUM_WINDOWS  equ 9
DUMP_TOTAL   equ NUM_WINDOWS * WIN_SIZE          ; 9 * 64 = 576 bytes

; GBSTATE.BIN layout, version 2 (fidelity harness) — SELF-DESCRIBING.
;
; v1 was three hardcoded regions, mirrored by hand in the Lua dumper and the
; differ: three copies of the same address/size list, none of which knew when
; the others drifted. WRAM is a moving target (gb_memmap.inc is edited as the
; port grows), so v2 carries its own region directory and every address/size
; below is SOURCED FROM A SYMBOL, never a literal:
;
;   +0x00  header (GBSTATE_HDR_SIZE = 16 B)
;            +0x00  magic "GBST"
;            +0x04  u8  version (2)
;            +0x05  u8  bit 7 = terminal dump reached; bits 0-6 = scenario id
;            +0x06  u16 region count
;            +0x08  u32 directory size in bytes
;            +0x0C  u32 total file size
;   +0x10  region directory: `count` x GBSTATE_DIRENT_SIZE (32 B) entries
;            +0x00  char name[20]  (NUL-padded; the differ's JOIN KEY)
;            +0x14  u32 gb_addr    (GB address the bytes came from)
;            +0x18  u32 size
;            +0x1C  u32 file_offset (filled in at dump time)
;   then    region payloads, concatenated in directory order.
;
; The differ (tools/golden_diff.py) reads this directory instead of hardcoding
; the layout, and cross-checks each region's gb_addr against the address the
; golden side resolved from pret's .sym — so a memmap drift on either side
; fails loudly instead of silently comparing the wrong bytes.
;
; The one region that is deliberately NOT the same shape as the golden's is
; wTileMap: the port dumps its full 40x25 canvas (the golden is the GB's 20x18),
; and the differ extracts the per-scenario subwindow. Same name, different size,
; by design.
GBSTATE_VERSION     equ 2
GBSTATE_HDR_SIZE    equ 16
GBSTATE_NAME_LEN    equ 20
GBSTATE_DIRENT_SIZE equ GBSTATE_NAME_LEN + 12    ; name + gb_addr + size + file_offset
GBSTATE_VRAM_SIZE   equ 0x1800

; battle_struct (pret macros/ram.asm:39) — species, HP, box level, status, 2
; types, catch rate, moves, DVs, level, 5 stats, PP. Derived, not a literal.
BATTLEMON_STRUCT_LENGTH equ 1 + 2 + 1 + 1 + 2 + 1 + NUM_MOVES + 2 + 1 \
                            + 2 * NUM_STATS + NUM_MOVES              ; = 29
; Scenario ids are generated from tools/scenario_manifest.json. The remaining
; fallbacks are non-golden debug gates retained by the generated include.
%include "assets/scenario_registry.inc"
%if GBSTATE_SCENARIO > 0x7f
    %error "GBSTATE scenario ids must leave bit 7 available for completion"
%endif
%define GBSTATE_TERMINAL (0x80 | GBSTATE_SCENARIO)
%if 0
; Historical hand-written dispatch retained in git history. The differ selects the golden by make
; target; ids: 0 other/unknown, 1 overworld (TRANSITION/BASELINE/WALK_NORTH),
; 2 STARTMENU, 3 STATUS, 4 STATUS_PAGE2, 5 PARTYMENU, 6 BAGMENU, 7 BATTLE,
; 8 OPTIONS, 9 TRAINERCARD, 10 G1 (dex list), 11 G2 (dex entry), 12 NAMINGSCREEN,
; 13 SIGNTEXT, 15 BATTLE_INTRO, 16 MOVEMENU (the FIGHT sub-menu), 17 ITEMTM,
; 18 ITEMSTONE, 19 ITEMUSE, 20 ITEMBALL).
; Id 14 is the battle-menu golden gate (DEBUG_BATTLE_GOLDEN + DEBUG_BATTLE_MENU,
; fidelity plan Stage 2); every %elifdef below names a gate the Makefile
; actually defines. Master's newer audit gates (DEBUG_TEXT, DEBUG_YESNO,
; DEBUG_LISTMENU_QTY, ...) have no id yet and tag as 0 — ids 21+ when they get one.
; ORDER MATTERS: a gate that IMPLIES another must be tested first — the Makefile's
; DEBUG_ITEMBALL block adds `-D DEBUG_BATTLE`, so ITEMBALL precedes BATTLE here or
; it would tag itself 7.
%ifdef DEBUG_STATUS_PAGE2
GBSTATE_SCENARIO equ 4
%elifdef DEBUG_STATUS
GBSTATE_SCENARIO equ 3
%elifdef DEBUG_STARTMENU
GBSTATE_SCENARIO equ 2
%elifdef DEBUG_PARTYMENU
GBSTATE_SCENARIO equ 5
%elifdef DEBUG_BAGMENU
GBSTATE_SCENARIO equ 6
%elifdef DEBUG_OPTIONS
GBSTATE_SCENARIO equ 8
%elifdef DEBUG_TRAINERCARD
GBSTATE_SCENARIO equ 9
%elifdef DEBUG_G1
GBSTATE_SCENARIO equ 10
%elifdef DEBUG_G2
GBSTATE_SCENARIO equ 11
%elifdef DEBUG_NAMINGSCREEN
GBSTATE_SCENARIO equ 12
%elifdef DEBUG_SIGNTEXT
GBSTATE_SCENARIO equ 13
%elifdef DEBUG_ITEMTM
GBSTATE_SCENARIO equ 17
%elifdef DEBUG_ITEMSTONE
GBSTATE_SCENARIO equ 18
%elifdef DEBUG_ITEMUSE
GBSTATE_SCENARIO equ 19
%elifdef DEBUG_ITEMBALL
GBSTATE_SCENARIO equ 20                 ; before DEBUG_BATTLE: ITEMBALL implies it
%elifdef DEBUG_MOVEMENU
GBSTATE_SCENARIO equ 16
%elifdef DEBUG_BATTLE_INTRO
GBSTATE_SCENARIO equ 15
%elifdef DEBUG_BATTLE_MENU
GBSTATE_SCENARIO equ 14                 ; battle menu golden (Stage 2; was reserved)
%elifdef DEBUG_BATTLE
GBSTATE_SCENARIO equ 7
%elifdef DEBUG_TRANSITION
GBSTATE_SCENARIO equ 1
%elifdef DEBUG_WALK_NORTH
GBSTATE_SCENARIO equ 1
%else
GBSTATE_SCENARIO equ 0
%endif
%endif

; DPMI real-mode call structure field offsets (DPMI 0.9 spec)
RMCS_EBX     equ 0x10
RMCS_EDX     equ 0x14
RMCS_ECX     equ 0x18
RMCS_EAX     equ 0x1C
RMCS_FLAGS   equ 0x20
RMCS_DS      equ 0x24
RMCS_SIZE    equ 0x32

; ---------------------------------------------------------------------------
section .data
align 4

%ifdef DEBUG_MAPSCRIPT_SIGHT
section .text

; ---------------------------------------------------------------------------
; RunMapScriptSightTest — map-script fidelity plan, Stage 3.
;
; Drives the per-frame map-script dispatch on a driver-wired map until that map's
; _Script engages a trainer that can see the player, then dumps. The compared
; surface is the trainer-flow WRAM (see the DEBUG_MAPSCRIPT_SIGHT gbregion rows
; below), which is what CheckFightingMapTrainers -> EmotionBubble ->
; TrainerWalkUpToPlayer mutate — and, because those headers are generated data,
; the only end-to-end check that assets/trainer_headers.inc is RIGHT and not just
; well-formed.
;
; WHY THIS LOOP AND NOT OverworldLoop — UPDATED 2026-08-04 (Stage 1b). The
; original reason is GONE: the port used to run TWO sight paths on a wired map
; (RunMapScript's faithful _Script -> CheckFightingMapTrainers, plus the
; port-only CheckTrainerSight/TrainerEncounterFlow pair called from
; OverworldLoopLessDelay), so entering the full loop engaged the trainer twice
; and could never match ground truth. That bespoke hook is now GATED OFF on
; every map dispatched to TrainerMapScript, which is every map these sight
; scenarios use — see the DEVIATION at the gate site in src/home/overworld.asm.
; The retirement this comment used to describe as a pending task HAS HAPPENED,
; and the continuous scenario it was a prerequisite for is trainer_battle_route
; (RunTrainerRouteTest below), which DOES drive the real OverworldLoop.
;
; This scenario deliberately keeps its tighter loop anyway: it is the focused
; per-map check that assets/trainer_headers.inc is right, and driving
; RunMapScript directly keeps its compared surface free of the joypad, walking
; and battle state a full-loop run necessarily moves. Seven maps share it, and a
; focused gate that fails for one reason is worth more than seven copies of the
; continuous one.
;
; In: EBP = GB memory base, map loaded, player seeded in the trainer's view range.
; Never returns (DumpBackbuffer writes GBSTATE.BIN + FRAME.BIN, then exits).
; ---------------------------------------------------------------------------
RunMapScriptSightTest:
    mov ecx, MAPSCRIPT_SIGHT_FRAMES
.frame:
    push ecx
    ; UpdateSprites first, as every overworld frame does: TrainerEngage reads the
    ; trainer's SCREEN position (wSpriteStateData1 YPIXELS/XPIXELS) and bails on an
    ; IMAGEINDEX of $FF, so a map-script dispatch with no sprite update behind it
    ; sees every trainer as off-screen and can never engage.
    call UpdateSprites
    call RunMapScript                     ; the map's _Script, once per frame
    call DelayFrame
    pop ecx
    ; wCurMapScript leaves 0 (the map's DEFAULT sub-script) only when
    ; CheckFightingMapTrainers engaged someone and advanced it.
    cmp byte [ebp + wCurMapScript], 0
    jne .engaged
    dec ecx
    jnz .frame
    ; Frame cap with no engagement: fall through and dump anyway, so the golden
    ; diff FAILS LOUDLY on an all-zero trainer-flow state instead of the harness
    ; quietly reporting a pass for a scenario that never happened.
.engaged:
    jmp DumpBackbuffer
%endif

%ifdef DEBUG_PALLET_OAK
section .text

; ---------------------------------------------------------------------------
; RunOakIntroTest — deterministic Oak-intro state gate.
;
; This is a state/boundary golden, not a live choreography recorder:
; - hits PalletTownDefaultScript's north-exit trigger,
; - hits PalletTownPikachuBattleScript's Pikachu battle seed,
; - hits PalletTownOakNotSafeComeWithMeScript's movement-script arm,
; - hits RunNPCMovementScript so the Pallet movement table consumer runs once,
; then dumps the rendered Pallet scene + GBSTATE terminal marker.
;
; The text-bearing states intentionally stay out of this gate while DisplayTextID
; is still a linked stand-in; Stage 2 owns that service closure.
; ---------------------------------------------------------------------------
RunOakIntroTest:
    mov byte [ebp + W_Y_COORD], 0
    mov byte [ebp + W_X_COORD], 10
    mov byte [ebp + W_DESTINATION_WARP_ID], 0xFF

    ; Let the default state observe the north exit and arm Oak's first state.
    call PalletTownDefaultScript

    ; Seed the battle boundary exactly as pret's Pikachu-battle state does.
    call PalletTownPikachuBattleScript

    ; Arm the player-follows-Oak movement table, then dispatch its first consumer.
    call PalletTownOakNotSafeComeWithMeScript
    call RunNPCMovementScript

    ; Publish one sprite update before dumping the scene.
    call UpdateSprites
    call DelayFrame
    jmp DumpBackbuffer
%endif

section .data
align 4

fname: db "DUMP.BIN", 0
fbname: db "FRAME.BIN", 0
fgbname: db "GBSTATE.BIN", 0
fpname: db "PAL.BIN", 0
%ifdef DEBUG_TEXT
; The text-engine oracle's probe streams (RunTextTest). Tier-1 data: generated,
; never hand-encoded — tools/generators/gen_text_oracle.py.
%include "assets/text_oracle.inc"
%endif

; ---------------------------------------------------------------------------
; GBSTATE.BIN region directory (layout spec at the GBSTATE_* equates above).
;
; MIRRORED BY (join key = the name string; addresses cross-checked at diff time):
;   tools/mgba_harness/lib/dump.lua  — dump.wram_regions(), resolving the SAME
;                                      names from pret's .sym
;   tools/golden_diff.py             — region policy (skips/masks/decoders)
;
; Every addr/size is a symbol or a symbol difference — gb_memmap.inc equates and
; the struct-length constants — so editing the memmap moves the dump with it.
; A region is "everything between symbol A and symbol B" wherever that is what it
; means; otherwise it is a named length constant.
;
; Excluded deliberately: NPC_DIALOG_BUF (port-bespoke staging WRAM with no GB
; counterpart — rendered text is compared as tilemap cells instead), the rival
; name span (build-define, not spec'd by seed.lua), and the wStringBuffer union
; (volatile multi-use scratch: its contents depend on which routine last ran).
%assign GBSTATE_PAYLOAD 0
%macro gbregion 3           ; %1 = name string, %2 = GB address, %3 = size
%%name: db %1
%if ($ - %%name) > GBSTATE_NAME_LEN
    %error "gbregion name too long for GBSTATE_NAME_LEN"
%endif
    times GBSTATE_NAME_LEN - ($ - %%name) db 0
    dd %2                   ; gb_addr
    dd %3                   ; size
    dd 0                    ; file_offset — filled in by DumpGBState
%assign GBSTATE_PAYLOAD GBSTATE_PAYLOAD + (%3)
%endmacro

align 4
gbstate_regions:
    ; --- video state (the v1 regions; wTileMap is the port's 40x25 canvas) ---
    gbregion "wTileMap",      W_TILEMAP,     W_TILEMAP_SIZE
    gbregion "vram_tiles",    GB_VRAM0,      GBSTATE_VRAM_SIZE
    gbregion "oam",           GB_OAM,        GB_OAM_SIZE
    ; --- player / save-block game data (compared in EVERY scenario) ---
    gbregion "wPlayerName",   wPlayerName,   NAME_LENGTH
    ; count + species list + $FF sentinel + 6 structs + 6 OT names + 6 nicks
    gbregion "wPartyData",    wPartyCount,   wPartyMonNicksEnd - wPartyCount
    ; owned + seen flag arrays, back to back (each NUM_POKEMON bits)
    gbregion "wPokedex",      wPokedexOwned, 2 * (wPokedexSeen - wPokedexOwned)
    gbregion "wBagItems",     wNumBagItems,  1 + BAG_ITEM_CAPACITY * 2 + 1
    gbregion "wPlayerMoney",  wPlayerMoney,  3      ; BCD
    ; wOptions, wObtainedBadges, wUnusedObtainedBadges, wLetterPrintingDelayFlags
    gbregion "wOptionsBlock", wOptions,      wPlayerID - wOptions
    gbregion "wPlayerID",     wPlayerID,     2
    ; --- battle / transient mon state (skipped per-scenario where unloaded) ---
    gbregion "wLoadedMon",    wLoadedMon,    PARTYMON_STRUCT_LENGTH
    ; wIsInBattle, wD057, wCurOpponent, wBattleType
    gbregion "wBattleFlags",  wIsInBattle,   wBattleType + 1 - wIsInBattle
    gbregion "wEnemyMonNick",  wEnemyMonNick,  NAME_LENGTH
    gbregion "wEnemyMon",      wEnemyMon,      BATTLEMON_STRUCT_LENGTH
    gbregion "wBattleMonNick", wBattleMonNick, NAME_LENGTH
    gbregion "wBattleMon",     wBattleMon,     BATTLEMON_STRUCT_LENGTH
; The stall-probe regions compile under EITHER the battle-frame photograph
; (AUTOKEY_DUMP_ON_BATTLE) or the state-gated follow-stall probe
; (AUTOKEY_DUMP_ON_FOLLOW). NASM %ifdef has no OR, so fold both into one helper.
%ifdef AUTOKEY_DUMP_ON_BATTLE
%define AUTOKEY_STALL_PROBE
%endif
%ifdef AUTOKEY_DUMP_ON_FOLLOW
%define AUTOKEY_STALL_PROBE
%endif
%ifdef AUTOKEY_STALL_PROBE
    ; Cutscene-stall probe (Oak intro debugging, 2026-08-06): the Pallet script
    ; step index + player map/coords, to localize where the intro wedges.
    gbregion "curMapCoord",   W_CUR_MAP,             5   ; wCurMap,-,-,wYCoord,wXCoord
    gbregion "palletScript",  wPalletTownCurScript,  1
    ; follow-stall probe: the NPC-movement-script engine state PLAYER_FOLLOWS_OAK
    ; waits on (wNPCMovementScriptPointerTableNum==0), plus the scripted-movement
    ; status bit and Oak's slot-1 sprite data.
    gbregion "npcMoveScript", wNPCMovementScriptPointerTableNum, 2  ; CC57 tablenum, CC58 bank
    gbregion "npcMoveFunc",   W_NPC_MOVEMENT_SCRIPT_FUNCTION_NUM, 1 ; CF10
    gbregion "statusFlags5",   W_STATUS_FLAGS_5,      1              ; D72F (BIT_SCRIPTED_NPC_MOVEMENT=0)
    gbregion "oakSlot1d2",    W_SPRITE_STATE_DATA_2 + 16, 16        ; Oak slot-1 data2 (MAPY/MAPX/facing/...)
    ; view pointer, to check the coord<->view projection is self-consistent
    ; (stride = mapwidth + 2*MAP_BORDER; view_col = (x>>1)+MAP_BORDER-SCREEN_BLOCK_WIDTH/2).
    gbregion "viewPtr",       W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR, 2
    ; who moved the player: door/warp + simulated-joypad state at the writing frame.
    gbregion "moveFlags",     W_MOVEMENT_FLAGS,      1     ; BIT_STANDING_ON_DOOR/BIT_EXITING_DOOR
    gbregion "destWarpId",    W_DESTINATION_WARP_ID, 1
    gbregion "simJoyIdx",     W_SIMULATED_JOYPAD_STATES_INDEX, 1
    gbregion "simJoyEnd",     W_SIMULATED_JOYPAD_STATES_END,   1
    gbregion "playerStepVec", W_SPRITE_PLAYER_Y_STEP_VECTOR,   3  ; C103 Yvec, C104, C105 Xvec
    gbregion "curMapWH",      W_CUR_MAP_HEIGHT,      2            ; height then width (blocks)
    ; input source at the writing frame: what direction is driving the walk?
    gbregion "joyHeld",       H_JOY_HELD,            1
    gbregion "joyPressed",    H_JOY_PRESSED,         1
    gbregion "joyIgnore",     W_JOY_IGNORE,          1
    gbregion "playerMoveDir", W_PLAYER_MOVING_DIRECTION, 1
    gbregion "walkCounter",   W_WALK_COUNTER,        1
    gbregion "statusFlags6",  W_STATUS_FLAGS_6,      1     ; BIT_FLY_WARP(3)/BIT_DUNGEON_WARP(4)
%endif
%ifdef DEBUG_BATTLE_DAMAGE
    ; The semantic differ validates each side against the legal Gen-1 damage
    ; set instead of asking unrelated RNG streams to produce the same byte.
    gbregion "damageOracle",    wBuffer,        30
%endif
%ifdef DEBUG_TRAINER_INIT
    ; Compact deterministic projection of trainer initialization. Enemy DVs and
    ; derived stats are intentionally excluded because the emulators do not
    ; share an RNG stream; roster identity, levels, active selection, prize
    ; metadata, AI reset, battle type and name prefix are exact.
    gbregion "trainerInit",      wBuffer,        30
%endif
%ifdef DEBUG_TRAINER_RESULT
    ; Compact terminal-state projection for the guarded trainer win/loss pair.
    ; Random trainer DVs/stats and transient presentation scratch are excluded;
    ; the result, money, persistent event/script state, HP/EXP and cleanup state
    ; are exact and shared by the real-navigation golden.
    gbregion "trainerResult",    wBuffer,        24
%endif
%ifdef DEBUG_BOX_SAVE
    ; --- the loaded PC box (SRAM/PC storage plan, stage 6 data half) ---
    ; SCENARIO-LOCAL for the same reason as the sight rows below: adding wBoxData
    ; to the shared set would relayout every committed golden. Mirrored by
    ; tools/mgba_harness/scenarios/save_boxes_load.lua; the differ joins by NAME
    ; and cross-checks the address, so the two must agree.
    ;
    ; One span covers the whole current-box block: count, the species list + $FF
    ; sentinel, 20 box_structs, 20 OT names and 20 nicknames. Unlike the sight
    ; rows there is no volatile scratch inside it -- every byte is saved data, so
    ; the enclosing block IS the tight span.
    gbregion "wBoxData",      wBoxDataStart, wBoxDataEnd - wBoxDataStart
%endif
%ifdef DEBUG_BILLSPC
    ; --- Bill's PC box-behaviour flow (sram plan stage 6) ---
    ; SCENARIO-LOCAL row (the DEBUG_BOX_SAVE precedent above): the whole
    ; current-box block after deposit/deposit/withdraw/release — count, species
    ; list + $FF sentinel, box_structs, OT names, nicknames, incl. the shifted
    ; residue _RemovePokemon leaves. tools/mgba_harness/scenarios/
    ; bills_pc_ops.lua mirrors it by name.
    gbregion "wBoxData",      wBoxDataStart, wBoxDataEnd - wBoxDataStart
%ifdef BILLSPC_MENU_PROBE
    ; Harness-diagnosis probe, NOT part of the golden: the whole HandleMenuInput
    ; state block (wTopMenuItemY..wMenuWatchMovingOutOfBounds), dumped mid-flow
    ; to see what a stuck menu is actually watching. Build with
    ; BILLSPC_MENU_PROBE=1; never enabled for a scenario run.
    gbregion "wMenuState",    wTopMenuItemY, 0x14
    gbregion "hJoyProbe",     H_JOY_PRESSED, 5   ; FFB3 pressed/held/joy5/joy6/joy7
%endif
%endif
%ifdef DEBUG_BILLSPC_CHANGEBOX
    ; --- change-box round trip (sram plan stage 6, SRAM banks 2/3) ---
    ; wBoxData proves the mon survived WRAM → sBox1 (bank 2) → WRAM through the
    ; BOX12 detour (bank 3); wCurrentBoxNum sits in wMainData (not a standard
    ; region) and must read back $80 = box 0 | BIT_HAS_CHANGED_BOXES.
    gbregion "wBoxData",      wBoxDataStart, wBoxDataEnd - wBoxDataStart
    gbregion "wCurrentBoxNum", wCurrentBoxNum, 1
%endif
%ifdef DEBUG_MAPSCRIPT_SIGHT
    ; --- trainer sight/engage flow (map-script fidelity plan Stage 3) ---
    ; SCENARIO-LOCAL rows: adding them to the shared set above would change every
    ; committed golden's .bin layout and force a full `make goldens`. The differ
    ; joins regions by NAME, so a scenario may carry extra ones as long as both
    ; sides emit them (tools/mgba_harness/scenarios/route3_sight.lua mirrors this
    ; list). Each is a tight span, not a convenient enclosing block: the bytes
    ; between these fields are volatile scratch that no two runs need to agree on.
    gbregion "wTrainerFlagBit", wTrainerHeaderFlagBit, 1
    gbregion "wEngagedTrainer",  wEngagedTrainerClass, 2   ; class, set
    gbregion "wTrainerEngage",   wTrainerEngageDistance, 4 ; distance, facing, screenY, screenX
    gbregion "wEmotionBubble",   wEmotionBubbleSpriteIndex, 2
    gbregion "wJoyIgnore",       wJoyIgnore, 1
    gbregion "wSpriteIndex",     wSpriteIndex, 1
    gbregion "wPlayerMapPos",    wCurMap, 5                ; wCurMap .. wXCoord
    gbregion "wStatusFlags5to7", wStatusFlags5, 4
    gbregion "wCurMapScript",    wCurMapScript, 1
    ; The persistent per-map script bytes, incl. w<Map>CurScript for the map under
    ; test — the byte TrainerMapScript reads and writes back.
    gbregion "wGameProgressFlags", wPalletTownCurScript - 1, 0x30
%endif
%ifdef DEBUG_SURF
    ; Surfboard scenario (items-plan Stage 11). Same rule as the sight rows above:
    ; scenario-local, mirrored by tools/mgba_harness/scenarios/surf_round_trip.lua,
    ; joined by NAME. These are the bytes the mount/dismount flow actually moves —
    ; none of them is in dump.standard_regions, so without this list the scenario
    ; would compare a party and a bag that the flow never touches and pass while
    ; proving nothing.
    gbregion "wPlayerMapPos",    wCurMap, 5                ; wCurMap .. wXCoord
    gbregion "wWalkBikeSurf",    wWalkBikeSurfState, 1     ; 0 walk, 1 bike, 2 surf
    gbregion "wWalkBikeSurfCopy", wWalkBikeSurfStateCopy, 1
    gbregion "wStatusFlags5to7", wStatusFlags5, 4          ; BIT_SCRIPTED_MOVEMENT_STATE
    gbregion "wTileInFront",     W_TILE_IN_FRONT_OF_PLAYER, 1
    gbregion "wPlayerDir",       W_PLAYER_DIRECTION, 1
    gbregion "wSimJoypad",       W_SIMULATED_JOYPAD_STATES_INDEX, 2 ; index + unused mask
    gbregion "wSimJoypadEnd",    W_SIMULATED_JOYPAD_STATES_END, 1
    gbregion "wJoyIgnore",       wJoyIgnore, 1
    gbregion "wPikachuSurf",     wPikachuOverworldStateFlags, 2 ; flags + spawn state
%endif
%ifdef DEBUG_LEDGE
    ; Ledge-hop scenario (regression-overworld-ledge-hop-never-advanced). Same
    ; rule as the sight/surf rows above: scenario-local, mirrored by
    ; tools/mgba_harness/scenarios/ledge_hop.lua, joined by NAME. These are the
    ; bytes HandleLedges arms and _HandleMidJump tears down; the post-teardown
    ; DOWN step is what moves wYCoord to 11 — if the teardown never runs, the
    ; step is eaten (wJoyIgnore stays $FF) and every one of these mismatches.
    gbregion "wPlayerMapPos",    wCurMap, 5                ; wCurMap .. wXCoord
    gbregion "wMovementFlags",   W_MOVEMENT_FLAGS, 1       ; BIT_LEDGE_OR_FISHING clear
    gbregion "wStatusFlags5to7", wStatusFlags5, 4          ; BIT_SCRIPTED_MOVEMENT_STATE clear
    gbregion "wSimJoypad",       W_SIMULATED_JOYPAD_STATES_INDEX, 2 ; index + unused mask
    gbregion "wSimJoypadEnd",    W_SIMULATED_JOYPAD_STATES_END, 2   ; both queued hop bytes
    gbregion "wJoyIgnore",       wJoyIgnore, 1             ; cleared by the teardown
    gbregion "wPlayerDir",       W_PLAYER_DIRECTION, 1
    gbregion "wWalkCounter",     W_WALK_COUNTER, 1         ; 0 = all motion finished
%ifdef DEBUG_LEDGE_TRACE
    gbregion "ledgeTrace",       0x26000, 0x1000           ; HandleMidJump call ring (debug aid)
%endif
%endif
%ifdef DEBUG_FISH
    ; Fishing-rod scenario (items-plan Stage 11). Same rule as the rows above:
    ; scenario-local, mirrored by tools/mgba_harness/scenarios/fish_old_rod.lua,
    ; joined by NAME. These are the bytes the rod flow writes: the response
    ; lane, the armed encounter, and the wWalkBikeSurfState round trip
    ; DoNotGenerateFishingEncounter performs around FishingAnim.
    gbregion "wPlayerMapPos",    wCurMap, 5                ; wCurMap .. wXCoord
    gbregion "wRodResponse",     wRodResponse, 1           ; 1 = bite
    gbregion "wCurOpponent",     wCurOpponent, 1           ; MAGIKARP armed
    gbregion "wCurEnemyLevel",   wCurEnemyLevel, 1         ; 5
    gbregion "wMoveMissed",      wMoveMissed, 1            ; 1 (bite path)
    gbregion "wWalkBikeSurf",    wWalkBikeSurfState, 1     ; restored 0 after anim
    gbregion "wWalkBikeSurfCopy", wWalkBikeSurfStateCopy, 1
    gbregion "wTileInFront",     W_TILE_IN_FRONT_OF_PLAYER, 1 ; $14 after the bump
    gbregion "wMovementFlags",   W_MOVEMENT_FLAGS, 1       ; BIT_LEDGE_OR_FISHING cleared
    gbregion "wStatusFlags5to7", wStatusFlags5, 4
%endif
%ifdef DEBUG_TRAINER_ROUTE
    ; Continuous trainer-route scenario (battle plan Stage 1b). Same rule as the
    ; rows above: scenario-local, mirrored by
    ; tools/mgba_harness/scenarios/trainer_battle_route.lua, joined by NAME.
    ;
    ; THE SURFACE IS CHOREOGRAPHY + REWARDS, NOT ARITHMETIC (merge-session ruling,
    ; mail thread 25). Damage and HP are deliberately absent: pinning them would
    ; require RNG lockstep between mGBA and the port through live menu timing, and
    ; per-turn damage math is already covered by 45/46's deterministic-turn design.
    ; The two reward bytes ARE pinned because they depend only on the defeated
    ; mons' species/level and the trainer class payout — zero RNG — and without
    ; them a run whose battle executed but rewarded wrongly would pass on
    ; choreography alone.
    ;
    ; wBattleResult / wIsInBattle / wCurOpponent: the battle ran and CLOSED. In
    ; particular wCurOpponent must be back to 0 — EndOfBattle.resetVariables clears
    ; it, and if it did not the loop's battle-entry poll would re-enter forever.
    gbregion "wBattleOutcome",   wBattleResult, 1
    gbregion "wIsInBattle",      wIsInBattle, 1
    gbregion "wCurOpponent",     wCurOpponent, 1
    ; The script state machine: wCurMapScript and Route 3's persistent script byte
    ; must both be back to 0 after EndTrainerBattle, and the trainer's persistent
    ; beaten bit (event byte $D7C2 bit 2) must be SET by the victory path.
    gbregion "wCurMapScript",    wCurMapScript, 1
    gbregion "wRoute3Script",    0xD5F7, 1
    gbregion "wRoute3Event",     0xD7C2, 1
    ; .battleOccurred's own flag work — the tail that only the real loop runs.
    gbregion "wStatusFlags3",    W_STATUS_FLAGS_3, 1       ; BIT_TALKED_TO_TRAINER cleared
    gbregion "wStatusFlags4",    W_STATUS_FLAGS_4, 1       ; BIT_BATTLE_OVER_OR_BLACKOUT set
    gbregion "wStatusFlags7",    W_STATUS_FLAGS_7, 1       ; BIT_TRAINER_BATTLE cleared
    ; Where the player ended up: the return re-enters the map, so map and coords
    ; must be the Route 3 spawn again, not a warp or a reload artifact.
    gbregion "wPlayerMapPos",    wCurMap, 5                ; wCurMap .. wXCoord
    ; The zero-RNG reward bytes.
    gbregion "wPlayerMoney",     wPlayerMoney, 3           ; BCD, prize added by AddBCD
    ; wPartyMon1Exp has no port symbol; build it from the struct base + offset the
    ; way wDayCareMonExp does in gb_memmap.inc. 3 bytes, BIG-ENDIAN (GB order).
    gbregion "wPartyMon1Exp",    wPartyMons + MON_EXP, 3   ; EXP gained by the lead
%endif
gbstate_regions_end:

GBSTATE_DIR_SIZE     equ gbstate_regions_end - gbstate_regions
GBSTATE_REGION_COUNT equ GBSTATE_DIR_SIZE / GBSTATE_DIRENT_SIZE
GBSTATE_TOTAL        equ GBSTATE_HDR_SIZE + GBSTATE_DIR_SIZE + GBSTATE_PAYLOAD
%ifdef DEBUG_NPC_WALK
fnlog: db "NPCLOG.BIN", 0
%endif
%ifdef DEBUG_SEAM
fseam: db "SEAMLOG.BIN", 0
%endif

; GB-address start of each 64-byte dump window. Host hexdump offsets:
;   0x000  overworld blockset (block 0..3)         — asset copy check
;   0x040  blockset entry for block 0x52           — DrawTileBlock src
;   0x080  PalletTown.blk (map block IDs)          — map asset copy
;   0x0C0  vTileset gfx in VRAM (tile 0,1,...)     — H2: tileset load
;   0x100  wOverworldMap start                     — LoadTileBlockMap
;   0x140  wSurroundingTiles                       — DrawTileBlock out
;   0x180  wTileMap (final view)                   — H1: tilemap
;   0x1C0  map header vars (curmap/dims/dataptr)   — header setup
;   0x200  tileset pointers (bank/blocks/gfx)      — pointer setup
; Addresses are the equs — the ROM window is allocator-packed (rom_window.inc)
; and moves whenever map data changes, so literals here WILL go stale.
%ifdef DEBUG_ITEMBALL
; ItemUseBall gate (items-plan Stage 6): the catch outcome + everything it mutates.
;   $D11B wCapturedMonSpecies (0 = not caught), $D11D wPokeBallAnimData
;         ($10 can't-catch / $20 miss / $61-$63 shakes / $43 caught)
;   $D162 wPartyCount + species list — a capture makes it 6 with the new species last
;   $D2FA party mon 6 struct — the caught mon (species, HP, level, DVs, catch rate)
;   $D31C bag: MASTER_BALL's qty must drop 99 → 98 (and only that slot changes)
;   $DA7F wBoxCount (must stay 0: the party had a free slot)
windows:
    dd 0xD11B    ; wCapturedMonSpecies / wPokeBallAnimData
    dd 0xD162    ; wPartyCount + wPartySpecies
    dd 0xD246    ; party mon 6 struct = wPartyMon1 + 5*44 ($D16A + 220) — the caught mon
    dd 0xD31C    ; wNumBagItems + (id,qty) pairs
    dd 0xDA7F    ; wBoxCount + wBoxSpecies
    dd 0xCFE4    ; wEnemyMon (species/HP/status — LoadEnemyMonData round-trip)
    dd 0xD2F6    ; wPokedexOwned (the caught species' bit must be set)
    dd 0xD309    ; wPokedexSeen
    dd 0xD11B    ; overview repeat
%elifdef DEBUG_ITEMTM
; Items-plan Stage 7 (DEBUG_ITEMTM) — teaching a TM/HM. Expectations:
;   $D16A party mon 1 struct — MON_MOVES (+$08) gains the machine's move; the PP
;         bytes (+$1D) get its base PP
;   $D0DF wMoveNum — the move TMToMove resolved from the machine
;   $D31C bag — a TM is consumed (count drops, slot 0 gone); an HM is NOT
;   $CD6A wActionResultOrTookBattleTurn — 2 = the player said no / it wasn't used
windows:
    dd 0xD16A    ; party mon 1 struct (species, HP, moves at +$08, PP at +$1D)
    dd 0xD31C    ; wNumBagItems + (id,qty) pairs — consumed (TM) or kept (HM)
    dd 0xD0DF    ; wMoveNum (+ wMovesString)
    dd 0xD11B    ; wTempTMHM / wNamedObjectIndex cluster ($D11D)
    dd 0xD162    ; wPartyCount + wPartySpecies
    dd 0xD2B4    ; wPartyMonNicks
    dd 0xCD6A    ; wActionResultOrTookBattleTurn
    dd 0xD035    ; wTempMoveNameBuffer / wLearnMoveMonName
    dd 0xD16A    ; overview repeat
%elifdef DEBUG_ITEMSTONE
; Items-plan Stage 8 (DEBUG_ITEMSTONE) — evolution stones. Expectations:
;   $D16A party mon 1 struct — species becomes the evolved form (VULPIX $52 +
;         FIRE_STONE -> NINETALES $53); stats are recalculated by TryEvolvingMon
;   $D162 wPartyCount + wPartySpecies — the species list entry evolves too
;   $D31C bag — the stone is consumed on success, KEPT when it has no effect
;   $CD6A wActionResultOrTookBattleTurn — 0 = item not used (no-effect / canceled)
;   $D155 wEvoStoneItemID — the stone ItemUseEvoStone parked for the party menu
windows:
    dd 0xCD3D    ; Stage 11: wWereAnyMonsAsleep. CAUTION: it reads 0 by dump time —
                 ; $CD3D is aliased scratch that the TEXT path reuses after the flute's
                 ; branch decision. The wake itself is visible as wPartyMon1Status
                 ; ($D16E, in the $D162 window) going 3 -> 0.
                 ; (was wWalkBikeSurfState $D6FF for the BICYCLE check — verified)
    dd 0xD31C    ; wNumBagItems + (id,qty) pairs
    dd 0xD162    ; wPartyCount + wPartySpecies
    dd 0xCD6A    ; wActionResultOrTookBattleTurn
    dd 0xD700    ; Stage 11: wUnusedCardKeyGateID ($D71E, +$1E) + wStatusFlags1
                 ; ($D727, +$27, BIT_UNUSED_CARD_KEY = bit 7) — drive with
                 ; ITEMSTONE_ID=CARD_KEY $30. Both stay 0 on real hardware: pret's
                 ; ItemUseCardKey reads the wrong byte and always falls to
                 ; ItemUseNotTime (see the BUG note there).
                 ; (was wEvoStoneItemID $D155 for Stage 8 — verified)
    dd 0xCCD3    ; wCanEvolveFlags + wForceEvolution
    dd 0xD000    ; Stage 11 (Safari): wEnemyMonActualCatchRate ($D006, +6) — drive with
                 ; ITEMSTONE_INBATTLE=1 and ITEMSTONE_ID=SAFARI_BAIT $15 (halves it) /
                 ; SAFARI_ROCK $16 (doubles it, saturating). The two Safari factors
                 ; ($CCE8/$CCE9) already fall inside the $CCD3 window above, at +$15/+$16.
                 ; (was wEvoOldSpecies/wEvoNewSpecies $CEE9 for Stage 8 — verified)
    dd 0xD0DA    ; wRepelRemainingSteps — Stage 9 (drive with ITEMSTONE_ID=REPEL
                 ; $1E / SUPER_REPEL $38 / MAX_REPEL $39; RunStoneTest dispatches
                 ; UseItem by wCurItem, so it exercises any item's handler)
    dd 0xD062    ; Stage 10: wPlayerBattleStatus2 (+$15 = wEscapedFromBattle @ $D077)
                 ; drive with ITEMSTONE_INBATTLE=1 and ITEMSTONE_ID=X_ACCURACY $2E /
                 ; DIRE_HIT $3A / GUARD_SPEC $37 / POKE_DOLL $33 / X_ATTACK $41
%elifdef DEBUG_CALCSTATS
; CalcStats gate: one 64-byte window over the test scratch at $D1E0 covers the
; scratch mon (DVs at +$1B) and both stat results (L5 at +$20, L100 at +$30).
windows:
    dd 0xD1E0
    dd 0xD1E0
    dd 0xD1E0
    dd 0xD1E0
    dd 0xD1E0
    dd 0xD1E0
    dd 0xD1E0
    dd 0xD1E0
    dd 0xD1E0
%elifdef DEBUG_PARTY
; Party-seed gate: party count + species list, the four seeded mon structs
; (44 B each from $D16A), party nicknames, and the bag (count + (id,qty) pairs).
windows:
    dd 0xD162    ; wPartyCount + wPartySpecies (6 + $FF) + start of mon1
    dd 0xD16A    ; party mon 1 struct (Snorlax)
    dd 0xD196    ; party mon 2 struct (Persian)  = $D16A + 44
    dd 0xD1C2    ; party mon 3 struct (Jigglypuff)
    dd 0xD1EE    ; party mon 4 struct (Pikachu)
    dd 0xD2B4    ; wPartyMonNicks (6 x 11)
    dd 0xD31C    ; wNumBagItems + bag (id,qty) pairs
    dd 0xD33C    ; bag items continued
    dd 0xD162    ; overview repeat
%elifdef DEBUG_WALKSPEED
; Walk-speed probe: one 64-byte window over the $D1E0 scratch holds the frame-rate
; measurement — +$00 start tick (dword), +$04 end tick, +$08 DelayFrame count.
; delta (end-start) == count → clean 60 Hz; delta < count → loop free-runs faster.
windows:
    dd 0xD1E0
    dd 0xD1E0
    dd 0xD1E0
    dd 0xD1E0
    dd 0xD1E0
    dd 0xD1E0
    dd 0xD1E0
    dd 0xD1E0
    dd 0xD1E0
%elifdef DEBUG_AUDIO
; Audio-engine gate: the whole engine RAM block + the virtual APU after 120
; ticks of Pallet Town BGM. Expected (music id $BA on CHAN1-3, tempo 160):
;   win1 $C026-2D = $BA,$BA,$BA,0,...   (wChannelSoundIDs)
;        $C006-0B = 3 in-blob LE pointers in $4000-$7FFF (command pointers)
;   win4 $C0C6 note speeds = 12; $C0E8/E9 wMusicTempo = $00,$A0 (big-endian)
;   win6 $FF10-26 nonzero pulse regs; $FF24 rAUDVOL = $77; $FF25 panning
windows:
    dd 0xC000    ; wSoundID/panning/vol, wChannelCommandPointers, ReturnAddrs, SoundIDs, Flags1/2
    dd 0xC040    ; duty patterns, vibrato arrays, freq low bytes, reload values
    dd 0xC080    ; pitch-slide arrays
    dd 0xC0B0    ; note delays, loop counters, speeds, octaves, volumes, tempos, ids, banks
    dd 0xC0F0    ; frequency/tempo modifiers
    dd 0xFF00    ; virtual APU: rAUD10-26 ($FF10-26) + wave RAM ($FF30-3F)
    dd 0xCFC0    ; fade block ($CFC6-C8) + wLastMusicSoundID ($CFC9)
    dd 0xD1E0    ; opl_dbg_snapshot: present, opl3, voice_state[0..61]
    dd 0xD220    ; SB detect (+0..6) + MIDI driver state (+7..: cfg,
                 ; present, active, on, dw progress, scale, cc7[16]);
                 ; $D240 pika PCM, $D246 shim device, $D248 tandy, $D250 spk, $D258 enh
%elifdef DEBUG_BATTLE
windows:
    dd 0xC468    ; W_TILEMAP row 5 (enemy HP-bar tile IDs, cols 12-20)
    dd 0xC5A8    ; W_TILEMAP row 13 (player HP-bar tile IDs, for comparison)
    dd 0xCFE4    ; wEnemyMon: species, HP hi(+1), HP lo(+2)
    dd 0xD0D6    ; wDamage
    dd 0xCFD1    ; wPlayerMove* (num,effect,power,type)
    dd 0xD014    ; wBattleMonHP (player HP, big-endian) — enemy-hit ground-truth
    dd 0xCFCB    ; wEnemyMove* (num,effect,power,type) — enemy-hit ground-truth
    dd 0xCFE4
    dd 0xD0D6
%else
windows:
    dd OW_BLOCKS_GBADDR             ; blockset blocks 0..3
    dd OW_BLOCKS_GBADDR + 0x52*16   ; blockset entry for block 0x52
    dd OW_PALLET_BLK_GBADDR         ; PalletTown.blk
    dd GB_VCHARS2                   ; vTileset gfx in VRAM
    dd W_OVERWORLD_MAP              ; wOverworldMap start
    dd W_SURROUNDING_TILES          ; wSurroundingTiles
    dd W_TILEMAP                    ; wTileMap
    dd W_CUR_MAP - 5                ; map header vars around wCurMap ($D358)
    dd W_TILESET_BLOCKS_PTR - 0xB   ; tileset header copy block ($D520)
%endif

; ---------------------------------------------------------------------------
section .bss
align 4
rmcs:        resb RMCS_SIZE      ; DPMI real-mode call structure
dos_seg:     resw 1              ; real-mode segment of DOS buffer
dos_sel:     resw 1              ; PM selector of DOS buffer (unused; freed via seg)
dos_flat:    resd 1              ; DS-relative (flat) offset of DOS buffer
file_handle: resw 1
stage:       resb DUMP_TOTAL     ; concatenated window bytes, staged here first
; PAL.BIN: 16-byte header, 64×RGB6 DAC entries, 384 tile slots, 8 BG + 8 OBJ ids.
PAL_HDR_SIZE    equ 16
PAL_DAC_SIZE    equ 64 * 3
PAL_TILEPAL_SIZE equ 384
PAL_TOTAL       equ PAL_HDR_SIZE + PAL_DAC_SIZE + PAL_TILEPAL_SIZE + 8 + 8
pal_stage:      resb PAL_TOTAL
pal_reg_tmp:    resd 1
%ifdef DEBUG_NPC_WALK
NPC_LOG_CAP  equ 4096            ; 12-byte records → 341 NPC walk-decisions
npc_log:     resb NPC_LOG_CAP    ; appended by movement.asm:npc_dbg_record
npc_log_n:   resd 1              ; bytes written so far
dbg_destTile: resb 1            ; tile CL at CanWalkOntoTile entry (saved before clobber)
%endif
%ifdef DEBUG_SEAM
SEAM_REC_SIZE equ 12
SEAM_LOG_CAP  equ 24576           ; 12-byte records → 2048 frames (~34 s of play)
seam_log:     resb SEAM_LOG_CAP   ; RING buffer, appended by SeamLogRecord
seam_log_i:   resd 1              ; write cursor (byte offset, wraps at CAP)
seam_log_n:   resd 1              ; total bytes ever written (may exceed CAP)
seam_out_len: resd 1              ; bytes actually staged for the file
%endif

; ---------------------------------------------------------------------------
section .text

%ifdef DEBUG_CALCSTATS
; ---------------------------------------------------------------------------
; RunCalcStatsTest — compute Bulbasaur (internal $99) stats at L5 and L100 with
; DVs=15 / stat-exp=0 into the $D1E0 scratch, then dump to DUMP.BIN. Validates
; GetMonHeader + CalcStat + _Multiply/_Divide end-to-end against canonical values.
; Never returns. Expected (big-endian words, host hexdump):
;   dump +$20 (L5):   HP=0015 Atk=000B Def=000B Spd=000B Spc=000D  (21/11/11/11/13)
;   dump +$30 (L100): HP=00E6 Atk=0085 Def=0085 Spd=007D Spc=00A5  (230/133/133/125/165)
; In: EBP = GB memory base.
; ---------------------------------------------------------------------------
RunCalcStatsTest:
    mov byte [ebp + wCurSpecies], 0x99      ; Bulbasaur internal index
    call GetMonHeader
    mov word [ebp + 0xD1FB], 0xFFFF         ; scratch DVs (all 15) at monbase+MON_DVS
    mov byte [ebp + wCurEnemyLevel], 5      ; --- L5 ---
    xor bh, bh                              ; b=0: ignore stat exp
    mov esi, 0xD1F0                         ; stat-exp base ptr (= monbase + $10)
    mov edx, 0xD200                         ; result dest
    call CalcStats
    mov byte [ebp + wCurEnemyLevel], 100    ; --- L100 ---
    xor bh, bh
    mov esi, 0xD1F0
    mov edx, 0xD210
    call CalcStats
    jmp DebugDumpMemory                     ; writes DUMP.BIN, exits
%endif

%ifdef DEBUG_AUDIO
; ---------------------------------------------------------------------------
; RunAudioTest — the Phase A milestone demo, driven through the real gateway
; (PlayMusic/PlaySound → AudioN_PlaySound → per-tick Audio1_UpdateMusic →
; opl_pass). Sequence: ~5 s of Pallet Town BGM, the A-button menu blip
; (ducks the music, exactly as on the GB), then a Pokémon cry (3-channel
; SFX with frequency/tempo modifiers), ~4 s more music, then dump the audio
; RAM + virtual APU + shim state to DUMP.BIN and exit. Audible when run
; under dos_port/run (DOSBox-X OPL emulation); byte-verifiable headless.
; Never returns. In: EBP = GB memory base.
;
; The auditioned song defaults to Game Corner; override from the make line
; with TRACK=<MUSIC_* name> (any constant in assets/audio_constants.inc) —
; the bank is resolved via the generated <name>_BANK constant, no asm edit.
; ---------------------------------------------------------------------------
%ifndef DEBUG_AUDIO_TRACK
%define DEBUG_AUDIO_TRACK MUSIC_GAME_CORNER
%endif
%define DEBUG_AUDIO_TRACK_BANK DEBUG_AUDIO_TRACK %+ _BANK
RunAudioTest:
    mov bl, DEBUG_AUDIO_TRACK_BANK          ; c = BANK(song)
    mov al, DEBUG_AUDIO_TRACK
    call PlayMusic
    ; /LOOP (audition): play the music only, forever — no SFX, no dump/exit,
    ; so the whole track (and its loop) can be heard clean. DelayFrame still
    ; services the quit key, so the user can exit normally.
    cmp byte [g_cfg_musicloop], 0
    je .withSfx
.musicOnly:
    call DelayFrame                         ; ticks the engine + enh layer
    jmp .musicOnly
.withSfx:
    mov edi, 300                            ; ~5 s of BGM
    call .ticks
    mov al, SFX_PRESS_AB                    ; menu blip over the music
    call PlaySound
    mov edi, 60
    call .ticks
    xor al, al                              ; cry modifiers: neutral pitch/length
    mov [ebp + wFrequencyModifier], al
    mov [ebp + wTempoModifier], al
    mov al, SFX_CRY_00                      ; Nidoran M base cry
    call PlaySound
    mov edi, 240
    call .ticks
    xor dl, dl                              ; PikachuCry1 — Phase C digitized PCM
    call PlayPikachuSoundClip               ; blocks ~0.8 s (SB DSP or speaker PWM)
    mov edi, 60                             ; a beat of music after the clip
    call .ticks
    call opl_dbg_snapshot                   ; shim state -> $D1E0 scratch
    call midi_dbg_snapshot                  ; MIDI driver state -> $D227+
    call pika_dbg_snapshot                  ; PCM player state -> $D240+
    call hal_dbg_snapshot                   ; active shim device -> $D246
    call tandy_dbg_snapshot                 ; SN76489 shim state -> $D248+
    call spk_dbg_snapshot                   ; speaker shim state -> $D250+
    call enh_dbg_snapshot                   ; OPL enh player state -> $D258+
    jmp DebugDumpMemory                     ; writes DUMP.BIN, exits
.ticks:
    push edi
    call DelayFrame                         ; runs audio_tick each frame
    pop edi
    dec edi
    jnz .ticks
    ret
%endif

%ifdef DEBUG_PARTY
; ---------------------------------------------------------------------------
; RunPartySeedTest — zero the party + bag counts, run the full debug new-game
; seed (PrepareNewGameDebug: AddPartyMon ×4, AddItemToInventory ×N, Pokédex,
; money), then dump party + bag WRAM to DUMP.BIN. Validates that _AddPartyMon /
; AddItemToInventory_ run correctly inside the real binary (not just the native
; harnesses). Never returns. In: EBP = GB memory base.
; ---------------------------------------------------------------------------
RunPartySeedTest:
    ; Start from an empty party + bag (WRAM is not guaranteed zeroed pre-Init).
    mov byte [ebp + 0xD162], 0      ; wPartyCount = 0
    mov byte [ebp + 0xD163], 0xFF   ; wPartySpecies sentinel
    mov byte [ebp + 0xD31C], 0      ; wNumBagItems = 0
    mov byte [ebp + 0xD31D], 0xFF   ; wBagItems sentinel
    call PrepareNewGameDebug
    jmp DebugDumpMemory             ; writes DUMP.BIN, exits
%endif

%ifdef DEBUG_BAGMENU
; ---------------------------------------------------------------------------
; RunBagMenuTest — seed the party + bag, load the font, open the bag (ITEM)
; screen over the (already set-up) overworld via the faithful StartMenu_Item →
; DisplayListMenuID path (menus S4). The DEBUG_BAGMENU hook inside
; DisplayListMenuIDLoop (home/list_menu.asm) renders one frame with the staged
; list + cursor and dumps FRAME.BIN. Never returns. In: EBP = GB memory base.
; Call from EnterMap (after the overworld is loaded) so Pallet Town backs the box.
; ---------------------------------------------------------------------------
RunBagMenuTest:
    mov byte [ebp + 0xD162], 0      ; wPartyCount = 0
    mov byte [ebp + 0xD163], 0xFF   ; wPartySpecies sentinel
    mov byte [ebp + 0xD31C], 0      ; wNumBagItems = 0
    mov byte [ebp + 0xD31D], 0xFF   ; wBagItems sentinel
    call PrepareNewGameDebug        ; seed party + bag
%ifdef DEBUG_BAGMENU_EMPTY
    ; Empty-inventory variant (the user's live worst-case symptom): re-zero the
    ; bag after the seed so the list is just CANCEL. make DEBUG_BAGMENU=1
    ; DEBUG_BAGMENU_EMPTY=1
    mov byte [ebp + 0xD31C], 0      ; wNumBagItems = 0
    mov byte [ebp + 0xD31D], 0xFF   ; wBagItems sentinel
%endif
    ; Swap the font into vFont so the list glyphs render (caller contract).
    or byte [ebp + W_FONT_LOADED], (1 << BIT_FONT_LOADED)
    call LoadFontTilePatterns
    mov byte [ebp + wLinkState], 0  ; not in the Cable Club
    mov byte [ebp + wBagSavedMenuItem], 0
    ; Mirror the live START-menu entry path: the canvas stride (40) is what is
    ; live when StartMenu_Item runs from the real START menu. The boot default
    ; of 20 masked the border-before-stride bug in this harness — this seed
    ; makes the harness the permanent regression repro for it.
    mov dword [text_row_stride], 40
    call StartMenu_Item             ; list_menu's DEBUG hook: 1 frame + dump + exit
.hang:
    jmp .hang                       ; unreachable (the list-menu hook dumps + exits)
%endif

%ifdef DEBUG_PARTYMENU
; ---------------------------------------------------------------------------
; RunPartyMenuTest — seed the party, load the font, open the POKéMON screen over
; the overworld. DisplayPartyMenu's DEBUG_PARTYMENU hook renders one frame and
; dumps FRAME.BIN. Never returns. In: EBP = GB memory base.
; ---------------------------------------------------------------------------
RunPartyMenuTest:
    mov byte [ebp + 0xD162], 0      ; wPartyCount = 0
    mov byte [ebp + 0xD163], 0xFF   ; wPartySpecies sentinel
    mov byte [ebp + 0xD31C], 0      ; wNumBagItems = 0
    mov byte [ebp + 0xD31D], 0xFF   ; wBagItems sentinel
    call PrepareNewGameDebug
    or byte [ebp + W_FONT_LOADED], (1 << BIT_FONT_LOADED)
    call LoadFontTilePatterns
    call StartMenu_Pokemon          ; production entry: the S5 dispatcher runs
                                    ; DisplayPartyMenu, whose hook dumps + exits
.hang:
    jmp .hang
%endif

%ifdef DEBUG_ITEMTM
; ---------------------------------------------------------------------------
; RunTMHMTest — items-plan Stage 7 gate. Seeds the party + bag, drops the TM/HM
; under test into bag slot 0, and drives the real UseItem dispatcher at it. The
; bag UI is bypassed the same way DEBUG_ITEMBALL bypasses the battle ITEM menu:
; wCurItem = the machine, wWhichPokemon = its BAG SLOT (RemoveUsedItem removes by
; index). AUTOKEY_APRESS answers the yes/no box, the party menu and the messages.
; Overrides: ITEMTM_ID (the item id), ITEMTM_MON (the party slot to teach).
; Never returns — DebugDumpMemory writes DUMP.BIN and exits.
; In: EBP = GB memory base.
; ---------------------------------------------------------------------------
%ifndef ITEMTM_ID
%define ITEMTM_ID 0xCE                  ; TM06 TOXIC — SNORLAX (party slot 0) learns it
%endif
%ifndef ITEMTM_MON
%define ITEMTM_MON 0
%endif
RunTMHMTest:
    mov byte [ebp + wPartyCount], 0
    mov byte [ebp + wPartySpecies], 0xFF
    mov byte [ebp + wNumBagItems], 0
    mov byte [ebp + wBagItems], 0xFF
    call PrepareNewGameDebug
    or byte [ebp + W_FONT_LOADED], (1 << BIT_FONT_LOADED)
    call LoadFontTilePatterns
    call LoadTextBoxTilePatterns
    ; Bag slot 0 becomes the machine under test (qty 1), so RemoveUsedItem's
    ; consume-vs-keep decision is visible in wNumBagItems / the first pair.
    mov byte [ebp + wBagItems + 0], ITEMTM_ID
    mov byte [ebp + wBagItems + 1], 1
    mov byte [ebp + wWhichPokemon], 0       ; the BAG slot, not the party slot
    mov byte [ebp + wCurItem], ITEMTM_ID
    ; DEBUG_SEED_PARTY gives the target mon four moves, and for slot 0 (SNORLAX)
    ; all four are HMs (FLY/CUT/SURF/STRENGTH) — LearnMove then correctly refuses
    ; every one ("HM techniques can't be deleted!") and re-prompts forever, which
    ; an A-only autokey script can never escape. Free the last three slots so this
    ; test exercises ItemUseTMHM's real path: teach into an empty slot.
    mov esi, wPartyMon1 + ITEMTM_MON * PARTYMON_STRUCT_LENGTH + MON_MOVES
    mov byte [ebp + esi + 1], 0
    mov byte [ebp + esi + 2], 0
    mov byte [ebp + esi + 3], 0
%ifdef ITEMTM_BISECT
    call DebugDumpMemory
%endif
    call UseItem
    call DebugDumpMemory                    ; DUMP.BIN (the windows: table below) + exit
%endif

%ifdef DEBUG_ITEMPP
; ---------------------------------------------------------------------------
; RunPPRestoreTest — items-plan Stage 11 PP-family gate. Seeds the party + bag,
; drops the PP item under test into bag slot 0, drains one move's PP so the
; restore has an observable effect, and drives the real UseItem dispatcher at it.
; The bag UI is bypassed exactly as DEBUG_ITEMTM bypasses it: wCurItem = the item,
; wWhichPokemon = its BAG SLOT (RemoveUsedItem removes by index). AUTOKEY_APRESS
; answers the party menu, the move menu (wMoveMenuType = 2) and the messages.
;
; This is the only gate that reaches ItemUsePPRestore at all — `move_selection`
; exercises the REGULAR battle move menu (wMoveMenuType = 0), never the type-2
; item path, so no pre-existing scenario can witness this handler.
;
; Overrides: ITEMPP_ID (item id), ITEMPP_MON (party slot), ITEMPP_DRAIN (the PP
; byte written into the target move slot before the item is used).
; Never returns — DebugDumpMemory writes DUMP.BIN + GBSTATE.BIN and exits.
; In: EBP = GB memory base.
; ---------------------------------------------------------------------------
%ifndef ITEMPP_ID
%define ITEMPP_ID 0x50                  ; ETHER — +10 PP to the chosen move
%endif
%ifndef ITEMPP_MON
%define ITEMPP_MON 0
%endif
%ifndef ITEMPP_DRAIN
%define ITEMPP_DRAIN 1                  ; move slot 0 left with 1 PP, no PP-Up bits
%endif
RunPPRestoreTest:
    mov byte [ebp + wPartyCount], 0
    mov byte [ebp + wPartySpecies], 0xFF
    mov byte [ebp + wNumBagItems], 0
    mov byte [ebp + wBagItems], 0xFF
    call PrepareNewGameDebug
    or byte [ebp + W_FONT_LOADED], (1 << BIT_FONT_LOADED)
    call LoadFontTilePatterns
    call LoadTextBoxTilePatterns
    ; Bag slot 0 becomes the PP item under test (qty 1), so RemoveUsedItem's
    ; consume decision is visible in wNumBagItems / the first pair.
    mov byte [ebp + wBagItems + 0], ITEMPP_ID
    mov byte [ebp + wBagItems + 1], 1
    mov byte [ebp + wWhichPokemon], 0       ; the BAG slot, not the party slot
    mov byte [ebp + wCurItem], ITEMPP_ID
    ; Drain move slot 0's PP. Without this the mon is already at full PP and
    ; .restorePP returns "no effect" — a real branch, but not the one under test.
    ; The PP-Up bits are deliberately left clear so ETHER's +10 is unambiguous and
    ; the Max-Ether BUG{} path is not entangled with this gate.
    mov byte [ebp + wPartyMon1 + ITEMPP_MON * PARTYMON_STRUCT_LENGTH + MON_PP], ITEMPP_DRAIN
    call UseItem
    call DebugDumpMemory                    ; DUMP.BIN + GBSTATE.BIN, then exit
%endif

%ifdef DEBUG_SURF
; ---------------------------------------------------------------------------
; RunSurfTestSeed — items-plan Stage 11 Surfboard gate. Unlike every other
; RunXxxTest in this file this one SEEDS AND RETURNS: EnterMap falls straight
; through into the real OverworldLoop afterwards, and AUTOKEY_SURF's scripted
; joypad drives the whole flow from there with LIVE collision. That is deliberate
; — the acceptance this gate owes is "both directions through the real movement
; loop", which a synthetic `call UseItem` cannot give.
;
; What it seeds: the debug party/bag/dex (so the START menu has the same shape the
; other bag scenarios navigate), then bag slot 0 = SURFBOARD qty 1.
; The spawn tile is seeded earlier, in EnterMap — see the DEBUG_SURF block in
; src/home/overworld.asm for the measured Pallet Town tile map.
;
; NOTE: nothing here seeds wTileInFrontOfPlayer. It must not: ItemUseSurfboard
; reads that byte STALE (it never recomputes it), so the scripted joypad's first
; press is a DOWN bump into the water, whose collision check is what populates it.
; Seeding it would hide exactly the coupling this scenario exists to cover.
; In: EBP = GB memory base.  Returns.
; ---------------------------------------------------------------------------
%ifndef SURF_ITEM_ID
%define SURF_ITEM_ID 0x07               ; SURFBOARD
%endif
RunSurfTestSeed:
    mov byte [ebp + wPartyCount], 0
    mov byte [ebp + wPartySpecies], 0xFF
    mov byte [ebp + wNumBagItems], 0
    mov byte [ebp + wBagItems], 0xFF
    call PrepareNewGameDebug
    mov byte [ebp + wBagItems + 0], SURF_ITEM_ID
    mov byte [ebp + wBagItems + 1], 1
    ret
%endif

%ifdef DEBUG_LEDGE
; ---------------------------------------------------------------------------
; RunLedgeTestSeed — ledge-hop gate. Like RunSurfTestSeed, this SEEDS AND
; RETURNS: EnterMap falls through into the real OverworldLoop and AUTOKEY_LEDGE
; drives the hop with live collision. Seeds the debug party (standard-region
; parity with the golden's seed.debug_new_game) and an empty bag — the ledge
; flow uses no items. Spawn coords are seeded earlier, in EnterMap (see the
; DEBUG_LEDGE block in src/home/overworld.asm for the measured Route 1 tiles).
; In: EBP = GB memory base.  Returns.
; ---------------------------------------------------------------------------
RunLedgeTestSeed:
    mov byte [ebp + wPartyCount], 0
    mov byte [ebp + wPartySpecies], 0xFF
    mov byte [ebp + wNumBagItems], 0
    mov byte [ebp + wBagItems], 0xFF
    call PrepareNewGameDebug
    ret
%endif

%ifdef DEBUG_FISH
; ---------------------------------------------------------------------------
; RunFishTestSeed — fishing-rod gate (items-plan Stage 11). Like
; RunSurfTestSeed, SEEDS AND RETURNS: EnterMap falls through into the real
; OverworldLoop and AUTOKEY_FISH drives both rod uses with live collision.
; Seeds the debug party + bag, then bag slot 0 = OLD ROD qty 1.
; Deliberately does NOT touch wTileInFrontOfPlayer (see the DEBUG_FISH block
; in src/home/overworld.asm — its boot value 0 IS the failure branch's input).
; In: EBP = GB memory base.  Returns.
; ---------------------------------------------------------------------------
RunFishTestSeed:
    mov byte [ebp + wPartyCount], 0
    mov byte [ebp + wPartySpecies], 0xFF
    mov byte [ebp + wNumBagItems], 0
    mov byte [ebp + wBagItems], 0xFF
    call PrepareNewGameDebug
    mov byte [ebp + wBagItems + 0], OLD_ROD
    mov byte [ebp + wBagItems + 1], 1
    ret
%endif

%ifdef DEBUG_TRAINER_ROUTE
; ---------------------------------------------------------------------------
; RunTrainerRouteTestSeed — continuous trainer-route gate (battle plan Stage 1b).
;
; Like RunLedgeTestSeed, this SEEDS AND RETURNS: EnterMap falls through into the
; real OverworldLoop and AUTOKEY_TRAINER_ROUTE answers the menus. Nothing here
; touches the battle — that is the whole point of this scenario, and the reason
; it is the one that can carry the Stage 1b tick.
;
; WHAT MAKES IT DIFFERENT FROM 44/45/46. Those three call StartTrainerBattle and
; InitBattle directly from RunBattleTest and never run OverworldLoop at all, so
; the live sight -> presentation -> turn-loop -> return choreography stayed
; unproven no matter how many of them passed. Here the loop does all of it:
; RunMapScript -> Route 3's TrainerMapScript -> CheckFightingMapTrainers engages
; -> DisplayEnemyTrainerTextAndStartBattle -> StartTrainerBattle seeds
; wCurOpponent -> the loop's own battle-entry poll -> NewBattle/InitBattle ->
; ... -> .battleOccurred -> the next RunMapScript dispatches EndTrainerBattle at
; script index 2.
;
; Seeds the debug party (standard-region parity with the golden's
; seed.debug_new_game) and an empty bag — this flow uses no items, and a bag item
; would only add a way for the two sides to diverge.  Spawn coords are seeded
; earlier, in EnterMap (see the DEBUG_TRAINER_ROUTE block in
; src/home/overworld.asm for why it reuses the sight scenarios' tile).
;
; DETERMINISM NOTE: the enemy HP is deliberately NOT collapsed the way 45/46
; collapse it. A continuous run has no harness to reach in and do that, and
; pinning damage would require RNG lockstep between mGBA and the port through
; live menu timing. The compared surface is choreography plus the two zero-RNG
; reward bytes (party EXP, player money) — see the scenario's golden_diff entry.
;
; In: EBP = GB memory base.  Returns.
; ---------------------------------------------------------------------------
RunTrainerRouteTestSeed:
    ; *** SEED ONCE. *** EnterMap re-runs this hook on EVERY map re-entry, and the
    ; post-battle path is one: pret's .battleOccurred tail ends `jp EnterMap`, and
    ; only AFTER that re-entry does RunMapScript dispatch script index 2 ->
    ; EndTrainerBattle to set the persistent beaten bit. An unguarded re-seed here
    ; clears $D7C2 bit 2 and zeroes both script bytes at exactly that moment, so
    ; EndTrainerBattle never runs, the trainer re-engages, and the scenario reads
    ; as "the beaten flag never sticks" — the maintainer-observed infinite battle
    ; loop (regression-battle-trainer-post-battle-and-hud symptom 1) reproduced by
    ; the HARNESS, not the game. Same class as the AUTOKEY phase-1 re-seed trap
    ; recorded on the cadence table.
    cmp byte [trainer_route_seeded], 0
    jne .alreadySeeded
    mov byte [trainer_route_seeded], 1
    mov byte [ebp + wPartyCount], 0
    mov byte [ebp + wPartySpecies], 0xFF
    mov byte [ebp + wNumBagItems], 0
    mov byte [ebp + wBagItems], 0xFF
    call PrepareNewGameDebug
    ; Arm Route 3's first sight trainer the way a fresh arrival would: persistent
    ; beaten bit clear, map script at its DEFAULT handler. The trainer itself comes
    ; from the generated map data, not from here — that is what makes this an
    ; end-to-end check of assets/trainer_headers.inc rather than of a seeded state.
    and byte [ebp + 0xD7C2], ~(1 << 2) & 0xff   ; Route 3 trainer 0 beaten flag
    mov byte [ebp + 0xD5F7], 0                  ; wRoute3CurScript = DEFAULT (0)
    mov byte [ebp + wCurMapScript], 0
.alreadySeeded:
    ret

section .bss
trainer_route_seeded: resb 1                    ; 0 = seed on first EnterMap only
section .text
%endif

%ifdef DEBUG_TEXTBOXID
; ---------------------------------------------------------------------------
; RunTextBoxIDTest — menus S2 FRAME.BIN gate (docs/current_plan_menus.md).
; Seeds the debug party (+ a field move so FIELD_MOVE_MON_MENU has content),
; switches to the flat 40×25 canvas render mode (same sequence as InitBattle),
; blanks the canvas, draws text box DEBUG_TEXTBOXID via the real
; DisplayTextBoxID home wrapper, renders 3 frames, dumps FRAME.BIN, exits.
; Never returns. In: EBP = GB base.  make DEBUG_TEXTBOXID=<id>
; NOTE: interactive ids (0x14 TWO_OPTION_MENU, 0x15 BUY_SELL_QUIT_MENU) would
; block in HandleMenuInput — verify 0x15's box via template 0x0E instead.
; ---------------------------------------------------------------------------
RunTextBoxIDTest:
    mov byte [ebp + 0xD162], 0      ; wPartyCount = 0
    mov byte [ebp + 0xD163], 0xFF   ; wPartySpecies sentinel
    mov byte [ebp + 0xD31C], 0      ; wNumBagItems = 0
    mov byte [ebp + 0xD31D], 0xFF   ; wBagItems sentinel
    call PrepareNewGameDebug        ; party + bag + money (MONEY_BOX reads it)
    ; give party mon 0 a field move and select it, so FIELD_MOVE_MON_MENU (0x04)
    ; lists a real field move above STATS/SWITCH/CANCEL; inert for every other id
    mov byte [ebp + wPartyMon1 + MON_MOVES + 1], 0x0F   ; move slot 2 = CUT
    mov byte [ebp + wWhichPokemon], 0
    ; font glyphs + box-border tiles into vFont
    or byte [ebp + W_FONT_LOADED], (1 << BIT_FONT_LOADED)
    call LoadFontTilePatterns
    ; flat-canvas render mode (mirrors InitBattle): render_bg decodes W_TILEMAP
    ; directly at screen (0,0), no window overlay, no per-frame OAM rebuild
    call ClearSprites
    mov byte [ebp + W_UPDATE_SPRITES_ENABLED], 0
    mov word [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR], 0
    mov byte [ebp + H_SCX], 0       ; zero the shadows too — commit_shadow_regs
    mov byte [ebp + H_SCY], 0       ; copies them over IO_SCX/SCY each DelayFrame
    mov byte [ebp + IO_SCX], 0
    mov byte [ebp + IO_SCY], 0
    call hide_window
    ; blank the whole canvas to the space tile so only the box under test shows
    lea edi, [ebp + W_TILEMAP]
    mov al, 0x7F                    ; TILE_SPC
    mov ecx, SCREEN_TILES_W * SCREEN_TILES_H
    rep stosb
    mov byte [ebp + wTextBoxID], DEBUG_TEXTBOXID
    call DisplayTextBoxID           ; home wrapper → DisplayTextBoxID_
    call DelayFrame
    call DelayFrame
    call DelayFrame
    call DumpBackbuffer             ; writes FRAME.BIN + exits (never returns)
.hang:
    jmp .hang
%endif

%ifdef DEBUG_TEXT
; ---------------------------------------------------------------------------
; RunTextTest — the TEXT-ENGINE ORACLE (docs/current_plan_text_engine.md, Stage 0).
;
; Runs ONE probe stream (assets/text_oracle.inc, generated by tools/generators/gen_text_oracle.py)
; through the real PrintText, in the real overworld dialog window, then dumps
; FRAME.BIN and exits. One case per TX_* command:
;   1 plain(+<LINE>)  2 <PARA>  3 TX_RAM  4 TX_NUM  5 TX_BCD  6 TX_FAR  7 TX_DOTS
;
; Why this exists: NO golden scenario and no other harness renders a text stream
; directly — every one of them reaches text incidentally, through a whole game
; path, and none covers TX_FAR/TX_NUM/TX_BCD/<PARA> at all. The previous attempt
; at the flat-pointer refactor assembled, linted, and passed `make fidelity` 6/6
; while rendering garbage in a live dialog. `make fidelity` is not an oracle for
; the text engine; this is.
;
; Never returns — DumpBackbuffer writes FRAME.BIN and exits.
; In: EBP = GB memory base.  make DEBUG_TEXT=<1..7>
; ---------------------------------------------------------------------------
RunTextTest:
    ; --- seed what the format commands read ---
    ; TX_RAM ($01) splices an '@'-terminated string from WRAM.
    mov esi, txt_oracle_ramstr           ; flat .data source
    lea edi, [ebp + wStringBuffer]
    mov ecx, 8                           ; "PIKACHU@"
    rep movsb
    ; TX_BCD ($02) reads 3 BCD bytes: 123456.
    mov byte [ebp + wStringBuffer + 16], 0x12
    mov byte [ebp + wStringBuffer + 17], 0x34
    mov byte [ebp + wStringBuffer + 18], 0x56
    ; TX_NUM ($09) reads a 2-byte BIG-ENDIAN value (GB order — high byte first): 4242.
    mov byte [ebp + wStringBuffer + 20], 0x10
    mov byte [ebp + wStringBuffer + 21], 0x92

    ; font glyphs + the message-box border tiles
    or byte [ebp + W_FONT_LOADED], (1 << BIT_FONT_LOADED)
    call LoadFontTilePatterns
    call LoadTextBoxTilePatterns

    ; Run the selected case through the production printer. PrintText draws the
    ; MESSAGE_BOX itself (msgbox_dialog is the default projection), so this is the
    ; same path an NPC dialog takes.
    mov esi, [txt_oracle_cases + (DEBUG_TEXT - 1) * 4]
%if DEBUG_TEXT == 9
    ; Case 9 enters through the OVERWORLD NPC entry instead, so the probe covers the
    ; map_sprites dispatch + ShowTextStream plumbing, not just the engine. It waits
    ; for A itself (npc_dialog_wait_impl); AUTOKEY_APRESS supplies the presses.
    call ShowTextStream
%else
    call PrintText
%endif

    call DelayFrame                      ; flush the last typed glyph to the back buffer
    call DelayFrame
    call DelayFrame
    call DumpBackbuffer                  ; FRAME.BIN + exit (never returns)
.hang:
    jmp .hang
%endif

%ifdef DEBUG_YESNO
; ---------------------------------------------------------------------------
; RunYesNoTest — menu-fidelity row 5 FRAME.BIN gate.
; Drives the two-option (YES/NO) framework — home/yes_no.asm — which no golden
; scenario and no other harness reaches. Renders the box and parks in
; HandleMenuInput; build with DEBUG_AUTOKEY=1 AUTOKEY_QUIET=1 (the Makefile does
; it for you) so AutoKeyDrive photographs the box at AUTOKEY_DUMP_FRAME and exits
; without any keypress perturbing the cursor.
;   make DEBUG_YESNO=<n>
;     1 = YesNoChoice          (YES_NO_MENU: box GB(14,7), 4x3 interior, no blank)
;     2 = YesNoChoicePokeCenter (HEAL_CANCEL_MENU: GB(11,6), 7x4, BLANK first line —
;         the only descriptor that exercises the blank-line row offset)
; What it proves: the options must sit TWO rows apart (pret's <NEXT> advances
; 2*SCREEN_WIDTH) with the ▶ cursor level with the FIRST option.
; Never returns. In: EBP = GB base.
; ---------------------------------------------------------------------------
RunYesNoTest:
    or byte [ebp + W_FONT_LOADED], (1 << BIT_FONT_LOADED)
    call LoadFontTilePatterns
    call LoadTextBoxTilePatterns
%if DEBUG_YESNO = 2
    call YesNoChoicePokeCenter
%else
    call YesNoChoice
%endif
.hang:
    jmp .hang
%endif

%ifdef DEBUG_LISTMENU
; ---------------------------------------------------------------------------
; RunListMenuTest — menus S3 FRAME.BIN gate (docs/current_plan_menus.md).
; Seeds the debug party + bag, then drives the GENERIC list-menu driver
; (home/list_menu.asm:DisplayListMenuID) with NO input: wBattleType != 0 takes
; the Old-Man-battle branch, which force-selects entry 0 and returns without
; touching HandleMenuInput. Renders 3 frames, dumps FRAME.BIN, exits.
;   make DEBUG_LISTMENU=<mode>
;     0 = PCPOKEMONLISTMENU  (party list: nick-base select + LoadMonData +
;         PrintLevel — the S3-completed paths)
;     2 = PRICEDITEMLISTMENU (price column via GetItemPrice/PrintBCDNumber.
;         NB: priced lists are 1-byte mart format; feeding it the 2-byte bag
;         list means qty bytes render as items — deterministic render gate
;         only, not a data-correctness gate)
;     3 = ITEMLISTMENU       (bag list with ×NN quantities + IsKeyItem skip)
;   (1 = MOVESLISTMENU needs a seeded wMoves list; unsupported here.)
; Never returns. In: EBP = GB base.
; ---------------------------------------------------------------------------
RunListMenuTest:
    mov byte [ebp + 0xD162], 0      ; wPartyCount = 0
    mov byte [ebp + 0xD163], 0xFF   ; wPartySpecies sentinel
    mov byte [ebp + 0xD31C], 0      ; wNumBagItems = 0
    mov byte [ebp + 0xD31D], 0xFF   ; wBagItems sentinel
    call PrepareNewGameDebug        ; party + bag + money
    or byte [ebp + W_FONT_LOADED], (1 << BIT_FONT_LOADED)
    call LoadFontTilePatterns
    ; input-free drive: Old Man battle type → auto-select entry 0
    mov byte [ebp + wBattleType], 1
    mov byte [ebp + wListMenuID], DEBUG_LISTMENU
    mov byte [ebp + wPrintItemPrices], 0
%if DEBUG_LISTMENU = 0
    mov word [ebp + wListPointer], wPartyCount & 0xFFFF
%else
    mov word [ebp + wListPointer], wNumBagItems & 0xFFFF
%endif
%if DEBUG_LISTMENU = 2
    mov byte [ebp + wPrintItemPrices], 1
    mov byte [ebp + hHalveItemPrices], 0
%endif
    xor al, al
    mov [ebp + wListScrollOffset], al
    mov [ebp + wCurrentMenuItem], al
    call DisplayListMenuID          ; box + entries + auto-select entry 0
    mov byte [ebp + wBattleType], 0
%ifdef DEBUG_LISTMENU_QTY
    ; Stage the ×NN quantity selector on top of the list — the ONLY headless route
    ; into DisplayChooseQuantityMenu (the live priced caller, the Pokémart, still
    ; dead-ends in a home_stubs.asm ret-stub, so its priced layout is otherwise
    ; unobservable). The routine draws its box, the "×01" label and — for
    ; PRICEDITEMLISTMENU — the price row, THEN parks in .waitForKeyPressLoop.
    ; We never leave that loop: build with DEBUG_AUTOKEY=1 AUTOKEY_QUIET=1, and
    ; AutoKeyDrive (which runs per frame from the DelayFrame inside
    ; JoypadLowSensitivity) writes FRAME.BIN at AUTOKEY_DUMP_FRAME and exits.
    ; A press-injecting autokey script would drive the quantity and change the
    ; render, which is why AUTOKEY_QUIET exists.
    mov byte [ebp + wMaxItemQuantity], 99
    call DisplayChooseQuantityMenu      ; parks in its key-wait loop; never returns
%endif
    call DelayFrame
    call DelayFrame
    call DelayFrame
    call DumpBackbuffer             ; writes FRAME.BIN + exits (never returns)
.hang:
    jmp .hang
%endif

%ifdef DEBUG_BATTLE
; ---------------------------------------------------------------------------
; RunBattleTest — seed party + a wild enemy, load font/textbox tiles, enter
; battle (InitBattle), render one frame, and dump FRAME.BIN. Never returns.
; Stage-0.5 gate: proves the centered battle render mode. In: EBP = GB base.
; ---------------------------------------------------------------------------
RunBattleTest:
%ifdef DEBUG_TRAINER_INIT
    mov byte [ebp + wPartyCount], 0
    mov byte [ebp + wPartySpecies], 0xFF
    mov byte [ebp + wNumBagItems], 0
    mov byte [ebp + wBagItems], 0xFF
    call PrepareNewGameDebug
    ; Route 3's first sight trainer: BUG CATCHER, roster 4.
    mov byte [ebp + wEngagedTrainerClass], OPP_ID_OFFSET + 2
    mov byte [ebp + wEngagedTrainerSet], 4
    call StartTrainerBattle              ; seeds wCurOpponent, then returns
    ; Stage 1b: StartTrainerBattle no longer runs the battle — OverworldLoop's
    ; wCurOpponent poll does (src/home/overworld.asm). This harness never runs
    ; that loop, so it stands in for the poll with the same call the loop makes
    ; through NewBattle. _InitBattleCommon's DEBUG_TRAINER_INIT stop still ends
    ; it right after the first active enemy mon is selected.
    call InitBattle

    lea edi, [ebp + wBuffer]
    mov al, [ebp + wCurOpponent]
    stosb
    mov al, [ebp + wTrainerClass]
    stosb
    mov al, [ebp + wTrainerNo]
    stosb
    mov al, [ebp + wEnemyPartyCount]
    stosb
    lea esi, [ebp + wEnemyPartySpecies]
    mov ecx, PARTY_LENGTH
    rep movsb
    mov esi, wEnemyMons + MON_LEVEL
    mov ecx, PARTY_LENGTH
.trainerLevels:
    mov al, [ebp + esi]
    stosb
    add esi, PARTYMON_STRUCT_LENGTH
    dec ecx
    jnz .trainerLevels
    mov al, [ebp + wEnemyMonPartyPos]
    stosb
    mov al, [ebp + wEnemyMonSpecies]
    stosb
    mov al, [ebp + wEnemyMonLevel]
    stosb
    mov al, [ebp + wAICount]
    stosb
    lea esi, [ebp + wAmountMoneyWon]
    mov ecx, 3
    rep movsb
    lea esi, [ebp + wTrainerBaseMoney]
    mov ecx, 2
    rep movsb
    mov al, [ebp + wIsInBattle]
    stosb
    lea esi, [ebp + wTrainerName]
    mov ecx, 4
    rep movsb
    call DebugDumpMemory
%elifdef DEBUG_TRAINER_RESULT
    ; Stage 1b terminal-state oracle. Both variants enter StartTrainerBattle
    ; through the production guard, load Route 3's real generated trainer party,
    ; and stop after both active battlers are selected. The harness then drives
    ; one deterministic terminal turn through the same execute/faint routines as
    ; the live loop, followed by EndOfBattle and EndTrainerBattle.
    mov byte [ebp + wPartyCount], 0
    mov byte [ebp + wPartySpecies], 0xff
    mov byte [ebp + wNumBagItems], 0
    mov byte [ebp + wBagItems], 0xff
    call PrepareNewGameDebug

    ; Route 3 standard-script state and first trainer header. The generated
    ; header binds flag bit 2 in event byte $D7C2.
    and byte [ebp + 0xD7C2], ~(1 << 2) & 0xff
    mov byte [ebp + 0xD5F7], 1          ; wRoute3CurScript: start-battle handler
    mov byte [ebp + wCurMapScript], 1
    mov byte [ebp + wSpriteIndex], 1
    mov esi, Route3TrainerHeader0
    call StoreTrainerHeaderPointer
    xor eax, eax
    call ReadTrainerHeaderInfo           ; publish wTrainerHeaderFlagBit
    mov byte [ebp + wEngagedTrainerClass], OPP_ID_OFFSET + 2
    mov byte [ebp + wEngagedTrainerSet], 4
    call StartTrainerBattle              ; seeds wCurOpponent, then returns
    ; Stage 1b: stand in for OverworldLoop's wCurOpponent poll (see the
    ; DEBUG_TRAINER_INIT note above). _InitBattleCommon's DEBUG_TRAINER_RESULT
    ; stop returns pre-presentation, once both active battlers are loaded.
    call InitBattle

%ifdef DEBUG_TRAINER_WIN
    ; Collapse the loaded roster to its active first mon and give it 1 HP. The
    ; debug party's L80 SNORLAX uses STRENGTH, whose minimum roll overkills it.
    mov byte [ebp + wEnemyPartyCount], 1
    mov byte [ebp + wEnemyMonPartyPos], 0
    mov word [ebp + wEnemyMonHP], 0x0100
    mov word [ebp + wEnemyMon1HP], 0x0100
    mov byte [ebp + wPlayerMoveListIndex], 3
    mov byte [ebp + wPlayerSelectedMove], STRENGTH
    mov byte [ebp + wPartyGainExpFlags], 1
    mov byte [ebp + wPartyFoughtCurrentEnemyFlags], 1
    mov byte [ebp + wBoostExpByExpAll], 0
    mov byte [ebp + wActionResultOrTookBattleTurn], 0
    call ExecutePlayerMove
    mov al, [ebp + wEnemyMonHP]
    or al, [ebp + wEnemyMonHP + 1]
    jnz .trainerResultFail
    mov word [ebp + wEnemyMon1HP], 0     ; terminal party state the faint path publishes
    call GainExperience                  ; deterministic EXP/stat-EXP result, presentation debug-skipped
    call TrainerBattleVictory            ; prize/result leaf, text wait debug-skipped
    mov byte [stage + 0], 0              ; outcome: win
%elifdef DEBUG_TRAINER_LOSS
    ; Exactly one party mon remains at 1 HP. Pin every enemy move to GUST, so
    ; any successful damage roll blacks out the party before it can act.
    mov byte [ebp + wPartyCount], 1
    mov word [ebp + wPartyMon1HP], 0x0100
    mov word [ebp + wBattleMonHP], 0x0100
    mov word [ebp + wEnemyMonHP], 0x1e00
    mov word [ebp + wEnemyMon1HP], 0x1e00
    mov byte [ebp + wEnemyMonMoves + 0], GUST
    mov byte [ebp + wEnemyMonMoves + 1], GUST
    mov byte [ebp + wEnemyMonMoves + 2], GUST
    mov byte [ebp + wEnemyMonMoves + 3], GUST
    mov byte [ebp + wEnemySelectedMove], GUST
    mov byte [ebp + wEnemyMoveListIndex], 0
    mov byte [ebp + wActionResultOrTookBattleTurn], 0
    call ExecuteEnemyMove
    mov al, [ebp + wBattleMonHP]
    or al, [ebp + wBattleMonHP + 1]
    jnz .trainerResultFail
    mov word [ebp + wPartyMon1HP], 0     ; terminal party state RemoveFaintedPlayerMon publishes
    mov byte [ebp + wBattleResult], 1
    call HandlePlayerBlackOut            ; terminal loss leaf
    mov byte [stage + 0], 1              ; outcome: loss
%else
%error DEBUG_TRAINER_RESULT needs DEBUG_TRAINER_WIN or DEBUG_TRAINER_LOSS
%endif

    mov al, [ebp + wBattleResult]
    mov [stage + 1], al                  ; preserve result before blackout cleanup
    call EndOfBattle
    call FinalizeTrainerBattleOutcome    ; loss publishes wIsInBattle=$ff
    call EndTrainerBattle                ; win sets flag, loss skips it; both reset script
    mov al, [ebp + wCurMapScript]
    mov [ebp + 0xD5F7], al               ; ExecuteCurMapScriptInTable write-back
%ifdef DEBUG_TRAINER_LOSS
    call ResetStatusAndHalveMoneyOnBlackout
%endif

    lea edi, [ebp + wBuffer]
    mov al, [stage + 0]
    stosb
    mov al, [stage + 1]
    stosb
    mov al, [ebp + wIsInBattle]
    stosb
    mov al, [ebp + wCurMapScript]
    stosb
    mov al, [ebp + 0xD5F7]
    stosb
    mov al, [ebp + 0xD7C2]
    stosb
    mov al, [ebp + wMiscFlags]
    stosb
    lea esi, [ebp + wPlayerMoney]
    mov ecx, 3
    rep movsb
    mov al, [ebp + wEnemyPartyCount]
    stosb
    mov al, [ebp + wEnemyMonPartyPos]
    stosb
    mov al, [ebp + wEnemyMonHP]
    stosb
    mov al, [ebp + wEnemyMonHP + 1]
    stosb
    mov al, [ebp + wEnemyMon1HP]
    stosb
    mov al, [ebp + wEnemyMon1HP + 1]
    stosb
    mov al, [ebp + wPartyCount]
    stosb
    mov al, [ebp + wPartyMon1HP]
    stosb
    mov al, [ebp + wPartyMon1HP + 1]
    stosb
    lea esi, [ebp + wPartyMon1 + MON_EXP]
    mov ecx, 3
    rep movsb
    mov al, [ebp + wBattleType]
    stosb
    mov al, [ebp + wCurOpponent]
    stosb
    call DebugDumpMemory

.trainerResultFail:
    mov byte [ebp + W_TILEMAP], 0xee
    call DelayFrame
    call DumpBackbuffer
    jmp .trainerResultFail
%elifdef DEBUG_BATTLE_GOLDEN
    ; ------------------------------------------------------------------
    ; Fidelity-plan Stage 2 golden gate — the REAL loaders + the battle
    ; convergence spec, twin of the mGBA scenarios (battle_intro /
    ; battle_menu / move_selection): PrepareNewGameDebug party/bag; wild
    ; PIDGEY L13 through the real InitBattle → LoadEnemyMonData; then
    ; overwrite ONLY the RNG-derived parts (DVs → $98 $76, stats
    ; recomputed by the real CalcStats, HP = MaxHP, unmodified snapshot
    ; refreshed) — exactly what the golden side's seed.enemy does after
    ; its real Route 1 grass encounter. Loader-derived parts (species,
    ; types, catch rate, moves, PP) are NOT written here, so a loader
    ; regression fails the golden diff instead of being papered over.
    ; ------------------------------------------------------------------
    mov byte [ebp + 0xD162], 0      ; wPartyCount = 0
    mov byte [ebp + 0xD163], 0xFF   ; wPartySpecies sentinel
    mov byte [ebp + 0xD31C], 0      ; wNumBagItems = 0
    mov byte [ebp + 0xD31D], 0xFF   ; wBagItems sentinel
    call PrepareNewGameDebug        ; the standard debug new-game seed
    ; TryDoWildEncounter's outputs, per the spec (the golden walks Route 1
    ; grass with wGrassMons forced to 10 x (L13, PIDGEY)):
    mov byte [ebp + wEnemyMonSpecies2], 0x24    ; PIDGEY (internal index)
    mov byte [ebp + wCurEnemyLevel], 13
    or byte [ebp + W_FONT_LOADED], (1 << BIT_FONT_LOADED)
    call LoadFontTilePatterns
    call LoadTextBoxTilePatterns
    call InitBattleCanvas           ; canvas + InitBattleVariables
    mov byte [ebp + wIsInBattle], 1 ; gate models a wild battle; live init owns this normally
    call LoadEnemyMonData           ; REAL loader — rolls DVs via BattleRandom
    ; --- spec-DV overwrite + stat recompute (seed.enemy's twin) ---
    mov byte [ebp + wEnemyMonDVs], 0x98
    mov byte [ebp + wEnemyMonDVs + 1], 0x76
    ; Identical registers to the loader's own CalcStats call: the level is
    ; still in wCurEnemyLevel (CalcStat's level source), wMonHeader still
    ; holds PIDGEY, and CalcStat reads the DVs at ESI + $0B = wEnemyMonDVs —
    ; so this recomputes the 5 stats from the spec DVs. Golden-measured
    ; result: MaxHP 36, Atk 19, Def 17, Spd 21, Spc 15.
    mov edx, wEnemyMonLevel + 1     ; stat block dest (wEnemyMonMaxHP)
    mov bh, 0                       ; no stat exp
    mov esi, wEnemyMonHP
    call CalcStats
    ; HP = MaxHP (copy the big-endian word verbatim — Gen-1 byte order rule)
    mov al, [ebp + wEnemyMonMaxHP]
    mov [ebp + wEnemyMonHP], al
    mov al, [ebp + wEnemyMonMaxHP + 1]
    mov [ebp + wEnemyMonHP + 1], al
    ; refresh the unmodified level+stats snapshot — the loader took it from
    ; the ROLLED DVs before the overwrite
    mov esi, wEnemyMonLevel
    mov edx, wEnemyMonUnmodifiedLevel
    mov ebx, 1 + NUM_STATS * 2
    call CopyData
    ; --- real intro scene (pret PrintBeginningBattleText order: pics, box,
    ;     pokéballs; NO HUDs — the GB first draws them at the battle menu) ---
    mov al, [ebp + wEnemyMonSpecies2]
    mov [ebp + wCurPartySpecies], al
    mov esi, W_TILEMAP + 12         ; hlcoord 12,0 (stride 40)
    call LoadFrontSpriteByMonIndex  ; real enemy front pic (not the stub)
    call LoadPlayerBackPic
    call SlideBattlePicsIn
    call DrawBattleIntroBox
    call SaveBattleScreen
    call DrawBattlePokeballs
%ifdef DEBUG_BATTLE_INTRO
    ; Dump at the parked "Wild PIDGEY appeared!" prompt. The ▼ poke at GB
    ; (16,18) = canvas (19,28) replicates the text engine's parked prompt
    ; (the port box prints instantly, promptless). wBattleMon is NOT loaded
    ; yet — the GB loads it at send-out, after this screen (golden: zeros).
    mov byte [ebp + W_TILEMAP + (19 * 40 + 28)], 0xEE
    call DelayFrame
    call DumpBackbuffer
.goldenintrohang:
    jmp .goldenintrohang
%else
    ; --- send-out (the golden pressed A on "appeared!"): the pokéballs give
    ; way and the selected alive party mon is loaded by the REAL
    ; LoadBattleMonFromParty; its back pic
    ; replaces Red's. Mirrors _InitBattleCommon's scan outcome + the
    ; pret StartBattle EXP/fought flag sets. ---
    call HideBattlePokeballs
%ifdef DEBUG_BATTLE_DAMAGE
    mov byte [ebp + wWhichPokemon], 3
    mov byte [ebp + wPlayerMonNumber], 3
    mov al, [ebp + wPartySpecies + 3]
    mov cl, 3
%else
    mov byte [ebp + wWhichPokemon], 0
    mov byte [ebp + wPlayerMonNumber], 0
    mov al, [ebp + wPartySpecies]
    mov cl, 0
%endif
    mov [ebp + wCurPartySpecies], al
    mov [ebp + wBattleMonSpecies2], al
    mov bh, FLAG_SET
    mov esi, wPartyGainExpFlags
    call FlagAction
%ifdef DEBUG_BATTLE_DAMAGE
    mov cl, 3
%else
    mov cl, 0
%endif
    mov bh, FLAG_SET
    mov esi, wPartyFoughtCurrentEnemyFlags
    call FlagAction
    call LoadBattleMonFromParty
    call LoadMonBackPic
%ifdef DEBUG_BATTLE_MENU
    ; The REAL battle menu: DisplayBattleMenu draws HUDs + boxes and parks in
    ; HandleMenuInput with the ▶ on FIGHT; AUTOKEY_QUIET photographs it at
    ; AUTOKEY_DUMP_FRAME (the Makefile adds DEBUG_AUTOKEY).
    call DisplayBattleMenu
.goldenmenuhang:
    call DelayFrame
    jmp .goldenmenuhang
%elifdef DEBUG_MOVEMENU
    ; The menu screen first (DisplayBattleMenu's draw half — the golden's move
    ; list draws over the real menu screen), then the FIGHT sub-menu parks in
    ; its own HandleMenuInput loop; AUTOKEY_QUIET photographs it.
    call LoadScreenTilesFromBuffer1
    call DrawHUDsAndHPBars
    call DrawEmptyDialogBox
    call SaveScreenTilesToBuffer1
    call DrawBattleMenuBox
    mov byte [ebp + wMoveMenuType], 0
    mov byte [ebp + wPlayerMoveListIndex], 0
    mov byte [ebp + wMenuItemToSwap], 0
    call MoveSelectionMenu
.goldenmovehang:
    call DelayFrame
    jmp .goldenmovehang
%elifdef DEBUG_ITEMBALL
    ; ball_catch golden gate (fidelity plan Stage 2e): throw a ball at the
    ; convergence-spec enemy loaded above by the REAL loaders. The golden
    ; navigated the real battle menu → ITEM → the bag list; the port's
    ; in-battle ITEM menu (BattleItemMenu) is still a battle-plan stub, so the
    ; selection is preset and UseItem called directly — the same bypass as the
    ; synthetic ITEMBALL gate below, on the golden-proven battle state.
    ; pret refs for the mirrored steps: BagWasSelected redraws the HUDs
    ; (core.asm:2293 — stages wLoadedMon, compared WRAM); UseBagItem
    ; (core.asm:2344) zeroes wPseudoItemID before UseItem and, post-capture,
    ; clears wCapturedMonSpecies + sets wBattleResult=2 (core.asm:2375-2395).
%ifndef ITEMBALL_ID
%define ITEMBALL_ID 0x01                ; MASTER_BALL — always captures (deterministic)
%endif
%ifndef ITEMBALL_SLOT
%define ITEMBALL_SLOT 2                 ; seeded bag: POTION, ANTIDOTE, MASTER_BALL, …
%endif
    call LoadScreenTilesFromBuffer1
    call DrawHUDsAndHPBars
    ; one party slot free → the capture takes the AddPartyMon path (the box
    ; path ends in the interactive naming screen; the golden declines the
    ; nickname prompt with B, converging on the port's species-name default)
    mov byte [ebp + wPartyCount], 5
    mov byte [ebp + wWhichPokemon], ITEMBALL_SLOT   ; bag INDEX (RemoveItemFromInventory)
    mov byte [ebp + wCurItem], ITEMBALL_ID
    mov byte [ebp + wPseudoItemID], 0
    call UseItem
    ; UseBagItem's post-capture tail — the golden's dump trigger polls
    ; wBattleResult == 2 at frame granularity, and by that frame boundary the
    ; GB has already returned up the battle loop into EndOfBattle, whose
    ; .resetVariables zeroed wIsInBattle (measured: the one-field first diff).
    ; Run the REAL EndOfBattle here too — result 2 skips its pay-day/evolution
    ; leg, and nothing after .resetVariables touches compared WRAM.
    mov byte [ebp + wCapturedMonSpecies], 0
    mov byte [ebp + wBattleResult], 2
    call EndOfBattle
    call DebugDumpMemory                ; GBSTATE.BIN (id 20) + DUMP.BIN + exit
%elifdef DEBUG_BATTLE_DAMAGE
    ; Numerical damage oracle. The emulators run the real numerical pipelines
    ; but keep independent RNG streams, so select semantic cases rather than
    ; equal rolls: non-critical Pikachu THUNDERSHOCK (STAB + 2x) and critical
    ; Pidgey SLASH (STAB + neutral). The mGBA twin reaches these through real
    ; non-lethal turns; this gate calls the numerical spine directly so text
    ; and animation waits cannot dominate a headless arithmetic check.
    ; Each 15-byte record staged at wBuffer is: crit, damage, move, power,
    ; move type, attacker species/level/attack/type1/type2, defender species,
    ; a combined stat-high guard, then defense/type1/type2. This fixed matchup
    ; keeps both stats and damage below 256.
    call LoadScreenTilesFromBuffer1
    call DrawHUDsAndHPBars
    mov byte [ebp + wBattleMonMoves], 0x54       ; THUNDERSHOCK
    mov byte [ebp + wBattleMonPP], 30
    mov byte [ebp + wEnemyMonMoves + 0], SLASH
    mov byte [ebp + wEnemyMonMoves + 1], SLASH
    mov byte [ebp + wEnemyMonMoves + 2], SLASH
    mov byte [ebp + wEnemyMonMoves + 3], SLASH

    ; Player half: load the real move record, then run the exact numerical
    ; sequence ExecutePlayerMove uses after hit/critical resolution.
    mov byte [ebp + hWhoseTurn], 0
    mov byte [ebp + wPlayerSelectedMove], 0x54  ; THUNDERSHOCK
    call GetCurrentMove
    mov byte [ebp + wCriticalHitOrOHKO], 0
    call GetDamageVarsForPlayerAttack
    call CalculateDamage
    call AdjustDamageForMoveType
    call RandomizeDamage
    cmp byte [ebp + wDamage], 0
    jne near .damageOracleFail
    cmp byte [ebp + wDamage + 1], 0
    je near .damageOracleFail
    mov al, [ebp + wCriticalHitOrOHKO]
    mov [stage + 0], al
    mov al, [ebp + wDamage + 1]
    mov [stage + 1], al
    mov al, [ebp + wPlayerSelectedMove]
    mov [stage + 2], al
    mov al, [ebp + wPlayerMovePower]
    mov [stage + 3], al
    mov al, [ebp + wPlayerMoveType]
    mov [stage + 4], al
    mov al, [ebp + wBattleMonSpecies]
    mov [stage + 5], al
    mov al, [ebp + wBattleMonLevel]
    mov [stage + 6], al
    mov al, [ebp + wBattleMonSpecial + 1]
    mov [stage + 7], al
    mov al, [ebp + wBattleMonType1]
    mov [stage + 8], al
    mov al, [ebp + wBattleMonType2]
    mov [stage + 9], al
    mov al, [ebp + wEnemyMonSpecies]
    mov [stage + 10], al
    mov al, [ebp + wBattleMonSpecial]
    or al, [ebp + wEnemyMonSpecial]
    mov [stage + 11], al
    mov al, [ebp + wEnemyMonSpecial + 1]
    mov [stage + 12], al
    mov al, [ebp + wEnemyMonType1]
    mov [stage + 13], al
    mov al, [ebp + wEnemyMonType2]
    mov [stage + 14], al

    ; Enemy half: same numerical spine, with the already-resolved crit flag set.
    mov byte [ebp + hWhoseTurn], 1
    mov byte [ebp + wEnemySelectedMove], SLASH
    call GetCurrentMove
    mov byte [ebp + wCriticalHitOrOHKO], 1
    call GetDamageVarsForEnemyAttack
    call CalculateDamage
    call AdjustDamageForMoveType
    call RandomizeDamage
    cmp byte [ebp + wDamage], 0
    jne near .damageOracleFail
    cmp byte [ebp + wDamage + 1], 0
    je near .damageOracleFail
    mov al, [ebp + wCriticalHitOrOHKO]
    mov [stage + 15], al
    mov al, [ebp + wDamage + 1]
    mov [stage + 16], al
    mov al, [ebp + wEnemySelectedMove]
    mov [stage + 17], al
    mov al, [ebp + wEnemyMovePower]
    mov [stage + 18], al
    mov al, [ebp + wEnemyMoveType]
    mov [stage + 19], al
    mov al, [ebp + wEnemyMonSpecies]
    mov [stage + 20], al
    mov al, [ebp + wEnemyMonLevel]
    mov [stage + 21], al
    mov al, [ebp + wEnemyMonAttack + 1]
    mov [stage + 22], al
    mov al, [ebp + wEnemyMonType1]
    mov [stage + 23], al
    mov al, [ebp + wEnemyMonType2]
    mov [stage + 24], al
    mov al, [ebp + wBattleMonSpecies]
    mov [stage + 25], al
    mov al, [ebp + wEnemyMonAttack]
    or al, [ebp + wPartyMon1Defense + 3 * PARTYMON_STRUCT_LENGTH]
    mov [stage + 26], al
    mov al, [ebp + wPartyMon1Defense + 3 * PARTYMON_STRUCT_LENGTH + 1]
    mov [stage + 27], al
    mov al, [ebp + wBattleMonType1]
    mov [stage + 28], al
    mov al, [ebp + wBattleMonType2]
    mov [stage + 29], al

    mov esi, stage
    lea edi, [ebp + wBuffer]
    mov ecx, 30
    rep movsb
    call DebugDumpMemory

.damageOracleFail:
    mov byte [ebp + W_TILEMAP], 0xEE
    call DelayFrame
    call DumpBackbuffer
    jmp .damageOracleFail
%elifdef DEBUG_BATTLE_FAINT
    ; ------------------------------------------------------------------
    ; battle_faint golden gate — the FIRST harness in which a battle turn
    ; actually resolves and a mon faints. Session 8's coverage analysis
    ; measured that 49 of the 62 pret core.asm labels it moved are never
    ; executed by the suite, because every existing battle gate stops at
    ; the menu, the move list, or a Master Ball capture. This gate runs
    ; the real damage pipeline and the real faint/EXP chain, which is
    ; where the bulk of those 49 live.
    ;
    ; RNG-INDEPENDENCE IS THE WHOLE DESIGN. The port and the golden do NOT
    ; share an RNG stream (tools/mgba_harness/lib/seed.lua: the debug
    ; seed's DVs "cannot be reproduced by construction"), so nothing this
    ; scenario compares may depend on a roll. The matchup is chosen to
    ; make that true rather than hoped for:
    ;   * SNORLAX L80 (debug party slot 0) vs the spec PIDGEY L13, 36 HP.
    ;     STRENGTH's minimum roll still exceeds 36 by a wide margin, so
    ;     the KO takes exactly one turn for ANY damage roll and any crit.
    ;   * SNORLAX outspeeds PIDGEY (L80 vs L13), so the enemy never acts:
    ;     the player mon's HP, status and PP are untouched by a roll.
    ;   * Therefore every compared datum -- EXP and stat EXP gained, party
    ;     HP, wBattleResult, the zeroed enemy HP -- is a deterministic
    ;     function of species and level, not of the stream. The damage
    ;     VALUE differs between the sides and is deliberately not compared:
    ;     it survives only in transient battle scratch, and the enemy ends
    ;     at 0 HP either way.
    ; The one roll that could still diverge is the 1/256 accuracy miss
    ; (Gen-1 hit test). It is not a flake -- both emulators are
    ; deterministic, so it is a fixed outcome per side. The .kod assert
    ; below turns a divergence there into a loud failure instead of a
    ; confusing WRAM diff.
    ;
    ; Turn entry is preset rather than driven through the menus, the same
    ; documented bypass DEBUG_ITEMBALL uses above: the port's in-battle
    ; menus are still battle-plan stubs. What is NOT bypassed is anything
    ; under test -- ExecutePlayerMove and HandleEnemyMonFainted are the
    ; real routines, and everything they reach runs for real.
    ; pret refs: MainInBattleLoop sets wPlayerSelectedMove from the move
    ; list then calls ExecutePlayerMove (core.asm:3244); it calls
    ; HandleEnemyMonFainted (core.asm:708) when the enemy hits 0 HP, which
    ; for a WILD battle runs FaintEnemyPokemon -> GainExperience and
    ; returns at the `ld a,[wIsInBattle] / dec a / ret z` wild exit.
    ; ------------------------------------------------------------------
    call LoadScreenTilesFromBuffer1
    call DrawHUDsAndHPBars
    ; The debug party pokes STRENGTH into SNORLAX's move slot 4
    ; (tools/mgba_harness/lib/seed.lua DEBUG_PARTY[1].pokes[4]), so the
    ; 0-based list index is 3. Both are set: GetCurrentMove reads
    ; wPlayerSelectedMove, DecrementPP reads wPlayerMoveListIndex.
    mov byte [ebp + wPlayerMoveListIndex], 3
    mov byte [ebp + wPlayerSelectedMove], STRENGTH
    ; not an item/run/switch turn -- ExecutePlayerMove bails to
    ; ExecutePlayerMoveDone if this is nonzero (core.asm:3257)
    mov byte [ebp + wActionResultOrTookBattleTurn], 0
    call ExecutePlayerMove
    ; The enemy must be at 0 HP now. If a 1/256 miss (or any pipeline
    ; regression) left it standing, fail loudly here rather than dumping a
    ; state that silently is not the scenario's subject.
    mov al, [ebp + wEnemyMonHP]
    or al, [ebp + wEnemyMonHP + 1]      ; big-endian word, either byte set = alive
    jz .faintKO
.faintAlive:
    ; Park with a distinctive marker so a failed run is diagnosable from
    ; FRAME.BIN rather than looking like a hang.
    mov byte [ebp + W_TILEMAP], 0xEE
    call DelayFrame
    call DumpBackbuffer                 ; writes FRAME.BIN, then exits
.faintKO:
    call HandleEnemyMonFainted          ; FaintEnemyPokemon -> GainExperience
    call DebugDumpMemory                ; GBSTATE.BIN (id 21) + DUMP.BIN + exit
%elifdef DEBUG_BATTLE_BLACKOUT
    ; ------------------------------------------------------------------
    ; battle_blackout golden gate — the OTHER half of the faint coverage
    ; battle_faint opened. battle_faint kills the ENEMY; nothing in the
    ; suite has ever killed the PLAYER, so RemoveFaintedPlayerMon and
    ; HandlePlayerBlackOut are still moved-blind code. This gate runs the
    ; real enemy turn into a player faint that empties the party.
    ;
    ; WHY THE PARTY IS RESHAPED. Routing to the black-out branch requires
    ; AnyPartyAlive to fail (core.asm:985-988); any surviving mon instead
    ; reaches DoUseNextMonDialogue + ChooseNextMon. Their current port bodies
    ; auto-answer and auto-select instead of driving the interactive party menu,
    ; and that partial flow is not this scenario's subject. So
    ; exactly one mon is left alive. It is party slot 3, STARTER_PIKACHU
    ; L5 (tools/mgba_harness/lib/seed.lua DEBUG_PARTY[4]), not slot 0:
    ; the send-out scan takes the first ALIVE mon, so zeroing 0-2 selects
    ; slot 3 on BOTH sides without either side naming it.
    ;
    ; RNG-INDEPENDENCE, same discipline as battle_faint (the two sides do
    ; NOT share an RNG stream):
    ;   * PIKACHU L5 speed ~14 vs the spec PIDGEY L13's measured 21, so
    ;     the ENEMY ALWAYS MOVES FIRST. The player mon faints before it
    ;     ever acts, so its PP and the party's PP are untouched -- which
    ;     is what makes the compared party data roll-invariant.
    ;   * The player mon is left at 1 HP, so ANY damage roll and any crit
    ;     outcome faints it. Gen-1 minimum damage is 1.
    ;   * The enemy's 4 moves are PINNED to GUST so move SELECTION cannot
    ;     matter. Without this the AI could pick SAND-ATTACK, deal no
    ;     damage, and hand the turn to the player -- who would then act,
    ;     decrementing PP a different number of times on each side. This
    ;     is a seed pin of the same class as seed.enemy's DV pin, and the
    ;     golden applies the identical pin.
    ; Residual roll: GUST's 1/256 Gen-1 accuracy miss. Deterministic per
    ; side, so the .blackoutAlive assert below makes it loud.
    ;
    ; pret refs: MainInBattleLoop calls ExecuteEnemyMove (core.asm:3244
    ; is the player twin) and then HandlePlayerMonFainted (core.asm:981)
    ; when the battle mon hits 0 HP; that runs RemoveFaintedPlayerMon and,
    ; with no mon alive, jp HandlePlayerBlackOut (core.asm:1171), which
    ; prints the blacked-out text, clears the screen and returns carry.
    ; ------------------------------------------------------------------
    call LoadScreenTilesFromBuffer1
    ; --- leave exactly one mon alive: slot 3 at 1 HP, the rest at 0 ---
    ; party-mon HP is a big-endian word at wPartyMon1HP + slot*44.
%assign BO_SLOT 0
%rep 6
%if BO_SLOT == 3
    mov word [ebp + wPartyMon1HP + BO_SLOT * PARTYMON_STRUCT_LENGTH], 0x0100
%else
    mov word [ebp + wPartyMon1HP + BO_SLOT * PARTYMON_STRUCT_LENGTH], 0x0000
%endif
%assign BO_SLOT BO_SLOT + 1
%endrep
    ; --- re-run the send-out for the one alive mon (slot 3) ---
    mov byte [ebp + wWhichPokemon], 3
    mov byte [ebp + wPlayerMonNumber], 3
    mov al, [ebp + wPartySpecies + 3]
    mov [ebp + wCurPartySpecies], al
    mov [ebp + wBattleMonSpecies2], al
    ; The gain-exp flags still carry InitBattle's send-out of slot 0, which this
    ; reshape retired. The golden never has that bit: its reshape lands BEFORE
    ; the send-out, so the real ChooseNextMon/send-out FLAG_SETs slot 3 and
    ; nothing else. LoadBattleMonFromParty does no flag bookkeeping, so restate
    ; it here or the flags diverge by exactly bit 0 (measured: port $01 vs
    ; golden $00 -- RemoveFaintedPlayerMon then clears slot 3's bit on both
    ; sides, so the compared end state is $00).
    mov byte [ebp + wPartyGainExpFlags], 1 << 3
    call LoadBattleMonFromParty         ; REAL loader; copies the 1 HP across
    call DrawHUDsAndHPBars
    ; --- pin the enemy's moves and its selection to GUST (see header) ---
    mov byte [ebp + wEnemyMonMoves + 0], GUST
    mov byte [ebp + wEnemyMonMoves + 1], GUST
    mov byte [ebp + wEnemyMonMoves + 2], GUST
    mov byte [ebp + wEnemyMonMoves + 3], GUST
    mov byte [ebp + wEnemySelectedMove], GUST
    mov byte [ebp + wEnemyMoveListIndex], 0
    mov byte [ebp + wActionResultOrTookBattleTurn], 0
    call ExecuteEnemyMove               ; the real enemy turn
    ; The player mon must be down now.
    mov al, [ebp + wBattleMonHP]
    or al, [ebp + wBattleMonHP + 1]     ; big-endian word, either byte set = alive
    jz .blackoutKO
.blackoutAlive:
    mov byte [ebp + W_TILEMAP], 0xEE    ; distinctive marker for FRAME.BIN
    call DelayFrame
    call DumpBackbuffer                 ; writes FRAME.BIN, then exits
.blackoutKO:
    call HandlePlayerMonFainted         ; RemoveFaintedPlayerMon -> HandlePlayerBlackOut
    call DebugDumpMemory                ; GBSTATE.BIN + DUMP.BIN + exit
%else
%error DEBUG_BATTLE_GOLDEN needs DEBUG_BATTLE_INTRO, DEBUG_BATTLE_MENU, DEBUG_MOVEMENU, DEBUG_ITEMBALL, DEBUG_BATTLE_FAINT or DEBUG_BATTLE_BLACKOUT
%endif
%endif

%else ; ------- the interactive/synthetic DEBUG_BATTLE harness -------
    mov byte [ebp + 0xD162], 0      ; wPartyCount = 0
    mov byte [ebp + 0xD163], 0xFF   ; wPartySpecies sentinel
    mov byte [ebp + 0xD31C], 0      ; wNumBagItems = 0
    mov byte [ebp + 0xD31D], 0xFF   ; wBagItems sentinel
    call PrepareNewGameDebug        ; seed party + bag (player mons for later stages)
    ; --- Stage-1b HUD test data: seed enemy + player battle-mon structs so the HUD
    ; has names / levels / HP to render (real path = LoadBattleMonFromParty, Stage 2/3).
    ; Enemy "PIDGEY" L3, HP 14/14 (full bar). Names = charmap bytes, $50-terminated.
    mov byte [ebp + wEnemyMonNick + 0], 0x8F  ; P
    mov byte [ebp + wEnemyMonNick + 1], 0x88  ; I
    mov byte [ebp + wEnemyMonNick + 2], 0x83  ; D
    mov byte [ebp + wEnemyMonNick + 3], 0x86  ; G
    mov byte [ebp + wEnemyMonNick + 4], 0x84  ; E
    mov byte [ebp + wEnemyMonNick + 5], 0x98  ; Y
    mov byte [ebp + wEnemyMonNick + 6], 0x50  ; @
    ; PIDGEY L13 — at this level its real moveset is GUST + SAND-ATTACK (L5) +
    ; QUICK-ATTACK (L12), so the wild random-move AI visibly varies turn to turn.
    ; Stats are L13-appropriate (≈base+DV at L13) so the damage trades read sensibly.
    mov byte [ebp + wEnemyMonLevel], 13
    ; HP/stats = the Stage 2 convergence spec (PIDGEY L13, DVs $98 $76 —
    ; golden-measured 36/19/17/21/15), so live play matches the goldens.
    ; (The old TEMP PP-test 200-HP seed is de-REVERTed per the plan.)
    mov word [ebp + wEnemyMonHP], 0x2400      ; big-endian 36
    mov word [ebp + wEnemyMonMaxHP], 0x2400   ; big-endian 36
    mov byte [ebp + wEnemyMonStatus], 0
    ; enemy stats/types for the damage calc (PIDGEY: Normal/Flying)
    mov byte [ebp + wEnemyMonType1], 0x00      ; NORMAL
    mov byte [ebp + wEnemyMonType2], 0x02      ; FLYING
    mov word [ebp + wEnemyMonAttack],  0x1300  ; 19 (big-endian)
    mov word [ebp + wEnemyMonDefense], 0x1100  ; 17
    mov word [ebp + wEnemyMonSpeed],   0x1500  ; 21
    mov word [ebp + wEnemyMonSpecial], 0x0F00  ; 15
    mov byte [ebp + wEnemyMonSpecies], 0x24    ; PIDGEY (internal index) — real moveset gen
    ; A real wild encounter sets wEnemyMonSpecies2 + wCurEnemyLevel (TryDoWildEncounter);
    ; this harness seeds wEnemyMon* directly, so mirror them — LoadEnemyMonData keys off
    ; wEnemyMonSpecies2, and ItemUseBall re-runs it on a capture (0 → GetMonLearnset OOB).
    mov byte [ebp + wEnemyMonSpecies2], 0x24
    mov byte [ebp + wCurEnemyLevel], 13
    ; Player "PIKACHU" L18, full 45-HP bar — enough to absorb several enemy turns so
    ; the battle runs long enough to watch the enemy's random move selection vary.
    mov byte [ebp + wBattleMonNick + 0], 0x8F  ; P
    mov byte [ebp + wBattleMonNick + 1], 0x88  ; I
    mov byte [ebp + wBattleMonNick + 2], 0x8A  ; K
    mov byte [ebp + wBattleMonNick + 3], 0x80  ; A
    mov byte [ebp + wBattleMonNick + 4], 0x82  ; C
    mov byte [ebp + wBattleMonNick + 5], 0x87  ; H
    mov byte [ebp + wBattleMonNick + 6], 0x94  ; U
    mov byte [ebp + wBattleMonNick + 7], 0x50  ; @
    mov byte [ebp + wBattleMonLevel], 18
    mov word [ebp + wBattleMonHP], 0x2D00     ; big-endian 45
    mov word [ebp + wBattleMonMaxHP], 0x2D00  ; big-endian 45
    mov byte [ebp + wBattleMonStatus], 0
    ; Pikachu's moves (FIGHT submenu): THUNDERSHOCK, GROWL, TAIL WHIP, QUICK ATTACK
    mov byte [ebp + wBattleMonMoves + 0], 0x54  ; THUNDERSHOCK
    mov byte [ebp + wBattleMonMoves + 1], 0x2D  ; GROWL
    mov byte [ebp + wBattleMonMoves + 2], 0x27  ; TAIL_WHIP
    mov byte [ebp + wBattleMonMoves + 3], 0x62  ; QUICK_ATTACK
    ; Full PP (the moves' real maxima; the TEMP low-PP Struggle-test seed is
    ; de-REVERTed per the fidelity plan's Stage 2):
    mov byte [ebp + wBattleMonPP + 0], 30      ; THUNDERSHOCK
    mov byte [ebp + wBattleMonPP + 1], 40      ; GROWL
    mov byte [ebp + wBattleMonPP + 2], 30      ; TAIL_WHIP
    mov byte [ebp + wBattleMonPP + 3], 30      ; QUICK_ATTACK
    ; player stats/types for the damage calc (PIKACHU: Electric)
    mov byte [ebp + wBattleMonType1], 0x17     ; ELECTRIC
    mov byte [ebp + wBattleMonType2], 0x17
    mov word [ebp + wBattleMonAttack],  0x1600 ; 22 (big-endian)
    mov word [ebp + wBattleMonDefense], 0x0F00 ; 15
    mov word [ebp + wBattleMonSpeed],   0x2800 ; 40 (faster than PIDGEY → player acts first)
    mov word [ebp + wBattleMonSpecial], 0x0C00 ; 12
    mov byte [ebp + wPlayerMonNumber], 0
    mov byte [ebp + wCriticalHitOrOHKO], 0
    mov byte [ebp + wEnemyBattleStatus3], 0
    mov byte [ebp + wPlayerBattleStatus3], 0   ; reflect/light-screen off (enemy-turn defense)
    ; clean the battle-status / disabled-move bytes SelectEnemyMove inspects, so its
    ; forced-move early-outs and the disabled-slot re-roll behave deterministically.
    mov byte [ebp + wEnemyBattleStatus1], 0
    mov byte [ebp + wEnemyBattleStatus2], 0
    mov byte [ebp + wPlayerBattleStatus1], 0
    mov byte [ebp + wEnemyDisabledMove], 0
    ; Seed the stat-stage modifiers to the neutral default (7) for BOTH battle mons.
    ; A real battle sets these in LoadBattleMonFromParty on send-out; this harness seeds
    ; wBattleMon*/wEnemyMon* directly, so without this the 8 mod bytes stay 0. CalcHitChance
    ; indexes StatModifierRatios by (accuracyMod-1)*2 — with mod 0 that's (0-1)&0xFF*2 = 254,
    ; reading ~228 bytes off the 26-byte table → garbage accuracy → moves "miss". (That
    ; garbage sits at a fixed .data offset, so the failure flips with unrelated code-size
    ; changes — which is why it appeared to come and go across rebuilds.)
    mov ecx, NUM_STAT_MODS
    mov esi, wPlayerMonAttackMod
.seedPMods:
    mov byte [ebp + esi], 7
    inc esi
    dec ecx
    jnz .seedPMods
    mov ecx, NUM_STAT_MODS
    mov esi, wEnemyMonAttackMod
.seedEMods:
    mov byte [ebp + esi], 7
    inc esi
    dec ecx
    jnz .seedEMods
    ; generate the wild enemy's moveset the real way (base moves + level-up learnset
    ; for PIDGEY $24 at its level) — replaces the old hardcoded move seed.
    call LoadWildMonMoves
    or byte [ebp + W_FONT_LOADED], (1 << BIT_FONT_LOADED)
    call LoadFontTilePatterns
    call LoadTextBoxTilePatterns
    call InitBattleCanvas           ; setup + clear canvas (no box/HUD yet)
%ifdef DEBUG_BATTLE_TRAINER
    ; --- Bug Catcher trainer test: trainer battle (enemy = trainer + ball row, not a
    ; wild mon), with party-status variety to exercise ok/fainted/status/empty balls. ---
    mov byte [ebp + wIsInBattle], 2
    mov byte [ebp + wEnemyPartyCount], 3
    ; enemy mon0 ok (HP 10), mon1 fainted (HP 0), mon2 statused (HP 10, status set)
    mov word [ebp + wEnemyMons + 0*PARTYMON_STRUCT_LENGTH + MON_HP], 0x0A00
    mov byte [ebp + wEnemyMons + 0*PARTYMON_STRUCT_LENGTH + MON_STATUS], 0
    mov word [ebp + wEnemyMons + 1*PARTYMON_STRUCT_LENGTH + MON_HP], 0
    mov byte [ebp + wEnemyMons + 1*PARTYMON_STRUCT_LENGTH + MON_STATUS], 0
    mov word [ebp + wEnemyMons + 2*PARTYMON_STRUCT_LENGTH + MON_HP], 0x0A00
    mov byte [ebp + wEnemyMons + 2*PARTYMON_STRUCT_LENGTH + MON_STATUS], 0x08
    ; player party variety: mon1 fainted, mon2 statused (PrepareNewGameDebug seeded healthy)
    mov word [ebp + wPartyMons + 1*PARTYMON_STRUCT_LENGTH + MON_HP], 0
    mov byte [ebp + wPartyMons + 2*PARTYMON_STRUCT_LENGTH + MON_STATUS], 0x08
    call DebugLoadEmbeddedTrainerPic     ; decode Bug Catcher trainer sprite → enemy VRAM
%else
    mov byte [ebp + wIsInBattle], 1
    call DebugLoadEmbeddedEnemyFrontPic     ; decode enemy (wild mon) front pic → VRAM
%endif
    call LoadPlayerBackPic  ; decode player trainer (Red) back pic → VRAM (slides in)
    call SlideBattlePicsIn          ; faithful silhouette slide-in (darkened)
    call DrawBattleIntroBox         ; box + "Wild <nick> appeared!" + enemy HUD
    call SaveBattleScreen           ; snapshot the clean screen (restored on menu re-entry)
%ifdef DEBUG_ITEMBALL
    ; --- items-plan Stage 6 gate: throw a ball at the seeded wild PIDGEY. ---
    ; The in-battle bag UI (BattleItemMenu) is still a battle-plan stub, so this
    ; drives UseItem the way that menu eventually will: wCurItem = the ball,
    ; wWhichPokemon = its BAG SLOT (RemoveItemFromInventory removes by index).
    ; The seeded bag (debug_party.asm) is POTION, ANTIDOTE, MASTER_BALL, … → slot 2.
    ; Party count is dropped to 5 so a capture takes the AddPartyMon path; the box
    ; path (SendNewMonToBox) ends in the interactive naming screen, which a headless
    ; run cannot answer. ITEMBALL_ID/ITEMBALL_SLOT override the ball under test.
%ifndef ITEMBALL_ID
%define ITEMBALL_ID 0x01                ; MASTER_BALL — always captures (deterministic)
%endif
%ifndef ITEMBALL_SLOT
%define ITEMBALL_SLOT 2
%endif
    mov byte [ebp + wIsInBattle], 1     ; wild battle
    mov byte [ebp + wPartyCount], 5     ; leave one party slot free
    mov byte [ebp + wBattleType], 0     ; BATTLE_TYPE_NORMAL
    mov byte [ebp + wWhichPokemon], ITEMBALL_SLOT
    mov byte [ebp + wCurItem], ITEMBALL_ID
    ; PrepareNewGameDebug does not clear the dex bitsets, so they hold uninitialised
    ; WRAM — the "already in the pokédex?" FLAG_TEST would read a garbage 1 and skip
    ; ShowPokedexData. Zero both bitsets so the capture takes the real new-species path
    ; and the dump's owned bit is a meaningful check.
    mov ecx, wPokedexSeenEnd - wPokedexOwned
    mov esi, wPokedexOwned
.zeroDex:
    mov byte [ebp + esi], 0
    inc esi
    dec ecx
    jnz .zeroDex
    call UseItem
    call DebugDumpMemory                ; DUMP.BIN (the windows: table below) + exit
%endif
%ifdef DEBUG_BATTLE_LIVE
    ; Intro: party-status pokéballs + "Wild <nick> appeared!", wait for A/B (blinking
    ; ▼), then the balls give way to the player HP-bar HUD (DisplayBattleMenu draws it).
    call DrawBattlePokeballs
    call WaitForAPress
    call HideBattlePokeballs
    ; send-out: faithfully the player trainer sprite slides OUT, then the mon comes in.
    ; For the starter PIKACHU this is just a SLIDE (it never enters a ball, so there is
    ; no throw/grow animation — Yellow special); every other mon gets the ball-throw +
    ; grow (AnimateSendingOutMon, more involved). TODO(send-out): trainer slide-out +
    ; Pikachu slide-in (easy) / ball+grow for others. For now: straight VRAM swap.
    call LoadEmbeddedBackPicFallback     ; decode PIKACHU back pic → VRAM $31 (same tilemap block)
%ifdef DEBUG_BATTLE_TRAINER
    ; enemy send-out: the TRAINER sends out its first mon, so the trainer sprite is
    ; replaced by the enemy mon's front pic (decode over VRAM $00, same tilemap block);
    ; DisplayBattleMenu's DrawBattleHUDs then draws the enemy HP bar (was suppressed for
    ; the trainer intro). TODO(send-out): trainer slide-out + the real enemy-mon throw.
    call DebugLoadEmbeddedEnemyFrontPic     ; enemy mon (PIDGEY) front → VRAM $00 (replaces Bug Catcher)
%endif
    ; Stage 3 (victory EXP): seed the defeated enemy's base stats + base exp (PIDGEY:
    ; HP40/Atk45/Def40/Spd56/Spc35, base exp 55) for GainExperience's stat-exp + EXP
    ; award, and flag party slot 0 (wPlayerMonNumber=0) to gain EXP. Real battles set
    ; these when the enemy mon is loaded / on send-out; the harness seeds the enemy
    ; battle-mon directly, so they're seeded here too.
    mov byte [ebp + wEnemyMonBaseStats + 0], 40   ; HP
    mov byte [ebp + wEnemyMonBaseStats + 1], 45   ; Attack
    mov byte [ebp + wEnemyMonBaseStats + 2], 40   ; Defense
    mov byte [ebp + wEnemyMonBaseStats + 3], 56   ; Speed
    mov byte [ebp + wEnemyMonBaseStats + 4], 35   ; Special
    mov byte [ebp + wEnemyMonBaseExp], 55
    ; flag the PIKACHU slot (DEBUG_PARTY party: 0=SNORLAX 1=PERSIAN 2=JIGGLYPUFF 3=PIKACHU
    ; L5 4=CHARIZARD 5=LAPRAS) so the gaining/leveling mon matches the on-screen PIKACHU.
    ; PIKACHU L5 + 102 EXP → L6, exercising the level-up display (grew text + stats box).
    or byte [ebp + wPartyGainExpFlags], (1 << 3)  ; party slot 3 (PIKACHU) participates → gains EXP
    mov byte [wBattleOver], 0        ; legacy harness flag (core.asm uses wBattleResult)
    ; Faithful battle loop: core.asm MainInBattleLoop runs the whole battle (menu, move
    ; select, speed-ordered turns, residual damage, faint/EXP/run) and returns on a
    ; terminal outcome (win/lose/ran). Esc quits the process.
    call MainInBattleLoop
    ; Post-battle: pret calls EndOfBattle here (via _InitBattleCommon, right after
    ; StartBattle). On a win it clears wForceEvolution + runs EvolutionAfterBattle
    ; (level-based post-battle evolutions) + UpdatePikachuMoodAfterBattle, then resets
    ; the battle WRAM and whites out. See current_plan_pokemon_behavior Stage 5.
    call EndOfBattle
    call EndBattleScreen            ; clean terminal (clears the battle screen)
.battle_done:
    call DelayFrame                 ; hold the terminal (real exit = overworld, Stage 3)
    jmp .battle_done
%elifdef DEBUG_BATTLE_ENEMYHIT
    ; Stage-2b ground-truth: pick the enemy move via the wild AI (SelectEnemyMove),
    ; run ONE enemy attack (no input waits), and dump battle WRAM. Proves the
    ; generated moveset (wEnemyMonMoves) + DoEnemyAttackDamage drains the player HP.
    call SelectEnemyMove
    call DoEnemyAttackDamage
    jmp DebugDumpMemory             ; writes DUMP.BIN, exits
%elifdef DEBUG_BATTLE_INTRO
    ; Dump the battle INTRO screen (scene + "Wild <nick> appeared!" + the ▼ advance
    ; arrow + the party-status pokéball row), no menu.
    mov byte [ebp + W_TILEMAP + (19 * 40 + 28)], 0xEE   ; ▼ (verify glyph renders)
    call DrawBattlePokeballs        ; player party-status balls (OAM sprites)
    call DelayFrame
    call DumpBackbuffer
.introhang:
    jmp .introhang
%elifdef DEBUG_MOVEMENU
    ; menu-fidelity row 22: render pret's MoveSelectionMenu + PrintMenuItem (the move
    ; list, the cursor, and the TYPE/PP box) with the DEBUG_BATTLE seed party. No golden
    ; scenario covers the FIGHT sub-menu, so this is its verification route.
    ; MoveSelectionMenu blocks in HandleMenuInput; build with DEBUG_AUTOKEY + AUTOKEY_QUIET
    ; (the Makefile does it) so AutoKeyDrive photographs the screen at AUTOKEY_DUMP_FRAME
    ; from inside the menu loop and exits. wMoveMenuType selects which of the three menus:
    ; 0 = regular battle (default), 1 = Mimic, 2 = move relearner.
%ifndef DEBUG_MOVEMENU_TYPE
%define DEBUG_MOVEMENU_TYPE 0
%endif
    mov byte [ebp + wMoveMenuType], DEBUG_MOVEMENU_TYPE
    mov byte [ebp + wPlayerMoveListIndex], 0
    mov byte [ebp + wMenuItemToSwap], 0
    call DrawBattleMenu             ; the FIGHT/PKMN/ITEM/RUN box the move box joins onto
    call MoveSelectionMenu
.movemenuhang:
    call DelayFrame
    jmp .movemenuhang
%else
    call DrawBattleMenu             ; Stage 2a: FIGHT/PKMN/ITEM/RUN menu (static)
    call DelayFrame
    call DumpBackbuffer             ; dump FRAME.BIN + exit (never returns)
.hang:
    jmp .hang
%endif
%endif ; DEBUG_BATTLE_GOLDEN / synthetic split
%endif

%ifdef DEBUG_LEARNMOVE
; ---------------------------------------------------------------------------
; RunLearnMoveTest — no-input ground truth for current_plan_pokemon_behavior
; Stage 3: does LearnMove's PrintText(LearnedMove1Text) render a legible box
; with the right nick/move-name substitutions in the live battle canvas? Seeds
; a battle-mode canvas (InitBattle, no enemy scene needed) then calls the exact
; src/engine/pokemon/evos_moves.asm:LearnMoveFromLevelUp entry point the real
; post-battle level-up sequence calls, on PrepareNewGameDebug's real STARTER_
; PIKACHU (party slot 3, level 5) — its moves come from the real WriteMonMoves
; learnset walk (add_mon.asm), not hand-picked, so whichever slot is open
; is authentic. Levels it 5->6, which pret's PikachuEvosMoves learns TAIL_WHIP
; at (evos_moves.asm-equivalent assets/evos_moves.inc). wPlayerMonNumber is also
; set to slot 3 so the in-battle wBattleMonMoves/PP sync branch runs too.
; ---------------------------------------------------------------------------
RunLearnMoveTest:
    mov byte [ebp + 0xD162], 0      ; wPartyCount = 0
    mov byte [ebp + 0xD163], 0xFF   ; wPartySpecies sentinel
    mov byte [ebp + 0xD31C], 0      ; wNumBagItems = 0
    mov byte [ebp + 0xD31D], 0xFF   ; wBagItems sentinel
    call PrepareNewGameDebug        ; seeds party incl. slot3 = STARTER_PIKACHU L5

    ; InitBattle reads wEnemyMonSpecies/Level/Nick to load the enemy pic; the
    ; enemy itself is irrelevant here (LearnMoveFromLevelUp never reads it), so
    ; seed a minimal PIDGEY L13 exactly like RunBattleTest above.
    mov byte [ebp + wEnemyMonNick + 0], 0x8F  ; P
    mov byte [ebp + wEnemyMonNick + 1], 0x88  ; I
    mov byte [ebp + wEnemyMonNick + 2], 0x83  ; D
    mov byte [ebp + wEnemyMonNick + 3], 0x86  ; G
    mov byte [ebp + wEnemyMonNick + 4], 0x84  ; E
    mov byte [ebp + wEnemyMonNick + 5], 0x98  ; Y
    mov byte [ebp + wEnemyMonNick + 6], 0x50  ; @
    mov byte [ebp + wEnemyMonLevel], 13
    mov byte [ebp + wEnemyMonSpecies], 0x24   ; PIDGEY (internal index)

    or byte [ebp + W_FONT_LOADED], (1 << BIT_FONT_LOADED)
    call LoadFontTilePatterns
    call LoadTextBoxTilePatterns
    mov byte [ebp + wIsInBattle], 1
    call InitBattleCanvas           ; battle-mode canvas (clears screen, no HUD/box yet)

%ifdef DEBUG_LEARNMOVE_FULL
    ; Sub-flag: fill all 4 slots so the all-slots-full (AbandonLearning) branch
    ; runs instead. make DEBUG_LEARNMOVE=1 DEBUG_LEARNMOVE_FULL=1
    mov byte [ebp + wPartyMon1 + 3*PARTYMON_STRUCT_LENGTH + MON_MOVES + 0], 1
    mov byte [ebp + wPartyMon1 + 3*PARTYMON_STRUCT_LENGTH + MON_MOVES + 1], 2
    mov byte [ebp + wPartyMon1 + 3*PARTYMON_STRUCT_LENGTH + MON_MOVES + 2], 3
    mov byte [ebp + wPartyMon1 + 3*PARTYMON_STRUCT_LENGTH + MON_MOVES + 3], SURF
%endif
    mov byte [ebp + wWhichPokemon], 3
    mov byte [ebp + wPlayerMonNumber], 3    ; == wWhichPokemon -> exercises battle-sync too
    mov byte [ebp + wCurEnemyLevel], 6
    mov byte [ebp + wPokedexNum], STARTER_PIKACHU

    call LearnMoveFromLevelUp
    call DelayFrame
    call DumpBackbuffer             ; dump FRAME.BIN + exit (never returns)
.hang:
    jmp .hang
%endif

%ifdef DEBUG_STATUS
; RunStatusScreenTest — seed the party, open the status/summary screen page 1 for
; the STARTER_PIKACHU in slot 3, and let StatusScreen's DEBUG_STATUS hook render one
; frame + dump FRAME.BIN before its button-wait. Never returns.
RunStatusScreenTest:
    mov byte [ebp + 0xD162], 0      ; wPartyCount = 0
    mov byte [ebp + 0xD163], 0xFF   ; wPartySpecies sentinel
    mov byte [ebp + 0xD31C], 0      ; wNumBagItems = 0
    mov byte [ebp + 0xD31D], 0xFF   ; wBagItems sentinel
    call PrepareNewGameDebug        ; seeds party incl. slot3 = STARTER_PIKACHU L5

    or byte [ebp + W_FONT_LOADED], (1 << BIT_FONT_LOADED)
    call LoadFontTilePatterns       ; font glyphs ($80+) — StatusScreen loads HP/HUD/box tiles itself
    mov byte [ebp + wWhichPokemon], 3
    mov byte [ebp + wMonDataLocation], 0    ; PLAYER_PARTY_DATA
    call StatusScreen               ; page 1; dumps + exits unless DEBUG_STATUS_PAGE2 (then returns)
%ifdef DEBUG_STATUS_PAGE2
    call StatusScreen2              ; page 2; dumps FRAME.BIN + exits
%endif
.hang:
    jmp .hang
%endif

; ---------------------------------------------------------------------------
; DebugDumpMemory — gather windows, write DUMP.BIN, exit. Never returns.
; In: EBP = GB memory base.
; ---------------------------------------------------------------------------
DebugDumpMemory:
    call DumpGBState               ; GBSTATE.BIN alongside every DUMP.BIN, so the
                                   ; DUMP.BIN-only gates (DEBUG_ITEM*, CALCSTATS…)
                                   ; feed the fidelity differ too — symmetric with
                                   ; DumpBackbuffer's call.
    ; --- 1. Gather each GB window into the staging buffer ---
    mov esi, windows
    mov edi, stage
    mov edx, NUM_WINDOWS
.gather:
    mov eax, [esi]                 ; GB offset of this window
    add esi, 4
    push esi
    push edx
    lea esi, [ebp + eax]           ; flat source = GB base + offset
    mov ecx, WIN_SIZE
    rep movsb                      ; DS:ESI -> ES:EDI, EDI accumulates
    pop edx
    pop esi
    dec edx
    jnz .gather

    ; --- 2. Allocate a 1 KB conventional DOS buffer (DPMI fn 0100h) ---
    mov ax, 0x0100
    mov bx, 0x40                   ; 64 paragraphs = 1024 bytes
    int 0x31
    jc .exit
    mov [dos_seg], ax
    mov [dos_sel], dx
    movzx eax, ax
    shl eax, 4                     ; linear = seg * 16
    sub eax, [ds_base]             ; flat (wraps under 4 GB limit -> linear)
    mov [dos_flat], eax

    ; --- 3. Stage filename at DOS buffer offset 0 ---
    mov esi, fname
    mov edi, [dos_flat]
    mov ecx, 9                     ; "DUMP.BIN" + NUL
    rep movsb

    ; --- 4. Stage dump data at DOS buffer offset 0x10 ---
    mov esi, stage
    mov edi, [dos_flat]
    add edi, 0x10
    mov ecx, DUMP_TOTAL
    rep movsb

    ; --- 5. Create file: INT 21h AH=3Ch, CX=0, DS:DX -> filename ---
    call zero_rmcs
    mov word [rmcs + RMCS_EAX], 0x3C00
    mov dword [rmcs + RMCS_EDX], 0                 ; filename at offset 0
    mov ax, [dos_seg]
    mov [rmcs + RMCS_DS], ax
    call sim_int21
    test byte [rmcs + RMCS_FLAGS], 1               ; CF set => error
    jnz .free
    mov ax, [rmcs + RMCS_EAX]
    mov [file_handle], ax

    ; --- 6. Write data: INT 21h AH=40h, BX=handle, CX=len, DS:DX -> data ---
    call zero_rmcs
    mov word [rmcs + RMCS_EAX], 0x4000
    movzx eax, word [file_handle]
    mov [rmcs + RMCS_EBX], eax
    mov dword [rmcs + RMCS_ECX], DUMP_TOTAL
    mov dword [rmcs + RMCS_EDX], 0x10              ; data at offset 0x10
    mov ax, [dos_seg]
    mov [rmcs + RMCS_DS], ax
    call sim_int21

    ; --- 7. Close file: INT 21h AH=3Eh, BX=handle ---
    call zero_rmcs
    mov word [rmcs + RMCS_EAX], 0x3E00
    movzx eax, word [file_handle]
    mov [rmcs + RMCS_EBX], eax
    call sim_int21

.free:
    ; Free the DOS buffer (DPMI fn 0101h, DX = selector)
    mov ax, 0x0101
    mov dx, [dos_sel]
    int 0x31

.exit:
    mov ax, 0x4C00
    int 0x21

; ---------------------------------------------------------------------------
; DumpGBState — write GBSTATE.BIN (header + W_TILEMAP + VRAM + OAM; layout at
; the GBSTATE_* equates above) so every DEBUG_* scenario emits the GB-state
; twin of the mGBA golden (fidelity harness Stage 1.3). Unlike the other dump
; routines this RETURNS — DumpBackbuffer calls it first, then writes FRAME.BIN
; and exits, so every existing hook gains GBSTATE.BIN with no call-site edits.
; In: EBP = GB memory base. Clobbers caller-saved regs; preserves EBP.
; ---------------------------------------------------------------------------
DumpGBState:
    ; --- Allocate a conventional DOS buffer: 0x10 + GBSTATE_TOTAL bytes ---
    ; 16 + 8464 = 8480 -> 530 paragraphs; round up to 0x280 (10 KB).
    mov ax, 0x0100
    mov bx, 0x280
    int 0x31
    jc .ret
    mov [dos_seg], ax
    mov [dos_sel], dx
    movzx eax, ax
    shl eax, 4
    sub eax, [ds_base]
    mov [dos_flat], eax

    ; --- Stage filename at offset 0 ---
    mov esi, fgbname
    mov edi, [dos_flat]
    mov ecx, 12                    ; "GBSTATE.BIN" + NUL
    rep movsb

    ; --- Header at offset 0x10 (= file offset 0) ---
    mov ebx, [dos_flat]
    add ebx, 0x10                  ; ebx = file base inside the DOS buffer
    mov dword [ebx], 'GBST'        ; little-endian store -> bytes G,B,S,T
    mov byte [ebx + 4], GBSTATE_VERSION
    mov byte [ebx + 5], GBSTATE_TERMINAL
    mov word [ebx + 6], GBSTATE_REGION_COUNT
    mov dword [ebx + 8], GBSTATE_DIR_SIZE
    mov dword [ebx + 12], GBSTATE_TOTAL

    ; --- Copy the region directory verbatim; EDI lands on the payload start ---
    mov esi, gbstate_regions
    lea edi, [ebx + GBSTATE_HDR_SIZE]
    mov ecx, GBSTATE_DIR_SIZE
    rep movsb

    ; --- Walk the regions: copy each payload, back-fill its file_offset ---
    ;   EBX = source dirent cursor    EDX = dest dirent cursor (in the buffer)
    ;   EDI = payload write cursor    EAX = running file offset
    mov edx, ebx
    add edx, GBSTATE_HDR_SIZE
    mov ebx, gbstate_regions
    mov eax, GBSTATE_HDR_SIZE + GBSTATE_DIR_SIZE
.region:
    cmp ebx, gbstate_regions_end
    jae .regions_done
    mov [edx + GBSTATE_NAME_LEN + 8], eax     ; dirent.file_offset
    mov esi, [ebx + GBSTATE_NAME_LEN]         ; dirent.gb_addr
    mov ecx, [ebx + GBSTATE_NAME_LEN + 4]     ; dirent.size
    add eax, ecx
    lea esi, [ebp + esi]                      ; flat source = GB base + addr
    rep movsb                                 ; -> EDI, which accumulates
    add ebx, GBSTATE_DIRENT_SIZE
    add edx, GBSTATE_DIRENT_SIZE
    jmp .region
.regions_done:

    ; --- Create GBSTATE.BIN ---
    call zero_rmcs
    mov word [rmcs + RMCS_EAX], 0x3C00
    mov dword [rmcs + RMCS_EDX], 0
    mov ax, [dos_seg]
    mov [rmcs + RMCS_DS], ax
    call sim_int21
    test byte [rmcs + RMCS_FLAGS], 1
    jnz .free
    mov ax, [rmcs + RMCS_EAX]
    mov [file_handle], ax

    ; --- Write header + regions in one shot ---
    call zero_rmcs
    mov word [rmcs + RMCS_EAX], 0x4000
    movzx eax, word [file_handle]
    mov [rmcs + RMCS_EBX], eax
    mov dword [rmcs + RMCS_ECX], GBSTATE_TOTAL
    mov dword [rmcs + RMCS_EDX], 0x10
    mov ax, [dos_seg]
    mov [rmcs + RMCS_DS], ax
    call sim_int21

    ; --- Close ---
    call zero_rmcs
    mov word [rmcs + RMCS_EAX], 0x3E00
    movzx eax, word [file_handle]
    mov [rmcs + RMCS_EBX], eax
    call sim_int21

.free:
    mov ax, 0x0101
    mov dx, [dos_sel]
    int 0x31
.ret:
    ret

; ---------------------------------------------------------------------------
; DumpBackbuffer — write the full GB_BACKBUF (RENDER_W*RENDER_H = 64000 raw
; palette-indexed bytes) to FRAME.BIN, then exit. Lets the host render the exact
; pixels the software PPU produced under DOSBox-X (no compositor screenshot).
; Allocates a single 64 KB+ conventional buffer so the data goes out in one write.
; First writes GBSTATE.BIN via DumpGBState, so every FRAME.BIN hook also emits
; the GB-state dump the fidelity differ consumes (Stage 1.3).
; In: EBP = GB memory base. Never returns.
; ---------------------------------------------------------------------------
DumpBackbuffer:
    call DumpGBState               ; GBSTATE.BIN alongside every FRAME.BIN
    call DumpPalette               ; PAL.BIN keeps host frame rendering lockstep
    ; --- Allocate a conventional DOS buffer big enough for 0x10 + 64000 bytes ---
    ; 0x10 + 64000 = 64016 bytes -> 4001 paragraphs; round up to 0x1001 (4097).
    mov ax, 0x0100
    mov bx, 0x1001
    int 0x31
    jc .exit
    mov [dos_seg], ax
    mov [dos_sel], dx
    movzx eax, ax
    shl eax, 4
    sub eax, [ds_base]
    mov [dos_flat], eax

    ; --- Stage filename at offset 0 ---
    mov esi, fbname
    mov edi, [dos_flat]
    mov ecx, 10                    ; "FRAME.BIN" + NUL
    rep movsb

    ; --- Copy backbuffer directly to buffer offset 0x10 ---
    lea esi, [ebp + GB_BACKBUF]
    mov edi, [dos_flat]
    add edi, 0x10
    mov ecx, GB_BACKBUF_SIZE
    rep movsb

    ; --- Create FRAME.BIN ---
    call zero_rmcs
    mov word [rmcs + RMCS_EAX], 0x3C00
    mov dword [rmcs + RMCS_EDX], 0
    mov ax, [dos_seg]
    mov [rmcs + RMCS_DS], ax
    call sim_int21
    test byte [rmcs + RMCS_FLAGS], 1
    jnz .free
    mov ax, [rmcs + RMCS_EAX]
    mov [file_handle], ax

    ; --- Write 64000 bytes ---
    call zero_rmcs
    mov word [rmcs + RMCS_EAX], 0x4000
    movzx eax, word [file_handle]
    mov [rmcs + RMCS_EBX], eax
    mov dword [rmcs + RMCS_ECX], GB_BACKBUF_SIZE
    mov dword [rmcs + RMCS_EDX], 0x10
    mov ax, [dos_seg]
    mov [rmcs + RMCS_DS], ax
    call sim_int21

    ; --- Close ---
    call zero_rmcs
    mov word [rmcs + RMCS_EAX], 0x3E00
    movzx eax, word [file_handle]
    mov [rmcs + RMCS_EBX], eax
    call sim_int21

.free:
    mov ax, 0x0101
    mov dx, [dos_sel]
    int 0x31
.exit:
    mov ax, 0x4C00
    int 0x21

; ---------------------------------------------------------------------------
; DumpPalette — write PAL.BIN alongside FRAME.BIN.  The file is a stable host
; debug contract: "PAL0", u8 version=1, 11 reserved, then 64 RGB6 DAC triples,
; tile_pal[384], bg_slot_pal[8], obj_slot_pal[8].  DAC triples are recomputed
; from the exact live slot tables and BGP/OBP mirrors, matching commit_palette.
; ---------------------------------------------------------------------------
DumpPalette:
    pushad
    mov byte [pal_stage + 0], 'P'
    mov byte [pal_stage + 1], 'A'
    mov byte [pal_stage + 2], 'L'
    mov byte [pal_stage + 3], '0'
    mov byte [pal_stage + 4], 1
    mov dword [pal_stage + 5], 0
    mov dword [pal_stage + 9], 0
    mov dword [pal_stage + 13], 0
    mov edi, pal_stage + PAL_HDR_SIZE
    xor ebx, ebx
.bg_slot:
    movzx esi, byte [bg_slot_pal + ebx]
    imul esi, 12
    add esi, pal_rgb_table
    movzx eax, byte [ebp + IO_BGP]
    mov [pal_reg_tmp], eax
    mov ecx, 4
.bg_color:
    mov eax, [pal_reg_tmp]
    mov edx, eax
    and edx, 3
    lea edx, [edx + edx*2]
    add edx, esi
    mov al, [edx]
    stosb
    mov al, [edx + 1]
    stosb
    mov al, [edx + 2]
    stosb
    shr dword [pal_reg_tmp], 2
    dec ecx
    jnz .bg_color
    inc ebx
    cmp ebx, 8
    jb .bg_slot
    xor ebx, ebx
.obj_slot:
    movzx esi, byte [obj_slot_pal + ebx]
    imul esi, 12
    add esi, pal_rgb_table
    movzx eax, byte [ebp + IO_OBP0]
    test ebx, 1
    jz .obj_reg
    movzx eax, byte [ebp + IO_OBP1]
.obj_reg:
    mov [pal_reg_tmp], eax
    mov ecx, 4
.obj_color:
    mov eax, [pal_reg_tmp]
    mov edx, eax
    and edx, 3
    lea edx, [edx + edx*2]
    add edx, esi
    mov al, [edx]
    stosb
    mov al, [edx + 1]
    stosb
    mov al, [edx + 2]
    stosb
    shr dword [pal_reg_tmp], 2
    dec ecx
    jnz .obj_color
    inc ebx
    cmp ebx, 8
    jb .obj_slot
    mov esi, tile_pal
    mov ecx, PAL_TILEPAL_SIZE
    rep movsb
    mov esi, bg_slot_pal
    mov ecx, 8
    rep movsb
    mov esi, obj_slot_pal
    mov ecx, 8
    rep movsb

    ; Stage filename + PAL.BIN payload in one conventional-memory buffer.
    mov ax, 0x0100
    mov bx, 0x100
    int 0x31
    jc .done
    mov [dos_seg], ax
    mov [dos_sel], dx
    movzx eax, ax
    shl eax, 4
    sub eax, [ds_base]
    mov [dos_flat], eax
    mov esi, fpname
    mov edi, [dos_flat]
    mov ecx, 8
    rep movsb
    mov esi, pal_stage
    mov edi, [dos_flat]
    add edi, 0x10
    mov ecx, PAL_TOTAL
    rep movsb
    call zero_rmcs
    mov word [rmcs + RMCS_EAX], 0x3c00
    mov ax, [dos_seg]
    mov [rmcs + RMCS_DS], ax
    call sim_int21
    test byte [rmcs + RMCS_FLAGS], 1
    jnz .free
    mov ax, [rmcs + RMCS_EAX]
    mov [file_handle], ax
    call zero_rmcs
    mov word [rmcs + RMCS_EAX], 0x4000
    movzx eax, word [file_handle]
    mov [rmcs + RMCS_EBX], eax
    mov dword [rmcs + RMCS_ECX], PAL_TOTAL
    mov dword [rmcs + RMCS_EDX], 0x10
    mov ax, [dos_seg]
    mov [rmcs + RMCS_DS], ax
    call sim_int21
    call zero_rmcs
    mov word [rmcs + RMCS_EAX], 0x3e00
    movzx eax, word [file_handle]
    mov [rmcs + RMCS_EBX], eax
    call sim_int21
.free:
    mov ax, 0x0101
    mov dx, [dos_sel]
    int 0x31
.done:
    popad
    ret

%ifdef DEBUG_NPC_WALK
; ---------------------------------------------------------------------------
; DumpNpcLog — write npc_log[0..npc_log_n) to NPCLOG.BIN, then exit.
; In: EBP = GB memory base. Never returns.
; ---------------------------------------------------------------------------
DumpNpcLog:
    mov ax, 0x0100
    mov bx, 0x1001                 ; 64 KB+ buffer (log is <= 4 KB)
    int 0x31
    jc .exit
    mov [dos_seg], ax
    mov [dos_sel], dx
    movzx eax, ax
    shl eax, 4
    sub eax, [ds_base]
    mov [dos_flat], eax

    ; filename at offset 0
    mov esi, fnlog
    mov edi, [dos_flat]
    mov ecx, 11                    ; "NPCLOG.BIN" + NUL
    rep movsb

    ; log bytes at offset 0x10
    mov esi, npc_log
    mov edi, [dos_flat]
    add edi, 0x10
    mov ecx, [npc_log_n]
    rep movsb

    call zero_rmcs
    mov word [rmcs + RMCS_EAX], 0x3C00
    mov dword [rmcs + RMCS_EDX], 0
    mov ax, [dos_seg]
    mov [rmcs + RMCS_DS], ax
    call sim_int21
    test byte [rmcs + RMCS_FLAGS], 1
    jnz .free
    mov ax, [rmcs + RMCS_EAX]
    mov [file_handle], ax

    call zero_rmcs
    mov word [rmcs + RMCS_EAX], 0x4000
    movzx eax, word [file_handle]
    mov [rmcs + RMCS_EBX], eax
    mov ecx, [npc_log_n]
    mov [rmcs + RMCS_ECX], ecx
    mov dword [rmcs + RMCS_EDX], 0x10
    mov ax, [dos_seg]
    mov [rmcs + RMCS_DS], ax
    call sim_int21

    call zero_rmcs
    mov word [rmcs + RMCS_EAX], 0x3E00
    movzx eax, word [file_handle]
    mov [rmcs + RMCS_EBX], eax
    call sim_int21
.free:
    mov ax, 0x0101
    mov dx, [dos_sel]
    int 0x31
.exit:
    mov ax, 0x4C00
    int 0x21
%endif

; ---------------------------------------------------------------------------
; sim_int21 — reflect INT 21h to real mode using the prepared rmcs.
; DPMI fn 0300h: BL=int#, BH=0, CX=0 (no stack words), ES:EDI -> rmcs.
; ---------------------------------------------------------------------------
sim_int21:
    push eax
    push ebx
    push ecx
    push edi
    mov ax, 0x0300
    mov bl, 0x21
    mov bh, 0
    xor cx, cx
    mov edi, rmcs                  ; ES already = flat DS selector
    int 0x31
    pop edi
    pop ecx
    pop ebx
    pop eax
    ret

; ---------------------------------------------------------------------------
; zero_rmcs — clear the real-mode call structure.
; ---------------------------------------------------------------------------
zero_rmcs:
    push eax
    push ecx
    push edi
    mov edi, rmcs
    xor al, al
    mov ecx, RMCS_SIZE
    rep stosb
    pop edi
    pop ecx
    pop eax
    ret

%ifdef DEBUG_SEAM
; ===========================================================================
; Seam-crossing trace harness (DEBUG_SEAM). Port-only debug code — no pret
; counterpart. Drives the real movement primitives across a map connection and
; records one 12-byte sample per rendered frame, so the host can see exactly
; when CheckMapConnections fires and whether the player's coordinates, the block
; -map view pointer, the fine scroll and the player's OAM entry stay coherent.
;
; Record layout (12 bytes, little-endian where noted):
;   0  wCurMap
;   1  wXCoord
;   2  wYCoord
;   3  wWalkCounter
;   4  wCurrentTileBlockMapViewPointer low   (5 = high)
;   6  wCurMapWidth
;   7  wCurMapHeight
;   8  hSCX
;   9  hSCY
;  10  OAM[0].Y   (player sprite; $00 => off-screen/hidden)
;  11  OAM[0].X
; ===========================================================================
SeamLogRecord:
    push eax
    push edi
    mov edi, [seam_log_i]               ; ring cursor — never "fills", oldest is overwritten
    add edi, seam_log

    mov al, [ebp + W_CUR_MAP]                          ; 0
    mov [edi + 0], al
    mov al, [ebp + W_X_COORD]                          ; 1
    mov [edi + 1], al
    mov al, [ebp + W_Y_COORD]                          ; 2
    mov [edi + 2], al
    mov al, [ebp + W_WALK_COUNTER]                     ; 3
    mov [edi + 3], al
    mov al, [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR]  ; 4
    mov [edi + 4], al
    mov al, [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR + 1] ; 5
    mov [edi + 5], al
    mov al, [ebp + W_CUR_MAP_WIDTH]                    ; 6
    mov [edi + 6], al
    mov al, [ebp + W_CUR_MAP_HEIGHT]                   ; 7
    mov [edi + 7], al
    mov al, [ebp + H_SCX]                              ; 8
    mov [edi + 8], al
    mov al, [ebp + H_SCY]                              ; 9
    mov [edi + 9], al
    mov al, [ebp + GB_OAM + 0]                         ; 10 player OAM Y
    mov [edi + 10], al
    mov al, [ebp + GB_OAM + 1]                         ; 11 player OAM X
    mov [edi + 11], al

    add dword [seam_log_n], SEAM_REC_SIZE
    mov eax, [seam_log_i]
    add eax, SEAM_REC_SIZE
    cmp eax, SEAM_LOG_CAP
    jb .stored
    xor eax, eax                        ; wrap
.stored:
    mov [seam_log_i], eax

%ifdef DEBUG_SEAM_LIVE
    ; Live mode: the player drives. Pressing A dumps the trace + the screen and quits.
    mov al, [ebp + H_JOY_PRESSED]
    test al, PAD_A
    jz .done
    pop edi
    pop eax
    call DumpSeamLog                    ; SEAMLOG.BIN (returns)
    jmp DumpBackbuffer                  ; FRAME.BIN, then exits — never returns
%endif
.done:
    pop edi
    pop eax
    ret

; DumpSeamLog — write seam_log to SEAMLOG.BIN and RETURN. Unlike the other dumpers
; this does not terminate: the harness calls DumpBackbuffer afterwards, and that one
; exits. (Ordering matters — DumpBackbuffer never returns.)
DumpSeamLog:
    mov ax, 0x0100
    mov bx, 0x1001                 ; 64 KB+ real-mode buffer (log <= 8 KB)
    int 0x31
    jc .exit
    mov [dos_seg], ax
    mov [dos_sel], dx
    movzx eax, ax
    shl eax, 4
    sub eax, [ds_base]
    mov [dos_flat], eax

    mov esi, fseam                 ; filename at offset 0
    mov edi, [dos_flat]
    mov ecx, 12                    ; "SEAMLOG.BIN" + NUL
    rep movsb

    ; log bytes at offset 0x10, oldest-first. If the ring never wrapped
    ; (total < CAP) it is simply [0, total). Otherwise the oldest record is at the
    ; write cursor, so emit [cursor, CAP) then [0, cursor).
    mov edi, [dos_flat]
    add edi, 0x10
    mov eax, [seam_log_n]
    cmp eax, SEAM_LOG_CAP
    jae .wrapped
    mov [seam_out_len], eax
    mov esi, seam_log
    mov ecx, eax
    rep movsb
    jmp .staged
.wrapped:
    mov dword [seam_out_len], SEAM_LOG_CAP
    mov esi, [seam_log_i]
    mov ecx, SEAM_LOG_CAP
    sub ecx, esi                   ; ECX = CAP - cursor (tail chunk)
    add esi, seam_log
    rep movsb
    mov esi, seam_log              ; head chunk [0, cursor)
    mov ecx, [seam_log_i]
    rep movsb
.staged:

    call zero_rmcs                 ; INT 21h/3Ch — create
    mov word [rmcs + RMCS_EAX], 0x3C00
    mov dword [rmcs + RMCS_EDX], 0
    mov ax, [dos_seg]
    mov [rmcs + RMCS_DS], ax
    call sim_int21
    test byte [rmcs + RMCS_FLAGS], 1
    jnz .free
    mov ax, [rmcs + RMCS_EAX]
    mov [file_handle], ax

    call zero_rmcs                 ; INT 21h/40h — write
    mov word [rmcs + RMCS_EAX], 0x4000
    movzx eax, word [file_handle]
    mov [rmcs + RMCS_EBX], eax
    mov ecx, [seam_out_len]
    mov [rmcs + RMCS_ECX], ecx
    mov dword [rmcs + RMCS_EDX], 0x10
    mov ax, [dos_seg]
    mov [rmcs + RMCS_DS], ax
    call sim_int21

    call zero_rmcs                 ; INT 21h/3Eh — close
    mov word [rmcs + RMCS_EAX], 0x3E00
    movzx eax, word [file_handle]
    mov [rmcs + RMCS_EBX], eax
    call sim_int21
.free:
    mov ax, 0x0101                 ; free DOS buffer
    mov dx, [dos_sel]
    int 0x31
.exit:
    ret
%endif

%ifdef DEBUG_AUTOKEY
; ---------------------------------------------------------------------------
; RunTMHMTest's sibling: RunStoneTest — items-plan Stage 8 (DEBUG_ITEMSTONE).
; Seeds party + bag, makes the target mon a stone-evolver (VULPIX), puts the
; stone in bag slot 0, and drives the real UseItem dispatch into ItemUseEvoStone.
; AUTOKEY_APRESS answers the party menu and every message.
; Overrides: ITEMSTONE_ID (the stone), ITEMSTONE_SPECIES (the target mon's species
; — set it to a non-evolver, e.g. SNORLAX $84, for the "no effect" case).
; Never returns — DebugDumpMemory writes DUMP.BIN and exits.
; ---------------------------------------------------------------------------
%ifdef DEBUG_ITEMSTONE
%ifndef ITEMSTONE_ID
%define ITEMSTONE_ID 0x20               ; FIRE_STONE
%endif
%ifndef ITEMSTONE_SPECIES
%define ITEMSTONE_SPECIES 0x52          ; VULPIX — FIRE_STONE -> NINETALES ($53)
%endif
RunStoneTest:
    mov byte [ebp + wPartyCount], 0
    mov byte [ebp + wPartySpecies], 0xFF
    mov byte [ebp + wNumBagItems], 0
    mov byte [ebp + wBagItems], 0xFF
    call PrepareNewGameDebug
    or byte [ebp + W_FONT_LOADED], (1 << BIT_FONT_LOADED)
    call LoadFontTilePatterns
    call LoadTextBoxTilePatterns
    ; party slot 0 becomes the mon under test (both the species list and the struct)
    mov byte [ebp + wPartySpecies], ITEMSTONE_SPECIES
    mov byte [ebp + wPartyMon1], ITEMSTONE_SPECIES
    ; bag slot 0 = the stone, qty 1 → RemoveItemFromInventory's decision is visible
    mov byte [ebp + wBagItems + 0], ITEMSTONE_ID
    mov byte [ebp + wBagItems + 1], 1
    mov byte [ebp + wWhichPokemon], 0       ; the BAG slot, not the party slot
    mov byte [ebp + wCurItem], ITEMSTONE_ID
%ifdef ITEMSTONE_INBATTLE
    ; Stage 10 (battle items): the five in-battle handlers gate on wIsInBattle and
    ; act on the ACTIVE mon (wPlayerMonNumber). This seeds just enough battle state
    ; to reach them from the overworld harness — it is NOT a real battle, so the
    ; X-stat path's StatModifierUpEffect runs without a battle screen behind it.
    mov byte [ebp + wIsInBattle], 1         ; wild battle
    mov byte [ebp + wPlayerMonNumber], 0
    mov byte [ebp + wPlayerBattleStatus2], 0
    mov byte [ebp + wEscapedFromBattle], 0
    mov byte [ebp + wPlayerMonAttackMod], 7     ; neutral stage — a real InitBattle
                                                ; seeds these; X Attack must take it to 8
    mov byte [ebp + wPartyMon1Status], 3       ; SLP, 3 turns — so POKE_FLUTE $49 has
    mov byte [ebp + wBattleMonStatus], 3       ; something to wake (harmless to the rest)
    mov byte [ebp + wEnemyMonActualCatchRate], 0x2A  ; Safari BAIT/ROCK operate on this
    mov byte [ebp + wSafariBaitFactor], 0            ; (42 -> 21 on bait, 84 on rock)
    mov byte [ebp + wSafariEscapeFactor], 0
%endif
%ifdef ITEMSTONE_CAVERN
    ; B1 (Escape Rope): ItemUseEscapeRope only works on the EscapeRopeTilesets
    ; (FOREST/CEMETERY/CAVERN/FACILITY/INTERIOR). The harness boots into Pallet Town,
    ; whose tileset is OVERWORLD ($00) — NOT on that list — so the success path is
    ; unreachable without this seed. Drive with ITEMSTONE_ID=ESCAPE_ROPE ($1D):
    ; wStatusFlags6 ($D731) must come back with FLY_WARP(3)|ESCAPE_WARP(6) set = $48,
    ; and wActionResultOrTookBattleTurn ($CD6A) = 1. Setting it to 0 instead
    ; (ITEMSTONE_CAVERN absent) exercises the .notUsable refusal.
    ; Results land in the EXISTING windows: wStatusFlags6 is $D700+$31, wStatusFlags4
    ; is $D700+$2D, wEscapedFromBattle is $D062+$15, and the bag is the $D31C window.
    mov byte [ebp + wCurMapTileset], 17     ; CAVERN (assets/map_dims.inc; not %included here)
%endif
    call UseItem
    call DebugDumpMemory                    ; DUMP.BIN (the windows: table above) + exit
%endif ; DEBUG_ITEMSTONE

; ---------------------------------------------------------------------------
; AutoKeyDrive — scripted joypad playback (debug harness).
;
; Called once per rendered frame from vblank.asm, immediately after joypad_update,
; so it OVERRIDES the real keyboard state for that frame. Replays a fixed button
; sequence from autokey_script so a keyboard-driven live path (overworld → START
; → a submenu) can be exercised in a headless DOSBox-X run. hJoyPressed is the
; rising edge of hJoyHeld, computed here the same way joypad_update does.
;
; Script entries are `dd first_frame, last_frame, held_mask` (inclusive range),
; terminated by first_frame = -1. Frames outside every range read as "no keys".
;
; In: EBP = GB base. Preserves all registers.
; ---------------------------------------------------------------------------
%ifndef AUTOKEY_PAD
%define AUTOKEY_PAD PAD_UP
%endif
%ifndef AUTOKEY_DOWNS
%define AUTOKEY_DOWNS 1
%endif
%ifndef AUTOKEY_DUMP_FRAME
%define AUTOKEY_DUMP_FRAME 200
%endif
%ifndef AK_WALK_BASE
%define AK_WALK_BASE 9000               ; AUTOKEY_ROUTE_WALK post-battle walk start
%endif
global AutoKeyDrive
AutoKeyDrive:
    pushad
    mov ecx, [autokey_frame]
    inc dword [autokey_frame]
    cmp ecx, AUTOKEY_DUMP_FRAME
    jne .noDump
    call DumpBackbuffer                 ; FRAME.BIN, then exits
.noDump:
%ifdef AUTOKEY_DUMP_ON_FOLLOW
    ; State-gated follow-stall probe: dump GBSTATE (+FRAME) and exit the FIRST
    ; frame the Pallet cutscene reaches PLAYER_FOLLOWS_OAK (script 7). That is the
    ; exact instant PalletMovementScript_OakMoveLeft reads wXCoord (steps=wXCoord-10),
    ; so this captures the coord it underflows on without needing a fixed frame the
    ; slow A-press battle never reaches deterministically.
%ifndef AUTOKEY_FOLLOW_SCRIPT
%define AUTOKEY_FOLLOW_SCRIPT 7            ; SCRIPT_PALLETTOWN_PLAYER_FOLLOWS_OAK
%endif
%ifdef AUTOKEY_FOLLOW_ON_YMOVE
    ; Pinpoint the exact frame the player's map Y first leaves the north-exit row 0
    ; (the mystery (10,0)->(8,8) teleport), capturing the full engine state.
    cmp byte [ebp + W_Y_COORD], 0
    jne .doFollowDump
    jmp .noFollowDump
%elifdef AUTOKEY_FOLLOW_ON_STEP
    ; Pinpoint the first frame the player begins a walk step (either step vector
    ; non-zero), to capture the joypad/direction driving the unwanted movement.
    cmp byte [ebp + W_SPRITE_PLAYER_Y_STEP_VECTOR], 0
    jne .doFollowDump
    cmp byte [ebp + W_SPRITE_PLAYER_X_STEP_VECTOR], 0
    jne .doFollowDump
    jmp .noFollowDump
%elifdef AUTOKEY_FOLLOW_ON_FLYWARP
    ; Catch the frame the fly/dungeon-warp bit arms (BIT_FLY_WARP=3, BIT_DUNGEON_WARP=4),
    ; which routes OverworldLoop -> HandleFlyWarpOrDungeonWarp -> SpecialEnterMap ->
    ; EnterMapBoot -> SetupPlayerSprite (the hardcoded (8,8) stomp).
    test byte [ebp + W_STATUS_FLAGS_6], (1 << 3) | (1 << 4)
    jnz .doFollowDump
    jmp .noFollowDump
%else
    cmp byte [ebp + wPalletTownCurScript], AUTOKEY_FOLLOW_SCRIPT
    jb .noFollowDump                       ; dump the first frame we REACH the target step
%endif
.doFollowDump:
    call DumpBackbuffer                 ; GBSTATE.BIN + FRAME.BIN, then exits
.noFollowDump:
%endif
%ifdef AUTOKEY_DUMP_ON_BATTLE
    ; State-gated battle photograph (boot-drift-robust, measured 2026-08-06). A
    ; fixed AUTOKEY_DUMP_FRAME lands wherever ~150 frames of boot drift put it, so
    ; it cannot reliably catch the narrow intro-battle window. Instead count frames
    ; while wCurOpponent != 0 (the intro script sets wCurOpponent alongside
    ; wBattleType at PalletTownPikachuBattleScript, and it persists through the
    ; battle until EndOfBattle clears it — so it catches the battle even if the
    ; special path clears wBattleType early) and dump once, AUTOKEY_BATTLE_DUMP_DELAY
    ; frames in — long enough for SlideBattlePicsIn + the intro box to settle.
    cmp byte [ebp + wCurOpponent], 0
    je .noBattleDump
    inc dword [autokey_battle_frame]
    mov eax, [autokey_battle_frame]
    cmp eax, AUTOKEY_BATTLE_DUMP_DELAY
    jne .noBattleDump
    call DumpBackbuffer                 ; FRAME.BIN, then exits
.noBattleDump:
%endif
    xor edx, edx                        ; DL = held mask for this frame
    lea esi, [autokey_script]
.scan:
    mov eax, [esi]
    cmp eax, -1
    je .apply
    cmp ecx, eax
    jl .next
    cmp ecx, [esi + 4]
    jg .next
    or dl, [esi + 8]
.next:
    add esi, 12
    jmp .scan
.apply:
%ifdef AUTOKEY_TRAINER_ROUTE
    ; *** STATE-GATED D-PAD (measured 2026-08-05, two stalled 26000-frame runs). ***
    ; A frame-scheduled D-pad press lands in whatever UI is up. One DOWN that hits
    ; the BATTLE menu (not the move menu) moves its cursor FIGHT -> ITEM, the menu
    ; REMEMBERS it (wBattleAndStartSavedMenuItem), and a D-pad-free press loop can
    ; never move it back: A opens the empty bag, B closes it, forever — the battle
    ; stalls mid-roster at full enemy HP (FRAME.BIN shows the menu parked on ITEM).
    ; The whole point of the DOWNs is the MOVE menu, so let them through ONLY while
    ; it is actually open: in a battle AND the cursor block holds MoveSelectionMenu's
    ; projected coords (.menuset: Y = $C+3 = $0F, X = 5+10 = $0F). Everywhere else —
    ; battle menu, text, and especially the post-battle overworld, where a DOWN
    ; WALKS the player and moves compared coords — they are stripped. The harness
    ; may read WRAM: it is the scenario driver, not game logic, and this keeps the
    ; PRESS SCHEDULE fixed while making its effect state-safe.
    test dl, PAD_UP | PAD_DOWN | PAD_LEFT | PAD_RIGHT
    jz .padOk
%ifdef AUTOKEY_ROUTE_WALK
    ; Bug-B repro gate: the repro walk uses UP/LEFT/RIGHT ONLY, and the cadence's
    ; only D-pad key is DOWN — so on the OVERWORLD (wIsInBattle==0) strip just
    ; the DOWN bit and pass the rest. No frame windows: this is robust against
    ; boot-time frame drift (measured 2026-08-06: boot ate ~73-150 frames, so a
    ; frame-windowed UP at 60 was consumed before the overworld loop was live).
    ; In-battle frames fall through to the move-menu-only gate below unchanged,
    ; so the cursor DOWNs keep working and a walk press cannot hit a menu.
    cmp byte [ebp + wIsInBattle], 0
    jne .routeWalkNo
    and dl, ~PAD_DOWN & 0xFF            ; overworld: cadence DOWN out, walk dirs pass
    jmp .padOk
.routeWalkNo:
%endif
    cmp byte [ebp + wIsInBattle], 2
    jne .stripPad
    cmp byte [ebp + wTopMenuItemY], 0x0F
    jne .stripPad
    cmp byte [ebp + wTopMenuItemX], 0x0F
    je .padOk
.stripPad:
    and dl, ~(PAD_UP | PAD_DOWN | PAD_LEFT | PAD_RIGHT) & 0xFF
.padOk:
%endif
    mov al, [autokey_prev]
    not al
    and al, dl                          ; pressed = held & ~prev
    mov [ebp + H_JOY_PRESSED], al
    mov [ebp + H_JOY_HELD], dl
    mov [autokey_prev], dl
    popad
    ret

section .data
autokey_frame: dd 0
%ifdef AUTOKEY_DUMP_ON_BATTLE
align 4
autokey_battle_frame: dd 0             ; frames counted while wBattleType != 0
%endif
autokey_prev:  db 0
align 4
; START opens the menu; DOWN moves POKéDEX → POKéMON; A selects it.
; The gaps are release frames (the menu code spins until the button is let go).
autokey_script:
%ifdef AUTOKEY_QUIET
    ; No presses, ever — the harness only wants AutoKeyDrive's AUTOKEY_DUMP_FRAME
    ; timer, so a screen that parks in its own key-wait loop (e.g. DEBUG_LISTMENU_QTY's
    ; DisplayChooseQuantityMenu) can be photographed mid-wait instead of run to a
    ; DumpBackbuffer the routine never reaches.
    dd  -1,  -1, 0
%elifdef AUTOKEY_CHOOSENAME
    ; menu-intro A4.5f (DEBUG_CHOOSENAME): after the pic fade (~60 frames) and the
    ; ChoosePlayerName slide-out, the default-name menu is up. DOWN moves the cursor
    ; NEW NAME -> YELLOW, A selects it (GetDefaultName + slide-in + "YOUR NAME IS ...").
    dd 110, 118, PAD_DOWN
    dd 135, 143, PAD_A
    dd  -1,  -1, 0
%elifdef AUTOKEY_CHOOSENAME_CUSTOM
    ; menu-intro A4.5f custom path (DEBUG_CHOOSENAME CHOOSENAME_CUSTOM=1): A picks the
    ; name menu's item 0 (NEW NAME) -> DisplayNamingScreen; A enters the cursor's first
    ; letter (grid starts on 'A'); START submits (.pressedStart). ChoosePlayerName then
    ; re-establishes the surface (MovieBeginSurface) and shows the pic + "YOUR NAME IS".
    dd 110, 118, PAD_A          ; name menu: select NEW NAME
    dd 160, 168, PAD_A          ; naming grid: enter the letter under the cursor
    dd 195, 203, PAD_START      ; submit the name
    dd  -1,  -1, 0
%elifdef AUTOKEY_SEAM
    ; DEBUG_SEAM_LIVE companion: hold AUTOKEY_PAD (default PAD_UP) into the seeded
    ; map's edge with LIVE collision, then press A so SeamLogRecord writes
    ; SEAMLOG.BIN + FRAME.BIN. This is the harness that reproduced the Viridian
    ; Forest "stuck at the gate spawn" bug headlessly.
%ifdef AUTOKEY_MENU_FIRST
    ; open + close the START menu before the walk: reproduces a live session that
    ; verified the menus and then went talking to NPCs (font/VRAM state cycled).
    dd  30,  36, PAD_START
    dd  70,  76, PAD_B
%define AK_SHIFT 90
%else
%define AK_SHIFT 0
%endif
%ifdef AUTOKEY_JOG_RIGHT
    ; hold AUTOKEY_PAD, sidestep one tile right, resume — some warp tiles are not
    ; the tile you arrive on (Viridian Forest South Gate: (4,0) is wall, (5,0) warps)
    dd  30 + AK_SHIFT, 120 + AK_SHIFT, AUTOKEY_PAD
    dd 140 + AK_SHIFT, 155 + AK_SHIFT, PAD_RIGHT
    dd 175 + AK_SHIFT, 400 + AK_SHIFT, AUTOKEY_PAD
%else
    dd  30 + AK_SHIFT, 400 + AK_SHIFT, AUTOKEY_PAD
%endif
    dd 430 + AK_SHIFT, 436 + AK_SHIFT, PAD_A
    ; Extra A presses: page through / dismiss a multi-page NPC dialog reached at
    ; the end of the walk (forest youngster repro). Harmless in the logged
    ; variant — the first A press dumps and exits before these fire.
    dd 490 + AK_SHIFT, 496 + AK_SHIFT, PAD_A
    dd 550 + AK_SHIFT, 556 + AK_SHIFT, PAD_A
    dd 610 + AK_SHIFT, 616 + AK_SHIFT, PAD_A
    dd 670 + AK_SHIFT, 676 + AK_SHIFT, PAD_A
    dd  -1,  -1, 0
%elifdef AUTOKEY_TALK
    ; NPC-dialog crash repro: with a DEBUG_START_MAP spawn placed a couple of
    ; tiles below an NPC, walk up into it (collision stops the player adjacent,
    ; facing up), then press A repeatedly to open and page through the dialog.
    ; Reaching AUTOKEY_DUMP_FRAME (default 200 — override to 450 for this
    ; script) proves the dialog survived; a crash leaves no FRAME.BIN.
    dd  30,  90, PAD_UP
    dd 120, 126, PAD_A
    dd 180, 186, PAD_A
    dd 240, 246, PAD_A
    dd 300, 306, PAD_A
    dd 360, 366, PAD_A
    dd  -1,  -1, 0
%elifdef AUTOKEY_TITLE
    ; Boot path with the title screen: pulse A through the title + main menu
    ; (NEW GAME) + any intro text, then open START and pick a submenu.
%assign AK_T 60
%rep 12
    dd  AK_T, AK_T + 5, PAD_A
%assign AK_T AK_T + 30
%endrep
    dd 480, 486, PAD_START
%assign AK_I 0
%rep AUTOKEY_DOWNS
    dd  510 + AK_I * 30,  516 + AK_I * 30, PAD_DOWN
%assign AK_I AK_I + 1
%endrep
    dd  510 + AUTOKEY_DOWNS * 30, 516 + AUTOKEY_DOWNS * 30, PAD_A
    dd  -1,  -1, 0
%elifdef AUTOKEY_CONTINUE_WALK
    ; Oak-cutscene-from-save repro (2026-08-06): FULL boot (no SKIP_TITLE),
    ; pulse A through the title + main menu — with a save present CONTINUE is
    ; the default item, so the pulses select and confirm it — then hold UP so
    ; the loaded player walks north into PalletTownDefaultScript's y=0 trigger.
    ; Run with AUTOKEY_NO_PARTY=1 (the debug party seed must not contaminate
    ; the state the save restored) and AUTOKEY_DUMP_FRAME past the text.
    ; START pulses first — the title advances on START (A is the cry easter
    ; egg); then A pulses select+confirm CONTINUE on the main menu.
%assign AK_T 60
%rep 8
    dd  AK_T, AK_T + 5, PAD_START
%assign AK_T AK_T + 60
%endrep
%assign AK_T 600
%rep 8
    dd  AK_T, AK_T + 5, PAD_A
%assign AK_T AK_T + 30
%endrep
%ifdef AK_CONTINUE_MENU_FIRST
    ; Suspect-isolation leg (OW-A.13 family): cycle the START menu open/closed
    ; after the load, BEFORE the walk — reproduces a session that browsed menus
    ; and then triggered the Oak cutscene (font/VRAM/auto-BG state cycled).
    dd  700,  708, PAD_START
    dd  800,  808, PAD_B
%endif
    ; walk north to the treeline, then STAIRCASE east along it (single RIGHT
    ; tap + UP hold, repeated): the first pair aligned with the x=9-11 north
    ; gap walks north automatically, so the approach cannot overshoot (a held
    ; RIGHT is ~11 steps and slid under the gap — measured on iteration 2).
    dd  900, 1260, PAD_UP
%assign AK_W 1320
%rep 11
    dd  AK_W,      AK_W + 12, PAD_RIGHT
    dd  AK_W + 32, AK_W + 80, PAD_UP
%assign AK_W AK_W + 90
%endrep
    dd 2350, 2800, PAD_UP
    ; dismiss the "OAK: Hey! Wait! / Don't go out!" text (its two pages), then
    ; idle so the cutscene's next beats (ShowObject + Oak's walk) can run before
    ; the dump. Verifies the CloseTextDisplay hide_window fix: no stale glyph
    ; window may survive the close, and Oak must appear.
    dd 3600, 3612, PAD_A
    dd 3760, 3772, PAD_A
    dd 3920, 3932, PAD_A
    dd  -1,  -1, 0
%elifdef AUTOKEY_APRESS
    ; Nothing to navigate: answer every <PROMPT> / button wait the flow raises.
    ; DEBUG_ITEMBALL alone uses B so the live AskName prompt deterministically
    ; declines the nickname; TM/stone/sign flows require affirmative A presses.
    ; Keep the train long: a flow that outlives it blocks forever on the next
    ; prompt (the harness has no other input source) and reads as a hang.
    ; AUTOKEY_APRESS_COUNT overrides the length for a flow that needs a longer
    ; train; the last press lands at frame 30 + (COUNT-1)*20 + 5, and every
    ; frame after that reads as "no keys" for the rest of the run.
%ifndef AUTOKEY_APRESS_COUNT
%define AUTOKEY_APRESS_COUNT 300
%endif
%assign AK_A 30
%rep AUTOKEY_APRESS_COUNT
%ifdef DEBUG_ITEMBALL
    dd AK_A, AK_A + 5, PAD_B
%else
    dd AK_A, AK_A + 5, PAD_A
%endif
%assign AK_A AK_A + 20
%endrep
    dd  -1,  -1, 0
%elifdef AUTOKEY_ITEMUSE
    ; items-plan Stage 5 (DEBUG_ITEMUSE): drive the real bag USE path twice.
    ;   START → DOWN DOWN → A          : open the START menu, pick ITEM
    ;   A → A                          : select bag slot 1 (POTION, qty 1) → USE
    ;   A                              : party menu → mon 1 (Snorlax, seeded to 1 HP)
    ;   A                              : dismiss "SNORLAX recovered by N!"
    ; then the bag is back with POTION consumed, so slot 1 is now ANTIDOTE:
    ;   A → A → A                      : ANTIDOTE → USE → mon 1 (no status) → refusal
    ; Pick the moment to look at with AUTOKEY_DUMP_FRAME (380 = the heal message,
    ; 620 = the refusal, 700 = the bag list with POTION gone).
    dd  60,  66, PAD_START
    dd 100, 106, PAD_DOWN
    dd 140, 146, PAD_DOWN
    dd 180, 186, PAD_A          ; ITEM
    dd 220, 226, PAD_A          ; POTION → USE/TOSS submenu
    dd 260, 266, PAD_A          ; USE
    dd 340, 346, PAD_A          ; party menu: mon 1
    dd 420, 426, PAD_A          ; dismiss the heal message
    dd 500, 506, PAD_A          ; ANTIDOTE → USE/TOSS submenu
    dd 540, 546, PAD_A          ; USE
    dd 600, 606, PAD_A          ; party menu: mon 1 (healthy → refusal)
    dd 660, 666, PAD_A          ; dismiss the refusal
    dd  -1,  -1, 0
%elifdef AUTOKEY_SURF
    ; items-plan Stage 11 (DEBUG_SURF): drive the real overworld loop through a
    ; complete surf round trip. The player spawns at Pallet (14,5) facing the water.
    ;   DOWN                : bump into the water. Blocked by CollisionCheckOnLand,
    ;                         but the check POPULATES wTileInFrontOfPlayer, which is
    ;                         what ItemUseSurfboard reads (it never recomputes it).
    ;   START -> DOWN DOWN -> A : open the START menu, pick ITEM
    ;   A -> A              : bag slot 0 (SURFBOARD) -> USE
    ;   A                   : dismiss "RED got on / ?????!" — mount done
    ;   B -> B              : close the bag, close the START menu. MEASURED, not
    ;                         assumed: at frame 480 the mount text is up over the
    ;                         overworld, and by 620 the BAG LIST HAS REDRAWN — using
    ;                         an item returns to the item list, it does not drop you
    ;                         into the overworld. The first cut of this script omitted
    ;                         these two B presses, so the second pass's START/DOWN
    ;                         presses went into the still-open bag and moved its
    ;                         cursor instead. The simulated DOWN step armed by
    ;                         .makePlayerMoveForward only runs once the overworld loop
    ;                         is running again, i.e. after these.
    ;   LEFT                : ONE surf step onto the SHORE tile (15,4). The shore tile
    ;                         KEEPS the surf state (IsNextTileShoreOrWater returns
    ;                         carry for $32), which is the only way to end up surfing
    ;                         while adjacent to passable land — moving toward plain
    ;                         land auto-dismounts in CollisionCheckOnWater.
    ;                         HOLD LENGTH IS LOAD-BEARING: measured at ~17 frames per
    ;                         surf step, so the first cut's 70-frame hold walked four
    ;                         steps to x=1 and auto-dismounted on the way (GBSTATE at
    ;                         frame 900 read x=1, wWalkBikeSurfState=0). 12 frames is
    ;                         one step.
    ;   A                   : interaction check against the land tile ahead. This is
    ;                         what makes the DISMOUNT branch reachable at all:
    ;                         ItemUseSurfboard reads wTileInFrontOfPlayer STALE, and
    ;                         after the step onto (15,4) that byte still holds $32
    ;                         (the shore tile just moved onto), which IsTilePassable
    ;                         rejects -> "no place to get off". Pressing A runs
    ;                         GetTileAndCoordsInFrontOfPlayer, refreshing it to
    ;                         (15,3) = $2C, which IS in Overworld_Coll. There is no
    ;                         sign or NPC there, so the press does nothing else.
    ;   START -> A -> A -> A : bag again -> SURFBOARD -> USE = DISMOUNT. NOTE the
    ;                         missing DOWNs: the START menu REMEMBERS its cursor, so
    ;                         it reopens already on ITEM. Measured — the first cut
    ;                         repeated the two DOWNs and landed on SAVE (index 2 + 2
    ;                         = 4), and frame 1220 photographed "Would you like to
    ;                         SAVE the game?" instead of the bag.
    ;   ...and STOP THERE — the dismount prints nothing.
    ;
    ; WHY THE SCRIPT ENDS WITH THE BAG STILL OPEN. The dismount arms a simulated
    ; LEFT step the same way the mount arms a simulated DOWN, but it ALSO sets
    ; wJoyIgnore = $FF, and the port has no JoypadOverworld yet, so nothing clears
    ; that byte, and with the menus closed the armed step is never consumed: measured,
    ; the port sits at (15,4) with wSimulatedJoypadStatesIndex = 1 and
    ; wJoyIgnore = $FF at frames 1180, 1440 AND 1800 — stuck, not slow. What the real
    ; game does there was not measured, and the simulated-input consumer is
    ; overworld-events' to own either way, so the scenario stops with the bag still
    ; open: both sides then have the step armed and unconsumed, and the compared bytes
    ; are exactly what ItemUseSurfboard itself wrote. The MOUNT's step IS consumed on
    ; both sides and is compared. Tracked in docs/current_plan_backlog.md.
    ; Cadence: 60-frame gaps with 10-frame holds — the spacing AUTOKEY_BILLSPC
    ; settled on after tighter gaps had presses eaten mid-draw.
    dd   60,   70, PAD_DOWN     ; bump: populate wTileInFrontOfPlayer
    dd  150,  160, PAD_START
    dd  210,  220, PAD_DOWN     ; POKéDEX -> POKéMON
    dd  270,  280, PAD_DOWN     ; -> ITEM
    dd  330,  340, PAD_A        ; ITEM
    dd  390,  400, PAD_A        ; SURFBOARD -> USE/TOSS
    dd  450,  460, PAD_A        ; USE -> mount
    dd  530,  540, PAD_A        ; dismiss "RED got on / ?????!"
    dd  600,  610, PAD_B        ; close the bag
    dd  660,  670, PAD_B        ; close the START menu -> overworld; the armed
                                ; simulated DOWN step runs here
    dd  780,  792, PAD_LEFT     ; ONE surf step onto the shore tile (15,4)
    dd  860,  870, PAD_A        ; refresh wTileInFrontOfPlayer to (15,3) = $2C
    dd  930,  940, PAD_START
    dd  990, 1000, PAD_A        ; ITEM (cursor already there — see the note above)
    dd 1050, 1060, PAD_A        ; SURFBOARD -> USE/TOSS
    dd 1110, 1120, PAD_A        ; USE -> dismount. The script ENDS here: .stopSurfing
                                ; prints no message (the only dismount text,
                                ; SurfingNoPlaceToGetOffText, is the failure branch),
                                ; so there is nothing to dismiss and a stray A would
                                ; just reopen the USE/TOSS box.
    dd   -1,   -1, 0
%elifdef AUTOKEY_LEDGE
    ; Ledge-hop round trip (regression-overworld-ledge-hop-never-advanced): the
    ; player spawns at Route 1 (8,7), standing tile $2C, ledge tile $37 below.
    ;   DOWN  : real press into the ledge. CollisionCheckOnLand →
    ;           CheckForJumpingAndTilePairCollisions → HandleLedges arms the hop
    ;           (BIT_LEDGE_OR_FISHING, wJoyIgnore=$FF, two simulated DOWN steps).
    ;           The hop then runs itself: AreInputsSimulated feeds the steps,
    ;           HandleMidJump advances the 16-entry arc each loop iteration and
    ;           tears everything down when the second step lands on (10,7).
    ;           Two steps ≈ 32 frames + Delay3 — done well before frame 240.
    ;   DOWN  : post-teardown NORMAL step to (11,7). This is the detector: with
    ;           the teardown missing (the regression), wJoyIgnore is still $FF,
    ;           the press is swallowed, and wYCoord stays 10 ≠ the golden's 11.
    ; 12-frame holds (one walk step; same measurement as AUTOKEY_SURF's LEFT).
    ; AK_LEDGE_SHIFT delays the whole script (debug-attach aid, like
    ; BILLSPC_ATTACH_DELAY) — never set for a golden run.
%ifndef AK_LEDGE_SHIFT
%define AK_LEDGE_SHIFT 0
%endif
    dd   60 + AK_LEDGE_SHIFT,   72 + AK_LEDGE_SHIFT, PAD_DOWN ; arm the hop; the loop plays it out
    dd  300 + AK_LEDGE_SHIFT,  312 + AK_LEDGE_SHIFT, PAD_DOWN ; post-teardown step — proves input is back
    dd   -1,   -1, 0
%elifdef AUTOKEY_TRAINER_ROUTE
    ; Continuous trainer route (DEBUG_TRAINER_ROUTE, battle plan Stage 1b).
    ;
    ; *** READ ORDER (2026-08-05): the prose between here and the "CADENCE
    ; REDESIGN" banner below documents the RETIRED two-phase designs (B,B,A;
    ; B,A,A + bounded DOWN phase) and their measured deadlocks. It is kept as
    ; the record of WHY the current design is shaped the way it is — its
    ; directives (e.g. "KEEP PHASE 1 SHORT") no longer apply. The CURRENT
    ; cadence and its rules live at the banner; the D-pad state gate lives at
    ; AutoKeyDrive.apply. ***
    ;
    ; This script does NOT drive the encounter — the map script does, on its own,
    ; from the first frame, because the player spawns inside the youngster's line
    ; of sight. All this script does is ANSWER: the pre-battle text, the battle
    ; menu, the move menu, and the end-of-battle text. That division is the point
    ; of the scenario: every state transition is the game's, not the harness's.
    ;
    ; The engage sequence before the player can act is long — emotion bubble,
    ; TrainerWalkUpToPlayer's step, the pre-battle text stream, then the battle
    ; intro and send-out — so the presses are spread wide and repeated rather than
    ; timed to individual screens. A press that lands on nothing is harmless here:
    ; A on the overworld with no dialog opens nothing (the spawn tile faces no
    ; sign or NPC), and A on a text prompt just advances it.
    ;
    ; FIGHT is the battle menu's default cursor position, so A selects it without
    ; any D-pad movement; the move menu then opens on move slot 0. The debug
    ; party's lead is the L80 mon whose STRENGTH one-shots this trainer's roster
    ; (the same contract 45/46 rely on), and wPlayerMoveListIndex is left at its
    ; natural default rather than forced — the point is to prove the live menu
    ; path works, and any of the lead's moves overkills a Route 3 bug catcher.
    ;
    ; Cadence: 10-frame holds with wide gaps (the AUTOKEY_SURF/FISH spacing).
    ; Three roster mons means three FIGHT+move cycles plus their send-out text.
    ; AK_ROUTE_SHIFT delays the whole script (debug-attach aid, like
    ; AK_LEDGE_SHIFT) — never set for a golden run.
%ifndef AK_ROUTE_SHIFT
%define AK_ROUTE_SHIFT 0
%endif
    ; MEASURED 2026-08-04 on the golden side, and it applies identically here: a
    ; live trainer battle CANNOT be driven by pressing A alone. When the trainer
    ; sends out its next mon, Gen 1 asks "will <PLAYER> change POKEMON?" YES/NO,
    ; and an A press answers YES and parks in the party menu. The mGBA run that
    ; did that killed the first roster mon and then sat in the party menu for
    ; 29000 frames until the frame cap. B is the key that gets back to the battle
    ; menu from anywhere: it advances ordinary text AND answers NO.
    ;
    ; The golden side can watch the tilemap and react; AutoKeyDrive is
    ; frame-scheduled and cannot. So instead of a fixed press list timed to
    ; individual screens -- which cannot survive a battle whose length varies with
    ; the damage rolls -- this emits a REPEATING B,A,A cadence for the whole run.
    ; One B clears whatever prompt is up (including the switch question), then TWO
    ; A presses make the two selections a turn actually costs.
    ;
    ; *** THE CADENCE WAS B,B,A AND IT DEADLOCKED. Do not "simplify" it back. ***
    ; MEASURED 2026-08-05 (FRAME.BIN at AUTOKEY_DUMP_FRAME=15000): the port sat in
    ; the MOVE menu with 0 EXP gained, 0 PP spent and wIsInBattle still $02 at the
    ; dump. Reaching a move costs TWO A presses -- A on the battle menu opens the
    ; move menu, A on the move menu commits -- but B,B,A supplies only one per
    ; 90-frame cycle. The A opened the move menu and the NEXT cycle's B cancelled
    ; it 30 frames later, forever: the battle never took a turn. The old comment
    ; here asserted one A made "the selection the battle menu is sitting on (FIGHT,
    ; then the move)", which silently treats two menu levels as one.
    ; The cycle repeats often enough that a turn always makes progress and a stray
    ; press lands somewhere harmless.
    ;
    ; 90-frame cycle from frame 240; AK_ROUTE_CYCLES covers the whole battle with
    ; margin (the mGBA reference run finished its battle by frame ~12000).
    ; *** THE PORT MUST SELECT THE SAME MOVE THE GOLDEN DOES. ***
    ; MEASURED 2026-08-05: the golden's Lua picks FIGHT then STRENGTH BY NAME
    ; (trainer_battle_route.lua: navigate.choose(STRENGTH)); a frame-scheduled
    ; autokey cannot read the tilemap, so plain A took the move menu's default,
    ; slot 0 = FLY. FLY is a two-turn charge move ("SNORLAX FLEW UP HIGH!" in the
    ; frame-15000 capture), so the battle crawled -- and because PP is part of the
    ; compared surface, port PP1 vs golden PP4 could never agree anyway.
    ; STRENGTH is move index 3 in the debug party (the same contract scenarios
    ; 45/46 encode by seeding wPlayerMoveListIndex = 3).
    ;
    ; PHASE 1 (below) adds DOWN,DOWN,DOWN before the committing A, which walks the
    ; move cursor to slot 3. Two facts make that robust rather than fragile:
    ;   * the cursor PERSISTS across turns -- MoveSelectionMenu seeds
    ;     wCurrentMenuItem from wPlayerMoveListIndex + 1 -- so once turn 1 commits
    ;     STRENGTH, every later move menu already opens on it; and
    ;   * the move menu does NOT wrap (HandleMenuInput clears wMenuWrappingEnabled
    ;     on every exit, src/home/window.asm; only the party menu sets it), so DOWN
    ;     at the last item is a no-op and DOWN x3 is IDEMPOTENT.
    ; InitBattle resets wPlayerMoveListIndex to 0 (init_battle.asm), which is why
    ; the index cannot simply be seeded at scenario setup the way 45/46 seed it.
    ;
    ; PHASE 2 drops the D-pad entirely. This is deliberate and load-bearing: after
    ; the battle the player is back on the overworld, where a DOWN press WALKS HIM,
    ; and wPlayerMapPos is a compared field. Phase 1 is bounded to the early frames
    ; that contain turn 1; phase 2 carries the rest of the battle on B,A,A.
    ; *** KEEP PHASE 1 SHORT. A D-PAD PRESS AFTER THE BATTLE RE-SEEDS THE RUN. ***
    ; MEASURED 2026-08-05: with phase 1 running to frame 4560, the frame-15000 dump
    ; came back with EXP at its seeded 640000, PP back at full, HP full and
    ; wRoute3Event cleared -- which reads like a lost battle and is not one. Once
    ; the battle ends the player is back on the overworld, the leftover DOWN presses
    ; WALK him, and a map transition re-enters EnterMap -> RunTrainerRouteTestSeed,
    ; which re-seeds the party and clears the very flags the scenario is there to
    ; prove. The battle itself was fine: the frame-900 capture shows
    ; "SNORLAX USED STRENGTH!".
    ; So phase 1 covers turn 1 ONLY. The cursor persists from there (see above), so
    ; nothing later needs the D-pad.
    ; *** CADENCE REDESIGN 2026-08-05 — ONE uniform cycle, NO B, gated D-pad. ***
    ; The two-phase design above this comment (bounded DOWN phase + B,A,A tail) is
    ; retired after two measured deterministic stalls:
    ;   * run 1 (26000f): stalled on roster mon 3, enemy at FULL HP, FLY charge
    ;     text on screen — turn-1 alignment had missed the move menu, the cursor
    ;     opened on slot 0 = FLY every turn.
    ;   * run 2 (26000f, after the send-out text/pic fix shifted frame counts):
    ;     stalled on mon 2 with the BATTLE menu parked on ITEM — a phase-1 DOWN
    ;     had hit the battle menu, and the D-pad-free tail could never move the
    ;     remembered cursor back to FIGHT (A opened the empty bag, B closed it,
    ;     forever).
    ; Two structural changes kill both stall classes:
    ;   1. NO B PRESSES. B exists to answer the golden side's "will <PLAYER>
    ;      change POKEMON?" prompt — but the golden is Lua-driven, not autokey,
    ;      and the PORT never shows that prompt (EnemySendOutFirstMon forces
    ;      wCurrentMenuItem=1, the switch flow is deferred). The port-side B's
    ;      only real effect was CANCELLING a just-opened move menu whenever the
    ;      cycle phase-locked with the battle rhythm (the same family as the
    ;      measured B,B,A deadlock above). With no cancel key in the script, menu
    ;      progress is monotone.
    ;   2. D-PAD IN EVERY CYCLE, GATED BY STATE. AutoKeyDrive.apply strips D-pad
    ;      bits unless the MOVE menu is actually open (wIsInBattle==2 and the
    ;      cursor block holds .menuset's projected Y/X = $0F/$0F — see the gate).
    ;      So the DOWNs fire exactly when they mean something (walking the cursor
    ;      to STRENGTH, idempotent at the list bottom, wPlayerMoveListIndex
    ;      persists the slot across turns), and NEVER hit the battle menu or walk
    ;      the player after the battle. The old phase-1 bound existed only for
    ;      the post-battle walk hazard; the gate retires it, so every cycle can
    ;      carry the DOWNs and turn-1 alignment stops being luck.
    ; Cycle (120 frames): A@0 (advance text / open FIGHT / commit move),
    ; DOWN@30/48/66 (gated), A@96 (commit when the menu opened mid-cycle).
%ifndef AK_ROUTE_CYCLES
%define AK_ROUTE_CYCLES 220             ; 240 + 220*120 = 26640 — past the default dump
%endif
%assign ak_i 0
%rep AK_ROUTE_CYCLES
    dd 240 + AK_ROUTE_SHIFT + ak_i * 120, 248 + AK_ROUTE_SHIFT + ak_i * 120, PAD_A
    dd 270 + AK_ROUTE_SHIFT + ak_i * 120, 278 + AK_ROUTE_SHIFT + ak_i * 120, PAD_DOWN
    dd 288 + AK_ROUTE_SHIFT + ak_i * 120, 296 + AK_ROUTE_SHIFT + ak_i * 120, PAD_DOWN
    dd 306 + AK_ROUTE_SHIFT + ak_i * 120, 314 + AK_ROUTE_SHIFT + ak_i * 120, PAD_DOWN
    dd 336 + AK_ROUTE_SHIFT + ak_i * 120, 344 + AK_ROUTE_SHIFT + ak_i * 120, PAD_A
%assign ak_i ak_i + 1
%endrep
%ifdef AUTOKEY_ROUTE_WALK
    ; Bug-B repro walk (2026-08-06, regression-battle-second-trainer-wont-engage).
    ; Requires PILOT_NEUTRAL (spawn (13,8), out of every sight line) so the battle
    ; is fought at a tile != the EnterMap re-seed target — that is what arms the
    ; post-battle teleport that desyncs every surviving NPC screen coordinate
    ; (InitSprites is pret-faithfully SKIPPED on battle return, so sprite state
    ; survives; pret's invariant "the player cannot have moved" is what the
    ; unguarded DEBUG_TRAINER_ROUTE re-seed violates).
    ;
    ; Pre-battle: (13,8) -> LEFT,LEFT -> (11,8) -> UP,UP -> (11,6), inside
    ; ROUTE3_YOUNGSTER1's RIGHT sight line (x=11-12 @ y=6, range 2) — the same
    ; tile the maintainer's live battle 1 was fought on. ROUTE MEASURED FROM THE
    ; LIVE TILEMAP (2026-08-06): the y=8 road's only passable northern gap is
    ; x=11 (tile $3C; x=12..16 are all tree $37), so UP from x=13 or x=14 no-ops
    ; — two earlier schedules proved that empirically. Engagement fires on
    ; arrival; the normal cadence answers the battle. First entry at 400 — past
    ; the measured worst-case boot (~150 frames); the overworld DOWN-strip in
    ; the gate makes exact placement non-critical.
    dd  400,  412, PAD_LEFT
    dd  520,  532, PAD_LEFT
    dd  640,  652, PAD_UP
    dd  760,  772, PAD_UP
    ; Post-battle: with the one-shot seed guard the player STAYS at the battle
    ; tile (11,6) — pret's sprites-survive-battle invariant restored — so the
    ; second-trainer test is a straight walk EAST along the y=6 row
    ; (maintainer-verified walkable end to end): RIGHT,RIGHT,RIGHT to (14,6),
    ; squarely inside ROUTE3_YOUNGSTER2's DOWN sight line (x=14, y=5-7, range
    ; 3), then STAND. Beaten trainer 0's line at (12,6) is crossed en route;
    ; his set flag makes the scan skip him. VERDICT via dosbox-mcp breakpoints:
    ;   * .engaging for sprite 3 promptly on arrival = bug B fixed (the
    ;     wFontLoaded battle-exit clear keeps NPC ticks alive, coords stay
    ;     true, no reload needed);
    ;   * anything else = read slot 3 data1 and wFontLoaded and keep digging.
    ; Run with AK_ROUTE_CYCLES=72 so the cadence is done (8880) before this.
    ; (AK_WALK_BASE default lives with the other AUTOKEY defaults above
    ;  AutoKeyDrive — the gate code uses it first, and NASM is single-pass.)
    dd AK_WALK_BASE      , AK_WALK_BASE +  12, PAD_RIGHT
    dd AK_WALK_BASE + 120, AK_WALK_BASE + 132, PAD_RIGHT
    dd AK_WALK_BASE + 240, AK_WALK_BASE + 252, PAD_RIGHT
%endif
    dd   -1,   -1, 0
%elifdef AUTOKEY_FISH
    ; items-plan Stage 11 (DEBUG_FISH): two OLD ROD uses through the real bag UI.
    ; Spawn is the DEBUG_SURF tile — Pallet (14,5) facing the water at (15,5).
    ;
    ; USE 1 — FishingInit FAILURE. wTileInFrontOfPlayer still holds its boot
    ; value 0 (nothing has bumped yet), IsNextTileShoreOrWater rejects it, and
    ; the handler takes `jp c, ItemUseNotTime` ("OAK: <PLAYER>! This isn't the
    ; time to use that!" — prompt, needs an A).
    ;   START -> DOWN DOWN -> A : open the START menu, pick ITEM
    ;   A -> A                  : bag slot 0 (OLD ROD) -> USE/TOSS -> USE
    ;   A                       : dismiss the NotTime prompt -> back in the bag
    ;   B -> B                  : close the bag, close the START menu
    ; USE 2 — the deterministic bite (ItemUseOldRod has NO RNG: MAGIKARP lv 5).
    ;   DOWN                    : bump into the water — the collision check
    ;                             populates wTileInFrontOfPlayer = $14 (the same
    ;                             stale-byte contract AUTOKEY_SURF pins)
    ;   START -> A              : reopen; the START menu remembers ITEM
    ;   A -> A                  : OLD ROD -> USE/TOSS -> USE. FishingInit prints
    ;                             "used OLD ROD!" (text_end, no prompt), delays
    ;                             80f; FishingAnim: 10f + rod gfx + 100f wait +
    ;                             shake + the real "!" EmotionBubble, then
    ;                             ItsABiteText prompts.
    ;   A (late)                : dismiss ItsABiteText -> back in the bag
    ; ...and STOP with the bag open: wCurOpponent is armed, closing the menus
    ; would start the wild battle (owned by the battle scenarios).
    ; Cadence: 60-frame gaps, 10-frame holds (the AUTOKEY_SURF spacing).
    ; The UP turn mirrors the golden: on GB the START press refreshes
    ; wTileInFrontOfPlayer for the CURRENT facing (pret .displayDialogue), so
    ; the golden must not face the water during the failure use. The port's
    ; byte just holds boot-0 (same outcome). 2-FRAME hold: (13,5) is passable
    ; (measured — a 6-frame hold outlived the turn-delay and walked), so the
    ; press must be a pure turn tap.
    dd   60,   62, PAD_UP       ; turn-only: face away from the water
    dd  130,  140, PAD_START
    dd  190,  200, PAD_DOWN     ; POKéDEX -> POKéMON
    dd  250,  260, PAD_DOWN     ; -> ITEM
    dd  310,  320, PAD_A        ; ITEM
    dd  370,  380, PAD_A        ; OLD ROD -> USE/TOSS
    dd  430,  440, PAD_A        ; USE -> FishingInit fails (front tile not water)
    ; ItemUseNotTimeText is THREE lines (text/line/cont) — a mid-text ▼ page
    ; plus the final prompt = TWO A presses. The first cut sent one, so the B
    ; pair below was eaten by the dialog + bag and the START menu was still
    ; open when the DOWN taps arrived (measured: FRAME.BIN at 480/1900).
    dd  510,  520, PAD_A        ; advance the ▼ page
    dd  580,  590, PAD_A        ; dismiss the final prompt -> bag redraws
    dd  650,  660, PAD_B        ; close the bag
    dd  710,  720, PAD_B        ; close the START menu
    dd  780,  786, PAD_DOWN     ; turn back + first blocked bump (6f hold: the
                                ; turn consumes iteration 1, the held press then
                                ; bumps the water and writes $14)
    dd  850,  860, PAD_DOWN     ; second bump — belt and braces
    dd  920,  930, PAD_START
    dd  980,  990, PAD_A        ; ITEM (cursor remembered)
    dd 1040, 1050, PAD_A        ; OLD ROD -> USE/TOSS
    dd 1100, 1110, PAD_A        ; USE -> "used OLD ROD!" + 80f + FishingAnim
    dd 1650, 1660, PAD_A        ; dismiss ItsABiteText (after ~100f wait + shake
                                ; + bubble; generous — the prompt blinks until A)
    dd   -1,   -1, 0
%elifdef AUTOKEY_BILLSPC
    ; sram-plan stage 6 (DEBUG_BILLSPC): drive the real Bill's PC box UI.
    ; RunBillsPCTest opened BillsPC_ as a generic-PC guest, so the six-entry
    ; menu (0 WITHDRAW / 1 DEPOSIT / 2 RELEASE / 3 CHANGE BOX / 4 PRINT BOX /
    ; 5 SEE YA!) is up almost immediately. Seeded party order (debug_party.asm):
    ; 0 SNORLAX, 1 PERSIAN, 2 JIGGLYPUFF, 3 STARTER_PIKACHU, 4 CHARIZARD,
    ; 5 LAPRAS — the script only ever touches PERSIAN and JIGGLYPUFF, so no
    ; starter-Pikachu branch fires on either side of the golden.
    ;   deposit PERSIAN → deposit JIGGLYPUFF → withdraw PERSIAN (the
    ;   44B→33B→44B round trip + stat recompute) → release JIGGLYPUFF → SEE YA
    ; Cadence: one input per 60 frames, 10-frame holds (edge-triggered, and well
    ; under JoypadLowSensitivity's repeat delay). The first cut used 30-40-frame
    ; gaps and the mon list ate one A mid-settle, shifting every later press one
    ; state over (PERSIAN got released instead of JIGGLYPUFF). The tail uses B —
    ; B answers prompts AND exits the menu, so the flow converges whether or not
    ; OnceReleasedText carries its own prompt before the YES/NO box.
%ifdef BILLSPC_ATTACH_DELAY
%assign BPC_AKS BILLSPC_ATTACH_DELAY    ; RunBillsPCTest idles this many frames
%else
%assign BPC_AKS 0
%endif
    ; Press budget per message (measured from the generated streams — see
    ; bills_pc_text.inc): _MonWasStoredText = 1 (prompt); _MonIsTakenOutText and
    ; _MonWasReleasedText = 2 (cont + prompt); _OnceReleasedText = 1 (cont; its
    ; `done` leaves the box up for the YES/NO choice).
    dd   40 + BPC_AKS,   50 + BPC_AKS, PAD_DOWN ; menu 0→1 (DEPOSIT)
    dd  100 + BPC_AKS,  110 + BPC_AKS, PAD_A    ; open the party mon list
    dd  160 + BPC_AKS,  170 + BPC_AKS, PAD_DOWN ; list 0→1 (PERSIAN)
    dd  220 + BPC_AKS,  230 + BPC_AKS, PAD_A    ; select PERSIAN → DEPOSIT/STATS/CANCEL
    dd  280 + BPC_AKS,  290 + BPC_AKS, PAD_A    ; DEPOSIT → "PERSIAN was stored in BOX 1."
    dd  360 + BPC_AKS,  370 + BPC_AKS, PAD_A    ; dismiss (prompt) → BillsPCMenu
    dd  440 + BPC_AKS,  450 + BPC_AKS, PAD_A    ; open the party mon list again
    dd  500 + BPC_AKS,  510 + BPC_AKS, PAD_DOWN ; list 0→1 (JIGGLYPUFF)
    dd  560 + BPC_AKS,  570 + BPC_AKS, PAD_A    ; select JIGGLYPUFF → submenu
    dd  620 + BPC_AKS,  630 + BPC_AKS, PAD_A    ; DEPOSIT → stored message
    dd  700 + BPC_AKS,  710 + BPC_AKS, PAD_A    ; dismiss (prompt) → BillsPCMenu
    dd  780 + BPC_AKS,  790 + BPC_AKS, PAD_UP   ; menu 1→0 (WITHDRAW)
    dd  840 + BPC_AKS,  850 + BPC_AKS, PAD_A    ; open the box mon list (PERSIAN 0, JIGGLYPUFF 1)
    dd  900 + BPC_AKS,  910 + BPC_AKS, PAD_A    ; select PERSIAN → WITHDRAW/STATS/CANCEL
    dd  960 + BPC_AKS,  970 + BPC_AKS, PAD_A    ; WITHDRAW → "PERSIAN is / taken out." (cont)
    dd 1040 + BPC_AKS, 1050 + BPC_AKS, PAD_A    ; scroll "Got PERSIAN." (cont)
    dd 1100 + BPC_AKS, 1110 + BPC_AKS, PAD_A    ; dismiss (prompt) → BillsPCMenu (cursor 0)
    dd 1180 + BPC_AKS, 1190 + BPC_AKS, PAD_DOWN ; menu 0→1
    dd 1240 + BPC_AKS, 1250 + BPC_AKS, PAD_DOWN ; menu 1→2 (RELEASE)
    dd 1300 + BPC_AKS, 1310 + BPC_AKS, PAD_A    ; open the box mon list (JIGGLYPUFF at 0)
    dd 1360 + BPC_AKS, 1370 + BPC_AKS, PAD_A    ; select JIGGLYPUFF → "Once released..." (cont)
    dd 1420 + BPC_AKS, 1430 + BPC_AKS, PAD_A    ; scroll to "OK?" → YES/NO box
    dd 1480 + BPC_AKS, 1490 + BPC_AKS, PAD_A    ; YES → "JIGGLYPUFF was / released." (cont)
    dd 1560 + BPC_AKS, 1570 + BPC_AKS, PAD_A    ; scroll "Bye JIGGLYPUFF!" (cont)
    dd 1620 + BPC_AKS, 1630 + BPC_AKS, PAD_A    ; dismiss (prompt) → BillsPCMenu
    dd 1700 + BPC_AKS, 1710 + BPC_AKS, PAD_B    ; SEE YA (ExitBillsPC) → harness hang loop
    dd 1780 + BPC_AKS, 1790 + BPC_AKS, PAD_B    ; spare — harmless in the hang loop
    dd  -1,  -1, 0
%elifdef AUTOKEY_BILLSPC_CHANGE
    ; sram-plan stage 6 (DEBUG_BILLSPC_CHANGEBOX): the change-box round trip —
    ; the ONLY runtime path into SRAM banks 2/3.
    ;   deposit PERSIAN → CHANGE BOX → YES (first change runs EmptyAllSRAMBoxes,
    ;   banks 2+3 init) → BOX12 (11×DOWN, A — bank-3 traffic both ways +
    ;   SaveGameData) → CHANGE BOX back to BOX 1 → SEE YA
    ; PERSIAN surviving in the final wBoxData proves the bank-2 store AND load;
    ; wCurrentBoxNum must read $80 (box 0 | BIT_HAS_CHANGED_BOXES).
    ; Cadence: the AUTOKEY_BILLSPC 60-frame/10-hold rhythm. Press budget for
    ; _WhenYouChangeBoxText (data/text/text_4.asm): cont + para = TWO presses,
    ; its `done` leaves the box up for YesNoChoice. ChangeBox's SaveGameData
    ; needs NO press (NowSavingText); the 240-frame quiet gaps after each box
    ; pick cover SFX_SAVE + WaitForSoundToFinish + the .dsv store.
    ; After ChangeBox returns, BillsPCMenu re-enters with wParentMenuItem = 3,
    ; so the second CHANGE BOX needs only an A.
%ifdef BILLSPC_ATTACH_DELAY
%assign BPC_AKS BILLSPC_ATTACH_DELAY    ; RunBillsPCTest idles this many frames
%else
%assign BPC_AKS 0
%endif
    dd   40 + BPC_AKS,   50 + BPC_AKS, PAD_DOWN ; menu 0→1 (DEPOSIT)
    dd  100 + BPC_AKS,  110 + BPC_AKS, PAD_A    ; open the party mon list
    dd  160 + BPC_AKS,  170 + BPC_AKS, PAD_DOWN ; list 0→1 (PERSIAN)
    dd  220 + BPC_AKS,  230 + BPC_AKS, PAD_A    ; select PERSIAN → DEPOSIT/STATS/CANCEL
    dd  280 + BPC_AKS,  290 + BPC_AKS, PAD_A    ; DEPOSIT → "PERSIAN was stored in BOX 1."
    dd  360 + BPC_AKS,  370 + BPC_AKS, PAD_A    ; dismiss (prompt) → BillsPCMenu (cursor 1)
    dd  440 + BPC_AKS,  450 + BPC_AKS, PAD_DOWN ; menu 1→2 (RELEASE)
    dd  500 + BPC_AKS,  510 + BPC_AKS, PAD_DOWN ; menu 2→3 (CHANGE BOX)
    dd  560 + BPC_AKS,  570 + BPC_AKS, PAD_A    ; CHANGE BOX → "When you change a..."
    dd  640 + BPC_AKS,  650 + BPC_AKS, PAD_A    ; cont: "will be saved."
    dd  700 + BPC_AKS,  710 + BPC_AKS, PAD_A    ; para: "Is that okay?" → YES/NO box
    dd  760 + BPC_AKS,  770 + BPC_AKS, PAD_A    ; YES → EmptyAllSRAMBoxes → box menu (BOX 1)
%assign BPC_I 0
%rep 11
    dd  820 + BPC_I * 60 + BPC_AKS, 830 + BPC_I * 60 + BPC_AKS, PAD_DOWN ; → BOX12
%assign BPC_I BPC_I + 1
%endrep
    dd 1540 + BPC_AKS, 1550 + BPC_AKS, PAD_A    ; pick BOX12 → save + swap (banks 2→3)
    ; Second CHANGE BOX — measured, NOT symmetric with the first. Two traps
    ; (FRAME.BIN bisects at 1860/2060/2160):
    ;  1. A 10-frame opener hold can DOUBLE-CONSUME (select + the text's cont
    ;     wait reads the still-held A — the dialog box is already drawn this
    ;     time, so page 1 prints before the hold releases). 4-frame hold.
    ;  2. The first pick's SaveGameData (.dsv write, host disk I/O) jitters
    ;     the frame timeline by a few frames run-to-run, so a press near a
    ;     wait boundary lands in DIFFERENT states across otherwise-identical
    ;     runs. Every gap here is >= 120 frames so the jitter cannot reorder
    ;     press vs wait.
    dd 1840 + BPC_AKS, 1844 + BPC_AKS, PAD_A    ; CHANGE BOX (short hold — trap 1)
    dd 1960 + BPC_AKS, 1964 + BPC_AKS, PAD_A    ; cont: "will be saved."
    dd 2080 + BPC_AKS, 2084 + BPC_AKS, PAD_A    ; para: "Is that okay?" → YES/NO box
    dd 2200 + BPC_AKS, 2210 + BPC_AKS, PAD_A    ; YES → box menu (cursor BOX12)
%assign BPC_I 0
%rep 11
    dd 2320 + BPC_I * 60 + BPC_AKS, 2330 + BPC_I * 60 + BPC_AKS, PAD_UP ; → BOX 1
%assign BPC_I BPC_I + 1
%endrep
    dd 3040 + BPC_AKS, 3050 + BPC_AKS, PAD_A    ; pick BOX 1 → save + swap back (bank 2)
    dd 3340 + BPC_AKS, 3350 + BPC_AKS, PAD_B    ; SEE YA (ExitBillsPC) → harness hang loop
    dd 3420 + BPC_AKS, 3430 + BPC_AKS, PAD_B    ; spare — harmless in the hang loop
    dd  -1,  -1, 0
%elifdef AUTOKEY_FLY
    ; overworld-events Stage 4 (DEBUG_AUTOKEY AUTOKEY_FLY): drive the real FLY path
    ; end-to-end so the town-map destination selection warps and ARRIVES, not just
    ; arms the flag. Prereqs are all seeded by PrepareNewGameDebug (DEBUG_SEED_PARTY):
    ; THUNDERBADGE set, SNORLAX (party slot 0) knows FLY, wTownVisitedFlag=$FFFF (every
    ; town flyable), and Pallet Town is an outside map so .canFly is taken.
    ;   START → DOWN → A     : open START, POKéDEX(0)→POKéMON(1), select it
    ;   A                    : party menu → SNORLAX (slot 0) → field-move pop-up
    ;   A                    : FLY (pop-up top — it is SNORLAX move slot 0) → Town Map
    ;                          (ChooseFlyDestination → LoadTownMap_Fly)
    ;   UP → A               : Town Map: step off PALLET to the next visited town,
    ;                          select it → wDestinationMap + BIT_FLY_WARP armed
    ;   (return to OverworldLoop, whose idle branch consumes BIT_FLY_WARP →
    ;    HandleFlyWarpOrDungeonWarp → the destination map loads and renders)
    ; Frame ranges are generous; AUTOKEY_DUMP_FRAME (default 900, Makefile) is set
    ; well past arrival so FRAME.BIN shows the destination map.
    dd  60,  66, PAD_START
    dd 110, 116, PAD_DOWN       ; POKéDEX → POKéMON
    dd 160, 166, PAD_A          ; open the party menu
    dd 250, 256, PAD_A          ; select SNORLAX → field-move pop-up
    dd 330, 336, PAD_A          ; select FLY → Town Map (ChooseFlyDestination)
    dd 470, 476, PAD_A          ; select the highlighted town → arm the Fly warp
    dd  -1,  -1, 0
%elifdef AUTOKEY_TRAINERCARD
    ; Trainer-card ENTER **and EXIT** (the default script above can only enter a
    ; submenu — it has a single A press). DEBUG_SEED_PARTY sets EVENT_GOT_POKEDEX
    ; (measured: two DOWNs landed on ITEM, not the card), so the START menu is
    ; POKéDEX / POKéMON / ITEM / <NAME> / SAVE / OPTION / EXIT and it takes THREE
    ; DOWNs to reach the trainer card; A opens it, and the second A satisfies the
    ; card's WaitForTextScrollButtonPress and returns to the START menu.
    ; Photograph the RETURN, not the card: the two defects this reproduces are
    ; both on the exit path (the overworld palette RunDefaultPaletteCommand
    ; restores behind the box, and the ▶ cursor PlaceMenuCursor puts back).
    dd  60,  66, PAD_START
    dd  90,  96, PAD_DOWN
    dd 120, 126, PAD_DOWN
    dd 150, 156, PAD_DOWN
    dd 180, 186, PAD_A          ; open the trainer card
    dd 290, 296, PAD_A          ; WaitForTextScrollButtonPress -> back to START
    dd  -1,  -1, 0
%else
    dd  60,  66, PAD_START
%assign AK_I 0
%rep AUTOKEY_DOWNS
    dd  90 + AK_I * 30,  96 + AK_I * 30, PAD_DOWN
%assign AK_I AK_I + 1
%endrep
    dd  90 + AUTOKEY_DOWNS * 30, 96 + AUTOKEY_DOWNS * 30, PAD_A
    dd  -1,  -1, 0
%endif
section .text
%endif

%ifdef DEBUG_CINEMATIC_MARKERS
; ---------------------------------------------------------------------------
; RunCinematicMarkersTest — A1.6 of docs/current_plan_menu_intro.md.
;
; Proves the cinematic projection substrate synthetically, BEFORE any real
; content depends on it: exact projection, OBJ clipping (hidden + edge-straddling),
; the matte, and — the part nothing else can prove — GB mod-256/mod-32 WRAP
; sampling on both axes.
;
; Why a dedicated harness rather than leaning on the title screen: a timing trace
; records the scroll value the game WROTE, which matches ground truth even if the
; renderer ignores or mis-samples it. Only pixels can distinguish a correct
; wrapped read from a linear one, and they only differ on wrapped frames. So this
; builds a scene whose wrapped and linear readings are unmistakably different:
;
;   GB_TILEMAP0 rows 0..17 / cols 0..19 : the mirrored marker scene
;   GB_TILEMAP0 row 0 / col 0           : DISTINCT wrap-target content
;   GB_TILEMAP0 rows 18..31, cols 20..31: left clear (0)
;   GB_TILEMAP1 (the ADJACENT map)      : POISON fill
;
; A correct wrap at src=252 samples this map's row/col 0 and shows the distinct
; content. A linear read walks past the map boundary into GB_TILEMAP1 and shows
; POISON. The verifier fails on any poison pixel.
;
; Offsets come from -D MARKER_SX / -D MARKER_SY so one build parameterizes the
; whole sweep (0..7 for sub-tile motion, 252..255 for wrap).
;
; Tiles are synthesized directly into VRAM, so g_tilecache_dirty MUST be armed —
; the compositor draws BG, window AND sprites from tile_cache, never from raw
; VRAM.
; ---------------------------------------------------------------------------
%ifndef MARKER_SX
%define MARKER_SX 0
%endif
%ifndef MARKER_SY
%define MARKER_SY 0
%endif

%define UI_LAYOUT_EQUATES_ONLY 1
%include "assets/ui_layout_intro.inc"

extern MovieBeginSurface        ; engine/movie/movie_projection.asm
extern MovieMirrorSurface
extern MovieSyncScroll
extern PublishProjectedOAM      ; engine/gfx/sprite_oam.asm
extern g_tilecache_dirty        ; ppu/ppu.asm
extern ClearSprites             ; home/clear_sprites.asm
extern DelayFrame               ; src/home/vblank.asm

global RunCinematicMarkersTest

MARK_SOLID   equ 1      ; color 3 — scene / OBJ marker
MARK_WRAP    equ 2      ; color 2 — the wrap target at row 0 / col 0
MARK_POISON  equ 3      ; color 1 — GB_TILEMAP1; must never be sampled

; MARKER_OBJ idx, oam_y, oam_x — one canonical OAM record at EDI (GB-relative).
; Y and X are RAW GB OAM values (screen + (8,16)), written unmodified so the
; hidden cases stay hidden by their real hardware values rather than by culling.
%macro MARKER_OBJ 3
    mov byte [edi + (%1) * OAM_ENTRY_SIZE + 0], %2      ; Y
    mov byte [edi + (%1) * OAM_ENTRY_SIZE + 1], %3      ; X
    mov byte [edi + (%1) * OAM_ENTRY_SIZE + 2], MARK_SOLID  ; tile
    mov byte [edi + (%1) * OAM_ENTRY_SIZE + 3], 0       ; attr
%endmacro

RunCinematicMarkersTest:
    ; ── synthesize marker tiles into VRAM ($8000, unsigned OBJ addressing) ──
    ; 2bpp: 8 rows x (lo plane, hi plane); color = (hi<<1)|lo.
    lea edi, [ebp + GB_VRAM0]
    mov ecx, 16
    xor al, al
    rep stosb                              ; tile 0 = blank
    mov ecx, 8                             ; tile 1 = color 3 (lo=FF, hi=FF)
.t1: mov byte [edi], 0xFF
    mov byte [edi + 1], 0xFF
    add edi, 2
    dec ecx
    jnz .t1
    mov ecx, 8                             ; tile 2 = color 2 (lo=00, hi=FF)
.t2: mov byte [edi], 0x00
    mov byte [edi + 1], 0xFF
    add edi, 2
    dec ecx
    jnz .t2
    mov ecx, 8                             ; tile 3 = color 1 (lo=FF, hi=00)
.t3: mov byte [edi], 0xFF
    mov byte [edi + 1], 0x00
    add edi, 2
    dec ecx
    jnz .t3
    mov byte [g_tilecache_dirty], 1        ; raw VRAM tile write — arm the cache

    ; Marker tiles live at $8000, so the BG/window must use UNSIGNED addressing.
    ; rLCDC bit 4 selects it; with the bit clear (the overworld's setting) tile
    ; ids resolve through SIGNED $9000 addressing and these markers decode as
    ; whatever happens to sit there. OBJ always use unsigned $8000, which is why
    ; a wrong setting here corrupts only the BG half of the scene — caught
    ; exactly this way on the first run of this harness.
    or byte [ebp + IO_LCDC], (1 << 4)

    call ClearSprites
    ; W_UPDATE_SPRITES_ENABLED is parked by MovieBeginSurface (to $FF, not 0 —
    ; 0 means "hide once", which erases the published cinematic OAM).
    mov word [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR], 0

    ; ── poison the ADJACENT tilemap ────────────────────────────────────────
    lea edi, [ebp + GB_TILEMAP1]
    mov ecx, 32 * 32
    mov al, MARK_POISON
    rep stosb

    ; ── take over the screen as a centred cinematic surface ────────────────
    call MovieBeginSurface                 ; clears W_TILEMAP, publishes matte+clip

    ; ── draw the BG marker scene into the projected 20x18 rectangle ────────
    ; Corner markers are the projection assertions: GB (0,0) must land at canvas
    ; (10,3) = pixel (80,24), and GB (19,17) at canvas (29,20).
    lea esi, [ebp + W_TILEMAP + UI_TITLE_ROW * SCREEN_WIDTH + UI_TITLE_COL]
    mov byte [esi], MARK_SOLID                                     ; GB (0,0)
    mov byte [esi + (UI_TITLE_GBH - 1) * SCREEN_WIDTH + UI_TITLE_GBW - 1], MARK_SOLID  ; GB (19,17)
    ; Distinct wrap-target content along GB row 0 and GB column 0, skipping
    ; (0,0) so the corner marker stays the projection assertion.
    lea edi, [esi + 1]                     ; GB row 0, cols 1..19
    mov ecx, UI_TITLE_GBW - 1
    mov al, MARK_WRAP
    rep stosb
    lea edi, [esi + SCREEN_WIDTH]          ; GB col 0, rows 1..17
    mov ecx, UI_TITLE_GBH - 1
.col0:
    mov byte [edi], MARK_WRAP
    add edi, SCREEN_WIDTH
    dec ecx
    jnz .col0

    call MovieMirrorSurface                ; stride 40 -> stride 32 into GB_TILEMAP0

    ; ── fine source scroll, through the shared helper ──────────────────────
    mov byte [ebp + H_SCX], MARKER_SX
    mov byte [ebp + H_SCY], MARKER_SY
    call MovieSyncScroll

    ; ── OBJ markers ────────────────────────────────────────────────────────
    ; Records 0-3 are GB-HIDDEN and must produce ZERO pixels; records 4-7
    ; straddle each screen edge and must be clipped PER PIXEL, never painting
    ; the matte. Built in GB memory because PublishProjectedOAM takes a
    ; GB-relative source.
    lea edi, [ebp + wShadowOAMBackup]
    mov ecx, OAM_COUNT * OAM_ENTRY_SIZE
    xor al, al
    rep stosb
    lea edi, [ebp + wShadowOAMBackup]
    MARKER_OBJ 0,   0,  80          ; hidden: OAM_Y = 0
    MARKER_OBJ 1, 160,  80          ; hidden: OAM_Y >= 160
    MARKER_OBJ 2,  80,   0          ; hidden: OAM_X = 0
    MARKER_OBJ 3,  80, 168          ; hidden: OAM_X >= 168
    MARKER_OBJ 4,  40,   4          ; straddles LEFT   (screen x = -4)
    MARKER_OBJ 5,  40, 164          ; straddles RIGHT  (screen x = 156)
    MARKER_OBJ 6,  12,  80          ; straddles TOP    (screen y = -4)
    MARKER_OBJ 7, 156,  80          ; straddles BOTTOM (screen y = 140)

    mov esi, wShadowOAMBackup       ; GB-relative source
    mov ecx, 8                      ; valid entries
    mov eax, UI_TITLE_COL * 8       ; projection X = 80
    mov ebx, UI_TITLE_WY            ; projection Y = 24
    call PublishProjectedOAM

    call DelayFrame
    call DelayFrame
    call DelayFrame
    call DumpBackbuffer             ; writes FRAME.BIN + exits (never returns)
.hang:
    jmp .hang
%endif
