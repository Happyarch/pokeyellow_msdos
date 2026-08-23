; evolution_stubs.asm — link-time stubs for the deferred engine/movie/ visual
; layer (pret engine/movie/credits.asm).
;
; The whole of pret engine/movie/evolution.asm is now translated and live in
; src/engine/movie/evolution.asm — sequence AND visual morph layer. The
; Evolution_BackAndForthAnim ret-stub that used to live here was RETIRED with
; the morph (docs/current_plan_evolution_animation.md Stage 3); the real body is
; in the mirror file beside Evolution_ChangeMonPic.
;
; The trade animation (pret engine/movie/trade.asm) stubs that used to live
; here (InternalClockTradeAnim / ExternalClockTradeAnim) RETIRED in link plan
; Stage 3 step 3: the real bodies are now in src/engine/movie/trade.asm. Only
; the Hall of Fame PC stub below is still deferred.
;
; Register map (CLAUDE.md): A=AL, BC=BX, DE=DX, HL=ESI, EBP = GB base.
bits 32
section .text

; HallOfFamePC — STUB RETIRED 2026-08-23: the real routine now links from
; src/engine/movie/credits.asm, which is the mirror this stub's TODO was waiting
; for. scripts/HallOfFame.asm's predef call now runs the ceremony and the roll.

; InternalClockTradeAnim / ExternalClockTradeAnim — STUBS RETIRED 2026-08-23:
; the real routines now link from src/engine/movie/trade.asm.

