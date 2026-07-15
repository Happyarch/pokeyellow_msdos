; town_map.asm — faithful port of engine/items/town_map.asm (pret).
;
; The TOWN MAP viewer (DisplayTownMap), the Fly destination selector
; (LoadTownMap_Fly), and the Pokedex "MON's NEST" area screen (LoadTownMap_Nest),
; plus their shared helpers (LoadTownMap RLE decoder, LoadTownMapEntry, the OAM
; writers, cursor blinking). Translated 1:1 from the SM83 source.
;
; LIVE: linked and reachable — the bag menu's TOWN_MAP item dispatches here through
; ItemUseTownMap. Every dependency is ported; the WRAM it needs is allocated for real
; in gb_memmap.inc (see the wShadowOAMBackup relocation note there). The remaining
; port-specific deviations are the three marked `; PORT:` below (the flat-canvas
; entry, the TownMapCoordsToOAMCoords write sink, and tm_publish_oam).
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

extern GBPalWhiteOut, GBPalWhiteOutWithDelay3   ; home/fade.asm (relocated)
extern ClearScreenArea               ; home/copy2.asm
extern FarCopyDataDouble, CopyVideoData, CopyVideoDataDouble  ; home/copy2.asm
extern JoypadLowSensitivity            ; src/home/joypad_lowsens.asm (home/joypad2.asm)
extern g_tilecache_dirty               ; ppu.asm — see the FarCopyData note in LoadTownMap
extern g_bg_whiteout                   ; ppu.asm — full-screen BG whiteout flag
extern spr_oam_valid                   ; ppu.asm — render_sprites active-entry count
extern hide_window                     ; home/window.asm
extern PrepareStaticOAM                ; engine/gfx/sprite_oam.asm — publish OBJ positions
extern HideSprites                     ; home/sprites.asm — zero shadow OAM
extern FindWildLocationsOfMon          ; engine/items/item_effects.asm (pret: predef)
extern RunPaletteCommand               ; engine/battle/faint_switch.asm (relocated)
extern RunDefaultPaletteCommand        ; engine/menus/naming_screen.asm (relocated)

; ---- town-map WRAM ---------------------------------------------------------
; Now REAL allocations in gb_memmap.inc, at pret's own addresses. The old
; PLACEHOLDER block based at 0xDE00 is gone: it overlapped wBoxMonNicks (0xDE05)
; and would have eaten box nicknames the moment this file was linked.
; wOAMBaseTile / wAnimCounter / wSymmetricSpriteOAMAttributes / wDestinationMap
; are likewise real (mon-icon OAM work, menus S7).

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

; TownMapCoordsToOAMCoords does `ld [hli], a` twice. At its DisplayWildLocations
; call site HL is a shadow-OAM pointer and those writes are load-bearing. At the
; other TWO call sites (DisplayTownMap, DrawPlayerOrBirdSprite) HL is the map's
; NAME pointer — i.e. a ROM address — so on the GB the writes are silently
; discarded by the hardware. The port cannot discard them: there the pointer is a
; flat host label, and `[ebp + esi]` would land megabytes outside the GB
; allocation (it hung the machine). Those two sites therefore aim the routine at a
; dead 2-byte sink, which reproduces the GB's behaviour exactly. The sink sits
; inside the wBuffer/wTownMapCoords scratch union (0xCEE9, 30 bytes) — the town map
; is a modal screen, so nothing else is live in it while this runs.
TOWNMAP_OAM_SINK   equ wTownMapCoords + 8

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
    call CopyVideoDataDouble
    xor al, al
    mov [ebp + wWhichTownMapLocation], al
    pop eax                             ; pop af -> al = wCurMap
    jmp .enterLoop

.townMapLoop:
    mov esi, TM_COORD(0, 0)             ; hlcoord 0, 0
    mov bh, 1                           ; lb bc, 1, 20 (height 1)
    mov bl, 20                          ; (width 20)
    call ClearScreenArea
    lea esi, [TownMapOrder]
    movzx ecx, byte [ebp + wWhichTownMapLocation]
    add esi, ecx                        ; add hl, bc
    mov al, [esi]                       ; ld a, [hl]
.enterLoop:
    mov edx, wTownMapCoords             ; ld de, wTownMapCoords
    call LoadTownMapEntry
    mov al, [ebp + edx]                 ; ld a, [de]
    push esi                            ; push hl (name ptr)
    mov esi, TOWNMAP_OAM_SINK           ; PORT: pret leaves HL = the ROM name ptr here,
                                        ; so its two [hli] writes go nowhere. See the
                                        ; TOWNMAP_OAM_SINK note above.
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
    lea edx, [BirdSprite]               ; ld de, BirdSprite
    mov bh, 0                           ; ld b, BANK(BirdSprite)
    mov bl, 12                          ; ld c, 12
    mov esi, vSpritesTile(BIRD_BASE_TILE)  ; ld hl, vSprites tile BIRD_BASE_TILE
    call CopyVideoData
    lea edx, [TownMapUpArrow]           ; ld de, TownMapUpArrow
    mov esi, vChars1Tile(0x6d)          ; ld hl, vChars1 tile $6d
    mov bh, 0
    mov bl, (TownMapUpArrowEnd - TownMapUpArrow) / TILE_1BPP
    call CopyVideoDataDouble
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
    call ClearScreenArea
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
    call GBPalWhiteOutWithDelay3
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
    ; --- PORT: save the caller's canvas context (see the flat-canvas note below).
    ; The town map is entered from the BAG, whose list box is a window over the live
    ; overworld BG — so the block-view pointer and the scroll registers below are the
    ; caller's, not ours, and zeroing them without saving leaves the bag composited
    ; over block 0 at scroll 0 when we return. Same class as the battle-exit fix (W-1).
    mov ax, [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR]
    mov [tm_saved_view_ptr], ax
    mov al, [ebp + H_SCX]
    mov [tm_saved_scx], al
    mov al, [ebp + H_SCY]
    mov [tm_saved_scy], al
    mov eax, [text_row_stride]
    mov [tm_saved_stride], eax
    mov eax, [g_bg_whiteout]
    mov [tm_saved_whiteout], eax

    ; port: draw the whole 20-wide screen centered in the 40-wide tile buffer.
    mov dword [text_row_stride], SCREEN_TILES_W
    call GBPalWhiteOutWithDelay3
    call ClearScreen
    call UpdateSprites

    ; --- PORT: flat-canvas render setup (the status_screen / init_battle template).
    ; Without this render_bg keeps compositing the OVERWORLD from the block view
    ; pointer and the scroll registers, and the freshly-drawn W_TILEMAP is never
    ; shown — the first attempt at this screen rendered Pallet Town.
    ; The SHADOWS matter as much as the registers: commit_shadow_regs copies H_SCX/SCY
    ; over IO_SCX/SCY every DelayFrame, so a stale overworld scroll would drag the flat
    ; canvas off-screen a frame later.
    mov word [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR], 0
    mov byte [ebp + H_SCX], 0
    mov byte [ebp + H_SCY], 0
    mov byte [ebp + IO_SCX], 0
    mov byte [ebp + IO_SCY], 0
    mov dword [g_bg_whiteout], 0        ; the bag menu may have set it
    ; Suppress the overworld's stale OBJ: render_sprites draws spr_oam_valid entries
    ; from the spr_dos_sx/sy tables, NOT from the OAM Y bytes, so a screen that clears
    ; g_bg_whiteout without this ghosts the player + NPCs onto the map.
    ; (The town map's OWN OBJ — cursor, player/bird — are written GB-native into shadow
    ; OAM, so they are published to those tables by tm_publish_oam, below.)
    mov dword [spr_oam_valid], 0
    ; ...and zero the shadow OAM itself, which pret gets for free: on entry
    ; wUpdateSpritesEnabled is still 0 (the bag menu's value), and pret's VBlank
    ; PrepareOAMData answers 0 with HideSprites. The port's update_oam only runs at
    ; 1, so without this the overworld's stale OAM entries survive — and tm_publish_oam
    ; then dutifully publishes them as ghost sprites over the map.
    call HideSprites
    call hide_window
    ; BG tile animations rewrite vTileset $03/$14 every DelayFrame; the world-map tiles
    ; live at $60+, so they are not hit — but the animator also arms the cache. Leave it.
    mov esi, TM_COORD(0, 0)             ; hlcoord 0, 0
    mov bh, 0x12                        ; lb bc, $12, $12
    mov bl, 0x12
    call TextBoxBorder
    ; ; PROJ town_map: TextBoxBorder draws an 18x18 box, so its BOTTOM edge lands on
    ; GB row 19 — two rows below the 18-row GB screen, i.e. OFF-SCREEN on hardware.
    ; The port's canvas is 25 rows tall, so those two rows are visible here and read
    ; as a stray frame under the map. Blank them: the GB shows a box with no bottom.
    mov esi, TM_COORD(0, 18)
    mov bh, 2                           ; rows 18-19 (GB), = canvas rows 21-22
    mov bl, 20                          ; the box's full width
    call ClearScreenArea
    call DisableLCD
    ; DEVIATION{class=HAL; pret=engine/items/town_map.asm:LoadTownMap; behavior=copy flat WorldMapTileGraphics through CopyVideoData instead of banked FarCopyData; evidence=pret LoadTownMap copy plus port flat data address and tile-cache invalidation contract; lifetime=permanent flat-memory and software-video boundary}
    ; pret uses FarCopyData here (a plain copy — it can, because the LCD
    ; is off). The port CANNOT: its FarCopyData forwards to CopyData, which resolves
    ; its source EBP-relative, and WorldMapTileGraphics is a FLAT .data label — so
    ; the copy read megabytes past the GB allocation and hung the machine. Same class
    ; as the CopyData bug in evolution.asm. CopyVideoData is the port's flat->VRAM
    ; primitive with the identical effect here, and it arms g_tilecache_dirty — which
    ; a plain copy does NOT: the compositor draws tiles from tile_cache, never from
    ; VRAM, so writing patterns without arming it renders the slots' PREVIOUS tiles.
    mov esi, vChars2Tile(0x60)          ; ESI = dest VRAM offset  (pret: de)
    lea edx, [WorldMapTileGraphics]     ; EDX = flat source       (pret: hl)
    mov bh, 0                           ; BANK(WorldMapTileGraphics) — no-op, flat
    mov bl, (WorldMapTileGraphicsEnd - WorldMapTileGraphics) / TILE_SIZE
    call CopyVideoData
    lea esi, [MonNestIcon]              ; ld hl, MonNestIcon
    mov edx, vSpritesTile(0x04)         ; ld de, vSprites tile $04
    mov bx, MonNestIconEnd - MonNestIcon
    mov al, 0
    call FarCopyDataDouble
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
    call RunPaletteCommand              ; ret-stub until the Phase 5 palette engine
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
    call GBPalWhiteOut
    call ClearScreen
    call ClearSprites
    call LoadPlayerSpriteGraphics
    call LoadFontTilePatterns
    call UpdateSprites
    ; --- PORT: hand the canvas back exactly as LoadTownMap found it. ClearSprites
    ; above already republished spr_oam_valid = 0 (so our OAM does not ghost onto the
    ; caller); these are the BG-side counterparts. Restoring the SAVED stride rather
    ; than the GB default of 20 matters: the bag is re-entered through ItemMenuLoop,
    ; which redraws at its own stride, but any other caller keeps the one it had.
    mov ax, [tm_saved_view_ptr]
    mov [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR], ax
    mov al, [tm_saved_scx]
    mov [ebp + H_SCX], al
    mov [ebp + IO_SCX], al
    mov al, [tm_saved_scy]
    mov [ebp + H_SCY], al
    mov [ebp + IO_SCY], al
    mov eax, [tm_saved_whiteout]
    mov [g_bg_whiteout], eax
    mov eax, [tm_saved_stride]
    mov [text_row_stride], eax
    jmp RunDefaultPaletteCommand        ; pret: jp RunDefaultPaletteCommand

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
    mov esi, TOWNMAP_OAM_SINK           ; PORT: same ROM-write quirk — see above.
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
    call FindWildLocationsOfMon         ; predef FindWildLocationsOfMon
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
    call tm_publish_oam                 ; PORT: see below
    jmp DelayFrame

; ---------------------------------------------------------------------------
; tm_publish_oam — PORT-ONLY. pret writes the cursor straight into wShadowOAM and
; lets the unconditional VBlank OAM DMA carry it to $FE00; it also parks
; wUpdateSpritesEnabled at $FF, which in pret means "OBJ are off and already
; hidden — leave the shadow OAM alone" (PrepareOAMData decrements A *before*
; `cp -1`, so its HideSprites branch fires on 0, not on $FF).
;
; The port cannot inherit that: video/frame.asm's update_oam runs the DMA only when
; wUpdateSpritesEnabled == 1, and render_sprites positions OBJ from the spr_dos_sx/sy
; tables and counts spr_oam_valid — neither of which shadow OAM feeds by itself. So a
; screen that hand-writes OAM must publish it (CLAUDE.md: "whoever owns the canvas owns
; OAM"). That is exactly what the battle pokéballs do via PrepareStaticOAM; do the same
; here, once per frame, since the blink animation rewrites OAM as it runs.
; It also has to enforce the GB's own OBJ visibility rule, which the port's taller
; canvas otherwise breaks: hardware hides an object whose Y is 0 or >= 160 (screen
; y = Y - 16, and the GB screen is 144 rows). HideSprites parks every unused entry
; at Y = $A0 = 160 — off-screen there, but row 144 of our 200-row canvas, i.e. two
; visible ghost sprites under the map. Zero those entries so the OAM bias sends them
; to (-8, -16) instead. This is local to the town map on purpose: PrepareStaticOAM's
; other caller (the battle pokéballs) legitimately places OBJ below GB row 144 on the
; widescreen canvas, so the rule must not be pushed down into the shared primitive.
; ---------------------------------------------------------------------------
tm_publish_oam:
    pushad
    lea esi, [ebp + W_SHADOW_OAM]
    lea edi, [ebp + GB_OAM]
    mov ecx, W_SHADOW_OAM_SIZE
    rep movsb                           ; the DMA pret gets for free

    lea edi, [ebp + GB_OAM]             ; apply the hardware Y-hide rule
    mov ecx, OAM_COUNT
.hideLoop:
    mov al, [edi]                       ; OAM Y
    test al, al
    jz .hidden                          ; Y == 0   -> off the top on hardware
    cmp al, 160
    jb .next                            ; 0 < Y < 160 -> visible on hardware
.hidden:
    mov dword [edi], 0                  ; -> (-8, -16), off-canvas
.next:
    add edi, 4
    dec ecx
    jnz .hideLoop

    mov ecx, OAM_COUNT
    call PrepareStaticOAM               ; -> spr_oam_valid + spr_dos_sx/sy
    popad
    ret

section .data
%include "assets/town_map_data.inc"
%include "assets/town_map_gfx.inc"

; --------------------------------------------------------------------------- #
; PORT-ONLY: the caller's canvas context, saved by LoadTownMap, restored by
; ExitTownMap. Not GB state — these are the port's compositor inputs.
; --------------------------------------------------------------------------- #
section .bss
tm_saved_view_ptr:  resw 1
tm_saved_scx:       resb 1
tm_saved_scy:       resb 1
tm_saved_stride:    resd 1
tm_saved_whiteout:  resd 1
