; pokedex.asm — the POKéDEX menu/list half (menus S8, package G1).
;
; Faithful port of the MENU/LIST portion of pret engine/menus/pokedex.asm
; (ShowPokedexMenu + HandlePokedexSideMenu + HandlePokedexListMenu +
; Pokedex_DrawInterface + DrawPokedexVerticalLine + Pokedex_PlacePokemonList +
; IsPokemonBitSet + DrawTileLine + PokedexToIndex + IndexToPokedex, plus the
; text tables). The DATA-entry half (ShowPokedexData/ShowPokedexDataInternal,
; dex entry drawing, flavour text) is package G2's pokedex_entry.asm — this file
; `extern`s ShowPokedexDataInternal from it and `global`s the four cross-half
; helpers (PokedexToIndex/IndexToPokedex/IsPokemonBitSet/DrawTileLine) G2 calls.
;
; Same routines, same labels, same branch structure/order as pret; divergences
; are tagged PROJ / TODO-HW / DEVIATION / STUB only.
;
; PORT MODEL (full-screen takeover, same shape as options.asm / naming_screen.asm):
; - The whole screen is drawn at pret GB coords into the 20-wide stride-20
;   W_TILEMAP scratch (hlcoord X,Y = W_TILEMAP + Y*20 + X via the local HL(x,y)
;   macro; GBSCR_W = 20 = pret SCREEN_WIDTH). pret's SCREEN_WIDTH is 20 EVERYWHERE
;   in this file (constants/hardware.inc) — do NOT use the port's SCREEN_WIDTH=40.
; - One full-screen window (pdex_show_window) shows the scratch, sourced from
;   GB_TILEMAP1 rows 0-17 at the UI_POKEDEX_MAIN anchor; g_bg_whiteout blanks the
;   overworld behind it. pdex_mirror blits the stride-20 scratch -> GB_TILEMAP1
;   each frame; it is installed as HandleMenuInput's menu_redraw_cb so the fresh
;   list + counts + cursor reach the window (pret's hAutoBGTransferEnabled VBlank
;   auto-transfer has no literal equivalent — same explicit-mirror pattern as
;   options_mirror / naming_mirror / S5 PartyMenuMirror).
; - The side menu (DATA/CRY/AREA/PRNT/QUIT) is a SUB-RECT of the main window (not
;   its own window): it draws into the same stride-20 scratch and rides the same
;   HandleMenuInput/mirror. UI_POKEDEX_SIDE_MENU_* is therefore documentary here.
; - Both the list menu (rows 3,5,7,…,15) and the side menu (rows 8,10,12,14,16)
;   are DOUBLE-spaced, so menu_item_step = 2*GBSCR_W and the menu-items text's
;   <NEXT> advances 2 rows (default hUILayoutFlags, BIT_SINGLE_SPACED_LINES clear).
;
; ; PROJ menus: box + list + side menu project onto the UI_POKEDEX_MAIN window
;   (GB(0,0) 20x18 --(center/top, X+10)--> wx=87 wy=0 clip=160 max_y=144
;   [UI_POKEDEX_MAIN_*]). Side menu sub-rect: UI_POKEDEX_SIDE_MENU_* (GB 15,8 5x9).
;
; Register map (CLAUDE.md): A=AL, BC=BX (B=BH,C=BL), DE=DX (D=DH,E=DL),
; HL=ESI, EBP = GB memory base; GB memory is [ebp + symbol].
;
; Build (standalone check):
;   nasm -f coff -I include/ -I . -o /dev/null src/engine/menus/pokedex.asm
; ---------------------------------------------------------------------------
bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_macros.inc"

%define UI_LAYOUT_EQUATES_ONLY 1
%include "assets/ui_layout_menus.inc"

global ShowPokedexMenu
global HandlePokedexSideMenu
global HandlePokedexListMenu
global Pokedex_DrawInterface
global DrawPokedexVerticalLine
global Pokedex_PlacePokemonList
; cross-half seam (G2 calls these):
global IsPokemonBitSet
global DrawTileLine
global PokedexToIndex
global LoadPokedexTilePatterns       ; shared no-op stub (G2 externs it)
extern IndexToPokedex                ; base_stats.inc — index->dex TABLE (== pret PokedexOrder)

; ---- externs -------------------------------------------------------------
extern GBPalWhiteOut                 ; home/fade.asm
extern GBPalWhiteOutWithDelay3       ; home/fade.asm
extern GBPalNormal                   ; init/init.asm
extern RunPaletteCommand             ; engine/battle/faint_switch.asm — palette HAL (no-op stub)
extern ReloadMapData                 ; home/reload_tiles.asm
extern LoadHpBarAndStatusTilePatterns ; gfx/load_font.asm — pret loader's 1st step
extern g_tilecache_dirty             ; ppu.asm — set after any VRAM tile write
extern ClearScreen                   ; movie/title.asm
extern UpdateSprites                 ; engine/overworld/movement.asm
extern Delay3                        ; video/frame.asm — 3× DelayFrame
extern DelayFrame                    ; video/frame.asm
extern HandleMenuInput               ; home/window.asm — vertical menu input driver → AL
extern PlaceUnfilledArrowMenuCursor  ; home/window.asm
extern menu_item_step                ; home/window.asm — cursor per-item row step
extern menu_redraw_cb                ; home/window.asm — per-cursor redraw callback
extern text_row_stride               ; text/text.asm — active W_TILEMAP row stride
extern PlaceString                   ; text/text.asm — ESI=dest, EAX=flat src
extern PrintNumber                   ; home/print_num.asm — EDX=src, BH=flags|bytes, BL=digits, ESI=dest
extern TextBoxBorder                 ; text/text.asm (unused here, kept out)
extern CountSetBits                  ; home/count_set_bits.asm — ESI=addr, BH=len → [wNumSetBits]
extern FlagAction                    ; engine/flag_action.asm — ESI=field, CL=bit, BH=action → CL
extern GetMonName                    ; home/names.asm — [wNamedObjectIndex] → wNameBuffer
extern set_single_window             ; ppu/ppu.asm
extern g_bg_whiteout                 ; ppu/ppu.asm
extern PlaySound                     ; engine/battle/move_effect_helpers.asm — audio HAL stub
; ShowPokedexDataInternal is defined by G2 (pokedex_entry.asm); the .choseData
; side-menu path calls it. At standalone `make check` this is an unresolved
; extern (link is finalized by ROOT at integration — G1↔G2 seam).
extern ShowPokedexDataInternal       ; engine/menus/pokedex_entry.asm (G2)

; ---- local equates (Tier-2 UI/index enums; not gb_memmap data) -----------
; pret ref: constants/palette_constants.asm
SET_PAL_GENERIC   equ 0x08
SET_PAL_DEFAULT   equ 0xFF

GBSCR_W           equ 20            ; pret SCREEN_WIDTH — the stride-20 scratch
LEADING_ZEROES    equ 0x80         ; PrintNumber BH flag (BIT_LEADING_ZEROES = 7)

; Raw tile ids drawn directly (charmap glyphs written as tile bytes).
TILE_HLINE        equ 0x7A         ; '─'   pokedex horizontal divider
TILE_VLINE        equ 0x71         ; vertical line tile ($70 = box tile, toggled)
TILE_POKEBALL     equ 0x72         ; owned-mon marker
TILE_BLANK        equ 0x7F         ; ' '

; wDexMaxSeenMon (0xCD3D) is defined in gb_memmap.inc (sym-verified, S8).

; hlcoord X,Y helper (stride-20 scratch)
%define HL(X,Y)  (W_TILEMAP + (Y) * GBSCR_W + (X))

; ===========================================================================
section .data
; (PokedexToIndex walks the existing global IndexToPokedex table from
; base_stats.inc — byte-identical to pret's PokedexOrder — so no separate
; dex-order table is emitted here.)

; Pokédex interface tileset (PokedexTileGraphics 18 tiles + PokeballTileGraphics
; 1 tile) — generated passthrough of gfx/pokedex/pokedex.2bpp + balls.2bpp.
%include "assets/pokedex_tiles.inc"

; pret ref: engine/menus/pokedex.asm text tables (charmap: 'A'=$80, ' '=$7F,
; '@'=$50, '─'=$7A, <NEXT>=$4E). Tier-2 hand-authored charmap bytes.
PokedexSeenText:                      ; pret ref: PokedexSeenText  "SEEN@"
    db 0x92, 0x84, 0x84, 0x8D, 0x50
PokedexOwnText:                       ; pret ref: PokedexOwnText   "OWN@"
    db 0x8E, 0x96, 0x8D, 0x50
PokedexContentsText:                  ; pret ref: PokedexContentsText  "CONTENTS@"
    db 0x82, 0x8E, 0x8D, 0x93, 0x84, 0x8D, 0x93, 0x92, 0x50
PokedexMenuItemsText:                 ; pret ref: PokedexMenuItemsText
    db 0x83, 0x80, 0x93, 0x80          ; "DATA"
    db 0x4E                            ; <NEXT>
    db 0x82, 0x91, 0x98                ; "CRY"
    db 0x4E
    db 0x80, 0x91, 0x84, 0x80          ; "AREA"
    db 0x4E
    db 0x8F, 0x91, 0x8D, 0x93          ; "PRNT"
    db 0x4E
    db 0x90, 0x94, 0x88, 0x93, 0x50    ; "QUIT@"

; ===========================================================================
section .text

; ---------------------------------------------------------------------------
; ShowPokedexMenu — pret ref: engine/menus/pokedex.asm:ShowPokedexMenu.
; Top-level entry: white out, clear, prime the list-menu state, then loop the
; list menu; A on a mon → side menu; dispatch the side menu's exit code; exit
; restores the scroll offset and reloads the map. In: EBP = GB base.
; ---------------------------------------------------------------------------
ShowPokedexMenu:
    call GBPalWhiteOut
    call ClearScreen
    call UpdateSprites
    ; port: this screen owns the stride-20 scratch (like options/naming).
    mov dword [text_row_stride], GBSCR_W
    movzx eax, byte [ebp + wListScrollOffset]
    push eax                                 ; save wListScrollOffset (pret push af)
    xor al, al
    mov [ebp + wCurrentMenuItem], al
    mov [ebp + wListScrollOffset], al
    mov [ebp + wLastMenuItem], al
    inc al
    mov [ebp + wPokedexNum], al
    mov [ebp + H_JOY7], al                   ; ldh [hJoy7], a
.setUpGraphics:
    call LoadPokedexTilePatterns             ; pret: callfar LoadPokedexTilePatterns
.loop:
    ; TODO-HW: palette HAL — pret: ld b, SET_PAL_GENERIC / call RunPaletteCommand.
    mov bl, SET_PAL_GENERIC                   ; port RunPaletteCommand no-op stub
    call RunPaletteCommand
.doPokemonListMenu:
    ; pret: ld hl,wTopMenuItemY / walk hli setting the menu fields. Direct field
    ; writes of the same addresses/values (same effect, no control-flow change).
    mov byte [ebp + wTopMenuItemY], 3
    mov byte [ebp + wTopMenuItemX], 0
    mov byte [ebp + wMenuWatchMovingOutOfBounds], 1
    mov byte [ebp + wMaxMenuItem], 6
    mov byte [ebp + wMenuWatchedKeys], PAD_LEFT | PAD_RIGHT | PAD_B | PAD_A
    call HandlePokedexListMenu
    jc .goToSideMenu                          ; carry: player chose a pokemon
.exitPokedex:
    xor al, al
    mov [ebp + wMenuWatchMovingOutOfBounds], al
    mov [ebp + wCurrentMenuItem], al
    mov [ebp + wLastMenuItem], al
    mov [ebp + H_JOY7], al
    mov [ebp + W_UNUSED_OVERRIDE_SIMULATED_JOYPAD_STATES_INDEX], al
    mov [ebp + W_OVERRIDE_SIMULATED_JOYPAD_STATES_MASK], al
    pop eax                                   ; restore saved wListScrollOffset
    mov [ebp + wListScrollOffset], al
    mov dword [menu_redraw_cb], 0             ; port: unhook our per-frame mirror
    call GBPalWhiteOutWithDelay3
    call RunDefaultPaletteCommand
    jmp ReloadMapData                         ; tail (pret: jp ReloadMapData)

.goToSideMenu:
    call HandlePokedexSideMenu                 ; returns BH = exit reason
    dec bh
    jz .exitPokedex                            ; b==1: chose Quit
    dec bh
    jz .doPokemonListMenu                       ; b==2: unseen / B pressed
    dec bh
    jz .loop                                   ; b==3: print (reload palette+list)
    jmp .setUpGraphics                          ; b==0: data/area shown (reload gfx)

; ---------------------------------------------------------------------------
; HandlePokedexSideMenu — pret ref: pokedex.asm:HandlePokedexSideMenu.
; The lower-right DATA/CRY/AREA/PRNT/QUIT menu. Saves 5 WRAM bytes across the
; menu; bails (b=2) if the highlighted mon is unseen. Out: BH = exit reason:
;   0 = data or area shown, 1 = Quit, 2 = unseen or B pressed, 3 = print.
; ---------------------------------------------------------------------------
HandlePokedexSideMenu:
    call PlaceUnfilledArrowMenuCursor          ; grey out the list cursor
    movzx eax, byte [ebp + wCurrentMenuItem]
    push eax                                   ; [P1] save wCurrentMenuItem
    mov bh, al                                 ; ld b, a
    movzx eax, byte [ebp + wLastMenuItem]
    push eax                                   ; [P2] save wLastMenuItem
    movzx eax, byte [ebp + wListScrollOffset]
    push eax                                   ; [P3] save wListScrollOffset
    add al, bh                                 ; add b (scroll + current item)
    inc al
    mov [ebp + wPokedexNum], al
    movzx eax, byte [ebp + wPokedexNum]        ; ld a,[wPokedexNum] (faithful reload)
    push eax                                   ; [P4] save wPokedexNum
    movzx eax, byte [ebp + wDexMaxSeenMon]
    push eax                                   ; [P5] save wDexMaxSeenMon
    mov esi, wPokedexSeen                       ; ld hl, wPokedexSeen
    call IsPokemonBitSet                        ; ZF set = unseen (and a inside)
    mov bh, 2                                   ; ld b, 2  (does not disturb flags)
    jz .exitSideMenu                            ; unseen → bail
    call PokedexToIndex
    ; pret: ld hl,wTopMenuItemY / hli walk. Direct writes (same addrs/values).
    mov byte [ebp + wTopMenuItemY], 8
    mov byte [ebp + wTopMenuItemX], 15
    mov byte [ebp + wCurrentMenuItem], 0
    mov byte [ebp + wMaxMenuItem], 4
    mov byte [ebp + wMenuWatchedKeys], PAD_A | PAD_B
    mov byte [ebp + wLastMenuItem], 0
    mov byte [ebp + wMenuWatchMovingOutOfBounds], 0
    mov byte [ebp + H_JOY7], 0
    ; port: side menu is a sub-rect of the main window; double-spaced rows.
    mov dword [menu_item_step], 2 * GBSCR_W
    mov dword [menu_redraw_cb], pdex_mirror
.handleMenuInput:
    call HandleMenuInput                        ; → AL = pressed keys
    test al, PAD_B                              ; bit B_PAD_B, a
    mov bh, 2                                    ; ld b, 2 (flags preserved)
    jnz .buttonBPressed
    mov al, [ebp + wCurrentMenuItem]
    and al, al
    jz .choseData
    dec al
    jz .choseCry
    dec al
    jz .choseArea
    dec al
    ; pret vc_patch Forbid_printing_Pokedex: _YELLOW_VC forbids printing (jr z to
    ; .handleMenuInput, a no-op). The ELSE (non-VC) build dispatches to .chosePrint;
    ; ported faithfully — .chosePrint itself is a STUB (printer out of scope).
    jz .chosePrint
    ; fell through: chose Quit
    mov bh, 1                                    ; ld b, 1
.exitSideMenu:
    pop eax                                      ; [P5]
    mov [ebp + wDexMaxSeenMon], al
    pop eax                                      ; [P4]
    mov [ebp + wPokedexNum], al
    pop eax                                      ; [P3]
    mov [ebp + wListScrollOffset], al
    pop eax                                      ; [P2]
    mov [ebp + wLastMenuItem], al
    pop eax                                      ; [P1]
    mov [ebp + wCurrentMenuItem], al
    mov byte [ebp + H_JOY7], 1                   ; ld a,$1 / ldh [hJoy7],a
    push ebx                                      ; push bc — save exit code (BH)
    mov esi, HL(0, 3)                             ; hlcoord 0,3
    mov edx, GBSCR_W                              ; ld de, 20 (vertical stride)
    mov bh, TILE_BLANK                            ; lb bc, ' ', 13
    mov bl, 13
    call DrawTileLine                             ; cover the list menu cursor column
    pop ebx                                       ; restore exit code
    ret

.buttonBPressed:
    push ebx                                       ; push bc — save exit code (BH=2)
    mov esi, HL(15, 8)                             ; hlcoord 15,8
    mov edx, GBSCR_W                               ; ld de, 20
    mov bh, TILE_BLANK                             ; lb bc, ' ', 9
    mov bl, 9
    call DrawTileLine                              ; cover the side menu cursor column
    pop ebx
    jmp .exitSideMenu

.choseData:
    call ShowPokedexDataInternal                   ; extern (G2)
    mov bh, 0                                       ; ld b, 0
    jmp .exitSideMenu

.choseCry:
    mov al, [ebp + wPokedexNum]
    call GetCryData                                 ; STUB (audio HAL)
    call PlaySound                                  ; audio HAL stub (no-op)
    jmp .handleMenuInput

.choseArea:
    ; STUB: pret `predef LoadTownMap_Nest` (pokémon area map) — OUT OF SCOPE for
    ; the menus swarm (town-map subsystem). No-op; take pret's area-shown path.
    mov bh, 0                                       ; ld b, 0
    jmp .exitSideMenu

.chosePrint:
    ; STUB: pret saves hTileAnimations, sets wCurPartySpecies, callfar
    ; PrintPokedexEntry, ClearScreen — the GB-printer path is OUT OF SCOPE. Keep
    ; the dispatch shape and the b=3 exit code (ShowPokedexMenu's .goToSideMenu
    ; triple-dec routes b=3 → .loop, reloading the palette + list).
    mov bh, 3                                       ; ld b, $3
    jmp .exitSideMenu

; ---------------------------------------------------------------------------
; HandlePokedexListMenu — pret ref: pokedex.asm:HandlePokedexListMenu.
; The scrolling list on the left. CF set on A (chose mon), clear on B. The
; scroll math (±1 row up/down, ±7 rows left/right, wDexMaxSeenMon clamps) is
; ported byte-for-byte.
; ---------------------------------------------------------------------------
HandlePokedexListMenu:
    ; port plumbing: stride-20 scratch, double-spaced cursor, per-frame mirror.
    mov dword [text_row_stride], GBSCR_W
    mov dword [menu_item_step], 2 * GBSCR_W
    mov dword [menu_redraw_cb], pdex_mirror
    call Pokedex_DrawInterface
    call pdex_show_window                            ; expose the finished scratch
.loop:
    call Pokedex_PlacePokemonList
    call GBPalNormal
    call HandleMenuInput                             ; → AL = pressed keys
    test al, PAD_B                                   ; bit B_PAD_B, a
    jnz .buttonBPressed
    test al, PAD_A                                   ; bit B_PAD_A, a
    jnz .buttonAPressed
.checkIfUpPressed:
    test al, PAD_UP
    jz .checkIfDownPressed
.upPressed:                                          ; scroll up one row
    mov al, [ebp + wListScrollOffset]
    and al, al
    jz .loop
    dec al
    mov [ebp + wListScrollOffset], al
    jmp .loop
.checkIfDownPressed:
    test al, PAD_DOWN
    jz .checkIfRightPressed
.downPressed:                                        ; scroll down one row
    mov al, [ebp + wDexMaxSeenMon]
    cmp al, 7
    jc .loop                                         ; list shorter than 7 rows
    sub al, 7
    mov bh, al                                       ; ld b, a
    mov al, [ebp + wListScrollOffset]
    cmp al, bh                                       ; cp b
    jz .loop
    inc al
    mov [ebp + wListScrollOffset], al
    jmp .loop
.checkIfRightPressed:
    test al, PAD_RIGHT
    jz .checkIfLeftPressed
.rightPressed:                                       ; scroll down 7 rows
    mov al, [ebp + wDexMaxSeenMon]
    cmp al, 7
    jc .loop
    sub al, 6
    mov bh, al                                       ; ld b, a
    mov al, [ebp + wListScrollOffset]
    add al, 7
    mov [ebp + wListScrollOffset], al
    cmp al, bh                                       ; cp b
    jc .loop
    dec bh
    mov al, bh                                       ; ld a, b
    mov [ebp + wListScrollOffset], al
    jmp .loop
.checkIfLeftPressed:                                 ; scroll up 7 rows
    test al, PAD_LEFT
    jz .buttonAPressed
.leftPressed:
    mov al, [ebp + wListScrollOffset]
    sub al, 7
    mov [ebp + wListScrollOffset], al
    jnc .loop                                        ; jp nc
    xor al, al
    mov [ebp + wListScrollOffset], al
    jmp .loop
.buttonAPressed:
    stc
    ret
.buttonBPressed:
    and al, al                                       ; clear carry
    ret

; ---------------------------------------------------------------------------
; Pokedex_DrawInterface — pret ref: pokedex.asm:Pokedex_DrawInterface.
; Draw the SEEN/OWN counts, dividers, CONTENTS + side-menu labels, and compute
; wDexMaxSeenMon (the highest seen pokédex number).
; ---------------------------------------------------------------------------
Pokedex_DrawInterface:
    mov byte [ebp + H_AUTO_BG_TRANSFER_EN], 0        ; xor a / ldh [hAutoBGTransferEnabled],a
    ; DEVIATION: clear BIT_SINGLE_SPACED_LINES so the side-menu <NEXT> advances 2
    ; rows (matches pret's default; defensive, per players_pc.asm precedent).
    and byte [ebp + H_UI_LAYOUT_FLAGS], ~(1 << BIT_SINGLE_SPACED_LINES) & 0xFF
    ; horizontal line under the counts: 5×'─' at (15,6)
    mov esi, HL(15, 6)
    mov al, TILE_HLINE
    mov ecx, 5
.hlineLoop:
    mov [ebp + esi], al
    inc esi
    dec ecx
    jnz .hlineLoop
    mov byte [ebp + HL(14, 0)], TILE_VLINE           ; hlcoord 14,0 / ld [hl],$71
    mov esi, HL(14, 1)
    call DrawPokedexVerticalLine
    mov esi, HL(14, 9)
    call DrawPokedexVerticalLine
    ; number of seen pokemon
    mov esi, wPokedexSeen
    mov bh, wPokedexSeenEnd - wPokedexSeen           ; ld b, count (19)
    call CountSetBits
    mov edx, wNumSetBits                              ; ld de, wNumSetBits (PrintNumber src)
    mov esi, HL(16, 2)
    mov bh, 1                                         ; lb bc,1,3 (1 byte, 3 digits)
    mov bl, 3
    call PrintNumber
    ; number of owned pokemon
    mov esi, wPokedexOwned
    mov bh, wPokedexOwnedEnd - wPokedexOwned
    call CountSetBits
    mov edx, wNumSetBits
    mov esi, HL(16, 5)
    mov bh, 1
    mov bl, 3
    call PrintNumber
    ; labels
    mov esi, HL(16, 1)
    mov eax, PokedexSeenText
    call PlaceString
    mov esi, HL(16, 4)
    mov eax, PokedexOwnText
    call PlaceString
    mov esi, HL(1, 1)
    mov eax, PokedexContentsText
    call PlaceString
    mov esi, HL(16, 8)
    mov eax, PokedexMenuItemsText
    call PlaceString
    ; find the highest pokedex number among seen pokemon.
    ; scans MSB-first from the last seen-bitfield byte down; b counts down from
    ; (bits+1) so, when the first set bit rotates into CF, b = its dex number.
    mov esi, wPokedexSeenEnd - 1                       ; ld hl, wPokedexSeenEnd-1
    mov bh, (wPokedexSeenEnd - wPokedexSeen) * 8 + 1  ; ld b, bits+1  (153)
.maxSeenPokemonLoop:
    mov al, [ebp + esi]                               ; ld a, [hld]
    dec esi
    mov bl, 8                                          ; ld c, 8
.maxSeenPokemonInnerLoop:
    dec bh                                              ; dec b (does not set CF)
    shl al, 1                                           ; sla a — bit7 → CF
    jc .storeMaxSeenPokemon
    dec bl                                              ; dec c
    jnz .maxSeenPokemonInnerLoop
    jmp .maxSeenPokemonLoop
.storeMaxSeenPokemon:
    mov [ebp + wDexMaxSeenMon], bh                      ; ld a,b / ld [wDexMaxSeenMon],a
    ret

; ---------------------------------------------------------------------------
; DrawPokedexVerticalLine — pret ref: pokedex.asm:DrawPokedexVerticalLine.
; Draw 9 tiles down column 14 (stride = pret SCREEN_WIDTH = 20), toggling the
; tile between $71 and $70 each row. In: ESI = EBP-rel top tile. Clobbers AL,BL.
; ---------------------------------------------------------------------------
DrawPokedexVerticalLine:
    mov bl, 9                                          ; ld c, 9 (height)
    mov edx, GBSCR_W                                   ; ld de, SCREEN_WIDTH (pret=20, NOT 40)
    mov al, TILE_VLINE                                 ; ld a, $71
.loop:
    mov [ebp + esi], al
    add esi, edx                                       ; add hl, de
    xor al, 1                                          ; toggle $71 ↔ $70
    dec bl
    jnz .loop
    ret

; ---------------------------------------------------------------------------
; Pokedex_PlacePokemonList — pret ref: pokedex.asm:Pokedex_PlacePokemonList.
; The 7-row scrolling list: dex number (LEADING_ZEROES), a pokéball for owned,
; and the mon name (or "----------" if unseen). Rows are 2 apart (double-spaced).
; ---------------------------------------------------------------------------
Pokedex_PlacePokemonList:
    mov byte [ebp + H_AUTO_BG_TRANSFER_EN], 0
    ; DEVIATION: pret `hlcoord 4,2 / lb bc,14,10 / call ClearScreenArea`. The
    ; port's ClearScreenArea advances rows by SCREEN_WIDTH=40; this is the
    ; stride-20 scratch, so clear inline at GBSCR_W (players_pc.asm precedent).
    call pdex_clear_list_area
    mov esi, HL(1, 3)                                   ; hlcoord 1,3
    mov al, [ebp + wListScrollOffset]
    mov [ebp + wPokedexNum], al
    mov dh, 7                                           ; ld d, 7 (row count)
    mov al, [ebp + wDexMaxSeenMon]
    cmp al, 7
    jnc .printPokemonLoop                               ; jr nc
    mov dh, al                                          ; ld d, a  (fewer than 7 rows)
    dec al
    mov [ebp + wMaxMenuItem], al
.printPokemonLoop:
    mov al, [ebp + wPokedexNum]
    inc al
    mov [ebp + wPokedexNum], al
    push eax                                            ; push af (dex number)
    push edx                                            ; push de (row counter DH)
    push esi                                            ; push hl (row start)
    sub esi, GBSCR_W                                    ; ld de,-SCREEN_WIDTH / add hl,de
    mov edx, wPokedexNum                                ; ld de, wPokedexNum (src)
    mov bh, LEADING_ZEROES | 1                          ; lb bc, LEADING_ZEROES|1, 3
    mov bl, 3
    call PrintNumber                                    ; ESI advances 3 digits
    add esi, GBSCR_W                                    ; ld de,SCREEN_WIDTH / add hl,de
    dec esi                                             ; dec hl → col 3 of the row
    push esi                                            ; push hl
    mov esi, wPokedexOwned                              ; ld hl, wPokedexOwned
    call IsPokemonBitSet                                ; ZF set = not owned
    pop esi                                             ; pop hl (col 3)
    mov al, TILE_BLANK                                  ; ld a, ' '
    jz .writeTile
    mov al, TILE_POKEBALL                               ; ld a, $72
.writeTile:
    mov [ebp + esi], al                                 ; ld [hl], a
    push esi                                            ; push hl
    mov esi, wPokedexSeen                               ; ld hl, wPokedexSeen
    call IsPokemonBitSet                                ; ZF clear = seen
    jnz .getPokemonName
    mov eax, .dashedLine                                ; ld de, .dashedLine (flat src)
    jmp .skipGettingName
.getPokemonName:
    call PokedexToIndex                                 ; wPokedexNum: dex# → index
    call GetMonName                                     ; [wNamedObjectIndex]=index → wNameBuffer
    lea eax, [ebp + wNameBuffer]                        ; PlaceString EAX = flat src
.skipGettingName:
    pop esi                                             ; pop hl (col 3)
    inc esi                                             ; inc hl → col 4
    call PlaceString
    pop esi                                             ; pop hl (row start)
    add esi, 2 * GBSCR_W                                ; ld bc,2*SCREEN_WIDTH / add hl,bc
    pop edx                                             ; pop de (restore row counter)
    pop eax                                             ; pop af (restore dex number)
    mov [ebp + wPokedexNum], al                         ; ld [wPokedexNum], a
    dec dh                                              ; dec d
    jnz .printPokemonLoop
    mov byte [ebp + H_AUTO_BG_TRANSFER_EN], 1
    jmp Delay3                                          ; call Delay3 / ret (tail)
.dashedLine:                                            ; unseen-mon placeholder
    db 0xE3, 0xE3, 0xE3, 0xE3, 0xE3, 0xE3, 0xE3, 0xE3, 0xE3, 0xE3, 0x50 ; "----------@"

; ---------------------------------------------------------------------------
; IsPokemonBitSet — pret ref: pokedex.asm:IsPokemonBitSet.
; Test a pokémon's bit in a seen/owned bitfield.
; In: [wPokedexNum] = pokédex number; ESI (HL) = bitfield address (EBP-rel).
; Out: AL = masked bit, ZF set iff clear. pret uses `predef FlagActionPredef`;
; the port sets ESI/CL/BH directly and tail-uses FlagAction (tms.asm precedent).
; ---------------------------------------------------------------------------
IsPokemonBitSet:
    mov al, [ebp + wPokedexNum]
    dec al
    mov cl, al                                          ; ld c, a (bit index)
    mov bh, FLAG_TEST                                   ; ld b, FLAG_TEST
    call FlagAction                                     ; → CL = result bit (ESI/EDX preserved)
    mov al, cl                                          ; ld a, c
    and al, al                                          ; and a → ZF
    ret

; ---------------------------------------------------------------------------
; DrawTileLine — pret ref: pokedex.asm:DrawTileLine.
; Write C copies of tile B, stepping the dest by DE each time.
; In: BH = tile id, BL = count, EDX = per-tile dest step, ESI = dest (EBP-rel).
; Preserves BX/EDX (pret push bc/de); advances ESI. (Also called by G2.)
; ---------------------------------------------------------------------------
DrawTileLine:
    push ebx                                            ; push bc
    push edx                                            ; push de
.loop:
    mov [ebp + esi], bh                                 ; ld [hl], b
    add esi, edx                                        ; add hl, de
    dec bl                                              ; dec c
    jnz .loop
    pop edx
    pop ebx
    ret

; ---------------------------------------------------------------------------
; PokedexToIndex — pret ref: pokedex.asm:PokedexToIndex.
; Convert the pokédex number at [wPokedexNum] to an internal index (walks
; the index->dex table until a matching dex number is found; the 1-based
; position is the index). In/Out via [wPokedexNum]. Preserves BX/ESI.
; DEVIATION: pret walks PokedexOrder; the port already ships that exact table
; (byte-identical) as the global `IndexToPokedex` (base_stats.inc), so we walk
; it instead of duplicating the data. pret's IndexToPokedex ROUTINE (the reverse
; lookup) is unused here — the port's callers index the table directly
; (IndexToPokedex[index-1]), which is what G2 does — so it is not re-ported.
; ---------------------------------------------------------------------------
PokedexToIndex:
    push ebx
    push esi
    mov al, [ebp + wPokedexNum]
    mov bh, al                                          ; ld b, a (target dex#)
    mov bl, 0                                           ; ld c, 0 (counter)
    mov esi, IndexToPokedex                              ; port's index->dex table (== PokedexOrder)
.loop:
    inc bl                                              ; inc c
    mov al, [esi]                                       ; ld a, [hli] (flat)
    inc esi
    cmp al, bh                                          ; cp b
    jne .loop
    mov al, bl                                          ; ld a, c
    mov [ebp + wPokedexNum], al
    pop esi
    pop ebx
    ret

; ---------------------------------------------------------------------------
; RunDefaultPaletteCommand — pret ref: home/palettes.asm:RunDefaultPaletteCommand
; (sets B=SET_PAL_DEFAULT, falls into RunPaletteCommand). File-local (same as
; naming_screen.asm; RunPaletteCommand is the port's no-op palette-HAL stub).
; ---------------------------------------------------------------------------
RunDefaultPaletteCommand:
    mov bl, SET_PAL_DEFAULT
    jmp RunPaletteCommand

; ---------------------------------------------------------------------------
; GetCryData — STUB. pret ref: home/pokemon.asm:157 (NOT home/audio.asm).
;
; The old comment here said "No audio HAL in this port (Phase 3)". That is FALSE and
; has been since the audio phases merged (2026-07-07): the engine is live, music
; plays, PlaySound and WaitForSoundToFinish are real bodies, and src/audio/engine_1.asm
; already understands cries (Audio1_IsCry, CRY_SFX_START/END, and it reads the two
; modifier vars this routine is supposed to set). The cry data is generated and
; exported too (assets/cry_data.inc → `global CryData`). Nothing about the HAL blocks
; this. What blocks it is that nobody has written these ~15 instructions.
;
; TWO stub violations to fix while destubbing, both real:
;   1. This is a ret-stub in a SOURCE-MIRROR file. Stubs belong in a *_stubs.asm
;      (CLAUDE.md / project-conventions). It should never have been parked here.
;   2. Its pret ref was wrong (home/audio.asm), which is why it reads as an
;      audio-subsystem deferral rather than the plain home-routine translation it is.
;
; The real body (pret home/pokemon.asm:157): index CryData by species-1, 3 bytes per
; entry → B = base cry id, [wFrequencyModifier] = pitch mod, [wTempoModifier] = tempo
; mod; return A = cry_id*3 + CRY_SFX_START (cry headers are 3 channels each). The
; BankswitchHome/BankswitchBack pair around the table read is a no-op in the flat port.
;
; Its only caller is PlayCry (home/home_stubs.asm), also a ret-stub — see the long
; note there for the blocking contract a bare ret drops. Ledger: M-32.
; ---------------------------------------------------------------------------
GetCryData:
    ret

; ---------------------------------------------------------------------------
; pdex_show_window — port plumbing: full-screen window over the whited-out
; overworld, sourced from GB_TILEMAP1 rows 0-17 at the UI_POKEDEX_MAIN anchor,
; then mirror the current scratch into it.
; ; PROJ menus: window = UI_POKEDEX_MAIN_(WX,WY,CLIP,MAXY) (GB 20x18 full screen).
; ---------------------------------------------------------------------------
pdex_show_window:
    mov dword [g_bg_whiteout], 1
    mov eax, UI_POKEDEX_MAIN_WX
    mov ebx, UI_POKEDEX_MAIN_WY
    mov ecx, UI_POKEDEX_MAIN_CLIP
    mov edx, UI_POKEDEX_MAIN_MAXY
    mov esi, GB_TILEMAP1
    xor edi, edi                                         ; start_row = 0
    call set_single_window
    call pdex_mirror
    ret

; ---------------------------------------------------------------------------
; pdex_mirror — blit the stride-20 scratch rows 0-17 → GB_TILEMAP1 rows 0-17
; (the window's source; port stand-in for hAutoBGTransferEnabled). Installed as
; HandleMenuInput's menu_redraw_cb. Preserves all registers.
; ---------------------------------------------------------------------------
pdex_mirror:
    pushad
    xor ebx, ebx
.row:
    imul esi, ebx, GBSCR_W
    lea esi, [ebp + esi + W_TILEMAP]
    mov edi, ebx
    shl edi, 5                                           ; ×32 tilemap stride
    lea edi, [ebp + edi + GB_TILEMAP1]
    mov ecx, GBSCR_W
    rep movsb
    inc ebx
    cmp ebx, UI_POKEDEX_MAIN_GBH                          ; 18 rows
    jb .row
    popad
    ret

; ---------------------------------------------------------------------------
; pdex_clear_list_area — clear the 14-row × 10-col list area at (4,2) on the
; stride-20 scratch (stands in for pret's ClearScreenArea, which is stride-40).
; Preserves all registers used by the caller.
; ---------------------------------------------------------------------------
pdex_clear_list_area:
    push eax
    push ecx
    push edx
    push edi
    lea edi, [ebp + HL(4, 2)]
    mov dl, 14                                            ; row count
    mov al, TILE_BLANK
.row:
    mov ecx, 10                                           ; width
    rep stosb
    add edi, GBSCR_W - 10                                 ; next row, same column
    dec dl
    jnz .row
    pop edi
    pop edx
    pop ecx
    pop eax
    ret

; ===========================================================================
; LoadPokedexTilePatterns — load the pokédex interface tileset into VRAM.
; pret: engine/gfx/load_pokedex_tiles.asm:LoadPokedexTilePatterns —
;   1. LoadHpBarAndStatusTilePatterns (fills $62-$7F; the dex tiles then
;      overwrite $60-$71, exactly as on the GB),
;   2. PokedexTileGraphics (18 tiles: frame/line tiles + the ′″ height
;      glyphs) → vChars2 tile $60,
;   3. PokeballTileGraphics (1 tile) → vChars2 tile $72 (caught marker).
; Shared by G1 (ShowPokedexMenu.setUpGraphics) and G2 (pokedex_entry).
; NB: this clobbers the box tiles $79-$7E via step 1 — the dex exit path
; (ShowPokedexMenu.exitPokedex → ReloadMapData) reloads LoadTextBoxTilePatterns
; + the map tileset, faithfully to pret. All registers preserved.
; ===========================================================================
LoadPokedexTilePatterns:
    call LoadHpBarAndStatusTilePatterns
    mov byte [g_tilecache_dirty], 1     ; VRAM tile data changes → rebuild cache
    push ecx
    push esi
    push edi
    mov esi, PokedexTileGraphics
    lea edi, [ebp + GB_VCHARS2 + 0x60 * TILE_SIZE]
    mov ecx, POKEDEX_TILE_GFX_SIZE / 4
    rep movsd
    mov esi, PokeballTileGraphics
    lea edi, [ebp + GB_VCHARS2 + 0x72 * TILE_SIZE]
    mov ecx, POKEBALL_TILE_SIZE / 4
    rep movsd
    pop edi
    pop esi
    pop ecx
    ret

; ===========================================================================
; RunPokedexTest — menus S8 package G1 FRAME.BIN gate (static open state).
; Seeds a handful of seen/owned bits, loads the font, then draws the CONTENTS
; list (Pokedex_DrawInterface + Pokedex_PlacePokemonList + the ▶ cursor + the
; window) WITHOUT entering the blocking HandleMenuInput loop, mirrors, settles,
; dumps FRAME.BIN, exits. In: EBP = GB base.  make DEBUG_G1=1 (root wires flag).
; ===========================================================================
%ifdef DEBUG_G1
global RunPokedexTest
extern LoadFontTilePatterns            ; gfx/load_font.asm
extern ClearSprites                    ; gfx/sprites.asm
extern PlaceMenuCursor                 ; home/window.asm
extern DumpBackbuffer                  ; debug/debug_dump.asm — writes FRAME.BIN + exits

RunPokedexTest:
    mov dword [text_row_stride], GBSCR_W
    mov dword [menu_item_step], 2 * GBSCR_W
    or byte [ebp + W_FONT_LOADED], (1 << BIT_FONT_LOADED)
    call LoadFontTilePatterns
    call ClearScreen                ; blank the scratch (as ShowPokedexMenu does —
                                    ; without it the boot-leftover map bytes show
                                    ; in the dex margins, a harness-only artifact)
    call LoadPokedexTilePatterns    ; real dex tileset (as ShowPokedexMenu.setUpGraphics)
    call ClearSprites
    mov byte [ebp + W_UPDATE_SPRITES_ENABLED], 0
    ; zero the owned+seen bitfields (contiguous 0xD2F6..0xD31C), then seed bits
    xor eax, eax
    lea edi, [ebp + wPokedexOwned]
    mov ecx, wPokedexSeenEnd - wPokedexOwned
    rep stosb
    mov byte [ebp + wPokedexSeen + 0], 0xFF               ; mons 1-8 seen
    mov byte [ebp + wPokedexSeen + 1], 0x0F               ; mons 9-12 seen
    mov byte [ebp + wPokedexOwned + 0], 0x55              ; mons 1,3,5,7 owned
    ; list-menu state (as ShowPokedexMenu / .doPokemonListMenu primes it)
    mov byte [ebp + wListScrollOffset], 0
    mov byte [ebp + wPokedexNum], 1
    mov byte [ebp + wTopMenuItemY], 3
    mov byte [ebp + wTopMenuItemX], 0
    mov byte [ebp + wCurrentMenuItem], 0
    mov byte [ebp + wLastMenuItem], 0
    mov byte [ebp + wMaxMenuItem], 6
    call Pokedex_DrawInterface                            ; also computes wDexMaxSeenMon
    call Pokedex_PlacePokemonList
    call PlaceMenuCursor                                  ; draw the ▶ on the first row
    call pdex_show_window
    call DelayFrame
    call DelayFrame
    call DelayFrame
    call DumpBackbuffer                                   ; writes FRAME.BIN + exits
.hang:
    jmp .hang
%endif
