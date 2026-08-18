; pikachu_movement.asm — mirror of pret engine/pikachu/pikachu_movement.asm.
;
; SUBSET, deliberately. pret's file is ~1100 lines of the Pikachu follower
; movement FSM; this port file currently holds ONE of its labels plus that
; label's own data blob, in pret order:
;   LoadPikachuShadowIntoVRAM (pret :917) + LedgeHoppingShadowGFX_3F (:923)
;
; Everything else in the pret file (ApplyPikachuMovementData_,
; LoadPikachuBallIconIntoVRAM, Func_fd851, LoadPikachuSpriteIntoVRAM, the
; Cosine_e/step tables, the movement-command handlers, ...) is UNPORTED and
; stays that way until the follower subsystem is scheduled. This file exists so
; that the one routine TryApplyPikachuMovementData needs lives at its mirrored
; pret path rather than being smuggled into a neighbouring file.
;
; Register map (CLAUDE.md): A→AL, B→BH, C→BL, DE→EDX, HL→ESI, GB memory =
; [ebp + SYM].
;
; VRAM TILE CACHE: this routine writes tile PATTERN bytes into vChars1, so the
; software PPU's `tile_cache` must be invalidated. It is — via the pret call
; chain itself: CopyVideoDataDoubleAlternate dispatches to CopyVideoDataDouble
; (LCD on) or FarCopyDataDouble (LCD off), and BOTH arm `g_tilecache_dirty` as
; their first statement (src/home/copy2.asm). There is no hand-rolled copy here,
; so nothing further is owed.
;
; Build (standalone check):
;   nasm -f coff -I include/ -I . -D BUG_FIX_LEVEL=0 \
;        src/engine/pikachu/pikachu_movement.asm -o /tmp/chk.o

bits 32

%include "gb_memmap.inc"
%include "gb_macros.inc"

; ---------------------------------------------------------------------------
; VRAM sub-region names from pret ram/vram.asm's "overworld" UNION arm, which
; include/gb_memmap.inc does not carry (it carries the "generic" and
; "battle/menu" arms, vChars0/1/2 and vSprites/vFont). Same addresses, pret's
; own overlay:
;     vNPCSprites  == vChars0 == $8000   (ds $80 tiles)
;     vNPCSprites2 == vChars1 == $8800   (ds $80 tiles)
; Written as an alias of the existing symbol so it cannot drift.
; ---------------------------------------------------------------------------

TILE_1BPP               equ 8       ; TILE_1BPP_SIZE — bytes per 1bpp 8x8 tile
                                    ; (same file-local spelling as town_map.asm)

; ---------------------------------------------------------------------------
; Externs
; ---------------------------------------------------------------------------
extern CopyVideoDataDoubleAlternate   ; src/home/copy.asm

global LoadPikachuShadowIntoVRAM

section .text

; ---------------------------------------------------------------------------
; LoadPikachuShadowIntoVRAM — pret engine/pikachu/pikachu_movement.asm:917.
;
;   ld hl, vNPCSprites2 + $7f * $10
;   ld de, LedgeHoppingShadowGFX_3F
;   lb bc, BANK(LedgeHoppingShadowGFX_3F), (End - Start) / 8
;   jp CopyVideoDataDoubleAlternate
;
; Stages the one-tile ledge-hop shadow, expanded 1bpp→2bpp, into the LAST tile
; slot of vNPCSprites2 ($8FF0 — OBJ tile index $FF).
;
; Port pointer convention (src/home/copy2.asm header): the graphics SOURCE is a
; FLAT program-image pointer (EDX), the VRAM DESTINATION is an EBP-relative GB
; offset (ESI). BH = source bank (a no-op under the flat model), BL = 1bpp tile
; count.
; ---------------------------------------------------------------------------
LoadPikachuShadowIntoVRAM:
    mov esi, vNPCSprites2 + 0x7f * TILE_SIZE            ; ld hl, vNPCSprites2 + $7f * $10
    lea edx, [LedgeHoppingShadowGFX_3F]                 ; ld de, LedgeHoppingShadowGFX_3F
    mov bh, 0                                           ; BANK(LedgeHoppingShadowGFX_3F) — no-op
    mov bl, (LedgeHoppingShadowGFX_3FEnd - LedgeHoppingShadowGFX_3F) / TILE_1BPP
    jmp CopyVideoDataDoubleAlternate                    ; jp (tail call, as pret)

; ---------------------------------------------------------------------------
; LedgeHoppingShadowGFX_3F — pret engine/pikachu/pikachu_movement.asm:923,
; INCBIN "gfx/overworld/shadow.1bpp" (8 bytes = one 1bpp tile).
;
; Incbin'd straight from the read-only pret gfx tree, the same way
; src/engine/battle/battle_transitions.asm carries
; `incbin "../gfx/overworld/battle_transition.2bpp"`. It is program-image data,
; hence `section .data` (link.ld sections rule).
; ---------------------------------------------------------------------------
section .data

global LedgeHoppingShadowGFX_3F
LedgeHoppingShadowGFX_3F:
    incbin "../gfx/overworld/shadow.1bpp"
LedgeHoppingShadowGFX_3FEnd:
