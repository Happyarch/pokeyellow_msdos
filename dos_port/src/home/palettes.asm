; palettes.asm — pret mirror of home/palettes.asm.
;
; The home-bank palette/delay grab-bag, plus this file's port-side role as the
; CGB/SGB palette command boundary for the native VGA renderer.
; Pret refs: home/palettes.asm, home/cgb_palettes.asm.
;
; Routines consolidated here (mirror rule, CLAUDE.md) from five port files that had
; grown their own copies, in pret home/palettes.asm order:
;
;   src/engine/overworld/map_sprites.asm  InitMapSprites  (the home wrapper only —
;                                         _InitMapSprites is a pret
;                                         engine/overworld/map_sprites.asm label and
;                                         stays in its own mirror)
;   src/home/fade.asm                     RestoreScreenTilesAndReloadTilePatterns,
;                                         GBPalWhiteOutWithDelay3, GBPalWhiteOut,
;                                         GetHealthBarColor
;   src/video/frame.asm                   Delay3
;   src/home/init.asm                     GBPalNormal
;   src/engine/menus/naming_screen.asm    RunDefaultPaletteCommand
;
; InitMapSprites' two port-only private helpers (ResetMapTrainerState,
; ApplyToggleableHiddenGate) deliberately did NOT come with it: they are overworld
; map-sprite bookkeeping with no pret counterpart, and CLAUDE.md lets a port-only
; helper live where its subsystem requires so long as it does not absorb a pret
; label. They stay in map_sprites.asm and are externed below.
bits 32
%include "gb_memmap.inc"

; File-local constants carried in with the routines that read them (recipe: a
; moved routine's file-local `equ` travels with it). Values verified identical to
; the other copies in the tree before the move.
BGP_NORMAL       equ 0xE4
OBP0_NORMAL      equ 0xD0
SET_PAL_DEFAULT        equ 0xFF
global RunPaletteCommand
global g_pal_dirty, bg_slot_pal, obj_slot_pal
global pal_rgb_table, mon_pal_table, battle_slot_pal, battle_tile_pal, command_pal_table, repaint_front_table
global InitMapSprites
global RestoreScreenTilesAndReloadTilePatterns
global GBPalWhiteOutWithDelay3
global Delay3
global GBPalNormal
global GBPalWhiteOut
global RunDefaultPaletteCommand
global GetHealthBarColor
extern _RunPaletteCommand
extern _InitMapSprites               ; src/engine/overworld/map_sprites.asm
extern ResetMapTrainerState          ; src/engine/overworld/map_sprites.asm (port ext)
extern ApplyToggleableHiddenGate     ; src/engine/overworld/map_sprites.asm (port ext)
extern ClearSprites                 ; src/home/clear_sprites.asm
extern LoadTextBoxTilePatterns      ; src/home/load_font.asm
extern ReloadMapSpriteTilePatterns  ; src/home/reload_sprites.asm
extern DelayFrames                  ; src/video/frame.asm  (In: BL = frame count)
extern UpdateCGBPal_BGP             ; src/home/cgb_palettes.asm
extern UpdateCGBPal_OBP0            ; src/home/cgb_palettes.asm
extern UpdateCGBPal_OBP1            ; src/home/cgb_palettes.asm
section .data
align 4
%include "assets/colors/palettes.inc"
; Preserve today's look until a palette command chooses otherwise.
bg_slot_pal: times 8 db PAL_DMG_GREEN
obj_slot_pal: times 8 db PAL_DMG_GREEN
g_pal_dirty: db 1
section .text

; ---------------------------------------------------------------------------
; InitMapSprites — home wrapper (pret name; extern'd by overworld.asm + text_script.asm).
; Runs the port-extension per-map bookkeeping, then the faithful _InitMapSprites.
; All registers preserved (pushad/popad).
; ---------------------------------------------------------------------------
InitMapSprites:
    pushad
    ; DIVERGENCE (port ext): reset the per-map trainer/interaction state. Kept here
    ; (not in InitSprites) so it fires on exactly the paths the bespoke reset did —
    ; map load + .mapTransition + post-text InitMapSprites — but NOT on the interaction
    ; stack's post-dialog reload (that path calls ReloadWalkingTilePatterns, not this).
    call ResetMapTrainerState
    ; DIVERGENCE (port ext): hide toggleable-hidden objects before the sprite-set /
    ; imageBaseOffset passes read PICTUREIDs, so a hidden object never gets a VRAM slot.
    call ApplyToggleableHiddenGate
    call _InitMapSprites
    popad
    ret

; ===========================================================================
; RestoreScreenTilesAndReloadTilePatterns
; Source: home/palettes.asm:RestoreScreenTilesAndReloadTilePatterns
;   Restores the saved screen (Buffer2) and reloads sprite/text tile patterns
;   after a menu/overlay, then reasserts the default palette and waits 3 frames.
; ===========================================================================
RestoreScreenTilesAndReloadTilePatterns:
    call ClearSprites
    mov byte [ebp + W_UPDATE_SPRITES_ENABLED], 1  ; ld a,$1 / ld [wUpdateSpritesEnabled],a
    ; Load-bearing since the party icons became OAM: they live in vSprites
    ; ($8000-$87FF), i.e. exactly the map-sprite tiles this reloads. Every port
    ; caller is an overworld-context exit, so the reload is in-context here.
    call ReloadMapSpriteTilePatterns
    ; TODO(unimplemented): call LoadScreenTilesFromBuffer2
    ;   (now a linkable global in src/home/tilemap.asm — wire when this path is
    ;   next audited; the call is still dropped here)
    call LoadTextBoxTilePatterns
    ; TODO(unimplemented): call RunDefaultPaletteCommand
    ;   (SGB/CGB palette command dispatch — Phase 5; town_map.asm stubs it too.
    ;   NOTE: since the mirror move this call's target is defined LOWER IN THIS
    ;   FILE, so the only thing still missing is the audit, not a symbol.)
    jmp Delay3                            ; jr Delay3 (tail-call)

GBPalWhiteOutWithDelay3:
    call GBPalWhiteOut
    jmp Delay3                            ; pret: call GBPalWhiteOut then falls into Delay3

; ---------------------------------------------------------------------------
; Delay3 — wait exactly 3 frames (tail-call into DelayFrames).
; Matches home/palettes.asm:Delay3. All registers preserved.
; ---------------------------------------------------------------------------
Delay3:
    push ebx
    mov bl, 3
    call DelayFrames
    pop ebx
    ret

; ---------------------------------------------------------------------------
; GBPalNormal — reset the BGP/OBP0 shadows to DMG normal palettes (pret writes
; only rBGP and rOBP0 here — OBP1 is untouched, as in pret).
; CGB palette updates deferred to Phase 5.
; ---------------------------------------------------------------------------
GBPalNormal:
    mov byte [ebp + IO_BGP],  BGP_NORMAL
    mov byte [ebp + IO_OBP0], OBP0_NORMAL
    ret

; ===========================================================================
; GBPalWhiteOut / GBPalWhiteOutWithDelay3 — white out all palettes.
; Source: home/palettes.asm:GBPalWhiteOut, GBPalWhiteOutWithDelay3
;   This is the canonical exported copy. (The old file-local scaffold in the
;   legacy src/movie/title.asm was retired 2026-07-23 and the file itself is
;   deleted, 2026-07-24.)
; ===========================================================================
GBPalWhiteOut:
    mov byte [ebp + IO_BGP],  0x00        ; xor a / ldh [rBGP],  a
    mov byte [ebp + IO_OBP0], 0x00        ;         ldh [rOBP0], a
    mov byte [ebp + IO_OBP1], 0x00        ;         ldh [rOBP1], a
    call UpdateCGBPal_BGP
    call UpdateCGBPal_OBP0
    call UpdateCGBPal_OBP1
    ret

; ---------------------------------------------------------------------------
; RunDefaultPaletteCommand — pret ref: home/palettes.asm:RunDefaultPaletteCommand
; (a 1-line label that sets B=SET_PAL_DEFAULT and falls into RunPaletteCommand).
; Promoted to a global (2026-07-12): ExitTownMap needs it too.
;
; The note that used to sit here was stale in three ways, all corrected 2026-07-26
; when this routine moved into its mirror: it said the routine "still lives in this
; file rather than beside RunPaletteCommand (engine/battle/faint_switch.asm)" —
; RunPaletteCommand has lived HERE for some time, and they are now adjacent, which
; was the whole point of the move; it said "pret sets `b` (= BH), this sets BL",
; which the code below contradicts (it sets BH, and has since the BL-first shim was
; removed in c84c76e8 — see memory palette-b-register-bl-vs-bh); and it called
; RunPaletteCommand "a ret-stub", which it is not (it dispatches to
; _RunPaletteCommand below).
; ---------------------------------------------------------------------------
RunDefaultPaletteCommand:
    mov bh, SET_PAL_DEFAULT
    jmp RunPaletteCommand

; RunPaletteCommand — pret ref: home/palettes.asm. In: GB `b` = the SET_PAL_* command,
; which is BH in the port's register map (CLAUDE.md: BC = BX, B = BH, C = BL).
;
; This used to be a normalizing shim: `mov al,bl / test al,al / jnz .have / mov al,bh`,
; i.e. it read BL FIRST and fell back to BH only when BL was zero, to tolerate call
; sites that had translated pret's `ld b` into the wrong half. That was a trap, not a
; kindness — it made the WRONG half authoritative. A site that correctly wrote BH
; (town_map, pokedex_entry) got the wrong palette whenever BL happened to be nonzero,
; and it meant nobody could fix a single call site without breaking it, because the
; "faithful" edit (BL -> BH) is exactly what the shim punished. Ledger M-62.
;
; Resolved 2026-07-14: every call site now passes BH, so this reads BH only, as pret's
; `b`. Two battle sites (faint_switch, faint_sendout) were passing NOTHING at all and
; dispatching on junk — they now set SET_PAL_BATTLE (M-72). pret's `c` is not read by
; _RunPaletteCommand, so BL carries nothing here.
RunPaletteCommand:
    mov al, bh                      ; GB b
    jmp _RunPaletteCommand

; ===========================================================================
; GetHealthBarColor
; Source: home/palettes.asm:GetHealthBarColor
;   In:  DL (E) = current HP-bar length in pixels (0..48 for a 6-tile bar).
;        ESI (HL) = flat GB address to store the color into.
;   Out: byte at [ebp+esi] = 0 green / 1 yellow / 2 red.
;   Faithful pixel thresholds: >=27 px green, >=10 px yellow, else red
;   (27/48 ~ 56%, 10/48 ~ 21%; pure gameplay logic, NOT color-blocked).
; ===========================================================================
GetHealthBarColor:
    xor dh, dh                            ; ld d, 0  (green)
    cmp dl, 27                            ; cp 27
    jae .gotColor                         ; jr nc, .gotColor
    inc dh                                ; inc d  (yellow)
    cmp dl, 10                            ; cp 10
    jae .gotColor                         ; jr nc, .gotColor
    inc dh                                ; inc d  (red)
.gotColor:
    mov [ebp + esi], dh                   ; ld [hl], d
    ret
