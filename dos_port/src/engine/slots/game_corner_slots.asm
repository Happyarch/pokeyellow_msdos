; engine/slots/game_corner_slots.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_macros.inc"
%include "gb_text.inc"

section .text

global StartSlotMachine
extern AbleToPlaySlotsCheck
extern PromptUserToPlaySlots
extern EnableAutoTextBoxDrawing
extern PrintPredefTextID

; ---------------------------------------------------------------------------
; StartSlotMachine
; ---------------------------------------------------------------------------
StartSlotMachine:
    ; ld a, [wHiddenEventFunctionArgument]
    mov al, [ebp + wHiddenEventFunctionArgument]
    
    ; cp SLOTS_OUTOFORDER
    cmp al, 0xFD ; SLOTS_OUTOFORDER
    ; jr z, .printOutOfOrder
    jz .printOutOfOrder
    
    ; cp SLOTS_OUTTOLUNCH
    cmp al, 0xFE ; SLOTS_OUTTOLUNCH
    ; jr z, .printOutToLunch
    jz .printOutToLunch
    
    ; cp SLOTS_SOMEONESKEYS
    cmp al, 0xFF ; SLOTS_SOMEONESKEYS
    ; jr z, .printSomeonesKeys
    jz .printSomeonesKeys
    
    ; farcall AbleToPlaySlotsCheck
    call AbleToPlaySlotsCheck
    
    ; ld a, [wCanPlaySlots]
    mov al, [ebp + wCanPlaySlots]
    ; and a
    test al, al
    ; ret z
    jz .ret_z
    
    ; ld a, [wLuckySlotHiddenEventIndex]
    mov al, [ebp + wLuckySlotHiddenEventIndex]
    ; ld b, a
    mov bh, al
    
    ; ld a, [wHiddenEventIndex]
    mov al, [ebp + wHiddenEventIndex]
    ; inc a
    inc al
    ; cp b
    cmp al, bh
    ; jr z, .match
    jz .match
    
    ; ld a, 253
    mov al, 253
    ; jr .next
    jmp .next
    
.match:
    ; ld a, 250
    mov al, 250
    
.next:
    ; ld [wSlotMachineSevenAndBarModeChance], a
    mov [ebp + wSlotMachineSevenAndBarModeChance], al
    
    ; ldh a, [hLoadedROMBank]
    GB_LDH_A hLoadedROMBank
    ; ld [wSlotMachineSavedROMBank], a
    mov [ebp + wSlotMachineSavedROMBank], al
    
    ; call PromptUserToPlaySlots
    call PromptUserToPlaySlots
    ; ret
    ret

.ret_z:
    ret

.printOutOfOrder:
    ; tx_pre_id GameCornerOutOfOrderText
    mov al, 0x2A
    ; jr .printText
    jmp .printText

.printOutToLunch:
    ; tx_pre_id GameCornerOutToLunchText
    mov al, 0x2B
    ; jr .printText
    jmp .printText

.printSomeonesKeys:
    ; tx_pre_id GameCornerSomeonesKeysText
    mov al, 0x2C

.printText:
    ; push af
    push eax
    ; call EnableAutoTextBoxDrawing
    call EnableAutoTextBoxDrawing
    ; pop af
    pop eax
    ; call PrintPredefTextID
    call PrintPredefTextID
    ; ret
    ret


section .data

global GameCornerOutOfOrderText
extern _GameCornerOutOfOrderText
GameCornerOutOfOrderText:
    text_far _GameCornerOutOfOrderText
    text_end

global GameCornerOutToLunchText
extern _GameCornerOutToLunchText
GameCornerOutToLunchText:
    text_far _GameCornerOutToLunchText
    text_end

global GameCornerSomeonesKeysText
extern _GameCornerSomeonesKeysText
GameCornerSomeonesKeysText:
    text_far _GameCornerSomeonesKeysText
    text_end
