; CeladonGym.asm — translated from pret scripts/CeladonGym.asm by dos_port/tools/sm83xlat.
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

%include "assets/gym_names.inc"
%include "assets/trainer_headers.inc"

global CeladonGymBeauty1Text
global CeladonGymBeauty2Text
global CeladonGymBeauty3Text
global CeladonGymCooltrainerF1Text
global CeladonGymCooltrainerF2Text
global CeladonGymCooltrainerF3Text
global CeladonGymCooltrainerF4Text
global CeladonGymErikaPostBattleScript
global CeladonGymErikaText
global CeladonGymRainbowBadgeInfoText
global CeladonGymReceiveTM21
global CeladonGymReceivedTM21Text
global CeladonGymResetScripts
global CeladonGymTM21NoRoomText
global CeladonGym_Script
global CeladonGym_ScriptPointers

extern CeladonGymBattleText2   ; NOT YET DEFINED IN THE PORT
extern CeladonGymBattleText3   ; NOT YET DEFINED IN THE PORT
extern CeladonGymBattleText4   ; NOT YET DEFINED IN THE PORT
extern CeladonGymBattleText5   ; NOT YET DEFINED IN THE PORT
extern CeladonGymBattleText6   ; NOT YET DEFINED IN THE PORT
extern CeladonGymBattleText7   ; NOT YET DEFINED IN THE PORT
extern CeladonGymBattleText8   ; NOT YET DEFINED IN THE PORT
extern CeladonGymTrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern CeladonGymTrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern CeladonGymTrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern CeladonGymTrainerHeader3   ; NOT YET DEFINED IN THE PORT
extern CeladonGymTrainerHeader4   ; NOT YET DEFINED IN THE PORT
extern CeladonGymTrainerHeader5   ; NOT YET DEFINED IN THE PORT
extern CeladonGymTrainerHeader6   ; NOT YET DEFINED IN THE PORT
extern CeladonGymTrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern CeladonGym_TextPointers   ; NOT YET DEFINED IN THE PORT
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
extern SaveEndBattleTextPointers
extern TalkToTrainer
extern TextScriptEnd
extern _CeladonGymErikaPostBattleAdviceText   ; NOT YET DEFINED IN THE PORT
extern _CeladonGymErikaPreBattleText   ; NOT YET DEFINED IN THE PORT
extern _CeladonGymErikaReceivedRainbowBadgeText   ; NOT YET DEFINED IN THE PORT
extern _CeladonGymRainbowBadgeInfoText   ; NOT YET DEFINED IN THE PORT
extern _CeladonGymReceivedTM21Text   ; NOT YET DEFINED IN THE PORT
extern _CeladonGymTM21NoRoomText   ; NOT YET DEFINED IN THE PORT
extern _TM21ExplanationText   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_CELADONGYM_ERIKA_POST_BATTLE            equ 3
TEXT_CELADONGYM_RAINBOWBADGE_INFO              equ 9
TEXT_CELADONGYM_RECEIVED_TM21                  equ 10
TEXT_CELADONGYM_TM21_NO_ROOM                   equ 11

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wBeatGymFlags                                  equ 0xD729
wCeladonGymCurScript                           equ 0xD5FE

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
CeladonGym_Script:
    mov esi, wCurrentMapScriptFlags
    test byte [ebp + esi], (1 << (BIT_CUR_MAP_LOADED_2))
    pushfd    ; SM83 form writes no flags
        and byte [ebp + esi], ~(1 << (BIT_CUR_MAP_LOADED_2)) & 0xFF
    popfd
    jz .sk_5
        call .LoadNames
.sk_5:
    call EnableAutoTextBoxDrawing
    mov esi, CeladonGymTrainerHeaders
    mov edi, CeladonGym_ScriptPointers   ; pret: ld de, CeladonGym_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wCeladonGymCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wCeladonGymCurScript], al
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
    TEXT_CeladonGym_Script_CityName
.LeaderName:
    TEXT_CeladonGym_Script_LeaderName

%assign event_byte -1
%assign event_byte_a -1
CeladonGymResetScripts:
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov [ebp + wCeladonGymCurScript], al
    mov [ebp + wCurMapScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
CeladonGym_ScriptPointers:
    dd CheckFightingMapTrainers
    dd DisplayEnemyTrainerTextAndStartBattle
    dd EndTrainerBattle
    dd CeladonGymErikaPostBattleScript

%assign event_byte -1
%assign event_byte_a -1
CeladonGymErikaPostBattleScript:
    mov al, [ebp + wIsInBattle]
    cmp al, 0xff
    jz CeladonGymResetScripts
    mov al, PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
CeladonGymReceiveTM21:
    mov al, TEXT_CELADONGYM_RAINBOWBADGE_INFO
    mov [ebp + hTextID], al
    call DisplayTextID
    pushfd    ; SM83 form writes no flags
        SetEvent EVENT_BEAT_ERIKA
    popfd
    mov bx, ((223) << 8) | (1)
    call GiveItem
    jae .BagFull
    mov al, TEXT_CELADONGYM_RECEIVED_TM21
    mov [ebp + hTextID], al
    call DisplayTextID
    SetEvent EVENT_GOT_TM21
    jmp .gymVictory

%assign event_byte -1
%assign event_byte_a -1
.BagFull:
    mov al, TEXT_CELADONGYM_TM21_NO_ROOM
    mov [ebp + hTextID], al
    call DisplayTextID
.gymVictory:
    mov esi, wObtainedBadges
    or byte [ebp + esi], (1 << (3))
    mov esi, wBeatGymFlags
    or byte [ebp + esi], (1 << (3))
    SetEventRange EVENT_BEAT_CELADON_GYM_TRAINER_0, EVENT_BEAT_CELADON_GYM_TRAINER_6
    jmp CeladonGymResetScripts

; CeladonGym_TextPointers (scripts/CeladonGym.asm:75-104) — not re-emitted: CeladonGymTrainerHeaders is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
CeladonGymErikaText:
    CheckEvent EVENT_BEAT_ERIKA
    jz .beforeBeat
    CheckEventReuseA EVENT_GOT_TM21
    jnz .afterBeat
    jnz .sk_112
        call CeladonGymReceiveTM21
.sk_112:
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
    mov esi, .PreBattleText
    call PrintText
    mov esi, wStatusFlags3
    or byte [ebp + esi], (1 << (BIT_TALKED_TO_TRAINER))
    or byte [ebp + esi], (1 << (BIT_PRINT_END_BATTLE_TEXT))
    mov esi, .ReceivedRainbowBadgeText
    mov edx, .ReceivedRainbowBadgeText   ; pret: ld de, .ReceivedRainbowBadgeText — SaveEndBattleTextPointers takes it in EDX
    call SaveEndBattleTextPointers
    mov al, [ebp + hSpriteIndex]
    mov [ebp + wSpriteIndex], al
    call EngageMapTrainer
    call InitBattleEnemyParameters
    mov al, 0x4
    mov [ebp + wGymLeaderNo], al
    mov al, SCRIPT_CELADONGYM_ERIKA_POST_BATTLE
    mov [ebp + wCeladonGymCurScript], al
    mov [ebp + wCurMapScript], al
.done:
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.PreBattleText:
    text_far _CeladonGymErikaPreBattleText
    text_end
.ReceivedRainbowBadgeText:
    text_far _CeladonGymErikaReceivedRainbowBadgeText
    text_end
.PostBattleAdviceText:
    text_far _CeladonGymErikaPostBattleAdviceText
    text_end
CeladonGymRainbowBadgeInfoText:
    text_far _CeladonGymRainbowBadgeInfoText
    text_end
CeladonGymReceivedTM21Text:
    text_far _CeladonGymReceivedTM21Text
    sound_get_item_1
    text_far _TM21ExplanationText
    text_end
CeladonGymTM21NoRoomText:
    text_far _CeladonGymTM21NoRoomText
    text_end

%assign event_byte -1
%assign event_byte_a -1
CeladonGymCooltrainerF1Text:
    mov esi, CeladonGymTrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; CeladonGymBattleText2 (scripts/CeladonGym.asm:173-182) — not re-emitted: CeladonGymBattleText2 is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
CeladonGymBeauty1Text:
    mov esi, CeladonGymTrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

; CeladonGymBattleText3 (scripts/CeladonGym.asm:191-200) — not re-emitted: CeladonGymBattleText3 is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
CeladonGymCooltrainerF2Text:
    mov esi, CeladonGymTrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

; CeladonGymBattleText4 (scripts/CeladonGym.asm:209-218) — not re-emitted: CeladonGymBattleText4 is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
CeladonGymBeauty2Text:
    mov esi, CeladonGymTrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

; CeladonGymBattleText5 (scripts/CeladonGym.asm:227-236) — not re-emitted: CeladonGymBattleText5 is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
CeladonGymCooltrainerF3Text:
    mov esi, CeladonGymTrainerHeader4
    call TalkToTrainer
    jmp TextScriptEnd

; CeladonGymBattleText6 (scripts/CeladonGym.asm:245-254) — not re-emitted: CeladonGymBattleText6 is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
CeladonGymBeauty3Text:
    mov esi, CeladonGymTrainerHeader5
    call TalkToTrainer
    jmp TextScriptEnd

; CeladonGymBattleText7 (scripts/CeladonGym.asm:263-272) — not re-emitted: CeladonGymBattleText7 is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
CeladonGymCooltrainerF4Text:
    mov esi, CeladonGymTrainerHeader6
    call TalkToTrainer
    jmp TextScriptEnd

; CeladonGymBattleText8 (scripts/CeladonGym.asm:281-290) — not re-emitted: CeladonGymBattleText8 is already defined in assets/trainer_headers.inc.
