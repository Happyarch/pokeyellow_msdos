; TradeCenter.asm — translated from pret scripts/TradeCenter.asm by dos_port/tools/sm83xlat.
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


global TradeCenterOpponentText
global TradeCenter_Script
global TradeCenter_TextPointers

extern EnableAutoTextBoxDrawing
extern SetSpriteFacingDirection   ; NOT YET DEFINED IN THE PORT
extern _TradeCenterOpponentText   ; NOT YET DEFINED IN THE PORT

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
hSpriteFacingDirection                         equ 0xFF8D
wSprite01StateData1FacingDirection             equ 0xC119
wSprite01StateData2MapX                        equ 0xC215
wSprite01StateData2MapY                        equ 0xC214

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
TradeCenter_Script:
    call EnableAutoTextBoxDrawing
    mov al, [ebp + hSerialConnectionStatus]
    cmp al, 2
    mov al, SPRITE_FACING_LEFT
    jz .next
    mov al, SPRITE_FACING_RIGHT
.next:
    mov [ebp + hSpriteFacingDirection], al
    mov al, 1
    mov [ebp + hSpriteIndex], al
    call SetSpriteFacingDirection
    mov esi, wStatusFlags3
    test byte [ebp + esi], (1 << (0))
    pushfd    ; SM83 form writes no flags
        or byte [ebp + esi], (1 << (0))
    popfd
    jz .nr_16
        ret
.nr_16:
    mov esi, wSprite01StateData2MapY
    mov al, 8
    mov [ebp + esi], al
    lea esi, [esi+1]
    mov al, 10
    mov [ebp + esi], al
    mov al, SPRITE_FACING_LEFT
    mov [ebp + wSprite01StateData1FacingDirection], al
    mov al, [ebp + hSerialConnectionStatus]
    cmp al, 2
    jnz .nr_26
        ret
.nr_26:
    mov al, 7
    mov [ebp + wSprite01StateData2MapX], al
    mov al, SPRITE_FACING_RIGHT
    mov [ebp + wSprite01StateData1FacingDirection], al
    ret

%assign event_byte -1
%assign event_byte_a -1
TradeCenter_TextPointers:
    dd TradeCenterOpponentText
TradeCenterOpponentText:
    text_far _TradeCenterOpponentText
    text_end
