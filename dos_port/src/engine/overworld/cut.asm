; cut.asm — HM01 Cut field move (OW-3.4).
;
; Intended repo path: dos_port/src/engine/overworld/cut.asm
; pret source: engine/overworld/cut.asm
;
; UsedCut: if the tile in front of the player is a cuttable tree ($3d overworld /
; $50 gym) or grass ($52), play the cut cutscene — name popup, cut animation,
; replace the tree/grass tile block with its cut variant, redraw. Helpers build
; the cut/leaf OAM block and swap the tile block.
;
; Register map (SM83 -> x86): A->AL, B->BH, C->BL/CL, D->DH, E->DL, HL->ESI,
; EDX = flat data pointer. GB memory is [ebp+offset]. WriteOAMBlock / CopyVideoData
; take flat source pointers (EDX); GetCutOrBoulderDustAnimationOffsets returns the
; block Y/X in BH/BL.
;
; Leaves: AnimCut is a farcall to a ret-stub (overworld_stubs.asm) until OW-6.1
; ports cut2.asm; UpdateCGBPal_OBP1 is externed (unported palette, shared with
; dust_smoke). The FAR text streams (_NothingToCutText/_UsedCutText) are Tier-1
; generated (assets/cut_text.inc via gen_overworld_strings.py).
;
; Build (check): nasm -f coff -I include/ -I . -o /dev/null \
;                     src/engine/overworld/cut.asm
; ---------------------------------------------------------------------------

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_macros.inc"
%include "gb_text.inc"                       ; text_far / text_end
%include "assets/audio_constants.inc"        ; SFX_CUT

; --- symbols not yet in the shared headers (golden sym-verified) ---
%ifndef wActionResultOrTookBattleTurn
wActionResultOrTookBattleTurn equ 0xCD6A ; golden 00:cd6a
%endif
%ifndef wCutTile
wCutTile                equ 0xCD4D ; golden 00:cd4d
%endif
%ifndef wTileInFrontOfPlayer
wTileInFrontOfPlayer    equ 0xCFC5 ; golden 00:cfc5
%endif
%ifndef wWhichAnimationOffsets
wWhichAnimationOffsets  equ 0xCD50 ; golden 00:cd50
%endif
%ifndef wSpritePlayerStateData1YPixels
wSpritePlayerStateData1YPixels equ 0xC104 ; golden 00:c104
%endif
%ifndef wShadowOAMSprite36Attributes
wShadowOAMSprite36Attributes   equ 0xC393 ; golden 00:c393
%endif
%ifndef wYBlockCoord
wYBlockCoord            equ 0xD362 ; golden 00:d362
%endif
%ifndef wXBlockCoord
wXBlockCoord            equ 0xD363 ; golden 00:d363
%endif
%ifndef W_SPRITE_PLAYER_FACING_DIR
W_SPRITE_PLAYER_FACING_DIR equ 0xC109
%endif
%ifndef GYM
GYM                     equ 7      ; constants/tileset_constants.asm
%endif
%ifndef OBJ_SIZE
OBJ_SIZE                equ 4      ; bytes per OAM entry
%endif
%ifndef SCREEN_HEIGHT_PX
SCREEN_HEIGHT_PX        equ 144
%endif

global UsedCut
global UsedCutText
global InitCutAnimOAM
global LoadCutGrassAnimationTilePattern
global WriteCutOrBoulderDustAnimationOAMBlock
global GetCutOrBoulderDustAnimationOffsets
global ReplaceTreeTileBlock

extern PrintText                    ; src/text/text.asm
extern GetPartyMonName              ; src/home/pokemon.asm (AL=index, ESI=nick list)
extern GBPalWhiteOutWithDelay3      ; src/home/fade.asm
extern ClearSprites                 ; src/gfx/sprites.asm
extern RestoreScreenTilesAndReloadTilePatterns ; src/home/fade.asm
extern Delay3                       ; src/video/frame.asm
extern LoadGBPal                    ; src/home/fade.asm
extern LoadCurrentMapView           ; src/engine/overworld/overworld.asm
extern SaveScreenTilesToBuffer2     ; src/movie/title.asm
extern LoadScreenTilesFromBuffer2   ; src/movie/title.asm
extern RedrawMapView                ; src/engine/overworld/update_map.asm (OW-3.1)
extern AnimCut                      ; src/engine/overworld/cut2.asm (OW-6.1)
extern PlaySound                    ; src/home/audio.asm
extern UpdateSprites                ; src/engine/overworld/movement.asm
extern UpdateCGBPal_OBP1            ; UNPORTED (palette; shared w/ dust_smoke)
extern CopyVideoData                ; src/home/copy2.asm (ESI=VRAM dest, EDX=flat src, BL=count)
extern WriteOAMBlock                ; src/home/oam.asm (AL=block, EDX=flat src, BH=Y, BL=X)
extern overworld_gfx                ; src/engine/overworld/overworld.asm (overworld tileset gfx)

section .text

; ---------------------------------------------------------------------------
; UsedCut — pret engine/overworld/cut.asm:UsedCut
; ---------------------------------------------------------------------------
UsedCut:
    mov byte [ebp + wActionResultOrTookBattleTurn], 0 ; init to failure
    mov al, [ebp + W_CUR_MAP_TILESET]
    and al, al                                 ; OVERWORLD (0)?
    jz .overworld
    cmp al, GYM
    jne .nothingToCut
    mov al, [ebp + wTileInFrontOfPlayer]
    cmp al, 0x50                               ; gym cut tree
    jne .nothingToCut
    jmp .canCut
.overworld:
    dec al                                     ; pret quirk: a(=0)->$ff, immediately reloaded
    mov al, [ebp + wTileInFrontOfPlayer]
    cmp al, 0x3d                               ; cut tree
    je .canCut
    cmp al, 0x52                               ; grass
    je .canCut
.nothingToCut:
    mov esi, .NothingToCutText
    jmp PrintText                              ; jp PrintText (tail)
.NothingToCutText:
    text_far _NothingToCutText
    text_end
.canCut:
    mov [ebp + wCutTile], al
    mov byte [ebp + wActionResultOrTookBattleTurn], 1 ; used cut
    mov al, [ebp + wWhichPokemon]
    mov esi, wPartyMonNicks
    call GetPartyMonName
    or byte [ebp + W_STATUS_FLAGS_5], (1 << BIT_NO_TEXT_DELAY) ; set BIT_NO_TEXT_DELAY,[hl]
    call GBPalWhiteOutWithDelay3
    call ClearSprites
    call RestoreScreenTilesAndReloadTilePatterns
    mov byte [ebp + H_WY], SCREEN_HEIGHT_PX    ; TODO-HW: hWY shadow (commit_shadow_regs -> rWY)
    call Delay3
    call LoadGBPal
    call LoadCurrentMapView
    call SaveScreenTilesToBuffer2
    call Delay3
    mov byte [ebp + H_WY], 0                    ; TODO-HW: hWY
    mov esi, UsedCutText
    call PrintText
    call LoadScreenTilesFromBuffer2
    and byte [ebp + W_STATUS_FLAGS_5], ~(1 << BIT_NO_TEXT_DELAY) ; res BIT_NO_TEXT_DELAY,[hl]
    mov byte [ebp + W_UPDATE_SPRITES_ENABLED], 0xff
    call InitCutAnimOAM
    mov edx, CutTreeBlockSwaps                  ; ld de, CutTreeBlockSwaps (flat)
    call ReplaceTreeTileBlock
    call RedrawMapView
    call AnimCut                                ; pret: farcall (banking elided; ret-stub OW-6.1)
    mov byte [ebp + W_UPDATE_SPRITES_ENABLED], 1
    mov al, SFX_CUT
    call PlaySound
    mov byte [ebp + H_WY], 0x90                 ; TODO-HW: hWY
    call UpdateSprites
    jmp RedrawMapView                          ; jp RedrawMapView (tail)

UsedCutText:
    text_far _UsedCutText
    text_end

; ---------------------------------------------------------------------------
; InitCutAnimOAM — pret engine/overworld/cut.asm:InitCutAnimOAM
; Load the cut tree (or grass leaf) tiles into vChars1 and build the OAM block.
; ---------------------------------------------------------------------------
InitCutAnimOAM:
    mov byte [ebp + wWhichAnimationOffsets], 0  ; select the cut offsets
    mov byte [ebp + IO_OBP1], 0xE4              ; %11100100 ; TODO-HW: rOBP1
    call UpdateCGBPal_OBP1
    mov al, [ebp + wCutTile]
    cmp al, 0x52
    je .grass
; tree — copy the cuttable tree top ($2d) and bottom ($3d) rows (2 tiles each)
    mov edx, overworld_gfx + 0x2d * TILE_SIZE   ; Overworld_GFX tile $2d (flat src)
    mov esi, GB_VFONT + 0x7c * TILE_SIZE        ; vChars1 tile $7c (VRAM dest)
    mov bl, 2                                    ; c = 2 tiles (bank elided under flat mem)
    call CopyVideoData
    mov edx, overworld_gfx + 0x3d * TILE_SIZE   ; Overworld_GFX tile $3d
    mov esi, GB_VFONT + 0x7e * TILE_SIZE        ; vChars1 tile $7e
    mov bl, 2
    call CopyVideoData
    jmp WriteCutOrBoulderDustAnimationOAMBlock  ; jr (tail)
.grass:
    mov esi, GB_VFONT + 0x7c * TILE_SIZE
    call LoadCutGrassAnimationTilePattern
    mov esi, GB_VFONT + 0x7d * TILE_SIZE
    call LoadCutGrassAnimationTilePattern
    mov esi, GB_VFONT + 0x7e * TILE_SIZE
    call LoadCutGrassAnimationTilePattern
    mov esi, GB_VFONT + 0x7f * TILE_SIZE
    call LoadCutGrassAnimationTilePattern
    call WriteCutOrBoulderDustAnimationOAMBlock
    ; alternate the 4 leaf sprites' flip attributes (X-flip, then Y+X-flip, …)
    mov esi, wShadowOAMSprite36Attributes
    mov al, OAM_XFLIP | OAM_PAL1
    mov cl, OBJ_SIZE                             ; c = 4 (pret: ld c,e ; e = OBJ_SIZE)
.grassLoop:
    mov [ebp + esi], al                          ; ld [hl], a
    add esi, OBJ_SIZE                             ; add hl, de (de = OBJ_SIZE)
    xor al, OAM_YFLIP | OAM_XFLIP
    dec cl
    jnz .grassLoop
    ret

; ---------------------------------------------------------------------------
; LoadCutGrassAnimationTilePattern — copy the leaf tile to VRAM dest ESI.
; pret engine/overworld/cut.asm:LoadCutGrassAnimationTilePattern.  In: ESI = dest.
; ---------------------------------------------------------------------------
LoadCutGrassAnimationTilePattern:
    mov edx, MoveAnimationTiles1 + 6 * TILE_SIZE ; leaf tile (flat src)
    mov bl, 1                                    ; c = 1 tile
    jmp CopyVideoData                            ; hl(ESI)=dest already set by caller

; ---------------------------------------------------------------------------
; WriteCutOrBoulderDustAnimationOAMBlock — build the 2x2 cut/dust OAM block.
; pret engine/overworld/cut.asm:WriteCutOrBoulderDustAnimationOAMBlock.
; (Retires the extern of the same name in dust_smoke.asm / OW-4.3.)
; ---------------------------------------------------------------------------
WriteCutOrBoulderDustAnimationOAMBlock:
    call GetCutOrBoulderDustAnimationOffsets    ; BH = Y, BL = X
    mov al, 9                                   ; ld a, $9 (shadow OAM block 36)
    mov edx, .OAMBlock                          ; ld de, .OAMBlock (flat src)
    jmp WriteOAMBlock                           ; jp WriteOAMBlock (tail)
.OAMBlock:
    db 0xfc, OAM_PAL1 | OAM_HIGH_PALS
    db 0xfd, OAM_PAL1 | OAM_HIGH_PALS
    db 0xfe, OAM_PAL1 | OAM_HIGH_PALS
    db 0xff, OAM_PAL1 | OAM_HIGH_PALS

; ---------------------------------------------------------------------------
; GetCutOrBoulderDustAnimationOffsets — compute the animation block's screen
; Y (BH) / X (BL) from the player's sprite position + a per-facing offset.
; pret engine/overworld/cut.asm:GetCutOrBoulderDustAnimationOffsets.
; ---------------------------------------------------------------------------
GetCutOrBoulderDustAnimationOffsets:
    mov bh, [ebp + wSpritePlayerStateData1YPixels]      ; b = player sprite Y (C104)
    mov bl, [ebp + wSpritePlayerStateData1YPixels + 2]  ; c = player sprite X (C106)
    mov al, [ebp + W_SPRITE_PLAYER_FACING_DIR]          ; facing (00/04/08/0C)
    shr al, 1                                           ; srl a (facing / 2)
    movzx edx, al                                       ; de = facing/2 (d = 0)
    mov esi, CutAnimationOffsets
    mov al, [ebp + wWhichAnimationOffsets]
    and al, al
    jz .next
    mov esi, BoulderDustAnimationOffsets
.next:
    add esi, edx                                        ; hl += de
    mov dl, [esi]                                        ; e = x offset (flat table)
    mov dh, [esi + 1]                                   ; d = y offset
    add bh, dh                                          ; b = Y + yoff
    add bl, dl                                          ; c = X + xoff
    ret

CutAnimationOffsets:
; db x, y pixel offsets from the player of where the cut animation is drawn.
    db  8, 36 ; player is facing down
    db  8,  4 ; player is facing up
    db -8, 20 ; player is facing left
    db 24, 20 ; player is facing right

BoulderDustAnimationOffsets:
; as above but 2 blocks away from the player (boulder dust).
    db  8,  52 ; down
    db  8, -12 ; up
    db -24, 20 ; left
    db 40,  20 ; right

; ---------------------------------------------------------------------------
; ReplaceTreeTileBlock — replace the tile block holding the tree in front of the
; player with its cut variant. pret engine/overworld/cut.asm:ReplaceTreeTileBlock.
; In: EDX = flat ptr to a {before,after} block-id table ($ff-terminated).
; ESI walks a GB address inside wOverworldMap (via wCurrentTileBlockMapViewPointer).
; ---------------------------------------------------------------------------
ReplaceTreeTileBlock:
    push edx                                    ; push de (block-swap table ptr)
    movzx ebx, byte [ebp + W_CUR_MAP_WIDTH]
    add ebx, 6                                  ; bc = wCurMapWidth + 6 (b = 0)
    movzx esi, word [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR] ; hl = [ptr] (GB block addr)
    add esi, ebx                                ; add hl, bc
    mov al, [ebp + W_SPRITE_PLAYER_FACING_DIR]
    and al, al
    jz .down
    cmp al, SPRITE_FACING_UP
    je .up
    cmp al, SPRITE_FACING_LEFT
    je .left
; right
    mov al, [ebp + wXBlockCoord]
    and al, al
    jz .centerTileBlock
    jmp .rightOfCenter
.down:
    mov al, [ebp + wYBlockCoord]
    and al, al
    jz .centerTileBlock
    jmp .belowCenter
.up:
    mov al, [ebp + wYBlockCoord]
    and al, al
    jz .aboveCenter
    jmp .centerTileBlock
.left:
    mov al, [ebp + wXBlockCoord]
    and al, al
    jz .leftOfCenter
    jmp .centerTileBlock
.belowCenter:
    add esi, ebx                                ; add hl, bc
.centerTileBlock:
    add esi, ebx                                ; add hl, bc
.aboveCenter:
    mov edx, 2                                  ; ld e, $2 (d = 0)
    add esi, edx                                ; add hl, de
    jmp .next
.leftOfCenter:
    mov edx, 1                                  ; ld e, $1
    add esi, ebx                                ; add hl, bc
    add esi, edx                                ; add hl, de
    jmp .next
.rightOfCenter:
    mov edx, 3                                  ; ld e, $3
    add esi, ebx                                ; add hl, bc
    add esi, edx                                ; add hl, de
.next:
    pop edx                                     ; pop de (block-swap table ptr)
    mov al, [ebp + esi]                         ; current block id at the tree
    mov bl, al                                  ; c = block id to find
.loop:
    mov al, [edx]                               ; ld a,[de] — table "before" id (flat)
    inc edx
    inc edx
    cmp al, 0xFF
    je .ret                                     ; ret z (end of table, no match)
    cmp al, bl                                  ; cp c
    jne .loop
    dec edx                                     ; back to the "after" id
    mov al, [edx]                               ; replacement block id
    mov [ebp + esi], al                         ; ld [hl], a
.ret:
    ret

; block-swap table: {tree block, cut-tree block} pairs, $ff-terminated.
; pret: data/tilesets/cut_tree_blocks.asm:CutTreeBlockSwaps.
CutTreeBlockSwaps:
    db 0x32, 0x6D
    db 0x33, 0x6C
    db 0x34, 0x6F
    db 0x35, 0x4C
    db 0x60, 0x6E
    db 0x0B, 0x0A
    db 0x3C, 0x35
    db 0x3F, 0x35
    db 0x3D, 0x36
    db -1                                       ; end

section .data

; grass-leaf tile source — pret uses MoveAnimationTiles1 tile 6 (battle move-anim
; tiles, not yet ported); incbin the battle move-anim-1 sheet and index tile 6.
MoveAnimationTiles1:
    incbin "../gfx/battle/move_anim_1.2bpp"

; Tier-1 generated FAR text streams (_NothingToCutText, _UsedCutText).
%include "assets/cut_text.inc"
