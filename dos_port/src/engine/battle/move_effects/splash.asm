; 1019__SplashEffect.asm — SplashEffect (the "But nothing happened!" no-op move).
;
; Faithful translation of engine/battle/effects.asm:SplashEffect (pret/pokeyellow).
; Splash is the simplest move-effect handler in Gen 1: play the (subanim-only) move
; animation, then unconditionally print "But nothing happened!" — no accuracy test,
; no substitute check, no WRAM writes at all.
;
; pret source (engine/battle/effects.asm):
;   SplashEffect:
;       call PlayCurrentMoveAnimation
;       jp PrintNoEffectText
;
;   PrintNoEffectText:
;       ld hl, NoEffectText
;       jp PrintText
;
;   NoEffectText:
;       text_far _NoEffectText
;       text_end
;
; PrintNoEffectText is trivial two-instruction glue (load the stream pointer, tail
; into PrintText) — not itself a §4 shared extern (move_effect_helpers.asm exposes
; PrintText/PrintDidntAffectText/etc., but no PrintNoEffectText wrapper), so per the
; PoisonEffect_ template convention (load the text-stream label into ESI, jmp
; PrintText directly) its body is inlined here rather than externed.
;
; Fidelity boundary: docs/move_translation_divergence.md. PlayCurrentMoveAnimation is
; a §2-item-1 allowlist stub (literal subanim, ANIMATION=OFF path) — called, not
; redefined. NoEffectText is the generated battle_text.inc stream (already global).
; No bugs/glitches: pret's bugs_and_glitches.md has no Splash-specific entry, and the
; handler has no conditional logic to diverge in.
;
; Register map: A=AL, HL=ESI, EBP=GB base. GB memory at [EBP+addr] (unused here —
; Splash touches no WRAM).
;
; Build: nasm -f coff -I include/ -I . -o /dev/null 1019__SplashEffect.asm

bits 32

%include "gb_macros.inc"
%include "gb_memmap.inc"
%include "gb_constants.inc"

section .text

global SplashEffect_

; --- allowlist anim stub (§2 item 1: literal subanim, ANIMATION=OFF path) ---
extern PlayCurrentMoveAnimation

; --- shared scaffold extern (§4: call, never define) ---
extern PrintText                    ; move_effect_helpers.asm — ESI = flat text stream

; --- battle_text.inc stream (global in core.o) ---
extern NoEffectText

; ===========================================================================
; SplashEffect_ — Splash: no accuracy test, no target check, no state change.
; Plays the move's subanimation, then unconditionally prints "But nothing
; happened!". Equivalent to pret's PrintNoEffectText inlined (ld hl, NoEffectText
; / jp PrintText).
; ===========================================================================
SplashEffect_:
    call PlayCurrentMoveAnimation
    mov esi, NoEffectText
    jmp PrintText
