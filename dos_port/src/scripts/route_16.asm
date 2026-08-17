; Route16.asm — translated from pret scripts/Route16.asm by dos_port/tools/sm83xlat.
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


global Route16Biker1Text
global Route16Biker2Text
global Route16Biker3Text
global Route16Biker4Text
global Route16Biker5Text
global Route16Biker6Text
global Route16ResetScripts
global Route16SnorlaxPostBattleScript
global Route16_Script
global Route16_ScriptPointers

extern CheckFightingMapTrainers   ; NOT YET DEFINED IN THE PORT
extern Delay3   ; NOT YET DEFINED IN THE PORT
extern DisplayEnemyTrainerTextAndStartBattle   ; NOT YET DEFINED IN THE PORT
extern DisplayTextID   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EndTrainerBattle   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern HideObject   ; NOT YET DEFINED IN THE PORT
extern Route16Biker1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route16Biker1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route16Biker1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route16Biker2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route16Biker2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route16Biker2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route16Biker3AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route16Biker3BattleText   ; NOT YET DEFINED IN THE PORT
extern Route16Biker3EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route16Biker4AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route16Biker4EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route16Biker5AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route16Biker5BattleText   ; NOT YET DEFINED IN THE PORT
extern Route16Biker5EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route16Biker6AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern Route16Biker6BattleText   ; NOT YET DEFINED IN THE PORT
extern Route16Biker6EndBattleText   ; NOT YET DEFINED IN THE PORT
extern Route16CyclingRoadSignText   ; NOT YET DEFINED IN THE PORT
extern Route16DefaultScript   ; NOT YET DEFINED IN THE PORT
extern Route16SignText   ; NOT YET DEFINED IN THE PORT
extern Route16SnorlaxReturnedToMountainsText   ; NOT YET DEFINED IN THE PORT
extern Route16SnorlaxText   ; NOT YET DEFINED IN THE PORT
extern Route16SnorlaxWokeUpText   ; NOT YET DEFINED IN THE PORT
extern Route16TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern Route16TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern Route16TrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern Route16TrainerHeader3   ; NOT YET DEFINED IN THE PORT
extern Route16TrainerHeader4   ; NOT YET DEFINED IN THE PORT
extern Route16TrainerHeader5   ; NOT YET DEFINED IN THE PORT
extern Route16TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern Route16_TextPointers   ; NOT YET DEFINED IN THE PORT
extern Route16biker4BattleText   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern UpdateSprites   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_ROUTE16_DEFAULT                         equ 0
SCRIPT_ROUTE16_SNORLAX_POST_BATTLE             equ 3
TEXT_ROUTE16_BIKER1                            equ 1
TEXT_ROUTE16_BIKER2                            equ 2
TEXT_ROUTE16_BIKER3                            equ 3
TEXT_ROUTE16_BIKER4                            equ 4
TEXT_ROUTE16_BIKER5                            equ 5
TEXT_ROUTE16_BIKER6                            equ 6
TEXT_ROUTE16_SNORLAX                           equ 7
TEXT_ROUTE16_CYCLING_ROAD_SIGN                 equ 8
TEXT_ROUTE16_SIGN                              equ 9
TEXT_ROUTE16_SNORLAX_WOKE_UP                   equ 10
TEXT_ROUTE16_SNORLAX_RETURNED_TO_MOUNTAINS     equ 11

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wRoute16CurScript                              equ 0xD625

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

Route16_Script:
    call EnableAutoTextBoxDrawing
    mov esi, Route16TrainerHeaders
    mov edi, Route16_ScriptPointers   ; pret: ld de, Route16_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wRoute16CurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wRoute16CurScript], al
    ret

Route16ResetScripts:
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov [ebp + wRoute16CurScript], al
    mov [ebp + wCurMapScript], al
    ret

Route16_ScriptPointers:
    dd Route16DefaultScript
    dd DisplayEnemyTrainerTextAndStartBattle
    dd EndTrainerBattle
    dd Route16SnorlaxPostBattleScript

; ---------------------------------------------------------------------------
; BAIL[event-byte-assembly-state] Route16DefaultScript (scripts/Route16.asm:25-44) — at scripts/Route16.asm:27: CheckEventReuseHL EVENT_FIGHT_ROUTE16_SNORLAX
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEventHL EVENT_BEAT_ROUTE16_SNORLAX
; PRET| 	jp nz, CheckFightingMapTrainers
; PRET| 	CheckEventReuseHL EVENT_FIGHT_ROUTE16_SNORLAX
; PRET| 	ResetEventReuseHL EVENT_FIGHT_ROUTE16_SNORLAX
; PRET| 	jp z, CheckFightingMapTrainers
; PRET| 	ld a, TEXT_ROUTE16_SNORLAX_WOKE_UP
; PRET| 	ldh [hTextID], a
; PRET| 	call DisplayTextID
; PRET| 	ld a, SNORLAX
; PRET| 	ld [wCurOpponent], a
; PRET| 	ld a, 30
; PRET| 	ld [wCurEnemyLevel], a
; PRET| 	ld a, TOGGLE_ROUTE_16_SNORLAX
; PRET| 	ld [wToggleableObjectIndex], a
; PRET| 	predef HideObject
; PRET| 	call UpdateSprites
; PRET| 	ld a, SCRIPT_ROUTE16_SNORLAX_POST_BATTLE
; PRET| 	ld [wRoute16CurScript], a
; PRET| 	ld [wCurMapScript], a
; PRET| 	ret

Route16SnorlaxPostBattleScript:
    mov al, [ebp + wIsInBattle]
    cmp al, 0xff
    jz Route16ResetScripts
    call UpdateSprites
    mov al, [ebp + wBattleResult]
    cmp al, 0x2
    jz .caught
    mov al, TEXT_ROUTE16_SNORLAX_RETURNED_TO_MOUNTAINS
    mov [ebp + hTextID], al
    call DisplayTextID
.caught:
    SetEvent EVENT_BEAT_ROUTE16_SNORLAX
    call Delay3
    mov al, SCRIPT_ROUTE16_DEFAULT
    mov [ebp + wRoute16CurScript], al
    mov [ebp + wCurMapScript], al
    ret

; ---------------------------------------------------------------------------
; Route16_TextPointers (scripts/Route16.asm:66-93) — Tier-1 data: Route16TrainerHeaders is generated into assets/trainer_headers.inc.

Route16Biker1Text:
    mov esi, Route16TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; Route16Biker1BattleText (scripts/Route16.asm:102-111) — Tier-1 data: Route16Biker1BattleText is generated into assets/trainer_headers.inc.

Route16Biker2Text:
    mov esi, Route16TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; Route16Biker2BattleText (scripts/Route16.asm:120-129) — Tier-1 data: Route16Biker2BattleText is generated into assets/trainer_headers.inc.

Route16Biker3Text:
    mov esi, Route16TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; Route16Biker3BattleText (scripts/Route16.asm:138-147) — Tier-1 data: Route16Biker3BattleText is generated into assets/trainer_headers.inc.

Route16Biker4Text:
    mov esi, Route16TrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; Route16biker4BattleText (scripts/Route16.asm:156-165) — Tier-1 data: Route16biker4BattleText is generated into assets/trainer_headers.inc.

Route16Biker5Text:
    mov esi, Route16TrainerHeader4
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; Route16Biker5BattleText (scripts/Route16.asm:174-183) — Tier-1 data: Route16Biker5BattleText is generated into assets/trainer_headers.inc.

Route16Biker6Text:
    mov esi, Route16TrainerHeader5
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; Route16Biker6BattleText (scripts/Route16.asm:192-221) — Tier-1 data: Route16Biker6BattleText is generated into assets/trainer_headers.inc.
