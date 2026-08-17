; SaffronGym.asm — translated from pret scripts/SaffronGym.asm by dos_port/tools/sm83xlat.
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

%include "assets/script_strings.inc"
%include "assets/trainer_headers.inc"

global SaffronGymChanneler1Text
global SaffronGymChanneler2Text
global SaffronGymChanneler3Text
global SaffronGymResetScripts
global SaffronGymSabrinaMarshBadgeInfoText
global SaffronGymSabrinaPostBattle
global SaffronGymSabrinaReceiveTM46Script
global SaffronGymSabrinaReceivedTM46Text
global SaffronGymSabrinaTM46NoRoomText
global SaffronGymSabrinaText
global SaffronGymYoungster1Text
global SaffronGymYoungster2Text
global SaffronGymYoungster3Text
global SaffronGymYoungster4Text
global SaffronGym_Script
global SaffronGym_ScriptPointers

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
extern PrintText
extern SaffronGymChanneler1BattleText   ; NOT YET DEFINED IN THE PORT
extern SaffronGymGymGuideText   ; NOT YET DEFINED IN THE PORT
extern SaffronGymTrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern SaffronGymTrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern SaffronGymTrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern SaffronGymTrainerHeader3   ; NOT YET DEFINED IN THE PORT
extern SaffronGymTrainerHeader4   ; NOT YET DEFINED IN THE PORT
extern SaffronGymTrainerHeader5   ; NOT YET DEFINED IN THE PORT
extern SaffronGymTrainerHeader6   ; NOT YET DEFINED IN THE PORT
extern SaffronGymTrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern SaffronGym_TextPointers   ; NOT YET DEFINED IN THE PORT
extern SaveEndBattleTextPointers
extern TalkToTrainer
extern TextScriptEnd
extern _SaffronGymSabrinaMarshBadgeInfoText   ; NOT YET DEFINED IN THE PORT
extern _SaffronGymSabrinaPostBattleAdviceText   ; NOT YET DEFINED IN THE PORT
extern _SaffronGymSabrinaReceivedMarshBadgeText   ; NOT YET DEFINED IN THE PORT
extern _SaffronGymSabrinaReceivedTM46Text   ; NOT YET DEFINED IN THE PORT
extern _SaffronGymSabrinaTM46NoRoomText   ; NOT YET DEFINED IN THE PORT
extern _SaffronGymSabrinaText   ; NOT YET DEFINED IN THE PORT
extern _TM46ExplanationText   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_SAFFRONGYM_SABRINA_POST_BATTLE          equ 3
TEXT_SAFFRONGYM_SABRINA_MARSH_BADGE_INFO       equ 10
TEXT_SAFFRONGYM_SABRINA_RECEIVED_TM46          equ 11
TEXT_SAFFRONGYM_SABRINA_TM46_NO_ROOM           equ 12

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wBeatGymFlags                                  equ 0xD729
wSaffronGymCurScript                           equ 0xD65B

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
SaffronGym_Script:
    mov esi, wCurrentMapScriptFlags
    test byte [ebp + esi], (1 << (BIT_CUR_MAP_LOADED_2))
    pushfd    ; SM83 form writes no flags
        and byte [ebp + esi], ~(1 << (BIT_CUR_MAP_LOADED_2)) & 0xFF
    popfd
    jz .sk_5
        call .LoadNames
.sk_5:
    call EnableAutoTextBoxDrawing
    mov esi, SaffronGymTrainerHeaders
    mov edi, SaffronGym_ScriptPointers   ; pret: ld de, SaffronGym_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wSaffronGymCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wSaffronGymCurScript], al
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
    TEXT_SaffronGym_Script_CityName
.LeaderName:
    TEXT_SaffronGym_Script_LeaderName

%assign event_byte -1
%assign event_byte_a -1
SaffronGymResetScripts:
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov [ebp + wSaffronGymCurScript], al
    mov [ebp + wCurMapScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
SaffronGym_ScriptPointers:
    dd CheckFightingMapTrainers
    dd DisplayEnemyTrainerTextAndStartBattle
    dd EndTrainerBattle
    dd SaffronGymSabrinaPostBattle

%assign event_byte -1
%assign event_byte_a -1
SaffronGymSabrinaPostBattle:
    mov al, [ebp + wIsInBattle]
    cmp al, 0xff
    jz SaffronGymResetScripts
    mov al, PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
SaffronGymSabrinaReceiveTM46Script:
    mov al, TEXT_SAFFRONGYM_SABRINA_MARSH_BADGE_INFO
    mov [ebp + hTextID], al
    call DisplayTextID
    pushfd    ; SM83 form writes no flags
        SetEvent EVENT_BEAT_SABRINA
    popfd
    mov bx, ((248) << 8) | (1)
    call GiveItem
    jae .BagFull
    mov al, TEXT_SAFFRONGYM_SABRINA_RECEIVED_TM46
    mov [ebp + hTextID], al
    call DisplayTextID
    SetEvent EVENT_GOT_TM46
    jmp .gymVictory

%assign event_byte -1
%assign event_byte_a -1
.BagFull:
    mov al, TEXT_SAFFRONGYM_SABRINA_TM46_NO_ROOM
    mov [ebp + hTextID], al
    call DisplayTextID
.gymVictory:
    mov esi, wObtainedBadges
    or byte [ebp + esi], (1 << (5))
    mov esi, wBeatGymFlags
    or byte [ebp + esi], (1 << (5))
    SetEventRange EVENT_BEAT_SAFFRON_GYM_TRAINER_0, EVENT_BEAT_SAFFRON_GYM_TRAINER_6
    jmp SaffronGymResetScripts

; SaffronGym_TextPointers (scripts/SaffronGym.asm:75-105) — not re-emitted: SaffronGymTrainerHeaders is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
SaffronGymSabrinaText:
    CheckEvent EVENT_BEAT_SABRINA
    jz .beforeBeat
    CheckEventReuseA EVENT_GOT_TM46
    jnz .afterBeat
    jnz .sk_113
        call SaffronGymSabrinaReceiveTM46Script
.sk_113:
    call DisableWaitingAfterTextDisplay
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.afterBeat:
    mov esi, .PostBattleAdviceText
    call PrintText
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.beforeBeat:
    mov esi, .Text
    call PrintText
    mov esi, wStatusFlags3
    or byte [ebp + esi], (1 << (BIT_TALKED_TO_TRAINER))
    or byte [ebp + esi], (1 << (BIT_PRINT_END_BATTLE_TEXT))
    mov esi, .ReceivedMarshBadgeText
    mov edx, .ReceivedMarshBadgeText   ; pret: ld de, .ReceivedMarshBadgeText — SaveEndBattleTextPointers takes it in EDX
    call SaveEndBattleTextPointers
    mov al, [ebp + hSpriteIndex]
    mov [ebp + wSpriteIndex], al
    call EngageMapTrainer
    call InitBattleEnemyParameters
    mov al, 0x6
    mov [ebp + wGymLeaderNo], al
    mov al, SCRIPT_SAFFRONGYM_SABRINA_POST_BATTLE
    mov [ebp + wSaffronGymCurScript], al
.done:
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.Text:
    text_far _SaffronGymSabrinaText
    text_end
.ReceivedMarshBadgeText:
    text_far _SaffronGymSabrinaReceivedMarshBadgeText
    sound_get_key_item
    text_promptbutton
    text_end
.PostBattleAdviceText:
    text_far _SaffronGymSabrinaPostBattleAdviceText
    text_end
SaffronGymSabrinaMarshBadgeInfoText:
    text_far _SaffronGymSabrinaMarshBadgeInfoText
    text_end
SaffronGymSabrinaReceivedTM46Text:
    text_far _SaffronGymSabrinaReceivedTM46Text
    sound_get_item_1
    text_far _TM46ExplanationText
    text_end
SaffronGymSabrinaTM46NoRoomText:
    text_far _SaffronGymSabrinaTM46NoRoomText
    text_end

%assign event_byte -1
%assign event_byte_a -1
SaffronGymChanneler1Text:
    mov esi, SaffronGymTrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
SaffronGymYoungster1Text:
    mov esi, SaffronGymTrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
SaffronGymChanneler2Text:
    mov esi, SaffronGymTrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
SaffronGymYoungster2Text:
    mov esi, SaffronGymTrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
SaffronGymChanneler3Text:
    mov esi, SaffronGymTrainerHeader4
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
SaffronGymYoungster3Text:
    mov esi, SaffronGymTrainerHeader5
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
SaffronGymYoungster4Text:
    mov esi, SaffronGymTrainerHeader6
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] SaffronGymGymGuideText (scripts/SaffronGym.asm:212-216) — at scripts/SaffronGym.asm:213: SaffronGymGymGuideText.afterBeat is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEvent EVENT_BEAT_SABRINA
; PRET| 	jr nz, .afterBeat
; PRET| 	ld hl, .ChampInMakingText
; PRET| 	call PrintText
; PRET| 	jr .done

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] SaffronGymGymGuideText.afterBeat (scripts/SaffronGym.asm:218-221) — at scripts/SaffronGym.asm:218: .BeatSabrinaText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .BeatSabrinaText
; PRET| 	call PrintText
; PRET| .done
; PRET| 	jp TextScriptEnd

; SaffronGymGymGuideText.ChampInMakingText (scripts/SaffronGym.asm:224-313) — not re-emitted: SaffronGymChanneler1BattleText is already defined in assets/trainer_headers.inc.
