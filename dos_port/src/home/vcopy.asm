; dos_port/src/home/vcopy.asm
; ============================================================
; Mirror of pret home/vcopy.asm — the BG-map / BG-animation VBlank family.
; Holds, in pret order: ClearBgMap, FillBgMap, RedrawRowOrColumn,
; VBlankCopyBgMap, VBlankCopy, UpdateMovingBgTiles, FlowerTile1/2/3.
;
; This file previously held CopyString and IsInRestOfArray under a "home util
; bucket" header. Those are home/copy_string.asm and home/array2.asm labels and
; now live in their own mirrors (src/home/copy_string.asm, src/home/array2.asm);
; the BG family arrived here from src/video/bg_anim.asm (deleted) and
; src/home/lcd.asm (which keeps DisableLCD / EnableLCD).
;
; THE FILE IS NOW COMPLETE. GetRowColAddressBgMap, FillBgMapCommon,
; AutoBgMapTransfer, TransferBgRows and VBlankCopyDouble used to be absent, under
; a note saying the port's renderer never scans the GB $9800 BG map so that half
; of the file "has never been needed". The renderer fact is still true; the
; conclusion was the maintainer's open question of 2026-08-23, and the answer is
; the same one the eight overworld VRAM-torus routines got in d7d72f8d7: a
; genuinely portable pret routine is ported for completeness even when unlinked.
;
; MEASURED before porting, per label:
;   AutoBgMapTransfer   pret's only caller is home/vblank.asm; the port's VBlank
;                       pipeline (src/home/vblank.asm) does not call it. Its
;                       output is the $9800 BG map, which render_bg never reads.
;                       hAutoBGTransferEnabled IS written faithfully all over the
;                       port, so the GATE byte is live — nothing consumes it.
;   TransferBgRows      reached only from AutoBgMapTransfer and VBlankCopyBgMap.
;   VBlankCopyDouble    armed in pret by home/copy2.asm:CopyVideoDataDouble via
;                       hVBlankCopyDoubleSize + DelayFrame. The port's
;                       CopyVideoDataDouble (src/home/copy2.asm:116) does the
;                       1bpp->2bpp expansion SYNCHRONOUSLY and never writes that
;                       HRAM byte, so this can never be armed here.
;   GetRowColAddressBgMap  pret's only caller is home/copy2.asm's
;                       CopyScreenTileBufferToVRAM `.setup`; the port's
;                       CopyScreenTileBufferToVRAM (copy2.asm:284) is three
;                       DelayFrames and drops the arming entirely.
;   FillBgMapCommon     the ONE exception — it has a live consumer here, because
;                       ClearBgMap and FillBgMap were ported with the shared body
;                       INLINED instead of shared. It is now the shared body they
;                       fall through into, which is pret's own shape.
; So four are unreached mirrors and one is wired. label_status --callers reported
; 0 port callers for all five before this change.
;
; -- Renderer-integrity notes (this port diverges hard from GB geometry) ------
; The DOS port's native renderer (src/ppu/ppu.asm:render_bg) does NOT scan the
; GB's 32x32 BG tilemap at $9800; it decodes the 44x32 `wSurroundingTiles`
; surface / the 40x25 wTileMap via `tile_cache`. Consequences honoured here:
;
;  * UpdateMovingBgTiles mutates tile PATTERN bytes in vChars/vTileset ($9000
;    region). That path DOES feed the renderer through `tile_cache`, so after
;    mutating pattern bytes we set `g_tilecache_dirty` (per CLAUDE.md) to force a
;    re-decode. Addresses are the *pattern* addresses (vTileset tile $14/$03),
;    never the 44x32 surface, and stride never assumes 32-wide geometry.
;
;  * VBlankCopyBgMap copies into the GB BG-map region addressed by
;    hVBlankCopyBGDest (a $9800-style pointer the caller supplies), exactly like
;    the existing do_bg_transfer (vblank.asm) writes the physical GB tilemap.
;    In this port that region is vestigial/unread by render_bg, so a faithful
;    copy there is harmless. The per-row width is the GB-faithful 20 tiles with a
;    32-wide stride -- hardcoded below, NOT the port's redefined SCREEN_WIDTH
;    (which is 40 for the extended viewport).
;
; Both VBlank routines SELF-GATE at their top on their arming byte, so an
; unconditional `call` from the DelayFrame pipeline is always correct: when the
; gate is unarmed the routine is a no-op `ret`. In the current build NOTHING arms
; either gate (all HRAM boots to 0), so both are inert.
;
; Build: nasm -f coff -I include/ -I . -o vcopy.o vcopy.asm

bits 32

%include "gb_memmap.inc"

; ── ROOT-INTEGRATION: relocate these to dos_port/include/gb_memmap.inc ───────
; These HRAM/WRAM symbols are not yet in gb_memmap.inc. Addresses verified from
; pret ram/hram.asm + ram/wram.asm sequential layout (chain lands exactly on the
; already-present hTileAnimations=0xFFD7). Once root adds them to gb_memmap.inc,
; DELETE this whole block (nasm `equ` cannot be %ifndef-guarded, so leaving both
; a memmap def and this local def would be a redefinition error).
; ── end ROOT-INTEGRATION block ──────────────────────────────────────────────

; GB-faithful BG-map geometry for VBlankCopyBgMap. Hardcoded on purpose: the
; port's SCREEN_WIDTH is redefined to 40 (extended viewport), but pret's
; VBlankCopyBgMap copies GB SCREEN_WIDTH(=20) tiles per row into a GB
; TILEMAP_WIDTH(=32)-wide map. Using the port's SCREEN_WIDTH here would copy 40
; bytes/row and overflow the 32-wide row.
GB_BG_ROW_TILES          equ 20        ; pret SCREEN_WIDTH  — tiles copied per row
GB_BG_STRIDE             equ 32        ; pret TILEMAP_WIDTH — dest bytes per row
; Same reasoning for AutoBgMapTransfer, which slices wTileMap into thirds by GB
; rows. See stigmergy [[redraw-ring-gb-geometry-contract]]: substituting the
; port's SCREEN_HEIGHT(25) here would slice 8-row thirds out of a buffer pret
; addresses in 6-row thirds, and address rows 18-24 that the GB map has no room
; for. GB geometry, always.
GB_SCREEN_HEIGHT         equ 18        ; pret SCREEN_HEIGHT — rows in the GB view

; vTileset ($9000) animated pattern-tile addresses (GB_VCHARS2 = vTileset).
; The tile IDs are shared (gb_memmap.inc) so screens that load their own graphics
; into vTileset can assert they don't overlap what this routine rewrites.
WATER_TILE_ADDR          equ GB_VCHARS2 + ANIM_WATER_TILE_ID * TILE_SIZE   ; $9140 (tile $14)
FLOWER_TILE_ADDR         equ GB_VCHARS2 + ANIM_FLOWER_TILE_ID * TILE_SIZE  ; $9030 (tile $03)

extern g_tilecache_dirty        ; src/ppu/ppu.asm — arm cache re-decode after vChars write

global GetRowColAddressBgMap
global ClearBgMap
global FillBgMap
global FillBgMapCommon
global RedrawRowOrColumn
global AutoBgMapTransfer
global TransferBgRows
global VBlankCopyBgMap
global VBlankCopyDouble
global VBlankCopy
global UpdateMovingBgTiles

section .text

; ---------------------------------------------------------------------------
; GetRowColAddressBgMap — pret home/vcopy.asm:4, the file's first label.
; Converts a wTileMap coordinate into the matching BG-map address.
;
; In:  ESI (HL) = wTileMap coordinate, BH (B) = high byte of the BG map base
; Out: ESI (HL) = BG map address. AL clobbered, exactly as pret clobbers A.
;
; pret shifts H right three times, catching each shifted-out bit in A through the
; carry (`srl h` / `rr a`), so A ends holding H's low 3 bits in its TOP 3 bits —
; i.e. HL is divided by 8 with the remainder re-joined at the low end via `or l`.
; x86 `shr r8, 1` sets CF from the bit shifted out and `rcr r8, 1` rotates it in
; through CF, so the pair maps one-for-one. Nothing may touch CF between them.
;
; UNREACHED here, and measured: pret's only caller is home/copy2.asm's
; CopyScreenTileBufferToVRAM `.setup`, which arms hVBlankCopyBGDest for the three
; screen thirds; the port's CopyScreenTileBufferToVRAM drops that arming because
; render_bg never scans the $9800 map. See the file header.
; ---------------------------------------------------------------------------
GetRowColAddressBgMap:
    push ecx
    mov cx, si                          ; CH = H, CL = L
    xor al, al                          ; xor a
    shr ch, 1                           ; srl h
    rcr al, 1                           ; rr a
    shr ch, 1                           ; srl h
    rcr al, 1                           ; rr a
    shr ch, 1                           ; srl h
    rcr al, 1                           ; rr a
    or  al, cl                          ; or l
    mov cl, al                          ; ld l, a
    mov al, bh                          ; ld a, b
    or  al, ch                          ; or h
    mov ch, al                          ; ld h, a
    movzx esi, cx
    pop ecx
    ret

; ---------------------------------------------------------------------------
; ClearBgMap — fill a BG tilemap (TILEMAP_AREA bytes) with the blank tile ($7F).
; In:  ESI = tilemap base offset (GB_TILEMAP0 or GB_TILEMAP1)
; Out: all registers preserved.
; ---------------------------------------------------------------------------
ClearBgMap:
    push eax
    mov al, 0x7F                        ; ld a, ' '
    call FillBgMapCommon                ; jr FillBgMapCommon
    ; pret CLOBBERS A here and lets the tail `ret` out of FillBgMapCommon return
    ; to its caller. The port's entry contract for this routine has always been
    ; "all registers preserved", and callers were written against it, so the
    ; push/pop/call stays. The target is now pret's, which is what the shape
    ; actually asserted.
    pop eax
    ret

; ---------------------------------------------------------------------------
; FillBgMap — fill a BG tilemap with tile AL.
; In:  ESI = tilemap base offset, AL = tile index
; Out: all registers preserved.
; ---------------------------------------------------------------------------
FillBgMap:
    ; pret is `FillBgMap:: ld a, l` — it takes the tile index in L and moves it to
    ; A before falling through. The port's entry contract already delivers the
    ; tile in AL (ESI is the base offset, not a value), so there is nothing to
    ; move and the label is a pure entry point onto the shared body below. That
    ; contract predates this change and is unchanged by it.
    ; fall through

; ---------------------------------------------------------------------------
; FillBgMapCommon — pret home/vcopy.asm:30. The shared fill body ClearBgMap and
; FillBgMap both reach (pret: `ClearBgMap: ld a,' ' / jr FillBgMapCommon`, and
; FillBgMap falls through). The port had this body INLINED into FillBgMap with no
; label, which is why the name read `missing`; it is now shared, as in pret.
;
; In:  ESI = tilemap base offset, AL = tile index. Out: all registers preserved.
;
; pret walks the area with a nested `dec e` / `dec d` pair over
; `ld de, TILEMAP_AREA` — 4 x 256 bytes. `rep stosb` over the same constant count
; is identical: TILEMAP_AREA is a fixed 1024, so the degenerate zero-count case
; the counter-width rule warns about cannot arise here.
; ---------------------------------------------------------------------------
FillBgMapCommon:
    push ecx
    push edi
    lea edi, [ebp + esi]
    mov ecx, TILEMAP_AREA
    rep stosb
    pop edi
    pop ecx
    ret

; ═══════════════════════════════════════════════════════════════════════════
; RedrawRowOrColumn — redraw a BG row of height 2 or a BG column of width 2.
; pret ref: home/vcopy.asm:RedrawRowOrColumn
;
; Copies tiles from wRedrawRowOrColumnSrcTiles to the GB address in
; hRedrawRowOrColumnDest (mode 1 = column, 2 = row).
; In:  EBP = GB memory base. Out: all registers preserved.
; ═══════════════════════════════════════════════════════════════════════════
RedrawRowOrColumn:
    pushad
    mov al, [ebp + hRedrawRowOrColumnMode]
    test al, al
    jz .done
    mov bl, al
    xor al, al
    mov [ebp + hRedrawRowOrColumnMode], al
    dec bl
    jnz .redrawRow

.redrawColumn:
    mov esi, wRedrawRowOrColumnSrcTiles
    mov dl, [ebp + hRedrawRowOrColumnDest]
    mov dh, [ebp + hRedrawRowOrColumnDest + 1]
    mov cl, 18                           ; SCREEN_HEIGHT (GB)
.loop1:
    mov al, [ebp + esi]
    inc esi
    movzx edi, dx
    mov [ebp + edi], al
    inc dx
    mov al, [ebp + esi]
    inc esi
    movzx edi, dx
    mov [ebp + edi], al
    mov al, 32 - 1                       ; TILEMAP_WIDTH - 1
    add dl, al
    jnc .noCarry
    inc dh
.noCarry:
    ; wrap from bottom to top if necessary (wrap inside 1024-byte vBGMap0 at 0x9800)
    mov al, dh
    and al, 0x03                         ; HIGH(TILEMAP_AREA - 1)
    or al, 0x98                          ; HIGH(vBGMap0)
    mov dh, al
    dec cl
    jnz .loop1
    mov byte [ebp + hRedrawRowOrColumnMode], 0
    popad
    ret

.redrawRow:
    mov esi, wRedrawRowOrColumnSrcTiles
    mov dl, [ebp + hRedrawRowOrColumnDest]
    mov dh, [ebp + hRedrawRowOrColumnDest + 1]
    push dx
    call .DrawHalf                       ; draw upper half
    pop dx
    add dl, 32                           ; TILEMAP_WIDTH
    call .DrawHalf                       ; draw lower half
    popad
    ret

.DrawHalf:
    mov cl, 20 / 2                       ; SCREEN_WIDTH / 2
.loop2:
    mov al, [ebp + esi]
    inc esi
    movzx edi, dx
    mov [ebp + edi], al
    inc dx
    mov al, [ebp + esi]
    inc esi
    movzx edi, dx
    mov [ebp + edi], al
    mov al, dl
    inc al
    ; wrap from right edge to left edge if necessary (wrap within 32-wide row)
    and al, 0x1F                         ; %11111
    mov bl, al
    mov al, dl
    and al, 0xE0                         ; %11100000
    or al, bl
    mov dl, al
    dec cl
    jnz .loop2
    ret

.done:
    popad
    ret

; ═══════════════════════════════════════════════════════════════════════════
; AutoBgMapTransfer — pret home/vcopy.asm:127. Push one THIRD of wTileMap to the
; BG map each V-blank, rotating top -> middle -> bottom via hAutoBGTransferPortion.
;
; UNREACHED here, and measured: pret's only caller is home/vblank.asm, and the
; port's VBlank pipeline does not call it. hAutoBGTransferEnabled is written
; faithfully by ~40 port routines, so the GATE is live — nothing consumes it, and
; the $9800 BG map it writes is never scanned by render_bg. Ported for label
; completeness under the same rule as the overworld torus ring (d7d72f8d7).
;
; GEOMETRY IS GB, NOT PORT. The thirds are GB_SCREEN_HEIGHT/3 = 6 rows of
; GB_BG_ROW_TILES = 20, into a GB_BG_STRIDE = 32 map. The port's SCREEN_WIDTH is
; 40 and SCREEN_HEIGHT 25; using them here would slice the wrong rows and overrun
; the row. See [[redraw-ring-gb-geometry-contract]].
;
; pret saves SP and uses `ld sp, hl` + `pop de` purely as a fast 2-byte reader.
; That is an SM83 speed trick with no x86 counterpart and no observable effect —
; the port reads the source through ESI and never touches ESP, so hSPTemp is not
; written. Same treatment VBlankCopyBgMap and VBlankCopy already give it.
;
; In:  EBP = GB memory base.
; Out: CLOBBERS EAX/EBX/EDX/ESI — deliberately, because pret clobbers a, b, de,
;      hl and sp here and its caller (home/vblank.asm) is what saves them. The two
;      VBlank routines below this one wrap themselves in pushad instead; that is a
;      pre-existing port choice, not a pattern to extend, and copying it here would
;      have cost the fallthrough into TransferBgRows that pret's shape depends on.
;      Anyone wiring this into the DelayFrame pipeline must save registers at the
;      call site.
; ═══════════════════════════════════════════════════════════════════════════
AutoBgMapTransfer:
    mov al, [ebp + hAutoBGTransferEnabled]
    test al, al
    jz .done                            ; ret z
    mov al, [ebp + hAutoBGTransferPortion]
    test al, al
    jz .transferTopThird
    dec al
    jz .transferMiddleThird
.transferBottomThird:
    mov esi, wTileMap + (2 * GB_SCREEN_HEIGHT / 3) * GB_BG_ROW_TILES  ; hlcoord 0, 12
    movzx edx, word [ebp + hAutoBGTransferDest] ; EDX = dest; DH:DL is the GB pointer.
                                                ; movzx, NOT `mov dx` — every write below
                                                ; is [EBP+EDX], so the upper half must be
                                                ; zero and pushad does not guarantee it.
    add dx, 12 * GB_BG_STRIDE                   ; ld de, 12 * TILEMAP_WIDTH / add hl, de
    xor al, al                                  ; xor a → TRANSFERTOP
    jmp .doTransfer
.transferTopThird:
    mov esi, wTileMap                           ; hlcoord 0, 0
    movzx edx, word [ebp + hAutoBGTransferDest]
    mov al, TRANSFERMIDDLE
    jmp .doTransfer
.transferMiddleThird:
    mov esi, wTileMap + (GB_SCREEN_HEIGHT / 3) * GB_BG_ROW_TILES      ; hlcoord 0, 6
    movzx edx, word [ebp + hAutoBGTransferDest]
    add dx, 6 * GB_BG_STRIDE
    mov al, TRANSFERBOTTOM
.doTransfer:
    mov [ebp + hAutoBGTransferPortion], al      ; store next portion
    mov bl, GB_SCREEN_HEIGHT / 3                ; ld b, SCREEN_HEIGHT / 3
    add esi, ebp                                ; ESI = flat source (pret: ld sp, hl)
    ; fall through into TransferBgRows, exactly as pret does
.done:
    ret

; ═══════════════════════════════════════════════════════════════════════════
; TransferBgRows — pret home/vcopy.asm:171. Copy BL rows of GB_BG_ROW_TILES(20)
; tiles into a GB_BG_STRIDE(32)-wide BG map.
;
; In:  ESI = flat source pointer, BL = row count, EDX = GB dest pointer with its
;      UPPER 16 BITS ZERO (every store is [EBP+EDX]); DH:DL is the pointer proper
; Out: ESI/EDX/EBX advanced; AL clobbered.
;
; THE ROW STEP IS 8-BIT AND THAT IS LOAD-BEARING. pret writes 20 bytes with 19
; `inc l` between them — the 20th byte is written without advancing — and then
; steps with `ld a, TILEMAP_WIDTH - (SCREEN_WIDTH - 1) / add l / ld l, a /
; jr nc / inc h`. So only the row step carries into H, and `inc l` wraps within
; the low byte. `add dl, 13` + `adc dh, 0` reproduces both halves exactly.
; Widening the pointer to 16 bits would change addressing at a page boundary —
; the same trap CopyMapViewToVRAM's `inc dl` documents.
;
; pret's loop is unrolled `pop de` pairs for speed on SM83; the byte SEQUENCE is
; what matters and a plain loop emits the identical one.
; ═══════════════════════════════════════════════════════════════════════════
TransferBgRows:
    mov ecx, GB_BG_ROW_TILES - 1        ; the first 19 bytes each advance L
.byte:
    mov al, [esi]
    inc esi
    mov [ebp + edx], al                 ; ld [hl], e / ld [hl], d
    inc dl                              ; inc l — 8-bit, never carries into H
    dec ecx
    jnz .byte
    mov al, [esi]                       ; the 20th byte: written, no advance
    inc esi
    mov [ebp + edx], al
    add dl, GB_BG_STRIDE - (GB_BG_ROW_TILES - 1)   ; add l  (= +13, net +32/row)
    adc dh, 0                                       ; jr nc / inc h
    dec bl                              ; dec b — 8-bit per the counter-width rule
    jnz TransferBgRows                  ; pret loops on the global label itself
    ret

; ═══════════════════════════════════════════════════════════════════════════
; VBlankCopyBgMap — flush a queued BG-map row copy.
; pret ref: home/vcopy.asm:VBlankCopyBgMap (+ TransferBgRows)
;
; Copies [hVBlankCopyBGNumRows] rows of GB_BG_ROW_TILES(20) tiles from
; hVBlankCopyBGSource to hVBlankCopyBGDest, dest advancing GB_BG_STRIDE(32) per
; row (12-byte pad), then disables the queue by zeroing the source low byte.
;
; Gate: hVBlankCopyBGSource low byte == 0 → ret (pret: the low byte doubles as
; the enable byte; XX00 is an invalid/disabled source). Also short-circuits on
; NumRows == 0. Nothing arms either in the current build → inert.
;
; Port note: dest is the caller-supplied GB BG-map pointer ($9800 region),
; addressed [ebp + ptr] exactly like do_bg_transfer. render_bg does not scan
; that region, so the copy is harmless/unread here (see header). NEVER uses the
; port's 40-wide SCREEN_WIDTH — GB_BG_ROW_TILES/GB_BG_STRIDE are hardcoded.
;
; In:  EBP = GB memory base. Out: all registers preserved.
; ═══════════════════════════════════════════════════════════════════════════
VBlankCopyBgMap:
    pushad

    ; ── self-gate ────────────────────────────────────────────────────────────
    mov al, [ebp + hVBlankCopyBGSource]     ; low byte = enable byte (pret)
    test al, al
    jz .done                                ; ret z — queue disabled
    movzx ebx, byte [ebp + hVBlankCopyBGNumRows]
    test ebx, ebx
    jz .done                                ; nothing queued

    ; ESI = flat source, EDI = flat dest (16-bit GB pointers from HRAM)
    movzx esi, word [ebp + hVBlankCopyBGSource]
    add esi, ebp
    movzx edi, word [ebp + hVBlankCopyBGDest]
    add edi, ebp

    ; pret zeroes the source so the transfer does not continue next V-blank
    mov byte [ebp + hVBlankCopyBGSource], 0

.row:
    mov ecx, GB_BG_ROW_TILES               ; 20 contiguous source bytes
    rep movsb                              ; src +20 (contiguous), dest +20
    add edi, GB_BG_STRIDE - GB_BG_ROW_TILES ; +12 → dest advances 32 (one 32-wide row)
    dec ebx
    jnz .row
.done:
    popad
    ret

; ═══════════════════════════════════════════════════════════════════════════
; VBlankCopyDouble — pret home/vcopy.asm:224. Copy [hVBlankCopyDoubleSize] 1bpp
; tiles from hVBlankCopyDoubleSource to hVBlankCopyDoubleDest, expanding to 2bpp
; on the way by writing each source byte TWICE (both bitplanes identical).
;
; UNREACHED here, and measured: pret arms this from home/copy2.asm's
; CopyVideoDataDouble, which writes hVBlankCopyDoubleSize and then DelayFrames
; until the V-blank handler has drained it. The port's CopyVideoDataDouble
; (src/home/copy2.asm:116) does the whole expansion SYNCHRONOUSLY and never
; writes that HRAM byte, so nothing in this build can arm the gate. The body is
; ported for label completeness; the self-gate makes it a no-op `ret`.
;
; In/Out: EBP = GB memory base; all registers preserved. Source and destination
; are written back so a multi-frame transfer continues, exactly as pret does.
;
; POINTERS ARE GB ADDRESSES, not flat ones. pret's source is `ld sp, hl` from
; hVBlankCopyDoubleSource — GB space — so both ends are read through [EBP+ptr].
; (The port's own CopyVideoDataDouble takes a FLAT source instead; that is a
; different routine with a different contract, and this one follows pret.)
;
; The `inc l` / `inc hl` split is pret's and is preserved: fifteen of every
; sixteen destination steps advance only the low byte, and only the sixteenth
; carries into H. See TransferBgRows above for why that matters.
; ═══════════════════════════════════════════════════════════════════════════
VBlankCopyDouble:
    pushad
    mov al, [ebp + hVBlankCopyDoubleSize]
    test al, al
    jz .done                            ; ret z — gate

    ; VRAM TILE PATTERNS CHANGE HERE, so the decode cache must be rebuilt. pret
    ; has no counterpart; this is the port's standing obligation for any write
    ; into vChars (CLAUDE.md, "VRAM tile writes"). Armed up front, before the
    ; first byte lands, so an early exit cannot leave a stale cache behind.
    mov byte [g_tilecache_dirty], 1

    movzx esi, word [ebp + hVBlankCopyDoubleSource]
    add esi, ebp                        ; ESI = flat view of the GB source
    movzx edx, word [ebp + hVBlankCopyDoubleDest]   ; EDX = GB dest pointer (movzx: the
                                        ; upper half must be zero — see AutoBgMapTransfer)
    movzx ebx, al                       ; ld b, a — tile count
    mov byte [ebp + hVBlankCopyDoubleSize], 0   ; xor a / ldh [...] — transferred

.tile:
    mov ecx, TILE_SIZE / 4              ; 4 groups of (2 src bytes -> 4 dest bytes)
.group:
    mov al, [esi]                       ; pop de: E = first byte
    mov ah, [esi + 1]                   ;         D = second byte
    add esi, 2
    mov [ebp + edx], al                 ; ld [hl], e
    inc dl
    mov [ebp + edx], al                 ; ld [hl], e   (duplicate → 2bpp)
    inc dl
    mov [ebp + edx], ah                 ; ld [hl], d
    inc dl
    mov [ebp + edx], ah                 ; ld [hl], d
    dec ecx
    jz .tileEnd                         ; the tile's LAST step is pret's `inc hl`
    inc dl                              ; the other three are `inc l`
    jmp .group
.tileEnd:
    inc dx                              ; inc hl — the one step that carries into H
    dec bl                              ; dec b — 8-bit per the counter-width rule
    jnz .tile

    ; pret writes both pointers back via `ld [hVBlankCopyDoubleSource], sp` and
    ; `ld sp, hl / ld [hVBlankCopyDoubleDest], sp`, so a transfer larger than one
    ; frame resumes where it stopped.
    sub esi, ebp
    mov [ebp + hVBlankCopyDoubleSource], si
    mov [ebp + hVBlankCopyDoubleDest], dx
.done:
    popad
    ret

; ═══════════════════════════════════════════════════════════════════════════
; VBlankCopy — copy [hVBlankCopySize] 2bpp tiles from hVBlankCopySource to
; hVBlankCopyDest.
; pret ref: home/vcopy.asm:VBlankCopy
;
; Source and destination addresses are updated so transfer can continue across
; subsequent frames.
; In:  EBP = GB memory base. Out: all registers preserved.
; Sets g_tilecache_dirty whenever tile data is transferred.
; ═══════════════════════════════════════════════════════════════════════════
VBlankCopy:
    pushad
    mov al, [ebp + hVBlankCopySize]
    test al, al
    jz .done

    mov byte [ebp + hVBlankCopySize], 0 ; transferred (pret: xor a / ldh [hVBlankCopySize], a)

    movzx ecx, al
    shl ecx, 4                          ; total bytes = size * 16 (TILE_SIZE)

    movzx esi, word [ebp + hVBlankCopySource]
    movzx edi, word [ebp + hVBlankCopyDest]

    ; Save initial 16-bit GB pointers and byte count to update headers
    push ecx
    push esi
    push edi

    add esi, ebp
    add edi, ebp
    rep movsb

    pop edi
    pop esi
    pop ecx

    ; Arm the tile-pattern decode cache only when this transfer actually wrote
    ; tile PATTERN bytes. The cache holds decoded patterns, so a pure tilemap
    ; write ($9800+) changes which tiles are shown, not what they look like, and
    ; needs no invalidation.
    ;
    ; THE TEST IS ON THE START ADDRESS, and that is load-bearing: EDI here is
    ; still the transfer's first byte. Testing the END instead would silently
    ; skip a copy that BEGINS in vChars and runs past GB_TILEMAP0 — it writes
    ; pattern bytes, the flag never arms, and the compositor keeps drawing the
    ; slots' previous occupants. That is the visible-corruption class, not a
    ; missed optimisation. Start < GB_TILEMAP0 is exact here because the range
    ; is contiguous and grows upward.
    cmp di, GB_TILEMAP0
    jae .noCacheDirty
    mov byte [g_tilecache_dirty], 1     ; VRAM tile pattern data changed → rebuild decode cache
.noCacheDirty:

    add esi, ecx
    add edi, ecx
    mov [ebp + hVBlankCopySource], si
    mov [ebp + hVBlankCopyDest], di

.done:
    popad
    ret

; ═══════════════════════════════════════════════════════════════════════════
; UpdateMovingBgTiles — animate overworld water (tile $14) + flower (tile $03).
; pret ref: home/vcopy.asm:UpdateMovingBgTiles
;
; Gate: hTileAnimations == 0 → ret (0 breaks Surf; 1 = water only; 2 = water+flower).
; In:  EBP = GB memory base. Out: all registers preserved.
; Sets g_tilecache_dirty whenever it mutates vChars pattern bytes.
; ═══════════════════════════════════════════════════════════════════════════
UpdateMovingBgTiles:
    pushad

    ; ── self-gate ────────────────────────────────────────────────────────────
    mov al, [ebp + hTileAnimations]
    test al, al
    jz .done                        ; ret z — animations disabled

    ; pret: ldh a,[rLY]; cp $90; ret c   ("skip if not in vblank")
    ; TODO-HW: rLY is the GB scanline counter; the software PPU does not expose a
    ; live per-scanline rLY here and DelayFrame IS the port's vblank-equivalent,
    ; so we always proceed. (Faithful I/O-boundary handling.)

    ; ── frame cadence: hMovingBGTilesCounter1 ────────────────────────────────
    mov al, [ebp + hMovingBGTilesCounter1]
    inc al
    mov [ebp + hMovingBGTilesCounter1], al
    cmp al, 20
    jb .done                        ; ret c — not this frame
    cmp al, 21
    je .flower                      ; jr z .flower

    ; ── water: rotate the 16 pattern bytes of tile $14 left or right ─────────
    lea esi, [ebp + WATER_TILE_ADDR]
    mov ecx, TILE_SIZE              ; 16 bytes

    mov al, [ebp + wMovingBGTilesCounter2]
    inc al
    and al, 7
    mov [ebp + wMovingBGTilesCounter2], al

    test al, 4
    jnz .water_left
.water_right:
    mov al, [esi]
    ror al, 1                      ; rrca — bit0 → bit7 (scroll right)
    mov [esi], al
    inc esi
    dec ecx
    jnz .water_right
    jmp .water_commit
.water_left:
    mov al, [esi]
    rol al, 1                      ; rlca — bit7 → bit0 (scroll left)
    mov [esi], al
    inc esi
    dec ecx
    jnz .water_left

.water_commit:
    mov byte [g_tilecache_dirty], 1     ; vChars mutated → re-decode tile_cache

    ; pret: ldh a,[hTileAnimations]; rrca; ret nc; then reset counter1
    ;   anim==1 (bit0 set)  → CF=1 → reset counter1 to 0 (loop stays on water)
    ;   anim==2 (bit0 clear)→ CF=0 → leave counter1 at 20 → next frame → .flower
    mov al, [ebp + hTileAnimations]
    ror al, 1
    jnc .done                      ; ret nc — leave counter armed for flower
    mov byte [ebp + hMovingBGTilesCounter1], 0
.done:
    popad
    ret

    ; ── flower: copy one of three 16-byte pattern frames into tile $03 ───────
.flower:
    mov byte [ebp + hMovingBGTilesCounter1], 0

    mov al, [ebp + wMovingBGTilesCounter2]
    and al, 3
    ;  a<2 → FlowerTile1 ; a==2 → FlowerTile2 ; else (a==3) → FlowerTile3
    lea esi, [FlowerTile1]
    cmp al, 2
    jb .flower_copy
    lea esi, [FlowerTile2]
    je .flower_copy
    lea esi, [FlowerTile3]
.flower_copy:
    lea edi, [ebp + FLOWER_TILE_ADDR]
    mov ecx, TILE_SIZE             ; 16 bytes = one 2bpp tile
    rep movsb
    mov byte [g_tilecache_dirty], 1     ; vChars mutated → re-decode tile_cache
    popad
    ret

; ═══════════════════════════════════════════════════════════════════════════
; Flower animation pattern frames (pret INCBIN gfx/tilesets/flower/flowerN.2bpp).
; Embedded as bytes so this file links standalone; each is exactly one 2bpp tile
; (TILE_SIZE = 16 bytes). Bytes verified against gfx/tilesets/flower/*.2bpp.
; ═══════════════════════════════════════════════════════════════════════════
section .data

FlowerTile1:
    db 0x81,0x00,0x00,0x18,0x00,0x24,0x85,0x5a,0x1c,0x42,0x18,0xa5,0x00,0x7e,0x81,0x18
FlowerTile2:
    db 0x81,0x00,0x00,0x0c,0x00,0x12,0x82,0x2d,0x0e,0xe1,0x0c,0x73,0x00,0x3e,0x81,0x18
FlowerTile3:
    db 0x81,0x18,0x00,0x24,0x04,0x5a,0x9d,0x42,0x18,0x24,0x00,0xdb,0x00,0x7e,0x81,0x18
