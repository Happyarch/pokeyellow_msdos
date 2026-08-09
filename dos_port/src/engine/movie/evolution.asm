; dos_port/src/engine/movie/evolution.asm
; ============================================================
; Mirror of pret engine/movie/evolution.asm — the evolution ANIMATION half.
;
; Holds two of that file's pret labels, in pret order:
;   EvolveMon, Evolution_CheckForCancel
; The rest of pret engine/movie/evolution.asm is the visual morph layer, which is
; unported; its entry point Evolution_BackAndForthAnim is a ret-stub in the
; sibling src/engine/movie/evolution_stubs.asm, and Evolution_ChangeMonPic and the
; remaining pic/cry routines have no port counterpart at all.
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
; DEFERRED UI (document for Wave 2 integrator): the cries, the palette flash and
; the back-and-forth pic morph are still deferred inside EvolveMon — see its own
; header for the current TODO-HW / [2b] scope.
;
; Build (from repo root):
;   nasm -f coff -I dos_port/include/ -I dos_port/ \
;       -o dos_port/src/engine/movie/evolution.o \
;       dos_port/src/engine/movie/evolution.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

; All WRAM/const aliases formerly declared here as %ifndef self-aliases are now
; in the shared includes (gb_memmap.inc / gb_constants.inc), promoted per
; docs/current_plan_pokemon_behavior.md Stage 0.

; ---------------------------------------------------------------------------
; Globals and externs
; ---------------------------------------------------------------------------
global EvolveMon

; Text/display/input helpers (Stage 2 — evolution now shows text + allows B-cancel):
extern DelayFrames              ; (BL = frame count)
extern DelayFrame               ; wait one frame
extern JoypadLowSensitivity     ; refresh hJoy5 (H_JOY5) low-sensitivity input

; Audio (live since the Phase-3 engine landed — see the EvolveMon header):
extern StopAllMusic             ; src/home/audio.asm
extern PlaySound                ; src/home/audio.asm — AL = sound id
extern PlayMusic                ; src/home/audio.asm — AL = song, BL = audio ROM bank
extern PlayCry                  ; home_stubs.asm — pret: home/pokemon.asm (still a stub)
extern WaitForSoundToFinish     ; src/home/delay.asm
extern Delay3                   ; src/home/palettes.asm

%include "assets/audio_constants.inc"   ; SFX_TINK, MUSIC_SAFARI_ZONE + its _BANK

section .text

; ===========================================================================
; EvolveMon  (pret engine/movie/evolution.asm EvolveMon)
; Runs the evolution animation and returns CF = "player cancelled".
;
; FUNCTIONAL now: the B-cancel loop is LIVE (real JoypadLowSensitivity input,
; honoring wForceEvolution), wEvoCancelled → CF is faithful, and the AUDIO is
; live. The audio used to be deferred behind "TODO-HW (audio HAL, Phase 3)";
; that claim went stale when the Phase-3 engine landed and linked, so the calls
; are restored here against pret's actual sequence. PlayCry is the one piece
; still genuinely missing, and it is missing because the ROUTINE is a stub, not
; because the subsystem is absent — so it is called faithfully and returns.
;
; Still deferred:
;   [2b] (software PPU / palette): EvolutionSetWholeScreenPalette flash,
;     Evolution_LoadPic old/new (LoadFlippedFrontSpriteByMonIndex + pic swap),
;     Evolution_ChangeMonPic / Evolution_BackAndForthAnim tile morph.
; STUB{class=stub; label=PlayCry; pret=home/pokemon.asm:PlayCry; behavior=the old and new species cries do not play, the call is made faithfully at both pret sites and the ret-stub in home_stubs.asm returns immediately; evidence=tools/label_status PlayCry reports stub with provider dos_port/src/home/home_stubs.asm, while every other audio routine this routine calls has a real linked body; lifetime=retire when PlayCry is translated, no change is needed here}
; Because the pic-load path is deferred, this does NOT clobber wCurPartySpecies/
; wCurSpecies, so (unlike pret) it need not save/restore them.
; Out: CF set iff cancelled. Clobbers AL; preserves ESI/EDX/EBX.
; ===========================================================================
EvolveMon:
    push esi
    push edx
    push ebx

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

    ; [2b]: EvolutionSetWholeScreenPalette (old species) + Evolution_LoadPic
    ;       old/new + vFrontPic/vBackPic swap (battle-pic + palette path).

    mov byte [ebp + hAutoBGTransferEnabled], 1 ; ld a,$1 / ldh [hAutoBGTransferEnabled],a
    mov al, [ebp + wEvoOldSpecies]  ; ld a, [wEvoOldSpecies]
    call PlayCry                    ; ret-stub — see the STUB annotation above
    call WaitForSoundToFinish
    mov bl, MUSIC_SAFARI_ZONE_BANK  ; ld c, BANK(Music_SafariZone)
    mov al, MUSIC_SAFARI_ZONE       ; ld a, MUSIC_SAFARI_ZONE
    call PlayMusic

    mov bl, 80                      ; pret: ld c, 80 / call DelayFrames
    call DelayFrames
    ; [2b]: EvolutionSetWholeScreenPalette PAL_BLACK.

    ; pret: lb bc, $1, $10 → 8 passes (c stepped 16→2, dec c twice per pass);
    ; BH = morph "speed" fed to the (deferred) back-and-forth anim, BL = the
    ; per-pass frame budget Evolution_CheckForCancel counts down.
    mov bh, 1
    mov bl, 0x10
.animLoop:
    push ebx
    call Evolution_CheckForCancel
    jc .evolutionCancelled
    call Evolution_BackAndForthAnim ; [2b] no-op stub (tile morph)
    pop ebx
    inc bh
    dec bl
    dec bl
    jnz .animLoop

    xor al, al
    mov [ebp + wEvoCancelled], al
    ; [2b]: Evolution_ChangeMonPic (show the new species pic).
    mov al, [ebp + wEvoNewSpecies]
.done:
    ; pret: ld [wWholeScreenPaletteMonSpecies], a / call StopAllMusic /
    ; ld a, [wWholeScreenPaletteMonSpecies] / call PlayCry. AL arrives holding the
    ; species, and pret parks it in WRAM precisely because StopAllMusic does not
    ; preserve A — so the reload is load-bearing, not redundant.
    mov [ebp + wWholeScreenPaletteMonSpecies], al
    call StopAllMusic
    mov al, [ebp + wWholeScreenPaletteMonSpecies]
    call PlayCry                    ; ret-stub — see the STUB annotation above
    ; [2b]: ld c, 0 / call EvolutionSetWholeScreenPalette.
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
; Evolution_CheckForCancel (pret engine/movie/evolution.asm) — wait BL frames,
; returning CF set if B is pressed (unless wForceEvolution blocks cancelling).
; ---------------------------------------------------------------------------
Evolution_CheckForCancel:
    call DelayFrame
    push ebx
    call JoypadLowSensitivity
    mov al, [ebp + H_JOY5]
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

; ---------------------------------------------------------------------------
; Evolution_BackAndForthAnim — [2b] deferred tile-morph; ret-stub in
; engine/movie/evolution_stubs.asm (STUB{} annotation there). pret morphs the
; on-screen pic back and forth BH times (Evolution_ChangeMonPic ±$31 tile
; offset); the software-PPU/palette morph is deferred.
; ---------------------------------------------------------------------------
extern Evolution_BackAndForthAnim    ; engine/movie/evolution_stubs.asm (STUB)



