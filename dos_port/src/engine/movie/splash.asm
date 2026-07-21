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

extern UpdateCGBPal_OBP0             ; home/cgb_palettes.asm — commit rOBP0 to the DAC
extern UpdateCGBPal_OBP1             ; home/cgb_palettes.asm
extern CopyVideoData                 ; home/copy2.asm — ESI=VRAM dest, EDX=flat src, BL=tiles
extern MoveAnimationTiles1           ; engine/overworld/cut.asm — battle move-anim tile sheet

section .text

; ---------------------------------------------------------------------------
; LoadShootingStarGraphics — set the star OBP palettes, load the star tiles into
; vChars1, and prime the logo + shooting-star shadow OAM. Source:
; engine/movie/splash.asm:LoadShootingStarGraphics.
;
; The star tiles time-share vChars1 ($8800, the text font) exactly as pret does —
; there is no text during the splash. The OAM tables are flat program-image data
; (this file's .data), so the two OAM copies are inline flat->GB rep movsb rather
; than pret's `call/jp CopyData` (the port's CopyData is EBP-relative on both ends,
; so a flat source cannot go through it — the GetDefaultName / PrepareOakSpeech path).
;
; DEVIATION{class=data-model; pret=engine/movie/splash.asm:LoadShootingStarGraphics; behavior=the two OAM-table copies (CopyData/jp CopyData) become inline flat->GB rep movsb; evidence=GameFreakLogoOAMData / GameFreakShootingStarOAMData are program-image data and the port CopyData adds EBP to BOTH ends; lifetime=permanent flat-memory model}
;
; In: EBP = GB base. Clobbers EAX/ECX/ESI/EDI (BH/BL via CopyVideoData).
; ---------------------------------------------------------------------------
global LoadShootingStarGraphics
LoadShootingStarGraphics:
    mov byte [ebp + IO_OBP0], 0xF9        ; ld a,$f9 / ldh [rOBP0], a
    mov byte [ebp + IO_OBP1], 0xA4        ; ld a,$a4 / ldh [rOBP1], a
    call UpdateCGBPal_OBP0
    call UpdateCGBPal_OBP1
    ; star tiles (from the battle move-anim set) -> vChars1 $20 / $21
    mov esi, GB_VFONT + 0x20 * TILE_SIZE  ; ld hl, vChars1 tile $20
    mov edx, MoveAnimationTiles1 + 3 * TILE_SIZE  ; ld de, MoveAnimationTiles1 tile 3
    mov bl, 1                             ; ld c, 1 (bh = bank, no-op)
    call CopyVideoData
    mov esi, GB_VFONT + 0x21 * TILE_SIZE
    mov edx, MoveAnimationTiles1 + 19 * TILE_SIZE ; MoveAnimationTiles1 tile 19
    mov bl, 1
    call CopyVideoData
    ; falling-star tile -> vChars1 $22
    mov esi, GB_VFONT + 0x22 * TILE_SIZE
    mov edx, FallingStar
    mov bl, FALLINGSTAR_TILES             ; (FallingStarEnd - FallingStar) / TILE_SIZE
    call CopyVideoData
    ; prime the logo OAM (24..) and the shooting-star OAM (0..) — flat -> GB shadow OAM
    mov esi, GameFreakLogoOAMData
    lea edi, [ebp + W_SHADOW_OAM + 24 * 4] ; wShadowOAMSprite24
    mov ecx, GameFreakLogoOAMDataEnd - GameFreakLogoOAMData
    rep movsb
    mov esi, GameFreakShootingStarOAMData
    lea edi, [ebp + W_SHADOW_OAM]
    mov ecx, GameFreakShootingStarOAMDataEnd - GameFreakShootingStarOAMData
    rep movsb
    ret

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
