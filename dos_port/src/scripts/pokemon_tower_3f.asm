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


global PokemonTower3FChanneler1Text
global PokemonTower3FChanneler2Text
global PokemonTower3FChanneler3Text
global PokemonTower3F_Script

extern CheckFightingMapTrainers   ; NOT YET DEFINED IN THE PORT
extern DisplayEnemyTrainerTextAndStartBattle   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EndTrainerBattle   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern PickUpItemText   ; NOT YET DEFINED IN THE PORT
extern PokemonTower3FChanneler1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonTower3FChanneler1BattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonTower3FChanneler1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonTower3FChanneler2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonTower3FChanneler2BattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonTower3FChanneler2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonTower3FChanneler3AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonTower3FChanneler3BattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonTower3FChanneler3EndBattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonTower3F_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern PokemonTower3F_TextPointers   ; NOT YET DEFINED IN THE PORT
extern PokemonTower3TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern PokemonTower3TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern PokemonTower3TrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern PokemonTower3TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_POKEMONTOWER3F_DEFAULT                  equ 0
SCRIPT_POKEMONTOWER3F_START_BATTLE             equ 1
SCRIPT_POKEMONTOWER3F_END_BATTLE               equ 2
TEXT_POKEMONTOWER3F_CHANNELER1                 equ 1
TEXT_POKEMONTOWER3F_CHANNELER2                 equ 2
TEXT_POKEMONTOWER3F_CHANNELER3                 equ 3
TEXT_POKEMONTOWER3F_ESCAPE_ROPE                equ 4

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

; ---------------------------------------------------------------------------
; PokemonTower3F_ScriptPointers (scripts/PokemonTower3F.asm:11-31) — Tier-1 data: PokemonTower3TrainerHeaders is generated into assets/trainer_headers.inc.

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

; ---------------------------------------------------------------------------
; PokemonTower3FChanneler1BattleText (scripts/PokemonTower3F.asm:52-85) — Tier-1 data: PokemonTower3FChanneler1BattleText is generated into assets/trainer_headers.inc.
