; intro.asm — the boot cinematic (menu-intro B2/B4).
;
; Source: engine/movie/intro.asm. Holds pret intro.asm's boot-cinematic labels:
; PlayIntro (the Game Freak splash then the Yellow intro), PlayShootingStar (the
; splash orchestration), the IntroDrawBlackBars framing helpers, and the
; GameFreakIntro logo graphic. The shooting-star animation itself
; (AnimateShootingStar / LoadShootingStarGraphics / MoveDownSmallStars + the OAM
; tables) is pret engine/movie/splash.asm and lives in splash.asm; the copyright
; screen is pret engine/movie/title.asm and lives in title.asm.
;
; Build: nasm -f coff -I include/ -I . -o intro.o intro.asm

bits 32

%include "gb_memmap.inc"
%define UI_LAYOUT_EQUATES_ONLY 1
%include "assets/ui_layout_intro.inc"   ; UI_SPLASH_ROW / UI_SPLASH_COL

hAutoBGTransferEnabled equ H_AUTO_BG_TRANSFER_EN   ; pret name (inert byte; consumer do_bg_transfer retired)

; --- Cinematic BG surface model (the port's own; documented in intro_yellow.asm) --
; MovieMirrorSurface shows the visible 18x20 window from W_TILEMAP +
; UI_SPLASH_ROW*SCREEN_TILES_W + UI_SPLASH_COL (row 3, col 10). Row-range (full-width)
; fills add only the row part (INTRO_BG_ROW_OFF); a GB coord(col,row) is authored at
; (col+UI_SPLASH_COL, row+UI_SPLASH_ROW). Not a per-routine deviation.
INTRO_BG_ROW_OFF  equ UI_SPLASH_ROW * SCREEN_TILES_W       ; = 120

extern MovieBeginSurface             ; movie_projection.asm — black-matte cinematic surface
extern MovieEndSurface               ; movie_projection.asm — tear down the surface
extern RunPaletteCommand             ; home/palettes.asm — BH = SET_PAL_* command
extern UpdateCGBPal_BGP              ; home/cgb_palettes.asm — commit rBGP to the DAC
extern FillMemory                    ; home/copy2.asm — ESI dest, BX count, AL value
extern CopyVideoData                 ; home/copy2.asm — ESI=VRAM dest, EDX=flat src, BL=tiles
extern DelayFrames                   ; video/frame.asm — BL = frame count
extern DelayFrame                    ; video/frame.asm — wait one frame
extern Delay3                        ; src/home/palettes.asm — wait 3 frames
extern ClearSprites                  ; home/sprites.asm — zero shadow OAM + count
extern g_tilecache_dirty             ; ppu.asm — arm the tile-cache rebuild
extern AnimateShootingStar           ; engine/movie/splash.asm — the shooting-star animation
extern LoadCopyrightAndTextBoxTiles  ; engine/movie/title.asm — the boot copyright screen
extern PlayIntroScene                ; engine/movie/intro_yellow.asm — the Yellow intro scenes (B3)

section .text

; ---------------------------------------------------------------------------
; IntroDrawBlackBars — draw the splash's framing bars (bar tile $1 = the $ff tile,
; which is white under the splash palette) on GB rows 0-3 and 14-17, clearing the
; surface first. (+ IntroClearScreen / IntroClearMiddleOfScreen / IntroClearCommon /
; IntroPlaceBlackTiles.) BG writes use the cinematic origin (above); pret's vBGMap0
; and vBGMap1 bar writes both land on the single W_TILEMAP canvas (there is no second
; BG map) — the port's surface model, not a per-routine deviation.
; ---------------------------------------------------------------------------
global IntroDrawBlackBars
IntroDrawBlackBars:
    call IntroClearScreen
    mov esi, W_TILEMAP + INTRO_BG_ROW_OFF                 ; GB rows 0-3 -> surface rows 0-3
    mov ecx, 4 * SCREEN_TILES_W                            ; ld c, SCREEN_WIDTH * 4
    call IntroPlaceBlackTiles
    mov esi, W_TILEMAP + INTRO_BG_ROW_OFF + 14 * SCREEN_TILES_W  ; GB rows 14-17
    mov ecx, 4 * SCREEN_TILES_W
    call IntroPlaceBlackTiles
    mov esi, W_TILEMAP + INTRO_BG_ROW_OFF                 ; ld hl, vBGMap1  (-> same surface)
    mov ecx, 4 * SCREEN_TILES_W                            ; ld c, TILEMAP_WIDTH * 4
    call IntroPlaceBlackTiles
    mov esi, W_TILEMAP + INTRO_BG_ROW_OFF + 14 * SCREEN_TILES_W  ; hlbgcoord 0,14,vBGMap1
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
    mov esi, W_TILEMAP + INTRO_BG_ROW_OFF + 4 * SCREEN_TILES_W   ; hlcoord 0, 4
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
; PlayShootingStar — the Game Freak "shooting star" splash. Shows the copyright
; screen, then draws the framing bars, loads the logo tiles, and runs the
; shooting-star animation on the cinematic surface, then tears it down.
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
%ifdef DEBUG_TITLE_TIMEOUT
%define DUMP_RESET_REPLAY 1
%endif
%ifdef DEBUG_SOFT_RESET
%define DUMP_RESET_REPLAY 1
%endif
%ifdef DUMP_RESET_REPLAY
    ; title_timeout / soft_reset golden (menu-intro B4): if this PlayShootingStar is the
    ; REPLAY that a title-screen reset triggered (the flip: title timeout/combo -> jmp Init
    ; -> PlayIntro), the copyright is now drawn — dump it (== the gamefreak_intro state, but
    ; reached via the reset route) and exit. The initial boot's PlayShootingStar has the flag
    ; clear, so it plays through normally to reach the title where the reset happens.
    extern g_title_reset_replay           ; engine/movie/title.asm
    cmp byte [g_title_reset_replay], 0
    je .not_reset_replay
    extern DumpBackbuffer                 ; debug/debug_dump.asm
    call DelayFrame                       ; let the copyright render to the surface
    call DelayFrame
    call DumpBackbuffer                   ; GBSTATE.BIN + FRAME.BIN + exit (fires once)
.not_reset_replay:
%endif
    mov bl, 180                           ; ld c, 180
    call DelayFrames                      ; show the copyright screen for ~3 seconds
    mov byte [ebp + wCurOpponent], 0      ; xor a / ld [wCurOpponent], a
    call IntroDrawBlackBars               ; white framing bars on GB rows 0-3 & 14-17
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
    ; copy gamefreak logo and others — BOTH of pret's copies: vChars2 + $600
    ; (signed BG tiles $60..) first, then vChars1 (OBJ tiles $80..)
    mov esi, GB_VCHARS2 + 0x600           ; ld de, vChars2 + $600
    mov edx, GameFreakIntro
    mov bl, GAMEFREAKINTRO_TILES
    call CopyVideoData
    mov esi, GB_VFONT                     ; ld de, vChars1
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
; Yellow intro scenes. Called from Init before the title. hAutoBGTransferEnabled is
; written faithfully but inert (the port's surface mirror replaces the GB VBlank
; auto-transfer; the byte is kept, as elsewhere in the port).
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

section .data
align 4

; GameFreakIntro — the Game Freak logo tile graphics (pret intro.asm INCBIN;
; gamefreak_presents + gamefreak_logo + a blank tile). Loaded to vChars1 by
; PlayShootingStar. Flat program-image data.
global GameFreakIntro
%include "assets/gamefreak_intro_2bpp.inc"   ; GameFreakIntro + GAMEFREAKINTRO_TILES
