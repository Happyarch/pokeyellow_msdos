; dos_port/src/home/array2.asm
; ============================================================
; Mirror of pret home/array2.asm: CallFunctionInTable, IsInArray,
; IsInRestOfArray, in pret order. All three were relocated port-side —
; CallFunctionInTable into home/run_map_script.asm, IsInArray into
; home/array.asm (which mirrors pret home/array.asm and keeps
; SkipFixedLengthTextEntries / AddNTimes), and IsInRestOfArray into the
; src/home/vcopy.asm "util bucket".
;
; SHAPE NOTE, preserved as found: pret's IsInArray sets b = 0 and FALLS THROUGH
; into IsInRestOfArray. The port has two independent loop bodies that differ only
; by the leading `xor bh, bh`. That duplication predates this move; collapsing it
; back into pret's fallthrough is a behaviour change, not a relocation.
;
; Register map: a=AL, b=BH, c=BL, de=EDX, hl=ESI. The arrays these search live in
; the program image, so they are read FLAT ([esi]), not EBP-relative.

bits 32

global CallFunctionInTable
global IsInArray
global IsInRestOfArray

section .text

; CallFunctionInTable — call function index AL in the flat dd jumptable ESI.
; pret's version is a 16-bit table (add a / ld a,[hli] / ld h,[hl]); here the table
; is flat dd, so index ×4 and load a 32-bit pointer. ESI/EDX/EBX preserved.
CallFunctionInTable:
    push esi
    push edx
    push ebx
    movzx ecx, al
    mov esi, [esi + ecx*4]
    call esi
    pop ebx
    pop edx
    pop esi
    ret


; ---------------------------------------------------------------------------
; IsInArray — pret home/array2.asm:IsInArray (shared home global).
; Search a $FF(-1)-terminated array at ESI (HL) for the value in AL (A).
; Entry size is EDX (DE) bytes. Returns CF=1 and BH (B) = 0-based index of the
; match if found; CF=0 if the terminator is reached first.
; Reads the array with FLAT addressing ([ESI]) — the effect-category arrays and
; HM/move tables that use this live in program .data (flat), not GB WRAM.
; In:  AL = value, ESI = array base (flat), EDX = entry stride (bytes).
; Out: CF = found, BH = count/index. Clobbers ESI (advances), BH, CL. AL/EDX kept.
; ---------------------------------------------------------------------------
IsInArray:
    xor bh, bh                  ; ld b, 0  (running count → match index)
.loop:
    mov cl, [esi]               ; ld a, [hl] — flat read
    cmp cl, 0xFF                ; cp -1 → terminator?
    je .notfound
    cmp cl, al                  ; cp c
    je .found
    inc bh                      ; inc b
    add esi, edx                ; add hl, de (advance by stride)
    jmp .loop
.notfound:
    clc
    ret
.found:
    stc
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
