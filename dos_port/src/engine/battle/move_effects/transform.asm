; 1200__TransformEffect.asm — TransformEffect_ (move-effect translation swarm).
;
; Faithful translation of engine/battle/move_effects/transform.asm:TransformEffect_
; (pret/pokeyellow). Transform copies the TARGET's species/types/catch-rate/moves/
; DVs/stats(unmodified+stages) into the USER, sets the user's TRANSFORMED status3
; bit, plays the substitute-aware "transform into" animation, and prints
; TransformedText (which names the mon transformed into).
;
; Fidelity boundary: docs/move_translation_divergence.md. Shared externs (§4) are
; called, not redefined; only §2 allowlist items (literal subanim, banks) diverge.
;
; *** Gen-1 Transform carries TWO pret-flagged bugs in the INVULNERABLE
; (charging Fly/Dig) pre-check — BOTH preserved verbatim under BUG_FIX_LEVEL<2,
; see the two "BUG(cosmetic)" blocks below. Net effect of both bugs together:
; the invulnerability check is non-functional on EITHER turn — Transform never
; actually fails against a charging Fly/Dig target in the unpatched game. ***
;
; Register map: A=AL, B=BH, C=BL (BC=BX/EBX), D=DH, E=DL (DE=EDX), HL=ESI (full
; 32-bit), EBP=GB base. GB memory at [EBP+addr]; battle_text streams are flat
; program addresses (ESI = stream).
;
; Build: nasm -f coff -I include/ -I . -o /dev/null 1200__TransformEffect.asm
;        nasm -f coff -I include/ -I . -D BUG_FIX_LEVEL=2 -o /dev/null 1200__TransformEffect.asm

bits 32

%include "gb_macros.inc"
%include "gb_memmap.inc"
%include "gb_constants.inc"

; ---------------------------------------------------------------------------
; FLAG FOR MASTER — wTransformedEnemyMonOriginalDVs is not yet in gb_memmap.inc.
; Sym-verified against the built ROM symbol table (pokeyellow.sym: "00:cceb
; wTransformedEnemyMonOriginalDVs"), cross-checked the same way the existing
; gb_memmap.inc entries were verified (e.g. wPlayerMoveListIndex sym = 00:cc2e,
; matching gb_memmap.inc's existing equ exactly) — same bank-0 WRAM numbering
; convention, so 0xCCEB is correct. Please fold this into gb_memmap.inc proper
; (it sits between wSafariBaitFactor $CCE9/$CCEA and wMonIsDisobedient $CCED in
; ram/wram.asm, a 2-byte word) and drop the local equ here.
; ---------------------------------------------------------------------------
%ifndef wTransformedEnemyMonOriginalDVs
%endif

section .text

global TransformEffect_

; --- shared scaffold externs (§4: call, never define) ---
extern PrintText                    ; move_effect_helpers.asm — ESI = flat text stream
extern PrintButItFailedText_        ; move_effect_helpers.asm
extern EffectCallBattleCore         ; move_effect_helpers.asm — jp [hl]/jpfar equivalent (flat jmp esi)
extern CopyData                     ; home/copy_data.asm — ESI=src GB off, EDX=dst GB off, BX=count
extern GetMonName                   ; home/names.asm — wNamedObjectIndex -> wNameBuffer
; --- allowlist anim stubs (§2 item 1: literal subanim, ANIMATION=OFF path) ---
extern PlayCurrentMoveAnimation
extern HideSubstituteShowMonAnim
extern ReshowSubstituteAnim
; AnimationTransformMon (engine/battle/animations.asm) is the literal hard-coded
; "transform into" pop-up subanim pret reaches when wOptions/BIT_BATTLE_ANIMATION
; is SET (animations off). It is NOT yet defined anywhere in the dos_port scaffold
; (move_effect_helpers.asm only stubs PlayCurrentMoveAnimation/PlayBattleAnimation/
; AnimationSubstitute, not this one — same situation 1196__SubstituteEffect.asm
; hit for AnimationSubstitute). Externed here per allowlist §2 item 1 so this file
; assembles standalone; resolving the undefined symbol at link time is the
; master's job.
; FLAG FOR MASTER: AnimationTransformMon has no stub yet — add a `ret`-stub
; global to move_effect_helpers.asm's allowlist-stub block before this handler
; can link (alongside AnimationSubstitute).
extern AnimationTransformMon
; --- battle_text.inc streams (global in core.o) ---
extern TransformedText

; ===========================================================================
; TransformEffect_ — pret engine/battle/move_effects/transform.asm.
; Copies the TARGET's data into the USER (hWhoseTurn: 0=player's turn (user=
; player, target=enemy), 1=enemy's turn (user=enemy, target=player)), sets
; TRANSFORMED, plays the transform animation, prints TransformedText.
; ===========================================================================
TransformEffect_:
    mov esi, wBattleMonSpecies          ; ld hl, wBattleMonSpecies  (default = enemy's
                                         ; turn: target = player's mon)
    mov edx, wEnemyMonSpecies           ; ld de, wEnemyMonSpecies   (user = enemy mon)
    mov ebx, wEnemyBattleStatus3        ; ld bc, wEnemyBattleStatus3 (user's status3 ->
                                         ; TRANSFORMED bit target)

; BUG(cosmetic) #1 — pret ref: engine/battle/move_effects/transform.asm:TransformEffect_
; ("bug: on enemy's turn, a is overloaded with hWhoseTurn, before the check for
; INVULNERABLE"). pret loads [wEnemyBattleStatus1] into A, then *immediately*
; clobbers A with [hWhoseTurn] before the INVULNERABLE bit test ever reads it —
; the status-byte load is dead. On the enemy's turn (the `jr nz, .hitTest` path,
; taken with A = hWhoseTurn = 1) the INVULNERABLE check (bit 6) ends up testing
; the raw hWhoseTurn byte instead of any battle-status byte, so it can never see
; bit 6 set — Transform can never be blocked by a charging Fly/Dig target via
; this path.
%if BUG_FIX_LEVEL >= 2
    mov al, [ebp + wEnemyBattleStatus1] ; fix: keep the loaded status byte alive for
                                         ; the INVULNERABLE test at .hitTest (branch on
                                         ; hWhoseTurn separately so AL isn't clobbered)
    cmp byte [ebp + hWhoseTurn], 0
    jnz .hitTest
%else
    mov al, [ebp + wEnemyBattleStatus1] ; ld a, [wEnemyBattleStatus1] -- dead load,
                                         ; preserved for fidelity (clobbered next line)
    mov al, [ebp + hWhoseTurn]          ; ldh a, [hWhoseTurn] -- THE BUG: overloads a
    and al, al
    jnz .hitTest                        ; enemy's turn -> .hitTest with a = hWhoseTurn
%endif
; player's turn
    mov esi, wEnemyMonSpecies           ; ld hl, wEnemyMonSpecies  (target = enemy mon)
    mov edx, wBattleMonSpecies          ; ld de, wBattleMonSpecies (user = player's mon)
    mov ebx, wPlayerBattleStatus3       ; ld bc, wPlayerBattleStatus3 (user's status3)

    mov al, [ebp + hWhoseTurn]          ; ld [wPlayerMoveListIndex], a -- pret stores
    mov [ebp + wPlayerMoveListIndex], al ; whatever 'a' held (hWhoseTurn, == 0 on this
                                         ; path either way); re-derived directly from
                                         ; hWhoseTurn here so this incidental store
                                         ; (not itself one of the two tagged bugs —
                                         ; pret doesn't comment on it) stays faithful
                                         ; under BOTH BUG_FIX_LEVEL builds rather than
                                         ; depending on bug #1's now-divergent AL content.

; BUG(cosmetic) #2 — pret ref: engine/battle/move_effects/transform.asm:TransformEffect_
; ("bug: this should be target's BattleStatus1 (i.e. wEnemyBattleStatus1)"). On the
; player's turn the target is the enemy, so the INVULNERABLE check should read the
; enemy's (target's) status1; pret instead reads the player's own (the user's)
; status1 — checking the wrong side entirely.
%if BUG_FIX_LEVEL >= 2
    mov al, [ebp + wEnemyBattleStatus1] ; fix: target's (enemy's) status1
%else
    mov al, [ebp + wPlayerBattleStatus1] ; ld a, [wPlayerBattleStatus1] -- THE BUG:
                                         ; the user's own status1, not the target's
%endif
.hitTest:
    test al, 1 << INVULNERABLE          ; bit INVULNERABLE, a ; invulnerable to typical
                                         ; attacks? (fly/dig) -- this check doesn't work
                                         ; due to the two bugs above (BUG_FIX_LEVEL<2)
    jnz .failed

    push esi                            ; push hl  (target species ptr)
    push edx                            ; push de  (user species ptr)
    push ebx                            ; push bc  (user status3 ptr)

    mov esi, wPlayerBattleStatus2       ; ld hl, wPlayerBattleStatus2
    mov al, [ebp + hWhoseTurn]
    and al, al
    jz .transformEffect
    mov esi, wEnemyBattleStatus2
.transformEffect:
; animation(s) played are different if target has Substitute up
    mov al, [ebp + esi]                 ; bit HAS_SUBSTITUTE_UP, [hl]
    test al, 1 << HAS_SUBSTITUTE_UP
    setnz dl                            ; stash the boolean across the calls below;
                                         ; EDX is scratch here -- its real (user ptr)
                                         ; value is already saved on the stack above
    push edx                            ; push af (the substitute-check result)
    jz .skipHideSubstitute
    call HideSubstituteShowMonAnim      ; call nz, Bankswitch -> HideSubstituteShowMonAnim
                                         ; (Bankswitch dropped per allowlist §2 item 4)
.skipHideSubstitute:

    mov al, [ebp + wOptions]
    test al, 1 << BIT_BATTLE_ANIMATION  ; ld a,[wOptions] / add a -> carry = bit 7
    jnz .useTransformAnim               ; animations OFF -> literal hard-coded pop-up
    call PlayCurrentMoveAnimation       ; animations ON -> generic move-anim path
    jmp .animDone
.useTransformAnim:
    call AnimationTransformMon          ; allowlist §2 item 1 -- see extern note above
.animDone:

    pop edx                             ; pop af (the substitute-check result)
    test dl, dl
    jz .skipReshowSubstitute
    call ReshowSubstituteAnim
.skipReshowSubstitute:

    pop ebx                             ; pop bc
    mov al, [ebp + ebx]                 ; ld a, [bc]
    or al, 1 << TRANSFORMED             ; set TRANSFORMED, a ; mon is now transformed
    mov [ebp + ebx], al                 ; ld [bc], a

    pop edx                             ; pop de
    pop esi                             ; pop hl
    push esi                            ; push hl (re-saved for .copyStats below)

; transform user into opposing Pokemon
; species
    mov al, [ebp + esi]                 ; ld a, [hl]
    mov [ebp + edx], al                 ; ld [de], a
; type 1, type 2, catch rate, and moves
    add esi, 5                          ; ld bc,$5 / add hl,bc -> hl = target's Type1
    add edx, 5                          ; inc de x5 -> de = user's Type1
    mov bx, 7                           ; inc bc x2 -> bc=7 (Type1,Type2,CatchRate,Moves[4])
    call CopyData
    mov al, [ebp + hWhoseTurn]
    and al, al
    jz .next
; save enemy mon DVs at wTransformedEnemyMonOriginalDVs
    mov al, [ebp + edx]                 ; ld a, [de]
    mov [ebp + wTransformedEnemyMonOriginalDVs], al
    inc edx
    mov al, [ebp + edx]
    mov [ebp + wTransformedEnemyMonOriginalDVs + 1], al
    dec edx
.next:
; DVs
    mov al, [ebp + esi]                 ; ld a, [hli]
    inc esi
    mov [ebp + edx], al                 ; ld [de], a
    inc edx
    mov al, [ebp + esi]
    inc esi
    mov [ebp + edx], al
    inc edx
; Skip level and max HP
    add esi, 3
    add edx, 3
; Attack, Defense, Speed, and Special stats
    mov bx, (NUM_STATS - 1) * 2
    call CopyData
    add esi, (wBattleMonMoves - wBattleMonPP) ; ld bc, wBattleMonMoves-wBattleMonPP /
                                               ; add hl, bc -> hl = target's Moves[0]
    mov bh, NUM_MOVES                   ; ld b, NUM_MOVES
.copyPPLoop:
; 5 PP for all moves
    mov al, [ebp + esi]                 ; ld a, [hli]
    inc esi
    and al, al
    jz .lessThanFourMoves
    mov al, 5
.lessThanFourMoves:
    mov [ebp + edx], al                 ; ld [de], a
    inc edx
    dec bh
    jnz .copyPPLoop
.copyStats:
; original (unmodified) stats and stat mods
    pop esi                             ; pop hl  (target species ptr)
    mov al, [ebp + esi]
    mov [ebp + wNamedObjectIndex], al
    call GetMonName
    mov esi, wEnemyMonUnmodifiedAttack
    mov edx, wPlayerMonUnmodifiedAttack
    call .copyBasedOnTurn               ; original (unmodified) stats
    mov esi, wEnemyMonStatMods
    mov edx, wPlayerMonStatMods
    call .copyBasedOnTurn               ; stat mods
    mov esi, TransformedText
    jmp PrintText

.copyBasedOnTurn:
    mov al, [ebp + hWhoseTurn]
    and al, al
    jz .gotStatsOrModsToCopy
    push esi                            ; push hl
    mov esi, edx                        ; ld h,d / ld l,e (hl = de)
    pop edx                             ; pop de (de = old hl)
.gotStatsOrModsToCopy:
    mov bx, (NUM_STATS - 1) * 2
    jmp CopyData                        ; jp CopyData -- tail; CopyData's ret returns
                                         ; to .copyBasedOnTurn's caller

.failed:
    mov esi, PrintButItFailedText_      ; ld hl, PrintButItFailedText_
    jmp EffectCallBattleCore            ; jp EffectCallBattleCore
