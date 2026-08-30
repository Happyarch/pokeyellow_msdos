; init.asm — Init / ClearVram / StopAllSounds / GBPalNormal.
;
; Source: home/init.asm (pret/pokeyellow)
;
; Init is the power-on / soft-reset entry. It clears WRAM, VRAM, HRAM, OAM and
; resets I/O shadows to DMG power-up values, then falls through to the title
; screen. Hardware / not-yet-ported subsystem steps are marked TODO and skipped
; so the routine stays linkable and faithful in structure:
;
;   di/ei, rIF/rIE writes        → no GB interrupt controller; shadows only
;   WriteDMACodeToHRAM + rROMB   → ; TODO-HW: OAM DMA + ROM banking
;   predef LoadSGB               → wOnSGB = 1 (no packet HAL, but the port IS colour
;                                  hardware — LoadSGB sets wOnSGB on CGB; see below)
;   predef PlayIntro             → call PlayIntro (Game Freak splash + Yellow intro);
;                                  faithful default — runs on every normal power-on,
;                                  skipped only under SKIP_TITLE / SKIP_INTRO (menu-intro B4)
;   audio engine setup           → StopAllSounds + SFX_Shooting_Star bank seed
;                                  (audio engine is live; the bank bytes below are
;                                  load-bearing, not done-at-PowerOn-inert cells)
;   jp PrepareTitleScreen        → jmp PrepareTitleScreen (title screen implemented;
;                                  routes to MainMenu — menu-intro A2/A3)
;
; Constants resolved from the rgbds build (pokeyellow.sym):
;   LCDC_DEFAULT = $E3, LCDC_ON = $80, IE = $0D, BGP normal = $E4, OBP0 = $D0
;
; Build: nasm -f coff -I include/ -o init.o init.asm

bits 32

%include "gb_memmap.inc"
%include "gb_macros.inc"
%include "assets/audio_constants.inc"  ; AUDIO_BANK_1 (generated, Tier-1)
%include "assets/map_dims.inc"         ; MAP_ID_PALLET_TOWN (SetupPlayerSprite)
%include "assets/event_constants.inc"  ; event defs (kept for parity with overworld boot glue)

LCDC_ON_VAL      equ 0x80
LCDC_DEFAULT_VAL equ 0xE3
IE_DEFAULT_VAL   equ 0x0D
CONNECTION_NONE  equ 0xFF
WRAM0_SIZE       equ 0x1000
VRAM_SIZE        equ 0x2000

; Map and tileset constants (relocated from src/engine/overworld/overworld.asm D.2)
TILESET_OVERWORLD           equ 0x00
PALLET_TOWN_BORDER_BLOCK    equ 0x0B
TILESET_BANK_FLAT           equ 0x01
PALLET_TOWN_VIEW_PTR        equ wOverworldMap + (MAP_BORDER) * (PALLET_TOWN_WIDTH + MAP_BORDER * 2) + (MAP_BORDER - 2)
ROUTE1_BLK_GB_SIZE         equ 180
ROUTE21_BLK_GB_SIZE        equ 450
PLAYER_NAME_FIELD equ 11
%ifndef PLAYER_NAME
%define PLAYER_NAME 'NINTEN'
%endif
%ifndef RIVAL_NAME
%define RIVAL_NAME 'SONY'
%endif
%macro encode_name 1
%strlen _en_len %1
%assign _en_i 1
%rep _en_len
    %substr _en_ch %1 _en_i
    db _en_ch + 0x3F
    %assign _en_i _en_i + 1
%endrep
    times (PLAYER_NAME_FIELD - _en_len) db 0x50
%endmacro

extern FillMemory
extern StopAllMusic          ; src/home/audio.asm
extern GBPalWhiteOut         ; src/home/palettes.asm — SoftReset prologue
extern GBPalNormal           ; src/home/palettes.asm
extern DelayFrames           ; src/home/delay.asm — BL = frame count
extern DisableLCD
extern ClearBgMap
extern ClearSprites
extern PrepareTitleScreen
extern g_window_count        ; src/ppu/ppu.asm — unified window descriptor list count
extern StageIndoorMapBlk     ; src/home/overworld.asm
extern InitializeToggleableObjectsFlags ; src/engine/overworld/toggleable_objects.asm
extern text_engine_init      ; src/home/text.asm
extern EnterMap              ; src/home/overworld.asm
extern g_player_marker_on    ; src/ppu/ppu.asm
; Boot-asset externs — definitions live in src/data/maps/map_headers.asm (D.1)
extern overworld_gfx
extern OVERWORLD_GFX_SIZE
extern overworld_blocks
extern OVERWORLD_BLOCKS_SIZE
extern pallet_town_blk
extern PALLET_TOWN_BLK_SIZE
extern route1_blk
extern ROUTE1_BLK_SIZE
extern route21_blk
extern ROUTE21_BLK_SIZE
extern viridian_city_blk
extern VIRIDIAN_CITY_BLK_SIZE
extern pewter_city_blk
extern PEWTER_CITY_BLK_SIZE
extern cerulean_city_blk
extern CERULEAN_CITY_BLK_SIZE
extern lavender_town_blk
extern LAVENDER_TOWN_BLK_SIZE
extern vermilion_city_blk
extern VERMILION_CITY_BLK_SIZE
extern celadon_city_blk
extern CELADON_CITY_BLK_SIZE
extern fuchsia_city_blk
extern FUCHSIA_CITY_BLK_SIZE
extern cinnabar_island_blk
extern CINNABAR_ISLAND_BLK_SIZE
extern saffron_city_blk
extern SAFFRON_CITY_BLK_SIZE
extern route2_blk
extern ROUTE2_BLK_SIZE
extern route3_blk
extern ROUTE3_BLK_SIZE
extern route4_blk
extern ROUTE4_BLK_SIZE
extern route5_blk
extern ROUTE5_BLK_SIZE
extern route6_blk
extern ROUTE6_BLK_SIZE
extern route7_blk
extern ROUTE7_BLK_SIZE
extern route8_blk
extern ROUTE8_BLK_SIZE
extern route9_blk
extern ROUTE9_BLK_SIZE
extern route10_blk
extern ROUTE10_BLK_SIZE
extern route11_blk
extern ROUTE11_BLK_SIZE
extern route12_blk
extern ROUTE12_BLK_SIZE
extern route13_blk
extern ROUTE13_BLK_SIZE
extern route14_blk
extern ROUTE14_BLK_SIZE
extern route15_blk
extern ROUTE15_BLK_SIZE
extern route16_blk
extern ROUTE16_BLK_SIZE
extern route17_blk
extern ROUTE17_BLK_SIZE
extern route18_blk
extern ROUTE18_BLK_SIZE
extern route19_blk
extern ROUTE19_BLK_SIZE
extern route20_blk
extern ROUTE20_BLK_SIZE
extern route22_blk
extern ROUTE22_BLK_SIZE
extern route24_blk
extern ROUTE24_BLK_SIZE
extern route25_blk
extern ROUTE25_BLK_SIZE
extern route23_blk
extern ROUTE23_BLK_SIZE
extern indigo_plateau_blk
extern INDIGO_PLATEAU_BLK_SIZE
extern overworld_coll
extern OVERWORLD_COLL_SIZE
extern map_headers_data
extern MAP_HEADERS_DATA_SIZE
%ifdef SKIP_TITLE
extern InitPlayerData2       ; engine/movie/oak_speech/init_player_data.asm
extern InitOptions           ; engine/menus/main_menu.asm
%endif

global Init
global ClearVram
global StopAllSounds
extern g_tilecache_dirty

section .text

; ---------------------------------------------------------------------------
; SoftReset — the warm-boot entry (pret home/init.asm:SoftReset). Stops all
; sounds, whites the palettes out, waits 32 frames, then falls into Init.
; Nothing calls it yet in the live build — pret's caller is TrySoftReset in the
; joypad handler, which sits behind the port-input-model deviation (the title
; screen's own UP+SELECT+B check routes through jmp Init directly, as pret's
; title does) — but the entry is faithful and ready for that wiring.
; ---------------------------------------------------------------------------
global SoftReset
SoftReset:
    call StopAllSounds
    call GBPalWhiteOut
    mov bl, 32                       ; ld c, 32
    call DelayFrames
    ; fallthrough

; ---------------------------------------------------------------------------
; Init — power-on / soft-reset routine.
; ---------------------------------------------------------------------------
Init:
    ; Reset I/O shadows to 0 (di/rIF/rIE — no GB interrupt controller)
    xor al, al
    mov byte [ebp + IO_SCX],  al
    mov byte [ebp + IO_SCY],  al
    mov byte [ebp + IO_SB],   al
    mov byte [ebp + IO_SC],   al
    mov byte [ebp + IO_WX],   al
    mov byte [ebp + IO_WY],   al
    mov byte [ebp + IO_TMA],  al
    mov byte [ebp + IO_TAC],  al
    mov byte [ebp + IO_BGP],  al
    mov byte [ebp + IO_OBP0], al
    mov byte [ebp + IO_OBP1], al

    mov byte [ebp + IO_LCDC], LCDC_ON_VAL
    call DisableLCD

    ; Zero WRAM0 ($C000, $1000 bytes)
    push edi
    push ecx
    lea edi, [ebp + GB_WRAM0]
    mov ecx, WRAM0_SIZE
    xor eax, eax
    rep stosb
    pop ecx
    pop edi

    call ClearVram

    ; Fill HRAM with 0 (SIZEOF(HRAM) - 1 bytes, matching the SM83 original)
    mov esi, GB_HRAM
    mov bx, GB_HRAM_SIZE - 1
    xor al, al
    call FillMemory

    call ClearSprites

    ; WriteDMACodeToHRAM / rROMB — ; TODO-HW: OAM DMA + ROM banking.
    ; The software PPU reads shadow OAM directly; no HRAM stub needed.

    xor al, al
    mov byte [ebp + hTileAnimations],   al
    mov byte [ebp + IO_STAT],             al
    mov byte [ebp + hSCX],              al
    mov byte [ebp + hSCY],              al
    ; wUnusedAudioCounter / +1 (pret's old wc0f3) — zeroed by the WRAM0 clear above

    mov byte [ebp + GB_IE], IE_DEFAULT_VAL

    ; Move window off-screen (200 = past bottom of 320×200 viewport). The unified
    ; window compositor starts with an empty list (count=0 ⇒ nothing drawn); the
    ; rWY/rWX shadows are kept for faithfulness + the sync_dialog_window flag.
    ; DEVIATION{class=projection; pret=home/init.asm:Init; behavior=hWY/rWY are parked at 200 instead of pret's 144 (SCREEN_HEIGHT_PX); evidence=the port viewport is 320x200, so 144 is still on-screen and would leave a live window row visible; lifetime=permanent widescreen projection}
    mov dword [g_window_count], 0
    mov byte [ebp + hWY],   200
    mov byte [ebp + IO_WY],  200
    mov byte [ebp + IO_WX],  7

    mov byte [ebp + hSerialConnectionStatus], CONNECTION_NONE

    ; Clear both BG tilemaps to blank space ($7F)
    mov esi, GB_TILEMAP0
    call ClearBgMap
    mov esi, GB_TILEMAP1
    call ClearBgMap

    mov byte [ebp + IO_LCDC],       LCDC_DEFAULT_VAL
    mov byte [ebp + hSoftReset],  16
    call StopAllSounds

    ; ei — no GB interrupt controller

    ; predef LoadSGB — the port has no SGB packet HAL, but it DOES have colour
    ; hardware, and on real colour hardware LoadSGB publishes wOnSGB = 1 (measured
    ; in mGBA on the golden ROM: hOnCGB = 1 AND wOnSGB = 1). Publish that result
    ; directly so every wOnSGB branch takes the colour path the real game takes.
    ; DEVIATION{class=HAL; pret=home/init.asm:Init; behavior=predef LoadSGB is not called, its observable result wOnSGB=1 is published directly and the SGB packet transfer is omitted; evidence=measured in mGBA on the golden ROM in CGB mode, LoadSGB leaves hOnCGB=1 and wOnSGB=1, and the port's VGA DAC slot palettes are the colour-hardware path; lifetime=retired if an SGB packet HAL is ever implemented}
    mov byte [ebp + wOnSGB], 1

    ; pret: ld a, BANK(SFX_Shooting_Star) / ld [wAudioROMBank], a /
    ; ld [wAudioSavedROMBank], a. This seed is load-bearing, not bookkeeping:
    ; StopAllSounds above leaves the bank at engine 1 ($02), and PlayIntro below
    ; plays SFX_SHOOTING_STAR, whose header lives only in SFX_Headers_3 (bank
    ; $1f, and its id $c2 IS MAX_SFX_ID_3). Under engine 1 that id is above
    ; MAX_SFX_ID_1 ($b9) but below engine 1's music boundary, so PlaySound falls
    ; through to the MUSIC path and the Game Freak shooting-star SFX never plays.
    ; The Phase-3 DEVIATION that used to stand here called these cells "inert
    ; until the audio engine lands"; the engine has landed, so it is retired.
    mov al, AUDIO_BANK_3                        ; BANK(SFX_Shooting_Star) = $1f
    mov [ebp + wAudioROMBank], al
    mov [ebp + wAudioSavedROMBank], al

    ; hAutoBGTransferDest = vBGMap1 ($9C00)
    mov byte [ebp + hAutoBGTransferDest + 1], (GB_TILEMAP1 >> 8) & 0xFF
    mov byte [ebp + hAutoBGTransferDest],      GB_TILEMAP1 & 0xFF
    mov byte [ebp + wUpdateSpritesEnabled], 0xFF   ; dec a / ld [wUpdateSpritesEnabled], a

    ; pret runs `predef PlayIntro` here — the Game Freak splash + Yellow intro — on
    ; every normal power-on. This is the faithful default (menu-intro B4 flip). It is
    ; skipped only under two test bypasses:
    ;   SKIP_TITLE — the deterministic overworld bypass skips the whole boot movie
    ;                (and the title/menu); PlayIntro must not run before EnterMapBoot.
    ;   SKIP_INTRO — piece-test harnesses (title / mainmenu / oak / naming) that boot
    ;                the real title but must land on their screen immediately, without
    ;                the ~20 s cinematic shifting their dump frames.
    ; DEVIATION{class=banking; pret=home/init.asm:Init; behavior=pret's `predef PlayIntro` (a banked predef-table dispatch) is lowered to a direct `call PlayIntro`; evidence=the flat 32-bit port has no predef table or ROM banking, so every predef becomes a direct call to the exact pret label (see the Predef boundary in docs/plans/menu_intro.md); lifetime=permanent flat-banking model}
%ifndef SKIP_TITLE
%ifndef SKIP_INTRO
    extern PlayIntro                        ; engine/movie/intro.asm
    call PlayIntro
%endif
%endif

    call DisableLCD
    call ClearVram
    call GBPalNormal
    call ClearSprites
    mov byte [ebp + IO_LCDC], LCDC_DEFAULT_VAL

%ifdef SKIP_TITLE
    ; test build: skip the title AND MainMenu. Two things that boot normally does
    ; therefore have to be done here, and ONLY here — pret's Init does neither,
    ; so doing them unconditionally is an unfaithful divergence that the title
    ; golden caught (wOptions want $00 / got $03: the ROM has not reached
    ; InitOptions at the title, but the port had already written it in Init).
    ;
    ;   1. InitOptions — normally reached via MainMenu. Called rather than
    ;      partially duplicated, so wPrinterSettings matches too.
    ;   2. InitPlayerData2 — normally reached via StartNewGame -> OakSpeech. It
    ;      seeds the party/box/bag list terminators; without it every list scan
    ;      runs off a garbage, DPMI-uninitialised inventory
    ;      (docs/glitch_safety.md).
    call InitOptions
    call InitPlayerData2
    jmp EnterMapBoot         ; go straight to overworld (boot glue → faithful EnterMap)
%else
    jmp PrepareTitleScreen   ; tail call — runs title screen, never returns normally
%endif

; ---------------------------------------------------------------------------
; ClearVram — zero all of VRAM ($8000, $2000 bytes).
; ---------------------------------------------------------------------------
ClearVram:
    mov byte [g_tilecache_dirty], 1     ; VRAM tile data changes → rebuild decode cache
    mov esi, GB_VRAM0
    mov bx,  VRAM_SIZE & 0xFFFF
    xor al,  al
    jmp FillMemory              ; tail-call (jp FillMemory in the original)

; ---------------------------------------------------------------------------
; StopAllSounds — pret home/init.asm. Resets the audio bank to engine 1 and
; stops everything via StopAllMusic ($ff → PlaySound → Audio2_StopAllAudio).
; ---------------------------------------------------------------------------
StopAllSounds:
    mov al, AUDIO_BANK_1                ; BANK("Audio Engine 1") = $02
    mov [ebp + wAudioROMBank], al
    mov [ebp + wAudioSavedROMBank], al
    xor al, al
    mov [ebp + wAudioFadeOutControl], al
    mov [ebp + wNewSoundID], al
    mov [ebp + wLastMusicSoundID], al
    jmp StopAllMusic

; ---------------------------------------------------------------------------
; Boot overworld glue — relocated from src/engine/overworld/overworld.asm D.2.
; EnterMapBoot is the one-time boot staging that both SKIP_TITLE and the
; title/main-menu SpecialEnterMap path jmp to before the faithful EnterMap.
; LoadOverworldAssets copies embedded map assets into the GB ROM window;
; SetupPlayerSprite seeds the player sprite WRAM for the initial map.
; ---------------------------------------------------------------------------
section .data
DefaultPlayerName:
    encode_name PLAYER_NAME
DefaultRivalName:
    encode_name RIVAL_NAME

section .text

global EnterMapBoot
global LoadOverworldAssets
global SetupPlayerSprite

EnterMapBoot:
    call LoadOverworldAssets
    call SetupPlayerSprite
    call StageIndoorMapBlk
%ifdef SKIP_TITLE
    lea esi, [DefaultPlayerName]
    lea edi, [ebp + wPlayerName]
    mov ecx, PLAYER_NAME_FIELD
    rep movsb
    lea esi, [DefaultRivalName]
    lea edi, [ebp + wRivalName]
    mov ecx, PLAYER_NAME_FIELD
    rep movsb
    call InitializeToggleableObjectsFlags
%endif
    call text_engine_init
    jmp EnterMap

LoadOverworldAssets:
    push esi
    push edi
    push ecx
    mov esi, overworld_gfx
    lea edi, [ebp + OW_GFX_GBADDR]
    mov ecx, OVERWORLD_GFX_SIZE
    rep movsb
    mov esi, overworld_blocks
    lea edi, [ebp + OW_BLOCKS_GBADDR]
    mov ecx, OVERWORLD_BLOCKS_SIZE
    rep movsb
    mov esi, pallet_town_blk
    lea edi, [ebp + OW_PALLET_BLK_GBADDR]
    mov ecx, PALLET_TOWN_BLK_SIZE
    rep movsb
    mov esi, route1_blk
    lea edi, [ebp + OW_ROUTE1_BLK_GBADDR]
    mov ecx, ROUTE1_BLK_SIZE
    rep movsb
    mov esi, route21_blk
    lea edi, [ebp + OW_ROUTE21_BLK_GBADDR]
    mov ecx, ROUTE21_BLK_SIZE
    rep movsb
    mov esi, viridian_city_blk
    lea edi, [ebp + OW_VIRIDIAN_CITY_BLK_GBADDR]
    mov ecx, VIRIDIAN_CITY_BLK_SIZE
    rep movsb
    mov esi, pewter_city_blk
    lea edi, [ebp + OW_PEWTER_CITY_BLK_GBADDR]
    mov ecx, PEWTER_CITY_BLK_SIZE
    rep movsb
    mov esi, cerulean_city_blk
    lea edi, [ebp + OW_CERULEAN_CITY_BLK_GBADDR]
    mov ecx, CERULEAN_CITY_BLK_SIZE
    rep movsb
    mov esi, lavender_town_blk
    lea edi, [ebp + OW_LAVENDER_TOWN_BLK_GBADDR]
    mov ecx, LAVENDER_TOWN_BLK_SIZE
    rep movsb
    mov esi, vermilion_city_blk
    lea edi, [ebp + OW_VERMILION_CITY_BLK_GBADDR]
    mov ecx, VERMILION_CITY_BLK_SIZE
    rep movsb
    mov esi, celadon_city_blk
    lea edi, [ebp + OW_CELADON_CITY_BLK_GBADDR]
    mov ecx, CELADON_CITY_BLK_SIZE
    rep movsb
    mov esi, fuchsia_city_blk
    lea edi, [ebp + OW_FUCHSIA_CITY_BLK_GBADDR]
    mov ecx, FUCHSIA_CITY_BLK_SIZE
    rep movsb
    mov esi, cinnabar_island_blk
    lea edi, [ebp + OW_CINNABAR_ISLAND_BLK_GBADDR]
    mov ecx, CINNABAR_ISLAND_BLK_SIZE
    rep movsb
    mov esi, saffron_city_blk
    lea edi, [ebp + OW_SAFFRON_CITY_BLK_GBADDR]
    mov ecx, SAFFRON_CITY_BLK_SIZE
    rep movsb
    mov esi, route2_blk
    lea edi, [ebp + OW_ROUTE_2_BLK_GBADDR]
    mov ecx, ROUTE2_BLK_SIZE
    rep movsb
    mov esi, route3_blk
    lea edi, [ebp + OW_ROUTE_3_BLK_GBADDR]
    mov ecx, ROUTE3_BLK_SIZE
    rep movsb
    mov esi, route4_blk
    lea edi, [ebp + OW_ROUTE_4_BLK_GBADDR]
    mov ecx, ROUTE4_BLK_SIZE
    rep movsb
    mov esi, route5_blk
    lea edi, [ebp + OW_ROUTE_5_BLK_GBADDR]
    mov ecx, ROUTE5_BLK_SIZE
    rep movsb
    mov esi, route6_blk
    lea edi, [ebp + OW_ROUTE_6_BLK_GBADDR]
    mov ecx, ROUTE6_BLK_SIZE
    rep movsb
    mov esi, route7_blk
    lea edi, [ebp + OW_ROUTE_7_BLK_GBADDR]
    mov ecx, ROUTE7_BLK_SIZE
    rep movsb
    mov esi, route8_blk
    lea edi, [ebp + OW_ROUTE_8_BLK_GBADDR]
    mov ecx, ROUTE8_BLK_SIZE
    rep movsb
    mov esi, route9_blk
    lea edi, [ebp + OW_ROUTE_9_BLK_GBADDR]
    mov ecx, ROUTE9_BLK_SIZE
    rep movsb
    mov esi, route10_blk
    lea edi, [ebp + OW_ROUTE_10_BLK_GBADDR]
    mov ecx, ROUTE10_BLK_SIZE
    rep movsb
    mov esi, route11_blk
    lea edi, [ebp + OW_ROUTE_11_BLK_GBADDR]
    mov ecx, ROUTE11_BLK_SIZE
    rep movsb
    mov esi, route12_blk
    lea edi, [ebp + OW_ROUTE_12_BLK_GBADDR]
    mov ecx, ROUTE12_BLK_SIZE
    rep movsb
    mov esi, route13_blk
    lea edi, [ebp + OW_ROUTE_13_BLK_GBADDR]
    mov ecx, ROUTE13_BLK_SIZE
    rep movsb
    mov esi, route14_blk
    lea edi, [ebp + OW_ROUTE_14_BLK_GBADDR]
    mov ecx, ROUTE14_BLK_SIZE
    rep movsb
    mov esi, route15_blk
    lea edi, [ebp + OW_ROUTE_15_BLK_GBADDR]
    mov ecx, ROUTE15_BLK_SIZE
    rep movsb
    mov esi, route16_blk
    lea edi, [ebp + OW_ROUTE_16_BLK_GBADDR]
    mov ecx, ROUTE16_BLK_SIZE
    rep movsb
    mov esi, route17_blk
    lea edi, [ebp + OW_ROUTE_17_BLK_GBADDR]
    mov ecx, ROUTE17_BLK_SIZE
    rep movsb
    mov esi, route18_blk
    lea edi, [ebp + OW_ROUTE_18_BLK_GBADDR]
    mov ecx, ROUTE18_BLK_SIZE
    rep movsb
    mov esi, route19_blk
    lea edi, [ebp + OW_ROUTE_19_BLK_GBADDR]
    mov ecx, ROUTE19_BLK_SIZE
    rep movsb
    mov esi, route20_blk
    lea edi, [ebp + OW_ROUTE_20_BLK_GBADDR]
    mov ecx, ROUTE20_BLK_SIZE
    rep movsb
    mov esi, route22_blk
    lea edi, [ebp + OW_ROUTE_22_BLK_GBADDR]
    mov ecx, ROUTE22_BLK_SIZE
    rep movsb
    mov esi, route24_blk
    lea edi, [ebp + OW_ROUTE_24_BLK_GBADDR]
    mov ecx, ROUTE24_BLK_SIZE
    rep movsb
    mov esi, route25_blk
    lea edi, [ebp + OW_ROUTE_25_BLK_GBADDR]
    mov ecx, ROUTE25_BLK_SIZE
    rep movsb
    mov esi, route23_blk
    lea edi, [ebp + OW_ROUTE_23_BLK_GBADDR]
    mov ecx, ROUTE23_BLK_SIZE
    rep movsb
    mov esi, indigo_plateau_blk
    lea edi, [ebp + OW_INDIGO_PLATEAU_BLK_GBADDR]
    mov ecx, INDIGO_PLATEAU_BLK_SIZE
    rep movsb
    mov esi, overworld_coll
    lea edi, [ebp + OW_COLL_GBADDR]
    mov ecx, OVERWORLD_COLL_SIZE
    rep movsb
    mov esi, map_headers_data
    lea edi, [ebp + OW_TILESET_HDR_GBADDR]
    mov ecx, MAP_HEADERS_DATA_SIZE
    rep movsb
    pop ecx
    pop edi
    pop esi
    ret

SetupPlayerSprite:
%ifdef SKIP_TITLE
    cmp byte [ebp + wCurMap], 0
    jne .skip_map_default
    mov byte [ebp + wCurMap], MAP_ID_PALLET_TOWN
    mov byte [ebp + wYCoord], 8
    mov byte [ebp + wXCoord], 8
    mov byte [ebp + wYBlockCoord], 0
    mov byte [ebp + wXBlockCoord], 0
    mov word [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR], PALLET_TOWN_VIEW_PTR
.skip_map_default:
%endif
    mov byte [ebp + W_SPRITE_PLAYER_FACING_DIR],   SPRITE_FACING_DOWN
    mov byte [ebp + wPlayerDirection],           0
    mov byte [ebp + wPlayerMovingDirection],    0
    mov byte [ebp + W_SPRITE_PLAYER_Y_STEP_VECTOR], 0
    mov byte [ebp + W_SPRITE_PLAYER_X_STEP_VECTOR], 0
    mov byte [ebp + wWalkCounter],               0
    mov byte [ebp + wSpritePlayerStateData1PictureID],      1
    mov byte [ebp + W_SPRITE_PLAYER_IMAGE_BASE_OFFSET], 1
    mov byte [ebp + W_SPRITE_PLAYER_Y_PIXELS],        0x3C
    mov byte [ebp + W_SPRITE_PLAYER_X_PIXELS],        0x40
    mov byte [ebp + wSpritePlayerStateData1ImageIndex],     SPRITE_FACING_DOWN
    mov byte [ebp + W_SPRITE_PLAYER_INTRA_ANIM],      0
    mov byte [ebp + W_SPRITE_PLAYER_ANIM_FRAME],      0
    mov byte [ebp + wSpritePlayerStateData2WalkAnimationCounter], 0
    mov byte [ebp + W_SPRITE_PLAYER_GRASS_PRIORITY],  0
    mov byte [ebp + wGrassTile],    0xFF
    mov byte [ebp + wFontLoaded],   0
    mov byte [ebp + wMovementFlags], 0
    mov byte [ebp + hAutoBGTransferEnabled],        0
    mov byte [g_player_marker_on], 0
    ret

; ---------------------------------------------------------------------------
; GBPalNormal MOVED to src/home/palettes.asm (mirror rule) — a pret
; home/palettes.asm label. Init still calls it.
; ---------------------------------------------------------------------------
