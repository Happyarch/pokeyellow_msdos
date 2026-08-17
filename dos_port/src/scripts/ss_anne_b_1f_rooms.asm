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
; SSAnneB1FRooms_ScriptPointers (scripts/SSAnneB1FRooms.asm:11-44) — Tier-1 data: SSAnne10TrainerHeaders is generated into assets/trainer_headers.inc.

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
; SSAnneB1FRoomsSailor1BattleText (scripts/SSAnneB1FRooms.asm:90-163) — Tier-1 data: SSAnneB1FRoomsSailor1BattleText is generated into assets/trainer_headers.inc.
