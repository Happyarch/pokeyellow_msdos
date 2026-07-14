; faint_sendout.asm — enemy (trainer) multi-mon send-out + trainer victory
; (battle-swarm-C). Faithful-core ports of pret engine/battle/core.asm:
;   EnemySendOut / EnemySendOutFirstMon (1315-1482), ReplaceFaintedEnemyMon (901),
;   TrainerBattleVictory (929).
; Graphics/audio/palette/link leaves are §2-allowlist stubbed (ANIMATION=OFF / audio
; HAL / palette HAL / TODO-HW link). The send-out STATE MACHINE is faithful: it scans
; the enemy party for the next live mon, loads it via LoadEnemyMonFromParty, and
; redraws the HUD. The battle-"shift" prompt (BIT_BATTLE_SHIFT → player may switch) is
; treated as SET mode (no prompt), which is faithful for the default option and avoids
; the unported SwitchPlayerMon.
;
; NOTE (verification): the DEBUG_BATTLE_TRAINER harness seeds only enemy party HP/status,
; not full structs, so a live send-out there loads a partially-seeded mon. The control
; flow matches pret and is correct once ReadTrainer populates wEnemyMons (real trainer
; init). See docs/translation_log.md.
;
; Register map (CLAUDE.md): A=AL; BC=BX; DE=EDX; HL=ESI; EBP=GB base, [ebp+addr].

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

; enemy-party struct aliases (pret wEnemyMon1* = wEnemyMons base + MON_* offsets)
%ifndef wEnemyMon1
wEnemyMon1       equ wEnemyMons
%endif
%ifndef wEnemyMon1Level
wEnemyMon1Level  equ (wEnemyMons + MON_LEVEL)
%endif

section .text

global EnemySendOut
global EnemySendOutFirstMon
global ReplaceFaintedEnemyMon
global TrainerBattleVictory

extern FlagAction                       ; ESI=array base, CL=index, BH=action
extern AddNTimes                        ; ESI=base, BX=stride, AL=count → ESI advanced
extern LoadEnemyMonFromParty            ; load wEnemyMons[wWhichPokemon] → enemy battle mon
extern PrintEmptyString
extern SaveScreenTilesToBuffer1
extern ClearSprites
extern DrawHUDsAndHPBars                ; redraw enemy + player HUD/HP bars
extern PrintBattleText                  ; EAX = flat battle-text stream
extern AddBCD                           ; ESI=src LSB, EDX=dst LSB, CL=byte count (BCD add)
extern MoneyForWinningText              ; battle_text.inc
extern RunPaletteCommand                ; faint_switch.asm (palette-HAL stub)

; ===========================================================================
; EnemySendOut — pret core.asm:1315. Player-exp bookkeeping, then send out the
; enemy's next live mon (faint path enters the .next scan with b=$ff).
; ===========================================================================
EnemySendOut:
    ; pret: clear then set the active player mon's gain-exp + fought flags, so the
    ; mon currently out earns EXP from the incoming enemy mon.
    mov byte [ebp + wPartyGainExpFlags], 0
    mov cl, [ebp + wPlayerMonNumber]
    mov esi, wPartyGainExpFlags
    mov bh, FLAG_SET
    call FlagAction
    mov byte [ebp + wPartyFoughtCurrentEnemyFlags], 0
    mov cl, [ebp + wPlayerMonNumber]
    mov esi, wPartyFoughtCurrentEnemyFlags
    mov bh, FLAG_SET
    call FlagAction
EnemySendOutFirstMon:
    ; clear enemy statuses (5 contiguous bytes) + disabled/minimized/used-move
    xor al, al
    mov [ebp + wEnemyStatsToDouble], al
    mov [ebp + wEnemyStatsToHalve], al
    mov [ebp + wEnemyBattleStatus1], al
    mov [ebp + wEnemyBattleStatus2], al
    mov [ebp + wEnemyBattleStatus3], al
    mov [ebp + wEnemyDisabledMove], al
    mov [ebp + wEnemyDisabledMoveNumber], al
    mov [ebp + wEnemyMonMinimized], al
    mov [ebp + wPlayerUsedMove], al
    mov [ebp + wEnemyUsedMove], al
    mov byte [ebp + wAICount], 0xFF             ; pret: dec a → $ff
    and byte [ebp + wPlayerBattleStatus1], (~(1 << USING_TRAPPING_MOVE)) & 0xFF
    ; ANIMATION=OFF: SlideTrainerPicOffScreen (trainer pic slide).
    call PrintEmptyString
    call SaveScreenTilesToBuffer1
    ; TODO-HW: link-battle received-switch index (Phase 4).
    ; --- find the next non-fainted enemy party mon (skip the current fainted slot) ---
.next:
    mov bh, 0xFF                                 ; b = $ff
.next2:
    inc bh
    mov al, [ebp + wEnemyMonPartyPos]
    cmp al, bh
    je  .next2                                   ; skip the current (fainted) slot
    mov al, bh                                   ; al = slot index (AddNTimes count)
    mov [ebp + wWhichPokemon], al
    mov esi, wEnemyMon1
    push ebx                                      ; preserve the loop counter (BH)
    mov bx, PARTYMON_STRUCT_LENGTH
    call AddNTimes                               ; esi -> this mon's struct (clobbers BX/AL)
    pop ebx
    inc esi                                      ; -> HP word
    mov al, [ebp + esi]
    or  al, [ebp + esi + 1]
    jz  .next2                                   ; fainted → try the next slot
.next3:
    ; wCurEnemyLevel = party-slot level
    mov al, [ebp + wWhichPokemon]
    mov esi, wEnemyMon1Level
    mov bx, PARTYMON_STRUCT_LENGTH
    call AddNTimes
    mov al, [ebp + esi]
    mov [ebp + wCurEnemyLevel], al
    ; wEnemyMonSpecies2 / wCurPartySpecies = enemy party species list[idx]
    mov al, [ebp + wWhichPokemon]
    inc al
    movzx ecx, al
    mov al, [ebp + wEnemyPartyCount + ecx]       ; wEnemyPartyCount+(idx+1) = species
    mov [ebp + wEnemyMonSpecies2], al
    mov [ebp + wCurPartySpecies], al
    call LoadEnemyMonFromParty                   ; sets wEnemyMonPartyPos, loads the struct
    mov byte [ebp + wCurrentMenuItem], 1         ; pret: default (no player switch)
    ; TODO(faithful): the BIT_BATTLE_SHIFT "TrainerAboutToUse / switch?" prompt +
    ; the party-menu path + SwitchPlayerMon. Treated as SET mode (no prompt).
.next4:
    call ClearSprites
    ; BUG(fixed): pret is `ld b, SET_PAL_BATTLE / call RunPaletteCommand`; the port set B
    ; not at all and dispatched on junk. See faint_switch.asm. Ledger M-72.
    mov bh, SET_PAL_BATTLE                        ; ld b, SET_PAL_BATTLE
    call RunPaletteCommand
    ; ANIMATION=OFF: TrainerSentOutText + LoadMonFrontSprite + AnimateSendingOutMon + PlayCry.
    call DrawHUDsAndHPBars                         ; ~ DrawEnemyHUDAndHPBar
    ; pret: `ld a,[wCurrentMenuItem]; and a; ret nz` — always nz here (we never prompt
    ; for a player switch), so the SwitchPlayerMon tail is unreachable and deferred.
    ret

; ===========================================================================
; ReplaceFaintedEnemyMon — pret core.asm:901. Palette/pokéball redraw (stubbed),
; then send out the next mon and reset the enemy move/AI bookkeeping. Returns ZF=0
; (single-player never "runs"; the ZF=1 → EnemyRan path is link-only).
; ===========================================================================
ReplaceFaintedEnemyMon:
    ; ANIMATION=OFF/palette: GetBattleHealthBarColor, OBP palettes, DrawEnemyPokeballs.
    ; TODO-HW: link-battle LinkBattleExchangeData → LINKBATTLE_RUN → ret z (EnemyRan).
    call EnemySendOut
    mov byte [ebp + wEnemyMoveNum], 0
    mov byte [ebp + wActionResultOrTookBattleTurn], 0
    mov byte [ebp + wAILayer2Encouragement], 0
    mov al, 1
    and al, al                                     ; ZF=0 → sent out (did not run)
    ret

; ===========================================================================
; TrainerBattleVictory — pret core.asm:929. Prize money + "defeated / money" text.
; Music, ScrollTrainerPicAfterBattle, PrintEndBattleText, and the gym-leader/rival
; music branches are deferred (audio/animation). wAmountMoneyWon was computed by
; ReadTrainer at battle start.
; ===========================================================================
TrainerBattleVictory:
    ; TODO-HW: PlayBattleVictoryMusic; ScrollTrainerPicAfterBattle; TrainerDefeatedText
    ; (TrainerDefeatedText is not yet in the generated battle_text.inc).
    mov eax, MoneyForWinningText
    call PrintBattleText
    ; win money: wPlayerMoney += wAmountMoneyWon (3-byte BCD). pret:
    ;   ld de, wPlayerMoney+2 / ld hl, wAmountMoneyWon+2 / ld c,3 / predef AddBCDPredef.
    ; Flat call to AddBCD (predef bank drop, §2 item 4): ESI=src LSB, EDX=dst LSB, CL=count.
    mov esi, wAmountMoneyWon + 2
    mov edx, W_PLAYER_MONEY + 2
    mov cl, 3
    call AddBCD
    mov byte [ebp + wBattleResult], 0              ; player won
    ret
