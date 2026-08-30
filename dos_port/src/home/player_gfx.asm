; ===========================================================================
; player_gfx.asm — alternate player sprite-graphics DATA
;
; CORRECTED 2026-08-15 (S6 remediation slice): this file previously carried
; ~150 lines of routine headers (LoadPlayerSpriteGraphics,
; LoadWalkingPlayerSpriteGraphics, LoadSurfingPlayerSpriteGraphics2,
; LoadSurfingPlayerSpriteGraphics, LoadBikePlayerSpriteGraphics,
; LoadPlayerSpriteGraphicsCommon, IsBikeRidingAllowed, ForceBikeOrSurf,
; StopBikeSurf, DoBikeSpeedup) with NO bodies underneath them, plus a block of
; %ifndef placeholder constants (ROUTE_17/OVERWORLD/FOREST/UNDERGROUND/
; SHIP_PORT/CAVERN/…) and five `extern`s (g_tilecache_dirty,
; AdvancePlayerSprite, PlayDefaultMusic, player_sprite, BikeRidingTilesets).
; Every one of those routines, constants and externs is DEAD in this file:
; `dos_port/tools/label_status --callers` confirms all ten routine labels are
; `global`-defined and live in `dos_port/src/home/overworld.asm` (pret's
; home/overworld.asm — the faithful mirror), and a grep of this file for each
; placeholder constant / extern found zero uses outside their own declaration
; comments. This is not a fork or a divergence — it is stale documentation
; left behind after the routines it once held were moved to their mirror; the
; header claiming "Intended path: dos_port/src/engine/overworld/player_gfx.asm"
; was itself part of that same stale aspiration and is removed too (gfx/ pret
; data is exempt from the path-mirror rule — see faithfulness-review skill,
; "Unmodeled pret dirs" — so there was never a placement requirement here).
;
; What this file ACTUALLY is, and all it needs to be: the port-only host for
; three generated pret gfx/sprites.asm data tables consumed by
; LoadPlayerSpriteGraphicsCommon in home/overworld.asm. No code, no pret
; routine counterpart of its own.
;
; Pret refs for the loader/dispatcher family (read them in
; dos_port/src/home/overworld.asm, not here):
;   home/overworld.asm: LoadPlayerSpriteGraphics, IsBikeRidingAllowed,
;   StopBikeSurf, ForceBikeOrSurf, LoadWalkingPlayerSpriteGraphics,
;   LoadSurfingPlayerSpriteGraphics2, LoadSurfingPlayerSpriteGraphics,
;   LoadBikePlayerSpriteGraphics, LoadPlayerSpriteGraphicsCommon.
;   DoBikeSpeedup also lives there (OW-A.6), called from OverworldLoop.
;
; VRAM layout the three tables below assume (unchanged from pret):
;   tiles 0-11  (standing/turn poses) → OBJ tiles $00-$0B at GB_VCHARS0 ($8000)
;   tiles 12-23 (walking poses)       → OBJ tiles $80-$8B at GB_VFONT   ($8800)
; The walking tiles time-share vChars1 with the text font, exactly as on the GB.
; ===========================================================================

; ---------------------------------------------------------------------------
; Alternate player sprite sheets — pret gfx/sprites.asm:35,74,87
; (RedBikeSprite / SeelSprite / SurfingPikachuSprite). Tier-1 generated data:
; assets/<stem>_sprite.inc, emitted by tools/generators/gen_all_assets.py from
; gfx/sprites/<stem>.2bpp. Each is a 384-byte, 24-tile sheet laid out exactly
; like player_sprite (12 standing tiles + 12 walking tiles), which is what
; LoadPlayerSpriteGraphicsCommon in home/overworld.asm's two 192-byte copies
; assume.
; D.4: player_sprite (pret RedSprite, the walking set) now also lives here
; instead of src/engine/overworld/overworld.asm; it is consumed the same way
; by LoadPlayerSpriteGraphicsCommon (home/overworld.asm) and by
; player_animations.asm's SetupPlayerAnimation.
;
; NOTE: assets/mon_icons.inc (consumed by src/engine/gfx/mon_icons.asm) also
; defines a non-`global` label literally named `SeelSprite` for the unrelated
; party-icon tile data — a same-name coincidence (both are "Seel" tile art),
; not a symbol collision, since that label is never exported. Flagged for the
; root; no action needed here.
; ---------------------------------------------------------------------------
; The explicit section directive is LOAD-BEARING: NASM 3.02's COFF backend
; emits a `global` label as an UNDEFINED external if it is defined in the
; implicit default section (measured 2026-08-15 — dropping this line made all
; three symbols vanish at link time with the data still present in the object).
section .data

global player_sprite
%include "assets/player_sprite.inc"

section .text

global RedBikeSprite
global SeelSprite
global SurfingPikachuSprite
%include "assets/red_bike_sprite.inc"
%include "assets/seel_sprite.inc"
%include "assets/surfing_pikachu_sprite.inc"
