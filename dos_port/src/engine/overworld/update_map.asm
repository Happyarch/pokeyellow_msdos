; update_map.asm — replace a block in wOverworldMap and redraw the visible map.
;
; Intended repo path: dos_port/src/engine/overworld/update_map.asm
; pret source: engine/overworld/update_map.asm
;
; ReplaceTileBlock writes [wNewTileBlockID] into the block at (b=Y, c=X) of
; wOverworldMap, then — if that block is inside the current map view — falls
; through to RedrawMapView.
;
; *** CANONICAL REDRAW PRECEDENT ***  RedrawMapView is a PROJ re-expression: pret
; repaints the visible map by staggering REDRAW_ROW VRAM copies one 2-row strip
; per DelayFrame (hRedrawMapViewRowOffset / CopyToRedrawRowOrColumnSrcTiles). The
; port's PPU is a native-width surface renderer — the 256x256 VRAM torus and the
; RedrawRowOrColumn rings are GONE (see CLAUDE.md) — so the whole staggered VRAM
; redraw collapses to: rebuild wSurroundingTiles (LoadCurrentMapView), mark the
; tile-decode cache dirty, and present one frame. cut.asm / elevator / map scripts
; cite THIS routine for their post-mutation redraw.
;
; Register map (SM83 -> x86): A->AL, HL->ESI, B->BH(Y), C->BL(X), D->DH, E->DL.
; wOverworldMap etc. are EBP-relative; g_tilecache_dirty is a flat host global.
;
; Build (check): nasm -f coff -I include/ -I . -o update_map.o \
;                     src/engine/overworld/update_map.asm
; ---------------------------------------------------------------------------

%include "gb_memmap.inc"
%include "gb_macros.inc"

global ReplaceTileBlock
global RedrawMapView
global CompareHLWithBC

extern GetPredefRegisters       ; src/home/predef.asm (restores BX=b:c, DX=d:e, ESI=hl)
extern LoadCurrentMapView       ; src/engine/overworld/overworld.asm
extern DelayFrame               ; src/video/frame.asm
extern g_tilecache_dirty        ; src/ppu/ppu.asm (flat global)

section .text

; ---------------------------------------------------------------------------
; ReplaceTileBlock — set wOverworldMap[(border) + width*Y + X] = wNewTileBlockID.
; pret: engine/overworld/update_map.asm:ReplaceTileBlock
; In (via predef): B = Y, C = X (restored by GetPredefRegisters)
; Falls through to RedrawMapView iff the block lies within the current map view.
; ---------------------------------------------------------------------------
ReplaceTileBlock:
    call GetPredefRegisters                    ; BH=Y, BL=X
    mov esi, W_OVERWORLD_MAP                    ; hl = wOverworldMap
    mov al, [ebp + W_CUR_MAP_WIDTH]
    add al, MAP_BORDER * 2                      ; a = width + border*2 (row stride)
    movzx edx, al                              ; de = stride (d=0)
    mov ecx, edx                               ; save stride (pret: push af)
; skip the top border rows: hl += stride * MAP_BORDER
    mov al, MAP_BORDER
.addBorderLoop:
    add esi, edx
    dec al
    jnz .addBorderLoop
    add esi, MAP_BORDER                        ; ld e,MAP_BORDER; add hl,de  (d=0)
    mov edx, ecx                               ; restore stride (pret: pop af; ld e,a)
; add width*Y
    test bh, bh                                ; ld a,b; and a
    jz .addX
.addWidthYTimesLoop:
    add esi, edx
    dec bh
    jnz .addWidthYTimesLoop
.addX:
    movzx eax, bl                              ; add hl, bc  (bc = X; b is 0 here)
    add esi, eax
    mov al, [ebp + W_NEW_TILE_BLOCK_ID]
    mov [ebp + esi], al                        ; ld [hl], a
; if the block is below the map view in memory, return.
    mov bl, [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR]      ; c = low byte
    mov bh, [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR + 1]  ; b = high byte
    call CompareHLWithBC
    jc .earlyRet                               ; ret c (block below view)
; if the block is above the map view in memory, return.
; PROJECTION (viewport): pret computes the view's far corner as
; `viewPtr + 4*stride + 6` (update_map.asm) — where 4 = SCREEN_BLOCK_HEIGHT-1 and
; 6 = SCREEN_BLOCK_WIDTH for pret's 6x5-block view. Both happen to collide with
; pret's border constants (MAP_BORDER+1 = 4, MAP_BORDER*2 = 6), which is why they
; were copied verbatim; they are viewport extents, not border. The port's view is
; 12x9 blocks, so the corner is (SCREEN_BLOCK_HEIGHT-1)*stride + SCREEN_BLOCK_WIDTH.
    push esi                                   ; save block address (pret: push hl)
    movzx esi, dl                              ; hl = e (stride)
    imul esi, esi, (SCREEN_BLOCK_HEIGHT - 1)   ; pret: 4 * stride (add hl,hl twice)
    add esi, SCREEN_BLOCK_WIDTH                ; pret: + 6 (de = $0006; add hl,de)
    movzx eax, bx                              ; bc = map-view pointer
    add esi, eax                               ; hl = (SBH-1)*stride + SBW + mapViewPtr
    pop ebx                                    ; bc = block address (pret: pop bc)
    call CompareHLWithBC
    jc .earlyRet                               ; ret c (block above view)
    jmp RedrawMapView                          ; pret: falls through to RedrawMapView
.earlyRet:
    ret

; ---------------------------------------------------------------------------
; RedrawMapView — repaint the visible map after a block mutation.
; pret: engine/overworld/update_map.asm:RedrawMapView (PROJ re-expression — see header).
; ---------------------------------------------------------------------------
RedrawMapView:
    mov al, [ebp + wIsInBattle]
    inc al
    jz .ret                                    ; wIsInBattle == $ff -> skip redraw
    ; PROJ: pret saves/clears hAutoBGTransferEnabled + hTileAnimations, runs the
    ; staggered per-row REDRAW_ROW VRAM copy loop, and calls RunDefaultPaletteCommand.
    ; The port's surface renderer needs none of the VRAM staggering; it rebuilds the
    ; view, dirties the decode cache, and presents one frame.
    ; TODO-HW: palette — pret's RunDefaultPaletteCommand is unimplemented (home/fade.asm).
    call LoadCurrentMapView
    mov byte [g_tilecache_dirty], 1            ; VRAM/view changed → rebuild decode cache
    call DelayFrame
.ret:
    ret

; ---------------------------------------------------------------------------
; CompareHLWithBC — 16-bit compare of HL (ESI) against BC (BX), high byte first.
; pret: engine/overworld/update_map.asm:CompareHLWithBC (a=h-b; ret nz; a=l-c; ret).
; Sets CF/ZF as the SUB does (CF = HL < BC in the pret sense). Clobbers EAX,ECX,
; flags; ESI/EBX/EDX preserved (ESI is a 16-bit GB address, so CH=h, CL=l).
; ---------------------------------------------------------------------------
CompareHLWithBC:
    mov ecx, esi                               ; ch = high byte of HL, cl = low byte
    mov al, ch
    sub al, bh                                 ; a = h - b
    jnz .done                                  ; ret nz (flags from this sub)
    mov al, cl
    sub al, bl                                 ; a = l - c (CF = l < c)
.done:
    ret
