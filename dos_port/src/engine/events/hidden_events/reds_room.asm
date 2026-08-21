; reds_room.asm — Red's bedroom hidden-event handlers.
;
; Faithful translation of pret `engine/events/hidden_events/reds_room.asm`. All
; four pret labels are here now:
;   PrintRedSNESText / RedBedroomSNESText — ported 2026-08-02 (the predef-text
;     plan's first end-to-end acceptance path); unchanged by this pass.
;   OpenRedsPC — the item-storage PC's per-map hidden-event handler. Retires the
;     ret-stub in src/engine/overworld/hidden_object_stubs.asm.
;   RedBedroomPCText — its `script_players_pc` predef marker. Retires the
;     ret-stub in src/engine/events/hidden_events/hidden_events_stubs.asm.
;
; RedBedroomPCText is a predef_code TextPredefs row ($03,
; src/data/text_predef_pointers.asm) — DisplayTextID's TEXT_PREDEF branch does a
; bare `call esi` straight at this label (TEXT_ASM_ENTRY sentinel), so the label
; must be x86 CODE at offset 0, not pret's one-byte `script_players_pc` marker
; ($FC, TX_SCRIPT_PLAYERS_PC). Dropping that byte is not a behavior change:
; DisplayTextID's ordinary byte-stream dict path (src/home/text_script.asm)
; dispatches that exact byte to TextScript_ItemStoragePC (src/home/map_objects.asm,
; already linked: SaveScreenTilesToBuffer2 then a jump into PlayerPC ->
; BankswitchAndContinue -> jp HoldTextDisplayOpen, matching pret's
; TextScript_ItemStoragePC). Calling that same routine directly reproduces the
; identical continuation — same pattern as CinnabarGymQuiz
; (src/engine/events/hidden_events/cinnabar_gym_quiz.asm) dropping its text_asm
; byte, and PokemonCenterPCText
; (src/engine/events/hidden_events/pokecenter_pc.asm) doing the same for
; script_pokecenter_pc.
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
extern TextScript_ItemStoragePC         ; src/home/map_objects.asm (linked)

; ─────────────────────────────────────────────────────────────────────────────
; PrintRedSNESText — pret engine/events/hidden_events/reds_room.asm:PrintRedSNESText.
; The bedroom SNES. Enables auto text-box drawing, then tail-jumps into the predef
; dispatch with RedBedroomSNESText's id.
; ─────────────────────────────────────────────────────────────────────────────
global PrintRedSNESText
PrintRedSNESText:
    call EnableAutoTextBoxDrawing
    ; pret: `tx_pre_jump RedBedroomSNESText`, spelled out (see include/predef.inc —
    ; a jump-out macro at a routine tail defeats the build-graph scanner).
    tx_pre_id RedBedroomSNESText
    jmp PrintPredefTextID

; ─────────────────────────────────────────────────────────────────────────────
; OpenRedsPC — pret engine/events/hidden_events/reds_room.asm:OpenRedsPC.
; The bedroom item-storage PC's hidden-event handler. No facing check (unlike
; OpenPokemonCenterPC) — matches pret exactly.
; ─────────────────────────────────────────────────────────────────────────────
global OpenRedsPC
OpenRedsPC:
    call EnableAutoTextBoxDrawing
    ; pret: `tx_pre_jump RedBedroomPCText`, spelled out.
    tx_pre_id RedBedroomPCText
    jmp PrintPredefTextID

; ─────────────────────────────────────────────────────────────────────────────
; RedBedroomPCText — pret engine/events/hidden_events/reds_room.asm:RedBedroomPCText.
; See file header for why this label carries no leading text_asm/script byte.
; ─────────────────────────────────────────────────────────────────────────────
global RedBedroomPCText
RedBedroomPCText:
    jmp TextScript_ItemStoragePC
