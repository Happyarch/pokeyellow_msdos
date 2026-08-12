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

; PrintSendOutMonMessage — pret engine/battle/common_text.asm:PrintSendOutMonMessage.
; Prints the send-out line, choosing among Go/DoIt/Getm/EnemysWeak/SoDo text by the
; enemy mon's remaining HP percentage ((curHP * 25) / (maxHP / 4)), and latches
; wLastSwitchInEnemyMonHP. The real body needs those five text streams as generated
; Tier-1 data (the two-tier rule forbids hand-encoding them here) plus the
; hMultiplicand/hDivisor Multiply/Divide plumbing. Restored as a call site by
; SendOutMon (plan item 1f); while stubbed the send-out prints no message and
; wLastSwitchInEnemyMonHP keeps its prior value.
; STUB{label=PrintSendOutMonMessage; class=stub; pret=engine/battle/common_text.asm:PrintSendOutMonMessage; behavior=return without printing the send-out message or latching wLastSwitchInEnemyMonHP; evidence=label DB reports PrintSendOutMonMessage missing and its five text streams have no generated Tier-1 asset; lifetime=until the send-out text is generated and the real body is ported under battle_completion 1d}
global PrintSendOutMonMessage
PrintSendOutMonMessage:
    ret

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
