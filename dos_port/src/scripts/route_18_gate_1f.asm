; Route18Gate1F.asm — translated from pret scripts/Route18Gate1F.asm by dos_port/tools/sm83xlat.
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


global Route18Gate1FDefaultScript
global Route18Gate1FGuardExcuseMeText
global Route18Gate1FGuardScript
global Route18Gate1FGuardText
global Route18Gate1FPlayerMovingRightScript
global Route18Gate1FPlayerMovingUpScript
global Route18Gate1F_Script
global Route18Gate1F_ScriptPointers
global Route18Gate1F_TextPointers

extern ArePlayerCoordsInArray
extern CallFunctionInTable
extern DisplayTextID
extern EnableAutoTextBoxDrawing
extern FillMemory
extern PrintText
extern Route16Gate1FIsBicycleInBagScript   ; NOT YET DEFINED IN THE PORT
extern StartSimulatingJoypadStates
extern TextScriptEnd
extern _Route18Gate1FGuardCyclingRoadUphillText   ; NOT YET DEFINED IN THE PORT
extern _Route18Gate1FGuardExcuseMeText   ; NOT YET DEFINED IN THE PORT
extern _Route18Gate1FGuardYouNeedABicycleText   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_ROUTE18GATE1F_DEFAULT                   equ 0
SCRIPT_ROUTE18GATE1F_PLAYER_MOVING_UP          equ 1
SCRIPT_ROUTE18GATE1F_GUARD                     equ 2
SCRIPT_ROUTE18GATE1F_PLAYER_MOVING_RIGHT       equ 3
TEXT_ROUTE18GATE1F_GUARD                       equ 1
TEXT_ROUTE18GATE1F_GUARD_EXCUSE_ME             equ 2

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wCoordIndex                                    equ 0xCD3D
wRoute18Gate1FCurScript                        equ 0xD668

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
Route18Gate1F_Script:
    mov esi, wStatusFlags6
    and byte [ebp + esi], ~(1 << (BIT_ALWAYS_ON_BIKE)) & 0xFF
    call EnableAutoTextBoxDrawing
    mov al, [ebp + wRoute18Gate1FCurScript]
    mov esi, Route18Gate1F_ScriptPointers
    jmp CallFunctionInTable

%assign event_byte -1
%assign event_byte_a -1
Route18Gate1F_ScriptPointers:
    dd Route18Gate1FDefaultScript
    dd Route18Gate1FPlayerMovingUpScript
    dd Route18Gate1FGuardScript
    dd Route18Gate1FPlayerMovingRightScript

%assign event_byte -1
%assign event_byte_a -1
Route18Gate1FDefaultScript:
    call Route16Gate1FIsBicycleInBagScript
    jz .nr_18
        ret
.nr_18:
    mov esi, .StopsPlayerCoords
    call ArePlayerCoordsInArray
    jb .nr_21
        ret
.nr_21:
    mov al, TEXT_ROUTE18GATE1F_GUARD_EXCUSE_ME
    mov [ebp + hTextID], al
    call DisplayTextID
    xor al, al
    mov [ebp + hJoyHeld], al
    mov al, [ebp + wCoordIndex]
    cmp al, 0x1
    jz .next_to_counter
    mov al, [ebp + wCoordIndex]
    dec al
    mov [ebp + wSimulatedJoypadStatesIndex], al
    mov bh, 0
    mov bl, al
    mov al, PAD_UP
    mov esi, wSimulatedJoypadStatesEnd
    call FillMemory
    call StartSimulatingJoypadStates
    mov al, SCRIPT_ROUTE18GATE1F_PLAYER_MOVING_UP
    mov [ebp + wRoute18Gate1FCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
.next_to_counter:
    mov al, SCRIPT_ROUTE18GATE1F_GUARD
    mov [ebp + wRoute18Gate1FCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
.StopsPlayerCoords:
    db 3, 4
    db 4, 4
    db 5, 4
    db 6, 4
    db -1

%assign event_byte -1
%assign event_byte_a -1
Route18Gate1FPlayerMovingUpScript:
    mov al, [ebp + wSimulatedJoypadStatesIndex]
    test al, al
    jz .nr_57
        ret
.nr_57:
    mov al, PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
Route18Gate1FGuardScript:
    mov al, TEXT_ROUTE18GATE1F_GUARD
    mov [ebp + hTextID], al
    call DisplayTextID
    mov al, 0x1
    mov [ebp + wSimulatedJoypadStatesIndex], al
    mov al, PAD_RIGHT
    mov [ebp + wSimulatedJoypadStatesEnd], al
    call StartSimulatingJoypadStates
    mov al, SCRIPT_ROUTE18GATE1F_PLAYER_MOVING_RIGHT
    mov [ebp + wRoute18Gate1FCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
Route18Gate1FPlayerMovingRightScript:
    mov al, [ebp + wSimulatedJoypadStatesIndex]
    test al, al
    jz .nr_77
        ret
.nr_77:
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov esi, wStatusFlags5
    and byte [ebp + esi], ~(1 << (BIT_SCRIPTED_MOVEMENT_STATE)) & 0xFF
    mov al, SCRIPT_ROUTE18GATE1F_DEFAULT
    mov [ebp + wRoute18Gate1FCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
Route18Gate1F_TextPointers:
    dd Route18Gate1FGuardText
    dd Route18Gate1FGuardExcuseMeText

%assign event_byte -1
%assign event_byte_a -1
Route18Gate1FGuardText:
    call Route16Gate1FIsBicycleInBagScript
    jz .no_bike
    mov esi, .CyclingRoadUphillText
    call PrintText
    jmp .text_script_end

%assign event_byte -1
%assign event_byte_a -1
.no_bike:
    mov esi, .YouNeedABicycleText
    call PrintText
.text_script_end:
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.YouNeedABicycleText:
    text_far _Route18Gate1FGuardYouNeedABicycleText
    text_end
.CyclingRoadUphillText:
    text_far _Route18Gate1FGuardCyclingRoadUphillText
    text_end
Route18Gate1FGuardExcuseMeText:
    text_far _Route18Gate1FGuardExcuseMeText
    text_end
