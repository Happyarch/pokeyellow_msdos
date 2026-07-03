; league_pc_stubs.asm — ret-only stubs for the two forward-deps of league_pc.asm
; (menus S6 package A). PKMNLeaguePC's Hall-of-Fame team loop is ported for label
; parity but guarded OFF while wNumHoFTeams==0 (no save layer yet), so LoadHallOfFameTeams
; and Func_7033f are referenced at link but never executed in the live build. These
; stubs let the faithful loop structure link; delete each when its real routine lands.
;
; Register map: A→AL, HL→ESI, BC→BX, DE→DX; GB mem = [ebp+SYM] (gb_memmap.inc).

bits 32

section .text

; LoadHallOfFameTeams — now provided REAL by src/engine/menus/save.asm (menus S7,
; package H). The ret-stub was deleted here so the real routine is the only global.

; Func_7033f — pret engine/movie/hall_of_fame.asm:Func_7033f (HoF mon-info box +
; cry, tail-jumped from LeaguePCShowMon). Provided by the HoF movie port.
; Reached only inside the dead team loop; returns to LeaguePCShowMon's caller.
global Func_7033f
Func_7033f:
    ret
