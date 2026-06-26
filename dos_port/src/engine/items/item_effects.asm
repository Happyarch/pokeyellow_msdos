; item_effects.asm — non-UI item-use effect math (items layer, Stage 3).
;
; Source: engine/items/item_effects.asm (pret/pokeyellow). These are the pure
; data-mutation cores of the ItemUse* handlers, lifted out of their UI: the
; surrounding text ("used ITEM!"), menus, animations, and in-battle stat-copy
; are stubbed/omitted; only the WRAM mutations remain. Callers supply the target
; pointer and amount; we return CF for had-effect / no-effect.
;
;   WakeUpEntireParty  — Poke Flute: clear SLP for every party mon, flag wakes.
;   RestorePPAmount    — Ether/Max Ether/Elixer: raise a move's current PP.
;   ApplyHealingItem   — Potion/Revive family: add HP, clamp to (half) max HP.
;   CureStatusAilment  — Antidote/.../Full Heal: clear a status flag if present.
;   ApplyVitamin       — HP Up/.../Calcium: add 2560 stat exp (capped at 25600).
;   RareCandyLevelUp   — Rare Candy: +1 level, set min exp, recalc stats, grow HP.
;
; Register map: a=AL, b=BH, c=BL, hl=ESI, de=EDX. GB memory at [EBP+addr].
;
; DEFERRED: Func_d85d (ItemUseEvoStone applicability check) is NOT translated
; here. It walks EvosMovesPointerTable + FarCopyData to test whether the used
; stone evolves the selected mon, but the DOS port stores EvosMovesPointerTable
; with its own flat addressing (see src/engine/pokemon/evos_moves.asm) — the
; pret `add hl,bc` twice / copy-2-bytes-as-a-16-bit-pointer logic does not carry
; over verbatim. It belongs with the evolution path and is left for that work.
;
; Build: nasm -f coff -I include/ -I . -o item_effects.o item_effects.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

global WakeUpEntireParty
global RestorePPAmount
global ApplyHealingItem
global CureStatusAilment
global ApplyVitamin
global RareCandyLevelUp

extern CalcStats        ; home/move_mon.asm (BH=consider-exp, ESI=stat-exp ptr, EDX=dest)
extern CalcExperience   ; engine/pokemon/experience.asm (DH=level -> H_EXPERIENCE)

section .text

; ---------------------------------------------------------------------------
; WakeUpEntireParty — clear the Sleep status of every party mon (Poke Flute).
; In:  ESI (hl) = first party mon's status byte
;      BL       = sleep-clear mask (~SLP_MASK, the bits to keep)
;      ECX      = PARTY_LENGTH (number of mons to walk)
; Out: wWereAnyMonsAsleep = 1 if any mon was asleep and got woken.
; ---------------------------------------------------------------------------
WakeUpEntireParty:
    mov edx, PARTYMON_STRUCT_LENGTH
.loop:
    mov al, [ebp + esi]
    push eax
    and al, SLP_MASK
    jz .notAsleep
    mov byte [ebp + wWereAnyMonsAsleep], 1
.notAsleep:
    pop eax
    and al, bl                       ; remove Sleep status, keep other bits
    mov [ebp + esi], al
    add esi, edx
    dec ecx
    jnz .loop
    ret

; ---------------------------------------------------------------------------
; RestorePPAmount — restore PP of one move (Ether/Max Ether/Elixer/Max Elixer).
; In:  ESI (hl)        = the move's PP byte
;      [wMaxPP]        = the move's max PP
;      [wPPRestoreItem] = item id (MAX_ETHER fully restores)
; Faithfully reproduces the original Max-Ether/Max-Elixer bug: the full-restore
; path doesn't mask the PP-Up bits, so a maxed-PP move with PP Ups applied is
; not detected as "no effect".
; ---------------------------------------------------------------------------
RestorePPAmount:
    mov al, [ebp + wMaxPP]
    mov bl, al                       ; b (here bl) = max PP
    mov al, [ebp + wPPRestoreItem]
    cmp al, MAX_ETHER
    jz .fullyRestorePP

    mov al, [ebp + esi]
    and al, PP_MASK
    cmp al, bl                       ; already at max PP?
    jz .ret
    add al, 10                       ; +10 PP
    cmp al, bl                       ; meets/exceeds max?
    jnc .storeNewAmount              ; if so leave bl = max
    mov bl, al                       ; else new amount is the cap
.storeNewAmount:
    mov al, [ebp + esi]
    and al, PP_UP_MASK               ; keep the PP-Up bits
    add al, bl
    mov [ebp + esi], al
.ret:
    ret

.fullyRestorePP:
    ; BUG (faithful): upper two PP-Up bits not masked here (pret intentional).
    mov al, [ebp + esi]
    cmp al, bl
    jz .ret
    jmp .storeNewAmount

; ---------------------------------------------------------------------------
; ApplyHealingItem — add HP to a mon and clamp to its max HP (potions/revives).
; In:  ESI (hl) = mon's current-HP low byte (HP is big-endian: low byte first,
;                 high byte at hl-1, as in the party struct)
;      BL       = heal amount (caller picks it from the item; UI selection
;                 omitted). REVIVE sets HP to half max instead of adding.
;      [wCurItem] = item id (REVIVE / HYPER_POTION / MAX_REVIVE branch points)
; Out: mon HP updated; wHPBarNewHP (word) = the new current HP for the UI bar.
; ---------------------------------------------------------------------------
ApplyHealingItem:
    mov al, [ebp + esi]
    add al, bl
    mov [ebp + esi], al
    mov [ebp + wHPBarNewHP], al

    dec esi                          ; -> HP high byte
    mov al, [ebp + esi]
    mov [ebp + wHPBarNewHP+1], al
    jnc .noCarry
    inc al
    mov [ebp + esi], al
    mov [ebp + wHPBarNewHP+1], al
.noCarry:
    inc esi                          ; -> HP low byte
    mov edx, esi                     ; de = current-HP low byte

    mov ecx, edx
    add ecx, (MON_MAXHP + 1) - (MON_HP + 1)  ; ecx -> max-HP low byte

    mov al, [ebp + wCurItem]
    cmp al, REVIVE
    jz .setCurrentHPToHalfMaxHP

    ; compare current HP with max HP (16-bit, big-endian)
    mov al, [ebp + ecx]              ; max HP low
    mov bl, al
    mov al, [ebp + edx]              ; current HP low
    sub al, bl
    dec ecx                          ; -> max HP high (dec preserves CF)
    dec edx                          ; -> current HP high
    mov bl, [ebp + ecx]              ; max HP high
    mov al, [ebp + edx]              ; current HP high
    sbb al, bl
    jnc .setCurrentHPToMaxHp         ; current HP >= max HP after healing

    mov al, [ebp + wCurItem]
    cmp al, HYPER_POTION
    jc .setCurrentHPToMaxHp          ; Full Restore / Max Potion
    cmp al, MAX_REVIVE
    jz .setCurrentHPToMaxHp
    ret

.setCurrentHPToHalfMaxHP:
    dec ecx                          ; -> max HP high
    dec edx                          ; -> current HP high
    mov al, [ebp + ecx]
    shr al, 1                        ; max high >> 1, bit0 -> CF
    mov [ebp + edx], al
    mov [ebp + wHPBarNewHP+1], al
    inc ecx                          ; -> max HP low (inc preserves CF)
    inc edx                          ; -> current HP low
    mov al, [ebp + ecx]
    rcr al, 1                        ; rotate CF into max low >> 1
    mov [ebp + edx], al
    mov [ebp + wHPBarNewHP], al
    ret

.setCurrentHPToMaxHp:
    mov al, [ebp + ecx]              ; max HP high
    mov [ebp + edx], al
    mov [ebp + wHPBarNewHP+1], al
    inc ecx                          ; -> low bytes
    inc edx
    mov al, [ebp + ecx]              ; max HP low
    mov [ebp + edx], al
    mov [ebp + wHPBarNewHP], al
    ret

; ---------------------------------------------------------------------------
; CureStatusAilment — clear a status flag the item heals, if present.
; In:  ESI (hl)   = mon's status byte
;      [wCurItem] = the status-heal item id (Full Heal cures everything)
; Out: CF set if a curable status was present and cleared; CF clear (no effect)
;      otherwise. The cured-status message id (pret's b register) and in-battle
;      stat copy are UI/battle integration and omitted here.
; ---------------------------------------------------------------------------
CureStatusAilment:
    mov al, [ebp + wCurItem]
    mov cl, (1 << PSN)
    cmp al, ANTIDOTE
    jz .checkMonStatus
    mov cl, (1 << BRN)
    cmp al, BURN_HEAL
    jz .checkMonStatus
    mov cl, (1 << FRZ)
    cmp al, ICE_HEAL
    jz .checkMonStatus
    mov cl, SLP_MASK
    cmp al, AWAKENING
    jz .checkMonStatus
    mov cl, (1 << PAR)
    cmp al, PARLYZ_HEAL
    jz .checkMonStatus
    mov cl, 0xff                     ; FULL_HEAL: cure everything
.checkMonStatus:
    mov al, [ebp + esi]
    and al, cl                       ; any curable status set?
    jz .noEffect
    xor al, al
    mov [ebp + esi], al              ; clear status in party data
    stc
    ret
.noEffect:
    clc
    ret

; ---------------------------------------------------------------------------
; ApplyVitamin — add 2560 (256*10) stat experience for the matching stat.
; In:  ESI (hl)   = mon's party-struct base
;      [wCurItem] = vitamin id (HP_UP..CALCIUM; picks the stat by offset)
; Out: CF set if applied; CF clear (no effect) if that stat already has >= 25600
;      stat exp (MSB >= 100). Caller follows up with GetMonHeader + CalcStats to
;      re-derive the stats (that recalc needs the loaded header — UI-adjacent).
; The stat-exp word is big-endian; we touch only its MSB (the +2560 step).
; ---------------------------------------------------------------------------
ApplyVitamin:
    movzx ebx, byte [ebp + wCurItem]
    sub bl, HP_UP                    ; stat index 0..4
    add bl, bl                       ; *2 (word stride)
    lea ecx, [esi + MON_HP_EXP]      ; ecx -> HP stat-exp MSB
    add ecx, ebx                     ; -> chosen stat-exp MSB
    mov al, [ebp + ecx]
    cmp al, 100                      ; already >= 25600 stat exp?
    jnc .noEffect
    add al, 10                       ; +2560 stat exp
    jnc .store                       ; (al < 100 here, so carry is impossible)
    mov al, 255
.store:
    mov [ebp + ecx], al
    stc
    ret
.noEffect:
    clc
    ret

; ---------------------------------------------------------------------------
; RareCandyLevelUp — raise the mon one level: set experience to the new level's
; minimum, recalculate stats, and add the max-HP gain to current HP.
; In:  ESI (hl) = mon's party-struct base. PRECONDITION: GetMonHeader has loaded
;      this mon's base stats into wMonHeader (CalcStats reads it), exactly as
;      pret's shared .useVitamin entry does before reaching .useRareCandy.
; Out: CF set if leveled (level/exp/stats/HP updated, [wCurEnemyLevel] = new
;      level); CF clear (no effect) if already MAX_LEVEL. Move-learning,
;      evolution, the stats box and party-menu redraw are UI/engine follow-ups
;      handled elsewhere (deferred), so they are not done here.
; ---------------------------------------------------------------------------
RareCandyLevelUp:
    mov al, [ebp + esi + MON_LEVEL]
    cmp al, MAX_LEVEL
    jz .noEffect
    inc al
    mov [ebp + esi + MON_LEVEL], al
    mov [ebp + wCurEnemyLevel], al

    mov dh, al                       ; CalcExperience: DH = new level
    push esi
    call CalcExperience              ; -> H_EXPERIENCE (3 bytes, big-endian)
    pop esi
    ; copy H_EXPERIENCE to the mon's experience BEFORE any Multiply/CalcStats —
    ; H_EXPERIENCE aliases H_MULTIPLICAND, which CalcStats clobbers.
    mov al, [ebp + H_EXPERIENCE]
    mov [ebp + esi + MON_EXP], al
    mov al, [ebp + H_EXPERIENCE + 1]
    mov [ebp + esi + MON_EXP + 1], al
    mov al, [ebp + H_EXPERIENCE + 2]
    mov [ebp + esi + MON_EXP + 2], al

    ; remember old max HP (big-endian) so we can add the gain to current HP
    mov bh, [ebp + esi + MON_MAXHP]
    mov bl, [ebp + esi + MON_MAXHP + 1]
    push ebx
    push esi
    call RecalcMonStats              ; rewrites the 5 stats incl. new max HP
    pop esi
    pop ebx                          ; bh:bl = old max HP

    mov al, [ebp + esi + MON_MAXHP + 1]   ; new max HP low
    sub al, bl
    mov cl, al                            ; cl = HP gained, low
    mov al, [ebp + esi + MON_MAXHP]       ; new max HP high
    sbb al, bh
    mov ch, al                            ; ch = HP gained, high

    mov al, [ebp + esi + MON_HP + 1]      ; current HP low
    add al, cl
    mov [ebp + esi + MON_HP + 1], al
    mov al, [ebp + esi + MON_HP]          ; current HP high
    adc al, ch
    mov [ebp + esi + MON_HP], al
    stc
    ret
.noEffect:
    clc
    ret

; RecalcMonStats — pret .recalculateStats: CalcStats over the mon at ESI (base),
; considering stat exp. In: ESI = struct base. Tail-calls CalcStats (clobbers
; ESI/EDX/EBX and the H_MULTIPLICAND scratch); callers save the base if needed.
RecalcMonStats:
    mov edx, esi
    add edx, MON_STATS               ; de -> stats destination
    add esi, MON_EXP + 2             ; hl -> exp LSB == stat-exp base for CalcStat
    mov bh, 1                        ; consider stat exp
    jmp CalcStats
