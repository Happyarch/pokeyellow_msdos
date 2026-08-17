; CinnabarIsland.asm — translated from pret scripts/CinnabarIsland.asm by dos_port/tools/sm83xlat.
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


global CinnabarIslandDefaultScript
global CinnabarIslandDoorIsLockedText
global CinnabarIslandGamblerText
global CinnabarIslandGirlText
global CinnabarIslandGymSignText
global CinnabarIslandPlayerMovingScript
global CinnabarIslandPokemonLabSignText
global CinnabarIslandSignText
global CinnabarIsland_Script
global CinnabarIsland_ScriptPointers
global CinnabarIsland_TextPointers

extern CallFunctionInTable
extern Delay3
extern DisplayTextID
extern EnableAutoTextBoxDrawing
extern IsItemInBag
extern MartSignText   ; NOT YET DEFINED IN THE PORT
extern PokeCenterSignText   ; NOT YET DEFINED IN THE PORT
extern StartSimulatingJoypadStates
extern _CinnabarIslandDoorIsLockedText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarIslandGamblerText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarIslandGirlText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarIslandGymSignText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarIslandPokemonLabSignText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarIslandSignText   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_CINNABARISLAND_DEFAULT                  equ 0
SCRIPT_CINNABARISLAND_PLAYER_MOVING            equ 1
TEXT_CINNABARISLAND_DOOR_IS_LOCKED             equ 8

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wCinnabarIslandCurScript                       equ 0xD638
wSpritePlayerStateData1FacingDirection         equ 0xC109

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
CinnabarIsland_Script:
    call EnableAutoTextBoxDrawing
    mov esi, wCurrentMapScriptFlags
    or byte [ebp + esi], (1 << (BIT_CUR_MAP_LOADED_1))
    ResetEvent EVENT_MANSION_SWITCH_ON
    ResetEvent EVENT_LAB_STILL_REVIVING_FOSSIL
    mov esi, CinnabarIsland_ScriptPointers
    mov al, [ebp + wCinnabarIslandCurScript]
    jmp CallFunctionInTable

%assign event_byte -1
%assign event_byte_a -1
CinnabarIsland_ScriptPointers:
    dd CinnabarIslandDefaultScript
    dd CinnabarIslandPlayerMovingScript

%assign event_byte -1
%assign event_byte_a -1
CinnabarIslandDefaultScript:
    mov bh, 43
    call IsItemInBag
    jz .nr_19
        ret
.nr_19:
    mov al, [ebp + wYCoord]
    cmp al, 4
    jz .nr_22
        ret
.nr_22:
    mov al, [ebp + wXCoord]
    cmp al, 18
    jz .nr_25
        ret
.nr_25:
    mov al, PLAYER_DIR_UP
    mov [ebp + wPlayerMovingDirection], al
    mov al, TEXT_CINNABARISLAND_DOOR_IS_LOCKED
    mov [ebp + hTextID], al
    call DisplayTextID
    xor al, al
    mov [ebp + hJoyHeld], al
    mov al, 0x1
    mov [ebp + wSimulatedJoypadStatesIndex], al
    mov al, PAD_DOWN
    mov [ebp + wSimulatedJoypadStatesEnd], al
    call StartSimulatingJoypadStates
    xor al, al
    mov [ebp + wSpritePlayerStateData1FacingDirection], al
    mov [ebp + wJoyIgnore], al
    mov al, SCRIPT_CINNABARISLAND_PLAYER_MOVING
    mov [ebp + wCinnabarIslandCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
CinnabarIslandPlayerMovingScript:
    mov al, [ebp + wSimulatedJoypadStatesIndex]
    test al, al
    jz .nr_48
        ret
.nr_48:
    call Delay3
    mov al, SCRIPT_CINNABARISLAND_DEFAULT
    mov [ebp + wCinnabarIslandCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
CinnabarIsland_TextPointers:
    dd CinnabarIslandGirlText
    dd CinnabarIslandGamblerText
    dd CinnabarIslandSignText
    dd MartSignText
    dd PokeCenterSignText
    dd CinnabarIslandPokemonLabSignText
    dd CinnabarIslandGymSignText
    dd CinnabarIslandDoorIsLockedText
CinnabarIslandDoorIsLockedText:
    text_far _CinnabarIslandDoorIsLockedText
    text_end
CinnabarIslandGirlText:
    text_far _CinnabarIslandGirlText
    text_end
CinnabarIslandGamblerText:
    text_far _CinnabarIslandGamblerText
    text_end
CinnabarIslandSignText:
    text_far _CinnabarIslandSignText
    text_end
CinnabarIslandPokemonLabSignText:
    text_far _CinnabarIslandPokemonLabSignText
    text_end
CinnabarIslandGymSignText:
    text_far _CinnabarIslandGymSignText
    text_end
