; vcopy.asm — home util singletons: standalone CopyString + IsInRestOfArray.
;
; These two small home routines have no dedicated file in the port yet, so they
; are grouped here as the "util" companions to the copy2.asm VRAM family (this
; file is the M10.1 util bucket; it does NOT port pret's BG-map vcopy.asm, whose
; physical-$9800 routines are dead under the native W_TILEMAP renderer).
;
; Sources:
;   * CopyString        — pret home/copy_string.asm (standalone entry; the port
;                         already has CopyToStringBuffer folded into core.asm,
;                         but not the bare CopyString that callers `ld hl` into).
;   * IsInRestOfArray   — pret home/array2.asm (the mid-array entry that IsInArray
;                         falls through to; the port's src/home/array.asm exports
;                         IsInArray only).
;
; Register map: HL→ESI, DE→EDX, BC→BX (B=BH, C=BL), A→AL.
;
; Build: nasm -f coff -I include/ -o vcopy.o vcopy.asm

bits 32

%include "gb_memmap.inc"

global CopyString
global IsInRestOfArray

section .text

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

; ---------------------------------------------------------------------------
; IsInRestOfArray — mid-array entry for the IsInArray search (pret array2.asm).
; Identical to src/home/array.asm:IsInArray but WITHOUT the leading `xor bh,bh`,
; so the caller preloads BH (running match count / index). Array read is FLAT
; ([ESI]) — the coord/predicate arrays that use this live in program .data,
; not GB WRAM (matches IsInArray and itemfinder.asm:HiddenItemNear).
;
; In:  AL  = value to find
;      ESI = array base (FLAT pointer), -1 ($FF) terminated
;      EDX = entry stride in bytes (DE); low word is what callers set (`mov dx,n`)
;      BH  = starting count/index (B) — caller-preset
; Out: CF = found; BH = 0-based index of the match (or count at terminator).
;      Clobbers ESI (advances), CL. AL/EDX preserved.
; ---------------------------------------------------------------------------
IsInRestOfArray:
.loop:
    mov cl, [esi]                    ; ld a, [hl] — flat read
    cmp cl, 0xFF                     ; cp -1 → terminator?
    je .notfound
    cmp cl, al                       ; cp c (value in AL)
    je .found
    inc bh                           ; inc b
    add esi, edx                     ; add hl, de (advance by stride)
    jmp .loop
.notfound:
    clc
    ret
.found:
    stc
    ret
