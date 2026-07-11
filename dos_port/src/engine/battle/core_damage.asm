; core_damage.asm — battle damage pipeline (battle engine plan, Stage 3/4).
;
; Faithful translation of the damage-calculation core from
; engine/battle/core.asm (pret/pokeyellow):
;   GetDamageVarsForPlayerAttack / GetDamageVarsForEnemyAttack / GetEnemyMonStat
;   CalculateDamage / JumpToOHKOMoveEffect
;   CriticalHitTest
;   AdjustDamageForMoveType
;   MoveHitTest / CalcHitChance
;   RandomizeDamage
;   BattleRandom
;
; Register map (CLAUDE.md): a=AL, b=BH, c=BL (bc=BX), d=DH, e=DL (de=DX),
; hl=ESI, ecx=scratch loop counter, edi=scratch. GB memory at [EBP+addr].
; HRAM math scratch via the H_*/h* aliases in gb_memmap.inc; Multiply/Divide
; honour the GB contract (product/quotient big-endian at $FF95..$FF98,
; divide byte-count in BH).
;
; Build: nasm -f coff -I include/ -I . -o core_damage.o core_damage.asm

bits 32

%include "gb_macros.inc"
%include "gb_memmap.inc"
%include "gb_constants.inc"

EFFECT_1E equ 0x1E    ; unused move effect, special-cased in CalculateDamage

section .text

global GetDamageVarsForPlayerAttack
global GetDamageVarsForEnemyAttack
global GetEnemyMonStat
global CalculateDamage
global JumpToOHKOMoveEffect
global CriticalHitTest
global AdjustDamageForMoveType
global MoveHitTest
global CalcHitChance
global RandomizeDamage
global BattleRandom

; --- externs (already translated elsewhere) ---
extern Multiply
extern Divide
extern Random
extern AddNTimes
extern GetMonHeader
extern CalcStat
extern TypeEffects
extern HighCriticalMoves
extern StatModifierRatios
; --- deferred externs (effect dispatcher / substitute; Stage 6/7) ---
extern JumpMoveEffect
extern CheckTargetSubstitute

; ===========================================================================
; BattleRandom — battle PRNG. In a link battle (Phase 4) this reads from a
; shared seed list; single-player just uses Random. Returns value in AL.
; TODO-HW: link-battle shared PRNG (Phase 4 network HAL).
; ===========================================================================
BattleRandom:
    mov al, [ebp + wLinkState]
    cmp al, LINK_STATE_BATTLING
    jne Random              ; tail-call Random (returns value in AL)
    ; link path not yet implemented; fall back to Random for determinism
    jmp Random

; ===========================================================================
; GetDamageVarsForPlayerAttack
; Out: BH=attack, BL=defense, DH=base power, DL=level (for CalculateDamage),
;      or returns with move power 0 if the move does no damage.
; ===========================================================================
GetDamageVarsForPlayerAttack:
    xor eax, eax
    mov esi, wDamage           ; init wDamage = 0
    mov [ebp + esi], al
    inc esi
    mov [ebp + esi], al
    mov esi, wPlayerMovePower
    mov al, [ebp + esi]        ; a = move power ([hli])
    inc esi
    test al, al
    mov dh, al                 ; d = move power
    jz .retpower               ; ret z (move power 0)
    mov al, [ebp + esi]        ; a = [wPlayerMoveType]
    cmp al, SPECIAL
    jae .specialAttack
; physical attack
    mov esi, wEnemyMonDefense
    mov al, [ebp + esi]
    inc esi
    mov bh, al
    mov bl, [ebp + esi]        ; bc = enemy defense
    mov al, [ebp + wEnemyBattleStatus3]
    test al, 1 << HAS_REFLECT_UP
    jz .physicalAttackCritCheck
    shl bx, 1                  ; double enemy defense (sla c / rl b)
.physicalAttackCritCheck:
    mov esi, wBattleMonAttack
    mov al, [ebp + wCriticalHitOrOHKO]
    test al, al
    jz .scaleStats
; critical hit: reset player attack & enemy defense to base values
    mov bl, STAT_DEFENSE
    call GetEnemyMonStat
    mov al, [ebp + hMultiplicand + 1]  ; hProduct+2
    mov bh, al
    mov al, [ebp + hMultiplicand + 2]  ; hProduct+3
    mov bl, al
    push ebx
    mov esi, wPartyMon1Attack
    mov al, [ebp + wPlayerMonNumber]
    mov bx, PARTYMON_STRUCT_LENGTH
    call AddNTimes
    pop ebx
    jmp .scaleStats
.specialAttack:
    mov esi, wEnemyMonSpecial
    mov al, [ebp + esi]
    inc esi
    mov bh, al
    mov bl, [ebp + esi]        ; bc = enemy special
    mov al, [ebp + wEnemyBattleStatus3]
    test al, 1 << HAS_LIGHT_SCREEN_UP
    jz .specialAttackCritCheck
    shl bx, 1                  ; double enemy special
.specialAttackCritCheck:
    mov esi, wBattleMonSpecial
    mov al, [ebp + wCriticalHitOrOHKO]
    test al, al
    jz .scaleStats
    mov bl, STAT_SPECIAL
    call GetEnemyMonStat
    mov al, [ebp + hMultiplicand + 1]
    mov bh, al
    mov al, [ebp + hMultiplicand + 2]
    mov bl, al
    push ebx
    mov esi, wPartyMon1Special
    mov al, [ebp + wPlayerMonNumber]
    mov bx, PARTYMON_STRUCT_LENGTH
    call AddNTimes
    pop ebx
.scaleStats:
; esi = pointer to player's 16-bit offensive stat (big-endian); bc = enemy def
    movzx eax, byte [ebp + esi]   ; a = high byte ([hli])
    inc esi
    movzx ecx, byte [ebp + esi]   ; c-scratch = low byte ([hl])
    mov esi, eax
    shl esi, 8
    or esi, ecx                   ; hl = player offensive stat
    or al, bh                     ; (stat high | enemy def high); sets ZF
    jz .next
; scale: bc /= 4, hl /= 4
    shr bx, 1
    shr bx, 1
    shr esi, 1
    shr esi, 1
    test si, si                   ; player offensive stat 0?
    jnz .next
    inc esi                       ; bump to 1
.next:
    mov eax, esi
    mov bh, al                    ; b = player offensive stat (low byte of hl)
    mov al, [ebp + wBattleMonLevel]
    mov dl, al                    ; e = level
    mov al, [ebp + wCriticalHitOrOHKO]
    test al, al
    jz .done
    shl dl, 1                     ; double level on crit
.done:
    mov al, 1
    test al, al                   ; nz, nc
    ret
.retpower:
    ret

; ===========================================================================
; GetDamageVarsForEnemyAttack — mirror of the player version (attacker = enemy)
; ===========================================================================
GetDamageVarsForEnemyAttack:
    mov esi, wDamage
    xor eax, eax
    mov [ebp + esi], al
    inc esi
    mov [ebp + esi], al
    mov esi, wEnemyMovePower
    mov al, [ebp + esi]
    inc esi
    mov dh, al                    ; d = move power
    test al, al
    jz .retpower
    mov al, [ebp + esi]           ; [wEnemyMoveType]
    cmp al, SPECIAL
    jae .specialAttack
; physical
    mov esi, wBattleMonDefense
    mov al, [ebp + esi]
    inc esi
    mov bh, al
    mov bl, [ebp + esi]           ; bc = player defense
    mov al, [ebp + wPlayerBattleStatus3]
    test al, 1 << HAS_REFLECT_UP
    jz .physicalAttackCritCheck
    shl bx, 1
.physicalAttackCritCheck:
    mov esi, wEnemyMonAttack
    mov al, [ebp + wCriticalHitOrOHKO]
    test al, al
    jz .scaleStats
; crit: player defense & enemy attack to base
    mov esi, wPartyMon1Defense
    mov al, [ebp + wPlayerMonNumber]
    mov bx, PARTYMON_STRUCT_LENGTH
    call AddNTimes
    mov al, [ebp + esi]
    inc esi
    mov bh, al
    mov bl, [ebp + esi]
    push ebx
    mov bl, STAT_ATTACK
    call GetEnemyMonStat
    mov esi, hMultiplicand + 1    ; hProduct+2 (enemy attack base, big-endian)
    pop ebx
    jmp .scaleStats
.specialAttack:
    mov esi, wBattleMonSpecial
    mov al, [ebp + esi]
    inc esi
    mov bh, al
    mov bl, [ebp + esi]
    mov al, [ebp + wPlayerBattleStatus3]
    test al, 1 << HAS_LIGHT_SCREEN_UP
    jz .specialAttackCritCheck
    shl bx, 1
.specialAttackCritCheck:
    mov esi, wEnemyMonSpecial
    mov al, [ebp + wCriticalHitOrOHKO]
    test al, al
    jz .scaleStats
    mov esi, wPartyMon1Special
    mov al, [ebp + wPlayerMonNumber]
    mov bx, PARTYMON_STRUCT_LENGTH
    call AddNTimes
    mov al, [ebp + esi]
    inc esi
    mov bh, al
    mov bl, [ebp + esi]
    push ebx
    mov bl, STAT_SPECIAL
    call GetEnemyMonStat
    mov esi, hMultiplicand + 1
    pop ebx
.scaleStats:
    movzx eax, byte [ebp + esi]
    inc esi
    movzx ecx, byte [ebp + esi]
    mov esi, eax
    shl esi, 8
    or esi, ecx                   ; hl = enemy offensive stat
    or al, bh
    jz .next
    shr bx, 1
    shr bx, 1
    shr esi, 1
    shr esi, 1
    test si, si
    jnz .next
    inc esi
.next:
    mov eax, esi
    mov bh, al
    mov al, [ebp + wEnemyMonLevel]
    mov dl, al
    mov al, [ebp + wCriticalHitOrOHKO]
    test al, al
    jz .done
    shl dl, 1
.done:
    mov al, 1
    test al, al
    ret
.retpower:
    ret

; ===========================================================================
; GetEnemyMonStat — get base (stat-stage-ignoring) stat BL of the enemy mon.
; In:  BL = stat index (STAT_*). Out: big-endian result at hMultiplicand+1/+2.
; Preserves DX (d/e).
; ===========================================================================
GetEnemyMonStat:
    push edx
    push ebx
    mov al, [ebp + wLinkState]
    cmp al, LINK_STATE_BATTLING
    jne .notLinkBattle
; link battle: read precomputed enemy party stats. TODO-HW: link (Phase 4).
    mov esi, wEnemyMon1Stats
    dec bl
    shl bl, 1
    mov bh, 0
    movzx ecx, bx
    add esi, ecx
    mov al, [ebp + wEnemyMonPartyPos]
    mov bx, PARTYMON_STRUCT_LENGTH
    call AddNTimes
    mov al, [ebp + esi]
    mov [ebp + hMultiplicand + 1], al
    inc esi
    mov al, [ebp + esi]
    mov [ebp + hMultiplicand + 2], al
    pop ebx
    pop edx
    ret
.notLinkBattle:
    mov al, [ebp + wEnemyMonLevel]
    mov [ebp + wCurEnemyLevel], al
    mov al, [ebp + wEnemyMonSpecies]
    mov [ebp + wCurSpecies], al
    call GetMonHeader
    mov esi, wEnemyMonDVs
    mov edi, wLoadedMonSpeedExp
    mov al, [ebp + esi]           ; DV byte 0 ([hli])
    mov [ebp + edi], al
    inc esi
    inc edi
    mov al, [ebp + esi]           ; DV byte 1
    mov [ebp + edi], al
    pop ebx                       ; restore bl = stat index
    mov bh, 0                     ; b = 0 (don't consider stat exp)
    mov esi, wLoadedMonSpeedExp - 0x0B  ; base ptr so CalcStat finds DVs here
    call CalcStat
    pop edx
    ret

; ===========================================================================
; CalculateDamage
; In: BH=attack, BL=defense, DH=base power, DL=level.
; Out: wDamage (big-endian) updated; returns nz,nc (a=1) unless 0-power early-out.
; ===========================================================================
CalculateDamage:
    mov al, [ebp + hWhoseTurn]
    test al, al
    mov al, [ebp + wPlayerMoveEffect]
    jz .effect
    mov al, [ebp + wEnemyMoveEffect]
.effect:
; EXPLODE_EFFECT halves defense (min 1)
    cmp al, EXPLODE_EFFECT
    jne .ok
    shr bl, 1
    jnz .ok
    inc bl
.ok:
    cmp al, TWO_TO_FIVE_ATTACKS_EFFECT
    je .skipbp
    cmp al, EFFECT_1E
    je .skipbp
    cmp al, OHKO_EFFECT
    je JumpToOHKOMoveEffect
    test dh, dh                   ; base power 0?
    jnz .skipbp
    ret
.skipbp:
; zero hDividend[0..2]
    xor eax, eax
    mov esi, hDividend
    mov [ebp + esi], al
    inc esi
    mov [ebp + esi], al
    inc esi
    mov [ebp + esi], al           ; esi = hDividend+2
; level * 2 (with carry into hDividend+2)
    mov al, dl
    add al, al
    jnc .nc
    push eax
    mov byte [ebp + esi], 1       ; ld [hl],1 (high byte)
    pop eax
.nc:
    inc esi                       ; hDividend+3
    mov [ebp + esi], al           ; store 2*level low byte; esi -> hDividend+4 (=hDivisor)
    inc esi
; divide by 5
    mov byte [ebp + esi], 5       ; ld [hld],a (hDivisor=5)
    dec esi                       ; -> hDividend+3
    push ebx
    mov bh, 4
    call Divide
    pop ebx
; add 2 (inc [hl] twice at hDividend+3)
    inc byte [ebp + esi]
    inc byte [ebp + esi]
    inc esi                       ; -> hDivisor (multiplier slot)
; multiply by base power
    mov [ebp + esi], dh
    call Multiply
; multiply by attack stat
    mov [ebp + esi], bh
    call Multiply
; divide by defense stat
    mov [ebp + esi], bl
    mov bh, 4
    call Divide
; divide by 50
    mov byte [ebp + esi], 50
    mov bh, 4
    call Divide
; add wDamage's high byte; cap at 997; add MIN_NEUTRAL_DAMAGE
    mov esi, wDamage
    mov bh, [ebp + esi]           ; b = [wDamage]
    mov al, [ebp + hQuotient + 3]
    add al, bh
    mov [ebp + hQuotient + 3], al
    jnc .dont_cap_1
    mov al, [ebp + hQuotient + 2]
    inc al
    mov [ebp + hQuotient + 2], al
    test al, al
    jz .cap
.dont_cap_1:
    mov al, [ebp + hQuotient]
    mov bh, al
    mov al, [ebp + hQuotient + 1]
    or al, al
    jnz .cap
    mov al, [ebp + hQuotient + 2]
    cmp al, (MAX_NEUTRAL_DAMAGE - MIN_NEUTRAL_DAMAGE + 1) >> 8
    jb .dont_cap_2
    cmp al, ((MAX_NEUTRAL_DAMAGE - MIN_NEUTRAL_DAMAGE + 1) >> 8) + 1
    jae .cap
    mov al, [ebp + hQuotient + 3]
    cmp al, (MAX_NEUTRAL_DAMAGE - MIN_NEUTRAL_DAMAGE + 1) & 0xFF
    jae .cap
.dont_cap_2:
    inc esi                       ; wDamage+1
    mov al, [ebp + hQuotient + 3]
    mov bh, [ebp + esi]
    add al, bh
    mov [ebp + esi], al
    dec esi                       ; wDamage
    mov al, [ebp + hQuotient + 2]
    mov bh, [ebp + esi]
    adc al, bh
    mov [ebp + esi], al
    jc .cap
    mov al, [ebp + esi]
    cmp al, (MAX_NEUTRAL_DAMAGE - MIN_NEUTRAL_DAMAGE + 1) >> 8
    jb .dont_cap_3
    cmp al, ((MAX_NEUTRAL_DAMAGE - MIN_NEUTRAL_DAMAGE + 1) >> 8) + 1
    jae .cap
    inc esi
    mov al, [ebp + esi]
    dec esi
    cmp al, (MAX_NEUTRAL_DAMAGE - MIN_NEUTRAL_DAMAGE + 1) & 0xFF
    jb .dont_cap_3
.cap:
    mov al, (MAX_NEUTRAL_DAMAGE - MIN_NEUTRAL_DAMAGE) >> 8
    mov [ebp + esi], al           ; ld [hli],a
    inc esi
    mov al, (MAX_NEUTRAL_DAMAGE - MIN_NEUTRAL_DAMAGE) & 0xFF
    mov [ebp + esi], al
    dec esi                       ; ld [hld],a -> back to wDamage
.dont_cap_3:
    inc esi                       ; wDamage+1
    mov al, [ebp + esi]
    add al, MIN_NEUTRAL_DAMAGE
    mov [ebp + esi], al
    dec esi                       ; -> wDamage
    jnc .dont_floor
    inc byte [ebp + esi]
.dont_floor:
    mov al, 1
    test al, al
    ret

; ===========================================================================
; JumpToOHKOMoveEffect — OHKO moves compute damage via their effect handler.
; ===========================================================================
JumpToOHKOMoveEffect:
    call JumpMoveEffect
    mov al, [ebp + wMoveMissed]
    dec al
    ret

; ===========================================================================
; CriticalHitTest — sets wCriticalHitOrOHKO if this attack crits.
; ===========================================================================
CriticalHitTest:
    xor eax, eax
    mov [ebp + wCriticalHitOrOHKO], al
    mov al, [ebp + hWhoseTurn]
    test al, al
    mov al, [ebp + wEnemyMonSpecies]
    jnz .handleEnemy
    mov al, [ebp + wBattleMonSpecies]
.handleEnemy:
    mov [ebp + wCurSpecies], al
    call GetMonHeader
    mov al, [ebp + wMonHBaseSpeed]
    mov bh, al
    shr bh, 1                     ; b = base speed / 2
    mov al, [ebp + hWhoseTurn]
    test al, al
    mov esi, wPlayerMovePower
    mov edx, wPlayerBattleStatus2
    jz .calcCriticalHitProbability
    mov esi, wEnemyMovePower
    mov edx, wEnemyBattleStatus2
.calcCriticalHitProbability:
    mov al, [ebp + esi]           ; base power ([hld])
    dec esi
    test al, al
    jz .ret0                      ; ret z (0 power)
    dec esi
    mov bl, [ebp + esi]           ; c = move id
    mov al, [ebp + edx]
    test al, 1 << GETTING_PUMPED  ; focus energy?
    ; BUG(critical): "Critical Hit Ratio Error" — Focus Energy (and Dire Hit)
    ; are intended to quadruple the crit chance but a bit-shift error makes
    ; .focusEnergyUsed shr (halve) where the intent was to skip the later shl;
    ; combined with the normal-move shr below this quarters the crit ratio for
    ; non-high-crit moves instead of quadrupling it. Gen-1 behavior, preserved
    ; verbatim. pret ref: engine/battle/core.asm:CriticalHitTest,
    ; docs/references/yellow_glitches.md#battle-system (Critical Hit Ratio Error)
    jnz .focusEnergyUsed
    shl bh, 1                     ; base speed/2 * 2
    jnc .noFocusEnergyUsed
    mov bh, 0xFF                  ; cap at 255
    jmp .noFocusEnergyUsed
.focusEnergyUsed:
    shr bh, 1
.noFocusEnergyUsed:
    mov esi, HighCriticalMoves
.loop:
    mov al, [esi]                 ; flat program-image table -> [esi], NOT [ebp+esi]
    inc esi
    cmp al, bl
    je .highCritical
    inc al                        ; FF terminates ($FF+1=0 -> ZF)
    jnz .loop
    shr bh, 1                     ; normal move: /2
    jmp .skipHighCritical
.highCritical:
    shl bh, 1
    jnc .noCarry
    mov bh, 0xFF
.noCarry:
    shl bh, 1
    jnc .skipHighCritical
    mov bh, 0xFF
.skipHighCritical:
    call BattleRandom
    rol al, 1
    rol al, 1
    rol al, 1
    cmp al, bh
    jae .ret0                     ; ret nc (no crit)
    mov al, 1
    mov [ebp + wCriticalHitOrOHKO], al
    ret
.ret0:
    ret

; ===========================================================================
; AdjustDamageForMoveType — apply STAB (1.5x) and type effectiveness to wDamage.
; ===========================================================================
AdjustDamageForMoveType:
; player-turn values: attacker = player, defender = enemy
    mov al, [ebp + wBattleMonType1]
    mov bh, al                    ; b = attacker type 1
    mov al, [ebp + wBattleMonType2]
    mov bl, al                    ; c = attacker type 2
    mov al, [ebp + wEnemyMonType1]
    mov dh, al                    ; d = defender type 1
    mov al, [ebp + wEnemyMonType2]
    mov dl, al                    ; e = defender type 2
    mov al, [ebp + wPlayerMoveType]
    mov [ebp + wMoveType], al
    mov al, [ebp + hWhoseTurn]
    test al, al
    jz .next
; enemy-turn values: attacker = enemy, defender = player
    mov al, [ebp + wEnemyMonType1]
    mov bh, al
    mov al, [ebp + wEnemyMonType2]
    mov bl, al
    mov al, [ebp + wBattleMonType1]
    mov dh, al
    mov al, [ebp + wBattleMonType2]
    mov dl, al
    mov al, [ebp + wEnemyMoveType]
    mov [ebp + wMoveType], al
.next:
    mov al, [ebp + wMoveType]
    cmp al, bh
    je .stab
    cmp al, bl
    je .stab
    jmp .skipStab
.stab:
; hl = damage (big-endian); hl = floor(1.5 * damage)
    movzx eax, byte [ebp + wDamage]   ; high
    shl eax, 8
    mov al, [ebp + wDamage + 1]        ; low
    mov esi, eax                       ; hl = damage
    mov ebx, eax
    shr bx, 1                          ; bc = damage / 2
    movzx eax, bx
    add esi, eax                       ; hl = 1.5 * damage
    mov eax, esi
    shr eax, 8
    mov [ebp + wDamage], al            ; high
    mov eax, esi
    mov [ebp + wDamage + 1], al        ; low
    mov al, [ebp + wDamageMultipliers]
    or al, 1 << BIT_STAB_DAMAGE
    mov [ebp + wDamageMultipliers], al
.skipStab:
    mov al, [ebp + wMoveType]
    mov bh, al                         ; b = move type
    mov esi, TypeEffects               ; flat table -> [esi]
.loop:
    mov al, [esi]                      ; attacking type ([hli])
    inc esi
    cmp al, 0xFF
    je .done
    cmp al, bh
    jne .nextTypePair
    mov al, [esi]                      ; defending type ([hl])
    cmp al, dh
    je .match
    cmp al, dl
    je .match
    jmp .nextTypePair
.match:
    push esi
    push ebx
    inc esi                            ; -> effectiveness factor
    mov al, [ebp + wDamageMultipliers]
    and al, 1 << BIT_STAB_DAMAGE
    mov bh, al
    mov al, [esi]                      ; a = damage multiplier (factor*10)
    mov [ebp + hMultiplier], al
    add al, bh
    mov [ebp + wDamageMultipliers], al
    xor al, al
    mov [ebp + hMultiplicand], al
    mov al, [ebp + wDamage]            ; ld hl,wDamage; [hli]
    mov [ebp + hMultiplicand + 1], al
    mov al, [ebp + wDamage + 1]        ; [hld]
    mov [ebp + hMultiplicand + 2], al
    call Multiply
    mov byte [ebp + hDivisor], 10
    mov bh, 4
    call Divide
    mov al, [ebp + hQuotient + 2]
    mov [ebp + wDamage], al            ; ld [hli],a
    mov bh, al
    mov al, [ebp + hQuotient + 3]
    mov [ebp + wDamage + 1], al        ; ld [hl],a
    ; BUG(critical): "0 Damage Glitch" — pret's own comment: "if damage is 0,
    ; make the move miss; this only occurs if a move that would do 2 or 3
    ; damage is 0.25x effective against the target." A real hit that rounds
    ; to 0 damage against a dual-type resist is logged as a miss instead of a
    ; 0-damage hit. Gen-1 behavior, preserved verbatim. pret ref: engine/battle/
    ; core.asm:AdjustDamageForMoveType, docs/references/yellow_glitches.md
    ; #battle-system (0 Damage Glitch)
    or al, bh                          ; damage 0?
    jnz .skipTypeImmunity
    inc al
    mov [ebp + wMoveMissed], al
.skipTypeImmunity:
    pop ebx
    pop esi
.nextTypePair:
    inc esi
    inc esi
    jmp .loop
.done:
    ret

; ===========================================================================
; MoveHitTest — accuracy / mist / substitute / invulnerability checks.
; Sets wMoveMissed (1 = missed) and zeroes wDamage on miss.
; ===========================================================================
MoveHitTest:
    mov esi, wEnemyBattleStatus1       ; hl
    mov edx, wPlayerMoveEffect          ; de
    mov ebx, wEnemyMonStatus            ; bc
    mov al, [ebp + hWhoseTurn]
    test al, al
    jz .dreamEaterCheck
    mov esi, wPlayerBattleStatus1
    mov edx, wEnemyMoveEffect
    mov ebx, wBattleMonStatus
.dreamEaterCheck:
    mov al, [ebp + edx]
    cmp al, DREAM_EATER_EFFECT
    jne .swiftCheck
    mov al, [ebp + ebx]
    and al, SLP_MASK
    jz .moveMissed
.swiftCheck:
    mov al, [ebp + edx]
    cmp al, SWIFT_EFFECT
    je .hit                            ; Swift never misses
    call CheckTargetSubstitute         ; sets ZF; overwrites a
    jz .checkForDigOrFlyStatus
    cmp al, DRAIN_HP_EFFECT
    je .moveMissed
    cmp al, DREAM_EATER_EFFECT
    je .moveMissed
.checkForDigOrFlyStatus:
    test byte [ebp + esi], 1 << INVULNERABLE
    jnz .moveMissed
    mov al, [ebp + hWhoseTurn]
    test al, al
    jnz .enemyTurn
; player turn: enemy mist check
    mov al, [ebp + wPlayerMoveEffect]
    cmp al, ATTACK_DOWN1_EFFECT
    jb .skipEnemyMistCheck
    cmp al, HAZE_EFFECT + 1
    jb .enemyMistCheck
    cmp al, ATTACK_DOWN2_EFFECT
    jb .skipEnemyMistCheck
    cmp al, REFLECT_EFFECT + 1
    jb .enemyMistCheck
    jmp .skipEnemyMistCheck
.enemyMistCheck:
    mov al, [ebp + wEnemyBattleStatus2]
    test al, 1 << PROTECTED_BY_MIST
    jnz .moveMissed
.skipEnemyMistCheck:
    mov al, [ebp + wPlayerBattleStatus2]
    test al, 1 << USING_X_ACCURACY
    jnz .hit
    jmp .calcHitChance
.enemyTurn:
    mov al, [ebp + wEnemyMoveEffect]
    cmp al, ATTACK_DOWN1_EFFECT
    jb .skipPlayerMistCheck
    cmp al, HAZE_EFFECT + 1
    jb .playerMistCheck
    cmp al, ATTACK_DOWN2_EFFECT
    jb .skipPlayerMistCheck
    cmp al, REFLECT_EFFECT + 1
    jb .playerMistCheck
    jmp .skipPlayerMistCheck
.playerMistCheck:
    mov al, [ebp + wPlayerBattleStatus2]
    test al, 1 << PROTECTED_BY_MIST
    jnz .moveMissed
.skipPlayerMistCheck:
    mov al, [ebp + wEnemyBattleStatus2]
    test al, 1 << USING_X_ACCURACY
    jnz .hit
.calcHitChance:
    call CalcHitChance
    mov al, [ebp + wPlayerMoveAccuracy]
    mov bh, al
    mov al, [ebp + hWhoseTurn]
    test al, al
    jz .doAccuracyCheck
    mov al, [ebp + wEnemyMoveAccuracy]
    mov bh, al
.doAccuracyCheck:
    ; BUG(critical): "1/256 Miss Glitch" — the unsigned `jae` below misses
    ; whenever the roll equals the accuracy threshold, so even a nominal 100%
    ; move (accuracy capped at 255) still misses on roll=255 (1/256 chance).
    ; Gen-1 behavior, preserved verbatim. pret ref: engine/battle/core.asm:
    ; MoveHitTest (jr nc, .moveMissed / cp b), docs/references/yellow_glitches.md
    ; #battle-system (1/256 Miss Glitch)
    call BattleRandom
    cmp al, bh
    jae .moveMissed
.hit:
    ret
.moveMissed:
    xor al, al
    mov [ebp + wDamage], al
    mov [ebp + wDamage + 1], al
    inc al
    mov [ebp + wMoveMissed], al
    mov al, [ebp + hWhoseTurn]
    test al, al
    jz .playerTurn
    and byte [ebp + wEnemyBattleStatus1], ~(1 << USING_TRAPPING_MOVE)
    ret
.playerTurn:
    and byte [ebp + wPlayerBattleStatus1], ~(1 << USING_TRAPPING_MOVE)
    ret

; ===========================================================================
; CalcHitChance — scale move accuracy by attacker accuracy & target evasion mods.
; Result stored into wPlayerMoveAccuracy / wEnemyMoveAccuracy.
; ===========================================================================
CalcHitChance:
    mov esi, wPlayerMoveAccuracy
    mov al, [ebp + hWhoseTurn]
    test al, al
    mov al, [ebp + wPlayerMonAccuracyMod]
    mov bh, al
    mov al, [ebp + wEnemyMonEvasionMod]
    mov bl, al
    jz .next
    mov esi, wEnemyMoveAccuracy
    mov al, [ebp + wEnemyMonAccuracyMod]
    mov bh, al
    mov al, [ebp + wPlayerMonEvasionMod]
    mov bl, al
.next:
    mov al, 0x0E
    sub al, bl
    mov bl, al                         ; c = 14 - evasion mod
    xor al, al
    mov [ebp + hMultiplicand], al
    mov [ebp + hMultiplicand + 1], al
    mov al, [ebp + esi]
    mov [ebp + hMultiplicand + 2], al  ; multiplicand = move accuracy
    push esi
    mov dh, 2                          ; d = 2 iterations
.loop:
    push ebx
    mov esi, StatModifierRatios        ; flat table
    dec bh
    shl bh, 1
    mov bl, bh
    mov bh, 0
    movzx ecx, bx
    add esi, ecx                       ; hl = ratio entry
    pop ebx
    mov al, [esi]                      ; numerator ([hli])
    inc esi
    mov [ebp + hMultiplier], al
    call Multiply
    mov al, [esi]                      ; denominator ([hl])
    mov [ebp + hDivisor], al
    mov bh, 4
    call Divide
    mov al, [ebp + hQuotient + 3]
    mov bh, al
    mov al, [ebp + hQuotient + 2]
    or al, bh
    jnz .nextCalculation
; clamp result to at least 1
    mov byte [ebp + hQuotient + 2], 0
    mov byte [ebp + hQuotient + 3], 1
.nextCalculation:
    mov bh, bl                         ; b = c (next stage index)
    dec dh
    jnz .loop
    mov al, [ebp + hQuotient + 2]
    test al, al
    mov al, [ebp + hQuotient + 3]
    jz .storeAccuracy
    mov al, 0xFF                       ; > 0xFF -> cap at 255
.storeAccuracy:
    pop esi
    mov [ebp + esi], al
    ret

; ===========================================================================
; RandomizeDamage — multiply wDamage by a random ~85%..100% factor.
; ===========================================================================
RandomizeDamage:
    mov esi, wDamage
    mov al, [ebp + esi]                ; high byte ([hli])
    inc esi
    test al, al
    jnz .greaterThanOne
    mov al, [ebp + esi]                ; low byte
    cmp al, 2
    jb .ret                            ; ret c (damage 0 or 1)
.greaterThanOne:
    xor al, al
    mov [ebp + hMultiplicand], al
    dec esi                            ; -> wDamage
    mov al, [ebp + esi]                ; high ([hli])
    inc esi
    mov [ebp + hMultiplicand + 1], al
    mov al, [ebp + esi]                ; low ([hl])
    mov [ebp + hMultiplicand + 2], al
.loop:
    call BattleRandom
    ror al, 1
    cmp al, (85 * 0xFF / 100) + 1      ; 85 percent + 1 = 217
    jb .loop
    mov [ebp + hMultiplier], al
    call Multiply
    mov byte [ebp + hDivisor], 255
    mov bh, 4
    call Divide
    mov al, [ebp + hQuotient + 2]
    mov esi, wDamage
    mov [ebp + esi], al                ; [hli]
    inc esi
    mov al, [ebp + hQuotient + 3]
    mov [ebp + esi], al                ; [hl]
.ret:
    ret

; ===========================================================================
; AIGetTypeEffectiveness — single-type effectiveness of the enemy move vs the
; player mon, stored in wTypeEffectiveness (scaled by 10). Does NOT handle dual-
; type stacking (4x / cancel). Used by trainer AI move selection.
;
; BUG (faithful, original): initializes wTypeEffectiveness to $10 (16) rather
; than EFFECTIVE (10). Preserved at BUG_FIX_LEVEL 0; pret ref core.asm:5371.
; ===========================================================================
global AIGetTypeEffectiveness

AIGetTypeEffectiveness:
    mov al, [ebp + wEnemyMoveType]
    mov dh, al                       ; d = enemy move type
    mov esi, wBattleMonType1
    mov bh, [ebp + esi]              ; b = player type 1
    inc esi
    mov bl, [ebp + esi]              ; c = player type 2
    mov byte [ebp + wTypeEffectiveness], 0x10   ; BUG(faithful): should be 10
    mov esi, TypeEffects             ; flat table -> [esi]
.loop:
    mov al, [esi]
    inc esi
    cmp al, 0xFF
    je .ret
    cmp al, dh
    jne .nextTypePair1
    mov al, [esi]
    inc esi
    cmp al, bh
    je .done
    cmp al, bl
    je .done
    jmp .nextTypePair2
.nextTypePair1:
    inc esi
.nextTypePair2:
    inc esi
    jmp .loop
.done:
    mov al, [ebp + wTrainerClass]
    cmp al, LORELEI
    jne .ok
    mov al, [ebp + wEnemyMonSpecies]
    cmp al, DEWGONG
    jne .ok
    call BattleRandom
    cmp al, 0x66                     ; 40% chance to ignore effectiveness
    jb .ret
.ok:
    mov al, [esi]                    ; effectiveness factor
    mov [ebp + wTypeEffectiveness], al
.ret:
    ret
