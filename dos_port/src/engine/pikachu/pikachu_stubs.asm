; pikachu_stubs.asm — engine/pikachu link stubs.
;
; Subsystem stub file for pret engine/pikachu/ labels whose bodies are deferred.
; Created 2026-08-11 for battle_completion plan item 1f (SendOutMon restoration).
;
bits 32
section .text

; IsPlayerPikachuAsleepInParty — pret
; engine/pikachu/pikachu_emotions.asm:IsPlayerPikachuAsleepInParty.
; Walks wPartySpecies for the starter Pikachu and returns CF=1 when that mon's
; status byte has SLP_MASK set. Its only restored caller is SendOutMon (plan item
; 1f), which uses the flag solely to pick between two Pikachu cry clips inside the
; starter-Pikachu branch. This stub returns CF=0 ("not asleep") rather than a bare
; ret, so the caller reads a defined flag instead of whatever the previous
; instruction left — the awake cry is also the correct answer for every party in
; which the starter Pikachu is not asleep.
; STUB{label=IsPlayerPikachuAsleepInParty; class=stub; pret=engine/pikachu/pikachu_emotions.asm:IsPlayerPikachuAsleepInParty; behavior=always reports the starter Pikachu as awake (CF=0) without scanning the party status bytes; evidence=label DB reports IsPlayerPikachuAsleepInParty missing and no port body exists; lifetime=until the pikachu_emotions party scan is ported}
global IsPlayerPikachuAsleepInParty
IsPlayerPikachuAsleepInParty:
    clc
    ret
