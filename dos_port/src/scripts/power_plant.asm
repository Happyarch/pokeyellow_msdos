; PowerPlant.asm — translated from pret scripts/PowerPlant.asm by dos_port/tools/sm83xlat.
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
extern PowerPlant_ScriptPointers ; assets/map_script_tables.inc
; Trainer headers and battle text are DEFINED once, by the single carrier
; src/data/trainer_headers.asm. Declare what this script uses; do NOT %include
; assets/trainer_headers.inc here — the asset DEFINES all 1302 symbols, so an
; include makes every one of them a duplicate global the moment a second script
; links. (That is what kept 202 link-ready scripts out of the build.)
extern PowerPlantTrainerHeaders    ; assets/trainer_headers.inc
extern PowerPlantVoltorbBattleText ; assets/trainer_headers.inc
extern Voltorb0TrainerHeader       ; assets/trainer_headers.inc
extern Voltorb1TrainerHeader       ; assets/trainer_headers.inc
extern Voltorb2TrainerHeader       ; assets/trainer_headers.inc
extern Voltorb3TrainerHeader       ; assets/trainer_headers.inc
extern Voltorb4TrainerHeader       ; assets/trainer_headers.inc
extern Voltorb5TrainerHeader       ; assets/trainer_headers.inc
extern Voltorb6TrainerHeader       ; assets/trainer_headers.inc
extern Voltorb7TrainerHeader       ; assets/trainer_headers.inc
extern ZapdosTrainerHeader         ; assets/trainer_headers.inc

global PowerPlantElectrode1Text
global PowerPlantElectrode2Text
global PowerPlantInitBattleScript
global PowerPlantVoltorb1Text
global PowerPlantVoltorb2Text
global PowerPlantVoltorb3Text
global PowerPlantVoltorb4Text
global PowerPlantVoltorb5Text
global PowerPlantVoltorb6Text
global PowerPlantZapdosText
global PowerPlant_Script

extern EnableAutoTextBoxDrawing
extern ExecuteCurMapScriptInTable
extern PlayCry
extern PowerPlantTrainerHeaders
extern PowerPlantVoltorbBattleText
extern PowerPlant_ScriptPointers
extern TalkToTrainer
extern TextScriptEnd
extern Voltorb0TrainerHeader
extern Voltorb1TrainerHeader
extern Voltorb2TrainerHeader
extern Voltorb3TrainerHeader
extern Voltorb4TrainerHeader
extern Voltorb5TrainerHeader
extern Voltorb6TrainerHeader
extern Voltorb7TrainerHeader
extern WaitForSoundToFinish
extern ZapdosTrainerHeader

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
PowerPlant_Script:
    call EnableAutoTextBoxDrawing
    mov esi, PowerPlantTrainerHeaders
    mov edi, PowerPlant_ScriptPointers   ; pret: ld de, PowerPlant_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wPowerPlantCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wPowerPlantCurScript], al
    ret

; PowerPlant_ScriptPointers (scripts/PowerPlant.asm:11-53) — not re-emitted: PowerPlant_ScriptPointers is already defined in assets/map_script_tables.inc.

%assign event_byte -1
%assign event_byte_a -1
PowerPlantInitBattleScript:
    call TalkToTrainer
    mov al, [ebp + wCurMapScript]
    mov [ebp + wPowerPlantCurScript], al
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
PowerPlantVoltorb1Text:
    mov esi, Voltorb0TrainerHeader
    jmp PowerPlantInitBattleScript

%assign event_byte -1
%assign event_byte_a -1
PowerPlantVoltorb2Text:
    mov esi, Voltorb1TrainerHeader
    jmp PowerPlantInitBattleScript

%assign event_byte -1
%assign event_byte_a -1
PowerPlantVoltorb3Text:
    mov esi, Voltorb2TrainerHeader
    jmp PowerPlantInitBattleScript

%assign event_byte -1
%assign event_byte_a -1
PowerPlantElectrode1Text:
    mov esi, Voltorb3TrainerHeader
    jmp PowerPlantInitBattleScript

%assign event_byte -1
%assign event_byte_a -1
PowerPlantVoltorb4Text:
    mov esi, Voltorb4TrainerHeader
    jmp PowerPlantInitBattleScript

%assign event_byte -1
%assign event_byte_a -1
PowerPlantVoltorb5Text:
    mov esi, Voltorb5TrainerHeader
    jmp PowerPlantInitBattleScript

%assign event_byte -1
%assign event_byte_a -1
PowerPlantElectrode2Text:
    mov esi, Voltorb6TrainerHeader
    jmp PowerPlantInitBattleScript

%assign event_byte -1
%assign event_byte_a -1
PowerPlantVoltorb6Text:
    mov esi, Voltorb7TrainerHeader
    jmp PowerPlantInitBattleScript

%assign event_byte -1
%assign event_byte_a -1
PowerPlantZapdosText:
    mov esi, ZapdosTrainerHeader
    jmp PowerPlantInitBattleScript

; PowerPlantVoltorbBattleText (scripts/PowerPlant.asm:107-111) — not re-emitted: PowerPlantVoltorbBattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
    mov al, ZAPDOS
    call PlayCry
    call WaitForSoundToFinish
    jmp TextScriptEnd
