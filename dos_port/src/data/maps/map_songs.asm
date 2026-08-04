; map_songs.asm — per-map music id + ROM bank, indexed by map id.
;
; pret ref: data/maps/songs.asm (MapSongBanks).
;
; Moved here 2026-08-02 from src/engine/overworld/overworld.asm, which is a CODE
; file. `lint_pret_labels` reported it as [aux_misplaced]: a pret data/ label
; must be defined under dos_port/src/data/ or in a generated assets/*.inc, and
; it was riding the overworld engine's embedded-asset region. Nothing about the
; bytes changed — this file holds the same `%include`, so the generated table is
; bit-identical and this is a pure relocation.
;
; Self-contained on purpose: map_songs.inc defines only MapSongBanks and its
; _END marker, carries no `equ`, and references no label from another asset.
; That is what made it separable in the 2026-08-02 pass. MapHeaderPointers
; followed 2026-08-04 (719d997d) once its "equ cannot cross an object file"
; blocker was measured false — see map_headers.asm beside this file.
;
; Consumer: LoadMapData's map-music path (the relocated pret home/overworld.asm
; routines) externs MapSongBanks.
;
; Embedded data goes in .data per the linker rule in docs/assembly.md.
;
; Build: nasm -f coff -I include/ -I . -o map_songs.o map_songs.asm
; ---------------------------------------------------------------------------
bits 32

%include "gb_constants.inc"
%include "assets/audio_constants.inc"    ; MUSIC_* ids + MUSIC_*_BANK

global MapSongBanks                       ; LoadMapData map music

section .data
align 4

%include "assets/map_songs.inc"
