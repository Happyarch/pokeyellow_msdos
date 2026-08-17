; Route20.asm — translated from pret scripts/Route20.asm by dos_port/tools/sm83xlat.
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


global Route20CooltrainerMText
global Route20Swimmer1Text
global Route20Swimmer2Text
global Route20Swimmer3Text
global Route20Swimmer4Text
global Route20Swimmer5Text
global Route20Swimmer6Text
global Route20Swimmer7Text
global Route20Swimmer8Text
global Route20Swimmer9Text
global Route20_Script

extern CheckFightingMapTrainers   ; NOT YET DEFINED IN THE PORT
extern DisplayEnemyTrainerTextAndStartBattle   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EndTrainerBattle   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern HideObject   ; NOT YET DEFINED IN THE PORT
extern Route20BoulderScript   ; NOT YET DEFINED IN THE PORT
extern Route20CooltrainerMAfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route20CooltrainerMBattleText   ; NOT YET DEFINED IN THE PORT
extern Route20CooltrainerMEndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route20HideObjectScript   ; NOT YET DEFINED IN THE PORT
extern Route20SeafoamIslandsSignText   ; NOT YET DEFINED IN THE PORT
extern Route20ShowObjectScript   ; NOT YET DEFINED IN THE PORT
extern Route20Swimmer1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route20Swimmer1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route20Swimmer1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route20Swimmer2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route20Swimmer2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route20Swimmer2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route20Swimmer3AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route20Swimmer3BattleText   ; NOT YET DEFINED IN THE PORT
extern Route20Swimmer3EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route20Swimmer4AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route20Swimmer4BattleText   ; NOT YET DEFINED IN THE PORT
extern Route20Swimmer4EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route20Swimmer5AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route20Swimmer5BattleText   ; NOT YET DEFINED IN THE PORT
extern Route20Swimmer5EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route20Swimmer6AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route20Swimmer6BattleText   ; NOT YET DEFINED IN THE PORT
extern Route20Swimmer6EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route20Swimmer7AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route20Swimmer7BattleText   ; NOT YET DEFINED IN THE PORT
extern Route20Swimmer7EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route20Swimmer8AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route20Swimmer8BattleText   ; NOT YET DEFINED IN THE PORT
extern Route20Swimmer8EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route20Swimmer9AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route20Swimmer9BattleText   ; NOT YET DEFINED IN THE PORT
extern Route20Swimmer9EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route20TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern Route20TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern Route20TrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern Route20TrainerHeader3   ; NOT YET DEFINED IN THE PORT
extern Route20TrainerHeader4   ; NOT YET DEFINED IN THE PORT
extern Route20TrainerHeader5   ; NOT YET DEFINED IN THE PORT
extern Route20TrainerHeader6   ; NOT YET DEFINED IN THE PORT
extern Route20TrainerHeader7   ; NOT YET DEFINED IN THE PORT
extern Route20TrainerHeader8   ; NOT YET DEFINED IN THE PORT
extern Route20TrainerHeader9   ; NOT YET DEFINED IN THE PORT
extern Route20TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern Route20_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern Route20_TextPointers   ; NOT YET DEFINED IN THE PORT
extern ShowObject   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_ROUTE20_DEFAULT                         equ 0
SCRIPT_ROUTE20_START_BATTLE                    equ 1
SCRIPT_ROUTE20_END_BATTLE                      equ 2
TEXT_ROUTE20_SWIMMER1                          equ 1
TEXT_ROUTE20_SWIMMER2                          equ 2
TEXT_ROUTE20_SWIMMER3                          equ 3
TEXT_ROUTE20_SWIMMER4                          equ 4
TEXT_ROUTE20_SWIMMER5                          equ 5
TEXT_ROUTE20_SWIMMER6                          equ 6
TEXT_ROUTE20_COOLTRAINER_M                     equ 7
TEXT_ROUTE20_SWIMMER7                          equ 8
TEXT_ROUTE20_SWIMMER8                          equ 9
TEXT_ROUTE20_SWIMMER9                          equ 10
TEXT_ROUTE20_SEAFOAM_ISLANDS_WEST_SIGN         equ 11
TEXT_ROUTE20_SEAFOAM_ISLANDS_EAST_SIGN         equ 12

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wRoute20CurScript                              equ 0xD627

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

Route20_Script:
    CheckAndResetEvent EVENT_IN_SEAFOAM_ISLANDS
    jz .sk_3
        call Route20BoulderScript
.sk_3:
    call EnableAutoTextBoxDrawing
    mov esi, Route20TrainerHeaders
    mov edi, Route20_ScriptPointers   ; pret: ld de, Route20_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wRoute20CurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wRoute20CurScript], al
    ret

; ---------------------------------------------------------------------------
; BAIL[pointer-domain-unknown] Route20BoulderScript (scripts/Route20.asm:13-27) — at scripts/Route20.asm:21: HL domain is top at a dereference
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckBothEventsSet EVENT_SEAFOAM3_BOULDER1_DOWN_HOLE, EVENT_SEAFOAM3_BOULDER2_DOWN_HOLE
; PRET| 	jr z, .next_boulder_check
; PRET| 	ld a, TOGGLE_SEAFOAM_ISLANDS_1F_BOULDER_1
; PRET| 	call Route20ShowObjectScript
; PRET| 	ld a, TOGGLE_SEAFOAM_ISLANDS_1F_BOULDER_2
; PRET| 	call Route20ShowObjectScript
; PRET| 	ld hl, .ToggleableObjectIDs
; PRET| .hide_toggleable_objects
; PRET| 	ld a, [hli]
; PRET| 	cp $ff
; PRET| 	jr z, .next_boulder_check
; PRET| 	push hl
; PRET| 	call Route20HideObjectScript
; PRET| 	pop hl
; PRET| 	jr .hide_toggleable_objects

.ToggleableObjectIDs:
    db 225
    db 226
    db 227
    db 228
    db 231
    db 232
    db -1

.next_boulder_check:
    CheckBothEventsSet EVENT_SEAFOAM4_BOULDER1_DOWN_HOLE, EVENT_SEAFOAM4_BOULDER2_DOWN_HOLE
    jnz .nr_40
        ret
.nr_40:
    mov al, 229
    call Route20ShowObjectScript
    mov al, 230
    call Route20ShowObjectScript
    mov al, 233
    call Route20HideObjectScript
    mov al, 234
    call Route20HideObjectScript
    ret

; ---------------------------------------------------------------------------
; BAIL[predef-leaves-id-in-a] Route20ShowObjectScript (scripts/Route20.asm:52-53) — at scripts/Route20.asm:53: predef_jump ShowObject
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld [wToggleableObjectIndex], a
; PRET| 	predef_jump ShowObject

; ---------------------------------------------------------------------------
; BAIL[predef-leaves-id-in-a] Route20HideObjectScript (scripts/Route20.asm:56-57) — at scripts/Route20.asm:57: predef_jump HideObject
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld [wToggleableObjectIndex], a
; PRET| 	predef_jump HideObject

; ---------------------------------------------------------------------------
; Route20_ScriptPointers (scripts/Route20.asm:60-102) — Tier-1 data: Route20TrainerHeaders is generated into assets/trainer_headers.inc.

Route20Swimmer1Text:
    mov esi, Route20TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

Route20Swimmer2Text:
    mov esi, Route20TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

Route20Swimmer3Text:
    mov esi, Route20TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

Route20Swimmer4Text:
    mov esi, Route20TrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

Route20Swimmer5Text:
    mov esi, Route20TrainerHeader4
    call TalkToTrainer
    jmp TextScriptEnd

Route20Swimmer6Text:
    mov esi, Route20TrainerHeader5
    call TalkToTrainer
    jmp TextScriptEnd

Route20CooltrainerMText:
    mov esi, Route20TrainerHeader6
    call TalkToTrainer
    jmp TextScriptEnd

Route20Swimmer7Text:
    mov esi, Route20TrainerHeader7
    call TalkToTrainer
    jmp TextScriptEnd

Route20Swimmer8Text:
    mov esi, Route20TrainerHeader8
    call TalkToTrainer
    jmp TextScriptEnd

Route20Swimmer9Text:
    mov esi, Route20TrainerHeader9
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; Route20Swimmer1BattleText (scripts/Route20.asm:165-286) — Tier-1 data: Route20Swimmer1BattleText is generated into assets/trainer_headers.inc.
