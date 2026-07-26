; dos_port/engine/pokemon/add_mon.asm — _AddEnemyMonToPlayerParty + _MoveMon.
;
; Source: engine/pokemon/add_mon.asm:_AddEnemyMonToPlayerParty, _MoveMon
;         (pret/pokeyellow). pret's _AddPartyMon half (and its
;         AddPartyMon_WriteMovePP PP helper) live in add_party_mon.asm in this
;         port; this file carries only the trade / box-move halves.
;
; DUP-SYMBOL RESOLUTION (M5.2): this file previously carried a stale, DIFFERENT
; `global AddPartyMon_WriteMovePP` (dest in EDI, FarCopyData→wMoveData) that
; duplicated the canonical global in write_moves.asm and the file-local copy in
; add_party_mon.asm. It was unreferenced here (pret's only caller, _AddPartyMon,
; is in add_party_mon.asm) so it is DELETED — dedup, not rename. The canonical
; PP writer stays in write_moves.asm.
;
; Register map: a=AL, b=BH, c=BL (bc=EBX), d=DH, e=DL (de=EDX), hl=ESI.
; GB WRAM is [ebp + sym]; data tables are flat program-image labels.
;
; Gen-2 forward-compat: every party↔box / enemy→party copy moves the FULL
; BOXMON_STRUCT_LENGTH (33) bytes in one CopyData, carrying struct offset 7
; (MON_CATCH_RATE / held item) through verbatim — see CLAUDE.md.
;
; Build: nasm -f coff -I include/ -I . -o add_mon.o add_mon.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

global _AddPartyMon
global LoadMovePPs
global AddPartyMon_WriteMovePP
global _AddEnemyMonToPlayerParty
global _MoveMon

extern AddNTimes
extern CopyData
extern SkipFixedLengthTextEntries
extern FlagAction
extern IndexToPokedex               ; engine/menus/pokedex.asm — predef, wPokedexNum in place
extern LoadMonData
extern CalcLevelFromExperience
extern CalcStats
extern GetMonHeader
extern CalcStat
extern CalcExperience
extern Random_
extern WriteMonMoves
extern Moves
extern MonsterNames
extern AskName                      ; engine/menus/naming_screen.asm — pret predef target
extern GetPredefRegisters

section .text

; ===========================================================================
; --- was src/engine/pokemon/add_party_mon.asm and src/engine/pokemon/write_moves.asm ---
; pret engine/pokemon/add_mon.asm order is _AddPartyMon, LoadMovePPs,
; AddPartyMon_WriteMovePP, _AddEnemyMonToPlayerParty, _MoveMon. The two labels
; already here were in that order, so the three arriving ones are PREPENDED and
; the whole file is now in pret order.
; ===========================================================================

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
    mov al, [ebp + wCurPartySpecies]         ; ld a, [wCurPartySpecies]
    mov [ebp + wPokedexNum], al              ; ld [wPokedexNum], a
    call IndexToPokedex                      ; predef IndexToPokedex
    mov al, [ebp + wPokedexNum]              ; ld a, [wPokedexNum] — dex# (1-based)
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

; ---------------------------------------------------------------------------
; LoadMovePPs — write each move's base PP into the 4 PP slots (pret add_mon.asm).
; In (via predef regs): ESI (hl) = move-id source (WRAM), EDX (de) = PP dest − 1
; (WRAM). Empty move slots get PP 0. AddPartyMon_WriteMovePP enters with the
; registers already set (the AddPartyMon path).
;
; DIVERGENCE (faithful to write_moves' existing daycare branch): the base PP is
; read straight from the flat `Moves` table — Moves[(id−1)*MOVE_LENGTH+MOVE_PP] —
; rather than the GB FarCopyData→wMoveData the original uses. Clobbers AL/ECX, BH.
; ---------------------------------------------------------------------------
LoadMovePPs:
    call GetPredefRegisters          ; esi=hl (moves src), edx=de (PP dest − 1)
AddPartyMon_WriteMovePP:
    mov bh, NUM_MOVES
.pploop:
    mov al, [ebp + esi]              ; ld a,[hli] — move id
    inc esi
    test al, al
    jz .empty                        ; empty slot → PP byte 0 (al already 0)
    movzx ecx, al
    dec ecx
    imul ecx, ecx, MOVE_LENGTH
    mov al, [Moves + ecx + MOVE_PP]  ; base PP (flat Moves table)
.empty:
    inc edx                          ; inc de
    mov [ebp + edx], al              ; ld [de],a
    dec bh
    jnz .pploop
    ret

_AddEnemyMonToPlayerParty:
    mov esi, wPartyCount
    mov al, [ebp + esi]
    cmp al, PARTY_LENGTH
    jz .partyFull
    
    inc al
    mov [ebp + esi], al
    mov cl, al
    movzx ecx, cl
    mov edx, esi
    add edx, ecx
    
    mov al, [ebp + wCurPartySpecies]
    mov [ebp + edx], al
    inc edx
    mov byte [ebp + edx], 0xff
    
    mov esi, wPartyMons
    mov al, [ebp + wPartyCount]
    dec al
    mov bx, PARTYMON_STRUCT_LENGTH
    call AddNTimes
    
    mov edx, esi
    mov esi, wLoadedMon
    mov bx, PARTYMON_STRUCT_LENGTH
    call CopyData
    
    mov esi, wPartyMonOT
    mov al, [ebp + wPartyCount]
    dec al
    call SkipFixedLengthTextEntries
    mov edx, esi
    
    mov esi, wEnemyMonOT
    mov al, [ebp + wWhichPokemon]
    call SkipFixedLengthTextEntries
    mov bx, NAME_LENGTH
    call CopyData
    
    mov esi, wPartyMonNicks
    mov al, [ebp + wPartyCount]
    dec al
    call SkipFixedLengthTextEntries
    mov edx, esi
    
    mov esi, wEnemyMonNicks
    mov al, [ebp + wWhichPokemon]
    call SkipFixedLengthTextEntries
    mov bx, NAME_LENGTH
    call CopyData
    
    mov al, [ebp + wCurPartySpecies]    ; ld a, [wCurPartySpecies]
    mov [ebp + wPokedexNum], al         ; ld [wPokedexNum], a
    push edx                            ; push de
    call IndexToPokedex                 ; predef IndexToPokedex
    pop edx                             ; pop de
    movzx eax, byte [ebp + wPokedexNum] ; ld a, [wPokedexNum]
    dec eax                             ; dex bit index (0-based)
    mov cl, al
    mov bh, FLAG_SET                    ; pret `ld b, FLAG_SET` (B=BH); FlagAction reads action in BH
    mov esi, wPokedexOwned
    push cx
    push bx
    call FlagAction
    pop bx
    pop cx
    mov esi, wPokedexSeen
    call FlagAction
    
    clc
    ret

.partyFull:
    stc
    ret

_MoveMon:
    mov al, [ebp + wMoveMonType]
    test al, al ; BOX_TO_PARTY
    jz .checkPartyMonSlots
    cmp al, DAYCARE_TO_PARTY
    jz .checkPartyMonSlots
    cmp al, PARTY_TO_DAYCARE
    mov esi, wDayCareMon
    jz .findMonDataSrc
    
    ; PARTY_TO_BOX
    mov esi, wBoxCount
    mov al, [ebp + esi]
    cmp al, MONS_PER_BOX
    jnz .partyOrBoxNotFull
    jmp .boxFull
    
.checkPartyMonSlots:
    mov esi, wPartyCount
    mov al, [ebp + esi]
    cmp al, PARTY_LENGTH
    jnz .partyOrBoxNotFull

.boxFull:
    stc
    ret

.partyOrBoxNotFull:
    inc al
    mov [ebp + esi], al
    mov cl, al
    movzx ecx, cl
    mov edx, esi
    add edx, ecx
    
    mov al, [ebp + wMoveMonType]
    cmp al, DAYCARE_TO_PARTY
    mov al, [ebp + wDayCareMon]
    jz .copySpecies
    mov al, [ebp + wCurPartySpecies]
.copySpecies:
    mov [ebp + edx], al
    inc edx
    mov byte [ebp + edx], 0xff
    
    mov al, [ebp + wMoveMonType]
    dec al
    mov esi, wPartyMons
    mov bx, PARTYMON_STRUCT_LENGTH
    mov al, [ebp + wPartyCount]
    jnz .addMonOffset
    
    mov esi, wBoxMons
    mov bx, BOXMON_STRUCT_LENGTH
    mov al, [ebp + wBoxCount]
.addMonOffset:
    dec al
    call AddNTimes
    
.findMonDataSrc:
    push esi
    mov edx, esi
    mov al, [ebp + wMoveMonType]
    test al, al
    mov esi, wBoxMons
    mov bx, BOXMON_STRUCT_LENGTH
    jz .addMonOffset2
    
    cmp al, DAYCARE_TO_PARTY
    mov esi, wDayCareMon
    jz .copyMonData
    
    mov esi, wPartyMons
    mov bx, PARTYMON_STRUCT_LENGTH
.addMonOffset2:
    mov al, [ebp + wWhichPokemon]
    call AddNTimes
    
.copyMonData:
    push esi
    push dx
    mov bx, BOXMON_STRUCT_LENGTH
    call CopyData
    pop dx
    pop esi
    
    mov al, [ebp + wMoveMonType]
    test al, al
    jz .findOTdest
    cmp al, DAYCARE_TO_PARTY
    jz .findOTdest
    
    mov eax, BOXMON_STRUCT_LENGTH        ; ld bc,BOXMON_STRUCT_LENGTH (const)
    add esi, eax
    mov al, [ebp + esi] ; Level
    
    add edx, 3
    mov [ebp + edx], al
    
.findOTdest:
    mov al, [ebp + wMoveMonType]
    cmp al, PARTY_TO_DAYCARE
    mov edx, wDayCareMonOT
    jz .findOTsrc
    
    dec al
    mov esi, wPartyMonOT
    mov al, [ebp + wPartyCount]
    jnz .addOToffset
    mov esi, wBoxMonOT
    mov al, [ebp + wBoxCount]
.addOToffset:
    dec al
    call SkipFixedLengthTextEntries
    mov edx, esi

.findOTsrc:
    mov esi, wBoxMonOT
    mov al, [ebp + wMoveMonType]
    test al, al
    jz .addOToffset2
    
    mov esi, wDayCareMonOT
    cmp al, DAYCARE_TO_PARTY
    jz .copyOT
    mov esi, wPartyMonOT
.addOToffset2:
    mov al, [ebp + wWhichPokemon]
    call SkipFixedLengthTextEntries
.copyOT:
    mov bx, NAME_LENGTH
    call CopyData
    
    mov al, [ebp + wMoveMonType]
    cmp al, PARTY_TO_DAYCARE
    mov edx, wDayCareMonName
    jz .findNickSrc
    
    dec al
    mov esi, wPartyMonNicks
    mov al, [ebp + wPartyCount]
    jnz .addNickOffset
    
    mov esi, wBoxMonNicks
    mov al, [ebp + wBoxCount]
.addNickOffset:
    dec al
    call SkipFixedLengthTextEntries
    mov edx, esi
    
.findNickSrc:
    mov esi, wBoxMonNicks
    mov al, [ebp + wMoveMonType]
    test al, al
    jz .addNickOffset2
    
    mov esi, wDayCareMonName
    cmp al, DAYCARE_TO_PARTY
    jz .copyNick
    mov esi, wPartyMonNicks
.addNickOffset2:
    mov al, [ebp + wWhichPokemon]
    call SkipFixedLengthTextEntries
.copyNick:
    mov bx, NAME_LENGTH
    call CopyData
    
    pop esi ; was saved at start of findMonDataSrc
    mov al, [ebp + wMoveMonType]
    cmp al, PARTY_TO_BOX
    jz .done
    cmp al, PARTY_TO_DAYCARE
    jz .done
    
    push esi
    shr al, 1
    add al, 2
    mov [ebp + wMonDataLocation], al
    call LoadMonData
    ; BUG{class=data-model; pret=engine/pokemon/add_mon.asm:_MoveMon; behavior=withdrawing a low-level Medium-Slow mon can inherit CalcExperience underflow as level 100 and softlock; evidence=pret BOX_TO_PARTY CalcLevelFromExperience call plus docs/bug_categorization.md Experience PC Withdrawing Softlock entry; lifetime=permanent Gen-1 behavior unless the experience underflow is fixed}
    ; "Experience PC Withdrawing Softlock" — this is the reachable
    ; call site for that catalogue entry: withdrawing a level-1 Medium-Slow mon
    ; from the PC (BillsPCWithdrawLogic -> _MoveMon, BOX_TO_PARTY) reaches
    ; CalcLevelFromExperience here, which can hit the 24-bit underflow in
    ; CalcExperience's linear/const-term subtraction (see the GLITCH tag there)
    ; and report Lv 100 for a mon that should be Lv 1-2 — in the withdraw context
    ; (rather than a battle EXP-gain context) this is documented to softlock
    ; rather than just mis-level. Gen-1 behavior, preserved verbatim. pret ref:
    ; engine/pokemon/add_mon.asm:_MoveMon (BOX_TO_PARTY/DAYCARE_TO_PARTY path),
    ; engine/pokemon/experience.asm:CalcExperience,
    ; docs/references/yellow_glitches.md#save--sram (Experience PC Withdrawing
    ; Softlock).
    call CalcLevelFromExperience
    mov al, dh
    mov [ebp + wCurEnemyLevel], al
    pop esi
    
    mov ecx, BOXMON_STRUCT_LENGTH        ; ld bc,BOXMON_STRUCT_LENGTH (const)
    add esi, ecx
    mov [ebp + esi], al
    inc esi
    
    mov edx, esi
    
    mov ecx, (MON_HP_EXP - 1) - MON_STATS ; ld bc,-0x12 (sign-ext = 16-bit add hl,bc)
    add esi, ecx
    mov bl, 1
    call CalcStats
    
.done:
    clc
    ret
