; faint_leaves.asm — battle-swarm subsystem C, worker task "faint_leaves".
;
; Two faithful SM83->x86 translations from pret engine/battle/core.asm:
;   1. AnyEnemyPokemonAliveCheck  (core.asm:883-898)
;   2. LoadBattleMonFromParty     (core.asm:1667-1708)
;
; Register map (project-wide, CLAUDE.md): A=AL; F.Z->ZF, F.C->CF;
; BC=EBX (B=BH,C=BL); DE=EDX (D=DH,E=DL); HL=ESI (full 32-bit);
; EBP=emulated GB base, so GB [addr] = [ebp+addr]. `ld a,[hli]` = read
; [ebp+esi] then inc esi. 16-bit `ld bc, X - Y` immediates become plain
; NASM constant expressions.
;
; Linked into the live EXE (Makefile FRONTEND_SRCS, battle-swarm-C).
; Build check: nasm -f coff -I include/ -I . -o /dev/null scratch/faint_leaves.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_macros.inc"

; === NEEDS-INTEGRATION: relocate to include/gb_memmap.inc or gb_constants.inc ===
; wPartyMon1Species is pret's alias for the party-mon-1 base address (MON_SPECIES
; offset 0 within the struct, so "...Species" == the struct base itself). The
; port's gb_memmap.inc already defines the struct base as wPartyMon1 ($D16A,
; verified sym per project memory "WRAM addresses resolved"). Since MON_SPECIES
; equ 0x00 (gb_constants.inc:60), wPartyMon1Species == wPartyMon1 with no offset
; needed. Defined here as an alias so the call site below reads identically to
; pret; move this equ into gb_memmap.inc next to wPartyMon1 when integrating.
%ifndef wPartyMon1Species
wPartyMon1Species equ wPartyMon1
%endif

extern CopyData                                ; dos_port/src/home/copy_data.asm
extern AddNTimes                               ; dos_port/src/home/array.asm
extern GetMonHeader                            ; dos_port/src/home/pokemon.asm
extern SkipFixedLengthTextEntries              ; dos_port/src/home/array.asm
extern ApplyBurnAndParalysisPenaltiesToPlayer  ; dos_port/src/engine/battle/status_penalties.asm
extern ApplyBadgeStatBoosts                    ; dos_port/src/engine/battle/badge_boosts.asm

global AnyEnemyPokemonAliveCheck
global LoadBattleMonFromParty

section .text

; ---------------------------------------------------------------------------
; AnyEnemyPokemonAliveCheck — pret engine/battle/core.asm:883-898
;
; Loops wEnemyPartyCount times over the enemy party, OR-ing the big-endian HP
; word (2 bytes) of each mon at stride PARTYMON_STRUCT_LENGTH into AL. Returns
; with ZF set from that accumulated AL (pret: `and a` / `ret` — ZF=1 means
; every enemy mon's HP bytes were all zero, i.e. every mon has fainted; ZF=0
; means at least one enemy mon is still alive). Caller is expected to
; `jz`/`jnz` on return, per pret's "stores whether enemy ran in Z flag"-style
; contract used throughout core.asm.
;
; In:  wEnemyPartyCount, wEnemyMon1HP..HP array (WRAM only). No caller-set
;      registers required (pure GB-memory loop).
; Out: ZF = all-fainted flag (1 = all fainted, matches pret `and a`/ret).
;      AL clobbered (final OR accumulator, no defined meaning beyond ZF).
;      ESI, ECX clobbered. EBX/EDX untouched.
; ---------------------------------------------------------------------------
AnyEnemyPokemonAliveCheck:
    movzx ecx, byte [ebp + wEnemyPartyCount]   ; ld a,[wEnemyPartyCount] / ld b,a
    xor al, al                                 ; xor a
    mov esi, wEnemyMon1HP                      ; ld hl, wEnemyMon1HP (raw GB offset)
.nextPokemon:
    or al, [ebp + esi]                         ; or [hl]
    inc esi                                    ; inc hl
    or al, [ebp + esi]                         ; or [hl]
    dec esi                                    ; dec hl
    add esi, PARTYMON_STRUCT_LENGTH            ; add hl, de (de was a compile-time constant)
    ; FIXED at integration: pret's counter is the 8-bit B (`dec b`), so a 0 count
    ; (a wild battle: wEnemyPartyCount==0) wraps at 256 and stays inside GB RAM — benign.
    ; This was widened to 32-bit `dec ecx`, so count 0 → ~4 billion iterations, walking
    ; ESI off the ~96 KB allocation → page fault. Restore pret's 8-bit wrap with `dec cl`
    ; (matches the sibling ChooseNextMon's `dec bl`). Reached only via a wild faint that
    ; shouldn't hit this routine at all — see the wIsInBattle-guard TODO below.
    dec cl                                     ; dec b (8-bit: count 0 wraps at 256, bounded)
    jnz .nextPokemon                           ; jr nz, .nextPokemon
    test al, al                                ; and a — sets ZF from AL, AL unchanged
    ret

; ---------------------------------------------------------------------------
; LoadBattleMonFromParty — pret engine/battle/core.asm:1667-1708
; "copies from party data to battle mon data when sending out a new player mon"
;
; Faithful chunked copy. GEN-2 FORWARD-COMPAT (CLAUDE.md, load-bearing): the
; party struct's offset 7 (MON_CATCH_RATE, aka held-item slot after a Gen1<->
; Gen2 trade) must never be clobbered by this routine. It never is: every
; CopyData call below only *reads* the party struct as a source; the byte at
; source offset 7 is read (as part of the first 12-byte species..moves chunk,
; core.asm:1673-1674) but never written back into the party struct. The
; `add hl, MON_DVS - MON_OTID` (core.asm:1675-1676) skips the source cursor
; over the party-only OTID/Exp/StatExp region (offsets 12-26, absent from the
; battle-mon struct) so the *next* chunk copy resumes at the party struct's
; DVs field (offset 27) — it does not re-touch offset 7. Preserved exactly,
; chunk-for-chunk, per the task brief: do not collapse this into one copy.
;
; In:  wWhichPokemon = party index of the mon being sent out (WRAM only).
;      No caller-set registers required.
; Out: wBattleMon* struct populated; wCurSpecies/wMonHeader set via
;      GetMonHeader; wPlayerMonUnmodifiedLevel..stats block set; burn/
;      paralysis + badge boosts applied; wPlayerMonAttackMod..(+7) reset to
;      the default stat modifier ($7). All GP registers clobbered (matches
;      pret: no register state is preserved across this routine acting as a
;      call boundary with several nested calls).
; ---------------------------------------------------------------------------
LoadBattleMonFromParty:
    ; --- hl = wPartyMon1Species + wWhichPokemon * PARTYMON_STRUCT_LENGTH ---
    mov al, [ebp + wWhichPokemon]              ; ld a, [wWhichPokemon]
    mov bx, PARTYMON_STRUCT_LENGTH              ; ld bc, PARTYMON_STRUCT_LENGTH
    mov esi, wPartyMon1Species                  ; ld hl, wPartyMon1Species
    call AddNTimes                              ; hl = party mon base (raw GB offset)

    ; --- species..moves (12 bytes, core.asm:1673-1674) — includes offset 7
    ;     (MON_CATCH_RATE) as a READ-ONLY source byte; see header note. ---
    mov edx, wBattleMonSpecies                  ; ld de, wBattleMonSpecies
    mov bx, wBattleMonDVs - wBattleMonSpecies    ; ld bc, wBattleMonDVs - wBattleMonSpecies
    call CopyData                                ; hl/de both advance by 12

    ; --- skip party-only OTID/Exp/StatExp (core.asm:1675-1676) ---
    add esi, MON_DVS - MON_OTID                  ; ld bc, MON_DVS - MON_OTID / add hl, bc

    ; --- DVs word (core.asm:1677-1679) ---
    mov edx, wBattleMonDVs                       ; ld de, wBattleMonDVs
    mov bx, MON_PP - MON_DVS                     ; ld bc, MON_PP - MON_DVS
    call CopyData

    ; --- PP, 4 bytes (core.asm:1680-1682) ---
    mov edx, wBattleMonPP                        ; ld de, wBattleMonPP
    mov bx, NUM_MOVES                            ; ld bc, NUM_MOVES
    call CopyData

    ; --- Level + 5 stats, 11 bytes (core.asm:1683-1685) ---
    mov edx, wBattleMonLevel                     ; ld de, wBattleMonLevel
    mov bx, wBattleMonPP - wBattleMonLevel        ; ld bc, wBattleMonPP - wBattleMonLevel
    call CopyData

    ; --- header lookup: wCurSpecies = wBattleMonSpecies2; call GetMonHeader ---
    mov al, [ebp + wBattleMonSpecies2]           ; ld a, [wBattleMonSpecies2]
    mov [ebp + wCurSpecies], al                  ; ld [wCurSpecies], a
    call GetMonHeader

    ; --- nickname copy: skip wPlayerMonNumber NAME_LENGTH entries, then copy ---
    mov esi, wPartyMonNicks                      ; ld hl, wPartyMonNicks
    mov al, [ebp + wPlayerMonNumber]             ; ld a, [wPlayerMonNumber]
    call SkipFixedLengthTextEntries              ; hl += NAME_LENGTH * a
    mov edx, wBattleMonNick                      ; ld de, wBattleMonNick
    mov bx, NAME_LENGTH                          ; ld bc, NAME_LENGTH
    call CopyData

    ; --- snapshot unmodified level+stats block (1 + NUM_STATS*2 bytes) ---
    mov esi, wBattleMonLevel                     ; ld hl, wBattleMonLevel
    mov edx, wPlayerMonUnmodifiedLevel            ; ld de, wPlayerMonUnmodifiedLevel
    mov bx, 1 + NUM_STATS * 2                    ; ld bc, 1 + NUM_STATS * 2
    call CopyData

    ; --- burn/paralysis penalties + badge boosts ---
    call ApplyBurnAndParalysisPenaltiesToPlayer
    call ApplyBadgeStatBoosts

    ; --- reset the 8 stat mods (wPlayerMonAttackMod..) to the default $7 ---
    mov al, 7                                    ; ld a, $7
    mov ecx, NUM_STAT_MODS                       ; ld b, NUM_STAT_MODS
    mov esi, wPlayerMonAttackMod                  ; ld hl, wPlayerMonAttackMod
.statModLoop:
    mov [ebp + esi], al                          ; ld [hli], a
    inc esi
    dec ecx                                      ; dec b
    jnz .statModLoop                             ; jr nz, .statModLoop
    ret
