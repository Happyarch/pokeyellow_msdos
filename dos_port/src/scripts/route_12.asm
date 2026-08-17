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

%include "assets/trainer_headers.inc"

global Route12CooltrainerMText
global Route12DefaultScript
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

extern CheckFightingMapTrainers
extern Delay3
extern DisplayEnemyTrainerTextAndStartBattle
extern DisplayTextID
extern EnableAutoTextBoxDrawing
extern EndTrainerBattle
extern ExecuteCurMapScriptInTable
extern HideObject
extern Route12CooltrainerMBattleText   ; NOT YET DEFINED IN THE PORT
extern Route12Fisher1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route12Fisher2BattleText   ; NOT YET DEFINED IN THE PORT
extern Route12Fisher3BattleText   ; NOT YET DEFINED IN THE PORT
extern Route12Fisher4BattleText   ; NOT YET DEFINED IN THE PORT
extern Route12Fisher5BattleText   ; NOT YET DEFINED IN THE PORT
extern Route12SuperNerdBattleText   ; NOT YET DEFINED IN THE PORT
extern Route12TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern Route12TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern Route12TrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern Route12TrainerHeader3   ; NOT YET DEFINED IN THE PORT
extern Route12TrainerHeader4   ; NOT YET DEFINED IN THE PORT
extern Route12TrainerHeader5   ; NOT YET DEFINED IN THE PORT
extern Route12TrainerHeader6   ; NOT YET DEFINED IN THE PORT
extern Route12TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern Route12_TextPointers   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer
extern TextScriptEnd
extern UpdateSprites

; Script constants — pret defines these via dw_const in this file.
SCRIPT_ROUTE12_DEFAULT                         equ 0
SCRIPT_ROUTE12_SNORLAX_POST_BATTLE             equ 3
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

%assign event_byte -1
%assign event_byte_a -1
Route12_Script:
    call EnableAutoTextBoxDrawing
    mov esi, Route12TrainerHeaders
    mov edi, Route12_ScriptPointers   ; pret: ld de, Route12_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wRoute12CurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wRoute12CurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
Route12ResetScripts:
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov [ebp + wRoute12CurScript], al
    mov [ebp + wCurMapScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
Route12_ScriptPointers:
    dd Route12DefaultScript
    dd DisplayEnemyTrainerTextAndStartBattle
    dd EndTrainerBattle
    dd Route12SnorlaxPostBattleScript

%assign event_byte -1
%assign event_byte_a -1
Route12DefaultScript:
    mov esi, wEventFlags + EVENT_BYTE(EVENT_BEAT_ROUTE12_SNORLAX)
    test byte [ebp + esi], EVENT_MASK(EVENT_BEAT_ROUTE12_SNORLAX)
    jnz CheckFightingMapTrainers
    CheckEventReuseHL EVENT_FIGHT_ROUTE12_SNORLAX
    pushfd    ; SM83 form writes no flags
        ResetEventReuseHL EVENT_FIGHT_ROUTE12_SNORLAX
    popfd
    jz CheckFightingMapTrainers
    mov al, TEXT_ROUTE12_SNORLAX_WOKE_UP
    mov [ebp + hTextID], al
    call DisplayTextID
    mov al, 132
    mov [ebp + wCurOpponent], al
    mov al, 30
    mov [ebp + wCurEnemyLevel], al
    mov al, 30
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call HideObject
    mov al, SCRIPT_ROUTE12_SNORLAX_POST_BATTLE
    mov [ebp + wRoute12CurScript], al
    mov [ebp + wCurMapScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
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

; Route12_TextPointers (scripts/Route12.asm:65-109) — not re-emitted: Route12TrainerHeaders is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route12Fisher1Text:
    mov esi, Route12TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; Route12Fisher1BattleText (scripts/Route12.asm:118-127) — not re-emitted: Route12Fisher1BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route12Fisher2Text:
    mov esi, Route12TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

; Route12Fisher2BattleText (scripts/Route12.asm:136-145) — not re-emitted: Route12Fisher2BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route12CooltrainerMText:
    mov esi, Route12TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

; Route12CooltrainerMBattleText (scripts/Route12.asm:154-163) — not re-emitted: Route12CooltrainerMBattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route12SuperNerdText:
    mov esi, Route12TrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

; Route12SuperNerdBattleText (scripts/Route12.asm:172-181) — not re-emitted: Route12SuperNerdBattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route12Fisher3Text:
    mov esi, Route12TrainerHeader4
    call TalkToTrainer
    jmp TextScriptEnd

; Route12Fisher3BattleText (scripts/Route12.asm:190-199) — not re-emitted: Route12Fisher3BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route12Fisher4Text:
    mov esi, Route12TrainerHeader5
    call TalkToTrainer
    jmp TextScriptEnd

; Route12Fisher4BattleText (scripts/Route12.asm:208-217) — not re-emitted: Route12Fisher4BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
Route12Fisher5Text:
    mov esi, Route12TrainerHeader6
    call TalkToTrainer
    jmp TextScriptEnd

; Route12Fisher5BattleText (scripts/Route12.asm:226-243) — not re-emitted: Route12Fisher5BattleText is already defined in assets/trainer_headers.inc.
