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
;     DoBikeSpeedup::                       (~L339)
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
INDIGO_PLATEAU              equ 0x09
%endif
%ifndef ROUTE_17
ROUTE_17                   equ 0x1C   ; Cycling Road
%endif
%ifndef ROUTE_23
ROUTE_23                   equ 0x22
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
BIT_DUNGEON_WARP           equ 4
%endif

; wPikachuSpawnStateFlags bit — constants/pikachu_emotion_constants.asm
%ifndef BIT_PIKACHU_SPAWN_SURFING
BIT_PIKACHU_SPAWN_SURFING  equ 6
%endif

; WRAM addresses absent from the port memmap (pret ram/wram.asm).
;   wPikachuSpawnStateFlags and wd472 are adjacent; the "wd472" label is the
;   literal address $D472, so wPikachuSpawnStateFlags = $D471.
%ifndef W_PIKACHU_SPAWN_STATE_FLAGS
W_PIKACHU_SPAWN_STATE_FLAGS equ 0xD471
%endif
%ifndef W_D472
W_D472                      equ 0xD472
%endif
; wNPCMovementScriptPointerTableNum — scripted-NPC-movement dispatch (deferred
; in the port). Address UNVERIFIED against the port's chosen CFxx layout; used
; only as a "0 == no script running" guard in DoBikeSpeedup.
%ifndef W_NPC_MOVEMENT_SCRIPT_POINTER_TABLE_NUM
W_NPC_MOVEMENT_SCRIPT_POINTER_TABLE_NUM equ 0xCF17
%endif

; ---------------------------------------------------------------------------
; Externs
; ---------------------------------------------------------------------------
extern g_tilecache_dirty            ; src/ppu/ppu.asm — arm tile-cache re-decode
extern AdvancePlayerSprite          ; src/engine/overworld/overworld.asm

; Player sprite tile data. player_sprite is the port's existing walking (Red)
; sprite set (assets/player_sprite.inc), i.e. pret RedSprite.
extern player_sprite                ; == RedSprite (walking)
; MISSING port assets (bike/surf) — extern'd so the file assembles; a LINK build
; needs these generated (see SUMMARY):
extern RedBikeSprite                ; bike
extern SeelSprite                   ; surfing (no Pikachu following)
extern SurfingPikachuSprite         ; surfing with Pikachu

; ---------------------------------------------------------------------------
; Globals
; ---------------------------------------------------------------------------
global LoadPlayerSpriteGraphics
global LoadWalkingPlayerSpriteGraphics
global LoadSurfingPlayerSpriteGraphics2
global LoadSurfingPlayerSpriteGraphics
global LoadBikePlayerSpriteGraphics
global LoadPlayerSpriteGraphicsCommon
global IsBikeRidingAllowed
global ForceBikeOrSurf
global DoBikeSpeedup
global StopBikeSurf

PLAYER_HALF_TILES equ 12                       ; 12 tiles per VRAM half
PLAYER_HALF_BYTES equ PLAYER_HALF_TILES * TILE_SIZE   ; 192 bytes ($C0)

section .text

; ---------------------------------------------------------------------------
; LoadPlayerSpriteGraphics — dispatcher.
; Pret ref: home/overworld.asm:LoadPlayerSpriteGraphics
; Loads standing/biking/surfing tiles based on wWalkBikeSurfState
; (0=standing, 1=biking, 2=surfing). If biking is not currently allowed the
; state is reset to standing first.
; ---------------------------------------------------------------------------
LoadPlayerSpriteGraphics:
    mov al, [ebp + W_WALK_BIKE_SURF_STATE]
    dec al
    jz .ridingBike                          ; state == 1

    ; standing (or surfing): honor hTileAnimations gate as pret does
    mov al, [ebp + H_TILE_ANIMATIONS]
    test al, al
    jnz .determineGraphics
    jmp .startWalking

.ridingBike:
    ; If the bike can't be used here, start walking instead.
    call IsBikeRidingAllowed                ; CF = biking allowed
    jc .determineGraphics

.startWalking:
    xor al, al
    mov [ebp + W_WALK_BIKE_SURF_STATE],      al
    mov [ebp + W_WALK_BIKE_SURF_STATE_COPY], al
    jmp LoadWalkingPlayerSpriteGraphics

.determineGraphics:
    mov al, [ebp + W_WALK_BIKE_SURF_STATE]
    test al, al
    jz LoadWalkingPlayerSpriteGraphics       ; 0 → walking
    dec al
    jz LoadBikePlayerSpriteGraphics          ; 1 → biking
    dec al
    jz LoadSurfingPlayerSpriteGraphics2      ; 2 → surfing
    jmp LoadWalkingPlayerSpriteGraphics      ; fallback

; ---------------------------------------------------------------------------
; LoadWalkingPlayerSpriteGraphics
; Pret ref: home/overworld.asm:LoadWalkingPlayerSpriteGraphics
; ---------------------------------------------------------------------------
LoadWalkingPlayerSpriteGraphics:
    mov byte [ebp + W_D472], 0
    mov esi, player_sprite                  ; RedSprite (walking) — DE in pret
    jmp LoadPlayerSpriteGraphicsCommon

; ---------------------------------------------------------------------------
; LoadSurfingPlayerSpriteGraphics2
; Pret ref: home/overworld.asm:LoadSurfingPlayerSpriteGraphics2
; Picks Surfing-Pikachu vs. Seel graphics from wd472 / the Pikachu-spawn flag.
; ---------------------------------------------------------------------------
LoadSurfingPlayerSpriteGraphics2:
    mov al, [ebp + W_D472]
    test al, al
    jz .checkPikachu                        ; d472 == 0
    dec al
    jz LoadSurfingPlayerSpriteGraphics      ; d472 == 1
    dec al
    jz .surfPikachu                         ; d472 == 2
.checkPikachu:
    test byte [ebp + W_PIKACHU_SPAWN_STATE_FLAGS], (1 << BIT_PIKACHU_SPAWN_SURFING)
    jz LoadSurfingPlayerSpriteGraphics
.surfPikachu:
    mov esi, SurfingPikachuSprite
    jmp LoadPlayerSpriteGraphicsCommon

; ---------------------------------------------------------------------------
; LoadSurfingPlayerSpriteGraphics — Seel (surf without following Pikachu).
; Pret ref: home/overworld.asm:LoadSurfingPlayerSpriteGraphics
; ---------------------------------------------------------------------------
LoadSurfingPlayerSpriteGraphics:
    mov esi, SeelSprite
    jmp LoadPlayerSpriteGraphicsCommon

; ---------------------------------------------------------------------------
; LoadBikePlayerSpriteGraphics — falls through to Common.
; Pret ref: home/overworld.asm:LoadBikePlayerSpriteGraphics
; ---------------------------------------------------------------------------
LoadBikePlayerSpriteGraphics:
    mov esi, RedBikeSprite
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
LoadPlayerSpriteGraphicsCommon:
    mov byte [g_tilecache_dirty], 1         ; VRAM tile data changes → re-decode cache

    ; standing tiles (0-11) → OBJ $00-$0B at $8000 (vNPCSprites)
    lea edi, [ebp + GB_VCHARS0]
    mov ecx, PLAYER_HALF_BYTES
    rep movsb

    ; walking tiles (12-23) → OBJ $80-$8B at $8800 (vChars1; shares vFont)
    ; ESI is already at source+$C0 after the first copy (pret: add e,$C0).
    lea edi, [ebp + GB_VFONT]
    mov ecx, PLAYER_HALF_BYTES
    rep movsb
    ret
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
IsBikeRidingAllowed:
    mov al, [ebp + W_CUR_MAP]
    cmp al, ROUTE_23
    je .allowed
    cmp al, INDIGO_PLATEAU
    je .allowed

    mov bh, [ebp + W_CUR_MAP_TILESET]       ; B = BH
    mov esi, BikeRidingTilesets             ; HL → table
.loop:
    mov al, [esi]                           ; ld a,[hli]
    inc esi
    cmp al, bh
    je .allowed
    inc al                                  ; $FF terminator → 0 (ZF)
    jnz .loop
    clc                                     ; pret: `and a` → CF=0 (not allowed)
    ret
.allowed:
    stc
    ret

; ---------------------------------------------------------------------------
; ForceBikeOrSurf — force the current bike/surf graphics + music.
; Pret ref: home/overworld.asm:ForceBikeOrSurf
; Pret bank-switches to (bank-0) LoadPlayerSpriteGraphics then jumps to
; PlayDefaultMusic. Bank switch is a no-op in the flat model.
; ---------------------------------------------------------------------------
ForceBikeOrSurf:
    call LoadPlayerSpriteGraphics
    ; TODO-HW: audio (Phase 3) — pret: jp PlayDefaultMusic
    ret

; ---------------------------------------------------------------------------
; DoBikeSpeedup — bikes move twice as fast (extra AdvancePlayerSprite step).
; Pret ref: home/overworld.asm:DoBikeSpeedup
; No-op unless biking, not on a ledge/fishing, and no NPC movement script is
; running. On Cycling Road (Route 17) the free step is suppressed while a
; horizontal/up direction is held.
; ---------------------------------------------------------------------------
DoBikeSpeedup:
    mov al, [ebp + W_WALK_BIKE_SURF_STATE]
    dec al                                  ; riding a bike?
    jnz .done                               ; ret nz

    test byte [ebp + W_MOVEMENT_FLAGS], (1 << BIT_LEDGE_OR_FISHING)
    jnz .done                               ; ret nz

    cmp byte [ebp + W_NPC_MOVEMENT_SCRIPT_POINTER_TABLE_NUM], 0
    jne .done                               ; ret nz (script running)

    mov al, [ebp + W_CUR_MAP]
    cmp al, ROUTE_17                         ; Cycling Road
    jne .goFaster
    mov al, [ebp + H_JOY_HELD]
    test al, (PAD_UP | PAD_LEFT | PAD_RIGHT)
    jnz .done                               ; ret nz
.goFaster:
    call AdvancePlayerSprite
.done:
    ret

; ---------------------------------------------------------------------------
; StopBikeSurf — revert to walking; restore music if leaving a dungeon warp.
; Pret ref: home/overworld.asm:StopBikeSurf
; ---------------------------------------------------------------------------
StopBikeSurf:
    mov al, [ebp + W_WALK_BIKE_SURF_STATE]
    test al, al
    jz .done                                ; ret z (already walking)
    mov byte [ebp + W_WALK_BIKE_SURF_STATE], 0
    test byte [ebp + W_STATUS_FLAGS_6], (1 << BIT_DUNGEON_WARP)
    jz .done                                ; ret z
    ; TODO-HW: audio (Phase 3) — pret: call PlayDefaultMusic
.done:
    ret

; ---------------------------------------------------------------------------
; BikeRidingTilesets — data/tilesets/bike_riding_tilesets.asm (pret embeds it
; right after IsBikeRidingAllowed). $FF-terminated tileset-id list.
; ---------------------------------------------------------------------------
section .data
BikeRidingTilesets:
    db OVERWORLD
    db FOREST
    db UNDERGROUND
    db SHIP_PORT
    db CAVERN
    db 0xFF                                  ; end
