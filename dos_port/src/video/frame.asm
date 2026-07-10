; frame.asm — DelayFrame / DelayFrames / Delay3 and the per-frame pipeline.
;
; Source: home/vblank.asm:DelayFrame, home/delay.asm:DelayFrames
;
; In the GB, the VBlank ISR handles shadow-register commits, auto-BG transfer,
; and OAM DMA every frame. In the DOS port these are folded into DelayFrame so
; that any call to DelayFrame (the standard "yield one frame" primitive) triggers
; a full render + input update, matching the original VBlank-driven timing.
;
; pret's hAutoBGTransferEnabled VBlank transfer (wTileMap → physical BG map) has
; NO runtime analog here — see the retirement note above DelayFrame's transfer
; phase. Screens that need their staging visible mirror it explicitly into their
; window descriptor's GB_TILEMAP0/1 band (list_mirror / options_mirror /
; pdex_mirror / sm_canvas_mirror / …), usually re-armed per frame via
; menu_redraw_cb. The faithful `hAutoBGTransferEnabled` writes throughout the
; menu code are vestigial pret-fidelity bookkeeping that nothing reads.
;
; Build: nasm -f coff -I include/ -o frame.o frame.asm

bits 32

%include "gb_memmap.inc"
%include "gb_macros.inc"

%ifdef DEBUG_SEAM_LIVE
%ifndef DEBUG_SEAM_NOLOG
extern SeamLogRecord     ; src/debug/debug_dump.asm (DEBUG_SEAM_LIVE trace)
%endif
%endif
extern wait_vblank
extern wait_pit_tick
extern audio_tick            ; src/audio/audio_hal.asm — pret VBlank audio block
extern commit_palette
extern render_bg
extern render_window
extern g_windows
extern g_window_count
extern render_sprites
extern draw_player_marker
extern present
extern joypad_update
extern pad_quit
extern cleanup
extern PrepareOAMData
extern TrackPlayTime         ; M2.1: advance play clock + CountDownIgnoreInputBitReset (src/util/play_time.asm)
extern Random                ; src/home/random.asm — pret VBlank RNG churn (home/vblank.asm:43)
%ifdef DEBUG_AUTOKEY
extern AutoKeyDrive          ; src/debug/debug_dump.asm
%endif
extern UpdateMovingBgTiles   ; M2.2: BG tile-animation step (self-gates on hTileAnimations)
extern VBlankCopyBgMap       ; M2.2: staged BG-map copy (self-gates on its row-count)
%ifdef DEBUG_NPC_WALK
extern DumpNpcLog       ; dump NPC walk-decision log to NPCLOG.BIN on quit
%endif
%ifdef DEBUG_WALKSPEED
extern DebugDumpMemory  ; dump ticks-per-tile stats to DUMP.BIN on quit
%endif

global DelayFrame
global DelayFrames
global Delay3

; ---------------------------------------------------------------------------
; Symbol not yet in gb_memmap.inc. Defined %ifndef-safe with its sym-verified
; address (see SUMMARY.md) so this file assembles standalone; when root promotes
; it to the canonical memmap that definition wins.
; ---------------------------------------------------------------------------
%ifndef W_DISABLE_VBLANK_WY_UPDATE
W_DISABLE_VBLANK_WY_UPDATE   equ 0xD09F   ; wDisableVBlankWYUpdate — nonzero = skip WY commit
%endif

section .text

; ---------------------------------------------------------------------------
; DelayFrame — sync to 60 Hz, run full per-frame pipeline.
;
; Mirrors what the GB VBlank ISR does:
;   commit shadow registers → staged BG copies/animations → OAM
;   → joypad update → BG render → windows → blit → check host-quit
;
; Out: all registers preserved. May call cleanup+exit if Esc was pressed.
; ---------------------------------------------------------------------------
DelayFrame:
    pushad
    call wait_vblank
    call wait_pit_tick
    call commit_shadow_regs
    call commit_palette         ; map BGP/OBP0/OBP1 → DAC (raw-index render)
    ; RETIRED: do_bg_transfer (pret's hAutoBGTransferEnabled VBlank auto-transfer)
    ; ran here. It was removed as the root cause of the menu "turns to grass" /
    ; every-other-row corruption family (OW-A.13): its geometry had rotted (it
    ; copied SCREEN_TILES_W=40 bytes per 32-wide tilemap row — row pad 32−40=−8 —
    ; for SCREEN_TILES_H=25 rows, both constants redefined since it was written
    ; for the GB's 20×18), and no single geometry CAN serve it: EN=1 arms exist
    ; from both stride-20 scratch screens (pokédex/options/naming) and 40-wide
    ; canvas screens (main-menu CONTINUE panel, save info panel). Whenever a
    ; faithful pret `hAutoBGTransferEnabled=1` write was live (the bag list loop
    ; and Pokedex_PlacePokemonList also LEAK it back to the START menu), this
    ; overwrote GB_TILEMAP1 — the START-menu/options/pokédex window SOURCE —
    ; with skewed canvas bytes every frame, out-fighting the explicit mirrors.
    ; render_bg's flat path reads wTileMap directly, and every window-owning
    ; screen maintains its own mirror, so the transfer fed nothing legitimate.
    ;
    ; VBlank BG-transfer phase (pret VBlank order): staged BG-map copy + moving-tile
    ; animation. Both are M2.2 globals that self-gate internally (VBlankCopyBgMap on
    ; its row-count, UpdateMovingBgTiles on hTileAnimations), so the unconditional
    ; call is correct — inert until their owners arm them.
    ; Does not reorder update_oam/render_bg/present.
    call VBlankCopyBgMap
    call UpdateMovingBgTiles
    call update_oam             ; PrepareOAMData → shadow OAM, then DMA to OAM
    call TrackPlayTime          ; pret VBlank: play clock + CountDownIgnoreInputBitReset (post-PrepareOAMData)
    ; pret home/vblank.asm:43 — `call Random`, every VBlank, between TrackPlayTime
    ; and ReadJoypad. This is the ONLY thing that churns hRandomAdd/hRandomSub for
    ; code that reads them without calling Random itself — most importantly
    ; TryDoWildEncounter, whose encounter roll is `hRandomAdd < wGrassRate` and
    ; whose slot pick is `hRandomSub`. Without it those two bytes only advanced when
    ; some NPC-wander path happened to call Random, leaving them stale and highly
    ; correlated at the moment of the step check — wild encounters fired only very
    ; rarely (observed: ~1 per 3 minutes of walking in grass). Restored 2026-07-10.
    call Random
    call joypad_update
%ifdef DEBUG_AUTOKEY
    call AutoKeyDrive                   ; scripted joypad: replay a button sequence
%endif
%ifdef DEBUG_SEAM_LIVE
%ifndef DEBUG_SEAM_NOLOG
    ; Sample the seam trace once per rendered frame, after the joypad is read so
    ; SeamLogRecord can see hJoyPressed (A = dump SEAMLOG.BIN + FRAME.BIN and exit).
    ; DEBUG_SEAM_NOLOG (see DEBUG_START_MAP) suppresses this: it reuses the spawn
    ; seeding for a plain playable build, where A must stay a game button.
    call SeamLogRecord
%endif
%endif
    ; hFrameCounter guarded decrement — pret VBlank: `and a / jr z / dec [hl]`.
    ; Unblocks callers using pret's set-hFrameCounter-and-spin idiom (M2.1).
    cmp byte [ebp + H_FRAME_COUNTER], 0
    je .noFrameDec
    dec byte [ebp + H_FRAME_COUNTER]
.noFrameDec:
    ; pret VBlank audio block (home/vblank.asm, right after the hFrameCounter
    ; dec): FadeOutAudio → Music_DoLowHealthAlarm → Audio1_UpdateMusic →
    ; device-shim pass. Self-gates on g_audio_engine_online.
    call audio_tick
    ; BG: render_bg picks its own path from wCurrentTileBlockMapViewPointer —
    ; nonzero = overworld surface, zero = flat 40×25 W_TILEMAP (title / menus /
    ; battle). InitBattle zeroes that pointer (+ SCX/SCY), so the battle screen is
    ; just the full-canvas W_TILEMAP rendered here. (Wave-2 Stage 1a: replaced the
    ; Stage-0.5 clear_backbuffer_battle + centered-window approach.)
    call render_bg
    call render_sprites         ; composite OAM sprites over BG
    ; DIVERGENCE FROM GB HARDWARE (intentional): on real DMG/CGB, OBJ sprites
    ; draw OVER the window layer, so the GB order is BG → window → sprites. We
    ; deliberately invert that here (window LAST, over sprites) because the
    ; window layer in this port is only ever the bottom dialog/menu box (WY=152),
    ; and that box must occlude NPCs standing under it. The artifact this guards
    ; against is port-specific: our extended 40×25 player-centered viewport shows
    ; far more of the map than the GB's 20×18 screen, exposing NPCs in the bottom
    ; rows that the original camera never placed under the textbox. The player
    ; sprite sits at screen center (well above WY=152), so it is never occluded.
    call present_windows        ; composite the window descriptor list OVER sprites
    call draw_player_marker     ; legacy placeholder (no-op unless explicitly enabled)
    call present
    cmp byte [pad_quit], 0
    je .done
    call cleanup
%ifdef DEBUG_NPC_WALK
    call DumpNpcLog             ; writes NPCLOG.BIN, then exits (never returns)
%endif
%ifdef DEBUG_WALKSPEED
    call DebugDumpMemory        ; writes DUMP.BIN (ticks/tile stats), then exits
%endif
    mov ax, 0x4C00
    int 0x21
.done:
    popad
    ret

; ---------------------------------------------------------------------------
; present_windows — composite the unified window descriptor list over the back
; buffer. Draws g_windows[0..g_window_count-1] in order (painter's order: later
; descriptors draw on top). count==0 ⇒ nothing drawn.
;
; The only caller of render_window. Each screen fully (re)defines g_windows /
; g_window_count on entry/state-change (via set_single_window / hide_window, or by
; appending descriptors directly), so present_windows just walks whatever the
; current owner left.
;
; In: EBP = GB memory base. All registers preserved.
; ---------------------------------------------------------------------------
present_windows:
    pushad
    xor ebx, ebx                    ; descriptor index
.loop:
    cmp ebx, [g_window_count]
    jae .done
    imul esi, ebx, WIN_DESC_SIZE
    add esi, g_windows
    call render_window              ; ESI = &g_windows[ebx]
    inc ebx
    jmp .loop
.done:
    popad
    ret

; ---------------------------------------------------------------------------
; update_oam — build shadow OAM (PrepareOAMData) and DMA it into OAM ($FE00).
;
; Mirrors the GB VBlank ISR steps PrepareOAMData + hDMARoutine. Gated on
; wUpdateSpritesEnabled so non-gameplay screens (e.g. the title, which writes
; its own shadow OAM) are not force-copied into OAM until the overworld enables
; sprite updates. In: EBP = GB memory base. All registers preserved.
; ---------------------------------------------------------------------------
update_oam:
    cmp byte [ebp + W_UPDATE_SPRITES_ENABLED], 1
    jne .done
    call PrepareOAMData
    pushad
    lea esi, [ebp + W_SHADOW_OAM]
    lea edi, [ebp + GB_OAM]
    mov ecx, W_SHADOW_OAM_SIZE
    rep movsb
    popad
.done:
    ret

; ---------------------------------------------------------------------------
; commit_shadow_regs — copy H_SCX/H_SCY/H_WY → IO_SCX/IO_SCY/IO_WY.
; Mirrors the GB VBlank ISR shadow-register commit.
; In: EBP = GB memory base. All registers preserved.
; ---------------------------------------------------------------------------
commit_shadow_regs:
    push eax
    inc byte [ebp + IO_DIV]     ; advance emulated DIV counter (~16384 Hz on GB; 1/frame is enough for RNG entropy)
    mov al, [ebp + H_SCX]
    mov [ebp + IO_SCX], al
    mov al, [ebp + H_SCY]
    mov [ebp + IO_SCY], al
    ; WY commit gated on wDisableVBlankWYUpdate (pret VBlank: skip rWY update when
    ; nonzero). Default/unset (0) → commit exactly as before — byte-identical.
    cmp byte [ebp + W_DISABLE_VBLANK_WY_UPDATE], 0
    jne .skipWY
    mov al, [ebp + H_WY]
    mov [ebp + IO_WY], al
.skipWY:
    pop eax
    ret

; ---------------------------------------------------------------------------
; do_bg_transfer — DELETED (see the retirement note in DelayFrame). The window
; compositor's explicit per-screen mirrors are the port's only WRAM→tilemap
; path; resurrect from git history only if a screen ever genuinely needs a
; generic transfer, and then per-descriptor (source stride + dest band owned by
; the descriptor), never as a global W_TILEMAP-wide copy.
; ---------------------------------------------------------------------------
; DelayFrames — wait BL (C register) frames.
; In:  BL = frame count. Out: BL = 0. Other registers preserved.
; ---------------------------------------------------------------------------
DelayFrames:
    test bl, bl
    jz .done
.loop:
    call DelayFrame
    dec bl
    jnz .loop
.done:
    ret

; ---------------------------------------------------------------------------
; Delay3 — wait exactly 3 frames (tail-call into DelayFrames).
; Matches home/delay.asm:Delay3. All registers preserved.
; ---------------------------------------------------------------------------
Delay3:
    push ebx
    mov bl, 3
    call DelayFrames
    pop ebx
    ret
