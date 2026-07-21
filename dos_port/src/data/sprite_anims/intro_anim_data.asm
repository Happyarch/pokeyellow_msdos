; intro_anim_data.asm — the Yellow intro's animated-object immutable data.
;
; Faithful mirror of pret's three animated-object tables:
;   data/sprite_anims/intro_frames.asm  → YellowIntro_AnimatedObjectFramesData
;   data/sprite_anims/intro_oam.asm     → YellowIntro_AnimatedObjectOAMData
;   engine/movie/intro_yellow.asm       → YellowIntro_AnimatedObjectSpawnStateData
; (relocated into one file so the whole blob shares a single GB base; the pret
; labels are preserved — see pret_label_allowlist.json.)
;
; Pointer model (see gb_memmap.inc, animated_objects.asm): these are the
; Spawn/Frames/OAMData GB-pointer tables. The engine reads them at [ebp+ptr]
; with byte-identical pret arithmetic, so the blob is assembled flat with its
; internal pointers pre-biased to the GB base W_INTRO_ANIM_DATA and copied
; flat→GB once at intro init by CopyYellowIntroAnimatedObjectData. The db bytes
; are byte-for-byte pret; only the `dw` pointers differ (GB-base-relative here vs
; ROM labels in pret). The frame macros resolve as: `frame t,d` = db t,d;
; endanim = 0xff; dorestart = 0xfe; delanim = 0xfc; `dbw d,p` = db d / dw p.
;
; Build: nasm -f coff -I include/ -I . -o intro_anim_data.o \
;        src/data/sprite_anims/intro_anim_data.asm

bits 32

%include "gb_memmap.inc"

; GB address of a label inside the blob (pre-biased so [ebp+ptr] resolves after
; the flat→GB copy).
%define GBPTR(l) (W_INTRO_ANIM_DATA + ((l) - IntroAnimDataBlob))

global YellowIntro_AnimatedObjectFramesData
global YellowIntro_AnimatedObjectOAMData
global YellowIntro_AnimatedObjectSpawnStateData
global IntroAnimDataBlob, IntroAnimDataBlobEnd
global CopyYellowIntroAnimatedObjectData

section .data

IntroAnimDataBlob:

; --- Frames table (pret data/sprite_anims/intro_frames.asm) ---
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

; --- OAM table (pret data/sprite_anims/intro_oam.asm) ---
YellowIntro_AnimatedObjectOAMData:
    db 0x00
    dw GBPTR(Unkn_fa179)
    db 0x96
    dw GBPTR(Unkn_fa17e)
    db 0x98
    dw GBPTR(Unkn_fa17e)
    db 0x9a
    dw GBPTR(Unkn_fa17e)
    db 0x0c
    dw GBPTR(Unkn_fa18f)
    db 0x0e
    dw GBPTR(Unkn_fa18f)
    db 0x3c
    dw GBPTR(Unkn_fa18f)
    db 0x60
    dw GBPTR(Unkn_fa1b0)
    db 0x70
    dw GBPTR(Unkn_fa1b0)
    db 0x80
    dw GBPTR(Unkn_fa1b0)
    db 0x90
    dw GBPTR(Unkn_fa201)
    db 0x00
    dw GBPTR(Unkn_fa201)
    db 0x06
    dw GBPTR(Unkn_fa201)
    db 0xc6
    dw GBPTR(Unkn_fa292)
    db 0x6d
    dw GBPTR(Unkn_fa2f7)
    db 0xf0
    dw GBPTR(Unkn_fa308)
    db 0xf4
    dw GBPTR(Unkn_fa308)
    db 0xf8
    dw GBPTR(Unkn_fa308)
    db 0x9c
    dw GBPTR(Unkn_fa329)
    db 0xec
    dw GBPTR(Unkn_fa329)

Unkn_fa179:
    db 1
    db 0xfc, 0xfc, 0x00, 0x00
Unkn_fa17e:
    db 4
    db 0xf8, 0xf8, 0x00, 0x00
    db 0xf8, 0x00, 0x01, 0x00
    db 0x00, 0xf8, 0x10, 0x00
    db 0x00, 0x00, 0x11, 0x00
Unkn_fa18f:
    db 8
    db 0xf0, 0xf8, 0x00, 0x00
    db 0xf0, 0x00, 0x01, 0x00
    db 0xf8, 0xf8, 0x10, 0x00
    db 0xf8, 0x00, 0x11, 0x00
    db 0x00, 0xf8, 0x20, 0x00
    db 0x00, 0x00, 0x20, 0x20
    db 0x08, 0xf8, 0x21, 0x00
    db 0x08, 0x00, 0x21, 0x20
Unkn_fa1b0:
    db 20
    db 0xe8, 0xf8, 0x00, 0x00
    db 0xe8, 0x00, 0x01, 0x00
    db 0xf0, 0xf8, 0x02, 0x00
    db 0xf0, 0x00, 0x03, 0x00
    db 0xf8, 0xf0, 0x04, 0x00
    db 0xf8, 0xf8, 0x05, 0x00
    db 0xf8, 0x00, 0x06, 0x00
    db 0xf8, 0x08, 0x04, 0x20
    db 0x00, 0xf0, 0x07, 0x00
    db 0x00, 0xf8, 0x08, 0x00
    db 0x00, 0x00, 0x08, 0x20
    db 0x00, 0x08, 0x07, 0x20
    db 0x08, 0xf0, 0x09, 0x00
    db 0x08, 0xf8, 0x0a, 0x00
    db 0x08, 0x00, 0x0a, 0x20
    db 0x08, 0x08, 0x09, 0x20
    db 0x10, 0xf0, 0x0b, 0x00
    db 0x10, 0xf8, 0x0c, 0x00
    db 0x10, 0x00, 0x0c, 0x20
    db 0x10, 0x08, 0x0b, 0x20
Unkn_fa201:
    db 36
    db 0xe8, 0xe8, 0x00, 0x00
    db 0xe8, 0xf0, 0x01, 0x00
    db 0xe8, 0xf8, 0x02, 0x00
    db 0xe8, 0x00, 0x03, 0x00
    db 0xe8, 0x08, 0x04, 0x00
    db 0xe8, 0x10, 0x05, 0x00
    db 0xf0, 0xe8, 0x10, 0x00
    db 0xf0, 0xf0, 0x11, 0x00
    db 0xf0, 0xf8, 0x12, 0x00
    db 0xf0, 0x00, 0x13, 0x00
    db 0xf0, 0x08, 0x14, 0x00
    db 0xf0, 0x10, 0x15, 0x00
    db 0xf8, 0xe8, 0x20, 0x00
    db 0xf8, 0xf0, 0x21, 0x00
    db 0xf8, 0xf8, 0x22, 0x00
    db 0xf8, 0x00, 0x23, 0x00
    db 0xf8, 0x08, 0x24, 0x00
    db 0xf8, 0x10, 0x25, 0x00
    db 0x00, 0xe8, 0x30, 0x00
    db 0x00, 0xf0, 0x31, 0x00
    db 0x00, 0xf8, 0x32, 0x00
    db 0x00, 0x00, 0x33, 0x00
    db 0x00, 0x08, 0x34, 0x00
    db 0x00, 0x10, 0x35, 0x00
    db 0x08, 0xe8, 0x40, 0x00
    db 0x08, 0xf0, 0x41, 0x00
    db 0x08, 0xf8, 0x42, 0x00
    db 0x08, 0x00, 0x43, 0x00
    db 0x08, 0x08, 0x44, 0x00
    db 0x08, 0x10, 0x45, 0x00
    db 0x10, 0xe8, 0x50, 0x00
    db 0x10, 0xf0, 0x51, 0x00
    db 0x10, 0xf8, 0x52, 0x00
    db 0x10, 0x00, 0x53, 0x00
    db 0x10, 0x08, 0x54, 0x00
    db 0x10, 0x10, 0x55, 0x00
Unkn_fa292:
    db 25
    db 0xec, 0xf0, 0x00, 0x00
    db 0xec, 0xf8, 0x01, 0x00
    db 0xec, 0x00, 0x02, 0x00
    db 0xec, 0x08, 0x03, 0x00
    db 0xec, 0x10, 0x04, 0x00
    db 0xf4, 0xf0, 0x05, 0x00
    db 0xf4, 0xf8, 0x06, 0x00
    db 0xf4, 0x00, 0x07, 0x00
    db 0xf4, 0x08, 0x08, 0x00
    db 0xf4, 0x10, 0x09, 0x00
    db 0xfc, 0xf0, 0x10, 0x00
    db 0xfc, 0xf8, 0x11, 0x00
    db 0xfc, 0x00, 0x12, 0x00
    db 0xfc, 0x08, 0x13, 0x00
    db 0xfc, 0x10, 0x14, 0x00
    db 0x04, 0xf0, 0x15, 0x00
    db 0x04, 0xf8, 0x16, 0x00
    db 0x04, 0x00, 0x17, 0x00
    db 0x04, 0x08, 0x18, 0x00
    db 0x04, 0x10, 0x19, 0x00
    db 0x0c, 0xf0, 0x20, 0x00
    db 0x0c, 0xf8, 0x21, 0x00
    db 0x0c, 0x00, 0x22, 0x00
    db 0x0c, 0x08, 0x23, 0x00
    db 0x0c, 0x10, 0x24, 0x00
Unkn_fa2f7:
    db 4
    db 0xfc, 0xf0, 0x00, 0x00
    db 0xfc, 0xf8, 0x01, 0x00
    db 0xfc, 0x00, 0x01, 0x20
    db 0xfc, 0x08, 0x00, 0x20
Unkn_fa308:
    db 8
    db 0xf8, 0xe8, 0x00, 0x10
    db 0xf8, 0xf0, 0x01, 0x10
    db 0x00, 0xe8, 0x02, 0x10
    db 0x00, 0xf0, 0x03, 0x10
    db 0xf8, 0x08, 0x01, 0x30
    db 0xf8, 0x10, 0x00, 0x30
    db 0x00, 0x08, 0x03, 0x30
    db 0x00, 0x10, 0x02, 0x30
Unkn_fa329:
    db 12
    db 0xf8, 0xd8, 0x00, 0x10
    db 0xf8, 0xe0, 0x01, 0x10
    db 0xf8, 0xe8, 0x02, 0x10
    db 0x00, 0xd8, 0x10, 0x10
    db 0x00, 0xe0, 0x11, 0x10
    db 0x00, 0xe8, 0x12, 0x10
    db 0xf8, 0x10, 0x02, 0x30
    db 0xf8, 0x18, 0x01, 0x30
    db 0xf8, 0x20, 0x00, 0x30
    db 0x00, 0x10, 0x12, 0x30
    db 0x00, 0x18, 0x11, 0x30
    db 0x00, 0x20, 0x10, 0x30

; --- Spawn-state table (pret intro_yellow.asm) ---
; Each entry: db FramesetID, AnimSeqID(callback), unused. Indexed by spawn id.
YellowIntro_AnimatedObjectSpawnStateData:
    db 0x00, 0x00, 0x00
    db 0x01, 0x01, 0x00
    db 0x02, 0x01, 0x00
    db 0x03, 0x01, 0x00
    db 0x04, 0x02, 0x00
    db 0x05, 0x03, 0x00
    db 0x06, 0x04, 0x00
    db 0x07, 0x01, 0x00
    db 0x08, 0x05, 0x00
    db 0x09, 0x01, 0x00
    db 0x0a, 0x01, 0x00

IntroAnimDataBlobEnd:

section .text

; ---------------------------------------------------------------------------
; CopyYellowIntroAnimatedObjectData — port-only: stage the immutable blob from
; the program image (flat .data) into GB space at [ebp+W_INTRO_ANIM_DATA], so
; the GB-base-relative pointers inside it resolve under [ebp+ptr]. pret keeps
; this data ROM-resident; the port has no GB-space ROM window for it, so it is
; copied once at intro init (the same flat→GB staging LoadShootingStarGraphics
; and GetDefaultName use). Clobbers nothing (pushad/popad).
; ---------------------------------------------------------------------------
CopyYellowIntroAnimatedObjectData:
    pushad
    mov esi, IntroAnimDataBlob                     ; flat program-image source
    lea edi, [ebp + W_INTRO_ANIM_DATA]             ; GB-space destination
    mov ecx, IntroAnimDataBlobEnd - IntroAnimDataBlob
    rep movsb
    popad
    ret

%ifdef DEBUG_CINEMATIC_ANIMOBJ
; ---------------------------------------------------------------------------
; RunAnimObjectTest — B1.3 lifecycle harness for the animated-object engine.
; Stages the real intro data, sets the port table pointers + a local no-op
; jumptable (all callbacks = ret, so the engine's frame-script interpreter is
; exercised without B3's real callbacks), spawns one object, and republishes
; the projected shadow OAM every frame. AUTOKEY dumps FRAME.BIN mid-run.
;
; Verifies: spawn→run→OAM-stamp, projected native positions (= canonical +
; (80,24)), and surface clipping (unused/edge OBJ never paint the matte).
; ---------------------------------------------------------------------------
extern MovieBeginSurface, ClearObjectAnimationBuffers, SpawnAnimatedObject
extern RunObjectAnimations, PublishProjectedOAM, DelayFrame
extern MaskAllAnimatedObjectStructs
extern g_tilecache_dirty
extern YellowIntro_AnimatedObjectJumptable    ; B3.1 real callbacks
global RunAnimObjectTest

RunAnimObjectTest:
    call MovieBeginSurface                          ; black matte surface + g_obj_clip
    mov byte [ebp + IO_OBP0], 0xe4                  ; visible OBJ palettes (color 3 = dark)
    mov byte [ebp + IO_OBP1], 0xe4
    ; fill the OBJ tile bank solid so whatever tile ids the object uses render
    mov al, 0xff
    lea edi, [ebp + GB_VCHARS0]
    mov ecx, 0x1000                                 ; 256 tiles x 16 bytes
    rep stosb
    mov byte [g_tilecache_dirty], 1                 ; VRAM tiles changed → rebuild cache
    ; stage the immutable data into GB space
    call CopyYellowIntroAnimatedObjectData
    ; clear the object block FIRST, then set the table pointers — the four
    ; pointers live inside wAnimatedObjectsData, so ClearObjectAnimationBuffers
    ; would wipe them if set earlier (pret sets them after the clear too, in
    ; InitYellowIntroGFXAndMusic → LoadYellowIntroObjectAnimationDataPointers).
    call ClearObjectAnimationBuffers
    call MaskAllAnimatedObjectStructs               ; masked slots must produce no OAM
    mov word [ebp + wAnimatedObjectSpawnStateDataPointer], GBPTR(YellowIntro_AnimatedObjectSpawnStateData)
    mov word [ebp + wAnimatedObjectFramesDataPointer], GBPTR(YellowIntro_AnimatedObjectFramesData)
    mov word [ebp + wAnimatedObjectOAMDataPointer], GBPTR(YellowIntro_AnimatedObjectOAMData)
    mov dword [ebp + wAnimatedObjectJumptablePointer], YellowIntro_AnimatedObjectJumptable
    ; spawn object 4 → frameset 4 (36-OBJ block), animseq 2 = Func_fa008, which
    ; slides XCoord left toward 0x58. Dumping early vs late shows it move left —
    ; a real callback exercised end-to-end (B3.1).
    mov al, 4                                       ; spawn-state index → frameset 4, animseq 2
    mov dh, 0x60                                    ; Y coord
    mov dl, 0x80                                    ; X coord (slides down to 0x58)
    call SpawnAnimatedObject
.loop:
    mov byte [ebp + wCurrentAnimatedObjectOAMBufferOffset], 0
    call RunObjectAnimations
    movzx ecx, byte [ebp + wCurrentAnimatedObjectOAMBufferOffset]
    shr ecx, 2                                      ; OBJ count = shadow-OAM cursor / 4
    mov esi, W_SHADOW_OAM
    mov eax, 80                                     ; projection X offset (surface at col 10)
    mov ebx, 24                                     ; projection Y offset (surface at row 3)
    call PublishProjectedOAM
    call DelayFrame
    jmp .loop
%endif
