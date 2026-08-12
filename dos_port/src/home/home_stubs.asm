; home_stubs.asm — ret-only stubs for pret home/ routines that must resolve at
; link time but whose real bodies are deferred. Per the stub convention
; (project-conventions skill), the stand-in lives HERE under its exact pret
; label — never as a ret-only body in the file that will eventually hold the
; real routine (src/home/text_script.asm already holds the faithful body; it is
; simply not linkable yet).
;
; Register map: A→AL, HL→ESI, BC→BX, DE→DX; GB mem = [ebp+SYM] (gb_memmap.inc).

bits 32

section .text

; ---------------------------------------------------------------------------
; PlayCry / GetCryData — STUBS RETIRED 2026-08-12 (battle plan 1d, commit in the
; same change). Both real bodies now live in their pret-mirrored file,
; src/home/pokemon.asm (pret home/pokemon.asm:140 and :157).
;
; The long note that stood here was already correct and is not repeated: it had
; retired the "no audio HAL (Phase 3)" excuse, listed every dependency as
; present (generated CryData, cry-aware engine_1.asm, real PlaySound and
; WaitForSoundToFinish), and recorded the contract a ret-only stub silently
; broke — pret's PlayCry BLOCKS in WaitForSoundToFinish for the length of the
; cry, and UsedStrengthText's message depended on that block, not on any
; register (ledger M-32, observed live 2026-07-13). Restoring the bodies
; restores the wait. Do not re-add a stand-in here.
; ---------------------------------------------------------------------------
