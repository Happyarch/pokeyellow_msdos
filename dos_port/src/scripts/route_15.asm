; Route15.asm — translated from pret scripts/Route15.asm by dos_port/tools/sm83xlat.
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

global Route15Beauty1Text
global Route15Beauty2Text
global Route15Biker1Text
global Route15Biker2Text
global Route15CooltrainerF1Text
global Route15CooltrainerF2Text
global Route15CooltrainerF3Text
global Route15CooltrainerF4Text
global Route15CooltrainerM1Text
global Route15CooltrainerM2Text
global Route15TalkToTrainer
global Route15_Script

extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern Route15CooltrainerF1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route15TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern Route15TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern Route15TrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern Route15TrainerHeader3   ; NOT YET DEFINED IN THE PORT
extern Route15TrainerHeader4   ; NOT YET DEFINED IN THE PORT
extern Route15TrainerHeader5   ; NOT YET DEFINED IN THE PORT
extern Route15TrainerHeader6   ; NOT YET DEFINED IN THE PORT
extern Route15TrainerHeader7   ; NOT YET DEFINED IN THE PORT
extern Route15TrainerHeader8   ; NOT YET DEFINED IN THE PORT
extern Route15TrainerHeader9   ; NOT YET DEFINED IN THE PORT
extern Route15TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern Route15_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wRoute15CurScript                              equ 0xD624

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
Route15_Script:
    call EnableAutoTextBoxDrawing
    mov esi, Route15TrainerHeaders
    mov edi, Route15_ScriptPointers   ; pret: ld de, Route15_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wRoute15CurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wRoute15CurScript], al
    ret

; Route15_ScriptPointers (scripts/Route15.asm:11-53) — not re-emitted: Route15_ScriptPointers is already defined in assets/map_script_tables.inc.

%assign event_byte -1
Route15CooltrainerF1Text:
    mov esi, Route15TrainerHeader0
    jmp Route15TalkToTrainer

%assign event_byte -1
Route15CooltrainerF2Text:
    mov esi, Route15TrainerHeader1
    jmp Route15TalkToTrainer

%assign event_byte -1
Route15CooltrainerM1Text:
    mov esi, Route15TrainerHeader2
    jmp Route15TalkToTrainer

%assign event_byte -1
Route15CooltrainerM2Text:
    mov esi, Route15TrainerHeader3
    jmp Route15TalkToTrainer

%assign event_byte -1
Route15Beauty1Text:
    mov esi, Route15TrainerHeader4
    jmp Route15TalkToTrainer

%assign event_byte -1
Route15Beauty2Text:
    mov esi, Route15TrainerHeader5
    jmp Route15TalkToTrainer

%assign event_byte -1
Route15Biker1Text:
    mov esi, Route15TrainerHeader6
    jmp Route15TalkToTrainer

%assign event_byte -1
Route15Biker2Text:
    mov esi, Route15TrainerHeader7
    jmp Route15TalkToTrainer

%assign event_byte -1
Route15CooltrainerF3Text:
    mov esi, Route15TrainerHeader8
    jmp Route15TalkToTrainer

%assign event_byte -1
Route15CooltrainerF4Text:
    mov esi, Route15TrainerHeader9
Route15TalkToTrainer:
    call TalkToTrainer
    jmp TextScriptEnd

; Route15CooltrainerF1BattleText (scripts/Route15.asm:108-229) — not re-emitted: Route15CooltrainerF1BattleText is already defined in assets/trainer_headers.inc.
