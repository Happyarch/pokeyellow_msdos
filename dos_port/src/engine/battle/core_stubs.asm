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
; TrainerAI is now LIVE in trainer_ai.asm (class-based move/item/switch AI; pret
; engine/battle/trainer_ai.asm) — its stub here was removed when trainer_ai.asm
; linked into the EXE (battle-swarm-C: SelectEnemyMove→AIEnemyTrainerChooseMoves wiring).
; HandlePoisonBurnLeechSeed is now LIVE in residual_damage.asm (poison/burn/Leech Seed
; end-of-round residual; pret engine/battle/core.asm:479) — its stub here was removed
; when residual_damage.asm linked into the EXE.
; JumpMoveEffect is now LIVE in effects.asm (MoveEffectPointerTable dispatch) — its
; stub here was removed when the move-effect scaffold linked effects.asm into the EXE.

extern FindMoveName              ; battle_menu.asm — AL = move id → EAX = flat name ptr

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

; ===========================================================================
; ExecutePlayerMove/ExecuteEnemyMove special-move leaves — NOW FAITHFULLY PORTED
; (battle-swarm-A). Each is its own file under src/engine/battle/; core.asm's
; `extern` declarations resolve to them:
;   PrintGhostText / IsGhostBattle .......... ghost.asm
;   HandleCounterMove ....................... counter.asm
;   MirrorMoveCopyMove / ReloadMoveData ..... mirror_move.asm
;   MetronomePickMove ....................... metronome.asm
;   PrintCriticalOHKOText ................... print_critical_ohko.asm
;   DisplayEffectiveness .................... display_effectiveness.asm
;   PrintMoveFailureText .................... print_move_failure.asm
;   HandleExplodingAnimation ................ exploding_animation.asm
; The stubs that used to live here are deleted.
; ===========================================================================
global PredefShakeScreenHorizontally

; PredefShakeScreenHorizontally — pret predef, cosmetic screen shake used by
; PrintMoveFailureText's Jump Kick / Hi Jump Kick crash path (B = # shakes).
; TODO-HW: real horizontal screen shake (rWX/rSCX manipulation) — deferred like
; the rest of the ANIMATION=OFF subanimation layer. No-op is faithful for now
; (HP bars / faints / text are all real; only the literal shake visual is off).
PredefShakeScreenHorizontally:
    ret
