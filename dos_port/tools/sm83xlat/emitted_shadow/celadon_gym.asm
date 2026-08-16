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


global CeladonGymBeauty1Text
global CeladonGymBeauty2Text
global CeladonGymBeauty3Text
global CeladonGymCooltrainerF1Text
global CeladonGymCooltrainerF2Text
global CeladonGymCooltrainerF3Text
global CeladonGymCooltrainerF4Text
global CeladonGymResetScripts
global CeladonGym_ScriptPointers

extern CeladonGymAfterBattleText2   ; NOT YET DEFINED IN THE PORT
extern CeladonGymAfterBattleText3   ; NOT YET DEFINED IN THE PORT
extern CeladonGymAfterBattleText4   ; NOT YET DEFINED IN THE PORT
extern CeladonGymAfterBattleText5   ; NOT YET DEFINED IN THE PORT
extern CeladonGymAfterBattleText6   ; NOT YET DEFINED IN THE PORT
extern CeladonGymAfterBattleText7   ; NOT YET DEFINED IN THE PORT
extern CeladonGymAfterBattleText8   ; NOT YET DEFINED IN THE PORT
extern CeladonGymBattleText2   ; NOT YET DEFINED IN THE PORT
extern CeladonGymBattleText3   ; NOT YET DEFINED IN THE PORT
extern CeladonGymBattleText4   ; NOT YET DEFINED IN THE PORT
extern CeladonGymBattleText5   ; NOT YET DEFINED IN THE PORT
extern CeladonGymBattleText6   ; NOT YET DEFINED IN THE PORT
extern CeladonGymBattleText7   ; NOT YET DEFINED IN THE PORT
extern CeladonGymBattleText8   ; NOT YET DEFINED IN THE PORT
extern CeladonGymEndBattleText2   ; NOT YET DEFINED IN THE PORT
extern CeladonGymEndBattleText3   ; NOT YET DEFINED IN THE PORT
extern CeladonGymEndBattleText4   ; NOT YET DEFINED IN THE PORT
extern CeladonGymEndBattleText5   ; NOT YET DEFINED IN THE PORT
extern CeladonGymEndBattleText6   ; NOT YET DEFINED IN THE PORT
extern CeladonGymEndBattleText7   ; NOT YET DEFINED IN THE PORT
extern CeladonGymEndBattleText8   ; NOT YET DEFINED IN THE PORT
extern CeladonGymErikaPostBattleScript   ; NOT YET DEFINED IN THE PORT
extern CeladonGymErikaText   ; NOT YET DEFINED IN THE PORT
extern CeladonGymRainbowBadgeInfoText   ; NOT YET DEFINED IN THE PORT
extern CeladonGymReceiveTM21   ; NOT YET DEFINED IN THE PORT
extern CeladonGymReceivedTM21Text   ; NOT YET DEFINED IN THE PORT
extern CeladonGymTM21NoRoomText   ; NOT YET DEFINED IN THE PORT
extern CeladonGymTrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern CeladonGymTrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern CeladonGymTrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern CeladonGymTrainerHeader3   ; NOT YET DEFINED IN THE PORT
extern CeladonGymTrainerHeader4   ; NOT YET DEFINED IN THE PORT
extern CeladonGymTrainerHeader5   ; NOT YET DEFINED IN THE PORT
extern CeladonGymTrainerHeader6   ; NOT YET DEFINED IN THE PORT
extern CeladonGymTrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern CeladonGym_Script   ; NOT YET DEFINED IN THE PORT
extern CeladonGym_TextPointers   ; NOT YET DEFINED IN THE PORT
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
extern _CeladonGymErikaPostBattleAdviceText   ; NOT YET DEFINED IN THE PORT
extern _CeladonGymErikaPreBattleText   ; NOT YET DEFINED IN THE PORT
extern _CeladonGymErikaReceivedRainbowBadgeText   ; NOT YET DEFINED IN THE PORT
extern _CeladonGymRainbowBadgeInfoText   ; NOT YET DEFINED IN THE PORT
extern _CeladonGymReceivedTM21Text   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_CELADONGYM_ERIKA_POST_BATTLE            equ 3
TEXT_CELADONGYM_ERIKA                          equ 1
TEXT_CELADONGYM_COOLTRAINER_F1                 equ 2
TEXT_CELADONGYM_BEAUTY1                        equ 3
TEXT_CELADONGYM_COOLTRAINER_F2                 equ 4
TEXT_CELADONGYM_BEAUTY2                        equ 5
TEXT_CELADONGYM_COOLTRAINER_F3                 equ 6
TEXT_CELADONGYM_BEAUTY3                        equ 7
TEXT_CELADONGYM_COOLTRAINER_F4                 equ 8
TEXT_CELADONGYM_RAINBOWBADGE_INFO              equ 9
TEXT_CELADONGYM_RECEIVED_TM21                  equ 10
TEXT_CELADONGYM_TM21_NO_ROOM                   equ 11

; pret RAM names the port still spells in SCREAMING_SNAKE. Guarded, so
; this file assembles both before and after the memmap rename lands.
%ifndef wCurrentMapScriptFlags
wCurrentMapScriptFlags                         equ W_CURRENT_MAP_SCRIPT_FLAGS
%endif
%ifndef wObtainedBadges
wObtainedBadges                                equ W_OBTAINED_BADGES
%endif

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wBeatGymFlags                                  equ 0xD729
wCeladonGymCurScript                           equ 0xD5FE

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] CeladonGym_Script (scripts/CeladonGym.asm:2-12) — at scripts/CeladonGym.asm:5: .LoadNames is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, wCurrentMapScriptFlags
; PRET| 	bit BIT_CUR_MAP_LOADED_2, [hl]
; PRET| 	res BIT_CUR_MAP_LOADED_2, [hl]
; PRET| 	call nz, .LoadNames
; PRET| 	call EnableAutoTextBoxDrawing
; PRET| 	ld hl, CeladonGymTrainerHeaders
; PRET| 	ld de, CeladonGym_ScriptPointers
; PRET| 	ld a, [wCeladonGymCurScript]
; PRET| 	call ExecuteCurMapScriptInTable
; PRET| 	ld [wCeladonGymCurScript], a
; PRET| 	ret

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] CeladonGym_Script.LoadNames (scripts/CeladonGym.asm:15-17) — at scripts/CeladonGym.asm:15: .CityName is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .CityName
; PRET| 	ld de, .LeaderName
; PRET| 	jp LoadGymLeaderAndCityName

; ---------------------------------------------------------------------------
; BAIL[inline-text-db] CeladonGym_Script.CityName (scripts/CeladonGym.asm:20-23) — at scripts/CeladonGym.asm:20: db "CELADON CITY@"
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	db "CELADON CITY@"
; PRET| 
; PRET| .LeaderName:
; PRET| 	db "ERIKA@"

CeladonGymResetScripts:
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov [ebp + wCeladonGymCurScript], al
    mov [ebp + wCurMapScript], al
    ret

CeladonGym_ScriptPointers:
    dd CheckFightingMapTrainers
    dd DisplayEnemyTrainerTextAndStartBattle
    dd EndTrainerBattle
    dd CeladonGymErikaPostBattleScript

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] CeladonGymErikaPostBattleScript (scripts/CeladonGym.asm:40-58) — at scripts/CeladonGym.asm:53: .BagFull is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, [wIsInBattle]
; PRET| 	cp $ff
; PRET| 	jp z, CeladonGymResetScripts
; PRET| 	ld a, PAD_CTRL_PAD
; PRET| 	ld [wJoyIgnore], a
; PRET| 
; PRET| CeladonGymReceiveTM21:
; PRET| 	ld a, TEXT_CELADONGYM_RAINBOWBADGE_INFO
; PRET| 	ldh [hTextID], a
; PRET| 	call DisplayTextID
; PRET| 	SetEvent EVENT_BEAT_ERIKA
; PRET| 	lb bc, TM_MEGA_DRAIN, 1
; PRET| 	call GiveItem
; PRET| 	jr nc, .BagFull
; PRET| 	ld a, TEXT_CELADONGYM_RECEIVED_TM21
; PRET| 	ldh [hTextID], a
; PRET| 	call DisplayTextID
; PRET| 	SetEvent EVENT_GOT_TM21
; PRET| 	jr .gymVictory

; ---------------------------------------------------------------------------
; BAIL[event-range-macro] CeladonGymReceiveTM21.BagFull (scripts/CeladonGym.asm:60-72) — at scripts/CeladonGym.asm:70: SetEventRange EVENT_BEAT_CELADON_GYM_TRAINER_0, EVENT_BEAT_CELADON_GYM_TRAINER_6
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, TEXT_CELADONGYM_TM21_NO_ROOM
; PRET| 	ldh [hTextID], a
; PRET| 	call DisplayTextID
; PRET| .gymVictory
; PRET| 	ld hl, wObtainedBadges
; PRET| 	set BIT_RAINBOWBADGE, [hl]
; PRET| 	ld hl, wBeatGymFlags
; PRET| 	set BIT_RAINBOWBADGE, [hl]
; PRET| 
; PRET| 	; deactivate gym trainers
; PRET| 	SetEventRange EVENT_BEAT_CELADON_GYM_TRAINER_0, EVENT_BEAT_CELADON_GYM_TRAINER_6
; PRET| 
; PRET| 	jp CeladonGymResetScripts

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] CeladonGym_TextPointers (scripts/CeladonGym.asm:75-104) — a generated asset already defines CeladonGymTrainerHeaders
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	def_text_pointers
; PRET| 	dw_const CeladonGymErikaText,            TEXT_CELADONGYM_ERIKA
; PRET| 	dw_const CeladonGymCooltrainerF1Text,    TEXT_CELADONGYM_COOLTRAINER_F1
; PRET| 	dw_const CeladonGymBeauty1Text,          TEXT_CELADONGYM_BEAUTY1
; PRET| 	dw_const CeladonGymCooltrainerF2Text,    TEXT_CELADONGYM_COOLTRAINER_F2
; PRET| 	dw_const CeladonGymBeauty2Text,          TEXT_CELADONGYM_BEAUTY2
; PRET| 	dw_const CeladonGymCooltrainerF3Text,    TEXT_CELADONGYM_COOLTRAINER_F3
; PRET| 	dw_const CeladonGymBeauty3Text,          TEXT_CELADONGYM_BEAUTY3
; PRET| 	dw_const CeladonGymCooltrainerF4Text,    TEXT_CELADONGYM_COOLTRAINER_F4
; PRET| 	dw_const CeladonGymRainbowBadgeInfoText, TEXT_CELADONGYM_RAINBOWBADGE_INFO
; PRET| 	dw_const CeladonGymReceivedTM21Text,     TEXT_CELADONGYM_RECEIVED_TM21
; PRET| 	dw_const CeladonGymTM21NoRoomText,       TEXT_CELADONGYM_TM21_NO_ROOM
; PRET| 
; PRET| CeladonGymTrainerHeaders:
; PRET| 	def_trainers 2
; PRET| CeladonGymTrainerHeader0:
; PRET| 	trainer EVENT_BEAT_CELADON_GYM_TRAINER_0, 2, CeladonGymBattleText2, CeladonGymEndBattleText2, CeladonGymAfterBattleText2
; PRET| CeladonGymTrainerHeader1:
; PRET| 	trainer EVENT_BEAT_CELADON_GYM_TRAINER_1, 2, CeladonGymBattleText3, CeladonGymEndBattleText3, CeladonGymAfterBattleText3
; PRET| CeladonGymTrainerHeader2:
; PRET| 	trainer EVENT_BEAT_CELADON_GYM_TRAINER_2, 4, CeladonGymBattleText4, CeladonGymEndBattleText4, CeladonGymAfterBattleText4
; PRET| CeladonGymTrainerHeader3:
; PRET| 	trainer EVENT_BEAT_CELADON_GYM_TRAINER_3, 4, CeladonGymBattleText5, CeladonGymEndBattleText5, CeladonGymAfterBattleText5
; PRET| CeladonGymTrainerHeader4:
; PRET| 	trainer EVENT_BEAT_CELADON_GYM_TRAINER_4, 2, CeladonGymBattleText6, CeladonGymEndBattleText6, CeladonGymAfterBattleText6
; PRET| CeladonGymTrainerHeader5:
; PRET| 	trainer EVENT_BEAT_CELADON_GYM_TRAINER_5, 2, CeladonGymBattleText7, CeladonGymEndBattleText7, CeladonGymAfterBattleText7
; PRET| CeladonGymTrainerHeader6:
; PRET| 	trainer EVENT_BEAT_CELADON_GYM_TRAINER_6, 3, CeladonGymBattleText8, CeladonGymEndBattleText8, CeladonGymAfterBattleText8
; PRET| 	db -1 ; end

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] CeladonGymErikaText (scripts/CeladonGym.asm:108-114) — at scripts/CeladonGym.asm:109: .beforeBeat is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEvent EVENT_BEAT_ERIKA
; PRET| 	jr z, .beforeBeat
; PRET| 	CheckEventReuseA EVENT_GOT_TM21
; PRET| 	jr nz, .afterBeat
; PRET| 	call z, CeladonGymReceiveTM21
; PRET| 	call DisableWaitingAfterTextDisplay
; PRET| 	jr .done

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] CeladonGymErikaText.afterBeat (scripts/CeladonGym.asm:116-118) — at scripts/CeladonGym.asm:116: .PostBattleAdviceText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .PostBattleAdviceText
; PRET| 	call PrintText
; PRET| 	jr .done

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] CeladonGymErikaText.beforeBeat (scripts/CeladonGym.asm:120-138) — at scripts/CeladonGym.asm:120: .PreBattleText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .PreBattleText
; PRET| 	call PrintText
; PRET| 	ld hl, wStatusFlags3
; PRET| 	set BIT_TALKED_TO_TRAINER, [hl]
; PRET| 	set BIT_PRINT_END_BATTLE_TEXT, [hl]
; PRET| 	ld hl, .ReceivedRainbowBadgeText
; PRET| 	ld de, .ReceivedRainbowBadgeText
; PRET| 	call SaveEndBattleTextPointers
; PRET| 	ldh a, [hSpriteIndex]
; PRET| 	ld [wSpriteIndex], a
; PRET| 	call EngageMapTrainer
; PRET| 	call InitBattleEnemyParameters
; PRET| 	ld a, $4
; PRET| 	ld [wGymLeaderNo], a
; PRET| 	ld a, SCRIPT_CELADONGYM_ERIKA_POST_BATTLE
; PRET| 	ld [wCeladonGymCurScript], a
; PRET| 	ld [wCurMapScript], a
; PRET| .done
; PRET| 	jp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[text-sound-command-unported] CeladonGymErikaText.PreBattleText (scripts/CeladonGym.asm:141-164) — at scripts/CeladonGym.asm:158: sound_get_item_1
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _CeladonGymErikaPreBattleText
; PRET| 	text_end
; PRET| 
; PRET| .ReceivedRainbowBadgeText:
; PRET| 	text_far _CeladonGymErikaReceivedRainbowBadgeText
; PRET| 	text_end
; PRET| 
; PRET| .PostBattleAdviceText:
; PRET| 	text_far _CeladonGymErikaPostBattleAdviceText
; PRET| 	text_end
; PRET| 
; PRET| CeladonGymRainbowBadgeInfoText:
; PRET| 	text_far _CeladonGymRainbowBadgeInfoText
; PRET| 	text_end
; PRET| 
; PRET| CeladonGymReceivedTM21Text:
; PRET| 	text_far _CeladonGymReceivedTM21Text
; PRET| 	sound_get_item_1
; PRET| 	text_far _TM21ExplanationText
; PRET| 	text_end
; PRET| 
; PRET| CeladonGymTM21NoRoomText:
; PRET| 	text_far _CeladonGymTM21NoRoomText
; PRET| 	text_end

CeladonGymCooltrainerF1Text:
    mov esi, CeladonGymTrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] CeladonGymBattleText2 (scripts/CeladonGym.asm:173-182) — a generated asset already defines CeladonGymBattleText2
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _CeladonGymBattleText2
; PRET| 	text_end
; PRET| 
; PRET| CeladonGymEndBattleText2:
; PRET| 	text_far _CeladonGymEndBattleText2
; PRET| 	text_end
; PRET| 
; PRET| CeladonGymAfterBattleText2:
; PRET| 	text_far _CeladonGymAfterBattleText2
; PRET| 	text_end

CeladonGymBeauty1Text:
    mov esi, CeladonGymTrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] CeladonGymBattleText3 (scripts/CeladonGym.asm:191-200) — a generated asset already defines CeladonGymBattleText3
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _CeladonGymBattleText3
; PRET| 	text_end
; PRET| 
; PRET| CeladonGymEndBattleText3:
; PRET| 	text_far _CeladonGymEndBattleText3
; PRET| 	text_end
; PRET| 
; PRET| CeladonGymAfterBattleText3:
; PRET| 	text_far _CeladonGymAfterBattleText3
; PRET| 	text_end

CeladonGymCooltrainerF2Text:
    mov esi, CeladonGymTrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] CeladonGymBattleText4 (scripts/CeladonGym.asm:209-218) — a generated asset already defines CeladonGymBattleText4
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _CeladonGymBattleText4
; PRET| 	text_end
; PRET| 
; PRET| CeladonGymEndBattleText4:
; PRET| 	text_far _CeladonGymEndBattleText4
; PRET| 	text_end
; PRET| 
; PRET| CeladonGymAfterBattleText4:
; PRET| 	text_far _CeladonGymAfterBattleText4
; PRET| 	text_end

CeladonGymBeauty2Text:
    mov esi, CeladonGymTrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] CeladonGymBattleText5 (scripts/CeladonGym.asm:227-236) — a generated asset already defines CeladonGymBattleText5
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _CeladonGymBattleText5
; PRET| 	text_end
; PRET| 
; PRET| CeladonGymEndBattleText5:
; PRET| 	text_far _CeladonGymEndBattleText5
; PRET| 	text_end
; PRET| 
; PRET| CeladonGymAfterBattleText5:
; PRET| 	text_far _CeladonGymAfterBattleText5
; PRET| 	text_end

CeladonGymCooltrainerF3Text:
    mov esi, CeladonGymTrainerHeader4
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] CeladonGymBattleText6 (scripts/CeladonGym.asm:245-254) — a generated asset already defines CeladonGymBattleText6
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _CeladonGymBattleText6
; PRET| 	text_end
; PRET| 
; PRET| CeladonGymEndBattleText6:
; PRET| 	text_far _CeladonGymEndBattleText6
; PRET| 	text_end
; PRET| 
; PRET| CeladonGymAfterBattleText6:
; PRET| 	text_far _CeladonGymAfterBattleText6
; PRET| 	text_end

CeladonGymBeauty3Text:
    mov esi, CeladonGymTrainerHeader5
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] CeladonGymBattleText7 (scripts/CeladonGym.asm:263-272) — a generated asset already defines CeladonGymBattleText7
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _CeladonGymBattleText7
; PRET| 	text_end
; PRET| 
; PRET| CeladonGymEndBattleText7:
; PRET| 	text_far _CeladonGymEndBattleText7
; PRET| 	text_end
; PRET| 
; PRET| CeladonGymAfterBattleText7:
; PRET| 	text_far _CeladonGymAfterBattleText7
; PRET| 	text_end

CeladonGymCooltrainerF4Text:
    mov esi, CeladonGymTrainerHeader6
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] CeladonGymBattleText8 (scripts/CeladonGym.asm:281-290) — a generated asset already defines CeladonGymBattleText8
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _CeladonGymBattleText8
; PRET| 	text_end
; PRET| 
; PRET| CeladonGymEndBattleText8:
; PRET| 	text_far _CeladonGymEndBattleText8
; PRET| 	text_end
; PRET| 
; PRET| CeladonGymAfterBattleText8:
; PRET| 	text_far _CeladonGymAfterBattleText8
; PRET| 	text_end
