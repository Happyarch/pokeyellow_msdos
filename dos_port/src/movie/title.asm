; title.asm — PrepareTitleScreen / DisplayTitleScreen and helpers.
;
; Source: engine/movie/title.asm, engine/movie/title_yellow.asm,
;         home/tilemap.asm (SaveScreenTiles/LoadScreenTiles)
;
; Animation overview:
;   1. Load all title graphics to VRAM.
;   2. Place Pokemon logo (no pikachu) in wTileMap; save to Buffer2.
;   3. Add pikachu to wTileMap; copy to physical tilemap at $9B00 (row 24);
;      save to Buffer1.  hSCY = 64.
;   4. Restore Buffer2 (logo only); copy to physical tilemap at $9800 (row 0).
;   5. Bounce hSCY from 64 → 0 over ~32 frames (DelayFrame each step).
;      (Historical: do_bg_transfer used to re-copy wTileMap → $9800 each
;      DelayFrame; it is retired — render_bg's flat path reads wTileMap
;      directly, so the physical-tilemap copies here are write-only noise and
;      the H_AUTO_BG_TRANSFER_EN/DEST writes below are vestigial bookkeeping.)
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
; NOT boundaries any more — the former TODO-HW block here was stale and is
; deleted rather than carried: every routine it disclaimed is a linked
; implementation (project_state, 2026-07-20). PlaySound (35 callers),
; StopAllMusic (9), PlayMusic (11), PlayPikachuSoundClip, RunPaletteCommand
; (14), UpdateCGBPal_OBP0 (5), GBPalNormal (13) are all live, and the OBP0 note
; ("no sprite renderer yet") predates render_sprites. A comment asserting a
; capability is missing is a claim like any other: it needs evidence, and these
; had gone false without anyone noticing.
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
%include "assets/ui_layout_intro.inc"   ; UI_TITLE_* projected surface geometry

; ---------------------------------------------------------------------------
; Externs
; ---------------------------------------------------------------------------
extern FillMemory
extern DisableLCD
extern EnableLCD
extern ClearSprites
extern LoadFontTilePatterns
extern LoadTextBoxTilePatterns
extern text_engine_init
extern DelayFrame
extern DelayFrames
extern Delay3
extern GBPalNormal
extern Init
extern EnterMapBoot              ; overworld.asm — one-time overworld boot glue → EnterMap
extern OakSpeech                 ; main_menu_stubs.asm — new-game data init (InitPlayerData2)
extern g_tilecache_dirty
extern JoypadLowSensitivity     ; src/home/joypad_lowsens.asm (home/joypad2.asm)
extern PlaySound                ; src/home/audio.asm — AL = sound id
extern StopAllMusic             ; src/home/audio.asm
extern WaitForSoundToFinish     ; src/home/audio.asm
extern PlayPikachuSoundClip     ; src/engine/pikachu/pikachu_pcm.asm — DL = clip index (pret: E)
extern RunPaletteCommand        ; src/home/palettes.asm — BH = palette command
extern UpdateCGBPal_OBP0        ; src/home/cgb_palettes.asm
extern GBPalWhiteOutWithDelay3  ; src/home/fade.asm
extern LoadGBPal                ; src/home/fade.asm
extern MovieBeginSurface        ; src/engine/movie/movie_projection.asm
extern MovieEndSurface          ; src/engine/movie/movie_projection.asm
extern MovieMirrorSurface       ; src/engine/movie/movie_projection.asm
extern MovieSyncScroll          ; src/engine/movie/movie_projection.asm
%ifdef DEBUG_TITLE
extern DumpBackbuffer           ; src/debug/debug_dump.asm — writes FRAME.BIN + exits
%endif

; ---------------------------------------------------------------------------
; Globals
; ---------------------------------------------------------------------------
global PrepareTitleScreen
global DisplayTitleScreen        ; MainMenu "B returns to title" seam (retires main_menu_stubs.asm stub)
global ClearScreen
global SaveScreenTilesToBuffer2  ; home/start_menu.asm — first *linked* caller (pret: home/tilemap.asm)
global LoadScreenTilesFromBuffer2 ; engine/menus/pc.asm — first *linked* caller (pret: home/tilemap.asm).
                                  ; The body has been here all along; only the export was missing, which is
                                  ; why pc.asm/oaks_pc.asm/players_pc.asm each "replaced" it with a window-
                                  ; count shim (menu-fidelity row 17 / M-80).

; ---------------------------------------------------------------------------
; Constants
; ---------------------------------------------------------------------------
NAME_LENGTH          equ 11      ; wPlayerName / wRivalName field size

; LCDC bit 7 — LCD enable (used by EnableLCD/DisableLCD in lcd_control.asm)
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

SCREEN_HEIGHT_PX     equ 144     ; pret's hWY "hide the window layer" value (see .hWY note below)

; Projected drawing origin. The title composes a Game Boy 20x18 screen, but
; wTileMap here is the port's 40x25 canvas, so every placement pret writes at
; coord(col,row) lands at coord(col+UI_TITLE_COL, row+UI_TITLE_ROW). Keeping
; pret's own col/row literals at the call sites and adding this one offset means
; the coordinates stay diffable against the disassembly instead of becoming
; pre-baked canvas numbers. Geometry comes from the generated layout, never a
; literal 10/3.
TITLE_ORIGIN         equ UI_TITLE_ROW * SCREEN_TILES_W + UI_TITLE_COL

; VRAM tile destination constants
VCHARS1_TILE_60      equ GB_VFONT + 0x60 * 16   ; = $8E00  (copyright tiles)
VCHARS1_TILE_65      equ GB_VFONT + 0x65 * 16   ; = $8E50  (GameFreak logo)
VCHARS1_TILE_6E      equ GB_VFONT + 0x6E * 16   ; = $8EE0  (Nine tile)
VCHARS1_TILE_70      equ GB_VFONT + 0x70 * 16   ; = $8F00  (Pikachu OBJ sprites)
VCHARS1_TILE_7D      equ GB_VFONT + 0x7D * 16   ; = $8FD0  (logo corner tiles)

; Tilemap destination addresses (high bytes passed to TitleScreenCopyTileMapToVRAM)
TILEMAP_DEST_HI_ROW0 equ (GB_TILEMAP0 >> 8)      ; $98  → $9800 (row 0)
TILEMAP_DEST_HI_ROW24 equ ((GB_TILEMAP0 + 0x300) >> 8) ; $9B → $9B00 (row 24)

; ---------------------------------------------------------------------------
; Data
; ---------------------------------------------------------------------------
section .data
align 4

; Pikachu eye OAM data — 8 sprites × 4 bytes = 32 bytes
; Copied to wShadowOAM by TitleScreen_PlacePikachu.
; (The old "OAM renderer not yet implemented" note here was stale: render_sprites
; has emulated DMG OBJ since the Phase-1 OAM pass. A2.4 routes these records
; through PublishProjectedOAM so they land on the centred cinematic surface.)
TitleScreenPikachuEyesOAMData:
    db 0x60, 0x40, 0xf1, 0x22
    db 0x60, 0x48, 0xf0, 0x22
    db 0x68, 0x40, 0xf3, 0x22
    db 0x68, 0x48, 0xf2, 0x22
    db 0x60, 0x60, 0xf0, 0x02
    db 0x60, 0x68, 0xf1, 0x02
    db 0x68, 0x60, 0xf2, 0x02
    db 0x68, 0x68, 0xf3, 0x02

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

; Debug player/rival names (pret charmap encoding).
; Copied to W_PLAYER_NAME / W_RIVAL_NAME in PrepareTitleScreen.
; N=$8D I=$88 N=$8D T=$93 E=$84 N=$8D @=$50 (terminator)
DebugPlayerName:
    db 0x8D,0x88,0x8D,0x93,0x84,0x8D,0x50,0x50,0x50,0x50,0x50
; S=$92 O=$8E N=$8D Y=$98 @=$50
DebugRivalName:
    db 0x92,0x8E,0x8D,0x98,0x50,0x50,0x50,0x50,0x50,0x50,0x50

; ---------------------------------------------------------------------------
; Tile graphics and tilemaps (generated by tools/generators/gen_title_gfx_inc.py)
; ---------------------------------------------------------------------------
%include "assets/pokemon_logo_2bpp.inc"
%include "assets/pokemon_logo_corner_2bpp.inc"
%include "assets/pikachu_bg_2bpp.inc"
%include "assets/pikachu_ob_2bpp.inc"
%include "assets/title_copyright_2bpp.inc"
%include "assets/gamefreak_inc_2bpp.inc"
%include "assets/nine_2bpp.inc"
%include "assets/pokemon_logo_tilemap.inc"
%include "assets/pikachu_tilemap.inc"
%include "assets/pika_bubble_tilemap.inc"

; ---------------------------------------------------------------------------
; Code
; ---------------------------------------------------------------------------
section .text

; ---------------------------------------------------------------------------
; PrepareTitleScreen — reset title-screen-relevant flags and fall through.
; Source: engine/movie/title.asm:PrepareTitleScreen
; ---------------------------------------------------------------------------
PrepareTitleScreen:
    ; Copy debug player/rival names to WRAM (matches original; overwritten later)
    lea esi, [DebugPlayerName]         ; flat address of our data
    lea edi, [ebp + W_PLAYER_NAME]
    mov ecx, NAME_LENGTH
    rep movsb
    lea esi, [DebugRivalName]
    lea edi, [ebp + W_RIVAL_NAME]
    mov ecx, NAME_LENGTH
    rep movsb

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
    call Title_GBPalWhiteOut

    ; Initialise HRAM display state
    mov byte [ebp + H_AUTO_BG_TRANSFER_EN], 1
    mov byte [ebp + H_TILE_ANIMATIONS],     0
    mov byte [ebp + H_SCX],                 0
    mov byte [ebp + H_SCY],                 0x40   ; start with SCY=64
    mov byte [ebp + H_WY],                  RENDER_H ; window off-screen (200)

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

    ; Fill physical BG tilemap 0 + first half of tilemap 1 with blank space.
    ; Original: FillMemory(vBGMap0, (vBGMap1+$40*32)-vBGMap0, ' ')
    ; = $9800..$9C3F = $43F bytes. We fill the whole tilemap0 + 64 rows of TM1.
    ; Simplification: fill both tilemaps entirely with $7F (space).
    mov esi, GB_TILEMAP0
    mov bx, (TILEMAP_AREA * 2) & 0xFFFF  ; 2 × 1024 = 2048 bytes
    mov al, 0x7F
    call FillMemory

    ; Place Pokemon logo (16×7 tiles) at tilemap coord (col=2, row=1)
    call TitleScreen_PlacePokemonLogo

    ; FillSpriteBuffer0WithAA — SRAM not emulated; stub no-op.
    ; ; TODO-HW: fill sSpriteBuffer0 with $AA when SRAM is emulated.

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
    call Title_SaveScreenTilesToBuffer1

    ; pret here is `ld a, $40 / ldh [hWY], a` — it turns the GB WINDOW ON at
    ; y=64 for the duration of the bounce. The port had `mov [H_SCY], 0x40`,
    ; which is a mistranslation twice over: hSCY was already set to $40 at the
    ; top of DisplayTitleScreen, so the write was a dead duplicate, and pret's
    ; actual hWY write was dropped on the floor.
    ;
    ; What that window does is load-bearing, not decoration. The row-24 copy
    ; above runs contiguously off tilemap 0 into tilemap 1 at $9C00, which lands
    ; wTileMap rows 8..17 (Pikachu + the copyright line) in vBGMap1 rows 0..9.
    ; LCDC $E3 has the window enabled and mapped to $9C00, so the window at y=64
    ; paints exactly those rows at exactly the screen position they belong to.
    ; The result: the top 64 px bounce with hSCY while the bottom 80 px stay
    ; nailed down. Without it the copyright line bounces along with the logo.
; STUB{class=temporary; label=DisplayTitleScreen.bounceWindow; pret=engine/movie/title.asm:DisplayTitleScreen; behavior=pret's `ld a, $40 / ldh [hWY], a` window-enable for the bounce is not translated, so the whole surface bounces instead of only its top 64 px; evidence=the port publishes ONE window descriptor and MovieBeginSurface has already claimed it for the cinematic surface itself, so reproducing pret's window layer needs a SECOND descriptor over the projected rect at source row 8 — that is an A2.5 change, not a one-line write; lifetime=A2.5, when the mid-bounce pixel captures make the bottom-half masking observable}

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
    loop .scrollStep                  ; ECX-- until zero

    jmp .bounceLoop

.finishedBouncing:
    ; The bounce ends at hSCY = 0, so the composition is now read from source row
    ; zero. Restore logo+pikachu and commit it to $9800 explicitly — there is no
    ; auto-BG-transfer in this port to do it on the next frame.
    call Title_LoadScreenTilesFromBuffer1
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
; DEVIATION{class=projection; pret=engine/movie/title.asm:DisplayTitleScreen; behavior=pret's `ld a, SCREEN_HEIGHT_PX / ldh [hWY], a` here is dropped instead of translated; evidence=this write turns the GB window layer back OFF after the bounce used it (pret enables it at hWY=$40 before the bounce, see the STUB above), so it only matters once that window exists in the port, and meanwhile writing it is actively harmful — the port's single descriptor IS the cinematic surface, set_single_window mirrors its wy into hWY, and any write here corrupts that mirror and trips the sync_dialog_window hWY==RENDER_H closed-gate; lifetime=A2.5, revisit together with the bounce window it disables}
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
%ifdef DEBUG_TITLE
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
    mov al, [ebp + H_JOY_HELD]
    cmp al, PAD_UP | PAD_SELECT | PAD_B       ; secret reset-save combo
    je  .go_to_main_menu
    and al, PAD_A | PAD_START
    jnz .go_to_main_menu
    call DoTitleScreenFunction
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

    ; Check if the reset-save combo was pressed (PAD_UP|PAD_SELECT|PAD_B)
    mov al, [ebp + H_JOY_HELD]
    and al, PAD_UP | PAD_SELECT | PAD_B
    cmp al, PAD_UP | PAD_SELECT | PAD_B
    je  .doClearSaveDialogue

    ; jp MainMenu → EnterMap (Phase 2: load Pallet Town directly). MainMenu's
    ; new-game path is StartNewGame → OakSpeech → SpecialEnterMap; OakSpeech's
    ; ported prologue (InitPlayerData2) seeds the party/box/bag list terminators,
    ; so a new game does not boot with garbage inventories (docs/glitch_safety.md).
    call OakSpeech
    jmp EnterMapBoot

.doClearSaveDialogue:
    ; DoClearSaveDialogue — ; TODO: save clear screen (Phase 5). Reset for now.
    jmp Init

.doTitlescreenReset:
    ; pret: ld [wAudioFadeOutControl], a / call StopAllMusic. `a` is $0C here —
    ; IncrementResetCounter leaves a = d = $0C on its reset path — and that value
    ; is the fade length, so it must be carried, not invented.
    mov [ebp + W_AUDIO_FADE_OUT], al
    call StopAllMusic
; DEVIATION{class=HAL; pret=engine/movie/title.asm:DisplayTitleScreen.audioFadeLoop; behavior=the fade-out wait calls DelayFrame each iteration instead of spinning on wAudioFadeOutControl alone; evidence=on the GB the audio engine runs from the VBlank interrupt so a bare spin still advances the fade, while this port ticks audio inside DelayFrame (frame.asm calls audio_tick which calls FadeOutAudio) so a bare spin would never decrement it and would hang forever; lifetime=permanent, audio is frame-driven in this port}
.audioFadeLoop:
    call DelayFrame
    cmp byte [ebp + W_AUDIO_FADE_OUT], 0
    jnz .audioFadeLoop
    ; The timeout path re-enters Init, which does not itself restore the
    ; compositor, so the surface has to be released here too or a narrow OBJ clip
    ; and a stuck whiteout survive the reset.
    call MovieEndSurface
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
; WriteCopyrightTiles — place ©1995-1999 GAME FREAK inc. at tilemap row 17.
; Source: engine/movie/title.asm:.WriteCopyrightTiles
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
; ClearScreen — fill wTileMap with $7F (space), enable auto-BG-transfer,
; wait 3 frames.
; Source: home/copy2.asm:ClearScreen
; ---------------------------------------------------------------------------
ClearScreen:
    push esi
    push ebx
    push eax
    mov esi, W_TILEMAP
    mov bx,  SCREEN_AREA & 0xFFFF
    mov al,  0x7F
    call FillMemory
    mov byte [ebp + H_AUTO_BG_TRANSFER_EN], 1
    pop eax
    pop ebx
    pop esi
    jmp Delay3    ; tail call

; ---------------------------------------------------------------------------
; GBPalWhiteOut — white out all palettes (BGP + both OBJ palettes).
; Source: home/palettes.asm:GBPalWhiteOut — zeroes rBGP, rOBP0, rOBP1 (then
; calls UpdateCGBPal_{BGP,OBP0,OBP1}; the CGB pal commit is Phase 5).
; Zeroing OBP0/OBP1 is required so sprites white out too, not just the BG.
; ---------------------------------------------------------------------------
Title_GBPalWhiteOut:
    mov byte [ebp + IO_BGP],  0x00
    mov byte [ebp + IO_OBP0], 0x00
    mov byte [ebp + IO_OBP1], 0x00
    ret

; JoypadLowSensitivity now lives in src/input/joypad_lowsens.asm (faithful
; auto-repeat translation of home/joypad2.asm); the local stub is gone. The
; .titleScreenLoop above already calls it then reads [hJoyHeld], matching pret
; engine/movie/title.asm:166-167.

; ---------------------------------------------------------------------------
; SaveScreenTilesToBuffer1 — copy wTileMap → wTileMapBackup.
; Source: home/tilemap.asm:SaveScreenTilesToBuffer1
; ---------------------------------------------------------------------------
Title_SaveScreenTilesToBuffer1:
    pushad
    lea esi, [ebp + W_TILEMAP]
    lea edi, [ebp + W_TILEMAP_BACKUP]
    mov ecx, SCREEN_AREA
    rep movsb
    popad
    ret

; ---------------------------------------------------------------------------
; SaveScreenTilesToBuffer2 — copy wTileMap → wTileMapBackup2.
; Source: home/tilemap.asm:SaveScreenTilesToBuffer2
; ---------------------------------------------------------------------------
SaveScreenTilesToBuffer2:
    pushad
    lea esi, [ebp + W_TILEMAP]
    lea edi, [ebp + W_TILEMAP_BACKUP2]
    mov ecx, SCREEN_AREA
    rep movsb
    popad
    ret

; ---------------------------------------------------------------------------
; LoadScreenTilesFromBuffer1 — disable auto-BG, copy wTileMapBackup → wTileMap,
; re-enable auto-BG.
; Source: home/tilemap.asm:LoadScreenTilesFromBuffer1
; ---------------------------------------------------------------------------
Title_LoadScreenTilesFromBuffer1:
    pushad
    mov byte [ebp + H_AUTO_BG_TRANSFER_EN], 0
    lea esi, [ebp + W_TILEMAP_BACKUP]
    lea edi, [ebp + W_TILEMAP]
    mov ecx, SCREEN_AREA
    rep movsb
    mov byte [ebp + H_AUTO_BG_TRANSFER_EN], 1
    popad
    ret

; ---------------------------------------------------------------------------
; LoadScreenTilesFromBuffer2 — disable auto-BG, copy wTileMapBackup2 → wTileMap,
; re-enable auto-BG.
; Source: home/tilemap.asm:LoadScreenTilesFromBuffer2
; ---------------------------------------------------------------------------
LoadScreenTilesFromBuffer2:
    pushad
    mov byte [ebp + H_AUTO_BG_TRANSFER_EN], 0
    lea esi, [ebp + W_TILEMAP_BACKUP2]
    lea edi, [ebp + W_TILEMAP]
    mov ecx, SCREEN_AREA
    rep movsb
    mov byte [ebp + H_AUTO_BG_TRANSFER_EN], 1
    popad
    ret

; ---------------------------------------------------------------------------
; LoadYellowTitleScreenGFX — load all Pokemon Yellow title tile graphics.
; Source: engine/movie/title_yellow.asm:LoadYellowTitleScreenGFX
;
; VRAM layout (signed tile mode, LCDC_DEFAULT=$E3, bit4=0, base $9000):
;   $9000 (vChars2)           ← Pokemon logo main tiles (128 tiles = $800 bytes)
;   $8FD0 (vChars1 tile $7D)  ← Logo corner tiles (3 tiles = $30 bytes)
;   $8800 (vChars1)           ← Pikachu BG tiles (64 tiles = $400 bytes)
;   $8F00 (vChars1 tile $70)  ← Pikachu OBJ sprite tiles (12 tiles = $C0 bytes)
; ---------------------------------------------------------------------------
LoadYellowTitleScreenGFX:
    pushad
    mov byte [g_tilecache_dirty], 1     ; VRAM tile data changes → rebuild decode cache

    ; Pokemon logo → vChars2 ($9000), 128 tiles
    lea esi, [pokemon_logo_2bpp]
    lea edi, [ebp + GB_VCHARS2]
    mov ecx, POKEMON_LOGO_2BPP_SIZE
    rep movsb

    ; Logo corner tiles → vChars1 tile $7D ($8FD0), 3 tiles
    lea esi, [pokemon_logo_corner_2bpp]
    lea edi, [ebp + VCHARS1_TILE_7D]
    mov ecx, POKEMON_LOGO_CORNER_2BPP_SIZE
    rep movsb

    ; Pikachu BG tiles → vChars1 ($8800), 64 tiles
    lea esi, [pikachu_bg_2bpp]
    lea edi, [ebp + GB_VFONT]
    mov ecx, PIKACHU_BG_2BPP_SIZE
    rep movsb

    ; Pikachu OBJ sprite tiles → vChars1 tile $70 ($8F00), 12 tiles
    lea esi, [pikachu_ob_2bpp]
    lea edi, [ebp + VCHARS1_TILE_70]
    mov ecx, PIKACHU_OB_2BPP_SIZE
    rep movsb

    popad
    ret

; ---------------------------------------------------------------------------
; TitleScreen_PlacePokemonLogo — copy 16×7 logo tilemap into wTileMap at (2,1).
; Source: engine/movie/title_yellow.asm:TitleScreen_PlacePokemonLogo
; ---------------------------------------------------------------------------
TitleScreen_PlacePokemonLogo:
    pushad
    lea esi, [pokemon_logo_tilemap]
    ; dest = wTileMap + projected coord(2, 1)
    lea edi, [ebp + W_TILEMAP + TITLE_ORIGIN + 1 * SCREEN_TILES_W + 2]
    mov ebx, POKEMON_LOGO_TILEMAP_HEIGHT   ; 7 rows
.logo_row:
    mov ecx, POKEMON_LOGO_TILEMAP_WIDTH    ; 16 tiles per row
    rep movsb
    add edi, SCREEN_TILES_W - POKEMON_LOGO_TILEMAP_WIDTH  ; next canvas row (stride 40)
    dec ebx
    jnz .logo_row
    popad
    ret

; ---------------------------------------------------------------------------
; TitleScreen_PlacePikachu — add pikachu tilemap (12×9) to wTileMap at (4,8),
; place tail tiles, and copy eye OAM data to wShadowOAM.
; Source: engine/movie/title_yellow.asm:TitleScreen_PlacePikachu
; ---------------------------------------------------------------------------
TitleScreen_PlacePikachu:
    pushad

    ; Place 12×9 pikachu tilemap at coord (col=4, row=8)
    lea esi, [pikachu_tilemap]
    lea edi, [ebp + W_TILEMAP + TITLE_ORIGIN + 8 * SCREEN_TILES_W + 4]
    mov ebx, PIKACHU_TILEMAP_HEIGHT       ; 9 rows
.pika_row:
    mov ecx, PIKACHU_TILEMAP_WIDTH        ; 12 tiles per row
    rep movsb
    add edi, SCREEN_TILES_W - PIKACHU_TILEMAP_WIDTH  ; skip remaining 8 cols
    dec ebx
    jnz .pika_row

    ; Place extra tail/overlap tiles at column 16, rows 10-13
    mov byte [ebp + W_TILEMAP + TITLE_ORIGIN + 10 * SCREEN_TILES_W + 16], 0x96
    mov byte [ebp + W_TILEMAP + TITLE_ORIGIN + 11 * SCREEN_TILES_W + 16], 0x9D
    mov byte [ebp + W_TILEMAP + TITLE_ORIGIN + 12 * SCREEN_TILES_W + 16], 0xA7
    mov byte [ebp + W_TILEMAP + TITLE_ORIGIN + 13 * SCREEN_TILES_W + 16], 0xB1

    ; Copy eye OAM data to wShadowOAM (32 bytes = 8 sprites × 4 bytes).
    ; Canonical OAM only — A2.4 publishes it to the projected surface.
    lea esi, [TitleScreenPikachuEyesOAMData]
    lea edi, [ebp + W_SHADOW_OAM]
    mov ecx, 32
    rep movsb

    popad
    ret

; ---------------------------------------------------------------------------
; TitleScreen_PlacePikaSpeechBubble — place 7×4 speech bubble at (6,4)
; and overlay two logo tiles at (9,8).
; Source: engine/movie/title_yellow.asm:TitleScreen_PlacePikaSpeechBubble
; ---------------------------------------------------------------------------
TitleScreen_PlacePikaSpeechBubble:
    pushad

    ; 7×4 bubble tilemap at coord (col=6, row=4)
    lea esi, [pika_bubble_tilemap]
    lea edi, [ebp + W_TILEMAP + TITLE_ORIGIN + 4 * SCREEN_TILES_W + 6]
    mov ebx, PIKA_BUBBLE_TILEMAP_HEIGHT   ; 4 rows
.bubble_row:
    mov ecx, PIKA_BUBBLE_TILEMAP_WIDTH    ; 7 tiles per row
    rep movsb
    add edi, SCREEN_TILES_W - PIKA_BUBBLE_TILEMAP_WIDTH
    dec ebx
    jnz .bubble_row

    ; Two logo-area tiles placed at (9,8) and (10,8)
    ; $64 = logo tile 100 (signed + → vChars2), $65 = logo tile 101
    mov byte [ebp + W_TILEMAP + TITLE_ORIGIN + 8 * SCREEN_TILES_W + 9],  0x64
    mov byte [ebp + W_TILEMAP + TITLE_ORIGIN + 8 * SCREEN_TILES_W + 10], 0x65

    popad
    ret

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
