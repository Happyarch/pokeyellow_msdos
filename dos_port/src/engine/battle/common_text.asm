; common_text.asm — RetreatMon and the switch-out message chain.
;
; Source (faithful translation): engine/battle/common_text.asm:183-260.
;
; PORTED 2026-08-12 (battle plan 2a). This whole file is new: the port had no
; mirror of pret's engine/battle/common_text.asm, and `RetreatMon` read `missing`
; in the label DB, which is what stopped `SwitchPlayerMon` from being ported.
;
; WHAT THE CHAIN DOES. When the player withdraws a mon, pret does not print one
; fixed line — it measures how much the ENEMY mon's HP fell since the last
; switch-in and picks the trainer's parting comment accordingly:
;   drop == 0   -> EnoughText          ("That's enough!")
;   drop 1-29%  -> ComeBackText        ("Come back!")
;   drop 30-69% -> OKExclamationText   ("OK!")
;   drop >= 70% -> GoodText            ("Good!")
; The three non-ComeBack lines then chain INTO ComeBackText, so the player sees
; e.g. "Good! / Come back!".
;
; TIER SPLIT, per the two-tier rule. The four printable intros are DATA and are
; generated: `_PlayerMon2Text`, `_EnoughText`, `_OKExclamationText`, `_GoodText`
; are emitted by tools/generators/gen_battle_text.py's EXTRA_FAR list (added in
; this same change), and `ComeBackText` is an ordinary generated wrapper. Only
; the SELECTOR — pret's `text_asm` tails — is code, and it lives here. That is
; the same split `TrainerEndBattleText` (src/home/trainers.asm) already uses, and
; the generator's own comment prescribes it: a `text_far` + `text_asm` wrapper is
; deliberately not flattened, because the far part is only the intro and the rest
; is chosen at runtime.
;
; TX_ASM CONTRACT. The port's TextCommandProcessor `.cmd_asm` is
; `push .next_cmd / jmp esi` (src/home/text.asm:1387), exactly pret's
; `ld de, NextTextCommand / push de / jp hl`. So an inline routine runs with the
; stream pointer in ESI and, by RETURNING with ESI set to another stream, makes
; the processor continue there — which is precisely how these selectors work.
;
; DEVIATION{class=data-model; pret=engine/battle/common_text.asm:PlayerMon2Text; behavior=the big-endian HP words are read at absolute offsets instead of pret's hl/de pointer walk with dec hl and dec de; evidence=pret walks the two words backwards only because the SM83 has no displacement addressing, and the port has [ebp+disp] so the same four bytes are read directly - the arithmetic including the sub/sbb borrow chain is unchanged; lifetime=permanent while the port uses x86 addressing}
;
; Register map (CLAUDE.md): A=AL, B=BH, C=BL, D=DH, E=DL, HL=ESI, DE=EDX,
; EBP = GB base, [ebp+addr].
;
; Build: nasm -f coff -I include/ -I . -o common_text.o common_text.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

TX_FAR_CMD equ 0x17                 ; TextCommandProcessor TX_FAR  (src/home/text.asm)
TX_ASM_CMD equ 0x08                 ; TextCommandProcessor TX_ASM

extern PrintText                    ; src/home/window.asm — ESI = stream
extern Multiply                     ; src/home/math.asm — hMultiplicand x hMultiplier
extern Divide                       ; src/home/math.asm — hDividend / hDivisor, BH = bytes
extern _PlayerMon2Text              ; assets/battle_text.inc (generated Tier-1 intro)
extern _EnoughText                  ; assets/battle_text.inc
extern _OKExclamationText           ; assets/battle_text.inc
extern _GoodText                    ; assets/battle_text.inc
extern ComeBackText                 ; assets/battle_text.inc (ordinary generated wrapper)

global RetreatMon
global PlayerMon2Text
global EnoughText
global OKExclamationText
global GoodText
global PrintComeBackText

section .text

; ---------------------------------------------------------------------------
; RetreatMon — pret common_text.asm:183. `ld hl, PlayerMon2Text / jp PrintText`.
; Called by SwitchPlayerMon before the withdraw animation.
; ---------------------------------------------------------------------------
RetreatMon:
    mov esi, PlayerMon2Text
    jmp PrintText                   ; pret: jp (tail)

; ---------------------------------------------------------------------------
; PlayerMon2Text — the intro, then a selector that measures the enemy mon's HP
; drop since the last switch-in and returns the matching outcome stream.
;
; pret's own comment on the arithmetic, kept because it documents a real quirk:
;   a = ((LastSwitchInEnemyMonHP - CurrentEnemyMonHP) * 25) / (EnemyMonMaxHP / 4)
; approximates the percentage the enemy's HP has fallen — ASSUMING it has not
; GAINED HP. If it has, the subtraction wraps and `a` is garbage that can land in
; any of the ranges below. That is Game Boy behaviour and is reproduced, not
; fixed: the wrap is what a faithful port must do.
; ---------------------------------------------------------------------------
PlayerMon2Text:
    db TX_FAR_CMD
    dd _PlayerMon2Text
    db TX_ASM_CMD
.asm:
    push edx                                    ; pret: push de
    push ebx                                    ; pret: push bc
    ; drop = wLastSwitchInEnemyMonHP - wEnemyMonHP, both big-endian words.
    ; Low bytes first so the borrow chains into the high byte, exactly as pret's
    ; sub/sbc pair does.
    mov bh, [ebp + wEnemyMonHP + 1]             ; ld b,[hl]  (current, low)
    mov al, [ebp + wLastSwitchInEnemyMonHP + 1] ; ld a,[de]  (previous, low)
    sub al, bh                                  ; sub b      (CF = borrow)
    mov [ebp + hMultiplicand + 2], al
    mov bh, [ebp + wEnemyMonHP]                 ; ld b,[hl]  (current, high)
    mov al, [ebp + wLastSwitchInEnemyMonHP]     ; ld a,[de]  (previous, high)
    sbb al, bh                                  ; sbc b      (consumes the borrow)
    mov [ebp + hMultiplicand + 1], al
    mov byte [ebp + hMultiplier], 25            ; ld a,25 / ldh [hMultiplier],a
    call Multiply
    ; divisor = (wEnemyMonMaxHP >> 2) low byte
    mov al, [ebp + wEnemyMonMaxHP]              ; ld a,[hli]  (max, high)
    mov bh, [ebp + wEnemyMonMaxHP + 1]          ; ld b,[hl]   (max, low)
    shr al, 1                                   ; srl a
    rcr bh, 1                                   ; rr b        (>> 1 across the word)
    shr al, 1                                   ; srl a
    rcr bh, 1                                   ; rr b        (>> 2 = maxHP / 4)
    mov al, bh                                  ; ld a, b
    mov bh, 4                                   ; ld b, 4  (Divide's byte count)
    mov [ebp + hDivisor], al                    ; ldh [hDivisor], a
    call Divide
    pop ebx                                     ; pret: pop bc
    pop edx                                     ; pret: pop de
    mov al, [ebp + hQuotient + 3]               ; ldh a,[hQuotient + 3]
    mov esi, EnoughText                         ; HP stayed the same
    test al, al                                 ; and a
    jz .ret                                     ; ret z
    mov esi, ComeBackText                       ; 1% - 29%
    cmp al, 30
    jb .ret                                     ; ret c
    mov esi, OKExclamationText                  ; 30% - 69%
    cmp al, 70
    jb .ret                                     ; ret c
    mov esi, GoodText                           ; 70% or more
.ret:
    ret                                         ; .cmd_asm resumes at ESI

; ---------------------------------------------------------------------------
; The three outcome lines. Each prints its own intro and then chains into
; ComeBackText (pret: `text_asm / jr PrintComeBackText`).
; ---------------------------------------------------------------------------
EnoughText:
    db TX_FAR_CMD
    dd _EnoughText
    db TX_ASM_CMD
    jmp short PrintComeBackText                 ; pret: jr PrintComeBackText

OKExclamationText:
    db TX_FAR_CMD
    dd _OKExclamationText
    db TX_ASM_CMD
    jmp short PrintComeBackText

GoodText:
    db TX_FAR_CMD
    dd _GoodText
    db TX_ASM_CMD
    jmp short PrintComeBackText

PrintComeBackText:
    mov esi, ComeBackText                       ; pret: ld hl, ComeBackText
    ret
