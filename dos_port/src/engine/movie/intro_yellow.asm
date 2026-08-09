; intro_yellow.asm — the complete Yellow intro (menu-intro B3).
;
; Faithful translation of pret engine/movie/intro_yellow.asm: the scene engine
; (PlayIntroScene, InitYellowIntroGFXAndMusic, all 18 YellowIntroScene0..17
; handlers via Jumptable_f9906, Func_fa06e and the flying-Pikachu helpers), the
; animated-object jumptable + behavior callbacks
; (ExecuteCurrentAnimatedObjectCallback via YellowIntro_AnimatedObjectJumptable),
; and the sine helpers, plus the spawn-state table (pret defines it here). The
; frame/OAM tables live in their pret data mirrors
; (src/data/sprite_anims/intro_frames.asm / intro_oam.asm — pret INCLUDEs both
; into this file); CopyYellowIntroAnimatedObjectData composes all three into GB
; space at W_INTRO_ANIM_DATA at intro init.
;
; The pret-only bank thunks Bank3E_CopyData / Bank3E_FillMemory are not defined
; here: Bank3E_CopyData is inlined at its one caller (DEVIATION at
; YellowIntro_Copy8BitSineWave), and Bank3E_FillMemory — pret's in-bank copy of
; home FillMemory, byte-identical logic — is realized by the shared home
; FillMemory (banking; every call site comments the pret name).
;
; Register map (as reached from the engine): EBX = current-struct base (pret BC),
; ESI = HL, EDX = DE, AL = A, EBP = GB base. Struct byte offsets are raw literals
; exactly as pret: 4 XCoord, 5 YCoord, 7 YOffset, b FieldB, c FieldC.
;
; Build: nasm -f coff -I include/ -I . -o intro_yellow.o \
;        src/engine/movie/intro_yellow.asm

bits 32

%include "gb_memmap.inc"

; pret HRAM names for the auto-BG-transfer registers — used so the faithful (inert)
; writes below cross-reference against pret by name (faithdiff matches stores by name).
hAutoBGTransferEnabled equ H_AUTO_BG_TRANSFER_EN
hAutoBGTransferDest    equ H_AUTO_BG_TRANSFER_DEST

global YellowIntro_AnimatedObjectJumptable
global Func_fa007, Func_fa008, Func_fa014, Func_fa02b, Func_fa062
global Func_fa03f, Func_fa051, Func_fa077, Func_fa079, Func_fa08e
global Func_f98a2, Func_f98cb, YellowIntro_NextScene
global LoadYellowIntroObjectAnimationDataPointers
global YellowIntro_SpawnAnimatedObjectAndSavePointer, YellowIntro_MaskCurrentAnimatedObjectStruct
global YellowIntro_SetTimerFor128Frames, YellowIntro_SetTimerFor88Frames
global YellowIntro_CheckFrameTimerDecrement
global YellowIntroScene1, YellowIntroScene5, YellowIntroScene9
global YellowIntroScene13, YellowIntroScene17, YellowIntroScene3
global Func_fa06e, YellowIntroScene0, Func_f98fc, Jumptable_f9906
global InitYellowIntroGFXAndMusic, PlayIntroScene
global YellowIntroScene16, YellowIntro_LoadDMGPalAndIncrementCounter
global YellowIntro_BlankPalsDelay2AndDisableLCD, YellowIntroScene15
global YellowIntro_Copy8BitSineWave, LoadYellowIntroFlyingSpeedBars
global YellowIntro_BlankTileMap, YellowIntro_BlankOAMBuffer, YellowIntro_BlankPalettes
global Func_f9e9a, Func_f9e5f

extern SpawnAnimatedObject, MaskCurrentAnimatedObjectStruct, MaskAllAnimatedObjectStructs
extern DelayFrames, DelayFrame, DisableLCD, FillMemory
extern UpdateCGBPal_BGP, UpdateCGBPal_OBP0, UpdateCGBPal_OBP1
extern CopyVideoData, RunPaletteCommand, PlayMusic, ClearObjectAnimationBuffers
extern YellowIntroPaletteAction      ; engine/gfx/palettes.asm
; The frame/OAM data mirrors (pret INCLUDEs both files into this one); staged
; into GB space by CopyYellowIntroAnimatedObjectData below.
extern YellowIntro_AnimatedObjectFramesData       ; data/sprite_anims/intro_frames.asm
extern YellowIntro_AnimatedObjectOAMData          ; data/sprite_anims/intro_oam.asm
extern MovieBeginSurface, MovieEndSurface, PublishProjectedOAM, JoypadLowSensitivity
extern MovieSyncScroll                            ; movie_projection.asm — H_SCX/H_SCY -> WIN_SRC_X/Y
extern RunObjectAnimations, UpdateMusicCTimes

; --- Cinematic BG surface model (the port's own; documented here once) ----------
; pret writes the GB BG map vBGMap0 ($9800, 32-wide). The port has no such map for
; the cinematic; it composites the BG from the widescreen W_TILEMAP canvas, of which
; MovieMirrorSurface shows the 18x20 window at W_TILEMAP + UI_YELLOW_INTRO_ROW*
; SCREEN_TILES_W + UI_YELLOW_INTRO_COL (row 3, col 10) — cf. title.asm TITLE_ORIGIN.
; So the scenes below mirror pret's vBGMap0 writes as W_TILEMAP writes at this
; origin: a GB coord(col,row) is authored at (col+INTRO_BG_COL, row+INTRO_BG_ROW).
; Row-range (contiguous full-width) fills add only the row part (INTRO_BG_ROW_OFF);
; column-specific writes add the full origin (INTRO_BG_ORIGIN). This is a uniform
; port convention, NOT a per-scene deviation — the scenes carry only plain
; "projected coord" comments, and DEVIATION annotations are reserved for genuine
; behavioural divergences (HAL / data-model / banking).
INTRO_BG_ROW      equ 3                                  ; UI_YELLOW_INTRO_ROW
INTRO_BG_COL      equ 10                                 ; UI_YELLOW_INTRO_COL
INTRO_BG_ROW_OFF  equ INTRO_BG_ROW * SCREEN_TILES_W      ; = 120 (row-only origin)
INTRO_BG_ORIGIN   equ INTRO_BG_ROW_OFF + INTRO_BG_COL    ; = 130 (full origin)

; wShadowOAM per-sprite attribute bytes (wShadowOAM + N*4 + 3). Pret names kept.
%define wShadowOAMSpriteAttr(n) (W_SHADOW_OAM + (n)*4 + 3)
%define wShadowOAMSprite08Attributes wShadowOAMSpriteAttr(8)
%define wShadowOAMSprite14Attributes wShadowOAMSpriteAttr(14)
%define wShadowOAMSprite16Attributes wShadowOAMSpriteAttr(16)
%define wShadowOAMSprite18Attributes wShadowOAMSpriteAttr(18)
%define wShadowOAMSprite19Attributes wShadowOAMSpriteAttr(19)
%define wShadowOAMSprite20Attributes wShadowOAMSpriteAttr(20)
%define wShadowOAMSprite25Attributes wShadowOAMSpriteAttr(25)
%define wShadowOAMSprite26Attributes wShadowOAMSpriteAttr(26)
%define wShadowOAMSprite28Attributes wShadowOAMSpriteAttr(28)

section .text

; ---------------------------------------------------------------------------
; LoadYellowIntroObjectAnimationDataPointers — point the animated-object engine
; at the Yellow-intro tables. MUST run after ClearObjectAnimationBuffers, which
; zeroes the block these pointers live in. Spawn/OAM/Frames are 16-bit GB
; addresses of the staged tables (gb_memmap.inc constants, pret store order);
; the jumptable is a 32-bit flat pointer (B1 data-model split).
; ---------------------------------------------------------------------------
LoadYellowIntroObjectAnimationDataPointers:
    mov word [ebp + wAnimatedObjectSpawnStateDataPointer], W_INTRO_SPAWN_DATA
    mov dword [ebp + wAnimatedObjectJumptablePointer], YellowIntro_AnimatedObjectJumptable
    mov word [ebp + wAnimatedObjectOAMDataPointer], W_INTRO_OAM_DATA
    mov word [ebp + wAnimatedObjectFramesDataPointer], W_INTRO_FRAMES_DATA
    ret

; ---------------------------------------------------------------------------
; Func_f98a2 — scene-7 hook: set the BG-priority bit (OAM attr bit 0) on the
; surfing-Pikachu OBJ so the wave BG draws over them.
; ---------------------------------------------------------------------------
Func_f98a2:
    mov al, [ebp + wShadowOAMSprite08Attributes]
    or al, 0x1
    mov [ebp + wShadowOAMSprite08Attributes], al
    mov al, [ebp + wShadowOAMSprite14Attributes]
    or al, 0x1
    mov [ebp + wShadowOAMSprite14Attributes], al
    mov al, [ebp + wShadowOAMSprite16Attributes]
    or al, 0x1
    mov [ebp + wShadowOAMSprite16Attributes], al
    mov al, [ebp + wShadowOAMSprite18Attributes]
    or al, 0x1
    mov [ebp + wShadowOAMSprite18Attributes], al
    mov al, [ebp + wShadowOAMSprite19Attributes]
    or al, 0x1
    mov [ebp + wShadowOAMSprite19Attributes], al
    ret

; ---------------------------------------------------------------------------
; Func_f98cb — scene-0xb hook: same BG-priority bit on the flying-Pikachu OBJ.
; ---------------------------------------------------------------------------
Func_f98cb:
    mov al, [ebp + wShadowOAMSprite18Attributes]
    or al, 0x1
    mov [ebp + wShadowOAMSprite18Attributes], al
    mov al, [ebp + wShadowOAMSprite19Attributes]
    or al, 0x1
    mov [ebp + wShadowOAMSprite19Attributes], al
    mov al, [ebp + wShadowOAMSprite20Attributes]
    or al, 0x1
    mov [ebp + wShadowOAMSprite20Attributes], al
    mov al, [ebp + wShadowOAMSprite25Attributes]
    or al, 0x1
    mov [ebp + wShadowOAMSprite25Attributes], al
    mov al, [ebp + wShadowOAMSprite26Attributes]
    or al, 0x1
    mov [ebp + wShadowOAMSprite26Attributes], al
    mov al, [ebp + wShadowOAMSprite28Attributes]
    or al, 0x1
    mov [ebp + wShadowOAMSprite28Attributes], al
    ret

; ---------------------------------------------------------------------------
; YellowIntro_NextScene — advance to the next intro scene.
; ---------------------------------------------------------------------------
YellowIntro_NextScene:
    inc byte [ebp + wYellowIntroCurrentScene]      ; ld hl, .. / inc [hl]
    ; vc_hook Reduce_intro_scene_flashing_0E — VC patch hook, no-op in the port
    ret

; ---------------------------------------------------------------------------
; YellowIntro_SpawnAnimatedObjectAndSavePointer — spawn an object (index AL,
; coords DX) and remember its struct base for the scene to mask later.
; ---------------------------------------------------------------------------
YellowIntro_SpawnAnimatedObjectAndSavePointer:
    call SpawnAnimatedObject                        ; EBX = struct base on success
    mov [ebp + wYellowIntroAnimatedObjectStructPointer], bx  ; ld [ptr],c / ld [ptr+1],b
    ret

; ---------------------------------------------------------------------------
; YellowIntro_MaskCurrentAnimatedObjectStruct — mask the saved object.
; ---------------------------------------------------------------------------
YellowIntro_MaskCurrentAnimatedObjectStruct:
    movzx ebx, word [ebp + wYellowIntroAnimatedObjectStructPointer]  ; bc = saved base
    call MaskCurrentAnimatedObjectStruct
    ret

; ---------------------------------------------------------------------------
; YellowIntro_SetTimerFor128Frames / _SetTimerFor88Frames.
; ---------------------------------------------------------------------------
YellowIntro_SetTimerFor128Frames:
    mov byte [ebp + wYellowIntroSceneTimer], 128
    ret

YellowIntro_SetTimerFor88Frames:
    mov byte [ebp + wYellowIntroSceneTimer], 88
    ret

; ---------------------------------------------------------------------------
; YellowIntro_CheckFrameTimerDecrement — decrement the scene timer; CF set (and
; nothing decremented) once it has reached 0.
; ---------------------------------------------------------------------------
YellowIntro_CheckFrameTimerDecrement:
    mov al, [ebp + wYellowIntroSceneTimer]         ; ld a, [hl]
    test al, al                                    ; and a
    jz .asm_f9e4b                                  ; jr z
    dec byte [ebp + wYellowIntroSceneTimer]        ; dec [hl]
    clc                                            ; and a  (CF = 0)
    ret
.asm_f9e4b:
    ; vc_hook Stop_reducing_intro_scene_flashing_0F — no-op in the port
    stc                                            ; scf
    ret

; ---------------------------------------------------------------------------
; The "wait-last" scenes (odd indices) that only touch the timer/object engine.
; Scenes 3/7/11/15 (hSCX scroll, LY-buffer roll, VBlank cloud copy) and the even
; active scenes ride later B3 increments (HAL). YellowIntro_NextScene advances
; wYellowIntroCurrentScene, so each of these runs once the timer expires.
; ---------------------------------------------------------------------------
YellowIntroScene1:
    call YellowIntro_CheckFrameTimerDecrement
    jc .expired                                    ; ret nc → fall through only when expired
    ret
.expired:
    call YellowIntro_MaskCurrentAnimatedObjectStruct
    call YellowIntro_NextScene
    ret

; Scene 4 — "running Pikachu 2": pump the music, lay out the framed BG (Func_f9e5f),
; spawn animated object $2, reset the DMG palettes, arm a 128-frame timer, advance.
; DEVIATION{class=HAL; pret=engine/movie/intro_yellow.asm:YellowIntroScene4; behavior=the hOnCGB branch that writes the CGB VRAM bank-1 attribute map (rVBK, the 6x6 tile-attribute box at $98d4) is omitted, the port always takes the DMG path; evidence=the port renders DMG shades through the VGA compositor and has no CGB tile-attribute plane, hOnCGB is 0-equivalent, this is the Phase-5 CGB palette boundary; lifetime=Phase-5 CGB palette translation}
YellowIntroScene4:
    call YellowIntro_BlankPalsDelay2AndDisableLCD
    mov bl, 0x5                                     ; ld c, $5
    call UpdateMusicCTimes
    xor al, al
    mov [ebp + H_LCDC_POINTER], al                 ; ldh [hLCDCPointer], a
    call Func_f9e5f
    mov dh, 0x58                                    ; lb de, $58, $58
    mov dl, 0x58
    mov al, 0x2
    call YellowIntro_SpawnAnimatedObjectAndSavePointer
    xor al, al
    call Func_f9e9a
    call YellowIntro_SetTimerFor128Frames
    call YellowIntro_NextScene
    ret

YellowIntroScene5:
    call YellowIntro_CheckFrameTimerDecrement
    jc .expired
    ret
.expired:
    call YellowIntro_MaskCurrentAnimatedObjectStruct
    call YellowIntro_NextScene
    ret

; Scene 6 — "surfing scene": arm the per-scanline SCY wobble (inert in the port),
; lay out a custom BG (rows 0-2 tile 0, row 3 a $20/$21 stripe, rows 4+ tile $10 =
; the water), and spawn object $5. The rSCY LY-effect + sine buffer produce the
; wave wobble on hardware; the port stores them faithfully but does not emulate the
; per-scanline override (see Copy8BitSineWave), so the wobble is inert. (BG fills
; use the cinematic origin, as documented once at the top; pret's rows-4+ $300 fill
; is capped at the surface bottom so it does not overrun the 40-wide canvas.)
YellowIntroScene6:
    call YellowIntro_BlankPalsDelay2AndDisableLCD
    mov bl, 0x5                                    ; ld c, $5
    call UpdateMusicCTimes
    mov al, 0x42                                   ; ld a, LOW(rSCY)  ($FF42)
    mov [ebp + H_LCDC_POINTER], al                 ; ldh [hLCDCPointer], a  (inert)
    call YellowIntro_Copy8BitSineWave
    mov esi, W_TILEMAP + INTRO_BG_ROW_OFF          ; GB rows 0-2 (at the BG row origin)
    mov bx, 3 * SCREEN_TILES_W                     ; ld bc, $60  (rows 0-2)
    xor al, al
    call FillMemory                                ; call Bank3E_FillMemory
    mov esi, W_TILEMAP + INTRO_BG_ROW_OFF + 3 * SCREEN_TILES_W  ; GB row 3 (col 0 start: the 32-col stripe covers the visible cols 10-29 with matching parity)
    mov cl, 0x10                                   ; ld c, $10
    mov al, 0x20                                   ; ld a, $20
.stripe:
    mov [ebp + esi], al                            ; ld [hli], a  ($20)
    inc esi
    inc al                                         ; inc a
    mov [ebp + esi], al                            ; ld [hli], a  ($21)
    inc esi
    dec al                                         ; dec a
    dec cl                                         ; dec c
    jnz .stripe
    mov esi, W_TILEMAP + INTRO_BG_ROW_OFF + 4 * SCREEN_TILES_W  ; GB rows 4-to-end
    mov bx, SCREEN_AREA - INTRO_BG_ROW_OFF - 4 * SCREEN_TILES_W ; capped at the surface bottom (origin-shifted)
    mov al, 0x10
    call FillMemory
    mov dh, 0x40                                   ; lb de, $40, $f8
    mov dl, 0xf8
    mov al, 0x5
    call YellowIntro_SpawnAnimatedObjectAndSavePointer
    mov al, 0x1
    call Func_f9e9a
    call YellowIntro_SetTimerFor88Frames
    call YellowIntro_NextScene
    ret

; Scene 7 — "surf wait": scroll the water right (hSCX += 2), circularly roll the
; LY-override wave buffer left by one (the wobble source), and request the 7-tile
; VBlank copy — until the timer expires. The scroll and timing are real; the LY
; wave and its VBlank transfer are inert in the port (no per-scanline LY / generic
; VBlank tile copy), so the buffer is maintained faithfully but the wobble is not
; visible.
YellowIntroScene7:
    call YellowIntro_CheckFrameTimerDecrement
    jc .expired                                    ; jr c, .expired
    add byte [ebp + H_SCX], 2                       ; ld hl,hSCX / inc [hl] / inc [hl]
    mov al, [ebp + W_LY_OVERRIDES_BUFFER]           ; ld a, [hl]  (save buffer[0])
    push eax                                        ; push af
    lea esi, [ebp + W_LY_OVERRIDES_BUFFER]          ; ld hl, wLYOverridesBuffer   (dest)
    lea edi, [ebp + W_LY_OVERRIDES_BUFFER + 1]      ; ld de, wLYOverridesBuffer+1 (src)
    mov cl, 0xff                                    ; ld c, $ff
.shift_loop:
    mov al, [edi]                                   ; ld a, [de]
    inc edi                                         ; inc de
    mov [esi], al                                   ; ld [hli], a
    inc esi
    dec cl                                          ; dec c
    jnz .shift_loop
    pop eax                                         ; pop af
    mov [esi], al                                   ; ld [hl], a  (buffer[255] = saved)
    call Request7TileTransferFromC810ToC710
    ret
.expired:
    call YellowIntro_MaskCurrentAnimatedObjectStruct
    call YellowIntro_NextScene
    ret

; Request7TileTransferFromC810ToC710 — queue a 7-tile VBlank copy of the rolled
; wave data (wLYOverridesBuffer+$10 -> wLYOverrides+$10). Ported verbatim, but INERT:
; the port has no generic VBlank tile copy, so the request bytes are written and
; never consumed.
; DEVIATION{class=HAL; pret=engine/movie/intro_yellow.asm:Request7TileTransferFromC810ToC710; behavior=the hVBlankCopySource/Dest/Size request is written but never acted on because the port has no generic VBlank tile copy (only VBlankCopyBgMap for BG-map rows), so the surfing LY-wave tile animation does not play; evidence=the port composites from tile_cache and does not emulate the per-scanline LY overrides this transfer feeds; lifetime=deferred VBlank tile-transfer HAL}
Request7TileTransferFromC810ToC710:
    mov al, 0x10
    mov [ebp + hVBlankCopySource], al               ; ldh [hVBlankCopySource], a
    mov al, (W_LY_OVERRIDES_BUFFER >> 8)            ; ld a, HIGH(wLYOverridesBuffer)
    mov [ebp + hVBlankCopySource + 1], al           ; ldh [hVBlankCopySource+1], a
    mov al, 0x10
    mov [ebp + hVBlankCopyDest], al                 ; ldh [hVBlankCopyDest], a
    mov al, (W_LY_OVERRIDES >> 8)                   ; ld a, HIGH(wLYOverrides)
    mov [ebp + hVBlankCopyDest + 1], al             ; ldh [hVBlankCopyDest+1], a
    mov al, 0x7
    mov [ebp + hVBlankCopySize], al                 ; ldh [hVBlankCopySize], a
    ret

; Scene 8 — "running Pikachu 3": identical layout to scene 4, spawning animated
; object $3 instead of $2. No CGB branch here in pret, so no DMG/CGB split.
YellowIntroScene8:
    call YellowIntro_BlankPalsDelay2AndDisableLCD
    mov bl, 0x5                                     ; ld c, $5
    call UpdateMusicCTimes
    xor al, al
    mov [ebp + H_LCDC_POINTER], al                 ; ldh [hLCDCPointer], a
    call Func_f9e5f
    mov dh, 0x58                                    ; lb de, $58, $58
    mov dl, 0x58
    mov al, 0x3
    call YellowIntro_SpawnAnimatedObjectAndSavePointer
    xor al, al
    call Func_f9e9a
    call YellowIntro_SetTimerFor128Frames
    call YellowIntro_NextScene
    ret

YellowIntroScene9:
    call YellowIntro_CheckFrameTimerDecrement
    jc .expired
    ret
.expired:
    call YellowIntro_MaskCurrentAnimatedObjectStruct
    call YellowIntro_NextScene
    ret

; Scene 10 — "gengar battle scene": clear the BG map, paint rows 0-7 with tile $2,
; then paste three tilemap boxes (the gengar/battle graphics) and spawn object $6.
; The .FillBGMapBox local (kept as in pret) copies a BH x BL tile box from a flat
; tilemap into W_TILEMAP, advancing one canvas row per source row. BG writes use the
; cinematic origin (documented once at the top); all three boxes fall inside the
; visible 20-col region.
YellowIntroScene10:
    call YellowIntro_BlankPalsDelay2AndDisableLCD
    mov bl, 0x5                                    ; ld c, $5
    call UpdateMusicCTimes
    xor al, al
    mov [ebp + H_LCDC_POINTER], al                 ; ldh [hLCDCPointer], a
    mov esi, W_TILEMAP                             ; ld hl, vBGMap0
    mov bx, SCREEN_AREA                            ; ld bc, $400  (clear whole map)
    xor al, al
    call FillMemory                                ; call Bank3E_FillMemory
    mov esi, W_TILEMAP + INTRO_BG_ROW_OFF          ; GB rows 0-7 (at the BG row origin)
    mov bx, 8 * SCREEN_TILES_W                     ; ld bc, $100  (rows 0-7)
    mov al, 0x2
    call FillMemory
    mov esi, W_TILEMAP + INTRO_BG_ORIGIN + 8 * SCREEN_TILES_W       ; ld hl, $9900  (GB row 8, col 0)
    mov edi, Unkn_f9b6e                            ; ld de, Unkn_f9b6e  (flat)
    mov bh, 6                                      ; lb bc, 6, 20
    mov bl, 20
    call .FillBGMapBox
    mov esi, W_TILEMAP + INTRO_BG_ORIGIN + 4 * SCREEN_TILES_W + 12  ; ld hl, $988c  (GB row 4, col 12)
    mov edi, Unkn_f9be6
    mov bh, 3                                      ; lb bc, 3, 4
    mov bl, 4
    call .FillBGMapBox
    mov esi, W_TILEMAP + INTRO_BG_ORIGIN + 7 * SCREEN_TILES_W + 3   ; ld hl, $98e3  (GB row 7, col 3)
    mov edi, Unkn_f9bf2
    mov bh, 2                                      ; lb bc, 2, 2
    mov bl, 2
    call .FillBGMapBox
    mov dh, 0x98                                   ; lb de, $98, $58
    mov dl, 0x58
    mov al, 0x6
    call YellowIntro_SpawnAnimatedObjectAndSavePointer
    mov al, 0x1
    call Func_f9e9a
    call YellowIntro_SetTimerFor128Frames
    call YellowIntro_NextScene
    ret

; In: ESI = W_TILEMAP dest offset, EDI = flat src, BH = rows, BL = cols.
.FillBGMapBox:
.fill_row:
    movzx ecx, bl                                  ; c = cols (fresh each row)
    push esi                                       ; push hl  (dest row start)
.fill_col:
    mov al, [edi]                                  ; ld a, [de]  (flat src)
    inc edi
    mov [ebp + esi], al                            ; ld [hli], a
    inc esi
    dec ecx                                        ; dec c
    jnz .fill_col
    pop esi                                        ; pop hl
    add esi, SCREEN_TILES_W                        ; ld bc,$20 / add hl,bc  (port stride 40)
    dec bh                                         ; dec b  (rows)
    jnz .fill_row
    ret

; Scene 11 — "clouds": every 8th frame, queue a VBlank copy of 4 cloud tiles
; (alternating halves of YellowIntroCloudGFX by bit 3 of the timer) into vChars
; $9600 — the cloud tile animation. INERT in the port (no generic VBlank tile
; copy), so the request is written faithfully but the clouds do not cycle.
; DEVIATION{class=HAL; pret=engine/movie/intro_yellow.asm:YellowIntroScene11; behavior=the hVBlankCopySource/Dest/Size cloud-tile request is written but never acted on because the port has no generic VBlank tile copy, so the cloud tiles do not animate; evidence=the port composites from tile_cache and does not run the generic VBlank tile transfer this scene queues; lifetime=deferred VBlank tile-transfer HAL}
YellowIntroScene11:
    call YellowIntro_CheckFrameTimerDecrement
    jc .expired                                    ; jr c, .expired
    mov al, [ebp + wYellowIntroSceneTimer]         ; ld a, [wYellowIntroSceneTimer]
    and al, 0x7                                     ; and $7
    jnz .ret                                        ; ret nz  (only every 8th frame)
    mov al, [ebp + wYellowIntroSceneTimer]         ; ld a, [wYellowIntroSceneTimer]
    and al, 0x8                                     ; and $8
    shl al, 1                                       ; sla a
    shl al, 1                                       ; sla a
    shl al, 1                                       ; sla a   (al = 0 or $40)
    movzx edx, al                                   ; ld e,a / ld d,$0
    lea esi, [YellowIntroCloudGFX + edx]           ; ld hl, YellowIntroCloudGFX / add hl,de
    mov eax, esi
    mov [ebp + hVBlankCopySource], al               ; ld a,l / ldh [hVBlankCopySource], a
    mov [ebp + hVBlankCopySource + 1], ah           ; ld a,h / ldh [hVBlankCopySource+1], a
    xor al, al                                      ; xor a
    mov [ebp + hVBlankCopyDest], al                 ; ldh [hVBlankCopyDest], a
    mov al, 0x96                                    ; ld a, $96
    mov [ebp + hVBlankCopyDest + 1], al             ; ldh [hVBlankCopyDest+1], a  ($9600)
    mov al, 0x4                                     ; ld a, $4
    mov [ebp + hVBlankCopySize], al                 ; ldh [hVBlankCopySize], a
.ret:
    ret
.expired:
    call YellowIntro_MaskCurrentAnimatedObjectStruct
    call YellowIntro_NextScene
    ret

; Scene 12 — "closing pan": lay out the framed BG (the Func_f9e5f pattern, inlined
; as in pret), paste an 8x12 graphic at (5,6) whose tile ids run 4.. with a 4-tile
; gap per row, patch three individual tiles, and spawn object $9.
;
; (BG writes use the cinematic origin, documented once at the top; the 12-col paste
; at col 5 stays inside the visible 20-col region.)
YellowIntroScene12:
    call YellowIntro_BlankPalsDelay2AndDisableLCD
    mov bl, 0x5                                    ; ld c, $5
    call UpdateMusicCTimes
    xor al, al
    mov [ebp + H_LCDC_POINTER], al                 ; ldh [hLCDCPointer], a
    mov esi, W_TILEMAP + INTRO_BG_ROW_OFF          ; GB rows 0-3 (at the BG row origin)
    mov bx, 4 * SCREEN_TILES_W                     ; ld bc, $80   (rows 0-3)
    mov al, 0x1
    call FillMemory                                ; call Bank3E_FillMemory
    mov esi, W_TILEMAP + INTRO_BG_ROW_OFF + 4 * SCREEN_TILES_W  ; GB rows 4-13
    mov bx, 10 * SCREEN_TILES_W                    ; ld bc, $140
    xor al, al
    call FillMemory
    mov esi, W_TILEMAP + INTRO_BG_ROW_OFF + 14 * SCREEN_TILES_W ; GB rows 14-17
    mov bx, 4 * SCREEN_TILES_W                     ; ld bc, $80
    mov al, 0x1
    call FillMemory
    ; paste 8x12 graphic at GB (col 5, row 6), tile ids 4.., skipping 4 vtiles per row
    mov esi, W_TILEMAP + INTRO_BG_ORIGIN + 6 * SCREEN_TILES_W + 5  ; ld hl, $98c5
    mov al, 0x4                                    ; ld a, $4  (start tile)
    mov bh, 8                                      ; ld b, 8   (rows)
.paste_row:
    mov cl, 12                                     ; ld c, 12  (cols)
    push esi                                       ; push hl
.paste_col:
    mov [ebp + esi], al                            ; ld [hli], a
    inc esi
    inc al                                         ; inc a
    dec cl                                         ; dec c
    jnz .paste_col
    pop esi                                        ; pop hl
    add esi, SCREEN_TILES_W                        ; ld de,$20 / add hl,de  (port stride 40)
    add al, 0x4                                    ; add $4
    dec bh                                         ; dec b
    jnz .paste_row
    mov byte [ebp + W_TILEMAP + INTRO_BG_ORIGIN + 6 * SCREEN_TILES_W + 4], 0x3   ; ld hl,$98c4 / ld [hl],$3
    mov byte [ebp + W_TILEMAP + INTRO_BG_ORIGIN + 7 * SCREEN_TILES_W + 4], 0x74  ; ld hl,$98e4 / ld [hl],$74
    mov byte [ebp + W_TILEMAP + INTRO_BG_ORIGIN + 13 * SCREEN_TILES_W + 5], 0x0  ; ld hl,$99a5 / ld [hl],$0
    mov dh, 0x60                                   ; lb de, $60, $58
    mov dl, 0x58
    mov al, 0x9
    call YellowIntro_SpawnAnimatedObjectAndSavePointer
    xor al, al
    call Func_f9e9a
    call YellowIntro_SetTimerFor128Frames
    call YellowIntro_NextScene
    ret

YellowIntroScene13:
    call YellowIntro_CheckFrameTimerDecrement
    jc .expired
    ret
.expired:
    mov dh, 0x68                                   ; lb de, $68, $58
    mov dl, 0x58
    mov al, 0x0a
    call SpawnAnimatedObject
    call YellowIntro_NextScene
    ret

; Scene 14 — "fade + reframe": run the DMG fade (YellowIntroPalSequence_f9dd6)
; one byte per frame; when it terminates, mask the objects, blank OAM, rebuild the
; framed BG (rows 0-3 tile 1, 4-13 tile 0, 14-17 tile 1 — the Func_f9e5f layout,
; inlined to match pret's three fills), restore the DMG palettes, spawn object $7,
; advance, and arm a $28-frame timer for the next scene.
;
; (BG row fills use the cinematic origin, documented once at the top. The
; hAutoBGTransferEnabled toggle is written faithfully though inert — nothing in the
; port reads the byte, do_bg_transfer is retired — matching every other port caller.)
YellowIntroScene14:
    mov edx, YellowIntroPalSequence_f9dd6          ; ld de, ...
    call YellowIntro_LoadDMGPalAndIncrementCounter
    jc .expired                                    ; jr c, .expired
    mov [ebp + IO_BGP], al                         ; ldh [rBGP], a
    mov [ebp + IO_OBP0], al                        ; ldh [rOBP0], a
    and al, 0xf0                                   ; and $f0
    mov [ebp + IO_OBP1], al                        ; ldh [rOBP1], a
    call UpdateCGBPal_BGP
    call UpdateCGBPal_OBP0
    call UpdateCGBPal_OBP1
    ret
.expired:
    call MaskAllAnimatedObjectStructs
    call YellowIntro_BlankOAMBuffer
    mov esi, W_TILEMAP + INTRO_BG_ROW_OFF          ; GB rows 0-3 (at the BG row origin)
    mov bx, 4 * SCREEN_TILES_W                     ; ld bc, SCREEN_WIDTH * 4
    mov al, 0x1
    call FillMemory                                ; call Bank3E_FillMemory
    mov esi, W_TILEMAP + INTRO_BG_ROW_OFF + 4 * SCREEN_TILES_W  ; GB rows 4-13
    mov bx, 10 * SCREEN_TILES_W                    ; ld bc, SCREEN_WIDTH * 10
    xor al, al
    call FillMemory
    mov esi, W_TILEMAP + INTRO_BG_ROW_OFF + 14 * SCREEN_TILES_W ; GB rows 14-17
    mov bx, 4 * SCREEN_TILES_W                     ; ld bc, SCREEN_WIDTH * 4
    mov al, 0x1
    call FillMemory
    mov byte [ebp + hAutoBGTransferEnabled], 1      ; ld a,$1 / ldh [hAutoBGTransferEnabled],a (inert, pret fidelity)
    call DelayFrame
    call DelayFrame
    call DelayFrame
    mov byte [ebp + hAutoBGTransferEnabled], 0      ; xor a / ldh [hAutoBGTransferEnabled],a
    mov al, 0xe4                                   ; ld a, $e4
    mov [ebp + IO_OBP0], al                        ; ldh [rOBP0], a
    mov [ebp + IO_BGP], al                         ; ldh [rBGP], a
    call UpdateCGBPal_BGP
    call UpdateCGBPal_OBP0
    mov dh, 0x58                                   ; lb de, $58, $58
    mov dl, 0x58
    mov al, 0x7
    call YellowIntro_SpawnAnimatedObjectAndSavePointer
    call YellowIntro_NextScene
    mov byte [ebp + wYellowIntroSceneTimer], 0x28  ; ld a,$28 / ld [timer],a  (vc_hook is a no-op in base ROM)
    ret

YellowIntroScene17:
    mov bl, 64                                     ; ld c, 64
    call DelayFrames
    or byte [ebp + wYellowIntroCurrentScene], 0x80 ; set 7, [hl]  (done flag)
    ret

; Scene 0 — "running Pikachu 1": spawn the object, set scroll/window/palettes to
; the intro defaults, arm a 130-frame timer, advance. (hLCDCPointer=0 disables
; the per-scanline LCDC effect, inert in the port.)
YellowIntroScene0:
    xor al, al
    mov [ebp + H_LCDC_POINTER], al                 ; ldh [hLCDCPointer], a
    mov dh, 0x58                                    ; lb de, $58, $58
    mov dl, 0x58
    mov al, 0x1
    call YellowIntro_SpawnAnimatedObjectAndSavePointer
    xor al, al
    mov [ebp + H_SCX], al                           ; ldh [hSCX], a
    mov [ebp + H_SCY], al                           ; ldh [hSCY], a
    mov al, 0x90
    mov [ebp + H_WY], al                            ; ldh [hWY], a
    mov al, 0xe4
    mov [ebp + IO_BGP], al                          ; ldh [rBGP], a
    mov [ebp + IO_OBP0], al                         ; ldh [rOBP0], a
    mov al, 0xc4
    mov [ebp + IO_OBP1], al                         ; ldh [rOBP1], a
    call UpdateCGBPal_BGP
    call UpdateCGBPal_OBP0
    call UpdateCGBPal_OBP1
    mov byte [ebp + wYellowIntroSceneTimer], 130    ; ld a,130 / ld [timer],a
    call YellowIntro_NextScene
    ret

; Scene 2 — "flying speed bars": clear the BG map, place the 6x6 gengar grid
; off-screen at col 20 (revealed later when scene 3 scrolls the BG right), and
; spawn the 8 flying speed-bar objects. The de/a set before LoadYellowIntroFlying
; SpeedBars are overloaded/ignored by that routine (kept for fidelity).
YellowIntroScene2:
    call YellowIntro_BlankPalsDelay2AndDisableLCD
    mov bl, 0x8                                    ; ld c, $8
    call UpdateMusicCTimes
    xor al, al
    mov [ebp + H_LCDC_POINTER], al                 ; ldh [hLCDCPointer], a
    mov esi, W_TILEMAP                             ; ld hl, vBGMap0
    mov bx, SCREEN_AREA                            ; ld bc, $400  (clear whole map)
    xor al, al
    call FillMemory                                ; call Bank3E_FillMemory
    call YellowIntroScene2_PlaceGraphic
    mov dh, 0x58                                   ; lb de, $58, $b8  (overloaded)
    mov dl, 0xb8
    mov al, 0x4                                    ; ld a, $4  (overloaded)
    call LoadYellowIntroFlyingSpeedBars
    mov al, 0x1
    call Func_f9e9a
    call YellowIntro_SetTimerFor128Frames
    call YellowIntro_NextScene
    ret

; YellowIntroScene2_PlaceGraphic — paint a 6x6 grid of tiles ($90.., +$10 per row)
; at GB (col 20, row 6), authored at the cinematic origin. Col 20 is off the right
; of the visible 20-col area at SCX=0; scene 3 scrolls the BG right to bring it in.
;
; DEVIATION{class=HAL; pret=engine/movie/intro_yellow.asm:YellowIntroScene2_PlaceGraphic; behavior=the hOnCGB branch that writes the CGB VRAM bank-1 attribute map is omitted, the port always takes the DMG path; evidence=the port renders DMG shades through the VGA compositor and has no CGB tile-attribute plane, the Phase-5 CGB palette boundary, same as YellowIntroScene4; lifetime=Phase-5 CGB palette translation}
YellowIntroScene2_PlaceGraphic:
    mov esi, W_TILEMAP + INTRO_BG_ORIGIN + 6 * SCREEN_TILES_W + 20  ; ld hl, $98d4  (GB col 20, row 6 — off-screen right, revealed by scene 3's scroll)
    mov bh, 0x6                                    ; ld b, $6  (rows)
    mov al, 0x90                                   ; ld a, $90
.row:
    mov cl, 0x6                                    ; ld c, $6  (cols)
    push eax                                       ; push af  (row start tile)
    push esi                                       ; push hl  (row start addr)
.col:
    mov [ebp + esi], al                           ; ld [hli], a
    inc esi
    inc al                                         ; inc a
    dec cl                                         ; dec c
    jnz .col
    pop esi                                        ; pop hl
    add esi, SCREEN_TILES_W                        ; add hl, de  ($20 -> 40)
    pop eax                                        ; pop af
    add al, 0x10                                   ; add $10
    dec bh                                         ; dec b
    jnz .row
    ; hOnCGB CGB attribute-map block omitted (Phase-5; port renders DMG shades)
    ret

; Scene 3 — hold the "running Pikachu 1" pose while scrolling the BG right to
; hSCX = 0x68, then mask the objects and advance. hSCX is the port's own scroll
; shadow (H_SCX), reconciled to the projected surface by PlayIntroScene.
YellowIntroScene3:
    call YellowIntro_CheckFrameTimerDecrement
    jc .expired                                    ; jr c, .expired
    mov al, [ebp + H_SCX]                          ; ldh a, [hSCX]
    cmp al, 0x68                                   ; cp $68
    je .done                                       ; ret z
    add al, 0x4                                    ; add $4
    mov [ebp + H_SCX], al                          ; ldh [hSCX], a
.done:
    ret
.expired:
    call MaskAllAnimatedObjectStructs
    call YellowIntro_NextScene
    ret

; ---------------------------------------------------------------------------
; Func_fa06e — index a word-pointer table (ESI/HL) by AL and return the entry.
; pret's only caller is the scene dispatcher Func_f98fc, whose table
; (Jumptable_f9906) is a flat 32-bit code-address table in the port.
;
; DEVIATION{class=data-model; pret=engine/movie/intro_yellow.asm:Func_fa06e; behavior=indexes the table at a x4 stride and returns a 32-bit flat entry instead of pret's 2-byte GB pointer at a x2 stride; evidence=its sole caller dispatches the Yellow-intro scene jumptable whose entries are native x86 code addresses (flat link-time labels), same rationale as the animated-object jumptable; lifetime=permanent — intrinsic to running GB code as native x86}
; ---------------------------------------------------------------------------
Func_fa06e:
    movzx eax, al                                  ; ld e,a / ld d,$0  (index)
    mov esi, [esi + eax*4]                          ; hl = table[index]  (flat, x4)
    ret

; ---------------------------------------------------------------------------
; Func_f98fc — dispatch to the current intro scene. jmp esi follows Func_fa06e's
; flat pointer (data-model DEVIATION annotated on Func_fa06e), mirroring pret's
; `jp hl`. All 18 Jumptable_f9906 entries point at their real
; YellowIntroScene0..17 handlers (the B3.2 auto-advance scaffold is gone).
; ---------------------------------------------------------------------------
Func_f98fc:
    mov al, [ebp + wYellowIntroCurrentScene]       ; ld a, [wYellowIntroCurrentScene]
    mov esi, Jumptable_f9906                        ; ld hl, Jumptable_f9906
    call Func_fa06e                                 ; hl = Jumptable_f9906[a]
    jmp esi                                          ; jp hl

; ---------------------------------------------------------------------------
; InitYellowIntroGFXAndMusic — blank the tilemap, load the intro tile sheets to
; VRAM, point the object engine at the intro tables, set the generic palette and
; music, and zero the scene state. hAutoBGTransferEnabled/Dest are written faithfully
; though inert (no port consumer reads the enable byte, do_bg_transfer is retired, and
; the compositor renders directly from W_TILEMAP); the port keeps these writes exactly
; as pret does throughout the tree. Graphics2 loads 255 tiles (pret's (size-$10)/$10).
; ---------------------------------------------------------------------------
; ---------------------------------------------------------------------------
; CopyYellowIntroAnimatedObjectData — port-only: stage the three immutable
; animated-object tables from the program image (flat .data) into GB space at
; [ebp + W_INTRO_ANIM_DATA], composed back-to-back (frames, OAM, spawn — the
; frames/OAM adjacency matches pret ROM $fa0ea-$fa35a, where intro_frames.asm
; and intro_oam.asm are INCLUDEd contiguously) so the GB-base-relative pointers
; inside them resolve under [ebp+ptr]. pret keeps this data ROM-resident; the
; port has no GB-space ROM window for it, so it is copied once at intro init
; (the same flat→GB staging LoadShootingStarGraphics and GetDefaultName use).
; The frames/OAM copy sizes are the gb_memmap.inc region deltas — each data
; mirror statically asserts its assembled size equals its delta, so these
; constants cannot drift from the tables. Clobbers nothing (pushad/popad).
; ---------------------------------------------------------------------------
CopyYellowIntroAnimatedObjectData:
    pushad
    mov esi, YellowIntro_AnimatedObjectFramesData   ; flat program-image source
    lea edi, [ebp + W_INTRO_FRAMES_DATA]            ; GB-space destination
    mov ecx, W_INTRO_OAM_DATA - W_INTRO_FRAMES_DATA
    rep movsb
    mov esi, YellowIntro_AnimatedObjectOAMData
    ; EDI already = &[ebp + W_INTRO_OAM_DATA]: the regions are contiguous.
    mov ecx, W_INTRO_SPAWN_DATA - W_INTRO_OAM_DATA
    rep movsb
    mov esi, YellowIntro_AnimatedObjectSpawnStateData
    mov ecx, W_INTRO_SPAWN_DATA_SIZE
    rep movsb
    popad
    ret

InitYellowIntroGFXAndMusic:
    xor al, al
    mov [ebp + hAutoBGTransferEnabled], al          ; ldh [hAutoBGTransferEnabled], a (=0, inert)
    mov [ebp + H_SCX], al                          ; ldh [hSCX], a
    mov [ebp + H_SCY], al                          ; ldh [hSCY], a
    mov [ebp + hAutoBGTransferDest], al        ; ldh [hAutoBGTransferDest], a (lo=0)
    mov byte [ebp + hAutoBGTransferDest + 1], 0x98 ; ld a,$98 / ldh [hAutoBGTransferDest+1],a (vBGMap0 $9800)
    call YellowIntro_BlankTileMap
    mov esi, W_TILEMAP                             ; ld hl, wTileMap
    mov bx, SCREEN_AREA                            ; ld bc, SCREEN_AREA
    mov al, 0x1                                    ; ld a, $1
    call FillMemory
    mov esi, W_TILEMAP + INTRO_BG_ROW_OFF + 4 * SCREEN_TILES_W  ; GB rows 4-13 (clear middle at the BG row origin)
    mov bx, SCREEN_TILES_W * 10                    ; ld bc, SCREEN_WIDTH * 10
    xor al, al
    call FillMemory
    mov byte [ebp + hAutoBGTransferEnabled], 1      ; ld a,$1 / ldh [hAutoBGTransferEnabled],a (inert, pret fidelity)
    call DelayFrame                                ; pret waits 3 frames for the (retired)
    call DelayFrame                                ; auto-transfer; kept for frame timing
    call DelayFrame
    mov byte [ebp + hAutoBGTransferEnabled], 0      ; xor a / ldh [hAutoBGTransferEnabled],a
    mov edx, YellowIntroGraphics2                  ; ld de, YellowIntroGraphics2
    mov esi, GB_VCHARS0                            ; ld hl, vChars0
    mov bl, YELLOWINTROGRAPHICS2_TILES - 1          ; (End - Start - $10) / $10
    call CopyVideoData
    mov edx, YellowIntroGraphics1                  ; ld de, YellowIntroGraphics1
    mov esi, GB_VCHARS2                            ; ld hl, vChars2
    mov bl, YELLOWINTROGRAPHICS1_TILES              ; (End - Start) / $10
    call CopyVideoData
    ; BUGFIX: stage the immutable frame/OAM/spawn blob from the program image into
    ; GB space (W_INTRO_ANIM_DATA = 0xF700) BEFORE the engine reads it. Without this
    ; the tables at 0xF700 are zero, so every animated object drew 40 blank sprites
    ; ($00 tiles) piled at its spawn point — the running Pikachu appeared as a few
    ; stuck pixels that never animated. pret keeps this data ROM-resident; the flat
    ; port must copy it (same flat->GB staging LoadShootingStarGraphics uses). The
    ; call was only wired into the DEBUG_CINEMATIC_ANIMOBJ harness, never the real intro.
    call CopyYellowIntroAnimatedObjectData
    call ClearObjectAnimationBuffers
    call LoadYellowIntroObjectAnimationDataPointers
    mov bh, 0x08                                   ; ld b, SET_PAL_GENERIC ($08)
    call RunPaletteCommand
    xor eax, eax                                   ; zero the 4 scene-state bytes
    mov [ebp + wYellowIntroCurrentScene], eax       ; CurrentScene / Timer / StructPointer
    mov al, 0xdc                                   ; ld a, MUSIC_YELLOW_INTRO ($dc)
    call PlayMusic
    ret

; ---------------------------------------------------------------------------
; PlayIntroScene — the Yellow-intro main loop: init, then step scenes until the
; done bit (scene bit 7) is set or A/B/START skips it; teardown and return.
;
; The loop is wrapped in MovieBeginSurface/MovieEndSurface and republishes the
; animated-object shadow OAM through PublishProjectedOAM each frame — the port's
; cinematic surface model (documented once at the top).
; DEVIATION{class=HAL; pret=engine/movie/intro_yellow.asm:PlayIntroScene; behavior=pret's rIE/rIF/rSTAT (GB interrupt enable + flags + STAT) save/setup/restore is dropped; evidence=the port drives OBJ from a projected shadow with its own PIT/keyboard ISR, not the GB interrupt controller; lifetime=permanent flat-memory/HAL model}
; ---------------------------------------------------------------------------
PlayIntroScene:
    ; pret saves rIE/rIF/rSTAT here (GB interrupt + STAT setup) — the port uses
    ; its own PIT/keyboard ISR, so it is dropped. (hAutoBGTransferEnabled IS written
    ; faithfully in the exit tail, as everywhere else in the port — see below.)
    call MovieBeginSurface                          ; PORT: cinematic surface + UI_YELLOW_INTRO projection
    call InitYellowIntroGFXAndMusic
    call DelayFrame
.loop:
    mov al, [ebp + wYellowIntroCurrentScene]        ; ld a, [wYellowIntroCurrentScene]
    test al, 0x80                                    ; bit 7, a
    jnz .exit                                        ; jr nz, .go_to_title_screen
    call JoypadLowSensitivity
    mov al, [ebp + H_JOY_PRESSED]                    ; ldh a, [hJoyPressed]
    test al, PAD_A | PAD_B | PAD_START               ; and PAD_A | PAD_B | PAD_START
    jnz .exit                                        ; jr nz, .go_to_title_screen
    call Func_f98fc
    mov byte [ebp + wCurrentAnimatedObjectOAMBufferOffset], 0  ; xor a / ld [..], a
    call RunObjectAnimations
    mov al, [ebp + wYellowIntroCurrentScene]         ; ld a, [wYellowIntroCurrentScene]
    cmp al, 0x7                                       ; cp 7
    jne .not7
    call Func_f98a2                                   ; call z, Func_f98a2  (clobbers AL, as pret's does)
.not7:
    cmp al, 0xb                                       ; cp $b
    jne .notb
    call Func_f98cb                                   ; call z, Func_f98cb
.notb:
    ; PORT: publish the animated-object shadow OAM, projected onto the surface
    movzx ecx, byte [ebp + wCurrentAnimatedObjectOAMBufferOffset]
    shr ecx, 2                                        ; OBJ count = shadow-OAM cursor / 4
    mov esi, W_SHADOW_OAM
    mov eax, 80                                       ; UI_YELLOW_INTRO_COL * 8
    mov ebx, 24                                       ; UI_YELLOW_INTRO_ROW * 8
    call PublishProjectedOAM
    ; PORT: present this frame's GB fine scroll on the cinematic window. Scenes
    ; 3/7/11/15 walk H_SCX (e.g. scene 7's `add H_SCX,2` — a pure hSCX water scroll
    ; with no tilemap roll), which on the GB the LCD reads automatically each frame.
    ; The port has no hardware scroll, so H_SCX must be transferred to the compositor
    ; window's fine source offset (WIN_SRC_X) explicitly — exactly as the title bounce
    ; does (title.asm:.scrollStep). Without this the water only scrolled inside a
    ; GBSTATE/FRAME dump (the dump path in debug_dump.asm calls MovieSyncScroll), never
    ; during live play — implements the B3 "present all H_SCX/H_SCY scrolling through
    ; the A1 WIN_SRC_X/WIN_SRC_Y helper" item.
    call MovieSyncScroll                              ; H_SCX/H_SCY -> WIN_SRC_X/Y (GB mod-256 wrap)
    call DelayFrame
%ifdef DEBUG_YELLOW_S01
    ; yellow_intro_s01 golden (menu-intro B4): state-triggered GBSTATE dump at the
    ; first rendered frame of scene 1 (the first "wait last" hold — deterministic
    ; per-scene setup: intro graphics/tilemap loaded, running-pika object spawned).
    ; DumpBackbuffer emits GBSTATE.BIN + FRAME.BIN and exits, so it fires exactly once.
    extern DumpBackbuffer                             ; debug/debug_dump.asm
    mov al, [ebp + wYellowIntroCurrentScene]
    cmp al, 1
    jne .no_ys01_dump
    call DumpBackbuffer
.no_ys01_dump:
%endif
%ifdef YELLOW_DUMP_SCENE
    ; scroll-evidence dump (menu-intro B3): capture FRAME.BIN/GBSTATE at a chosen scene
    ; AND scene-timer value, so a SCROLLING scene (3/7/11/15) can be photographed at a
    ; specific H_SCX. The scene timer counts DOWN from its per-scene init, and scene 7
    ; walks `H_SCX += 2` once per surviving decrement, so a HIGHER YELLOW_DUMP_TIMER =
    ; earlier in the scene = smaller H_SCX, a LOWER one = later = larger H_SCX. Two builds
    ; at two timer values give the plan's "two distinct scroll offsets" evidence: the
    ; captured FRAME.BIN reflects the real WIN_SRC_X the loop's MovieSyncScroll set (the
    ; general DumpBackbuffer does NOT sync scroll — only the render did), so the water
    ; band is displaced by the H_SCX delta iff the scroll is actually presented.
    extern DumpBackbuffer                             ; debug/debug_dump.asm
    mov al, [ebp + wYellowIntroCurrentScene]
    cmp al, YELLOW_DUMP_SCENE
    jne .no_yscroll_dump
    mov al, [ebp + wYellowIntroSceneTimer]
    cmp al, YELLOW_DUMP_TIMER
    jne .no_yscroll_dump
    call DumpBackbuffer
.no_yscroll_dump:
%endif
    jmp .loop
.exit:
    call YellowIntro_BlankPalettes
    mov byte [ebp + H_LCDC_POINTER], 0               ; ldh [hLCDCPointer], a
    call DelayFrame
    mov byte [ebp + H_WY], 0x90                       ; ld a,$90 / ldh [hWY], a
    call ClearObjectAnimationBuffers
    mov esi, W_TILEMAP                                ; ld hl, wTileMap
    mov bx, SCREEN_AREA                               ; ld bc, SCREEN_AREA
    xor al, al
    call FillMemory
    call YellowIntro_BlankOAMBuffer
    mov byte [ebp + hAutoBGTransferEnabled], 1        ; ld a,$1 / ldh [hAutoBGTransferEnabled],a (inert, pret fidelity)
    call DelayFrame
    call DelayFrame
    call DelayFrame
    mov byte [ebp + hAutoBGTransferEnabled], 0        ; xor a / ldh [hAutoBGTransferEnabled],a
    call MovieEndSurface                             ; PORT: tear down the cinematic surface
    ret

%ifdef DEBUG_CINEMATIC_YELLOW
global RunYellowIntroTest
; RunYellowIntroTest — B3.2d harness: play the Yellow intro (9 ported scenes render
; animated OBJ projected/clipped; the 9 unported even scenes auto-advance).
; AUTOKEY dumps FRAME.BIN mid-intro.
RunYellowIntroTest:
    call PlayIntroScene
.hang:
    call DelayFrame
    jmp .hang
%endif

; ---------------------------------------------------------------------------
; YellowIntro_LoadDMGPalAndIncrementCounter — index a DMG-palette sequence table
; (EDX = flat table ptr) by the scene timer, incrementing it. Out: AL = the
; palette byte, CF set (sequence over) when the byte is 0xff. The pal-sequence
; tables are flat program-image data, so the read is flat (not EBP-relative).
; ---------------------------------------------------------------------------
YellowIntro_LoadDMGPalAndIncrementCounter:
    movzx esi, byte [ebp + wYellowIntroSceneTimer] ; ld a,[hl] / ld l,a / ld h,$0
    inc byte [ebp + wYellowIntroSceneTimer]        ; inc [hl]
    add esi, edx                                   ; add hl, de  (de = flat table)
    mov al, [esi]                                  ; ld a, [hl]  (FLAT read)
    cmp al, 0xff
    je .expired
    clc                                            ; and a
    ret
.expired:
    stc                                            ; scf
    ret

; Scene 15 — "thunderbolt flash": every 4th frame invert OBP0 / toggle BGP low
; bits for a strobe; on timer expiry restore the palettes and fall through into
; scene 16 (pret has no ret here — the fallthrough is intentional, so scene 15
; is placed physically before scene 16).
YellowIntroScene15:
    call YellowIntro_CheckFrameTimerDecrement
    jc .expired                                    ; jr c, .expired
    mov al, [ebp + wYellowIntroSceneTimer]
    and al, 0x3
    jnz .ret                                       ; ret nz  (flash only every 4th frame)
    mov al, [ebp + IO_OBP0]                        ; ldh a, [rOBP0]
    xor al, 0xff
    mov [ebp + IO_OBP0], al                        ; ldh [rOBP0], a
    mov al, [ebp + IO_BGP]                         ; ldh a, [rBGP]
    xor al, 0x3
    mov [ebp + IO_BGP], al                         ; ldh [rBGP], a
    call UpdateCGBPal_BGP
    call UpdateCGBPal_OBP0
.ret:
    ret
.expired:
    xor al, al
    mov [ebp + H_LCDC_POINTER], al                 ; ldh [hLCDCPointer], a
    mov al, 0xe4
    mov [ebp + IO_BGP], al                         ; ldh [rBGP], a
    mov [ebp + IO_OBP0], al                        ; ldh [rOBP0], a
    call UpdateCGBPal_BGP
    call UpdateCGBPal_OBP0
    call YellowIntro_NextScene
    ; fall through into YellowIntroScene16 (faithful to pret's missing ret)

; Scene 16 — "fade to white": step the DMG BGP/OBP0 through YellowIntroPal-
; Sequence_f9e0a one byte per frame until it terminates (0xff), then advance.
YellowIntroScene16:
    mov edx, YellowIntroPalSequence_f9e0a          ; ld de, ...  (flat)
    call YellowIntro_LoadDMGPalAndIncrementCounter
    jc .expired                                    ; jr c, .expired
    mov [ebp + IO_OBP0], al                        ; ldh [rOBP0], a
    mov [ebp + IO_BGP], al                         ; ldh [rBGP], a
    call UpdateCGBPal_BGP
    call UpdateCGBPal_OBP0
    ret
.expired:
    call YellowIntro_NextScene
    ret

; ---------------------------------------------------------------------------
; YellowIntro_BlankPalsDelay2AndDisableLCD — black out the DMG+CGB palettes, wait
; two frames for them to take, then disable the LCD (scenes call this before
; rebuilding the BG map).
; ---------------------------------------------------------------------------
YellowIntro_BlankPalsDelay2AndDisableLCD:
    xor al, al
    mov [ebp + IO_BGP], al                         ; ldh [rBGP], a
    mov [ebp + IO_OBP0], al                        ; ldh [rOBP0], a
    mov [ebp + IO_OBP1], al                        ; ldh [rOBP1], a
    call UpdateCGBPal_BGP
    call UpdateCGBPal_OBP0
    call UpdateCGBPal_OBP1
    call DelayFrame
    call DelayFrame
    call DisableLCD
    ret

; ---------------------------------------------------------------------------
; Func_f9e5f — lay out the BG for the framed scenes: GB rows 0-3 tile $1, rows 4-13
; tile $0, rows 14-17 tile $1. Authored at the cinematic BG origin (see INTRO_BG_*
; at the top of this file) like every scene here — no per-scene projection note.
; ---------------------------------------------------------------------------
Func_f9e5f:
    mov esi, W_TILEMAP + INTRO_BG_ROW_OFF          ; GB rows 0-3 -> surface rows 0-3
    mov bx, 4 * SCREEN_TILES_W                      ; 4 rows x 40 (full-width covers visible cols 10-29)
    mov al, 0x1
    call FillMemory
    mov esi, W_TILEMAP + INTRO_BG_ROW_OFF + 4 * SCREEN_TILES_W  ; GB rows 4-13
    mov bx, 10 * SCREEN_TILES_W                     ; 10 rows x 40
    xor al, al
    call FillMemory
    mov esi, W_TILEMAP + INTRO_BG_ROW_OFF + 14 * SCREEN_TILES_W ; GB rows 14-17
    mov bx, 4 * SCREEN_TILES_W                      ; 4 rows x 40
    mov al, 0x1
    call FillMemory
    ret

; ---------------------------------------------------------------------------
; Func_f9e9a — per-scene reset: scroll/window to 0/0/$90, LCDC on, DMG palettes
; ($e4/$e4/$e0), CGB palettes applied. In: AL = palette variant (CGB-only).
;
; ---------------------------------------------------------------------------
Func_f9e9a:
    mov dl, al                                      ; ld e, a — palette variant
    call YellowIntroPaletteAction                   ; callfar YellowIntroPaletteAction
    xor al, al
    mov [ebp + H_SCX], al                          ; ldh [hSCX], a
    mov [ebp + H_SCY], al                           ; ldh [hSCY], a
    mov al, 0x90
    mov [ebp + H_WY], al                            ; ldh [hWY], a
    mov al, 0xe3
    mov [ebp + IO_LCDC], al                         ; ldh [rLCDC], a
    mov al, 0xe4
    mov [ebp + IO_BGP], al                          ; ldh [rBGP], a
    mov [ebp + IO_OBP0], al                         ; ldh [rOBP0], a
    mov al, 0xe0
    mov [ebp + IO_OBP1], al                         ; ldh [rOBP1], a
    call UpdateCGBPal_BGP
    call UpdateCGBPal_OBP0
    call UpdateCGBPal_OBP1
    ret

; ---------------------------------------------------------------------------
; YellowIntro_BlankTileMap — fill W_TILEMAP with the blank tile ($7f). Writes the
; port's canonical tilemap (the surface mirror carries it to GB_TILEMAP0).
; ---------------------------------------------------------------------------
YellowIntro_BlankTileMap:
    mov esi, W_TILEMAP                              ; ld hl, wTileMap
    mov bx, SCREEN_AREA                             ; ld bc, SCREEN_AREA
    mov al, 0x7f                                    ; ld a, $7f
    call FillMemory
    ret

; ---------------------------------------------------------------------------
; YellowIntro_BlankOAMBuffer — zero the shadow OAM.
; ---------------------------------------------------------------------------
YellowIntro_BlankOAMBuffer:
    mov esi, W_SHADOW_OAM                           ; ld hl, wShadowOAM
    mov bx, W_SHADOW_OAM_SIZE                       ; ld bc, wShadowOAMEnd - wShadowOAM
    xor al, al
    call FillMemory
    ret

; ---------------------------------------------------------------------------
; YellowIntro_BlankPalettes — black out the DMG+CGB palettes.
; ---------------------------------------------------------------------------
YellowIntro_BlankPalettes:
    xor al, al
    mov [ebp + IO_BGP], al                          ; ldh [rBGP], a
    mov [ebp + IO_OBP0], al                         ; ldh [rOBP0], a
    mov [ebp + IO_OBP1], al                         ; ldh [rOBP1], a
    call UpdateCGBPal_BGP
    call UpdateCGBPal_OBP0
    call UpdateCGBPal_OBP1
    ret

; ---------------------------------------------------------------------------
; YellowIntro_Copy8BitSineWave — fill wLYOverridesBuffer (0x100 bytes) with the
; amp-4 sine wave repeated 8 times (scene 6's surfing wobble source).
;
; DEVIATION{class=data-model; pret=engine/movie/intro_yellow.asm:YellowIntro_Copy8BitSineWave; behavior=the Bank3E_CopyData loop becomes an inline flat->GB rep movsb; evidence=the .SineWave source is flat program-image data while the port CopyData is EBP-relative on both ends, same as the splash OAM-table copies; lifetime=permanent flat-memory model}
; NOTE: the port does not emulate per-scanline LY overrides, so this buffer is
; written faithfully but never consumed (the wobble is inert).
; ---------------------------------------------------------------------------
YellowIntro_Copy8BitSineWave:
    lea edi, [ebp + W_LY_OVERRIDES_BUFFER]          ; ld de, wLYOverridesBuffer (dest)
    mov dl, 8                                       ; ld a, $8  (repeat count)
.loop:
    mov esi, YellowIntroSineWave8                   ; ld hl, .SineWave (flat source)
    mov ecx, YellowIntroSineWave8End - YellowIntroSineWave8
    rep movsb                                       ; call Bank3E_CopyData (flat -> GB)
    dec dl                                          ; dec a
    jnz .loop                                       ; jr nz, .loop
    ret

; ---------------------------------------------------------------------------
; LoadYellowIntroFlyingSpeedBars — spawn the 8 flying speed-bar objects (scene 2)
; from the flat (y, x, speed) table, stashing each object's speed in FieldB.
; The table is flat program-image data (flat reads); the struct write is GB.
; ---------------------------------------------------------------------------
LoadYellowIntroFlyingSpeedBars:
    mov esi, YellowIntroFlyingSpeedBarData          ; ld hl, ... (flat)
    mov al, 0x8                                     ; ld a, $8  (count)
.loop:
    push eax                                        ; push af  (count)
    mov dl, [esi]                                   ; ld e, [hl]
    inc esi
    mov dh, [esi]                                   ; ld d, [hl]
    inc esi
    mov al, [esi]                                   ; ld a, [hli]  (speed)
    inc esi
    push esi                                        ; push hl  (data ptr)
    push eax                                        ; push af  (speed)
    mov al, 0x8                                     ; ld a, $8  (spawn index)
    call SpawnAnimatedObject                        ; EBX = struct base
    pop eax                                         ; pop af  (speed)
    mov [ebp + ebx + 0x0b], al                      ; ld hl,$b/add hl,bc/ld [hl],a  (FieldB)
    pop esi                                         ; pop hl
    pop eax                                         ; pop af  (count)
    dec al                                          ; dec a
    jnz .loop
    ret

; ---------------------------------------------------------------------------
; Func_fa007 — no-op object callback.
; ---------------------------------------------------------------------------
Func_fa007:
    ret

; ---------------------------------------------------------------------------
; Func_fa008 — slide XCoord left toward 0x58, then stop.
; ---------------------------------------------------------------------------
Func_fa008:
    lea esi, [ebx + 4]              ; ld hl,$4/add hl,bc  (XCoord)
    mov al, [ebp + esi]            ; ld a, [hl]
    cmp al, 0x58                   ; cp $58
    je .ret                        ; ret z
    sub al, 0x4                    ; sub $4
    mov [ebp + esi], al            ; ld [hl], a
.ret:
    ret

; ---------------------------------------------------------------------------
; Func_fa014 — slide XCoord right toward 0x58 and YCoord tracks it (A carries
; from the X update into the Y compare, exactly as pret does).
; ---------------------------------------------------------------------------
Func_fa014:
    lea esi, [ebx + 4]             ; XCoord
    mov al, [ebp + esi]
    cmp al, 0x58                   ; cp $58
    je .asm_fa020                  ; jr z
    add al, 0x4                    ; add $4
    mov [ebp + esi], al            ; ld [hl], a  (A stays = XCoord+4)
.asm_fa020:
    lea esi, [ebx + 5]             ; YCoord
    cmp al, 0x58                   ; cp $58  (A from the X path)
    je .ret                        ; ret z
    add al, 0x1                    ; add $1
    mov [ebp + esi], al            ; ld [hl], a
.ret:
    ret

; ---------------------------------------------------------------------------
; Func_fa02b — dispatch on FieldB through the sub-jumptable.
;
; DEVIATION{class=data-model; pret=engine/movie/intro_yellow.asm:Func_fa02b; behavior=the FieldB sub-jumptable Jumptable_fa03b holds 32-bit flat x86 code addresses read at a x4 stride instead of pret's 2-byte GB addresses at a x2 stride; evidence=the jumptable targets are native x86 routines whose addresses are link-time flat labels, same rationale as ExecuteCurrentAnimatedObjectCallback; lifetime=permanent — intrinsic to running GB code as native x86}
; ---------------------------------------------------------------------------
Func_fa02b:
    movzx edx, byte [ebp + ebx + 0x0b]     ; ld hl,$b/add hl,bc/ld e,[hl]/ld d,$0  (FieldB)
    mov esi, [Jumptable_fa03b + edx*4]     ; flat callback address (table + 4*FieldB)
    jmp esi                                ; jp hl

; ---------------------------------------------------------------------------
; Func_fa03f — sub-state 0: slide YCoord up toward 0x58, then advance FieldB and
; fall through into Func_fa051.
; ---------------------------------------------------------------------------
Func_fa03f:
    lea esi, [ebx + 5]             ; YCoord
    mov al, [ebp + esi]
    cmp al, 0x58                   ; cp $58
    je .asm_fa04c                  ; jr z
    sub al, 0x2                    ; sub $2
    mov [ebp + esi], al
    ret
.asm_fa04c:
    inc byte [ebp + ebx + 0x0b]    ; ld hl,$b/add hl,bc/inc [hl]  (FieldB++)
    ; fall through into Func_fa051

; ---------------------------------------------------------------------------
; Func_fa051 — sub-state 1: bob YOffset with a sine of the advancing FieldC.
; ---------------------------------------------------------------------------
Func_fa051:
    lea esi, [ebx + 0x0c]          ; ld hl,$c/add hl,bc  (FieldC)
    mov al, [ebp + esi]           ; ld a, [hl]
    inc byte [ebp + esi]           ; inc [hl]  (FieldC++)
    mov dh, 0x8                    ; ld d, $8  (amplitude)
    call Func_fa079               ; AL = amplitude-scaled sine(FieldC)
    mov [ebp + ebx + 7], al        ; ld hl,$7/add hl,bc/ld [hl],a  (YOffset)
    ret

; ---------------------------------------------------------------------------
; Func_fa062 — XCoord += FieldB.
; ---------------------------------------------------------------------------
Func_fa062:
    mov al, [ebp + ebx + 0x0b]     ; ld hl,$b/add hl,bc/ld a,[hl]  (FieldB)
    lea esi, [ebx + 4]             ; ld hl,$4/add hl,bc  (XCoord)
    add al, [ebp + esi]            ; add [hl]
    mov [ebp + esi], al            ; ld [hl], a
    ret

; ---------------------------------------------------------------------------
; Func_fa077 — cosine entry: phase += 0x10, then sine.
; ---------------------------------------------------------------------------
Func_fa077:                        ; cosine
    add al, 0x10                   ; add $10
    ; fall through into Func_fa079

; ---------------------------------------------------------------------------
; Func_fa079 — sine(AL) scaled by amplitude DH. Out: AL = signed result.
; Phases 0x00-0x1f are the positive half; 0x20-0x3f are negated.
; ---------------------------------------------------------------------------
Func_fa079:
    and al, 0x3f                   ; and $3f
    cmp al, 0x20                   ; cp $20
    jae .asm_fa084                 ; jr nc
    call Func_fa08e               ; ESI = 16-bit product (HL)
    mov eax, esi
    shr eax, 8                     ; ld a, h  (high byte of HL)
    ret
.asm_fa084:
    and al, 0x1f                   ; and $1f
    call Func_fa08e
    mov eax, esi
    shr eax, 8                     ; ld a, h
    xor al, 0xff                   ; xor $ff
    inc al                         ; inc a  (two's-complement negate)
    ret

; ---------------------------------------------------------------------------
; Func_fa08e — 16-bit fixed-point multiply amplitude(DH) * sine_table[AL] via
; shift-add. Out: ESI = 16-bit product (the "HL" pret returns).
; ---------------------------------------------------------------------------
Func_fa08e:
    mov cl, al                     ; ld e, a   (E = phase, stashed)
    mov al, dh                     ; ld a, d   (A = amplitude, the multiplier)
    movzx edx, cl                  ; ld d, $0  (DE = 0:phase)
    mov esi, Unkn_fa0aa            ; ld hl, Unkn_fa0aa (flat sine table)
    lea esi, [esi + edx*2]         ; add hl,de / add hl,de  (hl = table + 2*phase)
    movzx edx, word [esi]          ; ld e,[hl]/inc hl/ld d,[hl]  (DE = sine_table[phase])
    xor edi, edi                   ; ld hl, $0  (HL accumulator)
.asm_fa09d:
    shr al, 1                      ; srl a  (CF = old bit0)
    jnc .asm_fa0a2                 ; jr nc
    add di, dx                     ; add hl, de
.asm_fa0a2:
    shl dx, 1                      ; sla e / rl d  (DE <<= 1, 16-bit)
    test al, al                    ; and a
    jnz .asm_fa09d                 ; jr nz
    movzx esi, di                  ; return HL (product) in ESI
    ret

section .data

; Sub-jumptable for Func_fa02b — flat code addresses (see the DEVIATION above).
Jumptable_fa03b:
    dd Func_fa03f
    dd Func_fa051

; Spawn-state table — each entry: db FramesetID, AnimSeqID (callback index),
; unused. Indexed by spawn id. Byte-for-byte pret (no internal pointers);
; staged into GB space at W_INTRO_SPAWN_DATA by
; CopyYellowIntroAnimatedObjectData, read by the engine at
; [ebp + wAnimatedObjectSpawnStateDataPointer].
global YellowIntro_AnimatedObjectSpawnStateData
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
YellowIntro_AnimatedObjectSpawnStateDataEnd:
; Static assert: the assembled size must equal the gb_memmap.inc staging size.
times ((YellowIntro_AnimatedObjectSpawnStateDataEnd - YellowIntro_AnimatedObjectSpawnStateData) - W_INTRO_SPAWN_DATA_SIZE) db 0
times (W_INTRO_SPAWN_DATA_SIZE - (YellowIntro_AnimatedObjectSpawnStateDataEnd - YellowIntro_AnimatedObjectSpawnStateData)) db 0

; The animated-object callback jumptable — flat 32-bit code addresses, consumed
; by ExecuteCurrentAnimatedObjectCallback (data-model DEVIATION annotated there).
YellowIntro_AnimatedObjectJumptable:
    dd Func_fa007
    dd Func_fa007
    dd Func_fa008
    dd Func_fa014
    dd Func_fa02b
    dd Func_fa062

; Unkn_fa0aa — pret `sine_table 32`: dw sin(x*0.5/32) as RGBDS Q16 fractions,
; i.e. round(sin(pi*x/32) * 65536) & 0xffff for x=0..31. Verified byte-exact
; against rgbasm. (x=16 is 0x0000 — RGBDS truncates sin(0.25turn)=1.0 to the low
; word; faithful to pret.) Read flat by Func_fa08e.
Unkn_fa0aa:
    dw 0x0000, 0x1918, 0x31f1, 0x4a50, 0x61f8, 0x78ad, 0x8e3a, 0xa268
    dw 0xb505, 0xc5e4, 0xd4db, 0xe1c6, 0xec83, 0xf4fa, 0xfb15, 0xfec4
    dw 0x0000, 0xfec4, 0xfb15, 0xf4fa, 0xec83, 0xe1c6, 0xd4db, 0xc5e4
    dw 0xb505, 0xa268, 0x8e3a, 0x78ad, 0x61f8, 0x4a50, 0x31f1, 0x1918

; Scene dispatch table (flat 32-bit code addresses, indexed by
; wYellowIntroCurrentScene). Unported scenes point at YellowIntro_NextScene
; (auto-advance scaffold) — repoint each as its scene lands (B3.2d).
Jumptable_f9906:
    dd YellowIntroScene0
    dd YellowIntroScene1
    dd YellowIntroScene2
    dd YellowIntroScene3
    dd YellowIntroScene4
    dd YellowIntroScene5
    dd YellowIntroScene6
    dd YellowIntroScene7
    dd YellowIntroScene8
    dd YellowIntroScene9
    dd YellowIntroScene10
    dd YellowIntroScene11
    dd YellowIntroScene12
    dd YellowIntroScene13
    dd YellowIntroScene14
    dd YellowIntroScene15
    dd YellowIntroScene16
    dd YellowIntroScene17

; DMG-palette fade sequences (one byte per frame, 0xff terminates). Flat data,
; read by YellowIntro_LoadDMGPalAndIncrementCounter.
global YellowIntroPalSequence_f9dd6, YellowIntroPalSequence_f9e0a
YellowIntroPalSequence_f9dd6:
    db 0xe4, 0xc0, 0xc0, 0xe4
    db 0xe4, 0xc0, 0xc0, 0xe4
    db 0xe4, 0xc0, 0xc0, 0xe4
    db 0xe4, 0xc0, 0xc0, 0xe4
    db 0xe4, 0xc0, 0xc0, 0xe4
    db 0xe4, 0xc0, 0xc0, 0xe4
    db 0xe4, 0xc0, 0xc0, 0xe4
    db 0xe4, 0xc0, 0xc0, 0xe4
    db 0xe4, 0xc0, 0xc0, 0xe4
    db 0xe4, 0xc0, 0xc0, 0xe4
    db 0xe4, 0xc0, 0xc0, 0xe4
    db 0xe4, 0xc0, 0xc0, 0xe4
    db 0xe4, 0xc0, 0xc0, 0xff
YellowIntroPalSequence_f9e0a:
    db 0xe4, 0x90, 0x90, 0x40
    db 0x40, 0x00, 0x00, 0xff

; amplitude-4 sine wave, copied 8x into wLYOverridesBuffer by Copy8BitSineWave.
YellowIntroSineWave8:
    db  0,  0,  1,  2,  2,  3,  3,  3
    db  4,  3,  3,  3,  2,  2,  1,  0
    db  0,  0, -1, -2, -2, -3, -3, -3
    db -4, -3, -3, -3, -2, -2, -1,  0
YellowIntroSineWave8End:

; Flying speed-bar spawn table (scene 2): y, x, speed per object.
global YellowIntroFlyingSpeedBarData
YellowIntroFlyingSpeedBarData:
    db 0xd0, 0x20, 0x02
    db 0xf0, 0x30, 0x04
    db 0xd0, 0x40, 0x06
    db 0xc0, 0x50, 0x08
    db 0xe0, 0x60, 0x08
    db 0xc0, 0x70, 0x06
    db 0xe0, 0x80, 0x04
    db 0xf0, 0x90, 0x02

; --- Yellow-intro gfx (B3.2b, gen_intro_gfx_inc.py; verified byte-exact vs the
; pret gfx/intro/*.2bpp). Loaded to VRAM by InitYellowIntroGFXAndMusic (B3.2c);
; the tilemaps are placed by scene 10. Flat program-image data. ---
global YellowIntroGraphics1, YellowIntroGraphics2
; YellowIntroCloudGFX and Unkn_f9b6e/be6/bf2 are declared `global` by their own
; generated .inc now (gen_intro_gfx_inc.py via gen_globals.insert_globals) — the
; file that DEFINES a label declares it, which is what clears [local_shadow].
%include "assets/yellow_intro_1_2bpp.inc"       ; YellowIntroGraphics1 (128 tiles)
%include "assets/yellow_intro_2_2bpp.inc"       ; YellowIntroGraphics2 (256 tiles)
%include "assets/yellow_intro_clouds_2bpp.inc"  ; YellowIntroCloudGFX (8 tiles)

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
extern g_tilecache_dirty
global RunAnimObjectTest

section .text

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
    mov word [ebp + wAnimatedObjectSpawnStateDataPointer], W_INTRO_SPAWN_DATA
    mov word [ebp + wAnimatedObjectFramesDataPointer], W_INTRO_FRAMES_DATA
    mov word [ebp + wAnimatedObjectOAMDataPointer], W_INTRO_OAM_DATA
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
%include "assets/yellow_intro_tilemaps.inc"     ; Unkn_f9b6e/be6/bf2
