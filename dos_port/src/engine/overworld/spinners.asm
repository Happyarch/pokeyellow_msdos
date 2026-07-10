; spinners.asm — dungeon spinner-arrow tile animation (OW-6.4).
;
; Intended repo path: dos_port/src/engine/overworld/spinners.asm
; pret source: engine/overworld/spinners.asm
;
; LoadSpinnerArrowTiles rotates the player's facing (SpinnerPlayerFacingDirections)
; and, on alternating simulated-joypad frames, copies either the spinner-arrow
; tiles or the original tileset tiles over the four spinner tiles — the blink
; that pushes the player. Facility vs Gym tilesets pick different tables.
;
; Register map (SM83 -> x86): A->AL, B->BH, C->BL, HL->ESI. GB memory is
; [ebp+offset]. The spinner tables are flat ROM: pret's `dw <src> tile N` becomes
; a `dd` flat pointer, so each entry grows 6 -> 8 bytes (dd src, db count, db bank,
; dw dest) and the table stride / skip-offset scale accordingly. CopyVideoData
; (ESI=VRAM dest GB offset, EDX=flat src, BL=count) sets g_tilecache_dirty itself.
; ; TODO-HW: the dest is a vTileset (GB_VCHARS2=$9000) tile offset — the native
; renderer re-decodes it from the tile cache.
;
; Facility_GFX / Gym_GFX (the tileset sheets the "restore" entries copy back) are
; incbin'd here as file-local labels (INTERIM — the port loads tilesets dynamically;
; retire + source from the tileset loader when unified). Check-only.
;
; Build (check): nasm -f coff -I include/ -I . -o /dev/null \
;                     src/engine/overworld/spinners.asm
; ---------------------------------------------------------------------------

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_macros.inc"

; --- symbols not yet in the shared headers (golden sym-verified) ---
%ifndef wSpritePlayerStateData1ImageIndex
wSpritePlayerStateData1ImageIndex equ 0xC102 ; golden 00:c102
%endif
%ifndef wCurMapTileset
wCurMapTileset             equ 0xD366 ; golden 00:d366
%endif
%ifndef wSimulatedJoypadStatesIndex
wSimulatedJoypadStatesIndex equ 0xCD38 ; golden 00:cd38
%endif
%ifndef FACILITY
FACILITY  equ 22
%endif
%ifndef GB_VTILESET
GB_VTILESET equ GB_VCHARS2 ; vTileset = $9000
%endif

; flat spinner entry (pret `spinner src,off,dest`): dd src, db count, db bank, dw dest
SPINNER_ENTRY_SIZE equ 8
%macro spinner 3
    dd %1 + (%2) * TILE_SIZE            ; source (flat ROM tile address)
    db 1                                ; count (tiles)
    db 0                                ; bank (flat: irrelevant)
    dw GB_VTILESET + (%3) * TILE_SIZE   ; dest (GB VRAM tile offset)
%endmacro

global LoadSpinnerArrowTiles

extern CopyVideoData               ; home/copy2.asm (ESI=VRAM dest, EDX=flat src, BL=count)

section .text

; ---------------------------------------------------------------------------
; LoadSpinnerArrowTiles — pret engine/overworld/spinners.asm:LoadSpinnerArrowTiles
; ---------------------------------------------------------------------------
LoadSpinnerArrowTiles:
    mov al, [ebp + wSpritePlayerStateData1ImageIndex]
    shr al, 1
    shr al, 1                                   ; srl a; srl a  (facing / 4)
    movzx ebx, al                               ; ld c,a; ld b,0 -> bc = index
    mov esi, SpinnerPlayerFacingDirections
    add esi, ebx                                ; add hl, bc (flat table)
    mov al, [esi]                               ; ld a,[hl] -> next facing
    mov [ebp + wSpritePlayerStateData1ImageIndex], al
    mov al, [ebp + wCurMapTileset]
    cmp al, FACILITY
    mov esi, FacilitySpinnerArrows
    je .gotSpinnerArrows
    mov esi, GymSpinnerArrows
.gotSpinnerArrows:
    mov al, [ebp + wSimulatedJoypadStatesIndex]
    test al, 1                                  ; bit 0, a (even or odd?)
    jnz .alternateGraphics
    add esi, SPINNER_ENTRY_SIZE * 4             ; pret `ld de,6*4` -> flat 8*4 (skip 4 entries)
.alternateGraphics:
    mov al, 4                                   ; ld a, $4 (entry count)
    xor ebx, ebx                                ; ld bc, $0 (running table offset)
.loop:
    push eax                                    ; push af (loop count)
    push esi                                    ; push hl (table base)
    push ebx                                    ; push bc (offset)
    add esi, ebx                                ; add hl, bc -> entry ptr
    mov edx, [esi]                              ; dd src (flat) -> EDX
    mov bl, [esi + 4]                           ; count -> BL
    movzx esi, word [esi + 6]                   ; dw dest (GB VRAM offset) -> ESI
    call CopyVideoData
    pop ebx                                     ; pop bc (offset)
    add bl, SPINNER_ENTRY_SIZE                  ; pret `ld a,$6; add c; ld c,a` -> +8
    pop esi                                     ; pop hl (table base)
    pop eax                                     ; pop af (loop count)
    dec al
    jnz .loop
    ret

section .data
SpinnerPlayerFacingDirections:
; next facing direction (spin): down->left, up->right, left->up, right->down
    db 0x08 ; down  -> left
    db 0x0C ; up    -> right
    db 0x04 ; left  -> up
    db 0x00 ; right -> down

FacilitySpinnerArrows:
    spinner SpinnerArrowAnimTiles, 0,     0x20
    spinner SpinnerArrowAnimTiles, 1,     0x21
    spinner SpinnerArrowAnimTiles, 2,     0x30
    spinner SpinnerArrowAnimTiles, 3,     0x31
    spinner Facility_GFX,          0x20,  0x20
    spinner Facility_GFX,          0x21,  0x21
    spinner Facility_GFX,          0x30,  0x30
    spinner Facility_GFX,          0x31,  0x31

GymSpinnerArrows:
    spinner SpinnerArrowAnimTiles, 1,     0x3c
    spinner SpinnerArrowAnimTiles, 3,     0x3d
    spinner SpinnerArrowAnimTiles, 0,     0x4c
    spinner SpinnerArrowAnimTiles, 2,     0x4d
    spinner Gym_GFX,               0x3c,  0x3c
    spinner Gym_GFX,               0x3d,  0x3d
    spinner Gym_GFX,               0x4c,  0x4c
    spinner Gym_GFX,               0x4d,  0x4d

; these tiles are the spinner-arrow animation (Rocket HQ / gym spin tiles).
SpinnerArrowAnimTiles:
    incbin "../gfx/overworld/spinners.2bpp"

; tileset sheets the "restore" entries copy back (INTERIM file-local incbins —
; the port loads tilesets dynamically; retire + source from the loader).
Facility_GFX:
    incbin "../gfx/tilesets/facility.2bpp"
Gym_GFX:
    incbin "../gfx/tilesets/gym.2bpp"
