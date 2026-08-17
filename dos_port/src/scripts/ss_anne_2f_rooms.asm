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

%include "assets/trainer_headers.inc"

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

extern Bankswitch
extern DisableAutoTextBoxDrawing
extern DisplayPokedex   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable
extern LoadScreenTilesFromBuffer1
extern PrintText
extern SSAnne2FRoomsGentleman1BattleText
extern SSAnne2FRooms_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern SSAnne9TrainerHeader0
extern SSAnne9TrainerHeader1
extern SSAnne9TrainerHeader2
extern SSAnne9TrainerHeader3
extern SSAnne9TrainerHeaders
extern SaveScreenTilesToBuffer1
extern TalkToTrainer
extern TextScriptEnd
extern _SSAnne2FRoomsBeautyText   ; NOT YET DEFINED IN THE PORT
extern _SSAnne2FRoomsBrunetteGirlText   ; NOT YET DEFINED IN THE PORT
extern _SSAnne2FRoomsGentleman3Text   ; NOT YET DEFINED IN THE PORT
extern _SSAnne2FRoomsGentleman4Text   ; NOT YET DEFINED IN THE PORT
extern _SSAnne2FRoomsGentleman5Text   ; NOT YET DEFINED IN THE PORT
extern _SSAnne2FRoomsGrampsText   ; NOT YET DEFINED IN THE PORT
extern _SSAnne2FRoomsLittleBoyText   ; NOT YET DEFINED IN THE PORT

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wSSAnne2FRoomsCurScript                        equ 0xD608

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
SSAnne2FRooms_Script:
    call DisableAutoTextBoxDrawing
    mov esi, SSAnne9TrainerHeaders
    mov edi, SSAnne2FRooms_ScriptPointers   ; pret: ld de, SSAnne2FRooms_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wSSAnne2FRoomsCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wSSAnne2FRoomsCurScript], al
    ret

; SSAnne2FRooms_ScriptPointers (scripts/SSAnne2FRooms.asm:11-42) — not re-emitted: SSAnne9TrainerHeaders is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
SSAnne2FRoomsGentleman1Text:
    mov esi, SSAnne9TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
SSAnne2FRoomsFisherText:
    mov esi, SSAnne9TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
SSAnne2FRoomsGentleman2Text:
    mov esi, SSAnne9TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
SSAnne2FRoomsCooltrainerFText:
    mov esi, SSAnne9TrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
SSAnne2FRoomsGentleman3Text:
    call SaveScreenTilesToBuffer1
    mov esi, .Text
    call PrintText
    call LoadScreenTilesFromBuffer1
    mov al, 132
    call DisplayPokedex
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.Text:
    text_far _SSAnne2FRoomsGentleman3Text
    text_end

%assign event_byte -1
%assign event_byte_a -1
SSAnne2FRoomsGentleman4Text:
    mov esi, .Text
    call PrintText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.Text:
    text_far _SSAnne2FRoomsGentleman4Text
    text_end

%assign event_byte -1
%assign event_byte_a -1
SSAnne2FRoomsGrampsText:
    mov esi, .Text
    call PrintText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.Text:
    text_far _SSAnne2FRoomsGrampsText
    text_end

%assign event_byte -1
%assign event_byte_a -1
SSAnne2FRoomsGentleman5Text:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call SSAnne2FRoomsPrintGentleman5Text
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
SSAnne2FRoomsLittleBoyText:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call SSAnne2FRoomsPrintLittleBoyText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
SSAnne2FRoomsBrunetteGirlText:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call SSAnne2FRoomsPrintBrunetteGirlText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
SSAnne2FRoomsBeautyText:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call SSAnne2FRoomsPrintBeautyText
    jmp TextScriptEnd

; SSAnne2FRoomsGentleman1BattleText (scripts/SSAnne2FRooms.asm:123-168) — not re-emitted: SSAnne2FRoomsGentleman1BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
SSAnne2FRoomsPrintGentleman5Text:
    mov esi, .text
    call PrintText
    ret

%assign event_byte -1
%assign event_byte_a -1
.text:
    text_far _SSAnne2FRoomsGentleman5Text
    text_end

%assign event_byte -1
%assign event_byte_a -1
SSAnne2FRoomsPrintLittleBoyText:
    mov esi, .text
    call PrintText
    ret

%assign event_byte -1
%assign event_byte_a -1
.text:
    text_far _SSAnne2FRoomsLittleBoyText
    text_end

%assign event_byte -1
%assign event_byte_a -1
SSAnne2FRoomsPrintBrunetteGirlText:
    mov esi, .text
    call PrintText
    ret

%assign event_byte -1
%assign event_byte_a -1
.text:
    text_far _SSAnne2FRoomsBrunetteGirlText
    text_end

%assign event_byte -1
%assign event_byte_a -1
SSAnne2FRoomsPrintBeautyText:
    mov esi, .text
    call PrintText
    ret

%assign event_byte -1
%assign event_byte_a -1
.text:
    text_far _SSAnne2FRoomsBeautyText
    text_end
