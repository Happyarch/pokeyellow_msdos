; pc_stubs.asm — integration-spine seam stub for the PC main menu (menus-port
; Session 9). PCMainMenu (pc.asm) reaches one remaining routine that pret files
; under engine/pokemon/bills_pc.asm. The DisplayPCMainMenu stub this file also
; held is RETIRED — the real routine lives in engine/pokemon/bills_pc.asm now.
; This stub is DELETED when the real BillsPC_ lands there too (the
; league_pc_stubs.asm / main_menu_stubs.asm pattern — the duplicate global
; forces removal, exactly as "real X replaced stub" in S7).
;
; Register map: A→AL, HL→ESI, BC→BX, DE→DX; GB mem = [ebp+SYM] (gb_memmap.inc).

bits 32

%include "gb_memmap.inc"

section .text

; STUB{class=stub; label=BillsPC_; pret=engine/pokemon/bills_pc.asm:BillsPC_; behavior=return immediately instead of running the storage-box UI; evidence=project_state:BillsPC_ reports linked ret stub; lifetime=until the Bill's PC UI is ported}
; BillsPC_ (pret engine/pokemon/bills_pc.asm) is
; Bill's #MON-storage box UI (deposit/withdraw/release — the backend logic already
; lives in bills_pc.asm as BillsPC{Deposit,Withdraw,Release}Logic; only the UI is
; deferred). pokemon_behavior Stage 6 owns it. pc.asm prints the "Accessed …"
; dialog before this call; the stub returns so the flow lands back in
; ReloadMainMenu. Delete when the real BillsPC_ lands.
global BillsPC_
BillsPC_:
    ret
