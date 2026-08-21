; bench_guys.asm — Pokecenter bench guys hidden-event handlers.
;
; Faithful translation of pret `engine/events/hidden_events/bench_guys.asm`.
;
; Routines:
;   PrintBenchGuyText: lookup current map in BenchGuyTextPointers, check player
;     facing direction (SPRITE_FACING_LEFT), and print the predef text ID.
;   SaffronCityPokecenterBenchGuyText: text_asm script branching on
;     EVENT_BEAT_SILPH_CO_GIOVANNI to select text 1 or 2.
;
; Text streams & table:
;   ViridianCityPokecenterBenchGuyText, PewterCityPokecenterBenchGuyText, ... (14 predefs)
;     are Tier-1 predef text data generated into assets/predef_text.inc.
;   SaffronCityPokecenterBenchGuyText1, SaffronCityPokecenterBenchGuyText2, and
;     BenchGuyTextPointers are Tier-1 data generated into assets/bench_guys_text.inc.
;
; Register map:
;   A = AL, B = BH, C = BL, HL = ESI; GB memory at [EBP + addr].
;
; Build: nasm -f coff -I include/ -I . -D BUG_FIX_LEVEL=0 -o bench_guys.o \
;            src/engine/events/hidden_events/bench_guys.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "events.inc"
%include "assets/event_constants.inc"
%include "assets/map_dims.inc"
%include "assets/predef_text_ids.inc"

section .text

extern EnableAutoTextBoxDrawing         ; src/home/window.asm
extern PrintPredefTextID                ; src/home/predef_text.asm
extern PrintText                        ; src/home/window.asm
extern TextScriptEnd                    ; src/home/overworld_text.asm

; ─────────────────────────────────────────────────────────────────────────────
; PrintBenchGuyText — pret engine/events/hidden_events/bench_guys.asm:PrintBenchGuyText.
; ─────────────────────────────────────────────────────────────────────────────
global PrintBenchGuyText
PrintBenchGuyText:
    call EnableAutoTextBoxDrawing
    mov esi, BenchGuyTextPointers
    mov al, [ebp + wCurMap]
    mov bh, al
.loop:
    mov al, [esi]
    inc esi
    cmp al, 0xFF
    je .done
    cmp al, bh
    je .match
    inc esi
    inc esi
    jmp .loop
.match:
    mov al, [esi]
    inc esi
    mov bh, al
    mov al, [ebp + wSpritePlayerStateData1FacingDirection]
    cmp al, bh
    ; bug: an 'inc hl' instruction is needed before looping back.
    ; Due to Yellow's new Pokecenter layout, it's now impossible to talk to a
    ; bench guy from above. The bug is still present but will not be triggered
    ; in a regular play.
    jne .loop                           ; player isn't facing the bench guy
    mov al, [esi]
    jmp PrintPredefTextID
.done:
    ret

; ─────────────────────────────────────────────────────────────────────────────
; SaffronCityPokecenterBenchGuyText — pret engine/events/hidden_events/bench_guys.asm:SaffronCityPokecenterBenchGuyText.
; ─────────────────────────────────────────────────────────────────────────────
global SaffronCityPokecenterBenchGuyText
SaffronCityPokecenterBenchGuyText:
    CheckEvent EVENT_BEAT_SILPH_CO_GIOVANNI
    mov esi, SaffronCityPokecenterBenchGuyText2
    jne .printText
    mov esi, SaffronCityPokecenterBenchGuyText1
.printText:
    call PrintText
    jmp TextScriptEnd

; %include the generated BenchGuyTextPointers table and Saffron texts
%include "assets/bench_guys_text.inc"
