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
%include "assets/trainer_headers.inc"

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
global ViridianGymGiovanniPostBattle
global ViridianGymGuidePostBattleText
global ViridianGymGuidePreBattleText
global ViridianGymHiker1Text
global ViridianGymHiker2Text
global ViridianGymHiker3Text
global ViridianGymPlayerSpinningScript
global ViridianGymReceiveTM27
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
extern PlaySound   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern SaveEndBattleTextPointers   ; NOT YET DEFINED IN THE PORT
extern ShowObject   ; NOT YET DEFINED IN THE PORT
extern StartSimulatingJoypadStates   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern UpdateSprites   ; NOT YET DEFINED IN THE PORT
extern ViridianGymCooltrainerM1BattleText   ; NOT YET DEFINED IN THE PORT
extern ViridianGymCooltrainerM2BattleText   ; NOT YET DEFINED IN THE PORT
extern ViridianGymCooltrainerM3BattleText   ; NOT YET DEFINED IN THE PORT
extern ViridianGymGiovanniEarthBadgeInfoText   ; NOT YET DEFINED IN THE PORT
extern ViridianGymGiovanniReceivedTM27Text   ; NOT YET DEFINED IN THE PORT
extern ViridianGymGiovanniTM27ExplanationText   ; NOT YET DEFINED IN THE PORT
extern ViridianGymGiovanniTM27NoRoomText   ; NOT YET DEFINED IN THE PORT
extern ViridianGymGiovanniText   ; NOT YET DEFINED IN THE PORT
extern ViridianGymGymGuideText   ; NOT YET DEFINED IN THE PORT
extern ViridianGymHiker1BattleText   ; NOT YET DEFINED IN THE PORT
extern ViridianGymHiker2BattleText   ; NOT YET DEFINED IN THE PORT
extern ViridianGymHiker3BattleText   ; NOT YET DEFINED IN THE PORT
extern ViridianGymRocker1BattleText   ; NOT YET DEFINED IN THE PORT
extern ViridianGymRocker2BattleText   ; NOT YET DEFINED IN THE PORT
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
TEXT_VIRIDIANGYM_GIOVANNI_EARTH_BADGE_INFO     equ 12
TEXT_VIRIDIANGYM_GIOVANNI_RECEIVED_TM27        equ 13
TEXT_VIRIDIANGYM_GIOVANNI_TM27_NO_ROOM         equ 14

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

ViridianGymGiovanniPostBattle:
    mov al, [ebp + wIsInBattle]
    cmp al, 0xff
    jz ViridianGymResetScripts
    mov al, PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
ViridianGymReceiveTM27:
    mov al, TEXT_VIRIDIANGYM_GIOVANNI_EARTH_BADGE_INFO
    mov [ebp + hTextID], al
    call DisplayTextID
    pushfd    ; SM83 form writes no flags
        SetEvent EVENT_BEAT_VIRIDIAN_GYM_GIOVANNI
    popfd
    mov bx, ((229) << 8) | (1)
    call GiveItem
    jae .bag_full
    mov al, TEXT_VIRIDIANGYM_GIOVANNI_RECEIVED_TM27
    mov [ebp + hTextID], al
    call DisplayTextID
    SetEvent EVENT_GOT_TM27
    jmp .gym_victory

.bag_full:
    mov al, TEXT_VIRIDIANGYM_GIOVANNI_TM27_NO_ROOM
    mov [ebp + hTextID], al
    call DisplayTextID
.gym_victory:
    mov esi, wObtainedBadges
    or byte [ebp + esi], (1 << (7))
    mov esi, wBeatGymFlags
    or byte [ebp + esi], (1 << (7))
    SetEventRange EVENT_BEAT_VIRIDIAN_GYM_TRAINER_0, EVENT_BEAT_VIRIDIAN_GYM_TRAINER_7
    mov al, 36
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and the predef id is not left in A because no reader is live; evidence=PredefPointers is unported and the flat model needs no bank switch, dataflow shows A dead after this site; lifetime=retired when PredefPointers is ported}
    call ShowObject
    SetEvents EVENT_2ND_ROUTE22_RIVAL_BATTLE, EVENT_ROUTE22_RIVAL_WANTS_BATTLE
    jmp ViridianGymResetScripts

; ViridianGym_TextPointers (scripts/ViridianGym.asm:171-205) — not re-emitted: ViridianGymTrainerHeaders is already defined in assets/trainer_headers.inc.

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

; ViridianGymCooltrainerM1BattleText (scripts/ViridianGym.asm:286-295) — not re-emitted: ViridianGymCooltrainerM1BattleText is already defined in assets/trainer_headers.inc.

ViridianGymHiker1Text:
    mov esi, ViridianGymTrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

; ViridianGymHiker1BattleText (scripts/ViridianGym.asm:304-313) — not re-emitted: ViridianGymHiker1BattleText is already defined in assets/trainer_headers.inc.

ViridianGymRocker1Text:
    mov esi, ViridianGymTrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

; ViridianGymRocker1BattleText (scripts/ViridianGym.asm:322-331) — not re-emitted: ViridianGymRocker1BattleText is already defined in assets/trainer_headers.inc.

ViridianGymHiker2Text:
    mov esi, ViridianGymTrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

; ViridianGymHiker2BattleText (scripts/ViridianGym.asm:340-349) — not re-emitted: ViridianGymHiker2BattleText is already defined in assets/trainer_headers.inc.

ViridianGymCooltrainerM2Text:
    mov esi, ViridianGymTrainerHeader4
    call TalkToTrainer
    jmp TextScriptEnd

; ViridianGymCooltrainerM2BattleText (scripts/ViridianGym.asm:358-367) — not re-emitted: ViridianGymCooltrainerM2BattleText is already defined in assets/trainer_headers.inc.

ViridianGymHiker3Text:
    mov esi, ViridianGymTrainerHeader5
    call TalkToTrainer
    jmp TextScriptEnd

; ViridianGymHiker3BattleText (scripts/ViridianGym.asm:376-385) — not re-emitted: ViridianGymHiker3BattleText is already defined in assets/trainer_headers.inc.

ViridianGymRocker2Text:
    mov esi, ViridianGymTrainerHeader6
    call TalkToTrainer
    jmp TextScriptEnd

; ViridianGymRocker2BattleText (scripts/ViridianGym.asm:394-403) — not re-emitted: ViridianGymRocker2BattleText is already defined in assets/trainer_headers.inc.

ViridianGymCooltrainerM3Text:
    mov esi, ViridianGymTrainerHeader7
    call TalkToTrainer
    jmp TextScriptEnd

; ViridianGymCooltrainerM3BattleText (scripts/ViridianGym.asm:412-421) — not re-emitted: ViridianGymCooltrainerM3BattleText is already defined in assets/trainer_headers.inc.

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
