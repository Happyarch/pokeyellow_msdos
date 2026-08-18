; evolution_stubs.asm — link-time stubs for the deferred engine/movie/ visual
; layer (pret engine/movie/evolution.asm and engine/movie/trade.asm).
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
