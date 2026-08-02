; reds_room.asm — Red's bedroom hidden-event handlers.
;
; Faithful translation of pret `engine/events/hidden_events/reds_room.asm`.
; Only PrintRedSNESText is ported here; OpenRedsPC and the two text entries it and
; PrintRedSNESText name are elsewhere:
;   * RedBedroomSNESText is a plain `text_far` wrapper, so it is Tier-1 DATA and is
;     generated into assets/predef_text.inc (via tools/generators/gen_predef_text.py).
;   * RedBedroomPCText is a `script_players_pc` marker with no port body yet — it
;     stands in at src/engine/events/hidden_events/hidden_events_stubs.asm.
;   * OpenRedsPC stays a ret-stub in src/engine/overworld/hidden_object_stubs.asm
;     until the PC service work lands; porting it here would only reach that stub.
;
; WHY THIS ONE ROUTINE, NOW: it is the cheapest REAL end-to-end path through the
; predef-text dispatch — press A at the SNES in Red's bedroom and the chain runs
; PrintRedSNESText -> PrintPredefTextID -> DisplayTextID's TEXT_PREDEF branch ->
; the flat TextPredefs row -> the generated RedBedroomSNESText stream. That is the
; must-hit acceptance the predef-text plan owes for editing DisplayTextID, and the
; bedroom is where every golden scenario already starts.
;
; Register map: A=AL; GB memory at [EBP + addr].
;
; Build: nasm -f coff -I include/ -I . -o reds_room.o \
;            src/engine/events/hidden_events/reds_room.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "predef.inc"                   ; tx_pre_id / tx_pre
%include "assets/predef_text_ids.inc"    ; the generated <Label>_id constants

section .text

extern EnableAutoTextBoxDrawing         ; src/home/window.asm
extern PrintPredefTextID                ; src/home/predef_text.asm

; ─────────────────────────────────────────────────────────────────────────────
; PrintRedSNESText — pret engine/events/hidden_events/reds_room.asm:PrintRedSNESText.
; The bedroom SNES. Enables auto text-box drawing, then tail-jumps into the predef
; dispatch with RedBedroomSNESText's id.
; ─────────────────────────────────────────────────────────────────────────────
global PrintRedSNESText
PrintRedSNESText:
    call EnableAutoTextBoxDrawing
    ; pret: `tx_pre_jump RedBedroomSNESText`, which is tx_pre_id + jp. Spelled out
    ; because a jump-out macro AT A ROUTINE TAIL defeats the build-graph scanner —
    ; see the note in include/predef.inc.
    tx_pre_id RedBedroomSNESText
    jmp PrintPredefTextID
