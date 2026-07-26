; dos_port/src/engine/pokemon/evolution.asm
; ============================================================
; The evolution ANIMATION half — pret engine/movie/evolution.asm.
;
; Pret refs: engine/movie/evolution.asm (EvolveMon, Evolution_CheckForCancel).
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
;       -o dos_port/src/engine/pokemon/evolution.o \
;       dos_port/src/engine/pokemon/evolution.asm

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

section .text

; ===========================================================================
; EvolveMon  (pret engine/movie/evolution.asm EvolveMon)
; Runs the evolution animation and returns CF = "player cancelled".
;
; FUNCTIONAL now: the B-cancel loop is LIVE (real JoypadLowSensitivity input,
; honoring wForceEvolution), and wEvoCancelled → CF is faithful. Deferred:
;   TODO-HW (audio HAL, Phase 3): StopAllMusic / SFX_TINK / PlayCry(old,new) /
;     PlayMusic(MUSIC_SAFARI_ZONE).
;   [2b] (software PPU / palette): EvolutionSetWholeScreenPalette flash,
;     Evolution_LoadPic old/new (LoadFlippedFrontSpriteByMonIndex + pic swap),
;     Evolution_ChangeMonPic / Evolution_BackAndForthAnim tile morph.
; Because the pic-load path is deferred, this does NOT clobber wCurPartySpecies/
; wCurSpecies, so (unlike pret) it need not save/restore them.
; Out: CF set iff cancelled. Clobbers AL; preserves ESI/EDX/EBX.
; ===========================================================================
EvolveMon:
    push esi
    push edx
    push ebx

    ; TODO-HW: audio HAL (Phase 3) — StopAllMusic; PlaySound SFX_TINK; Delay3;
    ;          PlayCry [wEvoOldSpecies]; PlayMusic MUSIC_SAFARI_ZONE.
    ; [2b]: EvolutionSetWholeScreenPalette (old species) + Evolution_LoadPic
    ;       old/new + vFrontPic/vBackPic swap (battle-pic + palette path).

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
    ; TODO-HW: audio HAL (Phase 3) — StopAllMusic; PlayCry AL; palette AL.
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



