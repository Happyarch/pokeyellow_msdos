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
; - DEVIATION(icons): pret renders mon icons as animated OAM sprites
;   (LoadMonPartySpriteGfxWithLCDDisabled + WriteMonPartySpriteOAMByPartyIndex
;   + the HandleMenuInput_ animation). The port draws them as BG tiles (2×2 at
;   cols 1-2) whose VRAM contents (assets/mon_icons.inc, vTileset tiles
;   PM_ICON_TILE_BASE+) are frame-swapped by PartyMenuAnimCB — the
;   menu_redraw_cb hook standing in for pret's in-loop AnimatePartyMon,
;   gated on wPartyMenuAnimMonEnabled and paced by wPartyMenuHPBarColors.
;   The icon tile data bakes the right half as a mirror of the left (the BG
;   layer has no per-tile X-flip); see assets/mon_icons.inc.
; - DEVIATION(text): the party message is drawn whole instead of PrintText's
;   typewriter reveal (engine far-text streams aren't GB-space assets yet;
;   S4 toss-dialog precedent).
; - VRAM restore on exit (tileset tiles clobbered by the icons, box tiles by
;   the HP-bar set) is the caller's: see StartMenu_Pokemon .exitMenu.
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
global PartyMenuAnimCB
global PartyMenuMirror
global DrawHP
global DrawHP2

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
extern Delay3                        ; video/frame.asm
extern GBPalNormal                   ; init/init.asm

GBSCR_W   equ 20        ; GB screen tile width (stride of the scratch)
TILE_SPC       equ 0x7F      ; blank space tile
CHAR_SWAP_CUR  equ 0xEC      ; ▷ (unfilled right arrow menu cursor)

; Mon-icon VRAM tiles: slot i uses 4 consecutive vTileset tiles (TL,TR,BL,BR)
; starting at PM_ICON_TILE_BASE + i*4; animation swaps the VRAM contents of
; the selected slot (the tilemap IDs stay fixed).
PM_ICON_TILE_BASE equ 0x01

section .data
align 4
; Mon-icon tile data + internal-index → ICON_* map (tools/gen_mon_icons_inc.py).
%include "assets/mon_icons.inc"

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

section .bss
align 4
pm_anim_ctr:    resd 1       ; vblank counter for the selected mon's icon bob
pm_anim_frame:  resd 1       ; 0/1 — current animation frame of the selected icon

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
    ; farcall LoadMonPartySpriteGfxWithLCDDisabled — DEVIATION(icons): BG-tile
    ; icon set loaded into vTileset instead of OAM sprite VRAM (see header)
    call LoadMonPartySpriteGfx
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
    ; farcall WriteMonPartySpriteOAMByPartyIndex — DEVIATION(icons): place the
    ; 2×2 BG icon tile IDs instead of OAM entries (see header)
    call WritePartyMonIconTiles             ; place the appropriate pokemon icon
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
    ; STUB(items-plan): PartyMenuItemUseMessagePointers (Antidote…RareCandy
    ; result texts, GetPartyMonName into the message) land with item USE
    ; dispatch; ids >= FIRST_PARTY_MENU_TEXT_ID are unreachable until then.
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
; WritePartyMonIconTiles — DEVIATION(icons): stands in for pret's
; WriteMonPartySpriteOAMByPartyIndex. Places the 2×2 icon tile IDs for party
; slot [wWhichPokemon] at scratch cols 1-2 of its name row + HP row; the
; VRAM contents behind those IDs are loaded by LoadMonPartySpriteGfx.
; Preserves all registers.
; ---------------------------------------------------------------------------
WritePartyMonIconTiles:
    push eax
    push edi
    movzx edi, byte [ebp + wWhichPokemon]
    mov eax, edi
    shl eax, 2
    add eax, PM_ICON_TILE_BASE              ; AL = TL tile id for this slot
    imul edi, edi, 2 * GBSCR_W         ; name row base (rows 0,2,4,…)
    mov [ebp + edi + W_TILEMAP + 1], al                     ; TL
    inc eax
    mov [ebp + edi + W_TILEMAP + 2], al                     ; TR
    inc eax
    mov [ebp + edi + W_TILEMAP + GBSCR_W + 1], al      ; BL
    inc eax
    mov [ebp + edi + W_TILEMAP + GBSCR_W + 2], al      ; BR
    pop edi
    pop eax
    ret

; ---------------------------------------------------------------------------
; LoadMonPartySpriteGfx — DEVIATION(icons): stands in for pret's
; LoadMonPartySpriteGfxWithLCDDisabled. Loads every party slot's icon
; (frame 0) into its 4 vTileset tiles and resets the animation state.
; Preserves all registers.
; ---------------------------------------------------------------------------
global LoadMonPartySpriteGfx            ; naming_screen.asm (menus S7 package C) externs it
LoadMonPartySpriteGfx:
    pushad
    mov dword [pm_anim_ctr], 0
    mov dword [pm_anim_frame], 0
    xor ebx, ebx                            ; slot
.slot:
    movzx eax, byte [ebp + wPartyCount]
    cmp ebx, eax
    jae .done
    mov eax, ebx
    xor edx, edx                            ; frame 0
    call LoadPartyMonIconFrame
    inc ebx
    jmp .slot
.done:
    popad
    ret

; ---------------------------------------------------------------------------
; LoadPartyMonIconFrame — copy one icon frame into a slot's vTileset tiles.
; In: EAX = party slot (0..5), EDX = frame (0/1).
; Clobbers EAX/ECX/EDX/ESI/EDI (EBX kept).
; ---------------------------------------------------------------------------
LoadPartyMonIconFrame:
    push eax                                ; save slot
    imul ecx, eax, PARTYMON_STRUCT_LENGTH
    movzx ecx, byte [ebp + ecx + wPartyMons + MON_SPECIES] ; internal index (1-based)
    dec ecx
    movzx ecx, byte [mon_icon_by_index + ecx] ; ICON_* id
    imul ecx, ecx, MON_ICON_BYTES           ; icon base in mon_icon_data
    mov eax, edx
    imul eax, eax, MON_ICON_FRAME_BYTES     ; + frame offset
    add ecx, eax
    lea esi, [mon_icon_data + ecx]          ; src = chosen frame's 4 tiles
    pop eax                                 ; slot
    shl eax, 2
    add eax, PM_ICON_TILE_BASE              ; first tile id of this slot
    shl eax, 4                              ; * TILE_SIZE → byte offset
    lea edi, [ebp + GB_VCHARS2 + eax]       ; dest = vTileset slot
    mov ecx, MON_ICON_FRAME_BYTES / 4
    rep movsd
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

; ---------------------------------------------------------------------------
; PartyMenuAnimCB — menu_redraw_cb hook: per-frame icon bob for the mon under
; the cursor + the live scratch→window mirror (the cursor the generic driver
; just drew must reach the panel window each frame).
; Stands in for pret HandleMenuInput_'s in-loop AnimatePartyMon: gated on
; wPartyMenuAnimMonEnabled, paced by the bar color the redraw stored in
; wPartyMenuHPBarColors[wCurrentMenuItem].
; DEVIATION(icons): frame periods 6/17/33 vblanks (green/yellow/red) — the
; established port cadence approximating pret's per-color animation delays.
; Preserves all registers.
; ---------------------------------------------------------------------------
PartyMenuAnimCB:
    call PartyMenuMirror
    pushad
    cmp byte [ebp + wPartyMenuAnimMonEnabled], 0
    jz .out
    movzx eax, byte [ebp + wCurrentMenuItem]
    movzx eax, byte [ebp + eax + wPartyMenuHPBarColors]
    mov ecx, 6                              ; green
    test al, al
    jz .havePeriod
    mov ecx, 17                             ; yellow
    cmp al, 1
    je .havePeriod
    mov ecx, 33                             ; red
.havePeriod:
    mov eax, [pm_anim_ctr]
    inc eax
    cmp eax, ecx
    jb .store
    mov edx, [pm_anim_frame]
    xor edx, 1                              ; toggle frame
    mov [pm_anim_frame], edx
    movzx eax, byte [ebp + wCurrentMenuItem]
    call LoadPartyMonIconFrame              ; reload the selected slot's VRAM
    xor eax, eax
.store:
    mov [pm_anim_ctr], eax
.out:
    popad
    ret
