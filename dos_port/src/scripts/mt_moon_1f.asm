; MtMoon1F.asm — translated from pret scripts/MtMoon1F.asm by dos_port/tools/sm83xlat.
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

global MtMoon1FCooltrainerF1Text
global MtMoon1FCooltrainerF2Text
global MtMoon1FHikerText
global MtMoon1FSuperNerdText
global MtMoon1FYoungster1Text
global MtMoon1FYoungster2Text
global MtMoon1FYoungster3Text
global MtMoon1F_Script
global MtMoon1TalkToTrainer

extern EnableAutoTextBoxDrawing
extern ExecuteCurMapScriptInTable
extern MtMoon1FHikerBattleText
extern MtMoon1F_ScriptPointers
extern MtMoon1TrainerHeader0
extern MtMoon1TrainerHeader1
extern MtMoon1TrainerHeader2
extern MtMoon1TrainerHeader3
extern MtMoon1TrainerHeader4
extern MtMoon1TrainerHeader5
extern MtMoon1TrainerHeader6
extern MtMoon1TrainerHeaders
extern TalkToTrainer
extern TextScriptEnd

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wMtMoon1FCurScript                             equ 0xD605

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
MtMoon1F_Script:
    call EnableAutoTextBoxDrawing
    mov esi, MtMoon1TrainerHeaders
    mov edi, MtMoon1F_ScriptPointers   ; pret: ld de, MtMoon1F_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wMtMoon1FCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wMtMoon1FCurScript], al
    ret

; MtMoon1F_ScriptPointers (scripts/MtMoon1F.asm:11-49) — not re-emitted: MtMoon1F_ScriptPointers is already defined in assets/map_script_tables.inc.

%assign event_byte -1
%assign event_byte_a -1
MtMoon1FHikerText:
    mov esi, MtMoon1TrainerHeader0
    jmp MtMoon1TalkToTrainer

%assign event_byte -1
%assign event_byte_a -1
MtMoon1FYoungster1Text:
    mov esi, MtMoon1TrainerHeader1
    jmp MtMoon1TalkToTrainer

%assign event_byte -1
%assign event_byte_a -1
MtMoon1FCooltrainerF1Text:
    mov esi, MtMoon1TrainerHeader2
    jmp MtMoon1TalkToTrainer

%assign event_byte -1
%assign event_byte_a -1
MtMoon1FSuperNerdText:
    mov esi, MtMoon1TrainerHeader3
    jmp MtMoon1TalkToTrainer

%assign event_byte -1
%assign event_byte_a -1
MtMoon1FCooltrainerF2Text:
    mov esi, MtMoon1TrainerHeader4
    jmp MtMoon1TalkToTrainer

%assign event_byte -1
%assign event_byte_a -1
MtMoon1FYoungster2Text:
    mov esi, MtMoon1TrainerHeader5
    jmp MtMoon1TalkToTrainer

%assign event_byte -1
%assign event_byte_a -1
MtMoon1FYoungster3Text:
    mov esi, MtMoon1TrainerHeader6
MtMoon1TalkToTrainer:
    call TalkToTrainer
    jmp TextScriptEnd

; MtMoon1FHikerBattleText (scripts/MtMoon1F.asm:89-174) — not re-emitted: MtMoon1FHikerBattleText is already defined in assets/trainer_headers.inc.
