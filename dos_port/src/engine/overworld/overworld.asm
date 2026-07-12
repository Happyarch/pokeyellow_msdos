; overworld.asm — Overworld map-loading and rendering routines.
;
; Faithful translations (pret cross-reference maintained):
;   ResetMapVariables          home/overworld.asm:ResetMapVariables
;   DrawTileBlock              home/overworld.asm:DrawTileBlock
;   LoadCurrentMapView         home/overworld.asm:LoadCurrentMapView
;   LoadTilesetTilePatternData home/overworld.asm:LoadTilesetTilePatternData
;   LoadTileBlockMap           home/overworld.asm:LoadTileBlockMap (N/S/W/E strips translated;
;                               Phase 2 scaffold sets all connected maps to $FF so they skip)
;   LoadScreenRelatedData      home/overworld.asm:LoadScreenRelatedData
;   LoadMapData                home/overworld.asm:LoadMapData  (faithful structure; stubs for
;                               InitMapSprites, RunPaletteCommand, LoadPlayerSpriteGraphics,
;                               UpdateMusic — ; TODO-HW tags below)
;
; Phase 2 scaffold (not a faithful translation):
;   EnterMap             — scaffold entry from title screen
;   OverworldLoop        — player-movement frame loop: UpdateSprites (facing + walk
;                           animation), AdvancePlayerSprite scroll, land collision
;   LoadPlayerSpriteGraphics — loads Red's standing tiles to $8000 and walking
;                           tiles to $8800 (the VRAM layout the sprite engine indexes)
;
; The player now renders through the real sprite engine: UpdateSprites
; (src/engine/overworld/movement.asm) drives the per-slot image index, and PrepareOAMData
; (src/gfx/sprite_oam.asm, run in the DelayFrame pipeline) builds shadow OAM from it.
;
; Asset layout in ROM window (EBP + $4000–$54FF and $1000+; see gb_memmap.inc):
;   $4000 : overworld.2bpp  (94 tiles, 1504 bytes)  → wTilesetGfxPtr
;   $4600 : overworld.bst   (128 blocks × 16 bytes) → wTilesetBlocksPtr
;   $4E00 : PalletTown.blk  (10×9 = 90 bytes)       → wCurMapDataPtr
;   $4F00 : Overworld_Coll  (passable-tile list, $FF-terminated)
;   $5000 : Route1.blk, $5200: Route21.blk, $5400: tileset header, $540C: map headers
;   $1000+: city/route .blk files (ViridianCity, PewterCity, … — see OW_*_BLK_GBADDR)
;
; Build: nasm -f coff -I include/ -I . -o overworld.o src/engine/overworld/overworld.asm

bits 32

%include "gb_memmap.inc"
%include "gb_macros.inc"
%include "assets/audio_constants.inc"   ; SFX_COLLISION / MUSIC_* (audio engine is live)
%include "assets/map_dims.inc"          ; map-id + tileset-id constants (OAKS_LAB/CINNABAR_GYM/SHIP_PORT, OW-A.6)
%include "assets/event_constants.inc"   ; EVENT_* bit indices (EVENT_2A7, OW-A.6)
%include "events.inc"                   ; CheckEvent/SetEvent/ResetEvent over W_EVENT_FLAGS

extern PlaySound                       ; src/home/audio.asm (real gateway, OW-A.14)
extern PlayDefaultMusic                ; src/home/audio.asm — surf-dismount music restore (OW-A.6)
extern PlayDefaultMusicFadeOutCurrent  ; src/home/audio.asm (real gateway, OW-A.14)
extern UpdateMusic6Times               ; src/home/audio.asm (real gateway, OW-A.14)
extern FillMemory
extern CopyData
extern FarCopyData
extern IsInArray              ; src/home/array.asm — shared home global (LoadTilesetHeader dungeon check)
extern RunMapScript           ; per-frame map _Script dispatch (script engine)
extern StepCountCheck         ; wild_encounter_check.asm — per-step counter decrement (M7.1)
extern AnyPartyAlive          ; wild_encounter_check.asm — DH = OR of party HP (linked; OW-A.6)
extern DelayFrames            ; src/video/frame.asm — BL = frame count
extern IsNextTileShoreOrWater ; src/engine/items/item_effects.asm — CF=1 shore/water ahead (OW-A.6)
extern CheckForJumpingAndTilePairCollisions ; src/engine/overworld/ledges.asm (linked, OW-7.2)
extern TilePairCollisionsWater              ; src/engine/overworld/ledges.asm — water seam pairs
extern NewBattle              ; wild_encounter_check.asm — wild/trainer encounter gate (LIVE)
extern AllPokemonFainted      ; wild_encounter_check.asm — blackout handoff
extern DisableLCD
extern EnableLCD
extern DelayFrame
extern LoadTextBoxTilePatterns
extern GBPalNormal
extern g_player_marker_on
extern UpdateSprites
; EnterMap reset-ladder leaves (OW-A.4): ClearVariablesOnEnterMap (clear_variables.asm,
; linked); the rest are ret-stubs in overworld_stubs.asm until their subsystems land.
extern ClearVariablesOnEnterMap        ; clear_variables.asm
extern ResetUsingStrengthOutOfBattleBit ; overworld_stubs.asm (TODO OW-A.4(b)/faithful)
extern MapEntryAfterBattle             ; overworld_stubs.asm (TODO OW-A.4(b)/faithful)
extern EnterMapAnim                    ; overworld_stubs.asm (TODO faithful — player_animations)
extern IsSurfingPikachuInParty         ; overworld_stubs.asm (TODO faithful — pikachu follower)
extern CheckForceBikeOrSurf            ; player_state.asm (LINKED — wild-live promotion)
extern LoadWildData                    ; wild_mons.asm — per-map wild data → wGrass/wWaterMons (OW-A.5)
extern LoadPlayerSpriteGraphics        ; engine/overworld/player_gfx.asm (faithful pret dispatcher;
                                       ; the walking-only scaffold that lived here is retired)
; HandleBlackOut's closure (wild-live promotion)
extern GBFadeOutToBlack                ; home/fade.asm
extern StopAllMusic                    ; home/audio.asm
extern StopAllSounds                   ; init/init.asm
extern g_audio_engine_online           ; home/audio.asm — 0 until audio_init (StopMusic guard)
extern BankswitchCommon                ; home/bankswitch.asm (flat: records hLoadedROMBank)
extern ResetStatusAndHalveMoneyOnBlackout ; engine/events/black_out.asm
extern PrepareForSpecialWarp           ; engine/overworld/special_warps.asm (real body — stub retired)
extern SpecialEnterMap                 ; engine/overworld/special_warps.asm
extern g_tilecache_dirty
extern hide_window           ; src/ppu/ppu.asm — empty the window list (count=0)
extern set_single_window     ; src/ppu/ppu.asm — define g_windows[] as one descriptor
extern InitMapSprites
; OW-A.2 P3b: the faithful home object-loader (InitSprites/LoadSprite, below) writes
; the per-slot movement-byte-2 + masked-text-id to wMapSpriteData and trainer
; class/num (or item) to wMapSpriteExtraData — both flat .bss globals in map_sprites.asm.
extern wMapSpriteData
extern wMapSpriteExtraData
; pret wNumSprites (ram/wram.asm) — number of sprites on the current map. Read by
; src/home/text_script.asm; not in this file's include chain, so define it here
; (guarded; matches m1_3_pending_symbols.inc's %ifndef pattern).
%ifndef wNumSprites
wNumSprites equ 0xD4E0
%endif
extern InitToggleableObjectFlags
extern text_engine_init
extern CheckNPCInteraction
extern IsNPCAtTargetBlock
extern CheckTrainerSight
extern TrainerEncounterFlow
extern DisplayStartMenu
extern w_map_text_table_ptr
extern MapTextTablePointers
; M3.3 home-rectify: faithful simulated-joypad framework
extern AreInputsSimulated           ; src/engine/overworld/simulate_joypad.asm
extern StartSimulatingJoypadStates  ; src/engine/overworld/simulate_joypad.asm
; M7.4 home-rectify: faithful ExtraWarpCheck function-1/function-2 dispatch
extern ExtraWarpCheck               ; src/engine/overworld/warp_check.asm
extern IsPlayerStandingOnDoorTileOrWarpTile ; src/engine/overworld/player_state.asm
%ifdef DEBUG_DUMP
extern DebugDumpMemory
%endif
%ifdef DEBUG_TRANSITION
extern DumpBackbuffer
%elifdef DEBUG_WALK_NORTH
extern DumpBackbuffer
%elifdef DEBUG_DIALOG
extern DumpBackbuffer
%endif
%ifdef DEBUG_SEAM
extern DumpBackbuffer
extern SeamLogRecord
extern DumpSeamLog
%endif
%ifdef DEBUG_NOCLIP
extern pad_noclip
%endif
%ifdef DEBUG_BAGMENU
extern RunBagMenuTest
%endif
%ifdef DEBUG_STARTMENU
extern SeedDeterministicPlayerIdentity  ; engine/debug/debug_party.asm — "RED"/id 0 (seed.lua spec)
%endif
%ifdef DEBUG_BAGMENU_LIVE
extern PrepareNewGameDebug
%endif
%ifdef DEBUG_SEED_PARTY
extern PrepareNewGameDebug
%endif
%ifdef DEBUG_PARTYMENU
extern RunPartyMenuTest
%endif
%ifdef DEBUG_BATTLE
extern RunBattleTest
%endif
%ifdef DEBUG_TEXTBOXID
extern RunTextBoxIDTest
%endif
%ifdef DEBUG_LISTMENU
extern RunListMenuTest
%endif
%ifdef DEBUG_DRAWBADGES
extern RunDrawBadgesTest
%endif
%ifdef DEBUG_TRAINERCARD
extern RunTrainerCardTest
%endif
%ifdef DEBUG_OAKSPC
extern RunOaksPCTest
%endif
%ifdef DEBUG_LEAGUEPC
extern RunLeaguePCTest
%endif
%ifdef DEBUG_OPTIONS
extern RunOptionsTest
%endif
%ifdef DEBUG_PLAYERSPC
extern RunPlayersPCTest
%endif
%ifdef DEBUG_MAINMENU
extern RunMainMenuTest
%endif
%ifdef DEBUG_SAVE
extern RunSaveTest
%endif
%ifdef DEBUG_NAMINGSCREEN
extern RunNamingScreenTest
%endif
%ifdef DEBUG_G1
extern RunPokedexTest
%endif
%ifdef DEBUG_G2
extern RunPokedexEntryTest
%endif
%ifdef DEBUG_I1
extern RunLinkMenuTest
%endif
%ifdef DEBUG_I2
extern RunLinkCupsTest
%endif
%ifdef DEBUG_LEARNMOVE
extern RunLearnMoveTest
%endif
%ifdef DEBUG_STATUS
extern RunStatusScreenTest
%endif
%ifdef DEBUG_WALKSPEED
extern DebugDumpMemory
extern tick_count
%endif

global EnterMap
global EnterMapBoot
global ResetMapVariables
global LoadScreenRelatedData
global LoadTilesetTilePatternData
global LoadTileBlockMap
global DrawTileBlock
global LoadCurrentMapView
; (OW-A.5: dead `global CopyMapViewToVRAM` removed — routine obsoleted by native
;  render_bg; had no body, exported an undefined symbol. See its note ~L1729.)
global OverworldLoop
global OverworldLoopLessDelay               ; OW-A.3: de-folded from OverworldLoop.lessDelay
global AdvancePlayerSprite
global _AdvancePlayerSprite                 ; OW-A.3: engine body, de-folded from the home wrapper
global IsTilePassable
global CheckWarpTile
global LoadWarpDestination
global PlayerStepOutFromDoor
global IgnoreInputForHalfSecond
global IsPlayerStandingOnDoorTile          ; OW-7.2: for player_state.asm (check-only) when it promotes
global LoadTilesetHeader                   ; OW-7.2: for special_warps.asm (now linked)
; LoadPlayerSpriteGraphics moved to engine/overworld/player_gfx.asm (wild-live
; promotion) — the scaffold here is retired; player_sprite is exported to it.
global player_sprite                       ; pret RedSprite; consumed by player_gfx.asm
global RefreshCollisionTileMap             ; menus S4: home/start_menu.asm restores
                                           ; the W_TILEMAP mirror around the menu

; ---------------------------------------------------------------------------
; Map and tileset constants
; ---------------------------------------------------------------------------
MAP_ID_PALLET_TOWN          equ 0x00
TILESET_OVERWORLD           equ 0x00
; tileset ids (constants/tileset_constants.asm; not in gb_memmap.inc) — PlayMapChangeSound
CEMETERY                    equ 15
FACILITY                    equ 22
OVERWORLD_DOOR_TILE         equ 0x0B   ; pret: door tile in tileset 0 (PlayMapChangeSound)
PALLET_TOWN_WIDTH           equ 10
PALLET_TOWN_HEIGHT          equ 9
PALLET_TOWN_BORDER_BLOCK    equ 0x0B   ; border block from PalletTown_Object
TILESET_BANK_FLAT           equ 0x01   ; ignored in flat model (TODO-HW: ROM banking)

; wCurrentTileBlockMapViewPointer for the Pallet Town spawn (wXCoord/wYCoord = 8,8;
; see EnterMap). Same derivation LoadWarpDestination uses, specialized to that coord:
;   stride   = PALLET_TOWN_WIDTH + 2*MAP_BORDER
;   view_row = (8>>1) + MAP_BORDER - SCREEN_BLOCK_HEIGHT/2 = 4 + MAP_BORDER - 4 = MAP_BORDER
;   view_col = (8>>1) + MAP_BORDER - SCREEN_BLOCK_WIDTH/2  = 4 + MAP_BORDER - 6 = MAP_BORDER - 2
; The `MAP_BORDER` / `MAP_BORDER - 2` terms are the reduced forms of those two
; expressions, not border literals — they track MAP_BORDER correctly.
PALLET_TOWN_VIEW_PTR        equ W_OVERWORLD_MAP + (MAP_BORDER) * (PALLET_TOWN_WIDTH + MAP_BORDER * 2) + (MAP_BORDER - 2)

; Number of connections in the Block/Connect strips (0xFF = none — disables strip loading)
MAP_NO_CONNECTION           equ 0xFF

; Pallet Town map connections (computed from the pret `connection` macro for the
; north=Route1 / south=Route21 connections, both at offset 0). See
; macros/scripts/maps.asm:connection. Route1 = 10×18, Route21 = 10×45.
MAP_ID_ROUTE_1              equ 0x0C
MAP_ID_ROUTE_21             equ 0x20
CONNECTION_NORTH           equ 1 << 3   ; wCurMapConnections bits (EAST=1,WEST=2,SOUTH=4,NORTH=8)
CONNECTION_SOUTH           equ 1 << 2

; The Pallet Town north(Route1)/south(Route21) strip + view-pointer equs that
; used to live here are GONE. They were hand-computed for MAP_BORDER = 6 (e.g.
; `NORTH_STRIP_DEST equ W_OVERWORLD_MAP + 6`, `_win = (w+12)*h + 1`) and had been
; dead since LoadMapHeader started reading the connection headers that
; tools/gen_map_headers.py emits into assets/map_headers.inc — which is the one
; place that knows MAP_BORDER. Nothing referenced them; they only survived as a
; second, silently-stale copy of the same arithmetic. Edit the generator.

ROUTE1_BLK_GB_SIZE         equ 180        ; 10×18
ROUTE21_BLK_GB_SIZE        equ 450        ; 10×45

; ---------------------------------------------------------------------------
; Default player / rival names (debug / SKIP_TITLE builds)
; ---------------------------------------------------------------------------
; The title screen's PrepareTitleScreen seeds wPlayerName / wRivalName (the
; engine's debug defaults NINTEN / SONY); SKIP_TITLE bypasses it entirely, so
; those fields held uninitialized garbage and <PLAYER>/<RIVAL> ($52/$53)
; substitutions printed junk. When SKIP_TITLE is set we seed the same defaults.
; Override at build time: `make SKIP_TITLE=1 PLAYER_NAME=ASH RIVAL_NAME=GARY`
; (the Makefile passes -D PLAYER_NAME="'<name>'"). Letters only, ≤7 chars.
PLAYER_NAME_FIELD equ 11                  ; wPlayerName/wRivalName field size (= title.asm NAME_LENGTH)
%ifndef PLAYER_NAME
%define PLAYER_NAME 'NINTEN'
%endif
%ifndef RIVAL_NAME
%define RIVAL_NAME 'SONY'
%endif

; encode_name — emit a name as charmap bytes padded to PLAYER_NAME_FIELD with $50.
; Each ASCII letter maps to the pret charmap by +0x3F: 'A'(0x41)->0x80, so this
; covers A-Z (0x80-0x99) and a-z (0xA0-0xB9). $50 is the '@' terminator + padding.
%macro encode_name 1
%strlen _en_len %1
%assign _en_i 1
%rep _en_len
    %substr _en_ch %1 _en_i
    db _en_ch + 0x3F
    %assign _en_i _en_i + 1
%endrep
    times (PLAYER_NAME_FIELD - _en_len) db 0x50
%endmacro

section .data
DefaultPlayerName:
    encode_name PLAYER_NAME
DefaultRivalName:
    encode_name RIVAL_NAME

section .text

; PAD_BUTTONS | PAD_CTRL_PAD = every button ($0F | $F0 = $FF); pret's EnterMap
; writes this to wJoyIgnore so no real input is honored during the map load.
; (hardware.inc constants; not defined in overworld.asm's include chain, so declared
; locally here — same idiom as ledges.asm's PAD_ALL.)
PAD_BUTTONS  equ 0x0F   ; A|B|SELECT|START (button byte low nibble)
PAD_CTRL_PAD equ 0xF0   ; RIGHT|LEFT|UP|DOWN (D-pad high nibble)

; ---------------------------------------------------------------------------
; EnterMapBoot — port-only ONE-TIME overworld boot glue (runs once per game boot).
; Both boot callers (init.asm SKIP_TITLE, title.asm, main_menu.asm SpecialEnterMap)
; jmp here; it loads the port's embedded overworld assets / player sprite / name
; defaults / text engine / toggleable-object flags that pret handles elsewhere in
; its new-game init, then falls into the faithful EnterMap. It must NOT be re-entered
; on warp/battle-return (those go through EnterMap directly).
; ---------------------------------------------------------------------------
EnterMapBoot:
    call LoadOverworldAssets
    call SetupPlayerSprite
%ifdef SKIP_TITLE
    ; Title screen (which normally seeds wPlayerName / wRivalName) was skipped —
    ; seed the build-time defaults so <PLAYER>/<RIVAL> don't print garbage.
    lea esi, [DefaultPlayerName]
    lea edi, [ebp + W_PLAYER_NAME]
    mov ecx, PLAYER_NAME_FIELD
    rep movsb
    lea esi, [DefaultRivalName]
    lea edi, [ebp + W_RIVAL_NAME]
    mov ecx, PLAYER_NAME_FIELD
    rep movsb
%endif
    ; Initialize the <DONE> sentinel (DONE_SENTINEL_WRAM = TX_END). Normally done by
    ; the title screen; SKIP_TITLE bypasses that, leaving the sentinel as garbage so
    ; any CHAR_DONE-terminated dialog ran off into a bogus TX_BOX → page fault.
    call text_engine_init
    call InitToggleableObjectFlags     ; seed global event/visibility flags to defaults
    ; fall into EnterMap

; ---------------------------------------------------------------------------
; EnterMap — faithful map (re-)entry. Pret ref: home/overworld.asm:1-41 (EnterMap).
; Sets wJoyIgnore, loads the map, clears per-map scratch, then runs the fly/warp/
; battle-return reset ladder before falling into OverworldLoop. Re-entered on every
; warp/battle-return (OW-A.4(b) routes those paths back here).
;
; Tripwire (OW-A.4): the DEBUG dump harnesses stay IMMEDIATELY after LoadMapData,
; BEFORE the resets. Every FRAME.BIN-baseline DEBUG build (DEBUG_BASELINE/
; DEBUG_TRANSITION/DEBUG_WALK_NORTH) dump-and-exits inside its harness, so the resets
; below NEVER run under those builds — the 3 baselines must stay byte-identical,
; proving the render/transition path is untouched. Resets run only in the real build.
; ---------------------------------------------------------------------------
EnterMap:
    ; ld a, PAD_BUTTONS | PAD_CTRL_PAD / ld [wJoyIgnore], a
    mov byte [ebp + W_JOY_IGNORE], PAD_BUTTONS | PAD_CTRL_PAD
%ifdef DEBUG_SEAM
    ; Seam-crossing trace harness: spawn on the target map next to a connection
    ; edge, walk into it with the REAL movement primitives, and sample state every
    ; frame into SEAMLOG.BIN. Must seed wCurMap/coords BEFORE LoadMapData reads them.
    ;
    ; Default target is the Viridian City <-> Route 22 (west) seam, the reported
    ; repro. wStatusFlags4 BIT_NO_BATTLES suppresses wild encounters through the
    ; engine's own gate (NewBattle checks it) rather than by de-wiring the call —
    ; keeps the seam-crossing trace deterministic (no random battle mid-walk).
    ; (W-1, the old battle-return tile-cache clobber, is now fixed — commit 02cf0d2f.)
%ifndef DEBUG_SEAM_MAP
%define DEBUG_SEAM_MAP 0x01               ; VIRIDIAN_CITY
%endif
%ifndef DEBUG_SEAM_X
%define DEBUG_SEAM_X 3                    ; 3 tiles from the west edge
%endif
%ifndef DEBUG_SEAM_Y
%define DEBUG_SEAM_Y 16                   ; inside Route 22's strip (Viridian y 8..25)
%endif
%ifndef DEBUG_SEAM_STEPS
%define DEBUG_SEAM_STEPS 8                ; x: 3,2,1,0,255(cross),then 3 more in Route 22
%endif
%ifndef DEBUG_SEAM_DIR
%define DEBUG_SEAM_DIR 0                  ; 0 = walk west, 1 = walk east
%endif
%if DEBUG_SEAM_DIR
%define SEAM_XVEC 0x01
%define SEAM_PDIR PLAYER_DIR_RIGHT
%define SEAM_FACE SPRITE_FACING_RIGHT
%else
%define SEAM_XVEC 0xFF
%define SEAM_PDIR PLAYER_DIR_LEFT
%define SEAM_FACE SPRITE_FACING_LEFT
%endif
    ; ONE-SHOT: OverworldLoop re-enters EnterMap on every map transition, so the
    ; seed must only fire on the first entry — otherwise a crossing teleports the
    ; player straight back to the spawn and the seam can never be left.
    cmp byte [seam_seeded], 0
    jne .seam_no_seed
    mov byte [seam_seeded], 1
    or byte [ebp + W_STATUS_FLAGS_4], (1 << BIT_NO_BATTLES)
    mov byte [ebp + W_CUR_MAP],  DEBUG_SEAM_MAP
    mov byte [ebp + W_X_COORD],  DEBUG_SEAM_X
    mov byte [ebp + W_Y_COORD],  DEBUG_SEAM_Y
    ; $FF = "not a warp arrival": LoadTilesetHeader's faithful tail otherwise
    ; re-derives the coords from the stale wDestinationWarpID on any dungeon-
    ; tileset map (e.g. a seeded Viridian Forest spawned at warp 0's (1,0)).
    mov byte [ebp + W_DESTINATION_WARP_ID], 0xFF
    mov byte [seam_reseat], 1             ; hand-seeded coords need the view ptr derived
.seam_no_seed:
%endif
%ifdef DEBUG_NO_WILD
    ; Debug: suppress wild encounters via the game's own flag (wStatusFlags4
    ; BIT_NO_BATTLES — the same gate NewBattle already honours). Re-set on every
    ; EnterMap so it survives StartNewGame's WRAM clear on a fully normal boot
    ; (title screen intact). Trainer/forced battles are unaffected.
    or byte [ebp + W_STATUS_FLAGS_4], (1 << BIT_NO_BATTLES)
%endif
    call LoadMapData
%ifdef DEBUG_SEAM
    cmp byte [seam_reseat], 0
    je .seam_no_reseat
    mov byte [seam_reseat], 0
    call SeamReseatView                   ; LoadMapData does not derive the view ptr
.seam_no_reseat:
%ifdef DEBUG_SEAM_LIVE
    ; Live mode: no scripted walk. Fall through to the real OverworldLoop so the
    ; player drives with the keyboard and COLLISION IS LIVE (the scripted harness
    ; bypasses it, and its traces came back clean). frame.asm samples every frame;
    ; pressing A writes SEAMLOG.BIN + FRAME.BIN and exits. Drive to the spot that
    ; reproduces, then press A.
%else
    mov ecx, DEBUG_SEAM_STEPS
.seam_step:
    push ecx
    mov byte [ebp + W_SPRITE_PLAYER_Y_STEP_VECTOR], 0
    mov byte [ebp + W_SPRITE_PLAYER_X_STEP_VECTOR], SEAM_XVEC
    mov byte [ebp + W_PLAYER_DIRECTION],        SEAM_PDIR
    mov byte [ebp + W_PLAYER_MOVING_DIRECTION], SEAM_PDIR
    mov byte [ebp + W_SPRITE_PLAYER_FACING_DIR], SEAM_FACE
    mov byte [ebp + W_WALK_COUNTER], 8
.seam_frames:
    call UpdateSprites
    call AdvancePlayerSprite
    pushf                                 ; CF=1 => CheckMapConnections fired
    call DelayFrame
    call SeamLogRecord                    ; one sample per rendered frame
    popf
    jc .seam_crossed
    cmp byte [ebp + W_WALK_COUNTER], 0
    jne .seam_frames
    pop ecx
    dec ecx
    jnz .seam_step
    jmp .seam_done                        ; never reached the edge

.seam_crossed:
    ; Mimic OverworldLoop's .mapTransition: a crossing reloads the whole map.
    ; Keep walking afterwards so post-crossing oscillation is visible in the log.
    pop ecx
    call LoadMapData
    call SeamLogRecord                    ; marker: first sample on the new map
    mov ecx, DEBUG_SEAM_STEPS
.seam_after:
    push ecx
    mov byte [ebp + W_SPRITE_PLAYER_Y_STEP_VECTOR], 0
    mov byte [ebp + W_SPRITE_PLAYER_X_STEP_VECTOR], SEAM_XVEC
    mov byte [ebp + W_PLAYER_DIRECTION],        SEAM_PDIR
    mov byte [ebp + W_PLAYER_MOVING_DIRECTION], SEAM_PDIR
    mov byte [ebp + W_SPRITE_PLAYER_FACING_DIR], SEAM_FACE
    mov byte [ebp + W_WALK_COUNTER], 8
.seam_after_frames:
    call UpdateSprites
    call AdvancePlayerSprite
    call DelayFrame
    call SeamLogRecord
    cmp byte [ebp + W_WALK_COUNTER], 0
    jne .seam_after_frames
    pop ecx
    dec ecx
    jnz .seam_after
.seam_done:
    call DumpSeamLog                      ; SEAMLOG.BIN (returns)
    call DumpBackbuffer                   ; FRAME.BIN: the final screen — then exits
%endif ; DEBUG_SEAM_LIVE
%endif ; DEBUG_SEAM
%ifdef DEBUG_DUMP
    call DebugDumpMemory     ; dump GB memory to DUMP.BIN, then exit (debug only)
%endif
%ifdef DEBUG_WALK_NORTH
    ; Walk-simulation harness: drive the REAL movement primitives north for
    ; DEBUG_WALK_STEPS steps (default 8: wYCoord 8 -> 0, the north edge), then
    ; dump the frame. Reveals where the player is VISUALLY when it reaches the
    ; map edge / when CheckMapConnections fires — i.e. whether the transition
    ; triggers at an appropriate point. Collision is skipped so the walk is
    ; unconditional. If a crossing fires mid-walk, we dump immediately.
    ;
    ; The spawn (tile 8,8 = Pallet block col 4) sits under a tree at block-row 0,
    ; so a blind straight-north walk drove the player THROUGH the tree and off the
    ; top edge into the OOB-clamped region (collision is skipped). Pre-walk east
    ; onto the passable north-exit column first so the northward walk stays on
    ; valid tiles and crosses into Route 1 legitimately.
%ifndef DEBUG_WALK_STEPS
%define DEBUG_WALK_STEPS 8
%endif
%ifndef DEBUG_WALK_EAST_STEPS
%define DEBUG_WALK_EAST_STEPS 2
%endif
    mov ecx, DEBUG_WALK_EAST_STEPS
.we_step:
    push ecx
    mov byte [ebp + W_SPRITE_PLAYER_Y_STEP_VECTOR], 0
    mov byte [ebp + W_SPRITE_PLAYER_X_STEP_VECTOR], 1     ; +1 (east)
    mov byte [ebp + W_PLAYER_DIRECTION],        PLAYER_DIR_RIGHT
    mov byte [ebp + W_PLAYER_MOVING_DIRECTION], PLAYER_DIR_RIGHT
    mov byte [ebp + W_SPRITE_PLAYER_FACING_DIR], SPRITE_FACING_RIGHT
    mov byte [ebp + W_WALK_COUNTER], 8
.we_frames:
    call UpdateSprites
    call AdvancePlayerSprite
    call DelayFrame
    cmp byte [ebp + W_WALK_COUNTER], 0
    jne .we_frames
    pop ecx
    dec ecx
    jnz .we_step

    mov ecx, DEBUG_WALK_STEPS
.wn_step:
    push ecx
    mov byte [ebp + W_SPRITE_PLAYER_Y_STEP_VECTOR], 0xFF   ; -1 (north)
    mov byte [ebp + W_SPRITE_PLAYER_X_STEP_VECTOR], 0
    mov byte [ebp + W_PLAYER_DIRECTION],        PLAYER_DIR_UP
    mov byte [ebp + W_PLAYER_MOVING_DIRECTION], PLAYER_DIR_UP
    mov byte [ebp + W_SPRITE_PLAYER_FACING_DIR], SPRITE_FACING_UP
    mov byte [ebp + W_WALK_COUNTER], 8
.wn_frames:
    call UpdateSprites
    call AdvancePlayerSprite
    jc .wn_crossed                ; CF=1 → CheckMapConnections fired this step
    call DelayFrame
    cmp byte [ebp + W_WALK_COUNTER], 0
    jne .wn_frames
    pop ecx
    dec ecx
    jnz .wn_step
    call DumpBackbuffer           ; reached edge without crossing — dump it
.wn_crossed:
    pop ecx                       ; (balance stack; ecx unused after)
    call DumpBackbuffer           ; dump the frame at the moment of crossing
%endif
%ifdef DEBUG_TRANSITION
    ; Deterministic transition test: simulate stepping off the north edge of
    ; Pallet Town (wYCoord wraps to 255), run the real CheckMapConnections, then
    ; the same reload .mapTransition does. Lets us screenshot the post-crossing
    ; render of Route 1's bottom without keyboard input.
%ifndef DEBUG_BASELINE
    mov byte [ebp + W_X_COORD], 8
    mov byte [ebp + W_Y_COORD], 255
    call CheckMapConnections                  ; sets W_CUR_MAP + view ptr for Route 1
%endif
    mov byte [ebp + W_WALK_COUNTER], 0
    mov byte [ebp + W_SPRITE_PLAYER_Y_STEP_VECTOR], 0
    mov byte [ebp + W_SPRITE_PLAYER_X_STEP_VECTOR], 0
    mov byte [ebp + H_SCY], 0
    mov byte [ebp + H_SCX], 0
    mov word [ebp + W_MAP_VIEW_VRAM_POINTER], GB_TILEMAP0
    call LoadMapHeader
    ; OW-A.2 P3b: LoadMapHeader now runs the faithful InitSprites (pret :1892), which
    ; repopulates the NPC slots from the destination map's object binary but leaves
    ; IMAGEBASEOFFSET cleared (that is InitMapSprites' job). The real .mapTransition
    ; (:902/:913) pairs LoadMapHeader with InitMapSprites; this harness claimed to do
    ; "the same reload .mapTransition does" but had OMITTED that InitMapSprites call —
    ; harmless before P3b (LoadMapHeader was sprite-agnostic), required now so the
    ; slots are tile-loaded / IMAGEBASEOFFSET-assigned like the real crossing does.
    call InitMapSprites
    call LoadTileBlockMap
    call LoadCurrentMapView
    ; Render a few frames so GB_BACKBUF holds the post-transition image, then
    ; exfiltrate the exact rendered pixels to FRAME.BIN for host inspection.
    call DelayFrame
    call DelayFrame
    call DelayFrame
    call DumpBackbuffer        ; writes FRAME.BIN then exits (never returns)
%endif
%ifdef DEBUG_DIALOG
    ; Dialog-box position test: fill GB_TILEMAP1 rows 0-5 with a checkerboard of
    ; tile IDs 0x50/0x51 (visible non-blank), show the window at the centered-bottom
    ; position (WY=152, WX=87), render 3 frames, dump FRAME.BIN.
    ; Tests Bug 2 (window at bottom, centered) and that the window renders at all.
    lea edi, [ebp + GB_TILEMAP1]
    mov ecx, 6 * 32                        ; 6 rows × 32 tiles = 192 bytes
    xor eax, eax
.dd_fill:
    mov byte [edi], 0x50
    inc edi
    mov byte [edi], 0x51
    inc edi
    sub ecx, 2
    jnz .dd_fill
    mov eax, 87                            ; wx (centered dialog: WX-7=80)
    mov ebx, 152                           ; wy (bottom of viewport)
    mov ecx, SCREEN_W                      ; clip_w = 160px
    mov edx, RENDER_H                      ; max_y = 200
    mov esi, GB_TILEMAP1
    xor edi, edi
    call set_single_window
    call DelayFrame
    call DelayFrame
    call DelayFrame
    call DumpBackbuffer                    ; writes FRAME.BIN, exits
%endif
%ifdef DEBUG_STARTMENU
    call SeedDeterministicPlayerIdentity   ; menu's name row = "RED" (golden spec), not the build define
    call DisplayStartMenu                  ; draws menu, renders one frame, dumps FRAME.BIN, exits
%endif
%ifdef DEBUG_BAGMENU
    call RunBagMenuTest                    ; seed bag, open bag screen, render one frame, dump FRAME.BIN, exits
%endif
%ifdef DEBUG_BAGMENU_LIVE
    ; Live, interactive: seed a full bag + money, then fall through to the normal
    ; OverworldLoop. Open the bag via START → ITEM (the real path) to exercise the
    ; list, TOSS quantity chooser, YES/NO confirm, and the "TOO IMPORTANT!" notice.
    mov byte [ebp + 0xD162], 0             ; wPartyCount = 0
    mov byte [ebp + 0xD163], 0xFF          ; wPartySpecies sentinel
    mov byte [ebp + 0xD31C], 0             ; wNumBagItems = 0
    mov byte [ebp + 0xD31D], 0xFF          ; wBagItems sentinel
    call PrepareNewGameDebug               ; seed party + bag + money (returns)
%endif
%ifdef DEBUG_SEED_PARTY
    ; Plain playable build with a seeded party: seed a full party + bag + money,
    ; then fall through to the normal OverworldLoop. No frame dump, no exit — reach
    ; the stats screen the real way (START → POKéMON → a mon → STATS), so the render
    ; runs through the faithful .choseStats path (ClearSprites etc.), not the harness.
    mov byte [ebp + 0xD162], 0             ; wPartyCount = 0
    mov byte [ebp + 0xD163], 0xFF          ; wPartySpecies sentinel
    mov byte [ebp + 0xD31C], 0             ; wNumBagItems = 0
    mov byte [ebp + 0xD31D], 0xFF          ; wBagItems sentinel
    call PrepareNewGameDebug               ; seed party + bag + money (returns)
%endif
%ifdef DEBUG_ITEMUSE
    ; Item-USE gate (items-plan Stage 5): the seeded party is at full HP, so knock
    ; party mon 1 (Snorlax) down to 1 HP — that gives the seeded POTION (bag slot 1,
    ; qty 1) a visible effect while leaving the mon status-free, so the ANTIDOTE the
    ; scripted joypad tries next must refuse ("It won't have any effect!").
    ; Current HP is a big-endian word: hi byte first. (gb_constants.inc is not
    ; included here, so the struct offset is spelled out: wPartyMon1 + MON_HP.)
    mov byte [ebp + wPartyMon1 + 0x01], 0
    mov byte [ebp + wPartyMon1 + 0x02], 1
%endif
%ifdef DEBUG_PARTYMENU
    call RunPartyMenuTest                  ; seed party, open party screen, render one frame, dump FRAME.BIN, exits
%endif
%ifdef DEBUG_BATTLE
    call RunBattleTest                     ; seed party+enemy, enter battle, render one frame, dump FRAME.BIN, exits
%endif
%ifdef DEBUG_TEXTBOXID
    call RunTextBoxIDTest                  ; canvas mode, draw text box id, dump FRAME.BIN, exits
%endif
%ifdef DEBUG_LISTMENU
    call RunListMenuTest                   ; seed party+bag, drive generic list menu, dump FRAME.BIN, exits
%endif
%ifdef DEBUG_DRAWBADGES
    call RunDrawBadgesTest                  ; seed badges, draw grid, window it, dump FRAME.BIN, exits
%endif
%ifdef DEBUG_TRAINERCARD
    call RunTrainerCardTest                 ; draw full trainer card, dump FRAME.BIN, exits
%endif
%ifdef DEBUG_OAKSPC
    call RunOaksPCTest                      ; open Oak's PC, dump the dialog FRAME.BIN, exits
%endif
%ifdef DEBUG_LEAGUEPC
    call RunLeaguePCTest                    ; draw HoF-PC dialog (0 teams), dump FRAME.BIN, exits
%endif
%ifdef DEBUG_OPTIONS
    call RunOptionsTest                     ; open OPTION menu, dump FRAME.BIN, exits
%endif
%ifdef DEBUG_PLAYERSPC
    call RunPlayersPCTest                   ; seed+open PlayerPC, dump parent-menu FRAME.BIN, exits
%endif
%ifdef DEBUG_MAINMENU
    call RunMainMenuTest                    ; seed save, draw CONTINUE menu + info panel, dump FRAME.BIN, exits
%endif
%ifdef DEBUG_SAVE
    call RunSaveTest                        ; seed party, run SaveGameData, dump "saved!" FRAME.BIN, exits
%endif
%ifdef DEBUG_NAMINGSCREEN
    call RunNamingScreenTest                ; open PLAYER naming screen, draw grid, dump FRAME.BIN, exits
%endif
%ifdef DEBUG_G1
    call RunPokedexTest                     ; seed seen/owned, draw pokédex CONTENTS list, dump FRAME.BIN, exits
%endif
%ifdef DEBUG_G2
    call RunPokedexEntryTest                ; open RHYDON dex data page (pic+HT/WT), dump FRAME.BIN, exits
%endif
%ifdef DEBUG_I1
    call RunLinkMenuTest                    ; open link cup-select screen (serial stubbed), dump FRAME.BIN, exits
%endif
%ifdef DEBUG_I2
    call RunLinkCupsTest                    ; run cup validators (pass+gated fail), record codes, dump, exits
%endif
%ifdef DEBUG_LEARNMOVE
    call RunLearnMoveTest                  ; force a level-up move-learn, render one frame, dump FRAME.BIN, exits
%endif
%ifdef DEBUG_STATUS
    call RunStatusScreenTest               ; open status screen page 1, render one frame, dump FRAME.BIN, exits
%endif
%ifdef DEBUG_WALKSPEED
    ; Live walk-speed instrumentation: boots normally into OverworldLoop so you can
    ; WALK with the keyboard. WalkSpeedSample (called at each real tile completion)
    ; records ticks-per-tile into $D1E0; pressing Esc dumps DUMP.BIN via DelayFrame's
    ; quit hook. tick_count is the true 60 Hz PIT counter, so avg ticks/tile = 16 →
    ; faithful walk speed; notably < 16 → movement really is too fast.
    ;   $D1E0 first tick   $D1E4 last tick   $D1E8 tiles   $D1EC min Δ   $D1F0 init flag
    mov dword [ebp + 0xD1E0], 0
    mov dword [ebp + 0xD1E4], 0
    mov dword [ebp + 0xD1E8], 0
    mov dword [ebp + 0xD1EC], 0xFFFFFFFF
    mov dword [ebp + 0xD1F0], 0
%endif

    ; --- faithful EnterMap reset ladder (pret home/overworld.asm:6-41) ----------
    ; Placed AFTER the DEBUG harnesses (tripwire): baseline DEBUG builds dump-and-exit
    ; before reaching here, so this only runs in the real build (and live-DEBUG builds
    ; that fall through, e.g. DEBUG_WALKSPEED / DEBUG_BAGMENU_LIVE).

    ; farcall ClearVariablesOnEnterMap
    call ClearVariablesOnEnterMap

    ; ld hl, wStatusFlags2 / bit BIT_WILD_ENCOUNTER_COOLDOWN, [hl]
    ; jr z, .skip / ld a, 3 / ld [wNumberOfNoRandomBattleStepsLeft], a
    test byte [ebp + W_STATUS_FLAGS_2], (1 << BIT_WILD_ENCOUNTER_COOLDOWN)
    jz .skipGivingThreeStepsOfNoRandomBattles
    mov byte [ebp + wNumberOfNoRandomBattleStepsLeft], 3   ; minimum steps between battles
.skipGivingThreeStepsOfNoRandomBattles:

    ; ld hl, wStatusFlags4 / bit BIT_BATTLE_OVER_OR_BLACKOUT, [hl]
    ; res BIT_BATTLE_OVER_OR_BLACKOUT, [hl]
    ; call z, ResetUsingStrengthOutOfBattleBit / call nz, MapEntryAfterBattle
    ; pret tests the bit, then `res`es it before the two conditional calls; in x86 the
    ; `res` (and [mem]) would clobber the ZF the calls read, so capture the tested bit
    ; into CL first, then res, then branch on CL.
    test byte [ebp + W_STATUS_FLAGS_4], (1 << BIT_BATTLE_OVER_OR_BLACKOUT)
    setnz cl                                               ; cl=1 if returning from a battle
    and byte [ebp + W_STATUS_FLAGS_4], ~(1 << BIT_BATTLE_OVER_OR_BLACKOUT)
    test cl, cl
    jnz .mapEntryAfterBattle
    call ResetUsingStrengthOutOfBattleBit                  ; z: normal (non-battle) entry
    jmp .afterBattleReturnCheck
.mapEntryAfterBattle:
    call MapEntryAfterBattle                               ; nz: post-battle re-entry
.afterBattleReturnCheck:

    ; ld hl, wStatusFlags6 / ld a, [hl] / and (1<<FLY_WARP)|(1<<DUNGEON_WARP)
    ; jr z, .didNot... / farcall EnterMapAnim / call UpdateSprites
    ; res FLY_WARP,[wStatusFlags6] / res NO_BATTLES,[wStatusFlags4]
    test byte [ebp + W_STATUS_FLAGS_6], (1 << BIT_FLY_WARP) | (1 << BIT_DUNGEON_WARP)
    jz .didNotEnterUsingFlyWarpOrDungeonWarp
    call EnterMapAnim
    call UpdateSprites
    and byte [ebp + W_STATUS_FLAGS_6], ~(1 << BIT_FLY_WARP)
    and byte [ebp + W_STATUS_FLAGS_4], ~(1 << BIT_NO_BATTLES)
.didNotEnterUsingFlyWarpOrDungeonWarp:

    ; call IsSurfingPikachuInParty
    call IsSurfingPikachuInParty
    ; farcall CheckForceBikeOrSurf (player_state.asm — LINKED as of the wild-live
    ; promotion; the PLAYER_STATE_LINKED gate is retired).
    call CheckForceBikeOrSurf ; handle SF-island currents / forced cycling-road bike

    ; ld hl, wStatusFlags6 / bit BIT_DUNGEON_WARP,[hl] / res BIT_DUNGEON_WARP,[hl]
    ; (pret's bit test result is unused here — just clear the bit)
    and byte [ebp + W_STATUS_FLAGS_6], ~(1 << BIT_DUNGEON_WARP)
    ; ld hl, wStatusFlags3 / res BIT_NO_NPC_FACE_PLAYER, [hl]
    and byte [ebp + W_STATUS_FLAGS_3], ~(1 << BIT_NO_NPC_FACE_PLAYER)

    ; call UpdateSprites
    call UpdateSprites

    ; ld hl, wCurrentMapScriptFlags / set CUR_MAP_LOADED_1,[hl] / set CUR_MAP_LOADED_2,[hl]
    or byte [ebp + W_CURRENT_MAP_SCRIPT_FLAGS], (1 << BIT_CUR_MAP_LOADED_1) | (1 << BIT_CUR_MAP_LOADED_2)

    ; xor a / ld [wJoyIgnore], a
    mov byte [ebp + W_JOY_IGNORE], 0
    ; fall through to OverworldLoop

; ---------------------------------------------------------------------------
; OverworldLoop — player-movement frame loop.
; Pret ref: home/overworld.asm:OverworldLoop / OverworldLoopLessDelay (the
; movement-relevant subset; no menus, warps, NPCs, battles, or scripts yet).
;
; Cadence matches the original: two DelayFrame calls per iteration, then one
; AdvancePlayerSprite (2 px scroll) — so a 16 px step takes ~16 frames.
;
; State machine:
;   - mid-walk (wWalkCounter != 0): keep advancing the sprite.
;   - idle: read held D-pad; on a press, set the step vector + facing, run the
;     land collision check, and (if passable) start an 8-frame walk.
; ---------------------------------------------------------------------------
OverworldLoop:
    call RunNPCMovementScript                    ; door-exit auto-walk (BIT_STANDING_ON_DOOR path)
    call RunMapScript                            ; per-frame map _Script (default no-op; Pallet event-gate)
    ; wIgnoreInputCounter countdown now runs faithfully via CountDownIgnoreInputBitReset
    ; (called by TrackPlayTime inside DelayFrame, Wave-2/M2.1). The old inline block that
    ; lived here decremented an extra time per loop (double-decrement) and only cleared
    ; hJoyHeld; the DelayFrame path is per-frame and also clears hJoyPressed. Removed.
    call UpdateSprites                         ; advance player facing + walk animation
    call DelayFrame
    ; --- OverworldLoop falls through into OverworldLoopLessDelay (pret) ---
OverworldLoopLessDelay:                      ; pret: home/overworld.asm:OverworldLoopLessDelay
    call DelayFrame

    cmp byte [ebp + W_WALK_COUNTER], 0
    jne .moveAhead                           ; still mid-step → keep walking

    ; --- idle: clear step vectors, then sample the held D-pad ---
    mov byte [ebp + W_SPRITE_PLAYER_Y_STEP_VECTOR], 0
    mov byte [ebp + W_SPRITE_PLAYER_X_STEP_VECTOR], 0

    ; Check trainer sight lines before reading joypad (pret: CheckTrainerSightLine).
    call CheckTrainerSight
    jnc .noTrainerSight
    call TrainerEncounterFlow
    jmp OverworldLoop
.noTrainerSight:

    ; Simulated joypad state overrides real input (pret: AreInputsSimulated).
    ; BIT_SCRIPTED_MOVEMENT_STATE is armed by PlayerStepOutFromDoor (via
    ; StartSimulatingJoypadStates). AreInputsSimulated (simulate_joypad.asm) pops the
    ; next queued PAD_* byte into H_JOY_HELD while scripted movement is active and
    ; leaves real input untouched otherwise; the door step's flag is then consumed at
    ; .handleDirection below (one-step buffer). H_JOY_HELD is used for A (not
    ; H_JOY_PRESSED): joypad_update runs twice per OverworldLoop idle iteration (one
    ; per DelayFrame), so H_JOY_PRESSED is always cleared before we read it.
    ; Re-trigger after dialog dismiss is prevented by .waitAReleased below.
    call AreInputsSimulated
    movzx eax, byte [ebp + H_JOY_HELD]
    test byte [ebp + W_STATUS_FLAGS_5], (1 << BIT_SCRIPTED_MOVEMENT_STATE)
    jnz .checkPADDown                               ; scripted step: skip START/A, go to D-pad
.checkJoyDisable:
    test byte [ebp + W_STATUS_FLAGS_5], (1 << BIT_DISABLE_JOYPAD)
    jnz .noDirection                            ; input suppressed during warp-arrival window

    ; START-press: open the start menu (pret: OverworldLoopLessDelay TEXT_START_MENU).
    ; Read from H_JOY_HELD like the A-press below; DisplayStartMenu's close path waits
    ; for START release before returning, so a held START can't re-open it next frame.
    test al, PAD_START
    jz .checkAPress
    call DisplayStartMenu
    jmp OverworldLoop
.checkAPress:

    ; A-press: check for NPC or sign. EAX = H_JOY_HELD (level-triggered, reliable).
    test al, PAD_A
    jz .checkPADDown
    call CheckNPCInteraction
    test al, al
    jz .checkPADDown                           ; no NPC/sign found → fall to D-pad

    ; Interaction handled. Wait for A to be released before restarting to prevent
    ; the next OverworldLoop iteration from re-triggering while A is still held.
.waitAReleased:
    call DelayFrame
    test byte [ebp + H_JOY_HELD], PAD_A
    jnz .waitAReleased
    jmp OverworldLoop

.checkPADDown:                                  ; EAX = H_JOY_HELD from above
    test al, PAD_DOWN
    jz .checkUp
    mov byte [ebp + W_SPRITE_PLAYER_Y_STEP_VECTOR], 1
    mov dl, PLAYER_DIR_DOWN
    mov dh, SPRITE_FACING_DOWN
    jmp .handleDirection
.checkUp:
    test al, PAD_UP
    jz .checkLeft
    mov byte [ebp + W_SPRITE_PLAYER_Y_STEP_VECTOR], 0xFF   ; -1
    mov dl, PLAYER_DIR_UP
    mov dh, SPRITE_FACING_UP
    jmp .handleDirection
.checkLeft:
    test al, PAD_LEFT
    jz .checkRight
    mov byte [ebp + W_SPRITE_PLAYER_X_STEP_VECTOR], 0xFF   ; -1
    mov dl, PLAYER_DIR_LEFT
    mov dh, SPRITE_FACING_LEFT
    jmp .handleDirection
.checkRight:
    test al, PAD_RIGHT
    jz .noDirection                          ; nothing held → idle (stop animating)
    mov byte [ebp + W_SPRITE_PLAYER_X_STEP_VECTOR], 1
    mov dl, PLAYER_DIR_RIGHT
    mov dh, SPRITE_FACING_RIGHT

.handleDirection:
    ; Always commit the new direction/facing — this happens even on turn-only presses.
    mov [ebp + W_PLAYER_DIRECTION],         dl
    mov [ebp + W_PLAYER_MOVING_DIRECTION],  dl
    mov [ebp + W_SPRITE_PLAYER_FACING_DIR], dh

    ; pret: bit BIT_SCRIPTED_MOVEMENT_STATE, a / jr nz, .noDirectionChange
    ; Scripted movement (door auto-walk) bypasses the 180° turn-delay entirely.
    test byte [ebp + W_STATUS_FLAGS_5], (1 << BIT_SCRIPTED_MOVEMENT_STATE)
    jz .notScripted
    and byte [ebp + W_STATUS_FLAGS_5], ~(1 << BIT_SCRIPTED_MOVEMENT_STATE)
    jmp .walkStart
.notScripted:

    ; Turn delay (pret: wCheckFor180DegreeTurn / wPlayerLastStopDirection).
    ; First press after idle with a NEW direction: update facing but don't walk.
    ; Second press (same direction, or same as last-stop dir): walk normally.
    cmp byte [ebp + W_CHECK_FOR_TURN], 0
    je .walkStart                             ; already committed to walking direction
    mov byte [ebp + W_CHECK_FOR_TURN], 0     ; consume the turn-check token
    cmp dl, [ebp + W_PLAYER_LAST_STOP_DIRECTION]
    je .walkStart                             ; same direction → walk normally
    ; Turn-only press (pret home/overworld.asm:186-199): facing was updated above;
    ; don't walk. OW-A.6 faithful turn tail: arm the Pikachu-collision grace
    ; counter, flag the in-place turn for this frame (.moveAhead clears it), and —
    ; pret :197 — roll a wild encounter on the turn itself (turning in grass can
    ; trigger a battle).
    mov byte [ebp + wPikachuCollisionCounter], 8
    or byte [ebp + wMiscFlags], (1 << BIT_TURNING)   ; set BIT_TURNING, [hl]
    call NewBattle                            ; CF=1 → a battle occurred on the turn
    jc .battleOccurred
    jmp OverworldLoop                         ; turn only — no step

.walkStart:
    ; OW-A.6 (pret .noDirectionChange, home/overworld.asm:203-226): while surfing
    ; (wWalkBikeSurfState == 2) collision routes through CollisionCheckOnWater;
    ; on land through CollisionCheckOnLand. Inert in today's live build — nothing
    ; sets state 2 until Surf item-use / ForceBikeOrSurf links (player_gfx.asm).
    cmp byte [ebp + W_WALK_BIKE_SURF_STATE], 2 ; surfing?
    jne .collisionOnLand
    call CollisionCheckOnWater                ; CF=1 → blocked on water
    jc OverworldLoop                          ; pret .surfing: jp c, OverworldLoop
    jmp .startWalk                            ; water clear → begin the step
.collisionOnLand:
    call CollisionCheckOnLand                 ; CF=1 → blocked
    jnc .startWalk

    ; Blocked. Collision-exit path (pret: bit BIT_STANDING_ON_WARP / ExtraWarpCheck).
    ; Only attempt exit if player IS on a warp tile (set at spawn by LoadWarpDestination
    ; or after a step by .moveAhead). BIT_EXITING_DOOR is NOT checked here — pret does
    ; not suppress collision-exit during the auto-walk window.
    test byte [ebp + W_MOVEMENT_FLAGS], (1 << BIT_STANDING_ON_WARP)
    jz OverworldLoop
    ; M7.4: faithful ExtraWarpCheck (pret home/overworld.asm:ExtraWarpCheck +
    ; jp c, CheckWarpsCollision). Replaces the hardcoded "facing DOWN" test with
    ; pret's per-map function-1 (IsPlayerFacingEdgeOfMap) / function-2
    ; (IsWarpTileInFrontOfPlayer) dispatch. Register-safe (returns only CF); DL
    ; is no longer consulted here. CheckWarpTile below is the port's
    ; CheckWarpsCollision (scans W_WARP_ENTRIES by the player's current coords).
    call ExtraWarpCheck
    jnc OverworldLoop
    call CheckWarpTile
    jnc OverworldLoop
    jmp .warpTransition

.startWalk:
    mov byte [ebp + W_WALK_COUNTER], 8        ; begin an 8-frame step
    jmp .moveAhead                             ; pret: jr .moveAhead2 — advance immediately, no extra delay

.noDirection:
    ; Save the last-used moving direction so the next press can check for a turn.
    ; (Pret: .noDirectionButtonsPressed — saves wPlayerMovingDirection to
    ; wPlayerLastStopDirection, zeroes moving dir, sets wCheckFor180DegreeTurn=1.)
    mov al, [ebp + W_PLAYER_MOVING_DIRECTION]
    mov [ebp + W_PLAYER_LAST_STOP_DIRECTION], al
    mov byte [ebp + W_PLAYER_MOVING_DIRECTION], 0
    mov byte [ebp + W_CHECK_FOR_TURN], 1
    jmp OverworldLoop

.moveAhead:
    ; pret .moveAhead2 head (home/overworld.asm:243-248): clear the in-place-turn
    ; flag + Pikachu-collision grace counter, then the bike double-step, then
    ; advance. DoBikeSpeedup is live but inert (wWalkBikeSurfState is never 1
    ; until Bicycle use / ForceBikeOrSurf links). OW-A.6.
    and byte [ebp + wMiscFlags], ~(1 << BIT_TURNING) & 0xFF  ; res BIT_TURNING, [hl]
    mov byte [ebp + wPikachuCollisionCounter], 0
    call DoBikeSpeedup
    call AdvancePlayerSprite
    jc .mapTransition
    cmp byte [ebp + W_WALK_COUNTER], 0
    jne OverworldLoop
%ifdef DEBUG_WALKSPEED
    call WalkSpeedSample                       ; tile just completed → record ticks/tile
%endif
    ; --- M7.1/OW-A.6: step count + wild-encounter gate (pret home/overworld.asm:249-268) ---
    ; The tile step just finished. pret runs StepCountCheck here, then (after
    ; poison/safari, deferred) NewBattle, taking the warp checks only when no battle
    ; occurred. StepCountCheck decrements the WRAM step counters — including
    ; wNumberOfNoRandomBattleStepsLeft, the post-battle 3-step encounter-free window
    ; that NewBattle's DetermineWildOpponent gate reads. Wild encounters are LIVE
    ; (the WILD_ENCOUNTERS_LIVE gate is retired).
    call StepCountCheck
    call NewBattle                            ; CF=1 → a wild/forced battle occurred
    jnc .noBattleOccurred                     ; pret: jp nc, CheckWarpsNoCollision
.battleOccurred:
    ; pret .battleOccurred (home/overworld.asm:269-296) — reached from the
    ; post-step NewBattle above and the on-turn NewBattle in .handleDirection.
    and byte [ebp + W_STATUS_FLAGS_3], ~(1 << BIT_TALKED_TO_TRAINER) & 0xFF
    and byte [ebp + W_STATUS_FLAGS_7], ~(1 << BIT_TRAINER_BATTLE) & 0xFF
    or  byte [ebp + W_CURRENT_MAP_SCRIPT_FLAGS], (1 << BIT_CUR_MAP_LOADED_1) | (1 << BIT_CUR_MAP_LOADED_2)
    mov byte [ebp + H_JOY_HELD], 0            ; xor a / ldh [hJoyHeld], a
    mov al, [ebp + W_CUR_MAP]
    cmp al, CINNABAR_GYM
    jne .notCinnabarGym
    SetEvent EVENT_2A7
.notCinnabarGym:
    or byte [ebp + W_STATUS_FLAGS_4], (1 << BIT_BATTLE_OVER_OR_BLACKOUT)
    mov al, [ebp + W_CUR_MAP]
    cmp al, OAKS_LAB
    je .noFaintCheck                          ; no blackout after losing to the rival in Oak's lab
    call AnyPartyAlive                        ; DH = OR of every party mon's HP bytes
    test dh, dh                               ; ld a, d / and a
    jz .allFainted
.noFaintCheck:
    mov bl, 10                                ; ld c, 10 (DelayFrames: BL = frame count)
    call DelayFrames
    jmp EnterMap                              ; full map re-entry (reset ladder, OW-A.4)
.allFainted:
    jmp AllPokemonFainted                     ; wild_encounter_check.asm → HandleBlackOut
.noBattleOccurred:
    ; pret CheckWarpsNoCollision (home/overworld.asm:360-417). The coord scan is
    ; CheckWarpTile (the port's CheckWarpsNoCollisionLoop); for the matched entry
    ; pret sets BIT_STANDING_ON_WARP, then fires on
    ; IsPlayerStandingOnDoorTileOrWarpTile (CF=1 → WarpFound1) and otherwise on
    ; ExtraWarpCheck. The `res` precedes the scan (pret does it at :267).
    and byte [ebp + W_MOVEMENT_FLAGS], ~(1 << BIT_STANDING_ON_WARP)
    call CheckWarpTile
    jnc OverworldLoop                         ; no coord match → bit stays cleared
    or byte [ebp + W_MOVEMENT_FLAGS], (1 << BIT_STANDING_ON_WARP)
    call IsPlayerStandingOnDoorTileOrWarpTile ; may `res` the bit for a warp carpet
    jc .warpTransition                        ; pret: jr c, WarpFound1
    call ExtraWarpCheck
    jnc OverworldLoop                         ; pret: jr nc, ...Retry2 (no other match)
.warpTransition:
    ; BL = resolved destination map; W_DESTINATION_WARP_ID = 0-based spawn warp index
    ; Only update W_LAST_MAP when leaving an outdoor map (mirrors pret CheckIfInOutsideMap).
    ; Indoor→indoor and indoor→outdoor transitions must NOT overwrite W_LAST_MAP or the
    ; 0xFF warp-destination resolver will return an indoor map instead of Pallet Town.
    ; ; DIVERGENCE: this is the `W_CUR_MAP < FIRST_INDOOR_MAP_ID` heuristic, NOT pret's
    ; tileset-based CheckIfInOutsideMap (OVERWORLD/PLATEAU → outside). The two disagree
    ; for edge maps (e.g. Route 23 / Indigo Plateau use the PLATEAU tileset but sit above
    ; FIRST_INDOOR_MAP_ID), so those would be misclassified here.
    ; ; TODO(edge-maps): switch this test to `call CheckIfInOutsideMap` (warp_check.asm,
    ; already global + faithful) when Route 23 / Plateau warping is exercised.
    mov al, [ebp + W_CUR_MAP]
    cmp al, FIRST_INDOOR_MAP_ID
    jae .skipLastMapUpdate
    mov [ebp + W_LAST_MAP], al
.skipLastMapUpdate:
    mov [ebp + W_CUR_MAP], bl
    ; Update text table dispatch for the new map.
    movzx eax, byte [ebp + W_CUR_MAP]
    lea esi, [MapTextTablePointers]
    mov esi, [esi + eax*4]
    mov [w_map_text_table_ptr], esi
    mov byte [ebp + W_WALK_COUNTER], 0
    mov byte [ebp + W_SPRITE_PLAYER_Y_STEP_VECTOR], 0
    mov byte [ebp + W_SPRITE_PLAYER_X_STEP_VECTOR], 0
    mov byte [ebp + H_SCY], 0
    mov byte [ebp + H_SCX], 0
    mov word [ebp + W_MAP_VIEW_VRAM_POINTER], GB_TILEMAP0
    ; pret WarpFound2 plays the map-change jingle here (:477/498/510), BEFORE the
    ; destination is loaded, so it reads the SOURCE map's tileset + door tile. Must
    ; precede LoadWarpDestination (which calls LoadMapHeader → destination tileset/
    ; tilemap + music). OW-A.14. Warp-pad/fly skip branch is deferred, so the single
    ; call here matches pret's 3 non-skip branches.
    call PlayMapChangeSound
    call LoadWarpDestination
    call InitMapSprites                        ; populate NPC slots for the new map
    ; pret: home/overworld.asm:515 (WarpFound2.indoorMaps) — clear BIT_EXITING_DOOR,
    ; then set BIT_STANDING_ON_DOOR to trigger RunNPCMovementScript→PlayerStepOutFromDoor
    ; on the next idle frame. PlayerStepOutFromDoor re-sets BIT_EXITING_DOOR only if the
    ; arrival tile is a door tile; stair arrivals leave it clear.
    and byte [ebp + W_MOVEMENT_FLAGS], ~(1 << BIT_EXITING_DOOR)
    or byte [ebp + W_MOVEMENT_FLAGS], (1 << BIT_STANDING_ON_DOOR)
    call IgnoreInputForHalfSecond
    ; OW-A.4(b): re-enter EnterMap on every warp, faithful to pret WarpFound2.done
    ; (home/overworld.asm:517, `jp EnterMap`). The pre-work above (wCurMap/wLastMap,
    ; LoadWarpDestination, view/scroll reset, door flags) mirrors WarpFound2's body;
    ; EnterMap then re-runs the full reset ladder — wJoyIgnore gate, LoadMapData
    ; (re-loads header/blocks/view/sprites for the new map), ClearVariablesOnEnterMap,
    ; the fly/dungeon-warp & battle-return resets, UpdateSprites, CUR_MAP_LOADED_1/2 —
    ; which the old `jmp OverworldLoop` silently skipped. The RunNPCMovementScript
    ; PlayerStepOutFromDoor still fires on the first post-warp idle frame (BIT_STANDING_ON_DOOR
    ; set above survives the LoadMapData reload). NOTE: the port's InitMapSprites here is
    ; now partially redundant with LoadMapData's sprite load inside EnterMap — verified
    ; harmless (idempotent slot repopulate), MCP live-warp confirmed.
    jmp EnterMap

.mapTransition:
    ; A connection was crossed — reload everything for the new map.
    mov byte [ebp + W_WALK_COUNTER], 0
    mov byte [ebp + W_SPRITE_PLAYER_Y_STEP_VECTOR], 0
    mov byte [ebp + W_SPRITE_PLAYER_X_STEP_VECTOR], 0

    ; Reset scroll and VRAM pointer. During the walk, H_SCY/H_SCX accumulated
    ; 2 px/frame (e.g. −144 px over 9 north steps). CopyMapViewToVRAM always
    ; writes to GB_TILEMAP0 ($9800), so the PPU must start reading from row 0
    ; (SCY=0). W_MAP_VIEW_VRAM_POINTER must also reset so RedrawRowOrColumn
    ; uses the correct base address on subsequent frames.
    mov byte [ebp + H_SCY], 0
    mov byte [ebp + H_SCX], 0
    mov word [ebp + W_MAP_VIEW_VRAM_POINTER], GB_TILEMAP0

    call LoadMapHeader
    ; pret home/overworld.asm:.loadNewMap (:652-654): LoadMapHeader (loads the new map's
    ; wMapMusicSoundID via the MapSongBanks load above) then fade in that music. Real now
    ; (OW-A.14); unconditional on a connection crossing (not a warp, so no warp gate).
    call PlayDefaultMusicFadeOutCurrent
    ;   ld b, SET_PAL_OVERWORLD / call RunPaletteCommand — palette reload for the new map.
    ;       Deferred to Phase 5 (the port renders a fixed DMG-green palette; SET_PAL_*
    ;       is the GBPalNormal stand-in applied by LoadMapData, not on this LoadMapHeader
    ;       path). Add the real RunPaletteCommand(SET_PAL_OVERWORLD) here when palettes land.
    ; pret also does the Pikachu spawn set (wPikachuOverworldStateFlags bit 4 /
    ;   wPikachuSpawnState = 2) at .loadNewMap — deferred with the Pikachu-follow engine.
    call InitMapSprites                        ; populate NPC slots for the new map
    ; Update text table dispatch for the new map.
    movzx eax, byte [ebp + W_CUR_MAP]
    lea esi, [MapTextTablePointers]
    mov esi, [esi + eax*4]
    mov [w_map_text_table_ptr], esi
    call LoadTileBlockMap
    call LoadCurrentMapView

    jmp OverworldLoopLessDelay

; ---------------------------------------------------------------------------
; ---------------------------------------------------------------------------
; LoadOverworldAssets — Phase 2 scaffold.
; Copies the generated map headers and overworld assets from .rodata into the
; ROM-window area of GB memory (EBP+$4000–$54FF).
; ---------------------------------------------------------------------------
LoadOverworldAssets:
    push esi
    push edi
    push ecx

    ; --- Copy overworld.2bpp to ROM window at OW_GFX_GBADDR ---
    mov esi, overworld_gfx
    lea edi, [ebp + OW_GFX_GBADDR]
    mov ecx, OVERWORLD_GFX_SIZE
    rep movsb

    ; --- Copy overworld.bst to ROM window at OW_BLOCKS_GBADDR ---
    mov esi, overworld_blocks
    lea edi, [ebp + OW_BLOCKS_GBADDR]
    mov ecx, OVERWORLD_BLOCKS_SIZE
    rep movsb

    ; --- Copy map block data to ROM window ---
    mov esi, pallet_town_blk
    lea edi, [ebp + OW_PALLET_BLK_GBADDR]
    mov ecx, PALLET_TOWN_BLK_SIZE
    rep movsb

    mov esi, route1_blk
    lea edi, [ebp + OW_ROUTE1_BLK_GBADDR]
    mov ecx, ROUTE1_BLK_SIZE
    rep movsb

    mov esi, route21_blk
    lea edi, [ebp + OW_ROUTE21_BLK_GBADDR]
    mov ecx, ROUTE21_BLK_SIZE
    rep movsb

    ; --- Copy all remaining OVERWORLD-tileset map block data ---
    mov esi, viridian_city_blk
    lea edi, [ebp + OW_VIRIDIAN_CITY_BLK_GBADDR]
    mov ecx, VIRIDIAN_CITY_BLK_SIZE
    rep movsb

    mov esi, pewter_city_blk
    lea edi, [ebp + OW_PEWTER_CITY_BLK_GBADDR]
    mov ecx, PEWTER_CITY_BLK_SIZE
    rep movsb

    mov esi, cerulean_city_blk
    lea edi, [ebp + OW_CERULEAN_CITY_BLK_GBADDR]
    mov ecx, CERULEAN_CITY_BLK_SIZE
    rep movsb

    mov esi, lavender_town_blk
    lea edi, [ebp + OW_LAVENDER_TOWN_BLK_GBADDR]
    mov ecx, LAVENDER_TOWN_BLK_SIZE
    rep movsb

    mov esi, vermilion_city_blk
    lea edi, [ebp + OW_VERMILION_CITY_BLK_GBADDR]
    mov ecx, VERMILION_CITY_BLK_SIZE
    rep movsb

    mov esi, celadon_city_blk
    lea edi, [ebp + OW_CELADON_CITY_BLK_GBADDR]
    mov ecx, CELADON_CITY_BLK_SIZE
    rep movsb

    mov esi, fuchsia_city_blk
    lea edi, [ebp + OW_FUCHSIA_CITY_BLK_GBADDR]
    mov ecx, FUCHSIA_CITY_BLK_SIZE
    rep movsb

    mov esi, cinnabar_island_blk
    lea edi, [ebp + OW_CINNABAR_ISLAND_BLK_GBADDR]
    mov ecx, CINNABAR_ISLAND_BLK_SIZE
    rep movsb

    mov esi, saffron_city_blk
    lea edi, [ebp + OW_SAFFRON_CITY_BLK_GBADDR]
    mov ecx, SAFFRON_CITY_BLK_SIZE
    rep movsb

    mov esi, route2_blk
    lea edi, [ebp + OW_ROUTE_2_BLK_GBADDR]
    mov ecx, ROUTE2_BLK_SIZE
    rep movsb

    mov esi, route3_blk
    lea edi, [ebp + OW_ROUTE_3_BLK_GBADDR]
    mov ecx, ROUTE3_BLK_SIZE
    rep movsb

    mov esi, route4_blk
    lea edi, [ebp + OW_ROUTE_4_BLK_GBADDR]
    mov ecx, ROUTE4_BLK_SIZE
    rep movsb

    mov esi, route5_blk
    lea edi, [ebp + OW_ROUTE_5_BLK_GBADDR]
    mov ecx, ROUTE5_BLK_SIZE
    rep movsb

    mov esi, route6_blk
    lea edi, [ebp + OW_ROUTE_6_BLK_GBADDR]
    mov ecx, ROUTE6_BLK_SIZE
    rep movsb

    mov esi, route7_blk
    lea edi, [ebp + OW_ROUTE_7_BLK_GBADDR]
    mov ecx, ROUTE7_BLK_SIZE
    rep movsb

    mov esi, route8_blk
    lea edi, [ebp + OW_ROUTE_8_BLK_GBADDR]
    mov ecx, ROUTE8_BLK_SIZE
    rep movsb

    mov esi, route9_blk
    lea edi, [ebp + OW_ROUTE_9_BLK_GBADDR]
    mov ecx, ROUTE9_BLK_SIZE
    rep movsb

    mov esi, route10_blk
    lea edi, [ebp + OW_ROUTE_10_BLK_GBADDR]
    mov ecx, ROUTE10_BLK_SIZE
    rep movsb

    mov esi, route11_blk
    lea edi, [ebp + OW_ROUTE_11_BLK_GBADDR]
    mov ecx, ROUTE11_BLK_SIZE
    rep movsb

    mov esi, route12_blk
    lea edi, [ebp + OW_ROUTE_12_BLK_GBADDR]
    mov ecx, ROUTE12_BLK_SIZE
    rep movsb

    mov esi, route13_blk
    lea edi, [ebp + OW_ROUTE_13_BLK_GBADDR]
    mov ecx, ROUTE13_BLK_SIZE
    rep movsb

    mov esi, route14_blk
    lea edi, [ebp + OW_ROUTE_14_BLK_GBADDR]
    mov ecx, ROUTE14_BLK_SIZE
    rep movsb

    mov esi, route15_blk
    lea edi, [ebp + OW_ROUTE_15_BLK_GBADDR]
    mov ecx, ROUTE15_BLK_SIZE
    rep movsb

    mov esi, route16_blk
    lea edi, [ebp + OW_ROUTE_16_BLK_GBADDR]
    mov ecx, ROUTE16_BLK_SIZE
    rep movsb

    mov esi, route17_blk
    lea edi, [ebp + OW_ROUTE_17_BLK_GBADDR]
    mov ecx, ROUTE17_BLK_SIZE
    rep movsb

    mov esi, route18_blk
    lea edi, [ebp + OW_ROUTE_18_BLK_GBADDR]
    mov ecx, ROUTE18_BLK_SIZE
    rep movsb

    mov esi, route19_blk
    lea edi, [ebp + OW_ROUTE_19_BLK_GBADDR]
    mov ecx, ROUTE19_BLK_SIZE
    rep movsb

    mov esi, route20_blk
    lea edi, [ebp + OW_ROUTE_20_BLK_GBADDR]
    mov ecx, ROUTE20_BLK_SIZE
    rep movsb

    mov esi, route22_blk
    lea edi, [ebp + OW_ROUTE_22_BLK_GBADDR]
    mov ecx, ROUTE22_BLK_SIZE
    rep movsb

    mov esi, route24_blk
    lea edi, [ebp + OW_ROUTE_24_BLK_GBADDR]
    mov ecx, ROUTE24_BLK_SIZE
    rep movsb

    mov esi, route25_blk
    lea edi, [ebp + OW_ROUTE_25_BLK_GBADDR]
    mov ecx, ROUTE25_BLK_SIZE
    rep movsb

    mov esi, route23_blk
    lea edi, [ebp + OW_ROUTE_23_BLK_GBADDR]
    mov ecx, ROUTE23_BLK_SIZE
    rep movsb

    mov esi, indigo_plateau_blk
    lea edi, [ebp + OW_INDIGO_PLATEAU_BLK_GBADDR]
    mov ecx, INDIGO_PLATEAU_BLK_SIZE
    rep movsb

    ; --- Copy Overworld_Coll passable-tile list to ROM window at OW_COLL_GBADDR ---
    mov esi, overworld_coll
    lea edi, [ebp + OW_COLL_GBADDR]
    mov ecx, OVERWORLD_COLL_SIZE
    rep movsb

    ; --- Copy map_headers.inc data to ROM window ---
    mov esi, map_headers_data
    lea edi, [ebp + OW_TILESET_HDR_GBADDR] ; Starts at tileset header
    mov ecx, MAP_HEADERS_DATA_SIZE
    rep movsb

    pop ecx
    pop edi
    pop esi
    ret

; ---------------------------------------------------------------------------
; SetupPlayerSprite — Phase 2 scaffold.
; Initializes the player sprite WRAM variables and starting map. W_CUR_MAP
; must be set here so LoadMapHeader knows which map to load.
; ---------------------------------------------------------------------------
SetupPlayerSprite:
    mov byte [ebp + W_CUR_MAP], MAP_ID_PALLET_TOWN
    mov byte [ebp + W_Y_COORD], 8
    mov byte [ebp + W_X_COORD], 8
    mov byte [ebp + W_Y_BLOCK_COORD], 0
    mov byte [ebp + W_X_BLOCK_COORD], 0
    mov word [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR], PALLET_TOWN_VIEW_PTR

    ; Face down, standing still (no in-progress walk).
    mov byte [ebp + W_SPRITE_PLAYER_FACING_DIR],   SPRITE_FACING_DOWN
    mov byte [ebp + W_PLAYER_DIRECTION],           0
    mov byte [ebp + W_PLAYER_MOVING_DIRECTION],    0
    mov byte [ebp + W_SPRITE_PLAYER_Y_STEP_VECTOR], 0
    mov byte [ebp + W_SPRITE_PLAYER_X_STEP_VECTOR], 0
    mov byte [ebp + W_WALK_COUNTER],               0

    mov byte [ebp + W_SPRITE_PLAYER_PICTURE_ID],      1   ; non-zero → slot in use
    mov byte [ebp + W_SPRITE_PLAYER_IMAGE_BASE_OFFSET], 1 ; player VRAM slot
    mov byte [ebp + W_SPRITE_PLAYER_Y_PIXELS],        0x3C ; fixed screen Y ($3C = GB center 72 - 12)
    mov byte [ebp + W_SPRITE_PLAYER_X_PIXELS],        0x40 ; fixed screen X ($40 = GB center 80 - 16)
    mov byte [ebp + W_SPRITE_PLAYER_IMAGE_INDEX],     SPRITE_FACING_DOWN
    mov byte [ebp + W_SPRITE_PLAYER_INTRA_ANIM],      0
    mov byte [ebp + W_SPRITE_PLAYER_ANIM_FRAME],      0
    mov byte [ebp + W_SPRITE_PLAYER_WALK_ANIM_COUNTER], 0
    mov byte [ebp + W_SPRITE_PLAYER_GRASS_PRIORITY],  0

    mov byte [ebp + W_GRASS_TILE],    0xFF
    mov byte [ebp + W_FONT_LOADED],   0
    mov byte [ebp + W_MOVEMENT_FLAGS], 0

    mov byte [ebp + H_AUTO_BG_TRANSFER_EN],        0
    mov byte [g_player_marker_on], 0
    ret

; ---------------------------------------------------------------------------
; LoadMapData — faithful translation.
; Pret ref: home/overworld.asm:LoadMapData
; ---------------------------------------------------------------------------
LoadMapData:
    call DisableLCD
    call ResetMapVariables
    call LoadTextBoxTilePatterns
    call LoadMapHeader
    ; Dispatch per-map text table: MapTextTablePointers[W_CUR_MAP] → w_map_text_table_ptr.
    movzx eax, byte [ebp + W_CUR_MAP]
    lea esi, [MapTextTablePointers]
    mov esi, [esi + eax*4]
    mov [w_map_text_table_ptr], esi
    call InitMapSprites                 ; pret: InitMapSprites (load sprite tile patterns)
    ; OW-A.5: pret calls LoadScreenRelatedData ONCE (home/overworld.asm:1967) then
    ; CopyMapViewToVRAM. The port's LoadScreenRelatedData (LoadTileBlockMap +
    ; LoadTilesetTilePatternData + LoadCurrentMapView) is idempotent and its
    ; LoadCurrentMapView is the native-render equivalent of pret's trailing
    ; CopyMapViewToVRAM, so one call covers both. (Removed a redundant second call.)
    call LoadScreenRelatedData

    mov byte [ebp + W_UPDATE_SPRITES_ENABLED], 1
    call EnableLCD
    ; pret: ld b, SET_PAL_OVERWORLD / call RunPaletteCommand (home/overworld.asm:1971).
    ; GBPalNormal is the port's palette stand-in (sets the normal DMG BGP the software
    ; PPU reads); TODO-HW: real RunPaletteCommand(SET_PAL_OVERWORLD) rides the Phase-5
    ; palette HAL (DMG-green is debug-only until then).
    call GBPalNormal
    call LoadPlayerSpriteGraphics       ; pret: LoadPlayerSpriteGraphics (:1972)
    ; pret tail (:1975-1985): play this map's default music unless we entered via a
    ; dungeon/fly warp (DUNGEON_WARP|FLY_WARP) or the map suppresses it (NO_MAP_MUSIC).
    ; Bank save/restore around it is a no-op in the flat model. Real now (OW-A.14).
    test byte [ebp + W_STATUS_FLAGS_6], (1 << BIT_DUNGEON_WARP) | (1 << BIT_FLY_WARP)
    jnz .noMapMusic
    test byte [ebp + W_STATUS_FLAGS_7], (1 << BIT_NO_MAP_MUSIC)
    jnz .noMapMusic
    call UpdateMusic6Times
    call PlayDefaultMusicFadeOutCurrent
.noMapMusic:
    ret

; ---------------------------------------------------------------------------
; HandleBlackOut — the whole party fainted: fade out, kill the music, halve the
; money / heal the party, and warp the player to their last Pokémon Center.
; Pret ref: home/overworld.asm:737 (HandleBlackOut, bank 00 — golden 00:0762).
; Does NOT print the "blacked out" message (its caller does).
; Reached from AllPokemonFainted (engine/overworld/wild_encounter_check.asm).
; ---------------------------------------------------------------------------
global HandleBlackOut
HandleBlackOut:
    call GBFadeOutToBlack
    mov al, 0x08                        ; ld a, $08 — fade-out control value
    call StopMusic
    ; ld hl, wStatusFlags4 / res BIT_BATTLE_OVER_OR_BLACKOUT, [hl]
    and byte [ebp + W_STATUS_FLAGS_4], (~(1 << BIT_BATTLE_OVER_OR_BLACKOUT)) & 0xFF
    mov al, 0x01                        ; ld a, BANK(PrepareForSpecialWarp) — golden 01:6042
    call BankswitchCommon               ; flat: records hLoadedROMBank (no MBC write)
    call ResetStatusAndHalveMoneyOnBlackout   ; callfar (flat: direct call)
    call PrepareForSpecialWarp
    call PlayDefaultMusicFadeOutCurrent
    jmp SpecialEnterMap                 ; jp SpecialEnterMap (tail)

; ---------------------------------------------------------------------------
; StopMusic — arm the audio fade-out (AL = wAudioFadeOutControl), stop the music
; engine, wait for the fade to finish, then silence every channel.
; Pret ref: home/overworld.asm:752 (StopMusic, golden 00:0785).
; In: AL = fade-out control value.
;
; DIVERGENCE 1 (audio tick location): on the GB the VBlank ISR advances the audio
; engine, so pret's bare `jr nz, .wait` spin sees wAudioFadeOutControl reach 0.
; The port has no VBlank audio ISR — the tick lives in DelayFrame (→ audio_tick →
; FadeOutAudio, which is what decrements the counter). A bare spin here would
; hang forever, so the wait pumps DelayFrame. Same idiom and same reason as
; home/audio.asm:WaitForSoundToFinish. (engine/overworld/healing_machine.asm
; bounds its copy of this spin instead; pumping is the correct form.)
;
; DIVERGENCE 2 (engine-offline guard): the port has a state the GB does not — the
; audio engine can be OFFLINE (`/NOSOUND`, or any build before audio_init runs;
; audio_tick self-gates on g_audio_engine_online). Offline, FadeOutAudio never
; runs, so nothing would ever clear the byte we just wrote and the wait above
; would spin forever. PlaySound already carries the mirror-image scaffold — it
; swallows requests while offline so WaitForSoundToFinish's spin exits at once —
; but StopMusic writes wAudioFadeOutControl directly, bypassing that. So: offline,
; skip the fade and clear the byte, preserving pret's post-condition
; (wAudioFadeOutControl == 0 on return) for whoever brings the engine online later.
; ---------------------------------------------------------------------------
global StopMusic
StopMusic:
    mov [ebp + wAudioFadeOutControl], al    ; ld [wAudioFadeOutControl], a
    call StopAllMusic
    cmp byte [g_audio_engine_online], 0     ; PORT GUARD — see DIVERGENCE 2
    jz .offline
.wait:
    mov al, [ebp + wAudioFadeOutControl]
    test al, al                             ; and a — fade-out finished?
    jz .done
    call DelayFrame                         ; pump the audio tick (see DIVERGENCE 1)
    jmp .wait
.offline:
    mov byte [ebp + wAudioFadeOutControl], 0 ; no tick will ever clear it
.done:
    jmp StopAllSounds                       ; jp StopAllSounds (tail)

; LoadPlayerSpriteGraphics — RETIRED from this file (wild-live promotion).
; The Phase-2 scaffold that lived here (walking-only, standing tiles → $8000 /
; walking tiles → $8800, plus a `call ClearSprites`) is superseded by the
; faithful pret dispatcher now linked from engine/overworld/player_gfx.asm
; (LoadPlayerSpriteGraphics → Walking/Bike/Surfing → LoadPlayerSpriteGraphicsCommon).
; Same VRAM layout; the scaffold's extra ClearSprites is intentionally NOT carried
; over — pret's LoadPlayerSpriteGraphicsCommon (home/overworld.asm:1775) does not
; clear OAM, and neither does pret's LoadMapData. `player_sprite` (pret RedSprite)
; stays defined here and is exported for player_gfx.asm.

; ---------------------------------------------------------------------------
; ResetMapVariables — faithful translation.
; Pret ref: home/overworld.asm:ResetMapVariables
;
; Sets wMapViewVRAMPointer = vBGMap0 ($9800 → port GB_TILEMAP0), zeroes SCX/SCY
; and walk state.
; ---------------------------------------------------------------------------
ResetMapVariables:
    ; pret home/overworld.asm:2024-2027 — wMapViewVRAMPointer = vBGMap0. Vestigial under
    ; the native-width renderer (dropped/unused; the torus rings are gone), but kept in
    ; lockstep with the other reset sites (EnterMapBoot etc. write GB_TILEMAP0) so the
    ; pointer is never left stale, matching pret's byte-for-byte reset here.
    mov word [ebp + W_MAP_VIEW_VRAM_POINTER], GB_TILEMAP0
    xor al, al
    mov byte [ebp + H_SCY],                       al
    mov byte [ebp + H_SCX],                       al
    mov byte [ebp + W_WALK_COUNTER],              al
    mov byte [ebp + W_UNUSED_CUR_MAP_TILESET_COPY], al
    mov byte [ebp + W_SPRITE_SET_ID],             al
    mov byte [ebp + W_WALK_BIKE_SURF_STATE_COPY], al
    ; Empty the window list on map entry: visibility is count-driven now, so this
    ; guarantees no stale box leaks over the overworld (e.g. the title's
    ; go_to_main_menu path). Dialog/menu code re-populates the list when it opens a
    ; box. The rWY/rWX shadows are parked off-screen for faithfulness.
    call hide_window                    ; count=0; sets H_WY = RENDER_H
    mov byte [ebp + IO_WY], RENDER_H
    mov byte [ebp + IO_WX], 7
    ret

; ---------------------------------------------------------------------------
; LoadScreenRelatedData — faithful translation.
; Pret ref: home/overworld.asm:LoadScreenRelatedData
; ---------------------------------------------------------------------------
LoadScreenRelatedData:
    call LoadTileBlockMap
    call LoadTilesetTilePatternData
    call LoadCurrentMapView
    ret

; ---------------------------------------------------------------------------
; LoadTilesetTilePatternData — faithful translation.
; Pret ref: home/overworld.asm:LoadTilesetTilePatternData
;
; Reads wTilesetGfxPtr (16-bit GB address) and copies $600 bytes (1536) from
; that ROM-window address to vTileset ($9000 = GB_VCHARS2).
; In the flat model wTilesetBank (FarCopyData bank arg) is ignored.
; ---------------------------------------------------------------------------
LoadTilesetTilePatternData:
    mov byte [g_tilecache_dirty], 1     ; VRAM tile data changes → rebuild decode cache
    ; ESI = wTilesetGfxPtr (16-bit GB address, LE word)
    movzx esi, word [ebp + W_TILESET_GFX_PTR]    ; ESI = HL = 0x4000
    mov edx, GB_VCHARS2                            ; EDX = DE = 0x9000 (vTileset)
    mov bx,  0x0600                                ; BX = BC = $600 bytes
    movzx eax, byte [ebp + W_TILESET_BANK]         ; AL = bank (ignored)
    jmp FarCopyData                                ; tail call

; ---------------------------------------------------------------------------
; LoadTileBlockMap — faithful translation.
; Pret ref: home/overworld.asm:LoadTileBlockMap
;
; 1. Fills wOverworldMap with wMapBackgroundTile (border block).
; 2. Copies PalletTown.blk data (from wCurMapDataPtr) into wOverworldMap,
;    offset by MAP_BORDER rows and MAP_BORDER columns.
; 3. Processes N/S/W/E connection strips (all $FF = none for Phase 2).
; ---------------------------------------------------------------------------
LoadTileBlockMap:
    push esi
    push edi
    push ebx
    push ecx

    ; Fill wOverworldMap..wOverworldMapEnd with wMapBackgroundTile
    mov esi, W_OVERWORLD_MAP
    mov bx,  W_OVERWORLD_MAP_SIZE & 0xFFFF
    movzx eax, byte [ebp + W_MAP_BACKGROUND_TILE]
    call FillMemory

    ; HL = ESI = wOverworldMap
    mov esi, W_OVERWORLD_MAP

    ; hMapWidth = wCurMapWidth; hMapStride = width + MAP_BORDER*2
    movzx ecx, byte [ebp + W_CUR_MAP_WIDTH]       ; ECX = width (= 10)
    mov byte [ebp + H_MAP_WIDTH], cl
    add cl, MAP_BORDER * 2                         ; CL = stride (= 16)
    mov byte [ebp + H_MAP_STRIDE], cl

    ; Skip MAP_BORDER rows: ESI += stride * MAP_BORDER
    movzx eax, cl                                  ; EAX = stride
    imul eax, MAP_BORDER                           ; EAX = stride * 3
    add esi, eax                                   ; ESI = row MAP_BORDER start

    ; Skip MAP_BORDER cols: ESI += MAP_BORDER
    add esi, MAP_BORDER                            ; ESI = first cell of map data

    ; DE = wCurMapDataPtr (source: .blk data in ROM window)
    movzx edx, word [ebp + W_CUR_MAP_DATA_PTR]    ; EDX = map .blk GB addr (rom_window.inc)

    ; B (BH) = wCurMapHeight (row count)
    movzx eax, byte [ebp + W_CUR_MAP_HEIGHT]
    mov bh, al

.row_loop:
    push esi                                       ; save row-start write ptr
    movzx ecx, byte [ebp + H_MAP_WIDTH]            ; CL = map width (without border)
.row_inner_loop:
    mov al, byte [ebp + edx]                       ; read block ID from .blk
    inc edx
    mov byte [ebp + esi], al                       ; write block ID to wOverworldMap
    inc esi
    dec cl
    jnz .row_inner_loop
    pop esi                                        ; restore row-start ptr
    movzx eax, byte [ebp + H_MAP_STRIDE]           ; EAX = stride
    add esi, eax                                   ; advance ESI to next row
    dec bh
    jnz .row_loop

    ; --- Border overrides (map-tool C3): hand-authored blocks for the border
    ;     ring, painted in tools/map_editor/editor.py and generated into
    ;     assets/map_border_overrides.inc. Applied BEFORE the connection
    ;     strips so connections always win (the generator also rejects any
    ;     cell inside a strip or the real map area).
    call ApplyMapBorderOverrides

    ; --- Connection strips: copy each connected map's edge into the wOverworldMap
    ;     border. SwitchToMapRomBank is a no-op in the flat model. The strip src
    ;     pointers (CONN_STRIP_SRC) index into the connected maps' block data
    ;     loaded at OW_ROUTE*_BLK_GBADDR. hNorthSouthConnectionStripWidth and the
    ;     connected-map width reuse H_MAP_STRIDE/H_MAP_WIDTH (they are HRAM unions).

.north_connection:
    cmp byte [ebp + W_NORTH_CONNECTED_MAP], MAP_NO_CONNECTION
    je  .south_connection
    movzx esi, word [ebp + W_NORTH_CONNECTED_MAP + CONN_STRIP_SRC]   ; HL = strip src
    movzx edx, word [ebp + W_NORTH_CONNECTED_MAP + CONN_STRIP_DEST]  ; DE = strip dest
    mov al, [ebp + W_NORTH_CONNECTED_MAP + CONN_STRIP_LENGTH]
    mov [ebp + H_MAP_STRIDE], al                                     ; hNSConnectionStripWidth
    mov al, [ebp + W_NORTH_CONNECTED_MAP + CONN_MAP_WIDTH]
    mov [ebp + H_MAP_WIDTH], al                                      ; hNSConnectedMapWidth
    call LoadNorthSouthConnectionsTileMap

.south_connection:
    cmp byte [ebp + W_SOUTH_CONNECTED_MAP], MAP_NO_CONNECTION
    je  .west_connection
    movzx esi, word [ebp + W_SOUTH_CONNECTED_MAP + CONN_STRIP_SRC]
    movzx edx, word [ebp + W_SOUTH_CONNECTED_MAP + CONN_STRIP_DEST]
    mov al, [ebp + W_SOUTH_CONNECTED_MAP + CONN_STRIP_LENGTH]
    mov [ebp + H_MAP_STRIDE], al
    mov al, [ebp + W_SOUTH_CONNECTED_MAP + CONN_MAP_WIDTH]
    mov [ebp + H_MAP_WIDTH], al
    call LoadNorthSouthConnectionsTileMap

.west_connection:
    cmp byte [ebp + W_WEST_CONNECTED_MAP], MAP_NO_CONNECTION
    je  .east_connection
    movzx esi, word [ebp + W_WEST_CONNECTED_MAP + CONN_STRIP_SRC]
    movzx edx, word [ebp + W_WEST_CONNECTED_MAP + CONN_STRIP_DEST]
    movzx ebx, byte [ebp + W_WEST_CONNECTED_MAP + CONN_STRIP_LENGTH] ; B = row count
    mov al, [ebp + W_WEST_CONNECTED_MAP + CONN_MAP_WIDTH]
    mov [ebp + H_MAP_WIDTH], al                                      ; hEWConnectedMapWidth
    call LoadEastWestConnectionsTileMap

.east_connection:
    cmp byte [ebp + W_EAST_CONNECTED_MAP], MAP_NO_CONNECTION
    je  .done
    movzx esi, word [ebp + W_EAST_CONNECTED_MAP + CONN_STRIP_SRC]
    movzx edx, word [ebp + W_EAST_CONNECTED_MAP + CONN_STRIP_DEST]
    movzx ebx, byte [ebp + W_EAST_CONNECTED_MAP + CONN_STRIP_LENGTH]
    mov al, [ebp + W_EAST_CONNECTED_MAP + CONN_MAP_WIDTH]
    mov [ebp + H_MAP_WIDTH], al
    call LoadEastWestConnectionsTileMap

.done:
    pop ecx
    pop ebx
    pop edi
    pop esi
    ret

; ---------------------------------------------------------------------------
; ApplyMapBorderOverrides — write the current map's authored border-ring
; blocks into wOverworldMap (map-tool plan C3; data from
; assets/map_border_overrides.inc, painted via tools/map_editor/editor.py).
;
; Record format per map: runs of `db row, col, len` + len block bytes,
; terminated by 0xFF. row/col are padded-grid coords; dest =
; wOverworldMap + row*(wCurMapWidth + 2*MAP_BORDER) + col.
;
; Called from LoadTileBlockMap between the map-data copy and the connection
; strips (registers are dead there; clobbers EAX/EBX/ECX/EDX/ESI/EDI).
; ---------------------------------------------------------------------------
ApplyMapBorderOverrides:
    movzx eax, byte [ebp + W_CUR_MAP]
    mov esi, [MapBorderOverridePointers + eax*4]  ; flat ptr to run list
    test esi, esi
    jz .done
    movzx ebx, byte [ebp + W_CUR_MAP_WIDTH]
    add ebx, MAP_BORDER * 2                       ; EBX = padded stride
.run:
    movzx eax, byte [esi]                         ; row (0xFF = end)
    cmp al, 0xFF
    je .done
    imul eax, ebx                                 ; row * stride
    movzx edx, byte [esi + 1]                     ; col
    add eax, edx
    lea edi, [eax + W_OVERWORLD_MAP]              ; GB offset of run start
    movzx ecx, byte [esi + 2]                     ; len
    add esi, 3
.copy:
    mov al, [esi]                                 ; flat src (embedded data)
    mov [ebp + edi], al                           ; GB dest
    inc esi
    inc edi
    dec ecx
    jnz .copy
    jmp .run
.done:
    ret

; ---------------------------------------------------------------------------
; LoadNorthSouthConnectionsTileMap — faithful translation.
; Pret ref: home/overworld.asm:LoadNorthSouthConnectionsTileMap
;
; Copies MAP_BORDER (3) rows of the connected map's edge into the wOverworldMap
; border. Each row copies hNorthSouthConnectionStripWidth (=H_MAP_STRIDE) bytes;
; src advances by hNorthSouthConnectedMapWidth (=H_MAP_WIDTH), dest by the
; wOverworldMap stride (wCurMapWidth + 2*MAP_BORDER).
;
; In:  ESI = HL = strip src, EDX = DE = strip dest, [H_MAP_STRIDE] = strip width,
;      [H_MAP_WIDTH] = connected-map width. EBP = GB base.
; Clobbers: EAX, EBX, ECX, ESI, EDX.
; ---------------------------------------------------------------------------
LoadNorthSouthConnectionsTileMap:
    mov ecx, MAP_BORDER                  ; C = 3 rows
.row:
    push esi
    push edx
    movzx ebx, byte [ebp + H_MAP_STRIDE] ; B = strip width
.inner:
    mov al, [ebp + esi]
    mov [ebp + edx], al
    inc esi
    inc edx
    dec bl
    jnz .inner
    pop edx
    pop esi
    movzx eax, byte [ebp + H_MAP_WIDTH]  ; src += connected-map width
    add esi, eax
    movzx eax, byte [ebp + W_CUR_MAP_WIDTH]
    add eax, MAP_BORDER * 2
    add edx, eax                         ; dest += wOverworldMap stride
    dec ecx
    jnz .row
    ret

; ---------------------------------------------------------------------------
; LoadEastWestConnectionsTileMap — faithful translation.
; Pret ref: home/overworld.asm:LoadEastWestConnectionsTileMap
;
; Copies MAP_BORDER (3) columns of the connected map's edge into the
; wOverworldMap border, for B (strip length) rows. Each row copies 3 bytes; src
; advances by hEastWestConnectedMapWidth (=H_MAP_WIDTH), dest by the wOverworldMap
; stride. (Pallet Town has no E/W connection, but kept faithful for completeness.)
;
; In:  ESI = HL = strip src, EDX = DE = strip dest, BL = row count,
;      [H_MAP_WIDTH] = connected-map width. EBP = GB base.
; Clobbers: EAX, EBX(bl=counter), ECX, ESI, EDX.
; ---------------------------------------------------------------------------
LoadEastWestConnectionsTileMap:
.row:
    push esi
    push edx
    mov ecx, MAP_BORDER                  ; 3 columns
.inner:
    mov al, [ebp + esi]
    mov [ebp + edx], al
    inc esi
    inc edx
    dec ecx
    jnz .inner
    pop edx
    pop esi
    movzx eax, byte [ebp + H_MAP_WIDTH]  ; src += connected-map width
    add esi, eax
    movzx eax, byte [ebp + W_CUR_MAP_WIDTH]
    add eax, MAP_BORDER * 2
    add edx, eax                         ; dest += wOverworldMap stride
    dec bl
    jnz .row
    ret

; ---------------------------------------------------------------------------
; DrawTileBlock — faithful translation.
; Pret ref: home/overworld.asm:DrawTileBlock
;
; Expands one 4×4 map block into tile IDs in wSurroundingTiles.
;
; In:  ESI = write ptr in wSurroundingTiles (HL)
;      BL  = block ID (C)
; Out: ESI advanced by 4*SURROUNDING_WIDTH (past all 4 tile rows of this block)
;      BL unchanged (saved/restored by caller via push/pop ecx before call)
; Clobbers: AL, ECX (internal row counter), EDX (tile data source ptr)
; ---------------------------------------------------------------------------
DrawTileBlock:
    push ecx
    push edx

    ; Compute tile data source: [EBP + wTilesetBlocksPtr + blockID*16]
    movzx edx, word [ebp + W_TILESET_BLOCKS_PTR]  ; EDX = OW_BLOCKS_GBADDR (DE in SM83)
    movzx eax, bl                                  ; EAX = blockID (C in SM83)
    shl eax, 4                                     ; EAX = blockID * 16
    add edx, eax                                   ; EDX = pointer into blockset

    ; TEMPORARY (no GB equivalent — remove once map data is extended): clamp
    ; out-of-range block IDs to block 0 (the black/border tile). The extended
    ; 40×25-tile draw can pull the camera viewport into uninitialized
    ; wOverworldMap padding, handing us a block ID past the embedded blockset;
    ; without this the tile read walks off the blockset and paints garbage. This
    ; is a stopgap: the plan is to extend the map data so those regions hold real
    ; blocks (no blank area exists), at which point this clamp is dead code and
    ; should be deleted. See TODO.md (Phase 2) and CLAUDE.md.
    cmp edx, OW_BLOCKS_GBADDR + OVERWORLD_BLOCKS_SIZE
    jb  .block_in_range
    mov edx, OW_BLOCKS_GBADDR
.block_in_range:

    mov cl, BLOCK_HEIGHT                           ; CL = 4 (row count)

.draw_row:
    push ecx
    ; Tiles 0–2: write to [ESI] with post-increment
    mov al, byte [ebp + edx]
    mov byte [ebp + esi], al
    inc esi
    inc edx
    mov al, byte [ebp + edx]
    mov byte [ebp + esi], al
    inc esi
    inc edx
    mov al, byte [ebp + edx]
    mov byte [ebp + esi], al
    inc esi
    inc edx
    ; Tile 3: write to [ESI] without incrementing ESI (SM83: ld [hl], a)
    mov al, byte [ebp + edx]
    mov byte [ebp + esi], al
    inc edx
    ; Advance ESI to start of next tile row: +45 = SURROUNDING_WIDTH - (BLOCK_WIDTH-1)
    add esi, SURROUNDING_WIDTH - BLOCK_WIDTH + 1   ; = 48 - 4 + 1 = 45
    pop ecx
    dec cl
    jnz .draw_row

    pop edx
    pop ecx
    ret

; ---------------------------------------------------------------------------
; LoadCurrentMapView — faithful translation.
; Pret ref: home/overworld.asm:LoadCurrentMapView
;
; Reads SCREEN_BLOCK_HEIGHT×SCREEN_BLOCK_WIDTH blocks from wOverworldMap
; (starting at wCurrentTileBlockMapViewPointer) and expands each via
; DrawTileBlock into wSurroundingTiles (SURROUNDING_WIDTH×SURROUNDING_HEIGHT).
; Then adjusts for wYBlockCoord/wXBlockCoord and copies the 20×18 view to
; wTileMap.
;
; The bank-switch (BankswitchCommon) is a no-op in the flat model.
; ---------------------------------------------------------------------------
LoadCurrentMapView:
    push esi
    push edi
    push ebx
    push ecx

    ; ; TODO-HW: BankswitchCommon (flat model — no-op)

    ; DE = wCurrentTileBlockMapViewPointer (block map source ptr)
    movzx edx, word [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR]

    ; HL = ESI = wSurroundingTiles (tile write destination)
    mov esi, W_SURROUNDING_TILES

    ; B (BH) = SCREEN_BLOCK_HEIGHT outer loop count
    mov bh, SCREEN_BLOCK_HEIGHT

.row_loop:
    push esi                                       ; save row-start of wSurroundingTiles
    push edx                                       ; save row-start of block map

    mov cl, SCREEN_BLOCK_WIDTH                     ; CL = C = inner block count

.row_inner_loop:
    push ecx                                       ; push bc (saves CL=inner count)
    push edx                                       ; push de
    push esi                                       ; push hl

    ; STOPGAP (no GB equivalent — remove once map data is extended): the 40×25
    ; viewport is larger than the GB's 20×18, so a player-centered camera near a
    ; map edge reaches past wOverworldMap. wOverworldMap ($E580) sits directly
    ; above wSurroundingTiles ($E000) in WRAM, so reads above its top border land
    ; in the tile buffer and decode tile IDs as block IDs → a garbage band. Any
    ; read outside [wOverworldMap, wOverworldMapEnd) instead yields the map's
    ; border block, so the extended/out-of-map area renders as clean dummy tiles
    ; (matching the in-bounds border) rather than garbage. See CLAUDE.md / TODO.md:
    ; the real fix is to extend map data to fill the larger viewport.
    cmp edx, W_OVERWORLD_MAP
    jb  .oobBlock
    cmp edx, W_OVERWORLD_MAP + W_OVERWORLD_MAP_SIZE
    jae .oobBlock
    movzx eax, byte [ebp + edx]                   ; A = block ID from wOverworldMap
    jmp .haveBlock
.oobBlock:
    movzx eax, byte [ebp + W_MAP_BACKGROUND_TILE] ; dummy = map border block
.haveBlock:
    mov bl, al                                     ; BL = block ID arg to DrawTileBlock (C)
    call DrawTileBlock                             ; writes 4×4 tiles to [EBP+ESI..]
                                                   ; ECX preserved by DrawTileBlock

    pop esi                                        ; pop hl (restore wSurroundingTiles ptr)
    pop edx                                        ; pop de (restore block map ptr)
    pop ecx                                        ; pop bc (restores CL=inner count)

    add esi, BLOCK_WIDTH                           ; HL += 4 (next block column in wSurroundingTiles)
    inc edx                                        ; DE++ (next block in block-map row)
    dec cl                                         ; dec C (inner count, not block ID)
    jnz .row_inner_loop

    ; Advance block-map pointer to next row
    pop edx                                        ; restore row-start of block map
    movzx eax, byte [ebp + W_CUR_MAP_WIDTH]
    add al, MAP_BORDER * 2                         ; stride = width + 6
    add edx, eax                                   ; EDX += stride (next block-map row)

    ; Advance wSurroundingTiles pointer to next block row (4 tile rows down)
    pop esi                                        ; restore row-start of wSurroundingTiles
    add esi, SURROUNDING_WIDTH * BLOCK_HEIGHT      ; ESI += 96 (= 24 * 4)

    dec bh                                         ; dec B (outer row count)
    jnz .row_loop

    ; Copy the sub-block window of wSurroundingTiles into wTileMap (the collision
    ; grid). Factored out so AdvancePlayerSprite can refresh it every step.
    call RefreshCollisionTileMap

    ; ; TODO-HW: BankswitchCommon restore (flat model — no-op)

    pop ecx
    pop ebx
    pop edi
    pop esi
    ret

; ---------------------------------------------------------------------------
; RefreshCollisionTileMap — copy the current sub-block window of wSurroundingTiles
; into wTileMap (the collision / text tile grid).
;
; wTileMap is what NPC collision (GetTileSpriteStandsOn → IsTilePassable) and the
; player collision read. wSurroundingTiles is the block-decoded render source.
; The window into it is offset by the player's sub-block coords (xBlock/yBlock):
; each is 0 or 1, shifting the 40×25 window by 0 or 2 tiles.
;
; BUG FIX (walking-NPC wall-clip): the sub-block coords change every step, but the
; full rebuild (LoadCurrentMapView) only ran on block crossings (every 2 steps),
; so between crossings wTileMap lagged the player's actual position by up to a
; tile — NPC collision then tested the wrong cell and walked into rendered walls
; (verified via the DEBUG_NPC_WALK log: destTile != trueTile). AdvancePlayerSprite
; now calls this every step so collision always matches the rendered map. Only the
; collision buffer is touched; wSurroundingTiles and SCX/SCY (render) are untouched.
;
; In: EBP = GB base. All registers preserved.
; ---------------------------------------------------------------------------
RefreshCollisionTileMap:
    pushad
    ; --- Adjust source pointer for sub-block coords ---
    mov esi, W_SURROUNDING_TILES
    cmp byte [ebp + W_Y_BLOCK_COORD], 0
    je  .adjust_x_coord
    add esi, SURROUNDING_WIDTH * 2                 ; skip 2 tile rows (bottom half of block)
.adjust_x_coord:
    cmp byte [ebp + W_X_BLOCK_COORD], 0
    je  .copy_to_tilemap
    add esi, BLOCK_WIDTH / 2                       ; skip 2 tiles (right half of block)
.copy_to_tilemap:
    mov edx, W_TILEMAP                             ; dest
    mov bh, SCREEN_HEIGHT                          ; 25 rows
.copy_row_loop:
    mov bl, SCREEN_WIDTH                           ; 40 cols
.copy_col_loop:
    mov al, byte [ebp + esi]
    mov byte [ebp + edx], al
    inc esi
    inc edx
    dec bl
    jnz .copy_col_loop
    add esi, SURROUNDING_WIDTH - SCREEN_WIDTH      ; next wSurroundingTiles row (+8)
    dec bh
    jnz .copy_row_loop
    popad
    ret

; ---------------------------------------------------------------------------
; CopyMapViewToVRAM — DIVERGENCE (OW-A.5): obsoleted by the native-width renderer.
; Pret ref: home/overworld.asm:CopyMapViewToVRAM / CopyMapViewToVRAM2.
; pret copies wTileMap (25×40) to vBGMap0 each map load; the port's render_bg
; (src/ppu/ppu.asm) instead decodes wSurroundingTiles directly to the pixel surface
; every frame, so there is no wTileMap→VRAM copy step. This routine has NO body and
; is never called; LoadCurrentMapView (invoked where pret calls CopyMapViewToVRAM)
; is the faithful stand-in. The dead `global` was removed (see ~L176).
%ifdef DEBUG_WALKSPEED
; ---------------------------------------------------------------------------
; WalkSpeedSample — called once per completed tile-step (from .moveAhead). Accrues
; ticks-per-tile stats into the $D1E0 scratch for DUMP.BIN. Reached only by call;
; sits between two ret-terminated routines so nothing falls through into it.
; In: EBP = GB base. Preserves all registers.
; ---------------------------------------------------------------------------
WalkSpeedSample:
    push eax
    push edx
    mov eax, [tick_count]
    cmp dword [ebp + 0xD1F0], 0
    jne .have
    mov [ebp + 0xD1E0], eax                 ; first tick
    mov [ebp + 0xD1E4], eax                 ; last tick
    mov dword [ebp + 0xD1E8], 1             ; tiles = 1
    mov dword [ebp + 0xD1F0], 1             ; initialized
    jmp .done
.have:
    mov edx, eax
    sub edx, [ebp + 0xD1E4]                 ; delta = now - last
    mov [ebp + 0xD1E4], eax                 ; last = now
    inc dword [ebp + 0xD1E8]                ; tiles++
    cmp edx, [ebp + 0xD1EC]
    jae .done
    mov [ebp + 0xD1EC], edx                 ; min delta
.done:
    pop edx
    pop eax
    ret
%endif

; ---------------------------------------------------------------------------
; AdvancePlayerSprite — home wrapper.
; pret: home/overworld.asm:AdvancePlayerSprite.
;
; Forces wUpdateSpritesEnabled = $FF for the duration of the sprite advance (so the
; OAM/sprite update runs while the player steps), then restores the prior value. This
; is pret's home-bank wrapper around _AdvancePlayerSprite; OW-A.3 de-folded it back out
; of the engine body it had been merged into (the save/restore was previously a
; documented Phase-2 omission). Register-safe.
; ---------------------------------------------------------------------------
AdvancePlayerSprite:
    push eax                                          ; keep caller EAX (wrapper clobbers AL)
    mov al, [ebp + W_UPDATE_SPRITES_ENABLED]          ; pret: ld a,[wUpdateSpritesEnabled] / push af
    mov byte [ebp + W_UPDATE_SPRITES_ENABLED], 0xFF   ; pret: ld a,$FF / ld [wUpdateSpritesEnabled],a
    push eax
    call _AdvancePlayerSprite                         ; pret: callfar _AdvancePlayerSprite
    pop eax
    mov [ebp + W_UPDATE_SPRITES_ENABLED], al          ; pret: pop af / ld [wUpdateSpritesEnabled],a
    pop eax
    ret

; ---------------------------------------------------------------------------
; _AdvancePlayerSprite — engine body.
; pret: engine/overworld/advance_player_sprite.asm:_AdvancePlayerSprite.
;
; Runs once per advanced frame of a walk. Decrements wWalkCounter; on the first
; frame (counter == 7) it slides wMapViewVRAMPointer by 2 tiles, advances the
; tile-block-map pointer when a block boundary is crossed, rebuilds the map view,
; and schedules the newly exposed row/column for VBlank redraw. Every frame it
; scrolls the BG by 2 px (hSCX/hSCY) in the direction of motion.
;
; Remaining Phase-2 omissions vs. pret (inside this body): IsSpinning and the
; Pikachu overworld-state flag.
;
; b (SM83) = wSpritePlayerStateData1YStepVector → kept in BL  (+1 / -1 / 0)
; c (SM83) = wSpritePlayerStateData1XStepVector → kept in CL  (+1 / -1 / 0)
; ---------------------------------------------------------------------------
_AdvancePlayerSprite:
    push eax
    push ebx
    push ecx
    push edx

    mov bl, [ebp + W_SPRITE_PLAYER_Y_STEP_VECTOR]    ; BL = b (Y step)
    mov cl, [ebp + W_SPRITE_PLAYER_X_STEP_VECTOR]    ; CL = c (X step)

    dec byte [ebp + W_WALK_COUNTER]
    jnz .afterUpdateMapCoords
    ; end of animation → commit the player's map coordinates
    mov al, [ebp + W_Y_COORD]
    add al, bl
    mov [ebp + W_Y_COORD], al
    mov al, [ebp + W_X_COORD]
    add al, cl
    mov [ebp + W_X_COORD], al
    call CheckMapConnections
    jc .transitionExit                         ; CF=1 → map changed, abort frame
.afterUpdateMapCoords:
    cmp byte [ebp + W_WALK_COUNTER], 7
    jne .scroll                                       ; only the first frame slides the view

    jmp .adjustXCoordWithinBlock

.adjustXCoordWithinBlock:
    mov al, [ebp + W_X_BLOCK_COORD]
    add al, cl
    mov [ebp + W_X_BLOCK_COORD], al
    cmp al, 0x02
    jne .checkForMoveToWestBlock
    ; crossed into the block to the east
    mov byte [ebp + W_X_BLOCK_COORD], 0
    inc byte [ebp + W_X_OFFSET_SINCE_LAST_SPECIAL_WARP]
    call MoveTileBlockMapPointerEast
    jmp .updateMapView
.checkForMoveToWestBlock:
    cmp al, 0xFF
    jne .adjustYCoordWithinBlock
    ; crossed into the block to the west
    mov byte [ebp + W_X_BLOCK_COORD], 1
    dec byte [ebp + W_X_OFFSET_SINCE_LAST_SPECIAL_WARP]
    call MoveTileBlockMapPointerWest
    jmp .updateMapView
.adjustYCoordWithinBlock:
    mov al, [ebp + W_Y_BLOCK_COORD]
    add al, bl
    mov [ebp + W_Y_BLOCK_COORD], al
    cmp al, 0x02
    jne .checkForMoveToNorthBlock
    ; crossed into the block to the south
    mov byte [ebp + W_Y_BLOCK_COORD], 0
    inc byte [ebp + W_Y_OFFSET_SINCE_LAST_SPECIAL_WARP]
    mov al, [ebp + W_CUR_MAP_WIDTH]
    call MoveTileBlockMapPointerSouth
    jmp .updateMapView
.checkForMoveToNorthBlock:
    cmp al, 0xFF
    jne .refreshTileMap                  ; no block crossing → only resync collision grid
    ; crossed into the block to the north
    mov byte [ebp + W_Y_BLOCK_COORD], 1
    dec byte [ebp + W_Y_OFFSET_SINCE_LAST_SPECIAL_WARP]
    mov al, [ebp + W_CUR_MAP_WIDTH]
    call MoveTileBlockMapPointerNorth

.updateMapView:
    call LoadCurrentMapView              ; rebuilds wSurroundingTiles AND refreshes wTileMap
    jmp .scroll
.refreshTileMap:
    ; Non-crossing step: the player's sub-block coords just changed, so re-copy
    ; wTileMap from the (unchanged) wSurroundingTiles with the new sub-block offset.
    ; Without this, NPC collision reads a stale grid and walks into rendered walls.
    call RefreshCollisionTileMap

.scroll:
    ; Sprite-shift loop: slide each NPC's screen position by 2*step pixels to
    ; keep them world-anchored while the BG scrolls under the player.
    ; Pret ref: engine/overworld/advance_player_sprite.asm lines 162-192.
    push esi
    mov bl, [ebp + W_SPRITE_PLAYER_Y_STEP_VECTOR]
    add bl, bl                                          ; BL = 2 * Ystep (+2/-2/0)
    mov cl, [ebp + W_SPRITE_PLAYER_X_STEP_VECTOR]
    add cl, cl                                          ; CL = 2 * Xstep
    mov esi, W_SPRITE_STATE_DATA_1 + 0x10 + SPRITESTATEDATA1_YPIXELS  ; slot 1 YPixels
    mov edx, 15                                         ; 15 NPC/Pikachu slots
.spriteShift:
    mov al, [ebp + esi]
    sub al, bl
    mov [ebp + esi], al                                 ; YPixels -= 2*Ystep
    mov al, [ebp + esi + 2]                             ; XPixels is YPIXELS+2 in data1
    sub al, cl
    mov [ebp + esi + 2], al                             ; XPixels -= 2*Xstep
    add esi, 0x10                                       ; next slot
    dec edx
    jnz .spriteShift
    pop esi
    ; hSCY += 2*Yvec ; hSCX += 2*Xvec
    mov al, [ebp + W_SPRITE_PLAYER_Y_STEP_VECTOR]
    add al, al
    add [ebp + H_SCY], al
    mov al, [ebp + W_SPRITE_PLAYER_X_STEP_VECTOR]
    add al, al
    add [ebp + H_SCX], al

    pop edx
    pop ecx
    pop ebx
    pop eax
    clc                                        ; CF=0 → no transition
    ret

.transitionExit:
    ; CheckMapConnections set CF=1 → propagate up to caller
    pop edx
    pop ecx
    pop ebx
    pop eax
    stc                                        ; CF=1 → transition occurred
    ret

; ---------------------------------------------------------------------------
; MoveTileBlockMapPointer{East,West,South,North} — faithful translations.
; Pret ref: engine/overworld/advance_player_sprite.asm
;
; Move wCurrentTileBlockMapViewPointer (the upper-left corner of the visible
; block-map region) by one block in the given direction. South/North take the
; row stride (wCurMapWidth + 2*MAP_BORDER) in AL on entry.
; All registers except the pointer are preserved.
; ---------------------------------------------------------------------------
MoveTileBlockMapPointerEast:
    push eax
    mov al, [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR]
    add al, 0x01
    mov [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR], al
    jnc .done
    inc byte [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR + 1]
.done:
    pop eax
    ret

MoveTileBlockMapPointerWest:
    push eax
    mov al, [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR]
    sub al, 0x01
    mov [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR], al
    jnc .done
    dec byte [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR + 1]
.done:
    pop eax
    ret

MoveTileBlockMapPointerSouth:            ; AL = wCurMapWidth
    push eax
    push ebx
    add al, MAP_BORDER * 2                ; AL = row stride
    movzx ebx, al
    mov al, [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR]
    add al, bl
    mov [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR], al
    jnc .done
    inc byte [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR + 1]
.done:
    pop ebx
    pop eax
    ret

MoveTileBlockMapPointerNorth:            ; AL = wCurMapWidth
    push eax
    push ebx
    add al, MAP_BORDER * 2                ; AL = row stride
    movzx ebx, al
    mov al, [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR]
    sub al, bl
    mov [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR], al
    jnc .done
    dec byte [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR + 1]
.done:
    pop ebx
    pop eax
    ret

%ifdef DEBUG_SEAM
section .data
seam_seeded: db 0        ; EnterMap is re-entered per map transition; seed once
seam_reseat: db 0        ; derive the view ptr only for the hand-seeded spawn
section .text

; ---------------------------------------------------------------------------
; SeamReseatView — DEBUG_SEAM only. Port-only debug helper, no pret counterpart.
; LoadMapData loads the header + block map but does NOT derive the view pointer
; (that lives in LoadWarpDestination). A harness that spawns on an arbitrary map
; must therefore recompute it from the seeded coordinates, using the same formula
; LoadWarpDestination does, and re-run LoadCurrentMapView to repaint the surface.
; ---------------------------------------------------------------------------
SeamReseatView:
    push eax
    push ebx
    push ecx
    movzx eax, byte [ebp + W_CUR_MAP_WIDTH]
    add eax, MAP_BORDER * 2                   ; EAX = stride
    movzx ebx, byte [ebp + W_Y_COORD]
    shr ebx, 1
    add ebx, MAP_BORDER
    sub ebx, SCREEN_BLOCK_HEIGHT / 2          ; EBX = view_row
    movzx ecx, byte [ebp + W_X_COORD]
    shr ecx, 1
    add ecx, MAP_BORDER
    sub ecx, SCREEN_BLOCK_WIDTH / 2           ; ECX = view_col
    imul eax, ebx
    add eax, ecx
    add eax, W_OVERWORLD_MAP
    mov [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR], ax
    ; wXBlockCoord/wYBlockCoord are the sub-block (odd/even coord) halves that
    ; RefreshCollisionTileMap uses to shift the wSurroundingTiles→wTileMap crop.
    ; The live spawn path maintains them; a hand-seeded coord must too, or the
    ; crop is one coord off and every collision test reads the wrong tile.
    mov al, [ebp + W_X_COORD]
    and al, 1
    mov [ebp + W_X_BLOCK_COORD], al
    mov al, [ebp + W_Y_COORD]
    and al, 1
    mov [ebp + W_Y_BLOCK_COORD], al
    call LoadCurrentMapView
    ; wTileMap is the collision mirror, and LoadCurrentMapView only fills
    ; wSurroundingTiles. Without this the very first collision check reads the
    ; PREVIOUS map's tiles (or zeros) and the player is walled in on the spawn
    ; tile — a harness artifact that looks exactly like a map bug.
    call RefreshCollisionTileMap
    ; Seed BIT_STANDING_ON_WARP exactly as LoadWarpDestination does, or a spawn
    ; that lands on a warp tile (every map-edge gate spawn does) can never take
    ; the collision-exit path — an artifact that would make the harness disagree
    ; with the live game.
    and byte [ebp + W_MOVEMENT_FLAGS], ~(1 << BIT_STANDING_ON_WARP)
    call CheckWarpTile
    jnc .noSpawnWarp
    or byte [ebp + W_MOVEMENT_FLAGS], (1 << BIT_STANDING_ON_WARP)
.noSpawnWarp:
    pop ecx
    pop ebx
    pop eax
    ret
%endif

; ---------------------------------------------------------------------------
; CollisionCheckOnLand — tile passability + sprite collision check.
; Pret ref: home/overworld.asm:CollisionCheckOnLand.
;
; Checks both the tile in front of the player (IsTilePassable) and whether any
; NPC occupies that block (IsNPCAtTargetBlock).  CF=1 if movement is blocked.
; ---------------------------------------------------------------------------
CollisionCheckOnLand:
%ifdef OVERWORLD_LEDGES
    ; M7.3 ledge-hop + tile-pair collisions live in src/engine/overworld/ledges.asm
    ; (CHECK-only by default; see Makefile). Referenced only under this flag, so the
    ; default build neither links ledges.asm nor alters land-collision behavior.
    extern CheckForJumpingAndTilePairCollisions
    extern TilePairCollisionsLand
%endif
%ifdef DEBUG_NOCLIP
    cmp byte [pad_noclip], 0
    jne .passable                 ; noclip active: always passable
%endif
    push eax
    push ecx
    push esi
    ; pret home/overworld.asm:1223-1225 — no collisions while the game is scripting the
    ; player's movement (wSimulatedJoypadStatesIndex != 0). Inert today: nothing sets the
    ; index until scripted NPC/cutscene movement lands (Stage 2), so this always falls
    ; through. Restored for faithfulness / to be correct once that path is live.
    cmp byte [ebp + W_SIMULATED_JOYPAD_STATES_INDEX], 0
    jne .noCollision                               ; scripted movement → always passable
    ; pret :1226-1231 — quick sprite reject. The accumulated collision-direction bits in
    ; wSpritePlayerStateData1CollisionData (player = slot 0) use the same bit layout as
    ; wPlayerDirection (bit0=RIGHT, bit1=LEFT, bit2=DOWN, bit3=UP — see the DH[3:2]/DH[1:0]
    ; write in movement.asm:DetectCollisionBetweenSprites); if a set bit overlaps the
    ; direction the player is trying to move, a sprite is already known to be there. This
    ; can only ADD a block that the thorough IsNPCAtTargetBlock scan below would also catch
    ; (pret itself questions why the deeper check ever misses). pret's `nop`, the
    ; res BIT_FACE_PLAYER / hTextID / Pikachu-collision-counter tail are folded into the
    ; bespoke IsNPCAtTargetBlock replacement below.
    mov dl, [ebp + W_PLAYER_DIRECTION]
    mov al, [ebp + W_SPRITE_STATE_DATA_1 + SPRITESTATEDATA1_COLLISIONDATA]
    and al, dl
    jnz .blocked                                   ; sprite already flagged in travel dir
    ; wTileMap is a sub-block viewport into wSurroundingTiles, offset by W_Y_BLOCK_COORD /
    ; W_X_BLOCK_COORD. AdvancePlayerSprite only calls LoadCurrentMapView on block-boundary
    ; crossings, so the viewport can be stale within a block (YBC/XBC changed but wTileMap
    ; not rebuilt). Rebuild here to apply the current sub-block offset before the tile read.
    call LoadCurrentMapView
    call GetTileInFrontOfPlayer                    ; CL = tile in front
%ifdef OVERWORLD_LEDGES
    ; M7.3 hook — pret home/overworld.asm:CollisionCheckOnLand (.noSpriteCollision):
    ;   ld hl, TilePairCollisionsLand / call CheckForJumpingAndTilePairCollisions
    ;   jr c, .collision   — an illegal tile-pair (elevation-seam) boundary blocks;
    ; plus the top-of-function `bit BIT_LEDGE_OR_FISHING, a / jr nz .noCollision`:
    ; once a ledge hop is armed the move is allowed (the hop carries the player).
    ; Faithful gate: in the OVERWORLD tileset with no matching ledge tile HandleLedges
    ; sets no state, and TilePairCollisionsLand holds only CAVERN/FOREST entries, so
    ; the scan returns CF=0 — this block is inert and behavior is byte-identical.
    push ebx                                       ; CheckForTilePairCollisions uses BL
    push edx                                       ; ...and DH (tile player stands on)
    mov esi, TilePairCollisionsLand                ; flat host ptr to the tile-pair table
    call CheckForJumpingAndTilePairCollisions      ; may arm a ledge hop; CF=1 → seam-blocked
    pop edx
    pop ebx
    jc .blocked                                    ; illegal tile-pair boundary → blocked
    test byte [ebp + W_MOVEMENT_FLAGS], (1 << BIT_LEDGE_OR_FISHING)
    jnz .noCollision                               ; ledge hop armed → allow the move
    movzx ecx, byte [ebp + W_TILE_IN_FRONT_OF_PLAYER] ; restore CL (HandleLedges clobbered ECX)
%endif
    call IsTilePassable                            ; CF = 1 if not passable
    jc .blocked                                    ; tile impassable → blocked
    ; IsNPCAtTargetBlock is the port's BESPOKE replacement for pret's IsSpriteInFrontOfPlayer
    ; (home/overworld.asm:1234) plus the res BIT_FACE_PLAYER / hTextID / Pikachu-collision-
    ; counter tail (:1236-1252): a straight MAPY/MAPX block scan of slots 1–15. It does not
    ; reproduce the sprite-facing side effect or the Pikachu-follow B-button leniency; those
    ; ride the sprite-engine reimpl. CF=1 → an NPC occupies the target block.
    call IsNPCAtTargetBlock                        ; CF = 1 if NPC is in front
    jc .blocked                                    ; NPC in the way → blocked
.noCollision:
    pop esi
    pop ecx
    pop eax
    clc
    ret
.blocked:
    ; pret home/overworld.asm:1259-1264 (.collision): play SFX_COLLISION on the bump,
    ; unless it's already playing on CHAN5. Done before the pops so PlaySound's clobber
    ; of eax/ecx/esi is undone by the restores; stc lands after (pop doesn't touch CF).
    mov al, [ebp + wChannelSoundIDs + CHAN5]        ; sound currently on CHAN5
    cmp al, SFX_COLLISION                            ; already playing?
    je .blockedSetCarry                              ; yes → don't retrigger
    mov al, SFX_COLLISION
    call PlaySound
.blockedSetCarry:
    pop esi
    pop ecx
    pop eax
    stc
    ret
%ifdef DEBUG_NOCLIP
.passable:
    clc
    ret
%endif

; ---------------------------------------------------------------------------
; CollisionCheckOnWater — collision check while surfing (OW-A.6).
; Pret ref: home/overworld.asm:1665 CollisionCheckOnWater.
;
; CF=1 → blocked on water; CF=0 → move allowed. The "passable land tile ahead"
; case disembarks (.stopSurfing): clears wWalkBikeSurfState, reloads the walking
; sprite, restores the map music, and returns CF=0 so the step onto land runs.
; Unreachable in today's live build — nothing sets wWalkBikeSurfState=2 until
; Surf item-use / ForceBikeOrSurf (player_gfx.asm) links.
;
; PORT (established divergence, same as CollisionCheckOnLand): pret's
; `predef GetTileAndCoordsInFrontOfPlayer` is realized as LoadCurrentMapView +
; GetTileInFrontOfPlayer (the port's simplified front-tile read; the coord
; side-outputs are dropped — see GetTileInFrontOfPlayer's DEFERRED note).
; Register safety mirrors CollisionCheckOnLand: EAX/ECX/ESI saved; DL is
; (re)written with W_PLAYER_DIRECTION, the same value callers already hold.
; ---------------------------------------------------------------------------
CollisionCheckOnWater:
    push eax
    push ecx
    push esi
    ; pret: bit BIT_SCRIPTED_MOVEMENT_STATE → never collide under simulated input
    test byte [ebp + W_STATUS_FLAGS_5], (1 << BIT_SCRIPTED_MOVEMENT_STATE)
    jnz .noCollision
    ; pret :1669-1672 — quick sprite reject in the travel direction (same
    ; collision-direction bit layout as CollisionCheckOnLand's reject).
    mov dl, [ebp + W_PLAYER_DIRECTION]
    mov al, [ebp + W_SPRITE_STATE_DATA_1 + SPRITESTATEDATA1_COLLISIONDATA]
    and al, dl
    jnz .collision
    ; pret :1673-1675 — water-seam tile pairs block (and may arm a ledge state);
    ; same save set as CollisionCheckOnLand's land hook.
    push ebx
    push edx
    mov esi, TilePairCollisionsWater               ; flat host ptr (ledges.asm)
    call CheckForJumpingAndTilePairCollisions
    pop edx
    pop ebx
    jc .collision
    ; pret :1676 predef GetTileAndCoordsInFrontOfPlayer → port idiom (see header):
    ; rebuild the viewport (stale within a block), then read the front tile.
    call LoadCurrentMapView
    call GetTileInFrontOfPlayer                    ; CL = tile → W_TILE_IN_FRONT_OF_PLAYER
    call IsNextTileShoreOrWater                    ; CF=1 → shore/water ahead
    jc .noCollision                                ; keep surfing
    movzx ecx, byte [ebp + W_TILE_IN_FRONT_OF_PLAYER] ; ld a,[wTileInFrontOfPlayer] / ld c,a
    call IsTilePassable                            ; CF=1 → not passable
    jnc .stopSurfing                               ; passable land ahead → disembark
.collision:
    ; pret :1685-1690 — bump SFX unless already playing on CHAN5.
    mov al, [ebp + wChannelSoundIDs + CHAN5]
    cmp al, SFX_COLLISION
    je .setCarry
    mov al, SFX_COLLISION
    call PlaySound
.setCarry:
    pop esi
    pop ecx
    pop eax
    stc
    ret
.checkIfVermilionDockTileset:
    ; UNREFERENCED in pret Yellow (no jump targets this label — Red-era remnant
    ; kept for label fidelity, like Func_5288 set 3).
    mov al, [ebp + W_CUR_MAP_TILESET]
    cmp al, SHIP_PORT                              ; Vermilion Dock tileset?
    jne .noCollision                               ; keep surfing if not
    jmp .stopSurfing
.stopSurfing:
    ; pret :1699-1708 ("based game freak") — disembark onto the passable tile.
    mov byte [ebp + wPikachuSpawnState], 3
    or byte [ebp + wPikachuOverworldStateFlags], (1 << 5) ; set 5, [hl] (hide)
    mov byte [ebp + W_WALK_BIKE_SURF_STATE], 0
    call LoadPlayerSpriteGraphics
    call PlayDefaultMusic
    ; fall through — pret: jr .noCollision
.noCollision:
    pop esi
    pop ecx
    pop eax
    clc                                            ; and a — CF=0
    ret

; ---------------------------------------------------------------------------
; DoBikeSpeedup — bikes move twice as fast as walking (OW-A.6).
; Pret ref: home/overworld.asm:339 DoBikeSpeedup.
;
; Called once per .moveAhead frame; when riding a bike it advances the player
; sprite a second time (2 px/frame). On Cycling Road (ROUTE_17) the speedup is
; suppressed while UP/LEFT/RIGHT is held (the forced-southward drift stays at
; walking speed). Inert in today's live build — wWalkBikeSurfState is never 1
; until Bicycle item-use / ForceBikeOrSurf links.
;
; PORT NOTE: the port's AdvancePlayerSprite returns CF=1 on a map-connection
; crossing; this inner call's CF is discarded (pret drops it too — its crossing
; is caught by CheckMapConnections on the wWalkCounter path). Revisit the
; crossing-mid-speedup case when biking goes live.
; ---------------------------------------------------------------------------
DoBikeSpeedup:
    mov al, [ebp + W_WALK_BIKE_SURF_STATE]
    dec al                                         ; riding a bike? (state == 1)
    jnz .done                                      ; ret nz
    test byte [ebp + W_MOVEMENT_FLAGS], (1 << BIT_LEDGE_OR_FISHING)
    jnz .done                                      ; ret nz — mid ledge-hop/fishing
    cmp byte [ebp + wNPCMovementScriptPointerTableNum], 0
    jne .done                                      ; ret nz — movement script active
    mov al, [ebp + W_CUR_MAP]
    cmp al, ROUTE_17                               ; Cycling Road
    jne .goFaster
    test byte [ebp + H_JOY_HELD], PAD_UP | PAD_LEFT | PAD_RIGHT
    jnz .done                                      ; ret nz — braking on Cycling Road
.goFaster:
    call AdvancePlayerSprite                       ; second advance → double speed
.done:
    ret

; ---------------------------------------------------------------------------
; GetTileInFrontOfPlayer — simplified translation.
; Pret ref: engine/overworld/player_state.asm:_GetTileAndCoordsInFrontOfPlayer
;
; Reads the tile the player faces from wTileMap at the fixed screen coordinate
; pret uses for each facing (the player is always centered). Stores it in
; wTileInFrontOfPlayer and returns it in CL.
;
; DEFERRED side-outputs: pret's _GetTileAndCoordsInFrontOfPlayer also returns the
; TARGET tile's map coordinates in D = wYCoord±1 and E = wXCoord±1 (facing-adjusted).
; Those are consumed by SignLoop (sign reading via IsSpriteOrSignInFrontOfPlayer,
; home/overworld.asm:1069) and the hidden-event coord scan — neither of which is
; live yet. The one current caller (CollisionCheckOnLand) needs only the tile, so
; the D/E outputs are intentionally dropped. When sign/hidden-event front-coord
; matching lands it must either derive the front coords itself from wYCoord/wXCoord
; + facing, or this routine be extended to emit them (see the note in player_state.asm
; that the port's dependents pre-read wTileInFrontOfPlayer and self-derive coords).
; ---------------------------------------------------------------------------
GetTileInFrontOfPlayer:
    ; Pret ref: engine/overworld/player_state.asm:_GetTileAndCoordsInFrontOfPlayer
    ;   lda_coord c, r  = W_TILEMAP + r*20 + c  (pret 20-wide tilemap)
    ; DOS tilemap is 40 wide; player standing tile = PLAYER_STANDING_ROW=17,
    ; PLAYER_STANDING_COL=24. Fronts are ±2 rows/cols from the standing tile.
    ;
    ;   Down  (row+2, col+0) = (19, 24)
    ;   Up    (row-2, col+0) = (15, 24)
    ;   Left  (row+0, col-2) = (17, 22)
    ;   Right (row+0, col+2) = (17, 26)
    mov al, [ebp + W_SPRITE_PLAYER_FACING_DIR]
    cmp al, SPRITE_FACING_DOWN
    jne .notDown
    mov esi, W_TILEMAP + (PLAYER_STANDING_ROW + 2) * SCREEN_TILES_W + PLAYER_STANDING_COL
    jmp .read
.notDown:
    cmp al, SPRITE_FACING_UP
    jne .notUp
    mov esi, W_TILEMAP + (PLAYER_STANDING_ROW - 2) * SCREEN_TILES_W + PLAYER_STANDING_COL
    jmp .read
.notUp:
    cmp al, SPRITE_FACING_LEFT
    jne .notLeft
    mov esi, W_TILEMAP + PLAYER_STANDING_ROW * SCREEN_TILES_W + (PLAYER_STANDING_COL - 2)
    jmp .read
.notLeft:
    mov esi, W_TILEMAP + PLAYER_STANDING_ROW * SCREEN_TILES_W + (PLAYER_STANDING_COL + 2)
.read:
    movzx ecx, byte [ebp + esi]
    mov [ebp + W_TILE_IN_FRONT_OF_PLAYER], cl
    ret

; ---------------------------------------------------------------------------
; IsTilePassable — faithful translation.
; Pret ref: engine/gfx/sprite_oam.asm:_IsTilePassable
;
; In:  CL = tile ID. Scans the $FF-terminated passable-tile list pointed to by
;      wTilesetCollisionPtr (GB pointer to list in ROM window at OW_COLL_GBADDR).
; Out: CF = 0 if CL is in the list (passable), CF = 1 otherwise.
; Clobbers AL, ESI.
;
; SM83 original:
;   ld hl, wTilesetCollisionPtr  ; load the pointer-to-pointer
;   ld a, [hli]
;   ld h, [hl]
;   ld l, a                       ; HL = *wTilesetCollisionPtr (the actual list address)
;   .loop:
;     ld a, [hli]
;     cp $ff
;     jr z, .tileNotPassable
;     cp c                         ; c = tile to test
;     jr nz, .loop
;     xor a                        ; ZF=1 CF=0 → passable
;     ret
;   .tileNotPassable:
;     scf                          ; CF=1 → not passable
;     ret
; ---------------------------------------------------------------------------
IsTilePassable:
    ; ESI = *wTilesetCollisionPtr (the flat GB address of the passable-tile list)
    movzx esi, word [ebp + W_TILESET_COLLISION_PTR]
.loop:
    mov al, byte [ebp + esi]
    inc esi
    cmp al, 0xFF
    je  .tileNotPassable            ; hit terminator → blocked
    cmp al, cl
    jne .loop                       ; not this tile → keep scanning
    clc                             ; found in list → passable
    ret
.tileNotPassable:
    stc                             ; not found → blocked
    ret

; ---------------------------------------------------------------------------
; LoadMapHeader — faithful translation.
; Pret ref: home/overworld.asm:LoadMapHeader
; ---------------------------------------------------------------------------
LoadMapHeader:
    push eax
    push ebx
    push ecx
    push esi
    push edi

    ; pret: farcall MarkTownVisitedAndLoadToggleableObjects (mark this town visited on
    ; the town map + load per-map toggleable-object visibility flags).
    ; TODO(faithful): not ported — the town-map visited-flag set and the hidden/toggleable
    ; object show-flag load aren't implemented yet (cf. InitToggleableObjectFlags scaffold,
    ; map_sprites.asm). Harmless for the current maps; restore with the town-map subsystem.

    ; pret: ld a,[wCurMapTileset] / ld b,a / res BIT_NO_PREVIOUS_MAP,a /
    ;       ld [wCurMapTileset],a / ldh [hPreviousTileset],a.
    ; Snapshot the previous map's tileset into hPreviousTileset BEFORE the header copy
    ; below overwrites wCurMapTileset (= wCurMapHeader first byte, 0xD366) with the new
    ; map's tileset. LoadTilesetHeader (tail of this routine) compares the two to decide
    ; whether to run the warp-arrival block-coord alignment: without this snapshot its
    ; "tileset unchanged" gate reads a stale value and the alignment fires on every load,
    ; shifting the sub-block viewport.
    ; BIT_NO_PREVIOUS_MAP (bit 7) is set by the save-load path (save.asm) to mean "this
    ; map is already loaded". pret res's it here and snapshots the CLEARED value; the
    ; res is zero-behavior on the current paths (the header copy below already overwrites
    ; wCurMapTileset), but keeping it faithful avoids a stale bit-7 leaking into
    ; hPreviousTileset. The 0xFF8B HRAM byte is a union with hMapStride/
    ; hNSConnectionStripWidth, written only later during LoadCurrentMapView / connection-
    ; strip drawing — never between here and the LoadTilesetHeader read — so it is safe.
    mov al, [ebp + W_CUR_MAP_TILESET]
    mov bl, al                              ; b = full tileset (incl. BIT_NO_PREVIOUS_MAP)
    and al, ~(1 << BIT_NO_PREVIOUS_MAP)     ; res BIT_NO_PREVIOUS_MAP
    mov [ebp + W_CUR_MAP_TILESET], al
    mov [ebp + H_PREVIOUS_TILESET], al
    ; pret: bit BIT_NO_PREVIOUS_MAP,b / ret nz — if the map is already loaded (bit was
    ; set), skip the whole header reload.
    ; TODO(OW-A.5/verify): the early return is DEFERRED. All 3 FRAME.BIN baselines exercise
    ; this routine with the bit CLEAR, so they cannot prove the bit-set path; that path is
    ; only reached after a continue-from-save, and skipping the header reload there would
    ; break the map if the port's .dsv restore does not repopulate wCurMapHeader (it does
    ; not today). Restore the `ret nz` once the save/continue flow can be driven live
    ; (MCP) and verified — same conservatism as OW-A.4(b). Faithful code:
    ;     test bl, (1 << BIT_NO_PREVIOUS_MAP)
    ;     jnz .noPreviousMapReturn   ; pop edi/esi/ecx/ebx/eax ; ret

    ; W_CUR_MAP_HEADER is a 10-byte buffer: tileset(1), h(1), w(1), blkptr(2), txtptr(2), scrptr(2), conn(1)
    movzx eax, byte [ebp + W_CUR_MAP]
    add eax, eax ; * 2 (MapHeaderPointers table is 2 bytes per entry)
    mov esi, MapHeaderPointers
    movzx ebx, word [esi + eax]
    add ebx, ebp ; EBX = address of map header in flat space (rom window)
    
    ; Copy 10 bytes to W_CUR_MAP_HEADER
    mov esi, ebx
    lea edi, [ebp + W_CUR_MAP_HEADER]
    mov ecx, W_CUR_MAP_HEADER_SIZE
    rep movsb
    
    ; Initialize all 4 connected maps to $FF (disabled) before loading actual values.
    ; Faithful to pret: home/overworld.asm line 1820-1825.
    ; Without this, stale connection data from the previous map persists.
    mov byte [ebp + W_NORTH_CONNECTED_MAP], MAP_NO_CONNECTION
    mov byte [ebp + W_SOUTH_CONNECTED_MAP], MAP_NO_CONNECTION
    mov byte [ebp + W_WEST_CONNECTED_MAP],  MAP_NO_CONNECTION
    mov byte [ebp + W_EAST_CONNECTED_MAP],  MAP_NO_CONNECTION
    
    ; ESI now points past the 10-byte header. Check connections bitmask.
    mov al, [ebp + W_CUR_MAP_CONNECTIONS]
    test al, CONNECTION_NORTH
    jz .noNorth
    mov edi, W_NORTH_CONNECTED_MAP
    call CopyMapConnectionHeader
.noNorth:
    mov al, [ebp + W_CUR_MAP_CONNECTIONS]
    test al, CONNECTION_SOUTH
    jz .noSouth
    mov edi, W_SOUTH_CONNECTED_MAP
    call CopyMapConnectionHeader
.noSouth:
    mov al, [ebp + W_CUR_MAP_CONNECTIONS]
    test al, CONNECTION_WEST
    jz .noWest
    mov edi, W_WEST_CONNECTED_MAP
    call CopyMapConnectionHeader
.noWest:
    mov al, [ebp + W_CUR_MAP_CONNECTIONS]
    test al, CONNECTION_EAST
    jz .noEast
    mov edi, W_EAST_CONNECTED_MAP
    call CopyMapConnectionHeader
.noEast:

    ; ESI now points to object_data_ptr
    movzx eax, word [esi]
    add eax, ebp ; EAX = object data flat address
    
    ; Read border block
    mov bl, [eax]
    mov [ebp + W_MAP_BACKGROUND_TILE], bl
    inc eax
    
    ; Copy warps to W_WARP_ENTRIES
    mov bl, [eax]
    mov [ebp + W_NUMBER_OF_WARPS], bl
    inc eax
    movzx ecx, bl
    shl ecx, 2                          ; * 4 bytes per warp entry
    mov esi, eax
    lea edi, [ebp + W_WARP_ENTRIES]
    rep movsb                           ; copy all warp entries to WRAM
    mov eax, esi                        ; advance EAX past copied warp bytes
    
    ; Signs: store the count, then copy the sign block into WRAM.
    ; Pret ref: home/overworld.asm:LoadMapHeader (.loadSignData) + CopySignData.
    ; Per sign (3 bytes): Y, X, textID.  Y/X -> wSignCoords (interleaved pairs),
    ; textID -> wSignTextIDs.  When wNumSigns == 0 the copy is skipped and the
    ; cursor advance adds 0, so a sign-less map is byte-identical to before.
    extern CopySignData                 ; src/engine/overworld/hidden_events.asm
    mov bl, [eax]
    mov [ebp + W_NUM_SIGNS], bl
    inc eax                             ; EAX -> first sign entry (flat address)
    test bl, bl
    jz .noSigns
    mov esi, eax                        ; ESI = flat src of the sign block
    call CopySignData                   ; copies wNumSigns*3 bytes; preserves EAX
.noSigns:
    movzx ebx, byte [ebp + W_NUM_SIGNS]
    lea ebx, [ebx + ebx * 2]           ; * 3 bytes per sign
    add eax, ebx                        ; advance cursor past the sign block
    
    ; Save object data pointer temp
    sub eax, ebp
    mov [ebp + W_OBJECT_DATA_PTR_TEMP], ax

    ; pret home/overworld.asm:1888-1892 (.loadSpriteData): populate the NPC sprite
    ; slots from the map-object binary, UNLESS returning from a battle/blackout
    ; (that data survives a battle, so it isn't rebuilt). W_OBJECT_DATA_PTR_TEMP
    ; (just set above) points at the sprite_count byte = pret's HL on InitSprites entry.
    ; OW-A.2 P3b: this is the faithful home object-loader; the bespoke InitMapSprites
    ; (still the driver until P3c) clears+repopulates the same slots afterward in
    ; LoadMapData, so this is currently redundant-but-harmless (byte-identical).
    mov al, [ebp + W_STATUS_FLAGS_4]
    test al, (1 << BIT_BATTLE_OVER_OR_BLACKOUT)
    jnz .skipInitSprites
    call InitSprites
.skipInitSprites:

    call LoadTilesetHeader

    ; pret: (gated on !BIT_BATTLE_OVER_OR_BLACKOUT) callfar SchedulePikachuSpawnForAfterText —
    ; queue the Pikachu-follower spawn to appear after the next text box.
    ; TODO(faithful): not ported (Pikachu-follower subsystem absent; cf. SpawnPikachu stub).

    ; Load this map's wild-encounter data (pret home/overworld.asm:LoadMapHeader:1900,
    ; callfar LoadWildData). Populates wGrassRate/wGrassMons + wWaterRate/wWaterMons from
    ; WildDataPointers[wCurMap] for TryDoWildEncounter. OW-A.5: previously LoadWildData had
    ; ZERO call sites, so every map's wild slots were stale. LoadWildData clobbers only
    ; EAX/ECX/EDX/ESI (no banking, no I/O), all of which the pops below restore, so it is
    ; safe here.
    call LoadWildData

    ; pret next doubles wCurMapHeight/Width -> wCurrentMapHeight2/Width2 (:1902-1907).
    ; DIVERGENCE (verified safe): the port derives those in CheckMapConnections (its ONLY
    ; consumer), at the top of that routine (set-before-use) — every read of
    ; W_CURRENT_MAP_HEIGHT_2/WIDTH_2 is inside CheckMapConnections, after the set — so
    ; LoadMapHeader does not need to compute them here.
    ; pret LoadMapHeader:1908-1923: load this map's default music (id, ROM bank) from
    ; MapSongBanks[wCurMap] into wMapMusicSoundID/wMapMusicROMBank. PlayDefaultMusic (the
    ; LoadMapData tail + connection crossing) plays it. Real now (OW-A.14); the pops below
    ; restore eax/esi. Flat model: MapSongBanks is a host-address label, stride 2.
    movzx eax, byte [ebp + W_CUR_MAP]
    lea esi, [MapSongBanks + eax*2]
    mov al, [esi]
    mov [ebp + wMapMusicSoundID], al            ; music 1
    mov al, [esi + 1]
    mov [ebp + wMapMusicROMBank], al            ; music 2

    pop edi
    pop esi
    pop ecx
    pop ebx
    pop eax
    ret

; ---------------------------------------------------------------------------
; Home object-loader (pret home/overworld.asm:2137-2274). OW-A.2 P3b.
;
; The faithful counterpart to (half of) the bespoke InitMapSprites: it populates
; the NPC sprite slots (PICTUREID / MAPY / MAPX / MOVEMENTBYTE1) from the map's
; object binary and stashes movement-byte-2 + masked text id in wMapSpriteData and
; trainer class/num (or item id) in wMapSpriteExtraData. It does NOT load tile
; patterns — that is InitMapSprites' job (map_sprites.asm), kept separate as in pret.
;
; Called from LoadMapHeader (above) at the pret :1892 point. Until P3c retires the
; bespoke InitMapSprites, that routine clears+repopulates these same slots when
; LoadMapData runs, so InitSprites' output is currently overwritten (redundant but
; harmless — the byte-identical baselines confirm it).
; ---------------------------------------------------------------------------
; hLoadSpriteTemp1/2 (pret HRAM scratch) — carry movement-byte-2 and text-id+flags
; from InitSprites into LoadSprite, and trainer class/num within LoadSprite.
; Write-before-read scratch, so the initial value is irrelevant.
section .data
h_load_sprite_temp1: db 0    ; pret hLoadSpriteTemp1
h_load_sprite_temp2: db 0    ; pret hLoadSpriteTemp2

section .text
global InitSprites
global ZeroSpriteStateData
global DisableRegularSprites
global LoadSprite

InitSprites:
    pushad
    ; A = [wNumSprites source] = sprite_count byte; ESI advances past it.
    ; W_OBJECT_DATA_PTR_TEMP holds the GB offset of the sprite_count byte.
    movzx esi, word [ebp + W_OBJECT_DATA_PTR_TEMP]   ; ESI = GB addr of sprite_count
    movzx eax, byte [ebp + esi]
    mov [ebp + wNumSprites], al                       ; wNumSprites = count
    inc esi                                            ; past the count byte
    call ZeroSpriteStateData
    call DisableRegularSprites
    ; zero wMapSpriteData ($20 bytes) — pret: ld hl,wMapSpriteData; ld bc,$20; FillMemory
    mov edi, wMapSpriteData
    xor al, al
    mov ecx, 0x20
    rep stosb
    ; any sprites?
    movzx eax, byte [ebp + wNumSprites]
    test al, al
    jz .done
    mov ebx, eax                                       ; EBX = count remaining (pret B)
    mov edx, 0x10                                       ; EDX = slot byte offset (slot 1)
    xor edi, edi                                        ; EDI = wMapSpriteData index (pret C): 0,2,4,...
.loadSpriteLoop:
    ; picture id -> x#SPRITESTATEDATA1_PICTUREID
    movzx eax, byte [ebp + esi]
    inc esi
    mov [ebp + edx + W_SPRITE_STATE_DATA_1 + SPRITESTATEDATA1_PICTUREID], al
    ; mapy -> x#SPRITESTATEDATA2_MAPY
    movzx eax, byte [ebp + esi]
    inc esi
    mov [ebp + edx + W_SPRITE_STATE_DATA_2 + SPRITESTATEDATA2_MAPY], al
    ; mapx -> x#SPRITESTATEDATA2_MAPX
    movzx eax, byte [ebp + esi]
    inc esi
    mov [ebp + edx + W_SPRITE_STATE_DATA_2 + SPRITESTATEDATA2_MAPX], al
    ; movement byte 1 -> x#SPRITESTATEDATA2_MOVEMENTBYTE1
    movzx eax, byte [ebp + esi]
    inc esi
    mov [ebp + edx + W_SPRITE_STATE_DATA_2 + SPRITESTATEDATA2_MOVEMENTBYTE1], al
    ; movement byte 2 -> temp1
    movzx eax, byte [ebp + esi]
    inc esi
    mov [h_load_sprite_temp1], al
    ; text id + flags -> temp2
    movzx eax, byte [ebp + esi]
    inc esi
    mov [h_load_sprite_temp2], al
    ; DIVERGENCE (port ext): set the per-slot ISTRAINER flag (SPRITESTATEDATA2 0x0A)
    ; that the port interaction stack (CheckNPCInteraction / CheckTrainerSight /
    ; TrainerEncounterFlow) reads. pret has no such field — it re-derives trainer-ness
    ; from the text-id flags at interaction time (IsSpriteOrSignInFrontOfPlayer, unported).
    ; The bespoke InitMapSprites used to set this; it is retired in P3c, so InitSprites
    ; (the slot populator) carries it. ZeroSpriteStateData already cleared the slot.
    test al, TRAINER_FLAG
    jz .not_trainer_slot
    mov byte [ebp + edx + W_SPRITE_STATE_DATA_2 + SPRITESTATEDATA2_ISTRAINER], 1
.not_trainer_slot:
    ; LoadSprite: ECX = wMapSpriteData index; ESI = read ptr (advanced past any
    ; trainer/item extra bytes on return). It preserves EBX/EDX/EDI and clobbers EAX.
    mov ecx, edi
    call LoadSprite
    ; advance to next sprite: slot offset += $10, wMapSpriteData index += 2, count--
    add edx, 0x10
    add edi, 2
    dec ebx
    jnz .loadSpriteLoop
.done:
    popad
    ret

; Zero sprite state data for slots 1-14 (slot 15 is Pikachu, left intact — pret).
ZeroSpriteStateData:
    push eax
    push ecx
    push edi
    xor al, al
    lea edi, [ebp + W_SPRITE_STATE_DATA_1 + 0x10]      ; slot 1
    mov ecx, 14 * 0x10
    rep stosb
    lea edi, [ebp + W_SPRITE_STATE_DATA_2 + 0x10]
    mov ecx, 14 * 0x10
    rep stosb
    pop edi
    pop ecx
    pop eax
    ret

; Disable regular sprites: SPRITESTATEDATA1_IMAGEINDEX for slots 1-14.
; DIVERGENCE (harness-only; zero real-game effect): pret writes $ff here — a
; "hidden until initialized" marker. This seed is IRRELEVANT to the running game:
; the first UpdateSprites frame calls InitializeSpriteStatus (movement.asm:727),
; which unconditionally overwrites IMAGEINDEX with $ff; the second frame's
; CheckSpriteAvailability → UpdateSpriteImage then computes the real facing index.
; So under the live game (EnterMap + OverworldLoop both run UpdateSprites) a $ff or
; a 0 seed here behave identically. The seed ONLY changes the STATIC pre-UpdateSprites
; DEBUG-harness snapshot (DEBUG_BASELINE etc. render without running UpdateSprites):
; $ff hides the NPCs there, 0 (the ZeroSpriteStateData value → facing-down anim-0)
; shows them. We keep 0 so that regression snapshot still exercises NPC rendering.
; Restoring the faithful $ff needs the DEBUG harness to run UpdateSprites like EnterMap
; — but on frame 2 the port's random-movement path makes a WALK NPC try to move
; immediately (no initial move-delay), so it also needs pret's move-delay/probability
; ported (movement-engine work, OW-A.7 territory) to keep the snapshot deterministic.
DisableRegularSprites:
    push ecx
    push esi
    mov esi, 0x10                                       ; slot 1
    mov ecx, 14
.loop:
    mov byte [ebp + esi + W_SPRITE_STATE_DATA_1 + SPRITESTATEDATA1_IMAGEINDEX], 0
    add esi, 0x10
    dec ecx
    jnz .loop
    pop esi
    pop ecx
    ret

; LoadSprite (pret home/overworld.asm:2218). In: ECX = wMapSpriteData/ExtraData byte
; index ((slot-1)*2); ESI = GB read ptr just past the text-id byte; temp1 = movement
; byte 2, temp2 = text id + flags. Out: ESI advanced past trainer/item extra bytes.
; Preserves EBX/ECX/EDX/EDI; clobbers EAX.
LoadSprite:
    push eax
    ; wMapSpriteData[C] = movement byte 2
    mov al, [h_load_sprite_temp1]
    mov [wMapSpriteData + ecx], al
    ; pret writes text id+flags to [C+1] here then immediately overwrites it with the
    ; masked value — kept for faithfulness ("this appears pointless").
    mov al, [h_load_sprite_temp2]
    mov [wMapSpriteData + ecx + 1], al
    mov al, [h_load_sprite_temp2]
    mov [h_load_sprite_temp1], al                       ; temp1 = text id+flags (save for flag test)
    and al, 0x3f
    mov [wMapSpriteData + ecx + 1], al                  ; wMapSpriteData[C+1] = masked text id
    ; branch on the raw (unmasked) text-id+flags byte
    mov al, [h_load_sprite_temp1]
    test al, TRAINER_FLAG
    jnz .trainerSprite
    test al, ITEM_FLAG
    jnz .itemBallSprite
    ; regular sprite: zero both wMapSpriteExtraData bytes
    mov word [wMapSpriteExtraData + ecx], 0
    pop eax
    ret
.trainerSprite:
    movzx eax, byte [ebp + esi]                         ; trainer class
    inc esi
    mov [h_load_sprite_temp1], al
    movzx eax, byte [ebp + esi]                         ; trainer number
    inc esi
    mov [h_load_sprite_temp2], al
    mov al, [h_load_sprite_temp1]
    mov [wMapSpriteExtraData + ecx], al                 ; ExtraData[C] = trainer class
    mov al, [h_load_sprite_temp2]
    mov [wMapSpriteExtraData + ecx + 1], al             ; ExtraData[C+1] = trainer number
    pop eax
    ret
.itemBallSprite:
    movzx eax, byte [ebp + esi]                         ; item number
    inc esi
    mov [h_load_sprite_temp1], al
    mov al, [h_load_sprite_temp1]
    mov [wMapSpriteExtraData + ecx], al                 ; ExtraData[C] = item number
    mov byte [wMapSpriteExtraData + ecx + 1], 0         ; ExtraData[C+1] = 0
    pop eax
    ret

CopyMapConnectionHeader:
    push ecx
    push edi
    add edi, ebp
    mov ecx, CONN_HEADER_SIZE
    rep movsb
    pop edi
    pop ecx
    ret

; ---------------------------------------------------------------------------
; LoadTilesetHeader — dynamic dispatch via W_CUR_MAP_TILESET.
; Pret ref: home/overworld.asm:LoadTilesetHeader
; Copies current tileset gfx/blocks/coll from .data section → fixed EBP slots,
; then sets g_tilecache_dirty so render_bg rebuilds the decoded-tile cache.
; ---------------------------------------------------------------------------
LoadTilesetHeader:
    push eax
    push ebx
    push esi
    push edi
    push ecx

    movzx eax, byte [ebp + W_CUR_MAP_TILESET]   ; tileset index 0-24

    ; Copy tileset GFX to fixed EBP slot
    mov esi, [TilesetGfxPtrs + eax*4]
    lea edi, [ebp + OW_GFX_GBADDR]
    mov ecx, [TilesetGfxSizes + eax*4]
    rep movsb

    ; Copy blockset to fixed EBP slot
    mov esi, [TilesetBlocksPtrs + eax*4]
    lea edi, [ebp + OW_BLOCKS_GBADDR]
    mov ecx, [TilesetBlocksSizes + eax*4]
    rep movsb

    ; Copy collision list to fixed EBP slot (max 64 bytes, $FF-terminated)
    mov esi, [TilesetCollPtrs + eax*4]
    lea edi, [ebp + OW_COLL_GBADDR]
    mov ecx, 64
    rep movsb

    ; Mark tile cache dirty — render_bg must rebuild decoded tiles
    mov byte [g_tilecache_dirty], 1

    ; Populate tileset header fields in WRAM.
    ; TODO-HW: wTilesetBank is meaningless under flat memory (no ROM banking) —
    ; left as a fixed no-op write, faithful in spirit to pret's CopyData'd bank
    ; byte, but never consumed as a real bank switch. Pret ref: engine/overworld/
    ; tilesets.asm (ld a,[hl] / ldh [hTileAnimations],a is the real 12th byte;
    ; the bank byte itself is CopyData'd from Tilesets[0]).
    mov byte [ebp + W_TILESET_BANK], 0x01  ; TODO-HW: banking no-op under flat memory
    mov word [ebp + W_TILESET_BLOCKS_PTR], OW_BLOCKS_GBADDR
    mov word [ebp + W_TILESET_GFX_PTR],   OW_GFX_GBADDR
    mov word [ebp + W_TILESET_COLLISION_PTR],  OW_COLL_GBADDR
    ; Per-tileset grass tile + tile-animation kind — pret ref: data/tilesets/
    ; tileset_headers.asm (`tileset` macro \5/\6 fields), inlined below as
    ; TilesetGrassTiles/TilesetAnimations (small pret data tables, EAX still
    ; holds the 0-24 tileset index from the movzx above).
    mov bl, [TilesetGrassTiles + eax]
    mov [ebp + W_GRASS_TILE], bl
    mov bl, [TilesetAnimations + eax]
    mov [ebp + H_TILE_ANIMATIONS], bl

    ; Per-tileset counter ("talking-over") tiles. pret copies these as bytes 7-9 of the
    ; 12-byte tileset header (wTilesetTalkingOverTiles, 3 bytes; part of its $b-byte
    ; CopyData in LoadTilesetHeader). Consumed by IsSpriteOrSignInFrontOfPlayer's
    ; .counterTilesLoop to extend NPC talking range over Pokemart/Pokecenter counters.
    ; Not yet read by the port's bespoke CheckNPCInteraction, but populated here so the
    ; data is correct when talking-range-over-counter lands. Table inlined below;
    ; EAX still holds the 0-24 tileset index (preserved through here for IsInArray).
    lea edi, [eax + eax*2]                       ; EDI = tileset * 3 (row into the table)
    mov bl, [TilesetCounterTiles + edi + 0]
    mov [ebp + W_TILESET_TALKING_OVER_TILES + 0], bl
    mov bl, [TilesetCounterTiles + edi + 1]
    mov [ebp + W_TILESET_TALKING_OVER_TILES + 1], bl
    mov bl, [TilesetCounterTiles + edi + 2]
    mov [ebp + W_TILESET_TALKING_OVER_TILES + 2], bl

    ; -----------------------------------------------------------------------
    ; Pret tail — engine/overworld/tilesets.asm lines 21-47 (previously
    ; silently omitted; see docs/current_plan_overworld_port.md OW-A.1).
    ; Gates the warp-arrival sub-block alignment (wYBlockCoord/wXBlockCoord =
    ; coord & 1) behind a dungeon-tileset check and a "did the tileset change"
    ; compare, exactly as pret does.
    ; -----------------------------------------------------------------------
    mov edx, 1                          ; IsInArray entry stride (1 byte/tileset id)
    mov esi, DungeonTilesets
    call IsInArray                      ; AL (tileset id) still set from the movzx above
    jc .dungeon                         ; pret: jr c, .dungeon

    ; pret: ld a,[wCurMapTileset] / ld b,a / ldh a,[hPreviousTileset] / cp b / jr z,.done
    mov bl, al                           ; BL = current tileset (AL untouched by IsInArray)
    mov al, [ebp + H_PREVIOUS_TILESET]   ; HRAM union w/ hMapStride/hNSConnectionStripWidth — read-only here
    cmp al, bl
    je .done                            ; tileset unchanged and not a dungeon tileset — skip realignment

.dungeon:
    cmp byte [ebp + W_DESTINATION_WARP_ID], 0xFF
    je .done                            ; pret: ld a,[wDestinationWarpID] / cp $ff / jr z,.done

    call LoadDestinationWarpPosition     ; pret: call LoadDestinationWarpPosition
    mov al, [ebp + W_Y_COORD]            ; pret: ld a,[wYCoord] / and $1 / ld [wYBlockCoord],a
    and al, 1
    mov [ebp + W_Y_BLOCK_COORD], al
    mov al, [ebp + W_X_COORD]            ; pret: ld a,[wXCoord] / and $1 / ld [wXBlockCoord],a
    and al, 1
    mov [ebp + W_X_BLOCK_COORD], al

.done:
    pop ecx
    pop edi
    pop esi
    pop ebx
    pop eax
    ret

; ---------------------------------------------------------------------------
; LoadDestinationWarpPosition — load spawn Y/X from the destination map's warp
; table entry selected by W_DESTINATION_WARP_ID.
; Pret ref: home/overworld.asm:LoadDestinationWarpPosition
; PROJ divergence: pret's predef version copies a 4-byte (block-view-pointer,
; Y, X) struct from an hl-indexed ROM table straight into
; wCurrentTileBlockMapViewPointer/wYCoord/wXCoord. The port has no parallel
; per-map view-pointer table; it reads Y/X directly out of the already-loaded
; W_WARP_ENTRIES (Y, X, dest_warp_id, dest_map_id per entry — see the
; `warp_event` macro / CheckWarpTile), and leaves wCurrentTileBlockMapViewPointer
; to LoadWarpDestination's explicit stride-math recompute, which replaces
; pret's ROM view-pointer lookup with an equivalent runtime computation.
; In:  W_DESTINATION_WARP_ID = 0-based warp index (destination map's table)
; Out: W_Y_COORD, W_X_COORD set. Preserves all other registers/flags.
; ---------------------------------------------------------------------------
LoadDestinationWarpPosition:
    push eax
    push esi

    movzx eax, byte [ebp + W_DESTINATION_WARP_ID]
    shl eax, 2                          ; * 4 bytes per warp entry
    lea esi, [ebp + W_WARP_ENTRIES]
    add esi, eax
    mov al, [esi]                       ; spawn Y tile
    mov [ebp + W_Y_COORD], al
    mov al, [esi+1]                     ; spawn X tile
    mov [ebp + W_X_COORD], al

    pop esi
    pop eax
    ret

; ---------------------------------------------------------------------------
; IgnoreInputForHalfSecond — suppress player input for ~30 frames after a warp.
; Sets wIgnoreInputCounter=30 and BIT_DISABLE_JOYPAD in wStatusFlags5.
; The countdown runs at the top of OverworldLoop; joypad is re-enabled when it
; reaches 0. OverworldLoop's idle path skips direction reads while the bit is set.
; Pret ref: home/overworld.asm:IgnoreInputForHalfSecond
; ---------------------------------------------------------------------------
IgnoreInputForHalfSecond:
    mov byte [ebp + W_IGNORE_INPUT_COUNTER], 30
    or byte [ebp + W_STATUS_FLAGS_5], (1 << BIT_DISABLE_JOYPAD) | (1 << 2) | (1 << 1)
    ret

; ---------------------------------------------------------------------------
; IsPlayerStandingOnDoorTile — check if the player's current tile is a door tile.
; Returns CF=1 if yes, CF=0 otherwise (stair, ladder, or unknown tileset).
; Reads W_CUR_MAP_TILESET, looks up DoorTileTable, then checks W_TILEMAP at
; PLAYER_STANDING_ROW/COL (the tile directly under the player sprite).
; All registers preserved.
; Pret ref: engine/overworld/doors.asm:IsPlayerStandingOnDoorTile
; ---------------------------------------------------------------------------
IsPlayerStandingOnDoorTile:
    push eax
    push esi

    movzx eax, byte [ebp + W_CUR_MAP_TILESET]
    mov esi, DoorTileTable

.search_tileset:
    cmp byte [esi], 0xFF               ; end of table → tileset not listed
    je .not_door
    cmp byte [esi], al                 ; tileset match?
    je .found_tileset
    inc esi                            ; skip tileset byte, then scan past 0-terminated tile list
.skip_tiles:
    cmp byte [esi], 0
    je .skip_done
    inc esi
    jmp .skip_tiles
.skip_done:
    inc esi                            ; skip the 0 terminator
    jmp .search_tileset

.found_tileset:
    inc esi                            ; ESI now points at first tile ID for this tileset
    movzx eax, byte [ebp + W_TILEMAP + PLAYER_STANDING_ROW * SCREEN_TILES_W + PLAYER_STANDING_COL]
.check_tile:
    cmp byte [esi], 0
    je .not_door
    cmp [esi], al
    je .is_door
    inc esi
    jmp .check_tile

.is_door:
    pop esi
    pop eax
    stc
    ret
.not_door:
    pop esi
    pop eax
    clc
    ret

; ---------------------------------------------------------------------------
; PlayMapChangeSound — on a warp, play the "go inside" jingle if the player
; walked through an overworld door tile, else "go outside".
; Pret ref: home/overworld.asm:PlayMapChangeSound (:666). Called from WarpFound2
; (the port's .warpTransition) before EnterMap, so it reads the SOURCE map's
; tilemap (the door the player stepped on), not the destination.
; Preserves nothing pret doesn't (AL used); the caller has no live regs here.
; ---------------------------------------------------------------------------
PlayMapChangeSound:
    mov al, [ebp + W_CUR_MAP_TILESET]
    cmp al, FACILITY
    je .didNotGoThroughDoor
    cmp al, CEMETERY
    je .didNotGoThroughDoor
    ; pret lda_coord 8, 8 = upper-left tile of the player's block, one row above the
    ; standing tile (lda_coord 8, 9 → port PLAYER_STANDING). Port row scaling is 1:1
    ; (fronts are ±2 rows), so project to (PLAYER_STANDING_ROW - 1, PLAYER_STANDING_COL).
    ; ; PROJ: this door-tile row projection + the pre-EnterMap tilemap timing are
    ; unverified (no golden warp scenario) — the go-inside/go-outside SFX selection
    ; needs MCP live-warp verification. Wrong projection only mis-picks the jingle.
    movzx eax, byte [ebp + W_TILEMAP + (PLAYER_STANDING_ROW - 1) * SCREEN_TILES_W + PLAYER_STANDING_COL]
    cmp al, OVERWORLD_DOOR_TILE                  ; pret: cp $0b (door tile in tileset 0)
    jne .didNotGoThroughDoor
    mov al, SFX_GO_INSIDE
    jmp .playSound
.didNotGoThroughDoor:
    mov al, SFX_GO_OUTSIDE
.playSound:
    call PlaySound
    ; pret tail: if wMapPalOffset != 0 ret; else jp GBFadeOutToBlack.
    ; TODO-HW: palette/fade (Phase 5) — GBFadeOutToBlack deferred (DMG-green debug palette).
    ret

; ---------------------------------------------------------------------------
; PlayerStepOutFromDoor — force one auto-step south off a warp-arrival tile.
; Called by RunNPCMovementScript when BIT_STANDING_ON_DOOR is detected.
; Calls IsPlayerStandingOnDoorTile first: if not a door tile (stair/ladder),
; clears the flags with no auto-walk. If on a door tile, sets BIT_EXITING_DOOR
; (marks auto-walk in progress) and BIT_SCRIPTED_MOVEMENT_STATE (injects PAD_DOWN
; into the idle-path direction logic; .handleDirection bypasses the turn-delay and
; fires the collision-exit warp). Pret ref: engine/overworld/auto_movement.asm:PlayerStepOutFromDoor
; ---------------------------------------------------------------------------
PlayerStepOutFromDoor:
    ; pret auto_movement.asm:PlayerStepOutFromDoor entry — clear BIT_UNKNOWN_5_1 in
    ; wStatusFlags5 unconditionally (both door and non-door paths run through here).
    and byte [ebp + W_STATUS_FLAGS_5], ~(1 << BIT_UNKNOWN_5_1)
    call IsPlayerStandingOnDoorTile
    jnc .notStandingOnDoor
    ; Door tile — set up one forced south step to walk off the arrival warp tile.
    or byte [ebp + W_MOVEMENT_FLAGS], (1 << BIT_EXITING_DOOR)
    mov byte [ebp + W_SIMULATED_JOYPAD_STATES_INDEX], 1
    mov byte [ebp + W_SIMULATED_JOYPAD_STATES_END], PAD_DOWN
    xor al, al
    mov [ebp + W_SPRITE_PLAYER_IMAGE_INDEX], al       ; pret: wSpritePlayerStateData1ImageIndex = 0
    ; StartSimulatingJoypadStates zeroes the override mask + slot-0 movement byte 1 and
    ; sets BIT_SCRIPTED_MOVEMENT_STATE so AreInputsSimulated feeds this one PAD_DOWN.
    ; (pret PlayerStepOutFromDoor also sets wJoyIgnore; omitted here because the port
    ; drains the 1-step buffer at .handleDirection rather than via AreInputsSimulated's
    ; .doneSimulating, so a lingering wJoyIgnore would leak — TODO(home-rectify M3.3
    ; follow-up): re-add wJoyIgnore once multi-step scripts drain via .doneSimulating.)
    call StartSimulatingJoypadStates
    ret
.notStandingOnDoor:
    ; Stair/ladder arrival — no auto-walk. Clear standing and exiting flags.
    ; pret: engine/overworld/auto_movement.asm:PlayerStepOutFromDoor:.notStandingOnDoor
    ; Zero the simulated-joypad fields first: otherwise a stale index/queued PAD_* byte
    ; leaks into AreInputsSimulated and would replay a phantom step on the next frame.
    xor al, al
    mov byte [ebp + W_UNUSED_OVERRIDE_SIMULATED_JOYPAD_STATES_INDEX], al
    mov byte [ebp + W_SIMULATED_JOYPAD_STATES_INDEX], al
    mov byte [ebp + W_SIMULATED_JOYPAD_STATES_END],   al
    and byte [ebp + W_MOVEMENT_FLAGS], ~((1 << BIT_STANDING_ON_DOOR) | (1 << BIT_EXITING_DOOR))
    and byte [ebp + W_STATUS_FLAGS_5], ~(1 << BIT_SCRIPTED_MOVEMENT_STATE)
    ret

; ---------------------------------------------------------------------------
; RunNPCMovementScript — dispatch door-exit auto-walk on warp arrival.
; Checks BIT_STANDING_ON_DOOR (set by .warpTransition), clears it, and calls
; PlayerStepOutFromDoor to inject one forced DOWN step and set BIT_EXITING_DOOR.
; Phase 2: door path only. Full NPC movement script dispatch deferred to Phase 3.
; Pret ref: home/npc_movement.asm:RunNPCMovementScript
; ---------------------------------------------------------------------------
RunNPCMovementScript:
    ; pret: home/npc_movement.asm:RunNPCMovementScript
    test byte [ebp + W_MOVEMENT_FLAGS], (1 << BIT_STANDING_ON_DOOR)
    jz .notDoor
    and byte [ebp + W_MOVEMENT_FLAGS], ~(1 << BIT_STANDING_ON_DOOR)
    call PlayerStepOutFromDoor
    ret
.notDoor:
    ; Scripted-NPC-movement dispatch half: index wNPCMovementScriptPointerTableNum
    ; (1-based) into a table of per-map movement-script pointer tables, then call
    ; function wNPCMovementScriptFunctionNum within it (pret: CallFunctionInTable).
    ; Bankswitching is a no-op under flat memory. UNGATED at OW-7.3 (2026-07-10):
    ; the NPC_MOVEMENT_SCRIPTS_LINKED %ifdef existed only because the per-map
    ; pointer tables (auto_movement.asm / pewter_guys chain) weren't linked; the
    ; OW-7.2 promotion linked them. Still inert until a script sets the table
    ; num nonzero (OW-2.5 Oak cutscene wires the first one).
    mov al, [ebp + wNPCMovementScriptPointerTableNum]
    test al, al
    jz .done
    dec al                                          ; table num is 1-based
    movzx eax, al
    mov esi, [NPCMovementScriptPointerTables + eax*4] ; ESI = flat per-map jumptable
    mov al, [ebp + W_NPC_MOVEMENT_SCRIPT_FUNCTION_NUM]
    call CallFunctionInTable                        ; call function AL within ESI
.done:
    ret

extern CallFunctionInTable
extern PalletMovementScriptPointerTable
extern PewterMuseumGuyMovementScriptPointerTable
extern PewterGymGuyMovementScriptPointerTable
; pret: RunNPCMovementScript.NPCMovementScriptPointerTables (flat dd in the port;
; read-only, lives in .text by placement — reads only, never written)
NPCMovementScriptPointerTables:
    dd PalletMovementScriptPointerTable
    dd PewterMuseumGuyMovementScriptPointerTable
    dd PewterGymGuyMovementScriptPointerTable

; ---------------------------------------------------------------------------
; CheckWarpTile — scan W_WARP_ENTRIES for a player coord match.
; Returns CF=1 if a warp matches; BL = resolved destination map ID;
; W_DESTINATION_WARP_ID = 0-based warp index in the destination map.
; Returns CF=0 if no match.
; Pret ref: home/overworld.asm:CheckForWarpTile (approach)
; ---------------------------------------------------------------------------
CheckWarpTile:
    push eax
    push ecx
    push esi

    movzx ecx, byte [ebp + W_NUMBER_OF_WARPS]
    test ecx, ecx
    jz .none
    mov al, [ebp + W_Y_COORD]
    mov ah, [ebp + W_X_COORD]
    lea esi, [ebp + W_WARP_ENTRIES]
.loop:
    cmp al, [esi]               ; Y match?
    jne .next
    cmp ah, [esi+1]             ; X match?
    jne .next
    mov bl, [esi+2]             ; dest_warp_id (0-based index in dest map)
    mov [ebp + W_DESTINATION_WARP_ID], bl
    mov bl, [esi+3]             ; dest_map_id (0xFF = LAST_MAP)
    cmp bl, 0xFF
    jne .found
    mov bl, [ebp + W_LAST_MAP]  ; resolve LAST_MAP to the previous map
.found:
    pop esi
    pop ecx
    pop eax
    stc
    ret
.next:
    add esi, 4
    dec ecx
    jnz .loop
.none:
    pop esi
    pop ecx
    pop eax
    clc
    ret

; ---------------------------------------------------------------------------
; LoadWarpDestination — load the destination map after a warp transition.
; Preconditions: W_CUR_MAP = destination map ID already set by caller;
;                W_DESTINATION_WARP_ID = 0-based index into that map's warp
;                table, used to resolve the player spawn coords.
;
; OW-A.5 DIVERGENCE (deferred faithfulness): this is a bespoke consolidation of
; pret's WarpFound2 map-change tail (home/overworld.asm:455-517). The following
; WarpFound2 pieces are intentionally NOT ported yet — each waits on its subsystem:
;   - ROCK_TUNNEL_1F special-case: wMapPalOffset=$06 + GBFadeOutToBlack (:470-474)
;     — TODO-HW: palette/fade (Phase 5; DMG-green is debug-only until then).
;   - PlayMapChangeSound (:477/498/510) — TODO-HW: audio (Phase 3).
;   - IsPlayerStandingOnWarpPadOrHole → warp-pad branch: LeaveMapAnim +
;     set BIT_FLY_WARP (:488-495) — TODO: fly/warp-pad subsystem (rides OW-7.2 /
;     the fly/dungeon-warp anim block already gated in EnterMap).
;   - SetPikachuSpawnOutside/WarpPad/BackOutside (:476/503/507) — TODO: Pikachu-
;     follower subsystem (cf. SpawnPikachu stub).
;   - wMapPalOffset reset on the .goBackOutside path (:512) — TODO-HW: palette.
;   - wWarpedFromWhichWarp/wWarpedFromWhichMap saves (:456-460) — not yet consumed
;     by any ported code; restore with the map-script/back-warp resolver.
; The wCurMap/wLastMap update + BIT_STANDING_ON_DOOR + IgnoreInputForHalfSecond +
; jp EnterMap half of WarpFound2 lives in OverworldLoop.warpTransition (OW-A.4(b)).
; ---------------------------------------------------------------------------
LoadWarpDestination:
    push eax
    push ebx
    push ecx
    push esi
    push edi

    ; Indoor maps use a shared EBP slot (INDOOR_BLK_GBADDR).  Copy this map's
    ; .blk bytes there before calling LoadMapHeader, which reads blk_ptr=INDOOR_BLK_GBADDR
    ; from the header and stores it in W_CUR_MAP_DATA_PTR → LoadTileBlockMap
    ; then reads the block layout from that address.
    movzx eax, byte [ebp + W_CUR_MAP]
    cmp eax, FIRST_INDOOR_MAP_ID
    jb .outdoor
    sub eax, FIRST_INDOOR_MAP_ID              ; 0-based table index
    mov esi, [IndoorMapBlkPtrs + eax*4]       ; flat DS label for this map's .blk
    lea edi, [ebp + INDOOR_BLK_GBADDR]
    mov ecx, [IndoorMapBlkSizes + eax*4]      ; byte count
    rep movsb
.outdoor:
    ; Load map header: copies fixed header to WRAM, copies warp entries to
    ; W_WARP_ENTRIES, and calls LoadTilesetHeader (which swaps tileset data
    ; into the fixed EBP ROM-window slots and sets g_tilecache_dirty).
    call LoadMapHeader

    ; After a tileset switch, copy GFX from OW_GFX_GBADDR → GB_VCHARS2 so
    ; render_bg rebuilds the tile decode cache from the new tileset.
    call LoadTilesetTilePatternData

    ; Resolve spawn coords from the destination map's warp table.
    ; W_DESTINATION_WARP_ID is the 0-based index set by CheckWarpTile.
    ; Factored into the shared LoadDestinationWarpPosition (pret name; see its
    ; definition above, right after LoadTilesetHeader) so this always-run warp
    ; arrival resolution and LoadTilesetHeader's pret-faithful, gated tail (which
    ; just ran a few lines up, inside the `call LoadMapHeader` above) share one
    ; implementation rather than duplicating the W_WARP_ENTRIES read. Unlike
    ; LoadTilesetHeader's gated call, this path always needs the spawn position —
    ; a genuine warp transition always has a valid W_DESTINATION_WARP_ID (never
    ; $FF) — so the & 1 block-coord alignment is redone here unconditionally.
    call LoadDestinationWarpPosition
    mov al, [ebp + W_Y_COORD]
    and al, 1
    mov [ebp + W_Y_BLOCK_COORD], al
    mov al, [ebp + W_X_COORD]
    and al, 1
    mov [ebp + W_X_BLOCK_COORD], al

    ; Recompute W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR from the spawn coordinates.
    ;   stride   = W_CUR_MAP_WIDTH + 2*MAP_BORDER
    ;   view_row = block_y + MAP_BORDER - SCREEN_BLOCK_HEIGHT/2   (block_y = Y/2)
    ;   view_col = block_x + MAP_BORDER - SCREEN_BLOCK_WIDTH/2    (block_x = X/2)
    ;   ptr      = W_OVERWORLD_MAP + view_row * stride + view_col
    movzx eax, byte [ebp + W_CUR_MAP_WIDTH]
    add eax, MAP_BORDER * 2                   ; EAX = stride

    movzx ebx, byte [ebp + W_Y_COORD]
    shr ebx, 1                                ; EBX = block_y
    add ebx, MAP_BORDER
    sub ebx, SCREEN_BLOCK_HEIGHT / 2          ; EBX = view_row

    movzx ecx, byte [ebp + W_X_COORD]
    shr ecx, 1                                ; ECX = block_x
    add ecx, MAP_BORDER
    sub ecx, SCREEN_BLOCK_WIDTH / 2           ; ECX = view_col

    imul eax, ebx                             ; EAX = view_row * stride
    add eax, ecx                              ; + view_col
    add eax, W_OVERWORLD_MAP                  ; + base = EBP-relative ptr
    mov [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR], ax

    call LoadTileBlockMap
    call LoadCurrentMapView

    ; Determine whether the spawn coords land on a warp tile and record it in
    ; BIT_STANDING_ON_WARP. Required so the collision-exit path fires when the
    ; scripted (or manual) south-step hits the building exit on the next idle frame.
    ; Mirrors pret: IsPlayerStandingOnWarp called from EnterMap.
    ; CheckWarpTile uses the W_WARP_ENTRIES now loaded for the destination map,
    ; and overwrites BL with the resolved back-destination — safe since EBX is
    ; caller-saved (pushed at the top of this routine).
    ;
    ; DIVERGENCE (double map load): pret's WarpFound2 does not call LoadMapHeader —
    ; it falls into EnterMap, which loads the map exactly once. The port front-loads
    ; LoadMapHeader here, and `.warpTransition` then `jmp EnterMap`, so LoadMapData →
    ; LoadMapHeader → LoadTilesetHeader runs a SECOND time. LoadTilesetHeader's
    ; faithful pret tail (engine/overworld/tilesets.asm:21-47) re-derives the spawn
    ; coords with `call LoadDestinationWarpPosition` whenever the tileset changed and
    ; wDestinationWarpID != $FF. CheckWarpTile below overwrites wDestinationWarpID
    ; with the ARRIVAL tile's outbound warp id, so that second pass resolved a
    ; different warp entry: entering Viridian Forest from the south gate (warp 3,
    ; the bottom of the map) landed the player on warp 1 (the top) while the view
    ; pointer — already stored above — still pointed at warp 3. Player and camera
    ; disagreed, and the top row let him walk off the map (wYCoord 0 -> 255).
    ; Preserve the id so the second pass re-derives the SAME coords (idempotent).
    ; Retire this save/restore when the front-loaded LoadMapHeader goes away.
    mov cl, [ebp + W_DESTINATION_WARP_ID]
    and byte [ebp + W_MOVEMENT_FLAGS], ~(1 << BIT_STANDING_ON_WARP)
    call CheckWarpTile
    jnc .no_spawn_warp
    or byte [ebp + W_MOVEMENT_FLAGS], (1 << BIT_STANDING_ON_WARP)
.no_spawn_warp:
    mov [ebp + W_DESTINATION_WARP_ID], cl

    ; Reset turn state: player spawns stopped, so the next press should turn
    ; first rather than immediately walking (prevents accidental exit on entry).
    mov byte [ebp + W_CHECK_FOR_TURN], 1
    mov byte [ebp + W_PLAYER_LAST_STOP_DIRECTION], 0
    mov byte [ebp + W_PLAYER_MOVING_DIRECTION], 0

    pop edi
    pop esi
    pop ecx
    pop ebx
    pop eax
    ret

; ---------------------------------------------------------------------------
; CheckMapConnections — faithful translation.
; Pret ref: home/overworld.asm:CheckMapConnections
; ---------------------------------------------------------------------------
CheckMapConnections:
    push ebx
    push edx

    ; Edge thresholds
    mov al, [ebp + W_CUR_MAP_HEIGHT]
    add al, al
    mov [ebp + W_CURRENT_MAP_HEIGHT_2], al
    mov al, [ebp + W_CUR_MAP_WIDTH]
    add al, al
    mov [ebp + W_CURRENT_MAP_WIDTH_2], al

    ; East connection check
    mov al, [ebp + W_X_COORD]
    cmp al, [ebp + W_CURRENT_MAP_WIDTH_2]
    jne .checkWest
    mov al, [ebp + W_EAST_CONNECTED_MAP]
    cmp al, MAP_NO_CONNECTION
    je .checkWest
    mov ebx, W_EAST_CONNECTED_MAP
    
    mov [ebp + W_CUR_MAP], al
    mov al, [ebp + W_EAST_CONNECTED_MAP + CONN_X_ALIGN]
    mov [ebp + W_X_COORD], al
    mov al, [ebp + W_Y_COORD]
    mov cl, al
    mov al, [ebp + W_EAST_CONNECTED_MAP + CONN_Y_ALIGN]
    add cl, al
    mov [ebp + W_Y_COORD], cl
    
    mov al, [ebp + W_EAST_CONNECTED_MAP + CONN_VIEW_PTR]
    mov dl, al
    mov al, [ebp + W_EAST_CONNECTED_MAP + CONN_VIEW_PTR + 1]
    mov dh, al
    
    shr cl, 1
    jz .savePointer2
    
.pointerAdjustmentLoop2:
    mov al, [ebp + W_EAST_CONNECTED_MAP + CONN_MAP_WIDTH]
    add al, MAP_BORDER * 2
    movzx eax, al
    add edx, eax
    dec cl
    jnz .pointerAdjustmentLoop2
.savePointer2:
    mov [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR], dx
    jmp .loadNewMap

.checkWest:
    mov al, [ebp + W_X_COORD]
    cmp al, 255
    jne .checkSouth
    mov al, [ebp + W_WEST_CONNECTED_MAP]
    cmp al, MAP_NO_CONNECTION
    je .checkSouth
    mov ebx, W_WEST_CONNECTED_MAP
    
    mov [ebp + W_CUR_MAP], al
    mov al, [ebp + W_WEST_CONNECTED_MAP + CONN_X_ALIGN]
    mov [ebp + W_X_COORD], al
    mov al, [ebp + W_Y_COORD]
    mov cl, al
    mov al, [ebp + W_WEST_CONNECTED_MAP + CONN_Y_ALIGN]
    add cl, al
    mov [ebp + W_Y_COORD], cl
    
    mov al, [ebp + W_WEST_CONNECTED_MAP + CONN_VIEW_PTR]
    mov dl, al
    mov al, [ebp + W_WEST_CONNECTED_MAP + CONN_VIEW_PTR + 1]
    mov dh, al
    
    shr cl, 1
    jz .savePointer1
    
.pointerAdjustmentLoop1:
    mov al, [ebp + W_WEST_CONNECTED_MAP + CONN_MAP_WIDTH]
    add al, MAP_BORDER * 2
    movzx eax, al
    add edx, eax
    dec cl
    jnz .pointerAdjustmentLoop1
.savePointer1:
    mov [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR], dx
    jmp .loadNewMap

.checkSouth:
    mov al, [ebp + W_Y_COORD]
    cmp al, [ebp + W_CURRENT_MAP_HEIGHT_2]
    jne .checkNorth
    mov al, [ebp + W_SOUTH_CONNECTED_MAP]
    cmp al, MAP_NO_CONNECTION
    je .checkNorth
    mov ebx, W_SOUTH_CONNECTED_MAP
    
    mov [ebp + W_CUR_MAP], al
    mov al, [ebp + W_SOUTH_CONNECTED_MAP + CONN_Y_ALIGN]
    mov [ebp + W_Y_COORD], al
    mov al, [ebp + W_X_COORD]
    mov cl, al
    mov al, [ebp + W_SOUTH_CONNECTED_MAP + CONN_X_ALIGN]
    add cl, al
    mov [ebp + W_X_COORD], cl
    
    mov al, [ebp + W_SOUTH_CONNECTED_MAP + CONN_VIEW_PTR]
    mov dl, al
    mov al, [ebp + W_SOUTH_CONNECTED_MAP + CONN_VIEW_PTR + 1]
    mov dh, al
    
    shr cl, 1
    jz .savePointer4
    movzx ecx, cl
    add edx, ecx
.savePointer4:
    mov [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR], dx
    jmp .loadNewMap

.checkNorth:
    mov al, [ebp + W_Y_COORD]
    cmp al, 255
    jne .done
    mov al, [ebp + W_NORTH_CONNECTED_MAP]
    cmp al, MAP_NO_CONNECTION
    je .done
    mov ebx, W_NORTH_CONNECTED_MAP
    
    mov [ebp + W_CUR_MAP], al
    mov al, [ebp + W_NORTH_CONNECTED_MAP + CONN_Y_ALIGN]
    mov [ebp + W_Y_COORD], al
    mov al, [ebp + W_X_COORD]
    mov cl, al
    mov al, [ebp + W_NORTH_CONNECTED_MAP + CONN_X_ALIGN]
    add cl, al
    mov [ebp + W_X_COORD], cl
    
    mov al, [ebp + W_NORTH_CONNECTED_MAP + CONN_VIEW_PTR]
    mov dl, al
    mov al, [ebp + W_NORTH_CONNECTED_MAP + CONN_VIEW_PTR + 1]
    mov dh, al
    
    shr cl, 1
    jz .savePointer3
    movzx ecx, cl
    add edx, ecx
.savePointer3:
    mov [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR], dx
    jmp .loadNewMap

.done:
    pop edx
    pop ebx
    clc                                        ; CF=0 → no transition
    ret

.loadNewMap:
    ; A connection was crossed. pret home/overworld.asm:.loadNewMap inlines the whole
    ; reload here — Pikachu spawn set, LoadMapHeader, PlayDefaultMusicFadeOutCurrent,
    ; RunPaletteCommand(SET_PAL_OVERWORLD), InitMapSprites, LoadTileBlockMap, then
    ; jp OverworldLoopLessDelay. The port instead returns CF=1 and the caller performs
    ; that reload at OverworldLoop.mapTransition, which now does LoadMapHeader +
    ; PlayDefaultMusicFadeOutCurrent (OW-A.14, real); palette reload still deferred.
    ; Only the coordinate/block sync stays inline here.
    ; First, synchronize block coordinates with the new tile coordinates.
    mov al, [ebp + W_X_COORD]
    and al, 1
    mov [ebp + W_X_BLOCK_COORD], al
    mov al, [ebp + W_Y_COORD]
    and al, 1
    mov [ebp + W_Y_BLOCK_COORD], al

    pop edx
    pop ebx
    stc                                        ; CF=1 → transition occurred
    ret

; ---------------------------------------------------------------------------
; Embedded overworld asset data (Phase 2 scaffold).
; gen_overworld_assets.py regenerates these from source binaries.
; ---------------------------------------------------------------------------

section .data

; Door tile IDs per tileset — pret ref: data/tilesets/door_tile_ids.asm
; Format: tileset_id, tile_id..., 0  (one entry per tileset); 0xFF = end table.
; IsPlayerStandingOnDoorTile scans this to decide whether the arrival tile
; after a warp is a building entrance/exit (needs auto-walk) or a stair/ladder (skip).
DoorTileTable:
    db  0, 0x1B, 0x58, 0       ; OVERWORLD
    db  2, 0x5E, 0             ; MART
    db  3, 0x3A, 0             ; FOREST
    db  8, 0x54, 0             ; HOUSE
    db  9, 0x3B, 0             ; FOREST_GATE
    db 10, 0x3B, 0             ; MUSEUM
    db 12, 0x3B, 0             ; GATE
    db 13, 0x1E, 0             ; SHIP
    db 16, 0x04, 0x15, 0       ; INTERIOR
    db 18, 0x1C, 0x38, 0x1A, 0 ; LOBBY
    db 19, 0x1A, 0x1C, 0x53, 0 ; MANSION
    db 20, 0x34, 0             ; LAB
    db 22, 0x43, 0x58, 0x1B, 0 ; FACILITY
    db 23, 0x3B, 0x1B, 0       ; PLATEAU
    db 0xFF                     ; end

; Dungeon-type tilesets — pret ref: data/tilesets/dungeon_tilesets.asm
; (DungeonTilesets). $FF-terminated, stride 1 (searched by LoadTilesetHeader
; via the shared IsInArray, src/home/array.asm).
; Tileset ids per constants/tileset_constants.asm: FOREST=3, MUSEUM=10, SHIP=13,
; CAVERN=17, LOBBY=18, MANSION=19, GATE=12, LAB=20, FACILITY=22, CEMETERY=15,
; GYM=7.
DungeonTilesets:
    db 3            ; FOREST
    db 10           ; MUSEUM
    db 13           ; SHIP
    db 17           ; CAVERN
    db 18           ; LOBBY
    db 19           ; MANSION
    db 12           ; GATE
    db 20           ; LAB
    db 22           ; FACILITY
    db 15           ; CEMETERY
    db 7            ; GYM
    db 0xFF         ; end

; Per-tileset grass tile + tile-animation kind — pret ref: data/tilesets/
; tileset_headers.asm (the `tileset` macro's \5 grass-tile / \6 TILEANIM_*
; fields). Indexed by W_CUR_MAP_TILESET (0-24, constants/tileset_constants.asm
; order); read by LoadTilesetHeader. TILEANIM_NONE=0, TILEANIM_WATER=1,
; TILEANIM_WATER_FLOWER=2 (constants/map_data_constants.asm).
TilesetGrassTiles:
    db 0x52 ; 0  OVERWORLD
    db 0xFF ; 1  REDS_HOUSE_1
    db 0xFF ; 2  MART
    db 0x20 ; 3  FOREST
    db 0xFF ; 4  REDS_HOUSE_2
    db 0xFF ; 5  DOJO
    db 0xFF ; 6  POKECENTER
    db 0xFF ; 7  GYM
    db 0xFF ; 8  HOUSE
    db 0xFF ; 9  FOREST_GATE
    db 0xFF ; 10 MUSEUM
    db 0xFF ; 11 UNDERGROUND
    db 0xFF ; 12 GATE
    db 0xFF ; 13 SHIP
    db 0xFF ; 14 SHIP_PORT
    db 0xFF ; 15 CEMETERY
    db 0xFF ; 16 INTERIOR
    db 0xFF ; 17 CAVERN
    db 0xFF ; 18 LOBBY
    db 0xFF ; 19 MANSION
    db 0xFF ; 20 LAB
    db 0xFF ; 21 CLUB
    db 0xFF ; 22 FACILITY
    db 0x45 ; 23 PLATEAU
    db 0xFF ; 24 BEACH_HOUSE

TilesetAnimations:
    db 2 ; 0  OVERWORLD     TILEANIM_WATER_FLOWER
    db 0 ; 1  REDS_HOUSE_1  TILEANIM_NONE
    db 0 ; 2  MART
    db 1 ; 3  FOREST        TILEANIM_WATER
    db 0 ; 4  REDS_HOUSE_2
    db 2 ; 5  DOJO          TILEANIM_WATER_FLOWER
    db 0 ; 6  POKECENTER
    db 2 ; 7  GYM           TILEANIM_WATER_FLOWER
    db 0 ; 8  HOUSE
    db 0 ; 9  FOREST_GATE
    db 0 ; 10 MUSEUM
    db 0 ; 11 UNDERGROUND
    db 0 ; 12 GATE
    db 1 ; 13 SHIP          TILEANIM_WATER
    db 1 ; 14 SHIP_PORT     TILEANIM_WATER
    db 0 ; 15 CEMETERY
    db 0 ; 16 INTERIOR
    db 1 ; 17 CAVERN        TILEANIM_WATER
    db 0 ; 18 LOBBY
    db 0 ; 19 MANSION
    db 0 ; 20 LAB
    db 0 ; 21 CLUB
    db 1 ; 22 FACILITY      TILEANIM_WATER
    db 1 ; 23 PLATEAU       TILEANIM_WATER
    db 0 ; 24 BEACH_HOUSE

; Per-tileset counter ("talking-over") tiles — pret ref: data/tilesets/
; tileset_headers.asm (the `tileset` macro's \2 \3 \4 fields, "3 counter tiles").
; 3 bytes per tileset ($FF = unused slot), indexed by W_CUR_MAP_TILESET * 3; copied
; into wTilesetTalkingOverTiles by LoadTilesetHeader. These extend NPC talking range
; over Pokemart/Pokecenter/etc. counter tiles (IsSpriteOrSignInFrontOfPlayer).
TilesetCounterTiles:
    db 0xFF, 0xFF, 0xFF ; 0  OVERWORLD
    db 0xFF, 0xFF, 0xFF ; 1  REDS_HOUSE_1
    db 0x18, 0x19, 0x1E ; 2  MART
    db 0xFF, 0xFF, 0xFF ; 3  FOREST
    db 0xFF, 0xFF, 0xFF ; 4  REDS_HOUSE_2
    db 0x3A, 0xFF, 0xFF ; 5  DOJO
    db 0x18, 0x19, 0x1E ; 6  POKECENTER
    db 0x3A, 0xFF, 0xFF ; 7  GYM
    db 0xFF, 0xFF, 0xFF ; 8  HOUSE
    db 0x17, 0x32, 0xFF ; 9  FOREST_GATE
    db 0x17, 0x32, 0xFF ; 10 MUSEUM
    db 0xFF, 0xFF, 0xFF ; 11 UNDERGROUND
    db 0x17, 0x32, 0xFF ; 12 GATE
    db 0xFF, 0xFF, 0xFF ; 13 SHIP
    db 0xFF, 0xFF, 0xFF ; 14 SHIP_PORT
    db 0x12, 0xFF, 0xFF ; 15 CEMETERY
    db 0xFF, 0xFF, 0xFF ; 16 INTERIOR
    db 0xFF, 0xFF, 0xFF ; 17 CAVERN
    db 0x15, 0x36, 0xFF ; 18 LOBBY
    db 0xFF, 0xFF, 0xFF ; 19 MANSION
    db 0xFF, 0xFF, 0xFF ; 20 LAB
    db 0x07, 0x17, 0xFF ; 21 CLUB
    db 0x12, 0xFF, 0xFF ; 22 FACILITY
    db 0xFF, 0xFF, 0xFF ; 23 PLATEAU
    db 0xFF, 0xFF, 0xFF ; 24 BEACH_HOUSE

section .rodata

; per-map (music id, music ROM bank), indexed by map id — pret data/maps/songs.asm
%include "assets/map_songs.inc"

; authored border-ring blocks (map-tool C3; see ApplyMapBorderOverrides)
%include "assets/map_border_overrides.inc"
global overworld_gfx                     ; exported for cut.asm (InitCutAnimOAM tree tiles $2d/$3d)
%include "assets/overworld_gfx.inc"
%include "assets/overworld_blocks.inc"
%include "assets/pallet_town_blk.inc"
%include "assets/route1_blk.inc"
%include "assets/route21_blk.inc"
%include "assets/viridian_city_blk.inc"
%include "assets/pewter_city_blk.inc"
%include "assets/cerulean_city_blk.inc"
%include "assets/lavender_town_blk.inc"
%include "assets/vermilion_city_blk.inc"
%include "assets/celadon_city_blk.inc"
%include "assets/fuchsia_city_blk.inc"
%include "assets/cinnabar_island_blk.inc"
%include "assets/saffron_city_blk.inc"
%include "assets/route2_blk.inc"
%include "assets/route3_blk.inc"
%include "assets/route4_blk.inc"
%include "assets/route5_blk.inc"
%include "assets/route6_blk.inc"
%include "assets/route7_blk.inc"
%include "assets/route8_blk.inc"
%include "assets/route9_blk.inc"
%include "assets/route10_blk.inc"
%include "assets/route11_blk.inc"
%include "assets/route12_blk.inc"
%include "assets/route13_blk.inc"
%include "assets/route14_blk.inc"
%include "assets/route15_blk.inc"
%include "assets/route16_blk.inc"
%include "assets/route17_blk.inc"
%include "assets/route18_blk.inc"
%include "assets/route19_blk.inc"
%include "assets/route20_blk.inc"
%include "assets/route22_blk.inc"
%include "assets/route24_blk.inc"
%include "assets/route25_blk.inc"
%include "assets/overworld_coll.inc"
%include "assets/player_sprite.inc"
; npc_*_still.inc files removed — LoadNPCSpriteTiles reads both still and walk
; halves from the full 384-byte sheet in npc_sprite_data_table.inc.
%include "assets/map_headers.inc"
%include "assets/extra_includes.inc"
