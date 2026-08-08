; battle_anim_dispatch.asm — hand-written battle-animation dispatch tables.
;
; pret keeps SpecialEffectPointers (data/battle_anims/special_effect_pointers.asm)
; and AnimationIdSpecialEffects (data/battle_anims/special_effects.asm) as data
; tables, %included INTO engine/battle/animations.asm. Placing them in the engine
; mirror trips the linter's aux_misplaced rule (pret data/ label outside the data
; layer), so — exactly like MoveEffectPointerTable (src/data/move_effect_pointers.asm)
; — they live here in the data layer. They are still HAND-WRITTEN (Tier-2
; authorship, data-layer placement): no generator can derive port function names.
;
; pret uses `db id; dw ptr` (3-byte entries; 16-bit ROM pointers). The flat DPMI
; model uses `db id; dd ptr` (5-byte entries; 32-bit program-image addresses),
; which is why PlayAnimation's search loop strides by 5 and
; DoSpecialEffectByAnimationId passes stride 5 to IsInArray (both in
; src/engine/battle/animations.asm). The handler targets are the Stage 3-5 stubs
; in core_stubs.asm (retired as each real routine lands) plus AnimationDelay10
; (live, in animations.asm).
bits 32

%include "gb_constants.inc"              ; SE_* / anim-id / move-id constants

; --- handler targets (core_stubs.asm STUBs unless marked live) ---
extern AnimationFlashScreen               ; live — src/engine/battle/animations.asm
extern AnimationDarkScreenPalette         ; live — src/engine/battle/animations.asm
extern AnimationResetScreenPalette        ; live — src/engine/battle/animations.asm
extern AnimationShakeScreen               ; live — src/engine/battle/animations.asm
extern AnimationWaterDropletsEverywhere
extern AnimationDarkenMonPalette          ; live — src/engine/battle/animations.asm
extern AnimationFlashScreenLong           ; live — src/engine/battle/animations.asm
extern AnimationSlideMonUp
extern AnimationSlideMonDown
extern AnimationFlashMonPic
extern AnimationSlideMonOff
extern AnimationBlinkMon
extern AnimationMoveMonHorizontally
extern AnimationResetMonPosition
extern AnimationLightScreenPalette         ; live — src/engine/battle/animations.asm
extern AnimationHideMonPic
extern AnimationSquishMonPic
extern AnimationShootBallsUpward
extern AnimationShootManyBallsUpward
extern AnimationBoundUpAndDown
extern AnimationMinimizeMon
extern AnimationSlideMonDownAndHide
extern AnimationTransformMon
extern AnimationLeavesFalling
extern AnimationPetalsFalling
extern AnimationSlideMonHalfOff
extern AnimationShakeEnemyHUD
extern AnimationSpiralBallsInward
extern AnimationDelay10                   ; live — src/engine/battle/animations.asm
extern AnimationFlashEnemyMonPic
extern AnimationHideEnemyMonPic
extern AnimationBlinkEnemyMon             ; live — src/engine/battle/animations.asm
extern AnimationShowMonPic
extern AnimationShowEnemyMonPic
extern AnimationSlideEnemyMonOff
extern AnimationShakeBackAndForth
extern AnimationSubstitute
extern AnimationWavyScreen
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

global SpecialEffectPointers
global AnimationIdSpecialEffects

%macro special_effect 2
    db %1
    dd %2
%endmacro

section .data

SpecialEffectPointers:
    ; special effect id, effect routine address
    special_effect SE_DARK_SCREEN_FLASH,         AnimationFlashScreen             ; $FE
    special_effect SE_DARK_SCREEN_PALETTE,       AnimationDarkScreenPalette       ; $FD
    special_effect SE_RESET_SCREEN_PALETTE,      AnimationResetScreenPalette      ; $FC
    special_effect SE_SHAKE_SCREEN,              AnimationShakeScreen             ; $FB
    special_effect SE_WATER_DROPLETS_EVERYWHERE, AnimationWaterDropletsEverywhere ; $FA
    special_effect SE_DARKEN_MON_PALETTE,        AnimationDarkenMonPalette        ; $F9
    special_effect SE_FLASH_SCREEN_LONG,         AnimationFlashScreenLong         ; $F8
    special_effect SE_SLIDE_MON_UP,              AnimationSlideMonUp              ; $F7
    special_effect SE_SLIDE_MON_DOWN,            AnimationSlideMonDown            ; $F6
    special_effect SE_FLASH_MON_PIC,             AnimationFlashMonPic             ; $F5
    special_effect SE_SLIDE_MON_OFF,             AnimationSlideMonOff             ; $F4
    special_effect SE_BLINK_MON,                 AnimationBlinkMon                ; $F3
    special_effect SE_MOVE_MON_HORIZONTALLY,     AnimationMoveMonHorizontally     ; $F2
    special_effect SE_RESET_MON_POSITION,        AnimationResetMonPosition        ; $F1
    special_effect SE_LIGHT_SCREEN_PALETTE,      AnimationLightScreenPalette      ; $F0
    special_effect SE_HIDE_MON_PIC,              AnimationHideMonPic              ; $EF
    special_effect SE_SQUISH_MON_PIC,            AnimationSquishMonPic            ; $EE
    special_effect SE_SHOOT_BALLS_UPWARD,        AnimationShootBallsUpward        ; $ED
    special_effect SE_SHOOT_MANY_BALLS_UPWARD,   AnimationShootManyBallsUpward    ; $EC
    special_effect SE_BOUNCE_UP_AND_DOWN,        AnimationBoundUpAndDown          ; $EB
    special_effect SE_MINIMIZE_MON,              AnimationMinimizeMon             ; $EA
    special_effect SE_SLIDE_MON_DOWN_AND_HIDE,   AnimationSlideMonDownAndHide     ; $E9
    special_effect SE_TRANSFORM_MON,             AnimationTransformMon            ; $E8
    special_effect SE_LEAVES_FALLING,            AnimationLeavesFalling           ; $E7
    special_effect SE_PETALS_FALLING,            AnimationPetalsFalling           ; $E6
    special_effect SE_SLIDE_MON_HALF_OFF,        AnimationSlideMonHalfOff         ; $E5
    special_effect SE_SHAKE_ENEMY_HUD,           AnimationShakeEnemyHUD           ; $E4
    special_effect SE_SHAKE_ENEMY_HUD_2,         AnimationShakeEnemyHUD           ; $E3 unused
    special_effect SE_SPIRAL_BALLS_INWARD,       AnimationSpiralBallsInward       ; $E2
    special_effect SE_DELAY_ANIMATION_10,        AnimationDelay10                 ; $E1
    special_effect SE_FLASH_ENEMY_MON_PIC,       AnimationFlashEnemyMonPic        ; $E0 unused
    special_effect SE_HIDE_ENEMY_MON_PIC,        AnimationHideEnemyMonPic         ; $DF
    special_effect SE_BLINK_ENEMY_MON,           AnimationBlinkEnemyMon           ; $DE
    special_effect SE_SHOW_MON_PIC,              AnimationShowMonPic              ; $DD
    special_effect SE_SHOW_ENEMY_MON_PIC,        AnimationShowEnemyMonPic         ; $DC
    special_effect SE_SLIDE_ENEMY_MON_OFF,       AnimationSlideEnemyMonOff        ; $DB
    special_effect SE_SHAKE_BACK_AND_FORTH,      AnimationShakeBackAndForth       ; $DA
    special_effect SE_SUBSTITUTE_MON,            AnimationSubstitute              ; $D9
    special_effect SE_WAVY_SCREEN,               AnimationWavyScreen              ; $D8
    db -1 ; end

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
