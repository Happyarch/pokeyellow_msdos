; SSAnne1FRooms.asm — translated from pret scripts/SSAnne1FRooms.asm by dos_port/tools/sm83xlat.
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


global SSAnne1FRoomsCooltrainerFText
global SSAnne1FRoomsGentleman1Text
global SSAnne1FRoomsGentleman2Text
global SSAnne1FRoomsWigglytuffText
global SSAnne1FRoomsYoungsterText
global SSAnne1FRooms_Script

extern CheckFightingMapTrainers   ; NOT YET DEFINED IN THE PORT
extern DisplayEnemyTrainerTextAndStartBattle   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EndTrainerBattle   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern PickUpItemText   ; NOT YET DEFINED IN THE PORT
extern PlayCry   ; NOT YET DEFINED IN THE PORT
extern SSAnne1FRoomsCooltrainerFAfterBattleText   ; NOT YET DEFINED IN THE PORT
extern SSAnne1FRoomsCooltrainerFBattleText   ; NOT YET DEFINED IN THE PORT
extern SSAnne1FRoomsCooltrainerFEndBattleText   ; NOT YET DEFINED IN THE PORT
extern SSAnne1FRoomsGentleman1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern SSAnne1FRoomsGentleman1BattleText   ; NOT YET DEFINED IN THE PORT
extern SSAnne1FRoomsGentleman1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern SSAnne1FRoomsGentleman2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern SSAnne1FRoomsGentleman2BattleText   ; NOT YET DEFINED IN THE PORT
extern SSAnne1FRoomsGentleman2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern SSAnne1FRoomsGentleman3Text   ; NOT YET DEFINED IN THE PORT
extern SSAnne1FRoomsGirl1Text   ; NOT YET DEFINED IN THE PORT
extern SSAnne1FRoomsGirl2Text   ; NOT YET DEFINED IN THE PORT
extern SSAnne1FRoomsLittleGirlText   ; NOT YET DEFINED IN THE PORT
extern SSAnne1FRoomsMiddleAgedManText   ; NOT YET DEFINED IN THE PORT
extern SSAnne1FRoomsYoungsterAfterBattleText   ; NOT YET DEFINED IN THE PORT
extern SSAnne1FRoomsYoungsterBattleText   ; NOT YET DEFINED IN THE PORT
extern SSAnne1FRoomsYoungsterEndBattleText   ; NOT YET DEFINED IN THE PORT
extern SSAnne1FRooms_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern SSAnne1FRooms_TextPointers   ; NOT YET DEFINED IN THE PORT
extern SSAnne8TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern SSAnne8TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern SSAnne8TrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern SSAnne8TrainerHeader3   ; NOT YET DEFINED IN THE PORT
extern SSAnne8TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern _SSAnne1FRoomsWigglytuffText   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_SSANNE1FROOMS_DEFAULT                   equ 0
SCRIPT_SSANNE1FROOMS_START_BATTLE              equ 1
SCRIPT_SSANNE1FROOMS_END_BATTLE                equ 2
TEXT_SSANNE1FROOMS_GENTLEMAN1                  equ 1
TEXT_SSANNE1FROOMS_GENTLEMAN2                  equ 2
TEXT_SSANNE1FROOMS_YOUNGSTER                   equ 3
TEXT_SSANNE1FROOMS_COOLTRAINER_F               equ 4
TEXT_SSANNE1FROOMS_GIRL1                       equ 5
TEXT_SSANNE1FROOMS_MIDDLE_AGED_MAN             equ 6
TEXT_SSANNE1FROOMS_LITTLE_GIRL                 equ 7
TEXT_SSANNE1FROOMS_WIGGLYTUFF                  equ 8
TEXT_SSANNE1FROOMS_GIRL2                       equ 9
TEXT_SSANNE1FROOMS_TM_BODY_SLAM                equ 10
TEXT_SSANNE1FROOMS_GENTLEMAN3                  equ 11

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wSSAnne1FRoomsCurScript                        equ 0xD607

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

SSAnne1FRooms_Script:
    call EnableAutoTextBoxDrawing
    mov esi, SSAnne8TrainerHeaders
    mov edi, SSAnne1FRooms_ScriptPointers   ; pret: ld de, SSAnne1FRooms_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wSSAnne1FRoomsCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wSSAnne1FRoomsCurScript], al
    ret

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] SSAnne1FRooms_ScriptPointers (scripts/SSAnne1FRooms.asm:11-40) — a generated asset already defines SSAnne8TrainerHeaders
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	def_script_pointers
; PRET| 	dw_const CheckFightingMapTrainers,              SCRIPT_SSANNE1FROOMS_DEFAULT
; PRET| 	dw_const DisplayEnemyTrainerTextAndStartBattle, SCRIPT_SSANNE1FROOMS_START_BATTLE
; PRET| 	dw_const EndTrainerBattle,                      SCRIPT_SSANNE1FROOMS_END_BATTLE
; PRET| 
; PRET| SSAnne1FRooms_TextPointers:
; PRET| 	def_text_pointers
; PRET| 	dw_const SSAnne1FRoomsGentleman1Text,    TEXT_SSANNE1FROOMS_GENTLEMAN1
; PRET| 	dw_const SSAnne1FRoomsGentleman2Text,    TEXT_SSANNE1FROOMS_GENTLEMAN2
; PRET| 	dw_const SSAnne1FRoomsYoungsterText,     TEXT_SSANNE1FROOMS_YOUNGSTER
; PRET| 	dw_const SSAnne1FRoomsCooltrainerFText,  TEXT_SSANNE1FROOMS_COOLTRAINER_F
; PRET| 	dw_const SSAnne1FRoomsGirl1Text,         TEXT_SSANNE1FROOMS_GIRL1
; PRET| 	dw_const SSAnne1FRoomsMiddleAgedManText, TEXT_SSANNE1FROOMS_MIDDLE_AGED_MAN
; PRET| 	dw_const SSAnne1FRoomsLittleGirlText,    TEXT_SSANNE1FROOMS_LITTLE_GIRL
; PRET| 	dw_const SSAnne1FRoomsWigglytuffText,    TEXT_SSANNE1FROOMS_WIGGLYTUFF
; PRET| 	dw_const SSAnne1FRoomsGirl2Text,         TEXT_SSANNE1FROOMS_GIRL2
; PRET| 	dw_const PickUpItemText,                 TEXT_SSANNE1FROOMS_TM_BODY_SLAM
; PRET| 	dw_const SSAnne1FRoomsGentleman3Text,    TEXT_SSANNE1FROOMS_GENTLEMAN3
; PRET| 
; PRET| SSAnne8TrainerHeaders:
; PRET| 	def_trainers
; PRET| SSAnne8TrainerHeader0:
; PRET| 	trainer EVENT_BEAT_SS_ANNE_8_TRAINER_0, 2, SSAnne1FRoomsGentleman1BattleText, SSAnne1FRoomsGentleman1EndBattleText, SSAnne1FRoomsGentleman1AfterBattleText
; PRET| SSAnne8TrainerHeader1:
; PRET| 	trainer EVENT_BEAT_SS_ANNE_8_TRAINER_1, 3, SSAnne1FRoomsGentleman2BattleText, SSAnne1FRoomsGentleman2EndBattleText, SSAnne1FRoomsGentleman2AfterBattleText
; PRET| SSAnne8TrainerHeader2:
; PRET| 	trainer EVENT_BEAT_SS_ANNE_8_TRAINER_2, 2, SSAnne1FRoomsYoungsterBattleText, SSAnne1FRoomsYoungsterEndBattleText, SSAnne1FRoomsYoungsterAfterBattleText
; PRET| SSAnne8TrainerHeader3:
; PRET| 	trainer EVENT_BEAT_SS_ANNE_8_TRAINER_3, 2, SSAnne1FRoomsCooltrainerFBattleText, SSAnne1FRoomsCooltrainerFEndBattleText, SSAnne1FRoomsCooltrainerFAfterBattleText
; PRET| 	db -1 ; end

SSAnne1FRoomsGentleman1Text:
    mov esi, SSAnne8TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

SSAnne1FRoomsGentleman2Text:
    mov esi, SSAnne8TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

SSAnne1FRoomsYoungsterText:
    mov esi, SSAnne8TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

SSAnne1FRoomsCooltrainerFText:
    mov esi, SSAnne8TrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

SSAnne1FRoomsWigglytuffText:
    text_far _SSAnne1FRoomsWigglytuffText

    mov al, 101
    call PlayCry
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] SSAnne1FRoomsGentleman1BattleText (scripts/SSAnne1FRooms.asm:74-139) — a generated asset already defines SSAnne1FRoomsGentleman1BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _SSAnne1FRoomsGentleman1BattleText
; PRET| 	text_end
; PRET| 
; PRET| SSAnne1FRoomsGentleman1EndBattleText:
; PRET| 	text_far _SSAnne1FRoomsGentleman1EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| SSAnne1FRoomsGentleman1AfterBattleText:
; PRET| 	text_far _SSAnne1FRoomsGentleman1AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| SSAnne1FRoomsGentleman2BattleText:
; PRET| 	text_far _SSAnne1FRoomsGentleman2BattleText
; PRET| 	text_end
; PRET| 
; PRET| SSAnne1FRoomsGentleman2EndBattleText:
; PRET| 	text_far _SSAnne1FRoomsGentleman2EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| SSAnne1FRoomsGentleman2AfterBattleText:
; PRET| 	text_far _SSAnne1FRoomsGentleman2AfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| SSAnne1FRoomsYoungsterBattleText:
; PRET| 	text_far _SSAnne1FRoomsYoungsterBattleText
; PRET| 	text_end
; PRET| 
; PRET| SSAnne1FRoomsYoungsterEndBattleText:
; PRET| 	text_far _SSAnne1FRoomsYoungsterEndBattleText
; PRET| 	text_end
; PRET| 
; PRET| SSAnne1FRoomsYoungsterAfterBattleText:
; PRET| 	text_far _SSAnne1FRoomsYoungsterAfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| SSAnne1FRoomsCooltrainerFBattleText:
; PRET| 	text_far _SSAnne1FRoomsCooltrainerFBattleText
; PRET| 	text_end
; PRET| 
; PRET| SSAnne1FRoomsCooltrainerFEndBattleText:
; PRET| 	text_far _SSAnne1FRoomsCooltrainerFEndBattleText
; PRET| 	text_end
; PRET| 
; PRET| SSAnne1FRoomsCooltrainerFAfterBattleText:
; PRET| 	text_far _SSAnne1FRoomsCooltrainerFAfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| SSAnne1FRoomsGirl1Text:
; PRET| 	text_far _SSAnne1FRoomsGirl1Text
; PRET| 	text_end
; PRET| 
; PRET| SSAnne1FRoomsMiddleAgedManText:
; PRET| 	text_far _SSAnne1FRoomsMiddleAgedManText
; PRET| 	text_end
; PRET| 
; PRET| SSAnne1FRoomsLittleGirlText:
; PRET| 	text_far _SSAnne1FRoomsLittleGirlText
; PRET| 	text_end
; PRET| 
; PRET| SSAnne1FRoomsGirl2Text:
; PRET| 	text_far _SSAnne1FRoomsGirl2Text
; PRET| 	text_end
; PRET| 
; PRET| SSAnne1FRoomsGentleman3Text:
; PRET| 	text_far _SSAnne1FRoomsGentleman3Text
; PRET| 	text_end
