; dos_port/src/engine/battle/effects.asm
; Mirror of pret engine/battle/effects.asm.
;
; Holds, in pret source order:
;   JumpMoveEffect / _JumpMoveEffect                 (the dispatch seam)
;   StatModifierUpEffect .. MoveMissed, PrintStatText
;   ConfusionSideEffect .. ConfusionEffectFailed
;   ClearHyperBeam
;   ConditionalPrintButItFailed .. CheckTargetSubstitute
; plus MoveEffectPointerTable (pret data/moves/effects_pointers.asm) at the tail.
;
; The remaining pret effects.asm handlers reached through jpfar live in
; move_effects/*.asm under their pret `XxxEffect_` names, mirroring pret's own
; engine/battle/move_effects/ split.
;
; DATA-vs-CODE NOTE: MoveEffectPointerTable is hand-authored code (Tier 2), NOT a
; generated .inc. The pointer table is keyed by effect byte (from move_effect_constants.asm)
; and points directly to ported handler globals or the shared UnportedMoveEffect stub.
; pret uses dw (16-bit, ROM bank-relative); here dd (32-bit flat, DPMI linear).
;
; DISPATCHER ROLE: Wave 2 (battle loop) calls JumpMoveEffect. The move-effect
; translation swarm is COMPLETE (2026-06-30, docs/plans/move_swarm.md): every
; non-NULL effect is faithfully translated (per docs/plans/move_translation_divergence.md)
; and wired in the table below. Only the 7 NULL-in-pret effects stay UnportedMoveEffect.
; Do not touch UnportedMoveEffect itself.
;
; UNPORTED — the 7 NULL-in-pret effects (no body in pret; handled inline in the
; core.asm main flow, not via JumpMoveEffect), so they stay UnportedMoveEffect:
;   $09 MIRROR_MOVE, $11 SWIFT, $28 SUPER_FANG, $29 SPECIAL_DAMAGE (Seismic Toss
;   etc.), $2D JUMP_KICK, $4E (unused const_skip), $53 METRONOME.
;
; Register map: A=AL, B=BH, C=BL (BC=BX), D=DH, E=DL (DE=EDX), HL=ESI, EBP=GB base.
; GB memory at [EBP+addr]; flat program-image data (text streams, StatModTextStrings)
; read via [label]/[esi]. Multiply/Divide use the HRAM contract
; (hMultiplicand/hMultiplier/hDivisor/hProduct, with hProduct+2 == hMultiplicand+1
; etc. — the same overlap the GB relies on).

bits 32

%include "gb_macros.inc"
%include "gb_memmap.inc"
%include "gb_constants.inc"

; ---------------------------------------------------------------------------
; Externs — jpfar handler globals from move_effects/*.asm (pret XxxEffect_ names)
; ---------------------------------------------------------------------------
; SCAFFOLD WIRING (move-effect swarm — COMPLETE): JumpMoveEffect is LIVE (this file
; links; the core_stubs.asm JumpMoveEffect stub is gone). All 34 non-NULL handlers
; are translated, audited, and externed below; the 7 NULL-in-pret effects route to
; UnportedMoveEffect (a no-op) so a battle can't crash on a moveless effect byte.
extern PoisonEffect_            ; src/engine/battle/move_effects/poison.asm
extern SplashEffect_           ; src/engine/battle/move_effects/splash.asm
extern FlinchSideEffect_       ; src/engine/battle/move_effects/flinch_side.asm
extern SleepEffect_            ; src/engine/battle/move_effects/sleep.asm
extern FreezeBurnParalyzeEffect_ ; src/engine/battle/move_effects/freeze_burn_paralyze.asm
extern RageEffect_             ; move_effects/rage.asm
extern ExplodeEffect_          ; move_effects/explode.asm
extern BideEffect_             ; move_effects/bide.asm
extern TwoToFiveAttacksEffect_ ; move_effects/two_to_five_attacks.asm
extern HyperBeamEffect_         ; move_effects/hyper_beam.asm
extern ThrashPetalDanceEffect_ ; move_effects/thrash_petal_dance.asm
extern DisableEffect_          ; move_effects/disable.asm
extern TrappingEffect_         ; move_effects/trapping.asm
extern ChargeEffect_           ; move_effects/charge.asm
extern MimicEffect_            ; move_effects/mimic.asm
extern SwitchAndTeleportEffect_ ; move_effects/switch_and_teleport.asm
extern DrainHPEffect_          ; move_effects/drain_hp.asm
extern ReflectLightScreenEffect_ ; move_effects/reflect_light_screen.asm
extern RecoilEffect_           ; move_effects/recoil.asm
extern PayDayEffect_           ; move_effects/pay_day.asm
extern SubstituteEffect_       ; move_effects/substitute.asm
extern HealEffect_             ; move_effects/heal.asm
extern TransformEffect_        ; move_effects/transform.asm
extern ConversionEffect_       ; move_effects/conversion.asm
extern FocusEnergyEffect_      ; move_effects/focus_energy.asm
extern HazeEffect_             ; move_effects/haze.asm
extern LeechSeedEffect_        ; move_effects/leech_seed.asm
extern MistEffect_             ; move_effects/mist.asm
extern OneHitKOEffect_         ; move_effects/one_hit_ko.asm
extern ParalyzeEffect_         ; move_effects/paralyze.asm

; --- backend externs (linkable) ---
extern Multiply
extern Divide
extern StatModifierRatios
extern ApplyBadgeStatBoosts
extern QuarterSpeedDueToParalysis
extern HalveAttackDueToBurn
extern MoveHitTest                      ; core_damage.asm — accuracy test → wMoveMissed
extern BattleRandom                     ; home/random.asm
extern DelayFrames                      ; frame.asm — BL = frame count
extern PrintText                        ; src/home/window.asm — pret's PrintText
extern MonsStatsRose                    ; core.asm — composes "<mon>'s STAT [greatly] rose!"
extern MonsStatsFell                    ; core.asm — composes "<mon>'s STAT [greatly] fell!"

; --- battle_text.inc streams (global in core.o; flat addresses) ---
extern NothingHappenedText
extern BecameConfusedText
extern ButItFailedText
extern DidntAffectText
extern ParalyzedMayNotAttackText

; --- data (pret data/battle/stat_mod_names.asm, generated asset) ---
extern StatModTextStrings               ; move_effect_helpers.asm

; --- literal move-subanimation / substitute: ret-stubs in core_stubs.asm ---
extern PlayCurrentMoveAnimation      ; core_stubs.asm (STUB)
extern PlayCurrentMoveAnimation2     ; core_stubs.asm (STUB)
extern HideSubstituteShowMonAnim     ; core_stubs.asm (STUB)
extern ReshowSubstituteAnim          ; core_stubs.asm (STUB)

; --- flat-model bank passthrough (no banks under DPMI) ---
extern Bankswitch                    ; move_effect_helpers.asm

section .text

; ---------------------------------------------------------------------------
; UnportedMoveEffect
; Shared no-op stub for every effect not yet translated to x86. Returns
; without altering any state. Wave 2 replaces table entries as handlers land.
; ---------------------------------------------------------------------------
global UnportedMoveEffect
UnportedMoveEffect:
    ret

; ---------------------------------------------------------------------------
; JumpMoveEffect
; pret ref: engine/battle/effects.asm:JumpMoveEffect
;
; Calls the handler for the current move's effect byte, then returns with B=1.
; Called by the battle core turn loop (Wave 2). Effect byte 0 (NO_ADDITIONAL_EFFECT)
; must never be passed here — the caller (battle core) skips this call for effect 0.
;
; Exits: BH = 1 (B = 1 in SM83 → faithful to pret "ld b, $1" after the jpfar)
; ---------------------------------------------------------------------------
global JumpMoveEffect
JumpMoveEffect:
    ; call _JumpMoveEffect — inner handler is tail-called from there;
    ; when the handler rets it lands here on mov bh, 1
    call _JumpMoveEffect
    ; ld b, $1  (B = BH in the register map)
    mov bh, 1
    ret

; ---------------------------------------------------------------------------
; _JumpMoveEffect
; pret ref: engine/battle/effects.asm:_JumpMoveEffect
;
; Reads the active side's effect byte, indexes MoveEffectPointerTable, and
; tail-calls (jp hl → jmp [ptr]) the handler so its ret returns to JumpMoveEffect.
; ---------------------------------------------------------------------------
_JumpMoveEffect:
    ; ldh a, [hWhoseTurn]  — 0 = player's turn, non-zero = enemy's turn
    movzx eax, byte [ebp + hWhoseTurn]
    ; and a  (sets Z if player's turn)
    test al, al
    ; ld a, [wPlayerMoveEffect]  (assume player; overwrite if enemy)
    mov al, byte [ebp + wPlayerMoveEffect]
    jz .next
    ; ld a, [wEnemyMoveEffect]
    mov al, byte [ebp + wEnemyMoveEffect]
.next:
    ; dec a  — subtract 1: effect $01 → index 0, effect $56 → index 85
    ; pret comment: "there is no special effect for 00"
    dec al
    ; movzx: zero-extend into EAX for safe 32-bit index arithmetic
    ; (pret used "add a" → ×2 for 16-bit dw; we use ×4 for 32-bit dd)
    movzx eax, al
    ; ld hl, MoveEffectPointerTable + bc  (indexed address of the dd entry)
    lea esi, [MoveEffectPointerTable + eax*4]
    ; jp hl  — tail-call: handler's ret returns to JumpMoveEffect's "mov bh, 1"
    jmp dword [esi]

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
    ; BUG{class=data-model; pret=engine/battle/core.asm:StatModifierUpEffect; behavior=each stat-stage change reapplies badge boosts to already-boosted current stats; evidence=pret call to ApplyBadgeStatBoosts plus docs/references/yellow_glitches.md Badge Stat Boost Glitch; lifetime=permanent Gen-1 behavior}
    ; "Badge Stat Boost Glitch" — ApplyBadgeStatBoosts is
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

; ===========================================================================
; PrintStatText — pret engine/battle/effects.asm:PrintStatText.
; In: BH (B) = 1-based stat index. Copies the matching '@'-terminated stat name
; from StatModTextStrings into wStringBuffer (STAT_NAME_LENGTH bytes), for the
; "<MON>'s <STAT> rose/fell!" message. Clobbers AL, BH, ECX, ESI, EDI.
; ===========================================================================
global PrintStatText
PrintStatText:
    mov esi, StatModTextStrings
.outer:
    dec bh                              ; pret: dec b; jr z, .foundStatName
    jz .found
.inner:
    mov al, [esi]                       ; ld a, [hli] (flat)
    inc esi
    cmp al, 0x50                        ; '@'
    jne .inner
    jmp .outer
.found:
    mov edi, wStringBuffer              ; ld de, wStringBuffer
    mov ecx, STAT_NAME_LENGTH           ; ld bc, STAT_NAME_LENGTH
.copy:
    mov al, [esi]                       ; flat source (StatModTextStrings)
    inc esi
    mov [ebp + edi], al                 ; GB WRAM dest
    inc edi
    dec ecx
    jnz .copy
    ret

; ===========================================================================
; ConfusionSideEffect — pret effects.asm:ConfusionSideEffect. The damaging move Confusion's
; 10% side effect: roll, and on success fall through into the shared success path.
; Silent on a failed roll (ret nc).
; ===========================================================================
ConfusionSideEffect:
    call BattleRandom
    cmp al, 10 * 0xFF / 100             ; cp 10 percent — chance of confusion
    jae .ret                            ; ret nc — roll failed, stay silent
    jmp ConfusionSideEffectSuccess      ; jr ConfusionSideEffectSuccess
.ret:
    ret

; ===========================================================================
; ConfusionEffect — pret effects.asm:ConfusionEffect. Confuse Ray / Supersonic: substitute +
; accuracy test, then the shared success path. Fails (silently, after the checks)
; on substitute / miss; "But it failed!" if the target is already confused.
; ===========================================================================
ConfusionEffect:
    call CheckTargetSubstitute
    jnz ConfusionEffectFailed           ; jr nz, ConfusionEffectFailed
    call MoveHitTest                    ; → wMoveMissed
    mov al, [ebp + wMoveMissed]
    and al, al
    jnz ConfusionEffectFailed           ; jr nz, ConfusionEffectFailed

; --- ConfusionSideEffectSuccess (shared; ConfusionEffect falls straight in, and
; ConfusionSideEffect jumps here on a successful roll). Plain file-local labels
; (not dot-locals) so both entry points can reference them. ---
ConfusionSideEffectSuccess:
    mov al, [ebp + hWhoseTurn]
    and al, al                          ; ZF preserved across the movs below
    mov esi, wEnemyBattleStatus1        ; ld hl, wEnemyBattleStatus1
    mov ebx, wEnemyConfusedCounter      ; ld bc, wEnemyConfusedCounter
    mov al, [ebp + wPlayerMoveEffect]   ; ld a, [wPlayerMoveEffect]
    jz .confuseTarget
    mov esi, wPlayerBattleStatus1       ; ld hl, wPlayerBattleStatus1
    mov ebx, wPlayerConfusedCounter     ; ld bc, wPlayerConfusedCounter
    mov al, [ebp + wEnemyMoveEffect]    ; ld a, [wEnemyMoveEffect]
.confuseTarget:
    test byte [ebp + esi], 1 << CONFUSED   ; bit CONFUSED, [hl] — is mon confused?
    jnz ConfusionEffectFailed              ; jr nz, ConfusionEffectFailed (AL = move effect)
    or byte [ebp + esi], 1 << CONFUSED     ; set CONFUSED, [hl] — mon is now confused
    push eax                               ; push af — preserve the move-effect byte
    call BattleRandom                      ; clobbers AL only (ESI/EBX preserved)
    and al, 3
    inc al
    inc al
    mov [ebp + ebx], al                    ; ld [bc], a — confusion lasts 2-5 turns
    pop eax                                ; pop af
    cmp al, CONFUSION_SIDE_EFFECT
    jz .skipAnim                           ; call nz, PlayCurrentMoveAnimation2
    call PlayCurrentMoveAnimation2         ;   (the damaging move already played its own
.skipAnim:                                 ;    subanim, so skip it for the side effect)
    mov esi, BecameConfusedText            ; ld hl, BecameConfusedText
    jmp PrintText                          ; jp PrintText

; --- ConfusionEffectFailed (shared fall-through). Literal translation: AL holds
; whatever the predecessor left — the move-effect byte on the already-confused
; entry (so $4C → silent for the side effect), or a non-$4C value on the
; substitute/miss early-fail entries (→ loud "But it failed!"). ---
ConfusionEffectFailed:
    cmp al, CONFUSION_SIDE_EFFECT
    jz .ret                             ; ret z — side-effect path stays silent
    mov bl, 50                          ; ld c, 50
    call DelayFrames
    jmp ConditionalPrintButItFailed
.ret:
    ret

; ===========================================================================
; ClearHyperBeam — pret engine/battle/effects.asm:ClearHyperBeam. Clears the
; NEEDS_TO_RECHARGE bit on the TARGET side's wXxxBattleStatus2 (enemy on the
; player's turn, player on the enemy's turn — the literal pret hl selection).
; Shared by FreezeBurnParalyzeEffect, FlinchSideEffect, TrappingEffect. Preserves
; ESI; clobbers AL (pret clobbers AF; callers don't rely on AL surviving).
; ===========================================================================
global ClearHyperBeam
ClearHyperBeam:
    push esi
    mov esi, wEnemyBattleStatus2        ; player's turn → target = enemy
    mov al, [ebp + hWhoseTurn]
    and al, al
    jz .playerTurn
    mov esi, wPlayerBattleStatus2
.playerTurn:
    and byte [ebp + esi], ~(1 << NEEDS_TO_RECHARGE) & 0xFF   ; res NEEDS_TO_RECHARGE
    pop esi
    ret

; ===========================================================================
; ConditionalPrintButItFailed / PrintButItFailedText_ — pret effects.asm.
; ConditionalPrintButItFailed: if the side effect failed yet the attack landed
; (wMoveDidntMiss != 0) return silently; otherwise print "But it failed!".
; ===========================================================================
global ConditionalPrintButItFailed
ConditionalPrintButItFailed:
    mov al, [ebp + wMoveDidntMiss]
    and al, al
    jz PrintButItFailedText_            ; side effect failed → "But it failed!"
    ret                                ; ret nz — attack succeeded, stay quiet
global PrintButItFailedText_
PrintButItFailedText_:
    mov esi, ButItFailedText
    jmp PrintText

; ===========================================================================
; PrintDidntAffectText / PrintMayNotAttackText — pret effects.asm.
; ===========================================================================
global PrintDidntAffectText
PrintDidntAffectText:
    mov esi, DidntAffectText
    jmp PrintText

global PrintMayNotAttackText
PrintMayNotAttackText:
    mov esi, ParalyzedMayNotAttackText
    jmp PrintText
; ===========================================================================
; CheckTargetSubstitute — pret effects.asm. ZF=1 if the target has NO substitute
; up (move can affect it), ZF=0 if a substitute is up. Preserves ESI/EDX; clobbers AL.
; ===========================================================================
global CheckTargetSubstitute
CheckTargetSubstitute:
    push esi
    mov esi, wEnemyBattleStatus2        ; target = enemy on the player's turn
    mov al, [ebp + hWhoseTurn]
    and al, al
    jz .next
    mov esi, wPlayerBattleStatus2
.next:
    test byte [ebp + esi], 1 << HAS_SUBSTITUTE_UP   ; ZF=1 → no substitute
    pop esi
    ret

; ---------------------------------------------------------------------------
; MoveEffectPointerTable
; pret ref: data/moves/effects_pointers.asm:MoveEffectPointerTable
;
; 86 entries, one per effect constant $01–$56 (indexed as effect_byte - 1).
; pret table uses dw (16-bit ROM-bank pointers); here dd (32-bit flat).
; Entries with NULL in pret, and all unported handlers, use UnportedMoveEffect.
; ---------------------------------------------------------------------------
global MoveEffectPointerTable
MoveEffectPointerTable:
    dd SleepEffect_             ; $01 EFFECT_01            — Sleep (Sing/Hypnosis etc.)
    dd PoisonEffect_            ; $02 [S4 reference handler]
    dd DrainHPEffect_        ; $03 DRAIN_HP_EFFECT
    dd FreezeBurnParalyzeEffect_ ; $04 BURN_SIDE_EFFECT1    — Burn 10%
    dd FreezeBurnParalyzeEffect_ ; $05 FREEZE_SIDE_EFFECT1  — Freeze 10%
    dd FreezeBurnParalyzeEffect_ ; $06 PARALYZE_SIDE_EFFECT1 — Paralyze 10%
    dd ExplodeEffect_        ; $07 EXPLODE_EFFECT
    dd DrainHPEffect_        ; $08 DREAM_EATER_EFFECT
    dd UnportedMoveEffect       ; $09 MIRROR_MOVE_EFFECT   — NULL in pret
    dd StatModifierUpEffect     ; $0A ATTACK_UP1_EFFECT
    dd StatModifierUpEffect     ; $0B DEFENSE_UP1_EFFECT
    dd StatModifierUpEffect     ; $0C SPEED_UP1_EFFECT
    dd StatModifierUpEffect     ; $0D SPECIAL_UP1_EFFECT
    dd StatModifierUpEffect     ; $0E ACCURACY_UP1_EFFECT
    dd StatModifierUpEffect     ; $0F EVASION_UP1_EFFECT
    dd PayDayEffect_         ; $10 PAY_DAY_EFFECT
    dd UnportedMoveEffect       ; $11 SWIFT_EFFECT         — NULL in pret
    dd StatModifierDownEffect   ; $12 ATTACK_DOWN1_EFFECT
    dd StatModifierDownEffect   ; $13 DEFENSE_DOWN1_EFFECT
    dd StatModifierDownEffect   ; $14 SPEED_DOWN1_EFFECT
    dd StatModifierDownEffect   ; $15 SPECIAL_DOWN1_EFFECT
    dd StatModifierDownEffect   ; $16 ACCURACY_DOWN1_EFFECT
    dd StatModifierDownEffect   ; $17 EVASION_DOWN1_EFFECT
    dd ConversionEffect_     ; $18 CONVERSION_EFFECT
    dd HazeEffect_           ; $19 HAZE_EFFECT
    dd BideEffect_           ; $1A BIDE_EFFECT
    dd ThrashPetalDanceEffect_; $1B THRASH_PETAL_DANCE_EFFECT
    dd SwitchAndTeleportEffect_; $1C SWITCH_AND_TELEPORT_EFFECT
    dd TwoToFiveAttacksEffect_; $1D TWO_TO_FIVE_ATTACKS_EFFECT
    dd TwoToFiveAttacksEffect_; $1E EFFECT_1E (unused)
    dd FlinchSideEffect_        ; $1F FLINCH_SIDE_EFFECT1  — Flinch 10%
    dd SleepEffect_             ; $20 SLEEP_EFFECT         — Sleep
    dd PoisonEffect_            ; $21 [S4 reference handler]
    dd FreezeBurnParalyzeEffect_ ; $22 BURN_SIDE_EFFECT2    — Burn 30%
    dd FreezeBurnParalyzeEffect_ ; $23 FREEZE_SIDE_EFFECT2  — Freeze 30%
    dd FreezeBurnParalyzeEffect_ ; $24 PARALYZE_SIDE_EFFECT2 — Paralyze 30%
    dd FlinchSideEffect_        ; $25 FLINCH_SIDE_EFFECT2  — Flinch 30%
    dd OneHitKOEffect_       ; $26 OHKO_EFFECT
    dd ChargeEffect_         ; $27 CHARGE_EFFECT
    dd UnportedMoveEffect       ; $28 SUPER_FANG_EFFECT    — NULL in pret
    dd UnportedMoveEffect       ; $29 SPECIAL_DAMAGE_EFFECT — NULL in pret (Seismic Toss etc.)
    dd TrappingEffect_       ; $2A TRAPPING_EFFECT
    dd ChargeEffect_         ; $2B FLY_EFFECT
    dd TwoToFiveAttacksEffect_; $2C ATTACK_TWICE_EFFECT
    dd UnportedMoveEffect       ; $2D JUMP_KICK_EFFECT     — NULL in pret
    dd MistEffect_           ; $2E MIST_EFFECT
    dd FocusEnergyEffect_    ; $2F FOCUS_ENERGY_EFFECT
    dd RecoilEffect_           ; $30 RECOIL_EFFECT
    dd ConfusionEffect         ; $31 CONFUSION_EFFECT     — Confuse Ray / Supersonic
    dd StatModifierUpEffect     ; $32 ATTACK_UP2_EFFECT
    dd StatModifierUpEffect     ; $33 DEFENSE_UP2_EFFECT
    dd StatModifierUpEffect     ; $34 SPEED_UP2_EFFECT
    dd StatModifierUpEffect     ; $35 SPECIAL_UP2_EFFECT
    dd StatModifierUpEffect     ; $36 ACCURACY_UP2_EFFECT
    dd StatModifierUpEffect     ; $37 EVASION_UP2_EFFECT
    dd HealEffect_             ; $38 HEAL_EFFECT          — Recover/Softboiled/Rest
    dd TransformEffect_         ; $39 TRANSFORM_EFFECT
    dd StatModifierDownEffect   ; $3A ATTACK_DOWN2_EFFECT
    dd StatModifierDownEffect   ; $3B DEFENSE_DOWN2_EFFECT
    dd StatModifierDownEffect   ; $3C SPEED_DOWN2_EFFECT
    dd StatModifierDownEffect   ; $3D SPECIAL_DOWN2_EFFECT
    dd StatModifierDownEffect   ; $3E ACCURACY_DOWN2_EFFECT
    dd StatModifierDownEffect   ; $3F EVASION_DOWN2_EFFECT
    dd ReflectLightScreenEffect_ ; $40 LIGHT_SCREEN_EFFECT
    dd ReflectLightScreenEffect_ ; $41 REFLECT_EFFECT
    dd PoisonEffect_            ; $42 [S4 reference handler]
    dd ParalyzeEffect_       ; $43 PARALYZE_EFFECT
    dd StatModifierDownEffect   ; $44 ATTACK_DOWN_SIDE_EFFECT
    dd StatModifierDownEffect   ; $45 DEFENSE_DOWN_SIDE_EFFECT
    dd StatModifierDownEffect   ; $46 SPEED_DOWN_SIDE_EFFECT
    dd StatModifierDownEffect   ; $47 SPECIAL_DOWN_SIDE_EFFECT
    dd StatModifierDownEffect   ; $48 (unused, const_skip) — pret: StatModifierDownEffect
    dd StatModifierDownEffect   ; $49 (unused, const_skip) — pret: StatModifierDownEffect
    dd StatModifierDownEffect   ; $4A (unused, const_skip) — pret: StatModifierDownEffect
    dd StatModifierDownEffect   ; $4B (unused, const_skip) — pret: StatModifierDownEffect
    dd ConfusionSideEffect     ; $4C CONFUSION_SIDE_EFFECT — Confusion's 10% side effect
    dd TwoToFiveAttacksEffect_; $4D TWINEEDLE_EFFECT
    dd UnportedMoveEffect       ; $4E (unused, const_skip) — NULL in pret
    dd SubstituteEffect_     ; $4F SUBSTITUTE_EFFECT
    dd HyperBeamEffect_      ; $50 HYPER_BEAM_EFFECT
    dd RageEffect_           ; $51 RAGE_EFFECT
    dd MimicEffect_          ; $52 MIMIC_EFFECT
    dd UnportedMoveEffect       ; $53 METRONOME_EFFECT     — NULL in pret
    dd LeechSeedEffect_      ; $54 LEECH_SEED_EFFECT
    dd SplashEffect_            ; $55 SPLASH_EFFECT        — Splash ("But nothing happened!")
    dd DisableEffect_        ; $56 DISABLE_EFFECT
MoveEffectPointerTableEnd:

; Arity assertion: NUM_MOVE_EFFECTS = $56 = 86 entries ($01..$56, indexed by effect-1).
; NASM evaluates this label-difference at assembly time (both labels in same section).
%define _MEPT_ENTRIES ((MoveEffectPointerTableEnd - MoveEffectPointerTable) / 4)
%if _MEPT_ENTRIES != 86
%fatal "MoveEffectPointerTable arity error: expected 86 entries ($01..$56), got " %+ _MEPT_ENTRIES
%endif
