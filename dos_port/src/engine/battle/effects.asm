; dos_port/src/engine/battle/effects.asm
; Mirror of pret engine/battle/effects.asm.
;
; Holds every pret effects.asm label whose body pret defines INLINE here, in pret
; source order: the JumpMoveEffect / _JumpMoveEffect dispatch seam, then
; SleepEffect, PoisonEffect, ExplodeEffect, FreezeBurnParalyzeEffect, CheckDefrost,
; the StatModifier{Up,Down}Effect family, BideEffect, ThrashPetalDanceEffect,
; SwitchAndTeleportEffect, TwoToFiveAttacksEffect, FlinchSideEffect, ChargeEffect,
; TrappingEffect, the Confusion family, HyperBeamEffect, ClearHyperBeam, RageEffect,
; MimicEffect, SplashEffect, DisableEffect, and the PrintNoEffectText ..
; CheckTargetSubstitute text/substitute tail — plus MoveEffectPointerTable
; (pret data/moves/effects_pointers.asm) at the very end.
;
; The OTHER pret effects.asm handlers are three-line `jpfar XxxEffect_` trampolines
; whose real bodies pret keeps in engine/battle/move_effects/*.asm; those 14 files
; are mirrored 1:1 under src/engine/battle/move_effects/ and keep their genuine pret
; `XxxEffect_` names. MoveEffectPointerTable reaches them directly — in the flat DPMI
; model there is no bank to switch, so the trampoline would be a pure no-op hop.
;
; Do NOT re-split an inline body back out to a move_effects/ file: a trailing
; underscore is a pret label ONLY when pret itself has that move_effects file.
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
%include "gb_text.inc"                 ; text_far / text_asm stream macros

; ---------------------------------------------------------------------------
; Externs — jpfar handler globals from move_effects/*.asm (pret XxxEffect_ names)
; ---------------------------------------------------------------------------
; SCAFFOLD WIRING (move-effect swarm — COMPLETE): JumpMoveEffect is LIVE (this file
; links; the core_stubs.asm JumpMoveEffect stub is gone). All 34 non-NULL handlers
; are translated, audited, and externed below; the 7 NULL-in-pret effects route to
; UnportedMoveEffect (a no-op) so a battle can't crash on a moveless effect byte.
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
extern ApplyBadgeStatBoosts           ; engine/battle/core.asm
extern QuarterSpeedDueToParalysis     ; engine/battle/core.asm
extern HalveAttackDueToBurn           ; engine/battle/core.asm
extern MoveHitTest                    ; engine/battle/core.asm — accuracy test → wMoveMissed
extern BattleRandom                   ; engine/battle/core.asm — battle PRNG, result in AL
extern DelayFrames                      ; src/home/delay.asm — BL = frame count
extern PrintText                        ; src/home/window.asm — pret's PrintText
extern MonsStatsRose                    ; core.asm — composes "<mon>'s STAT [greatly] rose!"
extern MonsStatsFell                    ; core.asm — composes "<mon>'s STAT [greatly] fell!"

; --- battle_text.inc streams (global in core.o; flat addresses) ---
extern NothingHappenedText
extern _ChargeMoveEffectText            ; assets/battle_text.inc — pret text_5.asm "<USER>"
extern MadeWhirlwindText                ; assets/battle_text.inc (ChargeMoveEffectText hook)
extern TookInSunlightText
extern LoweredItsHeadText
extern SkyAttackGlowingText
extern FlewUpHighText
extern DugAHoleText
extern BecameConfusedText
extern ButItFailedText
extern DidntAffectText
extern ParalyzedMayNotAttackText

; --- data (pret data/battle/stat_mod_names.asm, generated asset) ---
extern StatModTextStrings               ; src/data/battle_data.asm

; --- literal move-subanimation / substitute: ret-stubs in core_stubs.asm ---
extern PlayCurrentMoveAnimation      ; core_stubs.asm (STUB)
extern PlayCurrentMoveAnimation2     ; core_stubs.asm (STUB)
extern HideSubstituteShowMonAnim     ; core_stubs.asm (STUB)
extern ReshowSubstituteAnim          ; core_stubs.asm (STUB)

; --- flat-model bank passthrough (no banks under DPMI) ---
extern Bankswitch                    ; src/home/bankswitch2.asm
extern PlayBattleAnimation2
extern PlayBattleAnimation          ; core_stubs.asm (STUB)
extern GetMoveName                  ; home/names.asm — name of move [wNamedObjectIndex]
extern MoveWasDisabledText
extern AddNTimes                    ; home/array.asm — ESI += EBX(stride) * AL(count)
extern BurnedText
extern FrozenText
extern FireDefrostedText
extern MimicLearnedMoveText
extern MoveSelectionMenu            ; engine/battle/core.asm — see TODO(master) below
extern LoadScreenTilesFromBuffer1   ; src/home/tilemap.asm
extern PoisonedText
extern BadlyPoisonedText
extern FellAsleepText
extern AlreadyAsleepText
extern NoEffectText
extern ReadPlayerMonCurHPAndStatus  ; engine/battle/core.asm — already live + linked
extern IsUnaffectedText
extern RanFromBattleText
extern RanAwayScaredText
extern WasBlownAwayText

section .text

; ---------------------------------------------------------------------------
; UnportedMoveEffect
; Shared no-op stub for every effect not yet translated to x86. Returns
; without altering any state. Wave 2 replaces table entries as handlers land.
; ---------------------------------------------------------------------------
global UnportedMoveEffect
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
; ===========================================================================
; SleepEffect — inflict SLEEP (1-7 turn counter) on the target.
; ===========================================================================
global SleepEffect
SleepEffect:
    mov edx, wEnemyMonStatus            ; de = target status (player's turn → enemy)
    mov ebx, wEnemyBattleStatus2        ; bc = target battle status 2 (recharge flag lives here)
    mov al, [ebp + hWhoseTurn]
    and al, al
    jz .sleepEffect
    mov edx, wBattleMonStatus
    mov ebx, wPlayerBattleStatus2
.sleepEffect:
    mov al, [ebp + ebx]                 ; ld a,[bc]
    mov cl, al
    and cl, 1 << NEEDS_TO_RECHARGE      ; bit NEEDS_TO_RECHARGE,a — does the target need to recharge?
    and al, ~(1 << NEEDS_TO_RECHARGE) & 0xFF   ; res NEEDS_TO_RECHARGE,a — target no longer needs to recharge
    mov [ebp + ebx], al                 ; ld [bc],a (write back unconditionally)
    ; BUG{class=data-model; pret=engine/battle/effects.asm:SleepEffect; behavior=a target owing Hyper Beam recharge is put to sleep without status or accuracy checks; evidence=pret recharge short-circuit and source comment; lifetime=permanent Gen-1 behavior at compatibility level below 2}
    ; Hyper Beam recharge bypasses ALL hit-tests for status moves —
    ; a target that needed to recharge this turn is unconditionally put to sleep,
    ; skipping the already-asleep/already-statused check AND the accuracy test
    ; (MoveHitTest). pret's own comment flags this ("if the target had to recharge,
    ; all hit tests will be skipped including the event where the target already
    ; has another status"). Preserved verbatim below; the fix re-runs the normal
    ; checks instead of short-circuiting straight to the counter roll.
    ; pret ref: engine/battle/effects.asm:SleepEffect.
%if BUG_FIX_LEVEL >= 2
    ; fixed: fall through into the normal already-asleep/-statused + accuracy path
    ; even when the target needed to recharge (no early jump to .setSleepCounter).
%else
    test cl, cl
    jnz .setSleepCounter                 ; jr nz, .setSleepCounter (original bug)
%endif
    mov al, [ebp + edx]                  ; ld a,[de] — status byte
    mov bh, al                           ; ld b,a (stash full status byte)
    and al, SLP_MASK
    jz .notAlreadySleeping               ; jr z — not already asleep
    mov esi, AlreadyAsleepText           ; ld hl, AlreadyAsleepText
    jmp PrintText                        ; jp PrintText
.notAlreadySleeping:
    mov al, bh
    and al, al
    jnz .didntAffect                     ; jr nz — already has another status
    push edx                             ; push de
    call MoveHitTest                     ; apply accuracy tests (clobbers esi/edx/ebx/eax)
    pop edx                              ; pop de
    mov al, [ebp + wMoveMissed]
    and al, al
    jnz .didntAffect                     ; jr nz
.setSleepCounter:
; set target's sleep counter to a random number between 1 and 7
    call BattleRandom
    and al, SLP_MASK
    jz .setSleepCounter                  ; jr z — reroll on 0
    mov bh, al                           ; ld b,a
    mov al, [ebp + wUnknownSerialFlag_d499]
    and al, al
    jz .continueSetCounter               ; jr z — XXX stadium stuff? (always taken
                                          ; on real DMG/CGB hardware and in this port;
                                          ; only set during a GB Stadium link session)
    mov al, bh
    and al, 0x3
    jz .setSleepCounter                  ; jr z
    mov bh, al
.continueSetCounter:
    mov al, bh                           ; ld a,b
    mov [ebp + edx], al                  ; ld [de],a
    call PlayCurrentMoveAnimation2       ; literal subanim — ANIMATION=OFF stub (§2.1)
    mov esi, FellAsleepText              ; ld hl, FellAsleepText
    jmp PrintText                        ; jp PrintText
.didntAffect:
    jmp PrintDidntAffectText             ; jp PrintDidntAffectText
; ===========================================================================
; PoisonEffect — inflict POISON (or, for Toxic, BADLY_POISONED) on the target.
; Handles POISON_SIDE_EFFECT1/2 (20% / 40% chance, no accuracy test) and the
; main POISON_EFFECT (accuracy-tested). Misses if the target has a substitute,
; is already statused, or is a Poison-type.
; ===========================================================================
global PoisonEffect
PoisonEffect:
    mov esi, wEnemyMonStatus            ; hl = target status (player's turn → enemy)
    mov edx, wPlayerMoveEffect          ; de = move effect
    mov al, [ebp + hWhoseTurn]
    and al, al
    jz .poisonEffect
    mov esi, wBattleMonStatus
    mov edx, wEnemyMoveEffect
.poisonEffect:
    call CheckTargetSubstitute
    jnz .noEffect                       ; substitute up → can't poison a doll
    mov al, [ebp + esi]                 ; ld a,[hli] — status byte
    inc esi
    mov bh, al                          ; ld b, a (unused after, faithful)
    and al, al
    jnz .noEffect                       ; already statused → miss
    mov al, [ebp + esi]                 ; ld a,[hli] — type 1
    inc esi
    cmp al, POISON
    je .noEffect                        ; can't poison a Poison-type
    mov al, [ebp + esi]                 ; ld a,[hld] — type 2
    dec esi
    cmp al, POISON
    je .noEffect
    mov al, [ebp + edx]                 ; ld a,[de] — move effect
    cmp al, POISON_SIDE_EFFECT1
    mov bh, (20 * 0xFF / 100) + 1       ; 20 percent + 1 chance of poisoning
    je .sideEffectTest
    cmp al, POISON_SIDE_EFFECT2
    mov bh, (40 * 0xFF / 100) + 1       ; 40 percent + 1
    je .sideEffectTest
    ; main POISON_EFFECT (PoisonPowder etc.): apply the accuracy test.
    push esi
    push edx
    ; BUG{class=data-model; pret=engine/battle/core.asm:MoveHitTest; behavior=the poison handler inherits the 1-in-256 miss for nominally perfect accuracy; evidence=pret MoveHitTest plus docs/references/yellow_glitches.md 1 in 256 Miss Glitch; lifetime=permanent Gen-1 behavior}
    ; Gen-1 1/256 miss — MoveHitTest can roll a miss on a 100%-accuracy
    ; move (the inherited <256/256 hit-chance bug). Preserved here; the fix, if any,
    ; lives in MoveHitTest under BUG_FIX_LEVEL, not in this handler.
    ; pret ref: engine/battle/core.asm:MoveHitTest, bugs_and_glitches (1/256 miss).
    call MoveHitTest                    ; → wMoveMissed
    pop edx
    pop esi
    mov al, [ebp + wMoveMissed]
    and al, al
    jnz .didntAffect
    jmp .inflictPoison
.sideEffectTest:
    call BattleRandom
    cmp al, bh                          ; was the side effect successful?
    jae .ret                            ; ret nc — failed, stay silent
.inflictPoison:
    dec esi                             ; dec hl → back to the status byte
    or byte [ebp + esi], 1 << PSN       ; set PSN
    push edx                            ; push de (move-effect ptr)
    dec edx                             ; dec de → move NUM ptr (effect-1)
    mov al, [ebp + hWhoseTurn]
    and al, al                          ; ZF preserved across the movs below
    mov bh, SHAKE_SCREEN_ANIM           ; ld b, SHAKE_SCREEN_ANIM
    mov esi, wPlayerBattleStatus3       ; ld hl, wPlayerBattleStatus3
    mov cl, [ebp + edx]                 ; ld a,[de] — move num (stash; de is reused next)
    mov edx, wPlayerToxicCounter        ; ld de, wPlayerToxicCounter
    jnz .ok
    mov bh, ENEMY_HUD_SHAKE_ANIM
    mov esi, wEnemyBattleStatus3
    mov edx, wEnemyToxicCounter
.ok:
    mov al, cl                          ; a = move num
    cmp al, TOXIC
    jne .normalPoison                   ; not Toxic → regular poison
    or byte [ebp + esi], 1 << BADLY_POISONED   ; set Toxic battstatus
    xor al, al
    mov [ebp + edx], al                 ; clear the toxic counter
    mov esi, BadlyPoisonedText
    jmp .continue
.normalPoison:
    mov esi, PoisonedText
.continue:
    pop edx                             ; pop de (move-effect ptr)
    mov al, [ebp + edx]                 ; ld a,[de] — move effect
    cmp al, POISON_EFFECT
    je .regularPoisonEffect
    mov al, bh                          ; a = anim id (subanim is the ANIMATION=OFF stub)
    call PlayBattleAnimation2
    jmp PrintText                       ; ESI = the poison text stream
.regularPoisonEffect:
    call PlayCurrentMoveAnimation2
    jmp PrintText
.noEffect:
    mov al, [ebp + edx]
    cmp al, POISON_EFFECT
    jne .ret                            ; ret nz — side effects stay quiet on no-effect
.didntAffect:
    mov bl, 50                          ; ld c, 50
    call DelayFrames
    jmp PrintDidntAffectText
.ret:
    ret
; ===========================================================================
; ExplodeEffect — pret engine/battle/effects.asm:ExplodeEffect. Sets the
; ATTACKING (using) mon's own HP to 0, status to 0, and clears its SEEDED bit.
; No accuracy test, no substitute check, no text — this is the bare backend
; effect; the faint/HP-bar/message handling happens in the battle core's
; general post-move-effect flow (EXPLODE_EFFECT is special-cased there to
; always apply even on a miss).
; ===========================================================================
global ExplodeEffect
ExplodeEffect:
    mov esi, wBattleMonHP               ; hl = wBattleMonHP (player's own mon)
    mov edx, wPlayerBattleStatus2       ; de = wPlayerBattleStatus2
    mov al, [ebp + hWhoseTurn]
    and al, al
    jz .faintUser                       ; player's turn → the player's own mon explodes
    mov esi, wEnemyMonHP                ; enemy's turn → the enemy's own mon explodes
    mov edx, wEnemyBattleStatus2
.faintUser:
    xor al, al
    mov [ebp + esi], al                 ; ld [hli], a — HP high byte = 0
    inc esi
    mov [ebp + esi], al                 ; ld [hli], a — HP low byte = 0
    inc esi
    inc esi                             ; inc hl — skip wBattleMonBoxLevel/PartyPos byte
    mov [ebp + esi], al                 ; ld [hl], a — wBattleMonStatus = 0
    mov al, [ebp + edx]                 ; ld a, [de]
    and al, ~(1 << SEEDED) & 0xFF       ; res SEEDED, a — clear Leech Seed status
    mov [ebp + edx], al                 ; ld [de], a
    ret
; ===========================================================================
; FreezeBurnParalyzeEffect — chance-on-hit BURN/FREEZE/PARALYZE side effect.
; No accuracy test here (unlike the dedicated status moves) — purely a percent
; roll via BattleRandom once the type-immunity guard passes. Misses silently if
; the target has a substitute, is already statused (tail-jumps to CheckDefrost
; instead, which may thaw a frozen target against a Fire-type move), or shares
; a type with the move (e.g. an Electric move can't paralyze an Electric-type).
; ===========================================================================
global FreezeBurnParalyzeEffect
FreezeBurnParalyzeEffect:
    mov byte [ebp + wAnimationType], 0  ; xor a / ld [wAnimationType],a
    call CheckTargetSubstitute
    jnz .ret                            ; ret nz — substitute up, can't effect them
    mov al, [ebp + hWhoseTurn]
    and al, al
    jnz .opponentAttacker

; --- player is attacking; target = enemy mon ---
    mov al, [ebp + wEnemyMonStatus]
    and al, al
    jnz CheckDefrost                   ; jp nz, CheckDefrost — already statused
    mov al, [ebp + wPlayerMoveType]
    mov bh, al                          ; ld b, a
    mov al, [ebp + wEnemyMonType1]
    cmp al, bh                          ; do target type 1 and move type match?
    je .ret                             ; ret z — e.g. an Ice move can't freeze an Ice-type
    mov al, [ebp + wEnemyMonType2]
    cmp al, bh
    je .ret
    mov al, [ebp + wPlayerMoveEffect]
    cmp al, FREEZE_SIDE_EFFECT2         ; more Stadium stuff
    jne .altThreshold1
    mov al, [ebp + wUnknownSerialFlag_d499]
    test al, al
    mov al, FREEZE_SIDE_EFFECT1         ; mov doesn't touch flags — ZF from the test above survives
    mov bh, (30 * 0xFF / 100) + 1
    jz .regularEffectiveness1
    mov bh, (10 * 0xFF / 100) + 1
    jmp .regularEffectiveness1
.altThreshold1:
    cmp al, PARALYZE_SIDE_EFFECT1 + 1
    mov bh, (10 * 0xFF / 100) + 1       ; mov doesn't touch flags — CF from the cmp above survives
    jc .regularEffectiveness1
; extra effectiveness
    mov bh, (30 * 0xFF / 100) + 1
    ; pret ASSERTs (compile-time, gb_constants.inc): PARALYZE_SIDE_EFFECT2 -
    ; PARALYZE_SIDE_EFFECT1 == BURN_SIDE_EFFECT2 - BURN_SIDE_EFFECT1 == FREEZE_SIDE_EFFECT2
    ; - FREEZE_SIDE_EFFECT1 (all == 30, 0x1E) — verified against gb_constants.inc above.
    sub al, PARALYZE_SIDE_EFFECT2 - PARALYZE_SIDE_EFFECT1   ; treat extra-effective as regular from now on
.regularEffectiveness1:
    ; "push af / call BattleRandom / cp b / pop bc / ret nc / ld a,b" — BL (C) is
    ; dead in this routine, so it stands in as the AF-pair's stash slot instead of
    ; a literal stack push/pop; behaviorally identical (flags from `cmp` below
    ; survive the following `mov`, exactly as pret's flags survive `pop bc`).
    mov bl, al                          ; stash the effect-type value (push af)
    call BattleRandom                   ; al = random 8-bit value
    cmp al, bh                          ; was the roll under the threshold?
    mov al, bl                          ; ld a,b (restore effect-type value)
    jae .ret                            ; ret nc — random >= threshold, no status applied
    cmp al, BURN_SIDE_EFFECT1
    je .burn1
    cmp al, FREEZE_SIDE_EFFECT1
    je .freeze1
; paralyze1 (fallthrough — only PARALYZE_SIDE_EFFECT1 remains by elimination)
    mov byte [ebp + wEnemyMonStatus], 1 << PAR
    call QuarterSpeedDueToParalysis     ; quarter speed of affected mon
    mov al, ENEMY_HUD_SHAKE_ANIM
    call PlayBattleAnimation
    jmp PrintMayNotAttackText
.burn1:
    mov byte [ebp + wEnemyMonStatus], 1 << BRN
    call HalveAttackDueToBurn           ; halve attack of affected mon
    mov al, ENEMY_HUD_SHAKE_ANIM
    call PlayBattleAnimation
    mov esi, BurnedText
    jmp PrintText
.freeze1:
    call ClearHyperBeam                 ; resets hyper beam (recharge) condition from target
    mov byte [ebp + wEnemyMonStatus], 1 << FRZ
    mov al, ENEMY_HUD_SHAKE_ANIM
    call PlayBattleAnimation
    mov esi, FrozenText
    jmp PrintText

; --- opponent is attacking; target = player's mon ---
; mostly the same as above with addresses swapped for the opponent.
.opponentAttacker:
    mov al, [ebp + wBattleMonStatus]
    and al, al
    jnz CheckDefrost
    mov al, [ebp + wEnemyMoveType]
    mov bh, al
    mov al, [ebp + wBattleMonType1]
    cmp al, bh
    je .ret
    mov al, [ebp + wBattleMonType2]
    cmp al, bh
    je .ret
    mov al, [ebp + wEnemyMoveEffect]
    cmp al, FREEZE_SIDE_EFFECT2
    jne .altThreshold2
    mov al, [ebp + wUnknownSerialFlag_d499]
    test al, al
    mov al, FREEZE_SIDE_EFFECT1
    mov bh, (30 * 0xFF / 100) + 1
    jz .regularEffectiveness2
    mov bh, (10 * 0xFF / 100) + 1
    jmp .regularEffectiveness2
.altThreshold2:
    cmp al, PARALYZE_SIDE_EFFECT1 + 1
    mov bh, (10 * 0xFF / 100) + 1
    jc .regularEffectiveness2
; extra effectiveness
    mov bh, (30 * 0xFF / 100) + 1
    sub al, BURN_SIDE_EFFECT2 - BURN_SIDE_EFFECT1   ; same numeric stride (30); pret literally
                                                     ; uses the BURN pair here, ASSERTed equal above
.regularEffectiveness2:
    mov bl, al                          ; stash (see .regularEffectiveness1 note)
    call BattleRandom
    cmp al, bh
    mov al, bl
    jae .ret
    cmp al, BURN_SIDE_EFFECT1
    je .burn2
    cmp al, FREEZE_SIDE_EFFECT1
    je .freeze2
; paralyze2 (fallthrough)
    mov byte [ebp + wBattleMonStatus], 1 << PAR
    call QuarterSpeedDueToParalysis
    mov al, SHAKE_SCREEN_ANIM
    call PlayBattleAnimation2
    jmp PrintMayNotAttackText
.burn2:
    mov byte [ebp + wBattleMonStatus], 1 << BRN
    call HalveAttackDueToBurn
    mov al, SHAKE_SCREEN_ANIM
    call PlayBattleAnimation2
    mov esi, BurnedText
    jmp PrintText
.freeze2:
    ; BUG{class=data-model; pret=engine/battle/effects.asm:FreezeBurnParalyzeEffect; behavior=freezing the player side does not clear Hyper Beam recharge while freezing the enemy side does; evidence=pret .freeze1 and .freeze2 asymmetry plus source comment; lifetime=permanent Gen-1 behavior at compatibility level below 2}
    ; Hyper Beam recharge is reset for the player's side (.freeze1
    ; above calls ClearHyperBeam) but NOT here — pret's own source comment flags
    ; the asymmetry verbatim ("hyper beam bits aren't reset for opponent's side").
    ; A player mon that needed to recharge from Hyper Beam and then gets frozen by
    ; an opponent's move keeps the stale NEEDS_TO_RECHARGE flag; the symmetric
    ; case (opponent mon frozen by the player) correctly clears it.
    ; pret ref: engine/battle/effects.asm:FreezeBurnParalyzeEffect (.freeze2).
%if BUG_FIX_LEVEL >= 2
    call ClearHyperBeam                 ; fixed: symmetric reset on both sides
%else
    ; original (buggy): no ClearHyperBeam call on this path
%endif
    mov byte [ebp + wBattleMonStatus], 1 << FRZ
    mov al, SHAKE_SCREEN_ANIM
    call PlayBattleAnimation2
    mov esi, FrozenText
    jmp PrintText
.ret:
    ret

; ---------------------------------------------------------------------------
; CheckDefrost — pret engine/battle/effects.asm:CheckDefrost. Entry: AL = the target's
; current status byte (already loaded by the caller above). Any Fire-type move
; with a chance to inflict burn (i.e. every move that reaches this effect
; except Fire Spin, which has no burn chance) thaws a frozen target — even on
; the turn it's about to (re)inflict FRZ below, this label is only reached when
; the target ALREADY has a status, so a Fire move here only ever thaws, never
; re-freezes in the same call. Reached only from this effect (no other pret
; call site) — file-local (pret does not export it either).
; ---------------------------------------------------------------------------
CheckDefrost:
    test al, 1 << FRZ                   ; are they frozen?
    jz .ret                             ; ret z — some other status, nothing to thaw
    mov al, [ebp + hWhoseTurn]
    and al, al
    jnz .opponent
    ; player [attacker]
    mov al, [ebp + wPlayerMoveType]
    sub al, FIRE
    jnz .ret                            ; ret nz — move used isn't Fire-type, no thaw
    mov [ebp + wEnemyMonStatus], al     ; al == 0 here — "defrost" the frozen target
    mov esi, wEnemyMon1Status
    mov al, [ebp + wEnemyMonPartyPos]
    mov ebx, PARTYMON_STRUCT_LENGTH
    call AddNTimes
    mov byte [ebp + esi], 0             ; clear status in the roster copy too
    mov esi, FireDefrostedText
    jmp .common
.opponent:
    mov al, [ebp + wEnemyMoveType]      ; same as above with addresses swapped
    sub al, FIRE
    jnz .ret
    mov [ebp + wBattleMonStatus], al
    mov esi, wPartyMon1Status
    mov al, [ebp + wPlayerMonNumber]
    mov ebx, PARTYMON_STRUCT_LENGTH
    call AddNTimes
    mov byte [ebp + esi], 0
    mov esi, FireDefrostedText
.common:
    jmp PrintText
.ret:
    ret                                 ; pret reaches this via bare `ret z` / `ret nz`

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
; ===========================================================================
; BideEffect — pret BideEffect. Sets STORING_ENERGY on the user's side, clears
; the 2-byte accumulated-damage counter, clears wPlayerMoveEffect/wEnemyMoveEffect
; (both, unconditionally — literal pret behavior, not gated by hWhoseTurn; harmless
; here since EffectCallBattleCore's caller re-fetches/uses the move-effect byte
; before this handler runs, matching pret's own assumption), rolls a 2-3 turn
; Bide counter into the (overloaded) wXxxNumAttacksLeft byte, and plays the
; XSTATITEM_ANIM-family subanim (literal subanim → allowlist stub, §2 item 1).
;
; pret:
;   BideEffect:
;       ld hl, wPlayerBattleStatus1
;       ld de, wPlayerBideAccumulatedDamage
;       ld bc, wPlayerNumAttacksLeft
;       ldh a, [hWhoseTurn]
;       and a
;       jr z, .bideEffect
;       ld hl, wEnemyBattleStatus1
;       ld de, wEnemyBideAccumulatedDamage
;       ld bc, wEnemyNumAttacksLeft
;   .bideEffect
;       set STORING_ENERGY, [hl] ; mon is now using bide
;       xor a
;       ld [de], a
;       inc de
;       ld [de], a
;       ld [wPlayerMoveEffect], a
;       ld [wEnemyMoveEffect], a
;       call BattleRandom
;       and $1
;       inc a
;       inc a
;       ld [bc], a ; set Bide counter to 2 or 3 at random
;       ldh a, [hWhoseTurn]
;       add XSTATITEM_ANIM
;       jp PlayBattleAnimation2
; ===========================================================================
global BideEffect
BideEffect:
    mov esi, wPlayerBattleStatus1       ; ld hl, wPlayerBattleStatus1
    mov edx, wPlayerBideAccumulatedDamage ; ld de, wPlayerBideAccumulatedDamage
    mov ebx, wPlayerNumAttacksLeft      ; ld bc, wPlayerNumAttacksLeft
    mov al, [ebp + hWhoseTurn]          ; ldh a, [hWhoseTurn]
    and al, al
    jz .bideEffect                      ; jr z, .bideEffect
    mov esi, wEnemyBattleStatus1        ; ld hl, wEnemyBattleStatus1
    mov edx, wEnemyBideAccumulatedDamage ; ld de, wEnemyBideAccumulatedDamage
    mov ebx, wEnemyNumAttacksLeft       ; ld bc, wEnemyNumAttacksLeft
.bideEffect:
    or byte [ebp + esi], 1 << STORING_ENERGY  ; set STORING_ENERGY, [hl] — mon is now using bide
    xor al, al                          ; xor a
    mov [ebp + edx], al                 ; ld [de], a — low byte of accumulated damage
    inc edx                             ; inc de
    mov [ebp + edx], al                 ; ld [de], a — high byte of accumulated damage
    mov [ebp + wPlayerMoveEffect], al   ; ld [wPlayerMoveEffect], a
    mov [ebp + wEnemyMoveEffect], al    ; ld [wEnemyMoveEffect], a
    call BattleRandom
    and al, 1                           ; and $1
    inc al
    inc al                              ; a = 2 or 3
    mov [ebp + ebx], al                 ; ld [bc], a — set Bide counter to 2 or 3 at random
    mov al, [ebp + hWhoseTurn]          ; ldh a, [hWhoseTurn]
    add al, XSTATITEM_ANIM              ; add XSTATITEM_ANIM
    jmp PlayBattleAnimation2            ; jp PlayBattleAnimation2
; ===========================================================================
; ThrashPetalDanceEffect — pret engine/battle/effects.asm:ThrashPetalDanceEffect.
;   ld hl, wPlayerBattleStatus1
;   ld de, wPlayerNumAttacksLeft
;   ldh a, [hWhoseTurn]
;   and a
;   jr z, .thrashPetalDanceEffect
;   ld hl, wEnemyBattleStatus1
;   ld de, wEnemyNumAttacksLeft
; .thrashPetalDanceEffect
;   set THRASHING_ABOUT, [hl] ; mon is now using thrash/petal dance
;   call BattleRandom
;   and $1
;   inc a
;   inc a
;   ld [de], a ; set thrash/petal dance counter to 2 or 3 at random
;   ldh a, [hWhoseTurn]
;   add SHRINKING_SQUARE_ANIM
;   jp PlayBattleAnimation2
;
; In: hWhoseTurn (0 = player's turn, nonzero = enemy's turn) selects the ATTACKING
; side's wXxxBattleStatus1 / wXxxNumAttacksLeft pair — the literal pret hl/de
; selection (same side that is about to thrash/petal-dance).
; Out: THRASHING_ABOUT set on that side's battle-status-1 byte; that side's
; NumAttacksLeft set to a random 2 or 3 (BattleRandom & 1, + 2). Tail-jumps into
; PlayBattleAnimation2 with AL = SHRINKING_SQUARE_ANIM + hWhoseTurn (the per-side
; anim id pret selects via the literal `add`), matching pret's `jp` (this routine's
; caller is returned to by PlayBattleAnimation2's own ret, exactly as in pret).
; Clobbers: AL, ESI, EDX.
; ===========================================================================
global ThrashPetalDanceEffect
ThrashPetalDanceEffect:
    mov esi, wPlayerBattleStatus1       ; ld hl, wPlayerBattleStatus1
    mov edx, wPlayerNumAttacksLeft      ; ld de, wPlayerNumAttacksLeft
    mov al, [ebp + hWhoseTurn]          ; ldh a, [hWhoseTurn]
    and al, al
    jz .thrashPetalDanceEffect          ; jr z, .thrashPetalDanceEffect
    mov esi, wEnemyBattleStatus1        ; ld hl, wEnemyBattleStatus1
    mov edx, wEnemyNumAttacksLeft       ; ld de, wEnemyNumAttacksLeft
.thrashPetalDanceEffect:
    or byte [ebp + esi], 1 << THRASHING_ABOUT   ; set THRASHING_ABOUT, [hl]
    call BattleRandom                   ; call BattleRandom -> AL
    and al, 1                           ; and $1
    inc al                              ; inc a
    inc al                              ; inc a  -> al = 2 or 3
    mov [ebp + edx], al                 ; ld [de], a
    mov al, [ebp + hWhoseTurn]          ; ldh a, [hWhoseTurn]
    add al, SHRINKING_SQUARE_ANIM       ; add SHRINKING_SQUARE_ANIM
    jmp PlayBattleAnimation2            ; jp PlayBattleAnimation2 (tail call)
; ===========================================================================
; SwitchAndTeleportEffect — pret engine/battle/effects.asm:SwitchAndTeleportEffect.
; Teleport/Roar/Whirlwind. In a wild battle, rolls an escape chance from the
; user's and target's levels (auto-success if the escaping side's relevant level
; is >= the other's) via BattleRandom; on success sets wEscapedFromBattle and
; ends the battle with a flee/blow-away message. In a trainer battle the move
; always "doesn't affect" / "fails" (no trainer mon ever flees or switches via
; this effect) after the standard 50-frame delay.
; ===========================================================================
global SwitchAndTeleportEffect
SwitchAndTeleportEffect:
    mov al, [ebp + hWhoseTurn]
    and al, al
    jnz .handleEnemy

; --- player is attacking (player trying to flee/Roar) ---
    mov al, [ebp + wIsInBattle]
    dec al
    jnz .notWildBattle1                 ; wIsInBattle != 1 → trainer battle

    mov al, [ebp + wCurEnemyLevel]
    mov bh, al                          ; b = enemyLevel
    mov al, [ebp + wBattleMonLevel]
    cmp al, bh                          ; is the player's level >= the enemy's level?
    jae .playerMoveWasSuccessful        ; jr nc — if so, teleport always succeeds
    add al, bh                          ; a = playerLevel + enemyLevel (8-bit wrap, faithful)
    mov bl, al
    inc bl                              ; c = playerLevel + enemyLevel + 1
.rejectionSampleLoop1:
    call BattleRandom                   ; al = random byte in [0,255]
    cmp al, bl
    jae .rejectionSampleLoop1           ; jr nc — reroll until al < c
    shr bh, 1
    shr bh, 1                           ; b = enemyLevel / 4
    cmp al, bh                          ; is rand[0, playerLevel+enemyLevel] >= enemyLevel/4?
    jae .playerMoveWasSuccessful        ; jr nc — if so, allow teleporting
    mov bl, 50
    call DelayFrames
    mov al, [ebp + wPlayerMoveNum]
    cmp al, TELEPORT
    jnz PrintDidntAffectText            ; jp nz, PrintDidntAffectText
    jmp PrintButItFailedText_           ; jp PrintButItFailedText_
.playerMoveWasSuccessful:
    call ReadPlayerMonCurHPAndStatus
    xor al, al
    mov byte [ebp + wAnimationType], al
    inc al
    mov byte [ebp + wEscapedFromBattle], al
    mov al, [ebp + wPlayerMoveNum]
    jmp .playAnimAndPrintText
.notWildBattle1:
    mov bl, 50
    call DelayFrames
    mov esi, IsUnaffectedText
    mov al, [ebp + wPlayerMoveNum]
    cmp al, TELEPORT
    jnz PrintText                       ; jp nz, PrintText
    jmp PrintButItFailedText_           ; jp PrintButItFailedText_

; --- enemy is attacking (wild/trainer mon trying to flee/Roar the player away) ---
.handleEnemy:
    mov al, [ebp + wIsInBattle]
    dec al
    jnz .notWildBattle2

    mov al, [ebp + wBattleMonLevel]
    mov bh, al                          ; b = playerLevel
    mov al, [ebp + wCurEnemyLevel]
    cmp al, bh                          ; is the enemy's level >= the player's level?
    jae .enemyMoveWasSuccessful
    add al, bh                          ; a = enemyLevel + playerLevel (8-bit wrap, faithful)
    mov bl, al
    inc bl
.rejectionSampleLoop2:
    call BattleRandom
    cmp al, bl
    jae .rejectionSampleLoop2
    shr bh, 1
    shr bh, 1                           ; b = playerLevel / 4
    cmp al, bh
    jae .enemyMoveWasSuccessful
    mov bl, 50
    call DelayFrames
    mov al, [ebp + wEnemyMoveNum]
    cmp al, TELEPORT
    jnz PrintDidntAffectText
    jmp PrintButItFailedText_
.enemyMoveWasSuccessful:
    call ReadPlayerMonCurHPAndStatus
    xor al, al
    mov byte [ebp + wAnimationType], al
    inc al
    mov byte [ebp + wEscapedFromBattle], al
    mov al, [ebp + wEnemyMoveNum]
    jmp .playAnimAndPrintText
; NOTE (faithful, not a bug per docs/bugs_and_glitches.md — no entry there for
; this routine, so not BUG-tagged, but flagged for the auditor): pret's
; .notWildBattle2 ends in `jp ConditionalPrintButItFailed` while the player's
; mirror-image .notWildBattle1 above ends in an unconditional
; `jp PrintButItFailedText_`. This asymmetry is exactly what pret does — the
; enemy path additionally respects wMoveDidntMiss (stays silent if the
; attack itself missed) where the player path always prints "But it failed!".
; Preserved verbatim; this is the genuine pret control-flow split, not a
; transcription error.
.notWildBattle2:
    mov bl, 50
    call DelayFrames
    mov esi, IsUnaffectedText
    mov al, [ebp + wEnemyMoveNum]
    cmp al, TELEPORT
    jnz PrintText
    jmp ConditionalPrintButItFailed

; --- shared tail: the escaping side's move succeeded — animate + report ---
.playAnimAndPrintText:
    push eax                            ; push af (only AL is load-bearing past here)
    call PlayBattleAnimation            ; al = move num in/out; stub is a no-op (§2 item 1)
    mov bl, 20
    call DelayFrames
    pop eax
    mov esi, RanFromBattleText
    cmp al, TELEPORT
    je .printText
    mov esi, RanAwayScaredText
    cmp al, ROAR
    je .printText
    mov esi, WasBlownAwayText           ; WHIRLWIND (or any other move routed here)
.printText:
    jmp PrintText
; ===========================================================================
; TwoToFiveAttacksEffect — pick the multi-hit count for the current attacker's
; turn and stash it in wXxxNumAttacksLeft / wXxxNumHits. Guarded by
; ATTACKING_MULTIPLE_TIMES so it only runs once per multi-hit sequence (the
; per-hit dispatch loop that follows calls back into the same move's effect
; jump table on every hit; this routine must not re-roll mid-sequence).
;
; pret: HL = wXxxBattleStatus1 (re-entry-guard byte), DE = wXxxNumAttacksLeft,
; BC = wXxxNumHits, selected by hWhoseTurn. Translated: ESI/EDX/ECX respectively.
; ===========================================================================
global TwoToFiveAttacksEffect
TwoToFiveAttacksEffect:
    mov esi, wPlayerBattleStatus1       ; hl = wPlayerBattleStatus1
    mov edx, wPlayerNumAttacksLeft      ; de = wPlayerNumAttacksLeft
    mov ecx, wPlayerNumHits             ; bc = wPlayerNumHits
    mov al, [ebp + hWhoseTurn]
    and al, al
    jz .twoToFiveAttacksEffect
    mov esi, wEnemyBattleStatus1
    mov edx, wEnemyNumAttacksLeft
    mov ecx, wEnemyNumHits
.twoToFiveAttacksEffect:
    mov al, [ebp + esi]                 ; ld a,[hl] — battle status byte (no hl advance)
    bt ax, ATTACKING_MULTIPLE_TIMES     ; bit ATTACKING_MULTIPLE_TIMES, [hl]
    jc .ret                             ; ret nz — already mid multi-hit sequence
    or byte [ebp + esi], 1 << ATTACKING_MULTIPLE_TIMES   ; set ATTACKING_MULTIPLE_TIMES, [hl]

    mov esi, wPlayerMoveEffect          ; hl = wPlayerMoveEffect
    mov al, [ebp + hWhoseTurn]
    and al, al
    jz .setNumberOfHits
    mov esi, wEnemyMoveEffect
.setNumberOfHits:
    mov al, [ebp + esi]                 ; ld a,[hl] — this move's effect byte
    cmp al, TWINEEDLE_EFFECT
    je .twineedle
    cmp al, ATTACK_TWICE_EFFECT
    mov al, 2                           ; number of hits is always 2 for ATTACK_TWICE_EFFECT
    je .saveNumberOfHits
    ; TWO_TO_FIVE_ATTACKS_EFFECT (and the unused EFFECT_1E, which pret never special-
    ; cases — both fall through to this same generic roll): 3/8 chance for 2 and 3
    ; hits, 1/8 chance for 4 and 5 hits.
    call BattleRandom
    and al, 0x3
    cmp al, 0x2
    jc .gotNumHits
    ; if the number of hits was >= 2 (i.e. the 2-bit roll was 2 or 3), re-roll again
    ; for a lower chance of landing on the high end (4/5 hits)
    call BattleRandom
    and al, 0x3
.gotNumHits:
    inc al
    inc al
.saveNumberOfHits:
    mov [ebp + edx], al                 ; ld [de],a — wXxxNumAttacksLeft
    mov [ebp + ecx], al                 ; ld [bc],a — wXxxNumHits
    ret
.twineedle:
    ; NOTE (not a bug — faithful register-reuse quirk, pret ref:
    ; engine/battle/effects.asm:TwoToFiveAttacksEffect.twineedle): pret rewrites
    ; Twineedle's own move-effect byte to POISON_SIDE_EFFECT1 here (so the second
    ; hit's effect dispatch chains into the poison side-effect roll), then falls
    ; through to .saveNumberOfHits *without recomputing A* — the hit count Twineedle
    ; ends up with is whatever AL holds at that point, which is POISON_SIDE_EFFECT1
    ; itself (0x02). This only produces the correct "2 hits" because
    ; POISON_SIDE_EFFECT1 == 2 by coincidence of the effect-constant numbering.
    ; Preserved verbatim — do not "fix" by loading an explicit 2.
    mov al, POISON_SIDE_EFFECT1
    mov [ebp + esi], al                 ; ld [hl],a — overwrite move effect byte
    jmp .saveNumberOfHits
.ret:
    ret
; ===========================================================================
; FlinchSideEffect — pret engine/battle/effects.asm:FlinchSideEffect.
; Rolls FLINCH_SIDE_EFFECT1 (10%) or otherwise (30%) and, on success, sets
; FLINCHED on the move's target. A substitute on the target blocks the effect
; entirely (silent — `ret nz`, no text, matching pret).
; ===========================================================================
global FlinchSideEffect
FlinchSideEffect:
    call CheckTargetSubstitute
    jnz .ret                            ; ret nz — substitute up, stay silent

    mov esi, wEnemyBattleStatus1        ; hl = target's battle status1
    mov edx, wPlayerMoveEffect          ; de = attacker's move effect
    mov al, [ebp + hWhoseTurn]
    and al, al
    jz .flinchSideEffect                ; player's turn → target = enemy (defaults above)
    mov esi, wPlayerBattleStatus1       ; enemy's turn → target = player
    mov edx, wEnemyMoveEffect
.flinchSideEffect:
    mov al, [ebp + wLinkState]
    cmp al, LINK_STATE_BATTLING
    jne .skipClear1
    call ClearHyperBeam
.skipClear1:
    mov al, [ebp + edx]                 ; ld a,[de] — move effect
    cmp al, FLINCH_SIDE_EFFECT1
    mov bh, (10 * 0xFF / 100) + 1       ; chance of flinch (FLINCH_SIDE_EFFECT1)
    je .gotEffectChance
    mov bh, (30 * 0xFF / 100) + 1       ; chance of flinch otherwise (FLINCH_SIDE_EFFECT2)
.gotEffectChance:
    call BattleRandom
    cmp al, bh                          ; was the flinch successful?
    jae .ret                            ; ret nc — roll failed, stay silent

    or byte [ebp + esi], 1 << FLINCHED  ; set mon's status to flinching
    call ClearHyperBeam
.ret:
    ret
; ===========================================================================
; ChargeEffect — pret engine/battle/effects.asm:ChargeEffect.
; ===========================================================================
global ChargeEffect
ChargeEffect:
    mov esi, wPlayerBattleStatus1       ; ld hl, wPlayerBattleStatus1
    mov edx, wPlayerMoveEffect          ; ld de, wPlayerMoveEffect
    mov al, [ebp + hWhoseTurn]          ; ldh a, [hWhoseTurn]
    and al, al
    mov bh, XSTATITEM_ANIM              ; ld b, XSTATITEM_ANIM
    jz .chargeEffect                    ; jr z, .chargeEffect
    mov esi, wEnemyBattleStatus1        ; ld hl, wEnemyBattleStatus1
    mov edx, wEnemyMoveEffect           ; ld de, wEnemyMoveEffect
    mov bh, XSTATITEM_DUPLICATE_ANIM    ; ld b, XSTATITEM_DUPLICATE_ANIM
.chargeEffect:
    or byte [ebp + esi], 1 << CHARGING_UP   ; set CHARGING_UP, [hl]
    mov al, [ebp + edx]                 ; ld a, [de]  (move effect)
    dec edx                             ; dec de -> de contains enemy/player MOVENUM
    cmp al, FLY_EFFECT
    jne .notFly
    or byte [ebp + esi], 1 << INVULNERABLE  ; mon is now invulnerable to typical attacks (fly/dig)
    mov bh, TELEPORT                    ; load Teleport's animation
.notFly:
    mov al, [ebp + edx]                 ; ld a, [de]  (move num)
    cmp al, DIG
    jne .notDigOrFly
    or byte [ebp + esi], 1 << INVULNERABLE  ; mon is now invulnerable to typical attacks (fly/dig)
    mov bh, SLIDE_DOWN_ANIM
.notDigOrFly:
    push edx                            ; push de
    push ebx                            ; push bc  (preserve bh = chosen anim id)
    inc esi                             ; inc hl -> battle status 2
    push esi                            ; push hl
    mov al, [ebp + esi]                 ; ld a, [hl]
    test al, 1 << HAS_SUBSTITUTE_UP     ; bit HAS_SUBSTITUTE_UP, a
    jz .skipHide                        ; (call nz, Bankswitch — only if substitute is up)
    mov esi, HideSubstituteShowMonAnim  ; ld hl, HideSubstituteShowMonAnim (BANK(...) dropped — §2 item 4)
    call Bankswitch
.skipHide:
    pop esi                             ; pop hl  (esi = battle status 2 ptr again)
    pop ebx                             ; pop bc
    xor al, al
    mov [ebp + wAnimationType], al      ; xor a / ld [wAnimationType], a
    mov al, bh                          ; ld a, b
    call PlayBattleAnimation
    mov al, [ebp + esi]                 ; ld a, [hl]  (same status2 ptr, re-read like pret)
    test al, 1 << HAS_SUBSTITUTE_UP     ; bit HAS_SUBSTITUTE_UP, a
    jz .skipReshow                      ; (call nz, Bankswitch — only if substitute is up)
    mov esi, ReshowSubstituteAnim       ; ld hl, ReshowSubstituteAnim
    call Bankswitch
.skipReshow:
    pop edx                             ; pop de  (movenum ptr)
    mov al, [ebp + edx]                 ; ld a, [de]
    mov [ebp + wChargeMoveNum], al     ; ld [wChargeMoveNum], a

    mov esi, ChargeMoveEffectText       ; ld hl, ChargeMoveEffectText
    jmp PrintText                       ; jp PrintText

; ---------------------------------------------------------------------------
; ChargeMoveEffectText — pret engine/battle/effects.asm:ChargeMoveEffectText.
;
; pret's own shape, restored: a text_far intro ("<USER>", data/text/text_5.asm
; _ChargeMoveEffectText, generated into assets/battle_text.inc) followed by a
; text_asm hook that picks the matching completion stream by wChargeMoveNum and
; returns it in HL(ESI), so TextCommandProcessor resumes the message there.
;
; This replaces six hand-encoded composite `db 0x00, 0x5A, ...` blobs that pasted
; <USER> in front of each completion text's bytes. They rendered the same thing,
; but they were charmap hex in a .asm (the two-tier rule forbids it), they
; duplicated six generated streams byte-for-byte, and they dropped both pret
; labels. Nothing here needs composing in code: TX_FAR and TX_START_ASM are both
; real in the port's TextCommandProcessor (text-engine finding T-1).
;
; Flags: pret's `ld hl, XxxText` between the `cp` and the `jr z` does not disturb
; the compare, and neither does `mov esi, imm32` — the cascade translates directly.
; DIG is the unconditional default: pret has no `jr z` after its last `cp DIG`, so
; an unmatched move also falls into .gotText holding DugAHoleText.
; ---------------------------------------------------------------------------
ChargeMoveEffectText:
    text_far _ChargeMoveEffectText
    text_asm                            ; TX_START_ASM → TextCommandProcessor jumps here
    mov al, [ebp + wChargeMoveNum]      ; ld a, [wChargeMoveNum]
    cmp al, RAZOR_WIND
    mov esi, MadeWhirlwindText           ; ld hl, MadeWhirlwindText (flag-neutral)
    je .gotText                          ; jr z, .gotText
    cmp al, SOLARBEAM
    mov esi, TookInSunlightText
    je .gotText
    cmp al, SKULL_BASH
    mov esi, LoweredItsHeadText
    je .gotText
    cmp al, SKY_ATTACK
    mov esi, SkyAttackGlowingText
    je .gotText
    cmp al, FLY
    mov esi, FlewUpHighText
    je .gotText
    cmp al, DIG
    mov esi, DugAHoleText               ; no `jr z` in pret — DIG is the fallthrough default
.gotText:
    ret

; ===========================================================================
; TrappingEffect — pret engine/battle/effects.asm:TrappingEffect
;
; Sets USING_TRAPPING_MOVE on the attacker's own battle-status (hWhoseTurn side)
; and seeds wXxxNumAttacksLeft with a 2-5 turn counter (3/8 chance of 2 or 3,
; 1/8 chance of 4 or 5 — matches pret's comment). If the attacker is already
; mid-trap (bit already set, e.g. turn 2 of a Wrap), this is a no-op: ret nz
; leaves the existing counter untouched, so a Wrap chain doesn't re-roll its
; remaining-turns count each turn — faithful to pret.
;
; NOTE (pret comment, preserved verbatim — not a bugs_and_glitches.md-listed bug,
; just the original author's own caveat): this effect runs BEFORE the move's
; accuracy/hit test, so ClearHyperBeam fires — and USING_TRAPPING_MOVE/the attack
; counter get set — even if the trapping move goes on to miss. The practical
; upshot is the attacker won't need to recharge from a prior Hyper Beam even when
; the trapping move whiffs. This is intentional pret behavior (order of operations
; in JumpMoveEffect), not something this handler can or should "fix" — translated
; verbatim.
; ===========================================================================
global TrappingEffect
TrappingEffect:
    mov esi, wPlayerBattleStatus1       ; hl = wPlayerBattleStatus1
    mov edx, wPlayerNumAttacksLeft      ; de = wPlayerNumAttacksLeft
    mov al, [ebp + hWhoseTurn]
    and al, al
    jz .trappingEffect
    mov esi, wEnemyBattleStatus1
    mov edx, wEnemyNumAttacksLeft
.trappingEffect:
    test byte [ebp + esi], 1 << USING_TRAPPING_MOVE
    jnz .ret                            ; ret nz — already trapping; leave counter alone
    call ClearHyperBeam                 ; see NOTE above: runs before the hit test
    or byte [ebp + esi], 1 << USING_TRAPPING_MOVE   ; mon is now using a trapping move
    call BattleRandom                   ; 3/8 chance for 2 and 3 attacks,
    and al, 3                           ; 1/8 chance for 4 and 5 attacks
    cmp al, 2
    jc .setTrappingCounter
    call BattleRandom
    and al, 3
.setTrappingCounter:
    inc al
    mov [ebp + edx], al
.ret:
    ret
global ConfusionSideEffect
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
global ConfusionEffect
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
; ===========================================================================
; HyperBeamEffect — pret engine/battle/effects.asm:HyperBeamEffect.
;   ld hl, wPlayerBattleStatus2
;   ldh a, [hWhoseTurn]
;   and a
;   jr z, .hyperBeamEffect
;   ld hl, wEnemyBattleStatus2
; .hyperBeamEffect
;   set NEEDS_TO_RECHARGE, [hl]   ; mon now needs to recharge
;   ret
;
; In: hWhoseTurn (0 = player's turn, nonzero = enemy's turn) selects which side's
; wXxxBattleStatus2 byte gets NEEDS_TO_RECHARGE set — the ATTACKING side (the side
; whose hWhoseTurn value it is), matching pret's literal hl selection.
; Out: NEEDS_TO_RECHARGE bit set on that side's battle-status-2 byte.
; Clobbers: AL, ESI.
; ===========================================================================
global HyperBeamEffect
HyperBeamEffect:
    mov esi, wPlayerBattleStatus2       ; ld hl, wPlayerBattleStatus2
    mov al, [ebp + hWhoseTurn]          ; ldh a, [hWhoseTurn]
    and al, al
    jz .hyperBeamEffect                 ; jr z, .hyperBeamEffect
    mov esi, wEnemyBattleStatus2        ; ld hl, wEnemyBattleStatus2
.hyperBeamEffect:
    or byte [ebp + esi], 1 << NEEDS_TO_RECHARGE   ; set NEEDS_TO_RECHARGE, [hl]
    ret
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
; PrintNoEffectText — pret engine/battle/effects.asm:PrintNoEffectText.
; ===========================================================================
global PrintNoEffectText
PrintNoEffectText:
    mov esi, NoEffectText
    jmp PrintText

; ===========================================================================
; ConditionalPrintButItFailed / PrintButItFailedText_ — pret effects.asm.
; ConditionalPrintButItFailed: if the side effect failed yet the attack landed
; (wMoveDidntMiss != 0) return silently; otherwise print "But it failed!".
; ===========================================================================
global ConditionalPrintButItFailed
; ===========================================================================
; RageEffect — set USING_RAGE on the attacker's battle-status byte.
;
; pret:
;   RageEffect:
;       ld hl, wPlayerBattleStatus2
;       ldh a, [hWhoseTurn]
;       and a
;       jr z, .player
;       ld hl, wEnemyBattleStatus2
;   .player
;       set USING_RAGE, [hl] ; mon is now in "rage" mode
;       ret
; ===========================================================================
global RageEffect
RageEffect:
    mov esi, wPlayerBattleStatus2       ; ld hl, wPlayerBattleStatus2
    mov al, [ebp + hWhoseTurn]          ; ldh a, [hWhoseTurn]
    and al, al
    jz .player                          ; jr z, .player (player's turn → keep player ptr)
    mov esi, wEnemyBattleStatus2        ; ld hl, wEnemyBattleStatus2
.player:
    or byte [ebp + esi], 1 << USING_RAGE   ; set USING_RAGE, [hl]
    ret
; ===========================================================================
; MimicEffect — copy a move from the target's moveset into the user's Mimic
; slot for the remainder of the battle. Accuracy-tested (MoveHitTest); misses
; outright if the target is INVULNERABLE (charging Fly/Dig).
; ===========================================================================
global MimicEffect
MimicEffect:
    mov bl, 50                          ; ld c, 50
    call DelayFrames
    call MoveHitTest
    mov al, [ebp + wMoveMissed]
    and al, al
    jnz .mimicMissed
    mov al, [ebp + hWhoseTurn]
    and al, al                          ; ZF=1 → player's turn; ZF=0 → enemy's turn
                                         ; (flags held live across the two mov's below,
                                         ; exactly as pret's ld/ld doesn't touch flags)
    mov esi, wBattleMonMoves            ; hl = wBattleMonMoves (target's moves, if
                                         ; this turns out to be the enemy's turn)
    mov dl, [ebp + wPlayerBattleStatus1]   ; a = wPlayerBattleStatus1 (target battlestatus
                                         ; if enemy's turn — player is the target)
    jnz .enemyTurn                      ; hWhoseTurn != 0 → enemy's turn: target = player
    ; --- player's turn: link battle picks at random; normal battle lets the
    ; player choose (the Gen-1 asymmetry — GLITCH, see .letPlayerChooseMove) ---
    mov al, [ebp + wLinkState]
    cmp al, LINK_STATE_BATTLING
    jne .letPlayerChooseMove
    mov esi, wEnemyMonMoves             ; link battle: target = enemy, random pick
    mov dl, [ebp + wEnemyBattleStatus1]
.enemyTurn:
    test dl, 1 << INVULNERABLE          ; bit INVULNERABLE, a — target charging Fly/Dig?
    jnz .mimicMissed
.getRandomMove:
    push esi                            ; push hl
    call BattleRandom
    and al, 3                           ; and $3
    movzx ebx, al                       ; ld c, a / ld b, 0
    add esi, ebx                        ; add hl, bc
    mov al, [ebp + esi]                 ; ld a, [hl]
    pop esi                             ; pop hl
    and al, al
    jz .getRandomMove                   ; loop until a non-empty move slot is hit
    mov dl, al                          ; ld d, a — picked move id
    mov al, [ebp + hWhoseTurn]
    and al, al
    mov esi, wBattleMonMoves            ; hl = user's own moves (write target)
    mov al, [ebp + wPlayerMoveListIndex]   ; a = index of the Mimic slot itself
    jz .playerTurn
    mov esi, wEnemyMonMoves
    mov al, [ebp + wEnemyMoveListIndex]
    jmp .playerTurn
.letPlayerChooseMove:
    mov al, [ebp + wEnemyBattleStatus1]
    test al, 1 << INVULNERABLE
    jnz .mimicMissed
    mov al, [ebp + wCurrentMenuItem]
    push eax                            ; push af — only AL (the index) matters
    mov byte [ebp + wMoveMenuType], 1   ; select the "choose which foe move to mimic" UI
    ; TODO(master): the live MoveSelectionMenu (engine/battle/core.asm) explicitly defers
    ; the mimic-mode menu (wMoveMenuType=1, listing wEnemyMonMoves) — its header comment
    ; says "Mimic/relearn menus ... deferred (not reachable here)"; it always lists the
    ; player's OWN wBattleMonMoves regardless of wMoveMenuType. Faithful pret call kept
    ; here (§3 control-flow-into-battle-core); the actual mimic-mode listing/selection is
    ; a real gap in core.asm's MoveSelectionMenu, not something this handler can fix.
    call MoveSelectionMenu
    call LoadScreenTilesFromBuffer1
    mov esi, wEnemyMonMoves
    movzx ebx, byte [ebp + wCurrentMenuItem]
    add esi, ebx                        ; (kept as add+deref rather than a single
    mov dl, [ebp + esi]                 ; [ebp+esi+ebx] form — see recoil.asm precedent)
    pop eax
    mov esi, wBattleMonMoves            ; hl = wBattleMonMoves — on the player's turn the
                                         ; write target is always the player's own moves
.playerTurn:
    movzx ebx, al                       ; ld c, a / ld b, 0 — index of the Mimic slot
    add esi, ebx                        ; add hl, bc
    mov al, dl                          ; ld a, d — the picked/chosen move id
    mov [ebp + esi], al                 ; ld [hl], a — overwrite the Mimic slot
    mov [ebp + wNamedObjectIndex], al
    call GetMoveName
    call PlayCurrentMoveAnimation
    mov esi, MimicLearnedMoveText
    jmp PrintText
.mimicMissed:
    jmp PrintButItFailedText_

; GLITCH{class=data-model; pret=engine/battle/effects.asm:MimicEffect; behavior=the human chooses a copied move while enemy AI and link players receive a random move; evidence=pret choose-menu and BattleRandom branches; lifetime=permanent Gen-1 behavior; safety=pure bounded battle selection with no OOB or ACE hazard}
; Player-chooses-vs-AI-random Mimic asymmetry — pret ref:
; engine/battle/effects.asm:MimicEffect (.letPlayerChooseMove vs .getRandomMove).
; In a normal (non-link) battle the HUMAN player is shown a move-selection menu and
; freely CHOOSES which of the target's moves to copy; the enemy AI (and the player in
; a link battle) gets a uniformly random pick via BattleRandom & 3 (looping past empty
; slots). This is genuine Gen-1 behavior, not a translation bug — preserved verbatim,
; not "fixed" to be symmetric.
; Safety: safe — pure battle-logic fairness quirk, no engine/OOB hazard.
; ===========================================================================
; SplashEffect — Splash: no accuracy test, no target check, no state change.
; Plays the move's subanimation, then unconditionally prints "But nothing
; happened!" through pret's PrintNoEffectText (pret line 1451, below).
; ===========================================================================
global SplashEffect
SplashEffect:
    call PlayCurrentMoveAnimation
    jmp PrintNoEffectText
; ===========================================================================
; DisableEffect — pret engine/battle/effects.asm:DisableEffect.
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
global DisableEffect
DisableEffect:
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
; MoveEffectPointerTable moved 2026-08-02 to src/data/move_effect_pointers.asm.
; It is a pret data/moves/effects_pointers.asm table and lint_pret_labels reported
; it [aux_misplaced]. pret files this dispatch table under data/ too, even though
; its rows are code pointers, so following pret's own placement cleared the finding
; without needing an exception. It is still HAND-WRITTEN (Tier 2 authorship, data
; layer placement) — no generator can derive port function names from pret.
; The 86-entry arity assertion travelled with it; it is a label difference and
; must stay in the same translation unit as the table.
extern MoveEffectPointerTable          ; src/data/move_effect_pointers.asm
