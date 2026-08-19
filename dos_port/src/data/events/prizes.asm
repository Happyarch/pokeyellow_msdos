; prizes.asm — pret mirror of data/events/prizes.asm.
;
; Tables of Game Corner prizes (Pokemon species / TM items) and their BCD coin costs.

bits 32

%include "gb_constants.inc"
%include "data_macros.inc"
%include "assets/script_constants.inc"

global PrizeDifferentMenuPtrs
global PrizeMenuMon1Entries
global PrizeMenuMon1Cost
global PrizeMenuMon2Entries
global PrizeMenuMon2Cost
global PrizeMenuTMsEntries
global PrizeMenuTMsCost

section .data

PrizeDifferentMenuPtrs:
    dd PrizeMenuMon1Entries, PrizeMenuMon1Cost
    dd PrizeMenuMon2Entries, PrizeMenuMon2Cost
    dd PrizeMenuTMsEntries,  PrizeMenuTMsCost

PrizeMenuMon1Entries:
    db ABRA
    db VULPIX
    db WIGGLYTUFF
    db "@"

PrizeMenuMon1Cost:
    bcd2 230
    bcd2 1000
    bcd2 2680
    db "@"

PrizeMenuMon2Entries:
    db SCYTHER
    db PINSIR
    db PORYGON
    db "@"

PrizeMenuMon2Cost:
    bcd2 6500
    bcd2 6500
    bcd2 9999
    db "@"

PrizeMenuTMsEntries:
    db TM_DRAGON_RAGE
    db TM_HYPER_BEAM
    db TM_SUBSTITUTE
    db "@"

PrizeMenuTMsCost:
    bcd2 3300
    bcd2 5500
    bcd2 7700
    db "@"
