; Route25.asm — translated from pret scripts/Route25.asm by dos_port/tools/sm83xlat.
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


global Route25CooltrainerF1Text
global Route25CooltrainerF2Text
global Route25CooltrainerMText
global Route25Hiker1Text
global Route25Hiker2Text
global Route25Hiker3Text
global Route25Youngster1Text
global Route25Youngster2Text
global Route25Youngster3Text
global Route25_Script

extern CheckFightingMapTrainers   ; NOT YET DEFINED IN THE PORT
extern DisplayEnemyTrainerTextAndStartBattle   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EndTrainerBattle   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern HideObject   ; NOT YET DEFINED IN THE PORT
extern PickUpItemText   ; NOT YET DEFINED IN THE PORT
extern Route25BillSignText   ; NOT YET DEFINED IN THE PORT
extern Route25CooltrainerF1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route25CooltrainerF1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route25CooltrainerF1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route25CooltrainerF2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route25CooltrainerF2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route25CooltrainerF2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route25CooltrainerMAfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route25CooltrainerMBattleText   ; NOT YET DEFINED IN THE PORT
extern Route25CooltrainerMEndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route25Hiker1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route25Hiker1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route25Hiker1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route25Hiker2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route25Hiker2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route25Hiker2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route25Hiker3AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route25Hiker3BattleText   ; NOT YET DEFINED IN THE PORT
extern Route25Hiker3EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route25ToggleBillsScript   ; NOT YET DEFINED IN THE PORT
extern Route25TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern Route25TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern Route25TrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern Route25TrainerHeader3   ; NOT YET DEFINED IN THE PORT
extern Route25TrainerHeader4   ; NOT YET DEFINED IN THE PORT
extern Route25TrainerHeader5   ; NOT YET DEFINED IN THE PORT
extern Route25TrainerHeader6   ; NOT YET DEFINED IN THE PORT
extern Route25TrainerHeader7   ; NOT YET DEFINED IN THE PORT
extern Route25TrainerHeader8   ; NOT YET DEFINED IN THE PORT
extern Route25TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern Route25Youngster1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route25Youngster1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route25Youngster1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route25Youngster2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route25Youngster2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route25Youngster2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route25Youngster3AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route25Youngster3BattleText   ; NOT YET DEFINED IN THE PORT
extern Route25Youngster3EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route25_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern Route25_TextPointers   ; NOT YET DEFINED IN THE PORT
extern ShowObject   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_ROUTE25_DEFAULT                         equ 0
SCRIPT_ROUTE25_START_BATTLE                    equ 1
SCRIPT_ROUTE25_END_BATTLE                      equ 2
TEXT_ROUTE25_YOUNGSTER1                        equ 1
TEXT_ROUTE25_YOUNGSTER2                        equ 2
TEXT_ROUTE25_COOLTRAINER_M                     equ 3
TEXT_ROUTE25_COOLTRAINER_F1                    equ 4
TEXT_ROUTE25_YOUNGSTER3                        equ 5
TEXT_ROUTE25_COOLTRAINER_F2                    equ 6
TEXT_ROUTE25_HIKER1                            equ 7
TEXT_ROUTE25_HIKER2                            equ 8
TEXT_ROUTE25_HIKER3                            equ 9
TEXT_ROUTE25_TM_SEISMIC_TOSS                   equ 10
TEXT_ROUTE25_BILL_SIGN                         equ 11

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wBillsHouseCurScript                           equ 0xD660
wPikachuMapScriptFlags                         equ 0xD492
wRoute25CurScript                              equ 0xD602

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

Route25_Script:
    call EnableAutoTextBoxDrawing
    mov esi, Route25TrainerHeaders
    mov edi, Route25_ScriptPointers   ; pret: ld de, Route25_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wRoute25CurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wRoute25CurScript], al
    call Route25ToggleBillsScript
    ret

; ---------------------------------------------------------------------------
; BAIL[event-byte-assembly-state] Route25ToggleBillsScript (scripts/Route25.asm:12-31) — at scripts/Route25.asm:25: CheckEventReuseHL EVENT_MET_BILL_2
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, wPikachuMapScriptFlags
; PRET| 	res BIT_PIKACHU_MAP_2, [hl]
; PRET| 	res BIT_PIKACHU_MAP_3, [hl]
; PRET| 	res BIT_PIKACHU_MAP_4, [hl]
; PRET| 	res BIT_PIKACHU_MAP_SCRIPT_ACTIVE, [hl]
; PRET| 	xor a
; PRET| 	ld [wBillsHouseCurScript], a
; PRET| 	ld hl, wCurrentMapScriptFlags
; PRET| 	bit BIT_CUR_MAP_LOADED_2, [hl]
; PRET| 	res BIT_CUR_MAP_LOADED_2, [hl]
; PRET| 	ret z
; PRET| 	CheckEventHL EVENT_LEFT_BILLS_HOUSE_AFTER_HELPING
; PRET| 	ret nz
; PRET| 	CheckEventReuseHL EVENT_MET_BILL_2
; PRET| 	jr nz, .met_bill
; PRET| 	ResetEventReuseHL EVENT_BILL_SAID_USE_CELL_SEPARATOR
; PRET| 	ld a, TOGGLE_BILL_POKEMON
; PRET| 	ld [wToggleableObjectIndex], a
; PRET| 	predef ShowObject
; PRET| 	jr .done

; ---------------------------------------------------------------------------
; BAIL[event-byte-assembly-state] Route25ToggleBillsScript.met_bill (scripts/Route25.asm:33-46) — at scripts/Route25.asm:33: CheckEventAfterBranchReuseHL EVENT_GOT_SS_TICKET, EVENT_MET_BILL_2
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEventAfterBranchReuseHL EVENT_GOT_SS_TICKET, EVENT_MET_BILL_2
; PRET| 	jr z, .done
; PRET| 	SetEventReuseHL EVENT_LEFT_BILLS_HOUSE_AFTER_HELPING
; PRET| 	ld a, TOGGLE_NUGGET_BRIDGE_GUY
; PRET| 	ld [wToggleableObjectIndex], a
; PRET| 	predef HideObject
; PRET| 	ld a, TOGGLE_BILL_1
; PRET| 	ld [wToggleableObjectIndex], a
; PRET| 	predef HideObject
; PRET| 	ld a, TOGGLE_BILL_2
; PRET| 	ld [wToggleableObjectIndex], a
; PRET| 	predef ShowObject
; PRET| .done
; PRET| 	ret

; ---------------------------------------------------------------------------
; Route25_ScriptPointers (scripts/Route25.asm:49-88) — Tier-1 data: Route25TrainerHeaders is generated into assets/trainer_headers.inc.

Route25Youngster1Text:
    mov esi, Route25TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

Route25Youngster2Text:
    mov esi, Route25TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

Route25CooltrainerMText:
    mov esi, Route25TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

Route25CooltrainerF1Text:
    mov esi, Route25TrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

Route25Youngster3Text:
    mov esi, Route25TrainerHeader4
    call TalkToTrainer
    jmp TextScriptEnd

Route25CooltrainerF2Text:
    mov esi, Route25TrainerHeader5
    call TalkToTrainer
    jmp TextScriptEnd

Route25Hiker1Text:
    mov esi, Route25TrainerHeader6
    call TalkToTrainer
    jmp TextScriptEnd

Route25Hiker2Text:
    mov esi, Route25TrainerHeader7
    call TalkToTrainer
    jmp TextScriptEnd

Route25Hiker3Text:
    mov esi, Route25TrainerHeader8
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; Route25Youngster1BattleText (scripts/Route25.asm:145-254) — Tier-1 data: Route25Youngster1BattleText is generated into assets/trainer_headers.inc.
