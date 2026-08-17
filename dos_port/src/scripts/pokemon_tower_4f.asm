; PokemonTower4F.asm — translated from pret scripts/PokemonTower4F.asm by dos_port/tools/sm83xlat.
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

global PokemonTower4FChanneler1Text
global PokemonTower4FChanneler2Text
global PokemonTower4FChanneler3Text
global PokemonTower4F_Script

extern EnableAutoTextBoxDrawing
extern ExecuteCurMapScriptInTable
extern PokemonTower4FChanneler1BattleText
extern PokemonTower4F_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern PokemonTower4TrainerHeader0
extern PokemonTower4TrainerHeader1
extern PokemonTower4TrainerHeader2
extern PokemonTower4TrainerHeaders
extern TalkToTrainer
extern TextScriptEnd

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wPokemonTower4FCurScript                       equ 0xD62C

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
PokemonTower4F_Script:
    call EnableAutoTextBoxDrawing
    mov esi, PokemonTower4TrainerHeaders
    mov edi, PokemonTower4F_ScriptPointers   ; pret: ld de, PokemonTower4F_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wPokemonTower4FCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wPokemonTower4FCurScript], al
    ret

; PokemonTower4F_ScriptPointers (scripts/PokemonTower4F.asm:11-33) — not re-emitted: PokemonTower4TrainerHeaders is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
PokemonTower4FChanneler1Text:
    mov esi, PokemonTower4TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
PokemonTower4FChanneler2Text:
    mov esi, PokemonTower4TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
PokemonTower4FChanneler3Text:
    mov esi, PokemonTower4TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

; PokemonTower4FChanneler1BattleText (scripts/PokemonTower4F.asm:54-87) — not re-emitted: PokemonTower4FChanneler1BattleText is already defined in assets/trainer_headers.inc.
