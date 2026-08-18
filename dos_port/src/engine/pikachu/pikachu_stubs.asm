; pikachu_stubs.asm — engine/pikachu link stubs.
;
; Subsystem stub file for pret engine/pikachu/ labels whose bodies are deferred.
; Created 2026-08-11 for battle_completion plan item 1f (SendOutMon restoration).
;
bits 32
section .text

; GetPikaPicAnimationScriptIndex — pret engine/pikachu/pikachu_pic_animation.asm:GetPikaPicAnimationScriptIndex
; STUB{class=stub; label=GetPikaPicAnimationScriptIndex; pret=engine/pikachu/pikachu_pic_animation.asm:GetPikaPicAnimationScriptIndex; behavior=returns default emotion index 1; evidence=Phase 4 front-pic facial animation engine is deferred; lifetime=retire when Phase 4 pikachu_pic_animation.asm lands}
global GetPikaPicAnimationScriptIndex
GetPikaPicAnimationScriptIndex:
    mov al, 1
    ret

; StarterPikachuEmotionCommand_pikapic — pret engine/pikachu/pikachu_pic_animation.asm:StarterPikachuEmotionCommand_pikapic
; STUB{class=stub; label=StarterPikachuEmotionCommand_pikapic; pret=engine/pikachu/pikachu_pic_animation.asm:StarterPikachuEmotionCommand_pikapic; behavior=advances script pointer past argument byte; evidence=Phase 4 front-pic facial animation engine is deferred; lifetime=retire when Phase 4 pikachu_pic_animation.asm lands}
global StarterPikachuEmotionCommand_pikapic
StarterPikachuEmotionCommand_pikapic:
    inc edx
    ret

; BillsHouse_CheckPikachuEmotion — pret scripts/BillsHouse_2.asm:BillsHouse_CheckPikachuEmotion
; Script layer stub returning DL=0xFF (no map emotion).
global BillsHouse_CheckPikachuEmotion
BillsHouse_CheckPikachuEmotion:
    mov dl, 0xFF
    ret
