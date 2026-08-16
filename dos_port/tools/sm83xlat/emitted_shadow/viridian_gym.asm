; ViridianGym.asm — translated from pret scripts/ViridianGym.asm by dos_port/tools/sm83xlat.
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

%include "assets/audio_constants.inc"

global ViridianGymArrowMovement1
global ViridianGymArrowMovement10
global ViridianGymArrowMovement11
global ViridianGymArrowMovement12
global ViridianGymArrowMovement2
global ViridianGymArrowMovement3
global ViridianGymArrowMovement4
global ViridianGymArrowMovement5
global ViridianGymArrowMovement6
global ViridianGymArrowMovement7
global ViridianGymArrowMovement8
global ViridianGymArrowMovement9
global ViridianGymArrowTilePlayerMovement
global ViridianGymCooltrainerM1Text
global ViridianGymCooltrainerM2Text
global ViridianGymCooltrainerM3Text
global ViridianGymDefaultScript
global ViridianGymGuidePostBattleText
global ViridianGymGuidePreBattleText
global ViridianGymHiker1Text
global ViridianGymHiker2Text
global ViridianGymHiker3Text
global ViridianGymPlayerSpinningScript
global ViridianGymResetScripts
global ViridianGymRocker1Text
global ViridianGymRocker2Text
global ViridianGym_ScriptPointers

extern Bankswitch   ; NOT YET DEFINED IN THE PORT
extern CheckFightingMapTrainers   ; NOT YET DEFINED IN THE PORT
extern DecodeArrowMovementRLE   ; NOT YET DEFINED IN THE PORT
extern Delay3   ; NOT YET DEFINED IN THE PORT
extern DisplayEnemyTrainerTextAndStartBattle   ; NOT YET DEFINED IN THE PORT
extern DisplayTextID   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EndTrainerBattle   ; NOT YET DEFINED IN THE PORT
extern EngageMapTrainer   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern GBFadeInFromBlack   ; NOT YET DEFINED IN THE PORT
extern GBFadeOutToBlack   ; NOT YET DEFINED IN THE PORT
extern GiveItem   ; NOT YET DEFINED IN THE PORT
extern HideObject   ; NOT YET DEFINED IN THE PORT
extern InitBattleEnemyParameters   ; NOT YET DEFINED IN THE PORT
extern LoadGymLeaderAndCityName   ; NOT YET DEFINED IN THE PORT
extern LoadSpinnerArrowTiles   ; NOT YET DEFINED IN THE PORT
extern PickUpItemText   ; NOT YET DEFINED IN THE PORT
extern PlaySound   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern SaveEndBattleTextPointers   ; NOT YET DEFINED IN THE PORT
extern ShowObject   ; NOT YET DEFINED IN THE PORT
extern StartSimulatingJoypadStates   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern UpdateSprites   ; NOT YET DEFINED IN THE PORT
extern ViridianGymCooltrainerM1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern ViridianGymCooltrainerM1BattleText   ; NOT YET DEFINED IN THE PORT
extern ViridianGymCooltrainerM1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern ViridianGymCooltrainerM2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern ViridianGymCooltrainerM2BattleText   ; NOT YET DEFINED IN THE PORT
extern ViridianGymCooltrainerM2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern ViridianGymCooltrainerM3AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern ViridianGymCooltrainerM3BattleText   ; NOT YET DEFINED IN THE PORT
extern ViridianGymCooltrainerM3EndBattleText   ; NOT YET DEFINED IN THE PORT
extern ViridianGymGiovanniEarthBadgeInfoText   ; NOT YET DEFINED IN THE PORT
extern ViridianGymGiovanniPostBattle   ; NOT YET DEFINED IN THE PORT
extern ViridianGymGiovanniReceivedTM27Text   ; NOT YET DEFINED IN THE PORT
extern ViridianGymGiovanniTM27ExplanationText   ; NOT YET DEFINED IN THE PORT
extern ViridianGymGiovanniTM27NoRoomText   ; NOT YET DEFINED IN THE PORT
extern ViridianGymGiovanniText   ; NOT YET DEFINED IN THE PORT
extern ViridianGymGymGuideText   ; NOT YET DEFINED IN THE PORT
extern ViridianGymHiker1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern ViridianGymHiker1BattleText   ; NOT YET DEFINED IN THE PORT
extern ViridianGymHiker1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern ViridianGymHiker2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern ViridianGymHiker2BattleText   ; NOT YET DEFINED IN THE PORT
extern ViridianGymHiker2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern ViridianGymHiker3AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern ViridianGymHiker3BattleText   ; NOT YET DEFINED IN THE PORT
extern ViridianGymHiker3EndBattleText   ; NOT YET DEFINED IN THE PORT
extern ViridianGymReceiveTM27   ; NOT YET DEFINED IN THE PORT
extern ViridianGymRocker1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern ViridianGymRocker1BattleText   ; NOT YET DEFINED IN THE PORT
extern ViridianGymRocker1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern ViridianGymRocker2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern ViridianGymRocker2BattleText   ; NOT YET DEFINED IN THE PORT
extern ViridianGymRocker2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern ViridianGymTrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern ViridianGymTrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern ViridianGymTrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern ViridianGymTrainerHeader3   ; NOT YET DEFINED IN THE PORT
extern ViridianGymTrainerHeader4   ; NOT YET DEFINED IN THE PORT
extern ViridianGymTrainerHeader5   ; NOT YET DEFINED IN THE PORT
extern ViridianGymTrainerHeader6   ; NOT YET DEFINED IN THE PORT
extern ViridianGymTrainerHeader7   ; NOT YET DEFINED IN THE PORT
extern ViridianGymTrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern ViridianGym_Script   ; NOT YET DEFINED IN THE PORT
extern ViridianGym_TextPointers   ; NOT YET DEFINED IN THE PORT
extern _ViridianGymGiovanniPreBattleText   ; NOT YET DEFINED IN THE PORT
extern _ViridianGymGiovanniReceivedEarthBadgeText   ; NOT YET DEFINED IN THE PORT
extern _ViridianGymGuidePostBattleText   ; NOT YET DEFINED IN THE PORT
extern _ViridianGymGuidePreBattleText   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_VIRIDIANGYM_DEFAULT                     equ 0
SCRIPT_VIRIDIANGYM_GIOVANNI_POST_BATTLE        equ 3
SCRIPT_VIRIDIANGYM_PLAYER_SPINNING             equ 4
TEXT_VIRIDIANGYM_GIOVANNI                      equ 1
TEXT_VIRIDIANGYM_COOLTRAINER_M1                equ 2
TEXT_VIRIDIANGYM_HIKER1                        equ 3
TEXT_VIRIDIANGYM_ROCKER1                       equ 4
TEXT_VIRIDIANGYM_HIKER2                        equ 5
TEXT_VIRIDIANGYM_COOLTRAINER_M2                equ 6
TEXT_VIRIDIANGYM_HIKER3                        equ 7
TEXT_VIRIDIANGYM_ROCKER2                       equ 8
TEXT_VIRIDIANGYM_COOLTRAINER_M3                equ 9
TEXT_VIRIDIANGYM_GYM_GUIDE                     equ 10
TEXT_VIRIDIANGYM_REVIVE                        equ 11
TEXT_VIRIDIANGYM_GIOVANNI_EARTH_BADGE_INFO     equ 12
TEXT_VIRIDIANGYM_GIOVANNI_RECEIVED_TM27        equ 13
TEXT_VIRIDIANGYM_GIOVANNI_TM27_NO_ROOM         equ 14

; pret RAM names the port still spells in SCREAMING_SNAKE. Guarded, so
; this file assembles both before and after the memmap rename lands.
%ifndef wObtainedBadges
wObtainedBadges                                equ W_OBTAINED_BADGES
%endif
%ifndef wSimulatedJoypadStatesIndex
wSimulatedJoypadStatesIndex                    equ W_SIMULATED_JOYPAD_STATES_INDEX
%endif
%ifndef wXCoord
wXCoord                                        equ W_X_COORD
%endif
%ifndef wYCoord
wYCoord                                        equ W_Y_COORD
%endif

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wBeatGymFlags                                  equ 0xD729
wViridianGymCurScript                          equ 0xD5FA

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] ViridianGym_Script (scripts/ViridianGym.asm:2-11) — at scripts/ViridianGym.asm:2: .CityName is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .CityName
; PRET| 	ld de, .LeaderName
; PRET| 	call LoadGymLeaderAndCityName
; PRET| 	call EnableAutoTextBoxDrawing
; PRET| 	ld hl, ViridianGymTrainerHeaders
; PRET| 	ld de, ViridianGym_ScriptPointers
; PRET| 	ld a, [wViridianGymCurScript]
; PRET| 	call ExecuteCurMapScriptInTable
; PRET| 	ld [wViridianGymCurScript], a
; PRET| 	ret

; ---------------------------------------------------------------------------
; BAIL[inline-text-db] ViridianGym_Script.CityName (scripts/ViridianGym.asm:14-17) — at scripts/ViridianGym.asm:14: db "VIRIDIAN CITY@"
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	db "VIRIDIAN CITY@"
; PRET| 
; PRET| .LeaderName:
; PRET| 	db "GIOVANNI@"

ViridianGymResetScripts:
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov [ebp + wViridianGymCurScript], al
    mov [ebp + wCurMapScript], al
    ret

ViridianGym_ScriptPointers:
    dd ViridianGymDefaultScript
    dd DisplayEnemyTrainerTextAndStartBattle
    dd EndTrainerBattle
    dd ViridianGymGiovanniPostBattle
    dd ViridianGymPlayerSpinningScript

ViridianGymDefaultScript:
    mov al, [ebp + wYCoord]
    mov bh, al
    mov al, [ebp + wXCoord]
    mov bl, al
    mov esi, ViridianGymArrowTilePlayerMovement
    call DecodeArrowMovementRLE
    cmp al, 0xff
    jz CheckFightingMapTrainers
    call StartSimulatingJoypadStates
    mov esi, wMovementFlags
    or byte [ebp + esi], (1 << (BIT_SPINNING))
    mov al, SFX_ARROW_TILES
    call PlaySound
    mov al, PAD_BUTTONS | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    mov al, SCRIPT_VIRIDIANGYM_PLAYER_SPINNING
    mov [ebp + wCurMapScript], al
    ret

ViridianGymArrowTilePlayerMovement:
    db 11, 19
    dd ViridianGymArrowMovement1
    db 1, 19
    dd ViridianGymArrowMovement2
    db 2, 18
    dd ViridianGymArrowMovement3
    db 2, 11
    dd ViridianGymArrowMovement4
    db 10, 16
    dd ViridianGymArrowMovement5
    db 6, 4
    dd ViridianGymArrowMovement6
    db 13, 5
    dd ViridianGymArrowMovement7
    db 14, 4
    dd ViridianGymArrowMovement8
    db 15, 0
    dd ViridianGymArrowMovement9
    db 15, 1
    dd ViridianGymArrowMovement10
    db 16, 13
    dd ViridianGymArrowMovement11
    db 17, 13
    dd ViridianGymArrowMovement12
    db -1
ViridianGymArrowMovement1:
    db PAD_UP, 9
    db -1
ViridianGymArrowMovement2:
    db PAD_LEFT, 8
    db -1
ViridianGymArrowMovement3:
    db PAD_DOWN, 9
    db -1
ViridianGymArrowMovement4:
    db PAD_RIGHT, 6
    db -1
ViridianGymArrowMovement5:
    db PAD_DOWN, 2
    db -1
ViridianGymArrowMovement6:
    db PAD_DOWN, 7
    db -1
ViridianGymArrowMovement7:
    db PAD_RIGHT, 8
    db -1
ViridianGymArrowMovement8:
    db PAD_RIGHT, 9
    db -1
ViridianGymArrowMovement9:
    db PAD_UP, 8
    db -1
ViridianGymArrowMovement10:
    db PAD_UP, 6
    db -1
ViridianGymArrowMovement11:
    db PAD_LEFT, 6
    db -1
ViridianGymArrowMovement12:
    db PAD_LEFT, 12
    db -1

ViridianGymPlayerSpinningScript:
    mov al, [ebp + wSimulatedJoypadStatesIndex]
    test al, al
    jnz .ViridianGymLoadSpinnerArrow
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov esi, wMovementFlags
    and byte [ebp + esi], ~(1 << (BIT_SPINNING)) & 0xFF
    mov al, SCRIPT_VIRIDIANGYM_DEFAULT
    mov [ebp + wCurMapScript], al
    ret

.ViridianGymLoadSpinnerArrow:
; DEVIATION{class=banking; pret=macros/farcall.asm:farjp; behavior=bank switch dropped, jmp goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    jmp LoadSpinnerArrowTiles

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] ViridianGymGiovanniPostBattle (scripts/ViridianGym.asm:132-150) — at scripts/ViridianGym.asm:145: .bag_full is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, [wIsInBattle]
; PRET| 	cp $ff
; PRET| 	jp z, ViridianGymResetScripts
; PRET| 	ld a, PAD_CTRL_PAD
; PRET| 	ld [wJoyIgnore], a
; PRET| ; fallthrough
; PRET| ViridianGymReceiveTM27:
; PRET| 	ld a, TEXT_VIRIDIANGYM_GIOVANNI_EARTH_BADGE_INFO
; PRET| 	ldh [hTextID], a
; PRET| 	call DisplayTextID
; PRET| 	SetEvent EVENT_BEAT_VIRIDIAN_GYM_GIOVANNI
; PRET| 	lb bc, TM_FISSURE, 1
; PRET| 	call GiveItem
; PRET| 	jr nc, .bag_full
; PRET| 	ld a, TEXT_VIRIDIANGYM_GIOVANNI_RECEIVED_TM27
; PRET| 	ldh [hTextID], a
; PRET| 	call DisplayTextID
; PRET| 	SetEvent EVENT_GOT_TM27
; PRET| 	jr .gym_victory

; ---------------------------------------------------------------------------
; BAIL[event-range-macro] ViridianGymReceiveTM27.bag_full (scripts/ViridianGym.asm:152-168) — at scripts/ViridianGym.asm:162: SetEventRange EVENT_BEAT_VIRIDIAN_GYM_TRAINER_0, EVENT_BEAT_VIRIDIAN_GYM_TRAINER_7
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, TEXT_VIRIDIANGYM_GIOVANNI_TM27_NO_ROOM
; PRET| 	ldh [hTextID], a
; PRET| 	call DisplayTextID
; PRET| .gym_victory
; PRET| 	ld hl, wObtainedBadges
; PRET| 	set BIT_EARTHBADGE, [hl]
; PRET| 	ld hl, wBeatGymFlags
; PRET| 	set BIT_EARTHBADGE, [hl]
; PRET| 
; PRET| 	; deactivate gym trainers
; PRET| 	SetEventRange EVENT_BEAT_VIRIDIAN_GYM_TRAINER_0, EVENT_BEAT_VIRIDIAN_GYM_TRAINER_7
; PRET| 
; PRET| 	ld a, TOGGLE_ROUTE_22_RIVAL_2
; PRET| 	ld [wToggleableObjectIndex], a
; PRET| 	predef ShowObject
; PRET| 	SetEvents EVENT_2ND_ROUTE22_RIVAL_BATTLE, EVENT_ROUTE22_RIVAL_WANTS_BATTLE
; PRET| 	jp ViridianGymResetScripts

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] ViridianGym_TextPointers (scripts/ViridianGym.asm:171-205) — a generated asset already defines ViridianGymTrainerHeaders
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	def_text_pointers
; PRET| 	dw_const ViridianGymGiovanniText,               TEXT_VIRIDIANGYM_GIOVANNI
; PRET| 	dw_const ViridianGymCooltrainerM1Text,          TEXT_VIRIDIANGYM_COOLTRAINER_M1
; PRET| 	dw_const ViridianGymHiker1Text,                 TEXT_VIRIDIANGYM_HIKER1
; PRET| 	dw_const ViridianGymRocker1Text,                TEXT_VIRIDIANGYM_ROCKER1
; PRET| 	dw_const ViridianGymHiker2Text,                 TEXT_VIRIDIANGYM_HIKER2
; PRET| 	dw_const ViridianGymCooltrainerM2Text,          TEXT_VIRIDIANGYM_COOLTRAINER_M2
; PRET| 	dw_const ViridianGymHiker3Text,                 TEXT_VIRIDIANGYM_HIKER3
; PRET| 	dw_const ViridianGymRocker2Text,                TEXT_VIRIDIANGYM_ROCKER2
; PRET| 	dw_const ViridianGymCooltrainerM3Text,          TEXT_VIRIDIANGYM_COOLTRAINER_M3
; PRET| 	dw_const ViridianGymGymGuideText,               TEXT_VIRIDIANGYM_GYM_GUIDE
; PRET| 	dw_const PickUpItemText,                        TEXT_VIRIDIANGYM_REVIVE
; PRET| 	dw_const ViridianGymGiovanniEarthBadgeInfoText, TEXT_VIRIDIANGYM_GIOVANNI_EARTH_BADGE_INFO
; PRET| 	dw_const ViridianGymGiovanniReceivedTM27Text,   TEXT_VIRIDIANGYM_GIOVANNI_RECEIVED_TM27
; PRET| 	dw_const ViridianGymGiovanniTM27NoRoomText,     TEXT_VIRIDIANGYM_GIOVANNI_TM27_NO_ROOM
; PRET| 
; PRET| ViridianGymTrainerHeaders:
; PRET| 	def_trainers 2
; PRET| ViridianGymTrainerHeader0:
; PRET| 	trainer EVENT_BEAT_VIRIDIAN_GYM_TRAINER_0, 4, ViridianGymCooltrainerM1BattleText, ViridianGymCooltrainerM1EndBattleText, ViridianGymCooltrainerM1AfterBattleText
; PRET| ViridianGymTrainerHeader1:
; PRET| 	trainer EVENT_BEAT_VIRIDIAN_GYM_TRAINER_1, 4, ViridianGymHiker1BattleText, ViridianGymHiker1EndBattleText, ViridianGymHiker1AfterBattleText
; PRET| ViridianGymTrainerHeader2:
; PRET| 	trainer EVENT_BEAT_VIRIDIAN_GYM_TRAINER_2, 4, ViridianGymRocker1BattleText, ViridianGymRocker1EndBattleText, ViridianGymRocker1AfterBattleText
; PRET| ViridianGymTrainerHeader3:
; PRET| 	trainer EVENT_BEAT_VIRIDIAN_GYM_TRAINER_3, 2, ViridianGymHiker2BattleText, ViridianGymHiker2EndBattleText, ViridianGymHiker2AfterBattleText
; PRET| ViridianGymTrainerHeader4:
; PRET| 	trainer EVENT_BEAT_VIRIDIAN_GYM_TRAINER_4, 3, ViridianGymCooltrainerM2BattleText, ViridianGymCooltrainerM2EndBattleText, ViridianGymCooltrainerM2AfterBattleText
; PRET| ViridianGymTrainerHeader5:
; PRET| 	trainer EVENT_BEAT_VIRIDIAN_GYM_TRAINER_5, 4, ViridianGymHiker3BattleText, ViridianGymHiker3EndBattleText, ViridianGymHiker3AfterBattleText
; PRET| ViridianGymTrainerHeader6:
; PRET| 	trainer EVENT_BEAT_VIRIDIAN_GYM_TRAINER_6, 3, ViridianGymRocker2BattleText, ViridianGymRocker2EndBattleText, ViridianGymRocker2AfterBattleText
; PRET| ViridianGymTrainerHeader7:
; PRET| 	trainer EVENT_BEAT_VIRIDIAN_GYM_TRAINER_7, 4, ViridianGymCooltrainerM3BattleText, ViridianGymCooltrainerM3EndBattleText, ViridianGymCooltrainerM3AfterBattleText
; PRET| 	db -1 ; end

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] ViridianGymGiovanniText (scripts/ViridianGym.asm:209-215) — at scripts/ViridianGym.asm:210: .beforeBeat is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEvent EVENT_BEAT_VIRIDIAN_GYM_GIOVANNI
; PRET| 	jr z, .beforeBeat
; PRET| 	CheckEventReuseA EVENT_GOT_TM27
; PRET| 	jr nz, .afterBeat
; PRET| 	call z, ViridianGymReceiveTM27
; PRET| 	call DisableWaitingAfterTextDisplay
; PRET| 	jr .text_script_end

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] ViridianGymGiovanniText.afterBeat (scripts/ViridianGym.asm:217-228) — at scripts/ViridianGym.asm:219: .PostBattleAdviceText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, $1
; PRET| 	ld [wDoNotWaitForButtonPressAfterDisplayingText], a
; PRET| 	ld hl, .PostBattleAdviceText
; PRET| 	call PrintText
; PRET| 	call GBFadeOutToBlack
; PRET| 	ld a, TOGGLE_VIRIDIAN_GYM_GIOVANNI
; PRET| 	ld [wToggleableObjectIndex], a
; PRET| 	predef HideObject
; PRET| 	call UpdateSprites
; PRET| 	call Delay3
; PRET| 	call GBFadeInFromBlack
; PRET| 	jr .text_script_end

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] ViridianGymGiovanniText.beforeBeat (scripts/ViridianGym.asm:230-247) — at scripts/ViridianGym.asm:230: .PreBattleText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .PreBattleText
; PRET| 	call PrintText
; PRET| 	ld hl, wStatusFlags3
; PRET| 	set BIT_TALKED_TO_TRAINER, [hl]
; PRET| 	set BIT_PRINT_END_BATTLE_TEXT, [hl]
; PRET| 	ld hl, .ReceivedEarthBadgeText
; PRET| 	ld de, .ReceivedEarthBadgeText
; PRET| 	call SaveEndBattleTextPointers
; PRET| 	ldh a, [hSpriteIndex]
; PRET| 	ld [wSpriteIndex], a
; PRET| 	call EngageMapTrainer
; PRET| 	call InitBattleEnemyParameters
; PRET| 	ld a, $8
; PRET| 	ld [wGymLeaderNo], a
; PRET| 	ld a, SCRIPT_VIRIDIANGYM_GIOVANNI_POST_BATTLE
; PRET| 	ld [wViridianGymCurScript], a
; PRET| .text_script_end
; PRET| 	jp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[text-sound-command-unported] ViridianGymGiovanniText.PreBattleText (scripts/ViridianGym.asm:250-277) — at scripts/ViridianGym.asm:255: sound_level_up ; probably supposed to play SFX_GET_ITEM_1 but the wrong music bank is loaded
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _ViridianGymGiovanniPreBattleText
; PRET| 	text_end
; PRET| 
; PRET| .ReceivedEarthBadgeText:
; PRET| 	text_far _ViridianGymGiovanniReceivedEarthBadgeText
; PRET| 	sound_level_up ; probably supposed to play SFX_GET_ITEM_1 but the wrong music bank is loaded
; PRET| 	text_end
; PRET| 
; PRET| .PostBattleAdviceText:
; PRET| 	text_far _ViridianGymGiovanniPostBattleAdviceText
; PRET| 	text_waitbutton
; PRET| 	text_end
; PRET| 
; PRET| ViridianGymGiovanniEarthBadgeInfoText:
; PRET| 	text_far _ViridianGymGiovanniEarthBadgeInfoText
; PRET| 	text_end
; PRET| 
; PRET| ViridianGymGiovanniReceivedTM27Text:
; PRET| 	text_far _ViridianGymGiovanniReceivedTM27Text
; PRET| 	sound_get_item_1
; PRET| 
; PRET| ViridianGymGiovanniTM27ExplanationText:
; PRET| 	text_far _ViridianGymGiovanniTM27ExplanationText
; PRET| 	text_end
; PRET| 
; PRET| ViridianGymGiovanniTM27NoRoomText:
; PRET| 	text_far _ViridianGymGiovanniTM27NoRoomText
; PRET| 	text_end

ViridianGymCooltrainerM1Text:
    mov esi, ViridianGymTrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] ViridianGymCooltrainerM1BattleText (scripts/ViridianGym.asm:286-295) — a generated asset already defines ViridianGymCooltrainerM1BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _ViridianGymCooltrainerM1BattleText
; PRET| 	text_end
; PRET| 
; PRET| ViridianGymCooltrainerM1EndBattleText:
; PRET| 	text_far _ViridianGymCooltrainerM1EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| ViridianGymCooltrainerM1AfterBattleText:
; PRET| 	text_far _ViridianGymCooltrainerM1AfterBattleText
; PRET| 	text_end

ViridianGymHiker1Text:
    mov esi, ViridianGymTrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] ViridianGymHiker1BattleText (scripts/ViridianGym.asm:304-313) — a generated asset already defines ViridianGymHiker1BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _ViridianGymHiker1BattleText
; PRET| 	text_end
; PRET| 
; PRET| ViridianGymHiker1EndBattleText:
; PRET| 	text_far _ViridianGymHiker1EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| ViridianGymHiker1AfterBattleText:
; PRET| 	text_far _ViridianGymHiker1AfterBattleText
; PRET| 	text_end

ViridianGymRocker1Text:
    mov esi, ViridianGymTrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] ViridianGymRocker1BattleText (scripts/ViridianGym.asm:322-331) — a generated asset already defines ViridianGymRocker1BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _ViridianGymRocker1BattleText
; PRET| 	text_end
; PRET| 
; PRET| ViridianGymRocker1EndBattleText:
; PRET| 	text_far _ViridianGymRocker1EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| ViridianGymRocker1AfterBattleText:
; PRET| 	text_far _ViridianGymRocker1AfterBattleText
; PRET| 	text_end

ViridianGymHiker2Text:
    mov esi, ViridianGymTrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] ViridianGymHiker2BattleText (scripts/ViridianGym.asm:340-349) — a generated asset already defines ViridianGymHiker2BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _ViridianGymHiker2BattleText
; PRET| 	text_end
; PRET| 
; PRET| ViridianGymHiker2EndBattleText:
; PRET| 	text_far _ViridianGymHiker2EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| ViridianGymHiker2AfterBattleText:
; PRET| 	text_far _ViridianGymHiker2AfterBattleText
; PRET| 	text_end

ViridianGymCooltrainerM2Text:
    mov esi, ViridianGymTrainerHeader4
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] ViridianGymCooltrainerM2BattleText (scripts/ViridianGym.asm:358-367) — a generated asset already defines ViridianGymCooltrainerM2BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _ViridianGymCooltrainerM2BattleText
; PRET| 	text_end
; PRET| 
; PRET| ViridianGymCooltrainerM2EndBattleText:
; PRET| 	text_far _ViridianGymCooltrainerM2EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| ViridianGymCooltrainerM2AfterBattleText:
; PRET| 	text_far _ViridianGymCooltrainerM2AfterBattleText
; PRET| 	text_end

ViridianGymHiker3Text:
    mov esi, ViridianGymTrainerHeader5
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] ViridianGymHiker3BattleText (scripts/ViridianGym.asm:376-385) — a generated asset already defines ViridianGymHiker3BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _ViridianGymHiker3BattleText
; PRET| 	text_end
; PRET| 
; PRET| ViridianGymHiker3EndBattleText:
; PRET| 	text_far _ViridianGymHiker3EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| ViridianGymHiker3AfterBattleText:
; PRET| 	text_far _ViridianGymHiker3AfterBattleText
; PRET| 	text_end

ViridianGymRocker2Text:
    mov esi, ViridianGymTrainerHeader6
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] ViridianGymRocker2BattleText (scripts/ViridianGym.asm:394-403) — a generated asset already defines ViridianGymRocker2BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _ViridianGymRocker2BattleText
; PRET| 	text_end
; PRET| 
; PRET| ViridianGymRocker2EndBattleText:
; PRET| 	text_far _ViridianGymRocker2EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| ViridianGymRocker2AfterBattleText:
; PRET| 	text_far _ViridianGymRocker2AfterBattleText
; PRET| 	text_end

ViridianGymCooltrainerM3Text:
    mov esi, ViridianGymTrainerHeader7
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] ViridianGymCooltrainerM3BattleText (scripts/ViridianGym.asm:412-421) — a generated asset already defines ViridianGymCooltrainerM3BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _ViridianGymCooltrainerM3BattleText
; PRET| 	text_end
; PRET| 
; PRET| ViridianGymCooltrainerM3EndBattleText:
; PRET| 	text_far _ViridianGymCooltrainerM3EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| ViridianGymCooltrainerM3AfterBattleText:
; PRET| 	text_far _ViridianGymCooltrainerM3AfterBattleText
; PRET| 	text_end

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] ViridianGymGymGuideText (scripts/ViridianGym.asm:425-429) — at scripts/ViridianGym.asm:426: .afterBeat is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEvent EVENT_BEAT_VIRIDIAN_GYM_GIOVANNI
; PRET| 	jr nz, .afterBeat
; PRET| 	ld hl, ViridianGymGuidePreBattleText
; PRET| 	call PrintText
; PRET| 	jr .done

.afterBeat:
    mov esi, ViridianGymGuidePostBattleText
    call PrintText
.done:
    jmp TextScriptEnd

ViridianGymGuidePreBattleText:
    text_far _ViridianGymGuidePreBattleText
    text_end
ViridianGymGuidePostBattleText:
    text_far _ViridianGymGuidePostBattleText
    text_end
