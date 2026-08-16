; SSAnneBow.asm — translated from pret scripts/SSAnneBow.asm by dos_port/tools/sm83xlat.
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


global SSAnneBowSailor2Text
global SSAnneBowSailor3Text
global SSAnneBow_Script

extern CheckFightingMapTrainers   ; NOT YET DEFINED IN THE PORT
extern DisplayEnemyTrainerTextAndStartBattle   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EndTrainerBattle   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern SSAnne5TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern SSAnne5TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern SSAnne5TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern SSAnneBowCooltrainerMText   ; NOT YET DEFINED IN THE PORT
extern SSAnneBowSailor1Text   ; NOT YET DEFINED IN THE PORT
extern SSAnneBowSailor2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern SSAnneBowSailor2BattleText   ; NOT YET DEFINED IN THE PORT
extern SSAnneBowSailor2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern SSAnneBowSailor3AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern SSAnneBowSailor3BattleText   ; NOT YET DEFINED IN THE PORT
extern SSAnneBowSailor3EndBattleText   ; NOT YET DEFINED IN THE PORT
extern SSAnneBowSuperNerdText   ; NOT YET DEFINED IN THE PORT
extern SSAnneBow_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern SSAnneBow_TextPointers   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_SSANNEBOW_DEFAULT                       equ 0
SCRIPT_SSANNEBOW_START_BATTLE                  equ 1
SCRIPT_SSANNEBOW_END_BATTLE                    equ 2
TEXT_SSANNEBOW_SUPER_NERD                      equ 1
TEXT_SSANNEBOW_SAILOR1                         equ 2
TEXT_SSANNEBOW_COOLTRAINER_M                   equ 3
TEXT_SSANNEBOW_SAILOR2                         equ 4
TEXT_SSANNEBOW_SAILOR3                         equ 5

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wSSAnneBowCurScript                            equ 0xD616

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

SSAnneBow_Script:
    call EnableAutoTextBoxDrawing
    mov esi, SSAnne5TrainerHeaders
    mov edi, SSAnneBow_ScriptPointers   ; pret: ld de, SSAnneBow_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wSSAnneBowCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wSSAnneBowCurScript], al
    ret

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] SSAnneBow_ScriptPointers (scripts/SSAnneBow.asm:11-42) — a generated asset already defines SSAnne5TrainerHeaders
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	def_script_pointers
; PRET| 	dw_const CheckFightingMapTrainers,              SCRIPT_SSANNEBOW_DEFAULT
; PRET| 	dw_const DisplayEnemyTrainerTextAndStartBattle, SCRIPT_SSANNEBOW_START_BATTLE
; PRET| 	dw_const EndTrainerBattle,                      SCRIPT_SSANNEBOW_END_BATTLE
; PRET| 
; PRET| SSAnneBow_TextPointers:
; PRET| 	def_text_pointers
; PRET| 	dw_const SSAnneBowSuperNerdText,    TEXT_SSANNEBOW_SUPER_NERD
; PRET| 	dw_const SSAnneBowSailor1Text,      TEXT_SSANNEBOW_SAILOR1
; PRET| 	dw_const SSAnneBowCooltrainerMText, TEXT_SSANNEBOW_COOLTRAINER_M
; PRET| 	dw_const SSAnneBowSailor2Text,      TEXT_SSANNEBOW_SAILOR2
; PRET| 	dw_const SSAnneBowSailor3Text,      TEXT_SSANNEBOW_SAILOR3
; PRET| 
; PRET| SSAnne5TrainerHeaders:
; PRET| 	def_trainers 4
; PRET| SSAnne5TrainerHeader0:
; PRET| 	trainer EVENT_BEAT_SS_ANNE_5_TRAINER_0, 3, SSAnneBowSailor2BattleText, SSAnneBowSailor2EndBattleText, SSAnneBowSailor2AfterBattleText
; PRET| SSAnne5TrainerHeader1:
; PRET| 	trainer EVENT_BEAT_SS_ANNE_5_TRAINER_1, 3, SSAnneBowSailor3BattleText, SSAnneBowSailor3EndBattleText, SSAnneBowSailor3AfterBattleText
; PRET| 	db -1 ; end
; PRET| 
; PRET| SSAnneBowSuperNerdText:
; PRET| 	text_far _SSAnneBowSuperNerdText
; PRET| 	text_end
; PRET| 
; PRET| SSAnneBowSailor1Text:
; PRET| 	text_far _SSAnneBowSailor1Text
; PRET| 	text_end
; PRET| 
; PRET| SSAnneBowCooltrainerMText:
; PRET| 	text_far _SSAnneBowCooltrainerMText
; PRET| 	text_end

SSAnneBowSailor2Text:
    mov esi, SSAnne5TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] SSAnneBowSailor2BattleText (scripts/SSAnneBow.asm:51-60) — a generated asset already defines SSAnneBowSailor2BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _SSAnneBowSailor2BattleText
; PRET| 	text_end
; PRET| 
; PRET| SSAnneBowSailor2EndBattleText:
; PRET| 	text_far _SSAnneBowSailor2EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| SSAnneBowSailor2AfterBattleText:
; PRET| 	text_far _SSAnneBowSailor2AfterBattleText
; PRET| 	text_end

SSAnneBowSailor3Text:
    mov esi, SSAnne5TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] SSAnneBowSailor3BattleText (scripts/SSAnneBow.asm:69-78) — a generated asset already defines SSAnneBowSailor3BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _SSAnneBowSailor3BattleText
; PRET| 	text_end
; PRET| 
; PRET| SSAnneBowSailor3EndBattleText:
; PRET| 	text_far _SSAnneBowSailor3EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| SSAnneBowSailor3AfterBattleText:
; PRET| 	text_far _SSAnneBowSailor3AfterBattleText
; PRET| 	text_end
