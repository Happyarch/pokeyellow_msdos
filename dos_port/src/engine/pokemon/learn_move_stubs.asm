; learn_move_stubs.asm — link-time stub for learn_move.asm's DisplayTextBoxID call.
;
; Mirrors the existing src/engine/battle/core_stubs.asm precedent for the same
; "faithful caller, deferred backend" situation: learn_move.asm is a real,
; structure-for-structure translation of pret's engine/pokemon/learn_move.asm,
; including its two interactive YES/NO prompts (TryingToLearn's "delete a move
; to make room?" and AbandonLearning's "give up?"), both driven by the real
; pret DisplayTextBoxID dispatcher (pret home/textbox.asm). The real
; implementation (src/home/text_script.asm:DisplayTextBoxID, forwarding to
; DisplayTextBoxID_) is check-only right now — it belongs to the separate
; menus-port branch/session (docs/current_plan_menus.md) and isn't linked. Until
; it is, this stub stands in under the exact pret name so learn_move.asm can
; link today and reach a genuine, non-hanging pret outcome instead of a
; hand-rolled substitute for the whole caller.
;
; Behavior: alternates NO then YES-give-up across the (at most) two
; DisplayTextBoxID calls a single LearnMove invocation can make when all 4
; move slots are full — TryingToLearn's own prompt declines to delete a move
; (wCurrentMenuItem=1), then AbandonLearning's own prompt agrees to give up
; (wCurrentMenuItem=0) — reaching pret's real "declined, gave up" terminal
; outcome (DidNotLearnText, B=0) deterministically. A FIXED constant return
; would instead loop forever (AbandonLearning "NO, don't give up" routes back
; to DontAbandonLearning, which re-enters TryingToLearn with nothing changed) —
; a real player breaks that loop by eventually answering differently; a stub
; can't, so it must alternate instead.
;
; DELETE THIS FILE (and drop it from the Makefile's POKEMON_SRCS) once a real
; DisplayTextBoxID is promoted to a linked group — the duplicate global symbol
; must not coexist with the real one.
;
; In:  [wTextBoxID] = box selector (only TWO_OPTION_MENU is exercised from this
;      worktree today). esi(hl)/bh:bl(bc) = box coords/cursor — unused (no
;      rendering; this stub never draws anything).
; Out: [wCurrentMenuItem] set per the alternation above.

bits 32

%include "gb_memmap.inc"

section .bss
lm_stub_toggle: resb 1

section .text

global DisplayTextBoxID

DisplayTextBoxID:
    not byte [lm_stub_toggle]           ; 0x00 <-> 0xFF each call
    mov al, [lm_stub_toggle]
    and al, 1                           ; 1st call -> 1 (NO), 2nd -> 0 (YES/give up)
    mov [ebp + wCurrentMenuItem], al
    ret
