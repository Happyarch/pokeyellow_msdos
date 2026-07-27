; copy.asm — mirror of pret home/copy.asm.
;
; Holds two of that file's four pret labels: CopyData and FarCopyData. The other
; two, CopyVideoDataAlternate and CopyVideoDataDoubleAlternate, are unported
; (status `missing`) — the port's VRAM-write primitive is CopyVideoData, a
; home/vcopy.asm label in src/home/vcopy.asm, and nothing calls the Alternate pair.
;
; NOT in pret order, and deliberately left that way: pret puts FarCopyData first
; (home/copy.asm:1) and CopyData second (:13), while the port has them the other
; way round with FarCopyData ending in `jmp CopyData`. Swapping them would turn
; that jump into a fallthrough, which is a shape change, not a relocation — so it
; is a separate piece of work, recorded here rather than smuggled into this move.
;
; Was src/home/copy_data.asm until the mirror repair; CopyDataUntil, which that
; file also carried, is a home/move_mon.asm label and moved to src/home/move_mon.asm.
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
; Build: nasm -f coff -I include/ -o copy.o copy.asm

bits 32

%include "gb_memmap.inc"
%include "gb_macros.inc"

global CopyData
global FarCopyData

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
