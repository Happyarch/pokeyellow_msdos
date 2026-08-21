; gym_statues.asm — Gym statues hidden-event handler.
;
; Faithful translation of pret `engine/events/hidden_events/gym_statues.asm`.
; GymStatues checks if the player is facing up at a gym statue, finds the
; matching gym badge bit in MapBadgeFlags, and prints GymStatueText2 (if the
; badge is beaten) or GymStatueText1 (if not).
;
; Register map: A=AL, B=BH, C=BL, HL=ESI; GB memory at [EBP + addr].
;
; TEXT STRINGS & TABLES ARE DATA:
; GymStatueText1 and GymStatueText2 are generated into assets/predef_text.inc
; via tools/generators/gen_predef_text.py (dispatched through TextPredefs, ids $0E/$0F).
; MapBadgeFlags is generated into assets/badge_maps.inc via tools/generators/gen_badge_maps.py.
;
; Build: nasm -f coff -I include/ -I . -o gym_statues.o \
;            src/engine/events/hidden_events/gym_statues.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "predef.inc"                   ; tx_pre_id
%include "assets/predef_text_ids.inc"    ; GymStatueText1_id, GymStatueText2_id
%include "assets/badge_maps.inc"         ; MapBadgeFlags

global GymStatues

extern EnableAutoTextBoxDrawing         ; src/home/window.asm
extern PrintPredefTextID                ; src/home/predef_text.asm

section .text

; ─────────────────────────────────────────────────────────────────────────────
; GymStatues — pret engine/events/hidden_events/gym_statues.asm:GymStatues
; ─────────────────────────────────────────────────────────────────────────────
GymStatues:
    call EnableAutoTextBoxDrawing
    mov al, [ebp + wSpritePlayerStateData1FacingDirection]
    cmp al, SPRITE_FACING_UP
    jne .notFacingUp
    mov esi, MapBadgeFlags
    mov bl, [ebp + wCurMap]             ; ld a, [wCurMap] / ld b, a
.loop:
    lodsb                               ; ld a, [hli]
    cmp al, 0xFF                        ; cp $ff
    je .notFacingUp                     ; ret z
    cmp al, bl                          ; cp b
    je .match                           ; jr z, .match
    inc esi                             ; inc hl
    jmp .loop
.match:
    mov bh, [esi]                       ; ld b, [hl]
    mov al, [ebp + wBeatGymFlags]
    and al, bh                          ; and b
    cmp al, bh                          ; cp b
    tx_pre_id GymStatueText2
    je .haveBadge                       ; jr z, .haveBadge
    tx_pre_id GymStatueText1
.haveBadge:
    jmp PrintPredefTextID
.notFacingUp:
    ret
