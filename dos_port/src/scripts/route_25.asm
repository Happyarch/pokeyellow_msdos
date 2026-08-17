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

%include "assets/trainer_headers.inc"

global Route25CooltrainerF1Text
global Route25CooltrainerF2Text
global Route25CooltrainerMText
global Route25Hiker1Text
global Route25Hiker2Text
global Route25Hiker3Text
global Route25ToggleBillsScript
global Route25Youngster1Text
global Route25Youngster2Text
global Route25Youngster3Text
global Route25_Script

extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern HideObject   ; NOT YET DEFINED IN THE PORT
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
extern Route25Youngster1BattleText   ; NOT YET DEFINED IN THE PORT
extern Route25_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern ShowObject   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT

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

%assign event_byte -1
Route25_Script:
    call EnableAutoTextBoxDrawing
    mov esi, Route25TrainerHeaders
    mov edi, Route25_ScriptPointers   ; pret: ld de, Route25_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wRoute25CurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wRoute25CurScript], al
    call Route25ToggleBillsScript
    ret

%assign event_byte -1
Route25ToggleBillsScript:
    mov esi, wPikachuMapScriptFlags
    and byte [ebp + esi], ~(1 << (2)) & 0xFF
    and byte [ebp + esi], ~(1 << (3)) & 0xFF
    and byte [ebp + esi], ~(1 << (4)) & 0xFF
    and byte [ebp + esi], ~(1 << (7)) & 0xFF
    xor al, al
    mov [ebp + wBillsHouseCurScript], al
    mov esi, wCurrentMapScriptFlags
    test byte [ebp + esi], (1 << (BIT_CUR_MAP_LOADED_2))
    pushfd    ; SM83 form writes no flags
        and byte [ebp + esi], ~(1 << (BIT_CUR_MAP_LOADED_2)) & 0xFF
    popfd
    jnz .nr_22
        ret
.nr_22:
    mov esi, wEventFlags + EVENT_BYTE(EVENT_LEFT_BILLS_HOUSE_AFTER_HELPING)
    test byte [ebp + esi], EVENT_MASK(EVENT_LEFT_BILLS_HOUSE_AFTER_HELPING)
    jz .nr_24
        ret
.nr_24:
    CheckEventReuseHL EVENT_MET_BILL_2
    jnz .met_bill
    ResetEventReuseHL EVENT_BILL_SAID_USE_CELL_SEPARATOR
    mov al, 97
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call ShowObject
    jmp .done

%assign event_byte -1
.met_bill:
    CheckEventAfterBranchReuseHL EVENT_GOT_SS_TICKET, EVENT_MET_BILL_2
    jz .done
    SetEventReuseHL EVENT_LEFT_BILLS_HOUSE_AFTER_HELPING
    mov al, 37
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call HideObject
    mov al, 98
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call HideObject
    mov al, 99
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call ShowObject
.done:
    ret

; Route25_ScriptPointers (scripts/Route25.asm:49-88) — not re-emitted: Route25TrainerHeaders is already defined in assets/trainer_headers.inc.

%assign event_byte -1
Route25Youngster1Text:
    mov esi, Route25TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
Route25Youngster2Text:
    mov esi, Route25TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
Route25CooltrainerMText:
    mov esi, Route25TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
Route25CooltrainerF1Text:
    mov esi, Route25TrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
Route25Youngster3Text:
    mov esi, Route25TrainerHeader4
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
Route25CooltrainerF2Text:
    mov esi, Route25TrainerHeader5
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
Route25Hiker1Text:
    mov esi, Route25TrainerHeader6
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
Route25Hiker2Text:
    mov esi, Route25TrainerHeader7
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
Route25Hiker3Text:
    mov esi, Route25TrainerHeader8
    call TalkToTrainer
    jmp TextScriptEnd

; Route25Youngster1BattleText (scripts/Route25.asm:145-254) — not re-emitted: Route25Youngster1BattleText is already defined in assets/trainer_headers.inc.
