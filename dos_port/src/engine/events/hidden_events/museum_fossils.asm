; museum_fossils.asm — Pewter Museum fossil display hidden-event handlers.
;
; Faithful translation of pret `engine/events/hidden_events/museum_fossils.asm`.
; AerodactylFossilText and KabutopsFossilText are plain text_far wrappers
; generated as Tier-1 data in assets/predef_text.inc.
;
; Register map: A=AL; GB memory at [EBP + addr].
;
; Build: nasm -f coff -I include/ -I . -D BUG_FIX_LEVEL=0 -o /dev/null \
;            src/engine/events/hidden_events/museum_fossils.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "predef.inc"
%include "assets/predef_text_ids.inc"

global AerodactylFossil
global KabutopsFossil

extern DisplayMonFrontSpriteInBox       ; src/engine/events/hidden_events/museum_fossils2.asm
extern EnableAutoTextBoxDrawing         ; src/home/window.asm
extern PrintPredefTextID                ; src/home/predef_text.asm

section .text

; ─────────────────────────────────────────────────────────────────────────────
; AerodactylFossil — pret engine/events/hidden_events/museum_fossils.asm:AerodactylFossil
; ─────────────────────────────────────────────────────────────────────────────
AerodactylFossil:
    mov al, FOSSIL_AERODACTYL
    mov [ebp + wCurPartySpecies], al
    call DisplayMonFrontSpriteInBox
    call EnableAutoTextBoxDrawing
    tx_pre AerodactylFossilText
    ret

; ─────────────────────────────────────────────────────────────────────────────
; KabutopsFossil — pret engine/events/hidden_events/museum_fossils.asm:KabutopsFossil
; ─────────────────────────────────────────────────────────────────────────────
KabutopsFossil:
    mov al, FOSSIL_KABUTOPS
    mov [ebp + wCurPartySpecies], al
    call DisplayMonFrontSpriteInBox
    call EnableAutoTextBoxDrawing
    tx_pre KabutopsFossilText
    ret
