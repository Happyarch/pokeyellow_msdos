; dos_port/src/engine/movie/evolution.asm
; ============================================================
; Mirror of pret engine/movie/evolution.asm.
;
; Holds every pret label of that file, in pret order:
;   EvolveMon, EvolutionSetWholeScreenPalette, Evolution_LoadPic,
;   Evolution_BackAndForthAnim, Evolution_ChangeMonPic, Evolution_CheckForCancel
;
; Was src/engine/pokemon/evolution.asm until the mirror repair.
;
; The engine/pokemon/evos_moves.asm labels this file used to carry —
; TryEvolvingMon, EvolutionAfterBattle, RenameEvolvedMon, CancelledEvolution,
; and the two port-only GetMonLearnset_Evo* blob helpers that only
; EvolutionAfterBattle called — now live in their pret mirror,
; src/engine/pokemon/evos_moves.asm.
;
; EvosMovesPointerTable data: assets/evos_moves.inc (190 dd entries,
; internal-index order). Each blob: [evo entries…] db 0 [level,move pairs…] db 0.
; Blob is in FLAT program-image memory (not EBP-relative).
;
; -----------------------------------------------------------------------
; THE MORPH, AND HOW IT REACHES THE SCREEN
;
; pret stages the pic swap in wTileMap and lets the VBlank
; hAutoBGTransferEnabled auto-transfer push it to the BG map during
; Evolution_ChangeMonPic's Delay3. THE PORT RETIRED THAT AUTO-TRANSFER
; (src/home/vblank.asm — its geometry could not serve both the stride-20 scratch
; screens and the 40-wide canvas screens, and it was overwriting GB_TILEMAP1).
; The faithful `ldh [hAutoBGTransferEnabled]` writes below are kept as vestigial
; bookkeeping and move nothing, exactly as they are in
; src/engine/battle/battle_transitions.asm.
;
; What commits the canvas here is the SAME mechanism the battle transitions use:
; this screen is a FLAT-CANVAS screen, so render_bg reads wTileMap directly
; (ppu.asm's view-pointer==0 path) and republishes the whole canvas on every
; DelayFrame. Evolution_ChangeMonPic's `call Delay3` therefore IS the commit —
; three published frames per flip — and the accelerando loop's repeated flips
; each publish in turn. No per-screen wTileMap -> GB_TILEMAP0 mirror is needed
; (unlike list_mirror / PartyMenuMirror / SurfingMinigame_MirrorIntroCanvas,
; which all exist because those screens are shown THROUGH A WINDOW sourcing
; GB_TILEMAP0/1; this one is not — see evo_canvas_enter).
;
; Build (from repo root):
;   nasm -f coff -I dos_port/include/ -I dos_port/ \
;       -o dos_port/src/engine/movie/evolution.o \
;       dos_port/src/engine/movie/evolution.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "coords.inc"

; All WRAM/const aliases formerly declared here as %ifndef self-aliases are now
; in the shared includes (gb_memmap.inc / gb_constants.inc), promoted per
; docs/current_plan_pokemon_behavior.md Stage 0.

; ---------------------------------------------------------------------------
; Globals and externs
; ---------------------------------------------------------------------------
global EvolveMon
global EvolutionSetWholeScreenPalette
global Evolution_LoadPic
global Evolution_BackAndForthAnim
global Evolution_ChangeMonPic

; Text/display/input helpers (Stage 2 — evolution now shows text + allows B-cancel):
extern DelayFrames              ; (BL = frame count)
extern DelayFrame               ; wait one frame
extern JoypadLowSensitivity     ; refresh hJoy5 (hJoy5) low-sensitivity input

; Audio (live since the Phase-3 engine landed — see the EvolveMon header):
extern StopAllMusic             ; src/home/audio.asm
extern PlaySound                ; src/home/audio.asm — AL = sound id
extern PlayMusic                ; src/home/audio.asm — AL = song, BL = audio ROM bank
extern PlayCry                  ; src/home/pokemon.asm — pret home/pokemon.asm:140
extern WaitForSoundToFinish     ; src/home/delay.asm
extern Delay3                   ; src/home/palettes.asm

; Pic staging + palette (the morph layer):
extern GetMonHeader                     ; src/home/pokemon.asm — [wCurSpecies] -> wMonHeader
extern LoadFlippedFrontSpriteByMonIndex ; src/home/pokemon.asm — ESI = tilemap dest
extern CopyVideoData                    ; src/home/copy2.asm — ESI VRAM dest, EDX flat src, BL tiles
extern RunPaletteCommand                ; src/home/palettes.asm — BH = SET_PAL_* command

; Port-only presentation (evo_canvas_enter / _exit below):
extern ClearScreenArea          ; src/home/copy2.asm — ESI dest, BH rows, BL width
extern hide_window              ; src/ppu/ppu.asm
extern g_bg_whiteout            ; src/ppu/ppu.asm
extern text_row_stride          ; src/home/text.asm — live wTileMap row stride (20 / 40)

%include "assets/audio_constants.inc"   ; SFX_TINK, MUSIC_SAFARI_ZONE + its _BANK

; The evolution pic block: pret's `hlcoord 7, 2` centres a 7x7 pic on the GB's
; 20-wide screen (cols 7-13 of 0-19). BCOORD is the port's uniform GB-centering
; projection (+10 col / +3 row, include/coords.inc), so BCOORD(7,2) puts the same
; block at canvas cols 17-23 / rows 5-11 — centred on the 40x25 canvas, and the
; same convention the in-battle mon-pic animations use for their 7x7 blocks
; (docs/ui_projection.md, "battle-anim (mon-pic origin)").
%define EVO_PIC_ORIGIN BCOORD(7, 2)

section .text

; ===========================================================================
; EvolveMon  (pret engine/movie/evolution.asm EvolveMon)
; Runs the evolution animation and returns CF = "player cancelled".
;
; Complete as of the evolution-animation plan: the B-cancel loop, the audio, the
; dual vFrontPic/vBackPic pic staging, the PAL_BLACK silhouette and the
; accelerating back-and-forth morph all run. The only port-specific additions
; are the two presentation calls (evo_canvas_enter / evo_canvas_exit), annotated
; at their definitions.
;
; pret pushes wCurPartySpecies / wCurSpecies because Evolution_LoadPic clobbers
; both; the port used to skip that save/restore precisely because the pic path
; was deferred. It is restored here along with the pic path.
;
; Out: CF set iff cancelled. Clobbers AL; preserves ESI/EDX/EBX.
; ===========================================================================
EvolveMon:
    push esi                        ; push hl
    push edx                        ; push de
    push ebx                        ; push bc
    mov al, [ebp + wCurPartySpecies]
    push eax                        ; push af
    mov al, [ebp + wCurSpecies]
    push eax                        ; push af

    call evo_canvas_enter           ; PORT-ONLY: make wTileMap the live surface

    xor al, al                      ; xor a
    mov [ebp + wLowHealthAlarm], al ; ld [wLowHealthAlarm], a
    mov [ebp + wChannelSoundIDs + CHAN5], al  ; ld [wChannelSoundIDs + CHAN5], a
    call StopAllMusic
    mov byte [ebp + hAutoBGTransferEnabled], 1 ; ld a,$1 / ldh [hAutoBGTransferEnabled],a
    mov al, SFX_TINK                ; ld a, SFX_TINK
    call PlaySound
    call Delay3
    xor al, al                      ; xor a
    mov [ebp + hAutoBGTransferEnabled], al     ; ldh [hAutoBGTransferEnabled], a
    mov [ebp + hTileAnimations], al            ; ldh [hTileAnimations], a

    ; --- the mon's own palette, whole screen (pret: ld c, 0) -------------------
    mov al, [ebp + wEvoOldSpecies]              ; ld a, [wEvoOldSpecies]
    mov [ebp + wWholeScreenPaletteMonSpecies], al
    mov bl, 0                                   ; ld c, 0
    call EvolutionSetWholeScreenPalette

    ; --- stage BOTH pics: new species into vBackPic, old species into vFrontPic
    ; Evolution_LoadPic always decodes to vFrontPic ($9000, tiles $00-$30) and
    ; places tile ids $00-$30, so the new pic is loaded FIRST and copied up to
    ; vBackPic ($9310, tiles $31-$61); the old pic then overwrites vFrontPic.
    ; The ±$31 tilemap offset below is what swaps which of the two is shown. ----
    mov al, [ebp + wEvoNewSpecies]  ; ld a, [wEvoNewSpecies]
    mov [ebp + wCurPartySpecies], al
    mov [ebp + wCurSpecies], al
    call Evolution_LoadPic
    ; pret: ld de, vFrontPic / ld hl, vBackPic / ld bc, PIC_SIZE / call CopyVideoData.
    ; The port's CopyVideoData takes the SOURCE as a flat pointer and the DEST as
    ; an EBP-relative GB offset (src/home/copy2.asm), so `lea edx, [ebp+vFrontPic]`
    ; names the very same VRAM bytes pret's `de` names. It arms g_tilecache_dirty
    ; itself, which is what keeps the compositor from drawing the previous
    ; occupants of tiles $31-$61 (CLAUDE.md, "VRAM tile writes").
    mov esi, vBackPic               ; ld hl, vBackPic
    lea edx, [ebp + vFrontPic]      ; ld de, vFrontPic
    mov bx, PIC_SIZE                ; ld bc, PIC_SIZE (BH = bank, no-op; BL = 49 tiles)
    call CopyVideoData
    mov al, [ebp + wEvoOldSpecies]  ; ld a, [wEvoOldSpecies]
    mov [ebp + wCurPartySpecies], al
    mov [ebp + wCurSpecies], al
    call Evolution_LoadPic

    mov byte [ebp + hAutoBGTransferEnabled], 1 ; ld a,$1 / ldh [hAutoBGTransferEnabled],a
    mov al, [ebp + wEvoOldSpecies]  ; ld a, [wEvoOldSpecies]
    call PlayCry
    call WaitForSoundToFinish
    mov bl, MUSIC_SAFARI_ZONE_BANK  ; ld c, BANK(Music_SafariZone)
    mov al, MUSIC_SAFARI_ZONE       ; ld a, MUSIC_SAFARI_ZONE
    call PlayMusic

    mov bl, 80                      ; pret: ld c, 80 / call DelayFrames
    call DelayFrames
    mov bl, 1                       ; ld c, 1 — set PAL_BLACK instead of mon palette
    call EvolutionSetWholeScreenPalette

    ; pret: lb bc, $1, $10 → 8 passes (c stepped 16→2, dec c twice per pass);
    ; BH = the number of back-and-forth cycles Evolution_BackAndForthAnim runs,
    ; BL = the per-pass frame budget Evolution_CheckForCancel counts down.
    mov bh, 1
    mov bl, 0x10
.animLoop:
    push ebx
    call Evolution_CheckForCancel
    jc .evolutionCancelled
    call Evolution_BackAndForthAnim
    pop ebx
    inc bh
    dec bl
    dec bl
    jnz .animLoop

    xor al, al
    mov [ebp + wEvoCancelled], al
    mov al, 0x31                            ; ld a, $31
    mov [ebp + wEvoMonTileOffset], al
    call Evolution_ChangeMonPic             ; show the new species pic
    mov al, [ebp + wEvoNewSpecies]
.done:
    ; pret: ld [wWholeScreenPaletteMonSpecies], a / call StopAllMusic /
    ; ld a, [wWholeScreenPaletteMonSpecies] / call PlayCry. AL arrives holding the
    ; species, and pret parks it in WRAM precisely because StopAllMusic does not
    ; preserve A — so the reload is load-bearing, not redundant.
    mov [ebp + wWholeScreenPaletteMonSpecies], al
    call StopAllMusic
    mov al, [ebp + wWholeScreenPaletteMonSpecies]
    call PlayCry
    mov bl, 0                       ; ld c, 0 — back to the resolved mon's colour
    call EvolutionSetWholeScreenPalette

    call evo_canvas_exit            ; PORT-ONLY: hand the screen back to the caller

    pop eax                         ; pop af
    mov [ebp + wCurSpecies], al
    pop eax                         ; pop af
    mov [ebp + wCurPartySpecies], al
    pop ebx
    pop edx
    pop esi
    mov al, [ebp + wEvoCancelled]
    test al, al
    jz .noCancel
    stc
    ret
.noCancel:
    clc
    ret

.evolutionCancelled:
    pop ebx                         ; discard the saved BC from this .animLoop pass
    mov al, 1
    mov [ebp + wEvoCancelled], al
    mov al, [ebp + wEvoOldSpecies]
    jmp .done

; ---------------------------------------------------------------------------
; EvolutionSetWholeScreenPalette (pret engine/movie/evolution.asm)
; In: BL = pret's `c` — 0 = the mon's palette, nonzero = PAL_BLACK silhouette.
; ---------------------------------------------------------------------------
EvolutionSetWholeScreenPalette:
    mov bh, SET_PAL_POKEMON_WHOLE_SCREEN    ; ld b, SET_PAL_POKEMON_WHOLE_SCREEN
    jmp RunPaletteCommand                   ; jp RunPaletteCommand

; ---------------------------------------------------------------------------
; Evolution_LoadPic (pret engine/movie/evolution.asm)
; Decode [wCurSpecies]'s front pic to vFrontPic and place its 7x7 tile block.
; LoadFlippedFrontSpriteByMonIndex does BOTH halves (decode + place) and takes
; the tilemap destination in ESI, exactly as pret's `hlcoord 7, 2 / jp` does.
; ---------------------------------------------------------------------------
Evolution_LoadPic:
    call GetMonHeader
    mov esi, EVO_PIC_ORIGIN                 ; hlcoord 7, 2
    jmp LoadFlippedFrontSpriteByMonIndex    ; jp

; ---------------------------------------------------------------------------
; Evolution_BackAndForthAnim (pret engine/movie/evolution.asm)
; Show the mon change back and forth between the new and old species BH (pret b)
; times. Evolution_ChangeMonPic preserves BX, so the counter survives the calls.
; ---------------------------------------------------------------------------
Evolution_BackAndForthAnim:
    mov al, 0x31                            ; ld a, $31
    mov [ebp + wEvoMonTileOffset], al
    call Evolution_ChangeMonPic             ; -> tiles $31-$61 = the new species
    mov al, -0x31 & 0xFF                    ; ld a, -$31
    mov [ebp + wEvoMonTileOffset], al
    call Evolution_ChangeMonPic             ; -> tiles $00-$30 = the old species
    ; COUNTER WIDTH: pret is `dec b / jr nz` — 8-bit, so an entry count of 0
    ; runs 256 cycles and stops. `dec bh` IS that bound (CLAUDE.md / asm-translation),
    ; and EvolveMon only ever enters with 1..8, so nothing diverges.
    dec bh                                  ; dec b
    jnz Evolution_BackAndForthAnim          ; jr nz, Evolution_BackAndForthAnim
    ret

; ---------------------------------------------------------------------------
; Evolution_ChangeMonPic (pret engine/movie/evolution.asm)
; Add [wEvoMonTileOffset] to every tile id of the 7x7 pic block, flipping the
; block between the vFrontPic ids ($00-$30) and the vBackPic ids ($31-$61).
;
; The hAutoBGTransferEnabled pair is vestigial here (the port retired the VBlank
; auto-transfer — see this file's header); `call Delay3` is what publishes the
; edited canvas, because render_bg re-reads wTileMap on every DelayFrame.
; ---------------------------------------------------------------------------
Evolution_ChangeMonPic:
    push ebx                                ; push bc
    xor al, al
    mov [ebp + hAutoBGTransferEnabled], al  ; ldh [hAutoBGTransferEnabled], a
    mov esi, EVO_PIC_ORIGIN                 ; hlcoord 7, 2
    mov bh, PIC_HEIGHT                      ; lb bc, 7, 7 — B = rows
    mov bl, PIC_WIDTH                       ;              C = columns
    ; pret: `ld de, SCREEN_WIDTH - 7`, a row STRIDE remainder — the literal
    ; carries the port's 40-wide canvas, so this is 33 (docs/ui_projection.md:
    ; SCREEN_WIDTH as a stride translates verbatim, as a coordinate it does not).
    mov edx, SCREEN_WIDTH - PIC_WIDTH
.loop:
    push ebx                                ; push bc
.innerLoop:
    mov al, [ebp + wEvoMonTileOffset]       ; ld a, [wEvoMonTileOffset]
    add al, [ebp + esi]                     ; add [hl]
    mov [ebp + esi], al                     ; ld [hli], a
    inc esi                                 ;   (the `i` of hli)
    dec bl                                  ; dec c — 8-bit, pret's own bound
    jnz .innerLoop
    pop ebx                                 ; pop bc
    add esi, edx                            ; add hl, de
    dec bh                                  ; dec b — 8-bit
    jnz .loop
    mov al, 1
    mov [ebp + hAutoBGTransferEnabled], al  ; ldh [hAutoBGTransferEnabled], a
    call Delay3
    pop ebx                                 ; pop bc
    ret

; ---------------------------------------------------------------------------
; Evolution_CheckForCancel (pret engine/movie/evolution.asm) — wait BL frames,
; returning CF set if B is pressed (unless wForceEvolution blocks cancelling).
; ---------------------------------------------------------------------------
Evolution_CheckForCancel:
    call DelayFrame
    push ebx
    call JoypadLowSensitivity
    mov al, [ebp + hJoy5]
    pop ebx
    and al, PAD_B
    jnz .pressedB
.notAllowedToCancel:
    dec bl                          ; pret: dec c
    jnz Evolution_CheckForCancel
    clc                             ; pret: and a (CF clear)
    ret
.pressedB:
    mov al, [ebp + wForceEvolution]
    test al, al
    jnz .notAllowedToCancel         ; forced evolution can't be cancelled
    stc
    ret

; ===========================================================================
; PORT-ONLY presentation for the evolution screen.
;
; pret's evolution screen is simply "the screen", and its caller
; (engine/pokemon/evos_moves.asm:EvolutionAfterBattle) clears the top 12 rows of
; it before calling here. The port has three render sources — the overworld
; block surface, the flat 40x25 wTileMap canvas, and window descriptors over
; GB_TILEMAP0/1 — and which one is live depends on where the evolution was
; triggered from (a battle leaves the flat canvas; an evolution stone leaves the
; party menu's whiteout + window). The morph is a wTileMap screen, exactly like
; the battle transitions, so it has to say so.
;
; DEVIATION{class=projection; pret=engine/movie/evolution.asm:EvolveMon; behavior=takes ownership of the render surface around the animation - zeroes wCurrentTileBlockMapViewPointer and the hSCX/hSCY scroll shadows, clears g_bg_whiteout, hides any leftover window and sets the 40-wide canvas row stride, then restores the caller's values on exit - where pret simply draws on whatever the hardware was already showing; evidence=the port renders three different sources and render_bg only reads wTileMap when the view pointer is zero (src/ppu/ppu.asm .flat_path), so without this the whole morph is staged into a buffer nothing composites - the same defect the Surfing Pikachu intro shipped with, and the same setup src/engine/pokemon/status_screen.asm and src/engine/battle/init_battle.asm already perform for their flat-canvas screens; lifetime=permanent, the port's canvas-ownership boundary}
;
; The clears are described at their call sites below: a matte over the canvas
; cells outside the GB-centred 20x18 screen, then pret's own top-12-rows clear
; at the projected origin.
;
; In/Out: all registers preserved.
; ===========================================================================
evo_canvas_enter:
    pushad
    ; save what we are about to take over
    movzx eax, word [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR]
    mov [evo_saved_view_ptr], eax
    mov eax, [g_bg_whiteout]
    mov [evo_saved_whiteout], eax
    mov eax, [text_row_stride]
    mov [evo_saved_stride], eax
    ; flat-canvas render setup (the same sequence status_screen.asm performs)
    mov word [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR], 0
    mov byte [ebp + hSCX], 0        ; the SHADOWS as well — commit_shadow_regs copies
    mov byte [ebp + hSCY], 0        ; them over IO_SCX/SCY on every DelayFrame, so a
    mov byte [ebp + IO_SCX], 0      ; leftover overworld scroll would drag the canvas
    mov byte [ebp + IO_SCY], 0      ; off screen again next frame
    mov dword [g_bg_whiteout], 0
    mov dword [text_row_stride], SCREEN_WIDTH
    call hide_window                ; the party menu's window would cover the morph
    ; --- (a) the widescreen MATTE: everything outside the GB-centred 20x18
    ; screen. pret's screen IS the whole screen, so the canvas cells its 20x18
    ; never covers would otherwise show whatever the caller left there (measured:
    ; the overworld block crop). Same treatment, and the same reasoning, as the
    ; cinematic vignette in docs/ui_projection.md.
    mov esi, wTileMap                               ; rows above the GB screen
    mov bh, 3
    mov bl, SCREEN_WIDTH
    call ClearScreenArea
    mov esi, wTileMap + 21 * SCREEN_WIDTH           ; rows below it
    mov bh, SCREEN_HEIGHT - 21
    mov bl, SCREEN_WIDTH
    call ClearScreenArea
    mov esi, wTileMap + 3 * SCREEN_WIDTH            ; the left margin
    mov bh, 18
    mov bl, 10
    call ClearScreenArea
    mov esi, wTileMap + 3 * SCREEN_WIDTH + 30       ; the right margin
    mov bh, 18
    mov bl, 10
    call ClearScreenArea
    ; --- (b) pret's own clear, projected: `hlcoord 0, 0 / lb bc, 12, 20`. The
    ; caller (evos_moves.asm) makes this call too, but from the UNPROJECTED
    ; wTileMap origin, so it lands 10 columns left of the screen it means.
    ; Repeating it at BCOORD leaves the message box (GB rows 12-17) standing,
    ; exactly as pret's does.
    mov esi, BCOORD(0, 0)
    mov bh, 12
    mov bl, 20
    call ClearScreenArea
    popad
    ret

evo_canvas_exit:
    pushad
    mov eax, [evo_saved_view_ptr]
    mov [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR], ax
    mov eax, [evo_saved_whiteout]
    mov [g_bg_whiteout], eax
    mov eax, [evo_saved_stride]
    mov [text_row_stride], eax
    popad
    ret

section .bss
evo_saved_view_ptr: resd 1
evo_saved_whiteout: resd 1
evo_saved_stride:   resd 1
