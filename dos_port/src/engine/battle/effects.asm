; dos_port/src/engine/battle/effects.asm
; JumpMoveEffect dispatch seam + MoveEffectPointerTable
;
; Port of:
;   engine/battle/effects.asm:JumpMoveEffect + _JumpMoveEffect
;   data/moves/effects_pointers.asm:MoveEffectPointerTable
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
; PORTED + WIRED HANDLERS (all live in the table below; 34 non-NULL effects across
; the listed effect bytes; logged in docs/translation_log.md):
;   StatModifierUpEffect / StatModifierDownEffect  stat_mod_effects.asm
;       ($0A-$0F,$32-$37 up; $12-$17,$3A-$3F,$44-$4B down)
;   SleepEffect_              sleep.asm                  ($01/$20)
;   PoisonEffect_            poison.asm                  ($02/$21/$42, S4 reference)
;   DrainHPEffect_           drain_hp.asm                ($03/$08)
;   FreezeBurnParalyzeEffect_ freeze_burn_paralyze.asm   ($04/$05/$06/$22/$23/$24)
;   ExplodeEffect_           explode.asm                 ($07)
;   PayDayEffect_            pay_day.asm                 ($10)
;   ConversionEffect_        conversion.asm              ($18)
;   HazeEffect_             haze.asm                     ($19)
;   BideEffect_             bide.asm                     ($1A)
;   ThrashPetalDanceEffect_ thrash_petal_dance.asm       ($1B)
;   SwitchAndTeleportEffect_ switch_and_teleport.asm     ($1C)
;   TwoToFiveAttacksEffect_ two_to_five_attacks.asm      ($1D/$1E/$2C/$4D)
;   FlinchSideEffect_       flinch_side.asm              ($1F/$25)
;   OneHitKOEffect_         one_hit_ko.asm               ($26)
;   ChargeEffect_           charge.asm                   ($27/$2B)
;   TrappingEffect_         trapping.asm                 ($2A)
;   MistEffect_             mist.asm                     ($2E)
;   FocusEnergyEffect_      focus_energy.asm             ($2F)
;   RecoilEffect_           recoil.asm                   ($30)
;   ConfusionEffect_        confusion.asm                ($31)
;   HealEffect_             heal.asm                     ($38)
;   TransformEffect_        transform.asm                ($39)
;   ReflectLightScreenEffect_ reflect_light_screen.asm   ($40/$41)
;   ParalyzeEffect_         paralyze.asm                 ($43)
;   ConfusionSideEffect_    confusion.asm                ($4C)
;   SubstituteEffect_       substitute.asm               ($4F)
;   HyperBeamEffect_        hyper_beam.asm               ($50)
;   RageEffect_             rage.asm                     ($51)
;   MimicEffect_            mimic.asm                    ($52)
;   LeechSeedEffect_        leech_seed.asm               ($54)
;   SplashEffect_           splash.asm                   ($55)
;   DisableEffect_          disable.asm                  ($56)
;
; UNPORTED — the 7 NULL-in-pret effects (no body in pret; handled inline in the
; core.asm main flow, not via JumpMoveEffect), so they stay UnportedMoveEffect:
;   $09 MIRROR_MOVE, $11 SWIFT, $28 SUPER_FANG, $29 SPECIAL_DAMAGE (Seismic Toss
;   etc.), $2D JUMP_KICK, $4E (unused const_skip), $53 METRONOME.
;
; Register map: A=AL, B=BH, C=BL (BC=BX), HL=ESI, EBP=GB memory base.

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

; ---------------------------------------------------------------------------
; Externs — ported handler globals from move_effects/*.asm and stat_mod_effects.asm
; ---------------------------------------------------------------------------
; SCAFFOLD WIRING (move-effect swarm — COMPLETE): JumpMoveEffect is LIVE (this file
; links; the core_stubs.asm JumpMoveEffect stub is gone). All 34 non-NULL handlers
; are translated, audited, and externed below; the 7 NULL-in-pret effects route to
; UnportedMoveEffect (a no-op) so a battle can't crash on a moveless effect byte.
extern StatModifierUpEffect     ; src/engine/battle/stat_mod_effects.asm
extern StatModifierDownEffect   ; src/engine/battle/stat_mod_effects.asm
extern PoisonEffect_            ; src/engine/battle/move_effects/poison.asm
extern SplashEffect_           ; src/engine/battle/move_effects/splash.asm
extern FlinchSideEffect_       ; src/engine/battle/move_effects/flinch_side.asm
extern ConfusionEffect_        ; src/engine/battle/move_effects/confusion.asm
extern ConfusionSideEffect_    ; src/engine/battle/move_effects/confusion.asm
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
    dd ConfusionEffect_         ; $31 CONFUSION_EFFECT     — Confuse Ray / Supersonic
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
    dd ConfusionSideEffect_     ; $4C CONFUSION_SIDE_EFFECT — Confusion's 10% side effect
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
