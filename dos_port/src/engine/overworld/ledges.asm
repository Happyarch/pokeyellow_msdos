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
; HandleMidJump is called from OverworldLoopLessDelay (src/home/overworld.asm),
; restored at pret's position after being a dropped call from s16 to 2026-08-03
; (regression-overworld-ledge-hop-never-advanced; gated by the ledge_hop golden).
;
; Build (check): nasm -f coff -I include/ -I . -o ledges.o \
;                     src/engine/overworld/ledges.asm
; ---------------------------------------------------------------------------

bits 32

%include "gb_memmap.inc"
%include "assets/map_dims.inc"   ; map-id / tileset-id constants (Tier-1 generated)
%include "gb_macros.inc"
%include "assets/audio_constants.inc"   ; SFX_LEDGE (real id; audio engine is live)

; Tileset tables moved to the data layer 2026-08-02 (see the note at EOF).
extern TilePairCollisionsLand           ; src/data/tilesets/pair_collision_tile_ids.asm
extern TilePairCollisionsWater          ; src/data/tilesets/pair_collision_tile_ids.asm
extern LedgeTiles                       ; src/data/tilesets/ledge_tiles.asm

; --- Tileset ids (constants/tileset_constants.asm; not in gb_memmap.inc) -----

; PAD_BUTTONS | PAD_CTRL_PAD = every button ($0F | $F0). pret sets wJoyIgnore to
; this so no real input is honored while the ledge hop plays out.
PAD_ALL             equ 0xFF

; SFX_LEDGE comes from the generated assets/audio_constants.inc (real id 0xA2).
; The audio engine is live (home/audio.asm PlaySound), so this is a real call now
; (OW-A.14 destub 2026-07-09); the former hand-`equ 0xB6` placeholder was wrong.

; Standing tile (pret lda_coord 8,9). In the 40-wide port tilemap the player's feet
; are at (PLAYER_STANDING_ROW, PLAYER_STANDING_COL); same tile
; _GetTileAndCoordsInFrontOfPlayer uses as its base (player_state.asm).
STANDING_TILE_OFF   equ wTileMap + PLAYER_STANDING_ROW * SCREEN_TILES_W + PLAYER_STANDING_COL

global HandleLedges
global LoadHoppingShadowOAM
; LedgeHoppingShadow{,End} / LedgeHoppingShadowOAM{,End} are defined in the
; generated assets/ledge_shadow.inc below and are deliberately NOT `global` —
; declaring them here would make this file a second provider of a label the .inc
; already defines (lint_pret_labels `local_shadow`). Same convention as
; EmotionBubbles in emotion_bubbles.asm.
extern StartSimulatingJoypadStates    ; src/home/map_objects.asm (linked)
extern PlaySound                      ; src/home/audio.asm (real gateway, linked)
extern CopyVideoDataDouble            ; src/home/copy2.asm (1bpp -> 2bpp VRAM expand)
extern GBScreenToCanvasXY             ; src/engine/gfx/sprite_oam.asm — GB-screen -> canvas
extern spr_dos_sy, spr_dos_sx, spr_oam_valid  ; src/ppu/ppu.asm

section .text

; ---------------------------------------------------------------------------
; CheckForJumpingAndTilePairCollisions — pret home/overworld.asm.
;
; In:  ESI = flat host ptr to the directional tile-pair table (TilePairCollisionsLand
;            or ...Water); wTileInFrontOfPlayer already set by the caller.
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
;      Front tile is read from wTileInFrontOfPlayer.
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
; In:  wTileInFrontOfPlayer set by caller; W_SPRITE_PLAYER_FACING_DIR; tilemap.
; Clobbers: AL, BX, DX, ESI, flags.
; ---------------------------------------------------------------------------
HandleLedges:
    test byte [ebp + wMovementFlags], (1 << BIT_LEDGE_OR_FISHING)
    jnz .ret                                       ; already hopping / fishing
    cmp byte [ebp + wCurMapTileset], OVERWORLD
    jne .ret                                       ; ledges exist only in the OVERWORLD tileset
    mov bh, [ebp + W_SPRITE_PLAYER_FACING_DIR]     ; b = facing direction
    mov bl, [ebp + STANDING_TILE_OFF]              ; c = tile player stands on
    mov dl, [ebp + wTileInFrontOfPlayer]      ; d = ledge tile candidate (in front)
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
    mov al, [ebp + hJoyHeld]
    and al, dh
    jz  .ret                                       ; player isn't pressing into the ledge
    ; --- arm the hop -------------------------------------------------------
    mov byte [ebp + wJoyIgnore], PAD_ALL         ; ignore real input during the hop
    or  byte [ebp + wMovementFlags], (1 << BIT_LEDGE_OR_FISHING)
    call StartSimulatingJoypadStates               ; arm scripted-movement input (preserves DX)
    mov al, dh
    mov [ebp + wSimulatedJoypadStatesEnd], al      ; queue the ledge direction...
    mov [ebp + wSimulatedJoypadStatesEnd + 1], al  ; ...into both queue bytes (pret)
    mov byte [ebp + wSimulatedJoypadStatesIndex], 2 ; two simulated steps
    call LoadHoppingShadowOAM
    mov al, SFX_LEDGE
    call PlaySound                                  ; pret: ld a,SFX_LEDGE / call PlaySound
.ret:
    ret

; ---------------------------------------------------------------------------
; LoadHoppingShadowOAM — pret engine/overworld/ledges.asm:LoadHoppingShadowOAM.
;
;     ld hl, vChars1 tile $7f
;     ld de, LedgeHoppingShadow
;     lb bc, BANK(LedgeHoppingShadow), (LedgeHoppingShadowEnd - LedgeHoppingShadow) / TILE_1BPP_SIZE
;     call CopyVideoDataDouble
;     ld hl, LedgeHoppingShadowOAM
;     ld de, wShadowOAMSprite36
;     ld bc, LedgeHoppingShadowOAMEnd - LedgeHoppingShadowOAM
;     call CopyData
;     ld a, $a0
;     ld [wShadowOAMSprite38YCoord], a
;     ld [wShadowOAMSprite39YCoord], a
;
; REPLACED THE RET-STUB 2026-08-22. The stub's justification was that "the port's
; OAM path models sprites differently and has no dedicated shadow slots yet" —
; that premise is false: PrepareOAMData (src/engine/gfx/sprite_oam.asm) already
; carries pret's `.clearUnused` special case that STOPS at wShadowOAMSprite36
; ($90) while BIT_LEDGE_OR_FISHING is set, precisely so entries 36-39 survive a
; hop. The four slots were being preserved for a shadow nobody wrote.
;
; wShadowOAMSprite36/38/39 have no symbols in gb_memmap.inc; they are the standard
; 4-bytes-per-entry offsets from wShadowOAM, written the same way PrepareOAMData
; writes its own `0x90` low-byte comparison.
;
; DEVIATION{class=HAL; pret=engine/overworld/ledges.asm:LoadHoppingShadowOAM; behavior=after the two faithful shadow-OAM writes the port additionally projects each entry onto the widescreen canvas through GBScreenToCanvasXY into spr_dos_sy and spr_dos_sx, grows spr_oam_valid to cover index 37 without lowering it, and mirrors both entries into GB_OAM at fe00; evidence=render_sprites in src/ppu/ppu.asm positions OBJ exclusively from spr_dos_sy and spr_dos_sx gated by the spr_oam_valid count and reads tile and attr from GB_OAM never from the shadow bytes, so a raw shadow-OAM write draws nothing at all - the identical publish and mirror is what WriteOAMBlock in src/home/oam.asm does and why the trainer-sight emotion bubble needed it, and on hardware the unconditional VBlank OAM DMA plus the hardware OBJ scan give pret both for free; lifetime=permanent, the OBJ side of the software video HAL}
; ---------------------------------------------------------------------------
LoadHoppingShadowOAM:
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi

    ; 1bpp shadow tile -> vChars1 tile $7f. The OAM records name tile $ff, which is
    ; the same VRAM address seen through the $8000-based OBJ tile index.
    ; CopyVideoDataDouble arms g_tilecache_dirty itself.
    mov esi, GB_VFONT + 0x7F * TILE_SIZE     ; ld hl, vChars1 tile $7f
    mov edx, LedgeHoppingShadow              ; ld de, LedgeHoppingShadow (flat .data label)
    mov bh, 0                                ; BANK(LedgeHoppingShadow) — flat no-op
    mov bl, LEDGE_SHADOW_TILES               ; (End - Start) / TILE_1BPP_SIZE
    call CopyVideoDataDouble

    ; The two OAM records -> wShadowOAMSprite36. pret uses CopyData, whose port
    ; contract takes BOTH pointers as EBP-relative GB offsets; the source here is a
    ; flat .data label, so the copy is written out rather than routed through it.
    mov esi, LedgeHoppingShadowOAM
    lea edi, [ebp + wShadowOAM + 36 * 4]     ; wShadowOAMSprite36
    mov ecx, LedgeHoppingShadowOAMEnd - LedgeHoppingShadowOAM
    rep movsb

    mov byte [ebp + wShadowOAM + 38 * 4], 0xA0  ; ld [wShadowOAMSprite38YCoord], a
    mov byte [ebp + wShadowOAM + 39 * 4], 0xA0  ; ld [wShadowOAMSprite39YCoord], a

    ; --- port-only publish (see the DEVIATION above) -------------------------
    ; Entries 36 and 37 only; 38/39 were just parked off-screen at Y=$a0 and are
    ; not published, so render_sprites never reaches them through a stale
    ; spr_dos position (PrepareOAMData's .clearUnused stops at 36 during a hop).
    mov ecx, 36
.publish:
    mov bh, [ebp + wShadowOAM + ecx * 4]     ; OAM-byte-convention Y
    mov bl, [ebp + wShadowOAM + ecx * 4 + 1] ; OAM-byte-convention X
    mov eax, [ebp + wShadowOAM + ecx * 4]    ; the 4 bytes (Y, X, tile, attr)
    mov [ebp + GB_OAM + ecx * 4], eax        ; mirror into $FE00 (tile/attr source)
    call GBScreenToCanvasXY                  ; -> EAX = canvas Y, EDX = canvas X
    mov [spr_dos_sy + ecx * 4], eax
    mov [spr_dos_sx + ecx * 4], edx
    inc ecx
    cmp ecx, 38
    jb .publish
    ; grow, never lower — another publisher may already have raised the count
    cmp dword [spr_oam_valid], 38
    jae .done
    mov dword [spr_oam_valid], 38
.done:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

; Tier-1 generated data: LedgeHoppingShadow{,End} (pret gfx/overworld/shadow.1bpp)
; and LedgeHoppingShadowOAM{,End} (pret's two dbsprite records).
section .data
%include "assets/ledge_shadow.inc"
section .text

; ---------------------------------------------------------------------------
; HandleMidJump — pret home/overworld.asm:HandleMidJump.
; Called from the overworld frame loop (M7.1) each iteration. Advances the ledge-hop
; animation only while BIT_LEDGE_OR_FISHING is set.
; ---------------------------------------------------------------------------

; Embedded data (pret data/tilesets/*.asm) USED TO LIVE HERE.
;
; TilePairCollisionsLand / TilePairCollisionsWater / LedgeTiles moved 2026-08-02
; to the data layer (2026-08-16: to their mirrored paths under src/data/tilesets/)
; and are now GENERATED into one assets/*.inc per pret file
; by tools/generators/gen_static_tables.py. They were reported [aux_misplaced]
; (a pret data/ label must live in the data layer), and they had additionally
; been hand-transcribed from pret rather than generated. The header that stood
; here predicted exactly this move: "a future pass may promote these to a
; generated assets/*.inc under the two-tier rule". Bytes unchanged.
