; SilphCo3F.asm — translated from pret scripts/SilphCo3F.asm by dos_port/tools/sm83xlat.
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


global SilphCo3FRocketText
global SilphCo3FScientistText
global SilphCo3FSilphWorkerMText
global SilphCo3F_Script

extern CheckFightingMapTrainers   ; NOT YET DEFINED IN THE PORT
extern DisplayEnemyTrainerTextAndStartBattle   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EndTrainerBattle   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern PickUpItemText   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern ReplaceTileBlock   ; NOT YET DEFINED IN THE PORT
extern SilphCo2F_SetCardKeyDoorYScript   ; NOT YET DEFINED IN THE PORT
extern SilphCo3FGateCallbackScript   ; NOT YET DEFINED IN THE PORT
extern SilphCo3FRocketAfterBattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo3FRocketBattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo3FRocketEndBattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo3FScientistAfterBattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo3FScientistBattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo3FScientistEndBattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo3F_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern SilphCo3F_TextPointers   ; NOT YET DEFINED IN THE PORT
extern SilphCo3F_UnlockedDoorEventScript   ; NOT YET DEFINED IN THE PORT
extern SilphCo3TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern SilphCo3TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern SilphCo3TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern _SilphCo3FSilphWorkerMWhatShouldIDoText   ; NOT YET DEFINED IN THE PORT
extern _SilphCo3FSilphWorkerMYouSavedUsText   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_SILPHCO3F_DEFAULT                       equ 0
SCRIPT_SILPHCO3F_START_BATTLE                  equ 1
SCRIPT_SILPHCO3F_END_BATTLE                    equ 2
TEXT_SILPHCO3F_SILPH_WORKER_M                  equ 1
TEXT_SILPHCO3F_ROCKET                          equ 2
TEXT_SILPHCO3F_SCIENTIST                       equ 3
TEXT_SILPHCO3F_HYPER_POTION                    equ 4

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
hUnlockedSilphCoDoors                          equ 0xFFE0
wSilphCo3FCurScript                            equ 0xD643

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

SilphCo3F_Script:
    call SilphCo3FGateCallbackScript
    call EnableAutoTextBoxDrawing
    mov esi, SilphCo3TrainerHeaders
    mov edi, SilphCo3F_ScriptPointers   ; pret: ld de, SilphCo3F_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wSilphCo3FCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wSilphCo3FCurScript], al
    ret

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] SilphCo3FGateCallbackScript (scripts/SilphCo3F.asm:12-33) — at scripts/SilphCo3F.asm:20: .unlock_door1 is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, wCurrentMapScriptFlags
; PRET| 	bit BIT_CUR_MAP_LOADED_1, [hl]
; PRET| 	res BIT_CUR_MAP_LOADED_1, [hl]
; PRET| 	ret z
; PRET| 	ld hl, .GateCoordinates
; PRET| 	call SilphCo2F_SetCardKeyDoorYScript
; PRET| 	call SilphCo3F_UnlockedDoorEventScript
; PRET| 	CheckEvent EVENT_SILPH_CO_3_UNLOCKED_DOOR1
; PRET| 	jr nz, .unlock_door1
; PRET| 	push af
; PRET| 	ld a, $5f
; PRET| 	ld [wNewTileBlockID], a
; PRET| 	lb bc, 4, 4
; PRET| 	predef ReplaceTileBlock
; PRET| 	pop af
; PRET| .unlock_door1
; PRET| 	CheckEventAfterBranchReuseA EVENT_SILPH_CO_3_UNLOCKED_DOOR2, EVENT_SILPH_CO_3_UNLOCKED_DOOR1
; PRET| 	ret nz
; PRET| 	ld a, $5f
; PRET| 	ld [wNewTileBlockID], a
; PRET| 	lb bc, 4, 8
; PRET| 	predef_jump ReplaceTileBlock

.GateCoordinates:
    db 4, 4
    db 4, 8
    db -1

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] SilphCo3F_UnlockedDoorEventScript (scripts/SilphCo3F.asm:41-48) — at scripts/SilphCo3F.asm:46: .unlock_door1 is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	EventFlagAddress hl, EVENT_SILPH_CO_3_UNLOCKED_DOOR1
; PRET| 	ldh a, [hUnlockedSilphCoDoors]
; PRET| 	and a
; PRET| 	ret z
; PRET| 	cp $1
; PRET| 	jr nz, .unlock_door1
; PRET| 	SetEventReuseHL EVENT_SILPH_CO_3_UNLOCKED_DOOR1
; PRET| 	ret

; ---------------------------------------------------------------------------
; BAIL[event-byte-assembly-state] SilphCo3F_UnlockedDoorEventScript.unlock_door1 (scripts/SilphCo3F.asm:50-51) — at scripts/SilphCo3F.asm:50: SetEventAfterBranchReuseHL EVENT_SILPH_CO_3_UNLOCKED_DOOR2, EVENT_SILPH_CO_3_UNLOCKED_DOOR1
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	SetEventAfterBranchReuseHL EVENT_SILPH_CO_3_UNLOCKED_DOOR2, EVENT_SILPH_CO_3_UNLOCKED_DOOR1
; PRET| 	ret

; ---------------------------------------------------------------------------
; SilphCo3F_ScriptPointers (scripts/SilphCo3F.asm:54-72) — Tier-1 data: SilphCo3TrainerHeaders is generated into assets/trainer_headers.inc.

SilphCo3FSilphWorkerMText:
    CheckEvent EVENT_BEAT_SILPH_CO_GIOVANNI
    mov esi, .YouSavedUsText
    jnz .beat_giovanni
    mov esi, .WhatShouldIDoText
.beat_giovanni:
    call PrintText
    jmp TextScriptEnd

.WhatShouldIDoText:
    text_far _SilphCo3FSilphWorkerMWhatShouldIDoText
    text_end
.YouSavedUsText:
    text_far _SilphCo3FSilphWorkerMYouSavedUsText
    text_end

SilphCo3FRocketText:
    mov esi, SilphCo3TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; SilphCo3FRocketBattleText (scripts/SilphCo3F.asm:99-108) — Tier-1 data: SilphCo3FRocketBattleText is generated into assets/trainer_headers.inc.

SilphCo3FScientistText:
    mov esi, SilphCo3TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; SilphCo3FScientistBattleText (scripts/SilphCo3F.asm:117-126) — Tier-1 data: SilphCo3FScientistBattleText is generated into assets/trainer_headers.inc.
