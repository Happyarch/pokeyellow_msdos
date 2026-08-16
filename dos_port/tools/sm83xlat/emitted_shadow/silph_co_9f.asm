; SilphCo9F.asm — translated from pret scripts/SilphCo9F.asm by dos_port/tools/sm83xlat.
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


global SilphCo9FRocket1Text
global SilphCo9FRocket2Text
global SilphCo9FScientistText
global SilphCo9F_Script

extern CheckFightingMapTrainers   ; NOT YET DEFINED IN THE PORT
extern Delay3   ; NOT YET DEFINED IN THE PORT
extern DisplayEnemyTrainerTextAndStartBattle   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EndTrainerBattle   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern GBFadeInFromWhite   ; NOT YET DEFINED IN THE PORT
extern GBFadeOutToWhite   ; NOT YET DEFINED IN THE PORT
extern HealParty   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern ReplaceTileBlock   ; NOT YET DEFINED IN THE PORT
extern SilphCo9FGateCallbackScript   ; NOT YET DEFINED IN THE PORT
extern SilphCo9FNurseDontGiveUpText   ; NOT YET DEFINED IN THE PORT
extern SilphCo9FNurseText   ; NOT YET DEFINED IN THE PORT
extern SilphCo9FNurseThankYouText   ; NOT YET DEFINED IN THE PORT
extern SilphCo9FNurseYouLookTiredText   ; NOT YET DEFINED IN THE PORT
extern SilphCo9FRocket1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo9FRocket1BattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo9FRocket1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo9FRocket2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo9FRocket2BattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo9FRocket2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo9FScientistAfterBattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo9FScientistBattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo9FScientistEndBattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo9F_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern SilphCo9F_SetCardKeyDoorYScript   ; NOT YET DEFINED IN THE PORT
extern SilphCo9F_SetUnlockedSilphCoDoorsScript   ; NOT YET DEFINED IN THE PORT
extern SilphCo9F_TextPointers   ; NOT YET DEFINED IN THE PORT
extern SilphCo9TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern SilphCo9TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern SilphCo9TrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern SilphCo9TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_SILPHCO9F_DEFAULT                       equ 0
SCRIPT_SILPHCO9F_START_BATTLE                  equ 1
SCRIPT_SILPHCO9F_END_BATTLE                    equ 2
TEXT_SILPHCO9F_NURSE                           equ 1
TEXT_SILPHCO9F_ROCKET1                         equ 2
TEXT_SILPHCO9F_SCIENTIST                       equ 3
TEXT_SILPHCO9F_ROCKET2                         equ 4

; pret RAM names the port still spells in SCREAMING_SNAKE. Guarded, so
; this file assembles both before and after the memmap rename lands.
%ifndef wCurrentMapScriptFlags
wCurrentMapScriptFlags                         equ W_CURRENT_MAP_SCRIPT_FLAGS
%endif
%ifndef wNewTileBlockID
wNewTileBlockID                                equ W_NEW_TILE_BLOCK_ID
%endif

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
hUnlockedSilphCoDoors                          equ 0xFFE0
wSilphCo9FCurScript                            equ 0xD649

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

SilphCo9F_Script:
    call SilphCo9FGateCallbackScript
    call EnableAutoTextBoxDrawing
    mov esi, SilphCo9TrainerHeaders
    mov edi, SilphCo9F_ScriptPointers   ; pret: ld de, SilphCo9F_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wSilphCo9FCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wSilphCo9FCurScript], al
    ret

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] SilphCo9FGateCallbackScript (scripts/SilphCo9F.asm:12-51) — at scripts/SilphCo9F.asm:20: .unlock_door1 is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, wCurrentMapScriptFlags
; PRET| 	bit BIT_CUR_MAP_LOADED_1, [hl]
; PRET| 	res BIT_CUR_MAP_LOADED_1, [hl]
; PRET| 	ret z
; PRET| 	ld hl, .GateCoordinates
; PRET| 	call SilphCo9F_SetCardKeyDoorYScript
; PRET| 	call SilphCo9F_SetUnlockedSilphCoDoorsScript
; PRET| 	CheckEvent EVENT_SILPH_CO_9_UNLOCKED_DOOR1
; PRET| 	jr nz, .unlock_door1
; PRET| 	push af
; PRET| 	ld a, $5f
; PRET| 	ld [wNewTileBlockID], a
; PRET| 	lb bc, 4, 1
; PRET| 	predef ReplaceTileBlock
; PRET| 	pop af
; PRET| .unlock_door1
; PRET| 	CheckEventAfterBranchReuseA EVENT_SILPH_CO_9_UNLOCKED_DOOR2, EVENT_SILPH_CO_9_UNLOCKED_DOOR1
; PRET| 	jr nz, .unlock_door2
; PRET| 	push af
; PRET| 	ld a, $54
; PRET| 	ld [wNewTileBlockID], a
; PRET| 	lb bc, 2, 9
; PRET| 	predef ReplaceTileBlock
; PRET| 	pop af
; PRET| .unlock_door2
; PRET| 	CheckEventAfterBranchReuseA EVENT_SILPH_CO_9_UNLOCKED_DOOR3, EVENT_SILPH_CO_9_UNLOCKED_DOOR2
; PRET| 	jr nz, .unlock_door3
; PRET| 	push af
; PRET| 	ld a, $54
; PRET| 	ld [wNewTileBlockID], a
; PRET| 	lb bc, 5, 9
; PRET| 	predef ReplaceTileBlock
; PRET| 	pop af
; PRET| .unlock_door3
; PRET| 	CheckEventAfterBranchReuseA EVENT_SILPH_CO_9_UNLOCKED_DOOR4, EVENT_SILPH_CO_9_UNLOCKED_DOOR3
; PRET| 	ret nz
; PRET| 	ld a, $5f
; PRET| 	ld [wNewTileBlockID], a
; PRET| 	lb bc, 6, 5
; PRET| 	predef_jump ReplaceTileBlock

.GateCoordinates:
    db 4, 1
    db 2, 9
    db 5, 9
    db 6, 5
    db -1

; ---------------------------------------------------------------------------
; BAIL[pointer-domain-unknown] SilphCo9F_SetCardKeyDoorYScript (scripts/SilphCo9F.asm:61-81) — at scripts/SilphCo9F.asm:71: HL domain is top at a dereference
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	push hl
; PRET| 	ld hl, wCardKeyDoorY
; PRET| 	ld a, [hli]
; PRET| 	ld b, a
; PRET| 	ld a, [hl]
; PRET| 	ld c, a
; PRET| 	xor a
; PRET| 	ldh [hUnlockedSilphCoDoors], a
; PRET| 	pop hl
; PRET| .loop_card_key_doors
; PRET| 	ld a, [hli]
; PRET| 	cp $ff
; PRET| 	jr z, .exit_loop
; PRET| 	push hl
; PRET| 	ld hl, hUnlockedSilphCoDoors
; PRET| 	inc [hl]
; PRET| 	pop hl
; PRET| 	cp b
; PRET| 	jr z, .check_door
; PRET| 	inc hl
; PRET| 	jr .loop_card_key_doors

; ---------------------------------------------------------------------------
; BAIL[pointer-domain-unknown] SilphCo9F_SetCardKeyDoorYScript.check_door (scripts/SilphCo9F.asm:83-90) — at scripts/SilphCo9F.asm:83: HL domain is top at a dereference
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, [hli]
; PRET| 	cp c
; PRET| 	jr nz, .loop_card_key_doors
; PRET| 	ld hl, wCardKeyDoorY
; PRET| 	xor a
; PRET| 	ld [hli], a
; PRET| 	ld [hl], a
; PRET| 	ret

.exit_loop:
    xor al, al
    mov [ebp + hUnlockedSilphCoDoors], al
    ret

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] SilphCo9F_SetUnlockedSilphCoDoorsScript (scripts/SilphCo9F.asm:97-104) — at scripts/SilphCo9F.asm:102: .unlock_door1 is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	EventFlagAddress hl, EVENT_SILPH_CO_9_UNLOCKED_DOOR1
; PRET| 	ldh a, [hUnlockedSilphCoDoors]
; PRET| 	and a
; PRET| 	ret z
; PRET| 	cp $1
; PRET| 	jr nz, .unlock_door1
; PRET| 	SetEventReuseHL EVENT_SILPH_CO_9_UNLOCKED_DOOR1
; PRET| 	ret

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] SilphCo9F_SetUnlockedSilphCoDoorsScript.unlock_door1 (scripts/SilphCo9F.asm:106-109) — at scripts/SilphCo9F.asm:107: .unlock_door2 is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	cp $2
; PRET| 	jr nz, .unlock_door2
; PRET| 	SetEventAfterBranchReuseHL EVENT_SILPH_CO_9_UNLOCKED_DOOR2, EVENT_SILPH_CO_9_UNLOCKED_DOOR1
; PRET| 	ret

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] SilphCo9F_SetUnlockedSilphCoDoorsScript.unlock_door2 (scripts/SilphCo9F.asm:111-114) — at scripts/SilphCo9F.asm:112: .unlock_door3 is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	cp $3
; PRET| 	jr nz, .unlock_door3
; PRET| 	SetEventAfterBranchReuseHL EVENT_SILPH_CO_9_UNLOCKED_DOOR3, EVENT_SILPH_CO_9_UNLOCKED_DOOR1
; PRET| 	ret

; ---------------------------------------------------------------------------
; BAIL[event-byte-assembly-state] SilphCo9F_SetUnlockedSilphCoDoorsScript.unlock_door3 (scripts/SilphCo9F.asm:116-119) — at scripts/SilphCo9F.asm:118: SetEventAfterBranchReuseHL EVENT_SILPH_CO_9_UNLOCKED_DOOR4, EVENT_SILPH_CO_9_UNLOCKED_DOOR1
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	cp $4
; PRET| 	ret nz
; PRET| 	SetEventAfterBranchReuseHL EVENT_SILPH_CO_9_UNLOCKED_DOOR4, EVENT_SILPH_CO_9_UNLOCKED_DOOR1
; PRET| 	ret

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] SilphCo9F_ScriptPointers (scripts/SilphCo9F.asm:122-142) — a generated asset already defines SilphCo9TrainerHeaders
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	def_script_pointers
; PRET| 	dw_const CheckFightingMapTrainers,              SCRIPT_SILPHCO9F_DEFAULT
; PRET| 	dw_const DisplayEnemyTrainerTextAndStartBattle, SCRIPT_SILPHCO9F_START_BATTLE
; PRET| 	dw_const EndTrainerBattle,                      SCRIPT_SILPHCO9F_END_BATTLE
; PRET| 
; PRET| SilphCo9F_TextPointers:
; PRET| 	def_text_pointers
; PRET| 	dw_const SilphCo9FNurseText,     TEXT_SILPHCO9F_NURSE
; PRET| 	dw_const SilphCo9FRocket1Text,   TEXT_SILPHCO9F_ROCKET1
; PRET| 	dw_const SilphCo9FScientistText, TEXT_SILPHCO9F_SCIENTIST
; PRET| 	dw_const SilphCo9FRocket2Text,   TEXT_SILPHCO9F_ROCKET2
; PRET| 
; PRET| SilphCo9TrainerHeaders:
; PRET| 	def_trainers 2
; PRET| SilphCo9TrainerHeader0:
; PRET| 	trainer EVENT_BEAT_SILPH_CO_9F_TRAINER_0, 4, SilphCo9FRocket1BattleText, SilphCo9FRocket1EndBattleText, SilphCo9FRocket1AfterBattleText
; PRET| SilphCo9TrainerHeader1:
; PRET| 	trainer EVENT_BEAT_SILPH_CO_9F_TRAINER_1, 2, SilphCo9FScientistBattleText, SilphCo9FScientistEndBattleText, SilphCo9FScientistAfterBattleText
; PRET| SilphCo9TrainerHeader2:
; PRET| 	trainer EVENT_BEAT_SILPH_CO_9F_TRAINER_2, 4, SilphCo9FRocket2BattleText, SilphCo9FRocket2EndBattleText, SilphCo9FRocket2AfterBattleText
; PRET| 	db -1 ; end

; ---------------------------------------------------------------------------
; BAIL[predef-leaves-id-in-a] SilphCo9FNurseText (scripts/SilphCo9F.asm:146-156) — at scripts/SilphCo9F.asm:150: predef HealParty
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEvent EVENT_BEAT_SILPH_CO_GIOVANNI
; PRET| 	jr nz, .beat_giovanni
; PRET| 	ld hl, .YouLookTiredText
; PRET| 	call PrintText
; PRET| 	predef HealParty
; PRET| 	call GBFadeOutToWhite
; PRET| 	call Delay3
; PRET| 	call GBFadeInFromWhite
; PRET| 	ld hl, .DontGiveUpText
; PRET| 	call PrintText
; PRET| 	jr .text_script_end

.beat_giovanni:
    mov esi, .ThankYouText
    call PrintText
.text_script_end:
    jmp TextScriptEnd

.YouLookTiredText:
    text_far SilphCo9FNurseYouLookTiredText
    text_end
.DontGiveUpText:
    text_far SilphCo9FNurseDontGiveUpText
    text_end
.ThankYouText:
    text_far SilphCo9FNurseThankYouText
    text_end

SilphCo9FRocket1Text:
    mov esi, SilphCo9TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

SilphCo9FScientistText:
    mov esi, SilphCo9TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

SilphCo9FRocket2Text:
    mov esi, SilphCo9TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] SilphCo9FRocket1BattleText (scripts/SilphCo9F.asm:194-227) — a generated asset already defines SilphCo9FRocket1BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _SilphCo9FRocket1BattleText
; PRET| 	text_end
; PRET| 
; PRET| SilphCo9FRocket1EndBattleText:
; PRET| 	text_far _SilphCo9FRocket1EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| SilphCo9FRocket1AfterBattleText:
; PRET| 	text_far _SilphCo9FRocket1AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| SilphCo9FScientistBattleText:
; PRET| 	text_far _SilphCo9FScientistBattleText
; PRET| 	text_end
; PRET| 
; PRET| SilphCo9FScientistEndBattleText:
; PRET| 	text_far _SilphCo9FScientistEndBattleText
; PRET| 	text_end
; PRET| 
; PRET| SilphCo9FScientistAfterBattleText:
; PRET| 	text_far _SilphCo9FScientistAfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| SilphCo9FRocket2BattleText:
; PRET| 	text_far _SilphCo9FRocket2BattleText
; PRET| 	text_end
; PRET| 
; PRET| SilphCo9FRocket2EndBattleText:
; PRET| 	text_far _SilphCo9FRocket2EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| SilphCo9FRocket2AfterBattleText:
; PRET| 	text_far _SilphCo9FRocket2AfterBattleText
; PRET| 	text_end
