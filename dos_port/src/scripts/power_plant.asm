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

extern CheckFightingMapTrainers   ; NOT YET DEFINED IN THE PORT
extern DisplayEnemyTrainerTextAndStartBattle   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EndTrainerBattle   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern PickUpItemText   ; NOT YET DEFINED IN THE PORT
extern PlayCry   ; NOT YET DEFINED IN THE PORT
extern PowerPlantTrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern PowerPlantVoltorbBattleText   ; NOT YET DEFINED IN THE PORT
extern PowerPlantZapdosBattleText   ; NOT YET DEFINED IN THE PORT
extern PowerPlant_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern PowerPlant_TextPointers   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern Voltorb0TrainerHeader   ; NOT YET DEFINED IN THE PORT
extern Voltorb1TrainerHeader   ; NOT YET DEFINED IN THE PORT
extern Voltorb2TrainerHeader   ; NOT YET DEFINED IN THE PORT
extern Voltorb3TrainerHeader   ; NOT YET DEFINED IN THE PORT
extern Voltorb4TrainerHeader   ; NOT YET DEFINED IN THE PORT
extern Voltorb5TrainerHeader   ; NOT YET DEFINED IN THE PORT
extern Voltorb6TrainerHeader   ; NOT YET DEFINED IN THE PORT
extern Voltorb7TrainerHeader   ; NOT YET DEFINED IN THE PORT
extern WaitForSoundToFinish   ; NOT YET DEFINED IN THE PORT
extern ZapdosTrainerHeader   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_POWERPLANT_DEFAULT                      equ 0
SCRIPT_POWERPLANT_START_BATTLE                 equ 1
SCRIPT_POWERPLANT_END_BATTLE                   equ 2
TEXT_POWERPLANT_VOLTORB1                       equ 1
TEXT_POWERPLANT_VOLTORB2                       equ 2
TEXT_POWERPLANT_VOLTORB3                       equ 3
TEXT_POWERPLANT_ELECTRODE1                     equ 4
TEXT_POWERPLANT_VOLTORB4                       equ 5
TEXT_POWERPLANT_VOLTORB5                       equ 6
TEXT_POWERPLANT_ELECTRODE2                     equ 7
TEXT_POWERPLANT_VOLTORB6                       equ 8
TEXT_POWERPLANT_ZAPDOS                         equ 9
TEXT_POWERPLANT_CARBOS                         equ 10
TEXT_POWERPLANT_HP_UP                          equ 11
TEXT_POWERPLANT_RARE_CANDY                     equ 12
TEXT_POWERPLANT_TM_THUNDER                     equ 13
TEXT_POWERPLANT_TM_REFLECT                     equ 14

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wPowerPlantCurScript                           equ 0xD662

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

PowerPlant_Script:
    call EnableAutoTextBoxDrawing
    mov esi, PowerPlantTrainerHeaders
    mov edi, PowerPlant_ScriptPointers   ; pret: ld de, PowerPlant_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wPowerPlantCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wPowerPlantCurScript], al
    ret

; ---------------------------------------------------------------------------
; PowerPlant_ScriptPointers (scripts/PowerPlant.asm:11-53) — Tier-1 data: PowerPlant_ScriptPointers is generated into assets/map_script_tables.inc.

PowerPlantInitBattleScript:
    call TalkToTrainer
    mov al, [ebp + wCurMapScript]
    mov [ebp + wPowerPlantCurScript], al
    jmp TextScriptEnd

PowerPlantVoltorb1Text:
    mov esi, Voltorb0TrainerHeader
    jmp PowerPlantInitBattleScript

PowerPlantVoltorb2Text:
    mov esi, Voltorb1TrainerHeader
    jmp PowerPlantInitBattleScript

PowerPlantVoltorb3Text:
    mov esi, Voltorb2TrainerHeader
    jmp PowerPlantInitBattleScript

PowerPlantElectrode1Text:
    mov esi, Voltorb3TrainerHeader
    jmp PowerPlantInitBattleScript

PowerPlantVoltorb4Text:
    mov esi, Voltorb4TrainerHeader
    jmp PowerPlantInitBattleScript

PowerPlantVoltorb5Text:
    mov esi, Voltorb5TrainerHeader
    jmp PowerPlantInitBattleScript

PowerPlantElectrode2Text:
    mov esi, Voltorb6TrainerHeader
    jmp PowerPlantInitBattleScript

PowerPlantVoltorb6Text:
    mov esi, Voltorb7TrainerHeader
    jmp PowerPlantInitBattleScript

PowerPlantZapdosText:
    mov esi, ZapdosTrainerHeader
    jmp PowerPlantInitBattleScript

; ---------------------------------------------------------------------------
; PowerPlantVoltorbBattleText (scripts/PowerPlant.asm:107-111) — Tier-1 data: PowerPlantVoltorbBattleText is generated into assets/trainer_headers.inc.

    mov al, 75
    call PlayCry
    call WaitForSoundToFinish
    jmp TextScriptEnd
