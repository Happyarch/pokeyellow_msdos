; faint_switch.asm — player-side faint / forced-switch lifecycle (battle-swarm-C).
;
; Faithful ports of pret engine/battle/core.asm player-faint routines, with the
; graphics/audio/palette leaves stubbed per the §2 allowlist (ANIMATION=OFF / audio
; HAL / palette HAL). The switch-in STATE MACHINE is faithful; the one deferral is the
; interactive mon-picker: pret's in-battle BATTLE_PARTY_MENU is not yet ported (the
; port's DisplayPartyMenu is the divergent overworld menu that permits CANCEL — wrong
; for a forced switch), so ChooseNextMon auto-selects the first live party mon as a
; functional stand-in until the BattlePartyMenu sub-UI lands.
;
; Register map (CLAUDE.md): A=AL; BC=BX; DE=EDX; HL=ESI; EBP=GB base, [ebp+addr].
;
; Build: nasm -f coff -I include/ -I . -o faint_switch.o faint_switch.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

; wPartyMon1HP = wPartyMon1 + MON_HP (not aliased in the includes).
wPartyMon1HP    equ (wPartyMon1 + MON_HP)

section .text

; --- routines owned here ---
global HasMonFainted
global RemoveFaintedPlayerMon
global DoUseNextMonDialogue
global ChooseNextMon
global SendOutMon
global HandlePlayerBlackOut
global EnemyRan
; --- ANIMATION=OFF / palette-HAL stubs (consumed by the enemy-faint file too) ---
global SlideDownFaintedMonPic
global RunPaletteCommand

; --- externs ---
extern FlagAction                       ; flag_action.asm — ESI=array base, CL=index, BH=action
extern LoadBattleMonFromParty           ; faint_leaves.asm — party[wWhichPokemon] → battle mon
extern AnyPartyAlive                    ; wild_encounter_check.asm — DL=0 if none alive
extern ReadPlayerMonCurHPAndStatus      ; core.asm — sync battle mon HP/status (no-op today)
extern PrintBattleText                  ; core.asm — EAX = flat battle-text stream
extern PrintEmptyString                 ; battle_exp_stubs.asm
extern SaveScreenTilesToBuffer1         ; battle_menu.asm
extern LoadScreenTilesFromBuffer1       ; battle_menu.asm
extern DrawHUDsAndHPBars                ; battle_menu.asm — redraw both HUDs + HP bars
extern ClearScreen                      ; title.asm
extern PlayerMonFaintedText             ; battle_text.inc
extern WildRanText                      ; battle_text.inc

; ===========================================================================
; SlideDownFaintedMonPic / RunPaletteCommand — deferred leaves.
; SlideDownFaintedMonPic: pret slides the fainted pic off (ANIMATION=OFF → no-op;
; the HP bar has already drained to 0 in the faithful damage path).
; RunPaletteCommand: pret's palette dispatcher (SET_PAL_BATTLE etc.) — palette HAL,
; deferred to Phase 5 (GBC palette translation). No-op keeps the DMG placebo palette.
; ===========================================================================
SlideDownFaintedMonPic:
RunPaletteCommand:
    ret

; ===========================================================================
; HasMonFainted — pret core.asm:HasMonFainted. Tests whether the mon at
; wWhichPokemon has fainted; returns ZF=1 if fainted (HP == 0).
; (pret also prints NoWillText when wFirstMonsNotOutYet==0; that text path is a
; TODO — the ZF contract, which the switch loop reads, is exact.)
; ===========================================================================
HasMonFainted:
    mov esi, wPartyMon1HP
    mov bx, PARTYMON_STRUCT_LENGTH
    mov al, [ebp + wWhichPokemon]
    call AddNTimes                      ; esi -> this mon's HP word
    mov al, [ebp + esi]
    or  al, [ebp + esi + 1]             ; ZF=1 → fainted
    ret
extern AddNTimes

; ===========================================================================
; RemoveFaintedPlayerMon — pret core.asm:1015-1090. Clears the fainted mon's
; gain-exp flag, resets the enemy's multi-attack + accumulated Bide damage,
; sets wBattleResult=loss, and (only when called from HandlePlayerMonFainted,
; i.e. wInHandlePlayerMonFainted==1) plays the cry + "<mon> fainted!" message.
; Deferred (ANIMATION/audio/Yellow): low-health alarm, SlideDownFaintedMonPic
; animation, PlayCry, ModifyPikachuHappiness.
; ===========================================================================
RemoveFaintedPlayerMon:
    ; clear gain-exp flag for the fainted mon (pret: predef FlagActionPredef, FLAG_RESET)
    mov cl, [ebp + wPlayerMonNumber]
    mov esi, wPartyGainExpFlags
    mov bh, FLAG_RESET
    call FlagAction
    ; res ATTACKING_MULTIPLE_TIMES on the enemy
    and byte [ebp + wEnemyBattleStatus1], (~(1 << ATTACKING_MULTIPLE_TIMES)) & 0xFF
    ; TODO-HW: low-health alarm (audio HAL, Phase 3).
    ; a==0 here → zero the enemy's accumulated Bide damage (both bytes) + status
    xor al, al
    mov [ebp + wEnemyBideAccumulatedDamage + 0], al
    mov [ebp + wEnemyBideAccumulatedDamage + 1], al
    mov [ebp + wBattleMonStatus], al
    call ReadPlayerMonCurHPAndStatus
    call SlideDownFaintedMonPic          ; ANIMATION=OFF
    mov byte [ebp + wBattleResult], 1    ; player lost (overwritten on later continue)
    ; When both mons faint and the enemy faint was detected first, don't print /
    ; cry (pret: called by HandleEnemyMonFainted with wInHandlePlayerMonFainted==0).
    mov al, [ebp + wInHandlePlayerMonFainted]
    and al, al
    jz .ret
    ; TODO-HW: PlayCry(wBattleMonSpecies) (audio HAL); Yellow ModifyPikachuHappiness.
    mov eax, PlayerMonFaintedText
    call PrintBattleText                 ; "<nick> fainted!"
.ret:
    ret

; ===========================================================================
; DoUseNextMonDialogue — pret core.asm:1091-1117. Trainer battles: no prompt,
; return CF=0. Wild battles: pret asks "Use next Pokémon?" (Yes → switch, No →
; try to run). Returns CF=1 if the player ran.
; TODO(faithful): the wild Yes/No box (TWO_OPTION_MENU) + No→TryRunningFromBattle;
; stubbed to "Yes" (CF=0 → proceed to the forced switch).
; ===========================================================================
DoUseNextMonDialogue:
    call PrintEmptyString
    call SaveScreenTilesToBuffer1
    mov al, [ebp + wIsInBattle]
    and al, al
    dec al                               ; wIsInBattle==2 (trainer) → nz
    jnz .noRun                           ; trainer: no prompt
    ; wild: "Use next mon?" — defaulting to YES (switch). TODO: real Yes/No + run.
.noRun:
    clc                                  ; CF=0 → did not run
    ret

; ===========================================================================
; ChooseNextMon — pret core.asm:1125-1167. Faithful state: clear the turn flag,
; set wPlayerMonNumber, set the gain-exp + fought flags for the new mon, load it
; into the battle-mon struct, send it out. Returns ZF from the enemy's HP word
; (pret's contract, read by HandlePlayerMonFainted).
; DEFERRAL: pret runs BATTLE_PARTY_MENU here; that interactive picker is the
; deferred BattlePartyMenu sub-UI, so this auto-selects the first live party mon.
; ===========================================================================
ChooseNextMon:
    ; find the first party slot with non-zero HP (AnyPartyAlive already guaranteed one)
    movzx ebx, byte [ebp + wPartyCount]
    xor eax, eax                         ; idx = 0
.scanLoop:
    mov esi, wPartyMon1HP
    movzx edx, al
    imul edx, edx, PARTYMON_STRUCT_LENGTH
    add esi, edx
    mov dl, [ebp + esi]
    or  dl, [ebp + esi + 1]
    jnz .found
    inc al
    dec bl
    jnz .scanLoop
    ; fallback (should be unreachable): keep idx 0
    xor al, al
.found:
    mov [ebp + wWhichPokemon], al
    mov [ebp + wPlayerMonNumber], al
    mov byte [ebp + wActionResultOrTookBattleTurn], 0
    ; set the gain-exp flag for the new mon (predef FlagActionPredef, FLAG_SET)
    push eax
    mov cl, al
    mov esi, wPartyGainExpFlags
    mov bh, FLAG_SET
    call FlagAction
    pop eax
    ; set the fought-current-enemy flag for the new mon
    push eax
    mov cl, al
    mov esi, wPartyFoughtCurrentEnemyFlags
    mov bh, FLAG_SET
    call FlagAction
    pop eax
    call LoadBattleMonFromParty
    call SendOutMon
    mov al, [ebp + wEnemyMonHP]
    or  al, [ebp + wEnemyMonHP + 1]      ; ZF = enemy has 0 HP (pret return contract)
    ret

; ===========================================================================
; SendOutMon — pret core.asm:1764+. Redraws the HUDs and resets the player-side
; per-mon battle state for the incoming mon. ANIMATION=OFF: the send-out pic
; animation / cry / palette command are deferred; the STATE resets are faithful.
; ===========================================================================
SendOutMon:
    ; TODO-HW: PrintSendOutMonMessage ("Go! <mon>!" / audio).
    call DrawHUDsAndHPBars               ; enemy + player HUD/HP (pret draws each)
    xor al, al
    mov [ebp + wBattleAndStartSavedMenuItem + 0], al
    mov [ebp + wBattleAndStartSavedMenuItem + 1], al
    mov [ebp + wBoostExpByExpAll], al
    mov [ebp + wDamageMultipliers], al
    mov [ebp + wPlayerMoveNum], al
    mov [ebp + wPlayerUsedMove + 0], al
    mov [ebp + wPlayerUsedMove + 1], al
    mov [ebp + wPlayerStatsToDouble + 0], al
    mov [ebp + wPlayerStatsToDouble + 1], al   ; StatsToHalve
    mov [ebp + wPlayerBattleStatus1], al
    mov [ebp + wPlayerBattleStatus2], al
    mov [ebp + wPlayerBattleStatus3], al
    mov [ebp + wPlayerDisabledMove], al
    mov [ebp + wPlayerDisabledMoveNumber], al
    mov [ebp + wPlayerMonMinimized], al
    call RunPaletteCommand               ; SET_PAL_BATTLE (palette HAL stub)
    and byte [ebp + wEnemyBattleStatus1], (~(1 << USING_TRAPPING_MOVE)) & 0xFF
    ; ANIMATION=OFF: PlayMoveAnimation(POOF_ANIM) / AnimateSendingOutMon / Pikachu.
    ret

; ===========================================================================
; HandlePlayerBlackOut — pret core.asm:1171-1204. Called when the player has no
; usable mons. Prints the lose message, clears the screen, returns CF=1.
; TODO(faithful): the OPP_RIVAL1 / OAKS_LAB starter-battle no-blackout special
; case + link-lost text + SET_PAL_BATTLE_BLACK palette command.
; ===========================================================================
HandlePlayerBlackOut:
    ; TODO-HW: RunPaletteCommand(SET_PAL_BATTLE_BLACK); PlayerBlackedOutText2.
    call ClearScreen
    stc                                  ; CF=1 → player blacked out
    ret

; ===========================================================================
; EnemyRan — pret core.asm:263. Reached (single-player) only as the ReplaceFainted-
; EnemyMon "ran" tail, which is link-only, so this is effectively a safety path:
; restore the screen, note the fled enemy, end the battle.
; ===========================================================================
EnemyRan:
    call LoadScreenTilesFromBuffer1
    mov eax, WildRanText
    call PrintBattleText
    mov byte [ebp + wBattleResult], 0
    ; ANIMATION=OFF: AnimationSlideEnemyMonOff.
    ret
