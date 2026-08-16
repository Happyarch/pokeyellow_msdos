; PewterCity.asm — translated from pret scripts/PewterCity.asm by dos_port/tools/sm83xlat.
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


global MovementData_PewterGymGuyExit
global MovementData_PewterMuseumGuyExit
global PewterCityCheckPlayerLeavingEastScript
global PewterCityCooltrainerFText
global PewterCityCooltrainerMText
global PewterCityDefaultScript
global PewterCityGymSignText
global PewterCityHideSuperNerd1Script
global PewterCityHideYoungsterScript
global PewterCityMuseumSignText
global PewterCityPlayerLeavingEastCoords
global PewterCityPoliceNoticeSignText
global PewterCityResetSuperNerd1Script
global PewterCityResetYoungsterScript
global PewterCitySignText
global PewterCitySuperNerd1ItsRightHereText
global PewterCitySuperNerd1ShowsPlayerMuseumScript
global PewterCitySuperNerd1Text
global PewterCitySuperNerd2Text
global PewterCityTrainerTipsText
global PewterCityYoungsterGoTakeOnBrockText
global PewterCityYoungsterShowsPlayerGymScript
global PewterCityYoungsterText
global PewterCity_Script
global PewterCity_ScriptPointers
global PewterCity_TextPointers

extern ArePlayerCoordsInArray   ; NOT YET DEFINED IN THE PORT
extern CallFunctionInTable   ; NOT YET DEFINED IN THE PORT
extern DisplayTextID   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern GetSpritePosition2   ; NOT YET DEFINED IN THE PORT
extern HideObject   ; NOT YET DEFINED IN THE PORT
extern MartSignText   ; NOT YET DEFINED IN THE PORT
extern MoveSprite   ; NOT YET DEFINED IN THE PORT
extern PlayDefaultMusic   ; NOT YET DEFINED IN THE PORT
extern PokeCenterSignText   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern SetSpriteFacingDirectionAndDelay   ; NOT YET DEFINED IN THE PORT
extern SetSpritePosition1   ; NOT YET DEFINED IN THE PORT
extern SetSpritePosition2   ; NOT YET DEFINED IN THE PORT
extern ShowObject   ; NOT YET DEFINED IN THE PORT
extern SpriteFunc_34a1   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern YesNoChoice   ; NOT YET DEFINED IN THE PORT
extern _PewterCityCooltrainerFText   ; NOT YET DEFINED IN THE PORT
extern _PewterCityCooltrainerMText   ; NOT YET DEFINED IN THE PORT
extern _PewterCityGymSignText   ; NOT YET DEFINED IN THE PORT
extern _PewterCityMuseumSignText   ; NOT YET DEFINED IN THE PORT
extern _PewterCityPoliceNoticeSignText   ; NOT YET DEFINED IN THE PORT
extern _PewterCitySignText   ; NOT YET DEFINED IN THE PORT
extern _PewterCitySuperNerd1DidYouCheckOutMuseumText   ; NOT YET DEFINED IN THE PORT
extern _PewterCitySuperNerd1ItsRightHereText   ; NOT YET DEFINED IN THE PORT
extern _PewterCitySuperNerd1WerentThoseFossilsAmazingText   ; NOT YET DEFINED IN THE PORT
extern _PewterCitySuperNerd1YouHaveToGoText   ; NOT YET DEFINED IN THE PORT
extern _PewterCitySuperNerd2DoYouKnowWhatImDoingText   ; NOT YET DEFINED IN THE PORT
extern _PewterCitySuperNerd2ImSprayingRepelText   ; NOT YET DEFINED IN THE PORT
extern _PewterCitySuperNerd2ThatsRightText   ; NOT YET DEFINED IN THE PORT
extern _PewterCityTrainerTipsText   ; NOT YET DEFINED IN THE PORT
extern _PewterCityYoungsterGoTakeOnBrockText   ; NOT YET DEFINED IN THE PORT
extern _PewterCityYoungsterYoureATrainerFollowMeText   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_PEWTERCITY_DEFAULT                      equ 0
SCRIPT_PEWTERCITY_SUPER_NERD1_SHOWS_PLAYER_MUSEUM equ 1
SCRIPT_PEWTERCITY_HIDE_SUPER_NERD1             equ 2
SCRIPT_PEWTERCITY_RESET_SUPER_NERD1            equ 3
SCRIPT_PEWTERCITY_YOUNGSTER_SHOWS_PLAYER_GYM   equ 4
SCRIPT_PEWTERCITY_HIDE_YOUNGSTER               equ 5
SCRIPT_PEWTERCITY_RESET_YOUNGSTER              equ 6
TEXT_PEWTERCITY_YOUNGSTER                      equ 5
TEXT_PEWTERCITY_SUPER_NERD1_ITS_RIGHT_HERE     equ 13
TEXT_PEWTERCITY_YOUNGSTER_GO_TAKE_ON_BROCK     equ 14

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
hSpriteFacingDirection                         equ 0xFF8D
hSpriteImageIndex                              equ 0xFF8D
hSpriteMapXCoord                               equ 0xFFEE
hSpriteMapYCoord                               equ 0xFFED
hSpriteScreenXCoord                            equ 0xFFEC
hSpriteScreenYCoord                            equ 0xFFEB
wMuseum1FCurScript                             equ 0xD618
wPewterCityCurScript                           equ 0xD5F6
wPikachuMapScriptFlags                         equ 0xD492

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

PewterCity_Script:
    call EnableAutoTextBoxDrawing
    mov esi, wPikachuMapScriptFlags
    and byte [ebp + esi], ~(1 << (7)) & 0xFF
    mov esi, PewterCity_ScriptPointers
    mov al, [ebp + wPewterCityCurScript]
    call CallFunctionInTable
    ret

PewterCity_ScriptPointers:
    dd PewterCityDefaultScript
    dd PewterCitySuperNerd1ShowsPlayerMuseumScript
    dd PewterCityHideSuperNerd1Script
    dd PewterCityResetSuperNerd1Script
    dd PewterCityYoungsterShowsPlayerGymScript
    dd PewterCityHideYoungsterScript
    dd PewterCityResetYoungsterScript

PewterCityDefaultScript:
    xor al, al
    mov [ebp + wMuseum1FCurScript], al
    ResetEvent EVENT_BOUGHT_MUSEUM_TICKET
    call PewterCityCheckPlayerLeavingEastScript
    ret

PewterCityCheckPlayerLeavingEastScript:
    CheckEvent EVENT_BEAT_BROCK
    jz .nr_29
        ret
.nr_29:
    mov esi, PewterCityPlayerLeavingEastCoords
    call ArePlayerCoordsInArray
    jb .nr_36
        ret
.nr_36:
    mov al, PAD_SELECT | PAD_START | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    mov al, TEXT_PEWTERCITY_YOUNGSTER
    mov [ebp + hTextID], al
    jmp DisplayTextID

PewterCityPlayerLeavingEastCoords:
    db 17, 35
    db 17, 36
    db 18, 37
    db 19, 37
    db -1

PewterCitySuperNerd1ShowsPlayerMuseumScript:
    mov al, [ebp + wNPCMovementScriptPointerTableNum]
    test al, al
    jz .nr_53
        ret
.nr_53:
    mov al, 3
    mov [ebp + hSpriteIndex], al
    mov al, SPRITE_FACING_UP
    mov [ebp + hSpriteFacingDirection], al
    call SetSpriteFacingDirectionAndDelay
    mov al, SPRITE_FACING_UP
    mov [ebp + hSpriteImageIndex], al
    call SpriteFunc_34a1
    call PlayDefaultMusic
    mov esi, wMiscFlags
    or byte [ebp + esi], (1 << (BIT_NO_SPRITE_UPDATES))
    mov al, TEXT_PEWTERCITY_SUPER_NERD1_ITS_RIGHT_HERE
    mov [ebp + hTextID], al
    call DisplayTextID
    mov al, 0x3c
    mov [ebp + hSpriteScreenYCoord], al
    mov al, 0x30
    mov [ebp + hSpriteScreenXCoord], al
    mov al, 12
    mov [ebp + hSpriteMapYCoord], al
    mov al, 17
    mov [ebp + hSpriteMapXCoord], al
    mov al, 3
    mov [ebp + wSpriteIndex], al
    call SetSpritePosition1
    mov al, 3
    mov [ebp + hSpriteIndex], al
    mov edi, MovementData_PewterMuseumGuyExit   ; pret: ld de, MovementData_PewterMuseumGuyExit — MoveSprite takes it in EDI
    call MoveSprite
    mov al, SCRIPT_PEWTERCITY_HIDE_SUPER_NERD1
    mov [ebp + wPewterCityCurScript], al
    ret

MovementData_PewterMuseumGuyExit:
    db NPC_MOVEMENT_DOWN
    db NPC_MOVEMENT_DOWN
    db NPC_MOVEMENT_DOWN
    db NPC_MOVEMENT_DOWN
    db -1

PewterCityHideSuperNerd1Script:
    mov al, [ebp + wStatusFlags5]
    test al, (1 << (BIT_SCRIPTED_NPC_MOVEMENT))
    jz .nr_97
        ret
.nr_97:
    mov al, 4
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and the predef id is not left in A because no reader is live; evidence=PredefPointers is unported and the flat model needs no bank switch, dataflow shows A dead after this site; lifetime=retired when PredefPointers is ported}
    call HideObject
    mov al, SCRIPT_PEWTERCITY_RESET_SUPER_NERD1
    mov [ebp + wPewterCityCurScript], al
    ret

PewterCityResetSuperNerd1Script:
    mov al, 3
    mov [ebp + wSpriteIndex], al
    call SetSpritePosition2
    mov al, 4
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and the predef id is not left in A because no reader is live; evidence=PredefPointers is unported and the flat model needs no bank switch, dataflow shows A dead after this site; lifetime=retired when PredefPointers is ported}
    call ShowObject
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov al, SCRIPT_PEWTERCITY_DEFAULT
    mov [ebp + wPewterCityCurScript], al
    ret

PewterCityYoungsterShowsPlayerGymScript:
    mov al, [ebp + wNPCMovementScriptPointerTableNum]
    test al, al
    jz .nr_121
        ret
.nr_121:
    mov al, 5
    mov [ebp + hSpriteIndex], al
    mov al, SPRITE_FACING_LEFT
    mov [ebp + hSpriteFacingDirection], al
    call SpriteFunc_34a1
    call PlayDefaultMusic
    mov esi, wMiscFlags
    or byte [ebp + esi], (1 << (BIT_NO_SPRITE_UPDATES))
    mov al, TEXT_PEWTERCITY_YOUNGSTER_GO_TAKE_ON_BROCK
    mov [ebp + hTextID], al
    call DisplayTextID
    mov al, 0x3c
    mov [ebp + hSpriteScreenYCoord], al
    mov al, 0x40
    mov [ebp + hSpriteScreenXCoord], al
    mov al, 22
    mov [ebp + hSpriteMapYCoord], al
    mov al, 16
    mov [ebp + hSpriteMapXCoord], al
    mov al, 5
    mov [ebp + wSpriteIndex], al
    call SetSpritePosition1
    mov al, 5
    mov [ebp + hSpriteIndex], al
    mov edi, MovementData_PewterGymGuyExit   ; pret: ld de, MovementData_PewterGymGuyExit — MoveSprite takes it in EDI
    call MoveSprite
    mov al, SCRIPT_PEWTERCITY_HIDE_YOUNGSTER
    mov [ebp + wPewterCityCurScript], al
    ret

MovementData_PewterGymGuyExit:
    db NPC_MOVEMENT_RIGHT
    db NPC_MOVEMENT_RIGHT
    db NPC_MOVEMENT_RIGHT
    db NPC_MOVEMENT_RIGHT
    db NPC_MOVEMENT_RIGHT
    db -1

PewterCityHideYoungsterScript:
    mov al, [ebp + wStatusFlags5]
    test al, (1 << (BIT_SCRIPTED_NPC_MOVEMENT))
    jz .nr_163
        ret
.nr_163:
    mov al, 5
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and the predef id is not left in A because no reader is live; evidence=PredefPointers is unported and the flat model needs no bank switch, dataflow shows A dead after this site; lifetime=retired when PredefPointers is ported}
    call HideObject
    mov al, SCRIPT_PEWTERCITY_RESET_YOUNGSTER
    mov [ebp + wPewterCityCurScript], al
    ret

PewterCityResetYoungsterScript:
    mov al, 5
    mov [ebp + wSpriteIndex], al
    call SetSpritePosition2
    mov al, 5
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and the predef id is not left in A because no reader is live; evidence=PredefPointers is unported and the flat model needs no bank switch, dataflow shows A dead after this site; lifetime=retired when PredefPointers is ported}
    call ShowObject
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov al, SCRIPT_PEWTERCITY_DEFAULT
    mov [ebp + wPewterCityCurScript], al
    ret

PewterCity_TextPointers:
    dd PewterCityCooltrainerFText
    dd PewterCityCooltrainerMText
    dd PewterCitySuperNerd1Text
    dd PewterCitySuperNerd2Text
    dd PewterCityYoungsterText
    dd PewterCityTrainerTipsText
    dd PewterCityPoliceNoticeSignText
    dd MartSignText
    dd PokeCenterSignText
    dd PewterCityMuseumSignText
    dd PewterCityGymSignText
    dd PewterCitySignText
    dd PewterCitySuperNerd1ItsRightHereText
    dd PewterCityYoungsterGoTakeOnBrockText
PewterCityCooltrainerFText:
    text_far _PewterCityCooltrainerFText
    text_end
PewterCityCooltrainerMText:
    text_far _PewterCityCooltrainerMText
    text_end

PewterCitySuperNerd1Text:
    mov esi, .DidYouCheckOutMuseumText
    call PrintText
    call YesNoChoice
    mov al, [ebp + wCurrentMenuItem]
    test al, al
    jnz .playerDidNotGoIntoMuseum
    mov esi, .WerentThoseFossilsAmazingText
    call PrintText
    jmp .done

.playerDidNotGoIntoMuseum:
    mov esi, .YouHaveToGoText
    call PrintText
    xor al, al
    mov [ebp + hJoyPressed], al
    mov [ebp + hJoyHeld], al
    mov [ebp + W_NPC_MOVEMENT_SCRIPT_FUNCTION_NUM], al
    mov al, 0x2
    mov [ebp + wNPCMovementScriptPointerTableNum], al
    mov al, [ebp + hLoadedROMBank]
    mov [ebp + W_NPC_MOVEMENT_SCRIPT_BANK], al
    mov al, 3
    mov [ebp + wSpriteIndex], al
    call GetSpritePosition2
    mov al, SCRIPT_PEWTERCITY_SUPER_NERD1_SHOWS_PLAYER_MUSEUM
    mov [ebp + wPewterCityCurScript], al
.done:
    jmp TextScriptEnd

.DidYouCheckOutMuseumText:
    text_far _PewterCitySuperNerd1DidYouCheckOutMuseumText
    text_end
.WerentThoseFossilsAmazingText:
    text_far _PewterCitySuperNerd1WerentThoseFossilsAmazingText
    text_end
.YouHaveToGoText:
    text_far _PewterCitySuperNerd1YouHaveToGoText
    text_end
PewterCitySuperNerd1ItsRightHereText:
    text_far _PewterCitySuperNerd1ItsRightHereText
    text_end

PewterCitySuperNerd2Text:
    mov esi, .DoYouKnowWhatImDoingText
    call PrintText
    call YesNoChoice
    mov al, [ebp + wCurrentMenuItem]
    cmp al, 0x0
    jnz .playerDoesNotKnow
    mov esi, .ThatsRightText
    call PrintText
    jmp .done

.playerDoesNotKnow:
    mov esi, .ImSprayingRepelText
    call PrintText
.done:
    jmp TextScriptEnd

.DoYouKnowWhatImDoingText:
    text_far _PewterCitySuperNerd2DoYouKnowWhatImDoingText
    text_end
.ThatsRightText:
    text_far _PewterCitySuperNerd2ThatsRightText
    text_end
.ImSprayingRepelText:
    text_far _PewterCitySuperNerd2ImSprayingRepelText
    text_end

PewterCityYoungsterText:
    mov esi, .YoureATrainerFollowMeText
    call PrintText
    xor al, al
    mov [ebp + hJoyHeld], al
    mov [ebp + W_NPC_MOVEMENT_SCRIPT_FUNCTION_NUM], al
    mov al, 0x3
    mov [ebp + wNPCMovementScriptPointerTableNum], al
    mov al, [ebp + hLoadedROMBank]
    mov [ebp + W_NPC_MOVEMENT_SCRIPT_BANK], al
    mov al, 5
    mov [ebp + wSpriteIndex], al
    call GetSpritePosition2
    mov al, SCRIPT_PEWTERCITY_YOUNGSTER_SHOWS_PLAYER_GYM
    mov [ebp + wPewterCityCurScript], al
    jmp TextScriptEnd

.YoureATrainerFollowMeText:
    text_far _PewterCityYoungsterYoureATrainerFollowMeText
    text_end
PewterCityYoungsterGoTakeOnBrockText:
    text_far _PewterCityYoungsterGoTakeOnBrockText
    text_end
PewterCityTrainerTipsText:
    text_far _PewterCityTrainerTipsText
    text_end
PewterCityPoliceNoticeSignText:
    text_far _PewterCityPoliceNoticeSignText
    text_end
PewterCityMuseumSignText:
    text_far _PewterCityMuseumSignText
    text_end
PewterCityGymSignText:
    text_far _PewterCityGymSignText
    text_end
PewterCitySignText:
    text_far _PewterCitySignText
    text_end
