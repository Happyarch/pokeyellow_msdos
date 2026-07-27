; evolution_stubs.asm — link-time stubs for pret engine/movie/evolution.asm.
;
; The evolution SEQUENCE (EvolveMon's control-flow spine: cancel check, species
; swap, stat recompute, learnset check) is faithful and live in
; src/engine/movie/evolution.asm. The visual morph layer of pret's
; engine/movie/evolution.asm is deferred; its entry point stubs here so the
; sequence still CALLS it where pret does (2026-07-23 allowlist audit: a
; ret-only stand-in belongs in a *_stubs.asm under a STUB{} annotation, not in a
; code file behind a relocation-registry entry).
;
; Register map (CLAUDE.md): A=AL, BC=BX, DE=DX, HL=ESI, EBP = GB base.
bits 32
section .text

; STUB{class=temporary; label=Evolution_BackAndForthAnim; pret=engine/movie/evolution.asm:Evolution_BackAndForthAnim; behavior=return immediately instead of morphing the on-screen pic between old and new species BH times via Evolution_ChangeMonPic with the ±$31 wEvoMonTileOffset trick; evidence=Evolution_ChangeMonPic and the software-PPU pic morph are unported ([2b] deferred visual layer, caller evolution.asm runs the faithful species/stat changes around it); lifetime=until the evolution pic morph lands}
global Evolution_BackAndForthAnim
Evolution_BackAndForthAnim:
    ret
