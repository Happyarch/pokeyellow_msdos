; copy_data.asm — CopyData / FarCopyData translated from SM83 to x86.
;
; Source: home/copy.asm:CopyData, FarCopyData (pret/pokeyellow)
;
; CopyData    — copy BC bytes from HL to DE.
; FarCopyData — copy BC bytes from a:HL to DE (A = source ROM bank).
;
; The SM83 16-bit-count double-loop (can't branch on `dec bc`) collapses to
; `rep movsb`, as in FillMemory. Semantics match pret for all counts 1..65535;
; they DIVERGE only at BC=0 — pret CopyData(BC=0) copies 256 bytes (B=0 falls
; straight into .copybytes, C=0 underflows the loop 256×), the port copies 0.
; Safe: no caller passes BC=0 expecting 256 (callers that want 256 pass $100).
; Intentionally NOT emulated (pret's 256 is an underflow artifact, not a feature).
; FarCopyData's ROM-bank switch is a flat no-op
; under our unified address space. ; TODO-HW: model ROM banking when needed.
;
; Register map: HL→ESI (src, EBP-relative), DE→EDX (dst, EBP-relative),
; BC→BX (count), A→AL (bank for FarCopyData).
;
; Build: nasm -f coff -I include/ -o copy_data.o copy_data.asm

bits 32

%include "gb_memmap.inc"
%include "gb_macros.inc"

global CopyData
global FarCopyData
global CopyDataUntil

section .text

; ---------------------------------------------------------------------------
; CopyData — copy BX bytes from [EBP+ESI] to [EBP+EDX]
;
; In:  ESI = source GB offset (HL), EDX = dest GB offset (DE), BX = count
; Out: ESI, EDX advanced past the copied range (matches SM83 hl/de on return).
;      ECX clobbered. EBX preserved.
; ---------------------------------------------------------------------------
CopyData:
    push edi

    movzx ecx, bx                    ; count; BX=0 → 0 bytes (pret would copy 256 — see header)
    lea esi, [ebp + esi]
    movzx edi, dx
    lea edi, [ebp + edi]
    rep movsb

    sub esi, ebp
    mov edx, edi
    sub edx, ebp

    pop edi
    ret

; ---------------------------------------------------------------------------
; FarCopyData — copy BC bytes from a:HL to DE.
; Under the flat model the bank (AL) is irrelevant. Forwards to CopyData.
; ; TODO-HW: resolve (AL:HL) to a linear offset when ROM banking is modelled.
; ---------------------------------------------------------------------------
FarCopyData:
    jmp CopyData

; ---------------------------------------------------------------------------
; CopyDataUntil — copy [HL, BC) to [DE, ...). Source runs from HL up to (but
; not including) BC; destination starts at DE.  Source: home/move_mon.asm.
;
; In:  ESI = source GB offset (HL), EDX = dest GB offset (DE),
;      BX  = end-of-source GB offset, exclusive (BC).
; Out: ESI = BX, EDX = DE + (BX - HL). AL clobbered; EBX preserved.
;
; The SM83 does a 16-bit equality via two 8-bit compares (cp b / cp c); the
; whole-register `cmp si, bx` is the faithful equivalent. All these pointers
; are WRAM ($C000-$DFFF), so the low-16-bit compare matches GB semantics.
; ---------------------------------------------------------------------------
CopyDataUntil:
    mov al, [ebp + esi]
    inc esi
    mov [ebp + edx], al
    inc edx
    cmp si, bx
    jne CopyDataUntil
    ret
