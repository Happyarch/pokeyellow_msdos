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
extern CheckForUserInterruption      ; home/check_user_interruption.asm — BL frames, CF on skip
extern PublishProjectedOAM           ; engine/gfx/sprite_oam.asm — project wShadowOAM to the canvas
extern PlaySound                     ; home/audio.asm — AL = sound id
extern CopyData                      ; home/copy_data.asm — ESI/EDX EBP-relative, BX count
extern RunPaletteCommand             ; home/palettes.asm — BH = SET_PAL_* command
extern UpdateCGBPal_BGP              ; home/cgb_palettes.asm — commit rBGP to the DAC
extern ClearSprites                  ; home/sprites.asm — zero shadow OAM + count
extern Delay3                        ; video/frame.asm — wait 3 frames
extern DelayFrames                   ; video/frame.asm — BL = frame count
extern FillMemory                    ; home/copy_data.asm — ESI dest, BX count, AL value
extern MovieBeginSurface             ; movie_projection.asm — black-matte cinematic surface
extern MovieEndSurface               ; movie_projection.asm — tear down the surface
extern DelayFrame                    ; video/frame.asm — wait one frame
extern PlayIntroScene                ; engine/movie/intro_yellow.asm — the Yellow intro scenes (B3)
extern g_tilecache_dirty             ; ppu.asm — arm the tile-cache rebuild
extern ClearScreen                   ; movie/title.asm — clear the surface tilemap
extern LoadTextBoxTilePatterns       ; home/load_font.asm — font_extra -> vChars2 $60
extern title_copyright_2bpp          ; movie/title.asm — = NintendoCopyrightLogoGraphics (full copyright.png)

%include "assets/audio_constants.inc"   ; SFX_SHOOTING_STAR

hAutoBGTransferEnabled equ H_AUTO_BG_TRANSFER_EN   ; pret name (inert byte; consumer do_bg_transfer retired)

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

; Cinematic BG-drawing origin (same as intro_yellow.asm INTRO_BG_ORIGIN and
; title.asm TITLE_ORIGIN): MovieMirrorSurface reads the visible 18x20 window from
; W_TILEMAP + UI_SPLASH_ROW*SCREEN_TILES_W + UI_SPLASH_COL (row 3, col 10), so BG
; content is authored at that origin. Row-range fills add the row part; the whole-
; surface clear covers everything so it stays at 0.
SPLASH_BG_ROW_OFF  equ UI_SPLASH_ROW * SCREEN_TILES_W       ; = 120 (row-only origin)
SPLASH_BG_ORIGIN   equ SPLASH_BG_ROW_OFF + UI_SPLASH_COL    ; = 130 (full origin, for coord placement)

; ---------------------------------------------------------------------------
; IntroDrawBlackBars — draw the splash's framing bars (bar tile $1 = the $ff tile,
; which is white under the splash palette) on GB rows 0-3 and 14-17, clearing the
; surface first. Source: engine/movie/intro.asm:IntroDrawBlackBars (+ IntroClear
; Screen / IntroClearMiddleOfScreen / IntroClearCommon / IntroPlaceBlackTiles).
; BG writes use the cinematic origin (SPLASH_BG_ROW_OFF above); pret's vBGMap0 and
; vBGMap1 bar writes both land on the single W_TILEMAP canvas (there is no second
; BG map) — the port's surface model, not a per-routine deviation.
; ---------------------------------------------------------------------------
global IntroDrawBlackBars
IntroDrawBlackBars:
    call IntroClearScreen
    mov esi, W_TILEMAP + SPLASH_BG_ROW_OFF                 ; GB rows 0-3 -> surface rows 0-3
    mov ecx, 4 * SCREEN_TILES_W                            ; ld c, SCREEN_WIDTH * 4
    call IntroPlaceBlackTiles
    mov esi, W_TILEMAP + SPLASH_BG_ROW_OFF + 14 * SCREEN_TILES_W  ; GB rows 14-17
    mov ecx, 4 * SCREEN_TILES_W
    call IntroPlaceBlackTiles
    mov esi, W_TILEMAP + SPLASH_BG_ROW_OFF                 ; ld hl, vBGMap1  (-> same surface)
    mov ecx, 4 * SCREEN_TILES_W                            ; ld c, TILEMAP_WIDTH * 4
    call IntroPlaceBlackTiles
    mov esi, W_TILEMAP + SPLASH_BG_ROW_OFF + 14 * SCREEN_TILES_W  ; hlbgcoord 0,14,vBGMap1
    mov ecx, 4 * SCREEN_TILES_W
    jmp IntroPlaceBlackTiles                               ; jp IntroPlaceBlackTiles

; IntroClearScreen — clear the whole surface (pret clears vBGMap1 32x18; the port
; clears all of W_TILEMAP, which covers the visible window). Falls into common.
global IntroClearScreen
IntroClearScreen:
    mov esi, W_TILEMAP                                     ; ld hl, vBGMap1 (whole surface)
    mov ecx, SCREEN_AREA                                   ; ld bc, TILEMAP_WIDTH * SCREEN_HEIGHT
    jmp IntroClearCommon

; IntroClearMiddleOfScreen — clear GB rows 4-13 (between the bars) at the origin.
global IntroClearMiddleOfScreen
IntroClearMiddleOfScreen:
    mov esi, W_TILEMAP + SPLASH_BG_ROW_OFF + 4 * SCREEN_TILES_W   ; hlcoord 0, 4
    mov ecx, 10 * SCREEN_TILES_W                           ; ld bc, SCREEN_WIDTH * 10
    ; fall through
global IntroClearCommon
IntroClearCommon:
    mov byte [ebp + esi], 0                                ; ld [hl], 0
    inc esi
    dec ecx                                                ; dec bc / ld a,b / or c
    jnz IntroClearCommon
    ret

; IntroPlaceBlackTiles — fill ECX W_TILEMAP cells (from ESI) with bar tile 1.
global IntroPlaceBlackTiles
IntroPlaceBlackTiles:
    mov al, 1                                              ; ld a, 1
.loop:
    mov [ebp + esi], al                                   ; ld [hli], a
    inc esi
    dec ecx                                                ; dec c
    jnz .loop
    ret

; ---------------------------------------------------------------------------
; LoadCopyrightAndTextBoxTiles — the boot copyright screen. Loads the textbox font
; tiles + the Nintendo copyright logo graphic to vChars2 $60, then lays out the three
; "©1995-1999  Nintendo / Creatures inc. / GAME FREAK inc." lines at surface coord
; (col 2, row 7). Source: engine/movie/title.asm:LoadCopyrightAndTextBoxTiles (+
; LoadCopyrightTiles).
;
; The copyright-logo graphic occupies vChars2 $60-$72 (19 tiles); the "GAME FREAK
; inc." glyphs ($73-$7b) and the hyphen/space ($7c/$7f) come from the font_extra
; tiles that LoadTextBoxTilePatterns leaves at $73-$7F. CopyrightTextString is a
; tile-index layout (like title.asm's CopyrightRowTiles), placed directly rather
; than through PlaceString, whose dialog-box stride does not fit the cinematic canvas.
;
; DEVIATION{class=data-model; pret=engine/movie/title.asm:LoadCopyrightTiles; behavior=the copyright graphic is loaded as its exact 19 tiles instead of pret's count of 20, which on the GB overflows one tile past NintendoCopyrightLogoGraphics into the adjacent TextBoxGraphics ("A" tile); evidence=in the port's flat data model the two assets are not adjacent so the overflow would read unrelated bytes, and the 19 real tiles are what the layout references; lifetime=permanent flat-memory model}
; ---------------------------------------------------------------------------
global LoadCopyrightAndTextBoxTiles
LoadCopyrightAndTextBoxTiles:
    mov byte [ebp + H_WY], 0              ; ldh [hWY], a
    call ClearScreen                      ; clear the surface tilemap
    call LoadTextBoxTilePatterns          ; font_extra -> vChars2 $60-$7F
    ; fall through into LoadCopyrightTiles (a separate pret entry point)
global LoadCopyrightTiles
LoadCopyrightTiles:
    mov esi, GB_VCHARS2 + 0x60 * TILE_SIZE ; ld hl, vChars2 tile $60
    mov edx, title_copyright_2bpp          ; ld de, NintendoCopyrightLogoGraphics (flat)
    mov bl, 19                             ; 19 real copyright tiles (see DEVIATION)
    call CopyVideoData                     ; overwrites vChars2 $60-$72
    ; place the 3-line tile-index layout at the cinematic origin, coord (col 2, row 7)
    lea edx, [ebp + W_TILEMAP + SPLASH_BG_ORIGIN + 7 * SCREEN_TILES_W + 2] ; line start (flat)
    mov esi, edx
    mov edi, CopyrightTextString
.place_char:
    mov al, [edi]
    inc edi
    cmp al, 0x50                          ; "@" terminator
    je .done
    cmp al, 0x4E                          ; "next" (newline)
    je .newline
    mov [esi], al                         ; write the tile index (rendered from vChars2, signed mode)
    inc esi
    jmp .place_char
.newline:
    add edx, SCREEN_TILES_W               ; next surface row, same start col
    mov esi, edx
    jmp .place_char
.done:
    ret

; ---------------------------------------------------------------------------
; PlayShootingStar — the Game Freak "shooting star" splash (pret engine/movie/
; intro.asm:PlayShootingStar). Shows the copyright screen, then draws the framing
; bars, loads the logo tiles, and runs the shooting-star animation on the cinematic
; surface, then tears it down.
;
; DEVIATION{class=HAL; pret=engine/movie/intro.asm:PlayShootingStar; behavior=the GB LCD control (DisableLCD/EnableLCD + rLCDC window/BG-map bits, and the standalone ClearScreen before the bars which IntroDrawBlackBars already covers) is dropped in favour of the cinematic surface, and IO_LCDC is set only to select signed BG tile addressing; evidence=the port has no LCD and composites a matte surface with its own loop, so those hardware writes have no counterpart; lifetime=permanent flat-memory/HAL model}
; ---------------------------------------------------------------------------
global PlayShootingStar
PlayShootingStar:
    call MovieBeginSurface                ; PORT: black-matte cinematic surface
    mov byte [ebp + IO_LCDC], 0xE3        ; signed BG tile addressing (bit4=0) — © / bar / logo tiles in vChars2
    mov byte [ebp + H_SCX], 0             ; splash does not scroll — pin the surface origin
    mov byte [ebp + H_SCY], 0
    mov bh, 0x0C                          ; ld b, SET_PAL_GAME_FREAK_INTRO
    call RunPaletteCommand
    call LoadCopyrightAndTextBoxTiles     ; the ©1995-1999 Nintendo/Creatures/GAME FREAK screen
    mov al, 0x1B                          ; ldpal a, SHADE_BLACK,SHADE_DARK,SHADE_LIGHT,SHADE_WHITE
    mov [ebp + IO_BGP], al                ; ldh [rBGP], a  (inverted splash palette)
    call UpdateCGBPal_BGP
    mov bl, 180                           ; ld c, 180
    call DelayFrames                      ; show the copyright screen for ~3 seconds
    mov byte [ebp + wCurOpponent], 0      ; xor a / ld [wCurOpponent], a
    ; build the bar tiles: vChars2 tile 0 = $00 (color 0), tile 1 = $ff (color 3 = white)
    mov esi, GB_VCHARS2                    ; ld hl, vChars2
    mov bx, 0x10
    xor al, al
    call FillMemory                       ; tile 0 = $00
    mov esi, GB_VCHARS2 + 0x10            ; ld hl, vChars2 + $10
    mov bx, 0x10
    mov al, 0xFF
    call FillMemory                       ; tile 1 = $ff
    mov byte [g_tilecache_dirty], 1       ; VRAM tile data changed -> rebuild decode cache
    call IntroDrawBlackBars               ; white framing bars on GB rows 0-3 & 14-17
    mov esi, GB_VFONT                     ; logo -> vChars1 (OAM tiles $80..)
    mov edx, GameFreakIntro
    mov bl, GAMEFREAKINTRO_TILES
    call CopyVideoData
    mov bl, 64                            ; ld c, 64
    call DelayFrames
    call AnimateShootingStar              ; farcall in pret; direct here (CF = user skip)
    jc .next                              ; jr c, .next (skip the tail delay on interrupt)
    mov bl, 40                            ; ld c, 40
    call DelayFrames
.next:
    call IntroClearMiddleOfScreen
    call ClearSprites
    call MovieEndSurface                  ; PORT: tear down the surface
    call Delay3
    ret

; ---------------------------------------------------------------------------
; PlayIntro — the full boot cinematic: the Game Freak shooting-star splash, then the
; Yellow intro scenes. Called from Init before the title. (pret engine/movie/
; intro.asm:PlayIntro.) hAutoBGTransferEnabled is written faithfully but inert (the
; port's surface mirror replaces the GB VBlank auto-transfer; the byte is kept, as
; elsewhere in the port).
; ---------------------------------------------------------------------------
global PlayIntro
PlayIntro:
    mov byte [ebp + H_JOY_HELD], 0             ; xor a / ldh [hJoyHeld], a
    mov byte [ebp + hAutoBGTransferEnabled], 1 ; inc a / ldh [hAutoBGTransferEnabled], a
    call PlayShootingStar                       ; the Game Freak splash (B2)
    call PlayIntroScene                         ; callfar in pret — the Yellow intro scenes (B3)
    mov byte [ebp + H_SCX], 0                   ; xor a / ldh [hSCX], a
    mov byte [ebp + hAutoBGTransferEnabled], 0 ; ldh [hAutoBGTransferEnabled], a
    call ClearSprites
    call DelayFrame
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

; Shooting-star + Game Freak logo tile graphics (pret INCBINs). GameFreakIntro =
; gamefreak_presents (13t) + gamefreak_logo (6t) + blank (1t); FallingStar = 1 tile.
global GameFreakIntro
%include "assets/gamefreak_intro_2bpp.inc"   ; GameFreakIntro
global FallingStar
%include "assets/falling_star_2bpp.inc"      ; FallingStar

; Copyright-screen tile-index layout (pret title.asm:CopyrightTextString). Three
; lines of copyright-logo/font tile indices ($60-$7f); $4E = newline ("next"),
; $50 = end ("@"). Placed at surface coord (2,7) by LoadCopyrightAndTextBoxTiles.
global CopyrightTextString
CopyrightTextString:
    db 0x60,0x61,0x62,0x63,0x61,0x62,0x7c,0x7f,0x65,0x66,0x67,0x68,0x69,0x6a, 0x4E             ; ©1995-1999  Nintendo
    db 0x60,0x61,0x62,0x63,0x61,0x62,0x7c,0x7f,0x6b,0x6c,0x6d,0x6e,0x6f,0x70,0x71,0x72, 0x4E    ; ©1995-1999  Creatures inc.
    db 0x60,0x61,0x62,0x63,0x61,0x62,0x7c,0x7f,0x73,0x74,0x75,0x76,0x77,0x78,0x79,0x7a,0x7b, 0x50 ; ©1995-1999  GAME FREAK inc.

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
