; decrement_pp.asm — DecrementPP (battle engine plan, Stage 6).
;
; After using a move in battle, decrement its PP in the battle struct and (unless
; Transformed) in the party struct. Faithful translation of
; engine/battle/decrement_pp.asm (pret/pokeyellow).
;
; Register map: a=AL, b=BH, c=BL (bc=BX), d=DH, e=DL (de=DX), hl=ESI.
; In: DX (de) = pointer to the move id just used.
;
; AUDIT (2026-06-26): the prior swarm draft had two bugs, both fixed here:
;   1. it %include'd "dos_port/include/gb_memmap.inc" and omitted gb_constants.inc,
;      so STRUGGLE / PARTYMON_STRUCT_LENGTH / the battle-status bit names were
;      undefined.
;   2. it loaded the AddNTimes stride into CX, but AddNTimes reads BX (bc) — the
;      exact "helper reads BX" bug flagged in the pokemon-engine plan. The party
;      PP address was therefore computed from garbage.
;
; Build: nasm -f coff -I include/ -I . -o decrement_pp.o decrement_pp.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

section .text

global DecrementPP

extern AddNTimes

DecrementPP:
    mov al, [ebp + edx]              ; ld a, [de] — move id just used
    cmp al, STRUGGLE
    je .done                         ; Struggle has no PP to decrement
    mov esi, wPlayerBattleStatus1
    mov al, [ebp + esi]              ; ld a, [hli]
    inc esi
    ; BUG(critical): "Struggle PP Underflow" — this skip-list covers Bide/Thrash/
    ; multi-strike but deliberately does NOT include USING_TRAPPING_MOVE (Wrap/
    ; Bind/Fire Spin/Clamp). A trapping move's continuation turns are chosen by
    ; the forced-move early-out in SelectEnemyMove/its player-side equivalent
    ; (select_enemy_move.asm — locked-in moves skip AnyMoveToSelect's PP-is-zero
    ; check entirely), so if the move's PP hits 0 mid-trap, every subsequent
    ; continuation turn still reaches `dec byte [ebp+esi]` below and underflows
    ; the packed PP byte 0x00 -> 0xFF; PP_MASK (0x3F) then reads it back as 63.
    ; Gen-1 behavior, preserved verbatim. pret ref: engine/battle/decrement_pp.asm:
    ; DecrementPP, docs/references/yellow_glitches.md#battle-system (Struggle PP
    ; Underflow — despite the catalogue name, the actual trigger is any
    ; auto-selected/locked-in move bypassing the normal PP check, of which
    ; trapping-move continuation is the reachable case in this port).
    test al, (1 << STORING_ENERGY) | (1 << THRASHING_ABOUT) | (1 << ATTACKING_MULTIPLE_TIMES)
    jnz .done                        ; mid multi-turn move: no PP decrement
    mov al, [ebp + esi]              ; wPlayerBattleStatus2
    test al, 1 << USING_RAGE
    jnz .done                        ; Rage: no PP decrement
    mov esi, wBattleMonPP            ; PP of first move (battle struct)
    call .DecrementPP

    mov al, [ebp + wPlayerBattleStatus3]
    test al, 1 << TRANSFORMED
    jnz .done                        ; Transformed: battle PP is separate from party PP

    mov esi, wPartyMon1PP            ; PP of first move (party struct)
    mov al, [ebp + wPlayerMonNumber]
    mov bx, PARTYMON_STRUCT_LENGTH   ; bc (BX), NOT cx — AddNTimes reads BX
    call AddNTimes
.DecrementPP:
    mov al, [ebp + wPlayerMoveListIndex]  ; which move (0..3)
    movzx ecx, al
    add esi, ecx                     ; ld c,a; ld b,0; add hl,bc
    dec byte [ebp + esi]             ; dec [hl]
.done:
    ret
