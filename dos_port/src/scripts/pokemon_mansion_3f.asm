; PokemonMansion3F.asm — translated from pret scripts/PokemonMansion3F.asm by dos_port/tools/sm83xlat.
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
%include "assets/trainer_headers.inc"

global Mansion3CheckReplaceSwitchDoorBlocks
global PokemonMansion3FDefaultScript
global PokemonMansion3FScientistText
global PokemonMansion3FSuperNerdText
global PokemonMansion3F_Script
global PokemonMansion3F_ScriptPointers

extern ArePlayerCoordsInArray
extern CheckFightingMapTrainers
extern DisplayEnemyTrainerTextAndStartBattle
extern EnableAutoTextBoxDrawing
extern EndTrainerBattle
extern ExecuteCurMapScriptInTable
extern Mansion2ReplaceBlock   ; NOT YET DEFINED IN THE PORT
extern Mansion3Script_Switches
extern Mansion3TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern Mansion3TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern Mansion3TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern PokemonMansion3FSuperNerdBattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonMansion3F_TextPointers   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer
extern TextScriptEnd

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wCoordIndex                                    equ 0xCD3D
wDungeonWarpDestinationMap                     equ 0xD71C
wPokemonMansion3FCurScript                     equ 0xD63C

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
PokemonMansion3F_Script:
    call Mansion3CheckReplaceSwitchDoorBlocks
    call EnableAutoTextBoxDrawing
    mov esi, Mansion3TrainerHeaders
    mov edi, PokemonMansion3F_ScriptPointers   ; pret: ld de, PokemonMansion3F_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wPokemonMansion3FCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wPokemonMansion3FCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
Mansion3CheckReplaceSwitchDoorBlocks:
    mov esi, wCurrentMapScriptFlags
    test byte [ebp + esi], (1 << (BIT_CUR_MAP_LOADED_1))
    pushfd    ; SM83 form writes no flags
        and byte [ebp + esi], ~(1 << (BIT_CUR_MAP_LOADED_1)) & 0xFF
    popfd
    jnz .nr_15
        ret
.nr_15:
    CheckEvent EVENT_MANSION_SWITCH_ON
    jnz .switchTurnedOn
    mov al, 0xe
    mov bx, ((2) << 8) | (7)
    call Mansion2ReplaceBlock
    mov al, 0x5f
    mov bx, ((5) << 8) | (7)
    call Mansion2ReplaceBlock
    ret

%assign event_byte -1
%assign event_byte_a -1
.switchTurnedOn:
    mov al, 0x5f
    mov bx, ((2) << 8) | (7)
    call Mansion2ReplaceBlock
    mov al, 0xe
    mov bx, ((5) << 8) | (7)
    call Mansion2ReplaceBlock
    ret

%assign event_byte -1
%assign event_byte_a -1
PokemonMansion3F_ScriptPointers:
    dd PokemonMansion3FDefaultScript
    dd DisplayEnemyTrainerTextAndStartBattle
    dd EndTrainerBattle

%assign event_byte -1
%assign event_byte_a -1
PokemonMansion3FDefaultScript:
    mov esi, .holeCoords
    call .isPlayerFallingDownHole
    mov al, [ebp + wWhichDungeonWarp]
    test al, al
    jz CheckFightingMapTrainers
    cmp al, 0x3
    mov al, POKEMON_MANSION_1F
    jnz .fellDownHoleTo1F
    mov al, POKEMON_MANSION_2F
.fellDownHoleTo1F:
    mov [ebp + wDungeonWarpDestinationMap], al
    ret

%assign event_byte -1
%assign event_byte_a -1
.holeCoords:
    db 14, 16
    db 14, 17
    db 14, 19
    db -1

%assign event_byte -1
%assign event_byte_a -1
.isPlayerFallingDownHole:
    xor al, al
    mov [ebp + wWhichDungeonWarp], al
    mov al, [ebp + wStatusFlags3]
    setc ah                     ; SM83 `bit` preserves C — stash it
    test al, (1 << (4))
    bt   eax, 8                 ; CF = AH bit 0 = saved C; ZF untouched
    jz .nr_65
        ret
.nr_65:
    call ArePlayerCoordsInArray
    jb .nr_67
        ret
.nr_67:
    mov al, [ebp + wCoordIndex]
    mov [ebp + wWhichDungeonWarp], al
    mov esi, wStatusFlags3
    or byte [ebp + esi], (1 << (4))
    mov esi, wStatusFlags6
    or byte [ebp + esi], (1 << (BIT_DUNGEON_WARP))
    ret

; Mansion3Script_Switches (scripts/PokemonMansion3F.asm:77-84) — not re-emitted: Mansion3Script_Switches is already defined elsewhere in the port.

; PokemonMansion3F_TextPointers (scripts/PokemonMansion3F.asm:87-101) — not re-emitted: Mansion3TrainerHeaders is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
PokemonMansion3FSuperNerdText:
    mov esi, Mansion3TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
PokemonMansion3FScientistText:
    mov esi, Mansion3TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

; PokemonMansion3FSuperNerdBattleText (scripts/PokemonMansion3F.asm:116-141) — not re-emitted: PokemonMansion3FSuperNerdBattleText is already defined in assets/trainer_headers.inc.
