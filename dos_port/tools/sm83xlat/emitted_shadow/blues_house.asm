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


global BluesHouseDefaultScript
global BluesHouseNoopScript
global BluesHouse_Script
global BluesHouse_ScriptPointers
global BluesHouse_TextPointers

extern BluesHouseDaisyBagFullText   ; NOT YET DEFINED IN THE PORT
extern BluesHouseDaisyOfferMapText   ; NOT YET DEFINED IN THE PORT
extern BluesHouseDaisyRivalAtLabText   ; NOT YET DEFINED IN THE PORT
extern BluesHouseDaisySittingText   ; NOT YET DEFINED IN THE PORT
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

BluesHouse_Script:
    call EnableAutoTextBoxDrawing
    mov esi, BluesHouse_ScriptPointers
    xor al, al
    call CallFunctionInTable
    ret

BluesHouse_ScriptPointers:
    dd BluesHouseDefaultScript
    dd BluesHouseNoopScript

BluesHouseDefaultScript:
    SetEvent EVENT_ENTERED_BLUES_HOUSE
    mov al, SCRIPT_BLUESHOUSE_NOOP
    mov [ebp + wBluesHouseCurScript], al
BluesHouseNoopScript:
    ret

BluesHouse_TextPointers:
    dd BluesHouseDaisySittingText
    dd BluesHouseDaisyWalkingText
    dd BluesHouseTownMapText

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] BluesHouseDaisySittingText (scripts/BluesHouse.asm:28-34) — at scripts/BluesHouse.asm:31: .give_town_map is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEvent EVENT_GOT_TOWN_MAP
; PRET| 	jr nz, .got_town_map
; PRET| 	CheckEvent EVENT_GOT_POKEDEX
; PRET| 	jr nz, .give_town_map
; PRET| 	ld hl, BluesHouseDaisyRivalAtLabText
; PRET| 	call PrintText
; PRET| 	jr .done

; ---------------------------------------------------------------------------
; BAIL[predef-leaves-id-in-a] BluesHouseDaisySittingText.give_town_map (scripts/BluesHouse.asm:37-48) — at scripts/BluesHouse.asm:44: predef HideObject
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, BluesHouseDaisyOfferMapText
; PRET| 	call PrintText
; PRET| 	lb bc, TOWN_MAP, 1
; PRET| 	call GiveItem
; PRET| 	jr nc, .bag_full
; PRET| 	ld a, TOGGLE_TOWN_MAP
; PRET| 	ld [wToggleableObjectIndex], a
; PRET| 	predef HideObject
; PRET| 	ld hl, GotMapText
; PRET| 	call PrintText
; PRET| 	SetEvent EVENT_GOT_TOWN_MAP
; PRET| 	jr .done

.got_town_map:
    mov esi, BluesHouseDaisyUseMapText
    call PrintText
    jmp .done

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
