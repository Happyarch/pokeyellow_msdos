; surfing_pikachu_oam.asm — Surfing Pikachu minigame animated-object OAM definitions.
; Mirror of pret data/sprite_anims/surfing_pikachu_oam.asm.
;
; Pointer model (see animated_objects.asm): the engine reads this table at
; [ebp + wAnimatedObjectOAMDataPointer] with byte-identical pret arithmetic, so
; the table is assembled with its internal dw pointers pre-biased to the GB
; staging base W_SURF_OAM_DATA and copied flat→GB at minigame init.
; The db bytes are byte-for-byte pret; only the dw pointers differ (GB-base-relative
; here vs ROM labels in pret). Table entries are pret `dbw d, p` = db d / dw p.

bits 32

%include "gb_memmap.inc"

; GB address of a label in this table after the flat→GB copy.
%define GBPTR(l) (W_SURF_OAM_DATA + ((l) - SurfingPikachuOAMData))

global SurfingPikachuOAMData
global SurfingPikachuOAMDataEnd

section .data

SurfingPikachuOAMData:
    db 0x00
    dw GBPTR(.SingleTile) ; referenced but unused
    db 0x00
    dw GBPTR(.SurfingPikachu)
    db 0x36
    dw GBPTR(.SurfingPikachu)
    db 0x03
    dw GBPTR(.SurfingPikachu)
    db 0x39
    dw GBPTR(.SurfingPikachu)
    db 0x06
    dw GBPTR(.SurfingPikachu)
    db 0x3c
    dw GBPTR(.SurfingPikachu)
    db 0x09
    dw GBPTR(.SurfingPikachu)
    db 0x60
    dw GBPTR(.SurfingPikachu)
    db 0x0c
    dw GBPTR(.SurfingPikachu)
    db 0x63
    dw GBPTR(.SurfingPikachu)
    db 0x30
    dw GBPTR(.SurfingPikachu)
    db 0x66
    dw GBPTR(.SurfingPikachu)
    db 0x33
    dw GBPTR(.SurfingPikachu)
    db 0x69
    dw GBPTR(.SurfingPikachu)
    db 0x6c
    dw GBPTR(.UnusedFrontPikachu)
    db 0x9c
    dw GBPTR(.UnusedBackPikachu)
    db 0xa0
    dw GBPTR(.ResultsPikachu)
    db 0xa3
    dw GBPTR(.ResultsPikachu)
    db 0xa7
    dw GBPTR(.SmallSplash)
    db 0xa8
    dw GBPTR(.LargeSplash)
    db 0x98
    dw GBPTR(.EmptySurfboard) ; when Pikachu has fallen off
    db 0xe0
    dw GBPTR(.StartText)
    db 0xe6
    dw GBPTR(.GoalText) ; referenced but unused
    db 0xca
    dw GBPTR(.OhNoText)
    db 0xa7
    dw GBPTR(.WaterSpray)
    db 0x00
    dw GBPTR(.Plus50Pts)
    db 0x00
    dw GBPTR(.Plus150Pts)
    db 0x00
    dw GBPTR(.Plus350Pts)
    db 0x00
    dw GBPTR(.Plus750Pts)
    db 0x00
    dw GBPTR(.Plus180Pts)
    db 0x00
    dw GBPTR(.Plus500Pts)
    db 0x80
    dw GBPTR(.IntroPikachu)
    db 0x84
    dw GBPTR(.IntroPikachu)
    db 0x88
    dw GBPTR(.IntroPikachu)
    db 0x8c
    dw GBPTR(.IntroPikachu)

.SingleTile:
    db 1
    db -4, -4, 0x00, 0

.SurfingPikachu:
.UnusedFrontPikachu:
.UnusedBackPikachu:
.ResultsPikachu:
    db 9
    db -12, -12, 0x00, 0
    db -12,  -4, 0x01, 0
    db -12,   4, 0x02, 0
    db  -4, -12, 0x10, 0
    db  -4,  -4, 0x11, 0
    db  -4,   4, 0x12, 0
    db   4, -12, 0x20, 0
    db   4,  -4, 0x21, 0
    db   4,   4, 0x22, 0

.StartText:
.GoalText:
.OhNoText:
    db 12
    db  -8, -24, 0x00, 0
    db  -8, -16, 0x01, 0
    db  -8,  -8, 0x02, 0
    db  -8,   0, 0x03, 0
    db  -8,   8, 0x04, 0
    db  -8,  16, 0x05, 0
    db   0, -24, 0x10, 0
    db   0, -16, 0x11, 0
    db   0,  -8, 0x12, 0
    db   0,   0, 0x13, 0
    db   0,   8, 0x14, 0
    db   0,  16, 0x15, 0

.WaterSpray:
    db 3
    db  -4,  11, 0x00, OAM_PAL1
    db   4,   3, 0x0f, OAM_PAL1
    db   4,  11, 0x10, OAM_PAL1

.SmallSplash:
    db 6
    db  -4, -16, 0x00, OAM_PAL1 | OAM_XFLIP
    db  -4,   8, 0x00, OAM_PAL1
    db   4, -16, 0x10, OAM_PAL1 | OAM_XFLIP
    db   4,  -8, 0x0f, OAM_PAL1 | OAM_XFLIP
    db   4,   0, 0x0f, OAM_PAL1
    db   4,   8, 0x10, OAM_PAL1

.LargeSplash:
    db 12
    db -12, -16, 0x00, OAM_PAL1
    db -12,  -8, 0x01, OAM_PAL1
    db -12,   0, 0x01, OAM_PAL1 | OAM_XFLIP
    db -12,   8, 0x00, OAM_PAL1 | OAM_XFLIP
    db  -4, -16, 0x10, OAM_PAL1
    db  -4,  -8, 0x11, OAM_PAL1
    db  -4,   0, 0x11, OAM_PAL1 | OAM_XFLIP
    db  -4,   8, 0x10, OAM_PAL1 | OAM_XFLIP
    db   4, -16, 0x20, OAM_PAL1
    db   4,  -8, 0x21, OAM_PAL1
    db   4,   0, 0x21, OAM_PAL1 | OAM_XFLIP
    db   4,   8, 0x20, OAM_PAL1 | OAM_XFLIP

.EmptySurfboard:
    db 3
    db   4, -12, 0x00, 0
    db   4,  -4, 0x01, 0
    db   4,   4, 0x02, 0

.Plus50Pts:
    db 3
    db  -4, -12, 0xbf, 0
    db  -4,  -4, 0xd5, 0
    db  -4,   4, 0xd0, 0

.Plus150Pts:
    db 4
    db  -4, -16, 0xbf, 0
    db  -4,  -8, 0xd1, 0
    db  -4,   0, 0xd5, 0
    db  -4,   8, 0xd0, 0

.Plus350Pts:
    db 4
    db  -4, -16, 0xbf, 0
    db  -4,  -8, 0xd3, 0
    db  -4,   0, 0xd5, 0
    db  -4,   8, 0xd0, 0

.Plus750Pts:
    db 4
    db  -4, -16, 0xbf, 0
    db  -4,  -8, 0xd7, 0
    db  -4,   0, 0xd5, 0
    db  -4,   8, 0xd0, 0

.Plus180Pts:
    db 4
    db  -4, -16, 0xbf, 0
    db  -4,  -8, 0xd1, 0
    db  -4,   0, 0xd8, 0
    db  -4,   8, 0xd0, 0

.Plus500Pts:
    db 4
    db  -4, -16, 0xbf, 0
    db  -4,  -8, 0xd5, 0
    db  -4,   0, 0xd0, 0
    db  -4,   8, 0xd0, 0

.IntroPikachu:
    db 12
    db -12, -16, 0x03, OAM_XFLIP
    db -12,  -8, 0x02, OAM_XFLIP
    db -12,   0, 0x01, OAM_XFLIP
    db -12,   8, 0x00, OAM_XFLIP
    db  -4, -16, 0x13, OAM_XFLIP
    db  -4,  -8, 0x12, OAM_XFLIP
    db  -4,   0, 0x11, OAM_XFLIP
    db  -4,   8, 0x10, OAM_XFLIP
    db   4, -16, 0x23, OAM_XFLIP
    db   4,  -8, 0x22, OAM_XFLIP
    db   4,   0, 0x21, OAM_XFLIP
    db   4,   8, 0x20, OAM_XFLIP

SurfingPikachuOAMDataEnd:

; Static assert: the assembled size must equal 0x1BE (446 bytes).
times ((SurfingPikachuOAMDataEnd - SurfingPikachuOAMData) - 0x1BE) db 0
times (0x1BE - (SurfingPikachuOAMDataEnd - SurfingPikachuOAMData)) db 0
