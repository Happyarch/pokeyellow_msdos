; pics.asm — mon-pic merge + placement pipeline (Wave 2, Stage 1c-ii).
;
; Mirror of pret home/pics.asm. Holds five of its six pret labels:
;   UncompressMonSprite, LoadMonFrontSprite, LoadUncompressedSpriteData,
;   AlignSpriteDataCentered, ZeroSpriteBuffer, InterlaceMergeSpriteBuffers.
; (Everything else here is PORT-ONLY: LoadMonPicToVRAM, LoadMonBackPicToVRAM,
; PlacePicTilemap, RefreshMonFrontRepaintPalette, SlideBattlePicsIn, and the
; embedded-pic loaders DebugLoadEmbeddedEnemyFrontPic / DebugLoadEmbeddedTrainerPic
; / LoadEmbeddedBackPicFallback. Those three carried forked "Draw*Pic_Stub" names
; until 2026-07-27: they are not stubs (they have real bodies and never lived in a
; *_stubs.asm), so the suffix asserted a convention they did not follow. The fourth,
; DrawPlayerRedBackPic_Stub, was pret engine/battle/core.asm:LoadPlayerBackPic all
; along and MOVED to src/engine/battle/core.asm under its pret name.)
;
; FOUR pret labels this file used to carry MOVED OUT in the s16 mirror repair,
; because they belong to other pret files:
;   LoadFrontSpriteByMonIndex + LoadFlippedFrontSpriteByMonIndex are
;     home/pokemon.asm labels   -> src/home/pokemon.asm
;   CopyUncompressedPicToHL + LoadMonBackPic are
;     engine/battle/init_battle.asm labels -> src/engine/battle/init_battle.asm
; Nothing left in this file calls any of them.
; Pairs with src/gfx/uncompress.asm (the byte-exact-validated decoder).
;
; Flow (front pic): UncompressSpriteData decodes the stream into the two dense,
; column-major 1bpp chunks in sSpriteBuffer1 / sSpriteBuffer2; this file then
;   1. zeroes buffer0 and copies+centers chunk1 (buffer1) into it,
;   2. zeroes buffer1 and copies+centers chunk2 (buffer2) into it,
;   3. interlaces buffer0(MSB) + buffer1(LSB) into the 7x7 2bpp sprite in
;      buffer1+2, then copies the 49 tiles to VRAM and marks the tile cache dirty.
; PlacePicTilemap then writes the 49 tile IDs into W_TILEMAP in the column-major
; order the merged buffer produces (faithful to CopyUncompressedPicToTilemap).
;
; Render path: the battle BG uses SIGNED tile addressing, so tile ID $00-$7F maps
; to VRAM $9000-$97F0 (vChars2). We place the front pic at VRAM $9000 (tile ID $00),
; clear of the box/HP-bar tiles the HUD loads at $60-$7F.
;
; Register map: A=AL, BC=BX, DE=DX, HL=ESI, EBP=GB base; GB memory = [EBP+addr].
;
%include "gb_memmap.inc"
%include "gb_constants.inc"
%define UI_LAYOUT_EQUATES_ONLY 1
%include "assets/ui_layout_battle.inc"

bits 32

%define FW         SCREEN_TILES_W       ; 40 — W_TILEMAP stride
%define T_SP       0x7F                 ; blank/space tile (canvas clear)
%define PIC_SIZE   (7 * 7)              ; 49 tiles in the centered 7x7 sprite buffer
                                        ; (free SRAM just past sSpriteBuffer2 $A498)

extern ScaleSpriteByTwo           ; src/engine/battle/scale_sprites.asm
extern UncompressSpriteData
extern g_tilecache_dirty
extern DelayFrame
extern SetPal_BattleBlack
extern SetPal_Battle
extern repaint_front_table, tile_pal, bg_slot_pal, g_pal_dirty
global SlideBattlePicsIn

global LoadMonPicToVRAM
global LoadMonBackPicToVRAM
global PlacePicTilemap

; --- mon front-pic dispatch (M6.3, faithful port of home/pokemon.asm + home/pics.asm) ---
global LoadMonFrontSprite
global UncompressMonSprite
global RefreshMonFrontRepaintPalette

; --- embedded-pic loaders. DebugLoadEmbedded* are debug-harness-only (debug_dump.asm);
;     LoadEmbeddedBackPicFallback is the no-MON_FRONT_PICS build fallback. None is a
;     stub in the *_stubs.asm sense -- see each routine's header ---
global DebugLoadEmbeddedEnemyFrontPic
global LoadEmbeddedBackPicFallback
global DebugLoadEmbeddedTrainerPic

; MonFrontPics: Tier-1 GENERATED table (dex order, 151 records of {dd flatptr, dd len})
; pointing at the incbin'd compressed front .pic blobs. Build with -D MON_FRONT_PICS
; once tools/generators/gen_mon_pics.py + assets/mon_pics.inc + src/data/mon_pics.asm land and
; src/data/mon_pics.asm is added to the link set. See M6.3 SUMMARY "data follow-up".
%ifdef MON_FRONT_PICS
extern MonFrontPics
%endif

; pret constants not carried in gb_constants.inc:
;   RHYDON = internal index $01 (constants/pokemon_constants.asm)
;   NUM_POKEMON = 151          (constants/pokedex_constants.asm)

section .text

; ---------------------------------------------------------------------------
; LoadMonPicToVRAM — decode a compressed pic and assemble it into VRAM.
; In:  [wSpriteInputPtr] = GB addr of the staged compressed stream
;      [wSpriteFlipped]  = 0 front / 1 back
;      AL  = dimensions byte (hi nybble = height tiles, lo = width tiles)
;      EDX = destination VRAM GB address (e.g. GB_VCHARS2 = $9000)
; Out: 49 merged 2bpp tiles at [EDX]; g_tilecache_dirty set.
; ---------------------------------------------------------------------------
LoadMonPicToVRAM:
    mov [pic_dest], edx
    mov [pic_dims], al
    call UncompressSpriteData          ; -> buffer1 = chunk1, buffer2 = chunk2
    mov al, [pic_dims]
    ; fall through

; ---------------------------------------------------------------------------
; LoadUncompressedSpriteData — center each chunk in a 7x7 buffer, then merge.
; In: AL = dimensions byte.  Reuses [pic_dest] as the merge destination.
; ---------------------------------------------------------------------------
LoadUncompressedSpriteData:
    mov bl, al                         ; save dims byte
    and al, 0x0f                       ; width in tiles
    mov [hSpriteWidth], al
    mov bh, al
    mov al, 7
    sub al, bh                         ; 7-w
    inc al                             ; 8-w
    shr al, 1                          ; (8-w)/2  — horizontal center, tiles
    mov bh, al
    add al, al
    add al, al
    add al, al                         ; *8
    sub al, bh                         ; *7  — skip for horizontal center, in tiles
    mov [hSpriteOffset], al
    mov al, bl
    shr al, 4                          ; height in tiles (hi nybble)
    mov bh, al
    add al, al
    add al, al
    add al, al                         ; *8  — height in bytes
    mov [hSpriteHeight], al
    mov al, 7
    sub al, bh                         ; 7-h  — vertical center, tiles
    mov bh, al
    mov al, [hSpriteOffset]
    add al, bh                         ; 7*((8-w)/2) + (7-h)
    add al, al
    add al, al
    add al, al                         ; *8  — combined overall offset, in bytes
    mov [hSpriteOffset], al

    mov esi, sSpriteBuffer0
    call ZeroSpriteBuffer
    mov edx, sSpriteBuffer1            ; src chunk1
    mov esi, sSpriteBuffer0            ; -> buffer0 (becomes 2bpp MSB)
    call AlignSpriteDataCentered
    mov esi, sSpriteBuffer1
    call ZeroSpriteBuffer
    mov edx, sSpriteBuffer2            ; src chunk2
    mov esi, sSpriteBuffer1            ; -> buffer1 (becomes 2bpp LSB)
    call AlignSpriteDataCentered
    ; fall through to InterlaceMergeSpriteBuffers

; ---------------------------------------------------------------------------
; InterlaceMergeSpriteBuffers — interlace buffer0(MSB)+buffer1(LSB) into the 2bpp
; sprite spanning buffer1+buffer2 (rows of the two planes alternate), optionally
; nybble-swap for a flipped sprite, then copy the 49 tiles to [pic_dest] VRAM.
; ---------------------------------------------------------------------------
InterlaceMergeSpriteBuffers:
    mov edi, sSpriteBuffer2 + SPRITEBUFFERSIZE - 1   ; dest end (walk down)
    mov edx, sSpriteBuffer1 + SPRITEBUFFERSIZE - 1   ; source 2: buffer1 end
    mov esi, sSpriteBuffer0 + SPRITEBUFFERSIZE - 1   ; source 1: buffer0 end
    mov ecx, SPRITEBUFFERSIZE / 2
.interlace:
    mov al, [ebp + edx]
    dec edx
    mov [ebp + edi], al
    dec edi
    mov al, [ebp + esi]
    dec esi
    mov [ebp + edi], al
    dec edi
    mov al, [ebp + edx]
    dec edx
    mov [ebp + edi], al
    dec edi
    mov al, [ebp + esi]
    dec esi
    mov [ebp + edi], al
    dec edi
    dec ecx
    jnz .interlace

    cmp byte [ebp + wSpriteFlipped], 0
    je .notFlipped
    lea edi, [ebp + sSpriteBuffer1]                  ; flipped: swap nybbles, all bytes
    mov ecx, 2 * SPRITEBUFFERSIZE
.swap:
    mov al, [edi]
    rol al, 4
    mov [edi], al
    inc edi
    dec ecx
    jnz .swap
.notFlipped:
    lea esi, [ebp + sSpriteBuffer1]                  ; copy 49 tiles -> VRAM
    mov edi, [pic_dest]
    lea edi, [ebp + edi]
    mov ecx, PIC_SIZE * 16
    rep movsb
    mov byte [g_tilecache_dirty], 1
    ret

; ---------------------------------------------------------------------------
; AlignSpriteDataCentered — copy hSpriteWidth columns of hSpriteHeight bytes from
; [EDX] (source, read densely) into [ESI]+hSpriteOffset (dest), stepping the dest
; one full 7-tile column (56 bytes) between source columns. Centers the sprite.
; In: EDX = source GB addr, ESI = dest buffer GB addr.
; ---------------------------------------------------------------------------
AlignSpriteDataCentered:
    movzx eax, byte [hSpriteOffset]
    add esi, eax                       ; dest += centering offset
    mov cl, [hSpriteWidth]
.column:
    push esi
    mov ch, [hSpriteHeight]
.inner:
    mov al, [ebp + edx]
    inc edx
    mov [ebp + esi], al
    inc esi
    dec ch
    jnz .inner
    pop esi
    add esi, 7 * TILE_1BPP_SIZE         ; advance one full column (7 tiles)
    dec cl
    jnz .column
    ret

; ---------------------------------------------------------------------------
; ZeroSpriteBuffer — zero SPRITEBUFFERSIZE bytes at [ESI]. Preserves ESI.
; ---------------------------------------------------------------------------
ZeroSpriteBuffer:
    push esi
    lea edi, [ebp + esi]
    xor al, al
    mov ecx, SPRITEBUFFERSIZE
    rep stosb
    pop esi
    ret

; ---------------------------------------------------------------------------
; LoadMonBackPicToVRAM — decode a back pic, scale it 2x (4x4 -> 7x7), merge to VRAM.
; In:  [wSpriteInputPtr] = staged stream, [wSpriteFlipped] = flag, EDX = dest VRAM.
; ---------------------------------------------------------------------------
LoadMonBackPicToVRAM:
    mov [pic_dest], edx
    call UncompressSpriteData           ; buffer1 = chunk1, buffer2 = chunk2 (4x4 dense)
    call ScaleSpriteByTwo               ; buffer0 = scaled chunk1, buffer1 = scaled chunk2
    call InterlaceMergeSpriteBuffers
    ret

; ---------------------------------------------------------------------------
; PlacePicTilemap — write a 7x7 block of tile IDs into W_TILEMAP, column-major
; (ID = base + col*7 + row), matching the merged buffer's tile order.
; In: EDI = [ebp + W_TILEMAP + topleft] dest, AL = base tile ID.
; ---------------------------------------------------------------------------
PlacePicTilemap:
    mov bl, al                         ; running tile ID
    mov ecx, 7                         ; columns
.col:
    push edi
    push ecx
    mov ecx, 7                         ; rows
    mov al, bl
.row:
    mov [edi], al
    add edi, FW
    inc al
    dec ecx
    jnz .row
    mov bl, al                         ; next column continues the ID sequence
    pop ecx
    pop edi
    inc edi                            ; next column to the right
    dec ecx
    jnz .col
    ret

; ---------------------------------------------------------------------------
; LoadMonFrontSprite / UncompressMonSprite
; Source: home/pics.asm (pret/pokeyellow): UncompressMonSprite + LoadMonFrontSprite.
; pret reads the front-pic ROM pointer out of the loaded mon header ($b) and bank-
; selects by species index; the port has no banks, and the mon-header sprite pointer
; is a GB-ROM address with no meaning here, so the pic is resolved via the dex-keyed
; MonFrontPics table (Tier-1 data) and the compressed blob is staged into GB scratch
; because the decoder addresses its input with a 16-bit GB pointer ([ebp+wSpriteInputPtr]).
; In:  EAX = dex-1 (0..150); EDX = dest VRAM GB addr; [wSpriteFlipped] set.
; ---------------------------------------------------------------------------
LoadMonFrontSprite:
    mov [pic_dest], edx                      ; merge destination (LoadUncompressedSpriteData)
    mov [pic_repaint_index], eax             ; dex-1, preserved across the decoder
    call UncompressMonSprite                  ; stage blob + decode chunks into buffers
    mov al, [pic_dims]
    call LoadUncompressedSpriteData           ; center each chunk + interlace -> VRAM
    call ApplyMonFrontRepaint                 ; R2: normal decode remains intact if no record
    ret

; ---------------------------------------------------------------------------
; ApplyMonFrontRepaint — optionally replace a decoded 7x7 front picture with
; the sidecar-authored 2bpp repaint.  The editor stores PNG tiles row-major;
; battle VRAM / CopyUncompressedPicToHL use column-major tile ids, so transpose
; both pixel tiles and their per-tile palette grid while copying.  Repaint
; palettes occupy free BG slots 4..7; normal pictures have a zero table entry
; and therefore retain the byte-exact UncompressSpriteData result.
; ---------------------------------------------------------------------------
ApplyMonFrontRepaint:
    push ebx
    mov byte [repaint_active], 0
    mov eax, [pic_repaint_index]
    mov esi, [repaint_front_table + eax*4]
    test esi, esi
    jz .done
    mov eax, [esi]                           ; record: 2bpp source, row-major grid
    mov [repaint_blob], eax
    mov eax, [esi + 4]
    mov [repaint_grid], eax
    movzx ecx, byte [esi + 8]                ; 1..4 generated palette ids
    lea edx, [esi + ecx + 9]
    mov al, [edx]
    mov [repaint_width], al
    mov al, [edx + 1]
    mov [repaint_height], al
    mov al, 8
    sub al, [repaint_width]
    shr al, 1
    mov [repaint_x_offset], al
    mov al, 7
    sub al, [repaint_height]
    mov [repaint_y_offset], al
    lea esi, [esi + 9]
    mov edi, bg_slot_pal + 4
    rep movsb
    mov byte [repaint_active], 1

    mov byte [repaint_x], 0
.column:
    mov byte [repaint_y], 0
.row:
    ; source tile = row*width+column (PNG order), destination is centered
    ; column-major tile storage in the 7x7 vFrontPic canvas.
    movzx eax, byte [repaint_y]
    movzx edx, byte [repaint_width]
    imul eax, edx
    movzx edx, byte [repaint_x]
    add eax, edx
    shl eax, 4
    mov esi, [repaint_blob]
    add esi, eax
    movzx eax, byte [repaint_x]
    add al, [repaint_x_offset]
    imul eax, eax, 7
    movzx edx, byte [repaint_y]
    add dl, [repaint_y_offset]
    add eax, edx
    shl eax, 4
    mov edi, [pic_dest]
    add edi, ebp
    add edi, eax
    mov ecx, 4
    rep movsd

    ; The physical cache index is ($9000-$8000)/16 + destination tile id.
    movzx eax, byte [repaint_y]
    movzx edx, byte [repaint_width]
    imul eax, edx
    movzx edx, byte [repaint_x]
    add eax, edx
    mov esi, [repaint_grid]
    mov bl, [esi + eax]
    add bl, 4                               ; local repaint palette -> BG slot 4..7
    movzx edx, byte [repaint_x]
    add dl, [repaint_x_offset]
    imul edx, edx, 7
    movzx eax, byte [repaint_y]
    add al, [repaint_y_offset]
    add edx, eax
    mov eax, [pic_dest]
    sub eax, GB_VRAM0
    shr eax, 4
    add eax, edx
    mov [tile_pal + eax], bl

    inc byte [repaint_y]
    mov al, [repaint_y]
    cmp al, [repaint_height]
    jb .row
    inc byte [repaint_x]
    mov al, [repaint_x]
    cmp al, [repaint_width]
    jb .column
    mov byte [g_tilecache_dirty], 1
    mov byte [g_pal_dirty], 1
.done:
    pop ebx
    ret

; Reapply just the front-picture palette metadata after SetPal_Battle copies its
; 384-byte baseline.  HP-bar animation calls that setter too, so this deliberately
; does not touch VRAM; the 2bpp repaint was already blitted by ApplyMonFrontRepaint.
RefreshMonFrontRepaintPalette:
    pushad
    cmp byte [repaint_active], 0
    je .restore
    mov eax, [pic_repaint_index]
    mov esi, [repaint_front_table + eax*4]
    test esi, esi
    jz .restore
    movzx ecx, byte [esi + 8]
    lea esi, [esi + 9]
    mov edi, bg_slot_pal + 4
    rep movsb
    ; Grid begins at the record's second pointer.  Convert row-major PNG cells
    ; to the column-major vFrontPic tile ids ($9000 = cache tile 256).
    mov esi, [repaint_front_table + eax*4]
    mov esi, [esi + 4]
    mov byte [repaint_x], 0
.column:
    mov byte [repaint_y], 0
.row:
    movzx eax, byte [repaint_y]
    movzx edx, byte [repaint_width]
    imul eax, edx
    movzx edx, byte [repaint_x]
    add eax, edx
    mov bl, [esi + eax]
    add bl, 4
    movzx edx, byte [repaint_x]
    add dl, [repaint_x_offset]
    imul edx, edx, 7
    movzx eax, byte [repaint_y]
    add al, [repaint_y_offset]
    add edx, eax
    mov eax, [pic_dest]
    sub eax, GB_VRAM0
    shr eax, 4
    add eax, edx
    mov [tile_pal + eax], bl
    inc byte [repaint_y]
    mov al, [repaint_y]
    cmp al, [repaint_height]
    jb .row
    inc byte [repaint_x]
    mov al, [repaint_x]
    cmp al, [repaint_width]
    jb .column
.restore:
    popad
    ret

; In: EAX = dex-1. Stage the compressed front pic into GB scratch, point the decoder
; at it, and decode the two 1bpp chunks into sSpriteBuffer1/2 (tail-calls the decoder).
UncompressMonSprite:
%ifdef MON_FRONT_PICS
    lea esi, [MonFrontPics + eax*8]          ; record: dd flatptr, dd len
    mov ecx, [esi + 4]                        ; blob length
    mov esi, [esi]                            ; flat ptr to the compressed .pic
%else
    ; FALLBACK (build without -D MON_FRONT_PICS): stage the single embedded debug
    ; front pic (pidgey) for EVERY mon. The real per-mon MonFrontPics table now
    ; ships (tools/generators/gen_mon_pics.py → assets/mon_pics.inc + src/data/mon_pics.asm),
    ; and MON_FRONT_PICS is on by default in the Makefile — this path is only for
    ; an explicit no-data build. See the M6.3 SUMMARY history.
    mov esi, embedded_pic
    mov ecx, embedded_pic_len
%endif
    lea edi, [ebp + PIC_STAGE]
    rep movsb                                 ; stage compressed stream into GB scratch
    mov word [ebp + wSpriteInputPtr], PIC_STAGE
    mov al, [ebp + PIC_STAGE]                 ; dims byte (hi nyb = W, lo nyb = H tiles)
    mov [pic_dims], al
    jmp UncompressSpriteData                   ; -> buffer1 = chunk1, buffer2 = chunk2

; ---------------------------------------------------------------------------
; DebugLoadEmbeddedEnemyFrontPic — DEBUG-HARNESS ONLY. Stages an embedded pic,
; decodes + merges it to VRAM $9000 for the battle canvas. Hard-codes one mon
; (PIDGEY) so the decode/merge/placement can be visually gated. The production
; path is LoadMonFrontSprite / LoadFrontSpriteByMonIndex via the generated
; MonFrontPics table; this is reached only from src/debug/debug_dump.asm.
;
; Port-only by design: it is deliberately UNFAITHFUL (one hardcoded species), so
; it takes a descriptive port-only name rather than a pret label. It is not a STUB
; under the stub convention -- it stands in for nothing at link time and no pret
; label resolves to it.
; ---------------------------------------------------------------------------
DebugLoadEmbeddedEnemyFrontPic:
    mov esi, embedded_pic              ; stage compressed stream into GB space
    lea edi, [ebp + PIC_STAGE]
    mov ecx, embedded_pic_len
    rep movsb
    mov word [ebp + wSpriteInputPtr], PIC_STAGE
    mov byte [ebp + wSpriteFlipped], 0
    mov al, [embedded_pic]             ; dims byte
    mov edx, GB_VCHARS2                ; VRAM $9000 -> signed tile ID $00
    call LoadMonPicToVRAM              ; decode → VRAM only; the slide-in places it
    ret

; ---------------------------------------------------------------------------
; LoadEmbeddedBackPicFallback — no-data-build fallback + debug harness. Stages the
; embedded PIKACHU back pic, decodes + 2x-scales + merges it to VRAM $9310.
;
; DEVIATION{class=temporary; pret=engine/battle/init_battle.asm:LoadMonBackPic; behavior=returns one hardcoded species back pic instead of the sent-out mon's, reached only as LoadMonBackPic's fallback in a build assembled without MON_FRONT_PICS; evidence=src/engine/battle/init_battle.asm LoadMonBackPic reaches this solely from the %else of %ifdef MON_FRONT_PICS and dos_port/Makefile line 26 defines MON_FRONT_PICS unconditionally so the shipping build never takes it; lifetime=retires when the no-data build configuration is dropped}
; Port-only label, so this is a DEVIATION not a STUB -- a STUB annotation must name a pret label it stands in for at link time, and nothing resolves to this name.
; ---------------------------------------------------------------------------
LoadEmbeddedBackPicFallback:
    mov esi, embedded_backpic
    lea edi, [ebp + PIC_STAGE]
    mov ecx, embedded_backpic_len
    rep movsb
    mov word [ebp + wSpriteInputPtr], PIC_STAGE
    mov byte [ebp + wSpriteFlipped], 0     ; player back pic is not mirrored
    mov edx, GB_VCHARS2 + 0x31 * 16        ; VRAM $9310 -> signed tile ID $31
    call LoadMonBackPicToVRAM              ; decode → VRAM only; the slide-in places it
    ret


; ---------------------------------------------------------------------------
; DebugLoadEmbeddedTrainerPic — DEBUG-HARNESS ONLY. Decodes the Bug Catcher trainer
; sprite (7x7 front-style, not scaled) to the enemy pic VRAM ($00) for the
; trainer-battle test. The production path is pret _LoadTrainerPic indexing the
; generated TrainerPicPointers[class-1]; this is reached only from
; src/debug/debug_dump.asm.
;
; Port-only by design: deliberately UNFAITHFUL (one hardcoded trainer class), so it
; takes a descriptive port-only name rather than pret's _LoadTrainerPic. Not a STUB
; -- it stands in for nothing at link time.
; ---------------------------------------------------------------------------
DebugLoadEmbeddedTrainerPic:
    mov esi, embedded_bugcatcher
    lea edi, [ebp + PIC_STAGE]
    mov ecx, embedded_bugcatcher_len
    rep movsb
    mov word [ebp + wSpriteInputPtr], PIC_STAGE
    mov byte [ebp + wSpriteFlipped], 0
    mov al, [embedded_bugcatcher]          ; dims byte (7x7)
    mov edx, GB_VCHARS2                     ; VRAM $9000 -> tile ID $00
    call LoadMonPicToVRAM
    ret

; ---------------------------------------------------------------------------
; SlideBattlePicsIn — the silhouette slide-in (port of pret SlidePlayerAndEnemy-
; SilhouettesOnScreen, done software-native: pret's per-scanline SCX raster trick
; isn't expressible in the tile renderer). Both already-decoded pics (enemy front at
; VRAM tile $00, player back at $31) slide in from the screen edges over the cleared
; canvas, DARKENED via a silhouette BGP (color 0→light, 1-3→dark), then the palette
; restores to normal at the final position. The caller draws the box/HUD/pokéballs
; after. In: pics decoded to VRAM; EBP = GB base.
; ---------------------------------------------------------------------------
; PROJ battle: step count derived from the layout pic columns (generated)
%define SLIDE_STEPS     UI_BATTLE_SLIDE_STEPS
%define BGP_SILHOUETTE  0xFC            ; color 0→0 (light), 1/2/3→3 (dark)
%define BGP_NORMAL      0xE4

SlideBattlePicsIn:
    ; pret's SET_PAL_BATTLE_BLACK swaps all active CGB slots to PAL_BLACK.
    call SetPal_BattleBlack
    mov byte [ebp + IO_BGP], BGP_SILHOUETTE
    mov dword [slide_step], SLIDE_STEPS
.loop:
    lea edi, [ebp + W_TILEMAP]              ; clear the canvas each frame
    mov al, T_SP
    mov ecx, SCREEN_TILES_W * SCREEN_TILES_H
    rep stosb
    ; PROJ battle: final pic positions = UI_ENEMY_PIC / UI_PLAYER_PIC
    mov edx, [slide_step]                   ; enemy front: col (final + step), base $00
    add edx, UI_ENEMY_PIC_COL
    mov ebx, UI_ENEMY_PIC_ROW
    xor esi, esi
    call PlacePicSlide
    mov edx, UI_PLAYER_PIC_COL              ; player back: col (final - step), base $31
    sub edx, [slide_step]
    mov ebx, UI_PLAYER_PIC_ROW
    mov esi, 0x31
    call PlacePicSlide
    call DelayFrame
    call DelayFrame
    dec dword [slide_step]
    jns .loop
    call SetPal_Battle
    mov byte [ebp + IO_BGP], BGP_NORMAL     ; un-darken at the final position
    ret

; PlacePicSlide — place a 7x7 pic block clipped to the canvas. ESI=base tile id,
; EDX=signed left canvas col, EBX=top canvas row. Off-screen columns are skipped
; (tile IDs still advance, column-major like PlacePicTilemap). Preserves EDX/EBX/ESI.
PlacePicSlide:
    xor ecx, ecx                            ; column index 0..6
.col:
    mov eax, edx
    add eax, ecx                            ; canvas column (signed)
    js .next                                ; off the left edge
    cmp eax, SCREEN_TILES_W
    jge .next                               ; off the right edge
    push eax
    push ecx
    mov edi, ebx
    imul edi, edi, SCREEN_TILES_W
    add edi, eax                            ; W_TILEMAP offset = row*40 + col
    mov eax, ecx
    imul eax, eax, 7
    add eax, esi                            ; tile id = base + colindex*7
    mov ecx, 7                              ; 7 rows
.row:
    mov [ebp + edi + W_TILEMAP], al
    add edi, SCREEN_TILES_W
    inc eax
    dec ecx
    jnz .row
    pop ecx
    pop eax
.next:
    inc ecx
    cmp ecx, 7
    jb .col
    ret

; ---------------------------------------------------------------------------
section .data
align 4
embedded_pic:
    incbin "../gfx/pokemon/front/pidgey.pic"
embedded_pic_len equ $ - embedded_pic
embedded_backpic:
    incbin "../gfx/pokemon/back/pikachub.pic"
embedded_backpic_len equ $ - embedded_backpic
embedded_bugcatcher:
    incbin "../gfx/trainers/bugcatcher.pic"    ; Bug Catcher trainer (test-trainer sprite)
embedded_bugcatcher_len equ $ - embedded_bugcatcher

; ---------------------------------------------------------------------------
section .bss
align 4
pic_dest:       resd 1                 ; merge destination VRAM GB addr
hSpriteWidth:   resb 1                 ; tiles
hSpriteHeight:  resb 1                 ; bytes (tiles*8)
hSpriteOffset:  resb 1                 ; centering offset, bytes
pic_dims:       resb 1
slide_step:     resd 1                 ; SlideBattlePicsIn step counter
pic_repaint_index: resd 1              ; dex-1, for the generated front-repaint table
repaint_blob:   resd 1
repaint_grid:   resd 1
repaint_x:      resb 1
repaint_y:      resb 1
repaint_width:  resb 1
repaint_height: resb 1
repaint_x_offset: resb 1
repaint_y_offset: resb 1
repaint_active: resb 1
