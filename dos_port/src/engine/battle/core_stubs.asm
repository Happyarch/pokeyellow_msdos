; core_stubs.asm — link-time stubs for the faithful core.asm battle loop.
;
; core.asm is a structure-for-structure translation of pret's engine/battle/core.asm.
; A few of its backend calls reach into closures that are NOT link-ready yet (they
; depend on a large set of still-deferred predefs / UI / text — which is exactly why
; BATTLE_SRCS is check-only, not linked). Until those closures are ported wave-by-wave,
; the calls resolve to the faithful-behaviour stubs below, each matching a TODO(faithful)
; marker already present in core.asm. The battle loop itself (menu, move select, speed-
; ordered turns, damage, faint, EXP, run) is fully faithful and live.
;
; Register map: A=AL, BC=BX (B=BH), DE=EDX, HL/ESI, EBP = GB base; GB mem = [EBP+addr].
%include "gb_memmap.inc"
%include "gb_constants.inc"

bits 32
section .text

global FormatMovesString
global TrainerAI
; HandlePoisonBurnLeechSeed is now LIVE in residual_damage.asm (poison/burn/Leech Seed
; end-of-round residual; pret engine/battle/core.asm:479) — its stub here was removed
; when residual_damage.asm linked into the EXE.
; JumpMoveEffect is now LIVE in effects.asm (MoveEffectPointerTable dispatch) — its
; stub here was removed when the move-effect scaffold linked effects.asm into the EXE.

extern FindMoveName              ; battle_menu.asm — AL = move id → EAX = flat name ptr
extern PrintText                 ; move_effect_helpers.asm — ESI = flat battle_text stream → print + <PROMPT> wait
extern CriticalHitText           ; battle_text.inc — "Critical hit!" (0x58-terminated)
extern OHKOText                  ; battle_text.inc — "One-hit KO!" (0x58-terminated)
extern DelayFrames               ; frame.asm — BL = frame count (per B-8: BL, not CL)

; ---------------------------------------------------------------------------
; FormatMovesString — faithful copy of misc.asm:FormatMovesString OUTPUT: walk wMoves,
; emit each move's name with a 0x4E (<NEXT>) separator, a '-' (0xE3) for each empty slot,
; a 0x50 ('@') terminator, and record wNumMovesMinusOne. Names are resolved via the flat
; MoveNames walk (FindMoveName) rather than GetName, because GetName/names.asm is not yet
; link-ready (TrainerNames is undefined). The produced string — and the '-' empty-slot
; placeholder the user flagged — is byte-identical to the faithful routine's.
; (NOTE: '-' is the charmap tile 0xE3; misc.asm's `mov al,'-'` would assemble to ASCII
; 0x2D in NASM — a latent port bug in that never-linked file. We emit 0xE3 here.)
; In: wMoves seeded (core.asm copies wBattleMonMoves → wMoves first). EBP = GB base.
; ---------------------------------------------------------------------------
FormatMovesString:
    mov esi, wMoves
    mov edx, wMovesString
    xor bh, bh                          ; bh = slot counter
.nameLoop:
    mov al, [ebp + esi]
    inc esi
    test al, al
    jz .dashLoop                        ; 0 → empty slot (and all remaining)
    push esi
    push edx                            ; FindMoveName clobbers DL — preserve the dest cursor
    call FindMoveName                   ; AL=id → EAX = flat name ptr ('@'-terminated)
    pop edx
    mov esi, eax
.copyName:
    mov al, [esi]                       ; flat read
    inc esi
    cmp al, 0x50                        ; '@'
    jz .doneName
    mov [ebp + edx], al
    inc edx
    jmp .copyName
.doneName:
    mov [ebp + wNumMovesMinusOne], bh
    inc bh
    mov byte [ebp + edx], 0x4E          ; <NEXT>
    inc edx
    pop esi
    cmp bh, NUM_MOVES
    jz .done
    jmp .nameLoop
.dashLoop:
    mov byte [ebp + edx], 0xE3          ; '-' (charmap dash tile)
    inc edx
    inc bh
    cmp bh, NUM_MOVES
    jz .done
    mov byte [ebp + edx], 0x4E          ; <NEXT>
    inc edx
    jmp .dashLoop
.done:
    mov byte [ebp + edx], 0x50          ; '@'
    ret

; ---------------------------------------------------------------------------
; TrainerAI — pret trainer_ai.asm. Its closure (AIGetTypeEffectiveness + the stat-mod
; effect handlers) isn't link-ready. Stubbed to "no AI action" (CF=0) so the enemy always
; takes its randomly-selected move (SelectEnemyMove), which is correct for wild battles
; and an acceptable placeholder for trainers until the AI item/switch logic is wired.
; ---------------------------------------------------------------------------
TrainerAI:
    clc                                 ; CF=0 → AI did not use an item/switch
    ret

; ===========================================================================
; ExecutePlayerMove/ExecuteEnemyMove leaf stubs (Stage 2.5). The faithful turn-flow
; structure CALLS these where pret does; their bodies are deferred (marked TODO),
; matching the accepted anim-stub deferral pattern. Each preserves pret's flag/return
; contract so the surrounding faithful control flow behaves correctly.
; ===========================================================================
global PrintGhostText
global HandleCounterMove
global MirrorMoveCopyMove
global MetronomePickMove
global PrintCriticalOHKOText
global DisplayEffectiveness
global HandleExplodingAnimation

; PrintGhostText (pret core.asm:3452) — Pokémon Tower ghost "scared/get out" text.
; TODO(faithful): IsGhostBattle + ghost text. Stub: not a ghost battle → ZF=0 (proceed).
PrintGhostText:
    mov al, 1
    and al, al                          ; ZF=0 → not ghost, mon may act
    ret

; HandleCounterMove (pret core.asm) — Counter damage reflection.
; TODO(faithful): translate Counter. Stub: current move is not Counter → ZF=0 (normal damage).
HandleCounterMove:
    mov al, 1
    and al, al                          ; ZF=0 → proceed to normal damage calc
    ret

; MirrorMoveCopyMove (pret) — copy the last move the target used.
; TODO(faithful): translate Mirror Move. Stub: fail → ZF=1 (pret: jp z, ExecutePlayerMoveDone).
MirrorMoveCopyMove:
    xor al, al                          ; ZF=1 → Mirror Move failed (done)
    ret

; MetronomePickMove (pret) — pick a random move. TODO(faithful): translate Metronome.
; Stub: zero the acting side's move effect so the re-entry into the damage path does NOT
; re-trigger the METRONOME_EFFECT branch (would loop). The move resolves as a plain hit.
MetronomePickMove:
    mov al, [ebp + hWhoseTurn]
    and al, al
    jnz .enemy
    mov byte [ebp + wPlayerMoveEffect], 0
    ret
.enemy:
    mov byte [ebp + wEnemyMoveEffect], 0
    ret

; PrintCriticalOHKOText — faithful port of pret engine/battle/core.asm:3967. Prints
; "Critical hit!" (wCriticalHitOrOHKO==1) or "One-hit KO!" (==2), each with a <PROMPT>
; button-wait (an acknowledged beat between the used-move line and the result), then
; clears the flag; always ends with a 20-frame settle (pret `ld c,20 / jp DelayFrames`).
; These result beats were previously no-op'd, which is why messages ran together.
PrintCriticalOHKOText:            ; pret: "Critical hit!" / "One-hit KO!" text
    mov al, [ebp + wCriticalHitOrOHKO]
    and al, al
    jz .done                          ; pret: jr z, .done — no crit / no OHKO
    cmp al, 2
    je .ohko
    mov esi, CriticalHitText
    jmp .print
.ohko:
    mov esi, OHKOText
.print:
    call PrintText                    ; prints + <PROMPT> wait (RunBattleTextStream hook)
    mov byte [ebp + wCriticalHitOrOHKO], 0
.done:
    mov bl, 20                        ; pret: ld c, 20 (B-8: DelayFrames reads BL)
    jmp DelayFrames

; DisplayEffectiveness — faithful port of pret engine/battle/display_effectiveness.asm.
; From wDamageMultipliers (low 7 bits = type-eff numerator): ==EFFECTIVE(10) → neutral,
; no text; >10 → "It's super effective!"; <10 → "It's not very effective..." Each with a
; <PROMPT> button-wait. pret `and $7F / cp EFFECTIVE / ret z / jr nc,super / notvery`.
DisplayEffectiveness:
    mov al, [ebp + wDamageMultipliers]
    and al, 0x7F
    cmp al, EFFECTIVE                 ; 10 = neutral
    je .neutral                       ; pret: ret z
    jae .super                        ; >= 10 (already ruled out ==10) → super effective
    mov esi, NotVeryEffectiveText
    jmp PrintText                     ; tail: pret jp PrintText
.super:
    mov esi, SuperEffectiveText
    jmp PrintText
.neutral:
    ret

; HandleExplodingAnimation — pret: Explosion/Self-Destruct screen shake.
; TODO(faithful); no-op is safe (deferred like the anim stubs).
HandleExplodingAnimation:
    ret

; ---------------------------------------------------------------------------
; SuperEffectiveText / NotVeryEffectiveText — pret data/text/text_2.asm:1285-1293
; (_SuperEffectiveText / _NotVeryEffectiveText). Hand-authored here (Tier-2 code) since
; the generator does not emit them; charmap per constants/charmap.asm (' =$E0, .=$E8,
; !=$E7, <LINE>=$4F, <PROMPT>=$58, space=$7F, TX_START=$00). Faithful two-line +
; <PROMPT> wait, matching the sibling battle_text.inc streams.
; ---------------------------------------------------------------------------
section .data
global SuperEffectiveText
SuperEffectiveText:
    ; "It's super" <LINE> "effective!" <PROMPT>
    db 0x00, 0x88,0xB3,0xE0,0xB2,0x7F,0xB2,0xB4,0xAF,0xA4,0xB1
    db 0x4F, 0xA4,0xA5,0xA5,0xA4,0xA2,0xB3,0xA8,0xB5,0xA4,0xE7, 0x58
global NotVeryEffectiveText
NotVeryEffectiveText:
    ; "It's not very" <LINE> "effective..." <PROMPT>
    db 0x00, 0x88,0xB3,0xE0,0xB2,0x7F,0xAD,0xAE,0xB3,0x7F,0xB5,0xA4,0xB1,0xB8
    db 0x4F, 0xA4,0xA5,0xA5,0xA4,0xA2,0xB3,0xA8,0xB5,0xA4,0xE8,0xE8,0xE8, 0x58
