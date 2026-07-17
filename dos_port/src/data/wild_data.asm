; wild_data.asm — wild-encounter static data tables (battle engine plan, Stage 9).
;
; Holds the generated read-only wild-encounter data so the engine routines
; (LoadWildData, TryDoWildEncounter) can `extern` them. Per the linker rule in
; docs/assembly.md, embedded data lives in .data (not .rodata, which has no
; output-section rule and reads back as zero).
;
; WildDataPointers / WildMonEncounterSlotChances / per-map blobs:
;   tools/generators/gen_wild_encounters.py (from data/wild/).
;
; Build: nasm -f coff -I include/ -I . -o wild_data.o wild_data.asm

bits 32

global WildDataPointers
global WildDataPointersEnd
global WildMonEncounterSlotChances

section .data
align 4

%include "assets/wild_data.inc"
