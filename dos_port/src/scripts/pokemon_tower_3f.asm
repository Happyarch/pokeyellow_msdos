; PokemonTower3F.asm — translated from pret scripts/PokemonTower3F.asm by dos_port/tools/sm83xlat.
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

%include "assets/trainer_headers.inc"

global PokemonTower3FChanneler1Text
global PokemonTower3FChanneler2Text
global PokemonTower3FChanneler3Text
global PokemonTower3F_Script

extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern PokemonTower3FChanneler1BattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonTower3F_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern PokemonTower3TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern PokemonTower3TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern PokemonTower3TrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern PokemonTower3TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wPokemonTower3FCurScript                       equ 0xD62B

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

PokemonTower3F_Script:
    call EnableAutoTextBoxDrawing
    mov esi, PokemonTower3TrainerHeaders
    mov edi, PokemonTower3F_ScriptPointers   ; pret: ld de, PokemonTower3F_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wPokemonTower3FCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wPokemonTower3FCurScript], al
    ret

; PokemonTower3F_ScriptPointers (scripts/PokemonTower3F.asm:11-31) — not re-emitted: PokemonTower3TrainerHeaders is already defined in assets/trainer_headers.inc.

PokemonTower3FChanneler1Text:
    mov esi, PokemonTower3TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

PokemonTower3FChanneler2Text:
    mov esi, PokemonTower3TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

PokemonTower3FChanneler3Text:
    mov esi, PokemonTower3TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

; PokemonTower3FChanneler1BattleText (scripts/PokemonTower3F.asm:52-85) — not re-emitted: PokemonTower3FChanneler1BattleText is already defined in assets/trainer_headers.inc.
