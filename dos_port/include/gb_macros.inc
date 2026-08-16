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
; Makefile passes through as -D BUG_FIX_LEVEL=1. Every fix in the tree is gated
; by `%if BUG_FIX_LEVEL >= N`, an assembly-time conditional, so the level is
; baked into the binary.
;
; *** THE RUNTIME HALF DESCRIBED HERE WAS NEVER BUILT. *** This comment used to
; say entry.asm parses /FIXCRIT and /FIXALL into [bug_fix_level] "which
; runtime-conditional code reads". It does parse them and it does write the byte
; — but NOTHING READS IT: bug_fix_level is `global` in boot/entry.asm and no file
; externs it (verified tree-wide 2026-08-16). The two arguments are inert. They
; also cannot be retrofitted onto the existing fixes, because `%if` is resolved
; before the binary exists. Either wire the byte up and convert fixes to runtime
; conditionals, or delete the arguments; do not document them as working.
; ---------------------------------------------------------------------------
%ifndef BUG_FIX_LEVEL
  %define BUG_FIX_LEVEL 0
%endif

; ---------------------------------------------------------------------------
; Translation comment conventions
;
; BUG(critical): <description>
;   A bug that can cause buffer overflows, OOB writes, save corruption, or
;   arbitrary code execution. Fixed when BUG_FIX_LEVEL >= 1 (/FIXCRIT).
;   Template:
;     ; BUG(critical): <what goes wrong>
;     ; pret ref: <source file>:<label>, docs/bugs_and_glitches.md#L<line>
;     %if BUG_FIX_LEVEL >= 1
;       ; ... fixed implementation
;     %else
;       ; ... original (buggy) behavior
;     %endif
;
; BUG(cosmetic): <description>
;   A minor behavioral or visual bug that does not threaten save data or
;   system stability. Fixed when BUG_FIX_LEVEL >= 2 (/FIXALL).
;   Same template as above but %if BUG_FIX_LEVEL >= 2.
;
; GLITCH: <name> — <description>
;   An intentional glitch that users may exploit (MissingNo, item dup, etc.).
;   Safety tag: "safe under DPMI" or "unsafe on bare HW if ACE reachable".
;   These are never fixed by any flag — they are preserved behavior.
;   Example:
;     ; GLITCH: MissingNo encounter — reads past end of species table
;     ; Safety: safe under DPMI (bounded to emulated WRAM)
;
; TODO-HW: <description>
;   A GB hardware I/O access that has not yet been translated.
;   The original code is preserved as a comment; a stub (nop or ret) is emitted.
;   Example:
;     ; TODO-HW: write to rLCDC ($FF40) to enable/disable LCD
;     ;   original: ld [rLCDC], a
;     ;   pending: software renderer reads [EBP + IO_LCDC] to determine render state
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

; Load byte from HRAM offset (ldh a, [offset]) — offset is $FF00-relative
%macro GB_LDH_A 1
    mov al, [ebp + GB_IO + (%1 & 0x7F)]
%endmacro

; Store AL to HRAM offset (ldh [offset], a)
%macro GB_LDH 1
    mov [ebp + GB_IO + (%1 & 0x7F)], al
%endmacro

%endif ; GB_MACROS_INC
