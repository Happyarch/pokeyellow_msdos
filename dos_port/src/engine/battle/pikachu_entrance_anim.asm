; pikachu_entrance_anim.asm — the Yellow starter-Pikachu battle entrance.
; Faithful mirror of pret engine/battle/pikachu_entrance_anim.asm.
;
; SendOutMon uses this instead of the POOF_ANIM + AnimateSendingOutMon pair when the
; sent-out mon is the player's starter Pikachu. It slides the 7x7 back pic in one
; column at a time from the left edge of the player's slot, two frames per step.
;
; RETIRES the ret-only stub that stood in engine/battle/battle_stubs.asm, whose
; lifetime read "until the Yellow starter-Pikachu entrance is ported under
; battle_completion 4a" — 4a is ticked, but this routine was never part of it.
;
; ---------------------------------------------------------------------------
; TWO KINDS OF NUMBER HERE, and only one of them is projected.
;
; TILE IDS are stride-independent and stay verbatim: D walks the pic's ids, so
; `ld d, 7 * 13` (91) and `cp 7 * 7` (49) are id arithmetic, not geometry.
; .PlaceColumn writes ids D..D+6 down a column, and the compare goes the way that
; looks backwards at first: an id >= 49 is a REAL BACK-PIC TILE and is written, while
; anything BELOW 49 is replaced with $7F (blank). D starts at 91 and steps DOWN by 7
; per column, so the first passes are all real tiles and the trailing columns fall
; under 49 and come out blank — which is what makes the pic appear to slide in out of
; nothing. (The back pic lives at vBackPic tile $31 onward, i.e. ids 49-97; ids 0-48
; are the front-pic region.)
;
; GEOMETRY is projected: `hlcoord 0, 5` becomes BCOORD(0, 5) — the battle-frame
; projection every in-battle screen in this port uses — and `ld bc, SCREEN_WIDTH /
; add hl, bc` is a ROW STEP, so it takes the port's own stride. That is the
; SCREEN_WIDTH role split: as a row STRIDE each side uses its own value and the text
; is unchanged; only a SCREEN_WIDTH used as a COORDINATE needs re-deriving. Same
; treatment scroll_draw_trainer_pic.asm documents for the trainer pic.
; DEVIATION{class=projection; pret=engine/battle/pikachu_entrance_anim.asm:StarterPikachuBattleEntranceAnimation; behavior=the tilemap cursor is BCOORD(0, 5) on the port's 40x25 canvas and the column row-step is the canvas stride SCREEN_WIDTH=40 rather than the Game Boy's 20; evidence=every in-battle screen in this port is drawn through the BCOORD battle-frame projection in include/coords.inc which offsets pret hlcoords by +10 columns and +3 rows onto the wider canvas, and engine/battle/scroll_draw_trainer_pic.asm carries the identical annotation for the trainer-pic region; lifetime=permanent while the port renders a 40x25 canvas}
;
; COUNTER WIDTHS ARE PRET'S. `inc c` / `cp 9`, `dec c`, `dec e` are all 8-bit; the
; outer loop's exit is the `cp 9` on C, not a count, so it runs columns 1..8.
;
; NOT WITNESSED BY ANY GOLDEN: the branch needs the starter Pikachu as the sent-out
; party mon, and no scenario sends it out. battle_pikachu seeds a Pikachu BATTLE but
; enters through the harness's own scene builder.
;
; Register map (CLAUDE.md): A=AL, BC=BX (B=BH, C=BL), DE=EDX, HL=ESI, EBP = GB base.
;
; Build: nasm -f coff -I include/ -I . -o pikachu_entrance_anim.o pikachu_entrance_anim.asm

bits 32

%include "gb_memmap.inc"
%include "coords.inc"                   ; BCOORD — the battle-frame projection

extern DelayFrames                      ; src/home/delay.asm — BL = frame count

section .text

global StarterPikachuBattleEntranceAnimation
StarterPikachuBattleEntranceAnimation:
    mov esi, BCOORD(0, 5)               ; PROJ — pret hlcoord 0, 5
    mov bl, 0                           ; ld c, 0
.loop1:
    inc bl                              ; inc c
    mov al, bl
    cmp al, 9
    je .done                            ; ret z — eight columns done
    mov dh, 7 * 13                      ; ld d, 7 * 13 — first tile id of this pass
    push ebx                            ; push bc
    push esi                            ; push hl
.loop2:
    call .PlaceColumn
    dec esi                             ; dec hl — step one column left
    mov al, dh                          ; ld a, d
    sub al, 7                           ; sub 7 — previous column's ids
    mov dh, al                          ; ld d, a
    dec bl                              ; dec c
    jnz .loop2
    mov bl, 2                           ; ld c, 2
    call DelayFrames
    pop esi                             ; pop hl
    pop ebx                             ; pop bc
    inc esi                             ; inc hl — the pic grows one column right
    jmp .loop1
.done:
    ret

; --- .PlaceColumn — write tile ids DH..DH+6 down one column, blanking any id past
;     the end of the 7x7 pic. Preserves ESI/EDX/EBX, as pret preserves hl/de/bc.
.PlaceColumn:
    push esi                            ; push hl
    push edx                            ; push de
    push ebx                            ; push bc
    mov dl, 7                           ; ld e, 7 — seven rows
.loop3:
    mov al, dh                          ; ld a, d
    cmp al, 7 * 7
    jae .okay                           ; jr nc — id >= 49 IS a back-pic tile: write it
    mov al, 0x7F                        ; ld a, $7f — below 49: blank this cell
.okay:
    mov [ebp + esi], al                 ; ld [hl], a
    add esi, SCREEN_WIDTH               ; ld bc, SCREEN_WIDTH / add hl, bc — ROW STEP
    inc dh                              ; inc d
    dec dl                              ; dec e
    jnz .loop3
    pop ebx                             ; pop bc
    pop edx                             ; pop de
    pop esi                             ; pop hl
    ret
