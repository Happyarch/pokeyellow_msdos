; ============================================================================
; DEAD / DEFERRED — NOT IN THE BUILD (intentionally absent from dos_port/Makefile).
;
; GetPredefPointer is a faithful skeleton of pret's predef dispatcher, but the
; backing table `PredefPointers` (pret data/predef_pointers.asm) is NOT yet
; ported, so the references below (and the commented-out %include) are
; UNRESOLVED. This file therefore does not link and is deliberately excluded
; from every SRCS list.
;
; The only predef code the port links today is the leaf src/home/predef.asm
; (GetPredefRegisters). There is no predef *caller* in the port yet; predef WRAM
; slots are populated directly by callers / test harnesses.
;
; To revive: port data/predef_pointers.asm to a `PredefPointers` dd/db table,
; uncomment the include, add this file to a SRCS list. See M0.5 report.
; ============================================================================
%include "dos_port/include/gb_memmap.inc"

SECTION .text

global GetPredefPointer

GetPredefPointer:
	; save hl (esi)
	mov eax, esi
	mov [ebp + wPredefHL + 1], al
	shr eax, 8
	mov [ebp + wPredefHL], al

	; save de (dx)
	mov [ebp + wPredefDE], dh
	mov [ebp + wPredefDE + 1], dl

	; save bc (bx)
	mov [ebp + wPredefBC], bh
	mov [ebp + wPredefBC + 1], bl

	; PredefPointers lookup
	mov al, [ebp + wPredefID]
	movzx ecx, al
	lea ecx, [ecx + ecx*2]

	lea edi, [PredefPointers + ecx]

	; get bank of predef routine
	mov al, [edi]
	mov [ebp + wPredefBank], al

	; get pointer
	mov al, [edi + 1]
	mov ah, [edi + 2]
	movzx esi, ax

	ret

; We leave the include here to be assembled if needed,
; or it can be resolved by the linker.
; %include "data/predef_pointers.asm"
