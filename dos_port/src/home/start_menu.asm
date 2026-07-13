; start_menu.asm — DisplayStartMenu / RedisplayStartMenu / CloseStartMenu.
; Faithful port of pret home/start_menu.asm (menus-port Session 4; replaces the
; bespoke engine/menus/start_menu.asm navigation loop).
;
; Structure matches pret exactly: DisplayStartMenu falls into RedisplayStartMenu
; (DrawStartMenu + HandleMenuInput loop with the manual top/bottom wrap), the
; watched-key exit saves wBattleAndStartSavedMenuItem and dispatches to the
; StartMenu_* handlers (engine/menus/start_sub_menus.asm), and EXIT falls
; through to CloseStartMenu. The StartMenu_* handlers `jmp RedisplayStartMenu`
; back, all at the same stack depth (pret's jp chains), so the single
; pushad/popad pair at DisplayStartMenu entry / CloseStartMenu exit balances.
;
; Port-model notes (all rendering goes through DrawStartMenu's canvas→window
; bridge; see draw_start_menu.asm):
;  * vFont is time-shared with player/NPC walk tiles in the overworld, so the
;    font is swapped in at open and the walk tiles restored at close (the GB
;    keeps both resident; this is the port's tile-pattern management, mirroring
;    pret's LoadTextBoxTilePatterns/CloseTextDisplay reloads).
;  * SaveScreenTilesToBuffer2 IS called, faithfully (it is a pure wTileMap →
;    wTileMapBackup2 WRAM copy — movie/title.asm — with no compositor coupling).
;    Only the *restore* half diverges: DEVIATION(window-compositor) — while a
;    sub-menu is open the port drops the START window rather than leaving the box
;    tiles on screen beneath it, so the sub-menus replace pret's
;    LoadScreenTilesFromBuffer2 with a window drop + RedisplayStartMenu redraw
;    (see start_sub_menus.asm). The save is therefore currently write-only here;
;    it is kept because nothing forces it out, and dropping it would silently
;    break the first sub-menu that does want the buffer back.
;  * DEVIATION(port-input-model): pret's `call Joypad` has no port counterpart —
;    Joypad is `missing` (an INT 9h ISR latches H_JOY_* and joypad_update runs
;    inside DelayFrame, so DelayFrame *is* the poll; there is nothing synchronous
;    to call). The release-spin is also widened from pret's hJoyPressed/A to
;    H_JOY_HELD/A|B|START because OverworldLoop reads H_JOY_HELD, not the edge
;    (overworld.asm:904 — H_JOY_PRESSED is always cleared by the time it looks):
;    a still-held START would reopen the menu on the very next iteration.
;  * DEVIATION(port-input-model): pret's `jp CloseTextDisplay` teardown is folded
;    into CloseStartMenu. CloseTextDisplay is translated but NOT LINKED
;    (Makefile HOME_CHECK_SRCS — text_script.asm's link closure is blocked on the
;    same missing Joypad), and the port opens the START menu straight from
;    OverworldLoop rather than from inside DisplayTextID, whose saved-bank stack
;    slot CloseTextDisplay pops. Retire this fold when text_script.asm links.
;
; Input: H_JOY_PRESSED is reliable here (HandleMenuInput runs one DelayFrame →
; one joypad_update per iteration).
;
; Register map (CLAUDE.md): A=AL, BC=BX, DE=DX, HL=ESI, EBP = GB base.
;
; Build (standalone check):
;   nasm -f coff -I include/ -I . -o /dev/null src/home/start_menu.asm
; ---------------------------------------------------------------------------
bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "assets/event_constants.inc"
%include "assets/audio_constants.inc"    ; SFX_START_MENU
%include "events.inc"

global DisplayStartMenu
global RedisplayStartMenu
global RedisplayStartMenu_DoNotDrawStartMenu
global CloseStartMenu

extern DrawStartMenu                 ; engine/menus/draw_start_menu.asm
extern StartMenu_Pokedex             ; engine/menus/start_sub_menus.asm
extern StartMenu_Pokemon
extern StartMenu_Item
extern StartMenu_TrainerInfo
extern StartMenu_SaveReset
extern StartMenu_Option
extern PlaySound                     ; home/audio.asm — sound id in AL
extern PrintSafariZoneSteps          ; engine/overworld/player_state.asm (self-guards on wCurMap)
extern SaveScreenTilesToBuffer2      ; movie/title.asm (pret: home/tilemap.asm)
extern HandleMenuInput               ; home/window.asm
extern EraseMenuCursor
extern PlaceUnfilledArrowMenuCursor
extern PlaceMenuCursor
extern UpdateSprites                 ; engine/overworld/movement.asm
extern DelayFrame                    ; video/frame.asm
extern LoadFontTilePatterns          ; gfx/load_font.asm
extern LoadTextBoxTilePatterns       ; gfx/load_font.asm
extern ReloadWalkingTilePatterns     ; engine/overworld/map_sprites.asm (P3c: was LoadNPCSpriteTiles)
extern LoadPlayerSpriteGraphics      ; engine/overworld/overworld.asm
extern RefreshCollisionTileMap       ; engine/overworld/overworld.asm
extern hide_window                   ; ppu/ppu.asm
extern text_row_stride               ; text/text.asm
extern menu_redraw_cb                ; home/window.asm
%ifdef DEBUG_STARTMENU
extern DumpBackbuffer                ; debug/debug_dump.asm
extern sm_canvas_mirror              ; draw_start_menu.asm
%endif

section .text

; ---------------------------------------------------------------------------
; DisplayStartMenu — pret ref: home/start_menu.asm:DisplayStartMenu.
; In: EBP = GB base. All registers preserved (pushad; popad in CloseStartMenu).
; ---------------------------------------------------------------------------
DisplayStartMenu:
    pushad
    ; ld a, BANK(StartMenu_Pokedex) / call BankswitchCommon — flat: no-op
    ; ld a,[wWalkBikeSurfState] / ld [wWalkBikeSurfStateCopy],a
    mov al, [ebp + W_WALK_BIKE_SURF_STATE]
    mov [ebp + W_WALK_BIKE_SURF_STATE_COPY], al
    mov al, SFX_START_MENU
    call PlaySound                      ; pret: ld a, SFX_START_MENU / call PlaySound

    ; --- port: swap the text font into vFont ($8800) ---
    ; vFont is time-shared with the walk tiles; force the player to a standing
    ; pose first (a frozen walk image index would render as font glyphs), set
    ; BIT_FONT_LOADED (freezes NPC movement), then load the font. Mirrors the
    ; dialog path (map_sprites.asm:CheckNPCInteraction). Restored at close.
    mov al, [ebp + W_SPRITE_PLAYER_FACING_DIR]
    mov [ebp + W_SPRITE_PLAYER_IMAGE_INDEX], al
    mov byte [ebp + W_SPRITE_PLAYER_ANIM_FRAME], 0
    mov byte [ebp + W_SPRITE_PLAYER_INTRA_ANIM], 0
    or byte [ebp + W_FONT_LOADED], (1 << BIT_FONT_LOADED)
    call LoadFontTilePatterns
    ; fall through

; ---------------------------------------------------------------------------
; RedisplayStartMenu — pret ref: home/start_menu.asm:RedisplayStartMenu.
; ---------------------------------------------------------------------------
RedisplayStartMenu:
    ; Port model: W_TILEMAP doubles as the collision/"tile in front of sprite"
    ; mirror (RefreshCollisionTileMap) and as the menu staging canvas. Restore
    ; the map mirror before redrawing the box so UpdateSprites' text-box tile
    ; check (CheckSpriteAvailability) sees map + START box only — the analog of
    ; pret's screen-buffer restore before DrawStartMenu redraws over it.
    call RefreshCollisionTileMap
    call DrawStartMenu                  ; pret: farcall DrawStartMenu
RedisplayStartMenu_DoNotDrawStartMenu:
    call PrintSafariZoneSteps           ; pret: farcall PrintSafariZoneSteps
    call UpdateSprites
%ifdef DEBUG_STARTMENU
    ; OW-A.13 repro: seed the hAutoBGTransferEnabled=1 state the bag list /
    ; pokédex loops used to LEAK back to the START menu. Inert now that the
    ; legacy do_bg_transfer is retired (nothing reads the byte); on the old
    ; code the next DelayFrame repainted GB_TILEMAP1 — this menu's window
    ; source — with skewed canvas/map bytes, rendering the box as grass.
    mov byte [ebp + H_AUTO_BG_TRANSFER_EN], 1
    call PlaceMenuCursor                ; show ▶ at the remembered selection
    call sm_canvas_mirror
    call DelayFrame                     ; render one frame with the menu shown
    call DumpBackbuffer                 ; dump FRAME.BIN + exit (never returns)
%endif
.loop:
    call HandleMenuInput
    mov bl, al                          ; ld b,a — pressed keys
    ; check if Up pressed
    test al, PAD_UP                     ; bit B_PAD_UP,a
    jz .checkIfDownPressed
    mov al, [ebp + wCurrentMenuItem]    ; menu selection
    test al, al
    jnz .loop
    mov al, [ebp + wLastMenuItem]
    test al, al
    jnz .loop
    ; tried to go past the top item: wrap around to the bottom
    CheckEvent EVENT_GOT_POKEDEX        ; ZF=0 → have the Pokédex (clobbers AL)
    mov al, 6                           ; max index with the Pokédex (7 items)
    jnz .wrapMenuItemId
    dec al                              ; only 6 menu items without it
.wrapMenuItemId:
    mov [ebp + wCurrentMenuItem], al
    call EraseMenuCursor
    jmp .loop
.checkIfDownPressed:
    test bl, PAD_DOWN                   ; bit B_PAD_DOWN,a
    jz .buttonPressed
    ; tried to go past the bottom item: wrap around to the top
    CheckEvent EVENT_GOT_POKEDEX
    mov al, [ebp + wCurrentMenuItem]
    mov cl, 7                           ; ld c,7 — item count with the Pokédex
    jnz .checkIfPastBottom
    dec cl                              ; only 6 without it
.checkIfPastBottom:
    cmp al, cl
    jne .loop
    ; went past the bottom: wrap to the top
    xor al, al
    mov [ebp + wCurrentMenuItem], al
    call EraseMenuCursor
    jmp .loop
.buttonPressed:                         ; A, B, or Start pressed
    call PlaceUnfilledArrowMenuCursor
    mov al, [ebp + wCurrentMenuItem]
    mov [ebp + wBattleAndStartSavedMenuItem], al   ; save current selection
    mov al, bl
    test al, PAD_B | PAD_START          ; Start or B → close
    jnz CloseStartMenu
    call SaveScreenTilesToBuffer2       ; wTileMap → wTileMapBackup2 (no live flags here)
    CheckEvent EVENT_GOT_POKEDEX
    mov al, [ebp + wCurrentMenuItem]
    jnz .displayMenuItem
    inc al                              ; account for the missing Pokédex item
.displayMenuItem:
    cmp al, 0
    jz StartMenu_Pokedex
    cmp al, 1
    jz StartMenu_Pokemon
    cmp al, 2
    jz StartMenu_Item
    cmp al, 3
    jz StartMenu_TrainerInfo
    cmp al, 4
    jz StartMenu_SaveReset
    cmp al, 5
    jz StartMenu_Option
    ; EXIT falls through to CloseStartMenu

; ---------------------------------------------------------------------------
; CloseStartMenu — pret ref: home/start_menu.asm:CloseStartMenu.
; ---------------------------------------------------------------------------
CloseStartMenu:
    ; DEVIATION(port-input-model): pret spins `call Joypad / bit B_PAD_A,
    ; [hJoyPressed]` until the closing press clears. Joypad is `missing` in the
    ; port — DelayFrame runs joypad_update, so it IS the poll — and OverworldLoop
    ; reads H_JOY_HELD rather than the edge (overworld.asm:904), so B/START must
    ; be waited out too or a still-held START reopens the menu immediately. See
    ; the header.
.closeReleaseLoop:
    call DelayFrame
    test byte [ebp + H_JOY_HELD], PAD_A | PAD_B | PAD_START
    jnz .closeReleaseLoop
    call LoadTextBoxTilePatterns
    ; DEVIATION(port-input-model): pret `jp CloseTextDisplay` — folded here (see
    ; header; CloseTextDisplay is translated but unlinked): drop the menu window
    ; and swap the walk tiles back into vFont.
    call hide_window
    call RefreshCollisionTileMap        ; scrub the box tiles out of the mirror
                                        ; (pret: LoadScreenTilesFromBuffer2 analog)
    and byte [ebp + W_FONT_LOADED], ~(1 << BIT_FONT_LOADED) & 0xFF
    call ReloadWalkingTilePatterns      ; reload NPC walk tiles the menu font overwrote (vFont)
    call LoadPlayerSpriteGraphics
    mov dword [text_row_stride], 20     ; restore the overworld dialog stride
    mov dword [menu_redraw_cb], 0
    popad
    ret
