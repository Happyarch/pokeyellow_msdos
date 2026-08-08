; core_stubs.asm — link-time stubs for the faithful core.asm battle loop.
;
; core.asm is a structure-for-structure translation of pret's engine/battle/core.asm.
; A few of its backend calls reach into closures that are NOT link-ready yet (they
; depend on a large set of still-deferred predefs / UI / text — which is exactly why
; BATTLE_SRCS is check-only, not linked). Until those closures are ported wave-by-wave,
; the calls resolve to the faithful-behaviour stubs below, each matching a TODO(faithful)
; marker already present in core.asm. The battle loop itself (menu, move select, speed-
; ordered turns, damage, faint, EXP, run) is fully faithful and live.
;
; Register map: A=AL, BC=BX (B=BH), DE=EDX, HL/ESI, EBP = GB base; GB mem = [EBP+addr].
%include "gb_memmap.inc"
%include "gb_constants.inc"

bits 32
section .text

global FormatMovesString
; TrainerAI is now LIVE in trainer_ai.asm (class-based move/item/switch AI; pret
; engine/battle/trainer_ai.asm) — its stub here was removed when trainer_ai.asm
; linked into the EXE (battle-swarm-C: SelectEnemyMove→AIEnemyTrainerChooseMoves wiring).
; HandlePoisonBurnLeechSeed is now LIVE in residual_damage.asm (poison/burn/Leech Seed
; end-of-round residual; pret engine/battle/core.asm:479) — its stub here was removed
; when residual_damage.asm linked into the EXE.
; JumpMoveEffect is now LIVE in effects.asm (MoveEffectPointerTable dispatch) — its
; stub here was removed when the move-effect scaffold linked effects.asm into the EXE.

extern FindMoveName              ; battle_menu.asm — AL = move id → EAX = flat name ptr

; ---------------------------------------------------------------------------
; FormatMovesString — faithful copy of misc.asm:FormatMovesString OUTPUT: walk wMoves,
; emit each move's name with a 0x4E (<NEXT>) separator, a '-' (0xE3) for each empty slot,
; a 0x50 ('@') terminator, and record wNumMovesMinusOne. Names are resolved via the flat
; MoveNames walk (FindMoveName) rather than GetName, because GetName/names.asm is not yet
; link-ready (TrainerNames is undefined). The produced string — and the '-' empty-slot
; placeholder the user flagged — is byte-identical to the faithful routine's.
; (NOTE: '-' is the charmap tile 0xE3; misc.asm's `mov al,'-'` would assemble to ASCII
; 0x2D in NASM — a latent port bug in that never-linked file. We emit 0xE3 here.)
; In: wMoves seeded (core.asm copies wBattleMonMoves → wMoves first). EBP = GB base.
; ---------------------------------------------------------------------------
FormatMovesString:
    mov esi, wMoves
    mov edx, wMovesString
    xor bh, bh                          ; bh = slot counter
.nameLoop:
    mov al, [ebp + esi]
    inc esi
    test al, al
    jz .dashLoop                        ; 0 → empty slot (and all remaining)
    push esi
    push edx                            ; FindMoveName clobbers DL — preserve the dest cursor
    call FindMoveName                   ; AL=id → EAX = flat name ptr ('@'-terminated)
    pop edx
    mov esi, eax
.copyName:
    mov al, [esi]                       ; flat read
    inc esi
    cmp al, 0x50                        ; '@'
    jz .doneName
    mov [ebp + edx], al
    inc edx
    jmp .copyName
.doneName:
    mov [ebp + wNumMovesMinusOne], bh
    inc bh
    mov byte [ebp + edx], 0x4E          ; <NEXT>
    inc edx
    pop esi
    cmp bh, NUM_MOVES
    jz .done
    jmp .nameLoop
.dashLoop:
    mov byte [ebp + edx], 0xE3          ; '-' (charmap dash tile)
    inc edx
    inc bh
    cmp bh, NUM_MOVES
    jz .done
    mov byte [ebp + edx], 0x4E          ; <NEXT>
    inc edx
    jmp .dashLoop
.done:
    mov byte [ebp + edx], 0x50          ; '@'
    ret

; ===========================================================================
; ExecutePlayerMove/ExecuteEnemyMove special-move leaves — NOW FAITHFULLY PORTED
; (battle-swarm-A). Each is its own file under src/engine/battle/; core.asm's
; `extern` declarations resolve to them:
;   PrintGhostText / IsGhostBattle .......... ghost.asm
;   HandleCounterMove ....................... counter.asm
;   MirrorMoveCopyMove / ReloadMoveData ..... mirror_move.asm
;   MetronomePickMove ....................... metronome.asm
;   PrintCriticalOHKOText ................... print_critical_ohko.asm
;   DisplayEffectiveness .................... display_effectiveness.asm
;   PrintMoveFailureText .................... print_move_failure.asm
;   HandleExplodingAnimation ................ exploding_animation.asm
; The stubs that used to live here are deleted.
; ===========================================================================
; PredefShakeScreenHorizontally: RETIRED 2026-08-08 — real body in the mirror
; src/engine/gfx/screen_effects.asm (battle_animations Stage 3b), which also
; adds the previously-missing PredefShakeScreenVertically. Its TODO-HW ("real
; horizontal screen shake, rWX/rSCX manipulation") is discharged: the shake is
; a whole-canvas H_SCX/H_SCY displacement. PrintMoveFailureText's Jump Kick /
; Hi Jump Kick crash path now gets a real shake.

; ===========================================================================
; Move-subanimation dispatchers: RETIRED 2026-08-08 (battle_animations Stage 2b).
; PlayCurrentMoveAnimation(2)/PlayBattleAnimation(2)/PlayBattleAnimationGotID now
; live as real pret bodies in effects.asm, wired to animations.asm:MoveAnimation.
; The 2026-08-08 wiring crash was NOT in the interpreter: the port's <DONE> text
; sentinel lived at GB $C0F0/$C0F1 = wAudioSavedROMBank/wFrequencyModifier, and
; GetMoveSound's first-ever freq-modifier write destroyed the terminator (fixed:
; flat .data sentinel in src/home/text.asm; see memory
; regression-battle-anim-interp-runtime-crash).
; ===========================================================================

; STUB{class=temporary; label=AnimationSubstitute; pret=engine/battle/animations.asm:AnimationSubstitute; behavior=leave the mon pic unchanged instead of slide-out plus Substitute doll draw; evidence=no Substitute pic support in the port yet, callers in substitute.asm run the faithful state changes around it; lifetime=until Substitute pic VRAM support lands}
global AnimationSubstitute
AnimationSubstitute:
    ret

; STUB{class=temporary; label=AnimationTransformMon; pret=engine/battle/animations.asm:AnimationTransformMon; behavior=leave the mon pic unchanged instead of redrawing as the transformed species; evidence=no battle pic reload path for Transform yet, transform.asm runs the faithful stat/move copies around it; lifetime=until the Transform pic reload lands}
global AnimationTransformMon
AnimationTransformMon:
    ret

; STUB{class=temporary; label=HideSubstituteShowMonAnim; pret=engine/battle/animations.asm:HideSubstituteShowMonAnim; behavior=leave the pics unchanged instead of swapping the Substitute doll pic for the mon pic; evidence=no Substitute pic support in the port yet; lifetime=until Substitute pic VRAM support lands}
global HideSubstituteShowMonAnim
HideSubstituteShowMonAnim:
    ret

; STUB{class=temporary; label=ReshowSubstituteAnim; pret=engine/battle/animations.asm:ReshowSubstituteAnim; behavior=leave the pics unchanged instead of restoring the Substitute doll pic; evidence=no Substitute pic support in the port yet; lifetime=until Substitute pic VRAM support lands}
global ReshowSubstituteAnim
ReshowSubstituteAnim:
    ret

; STUB{class=temporary; label=SlideDownFaintedMonPic; pret=engine/battle/core.asm:SlideDownFaintedMonPic; behavior=return immediately instead of sliding the fainted mon pic off the screen row by row; evidence=ANIMATION=OFF layer, the HP bar has already drained to 0 in the faithful damage path (faint_switch.asm/faint_enemy.asm callers); lifetime=until the ANIMATION=OFF faint slide lands}
global SlideDownFaintedMonPic
SlideDownFaintedMonPic:
    ret

; ===========================================================================
; Battle-animation dispatch-target link stubs (battle_animations Stage 2).
; The interpreter core (src/engine/battle/animations.asm) links its hand-written
; dd tables SpecialEffectPointers / AnimationIdSpecialEffects and MoveAnimation
; against these; each real body lands in Stages 3-5 (trade = Phase 4). Retire
; each entry here when its owning stage ports the real routine.
; ===========================================================================
; --- Stage 3: screen / palette / flash / shake / wavy ---
; SetAnimationPalette: RETIRED 2026-08-08 — real body in animations.asm (pulled
; forward from Stage 3: the stub left wAnimPalette/OBP0/OBP1 uninitialized, so
; live animation particles rendered in wrong colors — maintainer-observed on
; the GUST demo).

; AnimationFlashScreen, AnimationFlashScreenLong, AnimationDarkScreenPalette,
; AnimationDarkenMonPalette, AnimationLightScreenPalette,
; AnimationResetScreenPalette: RETIRED 2026-08-08 — real bodies in
; animations.asm (Stage 3 flash/palette family), together with
; SetAnimationBGPalette, FlashScreenLongDelay, the FlashScreenLong* tables and
; the unreferenced AnimationUnusedPalette1-4 / FlashScreenUnused.

; STUB{class=temporary; label=AnimationFlashMonPic; pret=engine/battle/animations.asm:AnimationFlashMonPic; behavior=return instead of flashing the mon pic palette; evidence=real body arrives in a later battle-animations stage, the interpreter is faithful without it and offscreen anim OAM stays hidden by g_obj_clip; lifetime=until Stage 3 flash family lands}
global AnimationFlashMonPic
AnimationFlashMonPic:
    ret

; STUB{class=temporary; label=AnimationFlashEnemyMonPic; pret=engine/battle/animations.asm:AnimationFlashEnemyMonPic; behavior=return instead of flashing the enemy mon pic palette; evidence=real body arrives in a later battle-animations stage, the interpreter is faithful without it and offscreen anim OAM stays hidden by g_obj_clip; lifetime=until Stage 3 flash family lands}
global AnimationFlashEnemyMonPic
AnimationFlashEnemyMonPic:
    ret

; AnimationShakeScreen, AnimationBlinkEnemyMon: RETIRED 2026-08-08 — real bodies
; in animations.asm (Stage 3b shake family / blink wrapper chain), along with
; AnimationShakeScreen{Vertically,HorizontallyFast,HorizontallySlow},
; AnimationUnusedShakeScreen, the ShakeScreen* wrappers, BlinkEnemyMonSprite and
; the AnimationTypePointerTable dispatch.

; AnimationWavyScreen: RETIRED 2026-08-08 — real body in animations.asm, driving
; the per-row displacement HAL (g_row_xoff / g_row_xoff_on) added to ppu.asm in
; Stage 3c, together with WavyScreen_SetSCX and WavyScreenLineOffsets.

; FlashScreenEveryFourFrameBlocks, FlashScreenEveryEightFrameBlocks:
; RETIRED 2026-08-08 — real bodies in animations.asm (Stage 3 flash family).

; --- Stage 4: mon-pic slides + motion + OAM particles + HUD shake ---
; AnimationLeavesFalling, AnimationPetalsFalling,
; AnimationWaterDropletsEverywhere: RETIRED 2026-08-08 — real bodies in
; animations.asm (Stage 4f), with AnimationFallingObjects, the four
; FallingObjects_* helpers, their three data tables and _AnimationWaterDroplets.

; AnimationSpiralBallsInward, AnimationShootBallsUpward,
; AnimationShootManyBallsUpward: RETIRED 2026-08-08 — real bodies in
; animations.asm (Stage 4e ball particles), with _AnimationShootBallsUpward,
; BattleAnimWriteOAMEntry, InitMultipleObjectsOAM and their coordinate tables.

; AnimationMinimizeMon, AnimationSlideMonDownAndHide: RETIRED 2026-08-08 —
; real bodies in animations.asm (Stage 4d), with MinimizedMonSprite and
; CopyTempPicToMonPic (pulled forward from Stage 5 because both end in it).

; AnimationShakeBackAndForth, AnimationMoveMonHorizontally,
; AnimationResetMonPosition, AnimationSquishMonPic, AnimationBoundUpAndDown:
; RETIRED 2026-08-08 — real bodies in animations.asm (Stage 4c motion family),
; with _AnimationSquishMonPic. AnimationMinimizeMon stays stubbed below: its
; body needs wTempPic + CopyTempPicToMonPic.

; AnimationSlideMonUp, AnimationSlideMonDown, AnimationSlideMonOff,
; AnimationSlideMonHalfOff, AnimationSlideEnemyMonOff: RETIRED 2026-08-08 —
; real bodies in animations.asm (Stage 4b), with _AnimationSlideMonUp and
; _AnimationSlideMonOff. AnimationSlideMonDownAndHide stays stubbed below: its
; tail calls CopyTempPicToMonPic, which is Stage 5.

; AnimationHideMonPic, AnimationHideEnemyMonPic, AnimationShowMonPic,
; AnimationShowEnemyMonPic, AnimationBlinkMon: RETIRED 2026-08-08 — real bodies
; in animations.asm (Stage 4 mon-pic tilemap helpers), along with
; ClearMonPicFromTileMap, GetMonSpriteTileMapPointerFromRowCount, GetTileIDList,
; AnimCopyRowLeft/Right, CopyPicTiles, CopyDownscaledMonTiles,
; CopyTileIDs{,_NoBGTransfer} and CopyTileIDsFromList.

; STUB{class=temporary; label=AnimationShakeEnemyHUD; pret=engine/battle/animations.asm:AnimationShakeEnemyHUD; behavior=return instead of shaking the enemy HUD; evidence=real body arrives in a later battle-animations stage, the interpreter is faithful without it and offscreen anim OAM stays hidden by g_obj_clip; lifetime=until Stage 4 HUD shake lands}
global AnimationShakeEnemyHUD
AnimationShakeEnemyHUD:
    ret

; STUB{class=temporary; label=TailWhipAnimationUnused; pret=engine/battle/animations.asm:TailWhipAnimationUnused; behavior=return instead of the unused Tail Whip effect; evidence=real body arrives in a later battle-animations stage, the interpreter is faithful without it and offscreen anim OAM stays hidden by g_obj_clip; lifetime=until Stage 4 particle family lands}
global TailWhipAnimationUnused
TailWhipAnimationUnused:
    ret

; --- Stage 5: item-path ball toss/shake/poof + per-anim SE hooks ---
; STUB{class=temporary; label=TossBallAnimation; pret=engine/battle/animations.asm:TossBallAnimation; behavior=return instead of the Poke Ball toss animation sequence; evidence=real body arrives in a later battle-animations stage, the interpreter is faithful without it and offscreen anim OAM stays hidden by g_obj_clip; lifetime=until Stage 5 item-path ball animations land}
global TossBallAnimation
TossBallAnimation:
    ret

; STUB{class=temporary; label=DoBallTossSpecialEffects; pret=engine/battle/animations.asm:DoBallTossSpecialEffects; behavior=return instead of the ball-toss per-frame special effects; evidence=real body arrives in a later battle-animations stage, the interpreter is faithful without it and offscreen anim OAM stays hidden by g_obj_clip; lifetime=until Stage 5 item-path ball animations land}
global DoBallTossSpecialEffects
DoBallTossSpecialEffects:
    ret

; STUB{class=temporary; label=DoBallShakeSpecialEffects; pret=engine/battle/animations.asm:DoBallShakeSpecialEffects; behavior=return instead of the ball-shake per-frame special effects; evidence=real body arrives in a later battle-animations stage, the interpreter is faithful without it and offscreen anim OAM stays hidden by g_obj_clip; lifetime=until Stage 5 item-path ball animations land}
global DoBallShakeSpecialEffects
DoBallShakeSpecialEffects:
    ret

; STUB{class=temporary; label=DoPoofSpecialEffects; pret=engine/battle/animations.asm:DoPoofSpecialEffects; behavior=return instead of the poof per-frame special effects; evidence=real body arrives in a later battle-animations stage, the interpreter is faithful without it and offscreen anim OAM stays hidden by g_obj_clip; lifetime=until Stage 5 item-path ball animations land}
global DoPoofSpecialEffects
DoPoofSpecialEffects:
    ret

; STUB{class=temporary; label=DoGrowlSpecialEffects; pret=engine/battle/animations.asm:DoGrowlSpecialEffects; behavior=return instead of the Growl per-frame special effects; evidence=real body arrives in a later battle-animations stage, the interpreter is faithful without it and offscreen anim OAM stays hidden by g_obj_clip; lifetime=until Stage 5 per-anim hooks land}
global DoGrowlSpecialEffects
DoGrowlSpecialEffects:
    ret

; STUB{class=temporary; label=DoRockSlideSpecialEffects; pret=engine/battle/animations.asm:DoRockSlideSpecialEffects; behavior=return instead of the Rock Slide per-frame special effects; evidence=real body arrives in a later battle-animations stage, the interpreter is faithful without it and offscreen anim OAM stays hidden by g_obj_clip; lifetime=until Stage 5 per-anim hooks land}
global DoRockSlideSpecialEffects
DoRockSlideSpecialEffects:
    ret

; STUB{class=temporary; label=DoExplodeSpecialEffects; pret=engine/battle/animations.asm:DoExplodeSpecialEffects; behavior=return instead of the Explosion per-frame special effects; evidence=real body arrives in a later battle-animations stage, the interpreter is faithful without it and offscreen anim OAM stays hidden by g_obj_clip; lifetime=until Stage 5 per-anim hooks land}
global DoExplodeSpecialEffects
DoExplodeSpecialEffects:
    ret

; STUB{class=temporary; label=DoBlizzardSpecialEffects; pret=engine/battle/animations.asm:DoBlizzardSpecialEffects; behavior=return instead of the Blizzard per-frame special effects; evidence=real body arrives in a later battle-animations stage, the interpreter is faithful without it and offscreen anim OAM stays hidden by g_obj_clip; lifetime=until Stage 5 per-anim hooks land}
global DoBlizzardSpecialEffects
DoBlizzardSpecialEffects:
    ret

; --- Phase 4 (out of scope): trade-animation consumers ---
; STUB{class=stub; label=TradeHidePokemon; pret=engine/battle/animations.asm:TradeHidePokemon; behavior=return instead of hiding the traded mon pic; evidence=real body arrives in a later battle-animations stage, the interpreter is faithful without it and offscreen anim OAM stays hidden by g_obj_clip; lifetime=until the Phase 4 trade animation engine lands}
global TradeHidePokemon
TradeHidePokemon:
    ret

; STUB{class=stub; label=TradeShakePokeball; pret=engine/battle/animations.asm:TradeShakePokeball; behavior=return instead of shaking the trade Poke Ball; evidence=real body arrives in a later battle-animations stage, the interpreter is faithful without it and offscreen anim OAM stays hidden by g_obj_clip; lifetime=until the Phase 4 trade animation engine lands}
global TradeShakePokeball
TradeShakePokeball:
    ret

; STUB{class=stub; label=TradeJumpPokeball; pret=engine/battle/animations.asm:TradeJumpPokeball; behavior=return instead of the trade Poke Ball jump; evidence=real body arrives in a later battle-animations stage, the interpreter is faithful without it and offscreen anim OAM stays hidden by g_obj_clip; lifetime=until the Phase 4 trade animation engine lands}
global TradeJumpPokeball
TradeJumpPokeball:
    ret

