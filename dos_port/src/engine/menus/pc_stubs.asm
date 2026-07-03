; pc_stubs.asm — integration-spine seam stubs for the PC main menu (menus-port
; Session 9). PCMainMenu (pc.asm) reaches two routines that pret files under
; engine/pokemon/bills_pc.asm, which docs/current_plan_pokemon_behavior.md
; (Stage 6, still open) owns: the menus plan out-of-scope rule is "stub the
; seams, never touch its files." These honest stubs let the faithful PCMainMenu
; control flow link and be exercised today; each is DELETED when its real routine
; lands in bills_pc.asm (the league_pc_stubs.asm / main_menu_stubs.asm pattern —
; the duplicate global forces removal, exactly as "real X replaced stub" in S7).
;
; Register map: A→AL, HL→ESI, BC→BX, DE→DX; GB mem = [ebp+SYM] (gb_memmap.inc).

bits 32

%include "gb_memmap.inc"

section .text

; DEVIATION: integration stub — DisplayPCMainMenu (pret engine/pokemon/bills_pc.asm)
; draws the BILL's/player's/OAK's/league/LOG-OFF box (event-gated, TextBoxBorder +
; PlaceString) and arms the menu vars. The real routine is pokemon_behavior Stage 6.
; The stub does NOT draw the box (that is the pokemon_behavior work), but it arms
; the menu vars so PCMainMenu's [wMaxMenuItem]/[wCurrentMenuItem] dispatch and
; HandleMenuInput run on defined state rather than garbage. wMaxMenuItem = 2 is
; pret's pre-Pokédex layout (BILL's / player's / LOG OFF). Delete when the real
; DisplayPCMainMenu lands.
global DisplayPCMainMenu
DisplayPCMainMenu:
    xor al, al
    mov [ebp + hAutoBGTransferEnabled], al
    mov byte [ebp + wMaxMenuItem], 2
    mov byte [ebp + wTopMenuItemY], 2
    mov byte [ebp + wTopMenuItemX], 1
    mov byte [ebp + wCurrentMenuItem], 0
    mov byte [ebp + wLastMenuItem], 0
    mov byte [ebp + wMenuWatchedKeys], PAD_A | PAD_B
    mov byte [ebp + hAutoBGTransferEnabled], 1
    ret

; DEVIATION: integration stub — BillsPC_ (pret engine/pokemon/bills_pc.asm) is
; Bill's #MON-storage box UI (deposit/withdraw/release — the backend logic already
; lives in bills_pc.asm as BillsPC{Deposit,Withdraw,Release}Logic; only the UI is
; deferred). pokemon_behavior Stage 6 owns it. pc.asm prints the "Accessed …"
; dialog before this call; the stub returns so the flow lands back in
; ReloadMainMenu. Delete when the real BillsPC_ lands.
global BillsPC_
BillsPC_:
    ret
