; type_names.asm — type-id -> name table (wrapper around generated data).
;
; WideTypeNames : tools/gen_type_names.py (from data/types/names.asm). Indexed by raw
; Gen-1 type id; the unused 0x09-0x13 gap points at NORMAL (faithful to pret). Consumed
; by engine/battle/print_type.asm (pret's TypeNames, one flat pointer per entry) and by
; status_screen.asm. The .inc declares its own global.
;
; Build: nasm -f coff -I include/ -I . -o type_names.o type_names.asm

bits 32
section .data
align 4

%include "assets/type_names.inc"
