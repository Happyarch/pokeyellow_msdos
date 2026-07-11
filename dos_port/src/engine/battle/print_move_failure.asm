; print_move_failure.asm — PrintMoveFailureText (battle core, move-effect swarm ticket).
;
; Faithful translation of engine/battle/core.asm:PrintMoveFailureText (pret/pokeyellow).
; Prints the "doesn't affect"/"missed"/"unaffected" text for a move that failed to land,
; then (Gen-1 preserved) handles the Jump Kick / Hi Jump Kick "kept going and crashed"
; recoil path when the failed move's effect was JUMP_KICK_EFFECT.
;
; Fidelity boundary: docs/plans/move_translation_divergence.md. Only §2 allowlist items
; (predef→flat bank-switch call for PredefShakeScreenHorizontally) diverge.
;
; Register map: A=AL, B=BH (BC=BX), D=DH,E=DL (DE=EDX), HL=ESI, EBP=GB base.
; GB memory at [EBP+addr].
;
; Build: nasm -f coff -I include/ -I . -o print_move_failure.o print_move_failure.asm

bits 32

%include "gb_macros.inc"
%include "gb_memmap.inc"
%include "gb_constants.inc"

section .text

global PrintMoveFailureText

; --- shared scaffold externs (call, never define) ---
extern PrintText                        ; move_effect_helpers.asm — ESI = flat text stream
; --- battle_text.inc streams (global in assets/battle_text.inc) ---
extern DoesntAffectMonText
extern AttackMissedText
extern UnaffectedText
extern KeptGoingAndCrashedText
; --- battle core tail targets (core.asm) ---
extern ApplyDamageToPlayerPokemon
extern ApplyDamageToEnemyPokemon
; --- allowlist: predef→flat bank-switch call (§2 item 4) ---
extern PredefShakeScreenHorizontally

; ===========================================================================
; PrintMoveFailureText — pret engine/battle/core.asm:3889
; Prints why a move had no effect (immune / missed / already-unaffected via
; the OHKO "unaffected" marker), then clears wCriticalHitOrOHKO. If the move
; whose turn just failed was Jump Kick/Hi Jump Kick (JUMP_KICK_EFFECT), applies
; the Gen-1 crash-recoil damage (always damage/8, minimum 1) to the user.
; ===========================================================================
PrintMoveFailureText:
    mov edx, wPlayerMoveEffect          ; ld de, wPlayerMoveEffect
    mov al, [ebp + hWhoseTurn]          ; ldh a, [hWhoseTurn]
    and al, al
    jz .playersTurn
    mov edx, wEnemyMoveEffect           ; ld de, wEnemyMoveEffect
.playersTurn:
    mov esi, DoesntAffectMonText        ; ld hl, DoesntAffectMonText
    mov al, [ebp + wDamageMultipliers]
    and al, EFFECTIVENESS_MASK          ; 0x7F
    jz .gotTextToPrint                  ; multiplier==0 -> "doesn't affect"
    mov esi, AttackMissedText           ; ld hl, AttackMissedText
    mov al, [ebp + wCriticalHitOrOHKO]
    cmp al, 0xFF
    jnz .gotTextToPrint                 ; not the "unaffected" OHKO marker -> "missed"
    mov esi, UnaffectedText             ; ld hl, UnaffectedText
.gotTextToPrint:
    push edx                            ; push de (move-effect ptr survives PrintText)
    call PrintText
    xor al, al
    mov [ebp + wCriticalHitOrOHKO], al
    pop edx                             ; pop de
    mov al, [ebp + edx]                 ; ld a, [de] — move effect
    cmp al, JUMP_KICK_EFFECT            ; 0x2D
    jnz .ret                            ; ret nz

    ; GLITCH: Gen-1 Jump Kick/Hi Jump Kick crash recoil is always exactly 1 HP.
    ; wDamage is 0 here (the move missed before any damage was calculated), so the
    ; intended "damage/8" recoil always collapses to the post-shift minimum of 1.
    ; Preserved as-is. Not separately catalogued in docs/bugs_and_glitches.md or
    ; docs/references/yellow_glitches.md (corrected a stale backref to the former
    ; this pass — that file has no Jump Kick entry). pret ref:
    ; engine/battle/core.asm:PrintMoveFailureText. Safety: safe under DPMI
    ; (bounded WRAM arithmetic, no ACE potential).
    mov esi, wDamage                    ; ld hl, wDamage
    mov al, [ebp + esi]                 ; ld a, [hli] — high byte
    inc esi
    mov bl, [ebp + esi]                 ; ld b, [hl] — low byte (hl == wDamage+1)
    ; 16-bit big-endian {al:bl} >>= 3, faithful SRL A / RR B x3 (x86 SHR/RCR are
    ; bit-for-bit equivalent to Z80 SRL/RR w.r.t. the carry flag).
    shr al, 1
    rcr bl, 1
    shr al, 1
    rcr bl, 1
    shr al, 1
    rcr bl, 1
    mov [ebp + esi], bl                 ; ld [hl], b — store low byte at wDamage+1
    dec esi                             ; dec hl -> wDamage
    mov [ebp + esi], al                 ; ld [hli], a — store high byte at wDamage
    inc esi                             ; (hli post-increment) hl -> wDamage+1
    or al, bl                           ; or b — a = high | low, sets ZF
    jnz .applyRecoil
    inc al                              ; inc a (a was 0 here -> a = 1)
    mov [ebp + esi], al                 ; ld [hl], a — clamp low byte (== wDamage+1) to 1
.applyRecoil:
    mov esi, KeptGoingAndCrashedText    ; ld hl, KeptGoingAndCrashedText
    call PrintText
    mov bh, 4                           ; ld b, $4
    call PredefShakeScreenHorizontally  ; predef PredefShakeScreenHorizontally (allowlist §2.4)
    mov al, [ebp + hWhoseTurn]          ; ldh a, [hWhoseTurn]
    and al, al
    jnz .enemyTurn
    jmp ApplyDamageToPlayerPokemon      ; jp ApplyDamageToPlayerPokemon — recoil hits the user
.enemyTurn:
    jmp ApplyDamageToEnemyPokemon
.ret:
    ret
