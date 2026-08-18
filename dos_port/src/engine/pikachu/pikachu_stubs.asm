; pikachu_stubs.asm — engine/pikachu link stubs.
;
; Subsystem stub file for pret engine/pikachu/ labels whose bodies are deferred.
; Created 2026-08-11 for battle_completion plan item 1f (SendOutMon restoration).
;
bits 32
section .text


; PikachuWalksToNurseJoy — pret engine/pikachu/pikachu_emotions.asm:415
; TODO(follower_pikachu plan): replace with the real body. It sets
; hPikachuSpriteVRAMOffset = $40, loads the follower's sprite into VRAM, computes
; movement data from wSpritePikachuStateData2MapY/MapX and applies it via
; ApplyPikachuMovementData — all of which belong to the follower subsystem, whose
; plan (docs/current_plan_follower_pikachu.md) owns ApplyPikachuMovementData_ and
; the follow FSM. Reached: yes, from DisplayPokemonCenterDialogue_
; (src/engine/events/pokecenter.asm), which is linked as of the overworld-services
; chunk 2. Returns nothing its caller reads — pret's call site is a bare
; `callfar` that falls through — so a ret is a faithful no-op here, and the only
; visible consequence is that the follower does not walk to the nurse.
; STUB{class=stub; label=PikachuWalksToNurseJoy; pret=engine/pikachu/pikachu_emotions.asm:PikachuWalksToNurseJoy; behavior=returns immediately so the follower Pikachu does not walk to Nurse Joy during the heal cutscene, the heal itself is unaffected; evidence=the real body drives the follower movement FSM and ApplyPikachuMovementData which are unported and owned by the follower_pikachu plan, and pret's caller uses a bare callfar whose return value and flags are never read; lifetime=retire when the follower_pikachu plan lands ApplyPikachuMovementData_ and the follow FSM}
global PikachuWalksToNurseJoy
PikachuWalksToNurseJoy:
    ret

; StarterPikachuEmotionCommand_turnawayfromplayer — pret engine/pikachu/pikachu_emotions.asm:StarterPikachuEmotionCommand_turnawayfromplayer
; TODO(follower_pikachu plan Phase 3): replace with the real body in pikachu_emotions.asm.
; STUB{class=stub; label=StarterPikachuEmotionCommand_turnawayfromplayer; pret=engine/pikachu/pikachu_emotions.asm:StarterPikachuEmotionCommand_turnawayfromplayer; behavior=returns immediately so Pikachu does not turn away from player during map checks; evidence=real body is in pikachu_emotions.asm which is unported and owned by Phase 3 of follower_pikachu plan, callers in pikachu_movement.asm do not read return values or flags; lifetime=retire when follower_pikachu plan Phase 3 lands pikachu_emotions.asm}
global StarterPikachuEmotionCommand_turnawayfromplayer
StarterPikachuEmotionCommand_turnawayfromplayer:
    ret

