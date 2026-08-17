; VictoryRoad2F.asm — translated from pret scripts/VictoryRoad2F.asm by dos_port/tools/sm83xlat.
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

%include "assets/trainer_headers.inc"

global VictoryRoad2FCheckBoulderEventScript
global VictoryRoad2FCooltrainerMText
global VictoryRoad2FHikerText
global VictoryRoad2FMoltresText
global VictoryRoad2FReplaceTileBlockScript
global VictoryRoad2FResetBoulderEventScript
global VictoryRoad2FSuperNerd1Text
global VictoryRoad2FSuperNerd2Text
global VictoryRoad2FSuperNerd3Text
global VictoryRoad2F_Script
global VictoryRoad2F_ScriptPointers

extern CheckBoulderCoords
extern CheckFightingMapTrainers
extern DisplayEnemyTrainerTextAndStartBattle
extern EnableAutoTextBoxDrawing
extern EndTrainerBattle
extern ExecuteCurMapScriptInTable
extern MoltresTrainerHeader   ; NOT YET DEFINED IN THE PORT
extern PlayCry
extern ReplaceTileBlock
extern TalkToTrainer
extern TextScriptEnd
extern VictoryRoad2FDefaultScript   ; NOT YET DEFINED IN THE PORT
extern VictoryRoad2FHikerBattleText   ; NOT YET DEFINED IN THE PORT
extern VictoryRoad2FMoltresBattleText   ; NOT YET DEFINED IN THE PORT
extern VictoryRoad2TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern VictoryRoad2TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern VictoryRoad2TrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern VictoryRoad2TrainerHeader3   ; NOT YET DEFINED IN THE PORT
extern VictoryRoad2TrainerHeader4   ; NOT YET DEFINED IN THE PORT
extern VictoryRoad2TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern WaitForSoundToFinish

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wCoordIndex                                    equ 0xCD3D
wVictoryRoad2FCurScript                        equ 0xD63E

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
VictoryRoad2F_Script:
    mov esi, wCurrentMapScriptFlags
    test byte [ebp + esi], (1 << (BIT_CUR_MAP_LOADED_2))
    pushfd    ; SM83 form writes no flags
        and byte [ebp + esi], ~(1 << (BIT_CUR_MAP_LOADED_2)) & 0xFF
    popfd
    jz .sk_5
        call VictoryRoad2FResetBoulderEventScript
.sk_5:
    mov esi, wCurrentMapScriptFlags
    test byte [ebp + esi], (1 << (BIT_CUR_MAP_LOADED_1))
    pushfd    ; SM83 form writes no flags
        and byte [ebp + esi], ~(1 << (BIT_CUR_MAP_LOADED_1)) & 0xFF
    popfd
    jz .sk_9
        call VictoryRoad2FCheckBoulderEventScript
.sk_9:
    call EnableAutoTextBoxDrawing
    mov esi, VictoryRoad2TrainerHeaders
    mov edi, VictoryRoad2F_ScriptPointers   ; pret: ld de, VictoryRoad2F_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wVictoryRoad2FCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wVictoryRoad2FCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
VictoryRoad2FResetBoulderEventScript:
    ResetEvent EVENT_VICTORY_ROAD_1_BOULDER_ON_SWITCH
VictoryRoad2FCheckBoulderEventScript:
    CheckEvent EVENT_VICTORY_ROAD_2_BOULDER_ON_SWITCH1
    jz .not_on_switch
    pushfd
    push eax
    mov al, 0x15
    mov bx, ((4) << 8) | (3)
    call VictoryRoad2FReplaceTileBlockScript
    pop eax
    popfd
.not_on_switch:
    CheckEventReuseA EVENT_VICTORY_ROAD_2_BOULDER_ON_SWITCH2
    jnz .nr_31
        ret
.nr_31:
    mov al, 0x1d
    mov bx, ((7) << 8) | (11)
VictoryRoad2FReplaceTileBlockScript:
    mov [ebp + wNewTileBlockID], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call ReplaceTileBlock
    ret

%assign event_byte -1
%assign event_byte_a -1
VictoryRoad2F_ScriptPointers:
    dd VictoryRoad2FDefaultScript
    dd DisplayEnemyTrainerTextAndStartBattle
    dd EndTrainerBattle

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] VictoryRoad2FDefaultScript (scripts/VictoryRoad2F.asm:46-59) — at scripts/VictoryRoad2F.asm:46: .SwitchCoords is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .SwitchCoords
; PRET| 	call CheckBoulderCoords
; PRET| 	jp nc, CheckFightingMapTrainers
; PRET| 	ldh a, [hSpriteIndex]
; PRET| 	cp PIKACHU_SPRITE_INDEX
; PRET| 	jp z, CheckFightingMapTrainers
; PRET| 	EventFlagAddress hl, EVENT_VICTORY_ROAD_2_BOULDER_ON_SWITCH1
; PRET| 	ld a, [wCoordIndex]
; PRET| 	cp $2
; PRET| 	jr z, .second_switch
; PRET| 	CheckEventReuseHL EVENT_VICTORY_ROAD_2_BOULDER_ON_SWITCH1
; PRET| 	SetEventReuseHL EVENT_VICTORY_ROAD_2_BOULDER_ON_SWITCH1
; PRET| 	ret nz
; PRET| 	jr .set_script_flag

%assign event_byte -1
%assign event_byte_a -1
.second_switch:
    CheckEventAfterBranchReuseHL EVENT_VICTORY_ROAD_2_BOULDER_ON_SWITCH2, EVENT_VICTORY_ROAD_2_BOULDER_ON_SWITCH1
    pushfd    ; SM83 form writes no flags
        SetEventReuseHL EVENT_VICTORY_ROAD_2_BOULDER_ON_SWITCH2
    popfd
    jz .nr_63
        ret
.nr_63:
.set_script_flag:
    mov esi, wCurrentMapScriptFlags
    or byte [ebp + esi], (1 << (BIT_CUR_MAP_LOADED_1))
    ret

; VictoryRoad2FDefaultScript.SwitchCoords (scripts/VictoryRoad2F.asm:70-104) — not re-emitted: VictoryRoad2TrainerHeaders is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
VictoryRoad2FHikerText:
    mov esi, VictoryRoad2TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
VictoryRoad2FSuperNerd1Text:
    mov esi, VictoryRoad2TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
VictoryRoad2FCooltrainerMText:
    mov esi, VictoryRoad2TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
VictoryRoad2FSuperNerd2Text:
    mov esi, VictoryRoad2TrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
VictoryRoad2FSuperNerd3Text:
    mov esi, VictoryRoad2TrainerHeader4
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
VictoryRoad2FMoltresText:
    mov esi, MoltresTrainerHeader
    call TalkToTrainer
    jmp TextScriptEnd

; VictoryRoad2FMoltresBattleText (scripts/VictoryRoad2F.asm:143-143) — not re-emitted: VictoryRoad2FMoltresBattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
    mov al, 73
    call PlayCry
    call WaitForSoundToFinish
    jmp TextScriptEnd

; VictoryRoad2FHikerBattleText (scripts/VictoryRoad2F.asm:151-208) — not re-emitted: VictoryRoad2FHikerBattleText is already defined in assets/trainer_headers.inc.
