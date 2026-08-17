; Route11.asm — translated from pret scripts/Route11.asm by dos_port/tools/sm83xlat.
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

global Route11Gambler1Text
global Route11Gambler2Text
global Route11Gambler3Text
global Route11Gambler4Text
global Route11SuperNerd1Text
global Route11SuperNerd2Text
global Route11Youngster1Text
global Route11Youngster2Text
global Route11Youngster3Text
global Route11Youngster4Text
global Route11_Script

extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern Route11Gambler1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route11Gambler2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route11Gambler3BattleText   ; NOT YET DEFINED IN THE PORT
extern Route11Gambler4BattleText   ; NOT YET DEFINED IN THE PORT
extern Route11SuperNerd1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route11SuperNerd2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route11TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern Route11TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern Route11TrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern Route11TrainerHeader3   ; NOT YET DEFINED IN THE PORT
extern Route11TrainerHeader4   ; NOT YET DEFINED IN THE PORT
extern Route11TrainerHeader5   ; NOT YET DEFINED IN THE PORT
extern Route11TrainerHeader6   ; NOT YET DEFINED IN THE PORT
extern Route11TrainerHeader7   ; NOT YET DEFINED IN THE PORT
extern Route11TrainerHeader8   ; NOT YET DEFINED IN THE PORT
extern Route11TrainerHeader9   ; NOT YET DEFINED IN THE PORT
extern Route11TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern Route11Youngster1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route11Youngster2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route11Youngster3BattleText   ; NOT YET DEFINED IN THE PORT
extern Route11Youngster4BattleText   ; NOT YET DEFINED IN THE PORT
extern Route11_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wRoute11CurScript                              equ 0xD622

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

Route11_Script:
    call EnableAutoTextBoxDrawing
    mov esi, Route11TrainerHeaders
    mov edi, Route11_ScriptPointers   ; pret: ld de, Route11_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wRoute11CurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wRoute11CurScript], al
    ret

; Route11_ScriptPointers (scripts/Route11.asm:11-52) — not re-emitted: Route11_ScriptPointers is already defined in assets/map_script_tables.inc.

Route11Gambler1Text:
    mov esi, Route11TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; Route11Gambler1BattleText (scripts/Route11.asm:61-70) — not re-emitted: Route11Gambler1BattleText is already defined in assets/trainer_headers.inc.

Route11Gambler2Text:
    mov esi, Route11TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

; Route11Gambler2BattleText (scripts/Route11.asm:79-88) — not re-emitted: Route11Gambler2BattleText is already defined in assets/trainer_headers.inc.

Route11Youngster1Text:
    mov esi, Route11TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

; Route11Youngster1BattleText (scripts/Route11.asm:97-106) — not re-emitted: Route11Youngster1BattleText is already defined in assets/trainer_headers.inc.

Route11SuperNerd1Text:
    mov esi, Route11TrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

; Route11SuperNerd1BattleText (scripts/Route11.asm:115-124) — not re-emitted: Route11SuperNerd1BattleText is already defined in assets/trainer_headers.inc.

Route11Youngster2Text:
    mov esi, Route11TrainerHeader4
    call TalkToTrainer
    jmp TextScriptEnd

; Route11Youngster2BattleText (scripts/Route11.asm:133-142) — not re-emitted: Route11Youngster2BattleText is already defined in assets/trainer_headers.inc.

Route11Gambler3Text:
    mov esi, Route11TrainerHeader5
    call TalkToTrainer
    jmp TextScriptEnd

; Route11Gambler3BattleText (scripts/Route11.asm:151-160) — not re-emitted: Route11Gambler3BattleText is already defined in assets/trainer_headers.inc.

Route11Gambler4Text:
    mov esi, Route11TrainerHeader6
    call TalkToTrainer
    jmp TextScriptEnd

; Route11Gambler4BattleText (scripts/Route11.asm:169-178) — not re-emitted: Route11Gambler4BattleText is already defined in assets/trainer_headers.inc.

Route11Youngster3Text:
    mov esi, Route11TrainerHeader7
    call TalkToTrainer
    jmp TextScriptEnd

; Route11Youngster3BattleText (scripts/Route11.asm:187-196) — not re-emitted: Route11Youngster3BattleText is already defined in assets/trainer_headers.inc.

Route11SuperNerd2Text:
    mov esi, Route11TrainerHeader8
    call TalkToTrainer
    jmp TextScriptEnd

; Route11SuperNerd2BattleText (scripts/Route11.asm:205-214) — not re-emitted: Route11SuperNerd2BattleText is already defined in assets/trainer_headers.inc.

Route11Youngster4Text:
    mov esi, Route11TrainerHeader9
    call TalkToTrainer
    jmp TextScriptEnd

; Route11Youngster4BattleText (scripts/Route11.asm:223-236) — not re-emitted: Route11Youngster4BattleText is already defined in assets/trainer_headers.inc.
