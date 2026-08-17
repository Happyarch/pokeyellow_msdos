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

%include "assets/trainer_headers.inc"

global CeladonGymBeauty1Text
global CeladonGymBeauty2Text
global CeladonGymBeauty3Text
global CeladonGymCooltrainerF1Text
global CeladonGymCooltrainerF2Text
global CeladonGymCooltrainerF3Text
global CeladonGymCooltrainerF4Text
global CeladonGymErikaPostBattleScript
global CeladonGymReceiveTM21
global CeladonGymResetScripts
global CeladonGym_ScriptPointers

extern CeladonGymBattleText2   ; NOT YET DEFINED IN THE PORT
extern CeladonGymBattleText3   ; NOT YET DEFINED IN THE PORT
extern CeladonGymBattleText4   ; NOT YET DEFINED IN THE PORT
extern CeladonGymBattleText5   ; NOT YET DEFINED IN THE PORT
extern CeladonGymBattleText6   ; NOT YET DEFINED IN THE PORT
extern CeladonGymBattleText7   ; NOT YET DEFINED IN THE PORT
extern CeladonGymBattleText8   ; NOT YET DEFINED IN THE PORT
extern CeladonGymErikaText   ; NOT YET DEFINED IN THE PORT
extern CeladonGymRainbowBadgeInfoText   ; NOT YET DEFINED IN THE PORT
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

%assign event_byte -1
CeladonGymResetScripts:
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov [ebp + wCeladonGymCurScript], al
    mov [ebp + wCurMapScript], al
    ret

%assign event_byte -1
CeladonGym_ScriptPointers:
    dd CheckFightingMapTrainers
    dd DisplayEnemyTrainerTextAndStartBattle
    dd EndTrainerBattle
    dd CeladonGymErikaPostBattleScript

%assign event_byte -1
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

%assign event_byte -1
CeladonGymCooltrainerF1Text:
    mov esi, CeladonGymTrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; CeladonGymBattleText2 (scripts/CeladonGym.asm:173-182) — not re-emitted: CeladonGymBattleText2 is already defined in assets/trainer_headers.inc.

%assign event_byte -1
CeladonGymBeauty1Text:
    mov esi, CeladonGymTrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

; CeladonGymBattleText3 (scripts/CeladonGym.asm:191-200) — not re-emitted: CeladonGymBattleText3 is already defined in assets/trainer_headers.inc.

%assign event_byte -1
CeladonGymCooltrainerF2Text:
    mov esi, CeladonGymTrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

; CeladonGymBattleText4 (scripts/CeladonGym.asm:209-218) — not re-emitted: CeladonGymBattleText4 is already defined in assets/trainer_headers.inc.

%assign event_byte -1
CeladonGymBeauty2Text:
    mov esi, CeladonGymTrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

; CeladonGymBattleText5 (scripts/CeladonGym.asm:227-236) — not re-emitted: CeladonGymBattleText5 is already defined in assets/trainer_headers.inc.

%assign event_byte -1
CeladonGymCooltrainerF3Text:
    mov esi, CeladonGymTrainerHeader4
    call TalkToTrainer
    jmp TextScriptEnd

; CeladonGymBattleText6 (scripts/CeladonGym.asm:245-254) — not re-emitted: CeladonGymBattleText6 is already defined in assets/trainer_headers.inc.

%assign event_byte -1
CeladonGymBeauty3Text:
    mov esi, CeladonGymTrainerHeader5
    call TalkToTrainer
    jmp TextScriptEnd

; CeladonGymBattleText7 (scripts/CeladonGym.asm:263-272) — not re-emitted: CeladonGymBattleText7 is already defined in assets/trainer_headers.inc.

%assign event_byte -1
CeladonGymCooltrainerF4Text:
    mov esi, CeladonGymTrainerHeader6
    call TalkToTrainer
    jmp TextScriptEnd

; CeladonGymBattleText8 (scripts/CeladonGym.asm:281-290) — not re-emitted: CeladonGymBattleText8 is already defined in assets/trainer_headers.inc.
