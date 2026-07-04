; dos_port/src/engine/overworld/daycare_exp.asm — IncrementDayCareMonExp
;
; Source: engine/overworld/daycare_exp.asm:IncrementDayCareMonExp (pret/pokeyellow).
; Ticks the day-care mon's stored EXP by 1 (called once per overworld step
; while a mon is left in day-care — see scripts/Daycare.asm). Pure WRAM-only
; leaf routine, no hardware I/O boundary.
;
; Register map: a=AL, hl=ESI (pointer walking the 3-byte EXP field).
; GB WRAM is [ebp + sym].
;
; Big-endian note (asm-translation skill / CLAUDE.md): wDayCareMonExp is a
; 3-byte GB value stored HIGH byte first — wDayCareMonExp+0 is the MSB,
; +1 the mid byte, +2 the LSB. pret's carry chain walks it LSB-first
; (wDayCareMonExp+2, then +1, then +0), i.e. a manual ripple-carry "+1" on a
; big-endian number. This port preserves that exact byte order and walk
; direction byte-for-byte; +0 is never treated as a little-endian low byte,
; and the field is never re-assembled/re-stored as a native 24/32-bit int.
;
; x86 has no conditional RET, so pret's three `ret z` / `ret nz` / `ret c`
; each become a jcc to a single shared tail label (`.done`). In every case the
; flag the jcc reads is produced by the instruction immediately before it
; (test al,al -> jz; inc [mem] -> jnz; cmp -> jc), so nothing clobbers the
; flag between producer and consumer. The `dec esi` pointer steps (mirroring
; pret's `dec hl`) sit *after* their preceding jnz has already consumed ZF and
; *before* the next `inc [mem]` re-produces it, so letting dec disturb ZF/CF
; there is flag-safe.
;
; Build: nasm -f coff -I include/ -I . -o daycare_exp.o daycare_exp.asm

bits 32

%include "gb_memmap.inc"

; wDayCareInUse (0xDA47) and wDayCareMonExp (0xDA6C, = wDayCareMon + MON_EXP,
; 3-byte big-endian) are defined in gb_memmap.inc.

global IncrementDayCareMonExp

section .text

IncrementDayCareMonExp:
    ; pret: ld a, [wDayCareInUse] / and a / ret z
    mov al, [ebp + wDayCareInUse]
    test al, al                        ; ZF set iff no mon is in day-care
    jz .done

    ; pret: ld hl, wDayCareMonExp + 2   (LSB of the big-endian 3-byte field)
    mov esi, wDayCareMonExp + 2

    ; pret: inc [hl] / ret nz  -- LSB += 1; return unless it wrapped to 0
    inc byte [ebp + esi]
    jnz .done

    ; pret: dec hl  (pointer step; the ZF this instruction disturbs was
    ; already consumed by the jnz above, and the next inc reproduces ZF)
    dec esi

    ; pret: inc [hl] / ret nz  -- mid byte += 1 (carry from LSB); return
    ; unless it also wrapped to 0
    inc byte [ebp + esi]
    jnz .done

    ; pret: dec hl
    dec esi

    ; pret: inc [hl]  -- MSB += 1 (carry from mid byte); no wrap check here,
    ; pret falls through into the cap check unconditionally
    inc byte [ebp + esi]

    ; pret: ld a, [hl] / cp $50 / ret c  -- CF set iff MSB < 0x50 (unsigned);
    ; return without clamping in that case
    mov al, [ebp + esi]
    cmp al, 0x50
    jc .done

    ; pret: ld a, $50 / ld [hl], a  -- MSB reached/exceeded 0x50: clamp it
    ; back down to 0x50 (day-care EXP-tick cap)
    mov byte [ebp + esi], 0x50

.done:
    ret
