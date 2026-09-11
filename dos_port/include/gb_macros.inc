; gb_macros.inc — Translation macros and bug-fix level definitions.
; Include after gb_memmap.inc in every translated source file.

%ifndef GB_MACROS_INC
%define GB_MACROS_INC

; ---------------------------------------------------------------------------
; Bug fix level
; 0 = original behavior (all glitches active) — default
; 1 = fix critical bugs only (buffer overflows, OOB writes, save corruption, ACE)
; 2 = fix all documented bugs (cosmetic, behavioral, critical)
;
; Set at BUILD time, and only at build time: make BUG_FIX_LEVEL=1, which the
; Makefile passes through as -D BUG_FIX_LEVEL=1. Every fix is gated by
; `%if BUG_FIX_LEVEL >= N` — a preprocessor conditional, so NASM assembles one
; arm and discards the other. The value is not stored anywhere and no code can
; read it; the binary simply contains whichever arm was selected.
; ---------------------------------------------------------------------------
%ifndef BUG_FIX_LEVEL
  %define BUG_FIX_LEVEL 0
%endif

; ---------------------------------------------------------------------------
; Translation comment conventions — MACHINE-PARSED ANNOTATIONS
;
; Exactly four kinds: DEVIATION, BUG, GLITCH, STUB.
; Must adhere to single-line format:
;   ; KIND{class=<class>; pret=<file>:<Label>; behavior=<what differs>; evidence=<why true>; lifetime=<what retires it>}
;
; Required fields for all kinds: class, pret, behavior, evidence, lifetime.
; In addition:
;   - GLITCH also requires: safety=<safety assessment>
;   - STUB also requires:   label=<symbol name>; class must be 'stub' or 'temporary'
;
; Allowed classes: HAL, banking, projection, data-model, timing, stub, temporary.
; Syntax rule: No ';' or '}' allowed inside field values (the parser splits on ';').
;
; BUG pairs the annotation with a compile-time conditional block:
;   ; BUG{class=data-model; pret=...; behavior=...; evidence=...; lifetime=...}
;   %if BUG_FIX_LEVEL >= 1  ; 1 = critical only, 2 = all
;     ; fixed implementation
;   %else
;     ; original (buggy) behavior
;   %endif
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; Convenience macros for GB memory access via EBP
; ---------------------------------------------------------------------------

; Load byte from GB address in ESI into AL
%macro GB_LD_A_HL 0
    mov al, [ebp + esi]
%endmacro

; Store AL to GB address in ESI
%macro GB_LD_HL_A 0
    mov [ebp + esi], al
%endmacro

; Load byte from GB address in ESI into AL, post-increment ESI (hli)
%macro GB_LD_A_HLI 0
    mov al, [ebp + esi]
    inc esi
%endmacro

; Store AL to GB address in ESI, post-increment ESI (hli)
%macro GB_LD_HLI_A 0
    mov [ebp + esi], al
    inc esi
%endmacro

; Load byte from GB address in ESI into AL, post-decrement ESI (hld)
%macro GB_LD_A_HLD 0
    mov al, [ebp + esi]
    dec esi
%endmacro

; Load byte from HRAM/IO offset (ldh a, [offset]) — offset is $FF00-relative ($FF00-$FFFE)
%macro GB_LDH_A 1
    mov al, [ebp + GB_IO + (%1 & 0xFF)]
%endmacro

; Store AL to HRAM/IO offset (ldh [offset], a)
%macro GB_LDH 1
    mov [ebp + GB_IO + (%1 & 0xFF)], al
%endmacro

%endif ; GB_MACROS_INC
