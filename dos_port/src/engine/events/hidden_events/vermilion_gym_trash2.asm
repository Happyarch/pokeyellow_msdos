; vermilion_gym_trash2.asm — Vermilion Gym second lock trash can sampling and random table.
;
; Faithful translation of pret engine/events/hidden_events/vermilion_gym_trash2.asm.
;
; Register map: A=AL, B=BH, C=BL, D=DH, E=DL, HL=ESI; GB memory at [EBP + addr].
;
; Build: nasm -f coff -I include/ -I . -o vermilion_gym_trash2.o src/engine/events/hidden_events/vermilion_gym_trash2.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_macros.inc"

global TrashCanRandom
global Yellow_SampleSecondTrashCan
global GymTrashCans3c

extern JumpToAddress                    ; src/home/bankswitch2.asm
extern Random                           ; src/home/random.asm
extern AddNTimes                        ; src/home/array.asm

section .text

; ─────────────────────────────────────────────────────────────────────────────
; TrashCanRandom — pret engine/events/hidden_events/vermilion_gym_trash2.asm:TrashCanRandom
; In: DL = mask (de)
; Out: DL = random index (de), DH = 0
; ─────────────────────────────────────────────────────────────────────────────
TrashCanRandom:
    mov dh, 0                           ; ld d, 0
    movzx edx, dl                       ; de = e, zero-extended (d is 0)
    ; pret: ld hl, .Jumptable / add hl, de / add hl, de / ld a,[hli] / ld h,[hl] /
    ; ld l,a — a 2-byte `dw` row indexed by de. The port's rows are flat `dd`, so
    ; the same index scales by 4. The index is UNBOUNDED on both sides: it is the
    ; row's entry-count byte from GymTrashCans3c, which is only ever 3 or 4.
    mov esi, [TrashCanRandom.Jumptable + edx*4]
    call JumpToAddress                  ; pret: jp hl (the target's ret returns here)
    mov dl, al                          ; ld e, a
    mov dh, 0                           ; ld d, 0
    ret

.zero:
.one:
    mov al, 0                           ; ld a, 0 — flag-neutral like SM83's ld
    ret

.two:
    call Random
    and al, 0x01                        ; and $1
    ret

.three: ; should return to a, instead returns to b
; pret's own source comments this: "should return to a, instead returns to b".
; The three `ld b, n` should be `ld a, n`, so A leaves this case holding the SWAPPED
; RANDOM BYTE (0-255) rather than the intended offset 0-2. TrashCanRandom then does
; `ld e, a`, and Yellow_SampleSecondTrashCan indexes its row by 2*e — i.e. up to 510
; bytes past a 9-byte row. pret calls the result "truly random behavior"; every
; 3-entry row in GymTrashCans3c takes this path, so it is a LIVE path, not a corner.
;
; BUG{class=data-model; pret=engine/events/hidden_events/vermilion_gym_trash2.asm:TrashCanRandom; behavior=case 3 writes the sampled offset to B instead of A so the value returned in E is the raw swapped random byte 0-255 instead of 0-2, which makes Yellow_SampleSecondTrashCan read up to 510 bytes past the row; evidence=pret TrashCanRandom.three uses ld b and pret's own header comment on GymTrashCans3c documents the consequence as truly random behavior; lifetime=permanent latent Gen-1 behavior, fixed only under BUG_FIX_LEVEL 2}
    call Random
    rol al, 4                           ; swap a
    cmp al, 1 * 0xFF / 3
    mov bh, 0                           ; ld b, 0
    jb .three_ret
    cmp al, 2 * 0xFF / 3
    mov bh, 1                           ; ld b, 1
    jb .three_ret
    mov bh, 2                           ; ld b, 2
.three_ret:
%if BUG_FIX_LEVEL >= 2
    mov al, bh
%endif
    ret

.four:
    call Random
    and al, 0x03                        ; and $3
    ret

; ─────────────────────────────────────────────────────────────────────────────
; Yellow_SampleSecondTrashCan — pret engine/events/hidden_events/vermilion_gym_trash2.asm:Yellow_SampleSecondTrashCan
; ─────────────────────────────────────────────────────────────────────────────
Yellow_SampleSecondTrashCan:
    mov esi, GymTrashCans3c
    mov al, [ebp + wGymTrashCanIndex]
    mov bl, al                          ; ld c, a
    mov bh, 0                           ; ld b, 0
    mov al, 9                           ; ld a, 9
    call AddNTimes
    call AddNTimes                      ; ???? (al is 0 on return from AddNTimes, so second call no-ops)
    mov al, [esi]                       ; ld a, [hli]
    inc esi
    mov [ebp + hGymTrashCanRandNumMask], al  ; ldh — the row's entry count, 3 or 4
    mov dl, al                          ; ld e, a
    push esi                            ; push hl
    call TrashCanRandom
    pop esi                             ; pop hl
; DEVIATION{class=data-model; pret=engine/events/hidden_events/vermilion_gym_trash2.asm:Yellow_SampleSecondTrashCan; behavior=on a 3-entry row TrashCanRandom returns an out-of-range offset (the BUG above) so this indexes past GymTrashCans3c and reads whatever the linker placed after it, where pret reads the ROM bytes that followed the table; evidence=pret TrashCanRandom.three leaves A holding a 0-255 swapped random byte and hl advances by 2*e with no bound on either side, so the read is out of bounds in pret too and only the bytes it lands on differ; lifetime=permanent, an exact match would require reproducing the pret ROM bank layout}
    movzx edx, dl                       ; d is already 0 from TrashCanRandom
    add esi, edx                        ; add hl, de
    add esi, edx                        ; add hl, de
    mov al, [esi]                       ; ld a, [hli]
    inc esi
    mov [ebp + wSecondLockTrashCanIndex], al
    mov al, [esi]                       ; ld a, [hl]
    mov [ebp + wSecondLockTrashCanIndex + 1], al
    ret

section .data

align 4
; pret's `.Jumptable`, kept under its pret-local name. `dw` becomes `dd` (flat
; DPMI linear pointers), which is why TrashCanRandom scales the index by 4.
TrashCanRandom.Jumptable:
    dd TrashCanRandom.zero
    dd TrashCanRandom.one
    dd TrashCanRandom.two
    dd TrashCanRandom.three
    dd TrashCanRandom.four

; First byte: number of trashcan entries
; Following four byte pairs: indices for the second trash can.
; Note (pret bug): Rows that have 3 trashcan entries are sampled incorrectly.
; The sampling occurs by taking a random number and seeing which
; third of the range 0-255 the number falls in.  However, it returns
; that value to the wrong register, so the result is never used.
; Instead of using an offset in [0,1,2], the offset is instead
; in the full range 0-255.  This results in truly random behavior.
GymTrashCans3c:
    db 4
    db  1,3,   3,1,   1,-1,  3,-1
    db 3
    db  0,2,   2,4,   4,0,  -1,-1
    db 4
    db  1,5,   5,1,   1,-1,  5,-1
    db 3
    db  0,4,   4,6,   6,0,  -1,-1
    db 4
    db  1,3,   3,1,   5,5,   7,7
    db 3
    db  2,4,   4,8,   8,2,  -1,-1
    db 3
    db  3,7,   7,9,   9,3,  -1,-1
    db 4
    db  4,8,   6,10,  8,4,  10,6
    db 3
    db  5,7,   7,11, 11,5,  -1,-1
    db 3
    db  6,10, 10,12, 12,6,  -1,-1
    db 4
    db  7,9,   9,7,  11,13, 13,11
    db 3
    db  8,10, 10,14, 14,8,  -1,-1
    db 4
    db  9,13, 13,9,   9,-1, 13,-1
    db 3
    db 10,12, 12,14, 14,10, -1,-1
    db 4
    db 11,13, 13,11, 11,-1, 13,-1
