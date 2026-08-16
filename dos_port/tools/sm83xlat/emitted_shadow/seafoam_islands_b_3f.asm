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

%include "assets/map_dims.inc"

global RLEList_ForcedSurfingStrongCurrentNearSteps
global Seafoam4HolesCoords
global SeafoamIslandsB3FObjectMoving1Script
global SeafoamIslandsB3FObjectMoving2Script
global SeafoamIslandsB3F_ScriptPointers
global SeafoamIslandsB3F_TextPointers

extern BoulderText   ; NOT YET DEFINED IN THE PORT
extern CallFunctionInTable   ; NOT YET DEFINED IN THE PORT
extern CheckBoulderCoords   ; NOT YET DEFINED IN THE PORT
extern DecodeRLEList   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern HideObject   ; NOT YET DEFINED IN THE PORT
extern IsPlayerOnDungeonWarp   ; NOT YET DEFINED IN THE PORT
extern SeafoamIslandsB3FDefaultScript   ; NOT YET DEFINED IN THE PORT
extern SeafoamIslandsB3FMoveObjectScript   ; NOT YET DEFINED IN THE PORT
extern SeafoamIslandsB3F_Script   ; NOT YET DEFINED IN THE PORT
extern ShowObject   ; NOT YET DEFINED IN THE PORT
extern StartSimulatingJoypadStates   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_SEAFOAMISLANDSB3F_DEFAULT               equ 0
SCRIPT_SEAFOAMISLANDSB3F_OBJECT_MOVING1        equ 1
SCRIPT_SEAFOAMISLANDSB3F_OBJECT_MOVING2        equ 3

; pret RAM names the port still spells in SCREAMING_SNAKE. Guarded, so
; this file assembles both before and after the memmap rename lands.
%ifndef wSimulatedJoypadStatesEnd
wSimulatedJoypadStatesEnd                      equ W_SIMULATED_JOYPAD_STATES_END
%endif
%ifndef wSimulatedJoypadStatesIndex
wSimulatedJoypadStatesIndex                    equ W_SIMULATED_JOYPAD_STATES_INDEX
%endif
%ifndef wXCoord
wXCoord                                        equ W_X_COORD
%endif
%ifndef wYCoord
wYCoord                                        equ W_Y_COORD
%endif

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wCoordIndex                                    equ 0xCD3D
wDungeonWarpDestinationMap                     equ 0xD71C
wObjectToHide                                  equ 0xD078
wObjectToShow                                  equ 0xD079
wSeafoamIslandsB3FCurScript                    equ 0xD665
wSpritePlayerStateData2MovementByte1           equ 0xC206

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

; ---------------------------------------------------------------------------
; BAIL[bit-clobbers-live-carry] SeafoamIslandsB3F_Script (scripts/SeafoamIslandsB3F.asm:2-19) — at scripts/SeafoamIslandsB3F.asm:4: bit BIT_PUSHED_BOULDER, [hl]
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	call EnableAutoTextBoxDrawing
; PRET| 	ld hl, wMiscFlags
; PRET| 	bit BIT_PUSHED_BOULDER, [hl]
; PRET| 	res BIT_PUSHED_BOULDER, [hl]
; PRET| 	jr z, .noBoulderWasPushed
; PRET| 	ld hl, Seafoam4HolesCoords
; PRET| 	call CheckBoulderCoords
; PRET| 	ret nc
; PRET| 	EventFlagAddress hl, EVENT_SEAFOAM4_BOULDER1_DOWN_HOLE
; PRET| 	ld a, [wCoordIndex]
; PRET| 	cp $1
; PRET| 	jr nz, .boulder2FellDownHole
; PRET| 	SetEventReuseHL EVENT_SEAFOAM4_BOULDER1_DOWN_HOLE
; PRET| 	ld a, TOGGLE_SEAFOAM_ISLANDS_B3F_BOULDER_1
; PRET| 	ld [wObjectToHide], a
; PRET| 	ld a, TOGGLE_SEAFOAM_ISLANDS_B4F_BOULDER_1
; PRET| 	ld [wObjectToShow], a
; PRET| 	jr .hideAndShowBoulderObjects

; ---------------------------------------------------------------------------
; BAIL[event-byte-assembly-state] SeafoamIslandsB3F_Script.boulder2FellDownHole (scripts/SeafoamIslandsB3F.asm:21-33) — at scripts/SeafoamIslandsB3F.asm:21: SetEventAfterBranchReuseHL EVENT_SEAFOAM4_BOULDER2_DOWN_HOLE, EVENT_SEAFOAM4_BOULDER1_DOWN_HOLE
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	SetEventAfterBranchReuseHL EVENT_SEAFOAM4_BOULDER2_DOWN_HOLE, EVENT_SEAFOAM4_BOULDER1_DOWN_HOLE
; PRET| 	ld a, TOGGLE_SEAFOAM_ISLANDS_B3F_BOULDER_2
; PRET| 	ld [wObjectToHide], a
; PRET| 	ld a, TOGGLE_SEAFOAM_ISLANDS_B4F_BOULDER_2
; PRET| 	ld [wObjectToShow], a
; PRET| .hideAndShowBoulderObjects
; PRET| 	ld a, [wObjectToHide]
; PRET| 	ld [wToggleableObjectIndex], a
; PRET| 	predef HideObject
; PRET| 	ld a, [wObjectToShow]
; PRET| 	ld [wToggleableObjectIndex], a
; PRET| 	predef ShowObject
; PRET| 	jr .runCurrentMapScript

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

Seafoam4HolesCoords:
    db 16, 3
    db 16, 6
    db -1
SeafoamIslandsB3F_ScriptPointers:
    dd SeafoamIslandsB3FDefaultScript
    dd SeafoamIslandsB3FObjectMoving1Script
    dd SeafoamIslandsB3FMoveObjectScript
    dd SeafoamIslandsB3FObjectMoving2Script

; ---------------------------------------------------------------------------
; BAIL[host-pointer-in-16bit-reg] SeafoamIslandsB3FDefaultScript (scripts/SeafoamIslandsB3F.asm:61-79) — at scripts/SeafoamIslandsB3F.asm:70: de cannot hold the 32-bit address of RLEList_ForcedSurfingStrongCurrentNearSteps; callee DecodeRLEList has no abi.json entry
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckBothEventsSet EVENT_SEAFOAM3_BOULDER1_DOWN_HOLE, EVENT_SEAFOAM3_BOULDER2_DOWN_HOLE
; PRET| 	ret z
; PRET| 	ld a, [wYCoord]
; PRET| 	cp 8
; PRET| 	ret nz
; PRET| 	ld a, [wXCoord]
; PRET| 	cp 15
; PRET| 	ret nz
; PRET| 	ld hl, wSimulatedJoypadStatesEnd
; PRET| 	ld de, RLEList_ForcedSurfingStrongCurrentNearSteps
; PRET| 	call DecodeRLEList
; PRET| 	dec a
; PRET| 	ld [wSimulatedJoypadStatesIndex], a
; PRET| 	call StartSimulatingJoypadStates
; PRET| 	ld hl, wStatusFlags7
; PRET| 	set BIT_FORCED_WARP, [hl]
; PRET| 	ld a, SCRIPT_SEAFOAMISLANDSB3F_OBJECT_MOVING1
; PRET| 	ld [wSeafoamIslandsB3FCurScript], a
; PRET| 	ret

RLEList_ForcedSurfingStrongCurrentNearSteps:
    db PAD_DOWN, 6
    db PAD_RIGHT, 5
    db PAD_DOWN, 3
    db -1

SeafoamIslandsB3FObjectMoving1Script:
    mov al, [ebp + wSimulatedJoypadStatesIndex]
    test al, al
    jz .nr_90
        ret
.nr_90:
    mov al, SCRIPT_SEAFOAMISLANDSB3F_DEFAULT
    mov [ebp + wSeafoamIslandsB3FCurScript], al
    ret

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] SeafoamIslandsB3FMoveObjectScript (scripts/SeafoamIslandsB3F.asm:96-105) — at scripts/SeafoamIslandsB3F.asm:100: .playerFellThroughHoleLeft is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckBothEventsSet EVENT_SEAFOAM3_BOULDER1_DOWN_HOLE, EVENT_SEAFOAM3_BOULDER2_DOWN_HOLE
; PRET| 	ret z
; PRET| 	ld a, [wXCoord]
; PRET| 	cp 18
; PRET| 	jr z, .playerFellThroughHoleLeft
; PRET| 	cp 19
; PRET| 	ld a, SCRIPT_SEAFOAMISLANDSB3F_DEFAULT
; PRET| 	jr nz, .playerNotInStrongCurrent
; PRET| 	ld de, .RLEList_StrongCurrentNearRightBoulder
; PRET| 	jr .forceSurfMovement

; ---------------------------------------------------------------------------
; BAIL[host-pointer-in-16bit-reg] SeafoamIslandsB3FMoveObjectScript.playerFellThroughHoleLeft (scripts/SeafoamIslandsB3F.asm:107-122) — at scripts/SeafoamIslandsB3F.asm:107: de cannot hold the 32-bit address of .RLEList_StrongCurrentNearLeftBoulder; callee DecodeRLEList has no abi.json entry
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld de, .RLEList_StrongCurrentNearLeftBoulder
; PRET| .forceSurfMovement
; PRET| 	ld hl, wSimulatedJoypadStatesEnd
; PRET| 	call DecodeRLEList
; PRET| 	dec a
; PRET| 	ld [wSimulatedJoypadStatesIndex], a
; PRET| 	xor a
; PRET| 	ld [wSpritePlayerStateData2MovementByte1], a
; PRET| 	ld hl, wStatusFlags5
; PRET| 	set BIT_SCRIPTED_MOVEMENT_STATE, [hl]
; PRET| 	ld hl, wStatusFlags7
; PRET| 	set BIT_FORCED_WARP, [hl]
; PRET| 	ld a, SCRIPT_SEAFOAMISLANDSB3F_OBJECT_MOVING2
; PRET| .playerNotInStrongCurrent
; PRET| 	ld [wSeafoamIslandsB3FCurScript], a
; PRET| 	ret

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

SeafoamIslandsB3FObjectMoving2Script:
    mov al, [ebp + wSimulatedJoypadStatesIndex]
    test al, al
    jz .nr_140
        ret
.nr_140:
    mov al, SCRIPT_SEAFOAMISLANDSB3F_DEFAULT
    mov [ebp + wSeafoamIslandsB3FCurScript], al
    ret

SeafoamIslandsB3F_TextPointers:
    dd BoulderText
    dd BoulderText
    dd BoulderText
    dd BoulderText
    dd BoulderText
    dd BoulderText
