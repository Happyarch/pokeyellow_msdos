; is_player_just_outside_map.asm — pret: engine/overworld/is_player_just_outside_map.asm
;
; Faithful translation (pret cross-reference maintained):
;   IsPlayerJustOutsideMap   engine/overworld/is_player_just_outside_map.asm:IsPlayerJustOutsideMap
;
; Pure-logic leaf: no HW I/O, no VRAM/OAM writes. Called (pret) from
; engine/battle/wild_encounters.asm via `callfar IsPlayerJustOutsideMap` /
; `jr z, .CantEncounter` immediately after — so ZF is the entire caller-visible
; contract (no CF, no register outputs). Not yet wired to a port caller (the
; wild-encounter check is a separate ticket); this file only supplies the leaf.
;
; Register map (SM83 -> x86): A->AL, B->BH (per CLAUDE.md/asm-translation skill;
; B is pure scratch here, never a real BC pair value).
;   GB RAM -> EBP-relative offset [ebp + SYM]  (SYM from gb_memmap.inc)
;
; Build (check): nasm -f coff -I include/ -I . -o is_player_just_outside_map.o \
;                     src/engine/overworld/is_player_just_outside_map.asm
; ---------------------------------------------------------------------------

bits 32

%include "gb_memmap.inc"

global IsPlayerJustOutsideMap

section .text

; ---------------------------------------------------------------------------
; IsPlayerJustOutsideMap — pret engine/overworld/is_player_just_outside_map.asm.
;
; True ("just outside") when the player's block coordinate sits exactly one
; tile past a map edge on either axis:
;   wYCoord == wCurMapHeight*2      (one past the bottom edge)
;   wYCoord == 0xFF                 (one before the top edge, wrapped -1)
;   wXCoord == wCurMapWidth*2       (one past the right edge)
;   wXCoord == 0xFF                 (one before the left edge, wrapped -1)
;
; pret:
;   IsPlayerJustOutsideMap:
;       ld a, [wYCoord]
;       ld b, a
;       ld a, [wCurMapHeight]
;       call .compareCoordWithMapDimension
;       ret z
;       ld a, [wXCoord]
;       ld b, a
;       ld a, [wCurMapWidth]
;   .compareCoordWithMapDimension
;       add a
;       cp b
;       ret z
;       inc b
;       ret
;
; pret reuses one code path twice: the Y check is entered via `call` (so its
; `ret z`/final `ret` return into the still-running outer routine, at the `ret z`
; right after the call); the X check is entered by falling straight into the
; same label with no `call` (so its `ret z`/final `ret` return directly to
; IsPlayerJustOutsideMap's own caller). x86 `call`/`ret` manage the return
; address stack identically, so the same call-once/fall-through-once structure
; is mirrored exactly below via a real `call` for the Y check and physical
; fallthrough into `.compareCoordWithMapDimension` for the X check.
;
; Caller-visible flag: ZF. It is produced by exactly one of two instructions on
; any given path — the `cmp al, bh` (dimension*2 vs coord) or, if that compare
; misses, the `inc bl` (coord wraps 0xFF->0x00) — and nothing after either one
; but `jz`/`ret` executes before the routine returns, so ZF survives untouched
; to the `ret`. `jz`/`jnz` never touch flags; the only other instructions after
; a flag producer are `ret` itself (also flag-neutral). CF is not part of the
; contract (pret's caller only reads `jr z`) and is left as whatever `cmp`/`inc`
; happens to set — no caller relies on it.
;
; Out: ZF=1 if the player is exactly one tile outside the map, ZF=0 otherwise.
; Clobbers: AL, BH (BL/BX/EBX otherwise preserved), flags.
; ---------------------------------------------------------------------------
IsPlayerJustOutsideMap:
    mov al, [ebp + W_Y_COORD]
    mov bh, al
    mov al, [ebp + W_CUR_MAP_HEIGHT]
    call .compareCoordWithMapDimension
    jz  .ret                            ; ret z (ZF still holds the sub's result)
    mov al, [ebp + W_X_COORD]
    mov bh, al
    mov al, [ebp + W_CUR_MAP_WIDTH]
    ; fall through into .compareCoordWithMapDimension (no call — mirrors pret's
    ; fallthrough second use, so its ret/ret z below return straight to our caller)
.compareCoordWithMapDimension:
    add al, al                          ; add a  (dimension * 2)
    cmp al, bh                          ; cp b   -> ZF = (dimension*2 == coord)
    jz  .ret                            ; ret z
    inc bh                              ; inc b  -> ZF = (coord == 0xFF, wraps to 0)
    ret                                 ; ret    (returns with ZF from inc bh)
.ret:
    ret
