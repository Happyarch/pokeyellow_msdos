; cut2.asm — Cut / leaf-cut sprite OAM animation (OW-6.1).
;
; Intended repo path: dos_port/src/engine/overworld/cut2.asm
; pret source: engine/overworld/cut2.asm
;
; AnimCut runs the purely-cosmetic Cut animation: for a tree it spreads the 2x2
; cut OAM block apart while flickering OBP1; for grass (wCutTile==$52) it runs
; the leaf-cut frames (AnimCutGrass_UpdateOAMEntries spreads the four OAM
; entries, AnimCutGrass_SwapOAMEntries rotates them, then the block slides down).
; Retires the AnimCut ret-stub in overworld_stubs.asm (UsedCut/cut.asm is its
; only, check-only, caller — no linked caller depended on the stub).
;
; Register map (SM83 -> x86): A->AL, B->BH, C->BL, D->DH, E->DL, HL->ESI.
; GB memory is [ebp+offset]. All shadow-OAM / wBuffer copies are WRAM->WRAM, so
; the real CopyData (EBP-relative on both operands) is used directly. rOBP1 is
; the virtual OBP1 register ([ebp+IO_OBP1], TODO-HW). The AdjustOAMBlock{X,Y}Pos2
; primitives (pret engine/battle/animations.asm — UNPORTED) take ESI = GB OAM
; offset (hl), BL = count (c), and read wCoordAdjustmentAmount.
;
; Check-only until the battle-animation OAM primitives + palette shim land.
;
; Build (check): nasm -f coff -I include/ -I . -o /dev/null \
;                     src/engine/overworld/cut2.asm
; ---------------------------------------------------------------------------

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_macros.inc"

; --- symbols not yet in the shared headers (golden sym-verified) ---
%ifndef wCutTile
wCutTile                 equ 0xCD4D ; golden 00:cd4d
%endif
%ifndef wCoordAdjustmentAmount
wCoordAdjustmentAmount   equ 0xD089 ; golden 00:d089
%endif
%ifndef wBuffer
wBuffer                  equ 0xCEE9 ; golden 00:cee9
%endif
%ifndef wShadowOAMSprite36
wShadowOAMSprite36       equ 0xC390 ; golden 00:c390
%endif
%ifndef wShadowOAMSprite36YCoord
wShadowOAMSprite36YCoord equ 0xC390 ; golden 00:c390
%endif
%ifndef wShadowOAMSprite36XCoord
wShadowOAMSprite36XCoord equ 0xC391 ; golden 00:c391
%endif
%ifndef wShadowOAMSprite37XCoord
wShadowOAMSprite37XCoord equ 0xC395 ; golden 00:c395
%endif
%ifndef wShadowOAMSprite38
wShadowOAMSprite38       equ 0xC398 ; golden 00:c398
%endif
%ifndef wShadowOAMSprite38XCoord
wShadowOAMSprite38XCoord equ 0xC399 ; golden 00:c399
%endif
%ifndef wShadowOAMSprite39XCoord
wShadowOAMSprite39XCoord equ 0xC39D ; golden 00:c39d
%endif
%ifndef OBJ_SIZE
OBJ_SIZE                 equ 4
%endif

global AnimCut
global AnimCutGrass_UpdateOAMEntries
global AnimCutGrass_SwapOAMEntries

extern DelayFrame                  ; video/frame.asm
extern UpdateCGBPal_OBP1           ; UNPORTED (pret home/palettes.asm) — apply OBP1 -> CGB palette
extern AdjustOAMBlockXPos2         ; UNPORTED (pret engine/battle/animations.asm) — ESI=GB OAM off, BL=count
extern AdjustOAMBlockYPos2         ; UNPORTED (pret engine/battle/animations.asm) — ESI=GB OAM off, BL=count
extern CopyData                    ; home/copy_data.asm (WRAM->WRAM)

section .text

; ---------------------------------------------------------------------------
; AnimCut — pret engine/overworld/cut2.asm:AnimCut
; ---------------------------------------------------------------------------
AnimCut:
    mov al, [ebp + wCutTile]
    cmp al, 0x52
    je .grass
    mov bl, 0x8                                ; ld c, $8
.cutTreeLoop:
    push ebx                                   ; push bc
    mov esi, wShadowOAMSprite36XCoord
    mov byte [ebp + wCoordAdjustmentAmount], 1
    mov bl, 2                                  ; ld c, 2
    call AdjustOAMBlockXPos2
    mov esi, wShadowOAMSprite38XCoord
    mov byte [ebp + wCoordAdjustmentAmount], -1 & 0xFF
    mov bl, 2                                  ; ld c, 2
    call AdjustOAMBlockXPos2
    mov al, [ebp + IO_OBP1]                    ; TODO-HW: rOBP1 (virtual OBP1)
    xor al, 0x64
    mov [ebp + IO_OBP1], al                    ; TODO-HW: rOBP1
    call UpdateCGBPal_OBP1
    call DelayFrame
    pop ebx                                    ; pop bc
    dec bl
    jnz .cutTreeLoop
    ret
.grass:
    mov bl, 2                                  ; ld c, 2
.cutGrassLoop:
    push ebx                                   ; push bc
    mov bl, 0x8                                ; ld c, $8
    call AnimCutGrass_UpdateOAMEntries
    call AnimCutGrass_SwapOAMEntries
    mov bl, 0x8                                ; ld c, $8
    call AnimCutGrass_UpdateOAMEntries
    call AnimCutGrass_SwapOAMEntries
    mov esi, wShadowOAMSprite36YCoord
    mov byte [ebp + wCoordAdjustmentAmount], 2
    mov bl, 4                                  ; ld c, 4
    call AdjustOAMBlockYPos2
    pop ebx                                    ; pop bc
    dec bl
    jnz .cutGrassLoop
    ret

; ---------------------------------------------------------------------------
; AnimCutGrass_UpdateOAMEntries — spread the four grass OAM entries; loops C times.
; ---------------------------------------------------------------------------
AnimCutGrass_UpdateOAMEntries:
    push ebx                                   ; push bc
    mov esi, wShadowOAMSprite36XCoord
    mov byte [ebp + wCoordAdjustmentAmount], 1
    mov bl, 1                                  ; ld c, 1
    call AdjustOAMBlockXPos2
    mov esi, wShadowOAMSprite37XCoord
    mov byte [ebp + wCoordAdjustmentAmount], 2
    mov bl, 1
    call AdjustOAMBlockXPos2
    mov esi, wShadowOAMSprite38XCoord
    mov byte [ebp + wCoordAdjustmentAmount], -2 & 0xFF
    mov bl, 1
    call AdjustOAMBlockXPos2
    mov esi, wShadowOAMSprite39XCoord
    mov byte [ebp + wCoordAdjustmentAmount], -1 & 0xFF
    mov bl, 1
    call AdjustOAMBlockXPos2
    mov al, [ebp + IO_OBP1]                    ; TODO-HW: rOBP1
    xor al, 0x64
    mov [ebp + IO_OBP1], al                    ; TODO-HW: rOBP1
    call UpdateCGBPal_OBP1
    call DelayFrame
    pop ebx                                    ; pop bc
    dec bl
    jnz AnimCutGrass_UpdateOAMEntries
    ret

; ---------------------------------------------------------------------------
; AnimCutGrass_SwapOAMEntries — rotate OAM sprites 36/37 <-> 38/39 via wBuffer.
; ---------------------------------------------------------------------------
AnimCutGrass_SwapOAMEntries:
    mov esi, wShadowOAMSprite36
    mov edx, wBuffer
    mov bx, 2 * OBJ_SIZE
    call CopyData
    mov esi, wShadowOAMSprite38
    mov edx, wShadowOAMSprite36
    mov bx, 2 * OBJ_SIZE
    call CopyData
    mov esi, wBuffer
    mov edx, wShadowOAMSprite38
    mov bx, 2 * OBJ_SIZE
    jmp CopyData
