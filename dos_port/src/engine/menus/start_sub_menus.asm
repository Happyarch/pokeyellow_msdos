; start_sub_menus.asm — StartMenu_* dispatch targets (menus-port Sessions 4+5).
; Faithful port of pret engine/menus/start_sub_menus.asm — Session-4 scope is
; StartMenu_Item + ItemMenuLoop (the bag, realigned onto the generic
; DisplayListMenuID / DisplayTextBoxID / swap_items drivers, replacing the
; bespoke bag_menu.asm); Session-5 scope is StartMenu_Pokemon (the party menu
; dispatcher: DisplayPartyMenu → FIELD_MOVE_MON_MENU pop-up → HandleMenuInput
; → CANCEL/SWITCH/STATS/field-move routing) + the SwitchPartyMon family +
; ErasePartyMenuCursors.
;
; The other four StartMenu_* entries are NOT stubs — the header used to list all
; four as "STUB(S6/S7/S8)" long after Session 9 wired them, which is exactly
; backwards: StartMenu_Pokedex calls ShowPokedexMenu, StartMenu_TrainerInfo draws
; the full trainer card (DrawTrainerInfo + DrawBadges), StartMenu_SaveReset calls
; SaveMenu, StartMenu_Option calls DisplayOptionMenu. Read the bodies, not this
; header.
;
; The two refusal MESSAGES (CannotUseItemsHereText / CannotGetOffHereText) were
; also carried as STUB(text) — "link play not ported", "bike riding not ported".
; Neither was ever true of the message: the text engine takes a flat stream, the
; streams flatten straight out of pret's data/text/text_8.asm (Tier-1, via
; tools/generators/gen_menu_strings.py → assets/menu_text.inc), and PrintText links. They
; print now. A guard whose branch is kept but whose message is dropped is not a
; stub, it is a silently wrong screen.
;
; The field-move dispatch is now fully wired. FLY (.canFly) calls the real
; ChooseFlyDestination (home/reload_tiles.asm → the linked Town Map fly-target UI,
; src/engine/items/town_map.asm) and its armed BIT_FLY_WARP is consumed by
; OverworldLoop → HandleFlyWarpOrDungeonWarp (overworld-events Stage 4). CUT
; (.cut) calls UsedCut for real. SURF reaches UseItem, whose ItemUseSurfboard is a
; ret-stub owned by docs/current_plan_items.md, so it lands on pret's own refusal
; path rather than a port no-op.
;
; Field-move pop-up (port model): DisplayTextBoxID(FIELD_MOVE_MON_MENU) draws
; the box on the 40-wide canvas at the UI_FIELD_MOVE_MON_MENU anchor (S2's
; DisplayFieldMoveMonMenu); fm_show_window mirrors the box rect to GB_TILEMAP0
; and appends a window at the anchor's right/bottom placement (the box grows
; up/left with the mon's field moves, exactly pret's geometry, so the window
; rect is derived from the same wFieldMoves/wFieldMovesLeftmostXCoord math).
; The canvas rows the box occupies (canvas bytes >= 360) never alias the
; stride-20 party scratch (bytes 0-359), so the panel needs no save/restore —
; pret's SaveScreenTilesToBuffer1/LoadScreenTilesFromBuffer1 collapse to
; append/drop of the pop-up window descriptor.
;
; USE/TOSS sub-menu rendering: pret draws it with DisplayTextBoxID
; (USE_TOSS_MENU_TEMPLATE) — the S2 canvas dispatcher, which lands the box at
; the UI_*-projected 40-wide W_TILEMAP coords. In the overworld the canvas is
; not the screen, so ut_show_window bridges the box rect to a window
; descriptor over the live map (same mechanism as every other overworld box).
;
; Register map (CLAUDE.md): A=AL, BC=BX, DE=DX, HL=ESI, EBP = GB base.
;
; Build (standalone check):
;   nasm -f coff -I include/ -I . -o /dev/null src/engine/menus/start_sub_menus.asm
; ---------------------------------------------------------------------------
bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_text.inc"                   ; text_far / text_end + TX_* codes
%include "assets/audio_constants.inc"    ; SFX_SWAP

%define UI_LAYOUT_EQUATES_ONLY 1
%include "assets/ui_layout_menus.inc"

; The two refusal MESSAGES are Tier-1 data (tools/generators/gen_menu_strings.py flattens
; pret's data/text/text_8.asm); their text_far WRAPPERS are Tier-2 code, at the
; foot of this file under pret's own label names.
%include "assets/menu_text.inc"

global StartMenu_Pokedex
global StartMenu_Pokemon
global StartMenu_Item
global StartMenu_TrainerInfo
global StartMenu_SaveReset
global StartMenu_Option
global ItemMenuLoop
global ErasePartyMenuCursors
global SwitchPartyMon
global SwitchPartyMon_InitVarOrSwapData
global DrawTrainerInfo               ; pret DrawTrainerInfo family lives here (its mirror)
global trainer_card_present          ; port-only window/mirror bridge for the card
global trainer_card_teardown

extern RedisplayStartMenu            ; home/start_menu.asm
extern CloseStartMenu
extern DisplayPartyMenu              ; home/pokemon.asm (S5)
extern GoBackToPartyMenu
extern RedrawPartyMenu_              ; engine/menus/party_menu.asm
extern GBPalWhiteOutWithDelay3       ; src/home/palettes.asm
extern RestoreScreenTilesAndReloadTilePatterns
extern LoadGBPal
extern LoadTilesetTilePatternData    ; engine/overworld/overworld.asm — map tileset reload
extern g_bg_whiteout                 ; ppu/ppu.asm
extern g_obj_over_window             ; ppu/ppu.asm — OBJ-over-window z-order (party icons)
extern AddNTimes                     ; home/array.asm — ESI += BX × AL
extern SkipFixedLengthTextEntries    ; home/array.asm — ESI += NAME_LENGTH × AL
extern CopyData                      ; home/copy.asm — ESI→EDX, BX bytes
extern DisplayListMenuID             ; home/list_menu.asm
extern DisplayChooseQuantityMenu
extern list_mirror                   ; home/list_menu.asm — refresh the list window
extern DisplayTextBoxID              ; home/textbox.asm
extern HandleMenuInput               ; home/window.asm
extern PlaceUnfilledArrowMenuCursor
extern GetItemName                   ; home/names.asm — [wNamedObjectIndex] → wNameBuffer
extern CopyToStringBuffer            ; src/home/copy_string.asm — EDX=src → wStringBuffer
extern TossItem                      ; home/item.asm — ESI=inventory; CF=1 not tossed
extern UseItem                       ; home/item.asm — [wCurItem] → wActionResultOrTookBattleTurn
extern IsInArray                     ; home/array2.asm — AL=value, ESI=flat table, EDX=stride; CF=1
extern UsableItems_CloseMenu         ; data/item_data.asm (generated) — USE closes the menu
extern UsableItems_PartyMenu         ; data/item_data.asm (generated) — USE opens the party menu
extern add_window                    ; ppu/ppu.asm
extern g_window_count
extern text_row_stride               ; text/text.asm
extern menu_item_step                ; home/window.asm
extern menu_redraw_cb
extern IsKeyItem                     ; home/item.asm — [wCurItem] → [wIsKeyItem]
extern IsItemHM                      ; home/names.asm — AL=item id → CF
extern SaveMenu                      ; engine/menus/save.asm (S7) — START→SAVE flow
; --- S9 package wirings (Pokédex / Options / Trainer Card) ---
extern RedisplayStartMenu_DoNotDrawStartMenu ; home/start_menu.asm
extern ShowPokedexMenu               ; engine/menus/pokedex.asm (S8, pkg G)
extern DisplayOptionMenu             ; engine/menus/main_menu.asm (S6/S7, pkg D wrapper)
extern DrawBadges                    ; engine/menus/draw_badges.asm (S6, pkg B)
; --- DrawTrainerInfo family (the trainer card, formerly engine/menus/trainer_card.asm) ---
extern DisableLCD                    ; home/lcd.asm
extern EnableLCD
extern CopyVideoData                 ; home/copy2.asm — ESI dest VRAM off, EDX flat src, BL tiles
extern PlaceString                   ; text/text.asm — ESI=dest, EAX=flat src
extern PrintNumber                   ; home/print_num.asm — ESI=dest, EDX=src, BH=flags|bytes, BL=digits
extern PrintBCDNumber                ; home/print_bcd.asm — ESI=dest, EDX=BCD src, BL=flags|len
extern LoadBadgeTiles                ; engine/menus/draw_badges.asm (pkg B) — faces/badges → vChars2 $20
extern LoadMonPicToVRAM              ; gfx/pics.asm — decode staged pic → [EDX] VRAM
extern PlayerPicFront                ; data/trainer_pics.asm — Red's compressed front .pic (red.pic)
extern g_tilecache_dirty             ; ppu/ppu.asm — set on any VRAM tile-data write
extern set_single_window             ; ppu/ppu.asm
extern Delay3                        ; src/home/palettes.asm
extern UpdateSprites                 ; engine/overworld/movement.asm
extern ClearScreen                   ; home/copy2.asm
extern LoadTextBoxTilePatterns       ; gfx/load_font.asm
extern LoadFontTilePatterns          ; gfx/load_font.asm
extern WaitForTextScrollButtonPress  ; engine/battle/battle_menu.asm — ▼-wait + A/B
extern GBPalWhiteOut                 ; src/home/palettes.asm
extern GBPalNormal                   ; src/home/palettes.asm
extern RunPaletteCommand             ; src/home/palettes.asm
extern ReloadMapData                 ; home/reload_tiles.asm
extern DrawStartMenu                 ; engine/menus/draw_start_menu.asm
extern ClearSprites                  ; gfx/sprites.asm — zero shadow OAM
extern StatusScreen                  ; engine/pokemon/status_screen.asm — page 1
extern StatusScreen2                 ; engine/pokemon/status_screen.asm — page 2
extern CommitMonPartySpriteOAM       ; engine/gfx/mon_icons.asm — publish shadow OAM → compositor
extern PartyMenuMirror               ; engine/menus/party_menu.asm — canvas → panel window
extern WaitForSoundToFinish          ; home/audio.asm (pret: home/delay.asm)
extern PlaySound                     ; home/audio.asm — sound id in AL
extern PrintText                     ; home/window.asm — ESI = flat text stream
; --- field-move dispatch (row 9 part 3) ---
extern GetPartyMonName               ; home/pokemon.asm — AL = index, ESI = nick list
extern CheckIfInOutsideMap           ; src/home/overworld.asm — ZF=1 if outside
extern IsSurfingAllowed              ; engine/overworld/field_move_messages.asm (now LINKED)
extern PrintStrengthText              ; engine/overworld/field_move_messages.asm (now LINKED)
extern UsedCut                        ; engine/overworld/cut.asm — predef UsedCut (.cut)
extern Func_1510                     ; home/pikachu.asm
extern ChooseFlyDestination          ; home/reload_tiles.asm — Town Map Fly UI wrapper
extern DelayFrames                   ; video/frame.asm — BL = frame count
extern Divide                        ; home/math.asm — hDividend/hDivisor, BH = byte count
extern text_msgbox                   ; home/text.asm — active message-box projection
extern msgbox_dialog                 ; home/text.asm — the standard bottom dialog box
extern Init                          ; home/init.asm — soft reset (the link RESET item)
extern RunDefaultPaletteCommand      ; src/home/palettes.asm — the REAL body
                                     ; (SET_PAL_DEFAULT → RunPaletteCommand, now its
                                     ; immediate neighbour there). This file used to
                                     ; define a private ret-only copy that shadowed
                                     ; it; see the header.

; --- USE/TOSS box geometry (frozen layout; pret GB(13,10) 7x5, text (15,11)) ---
; ; PROJ menus: GB(13,10) 7x5 --(anchor=right/top, X+20, Y+0)--> wx=271 wy=80
;   clip=56 max_y=120 [UI_USE_TOSS_MENU_TEMPLATE_*]
UT_COL   equ UI_USE_TOSS_MENU_TEMPLATE_COL
UT_ROW   equ UI_USE_TOSS_MENU_TEMPLATE_ROW
UT_W     equ UI_USE_TOSS_MENU_TEMPLATE_X2 - UI_USE_TOSS_MENU_TEMPLATE_COL + 1
UT_H     equ UI_USE_TOSS_MENU_TEMPLATE_Y2 - UI_USE_TOSS_MENU_TEMPLATE_ROW + 1
UT_SROW  equ 21                      ; GB_TILEMAP0 mirror rows 21-25 (list 0-10,
                                     ; qty 12-14, yes/no 16-20 — all distinct)

TILE_SPC equ 0x7F                    ; blank space tile (charmap)
SET_PAL_TRAINER_CARD equ 0x0D        ; constants/palette_constants.asm (palette stub arg)

; --- trainer-card (DrawTrainerInfo family) constants ---
; VRAM region: pret vChars1 is not in gb_memmap; it is $8800.
TC_VCHARS1 equ 0x8800
; trainer-card union scratch (pret ram/wram.asm; sym-verified $CD3D block;
; the same union DrawBadges' wBadgeNumberTile/wBadgeNameTile reuse — both routines
; write every byte before reading it, no cross-dependency)
wTrainerInfoTextBoxWidthPlus1     equ 0xCD3D
wTrainerInfoTextBoxWidth          equ 0xCD3E
wTrainerInfoTextBoxNextRowOffset  equ 0xCD3F
TCSCR_W  equ 20                      ; stride-20 scratch (pret SCREEN_WIDTH)
%define TC_HL(X,Y)  (W_TILEMAP + (Y) * TCSCR_W + (X))
; number-print flag bytes (constants/gfx_constants.asm bit positions)
NUM_MONEY_SIGN     equ 1 << BIT_MONEY_SIGN
NUM_LEFT_ALIGN     equ 1 << BIT_LEFT_ALIGN
NUM_LEADING_ZERO   equ 1 << BIT_LEADING_ZEROES
; PROJ menus: front pic → VRAM $9000 (GB_VCHARS2), the verified battle/dex front-pic
; dest; PIC_STAGE staging matches gfx/pics.asm.
PIC_STAGE_GB equ 0xA4A0              ; GB scratch for the compressed input stream (pics.asm)
PLAYER_PIC_LEN equ 255              ; red.pic byte length (gfx/player/red.pic)

; trainer-card tile graphics (Tier-1, tools/generators/gen_trainer_card_tiles.py;
; the .inc carries no section directive, so wrap it — data must land in a loaded
; section, see link.ld)
section .data
align 4
%include "assets/trainer_card_tiles.inc"
section .text

; --- field-move dispatch constants (not yet in the shared headers; the %ifndef +
; pret-source-comment pattern used by field_move_messages.asm) ---
%ifndef BIT_BOULDERBADGE
BIT_BOULDERBADGE equ 0               ; wObtainedBadges bits — constants/ram_constants.asm
BIT_CASCADEBADGE equ 1
BIT_THUNDERBADGE equ 2
BIT_RAINBOWBADGE equ 3
BIT_SOULBADGE    equ 4
%endif
%ifndef BIT_SURF_ALLOWED
BIT_SURF_ALLOWED equ 1               ; wStatusFlags1 bit (constants/ram_constants.asm)
%endif
%ifndef SURFBOARD
SURFBOARD    equ 0x07                ; constants/item_constants.asm
%endif
%ifndef ESCAPE_ROPE
ESCAPE_ROPE  equ 0x1D                ; constants/item_constants.asm
%endif
%ifndef wd472
wd472        equ 0xD472              ; ram/wram.asm:wd472 — surf state (1 = board, 2 = Pikachu)
%endif
%ifndef BIT_UNKNOWN_4_1
BIT_UNKNOWN_4_1 equ 1                ; wStatusFlags4 bit (constants/ram_constants.asm; the
%endif                               ; port also carries it in m8_2_pending_symbols.inc)

section .text

; ---------------------------------------------------------------------------
; StartMenu_Pokedex — pret ref: start_sub_menus.asm:StartMenu_Pokedex.
; predef ShowPokedexMenu (S8, pkg G) — the pokédex screen tail-jumps ReloadMapData
; itself, so control returns here for the palette/redraw tail.
; ---------------------------------------------------------------------------
StartMenu_Pokedex:
    call ShowPokedexMenu                ; predef ShowPokedexMenu
    ; call LoadScreenTilesFromBuffer2 — port(window model): the pokédex already
    ; restored the map (its tail ReloadMapData); nothing to restore.
    call Delay3
    call LoadGBPal
    call UpdateSprites
    ; port: drop the pokédex full-takeover window + whiteout and reset the scratch
    ; stride (ShowPokedexMenu set text_row_stride=40 and never reset it) so
    ; RedisplayStartMenu / the overworld draw at stride 20 again.
    mov dword [g_window_count], 0
    mov dword [g_bg_whiteout], 0
    mov dword [g_obj_over_window], 0    ; back to the port's window-last order
    mov dword [text_row_stride], 20
    jmp RedisplayStartMenu

; ---------------------------------------------------------------------------
; StartMenu_Pokemon — pret ref: start_sub_menus.asm:StartMenu_Pokemon.
; DisplayPartyMenu → on chosen mon, the FIELD_MOVE_MON_MENU pop-up →
; HandleMenuInput → dispatch CANCEL / SWITCH / STATS / field move.
; ---------------------------------------------------------------------------
StartMenu_Pokemon:
    mov al, [ebp + wPartyCount]
    test al, al                         ; and a
    jz RedisplayStartMenu               ; jp z — empty party → straight back
    xor al, al
    mov [ebp + wMenuItemToSwap], al
    mov [ebp + wPartyMenuTypeOrMessageID], al
    mov [ebp + W_UPDATE_SPRITES_ENABLED], al
    call DisplayPartyMenu
    jmp .checkIfPokemonChosen           ; jr
.loop:
    xor al, al
    mov [ebp + wMenuItemToSwap], al
    mov [ebp + wPartyMenuTypeOrMessageID], al
    call GoBackToPartyMenu
.checkIfPokemonChosen:
    jnc .chosePokemon                   ; jr nc
.exitMenu:
    call GBPalWhiteOutWithDelay3
    call RestoreScreenTilesAndReloadTilePatterns
    ; port(window model) exit restores, BEFORE LoadGBPal un-whites the palette:
    ; pret restores the screen content during the whiteout (Restore…'s
    ; LoadScreenTilesFromBuffer2) — the window-model analog is dropping the
    ; party windows + whiteout field here, or the stale panel renders for a
    ; few frames with the box-tile patterns Restore… just loaded over the
    ; HP-bar set ($62-$7F). The icons need no restore of their own: they are OBJ
    ; in vSprites now (engine/gfx/mon_icons.asm), and the map sprite tiles they
    ; overwrote are exactly what Restore…'s ReloadMapSpriteTilePatterns brings back
    ; — same as pret. LoadTilesetTilePatternData below is for the BG tileset.
    mov dword [g_window_count], 0       ; drop the party panel/message windows
    mov dword [g_bg_whiteout], 0
    mov dword [g_obj_over_window], 0    ; back to the port's window-last order
    call LoadTilesetTilePatternData
    call LoadGBPal
    jmp RedisplayStartMenu              ; jp RedisplayStartMenu
.chosePokemon:
    ; call SaveScreenTilesToBuffer1 — port(window model): the pop-up is its
    ; own window over an untouched panel scratch; nothing to save (see header)
    mov byte [ebp + wTextBoxID], FIELD_MOVE_MON_MENU
    call DisplayTextBoxID               ; display pokemon menu options (canvas)
    call fm_show_window                 ; port: bridge the canvas box → window
    ; walk wFieldMoves to grow the menu vars: b = max item, c = top Y
    mov esi, wFieldMoves                ; ld hl,wFieldMoves
    mov bh, 2                           ; lb bc, 2, 12
    mov bl, 12
    mov dl, 5                           ; ld e,5
.adjustMenuVariablesLoop:
    dec dl                              ; dec e
    jz .storeMenuVariables
    mov al, [ebp + esi]                 ; ld a,[hli]
    inc esi
    test al, al                         ; end of field moves?
    jz .storeMenuVariables
    inc bh                              ; inc b
    sub bl, 2                           ; dec c / dec c
    jmp .adjustMenuVariablesLoop
.storeMenuVariables:
    ; PROJ menus: the pop-up lives on the 40-wide canvas at the
    ; UI_FIELD_MOVE_MON_MENU anchor — pret's cursor coords (Y=c,
    ; X=hFieldMoveMonMenuTopMenuItemX) shift by the same FM_ROW/COL deltas
    ; the box was drawn with (S2 DisplayFieldMoveMonMenu convention: the
    ; hFieldMove… X stays GB-space; consumers project at placement)
    mov al, bl
    add al, FM_ROW_SHIFT
    mov [ebp + wTopMenuItemY], al       ; ld [hli],a — top menu item Y
    mov al, [ebp + hFieldMoveMonMenuTopMenuItemX]
    add al, FM_COL_SHIFT
    mov [ebp + wTopMenuItemX], al       ; ld [hli],a — top menu item X
    xor al, al
    mov [ebp + wCurrentMenuItem], al    ; ld [hli],a
    mov al, bh
    mov [ebp + wMaxMenuItem], al        ; ld [hli],a
    mov byte [ebp + wMenuWatchedKeys], PAD_A | PAD_B
    mov byte [ebp + wLastMenuItem], 0   ; xor a / ld [hl],a
    ; port: cursor moves on the canvas while the pop-up is up
    mov dword [text_row_stride], SCREEN_TILES_W
    mov dword [menu_item_step], 2 * SCREEN_TILES_W
    mov dword [menu_redraw_cb], fm_mirror
    call HandleMenuInput
    mov dword [menu_redraw_cb], 0
    mov dword [text_row_stride], 20     ; back to the stride-20 scratch
    mov dword [menu_item_step], 2 * 20
    mov bl, al                          ; keep the pressed keys
    ; call LoadScreenTilesFromBuffer1 — port: drop the pop-up window instead
    call fm_drop_window
    test bl, PAD_B                      ; bit B_PAD_B,a
    jnz .loop                           ; jp nz
    ; if the B button wasn't pressed
    mov ah, [ebp + wMaxMenuItem]        ; ld b,a
    mov al, [ebp + wCurrentMenuItem]    ; menu selection
    cmp al, ah                          ; cp b
    jz .exitMenu                        ; jp z — the player chose Cancel
    dec ah
    cmp al, ah
    jz .choseSwitch                     ; jr z
    dec ah
    cmp al, ah
    jz .choseStats                      ; jp z
.choseOutOfBattleMove:
    ; AL = wCurrentMenuItem (the compare chain above left it there) = the index of
    ; the chosen move within wFieldMoves. pret: ld c,a / ld b,0 / ld hl,wFieldMoves /
    ; add hl,bc  →  ESI = &wFieldMoves[AL].
    movzx esi, al
    add esi, wFieldMoves
    push esi                            ; push hl
    mov al, [ebp + wWhichPokemon]
    mov esi, wPartyMonNicks             ; ld hl, wPartyMonNicks
    call GetPartyMonName                ; → wStringBuffer, for the messages below
    pop esi                             ; pop hl
    ; pret: ld a,[hl] / dec a / add a / ld c,a / ld b,0 / add hl,.outOfBattleMovePointers
    ; / ld a,[hli] / ld h,[hl] / ld l,a  — a 16-bit pointer table. The port's is 32-bit,
    ; so the scale is 4, not pret's 2; everything else is the same indexed indirect jump.
    movzx ecx, byte [ebp + esi]         ; the field-move id (1-based)
    dec ecx
    mov al, [ebp + W_OBTAINED_BADGES]   ; ld a,[wObtainedBadges] — every leaf reads AL
    jmp [.outOfBattleMovePointers + ecx * 4]   ; jp hl

.outOfBattleMovePointers:
    dd .cut
    dd .fly
    dd .surf
    dd .surf
    dd .strength
    dd .flash
    dd .dig
    dd .teleport
    dd .softboiled

.fly:
    test al, (1 << BIT_THUNDERBADGE)    ; bit BIT_THUNDERBADGE, a
    jz .newBadgeRequired
    call CheckIfInOutsideMap            ; ZF=1 → outside
    jz .canFly
    mov al, [ebp + wWhichPokemon]
    mov esi, wPartyMonNicks
    call GetPartyMonName
    mov esi, .cannotFlyHereText
    mov dword [text_msgbox], msgbox_dialog
    call PrintText
    jmp .loop
.canFly:
    ; pret's real tail. ChooseFlyDestination (home/reload_tiles.asm) shows the Town
    ; Map fly-target UI (LoadTownMap_Fly), arming wDestinationMap + BIT_FLY_WARP on an
    ; A-press or leaving them clear on a B-cancel. The whole selector is linked
    ; (src/engine/items/town_map.asm); OverworldLoop's idle branch consumes
    ; BIT_FLY_WARP via HandleFlyWarpOrDungeonWarp on the next iteration.
    call ChooseFlyDestination           ; call ChooseFlyDestination
    mov al, [ebp + W_STATUS_FLAGS_6]    ; ld a, [wStatusFlags6]
    test al, (1 << BIT_FLY_WARP)        ; bit BIT_FLY_WARP, a
    jnz .flyChosen                      ; jr nz, .asm_5d4c
    ; B-cancel: no destination chosen. Reload the font tiles the Town Map clobbered
    ; (vChars1 shares them) and re-open the party menu.
    call LoadFontTilePatterns           ; call LoadFontTilePatterns
    or byte [ebp + W_STATUS_FLAGS_4], (1 << BIT_UNKNOWN_4_1)  ; set BIT_UNKNOWN_4_1,[wStatusFlags4]
    jmp StartMenu_Pokemon               ; jp StartMenu_Pokemon
.flyChosen:                             ; pret .asm_5d4c — destination armed
    call Func_1510                      ; call Func_1510
    jmp .goBackToMap                    ; jp .goBackToMap

.cut:
    test al, (1 << BIT_CASCADEBADGE)
    jz .newBadgeRequired
    call UsedCut                        ; predef UsedCut
    mov al, [ebp + wActionResultOrTookBattleTurn]
    test al, al
    ; jp z, .loop — nothing to cut. UsedCut's .nothingToCut path prints its refusal
    ; and returns WITHOUT running any of its teardown (that all sits below .canCut),
    ; so the party screen is still up and .loop simply resumes it. Only the success
    ; path below has left the menu for the map.
    jz .loop
    ; DEVIATION{class=projection; pret=engine/menus/start_sub_menus.asm:StartMenu_Pokemon; behavior=tail-jump to CloseStartMenu instead of pret's CloseTextDisplay; evidence=CloseTextDisplay is linked but ends in the pop of the bank DisplayTextID pushed, and the port enters the START menu from OverworldLoop under its own pushad rather than from inside DisplayTextID, so that pop would unbalance the frame (see home/start_menu.asm header); lifetime=permanent start-menu entry-model boundary}
    ; Same fold, and for the same reason, as .goBackToMap's tail below —
    ; NOT the stale "CloseTextDisplay is check-only" one: that routine links now
    ; (Stage 2, home/text_script.asm). The stack model is why, and it is permanent.
    ; UsedCut has already redrawn the map and run UpdateSprites (its RedrawMapView
    ; tail), which is the part of CloseTextDisplay the fold drops.
    jmp CloseStartMenu                  ; jp CloseTextDisplay

.surf:
    test al, (1 << BIT_SOULBADGE)
    jz .newBadgeRequired
    call IsSurfingAllowed               ; farcall IsSurfingAllowed
    ; pret: bit BIT_SURF_ALLOWED,[hl] / res BIT_SURF_ALLOWED,[hl] / jp z,.loop —
    ; read the bit, then clear it unconditionally, then branch on the value READ.
    mov al, [ebp + W_STATUS_FLAGS_1]
    and byte [ebp + W_STATUS_FLAGS_1], ~(1 << BIT_SURF_ALLOWED) & 0xFF  ; res
    test al, (1 << BIT_SURF_ALLOWED)    ; bit (on the pre-res copy)
    jz .loop
    mov al, [ebp + wCurPartySpecies]
    cmp al, STARTER_PIKACHU
    jz .surfingPikachu
    mov al, 1
    jmp .continue
.surfingPikachu:
    mov al, 2                           ; Pikachu rides on the surfboard, not in it
.continue:
    mov [ebp + wd472], al
    mov al, SURFBOARD
    mov [ebp + wCurItem], al
    mov [ebp + wPseudoItemID], al
    call UseItem                        ; ItemUseSurfboard — a ret-stub today
                                        ; (item_use_stubs.asm), so this returns
                                        ; wActionResultOrTookBattleTurn = 0 and falls
                                        ; to .reloadNormalSprite: pret's own "the
                                        ; surfboard was refused" path. Correct shape,
                                        ; no surfing until that stub is retired.
    mov al, [ebp + wActionResultOrTookBattleTurn]
    test al, al
    jz .reloadNormalSprite
    call GBPalWhiteOutWithDelay3
    jmp .goBackToMap
.reloadNormalSprite:
    mov byte [ebp + wd472], 0           ; xor a / ld [wd472],a
    jmp .loop

.strength:
    test al, (1 << BIT_RAINBOWBADGE)
    jz .newBadgeRequired
    call PrintStrengthText              ; predef PrintStrengthText
    call GBPalWhiteOutWithDelay3
    jmp .goBackToMap

.flash:
    test al, (1 << BIT_BOULDERBADGE)
    jz .newBadgeRequired
    mov byte [ebp + wMapPalOffset], 0   ; xor a / ld [wMapPalOffset],a
    mov esi, .flashLightsAreaText
    mov dword [text_msgbox], msgbox_dialog
    call PrintText
    call GBPalWhiteOutWithDelay3
    jmp .goBackToMap
.flashLightsAreaText:
    text_far _FlashLightsAreaText
    text_end

.dig:
    ; no badge gate — DIG is an item effect (ESCAPE_ROPE), and ItemUseEscapeRope is
    ; translated and linked, so this one runs for real.
    mov al, ESCAPE_ROPE
    mov [ebp + wCurItem], al
    mov [ebp + wPseudoItemID], al
    call UseItem
    mov al, [ebp + wActionResultOrTookBattleTurn]
    test al, al
    jz .loop                            ; jp z, .loop — refused (e.g. can't leave here)
    call GBPalWhiteOutWithDelay3
    jmp .goBackToMap

.teleport:
    call CheckIfInOutsideMap
    jz .canTeleport
    mov al, [ebp + wWhichPokemon]
    mov esi, wPartyMonNicks
    call GetPartyMonName
    mov esi, .cannotUseTeleportNowText
    mov dword [text_msgbox], msgbox_dialog
    call PrintText
    jmp .loop
.canTeleport:
    mov esi, .warpToLastPokemonCenterText
    mov dword [text_msgbox], msgbox_dialog
    call PrintText
    ; set BIT_FLY_WARP / set BIT_ESCAPE_WARP, [wStatusFlags6]
    or byte [ebp + W_STATUS_FLAGS_6], (1 << BIT_FLY_WARP) | (1 << BIT_ESCAPE_WARP)
    call Func_1510
    ; set BIT_UNKNOWN_4_1 / res BIT_NO_BATTLES, [wStatusFlags4]
    or byte [ebp + W_STATUS_FLAGS_4], (1 << BIT_UNKNOWN_4_1)
    and byte [ebp + W_STATUS_FLAGS_4], ~(1 << BIT_NO_BATTLES) & 0xFF
    mov bl, 60                          ; ld c, 60
    call DelayFrames
    call GBPalWhiteOutWithDelay3
    jmp .goBackToMap
.warpToLastPokemonCenterText:
    text_far _WarpToLastPokemonCenterText
    text_end
.cannotUseTeleportNowText:
    text_far _CannotUseTeleportNowText
    text_end
.cannotFlyHereText:
    text_far _CannotFlyHereText
    text_end

.softboiled:
    ; no badge gate. Heal the target for maxHP/5, but only if the USER's current HP
    ; is MORE than maxHP/5 (pret compares quotient - HP and refuses on no-borrow).
    mov esi, wPartyMon1MaxHP
    mov al, [ebp + wWhichPokemon]
    mov bx, PARTYMON_STRUCT_LENGTH
    call AddNTimes                      ; ESI = &partyMon[which].MaxHP
    mov al, [ebp + esi]                 ; ld a,[hli] — MaxHP HIGH byte (big-endian)
    mov [ebp + hDividend], al
    mov al, [ebp + esi + 1]             ; ld a,[hl]  — MaxHP low byte
    mov [ebp + hDividend + 1], al
    mov byte [ebp + hDivisor], 5
    mov bh, 2                           ; ld b, 2 — dividend byte count
    ; pret is at MaxHP+1 here (the hli), then `ld bc, MON_HP - MON_MAXHP / add hl,bc`
    ; — a NEGATIVE displacement (MON_HP sits below MON_MAXHP in the struct), landing
    ; on the HP LOW byte. Folded into one lea; it touches no flags.
    lea esi, [esi + 1 + MON_HP - MON_MAXHP]
    call Divide                         ; hQuotient = MaxHP / 5
    mov bl, [ebp + esi]                 ; ld a,[hld] / ld b,a — current HP low
    dec esi                             ; hld → HP high
    mov al, [ebp + hQuotient + 3]       ; quotient low
    sub al, bl                          ; sub b        → CF = borrow (mov/dec above
                                        ;                do not disturb it afterwards)
    mov bl, [ebp + esi]                 ; ld b,[hl] — current HP high
    mov al, [ebp + hQuotient + 2]       ; quotient high
    sbb al, bl                          ; sbc b
    jnc .notHealthyEnough               ; jp nc — quotient >= HP: too weak to give
    mov al, [ebp + wPartyAndBillsPCSavedMenuItem]
    push eax                            ; push af — UseItem's party menu clobbers it
    mov al, POTION
    mov [ebp + wCurItem], al
    mov [ebp + wPseudoItemID], al
    call UseItem                        ; ItemUseMedicine — translated and linked
    pop eax                             ; pop af
    mov [ebp + wPartyAndBillsPCSavedMenuItem], al
    jmp .loop
.notHealthyEnough:                      ; current HP is less than 1/5 of max HP
    mov esi, .notHealthyEnoughText
    mov dword [text_msgbox], msgbox_dialog
    call PrintText
    jmp .loop
.notHealthyEnoughText:
    text_far _NotHealthyEnoughText
    text_end

.goBackToMap:
    call RestoreScreenTilesAndReloadTilePatterns
    ; DEVIATION{class=projection; pret=engine/menus/start_sub_menus.asm:StartMenu_Pokemon; behavior=tear down party-menu windows and whiteout before returning field-move flows to the map; evidence=pret CloseTextDisplay redraw path plus live port blank-screen reproduction when compositor state remains; lifetime=permanent window-compositor boundary}
    ; .goBackToMap is a PARTY-MENU exit — every path
    ; that reaches it came through DisplayPartyMenu, which raises g_bg_whiteout and
    ; owns the window list (party_menu.asm:417). pret has no such state: its party
    ; screen is just tiles, and CloseTextDisplay's LoadCurrentMapView redraws over
    ; them. The port composites the map only when g_bg_whiteout is clear, so without
    ; this teardown the map never draws at all and STRENGTH/FLASH/DIG/TELEPORT/SURF
    ; return to a BLANK screen (observed live, 2026-07-13). Identical to .exitMenu's
    ; teardown above — same exit, different destination — incl. the tileset reload
    ; (the party menu's HP-bar patterns sit in the BG tileset slots).
    mov dword [g_window_count], 0       ; drop the party panel/message windows
    mov dword [g_bg_whiteout], 0
    mov dword [g_obj_over_window], 0    ; back to the port's window-last order
    call LoadTilesetTilePatternData
    ; The palette is WHITE here: every caller ran GBPalWhiteOutWithDelay3, which
    ; zeroes BGP/OBP0/OBP1. pret un-whites inside CloseTextDisplay (`call LoadGBPal`,
    ; right after the hWY/DelayFrame); the CloseStartMenu fold below was written for
    ; the ORDINARY menu close — a path that never whites out — so it has none, and
    ; neither does RestoreScreenTilesAndReloadTilePatterns (whose header comment
    ; claims it "reasserts the default palette": false, its RunDefaultPaletteCommand
    ; call is commented out — filed as M-29).
    call LoadGBPal                      ; pret: CloseTextDisplay's LoadGBPal
    ; DEVIATION{class=projection; pret=engine/menus/start_sub_menus.asm:StartMenu_Pokemon; behavior=tail-jump to CloseStartMenu instead of pret's CloseTextDisplay; evidence=CloseTextDisplay is linked but ends in the pop of the bank DisplayTextID pushed at entry, and the port enters the START menu from OverworldLoop under its own pushad rather than from inside DisplayTextID, so that pop would unbalance the frame (see home/start_menu.asm header); lifetime=permanent start-menu entry-model boundary}
    ; pret is `jp CloseTextDisplay`. This fold was ORIGINALLY justified by
    ; "text_script.asm is check-only" with lifetime "until its closure links". That
    ; closure LANDED (overworld-events Stage 2) and the justification did not survive
    ; it — but the fold must stay, for a reason that is permanent rather than
    ; temporary. pret runs its whole START menu inside DisplayTextID's frame (that
    ; routine's `dict TEXT_START_MENU, DisplayStartMenu` — home/text_script.asm:1),
    ; which pushed hLoadedROMBank; CloseTextDisplay's closing `pop af` is that push's
    ; partner. The port opens the menu straight from OverworldLoop under a pushad/popad
    ; pair (home/start_menu.asm:11), so there is no such slot: jumping to
    ; CloseTextDisplay here would eat a pushad register and return through it.
    ; CloseStartMenu is the port's sanctioned fold and is what .useItem_closeMenu and
    ; StartMenu_SaveReset already tail-jump. Two things pret's CloseTextDisplay does
    ; that the fold does NOT, both harmless here but worth naming: it reloads the map
    ; view (LoadCurrentMapView — the port's view pointer is untouched by this menu),
    ; and it SKIPS LoadPlayerSpriteGraphics when BIT_FLY_WARP is set (TELEPORT sets
    ; it), where the fold reloads unconditionally.
    jmp CloseStartMenu

.newBadgeRequired:
    mov esi, .newBadgeRequiredText
    mov dword [text_msgbox], msgbox_dialog
    call PrintText
    jmp .loop
.newBadgeRequiredText:
    text_far _NewBadgeRequiredText
    text_end
.choseSwitch:
    mov al, [ebp + wPartyCount]
    cmp al, 2                           ; more than one pokemon in the party?
    jc StartMenu_Pokemon                ; jp c — if not, no switching
    call SwitchPartyMon_InitVarOrSwapData ; init [wMenuItemToSwap]
    mov byte [ebp + wPartyMenuTypeOrMessageID], SWAP_MONS_PARTY_MENU
    call GoBackToPartyMenu
    jmp .checkIfPokemonChosen           ; jp
.choseStats:
    ; pret start_sub_menus.asm:.choseStats — ClearSprites / wMonDataLocation=0 /
    ; predef StatusScreen / predef StatusScreen2 / ReloadMapData / jp
    ; StartMenu_Pokemon. wWhichPokemon was set by DisplayPartyMenu when the mon
    ; was chosen, so StatusScreen loads the right party slot.
    call ClearSprites                       ; call ClearSprites
    ; PORT teardown: StatusScreen mirrors init_battle — it zeroes the overworld
    ; camera (W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR / IO_SCX / IO_SCY) to drive its
    ; flat 40-wide canvas, and leaves text_row_stride at 40. pret HW StatusScreen
    ; touches none of these. ReloadMapData re-reads the view-ptr (it does not
    ; recompute it from the player's position), so without a restore the overworld
    ; behind the menus would snap to the map's top-left after STATS closes. Save
    ; the camera + restore stride here (the StartMenu_TrainerInfo precedent).
    mov ax, [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR]
    mov [choseStats_saved_view], ax
    mov al, [ebp + IO_SCX]
    mov [choseStats_saved_scx], al
    mov al, [ebp + IO_SCY]
    mov [choseStats_saved_scy], al
    ; StatusScreen zeroes the SHADOW scroll (H_SCX/H_SCY) so the flat canvas isn't
    ; dragged by the overworld scroll; commit_shadow_regs copies H_SCX/SCY → IO_SCX/SCY
    ; every frame, so save/restore the shadows too or the overworld scroll is lost.
    mov al, [ebp + H_SCX]
    mov [choseStats_saved_hscx], al
    mov al, [ebp + H_SCY]
    mov [choseStats_saved_hscy], al
    xor al, al                              ; xor a ; PLAYER_PARTY_DATA
    mov [ebp + wMonDataLocation], al
    call StatusScreen                       ; predef StatusScreen (page 1)
    call StatusScreen2                      ; predef StatusScreen2 (page 2)
    mov dword [text_row_stride], 20         ; StatusScreen left it 40; party menu is stride-20
    mov ax, [choseStats_saved_view]
    mov [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR], ax
    mov al, [choseStats_saved_scx]
    mov [ebp + IO_SCX], al
    mov al, [choseStats_saved_scy]
    mov [ebp + IO_SCY], al
    mov al, [choseStats_saved_hscx]         ; restore the shadow scroll (see save note above)
    mov [ebp + H_SCX], al
    mov al, [choseStats_saved_hscy]
    mov [ebp + H_SCY], al
    call ReloadMapData                      ; call ReloadMapData
    jmp StartMenu_Pokemon                   ; jp StartMenu_Pokemon

; ---------------------------------------------------------------------------
; StartMenu_TrainerInfo — pret ref: start_sub_menus.asm:StartMenu_TrainerInfo.
; The TRAINER CARD: DrawTrainerInfo (below, pret order) + DrawBadges (pkg B),
; composited full-screen, then WaitForTextScrollButtonPress before restoring the
; overworld + START menu.
; ---------------------------------------------------------------------------
StartMenu_TrainerInfo:
    call GBPalWhiteOut
    call ClearScreen
    call UpdateSprites
    mov al, [ebp + hTileAnimations]
    push eax                            ; push af
    xor al, al
    mov [ebp + hTileAnimations], al
    call DrawTrainerInfo
    call DrawBadges                     ; predef DrawBadges
    ; ld b, SET_PAL_TRAINER_CARD / call RunPaletteCommand — TODO-HW: palette HAL
    mov bh, SET_PAL_TRAINER_CARD
    call RunPaletteCommand
    call GBPalNormal
    call trainer_card_present           ; port: composite the 20x18 card as one window
    call WaitForTextScrollButtonPress
    call trainer_card_teardown
    call GBPalWhiteOut
    call LoadFontTilePatterns
    ; call LoadScreenTilesFromBuffer2 — port(window model): the START redraw below
    ; rebuilds the screen; no screen-buffer restore needed.
    call RunDefaultPaletteCommand
    call ReloadMapData
    call DrawStartMenu                  ; farcall DrawStartMenu
    call LoadGBPal
    pop eax                             ; pop af
    mov [ebp + hTileAnimations], al
    mov dword [text_row_stride], 20     ; DrawTrainerInfo set stride 40 → restore
    jmp RedisplayStartMenu_DoNotDrawStartMenu

; ===========================================================================
; DrawTrainerInfo + TrainerInfo_* helpers — the trainer-card screen body, at its
; pret position (between StartMenu_TrainerInfo and StartMenu_SaveReset, in pret's
; in-file order). Merged back from engine/menus/trainer_card.asm (menus-port
; Session 9 file; relocated_files debt retired 2026-07-24).
;
; DrawTrainerInfo loads the trainer-card tile graphics into VRAM, displays Red's
; front pic upper-right, draws the NAME/MONEY/TIME box + the ○BADGES○ box, and
; prints the player name, money (BCD) and play time. StartMenu_TrainerInfo (above)
; then calls DrawBadges (package B) for the 4×2 face/badge grid, composites the
; whole 20×18 screen as one window (trainer_card_present), and waits
; (WaitForTextScrollButtonPress) before restoring the overworld.
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
;   Tiles are carried in assets/trainer_card_tiles.inc (tools/generators/
;   gen_trainer_card_tiles.py, Tier-1) except the faces/badges
;   (assets/badge_tiles.inc, package B).
;
; PORT MODEL (CLAUDE.md + options.asm/pokedex_entry.asm precedent):
;   * Full-takeover screen: drawn at pret GB coords into the stride-20 W_TILEMAP
;     scratch (text_row_stride = 20; TC_HL(X,Y)=W_TILEMAP+Y*20+X), then composited
;     as one full-screen window over a whited-out overworld (options.asm model).
;   * DisableLCD/EnableLCD bracket the VRAM tile loads (faithful); the port also
;     sets g_tilecache_dirty so the decoded-tile cache refreshes.
; ===========================================================================

; ---------------------------------------------------------------------------
; DrawTrainerInfo — pret ref: start_sub_menus.asm:DrawTrainerInfo.
; loads tile patterns and draws everything except the gym-leader faces / badges
; (StartMenu_TrainerInfo calls DrawBadges after this). In: EBP = GB base.
; ---------------------------------------------------------------------------
DrawTrainerInfo:
    mov dword [text_row_stride], TCSCR_W        ; port: this screen owns the stride-20 scratch
    ; ld de, RedPicFront / lb bc, BANK, $01 / predef DisplayPicCenteredOrUpperRight
    ; — display Red's front pic upper-right (c=$01).
    ; DEVIATION{class=temporary; pret=engine/menus/start_sub_menus.asm:DrawTrainerInfo; behavior=use the caller-specific TrainerInfo_DisplayPlayerPic helper instead of missing DisplayPicCenteredOrUpperRight; evidence=project_state reports DisplayPicCenteredOrUpperRight missing; lifetime=until the shared picture predef is ported}
    ; DisplayPicCenteredOrUpperRight is not translated
    ; (label DB: missing). TrainerInfo_DisplayPlayerPic below does the c=$01 half of it
    ; for this one caller — see its header for the pic path and the column clamp. Retire
    ; it when the predef lands: this call becomes the predef with de/bc as pret sets them.
    call TrainerInfo_DisplayPlayerPic
    call DisableLCD
    ; hlcoord 0,2 / ' ' vline ; hlcoord 1,2 / ' ' vline — blank the two columns the
    ; pic's left edge would otherwise occupy behind the name box.
    mov esi, TC_HL(0, 2)
    mov al, 0x7F                                ; ' '
    call TrainerInfo_DrawVerticalLine
    mov esi, TC_HL(1, 2)
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
    ; DEVIATION{class=banking; pret=engine/menus/start_sub_menus.asm:DrawTrainerInfo; behavior=call shared LoadBadgeTiles instead of duplicating pret's inline FarCopyData load; evidence=pret inline face-badge copy plus linked draw_badges.asm shared owner; lifetime=permanent flat-data helper split}
    ; pret loads the 8*8 face/badge tiles inline here with a plain
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
    mov esi, TC_HL(0, 0)
    call TrainerInfo_DrawTextBox
    ; --- inner box: width 16, at (1,10) ---
    mov byte [ebp + wTrainerInfoTextBoxWidthPlus1], 16 + 1
    mov byte [ebp + wTrainerInfoTextBoxWidth], 16
    mov byte [ebp + wTrainerInfoTextBoxNextRowOffset], 3        ; SCREEN_WIDTH - (16+1)
    mov esi, TC_HL(1, 10)
    call TrainerInfo_DrawTextBox
    ; vertical lines framing the badge box (tile $d7 = box bg)
    mov esi, TC_HL(0, 10)
    mov al, 0xD7
    call TrainerInfo_DrawVerticalLine
    mov esi, TC_HL(19, 10)
    mov al, 0xD7
    call TrainerInfo_DrawVerticalLine
    ; ○BADGES○ label at (6,9)
    mov esi, TC_HL(6, 9)
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
    mov esi, TC_HL(2, 2)
    mov eax, TrainerInfo_NameMoneyTimeText
    call PlaceString
    ; player name at (7,2)
    mov esi, TC_HL(7, 2)
    lea eax, [ebp + wPlayerName]
    call PlaceString
    ; money (BCD) at (8,4): c = 3 | LEADING_ZEROES | LEFT_ALIGN | MONEY_SIGN
    mov esi, TC_HL(8, 4)
    mov edx, wPlayerMoney
    mov bl, 3 | NUM_LEADING_ZERO | NUM_LEFT_ALIGN | NUM_MONEY_SIGN
    call PrintBCDNumber
    ; play time hours at (9,6): b = LEFT_ALIGN|1, c = 3
    mov esi, TC_HL(9, 6)
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
; DEVIATION{class=HAL; pret=engine/menus/start_sub_menus.asm:DrawTrainerInfo; behavior=route flat trainer-card tile assets through CopyVideoData instead of banked FarCopyData; evidence=pret FarCopyData tile writes plus port tile-cache invalidation contract; lifetime=permanent flat-memory and software-video boundary}
; The tail is CopyVideoData, not FarCopyData. Two
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
; TrainerInfo_DisplayPlayerPic — PORT-ONLY helper (no pret label; it stands in
; for the missing DisplayPicCenteredOrUpperRight predef — see the DEVIATION at
; its call site in DrawTrainerInfo). Stages PlayerPicFront (red.pic, 7×7) into
; GB scratch, decodes + merges it to GB_VCHARS2 (49 tiles at ids $00+), and
; places the tilemap at the upper-right (pret hlcoord 15,1, hStartTileID 0).
; DEVIATION{class=projection; pret=engine/menus/start_sub_menus.asm:DrawTrainerInfo; behavior=the 7-wide pic placement is clamped to the on-screen columns 15-19 so the block does not wrap the 20-wide tilemap scratch, where pret's hlcoord 15,1 writes all 7 columns into its own 20-wide wTileMap; evidence=the port's tilemap scratch for this screen is 20 columns wide and starts the pic at column 15, so columns 22-26 would wrap into the next row; lifetime=until this screen is rebuilt on the port's native 40-column surface}
; The VRAM shift in DrawTrainerInfo keeps the faces' $20 range free exactly as pret.
; In: EBP = GB base.
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
    ; place the tilemap upper-right: column-major, id = col*7 + row, from TC_HL(15,1),
    ; clamped to the 5 visible columns (15-19). DEVIATION(pic): clamp, see header.
    xor ebx, ebx                                  ; col
.col:
    movzx eax, bl
    imul eax, eax, 7                              ; base id for this column
    mov ecx, 7                                    ; rows
    mov esi, TC_HL(15, 1)
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

; --- TrainerInfo_NameMoneyTimeText / TrainerInfo_BadgesText — at their pret
; position (between TrainerInfo_FarCopyData and TrainerInfo_DrawTextBox).
; Tier-1 DATA, generated by tools/generators/gen_menu_strings.py through the
; charmap (gb_text.encode). They were hand-encoded `db 0x8D,0x80,...` in the old
; trainer_card.asm until 2026-07-13 — the Tier-1 violation CLAUDE.md names
; explicitly. The generated bytes are byte-identical to the literals they
; replace ('/' encodes to $F3 through the charmap; only <NEXT> $4E, '@' $50 and
; the ○ TILE $76 are raw bytes — and pret writes that one as a byte too).
;
; The NAME/MONEY/TIME labels are double-spaced (rows 2,4,6) to line up with the
; value coords (name (7,2), money (8,4), time (9,6)): BIT_SINGLE_SPACED_LINES is
; clear, so <NEXT> advances two rows (players_pc.asm model).
; (The .inc opens section .data itself; switch back to .text after.)
%include "assets/trainer_card_strings.inc"
section .text

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

StartMenu_SaveReset:                    ; pret ref: start_sub_menus.asm:StartMenu_SaveReset
    ; The RESET half is back. It was omitted as "link-play (S8) … the guard would
    ; never take", but DrawStartMenu reads the SAME bit to label this item RESET
    ; instead of SAVE (draw_start_menu.asm: BIT_LINK_CONNECTED → StartMenuResetText).
    ; So the port would draw "RESET" and then SAVE — the two halves of one feature,
    ; split. Init is translated and linked; the branch costs three instructions and
    ; makes the pair correct by construction whenever link state does arrive.
    mov al, [ebp + W_STATUS_FLAGS_4]
    test al, (1 << BIT_LINK_CONNECTED)
    jnz Init                            ; jp nz, Init — soft reset during a link
    call SaveMenu                       ; predef SaveMenu
    ; DEVIATION{class=temporary; pret=engine/menus/start_sub_menus.asm:StartMenu_SaveReset; behavior=use linked CloseStartMenu instead of check-only HoldTextDisplayOpen and CloseTextDisplay after saving; evidence=project_state reports both text-script routines check-only and port fold closes to the same map destination; lifetime=until text_script.asm closure links}
    ; pret is `call LoadScreenTilesFromBuffer2 /
    ; jp HoldTextDisplayOpen` — hold until A is released, then fall into
    ; CloseTextDisplay, which CLOSES the menu and returns to the map. The port used
    ; to `jmp RedisplayStartMenu` and leave the START menu open after saving, which
    ; is simply the wrong screen. HoldTextDisplayOpen and CloseTextDisplay are both
    ; translated but sit in check-only text_script.asm (they do not link — the row-9
    ; part-3 linkage item); CloseStartMenu is the port's already-sanctioned fold of
    ; exactly that pair — release-spin, then the folded CloseTextDisplay — so the
    ; behaviour lands where pret's does. It spins on B/START too (the port reads
    ; HELD, not the edge) and reloads the box tiles on the way out; both are
    ; harmless supersets of the hold. The buffer restore is dropped (window model).
    jmp CloseStartMenu
; StartMenu_Option — pret ref: start_sub_menus.asm:StartMenu_Option.
; The OPTION screen (DisplayOptionMenu, pkg D). DisplayOptionMenu_ owns its own
; full-screen window + whiteout; drop them here before the START redraw.
StartMenu_Option:
    xor al, al
    mov [ebp + hAutoBGTransferEnabled], al   ; ldh [hAutoBGTransferEnabled],a
    call ClearScreen
    call UpdateSprites
    call DisplayOptionMenu                    ; callfar DisplayOptionMenu
    ; call LoadScreenTilesFromBuffer2 — port(window model): RedisplayStartMenu redraws.
    call LoadTextBoxTilePatterns
    call UpdateSprites
    ; port: drop the OPTION full-takeover window + whiteout (text_row_stride is
    ; already 20 — InitOptionsMenu set it) before RedisplayStartMenu.
    mov dword [g_window_count], 0
    mov dword [g_bg_whiteout], 0
    mov dword [g_obj_over_window], 0    ; back to the port's window-last order
    jmp RedisplayStartMenu

; ---------------------------------------------------------------------------
; ItemMenuLoop — pret ref: start_sub_menus.asm:ItemMenuLoop.
; pret: LoadScreenTilesFromBuffer2DisableBGTransfer + RunDefaultPaletteCommand,
; then falls into StartMenu_Item.
;
; LoadScreenTilesFromBuffer2DisableBGTransfer (home/tilemap.asm) does TWO things,
; and only one of them is window-model:
;   xor a / ldh [hAutoBGTransferEnabled], a   ← a plain state write. NOT a screen
;                                               restore. Kept, below.
;   wTileMapBackup2 → wTileMap (CopyData)     ← DEVIATION(window-model): the port
;                                               has no screen buffer to restore;
;                                               DisplayListMenuID redraws the list
;                                               and resets the window list.
; The old comment folded both into "subsumed by DisplayListMenuID's full redraw"
; and dropped the store with them. DisplayListMenuID happens to clear the byte
; itself (list_menu.asm:194), so nothing was visibly broken — but that is the
; callee's business, not a licence for the caller to skip pret's write, and the
; hAutoBGTransferEnabled leak is a known regression class here (OW-A.13).
; ---------------------------------------------------------------------------
ItemMenuLoop:
    mov byte [ebp + hAutoBGTransferEnabled], 0  ; LoadScreenTilesFromBuffer2DisableBGTransfer
    call RunDefaultPaletteCommand               ; call RunDefaultPaletteCommand
    ; fall through to StartMenu_Item

; ---------------------------------------------------------------------------
; StartMenu_Item — pret ref: start_sub_menus.asm:StartMenu_Item.
; The bag: DisplayListMenuID(ITEMLISTMENU) over wNumBagItems, then the
; USE/TOSS box for the chosen item. USE is a tagged stub (items-plan scope);
; TOSS runs the faithful chain (quantity → TossItem → yes/no → remove).
; ---------------------------------------------------------------------------
StartMenu_Item:
    mov al, [ebp + wLinkState]
    dec al                              ; is the player in the Colosseum or Trade Centre?
    jnz .notInCableClubRoom
    mov esi, CannotUseItemsHereText     ; ld hl, CannotUseItemsHereText
    mov dword [text_msgbox], msgbox_dialog  ; port: the standard bottom message box
    call PrintText
    jmp .exitMenu                       ; jr .exitMenu
.notInCableClubRoom:
    ; store the bag pointer in wListPointer (for DisplayListMenuID)
    mov word [ebp + wListPointer], wNumBagItems
    xor al, al
    mov [ebp + wPrintItemPrices], al
    mov al, ITEMLISTMENU
    mov [ebp + wListMenuID], al
    mov al, [ebp + wBagSavedMenuItem]
    mov [ebp + wCurrentMenuItem], al
    call DisplayListMenuID
    mov al, [ebp + wCurrentMenuItem]
    mov [ebp + wBagSavedMenuItem], al
    jnc .choseItem
.exitMenu:
    ; DEVIATION{class=projection; pret=engine/menus/start_sub_menus.asm:StartMenu_Item; behavior=redraw the START window list instead of restoring Buffer2 after leaving the bag; evidence=pret Buffer2 restore plus port RedisplayStartMenu window rebuild; lifetime=permanent window-compositor boundary}
    ; pret's `call LoadScreenTilesFromBuffer2` is dropped —
    ; RedisplayStartMenu → DrawStartMenu rebuilds the window list and the box, so
    ; there is no screen buffer to restore.
    ;
    ; Its two NEIGHBOURS were dropped with it, which the window model does not
    ; excuse and which was a real bug. LoadTextBoxTilePatterns reloads VRAM TILE
    ; PATTERNS, not a tilemap: a USE that opens the party menu overwrites the box
    ; tiles with the HP-bar set ($62-$7F) — this file's own StartMenu_Pokemon
    ; .exitMenu comment says exactly that — so leaving the bag afterwards drew the
    ; START box out of HP-bar patterns, and the compositor caches those tiles
    ; (g_tilecache_dirty), so it sticks. RedisplayStartMenu does NOT reload them.
    ; StartMenu_Option, twenty lines up in this same file, kept both calls.
    call LoadTextBoxTilePatterns        ; call LoadTextBoxTilePatterns
    call UpdateSprites                  ; call UpdateSprites
    jmp RedisplayStartMenu              ; jp RedisplayStartMenu
.choseItem:
    ; erase the list-menu cursor: pret blanks coords (5,4)/(5,6)/(5,8)/(5,10)
    ; = list-box-relative (1,2)/(1,4)/(1,6)/(1,8) in the stride-20 scratch
    mov al, TILE_SPC
    mov [ebp + W_TILEMAP + 2 * 20 + 1], al
    mov [ebp + W_TILEMAP + 4 * 20 + 1], al
    mov [ebp + W_TILEMAP + 6 * 20 + 1], al
    mov [ebp + W_TILEMAP + 8 * 20 + 1], al
    call PlaceUnfilledArrowMenuCursor
    call list_mirror                    ; port: push the edits to the list window
    xor al, al
    mov [ebp + wMenuItemToSwap], al
    mov al, [ebp + wCurItem]
    cmp al, BICYCLE
    je .useOrTossItem                   ; Bicycle: no USE/TOSS box
    ; --- USE/TOSS sub-menu ---
    mov byte [ebp + wTextBoxID], USE_TOSS_MENU_TEMPLATE
    call DisplayTextBoxID               ; canvas box at UI_USE_TOSS_* coords
    call ut_show_window                 ; port: bridge the canvas rect → window
    ; menu vars — pret Y=11 X=14, projected onto the canvas:
    ; PROJ menus: cursor = (UI_USE_TOSS_MENU_TEMPLATE_TX-1, .._TY)
    mov byte [ebp + wTopMenuItemY], UI_USE_TOSS_MENU_TEMPLATE_TY
    mov byte [ebp + wTopMenuItemX], UI_USE_TOSS_MENU_TEMPLATE_TX - 1
    xor al, al
    mov [ebp + wCurrentMenuItem], al
    mov [ebp + wLastMenuItem], al       ; old menu item id
    inc al                              ; a = 1
    mov [ebp + wMaxMenuItem], al
    mov byte [ebp + wMenuWatchedKeys], PAD_A | PAD_B
    ; port: the box lives on the 40-wide canvas for the duration of the input
    mov dword [text_row_stride], SCREEN_TILES_W
    mov dword [menu_item_step], 2 * SCREEN_TILES_W
    mov dword [menu_redraw_cb], ut_mirror
    call HandleMenuInput
    mov dword [menu_redraw_cb], 0
    mov bl, al                          ; keep the pressed keys
    call PlaceUnfilledArrowMenuCursor
    call ut_mirror                      ; final cursor state → window
    mov dword [text_row_stride], 20     ; back to the overworld scratch stride
    test bl, PAD_B                      ; bit B_PAD_B,a
    jz .useOrTossItem
    jmp ItemMenuLoop
.useOrTossItem:
    mov al, [ebp + wCurItem]
    mov [ebp + wNamedObjectIndex], al
    call GetItemName
    mov edx, wNameBuffer
    call CopyToStringBuffer
    mov al, [ebp + wCurItem]
    cmp al, BICYCLE
    jne .notBicycle
    mov al, [ebp + W_STATUS_FLAGS_6]
    test al, (1 << BIT_ALWAYS_ON_BIKE)
    jz .useItem_closeMenu
    mov esi, CannotGetOffHereText       ; ld hl, CannotGetOffHereText
    mov dword [text_msgbox], msgbox_dialog
    call PrintText
    jmp ItemMenuLoop                    ; jp ItemMenuLoop
.notBicycle:
    mov al, [ebp + wCurrentMenuItem]
    test al, al                         ; and a
    jnz .tossItem
    ; --- USE --- (pret engine/menus/start_sub_menus.asm:.notBicycle "use item")
    mov [ebp + wPseudoItemID], al       ; a must be 0 due to the jump above
    mov al, [ebp + wCurItem]
    cmp al, HM01
    jae .useItem_partyMenu              ; jr nc — an HM is "taught", party menu
    mov esi, UsableItems_CloseMenu      ; ld hl, UsableItems_CloseMenu
    mov edx, 1                          ; ld de, 1
    call IsInArray
    jc .useItem_closeMenu
    mov al, [ebp + wCurItem]
    mov esi, UsableItems_PartyMenu      ; ld hl, UsableItems_PartyMenu
    mov edx, 1
    call IsInArray
    jc .useItem_partyMenu
    call UseItem                        ; everything else: use in place, stay in the bag
    jmp ItemMenuLoop
.useItem_closeMenu:
    mov byte [ebp + wPseudoItemID], 0   ; xor a / ld [wPseudoItemID],a
    call UseItem
    mov al, [ebp + wActionResultOrTookBattleTurn]
    test al, al
    jz ItemMenuLoop                     ; jp z — the item refused; stay in the bag
    jmp CloseStartMenu
.useItem_partyMenu:
    movzx eax, byte [ebp + wUpdateSpritesEnabled]
    push eax                            ; push af
    call UseItem
    mov al, [ebp + wActionResultOrTookBattleTurn]
    cmp al, 0x02                        ; "not usable now, no menu shown"
    jz .partyMenuNotDisplayed
    call GBPalWhiteOutWithDelay3
    call RestoreScreenTilesAndReloadTilePatterns
    pop eax
    mov [ebp + wUpdateSpritesEnabled], al
    jmp StartMenu_Item                  ; jp StartMenu_Item — redraw the bag
.partyMenuNotDisplayed:
    pop eax
    mov [ebp + wUpdateSpritesEnabled], al
    jmp ItemMenuLoop
.tossItem:
    call IsKeyItem                      ; [wCurItem] → [wIsKeyItem]
    mov al, [ebp + wIsKeyItem]
    test al, al
    jnz .skipAskingQuantity             ; key item: TossItem_ shows "too important"
    mov al, [ebp + wCurItem]
    call IsItemHM                       ; CF = is HM
    jc .skipAskingQuantity
    call DisplayChooseQuantityMenu      ; appends the qty window; AL=$ff on B
    inc al
    jz .tossZeroItems
.skipAskingQuantity:
    mov esi, wNumBagItems               ; ld hl, wNumBagItems
    call TossItem
.tossZeroItems:
    jmp ItemMenuLoop

; --- the two refusal messages (pret ref: start_sub_menus.asm, same position) ---
; Tier-2 wrappers over the Tier-1 streams in assets/menu_text.inc, keeping pret's
; text_far indirection rather than pointing PrintText at the flat body directly.
CannotUseItemsHereText:
    text_far _CannotUseItemsHereText
    text_end

CannotGetOffHereText:
    text_far _CannotGetOffHereText
    text_end

; ---------------------------------------------------------------------------
; ut_show_window — append the USE/TOSS window descriptor over the list.
; ut_mirror — blit the canvas rect (UT_COL,UT_ROW) UT_W×UT_H (stride 40) →
; GB_TILEMAP0 rows UT_SROW.., cols 0.. (window source). Registers preserved
; (ut_mirror doubles as menu_redraw_cb).
; ---------------------------------------------------------------------------
ut_show_window:
    call ut_mirror
    mov eax, UI_USE_TOSS_MENU_TEMPLATE_WX
    mov ebx, UI_USE_TOSS_MENU_TEMPLATE_WY
    mov ecx, UI_USE_TOSS_MENU_TEMPLATE_CLIP
    mov edx, UI_USE_TOSS_MENU_TEMPLATE_MAXY
    mov esi, GB_TILEMAP0
    mov edi, UT_SROW
    call add_window                     ; [list] → [list, use/toss]
    ret

ut_mirror:
    pushad
    xor ebx, ebx
.row:
    mov esi, ebx
    imul esi, esi, SCREEN_TILES_W
    lea esi, [ebp + esi + W_TILEMAP + UT_ROW * SCREEN_TILES_W + UT_COL]
    mov edi, ebx
    shl edi, 5
    lea edi, [ebp + edi + GB_TILEMAP0 + UT_SROW * 32]
    mov ecx, UT_W
    rep movsb
    inc ebx
    cmp ebx, UT_H
    jb .row
    popad
    ret

; ===========================================================================
; Field-move pop-up window bridge (S5). The box itself is drawn by S2's
; DisplayFieldMoveMonMenu on the 40-wide canvas; these routines recover its
; rect from the same wFieldMoves/wFieldMovesLeftmostXCoord state, mirror it
; to GB_TILEMAP0 rows 0.., and place a right/bottom-anchored window.
; PROJ menus: GB(11,11) 9x7 --(anchor=right/bottom)--> wx=255 wy=144 clip=72
;   max_y=200 [UI_FIELD_MOVE_MON_MENU_*]; a box grown by n field moves keeps
;   the same right/bottom anchor: wx = RENDER_W+7 - W*8, wy = RENDER_H - H*8
;   (W=9,H=7 lands exactly on UI_FIELD_MOVE_MON_MENU_WX/WY).
; ===========================================================================
FM_COL_SHIFT equ UI_FIELD_MOVE_MON_MENU_COL - UI_FIELD_MOVE_MON_MENU_GBX
FM_ROW_SHIFT equ UI_FIELD_MOVE_MON_MENU_ROW - UI_FIELD_MOVE_MON_MENU_GBY

section .bss
align 4
fm_left:      resd 1               ; pop-up rect, GB coords / tiles
fm_top:       resd 1
fm_w:         resd 1
fm_h:         resd 1
fm_saved_wc:  resd 1               ; g_window_count before the pop-up appended
; .choseStats camera save/restore across the StatusScreen full-canvas takeover
choseStats_saved_view: resw 1      ; W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR (2 bytes)
choseStats_saved_scx:  resb 1
choseStats_saved_scy:  resb 1
choseStats_saved_hscx: resb 1      ; H_SCX shadow (StatusScreen zeroes it; see save note)
choseStats_saved_hscy: resb 1      ; H_SCY shadow

section .text

fm_show_window:
    ; n = nonzero entries in wFieldMoves (wNumFieldMoves is consumed/zeroed by
    ; the draw itself, so recount — the same walk pret's menu-var loop does)
    xor ecx, ecx
    xor eax, eax
.count:
    cmp byte [ebp + eax + wFieldMoves], 0
    jz .counted
    inc ecx
    inc eax
    cmp eax, 4
    jb .count
.counted:
    test ecx, ecx
    jnz .dynamic
    ; no field moves: the static template box, GB (11,11) 9×7
    mov eax, UI_FIELD_MOVE_MON_MENU_GBX
    mov ebx, UI_FIELD_MOVE_MON_MENU_GBY
    mov edx, UI_FIELD_MOVE_MON_MENU_GBW
    mov esi, UI_FIELD_MOVE_MON_MENU_GBH
    jmp .have
.dynamic:
    ; DisplayFieldMoveMonMenu's geometry: left = leftmostX-1, interior width
    ; 19-leftmostX (total W = 21-leftmostX), box grown 2 rows per move above
    ; row 11 plus one blank row (top = 10-2n, total H = 8+2n)
    movzx eax, byte [ebp + wFieldMovesLeftmostXCoord]
    mov edx, 21
    sub edx, eax                        ; W
    dec eax                             ; left
    mov ebx, 10
    sub ebx, ecx
    sub ebx, ecx                        ; top = 10 - 2n
    lea esi, [ecx * 2 + 8]              ; H = 8 + 2n
.have:
    mov [fm_left], eax
    mov [fm_top], ebx
    mov [fm_w], edx
    mov [fm_h], esi
    call fm_mirror
    mov eax, [g_window_count]
    mov [fm_saved_wc], eax
    mov ecx, [fm_w]
    shl ecx, 3                          ; clip = W*8
    mov eax, RENDER_W + 7
    sub eax, ecx                        ; wx (right-anchored)
    mov ebx, [fm_h]
    shl ebx, 3
    neg ebx
    add ebx, RENDER_H                   ; wy = RENDER_H - H*8 (bottom-anchored)
    mov edx, UI_FIELD_MOVE_MON_MENU_MAXY
    mov esi, GB_TILEMAP0
    xor edi, edi                        ; source rows 0..H-1
    call add_window
    ret

; blit the pop-up's canvas rect → GB_TILEMAP0 rows 0.. — doubles as the
; menu_redraw_cb while the pop-up input runs (live cursor). Registers preserved.
fm_mirror:
    pushad
    mov edx, [fm_top]
    add edx, FM_ROW_SHIFT
    imul edx, edx, SCREEN_TILES_W
    add edx, [fm_left]
    add edx, FM_COL_SHIFT               ; canvas byte offset of the box rect
    xor ebx, ebx
.row:
    cmp ebx, [fm_h]
    jae .done
    mov esi, ebx
    imul esi, esi, SCREEN_TILES_W
    add esi, edx
    lea esi, [ebp + esi + W_TILEMAP]
    mov edi, ebx
    shl edi, 5
    lea edi, [ebp + edi + GB_TILEMAP0]
    mov ecx, [fm_w]
    rep movsb
    inc ebx
    jmp .row
.done:
    popad
    ret

; drop the pop-up window (pret's LoadScreenTilesFromBuffer1 analog). Clobbers EAX.
fm_drop_window:
    mov eax, [fm_saved_wc]
    mov [g_window_count], eax
    ret

; ---------------------------------------------------------------------------
; ErasePartyMenuCursors — pret ref: start_sub_menus.asm:ErasePartyMenuCursors.
; writes a blank tile to all possible menu cursor positions on the party menu
; (stride-20 scratch; positions are (0,1) + 2 rows apart). Clobbers ESI/ECX/AL.
; ---------------------------------------------------------------------------
ErasePartyMenuCursors:
    mov esi, W_TILEMAP + 1 * 20         ; hlcoord 0,1
    mov ecx, 6                          ; ld a,6 — 6 menu cursor positions
.loop:
    mov byte [ebp + esi], TILE_SPC      ; ld [hl],' '
    add esi, 2 * 20                     ; ld bc,2*SCREEN_WIDTH — 2 rows apart
    dec ecx
    jnz .loop
    ret

; ---------------------------------------------------------------------------
; SwitchPartyMon — pret ref: start_sub_menus.asm:SwitchPartyMon. Second A
; press of a swap: exchange the data, clear both mons' rows, full redraw.
; ---------------------------------------------------------------------------
SwitchPartyMon:
    call SwitchPartyMon_InitVarOrSwapData ; swap data
    mov al, [ebp + wSwappedMenuItem]
    call SwitchPartyMon_ClearGfx
    mov al, [ebp + wCurrentMenuItem]
    call SwitchPartyMon_ClearGfx
    jmp RedrawPartyMenu_                ; jp RedrawPartyMenu_

; In: AL = party slot. Clears the slot's two scratch rows AND parks its 4 icon
; OAM entries, then plays SFX_SWAP — all three, as pret does.
;
; The old comment here claimed the OAM park was unnecessary because "the port's
; BG icons live in the rows just cleared". That stopped being true when the party
; icons became OBJ (engine/gfx/mon_icons.asm): blanking the BG rows no longer
; touches them, so both swapped mons' icons stayed on screen over two blank rows.
; It was invisible only because the swap SFX was missing too — with no
; WaitForSoundToFinish there was no frame in which the cleared state was shown.
; Wiring the sound (below) is what makes the missing park visible, so both are
; fixed together.
;
; ; PROJ: pret parks at SCREEN_HEIGHT_PX + OAM_Y_OFS — "one screen-height down",
; which is off the bottom of a 144px GB screen. The port's screen is RENDER_H
; (200) tall and the party panel's origin is canvas y=0 (UI_PARTY_PANEL_WY), so
; the GB constant would land the icon at canvas y=144 — visibly relocated, not
; hidden. Same idea, the port's screen height: OBJ_PARK_Y → spr_dos_sy = RENDER_H.
OBJ_PARK_Y equ RENDER_H + OAM_Y_OFS     ; pret: SCREEN_HEIGHT_PX + OAM_Y_OFS
OBJ_SIZE   equ OAM_ENTRY_SIZE           ; pret's name for it
SwitchPartyMon_ClearGfx:
    pushad                              ; (pret: push af … pop af; it clobbers hl/bc/de)
    movzx eax, al                       ; AL = party slot
    push eax
    imul edi, eax, 2 * 20               ; hlcoord 0,0 + AddNTimes(2*SCREEN_WIDTH)
    lea edi, [ebp + edi + W_TILEMAP]
    mov ecx, 2 * 20                     ; ld c,SCREEN_WIDTH*2
    mov al, TILE_SPC                    ; ld a,' '
    rep stosb                           ; .clearMonBGLoop
    pop eax                             ; pop af — the slot again
    ; ld hl, wShadowOAMSprite00YCoord / ld bc, OBJ_SIZE*4 / call AddNTimes
    imul edi, eax, OBJ_SIZE * 4         ; 4 OAM entries per mon icon
    add edi, W_SHADOW_OAM               ; wShadowOAMSprite00YCoord
    mov ecx, 4                          ; ld de,OBJ_SIZE / ld c,e
.clearMonOAMLoop:
    mov byte [ebp + edi], OBJ_PARK_Y    ; ld [hl], SCREEN_HEIGHT_PX + OAM_Y_OFS
    add edi, OBJ_SIZE                   ; add hl, de
    dec ecx
    jnz .clearMonOAMLoop
    ; PORT: the compositor does not read shadow OAM's Y — render_sprites draws at
    ; spr_dos_sx/sy, which only CommitMonPartySpriteOAM publishes. A park that is
    ; never committed changes nothing on screen. Likewise the blanked rows reach
    ; the panel window only through PartyMenuMirror. Both are needed for the
    ; cleared state to be visible during the WaitForSoundToFinish spin below —
    ; which is exactly the frame window pret shows it in.
    call CommitMonPartySpriteOAM
    call PartyMenuMirror
    call WaitForSoundToFinish           ; call WaitForSoundToFinish
    mov al, SFX_SWAP
    call PlaySound                      ; jp PlaySound (tail in pret)
    popad
    ret

; ---------------------------------------------------------------------------
; SwitchPartyMon_InitVarOrSwapData — pret ref:
; start_sub_menus.asm:SwitchPartyMon_InitVarOrSwapData.
; First call arms [wMenuItemToSwap] (1-based); the second swaps species byte,
; 44-byte structs, OT names and nicknames through wSwitchPartyMonTempBuffer.
; ---------------------------------------------------------------------------
SwitchPartyMon_InitVarOrSwapData:
    mov al, [ebp + wMenuItemToSwap]
    test al, al                         ; initialised yet?
    jnz .pickedMonsToSwap
    ; if not, initialise it so that it matches the current mon
    mov al, [ebp + wWhichPokemon]
    inc al                              ; counts from 1
    mov [ebp + wMenuItemToSwap], al
    ret
.pickedMonsToSwap:
    xor al, al
    mov [ebp + wPartyMenuTypeOrMessageID], al
    mov al, [ebp + wMenuItemToSwap]
    dec al
    mov ah, al                          ; ld b,a — 0-based armed index
    mov al, [ebp + wCurrentMenuItem]
    mov [ebp + wSwappedMenuItem], al
    cmp al, ah                          ; swapping a mon with itself?
    jnz .swappingDifferentMons
    ; can't swap a mon with itself
    xor al, al
    mov [ebp + wMenuItemToSwap], al
    mov [ebp + wPartyMenuTypeOrMessageID], al
    ret
.swappingDifferentMons:
    mov al, ah                          ; ld a,b
    mov [ebp + wMenuItemToSwap], al     ; now the 0-based partner index
    push esi                            ; push hl
    push edx                            ; push de
    push ebx
    ; swap the wPartySpecies bytes through hSwapTemp
    movzx esi, byte [ebp + wCurrentMenuItem]
    add esi, wPartySpecies
    movzx edx, byte [ebp + wMenuItemToSwap]
    add edx, wPartySpecies
    mov al, [ebp + esi]
    mov [ebp + hSwapTemp], al           ; ldh [hSwapTemp],a
    mov al, [ebp + edx]
    mov [ebp + esi], al
    mov al, [ebp + hSwapTemp]
    mov [ebp + edx], al
    ; swap the 44-byte party structs: cur → temp, partner → cur, temp → partner
    mov esi, wPartyMons
    mov bx, PARTYMON_STRUCT_LENGTH
    mov al, [ebp + wCurrentMenuItem]
    call AddNTimes
    push esi
    mov edx, wSwitchPartyMonTempBuffer
    mov bx, PARTYMON_STRUCT_LENGTH
    call CopyData
    mov esi, wPartyMons
    mov bx, PARTYMON_STRUCT_LENGTH
    mov al, [ebp + wMenuItemToSwap]
    call AddNTimes
    pop edx                             ; pop de — dest = cur struct
    push esi
    mov bx, PARTYMON_STRUCT_LENGTH
    call CopyData
    pop edx                             ; pop de — dest = partner struct
    mov esi, wSwitchPartyMonTempBuffer
    mov bx, PARTYMON_STRUCT_LENGTH
    call CopyData
    ; swap the OT names
    mov esi, wPartyMonOT
    mov al, [ebp + wCurrentMenuItem]
    call SkipFixedLengthTextEntries
    push esi
    mov edx, wSwitchPartyMonTempBuffer
    mov bx, NAME_LENGTH
    call CopyData
    mov esi, wPartyMonOT
    mov al, [ebp + wMenuItemToSwap]
    call SkipFixedLengthTextEntries
    pop edx
    push esi
    mov bx, NAME_LENGTH
    call CopyData
    pop edx
    mov esi, wSwitchPartyMonTempBuffer
    mov bx, NAME_LENGTH
    call CopyData
    ; swap the nicknames
    mov esi, wPartyMonNicks
    mov al, [ebp + wCurrentMenuItem]
    call SkipFixedLengthTextEntries
    push esi
    mov edx, wSwitchPartyMonTempBuffer
    mov bx, NAME_LENGTH
    call CopyData
    mov esi, wPartyMonNicks
    mov al, [ebp + wMenuItemToSwap]
    call SkipFixedLengthTextEntries
    pop edx
    push esi
    mov bx, NAME_LENGTH
    call CopyData
    pop edx
    mov esi, wSwitchPartyMonTempBuffer
    mov bx, NAME_LENGTH
    call CopyData
    mov al, [ebp + wMenuItemToSwap]
    mov [ebp + wSwappedMenuItem], al
    xor al, al
    mov [ebp + wMenuItemToSwap], al
    mov [ebp + wPartyMenuTypeOrMessageID], al
    pop ebx
    pop edx                             ; pop de
    pop esi                             ; pop hl
    ret

; (RunDefaultPaletteCommand used to be defined HERE, file-local and ret-only,
; "so StartMenu_TrainerInfo/StartMenu_Pokedex control flow links". It links
; without it: the real body is global in naming_screen.asm and does what pret
; does — `ld b, SET_PAL_DEFAULT` then fall into RunPaletteCommand. The private
; copy silently ate the SET_PAL_DEFAULT argument for every caller in this file.
; Harmless only while RunPaletteCommand is itself a Phase-5 ret-stub; the moment
; the palette engine lands, this screen would have been the one that doesn't
; restore the default palette, for no discoverable reason. Now externed.
; pokedex.asm still carries a third private copy — filed, out of this row's scope.)

; ===========================================================================
%ifdef DEBUG_TRAINERCARD
; ---------------------------------------------------------------------------
; RunTrainerCardTest — menus S9 gate. Seeds the player name / money / play time /
; badges, loads the font + text-box tiles, draws the full TRAINER CARD
; (DrawTrainerInfo + DrawBadges), composites it, dumps FRAME.BIN and exits (the
; live StartMenu_TrainerInfo blocks on WaitForTextScrollButtonPress). Never
; returns. In: EBP = GB base. Called from EnterMap after the overworld loads
; (overworld.asm, same %ifdef).
; make SKIP_TITLE=1 DEBUG_TRAINERCARD=1
; ---------------------------------------------------------------------------
extern FillMemory                    ; home/copy2.asm
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
