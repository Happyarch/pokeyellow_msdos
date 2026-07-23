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
;   predef LoadSGB               → ; TODO-HW: SGB detect (wOnSGB stays 0)
;   predef PlayIntro             → call PlayIntro (Game Freak splash + Yellow intro);
;                                  faithful default — runs on every normal power-on,
;                                  skipped only under SKIP_TITLE / SKIP_INTRO (menu-intro B4)
;   audio engine setup           → ; TODO: audio HAL (Phase 3)
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

LCDC_ON_VAL      equ 0x80
LCDC_DEFAULT_VAL equ 0xE3
IE_DEFAULT_VAL   equ 0x0D
CONNECTION_NONE  equ 0xFF
BGP_NORMAL       equ 0xE4
OBP0_NORMAL      equ 0xD0
WRAM0_SIZE       equ 0x1000
VRAM_SIZE        equ 0x2000

extern FillMemory
extern StopAllMusic          ; src/home/audio.asm
extern GBPalWhiteOut         ; src/home/fade.asm — SoftReset prologue
extern DelayFrames           ; src/video/frame.asm — BL = frame count
extern DisableLCD
extern ClearBgMap
extern ClearSprites
extern PrepareTitleScreen
extern g_window_count        ; src/ppu/ppu.asm — unified window descriptor list count
%ifdef SKIP_TITLE
extern EnterMapBoot          ; overworld.asm — one-time overworld boot glue → EnterMap
extern InitPlayerData2       ; engine/movie/oak_speech/init_player_data.asm
extern InitOptions           ; engine/menus/main_menu.asm
%endif

global Init
global ClearVram
global StopAllSounds
global GBPalNormal
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
    mov byte [ebp + H_TILE_ANIMATIONS],   al
    mov byte [ebp + IO_STAT],             al
    mov byte [ebp + H_SCX],              al
    mov byte [ebp + H_SCY],              al
    ; wc0f3 / wc0f3+1 — zeroed by the WRAM0 clear above

    mov byte [ebp + GB_IE], IE_DEFAULT_VAL

    ; Move window off-screen (200 = past bottom of 320×200 viewport). The unified
    ; window compositor starts with an empty list (count=0 ⇒ nothing drawn); the
    ; rWY/rWX shadows are kept for faithfulness + the sync_dialog_window flag.
    ; DEVIATION{class=projection; pret=home/init.asm:Init; behavior=hWY/rWY are parked at 200 instead of pret's 144 (SCREEN_HEIGHT_PX); evidence=the port viewport is 320x200, so 144 is still on-screen and would leave a live window row visible; lifetime=permanent widescreen projection}
    mov dword [g_window_count], 0
    mov byte [ebp + H_WY],   200
    mov byte [ebp + IO_WY],  200
    mov byte [ebp + IO_WX],  7

    mov byte [ebp + H_SERIAL_CONN_STATUS], CONNECTION_NONE

    ; Clear both BG tilemaps to blank space ($7F)
    mov esi, GB_TILEMAP0
    call ClearBgMap
    mov esi, GB_TILEMAP1
    call ClearBgMap

    mov byte [ebp + IO_LCDC],       LCDC_DEFAULT_VAL
    mov byte [ebp + H_SOFT_RESET],  16
    call StopAllSounds

    ; ei — no GB interrupt controller

    ; predef LoadSGB — ; TODO-HW: SGB detection. wOnSGB stays 0 (zeroed above).

    ; DEVIATION{class=HAL; pret=home/init.asm:Init; behavior=pret's wAudioROMBank/wAudioSavedROMBank = BANK(SFX_Shooting_Star) seed is dropped; evidence=the audio engine is Phase 3 (docs/current_plan_audio.md) and the bank cells are inert until it lands; lifetime=retired by the Phase 3 audio engine wiring the boot banks}

    ; hAutoBGTransferDest = vBGMap1 ($9C00)
    mov byte [ebp + H_AUTO_BG_TRANSFER_DEST + 1], (GB_TILEMAP1 >> 8) & 0xFF
    mov byte [ebp + H_AUTO_BG_TRANSFER_DEST],      GB_TILEMAP1 & 0xFF
    mov byte [ebp + wUpdateSpritesEnabled], 0xFF   ; dec a / ld [wUpdateSpritesEnabled], a

    ; pret runs `predef PlayIntro` here — the Game Freak splash + Yellow intro — on
    ; every normal power-on. This is the faithful default (menu-intro B4 flip). It is
    ; skipped only under two test bypasses:
    ;   SKIP_TITLE — the deterministic overworld bypass skips the whole boot movie
    ;                (and the title/menu); PlayIntro must not run before EnterMapBoot.
    ;   SKIP_INTRO — piece-test harnesses (title / mainmenu / oak / naming) that boot
    ;                the real title but must land on their screen immediately, without
    ;                the ~20 s cinematic shifting their dump frames.
    ; DEVIATION{class=banking; pret=home/init.asm:Init; behavior=pret's `predef PlayIntro` (a banked predef-table dispatch) is lowered to a direct `call PlayIntro`; evidence=the flat 32-bit port has no predef table or ROM banking, so every predef becomes a direct call to the exact pret label (see the Predef boundary in docs/current_plan_menu_intro.md); lifetime=permanent flat-banking model}
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
; GBPalNormal — reset BGP/OBP0/OBP1 shadows to DMG normal palettes.
; CGB palette updates deferred to Phase 5.
; ---------------------------------------------------------------------------
GBPalNormal:
    mov byte [ebp + IO_BGP],  BGP_NORMAL
    mov byte [ebp + IO_OBP0], OBP0_NORMAL
    ret
