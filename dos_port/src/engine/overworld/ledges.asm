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
;   _HandleMidJump                        engine/overworld/player_animations.asm:_HandleMidJump
;   TilePairCollisionsLand/Water          data/tilesets/pair_collision_tile_ids.asm
;   LedgeTiles                            data/tilesets/ledge_tiles.asm
;   PlayerJumpingYScreenCoords            engine/overworld/player_animations.asm
;
; Register map (SM83 -> x86): A->AL, HL->ESI, B->BH, C->BL, DE->DX (see CLAUDE.md).
;   GB RAM/ROM  -> EBP-relative offset  [ebp + SYM]   (SYM from gb_memmap.inc)
;   Embedded data tables (LedgeTiles / TilePairCollisions / PlayerJumping...) live in
;   .data and are addressed as FLAT 32-bit host pointers ([esi] / [Table + esi]),
;   per the port convention (see map_sprites.asm / simulate_joypad.asm).
;
; This file is CHECK-ONLY by default (assembled by `make check`, not linked). It is
; reached only when overworld.asm is built with -D OVERWORLD_LEDGES, at which point it
; must be promoted to a linked source list. See SUMMARY / Makefile note below.
;
; Build (check): nasm -f coff -I include/ -I . -o ledges.o \
;                     src/engine/overworld/ledges.asm
; ---------------------------------------------------------------------------

bits 32

%include "gb_memmap.inc"
%include "gb_macros.inc"

; --- Tileset ids (constants/tileset_constants.asm; not in gb_memmap.inc) -----
OVERWORLD           equ 0
CAVERN              equ 17
FOREST              equ 3

; PAD_BUTTONS | PAD_CTRL_PAD = every button ($0F | $F0). pret sets wJoyIgnore to
; this so no real input is honored while the ledge hop plays out.
PAD_ALL             equ 0xFF

; TODO-HW(audio): real id = SFX_LEDGE (constants/music_constants.asm). PlaySound is
; a stub in this port (src/engine/battle/move_effect_helpers.asm); value not yet
; load-bearing. Placeholder kept explicit so the audio pass can wire the true id.
SFX_LEDGE           equ 0xB6

; Standing tile (pret lda_coord 8,9). In the 40-wide port tilemap the player's feet
; are at (PLAYER_STANDING_ROW, PLAYER_STANDING_COL); same tile GetTileInFrontOfPlayer
; uses as its base (overworld.asm).
STANDING_TILE_OFF   equ W_TILEMAP + PLAYER_STANDING_ROW * SCREEN_TILES_W + PLAYER_STANDING_COL

global CheckForJumpingAndTilePairCollisions
global CheckForTilePairCollisions2
global CheckForTilePairCollisions
global HandleLedges
global HandleMidJump
global _HandleMidJump
global TilePairCollisionsLand
global TilePairCollisionsWater
global LedgeTiles

extern StartSimulatingJoypadStates    ; src/engine/overworld/simulate_joypad.asm (linked)
extern PlaySound                      ; src/engine/battle/move_effect_helpers.asm (stub, linked)
extern UpdateSprites                  ; src/engine/overworld/movement.asm (linked)
extern Delay3                         ; src/video/frame.asm (linked)
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
;            CollisionCheckOnLand, sets it via GetTileInFrontOfPlayer immediately
;            before — so this port keeps the value rather than re-deriving it, which
;            avoids exporting GetTileInFrontOfPlayer out of overworld.asm.)
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
CheckForJumpingAndTilePairCollisions:
    push esi                                       ; preserve the table ptr across HandleLedges
    call HandleLedges                              ; may arm a ledge hop
    pop esi
    test byte [ebp + W_MOVEMENT_FLAGS], (1 << BIT_LEDGE_OR_FISHING)
    jz  CheckForTilePairCollisions2               ; not jumping a ledge → run the tile-pair scan
    clc                                            ; jumping a ledge → no tile-pair collision
    ret

; ---------------------------------------------------------------------------
; CheckForTilePairCollisions2 — pret. Recomputes the standing tile, then falls
; through to CheckForTilePairCollisions.
; ---------------------------------------------------------------------------
CheckForTilePairCollisions2:
    mov dh, [ebp + STANDING_TILE_OFF]              ; DH = tile the player stands on (pret wTilePlayerStandingOn)
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
CheckForTilePairCollisions:
    mov cl, [ebp + W_TILE_IN_FRONT_OF_PLAYER]      ; c = tile in front
.loop:
    mov bl, [ebp + W_CUR_MAP_TILESET]              ; b = current tileset (pret re-reads each iter)
    mov al, [esi]                                  ; entry tileset (hl→tile1)
    inc esi
    cmp al, 0xFF
    je  .noMatch
    cmp al, bl
    je  .tilesetMatches
    inc esi                                        ; skip tile1 (hl→tile2)
.retry:
    inc esi                                        ; skip tile2 (hl→next entry)
    jmp .loop
.tilesetMatches:
    mov al, [esi]                                  ; tile1
    cmp al, dh
    je  .firstInPair
    inc esi                                        ; hl→tile2
    mov al, [esi]                                  ; tile2
    cmp al, dh
    je  .secondInPair
    jmp .retry
.firstInPair:
    inc esi                                        ; hl→tile2
    mov al, [esi]                                  ; tile2
    cmp al, cl
    je  .foundMatch
    jmp .loop                                      ; (faithful: ESI left at tile2)
.secondInPair:
    dec esi                                        ; hl→tile1
    mov al, [esi]                                  ; a = tile1 (hli)
    inc esi                                        ; hl→tile2
    cmp al, cl                                     ; compare tile1 vs front tile → sets ZF
    lea esi, [esi + 1]                             ; hl→next entry (flag-preserving inc)
    jne .loop
.foundMatch:
    stc
    ret
.noMatch:
    clc
    ret

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
    call PlaySound                                  ; TODO-HW(audio): stub
.ret:
    ret

; ---------------------------------------------------------------------------
; HandleMidJump — pret home/overworld.asm:HandleMidJump.
; Called from the overworld frame loop (M7.1) each iteration. Advances the ledge-hop
; animation only while BIT_LEDGE_OR_FISHING is set.
; ---------------------------------------------------------------------------
HandleMidJump:
    test byte [ebp + W_MOVEMENT_FLAGS], (1 << BIT_LEDGE_OR_FISHING)
    jz  .ret
    call _HandleMidJump
.ret:
    ret

; ---------------------------------------------------------------------------
; _HandleMidJump — pret engine/overworld/player_animations.asm:_HandleMidJump.
;
; Steps the player's on-screen Y through the 16-entry PlayerJumpingYScreenCoords arc
; (the hop). When the arc finishes and the current walk step completes, tears down the
; ledge/scripted-movement state and re-enables input.
;
; NOTE(port renderer): the hop's visible arc requires the player renderer to honor
; W_SPRITE_PLAYER_Y_PIXELS. The port currently pins the player at screen-centre (memory:
; "player Y pixel fixed"); until the renderer reads YPixels for the player, the logic
; (state teardown, input gating, the two forward steps) is faithful but the vertical
; arc will not be drawn. See SUMMARY.
;
; Clobbers: AL, CL, ESI, flags.
; ---------------------------------------------------------------------------
_HandleMidJump:
    mov al, [w_player_jumping_y_index]             ; c = current index
    mov cl, al
    inc al
    cmp al, 0x10                                    ; index+1 >= 16 → arc done
    jae .finishedJump
    mov [w_player_jumping_y_index], al             ; store incremented index
    movzx esi, cl                                  ; b=0; hl = coords + old index
    mov al, [PlayerJumpingYScreenCoords + esi]     ; next Y screen coord
    mov [ebp + W_SPRITE_PLAYER_Y_PIXELS], al
    ret
.finishedJump:
    cmp byte [ebp + W_WALK_COUNTER], 0
    jne .ret                                        ; wait until the current step finishes
    call UpdateSprites
    call Delay3
    mov byte [ebp + H_JOY_HELD], 0
    mov byte [ebp + H_JOY_PRESSED], 0
    mov byte [ebp + H_JOY_RELEASED], 0
    mov byte [w_player_jumping_y_index], 0
    and byte [ebp + W_MOVEMENT_FLAGS], ~(1 << BIT_LEDGE_OR_FISHING)
    and byte [ebp + W_STATUS_FLAGS_5], ~(1 << BIT_SCRIPTED_MOVEMENT_STATE)
    mov byte [ebp + W_JOY_IGNORE], 0
.ret:
    ret

; ===========================================================================
; Embedded data (pret data/tilesets/*.asm). Held in .data (flat host pointers).
; Kept inline here as this is the only consumer; a future pass may promote these
; to a generated assets/*.inc under the two-tier rule (they are pure static tables).
; ===========================================================================
section .data

; data/tilesets/pair_collision_tile_ids.asm
; FORMAT: tileset id, tile 1, tile 2. Terminated by $FF. The player may not cross
; between tile 1 and tile 2 (simulates elevation differences).
TilePairCollisionsLand:
    db CAVERN, 0x20, 0x05
    db CAVERN, 0x41, 0x05
    db FOREST, 0x30, 0x2E
    db CAVERN, 0x2A, 0x05
    db CAVERN, 0x05, 0x21
    db FOREST, 0x52, 0x2E
    db FOREST, 0x55, 0x2E
    db FOREST, 0x56, 0x2E
    db FOREST, 0x20, 0x2E
    db FOREST, 0x5E, 0x2E
    db FOREST, 0x5F, 0x2E
    db 0xFF                                         ; end

TilePairCollisionsWater:
    db FOREST, 0x14, 0x2E
    db FOREST, 0x48, 0x2E
    db CAVERN, 0x14, 0x05
    db 0xFF                                         ; end

; data/tilesets/ledge_tiles.asm
; FORMAT: player facing, tile player standing on, ledge tile, input required.
; Terminated by $FF.
LedgeTiles:
    db SPRITE_FACING_DOWN,  0x2C, 0x37, PAD_DOWN
    db SPRITE_FACING_DOWN,  0x39, 0x36, PAD_DOWN
    db SPRITE_FACING_DOWN,  0x39, 0x37, PAD_DOWN
    db SPRITE_FACING_LEFT,  0x2C, 0x27, PAD_LEFT
    db SPRITE_FACING_LEFT,  0x39, 0x27, PAD_LEFT
    db SPRITE_FACING_RIGHT, 0x2C, 0x0D, PAD_RIGHT
    db SPRITE_FACING_RIGHT, 0x2C, 0x1D, PAD_RIGHT
    db SPRITE_FACING_RIGHT, 0x39, 0x0D, PAD_RIGHT
    db 0xFF                                         ; end

; engine/overworld/player_animations.asm:PlayerJumpingYScreenCoords
; Sequence of on-screen Y coords for the player sprite during a ledge hop.
PlayerJumpingYScreenCoords:
    db 0x38, 0x36, 0x34, 0x32, 0x31, 0x30, 0x30, 0x30
    db 0x31, 0x32, 0x33, 0x34, 0x36, 0x38, 0x3C, 0x3C

; ---------------------------------------------------------------------------
section .bss
; pret wPlayerJumpingYScreenCoordsIndex (ram/wram.asm). Private to _HandleMidJump in
; this port; kept as a local .bss byte to avoid adding a gb_memmap.inc alias. Promote
; to gb_memmap.inc if any other routine needs it.
w_player_jumping_y_index: resb 1
