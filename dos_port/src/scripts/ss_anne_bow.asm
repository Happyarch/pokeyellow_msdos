; SSAnneBow.asm — translated from pret scripts/SSAnneBow.asm by dos_port/tools/sm83xlat.
;
; ONE-SHOT OUTPUT, NOW HAND-MAINTAINED. The transpiler ran once at the SHA
; recorded in dos_port/tools/sm83xlat/README.md and is not re-run; this file is
; ordinary Tier-2 source and editing it is the normal way it changes. There is
; deliberately no DO NOT EDIT header.
;
; Every pret label is preserved verbatim so the file stays line-for-line
; cross-referenceable against the disassembly.
;
; Regions the tool could not lower WITH CERTAINTY are reproduced below as
; commented pret source under a `; BAIL[reason]` banner, and define NO symbol —
; so a reference to one is a link error rather than a plausible wrong lowering.

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_text.inc"
%include "events.inc"
%include "assets/event_constants.inc"

%include "assets/trainer_headers.inc"

global SSAnneBowSailor2Text
global SSAnneBowSailor3Text
global SSAnneBow_Script

extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern SSAnne5TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern SSAnne5TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern SSAnne5TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern SSAnneBowSailor2BattleText   ; NOT YET DEFINED IN THE PORT
extern SSAnneBowSailor3BattleText   ; NOT YET DEFINED IN THE PORT
extern SSAnneBow_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wSSAnneBowCurScript                            equ 0xD616

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
SSAnneBow_Script:
    call EnableAutoTextBoxDrawing
    mov esi, SSAnne5TrainerHeaders
    mov edi, SSAnneBow_ScriptPointers   ; pret: ld de, SSAnneBow_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wSSAnneBowCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wSSAnneBowCurScript], al
    ret

; SSAnneBow_ScriptPointers (scripts/SSAnneBow.asm:11-42) — not re-emitted: SSAnne5TrainerHeaders is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
SSAnneBowSailor2Text:
    mov esi, SSAnne5TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; SSAnneBowSailor2BattleText (scripts/SSAnneBow.asm:51-60) — not re-emitted: SSAnneBowSailor2BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
SSAnneBowSailor3Text:
    mov esi, SSAnne5TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

; SSAnneBowSailor3BattleText (scripts/SSAnneBow.asm:69-78) — not re-emitted: SSAnneBowSailor3BattleText is already defined in assets/trainer_headers.inc.
