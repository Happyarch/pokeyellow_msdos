; battle_stubs.asm — battle front-end link stubs.
;
; CheckTargetSubstitute was stubbed here; it is now the faithful shared helper in
; move_effect_helpers.asm (the move-effect scaffold, deleted in chunk 17), so MoveHitTest's substitute
; check is real. JumpMoveEffect is live in effects.asm.
;
bits 32
section .text

; SaveTrainerName is now REAL (src/engine/battle/save_trainer_name.asm, its pret
; mirror) — no longer stubbed. Its stub's justification ("the Tier-1
; TrainerNamePointers name table ... not yet generated") was stale: the names are
; generated into assets/trainer_names.inc by gen_trainer_names.py.

; PrintSendOutMonMessage — STUB RETIRED 2026-08-18 (battle plan sendout messages).
; The real body is in its pret-mirrored home, src/engine/battle/common_text.asm,
; together with GoText, DoItText, GetmText, EnemysWeakText, and PrintPlayerMon1Text.


; StarterPikachuBattleEntranceAnimation — pret
; engine/battle/pikachu_entrance_anim.asm:StarterPikachuBattleEntranceAnimation.
; The Yellow starter-Pikachu send-out entrance, used instead of the POOF_ANIM +
; AnimateSendingOutMon pair when the sent-out mon is the starter Pikachu. Restored
; as a call site by SendOutMon (plan item 1f); while stubbed that branch draws no
; entrance animation, and the branch is only reachable once the starter Pikachu is
; the sent-out party mon.
; STUB{label=StarterPikachuBattleEntranceAnimation; class=stub; pret=engine/battle/pikachu_entrance_anim.asm:StarterPikachuBattleEntranceAnimation; behavior=return without drawing the starter-Pikachu battle entrance animation; evidence=label DB reports StarterPikachuBattleEntranceAnimation missing and no port body exists; lifetime=until the Yellow starter-Pikachu entrance is ported under battle_completion 4a}
global StarterPikachuBattleEntranceAnimation
StarterPikachuBattleEntranceAnimation:
    ret

; UseBagItem — STUB RETIRED 2026-08-12 (battle plan 2c). The real body is in its
; pret-mirrored home, src/engine/battle/core.asm, together with BagWasSelected,
; DisplayPlayerBag and DisplayBagMenu. It was added here by 2a purely so
; PartyMenuOrRockOrRun's safari-ROCK arm could keep pret's shape while the
; in-battle bag was unported; that arm now reaches the real routine.

; LinkBattleExchangeData — pret engine/battle/core.asm:LinkBattleExchangeData.
; The per-turn link-cable exchange: both sides swap their chosen action and the
; battle proceeds in lockstep.
;
; ADDED AS A STUB 2026-08-12 (battle plan 2b). ChooseNextMon calls it inside a
; `wLinkState == LINK_STATE_BATTLING` branch, and keeping pret's branch shape
; needs the label to resolve. Link play is entirely unported — there is no
; serial HAL — so the branch is unreachable in this port: wLinkState is 0 in
; single-player and nothing ever writes LINK_STATE_BATTLING.
; STUB{label=LinkBattleExchangeData; class=stub; pret=engine/battle/core.asm:LinkBattleExchangeData; behavior=return without exchanging any data with a peer so the link branch of ChooseNextMon does nothing; evidence=label DB reports LinkBattleExchangeData missing and the port has no serial link HAL at all so no code path sets wLinkState to LINK_STATE_BATTLING; lifetime=until link battles are ported, which no current plan schedules}
global LinkBattleExchangeData
LinkBattleExchangeData:
    ret
