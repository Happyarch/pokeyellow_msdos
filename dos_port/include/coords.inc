%ifndef COORDS_INC
%define COORDS_INC

; -----------------------------------------------------------------------------
; coords.inc — Coordinate mapping macros
; Translates GB x,y tile coordinates into port memory addresses.
;
; NOTE: The DOS port renders the overworld at a native 40x25 tile viewport
; (W_TILEMAP), unlike the GB's 20x18. 'coord' targets W_TILEMAP with stride 40.
; 'bgcoord' targets GB_TILEMAP0 with stride 32.
;
; hlcoord uses ESI (HL's pointer register); decoord uses EDI (DE's secondary
; pointer). bccoord uses EBX (full 32-bit), matching every existing
; hand-computed bccoord call site in the port (e.g. pokedex_entry.asm) — it
; must NOT alias ESI, since pret code routinely holds an hlcoord and a
; bccoord live at once (e.g. feeding TextCommandProcessor's ESI=stream /
; EBX=cursor pair).
; dwcoord emits a 32-bit `dd` address offset, despite the 'dw' in the name.
; -----------------------------------------------------------------------------

%macro validate_coords 2
    %if %1 >= SCREEN_WIDTH
        %error "x coord out of range"
    %endif
    %if %2 >= SCREEN_HEIGHT
        %error "y coord out of range"
    %endif
%endmacro

%macro validate_coords 4
    %if %1 >= %3
        %error "x coord out of range"
    %endif
    %if %2 >= %4
        %error "y coord out of range"
    %endif
%endmacro

%macro coord 3-4
    validate_coords %2, %3
    %if %0 >= 4
        mov %1, (%3) * SCREEN_WIDTH + (%2) + %4
    %else
        mov %1, (%3) * SCREEN_WIDTH + (%2) + W_TILEMAP
    %endif
%endmacro

%macro hlcoord 2-3
    %if %0 >= 3
        coord esi, %1, %2, %3
    %else
        coord esi, %1, %2
    %endif
%endmacro

%macro bccoord 2-3
    %if %0 >= 3
        coord ebx, %1, %2, %3
    %else
        coord ebx, %1, %2
    %endif
%endmacro

%macro decoord 2-3
    %if %0 >= 3
        coord edi, %1, %2, %3
    %else
        coord edi, %1, %2
    %endif
%endmacro

%macro dwcoord 2-3
    validate_coords %1, %2
    %if %0 >= 3
        dd (%2) * SCREEN_WIDTH + (%1) + %3
    %else
        dd (%2) * SCREEN_WIDTH + (%1) + W_TILEMAP
    %endif
%endmacro

%macro ldcoord_a 2-3
    validate_coords %1, %2
    %if %0 >= 3
        mov byte [ebp + (%2) * SCREEN_WIDTH + (%1) + %3], al
    %else
        mov byte [ebp + (%2) * SCREEN_WIDTH + (%1) + W_TILEMAP], al
    %endif
%endmacro

%macro lda_coord 2-3
    validate_coords %1, %2
    %if %0 >= 3
        mov al, byte [ebp + (%2) * SCREEN_WIDTH + (%1) + %3]
    %else
        mov al, byte [ebp + (%2) * SCREEN_WIDTH + (%1) + W_TILEMAP]
    %endif
%endmacro

%macro dbmapcoord 2
    db %2, %1
%endmacro

%macro bgcoord 3-4
    validate_coords %2, %3, TILEMAP_WIDTH, TILEMAP_H
    %if %0 >= 4
        mov %1, (%3) * TILEMAP_WIDTH + (%2) + %4
    %else
        mov %1, (%3) * TILEMAP_WIDTH + (%2) + GB_TILEMAP0
    %endif
%endmacro

%macro hlbgcoord 2-3
    %if %0 >= 3
        bgcoord esi, %1, %2, %3
    %else
        bgcoord esi, %1, %2
    %endif
%endmacro

%macro bcbgcoord 2-3
    %if %0 >= 3
        bgcoord ebx, %1, %2, %3
    %else
        bgcoord ebx, %1, %2
    %endif
%endmacro

%macro debgcoord 2-3
    %if %0 >= 3
        bgcoord edi, %1, %2, %3
    %else
        bgcoord edi, %1, %2
    %endif
%endmacro

%macro owcoord 4
    ; register, x, y, map width
    ; wOverworldMap has a MAP_BORDER-block ring on every side, so the row stride
    ; is (mapwidth + MAP_BORDER*2) and the origin is offset by MAP_BORDER in each
    ; axis. Matches pret ReplaceTileBlock (engine/overworld/update_map.asm), which
    ; uses `add MAP_BORDER * 2` for the stride and MAP_BORDER for the border skip.
    ; FIX(2026-07-04): was hardcoded to 3 (border=3); MAP_BORDER is 6 — the old
    ; form landed inside the border ring, not on the target block. Unused at fix
    ; time (coords.inc not yet %included), so zero call-site impact.
    mov %1, W_OVERWORLD_MAP + ((%2) + MAP_BORDER) + (((%3) + MAP_BORDER) * ((%4) + (MAP_BORDER * 2)))
%endmacro

%macro hlowcoord 3
    owcoord esi, %1, %2, %3
%endmacro

%macro bcowcoord 3
    owcoord ebx, %1, %2, %3
%endmacro

%macro deowcoord 3
    owcoord edi, %1, %2, %3
%endmacro

; event_displacement — precomputed wCurrentTileBlockMapViewPointer + player
; Y/X pair for the special-warp data tables (pret macros/coords.asm; consumed
; by data/maps/special_warps.asm's fly_warp / special_warp_spec macros).
; Pret emits `dw wOverworldMap + 7 + w + (w+6)*(y>>1) + (x>>1)` — a border-3,
; GB-viewport-centered pointer. RE-DERIVED 2026-07-10 against the port's
; runtime view-pointer recompute (overworld.asm:LoadWarpDestination):
;   stride   = width + 2*MAP_BORDER
;   view_row = (y>>1) + MAP_BORDER - SCREEN_BLOCK_HEIGHT/2
;   view_col = (x>>1) + MAP_BORDER - SCREEN_BLOCK_WIDTH/2
;   ptr      = W_OVERWORLD_MAP + view_row * stride + view_col
; The two MUST stay in lockstep: a special warp loads this table value into
; W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR exactly where a normal warp would have
; computed the runtime form. Both are pure functions of MAP_BORDER /
; SCREEN_BLOCK_*, so a future border change reassembles both correctly.
; Emits `dw` — the field at 0xD35E is 2 bytes and the pointer is a GB-space
; address; the previous `dd` emission was a latent size mismatch.
; FIX(2026-07-10): was pret's verbatim border-3 form (+7/+6 constants;
; MAP_BORDER is 6), flagged "do not use until re-derived". Unused before this
; fix; first consumer is special_warps.asm (OW-5.2).
%macro event_displacement 3
    ; map width, x coord, y coord (tile units, as pret passes them)
    dw (W_OVERWORLD_MAP + (((%3) >> 1) + MAP_BORDER - SCREEN_BLOCK_HEIGHT/2) * ((%1) + MAP_BORDER * 2) + (((%2) >> 1) + MAP_BORDER - SCREEN_BLOCK_WIDTH/2))
    db %3, %2
%endmacro

%endif
