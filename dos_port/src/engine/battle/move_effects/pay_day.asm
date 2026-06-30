; 1188__PayDayEffect.asm — PayDayEffect (move-effect translation swarm worker output).
;
; Faithful translation of engine/battle/effects.asm:PayDayEffect (pret/pokeyellow):
; scatters coins worth (2 x the user's level), expressed as a 3-byte BCD value
; written to wPayDayMoney, and accumulates that into the running wTotalPayDayMoney
; BCD total for the battle. Prints CoinsScatteredText.
;
; RE-TRANSLATION — the prior draft (src/engine/battle/move_effects/pay_day.asm)
; FAILED audit on two register-convention bugs, both fixed here:
;   1. Divide's byte-count input is BH (`mov bh, <count>`), not EBX/BL. The old
;      draft did `mov ebx, 4`, which sets BL=4/BH=0 — _Divide's `movzx ebx, bh`
;      then reads 0, so `test ebx, ebx; jz .done` aborts the divide before it runs.
;      See dos_port/src/engine/math/multiply_divide.asm:_Divide header comment
;      ("BH = dividend length in bytes (1..4)") and every other call site
;      (core_damage.asm, experience.asm, move_mon.asm) using `mov bh, N`.
;   2. AddBCD's calling convention is ESI=hl (source ptr), EDX=de (dest ptr),
;      CL=c (byte count) — see dos_port/src/engine/math/bcd.asm:AddBCD's own
;      comment ("AddBCD adds [hl] to [de] for c bytes. ESI = hl, EDX = de, CL =
;      c"). The old draft loaded EDI/EBX instead, which AddBCD never reads.
;
; pret's call site is `predef AddBCDPredef` (a bank-switched predef call). Per
; the fidelity spec §2 item 4 (bank switching: call the flat target directly,
; drop the bank load), this handler calls AddBCD directly — NOT AddBCDPredef.
; AddBCDPredef's first action is `call GetPredefRegisters`, which overwrites
; ESI/EDX/EBX from the wPredefHL/DE/BC mailbox (dos_port/src/home/predef.asm) —
; a mailbox nothing in this flat call chain populates, so going through
; AddBCDPredef here would clobber our freshly-set ESI/EDX/CL with stale/zeroed
; predef-mailbox values instead of the registers we just loaded. Calling AddBCD
; directly with the registers set per its own header comment is the correct flat
; translation, matching how other already-merged handlers treat predef bank calls.
;
; Fidelity boundary: docs/move_translation_divergence.md. Shared externs (§4) are
; called, not redefined; only §2 allowlist items (bank-switched predef call)
; diverge.
;
; Register map: A=AL, B=BH, C=BL (BC=BX), D=DH, E=DL (DE=EDX), HL=ESI, EBP=GB base.
; GB memory at [EBP+addr]; battle_text streams are flat program addresses.
;
; Build: nasm -f coff -I include/ -I . -o /dev/null 1188__PayDayEffect.asm

bits 32

%include "gb_macros.inc"
%include "gb_memmap.inc"
%include "gb_constants.inc"

section .text

global PayDayEffect_

; --- shared scaffold externs (§4: call, never define) ---
extern Divide                       ; home/math.asm — preserves esi/edx/bx, BH = dividend byte count
extern AddBCD                       ; engine/math/bcd.asm — ESI=hl src, EDX=de dst, CL=c (flat target; §2 item 4)
extern PrintText                    ; move_effect_helpers.asm — ESI = flat text stream
extern CoinsScatteredText           ; assets/battle_text.inc (generated Tier-1 data)

; --- missing-WRAM equs (flag for master) ---
; Neither wPayDayMoney nor wTotalPayDayMoney is in gb_memmap.inc yet. Both are
; derived below from ram/wram.asm by counting bytes from the nearest addresses
; ALREADY verified in gb_memmap.inc, the same technique used in
; scratch/994__ChargeEffect.asm for wChargeMoveNum.
;
; wTotalPayDayMoney (ram/wram.asm:618, "ds 3", a plain sequential field):
;   wEnemyMoveListIndex equ 0xCCE2          (gb_memmap.inc:238, verified)
;   + wEnemyMoveListIndex   db   (1 byte)   -> 0xCCE3
;   + wLastSwitchInEnemyMonHP dw (2 bytes)  -> 0xCCE5
;   = wTotalPayDayMoney starts at 0xCCE5, runs 3 bytes (0xCCE5-0xCCE7).

; wPayDayMoney (ram/wram.asm:1083) lives inside a `UNION ... NEXTU ... ENDU`
; block (ram/wram.asm:1067, "This union spans 20 bytes") as the 3rd NEXTU
; branch; every UNION/NEXTU branch starts at the SAME base address as the
; union's first branch, wNameBuffer, which gb_memmap.inc already has at
; 0xCD6D ("wNameBuffer equ 0xCD6D ... = wMoveData scratch union", gb_memmap.inc
; line 801; cross-checked against wMoveData equ 0xCD6D, the union's 2nd
; branch, also already present). NAME_BUFFER_LENGTH = 20
; (constants/text_constants.asm:8), so the union's 20-byte span comfortably
; covers wPayDayMoney's 3 bytes at the same base.
; FLAG FOR MASTER: add `wTotalPayDayMoney equ 0xCCE5` and
; `wPayDayMoney equ 0xCD6D` to gb_memmap.inc proper.

; ===========================================================================
; PayDayEffect_ — pret engine/battle/effects.asm:PayDayEffect.
; Scatters coins worth level*2, BCD-encoded into wPayDayMoney (3 bytes), and
; adds that into the running wTotalPayDayMoney BCD total for the battle.
; ===========================================================================
PayDayEffect_:
    xor al, al
    mov esi, wPayDayMoney               ; ld hl, wPayDayMoney
    mov [ebp + esi], al                  ; ld [hli], a
    inc esi

    mov al, [ebp + hWhoseTurn]           ; ldh a, [hWhoseTurn]
    test al, al
    mov al, [ebp + wBattleMonLevel]      ; ld a, [wBattleMonLevel]
    jz .payDayEffect                     ; jr z, .payDayEffect
    mov al, [ebp + wEnemyMonLevel]       ; ld a, [wEnemyMonLevel]
.payDayEffect:
    ; level * 2
    add al, al                           ; add a
    mov [ebp + hDividend + 3], al        ; ldh [hDividend + 3], a
    xor al, al
    mov [ebp + hDividend], al            ; ldh [hDividend], a
    mov [ebp + hDividend + 1], al        ; ldh [hDividend + 1], a
    mov [ebp + hDividend + 2], al        ; ldh [hDividend + 2], a

    ; convert to BCD — first digit pair: (level*2) / 100
    mov al, 100
    mov [ebp + hDivisor], al             ; ldh [hDivisor], a
    mov bh, 4                            ; ld b, $4 — Divide's byte-count input is BH, not EBX
    call Divide
    mov al, [ebp + hQuotient + 3]        ; ldh a, [hQuotient + 3]
    mov [ebp + esi], al                  ; ld [hli], a ; wPayDayMoney + 1
    inc esi

    ; second pass: remainder / 10, swap nibbles in, OR in the new remainder
    mov al, [ebp + hRemainder]           ; ldh a, [hRemainder]
    mov [ebp + hDividend + 3], al        ; ldh [hDividend + 3], a
    mov al, 10
    mov [ebp + hDivisor], al             ; ldh [hDivisor], a
    mov bh, 4                            ; ld b, $4
    call Divide
    mov al, [ebp + hQuotient + 3]        ; ldh a, [hQuotient + 3]
    rol al, 4                            ; swap a
    mov bl, al                           ; ld b, a
    mov al, [ebp + hRemainder]           ; ldh a, [hRemainder]
    add al, bl                           ; add b
    mov [ebp + esi], al                  ; ld [hl], a ; wPayDayMoney + 2 (no hl increment, matches pret)

    ; accumulate into the running battle total (3-byte BCD add, LSB-first,
    ; pret: `ld de, wTotalPayDayMoney + 2 / ld c, $3 / predef AddBCDPredef`).
    ; ESI is already wPayDayMoney + 2 from the store immediately above — AddBCD
    ; walks both pointers downward by c bytes, so esi/edx both start at their
    ; arrays' LAST (least-significant) byte.
    mov edx, wTotalPayDayMoney + 2      ; ld de, wTotalPayDayMoney + 2
    mov cl, 3                            ; ld c, $3
    call AddBCD                          ; flat target — §2 item 4 (predef bank call dropped)

    mov esi, CoinsScatteredText          ; ld hl, CoinsScatteredText
    jmp PrintText                        ; jp PrintText
