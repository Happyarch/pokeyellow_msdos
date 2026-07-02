; init_battle.asm — InitBattle (battle front-end, Wave 2 Stage 1a).
;
; WIDESCREEN CANVAS (user direction, 2026-06-28): the battle uses the FULL 320×200
; (40×25-tile) screen, with the faithful GB default UI built CENTERED in it, so
; individual elements can be spread out into the widescreen margins later on a
; case-by-case basis. There is NO centered 20×18 window any more.
;
; Render path: the battle screen is the BG plane. render_bg already has a
; non-overworld branch that decodes the whole 40×25 W_TILEMAP straight to the
; 320×200 back buffer (the path the title/menu screens use) — it only renders the
; overworld when wCurrentTileBlockMapViewPointer is nonzero. So InitBattle zeroes
; that pointer (+ SCX/SCY) and builds the layout directly in the 40-wide W_TILEMAP;
; frame.asm then renders it via render_bg. No window descriptor (hide_window).
;
; NOTE on the text helpers: TextBoxBorder / PlaceString hardcode a 20-wide stride
; (text.asm: SCREEN_W_TILES = 20), so they cannot lay out into the 40-wide canvas.
; The dialog box is therefore hand-drawn here with the box-border charmap tiles
; ($79-$7E) at stride 40. Single-line text (no <NEXT>/<LINE>) is stride-agnostic,
; so PlaceString still works for names later; the fixed intro string is written as
; raw glyph tile-bytes (renderable glyphs $60+ map 1:1 to tile IDs).
;
; Default GB layout centered in 40×25: col offset 10 = (40−20)/2, row offset 3
; ≈ (25−18)/2. GB battle dialog box is at GB (0,12); centered → canvas (10,15).
;
; In (seeded by the DEBUG_BATTLE harness): wEnemyMonSpecies, wEnemyMonLevel.
; Register map: A=AL, HL=ESI, EBP=GB memory base; GB memory = [EBP+addr].
;
%include "gb_macros.inc"
%include "gb_memmap.inc"
%include "gb_constants.inc"
%define UI_LAYOUT_EQUATES_ONLY 1
%include "assets/ui_layout_battle.inc"

bits 32

; box-border / blank tiles (constants/charmap.asm $79-$7F)
%define T_TL  0x79          ; ┌
%define T_H   0x7A          ; ─
%define T_TR  0x7B          ; ┐
%define T_V   0x7C          ; │
%define T_BL  0x7D          ; └
%define T_BR  0x7E          ; ┘
%define T_SP  0x7F          ; blank/space

%define FW    SCREEN_TILES_W           ; 40 — canvas stride (full widescreen)

; Bottom dialog box — geometry from the generated battle UI layout (Tier 1,
; assets/ui_layout_battle.inc; edit via tools/ui_layout/battle.py). The old
; +10col/+3row GB-centering now lives in the sidecar's per-element shifts.
; PROJ battle: dialog box = UI_DIALOG_BOX_OFS, outer UI_DIALOG_BOX_GBW x GBH
%define BOX_OFS   UI_DIALOG_BOX_OFS
%define BOX_INT_W (UI_DIALOG_BOX_GBW - 2)
%define BOX_INT_H (UI_DIALOG_BOX_GBH - 2)

section .data

; Intro text (faithful _WildMonAppearedText = "Wild <nick>" / "appeared!").
; Line 1 is the "Wild " prefix; the enemy mon's nick is appended at draw time.
intro_line1: db 0x96,0xa8,0xab,0xa3,0x7f         ; "Wild "
INTRO_LINE1_LEN equ $ - intro_line1
; "appeared!"     (a p p e a r e d !)
intro_line2: db 0xa0,0xaf,0xaf,0xa4,0xa0,0xb1,0xa4,0xa3,0xe7
INTRO_LINE2_LEN equ $ - intro_line2

section .text

global InitBattle
global DrawBattleIntroBox
extern InitBattleVariables
extern text_row_stride                   ; text.asm — unified engine row stride
extern ClearSprites
extern hide_window
extern LoadHpBarAndStatusTilePatterns
extern LoadHudTilePatterns
extern DrawBattleHUDs
extern DrawEnemyHUD

InitBattle:
    ; The battle projects the GB viewport into the full 40-wide W_TILEMAP canvas, so
    ; the ONE text engine renders at stride 40 here (the overworld leaves it at 20).
    ; TODO: a clean overworld exit must restore text_row_stride to 20 (Stage 3).
    mov dword [text_row_stride], SCREEN_TILES_W   ; 40
    call InitBattleVariables
    ; reset the remembered FIGHT-menu cursor (wPlayerMoveListIndex persists across move
    ; uses/menu exits for the whole battle; only a new battle clears it). It sits
    ; outside InitBattleVariables' clear block, so clear it explicitly here.
    mov byte [ebp + wPlayerMoveListIndex], 0
    mov byte [ebp + wIsInBattle], 1          ; wild battle (placeholder)
    ; Text-delay config for battle dialog (faithful to pret): set BIT_FAST_TEXT_DELAY so
    ; PrintLetterDelay reads the wOptions speed, and ensure BIT_TEXT_DELAY is OFF. The
    ; delay is enabled ONLY while a dialog MESSAGE prints (like TextCommandProcessor) —
    ; PlaceString/WidePlaceString call PrintLetterDelay unconditionally, so with the bit
    ; off here the menus/HUD/boxes type out instantly; only messages reveal char-by-char.
    mov al, [ebp + W_LETTER_PRINTING_DELAY]
    or  al, (1 << BIT_FAST_TEXT_DELAY)
    and al, (~(1 << BIT_TEXT_DELAY)) & 0xFF
    mov [ebp + W_LETTER_PRINTING_DELAY], al
    mov al, [ebp + wOptions]
    and al, 0xF0                              ; keep battle-style/anim bits, reset speed nibble (TEXT_DELAY_MASK)
    or al, TEXT_DELAY_MEDIUM                  ; default 3 frames/char
    mov [ebp + wOptions], al
    call ClearSprites                        ; drop the overworld OAM (player etc.)
    ; Stop the per-frame OAM rebuild (update_oam → PrepareOAMData) re-showing the
    ; overworld player sprite after ClearSprites; battle manages its own sprites.
    mov byte [ebp + W_UPDATE_SPRITES_ENABLED], 0
    ; Switch render_bg to its flat-canvas (non-overworld) path: zero the overworld
    ; view pointer so it decodes W_TILEMAP directly, and zero scroll so the 40×25
    ; canvas blits at screen (0,0).
    mov word [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR], 0
    mov byte [ebp + IO_SCX], 0
    mov byte [ebp + IO_SCY], 0
    call hide_window                         ; no window overlay — battle screen is the BG
    ; Load the HP-bar / status / ":L" tiles ($62-$71) the HUD needs. Tiles $79-$7E
    ; (the dialog box border) are byte-identical in both tile sets, so this does NOT
    ; clobber the box drawn below despite the load_font.asm warning.
    call LoadHpBarAndStatusTilePatterns
    call LoadHudTilePatterns                 ; HUD frame/divider tiles ($6d-$6f, $73-$78)

    ; --- full-screen blank: clear the whole 40×25 canvas to the space tile ---
    ; (per pret init order — blank the entire screen before drawing the layout).
    lea edi, [ebp + W_TILEMAP]
    mov al, T_SP
    mov ecx, SCREEN_TILES_W * SCREEN_TILES_H  ; 40 × 25 = 1000
    rep stosb
    ret

; ---------------------------------------------------------------------------
; DrawBattleIntroBox — draw the bottom dialog box + "Wild <nick> appeared!" intro
; text + the enemy HUD. Faithful flow: this runs AFTER the silhouette slide-in
; (SlideBattlePicsIn), so it draws over the already-slid mon pics. In: EBP = GB base.
; ---------------------------------------------------------------------------
DrawBattleIntroBox:
    ; --- hand-draw the bottom dialog box (stride 40) at UI_DIALOG_BOX_OFS ---
    ; top border: ┌ + ─×18 + ┐
    lea edi, [ebp + W_TILEMAP + BOX_OFS]
    mov byte [edi], T_TL
    lea edx, [edi + 1]                        ; save interior-fill start for reuse
    inc edi
    mov al, T_H
    mov ecx, BOX_INT_W
    rep stosb                                 ; ─×18  (edi now at right corner col)
    mov byte [edi], T_TR
    ; middle rows: │ + space×18 + │   (BOX_INT_H rows)
    mov ebx, BOX_INT_H
.midrow:
    add edx, FW                               ; next row's interior-fill start
    lea edi, [edx - 1]
    mov byte [edi], T_V                        ; left wall (col 0)
    inc edi                                    ; advance past it before filling
    mov al, T_SP
    mov ecx, BOX_INT_W
    rep stosb                                 ; spaces col 1..18 (edi → col 19)
    mov byte [edi], T_V                        ; right wall (col 19)
    dec ebx
    jnz .midrow
    ; bottom border: └ + ─×18 + ┘
    add edx, FW
    lea edi, [edx - 1]
    mov byte [edi], T_BL                        ; col 0
    inc edi                                    ; advance past it before filling
    mov al, T_H
    mov ecx, BOX_INT_W
    rep stosb                                 ; ─×18 col 1..18 (edi → col 19)
    mov byte [edi], T_BR                        ; col 19

    ; --- intro text on the dialog message lines (PROJ battle: UI_DIALOG_LINE1/2) ---
    ; line 1: "Wild " + enemy mon nick (faithful _WildMonAppearedText; nick is the
    ; $50-terminated string in wEnemyMonNick).
    mov esi, intro_line1                       ; flat .data source
    lea edi, [ebp + W_TILEMAP + UI_DIALOG_LINE1_OFS]
    mov ecx, INTRO_LINE1_LEN
    rep movsb                                  ; "Wild "
    lea esi, [ebp + wEnemyMonNick]             ; GB WRAM nick
.introNick:
    mov al, [esi]
    inc esi
    cmp al, 0x50                               ; '@' terminator
    je .introNickDone
    mov [edi], al
    inc edi
    jmp .introNick
.introNickDone:
    mov esi, intro_line2
    lea edi, [ebp + W_TILEMAP + UI_DIALOG_LINE2_OFS]
    mov ecx, INTRO_LINE2_LEN
    rep movsb

    ; --- enemy HUD: a WILD mon is already "out", so it shows its HP bar during the
    ; intro; a TRAINER (wIsInBattle==2) hasn't sent a mon out yet, so the enemy side
    ; shows the trainer's pokéball row instead (drawn by the caller). ---
    cmp byte [ebp + wIsInBattle], 1
    jne .skipEnemyHUD
    call DrawEnemyHUD
.skipEnemyHUD:
    ret
