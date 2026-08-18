; surfing_pikachu.asm — Surfing Pikachu minigame
; Mirror of pret engine/minigame/surfing_pikachu.asm
;
; Check-only translation for Chunk 2.

bits 32

%include "gb_memmap.inc"
%include "gb_macros.inc"
%include "gfx_macros.inc"
%include "coords.inc"
%include "assets/audio_constants.inc"

; ---------------------------------------------------------------------------
; Constants
; ---------------------------------------------------------------------------
GB_VCHARS1                    equ 0x8800
SCREEN_HEIGHT_PX              equ 144
SCREEN_WIDTH_PX               equ 160
TILEMAP_WIDTH_PX              equ 256
SURFING_MINIGAME_FLAT_WATER_Y equ 0x74
SURFING_MINIGAME_CENTER_X     equ 160 / 2 + 8   ; 88 (SCREEN_WIDTH_PX / 2 + OAM_X_OFS)

SURFING_MINIGAME_PIKACHU_STATE_RIDING       equ 0
SURFING_MINIGAME_PIKACHU_STATE_JUMPING      equ 1
SURFING_MINIGAME_PIKACHU_STATE_LANDING      equ 2
SURFING_MINIGAME_PIKACHU_STATE_CRASHED      equ 3
SURFING_MINIGAME_PIKACHU_STATE_GAME_END     equ 4
SURFING_MINIGAME_PIKACHU_STATE_INIT_RESULTS equ 5
SURFING_MINIGAME_PIKACHU_STATE_RESULTS      equ 6

; Palette shade constants for ldpal
SHADE_WHITE equ 0
SHADE_LIGHT equ 1
SHADE_DARK  equ 2
SHADE_BLACK equ 3

; Hardware / interrupt constants
rIF         equ 0xFF0F
rIE         equ 0xFFFF
STAT_MODE_0 equ 0x08                            ; STAT HBlank interrupt enable (bit 3)
IE_VBLANK   equ 1 << 0
IE_STAT     equ 1 << 1
IE_TIMER    equ 1 << 2
IE_SERIAL   equ 1 << 3

LCDC_ON        equ 0x80
LCDC_WIN_9C00  equ 0x40
LCDC_WIN_ON    equ 0x20
LCDC_OBJ_ON    equ 0x02
LCDC_BG_ON     equ 0x01

SET_PAL_SURFING_PIKACHU_TITLE    equ 0x0E
SET_PAL_SURFING_PIKACHU_MINIGAME equ 0x0F

PIKACRY_28  equ 27                              ; 0-based index for PikachuCry28
PIKACRY_34  equ 33                              ; 0-based index for PikachuCry34

OBJ_SIZE    equ 4

; Animated-object struct field offsets (16-byte structs)
ANIM_OBJ_INDEX           equ 0x00
ANIM_OBJ_FRAME_SET       equ 0x01
ANIM_OBJ_CALLBACK        equ 0x02
ANIM_OBJ_TILE            equ 0x03
ANIM_OBJ_X_COORD         equ 0x04
ANIM_OBJ_Y_COORD         equ 0x05
ANIM_OBJ_X_OFFSET        equ 0x06
ANIM_OBJ_Y_OFFSET        equ 0x07
ANIM_OBJ_DURATION        equ 0x08
ANIM_OBJ_DURATION_OFFSET equ 0x09
ANIM_OBJ_FRAME_IDX       equ 0x0A
ANIM_OBJ_FIELD_B         equ 0x0B
ANIM_OBJ_FIELD_C         equ 0x0C
ANIM_OBJ_FIELD_D         equ 0x0D
ANIM_OBJ_FIELD_E         equ 0x0E
ANIM_OBJ_FIELD_F         equ 0x0F

; OAM sprite fields
wShadowOAMSprite00TileID equ wShadowOAM + 0*4 + 2
wShadowOAMSprite02TileID equ wShadowOAM + 2*4 + 2
wShadowOAMSprite04XCoord equ wShadowOAM + 4*4 + 1
wShadowOAMSprite05XCoord equ wShadowOAM + 5*4 + 1

; WRAM / Script flag definitions
wPikachuMapScriptFlags       equ 0xD492
BIT_PIKACHU_MAP_SURF_SELECT equ 1

; Animated-object spawn table staging destination in GB space
W_SURF_SPAWN_DATA equ W_SURF_OAM_DATA + 0x1BE

; Coordinate projection macros: battle projection (+10 cols, +3 rows) onto 40x25 canvas
%unmacro hlcoord 2-3
%unmacro decoord 2-3
%unmacro debgcoord 2-3

%macro hlcoord 2-3
    mov esi, BCOORD(%1, %2)
%endmacro

%macro decoord 2-3
    mov edx, BCOORD(%1, %2)
%endmacro

%macro debgcoord 2-3
    %if %0 >= 3
        bgcoord edx, %1, %2, %3
    %else
        bgcoord edx, %1, %2
    %endif
%endmacro

; ---------------------------------------------------------------------------
; External symbols
; ---------------------------------------------------------------------------
extern ClearObjectAnimationBuffers                  ; src/engine/gfx/animated_objects.asm
extern ClearSprites                                 ; src/home/clear_sprites.asm
extern CopyData                                     ; src/home/copy.asm
extern DelayFrame                                   ; src/home/vblank.asm
extern DisableLCD                                   ; src/home/lcd.asm
extern FarCopyData                                  ; src/home/copy.asm
extern FillMemory                                   ; src/home/copy2.asm
extern GBPalNormal                                  ; src/home/palettes.asm
extern Joypad                                       ; src/home/joypad.asm
extern MaskCurrentAnimatedObjectStruct             ; src/engine/gfx/animated_objects.asm
extern PlayDefaultMusic                             ; src/home/audio.asm
extern PlayMusic                                    ; src/home/audio.asm
extern PlayPikachuSoundClip                         ; src/audio/pikachu_pcm.asm
extern PlaySound                                    ; src/home/audio.asm
extern Random                                       ; src/home/random.asm
extern RunDefaultPaletteCommand                     ; src/home/palettes.asm
extern RunObjectAnimations                          ; src/engine/gfx/animated_objects.asm
extern RunPaletteCommand                            ; src/home/palettes.asm
extern SetCurrentAnimatedObjectCallbackAndResetFrameStateRegisters ; src/engine/gfx/animated_objects.asm
extern SpawnAnimatedObject                          ; src/engine/gfx/animated_objects.asm
extern UpdateCGBPal_BGP                             ; src/home/cgb_palettes.asm
extern UpdateCGBPal_OBP0                            ; src/home/cgb_palettes.asm
extern UpdateCGBPal_OBP1                            ; src/home/cgb_palettes.asm
extern WaitForSoundToFinish                         ; src/home/delay.asm
extern RedrawRowOrColumn                            ; src/home/vcopy.asm
extern VBlankCopy                                   ; src/home/vcopy.asm

extern IsSurfingStarterPikachuInParty               ; src/engine/pikachu/pikachu_status.asm
extern ReloadMapAfterSurfingMinigame                ; src/home/overworld.asm
extern SurfingPikachuFrames                         ; src/data/sprite_anims/surfing_pikachu_frames.asm
extern SurfingPikachuOAMData                        ; src/data/sprite_anims/surfing_pikachu_oam.asm
extern add_window                                   ; src/ppu/ppu.asm
extern hide_window                                  ; src/ppu/ppu.asm
extern g_bg_whiteout                                ; src/ppu/ppu.asm
extern g_obj_clip                                   ; src/ppu/ppu.asm
extern g_obj_over_window                            ; src/ppu/ppu.asm
extern g_row_yoff                                   ; src/ppu/ppu.asm
%ifdef DEBUG_SURFING_PIKACHU
extern SurfingPikachuDebugFrameHook  ; src/debug/debug_dump.asm
%endif
extern PublishProjectedOAM              ; src/engine/gfx/sprite_oam.asm
extern g_row_yoff_on                                ; src/ppu/ppu.asm
extern g_surface_redraw_cb                          ; src/ppu/ppu.asm
extern g_tilecache_dirty                            ; src/ppu/ppu.asm
extern g_windows                                    ; src/ppu/ppu.asm
extern SurfingPikachu1Graphics1                     ; src/gfx/surfing_pikachu.asm
extern SurfingPikachu1Graphics1End                  ; src/gfx/surfing_pikachu.asm
extern SurfingPikachu1Graphics2                     ; src/gfx/surfing_pikachu.asm
extern SurfingPikachu1Graphics2End                  ; src/gfx/surfing_pikachu.asm
extern SurfingPikachu1Graphics3                     ; src/gfx/surfing_pikachu.asm
extern SurfingPikachu1Graphics3End                  ; src/gfx/surfing_pikachu.asm

; ---------------------------------------------------------------------------
; Global declarations (all 175 pret labels)
; ---------------------------------------------------------------------------
global SurfingPikachuMinigame
global SurfingPikachuLoop
global SurfingPikachu_CheckPressedSelect
global SurfingMinigame_ToggleStartFlag
global SurfingMinigame_UpdateMusicTempo
global SurfingMinigame_ResetMusicTempo
global SurfingPikachuMinigame_LoadGFXAndLayout
global SurfingPikachuMinigame_SetBGPals
global SurfingPikachuMinigame_InitStaticSpriteLayout
global SurfingPikachuMinigame_PlaceSpriteRowFromTiles
global SurfingPikachuMiniPikachuTile
global SurfingPikachuHPDigitTiles
global SurfingPikachuWideCloudTiles
global SurfingPikachuNarrowCloudTiles
global SurfingPikachuMinigame_DrawStaticTilemapLayout
global SurfingPikachuStatusBarTiles
global RunSurfingMinigameRoutine
global SurfingMinigame_StartGame
global SurfingMinigame_RunGame
global SurfingMinigame_WaitToShowResults
global SurfingMinigame_ScrollToResultsScreen
global SurfingMinigame_DrawResultsScreenAndWait
global SurfingMinigame_WriteHPLeftAndWait
global SurfingMinigame_WriteRadnessAndWait
global SurfingMinigame_WriteTotalAndWait
global SurfingMinigame_AddRemainingHPToTotalAndWait
global SurfingMinigame_AddRadnessToTotalAndWait
global SurfingMinigame_WaitLast
global SurfingMinigame_ExitOnPressA
global SurfingMinigame_GameOver
global SurfingMinigame_RunDelayTimer
global SurfingMinigame_UpdatePikachuDistance
global SurfingMinigameAnimatedObjectFn_Pikachu
global SurfingMinigame_UpdateRidingPikachu
global SurfingMinigame_UpdateJumpingPikachu
global SurfingMinigame_UpdateLandingPikachu
global SurfingMinigame_UpdateCrashedPikachu
global SurfingMinigame_UpdateGameEndPikachu
global SurfingMinigame_InitResultsPikachu
global SurfingMinigame_UpdateResultsPikachu
global SurfingMinigame_DPadAction
global SurfingMinigame_TileInteraction
global SurfingMinigame_SpeedUpPikachu
global SurfingMinigame_ReduceSpeedBy64
global SurfingMinigame_ReduceSpeedBy128
global SurfingMinigame_TryStartJump
global SurfingMinigame_UpdateSurfingFrame
global SurfingMinigame_UpdateBoardAngle
global SurfingMinigame_GetSpeedDividedBy32
global SurfingMinigame_SpawnWaterSpray
global SurfingMinigame_MoveBannerToCenter
global SurfingMinigame_MaskCurrentAnimatedObject
global SurfingMinigameAnimatedObjectFn_FlippingPika
global SurfingMinigameAnimatedObjectFn_IntroAnimationPikachu
global SurfingMinigame_MoveClouds
global SurfingMinigame_ReadBGMapBuffer
global SurfingMinigame_SetPikachuHeight
global SurfingMinigame_Deduct1HP
global SurfingMinigame_DrawHP
global SurfingMinigame_DrawResultsScreen
global SurfingMinigame_PrintTextHiScore
global SurfingMinigame_WriteHPLeft
global SurfingMinigame_AddRemainingHPToTotal
global SurfingMinigame_BCDPrintHPLeft
global SurfingMinigame_WriteRadness
global SurfingMinigame_AddRadnessToTotal
global SurfingMinigame_BCDPrintRadness
global SurfingMinigame_AddPointsToTotal
global SurfingMinigame_BCDPrintTotalScore
global SurfingMinigame_WriteTotal
global DidPlayerGetAHighScore
global SurfingMinigame_PlayPikaCryIfSurfingPikaInParty
global SurfingMinigame_IncreaseRadnessMeter
global SurfingMinigame_CalculateAndAddRadnessFromStunt
global SurfingMinigame_AddRadness
global SurfingMinigame_CoastAfterGoal
global SurfingMinigame_ScrollAndGenerateBGMap
global SurfingMinigame_GenerateBGMap
global SurfingMinigame_GetWaveDataPointers
global SurfingMinigame_ChooseNextWaveSequence
global SurfingMinigame_WaveSequenceStarts
global SurfingMinigame_LoadWavePattern00AndAdvance
global SurfingMinigame_LoadWavePattern01AndAdvance
global SurfingMinigame_LoadWavePattern02AndAdvance
global SurfingMinigame_LoadWavePattern03AndAdvance
global SurfingMinigame_LoadWavePattern04AndAdvance
global SurfingMinigame_LoadWavePattern05AndAdvance
global SurfingMinigame_LoadWavePattern06AndAdvance
global SurfingMinigame_LoadWavePattern07AndAdvance
global SurfingMinigame_LoadWavePattern08AndAdvance
global SurfingMinigame_LoadWavePattern09AndAdvance
global SurfingMinigame_LoadWavePattern0AAndAdvance
global SurfingMinigame_LoadWavePattern0BAndAdvance
global SurfingMinigame_LoadWavePattern0CAndAdvance
global SurfingMinigame_LoadWavePattern0DAndAdvance
global SurfingMinigame_LoadWavePattern0EAndAdvance
global SurfingMinigame_LoadWavePattern0FAndAdvance
global SurfingMinigame_LoadWavePattern10AndAdvance
global SurfingMinigame_LoadWavePattern11AndAdvance
global SurfingMinigame_LoadWavePattern12AndAdvance
global SurfingMinigame_LoadWavePattern13AndAdvance
global SurfingMinigame_LoadWavePattern14AndAdvance
global SurfingMinigame_LoadWavePattern15AndAdvance
global SurfingMinigame_LoadWavePattern16AndAdvance
global SurfingMinigame_LoadWavePattern17AndAdvance
global SurfingMinigame_LoadWavePattern18AndAdvance
global SurfingMinigame_LoadWavePattern19AndAdvance
global SurfingMinigame_LoadWavePattern1AAndAdvance
global SurfingMinigame_LoadWavePattern1BAndAdvance
global SurfingMinigame_LoadWavePattern1CAndAdvance
global SurfingMinigame_LoadBeachPatternAndAdvance
global SurfingMinigame_LoadBeachPatternAndReset
global SurfingMinigame_LoadFlatWaveAndReset
global SurfingMinigame_LoadFlatWave
global SurfingMinigame_AdvanceWaveFunctionFromA
global SurfingMinigame_AdvanceWaveFunction
global SurfingMinigame_ResetWaveSequence
global SurfingPikachuMinigameIntro
global DrawSurfingPikachuMinigameIntroBackground
global SurfingMinigame_UpdateLYOverrides
global SurfingMinigame_InitScanlineOverrides
global SurfingPikachu_GetJoypad_3FrameBuffer
global SurfingPikachuMinigame_BlankPals
global SurfingPikachuMinigame_NormalPals
global SurfingPikachu_ClearTileMap
global SurfingMinigame_ResetJumpArc
global SurfingMinigame_UpdatePikachuHeight
global SurfingMinigame_NTimesDE
global SurfingPikachu_PlaceBCDNumber
global SurfingPikachu_Cosine
global SurfingPikachu_Sine
global SurfingPikachuObjectSpawnData
global SurfingPikachuObjectCallbacks
global SurfingMinigameAnimatedObjectFn_nop
global SurfingMinigame_LYOverridesInitialSineWave
global SurfingMinigame_LYOverridesInitialSineWaveEnd
global SurfingMinigame_BGMetatileTable
global SurfingMinigameWavePattern00
global SurfingMinigameWavePattern01
global SurfingMinigameWavePattern02
global SurfingMinigameWavePattern03
global SurfingMinigameWavePattern04
global SurfingMinigameWavePattern05
global SurfingMinigameWavePattern06
global SurfingMinigameWavePattern07
global SurfingMinigameWavePattern08
global SurfingMinigameWavePattern09
global SurfingMinigameWavePattern0A
global SurfingMinigameWavePattern0B
global SurfingMinigameWavePattern0C
global SurfingMinigameWavePattern0D
global SurfingMinigameWavePattern0E
global SurfingMinigameWavePattern0F
global SurfingMinigameWavePattern10
global SurfingMinigameWavePattern11
global SurfingMinigameWavePattern12
global SurfingMinigameWavePattern13
global SurfingMinigameWavePattern14
global SurfingMinigameWavePattern15
global SurfingMinigameWavePattern16
global SurfingMinigameWavePattern17
global SurfingMinigameWavePattern18
global SurfingMinigameWavePattern19
global SurfingMinigameWavePattern1A
global SurfingMinigameWavePattern1B
global SurfingMinigameWavePattern1C
global SurfingMinigameBeachPattern

section .text

; ---------------------------------------------------------------------------
; SurfingPikachuMinigame
; ---------------------------------------------------------------------------
SurfingPikachuMinigame:
    call SurfingPikachuMinigame_BlankPals
    call DelayFrame
    call DelayFrame
    call DelayFrame
    mov al, [ebp + hTileAnimations]
    push eax
    xor al, al
    mov [ebp + hTileAnimations], al
    mov al, [ebp + wUpdateSpritesEnabled]
    push eax
    mov byte [ebp + wUpdateSpritesEnabled], 0xFF
    mov al, [ebp + rIE]
    push eax
    xor al, al
    mov [ebp + rIF], al
    mov byte [ebp + rIE], IE_VBLANK | IE_STAT | IE_TIMER | IE_SERIAL
    ; DEVIATION{class=HAL; pret=engine/minigame/surfing_pikachu.asm:SurfingPikachuMinigame; behavior=ldh [rSTAT] is stored to emulated memory without hardware interrupt dispatch; evidence=STAT HBlank interrupt is not emulated in the port and per-scanline effect is delivered by compositor; lifetime=permanent software-video boundary}
    mov byte [ebp + IO_STAT], STAT_MODE_0
    mov al, [ebp + hAutoBGTransferDest + 1]
    push eax
    mov byte [ebp + hAutoBGTransferDest + 1], vBGMap0 >> 8
    call SurfingMinigame_SetupPresentation
    call SurfingPikachuMinigameIntro
    call SurfingPikachuLoop
    call SurfingMinigame_TeardownPresentation
    xor al, al
    mov [ebp + IO_BGP], al
    mov [ebp + IO_OBP0], al
    mov [ebp + IO_OBP1], al
    call UpdateCGBPal_BGP
    call UpdateCGBPal_OBP0
    call UpdateCGBPal_OBP1
    call ClearObjectAnimationBuffers
    call ClearSprites
    xor al, al
    mov [ebp + hLCDCPointer], al
    mov [ebp + hSCX], al
    mov [ebp + hSCY], al
    mov byte [ebp + hWY], 200                    ; keep the window below visible screen (RENDER_H / 200)
    call DelayFrame
    pop eax
    mov [ebp + hAutoBGTransferDest + 1], al
    xor al, al
    mov [ebp + rIF], al
    pop eax
    mov [ebp + rIE], al
    xor al, al
    mov [ebp + IO_STAT], al
    call RunDefaultPaletteCommand
    call ReloadMapAfterSurfingMinigame
    call PlayDefaultMusic
    call GBPalNormal
    pop eax
    mov [ebp + wUpdateSpritesEnabled], al
    pop eax
    mov [ebp + hTileAnimations], al
    ret

; ===========================================================================
; Port-only presentation glue (no pret counterpart)
; ===========================================================================

; ---------------------------------------------------------------------------
; SurfingMinigame_SetupPresentation — port-only PPU configuration.
;
; Configures the PPU for the Surfing Pikachu minigame:
; - Whiteout BG matte (g_bg_whiteout = 1)
; - Centered 160x144 projection via 2 window descriptors (BG plane + Status bar)
; - Fine source scroll for BG torus wrapping
; - Hardware OBJ over window order (g_obj_over_window = 1)
; - Projected OBJ clip rectangle (80, 24, 240, 168)
; - Arms per-frame presentation callback (g_surface_redraw_cb)
; ---------------------------------------------------------------------------
SurfingMinigame_SetupPresentation:
    mov dword [g_bg_whiteout], 1
    call hide_window

    ; Window descriptor 0: BG plane
    ; wx = 80 + 7, wy = 24, clip_w = 160, max_y = 168, tilemap = GB_TILEMAP0, start_row = 0
    mov eax, 80 + 7
    mov ebx, 24
    mov ecx, 160
    mov edx, 168
    mov esi, GB_TILEMAP0
    xor edi, edi
    call add_window

    ; Fine scroll offsets for BG plane
    movzx eax, byte [ebp + hSCX]
    mov [g_windows + WIN_SRC_X], eax
    movzx eax, byte [ebp + hSCY]
    mov [g_windows + WIN_SRC_Y], eax

    ; Window descriptor 1: Status bar
    ; wx = 80 + 7, wy = 24 + 0x7E, clip_w = 160, max_y = 168, tilemap = GB_TILEMAP1, start_row = 0
    mov eax, 80 + 7
    mov ebx, 24 + 0x7E
    mov ecx, 160
    mov edx, 168
    mov esi, GB_TILEMAP1
    xor edi, edi
    call add_window

    ; Hardware OBJ over window order (Pikachu draws over water)
    mov dword [g_obj_over_window], 1

    ; Projected OBJ clipping rectangle (x0, y0, x1, y1)
    mov dword [g_obj_clip + 0], 80
    mov dword [g_obj_clip + 4], 24
    mov dword [g_obj_clip + 8], 240
    mov dword [g_obj_clip + 12], 168

    ; Arm per-frame callback and initialize
    mov dword [g_surface_redraw_cb], SurfingMinigame_PerFramePresentation
    call SurfingMinigame_PerFramePresentation
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_TeardownPresentation — port-only PPU restoration.
;
; Restores all PPU presentation flags to defaults.
; ---------------------------------------------------------------------------
SurfingMinigame_TeardownPresentation:
    mov dword [g_surface_redraw_cb], 0
    mov dword [g_bg_whiteout], 0
    mov dword [g_obj_over_window], 0
    mov dword [g_row_yoff_on], 0
    mov dword [g_obj_clip + 0], 0
    mov dword [g_obj_clip + 4], 0
    mov dword [g_obj_clip + 8], RENDER_W
    mov dword [g_obj_clip + 12], RENDER_H
    call hide_window
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_PerFramePresentation — port-only per-frame hook.
;
; Invoked each frame from DelayFrame via g_surface_redraw_cb.
; Updates fine scrolling on BG plane, status bar WY, and scanline overrides.
; ---------------------------------------------------------------------------
SurfingMinigame_PerFramePresentation:
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi

    ; 1. Refresh BG window descriptor fine scroll offsets
    movzx eax, byte [ebp + hSCX]
    mov [g_windows + WIN_SRC_X], eax
    movzx eax, byte [ebp + hSCY]
    mov [g_windows + WIN_SRC_Y], eax

    ; 2. Refresh Status Bar window WY from hWY
    movzx eax, byte [ebp + hWY]
    add eax, 24
    cmp eax, 168
    jbe .wy_ok
    mov eax, 168
.wy_ok:
    mov [g_windows + WIN_DESC_SIZE + WIN_WY], eax

    ; 3. Per-scanline wave table mapping (g_row_yoff)
    mov al, [ebp + hLCDCPointer]
    test al, al
    jz .disable_row_yoff

    mov dword [g_row_yoff_on], 1

    ; Clear top 24 rows: rows 0..23
    xor eax, eax
    mov edi, g_row_yoff
    mov ecx, 24 / 4             ; 6 dwords = 24 bytes
    rep stosd

    ; Copy 144 GB scanlines: L = 0..143 -> screen rows 24..167
    ; g_row_yoff[24 + L] = (wLYOverrides[L] - hSCY) & 0xFF
    mov esi, wLYOverrides
    mov dl, [ebp + hSCY]
    mov ecx, 144
.ly_loop:
    mov al, [ebp + esi]
    inc esi
    sub al, dl
    mov [edi], al
    inc edi
    dec ecx
    jnz .ly_loop

    ; Clear bottom 32 rows: rows 168..199
    xor eax, eax
    mov ecx, 32 / 4             ; 8 dwords = 32 bytes
    rep stosd
    jmp .done

.disable_row_yoff:
    mov dword [g_row_yoff_on], 0

.done:
    ; 4. PUBLISH SHADOW OAM TO THE COMPOSITOR.
    ;
    ; Without this the minigame draws NO SPRITES AT ALL — measured live
    ; 2026-08-18: no Pikachu on the water and none in the status bar, on a
    ; screen whose BG and HUD were otherwise correct. RunObjectAnimations fills
    ; wShadowOAM ($C300) exactly as pret does, and on the Game Boy the hardware
    ; OAM DMA would carry it to $FE00 and the PPU would scan it. The port has no
    ; such DMA and render_sprites positions from spr_dos_sx/spr_dos_sy, so a
    ; scene driver must publish its own OAM or nothing is drawn — the rule
    ; CLAUDE.md states as "whoever owns the canvas owns OAM", and the contract
    ; animated_objects.asm records ("the frame pipeline / scene driver publishes
    ; it projected via PublishProjectedOAM").
    ;
    ; This screen sets wUpdateSpritesEnabled = $FF, which puts it on the
    ; direct-OAM protocol: update_oam deliberately leaves it alone, so nothing
    ; else was ever going to publish on its behalf.
    ;
    ; Origin (80,24) is the same centred-GB-screen origin as g_obj_clip, which
    ; SetupPresentation arms to (80,24,240,168) — so an entry the GB would hide
    ; off-screen projects outside the clip and produces no pixels, preserving
    ; the hardware's hiding semantics. Same publish the battle animator uses
    ; (engine/battle/animations.asm:DrawFrameBlock).
    mov esi, wShadowOAM                 ; canonical OAM, GB offset
    mov ecx, OAM_COUNT                  ; all 40; offscreen hidden by g_obj_clip
    mov eax, 80                         ; centred-GB-screen origin X
    mov ebx, 24                         ; centred-GB-screen origin Y
    call PublishProjectedOAM

    ; 5. RE-ARM THE HARDWARE OBJ-OVER-WINDOW ORDER, EVERY FRAME.
    ;
    ; SetupPresentation arms this once, but ClearSprites and HideSprites both
    ; zero it ("the OBJ-over-window order dies with them", clear_sprites.asm),
    ; and the minigame calls ClearSprites faithfully — SurfingPikachuLoop's very
    ; first act is SurfingPikachuMinigame_LoadGFXAndLayout, which does so at
    ; entry. Measured live 2026-08-18 with dosbox-mcp: g_obj_over_window read
    ; back 0 while spr_oam_valid was 40 and spr_dos_sx/sy held in-clip canvas
    ; positions — the OBJ were published and then painted over.
    ;
    ; On this screen that is total invisibility rather than a z-order nit:
    ; window descriptor 0 IS the whole 160x144 GB screen, so the port's default
    ; window-last order overpaints every OBJ pixel. That is why publishing OAM
    ; alone left frame 90 byte-identical (commit 1a5da9d1b).
    ;
    ; Re-arming here rather than after the ClearSprites call keeps the flag with
    ; the publish it belongs to and makes it immune to any further faithful
    ; ClearSprites/HideSprites the minigame runs mid-loop.
    mov dword [g_obj_over_window], 1

    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

; ---------------------------------------------------------------------------
; SurfingPikachuLoop
; ---------------------------------------------------------------------------
SurfingPikachuLoop:
    call SurfingPikachuMinigame_LoadGFXAndLayout
    call DelayFrame
    mov bh, SET_PAL_SURFING_PIKACHU_TITLE
    call RunPaletteCommand
.loop:
    mov al, [ebp + wSurfingMinigameRoutineNumber]
    test al, 0x80
    jnz .ret
    call SurfingPikachu_GetJoypad_3FrameBuffer
    call SurfingPikachu_CheckPressedSelect
    jnz .ret
    call RunSurfingMinigameRoutine
    mov byte [ebp + wCurrentAnimatedObjectOAMBufferOffset], 15 * OBJ_SIZE
    call RunObjectAnimations
    call SurfingMinigame_MoveClouds
    call .DelayFrame
    call SurfingMinigame_UpdateMusicTempo
    jmp .loop
.ret:
    ret

.DelayFrame:
    call DelayFrame
%ifdef DEBUG_SURFING_PIKACHU
    call SurfingPikachuDebugFrameHook   ; harness: photograph frame N and exit
%endif
    ret

; ---------------------------------------------------------------------------
; SurfingPikachu_CheckPressedSelect
; ---------------------------------------------------------------------------
SurfingPikachu_CheckPressedSelect:
    mov esi, wPikachuMapScriptFlags
    test byte [ebp + esi], 1 << BIT_PIKACHU_MAP_SURF_SELECT
    jz .ret
    mov al, [ebp + hJoyPressed]
    and al, PAD_SELECT
.ret:
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_ToggleStartFlag (unused in pret)
; ---------------------------------------------------------------------------
SurfingMinigame_ToggleStartFlag:
    mov al, [ebp + hJoyPressed]
    and al, PAD_START
    jz .ret
    mov esi, wSurfingMinigameUnusedToggle
    mov al, [ebp + esi]
    xor al, 1
    mov [ebp + esi], al
.ret:
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_UpdateMusicTempo
; ---------------------------------------------------------------------------
SurfingMinigame_UpdateMusicTempo:
    mov al, [ebp + wSurfingMinigameMusicTempoEnabled]
    test al, al
    jz .ret

    ; check that all channels are on their last frame of note delay
    mov esi, wChannelNoteDelayCounters
    mov al, 1
    cmp al, [ebp + esi]
    jnz .ret
    inc esi
    cmp al, [ebp + esi]
    jnz .ret
    inc esi
    cmp al, [ebp + esi]
    jnz .ret

    ; de = ([wSurfingMinigamePikachuSpeed] & $3ff) * 2
    mov dl, [ebp + wSurfingMinigamePikachuSpeed]
    mov al, [ebp + wSurfingMinigamePikachuSpeed + 1]
    and al, 3
    mov dh, al
    shl dl, 1
    rcl dh, 1
    mov dl, dh
    mov dh, 0
    movzx edx, dx
    mov esi, .Tempos
    lea esi, [esi + edx*2]
    lea esi, [esi + edx*2]
    ; wMusicTempo is big-endian: pret stores [hli] (low byte) into wMusicTempo+1, [hl] (high byte) into wMusicTempo
    mov al, [esi]
    mov [ebp + wMusicTempo + 1], al
    mov al, [esi + 1]
    mov [ebp + wMusicTempo], al
.ret:
    ret

.Tempos:
    dw 117
    dw 109
    dw 101
    dw  93
    dw  85

; ---------------------------------------------------------------------------
; SurfingMinigame_ResetMusicTempo
; ---------------------------------------------------------------------------
SurfingMinigame_ResetMusicTempo:
    mov esi, wChannelNoteDelayCounters
    mov al, 1
    cmp al, [ebp + esi]
    jnz .ret
    inc esi
    cmp al, [ebp + esi]
    jnz .ret
    inc esi
    cmp al, [ebp + esi]
    jnz .ret
    mov byte [ebp + wMusicTempo + 1], 117
    xor al, al
    mov [ebp + wMusicTempo], al
.ret:
    ret

; ---------------------------------------------------------------------------
; CopySurfingPikachuAnimatedObjectData — PORT-ONLY helper (no pret counterpart).
; Copies the Frames, OAM, and Spawn tables from flat program memory to their
; contiguous GB echo RAM staging area at W_SURF_ANIM_DATA (0xFB00), modeled on
; CopyYellowIntroAnimatedObjectData (intro_yellow.asm).
; ---------------------------------------------------------------------------
CopySurfingPikachuAnimatedObjectData:
    pushad
    mov esi, SurfingPikachuFrames
    lea edi, [ebp + W_SURF_FRAMES_DATA]
    mov ecx, W_SURF_OAM_DATA - W_SURF_FRAMES_DATA
    rep movsb
    mov esi, SurfingPikachuOAMData
    mov ecx, W_SURF_SPAWN_DATA - W_SURF_OAM_DATA
    rep movsb
    mov esi, SurfingPikachuObjectSpawnData
    mov ecx, SurfingPikachuObjectSpawnDataEnd - SurfingPikachuObjectSpawnData
    rep movsb
    popad
    ret

; ---------------------------------------------------------------------------
; SurfingPikachuMinigame_LoadGFXAndLayout
; ---------------------------------------------------------------------------
SurfingPikachuMinigame_LoadGFXAndLayout:
    call SurfingPikachu_ClearTileMap
    call ClearSprites
    call DisableLCD
    mov esi, wSurfingMinigameData
    mov bx, wSurfingMinigameDataEnd - wSurfingMinigameData
    xor al, al
    call FillMemory
    mov esi, wLYOverrides
    mov bx, wLYOverridesBufferEnd - wLYOverrides
    xor al, al
    call FillMemory
    xor al, al
    mov [ebp + hAutoBGTransferEnabled], al
    call ClearObjectAnimationBuffers

    mov esi, SurfingPikachu1Graphics1
    sub esi, ebp
    mov edx, GB_VCHARS2
    mov bx, 80 * 16
    call FarCopyData
    mov byte [g_tilecache_dirty], 1

    mov esi, SurfingPikachu1Graphics2
    sub esi, ebp
    mov edx, GB_VCHARS0
    mov bx, 256 * 16
    call FarCopyData
    mov byte [g_tilecache_dirty], 1

    ; Stage animated-object tables from flat program image to GB echo RAM
    call CopySurfingPikachuAnimatedObjectData

    mov word  [ebp + wAnimatedObjectSpawnStateDataPointer], W_SURF_SPAWN_DATA   ; GB ptr
    mov dword [ebp + wAnimatedObjectJumptablePointer],      SurfingPikachuObjectCallbacks  ; HOST ptr
    mov word  [ebp + wAnimatedObjectOAMDataPointer],        W_SURF_OAM_DATA     ; GB ptr
    mov word  [ebp + wAnimatedObjectFramesDataPointer],     W_SURF_FRAMES_DATA  ; GB ptr

    mov esi, vBGMap0
    mov bx, 2 * TILEMAP_AREA
    xor al, al
    call FillMemory

    mov esi, (6)*TILEMAP_WIDTH + 0 + vBGMap0   ; hlbgcoord 0, 6
    mov bx, 12 * TILEMAP_WIDTH
    mov al, 0x0B                                ; water tile
    call FillMemory

    mov al, 1                                  ; surfing Pikachu
    lb dx, SURFING_MINIGAME_FLAT_WATER_Y, SURFING_MINIGAME_CENTER_X
    call SpawnAnimatedObject

    mov byte [ebp + wSurfingMinigamePikachuObjectHeight], SURFING_MINIGAME_FLAT_WATER_Y

    call SurfingMinigame_InitScanlineOverrides

    xor al, al
    mov [ebp + hSCX], al
    mov [ebp + hSCY], al
    mov byte [ebp + hWY], 0x7E                 ; place HP window just below Pikachu's waterline
    ; DEVIATION{class=HAL; pret=engine/minigame/surfing_pikachu.asm:SurfingPikachuMinigame_LoadGFXAndLayout; behavior=the per-scanline LY scroll override is stored faithfully to hLCDCPointer and wLYOverrides but nothing consumes them yet in chunk 2; evidence=hLCDCPointer and wLYOverrides are written by the minigame engine and will feed chunk 3 compositor channel; lifetime=retire when chunk 3 wires the per-scanline compositor channel}
    mov byte [ebp + hLCDCPointer], 0x42         ; rSCY - 0xFF00
    mov byte [ebp + wSurfingMinigamePikachuSpeed], 0x40 ; 0.25 initial speed
    xor al, al
    mov [ebp + wSurfingMinigamePikachuSpeed + 1], al
    mov [ebp + wSurfingMinigamePikachuHP], al
    mov byte [ebp + wSurfingMinigamePikachuHP + 1], 0x60 ; initial HP: $6000 in little-endian BCD
    mov esi, wSurfingMinigameWaveHeight
    mov bx, 20                                 ; pret: SCREEN_WIDTH (array length)
    mov al, SURFING_MINIGAME_FLAT_WATER_Y
    call FillMemory
    call SurfingPikachuMinigame_InitStaticSpriteLayout
    call SurfingPikachuMinigame_DrawStaticTilemapLayout
    mov byte [ebp + IO_LCDC], LCDC_ON | LCDC_WIN_9C00 | LCDC_WIN_ON | LCDC_OBJ_ON | LCDC_BG_ON
    call SurfingPikachuMinigame_SetBGPals
    ldpal al, SHADE_BLACK, SHADE_DARK, SHADE_LIGHT, SHADE_WHITE
    mov [ebp + IO_OBP0], al
    ldpal al, SHADE_BLACK, SHADE_DARK, SHADE_WHITE, SHADE_WHITE
    mov [ebp + IO_OBP1], al
    call UpdateCGBPal_OBP0
    call UpdateCGBPal_OBP1
    ret

; ---------------------------------------------------------------------------
; SurfingPikachuMinigame_SetBGPals
; ---------------------------------------------------------------------------
SurfingPikachuMinigame_SetBGPals:
    mov al, [ebp + wOnSGB]
    test al, al
    jnz .sgb
    ldpal al, SHADE_BLACK, SHADE_LIGHT, SHADE_WHITE, SHADE_WHITE
    mov [ebp + IO_BGP], al
    call UpdateCGBPal_BGP
    ret

.sgb:
    ldpal al, SHADE_BLACK, SHADE_DARK, SHADE_LIGHT, SHADE_WHITE
    mov [ebp + IO_BGP], al
    call UpdateCGBPal_BGP
    ret

; ---------------------------------------------------------------------------
; SurfingPikachuMinigame_InitStaticSpriteLayout
; ---------------------------------------------------------------------------
SurfingPikachuMinigame_InitStaticSpriteLayout:
    mov esi, wSpriteDataEnd
    mov edx, SurfingPikachuHPDigitTiles
    mov bh, 0x97                                ; HP digits: OAM Y
    mov bl, 0x80                                ; OAM X
    mov al, 4
    call SurfingPikachuMinigame_PlaceSpriteRowFromTiles
    mov edx, SurfingPikachuMiniPikachuTile
    mov bh, 0x96                                ; progress marker: OAM Y
    mov bl, 0x50                                ; OAM X
    mov al, 1
    call SurfingPikachuMinigame_PlaceSpriteRowFromTiles
    mov edx, SurfingPikachuWideCloudTiles
    mov bh, 0x14                                ; wide cloud: OAM Y
    mov bl, 0x20                                ; OAM X
    mov al, 5
    call SurfingPikachuMinigame_PlaceSpriteRowFromTiles
    mov edx, SurfingPikachuNarrowCloudTiles
    mov bh, 0x20                                ; narrow cloud: OAM Y
    mov bl, 0x80                                ; OAM X
    mov al, 4
    call SurfingPikachuMinigame_PlaceSpriteRowFromTiles
    ret

; ---------------------------------------------------------------------------
; SurfingPikachuMinigame_PlaceSpriteRowFromTiles
; ---------------------------------------------------------------------------
SurfingPikachuMinigame_PlaceSpriteRowFromTiles:
.loop:
    push eax
    mov [ebp + esi], bh                        ; Y
    inc esi
    mov [ebp + esi], bl                        ; X
    inc esi
    mov al, [edx]                              ; TileID
    mov [ebp + esi], al
    inc esi
    mov byte [ebp + esi], 0                    ; Attributes
    inc esi
    mov al, bl
    add al, TILE_WIDTH
    mov bl, al
    inc edx
    pop eax
    dec al
    jnz .loop
    ret

; ---------------------------------------------------------------------------
; SurfingPikachuMinigame_DrawStaticTilemapLayout
; ---------------------------------------------------------------------------
SurfingPikachuMinigame_DrawStaticTilemapLayout:
    debgcoord 1, 1, vBGMap1
    mov esi, SurfingPikachuStatusBarTiles
    mov cl, 9
.copyTileRow:
    mov al, [esi]
    inc esi
    mov [ebp + edx], al
    inc edx
    dec cl
    jnz .copyTileRow
    mov byte [ebp + (0)*TILEMAP_WIDTH + 1 + vBGMap1], 0x15 ; hlbgcoord 1, 0, vBGMap1
    mov byte [ebp + (0)*TILEMAP_WIDTH + 2 + vBGMap1], 0x16 ; hlbgcoord 2, 0, vBGMap1
    mov byte [ebp + (1)*TILEMAP_WIDTH + 12 + vBGMap1], 0x1B ; hlbgcoord 12, 1, vBGMap1
    mov byte [ebp + (1)*TILEMAP_WIDTH + 13 + vBGMap1], 0x1C ; hlbgcoord 13, 1, vBGMap1
    ret

; ---------------------------------------------------------------------------
; RunSurfingMinigameRoutine
; ---------------------------------------------------------------------------
RunSurfingMinigameRoutine:
    movzx edx, byte [ebp + wSurfingMinigameRoutineNumber]
    jmp [.Jumptable + edx*4]

.Jumptable:
    dd SurfingMinigame_StartGame ; 0
    dd SurfingMinigame_RunGame ; 1
    dd SurfingMinigame_WaitToShowResults ; 2
    dd SurfingMinigame_ScrollToResultsScreen ; 3
    dd SurfingMinigame_DrawResultsScreenAndWait ; 4
    dd SurfingMinigame_WriteHPLeftAndWait ; 5
    dd SurfingMinigame_WriteRadnessAndWait ; 6
    dd SurfingMinigame_WriteTotalAndWait ; 7
    dd SurfingMinigame_AddRemainingHPToTotalAndWait ; 8
    dd SurfingMinigame_AddRadnessToTotalAndWait ; 9
    dd SurfingMinigame_WaitLast ; a
    dd SurfingMinigame_ExitOnPressA ; b
    dd SurfingMinigame_GameOver ; c

; ---------------------------------------------------------------------------
; SurfingMinigame_StartGame
; ---------------------------------------------------------------------------
SurfingMinigame_StartGame:
    mov al, 2                                  ; "START" text
    lb dx, 0x48, 0xE0                          ; banner OAM Y, X
    call SpawnAnimatedObject
    inc byte [ebp + wSurfingMinigameRoutineNumber]
    mov byte [ebp + wSurfingMinigameMusicTempoEnabled], 1
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_RunGame
; ---------------------------------------------------------------------------
SurfingMinigame_RunGame:
    mov al, [ebp + wSurfingMinigameDistance]
    cmp al, 0x18                               ; end of 24-section course
    jae .finished
    mov esi, wSurfingMinigamePikachuHP
    mov al, [ebp + esi]
    inc esi
    or al, [ebp + esi]
    test al, al
    jz .dead
    call Random
    mov [ebp + wSurfingMinigameWaveRandomValue], al
    call SurfingMinigame_UpdateLYOverrides
    call SurfingMinigame_SetPikachuHeight
    call SurfingMinigame_ReadBGMapBuffer
    call SurfingMinigame_ScrollAndGenerateBGMap
    call SurfingMinigame_UpdatePikachuDistance
    call SurfingMinigame_Deduct1HP
    call SurfingMinigame_DrawHP
    ret

.finished:
    inc byte [ebp + wSurfingMinigameRoutineNumber]
    xor al, al
    mov [ebp + wSurfingMinigameMusicTempoEnabled], al
    mov byte [ebp + wSurfingMinigameRoutineDelay], 192 ; coast before results
    ret

.dead:
    mov byte [ebp + wSurfingMinigameGameOver], 1
    mov byte [ebp + wSurfingMinigameRoutineNumber], 0x0C
    mov byte [ebp + wSurfingMinigameGameOverDelay], 0x80
    mov al, 0x0B                               ; "Oh no.." text
    lb dx, 0x88, SURFING_MINIGAME_CENTER_X
    call SpawnAnimatedObject
    mov byte [ebp + ebx + ANIM_OBJ_Y_OFFSET], 0x80
    mov byte [ebp + ebx + ANIM_OBJ_FIELD_B], 0x80
    mov byte [ebp + ebx + ANIM_OBJ_FIELD_C], 0x30
    xor al, al
    mov [ebp + wSurfingMinigameMusicTempoEnabled], al
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_WaitToShowResults
; ---------------------------------------------------------------------------
SurfingMinigame_WaitToShowResults:
    call SurfingMinigame_RunDelayTimer
    jc .doneDelay
    xor al, al
    mov [ebp + wSurfingMinigameWaveRandomValue], al
    call SurfingMinigame_UpdateLYOverrides
    call SurfingMinigame_SetPikachuHeight
    call SurfingMinigame_ReadBGMapBuffer
    call SurfingMinigame_CoastAfterGoal
    call SurfingMinigame_ResetMusicTempo
    ret

.doneDelay:
    inc byte [ebp + wSurfingMinigameRoutineNumber]
    mov byte [ebp + hSCX], 0x90
    mov byte [ebp + wSurfingMinigameWaveFunctionNumber], 0x72
    mov byte [ebp + wSurfingMinigamePikachuState], SURFING_MINIGAME_PIKACHU_STATE_GAME_END
    xor al, al
    mov [ebp + hLCDCPointer], al
    mov [ebp + wSurfingMinigameSCX], al
    mov [ebp + wSurfingMinigameSCX2], al
    mov [ebp + wSurfingMinigameSCXHi], al
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_ScrollToResultsScreen
; ---------------------------------------------------------------------------
SurfingMinigame_ScrollToResultsScreen:
    mov al, [ebp + hSCX]
    test al, al
    jz .finished
    call SurfingMinigame_UpdateLYOverrides
    call SurfingMinigame_SetPikachuHeight
    call SurfingMinigame_ReadBGMapBuffer
    mov al, [ebp + hSCX]
    sub al, 4
    mov [ebp + hSCX], al
    mov byte [ebp + wSurfingMinigameXOffset], TILEMAP_WIDTH_PX - 32
    call SurfingMinigame_GenerateBGMap
    ret

.finished:
    xor al, al
    mov [ebp + wSurfingMinigamePikachuSpeed], al
    mov [ebp + wSurfingMinigamePikachuSpeed + 1], al
    inc byte [ebp + wSurfingMinigameRoutineNumber]
    mov byte [ebp + wSurfingMinigamePikachuState], SURFING_MINIGAME_PIKACHU_STATE_INIT_RESULTS
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_DrawResultsScreenAndWait
; ---------------------------------------------------------------------------
SurfingMinigame_DrawResultsScreenAndWait:
    call SurfingMinigame_DrawResultsScreen
    mov byte [ebp + wSurfingMinigameRoutineDelay], 32
    inc byte [ebp + wSurfingMinigameRoutineNumber]
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_WriteHPLeftAndWait
; ---------------------------------------------------------------------------
SurfingMinigame_WriteHPLeftAndWait:
    call SurfingMinigame_RunDelayTimer
    jnc .ret
    call SurfingMinigame_WriteHPLeft
    mov byte [ebp + wSurfingMinigameRoutineDelay], 64
    inc byte [ebp + wSurfingMinigameRoutineNumber]
.ret:
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_WriteRadnessAndWait
; ---------------------------------------------------------------------------
SurfingMinigame_WriteRadnessAndWait:
    call SurfingMinigame_RunDelayTimer
    jnc .ret
    call SurfingMinigame_WriteRadness
    mov byte [ebp + wSurfingMinigameRoutineDelay], 64
    inc byte [ebp + wSurfingMinigameRoutineNumber]
.ret:
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_WriteTotalAndWait
; ---------------------------------------------------------------------------
SurfingMinigame_WriteTotalAndWait:
    call SurfingMinigame_RunDelayTimer
    jnc .ret
    call SurfingMinigame_WriteTotal
    mov byte [ebp + wSurfingMinigameRoutineDelay], 64
    inc byte [ebp + wSurfingMinigameRoutineNumber]
.ret:
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_AddRemainingHPToTotalAndWait
; ---------------------------------------------------------------------------
SurfingMinigame_AddRemainingHPToTotalAndWait:
    call SurfingMinigame_RunDelayTimer
    jnc .ret
    call SurfingMinigame_AddRemainingHPToTotal
    push eax
    call SurfingMinigame_BCDPrintTotalScore
    pop eax
    jnc .ret
    mov byte [ebp + wSurfingMinigameRoutineDelay], 64
    inc byte [ebp + wSurfingMinigameRoutineNumber]
.ret:
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_AddRadnessToTotalAndWait
; ---------------------------------------------------------------------------
SurfingMinigame_AddRadnessToTotalAndWait:
    call SurfingMinigame_RunDelayTimer
    jnc .ret
    call SurfingMinigame_AddRadnessToTotal
    push eax
    call SurfingMinigame_BCDPrintTotalScore
    pop eax
    jnc .ret
    mov byte [ebp + wSurfingMinigameRoutineDelay], 128
    inc byte [ebp + wSurfingMinigameRoutineNumber]
    call DidPlayerGetAHighScore
    jnc .ret
    call SurfingMinigame_PrintTextHiScore
    mov byte [ebp + wSurfingMinigamePikachuState], SURFING_MINIGAME_PIKACHU_STATE_RESULTS
.ret:
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_WaitLast
; ---------------------------------------------------------------------------
SurfingMinigame_WaitLast:
    call SurfingMinigame_RunDelayTimer
    jnc .ret
    inc byte [ebp + wSurfingMinigameRoutineNumber]
.ret:
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_ExitOnPressA
; ---------------------------------------------------------------------------
SurfingMinigame_ExitOnPressA:
    call SurfingMinigame_UpdateLYOverrides
    mov al, [ebp + hJoyPressed]
    test al, PAD_A
    jz .ret
    or byte [ebp + wSurfingMinigameRoutineNumber], 0x80
.ret:
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_GameOver
; ---------------------------------------------------------------------------
SurfingMinigame_GameOver:
    call SurfingMinigame_UpdateLYOverrides
    call SurfingMinigame_SetPikachuHeight
    call SurfingMinigame_ReadBGMapBuffer
    call SurfingMinigame_ScrollAndGenerateBGMap
    call SurfingMinigame_ResetMusicTempo
    mov esi, wSurfingMinigameGameOverDelay
    mov al, [ebp + esi]
    test al, al
    jz .waitPressA
    dec byte [ebp + esi]
    ret

.waitPressA:
    mov al, [ebp + hJoyPressed]
    test al, PAD_A
    jz .ret
    or byte [ebp + wSurfingMinigameRoutineNumber], 0x80
.ret:
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_RunDelayTimer
; ---------------------------------------------------------------------------
SurfingMinigame_RunDelayTimer:
    mov esi, wSurfingMinigameRoutineDelay
    mov al, [ebp + esi]
    test al, al
    jz .setCarry
    dec byte [ebp + esi]
    clc
    ret

.setCarry:
    stc
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_UpdatePikachuDistance
; ---------------------------------------------------------------------------
SurfingMinigame_UpdatePikachuDistance:
    mov ah, [ebp + wSurfingMinigameDistance + 1]
    mov al, [ebp + wSurfingMinigameDistance + 2]
    mov dl, [ebp + wSurfingMinigamePikachuSpeed]
    mov dh, [ebp + wSurfingMinigamePikachuSpeed + 1]
    add ax, dx
    mov [ebp + wSurfingMinigameDistance + 1], ah
    mov [ebp + wSurfingMinigameDistance + 2], al
    jnc .noCarry
    inc byte [ebp + wSurfingMinigameDistance]
    dec byte [ebp + wShadowOAMSprite04XCoord]
    dec byte [ebp + wShadowOAMSprite04XCoord]
.noCarry:
    ret

; ---------------------------------------------------------------------------
; SurfingMinigameAnimatedObjectFn_Pikachu
; ---------------------------------------------------------------------------
SurfingMinigameAnimatedObjectFn_Pikachu:
    movzx edx, byte [ebp + wSurfingMinigamePikachuState]
    jmp [.StateFunctions + edx*4]

.StateFunctions:
    dd SurfingMinigame_UpdateRidingPikachu   ; 0
    dd SurfingMinigame_UpdateJumpingPikachu  ; 1
    dd SurfingMinigame_UpdateLandingPikachu  ; 2
    dd SurfingMinigame_UpdateCrashedPikachu  ; 3
    dd SurfingMinigame_UpdateGameEndPikachu  ; 4
    dd SurfingMinigame_InitResultsPikachu    ; 5
    dd SurfingMinigame_UpdateResultsPikachu  ; 6

; ---------------------------------------------------------------------------
; SurfingMinigame_UpdateRidingPikachu
; ---------------------------------------------------------------------------
SurfingMinigame_UpdateRidingPikachu:
    mov al, [ebp + wSurfingMinigameGameOver]
    test al, al
    jnz .gameOver
    call SurfingMinigame_SpawnWaterSpray
    mov al, [ebp + wSurfingMinigamePikachuObjectHeight]
    mov [ebp + ebx + ANIM_OBJ_Y_COORD], al
    call SurfingMinigame_TryStartJump
    jc .startedJump
    call SurfingMinigame_UpdateSurfingFrame
    call SurfingMinigame_SpeedUpPikachu
    ret

.startedJump:
    call SurfingMinigame_UpdateSurfingFrame
    mov byte [ebp + wSurfingMinigamePikachuState], SURFING_MINIGAME_PIKACHU_STATE_JUMPING
    xor al, al
    mov [ebp + ebx + ANIM_OBJ_FIELD_C], al
    mov [ebp + ebx + ANIM_OBJ_FIELD_D], al
    mov [ebp + ebx + ANIM_OBJ_FIELD_E], al
    mov [ebp + wSurfingMinigameRadnessMeter], al
    mov [ebp + wSurfingMinigameTrickFlags], al
    mov byte [ebp + wChannelSoundIDs + CHAN8], 0
    mov al, SFX_SURFING_JUMP
    call PlaySound
    ret

.gameOver:
    xor al, al
    mov [ebp + wSurfingMinigamePikachuSpeed], al
    mov [ebp + wSurfingMinigamePikachuSpeed + 1], al
    mov byte [ebp + wSurfingMinigamePikachuState], SURFING_MINIGAME_PIKACHU_STATE_GAME_END
    call SurfingMinigame_UpdateSurfingFrame
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_UpdateJumpingPikachu
; ---------------------------------------------------------------------------
SurfingMinigame_UpdateJumpingPikachu:
    call SurfingMinigame_DPadAction
    call SurfingMinigame_UpdatePikachuHeight
    jnc .ret
    call SurfingMinigame_TileInteraction
    jc .crash
    call SurfingMinigame_CalculateAndAddRadnessFromStunt
    mov byte [ebp + ebx + ANIM_OBJ_FIELD_C], 0
    mov byte [ebp + wSurfingMinigamePikachuState], SURFING_MINIGAME_PIKACHU_STATE_LANDING
    ret

.crash:
    mov byte [ebp + wSurfingMinigamePikachuState], SURFING_MINIGAME_PIKACHU_STATE_CRASHED
    mov byte [ebp + wSurfingMinigameCrashTimer], 0x60
    mov al, 0x10
    call SetCurrentAnimatedObjectCallbackAndResetFrameStateRegisters
    mov byte [ebp + wChannelSoundIDs + CHAN8], 0
    mov al, SFX_SURFING_CRASH
    call PlaySound
.ret:
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_UpdateLandingPikachu
; ---------------------------------------------------------------------------
SurfingMinigame_UpdateLandingPikachu:
    mov al, [ebp + ebx + ANIM_OBJ_FIELD_C]
    cmp al, 0x20
    jae .done
    add byte [ebp + ebx + ANIM_OBJ_FIELD_C], 4
    mov dh, 4                                  ; amplitude = 4
    call SurfingPikachu_Sine
    mov [ebp + ebx + ANIM_OBJ_Y_OFFSET], al
    call SurfingMinigame_SpawnWaterSpray
    mov al, [ebp + wSurfingMinigamePikachuObjectHeight]
    mov [ebp + ebx + ANIM_OBJ_Y_COORD], al
    ret

.done:
    mov byte [ebp + ebx + ANIM_OBJ_Y_OFFSET], 0
    mov byte [ebp + wSurfingMinigamePikachuState], SURFING_MINIGAME_PIKACHU_STATE_RIDING
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_UpdateCrashedPikachu
; ---------------------------------------------------------------------------
SurfingMinigame_UpdateCrashedPikachu:
    mov esi, wSurfingMinigameCrashTimer
    mov al, [ebp + esi]
    test al, al
    jz .done
    dec byte [ebp + esi]
    mov al, [ebp + wSurfingMinigamePikachuObjectHeight]
    mov [ebp + ebx + ANIM_OBJ_Y_COORD], al
    ret

.done:
    mov byte [ebp + wSurfingMinigamePikachuState], SURFING_MINIGAME_PIKACHU_STATE_RIDING
    mov al, 4
    call SetCurrentAnimatedObjectCallbackAndResetFrameStateRegisters
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_UpdateGameEndPikachu
; ---------------------------------------------------------------------------
SurfingMinigame_UpdateGameEndPikachu:
    mov al, [ebp + wSurfingMinigamePikachuObjectHeight]
    mov [ebp + ebx + ANIM_OBJ_Y_COORD], al
    call SurfingMinigame_UpdateSurfingFrame
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_InitResultsPikachu
; ---------------------------------------------------------------------------
SurfingMinigame_InitResultsPikachu:
    mov al, 0x0F
    call SetCurrentAnimatedObjectCallbackAndResetFrameStateRegisters
    mov byte [ebp + ebx + ANIM_OBJ_FIELD_C], 0
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_UpdateResultsPikachu
; ---------------------------------------------------------------------------
SurfingMinigame_UpdateResultsPikachu:
    mov al, [ebp + ebx + ANIM_OBJ_FIELD_C]
    add byte [ebp + ebx + ANIM_OBJ_FIELD_C], 2
    and al, 0x3F
    cmp al, 0x20
    jb .resetOffset
    mov dh, 0x10                               ; amplitude = 16
    call SurfingPikachu_Sine
    mov [ebp + ebx + ANIM_OBJ_Y_OFFSET], al
    ret

.resetOffset:
    mov byte [ebp + ebx + ANIM_OBJ_Y_OFFSET], 0
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_DPadAction
; ---------------------------------------------------------------------------
SurfingMinigame_DPadAction:
    mov al, [ebp + hJoy5]
    test al, PAD_LEFT
    jnz .dLeft
    test al, PAD_RIGHT
    jnz .dRight
    ret

.dLeft:
    mov byte [ebp + ebx + ANIM_OBJ_FIELD_E], 0
    mov al, [ebp + ebx + ANIM_OBJ_FIELD_D]
    inc byte [ebp + ebx + ANIM_OBJ_FIELD_D]
    cmp al, 0x0B
    jb .dLeftSkip
    call .StartTrick
    or byte [ebp + wSurfingMinigameTrickFlags], 1
.dLeftSkip:
    mov al, [ebp + ebx + ANIM_OBJ_FRAME_SET]
    cmp al, 0x0E
    jae .dLeftReset
    inc byte [ebp + ebx + ANIM_OBJ_FRAME_SET]
    ret

.dLeftReset:
    mov byte [ebp + ebx + ANIM_OBJ_FRAME_SET], 1
    ret

.dRight:
    mov byte [ebp + ebx + ANIM_OBJ_FIELD_D], 0
    mov al, [ebp + ebx + ANIM_OBJ_FIELD_E]
    inc byte [ebp + ebx + ANIM_OBJ_FIELD_E]
    cmp al, 0x0D
    jb .dRightSkip
    call .StartTrick
    or byte [ebp + wSurfingMinigameTrickFlags], 2
.dRightSkip:
    mov al, [ebp + ebx + ANIM_OBJ_FRAME_SET]
    cmp al, 1
    jz .dRightReset
    dec byte [ebp + ebx + ANIM_OBJ_FRAME_SET]
    ret

.dRightReset:
    mov byte [ebp + ebx + ANIM_OBJ_FRAME_SET], 0x0E
    ret

.StartTrick:
    call SurfingMinigame_IncreaseRadnessMeter
    xor al, al
    mov [ebp + ebx + ANIM_OBJ_FIELD_D], al
    mov [ebp + ebx + ANIM_OBJ_FIELD_E], al
    mov al, SFX_SURFING_FLIP
    call PlaySound
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_TileInteraction
; ---------------------------------------------------------------------------
SurfingMinigame_TileInteraction:
    mov dl, [ebp + ebx + ANIM_OBJ_FRAME_SET]
    mov al, [ebp + wSurfingMinigameBGMapReadBuffer]
    cmp al, 0x06                               ; rising slope
    jz .risingSlope
    cmp al, 0x14                               ; wave crest
    jz .waveCrest
    cmp al, 0x12                               ; wave face
    jz .waveFace
    cmp al, 0x07                               ; falling slope
    jz .fallingSlope
    mov al, dl
    cmp al, 1
    jz .wipeout
    cmp al, 2
    jz .hardLanding
    cmp al, 3
    jz .roughLanding
    cmp al, 4
    jz .cleanLanding
    cmp al, 5
    jz .roughLanding
    cmp al, 6
    jz .hardLanding
    cmp al, 7
    jz .wipeout
    jmp .wipeout

.risingSlope:
    mov al, dl
    cmp al, 1
    jz .wipeout
    cmp al, 2
    jz .wipeout
    cmp al, 3
    jz .wipeout
    cmp al, 4
    jz .hardLanding
    cmp al, 5
    jz .roughLanding
    cmp al, 6
    jz .cleanLanding
    cmp al, 7
    jz .roughLanding
    jmp .wipeout

.fallingSlope:
    mov al, dl
    cmp al, 1
    jz .roughLanding
    cmp al, 2
    jz .cleanLanding
    cmp al, 3
    jz .roughLanding
    cmp al, 4
    jz .hardLanding
    cmp al, 5
    jz .wipeout
    cmp al, 6
    jz .wipeout
    cmp al, 7
    jz .wipeout
    jmp .wipeout

.waveFace:
.waveCrest:
    mov al, dl
    cmp al, 1
    jz .wipeout
    cmp al, 2
    jz .hardLanding
    cmp al, 3
    jz .roughLanding
    cmp al, 4
    jz .cleanLanding
    cmp al, 5
    jz .cleanLanding
    cmp al, 6
    jz .roughLanding
    cmp al, 7
    jz .hardLanding
    jmp .wipeout

.hardLanding:
    call SurfingMinigame_ReduceSpeedBy128
    jmp .cleanLanding

.roughLanding:
    call SurfingMinigame_ReduceSpeedBy64
.cleanLanding:
    mov byte [ebp + wChannelSoundIDs + CHAN8], 0
    mov al, SFX_SURFING_LAND
    call PlaySound
    clc
    ret

.wipeout:
    mov byte [ebp + wSurfingMinigamePikachuSpeed], 0x40 ; 0.25 reset speed
    xor al, al
    mov [ebp + wSurfingMinigamePikachuSpeed + 1], al
    stc
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_SpeedUpPikachu
; ---------------------------------------------------------------------------
SurfingMinigame_SpeedUpPikachu:
    mov al, [ebp + wSurfingMinigamePikachuSpeed + 1]
    cmp al, 2
    jae .ret
    mov ah, al
    mov al, [ebp + wSurfingMinigamePikachuSpeed]
    add ax, 0x0002                             ; 0.0078125 in 8.8 (1/128 per frame)
    mov [ebp + wSurfingMinigamePikachuSpeed + 1], ah
    mov [ebp + wSurfingMinigamePikachuSpeed], al
.ret:
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_ReduceSpeedBy64
; ---------------------------------------------------------------------------
SurfingMinigame_ReduceSpeedBy64:
    mov al, [ebp + wSurfingMinigamePikachuSpeed + 1]
    test al, al
    jnz .go
    mov al, [ebp + wSurfingMinigamePikachuSpeed]
    cmp al, 0x40                               ; 0.25 avoid underflow
    jae .go
    xor al, al
    mov [ebp + wSurfingMinigamePikachuSpeed], al
    ret

.go:
    mov ah, [ebp + wSurfingMinigamePikachuSpeed + 1]
    mov al, [ebp + wSurfingMinigamePikachuSpeed]
    add ax, 0xFFC0                             ; -0.25 in 8.8
    mov [ebp + wSurfingMinigamePikachuSpeed + 1], ah
    mov [ebp + wSurfingMinigamePikachuSpeed], al
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_ReduceSpeedBy128
; ---------------------------------------------------------------------------
SurfingMinigame_ReduceSpeedBy128:
    mov al, [ebp + wSurfingMinigamePikachuSpeed + 1]
    test al, al
    jnz .go
    mov al, [ebp + wSurfingMinigamePikachuSpeed]
    cmp al, 0x80                               ; 0.5 avoid underflow
    jae .go
    xor al, al
    mov [ebp + wSurfingMinigamePikachuSpeed], al
    ret

.go:
    mov ah, [ebp + wSurfingMinigamePikachuSpeed + 1]
    mov al, [ebp + wSurfingMinigamePikachuSpeed]
    add ax, 0xFF80                             ; -0.5 in 8.8
    mov [ebp + wSurfingMinigamePikachuSpeed + 1], ah
    mov [ebp + wSurfingMinigamePikachuSpeed], al
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_TryStartJump
; ---------------------------------------------------------------------------
SurfingMinigame_TryStartJump:
    mov al, [ebp + hSCX]
    and al, 7
    cmp al, 3
    jb .noJump
    cmp al, 5
    jae .noJump
    mov al, [ebp + wSurfingMinigameBGMapReadBuffer]
    cmp al, 0x14                               ; wave crest
    jnz .noJump
    call SurfingMinigame_GetSpeedDividedBy32
    cmp al, 0x0A
    jb .noJump
    mov [ebp + wSurfingMinigameJumpArcMagnitude], al
    call SurfingMinigame_ResetJumpArc
    stc
    ret

.noJump:
    clc
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_UpdateSurfingFrame
; ---------------------------------------------------------------------------
SurfingMinigame_UpdateSurfingFrame:
    mov al, [ebp + hSCX]
    and al, 7
    cmp al, 3
    jb .ret
    cmp al, 5
    jae .ret
    mov al, [ebp + wSurfingMinigameBGMapReadBuffer]
    cmp al, 0x06                               ; rising slope
    jz .risingSlope
    cmp al, 0x14                               ; wave crest
    jz .risingSlope
    cmp al, 0x07                               ; falling slope
    jz .fallingSlope
    call SurfingMinigame_UpdateBoardAngle
    mov byte [ebp + ebx + ANIM_OBJ_FRAME_SET], 4
.ret:
    ret

.risingSlope:
    mov dl, 6
    jmp .selectFrame

.fallingSlope:
    mov dl, 2
.selectFrame:
    mov al, [ebp + wSurfingMinigameBoardAngleOffset]
    dec al
    add al, dl
    mov [ebp + ebx + ANIM_OBJ_FRAME_SET], al
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_UpdateBoardAngle
; ---------------------------------------------------------------------------
SurfingMinigame_UpdateBoardAngle:
    mov esi, wSurfingMinigameBoardAngleTimer
    mov al, [ebp + esi]
    inc byte [ebp + esi]
    and al, 7
    jnz .ret
    mov al, [ebp + wSurfingMinigameBoardAngleDecreasing]
    test al, al
    jz .increase
    mov al, [ebp + wSurfingMinigameBoardAngleOffset]
    test al, al
    jz .startIncreasing
    dec al
    mov [ebp + wSurfingMinigameBoardAngleOffset], al
    ret

.startIncreasing:
    xor al, al
    mov [ebp + wSurfingMinigameBoardAngleDecreasing], al
    ret

.increase:
    mov al, [ebp + wSurfingMinigameBoardAngleOffset]
    cmp al, 2
    jz .startDecreasing
    inc al
    mov [ebp + wSurfingMinigameBoardAngleOffset], al
    ret

.startDecreasing:
    mov byte [ebp + wSurfingMinigameBoardAngleDecreasing], 1
.ret:
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_GetSpeedDividedBy32
; ---------------------------------------------------------------------------
SurfingMinigame_GetSpeedDividedBy32:
    mov al, [ebp + wSurfingMinigamePikachuSpeed]
    mov ah, [ebp + wSurfingMinigamePikachuSpeed + 1]
    shl ax, 1
    shl ax, 1
    shl ax, 1
    mov al, ah
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_SpawnWaterSpray
; ---------------------------------------------------------------------------
SurfingMinigame_SpawnWaterSpray:
    mov esi, wSurfingMinigameWaterSprayCounter
    mov al, [ebp + esi]
    inc byte [ebp + esi]
    and al, 3
    jnz .ret
    call .GetYCoord
    mov dh, al                                 ; DH = Y
    mov dl, [ebp + ebx + ANIM_OBJ_X_COORD]     ; DL = X
    mov al, 0x0A                               ; water spray
    push ebx
    call SpawnAnimatedObject
    pop ebx
.ret:
    ret

.GetYCoord:
    mov al, [ebp + hSCX]
    test al, TILE_WIDTH
    jnz .getHeightPlus9
    mov esi, wSurfingMinigameWaveHeight + 8
    jmp .gotHL

.getHeightPlus9:
    mov esi, wSurfingMinigameWaveHeight + 9
.gotHL:
    mov al, [ebp + wSurfingMinigameBGMapReadBuffer + 1]
    cmp al, 0x06                               ; rising slope
    jz .risingSlope
    cmp al, 0x14                               ; wave crest
    jz .waveCrest
    cmp al, 0x07                               ; falling slope
    jz .fallingSlope
    mov al, [ebp + esi]
    ret

.risingSlope:
.waveCrest:
    mov dl, [ebp + hSCX]
    and dl, 7
    mov al, [ebp + esi]
    sub al, dl
    ret

.fallingSlope:
    mov dl, [ebp + hSCX]
    and dl, 7
    mov al, [ebp + esi]
    add al, dl
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_MoveBannerToCenter
; ---------------------------------------------------------------------------
SurfingMinigame_MoveBannerToCenter:
    mov al, [ebp + ebx + ANIM_OBJ_X_COORD]
    cmp al, SURFING_MINIGAME_CENTER_X
    jz .ret
    add al, 4
    mov [ebp + ebx + ANIM_OBJ_X_COORD], al
.ret:
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_MaskCurrentAnimatedObject (unreferenced in pret)
; ---------------------------------------------------------------------------
SurfingMinigame_MaskCurrentAnimatedObject:
    call MaskCurrentAnimatedObjectStruct
    ret

; ---------------------------------------------------------------------------
; SurfingMinigameAnimatedObjectFn_FlippingPika
; ---------------------------------------------------------------------------
SurfingMinigameAnimatedObjectFn_FlippingPika:
    mov al, [ebp + ebx + ANIM_OBJ_FIELD_B]
    test al, al
    jz .ret
    sub al, 2
    mov [ebp + ebx + ANIM_OBJ_FIELD_B], al
    mov dh, al                                 ; DH = amplitude
    mov al, [ebp + ebx + ANIM_OBJ_FIELD_C]
    inc byte [ebp + ebx + ANIM_OBJ_FIELD_C]
    call SurfingPikachu_Sine
    cmp al, 0x80
    jae .positive
    not al
    inc al
.positive:
    mov [ebp + ebx + ANIM_OBJ_Y_OFFSET], al
.ret:
    ret

; ---------------------------------------------------------------------------
; SurfingMinigameAnimatedObjectFn_IntroAnimationPikachu
; ---------------------------------------------------------------------------
SurfingMinigameAnimatedObjectFn_IntroAnimationPikachu:
    mov al, [ebp + ebx + ANIM_OBJ_FIELD_B]
    inc byte [ebp + ebx + ANIM_OBJ_FIELD_B]
    test al, 1
    jz .ret
    mov al, [ebp + ebx + ANIM_OBJ_X_COORD]
    cmp al, 0xC0                               ; fully off right edge
    jz .done
    inc byte [ebp + ebx + ANIM_OBJ_X_COORD]
    ret

.done:
    mov byte [ebp + wSurfingMinigameIntroAnimationFinished], 1
    call MaskCurrentAnimatedObjectStruct
.ret:
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_MoveClouds
; ---------------------------------------------------------------------------
SurfingMinigame_MoveClouds:
    mov dl, [ebp + wSurfingMinigameCloudScrollFraction]
    mov dh, 0
    mov al, [ebp + wSurfingMinigamePikachuSpeed]
    mov ah, [ebp + wSurfingMinigamePikachuSpeed + 1]
    add ax, dx
    mov [ebp + wSurfingMinigameCloudScrollFraction], al
    mov dh, ah
    mov esi, wShadowOAMSprite05XCoord
    mov dl, 9                                  ; number of cloud sprites (8-bit counter)
.loop:
    mov al, [ebp + esi]
    add al, dh
    mov [ebp + esi], al
    add esi, 4
    dec dl
    jnz .loop
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_ReadBGMapBuffer
; ---------------------------------------------------------------------------
SurfingMinigame_ReadBGMapBuffer:
    mov al, [ebp + wSurfingMinigameBGMapReadBuffer] ; unused read in pret
    mov al, [ebp + hSCX]
    add al, 9 * TILE_WIDTH                     ; sample wave 9 tiles into viewport
    shr al, 3
    movzx edx, al
    mov esi, vBGMap0
    add esi, edx
    mov al, [ebp + wSurfingMinigamePikachuObjectHeight]
    shr al, 3
    mov cl, al                                 ; 8-bit counter
.loop:
    test cl, cl
    jz .copy
    dec cl
    add esi, TILEMAP_WIDTH
    sub esi, vBGMap0
    and esi, TILEMAP_AREA - 1
    add esi, vBGMap0
    jmp .loop

.copy:
    mov byte [ebp + hVBlankCopyDest],     wSurfingMinigameBGMapReadBuffer & 0xFF
    mov byte [ebp + hVBlankCopyDest + 1], wSurfingMinigameBGMapReadBuffer >> 8
    mov ax, si
    mov [ebp + hVBlankCopySource], al
    mov [ebp + hVBlankCopySource + 1], ah
    mov byte [ebp + hVBlankCopySize], 1        ; copy 1 tile during VBlank
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_SetPikachuHeight
; ---------------------------------------------------------------------------
SurfingMinigame_SetPikachuHeight:
    mov al, [ebp + hSCX]
    test al, TILE_WIDTH
    jnz .rightHalf
    mov esi, wSurfingMinigameWaveHeight + 7
    jmp .gotWaveHeight

.rightHalf:
    mov esi, wSurfingMinigameWaveHeight + 8
.gotWaveHeight:
    mov al, [ebp + wSurfingMinigameBGMapReadBuffer]
    cmp al, 0x06                               ; rising slope
    jz .risingSlope
    cmp al, 0x14                               ; wave crest
    jz .waveCrest
    cmp al, 0x07                               ; falling slope
    jz .fallingSlope
    mov al, [ebp + esi]
    mov [ebp + wSurfingMinigamePikachuObjectHeight], al
    ret

.risingSlope:
.waveCrest:
    mov dl, [ebp + hSCX]
    and dl, 7
    mov al, [ebp + esi]
    sub al, dl
    mov [ebp + wSurfingMinigamePikachuObjectHeight], al
    ret

.fallingSlope:
    mov dl, [ebp + hSCX]
    and dl, 7
    mov al, [ebp + esi]
    add al, dl
    mov [ebp + wSurfingMinigamePikachuObjectHeight], al
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_Deduct1HP
; ---------------------------------------------------------------------------
SurfingMinigame_Deduct1HP:
    mov esi, wSurfingMinigamePikachuHP
    mov dl, 0x99
    call .BCD_Deduct
    jnc .ret
    inc esi
    mov dl, 0x99
.BCD_Deduct:
    mov al, [ebp + esi]
    test al, al
    jz .rollOver
    sub al, 1
    das
    mov [ebp + esi], al
    test al, al
    clc
    ret

.rollOver:
    mov [ebp + esi], dl
    stc
.ret:
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_DrawHP
; ---------------------------------------------------------------------------
SurfingMinigame_DrawHP:
    mov edx, wSurfingMinigamePikachuHP + 1
    mov esi, wShadowOAMSprite00TileID
    mov al, [ebp + edx]
    call .PlaceBCDNumber
    mov esi, wShadowOAMSprite02TileID
    mov al, [ebp + edx]
.PlaceBCDNumber:
    mov cl, al
    rol al, 4
    and al, 0x0F
    add al, 0xD0
    mov [ebp + esi], al
    add esi, 4
    mov al, cl
    and al, 0x0F
    add al, 0xD0
    mov [ebp + esi], al
    dec edx
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_DrawResultsScreen
; ---------------------------------------------------------------------------
SurfingMinigame_DrawResultsScreen:
    mov esi, wTileMap
    mov bx, SCREEN_AREA
    xor al, al
    call FillMemory

    ; DEVIATION{class=projection; pret=engine/minigame/surfing_pikachu.asm:SurfingMinigame_DrawResultsScreen; behavior=copy 10x20 tilemap row-by-row with stride 40 starting at BCOORD(0,6); evidence=wTileMap is 40 columns wide in the port vs 20 in pret; lifetime=permanent viewport expansion}
    mov esi, SurfingMinigame_BeachOutroTilemap ; pret: .BeachOutroTilemap
    sub esi, ebp
    decoord 0, 6
    mov ecx, 10
.copyOutroRow:
    push ecx
    push edx
    push esi
    mov bx, 20
    call CopyData
    pop esi
    add esi, 20
    pop edx
    add edx, SCREEN_WIDTH
    pop ecx
    dec ecx
    jnz .copyOutroRow

    call .PlaceTextbox
    mov esi, wShadowOAMSprite05XCoord
    mov bx, 9 * OBJ_SIZE
    xor al, al
    call FillMemory
    mov byte [ebp + hAutoBGTransferEnabled], 1
    ret

.PlaceTextbox:
    hlcoord 1, 1
    lb dx, 0x3B, 0x3C
    mov al, 0x40
    call .placeRow
    hlcoord 1, 2
    lb dx, 0x3F, 0x3F
    mov al, 0xFF
    call .placeRow
    hlcoord 1, 3
    lb dx, 0x3F, 0x3F
    mov al, 0xFF
    call .placeRow
    hlcoord 1, 4
    lb dx, 0x3F, 0x3F
    mov al, 0xFF
    call .placeRow
    hlcoord 1, 5
    lb dx, 0x3F, 0x3F
    mov al, 0xFF
    call .placeRow
    hlcoord 1, 6
    lb dx, 0x3F, 0x3F
    mov al, 0xFF
    call .placeRow
    hlcoord 1, 7
    lb dx, 0x3F, 0x3F
    mov al, 0xFF
    call .placeRow
    hlcoord 1, 8
    lb dx, 0x3F, 0x3F
    mov al, 0xFF
    call .placeRow
    hlcoord 1, 9
    lb dx, 0x3D, 0x3E
    mov al, 0x40
    call .placeRow
    ret

.placeRow:
    mov [ebp + esi], dh
    inc esi
    mov cl, 16                                 ; pret: SCREEN_WIDTH - 4 (box interior width, 8-bit counter)
.loop:
    mov [ebp + esi], al
    inc esi
    dec cl
    jnz .loop
    mov [ebp + esi], dl
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_PrintTextHiScore
; ---------------------------------------------------------------------------
SurfingMinigame_PrintTextHiScore:
    mov esi, .Hi_Score
    sub esi, ebp
    decoord 6, 8
    mov bx, .Hi_ScoreEnd - .Hi_Score
    call CopyData
    ret

.Hi_Score:
    db 0x20, 0x2E, 0x2F, 0x30, 0x31, 0x2C, 0x32, 0x23, 0x33 ; Hi-Score!!
.Hi_ScoreEnd:

; ---------------------------------------------------------------------------
; SurfingMinigame_WriteHPLeft
; ---------------------------------------------------------------------------
SurfingMinigame_WriteHPLeft:
    mov esi, .HP_Left
    sub esi, ebp
    decoord 2, 2
    mov bx, .HP_LeftEnd - .HP_Left
    call CopyData
    call SurfingMinigame_BCDPrintHPLeft
    ret

.HP_Left:
    db 0x20, 0x21, 0xFF, 0x22, 0x23, 0x24, 0x25 ; HP Left
.HP_LeftEnd:

; ---------------------------------------------------------------------------
; SurfingMinigame_AddRemainingHPToTotal
; ---------------------------------------------------------------------------
SurfingMinigame_AddRemainingHPToTotal:
    mov cl, 99                                 ; 8-bit counter
.loop:
    push ecx
    mov esi, wSurfingMinigamePikachuHP
    mov al, [ebp + esi]
    inc esi
    or al, [ebp + esi]
    test al, al
    jz .dead
    call SurfingMinigame_Deduct1HP
    mov dl, 1
    call SurfingMinigame_AddPointsToTotal
    pop ecx
    dec cl
    jnz .loop
    mov al, SFX_PRESS_AB
    call PlaySound
    clc
    ret

.dead:
    pop ecx
    stc
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_BCDPrintHPLeft
; ---------------------------------------------------------------------------
SurfingMinigame_BCDPrintHPLeft:
    hlcoord 10, 2
    mov edx, wSurfingMinigamePikachuHP + 1
    mov al, [ebp + edx]
    call SurfingPikachu_PlaceBCDNumber
    inc esi
    mov al, [ebp + edx]
    call SurfingPikachu_PlaceBCDNumber
    inc esi
    inc esi
    mov byte [ebp + esi], 0x21                 ; P
    inc esi
    mov byte [ebp + esi], 0x25                 ; t
    inc esi
    mov byte [ebp + esi], 0x26                 ; s
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_WriteRadness
; ---------------------------------------------------------------------------
SurfingMinigame_WriteRadness:
    mov esi, .Radness
    sub esi, ebp
    decoord 2, 4
    mov bx, .RadnessEnd - .Radness
    call CopyData
    call SurfingMinigame_BCDPrintRadness
    ret

.Radness:
    db 0x27, 0x28, 0x29, 0x2A, 0x23, 0x26, 0x26 ; Radness
.RadnessEnd:

; ---------------------------------------------------------------------------
; SurfingMinigame_AddRadnessToTotal
; ---------------------------------------------------------------------------
SurfingMinigame_AddRadnessToTotal:
    mov cl, 99                                 ; 8-bit counter
.loop:
    push ecx
    mov esi, wSurfingMinigameRadnessScore
    mov al, [ebp + esi]
    inc esi
    mov dl, al
    or al, [ebp + esi]
    jz .done
    mov dh, [ebp + esi]
    mov al, dl
    sub al, 1
    das
    mov dl, al
    mov al, dh
    sbb al, 0
    das
    mov [ebp + esi], al
    dec esi
    mov [ebp + esi], dl
    mov dl, 1
    call SurfingMinigame_AddPointsToTotal
    pop ecx
    dec cl
    jnz .loop
    mov al, SFX_PRESS_AB
    call PlaySound
    clc
    ret

.done:
    pop ecx
    stc
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_BCDPrintRadness
; ---------------------------------------------------------------------------
SurfingMinigame_BCDPrintRadness:
    mov al, [ebp + wSurfingMinigameRadnessScore + 1]
    hlcoord 10, 4
    call SurfingPikachu_PlaceBCDNumber
    mov al, [ebp + wSurfingMinigameRadnessScore]
    hlcoord 12, 4
    call SurfingPikachu_PlaceBCDNumber
    inc esi
    inc esi
    mov byte [ebp + esi], 0x21                 ; P
    inc esi
    mov byte [ebp + esi], 0x25                 ; t
    inc esi
    mov byte [ebp + esi], 0x26                 ; s
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_AddPointsToTotal
; ---------------------------------------------------------------------------
SurfingMinigame_AddPointsToTotal:
    mov al, [ebp + wSurfingMinigameTotalScore]
    add al, dl
    daa
    mov [ebp + wSurfingMinigameTotalScore], al
    mov al, [ebp + wSurfingMinigameTotalScore + 1]
    adc al, 0
    daa
    mov [ebp + wSurfingMinigameTotalScore + 1], al
    jnc .ret
    mov byte [ebp + wSurfingMinigameTotalScore], 0x99
    mov byte [ebp + wSurfingMinigameTotalScore + 1], 0x99
.ret:
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_BCDPrintTotalScore
; ---------------------------------------------------------------------------
SurfingMinigame_BCDPrintTotalScore:
    mov al, [ebp + wSurfingMinigameTotalScore + 1]
    hlcoord 10, 6
    call SurfingPikachu_PlaceBCDNumber
    mov al, [ebp + wSurfingMinigameTotalScore]
    hlcoord 12, 6
    call SurfingPikachu_PlaceBCDNumber
    inc esi
    inc esi
    mov byte [ebp + esi], 0x21                 ; P
    inc esi
    mov byte [ebp + esi], 0x25                 ; t
    inc esi
    mov byte [ebp + esi], 0x26                 ; s
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_WriteTotal
; ---------------------------------------------------------------------------
SurfingMinigame_WriteTotal:
    mov esi, .Total
    sub esi, ebp
    decoord 2, 6
    mov bx, .TotalEnd - .Total
    call CopyData
    call SurfingMinigame_BCDPrintRadness
    call SurfingMinigame_BCDPrintTotalScore
    ret

.Total:
    db 0x2B, 0x2C, 0x25, 0x28, 0x2D            ; Total
.TotalEnd:

; ---------------------------------------------------------------------------
; DidPlayerGetAHighScore
; ---------------------------------------------------------------------------
DidPlayerGetAHighScore:
    mov esi, wSurfingMinigameHiScore + 1
    mov al, [ebp + wSurfingMinigameTotalScore + 1]
    cmp al, [ebp + esi]
    jb .notHighScore
    jnz .highScore
    dec esi
    mov al, [ebp + wSurfingMinigameTotalScore]
    cmp al, [ebp + esi]
    jb .notHighScore
    jnz .highScore
.notHighScore:
    call WaitForSoundToFinish
    mov dl, PIKACRY_28                         ; ldpikacry e, PikachuCry28
    call SurfingMinigame_PlayPikaCryIfSurfingPikaInParty
    clc
    ret

.highScore:
    mov al, [ebp + wSurfingMinigameTotalScore]
    mov [ebp + wSurfingMinigameHiScore], al
    mov al, [ebp + wSurfingMinigameTotalScore + 1]
    mov [ebp + wSurfingMinigameHiScore + 1], al
    call WaitForSoundToFinish
    mov dl, PIKACRY_34                         ; ldpikacry e, PikachuCry34
    call SurfingMinigame_PlayPikaCryIfSurfingPikaInParty
    mov al, SFX_GET_ITEM2_4_2
    call PlaySound
    stc
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_PlayPikaCryIfSurfingPikaInParty
; ---------------------------------------------------------------------------
SurfingMinigame_PlayPikaCryIfSurfingPikaInParty:
    push edx
    call IsSurfingStarterPikachuInParty
    pop edx
    jnc .ret
    call PlayPikachuSoundClip
.ret:
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_IncreaseRadnessMeter
; ---------------------------------------------------------------------------
SurfingMinigame_IncreaseRadnessMeter:
    mov al, [ebp + wSurfingMinigameRadnessMeter]
    inc al
    cmp al, 4
    jb .cap
    mov al, 3
.cap:
    mov [ebp + wSurfingMinigameRadnessMeter], al
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_CalculateAndAddRadnessFromStunt
; ---------------------------------------------------------------------------
SurfingMinigame_CalculateAndAddRadnessFromStunt:
    mov al, [ebp + wSurfingMinigameRadnessMeter]
    test al, al
    jz .ret
    mov al, [ebp + wSurfingMinigameTrickFlags]
    and al, 3
    cmp al, 3                                  ; mixed combination
    jz .mixedChain
    mov dh, [ebp + wSurfingMinigameRadnessMeter] ; D = count
    mov dl, 1                                  ; E = 1
    xor al, al                                 ; A = 0
.getAmountOfRadness:
    add al, dl
    shl dl, 1
    dec dh
    jnz .getAmountOfRadness
.addRadness50AtATime:
    push eax
    mov dl, 0x50
    call SurfingMinigame_AddRadness
    pop eax
    dec al
    jnz .addRadness50AtATime
    mov al, [ebp + ebx + ANIM_OBJ_Y_COORD]
    sub al, 0x10
    mov dh, al                                 ; DH = Y
    mov dl, [ebp + ebx + ANIM_OBJ_X_COORD]     ; DL = X
    mov al, [ebp + wSurfingMinigameRadnessMeter]
    add al, 3
    push ebx
    call SpawnAnimatedObject
    pop ebx
    ret

.mixedChain:
    mov al, [ebp + wSurfingMinigameRadnessMeter]
    cmp al, 3
    jb .add180RadnessPoints
    mov al, 10
.add500Radness50AtATime:
    push eax
    mov dl, 0x50
    call SurfingMinigame_AddRadness
    pop eax
    dec al
    jnz .add500Radness50AtATime
    mov al, [ebp + ebx + ANIM_OBJ_Y_COORD]
    sub al, 0x10
    mov dh, al
    mov dl, [ebp + ebx + ANIM_OBJ_X_COORD]
    mov al, 9
    push ebx
    call SpawnAnimatedObject
    pop ebx
    ret

.add180RadnessPoints:
    mov dl, 0x50
    call SurfingMinigame_AddRadness
    mov dl, 0x50
    call SurfingMinigame_AddRadness
    mov dl, 0x50
    call SurfingMinigame_AddRadness
    mov dl, 0x30
    call SurfingMinigame_AddRadness
    mov al, [ebp + ebx + ANIM_OBJ_Y_COORD]
    sub al, 0x10
    mov dh, al
    mov dl, [ebp + ebx + ANIM_OBJ_X_COORD]
    mov al, 8
    push ebx
    call SpawnAnimatedObject
    pop ebx
.ret:
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_AddRadness
; ---------------------------------------------------------------------------
SurfingMinigame_AddRadness:
    mov al, [ebp + wSurfingMinigameRadnessScore]
    add al, dl
    daa
    mov [ebp + wSurfingMinigameRadnessScore], al
    mov al, [ebp + wSurfingMinigameRadnessScore + 1]
    adc al, 0
    daa
    mov [ebp + wSurfingMinigameRadnessScore + 1], al
    jnc .ret
    mov byte [ebp + wSurfingMinigameRadnessScore], 0x99
    mov byte [ebp + wSurfingMinigameRadnessScore + 1], 0x99
.ret:
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_CoastAfterGoal
; ---------------------------------------------------------------------------
SurfingMinigame_CoastAfterGoal:
    mov byte [ebp + wSurfingMinigameXOffset], 0xA0
    mov ah, [ebp + hSCX]
    mov al, [ebp + wSurfingMinigameSCX]
    add ax, 0x0900                             ; 9.0 pixels per frame
    mov [ebp + wSurfingMinigameSCX], al
    mov [ebp + hSCX], ah
    jmp SurfingMinigame_GenerateBGMap

; ---------------------------------------------------------------------------
; SurfingMinigame_ScrollAndGenerateBGMap
; ---------------------------------------------------------------------------
SurfingMinigame_ScrollAndGenerateBGMap:
    mov byte [ebp + wSurfingMinigameXOffset], 0xA0
    mov ah, [ebp + hSCX]
    mov al, [ebp + wSurfingMinigameSCX]
    add ax, 0x0180                             ; 1.5 pixels per frame
    mov [ebp + wSurfingMinigameSCX], al
    mov [ebp + hSCX], ah
SurfingMinigame_GenerateBGMap:
    mov esi, wSurfingMinigameSCX2
    mov al, [ebp + hSCX]
    cmp al, [ebp + esi]
    jz .ret
    mov [ebp + esi], al
    and al, 0xF0
    mov esi, wSurfingMinigameSCXHi
    cmp al, [ebp + esi]
    jz .ret
    mov [ebp + esi], al
    call SurfingMinigame_GetWaveDataPointers
    mov [ebp + wSurfingMinigameWaveHeightBuffer], bh
    mov [ebp + wSurfingMinigameWaveHeightBuffer + 1], bl
    push edx
    mov esi, wSurfingMinigameWaveHeight
    mov edx, wSurfingMinigameWaveHeight + 2
    mov cl, 18                                 ; SCREEN_WIDTH - 2 (8-bit counter)
.copyLoop:
    mov al, [ebp + edx]
    inc edx
    mov [ebp + esi], al
    inc esi
    dec cl
    jnz .copyLoop
    mov al, [ebp + wSurfingMinigameWaveHeightBuffer]
    mov [ebp + esi], al
    inc esi
    mov al, [ebp + wSurfingMinigameWaveHeightBuffer + 1]
    mov [ebp + esi], al
    pop edx
    mov esi, wRedrawRowOrColumnSrcTiles
    mov cl, 8                                  ; 8 metatiles (SurfingMinigameWavePattern01 - SurfingMinigameWavePattern00)
.loop:
    mov al, [edx]
    call .CopyRedrawSrcTiles
    inc edx
    dec cl
    jnz .loop
    mov al, [ebp + wSurfingMinigameXOffset]
    add al, [ebp + hSCX]
    and al, 0xF0
    shr al, 3
    movzx edx, al
    mov esi, vBGMap0
    add esi, edx
    mov ax, si
    mov [ebp + hRedrawRowOrColumnDest], al
    mov [ebp + hRedrawRowOrColumnDest + 1], ah
    mov byte [ebp + hRedrawRowOrColumnMode], 1
.ret:
    ret

.CopyRedrawSrcTiles:
    push edx
    push esi
    movzx edx, al
    lea edx, [SurfingMinigame_BGMetatileTable + edx*4]
    pop esi
    mov al, [edx]
    mov [ebp + esi], al
    inc esi
    mov al, [edx + 1]
    mov [ebp + esi], al
    inc esi
    mov al, [edx + 2]
    mov [ebp + esi], al
    inc esi
    mov al, [edx + 3]
    mov [ebp + esi], al
    inc esi
    pop edx
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_GetWaveDataPointers
; ---------------------------------------------------------------------------
SurfingMinigame_GetWaveDataPointers:
    movzx edx, byte [ebp + wSurfingMinigameWaveFunctionNumber]
    jmp [.WaveFunctions + edx*4]

.WaveFunctions:
    ; Each state selects the next 8-metatile slice of a wave sequence.
    dd SurfingMinigame_ChooseNextWaveSequence ; 00

    dd SurfingMinigame_LoadWavePattern13AndAdvance ; 01
    dd SurfingMinigame_LoadWavePattern14AndAdvance ; 02
    dd SurfingMinigame_LoadWavePattern15AndAdvance ; 03
    dd SurfingMinigame_LoadWavePattern16AndAdvance ; 04
    dd SurfingMinigame_LoadWavePattern00AndAdvance ; 05
    dd SurfingMinigame_LoadWavePattern17AndAdvance ; 06
    dd SurfingMinigame_LoadWavePattern18AndAdvance ; 07
    dd SurfingMinigame_LoadWavePattern19AndAdvance ; 08
    dd SurfingMinigame_LoadWavePattern00AndAdvance ; 09
    dd SurfingMinigame_LoadWavePattern00AndAdvance ; 0a
    dd SurfingMinigame_LoadWavePattern00AndAdvance ; 0b
    dd SurfingMinigame_LoadWavePattern00AndAdvance ; 0c
    dd SurfingMinigame_LoadFlatWaveAndReset ; 0d

    dd SurfingMinigame_LoadWavePattern08AndAdvance ; 0e
    dd SurfingMinigame_LoadWavePattern09AndAdvance ; 0f
    dd SurfingMinigame_LoadWavePattern0AAndAdvance ; 10
    dd SurfingMinigame_LoadWavePattern0BAndAdvance ; 11
    dd SurfingMinigame_LoadWavePattern0CAndAdvance ; 12
    dd SurfingMinigame_LoadWavePattern0DAndAdvance ; 13
    dd SurfingMinigame_LoadWavePattern00AndAdvance ; 14
    dd SurfingMinigame_LoadWavePattern00AndAdvance ; 15
    dd SurfingMinigame_LoadWavePattern00AndAdvance ; 16
    dd SurfingMinigame_LoadWavePattern00AndAdvance ; 17
    dd SurfingMinigame_LoadWavePattern00AndAdvance ; 18
    dd SurfingMinigame_LoadFlatWaveAndReset ; 19

    dd SurfingMinigame_LoadWavePattern0EAndAdvance ; 1a
    dd SurfingMinigame_LoadWavePattern0FAndAdvance ; 1b
    dd SurfingMinigame_LoadWavePattern10AndAdvance ; 1c
    dd SurfingMinigame_LoadWavePattern11AndAdvance ; 1d
    dd SurfingMinigame_LoadWavePattern12AndAdvance ; 1e
    dd SurfingMinigame_LoadWavePattern0EAndAdvance ; 1f
    dd SurfingMinigame_LoadWavePattern0FAndAdvance ; 20
    dd SurfingMinigame_LoadWavePattern10AndAdvance ; 21
    dd SurfingMinigame_LoadWavePattern11AndAdvance ; 22
    dd SurfingMinigame_LoadWavePattern12AndAdvance ; 23
    dd SurfingMinigame_LoadWavePattern00AndAdvance ; 24
    dd SurfingMinigame_LoadWavePattern00AndAdvance ; 25
    dd SurfingMinigame_LoadWavePattern00AndAdvance ; 26
    dd SurfingMinigame_LoadWavePattern00AndAdvance ; 27
    dd SurfingMinigame_LoadFlatWaveAndReset ; 28

    dd SurfingMinigame_LoadWavePattern13AndAdvance ; 29
    dd SurfingMinigame_LoadWavePattern14AndAdvance ; 2a
    dd SurfingMinigame_LoadWavePattern15AndAdvance ; 2b
    dd SurfingMinigame_LoadWavePattern16AndAdvance ; 2c
    dd SurfingMinigame_LoadWavePattern00AndAdvance ; 2d
    dd SurfingMinigame_LoadWavePattern00AndAdvance ; 2e
    dd SurfingMinigame_LoadWavePattern00AndAdvance ; 2f
    dd SurfingMinigame_LoadWavePattern00AndAdvance ; 30
    dd SurfingMinigame_LoadFlatWaveAndReset ; 31

    dd SurfingMinigame_LoadWavePattern17AndAdvance ; 32
    dd SurfingMinigame_LoadWavePattern18AndAdvance ; 33
    dd SurfingMinigame_LoadWavePattern19AndAdvance ; 34
    dd SurfingMinigame_LoadWavePattern17AndAdvance ; 35
    dd SurfingMinigame_LoadWavePattern18AndAdvance ; 36
    dd SurfingMinigame_LoadWavePattern19AndAdvance ; 37
    dd SurfingMinigame_LoadWavePattern17AndAdvance ; 38
    dd SurfingMinigame_LoadWavePattern18AndAdvance ; 39
    dd SurfingMinigame_LoadWavePattern19AndAdvance ; 3a
    dd SurfingMinigame_LoadWavePattern00AndAdvance ; 3b
    dd SurfingMinigame_LoadWavePattern00AndAdvance ; 3c
    dd SurfingMinigame_LoadWavePattern00AndAdvance ; 3d
    dd SurfingMinigame_LoadWavePattern00AndAdvance ; 3e
    dd SurfingMinigame_LoadFlatWaveAndReset ; 3f

    dd SurfingMinigame_LoadWavePattern1AAndAdvance ; 40
    dd SurfingMinigame_LoadWavePattern1BAndAdvance ; 41
    dd SurfingMinigame_LoadWavePattern0EAndAdvance ; 42
    dd SurfingMinigame_LoadWavePattern0FAndAdvance ; 43
    dd SurfingMinigame_LoadWavePattern10AndAdvance ; 44
    dd SurfingMinigame_LoadWavePattern11AndAdvance ; 45
    dd SurfingMinigame_LoadWavePattern12AndAdvance ; 46
    dd SurfingMinigame_LoadWavePattern1AAndAdvance ; 47
    dd SurfingMinigame_LoadWavePattern1BAndAdvance ; 48
    dd SurfingMinigame_LoadWavePattern00AndAdvance ; 49
    dd SurfingMinigame_LoadWavePattern00AndAdvance ; 4a
    dd SurfingMinigame_LoadWavePattern00AndAdvance ; 4b
    dd SurfingMinigame_LoadFlatWaveAndReset ; 4c

    dd SurfingMinigame_LoadWavePattern08AndAdvance ; 4d
    dd SurfingMinigame_LoadWavePattern09AndAdvance ; 4e
    dd SurfingMinigame_LoadWavePattern0AAndAdvance ; 4f
    dd SurfingMinigame_LoadWavePattern0BAndAdvance ; 50
    dd SurfingMinigame_LoadWavePattern0CAndAdvance ; 51
    dd SurfingMinigame_LoadWavePattern0DAndAdvance ; 52
    dd SurfingMinigame_LoadWavePattern00AndAdvance ; 53
    dd SurfingMinigame_LoadWavePattern1AAndAdvance ; 54
    dd SurfingMinigame_LoadWavePattern1BAndAdvance ; 55
    dd SurfingMinigame_LoadWavePattern1AAndAdvance ; 56
    dd SurfingMinigame_LoadWavePattern1BAndAdvance ; 57
    dd SurfingMinigame_LoadWavePattern00AndAdvance ; 58
    dd SurfingMinigame_LoadWavePattern00AndAdvance ; 59
    dd SurfingMinigame_LoadWavePattern00AndAdvance ; 5a
    dd SurfingMinigame_LoadFlatWaveAndReset ; 5b

    dd SurfingMinigame_LoadWavePattern0EAndAdvance ; 5c
    dd SurfingMinigame_LoadWavePattern0FAndAdvance ; 5d
    dd SurfingMinigame_LoadWavePattern10AndAdvance ; 5e
    dd SurfingMinigame_LoadWavePattern11AndAdvance ; 5f
    dd SurfingMinigame_LoadWavePattern12AndAdvance ; 60
    dd SurfingMinigame_LoadWavePattern13AndAdvance ; 61
    dd SurfingMinigame_LoadWavePattern14AndAdvance ; 62
    dd SurfingMinigame_LoadWavePattern15AndAdvance ; 63
    dd SurfingMinigame_LoadWavePattern16AndAdvance ; 64
    dd SurfingMinigame_LoadWavePattern00AndAdvance ; 65
    dd SurfingMinigame_LoadWavePattern00AndAdvance ; 66
    dd SurfingMinigame_LoadWavePattern00AndAdvance ; 67
    dd SurfingMinigame_LoadWavePattern00AndAdvance ; 68
    dd SurfingMinigame_LoadFlatWaveAndReset ; 69

    dd SurfingMinigame_LoadWavePattern01AndAdvance ; 6a
    dd SurfingMinigame_LoadWavePattern02AndAdvance ; 6b
    dd SurfingMinigame_LoadWavePattern03AndAdvance ; 6c
    dd SurfingMinigame_LoadWavePattern04AndAdvance ; 6d
    dd SurfingMinigame_LoadWavePattern05AndAdvance ; 6e
    dd SurfingMinigame_LoadWavePattern06AndAdvance ; 6f
    dd SurfingMinigame_LoadWavePattern07AndAdvance ; 70
    dd SurfingMinigame_LoadFlatWave ; 71

    dd SurfingMinigame_LoadWavePattern00AndAdvance ; 72
    dd SurfingMinigame_LoadWavePattern1CAndAdvance ; 73
    dd SurfingMinigame_LoadBeachPatternAndAdvance ; 74
    dd SurfingMinigame_LoadBeachPatternAndAdvance ; 75
    dd SurfingMinigame_LoadBeachPatternAndAdvance ; 76
    dd SurfingMinigame_LoadBeachPatternAndAdvance ; 77
    dd SurfingMinigame_LoadBeachPatternAndAdvance ; 78
    dd SurfingMinigame_LoadBeachPatternAndAdvance ; 79
    dd SurfingMinigame_LoadBeachPatternAndAdvance ; 7a
    dd SurfingMinigame_LoadBeachPatternAndReset ; 7b

; ---------------------------------------------------------------------------
; SurfingMinigame_ChooseNextWaveSequence
; ---------------------------------------------------------------------------
SurfingMinigame_ChooseNextWaveSequence:
    mov al, [ebp + wSurfingMinigameDistance]
    cmp al, 0x16                               ; force final "Big Kahuna" at section 22
    jb .checkParam
    jz .bigKahuna
    ja .gotWave
.bigKahuna:
    mov al, 0x6A
    jmp .gotNextFn

.checkParam:
    mov al, [ebp + wSurfingMinigameWaveRandomValue]
    test al, al
    jz .gotWave
    dec al
    and al, 7
    movzx edx, al
    mov al, [SurfingMinigame_WaveSequenceStarts + edx]
.gotNextFn:
    mov [ebp + wSurfingMinigameWaveFunctionNumber], al
.gotWave:
    lb bx, SURFING_MINIGAME_FLAT_WATER_Y, SURFING_MINIGAME_FLAT_WATER_Y
    mov edx, SurfingMinigameWavePattern00
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_WaveSequenceStarts
; ---------------------------------------------------------------------------
SurfingMinigame_WaveSequenceStarts:
    db 0x01, 0x0E, 0x1A, 0x29, 0x32, 0x40, 0x4D, 0x5C

; ---------------------------------------------------------------------------
; Wave pattern loading routines
; ---------------------------------------------------------------------------
SurfingMinigame_LoadWavePattern00AndAdvance:
    lb bx, SURFING_MINIGAME_FLAT_WATER_Y, SURFING_MINIGAME_FLAT_WATER_Y
    mov edx, SurfingMinigameWavePattern00
    jmp SurfingMinigame_AdvanceWaveFunction

SurfingMinigame_LoadWavePattern01AndAdvance:
    lb bx, SURFING_MINIGAME_FLAT_WATER_Y, SURFING_MINIGAME_FLAT_WATER_Y - 1 * TILE_HEIGHT
    mov edx, SurfingMinigameWavePattern01
    jmp SurfingMinigame_AdvanceWaveFunction

SurfingMinigame_LoadWavePattern02AndAdvance:
    lb bx, SURFING_MINIGAME_FLAT_WATER_Y - 2 * TILE_HEIGHT, SURFING_MINIGAME_FLAT_WATER_Y - 3 * TILE_HEIGHT
    mov edx, SurfingMinigameWavePattern02
    jmp SurfingMinigame_AdvanceWaveFunction

SurfingMinigame_LoadWavePattern03AndAdvance:
    lb bx, SURFING_MINIGAME_FLAT_WATER_Y - 4 * TILE_HEIGHT, SURFING_MINIGAME_FLAT_WATER_Y - 5 * TILE_HEIGHT
    mov edx, SurfingMinigameWavePattern03
    jmp SurfingMinigame_AdvanceWaveFunction

SurfingMinigame_LoadWavePattern04AndAdvance:
    lb bx, SURFING_MINIGAME_FLAT_WATER_Y - 6 * TILE_HEIGHT, SURFING_MINIGAME_FLAT_WATER_Y - 6 * TILE_HEIGHT
    mov edx, SurfingMinigameWavePattern04
    jmp SurfingMinigame_AdvanceWaveFunction

SurfingMinigame_LoadWavePattern05AndAdvance:
    lb bx, SURFING_MINIGAME_FLAT_WATER_Y - 6 * TILE_HEIGHT, SURFING_MINIGAME_FLAT_WATER_Y - 5 * TILE_HEIGHT
    mov edx, SurfingMinigameWavePattern05
    jmp SurfingMinigame_AdvanceWaveFunction

SurfingMinigame_LoadWavePattern06AndAdvance:
    lb bx, SURFING_MINIGAME_FLAT_WATER_Y - 4 * TILE_HEIGHT, SURFING_MINIGAME_FLAT_WATER_Y - 3 * TILE_HEIGHT
    mov edx, SurfingMinigameWavePattern06
    jmp SurfingMinigame_AdvanceWaveFunction

SurfingMinigame_LoadWavePattern07AndAdvance:
    lb bx, SURFING_MINIGAME_FLAT_WATER_Y - 2 * TILE_HEIGHT, SURFING_MINIGAME_FLAT_WATER_Y - 1 * TILE_HEIGHT
    mov edx, SurfingMinigameWavePattern07
    jmp SurfingMinigame_AdvanceWaveFunction

SurfingMinigame_LoadWavePattern08AndAdvance:
    lb bx, SURFING_MINIGAME_FLAT_WATER_Y, SURFING_MINIGAME_FLAT_WATER_Y - 1 * TILE_HEIGHT
    mov edx, SurfingMinigameWavePattern08
    jmp SurfingMinigame_AdvanceWaveFunction

SurfingMinigame_LoadWavePattern09AndAdvance:
    lb bx, SURFING_MINIGAME_FLAT_WATER_Y - 2 * TILE_HEIGHT, SURFING_MINIGAME_FLAT_WATER_Y - 3 * TILE_HEIGHT
    mov edx, SurfingMinigameWavePattern09
    jmp SurfingMinigame_AdvanceWaveFunction

SurfingMinigame_LoadWavePattern0AAndAdvance:
    lb bx, SURFING_MINIGAME_FLAT_WATER_Y - 4 * TILE_HEIGHT, SURFING_MINIGAME_FLAT_WATER_Y - 5 * TILE_HEIGHT
    mov edx, SurfingMinigameWavePattern0A
    jmp SurfingMinigame_AdvanceWaveFunction

SurfingMinigame_LoadWavePattern0BAndAdvance:
    lb bx, SURFING_MINIGAME_FLAT_WATER_Y - 5 * TILE_HEIGHT, SURFING_MINIGAME_FLAT_WATER_Y - 5 * TILE_HEIGHT
    mov edx, SurfingMinigameWavePattern0B
    jmp SurfingMinigame_AdvanceWaveFunction

SurfingMinigame_LoadWavePattern0CAndAdvance:
    lb bx, SURFING_MINIGAME_FLAT_WATER_Y - 4 * TILE_HEIGHT, SURFING_MINIGAME_FLAT_WATER_Y - 3 * TILE_HEIGHT
    mov edx, SurfingMinigameWavePattern0C
    jmp SurfingMinigame_AdvanceWaveFunction

SurfingMinigame_LoadWavePattern0DAndAdvance:
    lb bx, SURFING_MINIGAME_FLAT_WATER_Y - 2 * TILE_HEIGHT, SURFING_MINIGAME_FLAT_WATER_Y - 1 * TILE_HEIGHT
    mov edx, SurfingMinigameWavePattern0D
    jmp SurfingMinigame_AdvanceWaveFunction

SurfingMinigame_LoadWavePattern0EAndAdvance:
    lb bx, SURFING_MINIGAME_FLAT_WATER_Y, SURFING_MINIGAME_FLAT_WATER_Y - 1 * TILE_HEIGHT
    mov edx, SurfingMinigameWavePattern0E
    jmp SurfingMinigame_AdvanceWaveFunction

SurfingMinigame_LoadWavePattern0FAndAdvance:
    lb bx, SURFING_MINIGAME_FLAT_WATER_Y - 2 * TILE_HEIGHT, SURFING_MINIGAME_FLAT_WATER_Y - 3 * TILE_HEIGHT
    mov edx, SurfingMinigameWavePattern0F
    jmp SurfingMinigame_AdvanceWaveFunction

SurfingMinigame_LoadWavePattern10AndAdvance:
    lb bx, SURFING_MINIGAME_FLAT_WATER_Y - 4 * TILE_HEIGHT, SURFING_MINIGAME_FLAT_WATER_Y - 4 * TILE_HEIGHT
    mov edx, SurfingMinigameWavePattern10
    jmp SurfingMinigame_AdvanceWaveFunction

SurfingMinigame_LoadWavePattern11AndAdvance:
    lb bx, SURFING_MINIGAME_FLAT_WATER_Y - 4 * TILE_HEIGHT, SURFING_MINIGAME_FLAT_WATER_Y - 3 * TILE_HEIGHT
    mov edx, SurfingMinigameWavePattern11
    jmp SurfingMinigame_AdvanceWaveFunction

SurfingMinigame_LoadWavePattern12AndAdvance:
    lb bx, SURFING_MINIGAME_FLAT_WATER_Y - 2 * TILE_HEIGHT, SURFING_MINIGAME_FLAT_WATER_Y - 1 * TILE_HEIGHT
    mov edx, SurfingMinigameWavePattern12
    jmp SurfingMinigame_AdvanceWaveFunction

SurfingMinigame_LoadWavePattern13AndAdvance:
    lb bx, SURFING_MINIGAME_FLAT_WATER_Y, SURFING_MINIGAME_FLAT_WATER_Y - 1 * TILE_HEIGHT
    mov edx, SurfingMinigameWavePattern13
    jmp SurfingMinigame_AdvanceWaveFunction

SurfingMinigame_LoadWavePattern14AndAdvance:
    lb bx, SURFING_MINIGAME_FLAT_WATER_Y - 2 * TILE_HEIGHT, SURFING_MINIGAME_FLAT_WATER_Y - 3 * TILE_HEIGHT
    mov edx, SurfingMinigameWavePattern14
    jmp SurfingMinigame_AdvanceWaveFunction

SurfingMinigame_LoadWavePattern15AndAdvance:
    lb bx, SURFING_MINIGAME_FLAT_WATER_Y - 3 * TILE_HEIGHT, SURFING_MINIGAME_FLAT_WATER_Y - 3 * TILE_HEIGHT
    mov edx, SurfingMinigameWavePattern15
    jmp SurfingMinigame_AdvanceWaveFunction

SurfingMinigame_LoadWavePattern16AndAdvance:
    lb bx, SURFING_MINIGAME_FLAT_WATER_Y - 2 * TILE_HEIGHT, SURFING_MINIGAME_FLAT_WATER_Y - 1 * TILE_HEIGHT
    mov edx, SurfingMinigameWavePattern16
    jmp SurfingMinigame_AdvanceWaveFunction

SurfingMinigame_LoadWavePattern17AndAdvance:
    lb bx, SURFING_MINIGAME_FLAT_WATER_Y, SURFING_MINIGAME_FLAT_WATER_Y - 1 * TILE_HEIGHT
    mov edx, SurfingMinigameWavePattern17
    jmp SurfingMinigame_AdvanceWaveFunction

SurfingMinigame_LoadWavePattern18AndAdvance:
    lb bx, SURFING_MINIGAME_FLAT_WATER_Y - 2 * TILE_HEIGHT, SURFING_MINIGAME_FLAT_WATER_Y - 2 * TILE_HEIGHT
    mov edx, SurfingMinigameWavePattern18
    jmp SurfingMinigame_AdvanceWaveFunction

SurfingMinigame_LoadWavePattern19AndAdvance:
    lb bx, SURFING_MINIGAME_FLAT_WATER_Y - 2 * TILE_HEIGHT, SURFING_MINIGAME_FLAT_WATER_Y - 1 * TILE_HEIGHT
    mov edx, SurfingMinigameWavePattern19
    jmp SurfingMinigame_AdvanceWaveFunction

SurfingMinigame_LoadWavePattern1AAndAdvance:
    lb bx, SURFING_MINIGAME_FLAT_WATER_Y, SURFING_MINIGAME_FLAT_WATER_Y - 1 * TILE_HEIGHT
    mov edx, SurfingMinigameWavePattern1A
    jmp SurfingMinigame_AdvanceWaveFunction

SurfingMinigame_LoadWavePattern1BAndAdvance:
    lb bx, SURFING_MINIGAME_FLAT_WATER_Y - 1 * TILE_HEIGHT, SURFING_MINIGAME_FLAT_WATER_Y - 1 * TILE_HEIGHT
    mov edx, SurfingMinigameWavePattern1B
    jmp SurfingMinigame_AdvanceWaveFunction

SurfingMinigame_LoadWavePattern1CAndAdvance:
    lb bx, SURFING_MINIGAME_FLAT_WATER_Y, SURFING_MINIGAME_FLAT_WATER_Y
    mov edx, SurfingMinigameWavePattern1C
    jmp SurfingMinigame_AdvanceWaveFunction

SurfingMinigame_LoadBeachPatternAndAdvance:
    lb bx, SURFING_MINIGAME_FLAT_WATER_Y, SURFING_MINIGAME_FLAT_WATER_Y
    mov edx, SurfingMinigameBeachPattern
    jmp SurfingMinigame_AdvanceWaveFunction

SurfingMinigame_LoadBeachPatternAndReset:
    lb bx, SURFING_MINIGAME_FLAT_WATER_Y, SURFING_MINIGAME_FLAT_WATER_Y
    mov edx, SurfingMinigameBeachPattern
    jmp SurfingMinigame_ResetWaveSequence

SurfingMinigame_LoadFlatWaveAndReset:
    lb bx, SURFING_MINIGAME_FLAT_WATER_Y, SURFING_MINIGAME_FLAT_WATER_Y
    mov edx, SurfingMinigameWavePattern00
    jmp SurfingMinigame_ResetWaveSequence

SurfingMinigame_LoadFlatWave:
    lb bx, SURFING_MINIGAME_FLAT_WATER_Y, SURFING_MINIGAME_FLAT_WATER_Y
    mov edx, SurfingMinigameWavePattern00
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_AdvanceWaveFunctionFromA (unused in pret)
; ---------------------------------------------------------------------------
SurfingMinigame_AdvanceWaveFunctionFromA:
    inc al
    mov [ebp + wSurfingMinigameWaveFunctionNumber], al
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_AdvanceWaveFunction
; ---------------------------------------------------------------------------
SurfingMinigame_AdvanceWaveFunction:
    inc byte [ebp + wSurfingMinigameWaveFunctionNumber]
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_ResetWaveSequence
; ---------------------------------------------------------------------------
SurfingMinigame_ResetWaveSequence:
    xor al, al
    mov [ebp + wSurfingMinigameWaveFunctionNumber], al
    ret

; ---------------------------------------------------------------------------
; SurfingPikachuMinigameIntro
; ---------------------------------------------------------------------------
SurfingPikachuMinigameIntro:
    call SurfingPikachu_ClearTileMap
    call ClearSprites
    call DisableLCD
    xor al, al
    mov [ebp + hAutoBGTransferEnabled], al
    call ClearObjectAnimationBuffers
    mov esi, SurfingPikachu1Graphics3
    sub esi, ebp
    mov edx, GB_VCHARS1
    mov bx, 144 * 16
    call FarCopyData
    mov byte [g_tilecache_dirty], 1

    ; Stage animated-object tables from flat program image to GB echo RAM
    call CopySurfingPikachuAnimatedObjectData

    mov word  [ebp + wAnimatedObjectSpawnStateDataPointer], W_SURF_SPAWN_DATA   ; GB ptr
    mov dword [ebp + wAnimatedObjectJumptablePointer],      SurfingPikachuObjectCallbacks  ; HOST ptr
    mov word  [ebp + wAnimatedObjectOAMDataPointer],        W_SURF_OAM_DATA     ; GB ptr
    mov word  [ebp + wAnimatedObjectFramesDataPointer],     W_SURF_FRAMES_DATA  ; GB ptr

    mov al, 0x0C                                ; intro Pikachu
    lb dx, SURFING_MINIGAME_FLAT_WATER_Y, SURFING_MINIGAME_CENTER_X
    call SpawnAnimatedObject
    call DrawSurfingPikachuMinigameIntroBackground
    xor al, al
    mov [ebp + hSCX], al
    mov [ebp + hSCY], al
    mov byte [ebp + hWY], 200                  ; keep window below visible screen (RENDER_H / 200)
    mov bh, SET_PAL_SURFING_PIKACHU_MINIGAME
    call RunPaletteCommand
    mov byte [ebp + IO_LCDC], LCDC_ON | LCDC_WIN_9C00 | LCDC_WIN_ON | LCDC_OBJ_ON | LCDC_BG_ON
    mov byte [ebp + hAutoBGTransferEnabled], 1
    call DelayFrame
    call DelayFrame
    call DelayFrame
    call SurfingPikachuMinigame_SetBGPals
    ldpal al, SHADE_BLACK, SHADE_DARK, SHADE_LIGHT, SHADE_WHITE
    mov [ebp + IO_OBP0], al
    ldpal al, SHADE_BLACK, SHADE_DARK, SHADE_WHITE, SHADE_WHITE
    mov [ebp + IO_OBP1], al
    call UpdateCGBPal_OBP0
    call UpdateCGBPal_OBP1
    call DelayFrame
    mov al, MUSIC_SURFING_PIKACHU
    mov cl, 0x1F
    call PlayMusic
    xor al, al
    mov [ebp + wSurfingMinigameIntroAnimationFinished], al
.loop:
    mov al, [ebp + wSurfingMinigameIntroAnimationFinished]
    test al, al
    jnz .ret
    mov byte [ebp + wCurrentAnimatedObjectOAMBufferOffset], 0
    call RunObjectAnimations
    call DelayFrame
    jmp .loop
.ret:
    ret

; ---------------------------------------------------------------------------
; DrawSurfingPikachuMinigameIntroBackground
; ---------------------------------------------------------------------------
DrawSurfingPikachuMinigameIntroBackground:
    mov esi, wTileMap
    mov bx, SCREEN_AREA
    mov al, 0xFF
    call FillMemory

    ; DEVIATION{class=projection; pret=engine/minigame/surfing_pikachu.asm:DrawSurfingPikachuMinigameIntroBackground; behavior=copy 12x20 beach intro tilemap row-by-row with stride 40 starting at BCOORD(0,6); evidence=wTileMap is 40 columns wide in the port vs 20 in pret; lifetime=permanent viewport expansion}
    mov esi, SurfingMinigame_BeachIntroTilemap
    sub esi, ebp
    decoord 0, 6
    mov ecx, 12
.copyIntroRow:
    push ecx
    push edx
    push esi
    mov bx, 20
    call CopyData
    pop esi
    add esi, 20
    pop edx
    add edx, SCREEN_WIDTH
    pop ecx
    dec ecx
    jnz .copyIntroRow

    mov edx, SurfingMinigame_TitleTilemap
    hlcoord 4, 0
    lb bx, 6, 12                                ; rows=6, cols=12
    call .CopyBox

    hlcoord 3, 7
    lb bx, 3, 15                                ; rows=3, cols=15 (SCREEN_WIDTH - 5 in pret)
    call .FillBoxWithFF

    mov esi, SurfingMinigame_UseControlPadTilemap
    sub esi, ebp
    decoord 3, 7
    mov bx, SurfingMinigame_UseControlPadTilemapEnd - SurfingMinigame_UseControlPadTilemap
    call CopyData

    mov esi, SurfingMinigame_ToSurfRadTilemap
    sub esi, ebp
    decoord 4, 9
    mov bx, SurfingMinigame_ToSurfRadTilemapEnd - SurfingMinigame_ToSurfRadTilemap
    call CopyData

    ; DEVIATION{class=projection; pret=engine/minigame/surfing_pikachu.asm:DrawSurfingPikachuMinigameIntroBackground; behavior=the port commits the finished intro canvas from wTileMap to GB_TILEMAP0 with an explicit one-shot mirror, standing in for the GB's hAutoBGTransferEnabled VBlank transfer; evidence=the port retired pret's VBlank wTileMap-to-BG-map auto-transfer as the root cause of the OW-A.13 menu corruption family per the retirement note in src-home-vblank.asm so every screen mirrors its own staging, this routine is the only writer of the intro background and it writes wTileMap exclusively while the surface window samples GB_TILEMAP0, and measured live 2026-08-18 the intro rendered as a uniform tile 00 field with vBGMap0 all zeros while wTileMap held the drawn canvas; lifetime=permanent, the auto-transfer is not coming back}
    call SurfingMinigame_MirrorIntroCanvas
    ret

.CopyBox:
.copyRow:
    push ebx
    push esi
.copyColumn:
    mov al, [edx]
    inc edx
    mov [ebp + esi], al
    inc esi
    dec bl
    jnz .copyColumn
    pop esi
    add esi, SCREEN_WIDTH                      ; stride 40
    pop ebx
    dec bh
    jnz .copyRow
    ret

.FillBoxWithFF:
.fillRow:
    push ebx
    push esi
.fillColumn:
    mov byte [ebp + esi], 0xFF
    inc esi
    dec bl
    jnz .fillColumn
    pop esi
    add esi, SCREEN_WIDTH                      ; stride 40
    pop ebx
    dec bh
    jnz .fillRow
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_MirrorIntroCanvas — port-only. Commit the intro canvas
; (wTileMap) to the tilemap the surface window actually samples (GB_TILEMAP0).
;
; No pret counterpart: on the Game Boy the intro background is staged into
; wTileMap and hAutoBGTransferEnabled = 1 lets the VBlank handler push it to
; vBGMap0 a slice per frame. The port retired that auto-transfer outright (see
; the retirement note in src/home/vblank.asm — its geometry could not serve both
; the stride-20 scratch screens and the 40-wide canvas screens, and it was the
; root cause of the OW-A.13 menu-corruption family), so a screen that stages
; through wTileMap must commit it itself, exactly as the cinematic surfaces do
; via MovieMirrorSurface.
;
; The MINIGAME PROPER does not need this and must not get it: SurfingMinigame_
; GenerateBGMap writes vBGMap0 directly through hlbgcoord, which is why the game
; screen was correct while the intro rendered as a uniform field of tile $00.
; Mirroring per frame would overwrite that generated map with this canvas.
;
; Geometry: the canvas is SCREEN_WIDTH (40) wide; the surface window is 160 px
; wide and spans y 24..168, i.e. the 20x18 GB screen, sourced from GB_TILEMAP0
; (stride TILEMAP_WIDTH = 32) at its origin with hSCX = hSCY = 0.
;
; The SOURCE ORIGIN IS BCOORD(0,0), NOT wTileMap. This file re-defines hlcoord /
; decoord to the battle projection (+10 columns, +3 rows, see the %macro block at
; the top), so every cell this screen authors already sits at the projected origin
; on the 40x25 canvas — the same origin MovieMirrorSurface reads from. Mirroring
; from wTileMap instead puts the whole intro 10 columns right of where it belongs
; and clips half of it off the window; that was measured on screen 2026-08-18.
; So GB cell (c,r) takes canvas cell (c+10, r+3). Columns 20-31 of the GB map are
; left alone: the intro never scrolls, so they are never sampled.
;
; In:  EBP = GB memory base. All registers preserved.
; ---------------------------------------------------------------------------
SURF_INTRO_MIRROR_COLS equ 160 / 8             ; window clip width in tiles = 20
SURF_INTRO_MIRROR_ROWS equ (168 - 24) / 8      ; window height in tiles      = 18

SurfingMinigame_MirrorIntroCanvas:
    pushad
    lea esi, [ebp + BCOORD(0, 0)]              ; projected canvas origin, not wTileMap
    lea edi, [ebp + GB_TILEMAP0]
    mov edx, SURF_INTRO_MIRROR_ROWS
.row:
    push esi
    push edi
    mov ecx, SURF_INTRO_MIRROR_COLS
    rep movsb
    pop edi
    pop esi
    add esi, SCREEN_WIDTH                      ; next canvas row (stride 40)
    add edi, TILEMAP_WIDTH                     ; next GB tilemap row (stride 32)
    dec edx
    jnz .row
    popad
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_UpdateLYOverrides
; ---------------------------------------------------------------------------
SurfingMinigame_UpdateLYOverrides:
    mov esi, wLYOverrides + 2 * TILE_HEIGHT
    mov edx, wLYOverrides + 2 * TILE_HEIGHT + 1
    mov cl, SCREEN_HEIGHT_PX - 2 * TILE_HEIGHT ; 128 (8-bit counter)
    mov al, [ebp + esi]
    push eax
.loop:
    mov al, [ebp + edx]
    inc edx
    mov [ebp + esi], al
    inc esi
    dec cl
    jnz .loop
    pop eax
    mov [ebp + esi], al
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_InitScanlineOverrides
; ---------------------------------------------------------------------------
SurfingMinigame_InitScanlineOverrides:
    mov esi, wLYOverrides
    mov bx, wLYOverridesEnd - wLYOverrides      ; 256
    xor dl, dl
.loop:
    mov al, dl
    and al, (SurfingMinigame_LYOverridesInitialSineWaveEnd - SurfingMinigame_LYOverridesInitialSineWave) - 1
    mov dl, al
    movzx eax, dl
    mov al, [SurfingMinigame_LYOverridesInitialSineWave + eax]
    mov [ebp + esi], al
    inc esi
    inc dl
    dec bx
    jnz .loop
    ret

; ---------------------------------------------------------------------------
; SurfingPikachu_GetJoypad_3FrameBuffer
; ---------------------------------------------------------------------------
SurfingPikachu_GetJoypad_3FrameBuffer:
    call Joypad
    mov al, [ebp + hFrameCounter]
    test al, al
    jnz .delayed
    mov al, [ebp + hJoyHeld]
    mov [ebp + hJoy5], al
    mov byte [ebp + hFrameCounter], 2
    ret

.delayed:
    xor al, al
    mov [ebp + hJoy5], al
    ret

; ---------------------------------------------------------------------------
; SurfingPikachuMinigame_BlankPals
; ---------------------------------------------------------------------------
SurfingPikachuMinigame_BlankPals:
    xor al, al
    mov [ebp + IO_BGP], al
    mov [ebp + IO_OBP0], al
    mov [ebp + IO_OBP1], al
    call UpdateCGBPal_BGP
    call UpdateCGBPal_OBP0
    call UpdateCGBPal_OBP1
    ret

; ---------------------------------------------------------------------------
; SurfingPikachuMinigame_NormalPals
; ---------------------------------------------------------------------------
SurfingPikachuMinigame_NormalPals:
    ldpal al, SHADE_BLACK, SHADE_DARK, SHADE_LIGHT, SHADE_WHITE
    mov [ebp + IO_BGP], al
    mov [ebp + IO_OBP0], al
    ldpal al, SHADE_BLACK, SHADE_DARK, SHADE_WHITE, SHADE_WHITE
    mov [ebp + IO_OBP1], al
    call UpdateCGBPal_BGP
    call UpdateCGBPal_OBP0
    call UpdateCGBPal_OBP1
    ret

; ---------------------------------------------------------------------------
; SurfingPikachu_ClearTileMap
; ---------------------------------------------------------------------------
SurfingPikachu_ClearTileMap:
    mov esi, wTileMap
    mov bx, SCREEN_AREA
    xor al, al
    call FillMemory
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_ResetJumpArc
; ---------------------------------------------------------------------------
SurfingMinigame_ResetJumpArc:
    xor al, al
    mov [ebp + wSurfingMinigameJumpDescending], al
    mov [ebp + wSurfingMinigameJumpArcFraction], al
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_UpdatePikachuHeight
; ---------------------------------------------------------------------------
SurfingMinigame_UpdatePikachuHeight:
    mov al, [ebp + wSurfingMinigameJumpDescending]
    test al, al
    jnz .descending
    mov dh, [ebp + wSurfingMinigameJumpArcMagnitude]
    mov al, [ebp + wSurfingMinigameJumpArcFraction]
    or al, dh
    jz .done
    mov dl, [ebp + wSurfingMinigameJumpArcFraction]
    mov ax, 0xFF80                             ; -0.5 in 8.8 (decrease jump velocity)
    add ax, dx
    mov [ebp + wSurfingMinigameJumpArcFraction], al
    mov [ebp + wSurfingMinigameJumpArcMagnitude], ah

    ; -(4 * a ** 2)
    mov dl, al
    mov dh, 0
    movzx edx, dx
    call SurfingMinigame_NTimesDE
    mov dx, si
    mov al, 4
    call SurfingMinigame_NTimesDE
    mov ax, si
    xor al, 0xFF
    inc al
    xor ah, 0xFF
    mov si, ax

    push esi
    mov dh, [ebp + ebx + ANIM_OBJ_Y_COORD]
    mov dl, [ebp + ebx + ANIM_OBJ_FIELD_C]
    pop esi

    add si, dx
    mov ax, si
    mov [ebp + ebx + ANIM_OBJ_Y_COORD], ah
    mov [ebp + ebx + ANIM_OBJ_FIELD_C], al
    clc
    ret

.done:
    mov byte [ebp + wSurfingMinigameJumpDescending], 1
    clc
    ret

.descending:
    mov dl, [ebp + wSurfingMinigamePikachuObjectHeight]
    mov al, [ebp + ebx + ANIM_OBJ_Y_COORD]
    cmp al, SCREEN_HEIGHT_PX                   ; 144 (GB pixel-Y comparison)
    jae .okay
    cmp al, dl
    jae .reset
.okay:
    mov dh, [ebp + wSurfingMinigameJumpArcMagnitude]
    mov dl, [ebp + wSurfingMinigameJumpArcFraction]
    mov ax, 0x0080                             ; 0.5 in 8.8 (increase fall velocity)
    add ax, dx
    mov [ebp + wSurfingMinigameJumpArcFraction], al
    mov [ebp + wSurfingMinigameJumpArcMagnitude], ah

    ; 4 * a ** 2
    mov dl, al
    mov dh, 0
    movzx edx, dx
    call SurfingMinigame_NTimesDE
    mov dx, si
    mov al, 4
    call SurfingMinigame_NTimesDE

    push esi
    mov dh, [ebp + ebx + ANIM_OBJ_Y_COORD]
    mov dl, [ebp + ebx + ANIM_OBJ_FIELD_C]
    pop esi

    add si, dx
    mov ax, si
    mov [ebp + ebx + ANIM_OBJ_Y_COORD], ah
    mov [ebp + ebx + ANIM_OBJ_FIELD_C], al
    clc
    ret

.reset:
    mov al, [ebp + wSurfingMinigamePikachuObjectHeight]
    mov [ebp + ebx + ANIM_OBJ_Y_COORD], al
    mov byte [ebp + ebx + ANIM_OBJ_FIELD_C], 0
    stc
    ret

; ---------------------------------------------------------------------------
; SurfingMinigame_NTimesDE
; ---------------------------------------------------------------------------
SurfingMinigame_NTimesDE:
    xor esi, esi                               ; ld hl, $0
.loop:
    shr al, 1
    jnc .noAdd
    add si, dx
.noAdd:
    shl dx, 1
    test al, al
    jnz .loop
    ret

; ---------------------------------------------------------------------------
; SurfingPikachu_PlaceBCDNumber
; ---------------------------------------------------------------------------
SurfingPikachu_PlaceBCDNumber:
    mov cl, al
    rol al, 4
    and al, 0x0F
    add al, 0xD0
    mov [ebp + esi], al
    inc esi
    mov al, cl
    and al, 0x0F
    add al, 0xD0
    mov [ebp + esi], al
    dec edx
    ret

; ---------------------------------------------------------------------------
; SurfingPikachu_Cosine / SurfingPikachu_Sine
; ---------------------------------------------------------------------------
SurfingPikachu_Cosine:
    add al, 0x10
SurfingPikachu_Sine:
    and al, 0x3F
    cmp al, 0x20
    jae .positive
    call .GetSine
    mov ax, si
    mov al, ah
    ret

.positive:
    and al, 0x1F
    call .GetSine
    mov ax, si
    mov al, ah
    xor al, 0xFF
    inc al
    ret

.GetSine:
    mov cl, al                                 ; CL = phase
    mov al, dh                                 ; AL = amplitude (multiplier)
    movzx edx, cl                              ; EDX = 0:phase
    mov esi, .SineWave
    lea esi, [esi + edx*2]
    movzx edx, word [esi]                      ; EDX = sine_table[phase]
    xor edi, edi                               ; DI accumulator
.loop:
    shr al, 1
    jnc .noAdd
    add di, dx
.noAdd:
    shl dx, 1
    test al, al
    jnz .loop
    movzx esi, di                              ; return product in ESI (HL)
    ret

.SineWave:
    dw 0x0000, 0x0019, 0x0032, 0x004a, 0x0062, 0x0079, 0x008e, 0x00a2
    dw 0x00b5, 0x00c6, 0x00d5, 0x00e2, 0x00ed, 0x00f5, 0x00fb, 0x00ff
    dw 0x0100, 0x00ff, 0x00fb, 0x00f5, 0x00ed, 0x00e2, 0x00d5, 0x00c6
    dw 0x00b5, 0x00a2, 0x008e, 0x0079, 0x0062, 0x004a, 0x0032, 0x0019

; ---------------------------------------------------------------------------
; SurfingMinigameAnimatedObjectFn_nop
; ---------------------------------------------------------------------------
SurfingMinigameAnimatedObjectFn_nop:
    ret

; ---------------------------------------------------------------------------
; Section .data tables
; ---------------------------------------------------------------------------
section .data

SurfingPikachuMiniPikachuTile:
    db 0xFE

SurfingPikachuHPDigitTiles:
    db 0xD0, 0xD0, 0xD0, 0xD0

SurfingPikachuWideCloudTiles:
    db 0xEC, 0xED, 0xED, 0xEE, 0xEF

SurfingPikachuNarrowCloudTiles:
    db 0xEC, 0xED, 0xEE, 0xEF

SurfingPikachuStatusBarTiles:
    db 0x17, 0x18, 0x19, 0x19, 0x19, 0x19, 0x19, 0x19, 0x19

SurfingPikachuObjectSpawnData:
    ; frameset, callback, tile offset
    db 0x00, 0x00, 0x00 ; 0: unused
    db 0x04, 0x01, 0x00 ; 1: surfing Pikachu
    db 0x11, 0x02, 0x00 ; 2: START
    db 0x12, 0x02, 0x00 ; 3: GOAL
    db 0x15, 0x00, 0x00 ; 4: +50
    db 0x16, 0x00, 0x00 ; 5: +150
    db 0x17, 0x00, 0x00 ; 6: +350
    db 0x18, 0x00, 0x00 ; 7: +750
    db 0x19, 0x00, 0x00 ; 8: +180
    db 0x1A, 0x00, 0x00 ; 9: +500
    db 0x14, 0x00, 0x00 ; a: water spray
    db 0x13, 0x03, 0x00 ; b: Oh no...
    db 0x1B, 0x04, 0x00 ; c: intro Pikachu
SurfingPikachuObjectSpawnDataEnd:

SurfingPikachuObjectCallbacks:
    dd SurfingMinigameAnimatedObjectFn_nop ; 0
    dd SurfingMinigameAnimatedObjectFn_Pikachu ; 1
    dd SurfingMinigame_MoveBannerToCenter ; 2
    dd SurfingMinigameAnimatedObjectFn_FlippingPika ; 3
    dd SurfingMinigameAnimatedObjectFn_IntroAnimationPikachu ; 4

SurfingMinigame_LYOverridesInitialSineWave:
    ; a sine wave with amplitude 2
    db  0,  0,  0,  1,  1,  1,  1,  2
    db  2,  2,  1,  1,  1,  1,  0,  0
    db  0,  0,  0, -1, -1, -1, -1, -2
    db -2, -2, -1, -1, -1, -1,  0,  0
SurfingMinigame_LYOverridesInitialSineWaveEnd:

SurfingMinigame_BGMetatileTable:
    db 0x00, 0x00, 0x00, 0x00 ; 00 ; sky block (blank)
    db 0x0B, 0x0B, 0x0B, 0x0B ; 01 ; water block
    db 0x0B, 0x02, 0x02, 0x06 ; 02
    db 0x03, 0x0B, 0x07, 0x03 ; 03
    db 0x06, 0x06, 0x06, 0x06 ; 04
    db 0x07, 0x07, 0x07, 0x07 ; 05
    db 0x06, 0x04, 0x04, 0x08 ; 06
    db 0x05, 0x07, 0x08, 0x05 ; 07
    db 0x0B, 0x0B, 0x11, 0x12 ; 08
    db 0x0B, 0x0B, 0x13, 0x03 ; 09
    db 0x14, 0x12, 0x04, 0x08 ; 0a
    db 0x13, 0x07, 0x08, 0x05 ; 0b
    db 0x06, 0x14, 0x06, 0x14 ; 0c ; unused, identical to 11
    db 0x13, 0x07, 0x13, 0x07 ; 0d
    db 0x08, 0x08, 0x08, 0x08 ; 0e ; solid blue
    db 0x14, 0x12, 0x14, 0x12 ; 0f
    db 0x0B, 0x11, 0x02, 0x14 ; 10
    db 0x06, 0x14, 0x06, 0x14 ; 11
    db 0x0C, 0x0C, 0x0D, 0x0D ; 12 ; beach top block
    db 0x0D, 0x0D, 0x0D, 0x0D ; 13 ; beach sand block
    db 0x0E, 0x0F, 0x10, 0x0B ; 14 ; beach shore block
    db 0x12, 0x13, 0x12, 0x13 ; 15

SurfingMinigameWavePattern00:
    db 0x00, 0x00, 0x00, 0x01, 0x01, 0x01, 0x01, 0x01
SurfingMinigameWavePattern01:
    db 0x00, 0x00, 0x00, 0x01, 0x01, 0x02, 0x04, 0x06
SurfingMinigameWavePattern02:
    db 0x00, 0x00, 0x00, 0x01, 0x02, 0x04, 0x06, 0x0E
SurfingMinigameWavePattern03:
    db 0x00, 0x00, 0x00, 0x10, 0x11, 0x06, 0x0E, 0x0E
SurfingMinigameWavePattern04:
    db 0x00, 0x00, 0x00, 0x15, 0x15, 0x0E, 0x0E, 0x0E
SurfingMinigameWavePattern05:
    db 0x00, 0x00, 0x00, 0x03, 0x05, 0x07, 0x0E, 0x0E
SurfingMinigameWavePattern06:
    db 0x00, 0x00, 0x00, 0x01, 0x03, 0x05, 0x07, 0x0E
SurfingMinigameWavePattern07:
    db 0x00, 0x00, 0x00, 0x01, 0x01, 0x03, 0x05, 0x07
SurfingMinigameWavePattern08:
    db 0x00, 0x00, 0x00, 0x01, 0x01, 0x02, 0x04, 0x06
SurfingMinigameWavePattern09:
    db 0x00, 0x00, 0x00, 0x01, 0x02, 0x04, 0x06, 0x0E
SurfingMinigameWavePattern0A:
    db 0x00, 0x00, 0x00, 0x08, 0x0F, 0x0A, 0x0E, 0x0E
SurfingMinigameWavePattern0B:
    db 0x00, 0x00, 0x00, 0x09, 0x0D, 0x0B, 0x0E, 0x0E
SurfingMinigameWavePattern0C:
    db 0x00, 0x00, 0x00, 0x01, 0x03, 0x05, 0x07, 0x0E
SurfingMinigameWavePattern0D:
    db 0x00, 0x00, 0x00, 0x01, 0x01, 0x03, 0x05, 0x07
SurfingMinigameWavePattern0E:
    db 0x00, 0x00, 0x00, 0x01, 0x01, 0x02, 0x04, 0x06
SurfingMinigameWavePattern0F:
    db 0x00, 0x00, 0x00, 0x01, 0x10, 0x11, 0x06, 0x0E
SurfingMinigameWavePattern10:
    db 0x00, 0x00, 0x00, 0x01, 0x15, 0x15, 0x0E, 0x0E
SurfingMinigameWavePattern11:
    db 0x00, 0x00, 0x00, 0x01, 0x03, 0x05, 0x07, 0x0E
SurfingMinigameWavePattern12:
    db 0x00, 0x00, 0x00, 0x01, 0x01, 0x03, 0x05, 0x07
SurfingMinigameWavePattern13:
    db 0x00, 0x00, 0x00, 0x01, 0x01, 0x02, 0x04, 0x06
SurfingMinigameWavePattern14:
    db 0x00, 0x00, 0x00, 0x01, 0x08, 0x0F, 0x0A, 0x0E
SurfingMinigameWavePattern15:
    db 0x00, 0x00, 0x00, 0x01, 0x09, 0x0D, 0x0B, 0x0E
SurfingMinigameWavePattern16:
    db 0x00, 0x00, 0x00, 0x01, 0x01, 0x03, 0x05, 0x07
SurfingMinigameWavePattern17:
    db 0x00, 0x00, 0x00, 0x01, 0x01, 0x10, 0x11, 0x06
SurfingMinigameWavePattern18:
    db 0x00, 0x00, 0x00, 0x01, 0x01, 0x15, 0x15, 0x0E
SurfingMinigameWavePattern19:
    db 0x00, 0x00, 0x00, 0x01, 0x01, 0x03, 0x05, 0x07
SurfingMinigameWavePattern1A:
    db 0x00, 0x00, 0x00, 0x01, 0x01, 0x08, 0x0F, 0x0A
SurfingMinigameWavePattern1B:
    db 0x00, 0x00, 0x00, 0x01, 0x01, 0x09, 0x0D, 0x0B
SurfingMinigameWavePattern1C:
    db 0x00, 0x00, 0x00, 0x14, 0x14, 0x14, 0x14, 0x14
SurfingMinigameBeachPattern:
    db 0x00, 0x00, 0x00, 0x12, 0x13, 0x13, 0x13, 0x13

; ---------------------------------------------------------------------------
; Surfing Pikachu tilemaps (pret engine/minigame/surfing_pikachu.asm)
; ---------------------------------------------------------------------------
%include "assets/surfing_pikachu_tilemaps.inc"

