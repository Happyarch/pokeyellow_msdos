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
; StarterPikachuBattleEntranceAnimation — STUB RETIRED 2026-08-23: the real routine
; now links from its pret mirror, src/engine/battle/pikachu_entrance_anim.asm.
; SendOutMon's starter-Pikachu branch draws the entrance for real.

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
