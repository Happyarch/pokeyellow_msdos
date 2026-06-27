; experience.asm — GainExperience post-battle EXP/stat-exp distribution.
;
; Source: engine/battle/experience.asm (pret/pokeyellow).
; Routines: GainExperience, DivideExpDataByNumMonsGainingExp, BoostExp, CallBattleCore.
;
; AUDIT (2026-06-27): Full native-validation audit. The swarm draft had six bugs
; beyond the already-noted sbc→sbb and CX→BX stride fixes:
;   1. `hExperience` used but undefined (→ H_EXPERIENCE, the correct alias).
;   2. `wPlayerID` used but not in gb_memmap.inc (→ local define, 0xD358;
;      orchestrator must add to gb_memmap.inc).
;   3. `wCalculateWhoseStats` used but not in gb_memmap.inc (→ local alias for
;      wTempByteValue; orchestrator must add to gb_memmap.inc).
;   4. `PIKAHAPPY_LEVELUP` undefined (→ 1; from pikachu_emotion_constants.asm).
;   5. `LEVEL_UP_STATS_BOX` undefined (→ 1; from menu_constants.asm).
;   6. `call FlagActionPredef` called without predef-WRAM setup: GetPredefRegisters
;      clobbers ESI from wPredefHL (garbage). All four call sites changed to
;      `call FlagAction` with ESI set directly — FlagAction does not invoke
;      GetPredefRegisters.
;   7. Overwrite-max-exp path: `dec esi` left ESI at party_mon+0x0F (middle byte of
;      EXP); should be party_mon+0x0E (high byte). Fixed: `sub esi, 2`.
;   8. CopyData called with EDI as destination, but copy_data.asm uses EDX (dx).
;      Both CopyData calls (wBattleMonLevel, wPlayerMonUnmodifiedLevel) fixed.
;   9. `call BattleCore` inside CallBattleCore: BattleCore not defined or extern'd.
;      In the flat model, CallBattleCore dispatches via ESI (call esi); deferred.
;  10. Missing extern declarations for all called routines (NASM allows implicit
;      externals in COFF but explicit declarations are required for correctness).
;
; WAVE-1 SCOPE — headless math only:
;   KEEP + native-validate: stat-exp accumulation (0xFFFF cap), exp-award Multiply/
;   Divide/3-byte-add chain, BoostExp ×1.5 (trade/trainer), DivideExpDataBy
;   NumMonsGainingExp (set-bit count + per-stat divide), level-up CalcStats
;   recompute + HP delta.
;   DEFERRED (extern stubs, Wave 2): PrintText, GetPartyMonName, LoadMonData,
;   ModifyPikachuHappiness, PrintStatsBox, WaitForTextScrollButtonPress,
;   SaveScreenTilesToBuffer1, LoadScreenTilesFromBuffer1, PrintEmptyString,
;   LearnMoveFromLevelUp, CalculateModifiedStats, ApplyBurnAndParalysisPenalties
;   ToPlayer, ApplyBadgeStatBoosts, DrawPlayerHUDAndHPBar.
;   CallBattleCore is implemented as `call esi` (flat model; deferred integration).
;
; This file assembles clean; it will NOT link into PKMN.EXE until Wave 2 adds it
; to LINK_SRCS (same pattern as all other BATTLE_SRCS files).
;
; Build: nasm -f coff -I dos_port/include/ -o experience.o experience.asm

bits 32

%include "gb_macros.inc"
%include "gb_memmap.inc"
%include "gb_constants.inc"

; ---------------------------------------------------------------------------
; Local defines — constants/aliases not yet in the shared include files.
; Orchestrator must add these to gb_memmap.inc / gb_constants.inc to keep the
; includes authoritative.
; ---------------------------------------------------------------------------
%ifndef wPlayerID
wPlayerID              equ 0xD358  ; sym-pinned (pokeyellow.sym bank 00:d358)
%endif
%ifndef wCalculateWhoseStats
wCalculateWhoseStats   equ 0xD11D  ; = wTempByteValue (sym: 00:d11d); orchestrator add
%endif
%ifndef PIKAHAPPY_LEVELUP
PIKAHAPPY_LEVELUP      equ 1       ; constants/pikachu_emotion_constants.asm const_def 1
%endif
%ifndef LEVEL_UP_STATS_BOX
LEVEL_UP_STATS_BOX     equ 1       ; constants/menu_constants.asm (STATUS_SCREEN=0, LEVELUP=1)
%endif

; ---------------------------------------------------------------------------
; Extern declarations
; ---------------------------------------------------------------------------

; Math helpers (already translated + wired into LINK_SRCS)
extern Multiply
extern Divide
extern AddNTimes
extern CopyData

; Pokémon engine (already translated + wired into POKEMON_SRCS / LINK_SRCS)
extern CalcExperience           ; src/engine/pokemon/experience.asm
extern CalcLevelFromExperience  ; src/engine/pokemon/experience.asm
extern CalcStats                ; src/home/move_mon.asm
extern GetMonHeader             ; src/home/pokemon.asm
extern FlagAction               ; src/engine/flag_action.asm (not the predef variant)

; ---------------------------------------------------------------------------
; DEFERRED externs (Wave 2 — battle front end / UI subsystem).
; These symbols are NOT provided in the current link; the file assembles to
; COFF for type-checking but stays out of LINK_SRCS until Wave 2 wires them.
; ---------------------------------------------------------------------------
; Text / display
extern PrintText                ; deferred: battle text rendering
extern GetPartyMonName          ; deferred: party name lookup
extern LoadMonData              ; deferred: load party/box mon into wLoadedMon
extern ModifyPikachuHappiness   ; deferred: Pikachu happiness events
extern PrintStatsBox            ; deferred: level-up stats overlay
extern WaitForTextScrollButtonPress  ; deferred: A-press wait
extern SaveScreenTilesToBuffer1      ; deferred: screen tile save
extern LoadScreenTilesFromBuffer1    ; deferred: screen tile restore
extern PrintEmptyString              ; deferred: clear text line
extern LearnMoveFromLevelUp          ; deferred: move-learn flow

; Battle core dispatch targets (passed via ESI to CallBattleCore; Wave 2)
extern CalculateModifiedStats
extern ApplyBurnAndParalysisPenaltiesToPlayer
extern ApplyBadgeStatBoosts
extern DrawPlayerHUDAndHPBar

; ---------------------------------------------------------------------------
; Globals
; ---------------------------------------------------------------------------
global GainExperience
global DivideExpDataByNumMonsGainingExp
global BoostExp
global CallBattleCore

section .text

; ---------------------------------------------------------------------------
; GainExperience
;
; Awards EXP and stat-EXP to every party mon that participated in the battle.
; pret ref: engine/battle/experience.asm:GainExperience
;
; Registers: A=AL, BC=EBX (B=BH, C=BL), DE=EDX (D=DH, E=DL), HL=ESI.
; GB memory at [EBP + addr]; HRAM math scratch via gb_memmap.inc aliases.
; ---------------------------------------------------------------------------
GainExperience:
    ; Return immediately in link battles (wLinkState = LINK_STATE_BATTLING).
    mov al, [ebp + wLinkState]
    cmp al, LINK_STATE_BATTLING
    je .return

    ; Divide base stats + base EXP by number of mons gaining EXP (Exp.All path).
    call DivideExpDataByNumMonsGainingExp

    ; HL = wPartyMon1 (start of first party-mon struct); wWhichPokemon = 0.
    mov esi, wPartyMon1
    xor al, al
    mov [ebp + wWhichPokemon], al

.partyMonLoop:
    ; HP check: skip fainted mons (HP high | HP low == 0).
    inc esi                         ; → MON_HP high byte
    mov al, [ebp + esi]
    inc esi                         ; → MON_HP low byte
    mov ah, [ebp + esi]
    or al, ah
    jz .nextMon

    ; Test the party-mon's gain-exp flag in wPartyGainExpFlags.
    push esi                        ; save party-mon+2 across FlagAction
    mov esi, wPartyGainExpFlags
    mov al, [ebp + wWhichPokemon]
    mov cl, al
    mov bh, FLAG_TEST
    call FlagAction                 ; CL ← non-zero if flag is set
    mov al, cl
    test al, al
    pop esi                         ; restore party-mon+2
    jz .nextMon

    ; Advance pointer from MON_HP+1 to MON_HP_EXP+1 (low byte of HP stat-exp).
    ; ESI is party_mon+2 (MON_HP low); (MON_HP_EXP+1)-(MON_HP+1) = 0x12-0x02 = 0x10.
    add esi, (MON_HP_EXP + 1) - (MON_HP + 1)
    mov edi, esi                    ; EDI = stat-exp pointer (low byte of HP_EXP)
    mov esi, wEnemyMonBaseStats     ; ESI → enemy base stats array

; -----------------------------------------------------------------------
; Stat-EXP accumulation loop: add each enemy base stat to the corresponding
; party-mon stat-EXP word (big-endian; low byte at EDI, high byte at EDI-1).
; If the word would overflow 0xFFFF it is clamped to 0xFFFF.
; -----------------------------------------------------------------------
    mov cl, NUM_STATS               ; 5 stats
.gainStatExpLoop:
    mov al, [ebp + esi]             ; enemy base stat
    inc esi
    mov bh, al
    mov al, [ebp + edi]             ; low byte of party-mon stat-EXP
    add al, bh
    mov [ebp + edi], al
    jnc .nextBaseStat
    ; carry: increment the high byte
    dec edi
    mov al, [ebp + edi]
    inc al
    jz .maxStatExp                  ; high byte also overflowed → cap to 0xFFFF
    mov [ebp + edi], al
    inc edi
    jmp .nextBaseStat
.maxStatExp:
    ; BUG-FREE: a = 0 from inc overflow; dec a → 0xFF (wraps, as in SM83 `dec a`)
    dec al                          ; al = 0xFF
    mov [ebp + edi], al             ; high byte = 0xFF
    inc edi
    mov [ebp + edi], al             ; low byte = 0xFF  → stat-EXP = 0xFFFF
.nextBaseStat:
    dec cl
    jz .statExpDone
    inc edi                         ; skip past current low byte
    inc edi                         ; → low byte of next stat-EXP
    jmp .gainStatExpLoop

.statExpDone:
; -----------------------------------------------------------------------
; Compute base EXP * level, divide by 7 (rounded down) → hQuotient+2:+3.
; EDI now = low byte of SPC_EXP = party_mon + MON_SPC_EXP + 1.
; -----------------------------------------------------------------------
    xor al, al
    mov [ebp + hMultiplicand], al
    mov [ebp + hMultiplicand + 1], al
    mov al, [ebp + wEnemyMonBaseExp]
    mov [ebp + hMultiplicand + 2], al
    mov al, [ebp + wEnemyMonLevel]
    mov [ebp + hMultiplier], al
    call Multiply
    mov al, 7
    mov [ebp + hDivisor], al
    mov bh, 4
    call Divide                     ; hQuotient+2:+3 = floor(baseExp * level / 7)

; -----------------------------------------------------------------------
; Trade check: compare party mon's OT-ID with the player's ID.
; Traded mons get ×1.5 EXP boost (BoostExp). EDI is at SPC_EXP low byte.
; Offset to OTID from SPC_EXP low: MON_OTID - (MON_DVS - 1) = 0x0C - 0x1A = -0x0E
; -----------------------------------------------------------------------
    mov esi, edi
    add esi, MON_OTID - (MON_DVS - 1)  ; ESI → party_mon + MON_OTID (high byte)
    mov bh, [ebp + esi]                 ; OTID high byte from party struct
    inc esi
    mov al, [ebp + wPlayerID]
    cmp al, bh
    jne .tradedMon
    mov bh, [ebp + esi]                 ; OTID low byte
    mov al, [ebp + wPlayerID + 1]
    cmp al, bh
    mov al, 0
    je .next                            ; OT matches → not traded
.tradedMon:
    call BoostExp                       ; traded mon: EXP × 1.5
    mov al, 1
.next:
    mov [ebp + wGainBoostedExp], al

    ; Trainer battle check: wIsInBattle = 2 → dec = 1 (nz) → boost.
    ; Wild (=1) → dec = 0 (z) → no boost.
    mov al, [ebp + wIsInBattle]
    dec al
    jz .noBoost
    call BoostExp
.noBoost:
    ; ESI is at party_mon + MON_OTID + 1 (OTID low byte position).
    ; Three incs bring us to MON_EXP low byte (party_mon + 0x10).
    ; Layout: OTID = 0x0C-0x0D, EXP = 0x0E-0x0F-0x10.
    inc esi                             ; → 0x0E (EXP high)
    inc esi                             ; → 0x0F (EXP middle)
    inc esi                             ; → 0x10 (EXP low) ← start of 3-byte add

; -----------------------------------------------------------------------
; Add hQuotient+2:+3 into party_mon EXP (3 bytes big-endian, low → high).
; ESI = party_mon + 0x10 (EXP low byte).
; -----------------------------------------------------------------------
    mov bh, [ebp + esi]
    mov al, [ebp + hQuotient + 3]
    mov [ebp + wExpAmountGained + 1], al
    add al, bh
    mov [ebp + esi], al             ; store EXP low byte result
    dec esi                         ; → 0x0F (EXP middle)
    mov bh, [ebp + esi]
    mov al, [ebp + hQuotient + 2]
    mov [ebp + wExpAmountGained], al
    adc al, bh
    mov [ebp + esi], al             ; store EXP middle byte result
    jnc .noCarry
    dec esi                         ; → 0x0E (EXP high)
    inc byte [ebp + esi]            ; carry into EXP high byte
    inc esi                         ; → 0x0F (middle) for noCarry path alignment
.noCarry:
    inc esi                         ; → 0x10 (EXP low) in both paths

; -----------------------------------------------------------------------
; Cap EXP at the level-100 maximum for this species.
; ESI = party_mon + 0x10 (EXP low).  MAX_LEVEL = 100.
; Push ESI first; use wPartySpecies to look up the species for CalcExperience.
; -----------------------------------------------------------------------
    push esi                        ; PUSH A: save EXP-low pointer
    mov al, [ebp + wWhichPokemon]
    movzx ecx, al
    mov esi, wPartySpecies
    add esi, ecx
    mov al, [ebp + esi]
    mov [ebp + wCurSpecies], al
    call GetMonHeader
    mov dh, MAX_LEVEL
    call CalcExperience             ; hExperience = max EXP for level 100

    ; Load max EXP bytes into BH:CL:DH (high:mid:low).
    mov al, [ebp + H_EXPERIENCE]
    mov bh, al
    mov al, [ebp + H_EXPERIENCE + 1]
    mov cl, al
    mov al, [ebp + H_EXPERIENCE + 2]
    mov dh, al

    pop esi                         ; POP A: ESI = party_mon + 0x10 (EXP low)

    ; 3-byte compare: current EXP - max EXP (low → high via sbb chain).
    ; If current < max (borrow/carry set), skip the overwrite.
    mov al, [ebp + esi]             ; EXP low
    dec esi                         ; → 0x0F (EXP middle)
    sub al, dh
    mov al, [ebp + esi]             ; EXP middle
    dec esi                         ; → 0x0E (EXP high)
    sbb al, cl
    mov al, [ebp + esi]             ; EXP high
    sbb al, bh
    jc .next2                       ; current EXP < max → no cap needed

    ; Overwrite EXP with the level-100 maximum.
    ; ESI = 0x0E (EXP high). After writes: need ESI = 0x0E (high byte of EXP).
    mov al, bh
    mov [ebp + esi], al             ; high byte at 0x0E
    inc esi                         ; → 0x0F
    mov al, cl
    mov [ebp + esi], al             ; middle byte
    inc esi                         ; → 0x10
    mov al, dh
    mov [ebp + esi], al             ; low byte
    sub esi, 2                      ; FIX: esi → 0x0E (high byte), matching pret `ld [hld], a; dec hl`

.next2:
    ; ESI = party_mon + 0x0E (EXP high byte) in both paths.
    ; Save ESI so we can advance to MON_LEVEL for the level-change check.
    push esi                        ; PUSH B: save EXP-high pointer

    ; Deferred: display gained EXP text and reload mon data.
    ; GetPartyMonName, PrintText, LoadMonData all just return in Wave 1.
    mov al, [ebp + wWhichPokemon]
    mov esi, wPartyMonNicks
    call GetPartyMonName            ; DEFERRED stub
    mov esi, GainedText
    call PrintText                  ; DEFERRED stub
    xor al, al
    mov [ebp + wMonDataLocation], al
    call LoadMonData                ; DEFERRED stub (set W_LOADED_MON_EXP in harness)

    pop esi                         ; POP B: ESI = party_mon + 0x0E (EXP high)
    add esi, MON_LEVEL - MON_EXP   ; 0x21 - 0x0E = 0x13 → party_mon + MON_LEVEL
    push esi                        ; PUSH C: save MON_LEVEL pointer
    call CalcLevelFromExperience    ; result: DH = new level
    pop esi                         ; POP C: ESI = party_mon + MON_LEVEL

    mov al, [ebp + esi]             ; current stored level
    cmp al, dh
    je .nextMon_jump                ; same level → no level-up, skip

    ; -----------------------------------------------------------------
    ; Level-up path: update level, recompute stats, update battle mon.
    ; -----------------------------------------------------------------
    mov al, [ebp + wCurEnemyLevel]
    push eax                        ; PUSH D: save old wCurEnemyLevel
    push esi                        ; PUSH E: save MON_LEVEL pointer

    mov al, dh                      ; new level
    mov [ebp + wCurEnemyLevel], al
    mov [ebp + esi], al             ; write new level to party struct

    ; Navigate to MON_SPECIES: offset = MON_SPECIES - MON_LEVEL = 0x00 - 0x21 = -0x21
    add esi, MON_SPECIES - MON_LEVEL
    mov al, [ebp + esi]
    mov [ebp + wCurSpecies], al
    mov [ebp + wPokedexNum], al
    call GetMonHeader

    ; Navigate from MON_SPECIES to MON_MAXHP+1 (low byte of max HP).
    ; offset = (MON_MAXHP + 1) - MON_SPECIES = 0x23
    add esi, (MON_MAXHP + 1) - MON_SPECIES
    push esi                        ; PUSH F: save MON_MAXHP+1 pointer

    ; Read old max HP (before CalcStats updates it).
    mov al, [ebp + esi]             ; low byte of maxHP
    dec esi                         ; → MON_MAXHP (high byte)
    mov cl, al                      ; CL = old maxHP low
    mov bh, [ebp + esi]             ; BH = old maxHP high
    push ebx                        ; PUSH G: save old maxHP (BH:CL)

    ; EDI = party_mon + MON_MAXHP (CalcStats writes stats here).
    mov edi, esi

    ; Navigate to stat-EXP source for CalcStats.
    ; offset = (MON_HP_EXP - 1) - MON_MAXHP = (0x11 - 1) - 0x22 = -0x12
    add esi, (MON_HP_EXP - 1) - MON_MAXHP
    mov bh, 1                       ; BH = 1: include stat-EXP in calculation
    call CalcStats

    pop ebx                         ; POP G: BH = old maxHP high, CL = old maxHP low
    pop esi                         ; POP F: ESI = MON_MAXHP+1 (low byte)

    ; Compute HP delta: new maxHP - old maxHP.
    mov al, [ebp + esi]             ; new maxHP low byte (CalcStats wrote it)
    dec esi                         ; → MON_MAXHP high byte
    sub al, cl
    mov cl, al                      ; CL = maxHP delta low
    mov al, [ebp + esi]             ; new maxHP high byte
    sbb al, bh
    mov bh, al                      ; BH = maxHP delta high

    ; Add HP delta to current HP.
    ; MON_HP + 1 = (MON_HP + 1); offset from MON_MAXHP = (MON_HP+1) - MON_MAXHP = 0x02-0x22 = -0x20
    add esi, (MON_HP + 1) - MON_MAXHP
    mov al, [ebp + esi]             ; current HP low
    add al, cl
    mov [ebp + esi], al             ; write new current HP low
    dec esi                         ; → MON_HP high byte
    mov al, [ebp + esi]
    adc al, bh
    mov [ebp + esi], al             ; write new current HP high

    ; If this mon is the one currently in battle, sync battle-mon HP/stats.
    mov al, [ebp + wPlayerMonNumber]
    mov bh, al
    mov al, [ebp + wWhichPokemon]
    cmp al, bh
    jne .printGrewLevelText

    ; Copy current HP to wBattleMonHP (2 bytes: high then low).
    mov edx, wBattleMonHP
    mov al, [ebp + esi]             ; HP high byte (ESI = MON_HP high)
    mov [ebp + edx], al
    inc edx
    inc esi                         ; → MON_HP+1 (low byte)
    mov al, [ebp + esi]
    mov [ebp + edx], al

    ; Copy level + 5 stats (1 + NUM_STATS*2 = 11 bytes) to wBattleMonLevel.
    ; ESI is at MON_HP+1; advance to MON_LEVEL.
    ; offset = MON_LEVEL - (MON_HP + 1) = 0x21 - 0x02 = 0x1F
    add esi, MON_LEVEL - (MON_HP + 1)
    push esi                        ; PUSH H: save MON_LEVEL pointer
    mov edx, wBattleMonLevel
    mov bx, 1 + NUM_STATS * 2      ; 11 bytes
    call CopyData                   ; FIX: was EDI, must be EDX for copy_data.asm
    pop esi                         ; POP H: ESI = party_mon + MON_LEVEL

    ; If transformed, skip updating unmodified stats.
    mov al, [ebp + wPlayerBattleStatus3]
    test al, 1 << TRANSFORMED
    jnz .recalcStatChanges

    ; Update pre-stage-mod stats as well.
    mov edx, wPlayerMonUnmodifiedLevel
    mov bx, 1 + NUM_STATS * 2
    call CopyData                   ; FIX: was EDI, must be EDX for copy_data.asm

.recalcStatChanges:
    ; Recalculate modified stats for the battle mon (deferred — Wave 2 stubs).
    xor al, al
    mov [ebp + wCalculateWhoseStats], al   ; 0 = player's mon
    mov esi, CalculateModifiedStats
    call CallBattleCore
    mov esi, ApplyBurnAndParalysisPenaltiesToPlayer
    call CallBattleCore
    mov esi, ApplyBadgeStatBoosts
    call CallBattleCore
    mov esi, DrawPlayerHUDAndHPBar
    call CallBattleCore
    mov esi, PrintEmptyString
    call CallBattleCore
    call SaveScreenTilesToBuffer1

.printGrewLevelText:
    ; Deferred: Pikachu happiness + level-up display + move learning (Wave 2).
    ; PIKAHAPPY_LEVELUP = 1 (pikachu_emotion_constants.asm)
    mov al, PIKAHAPPY_LEVELUP
    call ModifyPikachuHappiness     ; DEFERRED stub
    mov esi, GrewLevelText
    call PrintText                  ; DEFERRED stub
    xor al, al
    mov [ebp + wMonDataLocation], al
    call LoadMonData                ; DEFERRED stub
    ; LEVEL_UP_STATS_BOX = 1 (menu_constants.asm)
    mov dh, LEVEL_UP_STATS_BOX
    call PrintStatsBox              ; DEFERRED stub
    call WaitForTextScrollButtonPress  ; DEFERRED stub
    call LoadScreenTilesFromBuffer1    ; DEFERRED stub
    xor al, al
    mov [ebp + wMonDataLocation], al
    mov al, [ebp + wCurSpecies]
    mov [ebp + wPokedexNum], al
    call LearnMoveFromLevelUp          ; DEFERRED stub

    ; Set the can-evolve flag for this mon.
    mov esi, wCanEvolveFlags
    mov al, [ebp + wWhichPokemon]
    mov cl, al
    mov bh, FLAG_SET
    call FlagAction                 ; FIX: was FlagActionPredef (missing predef setup)

    pop esi                         ; POP E: ESI = MON_LEVEL pointer
    pop eax                         ; POP D: AL = old wCurEnemyLevel
    mov [ebp + wCurEnemyLevel], al  ; restore

.nextMon_jump:
    jmp .nextMon
.nextMon:
    ; Advance to the next party mon if there are more.
    mov al, [ebp + wPartyCount]
    mov bh, al
    mov al, [ebp + wWhichPokemon]
    inc al
    cmp al, bh
    je .done
    mov [ebp + wWhichPokemon], al
    mov bx, PARTYMON_STRUCT_LENGTH
    mov esi, wPartyMon1
    call AddNTimes                  ; ESI = wPartyMon1 + AL * PARTYMON_STRUCT_LENGTH
    jmp .partyMonLoop

.done:
    ; Clear wPartyGainExpFlags (first byte only — pret matches this).
    mov esi, wPartyGainExpFlags
    xor al, al
    mov [ebp + esi], al

    ; Set the gain-exp flag for the currently-out mon (so it gains exp next battle).
    mov al, [ebp + wPlayerMonNumber]
    mov cl, al
    mov bh, FLAG_SET
    push ebx                        ; save BH=FLAG_SET for second call
    call FlagAction                 ; FIX: was FlagActionPredef

    ; Clear wPartyFoughtCurrentEnemyFlags, then set the fought flag for current mon.
    mov esi, wPartyFoughtCurrentEnemyFlags
    xor al, al
    mov [ebp + esi], al
    pop ebx                         ; restore BH=FLAG_SET, CL=wPlayerMonNumber
    call FlagAction                 ; FIX: was FlagActionPredef

.return:
    ret

; ---------------------------------------------------------------------------
; DivideExpDataByNumMonsGainingExp
;
; If two or more mons are gaining EXP (Exp.All), divides each enemy base stat
; and base EXP by the number of gaining mons (integer division).
; pret ref: engine/battle/experience.asm:DivideExpDataByNumMonsGainingExp
; ---------------------------------------------------------------------------
DivideExpDataByNumMonsGainingExp:
    ; Count set bits in wPartyGainExpFlags (which mons are gaining EXP).
    mov al, [ebp + wPartyGainExpFlags]
    mov bh, al
    xor al, al
    mov cl, 8
    mov dh, 0
.countSetBitsLoop:
    shr bh, 1                       ; CF ← bit 0 of BH, shift right
    adc dh, 0                       ; DH += CF (counts set bits)
    dec cl
    jnz .countSetBitsLoop

    ; DH = number of mons gaining EXP. If < 2, no division needed.
    cmp dh, 2
    jc .return
    mov [ebp + wTempByteValue], dh  ; store count

    ; Divide each byte from wEnemyMonBaseStats through wEnemyMonBaseExp (7 bytes).
    ; Layout: [HP,Atk,Def,Spd,Spc,CatchRate,BaseExp] at 0xD001–0xD007.
    mov esi, wEnemyMonBaseStats
    mov cl, wEnemyMonBaseExp + 1 - wEnemyMonBaseStats  ; 7 bytes
.divideLoop:
    xor al, al
    mov [ebp + hDividend], al           ; clear high byte of dividend
    mov al, [ebp + esi]
    mov [ebp + hDividend + 1], al       ; low byte = current value
    mov al, [ebp + wTempByteValue]
    mov [ebp + hDivisor], al
    mov bh, 2
    call Divide
    mov al, [ebp + hQuotient + 3]       ; quotient byte
    mov [ebp + esi], al
    inc esi
    dec cl
    jnz .divideLoop
.return:
    ret

; ---------------------------------------------------------------------------
; BoostExp
;
; Multiplies hQuotient+2:hQuotient+3 (16-bit big-endian) by 1.5.
; Method: result = value + (value >> 1), using the two-byte carry-through trick.
; pret ref: engine/battle/experience.asm:BoostExp
; ---------------------------------------------------------------------------
BoostExp:
    ; Load the 16-bit EXP value.
    mov al, [ebp + hQuotient + 2]   ; high byte
    mov bh, al
    mov al, [ebp + hQuotient + 3]   ; low byte
    mov cl, al

    ; half = value >> 1  (16-bit right-shift, CF preserved between bytes).
    shr bh, 1                       ; high byte >> 1, CF = bit 0 of high byte
    rcr cl, 1                       ; low byte >> 1 with CF from shr bh

    ; result_low = original_low + half_low (with any carry out into result_high).
    add al, cl
    mov [ebp + hQuotient + 3], al

    ; result_high = original_high + half_high + carry_in.
    mov al, [ebp + hQuotient + 2]   ; reload original (BH was already shifted)
    adc al, bh
    mov [ebp + hQuotient + 2], al
    ret

; ---------------------------------------------------------------------------
; CallBattleCore
;
; SM83: `ld b, BANK(BattleCore); jp Bankswitch` — dispatches to a BattleCore
; function via HL (the function pointer passed by the caller in pret).
; x86 flat model: bankswitching is a no-op; ESI holds the function pointer
; directly.  Wave 2 will flesh out each BattleCore target (CalculateModifiedStats,
; etc.) as real symbol bodies.  Until then, stubs return immediately so the
; level-up path assembles and links without the front-end.
;
; pret ref: engine/battle/experience.asm:CallBattleCore
; ---------------------------------------------------------------------------
CallBattleCore:
    ; In the flat x86 model, call the function whose address is in ESI.
    ; TODO-HW: When Wave 2 provides real bodies for CalculateModifiedStats et al.,
    ; this stays as-is — they'll link in normally.
    call esi
    ret

; ---------------------------------------------------------------------------
; Text stubs — labels referenced by `mov esi, <label>; call PrintText`.
; PrintText is deferred (extern above); these labels just need to exist.
; In pret these carry `text_far` / `text_asm` / `sound_level_up` directives
; processed by the text engine.  In the flat port the text-engine integration
; is deferred to Wave 2; for now they are bare `ret` stubs.
; ---------------------------------------------------------------------------

GainedText:
    ; DEFERRED: text_far _GainedText + text_asm dispatch (wBoostExpByExpAll /
    ; wGainBoostedExp → choose ExpPointsText / WithExpAllText / BoostedText).
    ret

WithExpAllText:
    ; DEFERRED: text_far _WithExpAllText + text_asm → ExpPointsText
    ret

BoostedText:
    ; DEFERRED: text_far _BoostedText
    ret

ExpPointsText:
    ; DEFERRED: text_far _ExpPointsText + text_end
    ret

GrewLevelText:
    ; DEFERRED: text_far _GrewLevelText + sound_level_up + text_end
    ret
