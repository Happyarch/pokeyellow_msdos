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
; - The party message goes through pret's PrintText, over this screen's own msgbox
;   PROJECTION record (msgbox_party, below). Until 2026-07-13 it was drawn whole from
;   a hand-encoded charmap copy of the six messages, under a DEVIATION(text) claiming
;   "engine far-text streams aren't GB-space assets yet" — they had been generated and
;   linked all along (assets/item_text.inc), and the hand copy spelled out "POKéMON"
;   where pret writes the $54 POKé command. msgbox_party is also what ledger finding
;   M-29 asked for: the projection for "a message box over a full-screen menu".
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
global PartyMenuPrintText               ; home/pokemon.asm:HandlePartyMenuInput prints
                                        ; PartyMenuText_12cc through this screen's msgbox
global DrawHP
global DrawHP2

extern LoadMonPartySpriteGfxWithLCDDisabled  ; engine/gfx/mon_icons.asm
extern WriteMonPartySpriteOAMByPartyIndex    ; engine/gfx/mon_icons.asm
extern IsThisPartyMonStarterPikachu          ; engine/pikachu/pikachu_status.asm
extern CheckPikachuFollowingPlayer           ; engine/overworld/pikachu.asm
extern SetMonPartySpriteOrigin               ; engine/gfx/mon_icons.asm (port: OAM→canvas projection)
extern FillMemory                    ; home/fill_memory.asm — ESI=dest, BX=count, AL=value
extern UpdateSprites                 ; engine/overworld/movement.asm
extern GetPartyMonName               ; home/pokemon.asm — AL=index, ESI=base → wNameBuffer
extern PlaceString                   ; text/text.asm — ESI=dest, EAX=flat src
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
extern DelayFrame                    ; video/frame.asm
extern GBPalNormal                   ; init/init.asm
extern PrintText                     ; home/window.asm — ESI=FLAT TX stream ptr
extern text_msgbox                   ; home/text.asm — → the active msgbox projection
extern msgbox_dialog                 ; home/text.asm — the overworld default we restore
extern text_arrow_pos                ; home/text.asm — MB_ARROW, republished by PrintText
extern RunPaletteCommand             ; engine/battle/faint_switch.asm (palette-HAL stub)
extern CanLearnTM                    ; engine/items/tms.asm — → CL (0 = can't learn)
extern EvosMovesPointerTable         ; assets/evos_moves.inc — flat dd table of flat blobs
; pret PartyMenuMessagePointers streams — pret's own text_far bodies (data/text/
; text_3.asm), flattened into assets/item_text.inc by tools/gen_item_text.py.
extern PartyMenuNormalText
extern PartyMenuItemUseText
extern PartyMenuBattleText
extern PartyMenuUseTMText
extern PartyMenuSwapMonText
; pret PartyMenuItemUseMessagePointers — the nine item-use result texts, generated
; into assets/item_text.inc (tools/gen_item_text.py) as {dd stream, dd length} pairs
; (the port needs the length to stage a stream in GB space; see .printItemUseMessage).
extern PartyMenuItemUseMessagePointers

GBSCR_W   equ 20        ; GB screen tile width (stride of the scratch)
TILE_SPC       equ 0x7F      ; blank space tile
CHAR_SWAP_CUR  equ 0xEC      ; ▷ (unfilled right arrow menu cursor)
PM_ARROW_BLINK equ 20        ; ▼ blink half-period, frames (battle ARROW_BLINK)

; constants/palette_constants.asm (palette-HAL stub args, as start_sub_menus.asm does)
SET_PAL_PARTY_MENU          equ 0x0A
SET_PAL_PARTY_MENU_HP_BARS  equ 0xFC

section .data
align 4
; The TMHM / EVO_STONE learnability labels ("ABLE" / "NOT ABLE" — pret's four
; local .{not,}ableTo{LearnMove,Evolve}Text) are Tier-1 DATA, generated by
; tools/gen_menu_strings.py.
%include "assets/party_menu_strings.inc"

; ---------------------------------------------------------------------------
; PartyMenuMessagePointers — pret engine/menus/party_menu.asm:237. RedrawPartyMenu_
; indexes it with wPartyMenuTypeOrMessageID and PrintTexts the stream. A pointer
; table is code (Tier-2), so it is hand-written here; the STREAMS it points at are
; pret's own text_far bodies (data/text/text_3.asm), flattened into
; assets/item_text.inc by tools/gen_item_text.py — which already scans
; engine/menus/party_menu.asm and has been emitting these five labels, as globals,
; since it was written.
;
; Until 2026-07-13 this file ignored them and carried a hand-encoded charmap `db`
; copy of the same six messages (pm_msg_*), drawn whole by a bespoke
; DrawPartyMenuMessage instead of PrintText, behind a DEVIATION(text) claiming
; "engine far-text streams aren't GB-space assets yet". They were, and are. Worse,
; the hand copy re-made M-16's mistake: it spelled "POKéMON" as seven literal
; glyphs, where pret writes `#MON` — the $54 POKé text COMMAND — so it silently
; bypassed the handler this port implements. The generated streams carry $54.
PartyMenuMessagePointers:
    dd PartyMenuNormalText          ; NORMAL_PARTY_MENU
    dd PartyMenuItemUseText         ; USE_ITEM_PARTY_MENU
    dd PartyMenuBattleText          ; BATTLE_PARTY_MENU
    dd PartyMenuUseTMText           ; TMHM_PARTY_MENU
    dd PartyMenuSwapMonText         ; SWAP_MONS_PARTY_MENU
    dd PartyMenuItemUseText         ; EVO_STONE_PARTY_MENU (pret repeats ItemUse)

; ---------------------------------------------------------------------------
; msgbox_party — the party menu's message-box PROJECTION record (msgbox.inc).
;
; The screen is pret's 20×18 stride-20 scratch, shown through two windows, over a
; whited-out canvas. Neither existing projection fits it, and that gap is what
; ledger finding M-29 is about:
;   * msgbox_dialog (text.asm) has MB_WIN_TILEMAP = GB_TILEMAP1 with STARTROW 0, so
;     PrintText would set_single_window — COLLAPSING this screen's window list — and
;     paint the dialog into GB_TILEMAP1 rows 0-5, which are the party PANEL's rows.
;     That shared staging buffer is the bug: manual_text_scroll (text.asm:386) does
;     the same copy unconditionally on every <PROMPT>/<PARA>, and unlike
;     sync_dialog_window it is NOT gated on g_bg_whiteout.
;   * msgbox_centered (core.asm) has no window (good) but is stride-40 and draws
;     into the CANVAS — which g_bg_whiteout means we never composite. Invisible.
;
; So: stride-20, box in this screen's own scratch, NO window (the caller's two party
; windows survive), and MB_PROMPT = our own wait — which is the mechanism the record
; was built for, and which keeps <PROMPT> away from manual_text_scroll's rows 0-5.
; PartyMenuMirror carries the finished box to the window layer, as it already does
; for every other cell of this screen.
; ; PROJ menus: GB(0,12) 20×6 — same cells as pret; the projection is the window.
global msgbox_party
msgbox_party:
    dd GBSCR_W                              ; MB_STRIDE       — the stride-20 scratch
    dd W_TILEMAP + 12 * GBSCR_W             ; MB_BOX_OFS      — (0,12), as pret
    dd 18                                   ; MB_BOX_W        — 18 interior columns
    dd 4                                    ; MB_BOX_H        — 4 interior rows
    dd W_TILEMAP + 14 * GBSCR_W + 1         ; MB_LINE1        — pret bccoord 1,14
    dd W_TILEMAP + 16 * GBSCR_W + 1         ; MB_LINE2        — <LINE> at (1,16)
    dd W_TILEMAP + 16 * GBSCR_W + 18        ; MB_ARROW        — ▼ at (18,16)
    dd PartyMenuPromptWait                  ; MB_PROMPT       — our own wait
    dd 0                                    ; MB_WIN_WX       ] no window: the box is
    dd 0                                    ; MB_WIN_WY       ] drawn in the scratch
    dd 0                                    ; MB_WIN_CLIP     ] this screen already
    dd 0                                    ; MB_WIN_MAXY     ] mirrors, so the party
    dd 0                                    ; MB_WIN_TILEMAP  ] window list survives
    dd 0                                    ; MB_WIN_STARTROW ]


section .text

; ---------------------------------------------------------------------------
; DrawPartyMenu_ — full draw: clear, load icon gfx, then RedrawPartyMenu_.
; pret ref: engine/menus/party_menu.asm:DrawPartyMenu_.
; ---------------------------------------------------------------------------
DrawPartyMenu_:
    ; The port's transfer analog is PartyMenuMirror, which isn't called until .done,
    ; so nothing here shows a half-drawn scratch — but pret's write is kept anyway
    ; (M-24's precedent, row 9). hAutoBGTransferEnabled is currently WRITE-ONLY in the
    ; port: do_bg_transfer was deleted (frame.asm:126, the OW-A.13 corruption family)
    ; and no reader replaced it. Every other screen still writes it as pret does; a
    ; screen that quietly stops is how the flag's state drifts from pret's.
    mov byte [ebp + hAutoBGTransferEnabled], 0  ; xor a / ldh [hAutoBGTransferEnabled],a
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
    ; If this row IS our starter Pikachu and it is out walking with us, the icon is
    ; the follower's, not a party icon: hPartyMonIndex := $ff selects that path in
    ; WriteMonPartySpriteOAMByPartyIndex (mon_icons.asm:.saveOAM), which was already
    ; ported and simply unreachable. (The comment here used to claim "the follower
    ; system is not ported" — false: both routines below are translated and linked.)
    ; Both calls clobber bc/de/hl exactly as pret's callfar does; the values live on
    ; the stack from the top of .loop.
    call IsThisPartyMonStarterPikachu       ; callfar — CF set iff it's OUR Pikachu
    jnc .regularMon
    call CheckPikachuFollowingPlayer        ; ZF=1 iff it is NOT following us
    jz .regularMon
    mov byte [ebp + hPartyMonIndex], 0xFF   ; ld a,$ff / ldh [hPartyMonIndex],a
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
; Both learnability columns were STUB(items-plan) — "reachable only from TM/HM item
; USE / evolution-stone USE, which current_plan_items.md owns". Reachability is not a
; blocker, and nothing was blocking: CanLearnTM (engine/items/tms.asm) and
; EvosMovesPointerTable (assets/evos_moves.inc) are both translated AND linked in the
; current build. The stubs cost every TMHM/EVO_STONE party menu its whole right-hand
; column — the one thing those two menus exist to show.
.teachMoveMenu:
    push esi                                ; push hl
    call CanLearnTM                         ; predef CanLearnTM → CL = 0 (can't learn)
    pop esi                                 ; pop hl
    mov eax, pm_str_able                    ; ld de,.ableToLearnMoveText
    test cl, cl                             ; ld a,c / and a
    jnz .placeMoveLearnabilityString
    mov eax, pm_str_not_able                ; ld de,.notAbleToLearnMoveText
.placeMoveLearnabilityString:
    push esi                                ; push hl
    add esi, GBSCR_W + 9                    ; ld bc,20+9 — down 1 row, right 9 cols
    call PlaceString
    pop esi                                 ; pop hl
    jmp .printLevel
.evolutionStoneMenu:
    ; pret copies the mon's EvosMoves blob into wEvoDataBuffer with two FarCopyData
    ; calls (it has to: the table is in another bank). The port's EvosMovesPointerTable
    ; is a flat dd table of flat blobs, so the entries are walked in place — same scan,
    ; same terminator, same 3-byte / 4-byte (EVOLVE_ITEM) entry stride, no staging copy.
    push esi                                ; push hl
    movzx eax, byte [ebp + wLoadedMonSpecies]
    dec eax                                 ; dec a — table is 0-based
    mov edi, [EvosMovesPointerTable + eax * 4]
    mov eax, pm_str_not_able                ; ld de,.notAbleToEvolveText
.checkEvolutionsLoop:
    mov cl, [edi]                           ; ld a,[hli] — entry type
    test cl, cl                             ; and a — reached terminator?
    jz .placeEvolutionStoneString           ; if so, place the "NOT ABLE" string
    cmp cl, EVOLVE_ITEM
    jnz .nextEvoEntry                       ; jr nz,.checkEvolutionsLoop (3-byte entry)
    ; a stone evolution entry: [+1] = the stone it needs, and it is 4 bytes long
    mov cl, [edi + 1]                       ; ld b,[hl]
    add edi, 4
    cmp [ebp + wEvoStoneItemID], cl         ; cp b — the stone the player used?
    jnz .checkEvolutionsLoop
    mov eax, pm_str_able                    ; ld de,.ableToEvolveText
    jmp .placeEvolutionStoneString
.nextEvoEntry:
    add edi, 3
    jmp .checkEvolutionsLoop
.placeEvolutionStoneString:
    pop esi                                 ; pop hl
    push esi                                ; push hl
    add esi, GBSCR_W + 9                    ; ld bc,20+9 — down 1 row, right 9 cols
    call PlaceString
    pop esi                                 ; pop hl
    ; fall through to .printLevel (pret: jr .printLevel)
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
    ; The call was dropped behind "TODO-HW: SGB/CGB palette command (Phase 5)". The
    ; PALETTE is Phase 5; the CALL is not. RunPaletteCommand is a linked global (a
    ; ret-only palette-HAL stub in faint_switch.asm) and six other screens — status,
    ; naming, pokédex, league PC, battle send-out, the trainer card — all call it
    ; today. Only this screen skipped it, so the day the HAL lands the party menu
    ; would have been the one screen with no palette. Restored.
    mov bh, SET_PAL_PARTY_MENU              ; ld b, SET_PAL_PARTY_MENU
    call RunPaletteCommand
.printMessage:
    mov al, [ebp + W_STATUS_FLAGS_5]        ; ld hl,wStatusFlags5 / ld a,[hl]
    push eax                                ; push af
    or byte [ebp + W_STATUS_FLAGS_5], 1 << BIT_NO_TEXT_DELAY ; set [hl]
    mov al, [ebp + wPartyMenuTypeOrMessageID] ; message ID
    cmp al, FIRST_PARTY_MENU_TEXT_ID
    jae .printItemUseMessage
    movzx eax, al                           ; add a / ld hl,PartyMenuMessagePointers
    mov esi, [PartyMenuMessagePointers + eax * 4]   ; ld a,[hli] / ld h,[hl] / ld l,a
    call PartyMenuPrintText                 ; call PrintText (through our projection)
.done:
    pop eax                                 ; pop af
    mov [ebp + W_STATUS_FLAGS_5], al        ; ld [hl],a
    mov byte [ebp + hAutoBGTransferEnabled], 1  ; ld a,1 / ldh [hAutoBGTransferEnabled],a
    ; …and do what that flag means here: mirror the finished scratch to GB_TILEMAP1
    ; (the two windows' source) in one shot. See DrawPartyMenu_ on the dead flag.
    call PartyMenuMirror
    ; port(window model): (re)build the two party windows; a rebuilt list also
    ; drops any stale field-move pop-up window (pret's screen-buffer restore)
    call ShowPartyMenuWindows
    call Delay3
    jmp GBPalNormal                         ; jp GBPalNormal
.printItemUseMessage:
    ; pret ref: engine/menus/party_menu.asm:.printItemUseMessage — mask the id,
    ; index PartyMenuItemUseMessagePointers, load the used mon's nick into
    ; wNameBuffer (the streams' text_ram operand), and PrintText.
    ;
    ; This used to hand-draw the border and run TextCommandProcessor at the box's
    ; cursor, under a DEVIATION(text) whose stated reason — "every one of these nine
    ; texts terminates with <DONE>/text_end (never <PROMPT>), so nothing blocks" —
    ; is false: RareCandyText is `text_far / sound_get_item_1 / text_promptbutton /
    ; text_end` (pret line 297), and the generated stream ends $0B $06 $50 — a sound
    ; command and a PROMPT. Open-coding the printer meant that prompt was never
    ; dispatched. It goes through PrintText now, like every other message in the game.
    and al, 0x0F                            ; and $0F
    movzx eax, al
    mov ecx, [PartyMenuItemUseMessagePointers + eax * 8]      ; the stream (flat)
    push ecx                                ; push hl
    mov al, [ebp + wUsedItemOnWhichPokemon]
    mov esi, wPartyMonNicks
    call GetPartyMonName                    ; → wNameBuffer
    pop esi                                 ; pop hl — the stream
    call PartyMenuPrintText
    jmp .done

; ---------------------------------------------------------------------------
; PartyMenuPrintText — pret's `call PrintText`, through this screen's projection.
; In: ESI = flat text-command stream.
;
; text_msgbox is global mutable state, so the record is selected around the call
; and restored to the overworld default afterwards: leaving it pointed here would
; re-project the next overworld dialog into a scratch nothing is mirroring. (The
; alternative — hold it for the screen's lifetime — would have to be un-held by the
; screen's exit path, which lives in another file. Scoping it to the call keeps the
; whole projection decision inside the screen that makes it.)
; ---------------------------------------------------------------------------
PartyMenuPrintText:
    mov dword [text_msgbox], msgbox_party
    call PrintText
    mov dword [text_msgbox], msgbox_dialog
    ret

; ---------------------------------------------------------------------------
; PartyMenuPromptWait — msgbox_party's MB_PROMPT hook: blink the ▼ at
; [text_arrow_pos] and wait for A/B, mirroring the scratch each frame so the arrow
; is actually on screen. Modelled on battle's BattlePromptWait (core.asm:569), which
; exists for the same reason: the default (text_prompt_hook == 0) is
; manual_text_scroll, and manual_text_scroll HIJACKS the window layer — it copies
; the scratch's dialog rows into GB_TILEMAP1 rows 0-5 and forces the overworld
; dialog's WX/WY. Those rows are this screen's mon-list panel. See M-29.
; All registers preserved (the caller is mid-stream).
; ---------------------------------------------------------------------------
PartyMenuPromptWait:
    pushad
    mov esi, [text_arrow_pos]
    mov byte [ebp + esi], CHAR_DOWN_ARROW
    mov ecx, PM_ARROW_BLINK
.wait:
    call PartyMenuMirror                    ; the ▼ lives in the scratch; show it
    call DelayFrame
    test byte [ebp + H_JOY_PRESSED], PAD_A | PAD_B
    jnz .done
    dec ecx
    jnz .wait
    mov ecx, PM_ARROW_BLINK                 ; blink toggle
    cmp byte [ebp + esi], CHAR_DOWN_ARROW
    jne .turnOn
    mov byte [ebp + esi], TILE_SPC
    jmp .wait
.turnOn:
    mov byte [ebp + esi], CHAR_DOWN_ARROW
    jmp .wait
.done:
    mov byte [ebp + esi], TILE_SPC          ; erase the ▼
    call PartyMenuMirror
    popad
    ret

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
    mov bh, SET_PAL_PARTY_MENU_HP_BARS      ; ld b, SET_PAL_PARTY_MENU_HP_BARS
    call RunPaletteCommand                  ; (palette-HAL stub — see .afterDrawingMonEntries)
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
