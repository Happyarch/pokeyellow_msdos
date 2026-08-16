; PewterGym.asm — translated from pret scripts/PewterGym.asm by dos_port/tools/sm83xlat.
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


global PewterGymBrockPostBattle
global PewterGymCooltrainerMText
global PewterGymGuideAdviceText
global PewterGymGuideBeginAdviceText
global PewterGymGuideFreeServiceText
global PewterGymGuidePostBattleText
global PewterGymGuidePreAdviceText
global PewterGymResetScripts
global PewterGymScriptReceiveTM34
global PewterGymText_5c41c
global PewterGym_ScriptPointers

extern CheckFightingMapTrainers   ; NOT YET DEFINED IN THE PORT
extern DisplayEnemyTrainerTextAndStartBattle   ; NOT YET DEFINED IN THE PORT
extern DisplayTextID   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EndTrainerBattle   ; NOT YET DEFINED IN THE PORT
extern EngageMapTrainer   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern GiveItem   ; NOT YET DEFINED IN THE PORT
extern HideObject   ; NOT YET DEFINED IN THE PORT
extern InitBattleEnemyParameters   ; NOT YET DEFINED IN THE PORT
extern LoadGymLeaderAndCityName   ; NOT YET DEFINED IN THE PORT
extern PewterGymBrockReceivedBoulderBadgeText   ; NOT YET DEFINED IN THE PORT
extern PewterGymBrockText   ; NOT YET DEFINED IN THE PORT
extern PewterGymBrockWaitTakeThisText   ; NOT YET DEFINED IN THE PORT
extern PewterGymCooltrainerMAfterBattleText   ; NOT YET DEFINED IN THE PORT
extern PewterGymCooltrainerMBattleText   ; NOT YET DEFINED IN THE PORT
extern PewterGymCooltrainerMEndBattleText   ; NOT YET DEFINED IN THE PORT
extern PewterGymGuideText   ; NOT YET DEFINED IN THE PORT
extern PewterGymReceivedTM34Text   ; NOT YET DEFINED IN THE PORT
extern PewterGymTM34NoRoomText   ; NOT YET DEFINED IN THE PORT
extern PewterGymTrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern PewterGymTrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern PewterGym_Script   ; NOT YET DEFINED IN THE PORT
extern PewterGym_TextPointers   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern SaveEndBattleTextPointers   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern YesNoChoice   ; NOT YET DEFINED IN THE PORT
extern _PewterGymBrockPostBattleAdviceText   ; NOT YET DEFINED IN THE PORT
extern _PewterGymBrockPreBattleText   ; NOT YET DEFINED IN THE PORT
extern _PewterGymBrockWaitTakeThisText   ; NOT YET DEFINED IN THE PORT
extern _PewterGymGuideAdviceText   ; NOT YET DEFINED IN THE PORT
extern _PewterGymGuideBeginAdviceText   ; NOT YET DEFINED IN THE PORT
extern _PewterGymGuideFreeServiceText   ; NOT YET DEFINED IN THE PORT
extern _PewterGymGuidePostBattleText   ; NOT YET DEFINED IN THE PORT
extern _PewterGymGuidePreAdviceText   ; NOT YET DEFINED IN THE PORT
extern _PewterGymGuyText   ; NOT YET DEFINED IN THE PORT
extern _PewterGymReceivedTM34Text   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_PEWTERGYM_BROCK_POST_BATTLE             equ 3
TEXT_PEWTERGYM_BROCK                           equ 1
TEXT_PEWTERGYM_COOLTRAINER_M                   equ 2
TEXT_PEWTERGYM_GYM_GUIDE                       equ 3
TEXT_PEWTERGYM_BROCK_WAIT_TAKE_THIS            equ 4
TEXT_PEWTERGYM_RECEIVED_TM34                   equ 5
TEXT_PEWTERGYM_TM34_NO_ROOM                    equ 6

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wBeatGymFlags                                  equ 0xD729
wPewterGymCurScript                            equ 0xD5FB
wPikachuSpawnStateFlags                        equ 0xD471

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] PewterGym_Script (scripts/PewterGym.asm:2-12) — at scripts/PewterGym.asm:5: .LoadNames is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, wCurrentMapScriptFlags
; PRET| 	bit BIT_CUR_MAP_LOADED_2, [hl]
; PRET| 	res BIT_CUR_MAP_LOADED_2, [hl]
; PRET| 	call nz, .LoadNames
; PRET| 	call EnableAutoTextBoxDrawing
; PRET| 	ld hl, PewterGymTrainerHeaders
; PRET| 	ld de, PewterGym_ScriptPointers
; PRET| 	ld a, [wPewterGymCurScript]
; PRET| 	call ExecuteCurMapScriptInTable
; PRET| 	ld [wPewterGymCurScript], a
; PRET| 	ret

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] PewterGym_Script.LoadNames (scripts/PewterGym.asm:15-18) — at scripts/PewterGym.asm:15: .CityName is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .CityName
; PRET| 	ld de, .LeaderName
; PRET| 	call LoadGymLeaderAndCityName
; PRET| 	ret

; ---------------------------------------------------------------------------
; BAIL[inline-text-db] PewterGym_Script.CityName (scripts/PewterGym.asm:21-24) — at scripts/PewterGym.asm:21: db "PEWTER CITY@"
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	db "PEWTER CITY@"
; PRET| 
; PRET| .LeaderName:
; PRET| 	db "BROCK@"

PewterGymResetScripts:
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov [ebp + wPewterGymCurScript], al
    mov [ebp + wCurMapScript], al
    ret

PewterGym_ScriptPointers:
    dd CheckFightingMapTrainers
    dd DisplayEnemyTrainerTextAndStartBattle
    dd EndTrainerBattle
    dd PewterGymBrockPostBattle

PewterGymBrockPostBattle:
    mov al, [ebp + wIsInBattle]
    cmp al, 0xff
    jz PewterGymResetScripts
    mov al, PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
PewterGymScriptReceiveTM34:
    mov al, TEXT_PEWTERGYM_BROCK_WAIT_TAKE_THIS
    mov [ebp + hTextID], al
    call DisplayTextID
    pushfd    ; SM83 form writes no flags
        SetEvent EVENT_BEAT_BROCK
    popfd
    mov bx, ((236) << 8) | (1)
    call GiveItem
    jae .BagFull
    mov al, TEXT_PEWTERGYM_RECEIVED_TM34
    mov [ebp + hTextID], al
    call DisplayTextID
    SetEvent EVENT_GOT_TM34
    jmp .gymVictory

.BagFull:
    mov al, TEXT_PEWTERGYM_TM34_NO_ROOM
    mov [ebp + hTextID], al
    call DisplayTextID
.gymVictory:
    mov esi, wObtainedBadges
    or byte [ebp + esi], (1 << (0))
    mov esi, wBeatGymFlags
    or byte [ebp + esi], (1 << (0))
    mov al, 5
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and the predef id is not left in A because no reader is live; evidence=PredefPointers is unported and the flat model needs no bank switch, dataflow shows A dead after this site; lifetime=retired when PredefPointers is ported}
    call HideObject
    mov al, 35
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and the predef id is not left in A because no reader is live; evidence=PredefPointers is unported and the flat model needs no bank switch, dataflow shows A dead after this site; lifetime=retired when PredefPointers is ported}
    call HideObject
    ResetEvents EVENT_1ST_ROUTE22_RIVAL_BATTLE, EVENT_ROUTE22_RIVAL_WANTS_BATTLE
    SetEvent EVENT_BEAT_PEWTER_GYM_TRAINER_0
    jmp PewterGymResetScripts

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] PewterGym_TextPointers (scripts/PewterGym.asm:85-97) — a generated asset already defines PewterGymTrainerHeaders
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	def_text_pointers
; PRET| 	dw_const PewterGymBrockText,             TEXT_PEWTERGYM_BROCK
; PRET| 	dw_const PewterGymCooltrainerMText,      TEXT_PEWTERGYM_COOLTRAINER_M
; PRET| 	dw_const PewterGymGuideText,             TEXT_PEWTERGYM_GYM_GUIDE
; PRET| 	dw_const PewterGymBrockWaitTakeThisText, TEXT_PEWTERGYM_BROCK_WAIT_TAKE_THIS
; PRET| 	dw_const PewterGymReceivedTM34Text,      TEXT_PEWTERGYM_RECEIVED_TM34
; PRET| 	dw_const PewterGymTM34NoRoomText,        TEXT_PEWTERGYM_TM34_NO_ROOM
; PRET| 
; PRET| PewterGymTrainerHeaders:
; PRET| 	def_trainers 2
; PRET| PewterGymTrainerHeader0:
; PRET| 	trainer EVENT_BEAT_PEWTER_GYM_TRAINER_0, 5, PewterGymCooltrainerMBattleText, PewterGymCooltrainerMEndBattleText, PewterGymCooltrainerMAfterBattleText
; PRET| 	db -1 ; end

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] PewterGymBrockText (scripts/PewterGym.asm:101-107) — at scripts/PewterGym.asm:102: .beforeBeat is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEvent EVENT_BEAT_BROCK
; PRET| 	jr z, .beforeBeat
; PRET| 	CheckEventReuseA EVENT_GOT_TM34
; PRET| 	jr nz, .afterBeat
; PRET| 	call z, PewterGymScriptReceiveTM34
; PRET| 	call DisableWaitingAfterTextDisplay
; PRET| 	jr .done

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] PewterGymBrockText.afterBeat (scripts/PewterGym.asm:109-111) — at scripts/PewterGym.asm:109: .PostBattleAdviceText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .PostBattleAdviceText
; PRET| 	call PrintText
; PRET| 	jr .done

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] PewterGymBrockText.beforeBeat (scripts/PewterGym.asm:113-133) — at scripts/PewterGym.asm:113: .PreBattleText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .PreBattleText
; PRET| 	call PrintText
; PRET| 	ld hl, wStatusFlags3
; PRET| 	set BIT_TALKED_TO_TRAINER, [hl]
; PRET| 	set BIT_PRINT_END_BATTLE_TEXT, [hl]
; PRET| 	ld hl, PewterGymBrockReceivedBoulderBadgeText
; PRET| 	ld de, PewterGymBrockReceivedBoulderBadgeText
; PRET| 	call SaveEndBattleTextPointers
; PRET| 	ldh a, [hSpriteIndex]
; PRET| 	ld [wSpriteIndex], a
; PRET| 	call EngageMapTrainer
; PRET| 	call InitBattleEnemyParameters
; PRET| 	ld a, $1
; PRET| 	ld [wGymLeaderNo], a
; PRET| 	xor a
; PRET| 	ldh [hJoyHeld], a
; PRET| 	ld a, SCRIPT_PEWTERGYM_BROCK_POST_BATTLE
; PRET| 	ld [wPewterGymCurScript], a
; PRET| 	ld [wCurMapScript], a
; PRET| .done
; PRET| 	jp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[text-sound-command-unported] PewterGymBrockText.PreBattleText (scripts/PewterGym.asm:136-161) — at scripts/PewterGym.asm:149: sound_get_item_1
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _PewterGymBrockPreBattleText
; PRET| 	text_end
; PRET| 
; PRET| .PostBattleAdviceText:
; PRET| 	text_far _PewterGymBrockPostBattleAdviceText
; PRET| 	text_end
; PRET| 
; PRET| PewterGymBrockWaitTakeThisText:
; PRET| 	text_far _PewterGymBrockWaitTakeThisText
; PRET| 	text_end
; PRET| 
; PRET| PewterGymReceivedTM34Text:
; PRET| 	text_far _PewterGymReceivedTM34Text
; PRET| 	sound_get_item_1
; PRET| 	text_far _TM34ExplanationText
; PRET| 	text_end
; PRET| 
; PRET| PewterGymTM34NoRoomText:
; PRET| 	text_far _PewterGymTM34NoRoomText
; PRET| 	text_end
; PRET| 
; PRET| PewterGymBrockReceivedBoulderBadgeText:
; PRET| 	text_far _PewterGymBrockReceivedBoulderBadgeText
; PRET| 	sound_get_item_1
; PRET| 	text_far _PewterGymBrockBoulderBadgeInfoText ; Text to tell that the flash technique can be used
; PRET| 	text_end

PewterGymCooltrainerMText:
    mov esi, PewterGymTrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] PewterGymCooltrainerMBattleText (scripts/PewterGym.asm:170-179) — a generated asset already defines PewterGymCooltrainerMBattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _PewterGymCooltrainerMBattleText
; PRET| 	text_end
; PRET| 
; PRET| PewterGymCooltrainerMEndBattleText:
; PRET| 	text_far _PewterGymCooltrainerMEndBattleText
; PRET| 	text_end
; PRET| 
; PRET| PewterGymCooltrainerMAfterBattleText:
; PRET| 	text_far _PewterGymCooltrainerMAfterBattleText
; PRET| 	text_end

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] PewterGymGuideText (scripts/PewterGym.asm:183-197) — at scripts/PewterGym.asm:185: .afterBeat is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, [wBeatGymFlags]
; PRET| 	bit BIT_BOULDERBADGE, a
; PRET| 	jr nz, .afterBeat
; PRET| 	ld hl, PewterGymGuidePreAdviceText
; PRET| 	call PrintText
; PRET| 	call YesNoChoice
; PRET| 	ld a, [wCurrentMenuItem]
; PRET| 	and a
; PRET| 	jr nz, .PewterGymGuideBeginAdviceText
; PRET| 	ld a, [wPikachuSpawnStateFlags]
; PRET| 	bit BIT_PIKACHU_SPAWN_STARTER, a
; PRET| 	jp nz, .asm_5c3fa
; PRET| 	ld hl, PewterGymGuideBeginAdviceText
; PRET| 	call PrintText
; PRET| 	jr .PewterGymGuideAdviceText

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] PewterGymGuideText.PewterGymGuideBeginAdviceText (scripts/PewterGym.asm:199-204) — at scripts/PewterGym.asm:204: .done is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, PewterGymGuideFreeServiceText
; PRET| 	call PrintText
; PRET| .PewterGymGuideAdviceText
; PRET| 	ld hl, PewterGymGuideAdviceText
; PRET| 	call PrintText
; PRET| 	jr .done

.afterBeat:
    mov esi, PewterGymGuidePostBattleText
    call PrintText
.done:
    jmp TextScriptEnd

.asm_5c3fa:
    mov esi, PewterGymText_5c41c
    call PrintText
    jmp TextScriptEnd

PewterGymGuidePreAdviceText:
    text_far _PewterGymGuidePreAdviceText
    text_end
PewterGymGuideBeginAdviceText:
    text_far _PewterGymGuideBeginAdviceText
    text_end
PewterGymGuideAdviceText:
    text_far _PewterGymGuideAdviceText
    text_end
PewterGymGuideFreeServiceText:
    text_far _PewterGymGuideFreeServiceText
    text_end
PewterGymGuidePostBattleText:
    text_far _PewterGymGuidePostBattleText
    text_end
PewterGymText_5c41c:
    text_far _PewterGymGuyText
    text_end
