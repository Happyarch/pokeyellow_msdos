; CeruleanGym.asm — translated from pret scripts/CeruleanGym.asm by dos_port/tools/sm83xlat.
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

global CeruleanGymCooltrainerFText
global CeruleanGymGymGuideText
global CeruleanGymMistyCascadeBadgeInfoText
global CeruleanGymMistyPostBattleScript
global CeruleanGymMistyReceivedCascadeBadgeText
global CeruleanGymMistyReceivedTM11Text
global CeruleanGymMistyTM11NoRoomText
global CeruleanGymMistyText
global CeruleanGymReceiveTM11
global CeruleanGymResetScripts
global CeruleanGymSwimmerText
global CeruleanGym_ScriptPointers

extern CeruleanGymBattleText1   ; NOT YET DEFINED IN THE PORT
extern CeruleanGymBattleText2   ; NOT YET DEFINED IN THE PORT
extern CeruleanGymTrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern CeruleanGymTrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern CeruleanGymTrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern CeruleanGym_Script   ; NOT YET DEFINED IN THE PORT
extern CeruleanGym_TextPointers   ; NOT YET DEFINED IN THE PORT
extern CheckFightingMapTrainers   ; NOT YET DEFINED IN THE PORT
extern DisableWaitingAfterTextDisplay   ; NOT YET DEFINED IN THE PORT
extern DisplayEnemyTrainerTextAndStartBattle   ; NOT YET DEFINED IN THE PORT
extern DisplayTextID   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EndTrainerBattle   ; NOT YET DEFINED IN THE PORT
extern EngageMapTrainer   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern GiveItem   ; NOT YET DEFINED IN THE PORT
extern InitBattleEnemyParameters   ; NOT YET DEFINED IN THE PORT
extern LoadGymLeaderAndCityName   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern SaveEndBattleTextPointers   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern _CeruleanGymGymGuideBeatMistyText   ; NOT YET DEFINED IN THE PORT
extern _CeruleanGymGymGuideChampInMakingText   ; NOT YET DEFINED IN THE PORT
extern _CeruleanGymMistyCascadeBadgeInfoText   ; NOT YET DEFINED IN THE PORT
extern _CeruleanGymMistyPreBattleText   ; NOT YET DEFINED IN THE PORT
extern _CeruleanGymMistyReceivedCascadeBadgeText   ; NOT YET DEFINED IN THE PORT
extern _CeruleanGymMistyReceivedTM11Text   ; NOT YET DEFINED IN THE PORT
extern _CeruleanGymMistyTM11ExplanationText   ; NOT YET DEFINED IN THE PORT
extern _CeruleanGymMistyTM11NoRoomText   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_CERULEANGYM_MISTY_POST_BATTLE           equ 3
TEXT_CERULEANGYM_MISTY_CASCADE_BADGE_INFO      equ 5
TEXT_CERULEANGYM_MISTY_RECEIVED_TM11           equ 6
TEXT_CERULEANGYM_MISTY_TM11_NO_ROOM            equ 7

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wBeatGymFlags                                  equ 0xD729
wCeruleanGymCurScript                          equ 0xD5FC

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] CeruleanGym_Script (scripts/CeruleanGym.asm:2-12) — at scripts/CeruleanGym.asm:5: CeruleanGym_Script.LoadNames is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, wCurrentMapScriptFlags
; PRET| 	bit BIT_CUR_MAP_LOADED_2, [hl]
; PRET| 	res BIT_CUR_MAP_LOADED_2, [hl]
; PRET| 	call nz, .LoadNames
; PRET| 	call EnableAutoTextBoxDrawing
; PRET| 	ld hl, CeruleanGymTrainerHeaders
; PRET| 	ld de, CeruleanGym_ScriptPointers
; PRET| 	ld a, [wCeruleanGymCurScript]
; PRET| 	call ExecuteCurMapScriptInTable
; PRET| 	ld [wCeruleanGymCurScript], a
; PRET| 	ret

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] CeruleanGym_Script.LoadNames (scripts/CeruleanGym.asm:15-17) — at scripts/CeruleanGym.asm:15: .CityName is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .CityName
; PRET| 	ld de, .LeaderName
; PRET| 	jp LoadGymLeaderAndCityName

; ---------------------------------------------------------------------------
; BAIL[inline-text-db] CeruleanGym_Script.CityName (scripts/CeruleanGym.asm:20-23) — at scripts/CeruleanGym.asm:20: db "CERULEAN CITY@"
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	db "CERULEAN CITY@"
; PRET| 
; PRET| .LeaderName:
; PRET| 	db "MISTY@"

%assign event_byte -1
%assign event_byte_a -1
CeruleanGymResetScripts:
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov [ebp + wCeruleanGymCurScript], al
    mov [ebp + wCurMapScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
CeruleanGym_ScriptPointers:
    dd CheckFightingMapTrainers
    dd DisplayEnemyTrainerTextAndStartBattle
    dd EndTrainerBattle
    dd CeruleanGymMistyPostBattleScript

%assign event_byte -1
%assign event_byte_a -1
CeruleanGymMistyPostBattleScript:
    mov al, [ebp + wIsInBattle]
    cmp al, 0xff
    jz CeruleanGymResetScripts
    mov al, PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
CeruleanGymReceiveTM11:
    mov al, TEXT_CERULEANGYM_MISTY_CASCADE_BADGE_INFO
    mov [ebp + hTextID], al
    call DisplayTextID
    pushfd    ; SM83 form writes no flags
        SetEvent EVENT_BEAT_MISTY
    popfd
    mov bx, ((213) << 8) | (1)
    call GiveItem
    jae .BagFull
    mov al, TEXT_CERULEANGYM_MISTY_RECEIVED_TM11
    mov [ebp + hTextID], al
    call DisplayTextID
    SetEvent EVENT_GOT_TM11
    jmp .gymVictory

%assign event_byte -1
%assign event_byte_a -1
.BagFull:
    mov al, TEXT_CERULEANGYM_MISTY_TM11_NO_ROOM
    mov [ebp + hTextID], al
    call DisplayTextID
.gymVictory:
    mov esi, wObtainedBadges
    or byte [ebp + esi], (1 << (1))
    mov esi, wBeatGymFlags
    or byte [ebp + esi], (1 << (1))
    SetEvents EVENT_BEAT_CERULEAN_GYM_TRAINER_0, EVENT_BEAT_CERULEAN_GYM_TRAINER_1
    jmp CeruleanGymResetScripts

; CeruleanGym_TextPointers (scripts/CeruleanGym.asm:75-90) — not re-emitted: CeruleanGymTrainerHeaders is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
CeruleanGymMistyText:
    CheckEvent EVENT_BEAT_MISTY
    jz .beforeBeat
    CheckEventReuseA EVENT_GOT_TM11
    jnz .afterBeat
    jnz .sk_98
        call CeruleanGymReceiveTM11
.sk_98:
    call DisableWaitingAfterTextDisplay
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.afterBeat:
    mov esi, .TM11ExplanationText
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
    mov esi, CeruleanGymMistyReceivedCascadeBadgeText
    mov edx, CeruleanGymMistyReceivedCascadeBadgeText   ; pret: ld de, CeruleanGymMistyReceivedCascadeBadgeText — SaveEndBattleTextPointers takes it in EDX
    call SaveEndBattleTextPointers
    mov al, [ebp + hSpriteIndex]
    mov [ebp + wSpriteIndex], al
    call EngageMapTrainer
    call InitBattleEnemyParameters
    mov al, 0x2
    mov [ebp + wGymLeaderNo], al
    xor al, al
    mov [ebp + hJoyHeld], al
    mov al, SCRIPT_CERULEANGYM_MISTY_POST_BATTLE
    mov [ebp + wCeruleanGymCurScript], al
.done:
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.PreBattleText:
    text_far _CeruleanGymMistyPreBattleText
    text_end
.TM11ExplanationText:
    text_far _CeruleanGymMistyTM11ExplanationText
    text_end
CeruleanGymMistyCascadeBadgeInfoText:
    text_far _CeruleanGymMistyCascadeBadgeInfoText
    text_end
CeruleanGymMistyReceivedTM11Text:
    text_far _CeruleanGymMistyReceivedTM11Text
    sound_get_item_1
    text_end
CeruleanGymMistyTM11NoRoomText:
    text_far _CeruleanGymMistyTM11NoRoomText
    text_end
CeruleanGymMistyReceivedCascadeBadgeText:
    text_far _CeruleanGymMistyReceivedCascadeBadgeText
    text_end

%assign event_byte -1
%assign event_byte_a -1
CeruleanGymCooltrainerFText:
    mov esi, CeruleanGymTrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; CeruleanGymBattleText1 (scripts/CeruleanGym.asm:159-168) — not re-emitted: CeruleanGymBattleText1 is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
CeruleanGymSwimmerText:
    mov esi, CeruleanGymTrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

; CeruleanGymBattleText2 (scripts/CeruleanGym.asm:177-186) — not re-emitted: CeruleanGymBattleText2 is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
CeruleanGymGymGuideText:
    CheckEvent EVENT_BEAT_MISTY
    jnz .afterBeat
    mov esi, .ChampInMakingText
    call PrintText
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.afterBeat:
    mov esi, .BeatMistyText
    call PrintText
.done:
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.ChampInMakingText:
    text_far _CeruleanGymGymGuideChampInMakingText
    text_end
.BeatMistyText:
    text_far _CeruleanGymGymGuideBeatMistyText
    text_end
