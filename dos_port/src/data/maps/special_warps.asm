; special_warps.asm — fly / dungeon / cable-club / new-game warp data tables.
;
; Intended repo path: dos_port/src/data/maps/special_warps.asm
; pret source: data/maps/special_warps.asm
;
; %include'd from src/engine/overworld/special_warps.asm (mirroring pret's
; trailing `INCLUDE "data/maps/special_warps.asm"`); not assembled standalone.
;
; The fly_warp / special_warp_spec / fly_warp_spec macros mirror pret's
; (defined in-file there too). fly_warp builds on `event_displacement`
; (include/coords.inc), re-derived 2026-07-10 against the port's runtime
; view-pointer formula (overworld.asm:LoadWarpDestination) — see the macro's
; header comment for the lockstep rule.
;
; PROJ divergence (flat pointer width): pret's fly_warp_spec emits
; `db map, 0 / dw ptr` — a 2-byte GB ROM pointer. The port's tables live in
; the EXE's .data at flat 32-bit DS addresses, so fly_warp_spec emits
; `dd ptr` (entry stride 4 → 6 bytes; LoadSpecialWarpData's pointer walk
; skips 4 pointer bytes where pret skips 2, and loads the pointer with one
; 32-bit read in place of pret's `ld a,[hli] / ld h,[hl] / ld l,a`). The
; fly_warp payload entries themselves keep pret's exact 6-byte layout
; (dw view-ptr / db y / db x / db y-sub / db x-sub): the view pointer is a
; 2-byte GB-space WRAM address, so wDungeonWarpDataEntrySize=6 and both copy
; loops survive verbatim.
;
; Map ids / <MAP>_WIDTH / tileset ids come from the generated
; assets/map_dims.inc (Tier-1: pret constants/map_constants.asm +
; tileset_constants.asm values, never hand-encoded).
; ---------------------------------------------------------------------------

; Format: (size 2 bytes)
; 00: target map ID
; 01: which dungeon warp in the source map was used
DungeonWarpList:
    db SEAFOAM_ISLANDS_B1F, 1
    db SEAFOAM_ISLANDS_B1F, 2
    db SEAFOAM_ISLANDS_B2F, 1
    db SEAFOAM_ISLANDS_B2F, 2
    db SEAFOAM_ISLANDS_B3F, 1
    db SEAFOAM_ISLANDS_B3F, 2
    db SEAFOAM_ISLANDS_B4F, 1
    db SEAFOAM_ISLANDS_B4F, 2
    db VICTORY_ROAD_2F,     2
    db POKEMON_MANSION_1F,  1
    db POKEMON_MANSION_1F,  2
    db POKEMON_MANSION_2F,  3
    db -1 ; end

%macro fly_warp 3
    ; map name, x coord, y coord (tiles) — 6 bytes:
    ; dw view-ptr / db y / db x (event_displacement) / db y-sub / db x-sub
    event_displacement %{1}_WIDTH, %2, %3
    db ((%3) & 0x01) ; sub-block Y
    db ((%2) & 0x01) ; sub-block X
%endmacro

DungeonWarpData:
    fly_warp SEAFOAM_ISLANDS_B1F, 18,  7
    fly_warp SEAFOAM_ISLANDS_B1F, 23,  7
    fly_warp SEAFOAM_ISLANDS_B2F, 19,  7
    fly_warp SEAFOAM_ISLANDS_B2F, 22,  7
    fly_warp SEAFOAM_ISLANDS_B3F, 18,  7
    fly_warp SEAFOAM_ISLANDS_B3F, 19,  7
    fly_warp SEAFOAM_ISLANDS_B4F,  4, 14
    fly_warp SEAFOAM_ISLANDS_B4F,  5, 14
    fly_warp VICTORY_ROAD_2F,     22, 16
    fly_warp POKEMON_MANSION_1F,  16, 14
    fly_warp POKEMON_MANSION_1F,  16, 14
    fly_warp POKEMON_MANSION_2F,  18, 14

%macro special_warp_spec 4
    ; map name, x, y, tileset — 8 bytes: db map / fly_warp / db tileset
    db %1
    fly_warp %1, %2, %3
    db %4
%endmacro

NewGameWarp:
    special_warp_spec REDS_HOUSE_2F, 3, 6, REDS_HOUSE_2
TradeCenterPlayerWarp:
    special_warp_spec TRADE_CENTER,  3, 4, CLUB
TradeCenterFriendWarp:
    special_warp_spec TRADE_CENTER,  6, 4, CLUB
ColosseumPlayerWarp:
    special_warp_spec COLOSSEUM,     3, 4, CLUB
ColosseumFriendWarp:
    special_warp_spec COLOSSEUM,     6, 4, CLUB

%macro fly_warp_spec 2
    ; db map, 0 / dd ptr — pret emits `dw \2` (2-byte GB ROM pointer); the
    ; port stores a flat 32-bit .data address (see PROJ divergence, header).
    db %1, 0
    dd %2
%endmacro

FlyWarpDataPtr:
    fly_warp_spec PALLET_TOWN,     .PalletTown
    fly_warp_spec VIRIDIAN_CITY,   .ViridianCity
    fly_warp_spec PEWTER_CITY,     .PewterCity
    fly_warp_spec CERULEAN_CITY,   .CeruleanCity
    fly_warp_spec LAVENDER_TOWN,   .LavenderTown
    fly_warp_spec VERMILION_CITY,  .VermilionCity
    fly_warp_spec CELADON_CITY,    .CeladonCity
    fly_warp_spec FUCHSIA_CITY,    .FuchsiaCity
    fly_warp_spec CINNABAR_ISLAND, .CinnabarIsland
    fly_warp_spec INDIGO_PLATEAU,  .IndigoPlateau
    fly_warp_spec SAFFRON_CITY,    .SaffronCity
    fly_warp_spec ROUTE_4,         .Route4
    fly_warp_spec ROUTE_10,        .Route10

.PalletTown:     fly_warp PALLET_TOWN,      5,  6
.ViridianCity:   fly_warp VIRIDIAN_CITY,   23, 26
.PewterCity:     fly_warp PEWTER_CITY,     13, 26
.CeruleanCity:   fly_warp CERULEAN_CITY,   19, 18
.LavenderTown:   fly_warp LAVENDER_TOWN,    3,  6
.VermilionCity:  fly_warp VERMILION_CITY,  11,  4
.CeladonCity:    fly_warp CELADON_CITY,    41, 10
.FuchsiaCity:    fly_warp FUCHSIA_CITY,    19, 28
.CinnabarIsland: fly_warp CINNABAR_ISLAND, 11, 12
.IndigoPlateau:  fly_warp INDIGO_PLATEAU,   9,  6
.SaffronCity:    fly_warp SAFFRON_CITY,     9, 30
.Route4:         fly_warp ROUTE_4,         11,  6
.Route10:        fly_warp ROUTE_10,        11, 20
