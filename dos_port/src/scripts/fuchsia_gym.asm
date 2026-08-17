; FuchsiaGym.asm — translated from pret scripts/FuchsiaGym.asm by dos_port/tools/sm83xlat.
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

global FuchsiaGymKogaPostBattleScript
global FuchsiaGymReceiveTM06
global FuchsiaGymResetScripts
global FuchsiaGymRocker1Text
global FuchsiaGymRocker2Text
global FuchsiaGymRocker3Text
global FuchsiaGymRocker4Text
global FuchsiaGymRocker5Text
global FuchsiaGymRocker6Text
global FuchsiaGym_ScriptPointers

extern CheckFightingMapTrainers   ; NOT YET DEFINED IN THE PORT
extern DisplayEnemyTrainerTextAndStartBattle   ; NOT YET DEFINED IN THE PORT
extern DisplayTextID   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EndTrainerBattle   ; NOT YET DEFINED IN THE PORT
extern EngageMapTrainer   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern FuchsiaGymGymGuideText   ; NOT YET DEFINED IN THE PORT
extern FuchsiaGymKogaReceivedTM06Text   ; NOT YET DEFINED IN THE PORT
extern FuchsiaGymKogaSoulBadgeInfoText   ; NOT YET DEFINED IN THE PORT
extern FuchsiaGymKogaTM06NoRoomText   ; NOT YET DEFINED IN THE PORT
extern FuchsiaGymKogaText   ; NOT YET DEFINED IN THE PORT
extern FuchsiaGymRocker1BattleText   ; NOT YET DEFINED IN THE PORT
extern FuchsiaGymRocker2BattleText   ; NOT YET DEFINED IN THE PORT
extern FuchsiaGymRocker3BattleText   ; NOT YET DEFINED IN THE PORT
extern FuchsiaGymRocker4BattleText   ; NOT YET DEFINED IN THE PORT
extern FuchsiaGymRocker5BattleText   ; NOT YET DEFINED IN THE PORT
extern FuchsiaGymRocker6BattleText   ; NOT YET DEFINED IN THE PORT
extern FuchsiaGymTrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern FuchsiaGymTrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern FuchsiaGymTrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern FuchsiaGymTrainerHeader3   ; NOT YET DEFINED IN THE PORT
extern FuchsiaGymTrainerHeader4   ; NOT YET DEFINED IN THE PORT
extern FuchsiaGymTrainerHeader5   ; NOT YET DEFINED IN THE PORT
extern FuchsiaGymTrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern FuchsiaGym_Script   ; NOT YET DEFINED IN THE PORT
extern FuchsiaGym_TextPointers   ; NOT YET DEFINED IN THE PORT
extern GiveItem   ; NOT YET DEFINED IN THE PORT
extern InitBattleEnemyParameters   ; NOT YET DEFINED IN THE PORT
extern LoadGymLeaderAndCityName   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern SaveEndBattleTextPointers   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern _FuchsiaGymGymGuideBeatKogaText   ; NOT YET DEFINED IN THE PORT
extern _FuchsiaGymGymGuideChampInMakingText   ; NOT YET DEFINED IN THE PORT
extern _FuchsiaGymKogaBeforeBattleText   ; NOT YET DEFINED IN THE PORT
extern _FuchsiaGymKogaPostBattleAdviceText   ; NOT YET DEFINED IN THE PORT
extern _FuchsiaGymKogaReceivedSoulBadgeText   ; NOT YET DEFINED IN THE PORT
extern _FuchsiaGymKogaReceivedTM06Text   ; NOT YET DEFINED IN THE PORT
extern _FuchsiaGymKogaSoulBadgeInfoText   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_FUCHSIAGYM_KOGA_POST_BATTLE             equ 3
TEXT_FUCHSIAGYM_KOGA_SOUL_BADGE_INFO           equ 9
TEXT_FUCHSIAGYM_KOGA_RECEIVED_TM06             equ 10
TEXT_FUCHSIAGYM_KOGA_TM06_NO_ROOM              equ 11

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wBeatGymFlags                                  equ 0xD729
wFuchsiaGymCurScript                           equ 0xD65A

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] FuchsiaGym_Script (scripts/FuchsiaGym.asm:2-9) — at scripts/FuchsiaGym.asm:2: .LoadNames is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	call .LoadNames
; PRET| 	call EnableAutoTextBoxDrawing
; PRET| 	ld hl, FuchsiaGymTrainerHeaders
; PRET| 	ld de, FuchsiaGym_ScriptPointers
; PRET| 	ld a, [wFuchsiaGymCurScript]
; PRET| 	call ExecuteCurMapScriptInTable
; PRET| 	ld [wFuchsiaGymCurScript], a
; PRET| 	ret

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] FuchsiaGym_Script.LoadNames (scripts/FuchsiaGym.asm:12-19) — at scripts/FuchsiaGym.asm:16: .CityName is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, wCurrentMapScriptFlags
; PRET| 	bit BIT_CUR_MAP_LOADED_2, [hl]
; PRET| 	res BIT_CUR_MAP_LOADED_2, [hl]
; PRET| 	ret z
; PRET| 	ld hl, .CityName
; PRET| 	ld de, .LeaderName
; PRET| 	call LoadGymLeaderAndCityName
; PRET| 	ret

; ---------------------------------------------------------------------------
; BAIL[inline-text-db] FuchsiaGym_Script.CityName (scripts/FuchsiaGym.asm:22-25) — at scripts/FuchsiaGym.asm:22: db "FUCHSIA CITY@"
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	db "FUCHSIA CITY@"
; PRET| 
; PRET| .LeaderName:
; PRET| 	db "KOGA@"

%assign event_byte -1
FuchsiaGymResetScripts:
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov [ebp + wFuchsiaGymCurScript], al
    mov [ebp + wCurMapScript], al
    ret

%assign event_byte -1
FuchsiaGym_ScriptPointers:
    dd CheckFightingMapTrainers
    dd DisplayEnemyTrainerTextAndStartBattle
    dd EndTrainerBattle
    dd FuchsiaGymKogaPostBattleScript

%assign event_byte -1
FuchsiaGymKogaPostBattleScript:
    mov al, [ebp + wIsInBattle]
    cmp al, 0xff
    jz FuchsiaGymResetScripts
    mov al, PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
FuchsiaGymReceiveTM06:
    mov al, TEXT_FUCHSIAGYM_KOGA_SOUL_BADGE_INFO
    mov [ebp + hTextID], al
    call DisplayTextID
    pushfd    ; SM83 form writes no flags
        SetEvent EVENT_BEAT_KOGA
    popfd
    mov bx, ((208) << 8) | (1)
    call GiveItem
    jae .BagFull
    mov al, TEXT_FUCHSIAGYM_KOGA_RECEIVED_TM06
    mov [ebp + hTextID], al
    call DisplayTextID
    SetEvent EVENT_GOT_TM06
    jmp .gymVictory

%assign event_byte -1
.BagFull:
    mov al, TEXT_FUCHSIAGYM_KOGA_TM06_NO_ROOM
    mov [ebp + hTextID], al
    call DisplayTextID
.gymVictory:
    mov esi, wObtainedBadges
    or byte [ebp + esi], (1 << (4))
    mov esi, wBeatGymFlags
    or byte [ebp + esi], (1 << (4))
    SetEventRange EVENT_BEAT_FUCHSIA_GYM_TRAINER_0, EVENT_BEAT_FUCHSIA_GYM_TRAINER_5
    jmp FuchsiaGymResetScripts

; FuchsiaGym_TextPointers (scripts/FuchsiaGym.asm:77-104) — not re-emitted: FuchsiaGymTrainerHeaders is already defined in assets/trainer_headers.inc.

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] FuchsiaGymKogaText (scripts/FuchsiaGym.asm:108-114) — at scripts/FuchsiaGym.asm:109: .beforeBeat is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEvent EVENT_BEAT_KOGA
; PRET| 	jr z, .beforeBeat
; PRET| 	CheckEventReuseA EVENT_GOT_TM06
; PRET| 	jr nz, .afterBeat
; PRET| 	call z, FuchsiaGymReceiveTM06
; PRET| 	call DisableWaitingAfterTextDisplay
; PRET| 	jr .done

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] FuchsiaGymKogaText.afterBeat (scripts/FuchsiaGym.asm:116-118) — at scripts/FuchsiaGym.asm:116: .PostBattleAdviceText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .PostBattleAdviceText
; PRET| 	call PrintText
; PRET| 	jr .done

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] FuchsiaGymKogaText.beforeBeat (scripts/FuchsiaGym.asm:120-139) — at scripts/FuchsiaGym.asm:120: .BeforeBattleText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .BeforeBattleText
; PRET| 	call PrintText
; PRET| 	ld hl, wStatusFlags3
; PRET| 	set BIT_TALKED_TO_TRAINER, [hl]
; PRET| 	set BIT_PRINT_END_BATTLE_TEXT, [hl]
; PRET| 	ld hl, .ReceivedSoulBadgeText
; PRET| 	ld de, .ReceivedSoulBadgeText
; PRET| 	call SaveEndBattleTextPointers
; PRET| 	ldh a, [hSpriteIndex]
; PRET| 	ld [wSpriteIndex], a
; PRET| 	call EngageMapTrainer
; PRET| 	call InitBattleEnemyParameters
; PRET| 	ld a, $5
; PRET| 	ld [wGymLeaderNo], a
; PRET| 	xor a
; PRET| 	ldh [hJoyHeld], a
; PRET| 	ld a, SCRIPT_FUCHSIAGYM_KOGA_POST_BATTLE
; PRET| 	ld [wFuchsiaGymCurScript], a
; PRET| .done
; PRET| 	jp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[text-sound-command-unported] FuchsiaGymKogaText.BeforeBattleText (scripts/FuchsiaGym.asm:142-165) — at scripts/FuchsiaGym.asm:159: sound_get_key_item
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _FuchsiaGymKogaBeforeBattleText
; PRET| 	text_end
; PRET| 
; PRET| .ReceivedSoulBadgeText:
; PRET| 	text_far _FuchsiaGymKogaReceivedSoulBadgeText
; PRET| 	text_end
; PRET| 
; PRET| .PostBattleAdviceText:
; PRET| 	text_far _FuchsiaGymKogaPostBattleAdviceText
; PRET| 	text_end
; PRET| 
; PRET| FuchsiaGymKogaSoulBadgeInfoText:
; PRET| 	text_far _FuchsiaGymKogaSoulBadgeInfoText
; PRET| 	text_end
; PRET| 
; PRET| FuchsiaGymKogaReceivedTM06Text:
; PRET| 	text_far _FuchsiaGymKogaReceivedTM06Text
; PRET| 	sound_get_key_item
; PRET| 	text_far _FuchsiaGymKogaTM06ExplanationText
; PRET| 	text_end
; PRET| 
; PRET| FuchsiaGymKogaTM06NoRoomText:
; PRET| 	text_far _FuchsiaGymKogaTM06NoRoomText
; PRET| 	text_end

%assign event_byte -1
FuchsiaGymRocker1Text:
    mov esi, FuchsiaGymTrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; FuchsiaGymRocker1BattleText (scripts/FuchsiaGym.asm:174-183) — not re-emitted: FuchsiaGymRocker1BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
FuchsiaGymRocker2Text:
    mov esi, FuchsiaGymTrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

; FuchsiaGymRocker2BattleText (scripts/FuchsiaGym.asm:192-201) — not re-emitted: FuchsiaGymRocker2BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
FuchsiaGymRocker3Text:
    mov esi, FuchsiaGymTrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

; FuchsiaGymRocker3BattleText (scripts/FuchsiaGym.asm:210-219) — not re-emitted: FuchsiaGymRocker3BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
FuchsiaGymRocker4Text:
    mov esi, FuchsiaGymTrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

; FuchsiaGymRocker4BattleText (scripts/FuchsiaGym.asm:228-237) — not re-emitted: FuchsiaGymRocker4BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
FuchsiaGymRocker5Text:
    mov esi, FuchsiaGymTrainerHeader4
    call TalkToTrainer
    jmp TextScriptEnd

; FuchsiaGymRocker5BattleText (scripts/FuchsiaGym.asm:246-255) — not re-emitted: FuchsiaGymRocker5BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
FuchsiaGymRocker6Text:
    mov esi, FuchsiaGymTrainerHeader5
    call TalkToTrainer
    jmp TextScriptEnd

; FuchsiaGymRocker6BattleText (scripts/FuchsiaGym.asm:264-273) — not re-emitted: FuchsiaGymRocker6BattleText is already defined in assets/trainer_headers.inc.

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] FuchsiaGymGymGuideText (scripts/FuchsiaGym.asm:277-283) — at scripts/FuchsiaGym.asm:279: .afterBeat is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEvent EVENT_BEAT_KOGA
; PRET| 	ld hl, .BeatKogaText
; PRET| 	jr nz, .afterBeat
; PRET| 	ld hl, .ChampInMakingText
; PRET| .afterBeat
; PRET| 	call PrintText
; PRET| 	jp TextScriptEnd

%assign event_byte -1
.ChampInMakingText:
    text_far _FuchsiaGymGymGuideChampInMakingText
    text_end
.BeatKogaText:
    text_far _FuchsiaGymGymGuideBeatKogaText
    text_end
