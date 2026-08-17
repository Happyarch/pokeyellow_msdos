; Route12.asm — translated from pret scripts/Route12.asm by dos_port/tools/sm83xlat.
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


global Route12CooltrainerMText
global Route12Fisher1Text
global Route12Fisher2Text
global Route12Fisher3Text
global Route12Fisher4Text
global Route12Fisher5Text
global Route12ResetScripts
global Route12SnorlaxPostBattleScript
global Route12SuperNerdText
global Route12_Script
global Route12_ScriptPointers

extern CheckFightingMapTrainers   ; NOT YET DEFINED IN THE PORT
extern Delay3   ; NOT YET DEFINED IN THE PORT
extern DisplayEnemyTrainerTextAndStartBattle   ; NOT YET DEFINED IN THE PORT
extern DisplayTextID   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EndTrainerBattle   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern HideObject   ; NOT YET DEFINED IN THE PORT
extern PickUpItemText   ; NOT YET DEFINED IN THE PORT
extern Route12CooltrainerMAfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route12CooltrainerMBattleText   ; NOT YET DEFINED IN THE PORT
extern Route12CooltrainerMEndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route12DefaultScript   ; NOT YET DEFINED IN THE PORT
extern Route12Fisher1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route12Fisher1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route12Fisher1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route12Fisher2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route12Fisher2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route12Fisher2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route12Fisher3AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route12Fisher3BattleText   ; NOT YET DEFINED IN THE PORT
extern Route12Fisher3EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route12Fisher4AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route12Fisher4BattleText   ; NOT YET DEFINED IN THE PORT
extern Route12Fisher4EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route12Fisher5AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route12Fisher5BattleText   ; NOT YET DEFINED IN THE PORT
extern Route12Fisher5EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route12SignText   ; NOT YET DEFINED IN THE PORT
extern Route12SnorlaxCalmedDownText   ; NOT YET DEFINED IN THE PORT
extern Route12SnorlaxText   ; NOT YET DEFINED IN THE PORT
extern Route12SnorlaxWokeUpText   ; NOT YET DEFINED IN THE PORT
extern Route12SportFishingSignText   ; NOT YET DEFINED IN THE PORT
extern Route12SuperNerdAfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route12SuperNerdBattleText   ; NOT YET DEFINED IN THE PORT
extern Route12SuperNerdEndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route12TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern Route12TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern Route12TrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern Route12TrainerHeader3   ; NOT YET DEFINED IN THE PORT
extern Route12TrainerHeader4   ; NOT YET DEFINED IN THE PORT
extern Route12TrainerHeader5   ; NOT YET DEFINED IN THE PORT
extern Route12TrainerHeader6   ; NOT YET DEFINED IN THE PORT
extern Route12TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern Route12_TextPointers   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern UpdateSprites   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_ROUTE12_DEFAULT                         equ 0
SCRIPT_ROUTE12_SNORLAX_POST_BATTLE             equ 3
TEXT_ROUTE12_SNORLAX                           equ 1
TEXT_ROUTE12_FISHER1                           equ 2
TEXT_ROUTE12_FISHER2                           equ 3
TEXT_ROUTE12_COOLTRAINER_M                     equ 4
TEXT_ROUTE12_SUPER_NERD                        equ 5
TEXT_ROUTE12_FISHER3                           equ 6
TEXT_ROUTE12_FISHER4                           equ 7
TEXT_ROUTE12_FISHER5                           equ 8
TEXT_ROUTE12_TM_PAY_DAY                        equ 9
TEXT_ROUTE12_IRON                              equ 10
TEXT_ROUTE12_SIGN                              equ 11
TEXT_ROUTE12_SPORT_FISHING_SIGN                equ 12
TEXT_ROUTE12_SNORLAX_WOKE_UP                   equ 13
TEXT_ROUTE12_SNORLAX_CALMED_DOWN               equ 14

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wRoute12CurScript                              equ 0xD623

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

Route12_Script:
    call EnableAutoTextBoxDrawing
    mov esi, Route12TrainerHeaders
    mov edi, Route12_ScriptPointers   ; pret: ld de, Route12_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wRoute12CurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wRoute12CurScript], al
    ret

Route12ResetScripts:
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov [ebp + wRoute12CurScript], al
    mov [ebp + wCurMapScript], al
    ret

Route12_ScriptPointers:
    dd Route12DefaultScript
    dd DisplayEnemyTrainerTextAndStartBattle
    dd EndTrainerBattle
    dd Route12SnorlaxPostBattleScript

; ---------------------------------------------------------------------------
; BAIL[event-byte-assembly-state] Route12DefaultScript (scripts/Route12.asm:25-43) — at scripts/Route12.asm:27: CheckEventReuseHL EVENT_FIGHT_ROUTE12_SNORLAX
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEventHL EVENT_BEAT_ROUTE12_SNORLAX
; PRET| 	jp nz, CheckFightingMapTrainers
; PRET| 	CheckEventReuseHL EVENT_FIGHT_ROUTE12_SNORLAX
; PRET| 	ResetEventReuseHL EVENT_FIGHT_ROUTE12_SNORLAX
; PRET| 	jp z, CheckFightingMapTrainers
; PRET| 	ld a, TEXT_ROUTE12_SNORLAX_WOKE_UP
; PRET| 	ldh [hTextID], a
; PRET| 	call DisplayTextID
; PRET| 	ld a, SNORLAX
; PRET| 	ld [wCurOpponent], a
; PRET| 	ld a, 30
; PRET| 	ld [wCurEnemyLevel], a
; PRET| 	ld a, TOGGLE_ROUTE_12_SNORLAX
; PRET| 	ld [wToggleableObjectIndex], a
; PRET| 	predef HideObject
; PRET| 	ld a, SCRIPT_ROUTE12_SNORLAX_POST_BATTLE
; PRET| 	ld [wRoute12CurScript], a
; PRET| 	ld [wCurMapScript], a
; PRET| 	ret

Route12SnorlaxPostBattleScript:
    mov al, [ebp + wIsInBattle]
    cmp al, 0xff
    jz Route12ResetScripts
    call UpdateSprites
    mov al, [ebp + wBattleResult]
    cmp al, 0x2
    jz .caught_snorlax
    mov al, TEXT_ROUTE12_SNORLAX_CALMED_DOWN
    mov [ebp + hTextID], al
    call DisplayTextID
.caught_snorlax:
    SetEvent EVENT_BEAT_ROUTE12_SNORLAX
    call Delay3
    mov al, SCRIPT_ROUTE12_DEFAULT
    mov [ebp + wRoute12CurScript], al
    mov [ebp + wCurMapScript], al
    ret

; ---------------------------------------------------------------------------
; Route12_TextPointers (scripts/Route12.asm:65-109) — Tier-1 data: Route12TrainerHeaders is generated into assets/trainer_headers.inc.

Route12Fisher1Text:
    mov esi, Route12TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; Route12Fisher1BattleText (scripts/Route12.asm:118-127) — Tier-1 data: Route12Fisher1BattleText is generated into assets/trainer_headers.inc.

Route12Fisher2Text:
    mov esi, Route12TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; Route12Fisher2BattleText (scripts/Route12.asm:136-145) — Tier-1 data: Route12Fisher2BattleText is generated into assets/trainer_headers.inc.

Route12CooltrainerMText:
    mov esi, Route12TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; Route12CooltrainerMBattleText (scripts/Route12.asm:154-163) — Tier-1 data: Route12CooltrainerMBattleText is generated into assets/trainer_headers.inc.

Route12SuperNerdText:
    mov esi, Route12TrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; Route12SuperNerdBattleText (scripts/Route12.asm:172-181) — Tier-1 data: Route12SuperNerdBattleText is generated into assets/trainer_headers.inc.

Route12Fisher3Text:
    mov esi, Route12TrainerHeader4
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; Route12Fisher3BattleText (scripts/Route12.asm:190-199) — Tier-1 data: Route12Fisher3BattleText is generated into assets/trainer_headers.inc.

Route12Fisher4Text:
    mov esi, Route12TrainerHeader5
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; Route12Fisher4BattleText (scripts/Route12.asm:208-217) — Tier-1 data: Route12Fisher4BattleText is generated into assets/trainer_headers.inc.

Route12Fisher5Text:
    mov esi, Route12TrainerHeader6
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; Route12Fisher5BattleText (scripts/Route12.asm:226-243) — Tier-1 data: Route12Fisher5BattleText is generated into assets/trainer_headers.inc.
