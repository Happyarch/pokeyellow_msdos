; SafariZoneGate.asm — translated from pret scripts/SafariZoneGate.asm, scripts/SafariZoneGate_2.asm by dos_port/tools/sm83xlat.
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

global Pointers_f2100
global SafariZoneEntranceAutoWalk
global SafariZoneEntranceAutoWalk2
global SafariZoneEntranceCalculateLowCostAdmission
global SafariZoneEntranceText_f20c4
global SafariZoneEntranceText_f20c9
global SafariZoneEntranceText_f20f6
global SafariZoneEntranceText_f210a
global SafariZoneEntranceText_f210f
global SafariZoneEntranceText_f2114
global SafariZoneEntranceText_f2119
global SafariZoneGateDefaultScript
global SafariZoneGateLeavingSafariScript
global SafariZoneGatePlayerMovingDownScript
global SafariZoneGatePlayerMovingRightScript
global SafariZoneGatePlayerMovingUpScript
global SafariZoneGatePrintSafariZoneWorker2Text
global SafariZoneGateReturnSimulatedJoypadStateScript
global SafariZoneGateSafariZoneWorker1GoodHaulComeAgainText
global SafariZoneGateSafariZoneWorker1LeavingEarlyText
global SafariZoneGateSafariZoneWorker1Text
global SafariZoneGateSafariZoneWorker1WouldYouLikeToJoinText
global SafariZoneGateSafariZoneWorker2Text
global SafariZoneGateSetScriptAfterMoveScript
global SafariZoneGateWouldYouLikeToJoinScript
global SafariZoneGate_Script
global SafariZoneGate_ScriptPointers
global SafariZoneGate_TextPointers

extern AddNTimes
extern ArePlayerCoordsInArray
extern Bankswitch
extern CallFunctionInTable
extern CopyData
extern Delay3
extern DisplayTextBoxID
extern DisplayTextID
extern DivideBCDPredef3
extern EnableAutoTextBoxDrawing
extern FillMemory
extern HasEnoughMoney
extern PlaySoundWaitForCurrent
extern PrintText
extern PrintText_NoCreatingTextBox
extern SafariZoneEntranceConvertBCDtoNumber   ; NOT YET DEFINED IN THE PORT
extern SafariZoneEntranceGetLowCostAdmissionText   ; NOT YET DEFINED IN THE PORT
extern SafariZoneGatePrintSafariZoneWorker1WouldYouLikeToJoinText   ; NOT YET DEFINED IN THE PORT
extern StartSimulatingJoypadStates
extern SubBCDPredef
extern TextScriptEnd
extern UpdateSprites
extern WaitForSoundToFinish
extern YesNoChoice
extern _SafariZoneGateSafariZoneWorker1CallYouOnThePAText   ; NOT YET DEFINED IN THE PORT
extern _SafariZoneGateSafariZoneWorker1GoodHaulComeAgainText   ; NOT YET DEFINED IN THE PORT
extern _SafariZoneGateSafariZoneWorker1GoodLuckText   ; NOT YET DEFINED IN THE PORT
extern _SafariZoneGateSafariZoneWorker1LeavingEarlyText   ; NOT YET DEFINED IN THE PORT
extern _SafariZoneGateSafariZoneWorker1NotEnoughMoneyText   ; NOT YET DEFINED IN THE PORT
extern _SafariZoneGateSafariZoneWorker1PleaseComeAgainText   ; NOT YET DEFINED IN THE PORT
extern _SafariZoneGateSafariZoneWorker1ReturnSafariBallsText   ; NOT YET DEFINED IN THE PORT
extern _SafariZoneGateSafariZoneWorker1Text   ; NOT YET DEFINED IN THE PORT
extern _SafariZoneGateSafariZoneWorker1ThatllBe500PleaseText   ; NOT YET DEFINED IN THE PORT
extern _SafariZoneGateSafariZoneWorker1WouldYouLikeToJoinText   ; NOT YET DEFINED IN THE PORT
extern _SafariZoneGateSafariZoneWorker2FirstTimeHereText   ; NOT YET DEFINED IN THE PORT
extern _SafariZoneGateSafariZoneWorker2SafariZoneExplanationText   ; NOT YET DEFINED IN THE PORT
extern _SafariZoneGateSafariZoneWorker2YoureARegularHereText   ; NOT YET DEFINED IN THE PORT
extern _SafariZoneLowCostText1   ; NOT YET DEFINED IN THE PORT
extern _SafariZoneLowCostText2   ; NOT YET DEFINED IN THE PORT
extern _SafariZoneLowCostText3   ; NOT YET DEFINED IN THE PORT
extern _SafariZoneLowCostText4   ; NOT YET DEFINED IN THE PORT
extern _SafariZoneLowCostText5   ; NOT YET DEFINED IN THE PORT
extern _SafariZoneLowCostText6   ; NOT YET DEFINED IN THE PORT
extern _SafariZoneLowCostText7   ; NOT YET DEFINED IN THE PORT
extern _SafariZoneLowCostText8   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_SAFARIZONEGATE_DEFAULT                  equ 0
SCRIPT_SAFARIZONEGATE_PLAYER_MOVING_RIGHT      equ 1
SCRIPT_SAFARIZONEGATE_WOULD_YOU_LIKE_TO_JOIN   equ 2
SCRIPT_SAFARIZONEGATE_PLAYER_MOVING            equ 3
SCRIPT_SAFARIZONEGATE_PLAYER_MOVING_DOWN       equ 4
SCRIPT_SAFARIZONEGATE_LEAVING_SAFARI           equ 5
SCRIPT_SAFARIZONEGATE_SET_SCRIPT_AFTER_MOVE    equ 6
TEXT_SAFARIZONEGATE_SAFARI_ZONE_WORKER1_1      equ 3
TEXT_SAFARIZONEGATE_SAFARI_ZONE_WORKER1_WOULD_YOU_LIKE_TO_JOIN equ 4
TEXT_SAFARIZONEGATE_SAFARI_ZONE_WORKER1_LEAVING_EARLY equ 5
TEXT_SAFARIZONEGATE_SAFARI_ZONE_WORKER1_GOOD_HAUL_COME_AGAIN equ 6

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wCoordIndex                                    equ 0xCD3D
wNextSafariZoneGateScript                      equ 0xCF0D
wPriceTemp                                     equ 0xCD3D
wSafariSteps                                   equ 0xD70C
wSpritePlayerStateData1FacingDirection         equ 0xC109

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
SafariZoneGate_Script:
    call EnableAutoTextBoxDrawing
    mov esi, SafariZoneGate_ScriptPointers
    mov al, [ebp + wSafariZoneGateCurScript]
    call CallFunctionInTable
    ret

%assign event_byte -1
%assign event_byte_a -1
SafariZoneGate_ScriptPointers:
    dd SafariZoneGateDefaultScript
    dd SafariZoneGatePlayerMovingRightScript
    dd SafariZoneGateWouldYouLikeToJoinScript
    dd SafariZoneGatePlayerMovingUpScript
    dd SafariZoneGatePlayerMovingDownScript
    dd SafariZoneGateLeavingSafariScript
    dd SafariZoneGateSetScriptAfterMoveScript

%assign event_byte -1
%assign event_byte_a -1
SafariZoneGateDefaultScript:
    mov esi, .PlayerNextToSafariZoneWorker1CoordsArray
    call ArePlayerCoordsInArray
    jb .nr_22
        ret
.nr_22:
    mov al, TEXT_SAFARIZONEGATE_SAFARI_ZONE_WORKER1_1
    mov [ebp + hTextID], al
    call DisplayTextID
    mov al, PAD_BUTTONS | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    xor al, al
    mov [ebp + hJoyHeld], al
    mov al, SPRITE_FACING_RIGHT
    mov [ebp + wSpritePlayerStateData1FacingDirection], al
    mov al, [ebp + wCoordIndex]
    cmp al, 1
    jz .player_not_next_to_worker
    mov al, SCRIPT_SAFARIZONEGATE_WOULD_YOU_LIKE_TO_JOIN
    mov [ebp + wSafariZoneGateCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
.player_not_next_to_worker:
    mov al, PAD_RIGHT
    mov bl, 1
    call SafariZoneEntranceAutoWalk
    mov al, PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    mov al, SCRIPT_SAFARIZONEGATE_PLAYER_MOVING_RIGHT
    mov [ebp + wSafariZoneGateCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
.PlayerNextToSafariZoneWorker1CoordsArray:
    db 2, 3
    db 2, 4
    db -1

%assign event_byte -1
%assign event_byte_a -1
SafariZoneGatePlayerMovingRightScript:
    call SafariZoneGateReturnSimulatedJoypadStateScript
    jz .nr_55
        ret
.nr_55:
SafariZoneGateWouldYouLikeToJoinScript:
    xor al, al
    mov [ebp + hJoyHeld], al
    mov [ebp + wJoyIgnore], al
    call UpdateSprites
    mov al, TEXT_SAFARIZONEGATE_SAFARI_ZONE_WORKER1_WOULD_YOU_LIKE_TO_JOIN
    mov [ebp + hTextID], al
    call DisplayTextID
    mov al, PAD_BUTTONS | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    ret

%assign event_byte -1
%assign event_byte_a -1
SafariZoneGatePlayerMovingUpScript:
    call SafariZoneGateReturnSimulatedJoypadStateScript
    jz .nr_70
        ret
.nr_70:
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov al, SCRIPT_SAFARIZONEGATE_LEAVING_SAFARI
    mov [ebp + wSafariZoneGateCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
SafariZoneGateLeavingSafariScript:
    mov al, PLAYER_DIR_DOWN
    mov [ebp + wPlayerMovingDirection], al
    CheckAndResetEvent EVENT_SAFARI_GAME_OVER
    jz .leaving_early
    ResetEventReuseHL EVENT_IN_SAFARI_ZONE
    call UpdateSprites
    mov al, PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    mov al, TEXT_SAFARIZONEGATE_SAFARI_ZONE_WORKER1_GOOD_HAUL_COME_AGAIN
    mov [ebp + hTextID], al
    call DisplayTextID
    xor al, al
    mov [ebp + wNumSafariBalls], al
    mov [ebp + wSafariSteps], al
    mov [ebp + wSafariSteps], al
    mov al, PAD_DOWN
    mov bl, 3
    call SafariZoneEntranceAutoWalk
    mov al, SCRIPT_SAFARIZONEGATE_PLAYER_MOVING_DOWN
    mov [ebp + wSafariZoneGateCurScript], al
    jmp .return

%assign event_byte -1
%assign event_byte_a -1
.leaving_early:
    mov al, TEXT_SAFARIZONEGATE_SAFARI_ZONE_WORKER1_LEAVING_EARLY
    mov [ebp + hTextID], al
    call DisplayTextID
.return:
    ret

%assign event_byte -1
%assign event_byte_a -1
SafariZoneGatePlayerMovingDownScript:
    call SafariZoneGateReturnSimulatedJoypadStateScript
    jz .nr_108
        ret
.nr_108:
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov al, SCRIPT_SAFARIZONEGATE_DEFAULT
    mov [ebp + wSafariZoneGateCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
SafariZoneGateSetScriptAfterMoveScript:
    call SafariZoneGateReturnSimulatedJoypadStateScript
    jz .nr_117
        ret
.nr_117:
    call Delay3
    mov al, [ebp + wNextSafariZoneGateScript]
    mov [ebp + wSafariZoneGateCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
SafariZoneEntranceAutoWalk:
    pushfd
    push eax
    mov bh, 0
    mov al, bl
    mov [ebp + wSimulatedJoypadStatesIndex], al
    mov esi, wSimulatedJoypadStatesEnd
    pop eax
    popfd
    call FillMemory
    jmp StartSimulatingJoypadStates

%assign event_byte -1
%assign event_byte_a -1
SafariZoneGateReturnSimulatedJoypadStateScript:
    mov al, [ebp + wSimulatedJoypadStatesIndex]
    test al, al
    ret

%assign event_byte -1
%assign event_byte_a -1
SafariZoneGate_TextPointers:
    dd SafariZoneGateSafariZoneWorker1Text
    dd SafariZoneGateSafariZoneWorker2Text
    dd SafariZoneGateSafariZoneWorker1Text
    dd SafariZoneGateSafariZoneWorker1WouldYouLikeToJoinText
    dd SafariZoneGateSafariZoneWorker1LeavingEarlyText
    dd SafariZoneGateSafariZoneWorker1GoodHaulComeAgainText
SafariZoneGateSafariZoneWorker1Text:
    text_far _SafariZoneGateSafariZoneWorker1Text
    text_end

%assign event_byte -1
%assign event_byte_a -1
SafariZoneGateSafariZoneWorker1WouldYouLikeToJoinText:
; DEVIATION{class=banking; pret=macros/farcall.asm:callfar; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call SafariZoneGatePrintSafariZoneWorker1WouldYouLikeToJoinText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
SafariZoneGateSafariZoneWorker1LeavingEarlyText:
    text_far _SafariZoneGateSafariZoneWorker1LeavingEarlyText

%assign event_byte -1
%assign event_byte_a -1
    call YesNoChoice
    mov al, [ebp + wCurrentMenuItem]
    test al, al
    jnz .not_ready_to_leave
    mov esi, .ReturnSafariBallsText
    call PrintText
    xor al, al
    mov [ebp + wSpritePlayerStateData1FacingDirection], al
    mov al, PAD_DOWN
    mov bl, 3
    call SafariZoneEntranceAutoWalk
    ResetEvents EVENT_SAFARI_GAME_OVER, EVENT_IN_SAFARI_ZONE
    mov al, SCRIPT_SAFARIZONEGATE_DEFAULT
    mov [ebp + wNextSafariZoneGateScript], al
    jmp .set_current_script

%assign event_byte -1
%assign event_byte_a -1
.not_ready_to_leave:
    mov esi, .GoodLuckText
    call PrintText
    mov al, SPRITE_FACING_UP
    mov [ebp + wSpritePlayerStateData1FacingDirection], al
    mov al, PAD_UP
    mov bl, 1
    call SafariZoneEntranceAutoWalk
    mov al, SCRIPT_SAFARIZONEGATE_LEAVING_SAFARI
    mov [ebp + wNextSafariZoneGateScript], al
.set_current_script:
    mov al, SCRIPT_SAFARIZONEGATE_SET_SCRIPT_AFTER_MOVE
    mov [ebp + wSafariZoneGateCurScript], al
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.ReturnSafariBallsText:
    text_far _SafariZoneGateSafariZoneWorker1ReturnSafariBallsText
    text_end
.GoodLuckText:
    text_far _SafariZoneGateSafariZoneWorker1GoodLuckText
    text_end
SafariZoneGateSafariZoneWorker1GoodHaulComeAgainText:
    text_far _SafariZoneGateSafariZoneWorker1GoodHaulComeAgainText
    text_end

%assign event_byte -1
%assign event_byte_a -1
SafariZoneGateSafariZoneWorker2Text:
; DEVIATION{class=banking; pret=macros/farcall.asm:callfar; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call SafariZoneGatePrintSafariZoneWorker2Text
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] SafariZoneGatePrintSafariZoneWorker1WouldYouLikeToJoinText (scripts/SafariZoneGate_2.asm:2-19) — at scripts/SafariZoneGate_2.asm:16: SafariZoneGatePrintSafariZoneWorker1WouldYouLikeToJoinText.has_positive_balance is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .WelcomeText
; PRET| 	call PrintText
; PRET| 	ld a, MONEY_BOX
; PRET| 	ld [wTextBoxID], a
; PRET| 	call DisplayTextBoxID
; PRET| 	call YesNoChoice
; PRET| 	ld a, [wCurrentMenuItem]
; PRET| 	and a
; PRET| 	jp nz, .PleaseComeAgain
; PRET| 	ld hl, wPlayerMoney
; PRET| 	ld a, [hli]
; PRET| 	or [hl]
; PRET| 	inc hl
; PRET| 	or [hl]
; PRET| 	jr nz, .has_positive_balance
; PRET| 	call SafariZoneEntranceGetLowCostAdmissionText
; PRET| 	jr c, .CantPayWalkDown
; PRET| 	jr .poor_mans_discount

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] SafariZoneGatePrintSafariZoneWorker1WouldYouLikeToJoinText.has_positive_balance (scripts/SafariZoneGate_2.asm:22-34) — at scripts/SafariZoneGate_2.asm:29: SafariZoneGatePrintSafariZoneWorker1WouldYouLikeToJoinText.success is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	xor a
; PRET| 	ldh [hMoney], a
; PRET| 	ld a, $05
; PRET| 	ldh [hMoney + 1], a
; PRET| 	ld a, $00
; PRET| 	ldh [hMoney + 2], a
; PRET| 	call HasEnoughMoney
; PRET| 	jr nc, .success
; PRET| 	ld hl, .NotEnoughMoneyText
; PRET| 	call PrintText
; PRET| 	call SafariZoneEntranceCalculateLowCostAdmission
; PRET| 	jr c, .CantPayWalkDown
; PRET| 	jr .poor_mans_discount

; ---------------------------------------------------------------------------
; BAIL[hl-half-register-access] SafariZoneGatePrintSafariZoneWorker1WouldYouLikeToJoinText.success (scripts/SafariZoneGate_2.asm:37-70) — at scripts/SafariZoneGate_2.asm:59: `h` is a half of ESI and has no flag-safe 8-bit x86 form
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	xor a
; PRET| 	ld [wPriceTemp], a
; PRET| 	ld a, $05
; PRET| 	ld [wPriceTemp + 1], a
; PRET| 	ld a, $00
; PRET| 	ld [wPriceTemp + 2], a
; PRET| 	ld hl, wPriceTemp + 2
; PRET| 	ld de, wPlayerMoney + 2
; PRET| 	ld c, 3
; PRET| 	predef SubBCDPredef
; PRET| 	ld a, SFX_PURCHASE
; PRET| 	call PlaySoundWaitForCurrent
; PRET| 	call WaitForSoundToFinish
; PRET| 	ld a, MONEY_BOX
; PRET| 	ld [wTextBoxID], a
; PRET| 	call DisplayTextBoxID
; PRET| 	ld hl, .MakePaymentText
; PRET| 	call PrintText
; PRET| 	ld a, 30
; PRET| 	ld hl, 502
; PRET| .poor_mans_discount
; PRET| 	ld [wNumSafariBalls], a
; PRET| 	ld a, h
; PRET| 	ld [wSafariSteps], a
; PRET| 	ld a, l
; PRET| 	ld [wSafariSteps + 1], a
; PRET| 	ld a, PAD_UP
; PRET| 	ld c, 3
; PRET| 	call SafariZoneEntranceAutoWalk2
; PRET| 	SetEvent EVENT_IN_SAFARI_ZONE
; PRET| 	ResetEventReuseHL EVENT_SAFARI_GAME_OVER
; PRET| 	ld a, SCRIPT_SAFARIZONEGATE_PLAYER_MOVING
; PRET| 	ld [wSafariZoneGateCurScript], a
; PRET| 	jr .done

%assign event_byte -1
%assign event_byte_a -1
.PleaseComeAgain:
    mov esi, .PleaseComeAgainText
    call PrintText
.CantPayWalkDown:
    mov al, PAD_DOWN
    mov bl, 1
    call SafariZoneEntranceAutoWalk2
    mov al, SCRIPT_SAFARIZONEGATE_PLAYER_MOVING_DOWN
    mov [ebp + wSafariZoneGateCurScript], al
.done:
    ret

%assign event_byte -1
%assign event_byte_a -1
.WelcomeText:
    text_far _SafariZoneGateSafariZoneWorker1WouldYouLikeToJoinText
    text_end
.MakePaymentText:
    text_far _SafariZoneGateSafariZoneWorker1ThatllBe500PleaseText
    sound_get_item_1
    text_far _SafariZoneGateSafariZoneWorker1CallYouOnThePAText
    text_end
.PleaseComeAgainText:
    text_far _SafariZoneGateSafariZoneWorker1PleaseComeAgainText
    text_end
.NotEnoughMoneyText:
    text_far _SafariZoneGateSafariZoneWorker1NotEnoughMoneyText
    text_end

%assign event_byte -1
%assign event_byte_a -1
SafariZoneGatePrintSafariZoneWorker2Text:
    mov esi, .FirstTimeHereText
    call PrintText
    call YesNoChoice
    mov al, [ebp + wCurrentMenuItem]
    test al, al
    mov esi, .YoureARegularHereText
    jnz .print_text
    mov esi, .SafariZoneExplanationText
.print_text:
    call PrintText
    ret

%assign event_byte -1
%assign event_byte_a -1
.FirstTimeHereText:
    text_far _SafariZoneGateSafariZoneWorker2FirstTimeHereText
    text_end
.SafariZoneExplanationText:
    text_far _SafariZoneGateSafariZoneWorker2SafariZoneExplanationText
    text_end
.YoureARegularHereText:
    text_far _SafariZoneGateSafariZoneWorker2YoureARegularHereText
    text_end

%assign event_byte -1
%assign event_byte_a -1
SafariZoneEntranceAutoWalk2:
    pushfd
    push eax
    mov bh, 0
    mov al, bl
    mov [ebp + wSimulatedJoypadStatesIndex], al
    mov esi, wSimulatedJoypadStatesEnd
    pop eax
    popfd
    call FillMemory
    jmp StartSimulatingJoypadStates

%assign event_byte -1
%assign event_byte_a -1
SafariZoneEntranceCalculateLowCostAdmission:
    mov esi, wPlayerMoney
    mov dx, hMoney
    mov bx, 0x3
    call CopyData
    xor al, al
    mov [ebp + hDivideBCDDivisor], al
    mov [ebp + hDivideBCDDivisor + 1], al
    mov al, 23
    mov [ebp + hDivideBCDDivisor + 2], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call DivideBCDPredef3
    mov al, [ebp + hDivideBCDQuotient + 2]
    call SafariZoneEntranceConvertBCDtoNumber
    pushfd
    push eax
    mov esi, wPlayerMoney
    xor al, al
    mov bx, 0x3
    call FillMemory
    mov esi, SafariZoneEntranceText_f20c4
    call PrintText_NoCreatingTextBox
    mov al, MONEY_BOX
    mov [ebp + wTextBoxID], al
    call DisplayTextBoxID
    mov esi, SafariZoneEntranceText_f20c9
    call PrintText
    pop eax
    popfd
    inc al
    jz .max_balls
    cmp al, 29
    jb .load_balls
.max_balls:
    mov al, 29
.load_balls:
    mov esi, 502
    test al, al
    ret

%assign event_byte -1
%assign event_byte_a -1
SafariZoneEntranceText_f20c4:
    text_far _SafariZoneLowCostText1
    text_end
SafariZoneEntranceText_f20c9:
    text_far _SafariZoneLowCostText2
    text_end

; ---------------------------------------------------------------------------
; BAIL[add-hl-r16] SafariZoneEntranceGetLowCostAdmissionText (scripts/SafariZoneGate_2.asm:183-200) — at scripts/SafariZoneGate_2.asm:190: hl de
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, wSafariSteps
; PRET| 	ld a, [hl]
; PRET| 	push af
; PRET| 	inc [hl]
; PRET| 	ld e, a
; PRET| 	ld d, $0
; PRET| 	ld hl, Pointers_f2100
; PRET| 	add hl, de
; PRET| 	add hl, de
; PRET| 	ld a, [hli]
; PRET| 	ld h, [hl]
; PRET| 	ld l, a
; PRET| 	call PrintText
; PRET| 	pop af
; PRET| 	cp $3
; PRET| 	jr z, .give_one_ball
; PRET| 	scf
; PRET| 	ret

%assign event_byte -1
%assign event_byte_a -1
.give_one_ball:
    mov esi, SafariZoneEntranceText_f20f6
    call PrintText_NoCreatingTextBox
    mov al, 0x1
    mov esi, 502
    test al, al
    ret

%assign event_byte -1
%assign event_byte_a -1
SafariZoneEntranceText_f20f6:
    text_far _SafariZoneLowCostText3
    sound_get_item_1
    text_far _SafariZoneLowCostText4
    text_end
Pointers_f2100:
    dd SafariZoneEntranceText_f210a
    dd SafariZoneEntranceText_f210f
    dd SafariZoneEntranceText_f2114
    dd SafariZoneEntranceText_f2119
    dd SafariZoneEntranceText_f2119
SafariZoneEntranceText_f210a:
    text_far _SafariZoneLowCostText5
    text_end
SafariZoneEntranceText_f210f:
    text_far _SafariZoneLowCostText6
    text_end
SafariZoneEntranceText_f2114:
    text_far _SafariZoneLowCostText7
    text_end
SafariZoneEntranceText_f2119:
    text_far _SafariZoneLowCostText8
    text_end

; ---------------------------------------------------------------------------
; BAIL[hl-half-register-access] SafariZoneEntranceConvertBCDtoNumber (scripts/SafariZoneGate_2.asm:240-252) — at scripts/SafariZoneGate_2.asm:243: `l` is a half of ESI and has no flag-safe 8-bit x86 form
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	push hl
; PRET| 	ld c, a
; PRET| 	and $f
; PRET| 	ld l, a
; PRET| 	ld h, $0
; PRET| 	ld a, c
; PRET| 	and $f0
; PRET| 	swap a
; PRET| 	ld bc, 10
; PRET| 	call AddNTimes
; PRET| 	ld a, l
; PRET| 	pop hl
; PRET| 	ret
