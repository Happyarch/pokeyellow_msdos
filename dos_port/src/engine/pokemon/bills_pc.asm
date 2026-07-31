; dos_port/src/engine/pokemon/bills_pc.asm
; Bill's PC — mirror of pret engine/pokemon/bills_pc.asm.
;
; Pret labels held here, in pret file order: DisplayPCMainMenu (+ its entry
; strings, generated), BillsPC_, BillsPCMenu, ExitBillsPC, BillsPCPrintBox,
; BillsPCDeposit, SleepingPikachuText2, BillsPCWithdraw, BillsPCRelease,
; BillsPCChangeBox, DisplayMonListMenu, BillsPCMenuText, BoxNoPCText,
; KnowsHMMove, HMMoveArray, DisplayDepositWithdrawMenu, DepositPCText,
; WithdrawPCText, StatsCancelPCText, and the text_far wrapper block.
; NOT here: CableClubLeftGameboy / CableClubRightGameboy / JustAMomentText /
; UnusedOpenBillsPC (+ OpenBillsPCText) — the serial-link tail of pret's file.
; The cable club is a serial-HAL boundary (TODO-HW: network HAL, Phase 4) and
; its entry points are owned by engine/link/cable_club.asm's package.
;
; PORT MODEL:
;  * SM83→x86: A=AL, B=BH, C=BL (BC=EBX), D=DH, E=DL (DE=EDX), HL=ESI;
;    EBP = GB base; GB memory at [EBP+addr]; flat program-image tables read via
;    [label] or [esi] (never [ebp+label]).
;  * DEVIATION(window-compositor), same shape as players_pc.asm: on the GB the
;    tilemap IS the screen; the port draws into the stride-20 W_TILEMAP scratch
;    and shows it through window descriptors.
;      - DisplayPCMainMenu publishes a 16-wide window clipped to the drawn
;        (event-gated) box height, over the live overworld (UI_PC_MAIN_MENU).
;      - The Bill's PC box UI is a full 20x18 GB-screen takeover window
;        (UI_BILLS_PC): menu box, message strip, BOX No. readout and the
;        deposit/withdraw submenu all live in one scratch, so every pret
;        coordinate lands 1:1. g_bg_whiteout=1 while it is up (the party-menu
;        screen class); the scratch's uncovered cells hold the Buffer2-restored
;        map mirror, exactly the tiles the GB shows there.
;      - Messages print through msgbox_bills_pc (MB_WIN_TILEMAP=0): pret's
;        message-box geometry, drawn into rows 12-17 of the same scratch, so
;        PrintText never collapses the window list (the msgbox_players_pc
;        reason). Visibility is by mirror, not per-character reveal — faithful
;        in effect because BillsPC_ sets BIT_NO_TEXT_DELAY, as pret does.
;      - DisplayListMenuID (the mon list) hides our window and shows its own
;        (its documented behaviour); every return path either re-appends via
;        bpc_show_window or redraws whole at BillsPCMenu. The list's PC-box
;        anchor is still the shared bag anchor — the list_menu.asm TODO(proj).
;
; Externs resolved:
;   MoveMon / RemovePokemon → src/home/move_mon.asm (the pret home wrappers)
;   ChangeBox               → src/engine/menus/save.asm (first live caller here)
;   PrintPCBox              → src/engine/printer/printer_stubs.asm (STUB)
;   PlayCry                 → src/home/home_stubs.asm (STUB)
;   ModifyPikachuHappiness  → src/engine/battle/battle_exp_stubs.asm (STUB)

bits 32

%include "gb_macros.inc"
%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_text.inc"                   ; text_far / text_end + TX_* codes
%include "msgbox.inc"                    ; MB_* — the message-box projection record
%include "events.inc"                    ; CheckEvent (clobbers AL, sets ZF)
%include "assets/event_constants.inc"    ; EVENT_MET_BILL / EVENT_GOT_POKEDEX
%include "assets/audio_constants.inc"    ; SFX_TURN_ON_PC / SFX_TURN_OFF_PC

%define UI_LAYOUT_EQUATES_ONLY 1
%include "assets/ui_layout_menus.inc"

global DisplayPCMainMenu
global BillsPC_
global KnowsHMMove

extern MoveMon                  ; src/home/move_mon.asm (pret home wrapper)
extern RemovePokemon            ; src/home/move_mon.asm (pret home wrapper)
extern IsInArray                ; src/home/array2.asm (shared home global)
extern SaveScreenTilesToBuffer2 ; src/home/tilemap.asm
extern TextBoxBorder            ; home/text.asm — ESI=top-left, BL=int_w, BH=int_h
extern PlaceString              ; home/text.asm — ESI=dest, EAX=flat src; EBX=end
extern UpdateSprites            ; src/home/update_sprites.asm
extern add_window               ; ppu/ppu.asm — EAX=wx EBX=wy ECX=clip EDX=max_y ESI=tm EDI=row
extern text_row_stride          ; home/text.asm — active W_TILEMAP row stride
extern menu_item_step           ; home/window.asm — per-item cursor row step
extern menu_redraw_cb           ; home/window.asm — per-frame redraw cb (0=none)
extern hide_window              ; ppu/ppu.asm
extern g_window_count           ; ppu/ppu.asm
extern g_bg_whiteout            ; ppu/ppu.asm — 1 = blank background (takeover screens)
extern DelayFrame               ; src/home/vblank.asm
extern RefreshCollisionTileMap  ; engine/overworld/overworld.asm
extern HandleMenuInput          ; home/window.asm — Out: AL = watched keys pressed
extern PlaceUnfilledArrowMenuCursor ; home/window.asm
extern PrintText                ; home/window.asm — In: ESI = text stream
extern text_msgbox              ; home/text.asm — the active msgbox projection
extern msgbox_dialog            ; home/text.asm — the overworld dialog projection
extern text_arrow_pos           ; home/text.asm — <PROMPT> ▼ cell (from MB_ARROW)
extern PlaySound                ; home/audio.asm — In: AL = sound id
extern WaitForSoundToFinish     ; src/home/delay.asm
extern Delay3                   ; src/home/palettes.asm
extern CopyVideoData            ; src/home/copy2.asm — ESI=VRAM dest, EDX=flat src, BL=tiles
extern PokeballTileGraphics     ; engine/battle/draw_hud_pokeball_gfx.asm (pret mirror)
extern LoadHpBarAndStatusTilePatterns ; src/home/load_font.asm
extern LoadTextBoxTilePatterns  ; src/home/load_font.asm
extern LoadScreenTilesFromBuffer2 ; src/home/tilemap.asm
extern LoadScreenTilesFromBuffer2DisableBGTransfer ; src/home/tilemap.asm
extern SaveScreenTilesToBuffer1 ; src/home/tilemap.asm
extern LoadScreenTilesFromBuffer1 ; src/home/tilemap.asm
extern DisplayListMenuID        ; home/list_menu.asm
extern YesNoChoice              ; src/home/yes_no.asm — CF=0 YES, CF=1 NO (+ wCurrentMenuItem)
extern GetPartyMonName          ; src/home/pokemon.asm — AL=index, ESI=name list base
extern IsThisPartyMonStarterPikachu ; engine/pikachu/pikachu_status.asm — CF out
extern IsThisBoxMonStarterPikachu   ; engine/pikachu/pikachu_status.asm — CF out
extern CheckPikachuFollowingPlayer  ; src/home/pikachu.asm — ZF set = not following
extern PlayPikachuSoundClip     ; src/audio/pikachu_pcm.asm — DL = 0-based clip index
extern PlayCry                  ; home_stubs.asm STUB — AL = species
extern ModifyPikachuHappiness   ; battle_exp_stubs.asm STUB — DH = PIKAHAPPY_* kind (pret ld d)
extern ChangeBox                ; engine/menus/save.asm — first live caller
extern PrintPCBox               ; engine/printer/printer_stubs.asm STUB
extern StatusScreen             ; engine/pokemon/status_screen.asm (pret predef)
extern StatusScreen2            ; engine/pokemon/status_screen.asm (pret predef)
extern ReloadTilesetTilePatterns ; src/home/reload_tiles.asm
extern RunDefaultPaletteCommand ; src/home/palettes.asm
extern LoadGBPal                ; src/home/fade.asm

; wMoveMonType/wRemoveMonFromBox values (constants/pokemon_data_constants.asm).
; Both live at the same WRAM address (wMoveMonType = wRemoveMonFromBox = $CF94).
; Not in the shared .inc files; defined locally.
%define BOX_TO_PARTY  0
%define PARTY_TO_BOX  1

BPC_STRIDE  equ 20              ; the GB-shaped scratch stride (NOT the 40-wide canvas)
TILE_SPC    equ 0x7F            ; blank space tile
BPC_ARROW_BLINK equ 20          ; ▼ blink half-period, frames (players_pc / party menu)
CHAR_0      equ 0xF6            ; charmap '0' (NOT ASCII — the char-literal bug class)
CHAR_1      equ 0xF7            ; charmap '1'
CHAR_TERM   equ 0x50            ; charmap '@' terminator
BOX_NUM_MASK equ 0x7F           ; constants/pokemon_data_constants.asm (bit7 of
                                ; wCurrentBoxNum = BIT_HAS_CHANGED_BOXES)

; ===========================================================================
; Tier-1 DATA: the PC main-menu entry strings, the box-UI menu strings, and the
; fourteen message streams — generated from pret engine/pokemon/bills_pc.asm +
; data/text/text_3.asm.
%include "assets/bills_pc_text.inc"

section .bss
align 4
bpcm_rows:      resd 1          ; PC main menu: total drawn rows (int_h + 2)
bpc_saved_view: resw 1          ; .viewStats camera save (start_sub_menus precedent)
bpc_saved_scx:  resb 1
bpc_saved_scy:  resb 1
bpc_saved_hscx: resb 1
bpc_saved_hscy: resb 1

; ===========================================================================
section .text

; ---------------------------------------------------------------------------
; DisplayPCMainMenu — pret ref: engine/pokemon/bills_pc.asm:DisplayPCMainMenu.
; Draws the BILL's / <player>'s / OAK's / LEAGUE / LOG OFF selector box (height
; event-gated on wNumHoFTeams and EVENT_GOT_POKEDEX, entries on EVENT_MET_BILL)
; and arms the menu vars for PCMainMenu's HandleMenuInput (pc.asm).
; In: EBP = GB base.
; ---------------------------------------------------------------------------
DisplayPCMainMenu:
    xor al, al
    mov [ebp + hAutoBGTransferEnabled], al   ; ldh [hAutoBGTransferEnabled], a
    call SaveScreenTilesToBuffer2
    ; DEVIATION{class=projection; pret=engine/pokemon/bills_pc.asm:DisplayPCMainMenu; behavior=draw into the stride-20 scratch and publish a height-clipped window instead of live tilemap cells; evidence=port window-compositor model, the players_pc.asm PlayerPCMenu precedent; lifetime=permanent window-compositor boundary}
    mov dword [text_row_stride], BPC_STRIDE
    mov al, [ebp + wNumHoFTeams]
    test al, al                              ; and a
    jnz .leaguePCAvailable                   ; jr nz
    CheckEvent EVENT_GOT_POKEDEX             ; ZF=1 → not yet
    jz .noOaksPC                             ; jr z
    mov al, [ebp + wNumHoFTeams]             ; pret re-reads it; kept
    test al, al
    jnz .leaguePCAvailable
    mov esi, W_TILEMAP                       ; hlcoord 0, 0
    mov bh, 8                                ; lb bc, 8, 14
    mov bl, 14
    jmp .next
.noOaksPC:
    mov esi, W_TILEMAP                       ; hlcoord 0, 0
    mov bh, 6                                ; lb bc, 6, 14
    mov bl, 14
    jmp .next
.leaguePCAvailable:
    mov esi, W_TILEMAP                       ; hlcoord 0, 0
    mov bh, 10                               ; lb bc, 10, 14
    mov bl, 14
.next:
    ; port: remember the drawn height — the window is clipped to it, so the
    ; shorter variants do not paint blank rows over the map (on the GB the
    ; undrawn rows simply keep showing the map).
    movzx eax, bh
    add eax, 2
    mov [bpcm_rows], eax
    call TextBoxBorder
    call UpdateSprites
    mov byte [ebp + wMaxMenuItem], 3         ; ld a, 3 / ld [wMaxMenuItem], a
    CheckEvent EVENT_MET_BILL                ; ZF=0 → met Bill
    jnz .metBill                             ; jr nz
    mov esi, W_TILEMAP + 2 * BPC_STRIDE + 2  ; hlcoord 2, 2
    mov eax, SomeonesPCText
    jmp .next2                               ; jr .next2
.metBill:
    mov esi, W_TILEMAP + 2 * BPC_STRIDE + 2  ; hlcoord 2, 2
    mov eax, BillsPCText
.next2:
    call PlaceString
    mov esi, W_TILEMAP + 4 * BPC_STRIDE + 2  ; hlcoord 2, 4
    lea eax, [ebp + wPlayerName]             ; ld de, wPlayerName (GB string → flat)
    call PlaceString
    mov esi, ebx                             ; ld l, c / ld h, b — continue at end
    mov eax, PlayersPCText
    call PlaceString
    CheckEvent EVENT_GOT_POKEDEX
    jz .noOaksPC2                            ; jr z
    mov esi, W_TILEMAP + 6 * BPC_STRIDE + 2  ; hlcoord 2, 6
    mov eax, OaksPCText
    call PlaceString
    mov al, [ebp + wNumHoFTeams]
    test al, al                              ; and a
    jz .noLeaguePC                           ; jr z
    mov byte [ebp + wMaxMenuItem], 4         ; ld a, 4 / ld [wMaxMenuItem], a
    mov esi, W_TILEMAP + 8 * BPC_STRIDE + 2  ; hlcoord 2, 8
    mov eax, PKMNLeaguePCText
    call PlaceString
    mov esi, W_TILEMAP + 10 * BPC_STRIDE + 2 ; hlcoord 2, 10
    mov eax, LogOffPCText
    jmp .next3                               ; jr .next3
.noLeaguePC:
    mov esi, W_TILEMAP + 8 * BPC_STRIDE + 2  ; hlcoord 2, 8
    mov eax, LogOffPCText
    jmp .next3                               ; jr .next3
.noOaksPC2:
    mov byte [ebp + wMaxMenuItem], 2         ; ld a, $2 / ld [wMaxMenuItem], a
    mov esi, W_TILEMAP + 6 * BPC_STRIDE + 2  ; hlcoord 2, 6
    mov eax, LogOffPCText
.next3:
    call PlaceString
    mov byte [ebp + wMenuWatchedKeys], PAD_A | PAD_B
    mov byte [ebp + wTopMenuItemY], 2
    mov byte [ebp + wTopMenuItemX], 1
    xor al, al
    mov [ebp + wCurrentMenuItem], al
    mov [ebp + wLastMenuItem], al
    mov byte [ebp + hAutoBGTransferEnabled], 1
    ; port: publish the finished box as this screen's window, and hand
    ; HandleMenuInput (called next by PCMainMenu, pc.asm) the live-cursor
    ; mirror. pc.asm clears menu_redraw_cb when HandleMenuInput returns.
    call bpcm_show_window
    mov dword [menu_item_step], 2 * BPC_STRIDE
    mov dword [menu_redraw_cb], BPCMainMenuMirror
    ret

; ---------------------------------------------------------------------------
; bpcm_show_window — mirror the scratch and append the PC main-menu box
; (scratch rows 0..bpcm_rows-1 → GB_TILEMAP0) as this screen's window, clipped
; to the drawn variant height. Port-only (window-compositor boundary).
; ---------------------------------------------------------------------------
bpcm_show_window:
    call BPCMainMenuMirror
    mov eax, UI_PC_MAIN_MENU_WX
    mov ebx, UI_PC_MAIN_MENU_WY
    mov ecx, UI_PC_MAIN_MENU_CLIP
    mov edx, [bpcm_rows]
    shl edx, 3                               ; rows → pixels
    mov esi, GB_TILEMAP0
    xor edi, edi
    call add_window
    ret

; ---------------------------------------------------------------------------
; BPCMainMenuMirror — carry the stride-20 scratch rows 0-11 (the tallest menu
; variant) to GB_TILEMAP0; the window descriptor clips shorter variants. All
; registers preserved, so it also serves as HandleMenuInput's menu_redraw_cb
; (the live ▶ cursor is a scratch tile). Port-only.
; ---------------------------------------------------------------------------
BPCMainMenuMirror:
    pushad
    xor ebx, ebx
.row:
    imul esi, ebx, BPC_STRIDE
    lea esi, [ebp + esi + W_TILEMAP]
    mov edi, ebx
    shl edi, 5                               ; row * 32
    lea edi, [ebp + edi + GB_TILEMAP0]
    mov ecx, UI_PC_MAIN_MENU_GBW
    rep movsb
    inc ebx
    cmp ebx, UI_PC_MAIN_MENU_GBH
    jb .row
    popad
    ret

section .text

; ---------------------------------------------------------------------------
; BillsPC_ — pret ref: engine/pokemon/bills_pc.asm:BillsPC_.
; Bill's #MON-storage box UI entry. Called by pc.asm:BillsPC (the generic-PC
; path, BIT_USING_GENERIC_PC set) and by the direct script access (not set).
; Pushes [wListScrollOffset]; ExitBillsPC pops it — legal because every
; inter-routine edge from here to ExitBillsPC is a jmp, exactly as pret's are
; all jp (the stack never moves between the push and the pop).
; ---------------------------------------------------------------------------
BillsPC_:
    or byte [ebp + W_STATUS_FLAGS_5], (1 << BIT_NO_TEXT_DELAY) ; set BIT_NO_TEXT_DELAY, [hl]
    xor al, al
    mov [ebp + wParentMenuItem], al
    inc al                                   ; MONSTER_NAME
    mov [ebp + wNameListType], al
    call LoadHpBarAndStatusTilePatterns
    mov al, [ebp + wListScrollOffset]        ; ld a, [wListScrollOffset]
    push eax                                 ; push af
    ; DEVIATION{class=projection; pret=engine/pokemon/bills_pc.asm:BillsPC_; behavior=raise g_bg_whiteout for the 20x18 takeover window instead of drawing live tilemap cells over the map; evidence=port window-compositor model, the party-menu takeover-screen class, file header; lifetime=permanent window-compositor boundary}
    mov byte [g_bg_whiteout], 1
    mov al, [ebp + wMiscFlags]
    test al, (1 << BIT_USING_GENERIC_PC)     ; bit BIT_USING_GENERIC_PC, a
    jnz BillsPCMenu                          ; jr nz
    ; accessing it directly
    mov al, SFX_TURN_ON_PC
    call PlaySound
    mov esi, SwitchOnText                    ; ld hl, SwitchOnText
    call BillsPCPrintText                    ; call PrintText (our projection)
    ; fall through

; ---------------------------------------------------------------------------
; BillsPCMenu — pret ref: engine/pokemon/bills_pc.asm:BillsPCMenu.
; Draw + run the WITHDRAW/DEPOSIT/RELEASE/CHANGE BOX/PRINT BOX/SEE YA! menu.
; Every sub-flow jumps back here for a full redraw, as pret's do.
; ---------------------------------------------------------------------------
BillsPCMenu:
    mov al, [ebp + wParentMenuItem]
    mov [ebp + wCurrentMenuItem], al
    mov esi, GB_VCHARS2 + 0x78 * 16          ; ld hl, vChars2 tile $78
    mov edx, PokeballTileGraphics            ; ld de, PokeballTileGraphics (flat)
    mov bh, 0                                ; BANK(PokeballTileGraphics) — flat no-op
    mov bl, 1                                ; 1 tile
    call CopyVideoData                       ; arms g_tilecache_dirty itself
    call LoadScreenTilesFromBuffer2DisableBGTransfer
    ; DEVIATION{class=projection; pret=engine/pokemon/bills_pc.asm:BillsPCMenu; behavior=drop stale window descriptors and redraw the whole scratch on every menu re-entry; evidence=pret redraws over live tilemap cells while the port's list and dialog windows are descriptors no WRAM restore can drop, the PlayerPCMenu precedent; lifetime=permanent window-compositor boundary}
    call hide_window
    mov dword [text_row_stride], BPC_STRIDE
    ; clear BIT_SINGLE_SPACED_LINES so BillsPCMenuText's <NEXT>s advance 2 rows
    ; (pret relies on the ambient default; the players_pc.asm data-model note)
    and byte [ebp + H_UI_LAYOUT_FLAGS], (~(1 << BIT_SINGLE_SPACED_LINES)) & 0xFF
    mov esi, W_TILEMAP + 12 * BPC_STRIDE     ; hlcoord 0, 12
    mov bh, 4                                ; lb bc, 4, 18
    mov bl, 18
    call TextBoxBorder
    mov esi, W_TILEMAP                       ; hlcoord 0, 0
    mov bh, 12                               ; lb bc, 12, 12
    mov bl, 12
    call TextBoxBorder
    call UpdateSprites
    mov esi, W_TILEMAP + 2 * BPC_STRIDE + 2  ; hlcoord 2, 2
    mov eax, BillsPCMenuText
    call PlaceString
    ; the pret wTopMenuItemY..wMenuWatchMovingOutOfBounds hli-walk, named:
    mov byte [ebp + wTopMenuItemY], 2
    mov byte [ebp + wTopMenuItemX], 1
    mov byte [ebp + wMaxMenuItem], 5
    mov byte [ebp + wMenuWatchedKeys], PAD_A | PAD_B
    xor al, al
    mov [ebp + wLastMenuItem], al
    mov [ebp + wPartyAndBillsPCSavedMenuItem], al
    mov [ebp + wListScrollOffset], al
    mov [ebp + wMenuWatchMovingOutOfBounds], al
    mov [ebp + wPlayerMonNumber], al
    mov esi, W_TILEMAP + 14 * BPC_STRIDE + 9 ; hlcoord 9, 14
    mov bh, 2                                ; lb bc, 2, 9
    mov bl, 9
    call TextBoxBorder
    mov al, [ebp + wCurrentBoxNum]
    and al, BOX_NUM_MASK
    cmp al, 9
    jc .singleDigitBoxNum                    ; jr c
    ; two digit box num
    sub al, 9
    mov byte [ebp + W_TILEMAP + 16 * BPC_STRIDE + 17], CHAR_1 ; hlcoord 17,16 / ld [hl], '1'
    add al, CHAR_0                           ; add '0'
    jmp .next                                ; jr .next
.singleDigitBoxNum:
    add al, CHAR_1                           ; add '1'
.next:
    mov [ebp + W_TILEMAP + 16 * BPC_STRIDE + 18], al          ; ldcoord_a 18, 16
    mov esi, W_TILEMAP + 16 * BPC_STRIDE + 10                 ; hlcoord 10, 16
    mov eax, BoxNoPCText
    call PlaceString
    mov byte [ebp + hAutoBGTransferEnabled], 1
    ; port: publish the finished screen and hand HandleMenuInput the live-cursor
    ; mirror (covered by the BillsPCMenu DEVIATION above)
    call bpc_show_window
    mov dword [menu_item_step], 2 * BPC_STRIDE
    mov dword [menu_redraw_cb], BillsPCMirror
    call Delay3
    call HandleMenuInput
    mov dword [menu_redraw_cb], 0
    test al, PAD_B                           ; bit B_PAD_B, a
    jnz ExitBillsPC                          ; jp nz
    call PlaceUnfilledArrowMenuCursor
    mov al, [ebp + wCurrentMenuItem]
    mov [ebp + wParentMenuItem], al
    test al, al                              ; and a
    jz BillsPCWithdraw                       ; jp z — withdraw
    cmp al, 1
    jz BillsPCDeposit                        ; jp z — deposit
    cmp al, 2
    jz BillsPCRelease                        ; jp z — release
    cmp al, 3
    jz BillsPCChangeBox                      ; jp z — change box
    cmp al, 4
    jz BillsPCPrintBox                       ; jp z
    ; (5 = SEE YA!) falls through

; ---------------------------------------------------------------------------
; ExitBillsPC — pret ref: engine/pokemon/bills_pc.asm:ExitBillsPC.
; ---------------------------------------------------------------------------
ExitBillsPC:
    mov al, [ebp + wMiscFlags]
    test al, (1 << BIT_USING_GENERIC_PC)
    jnz .next                                ; jr nz
    ; accessing it directly
    call LoadTextBoxTilePatterns
    mov al, SFX_TURN_OFF_PC
    call PlaySound
    call WaitForSoundToFinish
.next:
    and byte [ebp + wMiscFlags], (~(1 << BIT_NO_MENU_BUTTON_SOUND)) & 0xFF ; res BIT_NO_MENU_BUTTON_SOUND, [hl]
    call LoadScreenTilesFromBuffer2
    ; DEVIATION{class=projection; pret=engine/pokemon/bills_pc.asm:ExitBillsPC; behavior=drop the takeover window and whiteout and rebuild the canvas collision mirror on exit; evidence=the WRAM restore can neither drop window descriptors nor rebuild the map mirror UpdateSprites reads, the ExitPlayerPC precedent; lifetime=permanent window-compositor boundary}
    call hide_window
    mov byte [g_bg_whiteout], 0
    mov dword [menu_redraw_cb], 0
    call RefreshCollisionTileMap
    pop eax                                  ; pop af
    mov [ebp + wListScrollOffset], al        ; ld [wListScrollOffset], a
    and byte [ebp + W_STATUS_FLAGS_5], (~(1 << BIT_NO_TEXT_DELAY)) & 0xFF ; res BIT_NO_TEXT_DELAY, [hl]
    ret

; ---------------------------------------------------------------------------
; BillsPCPrintBox — pret ref: engine/pokemon/bills_pc.asm:BillsPCPrintBox.
; ---------------------------------------------------------------------------
BillsPCPrintBox:
    call PrintPCBox                          ; callfar PrintPCBox — STUB (printer)
    jmp BillsPCMenu                          ; jp BillsPCMenu

; ---------------------------------------------------------------------------
; BillsPCDeposit — pret ref: engine/pokemon/bills_pc.asm:BillsPCDeposit.
; ---------------------------------------------------------------------------
BillsPCDeposit:
    mov al, [ebp + wPartyCount]
    dec al                                   ; dec a
    jnz .partyLargeEnough                    ; jr nz
    mov esi, CantDepositLastMonText
    call BillsPCPrintText
    jmp BillsPCMenu
.partyLargeEnough:
    mov al, [ebp + wBoxCount]
    cmp al, MONS_PER_BOX
    jne .boxNotFull                          ; jr nz
    mov esi, BoxFullText
    call BillsPCPrintText
    jmp BillsPCMenu
.boxNotFull:
    mov esi, wPartyCount                     ; ld hl, wPartyCount
    call DisplayMonListMenu
    jc BillsPCMenu                           ; jp c
    call IsThisPartyMonStarterPikachu        ; callfar — CF out
    jnc .asm_215ad                           ; jr nc
    call CheckPikachuFollowingPlayer         ; ZF set = not following
    jz .asm_215ad                            ; jr z
    mov esi, SleepingPikachuText2
    call BillsPCPrintText
    jmp BillsPCMenu
.asm_215ad:
    call DisplayDepositWithdrawMenu
    jnc BillsPCMenu                          ; jp nc
    call IsThisPartyMonStarterPikachu
    jnc .asm_215c9                           ; jr nc
    mov dl, 27                               ; ldpikacry e, PikachuCry28 (0-based; status_screen precedent)
    call PlayPikachuSoundClip                ; callfar PlayPikachuSoundClip
    jmp .asm_215cf                           ; jr
.asm_215c9:
    mov al, [ebp + wCurPartySpecies]
    call PlayCry                             ; ret-stub today (home_stubs.asm)
.asm_215cf:
    mov dh, PIKAHAPPY_DEPOSITED              ; farcall_ModifyPikachuHappiness: ld d, kind
    call ModifyPikachuHappiness              ; ret-stub today (battle_exp_stubs.asm)
    mov byte [ebp + wMoveMonType], PARTY_TO_BOX
    call MoveMon
    xor al, al
    mov [ebp + wRemoveMonFromBox], al
    call RemovePokemon
    call WaitForSoundToFinish
    ; compose the box-number glyph run at wBoxNumString ("##@" / "#@")
    mov esi, wBoxNumString                   ; ld hl, wBoxNumString
    mov al, [ebp + wCurrentBoxNum]
    and al, BOX_NUM_MASK
    cmp al, 9
    jc .singleDigitBoxNum                    ; jr c
    sub al, 9
    mov byte [ebp + esi], CHAR_1             ; ld [hl], '1'
    inc esi                                  ; inc hl
    add al, CHAR_0                           ; add '0'
    jmp .next                                ; jr .next
.singleDigitBoxNum:
    add al, CHAR_1                           ; add '1'
.next:
    mov [ebp + esi], al                      ; ld [hli], a
    inc esi
    mov byte [ebp + esi], CHAR_TERM          ; ld [hl], '@'
    mov esi, MonWasStoredText
    call BillsPCPrintText
    jmp BillsPCMenu

; ---------------------------------------------------------------------------
; BillsPCWithdraw — pret ref: engine/pokemon/bills_pc.asm:BillsPCWithdraw.
; ---------------------------------------------------------------------------
BillsPCWithdraw:
    mov al, [ebp + wBoxCount]
    test al, al                              ; and a
    jnz .boxNotEmpty                         ; jr nz
    mov esi, NoMonText
    call BillsPCPrintText
    jmp BillsPCMenu
.boxNotEmpty:
    mov al, [ebp + wPartyCount]
    cmp al, PARTY_LENGTH
    jne .partyNotFull                        ; jr nz
    mov esi, CantTakeMonText
    call BillsPCPrintText
    jmp BillsPCMenu
.partyNotFull:
    mov esi, wBoxCount                       ; ld hl, wBoxCount
    call DisplayMonListMenu
    jc BillsPCMenu                           ; jp c
    call DisplayDepositWithdrawMenu
    jnc BillsPCMenu                          ; jp nc
    mov al, [ebp + wWhichPokemon]
    mov esi, wBoxMonNicks                    ; ld hl, wBoxMonNicks
    call GetPartyMonName
    call IsThisBoxMonStarterPikachu
    jnc .asm_21660                           ; jr nc
    mov dl, 34                               ; ldpikacry e, PikachuCry35 (0-based)
    call PlayPikachuSoundClip
    jmp .asm_21666                           ; jr
.asm_21660:
    mov al, [ebp + wCurPartySpecies]
    call PlayCry                             ; ret-stub today (home_stubs.asm)
.asm_21666:
    xor al, al                               ; BOX_TO_PARTY
    mov [ebp + wMoveMonType], al
    call MoveMon
    mov al, 1
    mov [ebp + wRemoveMonFromBox], al
    call RemovePokemon
    call WaitForSoundToFinish
    mov esi, MonIsTakenOutText
    call BillsPCPrintText
    jmp BillsPCMenu

; ---------------------------------------------------------------------------
; BillsPCRelease — pret ref: engine/pokemon/bills_pc.asm:BillsPCRelease.
; ---------------------------------------------------------------------------
BillsPCRelease:
    mov al, [ebp + wBoxCount]
    test al, al                              ; and a
    jnz .loop                                ; jr nz
    mov esi, NoMonText
    call BillsPCPrintText
    jmp BillsPCMenu
.loop:
    mov esi, wBoxCount                       ; ld hl, wBoxCount
    call DisplayMonListMenu
    jc BillsPCMenu                           ; jp c
    call IsThisBoxMonStarterPikachu
    jc .asm_216cb                            ; jr c
    mov esi, OnceReleasedText
    call BillsPCPrintText
    call YesNoChoice
    mov al, [ebp + wCurrentMenuItem]
    test al, al                              ; and a
    jnz .loop                                ; jr nz — chose NO
    inc al                                   ; inc a (al = 1)
    mov [ebp + wRemoveMonFromBox], al
    call RemovePokemon
    call WaitForSoundToFinish
    mov al, [ebp + wCurPartySpecies]
    call PlayCry                             ; ret-stub today (home_stubs.asm)
    mov esi, MonWasReleasedText
    call BillsPCPrintText
    jmp BillsPCMenu
.asm_216cb:
    mov al, [ebp + wWhichPokemon]
    mov esi, wBoxMonNicks                    ; ld hl, wBoxMonNicks
    call GetPartyMonName
    mov dl, 39                               ; ldpikacry e, PikachuCry40 (0-based)
    call PlayPikachuSoundClip
    mov esi, PikachuUnhappyText
    call BillsPCPrintText
    jmp BillsPCMenu

; ---------------------------------------------------------------------------
; BillsPCChangeBox — pret ref: engine/pokemon/bills_pc.asm:BillsPCChangeBox.
; First live caller of ChangeBox (engine/menus/save.asm).
; ---------------------------------------------------------------------------
BillsPCChangeBox:
    call ChangeBox                           ; farcall ChangeBox
    jmp BillsPCMenu                          ; jp BillsPCMenu

; ---------------------------------------------------------------------------
; DisplayMonListMenu — pret ref: engine/pokemon/bills_pc.asm:DisplayMonListMenu.
; In: ESI (hl) = count-byte address (wPartyCount or wBoxCount).
; Out: CF from DisplayListMenuID (set = cancelled). The trailing stores are
; mov-only, so the flag survives to the callers' jp c, as in pret.
; ---------------------------------------------------------------------------
DisplayMonListMenu:
    mov [ebp + wListPointer], si             ; ld a,l / [wListPointer] / ld a,h / [wListPointer+1]
    xor al, al
    mov [ebp + wPrintItemPrices], al
    mov [ebp + wListMenuID], al              ; PCPOKEMONLISTMENU
    inc al                                   ; MONSTER_NAME
    mov [ebp + wNameListType], al
    mov al, [ebp + wPartyAndBillsPCSavedMenuItem]
    mov [ebp + wCurrentMenuItem], al
    call DisplayListMenuID
    mov al, [ebp + wCurrentMenuItem]
    mov [ebp + wPartyAndBillsPCSavedMenuItem], al
    ret


; ---------------------------------------------------------------------------
; KnowsHMMove
; Returns whether the party mon at index [wWhichPokemon] knows any HM move.
; Sets C flag if yes; clears C flag if no.
; Faithful to pret, including the dead wBoxMon1Moves branch below .next.
;
; Inputs (WRAM): wWhichPokemon = 0-based party slot index.
; Clobbers: EAX, ECX, EDX, ESI, EBX.
; ---------------------------------------------------------------------------
KnowsHMMove:
    mov esi, W_PARTY_MON1_MOVES     ; ld hl, wPartyMon1Moves ($D172)
    mov ecx, PARTYMON_STRUCT_LENGTH  ; ld bc, PARTYMON_STRUCT_LENGTH (44)
    jmp .next
    ; --- unreachable — pret-faithful dead code (mirrors the original binary) ---
    mov esi, W_BOX_MON1_MOVES       ; ld hl, wBoxMon1Moves ($DA9D)
    mov ecx, BOXMON_STRUCT_LENGTH   ; ld bc, BOXMON_STRUCT_LENGTH (33)
.next:
    ; AddNTimes equivalent: esi += wWhichPokemon * ecx (stride)
    movzx eax, byte [ebp + wWhichPokemon]   ; ld a,[wWhichPokemon]
    imul ecx, eax                            ; ecx = index × stride
    add esi, ecx                             ; esi → moves[wWhichPokemon]

    mov bh, NUM_MOVES               ; ld b, NUM_MOVES (4)
.loop:
    mov al, byte [ebp + esi]        ; ld a,[hli]  — read move id from GB mem
    inc esi                         ; (hli post-increment)

    push esi                        ; push hl  (save GB pointer)
    push ebx                        ; push bc  (save B=move-counter, C=scratch)

    lea esi, [HMMoveArray]          ; ld hl, HMMoveArray  — flat program address
    mov edx, 1                      ; ld de, 1  (stride = 1 byte)
    call IsInArray                  ; C set if AL found in HMMoveArray

    pop ebx                         ; pop bc
    pop esi                         ; pop hl

    jc .done                        ; ret c → jump to ret-with-carry

    dec bh                          ; dec b
    jnz .loop

    clc                             ; and a  (clear carry = not found)
.done:
    ret

; ---------------------------------------------------------------------------
section .data

; HM move list — searched by KnowsHMMove via IsInArray.
; Matches data/moves/hm_moves.asm (pret); terminated by $FF (-1).
; Move IDs from gb_constants.inc: CUT=$0F FLY=$13 SURF=$39 STRENGTH=$46 FLASH=$94
HMMoveArray:
    db CUT
    db FLY
    db SURF
    db STRENGTH
    db FLASH
    db -1       ; terminator ($FF / -1); matches pret's "db -1"

; ===========================================================================
section .text

; ---------------------------------------------------------------------------
; DisplayDepositWithdrawMenu — pret ref: engine/pokemon/bills_pc.asm:
; DisplayDepositWithdrawMenu. The DEPOSIT|WITHDRAW / STATS / CANCEL submenu.
; Out: CF set = chose deposit/withdraw; CF clear = cancelled (B or CANCEL).
; ---------------------------------------------------------------------------
DisplayDepositWithdrawMenu:
    mov esi, W_TILEMAP + 10 * BPC_STRIDE + 9 ; hlcoord 9, 10
    mov bh, 6                                ; lb bc, 6, 9
    mov bl, 9
    call TextBoxBorder
    mov al, [ebp + wParentMenuItem]
    test al, al                              ; and a — Deposit(1) or Withdraw(0)?
    mov eax, DepositPCText                   ; ld de, DepositPCText (mov imm keeps flags)
    jnz .next                                ; jr nz
    mov eax, WithdrawPCText                  ; ld de, WithdrawPCText
.next:
    mov esi, W_TILEMAP + 12 * BPC_STRIDE + 11 ; hlcoord 11, 12
    call PlaceString
    mov esi, W_TILEMAP + 14 * BPC_STRIDE + 11 ; hlcoord 11, 14
    mov eax, StatsCancelPCText
    call PlaceString
    ; the pret wTopMenuItemY..wMenuWatchMovingOutOfBounds hli-walk, named:
    mov byte [ebp + wTopMenuItemY], 12
    mov byte [ebp + wTopMenuItemX], 10
    xor al, al
    mov [ebp + wCurrentMenuItem], al
    mov byte [ebp + wMaxMenuItem], 2
    mov byte [ebp + wMenuWatchedKeys], PAD_A | PAD_B
    xor al, al
    mov [ebp + wLastMenuItem], al
    mov [ebp + wListScrollOffset], al
    mov [ebp + wMenuWatchMovingOutOfBounds], al
    mov [ebp + wPlayerMonNumber], al
    mov [ebp + wPartyAndBillsPCSavedMenuItem], al
    ; port: the mon list just closed (DisplayListMenuID's own hide_window) —
    ; re-show our screen with the submenu drawn, cursor mirrored (file header)
    call bpc_show_window
    mov dword [menu_item_step], 2 * BPC_STRIDE
    mov dword [menu_redraw_cb], BillsPCMirror
.loop:
    call HandleMenuInput
    test al, PAD_B                           ; bit B_PAD_B, a
    jnz .exit                                ; jr nz
    mov al, [ebp + wCurrentMenuItem]
    test al, al                              ; and a
    jz .choseDepositWithdraw                 ; jr z
    dec al
    jz .viewStats                            ; jr z
.exit:
    mov dword [menu_redraw_cb], 0            ; port: disarm the mirror cb
    clc                                      ; and a
    ret
.choseDepositWithdraw:
    mov dword [menu_redraw_cb], 0            ; port: disarm the mirror cb
    stc                                      ; scf
    ret
.viewStats:
    mov dword [menu_redraw_cb], 0            ; port: StatusScreen owns the frame now
    call SaveScreenTilesToBuffer1
    mov al, [ebp + wParentMenuItem]
    test al, al                              ; and a
    mov al, PLAYER_PARTY_DATA                ; (mov imm keeps flags)
    jnz .next2                               ; jr nz
    mov al, BOX_DATA
.next2:
    mov [ebp + wMonDataLocation], al
    ; PORT camera/scroll save around StatusScreen — the start_sub_menus
    ; .choseStats plumbing: StatusScreen zeroes the overworld camera + shadow
    ; scroll to drive its flat canvas and leaves text_row_stride at 40; without
    ; the restore the overworld behind the PC snaps to the map's top-left.
    mov ax, [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR]
    mov [bpc_saved_view], ax
    mov al, [ebp + IO_SCX]
    mov [bpc_saved_scx], al
    mov al, [ebp + IO_SCY]
    mov [bpc_saved_scy], al
    mov al, [ebp + H_SCX]
    mov [bpc_saved_hscx], al
    mov al, [ebp + H_SCY]
    mov [bpc_saved_hscy], al
    call StatusScreen                        ; predef StatusScreen
    call StatusScreen2                       ; predef StatusScreen2
    mov dword [text_row_stride], BPC_STRIDE  ; StatusScreen left it 40
    mov ax, [bpc_saved_view]
    mov [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR], ax
    mov al, [bpc_saved_scx]
    mov [ebp + IO_SCX], al
    mov al, [bpc_saved_scy]
    mov [ebp + IO_SCY], al
    mov al, [bpc_saved_hscx]
    mov [ebp + H_SCX], al
    mov al, [bpc_saved_hscy]
    mov [ebp + H_SCY], al
    call LoadScreenTilesFromBuffer1
    call ReloadTilesetTilePatterns
    call RunDefaultPaletteCommand
    call LoadGBPal
    ; port: re-show the Buffer1-restored screen (menu + submenu) + cursor mirror
    mov byte [g_bg_whiteout], 1              ; StatusScreen's teardown cleared it
    call bpc_show_window
    mov dword [menu_redraw_cb], BillsPCMirror
    jmp .loop                                ; jr .loop

; ===========================================================================
; The text streams — pret's own wrappers (engine/pokemon/bills_pc.asm) around
; the generated bodies in assets/bills_pc_text.inc. SleepingPikachuText2 sits
; between Deposit and Withdraw in pret; the wrappers are gathered here like
; players_pc.asm gathers its own (same .data unit, order within it is not
; load-bearing — nothing falls through between them).
; ===========================================================================
section .data

SwitchOnText:
    text_far _SwitchOnText
    text_end

WhatText:                                    ; pret-unreferenced; mirror completeness
    text_far _WhatText
    text_end

DepositWhichMonText:                         ; pret-unreferenced; mirror completeness
    text_far _DepositWhichMonText
    text_end

MonWasStoredText:
    text_far _MonWasStoredText
    text_end

CantDepositLastMonText:
    text_far _CantDepositLastMonText
    text_end

BoxFullText:
    text_far _BoxFullText
    text_end

MonIsTakenOutText:
    text_far _MonIsTakenOutText
    text_end

NoMonText:
    text_far _NoMonText
    text_end

CantTakeMonText:
    text_far _CantTakeMonText
    text_end

PikachuUnhappyText:
    text_far _PikachuUnhappyText
    text_end

ReleaseWhichMonText:                         ; pret-unreferenced; mirror completeness
    text_far _ReleaseWhichMonText
    text_end

OnceReleasedText:
    text_far _OnceReleasedText
    text_end

MonWasReleasedText:
    text_far _MonWasReleasedText
    text_end

SleepingPikachuText2:
    text_far _SleepingPikachuText2
    text_end

align 4
; msgbox_bills_pc — this screen's message-box projection (msgbox.inc). pret's
; geometry exactly (the strip BillsPCMenu borders at (0,12)); MB_WIN_TILEMAP = 0
; so PrintText draws into the same full-screen scratch and never collapses the
; window list (see the file header).
msgbox_bills_pc:
    dd BPC_STRIDE                            ; MB_STRIDE
    dd W_TILEMAP + 12 * BPC_STRIDE           ; MB_BOX_OFS      — (0,12)
    dd 18                                    ; MB_BOX_W        — 18 interior columns
    dd 4                                     ; MB_BOX_H        — 4 interior rows
    dd W_TILEMAP + 14 * BPC_STRIDE + 1       ; MB_LINE1        — pret bccoord 1,14
    dd W_TILEMAP + 16 * BPC_STRIDE + 1       ; MB_LINE2        — <LINE> at (1,16)
    dd W_TILEMAP + 16 * BPC_STRIDE + 18      ; MB_ARROW        — ▼ at (18,16)
    dd BillsPCPromptWait                     ; MB_PROMPT       — our own wait
    dd 0                                     ; MB_WIN_WX       ] no window: this
    dd 0                                     ; MB_WIN_WY       ] file mirrors the
    dd 0                                     ; MB_WIN_CLIP     ] scratch itself, so
    dd 0                                     ; MB_WIN_MAXY     ] the takeover window
    dd 0                                     ; MB_WIN_TILEMAP  ] survives the
    dd 0                                     ; MB_WIN_STARTROW ] message

; ===========================================================================
; Port plumbing — the window projection of this screen. pret has no counterpart:
; on the GB the tilemap IS the screen. See the header's DEVIATION notes.
; ===========================================================================
section .text

; ---------------------------------------------------------------------------
; BillsPCPrintText — PrintText through msgbox_bills_pc, then carry the result
; to the window layer. text_msgbox is global mutable state, so it is selected
; around the call and restored to the overworld default (the PlayerPCPrintText
; precedent). In: ESI = text stream.
; ---------------------------------------------------------------------------
BillsPCPrintText:
    mov dword [text_msgbox], msgbox_bills_pc
    call PrintText
    mov dword [text_msgbox], msgbox_dialog
    call bpc_show_window
    ret

; ---------------------------------------------------------------------------
; BillsPCPromptWait — msgbox_bills_pc's MB_PROMPT hook: blink the ▼ at
; [text_arrow_pos] and wait for A/B, mirroring the scratch each frame. The
; default hook is manual_text_scroll, which hijacks the window layer for the
; overworld dialog and would drop this screen (the PlayerPCPromptWait model).
; All registers preserved (the caller is mid-stream).
; ---------------------------------------------------------------------------
BillsPCPromptWait:
    pushad
    call bpc_show_window                     ; the finished box exists in the scratch
    mov esi, [text_arrow_pos]
    mov byte [ebp + esi], CHAR_DOWN_ARROW
    mov ecx, BPC_ARROW_BLINK
.wait:
    call BillsPCMirror
    call DelayFrame
    test byte [ebp + H_JOY_PRESSED], PAD_A | PAD_B
    jnz .done
    dec ecx
    jnz .wait
    mov ecx, BPC_ARROW_BLINK                 ; blink toggle
    cmp byte [ebp + esi], CHAR_DOWN_ARROW
    jne .turnOn
    mov byte [ebp + esi], TILE_SPC
    jmp .wait
.turnOn:
    mov byte [ebp + esi], CHAR_DOWN_ARROW
    jmp .wait
.done:
    mov byte [ebp + esi], TILE_SPC           ; erase the ▼
    call BillsPCMirror
    popad
    ret

; ---------------------------------------------------------------------------
; bpc_show_window — mirror the scratch, then make the 20x18 takeover window
; (UI_BILLS_PC) THE window: hide the list unconditionally and re-append ours.
; A g_window_count-equality heuristic (the ppc_show_msg_window model) does NOT
; work here: DisplayListMenuID hides everything and appends its own single
; window, so the count returns to exactly the recorded value and the stale
; check reads "still ours" while the descriptor on screen is the list's
; (measured: the submenu drew into the scratch while the dead list window
; stayed up). This screen owns the whole GB frame, so drop-and-re-add is
; always correct; a YES/NO box appended after this call still lands on top.
; All registers preserved.
; ---------------------------------------------------------------------------
bpc_show_window:
    pushad
    call BillsPCMirror
    call hide_window
    mov eax, UI_BILLS_PC_WX
    mov ebx, UI_BILLS_PC_WY
    mov ecx, UI_BILLS_PC_CLIP
    mov edx, UI_BILLS_PC_MAXY
    mov esi, GB_TILEMAP0
    xor edi, edi
    call add_window
    popad
    ret

; ---------------------------------------------------------------------------
; BillsPCMirror — carry the full 20x18 stride-20 scratch to GB_TILEMAP0 rows
; 0-17 (stride 32; the window clip is 160 px, so cols 20-31 need no padding).
; Preserves all registers, so it also serves as HandleMenuInput's
; menu_redraw_cb (the live ▶ cursor is a scratch tile).
; ---------------------------------------------------------------------------
BillsPCMirror:
    pushad
    xor ebx, ebx
.row:
    imul esi, ebx, BPC_STRIDE
    lea esi, [ebp + esi + W_TILEMAP]
    mov edi, ebx
    shl edi, 5                               ; row * 32
    lea edi, [ebp + edi + GB_TILEMAP0]
    mov ecx, BPC_STRIDE
    rep movsb
    inc ebx
    cmp ebx, 18
    jb .row
    popad
    ret

; ===========================================================================
%ifdef DEBUG_BILLSPC
%define DEBUG_BILLSPC_ANY 1
%endif
%ifdef DEBUG_BILLSPC_CHANGEBOX
%define DEBUG_BILLSPC_ANY 1
%endif
%ifdef DEBUG_BILLSPC_ANY
; ---------------------------------------------------------------------------
; RunBillsPCTest — box-behaviour harness (sram plan stage 6). The party is
; already seeded (DEBUG_SEED_PARTY runs PrepareNewGameDebug before the
; dispatch row); pin the player identity, load the font, and open BillsPC_
; directly as a generic-PC guest (BIT_USING_GENERIC_PC skips the turn-on
; SFX/dialog, exactly the state the real PCMainMenu path hands over). The
; scripted joypad (AUTOKEY_BILLSPC / AUTOKEY_BILLSPC_CHANGE, debug_dump.asm)
; drives the real UI; AutoKeyDrive dumps FRAME.BIN + GBSTATE.BIN at
; AUTOKEY_DUMP_FRAME while this hangs in DelayFrame after the flow exits.
; ---------------------------------------------------------------------------
extern SeedDeterministicPlayerIdentity   ; engine/debug/debug_party.asm
extern LoadFontTilePatterns              ; src/home/load_font.asm
global RunBillsPCTest
RunBillsPCTest:
%ifdef BILLSPC_ATTACH_DELAY
    ; ~10 s of DelayFrame before the flow starts, so a debugger can attach and
    ; arm breakpoints before the autokey script begins (the ITEMBALL_ATTACH_DELAY
    ; pattern). The autokey frame counter runs during the wait, so pair this
    ; with a script shifted by BILLSPC_ATTACH_DELAY frames — or simply accept
    ; that the un-shifted presses fall on the wait and drive by hand/debugger.
    mov ecx, BILLSPC_ATTACH_DELAY
.attach:
    call DelayFrame
    dec ecx
    jnz .attach
%endif
    call SeedDeterministicPlayerIdentity
    or byte [ebp + W_FONT_LOADED], (1 << BIT_FONT_LOADED)
    call LoadFontTilePatterns
    ; Mimic the FULL PCMainMenu handoff state: BIT_USING_GENERIC_PC (skip the
    ; turn-on SFX/dialog) AND BIT_NO_MENU_BUTTON_SOUND (pc.asm sets it before
    ; HandleMenuInput; ExitBillsPC resets it). Without the latter every scripted
    ; press rings the A/B SFX and the flows' WaitForSoundToFinish delays each
    ; message prompt past the next scripted press — a permanent one-press slip
    ; (measured: the stored-message prompt armed ~15 ticks after the dismiss
    ; press had already passed).
    or byte [ebp + wMiscFlags], (1 << BIT_USING_GENERIC_PC) | (1 << BIT_NO_MENU_BUTTON_SOUND)
    call BillsPC_
.hang:
    call DelayFrame
    jmp .hang
%endif
