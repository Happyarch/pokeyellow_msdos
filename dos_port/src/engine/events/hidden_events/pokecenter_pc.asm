; pokecenter_pc.asm — Pokémon Center PC hidden-event handler.
;
; Faithful translation of pret `engine/events/hidden_events/pokecenter_pc.asm`.
; Both pret labels land here, retiring their ret-stubs:
;   OpenPokemonCenterPC — was in src/engine/overworld/hidden_object_stubs.asm.
;   PokemonCenterPCText — was in
;                         src/engine/events/hidden_events/hidden_events_stubs.asm.
;
; PokemonCenterPCText is a predef_code TextPredefs row ($21,
; src/data/text_predef_pointers.asm) — DisplayTextID's TEXT_PREDEF branch does a
; bare `call esi` straight at this label (TEXT_ASM_ENTRY sentinel), so the label
; must be x86 CODE at offset 0. pret opens it with the one-byte
; `script_pokecenter_pc` marker ($F9, TX_SCRIPT_POKECENTER_PC); dropping that byte
; is not a behavior change — DisplayTextID's ordinary byte-stream dict path
; (src/home/text_script.asm) dispatches that exact byte to
; TextScript_PokemonCenterPC (src/home/map_objects.asm, already linked: a jump
; into ActivatePC -> BankswitchAndContinue -> jp HoldTextDisplayOpen, matching
; pret's TextScript_PokemonCenterPC). Calling that same routine directly
; reproduces the identical continuation. Same pattern as CinnabarGymQuiz
; (src/engine/events/hidden_events/cinnabar_gym_quiz.asm) dropping its text_asm
; byte.
;
; Register map: A=AL; GB memory at [EBP + addr].
;
; Build: nasm -f coff -I include/ -I . -D BUG_FIX_LEVEL=0 -o /dev/null \
;            src/engine/events/hidden_events/pokecenter_pc.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "predef.inc"                   ; tx_pre_id
%include "assets/predef_text_ids.inc"   ; PokemonCenterPCText_id

section .text

global OpenPokemonCenterPC
global PokemonCenterPCText

extern EnableAutoTextBoxDrawing         ; src/home/window.asm
extern PrintPredefTextID                ; src/home/predef_text.asm
extern TextScript_PokemonCenterPC       ; src/home/map_objects.asm (linked)

; ─────────────────────────────────────────────────────────────────────────────
; OpenPokemonCenterPC — pret engine/events/hidden_events/pokecenter_pc.asm:OpenPokemonCenterPC.
; Only fires facing up. Suppresses the normal auto-text-box border (the PC's own
; UI draws its own box) and tail-jumps into the predef dispatch.
; ─────────────────────────────────────────────────────────────────────────────
OpenPokemonCenterPC:
    mov al, [ebp + wSpritePlayerStateData1FacingDirection]
    cmp al, SPRITE_FACING_UP
    jne .notFacingUp
    call EnableAutoTextBoxDrawing
    mov byte [ebp + wAutoTextBoxDrawingControl], (1 << BIT_NO_AUTO_TEXT_BOX)
    ; pret: `tx_pre_jump PokemonCenterPCText`, spelled out (see include/predef.inc
    ; — a jump-out macro at a routine tail defeats the build-graph scanner).
    tx_pre_id PokemonCenterPCText
    jmp PrintPredefTextID
.notFacingUp:
    ret

; ─────────────────────────────────────────────────────────────────────────────
; PokemonCenterPCText — pret engine/events/hidden_events/pokecenter_pc.asm:PokemonCenterPCText.
; See file header for why this label carries no leading text_asm/script byte.
; ─────────────────────────────────────────────────────────────────────────────
PokemonCenterPCText:
    jmp TextScript_PokemonCenterPC
