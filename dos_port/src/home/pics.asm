; pics.asm — mon-pic merge + placement pipeline (Wave 2, Stage 1c-ii).
;
; Source: home/pics.asm (pret/pokeyellow): LoadUncompressedSpriteData,
;   AlignSpriteDataCentered, ZeroSpriteBuffer, InterlaceMergeSpriteBuffers.
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
%define PIC_STAGE  0xA4A0               ; GB scratch for the compressed input stream
                                        ; (free SRAM just past sSpriteBuffer2 $A498)

extern UncompressSpriteData
extern g_tilecache_dirty
extern DelayFrame
extern dmg_palette
extern IndexToPokedex             ; flat dex table (pokemon_data.asm): [species-1] -> dex#
extern text_row_stride            ; text/text.asm — active W_TILEMAP row stride (20/40)
global SlideBattlePicsIn

global LoadMonPicToVRAM
global LoadMonBackPicToVRAM
global PlacePicTilemap
global CopyUncompressedPicToHL          ; shared flip-aware 7×7 tilemap placement

; --- mon front-pic dispatch (M6.3, faithful port of home/pokemon.asm + home/pics.asm) ---
global LoadFrontSpriteByMonIndex
global LoadFlippedFrontSpriteByMonIndex
global LoadMonFrontSprite
global UncompressMonSprite

; --- debug-harness-only stubs (DEBUG_BATTLE / debug_dump.asm); superseded by the
;     dispatch above once the MonFrontPics table is staged — see M6.3 SUMMARY ---
global DrawEnemyFrontPic_Stub
global DrawPlayerBackPic_Stub
global DrawPlayerRedBackPic_Stub
global DrawBugCatcherPic_Stub

; MonFrontPics: Tier-1 GENERATED table (dex order, 151 records of {dd flatptr, dd len})
; pointing at the incbin'd compressed front .pic blobs. Build with -D MON_FRONT_PICS
; once tools/gen_mon_pics.py + assets/mon_pics.inc + src/data/mon_pics.asm land and
; src/data/mon_pics.asm is added to the link set. See M6.3 SUMMARY "data follow-up".
%ifdef MON_FRONT_PICS
extern MonFrontPics
extern MonBackPics                ; dex-ordered back sprites (LoadMonBackPic); same gen/gate
%endif
global LoadMonBackPic             ; generic player send-out back pic (retires DrawPlayerBackPic_Stub)

; pret constants not carried in gb_constants.inc:
;   RHYDON = internal index $01 (constants/pokemon_constants.asm)
;   NUM_POKEMON = 151          (constants/pokedex_constants.asm)
%define RHYDON        0x01
%define NUM_POKEMON   151

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
; ScaleSpriteByTwo — scale both 4x4-tile chunks 2x into 7x7 chunks (2x2 output
; pixels per input pixel; rightmost/bottommost 4 px ignored). Source: pret
; engine/battle/scale_sprites.asm. chunk1(buffer1)->buffer0, chunk2(buffer2)->buffer1.
; ---------------------------------------------------------------------------
ScaleSpriteByTwo:
    mov edx, sSpriteBuffer1 + (4*4*8) - 5    ; last input byte (last 4 rows pre-skipped)
    mov esi, sSpriteBuffer0 + SPRITEBUFFERSIZE - 1
    call ScaleLastSpriteColumnByTwo          ; last tile column is a special case
    call ScaleFirstThreeSpriteColumnsByTwo
    mov edx, sSpriteBuffer2 + (4*4*8) - 5
    mov esi, sSpriteBuffer1 + SPRITEBUFFERSIZE - 1
    call ScaleLastSpriteColumnByTwo
    call ScaleFirstThreeSpriteColumnsByTwo
    ret

; In: EDX = source (read backward), ESI = dest (written backward).
ScaleFirstThreeSpriteColumnsByTwo:
    mov bh, 3                          ; 3 tile columns
.column:
    mov bl, 4*8 - 4                    ; 0x1c — 4 tiles minus 4 unused rows
.inner:
    push ebx
    mov al, [ebp + edx]
    mov bx, -(7*8) + 1                 ; scale low nybble, seek to previous output column
    call ScalePixelsByTwo
    mov al, [ebp + edx]
    dec dx
    rol al, 4                          ; swap a
    mov bx, 7*8 + 1 - 2                ; scale high nybble, seek back + to next 2 rows
    call ScalePixelsByTwo
    pop ebx
    dec bl
    jnz .inner
    sub dx, 4                          ; skip 4 unused rows of the input column
    mov al, bh
    mov bx, -7*8                       ; skip the already-written output column
    add si, bx
    mov bh, al
    dec bh
    jnz .column
    ret

; In: EDX = source, ESI = dest. Only the high nybble of each input byte is used.
ScaleLastSpriteColumnByTwo:
    mov byte [hSpriteScaleCtr], 4*8 - 4
.inner:
    mov al, [ebp + edx]
    dec dx
    rol al, 4                          ; swap a — high nybble holds the info
    mov bx, -1
    call ScalePixelsByTwo
    dec byte [hSpriteScaleCtr]
    jnz .inner
    sub dx, 4
    ret

; ScalePixelsByTwo — scale the low 4 bits of AL (4x1 px) to 2 output bytes (8x2 px):
; write DuplicateBitsTable[AL&0xf] to [ESI] and [ESI-1], then ESI += BX (signed).
; In: AL = byte, ESI = dest (hl), BX = signed offset (bc). Clobbers EAX, ECX.
ScalePixelsByTwo:
    push esi
    and al, 0x0f
    movzx ecx, al
    mov al, [DuplicateBitsTable + ecx]
    pop esi
    mov [ebp + esi], al                ; write byte twice (2 px tall)
    dec si
    mov [ebp + esi], al
    add si, bx                         ; advance dest by offset
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
; LoadFrontSpriteByMonIndex / LoadFlippedFrontSpriteByMonIndex
; Source: home/pokemon.asm (pret/pokeyellow). Faithful internal-index -> national-
; dex -> Rhydon-trap -> front-pic path, doing BOTH halves pret does: decode the pic
; to VRAM (fixed vFrontPic = $9000) AND place the 7×7 tile block on the tilemap at
; the caller's coord (pret tail-calls CopyUncompressedPicToHL). The flipped entry
; mirrors the pic in X (Pokédex / status / league-PC / evolution / trade / Oak /
; printer callers). Callers just set the tilemap coord and call — exactly like pret
; (hlcoord X,Y / call LoadFlippedFrontSpriteByMonIndex); no separate placement step.
; In:  [wCurPartySpecies] = internal species index; ESI = tilemap dest (GB flat
;      offset, i.e. hlcoord/scoord — the pret HL). Stride comes from text_row_stride.
; Out: pic decoded to $9000 AND placed 7×7 at ESI (flip-aware); [wSpriteFlipped]
;      cleared. Invalid dex -> "Rhydon trap": [wCurPartySpecies] = RHYDON, nothing
;      drawn (https://glitchcity.wiki/wiki/Rhydon_trap).
; ---------------------------------------------------------------------------
LoadFlippedFrontSpriteByMonIndex:
    mov byte [ebp + wSpriteFlipped], 1
    jmp LoadFrontSpriteByMonIndex.body
LoadFrontSpriteByMonIndex:
    mov byte [ebp + wSpriteFlipped], 0
.body:
    push esi                                ; preserve tilemap dest (pret: push hl)
    ; dex = IndexToPokedex[wCurPartySpecies - 1]   (internal index -> national dex)
    movzx eax, byte [ebp + wCurPartySpecies]
    dec eax
    movzx eax, byte [IndexToPokedex + eax]
    and al, al
    jz .invalidDexNumber                    ; dex #0 invalid
    cmp al, NUM_POKEMON + 1
    jae .invalidDexNumber                   ; dex > #151 invalid (unsigned)
    ; valid dex (1..151)
    dec eax                                  ; dex-1 = index into MonFrontPics
    mov edx, GB_VCHARS2                       ; VRAM dest FIXED = vFrontPic ($9000)
    call LoadMonFrontSprite                  ; stage + decode + center/merge -> $9000
    ; --- place the 7×7 tile block at the caller's coord (pret: pop hl / xor a /
    ;     ldh [hStartTileID],a / call CopyUncompressedPicToHL). Stride from the
    ;     runtime text_row_stride (20 menu scratch / 40 flat canvas) — the port's
    ;     one divergence from pret's constant SCREEN_WIDTH. -----------------------
    pop esi                                  ; restore tilemap dest (pret: pop hl)
    lea edi, [ebp + esi]                     ; full pointer for the placement
    xor al, al                               ; hStartTileID = 0
    mov edx, [text_row_stride]
    call CopyUncompressedPicToHL             ; flip-aware, reads [wSpriteFlipped]
    mov byte [ebp + wSpriteFlipped], 0       ; pret clears the flip flag AFTER placement
    ret
.invalidDexNumber:
    ; Rhydon trap — fail-safe invalid dex numbers to RHYDON (pret .invalidDexNumber)
    add esp, 4                               ; discard the saved dest (nothing drawn)
    mov byte [ebp + wCurPartySpecies], RHYDON
    ret

; ---------------------------------------------------------------------------
; CopyUncompressedPicToHL — port of engine/battle/init_battle.asm
; CopyUncompressedPicToHL. Write a 7×7 block of ascending tile ids into the
; tilemap, column-major (id runs down each column, then to the next column),
; flip-aware: when [wSpriteFlipped] is set the columns are laid RIGHT-TO-LEFT so
; the internally-mirrored front-pic tiles complete the horizontal flip (pret's
; `.flipped` branch). This is the ONE shared placement pret tail-calls from
; LoadFrontSpriteByMonIndex; the port splits VRAM-decode (LoadMonFrontSprite,
; done separately) from this tilemap step and re-strides it per caller.
;
; PORT SPLIT NOTE: pret's LoadFrontSpriteByMonIndex clears [wSpriteFlipped] only
; AFTER tail-calling this routine, so the flip flag is still live here. The port's
; LoadF[lipped]FrontSpriteByMonIndex clears it at the end of the VRAM decode, so a
; flipped caller must RE-ASSERT [wSpriteFlipped]=1 immediately before calling this.
;
; In:  EDI = dest tilemap flat address (caller has already added EBP)
;      EDX = row stride in bytes (20 = menu scratch, 40 = battle/status canvas)
;      AL  = start tile id (hStartTileID; 0 for front pics)
;      [ebp + wSpriteFlipped] = 1 flipped (R→L cols) / 0 normal (L→R cols)
; Out: 7×7 tile ids placed. Clobbers EAX, EBX, ECX, EDI. Preserves EDX, ESI.
; ---------------------------------------------------------------------------
CopyUncompressedPicToHL:
    cmp byte [ebp + wSpriteFlipped], 0
    jne .flipped
    mov ebx, 7                               ; 7 columns, left to right
.col:
    push edi
    mov ecx, 7                               ; 7 rows, top to bottom
.row:
    mov [edi], al
    add edi, edx                             ; down one row
    inc al                                   ; id ascends column-major
    dec ecx
    jnz .row
    pop edi
    inc edi                                  ; next column to the RIGHT
    dec ebx
    jnz .col
    ret
.flipped:
    add edi, 6                               ; start at the rightmost column
    mov ebx, 7
.fcol:
    push edi
    mov ecx, 7
.frow:
    mov [edi], al
    add edi, edx
    inc al
    dec ecx
    jnz .frow
    pop edi
    dec edi                                  ; next column to the LEFT
    dec ebx
    jnz .fcol
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
    call UncompressMonSprite                  ; stage blob + decode chunks into buffers
    mov al, [pic_dims]
    jmp LoadUncompressedSpriteData            ; center each chunk + interlace -> VRAM

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
    ; ships (tools/gen_mon_pics.py → assets/mon_pics.inc + src/data/mon_pics.asm),
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
; DrawEnemyFrontPic_Stub — STAGE-1c TEST STOPGAP. Stages an embedded pic, decodes
; + merges it to VRAM $9000, and places it top-right on the battle canvas.
; The real path (Stage 2/3) reads the enemy species -> a pic-pointer table and
; loads the matching pic; this hard-codes one mon so the decode/merge/placement
; can be visually gated now. Called from the DEBUG_BATTLE harness, not InitBattle.
; ---------------------------------------------------------------------------
DrawEnemyFrontPic_Stub:
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
; DrawPlayerBackPic_Stub — STAGE-1c TEST STOPGAP (see DrawEnemyFrontPic_Stub).
; Stages an embedded back pic, decodes + scales + merges it to VRAM $9310, and
; places it bottom-left. Real path (Stage 2/3): from the player's party species.
; ---------------------------------------------------------------------------
DrawPlayerBackPic_Stub:
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
; LoadMonBackPic — decode the SENT-OUT player mon's back sprite to vBackPic ($9310).
; The generic replacement for DrawPlayerBackPic_Stub (which hardcoded PIKACHU).
; pret: engine/battle/core.asm LoadMonBackPic — sets wCurPartySpecies from
; wBattleMonSpecies2, UncompressMonSprite from the mon header's BACK-sprite pointer,
; ScaleSpriteByTwo, InterlaceMergeSpriteBuffers → vBackPic. The port has no header
; sprite pointer (flat model): index the generated MonBackPics table by dex-1 (the
; same species→dex path LoadFrontSpriteByMonIndex uses for MonFrontPics), stage the
; blob, and reuse LoadMonBackPicToVRAM (decode + 2x scale + merge). All 151 back pics
; are 4x4 ($44), which is exactly what ScaleSpriteByTwo expects.
; In: [wBattleMonSpecies2] = the sent-out mon's internal species index. EBP = GB base.
; ---------------------------------------------------------------------------
LoadMonBackPic:
%ifdef MON_FRONT_PICS
    mov al, [ebp + wBattleMonSpecies2]
    mov [ebp + wCurPartySpecies], al           ; pret: ld [wCurPartySpecies], a
    ; species → national dex − 1 (IndexToPokedex is the flat table, NOT a routine)
    movzx eax, al
    dec eax
    movzx eax, byte [IndexToPokedex + eax]     ; dex number (1-based)
    dec eax                                    ; dex−1 = MonBackPics record index
    ; stage MonBackPics[dex−1] (record = { dd flatptr, dd len }) into GB scratch
    lea esi, [MonBackPics + eax*8]
    mov ecx, [esi + 4]                          ; blob length
    mov esi, [esi]                              ; flat ptr to the compressed back .pic
    lea edi, [ebp + PIC_STAGE]
    rep movsb
    mov word [ebp + wSpriteInputPtr], PIC_STAGE
    mov byte [ebp + wSpriteFlipped], 0         ; back pic is not mirrored
    mov edx, GB_VCHARS2 + 0x31 * 16            ; vBackPic dest (signed tile ID $31)
    jmp LoadMonBackPicToVRAM                    ; decode → 2x scale → merge to VRAM
%else
    ; no MonBackPics table in a no-data build: fall back to the embedded stub pic.
    jmp DrawPlayerBackPic_Stub
%endif

; ---------------------------------------------------------------------------
; DrawPlayerRedBackPic_Stub — decode the PLAYER (Red/Yellow) back sprite to the
; player pic VRAM ($31). This is the sprite that slides in on the player's side at
; battle start (pret LoadPlayerBackPic → RedPicBack); the mon's back pic replaces it
; only after the player sends a mon out. Scaled like a mon back (LoadMonBackPicToVRAM).
; ---------------------------------------------------------------------------
DrawPlayerRedBackPic_Stub:
    mov esi, embedded_redback
    lea edi, [ebp + PIC_STAGE]
    mov ecx, embedded_redback_len
    rep movsb
    mov word [ebp + wSpriteInputPtr], PIC_STAGE
    mov byte [ebp + wSpriteFlipped], 0
    mov edx, GB_VCHARS2 + 0x31 * 16        ; VRAM $9310 -> tile ID $31
    call LoadMonBackPicToVRAM
    ret

; ---------------------------------------------------------------------------
; DrawBugCatcherPic_Stub — decode the Bug Catcher trainer sprite (7x7 front-style,
; not scaled) to the enemy pic VRAM ($00), for the trainer-battle test. The real
; path indexes TrainerPicPointers[class-1] (generated) — Stage 4.
; ---------------------------------------------------------------------------
DrawBugCatcherPic_Stub:
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
    ; TODO(palette): the faithful silhouette is pret's CGB SET_PAL_BATTLE_BLACK (the
    ; whole CGB palette → black), which belongs to the Phase-5 GBC palette work. For
    ; now, force the darkest DMG shade to true black during the slide so every non-
    ; transparent pic pixel (BGP maps colors 1-3 → shade 3) renders as a black
    ; silhouette instead of the dark-green shade-3. Not game-accurate; acceptable stopgap.
    mov al, [dmg_palette + 9]                ; save shade-3 RGB (3 bytes)
    mov [slide_pal_save + 0], al
    mov al, [dmg_palette + 10]
    mov [slide_pal_save + 1], al
    mov al, [dmg_palette + 11]
    mov [slide_pal_save + 2], al
    mov byte [dmg_palette + 9], 0            ; shade 3 → black (R,G,B = 0)
    mov byte [dmg_palette + 10], 0
    mov byte [dmg_palette + 11], 0
    mov byte [ebp + IO_BGP], BGP_SILHOUETTE
    mov byte [g_tilecache_dirty], 1
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
    mov al, [slide_pal_save + 0]            ; restore shade-3 RGB
    mov [dmg_palette + 9], al
    mov al, [slide_pal_save + 1]
    mov [dmg_palette + 10], al
    mov al, [slide_pal_save + 2]
    mov [dmg_palette + 11], al
    mov byte [ebp + IO_BGP], BGP_NORMAL     ; un-darken at the final position
    mov byte [g_tilecache_dirty], 1
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
embedded_redback:
    incbin "../gfx/player/redb.pic"            ; player (Red/Yellow) back sprite
embedded_redback_len equ $ - embedded_redback
embedded_bugcatcher:
    incbin "../gfx/trainers/bugcatcher.pic"    ; Bug Catcher trainer (test-trainer sprite)
embedded_bugcatcher_len equ $ - embedded_bugcatcher

; repeats each input bit twice, e.g. DuplicateBitsTable[%0101] = %00110011
DuplicateBitsTable:
    db 0x00, 0x03, 0x0C, 0x0F, 0x30, 0x33, 0x3C, 0x3F
    db 0xC0, 0xC3, 0xCC, 0xCF, 0xF0, 0xF3, 0xFC, 0xFF

; ---------------------------------------------------------------------------
section .bss
align 4
pic_dest:       resd 1                 ; merge destination VRAM GB addr
hSpriteWidth:   resb 1                 ; tiles
hSpriteHeight:  resb 1                 ; bytes (tiles*8)
hSpriteOffset:  resb 1                 ; centering offset, bytes
hSpriteScaleCtr: resb 1                ; ScaleLastSpriteColumnByTwo inner counter
pic_dims:       resb 1
slide_step:     resd 1                 ; SlideBattlePicsIn step counter
slide_pal_save: resb 3                 ; saved dmg_palette shade-3 RGB during the slide
