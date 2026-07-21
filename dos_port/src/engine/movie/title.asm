; title.asm — the boot copyright screen (menu-intro B2).
;
; Source: engine/movie/title.asm. Holds pret title.asm's boot copyright-screen
; labels (LoadCopyrightAndTextBoxTiles -> LoadCopyrightTiles) + CopyrightTextString
; data. The port's title *screen* proper is a legacy relocation at movie/title.asm;
; these copyright labels go to the strict pret mirror. Consumed by PlayShootingStar
; (engine/movie/intro.asm).
;
; Build: nasm -f coff -I include/ -I . -o title.o title.asm

bits 32

%include "gb_memmap.inc"
%define UI_LAYOUT_EQUATES_ONLY 1
%include "assets/ui_layout_intro.inc"   ; UI_SPLASH_ROW / UI_SPLASH_COL

; Cinematic BG-drawing origin (the port surface model; see intro.asm / intro_yellow.asm).
INTRO_BG_ORIGIN   equ UI_SPLASH_ROW * SCREEN_TILES_W + UI_SPLASH_COL   ; = 130

extern ClearScreen                   ; movie/title.asm — clear the surface tilemap
extern LoadTextBoxTilePatterns       ; home/load_font.asm — font_extra -> vChars2 $60
extern CopyVideoData                 ; home/copy2.asm — ESI=VRAM dest, EDX=flat src, BL=tiles
extern title_copyright_2bpp          ; movie/title.asm — = NintendoCopyrightLogoGraphics (full copyright.png)
extern PlaceString                   ; home/text.asm — ESI=dest(GB offset), EAX=flat src
extern text_row_stride               ; home/text.asm — PlaceString row stride (port's SCREEN_WIDTH)

section .text

; ---------------------------------------------------------------------------
; LoadCopyrightAndTextBoxTiles — the boot copyright screen. Loads the textbox font
; tiles + the Nintendo copyright logo graphic to vChars2 $60, then lays out the three
; "©1995-1999  Nintendo / Creatures inc. / GAME FREAK inc." lines at surface coord
; (col 2, row 7). (+ its fall-through LoadCopyrightTiles.)
;
; The copyright-logo graphic occupies vChars2 $60-$72 (19 tiles); the "GAME FREAK
; inc." glyphs ($73-$7b) and the hyphen/space ($7c/$7f) come from the font_extra
; tiles that LoadTextBoxTilePatterns leaves at $73-$7F. CopyrightTextString is placed
; through PlaceString exactly as pret does (`jp PlaceString`); the only projection is
; the drawing origin (cinematic canvas) and the 40-wide row stride.
;
; DEVIATION{class=data-model; pret=engine/movie/title.asm:LoadCopyrightTiles; behavior=the copyright graphic is loaded as its exact 19 tiles instead of pret's count of 20, which on the GB overflows one tile past NintendoCopyrightLogoGraphics into the adjacent TextBoxGraphics ("A" tile); evidence=in the port's flat data model the two assets are not adjacent so the overflow would read unrelated bytes, and the 19 real tiles are what the layout references; lifetime=permanent flat-memory model}
; ---------------------------------------------------------------------------
global LoadCopyrightAndTextBoxTiles
LoadCopyrightAndTextBoxTiles:
    mov byte [ebp + H_WY], 0              ; ldh [hWY], a
    call ClearScreen                      ; clear the surface tilemap
    call LoadTextBoxTilePatterns          ; font_extra -> vChars2 $60-$7F
    ; fall through into LoadCopyrightTiles (a separate pret entry point)
global LoadCopyrightTiles
LoadCopyrightTiles:
    mov esi, GB_VCHARS2 + 0x60 * TILE_SIZE ; ld hl, vChars2 tile $60
    mov edx, title_copyright_2bpp          ; ld de, NintendoCopyrightLogoGraphics (flat)
    mov bl, 19                             ; 19 real copyright tiles (see DEVIATION)
    call CopyVideoData                     ; overwrites vChars2 $60-$72
    ; hlcoord 2, 7 (projected to the cinematic origin) then jp PlaceString — pret's
    ; exact tail call. PlaceString advances <NEXT> by 2*stride (double-spaced: the pret
    ; default, since BIT_SINGLE_SPACED_LINES is clear through boot), so the three lines
    ; land on surface rows 7 / 9 / 11 exactly as the GB — NOT the consecutive 7/8/9 a
    ; hand-rolled single-spaced loop would produce. text_row_stride is the port's runtime
    ; equivalent of pret's compile-time SCREEN_WIDTH; set it to the 40-wide cinematic
    ; canvas so a row step is one surface row.
    mov dword [text_row_stride], SCREEN_TILES_W
    mov esi, W_TILEMAP + INTRO_BG_ORIGIN + 7 * SCREEN_TILES_W + 2  ; ld hl, projected coord(2,7) — GB offset
    mov eax, CopyrightTextString                                   ; ld de, CopyrightTextString (flat src)
    jmp PlaceString                                                ; jp PlaceString

section .data
align 4

; Copyright-screen tile-index layout — a byte-exact mirror of pret title.asm's own
; hand-authored CopyrightTextString (`db $60,$61,... / next ... / db "@"`). Three lines
; of copyright-logo/font tile indices ($60-$7f); $4E = newline ("next"), $50 = end
; ("@"). Placed at surface coord (2,7) by LoadCopyrightTiles via PlaceString.
; NOT two-tier debt: these are indices into the NintendoCopyrightLogoGraphics graphic
; + font_extra, NOT gb_text-encodable glyphs — pret itself writes them as inline raw
; `db` bytes (gb_text.encode cannot map them), so the faithful port reproduces pret's
; exact bytes rather than inventing a bespoke encoder for a single custom-logo asset.
global CopyrightTextString
CopyrightTextString:
    db 0x60,0x61,0x62,0x63,0x61,0x62,0x7c,0x7f,0x65,0x66,0x67,0x68,0x69,0x6a, 0x4E             ; ©1995-1999  Nintendo
    db 0x60,0x61,0x62,0x63,0x61,0x62,0x7c,0x7f,0x6b,0x6c,0x6d,0x6e,0x6f,0x70,0x71,0x72, 0x4E    ; ©1995-1999  Creatures inc.
    db 0x60,0x61,0x62,0x63,0x61,0x62,0x7c,0x7f,0x73,0x74,0x75,0x76,0x77,0x78,0x79,0x7a,0x7b, 0x50 ; ©1995-1999  GAME FREAK inc.
