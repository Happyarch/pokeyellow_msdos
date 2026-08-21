; book_or_sculpture.asm — Bookshelf or sculpture hidden-event handler.
;
; Faithful translation of pret `engine/events/hidden_events/book_or_sculpture.asm`.
;
; Routines:
;   BookOrSculptureText: Checks wCurMapTileset for MANSION tileset and tile (8,6)
;     for tile 0x38 (Diglett sculpture). Displays DiglettSculptureText if match,
;     otherwise PokemonBooksText.
;
; Text streams:
;   PokemonBooksText, DiglettSculptureText: Tier-1 data generated into
;     assets/book_or_sculpture_text.inc.
;
; Register map:
;   A = AL, HL = ESI; GB memory at [EBP + addr].
;
; Build: nasm -f coff -I include/ -I . -D BUG_FIX_LEVEL=0 -o book_or_sculpture.o \
;            src/engine/events/hidden_events/book_or_sculpture.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "coords.inc"

%ifndef MANSION
%define MANSION                         19  ; constants/tileset_constants.asm
%endif

section .text

extern PrintText                        ; src/home/window.asm
extern TextScriptEnd                    ; src/home/overworld_text.asm

; ─────────────────────────────────────────────────────────────────────────────
; BookOrSculptureText — pret engine/events/hidden_events/book_or_sculpture.asm:BookOrSculptureText.
; ─────────────────────────────────────────────────────────────────────────────
global BookOrSculptureText
; DEVIATION{class=projection; pret=engine/events/hidden_events/book_or_sculpture.asm:BookOrSculptureText; behavior=reads tile at (PLAYER_STANDING_COL, PLAYER_STANDING_ROW - 3) = (24, 14) on 40x25 canvas instead of GB literal coord (8, 6); evidence=pret lda_coord 8, 6 is 3 rows above player feet (8, 9) which projects to (24, 14) per ui_projection.md; lifetime=permanent}
BookOrSculptureText:
    mov esi, PokemonBooksText
    mov al, [ebp + wCurMapTileset]
    cmp al, MANSION                     ; Celadon Mansion tileset
    jne .ok
    mov al, [ebp + wTileMap + (PLAYER_STANDING_ROW - 3) * SCREEN_TILES_W + PLAYER_STANDING_COL]
    cmp al, 0x38
    jne .ok
    mov esi, DiglettSculptureText
.ok:
    call PrintText
    jmp TextScriptEnd

; %include the generated PokemonBooksText and DiglettSculptureText data
%include "assets/book_or_sculpture_text.inc"
