; load_font.asm — expand the 1bpp text font to 2bpp and load it into vFont;
; also copy the 2bpp extra-char / box-drawing tiles to vChars2+$60.
;
; LoadFontTilePatterns — source: home/load_font.asm.
; Mirrors home/copy2.asm:FarCopyDataDouble (1bpp → 2bpp expansion).
; The font art (gfx/font/font.png) is embedded as NASM data via
; assets/font_1bpp.inc (tools/generators/gen_font_inc.py). With LCDC_DEFAULT ($8800
; signed addressing), char code C ('A'=$80) maps to tile at $8800+(C-$80)*16.
;
; LoadTextBoxTilePatterns — source: home/load_font.asm:LoadTextBoxTilePatterns.
; Copies 2bpp data (gfx/font/font_extra.png, chars $60-$7F) to vChars2+$60
; (EBP offset $9600). Includes box-drawing tiles $79-$7E used by TextBoxBorder.
; Data embedded via assets/font_extra_2bpp.inc (tools/generators/gen_font_extra_inc.py).
;
; Build: nasm -f coff -I include/ -I . -o load_font.o load_font.asm

bits 32

%include "gb_memmap.inc"
%include "gb_macros.inc"

global LoadFontTilePatterns
global LoadTextBoxTilePatterns
global LoadHpBarAndStatusTilePatterns
global LoadHudTilePatterns
global LoadStatusScreenHudTilePatterns
extern g_tilecache_dirty

section .data
align 4
%include "assets/font_1bpp.inc"
%include "assets/font_extra_2bpp.inc"
%include "assets/font_battle_extra_2bpp.inc"
%include "assets/battle_hud_2bpp.inc"

section .text

; ---------------------------------------------------------------------------
; LoadFontTilePatterns — expand embedded 1bpp font into vFont ($8800) as 2bpp.
; In:  EBP = GB memory base.
; Out: all registers preserved.
; ---------------------------------------------------------------------------
LoadFontTilePatterns:
    mov byte [g_tilecache_dirty], 1     ; VRAM tile data changes → rebuild decode cache
    push eax
    push ecx
    push esi
    push edi

    mov esi, font_1bpp_data
    lea edi, [ebp + GB_VFONT]
    mov ecx, FONT_1BPP_SIZE
.loop:
    lodsb
    mov ah, al
    mov [edi],     al    ; low bitplane
    mov [edi + 1], ah    ; high bitplane (duplicate → colors 0 or 3)
    add edi, 2
    dec ecx
    jnz .loop

    pop edi
    pop esi
    pop ecx
    pop eax
    ret

; ---------------------------------------------------------------------------
; LoadTextBoxTilePatterns — copy 2bpp box/extra-char tiles to vChars2+$60.
;
; Source: home/load_font.asm:LoadTextBoxTilePatterns.
; Destination: vChars2 tile $60 = EBP + GB_VCHARS2 + $60*TILE_SIZE = EBP+$9600.
; Data: 32 tiles (chars $60-$7F, including box-drawing tiles $79-$7E).
; In:  EBP = GB memory base.
; Out: all registers preserved.
; ---------------------------------------------------------------------------
LoadTextBoxTilePatterns:
    mov byte [g_tilecache_dirty], 1     ; VRAM tile data changes → rebuild decode cache
    push eax
    push ecx
    push esi
    push edi

    mov esi, font_extra_2bpp_data
    lea edi, [ebp + GB_VCHARS2 + 0x60 * TILE_SIZE]
    mov ecx, FONT_EXTRA_2BPP_SIZE / 4
    rep movsd

    pop edi
    pop esi
    pop ecx
    pop eax
    ret

; ---------------------------------------------------------------------------
; LoadHpBarAndStatusTilePatterns — copy the HP-bar/status 2bpp tiles to
; vChars2 tile $62.
;
; Source: home/load_font.asm:LoadHpBarAndStatusTilePatterns (pret
; HpBarAndStatusGraphics = gfx/font/font_battle_extra.2bpp).
; Destination: vChars2 tile $62 = EBP + GB_VCHARS2 + $62*TILE_SIZE = EBP+$9620.
; Data: 30 tiles ($62-$7F) — the HP-bar gauge segments, the ":L" tile ($6e),
; the narrow "HP"/"to" tiles, and status glyphs. This OVERWRITES the box-drawing
; tiles $79-$7E that LoadTextBoxTilePatterns supplies, so callers that need a
; TextBoxBorder afterward (e.g. the START menu) must call LoadTextBoxTilePatterns
; again on exit. The space tile $7F is blank in both sets, so panel backgrounds
; filled with spaces stay clean either way.
; In:  EBP = GB memory base.
; Out: all registers preserved.
; ---------------------------------------------------------------------------
LoadHpBarAndStatusTilePatterns:
    mov byte [g_tilecache_dirty], 1     ; VRAM tile data changes → rebuild decode cache
    push eax
    push ecx
    push esi
    push edi

    mov esi, font_battle_extra_2bpp_data
    lea edi, [ebp + GB_VCHARS2 + 0x62 * TILE_SIZE]
    mov ecx, FONT_BATTLE_EXTRA_2BPP_SIZE / 4
    rep movsd

    pop edi
    pop esi
    pop ecx
    pop eax
    ret

; ---------------------------------------------------------------------------
; LoadHudTilePatterns — load the battle HUD frame/divider tiles (pret
; engine/battle/core.asm:LoadHudTilePatterns + BattleHudTiles1/2/3). These overwrite
; the font_extra placeholders ("ID No.") at $73/$74 with the real underline/corner
; pieces the HP bar and pokéballs sit on. Source is pret's 1bpp data already expanded
; to 2bpp by the generator (FarCopyDataDouble equivalent):
;   battle_hud_tiles1  (3 tiles) → vChars2 tile $6d ($96d0)
;   battle_hud_tiles23 (6 tiles) → vChars2 tile $73 ($9730)
; Call right after LoadHpBarAndStatusTilePatterns (pret's combined
; LoadHudAndHpBarAndStatusTilePatterns). In: EBP = GB base. All registers preserved.
; ---------------------------------------------------------------------------
LoadHudTilePatterns:
    mov byte [g_tilecache_dirty], 1
    push eax
    push ecx
    push esi
    push edi

    mov esi, battle_hud_tiles1_2bpp
    lea edi, [ebp + GB_VCHARS2 + 0x6d * TILE_SIZE]
    mov ecx, BATTLE_HUD_TILES1_SIZE / 4
    rep movsd

    mov esi, battle_hud_tiles23_2bpp
    lea edi, [ebp + GB_VCHARS2 + 0x73 * TILE_SIZE]
    mov ecx, BATTLE_HUD_TILES23_SIZE / 4
    rep movsd

    pop edi
    pop esi
    pop ecx
    pop eax
    ret

; ---------------------------------------------------------------------------
; LoadStatusScreenHudTilePatterns — status/summary-screen HUD tiles.
;
; Faithful to pret engine/pokemon/status_screen.asm:StatusScreen, which — unlike the
; battle LoadHudTilePatterns bundle above — issues FOUR separate CopyVideoDataDouble
; loads to DISCONTIGUOUS vChars2 slots so it does NOT clobber the font's <ID> ($73)
; and № ($74) glyphs that LoadHpBarAndStatusTilePatterns just placed:
;   BattleHudTiles1 (3 tiles)      -> vChars2 $6d   (·│  :L  ← halfarrow end)
;   BattleHudTiles2 (1 tile)       -> vChars2 $78   (│)
;   BattleHudTiles3 (2 tiles)      -> vChars2 $76   (─ ┘)
;   PTile           (1 tile)       -> vChars2 $72   (bold P for "PP")
; battle_hud_tiles23_2bpp packs BattleHudTiles2 (3 tiles) + BattleHudTiles3 (3 tiles);
; the status screen uses only tile 0 of _2 and tiles 0-1 of _3 (offset 3 tiles in).
; Call right after LoadHpBarAndStatusTilePatterns. In: EBP = GB base. Regs preserved.
; ---------------------------------------------------------------------------
LoadStatusScreenHudTilePatterns:
    mov byte [g_tilecache_dirty], 1
    push eax
    push ecx
    push esi
    push edi

    ; BattleHudTiles1 -> $6d (3 tiles)
    mov esi, battle_hud_tiles1_2bpp
    lea edi, [ebp + GB_VCHARS2 + 0x6d * TILE_SIZE]
    mov ecx, (3 * TILE_SIZE) / 4
    rep movsd

    ; BattleHudTiles2 tile 0 -> $78 (1 tile)
    mov esi, battle_hud_tiles23_2bpp
    lea edi, [ebp + GB_VCHARS2 + 0x78 * TILE_SIZE]
    mov ecx, (1 * TILE_SIZE) / 4
    rep movsd

    ; BattleHudTiles3 tiles 0-1 -> $76 (2 tiles); _3 begins 3 tiles into _23
    mov esi, battle_hud_tiles23_2bpp + 3 * TILE_SIZE
    lea edi, [ebp + GB_VCHARS2 + 0x76 * TILE_SIZE]
    mov ecx, (2 * TILE_SIZE) / 4
    rep movsd

    ; PTile -> $72 (1 tile, bold P for "PP")
    mov esi, ptile_2bpp
    lea edi, [ebp + GB_VCHARS2 + 0x72 * TILE_SIZE]
    mov ecx, (1 * TILE_SIZE) / 4
    rep movsd

    pop edi
    pop esi
    pop ecx
    pop eax
    ret
