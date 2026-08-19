; prize_mon_levels.asm — pret mirror of data/events/prize_mon_levels.asm.
;
; Dictionary mapping prize Pokémon species to their levels when obtained at Game Corner.

bits 32

%include "gb_constants.inc"
%include "assets/script_constants.inc"

global PrizeMonLevelDictionary

section .data

PrizeMonLevelDictionary:
    db ABRA,       15
    db VULPIX,     18
    db WIGGLYTUFF, 22

    db SCYTHER,    30
    db PINSIR,     30
    db PORYGON,    26
