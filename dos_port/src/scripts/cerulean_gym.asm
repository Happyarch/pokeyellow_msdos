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


global CeruleanGymCooltrainerFText
global CeruleanGymMistyPostBattleScript
global CeruleanGymReceiveTM11
global CeruleanGymResetScripts
global CeruleanGymSwimmerText
global CeruleanGym_ScriptPointers

extern CeruleanGymAfterBattleText1   ; NOT YET DEFINED IN THE PORT
extern CeruleanGymAfterBattleText2   ; NOT YET DEFINED IN THE PORT
extern CeruleanGymBattleText1   ; NOT YET DEFINED IN THE PORT
extern CeruleanGymBattleText2   ; NOT YET DEFINED IN THE PORT
extern CeruleanGymEndBattleText1   ; NOT YET DEFINED IN THE PORT
extern CeruleanGymEndBattleText2   ; NOT YET DEFINED IN THE PORT
extern CeruleanGymGymGuideText   ; NOT YET DEFINED IN THE PORT
extern CeruleanGymMistyCascadeBadgeInfoText   ; NOT YET DEFINED IN THE PORT
extern CeruleanGymMistyReceivedCascadeBadgeText   ; NOT YET DEFINED IN THE PORT
extern CeruleanGymMistyReceivedTM11Text   ; NOT YET DEFINED IN THE PORT
extern CeruleanGymMistyTM11NoRoomText   ; NOT YET DEFINED IN THE PORT
extern CeruleanGymMistyText   ; NOT YET DEFINED IN THE PORT
extern CeruleanGymTrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern CeruleanGymTrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern CeruleanGymTrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern CeruleanGym_Script   ; NOT YET DEFINED IN THE PORT
extern CeruleanGym_TextPointers   ; NOT YET DEFINED IN THE PORT
extern CheckFightingMapTrainers   ; NOT YET DEFINED IN THE PORT
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
extern _CeruleanGymMistyReceivedTM11Text   ; NOT YET DEFINED IN THE PORT
extern _CeruleanGymMistyTM11ExplanationText   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_CERULEANGYM_MISTY_POST_BATTLE           equ 3
TEXT_CERULEANGYM_MISTY                         equ 1
TEXT_CERULEANGYM_COOLTRAINER_F                 equ 2
TEXT_CERULEANGYM_SWIMMER                       equ 3
TEXT_CERULEANGYM_GYM_GUIDE                     equ 4
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
; BAIL[target-region-bailed] CeruleanGym_Script (scripts/CeruleanGym.asm:2-12) — at scripts/CeruleanGym.asm:5: .LoadNames is defined in a region that bailed
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

CeruleanGymResetScripts:
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov [ebp + wCeruleanGymCurScript], al
    mov [ebp + wCurMapScript], al
    ret

CeruleanGym_ScriptPointers:
    dd CheckFightingMapTrainers
    dd DisplayEnemyTrainerTextAndStartBattle
    dd EndTrainerBattle
    dd CeruleanGymMistyPostBattleScript

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

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] CeruleanGym_TextPointers (scripts/CeruleanGym.asm:75-90) — a generated asset already defines CeruleanGymTrainerHeaders
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	def_text_pointers
; PRET| 	dw_const CeruleanGymMistyText,                 TEXT_CERULEANGYM_MISTY
; PRET| 	dw_const CeruleanGymCooltrainerFText,          TEXT_CERULEANGYM_COOLTRAINER_F
; PRET| 	dw_const CeruleanGymSwimmerText,               TEXT_CERULEANGYM_SWIMMER
; PRET| 	dw_const CeruleanGymGymGuideText,              TEXT_CERULEANGYM_GYM_GUIDE
; PRET| 	dw_const CeruleanGymMistyCascadeBadgeInfoText, TEXT_CERULEANGYM_MISTY_CASCADE_BADGE_INFO
; PRET| 	dw_const CeruleanGymMistyReceivedTM11Text,     TEXT_CERULEANGYM_MISTY_RECEIVED_TM11
; PRET| 	dw_const CeruleanGymMistyTM11NoRoomText,       TEXT_CERULEANGYM_MISTY_TM11_NO_ROOM
; PRET| 
; PRET| CeruleanGymTrainerHeaders:
; PRET| 	def_trainers 2
; PRET| CeruleanGymTrainerHeader0:
; PRET| 	trainer EVENT_BEAT_CERULEAN_GYM_TRAINER_0, 3, CeruleanGymBattleText1, CeruleanGymEndBattleText1, CeruleanGymAfterBattleText1
; PRET| CeruleanGymTrainerHeader1:
; PRET| 	trainer EVENT_BEAT_CERULEAN_GYM_TRAINER_1, 3, CeruleanGymBattleText2, CeruleanGymEndBattleText2, CeruleanGymAfterBattleText2
; PRET| 	db -1 ; end

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] CeruleanGymMistyText (scripts/CeruleanGym.asm:94-100) — at scripts/CeruleanGym.asm:95: .beforeBeat is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEvent EVENT_BEAT_MISTY
; PRET| 	jr z, .beforeBeat
; PRET| 	CheckEventReuseA EVENT_GOT_TM11
; PRET| 	jr nz, .afterBeat
; PRET| 	call z, CeruleanGymReceiveTM11
; PRET| 	call DisableWaitingAfterTextDisplay
; PRET| 	jr .done

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] CeruleanGymMistyText.afterBeat (scripts/CeruleanGym.asm:102-104) — at scripts/CeruleanGym.asm:102: .TM11ExplanationText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .TM11ExplanationText
; PRET| 	call PrintText
; PRET| 	jr .done

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] CeruleanGymMistyText.beforeBeat (scripts/CeruleanGym.asm:106-125) — at scripts/CeruleanGym.asm:106: .PreBattleText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .PreBattleText
; PRET| 	call PrintText
; PRET| 	ld hl, wStatusFlags3
; PRET| 	set BIT_TALKED_TO_TRAINER, [hl]
; PRET| 	set BIT_PRINT_END_BATTLE_TEXT, [hl]
; PRET| 	ld hl, CeruleanGymMistyReceivedCascadeBadgeText
; PRET| 	ld de, CeruleanGymMistyReceivedCascadeBadgeText
; PRET| 	call SaveEndBattleTextPointers
; PRET| 	ldh a, [hSpriteIndex]
; PRET| 	ld [wSpriteIndex], a
; PRET| 	call EngageMapTrainer
; PRET| 	call InitBattleEnemyParameters
; PRET| 	ld a, $2
; PRET| 	ld [wGymLeaderNo], a
; PRET| 	xor a
; PRET| 	ldh [hJoyHeld], a
; PRET| 	ld a, SCRIPT_CERULEANGYM_MISTY_POST_BATTLE
; PRET| 	ld [wCeruleanGymCurScript], a
; PRET| .done
; PRET| 	jp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[text-sound-command-unported] CeruleanGymMistyText.PreBattleText (scripts/CeruleanGym.asm:128-150) — at scripts/CeruleanGym.asm:141: sound_get_item_1
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _CeruleanGymMistyPreBattleText
; PRET| 	text_end
; PRET| 
; PRET| .TM11ExplanationText:
; PRET| 	text_far _CeruleanGymMistyTM11ExplanationText
; PRET| 	text_end
; PRET| 
; PRET| CeruleanGymMistyCascadeBadgeInfoText:
; PRET| 	text_far _CeruleanGymMistyCascadeBadgeInfoText
; PRET| 	text_end
; PRET| 
; PRET| CeruleanGymMistyReceivedTM11Text:
; PRET| 	text_far _CeruleanGymMistyReceivedTM11Text
; PRET| 	sound_get_item_1
; PRET| 	text_end
; PRET| 
; PRET| CeruleanGymMistyTM11NoRoomText:
; PRET| 	text_far _CeruleanGymMistyTM11NoRoomText
; PRET| 	text_end
; PRET| 
; PRET| CeruleanGymMistyReceivedCascadeBadgeText:
; PRET| 	text_far _CeruleanGymMistyReceivedCascadeBadgeText
; PRET| 	text_end

CeruleanGymCooltrainerFText:
    mov esi, CeruleanGymTrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] CeruleanGymBattleText1 (scripts/CeruleanGym.asm:159-168) — a generated asset already defines CeruleanGymBattleText1
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _CeruleanGymBattleText1
; PRET| 	text_end
; PRET| 
; PRET| CeruleanGymEndBattleText1:
; PRET| 	text_far _CeruleanGymEndBattleText1
; PRET| 	text_end
; PRET| 
; PRET| CeruleanGymAfterBattleText1:
; PRET| 	text_far _CeruleanGymAfterBattleText1
; PRET| 	text_end

CeruleanGymSwimmerText:
    mov esi, CeruleanGymTrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] CeruleanGymBattleText2 (scripts/CeruleanGym.asm:177-186) — a generated asset already defines CeruleanGymBattleText2
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _CeruleanGymBattleText2
; PRET| 	text_end
; PRET| 
; PRET| CeruleanGymEndBattleText2:
; PRET| 	text_far _CeruleanGymEndBattleText2
; PRET| 	text_end
; PRET| 
; PRET| CeruleanGymAfterBattleText2:
; PRET| 	text_far _CeruleanGymAfterBattleText2
; PRET| 	text_end

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] CeruleanGymGymGuideText (scripts/CeruleanGym.asm:190-194) — at scripts/CeruleanGym.asm:191: .afterBeat is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEvent EVENT_BEAT_MISTY
; PRET| 	jr nz, .afterBeat
; PRET| 	ld hl, .ChampInMakingText
; PRET| 	call PrintText
; PRET| 	jr .done

.afterBeat:
    mov esi, .BeatMistyText
    call PrintText
.done:
    jmp TextScriptEnd

.ChampInMakingText:
    text_far _CeruleanGymGymGuideChampInMakingText
    text_end
.BeatMistyText:
    text_far _CeruleanGymGymGuideBeatMistyText
    text_end
