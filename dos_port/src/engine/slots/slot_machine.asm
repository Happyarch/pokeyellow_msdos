; dos_port/src/slots/slot_machine.asm

%include "gb_macros.inc"
%include "gb_memmap.inc"
%include "gb_text.inc"
%include "coords.inc"

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

extern Random
extern SlotMachineWheel1
extern SlotMachineWheel2
extern SlotMachineWheel3

%define BIT_SLOTS_CAN_WIN 6
%define BIT_SLOTS_CAN_WIN_WITH_7_OR_BAR 7


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
