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
%include "assets/script_constants.inc"


global SeafoamIslandsB4FArticunoBattleText
global SeafoamIslandsB4FArticunoText
global SeafoamIslandsB4FBouldersSignText
global SeafoamIslandsB4FDangerSignText
global SeafoamIslandsB4FDefaultScript
global SeafoamIslandsB4FMoveObjectScript
global SeafoamIslandsB4FObjectMoving1Script
global SeafoamIslandsB4FObjectMoving2Script
global SeafoamIslandsB4FObjectMoving3Script
global SeafoamIslandsB4FResetScript
global SeafoamIslandsB4F_Script
global SeafoamIslandsB4F_ScriptPointers

extern ArePlayerCoordsInArray
extern ArticunoTrainerHeader   ; NOT YET DEFINED IN THE PORT
extern BoulderText   ; NOT YET DEFINED IN THE PORT
extern CallFunctionInTable
extern DecodeRLEList
extern EnableAutoTextBoxDrawing
extern EndTrainerBattle
extern ExecuteCurMapScriptInTable
extern ForceBikeOrSurf
extern PlayCry
extern SeafoamIslandsB4F_TextPointers   ; NOT YET DEFINED IN THE PORT
extern StartSimulatingJoypadStates
extern TalkToTrainer
extern TextScriptEnd
extern WaitForSoundToFinish
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

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wCoordIndex                                    equ 0xCD3D
wSeafoamIslandsB4FCurScript                    equ 0xD667

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
SeafoamIslandsB4F_Script:
    call EnableAutoTextBoxDrawing
    mov al, [ebp + wSeafoamIslandsB4FCurScript]
    mov esi, SeafoamIslandsB4F_ScriptPointers
    jmp CallFunctionInTable

%assign event_byte -1
%assign event_byte_a -1
SeafoamIslandsB4FResetScript:
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov [ebp + wSeafoamIslandsB4FCurScript], al
    mov [ebp + wCurMapScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
SeafoamIslandsB4F_ScriptPointers:
    dd SeafoamIslandsB4FDefaultScript
    dd SeafoamIslandsB4FObjectMoving1Script
    dd SeafoamIslandsB4FMoveObjectScript
    dd SeafoamIslandsB4FObjectMoving2Script
    dd SeafoamIslandsB4FObjectMoving3Script

%assign event_byte -1
%assign event_byte_a -1
SeafoamIslandsB4FObjectMoving3Script:
    mov al, [ebp + wIsInBattle]
    cmp al, 0xff
    jz SeafoamIslandsB4FResetScript
    call EndTrainerBattle
    mov al, SCRIPT_SEAFOAMISLANDSB4F_DEFAULT
    mov [ebp + wSeafoamIslandsB4FCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
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

%assign event_byte -1
%assign event_byte_a -1
.only1UpInputNeeded:
    mov al, 1
.forcePlayerUpFromSurfExit:
    mov [ebp + wSimulatedJoypadStatesIndex], al
    mov al, PAD_UP
    mov [ebp + wSimulatedJoypadStatesEnd], al
    call StartSimulatingJoypadStates
    mov esi, wStatusFlags7
    and byte [ebp + esi], ~(1 << (BIT_FORCED_WARP)) & 0xFF
    mov al, SCRIPT_SEAFOAMISLANDSB4F_OBJECT_MOVING1
    mov [ebp + wSeafoamIslandsB4FCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
.Coords:
    db 17, 20
    db 17, 21
    db 16, 20
    db 16, 21
    db -1

%assign event_byte -1
%assign event_byte_a -1
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

%assign event_byte -1
%assign event_byte_a -1
SeafoamIslandsB4FMoveObjectScript:
    CheckBothEventsSet EVENT_SEAFOAM4_BOULDER1_DOWN_HOLE, EVENT_SEAFOAM4_BOULDER2_DOWN_HOLE
    mov al, SCRIPT_SEAFOAMISLANDSB4F_DEFAULT
    jz .playerNotInStrongCurrent
    mov esi, .Coords
    call ArePlayerCoordsInArray
    mov al, SCRIPT_SEAFOAMISLANDSB4F_DEFAULT
    jae .playerNotInStrongCurrent
    mov al, [ebp + wCoordIndex]
    cmp al, 0x1
    jnz .nearRightBoulder
    mov edi, .RLEList_StrongCurrentNearLeftBoulder   ; pret: ld de, .RLEList_StrongCurrentNearLeftBoulder — DecodeRLEList takes it in EDI
    jmp .forceSurfMovement

%assign event_byte -1
%assign event_byte_a -1
.nearRightBoulder:
    mov edi, .RLEList_StrongCurrentNearRightBoulder   ; pret: ld de, .RLEList_StrongCurrentNearRightBoulder — DecodeRLEList takes it in EDI
.forceSurfMovement:
    mov esi, wSimulatedJoypadStatesEnd
    call DecodeRLEList
    dec al
    mov [ebp + wSimulatedJoypadStatesIndex], al
    call StartSimulatingJoypadStates
    mov al, SCRIPT_SEAFOAMISLANDSB4F_OBJECT_MOVING2
.playerNotInStrongCurrent:
    mov [ebp + wSeafoamIslandsB4FCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
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

%assign event_byte -1
%assign event_byte_a -1
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

%assign event_byte -1
%assign event_byte_a -1
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

%assign event_byte -1
%assign event_byte_a -1
SeafoamIslandsB4FArticunoText:
    mov esi, ArticunoTrainerHeader
    call TalkToTrainer
    mov al, SCRIPT_SEAFOAMISLANDSB4F_OBJECT_MOVING3
    mov [ebp + wSeafoamIslandsB4FCurScript], al
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
SeafoamIslandsB4FArticunoBattleText:
    text_far _SeafoamIslandsB4FArticunoBattleText

%assign event_byte -1
%assign event_byte_a -1
    mov al, 74
    call PlayCry
    call WaitForSoundToFinish
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
SeafoamIslandsB4FBouldersSignText:
    text_far _SeafoamIslandsB4FBouldersSignText
    text_end
SeafoamIslandsB4FDangerSignText:
    text_far _SeafoamIslandsB4FDangerSignText
    text_end
