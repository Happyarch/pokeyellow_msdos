; rest_house_maps.asm — pret data/maps/rest_house_maps.asm
;
; Safari Zone rest houses where blackout map is not updated.
; Map ID constants come from assets/map_dims.inc.

%include "assets/map_dims.inc"

bits 32

global SafariZoneRestHouses

section .data

SafariZoneRestHouses:
    db SAFARI_ZONE_WEST_REST_HOUSE
    db SAFARI_ZONE_EAST_REST_HOUSE
    db SAFARI_ZONE_NORTH_REST_HOUSE
    db 0xFF ; -1 end
