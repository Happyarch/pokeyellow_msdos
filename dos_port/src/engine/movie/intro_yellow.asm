; intro_yellow.asm — the Yellow intro's animated-object behavior callbacks.
;
; Faithful translation of the animated-object jumptable + callbacks + sine
; helpers from pret engine/movie/intro_yellow.asm (menu-intro B3.1). These are
; the per-object behaviors ExecuteCurrentAnimatedObjectCallback dispatches to
; (via YellowIntro_AnimatedObjectJumptable). The scene engine (PlayIntroScene,
; InitYellowIntroGFXAndMusic, scene dispatch 0-17, Func_fa06e, gfx/tilemaps)
; rides later B3 increments; this file will grow to hold them.
;
; Register map (as reached from the engine): EBX = current-struct base (pret BC),
; ESI = HL, EDX = DE, AL = A, EBP = GB base. Struct byte offsets are raw literals
; exactly as pret: 4 XCoord, 5 YCoord, 7 YOffset, b FieldB, c FieldC.
;
; Build: nasm -f coff -I include/ -I . -o intro_yellow.o \
;        src/engine/movie/intro_yellow.asm

bits 32

%include "gb_memmap.inc"

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

extern YellowIntroFramesData_GB, YellowIntroOAMData_GB, YellowIntroSpawnData_GB
extern SpawnAnimatedObject, MaskCurrentAnimatedObjectStruct, MaskAllAnimatedObjectStructs
extern DelayFrames, DelayFrame, DisableLCD, FillMemory
extern UpdateCGBPal_BGP, UpdateCGBPal_OBP0, UpdateCGBPal_OBP1
extern CopyVideoData, RunPaletteCommand, PlayMusic, ClearObjectAnimationBuffers
extern MovieBeginSurface, MovieEndSurface, PublishProjectedOAM, JoypadLowSensitivity
extern RunObjectAnimations, UpdateMusicCTimes

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
; addresses into the copied blob; the jumptable is a 32-bit flat pointer (B1
; data-model split).
; ---------------------------------------------------------------------------
LoadYellowIntroObjectAnimationDataPointers:
    ; The GB addresses are external absolutes; COFF has no 16-bit relocation, so
    ; load each into EAX (32-bit reloc) and store its low word.
    mov eax, YellowIntroSpawnData_GB
    mov [ebp + wAnimatedObjectSpawnStateDataPointer], ax
    mov dword [ebp + wAnimatedObjectJumptablePointer], YellowIntro_AnimatedObjectJumptable
    mov eax, YellowIntroOAMData_GB
    mov [ebp + wAnimatedObjectOAMDataPointer], ax
    mov eax, YellowIntroFramesData_GB
    mov [ebp + wAnimatedObjectFramesDataPointer], ax
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
; DEVIATION{class=HAL; pret=engine/movie/intro_yellow.asm:YellowIntroScene14; behavior=the two hAutoBGTransferEnabled stores gating the wTileMap->vBGMap0 auto-transfer are dropped while the three DelayFrame waits remain, because the port surface mirror copies W_TILEMAP every frame with no enable flag; evidence=hAutoBGTransferEnabled was retired when the surface mirror replaced the GB auto BG transfer and the compositor renders directly from W_TILEMAP; lifetime=permanent surface-mirror model}
; DEVIATION{class=projection; pret=engine/movie/intro_yellow.asm:YellowIntroScene14; behavior=the wTileMap row fills use the port 40-tile W_TILEMAP row stride instead of the GB 20-tile stride, so each SCREEN_WIDTH*N fill becomes SCREEN_TILES_W*N; evidence=the compositor renders the BG from the 40-wide W_TILEMAP not the GB shadow map, the same redirect as Func_f9e5f; lifetime=permanent widescreen tilemap model}
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
    mov esi, W_TILEMAP                             ; ld hl, wTileMap
    mov bx, 4 * SCREEN_TILES_W                     ; ld bc, SCREEN_WIDTH * 4
    mov al, 0x1
    call FillMemory                                ; call Bank3E_FillMemory
    mov esi, W_TILEMAP + 4 * SCREEN_TILES_W        ; hlcoord 0, 4
    mov bx, 10 * SCREEN_TILES_W                    ; ld bc, SCREEN_WIDTH * 10
    xor al, al
    call FillMemory
    mov esi, W_TILEMAP + 14 * SCREEN_TILES_W       ; hlcoord 0, 14
    mov bx, 4 * SCREEN_TILES_W                     ; ld bc, SCREEN_WIDTH * 4
    mov al, 0x1
    call FillMemory
    ; hAutoBGTransferEnabled=1 dropped (surface mirror; see DEVIATION)
    call DelayFrame
    call DelayFrame
    call DelayFrame
    ; hAutoBGTransferEnabled=0 dropped
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
; `jp hl`. Jumptable_f9906 entries for scenes not yet ported point at
; YellowIntro_NextScene so the intro auto-advances past them (temporary scaffold;
; repoint each as its scene lands — B3.2d milestone).
; ---------------------------------------------------------------------------
Func_f98fc:
    mov al, [ebp + wYellowIntroCurrentScene]       ; ld a, [wYellowIntroCurrentScene]
    mov esi, Jumptable_f9906                        ; ld hl, Jumptable_f9906
    call Func_fa06e                                 ; hl = Jumptable_f9906[a]
    jmp esi                                          ; jp hl

; ---------------------------------------------------------------------------
; InitYellowIntroGFXAndMusic — blank the tilemap, load the intro tile sheets to
; VRAM, point the object engine at the intro tables, set the generic palette and
; music, and zero the scene state. The retired hAutoBGTransferEnabled/Dest writes
; are omitted (the cinematic surface mirror handles BG transfer, not the GB's
; VBlank auto-transfer). Graphics2 loads 255 tiles (pret's (size-$10)/$10).
; ---------------------------------------------------------------------------
InitYellowIntroGFXAndMusic:
    xor al, al
    mov [ebp + H_SCX], al                          ; ldh [hSCX], a
    mov [ebp + H_SCY], al                          ; ldh [hSCY], a
    call YellowIntro_BlankTileMap
    mov esi, W_TILEMAP                             ; ld hl, wTileMap
    mov bx, SCREEN_AREA                            ; ld bc, SCREEN_AREA
    mov al, 0x1                                    ; ld a, $1
    call FillMemory
    mov esi, W_TILEMAP + 4 * SCREEN_TILES_W        ; hlcoord 0, 4
    mov bx, SCREEN_TILES_W * 10                    ; ld bc, SCREEN_WIDTH * 10
    xor al, al
    call FillMemory
    call DelayFrame                                ; pret waits 3 frames for the (retired)
    call DelayFrame                                ; auto-transfer; kept for frame timing
    call DelayFrame
    mov edx, YellowIntroGraphics2                  ; ld de, YellowIntroGraphics2
    mov esi, GB_VCHARS0                            ; ld hl, vChars0
    mov bl, YELLOWINTROGRAPHICS2_TILES - 1          ; (End - Start - $10) / $10
    call CopyVideoData
    mov edx, YellowIntroGraphics1                  ; ld de, YellowIntroGraphics1
    mov esi, GB_VCHARS2                            ; ld hl, vChars2
    mov bl, YELLOWINTROGRAPHICS1_TILES              ; (End - Start) / $10
    call CopyVideoData
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
; DEVIATION{class=projection; pret=engine/movie/intro_yellow.asm:PlayIntroScene; behavior=wraps the loop in MovieBeginSurface/MovieEndSurface and republishes the animated-object shadow OAM through PublishProjectedOAM each frame instead of the GB VBlank OAM DMA, and the rIE/rIF/rSTAT + hAutoBGTransferEnabled hardware setup is dropped; evidence=the port renders OBJ from a projected shadow onto the cinematic surface (UI_YELLOW_INTRO) and uses its own PIT/keyboard ISR, not GB interrupts or VBlank auto-transfer; lifetime=permanent widescreen/flat-memory model}
; ---------------------------------------------------------------------------
PlayIntroScene:
    ; pret saves rIE/rIF/rSTAT here (GB interrupt + STAT setup) — the port uses
    ; its own PIT/keyboard ISR, so it is dropped.
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
    call DelayFrame
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
    ; hAutoBGTransferEnabled toggle retired (surface mirror handles BG) — omit.
    call DelayFrame
    call DelayFrame
    call DelayFrame
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
; Func_f9e5f — lay out the BG for the framed scenes: rows 0-3 tile $1, rows 4-13
; tile $0, rows 14-17 tile $1. Establishes the BG-map redirect all vBGMap0-writing
; even scenes use.
;
; DEVIATION{class=projection; pret=engine/movie/intro_yellow.asm:Func_f9e5f; behavior=the vBGMap0 ($9800 GB BG map) fills are redirected to the port's canonical W_TILEMAP at its 40-tile row stride (the surface mirror carries W_TILEMAP to GB_TILEMAP0), so the multi-row fills become contiguous W_TILEMAP row ranges; evidence=the cinematic compositor renders the BG from W_TILEMAP not the 32-wide GB BG map, proven by the running intro whose Init W_TILEMAP fill renders; lifetime=permanent widescreen tilemap model}
; ---------------------------------------------------------------------------
Func_f9e5f:
    mov esi, W_TILEMAP                              ; vBGMap0 rows 0-3 (GB $80 = 4x32)
    mov bx, 4 * SCREEN_TILES_W                      ; 4 rows x 40
    mov al, 0x1
    call FillMemory
    mov esi, W_TILEMAP + 4 * SCREEN_TILES_W         ; rows 4-13 (GB $140 = 10x32)
    mov bx, 10 * SCREEN_TILES_W                     ; 10 rows x 40
    xor al, al
    call FillMemory
    mov esi, W_TILEMAP + 14 * SCREEN_TILES_W        ; rows 14-17 (GB $80 = 4x32)
    mov bx, 4 * SCREEN_TILES_W                      ; 4 rows x 40
    mov al, 0x1
    call FillMemory
    ret

; ---------------------------------------------------------------------------
; Func_f9e9a — per-scene reset: scroll/window to 0/0/$90, LCDC on, DMG palettes
; ($e4/$e4/$e0), CGB palettes applied. In: AL = palette variant (CGB-only).
;
; DEVIATION{class=HAL; pret=engine/movie/intro_yellow.asm:Func_f9e9a; behavior=the callfar YellowIntroPaletteAction (CGB palette-RAM + SGB packet setup) is dropped, and the DMG rBGP/rOBP shadows this routine also writes drive the port's rendering instead; evidence=CGB->VGA palette translation is the Phase-5 boundary (YellowIntroPaletteAction's InitCGBPalettes/SendSGBPacket are unported) and the port renders DMG shades from the IO palette shadows; lifetime=Phase-5 CGB palette port}
; ---------------------------------------------------------------------------
Func_f9e9a:
    ; ld e, a — variant selector, only read by the omitted YellowIntroPaletteAction.
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
    dd YellowIntro_NextScene        ; scene 2  (unported)
    dd YellowIntroScene3
    dd YellowIntroScene4
    dd YellowIntroScene5
    dd YellowIntro_NextScene        ; scene 6  (unported)
    dd YellowIntro_NextScene        ; scene 7  (unported)
    dd YellowIntroScene8
    dd YellowIntroScene9
    dd YellowIntro_NextScene        ; scene 10 (unported)
    dd YellowIntro_NextScene        ; scene 11 (unported)
    dd YellowIntro_NextScene        ; scene 12 (unported)
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
global YellowIntroGraphics1, YellowIntroGraphics2, YellowIntroCloudGFX
global Unkn_f9b6e, Unkn_f9be6, Unkn_f9bf2
%include "assets/yellow_intro_1_2bpp.inc"       ; YellowIntroGraphics1 (128 tiles)
%include "assets/yellow_intro_2_2bpp.inc"       ; YellowIntroGraphics2 (256 tiles)
%include "assets/yellow_intro_clouds_2bpp.inc"  ; YellowIntroCloudGFX (8 tiles)
%include "assets/yellow_intro_tilemaps.inc"     ; Unkn_f9b6e/be6/bf2
