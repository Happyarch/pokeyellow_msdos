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
%include "assets/map_dims.inc"   ; map-id / tileset-id constants (Tier-1 generated)

; ---------------------------------------------------------------------------
; wCurrentMapScriptFlags bit indices (constants/ram_constants.asm). Guarded
; local equs — several other ported files (main_menu.asm, trainer_battle.asm)
; already define these the same way; %ifndef makes duplication harmless and a
; later promotion to gb_memmap.inc a no-op here.
; ---------------------------------------------------------------------------
%ifndef BIT_CUR_MAP_LOADED_1
%endif
%ifndef BIT_CUR_MAP_LOADED_2
%endif

; ---------------------------------------------------------------------------
; Map IDs (constants/map_constants.asm). Local equs — the port's gb_constants.inc
; does not (yet) carry a full MAP_* enum, so these are pinned directly from the
; pret constant file's map_const hex column (verified against map_constants.asm
; on 2026-07-04). %ifndef-guarded in case a sibling file in this same subsystem
; already defines one (no observed collision at the time of writing; the
; warp_check.asm that used to define a handful of MAP_* names is gone).
; ---------------------------------------------------------------------------
%ifndef VERMILION_GYM
%endif
%ifndef SILPH_CO_2F
%endif
%ifndef SILPH_CO_3F
%endif
%ifndef SILPH_CO_4F
%endif
%ifndef SILPH_CO_5F
%endif
%ifndef SILPH_CO_6F
%endif
%ifndef SILPH_CO_7F
%endif
%ifndef SILPH_CO_8F
%endif
%ifndef SILPH_CO_9F
%endif
%ifndef SILPH_CO_10F
%endif
%ifndef SILPH_CO_11F
%endif
%ifndef POKEMON_MANSION_2F
%endif
%ifndef POKEMON_MANSION_3F
%endif
%ifndef POKEMON_MANSION_B1F
%endif
%ifndef POKEMON_MANSION_1F
%endif
%ifndef CINNABAR_GYM
%endif
%ifndef GAME_CORNER
%endif
%ifndef ROCKET_HIDEOUT_B1F
%endif
%ifndef ROCKET_HIDEOUT_B4F
%endif
%ifndef VICTORY_ROAD_3F
%endif
%ifndef VICTORY_ROAD_1F
%endif
%ifndef VICTORY_ROAD_2F
%endif
%ifndef LANCES_ROOM
%endif
%ifndef LORELEIS_ROOM
%endif
%ifndef BRUNOS_ROOM
%endif
%ifndef AGATHAS_ROOM
%endif

extern IsInArray                     ; src/home/array2.asm — $FF-terminated flat search

global SetMapSpecificScriptFlagsOnMapReload

section .text

; ---------------------------------------------------------------------------
; SetMapSpecificScriptFlagsOnMapReload
; pret: engine/overworld/specific_script_flags.asm
;
;   ld a, [wCurMap]                 -> mov al, [ebp + wCurMap]
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
;     set BIT_CUR_MAP_LOADED_2, [hl]  -> or byte [ebp+wCurrentMapScriptFlags], (1<<BIT_CUR_MAP_LOADED_2)
;     ret
;   .in_list:
;     ld hl, wCurrentMapScriptFlags
;     set BIT_CUR_MAP_LOADED_1, [hl]  -> or byte [ebp+wCurrentMapScriptFlags], (1<<BIT_CUR_MAP_LOADED_1)
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
    mov al, [ebp + wCurMap]        ; ld a, [wCurMap]
    cmp al, VERMILION_GYM            ; cp VERMILION_GYM
    je .vermilion_gym                ; jr z, .vermilion_gym

    mov edx, 1                       ; entry stride = 1 byte (db table)
    lea esi, [Bit5Maps]              ; ld hl, Bit5Maps
    call IsInArray                   ; search_loop, folded into shared helper
    jc .in_list
    ret

.vermilion_gym:
    or byte [ebp + wCurrentMapScriptFlags], (1 << BIT_CUR_MAP_LOADED_2)
    ret

.in_list:
    or byte [ebp + wCurrentMapScriptFlags], (1 << BIT_CUR_MAP_LOADED_1)
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
