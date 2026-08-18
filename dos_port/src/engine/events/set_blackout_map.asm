; set_blackout_map.asm — pret engine/events/set_blackout_map.asm
;
; Set the map to return to when blacking out or using Teleport or Dig.
; Safari rest houses don't count.
;
; Register map: A->AL, B->BH, C->BL, D->DH, E->DL, HL->ESI, EBP = GB memory base.

bits 32

%include "gb_memmap.inc"

%ifndef wLastBlackoutMap
wLastBlackoutMap equ 0xD718
%endif

section .text

global SetLastBlackoutMap

extern SafariZoneRestHouses ; data/maps/rest_house_maps.asm

SetLastBlackoutMap:
    push esi
    mov esi, SafariZoneRestHouses
    mov bh, [ebp + wCurMap]             ; ld a, [wCurMap] / ld b, a
.loop:
    mov al, [esi]                       ; ld a, [hli]
    inc esi
    cmp al, 0xFF                        ; cp -1
    je .notresthouse                    ; jr z, .notresthouse
    cmp al, bh                          ; cp b
    jne .loop                           ; jr nz, .loop
    jmp .done                           ; jr .done

.notresthouse:
    mov al, [ebp + wLastMap]            ; ld a, [wLastMap]
    mov [ebp + wLastBlackoutMap], al    ; ld [wLastBlackoutMap], a
.done:
    pop esi
    ret
