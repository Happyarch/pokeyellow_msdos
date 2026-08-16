; Route23.asm — translated from pret scripts/Route23.asm by dos_port/tools/sm83xlat.
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

global Route23CheckForBadgeScript
global Route23DefaultScript
global Route23Guard1Text
global Route23Guard2Text
global Route23Guard3Text
global Route23Guard4Text
global Route23Guard5Text
global Route23GuardsYCoords
global Route23MovePlayerDownScript
global Route23PlayerMovingScript
global Route23PrintOhThatsTheBadgeTextScript
global Route23ResetToDefaultScript
global Route23SetVictoryRoadBoulders
global Route23Swimmer1Text
global Route23Swimmer2Text
global Route23YouDontHaveTheBadgeYetText
global Route23_Script
global Route23_ScriptPointers
global Route23_TextPointers

extern BadgeTextPointers   ; NOT YET DEFINED IN THE PORT
extern CallFunctionInTable   ; NOT YET DEFINED IN THE PORT
extern CascadeBadgeText   ; NOT YET DEFINED IN THE PORT
extern DisplayTextID   ; NOT YET DEFINED IN THE PORT
extern EarthBadgeText   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern FlagActionPredef   ; NOT YET DEFINED IN THE PORT
extern HideObject   ; NOT YET DEFINED IN THE PORT
extern MarshBadgeText   ; NOT YET DEFINED IN THE PORT
extern PlaySoundWaitForCurrent   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern RainbowBadgeText   ; NOT YET DEFINED IN THE PORT
extern Route23CopyBadgeTextScript   ; NOT YET DEFINED IN THE PORT
extern Route23OhThatIsTheBadgeText   ; NOT YET DEFINED IN THE PORT
extern Route23VictoryRoadGateSignText   ; NOT YET DEFINED IN THE PORT
extern ShowObject   ; NOT YET DEFINED IN THE PORT
extern SoulBadgeText   ; NOT YET DEFINED IN THE PORT
extern StartSimulatingJoypadStates   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern ThunderBadgeText   ; NOT YET DEFINED IN THE PORT
extern VolcanoBadgeText   ; NOT YET DEFINED IN THE PORT
extern WaitForSoundToFinish   ; NOT YET DEFINED IN THE PORT
extern _Route23OhThatIsTheBadgeText   ; NOT YET DEFINED IN THE PORT
extern _Route23YouDontHaveTheBadgeYetText   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_ROUTE23_DEFAULT                         equ 0
SCRIPT_ROUTE23_PLAYER_MOVING                   equ 1
SCRIPT_ROUTE23_RESET_TO_DEFAULT                equ 2

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wRoute23CurScript                              equ 0xD666
wSpritePlayerStateData1FacingDirection         equ 0xC109
wWhichBadge                                    equ 0xCD3D

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

Route23_Script:
    call Route23SetVictoryRoadBoulders
    call EnableAutoTextBoxDrawing
    mov esi, Route23_ScriptPointers
    mov al, [ebp + wRoute23CurScript]
    jmp CallFunctionInTable

Route23SetVictoryRoadBoulders:
    mov esi, wCurrentMapScriptFlags
    test byte [ebp + esi], (1 << (BIT_CUR_MAP_LOADED_2))
    pushfd    ; SM83 form writes no flags
        and byte [ebp + esi], ~(1 << (BIT_CUR_MAP_LOADED_2)) & 0xFF
    popfd
    jnz .nr_12
        ret
.nr_12:
    ResetEvents EVENT_VICTORY_ROAD_2_BOULDER_ON_SWITCH1, EVENT_VICTORY_ROAD_2_BOULDER_ON_SWITCH2
    ResetEvents EVENT_VICTORY_ROAD_3_BOULDER_ON_SWITCH1, EVENT_VICTORY_ROAD_3_BOULDER_ON_SWITCH2
    mov al, 124
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and the predef id is not left in A because no reader is live; evidence=PredefPointers is unported and the flat model needs no bank switch, dataflow shows A dead after this site; lifetime=retired when PredefPointers is ported}
    call ShowObject
    mov al, 96
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef_jump; behavior=Predef dispatch replaced by a direct jmp, and the predef id is not left in A because no reader is live; evidence=PredefPointers is unported and the flat model needs no bank switch, dataflow shows A dead after this site; lifetime=retired when PredefPointers is ported}
    jmp HideObject

Route23_ScriptPointers:
    dd Route23DefaultScript
    dd Route23PlayerMovingScript
    dd Route23ResetToDefaultScript

Route23DefaultScript:
    mov esi, Route23GuardsYCoords
    mov al, [ebp + wYCoord]
    mov bh, al
    mov dl, 0x0
    mov bl, ((EVENT_PASSED_CASCADEBADGE_CHECK) - ((EVENT_PASSED_CASCADEBADGE_CHECK) / 8) * 8) + ((EVENT_PASSED_EARTHBADGE_CHECK + 1) - (EVENT_PASSED_CASCADEBADGE_CHECK))
.loop:
    mov al, [esi]
    lea esi, [esi+1]
    cmp al, -1
    jnz .nr_37
        ret
.nr_37:
    inc dl
    dec bl
    cmp al, bh
    jnz .loop
    cmp al, 35
    jnz .not_past_victory_road
    mov al, [ebp + wXCoord]
    cmp al, 14
    jb .nr_46
        ret
.nr_46:
.not_past_victory_road:
    mov al, dl
    mov [ebp + hSpriteIndex], al
    mov al, bl
    mov [ebp + wWhichBadge], al
    mov bh, FLAG_TEST
    mov esi, W_EVENT_FLAGS + EVENT_BYTE(EVENT_PASSED_CASCADEBADGE_CHECK)
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and the predef id is not left in A because no reader is live; evidence=PredefPointers is unported and the flat model needs no bank switch, dataflow shows A dead after this site; lifetime=retired when PredefPointers is ported}
    call FlagActionPredef
    mov al, bl
    test al, al
    jz .nr_57
        ret
.nr_57:
    call Route23CopyBadgeTextScript
    call DisplayTextID
    xor al, al
    mov [ebp + hJoyHeld], al
    ret

Route23GuardsYCoords:
    db 35
    db 56
    db 85
    db 96
    db 105
    db 119
    db 136
    db -1

; ---------------------------------------------------------------------------
; BAIL[add-hl-r16] Route23CopyBadgeTextScript (scripts/Route23.asm:75-91) — at scripts/Route23.asm:79: hl bc
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, BadgeTextPointers
; PRET| 	ld a, [wWhichBadge]
; PRET| 	ld c, a
; PRET| 	ld b, 0
; PRET| 	add hl, bc
; PRET| 	add hl, bc
; PRET| 	ld a, [hli]
; PRET| 	ld h, [hl]
; PRET| 	ld l, a
; PRET| 	ld de, wNameBuffer
; PRET| .copyTextLoop
; PRET| 	ld a, [hli]
; PRET| 	ld [de], a
; PRET| 	inc de
; PRET| 	cp '@'
; PRET| 	jr nz, .copyTextLoop
; PRET| 	ret

; ---------------------------------------------------------------------------
; BAIL[inline-text-db] BadgeTextPointers (scripts/Route23.asm:94-121) — at scripts/Route23.asm:103: db "EARTHBADGE@"
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	dw CascadeBadgeText
; PRET| 	dw ThunderBadgeText
; PRET| 	dw RainbowBadgeText
; PRET| 	dw SoulBadgeText
; PRET| 	dw MarshBadgeText
; PRET| 	dw VolcanoBadgeText
; PRET| 	dw EarthBadgeText
; PRET| 
; PRET| EarthBadgeText:
; PRET| 	db "EARTHBADGE@"
; PRET| 
; PRET| VolcanoBadgeText:
; PRET| 	db "VOLCANOBADGE@"
; PRET| 
; PRET| MarshBadgeText:
; PRET| 	db "MARSHBADGE@"
; PRET| 
; PRET| SoulBadgeText:
; PRET| 	db "SOULBADGE@"
; PRET| 
; PRET| RainbowBadgeText:
; PRET| 	db "RAINBOWBADGE@"
; PRET| 
; PRET| ThunderBadgeText:
; PRET| 	db "THUNDERBADGE@"
; PRET| 
; PRET| CascadeBadgeText:
; PRET| 	db "CASCADEBADGE@"

Route23MovePlayerDownScript:
    mov al, 0x1
    mov [ebp + wSimulatedJoypadStatesIndex], al
    mov al, PAD_DOWN
    mov [ebp + wSimulatedJoypadStatesEnd], al
    xor al, al
    mov [ebp + wSpritePlayerStateData1FacingDirection], al
    mov [ebp + wJoyIgnore], al
    jmp StartSimulatingJoypadStates

Route23PlayerMovingScript:
    mov al, [ebp + wSimulatedJoypadStatesIndex]
    test al, al
    jz .nr_136
        ret
.nr_136:
Route23ResetToDefaultScript:
    mov al, SCRIPT_ROUTE23_DEFAULT
    mov [ebp + wRoute23CurScript], al
    ret

Route23_TextPointers:
    dd Route23Guard1Text
    dd Route23Guard2Text
    dd Route23Swimmer1Text
    dd Route23Swimmer2Text
    dd Route23Guard3Text
    dd Route23Guard4Text
    dd Route23Guard5Text
    dd Route23VictoryRoadGateSignText

Route23Guard1Text:
    mov al, ((EVENT_PASSED_CASCADEBADGE_CHECK) - ((EVENT_PASSED_CASCADEBADGE_CHECK) / 8) * 8) + ((EVENT_PASSED_EARTHBADGE_CHECK) - (EVENT_PASSED_CASCADEBADGE_CHECK))
    call Route23CheckForBadgeScript
    jmp TextScriptEnd

Route23Guard2Text:
    mov al, ((EVENT_PASSED_CASCADEBADGE_CHECK) - ((EVENT_PASSED_CASCADEBADGE_CHECK) / 8) * 8) + ((EVENT_PASSED_VOLCANOBADGE_CHECK) - (EVENT_PASSED_CASCADEBADGE_CHECK))
    call Route23CheckForBadgeScript
    jmp TextScriptEnd

Route23Swimmer1Text:
    mov al, ((EVENT_PASSED_CASCADEBADGE_CHECK) - ((EVENT_PASSED_CASCADEBADGE_CHECK) / 8) * 8) + ((EVENT_PASSED_MARSHBADGE_CHECK) - (EVENT_PASSED_CASCADEBADGE_CHECK))
    call Route23CheckForBadgeScript
    jmp TextScriptEnd

Route23Swimmer2Text:
    mov al, ((EVENT_PASSED_CASCADEBADGE_CHECK) - ((EVENT_PASSED_CASCADEBADGE_CHECK) / 8) * 8) + ((EVENT_PASSED_SOULBADGE_CHECK) - (EVENT_PASSED_CASCADEBADGE_CHECK))
    call Route23CheckForBadgeScript
    jmp TextScriptEnd

Route23Guard3Text:
    mov al, ((EVENT_PASSED_CASCADEBADGE_CHECK) - ((EVENT_PASSED_CASCADEBADGE_CHECK) / 8) * 8) + ((EVENT_PASSED_RAINBOWBADGE_CHECK) - (EVENT_PASSED_CASCADEBADGE_CHECK))
    call Route23CheckForBadgeScript
    jmp TextScriptEnd

Route23Guard4Text:
    mov al, ((EVENT_PASSED_CASCADEBADGE_CHECK) - ((EVENT_PASSED_CASCADEBADGE_CHECK) / 8) * 8) + ((EVENT_PASSED_THUNDERBADGE_CHECK) - (EVENT_PASSED_CASCADEBADGE_CHECK))
    call Route23CheckForBadgeScript
    jmp TextScriptEnd

Route23Guard5Text:
    mov al, (EVENT_PASSED_CASCADEBADGE_CHECK) - ((EVENT_PASSED_CASCADEBADGE_CHECK) / 8) * 8
    call Route23CheckForBadgeScript
    jmp TextScriptEnd

Route23CheckForBadgeScript:
    mov [ebp + wWhichBadge], al
    call Route23CopyBadgeTextScript
    mov al, [ebp + wWhichBadge]
    inc al
    mov bl, al
    mov bh, FLAG_TEST
    mov esi, W_OBTAINED_BADGES
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and the predef id is not left in A because no reader is live; evidence=PredefPointers is unported and the flat model needs no bank switch, dataflow shows A dead after this site; lifetime=retired when PredefPointers is ported}
    call FlagActionPredef
    mov al, bl
    test al, al
    jnz .have_badge
    mov esi, Route23YouDontHaveTheBadgeYetText
    call PrintText
    call Route23MovePlayerDownScript
    mov al, SCRIPT_ROUTE23_PLAYER_MOVING
    mov [ebp + wRoute23CurScript], al
    ret

.have_badge:
    mov esi, Route23OhThatIsTheBadgeText
    call PrintText
    mov al, [ebp + wWhichBadge]
    mov bl, al
    mov bh, FLAG_SET
    mov esi, W_EVENT_FLAGS + EVENT_BYTE(EVENT_PASSED_CASCADEBADGE_CHECK)
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and the predef id is not left in A because no reader is live; evidence=PredefPointers is unported and the flat model needs no bank switch, dataflow shows A dead after this site; lifetime=retired when PredefPointers is ported}
    call FlagActionPredef
    mov al, SCRIPT_ROUTE23_RESET_TO_DEFAULT
    mov [ebp + wRoute23CurScript], al
    ret

Route23PrintOhThatsTheBadgeTextScript:
    mov esi, Route23OhThatIsTheBadgeText
    jmp PrintText

Route23YouDontHaveTheBadgeYetText:
    text_far _Route23YouDontHaveTheBadgeYetText

    mov al, SFX_DENIED
    call PlaySoundWaitForCurrent
    call WaitForSoundToFinish
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[text-sound-command-unported] Route23OhThatIsTheBadgeText (scripts/Route23.asm:238-245) — at scripts/Route23.asm:239: sound_get_item_1
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _Route23OhThatIsTheBadgeText
; PRET| 	sound_get_item_1
; PRET| 	text_far _Route23GoRightAheadText
; PRET| 	text_end
; PRET| 
; PRET| Route23VictoryRoadGateSignText:
; PRET| 	text_far _Route23VictoryRoadGateSignText
; PRET| 	text_end
