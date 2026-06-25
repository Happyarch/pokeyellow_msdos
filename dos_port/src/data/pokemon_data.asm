; pokemon_data.asm — Pokémon static data tables (Pokémon data/stats plan).
;
; Holds the generated/translated read-only Pokémon data so the engine routines
; (GetMonHeader, CalcStat, CalcExperience, …) can `extern` them. Per the linker
; rule in docs/assembly.md, embedded data lives in .data (not .rodata).
;
; BaseStats / IndexToPokedex : tools/gen_base_stats.py (from data/pokemon/).
; GrowthRateTable            : tools/gen_growth_rates.py (from data/growth_rates.asm).
; Moves                      : tools/gen_moves.py (from data/moves/moves.asm).
; EvosMovesPointerTable      : tools/gen_evos_moves.py (flat dd pointers + blobs).
; MonsterNames               : tools/gen_monster_names.py (charmap-encoded names).
;
; Build: nasm -f coff -I include/ -I . -o pokemon_data.o pokemon_data.asm

bits 32

global BaseStats
global IndexToPokedex
global GrowthRateTable
global Moves
global EvosMovesPointerTable
global MonsterNames

section .data
align 4

%include "assets/base_stats.inc"
%include "assets/growth_rates.inc"
%include "assets/moves.inc"
%include "assets/evos_moves.inc"
%include "assets/monster_names.inc"
