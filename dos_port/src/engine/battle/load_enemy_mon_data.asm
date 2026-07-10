; load_enemy_mon_data.asm — LoadEnemyMonData
;
; Faithful SM83->x86 translation of pret engine/battle/core.asm:LoadEnemyMonData
; (the ~6174 block): build the active enemy battle mon (wEnemyMon*) from
; wEnemyMonSpecies2 + wCurEnemyLevel — DVs, stats (CalcStats), current HP,
; types, moves (header defaults + WriteMonMoves), move PPs, base stats/exp,
; nickname, pokédex-seen flag, unmodified-level snapshot, and default stat mods.
;
; This is the wild/opponent counterpart to LoadEnemyMonFromParty (the link path,
; which pret `jp z`'s to). Without it the overworld encounter path had no way to
; populate wEnemyMon* — the DEBUG_BATTLE harness inlined a hardcoded PIDGEY seed.
;
; Register map (CLAUDE.md): A=AL; F.Z->ZF, F.C->CF; HL=ESI; DE=EDX; BC=EBX
; (B=BH, C=BL); EBP = GB memory base; GB memory = [EBP+addr]; ld[hli] -> mov+inc.
;
%include "gb_memmap.inc"
%include "gb_macros.inc"
%include "gb_constants.inc"

bits 32

%ifndef LINK_STATE_BATTLING
%define LINK_STATE_BATTLING 4
%endif

section .text

global LoadEnemyMonData
extern LoadEnemyMonFromParty            ; load_enemy_from_party.asm — link-battle path
extern GetMonHeader                     ; home/pokemon.asm — loads wMonHeader from wCurSpecies
extern BattleRandom                     ; core_damage.asm — battle RNG
extern CalcStats                        ; home/move_mon.asm — EDX=dest, ESI=EV base, BH=useEVs
extern AddNTimes                        ; home/array.asm — HL += BC*A
extern CopyData                         ; home/copy_data.asm — copy BC bytes ESI->EDX
extern GetMonName                       ; home/names.asm — wNamedObjectIndex -> wNameBuffer
extern WriteMonMoves                    ; write_moves.asm — level-up moveset (predef: wPredefDE)
extern LoadMovePPs                      ; write_moves.asm — PPs (predef: wPredefHL/DE)
extern IndexToPokedex                   ; pokemon_data.asm — flat TABLE byte[species-1]=dex# (NOT a routine)
extern FlagAction                       ; flag_action.asm — ESI=array, CL=bit, BH=action

; ---------------------------------------------------------------------------
LoadEnemyMonData:
    ; link battle → copy from the enemy party structs instead (pret: jp z)
    mov al, [ebp + wLinkState]
    cmp al, LINK_STATE_BATTLING
    je  LoadEnemyMonFromParty

    ; wCurSpecies = wEnemyMonSpecies = wEnemyMonSpecies2, then load its header.
    mov al, [ebp + wEnemyMonSpecies2]
    mov [ebp + wEnemyMonSpecies], al
    mov [ebp + wCurSpecies], al
    ; ; PROJ(port): the port's WriteMonMoves->GetMonLearnset reads wCurPartySpecies
    ; (not pret's wCurSpecies), so mirror the species there too for the moveset gen.
    mov [ebp + wCurPartySpecies], al
    call GetMonHeader

    ; --- DVs: transformed → original DVs; trainer → fixed; wild → random ---
    mov al, [ebp + wEnemyBattleStatus3]
    test al, 1 << TRANSFORMED
    mov esi, wTransformedEnemyMonOriginalDVs
    mov al, [ebp + esi]                 ; a = orig DV byte 1
    inc esi
    mov bh, [ebp + esi]                 ; b = orig DV byte 2
    jnz .storeDVs                       ; transformed → keep original DVs
    mov al, [ebp + wIsInBattle]
    cmp al, 2                           ; trainer battle?
    mov al, ATKDEFDV_TRAINER
    mov bh, SPDSPCDV_TRAINER
    jz  .storeDVs                       ; trainer → fixed DVs
    call BattleRandom                   ; wild → random DVs
    mov bh, al
    call BattleRandom
.storeDVs:
    mov esi, wEnemyMonDVs
    mov [ebp + esi], al                 ; DV byte 1
    inc esi
    mov [ebp + esi], bh                 ; DV byte 2

    ; --- level + stats ---
    mov edx, wEnemyMonLevel
    mov al, [ebp + wCurEnemyLevel]
    mov [ebp + edx], al                 ; store level
    inc edx                             ; edx → wEnemyMonMaxHP (stat block dest)
    mov bh, 0                           ; b = 0 (don't consider stat exp)
    mov esi, wEnemyMonHP                ; hl = EV base (pret passes wEnemyMonHP; unused, b=0)
    push esi
    call CalcStats                      ; writes MaxHP/Atk/Def/Spd/Spc to [edx]
    pop esi                             ; esi = wEnemyMonHP (current-HP dest below)

    mov al, [ebp + wIsInBattle]
    cmp al, 2
    jz  .copyHPAndStatusFromPartyData
    mov al, [ebp + wEnemyBattleStatus3]
    test al, 1 << TRANSFORMED
    jnz .copyTypes                      ; transformed → HP already set, skip
    ; wild, not transformed: current HP = max HP, status = 0
    mov al, [ebp + wEnemyMonMaxHP]
    mov [ebp + esi], al                 ; ld [hli], a
    inc esi
    mov al, [ebp + wEnemyMonMaxHP + 1]
    mov [ebp + esi], al
    inc esi
    inc esi                             ; skip wEnemyMonPartyPos (pret: inc hl)
    mov byte [ebp + esi], 0             ; status = 0
    jmp .copyTypes

.copyHPAndStatusFromPartyData:
    ; trainer mon: copy HP + status from the enemy party struct wWhichPokemon
    mov esi, wEnemyMon1HP
    mov al, [ebp + wWhichPokemon]
    mov ebx, PARTYMON_STRUCT_LENGTH     ; pret: wEnemyMon2 - wEnemyMon1 (enemy party stride)
    call AddNTimes                      ; esi += ebx*al
    mov al, [ebp + esi]
    mov [ebp + wEnemyMonHP], al
    inc esi
    mov al, [ebp + esi]
    mov [ebp + wEnemyMonHP + 1], al
    inc esi
    mov al, [ebp + wWhichPokemon]
    mov [ebp + wEnemyMonPartyPos], al
    inc esi                             ; pret: inc hl (skip to status byte)
    mov al, [ebp + esi]
    mov [ebp + wEnemyMonStatus], al

.copyTypes:
    ; types (2) + catch rate (1) from the mon header
    mov esi, wMonHTypes
    mov edx, wEnemyMonType
    mov al, [ebp + esi]                 ; type 1
    inc esi
    mov [ebp + edx], al
    inc edx
    mov al, [ebp + esi]                 ; type 2
    inc esi
    mov [ebp + edx], al
    inc edx
    mov al, [ebp + esi]                 ; catch rate
    inc esi
    mov [ebp + edx], al
    inc edx                             ; edx → wEnemyMonMoves

    mov al, [ebp + wIsInBattle]
    cmp al, 2
    jnz .copyStandardMoves
    ; trainer: copy the 4 moves straight from the enemy party struct
    mov esi, wEnemyMon1Moves
    mov al, [ebp + wWhichPokemon]
    mov ebx, PARTYMON_STRUCT_LENGTH
    call AddNTimes
    mov ebx, NUM_MOVES
    call CopyData                       ; copies to [edx], advances edx by NUM_MOVES
    jmp .loadMovePPs

.copyStandardMoves:
    ; wild: copy the header's 4 default moves, then WriteMonMoves fills level-up moves
    mov esi, wMonHMoves
    mov al, [ebp + esi]
    inc esi
    mov [ebp + edx], al
    inc edx
    mov al, [ebp + esi]
    inc esi
    mov [ebp + edx], al
    inc edx
    mov al, [ebp + esi]
    inc esi
    mov [ebp + edx], al
    inc edx
    mov al, [ebp + esi]                 ; 4th move (no esi advance needed)
    mov [ebp + edx], al
    dec edx
    dec edx
    dec edx                             ; edx → wEnemyMonMoves (base) for the predef
    mov byte [ebp + wLearningMovesFromDayCare], 0
    ; predef WriteMonMoves — stage de = wEnemyMonMoves in wPredefDE (big-endian)
    mov [ebp + wPredefDE], dh
    mov [ebp + wPredefDE + 1], dl
    call WriteMonMoves

.loadMovePPs:
    ; predef LoadMovePPs — hl = wEnemyMonMoves, de = wEnemyMonPP - 1
    mov word [ebp + wPredefHL], (wEnemyMonMoves >> 8) | ((wEnemyMonMoves & 0xFF) << 8)
    mov edx, wEnemyMonPP - 1
    mov [ebp + wPredefDE], dh
    mov [ebp + wPredefDE + 1], dl
    call LoadMovePPs

    ; --- base stats (NUM_STATS) + catch rate + base exp from the header ---
    mov esi, wMonHBaseStats
    mov edx, wEnemyMonBaseStats
    mov bh, NUM_STATS
.copyBaseStatsLoop:
    mov al, [ebp + esi]
    inc esi
    mov [ebp + edx], al
    inc edx
    dec bh
    jnz .copyBaseStatsLoop
    mov esi, wMonHCatchRate
    mov al, [ebp + esi]                 ; catch rate
    inc esi
    mov [ebp + edx], al
    inc edx
    mov al, [ebp + esi]                 ; base exp
    mov [ebp + edx], al

    ; --- nickname = species name ---
    mov al, [ebp + wEnemyMonSpecies2]
    mov [ebp + wNamedObjectIndex], al
    call GetMonName
    mov esi, wNameBuffer
    mov edx, wEnemyMonNick
    mov ebx, NAME_LENGTH
    call CopyData

    ; --- mark seen in the pokédex ---
    ; pret does `predef IndexToPokedex` (species in wd11e → dex# in wd11e). In the
    ; PORT, IndexToPokedex is a flat DATA TABLE (byte[species-1] = national dex#),
    ; NOT a routine — index it directly (mirrors LoadFrontSpriteByMonIndex in
    ; home/pics.asm). Calling it as code jumps into .data → page fault.
    movzx eax, byte [ebp + wEnemyMonSpecies2]
    dec eax
    movzx eax, byte [IndexToPokedex + eax]  ; dex number (1-based)
    dec eax                             ; dex bit index (0-based)
    mov cl, al
    mov bh, FLAG_SET                    ; FlagAction reads the action in BH
    mov esi, wPokedexSeen
    call FlagAction

    ; --- snapshot unmodified level + stats (1 + NUM_STATS*2 bytes) ---
    mov esi, wEnemyMonLevel
    mov edx, wEnemyMonUnmodifiedLevel
    mov ebx, 1 + NUM_STATS * 2
    call CopyData

    ; --- default stat mods ($7) ---
    mov esi, wEnemyMonStatMods
    mov bh, NUM_STAT_MODS
.statModLoop:
    mov byte [ebp + esi], 7
    inc esi
    dec bh
    jnz .statModLoop
    ret
