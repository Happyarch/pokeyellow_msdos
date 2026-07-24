; intro_frames.asm — Yellow-intro animated-object frame scripts.
; Mirror of pret data/sprite_anims/intro_frames.asm (INCLUDEd by
; engine/movie/intro_yellow.asm into bank $3E, ROM $fa0ea-$fa13d).
;
; Pointer model (see animated_objects.asm): the engine reads this table at
; [ebp + wAnimatedObjectFramesDataPointer] with byte-identical pret arithmetic,
; so the table is assembled with its internal dw pointers pre-biased to the GB
; staging base W_INTRO_FRAMES_DATA and copied flat→GB at intro init by
; CopyYellowIntroAnimatedObjectData (engine/movie/intro_yellow.asm), which
; composes the frames / OAM / spawn regions back-to-back exactly as pret's ROM
; lays them out. The db bytes are byte-for-byte pret; only the dw pointers
; differ (GB-base-relative here vs ROM labels in pret). Macro semantics
; (macros/scripts/gfx_anims.asm): `frame t,d` = db t,d; endanim = 0xff;
; dorestart = 0xfe.

bits 32

%include "gb_memmap.inc"

; GB address of a label in this table after the flat→GB copy.
%define GBPTR(l) (W_INTRO_FRAMES_DATA + ((l) - YellowIntro_AnimatedObjectFramesData))

global YellowIntro_AnimatedObjectFramesData
global YellowIntro_AnimatedObjectFramesDataEnd

section .data

YellowIntro_AnimatedObjectFramesData:
    dw GBPTR(Unkn_fa100)
    dw GBPTR(Unkn_fa103)
    dw GBPTR(Unkn_fa10a)
    dw GBPTR(Unkn_fa111)
    dw GBPTR(Unkn_fa118)
    dw GBPTR(Unkn_fa11b)
    dw GBPTR(Unkn_fa11e)
    dw GBPTR(Unkn_fa121)
    dw GBPTR(Unkn_fa124)
    dw GBPTR(Unkn_fa127)
    dw GBPTR(Unkn_fa138)

Unkn_fa100:
    db 0x00, 32          ; frame 0x00, 32
    db 0xff              ; endanim
Unkn_fa103:
    db 0x01, 4
    db 0x02, 4
    db 0x03, 4
    db 0xfe              ; dorestart
Unkn_fa10a:
    db 0x04, 4
    db 0x05, 4
    db 0x06, 4
    db 0xfe
Unkn_fa111:
    db 0x07, 4
    db 0x08, 4
    db 0x09, 4
    db 0xfe
Unkn_fa118:
    db 0x0a, 32
    db 0xff
Unkn_fa11b:
    db 0x0b, 32
    db 0xff
Unkn_fa11e:
    db 0x0c, 32
    db 0xff
Unkn_fa121:
    db 0x0d, 32
    db 0xff
Unkn_fa124:
    db 0x0e, 32
    db 0xff
Unkn_fa127:
    db 0x0f, 31
    db 0x11, 2
    db 0x0f, 2
    db 0x11, 2
    db 0x0f, 31
    db 0x11, 2
    db 0x0f, 23
    db 0x10, 32
    db 0xff
Unkn_fa138:
    db 0x12, 4
    db 0x13, 4
    db 0xfe

YellowIntro_AnimatedObjectFramesDataEnd:

; Static assert: the assembled size must equal the gb_memmap.inc region delta
; (W_INTRO_OAM_DATA is placed hard against this table, as in pret ROM). If the
; table ever changes size without the constants moving, one of these `times`
; goes negative and the assembly fails.
times ((YellowIntro_AnimatedObjectFramesDataEnd - YellowIntro_AnimatedObjectFramesData) - (W_INTRO_OAM_DATA - W_INTRO_FRAMES_DATA)) db 0
times ((W_INTRO_OAM_DATA - W_INTRO_FRAMES_DATA) - (YellowIntro_AnimatedObjectFramesDataEnd - YellowIntro_AnimatedObjectFramesData)) db 0
