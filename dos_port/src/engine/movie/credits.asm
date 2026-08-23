; ===========================================================================
; credits.asm — the Hall of Fame PC entry point and the credits roll.
; Faithful mirror of pret engine/movie/credits.asm, all 20 of its labels.
;
; This is the game's ENDING, and it was entirely unported: HallOfFamePC was a
; ret-only stub in engine/movie/evolution_stubs.asm while scripts/HallOfFame.asm
; already called it. With engine/movie/hall_of_fame.asm ported (07828148b), the
; chain HallOfFame_Script -> HallOfFamePC -> AnimateHallOfFame -> Credits is real.
;
; ---------------------------------------------------------------------------
; SCREEN PROJECTION — this is an engine/movie/ screen, so it runs on the shared
; CINEMATIC SURFACE (engine/movie/movie_projection.asm), exactly as
; hall_of_fame.asm does: MovieBeginSurface publishes a 160x144 GB window centred
; at canvas tile (10,3), MovieMirrorSurface pushes the drawn rectangle into the
; stride-32 GB tilemap the compositor samples, MovieSyncScroll turns hSCX into the
; window's fine source offset, MovieEndSurface hands the screen back. That module's
; header carries the class=projection annotation covering every cinematic screen.
; A correct wTileMap is NOT a displayed screen — see the measured note in
; hall_of_fame.asm's header before doubting it.
;
; ---------------------------------------------------------------------------
; THE BG-MAP DOUBLE BUFFER IS THE ONE REAL MECHANISM DIFFERENCE, and it collapses.
; pret draws the next state into wTileMap, pushes it to vBGMap0 OR vBGMap1 with
; CreditsCopyTileMapToVRAM (which is just "arm hAutoBGTransferDest + enable the
; auto transfer + Delay3"), and flips which map the LCD reads by setting or
; clearing rLCDC bit 3. That is a page flip, used so a half-drawn mon parade is
; never on screen.
; DEVIATION{class=projection; pret=engine/movie/credits.asm:CreditsCopyTileMapToVRAM; behavior=publishes the drawn canvas through MovieMirrorSurface instead of arming an auto-BG transfer into a chosen vBGMap, so the vBGMap0 and vBGMap1 page flip collapses to a single surface and the rLCDC bit-3 writes select nothing; evidence=render_bg composites from wTileMap through tile_cache and never scans either GB BG map, and the port has no auto-BG-transfer engine for hAutoBGTransferDest to steer - home/vcopy.asm AutoBgMapTransfer is an unreached mirror with no caller; lifetime=permanent while render_bg is a surface compositor}
; The visible consequence is nil: the port composites a whole frame at a time from
; wTileMap, so there is no half-drawn intermediate for the flip to hide.
;
; NO GOLDEN SCENARIO REACHES THIS, and that is stated rather than glossed: the
; credits are behind the Hall of Fame, which is behind the Champion. DEBUG_CREDITS=1
; (RunCreditsTest at the end of this file) is the runtime evidence available.
;
; Register map (CLAUDE.md): A=AL, BC=BX (B=BH, C=BL), DE=EDX, HL=ESI, EBP = GB base.
;
; Build (standalone check):
;   nasm -f coff -I include/ -I . -D BUG_FIX_LEVEL=0 -o /dev/null \
;        src/engine/movie/credits.asm
; ===========================================================================
bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_macros.inc"
%include "assets/audio_constants.inc"       ; MUSIC_CREDITS + its bank

%define FW SCREEN_WIDTH                             ; 40 — wTileMap row stride
%define scoord(x,y) (wTileMap + ((y)+3)*FW + ((x)+10))
GB_ROW_TILES equ 20                                 ; pret SCREEN_WIDTH, as a COUNT

global HallOfFamePC
global FadeInCredits
global HoFGBPalettes
global DisplayCreditsMon
global ScrollCreditsMonLeft
global GetNextCreditsMon
global CreditsCopyTileMapToVRAM
global CreditsLoadFont
global ShiftFontColorIndex
global FillFourRowsWithBlack
global FillMiddleOfScreenWithWhite
global FillLeftHalfOfScreenWithWhite
global FillRightHalfOfScreenWithWhite
global FillHalfOfScreenWithWhite
global Credits
global ShowTheEndGFX
global PlaceCreditsText

extern AnimateHallOfFame            ; engine/movie/hall_of_fame.asm
extern ClearScreen                  ; home/copy2.asm
extern DelayFrame                   ; home/vblank.asm
extern DelayFrames                  ; home/delay.asm — BL = frame count
extern DisableLCD                   ; home/lcd.asm
extern EnableLCD                    ; home/lcd.asm
extern FillMemory                   ; home/copy2.asm — ESI=dest, BX=count, AL=value
extern PlayMusic                    ; home/audio.asm
extern StopAllMusic                 ; home/audio.asm
extern Delay3                       ; home/palettes.asm
extern UpdateCGBPal_BGP             ; home/cgb_palettes.asm
extern LoadFontTilePatterns         ; home/load_font.asm
extern LoadTextBoxTilePatterns      ; home/load_font.asm
extern LoadCopyrightTiles           ; engine/movie/title.asm
extern SaveScreenTilesToBuffer2     ; home/tilemap.asm
extern LoadScreenTilesFromBuffer2DisableBGTransfer ; home/tilemap.asm
extern GetMonHeader                 ; home/pokemon.asm
extern LoadFrontSpriteByMonIndex    ; home/pokemon.asm
extern CopyVideoData                ; home/copy2.asm — arms g_tilecache_dirty itself
extern PlaceString                  ; home/text.asm — EAX=flat src, ESI=dest
extern text_row_stride              ; home/text.asm — live wTileMap row stride
extern g_tilecache_dirty            ; ppu/ppu.asm — arm after a raw vChars write
extern MovieBeginSurface            ; engine/movie/movie_projection.asm
extern MovieEndSurface
extern MovieMirrorSurface
extern MovieSyncScroll

section .data
align 4
; Tier-1 DATA: CreditsOrder, CreditsMons, CreditsTextPointers, the 86 name
; strings, TheEndTextString (tools/generators/gen_credits_data.py) and the
; "THE END" tiles (gen_title_gfx_inc.py).
%include "assets/credits_data.inc"
%include "assets/the_end_2bpp.inc"

; HoFGBPalettes — pret's four-step BGP fade-in, written with the `dc` "crumbs"
; macro (macros/data.asm): dc a,b,c,d = (a<<6)|(b<<4)|(c<<2)|d. So the FIRST
; argument is BGP's colour 3 and the SECOND is colour 2:
;   dc 3,0,0,0 = $C0   dc 3,1,0,0 = $D0   dc 3,2,0,0 = $E0   dc 3,3,0,0 = $F0
;
; THE FADE RAISES COLOUR 2, and that is the whole point of ShiftFontColorIndex.
; That routine zeroes the LOW bitplane of every font tile, so a glyph pixel goes
; from colour 3 (both planes set) to colour 2 (high only) — measured in the
; DEBUG_CREDITS dump: the 'D' tile at $8830 comes back 00 f8 00 84 ... , low planes
; all zero. Colour 3 stays black for the bars, colour 2 walks 0 -> 3 and the text
; fades in under it.
;
; This table read $C0,$C4,$C8,$CC when first written — the packing misread as
; raising colour 1 — and the credits text was invisible at every frame sampled
; because colour 2 stayed at shade 0. The tilemap was correct throughout; only
; rendering FRAME.BIN and then reading the tile planes out of the dump found it.
align 4
HoFGBPalettes:
    db 0xC0, 0xD0, 0xE0, 0xF0       ; dc 3,0,0,0 / 3,1,0,0 / 3,2,0,0 / 3,3,0,0

section .text

; ---------------------------------------------------------------------------
; HallOfFamePC — pret engine/movie/credits.asm:1. The ceremony, then the roll.
; Reached from scripts/HallOfFame.asm through the HallOfFamePC predef.
; ---------------------------------------------------------------------------
HallOfFamePC:
    call AnimateHallOfFame              ; callfar
    call ClearScreen
    mov bl, 100                         ; ld c, 100
    call DelayFrames

    call DisableLCD
    mov byte [ebp + IO_WX], 0xA7
    mov byte [ebp + IO_SCX], 0
    mov byte [ebp + IO_SCY], 0
    mov byte [ebp + hSCX], 0
    mov byte [ebp + hSCY], 0
    mov byte [ebp + hWY], 0
    mov byte [ebp + IO_WY], 0
    call CreditsLoadFont
    mov dword [text_row_stride], FW     ; PORT: canvas stride for the fills below
    call MovieBeginSurface              ; PORT: take the screen (see the header)
    mov esi, scoord(0, 0)               ; hlcoord 0, 0
    call FillFourRowsWithBlack
    mov esi, scoord(0, 14)              ; hlcoord 0, 14
    call FillFourRowsWithBlack
    mov byte [ebp + IO_BGP], 0xC0       ; ld a, %11000000 / ldh [rBGP], a
    call UpdateCGBPal_BGP
    call EnableLCD
    call StopAllMusic
    ; pret pushes the tilemap to vBGMap1 and then vBGMap0 — the page flip this
    ; port collapses (see the DEVIATION in the header). One publish is both.
    call CreditsCopyTileMapToVRAM
    call CreditsCopyTileMapToVRAM
    mov bl, MUSIC_CREDITS_BANK          ; ld c, BANK(Music_Credits)
    mov al, MUSIC_CREDITS
    call PlayMusic
    mov bl, 128                         ; ld c, 128
    call DelayFrames
    xor al, al
    mov [ebp + wHoFMonSpecies], al
    mov [ebp + wNumCreditsMonsDisplayed], al
    jmp Credits                         ; jp Credits

; ---------------------------------------------------------------------------
; FadeInCredits — pret :41. Walk BGP through HoFGBPalettes, 5 frames a step.
; ---------------------------------------------------------------------------
FadeInCredits:
    mov byte [ebp + hAutoBGTransferEnabled], 1
    mov esi, HoFGBPalettes              ; flat table
    mov bh, 4                           ; ld b, 4
.loop:
    mov al, [esi]                       ; ld a, [hli]
    inc esi
    mov [ebp + IO_BGP], al
    call UpdateCGBPal_BGP
    push esi
    mov bl, 5                           ; ld c, 5
    call DelayFrames
    pop esi
    dec bh                              ; dec b — 8-bit, as pret
    jnz .loop
    ret

; ---------------------------------------------------------------------------
; DisplayCreditsMon — pret :64. Swap in the next parade mon behind a white wipe,
; scroll it left across the screen, and wipe it out again.
; ---------------------------------------------------------------------------
DisplayCreditsMon:
    call CreditsCopyTileMapToVRAM       ; pret: to vBGMap1
    mov byte [ebp + hAutoBGTransferEnabled], 0
    or byte [ebp + IO_LCDC], LCDC_BG_MAP    ; set B_LCDC_BG_MAP, [hl] — inert here
    call SaveScreenTilesToBuffer2
    call FillMiddleOfScreenWithWhite
    call GetNextCreditsMon
    call CreditsCopyTileMapToVRAM       ; pret: to vBGMap0 + 12
    mov byte [ebp + hAutoBGTransferEnabled], 0
    call LoadScreenTilesFromBuffer2DisableBGTransfer
    call CreditsCopyTileMapToVRAM       ; pret: to vBGMap0
    mov byte [ebp + IO_BGP], 0xFC       ; make the mon a black silhouette
    call UpdateCGBPal_BGP
    and byte [ebp + IO_LCDC], ~LCDC_BG_MAP & 0xFF   ; res B_LCDC_BG_MAP, [hl]
    mov byte [ebp + hAutoBGTransferEnabled], 1
    mov bh, 0                           ; ld b, 0 — the running hSCX value
    mov bl, 10                          ; ld c, 10
    call ScrollCreditsMonLeft
    call FillLeftHalfOfScreenWithWhite
    mov bl, 10
    call ScrollCreditsMonLeft
    call FillRightHalfOfScreenWithWhite
    mov bl, 8
    call ScrollCreditsMonLeft
    mov byte [ebp + IO_BGP], 0xC0
    call UpdateCGBPal_BGP
    mov byte [ebp + hSCX], 0
    call MovieSyncScroll                ; PORT: hSCX back to 0 on the window too
    ret

; ---------------------------------------------------------------------------
; ScrollCreditsMonLeft — pret :101. BH = current hSCX, BL = steps; +8 per frame.
; ---------------------------------------------------------------------------
ScrollCreditsMonLeft:
    mov al, bh                          ; ld a, b
    mov [ebp + hSCX], al
    add al, 8
    mov bh, al                          ; ld b, a — 8-bit, so it wraps as pret's does
    call MovieMirrorSurface             ; PORT: publish, then move the window
    call MovieSyncScroll                ; PORT: hSCX -> the window source offset
    call DelayFrame
    dec bl                              ; dec c — 8-bit, as pret
    jnz ScrollCreditsMonLeft
    ret

; ---------------------------------------------------------------------------
; GetNextCreditsMon — pret :111. Take the next species from CreditsMons and put
; its front pic on screen.
; ---------------------------------------------------------------------------
GetNextCreditsMon:
    movzx ebx, byte [ebp + wNumCreditsMonsDisplayed]    ; ld c, [hl]
    inc byte [ebp + wNumCreditsMonsDisplayed]           ; inc [hl]
    mov al, [CreditsMons + ebx]         ; flat Tier-1 table
    mov [ebp + wCurPartySpecies], al
    mov [ebp + wCurSpecies], al
    mov esi, scoord(8, 6)               ; hlcoord 8, 6
    call GetMonHeader
    call LoadFrontSpriteByMonIndex
    ret

; ---------------------------------------------------------------------------
; CreditsCopyTileMapToVRAM — pret :128. See the DEVIATION in the file header:
; pret arms hAutoBGTransferDest at the caller's chosen vBGMap and lets the VBlank
; transfer push wTileMap there; the port publishes the one surface instead. The
; ESI the caller set for pret's destination is deliberately ignored.
; ---------------------------------------------------------------------------
CreditsCopyTileMapToVRAM:
    call MovieMirrorSurface
    mov byte [ebp + hAutoBGTransferEnabled], 1
    jmp Delay3                          ; jp Delay3

; ---------------------------------------------------------------------------
; CreditsLoadFont — pret :136. Load the font and box tiles, then shift their
; colour index so the roll can fade text in with the palette alone.
; ---------------------------------------------------------------------------
CreditsLoadFont:
    call LoadFontTilePatterns
    mov esi, GB_VFONT                   ; ld hl, vFont
    mov bx, (0x80 * TILE_SIZE) / 2      ; ld bc, ($80 tiles) / 2
    call ShiftFontColorIndex

    call LoadTextBoxTilePatterns
    mov esi, GB_VCHARS2 + 0x60 * TILE_SIZE  ; ld hl, vChars2 tile $60
    mov bx, (0x20 * TILE_SIZE) / 2      ; ld bc, ($20 tiles) / 2
    call ShiftFontColorIndex

    mov esi, GB_VCHARS2 + 0x7E * TILE_SIZE  ; ld hl, vChars2 tile $7e
    mov bx, TILE_SIZE
    mov al, 0xFF                        ; solid black
    call FillMemory
    mov byte [g_tilecache_dirty], 1     ; PORT: a raw vChars write must invalidate
    ret

; ---------------------------------------------------------------------------
; ShiftFontColorIndex — pret :151. "Zero every second byte at hl, writing a total
; of bc bytes." On font tiles holding only black and white it shifts the colour
; index black -> light grey, which is what lets the palette fade the text in while
; the black bars stay solid.
;
; In: ESI = GB VRAM offset, BX = byte count. VRAM TILE DATA, so the decode cache
; is armed — pret has no counterpart, it is this port's standing obligation.
;
; COUNTER IS PRET'S 16-BIT `dec bc` + `ld a,b / or c`, so a count of 0 walks the
; whole 64 KB before stopping, exactly as on the GB. Every caller passes a literal.
; ---------------------------------------------------------------------------
ShiftFontColorIndex:
    mov byte [g_tilecache_dirty], 1     ; PORT: raw vChars write -> rebuild the cache.
                                        ; Inside the loop because pret's `jr nz` targets
                                        ; the ROUTINE label, and matching that shape is
                                        ; worth more than saving 1023 redundant stores.
    mov byte [ebp + esi], 0             ; ld [hl], 0
    inc esi
    inc esi                             ; inc hl / inc hl — skip the odd byte
    dec bx                              ; dec bc
    jnz ShiftFontColorIndex             ; ld a,b / or c / jr nz, ShiftFontColorIndex
    ret

; ---------------------------------------------------------------------------
; FillFourRowsWithBlack — pret :164. Four rows of the solid-black tile ($7E).
;
; THE COUNT IS RE-EXPRESSED, THE STRIDE IS NOT. pret writes `ld bc, SCREEN_WIDTH*4`
; and fills 80 CONTIGUOUS bytes, because its rows are 20 wide and adjacent. On the
; port's 40-wide canvas the same four GB rows are four runs of 20 with a 40-byte
; step, so this is a row loop. That is the SCREEN_WIDTH role split: as a row STRIDE
; it is each side's own value, as a COUNT it must be re-derived.
; DEVIATION{class=projection; pret=engine/movie/credits.asm:FillFourRowsWithBlack; behavior=fills four rows of 20 tiles with a per-row loop through the port-only FillRowsCommon instead of pret's single contiguous FillMemory of SCREEN_WIDTH*4 bytes; evidence=pret's rows are 20 tiles wide and adjacent in its 20x18 tilemap so the region is contiguous there, while the port's canvas is 40 wide (SCREEN_WIDTH in gb_memmap.inc) and the same four GB rows are four separate runs - a contiguous fill of 80 bytes would paint two GB rows and half the canvas gutter; lifetime=permanent while the port renders a wider viewport than the GB}
; In: ESI = top-left. Out: registers preserved.
; ---------------------------------------------------------------------------
FillFourRowsWithBlack:
    mov al, 0x7E
    mov bh, 4
    jmp FillRowsCommon

; ---------------------------------------------------------------------------
; FillMiddleOfScreenWithWhite — pret :168. "Clear the area of the tile map between
; the black bars on the top and bottom": ten rows from GB row 4.
; DEVIATION{class=projection; pret=engine/movie/credits.asm:FillMiddleOfScreenWithWhite; behavior=fills ten rows of 20 tiles with a per-row loop through the port-only FillRowsCommon instead of pret's single contiguous FillMemory of SCREEN_WIDTH*10 bytes; evidence=same canvas-width reason as FillFourRowsWithBlack above - the ten GB rows are contiguous in pret's 20-wide tilemap and are ten separate runs in the port's 40-wide canvas; lifetime=permanent while the port renders a wider viewport than the GB}
; ---------------------------------------------------------------------------
FillMiddleOfScreenWithWhite:
    mov esi, scoord(0, 4)               ; hlcoord 0, 4
    mov al, 0x7F                        ; ' '
    mov bh, 10
    ; fall through

; FillRowsCommon — port-only: BH rows of GB_ROW_TILES tiles of AL at ESI, stepping
; FW per row. It exists because pret's contiguous fills cannot be contiguous here.
FillRowsCommon:
    push esi
    push ebx
    push ecx
    push edi
.row:
    lea edi, [ebp + esi]
    mov ecx, GB_ROW_TILES
    rep stosb
    add esi, FW
    dec bh
    jnz .row
    pop edi
    pop ecx
    pop ebx
    pop esi
    ret

; ---------------------------------------------------------------------------
; FillLeftHalfOfScreenWithWhite / FillRightHalfOfScreenWithWhite — pret :173/:179.
; Ten rows of ten tiles, from GB (0,4) and (10,4).
; ---------------------------------------------------------------------------
FillLeftHalfOfScreenWithWhite:
    mov esi, scoord(0, 4)               ; hlcoord 0, 4
    push ebx                            ; push bc
    call FillHalfOfScreenWithWhite
    pop ebx                             ; pop bc
    ret

FillRightHalfOfScreenWithWhite:
    mov esi, scoord(10, 4)              ; hlcoord 10, 4
    push ebx
    call FillHalfOfScreenWithWhite
    pop ebx
    ret

; ---------------------------------------------------------------------------
; FillHalfOfScreenWithWhite — pret :185. 10 rows x 10 tiles at ESI. pret already
; writes this as a row loop with a SCREEN_WIDTH row step, so only the step value
; differs between the two sides — the shape is unchanged.
; ---------------------------------------------------------------------------
FillHalfOfScreenWithWhite:
    push esi
    push ebx
    push ecx
    push edi
    mov bh, 10                          ; ld b, 10
    mov bl, 10                          ; ld c, 10
    mov al, 0x7F                        ; ' '
.loop:
    lea edi, [ebp + esi]
    movzx ecx, bl
    rep stosb
    add esi, FW                         ; ld bc, SCREEN_WIDTH / add hl, bc
    dec bh
    jnz .loop
    pop edi
    pop ecx
    pop ebx
    pop esi
    ret

; ---------------------------------------------------------------------------
; Credits — pret :213. Roll the credits: walk CreditsOrder, placing name strings
; until a CRED_TEXT* command ends the screen, then hold (and optionally fade or
; show a parade mon) before the next one.
; ---------------------------------------------------------------------------
Credits:
    mov edx, CreditsOrder               ; ld de, CreditsOrder (flat)
    push edx
.nextCreditsScreen:
    pop edx
    mov esi, scoord(9, 6)               ; hlcoord 9, 6
    push esi
    call FillMiddleOfScreenWithWhite
    pop esi
.nextCreditsCommand:
    mov al, [edx]                       ; ld a, [de] — flat command stream
    inc edx
    push edx
    cmp al, CRED_TEXT_FADE_MON
    je .fadeInTextAndShowMon
    cmp al, CRED_TEXT_MON
    je .showTextAndShowMon
    cmp al, CRED_TEXT_FADE
    je .fadeInText
    cmp al, CRED_TEXT
    je .showText
    cmp al, CRED_COPYRIGHT
    je .showCopyrightText
    cmp al, CRED_THE_END
    je .showTheEnd
    call PlaceCreditsText
    pop edx
    jmp .nextCreditsCommand

.showCopyrightText:
    call LoadCopyrightTiles             ; farcall
    pop edx
    jmp .nextCreditsCommand

.fadeInTextAndShowMon:
    call FadeInCredits
    mov bl, 102
    jmp .next1
.showTextAndShowMon:
    mov bl, 122
.next1:
    call MovieMirrorSurface             ; PORT: publish the finished screen
    call DelayFrames
    call DisplayCreditsMon
    jmp .nextCreditsScreen

.fadeInText:
    call FadeInCredits
    mov bl, 132
    jmp .next2
.showText:
    mov bl, 152
.next2:
    call MovieMirrorSurface             ; PORT: publish the finished screen
    call DelayFrames
    jmp .nextCreditsScreen

.showTheEnd:
    call ShowTheEndGFX
    pop edx
    ret

; ---------------------------------------------------------------------------
; ShowTheEndGFX — pret :271. The two-row "THE END" logo, faded in.
; ---------------------------------------------------------------------------
ShowTheEndGFX:
    mov bl, 24
    call DelayFrames
    call FillMiddleOfScreenWithWhite
    ; pret: ld de, TheEndGfx / ld hl, vChars2 tile $60 /
    ;       lb bc, BANK(TheEndGfx), (TheEndGfxEnd - TheEndGfx) / TILE_SIZE
    mov edx, TheEndGfx
    mov esi, GB_VCHARS2 + 0x60 * TILE_SIZE
    mov bh, 0                           ; bank — flat: ignored
    mov bl, (TheEndGfxEnd - TheEndGfx) / TILE_SIZE
    call CopyVideoData                  ; arms g_tilecache_dirty itself
    mov esi, scoord(4, 8)               ; hlcoord 4, 8
    mov eax, TheEndTextString
    call PlaceString
    mov esi, scoord(4, 9)               ; hlcoord 4, 9
    ; pret does `inc de` — PlaceString left DE on the first row's '@', so this
    ; steps to the second row. The port's PlaceString takes its source in EAX and
    ; leaves the terminator's address in EDX, so the same step is EDX+1.
    lea eax, [edx + 1]
    call PlaceString
    call MovieMirrorSurface             ; PORT: publish before the fade
    jmp FadeInCredits                   ; jp FadeInCredits

; ---------------------------------------------------------------------------
; PlaceCreditsText — pret :294. Place credits string AL at ESI, then step ESI down
; two rows for the next line.
;
; THE FIRST BYTE OF EACH STRING IS A SIGNED X-OFFSET, not text: pret loads it into
; c, sets b = -1 and does `add hl, bc`, i.e. HL += sign_extend16(0xFF00 | offset).
; Every offset in the table is $F8..$FB, so that is a small left shift that centres
; the name. Reproduced as the same 16-bit expression rather than a byte sign-extend,
; so a hypothetical positive offset byte would land where pret puts it.
; ---------------------------------------------------------------------------
PlaceCreditsText:
    push esi
    push esi
    movzx ebx, al                       ; ld c, a / ld b, 0 (index)
    mov edx, [CreditsTextPointers + ebx * 4]    ; dd table here, dw in pret
    pop esi
    mov al, [edx]                       ; ld a, [de] — the x-offset byte
    inc edx
    mov cx, 0xFF00                      ; ld b, -1
    mov cl, al                          ; ld c, a
    movsx ecx, cx
    add esi, ecx                        ; add hl, bc
    mov eax, edx                        ; PlaceString takes the source in EAX
    call PlaceString
    pop esi
    add esi, FW * 2                     ; ld bc, SCREEN_WIDTH * 2 / add hl, bc
    ret

%ifdef DEBUG_CREDITS
; ---------------------------------------------------------------------------
; RunCreditsTest — the only runtime evidence this file has: no golden scenario
; reaches the credits (they are behind the Hall of Fame, behind the Champion).
; Runs the real Credits roll, skipping the ceremony HallOfFamePC would play first.
;
;   dos_port/tools/run_headless.sh "DEBUG_CREDITS=1 AUTOKEY_DUMP_FRAME=<n>" /tmp/cr
;
; In: EBP = GB base. Called from EnterMap once the overworld is set up.
; ---------------------------------------------------------------------------
global RunCreditsTest
RunCreditsTest:
    or byte [ebp + wFontLoaded], (1 << BIT_FONT_LOADED)
    call ClearScreen
    call CreditsLoadFont
    mov dword [text_row_stride], FW
    call MovieBeginSurface
    mov esi, scoord(0, 0)
    call FillFourRowsWithBlack
    mov esi, scoord(0, 14)
    call FillFourRowsWithBlack
    mov byte [ebp + IO_BGP], 0xC0
    call UpdateCGBPal_BGP
    call CreditsCopyTileMapToVRAM
    xor al, al
    mov [ebp + wHoFMonSpecies], al
    mov [ebp + wNumCreditsMonsDisplayed], al
    call Credits
.hang:
    call DelayFrame
    jmp .hang
%endif
