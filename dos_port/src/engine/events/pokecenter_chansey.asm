; ===========================================================================
; pokecenter_chansey.asm — pret mirror of engine/events/pokecenter_chansey.asm.
;
; The Chansey standing beside the nurse in every Pokemon Center: print its line,
; then play the CHANSEY cry and wait for it to finish. Twelve map scripts extern
; PokecenterChanseyText, which is why this small routine unblocks so many.
;
; TWO-TIER RULE (CLAUDE.md): the message itself is Tier-1 DATA and is NOT written
; here — gen_overworld_strings.py owns it (POKECENTER_CHANSEY_FAR ->
; assets/pokecenter_chansey_text.inc, %included below). This file is the Tier-2
; code: the print/cry/wait sequence, in pret's order.
;
; Register map (CLAUDE.md): A->AL, HL->ESI; GB memory = [ebp + SYM]. Text streams
; are FLAT .data pointers in the port, so NurseChanseyText goes into ESI directly.
; ===========================================================================

bits 32

%include "gb_memmap.inc"
%include "gb_text.inc"                  ; text_far / text_end wrappers
%include "assets/script_constants.inc"  ; CHANSEY

global PokecenterChanseyText

extern PrintText                        ; src/home/window.asm
extern PlayCry                          ; src/home/pokemon.asm (AL = species)
extern WaitForSoundToFinish             ; src/home/delay.asm

section .text

; ---------------------------------------------------------------------------
; PokecenterChanseyText — pret engine/events/pokecenter_chansey.asm.
;   ld hl, NurseChanseyText / call PrintText / ld a, CHANSEY / call PlayCry /
;   call WaitForSoundToFinish / ret
; ---------------------------------------------------------------------------
PokecenterChanseyText:
    mov esi, NurseChanseyText           ; ld hl, NurseChanseyText
    call PrintText
    mov al, CHANSEY                     ; ld a, CHANSEY
    call PlayCry
    call WaitForSoundToFinish
    ret

; ---------------------------------------------------------------------------
section .data

%include "assets/pokecenter_chansey_text.inc"

; pret's wrapper — `text_far _NurseChanseyText / text_end`.
NurseChanseyText:
    text_far _NurseChanseyText
    text_end
