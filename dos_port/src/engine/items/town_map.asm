; town_map.asm — faithful port of engine/items/town_map.asm (pret).
;
; The TOWN MAP viewer (DisplayTownMap), the Fly destination selector
; (LoadTownMap_Fly), and the Pokedex "MON's NEST" area screen (LoadTownMap_Nest),
; plus their shared helpers (LoadTownMap RLE decoder, LoadTownMapEntry, the OAM
; writers, cursor blinking). Translated 1:1 from the SM83 source.
;
; DANGLING: not wired into the main loop or the linked build. Assembles AND links
; cleanly (no unresolved symbols). Dependencies with no implementation in the tree
; (palette engine, CopyVideoData*, ClearScreenArea, JoypadLowSensitivity,
; FindWildLocationsOfMon, BirdSprite) have their `extern` + call sites commented out
; and marked `; TODO(unimplemented):` — restore them when those routines are ported.
; Town-map WRAM the port hasn't allocated is given PLACEHOLDER equ offsets (TODO:
; allocate in gb_memmap.inc). The routine never executes, so the placeholders are
; harmless until it's wired in.
;
; -- CENTERING (port adaptation, per project note) --------------------------
; The GB town map is a 20x18 screen; the port's canvas is a 40x25 tile buffer
; (W_TILEMAP, read at stride SCREEN_TILES_W by the non-overworld renderer). So
; the whole screen is drawn CENTERED: tilemap coords are offset by
; TOWNMAP_COL_OFFSET(10) cols / TOWNMAP_ROW_OFFSET(3) rows, the text engine's
; row stride is set to 40 (text_row_stride), the RLE decoder wraps at width 20,
; and OAM pixel coords are shifted by the same amount (col*8 / row*8). Exact
; pixel origin should be re-verified once the screen is wired into the renderer.
;
; Build: nasm -f coff -I include/ -I . -o /dev/null src/engine/items/town_map.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

section .text

global DisplayTownMap
global LoadTownMap_Fly
global LoadTownMap_Nest
global TownMapSpriteBlinkingAnimation

; ---- ported helpers -------------------------------------------------------
extern PlaceString, TextBoxBorder, CopyData, FarCopyData
extern ClearScreen, ClearSprites, UpdateSprites
extern DisableLCD, EnableLCD, Delay3, DelayFrame, DelayFrames
extern GetMonName, WaitForTextScrollButtonPress, PlaySound
extern GBPalNormal, LoadPlayerSpriteGraphics, LoadFontTilePatterns
extern text_row_stride          ; global dd in text.asm; default 20

; ---- NOT YET PORTED — no implementation in the tree; would halt a link. -----
; TODO: port these, then restore the `extern` + the call/reference sites below
; (each is marked `; TODO(unimplemented):`). Left commented out so this dangling
; file assembles AND links cleanly.
; extern BirdSprite                    ; gfx/sprites/bird.2bpp — not generated
; extern GBPalWhiteOut, GBPalWhiteOutWithDelay3   ; home/palettes.asm
; extern RunPaletteCommand, RunDefaultPaletteCommand
; extern ClearScreenArea               ; home/copy2.asm
; extern FarCopyDataDouble, CopyVideoData, CopyVideoDataDouble
extern JoypadLowSensitivity            ; src/input/joypad_lowsens.asm (home/joypad2.asm)
; extern FindWildLocationsOfMon        ; engine/items/item_effects.asm (farcall)

; ---- town-map WRAM the port hasn't allocated yet ---------------------------
; TODO: allocate these in gb_memmap.inc (with non-colliding addresses) and drop
; this block. These are PLACEHOLDER offsets so the file links; the base almost
; certainly overlaps real WRAM, but the routine is dangling (never executes) so
; it is harmless until real allocation.
TOWNMAP_WRAM_PLACEHOLDER      equ 0xDE00   ; TODO: not a real allocation
wShadowOAMBackup              equ TOWNMAP_WRAM_PLACEHOLDER + 0x00  ; 160 bytes
wWhichTownMapLocation         equ TOWNMAP_WRAM_PLACEHOLDER + 0xA0
wOAMBaseTile                  equ TOWNMAP_WRAM_PLACEHOLDER + 0xA1
wAnimCounter                  equ TOWNMAP_WRAM_PLACEHOLDER + 0xA2
wTownMapSpriteBlinkingEnabled equ TOWNMAP_WRAM_PLACEHOLDER + 0xA3
wSymmetricSpriteOAMAttributes equ TOWNMAP_WRAM_PLACEHOLDER + 0xA4
; wDestinationMap now provided real by gb_memmap.inc (0xD719, menus S7); the old
; TOWNMAP_WRAM_PLACEHOLDER + 0xA5 line was dropped (inconsistent equ redefinition).
wTownVisitedFlag              equ TOWNMAP_WRAM_PLACEHOLDER + 0xA6  ; 2 bytes
wTownMapCoords                equ TOWNMAP_WRAM_PLACEHOLDER + 0xA8  ; scratch buffer
wFlyAnimUsingCoordList        equ TOWNMAP_WRAM_PLACEHOLDER + 0xC0
wFlyLocationsList             equ TOWNMAP_WRAM_PLACEHOLDER + 0xC1  ; NUM_CITY_MAPS+2

; --------------------------------------------------------------------------- #
; constants (TODO: migrate the missing ones to gb_constants.inc)
; --------------------------------------------------------------------------- #
NOT_VISITED        equ 0xFE
BIRD_BASE_TILE     equ 0x04
NUM_CITY_MAPS      equ 11         ; constants/map_constants.asm
SET_PAL_TOWN_MAP   equ 0x02       ; constants/palette_constants.asm
OBJ_SIZE           equ 4          ; bytes per OAM object
SCREEN_HEIGHT_PX   equ 144
B_PAD_A            equ 0
B_PAD_UP           equ 6
B_PAD_DOWN         equ 7
BIT_FLY_WARP       equ 3          ; constants/ram_constants.asm (wStatusFlags6)
BIT_USED_FLY       equ 7          ; constants/ram_constants.asm (wStatusFlags7)
; TODO-HW(audio): real SFX ids from constants/music_constants.asm (PlaySound is a stub)
SFX_TINK           equ 0x00
SFX_HEAL_AILMENT   equ 0x00
; HRAM joypad (port layout: FFB3 pressed, FFB4 held, FFB5 hJoy5, FFB6, FFB7 hJoy7)
; %ifndef-guarded so these coexist once root promotes H_JOY5/6/7 into
; gb_memmap.inc (shared with src/input/joypad_lowsens.asm).
%ifndef H_JOY5
H_JOY5             equ 0xFFB5
%endif
%ifndef H_JOY6
H_JOY6             equ 0xFFB6
%endif
%ifndef H_JOY7
H_JOY7             equ 0xFFB7
%endif

; centering of the 20x18 GB screen inside the 40x25 W_TILEMAP
TOWNMAP_COL_OFFSET equ 10
TOWNMAP_ROW_OFFSET equ 3
TOWNMAP_WIDTH      equ 20
TOWNMAP_X_PX       equ TOWNMAP_COL_OFFSET * 8      ; 80
TOWNMAP_Y_PX       equ TOWNMAP_ROW_OFFSET * 8      ; 24

; hlcoord/decoord: centered tile offset into the 40-wide W_TILEMAP (EBP-relative)
%define TM_COORD(x,y) (W_TILEMAP + ((y) + TOWNMAP_ROW_OFFSET) * SCREEN_TILES_W + ((x) + TOWNMAP_COL_OFFSET))

; VRAM tile-data destinations (TILE_SIZE = 16 bytes/tile)
%define vSpritesTile(n)  (GB_VCHARS0 + (n) * TILE_SIZE)
%define vChars1Tile(n)   (GB_VFONT   + (n) * TILE_SIZE)
%define vChars2Tile(n)   (GB_VCHARS2 + (n) * TILE_SIZE)
TILE_1BPP               equ 8      ; TILE_1BPP_SIZE

; named shadow-OAM slots (W_SHADOW_OAM = wShadowOAM)
%define wShadowOAM                 W_SHADOW_OAM
%define wShadowOAMSprite00         (W_SHADOW_OAM + 0  * OBJ_SIZE)
%define wShadowOAMSprite04         (W_SHADOW_OAM + 4  * OBJ_SIZE)
%define wShadowOAMSprite32         (W_SHADOW_OAM + 32 * OBJ_SIZE)
%define wShadowOAMSprite36         (W_SHADOW_OAM + 36 * OBJ_SIZE)
%define wShadowOAMSprite00YCoord   (W_SHADOW_OAM)
; backup-OAM named slots (wShadowOAMBackup is extern; offsets via addend)
%define wShadowOAMBackupSprite00   wShadowOAMBackup
%define wShadowOAMBackupSprite04   (wShadowOAMBackup + 4 * OBJ_SIZE)

; --------------------------------------------------------------------------- #
; DisplayTownMap — the "look at TOWN MAP" viewer.
; --------------------------------------------------------------------------- #
DisplayTownMap:
    call LoadTownMap
    mov esi, W_UPDATE_SPRITES_ENABLED   ; ld hl, wUpdateSpritesEnabled
    mov al, [ebp + esi]
    push eax                            ; push af (old value)
    mov byte [ebp + esi], 0xFF
    push esi                            ; push hl
    mov al, 1
    mov [ebp + H_JOY7], al              ; ldh [hJoy7], a
    mov al, [ebp + W_CUR_MAP]
    push eax                            ; push af (wCurMap)
    mov bh, 0                           ; ld b, 0
    call DrawPlayerOrBirdSprite
    mov esi, TM_COORD(1, 0)             ; hlcoord 1, 0
    lea eax, [ebp + wNameBuffer]        ; ld de, wNameBuffer (flat src for PlaceString)
    call PlaceString
    mov esi, wShadowOAMSprite00         ; ld hl, wShadowOAMSprite00
    mov edx, wShadowOAMBackupSprite00   ; ld de, wShadowOAMBackupSprite00
    mov bx, OBJ_SIZE * 4                ; ld bc, OBJ_SIZE * 4
    call CopyData
    mov esi, vSpritesTile(BIRD_BASE_TILE)  ; ld hl, vSprites tile BIRD_BASE_TILE
    lea edx, [TownMapCursor]            ; ld de, TownMapCursor
    mov bh, 0                           ; BANK(TownMapCursor)
    mov bl, (TownMapCursorEnd - TownMapCursor) / TILE_1BPP
    ; TODO(unimplemented): call CopyVideoDataDouble
    xor al, al
    mov [ebp + wWhichTownMapLocation], al
    pop eax                             ; pop af -> al = wCurMap
    jmp .enterLoop

.townMapLoop:
    mov esi, TM_COORD(0, 0)             ; hlcoord 0, 0
    mov bh, 1                           ; lb bc, 1, 20 (height 1)
    mov bl, 20                          ; (width 20)
    ; TODO(unimplemented): call ClearScreenArea
    lea esi, [TownMapOrder]
    movzx ecx, byte [ebp + wWhichTownMapLocation]
    add esi, ecx                        ; add hl, bc
    mov al, [esi]                       ; ld a, [hl]
.enterLoop:
    mov edx, wTownMapCoords             ; ld de, wTownMapCoords
    call LoadTownMapEntry
    mov al, [ebp + edx]                 ; ld a, [de]
    push esi                            ; push hl (name ptr)
    call TownMapCoordsToOAMCoords
    mov al, 4
    mov [ebp + wOAMBaseTile], al        ; ld [wOAMBaseTile], a
    mov esi, wShadowOAMSprite04         ; ld hl, wShadowOAMSprite04
    call WriteTownMapSpriteOAM          ; town map cursor sprite
    pop esi                             ; pop hl (name ptr)
    mov edx, wNameBuffer                ; ld de, wNameBuffer
.copyMapName:
    mov al, [esi]                       ; ld a, [hli]
    inc esi
    mov [ebp + edx], al                 ; ld [de], a
    inc edx
    cmp al, 0x50                        ; charmap "@" terminator
    jne .copyMapName
    mov esi, TM_COORD(1, 0)             ; hlcoord 1, 0
    lea eax, [ebp + wNameBuffer]        ; ld de, wNameBuffer
    call PlaceString
    mov esi, wShadowOAMSprite04         ; ld hl, wShadowOAMSprite04
    mov edx, wShadowOAMBackupSprite04   ; ld de, wShadowOAMBackupSprite04
    mov bx, OBJ_SIZE * 4
    call CopyData
.inputLoop:
    call TownMapSpriteBlinkingAnimation
    call JoypadLowSensitivity          ; call JoypadLowSensitivity
    mov al, [ebp + H_JOY5]              ; ldh a, [hJoy5]
    mov bh, al                          ; ld b, a
    and al, PAD_A | PAD_B | PAD_UP | PAD_DOWN
    jz .inputLoop
    mov al, SFX_TINK
    call PlaySound
    bt ebx, B_PAD_UP + 8               ; bit B_PAD_UP, b (b is in BH -> bit 6 of BH = bit 14 of EBX)
    jc .pressedUp
    bt ebx, B_PAD_DOWN + 8             ; bit B_PAD_DOWN, b
    jc .pressedDown
    xor al, al
    mov [ebp + wTownMapSpriteBlinkingEnabled], al
    mov [ebp + H_JOY7], al             ; ldh [hJoy7], a
    mov [ebp + wAnimCounter], al
    call ExitTownMap
    pop esi                            ; pop hl (wUpdateSpritesEnabled)
    pop eax                            ; pop af (old value)
    mov [ebp + esi], al                ; ld [hl], a
    ret
.pressedUp:
    mov al, [ebp + wWhichTownMapLocation]
    inc al
    cmp al, TownMapOrderEnd - TownMapOrder      ; number of list items + 1
    jne .noOverflow
    xor al, al
.noOverflow:
    mov [ebp + wWhichTownMapLocation], al
    jmp .townMapLoop
.pressedDown:
    mov al, [ebp + wWhichTownMapLocation]
    dec al
    cmp al, 0xFF                        ; cp -1
    jne .noUnderflow
    mov al, TownMapOrderEnd - TownMapOrder - 1  ; number of list items
.noUnderflow:
    mov [ebp + wWhichTownMapLocation], al
    jmp .townMapLoop

; Func_70f87 (pret) is unreferenced dead code (PlayPikachuSoundClip) — omitted.

; --------------------------------------------------------------------------- #
; LoadTownMap_Nest — the Pokedex "<MON>'s NEST" area screen.
; --------------------------------------------------------------------------- #
LoadTownMap_Nest:
    call LoadTownMap
    mov esi, W_UPDATE_SPRITES_ENABLED
    mov al, [ebp + esi]
    push eax                            ; push af
    mov byte [ebp + esi], 0xFF
    push esi                            ; push hl
    call DisplayWildLocations
    call GetMonName
    mov esi, TM_COORD(1, 0)             ; hlcoord 1, 0
    ; GetMonName returns the name at wcd6d / in bc (hl,bc); PlaceString wants the
    ; name flat ptr in EAX and cursor in ESI. GetMonName leaves the name buffer at
    ; wNameBuffer / wStringBuffer; use the standard staged buffer.
    lea eax, [ebp + wNameBuffer]
    call PlaceString
    ; ld h, b / ld l, c  -> continue from where PlaceString left the cursor
    ; (PlaceString returns cursor-at-terminator in EBX per the port contract).
    movzx esi, bx                       ; ld h, b / ld l, c
    lea eax, [MonsNestText]             ; ld de, MonsNestText
    call PlaceString
    call WaitForTextScrollButtonPress
    call ExitTownMap
    pop esi                             ; pop hl
    pop eax                             ; pop af
    mov [ebp + esi], al                 ; ld [hl], a
    ret

; MonsNestText / ToText / AreaUnknownText are generated into town_map_data.inc.

; --------------------------------------------------------------------------- #
; LoadTownMap_Fly — the Fly destination selector.
; --------------------------------------------------------------------------- #
LoadTownMap_Fly:
    call ClearSprites
    call LoadTownMap
    mov al, 1
    mov [ebp + H_JOY7], al              ; ldh [hJoy7], a
    call LoadPlayerSpriteGraphics
    call LoadFontTilePatterns
    ; TODO(unimplemented): lea edx, [BirdSprite]
    mov bh, 0                           ; ld b, BANK(BirdSprite)
    mov bl, 12                          ; ld c, 12
    mov esi, vSpritesTile(BIRD_BASE_TILE)  ; ld hl, vSprites tile BIRD_BASE_TILE
    ; TODO(unimplemented): call CopyVideoData
    lea edx, [TownMapUpArrow]           ; ld de, TownMapUpArrow
    mov esi, vChars1Tile(0x6d)          ; ld hl, vChars1 tile $6d
    mov bh, 0
    mov bl, (TownMapUpArrowEnd - TownMapUpArrow) / TILE_1BPP
    ; TODO(unimplemented): call CopyVideoDataDouble
    call BuildFlyLocationsList
    mov esi, W_UPDATE_SPRITES_ENABLED
    mov al, [ebp + esi]
    push eax                            ; push af
    mov byte [ebp + esi], 0xFF
    push esi                            ; push hl
    mov esi, TM_COORD(0, 0)             ; hlcoord 0, 0
    lea eax, [ToText]                   ; ld de, ToText
    call PlaceString
    mov al, [ebp + W_CUR_MAP]
    mov bh, 0                           ; ld b, 0
    call DrawPlayerOrBirdSprite
    mov esi, wFlyLocationsList          ; ld hl, wFlyLocationsList
    mov edx, TM_COORD(18, 0)            ; decoord 18, 0
.townMapFlyLoop:
    mov al, 0x7F                        ; charmap " "
    mov [ebp + edx], al                 ; ld [de], a
    push esi                            ; push hl
    push esi                            ; push hl
    mov esi, TM_COORD(3, 0)             ; hlcoord 3, 0
    mov bh, 1                           ; lb bc, 1, 15
    mov bl, 15
    ; TODO(unimplemented): call ClearScreenArea
    pop esi                             ; pop hl
    mov al, [ebp + esi]                 ; ld a, [hl]
    mov bh, BIRD_BASE_TILE              ; ld b, BIRD_BASE_TILE
    call DrawPlayerOrBirdSprite
    mov esi, TM_COORD(3, 0)             ; hlcoord 3, 0
    lea eax, [ebp + wNameBuffer]        ; ld de, wNameBuffer
    call PlaceString
    mov bl, 15                          ; ld c, 15
    call DelayFrames
    mov esi, TM_COORD(18, 0)            ; hlcoord 18, 0
    mov byte [ebp + esi], 0xED          ; ld [hl], '▲' (charmap up-arrow)
    mov esi, TM_COORD(19, 0)            ; hlcoord 19, 0
    mov byte [ebp + esi], 0xEE          ; ld [hl], '▼' (charmap down-arrow)
    pop esi                             ; pop hl
.inputLoopFly:
    push esi                            ; push hl
    call DelayFrame
    call JoypadLowSensitivity          ; call JoypadLowSensitivity
    mov al, [ebp + H_JOY5]              ; ldh a, [hJoy5]
    mov bh, al                          ; ld b, a
    pop esi                             ; pop hl
    and al, PAD_A | PAD_B | PAD_UP | PAD_DOWN
    jz .inputLoopFly
    bt ebx, B_PAD_A + 8                 ; bit B_PAD_A, b
    jc .pressedA
    mov al, SFX_TINK
    call PlaySound
    bt ebx, B_PAD_UP + 8               ; bit B_PAD_UP, b
    jc .pressedUpFly
    bt ebx, B_PAD_DOWN + 8             ; bit B_PAD_DOWN, b
    jc .pressedDownFly
    jmp .pressedB
.pressedA:
    mov al, SFX_HEAL_AILMENT
    call PlaySound
    mov al, [ebp + esi]                 ; ld a, [hl]
    mov [ebp + wDestinationMap], al     ; ld [wDestinationMap], a
    mov al, [ebp + W_STATUS_FLAGS_6]
    or al, 1 << BIT_FLY_WARP            ; set BIT_FLY_WARP, [hl]
    mov [ebp + W_STATUS_FLAGS_6], al
    mov al, [ebp + wStatusFlags7]       ; wStatusFlags6 + 1 == wStatusFlags7
    or al, 1 << BIT_USED_FLY            ; set BIT_USED_FLY, [hl]
    mov [ebp + wStatusFlags7], al
.pressedB:
    xor al, al
    mov [ebp + wTownMapSpriteBlinkingEnabled], al
    mov [ebp + H_JOY7], al              ; ldh [hJoy7], a
    ; TODO(unimplemented): call GBPalWhiteOutWithDelay3
    pop esi                             ; pop hl (wUpdateSpritesEnabled)
    pop eax                             ; pop af
    mov [ebp + esi], al                 ; ld [hl], a
    ret
.pressedUpFly:
    mov edx, TM_COORD(18, 0)            ; decoord 18, 0
    inc esi                             ; inc hl
    mov al, [ebp + esi]                 ; ld a, [hl]
    cmp al, 0xFF
    je .wrapToStartOfList
    cmp al, NOT_VISITED
    je .pressedUpFly                    ; skip past unvisited towns
    jmp .townMapFlyLoop
.wrapToStartOfList:
    mov esi, wFlyLocationsList
    jmp .townMapFlyLoop
.pressedDownFly:
    mov edx, TM_COORD(19, 0)            ; decoord 19, 0
    dec esi                             ; dec hl
    mov al, [ebp + esi]                 ; ld a, [hl]
    cmp al, 0xFF
    je .wrapToEndOfList
    cmp al, NOT_VISITED
    je .pressedDownFly                  ; skip past unvisited towns
    jmp .townMapFlyLoop
.wrapToEndOfList:
    mov esi, wFlyLocationsList + NUM_CITY_MAPS
    jmp .pressedDownFly


; --------------------------------------------------------------------------- #
; BuildFlyLocationsList — visited-town bitfield -> list of map numbers.
; --------------------------------------------------------------------------- #
BuildFlyLocationsList:
    mov esi, wFlyAnimUsingCoordList
    mov byte [ebp + esi], 0xFF
    inc esi
    mov al, [ebp + wTownVisitedFlag]
    mov dl, al                          ; ld e, a
    mov al, [ebp + wTownVisitedFlag + 1]
    mov dh, al                          ; ld d, a
    mov bh, 0                           ; lb bc, 0, NUM_CITY_MAPS (b = 0)
    mov bl, NUM_CITY_MAPS               ; (c = NUM_CITY_MAPS)
.loop:
    shr dh, 1                           ; srl d
    rcr dl, 1                           ; rr e
    mov al, NOT_VISITED
    jnc .notVisited
    mov al, bh                          ; store the map number if visited
.notVisited:
    mov [ebp + esi], al
    inc esi
    inc bh                              ; inc b
    dec bl                              ; dec c
    jnz .loop
    mov byte [ebp + esi], 0xFF
    ret

; --------------------------------------------------------------------------- #
; LoadTownMap — shared setup: draw the border + decompress the map + palette.
; --------------------------------------------------------------------------- #
LoadTownMap:
    ; port: draw the whole 20-wide screen centered in the 40-wide tile buffer.
    mov dword [text_row_stride], SCREEN_TILES_W
    ; TODO(unimplemented): call GBPalWhiteOutWithDelay3
    call ClearScreen
    call UpdateSprites
    mov esi, TM_COORD(0, 0)             ; hlcoord 0, 0
    mov bh, 0x12                        ; lb bc, $12, $12
    mov bl, 0x12
    call TextBoxBorder
    call DisableLCD
    lea esi, [WorldMapTileGraphics]     ; ld hl, WorldMapTileGraphics
    mov edx, vChars2Tile(0x60)          ; ld de, vChars2 tile $60
    mov bx, WorldMapTileGraphicsEnd - WorldMapTileGraphics
    mov al, 0                           ; BANK(WorldMapTileGraphics)
    call FarCopyData
    lea esi, [MonNestIcon]              ; ld hl, MonNestIcon
    mov edx, vSpritesTile(0x04)         ; ld de, vSprites tile $04
    mov bx, MonNestIconEnd - MonNestIcon
    mov al, 0
    ; TODO(unimplemented): call FarCopyDataDouble
    ; RLE decompress CompressedMap into the centered 20-wide region.
    mov esi, TM_COORD(0, 0)             ; hlcoord 0, 0
    lea edx, [CompressedMap]            ; ld de, CompressedMap (host ROM data)
    xor ecx, ecx                        ; port: column counter for width-20 wrap
.nextTile:
    mov al, [edx]                       ; ld a, [de]
    test al, al
    jz .doneDecode                      ; and a / jr z, .done
    mov bh, al                          ; ld b, a
    and al, 0x0F                        ; run length
    mov bl, al                          ; ld c, a
    mov al, bh
    shr al, 4                           ; swap a / and $f
    add al, 0x60                        ; add $60
.writeRunLoop:
    mov [ebp + esi], al                 ; ld [hli], a
    inc esi
    inc ecx                             ; port: advance/track column
    cmp ecx, TOWNMAP_WIDTH
    jb .noWrap
    xor ecx, ecx
    add esi, SCREEN_TILES_W - TOWNMAP_WIDTH   ; skip to next centered row
.noWrap:
    dec bl                              ; dec c
    jnz .writeRunLoop
    inc edx                             ; inc de
    jmp .nextTile
.doneDecode:
    call EnableLCD
    mov bh, SET_PAL_TOWN_MAP            ; ld b, SET_PAL_TOWN_MAP
    ; TODO(unimplemented): call RunPaletteCommand
    call Delay3
    call GBPalNormal
    xor al, al
    mov [ebp + wAnimCounter], al
    inc al
    mov [ebp + wTownMapSpriteBlinkingEnabled], al
    ret

; --------------------------------------------------------------------------- #
; ExitTownMap — restore the normal graphics/palette.
; --------------------------------------------------------------------------- #
ExitTownMap:
    xor al, al
    mov [ebp + wTownMapSpriteBlinkingEnabled], al
    ; TODO(unimplemented): call GBPalWhiteOut
    call ClearScreen
    call ClearSprites
    call LoadPlayerSpriteGraphics
    call LoadFontTilePatterns
    call UpdateSprites
    mov dword [text_row_stride], 20     ; port: restore default GB stride
    ret                                 ; TODO(unimplemented): jp RunDefaultPaletteCommand

; --------------------------------------------------------------------------- #
; DrawPlayerOrBirdSprite — a = map number, b = OAM base tile.
; --------------------------------------------------------------------------- #
DrawPlayerOrBirdSprite:
    push eax                            ; push af
    mov al, bh                          ; ld a, b
    mov [ebp + wOAMBaseTile], al        ; ld [wOAMBaseTile], a
    pop eax                             ; pop af
    mov edx, wTownMapCoords             ; ld de, wTownMapCoords
    call LoadTownMapEntry
    mov al, [ebp + edx]                 ; ld a, [de]
    push esi                            ; push hl (name ptr)
    call TownMapCoordsToOAMCoords
    call WritePlayerOrBirdSpriteOAM
    pop esi                             ; pop hl (name ptr)
    mov edx, wNameBuffer                ; ld de, wNameBuffer
.copyLoop:
    mov al, [esi]                       ; ld a, [hli]
    inc esi
    mov [ebp + edx], al                 ; ld [de], a
    inc edx
    cmp al, 0x50                        ; charmap "@" terminator
    jne .copyLoop
    mov esi, wShadowOAM                 ; ld hl, wShadowOAM
    mov edx, wShadowOAMBackup           ; ld de, wShadowOAMBackup
    mov bx, OAM_COUNT * 4               ; ld bc, OAM_COUNT * 4
    jmp CopyData

; --------------------------------------------------------------------------- #
; DisplayWildLocations — nest icons for a mon's wild-encounter maps.
; --------------------------------------------------------------------------- #
DisplayWildLocations:
    ; TODO(unimplemented): call FindWildLocationsOfMon
    call ZeroOutDuplicatesInList
    mov esi, wShadowOAM                 ; ld hl, wShadowOAM
    mov edx, wTownMapCoords             ; ld de, wTownMapCoords
.loop:
    mov al, [ebp + edx]                 ; ld a, [de]
    cmp al, 0xFF
    je .exitLoop
    test al, al                         ; and a
    jz .nextEntry
    push esi                            ; push hl
    call LoadTownMapEntry
    pop esi                             ; pop hl
    mov al, [ebp + edx]                 ; ld a, [de]
    cmp al, 0x19                        ; Cerulean Cave's coordinates
    je .nextEntry                       ; skip Cerulean Cave
    call TownMapCoordsToOAMCoords
    mov al, 4                           ; nest icon tile no.
    mov [ebp + esi], al                 ; ld [hli], a
    inc esi
    xor al, al
    mov [ebp + esi], al                 ; ld [hli], a
    inc esi
.nextEntry:
    inc edx                             ; inc de
    jmp .loop
.exitLoop:
    mov eax, esi                        ; ld a, l (low byte of hl) — were any OAM written?
    test al, al                         ; and a
    jnz .drawPlayerSprite
    mov esi, TM_COORD(1, 7)             ; hlcoord 1, 7
    mov bh, 2                           ; lb bc, 2, 15
    mov bl, 15
    call TextBoxBorder
    mov esi, TM_COORD(2, 9)             ; hlcoord 2, 9
    lea eax, [AreaUnknownText]          ; ld de, AreaUnknownText
    call PlaceString
    jmp .done
.drawPlayerSprite:
    mov al, [ebp + W_CUR_MAP]
    mov bh, 0                           ; ld b, 0
    call DrawPlayerOrBirdSprite
.done:
    mov esi, wShadowOAM                 ; ld hl, wShadowOAM
    mov edx, wShadowOAMBackup           ; ld de, wShadowOAMBackup
    mov bx, OAM_COUNT * 4
    jmp CopyData


; --------------------------------------------------------------------------- #
; TownMapCoordsToOAMCoords — packed map coords -> OAM pixel coords (centered).
; in: lower nybble al = x, upper nybble al = y; esi = OAM write ptr.
; out: bh/[hl] = y*8 + 24 (+centering), bl/[hl+1] = x*8 + 24 (+centering).
; --------------------------------------------------------------------------- #
TownMapCoordsToOAMCoords:
    push eax                            ; push af
    and al, 0xF0
    shr al, 1                           ; y*8
    add al, 24 + TOWNMAP_Y_PX
    mov bh, al                          ; ld b, a
    mov [ebp + esi], al                 ; ld [hli], a
    inc esi
    pop eax                             ; pop af
    and al, 0x0F
    shl al, 4                           ; swap a
    shr al, 1                           ; x*8
    add al, 24 + TOWNMAP_X_PX
    mov bl, al                          ; ld c, a
    mov [ebp + esi], al                 ; ld [hli], a
    inc esi
    ret

; --------------------------------------------------------------------------- #
; WritePlayerOrBirdSpriteOAM / WriteTownMapSpriteOAM
; --------------------------------------------------------------------------- #
WritePlayerOrBirdSpriteOAM:
    mov al, [ebp + wOAMBaseTile]
    test al, al                         ; and a
    mov esi, wShadowOAMSprite36         ; for player sprite
    jz WriteTownMapSpriteOAM
    mov esi, wShadowOAMSprite32         ; for bird sprite
WriteTownMapSpriteOAM:
    push esi                            ; push hl
    ; lb hl, -4, -4 / add hl, bc / ld b,h / ld c,l  ==  bc += 0xFCFC (mod 0x10000)
    add bx, 0xFCFC
    pop esi                             ; pop hl
    ; fallthrough

; Writes 4 OAM blocks for an asymmetric (helix) party sprite (no X-symmetry).
WriteAsymmetricMonPartySpriteOAM:
    mov dh, 2                           ; lb de, 2, 2
    mov dl, 2
.loop:
    push edx                            ; push de
    push ebx                            ; push bc
.innerLoop:
    mov al, bh                          ; ld a, b (Y)
    mov [ebp + esi], al
    inc esi
    mov al, bl                          ; ld a, c (X)
    mov [ebp + esi], al
    inc esi
    mov al, [ebp + wOAMBaseTile]
    mov [ebp + esi], al
    inc esi
    inc al
    mov [ebp + wOAMBaseTile], al
    xor al, al
    mov [ebp + esi], al                 ; attributes
    inc esi
    inc dh                              ; inc d (unused-but-faithful quirk)
    mov al, 8
    add al, bl                          ; add c
    mov bl, al                          ; ld c, a
    dec dl                              ; dec e
    jnz .innerLoop
    pop ebx                             ; pop bc
    pop edx                             ; pop de
    mov al, 8
    add al, bh                          ; add b
    mov bh, al                          ; ld b, a
    dec dh                              ; dec d
    jnz .loop
    ret

; Writes 4 OAM blocks for a symmetric party sprite (uses OAM_XFLIP, 2 tiles).
WriteSymmetricMonPartySpriteOAM:
    xor al, al
    mov [ebp + wSymmetricSpriteOAMAttributes], al
    mov dh, 2                           ; lb de, 2, 2
    mov dl, 2
.loop:
    push edx                            ; push de
    push ebx                            ; push bc
.innerLoop:
    mov al, bh                          ; ld a, b (Y)
    mov [ebp + esi], al
    inc esi
    mov al, bl                          ; ld a, c (X)
    mov [ebp + esi], al
    inc esi
    mov al, [ebp + wOAMBaseTile]
    mov [ebp + esi], al                 ; tile
    inc esi
    mov al, [ebp + wSymmetricSpriteOAMAttributes]
    mov [ebp + esi], al                 ; attributes
    inc esi
    xor al, OAM_XFLIP
    mov [ebp + wSymmetricSpriteOAMAttributes], al
    inc dh                              ; inc d
    mov al, 8
    add al, bl                          ; add c
    mov bl, al                          ; ld c, a
    dec dl                              ; dec e
    jnz .innerLoop
    pop ebx                             ; pop bc
    pop edx                             ; pop de
    inc byte [ebp + wOAMBaseTile]       ; inc [hl] (wOAMBaseTile) x2
    inc byte [ebp + wOAMBaseTile]
    mov al, 8
    add al, bh                          ; add b
    mov bh, al                          ; ld b, a
    dec dh                              ; dec d
    jnz .loop
    ret

; --------------------------------------------------------------------------- #
; ZeroOutDuplicatesInList — zero repeated bytes in the wild-location list.
; --------------------------------------------------------------------------- #
ZeroOutDuplicatesInList:
    mov edx, wBuffer                    ; ld de, wBuffer
.loop:
    mov al, [ebp + edx]                 ; ld a, [de]
    inc edx
    cmp al, 0xFF
    je .ret                             ; ret z
    mov bl, al                          ; ld c, a
    mov esi, edx                        ; ld l, e / ld h, d
.zeroDuplicatesLoop:
    mov al, [ebp + esi]                 ; ld a, [hl]
    cmp al, 0xFF
    je .loop
    cmp al, bl                          ; cp c
    jne .skipZeroing
    xor al, al
    mov [ebp + esi], al
.skipZeroing:
    inc esi
    jmp .zeroDuplicatesLoop
.ret:
    ret

; --------------------------------------------------------------------------- #
; LoadTownMapEntry — al = map number, edx = dest (wTownMapCoords).
; out: [edx] = packed coord (y<<4|x); esi = name label host address.
; NOTE: entries carry 4-byte host name pointers (dd), so the strides are 5 (ext)
;       and 6 (int), not pret's 3/4. Lookup logic is otherwise identical.
; --------------------------------------------------------------------------- #
LoadTownMapEntry:
    cmp al, FIRST_INDOOR_MAP
    jc .external
    lea esi, [InternalMapEntries]
.loop:
    cmp al, [esi]                       ; cp [hl] (INDOORGROUP threshold)
    jc .foundEntry
    add esi, 6                          ; ld bc, 4 -> port stride 6
    jmp .loop
.foundEntry:
    inc esi                             ; skip INDOORGROUP byte -> coord
    jmp .readEntry
.external:
    lea esi, [ExternalMapEntries]
    movzx ecx, al
    lea esi, [esi + ecx * 4]            ; + 4*id
    add esi, ecx                        ; + id  (port stride 5)
.readEntry:
    mov al, [esi]                       ; ld a, [hli] (coord)
    inc esi
    mov [ebp + edx], al                 ; ld [de], a
    mov esi, [esi]                      ; ld a,[hli]/ld h,[hl]/ld l,a — 4-byte name ptr
    ret

; --------------------------------------------------------------------------- #
; TownMapSpriteBlinkingAnimation — blink the cursor/nest sprites.
; --------------------------------------------------------------------------- #
TownMapSpriteBlinkingAnimation:
    mov al, [ebp + wAnimCounter]
    inc al
    cmp al, 25
    je .hideSprites
    cmp al, 50
    jne .done
    ; show sprites when the counter reaches 50
    mov esi, wShadowOAMBackup           ; ld hl, wShadowOAMBackup
    mov edx, wShadowOAM                 ; ld de, wShadowOAM
    mov bx, (OAM_COUNT - 4) * 4         ; ld bc, (OAM_COUNT - 4) * 4
    call CopyData
    xor al, al
    jmp .done
.hideSprites:
    mov esi, wShadowOAMSprite00YCoord   ; ld hl, wShadowOAMSprite00YCoord
    mov bh, OAM_COUNT - 4               ; ld b, OAM_COUNT - 4
    mov edx, OBJ_SIZE                   ; ld de, OBJ_SIZE
.hideSpritesLoop:
    mov byte [ebp + esi], SCREEN_HEIGHT_PX + OAM_Y_OFS
    add esi, edx                        ; add hl, de
    dec bh                              ; dec b
    jnz .hideSpritesLoop
    mov al, 25
.done:
    mov [ebp + wAnimCounter], al
    jmp DelayFrame

section .data
%include "assets/town_map_data.inc"
%include "assets/town_map_gfx.inc"
