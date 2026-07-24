; battle_stubs.asm — battle front-end link stubs.
;
; CheckTargetSubstitute was stubbed here; it is now the faithful shared helper in
; move_effect_helpers.asm (the move-effect scaffold), so MoveHitTest's substitute
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
