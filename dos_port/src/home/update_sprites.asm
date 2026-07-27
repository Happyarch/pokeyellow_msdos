; update_sprites.asm — UpdateSprites, the per-frame sprite-update entry point.
;
; Mirror of pret home/update_sprites.asm, whose ONLY label is UpdateSprites.
; It was carried by src/engine/overworld/movement.asm until chunk 17 of the
; relocated-label grind; the pret file it belongs to is a home-bank file of its
; own, so it gets its own mirror even though its body is 8 instructions and its
; only callee, _UpdateSprites, sits next door in
; src/engine/overworld/sprite_collisions.asm.
;
; pret wraps the _UpdateSprites call in a bank shuffle (hLoadedROMBank save,
; BankswitchCommon to BANK(_UpdateSprites), restore). The flat DPMI model has no
; banks, so both BankswitchCommon calls are no-ops and are omitted — the same
; banking boundary CLAUDE.md sanctions tree-wide; the wUpdateSpritesEnabled
; $ff/$01 dance around the call IS reproduced.
;
; Register map: A=AL, B=BH, C=BL (BC=BX), D=DH, E=DL (DE=EDX), HL=ESI, EBP=GB base.
;
; Build: nasm -f coff -I include/ -I . -o update_sprites.o update_sprites.asm

bits 32

%include "gb_memmap.inc"

global UpdateSprites

extern _UpdateSprites            ; src/engine/overworld/sprite_collisions.asm

section .text

; ---------------------------------------------------------------------------
; UpdateSprites — gate on wUpdateSpritesEnabled, then run _UpdateSprites.
; Pret ref: home/update_sprites.asm:UpdateSprites (bank-switch omitted).
; All registers preserved.
; ---------------------------------------------------------------------------
UpdateSprites:
    cmp byte [ebp + W_UPDATE_SPRITES_ENABLED], 1
    jne .done
    pushad
    mov byte [ebp + W_UPDATE_SPRITES_ENABLED], 0xFF
    call _UpdateSprites
    mov byte [ebp + W_UPDATE_SPRITES_ENABLED], 1
    popad
.done:
    ret
