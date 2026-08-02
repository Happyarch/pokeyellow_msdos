; predef.inc — the tx_pre_* macro family from pret macros/predef.asm.
;
; pret spells a predef-text call site as:
;
;     MACRO tx_pre_id
;         ld a, (\1_id - TextPredefs) / 2 + 1
;     ENDM
;     MACRO tx_pre        / tx_pre_jump
;         tx_pre_id \1    / tx_pre_id \1
;         call PrintPredefTextID  / jp PrintPredefTextID
;     ENDM
;
; The port computes the id differently, and it has to. Two reasons, both hard:
;   1. TextPredefs rows are 8 bytes here ({dd stream, dd size}, the same flat row
;      the ordinary map text table uses), not pret's 2-byte `dw`, so `/ 2` is wrong.
;   2. More fundamentally, the subtraction cannot be done at all: TextPredefs lives
;      in another object file (src/data/predef_text_data.asm) and NASM/COFF carries
;      no cross-object `equ`. This is the same limitation that blocks the
;      MapHeaderPointers relocation.
; So the ids are generated as assembly-time constants instead — assets/predef_text_ids.inc,
; emitted by tools/generators/gen_predef_text.py straight from pret's add_tx_pre
; order. Include that file alongside this one; `tx_pre_id Foo` then resolves Foo_id.
;
; The macro NAMES and the call-site shape are pret's, so a translated routine reads
; line-for-line against the disassembly.

%ifndef PREDEF_INC
%define PREDEF_INC

; tx_pre_id <Label> — AL = the predef text id of <Label>.
%macro tx_pre_id 1
    mov al, %1 %+ _id
%endmacro

; tx_pre <Label> — call the predef text dispatch (pret: call PrintPredefTextID).
%macro tx_pre 1
    tx_pre_id %1
    call PrintPredefTextID
%endmacro

; NOTE there is deliberately NO tx_pre_jump macro here, although pret has one.
; pret's is exactly `tx_pre_id \1` + `jp PrintPredefTextID`, and at a routine TAIL
; the port must spell those two lines out:
;
;     tx_pre_id RedBedroomSNESText
;     jmp PrintPredefTextID           ; pret: tx_pre_jump RedBedroomSNESText
;
; because update_label_db's build-graph scanner decides fall-through at a routine
; boundary and refuses to guess for a macro whose expansion jumps out — it raises
; "boundary decided by macro tx_pre_jump, whose expansion is not proven to return
; control". Writing the `jmp` at the call site keeps the boundary a real
; instruction the scanner can classify, and costs one line against pret.

%endif ; PREDEF_INC
