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
; bccoord/decoord shorthands map to the port's 32-bit pointer registers
; (esi/edi), not EBX/EDX.
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
        coord esi, %1, %2, %3
    %else
        coord esi, %1, %2
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
        bgcoord esi, %1, %2, %3
    %else
        bgcoord esi, %1, %2
    %endif
%endmacro

%macro debgcoord 2-3
    %if %0 >= 3
        bgcoord edi, %1, %2, %3
    %else
        bgcoord edi, %1, %2
    %endif
%endmacro

%macro owcoord 3-4
    ; register, x, y, map width
    mov %1, W_OVERWORLD_MAP + ((%2) + 3) + (((%3) + 3) * ((%4) + (3 * 2)))
%endmacro

%macro hlowcoord 3
    owcoord esi, %1, %2, %3
%endmacro

%macro bcowcoord 3
    owcoord esi, %1, %2, %3
%endmacro

%macro deowcoord 3
    owcoord edi, %1, %2, %3
%endmacro

%macro event_displacement 3
    ; map width, x blocks, y blocks
    dd (W_OVERWORLD_MAP + 7 + (%1) + ((%1) + 6) * ((%3) >> 1) + ((%2) >> 1))
    db %3, %2
%endmacro

%endif
