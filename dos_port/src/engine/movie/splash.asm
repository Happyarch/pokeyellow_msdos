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
%define UI_LAYOUT_EQUATES_ONLY 1
%include "assets/ui_layout_intro.inc"   ; UI_SPLASH_COL / UI_SPLASH_ROW

extern UpdateCGBPal_OBP0             ; home/cgb_palettes.asm — commit rOBP0 to the DAC
extern UpdateCGBPal_OBP1             ; home/cgb_palettes.asm
extern CopyVideoData                 ; home/copy2.asm — ESI=VRAM dest, EDX=flat src, BL=tiles
extern MoveAnimationTiles1           ; engine/overworld/cut.asm — battle move-anim tile sheet
extern CheckForUserInterruption      ; src/home/overworld.asm — BL frames, CF on skip
extern PublishProjectedOAM           ; engine/gfx/sprite_oam.asm — project wShadowOAM to the canvas
extern PlaySound                     ; home/audio.asm — AL = sound id
extern CopyData                      ; home/copy.asm — ESI/EDX EBP-relative, BX count
extern DelayFrame                    ; video/frame.asm — wait one frame
extern PlayIntro                     ; engine/movie/intro.asm — full boot cinematic (RunSplashTest harness)

%include "assets/audio_constants.inc"   ; SFX_SHOOTING_STAR

; wMoveDownSmallStarsOAMCount (pokeyellow.sym 00:cd3d) — not yet in gb_memmap.inc;
; report to root for promotion. %ifndef-guarded so promotion is a no-op here.
%ifndef wMoveDownSmallStarsOAMCount
wMoveDownSmallStarsOAMCount equ 0xCD3D
%endif

section .text

; ---------------------------------------------------------------------------
; publish_splash_oam — port-only: project the splash's canonical wShadowOAM onto
; the cinematic canvas (offset 80,24) so the OBJ render each frame. pret relies on
; the VBlank OAM DMA; the port renders OBJ from the projected shadow, so the splash
; publishes before every frame wait (cf. MovePicLeft's MovieSyncWindow). All
; registers preserved (pushad/popad).
; ---------------------------------------------------------------------------
publish_splash_oam:
    pushad
    mov esi, W_SHADOW_OAM                 ; canonical Y,X,tile,attr records
    mov ecx, 40                           ; all 40 OBJ slots
    mov eax, UI_SPLASH_COL * 8            ; projection X offset (80)
    mov ebx, UI_SPLASH_ROW * 8            ; projection Y offset (24)
    call PublishProjectedOAM
    popad
    ret

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

; ---------------------------------------------------------------------------
; AnimateShootingStar — the full splash animation: the big star sweeps down-left
; off-screen, the Game Freak logo flashes, then 4 waves of small stars fall from it.
; Source: engine/movie/splash.asm:AnimateShootingStar. (Calls publish_splash_oam
; before each frame wait — the port's OAM projection, documented there; the OAM
; priming copies live in LoadShootingStarGraphics, see its data-model note.)
;
; In: EBP = GB base. Out: CF set if the user skipped. Clobbers EAX/EBX/ECX/EDX/ESI/EDI.
; ---------------------------------------------------------------------------
global AnimateShootingStar
AnimateShootingStar:
    call LoadShootingStarGraphics
    mov al, SFX_SHOOTING_STAR
    call PlaySound
    ; --- big star: move down (+4 Y) and left (-4 X) until Y wraps to $a0 ---
    mov esi, W_SHADOW_OAM                  ; ld hl, wShadowOAM
    mov bh, 0xA0                           ; b = target Y ($a0)
    mov bl, 4                              ; c = 4 OBJ entries
.bigStarLoop:
    push esi                               ; push hl
    push ebx                               ; push bc
.bigStarInner:
    add byte [ebp + esi], 4                ; [Y] += 4
    inc esi
    sub byte [ebp + esi], 4                ; [X] += -4
    inc esi
    inc esi                                ; skip tile
    inc esi                                ; skip attr
    dec bl
    jnz .bigStarInner
    call publish_splash_oam                ; PORT: project before the frame wait
    mov bl, 1                              ; ld c, 1
    call CheckForUserInterruption
    pop ebx
    pop esi
    jc .done                               ; ret c
    mov al, [ebp + esi]                    ; a = [hl] (Y of entry 0)
    cmp al, 80
    jne .bsNext
    jmp .bigStarLoop                       ; Y == 80 → keep going
.bsNext:
    cmp al, bh                             ; cp b ($a0)
    jne .bigStarLoop                       ; Y != $a0 → keep going
    ; --- clear the 4 big-star OBJ (park off the bottom) ---
    mov esi, W_SHADOW_OAM                  ; wShadowOAMSprite00YCoord
    mov bl, 4
.clearLoop:
    mov byte [ebp + esi], SCREEN_H + OAM_Y_OFS  ; 144 + 16 = 160
    add esi, OAM_ENTRY_SIZE                       ; add hl, de (de = OBJ_SIZE)
    dec bl
    jnz .clearLoop
    ; --- flash the Game Freak logo (rotate OBP0 twice, 3 times) ---
    mov bh, 3                              ; ld b, 3
.flashLoop:
    ror byte [ebp + IO_OBP0], 1            ; rrc [hl] (rOBP0)
    ror byte [ebp + IO_OBP0], 1            ; rrc [hl]
    call UpdateCGBPal_OBP0
    call publish_splash_oam
    mov bl, 10                             ; ld c, 10
    call CheckForUserInterruption
    jc .done
    dec bh
    jnz .flashLoop
    ; --- prime 24 small-star OBJ (off-screen), from the SmallStarsOAM template ---
    mov edx, W_SHADOW_OAM                  ; ld de, wShadowOAM (GB dest, advances)
    mov eax, 24                            ; ld a, 24 (rep movsb leaves EAX untouched)
.initSmall:
    mov esi, SmallStarsOAM                 ; flat template
    lea edi, [ebp + edx]
    mov ecx, SmallStarsOAMEnd - SmallStarsOAM
    rep movsb
    add edx, SmallStarsOAMEnd - SmallStarsOAM
    dec eax
    jnz .initSmall
    ; --- 4 waves of small stars fall from the logo ---
    mov byte [ebp + wMoveDownSmallStarsOAMCount], 0
    mov esi, SmallStarsWaveCoordsPointerTable   ; ld hl, table
    mov bl, 6                              ; ld c, 6 (6 waves, last two empty)
.waveLoop:
    mov edx, [esi]                         ; the wave-coords pointer (dd flat vs pret dw)
    add esi, 4
    push ebx                               ; push bc (wave count)
    push esi                               ; push hl (table ptr)
    mov esi, W_SHADOW_OAM + 20 * 4         ; ld hl, wShadowOAMSprite20
    mov bl, 4                              ; ld c, 4 (4 stars per wave)
.waveInner:
    mov al, [edx]                          ; a = [de] (Y coord, flat)
    cmp al, 0xFF
    je .waveDone                           ; -1 = empty wave, stop
    mov [ebp + esi], al                    ; [hli] = Y
    inc esi
    inc edx
    mov al, [edx]                          ; X
    mov [ebp + esi], al                    ; [hli] = X
    inc esi
    inc edx
    inc esi                                ; skip tile
    mov ah, [edx]                          ; b = [de] (attr-nibble byte)
    mov al, [ebp + esi]                    ; a = [hl]
    and al, 0xF0
    or al, ah                              ; merge the low nibble
    mov [ebp + esi], al
    inc edx
    inc esi                                ; past attr
    dec bl
    jnz .waveInner
    mov al, [ebp + wMoveDownSmallStarsOAMCount]
    cmp al, 24
    je .waveDone
    add al, 6                              ; +6 (pret note: 4 visible, 2 off-screen)
    mov [ebp + wMoveDownSmallStarsOAMCount], al
.waveDone:
    call MoveDownSmallStars                ; steps them down; CF = skip
    pushfd                                 ; push af (save the skip flag)
    ; shift the on-screen entries down one slot (GB->GB, real CopyData)
    mov esi, W_SHADOW_OAM + 4 * 4          ; ld hl, wShadowOAMSprite04
    mov edx, W_SHADOW_OAM                  ; ld de, wShadowOAM
    mov bx, OAM_ENTRY_SIZE * 20                  ; ld bc, OBJ_SIZE * 20
    call CopyData
    popfd                                  ; pop af
    pop esi                                ; pop hl (table ptr)
    pop ebx                                ; pop bc (wave count)
    jc .done                               ; ret c (MoveDownSmallStars was skipped)
    dec bl                                 ; dec c
    jnz .waveLoop
    xor al, al                             ; and a — clear CF (no skip)
.done:
    ret

; ---------------------------------------------------------------------------
; MoveDownSmallStars — over 8 frames, walk the falling small stars down by their
; current count and blink the lower star (toggle OBP1). Source:
; engine/movie/splash.asm:MoveDownSmallStars. (Calls publish_splash_oam before each
; frame wait — the port's OAM projection, documented there.)
;
; In: EBP = GB base. Out: CF set if the user skipped. Clobbers EAX/EBX/ESI.
; ---------------------------------------------------------------------------
global MoveDownSmallStars
MoveDownSmallStars:
    mov bh, 8                             ; ld b, 8
.loop:
    mov esi, W_SHADOW_OAM + 23 * 4        ; ld hl, wShadowOAMSprite23
    movzx eax, byte [ebp + wMoveDownSmallStarsOAMCount]
    mov bl, al                            ; ld c, a (entries to step; always >= 6 at call sites)
.innerLoop:
    inc byte [ebp + esi]                  ; inc [hl] — the OBJ Y coordinate
    sub esi, 4                            ; add hl, de (de = -OBJ_SIZE)
    dec bl
    jnz .innerLoop
    ; blink the lower small-star row: toggle OBP1 bits 5+7
    mov al, [ebp + IO_OBP1]               ; ldh a, [rOBP1]
    xor al, 0xA0                          ; xor %10100000
    mov [ebp + IO_OBP1], al               ; ldh [rOBP1], a
    call UpdateCGBPal_OBP1
    call publish_splash_oam               ; PORT: project the OAM before the frame wait
    mov bl, 3                             ; ld c, 3
    call CheckForUserInterruption
    jc .done                              ; ret c
    dec bh                                ; dec b
    jnz .loop
.done:
    ret


%ifdef DEBUG_CINEMATIC_SPLASH
; ---------------------------------------------------------------------------
; RunSplashTest — B2/B4 pixel harness: run the full PlayIntro (splash -> intro) and
; park. AUTOKEY_QUIET photographs a frame at AUTOKEY_DUMP_FRAME. Never returns.
; ---------------------------------------------------------------------------
global RunSplashTest
RunSplashTest:
    call PlayIntro                        ; the full boot cinematic (splash + intro)
.hang:
    call DelayFrame
    jmp .hang
%endif

section .data
align 4

; Falling-star tile graphic (pret engine/movie/splash.asm INCBIN). GameFreakIntro
; moved to intro.asm (pret intro.asm); CopyrightTextString moved to title.asm.
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
