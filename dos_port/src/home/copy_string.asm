; dos_port/src/home/copy_string.asm
; ============================================================
; Mirror of pret home/copy_string.asm: CopyToStringBuffer, CopyString, in pret
; order. Both were relocated port-side — CopyToStringBuffer sat inside
; engine/battle/core.asm and CopyString in the src/home/vcopy.asm "util bucket"
; (which is now the real home/vcopy.asm mirror).
;
; SHAPE NOTE, preserved as found: pret's CopyToStringBuffer sets hl = wStringBuffer
; and FALLS THROUGH into CopyString. The port has two independent bodies — the
; wStringBuffer one copies through EDI, the general one through ESI — so the
; fallthrough does not exist here. That predates this move; re-deriving pret's
; shape is a behaviour change, not a relocation.
;
; Register map: a=AL, de=EDX, hl=ESI, EBP = GB base; GB memory = [EBP+addr].

bits 32

%include "gb_memmap.inc"

global CopyString

section .text

; ---------------------------------------------------------------------------
; CopyToStringBuffer — pret home/copy_string.asm. Copies the '@'-terminated string
; at EDX (GB addr) into wStringBuffer. Used by the Rage continuation (move name).
; ---------------------------------------------------------------------------
global CopyToStringBuffer            ; Wave 5/M5.3: give.asm consumes it once linked
CopyToStringBuffer:
    mov edi, wStringBuffer
.copy:
    mov al, [ebp + edx]
    inc edx
    mov [ebp + edi], al
    inc edi
    cmp al, 0x50                        ; '@'
    jne .copy
    ret

; ---------------------------------------------------------------------------
; CopyString — copy a '@'-terminated (0x50) string from EDX (DE) to ESI (HL).
; pret home/copy_string.asm:CopyString. Both pointers are EBP-relative GB
; offsets (matching the port's CopyToStringBuffer in core.asm, which copies to
; wStringBuffer and shares this loop body).
;
; In:  EDX = source GB offset (EBP-relative), ESI = destination GB offset (EBP-rel)
; Out: ESI/EDX advanced past the copied '@'; AL clobbered. Terminator IS copied.
; ---------------------------------------------------------------------------
CopyString:
.copy:
    mov al, [ebp + edx]              ; ld a, [de]
    inc edx
    mov [ebp + esi], al              ; ld [hli], a
    inc esi
    cmp al, 0x50                     ; cp "@"
    jne .copy
    ret
