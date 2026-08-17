; Route14.asm — translated from pret scripts/Route14.asm by dos_port/tools/sm83xlat.
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

global Route14Biker1Text
global Route14Biker2Text
global Route14Biker3Text
global Route14Biker4Text
global Route14CooltrainerM1Text
global Route14CooltrainerM2Text
global Route14CooltrainerM3Text
global Route14CooltrainerM4Text
global Route14CooltrainerM5Text
global Route14CooltrainerM6Text
global Route14_Script

extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern Route14Biker1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route14Biker2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route14Biker3BattleText   ; NOT YET DEFINED IN THE PORT
extern Route14Biker4BattleText   ; NOT YET DEFINED IN THE PORT
extern Route14CooltrainerM1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route14CooltrainerM2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route14CooltrainerM3BattleText   ; NOT YET DEFINED IN THE PORT
extern Route14CooltrainerM4BattleText   ; NOT YET DEFINED IN THE PORT
extern Route14CooltrainerM5BattleText   ; NOT YET DEFINED IN THE PORT
extern Route14CooltrainerM6BattleText   ; NOT YET DEFINED IN THE PORT
extern Route14TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern Route14TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern Route14TrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern Route14TrainerHeader3   ; NOT YET DEFINED IN THE PORT
extern Route14TrainerHeader4   ; NOT YET DEFINED IN THE PORT
extern Route14TrainerHeader5   ; NOT YET DEFINED IN THE PORT
extern Route14TrainerHeader6   ; NOT YET DEFINED IN THE PORT
extern Route14TrainerHeader7   ; NOT YET DEFINED IN THE PORT
extern Route14TrainerHeader8   ; NOT YET DEFINED IN THE PORT
extern Route14TrainerHeader9   ; NOT YET DEFINED IN THE PORT
extern Route14TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern Route14_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wRoute14CurScript                              equ 0xD61A

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
Route14_Script:
    call EnableAutoTextBoxDrawing
    mov esi, Route14TrainerHeaders
    mov edi, Route14_ScriptPointers   ; pret: ld de, Route14_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wRoute14CurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wRoute14CurScript], al
    ret

; Route14_ScriptPointers (scripts/Route14.asm:11-52) — not re-emitted: Route14_ScriptPointers is already defined in assets/map_script_tables.inc.

%assign event_byte -1
Route14CooltrainerM1Text:
    mov esi, Route14TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; Route14CooltrainerM1BattleText (scripts/Route14.asm:61-70) — not re-emitted: Route14CooltrainerM1BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
Route14CooltrainerM2Text:
    mov esi, Route14TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

; Route14CooltrainerM2BattleText (scripts/Route14.asm:79-88) — not re-emitted: Route14CooltrainerM2BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
Route14CooltrainerM3Text:
    mov esi, Route14TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

; Route14CooltrainerM3BattleText (scripts/Route14.asm:97-106) — not re-emitted: Route14CooltrainerM3BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
Route14CooltrainerM4Text:
    mov esi, Route14TrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

; Route14CooltrainerM4BattleText (scripts/Route14.asm:115-124) — not re-emitted: Route14CooltrainerM4BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
Route14CooltrainerM5Text:
    mov esi, Route14TrainerHeader4
    call TalkToTrainer
    jmp TextScriptEnd

; Route14CooltrainerM5BattleText (scripts/Route14.asm:133-142) — not re-emitted: Route14CooltrainerM5BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
Route14CooltrainerM6Text:
    mov esi, Route14TrainerHeader5
    call TalkToTrainer
    jmp TextScriptEnd

; Route14CooltrainerM6BattleText (scripts/Route14.asm:151-160) — not re-emitted: Route14CooltrainerM6BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
Route14Biker1Text:
    mov esi, Route14TrainerHeader6
    call TalkToTrainer
    jmp TextScriptEnd

; Route14Biker1BattleText (scripts/Route14.asm:169-178) — not re-emitted: Route14Biker1BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
Route14Biker2Text:
    mov esi, Route14TrainerHeader7
    call TalkToTrainer
    jmp TextScriptEnd

; Route14Biker2BattleText (scripts/Route14.asm:187-196) — not re-emitted: Route14Biker2BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
Route14Biker3Text:
    mov esi, Route14TrainerHeader8
    call TalkToTrainer
    jmp TextScriptEnd

; Route14Biker3BattleText (scripts/Route14.asm:205-214) — not re-emitted: Route14Biker3BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
Route14Biker4Text:
    mov esi, Route14TrainerHeader9
    call TalkToTrainer
    jmp TextScriptEnd

; Route14Biker4BattleText (scripts/Route14.asm:223-236) — not re-emitted: Route14Biker4BattleText is already defined in assets/trainer_headers.inc.
