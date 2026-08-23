; dos_port/src/data/pokemon/unknown_list.asm
; ============================================================
; Mirror of pret data/pokemon/unknown_list.asm — the carrier for Pointer_3b0ee.
;
; pret's own comment: "This list is used by a unreferenced function." That
; function is engine/pokemon/evos_moves.asm:Func_3b0a2, which is ported; the list
; is its only reason to exist.
;
; The bytes are Tier-1 data (tools/generators/gen_unknown_list.py transcribes the
; species list out of pret's file and resolves the names through
; assets/script_constants.inc), and this file is the carrier the aux placement
; rule pins to pret's path — a generated .inc is exempt, its .asm is not.
;
; The included .inc declares its own `global Pointer_3b0ee`, so this wrapper does not.
;
; Build: nasm -f coff -I include/ -I . -o unknown_list.o unknown_list.asm

bits 32

section .data
align 4

%include "assets/unknown_list.inc"
