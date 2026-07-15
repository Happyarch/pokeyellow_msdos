; 1020__DisableEffect.asm — DisableEffect (move-effect translation swarm).
;
; Faithful translation of engine/battle/effects.asm:DisableEffect (pret/pokeyellow).
; Accuracy-tests via MoveHitTest, then on hit: fails if the target already has a
; disabled move; otherwise picks a random non-empty move slot (0-3) on the target,
; rolls a random 1-8 turn duration, and packs (slot+1)<<4 | duration into
; wPlayerDisabledMove/wEnemyDisabledMove. Stores the disabled move's move-number
; (for the name print) into wPlayerDisabledMoveNumber/wEnemyDisabledMoveNumber.
;
; Fidelity boundary: docs/move_translation_divergence.md. Shared externs (§4) are
; called, not redefined; only §2 allowlist items (literal subanim, audio, banks)
; diverge.
;
; Register map: A=AL, B=BH, C=BL (BC=BX/EBX), D=DH, E=DL (DE=EDX), HL=ESI, EBP=GB base.
; GB memory at [EBP+addr]; battle_text streams are flat program addresses.
;
; Build: nasm -f coff -I include/ -I . -o /dev/null 1020__DisableEffect.asm

bits 32

%include "gb_macros.inc"
%include "gb_memmap.inc"
%include "gb_constants.inc"

section .text

global DisableEffect_

; --- shared scaffold externs (§4: call, never define) ---
extern MoveHitTest                  ; core_damage.asm — accuracy test → wMoveMissed
extern BattleRandom                 ; core_damage.asm
extern PrintText                    ; move_effect_helpers.asm — ESI = flat text stream
extern PrintButItFailedText_        ; move_effect_helpers.asm — "But it failed!"
extern GetMoveName                  ; home/names.asm — name of move [wNamedObjectIndex]
; --- allowlist anim stub (§2 item 1: literal subanim, ANIMATION=OFF path) ---
extern PlayCurrentMoveAnimation2
; --- battle_text.inc streams (global in core.o) ---
extern MoveWasDisabledText

; ===========================================================================
; DisableEffect_ — pret engine/battle/effects.asm:DisableEffect.
;
; NOTE (faithful, no extra code needed): pret's DisableEffect does NOT call
; CheckTargetSubstitute itself — it relies solely on MoveHitTest's internal
; substitute handling, which only blocks DRAIN_HP_EFFECT/DREAM_EATER_EFFECT
; behind a substitute. This is the well-known Gen-1 "Substitute doesn't block
; most non-damaging status moves" quirk (Disable, Leech Seed, Mimic, Conversion,
; etc. all bypass an active Substitute). Preserved verbatim by simply not adding
; a substitute check here, matching pret. pret ref: engine/battle/core.asm:
; MoveHitTest (the only substitute gate in this call path).
; ===========================================================================
DisableEffect_:
    call MoveHitTest
    mov al, [ebp + wMoveMissed]
    and al, al
    jnz .moveMissed

    mov edx, wEnemyDisabledMove          ; de = wEnemyDisabledMove
    mov esi, wEnemyMonMoves              ; hl = wEnemyMonMoves
    mov al, [ebp + hWhoseTurn]
    and al, al
    jz .disableEffect
    mov edx, wPlayerDisabledMove
    mov esi, wBattleMonMoves
.disableEffect:
    ; no effect if target already has a move disabled
    mov al, [ebp + edx]
    and al, al
    jnz .moveMissed

.pickMoveToDisable:
    push esi
    call BattleRandom
    and al, 0x3
    mov bl, al                           ; c = random move slot (0-3)
    xor bh, bh                           ; b = 0
    add esi, ebx
    mov al, [ebp + esi]                  ; a = move id at that slot
    pop esi                              ; restore hl = move-list base
    and al, al
    jz .pickMoveToDisable                ; loop until a non-00 move slot is found
    mov [ebp + wNamedObjectIndex], al    ; store move number

    push esi                             ; save hl (the target's move-list base)
    mov al, [ebp + hWhoseTurn]
    and al, al
    mov esi, wBattleMonPP                ; default PP base (target = player)
    jnz .enemyTurn                       ; enemy's turn → target = player, always check PP

    ; player's turn, target = enemy
    mov al, [ebp + wLinkState]
    cmp al, LINK_STATE_BATTLING
    pop esi                              ; esi = wEnemyMonMoves (move-list base)
    ; BUG{class=data-model; pret=engine/battle/effects.asm:DisableEffect; behavior=player Disable can select an enemy move slot already at zero PP outside link battles; evidence=pret player-turn non-link branch and source comment; lifetime=permanent Gen-1 behavior at compatibility level below 2}
    ; In a non-Link Battle, pret skips the PP check entirely when the
    ; player targets the enemy with Disable ("non-link battle enemies have unlimited
    ; PP so the previous checks aren't needed" — pret's own comment). This means the
    ; randomly-picked move slot can already be at 0 PP; the disable still "locks" it,
    ; which is harmless (that move couldn't be selected anyway) but is asymmetric with
    ; the enemy-turn / Link-Battle path, which always validates PP first. Gen-1 quirk,
    ; no bugs_and_glitches.md entry — preserved verbatim below.
    ; pret ref: engine/battle/effects.asm:DisableEffect (.playerTurnNotLinkBattle).
%if BUG_FIX_LEVEL >= 2
    ; fix: always validate PP, same as the enemy-turn / Link-Battle path (drop the
    ; non-link shortcut — fall straight into the PP-check block below).
%else
    jnz .playerTurnNotLinkBattle
%endif
    ; player's turn, Link Battle (or BUG_FIX_LEVEL>=2: always)
    push esi
    mov esi, wEnemyMonPP
.enemyTurn:
    push esi                             ; save PP-array base
    mov al, [ebp + esi]                  ; ld a,[hli] — pp[0]
    inc esi
    or al, [ebp + esi]                   ; pp[1]
    inc esi
    or al, [ebp + esi]                   ; pp[2]
    inc esi
    or al, [ebp + esi]                   ; pp[3]
    and al, PP_MASK
    pop esi                              ; restore PP-array base
    jz .moveMissedPopHL                  ; nothing to do if all moves have no PP left
    add esi, ebx                         ; esi = PP base + chosen slot
    mov al, [ebp + esi]
    pop esi                              ; restore hl = move-list base
    and al, al
    jz .pickMoveToDisable                ; pick another move if this one had 0 PP

.playerTurnNotLinkBattle:
    ; non-link battle enemies have unlimited PP so the previous checks aren't needed
    call BattleRandom
    and al, 0x7
    inc al                                ; a = 1-8 turns disabled
    inc bl                                ; c = move 1-4 will be disabled
    rol bl, 4                             ; swap c
    add al, bl                            ; map disabled move to high nibble of de's target
    mov [ebp + edx], al
    call PlayCurrentMoveAnimation2
    mov esi, wPlayerDisabledMoveNumber
    mov al, [ebp + hWhoseTurn]
    and al, al
    jnz .printDisableText
    inc esi                               ; wEnemyDisabledMoveNumber
.printDisableText:
    mov al, [ebp + wNamedObjectIndex]     ; move number
    mov [ebp + esi], al
    call GetMoveName
    mov esi, MoveWasDisabledText
    jmp PrintText
.moveMissedPopHL:
    pop esi
.moveMissed:
    jmp PrintButItFailedText_
