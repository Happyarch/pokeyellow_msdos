; pc.asm — the generic PC spine. Faithful port of pret engine/menus/pc.asm:
; ActivatePC (the Poké-Center PC script target) + PCMainMenu (the BILL's /
; player's / OAK's / league / LOG OFF selector) + its dispatch:
;   .playersPC → PlayerPC       (players_pc.asm)
;   OaksPC     → OpenOaksPC     (oaks_pc.asm)
;   PKMNLeague → PKMNLeaguePC   (league_pc.asm)
;   BillsPC    → BillsPC_       (SEAM STUB — pokemon_behavior Stage 6 owns the
;                                real box UI; DisplayPCMainMenu is the same seam)
; plus RemoveItemByID, which pret files here.
;
; SEAMS (pc_stubs.asm; deleted when pokemon_behavior Stage 6 lands them):
;   DisplayPCMainMenu — draws the PC main menu box + arms the menu vars.
;   BillsPC_          — Bill's #MON-storage box UI.
;
; HISTORY / CORRECTED CLAIMS (menu-fidelity row 17 part 1). The header this
; replaces asserted three things, all of them false, and each one had cost the
; file real code:
;   * "PlaySound / WaitForSoundToFinish are TODO-HW: audio HAL (Phase 3)" —
;     both are ported and live (home/audio.asm), and the port's audio engine
;     plays SFX. All six calls (SFX_TURN_ON_PC / SFX_ENTER_PC ×4 / SFX_TURN_OFF_PC)
;     are restored. M-79.
;   * "SaveScreenTilesToBuffer2 / LoadScreenTilesFromBuffer2 → window-model
;     save/restore" — both are ported (movie/title.asm), are pure wTileMap ↔
;     wTileMapBackup2 WRAM copies, and are already called from home/start_menu.asm
;     and overworld/cut.asm. The port's substitute (snapshot g_window_count)
;     saved nothing at all. Restored. M-80.
;   * The four dialogs are "drawn whole" because "the dialog projection collapses
;     the window list" — PrintText + the msgbox_dialog projection is exactly what
;     the other menus use, and nothing here needs a window to survive the message
;     (the PC menu box is redrawn by DisplayPCMainMenu on every PCMainMenu pass).
;     The drawn-whole plumbing came with NINE hand-encoded charmap strings — the
;     Tier-1 DATA violation — and it could not render <PLAYER> ($52) or POKé ($54)
;     as commands, so it open-coded them as literal glyph runs. All four streams
;     now generate into assets/pc_text.inc and print through PrintText. M-81.
;
; PORT MODEL:
;  * SM83→x86: A=AL, BC=BX, DE=DX, HL=ESI, EBP = GB base; GB memory at [EBP+sym].
;  * text_msgbox := msgbox_dialog before each PrintText — the port's one printer
;    takes its box geometry from a projection record (msgbox.inc); pret's box is
;    a fixed literal inside TextCommandProcessor, so it has no counterpart.
;  * DEVIATION(window-compositor) at the LoadScreenTilesFromBuffer2 sites: the WRAM
;    restore puts the map tiles back, but the port shows the dialog through the
;    WINDOW layer, which no WRAM copy touches — so the window is dropped too.
;
; Build (standalone check):
;   nasm -f coff -I include/ -I . -o /dev/null src/engine/menus/pc.asm
; ---------------------------------------------------------------------------
bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_text.inc"                    ; text_far / text_end + TX_* codes
%include "assets/event_constants.inc"    ; EVENT_MET_BILL
%include "assets/audio_constants.inc"    ; SFX_TURN_ON_PC / SFX_ENTER_PC / SFX_TURN_OFF_PC
%include "events.inc"                     ; CheckEvent (clobbers AL, sets ZF)

global ActivatePC
global PCMainMenu
global RemoveItemByID
global TurnedOnPC1Text
global AccessedBillsPCText
global AccessedSomeonesPCText
global AccessedMyPCText

extern DisplayPCMainMenu             ; pc_stubs.asm SEAM (pokemon_behavior S6)
extern BillsPC_                      ; pc_stubs.asm SEAM (pokemon_behavior S6)
extern PlayerPC                      ; engine/menus/players_pc.asm
extern OpenOaksPC                    ; engine/menus/oaks_pc.asm
extern PKMNLeaguePC                  ; engine/menus/league_pc.asm

extern HandleMenuInput               ; home/window.asm — Out: AL = watched keys pressed
extern PrintText                     ; home/window.asm — In: ESI = text stream
extern text_msgbox                   ; home/text.asm — the active msgbox projection
extern msgbox_dialog                 ; home/text.asm — the standard bottom dialog box
extern PlaySound                     ; home/audio.asm — In: AL = sound id
extern WaitForSoundToFinish          ; home/audio.asm
extern SaveScreenTilesToBuffer2      ; movie/title.asm — wTileMap → wTileMapBackup2
extern LoadScreenTilesFromBuffer2    ; movie/title.asm — wTileMapBackup2 → wTileMap
extern ReloadMapData                 ; home/reload_tiles.asm
extern UpdateSprites                 ; engine/overworld/movement.asm
extern Delay3                        ; video/frame.asm
extern hide_window                   ; ppu/ppu.asm — drop the dialog window layer

%ifdef DEBUG_PC
extern LoadFontTilePatterns          ; home/load_font.asm
global RunPCTest
%endif

; RemoveItemByID (hItemToRemove* are hram equs in gb_memmap.inc, not externs)
extern wBagItems
extern wItemQuantity
extern wWhichPokemon
extern wNumBagItems
extern RemoveItemFromInventory

; ===========================================================================
; Tier-1 DATA: the four message streams, generated from pret data/text/text_3.asm.
%include "assets/pc_text.inc"

; ===========================================================================
section .text

; ---------------------------------------------------------------------------
; ActivatePC — pret ref: engine/menus/pc.asm:ActivatePC.
; Overworld Poké-Center PC script target. In: EBP = GB base.
; ---------------------------------------------------------------------------
ActivatePC:
    call SaveScreenTilesToBuffer2
    mov al, SFX_TURN_ON_PC
    call PlaySound
    mov esi, TurnedOnPC1Text                  ; ld hl, TurnedOnPC1Text
    mov dword [text_msgbox], msgbox_dialog    ; port: publish the box projection
    call PrintText
    call WaitForSoundToFinish
    or byte [ebp + wMiscFlags], (1 << BIT_USING_GENERIC_PC)   ; set BIT_USING_GENERIC_PC, [hl]
    call LoadScreenTilesFromBuffer2
    call hide_window                          ; DEVIATION(window-compositor): the WRAM
                                              ; restore cannot drop the dialog WINDOW.
    call Delay3
    ; fall through to PCMainMenu

; ---------------------------------------------------------------------------
; PCMainMenu — pret ref: engine/menus/pc.asm:PCMainMenu.
; Draws the PC main menu (seam), runs HandleMenuInput, dispatches by the menu
; layout ([wMaxMenuItem]) and selection ([wCurrentMenuItem]).
; ---------------------------------------------------------------------------
PCMainMenu:
    call DisplayPCMainMenu                    ; farcall — SEAM (draws menu, sets wMaxMenuItem)
    or byte [ebp + wMiscFlags], (1 << BIT_NO_MENU_BUTTON_SOUND)  ; set BIT_NO_MENU_BUTTON_SOUND, [hl]
    call HandleMenuInput
    test al, PAD_B                            ; bit B_PAD_B, a
    jnz LogOff                                ; jp nz, LogOff
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
    and byte [ebp + wMiscFlags], (~(1 << BIT_NO_MENU_BUTTON_SOUND)) & 0xFF  ; res BIT_NO_MENU_BUTTON_SOUND, [hl]
    or  byte [ebp + wMiscFlags], (1 << BIT_USING_GENERIC_PC)                 ; set BIT_USING_GENERIC_PC, [hl]
    mov al, SFX_ENTER_PC
    call PlaySound
    call WaitForSoundToFinish
    mov esi, AccessedMyPCText                 ; ld hl, AccessedMyPCText
    mov dword [text_msgbox], msgbox_dialog
    call PrintText
    call PlayerPC                             ; farcall PlayerPC
    jmp ReloadMainMenu                        ; jr ReloadMainMenu

OaksPC:
    mov al, SFX_ENTER_PC
    call PlaySound
    call WaitForSoundToFinish
    call OpenOaksPC                           ; farcall OpenOaksPC
    jmp ReloadMainMenu                        ; jr ReloadMainMenu

PKMNLeague:
    mov al, SFX_ENTER_PC
    call PlaySound
    call WaitForSoundToFinish
    call PKMNLeaguePC                         ; farcall PKMNLeaguePC
    jmp ReloadMainMenu                        ; jr ReloadMainMenu

BillsPC:
    mov al, SFX_ENTER_PC
    call PlaySound
    call WaitForSoundToFinish
    CheckEvent EVENT_MET_BILL                 ; ZF=0 → met Bill (event SET)
    jnz .billsPC                              ; jr nz, .billsPC
    mov esi, AccessedSomeonesPCText           ; ld hl, AccessedSomeonesPCText
    jmp .printText                            ; jr .printText
.billsPC:
    mov esi, AccessedBillsPCText              ; ld hl, AccessedBillsPCText
.printText:
    mov dword [text_msgbox], msgbox_dialog
    call PrintText
    call BillsPC_                             ; farcall BillsPC_ — SEAM (pokemon_behavior S6)
    ; fall through to ReloadMainMenu

ReloadMainMenu:
    xor al, al
    mov [ebp + wDoNotWaitForButtonPressAfterDisplayingText], al
    call ReloadMapData
    call UpdateSprites
    jmp PCMainMenu                            ; jp PCMainMenu

LogOff:
    mov al, SFX_TURN_OFF_PC
    call PlaySound
    call WaitForSoundToFinish
    and byte [ebp + wMiscFlags], (~(1 << BIT_USING_GENERIC_PC)) & 0xFF       ; res BIT_USING_GENERIC_PC, [hl]
    and byte [ebp + wMiscFlags], (~(1 << BIT_NO_MENU_BUTTON_SOUND)) & 0xFF   ; res BIT_NO_MENU_BUTTON_SOUND, [hl]
    ret

; --- the four PC dialogs (pret ref: engine/menus/pc.asm, same position) ------
; Tier-2 wrappers over the Tier-1 streams in assets/pc_text.inc, keeping pret's
; text_far indirection rather than pointing PrintText at the flat body directly.
TurnedOnPC1Text:
    text_far _TurnedOnPC1Text
    text_end

AccessedBillsPCText:
    text_far _AccessedBillsPCText
    text_end

AccessedSomeonesPCText:
    text_far _AccessedSomeonesPCText
    text_end

AccessedMyPCText:
    text_far _AccessedMyPCText
    text_end

%ifdef DEBUG_PC
; ---------------------------------------------------------------------------
; RunPCTest — FRAME.BIN gate for the PC spine (row 17). Nothing in the linked
; game reaches ActivatePC yet (home/overworld_text.asm's TextScript_PokemonCenterPC
; is still behind %ifdef M72_OVERWORLD_TEXTSCRIPTS — see the ledger finding), and
; no golden covers this screen, so this is how the dialog gets observed at all.
; ActivatePC prints TurnedOnPC1Text and blocks in the stream's `prompt` wait; the
; harness runs with AUTOKEY_QUIET (no presses), so AutoKeyDrive photographs the
; open dialog at AUTOKEY_DUMP_FRAME and exits.
; ---------------------------------------------------------------------------
RunPCTest:
    or byte [ebp + W_FONT_LOADED], (1 << BIT_FONT_LOADED)
    call LoadFontTilePatterns
    call ActivatePC
.hang:
    jmp .hang
%endif

; ---------------------------------------------------------------------------
; RemoveItemByID — pret ref: engine/menus/pc.asm:RemoveItemByID.
; removes one of the specified item ID [hItemToRemoveID] from bag (if existent).
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
