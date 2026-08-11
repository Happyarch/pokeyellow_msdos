; battle_stubs.asm — battle front-end link stubs.
;
; CheckTargetSubstitute was stubbed here; it is now the faithful shared helper in
; move_effect_helpers.asm (the move-effect scaffold, deleted in chunk 17), so MoveHitTest's substitute
; check is real. JumpMoveEffect is live in effects.asm.
;
bits 32
section .text

; SaveTrainerName — pret engine/battle/save_trainer_name.asm:SaveTrainerName.
; Copies the engaged trainer class's display name (TrainerNamePointers[wTrainerClass-1])
; into wNameBuffer, which _TrainerNameText (TX_RAM wNameBuffer) then prints as the
; "<TRAINER>: " prefix of the end-battle text. The real body needs the Tier-1
; TrainerNamePointers name table (pret data/trainers/name_pointers.asm), not yet
; generated. Only caller: PrintEndBattleText (src/home/trainers.asm, M8.2) — which
; itself has no live driver until the trainer-header data generator lands, so this
; stub is never reached in the live build. While stubbed, wNameBuffer keeps its
; prior contents when the path is ever driven.
; STUB{label=SaveTrainerName; class=stub; pret=engine/battle/save_trainer_name.asm:SaveTrainerName; behavior=return without copying the trainer class name into wNameBuffer; evidence=label DB reports SaveTrainerName missing and TrainerNamePointers has no generated Tier-1 data; lifetime=until a gen_trainer_names generator emits TrainerNamePointers and the real body is ported}
global SaveTrainerName
SaveTrainerName:
    ret

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
