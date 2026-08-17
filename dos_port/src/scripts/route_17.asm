; Route17.asm — translated from pret scripts/Route17.asm by dos_port/tools/sm83xlat.
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

global Route17Biker10Text
global Route17Biker1Text
global Route17Biker2Text
global Route17Biker3Text
global Route17Biker4Text
global Route17Biker5Text
global Route17Biker6Text
global Route17Biker7Text
global Route17Biker8Text
global Route17Biker9Text
global Route17_Script

extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern Route17Biker10BattleText   ; NOT YET DEFINED IN THE PORT
extern Route17Biker1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route17Biker2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route17Biker3BattleText   ; NOT YET DEFINED IN THE PORT
extern Route17Biker4BattleText   ; NOT YET DEFINED IN THE PORT
extern Route17Biker5BattleText   ; NOT YET DEFINED IN THE PORT
extern Route17Biker6BattleText   ; NOT YET DEFINED IN THE PORT
extern Route17Biker7BattleText   ; NOT YET DEFINED IN THE PORT
extern Route17Biker8BattleText   ; NOT YET DEFINED IN THE PORT
extern Route17Biker9BattleText   ; NOT YET DEFINED IN THE PORT
extern Route17TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern Route17TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern Route17TrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern Route17TrainerHeader3   ; NOT YET DEFINED IN THE PORT
extern Route17TrainerHeader4   ; NOT YET DEFINED IN THE PORT
extern Route17TrainerHeader5   ; NOT YET DEFINED IN THE PORT
extern Route17TrainerHeader6   ; NOT YET DEFINED IN THE PORT
extern Route17TrainerHeader7   ; NOT YET DEFINED IN THE PORT
extern Route17TrainerHeader8   ; NOT YET DEFINED IN THE PORT
extern Route17TrainerHeader9   ; NOT YET DEFINED IN THE PORT
extern Route17TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern Route17_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wRoute17CurScript                              equ 0xD61B

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
Route17_Script:
    call EnableAutoTextBoxDrawing
    mov esi, Route17TrainerHeaders
    mov edi, Route17_ScriptPointers   ; pret: ld de, Route17_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wRoute17CurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wRoute17CurScript], al
    ret

; Route17_ScriptPointers (scripts/Route17.asm:11-57) — not re-emitted: Route17_ScriptPointers is already defined in assets/map_script_tables.inc.

%assign event_byte -1
%assign event_byte_a -1
Route17Biker1Text:
    mov esi, Route17TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; Route17Biker1BattleText (scripts/Route17.asm:66-75) — not re-emitted: Route17Biker1BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route17Biker2Text:
    mov esi, Route17TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

; Route17Biker2BattleText (scripts/Route17.asm:84-93) — not re-emitted: Route17Biker2BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route17Biker3Text:
    mov esi, Route17TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

; Route17Biker3BattleText (scripts/Route17.asm:102-111) — not re-emitted: Route17Biker3BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route17Biker4Text:
    mov esi, Route17TrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

; Route17Biker4BattleText (scripts/Route17.asm:120-129) — not re-emitted: Route17Biker4BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route17Biker5Text:
    mov esi, Route17TrainerHeader4
    call TalkToTrainer
    jmp TextScriptEnd

; Route17Biker5BattleText (scripts/Route17.asm:138-147) — not re-emitted: Route17Biker5BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route17Biker6Text:
    mov esi, Route17TrainerHeader5
    call TalkToTrainer
    jmp TextScriptEnd

; Route17Biker6BattleText (scripts/Route17.asm:156-165) — not re-emitted: Route17Biker6BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route17Biker7Text:
    mov esi, Route17TrainerHeader6
    call TalkToTrainer
    jmp TextScriptEnd

; Route17Biker7BattleText (scripts/Route17.asm:174-183) — not re-emitted: Route17Biker7BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route17Biker8Text:
    mov esi, Route17TrainerHeader7
    call TalkToTrainer
    jmp TextScriptEnd

; Route17Biker8BattleText (scripts/Route17.asm:192-201) — not re-emitted: Route17Biker8BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route17Biker9Text:
    mov esi, Route17TrainerHeader8
    call TalkToTrainer
    jmp TextScriptEnd

; Route17Biker9BattleText (scripts/Route17.asm:210-219) — not re-emitted: Route17Biker9BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route17Biker10Text:
    mov esi, Route17TrainerHeader9
    call TalkToTrainer
    jmp TextScriptEnd

; Route17Biker10BattleText (scripts/Route17.asm:228-261) — not re-emitted: Route17Biker10BattleText is already defined in assets/trainer_headers.inc.
