; Route11.asm — translated from pret scripts/Route11.asm by dos_port/tools/sm83xlat.
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


global Route11Gambler1Text
global Route11Gambler2Text
global Route11Gambler3Text
global Route11Gambler4Text
global Route11SuperNerd1Text
global Route11SuperNerd2Text
global Route11Youngster1Text
global Route11Youngster2Text
global Route11Youngster3Text
global Route11Youngster4Text
global Route11_Script

extern CheckFightingMapTrainers   ; NOT YET DEFINED IN THE PORT
extern DisplayEnemyTrainerTextAndStartBattle   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EndTrainerBattle   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern Route11DiglettsCaveSignText   ; NOT YET DEFINED IN THE PORT
extern Route11Gambler1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route11Gambler1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route11Gambler1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route11Gambler2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route11Gambler2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route11Gambler2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route11Gambler3AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route11Gambler3BattleText   ; NOT YET DEFINED IN THE PORT
extern Route11Gambler3EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route11Gambler4AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route11Gambler4BattleText   ; NOT YET DEFINED IN THE PORT
extern Route11Gambler4EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route11SuperNerd1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route11SuperNerd1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route11SuperNerd1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route11SuperNerd2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route11SuperNerd2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route11SuperNerd2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route11TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern Route11TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern Route11TrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern Route11TrainerHeader3   ; NOT YET DEFINED IN THE PORT
extern Route11TrainerHeader4   ; NOT YET DEFINED IN THE PORT
extern Route11TrainerHeader5   ; NOT YET DEFINED IN THE PORT
extern Route11TrainerHeader6   ; NOT YET DEFINED IN THE PORT
extern Route11TrainerHeader7   ; NOT YET DEFINED IN THE PORT
extern Route11TrainerHeader8   ; NOT YET DEFINED IN THE PORT
extern Route11TrainerHeader9   ; NOT YET DEFINED IN THE PORT
extern Route11TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern Route11Youngster1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route11Youngster1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route11Youngster1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route11Youngster2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route11Youngster2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route11Youngster2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route11Youngster3AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route11Youngster3BattleText   ; NOT YET DEFINED IN THE PORT
extern Route11Youngster3EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route11Youngster4AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route11Youngster4BattleText   ; NOT YET DEFINED IN THE PORT
extern Route11Youngster4EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route11_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern Route11_TextPointers   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_ROUTE11_DEFAULT                         equ 0
SCRIPT_ROUTE11_START_BATTLE                    equ 1
SCRIPT_ROUTE11_END_BATTLE                      equ 2
TEXT_ROUTE11_GAMBLER1                          equ 1
TEXT_ROUTE11_GAMBLER2                          equ 2
TEXT_ROUTE11_YOUNGSTER1                        equ 3
TEXT_ROUTE11_SUPER_NERD1                       equ 4
TEXT_ROUTE11_YOUNGSTER2                        equ 5
TEXT_ROUTE11_GAMBLER3                          equ 6
TEXT_ROUTE11_GAMBLER4                          equ 7
TEXT_ROUTE11_YOUNGSTER3                        equ 8
TEXT_ROUTE11_SUPER_NERD2                       equ 9
TEXT_ROUTE11_YOUNGSTER4                        equ 10
TEXT_ROUTE11_DIGLETTSCAVE_SIGN                 equ 11

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wRoute11CurScript                              equ 0xD622

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

Route11_Script:
    call EnableAutoTextBoxDrawing
    mov esi, Route11TrainerHeaders
    mov edi, Route11_ScriptPointers   ; pret: ld de, Route11_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wRoute11CurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wRoute11CurScript], al
    ret

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] Route11_ScriptPointers (scripts/Route11.asm:11-52) — a generated asset already defines Route11_ScriptPointers
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	def_script_pointers
; PRET| 	dw_const CheckFightingMapTrainers,              SCRIPT_ROUTE11_DEFAULT
; PRET| 	dw_const DisplayEnemyTrainerTextAndStartBattle, SCRIPT_ROUTE11_START_BATTLE
; PRET| 	dw_const EndTrainerBattle,                      SCRIPT_ROUTE11_END_BATTLE
; PRET| 
; PRET| Route11_TextPointers:
; PRET| 	def_text_pointers
; PRET| 	dw_const Route11Gambler1Text,         TEXT_ROUTE11_GAMBLER1
; PRET| 	dw_const Route11Gambler2Text,         TEXT_ROUTE11_GAMBLER2
; PRET| 	dw_const Route11Youngster1Text,       TEXT_ROUTE11_YOUNGSTER1
; PRET| 	dw_const Route11SuperNerd1Text,       TEXT_ROUTE11_SUPER_NERD1
; PRET| 	dw_const Route11Youngster2Text,       TEXT_ROUTE11_YOUNGSTER2
; PRET| 	dw_const Route11Gambler3Text,         TEXT_ROUTE11_GAMBLER3
; PRET| 	dw_const Route11Gambler4Text,         TEXT_ROUTE11_GAMBLER4
; PRET| 	dw_const Route11Youngster3Text,       TEXT_ROUTE11_YOUNGSTER3
; PRET| 	dw_const Route11SuperNerd2Text,       TEXT_ROUTE11_SUPER_NERD2
; PRET| 	dw_const Route11Youngster4Text,       TEXT_ROUTE11_YOUNGSTER4
; PRET| 	dw_const Route11DiglettsCaveSignText, TEXT_ROUTE11_DIGLETTSCAVE_SIGN
; PRET| 
; PRET| Route11TrainerHeaders:
; PRET| 	def_trainers
; PRET| Route11TrainerHeader0:
; PRET| 	trainer EVENT_BEAT_ROUTE_11_TRAINER_0, 3, Route11Gambler1BattleText, Route11Gambler1EndBattleText, Route11Gambler1AfterBattleText
; PRET| Route11TrainerHeader1:
; PRET| 	trainer EVENT_BEAT_ROUTE_11_TRAINER_1, 2, Route11Gambler2BattleText, Route11Gambler2EndBattleText, Route11Gambler2AfterBattleText
; PRET| Route11TrainerHeader2:
; PRET| 	trainer EVENT_BEAT_ROUTE_11_TRAINER_2, 3, Route11Youngster1BattleText, Route11Youngster1EndBattleText, Route11Youngster1AfterBattleText
; PRET| Route11TrainerHeader3:
; PRET| 	trainer EVENT_BEAT_ROUTE_11_TRAINER_3, 3, Route11SuperNerd1BattleText, Route11SuperNerd1EndBattleText, Route11SuperNerd1AfterBattleText
; PRET| Route11TrainerHeader4:
; PRET| 	trainer EVENT_BEAT_ROUTE_11_TRAINER_4, 4, Route11Youngster2BattleText, Route11Youngster2EndBattleText, Route11Youngster2AfterBattleText
; PRET| Route11TrainerHeader5:
; PRET| 	trainer EVENT_BEAT_ROUTE_11_TRAINER_5, 3, Route11Gambler3BattleText, Route11Gambler3EndBattleText, Route11Gambler3AfterBattleText
; PRET| Route11TrainerHeader6:
; PRET| 	trainer EVENT_BEAT_ROUTE_11_TRAINER_6, 3, Route11Gambler4BattleText, Route11Gambler4EndBattleText, Route11Gambler4AfterBattleText
; PRET| Route11TrainerHeader7:
; PRET| 	trainer EVENT_BEAT_ROUTE_11_TRAINER_7, 4, Route11Youngster3BattleText, Route11Youngster3EndBattleText, Route11Youngster3AfterBattleText
; PRET| Route11TrainerHeader8:
; PRET| 	trainer EVENT_BEAT_ROUTE_11_TRAINER_8, 3, Route11SuperNerd2BattleText, Route11SuperNerd2EndBattleText, Route11SuperNerd2AfterBattleText
; PRET| Route11TrainerHeader9:
; PRET| 	trainer EVENT_BEAT_ROUTE_11_TRAINER_9, 4, Route11Youngster4BattleText, Route11Youngster4EndBattleText, Route11Youngster4AfterBattleText
; PRET| 	db -1 ; end

Route11Gambler1Text:
    mov esi, Route11TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] Route11Gambler1BattleText (scripts/Route11.asm:61-70) — a generated asset already defines Route11Gambler1BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _Route11Gambler1BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route11Gambler1EndBattleText:
; PRET| 	text_far _Route11Gambler1EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route11Gambler1AfterBattleText:
; PRET| 	text_far _Route11Gambler1AfterBattleText
; PRET| 	text_end

Route11Gambler2Text:
    mov esi, Route11TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] Route11Gambler2BattleText (scripts/Route11.asm:79-88) — a generated asset already defines Route11Gambler2BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _Route11Gambler2BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route11Gambler2EndBattleText:
; PRET| 	text_far _Route11Gambler2EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route11Gambler2AfterBattleText:
; PRET| 	text_far _Route11Gambler2AfterBattleText
; PRET| 	text_end

Route11Youngster1Text:
    mov esi, Route11TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] Route11Youngster1BattleText (scripts/Route11.asm:97-106) — a generated asset already defines Route11Youngster1BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _Route11Youngster1BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route11Youngster1EndBattleText:
; PRET| 	text_far _Route11Youngster1EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route11Youngster1AfterBattleText:
; PRET| 	text_far _Route11Youngster1AfterBattleText
; PRET| 	text_end

Route11SuperNerd1Text:
    mov esi, Route11TrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] Route11SuperNerd1BattleText (scripts/Route11.asm:115-124) — a generated asset already defines Route11SuperNerd1BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _Route11SuperNerd1BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route11SuperNerd1EndBattleText:
; PRET| 	text_far _Route11SuperNerd1EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route11SuperNerd1AfterBattleText:
; PRET| 	text_far _Route11SuperNerd1AfterBattleText
; PRET| 	text_end

Route11Youngster2Text:
    mov esi, Route11TrainerHeader4
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] Route11Youngster2BattleText (scripts/Route11.asm:133-142) — a generated asset already defines Route11Youngster2BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _Route11Youngster2BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route11Youngster2EndBattleText:
; PRET| 	text_far _Route11Youngster2EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route11Youngster2AfterBattleText:
; PRET| 	text_far _Route11Youngster2AfterBattleText5
; PRET| 	text_end

Route11Gambler3Text:
    mov esi, Route11TrainerHeader5
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] Route11Gambler3BattleText (scripts/Route11.asm:151-160) — a generated asset already defines Route11Gambler3BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _Route11Gambler3BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route11Gambler3EndBattleText:
; PRET| 	text_far _Route11Gambler3EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route11Gambler3AfterBattleText:
; PRET| 	text_far _Route11Gambler3AfterBattleText
; PRET| 	text_end

Route11Gambler4Text:
    mov esi, Route11TrainerHeader6
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] Route11Gambler4BattleText (scripts/Route11.asm:169-178) — a generated asset already defines Route11Gambler4BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _Route11Gambler4BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route11Gambler4EndBattleText:
; PRET| 	text_far _Route11Gambler4EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route11Gambler4AfterBattleText:
; PRET| 	text_far _Route11Gambler4AfterBattleText
; PRET| 	text_end

Route11Youngster3Text:
    mov esi, Route11TrainerHeader7
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] Route11Youngster3BattleText (scripts/Route11.asm:187-196) — a generated asset already defines Route11Youngster3BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _Route11Youngster3BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route11Youngster3EndBattleText:
; PRET| 	text_far _Route11Youngster3EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route11Youngster3AfterBattleText:
; PRET| 	text_far _Route11Youngster3AfterBattleText
; PRET| 	text_end

Route11SuperNerd2Text:
    mov esi, Route11TrainerHeader8
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] Route11SuperNerd2BattleText (scripts/Route11.asm:205-214) — a generated asset already defines Route11SuperNerd2BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _Route11SuperNerd2BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route11SuperNerd2EndBattleText:
; PRET| 	text_far _Route11SuperNerd2EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route11SuperNerd2AfterBattleText:
; PRET| 	text_far _Route11SuperNerd2AfterBattleText
; PRET| 	text_end

Route11Youngster4Text:
    mov esi, Route11TrainerHeader9
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] Route11Youngster4BattleText (scripts/Route11.asm:223-236) — a generated asset already defines Route11Youngster4BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _Route11Youngster4BattleText
; PRET| 	text_end
; PRET| 
; PRET| Route11Youngster4EndBattleText:
; PRET| 	text_far _Route11Youngster4EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route11Youngster4AfterBattleText:
; PRET| 	text_far _Route11Youngster4AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| Route11DiglettsCaveSignText:
; PRET| 	text_far _Route11DiglettsCaveSignText
; PRET| 	text_end
