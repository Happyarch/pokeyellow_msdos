; load_enemy_from_party.asm — battle-swarm subsystem C, worker task
; "load_enemy_from_party".
;
; Faithful SM83->x86 translation of pret engine/battle/core.asm:1711-1762
; (LoadEnemyMonFromParty) — "copies from enemy party data to current enemy
; mon data when sending out a new enemy mon". This is the enemy-side twin of
; LoadBattleMonFromParty (dos_port/scratch/faint_leaves.asm); same chunked
; CopyData idiom, same MON_DVS-MON_OTID skip, same AddNTimes/CopyData/
; SkipFixedLengthTextEntries contracts (verified directly against
; dos_port/src/home/array.asm and dos_port/src/home/copy_data.asm).
;
; Register map (project-wide, CLAUDE.md): A=AL; F.Z->ZF, F.C->CF;
; BC=EBX (B=BH,C=BL); DE=EDX (D=DH,E=DL); HL=ESI (full 32-bit);
; EBP=emulated GB base, so GB [addr] = [ebp+addr]. `ld a,[hli]` = read
; [ebp+esi] then inc esi. 16-bit `ld bc, X - Y` immediates become plain
; NASM constant expressions.
;
; Linked into the live EXE (Makefile FRONTEND_SRCS, battle-swarm-C).
; Build check: nasm -f coff -I include/ -I . -o /dev/null scratch/load_enemy_from_party.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_macros.inc"

; === NEEDS-INTEGRATION ===
; None. Every WRAM/const symbol named in the task brief was found already
; defined in the port's shared includes (grepped directly, see worker report):
;   wWhichPokemon (gb_memmap.inc:161), wEnemyMons (:216), PARTYMON_STRUCT_LENGTH
;   (gb_constants.inc:84), wEnemyMonSpecies (gb_memmap.inc:315), wEnemyMonDVs
;   (:325), wEnemyMonPP (:333), wEnemyMonLevel (:326), wCurSpecies (:131),
;   wEnemyMonNicks (:1243), wEnemyMonNick (:313), wEnemyMonUnmodifiedLevel
;   (:274), wMonHBaseStats (:142), wEnemyMonBaseStats (:334), wEnemyMonStatMods
;   (:283), wEnemyMonPartyPos (:318), MON_DVS/MON_OTID/MON_PP/MON_SPECIES
;   (gb_constants.inc:74/67/75/58), NUM_MOVES (:14), NAME_LENGTH (:21),
;   NUM_STATS (:13), NUM_STAT_MODS (:269).
; No local equ block needed — unlike the sibling LoadBattleMonFromParty, which
; had to alias wPartyMon1Species (party side), the enemy side's wEnemyMonSpecies
; and wEnemyMonUnmodifiedLevel etc. are already first-class port symbols.

extern CopyData                                ; dos_port/src/home/copy_data.asm
extern AddNTimes                               ; dos_port/src/home/array.asm
extern GetMonHeader                            ; dos_port/src/home/pokemon.asm
extern SkipFixedLengthTextEntries              ; dos_port/src/home/array.asm
extern ApplyBurnAndParalysisPenaltiesToEnemy   ; dos_port/src/engine/battle/status_penalties.asm

global LoadEnemyMonFromParty

section .text

; ---------------------------------------------------------------------------
; LoadEnemyMonFromParty — pret engine/battle/core.asm:1711-1762
; "copies from enemy party data to current enemy mon data when sending out a
; new enemy mon"
;
; Faithful chunked copy, mirroring LoadBattleMonFromParty's structure exactly
; (see dos_port/scratch/faint_leaves.asm for the player-side twin and its
; header note on the CopyData/AddNTimes/SkipFixedLengthTextEntries register
; contracts, verified there against dos_port/src/home/copy_data.asm and
; dos_port/src/home/array.asm — reused unchanged here).
;
; GEN-2 FORWARD-COMPAT (CLAUDE.md, load-bearing): the enemy party struct's
; offset 7 (MON_CATCH_RATE, aka held-item slot after a Gen1<->Gen2 trade) must
; never be clobbered by this routine. It never is: the first CopyData call
; below (species..moves, 12 bytes, core.asm:1714-1717 / wEnemyMonSpecies..
; wEnemyMonDVs) only *reads* offset 7 out of wEnemyMons (the party struct) as
; a source byte and writes it into wEnemyMonCatchRate (0xCFEB, offset 7 of
; the battle-mon struct — a real, distinct field there, not a repurposed
; slot) — it never writes back into the party struct. The `add hl, MON_DVS - MON_OTID`
; (core.asm:1718-1719) then skips the source cursor over the party-only
; OTID/Exp/StatExp region (offsets 12-26, absent from the battle-mon struct)
; so the *next* chunk copy resumes at the party struct's DVs field (offset
; 27) — it does not re-touch offset 7. Preserved exactly, chunk-for-chunk.
;
; In:  wWhichPokemon = party index of the enemy mon being sent out (WRAM
;      only). No caller-set registers required.
; Out: wEnemyMon* struct populated; wCurSpecies/wMonHeader set via
;      GetMonHeader; wEnemyMonUnmodifiedLevel..stats block set; burn/
;      paralysis penalties applied; wEnemyMonBaseStats copied from
;      wMonHBaseStats; wEnemyMonAttackMod..(+7) reset to the default stat
;      modifier ($7); wEnemyMonPartyPos = wWhichPokemon. All GP registers
;      clobbered (matches pret: no register state is preserved across this
;      routine acting as a call boundary with several nested calls).
; ---------------------------------------------------------------------------
LoadEnemyMonFromParty:
    ; --- hl = wEnemyMons + wWhichPokemon * PARTYMON_STRUCT_LENGTH ---
    mov al, [ebp + wWhichPokemon]               ; ld a, [wWhichPokemon]
    mov bx, PARTYMON_STRUCT_LENGTH               ; ld bc, PARTYMON_STRUCT_LENGTH
    mov esi, wEnemyMons                          ; ld hl, wEnemyMons
    call AddNTimes                               ; hl = enemy party mon base (raw GB offset)

    ; --- species..moves (12 bytes, core.asm:1714-1717) — includes offset 7
    ;     (MON_CATCH_RATE) as a READ-ONLY source byte; see header note. ---
    mov edx, wEnemyMonSpecies                    ; ld de, wEnemyMonSpecies
    mov bx, wEnemyMonDVs - wEnemyMonSpecies       ; ld bc, wEnemyMonDVs - wEnemyMonSpecies
    call CopyData                                 ; hl/de both advance by 12

    ; --- skip party-only OTID/Exp/StatExp (core.asm:1718-1719) ---
    add esi, MON_DVS - MON_OTID                   ; ld bc, MON_DVS - MON_OTID / add hl, bc

    ; --- DVs word (core.asm:1720-1722) ---
    mov edx, wEnemyMonDVs                         ; ld de, wEnemyMonDVs
    mov bx, MON_PP - MON_DVS                      ; ld bc, MON_PP - MON_DVS
    call CopyData

    ; --- PP, 4 bytes (core.asm:1723-1725) ---
    mov edx, wEnemyMonPP                          ; ld de, wEnemyMonPP
    mov bx, NUM_MOVES                             ; ld bc, NUM_MOVES
    call CopyData

    ; --- Level + 5 stats, 11 bytes (core.asm:1726-1728) ---
    mov edx, wEnemyMonLevel                       ; ld de, wEnemyMonLevel
    mov bx, wEnemyMonPP - wEnemyMonLevel           ; ld bc, wEnemyMonPP - wEnemyMonLevel
    call CopyData

    ; --- header lookup: wCurSpecies = wEnemyMonSpecies; call GetMonHeader ---
    mov al, [ebp + wEnemyMonSpecies]              ; ld a, [wEnemyMonSpecies]
    mov [ebp + wCurSpecies], al                   ; ld [wCurSpecies], a
    call GetMonHeader

    ; --- nickname copy: skip wWhichPokemon NAME_LENGTH entries, then copy ---
    mov esi, wEnemyMonNicks                       ; ld hl, wEnemyMonNicks
    mov al, [ebp + wWhichPokemon]                 ; ld a, [wWhichPokemon]
    call SkipFixedLengthTextEntries               ; hl += NAME_LENGTH * a
    mov edx, wEnemyMonNick                        ; ld de, wEnemyMonNick
    mov bx, NAME_LENGTH                           ; ld bc, NAME_LENGTH
    call CopyData

    ; --- snapshot unmodified level+stats block (1 + NUM_STATS*2 bytes) ---
    mov esi, wEnemyMonLevel                       ; ld hl, wEnemyMonLevel
    mov edx, wEnemyMonUnmodifiedLevel             ; ld de, wEnemyMonUnmodifiedLevel
    mov bx, 1 + NUM_STATS * 2                     ; ld bc, 1 + NUM_STATS * 2
    call CopyData

    ; --- burn/paralysis penalties (enemy has no badge boosts) ---
    call ApplyBurnAndParalysisPenaltiesToEnemy

    ; --- base-stats copy loop: wMonHBaseStats -> wEnemyMonBaseStats, NUM_STATS bytes ---
    mov esi, wMonHBaseStats                       ; ld hl, wMonHBaseStats
    mov edx, wEnemyMonBaseStats                   ; ld de, wEnemyMonBaseStats
    mov ecx, NUM_STATS                            ; ld b, NUM_STATS
.copyBaseStatsLoop:
    mov al, [ebp + esi]                           ; ld a, [hli]
    inc esi
    mov [ebp + edx], al                           ; ld [de], a
    inc edx                                        ; inc de
    dec ecx                                        ; dec b
    jnz .copyBaseStatsLoop                        ; jr nz, .copyBaseStatsLoop

    ; --- reset the 8 stat mods (wEnemyMonAttackMod..) to the default $7 ---
    mov al, 7                                     ; ld a, $7
    mov ecx, NUM_STAT_MODS                        ; ld b, NUM_STAT_MODS
    mov esi, wEnemyMonStatMods                    ; ld hl, wEnemyMonStatMods
.statModLoop:
    mov [ebp + esi], al                           ; ld [hli], a
    inc esi
    dec ecx                                        ; dec b
    jnz .statModLoop                              ; jr nz, .statModLoop

    ; --- wEnemyMonPartyPos = wWhichPokemon ---
    mov al, [ebp + wWhichPokemon]                 ; ld a, [wWhichPokemon]
    mov [ebp + wEnemyMonPartyPos], al             ; ld [wEnemyMonPartyPos], a
    ret
