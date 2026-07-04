%ifndef GFX_MACROS_INC
%define GFX_MACROS_INC

; -----------------------------------------------------------------------------
; gfx_macros.inc — GFX & Code Sugar Macros
; -----------------------------------------------------------------------------

; RGB r, g, b (packs RGB555)
%macro RGB 3-*
    %rep %0 / 3
        dw ((%3) << 10) | ((%2) << 5) | (%1)
        %rotate 3
    %endrep
%endmacro

; dbsprite x_tile, y_tile, x_pixel, y_pixel, vtile_offset, attributes
%macro dbsprite 6
    db ((%2 * 8) % 256 + %4), ((%1 * 8) % 256 + %3), %5, %6
%endmacro

; -----------------------------------------------------------------------------
; Code Sugar (from macros/code.asm)
; -----------------------------------------------------------------------------

%macro lb 3
    mov %1, (((%2) & 0xFF) << 8) | ((%3) & 0xFF)
%endmacro

%macro ldpal 5
    mov %1, ((%2) << 6) | ((%3) << 4) | ((%4) << 2) | (%5)
%endmacro

%macro dict 2
    %if %1 == 0
        test al, al
    %else
        cmp al, %1
    %endif
    jz %2
%endmacro

; ld_hli_a_string: N/A (requires complex compile-time string indexing).
; Emit a runtime loop or unroll manually instead.

%endif ; GFX_MACROS_INC
