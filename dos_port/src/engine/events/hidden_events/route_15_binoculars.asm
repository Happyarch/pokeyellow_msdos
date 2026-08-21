; route_15_binoculars.asm — Route 15 gate binoculars hidden-event handler.
;
; Faithful translation of pret `engine/events/hidden_events/route_15_binoculars.asm`.
;
; Routines:
;   Route15GateLeftBinoculars: If player is facing up, enables auto text-box
;     drawing, displays predef text Route15UpstairsBinocularsText, plays
;     Articuno's cry, displays Articuno's front sprite in a popup box, and clears
;     hAutoBGTransferEnabled.
;
; Text streams:
;   Route15UpstairsBinocularsText: Tier-1 predef text data generated into
;     assets/predef_text.inc.
;
; Register map:
;   A = AL; GB memory at [EBP + addr].
;
; Build: nasm -f coff -I include/ -I . -D BUG_FIX_LEVEL=0 -o route_15_binoculars.o \
;            src/engine/events/hidden_events/route_15_binoculars.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "predef.inc"
%include "assets/predef_text_ids.inc"

%ifndef ARTICUNO
%define ARTICUNO                        0x4A  ; constants/pokemon_constants.asm
%endif

section .text

extern EnableAutoTextBoxDrawing         ; src/home/window.asm
extern PrintPredefTextID                ; src/home/predef_text.asm
extern PlayCry                          ; src/home/pokemon.asm
extern DisplayMonFrontSpriteInBox       ; src/engine/events/hidden_events/museum_fossils2.asm

; ─────────────────────────────────────────────────────────────────────────────
; Route15GateLeftBinoculars — pret engine/events/hidden_events/route_15_binoculars.asm:Route15GateLeftBinoculars.
; ─────────────────────────────────────────────────────────────────────────────
global Route15GateLeftBinoculars
Route15GateLeftBinoculars:
    mov al, [ebp + wSpritePlayerStateData1FacingDirection]
    cmp al, SPRITE_FACING_UP
    jne .done
    call EnableAutoTextBoxDrawing
    tx_pre Route15UpstairsBinocularsText
    mov al, ARTICUNO
    mov [ebp + wCurPartySpecies], al
    call PlayCry
    call DisplayMonFrontSpriteInBox
    xor al, al
    mov [ebp + hAutoBGTransferEnabled], al
.done:
    ret
