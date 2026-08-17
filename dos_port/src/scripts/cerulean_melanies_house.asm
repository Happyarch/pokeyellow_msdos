; CeruleanMelaniesHouse.asm — translated from pret scripts/CeruleanMelaniesHouse.asm by dos_port/tools/sm83xlat.
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


global CeruleanHouse1Text_1cfc8
global CeruleanHouse1Text_1cfce
global CeruleanHouse1Text_1cfd3
global CeruleanHouse1Text_1cfd9
global CeruleanHouse1Text_1cfdf
global CeruleanMelanieHouseBulbasaurText
global CeruleanMelanieHouseMelanieText
global CeruleanMelanieHouseOddishText
global CeruleanMelanieHouseSandshrewText
global CeruleanMelaniesHouse_Script
global CeruleanMelaniesHouse_TextPointers

extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern GetMonName   ; NOT YET DEFINED IN THE PORT
extern GivePokemon   ; NOT YET DEFINED IN THE PORT
extern HideObject   ; NOT YET DEFINED IN THE PORT
extern MelanieBulbasaurText   ; NOT YET DEFINED IN THE PORT
extern MelanieOddishText   ; NOT YET DEFINED IN THE PORT
extern MelanieSandshrewText   ; NOT YET DEFINED IN THE PORT
extern MelanieText1   ; NOT YET DEFINED IN THE PORT
extern MelanieText2   ; NOT YET DEFINED IN THE PORT
extern MelanieText3   ; NOT YET DEFINED IN THE PORT
extern MelanieText4   ; NOT YET DEFINED IN THE PORT
extern MelanieText5   ; NOT YET DEFINED IN THE PORT
extern PlayCry   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern WaitForTextScrollButtonPress   ; NOT YET DEFINED IN THE PORT
extern YesNoChoice   ; NOT YET DEFINED IN THE PORT

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wAddedToParty                                  equ 0xCCD3

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
CeruleanMelaniesHouse_Script:
    call EnableAutoTextBoxDrawing
    ret

%assign event_byte -1
CeruleanMelaniesHouse_TextPointers:
    dd CeruleanMelanieHouseMelanieText
    dd CeruleanMelanieHouseBulbasaurText
    dd CeruleanMelanieHouseOddishText
    dd CeruleanMelanieHouseSandshrewText

%assign event_byte -1
CeruleanMelanieHouseMelanieText:
    mov al, 0x1
    mov [ebp + wDoNotWaitForButtonPressAfterDisplayingText], al
    CheckEvent EVENT_GOT_BULBASAUR_IN_CERULEAN
    jnz .asm_1cfbf
    mov esi, CeruleanHouse1Text_1cfc8
    call PrintText
    mov al, [ebp + wPikachuHappiness]
    cmp al, 147
    jb .asm_1cfb3
    mov esi, CeruleanHouse1Text_1cfce
    call PrintText
    call YesNoChoice
    mov al, [ebp + wCurrentMenuItem]
    test al, al
    jnz .asm_1cfb6
    mov al, 0x1
    mov [ebp + wDoNotWaitForButtonPressAfterDisplayingText], al
    mov al, 153
    mov [ebp + wNamedObjectIndex], al
    mov [ebp + wCurPartySpecies], al
    call GetMonName
    mov al, 0x1
    mov [ebp + wDoNotWaitForButtonPressAfterDisplayingText], al
    mov bx, ((153) << 8) | (10)
    call GivePokemon
    jae .asm_1cfb3
    mov al, [ebp + wAddedToParty]
    test al, al
    jnz .sk_42
        call WaitForTextScrollButtonPress
.sk_42:
    mov al, 0x1
    mov [ebp + wDoNotWaitForButtonPressAfterDisplayingText], al
    mov esi, CeruleanHouse1Text_1cfd3
    call PrintText
    mov al, 52
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call HideObject
    SetEvent EVENT_GOT_BULBASAUR_IN_CERULEAN
.asm_1cfb3:
    jmp TextScriptEnd

%assign event_byte -1
.asm_1cfb6:
    mov esi, CeruleanHouse1Text_1cfdf
    call PrintText
    jmp TextScriptEnd

%assign event_byte -1
.asm_1cfbf:
    mov esi, CeruleanHouse1Text_1cfd9
    call PrintText
    jmp TextScriptEnd

%assign event_byte -1
CeruleanHouse1Text_1cfc8:
    text_far MelanieText1
    text_waitbutton
    text_end
CeruleanHouse1Text_1cfce:
    text_far MelanieText2
    text_end
CeruleanHouse1Text_1cfd3:
    text_far MelanieText3
    text_waitbutton
    text_end
CeruleanHouse1Text_1cfd9:
    text_far MelanieText4
    text_waitbutton
    text_end
CeruleanHouse1Text_1cfdf:
    text_far MelanieText5
    text_waitbutton
    text_end
CeruleanMelanieHouseBulbasaurText:
    text_far MelanieBulbasaurText

%assign event_byte -1
    mov al, 153
    call PlayCry
    jmp TextScriptEnd

%assign event_byte -1
CeruleanMelanieHouseOddishText:
    text_far MelanieOddishText

%assign event_byte -1
    mov al, 185
    call PlayCry
    jmp TextScriptEnd

%assign event_byte -1
CeruleanMelanieHouseSandshrewText:
    text_far MelanieSandshrewText

%assign event_byte -1
    mov al, 96
    call PlayCry
    jmp TextScriptEnd
