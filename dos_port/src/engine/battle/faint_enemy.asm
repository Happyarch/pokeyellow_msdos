; faint_enemy.asm — battle-swarm subsystem C, worker task "faint_enemy".
;
; Faithful SM83->x86 translation of pret engine/battle/core.asm:741-867
; (FaintEnemyPokemon), including its EndLowHealthAlarm/AnyEnemyPokemonAliveCheck
; neighbors' referenced helpers only where FaintEnemyPokemon itself calls them.
;
; Register map (project-wide, CLAUDE.md): A=AL; F.Z->ZF, F.C->CF;
; BC=EBX (B=BH,C=BL); DE=EDX (D=DH,E=DL); HL=ESI (full 32-bit);
; EBP=emulated GB base, so GB [addr] = [ebp+addr]. `ld a,[hli]` = read
; [ebp+esi] then inc esi. `srl [hl]` = shr byte [ebp+esi],1.
;
; Linked into the live EXE (Makefile FRONTEND_SRCS, battle-swarm-C). Consumed by
; HandleEnemyMonFainted / HandlePlayerMonFainted (core.asm). RemoveFaintedPlayerMon +
; SlideDownFaintedMonPic are defined in faint_switch.asm.

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_macros.inc"

; =============================================================================
; === NEEDS-INTEGRATION ===
; =============================================================================
;
; 1. TRUE — pret constants/misc_constants.asm:3 `DEF TRUE EQU 1`. Not defined
;    anywhere in dos_port/include/*.inc. Used for wBoostExpByExpAll = TRUE
;    (core.asm:857). Move into gb_constants.inc when integrating.
%ifndef TRUE
TRUE equ 1
%endif

; 2. wEnemyStatsToDouble / wEnemyStatsToHalve — now defined directly in
;    gb_memmap.inc (0xD064/0xD065, = wEnemyBattleStatus1 - 2/-1), so the
;    %ifndef guard below is inert. Kept only as a fallback.
%ifndef wEnemyStatsToDouble
wEnemyStatsToDouble equ wEnemyBattleStatus1 - 2   ; = 0xD064
wEnemyStatsToHalve  equ wEnemyBattleStatus1 - 1   ; = 0xD065
%endif

; 3. EXP_ALL — item id constant, not defined anywhere in gb_constants.inc or
;    dos_port/assets (grepped the whole dos_port/ tree). Value from pret
;    constants/item_constants.asm:87 (`const EXP_ALL` is the 76th entry in the
;    0-based `const_value` chain starting at NO_ITEM=$00, i.e. $4B). Move into
;    gb_constants.inc when integrating.
%ifndef EXP_ALL
EXP_ALL equ 0x4B
%endif

; 4. MUSIC_DEFEATED_WILD_MON — victory jingle id ($F9), from assets/audio_constants.inc
;    (not included here to avoid pulling the whole audio table). Local guard mirrors
;    the constants above.
%ifndef MUSIC_DEFEATED_WILD_MON
MUSIC_DEFEATED_WILD_MON equ 0xF9
%endif

; 4. RemoveFaintedPlayerMon — grepped the whole dos_port/ tree; genuinely does
;    not exist yet (only referenced in a TODO(faithful) comment at
;    src/engine/battle/core.asm:2191). Sibling routine (pret core.asm, the
;    HandlePlayerMonFainted counterpart) that zeroes BOTH bytes of
;    wPlayerBideAccumulatedDamage. Declared extern per the task brief; the
;    swarm root must add the real definition (or a stub matching its pret
;    contract: no input registers, zeroes wBattleMonHP-word-fainted-mon state)
;    before this file can link.
;
; 5. SlideDownFaintedMonPic — ANIMATION=OFF central stub. Also does not exist
;    anywhere in the port yet (core.asm:2175 TODO(faithful) mentions it by
;    name only; no core_stubs.asm entry). Declared extern + called at the
;    faithful call site (matching pret's hlcoord 12,5 / decoord 12,6 pixel-
;    slide animation, which is pure graphics and out of scope for this
;    logic-only routine per the ANIMATION=OFF leaf-stub convention). The
;    swarm root must add a `ret`-only stub to core_stubs.asm (or a real
;    animation) before this file can link.
;
; =============================================================================

global FaintEnemyPokemon

extern ReadPlayerMonCurHPAndStatus     ; src/engine/battle/core.asm (stub today, faithful call site)
extern AddNTimes                       ; src/home/array.asm — ESI=base,BX=stride,AL=count -> ESI advances
extern ClearScreenArea                 ; src/home/copy2.asm — ESI=W_TILEMAP dest, BH=rows, BL=width
extern RemoveFaintedPlayerMon          ; NEEDS-INTEGRATION (see block above) — sibling file, missing
extern AnyPartyAlive                   ; src/engine/overworld/wild_encounter_check.asm — out: DH = OR of all party HP bytes (nz => someone alive)
extern PrintBattleText                 ; src/engine/battle/core.asm — in: EAX = flat ptr to battle_text.inc stream
extern PrintEmptyString                ; src/engine/battle/battle_exp_stubs.asm (currently a bare ret stub)
extern SaveScreenTilesToBuffer1        ; src/engine/battle/battle_menu.asm — no args, snapshots screen
extern IsItemInBag                     ; src/home/item_predicates.asm — in: BH = item id; out: ZF (1 = not in bag), AL = qty
extern GainExperience                  ; src/engine/battle/experience.asm — no args, reads wBoostExpByExpAll/wPartyGainExpFlags
extern SlideDownFaintedMonPic          ; NEEDS-INTEGRATION (see block above) — central ANIMATION=OFF stub, missing
extern EnemyMonFaintedText             ; dos_port/assets/battle_text.inc (global label, battle_text stream)
extern EndLowHealthAlarm               ; src/audio/play_battle_music.asm — clears wLowHealthAlarm + CHAN5
extern PlayBattleVictoryMusic          ; src/audio/play_battle_music.asm — AL=music id, plays victory jingle

section .bss
; Local scratch: pret uses `push af` / `pop af` to carry the "does the player
; have EXP_ALL" ZF result across the halving loop and the first GainExperience
; call. x86 EFLAGS are not guaranteed to survive a `call` (GainExperience
; clobbers freely), so the boolean is parked in memory instead of relying on
; ZF/pushfd across the call boundary.
faint_enemy_has_exp_all: resb 1

section .text

; ---------------------------------------------------------------------------
; FaintEnemyPokemon — pret engine/battle/core.asm:741-867.
;
; No caller-set registers required (pure GB-memory / extern-call routine,
; matching pret's parameterless call convention). Clobbers all GP registers
; (matches pret: acts as a call boundary with several nested calls).
; ---------------------------------------------------------------------------
FaintEnemyPokemon:
    call ReadPlayerMonCurHPAndStatus

    ; --- trainer-only: zero the fainted enemy's party-slot HP word ---
    mov al, [ebp + wIsInBattle]
    dec al
    jz .wild                              ; wIsInBattle == 1 (wild) -> skip

    mov al, [ebp + wEnemyMonPartyPos]     ; ld a, [wEnemyMonPartyPos]
    mov esi, wEnemyMon1HP                 ; ld hl, wEnemyMon1HP
    mov bx, PARTYMON_STRUCT_LENGTH        ; ld bc, PARTYMON_STRUCT_LENGTH
    call AddNTimes                        ; hl = &party-slot HP word
    mov byte [ebp + esi], 0               ; ld [hli], a  (a=0)
    inc esi
    mov byte [ebp + esi], 0               ; ld [hl], a

.wild:
    and byte [ebp + wPlayerBattleStatus1], (~(1 << ATTACKING_MULTIPLE_TIMES)) & 0xFF
                                           ; res ATTACKING_MULTIPLE_TIMES, [hl]

    ; BUG(critical): Gen-1 zeroes only the high byte of wPlayerBideAccumulatedDamage
    ; (link desync) — pret core.asm:756-766, docs/bugs_and_glitches.md. Preserved by default.
    ; Endianness confirmed against pret core.asm:3662-3681 (adds to "+1" first with
    ; `add c`, then to the base "+0" with `adc b` after `ld hl,...+1`/`ld a,[hld]`):
    ; the BASE address (+0) is the HIGH byte pret's `ld [wPlayerBideAccumulatedDamage],a`
    ; targets; "+1" is the low byte the real bug leaves untouched.
%if BUG_FIX_LEVEL >= 1
    mov byte [ebp + wPlayerBideAccumulatedDamage + 0], 0
    mov byte [ebp + wPlayerBideAccumulatedDamage + 1], 0
%else
    mov byte [ebp + wPlayerBideAccumulatedDamage], 0   ; high byte only (Gen-1 bug)
%endif

    ; --- clear enemy statuses: 5 contiguous bytes starting at wEnemyStatsToDouble
    ;     (wEnemyStatsToDouble, wEnemyStatsToHalve, wEnemyBattleStatus1/2/3) ---
    mov byte [ebp + wEnemyStatsToDouble], 0
    mov byte [ebp + wEnemyStatsToHalve], 0
    mov byte [ebp + wEnemyBattleStatus1], 0
    mov byte [ebp + wEnemyBattleStatus2], 0
    mov byte [ebp + wEnemyBattleStatus3], 0

    mov byte [ebp + wEnemyDisabledMove], 0
    mov byte [ebp + wEnemyDisabledMoveNumber], 0
    mov byte [ebp + wEnemyMonMinimized], 0

    mov byte [ebp + wPlayerUsedMove], 0       ; ld hl,wPlayerUsedMove / ld[hli],a
    mov byte [ebp + wEnemyUsedMove], 0        ; ld[hl],a

    ; ANIMATION=OFF: pret `hlcoord 12,5 / decoord 12,6 / call SlideDownFaintedMonPic`
    ; is a pure pixel-slide graphics effect. Call site kept faithful (extern, called
    ; unconditionally as pret does) but no coordinate setup — the stub owns its own
    ; no-op geometry until the animation layer exists.
    call SlideDownFaintedMonPic

    ; ClearScreenArea IS real: pret `hlcoord 0,0 / lb bc,4,11`.
    mov esi, W_TILEMAP + 0                    ; hlcoord 0, 0
    mov bh, 4                                 ; b = 4 rows
    mov bl, 11                                ; c = 11 width
    call ClearScreenArea

    ; --- win audio (pret core.asm:786-806): a trainer win plays SFX_FAINT_FALL then
    ;     SFX_FAINT_THUD; a wild win ends the low-health alarm and plays the victory
    ;     jingle. The post-audio logic at .sfxplayed is common to both. ---
    mov al, [ebp + wIsInBattle]
    dec al
    jz .wild_win                              ; wIsInBattle == 1 (wild) -> victory music
    ; Trainer win: SFX_FAINT_FALL / SFX_FAINT_THUD.
    ; TODO-HW: trainer faint SFX (wFrequencyModifier/wTempoModifier=0,
    ; PlaySoundWaitForCurrent SFX_FAINT_FALL, wait CHAN5, PlaySound SFX_FAINT_THUD,
    ; WaitForSoundToFinish). Trainer battles aren't the live overworld path yet.
    jmp .sfxplayed
.wild_win:
    call EndLowHealthAlarm                     ; pret: call EndLowHealthAlarm
    mov al, MUSIC_DEFEATED_WILD_MON            ; pret: ld a, MUSIC_DEFEATED_WILD_MON
    call PlayBattleVictoryMusic                ; pret: call PlayBattleVictoryMusic

.sfxplayed:
    ; --- double-faint guard (pret :808-815) ---
    mov al, [ebp + wBattleMonHP]
    or al, [ebp + wBattleMonHP + 1]
    jnz .playermonnotfaint                    ; battle mon HP != 0 -> not fainted
    mov al, [ebp + wInHandlePlayerMonFainted]
    and al, al
    jnz .playermonnotfaint                    ; already inside HandlePlayerMonFainted -> skip
    call RemoveFaintedPlayerMon

.playermonnotfaint:
    call AnyPartyAlive
    test dh, dh
    jz .return                                  ; ret z (no party alive -> just return)

    mov eax, EnemyMonFaintedText
    call PrintBattleText                       ; ld hl,EnemyMonFaintedText / call PrintText
    call PrintEmptyString
    call SaveScreenTilesToBuffer1

    mov byte [ebp + wBattleResult], 0

    mov bh, EXP_ALL                            ; ld b, EXP_ALL (B -> BH per register map)
    call IsItemInBag                           ; ZF=1 -> not in bag
    setz byte [faint_enemy_has_exp_all]         ; push af (parked in memory, see .bss note)
    jz .giveExpToMonsThatFought                 ; jr z, .giveExpToMonsThatFought

    ; --- has EXP_ALL: halve wEnemyMonBaseStats for NUM_STATS+2 bytes ---
    mov esi, wEnemyMonBaseStats
    mov ecx, NUM_STATS + 2
.halveExpDataLoop:
    shr byte [ebp + esi], 1                    ; srl [hl]
    inc esi
    dec ecx
    jnz .halveExpDataLoop

.giveExpToMonsThatFought:
    mov byte [ebp + wBoostExpByExpAll], 0
    call GainExperience                        ; callfar GainExperience

    ; pret: `pop af / ret z` — ret if the saved IsItemInBag ZF was set (EXP_ALL
    ; NOT in bag). faint_enemy_has_exp_all = setz(that ZF) = 1 when NOT in bag, so
    ; the faithful test is `ret nz` here, NOT `ret z` — the byte holds the raw ZF,
    ; not "has exp all". (Was `jz`: inverted → on a normal wild win it wrongly ran
    ; the EXP_ALL block, a 2nd whole-party GainExperience that clobbered wIsInBattle
    ; → TrainerAI `call edi` page fault. bug#3.)
    cmp byte [faint_enemy_has_exp_all], 0       ; pop af / ret z (byte=1 ⇒ ZF was set ⇒ no EXP_ALL)
    jnz .return                                  ; no EXP_ALL -> done

    ; --- has EXP_ALL: award to every party mon (halved share) ---
    mov byte [ebp + wBoostExpByExpAll], TRUE
    mov al, [ebp + wPartyCount]
    xor bh, bh                                  ; ld b, 0 (B -> BH per register map)
.gainExpFlagsLoop:
    stc                                          ; scf
    rcl bh, 1                                    ; rl b
    dec al
    jnz .gainExpFlagsLoop
    mov [ebp + wPartyGainExpFlags], bh
    call GainExperience                          ; jpfar GainExperience (tail call -> plain call+ret)

.return:
    ret
