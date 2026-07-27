; title.asm — the title screen, at its pret mirror.
;
; Source: engine/movie/title.asm. Holds pret title.asm's labels:
; PrepareTitleScreen -> DisplayTitleScreen (fall-through, load-bearing),
; TitleScreenCopyTileMapToVRAM, the boot copyright screen
; (LoadCopyrightAndTextBoxTiles -> LoadCopyrightTiles) + CopyrightTextString
; data, DoTitleScreenFunction, CopyDebugName + the debug boot names, and
; IncrementResetCounter. The title-screen driver moved here from the legacy
; title module src/movie/title.asm 2026-07-24 (relocated-labels grind — the
; split was registered legacy debt in tools/pret_label_allowlist.json, now
; retired). The Yellow graphics/placement half is in its own mirror,
; src/engine/movie/title_yellow.asm; ClearScreen went to its pret mirror
; src/home/copy2.asm (2026-07-24) and the legacy module is deleted.
;
; Animation overview (DisplayTitleScreen):
;   1. Load all title graphics to VRAM.
;   2. Place Pokemon logo (no pikachu) in wTileMap; save to Buffer2.
;   3. Add pikachu to wTileMap; copy to physical tilemap at $9B00 (row 24);
;      save to Buffer1.  hSCY = 64.
;   4. Restore Buffer2 (logo only); copy to physical tilemap at $9800 (row 0).
;   5. hWY = 64 turns the GB window on, then hSCY bounces 64 → 0 over ~32
;      frames (DelayFrame each step). The window is what keeps the bottom of
;      the screen still while the logo bounces — see the hWY comment there.
;      (The physical-tilemap copies are NOT noise, whatever the old comment
;      here claimed. Under projection the compositor samples the GB tilemap
;      through the window descriptor, and the row-24 copy's contiguous spill
;      into tilemap 1 is exactly what feeds the bounce window.)
;   6. After bounce, restore Buffer1 (logo+pikachu); DelayFrames(36) —
;      Pikachu appears (render_bg reads the restored wTileMap).
;   7. Place speech bubble; play PCM; play music.
;   8. Main idle loop: blink Pikachu's eyes, await A/Start → main menu.
;      Inactivity for ~51 s resets to Init.
;
; Hardware I/O boundaries in this file:
;   FillSpriteBuffer0WithAA — not ported (project_state: missing). SRAM is not
;     emulated, and pret uses this only to prime a sprite buffer with $AA.
;
; Build: nasm -f coff -I include/ -I . -o title.o title.asm

bits 32

%include "gb_memmap.inc"
%include "gb_macros.inc"
%include "gb_constants.inc"             ; SET_PAL_TITLE_SCREEN
%include "assets/audio_constants.inc"   ; SFX_INTRO_*/MUSIC_TITLE_SCREEN
%define PIKA_PCM_EQUATES_ONLY 1         ; indices only — the blob lives in pikachu_pcm.o
%include "assets/pika_pcm.inc"          ; PIKA_CRY_*_IDX
%define UI_LAYOUT_EQUATES_ONLY 1
%include "assets/ui_layout_intro.inc"   ; UI_TITLE_* / UI_SPLASH_* projected surface geometry

; ---------------------------------------------------------------------------
; Externs
; ---------------------------------------------------------------------------
extern FillMemory
extern DisableLCD
extern EnableLCD
extern ClearSprites
extern LoadFontTilePatterns
extern LoadTextBoxTilePatterns       ; home/load_font.asm — font_extra -> vChars2 $60
extern text_engine_init
extern DelayFrame
extern DelayFrames
extern Delay3
extern GBPalNormal
extern Init
extern MainMenu                  ; engine/menus/main_menu.asm — the real post-title route
extern g_tilecache_dirty
extern JoypadLowSensitivity     ; src/home/joypad2.asm
extern PlaySound                ; src/home/audio.asm — AL = sound id
extern StopAllMusic             ; src/home/audio.asm
extern WaitForSoundToFinish     ; src/home/delay.asm
extern PlayPikachuSoundClip     ; src/engine/pikachu/pikachu_pcm.asm — DL = clip index (pret: E)
extern RunPaletteCommand        ; src/home/palettes.asm — BH = palette command
extern UpdateCGBPal_OBP0        ; src/home/cgb_palettes.asm
extern GBPalWhiteOutWithDelay3  ; src/home/palettes.asm
extern LoadGBPal                ; src/home/fade.asm
extern MovieBeginSurface        ; src/engine/movie/movie_projection.asm
extern MovieEndSurface          ; src/engine/movie/movie_projection.asm
extern MovieMirrorSurface       ; src/engine/movie/movie_projection.asm
extern MovieSyncScroll          ; src/engine/movie/movie_projection.asm
extern MovieSyncWindow          ; src/engine/movie/movie_projection.asm
extern PublishProjectedOAM      ; src/engine/gfx/sprite_oam.asm — ESI=src ECX=n EAX/EBX=offset
extern ClearScreen                   ; home/copy2.asm — clear the surface tilemap
extern CopyVideoData                 ; home/copy2.asm — ESI=VRAM dest, EDX=flat src, BL=tiles
extern PlaceString                   ; home/text.asm — ESI=dest(GB offset), EAX=flat src
extern text_row_stride               ; home/text.asm — PlaceString row stride (port's SCREEN_WIDTH)
extern SaveScreenTilesToBuffer1     ; src/home/tilemap.asm
extern LoadScreenTilesFromBuffer1   ; src/home/tilemap.asm
extern SaveScreenTilesToBuffer2     ; src/home/tilemap.asm
extern LoadScreenTilesFromBuffer2   ; src/home/tilemap.asm
extern GBPalWhiteOut                ; src/home/palettes.asm — the real pret routine
extern DoClearSaveDialogue          ; engine/movie/oak_speech/clear_save.asm (temporary DEVIATION: plain reset)
; --- the Yellow graphics/placement half (its own pret mirror) ---------------
extern LoadYellowTitleScreenGFX          ; src/engine/movie/title_yellow.asm
extern TitleScreen_PlacePokemonLogo      ; src/engine/movie/title_yellow.asm
extern TitleScreen_PlacePikachu          ; src/engine/movie/title_yellow.asm
extern TitleScreen_PlacePikaSpeechBubble ; src/engine/movie/title_yellow.asm
extern TitleScreenPublishEyes            ; src/engine/movie/title_yellow.asm — port-only eye republish
%ifdef DEBUG_TITLE
%define TITLE_NEEDS_DUMP 1
%endif
%ifdef DEBUG_TITLE_REENTRY
%define TITLE_NEEDS_DUMP 1
%endif
%ifdef TITLE_NEEDS_DUMP
extern DumpBackbuffer           ; src/debug/debug_dump.asm — writes FRAME.BIN + exits
%endif

; ---------------------------------------------------------------------------
; Globals
; ---------------------------------------------------------------------------
global PrepareTitleScreen
global DisplayTitleScreen        ; MainMenu "B returns to title" seam

; ---------------------------------------------------------------------------
; Constants
; ---------------------------------------------------------------------------
NAME_LENGTH          equ 11      ; wPlayerName / wRivalName field size

; LCDC bit 7 — LCD enable (used by EnableLCD/DisableLCD in lcd.asm)
LCDC_DEFAULT_VAL     equ 0xE3

; GB joypad bits in the hJoyHeld shadow (active HIGH)
PAD_A                equ 0x01
PAD_B                equ 0x02
PAD_SELECT           equ 0x04
PAD_START            equ 0x08
PAD_RIGHT            equ 0x10
PAD_LEFT             equ 0x20
PAD_UP               equ 0x40
PAD_DOWN             equ 0x80

SCREEN_HEIGHT_PX     equ 144     ; pret's hWY "hide the window layer" value (see the hWY note below)

; Projected drawing origins. The title composes a Game Boy 20x18 screen, but
; wTileMap here is the port's 40x25 canvas, so every placement pret writes at
; coord(col,row) lands at coord(col+UI_TITLE_COL, row+UI_TITLE_ROW). Keeping
; pret's own col/row literals at the call sites and adding this one offset means
; the coordinates stay diffable against the disassembly instead of becoming
; pre-baked canvas numbers. Geometry comes from the generated layout, never a
; literal 10/3. The copyright screen draws at the cinematic splash origin.
TITLE_ORIGIN         equ UI_TITLE_ROW * SCREEN_TILES_W + UI_TITLE_COL
INTRO_BG_ORIGIN      equ UI_SPLASH_ROW * SCREEN_TILES_W + UI_SPLASH_COL   ; = 130

; VRAM tile destination constants
VCHARS1_TILE_60      equ GB_VFONT + 0x60 * 16   ; = $8E00  (copyright tiles)
VCHARS1_TILE_65      equ GB_VFONT + 0x65 * 16   ; = $8E50  (GameFreak logo)
VCHARS1_TILE_6E      equ GB_VFONT + 0x6E * 16   ; = $8EE0  (Nine tile)

; Tilemap destination addresses (high bytes passed to TitleScreenCopyTileMapToVRAM)
TILEMAP_DEST_HI_ROW0 equ (GB_TILEMAP0 >> 8)      ; $98 → $9800 (row 0)
TILEMAP_DEST_HI_ROW24 equ ((GB_TILEMAP0 + 0x300) >> 8) ; $9B → $9B00 (row 24)

; ---------------------------------------------------------------------------
; Data
; ---------------------------------------------------------------------------
section .data
align 4

%ifdef DEBUG_TITLE
%define TITLE_DBG_COUNTER 1
%endif
%ifdef DEBUG_MAINMENU_LIVE
%define TITLE_DBG_COUNTER 1
%endif
%ifdef DEBUG_TITLE_REENTRY
%define TITLE_DBG_COUNTER 1
%endif
%ifdef DEBUG_SOFT_RESET
%define TITLE_DBG_COUNTER 1
%endif
%ifdef TITLE_DBG_COUNTER
title_dbg_frame: dd 0                   ; frames elapsed (mid-bounce / idle-loop / forced-start counter)
%endif
%ifdef DEBUG_TITLE_REENTRY
; Persists across the DisplayTitleScreen re-entry (.data survives the jmp).
; Visit 1 latches START -> MainMenu; MainMenu B-cancels back to DisplayTitleScreen;
; visit 2 dumps the checkpoint, proving the round trip restored every piece of
; state MovieBeginSurface owns (g_obj_clip, g_bg_whiteout, source offsets, OAM).
title_reentry_visit: dd 0
%endif
; title_timeout / soft_reset goldens (menu-intro B4): set to 1 on a title-screen reset
; (timeout or the UP+SELECT+B combo) so PlayShootingStar dumps the REPLAYED copyright
; the flip produces. Host .data, so it survives the jmp Init back into the boot movie.
; Defined unconditionally (1 byte, inert in the default build); only the reset paths
; write it and only the DEBUG_TITLE_TIMEOUT/DEBUG_SOFT_RESET dump hook reads it.
global g_title_reset_replay
g_title_reset_replay: db 0

; Copyright row tile indices ($FF = end sentinel).
; ©1995-1999 GAME FREAK inc.
; $e0-$e4 = © 1 9 9 5 (signed → vChars1 $8E00-)
; $ee = Nine tile (signed → $8EE0)
; $e5-$ed = GAME FREAK inc. (signed → vChars1 $8E50-)
CopyrightRowTiles:
    db 0xe0,0xe1,0xe2,0xe3,0xe1,0xe2,0xee,0xe5,0xe6,0xe7,0xe8,0xe9,0xea,0xeb,0xec,0xed,0xff

; Controls the bouncing effect of the Pokemon logo on the title screen.
; Pairs of (signed SCY delta, number of times to scroll); $00 terminates.
;
; pret: engine/movie/title.asm:DisplayTitleScreen.TitleScreenPokemonLogoYScrolls
; — a LOCAL label inside DisplayTitleScreen, so the port keeps that exact name
; and scope (an earlier revision invented a global `TitleScreenYScrolls`). The
; qualified spelling defines the same local NASM would produce from `.name`,
; without having to move the data below DisplayTitleScreen: NASM binds a bare
; `.name` to the most recent textually preceding global, which here would be the
; wrong routine.
;
; hSCY starts at $40 and this table walks it 64 -> 0 -> 12 -> 0 -> 4 -> 0 -> 2
; -> 0: range [0,64], and it NEVER crosses the 0/255 boundary. The -3 entry is
; special only because pret's `cp -3` dispatches SFX_INTRO_CRASH there — it is
; not an unsigned wrap, so it is not wrap evidence for the compositor.
DisplayTitleScreen.TitleScreenPokemonLogoYScrolls:
    db -4, 16
    db  3,  4
    db -3,  4
    db  2,  2
    db -2,  2
    db  1,  2
    db -1,  2
    db  0

; Debug player/rival names (pret charmap encoding), Tier-1 generated data at its
; pret mirror (pret engine/movie/title.asm holds DebugNewGamePlayerName/RivalName).
; Copied to W_PLAYER_NAME / W_RIVAL_NAME by PrepareTitleScreen (this file)
; and PrepareOakSpeech (oak_speech.asm). The three labels MUST stay contiguous at
; pret's exact lengths: the NAME_LENGTH(11) copies deliberately overrun, so
; wPlayerName really holds "NINTEN@SONY" on hardware — the golden caught the
; padded-to-11 version as wrong. See tools/generators/gen_debug_boot_names.py.
%include "assets/debug_boot_names.inc"   ; DebugNewGame{Player,Rival}Name + DebugNameTail

; Copyright-screen tile-index layout — a byte-exact mirror of pret title.asm's own
; hand-authored CopyrightTextString (`db $60,$61,... / next ... / db "@"`). Three lines
; of copyright-logo/font tile indices ($60-$7f); $4E = newline ("next"), $50 = end
; ("@"). Placed at surface coord (2,7) by LoadCopyrightTiles via PlaceString.
; NOT two-tier debt: these are indices into the NintendoCopyrightLogoGraphics graphic
; + font_extra, NOT gb_text-encodable glyphs — pret itself writes them as inline raw
; `db` bytes (gb_text.encode cannot map them), so the faithful port reproduces pret's
; exact bytes rather than inventing a bespoke encoder for a single custom-logo asset.
global CopyrightTextString
CopyrightTextString:
    db 0x60,0x61,0x62,0x63,0x61,0x62,0x7c,0x7f,0x65,0x66,0x67,0x68,0x69,0x6a, 0x4E             ; ©1995-1999  Nintendo
    db 0x60,0x61,0x62,0x63,0x61,0x62,0x7c,0x7f,0x6b,0x6c,0x6d,0x6e,0x6f,0x70,0x71,0x72, 0x4E    ; ©1995-1999  Creatures inc.
    db 0x60,0x61,0x62,0x63,0x61,0x62,0x7c,0x7f,0x73,0x74,0x75,0x76,0x77,0x78,0x79,0x7a,0x7b, 0x50 ; ©1995-1999  GAME FREAK inc.

; The © / GAME FREAK / Nine tile graphics (generated flat assets). pret keeps
; these in gfx data banks (NintendoCopyrightLogoGraphics / GameFreakLogoGraphics
; / NineTile); the port embeds them beside their primary consumers
; (LoadCopyrightTiles + DisplayTitleScreen). splash.asm reuses them for the ©
; boot screen.
global title_copyright_2bpp          ; = the full copyright.png (NintendoCopyrightLogoGraphics)
%include "assets/title_copyright_2bpp.inc"
global gamefreak_inc_2bpp            ; = GameFreakLogoGraphics — "GAME FREAK inc." glyphs (© screen line 3)
global nine_2bpp                     ; = NineTile — the © screen's separator glyph
%include "assets/gamefreak_inc_2bpp.inc"
%include "assets/nine_2bpp.inc"

; ---------------------------------------------------------------------------
; Code — pret's in-file order: PrepareTitleScreen (falls through into)
; DisplayTitleScreen, TitleScreenCopyTileMapToVRAM, LoadCopyrightAndTextBoxTiles
; (falls through into) LoadCopyrightTiles, DoTitleScreenFunction, CopyDebugName,
; IncrementResetCounter. (TitleScreen_PlayPikachuPCM and FillSpriteBuffer0WithAA
; are the two dropped pret labels — see the DEVIATIONs at their call sites.)
; ---------------------------------------------------------------------------
section .text

; ---------------------------------------------------------------------------
; PrepareTitleScreen — reset title-screen-relevant flags and fall through.
; Source: engine/movie/title.asm:PrepareTitleScreen
; ---------------------------------------------------------------------------
PrepareTitleScreen:
    ; Copy debug player/rival names to WRAM (matches original; overwritten later)
    lea esi, [DebugNewGamePlayerName]  ; ld hl, DebugNewGamePlayerName
    lea edi, [ebp + W_PLAYER_NAME]     ; ld de, wPlayerName
    call CopyDebugName
    lea esi, [DebugNewGameRivalName]   ; ld hl, DebugNewGameRivalName
    lea edi, [ebp + W_RIVAL_NAME]      ; ld de, wRivalName
    call CopyDebugName

    ; Zero hWY (window on-screen at y=0 initially, DisableLCD will move it)
    mov byte [ebp + H_WY], 0

    ; Clear letter-printing / status / Elite4 flags
    xor al, al
    mov byte [ebp + W_LETTER_PRINTING_DELAY], al
    mov byte [ebp + W_STATUS_FLAGS_6],        al
    mov byte [ebp + W_STATUS_FLAGS_7],        al
    mov byte [ebp + W_ELITE4_FLAGS],          al

    ; Audio ROM bank — TODO: audio HAL (Phase 3); write placeholder
    ; BANK(Music_TitleScreen) = 0 for now (stub)
    mov byte [ebp + W_AUDIO_ROM_BANK],        al
    mov byte [ebp + W_AUDIO_SAVED_ROM_BANK],  al

    ; Fall through to DisplayTitleScreen

; ---------------------------------------------------------------------------
; DisplayTitleScreen — load graphics, bounce animation, idle loop.
; Source: engine/movie/title.asm:DisplayTitleScreen
; ---------------------------------------------------------------------------
DisplayTitleScreen:
    call GBPalWhiteOut               ; the real home/fade.asm routine (BGP+OBP0/1 + CGB commits)

    ; Initialise HRAM display state
    mov byte [ebp + H_AUTO_BG_TRANSFER_EN], 1
    mov byte [ebp + H_TILE_ANIMATIONS],     0
    mov byte [ebp + H_SCX],                 0
    mov byte [ebp + H_SCY],                 0x40   ; start with SCY=64
    mov byte [ebp + H_WY],                  SCREEN_HEIGHT_PX ; pret's $90 — window off

    call ClearScreen

    ; Take over the screen as a centred 160x144 cinematic surface. This must run
    ; AFTER ClearScreen: ClearScreen is the shared pret routine and fills the
    ; whole 40x25 canvas with $7F, which would paint space tiles across the
    ; matte. MovieBeginSurface then zeroes the canvas (matte = colour zero) and
    ; publishes the descriptor, and TitleBlankSurface restores $7F to just the
    ; 20x18 rectangle — which is the projection of what pret's ClearScreen
    ; actually means on a Game Boy, where wTileMap IS the 20x18 screen.
    call MovieBeginSurface
    call TitleBlankSurface

    call DisableLCD

    ; Load the game font (needed for text tiles displayed later)
    call LoadFontTilePatterns
    call LoadTextBoxTilePatterns
    call text_engine_init

    ; Load title-screen tile graphics to VRAM (all via direct rep movsb since
    ; source is in program image, not in GB memory; CopyData is for GB→GB copies)
    pushad

    ; Nintendo copyright tiles → vChars1 tile $60 ($8E00), 5 tiles
    lea esi, [title_copyright_2bpp]
    lea edi, [ebp + VCHARS1_TILE_60]
    mov ecx, 5 * 16
    rep movsb

    ; Nine tile → vChars1 tile $6E ($8EE0), 1 tile
    lea esi, [nine_2bpp]
    lea edi, [ebp + VCHARS1_TILE_6E]
    mov ecx, 1 * 16
    rep movsb

    ; GameFreak inc. logo → vChars1 tile $65 ($8E50), 9 tiles
    lea esi, [gamefreak_inc_2bpp]
    lea edi, [ebp + VCHARS1_TILE_65]
    mov ecx, 9 * 16
    rep movsb

    ; Yellow-specific graphics (logo, corner, pikachu BG/OBJ)
    ; LoadYellowTitleScreenGFX also uses pushad/popad; safe to nest
    popad
    call LoadYellowTitleScreenGFX

    ; Fill both physical BG tilemaps with blank space, exactly pret's range:
    ; FillMemory(vBGMap0, (vBGMap1 tile $40) - vBGMap0, ' ') = $9800..$9FFF
    ; = 2048 bytes = both 32×32 tilemaps in full. (An older comment here claimed
    ; pret filled only $43F bytes — false: `vBGMap1 tile $40` is vBGMap1+$400.)
    mov esi, GB_TILEMAP0
    mov bx, (TILEMAP_AREA * 2) & 0xFFFF  ; 2 × 1024 = 2048 bytes
    mov al, 0x7F
    call FillMemory

    ; Place Pokemon logo (16×7 tiles) at tilemap coord (col=2, row=1)
    call TitleScreen_PlacePokemonLogo

    ; DEVIATION{class=HAL; pret=engine/movie/title.asm:FillSpriteBuffer0WithAA; behavior=the call is dropped, no port label exists; evidence=the routine only primes SRAM sSpriteBuffer0 with $AA through OpenSRAM/CloseSRAM and the port has no SRAM emulation (Phase 5), nothing reads the pattern before the next pic decode overwrites it; lifetime=retired when Phase 5 SRAM emulation lands}

    ; Write copyright row tiles at tilemap row 17 (bottom row)
    call WriteCopyrightTiles

    ; Save logo-only tilemap to Buffer2
    call SaveScreenTilesToBuffer2

    ; Load Buffer2 back (no-op: same content, but matches original sequence)
    call LoadScreenTilesFromBuffer2

    call EnableLCD

    ; Add Pikachu to the tilemap (logo+pikachu)
    call TitleScreen_PlacePikachu

    ; Copy logo+pikachu to physical tilemap at row 24 ($9B00)
    mov al, TILEMAP_DEST_HI_ROW24
    call TitleScreenCopyTileMapToVRAM

    ; Save logo+pikachu tilemap to Buffer1
    call SaveScreenTilesToBuffer1

    ; Turn the GB window on at y=64 for the bounce. This is load-bearing, not
    ; decoration: the row-24 copy above runs contiguously off tilemap 0 into
    ; tilemap 1 at $9C00, landing wTileMap rows 8..17 (Pikachu + the copyright
    ; line) in vBGMap1 rows 0..9. LCDC $E3 has the window enabled and mapped to
    ; $9C00, so the window at y=64 paints exactly those rows at exactly the
    ; screen position they belong to — the top 64 px bounce with hSCY while the
    ; bottom 80 px stay nailed down. Without it the copyright bounces too.
    mov byte [ebp + H_WY], 0x40
    call MovieSyncWindow

    ; Restore logo-only tilemap and copy to row 0 ($9800)
    call LoadScreenTilesFromBuffer2
    mov al, TILEMAP_DEST_HI_ROW0
    call TitleScreenCopyTileMapToVRAM

    ; pret: ld b, SET_PAL_TITLE_SCREEN / call RunPaletteCommand / call GBPalNormal
    mov bh, SET_PAL_TITLE_SCREEN        ; port contract: command in BH
    call RunPaletteCommand
    call GBPalNormal

    ; pret: ld a, %11100000 / ldh [rOBP0], a / call UpdateCGBPal_OBP0
    mov byte [ebp + IO_OBP0], 0xE0
    call UpdateCGBPal_OBP0

    ; ---------------------------------------------------------------------------
    ; Bounce animation: SCY slides from 64 → 0 with spring-damped overshoot.
    ; Table: pairs (delta, count); $00 = end of table.
    ; ---------------------------------------------------------------------------
    lea esi, [DisplayTitleScreen.TitleScreenPokemonLogoYScrolls]    ; ESI = table pointer (flat DS address)

.bounceLoop:
    movsx eax, byte [esi]             ; AL = delta (signed)
    test al, al
    jz .finishedBouncing
    inc esi
    movzx ecx, byte [esi]             ; CL = repeat count
    inc esi

    ; pret: cp -3 / jr nz,.skipPlayingSound / ld a,SFX_INTRO_CRASH / call PlaySound.
    ; The test is on the DELTA, so the crash lands on the entry that overshoots
    ; back through the logo's rest position — the -3 row, which occurs once.
    cmp al, -3
    jne .skipPlayingSound
    push eax
    push ecx
    mov al, SFX_INTRO_CRASH
    call PlaySound
    pop ecx
    pop eax
.skipPlayingSound:

.scrollStep:
    call DelayFrame
    ; hSCY += delta
    mov dl, [ebp + H_SCY]
    add dl, al
    mov [ebp + H_SCY], dl
    call MovieSyncScroll              ; hSCY -> WIN_SRC_Y, GB wrap semantics
%ifdef DEBUG_TITLE
%if TITLE_DUMP_FRAME > 0
    ; Mid-bounce capture (A2.5). The stable checkpoint cannot evidence the bounce
    ; window at all — pret parks it off-screen before then — so the only way to
    ; see the bottom-half masking is to photograph a frame while hSCY is moving.
    inc dword [title_dbg_frame]
    cmp dword [title_dbg_frame], TITLE_DUMP_FRAME
    jne .no_dump
    call DumpBackbuffer               ; never returns
.no_dump:
%endif
%endif
    loop .scrollStep                  ; ECX-- until zero

    jmp .bounceLoop

.finishedBouncing:
    ; The bounce ends at hSCY = 0, so the composition is now read from source row
    ; zero. Restore logo+pikachu and commit it to $9800 explicitly — there is no
    ; auto-BG-transfer in this port to do it on the next frame.
    call LoadScreenTilesFromBuffer1
    call MovieMirrorSurface
    call MovieSyncScroll               ; hSCY is 0 here, so WIN_SRC_Y returns to 0
    mov bl, 36
    call DelayFrames                  ; 36 frames → Pikachu appears

    mov al, SFX_INTRO_WHOOSH
    call PlaySound

    ; Add speech bubble to current wTileMap (logo+pikachu), then mirror it — the
    ; mutation has to reach the GB tilemap before the next frame samples it.
    call TitleScreen_PlacePikaSpeechBubble
    call MovieMirrorSurface
    ; Bounce is over — park the window off-screen again. Everything from here on
    ; composes on BG alone, which is why the stable checkpoint is BG-only.
    mov byte [ebp + H_WY], SCREEN_HEIGHT_PX
    call MovieSyncWindow
    call Delay3

    ; pret: ldpikacry e, PikachuCry1 / call TitleScreen_PlayPikachuPCM.
    ; The clip argument is an INDEX into PikachuCriesPointerTable, not an address.
; DEVIATION{class=banking; pret=engine/movie/title.asm:TitleScreen_PlayPikachuPCM; behavior=both PCM sites call PlayPikachuSoundClip directly instead of through the one-line TitleScreen_PlayPikachuPCM thunk; evidence=that routine's entire body is `callfar PlayPikachuSoundClip / ret`, a bank trampoline with no behavior in the port's flat model; lifetime=permanent flat-banking model}
    mov dl, PIKA_CRY_1_IDX
    call PlayPikachuSoundClip
    call WaitForSoundToFinish
    call StopAllMusic
    mov al, MUSIC_TITLE_SCREEN
    mov [ebp + wNewSoundID], al                ; pret writes it before PlaySound
    call PlaySound

    ; ---------------------------------------------------------------------------
    ; Main idle loop: blink Pikachu's eyes, wait for input, reset on timeout.
    ; ---------------------------------------------------------------------------
.loop:
%ifdef DEBUG_TITLE_REENTRY
    ; title_reentry scenario (A3). Count title visits. Visit 1 falls through to
    ; latch START below; visit 2 is the post-B-cancel re-entry and dumps the
    ; checkpoint here — the same point and settle as the `title` golden, so a
    ; clean round trip produces a byte-identical frame.
    inc dword [title_reentry_visit]
    cmp dword [title_reentry_visit], 2
    jne .reentry_no_dump
    call DelayFrame
    call DelayFrame
    call DelayFrame
    call DumpBackbuffer                ; never returns
.reentry_no_dump:
%endif
%ifdef DEBUG_TITLE
%if TITLE_DUMP_FRAME == 0 && TITLE_DUMP_SCENE == 0 && TITLE_DUMP_LOOP == 0
    ; A2.3/A2.6 pixel gate. This point is the plan's stable title checkpoint: the
    ; bounce has finished, hSCY and WIN_SRC_Y are back to zero, the logo+pikachu
    ; tilemap is installed at source row zero, the matte and centred window are
    ; published, the palette is live, MUSIC_TITLE_SCREEN has been dispatched, and
    ; no input has been consumed. Three frames settle the compositor, then the
    ; back buffer is photographed. Never returns.
    call DelayFrame
    call DelayFrame
    call DelayFrame
    call DumpBackbuffer
%endif
%endif
    ; Reset per-loop title screen state
    xor al, al
    mov byte [ebp + W_UNUSED_FLAG],            al
    mov byte [ebp + W_TITLE_SCREEN_SCENE],     al
    mov byte [ebp + W_TITLE_SCREEN_TIMER],     al
    mov byte [ebp + W_TITLE_SCREEN_SCENE + 2], al  ; reset counter low
    mov byte [ebp + W_TITLE_SCREEN_SCENE + 3], al  ; reset counter high
    mov byte [ebp + W_TITLE_SCREEN_SCENE + 4], 0x0F

.titleScreenLoop:
    call IncrementResetCounter
    jc   .doTitlescreenReset
    call DelayFrame
    call JoypadLowSensitivity
%ifdef DEBUG_MAINMENU_LIVE
    ; main_menu scenario (A3): reach the main menu by the REAL route rather than
    ; a synthetic draw. Latch START on the second idle-loop iteration so the
    ; check below takes .go_to_main_menu, which runs the genuine exit sequence
    ; (exit PCM, whiteout, ClearSprites, ClearScreen, the two tilemap blanks,
    ; LoadGBPal, MovieEndSurface) rather than jumping into MainMenu and skipping
    ; all of it.
    ;
    ; This MUST sit after JoypadLowSensitivity and before the read: put it at the
    ; end of the loop body instead and the next iteration's DelayFrame ->
    ; joypad_update and JoypadLowSensitivity both refresh hJoyHeld from the
    ; keyboard, wiping the latch before anything reads it. First attempt did
    ; exactly that and the harness sat on the title until it timed out.
    inc dword [title_dbg_frame]
    cmp dword [title_dbg_frame], 2
    jne .no_forced_start
    mov byte [ebp + H_JOY_HELD], PAD_START
.no_forced_start:
%endif
%ifdef DEBUG_TITLE_REENTRY
    ; Visit 1 only (visit 2 dumps at .loop and never reaches here): latch START
    ; on the 2nd iteration so the genuine exit sequence runs into MainMenu.
    inc dword [title_dbg_frame]
    cmp dword [title_dbg_frame], 2
    jne .reentry_no_start
    mov byte [ebp + H_JOY_HELD], PAD_START
.reentry_no_start:
%endif
%ifdef DEBUG_SOFT_RESET
    ; soft_reset scenario: latch the UP+SELECT+B reset-save combo on the 2nd idle-loop
    ; iteration (same placement as the START latch — after JoypadLowSensitivity, before
    ; the read). The combo takes .go_to_main_menu -> .doClearSaveDialogue -> jmp Init,
    ; which (post-flip) replays the boot movie.
    inc dword [title_dbg_frame]
    cmp dword [title_dbg_frame], 2
    jne .no_soft_reset
    mov byte [ebp + H_JOY_HELD], PAD_UP | PAD_SELECT | PAD_B
.no_soft_reset:
%endif
    mov al, [ebp + H_JOY_HELD]
    cmp al, PAD_UP | PAD_SELECT | PAD_B       ; secret reset-save combo
    je  .go_to_main_menu
    and al, PAD_A | PAD_START
    jnz .go_to_main_menu
    call DoTitleScreenFunction
%ifdef DEBUG_TITLE
%if TITLE_DUMP_LOOP > 0
    ; Blink-TIMING capture (A2.5). Photograph the Nth idle-loop iteration
    ; regardless of scene, so the eye state can be classified from pixels and
    ; the blink onset/duration compared against the golden trace. One DelayFrame
    ; runs per iteration, so iteration N is frame N of the idle loop.
    inc dword [title_dbg_frame]
    cmp dword [title_dbg_frame], TITLE_DUMP_LOOP
    jne .no_loop_dump
    call DumpBackbuffer               ; never returns
.no_loop_dump:
%endif
%if TITLE_DUMP_SCENE > 0
    ; Blink-state capture (A2.4). Photograph the frame on which the eye-blink
    ; state machine has reached a chosen wTitleScreenScene, so the half and
    ; closed frames are observable instead of only the open state the stable
    ; checkpoint holds. Scene numbering: 1/7 half, 4 closed, 10 open.
    cmp byte [ebp + W_TITLE_SCREEN_SCENE], TITLE_DUMP_SCENE
    jne .no_scene_dump
    call DelayFrame                   ; let the republished OAM reach the buffer
    call DumpBackbuffer               ; never returns
.no_scene_dump:
%endif
%endif
    jmp .titleScreenLoop

.go_to_main_menu:
    ; pret: ldpikacry e, PikachuCry11 / call TitleScreen_PlayPikachuPCM —
    ; the title-exit PCM beat, the second of the two.
    mov dl, PIKA_CRY_11_IDX
    call PlayPikachuSoundClip
    call GBPalWhiteOutWithDelay3
    call ClearSprites
    xor al, al
    mov byte [ebp + H_WY], al
    call MovieSyncWindow            ; hWY=0 — pret's full-screen window over the blanked maps
    inc al
    mov byte [ebp + H_AUTO_BG_TRANSFER_EN], al
    call ClearScreen
    mov al, TILEMAP_DEST_HI_ROW0
    call TitleScreenCopyTileMapToVRAM
    mov al, (GB_TILEMAP1 >> 8) & 0xFF
    call TitleScreenCopyTileMapToVRAM
    call Delay3
    call LoadGBPal                      ; pret's exact call here, now linked
    call MovieEndSurface                ; hand the screen back before any next owner

%ifdef DEBUG_SOFT_RESET
    ; soft_reset: the exit sequence above ran DelayFrame (GBPalWhiteOutWithDelay3 / Delay3),
    ; and each DelayFrame refreshes hJoyHeld from the harness keyboard — which holds nothing,
    ; so the frame-2 latch is already wiped by the time we re-check the combo below. On real
    ; hardware the player HOLDS UP+SELECT+B continuously through the exit, so the re-check
    ; still sees it; re-assert it here to model that continuous hold (the mGBA scenario holds
    ; the combo for 60 frames for exactly this reason).
    mov byte [ebp + H_JOY_HELD], PAD_UP | PAD_SELECT | PAD_B
%endif
    ; Check if the reset-save combo was pressed (PAD_UP|PAD_SELECT|PAD_B)
    mov al, [ebp + H_JOY_HELD]
    and al, PAD_UP | PAD_SELECT | PAD_B
    cmp al, PAD_UP | PAD_SELECT | PAD_B
    je  .doClearSaveDialogue

    jmp MainMenu

.doClearSaveDialogue:
%ifdef DEBUG_SOFT_RESET
    ; soft_reset golden (menu-intro B4): the UP+SELECT+B combo re-enters Init, which
    ; (post-flip) replays the boot movie. Mark it so PlayShootingStar dumps the replay.
    mov byte [g_title_reset_replay], 1
%endif
    jmp DoClearSaveDialogue            ; farjp DoClearSaveDialogue (stub: resets via Init)

.doTitlescreenReset:
    ; pret: ld [wAudioFadeOutControl], a / call StopAllMusic. `a` is $0C here —
    ; IncrementResetCounter leaves a = d = $0C on its reset path — and that value
    ; is the fade length, so it must be carried, not invented.
    mov [ebp + W_AUDIO_FADE_OUT], al
    call StopAllMusic
; DEVIATION{class=HAL; pret=engine/movie/title.asm:DisplayTitleScreen.audioFadeLoop; behavior=the fade-out wait calls DelayFrame each iteration instead of spinning on wAudioFadeOutControl alone; evidence=on the GB the audio engine runs from the VBlank interrupt so a bare spin still advances the fade, while this port ticks audio inside DelayFrame (src/home/vblank.asm calls audio_tick which calls FadeOutAudio) so a bare spin would never decrement it and would hang forever; lifetime=permanent, audio is frame-driven in this port}
.audioFadeLoop:
    call DelayFrame
    cmp byte [ebp + W_AUDIO_FADE_OUT], 0
    jnz .audioFadeLoop
    ; The timeout path re-enters Init, which does not itself restore the
    ; compositor, so the surface has to be released here too or a narrow OBJ clip
    ; and a stuck whiteout survive the reset.
    call MovieEndSurface
%ifdef DEBUG_TITLE_TIMEOUT
    ; title_timeout golden (menu-intro B4): mark that a title-screen reset just
    ; occurred, so PlayShootingStar dumps the REPLAYED copyright (the flip makes
    ; jmp Init -> PlayIntro replay the boot movie). Survives Init (host .bss, not
    ; GB WRAM). Set on the timeout path; the soft_reset combo sets it separately.
    mov byte [g_title_reset_replay], 1
%endif
    jmp Init

; ---------------------------------------------------------------------------
; TitleBlankSurface — fill the projected 20x18 rectangle with $7F (space).
;
; Port-only. The GB equivalent is ClearScreen's wTileMap fill; here that fill
; has to be rectangle-limited or it destroys the matte. Not a pret label —
; ClearScreen keeps its own name and its whole-canvas meaning for every other
; caller.
; ---------------------------------------------------------------------------
TitleBlankSurface:
    pushad
    lea edi, [ebp + W_TILEMAP + TITLE_ORIGIN]
    mov edx, UI_TITLE_GBH                 ; 18 rows
    mov al, 0x7F
.row:
    mov ecx, UI_TITLE_GBW                 ; 20 columns
    push edi
    rep stosb
    pop edi
    add edi, SCREEN_TILES_W               ; next canvas row (stride 40)
    dec edx
    jnz .row
    popad
    ret

; ---------------------------------------------------------------------------
; WriteCopyrightTiles — place ©1995-1999 GAME FREAK inc. at tilemap row 17.
; Source: engine/movie/title.asm:DisplayTitleScreen (the inline copyright-row
; write; port-local helper, not a pret label).
; ---------------------------------------------------------------------------
WriteCopyrightTiles:
    push esi
    push edi
    lea esi, [CopyrightRowTiles]
    ; projected coord(2, 17) in wTileMap (canvas stride 40, not the GB's 20)
    lea edi, [ebp + W_TILEMAP + TITLE_ORIGIN + 17 * SCREEN_TILES_W + 2]
.copy:
    mov al, [esi]
    inc esi
    cmp al, 0xFF
    je .done
    mov [edi], al
    inc edi
    jmp .copy
.done:
    pop edi
    pop esi
    ret

; ---------------------------------------------------------------------------
; TitleScreenCopyTileMapToVRAM — commit wTileMap to the GB tilemap, wait 3 frames.
; In:  AL = high byte of the GB tilemap destination.
; Source: engine/movie/title.asm:TitleScreenCopyTileMapToVRAM
;
; On the GB this only re-points hAutoBGTransferDest and lets the VBlank handler's
; auto-transfer do the copy over the following frames. This port has no
; auto-BG-transfer implementation (nothing else in the tree reads
; hAutoBGTransferDest), so the byte was being stored and the copy never happened
; — the old bespoke title got away with it because render_bg read wTileMap flat.
; Under projection the compositor samples the GB tilemap through the window
; descriptor, so the transfer has to be real. The dest byte is still written,
; because it is observable GB state that goldens compare.
;
; Rows are written byte-contiguously at the GB's 32-byte stride and are NOT
; wrapped: a row-24 destination ($9B00) genuinely runs off the end of tilemap 0
; and into tilemap 1 at $9C00, exactly as the hardware transfer would. The
; wrap belongs to the SAMPLER, not the writer — render_window re-reads rows
; mod-32 within one tilemap, which is what makes the bounce show tilemap 0's
; row 0 content once hSCY scrolls past row 31.
; ---------------------------------------------------------------------------
TitleScreenCopyTileMapToVRAM:
    mov byte [ebp + H_AUTO_BG_TRANSFER_DEST + 1], al
    pushad
    movzx edi, byte [ebp + H_AUTO_BG_TRANSFER_DEST + 1]
    shl edi, 8
    movzx edx, byte [ebp + H_AUTO_BG_TRANSFER_DEST]
    add edi, edx                          ; dest = hi:lo, as pret assembles it
    add edi, ebp
    lea esi, [ebp + W_TILEMAP + TITLE_ORIGIN]
    mov edx, UI_TITLE_GBH                 ; 18 rows
.row:
    mov ecx, UI_TITLE_GBW                 ; 20 columns
    push esi
    push edi
    rep movsb
    pop edi
    pop esi
    add esi, SCREEN_TILES_W               ; next canvas row (stride 40)
    add edi, 32                           ; next GB tilemap row (stride 32)
    dec edx
    jnz .row
    popad
    jmp Delay3    ; tail call

; ---------------------------------------------------------------------------
; LoadCopyrightAndTextBoxTiles — the boot copyright screen. Loads the textbox font
; tiles + the Nintendo copyright logo graphic to vChars2 $60, then lays out the three
; "©1995-1999  Nintendo / Creatures inc. / GAME FREAK inc." lines at surface coord
; (col 2, row 7). (+ its fall-through LoadCopyrightTiles.)
;
; The © screen's glyphs occupy vChars2 $60-$7C: copyright.png at $60-$72 (19 tiles,
; "©1995-1999" + "Nintendo" + "Creatures inc."), the "GAME FREAK inc." glyphs at
; $73-$7B (gamefreak_inc.2bpp), and the separator at $7C (nine.2bpp). On the GB these
; three graphics are laid out contiguously right after copyright.png, so pret loads
; them with a SINGLE CopyVideoData whose count spans all three (+1 font_extra overflow);
; the flat port loads the same tiles to the same slots with three copies (see the body).
; CopyrightTextString is placed through PlaceString exactly as pret does (`jp PlaceString`);
; the only projection is the drawing origin (cinematic canvas) and the 40-wide row stride.
;
; DEVIATION{class=data-model; pret=engine/movie/title.asm:LoadCopyrightTiles; behavior=pret's single CopyVideoData spanning the ROM-contiguous copyright + GameFreakLogoGraphics + NineTile + 1 font_extra overflow is issued as three separate copies (copyright 19 tiles, gamefreak_inc 9, nine 1) to the identical vChars2 slots, and the unused 1-tile font_extra overflow at $7D is omitted; evidence=those three graphics are separate flat assets in the port so a single contiguous copy is impossible, and CopyrightTextString references only $60-$7C so the $7D overflow is never displayed; lifetime=permanent flat-memory model}
; ---------------------------------------------------------------------------
global LoadCopyrightAndTextBoxTiles
LoadCopyrightAndTextBoxTiles:
    mov byte [ebp + H_WY], 0              ; ldh [hWY], a
    call ClearScreen                      ; clear the surface tilemap
    call LoadTextBoxTilePatterns          ; font_extra -> vChars2 $60-$7F
    ; fall through into LoadCopyrightTiles (a separate pret entry point)
global LoadCopyrightTiles
LoadCopyrightTiles:
    ; pret's LoadCopyrightTiles issues ONE CopyVideoData whose count spans the ROM's
    ; contiguous NintendoCopyrightLogoGraphics + GameFreakLogoGraphics + NineTile (+1
    ; font_extra overflow) — 30 tiles to vChars2 $60. In the port those are three separate
    ; flat assets, so we load them to the same contiguous slots ($60-$7C) with three copies.
    mov esi, GB_VCHARS2 + 0x60 * TILE_SIZE ; ld hl, vChars2 tile $60
    mov edx, title_copyright_2bpp          ; NintendoCopyrightLogoGraphics (copyright.2bpp)
    mov bl, 19                             ; 19 tiles -> $60-$72
    call CopyVideoData
    mov esi, GB_VCHARS2 + 0x73 * TILE_SIZE  ; GameFreakLogoGraphics (gamefreak_inc.2bpp)
    mov edx, gamefreak_inc_2bpp
    mov bl, 9                              ; 9 "GAME FREAK inc." glyphs -> $73-$7B (© line 3)
    call CopyVideoData
    mov esi, GB_VCHARS2 + 0x7C * TILE_SIZE  ; NineTile (nine.2bpp) — the © separator glyph
    mov edx, nine_2bpp
    mov bl, 1                              ; 1 tile -> $7C
    call CopyVideoData
    ; (pret's 30th tile is a 1-tile font_extra overflow at $7D that CopyrightTextString
    ; never references, so the port omits it.)
    ; hlcoord 2, 7 (projected to the cinematic origin) then jp PlaceString — pret's
    ; exact tail call. PlaceString advances <NEXT> by 2*stride (double-spaced: the pret
    ; default, since BIT_SINGLE_SPACED_LINES is clear through boot), so the three lines
    ; land on surface rows 7 / 9 / 11 exactly as the GB — NOT the consecutive 7/8/9 a
    ; hand-rolled single-spaced loop would produce. text_row_stride is the port's runtime
    ; equivalent of pret's compile-time SCREEN_WIDTH; set it to the 40-wide cinematic
    ; canvas so a row step is one surface row.
    mov dword [text_row_stride], SCREEN_TILES_W
    mov esi, W_TILEMAP + INTRO_BG_ORIGIN + 7 * SCREEN_TILES_W + 2  ; ld hl, projected coord(2,7) — GB offset
    mov eax, CopyrightTextString                                   ; ld de, CopyrightTextString (flat src)
    jmp PlaceString                                                ; jp PlaceString

; ---------------------------------------------------------------------------
; DoTitleScreenFunction — drive Pikachu eye-blink state machine.
; Source: engine/movie/title.asm:DoTitleScreenFunction
;
; Jumptable (12 entries, indexed by wTitleScreenScene 0-11):
;   0→Nop, 1→BlinkHalf, 2-3→BlinkWait, 4→BlinkClosed, 5-6→BlinkWait,
;   7→BlinkHalf, 8-9→BlinkWait, 10→BlinkOpen, 11→GoBackToStart
; ---------------------------------------------------------------------------
DoTitleScreenFunction:
    call .CheckTimer
    movzx eax, byte [ebp + W_TITLE_SCREEN_SCENE]
    cmp al, 11
    ja .Nop           ; clamp out-of-range scenes
    lea edi, [.Jumptable]
    jmp [edi + eax * 4]

section .data
.Jumptable:
    dd .Nop, .BlinkHalf, .BlinkWait, .BlinkWait, .BlinkClosed
    dd .BlinkWait, .BlinkWait, .BlinkHalf, .BlinkWait, .BlinkWait
    dd .BlinkOpen, .GoBackToStart

section .text

.GoBackToStart:
    mov byte [ebp + W_TITLE_SCREEN_SCENE], 0
.Nop:
    ret

.BlinkOpen:
    xor dl, dl
    jmp .LoadBlinkFrame
.BlinkHalf:
    mov dl, 4
    jmp .LoadBlinkFrame
.BlinkClosed:
    mov dl, 8
.LoadBlinkFrame:
    ; Modify TileID byte of 8 OAM sprites: clear bits 2-3, OR with DL (blink state).
    ; A2.4 republishes after this mutation so the change reaches the next frame.
    lea esi, [ebp + W_SHADOW_OAM + 2]    ; TileID of sprite 0
    mov ecx, 8
.blink_loop:
    mov al, [esi]
    and al, 0xF3
    or  al, dl
    mov [esi], al
    add esi, 4                             ; advance to next sprite's TileID
    dec ecx
    jnz .blink_loop
    ; The tile IDs changed; republish so the new blink frame is what gets drawn.
    call TitleScreenPublishEyes
.BlinkWait:
    inc byte [ebp + W_TITLE_SCREEN_SCENE]
    ret

.CheckTimer:
    push eax
    lea esi, [ebp + W_TITLE_SCREEN_TIMER]
    mov al, [esi]
    inc byte [esi]
    test al, al
    jz .restart
    cmp al, 0x80
    je .restart
    cmp al, 0x90
    jne .timer_done
.restart:
    mov byte [ebp + W_TITLE_SCREEN_SCENE], 1
.timer_done:
    pop eax
    ret

; ---------------------------------------------------------------------------
; CopyDebugName — copy one NAME_LENGTH debug boot name (pret engine/movie/
; title.asm:CopyDebugName: ld bc, NAME_LENGTH / jp CopyData; the source is
; program-image data here, so the CopyData tail is a flat rep movsb).
; In: ESI = flat source name, EDI = flat dest (EBP-biased). Clobbers ECX/ESI/EDI.
; ---------------------------------------------------------------------------
global CopyDebugName
CopyDebugName:
    mov ecx, NAME_LENGTH               ; ld bc, NAME_LENGTH
    rep movsb                          ; jp CopyData
    ret

; ---------------------------------------------------------------------------
; IncrementResetCounter — increment the 16-bit inactivity counter at
; wTitleScreenScene+2/+3. Sets CF if high byte reaches $0C (~51 s at 60 Hz).
; Source: engine/movie/title.asm:IncrementResetCounter
; ---------------------------------------------------------------------------
IncrementResetCounter:
    pushad
    lea esi, [ebp + W_TITLE_SCREEN_SCENE + 2]
    movzx eax, byte [esi]       ; lo byte of counter
    movzx edx, byte [esi + 1]   ; hi byte of counter
    inc eax
%ifdef DEBUG_TITLE_TIMEOUT
    ; title_timeout golden: fire the reset after ~40 idle frames instead of the real
    ; $0C00 (~3072), so the headless run stays well under the 150 s cap. The REPLAY
    ; ROUTE is identical — only the wait is shortened; the mGBA side uses the ROM's
    ; real $0C00 timeout to generate the golden (both reach the same replay copyright).
    cmp eax, 40
    jae .do_reset
%endif
    cmp eax, 0x100
    jb .no_carry
    xor eax, eax
    inc edx
.no_carry:
    cmp edx, 0x0C
    je .do_reset
    mov [esi],     al
    mov [esi + 1], dl
    popad
    clc
    ret
.do_reset:
    popad
    ; pret returns here with a = d = $0C (it loaded d into a for the `cp $c`
    ; that detected the reset). .doTitlescreenReset stores that byte as the
    ; audio fade length, so the value is load-bearing — popad would otherwise
    ; hand back whatever the caller had in AL.
    mov al, 0x0C
    stc                                 ; mov does not disturb CF
    ret
