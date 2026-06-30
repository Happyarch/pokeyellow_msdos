; move_grammar.asm — generated move-use sentence-grammar table (battle engine).
;
; MoveGrammar : tools/gen_move_grammar.py (from data/moves/grammar.asm). Vestigial in
; the English ROM (all groups yield the same "<MON> used <MOVE>!" sentence) but the base
; game still ships and walks it, so we carry it for faithfulness. Consumed by the
; (hand-authored, Tier-2) GetMoveGrammar in the future used_move_text translation.
;
; The included .inc declares its own `global MoveGrammar`, so this wrapper does not.
;
; Build: nasm -f coff -I include/ -I . -o move_grammar.o move_grammar.asm

bits 32

section .data
align 4

%include "assets/move_grammar.inc"
