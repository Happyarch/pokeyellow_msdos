; dungeon_maps.asm — mirror of pret data/maps/dungeon_maps.asm.
;
; Consumed by GetBattleTransitionID_IsDungeonMap (src/engine/battle/
; battle_transitions.asm). Map-id constants come from the generated
; assets/map_dims.inc (pret names). Hand-written `db` of named constants is
; within the two-tier rule (constants, not encoded text).
;
; pret's own comment, preserved: GetBattleTransitionID_IsDungeonMap fails to
; recognize VICTORY_ROAD_2F, VICTORY_ROAD_3F, all ROCKET_HIDEOUT maps,
; POKEMON_MANSION_1F, SEAFOAM_ISLANDS_[B1F-B4F], POWER_PLANT, DIGLETTS_CAVE,
; and SILPH_CO_[9-11]F as dungeon maps.

%include "assets/map_dims.inc"

bits 32

global DungeonMaps1
global DungeonMaps2

section .data

; GetBattleTransitionID_IsDungeonMap checks if wCurMap
; is equal to one of these maps
DungeonMaps1:
    db VIRIDIAN_FOREST
    db ROCK_TUNNEL_1F
    db SEAFOAM_ISLANDS_1F
    db ROCK_TUNNEL_B1F
    db 0xFF ; end

; GetBattleTransitionID_IsDungeonMap checks if wCurMap
; is in between or equal to each pair of maps
DungeonMaps2:
    ; all MT_MOON maps
    db MT_MOON_1F, MT_MOON_B2F
    ; all SS_ANNE maps, VICTORY_ROAD_1F, LANCES_ROOM, and HALL_OF_FAME
    db SS_ANNE_1F, HALL_OF_FAME
    ; all POKEMON_TOWER maps and Lavender Town buildings
    db LAVENDER_POKECENTER, LAVENDER_CUBONE_HOUSE
    ; SILPH_CO_[2-8]F, POKEMON_MANSION[2F-B1F], SAFARI_ZONE, and
    ; CERULEAN_CAVE maps, except for SILPH_CO_1F
    db SILPH_CO_2F, CERULEAN_CAVE_1F
    db 0xFF ; end
