; Route20.asm — translated from pret scripts/Route20.asm by dos_port/tools/sm83xlat.
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
%include "assets/script_constants.inc"

%include "assets/trainer_headers.inc"

global Route20BoulderScript
global Route20CooltrainerMText
global Route20HideObjectScript
global Route20ShowObjectScript
global Route20Swimmer1Text
global Route20Swimmer2Text
global Route20Swimmer3Text
global Route20Swimmer4Text
global Route20Swimmer5Text
global Route20Swimmer6Text
global Route20Swimmer7Text
global Route20Swimmer8Text
global Route20Swimmer9Text
global Route20_Script

extern EnableAutoTextBoxDrawing
extern ExecuteCurMapScriptInTable
extern HideObject
extern Route20Swimmer1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route20TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern Route20TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern Route20TrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern Route20TrainerHeader3   ; NOT YET DEFINED IN THE PORT
extern Route20TrainerHeader4   ; NOT YET DEFINED IN THE PORT
extern Route20TrainerHeader5   ; NOT YET DEFINED IN THE PORT
extern Route20TrainerHeader6   ; NOT YET DEFINED IN THE PORT
extern Route20TrainerHeader7   ; NOT YET DEFINED IN THE PORT
extern Route20TrainerHeader8   ; NOT YET DEFINED IN THE PORT
extern Route20TrainerHeader9   ; NOT YET DEFINED IN THE PORT
extern Route20TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern Route20_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern ShowObject
extern TalkToTrainer
extern TextScriptEnd

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wRoute20CurScript                              equ 0xD627

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
Route20_Script:
    CheckAndResetEvent EVENT_IN_SEAFOAM_ISLANDS
    jz .sk_3
        call Route20BoulderScript
.sk_3:
    call EnableAutoTextBoxDrawing
    mov esi, Route20TrainerHeaders
    mov edi, Route20_ScriptPointers   ; pret: ld de, Route20_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wRoute20CurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wRoute20CurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
Route20BoulderScript:
    CheckBothEventsSet EVENT_SEAFOAM3_BOULDER1_DOWN_HOLE, EVENT_SEAFOAM3_BOULDER2_DOWN_HOLE
    jz .next_boulder_check
    mov al, TOGGLE_SEAFOAM_ISLANDS_1F_BOULDER_1
    call Route20ShowObjectScript
    mov al, TOGGLE_SEAFOAM_ISLANDS_1F_BOULDER_2
    call Route20ShowObjectScript
    mov esi, .ToggleableObjectIDs
.hide_toggleable_objects:
    mov al, [esi]
    lea esi, [esi+1]
    cmp al, 0xff
    jz .next_boulder_check
    push esi
    call Route20HideObjectScript
    pop esi
    jmp .hide_toggleable_objects

%assign event_byte -1
%assign event_byte_a -1
.ToggleableObjectIDs:
    db TOGGLE_SEAFOAM_ISLANDS_B1F_BOULDER_1
    db TOGGLE_SEAFOAM_ISLANDS_B1F_BOULDER_2
    db TOGGLE_SEAFOAM_ISLANDS_B2F_BOULDER_1
    db TOGGLE_SEAFOAM_ISLANDS_B2F_BOULDER_2
    db TOGGLE_SEAFOAM_ISLANDS_B3F_BOULDER_3
    db TOGGLE_SEAFOAM_ISLANDS_B3F_BOULDER_4
    db -1

%assign event_byte -1
%assign event_byte_a -1
.next_boulder_check:
    CheckBothEventsSet EVENT_SEAFOAM4_BOULDER1_DOWN_HOLE, EVENT_SEAFOAM4_BOULDER2_DOWN_HOLE
    jnz .nr_40
        ret
.nr_40:
    mov al, TOGGLE_SEAFOAM_ISLANDS_B3F_BOULDER_1
    call Route20ShowObjectScript
    mov al, TOGGLE_SEAFOAM_ISLANDS_B3F_BOULDER_2
    call Route20ShowObjectScript
    mov al, TOGGLE_SEAFOAM_ISLANDS_B4F_BOULDER_1
    call Route20HideObjectScript
    mov al, TOGGLE_SEAFOAM_ISLANDS_B4F_BOULDER_2
    call Route20HideObjectScript
    ret

%assign event_byte -1
%assign event_byte_a -1
Route20ShowObjectScript:
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef_jump; behavior=Predef dispatch replaced by a direct jmp, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    jmp ShowObject

%assign event_byte -1
%assign event_byte_a -1
Route20HideObjectScript:
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef_jump; behavior=Predef dispatch replaced by a direct jmp, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    jmp HideObject

; Route20_ScriptPointers (scripts/Route20.asm:60-102) — not re-emitted: Route20TrainerHeaders is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route20Swimmer1Text:
    mov esi, Route20TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
Route20Swimmer2Text:
    mov esi, Route20TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
Route20Swimmer3Text:
    mov esi, Route20TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
Route20Swimmer4Text:
    mov esi, Route20TrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
Route20Swimmer5Text:
    mov esi, Route20TrainerHeader4
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
Route20Swimmer6Text:
    mov esi, Route20TrainerHeader5
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
Route20CooltrainerMText:
    mov esi, Route20TrainerHeader6
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
Route20Swimmer7Text:
    mov esi, Route20TrainerHeader7
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
Route20Swimmer8Text:
    mov esi, Route20TrainerHeader8
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
Route20Swimmer9Text:
    mov esi, Route20TrainerHeader9
    call TalkToTrainer
    jmp TextScriptEnd

; Route20Swimmer1BattleText (scripts/Route20.asm:165-286) — not re-emitted: Route20Swimmer1BattleText is already defined in assets/trainer_headers.inc.
