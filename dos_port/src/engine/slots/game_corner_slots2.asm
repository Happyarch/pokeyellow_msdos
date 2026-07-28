; engine/slots/game_corner_slots2.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_macros.inc"
%include "gb_text.inc"

section .text

global AbleToPlaySlotsCheck
extern GetQuantityOfItemInBag
extern EnableAutoTextBoxDrawing
extern PrintPredefTextID

; ---------------------------------------------------------------------------
; AbleToPlaySlotsCheck
; ---------------------------------------------------------------------------
AbleToPlaySlotsCheck:
    ; ld a, [wSpritePlayerStateData1ImageIndex]
    mov al, [ebp + wSpritePlayerStateData1ImageIndex]
    ; and $8
    and al, 0x08
    ; jr z, .done ; not able
    jz .done
    
    ; ld b, COIN_CASE
    mov bh, COIN_CASE
    
    ; predef GetQuantityOfItemInBag
    call GetQuantityOfItemInBag
    
    ; ld a, b
    mov al, bh
    ; and a
    test al, al
    
    ; ld b, (GameCornerCoinCaseText_id - TextPredefs) / 2 + 1
    mov bh, 0x35
    
    ; jr z, .printCoinCaseRequired
    jz .printCoinCaseRequired
    
    ; ld hl, wPlayerCoins
    mov esi, wPlayerCoins
    
    ; ld a, [hli]
    GB_LD_A_HLI
    
    ; or [hl]
    or al, [ebp + esi]
    
    ; jr nz, .done ; able to play
    jnz .done
    
    ; ld b, (GameCornerNoCoinsText_id - TextPredefs) / 2 + 1
    mov bh, 0x34
    
.printCoinCaseRequired:
    ; call EnableAutoTextBoxDrawing
    call EnableAutoTextBoxDrawing
    
    ; ld a, b
    mov al, bh
    
    ; call PrintPredefTextID
    call PrintPredefTextID
    
    ; xor a
    xor al, al
    
.done:
    ; ld [wCanPlaySlots], a
    mov [ebp + wCanPlaySlots], al
    ; ret
    ret


section .data

; Both message streams here are Tier-1 data, now GENERATED into
; assets/predef_text.inc (tools/generators/gen_predef_text.py) as the single
; definition. The hand-written wrappers they replace pointed at `_GameCorner*Text`
; far labels no file defined, so they could never have linked.
extern GameCornerCoinCaseText            ; assets/predef_text.inc (generated)
extern GameCornerNoCoinsText             ; assets/predef_text.inc (generated)
