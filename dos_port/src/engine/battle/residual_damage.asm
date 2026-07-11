; residual_damage.asm — HandlePoisonBurnLeechSeed (battle engine plan, Stage 7).
;
; Faithful translation of:
;   engine/battle/core.asm:HandlePoisonBurnLeechSeed         (pret line 479)
;   engine/battle/core.asm:HandlePoisonBurnLeechSeed_DecreaseOwnHP (line 559)
;   engine/battle/core.asm:HandlePoisonBurnLeechSeed_IncreaseEnemyHP (line 627)
;
; Behaviour:
;   Poison / Burn  — deal 1/16 maxHP (min 1) to the current mon at end of turn.
;   Badly Poisoned (Toxic) — multiply the per-tick damage by an escalating
;     counter (incremented inside DecreaseOwnHP on every call, i.e. each turn).
;   Leech Seed — drain the seeded mon by 1/16 maxHP, heal the opposing mon by
;     the same amount (capped at maxHP).
;
; GLITCH: Leech Seed + Toxic counter interaction.
;   pret comment: "note that the toxic ticks are considered even if the damage
;   is not poison (hence the Leech Seed glitch)". DecreaseOwnHP is called once
;   for Poison/Burn and once for Leech Seed; each call increments the toxic
;   counter. A Badly-Poisoned + Leech-Seeded mon therefore takes
;   (1/16 * maxHP * counter) drain from Leech Seed, and the counter keeps
;   climbing each turn. Carried faithfully — no BUG_FIX_LEVEL guard.
;   Also catalogued as "Toxic + Leech Seed Stacking" in
;   docs/references/yellow_glitches.md#battle-system. Safety: safe under DPMI
;   (bounded WRAM arithmetic, no ACE potential).
;
; GLITCH: Leech Seed overkill heal.
;   pret comment: "bc isn't updated if HP subtracted was capped to prevent
;   overkill". When the drained mon has less HP than 1/16 maxHP, DecreaseOwnHP
;   zeros that mon's HP but BX still holds the uncapped drain. IncreaseEnemyHP
;   heals the seeder by the uncapped amount — potentially more than was taken.
;   Carried faithfully. Safety: safe under DPMI (bounded WRAM arithmetic, no
;   ACE potential).
;
; GLITCH: toxic-counter-scales-Leech-Seed-too (the branch at .nonZeroDamage's
;   toxic-counter check below executes even when this routine was entered from
;   the Leech Seed path, not just Poison/Burn). This is the same underlying
;   mechanism as the "Leech Seed + Toxic counter interaction" GLITCH above, not
;   a distinct bug. Carried faithfully. Safety: safe under DPMI (bounded WRAM
;   arithmetic, no ACE potential).
;
; Deferred UI externs (Wave 2 battle front-end must supply these):
;   PrintText           — ESI = flat pointer to text label; prints a text box.
;   PlayMoveAnimation   — AL = animation ID; plays a battle animation.
;   DrawHUDsAndHPBars   — redraws both battle HUDs and HP bars.
;   DelayFrames         — BL = frame count; delays that many frames.
;   UpdateCurMonHPBar   — reads hWhoseTurn + wHPBar{Old,New,Max}HP to animate
;                         one side's HP bar. MUST preserve BX (pret push bc/pop bc).
;   HurtByPoisonText    — flat pointer to the "hurt by poison" text label.
;   HurtByBurnText      — flat pointer to the "hurt by burn" text label.
;   HurtByLeechSeedText — flat pointer to the "hurt by Leech Seed" text label.
;
; Shared-include aliases used here (added in the wave-1 PREP):
;   gb_memmap.inc    → wAnimationType (0xCC5B) / wPlayerToxicCounter (0xD06B) /
;                      wEnemyToxicCounter (0xD070)
;   gb_constants.inc → ABSORB (0x47) / BURN_PSN_ANIM (0xBA)
;
; Register map (CLAUDE.md): A=AL, BC=BX (B=BH C=BL), DE=DX (D=DH E=DL),
; HL=ESI, EBP=emulated GB memory base. GB memory = [EBP + addr].
; Flat (program image) labels are NOT EBP-relative.
;
; Build: nasm -f coff -I include/ -I . -o residual_damage.o residual_damage.asm

bits 32

%include "gb_macros.inc"
%include "gb_memmap.inc"
%include "gb_constants.inc"

; wAnimationType, wPlayerToxicCounter, wEnemyToxicCounter come from gb_memmap.inc;
; ABSORB / BURN_PSN_ANIM from gb_constants.inc (both added in the wave-1 PREP).

; ── Deferred UI externs ──────────────────────────────────────────────────────
extern PrintText
extern PlayMoveAnimation
extern DrawHUDsAndHPBars
extern DelayFrames
extern UpdateCurMonHPBar
extern HurtByPoisonText
extern HurtByBurnText
extern HurtByLeechSeedText

section .text

global HandlePoisonBurnLeechSeed
global HandlePoisonBurnLeechSeed_DecreaseOwnHP
global HandlePoisonBurnLeechSeed_IncreaseEnemyHP

; ===========================================================================
; HandlePoisonBurnLeechSeed
;
; Called at end of each turn to apply Poison/Burn/Leech-Seed residual damage.
; hWhoseTurn selects which mon's residuals are processed:
;   0 = player's turn → process player mon's residuals (wBattleMonHP/Status)
;   1 = enemy's turn  → process enemy mon's residuals  (wEnemyMonHP/Status)
;
; Returns: ZF=0, AL≠0  — mon still alive
;          ZF=1, AL=0  — mon fainted (HP became 0)
;
; pret: engine/battle/core.asm:HandlePoisonBurnLeechSeed (line 479)
; ===========================================================================
HandlePoisonBurnLeechSeed:
    ; Select HP pointer (ESI=HL) and status byte address (EDX=DE).
    mov esi, wBattleMonHP
    mov edx, wBattleMonStatus
    mov al, [ebp + hWhoseTurn]
    test al, al
    jz .playersTurn
    mov esi, wEnemyMonHP
    mov edx, wEnemyMonStatus
.playersTurn:

    ; ── Burn / Poison check ─────────────────────────────────────────────────
    mov al, [ebp + edx]
    and al, (1 << BRN) | (1 << PSN)
    jz .notBurnedOrPoisoned

    ; Select text label: default to poison text, override to burn if BRN bit set.
    ; (pret loads HurtByPoisonText first, then conditionally overwrites with
    ;  HurtByBurnText if the BRN flag is present — BRN bit is higher than PSN.)
    push esi                        ; save HP pointer around PrintText call
    mov esi, HurtByPoisonText
    mov al, [ebp + edx]
    test al, (1 << BRN)
    jz .poisoned
    mov esi, HurtByBurnText
.poisoned:
    call PrintText                  ; deferred UI — print hurt-by-burn/poison text

    ; Play burn/poison animation (wAnimationType=0 = move animation type).
    xor al, al
    mov [ebp + wAnimationType], al
    mov al, BURN_PSN_ANIM
    call PlayMoveAnimation          ; deferred UI — AL = animation ID

    pop esi                         ; restore HP pointer
    call HandlePoisonBurnLeechSeed_DecreaseOwnHP

.notBurnedOrPoisoned:
    ; ── Leech Seed check (SEEDED = bit 7 of wPlayer/EnemyBattleStatus2) ────
    ; pret: ld de, wPlayerBattleStatus2/wEnemyBattleStatus2 based on hWhoseTurn,
    ;       then "add a" (shifts SEEDED bit 7 into carry).
    mov edx, wPlayerBattleStatus2
    mov al, [ebp + hWhoseTurn]
    test al, al
    jz .playersTurn2
    mov edx, wEnemyBattleStatus2
.playersTurn2:
    test byte [ebp + edx], (1 << SEEDED)
    jz .notLeechSeeded

    ; Flip hWhoseTurn so the ABSORB animation fires from the seeder's side,
    ; then restore it before the drain math.
    push esi                        ; save HP pointer
    mov al, [ebp + hWhoseTurn]
    push eax                        ; save hWhoseTurn across animation
    xor al, 1
    mov [ebp + hWhoseTurn], al      ; flip turn for the animation
    xor al, al
    mov [ebp + wAnimationType], al
    mov al, ABSORB
    call PlayMoveAnimation          ; deferred UI — Leech Seed animation
    pop eax                         ; restore saved hWhoseTurn (low byte = value)
    mov [ebp + hWhoseTurn], al
    pop esi                         ; restore HP pointer

    ; Drain the seeded mon (BX = drain amount on return).
    ; GLITCH: if the mon is also Badly Poisoned, the toxic counter is incremented
    ; here too, scaling the drain by the (now twice-bumped) counter.
    call HandlePoisonBurnLeechSeed_DecreaseOwnHP
    ; GLITCH (overkill heal): BX may exceed actual HP taken if HP was < 1/16 maxHP.
    call HandlePoisonBurnLeechSeed_IncreaseEnemyHP  ; heals seeder by BX

    push esi
    mov esi, HurtByLeechSeedText
    call PrintText                  ; deferred UI
    pop esi                         ; restore HP pointer

.notLeechSeeded:
    ; ── Faint check ─────────────────────────────────────────────────────────
    ; pret: ld a, [hli] / or [hl] — test whether the current-mon HP is zero.
    ; ESI = hp_ptr (wBattleMonHP or wEnemyMonHP), pointing to HP high byte.
    mov al, [ebp + esi]             ; HP high byte
    or al, [ebp + esi + 1]          ; OR with HP low byte
    ; pret: ret nz (return if ZF=0 → alive). x86 has no conditional ret.
    jz .fainted
    ret                             ; HP > 0: alive — ZF=0, AL≠0
.fainted:
    ; HP == 0: mon fainted.
    call DrawHUDsAndHPBars          ; deferred UI — redraw HUDs
    mov bl, 20
    call DelayFrames                ; deferred UI — delay 20 frames
    xor al, al                      ; ZF=1, AL=0 → caller sees "fainted"
    ret

; ===========================================================================
; HandlePoisonBurnLeechSeed_DecreaseOwnHP
;
; Decreases the current mon's HP by 1/16 of its maxHP (min 1).
; If the mon has BADLY_POISONED (Toxic), the toxic counter is incremented and
; the per-tick damage is multiplied by the new counter value.
;
; On entry:  ESI = GB address of the mon's current HP high byte.
; On return: BX  = total damage applied (or uncapped amount if HP was < drain);
;            ESI = restored to entry value (HP pointer).
; Clobbers:  EAX, EDX, EDI (EDI used as 16-bit accumulator for toxic multiply).
;
; pret: engine/battle/core.asm:HandlePoisonBurnLeechSeed_DecreaseOwnHP (line 559)
; ===========================================================================
HandlePoisonBurnLeechSeed_DecreaseOwnHP:
    push esi                        ; push #1 — caller's HP pointer restore
    push esi                        ; push #2 — HP pointer for subtraction section

    ; ── Read MaxHP (big-endian 16-bit at hp_ptr + 14) ───────────────────────
    ; wBattleMonHP + 0xE = wBattleMonMaxHP; same gap for the enemy side.
    add esi, 0xE                    ; ESI → MaxHP high byte
    mov al, [ebp + esi]
    mov [ebp + wHPBarMaxHP + 1], al ; scratch (pret: ld [wHPBarMaxHP+1], a)
    mov bh, al                      ; BH = MaxHP high byte
    inc esi                         ; ESI → MaxHP low byte
    mov al, [ebp + esi]
    mov [ebp + wHPBarMaxHP], al     ; scratch (pret: ld [wHPBarMaxHP], a)
    mov bl, al                      ; BL = MaxHP low byte
    ; BX = MaxHP (BH:BL big-endian)

    ; ── Compute base damage = MaxHP / 16 ────────────────────────────────────
    ; pret: two 16-bit right-shifts (srl b / rr c pairs) then two BL-only shifts.
    ; For MaxHP < 1024: after the two 16-bit shifts BH = 0; result lives in BL.
    shr bh, 1
    rcr bl, 1
    shr bh, 1
    rcr bl, 1                       ; BX >>= 2 (16-bit; BH = 0 for MaxHP < 1024)
    shr bl, 1
    shr bl, 1                       ; BL >>= 2 more → BL = MaxHP / 16, BH = 0

    ; Minimum damage is 1 (pret: inc c if c == 0)
    test bl, bl
    jnz .nonZeroDamage
    mov bl, 1
.nonZeroDamage:
    ; BX = (BH=0, BL=per-tick damage)

    ; ── Toxic counter check and multiply ────────────────────────────────────
    ; pret selects the BADLY_POISONED flag from wPlayer/EnemyBattleStatus3
    ; and the toxic counter from wPlayer/EnemyToxicCounter based on hWhoseTurn.
    ; GLITCH: this branch executes even when called from the Leech Seed path,
    ; causing the toxic counter to scale Leech Seed drain too.
    mov esi, wPlayerBattleStatus3
    mov edx, wPlayerToxicCounter
    mov al, [ebp + hWhoseTurn]
    test al, al
    jz .playersTurn_toxic
    mov esi, wEnemyBattleStatus3
    mov edx, wEnemyToxicCounter
.playersTurn_toxic:
    test byte [ebp + esi], (1 << BADLY_POISONED)
    jz .noToxic

    ; Increment the toxic counter (pret: ld a, [de] / inc a / ld [de], a).
    mov al, [ebp + edx]
    inc al
    mov [ebp + edx], al             ; save incremented counter

    ; Multiply base damage BX by the counter (AL) via repeated addition:
    ; pret: ld hl, 0 / .loop: add hl, bc / dec a / jr nz / ld b, h / ld c, l
    ; Use EDI as the 16-bit HL accumulator (pushed to avoid clobbering caller).
    push edi
    xor edi, edi                    ; EDI = 0 (HL accumulator)
.toxicTicksLoop:
    add di, bx                      ; DI += BX (16-bit; pret: add hl, bc)
    dec al
    jnz .toxicTicksLoop
    movzx ebx, di                   ; BX = total damage (pret: ld b, h / ld c, l)
    pop edi

.noToxic:
    ; BX = total damage (BH:BL, 16-bit)

    ; ── Subtract damage from current HP ─────────────────────────────────────
    pop esi                         ; pop #2 → ESI = original HP ptr (high byte)
    inc esi                         ; ESI → HP low byte (pret: inc hl)

    ; Subtract low byte (pret: ld a, [hl] / sub c / ld [hld], a):
    mov al, [ebp + esi]
    mov [ebp + wHPBarOldHP], al     ; save old HP low byte
    sub al, bl                      ; HP_low -= damage_low
    mov [ebp + esi], al             ; store new HP_low (pret: ld [hld], a)
    mov [ebp + wHPBarNewHP], al     ; save new HP low byte
    dec esi                         ; ESI → HP high byte (pret: [hld] auto-dec)

    ; Subtract high byte with borrow (pret: ld a, [hl] / sbc b / ld [hl], a):
    mov al, [ebp + esi]
    mov [ebp + wHPBarOldHP + 1], al ; save old HP high byte
    sbb al, bh                      ; HP_high -= damage_high + borrow
    mov [ebp + esi], al             ; store new HP high byte
    mov [ebp + wHPBarNewHP + 1], al

    ; Overkill check (carry = result was negative):
    jnc .noOverkill
    ; Zero HP (pret: xor a / ld [hli], a / ld [hl], a):
    xor al, al
    mov [ebp + esi], al             ; zero HP high byte
    inc esi                         ; ESI → HP low byte (pret: [hli] auto-inc)
    mov [ebp + esi], al             ; zero HP low byte
    mov [ebp + wHPBarNewHP], al
    mov [ebp + wHPBarNewHP + 1], al
    dec esi                         ; restore ESI to HP high byte
    ; BX still holds uncapped damage (see Leech Seed overkill GLITCH in header)
.noOverkill:

    ; Update HP bar (pret: UpdateCurMonHPBar, which does push bc / pop bc).
    ; Push BX for safety in case the deferred impl forgets the pret contract.
    push ebx
    call UpdateCurMonHPBar          ; deferred UI
    pop ebx

    pop esi                         ; pop #1 → ESI = original HP ptr (for caller)
    ret

; ===========================================================================
; HandlePoisonBurnLeechSeed_IncreaseEnemyHP
;
; Heals the opposing mon (the Leech Seed attacker) by BX (the drain amount
; computed by DecreaseOwnHP). Caps at MaxHP.
;
; On entry:  ESI = seeded mon's HP pointer (caller's HL, pushed/restored here).
;            BX  = drain amount (from DecreaseOwnHP).
;            hWhoseTurn: 0 = player's turn → heal enemy; 1 = enemy's turn → heal player.
; On return: ESI = restored (caller's HP pointer).
;
; pret: engine/battle/core.asm:HandlePoisonBurnLeechSeed_IncreaseEnemyHP (line 627)
; ===========================================================================
HandlePoisonBurnLeechSeed_IncreaseEnemyHP:
    push esi                        ; save caller's HP pointer (seeded mon's)

    ; ── Select MaxHP pointer for the healing side ────────────────────────────
    ; pret: player's turn → heal enemy (wEnemyMonMaxHP);
    ;       enemy's turn  → heal player (wBattleMonMaxHP).
    mov esi, wEnemyMonMaxHP
    mov al, [ebp + hWhoseTurn]
    test al, al
    jz .playersTurn_heal
    mov esi, wBattleMonMaxHP
.playersTurn_heal:

    ; ── Read MaxHP of the healing mon ───────────────────────────────────────
    ; pret: ld a, [hli] (high byte → [wHPBarMaxHP+1], HL++);
    ;       ld a, [hl]  (low byte  → [wHPBarMaxHP],   HL stays).
    mov al, [ebp + esi]
    mov [ebp + wHPBarMaxHP + 1], al ; MaxHP high byte to scratch
    inc esi                         ; ESI → MaxHP low byte (pret: [hli] auto-inc)
    mov al, [ebp + esi]
    mov [ebp + wHPBarMaxHP], al     ; MaxHP low byte to scratch

    ; ── Navigate from MaxHP+1 to HP low byte ────────────────────────────────
    ; pret: ld de, wBattleMonHP - wBattleMonMaxHP = -14
    ;       add hl, de → HL = (MaxHP_low address) - 14 = HP_low address.
    ; The gap is the same for both sides:
    ;   wBattleMonHP (0xD014) - wBattleMonMaxHP (0xD022) = -14
    ;   wEnemyMonHP  (0xCFE5) - wEnemyMonMaxHP  (0xCFF3) = -14  (then +1 = HP_low)
    ; After ld a,[hli] ESI is at MaxHP_low (+1 from MaxHP base); -14 → HP_low.
    sub esi, 14                     ; ESI → HP low byte of the healing mon

    ; ── Add BX (drain amount) to current HP ─────────────────────────────────
    ; pret: ld a,[hl] / add c / ld [hld],a ; ld a,[hl] / adc b / ld [hli],a
    mov al, [ebp + esi]
    mov [ebp + wHPBarOldHP], al     ; old HP low byte
    add al, bl                      ; HP_low += damage_low (pret: add c)
    mov [ebp + esi], al             ; store new HP_low (pret: ld [hld], a)
    mov [ebp + wHPBarNewHP], al
    dec esi                         ; ESI → HP high byte (pret: [hld] auto-dec)

    mov al, [ebp + esi]
    mov [ebp + wHPBarOldHP + 1], al ; old HP high byte
    adc al, bh                      ; HP_high += damage_high + carry (pret: adc b)
    mov [ebp + esi], al             ; store new HP_high (pret: ld [hli], a)
    mov [ebp + wHPBarNewHP + 1], al
    inc esi                         ; ESI → HP low byte again (pret: [hli] auto-inc)

    ; ── Overheal clamp: if new HP > MaxHP, set HP = MaxHP ───────────────────
    ; pret reads MaxHP from the wHPBarMaxHP scratch (stored above), loads new HP
    ; from memory, then does a 16-bit subtraction to detect overflow.
    ; If HP - MaxHP >= 0 (no borrow), HP is >= MaxHP → clamp.
    mov al, [ebp + esi]             ; new HP low byte (pret: ld a, [hld])
    sub al, [ebp + wHPBarMaxHP]     ; HP_low - MaxHP_low (pret: sub c)
    dec esi                         ; ESI → HP high byte (pret: [hld] auto-dec)
    mov al, [ebp + esi]             ; new HP high byte (pret: ld a, [hl])
    sbb al, [ebp + wHPBarMaxHP + 1] ; HP_high - MaxHP_high - borrow (pret: sbc b)
    jc .noOverfullHeal              ; carry set → HP < MaxHP, no clamp

    ; Clamp HP to MaxHP (pret: ld a, b / ld [hli], a / ld a, c / ld [hl], a):
    mov al, [ebp + wHPBarMaxHP + 1] ; MaxHP high byte (pret: ld a, b)
    mov [ebp + esi], al             ; store to HP high byte (pret: ld [hli], a)
    mov [ebp + wHPBarNewHP + 1], al
    inc esi                         ; ESI → HP low byte
    mov al, [ebp + wHPBarMaxHP]     ; MaxHP low byte (pret: ld a, c)
    mov [ebp + esi], al             ; store to HP low byte
    mov [ebp + wHPBarNewHP], al
.noOverfullHeal:

    ; ── Update HP bar for the healing side ──────────────────────────────────
    ; pret flips hWhoseTurn so UpdateCurMonHPBar draws the correct (healed) side.
    mov al, [ebp + hWhoseTurn]
    xor al, 1
    mov [ebp + hWhoseTurn], al      ; flip turn (pret: ldh a,[hWhoseTurn] / xor $1)
    call UpdateCurMonHPBar          ; deferred UI
    mov al, [ebp + hWhoseTurn]
    xor al, 1
    mov [ebp + hWhoseTurn], al      ; restore turn

    pop esi                         ; restore caller's HP pointer
    ret
