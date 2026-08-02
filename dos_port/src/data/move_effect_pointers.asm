; move_effect_pointers.asm — the move-effect dispatch table.
;
; pret ref: data/moves/effects_pointers.asm:MoveEffectPointerTable
;
; Moved here 2026-08-02 from src/engine/battle/effects.asm to clear its
; [aux_misplaced] finding. This was the one label of the 14 that looked like it
; needed a maintainer exception, because its rows are POINTERS TO CODE, not
; static bytes — and the project's two-tier rule explicitly names it as a
; hand-written `dd` table rather than generated data.
;
; It needed no exception. pret itself files this table under data/ — its home is
; data/moves/effects_pointers.asm, a data file whose `dw` rows point at handlers
; in engine/battle/effects.asm. pret treats a dispatch table as data even though
; its contents are code addresses, and the linter's expectation is
; "dos_port/src/data/ OR a generated assets/*.inc" — so a hand-written table in
; the data layer satisfies both rules at once. It stays hand-written: it is keyed
; by the effect byte but its values are PORT function names, so no generator can
; derive it from pret alone.
;
; pret uses dw (16-bit, ROM bank-relative); here dd (32-bit flat, DPMI linear).
; Entries that are NULL in pret, and any unported handler, point at
; UnportedMoveEffect (a `ret` stub that still lives beside the dispatcher in
; effects.asm).
;
; It also moved from `section .text` to `section .data`: it is read-only data
; reached by `lea esi, [MoveEffectPointerTable + eax*4]` in JumpMoveEffect, never
; executed. link.ld places both in the loaded image, so this is a hygiene change,
; not a behavioural one.
;
; The 86-entry arity assertion travels WITH the table: it is a NASM label
; difference evaluated at assembly time, so both labels must stay in one
; translation unit. Splitting them would have silently disabled the check.
;
; Build: nasm -f coff -I include/ -I . -o move_effect_pointers.o move_effect_pointers.asm
; ---------------------------------------------------------------------------
bits 32

global MoveEffectPointerTable

; Handlers live in src/engine/battle/effects.asm and src/engine/battle/move_effects/*.asm.
extern BideEffect
extern ChargeEffect
extern ConfusionEffect
extern ConfusionSideEffect
extern ConversionEffect_
extern DisableEffect
extern DrainHPEffect_
extern ExplodeEffect
extern FlinchSideEffect
extern FocusEnergyEffect_
extern FreezeBurnParalyzeEffect
extern HazeEffect_
extern HealEffect_
extern HyperBeamEffect
extern LeechSeedEffect_
extern MimicEffect
extern MistEffect_
extern OneHitKOEffect_
extern ParalyzeEffect_
extern PayDayEffect_
extern PoisonEffect
extern RageEffect
extern RecoilEffect_
extern ReflectLightScreenEffect_
extern SleepEffect
extern SplashEffect
extern StatModifierDownEffect
extern StatModifierUpEffect
extern SubstituteEffect_
extern SwitchAndTeleportEffect
extern ThrashPetalDanceEffect
extern TransformEffect_
extern TrappingEffect
extern TwoToFiveAttacksEffect
extern UnportedMoveEffect

section .data
align 4

MoveEffectPointerTable:
    dd SleepEffect             ; $01 EFFECT_01            — Sleep (Sing/Hypnosis etc.)
    dd PoisonEffect            ; $02 [S4 reference handler]
    dd DrainHPEffect_        ; $03 DRAIN_HP_EFFECT
    dd FreezeBurnParalyzeEffect ; $04 BURN_SIDE_EFFECT1    — Burn 10%
    dd FreezeBurnParalyzeEffect ; $05 FREEZE_SIDE_EFFECT1  — Freeze 10%
    dd FreezeBurnParalyzeEffect ; $06 PARALYZE_SIDE_EFFECT1 — Paralyze 10%
    dd ExplodeEffect        ; $07 EXPLODE_EFFECT
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
    dd BideEffect           ; $1A BIDE_EFFECT
    dd ThrashPetalDanceEffect; $1B THRASH_PETAL_DANCE_EFFECT
    dd SwitchAndTeleportEffect; $1C SWITCH_AND_TELEPORT_EFFECT
    dd TwoToFiveAttacksEffect; $1D TWO_TO_FIVE_ATTACKS_EFFECT
    dd TwoToFiveAttacksEffect; $1E EFFECT_1E (unused)
    dd FlinchSideEffect        ; $1F FLINCH_SIDE_EFFECT1  — Flinch 10%
    dd SleepEffect             ; $20 SLEEP_EFFECT         — Sleep
    dd PoisonEffect            ; $21 [S4 reference handler]
    dd FreezeBurnParalyzeEffect ; $22 BURN_SIDE_EFFECT2    — Burn 30%
    dd FreezeBurnParalyzeEffect ; $23 FREEZE_SIDE_EFFECT2  — Freeze 30%
    dd FreezeBurnParalyzeEffect ; $24 PARALYZE_SIDE_EFFECT2 — Paralyze 30%
    dd FlinchSideEffect        ; $25 FLINCH_SIDE_EFFECT2  — Flinch 30%
    dd OneHitKOEffect_       ; $26 OHKO_EFFECT
    dd ChargeEffect         ; $27 CHARGE_EFFECT
    dd UnportedMoveEffect       ; $28 SUPER_FANG_EFFECT    — NULL in pret
    dd UnportedMoveEffect       ; $29 SPECIAL_DAMAGE_EFFECT — NULL in pret (Seismic Toss etc.)
    dd TrappingEffect       ; $2A TRAPPING_EFFECT
    dd ChargeEffect         ; $2B FLY_EFFECT
    dd TwoToFiveAttacksEffect; $2C ATTACK_TWICE_EFFECT
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
    dd PoisonEffect            ; $42 [S4 reference handler]
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
    dd TwoToFiveAttacksEffect; $4D TWINEEDLE_EFFECT
    dd UnportedMoveEffect       ; $4E (unused, const_skip) — NULL in pret
    dd SubstituteEffect_     ; $4F SUBSTITUTE_EFFECT
    dd HyperBeamEffect      ; $50 HYPER_BEAM_EFFECT
    dd RageEffect           ; $51 RAGE_EFFECT
    dd MimicEffect          ; $52 MIMIC_EFFECT
    dd UnportedMoveEffect       ; $53 METRONOME_EFFECT     — NULL in pret
    dd LeechSeedEffect_      ; $54 LEECH_SEED_EFFECT
    dd SplashEffect            ; $55 SPLASH_EFFECT        — Splash ("But nothing happened!")
    dd DisableEffect        ; $56 DISABLE_EFFECT
MoveEffectPointerTableEnd:

; Arity assertion: NUM_MOVE_EFFECTS = $56 = 86 entries ($01..$56, indexed by effect-1).
; NASM evaluates this label-difference at assembly time (both labels in same section).
%define _MEPT_ENTRIES ((MoveEffectPointerTableEnd - MoveEffectPointerTable) / 4)
%if _MEPT_ENTRIES != 86
%fatal "MoveEffectPointerTable arity error: expected 86 entries ($01..$56), got " %+ _MEPT_ENTRIES
%endif
