; oaks_pc_stubs.asm — seam stub for OAK's PC (menu-fidelity row 17 part 3).
;
; OpenOaksPC (oaks_pc.asm) does `predef DisplayDexRating` on YES. pret files that
; routine under engine/events/pokedex_rating.asm: it counts owned/seen species,
; prints OAK's rating text and plays the rating fanfare — the pokédex package owns
; it, which the menus plan does not. Before this stub the port had NO call at all:
; a bare comment claiming "STUB(S8: pokedex package)" sat where the predef belongs,
; with no stub body anywhere (ledger M-88). An honest ret-only stub restores the
; call so the control flow is pret's; delete this file when the real
; DisplayDexRating lands (the duplicate global forces the removal — the
; pc_stubs.asm / league_pc_stubs.asm pattern).
;
; Contract: DisplayDexRating takes no arguments and returns nothing; no caller
; reads a flag or a register from it (OpenOaksPC falls straight through to
; ClosedOaksPCText, hall_of_fame.asm likewise ignores the return). A ret-only body
; therefore preserves every contract the callers actually depend on — only the
; rating cutscene itself is missing.
;
; Register map: A→AL, HL→ESI, BC→BX, DE→DX; GB mem = [ebp+SYM] (gb_memmap.inc).

bits 32

%include "gb_memmap.inc"

section .text

global DisplayDexRating
DisplayDexRating:
    ret
