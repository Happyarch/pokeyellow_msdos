; Route3.asm — translated from pret scripts/Route3.asm by dos_port/tools/sm83xlat.
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

global Route3CooltrainerF1Text
global Route3CooltrainerF2Text
global Route3CooltrainerF3Text
global Route3Youngster1Text
global Route3Youngster2Text
global Route3Youngster3Text
global Route3Youngster4Text
global Route3Youngster5Text
global Route3_Script

extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern Route3CooltrainerF1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route3CooltrainerF2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route3CooltrainerF3BattleText   ; NOT YET DEFINED IN THE PORT
extern Route3TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern Route3TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern Route3TrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern Route3TrainerHeader3   ; NOT YET DEFINED IN THE PORT
extern Route3TrainerHeader4   ; NOT YET DEFINED IN THE PORT
extern Route3TrainerHeader5   ; NOT YET DEFINED IN THE PORT
extern Route3TrainerHeader6   ; NOT YET DEFINED IN THE PORT
extern Route3TrainerHeader7   ; NOT YET DEFINED IN THE PORT
extern Route3TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern Route3Youngster1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route3Youngster2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route3Youngster3BattleText   ; NOT YET DEFINED IN THE PORT
extern Route3Youngster4BattleText   ; NOT YET DEFINED IN THE PORT
extern Route3Youngster5BattleText   ; NOT YET DEFINED IN THE PORT
extern Route3_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wRoute3CurScript                               equ 0xD5F7

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

Route3_Script:
    call EnableAutoTextBoxDrawing
    mov esi, Route3TrainerHeaders
    mov edi, Route3_ScriptPointers   ; pret: ld de, Route3_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wRoute3CurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wRoute3CurScript], al
    ret

; Route3_ScriptPointers (scripts/Route3.asm:11-51) — not re-emitted: Route3_ScriptPointers is already defined in assets/map_script_tables.inc.

Route3Youngster1Text:
    mov esi, Route3TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; Route3Youngster1BattleText (scripts/Route3.asm:60-69) — not re-emitted: Route3Youngster1BattleText is already defined in assets/trainer_headers.inc.

Route3Youngster2Text:
    mov esi, Route3TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

; Route3Youngster2BattleText (scripts/Route3.asm:78-87) — not re-emitted: Route3Youngster2BattleText is already defined in assets/trainer_headers.inc.

Route3CooltrainerF1Text:
    mov esi, Route3TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

; Route3CooltrainerF1BattleText (scripts/Route3.asm:96-105) — not re-emitted: Route3CooltrainerF1BattleText is already defined in assets/trainer_headers.inc.

Route3Youngster3Text:
    mov esi, Route3TrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

; Route3Youngster3BattleText (scripts/Route3.asm:114-123) — not re-emitted: Route3Youngster3BattleText is already defined in assets/trainer_headers.inc.

Route3CooltrainerF2Text:
    mov esi, Route3TrainerHeader4
    call TalkToTrainer
    jmp TextScriptEnd

; Route3CooltrainerF2BattleText (scripts/Route3.asm:132-141) — not re-emitted: Route3CooltrainerF2BattleText is already defined in assets/trainer_headers.inc.

Route3Youngster4Text:
    mov esi, Route3TrainerHeader5
    call TalkToTrainer
    jmp TextScriptEnd

; Route3Youngster4BattleText (scripts/Route3.asm:150-159) — not re-emitted: Route3Youngster4BattleText is already defined in assets/trainer_headers.inc.

Route3Youngster5Text:
    mov esi, Route3TrainerHeader6
    call TalkToTrainer
    jmp TextScriptEnd

; Route3Youngster5BattleText (scripts/Route3.asm:168-177) — not re-emitted: Route3Youngster5BattleText is already defined in assets/trainer_headers.inc.

Route3CooltrainerF3Text:
    mov esi, Route3TrainerHeader7
    call TalkToTrainer
    jmp TextScriptEnd

; Route3CooltrainerF3BattleText (scripts/Route3.asm:186-199) — not re-emitted: Route3CooltrainerF3BattleText is already defined in assets/trainer_headers.inc.
