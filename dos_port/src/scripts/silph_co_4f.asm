; SilphCo4F.asm — translated from pret scripts/SilphCo4F.asm by dos_port/tools/sm83xlat.
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

global SilphCo4FRocket1Text
global SilphCo4FRocket2Text
global SilphCo4FScientistText
global SilphCo4F_Script

extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern ReplaceTileBlock   ; NOT YET DEFINED IN THE PORT
extern SilphCo4FGateCallbackScript   ; NOT YET DEFINED IN THE PORT
extern SilphCo4FRocket1BattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo4FRocket2BattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo4FScientistBattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo4FSilphWorkerMText   ; NOT YET DEFINED IN THE PORT
extern SilphCo4FUnlockedDoorEventScript   ; NOT YET DEFINED IN THE PORT
extern SilphCo4F_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern SilphCo4F_SetCardKeyDoorYScript   ; NOT YET DEFINED IN THE PORT
extern SilphCo4TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern SilphCo4TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern SilphCo4TrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern SilphCo4TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern SilphCo6FBeatGiovanniPrintDEOrPrintHLScript   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern _SilphCo4FSilphWorkerMImHidingText   ; NOT YET DEFINED IN THE PORT
extern _SilphCo4FSilphWorkerMTeamRocketIsGoneText   ; NOT YET DEFINED IN THE PORT

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
hUnlockedSilphCoDoors                          equ 0xFFE0
wSilphCo4FCurScript                            equ 0xD644

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

SilphCo4F_Script:
    call SilphCo4FGateCallbackScript
    call EnableAutoTextBoxDrawing
    mov esi, SilphCo4TrainerHeaders
    mov edi, SilphCo4F_ScriptPointers   ; pret: ld de, SilphCo4F_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wSilphCo4FCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wSilphCo4FCurScript], al
    ret

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] SilphCo4FGateCallbackScript (scripts/SilphCo4F.asm:12-33) — at scripts/SilphCo4F.asm:20: .unlock_door1 is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, wCurrentMapScriptFlags
; PRET| 	bit BIT_CUR_MAP_LOADED_1, [hl]
; PRET| 	res BIT_CUR_MAP_LOADED_1, [hl]
; PRET| 	ret z
; PRET| 	ld hl, .GateCoordinates
; PRET| 	call SilphCo4F_SetCardKeyDoorYScript
; PRET| 	call SilphCo4FUnlockedDoorEventScript
; PRET| 	CheckEvent EVENT_SILPH_CO_4_UNLOCKED_DOOR1
; PRET| 	jr nz, .unlock_door1
; PRET| 	push af
; PRET| 	ld a, $54
; PRET| 	ld [wNewTileBlockID], a
; PRET| 	lb bc, 6, 2
; PRET| 	predef ReplaceTileBlock
; PRET| 	pop af
; PRET| .unlock_door1
; PRET| 	CheckEventAfterBranchReuseA EVENT_SILPH_CO_4_UNLOCKED_DOOR2, EVENT_SILPH_CO_4_UNLOCKED_DOOR1
; PRET| 	ret nz
; PRET| 	ld a, $54
; PRET| 	ld [wNewTileBlockID], a
; PRET| 	lb bc, 4, 6
; PRET| 	predef_jump ReplaceTileBlock

.GateCoordinates:
    db 6, 2
    db 4, 6
    db -1

; ---------------------------------------------------------------------------
; BAIL[pointer-domain-unknown] SilphCo4F_SetCardKeyDoorYScript (scripts/SilphCo4F.asm:41-61) — at scripts/SilphCo4F.asm:51: HL domain is top at a dereference
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
; PRET| .loop_check_doors
; PRET| 	ld a, [hli]
; PRET| 	cp $ff
; PRET| 	jr z, .exit_loop
; PRET| 	push hl
; PRET| 	ld hl, hUnlockedSilphCoDoors
; PRET| 	inc [hl]
; PRET| 	pop hl
; PRET| 	cp b
; PRET| 	jr z, .check_y_coord
; PRET| 	inc hl
; PRET| 	jr .loop_check_doors

; ---------------------------------------------------------------------------
; BAIL[pointer-domain-unknown] SilphCo4F_SetCardKeyDoorYScript.check_y_coord (scripts/SilphCo4F.asm:63-70) — at scripts/SilphCo4F.asm:63: HL domain is top at a dereference
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, [hli]
; PRET| 	cp c
; PRET| 	jr nz, .loop_check_doors
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
; BAIL[target-region-bailed] SilphCo4FUnlockedDoorEventScript (scripts/SilphCo4F.asm:77-84) — at scripts/SilphCo4F.asm:82: .unlock_door1 is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	EventFlagAddress hl, EVENT_SILPH_CO_4_UNLOCKED_DOOR1
; PRET| 	ldh a, [hUnlockedSilphCoDoors]
; PRET| 	and a
; PRET| 	ret z
; PRET| 	cp $1
; PRET| 	jr nz, .unlock_door1
; PRET| 	SetEventReuseHL EVENT_SILPH_CO_4_UNLOCKED_DOOR1
; PRET| 	ret

; ---------------------------------------------------------------------------
; BAIL[event-byte-assembly-state] SilphCo4FUnlockedDoorEventScript.unlock_door1 (scripts/SilphCo4F.asm:86-87) — at scripts/SilphCo4F.asm:86: SetEventAfterBranchReuseHL EVENT_SILPH_CO_4_UNLOCKED_DOOR2, EVENT_SILPH_CO_4_UNLOCKED_DOOR1
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	SetEventAfterBranchReuseHL EVENT_SILPH_CO_4_UNLOCKED_DOOR2, EVENT_SILPH_CO_4_UNLOCKED_DOOR1
; PRET| 	ret

; SilphCo4F_ScriptPointers (scripts/SilphCo4F.asm:90-113) — not re-emitted: SilphCo4TrainerHeaders is already defined in assets/trainer_headers.inc.

; ---------------------------------------------------------------------------
; BAIL[host-pointer-in-16bit-reg] SilphCo4FSilphWorkerMText (scripts/SilphCo4F.asm:117-120) — at scripts/SilphCo4F.asm:118: de cannot hold the 32-bit address of .TeamRocketIsGoneText; callee SilphCo6FBeatGiovanniPrintDEOrPrintHLScript has no abi.json entry
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .ImHidingText
; PRET| 	ld de, .TeamRocketIsGoneText
; PRET| 	call SilphCo6FBeatGiovanniPrintDEOrPrintHLScript
; PRET| 	jp TextScriptEnd

.ImHidingText:
    text_far _SilphCo4FSilphWorkerMImHidingText
    text_end
.TeamRocketIsGoneText:
    text_far _SilphCo4FSilphWorkerMTeamRocketIsGoneText
    text_end

SilphCo4FRocket1Text:
    mov esi, SilphCo4TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; SilphCo4FRocket1BattleText (scripts/SilphCo4F.asm:137-146) — not re-emitted: SilphCo4FRocket1BattleText is already defined in assets/trainer_headers.inc.

SilphCo4FScientistText:
    mov esi, SilphCo4TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

; SilphCo4FScientistBattleText (scripts/SilphCo4F.asm:155-164) — not re-emitted: SilphCo4FScientistBattleText is already defined in assets/trainer_headers.inc.

SilphCo4FRocket2Text:
    mov esi, SilphCo4TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

; SilphCo4FRocket2BattleText (scripts/SilphCo4F.asm:173-182) — not re-emitted: SilphCo4FRocket2BattleText is already defined in assets/trainer_headers.inc.
