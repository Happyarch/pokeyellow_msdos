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

%include "assets/trainer_headers.inc"

global SSAnne1FRoomsCooltrainerFText
global SSAnne1FRoomsGentleman1Text
global SSAnne1FRoomsGentleman2Text
global SSAnne1FRoomsWigglytuffText
global SSAnne1FRoomsYoungsterText
global SSAnne1FRooms_Script

extern EnableAutoTextBoxDrawing
extern ExecuteCurMapScriptInTable
extern PlayCry
extern SSAnne1FRoomsGentleman1BattleText   ; NOT YET DEFINED IN THE PORT
extern SSAnne1FRooms_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern SSAnne8TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern SSAnne8TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern SSAnne8TrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern SSAnne8TrainerHeader3   ; NOT YET DEFINED IN THE PORT
extern SSAnne8TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer
extern TextScriptEnd
extern _SSAnne1FRoomsWigglytuffText   ; NOT YET DEFINED IN THE PORT

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wSSAnne1FRoomsCurScript                        equ 0xD607

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
SSAnne1FRooms_Script:
    call EnableAutoTextBoxDrawing
    mov esi, SSAnne8TrainerHeaders
    mov edi, SSAnne1FRooms_ScriptPointers   ; pret: ld de, SSAnne1FRooms_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wSSAnne1FRoomsCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wSSAnne1FRoomsCurScript], al
    ret

; SSAnne1FRooms_ScriptPointers (scripts/SSAnne1FRooms.asm:11-40) — not re-emitted: SSAnne8TrainerHeaders is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
SSAnne1FRoomsGentleman1Text:
    mov esi, SSAnne8TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
SSAnne1FRoomsGentleman2Text:
    mov esi, SSAnne8TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
SSAnne1FRoomsYoungsterText:
    mov esi, SSAnne8TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
SSAnne1FRoomsCooltrainerFText:
    mov esi, SSAnne8TrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
SSAnne1FRoomsWigglytuffText:
    text_far _SSAnne1FRoomsWigglytuffText

%assign event_byte -1
%assign event_byte_a -1
    mov al, 101
    call PlayCry
    jmp TextScriptEnd

; SSAnne1FRoomsGentleman1BattleText (scripts/SSAnne1FRooms.asm:74-139) — not re-emitted: SSAnne1FRoomsGentleman1BattleText is already defined in assets/trainer_headers.inc.
