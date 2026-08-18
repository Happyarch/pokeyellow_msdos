; surfing_pikachu_frames.asm — Surfing Pikachu minigame animated-object frame scripts.
; Mirror of pret data/sprite_anims/surfing_pikachu_frames.asm.
;
; Pointer model (see animated_objects.asm): the engine reads this table at
; [ebp + wAnimatedObjectFramesDataPointer] with byte-identical pret arithmetic,
; so the table is assembled with its internal dw pointers pre-biased to the GB
; staging base W_SURF_FRAMES_DATA and copied flat→GB at minigame init.
; The db bytes are byte-for-byte pret; only the dw pointers differ (GB-base-relative
; here vs ROM labels in pret). Macro semantics (macros/scripts/gfx_anims.asm):
; `frame t,d` = db t,d; `frame t,d,fl1,fl2` = db t,(d | (fl1<<1) | (fl2<<1));
; `endanim` = 0xff; `dorestart` = 0xfe; `dorepeat n` = 0xfd, n; `delanim` = 0xfc.

bits 32

%include "gb_memmap.inc"

; GB address of a label in this table after the flat→GB copy.
%define GBPTR(l) (W_SURF_FRAMES_DATA + ((l) - SurfingPikachuFrames))

global SurfingPikachuFrames
global SurfingPikachuFramesEnd

section .data

SurfingPikachuFrames:
    dw GBPTR(.SingleTile)
    dw GBPTR(.SurfingAngle00)
    dw GBPTR(.SurfingAngle01)
    dw GBPTR(.SurfingAngle02)
    dw GBPTR(.SurfingAngle03)
    dw GBPTR(.SurfingAngle04)
    dw GBPTR(.SurfingAngle05)
    dw GBPTR(.SurfingAngle06)
    dw GBPTR(.SurfingAngle07)
    dw GBPTR(.SurfingAngle08)
    dw GBPTR(.SurfingAngle09)
    dw GBPTR(.SurfingAngle10)
    dw GBPTR(.SurfingAngle11)
    dw GBPTR(.SurfingAngle12)
    dw GBPTR(.SurfingAngle13)
    dw GBPTR(.SmallSplash)
    dw GBPTR(.LargeSplash)
    dw GBPTR(.StartText)
    dw GBPTR(.GoalText)
    dw GBPTR(.OhNoText)
    dw GBPTR(.WaterSpray)
    dw GBPTR(.Plus50Pts)
    dw GBPTR(.Plus150Pts)
    dw GBPTR(.Plus350Pts)
    dw GBPTR(.Plus750Pts)
    dw GBPTR(.Plus180Pts)
    dw GBPTR(.Plus500Pts)
    dw GBPTR(.IntroPikachu)

.SingleTile:
    db 0x00, 32
    db 0xff

.SurfingAngle00:
    db 0x01, 8
    db 0x02, 8
    db 0xfe

.SurfingAngle01:
    db 0x03, 8
    db 0x04, 8
    db 0xfe

.SurfingAngle02:
    db 0x05, 8
    db 0x06, 8
    db 0xfe

.SurfingAngle03:
    db 0x07, 8
    db 0x08, 8
    db 0xfe

.SurfingAngle04:
    db 0x09, 8
    db 0x0a, 8
    db 0xfe

.SurfingAngle05:
    db 0x0b, 8
    db 0x0c, 8
    db 0xfe

.SurfingAngle06:
    db 0x0d, 8
    db 0x0e, 8
    db 0xfe

.SurfingAngle07:
    db 0x01, 0xc8        ; frame $01, 8, OAM_XFLIP, OAM_YFLIP
    db 0x02, 0xc8        ; frame $02, 8, OAM_XFLIP, OAM_YFLIP
    db 0xfe

.SurfingAngle08:
    db 0x03, 0xc8
    db 0x04, 0xc8
    db 0xfe

.SurfingAngle09:
    db 0x05, 0xc8
    db 0x06, 0xc8
    db 0xfe

.SurfingAngle10:
    db 0x07, 0xc8
    db 0x08, 0xc8
    db 0xfe

.SurfingAngle11:
    db 0x09, 0xc8
    db 0x0a, 0xc8
    db 0xfe

.SurfingAngle12:
    db 0x0b, 0xc8
    db 0x0c, 0xc8
    db 0xfe

.SurfingAngle13:
    db 0x0d, 0xc8
    db 0x0e, 0xc8
    db 0xfe

.SmallSplash:
    db 0x11, 7
    db 0x12, 7
    db 0xfe

.LargeSplash:
    db 0x13, 2
    db 0x14, 2
    db 0xfd, 8          ; dorepeat 8
    db 0x15, 2
    db 0xff

.StartText:
    db 0x16, 32
    db 0x16, 32
    db 0xfc              ; delanim

.GoalText:
    db 0x17, 32
    db 0x17, 32
    db 0xfc              ; delanim

.OhNoText:
    db 0x18, 32
    db 0xff

.Plus50Pts:
    db 0x1a, 4
    db 0xfd, 1
    db 0x1a, 3
    db 0xfd, 1
    db 0x1a, 2
    db 0xfd, 1
    db 0x1a, 1
    db 0xfc

.Plus150Pts:
    db 0x1b, 4
    db 0xfd, 1
    db 0x1b, 3
    db 0xfd, 1
    db 0x1b, 2
    db 0xfd, 1
    db 0x1b, 1
    db 0xfc

.Plus350Pts:
    db 0x1c, 4
    db 0xfd, 1
    db 0x1c, 3
    db 0xfd, 1
    db 0x1c, 2
    db 0xfd, 1
    db 0x1c, 1
    db 0xfc

.Plus750Pts:
    db 0x1d, 4
    db 0xfd, 1
    db 0x1d, 3
    db 0xfd, 1
    db 0x1d, 2
    db 0xfd, 1
    db 0x1d, 1
    db 0xfc

.Plus180Pts:
    db 0x1e, 4
    db 0xfd, 1
    db 0x1e, 3
    db 0xfd, 1
    db 0x1e, 2
    db 0xfd, 1
    db 0x1e, 1
    db 0xfc

.Plus500Pts:
    db 0x1f, 4
    db 0xfd, 1
    db 0x1f, 3
    db 0xfd, 1
    db 0x1f, 2
    db 0xfd, 1
    db 0x1f, 1
    db 0xfc

.WaterSpray:
    db 0x19, 1
    db 0xfc

.IntroPikachu:
    db 0x20, 7
    db 0x21, 7
    db 0x22, 7
    db 0x23, 7
    db 0xfe

SurfingPikachuFramesEnd:

; Static assert: the assembled size must equal the gb_memmap.inc region delta
; (W_SURF_OAM_DATA is placed hard against this table, as in pret ROM).
times ((SurfingPikachuFramesEnd - SurfingPikachuFrames) - (W_SURF_OAM_DATA - W_SURF_FRAMES_DATA)) db 0
times ((W_SURF_OAM_DATA - W_SURF_FRAMES_DATA) - (SurfingPikachuFramesEnd - SurfingPikachuFrames)) db 0
