; SilphCo10F.asm — translated from pret scripts/SilphCo10F.asm by dos_port/tools/sm83xlat.
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


global SilphCo10FGateCallbackScript
global SilphCo10FRocketText
global SilphCo10FScientistText
global SilphCo10F_Script
global SilphCo10F_SetUnlockedSilphCoDoorsScript

extern CheckFightingMapTrainers   ; NOT YET DEFINED IN THE PORT
extern DisplayEnemyTrainerTextAndStartBattle   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EndTrainerBattle   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern PickUpItemText   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern ReplaceTileBlock   ; NOT YET DEFINED IN THE PORT
extern SilphCo10FRocketAfterBattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo10FRocketBattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo10FRocketEndBattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo10FScientistAfterBattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo10FScientistBattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo10FScientistEndBattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo10FSilphWorkerFText   ; NOT YET DEFINED IN THE PORT
extern SilphCo10F_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern SilphCo10F_TextPointers   ; NOT YET DEFINED IN THE PORT
extern SilphCo10TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern SilphCo10TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern SilphCo10TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern SilphCo2F_SetCardKeyDoorYScript   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_SILPHCO10F_DEFAULT                      equ 0
SCRIPT_SILPHCO10F_START_BATTLE                 equ 1
SCRIPT_SILPHCO10F_END_BATTLE                   equ 2
TEXT_SILPHCO10F_ROCKET                         equ 1
TEXT_SILPHCO10F_SCIENTIST                      equ 2
TEXT_SILPHCO10F_SILPH_WORKER_F                 equ 3
TEXT_SILPHCO10F_TM_EARTHQUAKE                  equ 4
TEXT_SILPHCO10F_RARE_CANDY                     equ 5
TEXT_SILPHCO10F_CARBOS                         equ 6

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
wSilphCo10FCurScript                           equ 0xD657

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

SilphCo10F_Script:
    call SilphCo10FGateCallbackScript
    call EnableAutoTextBoxDrawing
    mov esi, SilphCo10TrainerHeaders
    mov edi, SilphCo10F_ScriptPointers   ; pret: ld de, SilphCo10F_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wSilphCo10FCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wSilphCo10FCurScript], al
    ret

SilphCo10FGateCallbackScript:
    mov esi, wCurrentMapScriptFlags
    test byte [ebp + esi], (1 << (BIT_CUR_MAP_LOADED_1))
    pushfd    ; SM83 form writes no flags
        and byte [ebp + esi], ~(1 << (BIT_CUR_MAP_LOADED_1)) & 0xFF
    popfd
    jnz .nr_15
        ret
.nr_15:
    mov esi, .GateCoordinates
    call SilphCo2F_SetCardKeyDoorYScript
    call SilphCo10F_SetUnlockedSilphCoDoorsScript
    CheckEvent EVENT_SILPH_CO_10_UNLOCKED_DOOR
    jz .nr_20
        ret
.nr_20:
    mov al, 0x54
    mov [ebp + wNewTileBlockID], al
    mov bx, ((4) << 8) | (5)
; DEVIATION{class=banking; pret=macros/predef.asm:predef_jump; behavior=Predef dispatch replaced by a direct jmp, and the predef id is not left in A because no reader is live; evidence=PredefPointers is unported and the flat model needs no bank switch, dataflow shows A dead after this site; lifetime=retired when PredefPointers is ported}
    jmp ReplaceTileBlock

.GateCoordinates:
    db 4, 5
    db -1

SilphCo10F_SetUnlockedSilphCoDoorsScript:
    mov al, [ebp + hUnlockedSilphCoDoors]
    test al, al
    jnz .nr_33
        ret
.nr_33:
    SetEvent EVENT_SILPH_CO_10_UNLOCKED_DOOR
    ret

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] SilphCo10F_ScriptPointers (scripts/SilphCo10F.asm:38-58) — a generated asset already defines SilphCo10TrainerHeaders
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	def_script_pointers
; PRET| 	dw_const CheckFightingMapTrainers,              SCRIPT_SILPHCO10F_DEFAULT
; PRET| 	dw_const DisplayEnemyTrainerTextAndStartBattle, SCRIPT_SILPHCO10F_START_BATTLE
; PRET| 	dw_const EndTrainerBattle,                      SCRIPT_SILPHCO10F_END_BATTLE
; PRET| 
; PRET| SilphCo10F_TextPointers:
; PRET| 	def_text_pointers
; PRET| 	dw_const SilphCo10FRocketText,       TEXT_SILPHCO10F_ROCKET
; PRET| 	dw_const SilphCo10FScientistText,    TEXT_SILPHCO10F_SCIENTIST
; PRET| 	dw_const SilphCo10FSilphWorkerFText, TEXT_SILPHCO10F_SILPH_WORKER_F
; PRET| 	dw_const PickUpItemText,             TEXT_SILPHCO10F_TM_EARTHQUAKE
; PRET| 	dw_const PickUpItemText,             TEXT_SILPHCO10F_RARE_CANDY
; PRET| 	dw_const PickUpItemText,             TEXT_SILPHCO10F_CARBOS
; PRET| 
; PRET| SilphCo10TrainerHeaders:
; PRET| 	def_trainers
; PRET| SilphCo10TrainerHeader0:
; PRET| 	trainer EVENT_BEAT_SILPH_CO_10F_TRAINER_0, 3, SilphCo10FRocketBattleText, SilphCo10FRocketEndBattleText, SilphCo10FRocketAfterBattleText
; PRET| SilphCo10TrainerHeader1:
; PRET| 	trainer EVENT_BEAT_SILPH_CO_10F_TRAINER_1, 4, SilphCo10FScientistBattleText, SilphCo10FScientistEndBattleText, SilphCo10FScientistAfterBattleText
; PRET| 	db -1 ; end

SilphCo10FRocketText:
    mov esi, SilphCo10TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

SilphCo10FScientistText:
    mov esi, SilphCo10TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] SilphCo10FSilphWorkerFText (scripts/SilphCo10F.asm:74-80) — at scripts/SilphCo10F.asm:75: .QuietAboutMyCryingText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEvent EVENT_BEAT_SILPH_CO_GIOVANNI
; PRET| 	ld hl, .QuietAboutMyCryingText
; PRET| 	jr nz, .beat_giovanni
; PRET| 	ld hl, .ImScaredText
; PRET| .beat_giovanni
; PRET| 	call PrintText
; PRET| 	jp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] SilphCo10FSilphWorkerFText.ImScaredText (scripts/SilphCo10F.asm:83-112) — a generated asset already defines SilphCo10FRocketBattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _SilphCo10FSilphWorkerFImScaredText
; PRET| 	text_end
; PRET| 
; PRET| .QuietAboutMyCryingText:
; PRET| 	text_far _SilphCo10FSilphWorkerFQuietAboutMyCryingText
; PRET| 	text_end
; PRET| 
; PRET| SilphCo10FRocketBattleText:
; PRET| 	text_far _SilphCo10FRocketBattleText
; PRET| 	text_end
; PRET| 
; PRET| SilphCo10FRocketEndBattleText:
; PRET| 	text_far _SilphCo10FRocketEndBattleText
; PRET| 	text_end
; PRET| 
; PRET| SilphCo10FRocketAfterBattleText:
; PRET| 	text_far _SilphCo10FRocketAfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| SilphCo10FScientistBattleText:
; PRET| 	text_far _SilphCo10FScientistBattleText
; PRET| 	text_end
; PRET| 
; PRET| SilphCo10FScientistEndBattleText:
; PRET| 	text_far _SilphCo10FScientistEndBattleText
; PRET| 	text_end
; PRET| 
; PRET| SilphCo10FScientistAfterBattleText:
; PRET| 	text_far _SilphCo10FScientistAfterBattleText
; PRET| 	text_end
