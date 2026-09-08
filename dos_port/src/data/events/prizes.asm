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

; NOTE (faithful terminator): pret data/events/prizes.asm writes "@" here and
; rgbds assembles it through the charmap to $50. NASM has no charmap, so a bare
; db "@" would emit ASCII $40 — which GetPrizeMenuId.copy_entries (cmp al, 0x50)
; never matches, running the copy off the end of the tables and across WRAM
; (wPrize1 DF0A through wPlayerName DF25 into wPartyData, stopping at the first
; coincidental $50 in .data). Every "@" below is therefore an explicit 0x50:
; the same byte pret ships, and the convention GetMonName already uses.

PrizeMenuMon1Entries:
    db ABRA
    db VULPIX
    db WIGGLYTUFF
    db 0x50 ; "@"

PrizeMenuMon1Cost:
    bcd2 230
    bcd2 1000
    bcd2 2680
    db 0x50 ; "@"

PrizeMenuMon2Entries:
    db SCYTHER
    db PINSIR
    db PORYGON
    db 0x50 ; "@"

PrizeMenuMon2Cost:
    bcd2 6500
    bcd2 6500
    bcd2 9999
    db 0x50 ; "@"

PrizeMenuTMsEntries:
    db TM_DRAGON_RAGE
    db TM_HYPER_BEAM
    db TM_SUBSTITUTE
    db 0x50 ; "@"

PrizeMenuTMsCost:
    bcd2 3300
    bcd2 5500
    bcd2 7700
    db 0x50 ; "@"
