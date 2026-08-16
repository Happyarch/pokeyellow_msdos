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
extern PickUpItemText   ; NOT YET DEFINED IN THE PORT
extern PokemonTower5FChanneler1Text   ; NOT YET DEFINED IN THE PORT
extern PokemonTower5FChanneler2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonTower5FChanneler2BattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonTower5FChanneler2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonTower5FChanneler3AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonTower5FChanneler3BattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonTower5FChanneler3EndBattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonTower5FChanneler4AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonTower5FChanneler4BattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonTower5FChanneler4EndBattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonTower5FChanneler5AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonTower5FChanneler5BattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonTower5FChanneler5EndBattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonTower5FDefaultScript   ; NOT YET DEFINED IN THE PORT
extern PokemonTower5FPurifiedZoneCoords   ; NOT YET DEFINED IN THE PORT
extern PokemonTower5FPurifiedZoneText   ; NOT YET DEFINED IN THE PORT
extern PokemonTower5F_TextPointers   ; NOT YET DEFINED IN THE PORT
extern PokemonTower5TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern PokemonTower5TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern PokemonTower5TrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern PokemonTower5TrainerHeader3   ; NOT YET DEFINED IN THE PORT
extern PokemonTower5TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
TEXT_POKEMONTOWER5F_CHANNELER1                 equ 1
TEXT_POKEMONTOWER5F_CHANNELER2                 equ 2
TEXT_POKEMONTOWER5F_CHANNELER3                 equ 3
TEXT_POKEMONTOWER5F_CHANNELER4                 equ 4
TEXT_POKEMONTOWER5F_CHANNELER5                 equ 5
TEXT_POKEMONTOWER5F_NUGGET                     equ 6
TEXT_POKEMONTOWER5F_PURIFIEDZONE               equ 7

; pret RAM names the port still spells in SCREAMING_SNAKE. Guarded, so
; this file assembles both before and after the memmap rename lands.
%ifndef wStatusFlags4
wStatusFlags4                                  equ W_STATUS_FLAGS_4
%endif

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

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] PokemonTower5FPurifiedZoneCoords (scripts/PokemonTower5F.asm:46-76) — a generated asset already defines PokemonTower5TrainerHeaders
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	dbmapcoord 10,  8
; PRET| 	dbmapcoord 11,  8
; PRET| 	dbmapcoord 10,  9
; PRET| 	dbmapcoord 11,  9
; PRET| 	db -1 ; end
; PRET| 
; PRET| PokemonTower5F_TextPointers:
; PRET| 	def_text_pointers
; PRET| 	dw_const PokemonTower5FChanneler1Text,   TEXT_POKEMONTOWER5F_CHANNELER1
; PRET| 	dw_const PokemonTower5FChanneler2Text,   TEXT_POKEMONTOWER5F_CHANNELER2
; PRET| 	dw_const PokemonTower5FChanneler3Text,   TEXT_POKEMONTOWER5F_CHANNELER3
; PRET| 	dw_const PokemonTower5FChanneler4Text,   TEXT_POKEMONTOWER5F_CHANNELER4
; PRET| 	dw_const PokemonTower5FChanneler5Text,   TEXT_POKEMONTOWER5F_CHANNELER5
; PRET| 	dw_const PickUpItemText,                 TEXT_POKEMONTOWER5F_NUGGET
; PRET| 	dw_const PokemonTower5FPurifiedZoneText, TEXT_POKEMONTOWER5F_PURIFIEDZONE
; PRET| 
; PRET| PokemonTower5TrainerHeaders:
; PRET| 	def_trainers 2
; PRET| PokemonTower5TrainerHeader0:
; PRET| 	trainer EVENT_BEAT_POKEMONTOWER_5_TRAINER_0, 2, PokemonTower5FChanneler2BattleText, PokemonTower5FChanneler2EndBattleText, PokemonTower5FChanneler2AfterBattleText
; PRET| PokemonTower5TrainerHeader1:
; PRET| 	trainer EVENT_BEAT_POKEMONTOWER_5_TRAINER_1, 3, PokemonTower5FChanneler3BattleText, PokemonTower5FChanneler3EndBattleText, PokemonTower5FChanneler3AfterBattleText
; PRET| PokemonTower5TrainerHeader2:
; PRET| 	trainer EVENT_BEAT_POKEMONTOWER_5_TRAINER_2, 2, PokemonTower5FChanneler4BattleText, PokemonTower5FChanneler4EndBattleText, PokemonTower5FChanneler4AfterBattleText
; PRET| PokemonTower5TrainerHeader3:
; PRET| 	trainer EVENT_BEAT_POKEMONTOWER_5_TRAINER_3, 2, PokemonTower5FChanneler5BattleText, PokemonTower5FChanneler5EndBattleText, PokemonTower5FChanneler5AfterBattleText
; PRET| 	db -1 ; end
; PRET| 
; PRET| PokemonTower5FChanneler1Text:
; PRET| 	text_far _PokemonTower5FChanneler1Text
; PRET| 	text_end

PokemonTower5FChanneler2Text:
    mov esi, PokemonTower5TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] PokemonTower5FChanneler2BattleText (scripts/PokemonTower5F.asm:85-94) — a generated asset already defines PokemonTower5FChanneler2BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _PokemonTower5FChanneler2BattleText
; PRET| 	text_end
; PRET| 
; PRET| PokemonTower5FChanneler2EndBattleText:
; PRET| 	text_far _PokemonTower5FChanneler2EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| PokemonTower5FChanneler2AfterBattleText:
; PRET| 	text_far _PokemonTower5FChanneler2AfterBattleText
; PRET| 	text_end

PokemonTower5FChanneler3Text:
    mov esi, PokemonTower5TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] PokemonTower5FChanneler3BattleText (scripts/PokemonTower5F.asm:103-112) — a generated asset already defines PokemonTower5FChanneler3BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _PokemonTower5FChanneler3BattleText
; PRET| 	text_end
; PRET| 
; PRET| PokemonTower5FChanneler3EndBattleText:
; PRET| 	text_far _PokemonTower5FChanneler3EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| PokemonTower5FChanneler3AfterBattleText:
; PRET| 	text_far _PokemonTower5FChanneler3AfterBattleText
; PRET| 	text_end

PokemonTower5FChanneler4Text:
    mov esi, PokemonTower5TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] PokemonTower5FChanneler4BattleText (scripts/PokemonTower5F.asm:121-130) — a generated asset already defines PokemonTower5FChanneler4BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _PokemonTower5FChanneler4BattleText
; PRET| 	text_end
; PRET| 
; PRET| PokemonTower5FChanneler4EndBattleText:
; PRET| 	text_far _PokemonTower5FChanneler4EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| PokemonTower5FChanneler4AfterBattleText:
; PRET| 	text_far _PokemonTower5FChanneler4AfterBattleText
; PRET| 	text_end

PokemonTower5FChanneler5Text:
    mov esi, PokemonTower5TrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] PokemonTower5FChanneler5BattleText (scripts/PokemonTower5F.asm:139-152) — a generated asset already defines PokemonTower5FChanneler5BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _PokemonTower5FChanneler5BattleText
; PRET| 	text_end
; PRET| 
; PRET| PokemonTower5FChanneler5EndBattleText:
; PRET| 	text_far _PokemonTower5FChanneler5EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| PokemonTower5FChanneler5AfterBattleText:
; PRET| 	text_far _PokemonTower5FChanneler5AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| PokemonTower5FPurifiedZoneText:
; PRET| 	text_far _PokemonTower5FPurifiedZoneText
; PRET| 	text_end
