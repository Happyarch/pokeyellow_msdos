; pc.asm — the generic PC integration spine (menus-port Session 9). Faithful
; port of pret engine/menus/pc.asm: ActivatePC (the overworld Poké-Center PC
; script target) + PCMainMenu (the BILL's / player's / OAK's / league / LOG OFF
; selector) + its dispatch to the per-PC screens ported in Sessions 6-8:
;   .playersPC → PlayerPC       (package F, players_pc.asm)
;   OaksPC     → OpenOaksPC      (package A, oaks_pc.asm)
;   PKMNLeague → PKMNLeaguePC    (package A, league_pc.asm)
;   BillsPC    → BillsPC_        (SEAM STUB — pokemon_behavior Stage 6 owns the
;                                 real box UI; DisplayPCMainMenu is the same seam)
;
; SEAMS (pc_stubs.asm; deleted when pokemon_behavior Stage 6 lands them):
;   DisplayPCMainMenu — draws the PC main menu box + sets the menu vars.
;   BillsPC_          — Bill's #MON-storage box UI.
; The menus plan out-of-scope rule ("stub the seams, never touch its files")
; forbids porting these into bills_pc.asm here; the spine externs them so the
; whole PCMainMenu control flow links and is exercisable today, going fully live
; when the real routines replace the stubs (the S7 "real X replaced stub" pattern).
;
; PORT MODEL (CLAUDE.md + players_pc.asm/oaks_pc.asm precedent):
;  * SM83→x86: A=AL, BC=BX, DE=DX, HL=ESI, EBP = GB base; GB memory at [EBP+sym].
;  * SaveScreenTilesToBuffer2 / LoadScreenTilesFromBuffer2 → window-model save /
;    restore of g_window_count (the overworld map underneath is never touched by a
;    window overlay, so there is nothing to snapshot but the window list).
;  * Dialog text: pret prints each message with PrintText. PrintText_Overworld
;    collapses the window list (would hide any menu), so — as in S4-S8 — the PC
;    messages are DRAWN WHOLE into the stride-20 W_TILEMAP scratch (rows 12-17) +
;    a GB_TILEMAP1 window at UI_MESSAGE_BOX, pret wording (data/text/text_3.asm),
;    with each `prompt`/`para` reproduced as a ▼ + A/B wait. DEVIATION(text).
;  * PlaySound / WaitForSoundToFinish (SFX_TURN_ON/OFF_PC, SFX_ENTER_PC) are
;    ; TODO-HW: audio HAL (Phase 3) — no-ops (no return-contract impact).
;
; Build (standalone check):
;   nasm -f coff -I include/ -I . -o /dev/null src/engine/menus/pc.asm
; ---------------------------------------------------------------------------
bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "assets/event_constants.inc"    ; EVENT_MET_BILL
%include "events.inc"                     ; CheckEvent (clobbers AL, sets ZF)

%define UI_LAYOUT_EQUATES_ONLY 1
%include "assets/ui_layout_menus.inc"

global ActivatePC
global PCMainMenu
global RemoveItemByID

extern DisplayPCMainMenu             ; pc_stubs.asm SEAM (pokemon_behavior S6)
extern BillsPC_                      ; pc_stubs.asm SEAM (pokemon_behavior S6)
extern PlayerPC                      ; engine/menus/players_pc.asm (package F)
extern OpenOaksPC                    ; engine/menus/oaks_pc.asm    (package A)
extern PKMNLeaguePC                  ; engine/menus/league_pc.asm  (package A)

extern HandleMenuInput               ; home/window.asm — Out: AL = watched keys pressed
extern ReloadMapData                 ; home/reload_tiles.asm
extern UpdateSprites                 ; engine/overworld/movement.asm
extern Delay3                        ; video/frame.asm
extern DelayFrame                    ; video/frame.asm
extern TextBoxBorder                 ; text/text.asm — ESI=top-left, BL=int_w, BH=int_h
extern place_flat_str                ; text/text.asm — ESI=dest, EAX=flat '@'-term src (ESI advances)
extern add_window                    ; ppu/ppu.asm
extern g_window_count                ; ppu/ppu.asm

; RemoveItemByID (unchanged from the original port stub; hItemToRemove* are hram
; equs in gb_memmap.inc, not externs)
extern wBagItems
extern wItemQuantity
extern wWhichPokemon
extern wNumBagItems
extern RemoveItemFromInventory

; charmap glyphs
PC_TERM   equ 0x50                    ; '@' string terminator
PC_DOWN   equ 0xEE                    ; ▼ text-prompt arrow
PC_SPC    equ 0x7F                    ; blank tile
PC_STRIDE equ 20                      ; drawn-whole scratch stride
MSG_SROW  equ 12                      ; first scratch row of the message border

; ===========================================================================
section .data
align 4
; pret data/text/text_3.asm wording, GB charmap ('@'-terminated). Control codes
; are expanded to literal tiles for the drawn-whole placer (# → POKé literal
; 0x8F,0x8E,0x8A,0xBA; <PLAYER> → the wPlayerName buffer, placed separately).
s_turnedon:  db 0x7F,0xB3,0xB4,0xB1,0xAD,0xA4,0xA3,0x7F,0xAE,0xAD, PC_TERM                          ; " turned on"
s_thepc:     db 0xB3,0xA7,0xA4,0x7F,0x8F,0x82,0xE8, PC_TERM                                         ; "the PC."
s_accmypc:   db 0x80,0xA2,0xA2,0xA4,0xB2,0xB2,0xA4,0xA3,0x7F,0xAC,0xB8,0x7F,0x8F,0x82,0xE8, PC_TERM ; "Accessed my PC."
s_accitem:   db 0x80,0xA2,0xA2,0xA4,0xB2,0xB2,0xA4,0xA3,0x7F,0x88,0xB3,0xA4,0xAC, PC_TERM           ; "Accessed Item"
s_storesys:  db 0x92,0xB3,0xAE,0xB1,0xA0,0xA6,0xA4,0x7F,0x92,0xB8,0xB2,0xB3,0xA4,0xAC,0xE8, PC_TERM ; "Storage System."
s_accbills:  db 0x80,0xA2,0xA2,0xA4,0xB2,0xB2,0xA4,0xA3,0x7F,0x81,0x88,0x8B,0x8B,0xBD, PC_TERM      ; "Accessed BILL's"
s_pcdot:     db 0x8F,0x82,0xE8, PC_TERM                                                             ; "PC."
s_accpkmn:   db 0x80,0xA2,0xA2,0xA4,0xB2,0xB2,0xA4,0xA3,0x7F,0x8F,0x8E,0x8A,0xBA,0x8C,0x8E,0x8D, PC_TERM ; "Accessed POKéMON"
s_accsome:   db 0x80,0xA2,0xA2,0xA4,0xB2,0xB2,0xA4,0xA3,0x7F,0xB2,0xAE,0xAC,0xA4,0xAE,0xAD,0xA4,0xBD, PC_TERM ; "Accessed someone's"
s_empty:     db PC_TERM

section .bss
align 4
pc_saved_wc: resd 1                   ; g_window_count at the start of a message

; ===========================================================================
section .text

; ---------------------------------------------------------------------------
; ActivatePC — pret ref: engine/menus/pc.asm:ActivatePC.
; Overworld Poké-Center PC script target. In: EBP = GB base.
; ---------------------------------------------------------------------------
ActivatePC:
    ; call SaveScreenTilesToBuffer2 — port(window model): snapshot the window
    ; list so the turn-on dialog can be dropped without disturbing the map.
    mov eax, [g_window_count]
    mov [pc_saved_wc], eax
    ; TODO-HW: PlaySound SFX_TURN_ON_PC — audio HAL (Phase 3)
    ; ld hl, TurnedOnPC1Text / call PrintText — "<PLAYER> turned on / the PC." (prompt)
    call PC_TurnedOnPC1Text
    ; TODO-HW: WaitForSoundToFinish — audio HAL (Phase 3)
    or byte [ebp + wMiscFlags], (1 << BIT_USING_GENERIC_PC)   ; set BIT_USING_GENERIC_PC
    ; call LoadScreenTilesFromBuffer2 — port(window model): drop the turn-on
    ; dialog window (the map underneath is untouched).
    mov eax, [pc_saved_wc]
    mov [g_window_count], eax
    call Delay3
    ; fall through to PCMainMenu

; ---------------------------------------------------------------------------
; PCMainMenu — pret ref: engine/menus/pc.asm:PCMainMenu.
; Draws the PC main menu (seam), runs HandleMenuInput, dispatches by the menu
; layout ([wMaxMenuItem]) and selection ([wCurrentMenuItem]).
; ---------------------------------------------------------------------------
PCMainMenu:
    call DisplayPCMainMenu                    ; farcall — SEAM (draws menu, sets wMaxMenuItem)
    or byte [ebp + wMiscFlags], (1 << BIT_NO_MENU_BUTTON_SOUND)  ; set BIT_NO_MENU_BUTTON_SOUND
    call HandleMenuInput
    test al, PAD_B                            ; bit B_PAD_B,a
    jnz LogOff                                ; jp nz
    mov al, [ebp + wMaxMenuItem]
    cmp al, 2
    jnz .next                                 ; jr nz — not 2 items (pre-Pokédex)
    mov al, [ebp + wCurrentMenuItem]
    test al, al                               ; and a
    jz BillsPC                                ; jp z — 0 = BILL's PC
    cmp al, 1
    jz .playersPC                             ; jr z — 1 = player's PC
    jmp LogOff                                ; otherwise (2) = LOG OFF
.next:
    cmp al, 3                                 ; al still = wMaxMenuItem
    jnz .next2                                ; jr nz — not 3 items (Pokédex, pre-league)
    mov al, [ebp + wCurrentMenuItem]
    test al, al                               ; and a
    jz BillsPC                                ; jp z
    cmp al, 1
    jz .playersPC                             ; jr z
    cmp al, 2
    jz OaksPC                                 ; jp z — 2 = OAK's PC
    jmp LogOff                                ; otherwise (3) = LOG OFF
.next2:
    mov al, [ebp + wCurrentMenuItem]
    test al, al                               ; and a
    jz BillsPC                                ; jp z
    cmp al, 1
    jz .playersPC                             ; jr z
    cmp al, 2
    jz OaksPC                                 ; jp z
    cmp al, 3
    jz PKMNLeague                             ; jp z — 3 = league PC
    jmp LogOff                                ; otherwise (4) = LOG OFF
.playersPC:
    and byte [ebp + wMiscFlags], (~(1 << BIT_NO_MENU_BUTTON_SOUND)) & 0xFF  ; res BIT_NO_MENU_BUTTON_SOUND
    or  byte [ebp + wMiscFlags], (1 << BIT_USING_GENERIC_PC)                 ; set BIT_USING_GENERIC_PC
    ; TODO-HW: PlaySound SFX_ENTER_PC / WaitForSoundToFinish — audio HAL
    ; ld hl, AccessedMyPCText / call PrintText — "Accessed my PC. / Item Storage" (prompt)
    call PC_AccessedMyPCText
    call PlayerPC                             ; farcall PlayerPC (package F)
    jmp ReloadMainMenu                        ; jr ReloadMainMenu

OaksPC:
    ; TODO-HW: PlaySound SFX_ENTER_PC / WaitForSoundToFinish — audio HAL
    call OpenOaksPC                           ; farcall OpenOaksPC (package A)
    jmp ReloadMainMenu                        ; jr ReloadMainMenu

PKMNLeague:
    ; TODO-HW: PlaySound SFX_ENTER_PC / WaitForSoundToFinish — audio HAL
    call PKMNLeaguePC                         ; farcall PKMNLeaguePC (package A)
    jmp ReloadMainMenu                        ; jr ReloadMainMenu

BillsPC:
    ; TODO-HW: PlaySound SFX_ENTER_PC / WaitForSoundToFinish — audio HAL
    CheckEvent EVENT_MET_BILL                 ; ZF=0 → met Bill (event SET)
    jnz .billsPC                              ; jr nz
    ; ld hl, AccessedSomeonesPCText — "Accessed someone's PC."
    call PC_AccessedSomeonesPCText
    jmp .afterText                            ; jr .printText → after the drawn-whole text
.billsPC:
    ; ld hl, AccessedBillsPCText — "Accessed BILL's PC."
    call PC_AccessedBillsPCText
.afterText:
    call BillsPC_                             ; farcall BillsPC_ — SEAM (pokemon_behavior S6)
    ; fall through to ReloadMainMenu

ReloadMainMenu:
    xor al, al
    mov [ebp + wDoNotWaitForButtonPressAfterDisplayingText], al
    call ReloadMapData
    call UpdateSprites
    jmp PCMainMenu                            ; jp PCMainMenu

LogOff:
    ; TODO-HW: PlaySound SFX_TURN_OFF_PC / WaitForSoundToFinish — audio HAL
    and byte [ebp + wMiscFlags], (~(1 << BIT_USING_GENERIC_PC)) & 0xFF       ; res BIT_USING_GENERIC_PC
    and byte [ebp + wMiscFlags], (~(1 << BIT_NO_MENU_BUTTON_SOUND)) & 0xFF   ; res BIT_NO_MENU_BUTTON_SOUND
    ret

; ===========================================================================
; Drawn-whole dialog plumbing (DEVIATION(text) — see file header; mirrors
; oaks_pc.asm's oak_* / players_pc.asm's pc_msg_* helpers). Each message opens
; (snapshots the window list), draws one or more pages (border + lines into the
; stride-20 scratch rows 12-17 → GB_TILEMAP1 window at UI_MESSAGE_BOX), waits a
; ▼ + A/B cycle per `para`/`prompt`, then closes (restores the window list).
; ===========================================================================

; snapshot g_window_count for this message
pc_msg_open:
    mov eax, [g_window_count]
    mov [pc_saved_wc], eax
    ret

; restore the window list (drops the message window). Clobbers EAX.
pc_msg_close:
    mov eax, [pc_saved_wc]
    mov [g_window_count], eax
    ret

; draw the empty message border into scratch rows 12-17 (interior 18x4, total 20x6)
pc_msg_border:
    mov esi, W_TILEMAP + MSG_SROW * PC_STRIDE
    mov bl, 18
    mov bh, 4
    call TextBoxBorder
    ret

; mirror scratch rows 12-17 → GB_TILEMAP1 rows 0-5 (pad cols 20-31), then (re)show
; exactly one message window at UI_MESSAGE_BOX (reset to pc_saved_wc so successive
; pages replace rather than stack). Preserves nothing needed by callers.
pc_msg_show:
    pushad
    mov ecx, 6
    lea esi, [ebp + W_TILEMAP + MSG_SROW * PC_STRIDE]
    lea edi, [ebp + GB_TILEMAP1]
.row:
    push ecx
    push edi
    mov ecx, 20
    rep movsb
    mov al, PC_SPC
    mov ecx, 12                               ; pad cols 20-31
    rep stosb
    pop edi
    pop ecx
    add edi, 32
    dec ecx
    jnz .row
    mov eax, [pc_saved_wc]                     ; drop any prior page's window
    mov [g_window_count], eax
    mov eax, UI_MESSAGE_BOX_WX
    mov ebx, UI_MESSAGE_BOX_WY
    mov ecx, UI_MESSAGE_BOX_CLIP
    mov edx, UI_MESSAGE_BOX_MAXY
    mov esi, GB_TILEMAP1
    xor edi, edi
    call add_window
    popad
    ret

; draw a two-line page: EAX = line-1 flat str, EDX = line-2 flat str (s_empty for
; a one-line page). Then show the window.
pc_msg_page:
    push edx
    call pc_msg_border
    pop edx
    push edx
    mov esi, W_TILEMAP + 14 * PC_STRIDE + 1
    call place_flat_str                        ; EAX = line 1
    pop eax
    mov esi, W_TILEMAP + 16 * PC_STRIDE + 1
    call place_flat_str                        ; EAX = line 2
    call pc_msg_show
    ret

; ▼ + wait for an A/B press cycle (a text `para`/`prompt`), then clear the ▼.
pc_prompt:
    mov byte [ebp + GB_TILEMAP1 + DIALOG_ARROW_TILEMAP_OFFSET], PC_DOWN
.release:
    call DelayFrame
    test byte [ebp + H_JOY_HELD], PAD_A | PAD_B
    jnz .release
.press:
    call DelayFrame
    test byte [ebp + H_JOY_HELD], PAD_A | PAD_B
    jz .press
    mov byte [ebp + GB_TILEMAP1 + DIALOG_ARROW_TILEMAP_OFFSET], PC_SPC
    ret

; --- the four PC dialogs (pret data/text/text_3.asm) ---

; TurnedOnPC1Text: "<PLAYER> turned on" / "the PC." (prompt)
PC_TurnedOnPC1Text:
    call pc_msg_open
    call pc_msg_border
    lea eax, [ebp + W_PLAYER_NAME]             ; <PLAYER>
    mov esi, W_TILEMAP + 14 * PC_STRIDE + 1
    call place_flat_str                        ; ESI advances past the name
    mov eax, s_turnedon
    call place_flat_str                        ; " turned on" on the same line
    mov esi, W_TILEMAP + 16 * PC_STRIDE + 1
    mov eax, s_thepc
    call place_flat_str
    call pc_msg_show
    call pc_prompt
    call pc_msg_close
    ret

; AccessedMyPCText: "Accessed my PC." <para> "Accessed Item" / "Storage System." (prompt)
PC_AccessedMyPCText:
    call pc_msg_open
    mov eax, s_accmypc
    mov edx, s_empty
    call pc_msg_page
    call pc_prompt                             ; para page break
    mov eax, s_accitem
    mov edx, s_storesys
    call pc_msg_page
    call pc_prompt                             ; terminal prompt
    call pc_msg_close
    ret

; AccessedBillsPCText: "Accessed BILL's" / "PC." <para> "Accessed #MON" / "Storage System." (prompt)
PC_AccessedBillsPCText:
    call pc_msg_open
    mov eax, s_accbills
    mov edx, s_pcdot
    call pc_msg_page
    call pc_prompt
    mov eax, s_accpkmn
    mov edx, s_storesys
    call pc_msg_page
    call pc_prompt
    call pc_msg_close
    ret

; AccessedSomeonesPCText: "Accessed someone's" / "PC." <para> "Accessed #MON" / "Storage System." (prompt)
PC_AccessedSomeonesPCText:
    call pc_msg_open
    mov eax, s_accsome
    mov edx, s_pcdot
    call pc_msg_page
    call pc_prompt
    mov eax, s_accpkmn
    mov edx, s_storesys
    call pc_msg_page
    call pc_prompt
    call pc_msg_close
    ret

; ---------------------------------------------------------------------------
; RemoveItemByID — pret ref: engine/menus/pc.asm:RemoveItemByID.
; removes one of the specified item ID [hItemToRemoveID] from bag (if existent).
; Unchanged from the original port stub.
; ---------------------------------------------------------------------------
RemoveItemByID:
    mov esi, wBagItems
    mov bl, [ebp + hItemToRemoveID]
    xor al, al
    mov [ebp + hItemToRemoveIndex], al
.loop:
    mov al, [ebp + esi]
    inc esi
    cmp al, 0xff                              ; -1 terminator
    jz .done
    cmp al, bl
    jz .foundItem
    inc esi                                    ; skip quantity byte
    mov al, [ebp + hItemToRemoveIndex]
    inc al
    mov [ebp + hItemToRemoveIndex], al
    jmp .loop
.foundItem:
    mov al, 1
    mov [ebp + wItemQuantity], al
    mov al, [ebp + hItemToRemoveIndex]
    mov [ebp + wWhichPokemon], al
    mov esi, wNumBagItems
    jmp RemoveItemFromInventory
.done:
    ret
