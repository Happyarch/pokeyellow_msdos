; PokemonTower7F.asm — translated from pret scripts/PokemonTower7F.asm by dos_port/tools/sm83xlat.
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

%include "assets/audio_constants.inc"
%include "assets/map_dims.inc"

global PokemonTower7FJessieJamesEndBattleText
global PokemonTower7FJessieJamesText
global PokemonTower7FMovementData_60d7a
global PokemonTower7FMovementData_60d7b
global PokemonTower7FMrFujiText
global PokemonTower7FScript10
global PokemonTower7FScript5
global PokemonTower7FScript6
global PokemonTower7FScript7
global PokemonTower7FScript8
global PokemonTower7FScript9
global PokemonTower7FScript_60d2a
global PokemonTower7FScript_HideObject
global PokemonTower7FScript_ShowObject
global PokemonTower7FSetDefaultScript
global PokemonTower7FSetScript
global PokemonTower7FText4
global PokemonTower7FText5
global PokemonTower7FText6
global PokemonTower7FWarpToMrFujiHouseScript
global PokemonTower7F_Script
global PokemonTower7F_ScriptPointers
global PokemonTower7F_TextPointers

extern CallFunctionInTable   ; NOT YET DEFINED IN THE PORT
extern Delay3   ; NOT YET DEFINED IN THE PORT
extern DelayFrames   ; NOT YET DEFINED IN THE PORT
extern DisplayTextID   ; NOT YET DEFINED IN THE PORT
extern EmotionBubble   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern GBFadeInFromBlack   ; NOT YET DEFINED IN THE PORT
extern GBFadeOutToBlack   ; NOT YET DEFINED IN THE PORT
extern HideObject   ; NOT YET DEFINED IN THE PORT
extern MoveSprite   ; NOT YET DEFINED IN THE PORT
extern PlayDefaultMusic   ; NOT YET DEFINED IN THE PORT
extern PlayMusic   ; NOT YET DEFINED IN THE PORT
extern PokemonTower7FScript0   ; NOT YET DEFINED IN THE PORT
extern PokemonTower7FScript1   ; NOT YET DEFINED IN THE PORT
extern PokemonTower7FScript2   ; NOT YET DEFINED IN THE PORT
extern PokemonTower7FScript3   ; NOT YET DEFINED IN THE PORT
extern PokemonTower7FScript4   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern SaveEndBattleTextPointers   ; NOT YET DEFINED IN THE PORT
extern ShowObject   ; NOT YET DEFINED IN THE PORT
extern StopAllMusic   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern UpdateSprites   ; NOT YET DEFINED IN THE PORT
extern _PokemonTower7FMrFujiRescueText   ; NOT YET DEFINED IN THE PORT
extern _PokemonTowerJessieJamesText1   ; NOT YET DEFINED IN THE PORT
extern _PokemonTowerJessieJamesText2   ; NOT YET DEFINED IN THE PORT
extern _PokemonTowerJessieJamesText3   ; NOT YET DEFINED IN THE PORT
extern _PokemonTowerJessieJamesText4   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_POKEMONTOWER7F_SCRIPT0                  equ 0
SCRIPT_POKEMONTOWER7F_SCRIPT1                  equ 1
SCRIPT_POKEMONTOWER7F_SCRIPT2                  equ 2
SCRIPT_POKEMONTOWER7F_SCRIPT5                  equ 5
SCRIPT_POKEMONTOWER7F_SCRIPT8                  equ 8
SCRIPT_POKEMONTOWER7F_SCRIPT9                  equ 9
SCRIPT_POKEMONTOWER7F_SCRIPT10                 equ 10
SCRIPT_POKEMONTOWER7F_WARP_TO_MR_FUJI_HOUSE    equ 11
TEXT_POKEMONTOWER7F_TEXT4                      equ 4
TEXT_POKEMONTOWER7F_TEXT5                      equ 5
TEXT_POKEMONTOWER7F_TEXT6                      equ 6

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
hWarpDestinationMap                            equ 0xFF8B
wPokemonTower7FCurScript                       equ 0xD62F
wSprite01StateData1FacingDirection             equ 0xC119
wSprite01StateData1MovementStatus              equ 0xC111
wSprite02StateData1FacingDirection             equ 0xC129
wSprite02StateData1MovementStatus              equ 0xC121
wSpritePlayerStateData1FacingDirection         equ 0xC109

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
PokemonTower7F_Script:
    call EnableAutoTextBoxDrawing
    mov esi, PokemonTower7F_ScriptPointers
    mov al, [ebp + wPokemonTower7FCurScript]
    call CallFunctionInTable
    ret

%assign event_byte -1
%assign event_byte_a -1
PokemonTower7FSetDefaultScript:
    xor al, al
    mov [ebp + wJoyIgnore], al
PokemonTower7FSetScript:
    mov [ebp + wPokemonTower7FCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
PokemonTower7F_ScriptPointers:
    dd PokemonTower7FScript0
    dd PokemonTower7FScript1
    dd PokemonTower7FScript2
    dd PokemonTower7FScript3
    dd PokemonTower7FScript4
    dd PokemonTower7FScript5
    dd PokemonTower7FScript6
    dd PokemonTower7FScript7
    dd PokemonTower7FScript8
    dd PokemonTower7FScript9
    dd PokemonTower7FScript10
    dd PokemonTower7FWarpToMrFujiHouseScript

%assign event_byte -1
%assign event_byte_a -1
    CheckEvent EVENT_BEAT_POKEMONTOWER_7_JESSIE_JAMES
    jnz .sk_36
        call PokemonTower7FScript_60d2a
.sk_36:
    ret

%assign event_byte -1
%assign event_byte_a -1
PokemonTower7FScript_60d2a:
    mov al, [ebp + wYCoord]
    cmp al, 0xc
    jz .nr_42
        ret
.nr_42:
    ResetEvent EVENT_POKEMONTOWER_7_JESSIE_JAMES_ON_LEFT
    mov al, [ebp + wXCoord]
    cmp al, 0xa
    jz .asm_60d47
    mov al, [ebp + wXCoord]
    cmp al, 0xb
    jz .nr_49
        ret
.nr_49:
    SetEvent EVENT_POKEMONTOWER_7_JESSIE_JAMES_ON_LEFT
.asm_60d47:
    call StopAllMusic
    mov bl, 32
    mov al, MUSIC_MEET_JESSIE_JAMES
    call PlayMusic
    xor al, al
    mov [ebp + hJoyHeld], al
    mov al, PAD_SELECT | PAD_START | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    mov al, 65
    call PokemonTower7FScript_ShowObject
    mov al, 66
    call PokemonTower7FScript_ShowObject
    mov al, 0x1
    mov [ebp + wDoNotWaitForButtonPressAfterDisplayingText], al
    mov al, TEXT_POKEMONTOWER7F_TEXT4
    mov [ebp + hTextID], al
    call DisplayTextID
    mov al, PAD_BUTTONS | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    mov al, SCRIPT_POKEMONTOWER7F_SCRIPT1
    call PokemonTower7FSetScript
    ret

%assign event_byte -1
%assign event_byte_a -1
PokemonTower7FMovementData_60d7a:
    db 0x4
PokemonTower7FMovementData_60d7b:
    db 0x4
    db 0x4
    db 0x4
    db 0xFF

; ---------------------------------------------------------------------------
; BAIL[host-pointer-in-16bit-reg] PokemonTower7FScript1 (scripts/PokemonTower7F.asm:84-96) — at scripts/PokemonTower7F.asm:84: de cannot hold the 32-bit address of PokemonTower7FMovementData_60d7b; callee <none in range> has no abi.json entry
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld de, PokemonTower7FMovementData_60d7b
; PRET| 	CheckEvent EVENT_POKEMONTOWER_7_JESSIE_JAMES_ON_LEFT
; PRET| 	jr z, .asm_60d8c
; PRET| 	ld de, PokemonTower7FMovementData_60d7a
; PRET| .asm_60d8c
; PRET| 	ld a, POKEMONTOWER7F_JESSIE
; PRET| 	ldh [hSpriteIndex], a
; PRET| 	call MoveSprite
; PRET| 	ld a, PAD_BUTTONS | PAD_CTRL_PAD
; PRET| 	ld [wJoyIgnore], a
; PRET| 	ld a, SCRIPT_POKEMONTOWER7F_SCRIPT2
; PRET| 	call PokemonTower7FSetScript
; PRET| 	ret

; ---------------------------------------------------------------------------
; BAIL[host-pointer-in-16bit-reg] PokemonTower7FScript2 (scripts/PokemonTower7F.asm:99-127) — at scripts/PokemonTower7F.asm:115: de cannot hold the 32-bit address of PokemonTower7FMovementData_60d7a; callee <none in range> has no abi.json entry
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, PAD_BUTTONS | PAD_CTRL_PAD
; PRET| 	ld [wJoyIgnore], a
; PRET| 	ld a, [wStatusFlags5]
; PRET| 	bit BIT_SCRIPTED_NPC_MOVEMENT, a
; PRET| 	ret nz
; PRET| PokemonTower7FScript3:
; PRET| 	ld a, SPRITE_FACING_DOWN
; PRET| 	ld [wSprite01StateData1FacingDirection], a
; PRET| 	CheckEvent EVENT_POKEMONTOWER_7_JESSIE_JAMES_ON_LEFT
; PRET| 	jr z, .asm_60dba
; PRET| 	ld a, SPRITE_FACING_RIGHT
; PRET| 	ld [wSprite01StateData1FacingDirection], a
; PRET| .asm_60dba
; PRET| 	ld a, $2
; PRET| 	ld [wSprite01StateData1MovementStatus], a
; PRET| PokemonTower7FScript4:
; PRET| 	ld de, PokemonTower7FMovementData_60d7a
; PRET| 	CheckEvent EVENT_POKEMONTOWER_7_JESSIE_JAMES_ON_LEFT
; PRET| 	jr z, .asm_60dcc
; PRET| 	ld de, PokemonTower7FMovementData_60d7b
; PRET| .asm_60dcc
; PRET| 	ld a, POKEMONTOWER7F_JAMES
; PRET| 	ldh [hSpriteIndex], a
; PRET| 	call MoveSprite
; PRET| 	ld a, PAD_BUTTONS | PAD_CTRL_PAD
; PRET| 	ld [wJoyIgnore], a
; PRET| 	ld a, SCRIPT_POKEMONTOWER7F_SCRIPT5
; PRET| 	call PokemonTower7FSetScript
; PRET| 	ret

%assign event_byte -1
%assign event_byte_a -1
PokemonTower7FScript5:
    mov al, PAD_BUTTONS | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    mov al, [ebp + wStatusFlags5]
    test al, (1 << (BIT_SCRIPTED_NPC_MOVEMENT))
    jz .nr_134
        ret
.nr_134:
PokemonTower7FScript6:
    mov al, 0x2
    mov [ebp + wSprite02StateData1MovementStatus], al
    mov al, SPRITE_FACING_LEFT
    mov [ebp + wSprite02StateData1FacingDirection], al
    CheckEvent EVENT_POKEMONTOWER_7_JESSIE_JAMES_ON_LEFT
    jz .asm_60dff
    mov al, SPRITE_FACING_DOWN
    mov [ebp + wSprite02StateData1FacingDirection], al
.asm_60dff:
    call Delay3
    mov al, PAD_SELECT | PAD_START | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    mov al, TEXT_POKEMONTOWER7F_TEXT5
    mov [ebp + hTextID], al
    call DisplayTextID
PokemonTower7FScript7:
    mov esi, wStatusFlags3
    or byte [ebp + esi], (1 << (BIT_TALKED_TO_TRAINER))
    or byte [ebp + esi], (1 << (BIT_PRINT_END_BATTLE_TEXT))
    mov esi, PokemonTower7FJessieJamesEndBattleText
    mov edx, PokemonTower7FJessieJamesEndBattleText   ; pret: ld de, PokemonTower7FJessieJamesEndBattleText — SaveEndBattleTextPointers takes it in EDX
    call SaveEndBattleTextPointers
    mov al, OPP_ROCKET
    mov [ebp + wCurOpponent], al
    mov al, 0x2c
    mov [ebp + wTrainerNo], al
    xor al, al
    mov [ebp + hJoyHeld], al
    mov [ebp + wJoyIgnore], al
    mov al, SCRIPT_POKEMONTOWER7F_SCRIPT8
    call PokemonTower7FSetScript
    ret

%assign event_byte -1
%assign event_byte_a -1
PokemonTower7FScript8:
    mov al, PAD_BUTTONS | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    mov al, [ebp + wIsInBattle]
    cmp al, 0xff
    jz PokemonTower7FSetDefaultScript
    mov al, 0x2
    mov [ebp + wSprite01StateData1MovementStatus], al
    mov [ebp + wSprite02StateData1MovementStatus], al
    xor al, al
    mov [ebp + wSprite01StateData1FacingDirection], al
    mov [ebp + wSprite02StateData1FacingDirection], al
    mov al, PAD_SELECT | PAD_START | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    mov al, 0x1
    mov [ebp + wDoNotWaitForButtonPressAfterDisplayingText], al
    mov al, TEXT_POKEMONTOWER7F_TEXT6
    mov [ebp + hTextID], al
    call DisplayTextID
    xor al, al
    mov [ebp + wDoNotWaitForButtonPressAfterDisplayingText], al
    call StopAllMusic
    mov bl, 32
    mov al, MUSIC_MEET_JESSIE_JAMES
    call PlayMusic
    mov al, PAD_BUTTONS | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    mov al, SCRIPT_POKEMONTOWER7F_SCRIPT9
    call PokemonTower7FSetScript
    ret

%assign event_byte -1
%assign event_byte_a -1
PokemonTower7FScript9:
    mov al, PAD_BUTTONS | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    call GBFadeOutToBlack
    mov al, 65
    call PokemonTower7FScript_HideObject
    mov al, 66
    call PokemonTower7FScript_HideObject
    call UpdateSprites
    call Delay3
    call GBFadeInFromBlack
    mov al, SCRIPT_POKEMONTOWER7F_SCRIPT10
    call PokemonTower7FSetScript
    ret

%assign event_byte -1
%assign event_byte_a -1
PokemonTower7FScript10:
    call PlayDefaultMusic
    xor al, al
    mov [ebp + hJoyHeld], al
    mov [ebp + wJoyIgnore], al
    SetEvent EVENT_BEAT_POKEMONTOWER_7_JESSIE_JAMES
    mov al, SCRIPT_POKEMONTOWER7F_SCRIPT0
    call PokemonTower7FSetScript
    ret

%assign event_byte -1
%assign event_byte_a -1
PokemonTower7FScript_ShowObject:
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call ShowObject
    call UpdateSprites
    call Delay3
    ret

%assign event_byte -1
%assign event_byte_a -1
PokemonTower7FScript_HideObject:
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call HideObject
    ret

%assign event_byte -1
%assign event_byte_a -1
PokemonTower7FWarpToMrFujiHouseScript:
    mov al, PAD_BUTTONS | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    mov al, 67
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call HideObject
    mov al, SPRITE_FACING_UP
    mov [ebp + wSpritePlayerStateData1FacingDirection], al
    mov al, MR_FUJIS_HOUSE
    mov [ebp + hWarpDestinationMap], al
    mov al, 0x1
    mov [ebp + wDestinationWarpID], al
    mov al, LAVENDER_TOWN
    mov [ebp + wLastMap], al
    mov esi, wStatusFlags3
    or byte [ebp + esi], (1 << (3))
    mov al, SCRIPT_POKEMONTOWER7F_SCRIPT0
    mov [ebp + wPokemonTower7FCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
PokemonTower7F_TextPointers:
    dd PokemonTower7FJessieJamesText
    dd PokemonTower7FJessieJamesText
    dd PokemonTower7FMrFujiText
    dd PokemonTower7FText4
    dd PokemonTower7FText5
    dd PokemonTower7FText6
PokemonTower7FJessieJamesText:
    text_end
PokemonTower7FText4:
    text_far _PokemonTowerJessieJamesText1

%assign event_byte -1
%assign event_byte_a -1
    mov bl, 10
    call DelayFrames
    mov al, PLAYER_DIR_UP
    mov [ebp + wPlayerMovingDirection], al
    mov al, 0x0
    mov [ebp + wEmotionBubbleSpriteIndex], al
    mov al, 0
    mov [ebp + wWhichEmotionBubble], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call EmotionBubble
    mov bl, 20
    call DelayFrames
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
PokemonTower7FText5:
    text_far _PokemonTowerJessieJamesText2
    text_end
PokemonTower7FJessieJamesEndBattleText:
    text_far _PokemonTowerJessieJamesText3
    text_end
PokemonTower7FText6:
    text_far _PokemonTowerJessieJamesText4

%assign event_byte -1
%assign event_byte_a -1
    mov bl, 64
    call DelayFrames
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
PokemonTower7FMrFujiText:
    mov esi, .RescueText
    call PrintText
    SetEvent EVENT_RESCUED_MR_FUJI
    SetEvent EVENT_RESCUED_MR_FUJI_2
    mov al, 68
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call ShowObject
    mov al, 24
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call HideObject
    mov al, 25
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call ShowObject
    mov al, SCRIPT_POKEMONTOWER7F_WARP_TO_MR_FUJI_HOUSE
    mov [ebp + wPokemonTower7FCurScript], al
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.RescueText:
    text_far _PokemonTower7FMrFujiRescueText
    text_end
