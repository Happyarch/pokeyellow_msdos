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
;   (The Pay Day award used to be listed here as deferred, on three claims that
;   were EACH measurably false by 2026-08-11: AddBCDPredef is translated
;   (src/engine/math/bcd.asm), PickUpPayDayMoneyText IS generated
;   (assets/battle_text.inc), and PayDayEffect_ does accumulate into
;   wTotalPayDayMoney (move_effects/pay_day.asm). It is implemented below.)
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

extern AddBCD                            ; engine/math/bcd.asm — predef AddBCDPredef's body
extern PickUpPayDayMoneyText             ; assets/battle_text.inc (generated Tier-1)
extern PrintText                         ; src/home/window.asm
extern EvolutionAfterBattle              ; evos_moves.asm — walks party, evolves eligible mons
extern UpdatePikachuMoodAfterBattle      ; pikachu_status.asm — raises starter Pikachu mood (DH=$82)
extern GBPalWhiteOut                     ; src/home/palettes.asm — fade to white on the way out

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
    ; Award it. ESI is already wTotalPayDayMoney + 2 from the or-chain above,
    ; exactly as pret's HL is — AddBCD walks both pointers DOWNWARD by C bytes,
    ; so source and destination both start at their array's least-significant
    ; byte. Big-endian GB money, 3-byte BCD.
    ; DEVIATION{class=HAL; pret=engine/battle/end_of_battle.asm:EndOfBattle; behavior=calls AddBCD directly where pret runs predef AddBCDPredef; evidence=AddBCDPredef in the port is GetPredefRegisters falling through to AddBCD and the port has no predef dispatcher staging wPredefHL-DE-BC for this site so GetPredefRegisters would load stale registers over the live ones, the same convention pay_day.asm and ReadTrainer already use; lifetime=permanent, the port calls predef targets directly}
    mov edx, wPlayerMoney + 2            ; ld de, wPlayerMoney + 2
    mov cl, 3                            ; ld c, $3
    call AddBCD                          ; predef AddBCDPredef
    mov esi, PickUpPayDayMoneyText       ; ld hl, PickUpPayDayMoneyText
    call PrintText

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
    ; DEVIATION{class=projection; pret=engine/battle/end_of_battle.asm:EndOfBattle; behavior=additionally clears wFontLoaded BIT_FONT_LOADED at battle teardown, which pret does not do here; evidence=the port-only battle entry (init_battle.asm InitBattleCommon and InitWildBattle) sets the bit for its 40x25 battle canvas font load - pret never sets it outside DisplayTextIDInit - and nothing on the exit path cleared it, so after every battle UpdateNPCSprite's pret-faithful font freeze kept ALL NPC ticks (facing re-assert, InitializeSpriteScreenPosition snap, movement) suspended until an unrelated text open/close cycle, measured live 2026-08-06 as wFontLoaded=01 post-battle with NPC screen coords frozen stale for 7000+ frames (regression-battle-second-trainer-wont-engage); lifetime=permanent while the battle canvas sets the bit on entry, retire together with those setters if the canvas stops sharing vFont}
    and byte [ebp + wFontLoaded], ~(1 << BIT_FONT_LOADED) & 0xFF
    ; TODO-HW: WaitForSoundToFinish (audio HAL, Phase 3)
    call GBPalWhiteOut
    mov byte [ebp + wDestinationWarpID], 0xFF         ; don't reposition on map re-entry
    ret
