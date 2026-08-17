; VictoryRoad3F.asm — translated from pret scripts/VictoryRoad3F.asm by dos_port/tools/sm83xlat.
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
%include "assets/trainer_headers.inc"

global VictoryRoad3FCheckBoulderEventScript
global VictoryRoad3FCooltrainerF1Text
global VictoryRoad3FCooltrainerF2Text
global VictoryRoad3FCooltrainerM1Text
global VictoryRoad3FCooltrainerM2Text
global VictoryRoad3FDefaultScript
global VictoryRoad3F_Script
global VictoryRoad3F_ScriptPointers

extern CheckBoulderCoords
extern CheckFightingMapTrainers
extern DisplayEnemyTrainerTextAndStartBattle
extern EnableAutoTextBoxDrawing
extern EndTrainerBattle
extern ExecuteCurMapScriptInTable
extern HideObject
extern IsPlayerOnDungeonWarp
extern ReplaceTileBlock
extern ShowObject
extern TalkToTrainer
extern TextScriptEnd
extern VictoryRoad3FCooltrainerM1BattleText
extern VictoryRoad3F_TextPointers   ; NOT YET DEFINED IN THE PORT
extern VictoryRoad3TrainerHeader0
extern VictoryRoad3TrainerHeader1
extern VictoryRoad3TrainerHeader2
extern VictoryRoad3TrainerHeader3
extern VictoryRoad3TrainerHeaders

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wCoordIndex                                    equ 0xCD3D
wDungeonWarpDestinationMap                     equ 0xD71C
wVictoryRoad3FCurScript                        equ 0xD63F

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
VictoryRoad3F_Script:
    call VictoryRoad3FCheckBoulderEventScript
    call EnableAutoTextBoxDrawing
    mov esi, VictoryRoad3TrainerHeaders
    mov edi, VictoryRoad3F_ScriptPointers   ; pret: ld de, VictoryRoad3F_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wVictoryRoad3FCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wVictoryRoad3FCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
VictoryRoad3FCheckBoulderEventScript:
    mov esi, wCurrentMapScriptFlags
    test byte [ebp + esi], (1 << (BIT_CUR_MAP_LOADED_1))
    pushfd    ; SM83 form writes no flags
        and byte [ebp + esi], ~(1 << (BIT_CUR_MAP_LOADED_1)) & 0xFF
    popfd
    jnz .nr_15
        ret
.nr_15:
    mov esi, wEventFlags + EVENT_BYTE(EVENT_VICTORY_ROAD_3_BOULDER_ON_SWITCH1)
    test byte [ebp + esi], EVENT_MASK(EVENT_VICTORY_ROAD_3_BOULDER_ON_SWITCH1)
    jnz .nr_17
        ret
.nr_17:
    mov al, 0x1d
    mov [ebp + wNewTileBlockID], al
    mov bx, ((5) << 8) | (3)
; DEVIATION{class=banking; pret=macros/predef.asm:predef_jump; behavior=Predef dispatch replaced by a direct jmp, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    jmp ReplaceTileBlock

%assign event_byte -1
%assign event_byte_a -1
VictoryRoad3F_ScriptPointers:
    dd VictoryRoad3FDefaultScript
    dd DisplayEnemyTrainerTextAndStartBattle
    dd EndTrainerBattle

%assign event_byte -1
%assign event_byte_a -1
VictoryRoad3FDefaultScript:
    mov esi, wMiscFlags
    setc ah                     ; SM83 `bit` preserves C — stash it
    test byte [ebp + esi], (1 << (BIT_PUSHED_BOULDER))
    bt   eax, 8                 ; CF = AH bit 0 = saved C; ZF untouched
    pushfd    ; SM83 form writes no flags
        and byte [ebp + esi], ~(1 << (BIT_PUSHED_BOULDER)) & 0xFF
    popfd
    jz .check_switch_hole
    mov esi, .SwitchOrHoleCoords
    call CheckBoulderCoords
    jae .check_switch_hole
    mov al, [ebp + wCoordIndex]
    cmp al, 0x1
    jnz .handle_hole
    mov al, [ebp + hSpriteIndex]
    cmp al, PIKACHU_SPRITE_INDEX
    jz .check_switch_hole
    mov esi, wCurrentMapScriptFlags
    or byte [ebp + esi], (1 << (BIT_CUR_MAP_LOADED_1))
    SetEvent EVENT_VICTORY_ROAD_3_BOULDER_ON_SWITCH1
    ret

%assign event_byte -1
%assign event_byte_a -1
.handle_hole:
    CheckAndSetEvent EVENT_VICTORY_ROAD_3_BOULDER_ON_SWITCH2
    jnz .check_switch_hole
    mov al, TOGGLE_VICTORY_ROAD_3F_BOULDER
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call HideObject
    mov al, TOGGLE_VICTORY_ROAD_2F_BOULDER
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef_jump; behavior=Predef dispatch replaced by a direct jmp, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    jmp ShowObject

%assign event_byte -1
%assign event_byte_a -1
.SwitchOrHoleCoords:
    db 5, 3
    db 15, 23
    db -1

%assign event_byte -1
%assign event_byte_a -1
.check_switch_hole:
    mov al, VICTORY_ROAD_2F
    mov [ebp + wDungeonWarpDestinationMap], al
    mov esi, .SwitchOrHoleCoords
    call IsPlayerOnDungeonWarp
    mov al, [ebp + wCoordIndex]
    cmp al, 0x1
    jnz .hole
    mov esi, wStatusFlags3
    and byte [ebp + esi], ~(1 << (BIT_ON_DUNGEON_WARP)) & 0xFF
    mov esi, wStatusFlags6
    and byte [ebp + esi], ~(1 << (BIT_DUNGEON_WARP)) & 0xFF
    ret

%assign event_byte -1
%assign event_byte_a -1
.hole:
    mov al, [ebp + wStatusFlags3]
    test al, (1 << (BIT_ON_DUNGEON_WARP))
    jz CheckFightingMapTrainers
    ret

; VictoryRoad3F_TextPointers (scripts/VictoryRoad3F.asm:82-104) — not re-emitted: VictoryRoad3TrainerHeaders is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
VictoryRoad3FCooltrainerM1Text:
    mov esi, VictoryRoad3TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
VictoryRoad3FCooltrainerF1Text:
    mov esi, VictoryRoad3TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
VictoryRoad3FCooltrainerM2Text:
    mov esi, VictoryRoad3TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
VictoryRoad3FCooltrainerF2Text:
    mov esi, VictoryRoad3TrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

; VictoryRoad3FCooltrainerM1BattleText (scripts/VictoryRoad3F.asm:131-176) — not re-emitted: VictoryRoad3FCooltrainerM1BattleText is already defined in assets/trainer_headers.inc.
