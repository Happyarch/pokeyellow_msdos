; VictoryRoad1F.asm — translated from pret scripts/VictoryRoad1F.asm by dos_port/tools/sm83xlat.
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

; Trainer headers and battle text are DEFINED once, by the single carrier
; src/data/trainer_headers.asm. Declare what this script uses; do NOT %include
; assets/trainer_headers.inc here — the asset DEFINES all 1302 symbols, so an
; include makes every one of them a duplicate global the moment a second script
; links. (That is what kept 202 link-ready scripts out of the build.)
extern VictoryRoad1FCooltrainerFBattleText ; assets/trainer_headers.inc
extern VictoryRoad1TrainerHeader0          ; assets/trainer_headers.inc
extern VictoryRoad1TrainerHeader1          ; assets/trainer_headers.inc
extern VictoryRoad1TrainerHeaders          ; assets/trainer_headers.inc

global VictoryRoad1FCooltrainerFText
global VictoryRoad1FCooltrainerMText
global VictoryRoad1FDefaultScript
global VictoryRoad1F_Script
global VictoryRoad1F_ScriptPointers

extern CheckBoulderCoords
extern CheckFightingMapTrainers
extern DisplayEnemyTrainerTextAndStartBattle
extern EnableAutoTextBoxDrawing
extern EndTrainerBattle
extern ExecuteCurMapScriptInTable
extern ReplaceTileBlock
extern TalkToTrainer
extern TextScriptEnd
extern VictoryRoad1FCooltrainerFBattleText
extern VictoryRoad1TrainerHeader0
extern VictoryRoad1TrainerHeader1
extern VictoryRoad1TrainerHeaders

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
VictoryRoad1F_Script:
    mov esi, wCurrentMapScriptFlags
    test byte [ebp + esi], (1 << (BIT_CUR_MAP_LOADED_1))
    pushfd    ; SM83 form writes no flags
        and byte [ebp + esi], ~(1 << (BIT_CUR_MAP_LOADED_1)) & 0xFF
    popfd
    jz .sk_5
        call .next
.sk_5:
    call EnableAutoTextBoxDrawing
    mov esi, VictoryRoad1TrainerHeaders
    mov edi, VictoryRoad1F_ScriptPointers   ; pret: ld de, VictoryRoad1F_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wVictoryRoad1FCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wVictoryRoad1FCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
.next:
    CheckEvent EVENT_VICTORY_ROAD_1_BOULDER_ON_SWITCH
    jnz .nr_15
        ret
.nr_15:
    mov al, 0x1d
    mov [ebp + wNewTileBlockID], al
    mov bx, ((6) << 8) | (4)
; DEVIATION{class=banking; pret=macros/predef.asm:predef_jump; behavior=Predef dispatch replaced by a direct jmp, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    jmp ReplaceTileBlock

%assign event_byte -1
%assign event_byte_a -1
VictoryRoad1F_ScriptPointers:
    dd VictoryRoad1FDefaultScript
    dd DisplayEnemyTrainerTextAndStartBattle
    dd EndTrainerBattle

%assign event_byte -1
%assign event_byte_a -1
VictoryRoad1FDefaultScript:
    CheckEvent EVENT_VICTORY_ROAD_1_BOULDER_ON_SWITCH
    jnz CheckFightingMapTrainers
    mov esi, .SwitchCoords
    call CheckBoulderCoords
    jae CheckFightingMapTrainers
    mov al, [ebp + hSpriteIndex]
    cmp al, PIKACHU_SPRITE_INDEX
    jz CheckFightingMapTrainers
    mov esi, wCurrentMapScriptFlags
    or byte [ebp + esi], (1 << (BIT_CUR_MAP_LOADED_1))
    SetEvent EVENT_VICTORY_ROAD_1_BOULDER_ON_SWITCH
    ret

%assign event_byte -1
%assign event_byte_a -1
.SwitchCoords:
    db 13, 17
    db -1 ; end

; VictoryRoad1FDefaultScript.SwitchCoords (scripts/VictoryRoad1F.asm:42-61) — not re-emitted: VictoryRoad1TrainerHeaders is already defined in assets/trainer_headers.inc. Restored .SwitchCoords sibling.

%assign event_byte -1
%assign event_byte_a -1
VictoryRoad1FCooltrainerFText:
    mov esi, VictoryRoad1TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
VictoryRoad1FCooltrainerMText:
    mov esi, VictoryRoad1TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

; VictoryRoad1FCooltrainerFBattleText (scripts/VictoryRoad1F.asm:76-97) — not re-emitted: VictoryRoad1FCooltrainerFBattleText is already defined in assets/trainer_headers.inc.
