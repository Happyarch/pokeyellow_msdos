; dex_entries.asm — Pokédex entry pointer table + the 151 entry blobs.
;
; pret ref: data/pokemon/dex_entries.asm (PokedexEntryPointers).
;
; Moved here 2026-08-02 from src/engine/menus/pokedex.asm, which is a CODE file.
; `lint_pret_labels` reported it as [aux_misplaced]: a pret data/ label must be
; defined under dos_port/src/data/ or in a generated dos_port/assets/*.inc, and
; it was sitting in the menu engine next to the routines that read it. Nothing
; about the bytes changed — this file holds the same `%include` the code file
; held, so the generated blob is bit-identical and this is a pure relocation.
;
; Consumers extern PokedexEntryPointers rather than %including the asset:
;   * src/engine/menus/pokedex.asm  — the DATA page walks it for the current mon.
;   * src/engine/menus/link_menu.asm (PetitCup).
;
; Embedded data goes in .data per the linker rule in docs/assembly.md (.rodata
; has no output-section rule of its own; link.ld folds it into .data, but .data
; is what this project writes).
;
; Build: nasm -f coff -I include/ -I . -o dex_entries.o dex_entries.asm
; ---------------------------------------------------------------------------
bits 32

%include "gb_constants.inc"

global PokedexEntryPointers          ; link_menu.asm (PetitCup) externs it

section .data
align 4

; PokedexEntryPointers + the 151 entry blobs (flat .data, charmap-encoded).
%include "assets/dex_entries.inc"
