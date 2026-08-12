; scroll_draw_trainer_pic.asm — _ScrollTrainerPicAfterBattle, DrawTrainerPicColumn.
;
; Source (faithful translation): engine/battle/scroll_draw_trainer_pic.asm.
;
; After the last enemy mon faints, the trainer's pic scrolls back in from the
; right edge of the battle frame before the defeat text prints. pret drives it
; column-by-column: six passes, each redrawing the columns drawn so far one tile
; further left, with a 4-frame wait between passes.
;
; Called only from ScrollTrainerPicAfterBattle (src/engine/battle/core.asm), the
; port's flat stand-in for pret's `jpfar _ScrollTrainerPicAfterBattle`.
;
; PORTED 2026-08-11 (battle plan 1d). Both labels read `missing` in the label DB
; before this file existed, which is why TrainerBattleVictory's
; `call ScrollTrainerPicAfterBattle` had been dropped.
;
; DEVIATION{class=projection; pret=engine/battle/scroll_draw_trainer_pic.asm:_ScrollTrainerPicAfterBattle; behavior=the tilemap cursor is BCOORD(19, 0) on the port's 40x25 canvas and the row step is the canvas stride SCREEN_WIDTH=40 rather than the Game Boy's 20; evidence=every in-battle screen in this port is drawn through the BCOORD battle-frame projection (include/coords.inc) which offsets pret hlcoords by +10 columns and +3 rows onto the wider canvas - animations.asm uses the same macro for the same trainer-pic region at BCOORD(12, 0); lifetime=permanent while the port renders a 40x25 canvas}
;
; Register map (CLAUDE.md): A=AL, BC=EBX (B=BH C=BL), DE=EDX (D=DH E=DL),
; HL=ESI, EBP=GB base, tilemap writes are [ebp + esi].
;
; Build: nasm -f coff -I include/ -I . -o scroll_draw_trainer_pic.o scroll_draw_trainer_pic.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "coords.inc"

extern RunPaletteCommand            ; src/home/palettes.asm — BH = SET_PAL_* id
extern _LoadTrainerPic              ; src/engine/battle/init_battle.asm — pic -> vFrontPic
extern DelayFrames                  ; src/home/delay.asm — BL = frame count

global _ScrollTrainerPicAfterBattle
global DrawTrainerPicColumn

section .text

; ---------------------------------------------------------------------------
; _ScrollTrainerPicAfterBattle — reload the enemy trainer's pic and slide it in
; from the right edge of the battle frame.
;
; pret: xor a / ld [wEnemyMonSpecies2],a / ld b,SET_PAL_BATTLE /
;       call RunPaletteCommand / callfar _LoadTrainerPic / hlcoord 19,0 /
;       ld c,$0 / .scrollLoop ...
;
; In:  EBP = GB base. Out: everything caller-saved clobbered (as pret).
; ---------------------------------------------------------------------------
_ScrollTrainerPicAfterBattle:
    mov byte [ebp + wEnemyMonSpecies2], 0   ; xor a / ld [wEnemyMonSpecies2], a
    mov bh, SET_PAL_BATTLE                  ; ld b, SET_PAL_BATTLE (port reads BH)
    call RunPaletteCommand
    call _LoadTrainerPic                    ; pret: callfar (flat model — plain call)
    mov esi, BCOORD(19, 0)                  ; PROJ — pret hlcoord 19, 0
    xor bl, bl                              ; ld c, $0 — columns drawn so far
.scrollLoop:
    inc bl                                  ; inc c
    cmp bl, 7                               ; ld a,c / cp 7
    je .done                                ; ret z — all 6 columns are home
    xor dh, dh                              ; ld d, $0 — first tile id of column 0
    push ebx                                ; push bc
    push esi                                ; push hl
.drawTrainerPicLoop:
    call DrawTrainerPicColumn
    inc esi                                 ; inc hl — next column to the right
    add dh, 7                               ; ld a,7 / add d / ld d,a — next 7-tile column
    dec bl                                  ; dec c
    jnz .drawTrainerPicLoop
    mov bl, 4                               ; ld c, 4
    call DelayFrames
    pop esi                                 ; pop hl
    pop ebx                                 ; pop bc
    dec esi                                 ; dec hl — start one column further left
    jmp .scrollLoop
.done:
    ret

; ---------------------------------------------------------------------------
; DrawTrainerPicColumn — write one 7-tile column of the trainer pic to the
; tilemap: 7 ascending tile ids starting at DH, stepping down one row each.
;
; pret: push hl/de/bc / ld e,7 / .loop ld [hl],d / ld bc,SCREEN_WIDTH /
;       add hl,bc / inc d / dec e / jr nz / pop bc/de/hl / ret
;
; In:  ESI = GB tilemap offset of the column top, DH = first tile id.
; Out: ESI, EDX, EBX preserved (pret pushes and pops all three).
; ---------------------------------------------------------------------------
DrawTrainerPicColumn:
    push esi                                ; push hl
    push edx                                ; push de
    push ebx                                ; push bc
    mov dl, 7                               ; ld e, 7
.loop:
    mov [ebp + esi], dh                     ; ld [hl], d
    add esi, SCREEN_WIDTH                   ; ld bc,SCREEN_WIDTH / add hl,bc
    inc dh                                  ; inc d
    dec dl                                  ; dec e
    jnz .loop
    pop ebx                                 ; pop bc
    pop edx                                 ; pop de
    pop esi                                 ; pop hl
    ret
