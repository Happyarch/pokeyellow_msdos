; CeruleanCaveB1F.asm — translated from pret scripts/CeruleanCaveB1F.asm by dos_port/tools/sm83xlat.
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
%include "assets/script_constants.inc"

; Map script-pointer tables are DEFINED once, by the single carrier
; src/data/map_script_tables.asm. Declare what this script uses; do NOT %include
; assets/map_script_tables.inc here — the asset DEFINES every table, so an include
; makes them duplicate globals as soon as a second script links.
extern CeruleanCaveB1F_ScriptPointers ; assets/map_script_tables.inc
; Trainer headers and battle text are DEFINED once, by the single carrier
; src/data/trainer_headers.asm. Declare what this script uses; do NOT %include
; assets/trainer_headers.inc here — the asset DEFINES all 1302 symbols, so an
; include makes every one of them a duplicate global the moment a second script
; links. (That is what kept 202 link-ready scripts out of the build.)
extern CeruleanCaveB1FTrainerHeaders ; assets/trainer_headers.inc
extern MewtwoBattleText              ; assets/trainer_headers.inc
extern MewtwoTrainerHeader           ; assets/trainer_headers.inc

global CeruleanCaveB1FMewtwoText
global CeruleanCaveB1F_Script

extern CeruleanCaveB1FTrainerHeaders
extern CeruleanCaveB1F_ScriptPointers
extern EnableAutoTextBoxDrawing
extern ExecuteCurMapScriptInTable
extern MewtwoBattleText
extern MewtwoTrainerHeader
extern PlayCry
extern TalkToTrainer
extern TextScriptEnd
extern WaitForSoundToFinish

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
CeruleanCaveB1F_Script:
    call EnableAutoTextBoxDrawing
    mov esi, CeruleanCaveB1FTrainerHeaders
    mov edi, CeruleanCaveB1F_ScriptPointers   ; pret: ld de, CeruleanCaveB1F_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wCeruleanCaveB1FCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wCeruleanCaveB1FCurScript], al
    ret

; CeruleanCaveB1F_ScriptPointers (scripts/CeruleanCaveB1F.asm:11-28) — not re-emitted: CeruleanCaveB1F_ScriptPointers is already defined in assets/map_script_tables.inc.

%assign event_byte -1
%assign event_byte_a -1
CeruleanCaveB1FMewtwoText:
    mov esi, MewtwoTrainerHeader
    call TalkToTrainer
    jmp TextScriptEnd

; MewtwoBattleText (scripts/CeruleanCaveB1F.asm:37-37) — not re-emitted: MewtwoBattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
    mov al, MEWTWO
    call PlayCry
    call WaitForSoundToFinish
    jmp TextScriptEnd
