; copy_data.asm — CopyData / FarCopyData translated from SM83 to x86.
;
; Source: home/copy.asm:CopyData, FarCopyData (pret/pokeyellow)
;
; CopyData    — copy BC bytes from HL to DE.
; FarCopyData — copy BC bytes from a:HL to DE (A = source ROM bank).
;
; The SM83 16-bit-count double-loop (can't branch on `dec bc`) collapses to
; `rep movsb`, as in FillMemory. FarCopyData's ROM-bank switch is a flat no-op
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

    movzx ecx, bx
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
