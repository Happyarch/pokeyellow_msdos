; specific_script_flags.asm — pret engine/overworld/specific_script_flags.asm
;
; SetMapSpecificScriptFlagsOnMapReload — on a map (re)load, sets a per-map bit
; in wCurrentMapScriptFlags that a map's _Script/text routines later test to
; decide whether "you just walked in" one-shot setup logic should run again.
; VERMILION_GYM gets its own bit (it wires the Lt. Surge trash-can event flag,
; engine/events/hidden_events/vermilion_gym_trash.asm) while a fixed list of
; "reload the puzzle/lobby state" maps (Silph Co., Pokemon Mansion, Cinnabar
; Gym, Game Corner, Rocket Hideout, Victory Road, the Elite Four rooms) share
; another bit.
;
; pret source: engine/overworld/specific_script_flags.asm
;              (table: data/maps/bit_5_maps.asm, INCLUDEd by the pret file)
;
; ---------------------------------------------------------------------------
bits 32

%include "gb_memmap.inc"

; ---------------------------------------------------------------------------
; wCurrentMapScriptFlags bit indices (constants/ram_constants.asm). Guarded
; local equs — several other ported files (main_menu.asm, trainer_battle.asm)
; already define these the same way; %ifndef makes duplication harmless and a
; later promotion to gb_memmap.inc a no-op here.
; ---------------------------------------------------------------------------
%ifndef BIT_CUR_MAP_LOADED_1
BIT_CUR_MAP_LOADED_1   equ 5   ; ram_constants.asm: wCurrentMapScriptFlags bit 5
%endif
%ifndef BIT_CUR_MAP_LOADED_2
BIT_CUR_MAP_LOADED_2   equ 6   ; ram_constants.asm: wCurrentMapScriptFlags bit 6
%endif

; ---------------------------------------------------------------------------
; Map IDs (constants/map_constants.asm). Local equs — the port's gb_constants.inc
; does not (yet) carry a full MAP_* enum, so these are pinned directly from the
; pret constant file's map_const hex column (verified against map_constants.asm
; on 2026-07-04). %ifndef-guarded in case a sibling file in this same subsystem
; already defines one (warp_check.asm defines a handful of MAP_* names, but not
; these; no observed collision at the time of writing).
; ---------------------------------------------------------------------------
%ifndef VERMILION_GYM
VERMILION_GYM           equ 0x5C
%endif
%ifndef SILPH_CO_2F
SILPH_CO_2F             equ 0xCF
%endif
%ifndef SILPH_CO_3F
SILPH_CO_3F             equ 0xD0
%endif
%ifndef SILPH_CO_4F
SILPH_CO_4F             equ 0xD1
%endif
%ifndef SILPH_CO_5F
SILPH_CO_5F             equ 0xD2
%endif
%ifndef SILPH_CO_6F
SILPH_CO_6F             equ 0xD3
%endif
%ifndef SILPH_CO_7F
SILPH_CO_7F             equ 0xD4
%endif
%ifndef SILPH_CO_8F
SILPH_CO_8F             equ 0xD5
%endif
%ifndef SILPH_CO_9F
SILPH_CO_9F             equ 0xE9
%endif
%ifndef SILPH_CO_10F
SILPH_CO_10F            equ 0xEA
%endif
%ifndef SILPH_CO_11F
SILPH_CO_11F            equ 0xEB
%endif
%ifndef POKEMON_MANSION_2F
POKEMON_MANSION_2F      equ 0xD6
%endif
%ifndef POKEMON_MANSION_3F
POKEMON_MANSION_3F      equ 0xD7
%endif
%ifndef POKEMON_MANSION_B1F
POKEMON_MANSION_B1F     equ 0xD8
%endif
%ifndef POKEMON_MANSION_1F
POKEMON_MANSION_1F      equ 0xA5
%endif
%ifndef CINNABAR_GYM
CINNABAR_GYM            equ 0xA6
%endif
%ifndef GAME_CORNER
GAME_CORNER             equ 0x87
%endif
%ifndef ROCKET_HIDEOUT_B1F
ROCKET_HIDEOUT_B1F      equ 0xC7
%endif
%ifndef ROCKET_HIDEOUT_B4F
ROCKET_HIDEOUT_B4F      equ 0xCA
%endif
%ifndef VICTORY_ROAD_3F
VICTORY_ROAD_3F         equ 0xC6
%endif
%ifndef VICTORY_ROAD_1F
VICTORY_ROAD_1F         equ 0x6C
%endif
%ifndef VICTORY_ROAD_2F
VICTORY_ROAD_2F         equ 0xC2
%endif
%ifndef LANCES_ROOM
LANCES_ROOM             equ 0x71
%endif
%ifndef LORELEIS_ROOM
LORELEIS_ROOM           equ 0xF5
%endif
%ifndef BRUNOS_ROOM
BRUNOS_ROOM             equ 0xF6
%endif
%ifndef AGATHAS_ROOM
AGATHAS_ROOM            equ 0xF7
%endif

extern IsInArray                     ; src/home/array.asm — $FF-terminated flat search

global SetMapSpecificScriptFlagsOnMapReload

section .text

; ---------------------------------------------------------------------------
; SetMapSpecificScriptFlagsOnMapReload
; pret: engine/overworld/specific_script_flags.asm
;
;   ld a, [wCurMap]                 -> mov al, [ebp + W_CUR_MAP]
;   cp VERMILION_GYM                -> cmp al, VERMILION_GYM
;   jr z, .vermilion_gym            -> je .vermilion_gym
;   ld c, a                         -> (folded away: AL already holds the
;                                       search value IsInArray wants — pret's
;                                       `ld c,a` only exists because SM83's
;                                       loop re-uses A as scratch; the x86
;                                       search helper takes AL directly)
;   ld hl, Bit5Maps                 -> lea esi, [Bit5Maps]
;   .search_loop:
;     ld a, [hli] / cp c / jr z, .in_list
;     cp $ff / jr nz, .search_loop
;     ret                           -> call IsInArray ; jc .in_list / ret
;                                       (IsInArray is exactly this $FF-terminated
;                                       linear-scan loop, already shared home code
;                                       — reused per project convention rather
;                                       than re-implemented here)
;   .vermilion_gym:
;     ld hl, wCurrentMapScriptFlags
;     set BIT_CUR_MAP_LOADED_2, [hl]  -> or byte [ebp+W_CURRENT_MAP_SCRIPT_FLAGS], (1<<BIT_CUR_MAP_LOADED_2)
;     ret
;   .in_list:
;     ld hl, wCurrentMapScriptFlags
;     set BIT_CUR_MAP_LOADED_1, [hl]  -> or byte [ebp+W_CURRENT_MAP_SCRIPT_FLAGS], (1<<BIT_CUR_MAP_LOADED_1)
;     ret
;
; Flags: AL is only ever compared, never arithmetically modified, between the
; `mov al,[wCurMap]` and the `cmp al, VERMILION_GYM`, so ZF is live and correct
; at `je .vermilion_gym`. IsInArray's own CF (found/not-found) is consumed
; immediately by `jc .in_list` with nothing in between — no flag-clobbering
; instruction is interposed anywhere on either path.
;
; In:  none (reads wCurMap)
; Out: none. Clobbers AL, BH, CL, ESI, EDX (all scratch — no live caller state
;      to preserve across this call in pret either; it's called at the tail
;      of map-reload processing).
; ---------------------------------------------------------------------------
SetMapSpecificScriptFlagsOnMapReload:
    mov al, [ebp + W_CUR_MAP]        ; ld a, [wCurMap]
    cmp al, VERMILION_GYM            ; cp VERMILION_GYM
    je .vermilion_gym                ; jr z, .vermilion_gym

    mov edx, 1                       ; entry stride = 1 byte (db table)
    lea esi, [Bit5Maps]              ; ld hl, Bit5Maps
    call IsInArray                   ; search_loop, folded into shared helper
    jc .in_list
    ret

.vermilion_gym:
    or byte [ebp + W_CURRENT_MAP_SCRIPT_FLAGS], (1 << BIT_CUR_MAP_LOADED_2)
    ret

.in_list:
    or byte [ebp + W_CURRENT_MAP_SCRIPT_FLAGS], (1 << BIT_CUR_MAP_LOADED_1)
    ret

; ---------------------------------------------------------------------------
; Bit5Maps — pret: data/maps/bit_5_maps.asm (INCLUDEd inline by the pret file
; at label Bit5Maps; inlined here per project-conventions — this is a small
; pret data table, not a Tier-1 generated asset). $FF-terminated, read via
; IsInArray with a 1-byte stride; lives in the port's flat program data (not
; emulated GB WRAM), same convention as the other IsInArray call sites.
; ---------------------------------------------------------------------------
section .data

Bit5Maps:
    db SILPH_CO_2F
    db SILPH_CO_3F
    db SILPH_CO_4F
    db SILPH_CO_5F
    db SILPH_CO_6F
    db SILPH_CO_7F
    db SILPH_CO_8F
    db SILPH_CO_9F
    db SILPH_CO_10F
    db SILPH_CO_11F
    db POKEMON_MANSION_2F
    db POKEMON_MANSION_3F
    db POKEMON_MANSION_B1F
    db POKEMON_MANSION_1F
    db CINNABAR_GYM
    db GAME_CORNER
    db ROCKET_HIDEOUT_B1F
    db ROCKET_HIDEOUT_B4F
    db VICTORY_ROAD_3F
    db VICTORY_ROAD_1F
    db VICTORY_ROAD_2F
    db LANCES_ROOM
    db LORELEIS_ROOM
    db BRUNOS_ROOM
    db AGATHAS_ROOM
    db 0xFF ; end
