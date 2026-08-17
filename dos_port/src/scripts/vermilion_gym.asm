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

global VermilionGymGentlemanText
global VermilionGymResetScripts
global VermilionGymSailorText
global VermilionGymSetDoorTile
global VermilionGymSuperNerdText
global VermilionGym_ScriptPointers

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
extern PlaySound   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern ReplaceTileBlock   ; NOT YET DEFINED IN THE PORT
extern SaveEndBattleTextPointers   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern VermilionGymGentlemanAfterBattleText   ; NOT YET DEFINED IN THE PORT
extern VermilionGymGentlemanBattleText   ; NOT YET DEFINED IN THE PORT
extern VermilionGymGentlemanEndBattleText   ; NOT YET DEFINED IN THE PORT
extern VermilionGymGymGuideText   ; NOT YET DEFINED IN THE PORT
extern VermilionGymLTSurgeAfterBattleScript   ; NOT YET DEFINED IN THE PORT
extern VermilionGymLTSurgeReceiveTM24Script   ; NOT YET DEFINED IN THE PORT
extern VermilionGymLTSurgeReceivedTM24Text   ; NOT YET DEFINED IN THE PORT
extern VermilionGymLTSurgeReceivedThunderBadgeText   ; NOT YET DEFINED IN THE PORT
extern VermilionGymLTSurgeTM24NoRoomText   ; NOT YET DEFINED IN THE PORT
extern VermilionGymLTSurgeText   ; NOT YET DEFINED IN THE PORT
extern VermilionGymLTSurgeThunderBadgeInfoText   ; NOT YET DEFINED IN THE PORT
extern VermilionGymSailorAfterBattleText   ; NOT YET DEFINED IN THE PORT
extern VermilionGymSailorBattleText   ; NOT YET DEFINED IN THE PORT
extern VermilionGymSailorEndBattleText   ; NOT YET DEFINED IN THE PORT
extern VermilionGymSuperNerdAfterBattleText   ; NOT YET DEFINED IN THE PORT
extern VermilionGymSuperNerdBattleText   ; NOT YET DEFINED IN THE PORT
extern VermilionGymSuperNerdEndBattleText   ; NOT YET DEFINED IN THE PORT
extern VermilionGymTrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern VermilionGymTrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern VermilionGymTrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern VermilionGymTrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern VermilionGym_Script   ; NOT YET DEFINED IN THE PORT
extern VermilionGym_TextPointers   ; NOT YET DEFINED IN THE PORT
extern _VermilionGymGymGuideBeatLTSurgeText   ; NOT YET DEFINED IN THE PORT
extern _VermilionGymGymGuideChampInMakingText   ; NOT YET DEFINED IN THE PORT
extern _VermilionGymLTSurgePostBattleAdviceText   ; NOT YET DEFINED IN THE PORT
extern _VermilionGymLTSurgePreBattleText   ; NOT YET DEFINED IN THE PORT
extern _VermilionGymLTSurgeReceivedTM24Text   ; NOT YET DEFINED IN THE PORT
extern _VermilionGymLTSurgeThunderBadgeInfoText   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_VERMILIONGYM_LT_SURGE_AFTER_BATTLE      equ 3
TEXT_VERMILIONGYM_LT_SURGE                     equ 1
TEXT_VERMILIONGYM_GENTLEMAN                    equ 2
TEXT_VERMILIONGYM_SUPER_NERD                   equ 3
TEXT_VERMILIONGYM_SAILOR                       equ 4
TEXT_VERMILIONGYM_GYM_GUIDE                    equ 5
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

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] VermilionGym_Script (scripts/VermilionGym.asm:2-17) — at scripts/VermilionGym.asm:6: .LoadNames is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, wCurrentMapScriptFlags
; PRET| 	bit BIT_CUR_MAP_LOADED_1, [hl]
; PRET| 	res BIT_CUR_MAP_LOADED_1, [hl]
; PRET| 	push hl
; PRET| 	call nz, .LoadNames
; PRET| 	pop hl
; PRET| 	bit BIT_CUR_MAP_LOADED_2, [hl]
; PRET| 	res BIT_CUR_MAP_LOADED_2, [hl]
; PRET| 	call nz, VermilionGymSetDoorTile
; PRET| 	call EnableAutoTextBoxDrawing
; PRET| 	ld hl, VermilionGymTrainerHeaders
; PRET| 	ld de, VermilionGym_ScriptPointers
; PRET| 	ld a, [wVermilionGymCurScript]
; PRET| 	call ExecuteCurMapScriptInTable
; PRET| 	ld [wVermilionGymCurScript], a
; PRET| 	ret

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] VermilionGym_Script.LoadNames (scripts/VermilionGym.asm:20-22) — at scripts/VermilionGym.asm:20: .CityName is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .CityName
; PRET| 	ld de, .LeaderName
; PRET| 	jp LoadGymLeaderAndCityName

; ---------------------------------------------------------------------------
; BAIL[inline-text-db] VermilionGym_Script.CityName (scripts/VermilionGym.asm:25-28) — at scripts/VermilionGym.asm:25: db "VERMILION CITY@"
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	db "VERMILION CITY@"
; PRET| 
; PRET| .LeaderName:
; PRET| 	db "LT.SURGE@"

VermilionGymSetDoorTile:
    CheckEvent EVENT_2ND_LOCK_OPENED
    jnz .doorsOpen
    mov al, 0x24
    jmp .replaceTile

.doorsOpen:
    mov al, SFX_GO_INSIDE
    call PlaySound
    mov al, 0x5
.replaceTile:
    mov [ebp + wNewTileBlockID], al
    mov bx, ((2) << 8) | (2)
; DEVIATION{class=banking; pret=macros/predef.asm:predef_jump; behavior=Predef dispatch replaced by a direct jmp, and the predef id is not left in A because no reader is live; evidence=PredefPointers is unported and the flat model needs no bank switch, dataflow shows A dead after this site; lifetime=retired when PredefPointers is ported}
    jmp ReplaceTileBlock

VermilionGymResetScripts:
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov [ebp + wVermilionGymCurScript], al
    mov [ebp + wCurMapScript], al
    ret

VermilionGym_ScriptPointers:
    dd CheckFightingMapTrainers
    dd DisplayEnemyTrainerTextAndStartBattle
    dd EndTrainerBattle
    dd VermilionGymLTSurgeAfterBattleScript

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] VermilionGymLTSurgeAfterBattleScript (scripts/VermilionGym.asm:59-77) — at scripts/VermilionGym.asm:72: .bag_full is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, [wIsInBattle]
; PRET| 	cp $ff ; did we lose?
; PRET| 	jp z, VermilionGymResetScripts
; PRET| 	ld a, PAD_CTRL_PAD
; PRET| 	ld [wJoyIgnore], a
; PRET| 
; PRET| VermilionGymLTSurgeReceiveTM24Script:
; PRET| 	ld a, TEXT_VERMILIONGYM_LT_SURGE_THUNDER_BADGE_INFO
; PRET| 	ldh [hTextID], a
; PRET| 	call DisplayTextID
; PRET| 	SetEvent EVENT_BEAT_LT_SURGE
; PRET| 	lb bc, TM_THUNDERBOLT, 1
; PRET| 	call GiveItem
; PRET| 	jr nc, .bag_full
; PRET| 	ld a, TEXT_VERMILIONGYM_LT_SURGE_RECEIVED_TM24
; PRET| 	ldh [hTextID], a
; PRET| 	call DisplayTextID
; PRET| 	SetEvent EVENT_GOT_TM24
; PRET| 	jr .gym_victory

; ---------------------------------------------------------------------------
; BAIL[event-range-macro] VermilionGymLTSurgeReceiveTM24Script.bag_full (scripts/VermilionGym.asm:79-91) — at scripts/VermilionGym.asm:89: SetEventRange EVENT_BEAT_VERMILION_GYM_TRAINER_0, EVENT_BEAT_VERMILION_GYM_TRAINER_2
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, TEXT_VERMILIONGYM_LT_SURGE_TM24_NO_ROOM
; PRET| 	ldh [hTextID], a
; PRET| 	call DisplayTextID
; PRET| .gym_victory
; PRET| 	ld hl, wObtainedBadges
; PRET| 	set BIT_THUNDERBADGE, [hl]
; PRET| 	ld hl, wBeatGymFlags
; PRET| 	set BIT_THUNDERBADGE, [hl]
; PRET| 
; PRET| 	; deactivate gym trainers
; PRET| 	SetEventRange EVENT_BEAT_VERMILION_GYM_TRAINER_0, EVENT_BEAT_VERMILION_GYM_TRAINER_2
; PRET| 
; PRET| 	jp VermilionGymResetScripts

; ---------------------------------------------------------------------------
; VermilionGym_TextPointers (scripts/VermilionGym.asm:94-112) — Tier-1 data: VermilionGymTrainerHeaders is generated into assets/trainer_headers.inc.

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] VermilionGymLTSurgeText (scripts/VermilionGym.asm:116-122) — at scripts/VermilionGym.asm:117: .before_beat is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEvent EVENT_BEAT_LT_SURGE
; PRET| 	jr z, .before_beat
; PRET| 	CheckEventReuseA EVENT_GOT_TM24
; PRET| 	jr nz, .got_tm24_already
; PRET| 	call z, VermilionGymLTSurgeReceiveTM24Script
; PRET| 	call DisableWaitingAfterTextDisplay
; PRET| 	jr .text_script_end

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] VermilionGymLTSurgeText.got_tm24_already (scripts/VermilionGym.asm:124-126) — at scripts/VermilionGym.asm:124: .PostBattleAdviceText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .PostBattleAdviceText
; PRET| 	call PrintText
; PRET| 	jr .text_script_end

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] VermilionGymLTSurgeText.before_beat (scripts/VermilionGym.asm:128-148) — at scripts/VermilionGym.asm:128: .PreBattleText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .PreBattleText
; PRET| 	call PrintText
; PRET| 	ld hl, wStatusFlags3
; PRET| 	set BIT_TALKED_TO_TRAINER, [hl]
; PRET| 	set BIT_PRINT_END_BATTLE_TEXT, [hl]
; PRET| 	ld hl, VermilionGymLTSurgeReceivedThunderBadgeText
; PRET| 	ld de, VermilionGymLTSurgeReceivedThunderBadgeText
; PRET| 	call SaveEndBattleTextPointers
; PRET| 	ldh a, [hSpriteIndex]
; PRET| 	ld [wSpriteIndex], a
; PRET| 	call EngageMapTrainer
; PRET| 	call InitBattleEnemyParameters
; PRET| 	ld a, $3
; PRET| 	ld [wGymLeaderNo], a
; PRET| 	xor a
; PRET| 	ldh [hJoyHeld], a
; PRET| 	ld a, SCRIPT_VERMILIONGYM_LT_SURGE_AFTER_BATTLE
; PRET| 	ld [wVermilionGymCurScript], a
; PRET| 	ld [wCurMapScript], a
; PRET| .text_script_end
; PRET| 	jp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[text-sound-command-unported] VermilionGymLTSurgeText.PreBattleText (scripts/VermilionGym.asm:151-174) — at scripts/VermilionGym.asm:164: sound_get_key_item
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _VermilionGymLTSurgePreBattleText
; PRET| 	text_end
; PRET| 
; PRET| .PostBattleAdviceText:
; PRET| 	text_far _VermilionGymLTSurgePostBattleAdviceText
; PRET| 	text_end
; PRET| 
; PRET| VermilionGymLTSurgeThunderBadgeInfoText:
; PRET| 	text_far _VermilionGymLTSurgeThunderBadgeInfoText
; PRET| 	text_end
; PRET| 
; PRET| VermilionGymLTSurgeReceivedTM24Text:
; PRET| 	text_far _VermilionGymLTSurgeReceivedTM24Text
; PRET| 	sound_get_key_item
; PRET| 	text_far _TM24ExplanationText
; PRET| 	text_end
; PRET| 
; PRET| VermilionGymLTSurgeTM24NoRoomText:
; PRET| 	text_far _VermilionGymLTSurgeTM24NoRoomText
; PRET| 	text_end
; PRET| 
; PRET| VermilionGymLTSurgeReceivedThunderBadgeText:
; PRET| 	text_far _VermilionGymLTSurgeReceivedThunderBadgeText
; PRET| 	text_end

VermilionGymGentlemanText:
    mov esi, VermilionGymTrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; VermilionGymGentlemanBattleText (scripts/VermilionGym.asm:183-192) — Tier-1 data: VermilionGymGentlemanBattleText is generated into assets/trainer_headers.inc.

VermilionGymSuperNerdText:
    mov esi, VermilionGymTrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; VermilionGymSuperNerdBattleText (scripts/VermilionGym.asm:201-210) — Tier-1 data: VermilionGymSuperNerdBattleText is generated into assets/trainer_headers.inc.

VermilionGymSailorText:
    mov esi, VermilionGymTrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; VermilionGymSailorBattleText (scripts/VermilionGym.asm:219-228) — Tier-1 data: VermilionGymSailorBattleText is generated into assets/trainer_headers.inc.

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] VermilionGymGymGuideText (scripts/VermilionGym.asm:232-237) — at scripts/VermilionGym.asm:237: .text_script_end is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, [wBeatGymFlags]
; PRET| 	bit BIT_THUNDERBADGE, a
; PRET| 	jr nz, .got_thunderbadge
; PRET| 	ld hl, .ChampInMakingText
; PRET| 	call PrintText
; PRET| 	jr .text_script_end

.got_thunderbadge:
    mov esi, .BeatLTSurgeText
    call PrintText
.text_script_end:
    jmp TextScriptEnd

.ChampInMakingText:
    text_far _VermilionGymGymGuideChampInMakingText
    text_end
.BeatLTSurgeText:
    text_far _VermilionGymGymGuideBeatLTSurgeText
    text_end
