; oaks_lab_posters.asm — Oak's Lab poster hidden-event handlers.
;
; Faithful translation of pret `engine/events/hidden_events/oaks_lab_posters.asm`.
; PushStartText, SaveOptionText, StrengthsAndWeaknessesText are plain text_far
; wrappers and are generated as Tier-1 data in assets/predef_text.inc.
;
; Register map: A=AL, B=BH, HL=ESI; GB memory at [EBP + addr].
;
; Build: nasm -f coff -I include/ -I . -D BUG_FIX_LEVEL=0 -o /dev/null \
;            src/engine/events/hidden_events/oaks_lab_posters.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "predef.inc"
%include "assets/predef_text_ids.inc"

global DisplayOakLabLeftPoster
global DisplayOakLabRightPoster

extern EnableAutoTextBoxDrawing         ; src/home/window.asm
extern CountSetBits                     ; src/home/count_set_bits.asm
extern PrintPredefTextID                ; src/home/predef_text.asm

section .text

; ─────────────────────────────────────────────────────────────────────────────
; DisplayOakLabLeftPoster — pret engine/events/hidden_events/oaks_lab_posters.asm:DisplayOakLabLeftPoster
; ─────────────────────────────────────────────────────────────────────────────
DisplayOakLabLeftPoster:
    call EnableAutoTextBoxDrawing
    tx_pre_id PushStartText
    jmp PrintPredefTextID

; ─────────────────────────────────────────────────────────────────────────────
; DisplayOakLabRightPoster — pret engine/events/hidden_events/oaks_lab_posters.asm:DisplayOakLabRightPoster
; ─────────────────────────────────────────────────────────────────────────────
DisplayOakLabRightPoster:
    call EnableAutoTextBoxDrawing
    mov esi, wPokedexOwned
    mov bh, wPokedexOwnedEnd - wPokedexOwned
    call CountSetBits
    mov al, [ebp + wNumSetBits]
    cmp al, 2
    tx_pre_id SaveOptionText
    jb .ownLessThanTwo
    ; own two or more mon
    tx_pre_id StrengthsAndWeaknessesText
.ownLessThanTwo:
    jmp PrintPredefTextID
