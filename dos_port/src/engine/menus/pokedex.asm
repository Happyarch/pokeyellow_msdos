; pokedex.asm — the POKéDEX. Full port of pret engine/menus/pokedex.asm.
;
; BOTH halves live here, as they do in pret: the menu/list screen (ShowPokedexMenu,
; HandlePokedexSideMenu, HandlePokedexListMenu, Pokedex_DrawInterface,
; DrawPokedexVerticalLine, Pokedex_PlacePokemonList, IsPokemonBitSet, DrawTileLine,
; PokedexToIndex) and the DATA/entry page (ShowPokedexData, ShowPokedexDataInternal,
; DrawDexEntryOnScreen, Pokedex_PrintFlavorTextAtRow11/AtBC,
; Pokedex_PrepareDexEntryForPrinting, HeightWeightText, PokeText,
; PokedexDataDividerLine).
;
; The entry page used to be a separate src/engine/menus/pokedex_entry.asm, held there
; by NINE allowlist entries whose only stated reason was "pret … split across port
; files (draft Session H)". Challenged at menu-fidelity row 16 part 2 and found to be
; no reason at all: the split was an artifact of two parallel authoring sessions
; (the deleted header said so — "package G2 … a separate worker/worktree … Root
; finalizes the link at integration"), and it forced the two halves of ONE screen to
; reach each other through an extern seam (DrawTileLine / IsPokemonBitSet /
; PokedexToIndex / ShowPokedexDataInternal). Merged back to the mirrored path; all
; nine entries deleted, not re-blessed. Ledger M-78.
;
; NOT IndexToPokedex: pret has a ROUTINE by that name (dex# lookup), while the port
; gives the name to a DATA TABLE in pokemon_data.asm and has no such routine. That
; label squat is real but cross-file (pokemon_data.asm + home/pics.asm + the base-stats
; generator all depend on the table name), so it is filed as ledger M-71, not fixed here.
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
; - The DATA page is the same model on its own window anchor: dex_mirror blits the
;   scratch and dex_show_window publishes it at UI_POKEDEX_ENTRY_*.
;
; ; PROJ menus: box + list + side menu project onto the UI_POKEDEX_MAIN window
;   (GB(0,0) 20x18 --(center/top, X+10)--> wx=87 wy=0 clip=160 max_y=144
;   [UI_POKEDEX_MAIN_*]). Side menu sub-rect: UI_POKEDEX_SIDE_MENU_* (GB 15,8 5x9).
;   DATA page: UI_POKEDEX_ENTRY_* (GB(0,0) 20x18, same projection).
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
global IsPokemonBitSet
global DrawTileLine
global PokedexToIndex
; the DATA (entry) page — pret pokedex.asm:438-693:
global ShowPokedexData
global ShowPokedexDataInternal
global DrawDexEntryOnScreen
global Pokedex_PrintFlavorTextAtRow11
global Pokedex_PrintFlavorTextAtBC
global Pokedex_PrepareDexEntryForPrinting
global LoadPokedexTilePatterns       ; REAL body (below), not a stub — G2 externs it
extern IndexToPokedex                ; base_stats.inc — index->dex TABLE (== pret PokedexOrder)

; ---- externs -------------------------------------------------------------
extern GBPalWhiteOut                 ; home/fade.asm
extern GBPalWhiteOutWithDelay3       ; home/fade.asm
extern GBPalNormal                   ; init/init.asm
; RunPaletteCommand is a REAL, LINKED body (home/palettes.asm) — not the "no-op palette
; HAL stub" this file once claimed. It takes the command in GB `b` == BH, as pret does
; (M-62 resolved: the old BL-first normalizing shim is gone and every call site now
; passes BH; see home/palettes.asm for why the half-and-half state was dangerous).
extern RunPaletteCommand             ; home/palettes.asm — REAL body; BH = pret's `b`
extern RunDefaultPaletteCommand      ; engine/menus/naming_screen.asm — BH=SET_PAL_DEFAULT → RunPaletteCommand
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
; PlaySound is a REAL body (home/audio.asm), not the "audio HAL stub" this file used
; to claim — the audio engine is live and music plays. The POKéDEX CRY option is
; silent only because GetCryData/PlayCry are still ret-stubs (home_stubs.asm; M-32).
extern PlaySound                     ; home/audio.asm — a REAL body
extern GetCryData                    ; home_stubs.asm — STUB (M-32); pret home/pokemon.asm
extern LoadTownMap_Nest              ; engine/items/town_map.asm — REAL body, linked (M-64)
extern PrintPokedexEntry             ; engine/printer/printer_stubs.asm — STUB (GB printer)
; ---- externs used only by the DATA (entry) page ---------------------------
extern TextCommandProcessor          ; home/text.asm — ESI = stream (FLAT ptr), EBX = cursor
extern GetMonHeader                  ; home/pokemon.asm — wCurSpecies → wMonHeader
extern LoadFlippedFrontSpriteByMonIndex ; gfx/pics.asm — ESI = tilemap coord; decode + place
extern JoypadLowSensitivity          ; input/joypad_lowsens.asm → [hJoy5]
extern LoadTextBoxTilePatterns       ; gfx/load_font.asm
; PlayCry is a ret-only STUB (home_stubs.asm), NOT an absent routine and NOT an audio-HAL
; blocker — the engine is live and CryData is generated; nobody has written its ~15
; instructions (M-32). pret's DrawDexEntryOnScreen calls it, so the port calls it: the
; call is what goes loud the day the stub is filled in. Dropping it was M-75.
extern PlayCry                       ; home_stubs.asm — STUB (M-32); pret home/pokemon.asm
extern g_dex_flavor_active           ; text/text.asm — full-page window mode for the flavor

; ---- local equates (Tier-2 UI/index enums; not gb_memmap data) -----------
; pret ref: constants/palette_constants.asm
SET_PAL_GENERIC   equ 0x08
SET_PAL_DEFAULT   equ 0xFF
SET_PAL_POKEDEX   equ 0x04

; hDexWeight — pret ram/hram.asm: a UNION member at the HRAM top (with hBaseTileID,
; hWarpDestinationMap, hOAMTile, hROMBankTemp …). The port's 0xFF8B is the same union
; slot (H_MAP_STRIDE / H_PREVIOUS_TILESET / hItemPrice / hWarpDestinationMap). That
; sharing is exactly why pret save/restores the two bytes around the weight print, and
; why the port now does too — see DrawDexEntryOnScreen.owned (M-76).
hDexWeight        equ 0xFF8B
; hClearLetterPrintingDelayFlags — pret ram/hram.asm (the byte before hUILayoutFlags).
H_CLEAR_LETTER_PRINTING_DELAY_FLAGS equ 0xFFF9
; hUILayoutFlags bit (pret constants/gfx_constants.asm) — treat <PAGE> as <NEXT>.
BIT_PAGE_CHAR_IS_NEXT equ 3
; wPrinterPokedexEntryTextPointer — pret ram/wram.asm (dw). Read only by the GB-Printer
; path (Pokedex_PrepareDexEntryForPrinting); the port reaches the flavor through
; dex_flavor_ptr instead, so nothing populates it (see the tag at that routine).
wPrinterPokedexEntryTextPointer equ 0xCAF5
; wDexFlavorBuf — PORT-ONLY staging buffer (DEVIATION, see Pokedex_PrintFlavorTextAtBC).
; TextCommandProcessor reads its stream EBP-relative but the flavor lives in flat .data,
; so the bytes are copied into GB space first. Reuses wTileMapBackup2 (W_TILEMAP_BACKUP2
; = $F100, 1000 B) — a screen-backup scratch the per-frame BG/window renderer never reads
; (render_bg sources wSurroundingTiles at $E000).
wDexFlavorBuf     equ W_TILEMAP_BACKUP2
DEX_FLAVOR_MAX    equ 300           ; copy bound (the longest entry is well under 140 B)

; charmap glyphs used by the entry page (constants/charmap.asm)
GLYPH_NO          equ 0x74          ; '№'
GLYPH_DOT         equ 0xF2          ; '<DOT>' decimal point
GLYPH_FEET        equ 0x60          ; '′'  (dex tileset)
GLYPH_INCHES      equ 0x61          ; '″'  (dex tileset)
GLYPH_ZERO        equ 0xF6          ; '0'

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

; pret ref: engine/menus/pokedex.asm text tables. These were hand-encoded charmap
; `db` bytes here until 2026-07-14, under a comment calling them "Tier-2 hand-authored
; charmap bytes" — there is NO such exemption. A rendered string is Tier-1 DATA
; (CLAUDE.md), so all five (the four PlaceString labels + the routine-local
; .dashedLine) are now generated by tools/gen_menu_strings.py through gb_text.encode.
; The generated bytes are byte-identical to the literals they replace. Ledger M-70.
; The DATA page's three blobs (HeightWeightText / PokeText / PokedexDataDividerLine)
; were the same violation in pokedex_entry.asm and are generated into the same .inc
; (M-77) — again byte-identical to the literals they replace.
%include "assets/pokedex_strings.inc"

; PokedexEntryPointers + the 151 entry blobs (flat .data, charmap-encoded).
global PokedexEntryPointers          ; link_cups.asm (PetitCup) externs it
%include "assets/dex_entries.inc"

; ===========================================================================
section .bss
align 4
; Port register spill for the DATA page (stands in for pret's push/pop chain across
; the long GetMonName / GetMonHeader / pic-load span; observably identical).
dex_entry_ptr:    resd 1     ; FLAT .data ptr to the current PokedexEntry blob
dex_flavor_ptr:   resd 1     ; FLAT .data ptr to the flavor stream
saved_pokedexnum: resb 1     ; internal index, saved while wPokedexNum holds the dex#
saved_owned:      resb 1     ; owned flag (from IsPokemonBitSet)
saved_dexweight:  resb 2     ; the two borrowed hDexWeight HRAM bytes (pret's push af ×2)

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
    ; pret: ld b, SET_PAL_GENERIC / call RunPaletteCommand. Not a TODO-HW — the palette
    ; engine is live (home/palettes.asm), and BH *is* pret's `b` (M-62 resolved).
    mov bh, SET_PAL_GENERIC                   ; ld b, SET_PAL_GENERIC
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
    ; STUB{class=stub; label=GetCryData; pret=home/audio.asm:GetCryData; behavior=returns without preparing cry parameters; evidence=project_state:GetCryData reports linked stub; lifetime=until audio Phase A cry gateway}
    call GetCryData
    call PlaySound                                  ; audio HAL stub (no-op)
    jmp .handleMenuInput

.choseArea:
    ; M-64: this was a no-op "STUB" whose comment claimed LoadTownMap_Nest was "OUT
    ; OF SCOPE (town-map subsystem)". FALSE — and it silently killed the AREA option.
    ; LoadTownMap_Nest is a REAL 74-instruction body (engine/items/town_map.asm:252)
    ; that is GLOBAL and LINKED (ITEMS_SRCS ⊂ LINK_SRCS). It was written, wired, and
    ; then never called: the only thing missing was this one instruction.
    ; pret does `predef LoadTownMap_Nest`; the port calls it directly (predefs carry
    ; no bank in a flat address space, and this predef takes no register args).
    call LoadTownMap_Nest                           ; predef LoadTownMap_Nest — display pokémon areas
    mov bh, 0                                       ; ld b, 0
    jmp .exitSideMenu

.chosePrint:
    ; The GB-printer path. pret's body is ported in full and faithfully; only the
    ; printer routine itself is deferred — PrintPokedexEntry is a ret-only STUB in
    ; engine/printer/printer_stubs.asm (the Game Boy Printer is a serial-link
    ; peripheral: TODO-HW serial). Keeping the surrounding body means the screen is
    ; cleared and redrawn exactly as on hardware-with-no-printer, and whoever ports
    ; the printer only has to fill in the stub. Previously this whole path was a bare
    ; `mov bh,3 / jmp`, which dropped 3 stores and 2 calls with no tag (M-65).
    mov al, [ebp + hTileAnimations]                 ; ldh a, [hTileAnimations]
    push eax                                        ; push af
    mov byte [ebp + hTileAnimations], 0             ; xor a / ldh [hTileAnimations], a
    mov al, [ebp + wPokedexNum]
    mov [ebp + wCurPartySpecies], al
    call PrintPokedexEntry                          ; callfar PrintPokedexEntry — STUB (TODO-HW: serial)
    mov byte [ebp + hAutoBGTransferEnabled], 0      ; xor a / ldh [hAutoBGTransferEnabled], a
    call ClearScreen
    pop eax                                         ; pop af
    mov [ebp + hTileAnimations], al                 ; ldh [hTileAnimations], a
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
    ; DEVIATION(window-list): pret has no equivalent — the GB shows the BG map directly.
    ; The port composites through a window list, so the finished stride-20 scratch has to
    ; be published as a window once before the menu loop can mirror into it each frame.
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
    mov byte [ebp + hAutoBGTransferEnabled], 0        ; xor a / ldh [hAutoBGTransferEnabled],a
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
    mov byte [ebp + hAutoBGTransferEnabled], 0
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
    mov byte [ebp + hAutoBGTransferEnabled], 1
    jmp Delay3                                          ; call Delay3 / ret (tail)
; .dashedLine ("----------@", the unseen-mon placeholder) is Tier-1 DATA and is now
; generated into assets/pokedex_strings.inc, which defines it under pret's own local
; name via NASM's Global.local form (Pokedex_PlacePokemonList.dashedLine). M-70.

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
    ; DEVIATION(predef): pret does `predef FlagActionPredef`; the port calls FlagAction
    ; directly. FlagActionPredef's prologue is GetPredefRegisters, which would clobber
    ; the very registers this call passes its arguments in. Established port pattern with
    ; the same justification at home/item_predicates.asm:125.
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

; ===========================================================================
; The DATA (entry) page — pret engine/menus/pokedex.asm:438-693. Reached from the
; side menu's DATA option (.choseData → ShowPokedexDataInternal) and, from outside
; the pokédex, through ShowPokedexData.
; ===========================================================================

; ---------------------------------------------------------------------------
; ShowPokedexData — pret ref: pokedex.asm:ShowPokedexData.
; Show a dex entry from OUTSIDE the pokédex: load the dex tile patterns first,
; then fall through to ShowPokedexDataInternal.
; ---------------------------------------------------------------------------
ShowPokedexData:
    call GBPalWhiteOutWithDelay3
    call ClearScreen
    call UpdateSprites
    call LoadPokedexTilePatterns         ; pret: callfar LoadPokedexTilePatterns
    ; fall through

; ---------------------------------------------------------------------------
; ShowPokedexDataInternal — pret ref: pokedex.asm:ShowPokedexDataInternal.
; Draw the entry page, print the flavor if the mon is owned, wait for A/B, tear down.
; ---------------------------------------------------------------------------
ShowPokedexDataInternal:
    ; ld hl, wStatusFlags2 / set BIT_NO_AUDIO_FADE_OUT, [hl]
    or byte [ebp + W_STATUS_FLAGS_2], 1 << BIT_NO_AUDIO_FADE_OUT
    ; pret: ld a,$33 / ldh [rAUDVOL],a — duck to 3/7 volume for the cry. This was
    ; dropped behind "TODO-HW: audio HAL (Phase 3). No APU; skipped." — FALSE, and the
    ; same false claim row 14 killed for rAUDTERM (M-53): rAUDVOL is a live GB byte
    ; ($FF24, gb_memmap.inc), written by engine_1/engine_2 and READ every frame by the
    ; OPL / Tandy / MPU-401 shims to scale channel output. Nothing was blocking it. M-73.
    mov byte [ebp + rAUDVOL], 0x33       ; ld a, $33 (3/7 volume) / ldh [rAUDVOL], a
    movzx eax, byte [ebp + hTileAnimations]
    push eax                             ; push af
    xor al, al
    mov [ebp + hTileAnimations], al
    call GBPalWhiteOut                   ; zero all palettes
    mov al, [ebp + wPokedexNum]
    mov [ebp + wCurPartySpecies], al
    push eax                             ; push af (wPokedexNum)
    mov bh, SET_PAL_POKEDEX              ; ld b, SET_PAL_POKEDEX (BH == pret's `b`)
    call RunPaletteCommand
    pop eax                              ; pop af
    mov [ebp + wPokedexNum], al
    call DrawDexEntryOnScreen            ; CF set = mon is owned → print the flavor
    ; DEBUG_G2's dump no longer happens here: the old pre-flavor hook photographed
    ; a state the GB never pauses in (the real game prints the flavor ATOMICALLY —
    ; the dex leaves the letter delay off — and parks at the <PAGE> ▼). The gate
    ; now lets the real flavor print and park in its <PAGE> wait, and AutoKeyDrive
    ; (AUTOKEY_QUIET, no presses) writes FRAME.BIN+GBSTATE.BIN at AUTOKEY_DUMP_FRAME
    ; and exits — the PDEX_AREA / DEBUG_I1 pattern.
    jnc .waitForButtonPress              ; pret: call c, Pokedex_PrintFlavorTextAtRow11
    call Pokedex_PrintFlavorTextAtRow11
.waitForButtonPress:
    ; DEVIATION(input): pret's JoypadLowSensitivity opens with `call Joypad` — a fresh
    ; hardware read per iteration — so pret's spin needs no DelayFrame. The port
    ; refreshes H_JOY_HELD/H_JOY_PRESSED only in joypad_update, which runs once per
    ; DelayFrame, so a DelayFrame-less spin here would never see the button (no way out)
    ; AND would freeze the software PPU mid-reveal. Same shape as the options/town-map
    ; input loops.
    call DelayFrame
    call JoypadLowSensitivity
    mov al, [ebp + H_JOY5]               ; ldh a, [hJoy5]
    and al, PAD_A | PAD_B
    jz .waitForButtonPress
    pop eax                              ; pop af (hTileAnimations)
    mov [ebp + hTileAnimations], al
    call GBPalWhiteOut
    call ClearScreen
    ; The old comment here said RunDefaultPaletteCommand was "not defined in the port".
    ; It is: a global body in engine/menus/naming_screen.asm that this very file already
    ; calls from .exitPokedex. Restored — without it the dex exit left the pokédex
    ; palette set (M-74).
    call RunDefaultPaletteCommand
    call LoadTextBoxTilePatterns
    call GBPalNormal
    ; ld hl, wStatusFlags2 / res BIT_NO_AUDIO_FADE_OUT, [hl]
    and byte [ebp + W_STATUS_FLAGS_2], (~(1 << BIT_NO_AUDIO_FADE_OUT)) & 0xFF
    mov byte [ebp + rAUDVOL], 0x77       ; ld a, $77 (max volume) / ldh [rAUDVOL], a — M-73
    ret

; ---------------------------------------------------------------------------
; DrawDexEntryOnScreen — pret ref: pokedex.asm:DrawDexEntryOnScreen.
; Draw the bordered page (border / divider / HT-WT labels / name / № / species +
; the front pic). For an OWNED mon also print height + weight and stash the flavor
; pointer. Out: CF set = owned (print the flavor); CF clear = unowned.
; ---------------------------------------------------------------------------
DrawDexEntryOnScreen:
    call ClearScreen                     ; blanks W_TILEMAP
    ; port: the entry page owns the stride-20 scratch (PlaceString's <NEXT> and the
    ; flavor advance both step by text_row_stride). Same reset ShowPokedexMenu does.
    mov dword [text_row_stride], GBSCR_W

    ; --- border: four DrawTileLine edges (dex tileset $64/$6f/$66/$67) ----------
    mov esi, HL(0, 0)                    ; hlcoord 0,0 — top
    mov edx, 1                           ; ld de, 1 (horizontal)
    mov bh, 0x64
    mov bl, GBSCR_W                      ; lb bc, $64, SCREEN_WIDTH
    call DrawTileLine
    mov esi, HL(0, 17)                   ; hlcoord 0,17 — bottom
    mov edx, 1
    mov bh, 0x6F
    mov bl, GBSCR_W
    call DrawTileLine
    mov esi, HL(0, 1)                    ; hlcoord 0,1 — left
    mov edx, GBSCR_W                     ; ld de, 20 (vertical)
    mov bh, 0x66
    mov bl, 0x10                         ; lb bc, $66, $10
    call DrawTileLine
    mov esi, HL(19, 1)                   ; hlcoord 19,1 — right
    mov edx, GBSCR_W
    mov bh, 0x67
    mov bl, 0x10
    call DrawTileLine

    ; --- corners (ldcoord_a) ---------------------------------------------------
    mov byte [ebp + HL(0, 0)],   0x63    ; upper left
    mov byte [ebp + HL(19, 0)],  0x65    ; upper right
    mov byte [ebp + HL(0, 17)],  0x6C    ; lower left
    mov byte [ebp + HL(19, 17)], 0x6E    ; lower right

    ; --- divider (row 9) + HT/WT labels (row 6) --------------------------------
    mov eax, PokedexDataDividerLine
    mov esi, HL(0, 9)
    call PlaceString
    mov eax, HeightWeightText
    mov esi, HL(9, 6)
    call PlaceString

    ; --- mon name (row 2) — GetMonName reads wNamedObjectIndex (= wPokedexNum) ---
    call GetMonName
    lea eax, [ebp + wNameBuffer]         ; PlaceString takes a FLAT source pointer
    mov esi, HL(9, 2)
    call PlaceString

    ; --- entry blob: PokedexEntryPointers[wPokedexNum - 1] (flat .data) ---------
    movzx eax, byte [ebp + wPokedexNum]
    dec eax
    mov eax, [PokedexEntryPointers + eax*4]
    mov [dex_entry_ptr], eax

    ; --- species classification (row 4) — EAX = flat entry ptr ------------------
    mov esi, HL(9, 4)
    call PlaceString                     ; entry+0 = the '@'-terminated species name

    ; --- № + national dex number (row 8) ---------------------------------------
    mov byte [ebp + HL(2, 8)], GLYPH_NO  ; ld a,'№' / ld [hli],a
    mov byte [ebp + HL(3, 8)], GLYPH_DOT ; ld a,'<DOT>' / ld [hli],a
    movzx eax, byte [ebp + wPokedexNum]  ; internal index
    mov [saved_pokedexnum], al           ; pret: push af
    dec eax
    ; DEVIATION(flat-data): pret calls the IndexToPokedex ROUTINE; in the port that pret
    ; name belongs to the TABLE it walks (see the file header + ledger M-71), so the
    ; lookup is the table read the routine would have done. Cross-file rename, not fixed
    ; here; faithdiff therefore shows IndexToPokedex as a DROPPED call.
    movzx eax, byte [IndexToPokedex + eax]
    mov [ebp + wPokedexNum], al          ; wPokedexNum := dex# (PrintNumber + the owned bit)
    mov edx, wPokedexNum
    mov bh, LEADING_ZEROES | 1           ; lb bc, LEADING_ZEROES | 1, 3
    mov bl, 3
    mov esi, HL(4, 8)                    ; № and <DOT> consumed cols 2,3 (pret's hli walk)
    call PrintNumber

    ; --- owned? (bit dex#-1 of wPokedexOwned) ----------------------------------
    mov esi, wPokedexOwned               ; ld hl, wPokedexOwned
    call IsPokemonBitSet                 ; reads wPokedexNum (= dex#) → AL/CL = owned
    mov [saved_owned], al
    mov al, [saved_pokedexnum]           ; pret: pop af
    mov [ebp + wPokedexNum], al          ; restore the internal index
    mov al, [ebp + wCurPartySpecies]
    mov [ebp + wCurSpecies], al

    ; --- front pic at (1,1) ----------------------------------------------------
    call Delay3
    call GBPalNormal
    call GetMonHeader                    ; load the picture location
    ; pret: hlcoord 1,1 / call LoadFlippedFrontSpriteByMonIndex. The port's loader
    ; decodes to $9000 AND places the 7×7 block (flip-aware) at text_row_stride (= 20,
    ; the dex scratch) — so just set the coord; there is no separate placement step.
    mov esi, HL(1, 1)
    call LoadFlippedFrontSpriteByMonIndex
    mov al, [ebp + wCurPartySpecies]
    call PlayCry                         ; ret-only STUB (home_stubs.asm, M-32) — see the extern

    ; --- owned gate (pret: ld a,c / and a / ret z) -----------------------------
    mov al, [saved_owned]
    test al, al                          ; and a (clears CF)
    jnz .owned
    ; unowned: no height/weight/flavor. Publish the page (border/name/№/pic) as drawn.
    call dex_show_window                 ; DEVIATION(window-list): see dex_show_window
    clc                                  ; CF = 0 → the caller skips the flavor
    ret

.owned:
    ; DEVIATION(flat-data): pret walks the entry's fields with DE (feet, inches, weight,
    ; then the description pointer), relying on PrintNumber leaving DE where the next
    ; `inc de` expects it. The port's blob is flat .data and its PrintNumber clobbers
    ; EDX, so the field offsets are found once by scanning to the name's '@':
    ;   feet = @+1, inches = @+2, weight_lo = @+3, weight_hi = @+4, flavor = @+5.
    ; EDI is preserved by PrintNumber, so it carries the '@' pointer across the calls.
    mov edi, [dex_entry_ptr]
.scan_at:
    cmp byte [edi], 0x50                 ; '@'
    je .found_at
    inc edi
    jmp .scan_at
.found_at:
    ; hDexWeight ($FF8B) is a shared HRAM UNION slot, in the port exactly as in pret
    ; (hMapStride / hPreviousTileset / hWarpDestinationMap / hItemPrice all live here;
    ; pret unions it with hBaseTileID & co). pret saves and restores the two bytes it
    ; borrows — the port had DROPPED that under "hDexWeight is a port-local dex scratch
    ; with no other reader in this window", which is false: the overworld's
    ; hPreviousTileset sits in this byte across a dex visit and is read on the way back
    ; out (engine/overworld/overworld.asm). Restored, and hoisted above the feet/inches
    ; staging because the port stages those here too (pret's PrintNumber reads them
    ; straight out of ROM through DE). Ledger M-76.
    mov al, [ebp + hDexWeight + 0]
    mov [saved_dexweight + 0], al        ; pret: ld a,[hl] / push af
    mov al, [ebp + hDexWeight + 1]
    mov [saved_dexweight + 1], al        ; pret: ld a,[hl] / push af
    ; --- feet (12,6): 1 byte / 2 digits, then '′' -------------------------------
    movzx eax, byte [edi + 1]            ; feet (pret reads it too, and discards it)
    mov [ebp + hDexWeight], al           ; stage into GB space for PrintNumber
    mov edx, hDexWeight
    mov bh, 1
    mov bl, 2
    mov esi, HL(12, 6)
    call PrintNumber                     ; ESI → HL(14,6)
    mov byte [ebp + esi], GLYPH_FEET     ; ld [hl], '′'
    ; --- inches (15,6): LEADING_ZEROES | 1 byte / 2 digits, then '″' ------------
    movzx eax, byte [edi + 2]            ; inches
    mov [ebp + hDexWeight], al
    mov edx, hDexWeight
    mov bh, LEADING_ZEROES | 1
    mov bl, 2
    mov esi, HL(15, 6)
    call PrintNumber                     ; ESI → HL(17,6)
    mov byte [ebp + esi], GLYPH_INCHES   ; ld [hl], '″'
    ; --- weight (11,8): staged BIG-endian into hDexWeight, 2 bytes / 5 digits ----
    movzx eax, byte [edi + 4]            ; weight, upper byte
    mov [ebp + hDexWeight + 0], al       ; big-endian: [0] = upper
    movzx eax, byte [edi + 3]            ; weight, lower byte
    mov [ebp + hDexWeight + 1], al       ; [1] = lower
    mov edx, hDexWeight
    mov bh, 2
    mov bl, 5
    mov esi, HL(11, 8)
    call PrintNumber
    ; --- decimal point: the weight is stored in tenths of pounds ----------------
    ; if it is under 10, put a '0' before the point (pret's 16-bit sub/sbc compare).
    mov al, [ebp + hDexWeight + 1]       ; ldh a, [hDexWeight + 1]
    sub al, 10                           ; sub 10
    mov al, [ebp + hDexWeight + 0]       ; ldh a, [hDexWeight]   (mov preserves CF)
    sbb al, 0                            ; sbc 0
    mov esi, HL(14, 8)                   ; hlcoord 14,8          (mov preserves CF)
    jnc .decpt                           ; jr nc, .next (weight >= 10)
    mov byte [ebp + esi], GLYPH_ZERO     ; ld [hl], '0'
.decpt:
    ; inc hl / ld a,[hli] / ld [hld],a / ld [hl],'<DOT>' — shove the tenths digit one
    ; tile right and drop the decimal point into the gap it leaves.
    inc esi                              ; → (15,8)
    mov al, [ebp + esi]                  ; a = [hli]
    inc esi                              ; → (16,8)
    mov [ebp + esi], al                  ; ld [hld], a
    dec esi                              ; → (15,8)
    mov byte [ebp + esi], GLYPH_DOT      ; ld [hl], '<DOT>'
    ; restore the borrowed HRAM union bytes (pret: pop af ×2) — M-76.
    mov al, [saved_dexweight + 1]
    mov [ebp + hDexWeight + 1], al
    mov al, [saved_dexweight + 0]
    mov [ebp + hDexWeight + 0], al
    ; --- flavor pointer = @+5 (pret: pop hl / inc hl) ---------------------------
    lea eax, [edi + 5]
    mov [dex_flavor_ptr], eax
    ; port: HT/WT is in the scratch now — publish the page. If the caller runs the
    ; flavor (CF=1), that path re-mirrors after TextCommandProcessor.
    call dex_show_window
    stc                                  ; scf → CF = 1 = "print the flavor"
    ret

; ---------------------------------------------------------------------------
; Pokedex_PrintFlavorTextAtRow11 / …AtBC — pret ref: pokedex.asm.
; Print the flavor description through TextCommandProcessor.
; ---------------------------------------------------------------------------
Pokedex_PrintFlavorTextAtRow11:
    mov ebx, HL(1, 11)                   ; bccoord 1,11 (TCP's destination cursor)
Pokedex_PrintFlavorTextAtBC:
    ; DEVIATION(flat-data): pret's flavor is a far-bank text run; the port's data
    ; generator inlines it into the entry blob. TextCommandProcessor reads its stream
    ; EBP-relative, so the flat bytes are staged into GB space first.
    call dex_stage_flavor                ; [dex_flavor_ptr] → wDexFlavorBuf; ESI = GB off
    lea esi, [ebp + esi]                 ; → flat ptr (TCP's stream pointer is flat)
    mov byte [ebp + H_CLEAR_LETTER_PRINTING_DELAY_FLAGS], 0x02  ; ld a, %10
    ; DEVIATION(window-list): pokédex flavor mode. The text engine's dialog helpers
    ; (sync_dialog_window per char, manual_text_scroll at the <PAGE> break) must mirror
    ; the full 20×18 page and keep the pokédex window, NOT do the dialog-box copy +
    ; bottom-window swap (which showed only the bottom 6 rows of the entry).
    mov byte [g_dex_flavor_active], 1
    call TextCommandProcessor            ; ESI = stream, EBX = cursor
    mov byte [g_dex_flavor_active], 0
    mov byte [ebp + H_CLEAR_LETTER_PRINTING_DELAY_FLAGS], 0     ; xor a
    call dex_mirror                      ; port: push the finished flavor to the window
    ret

; ---------------------------------------------------------------------------
; Pokedex_PrepareDexEntryForPrinting — pret ref: pokedex.asm.
; The GB-Printer entry layout (a 13-row box), with <PAGE> forced to act as <NEXT>.
; Its only caller is PrintPokedexEntry, which is a ret-only STUB (the GB Printer is a
; serial-link peripheral — TODO-HW: serial), so nothing reaches this today; it is
; ported in full so that filling that stub in is all the printer needs.
; ---------------------------------------------------------------------------
Pokedex_PrepareDexEntryForPrinting:
    mov esi, HL(0, 0)                    ; hlcoord 0,0
    mov edx, GBSCR_W                     ; ld de, SCREEN_WIDTH (vertical)
    mov bh, 0x66
    mov bl, 0x0D                         ; lb bc, $66, $d
    call DrawTileLine
    mov esi, HL(19, 0)                   ; hlcoord 19,0
    mov edx, GBSCR_W
    mov bh, 0x67
    mov bl, 0x0D
    call DrawTileLine
    mov esi, HL(0, 13)                   ; hlcoord 0,13
    mov edx, 1                           ; ld de, $1 (horizontal)
    mov bh, 0x6F
    mov bl, GBSCR_W                      ; lb bc, $6f, SCREEN_WIDTH
    call DrawTileLine
    mov byte [ebp + HL(0, 13)],  0x6C    ; ldcoord_a 0,13
    mov byte [ebp + HL(19, 13)], 0x6E    ; ldcoord_a 19,13
    ; TODO-HW(serial): pret loads the stream pointer from wPrinterPokedexEntryTextPointer,
    ; which only the printer path writes. In the port the flavor is flat .data reached
    ; through dex_flavor_ptr, which DrawDexEntryOnScreen has already set for the mon on
    ; screen — so this routine prints the same stream pret would, and the pret WRAM word
    ; stays unpopulated until the printer itself is ported.
    mov ebx, HL(1, 1)                    ; bccoord 1,1
    or byte [ebp + H_UI_LAYOUT_FLAGS], 1 << BIT_PAGE_CHAR_IS_NEXT
    call Pokedex_PrintFlavorTextAtBC
    and byte [ebp + H_UI_LAYOUT_FLAGS], (~(1 << BIT_PAGE_CHAR_IS_NEXT)) & 0xFF
    ret

; ---------------------------------------------------------------------------
; dex_stage_flavor — copy the flat flavor stream at [dex_flavor_ptr] into GB scratch
; (wDexFlavorBuf), stopping after the first $50. Out: ESI = wDexFlavorBuf (GB offset).
; Clobbers EAX/ECX/EDX/EDI. Port plumbing; not a pret routine.
; ---------------------------------------------------------------------------
dex_stage_flavor:
    mov edx, [dex_flavor_ptr]            ; flat source
    lea edi, [ebp + wDexFlavorBuf]       ; GB-space destination (flat)
    mov ecx, DEX_FLAVOR_MAX
.copy:
    mov al, [edx]
    mov [edi], al
    inc edx
    inc edi
    cmp al, 0x50                         ; TX_END / '@' — the first one wins
    je .done
    dec ecx
    jnz .copy
.done:
    mov esi, wDexFlavorBuf               ; GB offset for TCP ([ebp + esi])
    ret

; ---------------------------------------------------------------------------
; dex_mirror / dex_show_window — the DATA page's window plumbing, the same
; stand-in for pret's hAutoBGTransferEnabled VBlank transfer as pdex_mirror /
; pdex_show_window, on the UI_POKEDEX_ENTRY_* anchor. Preserve all registers.
; ; PROJ menus: window = UI_POKEDEX_ENTRY_(WX,WY,CLIP,MAXY).
; ---------------------------------------------------------------------------
dex_mirror:
    pushad
    xor ebx, ebx
.row:
    imul esi, ebx, GBSCR_W
    lea esi, [ebp + esi + W_TILEMAP]
    mov edi, ebx
    shl edi, 5                           ; ×32 tilemap stride
    lea edi, [ebp + edi + GB_TILEMAP1]
    mov ecx, GBSCR_W
    rep movsb
    inc ebx
    cmp ebx, UI_POKEDEX_ENTRY_GBH        ; 18 rows
    jb .row
    popad
    ret

dex_show_window:
    pushad
    call dex_mirror
    mov dword [g_bg_whiteout], 1         ; the dex page is a full-screen takeover
    mov eax, UI_POKEDEX_ENTRY_WX
    mov ebx, UI_POKEDEX_ENTRY_WY
    mov ecx, UI_POKEDEX_ENTRY_CLIP
    mov edx, UI_POKEDEX_ENTRY_MAXY
    mov esi, GB_TILEMAP1
    xor edi, edi                         ; start_row = 0
    call set_single_window
    popad
    ret

; RunDefaultPaletteCommand was DUPLICATED here as a second file-local copy of the
; body naming_screen.asm already `global`s (both just set the default palette id and
; tail-jump RunPaletteCommand). Two bodies for one pret label is a label-fidelity
; violation; the copy is deleted and the global is externed instead. Ledger M-67.
; GetCryData was a ret-STUB parked HERE, in a source-mirror file — violation #1 of the
; two its own comment admitted to. It is a home routine (pret home/pokemon.asm), so it
; has moved to home_stubs.asm under its pret label, with its note. Ledger M-66/M-32.
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
; Used by both halves of this file (ShowPokedexMenu.setUpGraphics and ShowPokedexData).
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
%define DEBUG_PDEX
%endif
%ifdef DEBUG_G2
%define DEBUG_PDEX
%endif
%ifdef DEBUG_PDEX
extern LoadFontTilePatterns            ; gfx/load_font.asm
extern ClearSprites                    ; gfx/sprites.asm
extern DumpBackbuffer                  ; debug/debug_dump.asm — writes FRAME.BIN + exits
extern SeedDeterministicPlayerIdentity ; engine/debug/debug_party.asm — "RED"/id 0 (seed.lua spec)
%endif

%ifdef DEBUG_G1
global RunPokedexTest
extern PlaceMenuCursor                 ; home/window.asm

RunPokedexTest:
%ifdef PDEX_AREA
    ; ---- AREA-option gate (M-64) -----------------------------------------
    ; Renders the side menu's AREA screen by making the ONE call .choseArea now
    ; makes. Until 2026-07-14 that call did not exist, so LoadTownMap_Nest — a
    ; complete, linked routine — had never executed even once. This exists so the
    ; claim "the AREA option works again" rests on a photograph, not on a faithdiff.
    ; Input contract as pret's side menu leaves it: wPokedexNum holds the INTERNAL
    ; index (PokedexToIndex ran), which is also wNamedObjectIndex (same union, 0xD11D)
    ; and is what GetMonName + DisplayWildLocations read.
    or byte [ebp + W_FONT_LOADED], (1 << BIT_FONT_LOADED)
    call LoadFontTilePatterns
    call ClearSprites
    mov byte [ebp + wPokedexNum], 16                      ; dex #16 = PIDGEY (has nests)
    call PokedexToIndex                                   ; dex# -> internal index
    call LoadTownMap_Nest                                 ; .choseArea's call
.hangArea:
    ; DelayFrame (not a bare spin) so AutoKeyDrive keeps ticking even if
    ; LoadTownMap_Nest returned early — otherwise the autokey clock stops and the
    ; dump never fires, which reads exactly like a crash.
    call DelayFrame
    jmp .hangArea
%else
    ; identity = the golden spec ("RED" / id 0): the bare boot leaves wPlayerID
    ; as InitPlayerData's RNG roll (F-5 class — not even reproducible run to
    ; run), and the pokedex_list golden compares wPlayerName/wPlayerID
    call SeedDeterministicPlayerIdentity
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
    ; Mon 4 (CHARMANDER, bit 3) is deliberately left UNSEEN so the visible window
    ; contains one unseen row: that is the only thing that draws .dashedLine
    ; ("----------"), and with an all-seen seed the placeholder path renders never.
    mov byte [ebp + wPokedexSeen + 0], 0xF7               ; mons 1-3,5-8 seen (4 UNSEEN)
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
%endif ; PDEX_AREA
%endif ; DEBUG_G1

; ===========================================================================
; RunPokedexEntryTest — the DATA page's FRAME.BIN gate (make DEBUG_G2=1). Seeds a
; seen+owned mon (RHYDON, internal index 1 → national dex 112), then drives the REAL
; live path: the side menu's DATA option calls ShowPokedexDataInternal directly
; (.choseData), whose .waitForButtonPress self-dumps FRAME.BIN under DEBUG_G2.
; ===========================================================================
%ifdef DEBUG_G2
global RunPokedexEntryTest
RunPokedexEntryTest:
    ; identity = the golden spec (F-5 class, same rationale as RunPokedexTest)
    call SeedDeterministicPlayerIdentity
    mov byte [ebp + wPokedexNum], 1       ; RHYDON internal index (→ dex 112)
    mov byte [ebp + wCurPartySpecies], 1
    ; mark RHYDON (dex 112) seen + owned: bit 111 → byte 13, bit 7. The SEEN bit
    ; is load-bearing for the golden: pret's CONTENTS list only opens a mon's
    ; side menu if it is seen, so the mGBA scenario cannot reach this page
    ; without it (the comment used to say "seen + owned" while the code set
    ; owned only — the golden is what caught the lie).
    or byte [ebp + wPokedexSeen  + 13], 1 << 7
    or byte [ebp + wPokedexOwned + 13], 1 << 7
    or byte [ebp + W_FONT_LOADED], (1 << BIT_FONT_LOADED)
    call LoadFontTilePatterns
    call LoadPokedexTilePatterns          ; the dex tileset, as .setUpGraphics loads it
    call ClearSprites
    mov byte [ebp + W_UPDATE_SPRITES_ENABLED], 0
    call ShowPokedexDataInternal
.hangEntry:
    ; DelayFrame (not a bare spin) so AutoKeyDrive keeps ticking even if
    ; ShowPokedexDataInternal returns early — otherwise the autokey clock stops
    ; and the dump never fires, which reads exactly like a crash (PDEX_AREA note).
    call DelayFrame
    jmp .hangEntry
%endif ; DEBUG_G2
