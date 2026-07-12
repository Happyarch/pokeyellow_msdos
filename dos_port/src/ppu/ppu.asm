; ppu.asm — software PPU: scanline BG renderer + OAM compositor.
;
; Renders the 40×25 tile viewport directly into the 320×200 back buffer at
; [EBP + GB_BACKBUF], honoring the I/O register shadows:
;
;   IO_LCDC bit 3 — BG tilemap select   (0 = $9800, 1 = $9C00)
;   IO_LCDC bit 4 — tile data addressing (1 = $8000 unsigned,
;                                          0 = $8800 signed, base $9000)
;   IO_SCX/IO_SCY — background scroll (wraps at 256 px)
;   IO_BGP        — DMG palette: 4 × 2-bit shade, bits 1-0 = color 0
;
; STRATEGY (scanline + decoded tile cache): the whole BG/window tile-data
; region ($8000-$97FF, 384 tiles) is pre-decoded from 2bpp to 8bpp once into
; tile_cache (BGP shade baked in), and re-decoded only when VRAM tile data or
; BGP changes (g_tilecache_dirty / BGP compare). render_bg then builds each
; output scanline by COPYING decoded tile rows (8 bytes/tile) into
; bg_scanline_buf and copying 320 px from the (SCX & 7) fine offset — no
; per-pixel bit decoding in the hot path. Both axes scroll pixel-smooth; the GB
; tilemap wraps at (SCX/8 + col) & 31 and (y + SCY) >> 3 & 31.
;
; 2bpp tile format: each tile row is 2 bytes — byte 0 = low bitplane,
; byte 1 = high bitplane, bit 7 = leftmost pixel.
; color = (hi_bit << 1) | lo_bit.
;
; This is HAL code, not a pret translation — the SM83 register mapping does
; not apply here. EBP is the GB memory base.
;
; Build: nasm -f coff -I include/ -o ppu.o ppu.asm

bits 32

%include "gb_memmap.inc"
%include "gb_macros.inc"

LCDC_BG_MAP_BIT   equ 3        ; rLCDC bit 3: BG tilemap select
LCDC_TILEDATA_BIT equ 4        ; rLCDC bit 4: tile data addressing mode
LCDC_WIN_EN_BIT   equ 5        ; rLCDC bit 5: window enable
LCDC_WIN_MAP_BIT  equ 6        ; rLCDC bit 6: window tilemap select (0=$9800, 1=$9C00)

; ---------------------------------------------------------------------------
; Exported symbols
; ---------------------------------------------------------------------------
global render_bg
global render_window
global render_sprites
global draw_player_marker
global g_player_marker_on
global g_tilecache_dirty

; Player placeholder marker — the player sprite is always at the fixed screen
; center (pret keeps the camera locked on the player and scrolls the BG). Until
; the OAM sprite renderer lands (Phase 1 open item), draw a simple two-tone box
; there so it's obvious where "you" are. Tile (8,8): 16×16 px at (64,64).
PLAYER_MARKER_X    equ 64
PLAYER_MARKER_Y    equ 64
PLAYER_MARKER_SIZE equ 16
PLAYER_MARKER_SHADE equ 3       ; darkest DMG shade for the outline/body
PLAYER_MARKER_INNER equ 0       ; lightest shade for the inner square

; Decoded tile cache: the BG/window tile-data region $8000-$97FF is 0x1800
; bytes = 384 tiles of 16 bytes. Each is pre-decoded once to 8bpp (64 bytes)
; so render_bg copies rows instead of bit-decoding per pixel every frame.
; Stores the RAW 2-bit GB color (0-3), NOT a BGP-mapped shade — the VGA DAC
; does palette mapping (see commit_palette in video.asm), so the cache depends
; only on VRAM tile data and is rebuilt only on g_tilecache_dirty (a palette
; change is just a DAC reprogram, no rebuild).
TILE_CACHE_TILES  equ 384
TILE_CACHE_SIZE   equ TILE_CACHE_TILES * 64

; bg_surface geometry — the decoded 8bpp mirror of wSurroundingTiles.
; NEVER spell these as the bare literals they happen to equal: SURF_W_TILES(48)
; and TILE_HEIGHT(8) collide numerically with nothing here today, but the same
; class of collision (MAP_BORDER*2 == SCREEN_BLOCK_WIDTH) has already bitten this
; codebase once.
SURF_W_TILES      equ 48                        ; wSurroundingTiles width  (tiles)
SURF_H_TILES      equ 36                        ; wSurroundingTiles height (tiles)
SURF_CELLS        equ SURF_W_TILES * SURF_H_TILES   ; 1728
SURF_W            equ SURF_W_TILES * 8          ; 384 px — one surface scanline
SURF_TILE_ROW     equ SURF_W * 8                ; 3072 B — one tile row of surface
TILE_BLANK        equ 0x7F                      ; blank space tile (ClearScreen fill)

; ---------------------------------------------------------------------------
; DATA (initialized — must start "dirty" so the first frame builds the cache)
; ---------------------------------------------------------------------------
section .data
align 4
g_tilecache_dirty: db 1     ; nonzero → render_bg rebuilds tile_cache this frame

; --- bg_surface dirty-skip state (compositor-perf Stage 1b) --------------------
; bg_surface is a pure function of (tile id per cell, tile_cache, tiledata_mode),
; so a cell only needs re-decoding when its tile id changes. surf_shadow holds
; last frame's ids; surf_force forces a full re-decode when the *other* two inputs
; change — i.e. whenever the ids alone no longer determine the pixels:
;   * tile_cache rebuilt (same ids, new patterns)  → rebuild_tile_cache arms it
;   * tiledata_mode flipped (same ids, new tiles)  → id→cache mapping changed
;   * source path switched (overworld ↔ flat)      → the padding cells' meaning
;     changes (flat pads with TILE_BLANK; overworld reads real ids there)
; Starts armed: bg_surface is BSS (zeroed), which no id shadow can describe.
align 4
surf_force:      db 1       ; nonzero → re-decode every cell this frame
align 4
surf_mode_shadow: dd -1     ; tiledata_mode last decoded with (-1 = none yet)
surf_path_shadow: dd -1     ; 1 = overworld surface, 0 = flat wTileMap (-1 = none)

; --- Unified window-compositor descriptor list ----------------------------------
; g_windows[] is the ONE source of truth for what the window layer draws.
; frame.asm loops g_window_count descriptors (painter's order); render_window draws
; one. A screen fully (re)defines this list whenever its window state changes —
; never rely on prior contents. count==0 ⇒ nothing drawn. (Layout/field offsets:
; gb_memmap.inc WIN_*; default count=0 = hidden until a screen populates it.)
align 4
global g_windows, g_window_count
g_window_count: dd 0

; Full-screen whiteout: when nonzero, render_bg fills the whole back buffer with
; BG color 0 (the menu's white) and render_sprites is skipped, so a window-layer
; menu (e.g. the party screen) can sit centered on a clean white field instead of
; over the overworld. Set on menu entry, cleared on exit.
global g_bg_whiteout
g_bg_whiteout: dd 0

; ---------------------------------------------------------------------------
; BSS
; ---------------------------------------------------------------------------
section .bss
align 4
tile_cache:  resb TILE_CACHE_SIZE  ; 384 × 64 = 24 KB of decoded raw-color tile rows
alignb 4
g_player_marker_on: resb 1 ; nonzero → draw_player_marker paints the placeholder
alignb 4
spr_oam_ptr: resd 1        ; GB-relative offset of the current OAM entry
spr_count:   resd 1        ; OAM entries left to process
spr_sx:      resd 1        ; sprite left screen X (signed)
spr_sy:      resd 1        ; sprite top screen Y (signed)
spr_tilebase: resd 1       ; GB-relative address of the sprite's tile data
spr_attr:    resd 1        ; OAM attribute byte
spr_row:     resd 1        ; current sprite row 0..7
spr_rowbase: resd 1        ; GB-relative back-buffer offset of the current row
spr_lo:      resb 1        ; low bitplane of the current tile row
spr_hi:      resb 1        ; high bitplane of the current tile row
alignb 4
; Shared BG/window frame constants (written once per frame)
tiledata_mode:   resd 1    ; 1 = $8000 unsigned, 0 = $8800 signed
; render_bg surface-mirror state
bg_tilemap_base: resd 1    ; BG tilemap base addr ($9800 or $9C00)
bg_scy:          resd 1    ; SCY shadow
bg_scx:          resd 1    ; SCX shadow
sprite_shift_x:  resd 1    ; Dynamic X shift for sprites to align with DOS camera
sprite_shift_y:  resd 1    ; Dynamic Y shift for sprites
; 32-bit DOS position tables for each OAM entry (filled by PrepareOAMData)
global spr_dos_sy, spr_dos_sx, spr_oam_valid
spr_dos_sy:    resd OAM_COUNT  ; signed DOS Y for entry 0..OAM_COUNT-1
spr_dos_sx:    resd OAM_COUNT  ; signed DOS X for entry 0..OAM_COUNT-1
spr_oam_valid: resd 1          ; count of valid entries written this frame (set by PrepareOAMData)

; bg_surface: 384×288 raw-color mirror of wSurroundingTiles.
bg_surface:        resb SURF_W * SURF_H_TILES * 8
alignb 4
surf_shadow:       resb SURF_CELLS   ; tile id each surface cell was last decoded from
alignb 4
surf_row_base:     resd 1            ; bg_surface offset of the row being decoded (scan paths)
surf_row_ctr:      resd 1            ; row counter for the force paths
id_cache_lut:      resd 256          ; tile id → tile_cache pointer (rebuilt on mode flip)
; render_window row buffer and scanline state
row_buf:         resb 256  ; decoded 256-px virtual window row (shade 0–3)
win_map_row:     resd 1    ; EBP-relative offset of current window tilemap row
win_fine_y2:     resd 1    ; (WLY & 7) * 2
win_line_ctr:    resd 1    ; WLY — window internal line counter (resets per descriptor)

; window descriptor storage + per-call cached fields (read once at render_window top
; so decode_win_row / row copies may clobber ESI without losing the descriptor ptr)
alignb 4
g_windows:       resb MAX_WINDOWS * WIN_DESC_SIZE  ; ordered painter's-order list
win_wx:          resd 1    ; cached descriptor WIN_WX
win_wy:          resd 1    ; cached descriptor WIN_WY
win_clip_w:      resd 1    ; cached descriptor WIN_CLIP_W
win_max_y:       resd 1    ; cached descriptor WIN_MAX_Y
win_map_base:    resd 1    ; tilemap_base + start_row*32 (row WLY=0 maps to)

; ---------------------------------------------------------------------------
; Code
; ---------------------------------------------------------------------------
section .text

; ---------------------------------------------------------------------------
; render_bg — blit the BG plane from a decoded offscreen surface (Tier 2 step 3).
;
; Instead of re-resolving 48 tiles × 200 scanlines from the VRAM tilemap every
; frame, we decode wSurroundingTiles (48x36 tiles) into bg_surface (384x288)
; every frame, then blit a 320x200 window at the calculated offset.
; ---------------------------------------------------------------------------
render_bg:
    pushad

    ; Full-screen whiteout: fill the back buffer with BG color 0 and skip the map.
    cmp dword [g_bg_whiteout], 0
    je .no_whiteout
    lea edi, [ebp + GB_BACKBUF]
    mov ecx, RENDER_W * RENDER_H / 4
    xor eax, eax
    rep stosd
    popad
    ret
.no_whiteout:

    ; Tile-data addressing mode (LCDC bit 4): 1 = $8000 unsigned, 0 = $8800 signed.
    ; A flip remaps every id → tile, so the id shadow no longer describes the
    ; surface: force a full re-decode.
    movzx eax, byte [ebp + IO_LCDC]
    shr eax, LCDC_TILEDATA_BIT
    and eax, 1
    mov [tiledata_mode], eax
    cmp eax, [surf_mode_shadow]
    je .mode_same
    mov [surf_mode_shadow], eax
    mov byte [surf_force], 1
    call build_id_cache_lut         ; id → tile_cache pointer, for THIS mode
.mode_same:

    ; sync tile cache if needed (rebuild_tile_cache arms surf_force: the ids are
    ; unchanged but the patterns behind them are not)
    cmp byte [g_tilecache_dirty], 0
    je .cache_ok
    call rebuild_tile_cache
.cache_ok:

    ; ---- decode the tile ids into bg_surface (48×36 tiles = 384×288 px) -------
    ; Which source feeds the surface: view pointer nonzero = the overworld's
    ; wSurroundingTiles; zero = the flat 40×25 wTileMap (title / menus / battle).
    ; A switch between them changes what the padding cells mean, so it forces too.
    xor eax, eax
    cmp word [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR], 0
    je .have_path
    inc eax
.have_path:
    cmp eax, [surf_path_shadow]
    je .path_same
    mov [surf_path_shadow], eax
    mov byte [surf_force], 1
.path_same:
    test eax, eax
    jz .flat_path
    call decode_surface_overworld
    jmp .decode_done
.flat_path:
    call decode_surface_flat
.decode_done:
    mov byte [surf_force], 0

    ; ---- blit a 320x200 window from bg_surface ----
    ; Check if we are actually in the overworld (view pointer != 0)
    movzx eax, word [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR]
    test eax, eax
    jz .not_overworld

    ; The view pointer (wCurrentTileBlockMapViewPointer) identifies the top-left
    ; block of wSurroundingTiles. We subtract it from the map origin (MAP_BORDER)
    ; to find the world block coordinate of bg_surface.
    movzx ecx, byte [ebp + W_CUR_MAP_WIDTH]
    add ecx, MAP_BORDER * 2
    sub eax, W_OVERWORLD_MAP
    xor edx, edx
    div ecx
    ; EAX = view_block_y, EDX = view_block_x
    mov ebx, eax   ; save view_block_y in EBX
    
    ; Xoff = (MAP_BORDER*32 + wXCoord*16 - view_block_x*32) - 160 + walk_offset_x
    mov eax, MAP_BORDER
    sub eax, edx             ; eax = MAP_BORDER - view_block_x
    shl eax, 5               ; * 32
    movzx ecx, byte [ebp + W_X_COORD]
    shl ecx, 4               ; * 16
    add eax, ecx
    sub eax, 160
    
    ; walk_offset_x = X_STEP_VECTOR * (8 - wWalkCounter) * 2 (only if walking)
    movzx ecx, byte [ebp + W_WALK_COUNTER]
    test ecx, ecx
    jz .no_walk_x
    push ebx
    mov ebx, 8
    sub ebx, ecx             ; ebx = 8 - walk_counter
    shl ebx, 1               ; ebx = (8 - walk_counter) * 2
    movsx ecx, byte [ebp + W_SPRITE_PLAYER_X_STEP_VECTOR]
    imul ecx, ebx            ; ecx = step_vector * offset
    add eax, ecx
    pop ebx
.no_walk_x:
    
    ; EAX is now Original_Xoff
    mov [sprite_shift_x], eax
    
    ; Clamp X to 0..64 to stay within bg_surface
    test eax, eax
    jns .x_min_ok
    xor eax, eax
.x_min_ok:
    cmp eax, 64
    jle .x_max_ok
    mov eax, 64
.x_max_ok:
    mov [bg_scx], eax
    
    ; Shift_X = GB_Screen_Abs_X - bg_scx
    mov eax, [sprite_shift_x]
    sub eax, [bg_scx]
    mov [sprite_shift_x], eax
    
    ; Yoff = (MAP_BORDER*32 + wYCoord*16 - view_block_y*32) - 96 + walk_offset_y
    mov eax, MAP_BORDER
    sub eax, ebx             ; eax = MAP_BORDER - view_block_y
    shl eax, 5               ; * 32
    movzx ecx, byte [ebp + W_Y_COORD]
    shl ecx, 4               ; * 16
    add eax, ecx
    sub eax, 96
    
    ; walk_offset_y = Y_STEP_VECTOR * (8 - wWalkCounter) * 2 (only if walking)
    movzx ecx, byte [ebp + W_WALK_COUNTER]
    test ecx, ecx
    jz .no_walk_y
    push ebx
    mov ebx, 8
    sub ebx, ecx             ; ebx = 8 - walk_counter
    shl ebx, 1               ; ebx = (8 - walk_counter) * 2
    movsx ecx, byte [ebp + W_SPRITE_PLAYER_Y_STEP_VECTOR]
    imul ecx, ebx            ; ecx = step_vector * offset
    add eax, ecx
    pop ebx
.no_walk_y:
    
    ; EAX is now Original_Yoff
    mov [sprite_shift_y], eax
    
    ; Clamp Y to 0..88 to stay within bg_surface
    test eax, eax
    jns .y_min_ok
    xor eax, eax
.y_min_ok:
    cmp eax, 88
    jle .y_max_ok
    mov eax, 88
.y_max_ok:
    mov [bg_scy], eax
    
    ; Shift_Y = GB_Screen_Abs_Y - bg_scy
    mov eax, [sprite_shift_y]
    sub eax, [bg_scy]
    mov [sprite_shift_y], eax
    
    jmp .do_blit

.not_overworld:
    movzx ecx, byte [ebp + IO_SCX]
    mov dword [bg_scx], ecx
    mov dword [sprite_shift_x], 0
    movzx ecx, byte [ebp + IO_SCY]
    mov dword [bg_scy], ecx
    mov dword [sprite_shift_y], 0

.do_blit:

    ; blit 320x200 from bg_surface at (Xoff, Yoff)
    xor edx, edx   ; screen y
.blit_row:
    mov eax, [bg_scy]
    add eax, edx
    
    movzx ecx, word [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR]
    test ecx, ecx
    jnz .no_y_wrap
    and eax, 255
.no_y_wrap:

    imul eax, eax, 384
    mov ecx, [bg_scx]
    add eax, ecx
    lea esi, [bg_surface + eax]
    
    mov edi, edx
    imul edi, RENDER_W
    lea edi, [ebp + GB_BACKBUF + edi]

    ; 320 bytes = 80 dwords
    mov ecx, RENDER_W / 4
    rep movsd

    inc edx
    cmp edx, RENDER_H
    jb .blit_row

    popad
    ret

; ---------------------------------------------------------------------------
; build_id_cache_lut — precompute id → tile_cache pointer for the current mode.
;
; The id→pattern mapping depends only on tiledata_mode, so resolving it per tile
; (a memory `cmp`, a branch, a sign/zero extend and two shifts, ~15 cycles × 1728
; cells) was pure repeated work. Do it once for all 256 ids whenever the mode
; flips — which is also exactly when a full re-decode is forced anyway.
;
; tile_cache is indexed from GB_VCHARS0 ($8000) in 64-byte decoded tiles:
;   unsigned ($8000 base): id*16 packed → id*64 decoded
;   signed   ($9000 base): $1000 + sx(id)*16 packed → $4000 + sx(id)*64 decoded
; In: [tiledata_mode]. All registers preserved.
; ---------------------------------------------------------------------------
build_id_cache_lut:
    pushad
    xor ecx, ecx                           ; id 0..255
    cmp dword [tiledata_mode], 0
    je .signed
.unsigned_loop:
    mov eax, ecx
    shl eax, 6                             ; id * 64 (one decoded tile)
    add eax, tile_cache
    mov [id_cache_lut + ecx*4], eax
    inc ecx
    cmp ecx, 256
    jb .unsigned_loop
    popad
    ret
.signed:
    movsx eax, cl                          ; sx(id): ids $80-$FF address $8800-$8FFF
    shl eax, 6                             ; sx(id) * 64
    add eax, tile_cache + 0x4000           ; $9000 base = ($1000 packed) × 4 decoded
    mov [id_cache_lut + ecx*4], eax
    inc ecx
    cmp ecx, 256
    jb .signed
    popad
    ret

; ---------------------------------------------------------------------------
; decode_tile — paint one decoded 8×8 tile into bg_surface.
;
; In:  AL = GB tile id, EDI = destination in bg_surface, id_cache_lut built.
; Out: ESI and EDI preserved — every caller keeps a live cursor in one or both of
;      them. (ESI is saved HERE, not by the callers: a caller that forgot to save
;      it kept walking a tile_cache pointer as if it were its source cursor, which
;      silently poisoned the id shadow. Owning the save inside the callee makes
;      that class of bug unrepresentable.) EAX clobbered.
;
; The 8-row copy is fully unrolled: on a 386 a taken `jnz` costs ~7 cycles plus a
; prefetch-queue flush, so the 8-iteration loop it replaces spent roughly a third
; of its time on loop overhead alone. Displacements are compile-time constants, so
; the two pointer `add`s per row vanish as well.
; ---------------------------------------------------------------------------
decode_tile:
    push esi
    movzx eax, al
    mov esi, [id_cache_lut + eax*4]
%assign _row 0
%rep 8
    mov eax, [esi + _row * 8]
    mov [edi + _row * SURF_W], eax
    mov eax, [esi + _row * 8 + 4]
    mov [edi + _row * SURF_W + 4], eax
%assign _row _row + 1
%endrep
    pop esi
    ret

; ---------------------------------------------------------------------------
; decode_surface_overworld — refresh bg_surface from wSurroundingTiles (48×36).
;
; Dirty-skip (compositor-perf Stage 1b): a cell is re-decoded only when its tile
; id differs from surf_shadow (or surf_force is armed). The scan is a `repe cmpsb`
; over each 48-cell row, so an unchanged row costs ~5 cycles/cell instead of the
; ~130 a decode costs — an idle overworld frame drops from 110 KB of surface
; writes to a 1728-byte compare. A walk step that moves the block-map view pointer
; rewrites wSurroundingTiles wholesale and pays the full decode on that one frame.
;
; The two paths are separate loops on purpose: the force path needs no compare and
; walks all three cursors linearly (dest advances 8 px/cell, one tile row = 8 surface
; scanlines), so it carries none of the scan path's per-cell column arithmetic.
;
; In: EBP = GB memory base, [surf_force] set, id_cache_lut built. Clobbers EAX-EDI.
; ---------------------------------------------------------------------------
decode_surface_overworld:
    cmp byte [surf_force], 0
    jne .force

    ; --- steady state: cmpsb-scan each row, decode only the cells that changed ---
    lea esi, [ebp + W_SURROUNDING_TILES]   ; src cursor (flat)
    mov edi, surf_shadow                   ; id-shadow cursor
    mov dword [surf_row_base], bg_surface
    mov edx, SURF_H_TILES                  ; rows remaining
.row:
    mov ecx, SURF_W_TILES                  ; cells remaining in this row
.scan:
    repe cmpsb                             ; run past every cell whose id is unchanged
    je .row_done                           ; ZF set ⇒ the whole remaining run matched
    ; Mismatch: cmpsb has already stepped past it. New id = [esi-1], its shadow
    ; slot = [edi-1], and the cell's column is (width-1) - ECX.
    mov al, [esi - 1]
    mov [edi - 1], al
    mov ebx, SURF_W_TILES - 1
    sub ebx, ecx
    push edi
    mov edi, [surf_row_base]
    lea edi, [edi + ebx*8]
    call decode_tile                       ; preserves ESI (the scan cursor)
    pop edi
    jecxz .row_done                        ; that was the row's last cell
    jmp .scan
.row_done:
    add dword [surf_row_base], SURF_TILE_ROW
    dec edx
    jnz .row
    ret

    ; --- force: every cell, linear cursors, no compare ---
.force:
    lea ebx, [ebp + W_SURROUNDING_TILES]   ; src cursor  (EBX: decode_tile owns ESI)
    mov edx, surf_shadow                   ; id-shadow cursor
    mov edi, bg_surface                    ; dest cursor
    mov dword [surf_row_ctr], SURF_H_TILES
.force_row:
    mov ecx, SURF_W_TILES
.force_cell:
    mov al, [ebx]
    mov [edx], al
    inc ebx
    inc edx
    call decode_tile                       ; EDI = dest, preserved
    add edi, 8                             ; next cell = 8 px right
    dec ecx
    jnz .force_cell
    ; end of tile row: step dest down 8 surface scanlines (the row's 48 cells have
    ; already advanced it by one scanline's worth)
    add edi, SURF_TILE_ROW - SURF_W
    dec dword [surf_row_ctr]
    jnz .force_row
    ret

; ---------------------------------------------------------------------------
; decode_surface_flat — refresh bg_surface from the flat 40×25 wTileMap.
;
; The non-overworld path (title / menus / text / battle). wTileMap is
; SCREEN_TILES_W × SCREEN_TILES_H; the surface's extra columns (≥40) and rows
; (≥25) are padding and render as TILE_BLANK.
;
; Stage 1c: the padding is *static* — it only changes when the tile patterns or
; the addressing mode do, i.e. exactly when surf_force is armed. So the steady
; state scans only the 1000 live cells, not 1728, and the 728 padding cells are
; painted once on the force frame instead of every frame.
;
; NOTE the read is direct from wTileMap at its native 40-wide stride. Funnelling
; it through the 32-wide GB VRAM tilemap is what produced the title-screen
; "Pikachu mirror" (surface cols 32-47 wrapped back onto cols 0-15); see the
; do_bg_transfer retirement note in src/video/frame.asm.
;
; In: EBP = GB memory base, [surf_force] set, id_cache_lut built. Clobbers EAX-EDI.
; ---------------------------------------------------------------------------
decode_surface_flat:
    cmp byte [surf_force], 0
    jne .force

    ; --- steady state: scan the live 40 cells of each of the 25 live rows ---
    lea esi, [ebp + W_TILEMAP]
    mov edi, surf_shadow
    mov dword [surf_row_base], bg_surface
    xor edx, edx                           ; row
.row:
    mov ecx, SCREEN_TILES_W
.scan:
    repe cmpsb
    je .row_done
    mov al, [esi - 1]
    mov [edi - 1], al
    mov ebx, SCREEN_TILES_W - 1
    sub ebx, ecx
    push edi
    mov edi, [surf_row_base]
    lea edi, [edi + ebx*8]
    call decode_tile                       ; preserves ESI (the scan cursor)
    pop edi
    jecxz .row_done
    jmp .scan
.row_done:
    add edi, SURF_W_TILES - SCREEN_TILES_W ; step the shadow past the static padding
    add dword [surf_row_base], SURF_TILE_ROW
    inc edx
    cmp edx, SCREEN_TILES_H
    jb .row
    ret

    ; --- force: every cell, live or padding, linear cursors ---
.force:
    lea ebx, [ebp + W_TILEMAP]             ; live-row src (EBX: decode_tile owns ESI)
    mov edx, surf_shadow
    mov edi, bg_surface
    mov dword [surf_row_ctr], 0            ; row
.force_row:
    xor ecx, ecx                           ; column
.force_cell:
    mov al, TILE_BLANK
    cmp dword [surf_row_ctr], SCREEN_TILES_H   ; row ≥ 25 → padding
    jae .have_id
    cmp ecx, SCREEN_TILES_W                    ; col ≥ 40 → padding
    jae .have_id
    mov al, [ebx + ecx]                    ; EBX = wTileMap row base (live rows only)
.have_id:
    mov [edx], al
    inc edx
    call decode_tile                       ; EDI = dest, preserved
    add edi, 8
    inc ecx
    cmp ecx, SURF_W_TILES
    jb .force_cell
    add ebx, SCREEN_TILES_W                ; (walks past wTileMap on padding rows;
                                           ;  never dereferenced there)
    add edi, SURF_TILE_ROW - SURF_W
    inc dword [surf_row_ctr]
    cmp dword [surf_row_ctr], SURF_H_TILES
    jb .force_row
    ret

; ---------------------------------------------------------------------------
; rebuild_tile_cache — decode the 384 BG/window tiles ($8000-$97FF) to 8bpp.
;
; Each 16-byte 2bpp tile becomes 64 bytes (8×8) of RAW color (0-3) in
; tile_cache, laid out linearly (tile i at offset i*64). render_bg then copies
; decoded rows instead of bit-decoding per pixel. Both source (VRAM) and dest
; (cache) are contiguous, so a single source pointer / dest pointer suffice.
; No BGP is applied here — the VGA DAC maps color→shade (commit_palette).
;
; Clears g_tilecache_dirty. In: EBP = GB memory base. All registers preserved.
; ---------------------------------------------------------------------------
rebuild_tile_cache:
    pushad

    mov esi, GB_VCHARS0                ; GB offset of the first tile-data byte
    mov edi, tile_cache
    mov edx, TILE_CACHE_TILES * 8      ; total tile rows (8 per tile)
.row_loop:
    mov bl, [ebp + esi]               ; low bitplane
    mov bh, [ebp + esi + 1]           ; high bitplane
    add esi, 2
    mov ecx, 8
.px_loop:
    xor eax, eax
    shl bh, 1
    rcl al, 1
    shl bl, 1
    rcl al, 1
    stosb                             ; tile_cache[..] = raw color 0-3 (ES:[EDI])
    dec ecx
    jnz .px_loop
    dec edx
    jnz .row_loop

    mov byte [g_tilecache_dirty], 0
    ; The tile ids in surf_shadow are unchanged but the patterns they name are
    ; not, so the id shadow no longer describes bg_surface: force a re-decode.
    mov byte [surf_force], 1
    popad
    ret

; ---------------------------------------------------------------------------
; render_sprites — composite the 40 OAM sprites over the back buffer.
;
; Emulates DMG OBJ rendering (8×8 mode, LCDC_OBJ_8): for each visible sprite,
; blit its 8×8 tile from the OBJ tile area ($8000, unsigned addressing) honoring
; X/Y flip, the OBP0/OBP1 palette, color-0 transparency, and the BG-priority bit
; (attr bit 7 → draw only over BG shade 0; correct under the standard BGP=$E4).
; Reads OAM from $FE00. Call after render_bg, before present.
;
; Simplifications vs. hardware: sprites are drawn in reverse OAM order so a lower
; index ends up on top (handles the index tiebreak, not the smaller-X-wins rule),
; and the 10-sprites-per-scanline limit is not enforced. 8×16 OBJ size (LCDC
; bit 2) is not handled — Pokémon overworld/menus use 8×8.
;
; In:  EBP = GB memory base. All registers preserved.
; ---------------------------------------------------------------------------
render_sprites:
    pushad
    ; Skip OBJ sprites during a full-screen whiteout (overworld player/NPCs must
    ; not paint over the menu's clean white field).
    cmp dword [g_bg_whiteout], 0
    jne .done
    test byte [ebp + IO_LCDC], LCDCF_OBJ_ON
    jz .done

    ; No OBP unpack: sprite pixels are written as raw palette-indexed values
    ; (4 + color for OBP0, 8 + color for OBP1). commit_palette (video.asm) sets
    ; DAC entries 4-7 / 8-11 to the OBP0/OBP1-mapped DMG shades.

    mov dword [spr_oam_ptr], GB_OAM + (OAM_COUNT - 1) * OAM_ENTRY_SIZE
    mov dword [spr_count], OAM_COUNT

.spriteLoop:
    mov esi, [spr_oam_ptr]
    mov ecx, esi                         ; entry index = (oam_ptr - GB_OAM) >> 2
    sub ecx, GB_OAM
    shr ecx, 2
    cmp ecx, [spr_oam_valid]             ; skip entries PrepareOAMData did not write
    jae .nextSprite
    mov eax, [spr_dos_sy + ecx*4]        ; 32-bit DOS Y set by PrepareOAMData
    add eax, [sprite_shift_y]
    mov [spr_sy], eax
    mov eax, [spr_dos_sx + ecx*4]        ; 32-bit DOS X set by PrepareOAMData
    add eax, [sprite_shift_x]
    mov [spr_sx], eax
    movzx eax, byte [ebp + esi + 2]      ; tile id
    shl eax, 4
    add eax, GB_VCHARS0
    mov [spr_tilebase], eax
    movzx eax, byte [ebp + esi + 3]      ; attributes
    mov [spr_attr], eax

    ; Cull sprites that fall entirely off-screen.
    mov eax, [spr_sy]
    cmp eax, RENDER_H
    jge .nextSprite                      ; top at/below bottom edge
    add eax, 7
    js  .nextSprite                      ; bottom row above top edge
    mov eax, [spr_sx]
    cmp eax, RENDER_W
    jge .nextSprite
    add eax, 7
    js  .nextSprite

    mov dword [spr_row], 0
.rowLoop:
    mov eax, [spr_sy]
    add eax, [spr_row]                   ; py
    js  .rowNext                         ; row above the screen
    cmp eax, RENDER_H
    jge .rowNext
    imul ecx, eax, RENDER_W
    add ecx, GB_BACKBUF
    mov [spr_rowbase], ecx

    ; srcrow = yflip ? 7 - row : row
    mov edx, [spr_row]
    test byte [spr_attr], OAM_YFLIP
    jz .noYFlip
    mov edx, 7
    sub edx, [spr_row]
.noYFlip:
    mov eax, [spr_tilebase]
    lea eax, [eax + edx * 2]
    mov dl, [ebp + eax]
    mov [spr_lo], dl
    mov dl, [ebp + eax + 1]
    mov [spr_hi], dl

    xor esi, esi                         ; col = 0..7
.colLoop:
    ; bit index = xflip ? col : 7 - col
    mov ecx, esi
    test byte [spr_attr], OAM_XFLIP
    jnz .haveBit
    mov ecx, 7
    sub ecx, esi
.haveBit:
    movzx eax, byte [spr_lo]
    shr eax, cl
    and eax, 1
    movzx ebx, byte [spr_hi]
    shr ebx, cl
    and ebx, 1
    lea eax, [eax + ebx * 2]             ; color 0..3
    test eax, eax
    jz .colNext                          ; color 0 = transparent

    ; pixel = palette base + color: OBP0 → 4+color, OBP1 → 8+color. The DAC
    ; (commit_palette) maps 4-7 / 8-11 to the OBP0/OBP1-mapped DMG shades.
    lea ebx, [eax + 4]
    test byte [spr_attr], OAM_PAL1
    jz .pal0
    lea ebx, [eax + 8]
.pal0:

    mov eax, [spr_sx]
    add eax, esi                         ; px
    js  .colNext
    cmp eax, RENDER_W
    jge .colNext
    mov ecx, [spr_rowbase]
    add ecx, eax                         ; back-buffer offset (GB-relative)
    test byte [spr_attr], OAM_PRIO
    jz .writePx
    cmp byte [ebp + ecx], 0              ; behind BG: only over BG color 0
    jne .colNext
.writePx:
    mov [ebp + ecx], bl
.colNext:
    inc esi
    cmp esi, 8
    jb .colLoop

.rowNext:
    inc dword [spr_row]
    cmp dword [spr_row], 8
    jb .rowLoop

.nextSprite:
    sub dword [spr_oam_ptr], OAM_ENTRY_SIZE
    dec dword [spr_count]
    jnz .spriteLoop

.done:
    popad
    ret

; ---------------------------------------------------------------------------
; render_window — composite the GB window layer over the back buffer.
;
; The window is a non-scrolling BG-like plane that overlays the main BG from
; screen position (WX-7, WY) downward. Under the unified compositor each box is
; described by a window descriptor (gb_memmap.inc WIN_*): the box geometry
; (wx/wy/clip_w/max_y) and its source (tilemap_base + start_row) come from the
; descriptor, NOT the loose IO_WX/IO_WY/g_win_* globals. Tile data addressing
; still follows the shared LCDC bit 4, identical to the BG. BGP applies — the
; window is fully opaque (color 0 is NOT transparent). Visibility is purely
; count-driven now (frame.asm loops g_window_count descriptors), so the old LCDC
; bit-5/bit-0 enable gate moved out to the legacy shim during migration.
;
; WLY — window internal line counter:
;   WLY starts at 0 per descriptor and increments once for every scanline on
;   which the box is drawn (cur_y >= wy). It is NOT the same as LY. WLY (offset by
;   the descriptor's start_row) indexes the box's tilemap row, so a box that
;   becomes visible only at screen row 72 maps its first source row (WLY=0) there
;   — not row 9. This prevents visual drift when a box starts mid-screen. The
;   implementation stores WLY in win_line_ctr (BSS), reset at each render_window
;   call and incremented after each active scanline.
;
; Call after render_bg AND render_sprites. NOTE: this inverts the GB hardware
; layer order — on real DMG/CGB, OBJ sprites draw over the window, so the HW
; order is BG → window → sprites. We diverge on purpose: the window here is only
; the bottom dialog/menu box (WY=152), which must occlude NPCs under it. The
; bug only shows up because this port's extended 40×25 player-centered viewport
; renders NPCs in the bottom rows that the GB's 20×18 screen never put under the
; box. See the DIVERGENCE note in src/video/frame.asm:DelayFrame.
; In:  EBP = GB memory base, ESI = flat pointer to the window descriptor to draw.
;      All registers preserved.
; ---------------------------------------------------------------------------
render_window:
    pushad

    ; No BGP unpack: the window writes raw color (0-3) like the BG; the DAC
    ; (commit_palette) maps it via BGP — the window shares the BG palette.

    ; Cache descriptor fields up front so decode_win_row / the row copies are free
    ; to clobber ESI without losing the descriptor pointer.
    mov eax, [esi + WIN_WX]
    mov [win_wx], eax
    mov eax, [esi + WIN_WY]
    mov [win_wy], eax
    mov eax, [esi + WIN_CLIP_W]
    mov [win_clip_w], eax
    mov eax, [esi + WIN_MAX_Y]
    mov [win_max_y], eax
    ; win_map_base = tilemap_base + start_row*32 (the tilemap row WLY=0 maps to)
    mov eax, [esi + WIN_START_ROW]
    shl eax, 5
    add eax, [esi + WIN_TILEMAP]
    mov [win_map_base], eax

    ; Cache tile data addressing mode (shared LCDC bit 4).
    movzx eax, byte [ebp + IO_LCDC]
    shr eax, LCDC_TILEDATA_BIT
    and eax, 1
    mov [tiledata_mode], eax

    ; Reset WLY for this descriptor.
    mov dword [win_line_ctr], 0

    mov ebx, [win_wy]                  ; EBX = wy (window top edge, screen-Y units)

    xor ecx, ecx                       ; cur_y = 0

.scanline_loop:
    ; Skip scanlines above the window's vertical trigger.
    cmp ecx, ebx                       ; cur_y < WY?
    jb .next_scanline
    ; Skip scanlines at/below the box bottom (descriptor max_y).
    cmp ecx, [win_max_y]
    jae .next_scanline

    ; ── Decode one window tile row (32 tiles) into row_buf ──────────────────

    ; fine_y2 = (WLY & 7) * 2
    mov edx, [win_line_ctr]
    mov eax, edx
    and eax, 7
    shl eax, 1
    mov [win_fine_y2], eax

    ; map_row = win_map_base + (WLY >> 3) * 32   (win_map_base folds in start_row)
    shr edx, 3
    shl edx, 5
    add edx, [win_map_base]
    mov [win_map_row], edx

    push ecx                            ; save scanline counter — decode_win_row clobbers ECX
    call decode_win_row                ; fill row_buf[0..255] from the 32 window tiles
    pop ecx                            ; restore scanline counter

    ; ── Copy visible window pixels into the back buffer ─────────────────────

    ; wx_adj = wx - 7: signed screen X of the window's left column.
    mov edx, [win_wx]
    sub edx, 7                         ; EDX = wx_adj (signed)

    ; EDI = start of this back-buffer row.
    push ecx
    imul ecx, ecx, RENDER_W
    lea edi, [ebp + GB_BACKBUF + ecx]
    pop ecx

    test edx, edx
    js .win_left_clip

    ; wx_adj >= 0: copy row_buf[0..] → backbuf[wx_adj..RENDER_W-1].
    cmp edx, RENDER_W
    jge .win_inc_ctr                   ; window entirely off the right edge
    lea esi, [row_buf]
    push ecx
    mov ecx, RENDER_W
    sub ecx, edx                       ; pixels to reach the right edge
    ; Clamp to SCREEN_W (160px = 20 tiles), the dialog/menu box's content width.
    ; row_buf holds 256 decoded px (32 tiles), but only cols 0-19 carry the box;
    ; cols 20-31 are TILE_SPC filler added to pad the 32-wide GB tilemap row, and
    ; must NOT be blitted — otherwise they paint blank tiles over the BG to the
    ; right of the box (the box is 160px centered in our 320px viewport, so BG is
    ; visible past its right edge). 160 < 256, so this also stays within row_buf.
    ; The descriptor's clip_w is SCREEN_W (160) for the full dialog; the start menu
    ; narrows it; the bag's sub-boxes set their own widths.
    cmp ecx, [win_clip_w]
    jbe .do_right_copy
    mov ecx, [win_clip_w]
.do_right_copy:
    add edi, edx                       ; advance dest to screen_x_start
    rep movsb
    pop ecx
    jmp .win_inc_ctr

.win_left_clip:
    ; wx_adj < 0: skip the first -wx_adj pixels of row_buf, copy into backbuf[0..].
    neg edx                            ; EDX = number of leading columns to clip
    lea esi, [row_buf + edx]
    push ecx
    mov ecx, RENDER_W
    mov eax, [win_clip_w]              ; box content width (see right-copy clamp above)
    sub eax, edx                       ; content px remaining after the clip
    cmp ecx, eax
    jbe .do_left_copy
    mov ecx, eax                       ; clamp — only blit real box content, not filler
.do_left_copy:
    rep movsb
    pop ecx

.win_inc_ctr:
    inc dword [win_line_ctr]

.next_scanline:
    inc ecx
    ; Loop over all RENDER_H (200) scanlines. Dialog box uses WY=152 to land in
    ; rows 152-199; window is parked at WY=200 (off-screen) when hidden.
    cmp ecx, RENDER_H
    jb .scanline_loop

.done:
    popad
    ret

; ---------------------------------------------------------------------------
; set_single_window — define g_windows[] as exactly one descriptor (count=1).
;
; The migration target for single-box screens (dialog / START / party): replaces
; the old "write IO_WX/H_WY/g_win_clip_w/g_win_max_y then present" pattern with one
; call that fully (re)defines the window list. Pass count=0 directly (via
;   mov dword [g_window_count], 0) to hide instead.
;
; In:  EAX = wx (WX units), EBX = wy (screen-Y px), ECX = clip_w (px),
;      EDX = max_y (px, exclusive), ESI = tilemap_base (EBP-rel: GB_TILEMAP0/1),
;      EDI = start_row (tilemap row mapped to WLY=0), EBP = GB memory base.
; Out: g_window_count = 1, g_windows[0] populated. Also mirrors wy→H_WY and
;      wx→IO_WX so the legacy "is the dialog open?" flag (sync_dialog_window reads
;      H_WY) and rWX/rWY faithfulness stay in sync. All registers preserved.
; ---------------------------------------------------------------------------
global set_single_window
set_single_window:
    mov [g_windows + WIN_WX], eax
    mov [g_windows + WIN_WY], ebx
    mov [g_windows + WIN_CLIP_W], ecx
    mov [g_windows + WIN_MAX_Y], edx
    mov [g_windows + WIN_TILEMAP], esi
    mov [g_windows + WIN_START_ROW], edi
    mov dword [g_window_count], 1
    mov [ebp + H_WY], bl                ; mirror wy → rWY (legacy dialog-open flag)
    mov [ebp + IO_WX], al               ; mirror wx → rWX (faithfulness)
    ret

; ---------------------------------------------------------------------------
; hide_window — empty the window list (count=0 ⇒ nothing drawn).
;
; The migration target for the old "hide" paths (H_WY=RENDER_H + restore the
; g_win_* defaults). Also parks rWY off-screen (RENDER_H) so the legacy
; sync_dialog_window gate (H_WY == RENDER_H) still reads "closed".
; In:  EBP = GB memory base. All registers preserved.
; ---------------------------------------------------------------------------
global hide_window
hide_window:
    mov dword [g_window_count], 0
    mov byte [ebp + H_WY], RENDER_H
    ret

; ---------------------------------------------------------------------------
; add_window — append one descriptor to g_windows[] (g_window_count++).
;
; For multi-box screens (the bag: list + USE/TOSS + quantity + YES/NO). The owner
; first resets the list (hide_window, or directly g_window_count=0), then appends
; each box in painter's order (later descriptors draw on top). Unlike
; set_single_window this does NOT mirror wy→H_WY / wx→IO_WX — those exist only for
; the dialog-open gate (sync_dialog_window), which sub-boxes must not disturb.
; Caller must keep the resulting count <= MAX_WINDOWS.
; In:  EAX=wx, EBX=wy, ECX=clip_w, EDX=max_y, ESI=tilemap_base (EBP-rel), EDI=start_row.
; Out: g_windows[old_count] populated; g_window_count incremented. All regs preserved.
;      ([g_windows + ebp + ..] uses ebp as INDEX (not base) → defaults to DS, matching
;       set_single_window's direct [g_windows + ..] writes; not SS-relative.)
; ---------------------------------------------------------------------------
global add_window
add_window:
    push ebp
    mov ebp, [g_window_count]
    imul ebp, ebp, WIN_DESC_SIZE
    mov [g_windows + ebp + WIN_WX], eax
    mov [g_windows + ebp + WIN_WY], ebx
    mov [g_windows + ebp + WIN_CLIP_W], ecx
    mov [g_windows + ebp + WIN_MAX_Y], edx
    mov [g_windows + ebp + WIN_TILEMAP], esi
    mov [g_windows + ebp + WIN_START_ROW], edi
    pop ebp
    inc dword [g_window_count]
    ret

; ---------------------------------------------------------------------------
; decode_win_row — decode the 32 window tiles of the current row into row_buf
;
; In:  [win_map_row] = GB tilemap row base address
;      [win_fine_y2] = (WLY & 7) * 2
;      [tiledata_mode] set by render_window preamble. Stores raw color 0-3.
; Clobbers: EAX, EBX, ECX, EDX, ESI, EDI
; ---------------------------------------------------------------------------
decode_win_row:
    mov edi, row_buf
    xor esi, esi                       ; tile column 0..31

.wrow_tile:
    mov eax, [win_map_row]
    add eax, esi
    movzx eax, byte [ebp + eax]       ; tile_id

    cmp dword [tiledata_mode], 0
    jne .wrow_unsigned
    movsx eax, al
    shl eax, 4
    add eax, 0x9000
    jmp .wrow_addr_ok
.wrow_unsigned:
    shl eax, 4
    add eax, GB_VRAM0
.wrow_addr_ok:
    add eax, [win_fine_y2]

    mov bl, [ebp + eax]
    mov bh, [ebp + eax + 1]

    mov ecx, 8
.wrow_px:
    xor eax, eax
    shl bh, 1
    rcl al, 1
    shl bl, 1
    rcl al, 1
    stosb                              ; raw color 0-3 (DAC maps via BGP)
    dec ecx
    jnz .wrow_px

    inc esi
    cmp esi, TILEMAP_W
    jb .wrow_tile
    ret

; ---------------------------------------------------------------------------
; draw_player_marker — paint the player placeholder into the back buffer.
;
; No-op unless g_player_marker_on is set (so it only shows in the overworld,
; not the title screen). Draws a PLAYER_MARKER_SIZE square of the darkest shade
; with a half-size lighter square inset, centered on the fixed player screen
; position. Call after render_bg, before present.
;
; In:  EBP = GB memory base. All registers preserved.
; ---------------------------------------------------------------------------
draw_player_marker:
    cmp byte [g_player_marker_on], 0
    jz .ret
    pushad

    ; Outer square: PLAYER_MARKER_SIZE × PLAYER_MARKER_SIZE of the body shade.
    mov edx, PLAYER_MARKER_Y
    mov ecx, PLAYER_MARKER_SIZE                  ; rows remaining
.outer_row:
    imul edi, edx, RENDER_W
    lea edi, [ebp + GB_BACKBUF + edi + PLAYER_MARKER_X]
    push ecx
    mov ecx, PLAYER_MARKER_SIZE
    mov al, PLAYER_MARKER_SHADE
    rep stosb
    pop ecx
    inc edx
    dec ecx
    jnz .outer_row

    ; Inner square: half size, inset by a quarter, in the lighter shade.
    mov edx, PLAYER_MARKER_Y + PLAYER_MARKER_SIZE / 4
    mov ecx, PLAYER_MARKER_SIZE / 2
.inner_row:
    imul edi, edx, RENDER_W
    lea edi, [ebp + GB_BACKBUF + edi + PLAYER_MARKER_X + PLAYER_MARKER_SIZE / 4]
    push ecx
    mov ecx, PLAYER_MARKER_SIZE / 2
    mov al, PLAYER_MARKER_INNER
    rep stosb
    pop ecx
    inc edx
    dec ecx
    jnz .inner_row

    popad
.ret:
    ret
