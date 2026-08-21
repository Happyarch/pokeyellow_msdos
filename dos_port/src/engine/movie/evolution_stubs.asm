; evolution_stubs.asm — link-time stubs for the deferred engine/movie/ visual
; layer (pret engine/movie/trade.asm).
;
; The whole of pret engine/movie/evolution.asm is now translated and live in
; src/engine/movie/evolution.asm — sequence AND visual morph layer. The
; Evolution_BackAndForthAnim ret-stub that used to live here was RETIRED with
; the morph (docs/current_plan_evolution_animation.md Stage 3); the real body is
; in the mirror file beside Evolution_ChangeMonPic. Only the trade animation
; below is still deferred.
;
; Register map (CLAUDE.md): A=AL, BC=BX, DE=DX, HL=ESI, EBP = GB base.
bits 32
section .text

; The in-game trade animation (pret engine/movie/trade.asm), reached as
; `predef InternalClockTradeAnim` from engine/events/in_game_trades.asm's
; InGameTrade_DoTrade and from engine/link/cable_club.asm. It is purely
; cinematic: the whole trade — flag set, RemovePokemon, AddPartyMon, the
; wTraded* mirror, the trade-evolution check — is done by the caller around it,
; so the port trades correctly while the animation is missing.
; It lands in this file rather than a trade_stubs.asm of its own because a new
; source file cannot be linked without a Makefile edit (owned elsewhere); the
; area is right (pret engine/movie/) and it retires with the real routine.
; TODO(in-game-trade/link): replace with a translation of engine/movie/trade.asm
; (InternalClockTradeAnim + its LoadTradingGFXAndMonNames/TradeAnim* body). It
; IS reached in the live build — any of the six NPC trades runs it.
; STUB{class=temporary; label=InternalClockTradeAnim; pret=engine/movie/trade.asm:InternalClockTradeAnim; behavior=return immediately instead of playing the cable-link trade cinematic - the mon sprites entering and leaving the tubes, the ball animation and the trade jingle; evidence=engine/movie/trade.asm is unported (no port definition of InternalClockTradeAnim or of its LoadTradingGFXAndMonNames body) while its callers in_game_trades.asm and cable_club.asm perform every data-side effect of the trade themselves; lifetime=until engine/movie/trade.asm is translated}
global InternalClockTradeAnim
InternalClockTradeAnim:
    ret

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
