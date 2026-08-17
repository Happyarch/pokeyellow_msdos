; SSAnne2FRooms.asm — translated from pret scripts/SSAnne2FRooms.asm, scripts/SSAnne2FRooms_2.asm by dos_port/tools/sm83xlat.
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


global SSAnne2FRoomsBeautyText
global SSAnne2FRoomsBrunetteGirlText
global SSAnne2FRoomsCooltrainerFText
global SSAnne2FRoomsFisherText
global SSAnne2FRoomsGentleman1Text
global SSAnne2FRoomsGentleman2Text
global SSAnne2FRoomsGentleman3Text
global SSAnne2FRoomsGentleman4Text
global SSAnne2FRoomsGentleman5Text
global SSAnne2FRoomsGrampsText
global SSAnne2FRoomsLittleBoyText
global SSAnne2FRoomsPrintBeautyText
global SSAnne2FRoomsPrintBrunetteGirlText
global SSAnne2FRoomsPrintGentleman5Text
global SSAnne2FRoomsPrintLittleBoyText
global SSAnne2FRooms_Script

extern Bankswitch   ; NOT YET DEFINED IN THE PORT
extern CheckFightingMapTrainers   ; NOT YET DEFINED IN THE PORT
extern DisableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern DisplayEnemyTrainerTextAndStartBattle   ; NOT YET DEFINED IN THE PORT
extern DisplayPokedex   ; NOT YET DEFINED IN THE PORT
extern EndTrainerBattle   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern LoadScreenTilesFromBuffer1   ; NOT YET DEFINED IN THE PORT
extern PickUpItemText   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern SSAnne2FRoomsCooltrainerFAfterBattleText   ; NOT YET DEFINED IN THE PORT
extern SSAnne2FRoomsCooltrainerFBattleText   ; NOT YET DEFINED IN THE PORT
extern SSAnne2FRoomsCooltrainerFEndBattleText   ; NOT YET DEFINED IN THE PORT
extern SSAnne2FRoomsFisherAfterBattleText   ; NOT YET DEFINED IN THE PORT
extern SSAnne2FRoomsFisherBattleText   ; NOT YET DEFINED IN THE PORT
extern SSAnne2FRoomsFisherEndBattleText   ; NOT YET DEFINED IN THE PORT
extern SSAnne2FRoomsGentleman1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern SSAnne2FRoomsGentleman1BattleText   ; NOT YET DEFINED IN THE PORT
extern SSAnne2FRoomsGentleman1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern SSAnne2FRoomsGentleman2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern SSAnne2FRoomsGentleman2BattleText   ; NOT YET DEFINED IN THE PORT
extern SSAnne2FRoomsGentleman2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern SSAnne2FRooms_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern SSAnne2FRooms_TextPointers   ; NOT YET DEFINED IN THE PORT
extern SSAnne9TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern SSAnne9TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern SSAnne9TrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern SSAnne9TrainerHeader3   ; NOT YET DEFINED IN THE PORT
extern SSAnne9TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern SaveScreenTilesToBuffer1   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern _SSAnne2FRoomsBeautyText   ; NOT YET DEFINED IN THE PORT
extern _SSAnne2FRoomsBrunetteGirlText   ; NOT YET DEFINED IN THE PORT
extern _SSAnne2FRoomsGentleman3Text   ; NOT YET DEFINED IN THE PORT
extern _SSAnne2FRoomsGentleman4Text   ; NOT YET DEFINED IN THE PORT
extern _SSAnne2FRoomsGentleman5Text   ; NOT YET DEFINED IN THE PORT
extern _SSAnne2FRoomsGrampsText   ; NOT YET DEFINED IN THE PORT
extern _SSAnne2FRoomsLittleBoyText   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_SSANNE2FROOMS_DEFAULT                   equ 0
SCRIPT_SSANNE2FROOMS_START_BATTLE              equ 1
SCRIPT_SSANNE2FROOMS_END_BATTLE                equ 2
TEXT_SSANNE2FROOMS_GENTLEMAN1                  equ 1
TEXT_SSANNE2FROOMS_FISHER                      equ 2
TEXT_SSANNE2FROOMS_GENTLEMAN2                  equ 3
TEXT_SSANNE2FROOMS_COOLTRAINER_F               equ 4
TEXT_SSANNE2FROOMS_GENTLEMAN3                  equ 5
TEXT_SSANNE2FROOMS_MAX_ETHER                   equ 6
TEXT_SSANNE2FROOMS_GENTLEMAN4                  equ 7
TEXT_SSANNE2FROOMS_GRAMPS                      equ 8
TEXT_SSANNE2FROOMS_RARE_CANDY                  equ 9
TEXT_SSANNE2FROOMS_GENTLEMAN5                  equ 10
TEXT_SSANNE2FROOMS_LITTLE_BOY                  equ 11
TEXT_SSANNE2FROOMS_BRUNETTE_GIRL               equ 12
TEXT_SSANNE2FROOMS_BEAUTY                      equ 13

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wSSAnne2FRoomsCurScript                        equ 0xD608

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

SSAnne2FRooms_Script:
    call DisableAutoTextBoxDrawing
    mov esi, SSAnne9TrainerHeaders
    mov edi, SSAnne2FRooms_ScriptPointers   ; pret: ld de, SSAnne2FRooms_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wSSAnne2FRoomsCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wSSAnne2FRoomsCurScript], al
    ret

; ---------------------------------------------------------------------------
; SSAnne2FRooms_ScriptPointers (scripts/SSAnne2FRooms.asm:11-42) — Tier-1 data: SSAnne9TrainerHeaders is generated into assets/trainer_headers.inc.

SSAnne2FRoomsGentleman1Text:
    mov esi, SSAnne9TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

SSAnne2FRoomsFisherText:
    mov esi, SSAnne9TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

SSAnne2FRoomsGentleman2Text:
    mov esi, SSAnne9TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

SSAnne2FRoomsCooltrainerFText:
    mov esi, SSAnne9TrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

SSAnne2FRoomsGentleman3Text:
    call SaveScreenTilesToBuffer1
    mov esi, .Text
    call PrintText
    call LoadScreenTilesFromBuffer1
    mov al, 132
    call DisplayPokedex
    jmp TextScriptEnd

.Text:
    text_far _SSAnne2FRoomsGentleman3Text
    text_end

SSAnne2FRoomsGentleman4Text:
    mov esi, .Text
    call PrintText
    jmp TextScriptEnd

.Text:
    text_far _SSAnne2FRoomsGentleman4Text
    text_end

SSAnne2FRoomsGrampsText:
    mov esi, .Text
    call PrintText
    jmp TextScriptEnd

.Text:
    text_far _SSAnne2FRoomsGrampsText
    text_end

SSAnne2FRoomsGentleman5Text:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call SSAnne2FRoomsPrintGentleman5Text
    jmp TextScriptEnd

SSAnne2FRoomsLittleBoyText:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call SSAnne2FRoomsPrintLittleBoyText
    jmp TextScriptEnd

SSAnne2FRoomsBrunetteGirlText:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call SSAnne2FRoomsPrintBrunetteGirlText
    jmp TextScriptEnd

SSAnne2FRoomsBeautyText:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call SSAnne2FRoomsPrintBeautyText
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; SSAnne2FRoomsGentleman1BattleText (scripts/SSAnne2FRooms.asm:123-168) — Tier-1 data: SSAnne2FRoomsGentleman1BattleText is generated into assets/trainer_headers.inc.

SSAnne2FRoomsPrintGentleman5Text:
    mov esi, .text
    call PrintText
    ret

.text:
    text_far _SSAnne2FRoomsGentleman5Text
    text_end

SSAnne2FRoomsPrintLittleBoyText:
    mov esi, .text
    call PrintText
    ret

.text:
    text_far _SSAnne2FRoomsLittleBoyText
    text_end

SSAnne2FRoomsPrintBrunetteGirlText:
    mov esi, .text
    call PrintText
    ret

.text:
    text_far _SSAnne2FRoomsBrunetteGirlText
    text_end

SSAnne2FRoomsPrintBeautyText:
    mov esi, .text
    call PrintText
    ret

.text:
    text_far _SSAnne2FRoomsBeautyText
    text_end
