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

%include "assets/trainer_headers.inc"

global SSAnneB1FRoomsFisherText
global SSAnneB1FRoomsMachokeText
global SSAnneB1FRoomsSailor1Text
global SSAnneB1FRoomsSailor2Text
global SSAnneB1FRoomsSailor3Text
global SSAnneB1FRoomsSailor4Text
global SSAnneB1FRoomsSailor5Text
global SSAnneB1FRooms_Script

extern EnableAutoTextBoxDrawing
extern ExecuteCurMapScriptInTable
extern PlayCry
extern SSAnne10TrainerHeader0
extern SSAnne10TrainerHeader1
extern SSAnne10TrainerHeader2
extern SSAnne10TrainerHeader3
extern SSAnne10TrainerHeader4
extern SSAnne10TrainerHeader5
extern SSAnne10TrainerHeaders
extern SSAnneB1FRoomsSailor1BattleText
extern SSAnneB1FRooms_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer
extern TextScriptEnd
extern _SSAnneB1FRoomsMachokeText   ; NOT YET DEFINED IN THE PORT

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wSSAnneB1FRoomsCurScript                       equ 0xD628

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
SSAnneB1FRooms_Script:
    call EnableAutoTextBoxDrawing
    mov esi, SSAnne10TrainerHeaders
    mov edi, SSAnneB1FRooms_ScriptPointers   ; pret: ld de, SSAnneB1FRooms_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wSSAnneB1FRoomsCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wSSAnneB1FRoomsCurScript], al
    ret

; SSAnneB1FRooms_ScriptPointers (scripts/SSAnneB1FRooms.asm:11-44) — not re-emitted: SSAnne10TrainerHeaders is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
SSAnneB1FRoomsSailor1Text:
    mov esi, SSAnne10TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
SSAnneB1FRoomsSailor2Text:
    mov esi, SSAnne10TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
SSAnneB1FRoomsSailor3Text:
    mov esi, SSAnne10TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
SSAnneB1FRoomsSailor4Text:
    mov esi, SSAnne10TrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
SSAnneB1FRoomsSailor5Text:
    mov esi, SSAnne10TrainerHeader4
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
SSAnneB1FRoomsFisherText:
    mov esi, SSAnne10TrainerHeader5
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
SSAnneB1FRoomsMachokeText:
    text_far _SSAnneB1FRoomsMachokeText

%assign event_byte -1
%assign event_byte_a -1
    mov al, 41
    call PlayCry
    jmp TextScriptEnd

; SSAnneB1FRoomsSailor1BattleText (scripts/SSAnneB1FRooms.asm:90-163) — not re-emitted: SSAnneB1FRoomsSailor1BattleText is already defined in assets/trainer_headers.inc.
