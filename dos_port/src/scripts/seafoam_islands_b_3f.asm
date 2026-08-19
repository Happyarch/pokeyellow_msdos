; SeafoamIslandsB3F.asm — translated from pret scripts/SeafoamIslandsB3F.asm by dos_port/tools/sm83xlat.
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
%include "assets/script_constants.inc"

%include "assets/map_dims.inc"

global RLEList_ForcedSurfingStrongCurrentNearSteps
global Seafoam4HolesCoords
global SeafoamIslandsB3FDefaultScript
global SeafoamIslandsB3FMoveObjectScript
global SeafoamIslandsB3FObjectMoving1Script
global SeafoamIslandsB3FObjectMoving2Script
global SeafoamIslandsB3F_Script
global SeafoamIslandsB3F_ScriptPointers
global SeafoamIslandsB3F_TextPointers

extern BoulderText   ; NOT YET DEFINED IN THE PORT
extern CallFunctionInTable
extern CheckBoulderCoords
extern DecodeRLEList
extern EnableAutoTextBoxDrawing
extern HideObject
extern IsPlayerOnDungeonWarp
extern ShowObject
extern StartSimulatingJoypadStates

; Script constants — pret defines these via dw_const in this file.
SCRIPT_SEAFOAMISLANDSB3F_DEFAULT               equ 0
SCRIPT_SEAFOAMISLANDSB3F_OBJECT_MOVING1        equ 1
SCRIPT_SEAFOAMISLANDSB3F_OBJECT_MOVING2        equ 3

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
SeafoamIslandsB3F_Script:
    call EnableAutoTextBoxDrawing
    mov esi, wMiscFlags
    setc ah                     ; SM83 `bit` preserves C — stash it
    test byte [ebp + esi], (1 << (BIT_PUSHED_BOULDER))
    bt   eax, 8                 ; CF = AH bit 0 = saved C; ZF untouched
    pushfd    ; SM83 form writes no flags
        and byte [ebp + esi], ~(1 << (BIT_PUSHED_BOULDER)) & 0xFF
    popfd
    jz .noBoulderWasPushed
    mov esi, Seafoam4HolesCoords
    call CheckBoulderCoords
    jb .nr_9
        ret
.nr_9:
    mov esi, wEventFlags + EVENT_BYTE(EVENT_SEAFOAM4_BOULDER1_DOWN_HOLE)
    %assign event_byte EVENT_BYTE(EVENT_SEAFOAM4_BOULDER1_DOWN_HOLE)
    mov al, [ebp + wCoordIndex]
    cmp al, 0x1
    jnz .boulder2FellDownHole
    SetEventReuseHL EVENT_SEAFOAM4_BOULDER1_DOWN_HOLE
    mov al, TOGGLE_SEAFOAM_ISLANDS_B3F_BOULDER_1
    mov [ebp + wObjectToHide], al
    mov al, TOGGLE_SEAFOAM_ISLANDS_B4F_BOULDER_1
    mov [ebp + wObjectToShow], al
    jmp .hideAndShowBoulderObjects

%assign event_byte -1
%assign event_byte_a -1
.boulder2FellDownHole:
    SetEventAfterBranchReuseHL EVENT_SEAFOAM4_BOULDER2_DOWN_HOLE, EVENT_SEAFOAM4_BOULDER1_DOWN_HOLE
    mov al, TOGGLE_SEAFOAM_ISLANDS_B3F_BOULDER_2
    mov [ebp + wObjectToHide], al
    mov al, TOGGLE_SEAFOAM_ISLANDS_B4F_BOULDER_2
    mov [ebp + wObjectToShow], al
.hideAndShowBoulderObjects:
    mov al, [ebp + wObjectToHide]
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call HideObject
    mov al, [ebp + wObjectToShow]
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call ShowObject
    jmp .runCurrentMapScript

%assign event_byte -1
%assign event_byte_a -1
.noBoulderWasPushed:
    mov al, SEAFOAM_ISLANDS_B4F
    mov [ebp + wDungeonWarpDestinationMap], al
    mov esi, Seafoam4HolesCoords
    call IsPlayerOnDungeonWarp
    mov al, [ebp + wStatusFlags6]
    test al, (1 << (BIT_DUNGEON_WARP))
    jz .nr_41
        ret
.nr_41:
.runCurrentMapScript:
    mov esi, SeafoamIslandsB3F_ScriptPointers
    mov al, [ebp + wSeafoamIslandsB3FCurScript]
    jmp CallFunctionInTable

%assign event_byte -1
%assign event_byte_a -1
Seafoam4HolesCoords:
    db 16, 3
    db 16, 6
    db -1
SeafoamIslandsB3F_ScriptPointers:
    dd SeafoamIslandsB3FDefaultScript
    dd SeafoamIslandsB3FObjectMoving1Script
    dd SeafoamIslandsB3FMoveObjectScript
    dd SeafoamIslandsB3FObjectMoving2Script

%assign event_byte -1
%assign event_byte_a -1
SeafoamIslandsB3FDefaultScript:
    CheckBothEventsSet EVENT_SEAFOAM3_BOULDER1_DOWN_HOLE, EVENT_SEAFOAM3_BOULDER2_DOWN_HOLE
    jnz .nr_62
        ret
.nr_62:
    mov al, [ebp + wYCoord]
    cmp al, 8
    jz .nr_65
        ret
.nr_65:
    mov al, [ebp + wXCoord]
    cmp al, 15
    jz .nr_68
        ret
.nr_68:
    mov esi, wSimulatedJoypadStatesEnd
    mov edi, RLEList_ForcedSurfingStrongCurrentNearSteps   ; pret: ld de, RLEList_ForcedSurfingStrongCurrentNearSteps — DecodeRLEList takes it in EDI
    call DecodeRLEList
    dec al
    mov [ebp + wSimulatedJoypadStatesIndex], al
    call StartSimulatingJoypadStates
    mov esi, wStatusFlags7
    or byte [ebp + esi], (1 << (BIT_FORCED_WARP))
    mov al, SCRIPT_SEAFOAMISLANDSB3F_OBJECT_MOVING1
    mov [ebp + wSeafoamIslandsB3FCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
RLEList_ForcedSurfingStrongCurrentNearSteps:
    db PAD_DOWN, 6
    db PAD_RIGHT, 5
    db PAD_DOWN, 3
    db -1

%assign event_byte -1
%assign event_byte_a -1
SeafoamIslandsB3FObjectMoving1Script:
    mov al, [ebp + wSimulatedJoypadStatesIndex]
    test al, al
    jz .nr_90
        ret
.nr_90:
    mov al, SCRIPT_SEAFOAMISLANDSB3F_DEFAULT
    mov [ebp + wSeafoamIslandsB3FCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
SeafoamIslandsB3FMoveObjectScript:
    CheckBothEventsSet EVENT_SEAFOAM3_BOULDER1_DOWN_HOLE, EVENT_SEAFOAM3_BOULDER2_DOWN_HOLE
    jnz .nr_97
        ret
.nr_97:
    mov al, [ebp + wXCoord]
    cmp al, 18
    jz .playerFellThroughHoleLeft
    cmp al, 19
    mov al, SCRIPT_SEAFOAMISLANDSB3F_DEFAULT
    jnz .playerNotInStrongCurrent
    mov edi, .RLEList_StrongCurrentNearRightBoulder   ; pret: ld de, .RLEList_StrongCurrentNearRightBoulder — DecodeRLEList takes it in EDI
    jmp .forceSurfMovement

%assign event_byte -1
%assign event_byte_a -1
.playerFellThroughHoleLeft:
    mov edi, .RLEList_StrongCurrentNearLeftBoulder   ; pret: ld de, .RLEList_StrongCurrentNearLeftBoulder — DecodeRLEList takes it in EDI
.forceSurfMovement:
    mov esi, wSimulatedJoypadStatesEnd
    call DecodeRLEList
    dec al
    mov [ebp + wSimulatedJoypadStatesIndex], al
    xor al, al
    mov [ebp + wSpritePlayerStateData2MovementByte1], al
    mov esi, wStatusFlags5
    or byte [ebp + esi], (1 << (BIT_SCRIPTED_MOVEMENT_STATE))
    mov esi, wStatusFlags7
    or byte [ebp + esi], (1 << (BIT_FORCED_WARP))
    mov al, SCRIPT_SEAFOAMISLANDSB3F_OBJECT_MOVING2
.playerNotInStrongCurrent:
    mov [ebp + wSeafoamIslandsB3FCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
.RLEList_StrongCurrentNearRightBoulder:
    db PAD_DOWN, 6
    db PAD_RIGHT, 2
    db PAD_DOWN, 4
    db PAD_LEFT, 1
    db -1
.RLEList_StrongCurrentNearLeftBoulder:
    db PAD_DOWN, 6
    db PAD_RIGHT, 2
    db PAD_DOWN, 4
    db -1

%assign event_byte -1
%assign event_byte_a -1
SeafoamIslandsB3FObjectMoving2Script:
    mov al, [ebp + wSimulatedJoypadStatesIndex]
    test al, al
    jz .nr_140
        ret
.nr_140:
    mov al, SCRIPT_SEAFOAMISLANDSB3F_DEFAULT
    mov [ebp + wSeafoamIslandsB3FCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
SeafoamIslandsB3F_TextPointers:
    dd BoulderText
    dd BoulderText
    dd BoulderText
    dd BoulderText
    dd BoulderText
    dd BoulderText
