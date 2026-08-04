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

extern CopyData                           ; src/home/copy.asm
extern DelayFrame                         ; src/home/vblank.asm
extern g_player_marker_on                 ; src/ppu/ppu.asm
; EnterMap reset-ladder leaves (OW-A.4): ClearVariablesOnEnterMap (clear_variables.asm,
; linked); the rest are ret-stubs in overworld_stubs.asm until their subsystems land.
extern LoadPlayerSpriteGraphics        ; engine/overworld/player_gfx.asm (faithful pret dispatcher;
                                       ; the walking-only scaffold that lived here is retired)
; HandleBlackOut's closure (wild-live promotion)
extern hide_window           ; src/ppu/ppu.asm — empty the window list (count=0)
%define SET_PAL_OVERWORLD 9
; OW-A.2 P3b: the faithful home object-loader (InitSprites/LoadSprite, below) writes
; the per-slot movement-byte-2 + masked-text-id to wMapSpriteData and trainer
; class/num (or item) to wMapSpriteExtraData — both flat .bss globals in map_sprites.asm.
; pret wNumSprites (ram/wram.asm) — number of sprites on the current map. Read by
; src/home/text_script.asm; not in this file's include chain, so define it here
; (guarded; gb_memmap.inc carries the canonical copy at the same value).
%ifndef wNumSprites
wNumSprites equ 0xD4E0
%endif
extern InitToggleableObjectFlags          ; src/engine/overworld/map_sprites.asm
extern text_engine_init                   ; src/home/text.asm
                                    ; CF=1 + [hTextID]=sign id or sprite slot
; Hidden-event / bookshelf / card-key A-press dispatch (checked before signs/sprites).
extern DisplaySignText              ; src/home/overworld_text.asm — [hTextID] → ShowTextStream
extern LoadFontTilePatterns         ; src/home/load_font.asm
extern ReloadWalkingTilePatterns    ; src/engine/overworld/map_sprites.asm
; M7.4 home-rectify: faithful ExtraWarpCheck function-1/function-2 dispatch
%ifdef DEBUG_DUMP
%endif
%ifdef DEBUG_TRANSITION
%elifdef DEBUG_WALK_NORTH
%elifdef DEBUG_DIALOG
%elifdef DEBUG_SIGNTEXT
%endif
%ifdef DEBUG_PALLET_OAK
%endif
%ifdef DEBUG_MAPSCRIPT_SIGHT
%endif
%ifdef DEBUG_SEAM
%endif
%ifdef DEBUG_NOCLIP
%endif
%ifdef DEBUG_BAGMENU
%endif
; Deterministic player identity ("RED" / id 0 — the seed.lua golden spec). Needed by
; every gate whose golden compares the wPlayerName/wPlayerID WRAM regions, not just
; the start menu: without it wPlayerID is an RNG roll from InitPlayerData and is not
; reproducible between runs of the port itself (fidelity plan F-5).
%ifdef DEBUG_STARTMENU
%define NEED_SEED_IDENTITY
%endif
%ifdef DEBUG_TRANSITION
%define NEED_SEED_IDENTITY
%endif
%ifdef DEBUG_SIGNTEXT
%define NEED_SEED_IDENTITY
%endif
%ifdef DEBUG_PALLET_OAK
%define NEED_SEED_IDENTITY
%endif
%ifdef DEBUG_MAPSCRIPT_SIGHT
%define NEED_SEED_IDENTITY
%endif
%ifdef DEBUG_PREDEFTEXT
%define NEED_SEED_IDENTITY
%endif
%ifdef NEED_SEED_IDENTITY
%endif
; SeamReseatView: any harness that hand-seeds wYCoord/wXCoord must derive the view
; pointer itself (LoadMapData doesn't — that lives in LoadDestinationMapData).
%ifdef DEBUG_SEAM
%define NEED_SEAM_RESEAT
%endif
%ifdef DEBUG_SIGNTEXT
%define NEED_SEAM_RESEAT
%endif
%ifdef DEBUG_PALLET_OAK
%define NEED_SEAM_RESEAT
%endif
%ifdef DEBUG_MAPSCRIPT_SIGHT
%define NEED_SEAM_RESEAT
%endif
%ifdef DEBUG_SURF
%define NEED_SEAM_RESEAT
%endif
%ifdef DEBUG_LEDGE
%define NEED_SEAM_RESEAT
%endif
%ifdef DEBUG_FISH
%define NEED_SEAM_RESEAT
%endif
%ifdef DEBUG_PREDEFTEXT
%define NEED_SEAM_RESEAT
%endif
%ifdef DEBUG_BAGMENU_LIVE
%endif
%ifdef DEBUG_SEED_PARTY
%endif
%ifdef DEBUG_PARTYMENU
%endif
%ifdef DEBUG_TEXT
%endif
%ifdef DEBUG_ITEMTM
%endif
%ifdef DEBUG_ITEMSTONE
%endif
%ifdef DEBUG_BATTLE
%endif
%ifdef DEBUG_TEXTBOXID
%endif
%ifdef DEBUG_LISTMENU
%endif
%ifdef DEBUG_YESNO
%endif
%ifdef DEBUG_DRAWBADGES
%endif
%ifdef DEBUG_TRAINERCARD
%endif
%ifdef DEBUG_CINEMATIC_MARKERS
%endif
%ifdef DEBUG_OAKSPC
%endif
%ifdef DEBUG_PC
%endif
%ifdef DEBUG_LEAGUEPC
%endif
%ifdef DEBUG_OPTIONS
%endif
%ifdef DEBUG_PLAYERSPC
%endif
%ifdef DEBUG_MAINMENU
%endif
%ifdef DEBUG_CONTINUE_SEED
%endif
%ifdef DEBUG_OAKPIC
%endif
%ifdef DEBUG_OAKINTRO
%endif
%ifdef DEBUG_NAMEMENU
%endif
%ifdef DEBUG_OAKSLIDE
%endif
%ifdef DEBUG_CHOOSENAME
%endif
%ifdef DEBUG_CINEMATIC_SPLASH
%endif
%ifdef DEBUG_CINEMATIC_ANIMOBJ
%endif
%ifdef DEBUG_CINEMATIC_YELLOW
%endif
%ifdef DEBUG_SAVE
%endif
%ifdef DEBUG_NAMINGSCREEN
%endif
%ifdef DEBUG_G1
%endif
%ifdef DEBUG_G2
%endif
%ifdef DEBUG_I1
%endif
%ifdef DEBUG_I2
%endif
%ifdef DEBUG_LEARNMOVE
%endif
%ifdef DEBUG_STATUS
%endif
%ifdef DEBUG_WALKSPEED
extern tick_count                         ; boot/timing.asm
%endif

global EnterMapBoot
; (OW-A.5: dead `global CopyMapViewToVRAM` removed — routine obsoleted by native
;  render_bg; had no body, exported an undefined symbol. See its note ~L1729.)
; IsSpriteOrSignInFrontOfPlayer (complete: sign + counter + sprite scan) and
; IsSpriteInFrontOfPlayer / IsSpriteInFrontOfPlayer2 moved to their pret mirror,
; src/home/overworld.asm (menu-intro review + R-002 retirement, 2026-07-23).
global CheckWarpTile
global LoadDestinationMapData
; LoadPlayerSpriteGraphics moved to engine/overworld/player_gfx.asm (wild-live
; promotion) — the scaffold here is retired; player_sprite is exported to it.
global player_sprite                       ; pret RedSprite; consumed by player_gfx.asm
global RefreshCollisionTileMap             ; menus S4: home/start_menu.asm restores

; --- moved to src/home/overworld.asm (pret home/overworld.asm mirror) ---
extern EnterMap                           ; src/home/overworld.asm
extern LoadCurrentMapView                 ; src/home/overworld.asm
extern LoadDestinationWarpPosition        ; src/home/overworld.asm
extern LoadMapHeader                      ; src/home/overworld.asm
extern LoadTileBlockMap                   ; src/home/overworld.asm
extern LoadTilesetTilePatternData         ; src/home/overworld.asm

; --- consumed by the relocated pret home/overworld.asm routines ---
global ApplyMapBorderOverrides
global h_load_sprite_temp1
global h_load_sprite_temp2
                                           ; the W_TILEMAP mirror around the menu

; ---------------------------------------------------------------------------
; Map and tileset constants
; ---------------------------------------------------------------------------
MAP_ID_PALLET_TOWN          equ 0x00
TILESET_OVERWORLD           equ 0x00
; tileset ids (constants/tileset_constants.asm; not in gb_memmap.inc) — PlayMapChangeSound
; wStatusFlags6 bit 5 (constants/ram_constants.asm). Its siblings (BIT_FLY_WARP,
; BIT_DUNGEON_WARP, BIT_ESCAPE_WARP, …) come from gb_memmap.inc, but this one only
; exists in gb_constants.inc, which this file does not include — and the two headers
; must not both define it (bare `equ` redefinition is a NASM error in any file that
; includes both). Local def, same as player_gfx.asm / special_warps.asm do for theirs.
PALLET_TOWN_WIDTH           equ 10
PALLET_TOWN_HEIGHT          equ 9
PALLET_TOWN_BORDER_BLOCK    equ 0x0B   ; border block from PalletTown_Object
TILESET_BANK_FLAT           equ 0x01   ; ignored in flat model (TODO-HW: ROM banking)

; wCurrentTileBlockMapViewPointer for the Pallet Town spawn (wXCoord/wYCoord = 8,8;
; see EnterMap). Same derivation LoadDestinationMapData uses, specialized to that coord:
;   stride   = PALLET_TOWN_WIDTH + 2*MAP_BORDER
;   view_row = (8>>1) + MAP_BORDER - SCREEN_BLOCK_HEIGHT/2 = 4 + MAP_BORDER - 4 = MAP_BORDER
;   view_col = (8>>1) + MAP_BORDER - SCREEN_BLOCK_WIDTH/2  = 4 + MAP_BORDER - 6 = MAP_BORDER - 2
; The `MAP_BORDER` / `MAP_BORDER - 2` terms are the reduced forms of those two
; expressions, not border literals — they track MAP_BORDER correctly.
PALLET_TOWN_VIEW_PTR        equ W_OVERWORLD_MAP + (MAP_BORDER) * (PALLET_TOWN_WIDTH + MAP_BORDER * 2) + (MAP_BORDER - 2)

; Number of connections in the Block/Connect strips (0xFF = none — disables strip loading)

; Pallet Town map connections (computed from the pret `connection` macro for the
; north=Route1 / south=Route21 connections, both at offset 0). See
; macros/scripts/maps.asm:connection. Route1 = 10×18, Route21 = 10×45.
MAP_ID_ROUTE_1              equ 0x0C
MAP_ID_ROUTE_21             equ 0x20

; The Pallet Town north(Route1)/south(Route21) strip + view-pointer equs that
; used to live here are GONE. They were hand-computed for MAP_BORDER = 6 (e.g.
; `NORTH_STRIP_DEST equ W_OVERWORLD_MAP + 6`, `_win = (w+12)*h + 1`) and had been
; dead since LoadMapHeader started reading the connection headers that
; tools/generators/gen_map_headers.py emits into assets/map_headers.inc — which is the one
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
    ; EnterMap now lives in its pret mirror src/home/overworld.asm, so the
    ; original fallthrough becomes an explicit tail jump (same semantics,
    ; same stack depth -- EnterMap never returns to EnterMapBoot).
    jmp EnterMap
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
; RefreshCollisionTileMap — copy the current sub-block window of wSurroundingTiles
; into wTileMap (the collision / text tile grid).
;
; wTileMap is what NPC collision (GetTileSpriteStandsOn → IsTilePassable) and the
; player collision read. wSurroundingTiles is the block-decoded render source.
; The window into it is offset by the player's sub-block coords (xBlock/yBlock):
; each is 0 or 1, shifting the 40×25 window by 0 or 2 tiles.
;
; FIXED(walking-NPC wall-clip): the sub-block coords change every step, but the
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

%ifdef DEBUG_SEAM
section .data
seam_seeded: db 0        ; EnterMap is re-entered per map transition; seed once
seam_reseat: db 0        ; derive the view ptr only for the hand-seeded spawn
section .text
%endif

%ifdef NEED_SEAM_RESEAT
; ---------------------------------------------------------------------------
; SeamReseatView — DEBUG harnesses only (DEBUG_SEAM, DEBUG_SIGNTEXT). Port-only
; debug helper, no pret counterpart.
; LoadMapData loads the header + block map but does NOT derive the view pointer
; (that lives in LoadDestinationMapData). A harness that spawns on an arbitrary map
; must therefore recompute it from the seeded coordinates, using the same formula
; LoadDestinationMapData does, and re-run LoadCurrentMapView to repaint the surface.
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
    ; Seed BIT_STANDING_ON_WARP exactly as LoadDestinationMapData does, or a spawn
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

; (IsSpriteOrSignInFrontOfPlayer moved to its pret mirror, src/home/overworld.asm
;  — R-002 retirement 2026-07-23, now COMPLETE: sign branch + counter-tile
;  talking-range extension + fallthrough into the sprite scan, under pret's
;  CF/[hTextID] contract. The sign-branch-only version that lived here, with
;  its inline front-coord computation and AL=1/0 return, is retired; the
;  mirror routine uses GetTileAndCoordsInFrontOfPlayer as pret does.)

; ---------------------------------------------------------------------------
; DoSignInteraction — display the sign text IsSpriteOrSignInFrontOfPlayer resolved
; into [hTextID].
;
; DEVIATION{class=temporary; pret=home/overworld.asm:IsSpriteOrSignInFrontOfPlayer; behavior=port-only DoSignInteraction supplies font and player-state framing before DisplaySignText; evidence=sign_pallet golden-matches through the A-press sign path while DisplayTextID now owns the map-text service dispatcher; lifetime=until the sign interaction path is folded through DisplayTextID}
; pret has no counterpart for this glue. pret reaches the sign text
; through DisplayTextID, which sets up the font/player state itself. The port's
; overworld does not use DisplayTextID on the NPC path either — CheckNPCInteraction
; is its equivalent, and it both detects and displays — so DisplaySignText
; (overworld_text.asm) is written to the same contract: it expects its CALLER to have
; loaded the font and frozen the player, "exactly as CheckNPCInteraction does" (the
; integration note in hidden_events.asm). This routine is that caller. It mirrors the
; NPC path's framing rather than DisplayTextID's, so both overworld text paths enter
; and leave the dialog identically. Retires when signs are routed through DisplayTextID.
; ---------------------------------------------------------------------------
DoSignInteraction:
    pushad
    ; Font tiles time-share vChars1 with the player/NPC walk tiles, so the walking
    ; player must be forced to a STANDING pose before the font load or its frozen
    ; walk-tile index renders font glyphs as the player — the same trap, and the same
    ; fix, as CheckNPCInteraction (map_sprites.asm).
    mov al, [ebp + W_SPRITE_PLAYER_FACING_DIR]
    mov [ebp + W_SPRITE_PLAYER_IMAGE_INDEX], al
    mov byte [ebp + W_SPRITE_PLAYER_ANIM_FRAME], 0
    mov byte [ebp + W_SPRITE_PLAYER_INTRA_ANIM], 0

    or byte [ebp + W_FONT_LOADED], (1 << BIT_FONT_LOADED)  ; freezes NPC movement too
    call LoadFontTilePatterns
    call DisplaySignText                 ; reads [hTextID]; runs ShowTextStream

    call hide_window
    and byte [ebp + W_FONT_LOADED], ~(1 << BIT_FONT_LOADED)
    call ReloadWalkingTilePatterns       ; font clobbered the walk tiles — restore
    call LoadPlayerSpriteGraphics
    call LoadCurrentMapView              ; rebuild the BG the text box covered
    call DelayFrame
    popad
    ret

; ---------------------------------------------------------------------------
; GetTileInFrontOfPlayer (port-only fork) was DELETED 2026-07-27.
;
; It duplicated pret's _GetTileAndCoordsInFrontOfPlayer byte-for-byte in its tile
; read -- same four W_TILEMAP offset expressions, same W_TILE_IN_FRONT_OF_PLAYER
; store -- differing only by omitting the DH/DL front-coord outputs. That faithful
; routine is translated and linked at src/engine/overworld/player_state.asm, so two
; copies of one facing->offset table were live and could silently diverge.
; Both former callers (src/home/overworld.asm CollisionCheckOnLand and the surf
; collision path) now call _GetTileAndCoordsInFrontOfPlayer directly.
; ---------------------------------------------------------------------------

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
; LoadDestinationMapData — load the destination map after a warp transition.
;
; PORT-ONLY orchestrator: no pret counterpart. Renamed from LoadWarpDestination on
; 2026-07-27 because that name shadowed pret's real, unrelated, and separately
; translated home/overworld.asm:LoadDestinationWarpPosition (which copies a 4-byte
; warp-position record into wCurrentTileBlockMapViewPointer). The two do entirely
; different jobs, and the near-identical names made greps and call-graph reading
; ambiguous.
;
; DEVIATION{class=banking; pret=home/overworld.asm:LoadMapData; behavior=one port routine performs the destination map header load, indoor .blk staging into a shared EBP window, tileset pattern load and view-pointer derivation that pret spreads across LoadMapData plus its bank-switched callees; evidence=the port has no ROM banking so pret's per-bank load sequence has no counterpart and indoor maps must share INDOOR_BLK_GBADDR rather than living at distinct bank addresses; lifetime=permanent, the flat memory model is by design}
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
LoadDestinationMapData:
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

section .rodata

; MapSongBanks (pret data/maps/songs.asm) used to be %included HERE. Moved
; 2026-08-02 to src/data/maps/map_songs.asm to clear its [aux_misplaced]
; finding — a pret data/ label belongs in the data layer. It was separable
; because map_songs.inc defines only that table, carries no `equ`, and
; references nothing else. Bytes unchanged.
extern MapSongBanks                       ; src/data/maps/map_songs.asm

; authored border-ring blocks (map-tool C3; see ApplyMapBorderOverrides)
%include "assets/map_border_overrides.inc"
global overworld_gfx                     ; exported for cut.asm (InitCutAnimOAM tree tiles $2d/$3d)

%include "assets/overworld_gfx.inc"
global OVERWORLD_BLOCKS_SIZE             ; DrawTileBlock block-ID clamp (relocated)
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
; *** MapHeaderPointers is a pret data/maps/map_header_pointers.asm table and
; *** `lint_pret_labels` reports it as [aux_misplaced]. It could NOT be moved to
; *** the data layer in the 2026-08-02 sweep that moved MapSongBanks out, and the
; *** reason is structural, not effort:
;   1. assets/map_headers.inc also defines TilesetGfxPtrs/GfxSizes/BlocksPtrs/
;      BlocksSizes/CollPtrs, whose rows point at reds_house_gfx, pokecenter_gfx,
;      forest_gfx ... — labels defined by assets/extra_includes.inc and NOT global.
;      Splitting the table from those blobs breaks the link.
;   2. extra_includes.inc's blobs are in turn welded to the CODE in this file:
;      it consumes size `equ`s (OVERWORLD_BLOCKS_SIZE and friends) as assembly-time
;      immediates, and a NASM `equ` cannot cross an object file. This is the same
;      constraint already documented for the pokedex tile blob, which had to travel
;      with its routine for exactly this reason.
; Clearing this finding therefore needs a real refactor — either publish the blob
; sizes as linkable data words and change the consuming code to load them, or move
; the whole asset region and its consumers together. That is a scoped piece of work,
; NOT a suppression, and it is deliberately left open rather than waived.
global MapHeaderPointers                  ; LoadMapHeader (relocated to src/home/overworld.asm)
; per-tileset gfx/blockset/collision pointer + size tables, also from
; assets/map_headers.inc — read by LoadTilesetHeader, which lives in its own pret
; mirror (src/engine/overworld/tilesets.asm). This file owns the generated blob,
; so it exports the four-plus-one symbols rather than the mirror re-%including it.
global TilesetGfxPtrs
global TilesetGfxSizes
global TilesetBlocksPtrs
global TilesetBlocksSizes
global TilesetCollPtrs

; --- consumed by the relocated pret home/overworld.asm routines ---
global DoSignInteraction
global SeamReseatView
global WalkSpeedSample
global seam_reseat
global seam_seeded
%include "assets/map_headers.inc"
%include "assets/extra_includes.inc"

