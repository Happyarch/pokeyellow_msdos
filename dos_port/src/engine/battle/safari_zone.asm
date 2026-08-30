; safari_zone.asm — mirror of pret engine/battle/safari_zone.asm.
;
; Source (faithful translation): engine/battle/safari_zone.asm:1-28, the whole
; routine half of the file. PrintSafariZoneBattleText prints the per-turn Safari
; message and, when the escape factor runs out, refreshes the enemy's ACTUAL
; catch rate from its species header.
;
; PORTED 2026-08-12 (battle plan 4d). The label was `missing`; all three callees
; (GetMonHeader, LoadScreenTilesFromBuffer1, PrintText) were already translated,
; so this needed no stubs.
;
; THE TEXT HALF OF PRET'S FILE IS TIER-1 DATA and is NOT here: SafariZoneEatingText
; and SafariZoneAngryText are generated into assets/battle_text.inc via
; gen_battle_text.py (BATTLE_SRC scan list includes this file).
;
; Live caller: dos_port/src/engine/battle/init_battle.asm calls
; PrintSafariZoneBattleText from the Safari turn flow (the .notOutOfSafariBalls
; path in _InitBattleCommon's special-battle loop). The routine is fully linked
; and reachable on that path.
;
; Register map (CLAUDE.md): A=AL, B=BH, C=BL, D=DH, E=DL, HL=ESI,
; EBP = GB base, [ebp+addr].
;
; ---------------------------------------------------------------------------
; TWO THINGS THAT ARE NOT OBVIOUS FROM THE SM83:
;
; 1. `dec hl` WALKS BACKWARDS INTO A DIFFERENT VARIABLE. pret loads
;    wSafariBaitFactor and, on the no-bait arm, does a bare `dec hl` to reach the
;    byte BEFORE it. That byte is wSafariEscapeFactor — confirmed against the ROM
;    symbol file, which places them adjacent at 00:cce8 (escape) and 00:cce9
;    (bait), matching include/gb_memmap.inc exactly. The port keeps the pointer
;    arithmetic rather than naming the second variable directly, so the
;    adjacency stays as load-bearing here as it is in pret.
;
; 2. `jr nz` READS THE ZF OF `dec [hl]`, ACROSS AN `ld hl`. pret writes
;    `dec [hl] / ld hl, SafariZoneAngryText / jr nz, .done`, so the branch
;    consumes the flags the DECREMENT set — the load between them is
;    flag-neutral on SM83. It is flag-neutral here too, because a `mov` to a
;    register sets no flags in x86. **Replacing that mov with anything that
;    writes flags (lea is fine, an add or a test is not) silently inverts the
;    catch-rate refresh below.** The refresh fires only when the escape factor
;    has just reached ZERO.
; ---------------------------------------------------------------------------

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

extern GetMonHeader                 ; home/pokemon.asm
extern LoadScreenTilesFromBuffer1   ; home/tilemap.asm
extern PrintText                    ; home/window.asm — ESI = flat text stream
extern SafariZoneEatingText         ; assets/battle_text.inc (generated Tier-1)
extern SafariZoneAngryText          ; assets/battle_text.inc (generated Tier-1)

global PrintSafariZoneBattleText

section .text

; ---------------------------------------------------------------------------
; PrintSafariZoneBattleText — pret safari_zone.asm:1.
; ---------------------------------------------------------------------------
PrintSafariZoneBattleText:
    mov esi, wSafariBaitFactor              ; ld hl, wSafariBaitFactor
    mov al, [ebp + esi]                     ; ld a, [hl]
    test al, al                             ; and a
    jz .no_bait                             ; jr z
    dec byte [ebp + esi]                    ; dec [hl] — one fewer baited turn
    mov esi, SafariZoneEatingText           ; ld hl (flat .data stream)
    jmp .done                               ; jr .done

.no_bait:
    dec esi                                 ; dec hl -> wSafariEscapeFactor (see note 1)
    mov al, [ebp + esi]                     ; ld a, [hl]
    test al, al                             ; and a
    jz .ret                                 ; ret z — neither factor active, print nothing
    dec byte [ebp + esi]                    ; dec [hl] — SETS THE ZF THE BRANCH BELOW READS
    mov esi, SafariZoneAngryText            ; ld hl — flag-neutral, exactly as pret's ld (note 2)
    jnz .done                               ; jr nz — still angry, just print
    ; The escape factor has just hit ZERO: the mon calms down, so its catch rate
    ; goes back to the species' base value.
    push esi                                ; push hl
    mov al, [ebp + wEnemyMonSpecies]
    mov [ebp + wCurSpecies], al
    call GetMonHeader
    mov al, [ebp + wMonHCatchRate]
    mov [ebp + wEnemyMonActualCatchRate], al
    pop esi                                 ; pop hl

.done:
    push esi                                ; push hl
    call LoadScreenTilesFromBuffer1
    pop esi                                 ; pop hl
    jmp PrintText                           ; jp PrintText (tail)

.ret:
    ret
