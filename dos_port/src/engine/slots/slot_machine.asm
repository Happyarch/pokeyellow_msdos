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
global SlotMachine_StopOrAnimWheel1
global SlotMachine_StopOrAnimWheel2
global SlotMachine_StopOrAnimWheel3
global SlotMachine_StopWheel1Early
global SlotMachine_StopWheel2Early
global SlotMachine_HandleInputWhileWheelsSpin
global SlotMachine_CheckForMatches
global SlotMachine_SpinWheels
global LoadSlotMachineTiles
global MainSlotMachineLoop
global PromptUserToPlaySlots

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
extern SlotMachineWheel1        ; src/data/events/slot_machine_wheels.asm
extern SlotMachineWheel2        ; src/data/events/slot_machine_wheels.asm
extern SlotMachineWheel3        ; src/data/events/slot_machine_wheels.asm
extern PrintBCDNumber           ; src/home/print_bcd.asm
extern PrintNumber              ; src/home/print_num.asm
extern SubBCDPredef             ; src/engine/math/bcd.asm
extern AddBCDPredef             ; src/engine/math/bcd.asm
extern WaitForSoundToFinish     ; src/home/delay.asm
extern PlaySound                ; src/home/audio.asm
extern UpdateCGBPal_BGP         ; src/home/cgb_palettes.asm
extern UpdateCGBPal_OBP0        ; src/home/cgb_palettes.asm
extern DelayFrames              ; src/home/delay.asm
extern DelayFrame               ; src/home/vblank.asm
extern JoypadLowSensitivity     ; src/home/joypad2.asm
extern PrintText                ; src/home/window.asm
extern WaitForTextScrollButtonPress ; src/home/joypad2.asm
extern CopyData                 ; src/home/copy.asm
extern FarCopyData              ; src/home/copy.asm
extern DisableLCD               ; src/home/lcd.asm
extern EnableLCD                ; src/home/lcd.asm
extern SlotMachineTiles2            ; pret engine/battle/animations.asm
extern g_tilecache_dirty            ; src/ppu/ppu.asm
extern SaveScreenTilesToBuffer1     ; src/home/tilemap.asm
extern LoadScreenTilesFromBuffer1   ; src/home/tilemap.asm
extern TextBoxBorder                ; src/home/text.asm
extern PlaceString                  ; src/home/text.asm
extern HandleMenuInput              ; src/home/window.asm
extern DisplayTextBoxID             ; src/home/textbox.asm
extern yn_box_col                   ; home/yes_no.asm — two-option box top-left, GB X
extern yn_box_row                   ; home/yes_no.asm — two-option box top-left, GB Y
extern yn_proj_mode                 ; home/yes_no.asm — 0 = overworld anchor, 1 = battle
extern SaveScreenTilesToBuffer2     ; src/home/tilemap.asm
extern LoadScreenTilesFromBuffer2   ; src/home/tilemap.asm
extern DisplayTextIDInit            ; src/engine/menus/display_text_id_init.asm
extern Bankswitch                   ; src/home/bankswitch2.asm
extern YesNoChoice                  ; src/home/yes_no.asm
extern EmotionBubble                ; src/engine/overworld/emotion_bubbles.asm
extern GBPalWhiteOutWithDelay3      ; src/home/palettes.asm
extern LoadFontTilePatterns         ; src/home/load_font.asm
extern RunPaletteCommand            ; src/home/palettes.asm
extern Delay3                       ; src/home/palettes.asm
extern GBPalNormal                  ; src/home/palettes.asm
extern FillMemory                   ; src/home/copy2.asm
extern RunDefaultPaletteCommand     ; src/home/palettes.asm
extern ReloadMapSpriteTilePatterns  ; src/home/reload_sprites.asm
extern ReloadTilesetTilePatterns    ; src/home/reload_tiles.asm
extern CloseTextDisplay             ; src/home/text_script.asm

%define BIT_SLOTS_CAN_WIN 6
%define BIT_SLOTS_CAN_WIN_WITH_7_OR_BAR 7

SET_PAL_SLOTS                   equ 5
SMILE_BUBBLE                    equ 2

wPayoutCoins                    equ 0xCD4A
wTempCoins1                     equ 0xCD46
wTempCoins2                     equ 0xCD4A
wSlotMachineWinningSymbol       equ 0xCD41
SLOTS7                          equ 0x0200
SLOTSBAR                        equ 0x0604
SLOTSCHERRY                     equ 0x0A08
wStoppingWhichSlotMachineWheel  equ 0xCD3D
wSlotMachineWheel1Offset        equ 0xCD3E
wSlotMachineWheel2Offset        equ 0xCD3F
wSlotMachineWheel3Offset        equ 0xCD40
wSlotMachineWheel1BottomTile    equ 0xCD41
wSlotMachineWheel1MiddleTile    equ 0xCD42
wSlotMachineWheel1TopTile       equ 0xCD43
wSlotMachineWheel2BottomTile    equ 0xCD44
wSlotMachineWheel2MiddleTile    equ 0xCD45
wSlotMachineWheel2TopTile       equ 0xCD46
wSlotMachineWheel3BottomTile    equ 0xCD47
wSlotMachineWheel3MiddleTile    equ 0xCD48
wSlotMachineWheel3TopTile       equ 0xCD49
wSlotMachineFlags               equ 0xCD4C
wSlotMachineWheel1SlipCounter   equ 0xCD4D
wSlotMachineWheel2SlipCounter   equ 0xCD4E
wSlotMachineRerollCounter       equ 0xCD4F


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
    ; pret: `hlcoord 3, 6`, expanded inline. This label's ONLY instruction is the
    ; coord load and it then FALLS THROUGH into SlotMachine_UpdateBallTiles, which
    ; is pret's own structure. update_label_db refuses to classify a boundary whose
    ; last token is a macro it cannot prove returns control (hlcoord's body has a
    ; %if, and a conditional arm could hold a jmp/ret), so it errors out rather
    ; than manufacture a fall-through edge. Expanding the one instruction here
    ; keeps the fall-through and lets the scanner see it; every other hlcoord in
    ; this file is mid-routine and unaffected.
    mov esi, (6) * SCREEN_WIDTH + (3) + W_TILEMAP

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

; -----------------------------------------------------------------------------
; SlotMachine_StopOrAnimWheel1
; -----------------------------------------------------------------------------
SlotMachine_StopOrAnimWheel1:
    mov al, byte [ebp + wStoppingWhichSlotMachineWheel]
    cmp al, 1
    jc .animWheel
    mov al, byte [ebp + wSlotMachineWheel1Offset]
    shr al, 1
    jnc .animWheel ; check that a symbol is centred in the wheel
    mov esi, wSlotMachineWheel1SlipCounter
    mov al, byte [ebp + esi]
    test al, al
    jz .exit
    dec byte [ebp + esi]
    call SlotMachine_StopWheel1Early
    jnz .exit
.animWheel:
    jmp SlotMachine_AnimWheel1
.exit:
    ret

; -----------------------------------------------------------------------------
; SlotMachine_StopOrAnimWheel2
; -----------------------------------------------------------------------------
SlotMachine_StopOrAnimWheel2:
    mov al, byte [ebp + wStoppingWhichSlotMachineWheel]
    cmp al, 2
    jc .animWheel
    mov al, byte [ebp + wSlotMachineWheel2Offset]
    shr al, 1
    jnc .animWheel ; check that a symbol is centred in the wheel
    mov esi, wSlotMachineWheel2SlipCounter
    mov al, byte [ebp + esi]
    test al, al
    jz .exit
    dec byte [ebp + esi]
    call SlotMachine_StopWheel2Early
    jz .exit
.animWheel:
    jmp SlotMachine_AnimWheel2
.exit:
    ret

; -----------------------------------------------------------------------------
; SlotMachine_StopOrAnimWheel3
; -----------------------------------------------------------------------------
SlotMachine_StopOrAnimWheel3:
    mov al, byte [ebp + wStoppingWhichSlotMachineWheel]
    cmp al, 3
    jc .animWheel
    mov al, byte [ebp + wSlotMachineWheel3Offset]
    shr al, 1
    jnc .animWheel ; check that a symbol is centred in the wheel
; wheel 3 stops as soon as possible
    stc
    ret
.animWheel:
    call SlotMachine_AnimWheel3
    and al, al
    ret

; -----------------------------------------------------------------------------
; SlotMachine_StopWheel1Early
; -----------------------------------------------------------------------------
SlotMachine_StopWheel1Early:
    call SlotMachine_GetWheel1Tiles
    mov esi, wSlotMachineWheel1BottomTile
    mov al, byte [ebp + wSlotMachineFlags]
    and al, (1 << BIT_SLOTS_CAN_WIN_WITH_7_OR_BAR)
    jnz .sevenAndBarMode
; Stop early if the middle symbol is not a cherry.
    inc esi
    mov al, byte [ebp + esi]
    cmp al, (SLOTSCHERRY >> 8)
    jnz .stopWheel
    ret
; BUG{class=data-model; pret=engine/slots/slot_machine.asm:SlotMachine_StopWheel1Early; behavior=in seven-and-bar mode the wheel was likely intended to stop when a 7 symbol is visible but cp HIGH(SLOTS7) followed by jr c never branches because all symbol tile IDs are at least HIGH(SLOTS7); evidence=pret comment and cp HIGH(SLOTS7) comparison where SLOTS7 high byte is 0x02 and no symbol high byte is smaller; lifetime=permanent Gen-1 behavior unless BUG_FIX_LEVEL >= 2}
.sevenAndBarMode:
    mov cl, 3
.loop:
    mov al, byte [ebp + esi]
    inc esi
%if BUG_FIX_LEVEL >= 2
    cmp al, (SLOTS7 >> 8)
    jz .stopWheel
%else
    cmp al, (SLOTS7 >> 8)
    jc .stopWheel ; condition never true
%endif
    dec cl
    jnz .loop
    ret
.stopWheel:
    inc al
    mov esi, wSlotMachineWheel1SlipCounter
    mov byte [ebp + esi], 0
    ret

; -----------------------------------------------------------------------------
; SlotMachine_StopWheel2Early
; -----------------------------------------------------------------------------
SlotMachine_StopWheel2Early:
    call SlotMachine_GetWheel2Tiles
    mov al, byte [ebp + wSlotMachineFlags]
    and al, (1 << BIT_SLOTS_CAN_WIN_WITH_7_OR_BAR)
    jnz .sevenAndBarMode
; Stop early if any symbols are lined up in the first two wheels.
    call SlotMachine_FindWheel1Wheel2Matches
    jnz .exit
    jmp .stopWheel
; Stop early if two 7 symbols or two bar symbols are lined up in the first two
; wheels OR if no symbols are lined up and the bottom symbol in wheel 2 is a
; 7 symbol or bar symbol.
.sevenAndBarMode:
    call SlotMachine_FindWheel1Wheel2Matches
    mov al, byte [ebp + edi]
    cmp al, (SLOTSBAR >> 8) + 1
    jnc .exit
.stopWheel:
    xor al, al
    mov byte [ebp + wSlotMachineWheel2SlipCounter], al
    ret
.exit:
    ret

; -----------------------------------------------------------------------------
; SlotMachine_HandleInputWhileWheelsSpin
; -----------------------------------------------------------------------------
SlotMachine_HandleInputWhileWheelsSpin:
    call DelayFrame
    call JoypadLowSensitivity
    mov al, byte [ebp + H_JOY5]
    and al, PAD_A
    jz .exit
    mov esi, wStoppingWhichSlotMachineWheel
    mov al, byte [ebp + esi]
    dec al
    mov edx, wSlotMachineWheel1SlipCounter
    jz .skip
    dec al
    mov edx, wSlotMachineWheel2SlipCounter
    jz .skip
.loop:
    inc byte [ebp + esi]
    mov al, SFX_SLOTS_STOP_WHEEL
    jmp PlaySound
.skip:
    mov al, byte [ebp + edx]
    test al, al
    jnz .exit
    jmp .loop
.exit:
    ret

; -----------------------------------------------------------------------------
; SlotMachine_CheckForMatches
; -----------------------------------------------------------------------------
SlotMachine_CheckForMatches:
    call SlotMachine_GetWheel3Tiles
    mov al, byte [ebp + wSlotMachineBet]
    cmp al, 2
    jz .checkMatchesFor2CoinBet
    cmp al, 1
    jz .checkMatchFor1CoinBet
; 3 coin bet allows diagonal matches (plus the matches for 1/2 coin bets)
    mov esi, wSlotMachineWheel1BottomTile
    mov edi, wSlotMachineWheel2MiddleTile
    mov ecx, wSlotMachineWheel3TopTile
    call SlotMachine_CheckForMatch
    jz .foundMatch
    mov esi, wSlotMachineWheel1TopTile
    mov edi, wSlotMachineWheel2MiddleTile
    mov ecx, wSlotMachineWheel3BottomTile
    call SlotMachine_CheckForMatch
    jz .foundMatch
; 2 coin bet allows top/bottom horizontal matches (plus the match for a 1 coin bet)
.checkMatchesFor2CoinBet:
    mov esi, wSlotMachineWheel1TopTile
    mov edi, wSlotMachineWheel2TopTile
    mov ecx, wSlotMachineWheel3TopTile
    call SlotMachine_CheckForMatch
    jz .foundMatch
    mov esi, wSlotMachineWheel1BottomTile
    mov edi, wSlotMachineWheel2BottomTile
    mov ecx, wSlotMachineWheel3BottomTile
    call SlotMachine_CheckForMatch
    jz .foundMatch
; 1 coin bet only allows a middle horizontal match
.checkMatchFor1CoinBet:
    mov esi, wSlotMachineWheel1MiddleTile
    mov edi, wSlotMachineWheel2MiddleTile
    mov ecx, wSlotMachineWheel3MiddleTile
    call SlotMachine_CheckForMatch
    jz .foundMatch
    mov al, byte [ebp + wSlotMachineFlags]
    and al, (1 << BIT_SLOTS_CAN_WIN) | (1 << BIT_SLOTS_CAN_WIN_WITH_7_OR_BAR)
    jz .noMatch
    mov esi, wSlotMachineRerollCounter
    dec byte [ebp + esi]
    jnz .rollWheel3DownByOneSymbol
.noMatch:
    mov esi, NotThisTimeText
    call PrintText
.done:
    xor al, al
    mov byte [ebp + wMuteAudioAndPauseMusic], al
    ret
.rollWheel3DownByOneSymbol:
    call SlotMachine_AnimWheel3
    call DelayFrame
    call SlotMachine_AnimWheel3
    call DelayFrame
    jmp SlotMachine_CheckForMatches
.foundMatch:
    mov al, byte [ebp + wSlotMachineFlags]
    and al, (1 << BIT_SLOTS_CAN_WIN) | (1 << BIT_SLOTS_CAN_WIN_WITH_7_OR_BAR)
    jz .rollWheel3DownByOneSymbol ; roll wheel if player isn't allowed to win
    and al, (1 << BIT_SLOTS_CAN_WIN_WITH_7_OR_BAR)
    jnz .acceptMatch
; if 7/bar matches aren't enabled and the match was a 7/bar symbol, roll wheel
    mov al, byte [ebp + esi]
    cmp al, (SLOTSBAR >> 8) + 1
    jc .rollWheel3DownByOneSymbol
.acceptMatch:
    mov al, byte [ebp + esi]
    sub al, 2
    mov byte [ebp + wSlotMachineWinningSymbol], al
    movzx eax, al
    mov edx, [SlotRewardPointers + eax * 2]
    mov esi, [SlotRewardPointers + eax * 2 + 4]
    push edx
    sub esi, ebp
    mov dx, wStringBuffer
    mov bx, 4 ; every SlotReward*Text is at most 4 bytes
    call CopyData
    pop esi
    push .flashScreenLoop
    push esi
    ret

.flashScreenLoop:
    mov al, byte [ebp + 0xFF47]              ; ldh a, [rBGP]
    xor al, 0x40
    mov byte [ebp + 0xFF47], al              ; ldh [rBGP], a
    call UpdateCGBPal_BGP
    mov bl, 5
    call DelayFrames
    dec bh
    jnz .flashScreenLoop
    mov esi, wPayoutCoins
    mov byte [ebp + esi], dh
    inc esi
    mov byte [ebp + esi], dl
    call SlotMachine_PrintPayoutCoins
    mov esi, SymbolLinedUpSlotMachineText
    call PrintText
    call WaitForTextScrollButtonPress
    call SlotMachine_PayCoinsToPlayer
    call SlotMachine_PrintPayoutCoins
    mov al, 0xE4
    mov byte [ebp + 0xFF48], al              ; ldh [rOBP0], a
    call UpdateCGBPal_OBP0
    jmp .done

; -----------------------------------------------------------------------------
; SlotMachine_SpinWheels
; -----------------------------------------------------------------------------
SlotMachine_SpinWheels:
    mov bl, 20
.loop1:
    push ebx
    call SlotMachine_AnimWheel1
    call SlotMachine_AnimWheel2
    call SlotMachine_AnimWheel3
    mov bl, 2
    call DelayFrames
    pop ebx
    dec bl
    jnz .loop1
    xor al, al
    mov byte [ebp + wStoppingWhichSlotMachineWheel], al
.loop2:
    call SlotMachine_HandleInputWhileWheelsSpin
    call SlotMachine_StopOrAnimWheel1
    call SlotMachine_StopOrAnimWheel2
    call SlotMachine_StopOrAnimWheel3
    jc .exit
    mov al, byte [ebp + wOnSGB]
    xor al, 1
    inc al
    mov bl, al
    call DelayFrames
    jmp .loop2
.exit:
    ret

; -----------------------------------------------------------------------------
; LoadSlotMachineTiles
; -----------------------------------------------------------------------------
LoadSlotMachineTiles:
    call DisableLCD
    mov esi, SlotMachineTiles2
    sub esi, ebp
    mov edx, GB_VCHARS0
; BUG{class=data-model; pret=engine/slots/slot_machine.asm:LoadSlotMachineTiles; behavior=copies $1c tiles of SlotMachineTiles2 where the blob is $18 tiles, over-reading 4 tiles past its end on both copies; evidence=gfx/slots/slots_2.2bpp is 384 bytes = 24 tiles = $18, and pret's own comment names the intended bound; lifetime=permanent, the faithful branch reproduces the over-read}
%if BUG_FIX_LEVEL >= 2
    mov bx, 0x18 * 16
%else
    mov bx, 0x1c * 16
%endif
    ; ld a, BANK(SlotMachineTiles2) — no-op under flat model
    call FarCopyData
    mov esi, SlotMachineTiles1
    sub esi, ebp
    mov edx, GB_VCHARS2
    mov bx, SlotMachineTiles1End - SlotMachineTiles1
    ; ld a, BANK(SlotMachineTiles1) — no-op under flat model
    call FarCopyData
    mov esi, SlotMachineTiles2
    sub esi, ebp
    mov edx, GB_VCHARS2 + 0x25 * 16
%if BUG_FIX_LEVEL >= 2
    mov bx, 0x18 * 16
%else
    mov bx, 0x1c * 16
%endif
    ; ld a, BANK(SlotMachineTiles2) — no-op under flat model
    call FarCopyData
    mov esi, SlotMachineMap
    sub esi, ebp
    decoord 0, 0
    mov edx, edi
    mov bx, SlotMachineMapEnd - SlotMachineMap
    call CopyData
    mov byte [g_tilecache_dirty], 1
    call EnableLCD
    mov esi, wSlotMachineWheel1Offset
    mov al, 0x1c
    mov byte [ebp + esi], al
    inc esi
    mov byte [ebp + esi], al
    inc esi
    mov byte [ebp + esi], al
    call SlotMachine_AnimWheel1
    call SlotMachine_AnimWheel2
    jmp SlotMachine_AnimWheel3

; -----------------------------------------------------------------------------
; MainSlotMachineLoop
; -----------------------------------------------------------------------------
MainSlotMachineLoop:
    call SlotMachine_PrintCreditCoins
    xor al, al
    mov esi, wPayoutCoins
    mov byte [ebp + esi], al
    inc esi
    mov byte [ebp + esi], al
    call SlotMachine_PrintPayoutCoins
    mov esi, BetHowManySlotMachineText
    call PrintText
    call SaveScreenTilesToBuffer1
.loop:
    mov al, PAD_A | PAD_B
    mov byte [ebp + wMenuWatchedKeys], al
    mov byte [ebp + wMaxMenuItem], 2
    mov byte [ebp + wTopMenuItemY], 12
    mov byte [ebp + wTopMenuItemX], 15
    xor al, al
    mov byte [ebp + wCurrentMenuItem], al
    mov byte [ebp + wLastMenuItem], al
    mov byte [ebp + wMenuWatchMovingOutOfBounds], al
    hlcoord 14, 11
    mov bh, 5
    mov bl, 4
    call TextBoxBorder
    hlcoord 16, 12
    mov eax, CoinMultiplierSlotMachineText
    call PlaceString
    call HandleMenuInput
    and al, PAD_B
    jnz LoadScreenTilesFromBuffer1
    mov al, byte [ebp + wCurrentMenuItem]
    mov bh, al
    mov al, 3
    sub al, bh
    mov byte [ebp + wSlotMachineBet], al
    mov esi, wPlayerCoins
    mov bl, al
    mov al, byte [ebp + esi]
    inc esi
    and al, al
    jnz .skip1
    mov al, byte [ebp + esi]
    cmp al, bl
    jnc .skip1
    mov esi, NotEnoughCoinsSlotMachineText
    call PrintText
    jmp .loop
.skip1:
    call LoadScreenTilesFromBuffer1
    call SlotMachine_SubtractBetFromPlayerCoins
    call SlotMachine_LightBalls
    call SlotMachine_SetFlags
    mov al, 4
    mov esi, wSlotMachineWheel1SlipCounter
    mov byte [ebp + esi], al
    inc esi
    mov byte [ebp + esi], al
    inc esi
    mov byte [ebp + esi], al
    call WaitForSoundToFinish
    mov al, SFX_SLOTS_NEW_SPIN
    call PlaySound
    mov esi, StartSlotMachineText
    call PrintText
    call SlotMachine_SpinWheels
    call SlotMachine_CheckForMatches
    mov esi, wPlayerCoins
    mov al, byte [ebp + esi]
    inc esi
    or al, byte [ebp + esi]
    jnz .skip2
    mov esi, OutOfCoinsSlotMachineText
    call PrintText
    mov bl, 60
    jmp DelayFrames
.skip2:
    mov esi, OneMoreGoSlotMachineText
    call PrintText
    hlcoord 14, 12
    mov bh, 13
    mov bl, 15
    xor al, al
    mov byte [ebp + wTwoOptionMenuID], al
    ; The port places this box from yn_box_col/row/proj_mode (the window
    ; compositor), not from esi/bh/bl above — those stay for pret cross-
    ; reference only. Overworld/menu anchor.
    mov dword [yn_box_col], 14
    mov dword [yn_box_row], 12
    mov dword [yn_proj_mode], 0          ; overworld/menu anchor
    mov byte [ebp + wTextBoxID], TWO_OPTION_MENU
    call DisplayTextBoxID
    mov al, byte [ebp + wCurrentMenuItem]
    and al, al
    jnz .ret
    call SlotMachine_PutOutLitBalls
    jmp MainSlotMachineLoop
.ret:
    ret

; -----------------------------------------------------------------------------
; PromptUserToPlaySlots
; -----------------------------------------------------------------------------
PromptUserToPlaySlots:
    call SaveScreenTilesToBuffer2
    mov al, (1 << BIT_NO_AUTO_TEXT_BOX)
    mov byte [ebp + wAutoTextBoxDrawingControl], al
    mov bh, al
    mov esi, DisplayTextIDInit
    call Bankswitch
    mov esi, PlaySlotMachineText
    call PrintText
    call YesNoChoice
    mov al, byte [ebp + wCurrentMenuItem]
    and al, al
    jnz .done
    dec al
    mov byte [ebp + wUpdateSpritesEnabled], al
    mov esi, wSlotMachineRerollCounter
    xor al, al
    mov byte [ebp + esi], al
    inc esi
    mov byte [ebp + esi], SMILE_BUBBLE
    call EmotionBubble
    call GBPalWhiteOutWithDelay3
    call LoadSlotMachineTiles
    call LoadFontTilePatterns
    mov bh, SET_PAL_SLOTS
    call RunPaletteCommand
    call Delay3
    call GBPalNormal
    mov al, 0xE4
    mov byte [ebp + 0xFF48], al              ; ldh [rOBP0], a
    call UpdateCGBPal_OBP0
    mov esi, wStatusFlags5
    or byte [ebp + esi], (1 << BIT_NO_TEXT_DELAY)
    xor al, al
    mov byte [ebp + W_SLOT_MACHINE_ALLOW_MATCHES_COUNTER], al
    mov esi, wStoppingWhichSlotMachineWheel
    mov bx, 0x14
    call FillMemory
    call MainSlotMachineLoop
    mov esi, wStatusFlags5
    and byte [ebp + esi], ~(1 << BIT_NO_TEXT_DELAY) & 0xFF
    xor al, al
    mov byte [ebp + W_SLOT_MACHINE_ALLOW_MATCHES_COUNTER], al
    call GBPalWhiteOutWithDelay3
    mov byte [ebp + wUpdateSpritesEnabled], 1
    call RunDefaultPaletteCommand
    call ReloadMapSpriteTilePatterns
    call ReloadTilesetTilePatterns
.done:
    call LoadScreenTilesFromBuffer2
    call Delay3
    call GBPalNormal
    movzx eax, byte [ebp + wSlotMachineSavedROMBank]
    push eax
    jmp CloseTextDisplay


