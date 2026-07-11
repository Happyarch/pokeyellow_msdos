; stat_mod_effects.asm — StatModifierUpEffect / StatModifierDownEffect
; (battle engine plan, Stage 5).
;
; Faithful translation of engine/battle/effects.asm:StatModifierUpEffect and
; StatModifierDownEffect (plus their flow-control helpers). These are the stat-
; stage move-effect handlers: they bump the relevant stat-mod by ±1/±2 (clamped to
; the 1..13 stage range), then recompute the affected battle stat from the
; unmodified stat via StatModifierRatios (Multiply/Divide), capping at 999 / flooring
; at 1. ApplyBadgeStatBoosts is reapplied and the paralysis/burn penalties refreshed.
;
; Like the move_effects/* files, the *presentation* tail is the deferred battle
; front end: animation, substitute/minimize, the "rose"/"fell"/"nothing happened"
; text, and the per-stat name copy (PrintStatText) are deferred externs, so this
; file assembles (make check) but does not yet link into the EXE. The stat-stage
; arithmetic — the Stage 5 backend — is native-validated with those externs stubbed.
;
; Register map: a=AL, b=BH, c=BL (bc=BX), d=DH, e=DL (de=DX), hl=ESI.
; Multiply/Divide use the HRAM contract (hMultiplicand/hMultiplier/hDivisor/hProduct,
; with hProduct+2 == hMultiplicand+1 etc. — the same overlap the GB relies on).
;
; Build: nasm -f coff -I include/ -I . -o stat_mod_effects.o stat_mod_effects.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

; --- backend externs (linkable) ---
extern Multiply
extern Divide
extern StatModifierRatios
extern ApplyBadgeStatBoosts
extern QuarterSpeedDueToParalysis
extern HalveAttackDueToBurn
extern MoveHitTest
extern BattleRandom

; --- deferred front-end externs (UI: animation / substitute / text) ---
extern PrintText
extern PrintStatText
extern PlayCurrentMoveAnimation
extern PlayCurrentMoveAnimation2
extern Bankswitch
extern HideSubstituteShowMonAnim
extern ReshowSubstituteAnim
extern ConditionalPrintButItFailed
extern CheckTargetSubstitute
extern MonsStatsRose                    ; core.asm — composes "<mon>'s STAT [greatly] rose!"
extern MonsStatsFell                    ; core.asm — composes "<mon>'s STAT [greatly] fell!"
extern NothingHappenedText

section .text

global StatModifierUpEffect
global StatModifierDownEffect

; ===========================================================================
; StatModifierUpEffect
; ===========================================================================
StatModifierUpEffect:
    mov esi, wPlayerMonStatMods
    mov edx, wPlayerMoveEffect
    mov al, [ebp + hWhoseTurn]
    test al, al
    jz .statModifierUpEffect
    mov esi, wEnemyMonStatMods
    mov edx, wEnemyMoveEffect
.statModifierUpEffect:
    mov al, [ebp + edx]                  ; a = move effect
    sub al, ATTACK_UP1_EFFECT
    cmp al, EVASION_UP1_EFFECT + 3 - ATTACK_UP1_EFFECT   ; covers all +1 effects (=8)
    jb .incrementStatMod
    sub al, ATTACK_UP2_EFFECT - ATTACK_UP1_EFFECT       ; map +2 effects → +1 index
.incrementStatMod:
    mov bl, al                           ; c = stat index (0..5)
    mov bh, 0
    movzx ecx, bx
    add esi, ecx                         ; hl = &statMod[index]
    mov bh, [ebp + esi]
    inc bh                               ; increment the stat mod
    mov al, 0x0D
    cmp al, bh
    jb PrintNothingHappenedText          ; jp c — can't raise past +6 (13 < b)
    mov al, [ebp + edx]
    cmp al, ATTACK_UP1_EFFECT + 8         ; is it a +2 effect? ( >= $12 )
    jb .ok
    inc bh                               ; +2: bump mod again
    mov al, 0x0D
    cmp al, bh
    jae .ok                              ; jr nc — unless already +6
    mov bh, al                           ; cap at 13
.ok:
    mov [ebp + esi], bh
    mov al, bl
    cmp al, 4
    jae UpdateStatDone                   ; evasion/accuracy: no stat recalc
    push esi
    mov esi, wBattleMonAttack + 1        ; hl = &stat low byte (big-endian +1)
    mov edx, wPlayerMonUnmodifiedAttack
    mov al, [ebp + hWhoseTurn]
    test al, al
    jz .pointToStats
    mov esi, wEnemyMonAttack + 1
    mov edx, wEnemyMonUnmodifiedAttack
.pointToStats:
    push ebx
    shl bl, 1                            ; c = index*2 (stat stride)
    mov bh, 0
    movzx ecx, bx
    add esi, ecx                         ; hl = &modifiedStat (low byte)
    mov al, bl
    add dl, al
    jnc .checkIf999
    inc dh                               ; de = &unmodifiedStat
.checkIf999:
    pop ebx
    ; check if stat is already 999
    mov al, [ebp + esi]                  ; low byte; hl→high (ld a,[hld])
    dec esi
    sub al, MAX_STAT_VALUE & 0xFF
    jnz .recalculateStat
    mov al, [ebp + esi]                  ; high byte
    sbb al, MAX_STAT_VALUE >> 8
    jz RestoreOriginalStatModifier       ; already 999 → undo the bump
.recalculateStat:
    push esi
    push ebx
    mov esi, StatModifierRatios          ; flat table
    dec bh                               ; b = stat mod value
    shl bh, 1
    mov bl, bh
    mov bh, 0
    movzx ecx, bx
    add esi, ecx                         ; hl = &ratio[mod]
    pop ebx
    xor al, al
    mov [ebp + hMultiplicand], al
    mov al, [ebp + edx]                  ; unmodified stat high
    mov [ebp + hMultiplicand + 1], al
    inc edx
    mov al, [ebp + edx]                  ; unmodified stat low
    mov [ebp + hMultiplicand + 2], al
    mov al, [esi]                        ; ratio numerator (ld a,[hli], flat)
    inc esi
    mov [ebp + hMultiplier], al
    call Multiply
    mov al, [esi]                        ; ratio denominator (flat)
    mov [ebp + hDivisor], al
    mov bh, 4
    call Divide
    pop esi
    ; cap at MAX_STAT_VALUE (999)
    mov al, [ebp + hProduct + 3]
    sub al, MAX_STAT_VALUE & 0xFF
    mov al, [ebp + hProduct + 2]
    sbb al, MAX_STAT_VALUE >> 8
    jc UpdateStat                        ; product < 999 → use it
    mov al, MAX_STAT_VALUE >> 8
    mov [ebp + hMultiplicand + 1], al    ; (= hProduct+2) cap to 999
    mov al, MAX_STAT_VALUE & 0xFF
    mov [ebp + hMultiplicand + 2], al    ; (= hProduct+3)

UpdateStat:
    mov al, [ebp + hProduct + 2]
    mov [ebp + esi], al                  ; ld [hli], a
    inc esi
    mov al, [ebp + hProduct + 3]
    mov [ebp + esi], al                  ; ld [hl], a
    pop esi
UpdateStatDone:
    mov bh, bl
    inc bh
    call PrintStatText
    mov esi, wPlayerBattleStatus2
    mov edx, wPlayerMoveNum
    mov ebx, wPlayerMonMinimized
    mov al, [ebp + hWhoseTurn]
    test al, al
    jz .playerTurn
    mov esi, wEnemyBattleStatus2
    mov edx, wEnemyMoveNum
    mov ebx, wEnemyMonMinimized
.playerTurn:
    mov al, [ebp + edx]
    cmp al, MINIMIZE
    jne .notMinimize
    ; substitute up? slide it off before the minimize animation
    test byte [ebp + esi], (1 << HAS_SUBSTITUTE_UP)
    pushfd
    push ebx
    push edx
    mov esi, HideSubstituteShowMonAnim
    mov bh, 0                            ; BANK(...) — no banks in the port
    jz .skipHideBank
    call Bankswitch
.skipHideBank:
    pop edx
.notMinimize:
    call PlayCurrentMoveAnimation
    mov al, [ebp + edx]
    cmp al, MINIMIZE
    jne .applyBadgeBoostsAndStatusPenalties
    pop ebx
    mov al, 1
    mov [ebp + ebx], al
    mov esi, ReshowSubstituteAnim
    mov bh, 0
    popfd
    jz .skipReshowBank
    call Bankswitch
.skipReshowBank:
.applyBadgeBoostsAndStatusPenalties:
    ; BUG(critical): "Badge Stat Boost Glitch" — ApplyBadgeStatBoosts is
    ; reapplied on EVERY stat-stage change (not just once on stat load), and it
    ; boosts the already-boosted current value again rather than the base
    ; stat, so repeated stat-up moves compound the 1.125x badge boost each
    ; time, stacking toward MAX_STAT_VALUE (999). Gen-1 behavior, preserved
    ; verbatim. pret ref: engine/battle/core.asm:StatModifierUpEffect (call
    ; ApplyBadgeStatBoosts), docs/references/yellow_glitches.md#battle-system
    ; (Badge Stat Boost Glitch)
    mov al, [ebp + hWhoseTurn]
    test al, al
    jnz .skipBadge
    call ApplyBadgeStatBoosts            ; call z (player turn) — reapply badge boosts
.skipBadge:
    call MonsStatsRose                   ; "<mon>'s STAT [greatly] rose!" (intro+suffix+PROMPT)
    call QuarterSpeedDueToParalysis
    jmp HalveAttackDueToBurn

RestoreOriginalStatModifier:
    pop esi                              ; undo the push esi from .pointToStats path
    dec byte [ebp + esi]                 ; dec [hl] — revert the mod bump

PrintNothingHappenedText:
    mov esi, NothingHappenedText
    jmp PrintText

; ===========================================================================
; StatModifierDownEffect
; ===========================================================================
StatModifierDownEffect:
    mov esi, wEnemyMonStatMods
    mov edx, wPlayerMoveEffect
    mov ebx, wEnemyBattleStatus1
    mov al, [ebp + hWhoseTurn]
    test al, al
    jz .statModifierDownEffect
    mov esi, wPlayerMonStatMods
    mov edx, wEnemyMoveEffect
    mov ebx, wPlayerBattleStatus1
    mov al, [ebp + wLinkState]
    cmp al, LINK_STATE_BATTLING
    je .statModifierDownEffect
    call BattleRandom
    cmp al, 64                           ; 25 percent + 1 — chance to miss in regular battle
    jb MoveMissed
.statModifierDownEffect:
    call CheckTargetSubstitute           ; can't hit through substitute
    jnz MoveMissed
    mov al, [ebp + edx]
    cmp al, ATTACK_DOWN_SIDE_EFFECT
    jb .nonSideEffect
    call BattleRandom
    cmp al, 85                           ; 33 percent + 1 — side-effect chance
    jae CantLowerAnymore
    mov al, [ebp + edx]
    sub al, ATTACK_DOWN_SIDE_EFFECT      ; map side effect → 0..3
    jmp .decrementStatMod
.nonSideEffect:
    push esi
    push edx
    push ebx
    call MoveHitTest                     ; accuracy test → wMoveMissed
    pop ebx
    pop edx
    pop esi
    mov al, [ebp + wMoveMissed]
    test al, al
    jnz MoveMissed
    mov al, [ebp + ebx]
    test al, (1 << INVULNERABLE)         ; fly/dig
    jnz MoveMissed
    mov al, [ebp + edx]
    sub al, ATTACK_DOWN1_EFFECT
    cmp al, EVASION_DOWN1_EFFECT + 3 - ATTACK_DOWN1_EFFECT  ; all -1 effects (=8)
    jb .decrementStatMod
    sub al, ATTACK_DOWN2_EFFECT - ATTACK_DOWN1_EFFECT       ; map -2 → -1 index
.decrementStatMod:
    mov bl, al
    mov bh, 0
    movzx ecx, bx
    add esi, ecx
    mov bh, [ebp + esi]
    dec bh
    jz CantLowerAnymore                  ; mod 1 (-6) → can't lower
    mov al, [ebp + edx]
    cmp al, ATTACK_DOWN2_EFFECT - 0x16   ; $24
    jb .ok
    cmp al, ATTACK_DOWN_SIDE_EFFECT      ; side effects: stat down is always 1
    jae .ok
    dec bh                               ; down-2 effects: dec mod again
    jnz .ok
    inc bh                               ; clamp to 1 (-6) if it hit 0 (-7)
.ok:
    mov [ebp + esi], bh
    mov al, bl
    cmp al, 4
    jae UpdateLoweredStatDone            ; evasion/accuracy: no stat recalc
    push esi
    push edx
    mov esi, wEnemyMonAttack + 1
    mov edx, wEnemyMonUnmodifiedAttack
    mov al, [ebp + hWhoseTurn]
    test al, al
    jz .pointToStat
    mov esi, wBattleMonAttack + 1
    mov edx, wPlayerMonUnmodifiedAttack
.pointToStat:
    push ebx
    shl bl, 1
    mov bh, 0
    movzx ecx, bx
    add esi, ecx
    mov al, bl
    add dl, al
    jnc .noCarry
    inc dh
.noCarry:
    pop ebx
    mov al, [ebp + esi]                  ; ld a,[hld]
    dec esi
    sub al, 1                            ; can't lower stat below 1 (-6)
    jnz .recalculateStat
    mov al, [ebp + esi]
    test al, al
    jz CantLowerAnymore_Pop
.recalculateStat:
    push esi
    push ebx
    mov esi, StatModifierRatios
    dec bh
    shl bh, 1
    mov bl, bh
    mov bh, 0
    movzx ecx, bx
    add esi, ecx
    pop ebx
    xor al, al
    mov [ebp + hMultiplicand], al
    mov al, [ebp + edx]
    mov [ebp + hMultiplicand + 1], al
    inc edx
    mov al, [ebp + edx]
    mov [ebp + hMultiplicand + 2], al
    mov al, [esi]                        ; numerator (flat)
    inc esi
    mov [ebp + hMultiplier], al
    call Multiply
    mov al, [esi]                        ; denominator (flat)
    mov [ebp + hDivisor], al
    mov bh, 4
    call Divide
    pop esi
    mov al, [ebp + hProduct + 3]
    mov bh, al
    mov al, [ebp + hProduct + 2]
    or al, bh
    jnz UpdateLoweredStat
    mov [ebp + hMultiplicand + 1], al    ; a = 0 → (= hProduct+2)
    mov al, 1
    mov [ebp + hMultiplicand + 2], al    ; floor stat at 1
UpdateLoweredStat:
    mov al, [ebp + hProduct + 2]
    mov [ebp + esi], al
    inc esi
    mov al, [ebp + hProduct + 3]
    mov [ebp + esi], al
    pop edx
    pop esi
UpdateLoweredStatDone:
    mov bh, bl
    inc bh
    push edx
    call PrintStatText
    pop edx
    mov al, [ebp + edx]
    cmp al, ATTACK_DOWN_SIDE_EFFECT      ; side effects: animation already played
    jae .applyBadgeBoostsAndStatusPenalties
    call PlayCurrentMoveAnimation2
.applyBadgeBoostsAndStatusPenalties:
    mov al, [ebp + hWhoseTurn]
    test al, al
    jz .skipBadge
    call ApplyBadgeStatBoosts            ; call nz (enemy used stat-down on player)
.skipBadge:
    call MonsStatsFell                   ; "<mon>'s STAT [greatly] fell!" (intro+suffix+PROMPT)
    call QuarterSpeedDueToParalysis
    jmp HalveAttackDueToBurn

CantLowerAnymore_Pop:
    pop edx
    pop esi
    inc byte [ebp + esi]                 ; inc [hl]
CantLowerAnymore:
    mov al, [ebp + edx]
    cmp al, ATTACK_DOWN_SIDE_EFFECT
    jae .ret                             ; ret nc — side effects stay quiet
    mov esi, NothingHappenedText
    jmp PrintText
.ret:
    ret

MoveMissed:
    mov al, [ebp + edx]
    cmp al, ATTACK_DOWN_SIDE_EFFECT
    jae .ret                             ; ret nc
    jmp ConditionalPrintButItFailed
.ret:
    ret
