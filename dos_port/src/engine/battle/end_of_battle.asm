; end_of_battle.asm — EndOfBattle (post-battle cleanup + evolution hook).
;
; Faithful port of pret engine/battle/end_of_battle.asm:EndOfBattle. Runs after
; the battle loop returns (pret calls it via `callfar EndOfBattle` in
; _InitBattleCommon, right after StartBattle). Its job: on a win, award Pay Day
; money and run post-battle evolutions; then reset all the battle WRAM state and
; white out on the way back to the overworld.
;
; current_plan_pokemon_behavior.md Stage 5: this is the wire that connects the
; (already-linked) EvolutionAfterBattle to the end of a battle — win → GainExperience
; level-up sets wCanEvolveFlags → EndOfBattle clears wForceEvolution and calls
; EvolutionAfterBattle → the eligible party mons evolve.
;
; Deferred boundaries (marked inline):
;   - Link-battle presentation (versus box + YOU WIN/LOSE/DRAW): no networking in
;     the port (Phase 4). wLinkState is never LINK_STATE_BATTLING here.
;   - Pay Day award (predef AddBCDPredef → wPlayerMoney; PickUpPayDayMoneyText):
;     AddBCDPredef unlinked + text not generated. The Pay Day move can't set
;     wTotalPayDayMoney yet, so this branch is never taken; kept structurally.
;   - WaitForSoundToFinish: audio HAL (Phase 3).
;
; Register map (CLAUDE.md): A=AL; BC=BX; DE=EDX; HL=ESI; EBP=GB base, [ebp+addr].
;
; Build: nasm -f coff -I include/ -I . -o end_of_battle.o end_of_battle.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

section .text

global EndOfBattle

extern EvolutionAfterBattle              ; evolution.asm — walks party, evolves eligible mons
extern UpdatePikachuMoodAfterBattle      ; pikachu_status.asm — raises starter Pikachu mood (DH=$82)
extern GBPalWhiteOut                     ; home/fade.asm — fade to white on the way out

EndOfBattle:
    mov al, [ebp + wLinkState]
    cmp al, LINK_STATE_BATTLING
    jne .notLinkBattle
    ; --- link battle ---
    ; TODO-HW: network/link battle presentation (Phase 4). Pret copies the enemy
    ; mon status into wEnemyMon1Status, RunPaletteCommand SET_PAL_OVERWORLD,
    ; DisplayLinkBattleVersusTextBox, places "YOU WIN/LOSE/DRAW", DelayFrames(200).
    ; The port has no networking, so this branch is unreachable; if it is ever
    ; entered, fall through to evolution to stay faithful.
    jmp .evolution

.notLinkBattle:
    mov al, [ebp + wBattleResult]
    and al, al
    jnz .resetVariables                  ; lost/drew → no Pay Day, no evolution

    ; Pay Day money (3-byte BCD running total). 0 in every port battle so far.
    mov esi, wTotalPayDayMoney
    mov al, [ebp + esi]
    inc esi
    or al, [ebp + esi]
    inc esi
    or al, [ebp + esi]
    jz .evolution                        ; pay day money 0 → skip the award
    ; TODO-HW: award Pay Day — predef AddBCDPredef (DE=wPlayerMoney+2, C=3) then
    ; PrintText PickUpPayDayMoneyText. Deferred: AddBCDPredef unlinked +
    ; PickUpPayDayMoneyText not generated. Falls through to evolution.

.evolution:
    xor al, al
    mov [ebp + wForceEvolution], al      ; not a forced (stone) evolution
    call EvolutionAfterBattle            ; pret: predef EvolutionAfterBattle
    mov dh, 0x82                         ; pret: ld d, $82
    call UpdatePikachuMoodAfterBattle    ; pret: callfar UpdatePikachuMoodAfterBattle

.resetVariables:
    xor al, al
    mov [ebp + wLowHealthAlarm], al                   ; disable low-health alarm
    mov [ebp + wChannelSoundIDs + CHAN5], al
    mov [ebp + wIsInBattle], al
    mov [ebp + wBattleType], al
    mov [ebp + wMoveMissed], al
    mov [ebp + wCurOpponent], al
    mov [ebp + wForcePlayerToChooseMon], al
    mov [ebp + wNumRunAttempts], al
    mov [ebp + wEscapedFromBattle], al
    mov esi, wPartyAndBillsPCSavedMenuItem
    mov [ebp + esi], al                               ; 4-byte block (pret: ld [hli] x4)
    mov [ebp + esi + 1], al
    mov [ebp + esi + 2], al
    mov [ebp + esi + 3], al
    mov [ebp + wListScrollOffset], al
    ; clear the wBattleStatusData block (AL still 0)
    mov esi, wBattleStatusData
    mov ecx, wBattleStatusDataEnd - wBattleStatusData
.loop:
    mov [ebp + esi], al
    inc esi
    dec ecx
    jnz .loop
    ; arm the wild-encounter cooldown so a step doesn't immediately re-trigger
    mov esi, wStatusFlags2
    or byte [ebp + esi], (1 << BIT_WILD_ENCOUNTER_COOLDOWN)
    ; TODO-HW: WaitForSoundToFinish (audio HAL, Phase 3)
    call GBPalWhiteOut
    mov byte [ebp + wDestinationWarpID], 0xFF         ; don't reposition on map re-entry
    ret
