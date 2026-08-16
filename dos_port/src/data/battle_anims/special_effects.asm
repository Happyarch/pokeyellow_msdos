; special_effects.asm — animation id -> extra special-effect routine.
;
; pret ref: data/battle_anims/special_effects.asm:AnimationIdSpecialEffects
;
; pret keeps this table in data/ and %includes it INTO engine/battle/animations.asm.
; The port carries it at the mirrored path dos_port/src/data/battle_anims/special_effects.asm; it was part of
; src/data/battle_anim_dispatch.asm until 2026-08-16
; (docs/current_plan_data_path_mirror.md).
;
; HAND-WRITTEN (Tier-2 authorship, data-layer placement): no generator can derive
; port function names. Handler targets are the battle-animation stubs in
; core_stubs.asm, retired as each real routine lands.
bits 32

%include "gb_constants.inc"              ; SE_* / anim-id / move-id constants
%include "battle_anims.inc"              ; the `special_effect` row macro

; --- handler targets (core_stubs.asm STUBs unless marked live) ---
extern AnimationFlashScreen               ; live — src/engine/battle/animations.asm
extern TailWhipAnimationUnused
extern DoGrowlSpecialEffects
extern DoBlizzardSpecialEffects
extern FlashScreenEveryFourFrameBlocks     ; live — src/engine/battle/animations.asm
extern FlashScreenEveryEightFrameBlocks    ; live — src/engine/battle/animations.asm
extern DoExplodeSpecialEffects
extern DoRockSlideSpecialEffects
extern TradeHidePokemon
extern TradeShakePokeball
extern TradeJumpPokeball
extern DoBallTossSpecialEffects
extern DoBallShakeSpecialEffects
extern DoPoofSpecialEffects

global AnimationIdSpecialEffects

section .data

AnimationIdSpecialEffects:
    ; animation id, effect routine address
    special_effect MEGA_PUNCH,            AnimationFlashScreen
    special_effect GUILLOTINE,            AnimationFlashScreen
    special_effect MEGA_KICK,             AnimationFlashScreen
    special_effect HEADBUTT,              AnimationFlashScreen
    special_effect TAIL_WHIP,             TailWhipAnimationUnused
    special_effect GROWL,                 DoGrowlSpecialEffects
    special_effect DISABLE,               AnimationFlashScreen
    special_effect BLIZZARD,              DoBlizzardSpecialEffects
    special_effect BUBBLEBEAM,            AnimationFlashScreen
    special_effect HYPER_BEAM,            FlashScreenEveryFourFrameBlocks
    special_effect THUNDERBOLT,           FlashScreenEveryEightFrameBlocks
    special_effect REFLECT,               AnimationFlashScreen
    special_effect SELFDESTRUCT,          DoExplodeSpecialEffects
    special_effect SPORE,                 FlashScreenEveryFourFrameBlocks
    special_effect EXPLOSION,             DoExplodeSpecialEffects
    special_effect ROCK_SLIDE,            DoRockSlideSpecialEffects
    special_effect TRADE_BALL_DROP_ANIM,  TradeHidePokemon
    special_effect TRADE_BALL_SHAKE_ANIM, TradeShakePokeball
    special_effect TRADE_BALL_TILT_ANIM,  TradeJumpPokeball
    special_effect TOSS_ANIM,             DoBallTossSpecialEffects
    special_effect SHAKE_ANIM,            DoBallShakeSpecialEffects
    special_effect POOF_ANIM,             DoPoofSpecialEffects
    special_effect GREATTOSS_ANIM,        DoBallTossSpecialEffects
    special_effect ULTRATOSS_ANIM,        DoBallTossSpecialEffects
    db -1 ; end

