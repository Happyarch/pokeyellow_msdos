; Route24.asm — translated from pret scripts/Route24.asm by dos_port/tools/sm83xlat.
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

global Route24AfterRocketBattleScript
global Route24CooltrainerF1Text
global Route24CooltrainerF2Text
global Route24CooltrainerM1Text
global Route24CooltrainerM2Text
global Route24CooltrainerM3Text
global Route24CooltrainerM4Text
global Route24DefaultScript
global Route24PlayerMovingScript
global Route24SetDefaultScript
global Route24Text_515de
global Route24Text_515e3
global Route24Text_515e9
global Route24Text_515ee
global Route24Youngster1Text
global Route24Youngster2Text
global Route24_Script
global Route24_ScriptPointers

extern ArePlayerCoordsInArray
extern CheckFightingMapTrainers
extern Delay3
extern DisplayEnemyTrainerTextAndStartBattle
extern DisplayTextID
extern EnableAutoTextBoxDrawing
extern EndTrainerBattle
extern EngageMapTrainer
extern ExecuteCurMapScriptInTable
extern GetMonName
extern GiveItem
extern GivePokemon
extern InitBattleEnemyParameters
extern PrintText
extern Route24CooltrainerM2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route24TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern Route24TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern Route24TrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern Route24TrainerHeader3   ; NOT YET DEFINED IN THE PORT
extern Route24TrainerHeader4   ; NOT YET DEFINED IN THE PORT
extern Route24TrainerHeader5   ; NOT YET DEFINED IN THE PORT
extern Route24TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern Route24_TextPointers   ; NOT YET DEFINED IN THE PORT
extern SaveEndBattleTextPointers
extern StartSimulatingJoypadStates
extern TalkToTrainer
extern TextScriptEnd
extern UpdateSprites
extern WaitForTextScrollButtonPress
extern YesNoChoice
extern _Route24CooltrainerM1DefeatedText   ; NOT YET DEFINED IN THE PORT
extern _Route24CooltrainerM1JoinTeamRocketText   ; NOT YET DEFINED IN THE PORT
extern _Route24CooltrainerM1NoRoomText   ; NOT YET DEFINED IN THE PORT
extern _Route24CooltrainerM1ReceivedNuggetText   ; NOT YET DEFINED IN THE PORT
extern _Route24CooltrainerM1YouBeatOurContestText   ; NOT YET DEFINED IN THE PORT
extern _Route24CooltrainerM1YouCouldBecomeATopLeaderText   ; NOT YET DEFINED IN THE PORT
extern _Route24CooltrainerM1YouJustEarnedAPrizeText   ; NOT YET DEFINED IN THE PORT
extern _Route24DamianText1   ; NOT YET DEFINED IN THE PORT
extern _Route24DamianText2   ; NOT YET DEFINED IN THE PORT
extern _Route24DamianText3   ; NOT YET DEFINED IN THE PORT
extern _Route24DamianText4   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_ROUTE24_DEFAULT                         equ 0
SCRIPT_ROUTE24_AFTER_ROCKET_BATTLE             equ 3
SCRIPT_ROUTE24_PLAYER_MOVING                   equ 4
TEXT_ROUTE24_COOLTRAINER_M1                    equ 1

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wAddedToParty                                  equ 0xCCD3
wRoute24CurScript                              equ 0xD601

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
Route24_Script:
    call EnableAutoTextBoxDrawing
    mov esi, Route24TrainerHeaders
    mov edi, Route24_ScriptPointers   ; pret: ld de, Route24_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wRoute24CurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wRoute24CurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
Route24SetDefaultScript:
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov [ebp + wRoute24CurScript], al
    mov [ebp + wCurMapScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
Route24_ScriptPointers:
    dd Route24DefaultScript
    dd DisplayEnemyTrainerTextAndStartBattle
    dd EndTrainerBattle
    dd Route24AfterRocketBattleScript
    dd Route24PlayerMovingScript

%assign event_byte -1
%assign event_byte_a -1
Route24DefaultScript:
    CheckEvent EVENT_GOT_NUGGET
    jnz CheckFightingMapTrainers
    mov esi, .PlayerCoordsArray
    call ArePlayerCoordsInArray
    jae CheckFightingMapTrainers
    xor al, al
    mov [ebp + hJoyHeld], al
    mov al, TEXT_ROUTE24_COOLTRAINER_M1
    mov [ebp + hTextID], al
    call DisplayTextID
    CheckAndResetEvent EVENT_NUGGET_REWARD_AVAILABLE
    jnz .nr_37
        ret
.nr_37:
    mov al, PAD_DOWN
    mov [ebp + wSimulatedJoypadStatesEnd], al
    mov al, 0x1
    mov [ebp + wSimulatedJoypadStatesIndex], al
    call StartSimulatingJoypadStates
    mov al, SCRIPT_ROUTE24_PLAYER_MOVING
    mov [ebp + wRoute24CurScript], al
    mov [ebp + wCurMapScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
.PlayerCoordsArray:
    db 15, 10
    db -1

%assign event_byte -1
%assign event_byte_a -1
Route24PlayerMovingScript:
    mov al, [ebp + wSimulatedJoypadStatesIndex]
    test al, al
    jz .nr_55
        ret
.nr_55:
    call Delay3
    mov al, SCRIPT_ROUTE24_DEFAULT
    mov [ebp + wRoute24CurScript], al
    mov [ebp + wCurMapScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
Route24AfterRocketBattleScript:
    mov al, [ebp + wIsInBattle]
    cmp al, 0xff
    jz Route24SetDefaultScript
    call UpdateSprites
    mov al, PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    SetEvent EVENT_BEAT_ROUTE24_ROCKET
    mov al, TEXT_ROUTE24_COOLTRAINER_M1
    mov [ebp + hTextID], al
    call DisplayTextID
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov al, SCRIPT_ROUTE24_DEFAULT
    mov [ebp + wRoute24CurScript], al
    mov [ebp + wCurMapScript], al
    ret

; Route24_TextPointers (scripts/Route24.asm:81-106) — not re-emitted: Route24TrainerHeaders is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route24CooltrainerM1Text:
    pushfd    ; SM83 form writes no flags
        ResetEvent EVENT_NUGGET_REWARD_AVAILABLE
    popfd
    CheckEvent EVENT_GOT_NUGGET
    jnz .got_item
    mov esi, .YouBeatOurContestText
    call PrintText
    mov bx, ((49) << 8) | (1)
    call GiveItem
    jae .bag_full
    SetEvent EVENT_GOT_NUGGET
    mov esi, .ReceivedNuggetText
    call PrintText
    mov esi, .JoinTeamRocketText
    call PrintText
    mov esi, wStatusFlags3
    or byte [ebp + esi], (1 << (BIT_TALKED_TO_TRAINER))
    or byte [ebp + esi], (1 << (BIT_PRINT_END_BATTLE_TEXT))
    mov esi, .DefeatedText
    mov edx, .DefeatedText   ; pret: ld de, .DefeatedText — SaveEndBattleTextPointers takes it in EDX
    call SaveEndBattleTextPointers
    mov al, [ebp + hSpriteIndex]
    mov [ebp + wSpriteIndex], al
    call EngageMapTrainer
    call InitBattleEnemyParameters
    xor al, al
    mov [ebp + hJoyHeld], al
    mov al, SCRIPT_ROUTE24_AFTER_ROCKET_BATTLE
    mov [ebp + wRoute24CurScript], al
    mov [ebp + wCurMapScript], al
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.got_item:
    mov esi, .YouCouldBecomeATopLeaderText
    call PrintText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.bag_full:
    mov esi, .NoRoomText
    call PrintText
    SetEvent EVENT_NUGGET_REWARD_AVAILABLE
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.YouBeatOurContestText:
    text_far _Route24CooltrainerM1YouBeatOurContestText
    sound_get_item_1
    text_far _Route24CooltrainerM1YouJustEarnedAPrizeText
    text_end
.ReceivedNuggetText:
    text_far _Route24CooltrainerM1ReceivedNuggetText
    sound_get_key_item
    text_promptbutton
    text_end
.NoRoomText:
    text_far _Route24CooltrainerM1NoRoomText
    text_end
.JoinTeamRocketText:
    text_far _Route24CooltrainerM1JoinTeamRocketText
    text_end
.DefeatedText:
    text_far _Route24CooltrainerM1DefeatedText
    text_end
.YouCouldBecomeATopLeaderText:
    text_far _Route24CooltrainerM1YouCouldBecomeATopLeaderText
    text_end

%assign event_byte -1
%assign event_byte_a -1
Route24CooltrainerM2Text:
    mov esi, Route24TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
Route24CooltrainerM3Text:
    mov esi, Route24TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
Route24CooltrainerF1Text:
    mov esi, Route24TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
Route24Youngster1Text:
    mov esi, Route24TrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
Route24CooltrainerF2Text:
    mov esi, Route24TrainerHeader4
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
Route24Youngster2Text:
    mov esi, Route24TrainerHeader5
    call TalkToTrainer
    jmp TextScriptEnd

; Route24CooltrainerM2BattleText (scripts/Route24.asm:214-283) — not re-emitted: Route24CooltrainerM2BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route24CooltrainerM4Text:
    CheckEvent EVENT_54F
    jnz .asm_515d5
    mov esi, Route24Text_515de
    call PrintText
    call YesNoChoice
    mov al, [ebp + wCurrentMenuItem]
    test al, al
    jnz .asm_515d0
    mov al, 176
    mov [ebp + wNamedObjectIndex], al
    mov [ebp + wCurPartySpecies], al
    call GetMonName
    mov al, 0x1
    mov [ebp + wDoNotWaitForButtonPressAfterDisplayingText], al
    mov bx, ((176) << 8) | (10)
    call GivePokemon
    jae TextScriptEnd
    mov al, [ebp + wAddedToParty]
    test al, al
    jnz .sk_306
        call WaitForTextScrollButtonPress
.sk_306:
    mov al, 0x1
    mov [ebp + wDoNotWaitForButtonPressAfterDisplayingText], al
    mov esi, Route24Text_515e3
    call PrintText
    SetEvent EVENT_54F
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.asm_515d0:
    mov esi, Route24Text_515e9
    jmp .asm_515d8

%assign event_byte -1
%assign event_byte_a -1
.asm_515d5:
    mov esi, Route24Text_515ee
.asm_515d8:
    call PrintText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
Route24Text_515de:
    text_far _Route24DamianText1
    text_end
Route24Text_515e3:
    text_far _Route24DamianText2
    text_waitbutton
    text_end
Route24Text_515e9:
    text_far _Route24DamianText3
    text_end
Route24Text_515ee:
    text_far _Route24DamianText4
    text_end
