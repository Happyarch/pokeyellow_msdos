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
global PokemonTower5F_Script
global PokemonTower5F_ScriptPointers

extern ArePlayerCoordsInArray   ; NOT YET DEFINED IN THE PORT
extern CheckFightingMapTrainers   ; NOT YET DEFINED IN THE PORT
extern Delay3   ; NOT YET DEFINED IN THE PORT
extern DisplayEnemyTrainerTextAndStartBattle   ; NOT YET DEFINED IN THE PORT
extern DisplayTextID   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EndTrainerBattle   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern GBFadeInFromWhite   ; NOT YET DEFINED IN THE PORT
extern GBFadeOutToWhite   ; NOT YET DEFINED IN THE PORT
extern HealParty   ; NOT YET DEFINED IN THE PORT
extern PokemonTower5FChanneler2BattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonTower5FChanneler3BattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonTower5FChanneler4BattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonTower5FChanneler5BattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonTower5FDefaultScript   ; NOT YET DEFINED IN THE PORT
extern PokemonTower5FPurifiedZoneCoords   ; NOT YET DEFINED IN THE PORT
extern PokemonTower5TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern PokemonTower5TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern PokemonTower5TrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern PokemonTower5TrainerHeader3   ; NOT YET DEFINED IN THE PORT
extern PokemonTower5TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT

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

PokemonTower5F_Script:
    call EnableAutoTextBoxDrawing
    mov esi, PokemonTower5TrainerHeaders
    mov edi, PokemonTower5F_ScriptPointers   ; pret: ld de, PokemonTower5F_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wPokemonTower5FCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wPokemonTower5FCurScript], al
    ret

PokemonTower5F_ScriptPointers:
    dd PokemonTower5FDefaultScript
    dd DisplayEnemyTrainerTextAndStartBattle
    dd EndTrainerBattle

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] PokemonTower5FDefaultScript (scripts/PokemonTower5F.asm:17-23) — at scripts/PokemonTower5F.asm:19: .in_purified_zone is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, PokemonTower5FPurifiedZoneCoords
; PRET| 	call ArePlayerCoordsInArray
; PRET| 	jr c, .in_purified_zone
; PRET| 	ld hl, wStatusFlags4
; PRET| 	res BIT_NO_BATTLES, [hl]
; PRET| 	ResetEvent EVENT_IN_PURIFIED_ZONE
; PRET| 	jp CheckFightingMapTrainers

; ---------------------------------------------------------------------------
; BAIL[predef-leaves-id-in-a] PokemonTower5FDefaultScript.in_purified_zone (scripts/PokemonTower5F.asm:25-43) — at scripts/PokemonTower5F.asm:33: predef HealParty
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckAndSetEvent EVENT_IN_PURIFIED_ZONE
; PRET| 	ret nz
; PRET| 	xor a
; PRET| 	ldh [hJoyHeld], a
; PRET| 	ld a, PAD_CTRL_PAD
; PRET| 	ld [wJoyIgnore], a
; PRET| 	ld hl, wStatusFlags4
; PRET| 	set BIT_NO_BATTLES, [hl]
; PRET| 	predef HealParty
; PRET| 	call GBFadeOutToWhite
; PRET| 	call Delay3
; PRET| 	call Delay3
; PRET| 	call GBFadeInFromWhite
; PRET| 	ld a, TEXT_POKEMONTOWER5F_PURIFIEDZONE
; PRET| 	ldh [hTextID], a
; PRET| 	call DisplayTextID
; PRET| 	xor a
; PRET| 	ld [wJoyIgnore], a
; PRET| 	ret

; PokemonTower5FPurifiedZoneCoords (scripts/PokemonTower5F.asm:46-76) — not re-emitted: PokemonTower5TrainerHeaders is already defined in assets/trainer_headers.inc.

PokemonTower5FChanneler2Text:
    mov esi, PokemonTower5TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; PokemonTower5FChanneler2BattleText (scripts/PokemonTower5F.asm:85-94) — not re-emitted: PokemonTower5FChanneler2BattleText is already defined in assets/trainer_headers.inc.

PokemonTower5FChanneler3Text:
    mov esi, PokemonTower5TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

; PokemonTower5FChanneler3BattleText (scripts/PokemonTower5F.asm:103-112) — not re-emitted: PokemonTower5FChanneler3BattleText is already defined in assets/trainer_headers.inc.

PokemonTower5FChanneler4Text:
    mov esi, PokemonTower5TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

; PokemonTower5FChanneler4BattleText (scripts/PokemonTower5F.asm:121-130) — not re-emitted: PokemonTower5FChanneler4BattleText is already defined in assets/trainer_headers.inc.

PokemonTower5FChanneler5Text:
    mov esi, PokemonTower5TrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

; PokemonTower5FChanneler5BattleText (scripts/PokemonTower5F.asm:139-152) — not re-emitted: PokemonTower5FChanneler5BattleText is already defined in assets/trainer_headers.inc.
