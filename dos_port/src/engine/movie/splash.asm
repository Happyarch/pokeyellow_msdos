; splash.asm — the Game Freak "shooting star" splash (menu-intro B2).
;
; Source: engine/movie/splash.asm.
;
; Being ported incrementally. This first drop is the DATA layer: the shooting-star
; and Game Freak logo graphics + the OAM tables + the small-star wave coordinates,
; kept byte-for-byte against pret (the port's dbsprite macro is identical to pret's,
; `db y*8+ypxl, x*8+xpxl, tile, attr`). The animation routines
; (LoadShootingStarGraphics / AnimateShootingStar / MoveDownSmallStars) land next,
; publishing this OAM through PublishProjectedOAM (ESI=canonical OAM, EAX=80, EBX=24)
; each frame — the port renders OBJ from a projected shadow, not raw wShadowOAM.
;
; Build: nasm -f coff -I include/ -I . -o splash.o splash.asm

bits 32

%include "gb_memmap.inc"      ; OAM_PRIO / OAM_PAL1 / OAM_HIGH_PALS / OAM_XFLIP
%include "gfx_macros.inc"     ; dbsprite (== pret macros/gfx.asm:dbsprite)

section .data
align 4

; Shooting-star + Game Freak logo tile graphics (pret INCBINs). GameFreakIntro =
; gamefreak_presents (13t) + gamefreak_logo (6t) + blank (1t); FallingStar = 1 tile.
global GameFreakIntro
%include "assets/gamefreak_intro_2bpp.inc"   ; GameFreakIntro
global FallingStar
%include "assets/falling_star_2bpp.inc"      ; FallingStar

; --- OAM tables (pret engine/movie/splash.asm, dbsprite verbatim) ---

; The Game Freak logo: 16 OBJ (tiles $80-$93), copied to wShadowOAMSprite24.
global GameFreakLogoOAMData
global GameFreakLogoOAMDataEnd
GameFreakLogoOAMData:
    dbsprite 10,  9,  0,  0, 0x8d, 0
    dbsprite 11,  9,  0,  0, 0x8e, 0
    dbsprite 10, 10,  0,  0, 0x8f, 0
    dbsprite 11, 10,  0,  0, 0x90, 0
    dbsprite 10, 11,  0,  0, 0x91, 0
    dbsprite 11, 11,  0,  0, 0x92, 0
    dbsprite  6, 12,  0,  0, 0x80, 0
    dbsprite  7, 12,  0,  0, 0x81, 0
    dbsprite  8, 12,  0,  0, 0x82, 0
    dbsprite  9, 12,  0,  0, 0x83, 0
    dbsprite 10, 12,  0,  0, 0x93, 0
    dbsprite 11, 12,  0,  0, 0x84, 0
    dbsprite 12, 12,  0,  0, 0x85, 0
    dbsprite 13, 12,  0,  0, 0x83, 0
    dbsprite 14, 12,  0,  0, 0x81, 0
    dbsprite 15, 12,  0,  0, 0x86, 0
GameFreakLogoOAMDataEnd:

; The big shooting star: 4 OBJ (tiles $a0/$a1, x-flipped pairs), copied to wShadowOAM.
global GameFreakShootingStarOAMData
global GameFreakShootingStarOAMDataEnd
GameFreakShootingStarOAMData:
    dbsprite 20,  0,  0,  0, 0xa0, OAM_PAL1 | OAM_HIGH_PALS
    dbsprite 21,  0,  0,  0, 0xa0, OAM_PAL1 | OAM_HIGH_PALS | OAM_XFLIP
    dbsprite 20,  1,  0,  0, 0xa1, OAM_PAL1 | OAM_HIGH_PALS
    dbsprite 21,  1,  0,  0, 0xa1, OAM_PAL1 | OAM_HIGH_PALS | OAM_XFLIP
GameFreakShootingStarOAMDataEnd:

; The small-stars template (tile $a2), copied 24× off-screen then animated.
global SmallStarsOAM
global SmallStarsOAMEnd
SmallStarsOAM:
    dbsprite  0,  0,  0,  0, 0xa2, OAM_PRIO | OAM_PAL1
SmallStarsOAMEnd:

; Wave dispatch — a code-address table (stays in .asm per the B-phase convention).
global SmallStarsWaveCoordsPointerTable
SmallStarsWaveCoordsPointerTable:
    dd SmallStarsWave1Coords
    dd SmallStarsWave2Coords
    dd SmallStarsWave3Coords
    dd SmallStarsWave4Coords
    dd SmallStarsEmptyWave
    dd SmallStarsEmptyWave

; The stars fall in 4 waves of 4 OAM entries; each array is the Y,X of each entry.
global SmallStarsWave1Coords
SmallStarsWave1Coords:
    db 0x68, 0x30
    db 0x05, 0x68
    db 0x40, 0x05
    db 0x68, 0x58
    db 0x04, 0x68
    db 0x78, 0x07
global SmallStarsWave2Coords
SmallStarsWave2Coords:
    db 0x68, 0x38
    db 0x05, 0x68
    db 0x48, 0x06
    db 0x68, 0x60
    db 0x04, 0x68
    db 0x70, 0x07
global SmallStarsWave3Coords
SmallStarsWave3Coords:
    db 0x68, 0x34
    db 0x05, 0x68
    db 0x4c, 0x06
    db 0x68, 0x54
    db 0x06, 0x68
    db 0x64, 0x07
global SmallStarsWave4Coords
SmallStarsWave4Coords:
    db 0x68, 0x3c
    db 0x05, 0x68
    db 0x5c, 0x04
    db 0x68, 0x6c
    db 0x07, 0x68
    db 0x74, 0x07
global SmallStarsEmptyWave
SmallStarsEmptyWave:
    db 0xFF                              ; -1 = end
