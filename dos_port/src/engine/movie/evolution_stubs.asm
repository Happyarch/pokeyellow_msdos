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

; The Hall of Fame PC screen (pret engine/movie/credits.asm:HallOfFamePC), the
; post-championship "PROF.OAK's PC" replay of the Hall of Fame entries. Its only
; port caller is HallOfFamePCForever in src/engine/pikachu/pikachu_emotions.asm,
; which pret guards with IF DEF(_DEBUG) and which nothing calls on either side —
; so this stub is NOT reached in the live build; it exists to resolve that call.
; It lands in this file for the same reason InternalClockTradeAnim does: the area
; is right (pret engine/movie/) and there is no credits.asm mirror yet.
; TODO(credits/hall-of-fame): replace with a translation of
; engine/movie/credits.asm (HallOfFamePC + the credits sequence around it).
; STUB{class=temporary; label=HallOfFamePC; pret=engine/movie/credits.asm:HallOfFamePC; behavior=return immediately instead of drawing the Hall of Fame PC screen and paging through the recorded champion parties; evidence=engine/movie/credits.asm is unported - the label DB reports HallOfFamePC missing with no port definition - and its only port reference is the unreferenced debug-only HallOfFamePCForever; lifetime=until engine/movie/credits.asm is translated}
global HallOfFamePC
HallOfFamePC:
    ret
