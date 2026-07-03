; ===========================================================================
; main_menu.asm — the boot main menu (menus-port Session 7, package E).
; Faithful port of pret engine/menus/main_menu.asm:
;   MainMenu / InitOptions / Func_5cc1 / StartNewGame(Debug) / SpecialEnterMap /
;   DisplayContinueGameInfo / PrintSaveScreenText / PrintNumBadges /
;   PrintNumOwnedMons / PrintPlayTime / DisplayOptionMenu / CheckForPlayerNameInSRAM.
;
; STRUCTURE + FLOW mirror pret EXACTLY (same labels, same branch order, same call
; order). The only divergences are the three tagged classes:
;   ; PROJ      — GB→canvas geometry (cites a UI_* equate from ui_layout_menus.inc)
;   ; TODO-HW:  — a Game-Boy I/O boundary with no port hardware
;   ; DEVIATION — a port-model plumbing note (window compositor / text stride)
;
; PORT MODEL (window compositor; same as draw_start_menu.asm / options.asm):
; - The CONTINUE/NEW GAME box and the PLAYER/BADGES/#DEX/TIME info panel are drawn
;   at UI_*-projected coordinates into the 40-wide stride-40 W_TILEMAP canvas
;   (the DisplayTextBoxID_ canvas model). MainMenuShowWindow / the info panel's
;   DisplayContinueGameInfoShowWindow then blit the box rects → GB_TILEMAP1 and
;   define window descriptors from the UI_MAIN_MENU_* / UI_CONTINUE_INFO_* equates,
;   over a g_bg_whiteout blank background (the main menu is a plain-background
;   screen). The live ▶ cursor reaches the window via mainmenu_mirror armed as
;   menu_redraw_cb (the S3/S4/S6 per-frame mirror pattern).
; - The two panels source DISJOINT GB_TILEMAP1 row bands (menu rows 0.., info
;   rows CI_SROW..) so both windows composite simultaneously (add_window), matching
;   the real screen (menu box + save info panel visible together).
;
; ; PROJ menus: CONTINUE/NEW GAME box   -> UI_MAIN_MENU_*     (GB(0,0) 15x8, center/top)
; ; PROJ menus: PLAYER/BADGES/#DEX/TIME -> UI_CONTINUE_INFO_* (GB(4,7) 16x10, center/top)
;
; Register map (CLAUDE.md): A=AL, BC=BX (B=BH,C=BL), DE=DX (D=DH,E=DL),
; HL=ESI, EBP = GB memory base. GB memory is [ebp + symbol].
;
; Build (standalone check):
;   nasm -f coff -I include/ -I . -o /dev/null src/engine/menus/main_menu.asm
; ---------------------------------------------------------------------------
bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_macros.inc"

%define UI_LAYOUT_EQUATES_ONLY 1
%include "assets/ui_layout_menus.inc"

; ---------------------------------------------------------------------------
; Constants pret pulls from constants/*.asm (deterministic enum values; defined
; locally, %ifndef-guarded, so a future root-promotion into an include is safe).
; ---------------------------------------------------------------------------
%ifndef LINK_STATE_NONE
LINK_STATE_NONE         equ 0x00        ; constants/serial_constants.asm
%endif
%ifndef TRUE
TRUE                    equ 1
%endif
%ifndef HALL_OF_FAME
HALL_OF_FAME            equ 0x76        ; constants/map_constants.asm (map id $76)
%endif
%ifndef LEADING_ZEROES
LEADING_ZEROES          equ 1 << BIT_LEADING_ZEROES   ; text_constants.asm ($80)
%endif
; wStatusFlags6 bit indices (constants/ram_constants.asm)
%ifndef BIT_GAME_TIMER_COUNTING
BIT_GAME_TIMER_COUNTING equ 0
%endif
%ifndef BIT_DEBUG_MODE
BIT_DEBUG_MODE          equ 1
%endif
%ifndef BIT_FLY_OR_DUNGEON_WARP
BIT_FLY_OR_DUNGEON_WARP equ 2
%endif
; wCurrentMapScriptFlags bit (constants/ram_constants.asm)
%ifndef BIT_CUR_MAP_LOADED_1
BIT_CUR_MAP_LOADED_1    equ 5
%endif

; ---------------------------------------------------------------------------
; WRAM addresses pret names that are not yet in gb_memmap.inc. Values are the
; authoritative origin/symbols:pokeyellow.sym bank-00 offsets (reported for root
; to promote into gb_memmap.inc). %ifndef-guarded so promotion is a no-op here.
; ---------------------------------------------------------------------------
%ifndef wDefaultMap
wDefaultMap             equ 0xD07B      ; sym 00:d07b (union lane of wAnimationID)
%endif
%ifndef wDestinationMap
wDestinationMap         equ 0xD719      ; sym 00:d719
%endif
%ifndef wCableClubDestinationMap
wCableClubDestinationMap equ 0xD72C     ; sym 00:d72c (= wStatusFlags3 union lane)
%endif
%ifndef wEnteringCableClub
wEnteringCableClub      equ 0xCC47      ; sym 00:cc47 (pret ram/wram.asm:430)
%endif

; charmap control codes (constants/charmap.asm; text.asm keeps its own copies).
%ifndef CHAR_NEXT
CHAR_NEXT               equ 0x4E        ; <NEXT> — next line
%endif
%ifndef CHAR_TERMINATOR
CHAR_TERMINATOR         equ 0x50        ; '@' — string terminator
%endif

; ---------------------------------------------------------------------------
; GB→canvas projection macros (cite the UI_* equates; NOT bare literals).
;   MM(x,y): pret hlcoord (x,y) inside the CONTINUE/NEW GAME box  → 40-canvas offset
;   CI(x,y): pret hlcoord (x,y) inside the save-info panel        → 40-canvas offset
; Both anchors share the center/top projection (canvas_x = gbx + (COL-GBX),
; canvas_y = gby + (ROW-GBY)); CI's ROW-GBY == 0 lets PrintSaveScreenText's top
; panel (GB row 0) reuse the same basis.
; ---------------------------------------------------------------------------
%define MM(x,y) (W_TILEMAP + ((y) - UI_MAIN_MENU_GBY + UI_MAIN_MENU_ROW) * SCREEN_TILES_W + ((x) - UI_MAIN_MENU_GBX + UI_MAIN_MENU_COL))
%define CI(x,y) (W_TILEMAP + ((y) - UI_CONTINUE_INFO_GBY + UI_CONTINUE_INFO_ROW) * SCREEN_TILES_W + ((x) - UI_CONTINUE_INFO_GBX + UI_CONTINUE_INFO_COL))

MM_TOTAL_W  equ UI_MAIN_MENU_X2 - UI_MAIN_MENU_COL + 1        ; 15 tiles wide
CI_TOTAL_W  equ UI_CONTINUE_INFO_X2 - UI_CONTINUE_INFO_COL + 1 ; 16 tiles wide
CI_SROW     equ 10                                            ; info-panel GB_TILEMAP1 band

TIME_SEP    equ 0x6D          ; ':' hours/minutes separator glyph (pret ld [hl],$6d)

global MainMenu
global InitOptions
global Func_5cc1
global StartNewGame
global StartNewGameDebug
global SpecialEnterMap
global DisplayContinueGameInfo
global PrintSaveScreenText
global PrintNumBadges
global PrintNumOwnedMons
global PrintPlayTime
global DisplayOptionMenu
global CheckForPlayerNameInSRAM

; --- ported infra (text / numbers / menu driver / compositor / frame / boot) ---
extern TextBoxBorder            ; text.asm — ESI=top-left, BL=int_w, BH=int_h
extern PlaceString              ; text.asm — ESI=dest, EAX=flat src
extern text_row_stride          ; text.asm — active W_TILEMAP row stride
extern PrintNumber              ; print_num.asm — EDX=src, BH=flags|bytes, BL=digits, ESI=dest
extern CountSetBits             ; count_set_bits.asm — ESI=base, BH=len → [wNumSetBits]
extern HandleMenuInput          ; window.asm — vertical menu loop; AL=key that ended it
extern PlaceMenuCursor          ; window.asm — draw ▶ at the current item
extern menu_item_step           ; window.asm — cursor per-item row step
extern menu_redraw_cb           ; window.asm — per-frame redraw callback
extern set_single_window        ; ppu.asm — g_windows[] = one descriptor
extern add_window               ; ppu.asm — append one descriptor
extern g_bg_whiteout            ; ppu.asm — 1 = blank BG behind the window list
extern DelayFrame               ; frame.asm
extern DelayFrames              ; frame.asm — BL = frame count
extern ClearScreen              ; title.asm — blank canvas + auto-transfer
extern LoadTextBoxTilePatterns  ; load_font.asm
extern LoadFontTilePatterns     ; load_font.asm
extern UpdateSprites            ; movement.asm
extern GBPalWhiteOutWithDelay3  ; fade.asm
extern ResetPlayerSpriteData    ; reset_player_sprite.asm
extern EnterMap                 ; overworld.asm
extern DsvFileExists            ; save/dsv_io.asm — CF=1/AL=1 if POKEMON.DSV present
extern DisplayOptionMenu_       ; options.asm (package D)

; --- seams provided by other packages / root at integration (reported) ---
extern TryLoadSaveFile          ; save.asm (package H) — predef; sets wSaveFileStatus=2
extern OakSpeech                ; cutscene seam (root) — includes the naming screen (pkg C)
extern DisplayTitleScreen       ; title seam (root) — B on the menu returns to the title
extern PrepareForSpecialWarp    ; overworld warp seam (root) — HoF continue path

section .bss
align 4
mm_box_rows:  resd 1            ; total CONTINUE/NEW GAME box rows incl. borders (8 or 6)

section .text

; ===========================================================================
; MainMenu — pret ref: engine/menus/main_menu.asm:MainMenu.
; ===========================================================================
MainMenu:
    ; Check save file
    call InitOptions
    mov byte [ebp + wOptionsInitialized], 0     ; xor a ; ld [wOptionsInitialized],a
    mov byte [ebp + wSaveFileStatus], 1         ; inc a ; ld [wSaveFileStatus],a (=no save)
    call CheckForPlayerNameInSRAM
    jnc .mainMenuLoop                           ; jr nc — no save present
    call TryLoadSaveFile                         ; predef TryLoadSaveFile (sets wSaveFileStatus=2)

.mainMenuLoop:
    mov bl, 20
    call DelayFrames
    mov byte [ebp + wLinkState], LINK_STATE_NONE ; xor a ; ld [wLinkState],a
    ; ld hl, wPartyAndBillsPCSavedMenuItem / ld [hli],a ×3 / ld [hl],a  (4 zero bytes)
    mov byte [ebp + wPartyAndBillsPCSavedMenuItem + 0], 0
    mov byte [ebp + wPartyAndBillsPCSavedMenuItem + 1], 0
    mov byte [ebp + wPartyAndBillsPCSavedMenuItem + 2], 0
    mov byte [ebp + wPartyAndBillsPCSavedMenuItem + 3], 0
    mov byte [ebp + wDefaultMap], 0
    ; ld hl, wStatusFlags4 / res BIT_LINK_CONNECTED, [hl]
    and byte [ebp + W_STATUS_FLAGS_4], ~(1 << BIT_LINK_CONNECTED) & 0xFF
    call ClearScreen
    ; TODO-HW: palette HAL (Phase 5) — RunDefaultPaletteCommand loads the default
    ; CGB/DMG palette; the port palette is a placeholder, so this is a render no-op.
    call LoadTextBoxTilePatterns
    call LoadFontTilePatterns
    ; ld hl, wStatusFlags5 / set BIT_NO_TEXT_DELAY, [hl]
    or byte [ebp + W_STATUS_FLAGS_5], (1 << BIT_NO_TEXT_DELAY)

    ; DEVIATION: the box + items run on the 40-wide canvas (stride 40; items are
    ; double-spaced, matching pret's 6-row-box=3-items / 4-row-box=2-items geometry).
    mov dword [text_row_stride], SCREEN_TILES_W
    mov dword [menu_item_step], 2 * SCREEN_TILES_W

    mov al, [ebp + wSaveFileStatus]
    cmp al, 1
    jz .noSaveFile
; there's a save file
    ; hlcoord 0,0 / lb bc,6,13 / TextBoxBorder
    ; PROJ menus: box top-left = UI_MAIN_MENU_(COL,ROW) [15x8]
    mov esi, MM(0, 0)
    mov bx, (6 << 8) | 13                       ; BH=6 int rows, BL=13 int cols
    mov dword [mm_box_rows], 8
    call TextBoxBorder
    ; hlcoord 2,2 / ld de,ContinueText / PlaceString
    mov esi, MM(2, 2)
    mov eax, ContinueText
    call PlaceString
    jmp .next2
.noSaveFile:
    ; hlcoord 0,0 / lb bc,4,13 / TextBoxBorder
    mov esi, MM(0, 0)
    mov bx, (4 << 8) | 13
    mov dword [mm_box_rows], 6
    call TextBoxBorder
    mov esi, MM(2, 2)
    mov eax, NewGameText
    call PlaceString
.next2:
    ; ld hl, wStatusFlags5 / res BIT_NO_TEXT_DELAY, [hl]
    and byte [ebp + W_STATUS_FLAGS_5], ~(1 << BIT_NO_TEXT_DELAY) & 0xFF
    call UpdateSprites
    mov byte [ebp + wCurrentMenuItem], 0        ; xor a / ld [wCurrentMenuItem],a
    mov byte [ebp + wLastMenuItem], 0           ; ld [wLastMenuItem],a
    mov byte [ebp + wMenuJoypadPollCount], 0    ; ld [wMenuJoypadPollCount],a
    ; inc a → 1 → wTopMenuItemX ; inc a → 2 → wTopMenuItemY  (pret absolute 1,2)
    ; PROJ menus: cursor = (UI_MAIN_MENU_COL+1, UI_MAIN_MENU_ROW+2)
    mov byte [ebp + wTopMenuItemX], UI_MAIN_MENU_COL + 1
    mov byte [ebp + wTopMenuItemY], UI_MAIN_MENU_ROW + 2
    mov byte [ebp + wMenuWatchedKeys], PAD_A | PAD_B | PAD_START
    mov al, [ebp + wSaveFileStatus]
    mov [ebp + wMaxMenuItem], al
    ; DEVIATION: bridge the canvas box to a window (g_bg_whiteout blank bg + the
    ; single descriptor + the per-frame mirror as menu_redraw_cb). Stands in for
    ; pret relying on the LCD showing the drawn BG map directly.
    call MainMenuShowWindow
    call HandleMenuInput
    test al, PAD_B                              ; bit B_PAD_B, a
    jnz .backToTitle                            ; jp nz DisplayTitleScreen
    mov bl, 20
    call DelayFrames
    mov al, [ebp + wCurrentMenuItem]
    mov bh, al                                  ; ld b, a
    mov al, [ebp + wSaveFileStatus]
    cmp al, 2
    jz .skipInc                                 ; jp z .skipInc
; If there's no save file, increment the current menu item so that the numbers
; are the same whether or not there's a save file.
    inc bh                                      ; inc b
.skipInc:
    mov al, bh                                  ; ld a, b
    test al, al                                 ; and a
    jz .choseContinue
    cmp al, 1
    jz .startNewGame                            ; jp z StartNewGame
    call DisplayOptionMenu
    mov byte [ebp + wOptionsInitialized], TRUE  ; ld a,TRUE / ld [wOptionsInitialized],a
    jmp .mainMenuLoop
.startNewGame:
    jmp StartNewGame
.backToTitle:
    jmp DisplayTitleScreen                      ; go back to the title screen

.choseContinue:
    call DisplayContinueGameInfo
    ; ld hl, wCurrentMapScriptFlags / set BIT_CUR_MAP_LOADED_1, [hl]
    or byte [ebp + W_CURRENT_MAP_SCRIPT_FLAGS], (1 << BIT_CUR_MAP_LOADED_1)
.inputLoop:
    ; xor a / ldh [hJoyPressed],a / ldh [hJoyReleased],a / ldh [hJoyHeld],a / call Joypad
    ; TODO-HW: joypad HAL — the port has no `Joypad` routine; hJoyHeld is refreshed
    ; by the keyboard ISR through DelayFrame (joypad_update). The three clears are
    ; kept; `call Joypad` becomes `call DelayFrame` (one poll frame, then read).
    mov byte [ebp + H_JOY_PRESSED], 0
    mov byte [ebp + H_JOY_RELEASED], 0
    mov byte [ebp + H_JOY_HELD], 0
    call DelayFrame
    mov al, [ebp + H_JOY_HELD]                  ; ldh a, [hJoyHeld]
    test al, PAD_A                              ; bit B_PAD_A, a
    jnz .pressedA
    test al, PAD_B                              ; bit B_PAD_B, a
    jnz .backToMainLoop                         ; jp nz .mainMenuLoop
    jmp .inputLoop
.backToMainLoop:
    jmp .mainMenuLoop
.pressedA:
    call GBPalWhiteOutWithDelay3
    call ClearScreen
    mov byte [ebp + W_PLAYER_DIRECTION], PLAYER_DIR_DOWN
    mov bl, 10
    call DelayFrames
    mov al, [ebp + wNumHoFTeams]
    test al, al                                 ; and a
    jz .toSpecialEnterMap                       ; jp z SpecialEnterMap
    mov al, [ebp + wCurMap]
    cmp al, HALL_OF_FAME
    jnz .toSpecialEnterMap                      ; jp nz SpecialEnterMap
    mov byte [ebp + wDestinationMap], 0         ; xor a / ld [wDestinationMap],a
    ; ld hl, wStatusFlags6 / set BIT_FLY_OR_DUNGEON_WARP, [hl]
    or byte [ebp + wStatusFlags6], (1 << BIT_FLY_OR_DUNGEON_WARP)
    call PrepareForSpecialWarp
    jmp SpecialEnterMap
.toSpecialEnterMap:
    jmp SpecialEnterMap

; ===========================================================================
; InitOptions — pret ref: main_menu.asm:InitOptions.
; ===========================================================================
InitOptions:
    mov byte [ebp + wLetterPrintingDelayFlags], 1 << BIT_FAST_TEXT_DELAY
    mov byte [ebp + wOptions], TEXT_DELAY_MEDIUM
    ; ld a,64 / ld [wPrinterSettings],a — plain WRAM value (printer/audio setting;
    ; the printer hardware is TODO-HW only where a byte is actually transmitted,
    ; which is not here — this is a value store, kept verbatim).
    mov byte [ebp + wPrinterSettings], 64
    ret

; ===========================================================================
; Func_5cc1 — pret ref: main_menu.asm:Func_5cc1 (unused; the `ret c` is always
; taken because $6d < $80, so the NotEnoughMemoryText PrintText branch is dead
; code). Ported faithfully; the dead branch is a comment (NotEnoughMemoryText is
; a bank-far text stream with no port far-text infra, and is never reached).
; ===========================================================================
Func_5cc1:
    mov al, 0x6D
    cmp al, 0x80
    jc .done                                    ; ret c — always executed
    ; ld hl, NotEnoughMemoryText / call PrintText   (unreachable)
.done:
    ret

; ===========================================================================
; StartNewGame — pret ref: main_menu.asm:StartNewGame.
; Ensure debug mode is not used when starting a regular new game, then fall
; through to StartNewGameDebug.
; ===========================================================================
StartNewGame:
    ; ld hl, wStatusFlags6 / res BIT_DEBUG_MODE, [hl]
    and byte [ebp + wStatusFlags6], ~(1 << BIT_DEBUG_MODE) & 0xFF
    ; fallthrough
StartNewGameDebug:
    ; DEVIATION: clear the window-model whiteout so the OakSpeech cutscene / new
    ; overworld render on a clean BG (pret has no compositor concept).
    mov dword [g_bg_whiteout], 0
    call OakSpeech                              ; includes the naming screen (pkg C)
    mov byte [ebp + W_PLAYER_MOVING_DIRECTION], 0x8   ; ld a,$8 / ld [wPlayerMovingDirection],a
    mov bl, 20
    call DelayFrames
    ; fallthrough to SpecialEnterMap

; ===========================================================================
; SpecialEnterMap — pret ref: main_menu.asm:SpecialEnterMap:: — the hand-off to
; the overworld boot (root wires EnterMap). Reached from the continue / new-game /
; special-warp paths.
; ===========================================================================
SpecialEnterMap:
    ; DEVIATION: drop the menu whiteout before entering the overworld.
    mov dword [g_bg_whiteout], 0
    mov byte [ebp + H_JOY_PRESSED], 0           ; xor a / ldh [hJoyPressed],a
    mov byte [ebp + H_JOY_HELD], 0              ; ldh [hJoyHeld],a
    mov byte [ebp + H_JOY5], 0                  ; ldh [hJoy5],a
    mov byte [ebp + wCableClubDestinationMap], 0
    ; ld hl, wStatusFlags6 / set BIT_GAME_TIMER_COUNTING, [hl]
    or byte [ebp + wStatusFlags6], (1 << BIT_GAME_TIMER_COUNTING)
    call ResetPlayerSpriteData
    mov bl, 20
    call DelayFrames
    call Func_5cc1
    mov al, [ebp + wEnteringCableClub]
    test al, al                                 ; and a
    jnz .ret                                    ; ret nz
    jmp EnterMap
.ret:
    ret

; ===========================================================================
; DisplayContinueGameInfo — pret ref: main_menu.asm:DisplayContinueGameInfo.
; Draw the PLAYER / BADGES / #DEX / TIME panel of the loaded save.
; ; PROJ menus: box + fields project onto UI_CONTINUE_INFO_* (GB(4,7) 16x10).
; ===========================================================================
DisplayContinueGameInfo:
    ; DEVIATION: the info panel runs on the 40-wide canvas.
    mov dword [text_row_stride], SCREEN_TILES_W
    mov byte [ebp + hAutoBGTransferEnabled], 0  ; xor a / ldh [hAutoBGTransferEnabled],a
    mov esi, CI(4, 7)                           ; hlcoord 4,7
    mov bx, (8 << 8) | 14                       ; lb bc, 8, 14 → BH=8 rows, BL=14 cols
    call TextBoxBorder
    mov esi, CI(5, 9)                           ; hlcoord 5,9
    mov eax, SaveScreenInfoText
    call PlaceString
    mov esi, CI(12, 9)                          ; hlcoord 12,9
    lea eax, [ebp + wPlayerName]                ; ld de, wPlayerName (flat src)
    call PlaceString
    mov esi, CI(17, 11)                         ; hlcoord 17,11
    call PrintNumBadges
    mov esi, CI(16, 13)                         ; hlcoord 16,13
    call PrintNumOwnedMons
    mov esi, CI(13, 15)                         ; hlcoord 13,15
    call PrintPlayTime
    mov byte [ebp + hAutoBGTransferEnabled], 1  ; ld a,1 / ldh [hAutoBGTransferEnabled],a
    ; DEVIATION: expose the finished panel as a window (add over the menu box).
    call DisplayContinueGameInfoShowWindow
    mov bl, 30                                  ; ld c,30
    jmp DelayFrames                             ; jp DelayFrames (tail)

; ===========================================================================
; PrintSaveScreenText — pret ref: main_menu.asm:PrintSaveScreenText.
; The START-menu SAVE screen's identical PLAYER/BADGES/#DEX/TIME panel, at the top
; of the screen (hlcoord 4,0). Called by engine/menus/save.asm (package H).
; DEVIATION: this panel's window plumbing + a dedicated UI element are owned by
;   package H (the SAVE screen). The DRAW is ported here faithfully into the
;   canvas via the CI() projection (its ROW-GBY offset is 0, so the top-of-screen
;   box reuses the same center-anchored basis). See report: needs UI_SAVE_INFO.
; ; PROJ menus: fields project via the UI_CONTINUE_INFO_* center anchor.
; ===========================================================================
PrintSaveScreenText:
    mov dword [text_row_stride], SCREEN_TILES_W
    mov byte [ebp + hAutoBGTransferEnabled], 0  ; xor a / ldh [hAutoBGTransferEnabled],a
    mov esi, CI(4, 0)                           ; hlcoord 4,0
    mov bx, (8 << 8) | 14                       ; lb bc, 8, 14
    call TextBoxBorder
    call LoadTextBoxTilePatterns
    call UpdateSprites
    mov esi, CI(5, 2)                           ; hlcoord 5,2
    mov eax, SaveScreenInfoText
    call PlaceString
    mov esi, CI(12, 2)                          ; hlcoord 12,2
    lea eax, [ebp + wPlayerName]
    call PlaceString
    mov esi, CI(17, 4)                          ; hlcoord 17,4
    call PrintNumBadges
    mov esi, CI(16, 6)                          ; hlcoord 16,6
    call PrintNumOwnedMons
    mov esi, CI(13, 8)                          ; hlcoord 13,8
    call PrintPlayTime
    mov byte [ebp + hAutoBGTransferEnabled], 1  ; ld a,$1 / ldh [hAutoBGTransferEnabled],a
    mov bl, 30                                  ; ld c,30
    jmp DelayFrames                             ; jp DelayFrames (tail)

; ===========================================================================
; PrintNumBadges — pret ref: main_menu.asm:PrintNumBadges.
; In: ESI = dest tile cursor. Out (tail PrintNumber): 2-digit badge count.
; ===========================================================================
PrintNumBadges:
    push esi                                    ; push hl
    mov esi, W_OBTAINED_BADGES                  ; ld hl, wObtainedBadges
    mov bh, 1                                   ; ld b, $1
    call CountSetBits
    pop esi                                     ; pop hl
    mov edx, wNumSetBits                        ; ld de, wNumSetBits
    mov bx, (1 << 8) | 2                        ; lb bc, 1, 2 → BH=1 byte, BL=2 digits
    jmp PrintNumber                             ; jp PrintNumber (tail)

; ===========================================================================
; PrintNumOwnedMons — pret ref: main_menu.asm:PrintNumOwnedMons.
; ===========================================================================
PrintNumOwnedMons:
    push esi                                    ; push hl
    mov esi, wPokedexOwned                      ; ld hl, wPokedexOwned
    mov bh, wPokedexOwnedEnd - wPokedexOwned    ; ld b, wPokedexOwnedEnd - wPokedexOwned
    call CountSetBits
    pop esi                                     ; pop hl
    mov edx, wNumSetBits                        ; ld de, wNumSetBits
    mov bx, (1 << 8) | 3                        ; lb bc, 1, 3
    jmp PrintNumber                             ; jp PrintNumber (tail)

; ===========================================================================
; PrintPlayTime — pret ref: main_menu.asm:PrintPlayTime.
; ===========================================================================
PrintPlayTime:
    mov edx, wPlayTimeHours                     ; ld de, wPlayTimeHours
    mov bx, (1 << 8) | 3                        ; lb bc, 1, 3
    call PrintNumber
    mov byte [ebp + esi], TIME_SEP              ; ld [hl], $6d (':')
    inc esi                                     ; inc hl
    mov edx, wPlayTimeMinutes                   ; ld de, wPlayTimeMinutes
    mov bx, ((LEADING_ZEROES | 1) << 8) | 2     ; lb bc, LEADING_ZEROES | 1, 2
    jmp PrintNumber                             ; jp PrintNumber (tail)

; ===========================================================================
; DisplayOptionMenu — pret ref: main_menu.asm:DisplayOptionMenu.
; ===========================================================================
DisplayOptionMenu:
    call DisplayOptionMenu_                     ; callfar DisplayOptionMenu_
    ret

; ===========================================================================
; CheckForPlayerNameInSRAM — pret ref: main_menu.asm:CheckForPlayerNameInSRAM.
; TODO-HW: SRAM banking — pret enables SRAM (rRAMG/rBMODE/rRAMB) and scans
; sPlayerName for '@' (found → scf). The port has no SRAM: the whole routine
; collapses to a POKEMON.DSV presence check. DsvFileExists returns CF=1 on
; "found", preserving pret's scf found-path polarity into the caller's `jr nc`.
; ===========================================================================
CheckForPlayerNameInSRAM:
    call DsvFileExists
    ret

; ===========================================================================
; Port window plumbing (DEVIATION — window compositor bridge).
; ===========================================================================

; MainMenuShowWindow — blank BG, mirror the box → GB_TILEMAP1 rows 0.., define the
; single window from UI_MAIN_MENU_*, arm the per-frame mirror callback.
; ; PROJ menus: window = UI_MAIN_MENU_(WX,WY,CLIP); max_y = box_rows*8.
MainMenuShowWindow:
    mov dword [g_bg_whiteout], 1                ; plain background behind the box
    call mainmenu_mirror
    mov eax, UI_MAIN_MENU_WX
    mov ebx, UI_MAIN_MENU_WY
    mov ecx, UI_MAIN_MENU_CLIP
    mov edx, [mm_box_rows]
    shl edx, 3                                  ; max_y = rows * 8
    mov esi, GB_TILEMAP1
    xor edi, edi                                ; start_row = 0
    call set_single_window
    mov dword [menu_redraw_cb], mainmenu_mirror
    ret

; mainmenu_mirror — copy the box rect (canvas UI_MAIN_MENU_(COL,ROW), 15 wide,
; mm_box_rows tall) → GB_TILEMAP1 rows 0.. cols 0..14. Preserves all registers
; (doubles as menu_redraw_cb inside HandleMenuInput).
mainmenu_mirror:
    pushad
    xor ebx, ebx                                ; row
.row:
    mov esi, ebx
    imul esi, esi, SCREEN_TILES_W
    lea esi, [ebp + esi + W_TILEMAP + UI_MAIN_MENU_ROW * SCREEN_TILES_W + UI_MAIN_MENU_COL]
    mov edi, ebx
    shl edi, 5                                  ; row * 32 tilemap stride
    lea edi, [ebp + edi + GB_TILEMAP1]
    mov ecx, MM_TOTAL_W
    rep movsb
    inc ebx
    cmp ebx, [mm_box_rows]
    jb .row
    popad
    ret

; DisplayContinueGameInfoShowWindow — mirror the info panel → GB_TILEMAP1 rows
; CI_SROW.. (a band disjoint from the menu box), append its window over the menu.
; ; PROJ menus: window = UI_CONTINUE_INFO_(WX,WY,CLIP,MAXY).
DisplayContinueGameInfoShowWindow:
    call dcgi_mirror
    mov eax, UI_CONTINUE_INFO_WX
    mov ebx, UI_CONTINUE_INFO_WY
    mov ecx, UI_CONTINUE_INFO_CLIP
    mov edx, UI_CONTINUE_INFO_MAXY
    mov esi, GB_TILEMAP1
    mov edi, CI_SROW                            ; distinct source band
    call add_window
    ret

; dcgi_mirror — copy the info panel rect (canvas UI_CONTINUE_INFO_(COL,ROW), 16
; wide, UI_CONTINUE_INFO_GBH tall) → GB_TILEMAP1 rows CI_SROW.. Preserves regs.
dcgi_mirror:
    pushad
    xor ebx, ebx                                ; row
.row:
    mov esi, ebx
    add esi, UI_CONTINUE_INFO_ROW
    imul esi, esi, SCREEN_TILES_W
    lea esi, [ebp + esi + W_TILEMAP + UI_CONTINUE_INFO_COL]
    mov edi, ebx
    add edi, CI_SROW
    shl edi, 5
    lea edi, [ebp + edi + GB_TILEMAP1]
    mov ecx, CI_TOTAL_W
    rep movsb
    inc ebx
    cmp ebx, UI_CONTINUE_INFO_GBH
    jb .row
    popad
    ret

; ===========================================================================
; Strings (Tier-2 code data — hand-authored GB charmap; 'A'=$80, ' '=$7F,
; '#'=$54 → "POKé", '@'=$50, <NEXT>=$4E). pret aliases these labels.
; ===========================================================================
section .data
align 4

; pret ref: main_menu.asm:ContinueText / NewGameText (NewGameText follows so the
; save-present PlaceString of ContinueText falls through into it, exactly as pret).
ContinueText:
    db 0x82, 0x8E, 0x8D, 0x93, 0x88, 0x8D, 0x94, 0x84    ; "CONTINUE"
    db CHAR_NEXT                                          ; next ""
    ; fallthrough
NewGameText:
    db 0x8D, 0x84, 0x96, 0x7F, 0x86, 0x80, 0x8C, 0x84    ; "NEW GAME"
    db CHAR_NEXT, 0x8E, 0x8F, 0x93, 0x88, 0x8E, 0x8D      ; next "OPTION"
    db CHAR_TERMINATOR                                    ; '@'

; pret ref: main_menu.asm:SaveScreenInfoText
;   "PLAYER" next "BADGES    " next "#DEX    " next "TIME@"
SaveScreenInfoText:
    db 0x8F, 0x8B, 0x80, 0x98, 0x84, 0x91                            ; "PLAYER"
    db CHAR_NEXT
    db 0x81, 0x80, 0x83, 0x86, 0x84, 0x92, 0x7F, 0x7F, 0x7F, 0x7F    ; "BADGES    "
    db CHAR_NEXT
    db 0x54, 0x83, 0x84, 0x97, 0x7F, 0x7F, 0x7F, 0x7F                ; "#DEX    "
    db CHAR_NEXT
    db 0x93, 0x88, 0x8C, 0x84                                        ; "TIME"
    db CHAR_TERMINATOR                                               ; '@'

; ===========================================================================
; RunMainMenuTest — menus S7 package E FRAME.BIN gate (static open state).
; Seeds a save (PrepareNewGameDebug party + name/badges/dex/time, then DsvWriteSave
; so a POKEMON.DSV exists), forces the save-present menu, draws the CONTINUE/NEW
; GAME box + ▶ cursor and the DisplayContinueGameInfo panel WITHOUT entering the
; blocking HandleMenuInput loop (same draw calls as MainMenu.mainMenuLoop), then
; renders 3 frames and dumps FRAME.BIN. Never returns.
; In: EBP = GB base.  make DEBUG_MAINMENU=1  (root wires the flag + call site).
; ===========================================================================
%ifdef DEBUG_MAINMENU
global RunMainMenuTest
extern PrepareNewGameDebug      ; debug/debug_party.asm — seed a debug party
extern DsvWriteSave             ; save/dsv_io.asm — serialize save → POKEMON.DSV
extern ClearSprites             ; gfx/sprites.asm
extern DumpBackbuffer           ; debug/debug_dump.asm — writes FRAME.BIN + exits

section .text
RunMainMenuTest:
    call PrepareNewGameDebug
    ; player name "RED@"
    mov byte [ebp + wPlayerName + 0], 0x91      ; R
    mov byte [ebp + wPlayerName + 1], 0x84      ; E
    mov byte [ebp + wPlayerName + 2], 0x83      ; D
    mov byte [ebp + wPlayerName + 3], CHAR_TERMINATOR
    mov byte [ebp + W_OBTAINED_BADGES], 0x1F    ; 5 badges
    mov byte [ebp + wPokedexOwned + 0], 0xFF    ; a few owned mons
    mov byte [ebp + wPokedexOwned + 1], 0x0F
    mov byte [ebp + wPlayTimeHours], 5
    mov byte [ebp + wPlayTimeMinutes], 30
    call DsvWriteSave                           ; make DsvFileExists true

    ; font + text-box tiles into vFont
    or byte [ebp + W_FONT_LOADED], (1 << BIT_FONT_LOADED)
    call LoadFontTilePatterns
    call LoadTextBoxTilePatterns
    call ClearSprites
    mov byte [ebp + W_UPDATE_SPRITES_ENABLED], 0

    mov byte [ebp + wSaveFileStatus], 2         ; force the save-present menu
    ; --- draw the CONTINUE/NEW GAME/OPTION box (MainMenu save-present branch) ---
    mov dword [text_row_stride], SCREEN_TILES_W
    mov dword [menu_item_step], 2 * SCREEN_TILES_W
    mov esi, MM(0, 0)
    mov bx, (6 << 8) | 13
    mov dword [mm_box_rows], 8
    call TextBoxBorder
    mov esi, MM(2, 2)
    mov eax, ContinueText
    call PlaceString
    mov byte [ebp + wTopMenuItemX], UI_MAIN_MENU_COL + 1
    mov byte [ebp + wTopMenuItemY], UI_MAIN_MENU_ROW + 2
    mov byte [ebp + wCurrentMenuItem], 0
    mov byte [ebp + wLastMenuItem], 0
    call MainMenuShowWindow
    call PlaceMenuCursor                        ; ▶ on CONTINUE
    call mainmenu_mirror

    ; --- the save-info panel (real routine; adds its own window) ---
    call DisplayContinueGameInfo

    call DelayFrame
    call DelayFrame
    call DelayFrame
    call DumpBackbuffer                          ; writes FRAME.BIN + exits
.hang:
    jmp .hang
%endif
