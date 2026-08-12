; pikachu_happiness.asm — mirror of pret engine/events/pikachu_happiness.asm.
;
; Source (faithful translation): engine/events/pikachu_happiness.asm:1-118,
; routine + both data tables, which pret keeps in this same engine file.
;
; PORTED 2026-08-12 (battle plan 3d). It was the last ret-only stub in
; battle_exp_stubs.asm. NINE call sites were already live and inert against it:
; GainExperience (level-up), ItemUseMedicine (x2), ItemUseTMHM, ItemUseXAccuracy,
; ItemUseGuardSpec, ItemUseDireHit, ItemUseXStat, and BillsPCDeposit. All nine
; now do something.
;
; WHAT IT DOES. Given a reason code in D (PIKAHAPPY_*), it adjusts
; wPikachuHappiness by a delta that depends on BOTH the reason and which
; hundred the current happiness sits in, then may set wPikachuMood.
;
; THE GATE IS NOT THE SAME FOR EVERY REASON. PIKAHAPPY_GYMLEADER and
; PIKAHAPPY_WALKING ask whether the starter Pikachu is alive ANYWHERE in the
; party (IsStarterPikachuAliveInOurParty); every other reason asks whether the
; mon currently being acted on IS the starter Pikachu
; (IsThisPartyMonStarterPikachu). Both return CF, and both are already
; translated in src/engine/pikachu/pikachu_status.asm.
;
; TWO ORIGINAL-GAME QUIRKS, REPRODUCED, NOT FIXED:
;   * The table index is `dec c` then three `add hl, bc` — a multiply by 3 with
;     no bounds check, so a reason code outside 1..11 reads past the table.
;     Callers only ever pass the constants, which is the same guarantee pret
;     relies on.
;   * The sign test on the delta is `cp 100`, not `cp 128`. pret's own comment
;     calls this "inexplicable": deltas of 100..127 would be treated as negative
;     if any existed. None do — the largest positive entry is 5 — so it is
;     unreachable rather than wrong, and it is left exactly as the ROM has it.
;
; DATA PLACEMENT. HappinessChangeTable and PikachuMoods live HERE because pret
; defines them here, in engine/, not under data/. That is the mirror rule; the
; port's data-layer rule covers labels pret keeps in data/.
;
; DEVIATION{class=banking; pret=engine/events/pikachu_happiness.asm:ModifyPikachuHappiness; behavior=the two callfar gates are plain calls; evidence=the port has one flat address space so a far call is an ordinary call - the same standing convention SwitchPlayerMon and DoubleOrHalveSelectedStats already carry; lifetime=permanent while the port is flat-addressed}
;
; DEVIATION{class=projection; pret=engine/events/pikachu_happiness.asm:ModifyPikachuHappiness; behavior=HappinessChangeTable and PikachuMoods are walked as flat program pointers with [esi] while wPikachuHappiness and wPikachuMood stay GB-relative; evidence=both tables are Tier-1 data emitted into the port image rather than into emulated GB memory, the same split CalculateModifiedStat uses for StatModifierRatios, and the index arithmetic is unchanged; lifetime=permanent while the port keeps generated tables in the program image}
;
; Register map (CLAUDE.md): A=AL, B=BH, C=BL, D=DH, E=DL, HL=ESI,
; EBP = GB base, [ebp+addr].
;
; Build: nasm -f coff -I include/ -I . -o pikachu_happiness.o pikachu_happiness.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

extern IsThisPartyMonStarterPikachu     ; engine/pikachu/pikachu_status.asm — CF = it is
extern IsStarterPikachuAliveInOurParty  ; engine/pikachu/pikachu_status.asm — CF = alive

global ModifyPikachuHappiness

section .text

; ---------------------------------------------------------------------------
; ModifyPikachuHappiness — pret pikachu_happiness.asm:1.
; In: DH (pret D) = a PIKAHAPPY_* reason code.
; ---------------------------------------------------------------------------
ModifyPikachuHappiness:
    mov al, dh                          ; ld a, d
    cmp al, PIKAHAPPY_GYMLEADER
    je .checkanywhereinparty            ; jr z
    cmp al, PIKAHAPPY_WALKING
    je .checkanywhereinparty            ; jr z
    push edx                            ; push de
    call IsThisPartyMonStarterPikachu   ; callfar — CF = the acted-on mon is it
    pop edx                             ; pop de (flag-neutral, as on SM83)
    jnc .ret                            ; ret nc
    jmp .proceed                        ; jr .proceed

.checkanywhereinparty:
    push edx                            ; push de
    call IsStarterPikachuAliveInOurParty ; callfar — CF = alive somewhere
    pop edx
    jnc .ret                            ; ret nc

.proceed:
    push edx                            ; push de — D (the reason) is needed again
    ; Divide wPikachuHappiness by 100, keeping the integer part in E.
    mov dl, 0                           ; ld e, $0
    mov al, [ebp + wPikachuHappiness]
    cmp al, 100
    jb .happiness_div_100               ; jr c
    inc dl
    cmp al, 200
    jb .happiness_div_100               ; jr c
    inc dl
.happiness_div_100:
    ; HappinessChangeTable[(D - 1) * 3 + E] — three bytes per reason, one per
    ; happiness hundred.
    mov bl, dh                          ; ld c, d
    dec bl                              ; dec c
    mov bh, 0                           ; ld b, $0
    mov esi, HappinessChangeTable       ; FLAT table from here to the store
    movzx ecx, bx
    add esi, ecx                        ; add hl, bc
    add esi, ecx                        ; add hl, bc
    add esi, ecx                        ; add hl, bc   (three times = *3)
    mov dh, 0                           ; ld d, $0
    movzx ecx, dx
    add esi, ecx                        ; add hl, de
    mov al, [esi]                       ; ld a, [hl] — the delta
    ; Positive delta: take min($ff, delta + happiness).
    ; Negative delta: take max($00, delta + happiness).
    ; The threshold is 100, not 128 — pret's "inexplicable" comparison, kept.
    cmp al, 100
    mov al, [ebp + wPikachuHappiness]   ; ld a,[…] — flag-neutral, CF survives
    jae .negative                       ; jr nc
    add al, [esi]                       ; add [hl]
    jnc .okay                           ; jr nc
    mov al, -1                          ; saturate high
    jmp .okay                           ; jr .okay
.negative:
    add al, [esi]                       ; add [hl]
    jc .okay                            ; jr c
    xor al, al                          ; saturate low
.okay:
    mov [ebp + wPikachuHappiness], al

    ; PikachuMoods[D - 1] — one byte per reason.
    pop edx                             ; pop de — D is the reason again
    dec dh                              ; dec d
    mov esi, PikachuMoods               ; FLAT table
    mov dl, dh                          ; ld e, d
    mov dh, 0                           ; ld d, $0
    movzx ecx, dx
    add esi, ecx                        ; add hl, de
    mov al, [esi]                       ; ld a, [hl]
    mov bh, al                          ; ld b, a — the candidate mood
    ; $80 means "leave the mood alone".
    cmp al, 0x80
    je .done                            ; jr z
    mov al, [ebp + wPikachuMood]        ; flag-neutral: the CF above survives
    jb .decreased                       ; jr c — candidate < $80, a sad mood
    ; Happy mood: only raise it, and only when no emotion override is pending.
    cmp al, bh                          ; cp b
    jae .done                           ; jr nc
    mov al, [ebp + wPikachuEmotionModifier]
    test al, al                         ; and a
    jnz .done                           ; jr nz
    jmp .update_mood                    ; jr .update_mood
.decreased:
    ; Sad mood: only lower it.
    cmp al, bh                          ; cp b
    jb .done                            ; jr c
.update_mood:
    mov al, bh                          ; ld a, b
    mov [ebp + wPikachuMood], al
.done:
.ret:
    ret

section .data

; HappinessChangeTable — pret pikachu_happiness.asm:95. Three signed deltas per
; reason: happiness < 100, < 200, and >= 200. Rows are in PIKAHAPPY_* order,
; which is why the index is (reason - 1) * 3.
HappinessChangeTable:
    ; Increase
    db   5,   3,   2        ; PIKAHAPPY_LEVELUP        — gained a level
    db   5,   3,   2        ; PIKAHAPPY_USEDITEM       — HP restore
    db   1,   1,   0        ; PIKAHAPPY_USEDXITEM      — used an X item
    db   3,   2,   1        ; PIKAHAPPY_GYMLEADER      — challenged a Gym Leader
    db   1,   1,   0        ; PIKAHAPPY_USEDTMHM       — taught a TM/HM
    db   2,   1,   1        ; PIKAHAPPY_WALKING        — walking around
    ; Decrease
    db  -3,  -3,  -5        ; PIKAHAPPY_DEPOSITED      — boxed
    db  -1,  -1,  -1        ; PIKAHAPPY_FAINTED        — fainted in battle
    db  -5,  -5, -10        ; PIKAHAPPY_PSNFNT         — fainted to poison outside battle
    db  -5,  -5, -10        ; PIKAHAPPY_CARELESSTRAINER — fainted to a mon 30+ levels higher
    db -10, -10, -20        ; PIKAHAPPY_TRADE          — traded away

; PikachuMoods — pret pikachu_happiness.asm:109. One candidate mood per reason;
; $80 means "do not touch the mood". pret labels four of these Unknown and the
; comments below keep its wording rather than inventing meanings.
PikachuMoods:
    ; Increase
    db 0x8a                 ; PIKAHAPPY_LEVELUP
    db 0x83                 ; PIKAHAPPY_USEDITEM
    db 0x80                 ; PIKAHAPPY_USEDXITEM   (pret: "Teach TM/HM")
    db 0x80                 ; PIKAHAPPY_GYMLEADER   (pret: "Challenged Gym Leader")
    db 0x94                 ; PIKAHAPPY_USEDTMHM    (pret: Unknown, d = 5)
    db 0x80                 ; PIKAHAPPY_WALKING     (pret: Unknown, d = 6)
    ; Decrease
    db 0x62                 ; PIKAHAPPY_DEPOSITED
    db 0x6c                 ; PIKAHAPPY_FAINTED
    db 0x62                 ; PIKAHAPPY_PSNFNT      (pret: Unknown, d = 9)
    db 0x6c                 ; PIKAHAPPY_CARELESSTRAINER (pret: Unknown, d = 10)
    db 0x00                 ; PIKAHAPPY_TRADE       (pret: Unknown, d = 11)
