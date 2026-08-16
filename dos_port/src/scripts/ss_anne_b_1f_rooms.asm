; SSAnneB1FRooms.asm — translated from pret scripts/SSAnneB1FRooms.asm by dos_port/tools/sm83xlat.
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


global SSAnneB1FRoomsFisherText
global SSAnneB1FRoomsMachokeText
global SSAnneB1FRoomsSailor1Text
global SSAnneB1FRoomsSailor2Text
global SSAnneB1FRoomsSailor3Text
global SSAnneB1FRoomsSailor4Text
global SSAnneB1FRoomsSailor5Text
global SSAnneB1FRooms_Script

extern CheckFightingMapTrainers   ; NOT YET DEFINED IN THE PORT
extern DisplayEnemyTrainerTextAndStartBattle   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EndTrainerBattle   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern PickUpItemText   ; NOT YET DEFINED IN THE PORT
extern PlayCry   ; NOT YET DEFINED IN THE PORT
extern SSAnne10TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern SSAnne10TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern SSAnne10TrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern SSAnne10TrainerHeader3   ; NOT YET DEFINED IN THE PORT
extern SSAnne10TrainerHeader4   ; NOT YET DEFINED IN THE PORT
extern SSAnne10TrainerHeader5   ; NOT YET DEFINED IN THE PORT
extern SSAnne10TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern SSAnneB1FRoomsFisherAfterBattleText   ; NOT YET DEFINED IN THE PORT
extern SSAnneB1FRoomsFisherBattleText   ; NOT YET DEFINED IN THE PORT
extern SSAnneB1FRoomsFisherEndBattleText   ; NOT YET DEFINED IN THE PORT
extern SSAnneB1FRoomsSailor1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern SSAnneB1FRoomsSailor1BattleText   ; NOT YET DEFINED IN THE PORT
extern SSAnneB1FRoomsSailor1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern SSAnneB1FRoomsSailor2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern SSAnneB1FRoomsSailor2BattleText   ; NOT YET DEFINED IN THE PORT
extern SSAnneB1FRoomsSailor2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern SSAnneB1FRoomsSailor3AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern SSAnneB1FRoomsSailor3BattleText   ; NOT YET DEFINED IN THE PORT
extern SSAnneB1FRoomsSailor3EndBattleText   ; NOT YET DEFINED IN THE PORT
extern SSAnneB1FRoomsSailor4AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern SSAnneB1FRoomsSailor4BattleText   ; NOT YET DEFINED IN THE PORT
extern SSAnneB1FRoomsSailor4EndBattleText   ; NOT YET DEFINED IN THE PORT
extern SSAnneB1FRoomsSailor5AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern SSAnneB1FRoomsSailor5BattleText   ; NOT YET DEFINED IN THE PORT
extern SSAnneB1FRoomsSailor5EndBattleText   ; NOT YET DEFINED IN THE PORT
extern SSAnneB1FRoomsSuperNerdText   ; NOT YET DEFINED IN THE PORT
extern SSAnneB1FRooms_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern SSAnneB1FRooms_TextPointers   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern _SSAnneB1FRoomsMachokeText   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_SSANNEB1FROOMS_DEFAULT                  equ 0
SCRIPT_SSANNEB1FROOMS_START_BATTLE             equ 1
SCRIPT_SSANNEB1FROOMS_END_BATTLE               equ 2
TEXT_SSANNEB1FROOMS_SAILOR1                    equ 1
TEXT_SSANNEB1FROOMS_SAILOR2                    equ 2
TEXT_SSANNEB1FROOMS_SAILOR3                    equ 3
TEXT_SSANNEB1FROOMS_SAILOR4                    equ 4
TEXT_SSANNEB1FROOMS_SAILOR5                    equ 5
TEXT_SSANNEB1FROOMS_FISHER                     equ 6
TEXT_SSANNEB1FROOMS_SUPER_NERD                 equ 7
TEXT_SSANNEB1FROOMS_MACHOKE                    equ 8
TEXT_SSANNEB1FROOMS_ETHER                      equ 9
TEXT_SSANNEB1FROOMS_TM_REST                    equ 10
TEXT_SSANNEB1FROOMS_MAX_POTION                 equ 11

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wSSAnneB1FRoomsCurScript                       equ 0xD628

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

SSAnneB1FRooms_Script:
    call EnableAutoTextBoxDrawing
    mov esi, SSAnne10TrainerHeaders
    mov edi, SSAnneB1FRooms_ScriptPointers   ; pret: ld de, SSAnneB1FRooms_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wSSAnneB1FRoomsCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wSSAnneB1FRoomsCurScript], al
    ret

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] SSAnneB1FRooms_ScriptPointers (scripts/SSAnneB1FRooms.asm:11-44) — a generated asset already defines SSAnne10TrainerHeaders
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	def_script_pointers
; PRET| 	dw_const CheckFightingMapTrainers,              SCRIPT_SSANNEB1FROOMS_DEFAULT
; PRET| 	dw_const DisplayEnemyTrainerTextAndStartBattle, SCRIPT_SSANNEB1FROOMS_START_BATTLE
; PRET| 	dw_const EndTrainerBattle,                      SCRIPT_SSANNEB1FROOMS_END_BATTLE
; PRET| 
; PRET| SSAnneB1FRooms_TextPointers:
; PRET| 	def_text_pointers
; PRET| 	dw_const SSAnneB1FRoomsSailor1Text,   TEXT_SSANNEB1FROOMS_SAILOR1
; PRET| 	dw_const SSAnneB1FRoomsSailor2Text,   TEXT_SSANNEB1FROOMS_SAILOR2
; PRET| 	dw_const SSAnneB1FRoomsSailor3Text,   TEXT_SSANNEB1FROOMS_SAILOR3
; PRET| 	dw_const SSAnneB1FRoomsSailor4Text,   TEXT_SSANNEB1FROOMS_SAILOR4
; PRET| 	dw_const SSAnneB1FRoomsSailor5Text,   TEXT_SSANNEB1FROOMS_SAILOR5
; PRET| 	dw_const SSAnneB1FRoomsFisherText,    TEXT_SSANNEB1FROOMS_FISHER
; PRET| 	dw_const SSAnneB1FRoomsSuperNerdText, TEXT_SSANNEB1FROOMS_SUPER_NERD
; PRET| 	dw_const SSAnneB1FRoomsMachokeText,   TEXT_SSANNEB1FROOMS_MACHOKE
; PRET| 	dw_const PickUpItemText,              TEXT_SSANNEB1FROOMS_ETHER
; PRET| 	dw_const PickUpItemText,              TEXT_SSANNEB1FROOMS_TM_REST
; PRET| 	dw_const PickUpItemText,              TEXT_SSANNEB1FROOMS_MAX_POTION
; PRET| 
; PRET| SSAnne10TrainerHeaders:
; PRET| 	def_trainers
; PRET| SSAnne10TrainerHeader0:
; PRET| 	trainer EVENT_BEAT_SS_ANNE_10_TRAINER_0, 2, SSAnneB1FRoomsSailor1BattleText, SSAnneB1FRoomsSailor1EndBattleText, SSAnneB1FRoomsSailor1AfterBattleText
; PRET| SSAnne10TrainerHeader1:
; PRET| 	trainer EVENT_BEAT_SS_ANNE_10_TRAINER_1, 3, SSAnneB1FRoomsSailor2BattleText, SSAnneB1FRoomsSailor2EndBattleText, SSAnneB1FRoomsSailor2AfterBattleText
; PRET| SSAnne10TrainerHeader2:
; PRET| 	trainer EVENT_BEAT_SS_ANNE_10_TRAINER_2, 2, SSAnneB1FRoomsSailor3BattleText, SSAnneB1FRoomsSailor3EndBattleText, SSAnneB1FRoomsSailor3AfterBattleText
; PRET| SSAnne10TrainerHeader3:
; PRET| 	trainer EVENT_BEAT_SS_ANNE_10_TRAINER_3, 2, SSAnneB1FRoomsSailor4BattleText, SSAnneB1FRoomsSailor4EndBattleText, SSAnneB1FRoomsSailor4AfterBattleText
; PRET| SSAnne10TrainerHeader4:
; PRET| 	trainer EVENT_BEAT_SS_ANNE_10_TRAINER_4, 2, SSAnneB1FRoomsSailor5BattleText, SSAnneB1FRoomsSailor5EndBattleText, SSAnneB1FRoomsSailor5AfterBattleText
; PRET| SSAnne10TrainerHeader5:
; PRET| 	trainer EVENT_BEAT_SS_ANNE_10_TRAINER_5, 3, SSAnneB1FRoomsFisherBattleText, SSAnneB1FRoomsFisherEndBattleText, SSAnneB1FRoomsFisherAfterBattleText
; PRET| 	db -1 ; end

SSAnneB1FRoomsSailor1Text:
    mov esi, SSAnne10TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

SSAnneB1FRoomsSailor2Text:
    mov esi, SSAnne10TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

SSAnneB1FRoomsSailor3Text:
    mov esi, SSAnne10TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

SSAnneB1FRoomsSailor4Text:
    mov esi, SSAnne10TrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

SSAnneB1FRoomsSailor5Text:
    mov esi, SSAnne10TrainerHeader4
    call TalkToTrainer
    jmp TextScriptEnd

SSAnneB1FRoomsFisherText:
    mov esi, SSAnne10TrainerHeader5
    call TalkToTrainer
    jmp TextScriptEnd

SSAnneB1FRoomsMachokeText:
    text_far _SSAnneB1FRoomsMachokeText

    mov al, 41
    call PlayCry
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] SSAnneB1FRoomsSailor1BattleText (scripts/SSAnneB1FRooms.asm:90-163) — a generated asset already defines SSAnneB1FRoomsSailor1BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _SSAnneB1FRoomsSailor1BattleText
; PRET| 	text_end
; PRET| 
; PRET| SSAnneB1FRoomsSailor1EndBattleText:
; PRET| 	text_far _SSAnneB1FRoomsSailor1EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| SSAnneB1FRoomsSailor1AfterBattleText:
; PRET| 	text_far _SSAnneB1FRoomsSailor1AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| SSAnneB1FRoomsSailor2BattleText:
; PRET| 	text_far _SSAnneB1FRoomsSailor2BattleText
; PRET| 	text_end
; PRET| 
; PRET| SSAnneB1FRoomsSailor2EndBattleText:
; PRET| 	text_far _SSAnneB1FRoomsSailor2EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| SSAnneB1FRoomsSailor2AfterBattleText:
; PRET| 	text_far _SSAnneB1FRoomsSailor2AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| SSAnneB1FRoomsSailor3BattleText:
; PRET| 	text_far _SSAnneB1FRoomsSailor3BattleText
; PRET| 	text_end
; PRET| 
; PRET| SSAnneB1FRoomsSailor3EndBattleText:
; PRET| 	text_far _SSAnneB1FRoomsSailor3EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| SSAnneB1FRoomsSailor3AfterBattleText:
; PRET| 	text_far _SSAnneB1FRoomsSailor3AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| SSAnneB1FRoomsSailor4BattleText:
; PRET| 	text_far _SSAnneB1FRoomsSailor4BattleText
; PRET| 	text_end
; PRET| 
; PRET| SSAnneB1FRoomsSailor4EndBattleText:
; PRET| 	text_far _SSAnneB1FRoomsSailor4EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| SSAnneB1FRoomsSailor4AfterBattleText:
; PRET| 	text_far _SSAnneB1FRoomsSailor4AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| SSAnneB1FRoomsSailor5BattleText:
; PRET| 	text_far _SSAnneB1FRoomsSailor5BattleText
; PRET| 	text_end
; PRET| 
; PRET| SSAnneB1FRoomsSailor5EndBattleText:
; PRET| 	text_far _SSAnneB1FRoomsSailor5EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| SSAnneB1FRoomsSailor5AfterBattleText:
; PRET| 	text_far _SSAnneB1FRoomsSailor5AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| SSAnneB1FRoomsFisherBattleText:
; PRET| 	text_far _SSAnneB1FRoomsFisherBattleText
; PRET| 	text_end
; PRET| 
; PRET| SSAnneB1FRoomsFisherEndBattleText:
; PRET| 	text_far _SSAnneB1FRoomsFisherEndBattleText
; PRET| 	text_end
; PRET| 
; PRET| SSAnneB1FRoomsFisherAfterBattleText:
; PRET| 	text_far _SSAnneB1FRoomsFisherAfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| SSAnneB1FRoomsSuperNerdText:
; PRET| 	text_far _SSAnneB1FRoomsSuperNerdText
; PRET| 	text_end
