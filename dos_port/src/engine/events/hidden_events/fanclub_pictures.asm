; fanclub_pictures.asm — Pokémon Fan Club picture hidden-event handlers.
;
; Faithful translation of pret `engine/events/hidden_events/fanclub_pictures.asm`.
; FanClubPicture1Text and FanClubPicture2Text are plain text_far wrappers
; generated as Tier-1 data in assets/predef_text.inc.
;
; Register map: A=AL; GB memory at [EBP + addr].
;
; Build: nasm -f coff -I include/ -I . -D BUG_FIX_LEVEL=0 -o /dev/null \
;            src/engine/events/hidden_events/fanclub_pictures.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "predef.inc"
%include "assets/script_constants.inc"
%include "assets/predef_text_ids.inc"

global FanClubPicture1
global FanClubPicture2

extern DisplayMonFrontSpriteInBox       ; src/engine/events/hidden_events/museum_fossils2.asm
extern EnableAutoTextBoxDrawing         ; src/home/window.asm
extern PrintPredefTextID                ; src/home/predef_text.asm

section .text

; ─────────────────────────────────────────────────────────────────────────────
; FanClubPicture1 — pret engine/events/hidden_events/fanclub_pictures.asm:FanClubPicture1
; ─────────────────────────────────────────────────────────────────────────────
FanClubPicture1:
    mov al, RAPIDASH
    mov [ebp + wCurPartySpecies], al
    call DisplayMonFrontSpriteInBox
    call EnableAutoTextBoxDrawing
    tx_pre FanClubPicture1Text
    ret

; ─────────────────────────────────────────────────────────────────────────────
; FanClubPicture2 — pret engine/events/hidden_events/fanclub_pictures.asm:FanClubPicture2
; ─────────────────────────────────────────────────────────────────────────────
FanClubPicture2:
    mov al, FEAROW
    mov [ebp + wCurPartySpecies], al
    call DisplayMonFrontSpriteInBox
    call EnableAutoTextBoxDrawing
    tx_pre FanClubPicture2Text
    ret
