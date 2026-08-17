; BillsHouse.asm — translated from pret scripts/BillsHouse.asm, scripts/BillsHouse_2.asm by dos_port/tools/sm83xlat.
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

global BillMovement_WalkAroundPlayer
global BillMovement_WalkToCellSeparator
global BillsHouseBillCheckOutMyRarePokemonText
global BillsHouseBillDontLeaveText
global BillsHouseBillPokemonText
global BillsHouseBillSSTicketText
global BillsHousePikachuConfused
global BillsHousePikachuWatchPlayer
global BillsHousePrintBillCheckOutMyRarePokemonText
global BillsHousePrintBillPokemonText
global BillsHousePrintBillSSTicketText
global BillsHouseScript0
global BillsHouseScript1
global BillsHouseScript2
global BillsHouseScript3
global BillsHouseScript4
global BillsHouseScript5
global BillsHouseScript6
global BillsHouseScript7
global BillsHouseScript8
global BillsHouseScript9
global BillsHouse_CheckMetBill
global BillsHouse_Script
global BillsHouse_ScriptPointers
global BillsHouse_TextPointers
global PikachuMovement_Confused
global PikachuMovement_EnterCellSeparatorDown
global PikachuMovement_EnterCellSeparatorNotDown
global PikachuMovement_ExitCellSeparator
global PikachuMovement_WatchPlayer1
global PikachuMovement_WatchPlayer2
global RLE_1e219

extern ApplyPikachuMovementData
extern Bankswitch
extern BillsHouse_CheckPikachuEmotion   ; NOT YET DEFINED IN THE PORT
extern CallFunctionInTable
extern CheckPikachuFollowingPlayer
extern CheckPikachuStatusCondition
extern DecodeRLEList
extern DelayFrames
extern DisablePikachuFollowingPlayer
extern DisplayTextID
extern EmotionBubble
extern EnableAutoTextBoxDrawing
extern GiveItem
extern HideObject
extern InitializePikachuTextID   ; NOT YET DEFINED IN THE PORT
extern MoveSprite
extern PrintText
extern SetSpriteFacingDirectionAndDelay   ; NOT YET DEFINED IN THE PORT
extern SetSpritePosition1
extern ShowObject
extern StartSimulatingJoypadStates
extern TextScriptEnd
extern TryApplyPikachuMovementData   ; NOT YET DEFINED IN THE PORT
extern UpdateSprites
extern YesNoChoice
extern _BillsHouseBillCheckOutMyRarePokemonText   ; NOT YET DEFINED IN THE PORT
extern _BillsHouseBillDontLeaveText   ; NOT YET DEFINED IN THE PORT
extern _BillsHouseBillImNotAPokemonText   ; NOT YET DEFINED IN THE PORT
extern _BillsHouseBillNoYouGottaHelpText   ; NOT YET DEFINED IN THE PORT
extern _BillsHouseBillThankYouText   ; NOT YET DEFINED IN THE PORT
extern _BillsHouseBillUseSeparationSystemText   ; NOT YET DEFINED IN THE PORT
extern _BillsHouseBillWhyDontYouGoInsteadOfMeText   ; NOT YET DEFINED IN THE PORT
extern _SSTicketNoRoomText   ; NOT YET DEFINED IN THE PORT
extern _SSTicketReceivedText   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_BILLSHOUSE_SCRIPT0                      equ 0
SCRIPT_BILLSHOUSE_SCRIPT1                      equ 1
SCRIPT_BILLSHOUSE_SCRIPT2                      equ 2
SCRIPT_BILLSHOUSE_SCRIPT3                      equ 3
SCRIPT_BILLSHOUSE_SCRIPT4                      equ 4
SCRIPT_BILLSHOUSE_SCRIPT5                      equ 5
SCRIPT_BILLSHOUSE_SCRIPT6                      equ 6
SCRIPT_BILLSHOUSE_SCRIPT7                      equ 7
SCRIPT_BILLSHOUSE_SCRIPT8                      equ 8
SCRIPT_BILLSHOUSE_SCRIPT9                      equ 9
TEXT_BILLSHOUSE_BILL_SS_TICKET                 equ 2

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
hSpriteFacingDirection                         equ 0xFF8D
hSpriteMapXCoord                               equ 0xFFEE
hSpriteMapYCoord                               equ 0xFFED
hSpriteScreenXCoord                            equ 0xFFEC
hSpriteScreenYCoord                            equ 0xFFEB
wBillsHouseCurScript                           equ 0xD660
wPikachuMapScriptFlags                         equ 0xD492
wPikachuSpawnStateFlags                        equ 0xD471
wSpritePlayerStateData1FacingDirection         equ 0xC109

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
BillsHouse_Script:
    call BillsHouse_CheckMetBill
    call EnableAutoTextBoxDrawing
    mov al, [ebp + wBillsHouseCurScript]
    mov esi, BillsHouse_ScriptPointers
    call CallFunctionInTable
    ret

%assign event_byte -1
%assign event_byte_a -1
BillsHouse_ScriptPointers:
    dd BillsHouseScript0
    dd BillsHouseScript1
    dd BillsHouseScript2
    dd BillsHouseScript3
    dd BillsHouseScript4
    dd BillsHouseScript5
    dd BillsHouseScript6
    dd BillsHouseScript7
    dd BillsHouseScript8
    dd BillsHouseScript9

%assign event_byte -1
%assign event_byte_a -1
BillsHouse_CheckMetBill:
    mov esi, wPikachuMapScriptFlags
    test byte [ebp + esi], (1 << (BIT_PIKACHU_MAP_SCRIPT_ACTIVE))
    pushfd    ; SM83 form writes no flags
        or byte [ebp + esi], (1 << (BIT_PIKACHU_MAP_SCRIPT_ACTIVE))
    popfd
    jz .nr_26
        ret
.nr_26:
    mov esi, wEventFlags + EVENT_BYTE(EVENT_MET_BILL_2)
    test byte [ebp + esi], EVENT_MASK(EVENT_MET_BILL_2)
    jz .notMetBill
    jmp .metBill

%assign event_byte -1
%assign event_byte_a -1
.notMetBill:
    mov al, SCRIPT_BILLSHOUSE_SCRIPT0
    jmp .setScript

%assign event_byte -1
%assign event_byte_a -1
.metBill:
    mov al, SCRIPT_BILLSHOUSE_SCRIPT9
.setScript:
    mov [ebp + wBillsHouseCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
BillsHouseScript0:
    mov al, [ebp + wPikachuSpawnStateFlags]
    setc ah                     ; SM83 `bit` preserves C — stash it
    test al, (1 << (BIT_PIKACHU_SPAWN_STARTER))
    bt   eax, 8                 ; CF = AH bit 0 = saved C; ZF untouched
    jz .done
; DEVIATION{class=banking; pret=macros/farcall.asm:callfar; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call CheckPikachuStatusCondition
    jb .done
; DEVIATION{class=banking; pret=macros/farcall.asm:callfar; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call BillsHousePikachuConfused
.done:
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov al, SCRIPT_BILLSHOUSE_SCRIPT1
    mov [ebp + wBillsHouseCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
BillsHouseScript1:
    ret

%assign event_byte -1
%assign event_byte_a -1
BillsHouseScript2:
    mov al, PAD_BUTTONS | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    mov al, [ebp + wSpritePlayerStateData1FacingDirection]
    test al, al   ; pret: and a ; cp SPRITE_FACING_DOWN
    mov edi, BillMovement_WalkToCellSeparator   ; pret: ld de, BillMovement_WalkToCellSeparator — MoveSprite takes EDI
    jnz .notDown
    call CheckPikachuFollowingPlayer
    jnz .pikachuNotFollowing
    call BillsHousePikachuWatchPlayer   ; pret: callfar BillsHousePikachuWatchPlayer
.pikachuNotFollowing:
    mov edi, BillMovement_WalkAroundPlayer   ; pret: ld de, BillMovement_WalkAroundPlayer — MoveSprite takes EDI
.notDown:
    mov al, 1   ; pret: ld a, BILLSHOUSE_BILL_POKEMON
    mov [ebp + hSpriteIndex], al
    call MoveSprite
    mov al, SCRIPT_BILLSHOUSE_SCRIPT3
    mov [ebp + wBillsHouseCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
BillMovement_WalkToCellSeparator:
    db NPC_MOVEMENT_UP
    db NPC_MOVEMENT_UP
    db NPC_MOVEMENT_UP
    db -1
BillMovement_WalkAroundPlayer:
    db NPC_MOVEMENT_RIGHT
    db NPC_MOVEMENT_UP
    db NPC_MOVEMENT_UP
    db NPC_MOVEMENT_LEFT
    db NPC_MOVEMENT_UP
    db -1

%assign event_byte -1
%assign event_byte_a -1
BillsHouseScript3:
    mov al, [ebp + wStatusFlags5]
    test al, (1 << (BIT_SCRIPTED_NPC_MOVEMENT))
    jz .nr_96
        ret
.nr_96:
    mov al, TOGGLE_BILL_POKEMON
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call HideObject
    call CheckPikachuFollowingPlayer
    jz .pikachuNotFollowing
    mov esi, PikachuMovement_EnterCellSeparatorDown
    mov al, [ebp + wSpritePlayerStateData1FacingDirection]
    test al, al
    jnz .applyPikachuMovement
    mov esi, PikachuMovement_EnterCellSeparatorNotDown
.applyPikachuMovement:
    call ApplyPikachuMovementData
; DEVIATION{class=banking; pret=macros/farcall.asm:callfar; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call InitializePikachuTextID
.pikachuNotFollowing:
    xor al, al
    mov [ebp + wJoyIgnore], al
    SetEvent EVENT_BILL_SAID_USE_CELL_SEPARATOR
    mov al, SCRIPT_BILLSHOUSE_SCRIPT4
    mov [ebp + wBillsHouseCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
PikachuMovement_EnterCellSeparatorDown:
    db 0
    db 30
    db 30
    db 30
    db 63
PikachuMovement_EnterCellSeparatorNotDown:
    db 0
    db 30
    db 31
    db 30
    db 30
    db 32
    db 54
    db 63

%assign event_byte -1
%assign event_byte_a -1
BillsHouseScript4:
    CheckEvent EVENT_USED_CELL_SEPARATOR_ON_BILL
    jnz .nr_137
        ret
.nr_137:
    mov al, PAD_SELECT | PAD_START | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    mov al, SCRIPT_BILLSHOUSE_SCRIPT5
    mov [ebp + wBillsHouseCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
BillsHouseScript5:
    mov al, 2
    mov [ebp + wSpriteIndex], al
    mov al, 0xc
    mov [ebp + hSpriteScreenYCoord], al
    mov al, 0x40
    mov [ebp + hSpriteScreenXCoord], al
    mov al, 6
    mov [ebp + hSpriteMapYCoord], al
    mov al, 5
    mov [ebp + hSpriteMapXCoord], al
    call SetSpritePosition1
    mov al, TOGGLE_BILL_1
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call ShowObject
    mov bl, 8
    call DelayFrames
    mov esi, wPikachuSpawnStateFlags
    test byte [ebp + esi], (1 << (BIT_PIKACHU_SPAWN_STARTER))
    jz .pikachuNotFollowing
    call CheckPikachuFollowingPlayer
    jz .pikachuNotFollowing
    mov al, 2
    mov [ebp + hSpriteIndex], al
    mov al, SPRITE_FACING_DOWN
    mov [ebp + hSpriteFacingDirection], al
    call SetSpriteFacingDirectionAndDelay
    mov esi, PikachuMovement_ExitCellSeparator
    call ApplyPikachuMovementData
    mov al, 0xf
    mov [ebp + wEmotionBubbleSpriteIndex], al
    mov al, EXCLAMATION_BUBBLE
    mov [ebp + wWhichEmotionBubble], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call EmotionBubble
; DEVIATION{class=banking; pret=macros/farcall.asm:callfar; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call InitializePikachuTextID
.pikachuNotFollowing:
    mov al, 2
    mov [ebp + hSpriteIndex], al
    mov edi, .BillExitMachineMovement   ; pret: ld de, .BillExitMachineMovement — MoveSprite takes it in EDI
    call MoveSprite
    mov al, SCRIPT_BILLSHOUSE_SCRIPT6
    mov [ebp + wBillsHouseCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
.BillExitMachineMovement:
    db NPC_MOVEMENT_DOWN
    db NPC_MOVEMENT_RIGHT
    db NPC_MOVEMENT_RIGHT
    db NPC_MOVEMENT_RIGHT
    db NPC_MOVEMENT_DOWN
    db -1
PikachuMovement_ExitCellSeparator:
    db 0
    db 55
    db 63

%assign event_byte -1
%assign event_byte_a -1
BillsHouseScript6:
    mov al, [ebp + wStatusFlags5]
    test al, (1 << (BIT_SCRIPTED_NPC_MOVEMENT))
    jz .nr_204
        ret
.nr_204:
    SetEvent EVENT_MET_BILL_2
    SetEvent EVENT_MET_BILL
    mov al, SCRIPT_BILLSHOUSE_SCRIPT7
    mov [ebp + wBillsHouseCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
BillsHouseScript7:
    xor al, al
    mov [ebp + wPlayerMovingDirection], al
    mov al, SPRITE_FACING_UP
    mov [ebp + wSpritePlayerStateData1FacingDirection], al
    mov al, PAD_SELECT | PAD_START | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    mov edi, RLE_1e219   ; pret: ld de, RLE_1e219 — DecodeRLEList takes it in EDI
    mov esi, wSimulatedJoypadStatesEnd
    call DecodeRLEList
    dec al
    mov [ebp + wSimulatedJoypadStatesIndex], al
    call StartSimulatingJoypadStates
    mov al, SCRIPT_BILLSHOUSE_SCRIPT8
    mov [ebp + wBillsHouseCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
RLE_1e219:
    db PAD_RIGHT, 0x3
    db 0xFF

%assign event_byte -1
%assign event_byte_a -1
BillsHouseScript8:
    mov al, [ebp + wSimulatedJoypadStatesIndex]
    test al, al
    jz .nr_235
        ret
.nr_235:
    xor al, al
    mov [ebp + wPlayerMovingDirection], al
    mov al, SPRITE_FACING_UP
    mov [ebp + wSpritePlayerStateData1FacingDirection], al
    mov al, 2
    mov [ebp + hSpriteIndex], al
    mov al, SPRITE_FACING_DOWN
    mov [ebp + hSpriteFacingDirection], al
    call SetSpriteFacingDirectionAndDelay
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov al, TEXT_BILLSHOUSE_BILL_SS_TICKET
    mov [ebp + hTextID], al
    call DisplayTextID
    mov al, SCRIPT_BILLSHOUSE_SCRIPT9
    mov [ebp + wBillsHouseCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
BillsHouseScript9:
    ret

%assign event_byte -1
%assign event_byte_a -1
BillsHouse_TextPointers:
    dd BillsHouseBillPokemonText
    dd BillsHouseBillSSTicketText
    dd BillsHouseBillCheckOutMyRarePokemonText
    dd BillsHouseBillDontLeaveText
BillsHouseBillDontLeaveText:
    text_far _BillsHouseBillDontLeaveText
    text_end

%assign event_byte -1
%assign event_byte_a -1
BillsHouseBillPokemonText:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call BillsHousePrintBillPokemonText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
BillsHouseBillSSTicketText:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call BillsHousePrintBillSSTicketText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
BillsHouseBillCheckOutMyRarePokemonText:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call BillsHousePrintBillCheckOutMyRarePokemonText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
BillsHousePrintBillPokemonText:
    mov esi, .ImNotAPokemonText
    call PrintText
    call YesNoChoice
    mov al, [ebp + wCurrentMenuItem]
    test al, al
    jnz .answered_no
.use_machine:
    mov esi, .UseSeparationSystemText
    call PrintText
    mov al, SCRIPT_BILLSHOUSE_SCRIPT2
    mov [ebp + wBillsHouseCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
.answered_no:
    mov esi, .NoYouGottaHelpText
    call PrintText
    jmp .use_machine

%assign event_byte -1
%assign event_byte_a -1
.ImNotAPokemonText:
    text_far _BillsHouseBillImNotAPokemonText
    text_end
.UseSeparationSystemText:
    text_far _BillsHouseBillUseSeparationSystemText
    text_end
.NoYouGottaHelpText:
    text_far _BillsHouseBillNoYouGottaHelpText
    text_end

%assign event_byte -1
%assign event_byte_a -1
BillsHousePrintBillSSTicketText:
    CheckEvent EVENT_GOT_SS_TICKET
    jnz .got_ss_ticket
    mov esi, .ThankYouText
    call PrintText
    mov bx, (S_S_TICKET << 8) | (1)   ; pret: lb bc, S_S_TICKET, 1 (BillsHouse_2.asm:36)
    call GiveItem
    jae .bag_full
    mov esi, .SSTicketReceivedText
    call PrintText
    SetEvent EVENT_GOT_SS_TICKET
    mov al, TOGGLE_CERULEAN_GUARD_1
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call ShowObject
    mov al, TOGGLE_CERULEAN_GUARD_2
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call HideObject
.got_ss_ticket:
    mov esi, .WhyDontYouGoInsteadOfMeText
    call PrintText
    ret

%assign event_byte -1
%assign event_byte_a -1
.bag_full:
    mov esi, .SSTicketNoRoomText
    call PrintText
    ret

%assign event_byte -1
%assign event_byte_a -1
.ThankYouText:
    text_far _BillsHouseBillThankYouText
    text_end
.SSTicketReceivedText:
    text_far _SSTicketReceivedText
    sound_get_key_item
    text_promptbutton
    text_end
.SSTicketNoRoomText:
    text_far _SSTicketNoRoomText
    text_end
.WhyDontYouGoInsteadOfMeText:
    text_far _BillsHouseBillWhyDontYouGoInsteadOfMeText
    text_end

%assign event_byte -1
%assign event_byte_a -1
BillsHousePrintBillCheckOutMyRarePokemonText:
    mov esi, .text
    call PrintText
    ret

%assign event_byte -1
%assign event_byte_a -1
.text:
    text_far _BillsHouseBillCheckOutMyRarePokemonText
    text_end

; ---------------------------------------------------------------------------
; BAIL[pikachu-table-index] BillsHouse_CheckPikachuEmotion (scripts/BillsHouse_2.asm:85-101) — at scripts/BillsHouse_2.asm:92: ldpikaemotion needs (X_id - Table) / N across object files
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, [wCurMap]
; PRET| 	cp BILLS_HOUSE
; PRET| 	jr nz, .noEmotion
; PRET| 	call CheckPikachuFollowingPlayer
; PRET| 	jr z, .noEmotion
; PRET| 	ld a, [wBillsHouseCurScript]
; PRET| 	cp SCRIPT_BILLSHOUSE_SCRIPT5
; PRET| 	ldpikaemotion e, PikachuEmotion27
; PRET| 	ret z
; PRET| 	cp SCRIPT_BILLSHOUSE_SCRIPT0
; PRET| 	ldpikaemotion e, PikachuEmotion23
; PRET| 	ret z
; PRET| 	CheckEventHL EVENT_MET_BILL_2
; PRET| 	ldpikaemotion e, PikachuEmotion32
; PRET| 	ret z
; PRET| 	ldpikaemotion e, PikachuEmotion31
; PRET| 	ret

%assign event_byte -1
%assign event_byte_a -1
.noEmotion:
    mov dl, 0xff
    ret

%assign event_byte -1
%assign event_byte_a -1
BillsHousePikachuConfused:
    mov al, PAD_BUTTONS | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    xor al, al
    mov [ebp + wPlayerMovingDirection], al
    call UpdateSprites
    call UpdateSprites
    mov esi, PikachuMovement_Confused
    call ApplyPikachuMovementData
    mov al, 0xf
    mov [ebp + wEmotionBubbleSpriteIndex], al
    mov al, QUESTION_BUBBLE
    mov [ebp + wWhichEmotionBubble], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call EmotionBubble
    call DisablePikachuFollowingPlayer
; DEVIATION{class=banking; pret=macros/farcall.asm:callfar; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call InitializePikachuTextID
    ret

%assign event_byte -1
%assign event_byte_a -1
PikachuMovement_Confused:
    db 0
    db 32
    db 32
    db 32
    db 30
    db 63

%assign event_byte -1
%assign event_byte_a -1
BillsHousePikachuWatchPlayer:
    mov esi, PikachuMovement_WatchPlayer1
    mov bh, SPRITE_FACING_UP
    call TryApplyPikachuMovementData
    mov esi, PikachuMovement_WatchPlayer2
    mov bh, SPRITE_FACING_RIGHT
    call TryApplyPikachuMovementData
    ret

%assign event_byte -1
%assign event_byte_a -1
PikachuMovement_WatchPlayer1:
    db 0
    db 31
    db 29
    db 56
    db 63
PikachuMovement_WatchPlayer2:
    db 0
    db 30
    db 31
    db 31
    db 29
    db 56
    db 63
