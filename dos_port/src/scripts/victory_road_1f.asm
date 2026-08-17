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

%include "assets/trainer_headers.inc"

global VictoryRoad1FCooltrainerFText
global VictoryRoad1FCooltrainerMText
global VictoryRoad1F_Script
global VictoryRoad1F_ScriptPointers

extern CheckBoulderCoords   ; NOT YET DEFINED IN THE PORT
extern CheckFightingMapTrainers   ; NOT YET DEFINED IN THE PORT
extern DisplayEnemyTrainerTextAndStartBattle   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EndTrainerBattle   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern ReplaceTileBlock   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern VictoryRoad1FCooltrainerFBattleText   ; NOT YET DEFINED IN THE PORT
extern VictoryRoad1FDefaultScript   ; NOT YET DEFINED IN THE PORT
extern VictoryRoad1TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern VictoryRoad1TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern VictoryRoad1TrainerHeaders   ; NOT YET DEFINED IN THE PORT

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wVictoryRoad1FCurScript                        equ 0xD650

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
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
VictoryRoad1F_ScriptPointers:
    dd VictoryRoad1FDefaultScript
    dd DisplayEnemyTrainerTextAndStartBattle
    dd EndTrainerBattle

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] VictoryRoad1FDefaultScript (scripts/VictoryRoad1F.asm:28-39) — at scripts/VictoryRoad1F.asm:30: .SwitchCoords is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEvent EVENT_VICTORY_ROAD_1_BOULDER_ON_SWITCH
; PRET| 	jp nz, CheckFightingMapTrainers
; PRET| 	ld hl, .SwitchCoords
; PRET| 	call CheckBoulderCoords
; PRET| 	jp nc, CheckFightingMapTrainers
; PRET| 	ldh a, [hSpriteIndex]
; PRET| 	cp PIKACHU_SPRITE_INDEX
; PRET| 	jp z, CheckFightingMapTrainers
; PRET| 	ld hl, wCurrentMapScriptFlags
; PRET| 	set BIT_CUR_MAP_LOADED_1, [hl]
; PRET| 	SetEvent EVENT_VICTORY_ROAD_1_BOULDER_ON_SWITCH
; PRET| 	ret

; VictoryRoad1FDefaultScript.SwitchCoords (scripts/VictoryRoad1F.asm:42-61) — not re-emitted: VictoryRoad1TrainerHeaders is already defined in assets/trainer_headers.inc.

%assign event_byte -1
VictoryRoad1FCooltrainerFText:
    mov esi, VictoryRoad1TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
VictoryRoad1FCooltrainerMText:
    mov esi, VictoryRoad1TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

; VictoryRoad1FCooltrainerFBattleText (scripts/VictoryRoad1F.asm:76-97) — not re-emitted: VictoryRoad1FCooltrainerFBattleText is already defined in assets/trainer_headers.inc.
