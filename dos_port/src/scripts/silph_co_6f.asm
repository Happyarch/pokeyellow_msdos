; SilphCo6F.asm — translated from pret scripts/SilphCo6F.asm by dos_port/tools/sm83xlat.
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


global SilphCo6FRocket1Text
global SilphCo6FRocket2Text
global SilphCo6FScientistText
global SilphCo6F_GateCallbackScript
global SilphCo6F_Script
global SilphCo6F_UnlockedDoorEventScript

extern CheckFightingMapTrainers   ; NOT YET DEFINED IN THE PORT
extern DisplayEnemyTrainerTextAndStartBattle   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EndTrainerBattle   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern PickUpItemText   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern ReplaceTileBlock   ; NOT YET DEFINED IN THE PORT
extern SilphCo4F_SetCardKeyDoorYScript   ; NOT YET DEFINED IN THE PORT
extern SilphCo6FBeatGiovanniPrintDEOrPrintHLScript   ; NOT YET DEFINED IN THE PORT
extern SilphCo6FRocket1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo6FRocket1BattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo6FRocket1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo6FRocket2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo6FRocket2BattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo6FRocket2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo6FScientistAfterBattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo6FScientistBattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo6FScientistEndBattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo6FSilphWorkerF1Text   ; NOT YET DEFINED IN THE PORT
extern SilphCo6FSilphWorkerF2Text   ; NOT YET DEFINED IN THE PORT
extern SilphCo6FSilphWorkerM1Text   ; NOT YET DEFINED IN THE PORT
extern SilphCo6FSilphWorkerM2Text   ; NOT YET DEFINED IN THE PORT
extern SilphCo6FSilphWorkerM3Text   ; NOT YET DEFINED IN THE PORT
extern SilphCo6F_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern SilphCo6F_TextPointers   ; NOT YET DEFINED IN THE PORT
extern SilphCo6TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern SilphCo6TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern SilphCo6TrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern SilphCo6TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern _SilphCo6FSilphWorkerF1HaveToMarryHimText   ; NOT YET DEFINED IN THE PORT
extern _SilphCo6FSilphWorkerF1SuchACowardText   ; NOT YET DEFINED IN THE PORT
extern _SilphCo6FSilphWorkerF2TeamRocketConquerWorldText   ; NOT YET DEFINED IN THE PORT
extern _SilphCo6FSilphWorkerF2TeamRocketRanText   ; NOT YET DEFINED IN THE PORT
extern _SilphCo6FSilphWorkerM1BackToWorkText   ; NOT YET DEFINED IN THE PORT
extern _SilphCo6FSilphWorkerM1TookOverTheBuildingText   ; NOT YET DEFINED IN THE PORT
extern _SilphCo6FSilphWorkerM3TargetedSilphText   ; NOT YET DEFINED IN THE PORT
extern _SilphCo6FSilphWorkerM3WorkForSilphText   ; NOT YET DEFINED IN THE PORT
extern _SilphCo6FSilphWorkerMHelpMePleaseText   ; NOT YET DEFINED IN THE PORT
extern _SilphCo6FSilphWorkerMWeGotEngagedText   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_SILPHCO6F_DEFAULT                       equ 0
SCRIPT_SILPHCO6F_START_BATTLE                  equ 1
SCRIPT_SILPHCO6F_END_BATTLE                    equ 2
TEXT_SILPHCO6F_SILPH_WORKER_M1                 equ 1
TEXT_SILPHCO6F_SILPH_WORKER_M2                 equ 2
TEXT_SILPHCO6F_SILPH_WORKER_F1                 equ 3
TEXT_SILPHCO6F_SILPH_WORKER_F2                 equ 4
TEXT_SILPHCO6F_SILPH_WORKER_M3                 equ 5
TEXT_SILPHCO6F_ROCKET1                         equ 6
TEXT_SILPHCO6F_SCIENTIST                       equ 7
TEXT_SILPHCO6F_ROCKET2                         equ 8
TEXT_SILPHCO6F_HP_UP                           equ 9
TEXT_SILPHCO6F_X_ACCURACY                      equ 10

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
hUnlockedSilphCoDoors                          equ 0xFFE0
wSilphCo6FCurScript                            equ 0xD646

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

SilphCo6F_Script:
    call SilphCo6F_GateCallbackScript
    call EnableAutoTextBoxDrawing
    mov esi, SilphCo6TrainerHeaders
    mov edi, SilphCo6F_ScriptPointers   ; pret: ld de, SilphCo6F_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wSilphCo6FCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wSilphCo6FCurScript], al
    ret

SilphCo6F_GateCallbackScript:
    mov esi, wCurrentMapScriptFlags
    test byte [ebp + esi], (1 << (BIT_CUR_MAP_LOADED_1))
    pushfd    ; SM83 form writes no flags
        and byte [ebp + esi], ~(1 << (BIT_CUR_MAP_LOADED_1)) & 0xFF
    popfd
    jnz .nr_15
        ret
.nr_15:
    mov esi, .GateCoordinates
    call SilphCo4F_SetCardKeyDoorYScript
    call SilphCo6F_UnlockedDoorEventScript
    CheckEvent EVENT_SILPH_CO_6_UNLOCKED_DOOR
    jz .nr_20
        ret
.nr_20:
    mov al, 0x5f
    mov [ebp + wNewTileBlockID], al
    mov bx, ((6) << 8) | (2)
; DEVIATION{class=banking; pret=macros/predef.asm:predef_jump; behavior=Predef dispatch replaced by a direct jmp, and the predef id is not left in A because no reader is live; evidence=PredefPointers is unported and the flat model needs no bank switch, dataflow shows A dead after this site; lifetime=retired when PredefPointers is ported}
    jmp ReplaceTileBlock

.GateCoordinates:
    db 6, 2
    db -1

SilphCo6F_UnlockedDoorEventScript:
    mov al, [ebp + hUnlockedSilphCoDoors]
    test al, al
    jnz .nr_33
        ret
.nr_33:
    SetEvent EVENT_SILPH_CO_6_UNLOCKED_DOOR
    ret

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] SilphCo6F_ScriptPointers (scripts/SilphCo6F.asm:38-64) — a generated asset already defines SilphCo6TrainerHeaders
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	def_script_pointers
; PRET| 	dw_const CheckFightingMapTrainers,              SCRIPT_SILPHCO6F_DEFAULT
; PRET| 	dw_const DisplayEnemyTrainerTextAndStartBattle, SCRIPT_SILPHCO6F_START_BATTLE
; PRET| 	dw_const EndTrainerBattle,                      SCRIPT_SILPHCO6F_END_BATTLE
; PRET| 
; PRET| SilphCo6F_TextPointers:
; PRET| 	def_text_pointers
; PRET| 	dw_const SilphCo6FSilphWorkerM1Text, TEXT_SILPHCO6F_SILPH_WORKER_M1
; PRET| 	dw_const SilphCo6FSilphWorkerM2Text, TEXT_SILPHCO6F_SILPH_WORKER_M2
; PRET| 	dw_const SilphCo6FSilphWorkerF1Text, TEXT_SILPHCO6F_SILPH_WORKER_F1
; PRET| 	dw_const SilphCo6FSilphWorkerF2Text, TEXT_SILPHCO6F_SILPH_WORKER_F2
; PRET| 	dw_const SilphCo6FSilphWorkerM3Text, TEXT_SILPHCO6F_SILPH_WORKER_M3
; PRET| 	dw_const SilphCo6FRocket1Text,       TEXT_SILPHCO6F_ROCKET1
; PRET| 	dw_const SilphCo6FScientistText,     TEXT_SILPHCO6F_SCIENTIST
; PRET| 	dw_const SilphCo6FRocket2Text,       TEXT_SILPHCO6F_ROCKET2
; PRET| 	dw_const PickUpItemText,             TEXT_SILPHCO6F_HP_UP
; PRET| 	dw_const PickUpItemText,             TEXT_SILPHCO6F_X_ACCURACY
; PRET| 
; PRET| SilphCo6TrainerHeaders:
; PRET| 	def_trainers 6
; PRET| SilphCo6TrainerHeader0:
; PRET| 	trainer EVENT_BEAT_SILPH_CO_6F_TRAINER_0, 2, SilphCo6FRocket1BattleText, SilphCo6FRocket1EndBattleText, SilphCo6FRocket1AfterBattleText
; PRET| SilphCo6TrainerHeader1:
; PRET| 	trainer EVENT_BEAT_SILPH_CO_6F_TRAINER_1, 3, SilphCo6FScientistBattleText, SilphCo6FScientistEndBattleText, SilphCo6FScientistAfterBattleText
; PRET| SilphCo6TrainerHeader2:
; PRET| 	trainer EVENT_BEAT_SILPH_CO_6F_TRAINER_2, 2, SilphCo6FRocket2BattleText, SilphCo6FRocket2EndBattleText, SilphCo6FRocket2AfterBattleText
; PRET| 	db -1 ; end

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] SilphCo6FBeatGiovanniPrintDEOrPrintHLScript (scripts/SilphCo6F.asm:67-69) — at scripts/SilphCo6F.asm:68: .beat_giovanni is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEvent EVENT_BEAT_SILPH_CO_GIOVANNI
; PRET| 	jr nz, .beat_giovanni
; PRET| 	jr .print_text

; ---------------------------------------------------------------------------
; BAIL[hl-half-register-access] SilphCo6FBeatGiovanniPrintDEOrPrintHLScript.beat_giovanni (scripts/SilphCo6F.asm:71-74) — at scripts/SilphCo6F.asm:71: `h` is a half of ESI and has no flag-safe 8-bit x86 form
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld h, d
; PRET| 	ld l, e
; PRET| .print_text
; PRET| 	jp PrintText

; ---------------------------------------------------------------------------
; BAIL[host-pointer-in-16bit-reg] SilphCo6FSilphWorkerM1Text (scripts/SilphCo6F.asm:78-81) — at scripts/SilphCo6F.asm:79: de cannot hold the 32-bit address of .BackToWorkText; callee SilphCo6FBeatGiovanniPrintDEOrPrintHLScript has no abi.json entry
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .TookOverTheBuildingText
; PRET| 	ld de, .BackToWorkText
; PRET| 	call SilphCo6FBeatGiovanniPrintDEOrPrintHLScript
; PRET| 	jp TextScriptEnd

.TookOverTheBuildingText:
    text_far _SilphCo6FSilphWorkerM1TookOverTheBuildingText
    text_end
.BackToWorkText:
    text_far _SilphCo6FSilphWorkerM1BackToWorkText
    text_end

; ---------------------------------------------------------------------------
; BAIL[host-pointer-in-16bit-reg] SilphCo6FSilphWorkerM2Text (scripts/SilphCo6F.asm:93-96) — at scripts/SilphCo6F.asm:94: de cannot hold the 32-bit address of .WeGotEngagedText; callee SilphCo6FBeatGiovanniPrintDEOrPrintHLScript has no abi.json entry
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .HelpMePleaseText
; PRET| 	ld de, .WeGotEngagedText
; PRET| 	call SilphCo6FBeatGiovanniPrintDEOrPrintHLScript
; PRET| 	jp TextScriptEnd

.HelpMePleaseText:
    text_far _SilphCo6FSilphWorkerMHelpMePleaseText
    text_end
.WeGotEngagedText:
    text_far _SilphCo6FSilphWorkerMWeGotEngagedText
    text_end

; ---------------------------------------------------------------------------
; BAIL[host-pointer-in-16bit-reg] SilphCo6FSilphWorkerF1Text (scripts/SilphCo6F.asm:108-111) — at scripts/SilphCo6F.asm:109: de cannot hold the 32-bit address of .HaveToMarryHimText; callee SilphCo6FBeatGiovanniPrintDEOrPrintHLScript has no abi.json entry
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .SuchACowardText
; PRET| 	ld de, .HaveToMarryHimText
; PRET| 	call SilphCo6FBeatGiovanniPrintDEOrPrintHLScript
; PRET| 	jp TextScriptEnd

.SuchACowardText:
    text_far _SilphCo6FSilphWorkerF1SuchACowardText
    text_end
.HaveToMarryHimText:
    text_far _SilphCo6FSilphWorkerF1HaveToMarryHimText
    text_end

; ---------------------------------------------------------------------------
; BAIL[host-pointer-in-16bit-reg] SilphCo6FSilphWorkerF2Text (scripts/SilphCo6F.asm:123-126) — at scripts/SilphCo6F.asm:124: de cannot hold the 32-bit address of .TeamRocketRanText; callee SilphCo6FBeatGiovanniPrintDEOrPrintHLScript has no abi.json entry
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .TeamRocketConquerWorldText
; PRET| 	ld de, .TeamRocketRanText
; PRET| 	call SilphCo6FBeatGiovanniPrintDEOrPrintHLScript
; PRET| 	jp TextScriptEnd

.TeamRocketConquerWorldText:
    text_far _SilphCo6FSilphWorkerF2TeamRocketConquerWorldText
    text_end
.TeamRocketRanText:
    text_far _SilphCo6FSilphWorkerF2TeamRocketRanText
    text_end

; ---------------------------------------------------------------------------
; BAIL[host-pointer-in-16bit-reg] SilphCo6FSilphWorkerM3Text (scripts/SilphCo6F.asm:138-141) — at scripts/SilphCo6F.asm:139: de cannot hold the 32-bit address of .WorkForSilphText; callee SilphCo6FBeatGiovanniPrintDEOrPrintHLScript has no abi.json entry
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .TargetedSilphText
; PRET| 	ld de, .WorkForSilphText
; PRET| 	call SilphCo6FBeatGiovanniPrintDEOrPrintHLScript
; PRET| 	jp TextScriptEnd

.TargetedSilphText:
    text_far _SilphCo6FSilphWorkerM3TargetedSilphText
    text_end
.WorkForSilphText:
    text_far _SilphCo6FSilphWorkerM3WorkForSilphText
    text_end

SilphCo6FRocket1Text:
    mov esi, SilphCo6TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] SilphCo6FRocket1BattleText (scripts/SilphCo6F.asm:158-167) — a generated asset already defines SilphCo6FRocket1BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _SilphCo6FRocket1BattleText
; PRET| 	text_end
; PRET| 
; PRET| SilphCo6FRocket1EndBattleText:
; PRET| 	text_far _SilphCo6FRocket1EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| SilphCo6FRocket1AfterBattleText:
; PRET| 	text_far _SilphCo6FRocket1AfterBattleText
; PRET| 	text_end

SilphCo6FScientistText:
    mov esi, SilphCo6TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] SilphCo6FScientistBattleText (scripts/SilphCo6F.asm:176-185) — a generated asset already defines SilphCo6FScientistBattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _SilphCo6FScientistBattleText
; PRET| 	text_end
; PRET| 
; PRET| SilphCo6FScientistEndBattleText:
; PRET| 	text_far _SilphCo6FScientistEndBattleText
; PRET| 	text_end
; PRET| 
; PRET| SilphCo6FScientistAfterBattleText:
; PRET| 	text_far _SilphCo6FScientistAfterBattleText
; PRET| 	text_end

SilphCo6FRocket2Text:
    mov esi, SilphCo6TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] SilphCo6FRocket2BattleText (scripts/SilphCo6F.asm:194-203) — a generated asset already defines SilphCo6FRocket2BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _SilphCo6FRocket2BattleText
; PRET| 	text_end
; PRET| 
; PRET| SilphCo6FRocket2EndBattleText:
; PRET| 	text_far _SilphCo6FRocket2EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| SilphCo6FRocket2AfterBattleText:
; PRET| 	text_far _SilphCo6FRocket2AfterBattleText
; PRET| 	text_end
