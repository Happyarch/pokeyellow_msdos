; dust_smoke.asm — boulder-push dust animation (OW-4.3).
;
; Intended repo path: dos_port/src/engine/overworld/dust_smoke.asm
; pret source: engine/overworld/dust_smoke.asm
;
; AnimateBoulderDust runs the 8-step smoke puff animation shown when a Strength
; boulder is pushed: it loads the smoke tile 4× into vChars1, writes the OAM
; block (shared cut/dust routine), then per step advances the OAM block via a
; per-facing adjust function and flickers OBP1. GetMoveBoulderDustFunctionPointer
; selects that adjust function + coord delta from the player's facing.
; LoadSmokeTile{FourTimes} copy the smoke tile to VRAM via CopyVideoData.
;
; Register map (SM83 -> x86): A->AL, B->BH, C->BL/CL, D->DH, E->DL, HL->ESI.
; GB memory is [ebp+offset]. The function-pointer table is a flat `dd` (pret
; `dw`), so entries are 6 bytes (db,db,dd) not 4, and the facing index scales
; accordingly. The pret `jp hl` manual-call trampoline becomes an indirect
; `call esi` (push return / jump-to-func / func rets back).
;
; Check-only until the OAM-animation subsystem lands: externs the unported
; UpdateCGBPal_OBP1 (palette), WriteCutOrBoulderDustAnimationOAMBlock and
; AdjustOAMBlock{Y,X}Pos (shared with cut — OW-3.4).
;
; Build (check): nasm -f coff -I include/ -I . -o /dev/null \
;                     src/engine/overworld/dust_smoke.asm
; ---------------------------------------------------------------------------

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_macros.inc"

; --- symbols not yet in the shared headers (golden sym-verified) ---
%ifndef wWhichAnimationOffsets
wWhichAnimationOffsets  equ 0xCD50 ; golden 00:cd50
%endif
%ifndef wCoordAdjustmentAmount
wCoordAdjustmentAmount  equ 0xD089 ; golden 00:d089
%endif
%ifndef wShadowOAMSprite36
wShadowOAMSprite36      equ 0xC390 ; golden 00:c390
%endif
%ifndef wSpritePlayerStateData1FacingDirection
wSpritePlayerStateData1FacingDirection equ 0xC109 ; golden 00:c109
%endif

global AnimateBoulderDust
global GetMoveBoulderDustFunctionPointer
global LoadSmokeTileFourTimes
global LoadSmokeTile

extern UpdateCGBPal_OBP1            ; overworld_stubs.asm ret-stub (TODO-HW palette; pret home/cgb_palettes.asm)
extern WriteCutOrBoulderDustAnimationOAMBlock ; src/engine/overworld/cut.asm (OW-3.4)
extern AdjustOAMBlockYPos          ; UNPORTED (OW-3.4 cut.asm shared OAM anim primitive)
extern AdjustOAMBlockXPos          ; UNPORTED (OW-3.4 cut.asm shared OAM anim primitive)
extern CopyVideoData               ; home/copy2.asm (In: ESI=VRAM dest, EDX=flat src, BL=count)
extern Delay3                      ; video/frame.asm
extern LoadPlayerSpriteGraphics    ; engine/overworld/player_gfx.asm

section .text

; ---------------------------------------------------------------------------
; AnimateBoulderDust — pret engine/overworld/dust_smoke.asm:AnimateBoulderDust
; ---------------------------------------------------------------------------
AnimateBoulderDust:
    mov byte [ebp + wWhichAnimationOffsets], 1  ; select the boulder dust offsets
    mov al, [ebp + W_UPDATE_SPRITES_ENABLED]
    push eax                                    ; push af (save wUpdateSpritesEnabled)
    mov byte [ebp + W_UPDATE_SPRITES_ENABLED], 0xff
    mov byte [ebp + IO_OBP1], 0xE4              ; %11100100 ; TODO-HW: rOBP1 (virtual OBP1)
    call UpdateCGBPal_OBP1
    call LoadSmokeTileFourTimes
    call WriteCutOrBoulderDustAnimationOAMBlock ; pret: farcall (banking elided; OW-3.4 unported)
    mov cl, 8                                   ; number of steps in animation
.loop:
    push ecx                                    ; save step counter (pret: push bc)
    call GetMoveBoulderDustFunctionPointer      ; ESI = adjust func, EDX = OAM sprite ptr
    mov cl, 4                                    ; c = OAM entries to adjust (arg to the func)
    call esi                                     ; pret: ld bc,.ret / push bc / jp hl (manual call)
    mov al, [ebp + IO_OBP1]                     ; TODO-HW: rOBP1
    xor al, 0x64                                ; %01100100 (palette flicker)
    mov [ebp + IO_OBP1], al                     ; TODO-HW: rOBP1
    call UpdateCGBPal_OBP1
    call Delay3
    pop ecx                                     ; restore step counter (pret: pop bc)
    dec cl
    jnz .loop
    pop eax                                     ; pop af
    mov [ebp + W_UPDATE_SPRITES_ENABLED], al    ; restore wUpdateSpritesEnabled
    jmp LoadPlayerSpriteGraphics                ; jp (tail)

; ---------------------------------------------------------------------------
; GetMoveBoulderDustFunctionPointer
; pret engine/overworld/dust_smoke.asm:GetMoveBoulderDustFunctionPointer
; Out: ESI = adjust-function pointer, EDX = OAM sprite pointer (GB offset),
;      wCoordAdjustmentAmount = Y-delta.
; ---------------------------------------------------------------------------
GetMoveBoulderDustFunctionPointer:
    mov al, [ebp + wSpritePlayerStateData1FacingDirection] ; 0/4/8/12 (down/up/left/right)
    shr al, 2                                   ; entry index 0..3 (facing / 4)
    movzx eax, al
    imul eax, eax, 6                            ; 6-byte entries (db,db,dd) — flat dd, not pret dw
    mov esi, MoveBoulderDustFunctionPointerTable
    add esi, eax                                ; flat ptr to the entry
    mov al, [esi]                               ; ld a,[hli] — Y adjust (table is in image → flat)
    mov [ebp + wCoordAdjustmentAmount], al
    movzx edx, byte [esi + 1]                   ; ld a,[hli]; ld e,a — X (OAM byte offset 0/1); d=0
    mov esi, [esi + 2]                          ; dd func ptr (flat) → hl = func ptr (read last)
    add edx, wShadowOAMSprite36                 ; de = wShadowOAMSprite36 + e (OAM sprite ptr)
    ret

; ---------------------------------------------------------------------------
; LoadSmokeTileFourTimes — copy the smoke tile into vChars1 tiles $7c..$7f.
; pret engine/overworld/dust_smoke.asm:LoadSmokeTileFourTimes
; ---------------------------------------------------------------------------
LoadSmokeTileFourTimes:
    mov esi, GB_VFONT + 0x7c * TILE_SIZE        ; vChars1 tile $7c (0x8800 + 0x7c0 = 0x8fc0)
    mov cl, 4
.loop:
    push ecx
    push esi
    call LoadSmokeTile                          ; ESI = dest; CopyVideoData sets g_tilecache_dirty
    pop esi
    add esi, TILE_SIZE                          ; ld bc,TILE_SIZE; add hl,bc
    pop ecx
    dec cl
    jnz .loop
    ret

; ---------------------------------------------------------------------------
; LoadSmokeTile — copy one smoke tile to VRAM dest ESI. pret: jp CopyVideoData.
; In: ESI = VRAM dest (set by caller; preserved here).
; ---------------------------------------------------------------------------
LoadSmokeTile:
    mov edx, SSAnneSmokePuffTile                ; ld de, SSAnneSmokePuffTile (flat src)
    mov bl, (SSAnneSmokePuffTileEnd - SSAnneSmokePuffTile) / TILE_SIZE ; c = tile count
    ; b = BANK(...) elided under flat memory
    jmp CopyVideoData                           ; hl(ESI)=dest already set by caller

section .data

; boulder_dust_adjust Y, X, func  →  db Y, db X, dd func (flat dd; pret dw). 6-byte entries.
MoveBoulderDustFunctionPointerTable:
    db -1, 0
    dd AdjustOAMBlockYPos                        ; down
    db  1, 0
    dd AdjustOAMBlockYPos                        ; up
    db  1, 1
    dd AdjustOAMBlockXPos                        ; left
    db -1, 1
    dd AdjustOAMBlockXPos                        ; right

SSAnneSmokePuffTile:
    incbin "../gfx/overworld/smoke.2bpp"
SSAnneSmokePuffTileEnd:
