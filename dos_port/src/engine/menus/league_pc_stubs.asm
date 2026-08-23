; league_pc_stubs.asm — EMPTY. Both stubs it once held have been retired by their
; real routines landing: LoadHallOfFameTeams (src/engine/menus/save.asm, menus S7)
; and Func_7033f (src/engine/movie/hall_of_fame.asm). The header used to say the
; Hall-of-Fame team loop was "guarded OFF while wNumHoFTeams==0 (no save layer
; yet)"; that guard is gone and the loop is pret's, unconditional and live.
;
; Register map: A→AL, HL→ESI, BC→BX, DE→DX; GB mem = [ebp+SYM] (gb_memmap.inc).

bits 32

section .text

; LoadHallOfFameTeams — now provided REAL by src/engine/menus/save.asm (menus S7,
; package H). The ret-stub was deleted here so the real routine is the only global.

; Func_7033f — now provided REAL by src/engine/movie/hall_of_fame.asm. The ret-stub
; was deleted here so the real routine is the only global. LeaguePCShowMon's tail
; jump now draws the mon-info box and plays the cry, as pret does.
;
; NOTHING IS LEFT IN THIS FILE. It is kept, empty of stubs, only because both of its
; former occupants were retired by the routines landing rather than by the file being
; renamed away; delete it when someone is confident no reference remains.
