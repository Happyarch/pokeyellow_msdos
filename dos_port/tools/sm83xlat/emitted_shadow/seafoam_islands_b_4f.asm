; SeafoamIslandsB4F.asm — translated from pret scripts/SeafoamIslandsB4F.asm by dos_port/tools/sm83xlat.
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


global SeafoamIslandsB4FArticunoBattleText
global SeafoamIslandsB4FArticunoText
global SeafoamIslandsB4FBouldersSignText
global SeafoamIslandsB4FDangerSignText
global SeafoamIslandsB4FDefaultScript
global SeafoamIslandsB4FObjectMoving1Script
global SeafoamIslandsB4FObjectMoving2Script
global SeafoamIslandsB4FObjectMoving3Script
global SeafoamIslandsB4FResetScript
global SeafoamIslandsB4F_Script
global SeafoamIslandsB4F_ScriptPointers

extern ArePlayerCoordsInArray   ; NOT YET DEFINED IN THE PORT
extern ArticunoTrainerHeader   ; NOT YET DEFINED IN THE PORT
extern BoulderText   ; NOT YET DEFINED IN THE PORT
extern CallFunctionInTable   ; NOT YET DEFINED IN THE PORT
extern DecodeRLEList   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EndTrainerBattle   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern ForceBikeOrSurf   ; NOT YET DEFINED IN THE PORT
extern PlayCry   ; NOT YET DEFINED IN THE PORT
extern SeafoamIslandsB4FMoveObjectScript   ; NOT YET DEFINED IN THE PORT
extern SeafoamIslandsB4F_TextPointers   ; NOT YET DEFINED IN THE PORT
extern StartSimulatingJoypadStates   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern WaitForSoundToFinish   ; NOT YET DEFINED IN THE PORT
extern _SeafoamIslandsB4FArticunoBattleText   ; NOT YET DEFINED IN THE PORT
extern _SeafoamIslandsB4FBouldersSignText   ; NOT YET DEFINED IN THE PORT
extern _SeafoamIslandsB4FDangerSignText   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_SEAFOAMISLANDSB4F_DEFAULT               equ 0
SCRIPT_SEAFOAMISLANDSB4F_OBJECT_MOVING1        equ 1
SCRIPT_SEAFOAMISLANDSB4F_OBJECT_MOVING2        equ 3
SCRIPT_SEAFOAMISLANDSB4F_OBJECT_MOVING3        equ 4
TEXT_SEAFOAMISLANDSB4F_BOULDER1                equ 1
TEXT_SEAFOAMISLANDSB4F_BOULDER2                equ 2
TEXT_SEAFOAMISLANDSB4F_ARTICUNO                equ 3
TEXT_SEAFOAMISLANDSB4F_BOULDERS_SIGN           equ 4
TEXT_SEAFOAMISLANDSB4F_DANGER_SIGN             equ 5

; pret RAM names the port still spells in SCREAMING_SNAKE. Guarded, so
; this file assembles both before and after the memmap rename lands.
%ifndef wSimulatedJoypadStatesEnd
wSimulatedJoypadStatesEnd                      equ W_SIMULATED_JOYPAD_STATES_END
%endif
%ifndef wSimulatedJoypadStatesIndex
wSimulatedJoypadStatesIndex                    equ W_SIMULATED_JOYPAD_STATES_INDEX
%endif

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wCoordIndex                                    equ 0xCD3D
wSeafoamIslandsB4FCurScript                    equ 0xD667

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

SeafoamIslandsB4F_Script:
    call EnableAutoTextBoxDrawing
    mov al, [ebp + wSeafoamIslandsB4FCurScript]
    mov esi, SeafoamIslandsB4F_ScriptPointers
    jmp CallFunctionInTable

SeafoamIslandsB4FResetScript:
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov [ebp + wSeafoamIslandsB4FCurScript], al
    mov [ebp + wCurMapScript], al
    ret

SeafoamIslandsB4F_ScriptPointers:
    dd SeafoamIslandsB4FDefaultScript
    dd SeafoamIslandsB4FObjectMoving1Script
    dd SeafoamIslandsB4FMoveObjectScript
    dd SeafoamIslandsB4FObjectMoving2Script
    dd SeafoamIslandsB4FObjectMoving3Script

SeafoamIslandsB4FObjectMoving3Script:
    mov al, [ebp + wIsInBattle]
    cmp al, 0xff
    jz SeafoamIslandsB4FResetScript
    call EndTrainerBattle
    mov al, SCRIPT_SEAFOAMISLANDSB4F_DEFAULT
    mov [ebp + wSeafoamIslandsB4FCurScript], al
    ret

SeafoamIslandsB4FDefaultScript:
    CheckBothEventsSet EVENT_SEAFOAM3_BOULDER1_DOWN_HOLE, EVENT_SEAFOAM3_BOULDER2_DOWN_HOLE
    jnz .nr_34
        ret
.nr_34:
    mov esi, .Coords
    call ArePlayerCoordsInArray
    jb .nr_37
        ret
.nr_37:
    mov al, [ebp + wCoordIndex]
    cmp al, 0x3
    jae .only1UpInputNeeded
    mov al, PAD_UP
    mov [ebp + wSimulatedJoypadStatesEnd + 1], al
    mov al, 2
    jmp .forcePlayerUpFromSurfExit

.only1UpInputNeeded:
    mov al, 1
.forcePlayerUpFromSurfExit:
    mov [ebp + wSimulatedJoypadStatesIndex], al
    mov al, PAD_UP
    mov [ebp + wSimulatedJoypadStatesEnd], al
    call StartSimulatingJoypadStates
    mov esi, wStatusFlags7
    and byte [ebp + esi], ~(1 << (2)) & 0xFF
    mov al, SCRIPT_SEAFOAMISLANDSB4F_OBJECT_MOVING1
    mov [ebp + wSeafoamIslandsB4FCurScript], al
    ret

.Coords:
    db 17, 20
    db 17, 21
    db 16, 20
    db 16, 21
    db -1

SeafoamIslandsB4FObjectMoving1Script:
    mov al, [ebp + wSimulatedJoypadStatesIndex]
    test al, al
    jz .nr_68
        ret
.nr_68:
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov al, SCRIPT_SEAFOAMISLANDSB4F_DEFAULT
    mov [ebp + wSeafoamIslandsB4FCurScript], al
    ret

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] SeafoamIslandsB4FMoveObjectScript (scripts/SeafoamIslandsB4F.asm:76-87) — at scripts/SeafoamIslandsB4F.asm:78: .playerNotInStrongCurrent is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckBothEventsSet EVENT_SEAFOAM4_BOULDER1_DOWN_HOLE, EVENT_SEAFOAM4_BOULDER2_DOWN_HOLE
; PRET| 	ld a, SCRIPT_SEAFOAMISLANDSB4F_DEFAULT
; PRET| 	jr z, .playerNotInStrongCurrent
; PRET| 	ld hl, .Coords
; PRET| 	call ArePlayerCoordsInArray
; PRET| 	ld a, SCRIPT_SEAFOAMISLANDSB4F_DEFAULT
; PRET| 	jr nc, .playerNotInStrongCurrent
; PRET| 	ld a, [wCoordIndex]
; PRET| 	cp $1
; PRET| 	jr nz, .nearRightBoulder
; PRET| 	ld de, .RLEList_StrongCurrentNearLeftBoulder
; PRET| 	jr .forceSurfMovement

; ---------------------------------------------------------------------------
; BAIL[host-pointer-in-16bit-reg] SeafoamIslandsB4FMoveObjectScript.nearRightBoulder (scripts/SeafoamIslandsB4F.asm:89-99) — at scripts/SeafoamIslandsB4F.asm:89: de cannot hold the 32-bit address of .RLEList_StrongCurrentNearRightBoulder; callee DecodeRLEList has no abi.json entry
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld de, .RLEList_StrongCurrentNearRightBoulder
; PRET| .forceSurfMovement
; PRET| 	ld hl, wSimulatedJoypadStatesEnd
; PRET| 	call DecodeRLEList
; PRET| 	dec a
; PRET| 	ld [wSimulatedJoypadStatesIndex], a
; PRET| 	call StartSimulatingJoypadStates
; PRET| 	ld a, SCRIPT_SEAFOAMISLANDSB4F_OBJECT_MOVING2
; PRET| .playerNotInStrongCurrent
; PRET| 	ld [wSeafoamIslandsB4FCurScript], a
; PRET| 	ret

.Coords:
    db 14, 4
    db 14, 5
    db -1
.RLEList_StrongCurrentNearRightBoulder:
    db PAD_UP, 3
    db PAD_RIGHT, 2
    db PAD_UP, 1
    db -1
.RLEList_StrongCurrentNearLeftBoulder:
    db PAD_UP, 3
    db PAD_RIGHT, 3
    db PAD_UP, 1
    db -1

SeafoamIslandsB4FObjectMoving2Script:
    mov al, [ebp + wSimulatedJoypadStatesIndex]
    mov bh, al
    cmp al, 0x1
    jnz .sk_122
        call .doneForcedSurfMovement
.sk_122:
    mov al, bh
    test al, al
    jz .nr_125
        ret
.nr_125:
    mov al, SCRIPT_SEAFOAMISLANDSB4F_DEFAULT
    mov [ebp + wSeafoamIslandsB4FCurScript], al
    ret

.doneForcedSurfMovement:
    xor al, al
    mov [ebp + wWalkBikeSurfState], al
    mov [ebp + wWalkBikeSurfStateCopy], al
    jmp ForceBikeOrSurf

; ---------------------------------------------------------------------------
; BAIL[owned-by-gen_map_script_tables] SeafoamIslandsB4F_TextPointers (scripts/SeafoamIslandsB4F.asm:137-150) — at scripts/SeafoamIslandsB4F.asm:149: trainer EVENT_BEAT_ARTICUNO, 0, SeafoamIslandsB4FArticunoBattleText, SeafoamIslandsB4FArticunoBattleText, SeafoamIslandsB4FArticunoBattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	def_text_pointers
; PRET| 	dw_const BoulderText,                       TEXT_SEAFOAMISLANDSB4F_BOULDER1
; PRET| 	dw_const BoulderText,                       TEXT_SEAFOAMISLANDSB4F_BOULDER2
; PRET| 	dw_const SeafoamIslandsB4FArticunoText,     TEXT_SEAFOAMISLANDSB4F_ARTICUNO
; PRET| 	dw_const SeafoamIslandsB4FBouldersSignText, TEXT_SEAFOAMISLANDSB4F_BOULDERS_SIGN
; PRET| 	dw_const SeafoamIslandsB4FDangerSignText,   TEXT_SEAFOAMISLANDSB4F_DANGER_SIGN
; PRET| 
; PRET| ; Articuno is object 3, but its event flag is bit 2.
; PRET| ; This is not a problem because its sight range is 0, and
; PRET| ; trainer headers were not stored by ExecuteCurMapScriptInTable.
; PRET| 	def_trainers 2
; PRET| ArticunoTrainerHeader:
; PRET| 	trainer EVENT_BEAT_ARTICUNO, 0, SeafoamIslandsB4FArticunoBattleText, SeafoamIslandsB4FArticunoBattleText, SeafoamIslandsB4FArticunoBattleText
; PRET| 	db -1 ; end

SeafoamIslandsB4FArticunoText:
    mov esi, ArticunoTrainerHeader
    call TalkToTrainer
    mov al, SCRIPT_SEAFOAMISLANDSB4F_OBJECT_MOVING3
    mov [ebp + wSeafoamIslandsB4FCurScript], al
    jmp TextScriptEnd

SeafoamIslandsB4FArticunoBattleText:
    text_far _SeafoamIslandsB4FArticunoBattleText

    mov al, 74
    call PlayCry
    call WaitForSoundToFinish
    jmp TextScriptEnd

SeafoamIslandsB4FBouldersSignText:
    text_far _SeafoamIslandsB4FBouldersSignText
    text_end
SeafoamIslandsB4FDangerSignText:
    text_far _SeafoamIslandsB4FDangerSignText
    text_end
