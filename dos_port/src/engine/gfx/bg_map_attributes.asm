; bg_map_attributes.asm — pret engine/gfx/bg_map_attributes.asm
;
; Per-cell CGB BG palette attributes. On hardware LoadBGMapAttributes VDMAs an
; attribute plane into VRAM bank 1, where the PPU pairs it with the tilemap cell
; by cell. The port's compositor has no second VRAM bank and no per-cell palette
; channel: it bakes a palette band into tile_cache per TILE ID (tile_pal, see
; ppu.asm:rebuild_tile_cache). So the port RESOLVES the plane at load time —
; walking the tilemap alongside the attribute payload and publishing
; tile_pal[tile id] = attribute — instead of carrying it to draw time.
;
; That resolution is exact only while a screen never shows one tile id under two
; different palettes. Measured 2026-08-09 against the mGBA goldens, every screen
; reached from here is collision-free at the pixel level except the Game Freak
; copyright screen (4 tiles) and the pokédex list (1 tile); see the DEVIATION
; below and stigmergy memory cgb-stage0-collision-analysis for the decomposition.
;
; DEVIATION{class=HAL; pret=engine/gfx/bg_map_attributes.asm:LoadBGMapAttributes; behavior=the attribute plane is resolved to a per-tile-id palette band at load time instead of being VDMAed to VRAM bank 1 and paired per cell by the PPU, so a screen showing one tile id under two palettes takes the last one written; evidence=the port's compositor bakes palette into tile_cache per tile id (ppu.asm:rebuild_tile_cache) and models no VRAM bank 1, and a golden-measured collision census found only 5 colliding tiles across all statically-resolvable screens; lifetime=retire when a per-cell attribute layer lands in the compositor, at which point this walks the plane into that layer instead}
;
; The rVBK / rVDMA / rLY / rSTAT sequencing pret needs around the transfer is pure
; hardware and has no port counterpart: the port writes tile_pal directly and arms
; g_tilecache_dirty so the next frame re-decodes.

bits 32
%include "gb_memmap.inc"

global LoadBGMapAttributes
global BGMapAttributesPointers

extern tile_pal, g_tilecache_dirty
extern HandleBadgeFaceAttributes, HandlePartyHPBarAttributes  ; gfx_stubs.asm

; Mirrors ppu.asm's file-local constant of the same name (rLCDC bit 4: tile data
; addressing mode). Kept in step with it deliberately — this routine must resolve
; a tile id to a tile_cache slot exactly as build_id_cache_lut does.
LCDC_TILEDATA_BIT equ 4

section .data

%include "assets/bg_map_attributes.inc"

; pret engine/gfx/bg_map_attributes.asm:BGMapAttributesPointers. Hand-written
; because a dispatch table of addresses is code, not generated data; its rows
; are the payload labels the generator emits. pret uses dw (bank-relative);
; the port uses dd (flat DPMI linear).
BGMapAttributesPointers:
    dd BGMapAttributes_Unknown1
    dd BGMapAttributes_Unknown2
    dd BGMapAttributes_GameFreakIntro
    dd BGMapAttributes_TrainerCard
    dd BGMapAttributes_PartyMenu
    dd BGMapAttributes_NidorinoIntro
    dd BGMapAttributes_TitleScreen
    dd BGMapAttributes_Slots
    dd BGMapAttributes_Pokedex
    dd BGMapAttributes_StatusScreen
    dd BGMapAttributes_Battle
    dd BGMapAttributes_WholeScreen
    dd BGMapAttributes_Unknown13

section .text

; ---------------------------------------------------------------------------
; LoadBGMapAttributes — publish one screen's attribute plane into tile_pal.
;
; In:  BL = packet index (pret's `c`), 1-based into BGMapAttributesPointers.
;      BH nonzero = this screen is drawn on the 40x25 canvas under the uniform
;         +10/+3 GB-centered projection, so also walk that window (see below).
;      EBP = GB memory base.
; Out: tile_pal updated for every tile id the screen's tilemaps reference.
;      All registers preserved.
;
; pret indexes BGMapAttributesPointers[c-1] and runs two transfers: payload #1 to
; vBGMap0 and payload #2 to vBGMap1. The port does the same pairing, walking
; GB_TILEMAP0 against map0 and GB_TILEMAP1 against map1, because a screen may
; live in either map (the cinematics render through a window descriptor whose
; WIN_TILEMAP selects one of the two).
; ---------------------------------------------------------------------------
LoadBGMapAttributes:
    pushad

    movzx eax, bl                       ; c = packet index, 1-based
    test eax, eax
    jz .done                            ; c = 0 has no table; pret would underflow
    dec eax
    cmp eax, BG_ATTR_TABLE_COUNT
    jae .done
    mov esi, [BGMapAttributesPointers + eax*4]

    ; .apply_plane / .apply_canvas_plane both clobber EBX, and the canvas flag
    ; (BH) and packet index (BL) are still needed after them — keep a copy on the
    ; stack rather than in a register the walks are free to destroy.
    push ebx

    mov ecx, [esi]                      ; row count (18, or 32 for WholeScreen)
    mov edx, [esi + 4]                  ; → vBGMap0 payload
    mov edi, GB_TILEMAP0
    call .apply_plane

    mov ecx, [esi]
    mov edx, [esi + 8]                  ; → vBGMap1 payload
    mov edi, GB_TILEMAP1
    call .apply_plane

    ; Screens the port draws straight onto its 40x25 canvas never touch
    ; GB_TILEMAP0/1, so the two walks above see nothing for them. The cinematics
    ; and the battle frame project the whole 20x18 GB screen into the canvas at a
    ; uniform +10 col / +3 row (docs/ui_projection.md — the BCOORD offset), which
    ; is a defined cell-for-cell mapping, so walk that window too when the caller
    ; says this command uses it. Screens with PER-ELEMENT anchoring (the overworld
    ; menu family) have no such mapping and are deliberately excluded: reading the
    ; canvas at GB coordinates there would colour the wrong tiles, which is worse
    ; than leaving them on palette 0.
    cmp byte [esp + 1], 0               ; the saved BH — canvas-projection flag
    je .no_canvas
    mov ecx, [esi]
    mov edx, [esi + 4]                  ; the vBGMap0 payload is the screen's plane
    call .apply_canvas_plane
.no_canvas:

    pop ebx                             ; packet index back in BL for the dispatch
    ; pret: pop af / dec a x4 / jr nz .checkIfHandlingPartyMenu — c == 4 is the
    ; trainer card and c == 5 the party menu, each of which then overwrites
    ; individual attribute cells that the plane above cannot express.
    cmp bl, 4
    jne .not_trainer_card
    call HandleBadgeFaceAttributes
    jmp .done_handlers
.not_trainer_card:
    cmp bl, 5
    jne .done_handlers
    call HandlePartyHPBarAttributes
.done_handlers:

    ; tile_pal feeds the palette band baked into tile_cache at decode time, so the
    ; cache must be rebuilt before these bands are visible.
    mov byte [g_tilecache_dirty], 1
.done:
    popad
    ret

; ---------------------------------------------------------------------------
; .apply_plane — walk one 32-wide tilemap against one attribute payload.
;
; In:  ECX = rows, EDX = attribute payload, EDI = EBP-relative tilemap base.
; Clobbers: EAX EBX ECX EDX EDI plus the cell cursor. ESI preserved (the caller
;           keeps the table pointer there).
; ---------------------------------------------------------------------------
.apply_plane:
    push esi
    shl ecx, 5                          ; rows * 32 = cells; both planes are 32 wide
.cell_loop:
    movzx eax, byte [ebp + edi]         ; tile id at this cell
    ; Resolve the id through the LIVE addressing mode, exactly as the compositor
    ; does (ppu.asm:build_id_cache_lut). tile_pal is indexed by physical tile slot
    ; from $8000, not by tile id:
    ;   unsigned ($8000 base): slot = id
    ;   signed   ($9000 base): slot = id < 128 ? id + 256 : id
    test byte [ebp + IO_LCDC], 1 << LCDC_TILEDATA_BIT
    jnz .have_slot
    cmp al, 128
    jae .have_slot
    add eax, 256
.have_slot:
    movzx ebx, byte [edx]               ; attribute byte = 2-bit palette index
    and bl, 7                           ; attr & 7 — the palette field, as on CGB
    mov [tile_pal + eax], bl
    inc edi
    inc edx
    dec ecx
    jnz .cell_loop
    pop esi
    ret

; ---------------------------------------------------------------------------
; .apply_canvas_plane — walk the projected 20x18 GB window inside W_TILEMAP.
;
; The attribute payload stays 32 bytes per row (its own GB BG-map stride) while
; the canvas row stride is SCREEN_WIDTH, so the two cursors advance differently:
; only the leftmost 20 columns of each attribute row correspond to a GB cell.
;
; In:  ECX = rows in the payload, EDX = attribute payload.
; Clobbers: EAX EBX ECX EDX EDI. ESI preserved.
; ---------------------------------------------------------------------------
GB_SCREEN_COLS   equ 20
GB_SCREEN_ROWS   equ 18
BG_ATTR_STRIDE   equ 32                 ; the attribute plane's own row stride

.apply_canvas_plane:
    push esi
    cmp ecx, GB_SCREEN_ROWS             ; only the GB-visible rows project
    jbe .rows_ok
    mov ecx, GB_SCREEN_ROWS
.rows_ok:
    xor ebx, ebx                        ; EBX = current row
.row_loop:
    ; W_TILEMAP cell for GB (0, row) = (row + 3) * SCREEN_WIDTH + 10
    lea edi, [ebx + 3]
    imul edi, edi, SCREEN_WIDTH
    add edi, W_TILEMAP + 10
    push ecx
    mov ecx, GB_SCREEN_COLS
.col_loop:
    movzx eax, byte [ebp + edi]
    test byte [ebp + IO_LCDC], 1 << LCDC_TILEDATA_BIT
    jnz .canvas_slot
    cmp al, 128
    jae .canvas_slot
    add eax, 256
.canvas_slot:
    push ebx
    movzx ebx, byte [edx]
    and bl, 7
    mov [tile_pal + eax], bl
    pop ebx
    inc edi
    inc edx
    dec ecx
    jnz .col_loop
    pop ecx
    add edx, BG_ATTR_STRIDE - GB_SCREEN_COLS   ; skip the 12 off-screen columns
    inc ebx
    dec ecx
    jnz .row_loop
    pop esi
    ret
