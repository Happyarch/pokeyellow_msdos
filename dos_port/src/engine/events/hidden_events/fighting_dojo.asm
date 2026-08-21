; fighting_dojo.asm — Fighting Dojo hidden-event handlers.
;
; Faithful translation of pret `engine/events/hidden_events/fighting_dojo.asm`.
; Only the PrintFightingDojoText* handlers are ported here:
;   * EnemiesOnEverySideText, WhatGoesAroundComesAroundText, FightingDojoText are
;     plain `text_far` wrappers, so they are Tier-1 DATA and are generated into
;     assets/predef_text.inc (via tools/generators/gen_predef_text.py), dispatched
;     through TextPredefs (src/data/text_predef_pointers.asm, ids $39, $3A, $38).
;
; Register map: A=AL; GB memory at [EBP + addr].
;
; Build: nasm -f coff -I include/ -I . -o fighting_dojo.o \
;            src/engine/events/hidden_events/fighting_dojo.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "predef.inc"                   ; tx_pre_id
%include "assets/predef_text_ids.inc"    ; EnemiesOnEverySideText_id, ...

global PrintFightingDojoText2
global PrintFightingDojoText3
global PrintFightingDojoText

extern EnableAutoTextBoxDrawing         ; src/home/window.asm
extern PrintPredefTextID                ; src/home/predef_text.asm

section .text

; ─────────────────────────────────────────────────────────────────────────────
; PrintFightingDojoText2 — pret engine/events/hidden_events/fighting_dojo.asm:PrintFightingDojoText2
; ─────────────────────────────────────────────────────────────────────────────
PrintFightingDojoText2:
    call EnableAutoTextBoxDrawing
    tx_pre_id EnemiesOnEverySideText
    jmp PrintPredefTextID

; ─────────────────────────────────────────────────────────────────────────────
; PrintFightingDojoText3 — pret engine/events/hidden_events/fighting_dojo.asm:PrintFightingDojoText3
; ─────────────────────────────────────────────────────────────────────────────
PrintFightingDojoText3:
    call EnableAutoTextBoxDrawing
    tx_pre_id WhatGoesAroundComesAroundText
    jmp PrintPredefTextID

; ─────────────────────────────────────────────────────────────────────────────
; PrintFightingDojoText — pret engine/events/hidden_events/fighting_dojo.asm:PrintFightingDojoText
; ─────────────────────────────────────────────────────────────────────────────
PrintFightingDojoText:
    call EnableAutoTextBoxDrawing
    tx_pre_id FightingDojoText
    jmp PrintPredefTextID
