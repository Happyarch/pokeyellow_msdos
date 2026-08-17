; SilphCo5F.asm — translated from pret scripts/SilphCo5F.asm by dos_port/tools/sm83xlat.
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

global SilphCo5FRockerText
global SilphCo5FRocket1Text
global SilphCo5FRocket2Text
global SilphCo5FScientistText
global SilphCo5F_Script

extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern ReplaceTileBlock   ; NOT YET DEFINED IN THE PORT
extern SilphCo4F_SetCardKeyDoorYScript   ; NOT YET DEFINED IN THE PORT
extern SilphCo5FGateCallbackScript   ; NOT YET DEFINED IN THE PORT
extern SilphCo5FRockerBattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo5FRocket1BattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo5FRocket2BattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo5FScientistBattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo5FSilphWorkerMText   ; NOT YET DEFINED IN THE PORT
extern SilphCo5F_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern SilphCo5F_SetUnlockedSilphCoDoorsScript   ; NOT YET DEFINED IN THE PORT
extern SilphCo5TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern SilphCo5TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern SilphCo5TrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern SilphCo5TrainerHeader3   ; NOT YET DEFINED IN THE PORT
extern SilphCo5TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern SilphCo6FBeatGiovanniPrintDEOrPrintHLScript   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern _SilphCo5FSilphWorkerMThatsYouRightText   ; NOT YET DEFINED IN THE PORT
extern _SilphCo5FSilphWorkerMYoureOurHeroText   ; NOT YET DEFINED IN THE PORT

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
hUnlockedSilphCoDoors                          equ 0xFFE0
wSilphCo5FCurScript                            equ 0xD645

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

SilphCo5F_Script:
    call SilphCo5FGateCallbackScript
    call EnableAutoTextBoxDrawing
    mov esi, SilphCo5TrainerHeaders
    mov edi, SilphCo5F_ScriptPointers   ; pret: ld de, SilphCo5F_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wSilphCo5FCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wSilphCo5FCurScript], al
    ret

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] SilphCo5FGateCallbackScript (scripts/SilphCo5F.asm:12-42) — at scripts/SilphCo5F.asm:20: .unlock_door1 is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, wCurrentMapScriptFlags
; PRET| 	bit BIT_CUR_MAP_LOADED_1, [hl]
; PRET| 	res BIT_CUR_MAP_LOADED_1, [hl]
; PRET| 	ret z
; PRET| 	ld hl, .GateCoordinates
; PRET| 	call SilphCo4F_SetCardKeyDoorYScript
; PRET| 	call SilphCo5F_SetUnlockedSilphCoDoorsScript
; PRET| 	CheckEvent EVENT_SILPH_CO_5_UNLOCKED_DOOR1
; PRET| 	jr nz, .unlock_door1
; PRET| 	push af
; PRET| 	ld a, $5f
; PRET| 	ld [wNewTileBlockID], a
; PRET| 	lb bc, 2, 3
; PRET| 	predef ReplaceTileBlock
; PRET| 	pop af
; PRET| .unlock_door1
; PRET| 	CheckEventAfterBranchReuseA EVENT_SILPH_CO_5_UNLOCKED_DOOR2, EVENT_SILPH_CO_5_UNLOCKED_DOOR1
; PRET| 	jr nz, .unlock_door2
; PRET| 	push af
; PRET| 	ld a, $5f
; PRET| 	ld [wNewTileBlockID], a
; PRET| 	lb bc, 6, 3
; PRET| 	predef ReplaceTileBlock
; PRET| 	pop af
; PRET| .unlock_door2
; PRET| 	CheckEventAfterBranchReuseA EVENT_SILPH_CO_5_UNLOCKED_DOOR3, EVENT_SILPH_CO_5_UNLOCKED_DOOR2
; PRET| 	ret nz
; PRET| 	ld a, $5f
; PRET| 	ld [wNewTileBlockID], a
; PRET| 	lb bc, 5, 7
; PRET| 	predef_jump ReplaceTileBlock

.GateCoordinates:
    db 2, 3
    db 6, 3
    db 5, 7
    db -1

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] SilphCo5F_SetUnlockedSilphCoDoorsScript (scripts/SilphCo5F.asm:51-58) — at scripts/SilphCo5F.asm:56: .unlock_door1 is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	EventFlagAddress hl, EVENT_SILPH_CO_5_UNLOCKED_DOOR1
; PRET| 	ldh a, [hUnlockedSilphCoDoors]
; PRET| 	and a
; PRET| 	ret z
; PRET| 	cp $1
; PRET| 	jr nz, .unlock_door1
; PRET| 	SetEventReuseHL EVENT_SILPH_CO_5_UNLOCKED_DOOR1
; PRET| 	ret

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] SilphCo5F_SetUnlockedSilphCoDoorsScript.unlock_door1 (scripts/SilphCo5F.asm:60-63) — at scripts/SilphCo5F.asm:61: .unlock_door2 is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	cp $2
; PRET| 	jr nz, .unlock_door2
; PRET| 	SetEventAfterBranchReuseHL EVENT_SILPH_CO_5_UNLOCKED_DOOR2, EVENT_SILPH_CO_5_UNLOCKED_DOOR1
; PRET| 	ret

; ---------------------------------------------------------------------------
; BAIL[event-byte-assembly-state] SilphCo5F_SetUnlockedSilphCoDoorsScript.unlock_door2 (scripts/SilphCo5F.asm:65-66) — at scripts/SilphCo5F.asm:65: SetEventAfterBranchReuseHL EVENT_SILPH_CO_5_UNLOCKED_DOOR3, EVENT_SILPH_CO_5_UNLOCKED_DOOR1
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	SetEventAfterBranchReuseHL EVENT_SILPH_CO_5_UNLOCKED_DOOR3, EVENT_SILPH_CO_5_UNLOCKED_DOOR1
; PRET| 	ret

; SilphCo5F_ScriptPointers (scripts/SilphCo5F.asm:69-98) — not re-emitted: SilphCo5TrainerHeaders is already defined in assets/trainer_headers.inc.

; ---------------------------------------------------------------------------
; BAIL[host-pointer-in-16bit-reg] SilphCo5FSilphWorkerMText (scripts/SilphCo5F.asm:102-105) — at scripts/SilphCo5F.asm:103: de cannot hold the 32-bit address of .YoureOurHeroText; callee SilphCo6FBeatGiovanniPrintDEOrPrintHLScript has no abi.json entry
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .ThatsYouRightText
; PRET| 	ld de, .YoureOurHeroText
; PRET| 	call SilphCo6FBeatGiovanniPrintDEOrPrintHLScript
; PRET| 	jp TextScriptEnd

.ThatsYouRightText:
    text_far _SilphCo5FSilphWorkerMThatsYouRightText
    text_end
.YoureOurHeroText:
    text_far _SilphCo5FSilphWorkerMYoureOurHeroText
    text_end

SilphCo5FRocket1Text:
    mov esi, SilphCo5TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; SilphCo5FRocket1BattleText (scripts/SilphCo5F.asm:122-131) — not re-emitted: SilphCo5FRocket1BattleText is already defined in assets/trainer_headers.inc.

SilphCo5FScientistText:
    mov esi, SilphCo5TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

; SilphCo5FScientistBattleText (scripts/SilphCo5F.asm:140-149) — not re-emitted: SilphCo5FScientistBattleText is already defined in assets/trainer_headers.inc.

SilphCo5FRockerText:
    mov esi, SilphCo5TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

; SilphCo5FRockerBattleText (scripts/SilphCo5F.asm:158-167) — not re-emitted: SilphCo5FRockerBattleText is already defined in assets/trainer_headers.inc.

SilphCo5FRocket2Text:
    mov esi, SilphCo5TrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

; SilphCo5FRocket2BattleText (scripts/SilphCo5F.asm:176-197) — not re-emitted: SilphCo5FRocket2BattleText is already defined in assets/trainer_headers.inc.
