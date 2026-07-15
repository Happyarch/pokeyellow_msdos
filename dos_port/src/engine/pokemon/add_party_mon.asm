; add_party_mon.asm — _AddPartyMon (Pokémon data/stats plan, Stage 5).
;
; Source: engine/pokemon/add_mon.asm:_AddPartyMon (full faithful translation).
;
; Adds a new mon to the PLAYER's party (wMonDataLocation low nibble = 0) or the
; ENEMY's party (low nibble != 0). If the whole value is 0 the player may name
; the mon through AskName. Writes the
; party-list entry + the 44-byte party_struct (species, DVs, current HP, box
; level/status, types, level-up moves, OT, experience, level, stats). Returns CF
; set on success, CF clear if the party is full.
;
; Wave-5 M5.1 completion (was PARTIAL — see docs/battle_audit_findings.md):
;  - Pokédex owned/seen flags now set on the player path (pret L82–104).
;  - In-battle wild-catch path copies the enemy mon's DVs/HP/status/stats
;    (pret .copyEnemyMonData / L236–241) instead of rolling fresh DVs + CalcStats.
;  - Trainer/enemy-party path uses the fixed ATKDEFDV_TRAINER/SPDSPCDV_TRAINER
;    IVs and skips the Dex update (pret L76–80).
;  - Real OT-ID = wPlayerID (pret L201–206), no longer 0.
;  - MON_CATCH_RATE (struct offset 7) preserved verbatim (Gen-2 held-item slot).
;
; DIVERGENCES:
;  - IndexToPokedex is the port's flat internal→dex table, read directly (as in
;    evolution.asm / evos_moves.asm) instead of pret's in-place predef.
;  - AddPartyMon_WriteMovePP reads the base PP straight from the flat Moves table
;    instead of FarCopyData-ing the record to wMoveData.
;
; Register map: a=AL, b=BH, c=BL, d=DH, hl=ESI, de=EDX, bc=EBX.

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

; --- WRAM symbols not (yet) carried in gb_memmap.inc ---------------------------
; wPokedexOwned/wPokedexSeen/wUnusedAlreadyOwnedFlag now live canonically in
; gb_memmap.inc (Wave 5 integration).

extern GetMonHeader
extern CalcStat
extern CalcStats
extern CalcExperience
extern Random_
extern SkipFixedLengthTextEntries
extern CopyData
extern AddNTimes
extern WriteMonMoves
extern Moves
extern MonsterNames
extern IndexToPokedex               ; flat table: byte[species-1] = national dex#
extern FlagAction                   ; esi=flag array, cl=bit index, bh=action
extern AskName                      ; engine/menus/naming_screen.asm — pret predef target

global _AddPartyMon

section .text

_AddPartyMon:
    ; wMonDataLocation low nibble: 0 = player party, else enemy party.
    mov edx, wPartyCount             ; de = party count var (player default)
    mov al, [ebp + wMonDataLocation]
    and al, 0x0F
    jz .haveCount
    mov edx, wEnemyPartyCount
.haveCount:
    mov al, [ebp + edx]
    inc al
    cmp al, PARTY_LENGTH + 1
    jc .notFull
    ret                              ; party full (ret nc): CF clear
.notFull:
    mov [ebp + edx], al              ; new count (doubles as hNewPartyLength)

    ; append species: edx = countvar + newcount -> &species[count-1]
    movzx ecx, al
    add edx, ecx
    mov al, [ebp + wCurPartySpecies]
    mov [ebp + edx], al
    inc edx
    mov byte [ebp + edx], 0xFF       ; list terminator

    ; OT name slot: hl = wPartyMonOT / wEnemyMonOT + (count-1)*NAME_LENGTH
    mov esi, wPartyMonOT
    mov al, [ebp + wMonDataLocation]
    and al, 0x0F
    jz .otDest
    mov esi, wEnemyMonOT
.otDest:
    call .loadNewLenM1               ; al = hNewPartyLength - 1
    call SkipFixedLengthTextEntries
    mov edx, esi                     ; de = OT dest
    mov esi, wPlayerName
    mov bx, NAME_LENGTH
    call CopyData

    ; pret: only the whole-zero player path runs predef AskName.
    mov al, [ebp + wMonDataLocation]
    test al, al
    jnz .skipNaming
    mov esi, wPartyMonNicks
    mov al, [ebp + wPartyCount]      ; player path ⇒ count var is wPartyCount
    dec al
    call SkipFixedLengthTextEntries          ; esi = &nick[count-1] (WRAM)
    mov eax, esi
    mov byte [ebp + wPredefHL + 1], al
    shr eax, 8
    mov byte [ebp + wPredefHL], al           ; GB predef register is big-endian
    mov byte [ebp + wNamingScreenType], NAME_MON_SCREEN
    call AskName
.skipNaming:

    ; hl = wPartyMons / wEnemyMons + (count-1)*PARTYMON_STRUCT_LENGTH
    mov esi, wPartyMons
    mov al, [ebp + wMonDataLocation]
    and al, 0x0F
    jz .structBase
    mov esi, wEnemyMons
.structBase:
    call .loadNewLenM1               ; al = count-1
    mov bx, PARTYMON_STRUCT_LENGTH
    call AddNTimes
    mov edx, esi                     ; de = struct start (write cursor)
    push esi                         ; [S1] struct ptr (for final stats)

    ; species byte (internal index)
    mov al, [ebp + wCurPartySpecies]
    mov [ebp + wCurSpecies], al
    call GetMonHeader
    mov al, [ebp + wMonHeader]
    mov [ebp + edx], al
    inc edx                          ; de = struct+1

    ; --- DV / Dex / wild-catch selection (pret L76–162) ----------------------
    ; Enemy-party path uses fixed trainer IVs and skips the Dex update.
    mov al, [ebp + wMonDataLocation]
    and al, 0x0F                     ; sets ZF; the movs below preserve it
    mov al, ATKDEFDV_TRAINER         ; DV byte 0 (fixed trainer avg)
    mov bh, SPDSPCDV_TRAINER         ; DV byte 1
    jnz .writeDVs                    ; enemy party ⇒ fixed IVs, skip Dex

    ; Player path: update the Pokédex (owned + seen).
    ; pret: ld [wPokedexNum],a; predef IndexToPokedex. Port table is flat.
    mov al, [ebp + wCurPartySpecies]
    mov [ebp + wPokedexNum], al
    dec al
    movzx eax, al
    movzx eax, byte [IndexToPokedex + eax]   ; national dex # (1-based)
    mov [ebp + wPokedexNum], al              ; pret leaves dex# in wPokedexNum
    dec al                                    ; 0-based flag index
    mov cl, al
    mov bh, FLAG_TEST
    mov esi, wPokedexOwned
    call FlagAction                           ; cl = was-already-owned bit
    mov [ebp + wUnusedAlreadyOwnedFlag], cl   ; pret dead store, kept faithful
    mov al, [ebp + wPokedexNum]
    dec al
    mov cl, al
    mov bh, FLAG_SET
    mov esi, wPokedexOwned
    push ecx                          ; preserve flag index across owned-set
    call FlagAction
    pop ecx
    mov esi, wPokedexSeen
    call FlagAction                   ; FlagAction preserves ebx/edx/esi

    ; Wild mon caught in battle? (any nonzero wIsInBattle)
    mov al, [ebp + wIsInBattle]
    test al, al
    jnz .copyEnemyMonData
    ; Not wild: random IVs — bh = 1st byte, al = 2nd byte.
    call Random_
    mov bh, al
    call Random_

.writeDVs:
    mov esi, [esp]                    ; [S1] struct ptr
    add esi, MON_DVS
    mov [ebp + esi], al              ; DV byte 0
    inc esi
    mov [ebp + esi], bh              ; DV byte 1

    ; current HP = max HP: CalcStat(c=1 HP, b=0)
    mov esi, [esp]
    add esi, MON_HP_EXP - 1
    mov bl, 1
    mov bh, 0
    call CalcStat
    mov al, [ebp + hMultiplicand + 1]
    mov [ebp + edx], al
    inc edx
    mov al, [ebp + hMultiplicand + 2]
    mov [ebp + edx], al
    inc edx                          ; de = struct+3
    xor al, al
    mov [ebp + edx], al              ; box level 0
    inc edx
    mov [ebp + edx], al              ; status 0
    inc edx                          ; de = struct+5
    jmp .copyMonTypesAndMoves

.copyEnemyMonData:
    ; Wild catch: copy DVs / HP / status from the current enemy mon.
    mov esi, [esp]                   ; [S1] struct ptr
    add esi, MON_DVS
    mov al, [ebp + wEnemyMonDVs]
    mov [ebp + esi], al              ; DV byte 0 from enemy
    inc esi
    mov al, [ebp + wEnemyMonDVs + 1]
    mov [ebp + esi], al              ; DV byte 1 from enemy
    mov al, [ebp + wEnemyMonHP]
    mov [ebp + edx], al              ; cur HP hi from enemy
    inc edx
    mov al, [ebp + wEnemyMonHP + 1]
    mov [ebp + edx], al              ; cur HP lo from enemy
    inc edx
    xor al, al
    mov [ebp + edx], al              ; box level 0
    inc edx
    mov al, [ebp + wEnemyMonStatus]
    mov [ebp + edx], al              ; status from enemy
    inc edx                          ; de = struct+5

.copyMonTypesAndMoves:
    ; types + catch rate from wMonHTypes
    mov esi, wMonHTypes
    mov al, [ebp + esi]
    inc esi
    mov [ebp + edx], al              ; type1
    inc edx
    mov al, [ebp + esi]
    inc esi
    mov [ebp + edx], al              ; type2
    inc edx
    mov al, [ebp + esi]
    mov [ebp + edx], al              ; catch rate (de not yet incremented)
    ; Gen-1↔Gen-2 forward-compat (faithful to pret): the MON_CATCH_RATE byte
    ; (struct offset 7) is the held-item slot in Gen 2's Time Capsule, so a mon
    ; traded up keeps an item here. Kadabra ships already holding a TwistedSpoon,
    ; so overwrite its catch rate with TWISTEDSPOON_GSC. Keep this byte intact and
    ; never repurpose/shrink the struct, or the future Gen 2 port loses held items.
    mov al, [ebp + wCurPartySpecies]
    cmp al, KADABRA
    jne .notKadabra
    mov byte [ebp + edx], TWISTEDSPOON_GSC
.notKadabra:

    ; level-1 moves from wMonHMoves
    mov esi, wMonHMoves
    mov al, [ebp + esi]
    inc esi
    inc edx                          ; de = struct+8 (MON_MOVES)
    push edx                         ; [S2] moves ptr (for PP)
    mov [ebp + edx], al
    mov al, [ebp + esi]
    inc esi
    inc edx
    mov [ebp + edx], al
    mov al, [ebp + esi]
    inc esi
    inc edx
    mov [ebp + edx], al
    mov al, [ebp + esi]
    inc esi
    inc edx
    mov [ebp + edx], al              ; de = struct+11

    ; Stage 6: add the moves this mon would know by wCurEnemyLevel. pret does
    ; `predef WriteMonMoves` with de = MON_MOVES base; the predef dispatch stashes
    ; de in wPredefDE, which WriteMonMoves restores via GetPredefRegisters. We set
    ; wPredefDE directly (MON_MOVES base = edx-3, since edx = MON_MOVES+3 here).
    lea ecx, [edx - 3]               ; MON_MOVES base (GB addr, < 0x10000)
    mov [ebp + wPredefDE], ch        ; big-endian: high byte
    mov [ebp + wPredefDE + 1], cl    ;             low byte
    xor al, al
    mov [ebp + wLearningMovesFromDayCare], al
    push edx                         ; save de = struct+11 (WriteMonMoves clobbers edx)
    call WriteMonMoves
    pop edx                          ; restore de = struct+11

    ; OT id = wPlayerID (trainer id of the catching/receiving player)
    mov al, [ebp + wPlayerID]
    inc edx
    mov [ebp + edx], al              ; OTID hi (struct+12)
    mov al, [ebp + wPlayerID + 1]
    inc edx
    mov [ebp + edx], al              ; OTID lo (struct+13)

    ; experience = CalcExperience(level)
    push edx                         ; [S3]
    mov al, [ebp + wCurEnemyLevel]
    mov dh, al
    call CalcExperience
    pop edx                          ; [S3]
    inc edx
    mov al, [ebp + hExperience]
    mov [ebp + edx], al              ; exp hi (struct+14)
    inc edx
    mov al, [ebp + hExperience + 1]
    mov [ebp + edx], al
    inc edx
    mov al, [ebp + hExperience + 2]
    mov [ebp + edx], al              ; de = struct+16

    ; zero EVs (NUM_STATS*2 bytes)
    mov bh, NUM_STATS * 2
.evLoop:
    inc edx
    mov byte [ebp + edx], 0
    dec bh
    jnz .evLoop                      ; de = struct+0x1A

    inc edx
    inc edx                          ; de = struct+0x1C
    pop esi                          ; [S2] moves ptr (MON_MOVES base) = WritePP source
    call AddPartyMon_WriteMovePP_PartyBuilder ; local flat-table variant

    ; level
    inc edx
    mov al, [ebp + wCurEnemyLevel]
    mov [ebp + edx], al              ; struct+MON_LEVEL (0x21)
    inc edx                          ; de = struct+MON_STATS (0x22)

    ; final stats: wild catch copies the enemy mon's stats; otherwise CalcStats.
    mov al, [ebp + wIsInBattle]
    dec al
    jnz .calcFreshStats              ; wIsInBattle != 1 ⇒ fresh stats
    mov esi, wEnemyMonMaxHP          ; src; edx already = MON_STATS dest
    mov bx, NUM_STATS * 2
    call CopyData                    ; copy stats of cur enemy mon
    pop esi                          ; [S1] discard
    jmp .doneOK
.calcFreshStats:
    pop esi                          ; [S1] struct ptr
    add esi, MON_HP_EXP - 1
    mov bh, 0
    call CalcStats
.doneOK:
    stc                              ; success
    ret

; hNewPartyLength - 1 helper (port has no hNewPartyLength HRAM slot; the count
; var was just written, so re-reading it yields the new length). Clobbers AL/flags.
.loadNewLenM1:
    mov al, [ebp + wMonDataLocation]
    and al, 0x0F
    jz .lnPlayer
    mov al, [ebp + wEnemyPartyCount]
    dec al
    ret
.lnPlayer:
    mov al, [ebp + wPartyCount]
    dec al
    ret

; AddPartyMon_WriteMovePP_PartyBuilder — port-local flat-table variant of the
; pret AddPartyMon_WriteMovePP provider in write_moves.asm.
; Source: engine/pokemon/add_mon.asm:AddPartyMon_WriteMovePP.
; In: ESI (hl) = MON_MOVES base (move ids, WRAM); EDX (de) = MON_PP - 1 (WRAM).
; DIVERGENCE: read the PP byte straight from the flat Moves table (like
; GetMonHeader) instead of FarCopyData-ing the record to wMoveData.
; NOTE (Wave-5 M5.2): a duplicate lives in add_mon.asm; leave this file-local
; copy intact — M5.2 resolves the duplication.
AddPartyMon_WriteMovePP_PartyBuilder:
    mov bh, NUM_MOVES
.pploop:
    mov al, [ebp + esi]              ; ld a,[hli] — move id from slot
    inc esi
    test al, al
    jz .empty                       ; empty slot ⇒ PP 0
    movzx eax, al
    dec eax
    imul eax, eax, MOVE_LENGTH
    mov al, [Moves + eax + MOVE_PP]  ; base PP (flat table)
.empty:
    inc edx
    mov [ebp + edx], al              ; ld [de],a (PP, or 0 for empty)
    dec bh
    jnz .pploop
    ret
