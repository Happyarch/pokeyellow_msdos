; VermilionCity.asm — translated from pret scripts/VermilionCity.asm, scripts/VermilionCity_2.asm by dos_port/tools/sm83xlat.
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


global OfficerJennyText1
global OfficerJennyText2
global OfficerJennyText3
global OfficerJennyText4
global OfficerJennyText5
global SSAnneTicketCheckCoords
global VermilionCityBeautyText
global VermilionCityDefaultScript
global VermilionCityGambler1Text
global VermilionCityGambler2Text
global VermilionCityGymSignText
global VermilionCityHarborSignText
global VermilionCityMachopText
global VermilionCityNoticeSignText
global VermilionCityOfficerJennyText
global VermilionCityPlayerAllowedToPassScript
global VermilionCityPlayerExitShipScript
global VermilionCityPlayerMovingUp1Script
global VermilionCityPlayerMovingUp2Script
global VermilionCityPokemonFanClubSignText
global VermilionCityPrintGymSignText
global VermilionCityPrintHarborSignText
global VermilionCityPrintNoticeSignText
global VermilionCityPrintOfficerJennyText
global VermilionCityPrintPokemonFanClubSignText
global VermilionCityPrintSignText
global VermilionCitySailor1Text
global VermilionCitySailor2Text
global VermilionCitySignText
global VermilionCity_ScriptPointers
global VermilionCity_TextPointers

extern ArePlayerCoordsInArray   ; NOT YET DEFINED IN THE PORT
extern Bankswitch   ; NOT YET DEFINED IN THE PORT
extern CallFunctionInTable   ; NOT YET DEFINED IN THE PORT
extern DelayFrames   ; NOT YET DEFINED IN THE PORT
extern DisplayTextID   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern GetMonName   ; NOT YET DEFINED IN THE PORT
extern GetQuantityOfItemInBag   ; NOT YET DEFINED IN THE PORT
extern GivePokemon   ; NOT YET DEFINED IN THE PORT
extern MartSignText   ; NOT YET DEFINED IN THE PORT
extern PlayCry   ; NOT YET DEFINED IN THE PORT
extern PokeCenterSignText   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern Random   ; NOT YET DEFINED IN THE PORT
extern StartSimulatingJoypadStates   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern VermilionCityLeftSSAnneCallbackScript   ; NOT YET DEFINED IN THE PORT
extern VermilionCity_Script   ; NOT YET DEFINED IN THE PORT
extern WaitForSoundToFinish   ; NOT YET DEFINED IN THE PORT
extern WaitForTextScrollButtonPress   ; NOT YET DEFINED IN THE PORT
extern YesNoChoice   ; NOT YET DEFINED IN THE PORT
extern _OfficerJennyText1   ; NOT YET DEFINED IN THE PORT
extern _OfficerJennyText2   ; NOT YET DEFINED IN THE PORT
extern _OfficerJennyText3   ; NOT YET DEFINED IN THE PORT
extern _OfficerJennyText4   ; NOT YET DEFINED IN THE PORT
extern _OfficerJennyText5   ; NOT YET DEFINED IN THE PORT
extern _VermilionCityBeautyText   ; NOT YET DEFINED IN THE PORT
extern _VermilionCityGambler1DidYouSeeText   ; NOT YET DEFINED IN THE PORT
extern _VermilionCityGambler1SSAnneDepartedText   ; NOT YET DEFINED IN THE PORT
extern _VermilionCityGambler2Text   ; NOT YET DEFINED IN THE PORT
extern _VermilionCityGymSignText   ; NOT YET DEFINED IN THE PORT
extern _VermilionCityHarborSignText   ; NOT YET DEFINED IN THE PORT
extern _VermilionCityMachopStompingTheLandFlatText   ; NOT YET DEFINED IN THE PORT
extern _VermilionCityMachopText   ; NOT YET DEFINED IN THE PORT
extern _VermilionCityNoticeSignText   ; NOT YET DEFINED IN THE PORT
extern _VermilionCityPokemonFanClubSignText   ; NOT YET DEFINED IN THE PORT
extern _VermilionCitySailor1DoYouHaveATicketText   ; NOT YET DEFINED IN THE PORT
extern _VermilionCitySailor1FlashedTicketText   ; NOT YET DEFINED IN THE PORT
extern _VermilionCitySailor1ShipSetSailText   ; NOT YET DEFINED IN THE PORT
extern _VermilionCitySailor1WelcomeToSSAnneText   ; NOT YET DEFINED IN THE PORT
extern _VermilionCitySailor1YouNeedATicketText   ; NOT YET DEFINED IN THE PORT
extern _VermilionCitySailor2Text   ; NOT YET DEFINED IN THE PORT
extern _VermilionCitySignText   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_VERMILIONCITY_DEFAULT                   equ 0
SCRIPT_VERMILIONCITY_PLAYER_MOVING_UP1         equ 1
SCRIPT_VERMILIONCITY_PLAYER_EXIT_SHIP          equ 2
SCRIPT_VERMILIONCITY_PLAYER_MOVING_UP2         equ 3
SCRIPT_VERMILIONCITY_PLAYER_ALLOWED_TO_PASS    equ 4
TEXT_VERMILIONCITY_SAILOR1                     equ 3

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wAddedToParty                                  equ 0xCCD3
wBeatGymFlags                                  equ 0xD729
wFirstLockTrashCanIndex                        equ 0xD742
wPikachuMapScriptFlags                         equ 0xD492
wSavedCoordIndex                               equ 0xCF0D
wSpritePlayerStateData1FacingDirection         equ 0xC109
wVermilionCityCurScript                        equ 0xD629

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

; ---------------------------------------------------------------------------
; BAIL[pointer-domain-unknown] VermilionCity_Script (scripts/VermilionCity.asm:2-18) — at scripts/VermilionCity.asm:11: HL domain is top at a dereference
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	call EnableAutoTextBoxDrawing
; PRET| 	ld hl, wPikachuMapScriptFlags
; PRET| 	res BIT_PIKACHU_MAP_SCRIPT_ACTIVE, [hl]
; PRET| 	ld hl, wCurrentMapScriptFlags
; PRET| 	bit BIT_CUR_MAP_LOADED_2, [hl]
; PRET| 	res BIT_CUR_MAP_LOADED_2, [hl]
; PRET| 	push hl
; PRET| 	call nz, VermilionCityLeftSSAnneCallbackScript
; PRET| 	pop hl
; PRET| 	bit BIT_CUR_MAP_LOADED_1, [hl]
; PRET| 	res BIT_CUR_MAP_LOADED_1, [hl]
; PRET| 	call nz, .setFirstLockTrashCanIndex
; PRET| 	ld hl, VermilionCity_ScriptPointers
; PRET| 	ld a, [wVermilionCityCurScript]
; PRET| 	call CallFunctionInTable
; PRET| 	call .vermilionCityScript_19869
; PRET| 	ret

; ---------------------------------------------------------------------------
; BAIL[event-byte-assembly-state] VermilionCity_Script.vermilionCityScript_19869 (scripts/VermilionCity.asm:21-26) — at scripts/VermilionCity.asm:23: CheckEventReuseHL EVENT_GOT_BIKE_VOUCHER
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEventHL EVENT_LEFT_FANCLUB_AFTER_BIKE_VOUCHER
; PRET| 	ret nz
; PRET| 	CheckEventReuseHL EVENT_GOT_BIKE_VOUCHER
; PRET| 	ret z
; PRET| 	SetEventReuseHL EVENT_LEFT_FANCLUB_AFTER_BIKE_VOUCHER
; PRET| 	ret

.setFirstLockTrashCanIndex:
    call Random
    mov al, [ebp + hRandomAdd]
    mov bh, al
    mov al, [ebp + hRandomSub]
    adc al, bh
    and al, 0xe
    mov [ebp + wFirstLockTrashCanIndex], al
    ret

; ---------------------------------------------------------------------------
; BAIL[event-byte-assembly-state] VermilionCityLeftSSAnneCallbackScript (scripts/VermilionCity.asm:39-46) — at scripts/VermilionCity.asm:41: CheckEventReuseHL EVENT_WALKED_PAST_GUARD_AFTER_SS_ANNE_LEFT
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEventHL EVENT_SS_ANNE_LEFT
; PRET| 	ret z
; PRET| 	CheckEventReuseHL EVENT_WALKED_PAST_GUARD_AFTER_SS_ANNE_LEFT
; PRET| 	SetEventReuseHL EVENT_WALKED_PAST_GUARD_AFTER_SS_ANNE_LEFT
; PRET| 	ret nz
; PRET| 	ld a, SCRIPT_VERMILIONCITY_PLAYER_EXIT_SHIP
; PRET| 	ld [wVermilionCityCurScript], a
; PRET| 	ret

VermilionCity_ScriptPointers:
    dd VermilionCityDefaultScript
    dd VermilionCityPlayerMovingUp1Script
    dd VermilionCityPlayerExitShipScript
    dd VermilionCityPlayerMovingUp2Script
    dd VermilionCityPlayerAllowedToPassScript

VermilionCityDefaultScript:
    mov al, [ebp + wSpritePlayerStateData1FacingDirection]
    test al, al
    jnz .return
    mov esi, SSAnneTicketCheckCoords
    call ArePlayerCoordsInArray
    jae .return
    xor al, al
    mov [ebp + hJoyHeld], al
    mov [ebp + wSavedCoordIndex], al
    mov al, TEXT_VERMILIONCITY_SAILOR1
    mov [ebp + hTextID], al
    call DisplayTextID
    CheckEvent EVENT_SS_ANNE_LEFT
    jnz .ship_departed
    mov bh, 63
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and the predef id is not left in A because no reader is live; evidence=PredefPointers is unported and the flat model needs no bank switch, dataflow shows A dead after this site; lifetime=retired when PredefPointers is ported}
    call GetQuantityOfItemInBag
    mov al, bh
    test al, al
    jz .nr_75
        ret
.nr_75:
.ship_departed:
    mov al, PAD_UP
    mov [ebp + wSimulatedJoypadStatesEnd], al
    mov al, 0x1
    mov [ebp + wSimulatedJoypadStatesIndex], al
    call StartSimulatingJoypadStates
    mov al, SCRIPT_VERMILIONCITY_PLAYER_MOVING_UP1
    mov [ebp + wVermilionCityCurScript], al
    ret

.return:
    ret

SSAnneTicketCheckCoords:
    db 30, 18
    db -1

VermilionCityPlayerAllowedToPassScript:
    mov esi, SSAnneTicketCheckCoords
    call ArePlayerCoordsInArray
    jae .nr_96
        ret
.nr_96:
    mov al, SCRIPT_VERMILIONCITY_DEFAULT
    mov [ebp + wVermilionCityCurScript], al
    ret

VermilionCityPlayerExitShipScript:
    mov al, PAD_BUTTONS | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    mov al, PAD_UP
    mov [ebp + wSimulatedJoypadStatesEnd], al
    mov [ebp + wSimulatedJoypadStatesEnd + 1], al
    mov al, 2
    mov [ebp + wSimulatedJoypadStatesIndex], al
    call StartSimulatingJoypadStates
    mov al, SCRIPT_VERMILIONCITY_PLAYER_MOVING_UP2
    mov [ebp + wVermilionCityCurScript], al
    ret

VermilionCityPlayerMovingUp2Script:
    mov al, [ebp + wSimulatedJoypadStatesIndex]
    test al, al
    jz .nr_117
        ret
.nr_117:
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov [ebp + hJoyHeld], al
    mov al, SCRIPT_VERMILIONCITY_DEFAULT
    mov [ebp + wVermilionCityCurScript], al
    ret

VermilionCityPlayerMovingUp1Script:
    mov al, [ebp + wSimulatedJoypadStatesIndex]
    test al, al
    jz .nr_128
        ret
.nr_128:
    mov bl, 10
    call DelayFrames
    mov al, SCRIPT_VERMILIONCITY_DEFAULT
    mov [ebp + wVermilionCityCurScript], al
    ret

VermilionCity_TextPointers:
    dd VermilionCityBeautyText
    dd VermilionCityGambler1Text
    dd VermilionCitySailor1Text
    dd VermilionCityGambler2Text
    dd VermilionCityMachopText
    dd VermilionCitySailor2Text
    dd VermilionCityOfficerJennyText
    dd VermilionCitySignText
    dd VermilionCityNoticeSignText
    dd MartSignText
    dd PokeCenterSignText
    dd VermilionCityPokemonFanClubSignText
    dd VermilionCityGymSignText
    dd VermilionCityHarborSignText
VermilionCityBeautyText:
    text_far _VermilionCityBeautyText
    text_end

VermilionCityGambler1Text:
    CheckEvent EVENT_SS_ANNE_LEFT
    jnz .ship_departed
    mov esi, .DidYouSeeText
    call PrintText
    jmp .text_script_end

.ship_departed:
    mov esi, .SSAnneDepartedText
    call PrintText
.text_script_end:
    jmp TextScriptEnd

.DidYouSeeText:
    text_far _VermilionCityGambler1DidYouSeeText
    text_end
.SSAnneDepartedText:
    text_far _VermilionCityGambler1SSAnneDepartedText
    text_end

VermilionCitySailor1Text:
    CheckEvent EVENT_SS_ANNE_LEFT
    jnz .ship_departed
    mov al, [ebp + wSpritePlayerStateData1FacingDirection]
    cmp al, SPRITE_FACING_RIGHT
    jz .greet_player
    mov esi, .inFrontOfOrBehindGuardCoords
    call ArePlayerCoordsInArray
    jae .greet_player_and_check_ticket
.greet_player:
    mov esi, .WelcomeToSSAnneText
    call PrintText
    jmp .end

.greet_player_and_check_ticket:
    mov esi, .DoYouHaveATicketText
    call PrintText
    mov bh, 63
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and the predef id is not left in A because no reader is live; evidence=PredefPointers is unported and the flat model needs no bank switch, dataflow shows A dead after this site; lifetime=retired when PredefPointers is ported}
    call GetQuantityOfItemInBag
    mov al, bh
    test al, al
    jnz .player_has_ticket
    mov esi, .YouNeedATicketText
    call PrintText
    jmp .end

.player_has_ticket:
    mov esi, .FlashedTicketText
    call PrintText
    mov al, SCRIPT_VERMILIONCITY_PLAYER_ALLOWED_TO_PASS
    mov [ebp + wVermilionCityCurScript], al
    jmp .end

.ship_departed:
    mov esi, .ShipSetSailText
    call PrintText
.end:
    jmp TextScriptEnd

.inFrontOfOrBehindGuardCoords:
    db 29, 19
    db 31, 19
    db -1
.WelcomeToSSAnneText:
    text_far _VermilionCitySailor1WelcomeToSSAnneText
    text_end
.DoYouHaveATicketText:
    text_far _VermilionCitySailor1DoYouHaveATicketText
    text_end
.FlashedTicketText:
    text_far _VermilionCitySailor1FlashedTicketText
    text_end
.YouNeedATicketText:
    text_far _VermilionCitySailor1YouNeedATicketText
    text_end
.ShipSetSailText:
    text_far _VermilionCitySailor1ShipSetSailText
    text_end
VermilionCityGambler2Text:
    text_far _VermilionCityGambler2Text
    text_end
VermilionCityMachopText:
    text_far _VermilionCityMachopText

    mov al, 106
    call PlayCry
    call WaitForSoundToFinish
    mov esi, .StompingTheLandFlatText
    ret

.StompingTheLandFlatText:
    text_far _VermilionCityMachopStompingTheLandFlatText
    text_end
VermilionCitySailor2Text:
    text_far _VermilionCitySailor2Text
    text_end

VermilionCitySignText:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call VermilionCityPrintSignText
    jmp TextScriptEnd

VermilionCityNoticeSignText:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call VermilionCityPrintNoticeSignText
    jmp TextScriptEnd

VermilionCityPokemonFanClubSignText:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call VermilionCityPrintPokemonFanClubSignText
    jmp TextScriptEnd

VermilionCityGymSignText:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call VermilionCityPrintGymSignText
    jmp TextScriptEnd

VermilionCityHarborSignText:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call VermilionCityPrintHarborSignText
    jmp TextScriptEnd

VermilionCityOfficerJennyText:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call VermilionCityPrintOfficerJennyText
    jmp TextScriptEnd

VermilionCityPrintOfficerJennyText:
    CheckEvent EVENT_GOT_SQUIRTLE_FROM_OFFICER_JENNY
    jnz .asm_f1a69
    mov al, [ebp + wBeatGymFlags]
    test al, (1 << (2))
    jnz .asm_f1a24
    mov esi, OfficerJennyText1
    call PrintText
    ret

.asm_f1a24:
    mov esi, OfficerJennyText2
    call PrintText
    call YesNoChoice
    mov al, [ebp + wCurrentMenuItem]
    test al, al
    jnz .asm_f1a62
    mov al, 177
    mov [ebp + wNamedObjectIndex], al
    mov [ebp + wCurPartySpecies], al
    call GetMonName
    mov al, 0x1
    mov [ebp + wDoNotWaitForButtonPressAfterDisplayingText], al
    mov bx, ((177) << 8) | (10)
    call GivePokemon
    jb .nr_26
        ret
.nr_26:
    mov al, [ebp + wAddedToParty]
    test al, al
    jnz .sk_29
        call WaitForTextScrollButtonPress
.sk_29:
    mov al, 0x1
    mov [ebp + wDoNotWaitForButtonPressAfterDisplayingText], al
    mov esi, OfficerJennyText3
    call PrintText
    SetEvent EVENT_GOT_SQUIRTLE_FROM_OFFICER_JENNY
    ret

.asm_f1a62:
    mov esi, OfficerJennyText4
    call PrintText
    ret

.asm_f1a69:
    mov esi, OfficerJennyText5
    call PrintText
    ret

OfficerJennyText1:
    text_far _OfficerJennyText1
    text_end
OfficerJennyText2:
    text_far _OfficerJennyText2
    text_end
OfficerJennyText3:
    text_far _OfficerJennyText3
    text_waitbutton
    text_end
OfficerJennyText4:
    text_far _OfficerJennyText4
    text_end
OfficerJennyText5:
    text_far _OfficerJennyText5
    text_end

VermilionCityPrintSignText:
    mov esi, .text
    call PrintText
    ret

.text:
    text_far _VermilionCitySignText
    text_end

VermilionCityPrintNoticeSignText:
    mov esi, .text
    call PrintText
    ret

.text:
    text_far _VermilionCityNoticeSignText
    text_end

VermilionCityPrintPokemonFanClubSignText:
    mov esi, .text
    call PrintText
    ret

.text:
    text_far _VermilionCityPokemonFanClubSignText
    text_end

VermilionCityPrintGymSignText:
    mov esi, .text
    call PrintText
    ret

.text:
    text_far _VermilionCityGymSignText
    text_end

VermilionCityPrintHarborSignText:
    mov esi, .text
    call PrintText
    ret

.text:
    text_far _VermilionCityHarborSignText
    text_end
