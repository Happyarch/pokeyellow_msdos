; PokemonTower5F.asm — translated from pret scripts/PokemonTower5F.asm by dos_port/tools/sm83xlat.
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

global PokemonTower5FChanneler2Text
global PokemonTower5FChanneler3Text
global PokemonTower5FChanneler4Text
global PokemonTower5FChanneler5Text
global PokemonTower5FDefaultScript
global PokemonTower5F_Script
global PokemonTower5F_ScriptPointers

extern ArePlayerCoordsInArray
extern CheckFightingMapTrainers
extern Delay3
extern DisplayEnemyTrainerTextAndStartBattle
extern DisplayTextID
extern EnableAutoTextBoxDrawing
extern EndTrainerBattle
extern ExecuteCurMapScriptInTable
extern GBFadeInFromWhite
extern GBFadeOutToWhite
extern HealParty
extern PokemonTower5FChanneler2BattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonTower5FChanneler3BattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonTower5FChanneler4BattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonTower5FChanneler5BattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonTower5FPurifiedZoneCoords   ; NOT YET DEFINED IN THE PORT
extern PokemonTower5TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern PokemonTower5TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern PokemonTower5TrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern PokemonTower5TrainerHeader3   ; NOT YET DEFINED IN THE PORT
extern PokemonTower5TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer
extern TextScriptEnd

; Script constants — pret defines these via dw_const in this file.
TEXT_POKEMONTOWER5F_PURIFIEDZONE               equ 7

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wPokemonTower5FCurScript                       equ 0xD62D

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
PokemonTower5F_Script:
    call EnableAutoTextBoxDrawing
    mov esi, PokemonTower5TrainerHeaders
    mov edi, PokemonTower5F_ScriptPointers   ; pret: ld de, PokemonTower5F_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wPokemonTower5FCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wPokemonTower5FCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
PokemonTower5F_ScriptPointers:
    dd PokemonTower5FDefaultScript
    dd DisplayEnemyTrainerTextAndStartBattle
    dd EndTrainerBattle

%assign event_byte -1
%assign event_byte_a -1
PokemonTower5FDefaultScript:
    mov esi, PokemonTower5FPurifiedZoneCoords
    call ArePlayerCoordsInArray
    jb .in_purified_zone
    mov esi, wStatusFlags4
    and byte [ebp + esi], ~(1 << (BIT_NO_BATTLES)) & 0xFF
    ResetEvent EVENT_IN_PURIFIED_ZONE
    jmp CheckFightingMapTrainers

%assign event_byte -1
%assign event_byte_a -1
.in_purified_zone:
    CheckAndSetEvent EVENT_IN_PURIFIED_ZONE
    jz .nr_26
        ret
.nr_26:
    xor al, al
    mov [ebp + hJoyHeld], al
    mov al, PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    mov esi, wStatusFlags4
    or byte [ebp + esi], (1 << (BIT_NO_BATTLES))
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call HealParty
    call GBFadeOutToWhite
    call Delay3
    call Delay3
    call GBFadeInFromWhite
    mov al, TEXT_POKEMONTOWER5F_PURIFIEDZONE
    mov [ebp + hTextID], al
    call DisplayTextID
    xor al, al
    mov [ebp + wJoyIgnore], al
    ret

; PokemonTower5FPurifiedZoneCoords (scripts/PokemonTower5F.asm:46-76) — not re-emitted: PokemonTower5TrainerHeaders is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
PokemonTower5FChanneler2Text:
    mov esi, PokemonTower5TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; PokemonTower5FChanneler2BattleText (scripts/PokemonTower5F.asm:85-94) — not re-emitted: PokemonTower5FChanneler2BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
PokemonTower5FChanneler3Text:
    mov esi, PokemonTower5TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

; PokemonTower5FChanneler3BattleText (scripts/PokemonTower5F.asm:103-112) — not re-emitted: PokemonTower5FChanneler3BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
PokemonTower5FChanneler4Text:
    mov esi, PokemonTower5TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

; PokemonTower5FChanneler4BattleText (scripts/PokemonTower5F.asm:121-130) — not re-emitted: PokemonTower5FChanneler4BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
PokemonTower5FChanneler5Text:
    mov esi, PokemonTower5TrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

; PokemonTower5FChanneler5BattleText (scripts/PokemonTower5F.asm:139-152) — not re-emitted: PokemonTower5FChanneler5BattleText is already defined in assets/trainer_headers.inc.
