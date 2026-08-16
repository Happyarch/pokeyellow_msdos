; dos_port/src/items/itemfinder.asm

%include "gb_macros.inc"
%include "gb_constants.inc"      ; FLAG_TEST
%include "gb_memmap.inc"

section .text

global HiddenItemNear
global Sub5ClampTo0

extern IsInRestOfArray
extern FlagAction
extern HiddenItemCoords

; -----------------------------------------------------------------------------
; HiddenItemNear
; Checks if there is a hidden item near the player's coordinates.
; Sets carry flag if an item is near, clears carry flag otherwise.
; -----------------------------------------------------------------------------
HiddenItemNear:
    lea esi, [HiddenItemCoords]
    mov bh, 0
.loop:
    mov dx, 3
    mov al, byte [ebp + wCurMap]
    call IsInRestOfArray
    jnc .done ; return if current map has no hidden items
    
    push bx
    push esi
    
    ; UNVERIFIED by any scenario, but NOT unlinked — that half of this note was
    ; stale and is corrected 2026-08-14: label_status reports HiddenItemNear with
    ; one port caller, ItemUseItemfinder (item_effects.asm:1625), so this runs in
    ; the shipped build. Three mechanical bugs fixed 2026-07-12 alongside the evolution-path
    ; repair, all of which would have made this silently read the wrong flag:
    ;   - the flag array went in EDI; FlagAction takes it in ESI (HL).
    ;   - FLAG_TEST is 2, not 1 (1 is FLAG_SET — this would have SET the flag).
    ;   - FlagActionPredef's first act is GetPredefRegisters, which reloads
    ;     ESI/EDX/EBX from the stale wPredefHL/DE/BC slots. The port has no predef
    ;     dispatcher: call FlagAction directly. (Same trap as experience.asm and
    ;     evolution.asm.)
    mov esi, W_OBTAINED_HIDDEN_ITEMS_FLAGS
    mov cl, bh
    mov bh, FLAG_TEST
    call FlagAction
    mov ah, cl                      ; FlagAction returns the result in CL
    
    pop esi
    pop bx
    
    inc bh
    test ah, ah
    
    ; FLAG PRESERVATION: pret's `and a` sets ZF and its three `inc hl` are
    ; FLAG-NEUTRAL on SM83 (16-bit inc writes no flags), so its `jr nz` reads the
    ; flag test. `inc esi` DOES write ZF, and ESI here is a flat table address
    ; that is never zero, so ZF was always clear and this branch was ALWAYS
    ; TAKEN — every hidden item read as already-obtained and the Itemfinder
    ; could never report one. `lea` is the flag-neutral x86 equivalent.
    lea esi, [esi + 1]
    mov dh, byte [esi] ; d = [hl]
    lea esi, [esi + 1]
    mov dl, byte [esi] ; e = [hl]
    lea esi, [esi + 1]
    jnz .loop ; if item has already been obtained
    
    ; check if the item is within 4-5 tiles
    mov al, byte [ebp + wYCoord]
    call Sub5ClampTo0
    cmp al, dh
    jnc .loop
    
    mov al, byte [ebp + wYCoord]
    add al, 4
    cmp al, dh
    jc .loop
    
    mov al, byte [ebp + wXCoord]
    call Sub5ClampTo0
    cmp al, dl
    jnc .loop
    
    mov al, byte [ebp + wXCoord]
    add al, 5
    cmp al, dl
    jc .loop
    
    stc
    ret

.done:
    clc
    ret

; -----------------------------------------------------------------------------
; Sub5ClampTo0
; subtract 5 but clamp to 0
; -----------------------------------------------------------------------------
Sub5ClampTo0:
    sub al, 5
    cmp al, 0xF0
    jc .ret
    mov al, 0
.ret:
    ret
