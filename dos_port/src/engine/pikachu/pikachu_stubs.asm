; pikachu_stubs.asm — engine/pikachu link stubs.
;
; Subsystem stub file for pret engine/pikachu/ labels whose bodies are deferred.
; Created 2026-08-11 for battle_completion plan item 1f (SendOutMon restoration).
;
; The two pikapic stand-ins (GetPikaPicAnimationScriptIndex,
; StarterPikachuEmotionCommand_pikapic) were RETIRED when the real bodies landed
; in src/engine/pikachu/pikachu_pic_animation.asm (follower Pikachu Phase 4).
;
bits 32
section .text

; BillsHouse_CheckPikachuEmotion — pret scripts/BillsHouse_2.asm:BillsHouse_CheckPikachuEmotion
; Script layer stub returning DL=0xFF (no map emotion).
global BillsHouse_CheckPikachuEmotion
BillsHouse_CheckPikachuEmotion:
    mov dl, 0xFF
    ret
