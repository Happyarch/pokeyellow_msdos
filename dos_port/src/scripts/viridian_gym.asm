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
%include "assets/gym_names.inc"
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
global ViridianGymGiovanniEarthBadgeInfoText
global ViridianGymGiovanniPostBattle
global ViridianGymGiovanniReceivedTM27Text
global ViridianGymGiovanniTM27ExplanationText
global ViridianGymGiovanniTM27NoRoomText
global ViridianGymGiovanniText
global ViridianGymGuidePostBattleText
global ViridianGymGuidePreBattleText
global ViridianGymGymGuideText
global ViridianGymHiker1Text
global ViridianGymHiker2Text
global ViridianGymHiker3Text
global ViridianGymPlayerSpinningScript
global ViridianGymReceiveTM27
global ViridianGymResetScripts
global ViridianGymRocker1Text
global ViridianGymRocker2Text
global ViridianGym_ScriptPointers

extern Bankswitch
extern CheckFightingMapTrainers
extern DecodeArrowMovementRLE
extern Delay3
extern DisableWaitingAfterTextDisplay   ; NOT YET DEFINED IN THE PORT
extern DisplayEnemyTrainerTextAndStartBattle
extern DisplayTextID
extern EnableAutoTextBoxDrawing
extern EndTrainerBattle
extern EngageMapTrainer
extern ExecuteCurMapScriptInTable
extern GBFadeInFromBlack
extern GBFadeOutToBlack
extern GiveItem
extern HideObject
extern InitBattleEnemyParameters
extern LoadGymLeaderAndCityName
extern LoadSpinnerArrowTiles
extern PlaySound
extern PrintText
extern SaveEndBattleTextPointers
extern ShowObject
extern StartSimulatingJoypadStates
extern TalkToTrainer
extern TextScriptEnd
extern UpdateSprites
extern ViridianGymCooltrainerM1BattleText   ; NOT YET DEFINED IN THE PORT
extern ViridianGymCooltrainerM2BattleText   ; NOT YET DEFINED IN THE PORT
extern ViridianGymCooltrainerM3BattleText   ; NOT YET DEFINED IN THE PORT
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
extern _ViridianGymGiovanniEarthBadgeInfoText   ; NOT YET DEFINED IN THE PORT
extern _ViridianGymGiovanniPostBattleAdviceText   ; NOT YET DEFINED IN THE PORT
extern _ViridianGymGiovanniPreBattleText   ; NOT YET DEFINED IN THE PORT
extern _ViridianGymGiovanniReceivedEarthBadgeText   ; NOT YET DEFINED IN THE PORT
extern _ViridianGymGiovanniReceivedTM27Text   ; NOT YET DEFINED IN THE PORT
extern _ViridianGymGiovanniTM27ExplanationText   ; NOT YET DEFINED IN THE PORT
extern _ViridianGymGiovanniTM27NoRoomText   ; NOT YET DEFINED IN THE PORT
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
; BAIL[host-pointer-in-16bit-reg] ViridianGym_Script (scripts/ViridianGym.asm:2-11) — at scripts/ViridianGym.asm:3: de cannot hold the 32-bit address of .LeaderName; callee LoadGymLeaderAndCityName has no abi.json entry
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

%assign event_byte -1
%assign event_byte_a -1
.CityName:
    TEXT_ViridianGym_Script_CityName
.LeaderName:
    TEXT_ViridianGym_Script_LeaderName

%assign event_byte -1
%assign event_byte_a -1
ViridianGymResetScripts:
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov [ebp + wViridianGymCurScript], al
    mov [ebp + wCurMapScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
ViridianGym_ScriptPointers:
    dd ViridianGymDefaultScript
    dd DisplayEnemyTrainerTextAndStartBattle
    dd EndTrainerBattle
    dd ViridianGymGiovanniPostBattle
    dd ViridianGymPlayerSpinningScript

%assign event_byte -1
%assign event_byte_a -1
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

%assign event_byte -1
%assign event_byte_a -1
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

%assign event_byte -1
%assign event_byte_a -1
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

%assign event_byte -1
%assign event_byte_a -1
.ViridianGymLoadSpinnerArrow:
; DEVIATION{class=banking; pret=macros/farcall.asm:farjp; behavior=bank switch dropped, jmp goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    jmp LoadSpinnerArrowTiles

%assign event_byte -1
%assign event_byte_a -1
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

%assign event_byte -1
%assign event_byte_a -1
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
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call ShowObject
    SetEvents EVENT_2ND_ROUTE22_RIVAL_BATTLE, EVENT_ROUTE22_RIVAL_WANTS_BATTLE
    jmp ViridianGymResetScripts

; ViridianGym_TextPointers (scripts/ViridianGym.asm:171-205) — not re-emitted: ViridianGymTrainerHeaders is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
ViridianGymGiovanniText:
    CheckEvent EVENT_BEAT_VIRIDIAN_GYM_GIOVANNI
    jz .beforeBeat
    CheckEventReuseA EVENT_GOT_TM27
    jnz .afterBeat
    jnz .sk_213
        call ViridianGymReceiveTM27
.sk_213:
    call DisableWaitingAfterTextDisplay
    jmp .text_script_end

%assign event_byte -1
%assign event_byte_a -1
.afterBeat:
    mov al, 0x1
    mov [ebp + wDoNotWaitForButtonPressAfterDisplayingText], al
    mov esi, .PostBattleAdviceText
    call PrintText
    call GBFadeOutToBlack
    mov al, 49
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call HideObject
    call UpdateSprites
    call Delay3
    call GBFadeInFromBlack
    jmp .text_script_end

%assign event_byte -1
%assign event_byte_a -1
.beforeBeat:
    mov esi, .PreBattleText
    call PrintText
    mov esi, wStatusFlags3
    or byte [ebp + esi], (1 << (BIT_TALKED_TO_TRAINER))
    or byte [ebp + esi], (1 << (BIT_PRINT_END_BATTLE_TEXT))
    mov esi, .ReceivedEarthBadgeText
    mov edx, .ReceivedEarthBadgeText   ; pret: ld de, .ReceivedEarthBadgeText — SaveEndBattleTextPointers takes it in EDX
    call SaveEndBattleTextPointers
    mov al, [ebp + hSpriteIndex]
    mov [ebp + wSpriteIndex], al
    call EngageMapTrainer
    call InitBattleEnemyParameters
    mov al, 0x8
    mov [ebp + wGymLeaderNo], al
    mov al, SCRIPT_VIRIDIANGYM_GIOVANNI_POST_BATTLE
    mov [ebp + wViridianGymCurScript], al
.text_script_end:
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.PreBattleText:
    text_far _ViridianGymGiovanniPreBattleText
    text_end
.ReceivedEarthBadgeText:
    text_far _ViridianGymGiovanniReceivedEarthBadgeText
    sound_level_up
    text_end
.PostBattleAdviceText:
    text_far _ViridianGymGiovanniPostBattleAdviceText
    text_waitbutton
    text_end
ViridianGymGiovanniEarthBadgeInfoText:
    text_far _ViridianGymGiovanniEarthBadgeInfoText
    text_end
ViridianGymGiovanniReceivedTM27Text:
    text_far _ViridianGymGiovanniReceivedTM27Text
    sound_get_item_1
ViridianGymGiovanniTM27ExplanationText:
    text_far _ViridianGymGiovanniTM27ExplanationText
    text_end
ViridianGymGiovanniTM27NoRoomText:
    text_far _ViridianGymGiovanniTM27NoRoomText
    text_end

%assign event_byte -1
%assign event_byte_a -1
ViridianGymCooltrainerM1Text:
    mov esi, ViridianGymTrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; ViridianGymCooltrainerM1BattleText (scripts/ViridianGym.asm:286-295) — not re-emitted: ViridianGymCooltrainerM1BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
ViridianGymHiker1Text:
    mov esi, ViridianGymTrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

; ViridianGymHiker1BattleText (scripts/ViridianGym.asm:304-313) — not re-emitted: ViridianGymHiker1BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
ViridianGymRocker1Text:
    mov esi, ViridianGymTrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

; ViridianGymRocker1BattleText (scripts/ViridianGym.asm:322-331) — not re-emitted: ViridianGymRocker1BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
ViridianGymHiker2Text:
    mov esi, ViridianGymTrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

; ViridianGymHiker2BattleText (scripts/ViridianGym.asm:340-349) — not re-emitted: ViridianGymHiker2BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
ViridianGymCooltrainerM2Text:
    mov esi, ViridianGymTrainerHeader4
    call TalkToTrainer
    jmp TextScriptEnd

; ViridianGymCooltrainerM2BattleText (scripts/ViridianGym.asm:358-367) — not re-emitted: ViridianGymCooltrainerM2BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
ViridianGymHiker3Text:
    mov esi, ViridianGymTrainerHeader5
    call TalkToTrainer
    jmp TextScriptEnd

; ViridianGymHiker3BattleText (scripts/ViridianGym.asm:376-385) — not re-emitted: ViridianGymHiker3BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
ViridianGymRocker2Text:
    mov esi, ViridianGymTrainerHeader6
    call TalkToTrainer
    jmp TextScriptEnd

; ViridianGymRocker2BattleText (scripts/ViridianGym.asm:394-403) — not re-emitted: ViridianGymRocker2BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
ViridianGymCooltrainerM3Text:
    mov esi, ViridianGymTrainerHeader7
    call TalkToTrainer
    jmp TextScriptEnd

; ViridianGymCooltrainerM3BattleText (scripts/ViridianGym.asm:412-421) — not re-emitted: ViridianGymCooltrainerM3BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
ViridianGymGymGuideText:
    CheckEvent EVENT_BEAT_VIRIDIAN_GYM_GIOVANNI
    jnz .afterBeat
    mov esi, ViridianGymGuidePreBattleText
    call PrintText
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.afterBeat:
    mov esi, ViridianGymGuidePostBattleText
    call PrintText
.done:
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
ViridianGymGuidePreBattleText:
    text_far _ViridianGymGuidePreBattleText
    text_end
ViridianGymGuidePostBattleText:
    text_far _ViridianGymGuidePostBattleText
    text_end
