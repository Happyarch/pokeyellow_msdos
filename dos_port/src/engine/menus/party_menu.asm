; party_menu.asm — DrawPartyMenu_ / RedrawPartyMenu_ (menus-port Session 5).
;
; Faithful port of pret engine/menus/party_menu.asm, realigned onto the
; generic drivers: the home driver (home/pokemon.asm DisplayPartyMenu /
; PartyMenuInit / HandlePartyMenuInput) owns the input loop via
; HandleMenuInput; this file owns the screen. Per-entry rendering follows
; pret line-for-line: GetPartyMonName + PlaceString at hlcoord 3,0 (+2 rows
; per mon), PrintStatusCondition 14 cols right, DrawHP2 (HP bar + fraction,
; BIT_PARTY_MENU_HP_BAR), SetPartyMenuHPBarColor, PrintLevel 10 cols right,
; the ▷ marker on the swap-armed mon, and the PartyMenuMessagePointers
; message in the bottom box.
;
; Port model (window compositor):
; - The screen is pret's 20×18 stride-20 W_TILEMAP scratch, mirrored to
;   GB_TILEMAP1 rows 0-17 by PartyMenuMirror — the hAutoBGTransferEnabled
;   analog (frame.asm's do_bg_transfer is canvas-scoped, stride 40, so it
;   can't serve this scratch; same explicit-mirror pattern as S3's
;   list_mirror). RedrawPartyMenu_'s .done mirrors once where pret re-enables
;   the transfer; PartyMenuAnimCB re-mirrors each input frame (live cursor).
; - Two window descriptors show it: the mon-list rows through UI_PARTY_PANEL
;   and the message rows through UI_MESSAGE_BOX (the standard dialog anchor).
;   The overworld behind them is blanked with g_bg_whiteout (pret's party
;   screen is a full-screen takeover on a white field).
; - Mon icons are pret's OAM sprites (engine/gfx/mon_icons.asm):
;   LoadMonPartySpriteGfxWithLCDDisabled loads the tile patterns into vSprites,
;   WriteMonPartySpriteOAMByPartyIndex writes 4 OBJ per mon, and AnimatePartyMon
;   (called per frame from HandleMenuInput_, as pret does) runs the bob. The port's
;   old BG-tile hack — icons parked in vTileset, frame-swapped by PartyMenuAnimCB,
;   right column baked as a mirror — is gone; see docs/plans/party_icons_oam.md.
;   PartyMenuMirror stays as menu_redraw_cb: it pushes the live cursor (a BG tile)
;   to the panel window each iteration, which the icons no longer need.
; - DEVIATION(text): the party message is drawn whole instead of PrintText's
;   typewriter reveal (engine far-text streams aren't GB-space assets yet;
;   S4 toss-dialog precedent).
; - VRAM restore on exit is the caller's (StartMenu_Pokemon .exitMenu): the
;   HP-bar/status set clobbers vChars2 box tiles, and the icons clobber the OBJ
;   tiles at vSprites — which is exactly what pret's
;   RestoreScreenTilesAndReloadTilePatterns → ReloadMapSpriteTilePatterns is for.
;
; Register map (CLAUDE.md): A=AL, BC=BX, DE=DX, HL=ESI, EBP = GB base.
;
; Build (standalone check):
;   nasm -f coff -I include/ -I . -o /dev/null src/engine/menus/party_menu.asm
; ---------------------------------------------------------------------------
bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_macros.inc"

%define UI_LAYOUT_EQUATES_ONLY 1
%include "assets/ui_layout_menus.inc"

global DrawPartyMenu_
global RedrawPartyMenu_
global SetPartyMenuHPBarColor
global PartyMenuMirror
global DrawHP
global DrawHP2

extern LoadMonPartySpriteGfxWithLCDDisabled  ; engine/gfx/mon_icons.asm
extern WriteMonPartySpriteOAMByPartyIndex    ; engine/gfx/mon_icons.asm
extern SetMonPartySpriteOrigin               ; engine/gfx/mon_icons.asm (port: OAM→canvas projection)
extern FillMemory                    ; home/fill_memory.asm — ESI=dest, BX=count, AL=value
extern UpdateSprites                 ; engine/overworld/movement.asm
extern GetPartyMonName               ; home/pokemon.asm — AL=index, ESI=base → wNameBuffer
extern PlaceString                   ; text/text.asm — ESI=dest, EAX=flat src
extern place_flat_str                ; text/text.asm — ESI=dest, EAX=flat src (no coord return)
extern TextBoxBorder                 ; text/text.asm — ESI=top-left, BL=int w, BH=int h
extern PrintStatusCondition          ; home/pokemon.asm — EDX=status addr, ESI=dest
extern DrawHPBar                     ; home/pokemon.asm — ESI=dest, DH=tiles, DL=px, BL=sliver
extern GetHPBarLength                ; engine/gfx/hp_bar.asm — BX=hp, DX=maxhp → DL=px
extern PrintNumber                   ; home/print_num.asm
extern PrintLevel                    ; home/pokemon.asm — ESI=dest, [wLoadedMonLevel]
extern LoadMonData                   ; engine/pokemon/load_mon_data.asm
extern ErasePartyMenuCursors         ; engine/menus/start_sub_menus.asm
extern GetHealthBarColor             ; home/fade.asm — DL=px, ESI=dest addr
extern set_single_window             ; ppu/ppu.asm
extern add_window
extern g_bg_whiteout
extern g_obj_over_window             ; ppu/ppu.asm — OBJ over the window layer (GB order)
extern Delay3                        ; video/frame.asm
extern GBPalNormal                   ; init/init.asm
extern TextCommandProcessor          ; home/text.asm — ESI=GB-space TX stream, EBX=cursor
; pret PartyMenuItemUseMessagePointers — the nine item-use result texts, generated
; into assets/item_text.inc (tools/gen_item_text.py) as {dd stream, dd length} pairs
; (the port needs the length to stage a stream in GB space; see .printItemUseMessage).
extern PartyMenuItemUseMessagePointers

GBSCR_W   equ 20        ; GB screen tile width (stride of the scratch)
TILE_SPC       equ 0x7F      ; blank space tile
CHAR_SWAP_CUR  equ 0xEC      ; ▷ (unfilled right arrow menu cursor)

section .data
align 4
; --- PartyMenuMessagePointers texts (pret data/text/text_3.asm wording; GB
; charmap: 'A'=$80/'a'=$A0, é=$BA, ' '=$7F, '.'=$E8, '?'=$E6, '@'=$50) --------
; "Choose a POKéMON."
pm_msg_normal1: db 0x82,0xA7,0xAE,0xAE,0xB2,0xA4,0x7F,0xA0,0x7F
                db 0x8F,0x8E,0x8A,0xBA,0x8C,0x8E,0x8D,0xE8, 0x50
; "Use item on which" / "POKéMON?"
pm_msg_item1:   db 0x94,0xB2,0xA4,0x7F,0xA8,0xB3,0xA4,0xAC,0x7F
                db 0xAE,0xAD,0x7F,0xB6,0xA7,0xA8,0xA2,0xA7, 0x50
pm_msg_mon_q:   db 0x8F,0x8E,0x8A,0xBA,0x8C,0x8E,0x8D,0xE6, 0x50
; "Bring out which" / (POKéMON?)
pm_msg_battle1: db 0x81,0xB1,0xA8,0xAD,0xA6,0x7F,0xAE,0xB4,0xB3,0x7F
                db 0xB6,0xA7,0xA8,0xA2,0xA7, 0x50
; "Teach to which" / (POKéMON?)
pm_msg_tm1:     db 0x93,0xA4,0xA0,0xA2,0xA7,0x7F,0xB3,0xAE,0x7F
                db 0xB6,0xA7,0xA8,0xA2,0xA7, 0x50
; "Move POKéMON" / "where?"
pm_msg_swap1:   db 0x8C,0xAE,0xB5,0xA4,0x7F,0x8F,0x8E,0x8A,0xBA,0x8C,0x8E,0x8D, 0x50
pm_msg_swap2:   db 0xB6,0xA7,0xA4,0xB1,0xA4,0xE6, 0x50

; line-1 / line-2 pointer pairs, indexed by wPartyMenuTypeOrMessageID
; (pret PartyMenuMessagePointers; entry 5 repeats ItemUse, as pret)
pm_msg_table:
    dd pm_msg_normal1, 0                 ; NORMAL_PARTY_MENU
    dd pm_msg_item1,   pm_msg_mon_q      ; USE_ITEM_PARTY_MENU
    dd pm_msg_battle1, pm_msg_mon_q      ; BATTLE_PARTY_MENU
    dd pm_msg_tm1,     pm_msg_mon_q      ; TMHM_PARTY_MENU
    dd pm_msg_swap1,   pm_msg_swap2      ; SWAP_MONS_PARTY_MENU
    dd pm_msg_item1,   pm_msg_mon_q      ; EVO_STONE_PARTY_MENU (pret aliases ItemUse)


section .text

; ---------------------------------------------------------------------------
; DrawPartyMenu_ — full draw: clear, load icon gfx, then RedrawPartyMenu_.
; pret ref: engine/menus/party_menu.asm:DrawPartyMenu_.
; ---------------------------------------------------------------------------
DrawPartyMenu_:
    ; xor a / ldh [hAutoBGTransferEnabled],a — port: the transfer analog is
    ; PartyMenuMirror, which simply isn't called until .done (nothing shows
    ; the half-drawn scratch), so pret's disable needs no state.
    ; call ClearScreen — port: title.asm's ClearScreen is canvas-scoped (and
    ; re-arms the canvas auto-transfer mid-draw); the party screen is the
    ; stride-20 scratch, whose 20×18 rows are the contiguous 360 bytes at
    ; W_TILEMAP — blanked directly.
    mov esi, W_TILEMAP
    mov bx, 18 * GBSCR_W
    mov al, TILE_SPC
    call FillMemory
    call UpdateSprites
    ; PORT: the icons are OBJ, and this screen is a window over a whited-out canvas,
    ; so tell mon_icons.asm where GB (0,0) lands: the panel window's anchor
    ; (docs/ui_projection.md — canvas x = WX - 7, y = WY).
    mov eax, UI_PARTY_PANEL_WX - 7
    mov ebx, UI_PARTY_PANEL_WY
    call SetMonPartySpriteOrigin
    call LoadMonPartySpriteGfxWithLCDDisabled ; farcall LoadMonPartySpriteGfxWithLCDDisabled
    ; fall through to RedrawPartyMenu_

; ---------------------------------------------------------------------------
; RedrawPartyMenu_ — redraw every entry (or just the message in swap mode).
; pret ref: engine/menus/party_menu.asm:RedrawPartyMenu_.
; ---------------------------------------------------------------------------
RedrawPartyMenu_:
    mov al, [ebp + wPartyMenuTypeOrMessageID]
    cmp al, SWAP_MONS_PARTY_MENU
    jz .printMessage                        ; jp z,.printMessage
    call ErasePartyMenuCursors
    ; farcall InitPartyMenuBlkPacket — TODO-HW: SGB palette BLK packet (Phase 5)
    mov esi, W_TILEMAP + 0 * GBSCR_W + 3 ; hlcoord 3,0
    mov edx, wPartySpecies                  ; ld de,wPartySpecies
    xor al, al
    mov bl, al                              ; ld c,a
    mov [ebp + hPartyMonIndex], al          ; ldh [hPartyMonIndex],a
    mov [ebp + wWhichPartyMenuHPBar], al
.loop:
    mov al, [ebp + edx]                     ; ld a,[de]
    cmp al, 0xFF                            ; reached the terminator?
    jz .afterDrawingMonEntries              ; jp z
    push ebx                                ; push bc
    push edx                                ; push de
    push esi                                ; push hl
    mov al, bl                              ; ld a,c
    push esi                                ; push hl
    mov esi, wPartyMonNicks                 ; ld hl,wPartyMonNicks
    call GetPartyMonName                    ; → wNameBuffer
    pop esi                                 ; pop hl
    lea eax, [ebp + wNameBuffer]            ; port: PlaceString src = flat ptr
    call PlaceString                        ; print the pokemon's name
    mov al, [ebp + hPartyMonIndex]          ; ldh a,[hPartyMonIndex]
    mov [ebp + wWhichPokemon], al
    ; STUB(pikachu-follow): IsThisPartyMonStarterPikachu +
    ; CheckPikachuFollowingPlayer (walking-pikachu OAM slot $ff) — the follower
    ; system is not ported; every mon takes the .regularMon path.
.regularMon:
    ; farcall WriteMonPartySpriteOAMByPartyIndex — place the appropriate pokemon
    ; icon (4 OBJ at the mon's row, from [hPartyMonIndex])
    call WriteMonPartySpriteOAMByPartyIndex
    mov al, [ebp + wWhichPokemon]
    inc al
    mov [ebp + hPartyMonIndex], al          ; ldh [hPartyMonIndex],a
    call LoadMonData
    pop esi                                 ; pop hl
    push esi                                ; push hl
    mov al, [ebp + wMenuItemToSwap]
    test al, al                             ; is the player swapping positions?
    jz .skipUnfilledRightArrow
    dec al
    mov ah, al                              ; ld b,a
    mov al, [ebp + wWhichPokemon]
    cmp al, ah                              ; swapping the current pokemon?
    jnz .skipUnfilledRightArrow
    ; the player is swapping the current pokemon in the list
    mov byte [ebp + esi - 3], CHAR_SWAP_CUR ; dec hl ×3 / ld [hli],'▷'
.skipUnfilledRightArrow:
    mov al, [ebp + wPartyMenuTypeOrMessageID] ; menu type
    cmp al, TMHM_PARTY_MENU
    jz .teachMoveMenu
    cmp al, EVO_STONE_PARTY_MENU
    jz .evolutionStoneMenu
    push esi                                ; push hl
    add esi, 14                             ; ld bc,14 / add hl,bc
    mov edx, wLoadedMonStatus               ; ld de,wLoadedMonStatus
    call PrintStatusCondition
    pop esi                                 ; pop hl
    push esi                                ; push hl
    add esi, GBSCR_W + 1               ; down 1 row, right 1 col
    or byte [ebp + H_UI_LAYOUT_FLAGS], 1 << BIT_PARTY_MENU_HP_BAR
    call DrawHP2                            ; predef DrawHP2
    and byte [ebp + H_UI_LAYOUT_FLAGS], (~(1 << BIT_PARTY_MENU_HP_BAR)) & 0xFF
    call SetPartyMenuHPBarColor             ; color the HP bar (on SGB)
    pop esi                                 ; pop hl
    jmp .printLevel
.teachMoveMenu:
    ; STUB(items-plan): TMHM_PARTY_MENU ("ABLE"/"NOT ABLE" via predef
    ; CanLearnTM) is reachable only from TM/HM item USE, which
    ; current_plan_items.md owns; the dispatch branch is kept.
    jmp .printLevel
.evolutionStoneMenu:
    ; STUB(items-plan): EVO_STONE_PARTY_MENU ("ABLE"/"NOT ABLE" from the mon's
    ; EvosMoves stone entries) is reachable only from evolution-stone USE.
    jmp .printLevel
.printLevel:
    add esi, 10                             ; move 10 columns to the right
    call PrintLevel                         ; [wLoadedMonLevel] via LoadMonData
    pop esi                                 ; pop hl
    pop edx                                 ; pop de
    inc edx                                 ; inc de
    add esi, 2 * GBSCR_W               ; ld bc,2*SCREEN_WIDTH / add hl,bc
    pop ebx                                 ; pop bc
    inc bl                                  ; inc c
    jmp .loop
.afterDrawingMonEntries:
    ; ld b,SET_PAL_PARTY_MENU / call RunPaletteCommand — TODO-HW: SGB/CGB
    ; palette command (Phase 5)
.printMessage:
    mov al, [ebp + W_STATUS_FLAGS_5]        ; ld hl,wStatusFlags5 / ld a,[hl]
    push eax                                ; push af
    or byte [ebp + W_STATUS_FLAGS_5], 1 << BIT_NO_TEXT_DELAY ; set [hl]
    mov al, [ebp + wPartyMenuTypeOrMessageID] ; message ID
    cmp al, FIRST_PARTY_MENU_TEXT_ID
    jae .printItemUseMessage
    ; DEVIATION(text): pret streams PartyMenuMessagePointers[id] through
    ; PrintText; the port draws the message whole (see header)
    call DrawPartyMenuMessage
.done:
    pop eax                                 ; pop af
    mov [ebp + W_STATUS_FLAGS_5], al        ; ld [hl],a
    ; ld a,1 / ldh [hAutoBGTransferEnabled],a — port: mirror the finished
    ; scratch to GB_TILEMAP1 (the windows' source) in one shot
    call PartyMenuMirror
    ; port(window model): (re)build the two party windows; a rebuilt list also
    ; drops any stale field-move pop-up window (pret's screen-buffer restore)
    call ShowPartyMenuWindows
    call Delay3
    jmp GBPalNormal                         ; jp GBPalNormal
.printItemUseMessage:
    ; pret ref: engine/menus/party_menu.asm:.printItemUseMessage — mask the id,
    ; index PartyMenuItemUseMessagePointers, load the used mon's nick into
    ; wNameBuffer (the streams' text_ram), and print.
    ;
    ; DEVIATION(text): pret's PrintText draws the message box itself; the port
    ; draws the border here and runs TextCommandProcessor at the box's cursor,
    ; writing into the party menu's own stride-20 scratch (which .done then
    ; mirrors to the window layer). The stream is copied into GB space first
    ; because TextCommandProcessor reads its stream EBP-relative — same staging
    ; ShowTextStream does for NPC dialogs. The caller set BIT_NO_TEXT_DELAY, so
    ; there is no per-letter reveal to composite; and every one of these nine
    ; texts terminates with <DONE>/text_end (never <PROMPT>), so nothing blocks
    ; before the mirror — ItemUseMedicine does the button wait afterwards.
    and al, 0x0F                            ; and $0F
    movzx eax, al
    mov ecx, [PartyMenuItemUseMessagePointers + eax * 8]      ; the stream
    mov edx, [PartyMenuItemUseMessagePointers + eax * 8 + 4]  ; its length
    push ecx
    push edx
    mov al, [ebp + wUsedItemOnWhichPokemon]
    mov esi, wPartyMonNicks
    call GetPartyMonName                    ; → wNameBuffer
    pop ecx                                 ; length
    pop esi                                 ; flat stream ptr
    push ecx
    lea edi, [ebp + NPC_DIALOG_BUF]
    rep movsb                               ; flat → GB WRAM
    pop ecx
    mov esi, W_TILEMAP + 12 * GBSCR_W       ; the standard dialog cell (0,12)
    mov bl, 18                              ; interior width  (total 20)
    mov bh, 4                               ; interior height (total 6)
    call TextBoxBorder
    mov ebx, W_TILEMAP + 14 * GBSCR_W + 1   ; bccoord 1,14 — TCP's cursor
    mov esi, NPC_DIALOG_BUF                  ; EBP-relative stream ptr
    call TextCommandProcessor
    jmp .done

; ---------------------------------------------------------------------------
; SetPartyMenuHPBarColor — store the current bar's color for the animation
; pacing (and, on SGB, recolor it — TODO-HW).
; pret ref: engine/menus/party_menu.asm:SetPartyMenuHPBarColor.
; In: DL = HP-bar pixels (DrawHP2's HPBarLength result survives in e, as pret).
; ---------------------------------------------------------------------------
SetPartyMenuHPBarColor:
    movzx eax, byte [ebp + wWhichPartyMenuHPBar]
    lea esi, [eax + wPartyMenuHPBarColors]  ; ld hl,wPartyMenuHPBarColors / add
    call GetHealthBarColor                  ; DL=pixels → [ebp+esi] = color
    ; ld b,SET_PAL_PARTY_MENU_HP_BARS / call RunPaletteCommand — TODO-HW:
    ; SGB palette command (Phase 5)
    inc byte [ebp + wWhichPartyMenuHPBar]   ; ld hl,… / inc [hl]
    ret

; ---------------------------------------------------------------------------
; DrawHP / DrawHP2 / DrawHP_ — HP bar + "cur/ max" fraction for the loaded mon.
; pret ref: engine/pokemon/status_screen.asm:DrawHP/DrawHP2/DrawHP_ — hosted
; here until pokemon_behavior's StatusScreen lands (that plan owns the file's
; port; the routines keep their pret names and move verbatim).
; In: ESI (hl) = bar position. Out: DL = bar pixels (pret leaves them in e).
; ---------------------------------------------------------------------------
DrawHP:
    ; call GetPredefRegisters — predef plumbing, collapsed in the flat port
    mov al, 1                               ; stats screen
    jmp DrawHP_
DrawHP2:
    ; call GetPredefRegisters
    mov al, 2                               ; party menu
DrawHP_:
    mov [ebp + wHPBarType], al
    push esi                                ; push hl
    mov bh, [ebp + wLoadedMonHP]            ; ld a,[wLoadedMonHP] / ld b,a
    mov bl, [ebp + wLoadedMonHP + 1]        ; ld c,a
    mov al, bl
    or al, bh                               ; or b
    jnz .nonzeroHP
    xor al, al                              ; xor a
    mov bl, al                              ; ld c,a — no sliver
    mov dl, al                              ; ld e,a — 0 pixels
    mov dh, 6                               ; ld d,$6
    jmp .drawHPBarAndPrintFraction
.nonzeroHP:
    mov dh, [ebp + wLoadedMonMaxHP]         ; ld a,[wLoadedMonMaxHP] / ld d,a
    mov dl, [ebp + wLoadedMonMaxHP + 1]     ; ld e,a
    call GetHPBarLength                     ; predef HPBarLength → DL = pixels
    mov dh, 6                               ; ld a,$6 / ld d,a
    mov bl, 6                               ; ld c,a — alive → force a sliver
.drawHPBarAndPrintFraction:
    pop esi                                 ; pop hl
    push edx                                ; push de
    push esi                                ; push hl
    push esi                                ; push hl
    call DrawHPBar
    pop esi                                 ; pop hl
    test byte [ebp + H_UI_LAYOUT_FLAGS], 1 << BIT_PARTY_MENU_HP_BAR
    jz .printFractionBelowBar
    add esi, 9                              ; ld bc,$9 — right of bar
    jmp .printFraction
.printFractionBelowBar:
    add esi, GBSCR_W + 1               ; below bar (stride-20 scratch)
.printFraction:
    push ebx
    mov edx, wLoadedMonHP                   ; ld de,wLoadedMonHP
    mov bh, 2                               ; 2 bytes
    mov bl, 3                               ; 3 digits
    call PrintNumber                        ; ESI advances past the field
    mov byte [ebp + esi], 0xF3              ; ld a,'/' / ld [hli],a
    inc esi
    mov edx, wLoadedMonMaxHP
    mov bh, 2
    mov bl, 3
    call PrintNumber
    pop ebx
    pop esi                                 ; pop hl
    pop edx                                 ; pop de — DL = bar pixels
    ret

; ---------------------------------------------------------------------------
; DrawPartyMenuMessage — message box border + PartyMenuMessagePointers[id]
; text, drawn whole into scratch rows 12-17 (DEVIATION(text), see header).
; The auto-transfer mirrors it to GB_TILEMAP1; UI_MESSAGE_BOX shows it.
; ---------------------------------------------------------------------------
DrawPartyMenuMessage:
    mov esi, W_TILEMAP + 12 * GBSCR_W  ; standard dialog cell (0,12)
    mov bl, 18                              ; interior width  (total 20)
    mov bh, 4                               ; interior height (total 6)
    call TextBoxBorder
    movzx eax, byte [ebp + wPartyMenuTypeOrMessageID]
    mov ecx, [pm_msg_table + eax * 8]       ; line 1
    mov edx, [pm_msg_table + eax * 8 + 4]   ; line 2 (0 = single-line)
    mov esi, W_TILEMAP + 14 * GBSCR_W + 1
    mov eax, ecx
    call place_flat_str
    test edx, edx
    jz .done
    mov esi, W_TILEMAP + 16 * GBSCR_W + 1
    mov eax, edx
    call place_flat_str
.done:
    ret

; ---------------------------------------------------------------------------
; ShowPartyMenuWindows — (re)build the party screen's window descriptors:
;   window 0 = the mon list: GB_TILEMAP1 rows 0-11 at the UI_PARTY_PANEL
;     anchor. PROJ menus: GB(0,0) 20x18 --(center/top)--> wx=87 wy=0 clip=160
;     [UI_PARTY_PANEL_*]; max_y is the mon rows only (12*8 px) — the message
;     rows 12-17 route to the dialog anchor below instead of the panel's
;     UI_PARTY_PANEL_MAXY, so they aren't shown twice.
;   window 1 = the message box: GB_TILEMAP1 rows 12-17 at the standard dialog
;     anchor. PROJ menus: GB(0,12) 20x6 --(center/bottom)--> wx=87 wy=152
;     clip=160 max_y=200 [UI_MESSAGE_BOX_*].
; Also raises g_bg_whiteout: pret's party screen is a full-screen takeover on
; a white field; the port blanks the 320×200 viewport around the windows.
; ---------------------------------------------------------------------------
ShowPartyMenuWindows:
    mov dword [g_bg_whiteout], 1
    ; The panel window covers the whole list, icons included — so the icon OBJ
    ; have to composite over it, as OBJ do over the window on the GB. (The port's
    ; default order paints the window last; see frame.asm.)
    mov dword [g_obj_over_window], 1
    mov eax, UI_PARTY_PANEL_WX
    mov ebx, UI_PARTY_PANEL_WY
    mov ecx, UI_PARTY_PANEL_CLIP
    mov edx, UI_PARTY_PANEL_WY + 12 * 8     ; mon rows 0-11 (see comment above)
    mov esi, GB_TILEMAP1
    xor edi, edi                            ; start_row = 0
    call set_single_window
    mov eax, UI_MESSAGE_BOX_WX
    mov ebx, UI_MESSAGE_BOX_WY
    mov ecx, UI_MESSAGE_BOX_CLIP
    mov edx, UI_MESSAGE_BOX_MAXY
    mov esi, GB_TILEMAP1
    mov edi, 12                             ; source row band 12-17
    call add_window
    ret

; ---------------------------------------------------------------------------
; PartyMenuMirror — blit the stride-20 scratch rows 0-17 → GB_TILEMAP1 rows
; 0-17 (the two party windows' source). The port's stand-in for pret's
; hAutoBGTransferEnabled VBlank transfer. Preserves all registers.
; ---------------------------------------------------------------------------
PartyMenuMirror:
    pushad
    xor ebx, ebx
.row:
    imul esi, ebx, GBSCR_W
    lea esi, [ebp + esi + W_TILEMAP]
    mov edi, ebx
    shl edi, 5                              ; ×32 tilemap stride
    lea edi, [ebp + edi + GB_TILEMAP1]
    mov ecx, GBSCR_W
    rep movsb
    inc ebx
    cmp ebx, 18
    jb .row
    popad
    ret
