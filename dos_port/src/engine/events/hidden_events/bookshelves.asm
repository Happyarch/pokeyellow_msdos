; bookshelves.asm — bookshelf/sculpture/statue hidden-event handler.
;
; Faithful translation of pret `engine/events/hidden_events/bookshelves.asm`.
; Retires the PrintBookshelfText ret-stub in
; src/engine/overworld/hidden_object_stubs.asm.
;
; Called by CheckForHiddenEventOrBookshelfOrCardKeyDoor (src/home/hidden_events.asm)
; as the fallback when no per-map hidden-event handler fired. That caller always
; runs `call GetTileAndCoordsInFrontOfPlayer`
; (src/engine/overworld/player_state.asm) immediately before this call, which
; stores the one-tile-ahead tile id into wTileInFrontOfPlayer — EXACTLY the value
; pret's own `lda_coord 8, 7` reads when facing up (GetTileAndCoordsInFrontOfPlayer's
; facing-up case reads wTileMap + (PLAYER_STANDING_ROW-2)*40 + PLAYER_STANDING_COL,
; the same screen cell as GB coord (8,7) — see that routine's header comment). So
; this file reads wTileInFrontOfPlayer instead of re-deriving the screen
; coordinate: reuse the already-published projected value rather than
; re-deriving pret's raw tilemap coordinate a second time.
;
; BookshelfTileIDs is a (tileset id, tile id, predef text id) lookup table —
; pret data/tilesets/bookshelf_tile_ids.asm, INCLUDEd by pret's bookshelves.asm.
; A pointer/id table, not a string (two-tier rule precedent:
; src/engine/events/hidden_events/cinnabar_gym_quiz.asm's CinnabarGymGateCoords),
; so it is hand-written here rather than generated, using local tileset-id
; equates (constants/tileset_constants.asm values; not generated anywhere in the
; port) — no separate mirror file exists for it, and this change's file
; allow-list has no slot for one, so it is inlined exactly as pret's bookshelves.asm
; textually INCLUDEs it.
;
; Register map: A=AL, BC=BX (B=BH,C=BL), HL=ESI; GB memory at [EBP + addr].
;
; Build: nasm -f coff -I include/ -I . -D BUG_FIX_LEVEL=0 -o /dev/null \
;            src/engine/events/hidden_events/bookshelves.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "predef.inc"
%include "assets/predef_text_ids.inc"

section .text

global PrintBookshelfText

extern EnableAutoTextBoxDrawing         ; src/home/window.asm
extern PrintPredefTextID                ; src/home/predef_text.asm
extern PrintCardKeyText                 ; src/engine/events/card_key.asm

; hInteractedWithBookshelf shares HRAM $FFDB with hItemToRemoveID (golden
; 00:ffdb); see src/home/hidden_events.asm / hidden_object_stubs.asm for the
; same local alias — no gb_memmap.inc symbol exists for it.
%ifndef H_INTERACTED_WITH_BOOKSHELF
H_INTERACTED_WITH_BOOKSHELF equ 0xFFDB
%endif

; Tileset ids used by BookshelfTileIDs below (pret constants/tileset_constants.asm
; const_def order: OVERWORLD=0, REDS_HOUSE_1=1, MART=2, FOREST=3, REDS_HOUSE_2=4,
; DOJO=5, POKECENTER=6, GYM=7, HOUSE=8, ..., GATE=12, SHIP=13, ..., LOBBY=18,
; MANSION=19, LAB=20, ..., PLATEAU=23). Suffixed _TILESET to avoid any clash with
; map-name constants elsewhere.
PLATEAU_TILESET      equ 23
HOUSE_TILESET        equ 8
MANSION_TILESET      equ 19
REDS_HOUSE_1_TILESET equ 1
LAB_TILESET          equ 20
LOBBY_TILESET        equ 18
GYM_TILESET          equ 7
DOJO_TILESET         equ 5
GATE_TILESET         equ 12
MART_TILESET         equ 2
POKECENTER_TILESET   equ 6
SHIP_TILESET         equ 13

; ─────────────────────────────────────────────────────────────────────────────
; PrintBookshelfText — pret engine/events/hidden_events/bookshelves.asm:PrintBookshelfText.
; ─────────────────────────────────────────────────────────────────────────────
PrintBookshelfText:
    mov al, [ebp + wSpritePlayerStateData1FacingDirection]
    cmp al, SPRITE_FACING_UP
    jne .noMatch
; facing up
    mov al, [ebp + wCurMapTileset]
    mov bh, al                            ; ld b, a
    mov al, [ebp + wTileInFrontOfPlayer]  ; lda_coord 8, 7 (see file header)
    mov cl, al                            ; ld c, a
    mov esi, BookshelfTileIDs
.loop:
    mov al, [esi]                         ; ld a, [hli]
    inc esi
    cmp al, 0xFF
    je .noMatch
    cmp al, bh
    jne .nextBookshelfEntry1
    mov al, [esi]                         ; ld a, [hli]
    inc esi
    cmp al, cl
    jne .nextBookshelfEntry2
    mov al, [esi]                         ; ld a, [hl]
    push eax
    call EnableAutoTextBoxDrawing
    pop eax
    call PrintPredefTextID
    mov byte [ebp + H_INTERACTED_WITH_BOOKSHELF], 0
    ret
.nextBookshelfEntry1:
    inc esi                               ; inc hl
.nextBookshelfEntry2:
    inc esi                               ; inc hl
    jmp .loop
.noMatch:
    mov byte [ebp + H_INTERACTED_WITH_BOOKSHELF], 0xFF
    jmp PrintCardKeyText                  ; pret: farjp PrintCardKeyText

; ─────────────────────────────────────────────────────────────────────────────
; BookshelfTileIDs — pret data/tilesets/bookshelf_tile_ids.asm.
; Rows: tileset id, tile-in-front id, predef text id. 0xFF terminates.
; ─────────────────────────────────────────────────────────────────────────────
%macro bookshelf_tile 3
    db %1, %2, %3 %+ _id
%endmacro

section .data
BookshelfTileIDs:
    bookshelf_tile PLATEAU_TILESET,      0x30, IndigoPlateauStatues
    bookshelf_tile HOUSE_TILESET,        0x3D, TownMapText
    bookshelf_tile HOUSE_TILESET,        0x1E, BookOrSculptureText
    bookshelf_tile MANSION_TILESET,      0x32, BookOrSculptureText
    bookshelf_tile REDS_HOUSE_1_TILESET, 0x32, BookOrSculptureText
    bookshelf_tile LAB_TILESET,          0x28, BookOrSculptureText
    bookshelf_tile LOBBY_TILESET,        0x16, ElevatorText
    bookshelf_tile GYM_TILESET,          0x1D, BookOrSculptureText
    bookshelf_tile DOJO_TILESET,         0x1D, BookOrSculptureText
    bookshelf_tile GATE_TILESET,         0x22, BookOrSculptureText
    bookshelf_tile MART_TILESET,         0x54, PokemonStuffText
    bookshelf_tile MART_TILESET,         0x55, PokemonStuffText
    bookshelf_tile POKECENTER_TILESET,   0x54, PokemonStuffText
    bookshelf_tile POKECENTER_TILESET,   0x55, PokemonStuffText
    bookshelf_tile LOBBY_TILESET,        0x50, PokemonStuffText
    bookshelf_tile LOBBY_TILESET,        0x52, PokemonStuffText
    bookshelf_tile SHIP_TILESET,         0x36, BookOrSculptureText
    db 0xFF
section .text
