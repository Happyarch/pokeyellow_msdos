; dos_port/src/slots/slot_machine.asm

%include "gb_macros.inc"
%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_text.inc"
%include "coords.inc"
%include "assets/audio_constants.inc"

; Tier-1 DATA: message streams and string constants from data/text/text_2.asm
; and engine/slots/slot_machine.asm.
%include "assets/slots_text.inc"

section .text

global SlotMachine_SetFlags
global SlotMachine_FindWheel1Wheel2Matches
global SlotMachine_CheckForMatch
global SlotMachine_GetWheel3Tiles
global SlotMachine_GetWheel2Tiles
global SlotMachine_GetWheel1Tiles
global SlotMachine_GetWheelTiles
global SlotMachine_AnimWheel1
global SlotMachine_AnimWheel2
global SlotMachine_AnimWheel3
global SlotMachine_AnimWheel
global SlotMachine_PutOutLitBalls
global SlotMachine_LightBalls
global SlotMachine_UpdateThreeCoinBallTiles
global SlotMachine_UpdateTwoCoinBallTiles
global SlotMachine_UpdateOneCoinBallTiles
global SlotMachine_UpdateBallTiles
global SlotMachine_SubtractBetFromPlayerCoins
global SlotMachine_PrintCreditCoins
global SlotMachine_PrintPayoutCoins
global SlotMachine_PayCoinsToPlayer

global PlaySlotMachineText
global OutOfCoinsSlotMachineText
global BetHowManySlotMachineText
global StartSlotMachineText
global NotEnoughCoinsSlotMachineText
global OneMoreGoSlotMachineText
global LinedUpText
global NotThisTimeText
global YeahText

global SlotMachineMap
global SlotMachineMapEnd
global SlotMachineTiles1
global SlotMachineTiles1End

global SlotMachine_PrintWinningSymbol
global SymbolLinedUpSlotMachineText
global SlotReward8Func
global SlotReward15Func
global SlotReward100Func
global SlotReward300Func
global SlotRewardPointers

extern Random
extern SlotMachineWheel1
extern SlotMachineWheel2
extern SlotMachineWheel3
extern PrintBCDNumber           ; src/home/print_bcd.asm
extern PrintNumber              ; src/home/print_num.asm
extern SubBCDPredef             ; src/engine/math/bcd.asm
extern AddBCDPredef             ; src/engine/math/bcd.asm
extern WaitForSoundToFinish     ; src/home/delay.asm
extern PlaySound                ; src/home/audio.asm
extern UpdateCGBPal_OBP0        ; src/home/cgb_palettes.asm
extern DelayFrames              ; src/home/delay.asm
extern PrintText                ; src/home/window.asm

%define BIT_SLOTS_CAN_WIN 6
%define BIT_SLOTS_CAN_WIN_WITH_7_OR_BAR 7

wPayoutCoins                    equ 0xCD4A
wTempCoins1                     equ 0xCD46
wTempCoins2                     equ 0xCD4A
wSlotMachineWinningSymbol       equ 0xCD41
SLOTSBAR                        equ 0x0604


; -----------------------------------------------------------------------------
; SlotMachine_SetFlags
; -----------------------------------------------------------------------------
SlotMachine_SetFlags:
    mov al, byte [ebp + W_SLOT_MACHINE_FLAGS]
    test al, (1 << BIT_SLOTS_CAN_WIN_WITH_7_OR_BAR)
    jnz .exit
    
    mov al, byte [ebp + W_SLOT_MACHINE_ALLOW_MATCHES_COUNTER]
    test al, al
    jnz .allowMatches
    
    call Random
    test al, al
    jz .setAllowMatchesCounter
    
    mov bl, al
    mov al, byte [ebp + W_SLOT_MACHINE_SEVEN_AND_BAR_MODE_CHANCE]
    cmp bl, al
    jc .allowSevenAndBarMatches
    
    mov al, 210
    cmp bl, al
    jc .allowMatches
    
    mov byte [ebp + W_SLOT_MACHINE_FLAGS], 0
.exit:
    ret

.allowMatches:
    or byte [ebp + W_SLOT_MACHINE_FLAGS], (1 << BIT_SLOTS_CAN_WIN)
    ret

.setAllowMatchesCounter:
    mov byte [ebp + W_SLOT_MACHINE_ALLOW_MATCHES_COUNTER], 60
    ret

.allowSevenAndBarMatches:
    or byte [ebp + W_SLOT_MACHINE_FLAGS], (1 << BIT_SLOTS_CAN_WIN_WITH_7_OR_BAR)
    ret

; -----------------------------------------------------------------------------
; SlotMachine_FindWheel1Wheel2Matches
; Return whether wheel 1 and wheel 2's current positions allow a match in Z flag.
; -----------------------------------------------------------------------------
SlotMachine_FindWheel1Wheel2Matches:
    mov esi, W_SLOT_MACHINE_WHEEL1_BOTTOM_TILE
    mov edi, W_SLOT_MACHINE_WHEEL2_BOTTOM_TILE
    
    ; bottom-bottom
    mov al, byte [ebp + edi]
    cmp al, byte [ebp + esi]
    jz .match
    
    ; bottom-middle
    inc edi
    mov al, byte [ebp + edi]
    cmp al, byte [ebp + esi]
    jz .match
    
    ; middle-middle
    inc esi
    cmp al, byte [ebp + esi]
    jz .match
    
    ; top-middle
    inc esi
    cmp al, byte [ebp + esi]
    jz .match
    
    ; top-top
    inc edi
    mov al, byte [ebp + edi]
    cmp al, byte [ebp + esi]
    jz .match
    
    ; no match
    dec edi
    dec edi
    ; Make sure Z flag is cleared (we know we are here because cmp failed)
    test esp, esp
.match:
    ret

; -----------------------------------------------------------------------------
; SlotMachine_CheckForMatch
; Compares the slot machine tiles at ESI, EDI, and ECX.
; Z flag is set if all three match.
; -----------------------------------------------------------------------------
SlotMachine_CheckForMatch:
    mov al, byte [ebp + edi]
    cmp al, byte [ebp + esi]
    jnz .no_match
    
    mov al, byte [ebp + ecx]
    cmp al, byte [ebp + esi]
.no_match:
    ret

; -----------------------------------------------------------------------------
; Slot machine text wrappers (pret engine/slots/slot_machine.asm)
; -----------------------------------------------------------------------------
PlaySlotMachineText:
    text_far _PlaySlotMachineText
    text_end

OutOfCoinsSlotMachineText:
    text_far _OutOfCoinsSlotMachineText
    text_end

BetHowManySlotMachineText:
    text_far _BetHowManySlotMachineText
    text_end

StartSlotMachineText:
    text_far _StartSlotMachineText
    text_end

NotEnoughCoinsSlotMachineText:
    text_far _NotEnoughCoinsSlotMachineText
    text_end

OneMoreGoSlotMachineText:
    text_far _OneMoreGoSlotMachineText
    text_end

LinedUpText:
    text_far _LinedUpText
    text_end

NotThisTimeText:
    text_far _NotThisTimeText
    text_end

YeahText:
    text_far _YeahText
    text_pause
    text_end

; -----------------------------------------------------------------------------
; GFX and Tilemap Data (INCBIN)
; -----------------------------------------------------------------------------
SlotMachineMap:
    incbin "../gfx/slots/slots.tilemap"
SlotMachineMapEnd:

SlotMachineTiles1:
    incbin "../gfx/slots/slots_1.2bpp"
SlotMachineTiles1End:

; -----------------------------------------------------------------------------
; SlotMachine_GetWheel3Tiles
; -----------------------------------------------------------------------------
SlotMachine_GetWheel3Tiles:
    mov edx, W_SLOT_MACHINE_WHEEL3_BOTTOM_TILE
    mov esi, SlotMachineWheel3
    mov al, [ebp + W_SLOT_MACHINE_WHEEL3_OFFSET]
    call SlotMachine_GetWheelTiles

; -----------------------------------------------------------------------------
; SlotMachine_GetWheel2Tiles
; -----------------------------------------------------------------------------
SlotMachine_GetWheel2Tiles:
    mov edx, W_SLOT_MACHINE_WHEEL2_BOTTOM_TILE
    mov esi, SlotMachineWheel2
    mov al, [ebp + W_SLOT_MACHINE_WHEEL2_OFFSET]
    call SlotMachine_GetWheelTiles

; -----------------------------------------------------------------------------
; SlotMachine_GetWheel1Tiles
; -----------------------------------------------------------------------------
SlotMachine_GetWheel1Tiles:
    mov edx, W_SLOT_MACHINE_WHEEL1_BOTTOM_TILE
    mov esi, SlotMachineWheel1
    mov al, [ebp + W_SLOT_MACHINE_WHEEL1_OFFSET]

; -----------------------------------------------------------------------------
; SlotMachine_GetWheelTiles
; -----------------------------------------------------------------------------
SlotMachine_GetWheelTiles:
    movzx ecx, al
    add esi, ecx
    mov cl, 3
.loop:
    mov al, [esi]
    inc esi
    mov [ebp + edx], al
    inc edx
    inc esi
    dec cl
    jnz .loop
    ret

; -----------------------------------------------------------------------------
; SlotMachine_AnimWheel1
; -----------------------------------------------------------------------------
SlotMachine_AnimWheel1:
    mov ebx, SlotMachineWheel1
    mov edx, W_SLOT_MACHINE_WHEEL1_OFFSET
    mov esi, W_SHADOW_OAM
    mov byte [ebp + wBaseCoordX], 0x30
    jmp SlotMachine_AnimWheel

; -----------------------------------------------------------------------------
; SlotMachine_AnimWheel2
; -----------------------------------------------------------------------------
SlotMachine_AnimWheel2:
    mov ebx, SlotMachineWheel2
    mov edx, W_SLOT_MACHINE_WHEEL2_OFFSET
    mov esi, W_SHADOW_OAM + 12 * 4
    mov byte [ebp + wBaseCoordX], 0x50
    jmp SlotMachine_AnimWheel

; -----------------------------------------------------------------------------
; SlotMachine_AnimWheel3
; -----------------------------------------------------------------------------
SlotMachine_AnimWheel3:
    mov ebx, SlotMachineWheel3
    mov edx, W_SLOT_MACHINE_WHEEL3_OFFSET
    mov esi, W_SHADOW_OAM + 24 * 4
    mov byte [ebp + wBaseCoordX], 0x70

; -----------------------------------------------------------------------------
; SlotMachine_AnimWheel
; -----------------------------------------------------------------------------
SlotMachine_AnimWheel:
    mov byte [ebp + wBaseCoordY], 0x58
    push edx
    movzx eax, byte [ebp + edx]
    lea edx, [ebx + eax]
.loop:
    mov al, byte [ebp + wBaseCoordY]
    mov byte [ebp + esi], al
    inc esi
    mov al, byte [ebp + wBaseCoordX]
    mov byte [ebp + esi], al
    inc esi
    mov al, byte [edx]
    mov byte [ebp + esi], al
    inc esi
    mov byte [ebp + esi], 0x80
    inc esi
    mov al, byte [ebp + wBaseCoordY]
    mov byte [ebp + esi], al
    inc esi
    mov al, byte [ebp + wBaseCoordX]
    add al, 8
    mov byte [ebp + esi], al
    inc esi
    mov al, byte [edx]
    inc al
    mov byte [ebp + esi], al
    inc esi
    mov byte [ebp + esi], 0x80
    inc esi
    inc edx
    mov al, byte [ebp + wBaseCoordY]
    sub al, 8
    mov byte [ebp + wBaseCoordY], al
    cmp al, 0x28
    jnz .loop
    pop edx
    mov al, byte [ebp + edx]
    inc al
    cmp al, 30
    jnz .skip
    xor al, al
.skip:
    mov byte [ebp + edx], al
    ret

; -----------------------------------------------------------------------------
; SlotMachine_PutOutLitBalls
; -----------------------------------------------------------------------------
SlotMachine_PutOutLitBalls:
    mov al, 0x23
    mov byte [ebp + wNewSlotMachineBallTile], al
    jmp SlotMachine_UpdateThreeCoinBallTiles

; -----------------------------------------------------------------------------
; SlotMachine_LightBalls
; -----------------------------------------------------------------------------
SlotMachine_LightBalls:
    mov al, 0x14
    mov byte [ebp + wNewSlotMachineBallTile], al
    mov al, byte [ebp + wSlotMachineBet]
    dec al
    jz SlotMachine_UpdateOneCoinBallTiles
    dec al
    jz SlotMachine_UpdateTwoCoinBallTiles

; -----------------------------------------------------------------------------
; SlotMachine_UpdateThreeCoinBallTiles
; -----------------------------------------------------------------------------
SlotMachine_UpdateThreeCoinBallTiles:
    hlcoord 3, 2
    call SlotMachine_UpdateBallTiles
    hlcoord 3, 10
    call SlotMachine_UpdateBallTiles

; -----------------------------------------------------------------------------
; SlotMachine_UpdateTwoCoinBallTiles
; -----------------------------------------------------------------------------
SlotMachine_UpdateTwoCoinBallTiles:
    hlcoord 3, 4
    call SlotMachine_UpdateBallTiles
    hlcoord 3, 8
    call SlotMachine_UpdateBallTiles

; -----------------------------------------------------------------------------
; SlotMachine_UpdateOneCoinBallTiles
; -----------------------------------------------------------------------------
SlotMachine_UpdateOneCoinBallTiles:
    hlcoord 3, 6

; -----------------------------------------------------------------------------
; SlotMachine_UpdateBallTiles
; -----------------------------------------------------------------------------
SlotMachine_UpdateBallTiles:
    mov al, byte [ebp + wNewSlotMachineBallTile]
    mov byte [ebp + esi], al
    add esi, 13
    mov byte [ebp + esi], al
    add esi, 7
    inc al
    mov byte [ebp + esi], al
    add esi, 13
    mov byte [ebp + esi], al
    ret

; -----------------------------------------------------------------------------
; SlotMachine_SubtractBetFromPlayerCoins
; -----------------------------------------------------------------------------
SlotMachine_SubtractBetFromPlayerCoins:
    mov esi, wTempCoins2 + 1
    mov al, byte [ebp + wSlotMachineBet]
    mov byte [ebp + esi], al
    dec esi
    xor al, al
    mov byte [ebp + esi], al
    inc esi
    mov edx, wPlayerCoins + 1
    mov cl, 2
    call SubBCDPredef
    ; NO ret — pret FALLS THROUGH into SlotMachine_PrintCreditCoins
    ; (engine/slots/slot_machine.asm:646-648: `predef SubBCDPredef` is the last
    ; instruction before the label). Subtracting the bet is what repaints the
    ; credit counter; with a ret here the on-screen total goes stale the moment
    ; you bet and only resyncs after a win, because PayCoinsToPlayer's loop calls
    ; PrintCreditCoins itself. faithdiff cannot see this: a fall-through is not a
    ; call, so all four faithdiffs returned 0 with the ret in place.

; -----------------------------------------------------------------------------
; SlotMachine_PrintCreditCoins
; -----------------------------------------------------------------------------
SlotMachine_PrintCreditCoins:
    hlcoord 5, 1
    mov edx, wPlayerCoins
    mov bl, 2
    jmp PrintBCDNumber

; -----------------------------------------------------------------------------
; SlotMachine_PrintPayoutCoins
; -----------------------------------------------------------------------------
SlotMachine_PrintPayoutCoins:
    hlcoord 11, 1
    mov edx, wPayoutCoins
    mov bx, ((LEADING_ZEROES | 2) << 8) | 4 ; 2 bytes, 4 digits
    jmp PrintNumber

; -----------------------------------------------------------------------------
; SlotMachine_PayCoinsToPlayer
; -----------------------------------------------------------------------------
SlotMachine_PayCoinsToPlayer:
    mov byte [ebp + wMuteAudioAndPauseMusic], 1
    call WaitForSoundToFinish

; Put 1 in the temp coins variable. This value is added to the player's coins
; repeatedly so the player can watch the value go up 1 coin at a time.
    mov esi, wTempCoins1
    xor al, al
    mov byte [ebp + esi], al
    inc esi
    inc al
    mov byte [ebp + esi], al

    mov al, 5
    mov byte [ebp + wAnimCounter], al

; Subtract 1 from the payout amount and add 1 to the player's coins each
; iteration until the payout amount reaches 0.
.loop:
    mov al, byte [ebp + wPayoutCoins + 1]
    mov dl, al
    mov al, byte [ebp + wPayoutCoins]
    mov dh, al
    or al, dl
    jz .exit
    dec dx
    mov al, dl
    mov byte [ebp + wPayoutCoins + 1], al
    mov al, dh
    mov byte [ebp + wPayoutCoins], al
    mov esi, wTempCoins1 + 1
    mov edx, wPlayerCoins + 1
    mov cl, 2
    call AddBCDPredef
    call SlotMachine_PrintCreditCoins
    call SlotMachine_PrintPayoutCoins
    mov al, SFX_SLOTS_REWARD
    call PlaySound
    mov al, byte [ebp + wAnimCounter]
    dec al
    jnz .skip1
    mov al, byte [ebp + 0xFF48]              ; ldh a, [rOBP0]
    xor al, 0x40 ; make the slot wheel symbols flash
    mov byte [ebp + 0xFF48], al              ; ldh [rOBP0], a
    call UpdateCGBPal_OBP0
    mov al, 5
.skip1:
    mov byte [ebp + wAnimCounter], al
    mov al, byte [ebp + wSlotMachineWinningSymbol]
    cmp al, (SLOTSBAR >> 8) + 1
    mov bl, 8
    jnc .skip2
    shr bl, 1 ; bl = 4 (make the the coins transfer faster if the symbol was 7 or bar)
.skip2:
    call DelayFrames
    jmp .loop
.exit:
    ret

; -----------------------------------------------------------------------------
; SlotMachine_PrintWinningSymbol
; prints winning symbol and down arrow in text box
; -----------------------------------------------------------------------------
SlotMachine_PrintWinningSymbol:
    hlcoord 2, 14
    mov al, byte [ebp + wSlotMachineWinningSymbol]
    add al, 0x25
    mov byte [ebp + esi], al
    inc esi
    inc al
    mov byte [ebp + esi], al
    dec esi
    inc al
    mov edx, -SCREEN_WIDTH
    add esi, edx
    mov byte [ebp + esi], al
    inc esi
    inc al
    mov byte [ebp + esi], al
    hlcoord 18, 16
    mov byte [ebp + esi], CHAR_DOWN_ARROW
    ret

; -----------------------------------------------------------------------------
; SymbolLinedUpSlotMachineText
; -----------------------------------------------------------------------------
SymbolLinedUpSlotMachineText:
    text_asm
    push ebx
    call SlotMachine_PrintWinningSymbol
    mov esi, LinedUpText
    pop ebx
    inc ebx
    inc ebx
    inc ebx
    inc ebx
    ret

; -----------------------------------------------------------------------------
; SlotReward8Func
; -----------------------------------------------------------------------------
SlotReward8Func:
    mov esi, W_SLOT_MACHINE_ALLOW_MATCHES_COUNTER
    mov al, byte [ebp + esi]
    test al, al
    jz .skip
    dec byte [ebp + esi]
.skip:
    mov bh, 0x02
    mov dx, 8
    ret

; -----------------------------------------------------------------------------
; SlotReward15Func
; -----------------------------------------------------------------------------
SlotReward15Func:
    mov esi, W_SLOT_MACHINE_ALLOW_MATCHES_COUNTER
    mov al, byte [ebp + esi]
    test al, al
    jz .skip
    dec byte [ebp + esi]
.skip:
    mov bh, 0x04
    mov dx, 15
    ret

; -----------------------------------------------------------------------------
; SlotReward100Func
; -----------------------------------------------------------------------------
SlotReward100Func:
    mov al, SFX_GET_KEY_ITEM
    call PlaySound
    xor al, al
    mov byte [ebp + W_SLOT_MACHINE_FLAGS], al
    mov bh, 0x08
    mov dx, 100
    ret

; -----------------------------------------------------------------------------
; SlotReward300Func
; -----------------------------------------------------------------------------
SlotReward300Func:
    mov esi, YeahText
    call PrintText
    mov al, SFX_GET_ITEM_2
    call PlaySound
    call Random
    cmp al, 0x80
    mov al, 0
    jc .skip
    mov byte [ebp + W_SLOT_MACHINE_FLAGS], al
.skip:
    mov byte [ebp + W_SLOT_MACHINE_ALLOW_MATCHES_COUNTER], al
    mov bh, 0x14
    mov dx, 300
    ret

; -----------------------------------------------------------------------------
; SlotRewardPointers
; -----------------------------------------------------------------------------
SlotRewardPointers:
    dd SlotReward300Func
    dd SlotReward300Text
    dd SlotReward100Func
    dd SlotReward100Text
    dd SlotReward8Func
    dd SlotReward8Text
    dd SlotReward15Func
    dd SlotReward15Text
    dd SlotReward15Func
    dd SlotReward15Text
    dd SlotReward15Func
    dd SlotReward15Text

