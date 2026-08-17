; Route18.asm — translated from pret scripts/Route18.asm by dos_port/tools/sm83xlat.
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

%include "assets/map_script_tables.inc"
%include "assets/trainer_headers.inc"

global Route18CooltrainerM1Text
global Route18CooltrainerM2Text
global Route18CooltrainerM3Text
global Route18_Script

extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern Route18CooltrainerM1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route18CooltrainerM2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route18CooltrainerM3BattleText   ; NOT YET DEFINED IN THE PORT
extern Route18TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern Route18TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern Route18TrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern Route18TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern Route18_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wRoute18CurScript                              equ 0xD626

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
Route18_Script:
    call EnableAutoTextBoxDrawing
    mov esi, Route18TrainerHeaders
    mov edi, Route18_ScriptPointers   ; pret: ld de, Route18_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wRoute18CurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wRoute18CurScript], al
    ret

; Route18_ScriptPointers (scripts/Route18.asm:11-32) — not re-emitted: Route18_ScriptPointers is already defined in assets/map_script_tables.inc.

%assign event_byte -1
Route18CooltrainerM1Text:
    mov esi, Route18TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; Route18CooltrainerM1BattleText (scripts/Route18.asm:41-50) — not re-emitted: Route18CooltrainerM1BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
Route18CooltrainerM2Text:
    mov esi, Route18TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

; Route18CooltrainerM2BattleText (scripts/Route18.asm:59-68) — not re-emitted: Route18CooltrainerM2BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
Route18CooltrainerM3Text:
    mov esi, Route18TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

; Route18CooltrainerM3BattleText (scripts/Route18.asm:77-94) — not re-emitted: Route18CooltrainerM3BattleText is already defined in assets/trainer_headers.inc.
