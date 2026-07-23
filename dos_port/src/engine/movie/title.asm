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
extern gamefreak_inc_2bpp            ; movie/title.asm — = GameFreakLogoGraphics ("GAME FREAK inc." glyphs)
extern nine_2bpp                     ; movie/title.asm — = NineTile (© separator glyph)
extern PlaceString                   ; home/text.asm — ESI=dest(GB offset), EAX=flat src
extern text_row_stride               ; home/text.asm — PlaceString row stride (port's SCREEN_WIDTH)

section .text

; ---------------------------------------------------------------------------
; LoadCopyrightAndTextBoxTiles — the boot copyright screen. Loads the textbox font
; tiles + the Nintendo copyright logo graphic to vChars2 $60, then lays out the three
; "©1995-1999  Nintendo / Creatures inc. / GAME FREAK inc." lines at surface coord
; (col 2, row 7). (+ its fall-through LoadCopyrightTiles.)
;
; The © screen's glyphs occupy vChars2 $60-$7C: copyright.png at $60-$72 (19 tiles,
; "©1995-1999" + "Nintendo" + "Creatures inc."), the "GAME FREAK inc." glyphs at
; $73-$7B (gamefreak_inc.2bpp), and the separator at $7C (nine.2bpp). On the GB these
; three graphics are laid out contiguously right after copyright.png, so pret loads
; them with a SINGLE CopyVideoData whose count spans all three (+1 font_extra overflow);
; the flat port loads the same tiles to the same slots with three copies (see the body).
; CopyrightTextString is placed through PlaceString exactly as pret does (`jp PlaceString`);
; the only projection is the drawing origin (cinematic canvas) and the 40-wide row stride.
;
; DEVIATION{class=data-model; pret=engine/movie/title.asm:LoadCopyrightTiles; behavior=pret's single CopyVideoData spanning the ROM-contiguous copyright + GameFreakLogoGraphics + NineTile + 1 font_extra overflow is issued as three separate copies (copyright 19 tiles, gamefreak_inc 9, nine 1) to the identical vChars2 slots, and the unused 1-tile font_extra overflow at $7D is omitted; evidence=those three graphics are separate flat assets in the port so a single contiguous copy is impossible, and CopyrightTextString references only $60-$7C so the $7D overflow is never displayed; lifetime=permanent flat-memory model}
; ---------------------------------------------------------------------------
global LoadCopyrightAndTextBoxTiles
LoadCopyrightAndTextBoxTiles:
    mov byte [ebp + H_WY], 0              ; ldh [hWY], a
    call ClearScreen                      ; clear the surface tilemap
    call LoadTextBoxTilePatterns          ; font_extra -> vChars2 $60-$7F
    ; fall through into LoadCopyrightTiles (a separate pret entry point)
global LoadCopyrightTiles
LoadCopyrightTiles:
    ; pret's LoadCopyrightTiles issues ONE CopyVideoData whose count spans the ROM's
    ; contiguous NintendoCopyrightLogoGraphics + GameFreakLogoGraphics + NineTile (+1
    ; font_extra overflow) — 30 tiles to vChars2 $60. In the port those are three separate
    ; flat assets, so we load them to the same contiguous slots ($60-$7C) with three copies.
    mov esi, GB_VCHARS2 + 0x60 * TILE_SIZE ; ld hl, vChars2 tile $60
    mov edx, title_copyright_2bpp          ; NintendoCopyrightLogoGraphics (copyright.2bpp)
    mov bl, 19                             ; 19 tiles -> $60-$72
    call CopyVideoData
    mov esi, GB_VCHARS2 + 0x73 * TILE_SIZE  ; GameFreakLogoGraphics (gamefreak_inc.2bpp)
    mov edx, gamefreak_inc_2bpp
    mov bl, 9                              ; 9 "GAME FREAK inc." glyphs -> $73-$7B (© line 3)
    call CopyVideoData
    mov esi, GB_VCHARS2 + 0x7C * TILE_SIZE  ; NineTile (nine.2bpp) — the © separator glyph
    mov edx, nine_2bpp
    mov bl, 1                              ; 1 tile -> $7C
    call CopyVideoData
    ; (pret's 30th tile is a 1-tile font_extra overflow at $7D that CopyrightTextString
    ; never references, so the port omits it.)
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

; ---------------------------------------------------------------------------
; CopyDebugName — copy one NAME_LENGTH debug boot name (pret engine/movie/
; title.asm:CopyDebugName: ld bc, NAME_LENGTH / jp CopyData; the source is
; program-image data here, so the CopyData tail is a flat rep movsb).
; In: ESI = flat source name, EDI = flat dest (EBP-biased). Clobbers ECX/ESI/EDI.
; ---------------------------------------------------------------------------
NAME_LENGTH equ 11                   ; wPlayerName / wRivalName field size
global CopyDebugName
CopyDebugName:
    mov ecx, NAME_LENGTH               ; ld bc, NAME_LENGTH
    rep movsb                          ; jp CopyData
    ret

section .data
align 4

; Debug player/rival names (pret charmap encoding), Tier-1 generated data at its
; pret mirror (pret engine/movie/title.asm holds DebugNewGamePlayerName/RivalName).
; Copied to W_PLAYER_NAME / W_RIVAL_NAME by PrepareTitleScreen (movie/title.asm)
; and PrepareOakSpeech (oak_speech.asm). The three labels MUST stay contiguous at
; pret's exact lengths: the NAME_LENGTH(11) copies deliberately overrun, so
; wPlayerName really holds "NINTEN@SONY" on hardware — the golden caught the
; padded-to-11 version as wrong. See tools/generators/gen_debug_boot_names.py.
%include "assets/debug_boot_names.inc"   ; DebugNewGame{Player,Rival}Name + DebugNameTail

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
