; trade2.asm — mirror of pret engine/movie/trade2.asm (link plan Stage 3 step 3).
; All 3 pret labels: Trade_PrintPlayerMonInfoText, Trade_PrintEnemyMonInfoText,
; Trade_MonInfoText.
;
; PROJECTION MODEL — same movie-projection surface as trade.asm; see that
; file's DEVIATION on TradeAnimCommon for the whole story (CC(X,Y), the
; MovieSync* calls, PublishProjectedOAM). Nothing here writes hSCX/hSCY/hWY/
; rWX or shadow OAM, so no MovieSync*/PublishProjectedOAM calls are needed in
; this file — every routine here only places text/numbers into the canvas via
; CC(X,Y), which the caller's already-armed movie surface mirrors.
;
; Register map (CLAUDE.md): A=AL, BC=BX (B=BH, C=BL), DE=DX, HL=ESI,
; EBP = GB base.
;
; Build check: nasm -f coff -I include/ -I . -D BUG_FIX_LEVEL=0 \
;              -o /dev/null src/engine/movie/trade2.asm
; ============================================================================

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

%define UI_LAYOUT_EQUATES_ONLY 1
%include "assets/ui_layout_intro.inc"   ; UI_TITLE_COL/ROW — the cinematic origin

; CC(X,Y) — pret hlcoord projection. Copied verbatim from trade.asm /
; src/engine/link/cable_club.asm (same movie-projection surface).
%define CC(X, Y) (wTileMap + ((Y) + UI_TITLE_ROW) * SCREEN_WIDTH + ((X) + UI_TITLE_COL))

extern PlaceString               ; src/home/text.asm — EAX=flat src, ESI=dest
extern PrintNumber                ; src/home/print_num.asm — ESI=dest, EDX=src, BH=flags|bytes, BL=digits
extern IndexToPokedex             ; src/engine/menus/pokedex.asm — in place on wPokedexNum

; Tier-1 generated data: Trade_MonInfoText (tools/generators/gen_menu_strings.py,
; TRADE_MON_INFO_STRINGS — a raw PlaceString glyph run, NOT a text_far body).
%include "assets/trade_mon_info_text.inc"

section .text

global Trade_PrintPlayerMonInfoText
global Trade_PrintEnemyMonInfoText

; ---------------------------------------------------------------------------
; Trade_PrintPlayerMonInfoText — pret engine/movie/trade2.asm:1.
; ---------------------------------------------------------------------------
Trade_PrintPlayerMonInfoText:
    mov esi, CC(5, 0)
    mov eax, Trade_MonInfoText
    call PlaceString
    mov al, [ebp + wTradedPlayerMonSpecies]
    mov [ebp + wPokedexNum], al
    call IndexToPokedex               ; pret: predef IndexToPokedex
    mov esi, CC(9, 0)
    mov edx, wPokedexNum
    mov bh, LEADING_ZEROES | 1
    mov bl, 3
    call PrintNumber
    mov esi, CC(5, 2)
    lea eax, [ebp + wStringBuffer]
    call PlaceString
    mov esi, CC(8, 4)
    lea eax, [ebp + wTradedPlayerMonOT]
    call PlaceString
    mov esi, CC(8, 6)
    mov edx, wTradedPlayerMonOTID
    mov bh, LEADING_ZEROES | 2
    mov bl, 5
    jmp PrintNumber

; ---------------------------------------------------------------------------
; Trade_PrintEnemyMonInfoText — pret engine/movie/trade2.asm:23.
; ---------------------------------------------------------------------------
Trade_PrintEnemyMonInfoText:
    mov esi, CC(5, 10)
    mov eax, Trade_MonInfoText
    call PlaceString
    mov al, [ebp + wTradedEnemyMonSpecies]
    mov [ebp + wPokedexNum], al
    call IndexToPokedex               ; pret: predef IndexToPokedex
    mov esi, CC(9, 10)
    mov edx, wPokedexNum
    mov bh, LEADING_ZEROES | 1
    mov bl, 3
    call PrintNumber
    mov esi, CC(5, 12)
    lea eax, [ebp + wNameBuffer]
    call PlaceString
    mov esi, CC(8, 14)
    lea eax, [ebp + wTradedEnemyMonOT]
    call PlaceString
    mov esi, CC(8, 16)
    mov edx, wTradedEnemyMonOTID
    mov bh, LEADING_ZEROES | 2
    mov bl, 5
    jmp PrintNumber

; Trade_MonInfoText: Tier-1 data, %included above (assets/trade_mon_info_text.inc).
