; Route6.asm — translated from pret scripts/Route6.asm by dos_port/tools/sm83xlat.
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

global Route6CooltrainerF1Text
global Route6CooltrainerF2Text
global Route6CooltrainerM1Text
global Route6CooltrainerM2Text
global Route6Youngster1Text
global Route6Youngster2Text
global Route6_Script

extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern Route6CooltrainerF1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route6CooltrainerF2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route6CooltrainerM1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route6CooltrainerM2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route6TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern Route6TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern Route6TrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern Route6TrainerHeader3   ; NOT YET DEFINED IN THE PORT
extern Route6TrainerHeader4   ; NOT YET DEFINED IN THE PORT
extern Route6TrainerHeader5   ; NOT YET DEFINED IN THE PORT
extern Route6TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern Route6Youngster1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route6Youngster2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route6_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wRoute6CurScript                               equ 0xD5FF

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
Route6_Script:
    call EnableAutoTextBoxDrawing
    mov esi, Route6TrainerHeaders
    mov edi, Route6_ScriptPointers   ; pret: ld de, Route6_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wRoute6CurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wRoute6CurScript], al
    ret

; Route6_ScriptPointers (scripts/Route6.asm:11-40) — not re-emitted: Route6_ScriptPointers is already defined in assets/map_script_tables.inc.

%assign event_byte -1
%assign event_byte_a -1
Route6CooltrainerM1Text:
    mov esi, Route6TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; Route6CooltrainerM1BattleText (scripts/Route6.asm:49-58) — not re-emitted: Route6CooltrainerM1BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route6CooltrainerF1Text:
    mov esi, Route6TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

; Route6CooltrainerF1BattleText (scripts/Route6.asm:67-76) — not re-emitted: Route6CooltrainerF1BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route6Youngster1Text:
    mov esi, Route6TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

; Route6Youngster1BattleText (scripts/Route6.asm:85-94) — not re-emitted: Route6Youngster1BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route6CooltrainerM2Text:
    mov esi, Route6TrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

; Route6CooltrainerM2BattleText (scripts/Route6.asm:103-112) — not re-emitted: Route6CooltrainerM2BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route6CooltrainerF2Text:
    mov esi, Route6TrainerHeader4
    call TalkToTrainer
    jmp TextScriptEnd

; Route6CooltrainerF2BattleText (scripts/Route6.asm:121-130) — not re-emitted: Route6CooltrainerF2BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route6Youngster2Text:
    mov esi, Route6TrainerHeader5
    call TalkToTrainer
    jmp TextScriptEnd

; Route6Youngster2BattleText (scripts/Route6.asm:139-152) — not re-emitted: Route6Youngster2BattleText is already defined in assets/trainer_headers.inc.
