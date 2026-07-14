; trainer_card.asm — the player status / TRAINER CARD screen (menus-port
; Session 9). Faithful port of pret engine/menus/start_sub_menus.asm's
; DrawTrainerInfo + TrainerInfo_* helpers (pret files these in start_sub_menus.asm;
; the port hosts them here so start_sub_menus.asm stays the StartMenu_* dispatch).
;
; DrawTrainerInfo loads the trainer-card tile graphics into VRAM, displays Red's
; front pic upper-right, draws the NAME/MONEY/TIME box + the ○BADGES○ box, and
; prints the player name, money (BCD) and play time. StartMenu_TrainerInfo
; (start_sub_menus.asm) then calls DrawBadges (package B) for the 4×2 face/badge
; grid, composites the whole 20×18 screen as one window (trainer_card_present),
; and waits (WaitForTextScrollButtonPress) before restoring the overworld.
;
; GFX / VRAM (pret vChars addressing → port signed-BG addressing):
;   * badge faces + badges (badges.2bpp, 64 tiles) → vChars2 $20 : draw_badges.asm
;     LoadBadgeTiles (package B) does exactly this; DrawTrainerInfo calls it.
;   * box corner/edge tiles (trainer_info.2bpp 0-7)  → vChars2 $77 (ids $77-$7E)
;   * box background tile   (trainer_info.2bpp 8)     → vChars1 $57 (id  $D7)
;   * blank leader names    (blank_leader_names.2bpp) → vChars2 $60 (ids $60+)
;   * badge numbers         (badge_numbers.2bpp 8)    → vChars1 $58 (ids $D8+)
;   * colon glyph           (font_extra.2bpp tile 13) → vChars1 $56 (id  $D6)
;   * ○ circle              (circle_tile.2bpp)         → vChars2 $76 (id  $76)
;   In the port's $8800-signed BG addressing, tile id T in $00-$7F resolves to
;   GB_VCHARS2 + T*16 and a vChars1 tile N (GB_VCHARS1 + N*16) is addressed by
;   tilemap id (N-$80) — e.g. the colon at vChars1 $56 is drawn as id $D6, exactly
;   as pret does (`ld [hl],$d6`), the box bg at vChars1 $57 as id $D7, etc.
;   Tiles are carried in assets/trainer_card_tiles.inc (tools/gen_trainer_card_tiles.py,
;   Tier-1) except the faces/badges (assets/badge_tiles.inc, package B).
;
; PORT MODEL (CLAUDE.md + options.asm/pokedex_entry.asm precedent):
;   * SM83→x86: A=AL, BC=BX, DE=DX, HL=ESI, EBP = GB base; GB mem at [EBP+sym].
;   * Full-takeover screen: drawn at pret GB coords into the stride-20 W_TILEMAP
;     scratch (text_row_stride = 20; HL(X,Y)=W_TILEMAP+Y*20+X), then composited as
;     one full-screen window over a whited-out overworld (options.asm model).
;   * DisableLCD/EnableLCD bracket the VRAM tile loads (faithful); the port also
;     sets g_tilecache_dirty so the decoded-tile cache refreshes.
;
; Build (standalone check):
;   nasm -f coff -I include/ -I . -o /dev/null src/engine/menus/trainer_card.asm
; ---------------------------------------------------------------------------
bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

%define UI_LAYOUT_EQUATES_ONLY 1
%include "assets/ui_layout_menus.inc"

global DrawTrainerInfo
global trainer_card_present
global trainer_card_teardown

extern DisableLCD                    ; video/lcd_control.asm
extern EnableLCD
extern CopyData                      ; home/copy_data.asm — ESI src off, EDX dst off, BX count
extern CopyVideoData                 ; home/copy2.asm — ESI dest VRAM off, EDX flat src, BL tiles
extern PlaceString                   ; text/text.asm — ESI=dest, EAX=flat src
extern PrintNumber                   ; home/print_num.asm — ESI=dest, EDX=src, BH=flags|bytes, BL=digits
extern PrintBCDNumber                ; home/print_bcd.asm — ESI=dest, EDX=BCD src, BL=flags|len
extern LoadBadgeTiles                ; engine/menus/draw_badges.asm (pkg B) — faces/badges → vChars2 $20
extern LoadMonPicToVRAM              ; gfx/pics.asm — decode staged pic → [EDX] VRAM
extern PlayerPicFront                ; data/trainer_pics.asm — Red's compressed front .pic (red.pic)
extern g_tilecache_dirty             ; ppu/ppu.asm — set on any VRAM tile-data write
extern g_bg_whiteout                 ; ppu/ppu.asm
extern set_single_window             ; ppu/ppu.asm
extern menu_redraw_cb                ; home/window.asm — per-frame redraw cb (0=none)
extern text_row_stride               ; text/text.asm

; --- VRAM regions (pret vChars1 is not in gb_memmap; it is $8800) ---
TC_VCHARS1 equ 0x8800

; --- trainer-card union scratch (pret ram/wram.asm; sym-verified $CD3D block;
; the same union DrawBadges' wBadgeNumberTile/wBadgeNameTile reuse — both routines
; write every byte before reading it, no cross-dependency) ---
wTrainerInfoTextBoxWidthPlus1     equ 0xCD3D
wTrainerInfoTextBoxWidth          equ 0xCD3E
wTrainerInfoTextBoxNextRowOffset  equ 0xCD3F

TCSCR_W  equ 20                      ; stride-20 scratch (pret SCREEN_WIDTH)
%define HL(X,Y)  (W_TILEMAP + (Y) * TCSCR_W + (X))

; number-print flag bytes (constants/gfx_constants.asm bit positions)
NUM_MONEY_SIGN     equ 1 << BIT_MONEY_SIGN
NUM_LEFT_ALIGN     equ 1 << BIT_LEFT_ALIGN
NUM_LEADING_ZERO   equ 1 << BIT_LEADING_ZEROES

; PROJ menus: front pic → VRAM $9000 (GB_VCHARS2), the verified battle/dex front-pic
; dest; PIC_STAGE staging matches gfx/pics.asm.
PIC_STAGE_GB equ 0xA4A0              ; GB scratch for the compressed input stream (pics.asm)
PLAYER_PIC_LEN equ 255              ; red.pic byte length (gfx/player/red.pic)

; ===========================================================================
section .data
align 4
%include "assets/trainer_card_tiles.inc"

; TrainerInfo_NameMoneyTimeText ("NAME/" <NEXT> "MONEY/" <NEXT> "TIME/@") and
; TrainerInfo_BadgesText ($76 "BADGES" $76 "@") are Tier-1 DATA, generated by
; tools/gen_menu_strings.py through the charmap (gb_text.encode). They were
; hand-encoded `db 0x8D,0x80,...` here until 2026-07-13 — the Tier-1 violation
; CLAUDE.md names explicitly. The generated bytes are byte-identical to the
; literals they replace ('/' encodes to $F3 through the charmap; only <NEXT> $4E,
; '@' $50 and the ○ TILE $76 are raw bytes — and pret writes that one as a byte too).
;
; The NAME/MONEY/TIME labels are double-spaced (rows 2,4,6) to line up with the value
; coords (name (7,2), money (8,4), time (9,6)): BIT_SINGLE_SPACED_LINES is cleared
; before PlaceString so <NEXT> advances two rows (players_pc.asm model).
%include "assets/trainer_card_strings.inc"

; ===========================================================================
section .text

; ---------------------------------------------------------------------------
; DrawTrainerInfo — pret ref: start_sub_menus.asm:DrawTrainerInfo.
; loads tile patterns and draws everything except the gym-leader faces / badges
; (StartMenu_TrainerInfo calls DrawBadges after this). In: EBP = GB base.
; ---------------------------------------------------------------------------
DrawTrainerInfo:
    mov dword [text_row_stride], TCSCR_W        ; port: this screen owns the stride-20 scratch
    ; ld de, RedPicFront / lb bc, BANK, $01 / predef DisplayPicCenteredOrUpperRight
    ; — display Red's front pic upper-right (c=$01).
    ; DEVIATION(missing-predef): DisplayPicCenteredOrUpperRight is not translated
    ; (label DB: missing). TrainerInfo_DisplayPlayerPic below does the c=$01 half of it
    ; for this one caller — see its header for the pic path and the column clamp. Retire
    ; it when the predef lands: this call becomes the predef with de/bc as pret sets them.
    call TrainerInfo_DisplayPlayerPic
    call DisableLCD
    ; hlcoord 0,2 / ' ' vline ; hlcoord 1,2 / ' ' vline — blank the two columns the
    ; pic's left edge would otherwise occupy behind the name box.
    mov esi, HL(0, 2)
    mov al, 0x7F                                ; ' '
    call TrainerInfo_DrawVerticalLine
    mov esi, HL(1, 2)
    mov al, 0x7F
    call TrainerInfo_DrawVerticalLine
    ; ld hl, vChars2 tile $07 / ld de, vChars2 tile $00 / ld bc, $1c tiles / CopyData
    ; — compact the decoded pic down a column so it fits below the badge-face range.
    mov esi, GB_VCHARS2 + 0x07 * TILE_SIZE
    mov edx, GB_VCHARS2 + 0x00 * TILE_SIZE
    mov bx, 0x1c * TILE_SIZE
    call CopyData
    mov byte [g_tilecache_dirty], 1              ; CopyData is the generic GB-space copier
                                                 ; and does NOT arm the cache; this one
                                                 ; lands in VRAM, so arm it by hand.
    ; --- load the trainer-card tile graphics into VRAM ---
    ; Each of these was a hand-rolled `rep movsd` into vChars until 2026-07-13, with
    ; one `mov [g_tilecache_dirty],1` at the end of the run covering all of them. Not a
    ; live bug (the flag WAS armed), but correct-by-accident: it is exactly the raw-VRAM
    ; -write pattern that has shipped visible corruption twice. They now go through the
    ; primitive, which arms the cache itself — correct by construction (CLAUDE.md).
    ; TrainerInfoTextBoxTileGraphics (8 box tiles) → vChars2 $77
    mov esi, GB_VCHARS2 + 0x77 * TILE_SIZE
    mov edx, tc_box_tiles
    mov bx, TC_BOX_TILE_COUNT
    call TrainerInfo_FarCopyData
    ; BlankLeaderNames → vChars2 $60, `ld bc, $17 tiles` = 23 tiles.
    ; blank_leader_names.2bpp is only 22 tiles: the 23rd tile pret copies is CircleTile,
    ; which gfx/trainer_card.asm lays down immediately after it. So the ○ lands at
    ; vChars2 $60 + 22 = $76 — the tile id TrainerInfo_BadgesText prints — as a free
    ; rider on THIS copy. CircleTile has no load and no referencer anywhere else in pret.
    ; The port reproduces the adjacency in assets/trainer_card_tiles.inc (asserted by
    ; the generator) and copies TC_BLANK_NAME_COPY_COUNT = 23, exactly as pret does.
    ; Until 2026-07-13 the port copied 22 and then loaded tc_circle_tile to $76 in a
    ; separate write — same pixels, but an invented load with no pret counterpart.
    mov esi, GB_VCHARS2 + 0x60 * TILE_SIZE
    mov edx, tc_blank_name_tiles
    mov bx, TC_BLANK_NAME_COPY_COUNT
    call TrainerInfo_FarCopyData
    ; GymLeaderFaceAndBadgeTileGraphics → vChars2 $20.
    ; DEVIATION(port-split): pret loads the 8*8 face/badge tiles inline here with a plain
    ; `call FarCopyData`. The port's badge package owns that exact load as LoadBadgeTiles
    ; (draw_badges.asm) — the same tiles to the same address — because DrawBadges needs it
    ; too and would otherwise duplicate it. Same bytes, one owner.
    call LoadBadgeTiles
    ; BadgeNumbersTileGraphics → vChars1 $58 (drawn as ids $D8+)
    mov esi, TC_VCHARS1 + 0x58 * TILE_SIZE
    mov edx, tc_badge_number_tiles
    mov bx, TC_BADGE_NUM_COUNT
    call TrainerInfo_FarCopyData
    ; colon glyph (TextBoxGraphics tile 13) → vChars1 $56 (id $D6).
    ; pret reaches this one with a plain FarCopyData (different source bank); flat, that
    ; is the same copy as any other — kept distinct only to mirror pret's structure.
    mov esi, TC_VCHARS1 + 0x56 * TILE_SIZE
    mov edx, tc_colon_tile
    mov bx, 1
    call TrainerInfo_FarCopyData
    ; box background tile (trainer_info tile 8) → vChars1 $57 (id $D7)
    mov esi, TC_VCHARS1 + 0x57 * TILE_SIZE
    mov edx, tc_bg_tile
    mov bx, 1
    call TrainerInfo_FarCopyData
    ; (no separate ○ load — it rode in on the BlankLeaderNames copy above, as in pret)
    call EnableLCD
    ; --- top NAME/MONEY/TIME box: width 18, at (0,0) ---
    mov byte [ebp + wTrainerInfoTextBoxWidthPlus1], 18 + 1
    mov byte [ebp + wTrainerInfoTextBoxWidth], 18
    mov byte [ebp + wTrainerInfoTextBoxNextRowOffset], 1        ; SCREEN_WIDTH - (18+1)
    mov esi, HL(0, 0)
    call TrainerInfo_DrawTextBox
    ; --- inner box: width 16, at (1,10) ---
    mov byte [ebp + wTrainerInfoTextBoxWidthPlus1], 16 + 1
    mov byte [ebp + wTrainerInfoTextBoxWidth], 16
    mov byte [ebp + wTrainerInfoTextBoxNextRowOffset], 3        ; SCREEN_WIDTH - (16+1)
    mov esi, HL(1, 10)
    call TrainerInfo_DrawTextBox
    ; vertical lines framing the badge box (tile $d7 = box bg)
    mov esi, HL(0, 10)
    mov al, 0xD7
    call TrainerInfo_DrawVerticalLine
    mov esi, HL(19, 10)
    mov al, 0xD7
    call TrainerInfo_DrawVerticalLine
    ; ○BADGES○ label at (6,9)
    mov esi, HL(6, 9)
    mov eax, TrainerInfo_BadgesText
    call PlaceString
    ; NAME/MONEY/TIME labels at (2,2). The <NEXT>s land them on rows 2, 4 and 6 (to
    ; line up with the values at (7,2)/(8,4)/(9,6)) because PlaceNextChar double-spaces
    ; <NEXT> whenever BIT_SINGLE_SPACED_LINES is CLEAR (home/text.asm) — which pret
    ; simply assumes here, and so do we. Until 2026-07-13 the port cleared the bit
    ; explicitly first: an ADDED store with no pret counterpart, defending against a
    ; leak that cannot happen. Every setter of that bit, in pret and in the port alike
    ; (learn_move, battle/core, save, printer2), re-clears it a few instructions later;
    ; nothing can reach a screen with it set. Papering over it in one screen would only
    ; hide a genuine leak if one ever appeared.
    mov esi, HL(2, 2)
    mov eax, TrainerInfo_NameMoneyTimeText
    call PlaceString
    ; player name at (7,2)
    mov esi, HL(7, 2)
    lea eax, [ebp + wPlayerName]
    call PlaceString
    ; money (BCD) at (8,4): c = 3 | LEADING_ZEROES | LEFT_ALIGN | MONEY_SIGN
    mov esi, HL(8, 4)
    mov edx, wPlayerMoney
    mov bl, 3 | NUM_LEADING_ZERO | NUM_LEFT_ALIGN | NUM_MONEY_SIGN
    call PrintBCDNumber
    ; play time hours at (9,6): b = LEFT_ALIGN|1, c = 3
    mov esi, HL(9, 6)
    mov edx, wPlayTimeHours
    mov bh, NUM_LEFT_ALIGN | 1
    mov bl, 3
    call PrintNumber
    mov byte [ebp + esi], 0xD6                   ; colon tile id
    inc esi
    ; play time minutes: b = LEADING_ZEROES|1, c = 2
    mov edx, wPlayTimeMinutes
    mov bh, NUM_LEADING_ZERO | 1
    mov bl, 2
    jmp PrintNumber                              ; tail (pret jp PrintNumber)

; ---------------------------------------------------------------------------
; TrainerInfo_FarCopyData — pret ref: start_sub_menus.asm:TrainerInfo_FarCopyData
;   ld a, BANK(TrainerInfoTextBoxTileGraphics) / jp FarCopyData
; i.e. it exists purely to fix the source bank for the four loads above; the copy
; itself is FarCopyData (hl = src, de = dest, bc = BYTE count).
;
; In:  ESI = destination GB VRAM offset   (pret de)
;      EDX = source FLAT pointer          (pret hl)
;      BX  = tile count                   (pret bc, in BYTES)
;
; DEVIATION(port-primitive): the tail is CopyVideoData, not FarCopyData. Two
; reasons, both structural rather than cosmetic:
;   * the bank byte pret sets here is a NO-OP under the flat model (the tile
;     assets are flat .data labels), so the routine's entire pret payload is gone
;     and only the tail remains;
;   * every one of these copies targets VRAM tile patterns, and CopyVideoData is
;     the port's VRAM-tile primitive: it arms g_tilecache_dirty itself. FarCopyData
;     does not (it is the generic GB-space copier), so routing these through it
;     would reintroduce the raw-VRAM-write hazard by construction.
; The count is therefore in TILES (CopyVideoData's BL), not bytes.
; ---------------------------------------------------------------------------
TrainerInfo_FarCopyData:
    jmp CopyVideoData                            ; pret: jp FarCopyData

; ---------------------------------------------------------------------------
; TrainerInfo_DisplayPlayerPic — port of the DisplayPicCenteredOrUpperRight
; RedPicFront call. Stages PlayerPicFront (red.pic, 7×7) into GB scratch, decodes
; + merges it to GB_VCHARS2 (49 tiles at ids $00+), and places the tilemap at the
; upper-right (pret hlcoord 15,1, hStartTileID 0). DEVIATION(pic): the placement is
; clamped to the on-screen columns (15-19) so the 7-wide block does not wrap the
; 20-wide scratch; the VRAM shift in DrawTrainerInfo keeps the faces' $20 range
; free exactly as pret. In: EBP = GB base.
; ---------------------------------------------------------------------------
TrainerInfo_DisplayPlayerPic:
    ; stage the compressed pic into GB scratch (pics.asm PIC_STAGE contract)
    mov esi, PlayerPicFront
    lea edi, [ebp + PIC_STAGE_GB]
    mov ecx, PLAYER_PIC_LEN
    rep movsb
    mov word [ebp + wSpriteInputPtr], PIC_STAGE_GB
    mov byte [ebp + wSpriteFlipped], 0
    mov al, [ebp + PIC_STAGE_GB]                 ; dims byte (0x77 = 7×7)
    mov edx, GB_VCHARS2                           ; decode/merge dest
    call LoadMonPicToVRAM
    ; place the tilemap upper-right: column-major, id = col*7 + row, from HL(15,1),
    ; clamped to the 5 visible columns (15-19). DEVIATION(pic): clamp, see header.
    xor ebx, ebx                                  ; col
.col:
    movzx eax, bl
    imul eax, eax, 7                              ; base id for this column
    mov ecx, 7                                    ; rows
    mov esi, HL(15, 1)
    add esi, ebx                                  ; column offset within row
.row:
    mov [ebp + esi], al
    add esi, TCSCR_W
    inc al
    dec ecx
    jnz .row
    inc ebx
    cmp ebx, 5                                    ; only cols 15-19 fit the 20-wide scratch
    jb .col
    ret

; ---------------------------------------------------------------------------
; TrainerInfo_DrawTextBox — pret ref: start_sub_menus.asm:TrainerInfo_DrawTextBox.
; height is always 6. In: ESI = dest (HL); [wTrainerInfoTextBox*] configured.
; ---------------------------------------------------------------------------
TrainerInfo_DrawTextBox:
    mov al, 0x79                                 ; upper-left corner
    mov dh, 0x7A                                 ; top edge (d)
    mov dl, 0x7B                                 ; upper-right corner (e)
    call TrainerInfo_DrawHorizontalEdge          ; top edge
    call TrainerInfo_NextTextBoxRow
    movzx edx, byte [ebp + wTrainerInfoTextBoxWidthPlus1]  ; ld e,a / ld d,0 → de = width+1
    mov ecx, 6                                    ; height (pret C; NextTextBoxRow
                                                  ; clobbers ECX, so preserve it)
.loop:
    mov byte [ebp + esi], 0x7C                    ; left edge
    add esi, edx
    mov byte [ebp + esi], 0x78                    ; right edge
    push ecx
    call TrainerInfo_NextTextBoxRow
    pop ecx
    dec ecx
    jnz .loop
    mov al, 0x7D                                  ; lower-left corner
    mov dh, 0x77                                  ; bottom edge (d)
    mov dl, 0x7E                                  ; lower-right corner (e)
    ; fall through to TrainerInfo_DrawHorizontalEdge

; In: AL = corner tile, DH = edge tile, DL = far corner tile; ESI = dest (HL).
TrainerInfo_DrawHorizontalEdge:
    mov [ebp + esi], al                          ; left corner
    inc esi
    movzx ecx, byte [ebp + wTrainerInfoTextBoxWidth]
    mov al, dh                                    ; edge tile (a = d)
.loop:
    mov [ebp + esi], al
    inc esi
    dec ecx
    jnz .loop
    mov al, dl                                    ; far corner (a = e)
    mov [ebp + esi], al
    ret

; In: ESI = HL; advances ESI by [wTrainerInfoTextBoxNextRowOffset] (+the prior inc).
TrainerInfo_NextTextBoxRow:
    movzx ecx, byte [ebp + wTrainerInfoTextBoxNextRowOffset]
.loop:
    inc esi
    dec ecx
    jnz .loop
    ret

; ---------------------------------------------------------------------------
; TrainerInfo_DrawVerticalLine — pret ref: start_sub_menus.asm.
; In: ESI = top tile (HL), AL = tile id. Draws 8 rows (stride SCREEN_WIDTH=20).
; ---------------------------------------------------------------------------
TrainerInfo_DrawVerticalLine:
    mov ecx, 8
.loop:
    mov [ebp + esi], al
    add esi, TCSCR_W                              ; ld de, SCREEN_WIDTH
    dec ecx
    jnz .loop
    ret

; ===========================================================================
; Port window bridge (DEVIATION — full-takeover compositor; options.asm model).
; trainer_card_present mirrors the finished stride-20 scratch (rows 0-17) →
; GB_TILEMAP1 and exposes it as one full-screen window over a whited-out
; overworld, arming the per-frame mirror so WaitForTextScrollButtonPress sees a
; stable image. trainer_card_teardown drops the window + whiteout + mirror.
; ; PROJ menus: full-screen 20×18 window (reuses UI_OPTIONS anchor geometry).
; ===========================================================================
trainer_card_present:
    mov dword [g_bg_whiteout], 1                  ; full takeover behind the card
    call tc_mirror
    mov eax, UI_OPTIONS_WX
    mov ebx, UI_OPTIONS_WY
    mov ecx, UI_OPTIONS_CLIP
    mov edx, UI_OPTIONS_MAXY
    mov esi, GB_TILEMAP1
    xor edi, edi
    call set_single_window
    mov dword [menu_redraw_cb], tc_mirror
    ret

trainer_card_teardown:
    mov dword [menu_redraw_cb], 0
    mov dword [g_bg_whiteout], 0
    ret

; tc_mirror — blit the stride-20 scratch rows 0-17 → GB_TILEMAP1 rows 0-17
; (pad cols 20-31). Preserves all registers (doubles as menu_redraw_cb).
tc_mirror:
    pushad
    mov ecx, 18
    lea esi, [ebp + W_TILEMAP]
    lea edi, [ebp + GB_TILEMAP1]
.row:
    push ecx
    push esi
    push edi
    mov ecx, 20
    rep movsb
    mov al, 0x7F
    mov ecx, 12                                   ; pad cols 20-31
    rep stosb
    pop edi
    pop esi
    add esi, TCSCR_W
    add edi, 32
    pop ecx
    dec ecx
    jnz .row
    popad
    ret

; ===========================================================================
%ifdef DEBUG_TRAINERCARD
; ---------------------------------------------------------------------------
; RunTrainerCardTest — menus S9 gate. Seeds the player name / money / play time /
; badges, loads the font + text-box tiles, draws the full TRAINER CARD
; (DrawTrainerInfo + DrawBadges), composites it, dumps FRAME.BIN and exits (the
; live StartMenu_TrainerInfo blocks on WaitForTextScrollButtonPress). Never
; returns. In: EBP = GB base. Called from EnterMap after the overworld loads.
; make SKIP_TITLE=1 DEBUG_TRAINERCARD=1
; ---------------------------------------------------------------------------
extern LoadFontTilePatterns          ; gfx/load_font.asm
extern LoadTextBoxTilePatterns       ; gfx/load_font.asm
extern ClearSprites                  ; gfx/sprites.asm
extern DrawBadges                    ; engine/menus/draw_badges.asm
extern FillMemory                    ; home/fill_memory.asm
extern DelayFrame                    ; video/frame.asm
extern DumpBackbuffer                ; debug/debug_dump.asm
extern SeedDeterministicPlayerIdentity ; engine/debug/debug_party.asm — "RED"/id 0 (seed.lua spec)
global RunTrainerCardTest
RunTrainerCardTest:
    ; player name "RED@" + wPlayerID = 0: the shared golden identity spec. The
    ; old hand-poked name left wPlayerID as InitPlayerData's RNG roll (F-5
    ; class), which the trainer_card golden's wPlayerID region would catch.
    call SeedDeterministicPlayerIdentity
    ; money = 123456 (3-byte BCD)
    mov byte [ebp + wPlayerMoney + 0], 0x12
    mov byte [ebp + wPlayerMoney + 1], 0x34
    mov byte [ebp + wPlayerMoney + 2], 0x56
    ; play time 5:30 (binary)
    mov byte [ebp + wPlayTimeHours], 5
    mov byte [ebp + wPlayTimeMinutes], 30
    ; badges 1,3,6,8 owned = %10100101
    mov byte [ebp + W_OBTAINED_BADGES], 0xA5
    or byte [ebp + W_FONT_LOADED], (1 << BIT_FONT_LOADED)
    call LoadFontTilePatterns
    call LoadTextBoxTilePatterns
    call ClearSprites
    mov byte [ebp + W_UPDATE_SPRITES_ENABLED], 0
    ; blank the stride-20 scratch (18 rows × 20)
    mov esi, W_TILEMAP
    mov bx, 18 * TCSCR_W
    mov al, 0x7F
    call FillMemory
    call DrawTrainerInfo
    call DrawBadges
    call trainer_card_present
    call DelayFrame
    call DelayFrame
    call DelayFrame
    call DumpBackbuffer                       ; writes FRAME.BIN + exits
.hang:
    jmp .hang
%endif
