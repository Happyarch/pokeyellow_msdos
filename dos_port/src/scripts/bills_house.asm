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

%include "assets/map_dims.inc"

global BillMovement_WalkAroundPlayer
global BillMovement_WalkToCellSeparator
global BillsHouseBillCheckOutMyRarePokemonText
global BillsHouseBillDontLeaveText
global BillsHouseBillPokemonText
global BillsHouseBillSSTicketText
global BillsHousePikachuWatchPlayer
global BillsHousePrintBillCheckOutMyRarePokemonText
global BillsHousePrintBillPokemonText
global BillsHouseScript1
global BillsHouseScript4
global BillsHouseScript6
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

extern ApplyPikachuMovementData   ; NOT YET DEFINED IN THE PORT
extern Bankswitch   ; NOT YET DEFINED IN THE PORT
extern BillsHousePikachuConfused   ; NOT YET DEFINED IN THE PORT
extern BillsHousePrintBillSSTicketText   ; NOT YET DEFINED IN THE PORT
extern BillsHouseScript0   ; NOT YET DEFINED IN THE PORT
extern BillsHouseScript2   ; NOT YET DEFINED IN THE PORT
extern BillsHouseScript3   ; NOT YET DEFINED IN THE PORT
extern BillsHouseScript5   ; NOT YET DEFINED IN THE PORT
extern BillsHouseScript7   ; NOT YET DEFINED IN THE PORT
extern BillsHouse_CheckPikachuEmotion   ; NOT YET DEFINED IN THE PORT
extern CallFunctionInTable   ; NOT YET DEFINED IN THE PORT
extern CheckPikachuFollowingPlayer   ; NOT YET DEFINED IN THE PORT
extern CheckPikachuStatusCondition   ; NOT YET DEFINED IN THE PORT
extern DecodeRLEList   ; NOT YET DEFINED IN THE PORT
extern DelayFrames   ; NOT YET DEFINED IN THE PORT
extern DisablePikachuFollowingPlayer   ; NOT YET DEFINED IN THE PORT
extern DisplayTextID   ; NOT YET DEFINED IN THE PORT
extern EmotionBubble   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern GiveItem   ; NOT YET DEFINED IN THE PORT
extern HideObject   ; NOT YET DEFINED IN THE PORT
extern MoveSprite   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern SetSpriteFacingDirectionAndDelay   ; NOT YET DEFINED IN THE PORT
extern SetSpritePosition1   ; NOT YET DEFINED IN THE PORT
extern ShowObject   ; NOT YET DEFINED IN THE PORT
extern StartSimulatingJoypadStates   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern TryApplyPikachuMovementData   ; NOT YET DEFINED IN THE PORT
extern UpdateSprites   ; NOT YET DEFINED IN THE PORT
extern YesNoChoice   ; NOT YET DEFINED IN THE PORT
extern _BillsHouseBillCheckOutMyRarePokemonText   ; NOT YET DEFINED IN THE PORT
extern _BillsHouseBillDontLeaveText   ; NOT YET DEFINED IN THE PORT
extern _BillsHouseBillImNotAPokemonText   ; NOT YET DEFINED IN THE PORT
extern _BillsHouseBillNoYouGottaHelpText   ; NOT YET DEFINED IN THE PORT
extern _BillsHouseBillThankYouText   ; NOT YET DEFINED IN THE PORT
extern _BillsHouseBillUseSeparationSystemText   ; NOT YET DEFINED IN THE PORT
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

BillsHouse_Script:
    call BillsHouse_CheckMetBill
    call EnableAutoTextBoxDrawing
    mov al, [ebp + wBillsHouseCurScript]
    mov esi, BillsHouse_ScriptPointers
    call CallFunctionInTable
    ret

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

BillsHouse_CheckMetBill:
    mov esi, wPikachuMapScriptFlags
    test byte [ebp + esi], (1 << (7))
    pushfd    ; SM83 form writes no flags
        or byte [ebp + esi], (1 << (7))
    popfd
    jz .nr_26
        ret
.nr_26:
    mov esi, W_EVENT_FLAGS + EVENT_BYTE(EVENT_MET_BILL_2)
    test byte [ebp + esi], EVENT_MASK(EVENT_MET_BILL_2)
    jz .notMetBill
    jmp .metBill

.notMetBill:
    mov al, SCRIPT_BILLSHOUSE_SCRIPT0
    jmp .setScript

.metBill:
    mov al, SCRIPT_BILLSHOUSE_SCRIPT9
.setScript:
    mov [ebp + wBillsHouseCurScript], al
    ret

; ---------------------------------------------------------------------------
; BAIL[bit-clobbers-live-carry] BillsHouseScript0 (scripts/BillsHouse.asm:42-53) — at scripts/BillsHouse.asm:43: bit BIT_PIKACHU_SPAWN_STARTER, a
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, [wPikachuSpawnStateFlags]
; PRET| 	bit BIT_PIKACHU_SPAWN_STARTER, a
; PRET| 	jr z, .done
; PRET| 	callfar CheckPikachuStatusCondition
; PRET| 	jr c, .done
; PRET| 	callfar BillsHousePikachuConfused
; PRET| .done
; PRET| 	xor a
; PRET| 	ld [wJoyIgnore], a
; PRET| 	ld a, SCRIPT_BILLSHOUSE_SCRIPT1
; PRET| 	ld [wBillsHouseCurScript], a
; PRET| 	ret

BillsHouseScript1:
    ret

; ---------------------------------------------------------------------------
; BAIL[host-pointer-in-16bit-reg] BillsHouseScript2 (scripts/BillsHouse.asm:59-76) — at scripts/BillsHouse.asm:63: de cannot hold the 32-bit address of BillMovement_WalkToCellSeparator; callee <none in range> has no abi.json entry
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, PAD_BUTTONS | PAD_CTRL_PAD
; PRET| 	ld [wJoyIgnore], a
; PRET| 	ld a, [wSpritePlayerStateData1FacingDirection]
; PRET| 	and a ; cp SPRITE_FACING_DOWN
; PRET| 	ld de, BillMovement_WalkToCellSeparator
; PRET| 	jr nz, .notDown
; PRET| 	call CheckPikachuFollowingPlayer
; PRET| 	jr nz, .pikachuNotFollowing
; PRET| 	callfar BillsHousePikachuWatchPlayer
; PRET| .pikachuNotFollowing
; PRET| 	ld de, BillMovement_WalkAroundPlayer
; PRET| .notDown
; PRET| 	ld a, BILLSHOUSE_BILL_POKEMON
; PRET| 	ldh [hSpriteIndex], a
; PRET| 	call MoveSprite
; PRET| 	ld a, SCRIPT_BILLSHOUSE_SCRIPT3
; PRET| 	ld [wBillsHouseCurScript], a
; PRET| 	ret

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

; ---------------------------------------------------------------------------
; BAIL[predef-leaves-id-in-a] BillsHouseScript3 (scripts/BillsHouse.asm:94-116) — at scripts/BillsHouse.asm:99: predef HideObject
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, [wStatusFlags5]
; PRET| 	bit BIT_SCRIPTED_NPC_MOVEMENT, a
; PRET| 	ret nz
; PRET| 	ld a, TOGGLE_BILL_POKEMON
; PRET| 	ld [wToggleableObjectIndex], a
; PRET| 	predef HideObject
; PRET| 	call CheckPikachuFollowingPlayer
; PRET| 	jr z, .pikachuNotFollowing
; PRET| 	ld hl, PikachuMovement_EnterCellSeparatorDown
; PRET| 	ld a, [wSpritePlayerStateData1FacingDirection]
; PRET| 	and a ; cp SPRITE_FACING_DOWN
; PRET| 	jr nz, .applyPikachuMovement
; PRET| 	ld hl, PikachuMovement_EnterCellSeparatorNotDown
; PRET| .applyPikachuMovement
; PRET| 	call ApplyPikachuMovementData
; PRET| 	callfar InitializePikachuTextID
; PRET| .pikachuNotFollowing
; PRET| 	xor a
; PRET| 	ld [wJoyIgnore], a
; PRET| 	SetEvent EVENT_BILL_SAID_USE_CELL_SEPARATOR
; PRET| 	ld a, SCRIPT_BILLSHOUSE_SCRIPT4
; PRET| 	ld [wBillsHouseCurScript], a
; PRET| 	ret

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

; ---------------------------------------------------------------------------
; BAIL[predef-leaves-id-in-a] BillsHouseScript5 (scripts/BillsHouse.asm:145-186) — at scripts/BillsHouse.asm:158: predef ShowObject
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, BILLSHOUSE_BILL1
; PRET| 	ld [wSpriteIndex], a
; PRET| 	ld a, $c
; PRET| 	ldh [hSpriteScreenYCoord], a
; PRET| 	ld a, $40
; PRET| 	ldh [hSpriteScreenXCoord], a
; PRET| 	ld a, 6
; PRET| 	ldh [hSpriteMapYCoord], a
; PRET| 	ld a, 5
; PRET| 	ldh [hSpriteMapXCoord], a
; PRET| 	call SetSpritePosition1
; PRET| 	ld a, TOGGLE_BILL_1
; PRET| 	ld [wToggleableObjectIndex], a
; PRET| 	predef ShowObject
; PRET| 	ld c, 8
; PRET| 	call DelayFrames
; PRET| 	ld hl, wPikachuSpawnStateFlags
; PRET| 	bit BIT_PIKACHU_SPAWN_STARTER, [hl]
; PRET| 	jr z, .pikachuNotFollowing
; PRET| 	call CheckPikachuFollowingPlayer
; PRET| 	jr z, .pikachuNotFollowing
; PRET| 	ld a, BILLSHOUSE_BILL1
; PRET| 	ldh [hSpriteIndex], a
; PRET| 	ld a, SPRITE_FACING_DOWN
; PRET| 	ldh [hSpriteFacingDirection], a
; PRET| 	call SetSpriteFacingDirectionAndDelay
; PRET| 	ld hl, PikachuMovement_ExitCellSeparator
; PRET| 	call ApplyPikachuMovementData
; PRET| 	ld a, $f
; PRET| 	ld [wEmotionBubbleSpriteIndex], a
; PRET| 	ld a, EXCLAMATION_BUBBLE
; PRET| 	ld [wWhichEmotionBubble], a
; PRET| 	predef EmotionBubble
; PRET| 	callfar InitializePikachuTextID
; PRET| .pikachuNotFollowing
; PRET| 	ld a, BILLSHOUSE_BILL1
; PRET| 	ldh [hSpriteIndex], a
; PRET| 	ld de, .BillExitMachineMovement
; PRET| 	call MoveSprite
; PRET| 	ld a, SCRIPT_BILLSHOUSE_SCRIPT6
; PRET| 	ld [wBillsHouseCurScript], a
; PRET| 	ret

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

; ---------------------------------------------------------------------------
; BAIL[host-pointer-in-16bit-reg] BillsHouseScript7 (scripts/BillsHouse.asm:212-226) — at scripts/BillsHouse.asm:218: de cannot hold the 32-bit address of RLE_1e219; callee DecodeRLEList has no abi.json entry
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	xor a
; PRET| 	ld [wPlayerMovingDirection], a
; PRET| 	ld a, SPRITE_FACING_UP
; PRET| 	ld [wSpritePlayerStateData1FacingDirection], a
; PRET| 	ld a, PAD_SELECT | PAD_START | PAD_CTRL_PAD
; PRET| 	ld [wJoyIgnore], a
; PRET| 	ld de, RLE_1e219
; PRET| 	ld hl, wSimulatedJoypadStatesEnd
; PRET| 	call DecodeRLEList
; PRET| 	dec a
; PRET| 	ld [wSimulatedJoypadStatesIndex], a
; PRET| 	call StartSimulatingJoypadStates
; PRET| 	ld a, SCRIPT_BILLSHOUSE_SCRIPT8
; PRET| 	ld [wBillsHouseCurScript], a
; PRET| 	ret

RLE_1e219:
    db PAD_RIGHT, 0x3
    db 0xFF

BillsHouseScript8:
    mov al, [ebp + W_SIMULATED_JOYPAD_STATES_INDEX]
    test al, al
    jz .nr_235
        ret
.nr_235:
    xor al, al
    mov [ebp + W_PLAYER_MOVING_DIRECTION], al
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

BillsHouseScript9:
    ret

BillsHouse_TextPointers:
    dd BillsHouseBillPokemonText
    dd BillsHouseBillSSTicketText
    dd BillsHouseBillCheckOutMyRarePokemonText
    dd BillsHouseBillDontLeaveText
BillsHouseBillDontLeaveText:
    text_far _BillsHouseBillDontLeaveText
    text_end

BillsHouseBillPokemonText:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call BillsHousePrintBillPokemonText
    jmp TextScriptEnd

BillsHouseBillSSTicketText:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call BillsHousePrintBillSSTicketText
    jmp TextScriptEnd

BillsHouseBillCheckOutMyRarePokemonText:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call BillsHousePrintBillCheckOutMyRarePokemonText
    jmp TextScriptEnd

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

.answered_no:
    mov esi, .NoYouGottaHelpText
    call PrintText
    jmp .use_machine

.ImNotAPokemonText:
    text_far _BillsHouseBillImNotAPokemonText
    text_end
.UseSeparationSystemText:
    text_far _BillsHouseBillUseSeparationSystemText
    text_end
.NoYouGottaHelpText:
    text_far _BillsHouseBillNoYouGottaHelpText
    text_end

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] BillsHousePrintBillSSTicketText (scripts/BillsHouse_2.asm:32-51) — at scripts/BillsHouse_2.asm:33: .got_ss_ticket is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEvent EVENT_GOT_SS_TICKET
; PRET| 	jr nz, .got_ss_ticket
; PRET| 	ld hl, .ThankYouText
; PRET| 	call PrintText
; PRET| 	lb bc, S_S_TICKET, 1
; PRET| 	call GiveItem
; PRET| 	jr nc, .bag_full
; PRET| 	ld hl, .SSTicketReceivedText
; PRET| 	call PrintText
; PRET| 	SetEvent EVENT_GOT_SS_TICKET
; PRET| 	ld a, TOGGLE_CERULEAN_GUARD_1
; PRET| 	ld [wToggleableObjectIndex], a
; PRET| 	predef ShowObject
; PRET| 	ld a, TOGGLE_CERULEAN_GUARD_2
; PRET| 	ld [wToggleableObjectIndex], a
; PRET| 	predef HideObject
; PRET| .got_ss_ticket
; PRET| 	ld hl, .WhyDontYouGoInsteadOfMeText
; PRET| 	call PrintText
; PRET| 	ret

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] BillsHousePrintBillSSTicketText.bag_full (scripts/BillsHouse_2.asm:53-55) — at scripts/BillsHouse_2.asm:53: .SSTicketNoRoomText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .SSTicketNoRoomText
; PRET| 	call PrintText
; PRET| 	ret

; ---------------------------------------------------------------------------
; BAIL[text-sound-command-unported] BillsHousePrintBillSSTicketText.ThankYouText (scripts/BillsHouse_2.asm:58-73) — at scripts/BillsHouse_2.asm:63: sound_get_key_item
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _BillsHouseBillThankYouText
; PRET| 	text_end
; PRET| 
; PRET| .SSTicketReceivedText:
; PRET| 	text_far _SSTicketReceivedText
; PRET| 	sound_get_key_item
; PRET| 	text_promptbutton
; PRET| 	text_end
; PRET| 
; PRET| .SSTicketNoRoomText:
; PRET| 	text_far _SSTicketNoRoomText
; PRET| 	text_end
; PRET| 
; PRET| .WhyDontYouGoInsteadOfMeText:
; PRET| 	text_far _BillsHouseBillWhyDontYouGoInsteadOfMeText
; PRET| 	text_end

BillsHousePrintBillCheckOutMyRarePokemonText:
    mov esi, .text
    call PrintText
    ret

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

.noEmotion:
    mov dl, 0xff
    ret

; ---------------------------------------------------------------------------
; BAIL[predef-leaves-id-in-a] BillsHousePikachuConfused (scripts/BillsHouse_2.asm:108-123) — at scripts/BillsHouse_2.asm:120: predef EmotionBubble
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, PAD_BUTTONS | PAD_CTRL_PAD
; PRET| 	ld [wJoyIgnore], a
; PRET| 	xor a
; PRET| 	ld [wPlayerMovingDirection], a
; PRET| 	call UpdateSprites
; PRET| 	call UpdateSprites
; PRET| 	ld hl, PikachuMovement_Confused
; PRET| 	call ApplyPikachuMovementData
; PRET| 	ld a, $f ; pikachu
; PRET| 	ld [wEmotionBubbleSpriteIndex], a
; PRET| 	ld a, QUESTION_BUBBLE
; PRET| 	ld [wWhichEmotionBubble], a
; PRET| 	predef EmotionBubble
; PRET| 	call DisablePikachuFollowingPlayer
; PRET| 	callfar InitializePikachuTextID
; PRET| 	ret

PikachuMovement_Confused:
    db 0
    db 32
    db 32
    db 32
    db 30
    db 63

BillsHousePikachuWatchPlayer:
    mov esi, PikachuMovement_WatchPlayer1
    mov bh, SPRITE_FACING_UP
    call TryApplyPikachuMovementData
    mov esi, PikachuMovement_WatchPlayer2
    mov bh, SPRITE_FACING_RIGHT
    call TryApplyPikachuMovementData
    ret

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
