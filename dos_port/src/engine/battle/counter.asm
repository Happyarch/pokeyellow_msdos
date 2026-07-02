; counter.asm — HandleCounterMove (battle-swarm worker ticket).
;
; Faithful translation of engine/battle/core.asm:4718 HandleCounterMove (pret/pokeyellow).
; Determines whether the attacking side's selected move is Counter, and if so whether it
; connects: the target's last-selected move must be Normal/Fighting-typed and non-zero
; base power, and must not itself be Counter. On success it doubles wDamage (clamped to
; $FFFF) and re-runs MoveHitTest for the doubled hit; on any failure path it leaves
; wMoveMissed=1 so the caller's `jz HandleIfPlayerMoveMissed` treats it as a miss.
;
; Fidelity boundary: docs/plans/move_translation_divergence.md. No §2 allowlist item is
; exercised here (no animation/audio/bank call); this is pure WRAM logic + MoveHitTest.
;
; Register map: A=AL; F.Z=ZF, F.C=CF; HL=ESI (hl/de/bc use full 32-bit regs per project
; convention); DE=EDX (D=DH,E=DL); BC=BX (B=BH,C=BL); EBP=GB base.
; GB memory at [EBP+addr].
;
; Build: nasm -f coff -I include/ -I . -o counter.o counter.asm

bits 32

%include "gb_macros.inc"
%include "gb_memmap.inc"
%include "gb_constants.inc"

section .text

global HandleCounterMove

; --- shared scaffold extern (§4: call, never define) ---
extern MoveHitTest                  ; core_damage.asm — accuracy test → wMoveMissed

; ===========================================================================
; HandleCounterMove — engine/battle/core.asm:4718.
;
; The variables checked by Counter are updated whenever the cursor points to a new move
; in the battle selection menu. This is irrelevant for the opponent's side outside of
; link battles, since the move selection is controlled by the AI. However, in the
; scenario where the player switches out and the opponent uses Counter, the outcome may
; be affected by the player's actions in the move selection menu prior to switching the
; Pokemon. This might also lead to desync glitches in link battles.
;
; Caller contract (do not change): "Not Counter" returns ZF=0 (caller falls through to
; normal damage); every path where the attacker's move IS Counter returns ZF=1 (its
; damage, if any, is already in wDamage) — this is exactly what the faithful translation
; below produces, with no manual ZF massaging.
; ===========================================================================
HandleCounterMove:
    mov al, [ebp + hWhoseTurn]      ; ldh a, [hWhoseTurn] ; whose turn
    and al, al
    ; player's turn
    mov esi, wEnemySelectedMove     ; ld hl, wEnemySelectedMove
    mov edx, wEnemyMovePower        ; ld de, wEnemyMovePower
    mov al, [ebp + wPlayerSelectedMove]   ; ld a, [wPlayerSelectedMove]
    jz .next                        ; jr z, .next
    ; enemy's turn
    mov esi, wPlayerSelectedMove    ; ld hl, wPlayerSelectedMove
    mov edx, wPlayerMovePower       ; ld de, wPlayerMovePower
    mov al, [ebp + wEnemySelectedMove]    ; ld a, [wEnemySelectedMove]
.next:
    cmp al, 0x44                    ; cp COUNTER
    jnz .notCounter                 ; ret nz ; return if not using Counter (ZF=0 preserved)
    mov byte [ebp + wMoveMissed], 1 ; ld a,$01 / ld [wMoveMissed],a — assume miss until it lands
    mov al, [ebp + esi]             ; ld a, [hl]
    cmp al, 0x44                    ; cp COUNTER
    jz .ret                         ; ret z ; miss if the opponent's last selected move is Counter.
    mov al, [ebp + edx]             ; ld a, [de]
    and al, al
    jz .ret                         ; ret z ; miss if the opponent's last selected move's Base Power is 0.
    ; check if the move the target last selected was Normal or Fighting type
    ; (wPlayerMoveType/wEnemyMoveType sit immediately after MovePower in gb_memmap.inc,
    ; so this indexes [edx+1] rather than a pret "inc de")
    mov al, [ebp + edx + 1]         ; inc de / ld a, [de]
    and al, al                      ; normal type
    jz .counterableType
    cmp al, 0x01                    ; cp FIGHTING
    jz .counterableType
    ; if the move wasn't Normal or Fighting type, miss
    xor al, al
    ret
.counterableType:
    ; BUG(cosmetic): "Unexpected Counter damage" — Counter simply doubles wDamage, which
    ; holds the last damage value dealt by *anyone* (player, opponent, a since-switched-out
    ; opponent, or even another link-battle player) because wDamage is shared and never
    ; cleared between turns/switches/battles. Inherent Gen-1 behavior, preserved verbatim.
    ; pret ref: engine/battle/core.asm#L4960, bugs_and_glitches.md#unexpected-counter-damage
    ; (fix listed as TBD upstream — no BUG_FIX_LEVEL gate to key off here).
    mov esi, wDamage                ; ld hl, wDamage
    mov al, [ebp + esi]             ; ld a, [hli] — high byte
    or al, [ebp + esi + 1]          ; or [hl] — or with low byte
    jz .ret                         ; ret z
    mov al, [ebp + esi + 1]         ; ld a, [hl] — low byte
    add al, al                      ; add a
    mov [ebp + esi + 1], al         ; ld [hld], a — write doubled low byte
    mov al, [ebp + esi]             ; ld a, [hl] — high byte
    adc al, al                      ; adc a
    mov [ebp + esi], al             ; ld [hl], a — write doubled(+carry) high byte
    jnc .noCarry                    ; jr nc, .noCarry
    mov byte [ebp + esi], 0xff      ; ld a,$ff / ld [hli],a
    mov byte [ebp + esi + 1], 0xff  ; ld [hl], a
.noCarry:
    mov byte [ebp + wMoveMissed], 0 ; xor a / ld [wMoveMissed], a
    call MoveHitTest
    xor al, al
    ret
.notCounter:
    ret                              ; ZF=0 still set from the cmp above
.ret:
    ret
