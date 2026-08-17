; VermilionGym.asm — translated from pret scripts/VermilionGym.asm by dos_port/tools/sm83xlat.
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
%include "assets/script_strings.inc"
%include "assets/trainer_headers.inc"

global VermilionGymGentlemanText
global VermilionGymGymGuideText
global VermilionGymLTSurgeAfterBattleScript
global VermilionGymLTSurgeReceiveTM24Script
global VermilionGymLTSurgeReceivedTM24Text
global VermilionGymLTSurgeReceivedThunderBadgeText
global VermilionGymLTSurgeTM24NoRoomText
global VermilionGymLTSurgeText
global VermilionGymLTSurgeThunderBadgeInfoText
global VermilionGymResetScripts
global VermilionGymSailorText
global VermilionGymSetDoorTile
global VermilionGymSuperNerdText
global VermilionGym_Script
global VermilionGym_ScriptPointers

extern CheckFightingMapTrainers
extern DisableWaitingAfterTextDisplay   ; NOT YET DEFINED IN THE PORT
extern DisplayEnemyTrainerTextAndStartBattle
extern DisplayTextID
extern EnableAutoTextBoxDrawing
extern EndTrainerBattle
extern EngageMapTrainer
extern ExecuteCurMapScriptInTable
extern GiveItem
extern InitBattleEnemyParameters
extern LoadGymLeaderAndCityName
extern PlaySound
extern PrintText
extern ReplaceTileBlock
extern SaveEndBattleTextPointers
extern TalkToTrainer
extern TextScriptEnd
extern VermilionGymGentlemanBattleText   ; NOT YET DEFINED IN THE PORT
extern VermilionGymSailorBattleText   ; NOT YET DEFINED IN THE PORT
extern VermilionGymSuperNerdBattleText   ; NOT YET DEFINED IN THE PORT
extern VermilionGymTrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern VermilionGymTrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern VermilionGymTrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern VermilionGymTrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern VermilionGym_TextPointers   ; NOT YET DEFINED IN THE PORT
extern _TM24ExplanationText   ; NOT YET DEFINED IN THE PORT
extern _VermilionGymGymGuideBeatLTSurgeText   ; NOT YET DEFINED IN THE PORT
extern _VermilionGymGymGuideChampInMakingText   ; NOT YET DEFINED IN THE PORT
extern _VermilionGymLTSurgePostBattleAdviceText   ; NOT YET DEFINED IN THE PORT
extern _VermilionGymLTSurgePreBattleText   ; NOT YET DEFINED IN THE PORT
extern _VermilionGymLTSurgeReceivedTM24Text   ; NOT YET DEFINED IN THE PORT
extern _VermilionGymLTSurgeReceivedThunderBadgeText   ; NOT YET DEFINED IN THE PORT
extern _VermilionGymLTSurgeTM24NoRoomText   ; NOT YET DEFINED IN THE PORT
extern _VermilionGymLTSurgeThunderBadgeInfoText   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_VERMILIONGYM_LT_SURGE_AFTER_BATTLE      equ 3
TEXT_VERMILIONGYM_LT_SURGE_THUNDER_BADGE_INFO  equ 6
TEXT_VERMILIONGYM_LT_SURGE_RECEIVED_TM24       equ 7
TEXT_VERMILIONGYM_LT_SURGE_TM24_NO_ROOM        equ 8

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wBeatGymFlags                                  equ 0xD729
wVermilionGymCurScript                         equ 0xD5FD

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
VermilionGym_Script:
    mov esi, wCurrentMapScriptFlags
    test byte [ebp + esi], (1 << (BIT_CUR_MAP_LOADED_1))
    pushfd    ; SM83 form writes no flags
        and byte [ebp + esi], ~(1 << (BIT_CUR_MAP_LOADED_1)) & 0xFF
    popfd
    push esi
    jz .sk_6
        call .LoadNames
.sk_6:
    pop esi
    test byte [ebp + esi], (1 << (BIT_CUR_MAP_LOADED_2))
    pushfd    ; SM83 form writes no flags
        and byte [ebp + esi], ~(1 << (BIT_CUR_MAP_LOADED_2)) & 0xFF
    popfd
    jz .sk_10
        call VermilionGymSetDoorTile
.sk_10:
    call EnableAutoTextBoxDrawing
    mov esi, VermilionGymTrainerHeaders
    mov edi, VermilionGym_ScriptPointers   ; pret: ld de, VermilionGym_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wVermilionGymCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wVermilionGymCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
.LoadNames:
    mov esi, .CityName
    mov edx, .LeaderName   ; pret: ld de, .LeaderName — LoadGymLeaderAndCityName takes it in EDX
    jmp LoadGymLeaderAndCityName

%assign event_byte -1
%assign event_byte_a -1
.CityName:
    TEXT_VermilionGym_Script_CityName
.LeaderName:
    TEXT_VermilionGym_Script_LeaderName

%assign event_byte -1
%assign event_byte_a -1
VermilionGymSetDoorTile:
    CheckEvent EVENT_2ND_LOCK_OPENED
    jnz .doorsOpen
    mov al, 0x24
    jmp .replaceTile

%assign event_byte -1
%assign event_byte_a -1
.doorsOpen:
    mov al, SFX_GO_INSIDE
    call PlaySound
    mov al, 0x5
.replaceTile:
    mov [ebp + wNewTileBlockID], al
    mov bx, ((2) << 8) | (2)
; DEVIATION{class=banking; pret=macros/predef.asm:predef_jump; behavior=Predef dispatch replaced by a direct jmp, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    jmp ReplaceTileBlock

%assign event_byte -1
%assign event_byte_a -1
VermilionGymResetScripts:
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov [ebp + wVermilionGymCurScript], al
    mov [ebp + wCurMapScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
VermilionGym_ScriptPointers:
    dd CheckFightingMapTrainers
    dd DisplayEnemyTrainerTextAndStartBattle
    dd EndTrainerBattle
    dd VermilionGymLTSurgeAfterBattleScript

%assign event_byte -1
%assign event_byte_a -1
VermilionGymLTSurgeAfterBattleScript:
    mov al, [ebp + wIsInBattle]
    cmp al, 0xff
    jz VermilionGymResetScripts
    mov al, PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
VermilionGymLTSurgeReceiveTM24Script:
    mov al, TEXT_VERMILIONGYM_LT_SURGE_THUNDER_BADGE_INFO
    mov [ebp + hTextID], al
    call DisplayTextID
    pushfd    ; SM83 form writes no flags
        SetEvent EVENT_BEAT_LT_SURGE
    popfd
    mov bx, ((TM_THUNDERBOLT) << 8) | (1)
    call GiveItem
    jae .bag_full
    mov al, TEXT_VERMILIONGYM_LT_SURGE_RECEIVED_TM24
    mov [ebp + hTextID], al
    call DisplayTextID
    SetEvent EVENT_GOT_TM24
    jmp .gym_victory

%assign event_byte -1
%assign event_byte_a -1
.bag_full:
    mov al, TEXT_VERMILIONGYM_LT_SURGE_TM24_NO_ROOM
    mov [ebp + hTextID], al
    call DisplayTextID
.gym_victory:
    mov esi, wObtainedBadges
    or byte [ebp + esi], (1 << (2))
    mov esi, wBeatGymFlags
    or byte [ebp + esi], (1 << (2))
    SetEventRange EVENT_BEAT_VERMILION_GYM_TRAINER_0, EVENT_BEAT_VERMILION_GYM_TRAINER_2
    jmp VermilionGymResetScripts

; VermilionGym_TextPointers (scripts/VermilionGym.asm:94-112) — not re-emitted: VermilionGymTrainerHeaders is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
VermilionGymLTSurgeText:
    CheckEvent EVENT_BEAT_LT_SURGE
    jz .before_beat
    CheckEventReuseA EVENT_GOT_TM24
    jnz .got_tm24_already
    jnz .sk_120
        call VermilionGymLTSurgeReceiveTM24Script
.sk_120:
    call DisableWaitingAfterTextDisplay
    jmp .text_script_end

%assign event_byte -1
%assign event_byte_a -1
.got_tm24_already:
    mov esi, .PostBattleAdviceText
    call PrintText
    jmp .text_script_end

%assign event_byte -1
%assign event_byte_a -1
.before_beat:
    mov esi, .PreBattleText
    call PrintText
    mov esi, wStatusFlags3
    or byte [ebp + esi], (1 << (BIT_TALKED_TO_TRAINER))
    or byte [ebp + esi], (1 << (BIT_PRINT_END_BATTLE_TEXT))
    mov esi, VermilionGymLTSurgeReceivedThunderBadgeText
    mov edx, VermilionGymLTSurgeReceivedThunderBadgeText   ; pret: ld de, VermilionGymLTSurgeReceivedThunderBadgeText — SaveEndBattleTextPointers takes it in EDX
    call SaveEndBattleTextPointers
    mov al, [ebp + hSpriteIndex]
    mov [ebp + wSpriteIndex], al
    call EngageMapTrainer
    call InitBattleEnemyParameters
    mov al, 0x3
    mov [ebp + wGymLeaderNo], al
    xor al, al
    mov [ebp + hJoyHeld], al
    mov al, SCRIPT_VERMILIONGYM_LT_SURGE_AFTER_BATTLE
    mov [ebp + wVermilionGymCurScript], al
    mov [ebp + wCurMapScript], al
.text_script_end:
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.PreBattleText:
    text_far _VermilionGymLTSurgePreBattleText
    text_end
.PostBattleAdviceText:
    text_far _VermilionGymLTSurgePostBattleAdviceText
    text_end
VermilionGymLTSurgeThunderBadgeInfoText:
    text_far _VermilionGymLTSurgeThunderBadgeInfoText
    text_end
VermilionGymLTSurgeReceivedTM24Text:
    text_far _VermilionGymLTSurgeReceivedTM24Text
    sound_get_key_item
    text_far _TM24ExplanationText
    text_end
VermilionGymLTSurgeTM24NoRoomText:
    text_far _VermilionGymLTSurgeTM24NoRoomText
    text_end
VermilionGymLTSurgeReceivedThunderBadgeText:
    text_far _VermilionGymLTSurgeReceivedThunderBadgeText
    text_end

%assign event_byte -1
%assign event_byte_a -1
VermilionGymGentlemanText:
    mov esi, VermilionGymTrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; VermilionGymGentlemanBattleText (scripts/VermilionGym.asm:183-192) — not re-emitted: VermilionGymGentlemanBattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
VermilionGymSuperNerdText:
    mov esi, VermilionGymTrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

; VermilionGymSuperNerdBattleText (scripts/VermilionGym.asm:201-210) — not re-emitted: VermilionGymSuperNerdBattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
VermilionGymSailorText:
    mov esi, VermilionGymTrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

; VermilionGymSailorBattleText (scripts/VermilionGym.asm:219-228) — not re-emitted: VermilionGymSailorBattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
VermilionGymGymGuideText:
    mov al, [ebp + wBeatGymFlags]
    test al, (1 << (2))
    jnz .got_thunderbadge
    mov esi, .ChampInMakingText
    call PrintText
    jmp .text_script_end

%assign event_byte -1
%assign event_byte_a -1
.got_thunderbadge:
    mov esi, .BeatLTSurgeText
    call PrintText
.text_script_end:
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.ChampInMakingText:
    text_far _VermilionGymGymGuideChampInMakingText
    text_end
.BeatLTSurgeText:
    text_far _VermilionGymGymGuideBeatLTSurgeText
    text_end
