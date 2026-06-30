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
; DISPATCHER ROLE: Wave 2 (battle loop) calls JumpMoveEffect. When an effect handler
; is ported, update the corresponding dd entry to its global label and remove it from
; the unported list in the header comment. Do not touch UnportedMoveEffect itself.
;
; PORTED HANDLERS (wired up in table below):
;   StatModifierUpEffect, StatModifierDownEffect   src/engine/battle/stat_mod_effects.asm
;   PayDayEffect_       src/engine/battle/move_effects/pay_day.asm
;   ConversionEffect_   src/engine/battle/move_effects/conversion.asm
;   HazeEffect_         src/engine/battle/move_effects/haze.asm
;   OneHitKOEffect_     src/engine/battle/move_effects/one_hit_ko.asm
;   MistEffect_         src/engine/battle/move_effects/mist.asm
;   FocusEnergyEffect_  src/engine/battle/move_effects/focus_energy.asm
;   RecoilEffect_       src/engine/battle/move_effects/recoil.asm
;   HealEffect_         src/engine/battle/move_effects/heal.asm
;   ParalyzeEffect_     src/engine/battle/move_effects/paralyze.asm
;   LeechSeedEffect_    src/engine/battle/move_effects/leech_seed.asm
;
; UNPORTED EFFECTS (routed to UnportedMoveEffect; Wave 2 fills in):
;   EFFECT_01 ($01)           SleepEffect
;   POISON_SIDE_EFFECT1 ($02) PoisonEffect
;   DRAIN_HP_EFFECT ($03)     DrainHPEffect_ [exists in drain_hp.asm but NOT global; needs
;                             "global DrainHPEffect_" added to that file before wiring here]
;   BURN_SIDE_EFFECT1 ($04)   FreezeBurnParalyzeEffect
;   FREEZE_SIDE_EFFECT1 ($05) FreezeBurnParalyzeEffect
;   PARALYZE_SIDE_EFFECT1 ($06) FreezeBurnParalyzeEffect
;   EXPLODE_EFFECT ($07)      ExplodeEffect
;   DREAM_EATER_EFFECT ($08)  DrainHPEffect_ [same as above; needs global]
;   MIRROR_MOVE_EFFECT ($09)  NULL in pret (no-op)
;   SWIFT_EFFECT ($11)        NULL in pret (no-op)
;   BIDE_EFFECT ($1A)         BideEffect
;   THRASH_PETAL_DANCE_EFFECT ($1B) ThrashPetalDanceEffect
;   SWITCH_AND_TELEPORT_EFFECT ($1C) SwitchAndTeleportEffect
;   TWO_TO_FIVE_ATTACKS_EFFECT ($1D) TwoToFiveAttacksEffect
;   EFFECT_1E ($1E)           TwoToFiveAttacksEffect (unused in pret)
;   FLINCH_SIDE_EFFECT1 ($1F) FlinchSideEffect
;   SLEEP_EFFECT ($20)        SleepEffect
;   POISON_SIDE_EFFECT2 ($21) PoisonEffect
;   BURN_SIDE_EFFECT2 ($22)   FreezeBurnParalyzeEffect
;   FREEZE_SIDE_EFFECT2 ($23) FreezeBurnParalyzeEffect (unused JP-only)
;   PARALYZE_SIDE_EFFECT2 ($24) FreezeBurnParalyzeEffect
;   FLINCH_SIDE_EFFECT2 ($25) FlinchSideEffect
;   CHARGE_EFFECT ($27)       ChargeEffect
;   SUPER_FANG_EFFECT ($28)   NULL in pret (no-op)
;   SPECIAL_DAMAGE_EFFECT ($29) NULL in pret (no-op; Seismic Toss etc.)
;   TRAPPING_EFFECT ($2A)     TrappingEffect
;   FLY_EFFECT ($2B)          ChargeEffect
;   ATTACK_TWICE_EFFECT ($2C) TwoToFiveAttacksEffect
;   JUMP_KICK_EFFECT ($2D)    NULL in pret (no-op)
;   CONFUSION_EFFECT ($31)    ConfusionEffect
;   TRANSFORM_EFFECT ($39)    TransformEffect_
;   LIGHT_SCREEN_EFFECT ($40) ReflectLightScreenEffect_ [reflect_light_screen.asm has text
;                             stubs only; main handler not yet ported]
;   REFLECT_EFFECT ($41)      ReflectLightScreenEffect_ [same]
;   POISON_EFFECT ($42)       PoisonEffect
;   CONFUSION_SIDE_EFFECT ($4C) ConfusionSideEffect
;   TWINEEDLE_EFFECT ($4D)    TwoToFiveAttacksEffect
;   unused ($4E)              NULL in pret
;   SUBSTITUTE_EFFECT ($4F)   SubstituteEffect_
;   HYPER_BEAM_EFFECT ($50)   HyperBeamEffect
;   RAGE_EFFECT ($51)         RageEffect
;   MIMIC_EFFECT ($52)        MimicEffect
;   METRONOME_EFFECT ($53)    NULL in pret (no-op)
;   SPLASH_EFFECT ($55)       SplashEffect
;   DISABLE_EFFECT ($56)      DisableEffect
;
; Register map: A=AL, B=BH, C=BL (BC=BX), HL=ESI, EBP=GB memory base.

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

; ---------------------------------------------------------------------------
; Externs — ported handler globals from move_effects/*.asm and stat_mod_effects.asm
; ---------------------------------------------------------------------------
; SCAFFOLD WIRING (move-effect swarm): JumpMoveEffect is now LIVE (this file links;
; the core_stubs.asm JumpMoveEffect stub is gone). Only the handlers that are ported
; AND integrated are wired below; every other entry routes to UnportedMoveEffect (a
; no-op) so a battle can't crash on an unported move. The 14 audit-first drafts in
; move_effects/* + the swarm's fresh bodies are wired in by the master as each one
; passes audit (S5). Live now:
;   - StatModifierUpEffect / StatModifierDownEffect  (shared stat body, §4)
;   - PoisonEffect_                                  (S4 reference handler)
extern StatModifierUpEffect     ; src/engine/battle/stat_mod_effects.asm
extern StatModifierDownEffect   ; src/engine/battle/stat_mod_effects.asm
extern PoisonEffect_            ; src/engine/battle/move_effects/poison.asm

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
    dd UnportedMoveEffect       ; $01 EFFECT_01            — SleepEffect (unported)
    dd PoisonEffect_            ; $02 [S4 reference handler]
    dd UnportedMoveEffect       ; (draft; await audit)           ; $03 DRAIN_HP_EFFECT      — Absorb / Mega Drain
    dd UnportedMoveEffect       ; $04 BURN_SIDE_EFFECT1    — FreezeBurnParalyzeEffect (unported)
    dd UnportedMoveEffect       ; $05 FREEZE_SIDE_EFFECT1  — FreezeBurnParalyzeEffect (unported)
    dd UnportedMoveEffect       ; $06 PARALYZE_SIDE_EFFECT1 — FreezeBurnParalyzeEffect (unported)
    dd UnportedMoveEffect       ; $07 EXPLODE_EFFECT       — ExplodeEffect (unported)
    dd UnportedMoveEffect       ; (draft; await audit)           ; $08 DREAM_EATER_EFFECT   — Dream Eater
    dd UnportedMoveEffect       ; $09 MIRROR_MOVE_EFFECT   — NULL in pret
    dd StatModifierUpEffect     ; $0A ATTACK_UP1_EFFECT
    dd StatModifierUpEffect     ; $0B DEFENSE_UP1_EFFECT
    dd StatModifierUpEffect     ; $0C SPEED_UP1_EFFECT
    dd StatModifierUpEffect     ; $0D SPECIAL_UP1_EFFECT
    dd StatModifierUpEffect     ; $0E ACCURACY_UP1_EFFECT
    dd StatModifierUpEffect     ; $0F EVASION_UP1_EFFECT
    dd UnportedMoveEffect       ; (draft; await audit)            ; $10 PAY_DAY_EFFECT
    dd UnportedMoveEffect       ; $11 SWIFT_EFFECT         — NULL in pret
    dd StatModifierDownEffect   ; $12 ATTACK_DOWN1_EFFECT
    dd StatModifierDownEffect   ; $13 DEFENSE_DOWN1_EFFECT
    dd StatModifierDownEffect   ; $14 SPEED_DOWN1_EFFECT
    dd StatModifierDownEffect   ; $15 SPECIAL_DOWN1_EFFECT
    dd StatModifierDownEffect   ; $16 ACCURACY_DOWN1_EFFECT
    dd StatModifierDownEffect   ; $17 EVASION_DOWN1_EFFECT
    dd UnportedMoveEffect       ; (draft; await audit)        ; $18 CONVERSION_EFFECT
    dd UnportedMoveEffect       ; (draft; await audit)              ; $19 HAZE_EFFECT
    dd UnportedMoveEffect       ; $1A BIDE_EFFECT          — BideEffect (unported)
    dd UnportedMoveEffect       ; $1B THRASH_PETAL_DANCE_EFFECT — ThrashPetalDanceEffect (unported)
    dd UnportedMoveEffect       ; $1C SWITCH_AND_TELEPORT_EFFECT — SwitchAndTeleportEffect (unported)
    dd UnportedMoveEffect       ; $1D TWO_TO_FIVE_ATTACKS_EFFECT — TwoToFiveAttacksEffect (unported)
    dd UnportedMoveEffect       ; $1E EFFECT_1E (unused)   — TwoToFiveAttacksEffect (unported)
    dd UnportedMoveEffect       ; $1F FLINCH_SIDE_EFFECT1  — FlinchSideEffect (unported)
    dd UnportedMoveEffect       ; $20 SLEEP_EFFECT         — SleepEffect (unported)
    dd PoisonEffect_            ; $21 [S4 reference handler]
    dd UnportedMoveEffect       ; $22 BURN_SIDE_EFFECT2    — FreezeBurnParalyzeEffect (unported)
    dd UnportedMoveEffect       ; $23 FREEZE_SIDE_EFFECT2  — FreezeBurnParalyzeEffect (unported)
    dd UnportedMoveEffect       ; $24 PARALYZE_SIDE_EFFECT2 — FreezeBurnParalyzeEffect (unported)
    dd UnportedMoveEffect       ; $25 FLINCH_SIDE_EFFECT2  — FlinchSideEffect (unported)
    dd UnportedMoveEffect       ; (draft; await audit)          ; $26 OHKO_EFFECT
    dd UnportedMoveEffect       ; $27 CHARGE_EFFECT        — ChargeEffect (unported)
    dd UnportedMoveEffect       ; $28 SUPER_FANG_EFFECT    — NULL in pret
    dd UnportedMoveEffect       ; $29 SPECIAL_DAMAGE_EFFECT — NULL in pret (Seismic Toss etc.)
    dd UnportedMoveEffect       ; $2A TRAPPING_EFFECT      — TrappingEffect (unported)
    dd UnportedMoveEffect       ; $2B FLY_EFFECT           — ChargeEffect (unported)
    dd UnportedMoveEffect       ; $2C ATTACK_TWICE_EFFECT  — TwoToFiveAttacksEffect (unported)
    dd UnportedMoveEffect       ; $2D JUMP_KICK_EFFECT     — NULL in pret
    dd UnportedMoveEffect       ; (draft; await audit)              ; $2E MIST_EFFECT
    dd UnportedMoveEffect       ; (draft; await audit)       ; $2F FOCUS_ENERGY_EFFECT
    dd UnportedMoveEffect       ; (draft; await audit)            ; $30 RECOIL_EFFECT
    dd UnportedMoveEffect       ; $31 CONFUSION_EFFECT     — ConfusionEffect (unported)
    dd StatModifierUpEffect     ; $32 ATTACK_UP2_EFFECT
    dd StatModifierUpEffect     ; $33 DEFENSE_UP2_EFFECT
    dd StatModifierUpEffect     ; $34 SPEED_UP2_EFFECT
    dd StatModifierUpEffect     ; $35 SPECIAL_UP2_EFFECT
    dd StatModifierUpEffect     ; $36 ACCURACY_UP2_EFFECT
    dd StatModifierUpEffect     ; $37 EVASION_UP2_EFFECT
    dd UnportedMoveEffect       ; (draft; await audit)              ; $38 HEAL_EFFECT
    dd UnportedMoveEffect       ; $39 TRANSFORM_EFFECT     — TransformEffect_ (unported)
    dd StatModifierDownEffect   ; $3A ATTACK_DOWN2_EFFECT
    dd StatModifierDownEffect   ; $3B DEFENSE_DOWN2_EFFECT
    dd StatModifierDownEffect   ; $3C SPEED_DOWN2_EFFECT
    dd StatModifierDownEffect   ; $3D SPECIAL_DOWN2_EFFECT
    dd StatModifierDownEffect   ; $3E ACCURACY_DOWN2_EFFECT
    dd StatModifierDownEffect   ; $3F EVASION_DOWN2_EFFECT
    dd UnportedMoveEffect       ; $40 LIGHT_SCREEN_EFFECT  — ReflectLightScreenEffect_ (unported)
    dd UnportedMoveEffect       ; $41 REFLECT_EFFECT       — ReflectLightScreenEffect_ (unported)
    dd PoisonEffect_            ; $42 [S4 reference handler]
    dd UnportedMoveEffect       ; (draft; await audit)          ; $43 PARALYZE_EFFECT
    dd StatModifierDownEffect   ; $44 ATTACK_DOWN_SIDE_EFFECT
    dd StatModifierDownEffect   ; $45 DEFENSE_DOWN_SIDE_EFFECT
    dd StatModifierDownEffect   ; $46 SPEED_DOWN_SIDE_EFFECT
    dd StatModifierDownEffect   ; $47 SPECIAL_DOWN_SIDE_EFFECT
    dd StatModifierDownEffect   ; $48 (unused, const_skip) — pret: StatModifierDownEffect
    dd StatModifierDownEffect   ; $49 (unused, const_skip) — pret: StatModifierDownEffect
    dd StatModifierDownEffect   ; $4A (unused, const_skip) — pret: StatModifierDownEffect
    dd StatModifierDownEffect   ; $4B (unused, const_skip) — pret: StatModifierDownEffect
    dd UnportedMoveEffect       ; $4C CONFUSION_SIDE_EFFECT — ConfusionSideEffect (unported)
    dd UnportedMoveEffect       ; $4D TWINEEDLE_EFFECT     — TwoToFiveAttacksEffect (unported)
    dd UnportedMoveEffect       ; $4E (unused, const_skip) — NULL in pret
    dd UnportedMoveEffect       ; $4F SUBSTITUTE_EFFECT    — SubstituteEffect_ (unported)
    dd UnportedMoveEffect       ; $50 HYPER_BEAM_EFFECT    — HyperBeamEffect (unported)
    dd UnportedMoveEffect       ; $51 RAGE_EFFECT          — RageEffect (unported)
    dd UnportedMoveEffect       ; $52 MIMIC_EFFECT         — MimicEffect (unported)
    dd UnportedMoveEffect       ; $53 METRONOME_EFFECT     — NULL in pret
    dd UnportedMoveEffect       ; (draft; await audit)         ; $54 LEECH_SEED_EFFECT
    dd UnportedMoveEffect       ; $55 SPLASH_EFFECT        — SplashEffect (unported)
    dd UnportedMoveEffect       ; $56 DISABLE_EFFECT       — DisableEffect (unported)
MoveEffectPointerTableEnd:

; Arity assertion: NUM_MOVE_EFFECTS = $56 = 86 entries ($01..$56, indexed by effect-1).
; NASM evaluates this label-difference at assembly time (both labels in same section).
%define _MEPT_ENTRIES ((MoveEffectPointerTableEnd - MoveEffectPointerTable) / 4)
%if _MEPT_ENTRIES != 86
%fatal "MoveEffectPointerTable arity error: expected 86 entries ($01..$56), got " %+ _MEPT_ENTRIES
%endif
