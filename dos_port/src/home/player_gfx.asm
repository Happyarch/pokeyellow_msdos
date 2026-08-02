; ===========================================================================
; player_gfx.asm — player-graphics variants + bike/surf state
; Intended path: dos_port/src/engine/overworld/player_gfx.asm
;
; Wave 7 / M7.5 (home-rectification swarm). Faithful translation of the pret
; player sprite-graphics loader family and the bike/surf helpers, which the
; port previously only stubbed (a single walking-only LoadPlayerSpriteGraphics
; scaffold in overworld.asm).
;
; Pret refs:
;   home/overworld.asm
;     LoadPlayerSpriteGraphics::            (dispatcher, ~L793)
;     IsBikeRidingAllowed::                 (~L804)  + data/tilesets/bike_riding_tilesets.asm
;     StopBikeSurf:                         (~L781)
;     DoBikeSpeedup::                       RETIRED → overworld.asm (OW-A.6)
;     ForceBikeOrSurf::                     (~L2115)
;     LoadWalkingPlayerSpriteGraphics::     (~L1743)
;     LoadSurfingPlayerSpriteGraphics2::    (~L1751)
;     LoadSurfingPlayerSpriteGraphics::     (~L1768)
;     LoadBikePlayerSpriteGraphics::        (~L1773)
;     LoadPlayerSpriteGraphicsCommon::      (~L1777)
;
; Register map (CLAUDE.md): A→AL, HL→ESI, BC→BX (B=BH,C=BL), DE→DX; GB mem =
; [ebp + SYM] (gb_memmap.inc). Bank switching is a no-op in the flat model.
;
; VRAM layout (unchanged from the walking-only scaffold, and matching the GB):
;   tiles 0-11  (standing/turn poses) → OBJ tiles $00-$0B at GB_VCHARS0 ($8000)
;   tiles 12-23 (walking poses)       → OBJ tiles $80-$8B at GB_VFONT   ($8800)
; The walking tiles time-share vChars1 with the text font, exactly as on the GB.
; ===========================================================================

%include "gb_memmap.inc"
%include "gb_macros.inc"

; ---------------------------------------------------------------------------
; Constants not yet in the shared memmap — local %ifndef placeholders with the
; canonical pret values. (Root: promote to gb_memmap.inc / gb_constants.inc.)
; ---------------------------------------------------------------------------

; Map ids — constants/map_constants.asm
%ifndef INDIGO_PLATEAU
%endif
%ifndef ROUTE_17
ROUTE_17                   equ 0x1C   ; Cycling Road
%endif
%ifndef ROUTE_23
%endif

; Tileset ids — constants/tileset_constants.asm (for BikeRidingTilesets)
%ifndef OVERWORLD
OVERWORLD                  equ 0
%endif
%ifndef FOREST
FOREST                     equ 3
%endif
%ifndef UNDERGROUND
UNDERGROUND                equ 11
%endif
%ifndef SHIP_PORT
SHIP_PORT                  equ 14
%endif
%ifndef CAVERN
CAVERN                     equ 17
%endif

; wStatusFlags6 bit — constants/ram_constants.asm
%ifndef BIT_DUNGEON_WARP
%endif

; wPikachuSpawnStateFlags bit — constants/pikachu_emotion_constants.asm
%ifndef BIT_PIKACHU_SPAWN_SURFING
%endif

; WRAM addresses absent from the port memmap (pret ram/wram.asm).
;   wPikachuSpawnStateFlags and wd472 are adjacent; the "wd472" label is the
;   literal address $D472, so wPikachuSpawnStateFlags = $D471.
%ifndef W_PIKACHU_SPAWN_STATE_FLAGS
%endif
%ifndef W_D472
%endif
; (The old W_NPC_MOVEMENT_SCRIPT_POINTER_TABLE_NUM 0xCF17 placeholder is gone —
; its only consumer, DoBikeSpeedup, was retired to overworld.asm; the golden
; wNPCMovementScriptPointerTableNum 0xCC57 lives in gb_memmap.inc.)

; ---------------------------------------------------------------------------
; Externs
; ---------------------------------------------------------------------------
extern g_tilecache_dirty            ; src/ppu/ppu.asm — arm tile-cache re-decode
extern AdvancePlayerSprite          ; src/home/overworld.asm
extern PlayDefaultMusic             ; src/home/audio.asm (real gateway)

; Player sprite tile data. player_sprite is the port's existing walking (Red)
; sprite set (assets/player_sprite.inc), i.e. pret RedSprite; it is defined in
; engine/overworld/overworld.asm and exported from there.
extern player_sprite                ; == RedSprite (walking)
; RedBikeSprite / SeelSprite / SurfingPikachuSprite are generated Tier-1 data,
; defined at the bottom of this file from assets/*_sprite.inc (gen_all_assets.py).

; ---------------------------------------------------------------------------
; Globals
; ---------------------------------------------------------------------------
; DoBikeSpeedup RETIRED → overworld.asm (OW-A.6; see note at its old body site)


; called by the routines that moved to src/home/overworld.asm
section .text

; ---------------------------------------------------------------------------
; LoadPlayerSpriteGraphics — dispatcher.
; Pret ref: home/overworld.asm:LoadPlayerSpriteGraphics
; Loads standing/biking/surfing tiles based on wWalkBikeSurfState
; (0=standing, 1=biking, 2=surfing). If biking is not currently allowed the
; state is reset to standing first.
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; LoadWalkingPlayerSpriteGraphics
; Pret ref: home/overworld.asm:LoadWalkingPlayerSpriteGraphics
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; LoadSurfingPlayerSpriteGraphics2
; Pret ref: home/overworld.asm:LoadSurfingPlayerSpriteGraphics2
; Picks Surfing-Pikachu vs. Seel graphics from wd472 / the Pikachu-spawn flag.
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; LoadSurfingPlayerSpriteGraphics — Seel (surf without following Pikachu).
; Pret ref: home/overworld.asm:LoadSurfingPlayerSpriteGraphics
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; LoadBikePlayerSpriteGraphics — falls through to Common.
; Pret ref: home/overworld.asm:LoadBikePlayerSpriteGraphics
; ---------------------------------------------------------------------------
    ; fall through

; ---------------------------------------------------------------------------
; LoadPlayerSpriteGraphicsCommon
; Pret ref: home/overworld.asm:LoadPlayerSpriteGraphicsCommon
; In:  ESI = source tile data (pret DE); bank (pret B) ignored in flat model.
; Copies 12 tiles (192 B) → vNPCSprites ($8000), then the next 12 tiles → $8800
; (vChars1, +$800). Pret does this with two CopyVideoData calls; here two
; rep movsb runs (CopyVideoData does not exist in the port). ESI advances by
; 192 across the first copy exactly as pret advances DE by $C0.
; Clobbers: ESI, EDI, ECX, AL (faithful: GB clobbers HL/DE/BC/A).
; ---------------------------------------------------------------------------
    ; NOTE (faithfulness): pret Common does NOT clear OAM. The old overworld.asm
    ; scaffold appended `call ClearSprites`; that is intentionally omitted here.
    ; If a caller relied on it, hoist the ClearSprites into the caller instead.

; ---------------------------------------------------------------------------
; IsBikeRidingAllowed — returns CF=1 if biking is allowed here.
; Pret ref: home/overworld.asm:IsBikeRidingAllowed
; Allowed on Route 23 / Indigo Plateau, or when the current tileset is one of
; BikeRidingTilesets. Hand loop (pret does not use IsInArray here).
; Clobbers: AL, BH, ESI.
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; ForceBikeOrSurf — force the current bike/surf graphics + music.
; Pret ref: home/overworld.asm:ForceBikeOrSurf
; Pret bank-switches to (bank-0) LoadPlayerSpriteGraphics then jumps to
; PlayDefaultMusic. Bank switch is a no-op in the flat model.
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; DoBikeSpeedup — RETIRED from this file (OW-A.6). The routine now links LIVE
; in src/engine/overworld/overworld.asm (its faithful pret home/overworld.asm
; location, called from OverworldLoop's .moveAhead), using the golden
; wNPCMovementScriptPointerTableNum (0xCC57) instead of this file's old 0xCF17
; placeholder guess. Nothing in this file called it.
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; StopBikeSurf — revert to walking; restore music if leaving a dungeon warp.
; Pret ref: home/overworld.asm:StopBikeSurf
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; BikeRidingTilesets — data/tilesets/bike_riding_tilesets.asm. pret embeds it
; right after IsBikeRidingAllowed, and the port did the same until 2026-08-02,
; when lint_pret_labels' [aux_misplaced] rule was cleared: a pret data/ label
; must live in the data layer. It is now generated into assets/tileset_tables.inc
; by tools/generators/gen_static_tables.py and hosted by src/data/tileset_data.asm.
; Bytes unchanged.
; ---------------------------------------------------------------------------
extern BikeRidingTilesets               ; src/data/tileset_data.asm

; ---------------------------------------------------------------------------
; Alternate player sprite sheets — pret gfx/sprites.asm:35,74,87
; (RedBikeSprite / SeelSprite / SurfingPikachuSprite). Tier-1 generated data:
; assets/<stem>_sprite.inc, emitted by tools/generators/gen_all_assets.py from
; gfx/sprites/<stem>.2bpp. Each is a 384-byte, 24-tile sheet laid out exactly
; like player_sprite (12 standing tiles + 12 walking tiles), which is what
; LoadPlayerSpriteGraphicsCommon's two 192-byte copies assume.
; ---------------------------------------------------------------------------
global RedBikeSprite
global SeelSprite
global SurfingPikachuSprite
%include "assets/red_bike_sprite.inc"
%include "assets/seel_sprite.inc"
%include "assets/surfing_pikachu_sprite.inc"
