; Route13.asm — translated from pret scripts/Route13.asm by dos_port/tools/sm83xlat.
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

global Route13Beauty1Text
global Route13Beauty2Text
global Route13BikerText
global Route13CooltrainerF1Text
global Route13CooltrainerF2Text
global Route13CooltrainerF3Text
global Route13CooltrainerF4Text
global Route13CooltrainerM1Text
global Route13CooltrainerM2Text
global Route13CooltrainerM3Text
global Route13_Script

extern EnableAutoTextBoxDrawing
extern ExecuteCurMapScriptInTable
extern Route13Beauty1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route13Beauty2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route13BikerBattleText   ; NOT YET DEFINED IN THE PORT
extern Route13CooltrainerF1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route13CooltrainerF2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route13CooltrainerF3BattleText   ; NOT YET DEFINED IN THE PORT
extern Route13CooltrainerF4BattleText   ; NOT YET DEFINED IN THE PORT
extern Route13CooltrainerM1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route13CooltrainerM2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route13CooltrainerM3BattleText   ; NOT YET DEFINED IN THE PORT
extern Route13TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern Route13TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern Route13TrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern Route13TrainerHeader3   ; NOT YET DEFINED IN THE PORT
extern Route13TrainerHeader4   ; NOT YET DEFINED IN THE PORT
extern Route13TrainerHeader5   ; NOT YET DEFINED IN THE PORT
extern Route13TrainerHeader6   ; NOT YET DEFINED IN THE PORT
extern Route13TrainerHeader7   ; NOT YET DEFINED IN THE PORT
extern Route13TrainerHeader8   ; NOT YET DEFINED IN THE PORT
extern Route13TrainerHeader9   ; NOT YET DEFINED IN THE PORT
extern Route13TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern Route13_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer
extern TextScriptEnd

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wRoute13CurScript                              equ 0xD619

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
Route13_Script:
    call EnableAutoTextBoxDrawing
    mov esi, Route13TrainerHeaders
    mov edi, Route13_ScriptPointers   ; pret: ld de, Route13_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wRoute13CurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wRoute13CurScript], al
    ret

; Route13_ScriptPointers (scripts/Route13.asm:11-54) — not re-emitted: Route13_ScriptPointers is already defined in assets/map_script_tables.inc.

%assign event_byte -1
%assign event_byte_a -1
Route13CooltrainerM1Text:
    mov esi, Route13TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; Route13CooltrainerM1BattleText (scripts/Route13.asm:63-72) — not re-emitted: Route13CooltrainerM1BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route13CooltrainerF1Text:
    mov esi, Route13TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

; Route13CooltrainerF1BattleText (scripts/Route13.asm:81-90) — not re-emitted: Route13CooltrainerF1BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route13CooltrainerF2Text:
    mov esi, Route13TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

; Route13CooltrainerF2BattleText (scripts/Route13.asm:99-108) — not re-emitted: Route13CooltrainerF2BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route13CooltrainerF3Text:
    mov esi, Route13TrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

; Route13CooltrainerF3BattleText (scripts/Route13.asm:117-126) — not re-emitted: Route13CooltrainerF3BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route13CooltrainerF4Text:
    mov esi, Route13TrainerHeader4
    call TalkToTrainer
    jmp TextScriptEnd

; Route13CooltrainerF4BattleText (scripts/Route13.asm:135-144) — not re-emitted: Route13CooltrainerF4BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route13CooltrainerM2Text:
    mov esi, Route13TrainerHeader5
    call TalkToTrainer
    jmp TextScriptEnd

; Route13CooltrainerM2BattleText (scripts/Route13.asm:153-162) — not re-emitted: Route13CooltrainerM2BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route13Beauty1Text:
    mov esi, Route13TrainerHeader6
    call TalkToTrainer
    jmp TextScriptEnd

; Route13Beauty1BattleText (scripts/Route13.asm:171-180) — not re-emitted: Route13Beauty1BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route13Beauty2Text:
    mov esi, Route13TrainerHeader7
    call TalkToTrainer
    jmp TextScriptEnd

; Route13Beauty2BattleText (scripts/Route13.asm:189-198) — not re-emitted: Route13Beauty2BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route13BikerText:
    mov esi, Route13TrainerHeader8
    call TalkToTrainer
    jmp TextScriptEnd

; Route13BikerBattleText (scripts/Route13.asm:207-216) — not re-emitted: Route13BikerBattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route13CooltrainerM3Text:
    mov esi, Route13TrainerHeader9
    call TalkToTrainer
    jmp TextScriptEnd

; Route13CooltrainerM3BattleText (scripts/Route13.asm:225-246) — not re-emitted: Route13CooltrainerM3BattleText is already defined in assets/trainer_headers.inc.
