; unused_stats_functions.asm — mirror of pret engine/battle/unused_stats_functions.asm.
;
; Source (faithful translation): engine/battle/unused_stats_functions.asm:1-62.
;
; PORTED 2026-08-12 (battle plan 3d). Both routines read `missing` in the label
; DB, which is what kept `DoubleOrHalveSelectedStats` a ret-only stub — its whole
; body is `callfar DoubleSelectedStats` / `jpfar HalveSelectedStats`.
;
; WHAT THEY DO, AND WHY THEY LOOK POINTLESS. Each walks the four battle-mon stat
; words (attack, defense, speed, special) and doubles or halves the ones selected
; by a bitmask. pret's own comment on both is "does nothing since no stats are
; ever selected (barring glitches)": wPlayerStatsToDouble / wPlayerStatsToHalve
; and their enemy twins are cleared on send-out and never set by any normal
; path, so the mask is 0 and the loop doubles nothing. They are still translated
; faithfully rather than left as stubs, because "barring glitches" is the point —
; the glitch paths that DO set those bytes are reachable in the original game,
; and a ret-only body would silently diverge there.
;
; The caller is `DoubleOrHalveSelectedStats` (core.asm), which `ItemUseMedicine`
; invokes after curing the ACTIVE battler so the in-battle stat copy re-applies
; any Reflect/Light Screen doubling. That path only became reachable when the
; in-battle ITEM menu landed (battle plan 2c).
;
; POINTER DIRECTION, and it is the thing to get right. GB stat words are
; BIG-ENDIAN (hard rule): the high byte is at +0, the low byte at +1.
;   * DoubleSelectedStats starts at wBattleMonAttack + 1 — the LOW byte — and
;     doubles low-then-high through the carry (`add a` / `rl a`).
;   * HalveSelectedStats starts at wBattleMonAttack + 0 — the HIGH byte — and
;     halves high-then-low through the carry (`srl a` / `rr [hl]`).
; Each helper leaves HL where it found it, so the caller's `inc hl / inc hl`
; advances exactly one stat word per iteration.
;
; FLAG CHAIN. `add al, al` / `shr al, 1` publish CF for the following
; `rcl` / `rcr` on the other half of the word, and the pointer steps between them
; are `inc`/`dec`, which PRESERVE CF on x86 exactly as SM83's `hld`/`hli` do.
; Nothing else may go between those pairs.
;
; COUNTER WIDTH. `ld c, 4` is a literal, and the loop is `dec c / ret z`, so the
; count is 8-bit and can never be 0 on entry. Translated as `dec bl`, not
; `dec ecx` — the port's standing rule about widened GB counters.
;
; Register map (CLAUDE.md): A=AL, B=BH, C=BL, D=DH, E=DL, HL=ESI,
; EBP = GB base, [ebp+addr].
;
; Build: nasm -f coff -I include/ -I . -o unused_stats_functions.o unused_stats_functions.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

global DoubleSelectedStats
global HalveSelectedStats

section .text

; ---------------------------------------------------------------------------
; DoubleSelectedStats — pret unused_stats_functions.asm:2. Double each stat
; whose bit is set in wPlayerStatsToDouble / wEnemyStatsToDouble.
; In: hWhoseTurn (0 = player, non-zero = enemy).
; ---------------------------------------------------------------------------
DoubleSelectedStats:
    mov al, [ebp + hWhoseTurn]          ; ldh a,[hWhoseTurn]
    test al, al                         ; and a
    ; pret's `ld a,[…]` / `ld hl,…` are flag-neutral, and so are these movs, so
    ; the ZF above survives to the branch.
    mov al, [ebp + wPlayerStatsToDouble]
    mov esi, wBattleMonAttack + 1       ; LOW byte of the first stat word
    jz .notEnemyTurn                    ; jr z
    mov al, [ebp + wEnemyStatsToDouble]
    mov esi, wEnemyMonAttack + 1
.notEnemyTurn:
    mov bl, 4                           ; ld c, 4   — four stat words
    mov bh, al                          ; ld b, a   — the selection mask
.loop:
    shr bh, 1                           ; srl b — CF = this stat's select bit
    jnc .skip                           ; call c, .doubleStat
    call .doubleStat
.skip:
    lea esi, [esi + 2]                  ; inc hl / inc hl — next stat word
    dec bl                              ; dec c
    jz .done                            ; ret z
    jmp .loop                           ; jr .loop
.done:
    ret

.doubleStat:
    mov al, [ebp + esi]                 ; ld a,[hl]  — low byte
    add al, al                          ; add a      — CF = carry into the high byte
    mov [ebp + esi], al                 ; ld [hld],a
    dec esi                             ; (the `d` of hld; preserves CF)
    mov al, [ebp + esi]                 ; ld a,[hl]  — high byte
    rcl al, 1                           ; rl a       — consumes that CF
    mov [ebp + esi], al                 ; ld [hli],a
    inc esi                             ; (the `i` of hli)
    ret

; ---------------------------------------------------------------------------
; HalveSelectedStats — pret unused_stats_functions.asm:31. Halve each stat whose
; bit is set in wPlayerStatsToHalve / wEnemyStatsToHalve, flooring at 1.
; In: hWhoseTurn (0 = player, non-zero = enemy).
; ---------------------------------------------------------------------------
HalveSelectedStats:
    mov al, [ebp + hWhoseTurn]          ; ldh a,[hWhoseTurn]
    test al, al                         ; and a
    mov al, [ebp + wPlayerStatsToHalve]
    mov esi, wBattleMonAttack           ; HIGH byte of the first stat word
    jz .notEnemyTurn                    ; jr z
    mov al, [ebp + wEnemyStatsToHalve]
    mov esi, wEnemyMonAttack
.notEnemyTurn:
    mov bl, 4                           ; ld c, 4
    mov bh, al                          ; ld b, a
.loop:
    shr bh, 1                           ; srl b
    jnc .skip                           ; call c, .halveStat
    call .halveStat
.skip:
    lea esi, [esi + 2]                  ; inc hl / inc hl
    dec bl                              ; dec c
    jz .done                            ; ret z
    jmp .loop                           ; jr .loop
.done:
    ret

.halveStat:
    mov al, [ebp + esi]                 ; ld a,[hl]  — high byte
    shr al, 1                           ; srl a      — CF = bit shifted out
    mov [ebp + esi], al                 ; ld [hli],a
    inc esi                             ; (the `i` of hli; preserves CF)
    rcr byte [ebp + esi], 1             ; rr [hl]    — low byte takes that CF
    or al, [ebp + esi]                  ; or [hl]    — ZF = the whole word is 0
    jnz .nonzeroStat                    ; jr nz
    mov byte [ebp + esi], 1             ; ld [hl],1  — floor the stat at 1
.nonzeroStat:
    dec esi                             ; dec hl — back to the high byte
    ret
