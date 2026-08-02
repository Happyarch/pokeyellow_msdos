; ledges.asm — ledge hopping + tile-pair (elevation-seam) collisions.
;
; Intended repo path: dos_port/src/engine/overworld/ledges.asm
;
; Faithful translations (pret cross-reference maintained):
;   CheckForJumpingAndTilePairCollisions  home/overworld.asm:CheckForJumpingAndTilePairCollisions
;   CheckForTilePairCollisions2           home/overworld.asm:CheckForTilePairCollisions2
;   CheckForTilePairCollisions            home/overworld.asm:CheckForTilePairCollisions
;   HandleLedges                          engine/overworld/ledges.asm:HandleLedges
;   HandleMidJump                         home/overworld.asm:HandleMidJump
;   TilePairCollisionsLand/Water          data/tilesets/pair_collision_tile_ids.asm
;   LedgeTiles                            data/tilesets/ledge_tiles.asm
;
; _HandleMidJump and PlayerJumpingYScreenCoords are pret
; engine/overworld/player_animations.asm labels and MOVED to that mirror,
; src/engine/overworld/player_animations.asm, in the s16 mirror repair. The
; private .bss hop index (w_player_jumping_y_index) went with them.
;
; Register map (SM83 -> x86): A->AL, HL->ESI, B->BH, C->BL, DE->DX (see CLAUDE.md).
;   GB RAM/ROM  -> EBP-relative offset  [ebp + SYM]   (SYM from gb_memmap.inc)
;   Embedded data tables (LedgeTiles / TilePairCollisions / PlayerJumping...) live in
;   .data and are addressed as FLAT 32-bit host pointers ([esi] / [Table + esi]),
;   per the port convention (see map_sprites.asm / simulate_joypad.asm).
;
; This file is LINKED (GAME_SRCS, since OW-7.2): HandleLedges is called from
; CollisionCheckOnLand. (It was originally check-only, reached only under
; -D OVERWORLD_LEDGES; that gate is gone.)
;
; This header used to add "and HandleMidJump from the overworld frame loop".
; MEASURED FALSE (s16): HandleMidJump has ZERO callers tree-wide, so the hop is
; armed here but never advanced or torn down. See the BUG{} on HandleMidJump in
; src/home/overworld.asm.
;
; Build (check): nasm -f coff -I include/ -I . -o ledges.o \
;                     src/engine/overworld/ledges.asm
; ---------------------------------------------------------------------------

bits 32

%include "gb_memmap.inc"
%include "gb_macros.inc"
%include "assets/audio_constants.inc"   ; SFX_LEDGE (real id; audio engine is live)

; Tileset tables moved to the data layer 2026-08-02 (see the note at EOF).
extern TilePairCollisionsLand           ; src/data/tileset_data.asm
extern TilePairCollisionsWater          ; src/data/tileset_data.asm
extern LedgeTiles                       ; src/data/tileset_data.asm

; --- Tileset ids (constants/tileset_constants.asm; not in gb_memmap.inc) -----
OVERWORLD           equ 0
CAVERN              equ 17
FOREST              equ 3

; PAD_BUTTONS | PAD_CTRL_PAD = every button ($0F | $F0). pret sets wJoyIgnore to
; this so no real input is honored while the ledge hop plays out.
PAD_ALL             equ 0xFF

; SFX_LEDGE comes from the generated assets/audio_constants.inc (real id 0xA2).
; The audio engine is live (home/audio.asm PlaySound), so this is a real call now
; (OW-A.14 destub 2026-07-09); the former hand-`equ 0xB6` placeholder was wrong.

; Standing tile (pret lda_coord 8,9). In the 40-wide port tilemap the player's feet
; are at (PLAYER_STANDING_ROW, PLAYER_STANDING_COL); same tile
; _GetTileAndCoordsInFrontOfPlayer uses as its base (player_state.asm).
STANDING_TILE_OFF   equ W_TILEMAP + PLAYER_STANDING_ROW * SCREEN_TILES_W + PLAYER_STANDING_COL

global HandleLedges
extern StartSimulatingJoypadStates    ; src/home/map_objects.asm (linked)
extern PlaySound                      ; src/home/audio.asm (real gateway, linked)
; LoadHoppingShadowOAM stub lives in overworld_stubs.asm (stub convention: a stub never
; sits in the file mirroring its own pret source). Retire the stub + restore the real
; body here once PrepareOAMData models shadow-OAM slots. See overworld_stubs.asm.
extern LoadHoppingShadowOAM           ; src/engine/overworld/overworld_stubs.asm (ret-stub, linked)

section .text

; ---------------------------------------------------------------------------
; CheckForJumpingAndTilePairCollisions — pret home/overworld.asm.
;
; In:  ESI = flat host ptr to the directional tile-pair table (TilePairCollisionsLand
;            or ...Water); W_TILE_IN_FRONT_OF_PLAYER already set by the caller.
;            (pret re-runs GetTileAndCoordsInFrontOfPlayer here; the port's caller,
;            CollisionCheckOnLand, sets it via _GetTileAndCoordsInFrontOfPlayer
;            immediately before — so this port keeps the value rather than
;            re-deriving it.)
; Out: CF = 1 if an illegal tile-pair boundary is crossed (movement blocked).
;      May arm a ledge hop (HandleLedges sets BIT_LEDGE_OR_FISHING + simulated joypad);
;      in that case CF = 0 (no tile-pair collision) and the caller allows the move.
; Clobbers: AL, BL, CL, DH, ESI, flags.
;
; SM83:
;   push hl / predef GetTileAndCoordsInFrontOfPlayer / farcall HandleLedges
;   and a / ld a,[wMovementFlags] / bit BIT_LEDGE_OR_FISHING,a / ret nz
;   (falls into CheckForTilePairCollisions2)
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; CheckForTilePairCollisions2 — pret. Recomputes the standing tile, then falls
; through to CheckForTilePairCollisions.
; ---------------------------------------------------------------------------
    ; fall through

; ---------------------------------------------------------------------------
; CheckForTilePairCollisions — pret. Scan the $FF-terminated table for a
; (tileset, standingTile, frontTile) triple that forbids the crossing.
;
; In:  ESI = flat host ptr to table; DH = standing tile.
;      Front tile is read from W_TILE_IN_FRONT_OF_PLAYER.
; Out: CF = 1 if the crossing is forbidden, CF = 0 otherwise.
; Clobbers: AL, BL, CL, ESI, flags. (DH preserved.)
;
; NOTE: the pointer arithmetic mirrors pret exactly, including the quirk that the
; .firstInPair non-match path leaves ESI mid-entry (pret leaves hl at tile2) — kept
; for faithfulness. The .secondInPair path uses LEA for the flag-preserving 16-bit
; `inc hl` so the following `jr nz` still tests the tile compare (x86 `inc` would
; clobber ZF, GB `inc hl` does not).
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; HandleLedges — engine/overworld/ledges.asm:HandleLedges.
;
; If the player is walking into a ledge tile (facing + standing + ledge triple in
; LedgeTiles) while holding the required direction, arm a two-tile ledge hop:
; set BIT_LEDGE_OR_FISHING, ignore all input, and queue two simulated joypad presses
; of the ledge direction so the normal movement loop walks the player forward while
; the hop plays out. OVERWORLD tileset only.
;
; In:  W_TILE_IN_FRONT_OF_PLAYER set by caller; W_SPRITE_PLAYER_FACING_DIR; tilemap.
; Clobbers: AL, BX, DX, ESI, flags.
; ---------------------------------------------------------------------------
HandleLedges:
    test byte [ebp + W_MOVEMENT_FLAGS], (1 << BIT_LEDGE_OR_FISHING)
    jnz .ret                                       ; already hopping / fishing
    cmp byte [ebp + W_CUR_MAP_TILESET], OVERWORLD
    jne .ret                                       ; ledges exist only in the OVERWORLD tileset
    mov bh, [ebp + W_SPRITE_PLAYER_FACING_DIR]     ; b = facing direction
    mov bl, [ebp + STANDING_TILE_OFF]              ; c = tile player stands on
    mov dl, [ebp + W_TILE_IN_FRONT_OF_PLAYER]      ; d = ledge tile candidate (in front)
    mov esi, LedgeTiles                            ; flat host ptr
.loop:
    mov al, [esi]                                  ; facing (or $ff terminator)
    inc esi
    cmp al, 0xFF
    je  .ret                                       ; end of list → no ledge here
    cmp al, bh
    jne .next1
    mov al, [esi]                                  ; standing tile
    inc esi
    cmp al, bl
    jne .next2
    mov al, [esi]                                  ; ledge tile
    inc esi
    cmp al, dl
    jne .next3
    mov dh, [esi]                                  ; DH = e = required input (PAD_*)
    jmp .foundMatch
.next1:
    inc esi
.next2:
    inc esi
.next3:
    inc esi
    jmp .loop
.foundMatch:
    mov al, [ebp + H_JOY_HELD]
    and al, dh
    jz  .ret                                       ; player isn't pressing into the ledge
    ; --- arm the hop -------------------------------------------------------
    mov byte [ebp + W_JOY_IGNORE], PAD_ALL         ; ignore real input during the hop
    or  byte [ebp + W_MOVEMENT_FLAGS], (1 << BIT_LEDGE_OR_FISHING)
    call StartSimulatingJoypadStates               ; arm scripted-movement input (preserves DX)
    mov al, dh
    mov [ebp + W_SIMULATED_JOYPAD_STATES_END], al      ; queue the ledge direction...
    mov [ebp + W_SIMULATED_JOYPAD_STATES_END + 1], al  ; ...into both queue bytes (pret)
    mov byte [ebp + W_SIMULATED_JOYPAD_STATES_INDEX], 2 ; two simulated steps
    call LoadHoppingShadowOAM
    mov al, SFX_LEDGE
    call PlaySound                                  ; pret: ld a,SFX_LEDGE / call PlaySound
.ret:
    ret

; ---------------------------------------------------------------------------
; HandleMidJump — pret home/overworld.asm:HandleMidJump.
; Called from the overworld frame loop (M7.1) each iteration. Advances the ledge-hop
; animation only while BIT_LEDGE_OR_FISHING is set.
; ---------------------------------------------------------------------------

; Embedded data (pret data/tilesets/*.asm) USED TO LIVE HERE.
;
; TilePairCollisionsLand / TilePairCollisionsWater / LedgeTiles moved 2026-08-02
; to src/data/tileset_data.asm and are now GENERATED into assets/tileset_tables.inc
; by tools/generators/gen_static_tables.py. They were reported [aux_misplaced]
; (a pret data/ label must live in the data layer), and they had additionally
; been hand-transcribed from pret rather than generated. The header that stood
; here predicted exactly this move: "a future pass may promote these to a
; generated assets/*.inc under the two-tier rule". Bytes unchanged.
