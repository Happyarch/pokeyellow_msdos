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
;  * pret's SaveScreenTilesToBuffer2 screen save/restore is not needed: the box
;    is a non-destructive window overlay. DEVIATION: while a sub-menu (e.g. the
;    item list) is open the START menu window is dropped rather than left
;    visible beneath it (pret leaves the underlying box tiles on screen);
;    RedisplayStartMenu redraws it on return, exactly as pret does.
;  * pret's `jp CloseTextDisplay` teardown is folded into CloseStartMenu: the
;    port opens the START menu straight from OverworldLoop (not from inside
;    DisplayTextID, whose saved-bank stack slot CloseTextDisplay pops).
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
extern HandleMenuInput               ; home/window.asm
extern EraseMenuCursor
extern PlaceUnfilledArrowMenuCursor
extern PlaceMenuCursor
extern UpdateSprites                 ; engine/overworld/movement.asm
extern DelayFrame                    ; video/frame.asm
extern LoadFontTilePatterns          ; gfx/load_font.asm
extern LoadTextBoxTilePatterns       ; gfx/load_font.asm
extern LoadNPCSpriteTiles            ; engine/overworld/map_sprites.asm
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
    ; TODO-HW: PlaySound SFX_START_MENU — audio HAL (Phase 3)

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
    ; STUB(safari): farcall PrintSafariZoneSteps — Safari Zone not yet ported
    call UpdateSprites
%ifdef DEBUG_STARTMENU
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
    ; pret: call SaveScreenTilesToBuffer2 — not needed (window overlay; see header)
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
    ; pret: call Joypad / ldh a,[hJoyPressed] / bit B_PAD_A,a / jr nz — spin
    ; until the closing press is released. Port edge semantics: DelayFrame runs
    ; one joypad_update; also wait out B/START so OverworldLoop's edge reads
    ; don't refire (port-model; pret's Joypad re-latch differs).
.closeReleaseLoop:
    call DelayFrame
    test byte [ebp + H_JOY_HELD], PAD_A | PAD_B | PAD_START
    jnz .closeReleaseLoop
    call LoadTextBoxTilePatterns
    ; pret: jp CloseTextDisplay — folded here (see header): drop the menu
    ; window and swap the walk tiles back into vFont.
    call hide_window
    call RefreshCollisionTileMap        ; scrub the box tiles out of the mirror
                                        ; (pret: LoadScreenTilesFromBuffer2 analog)
    and byte [ebp + W_FONT_LOADED], ~(1 << BIT_FONT_LOADED) & 0xFF
    call LoadNPCSpriteTiles
    call LoadPlayerSpriteGraphics
    mov dword [text_row_stride], 20     ; restore the overworld dialog stride
    mov dword [menu_redraw_cb], 0
    popad
    ret
