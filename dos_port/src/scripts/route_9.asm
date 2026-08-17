; Route9.asm — translated from pret scripts/Route9.asm by dos_port/tools/sm83xlat.
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

global Route9AJText
global Route9CooltrainerF1Text
global Route9CooltrainerF2Text
global Route9CooltrainerM2Text
global Route9Hiker1Text
global Route9Hiker2Text
global Route9Hiker3Text
global Route9TalkToTrainer
global Route9Youngster1Text
global Route9Youngster2Text
global Route9_Script

extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern Route9CooltrainerF1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route9TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern Route9TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern Route9TrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern Route9TrainerHeader3   ; NOT YET DEFINED IN THE PORT
extern Route9TrainerHeader4   ; NOT YET DEFINED IN THE PORT
extern Route9TrainerHeader5   ; NOT YET DEFINED IN THE PORT
extern Route9TrainerHeader6   ; NOT YET DEFINED IN THE PORT
extern Route9TrainerHeader7   ; NOT YET DEFINED IN THE PORT
extern Route9TrainerHeader8   ; NOT YET DEFINED IN THE PORT
extern Route9TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern Route9_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wRoute9CurScript                               equ 0xD603

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
Route9_Script:
    call EnableAutoTextBoxDrawing
    mov esi, Route9TrainerHeaders
    mov edi, Route9_ScriptPointers   ; pret: ld de, Route9_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wRoute9CurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wRoute9CurScript], al
    ret

; Route9_ScriptPointers (scripts/Route9.asm:11-50) — not re-emitted: Route9_ScriptPointers is already defined in assets/map_script_tables.inc.

%assign event_byte -1
Route9CooltrainerF1Text:
    mov esi, Route9TrainerHeader0
    jmp Route9TalkToTrainer

%assign event_byte -1
Route9AJText:
    mov esi, Route9TrainerHeader1
    jmp Route9TalkToTrainer

%assign event_byte -1
Route9CooltrainerM2Text:
    mov esi, Route9TrainerHeader2
    jmp Route9TalkToTrainer

%assign event_byte -1
Route9CooltrainerF2Text:
    mov esi, Route9TrainerHeader3
    jmp Route9TalkToTrainer

%assign event_byte -1
Route9Hiker1Text:
    mov esi, Route9TrainerHeader4
    jmp Route9TalkToTrainer

%assign event_byte -1
Route9Hiker2Text:
    mov esi, Route9TrainerHeader5
    jmp Route9TalkToTrainer

%assign event_byte -1
Route9Youngster1Text:
    mov esi, Route9TrainerHeader6
    jmp Route9TalkToTrainer

%assign event_byte -1
Route9Hiker3Text:
    mov esi, Route9TrainerHeader7
    jmp Route9TalkToTrainer

%assign event_byte -1
Route9Youngster2Text:
    mov esi, Route9TrainerHeader8
Route9TalkToTrainer:
    call TalkToTrainer
    jmp TextScriptEnd

; Route9CooltrainerF1BattleText (scripts/Route9.asm:100-209) — not re-emitted: Route9CooltrainerF1BattleText is already defined in assets/trainer_headers.inc.
