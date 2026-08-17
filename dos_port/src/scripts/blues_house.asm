; BluesHouse.asm — translated from pret scripts/BluesHouse.asm by dos_port/tools/sm83xlat.
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


global BluesHouseDaisySittingText
global BluesHouseDefaultScript
global BluesHouseNoopScript
global BluesHouse_Script
global BluesHouse_ScriptPointers
global BluesHouse_TextPointers

extern BluesHouseDaisyBagFullText   ; NOT YET DEFINED IN THE PORT
extern BluesHouseDaisyOfferMapText   ; NOT YET DEFINED IN THE PORT
extern BluesHouseDaisyRivalAtLabText   ; NOT YET DEFINED IN THE PORT
extern BluesHouseDaisyUseMapText   ; NOT YET DEFINED IN THE PORT
extern BluesHouseDaisyWalkingText   ; NOT YET DEFINED IN THE PORT
extern BluesHouseTownMapText   ; NOT YET DEFINED IN THE PORT
extern CallFunctionInTable   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern GiveItem   ; NOT YET DEFINED IN THE PORT
extern GotMapText   ; NOT YET DEFINED IN THE PORT
extern HideObject   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern _BluesHouseDaisyOfferMapText   ; NOT YET DEFINED IN THE PORT
extern _BluesHouseDaisyRivalAtLabText   ; NOT YET DEFINED IN THE PORT
extern _GotMapText   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_BLUESHOUSE_NOOP                         equ 1

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wBluesHouseCurScript                           equ 0xD5F2

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
BluesHouse_Script:
    call EnableAutoTextBoxDrawing
    mov esi, BluesHouse_ScriptPointers
    xor al, al
    call CallFunctionInTable
    ret

%assign event_byte -1
BluesHouse_ScriptPointers:
    dd BluesHouseDefaultScript
    dd BluesHouseNoopScript

%assign event_byte -1
BluesHouseDefaultScript:
    SetEvent EVENT_ENTERED_BLUES_HOUSE
    mov al, SCRIPT_BLUESHOUSE_NOOP
    mov [ebp + wBluesHouseCurScript], al
BluesHouseNoopScript:
    ret

%assign event_byte -1
BluesHouse_TextPointers:
    dd BluesHouseDaisySittingText
    dd BluesHouseDaisyWalkingText
    dd BluesHouseTownMapText

%assign event_byte -1
BluesHouseDaisySittingText:
    CheckEvent EVENT_GOT_TOWN_MAP
    jnz .got_town_map
    CheckEvent EVENT_GOT_POKEDEX
    jnz .give_town_map
    mov esi, BluesHouseDaisyRivalAtLabText
    call PrintText
    jmp .done

%assign event_byte -1
.give_town_map:
    mov esi, BluesHouseDaisyOfferMapText
    call PrintText
    mov bx, ((5) << 8) | (1)
    call GiveItem
    jae .bag_full
    mov al, 42
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call HideObject
    mov esi, GotMapText
    call PrintText
    SetEvent EVENT_GOT_TOWN_MAP
    jmp .done

%assign event_byte -1
.got_town_map:
    mov esi, BluesHouseDaisyUseMapText
    call PrintText
    jmp .done

%assign event_byte -1
.bag_full:
    mov esi, BluesHouseDaisyBagFullText
    call PrintText
.done:
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[text-sound-command-unported] BluesHouseDaisyRivalAtLabText (scripts/BluesHouse.asm:62-88) — at scripts/BluesHouse.asm:71: sound_get_key_item
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _BluesHouseDaisyRivalAtLabText
; PRET| 	text_end
; PRET| 
; PRET| BluesHouseDaisyOfferMapText:
; PRET| 	text_far _BluesHouseDaisyOfferMapText
; PRET| 	text_end
; PRET| 
; PRET| GotMapText:
; PRET| 	text_far _GotMapText
; PRET| 	sound_get_key_item
; PRET| 	text_end
; PRET| 
; PRET| BluesHouseDaisyBagFullText:
; PRET| 	text_far _BluesHouseDaisyBagFullText
; PRET| 	text_end
; PRET| 
; PRET| BluesHouseDaisyUseMapText:
; PRET| 	text_far _BluesHouseDaisyUseMapText
; PRET| 	text_end
; PRET| 
; PRET| BluesHouseDaisyWalkingText:
; PRET| 	text_far _BluesHouseDaisyWalkingText
; PRET| 	text_end
; PRET| 
; PRET| BluesHouseTownMapText:
; PRET| 	text_far _BluesHouseTownMapText
; PRET| 	text_end
