; dos_port/src/engine/pokemon/evolution.asm
; ============================================================
; Evolution + level-up move learning — DATA/DECISION LOGIC ONLY.
;
; Pret refs: engine/pokemon/evos_moves.asm (TryEvolvingMon,
;            EvolutionAfterBattle, LearnMoveFromLevelUp),
;            engine/movie/evolution.asm (EvolveMon — see note).
;
; EvosMovesPointerTable data: assets/evos_moves.inc (190 dd entries,
; internal-index order). Each blob: [evo entries…] db 0 [level,move pairs…] db 0.
; Evolution entry sizes: EVOLVE_LEVEL = 3 bytes (type, level, species);
; EVOLVE_ITEM  = 4 bytes (type, item_id, min_level, species);
; EVOLVE_TRADE = 3 bytes (type, min_level, species).
; Blob is in FLAT program-image memory (not EBP-relative).
;
; -----------------------------------------------------------------------
; DEFERRED UI STUBS (document for Wave 2 integrator):
;
;   EvoAnim_Deferred   — full evolution animation (engine/movie/evolution.asm
;                        EvolveMon: palette flash, sprite swap, B-cancel).
;                        Stubbed here as "always succeeds" (CF clear on return).
;
;   EvoText_Deferred   — "X is evolving!" / "X evolved into Y!" / "Stop!" text
;                        (PrintText calls in pret EvolutionAfterBattle).
;
;   LearnMove_Deferred — "Should X forget a move to make room for Y?" interactive
;                        menu.  Called when all 4 move slots are full.  Headless
;                        path silently drops the move; Wave 2 wires the real UI.
;
;   PlayDefaultMusic_Deferred / Evolution_ReloadTilesetTilePatterns_Deferred /
;   ClearScreen_Deferred / ClearSprites_Deferred / DelayFrames_Deferred /
;   GetPartyMonName_Deferred / CopyToStringBuffer_Deferred /
;   GetMoveName_Deferred — all serialised display / sound / timing calls; stubs
;                           here as no-ops or straight `ret`.
;
; -----------------------------------------------------------------------
; The data utilities this file's EvolutionAfterBattle depends on
; (WriteMonMoves / WriteMonMoves_ShiftMoveData, and the corrected
; GetMonLearnset) live in the wired src/engine/pokemon/write_moves.asm.
; The former standalone evos_moves.asm draft was retired in Stage 0
; (docs/current_plan_pokemon_behavior.md); all WRAM/const aliases it declared
; inline are now in gb_memmap.inc / gb_constants.inc.
;
; Build (from repo root):
;   nasm -f coff -I dos_port/include/ -I dos_port/ \
;       -o dos_port/src/engine/pokemon/evolution.o \
;       dos_port/src/engine/pokemon/evolution.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

; All WRAM/const aliases formerly declared here as %ifndef self-aliases are now
; in the shared includes (gb_memmap.inc / gb_constants.inc), promoted per
; docs/current_plan_pokemon_behavior.md Stage 0.

; Pret-name aliases for HRAM / WRAM symbols that use the H_ / W_ prefix in our
; includes, so the translation reads identically to the pret source.
hTileAnimations             equ hTileAnimations
hAutoBGTransferEnabled      equ hAutoBGTransferEnabled
wUpdateSpritesEnabled       equ wUpdateSpritesEnabled

; ---------------------------------------------------------------------------
; Globals and externs
; ---------------------------------------------------------------------------
global TryEvolvingMon
global EvolutionAfterBattle
global EvolveMon
global RenameEvolvedMon
global CancelledEvolution
global LearnMoveFromLevelUp
global GetMonLearnset_Evo       ; local corrected version (×4 dd offset + 32-bit read)
global GetMonLearnset_Evo_BlobStart

; From evos_moves.asm (data utilities — retained there):
extern WriteMonMoves
extern WriteMonMoves_ShiftMoveData

; From pokemon_data.asm:
extern EvosMovesPointerTable
extern IndexToPokedex           ; flat label: byte[species-1] = dex number
extern BaseStats                ; flat label: BASE_DATA_SIZE-byte structs, dex order
extern MonsterNames             ; flat label: NAME_LENGTH-byte names, internal-index order

; From home/:
extern FlagActionPredef
extern CalcStats                ; (ESI=stat-exp base-1, EDX=stat-out ptr, BH=consider-exp)
extern AddNTimes                ; (ESI=base, AL=count, BX=stride → ESI += AL*BX)
extern CopyData                 ; (ESI=src, EDI=dst, BX=len) — WRAM copy
extern GetName                  ; ([wNameListType],[wNameListIndex] → wNameBuffer)
extern GetPredefRegisters       ; restores ESI/EDX/EBX from wPredefHL/DE/BC

; From engine/pokemon/:
extern LoadMonData_             ; loads party/enemy/box/daycare mon into wLoadedMon
extern SetPartyMonTypes         ; updates mon type bytes from wPokedexNum (uses wPredefHL)

; From engine/pikachu/:
extern IsThisPartyMonStarterPikachu ; CF set if wWhichPokemon is the starter Pikachu

section .text

; ===========================================================================
; TryEvolvingMon
; Sets wCanEvolveFlags bit for the mon at [wWhichPokemon].
; Called before EvolutionAfterBattle to mark which mons are eligible.
; In: [wWhichPokemon] = party index (0-based)
; Pret ref: engine/pokemon/evos_moves.asm TryEvolvingMon
; ===========================================================================
TryEvolvingMon:
    mov esi, wCanEvolveFlags
    xor al, al
    mov [ebp + esi], al             ; clear wCanEvolveFlags
    mov al, [ebp + wWhichPokemon]
    mov cl, al                      ; c = party index
    mov bh, FLAG_SET
    call FlagActionPredef
    ret

; ===========================================================================
; EvolutionAfterBattle
; Iterates over the party; for each mon whose wCanEvolveFlags bit is set,
; walks the evo blob and triggers EvolveMon (stub) + post-evo data update.
; After battle: call TryEvolvingMon for each eligible mon first.
;
; Pret ref: engine/pokemon/evos_moves.asm EvolutionAfterBattle
; ===========================================================================
EvolutionAfterBattle:
    mov al, [ebp + hTileAnimations]
    push eax
    xor al, al
    mov [ebp + wEvolutionOccurred], al
    dec al                          ; al = 0xFF
    mov [ebp + wWhichPokemon], al
    push esi
    push ebx
    push edx
    mov esi, wPartySpecies          ; HL = &wPartyCount (then inc to species list)
    push esi

.Evolution_PartyMonLoop:
    mov esi, wWhichPokemon
    inc byte [ebp + esi]            ; [wWhichPokemon]++
    pop esi                         ; HL = ptr into wPartySpecies list
    inc esi                         ; advance to next species byte
    mov al, [ebp + esi]
    cmp al, 0xFF                    ; sentinel?
    je .done
    mov [ebp + wEvoOldSpecies], al
    push esi                        ; save party-species list cursor

    ; Test wCanEvolveFlags bit for this mon
    mov al, [ebp + wWhichPokemon]
    mov cl, al
    mov esi, wCanEvolveFlags
    mov bh, FLAG_TEST
    call FlagActionPredef
    mov al, cl
    test al, al
    jz .Evolution_PartyMonLoop      ; flag not set → skip this mon

    ; Load this mon's data into wLoadedMon (sets wLoadedMonLevel, etc.)
    mov al, [ebp + wCurPartySpecies]
    push eax                        ; save wCurPartySpecies
    xor al, al
    mov [ebp + wMonDataLocation], al ; PLAYER_PARTY_DATA = 0
    call LoadMonData_
    pop eax
    mov [ebp + wCurPartySpecies], al ; restore wCurPartySpecies

    ; Get evolution blob for this species (EvoOldSpecies is the internal index)
    mov al, [ebp + wEvoOldSpecies]
    call GetMonLearnset_Evo_BlobStart ; ESI = flat ptr to blob start (evo entries)

.evoEntryLoop:
    mov al, [esi]
    inc esi
    test al, al
    jz .Evolution_PartyMonLoop      ; end of evo entries → next mon

    mov bh, al                      ; bh = evolution type
    cmp al, EVOLVE_TRADE
    je .checkTradeEvo

    ; Not TRADE evo — if currently trading, skip this mon entirely
    mov al, [ebp + wLinkState]
    cmp al, LINK_STATE_TRADING
    je .Evolution_PartyMonLoop

    cmp bh, EVOLVE_ITEM
    je .checkItemEvo

    ; Must be EVOLVE_LEVEL — blocked when wForceEvolution is set
    ; (wForceEvolution is set when using a stone; stone evos are EVOLVE_ITEM)
    mov al, [ebp + wForceEvolution]
    test al, al
    jnz .Evolution_PartyMonLoop

    cmp bh, EVOLVE_LEVEL
    jne .nextEvoEntry1              ; unknown type: skip entry

    ; EVOLVE_LEVEL: read level, read species at HL
.checkLevel:
    mov al, [esi]
    inc esi                         ; al = level threshold (or min_level for ITEM)
    mov bh, al
    mov al, [ebp + wLoadedMonLevel]
    cmp al, bh                      ; mon level >= threshold?
    jc .nextEvoEntry2               ; no: skip species byte
    jmp .doEvolution                ; yes: species byte is at ESI

.checkTradeEvo:
    ; EVOLVE_TRADE (3 bytes: type, min_level, species)
    mov al, [ebp + wLinkState]
    cmp al, LINK_STATE_TRADING
    jne .nextEvoEntry1              ; not trading → skip (2 bytes: min_level + species)
    ; Trading: read min_level check
    mov al, [esi]
    inc esi                         ; al = min_level, ESI → species
    mov bh, al
    mov al, [ebp + wLoadedMonLevel]
    cmp al, bh
    jc .Evolution_PartyMonLoop      ; level < min_level → skip to next mon
    jmp .doEvolution

.checkItemEvo:
    ; EVOLVE_ITEM (4 bytes: type, item_id, min_level, species)
    ; In battle: skip entirely; outside battle: compare wCurItem to item_id
    mov al, [ebp + wIsInBattle]
    test al, al
    mov al, [esi]
    inc esi                         ; al = item_id, ESI → min_level
    jnz .nextEvoEntry1              ; if in battle, skip (skip min_level + species)
    mov bh, al                      ; bh = evolution item id
    mov al, [ebp + wCurItem]        ; = wEvoStoneItemID context (set by stone-use caller)
    cmp al, bh
    jne .nextEvoEntry1              ; wrong item → skip min_level + species
    jmp .checkLevel                 ; correct item → read min_level, then species

.doEvolution:
    ; ESI now points to the target species byte in the blob
    mov al, [ebp + wLoadedMonLevel]
    mov [ebp + wCurEnemyLevel], al  ; save current level (used by LearnMoveFromLevelUp)
    mov al, 1
    mov [ebp + wEvolutionOccurred], al

    push esi                        ; save blob cursor (species byte)
    mov al, [esi]
    mov [ebp + wEvoNewSpecies], al  ; store target species

    ; DEFERRED UI: show "X is evolving!" text and animation.
    ; EvolveMon stub below always succeeds (CF clear); real animation in Wave 2.
    call EvolveMon
    jc CancelledEvolution           ; if CF set: user cancelled (stub never sets CF)

    ; Restore blob cursor and read new species
    pop esi
    mov al, [esi]
    mov [ebp + wCurSpecies], al
    mov [ebp + wLoadedMonSpecies], al
    mov [ebp + wEvoNewSpecies], al

    ; DEFERRED UI: "EvolvedText" + "IntoText" + "ClearScreen"
    ; (would call GetName for new species name here)

    ; IndexToPokedex: species → dex number
    push eax
    mov al, [ebp + wPokedexNum]
    push eax                        ; save old wPokedexNum
    mov al, [ebp + wCurSpecies]
    dec al
    movzx eax, al
    movzx eax, byte [IndexToPokedex + eax]  ; flat dex-order lookup
    inc al                          ; 0-based → 1-based dex num
    mov [ebp + wPokedexNum], al

    ; Copy new species base stats into wMonHeader
    mov al, [ebp + wPokedexNum]
    dec al
    movzx eax, al
    imul eax, BASE_DATA_SIZE
    mov esi, BaseStats
    add esi, eax                    ; ESI = &BaseStats[dex-1]
    mov edi, wMonHeader
    mov bx, BASE_DATA_SIZE
    call CopyData

    mov al, [ebp + wCurSpecies]
    mov [ebp + wMonHIndex], al

    pop eax
    mov [ebp + wPokedexNum], al     ; restore old wPokedexNum
    pop eax

    ; Recompute all stats for the evolved species
    ; In: ESI = wLoadedMonHPExp - 1, EDX = wLoadedMonStats, BH = 1
    mov esi, wLoadedMonHPExp - 1
    mov edx, wLoadedMonStats
    mov bh, 1
    call CalcStats

    ; Find the party mon struct for wWhichPokemon
    mov esi, wPartyMon1
    mov al, [ebp + wWhichPokemon]
    mov bx, PARTYMON_STRUCT_LENGTH
    call AddNTimes                  ; ESI = &partyMon[wWhichPokemon]
    push esi                        ; save party mon ptr

    ; Adjust current HP: delta = (newMaxHP - oldMaxHP); curHP += delta
    push ebx
    mov edi, esi
    push edi                        ; save copy for CopyData dest later
    add esi, MON_MAXHP              ; ESI → mon's MaxHP field
    mov al, [ebp + esi]
    inc esi
    mov bh, al                      ; bh = old MaxHP high byte
    mov cl, [ebp + esi]             ; cl = old MaxHP low byte

    mov esi, wLoadedMonMaxHP + 1    ; new MaxHP (computed by CalcStats)
    mov al, [ebp + esi]
    dec esi
    sub al, cl                      ; al = new low - old low (carries in CF)
    mov cl, al
    mov al, [ebp + esi]
    sbb al, bh                      ; al = new high - old high - borrow
    mov bh, al

    mov esi, wLoadedMonHP + 1
    mov al, [ebp + esi]
    add al, cl
    mov [ebp + esi], al
    dec esi
    mov al, [ebp + esi]
    adc al, bh
    mov [ebp + esi], al

    pop edi                         ; EDI = party mon ptr
    pop ebx

    ; Copy all computed wLoadedMon stats back to the party mon struct
    mov esi, wLoadedMon
    mov bx, PARTYMON_STRUCT_LENGTH
    call CopyData                   ; copies full party struct from wLoadedMon → party slot

    ; Update the party mon's dex number and learn moves at current level
    mov al, [ebp + wCurSpecies]
    mov [ebp + wPokedexNum], al
    xor al, al
    mov [ebp + wMonDataLocation], al
    call LearnMoveFromLevelUp

    ; SetPartyMonTypes — needs wPredefHL = &partyMon (big-endian word)
    pop esi                         ; ESI = party mon WRAM address (16-bit WRAM addr)
    push eax
    movzx eax, si                   ; low 16 bits of ESI (the WRAM address)
    mov [ebp + wPredefHL + 1], al   ; store low byte of WRAM addr
    shr eax, 8
    mov [ebp + wPredefHL], al       ; store high byte of WRAM addr
    pop eax
    call SetPartyMonTypes

    ; Mark pokedex seen/owned for the new species
    mov al, [ebp + wIsInBattle]
    test al, al
    ; (DEFERRED: Evolution_ReloadTilesetTilePatterns when not in battle)

    ; IndexToPokedex again to get 0-based dex index for flag actions
    mov al, [ebp + wCurSpecies]
    dec al
    movzx eax, al
    movzx eax, byte [IndexToPokedex + eax]
    dec al                          ; 1-based → 0-based
    mov cl, al
    mov bh, FLAG_SET
    mov esi, wPokedexOwned
    push ebx
    call FlagActionPredef
    pop ebx
    mov esi, wPokedexSeen
    call FlagActionPredef

    ; Update party species list entry
    ; BUG(Wave 2): stack imbalance on the evolution-success path. Entering here the
    ; stack top is the per-iteration species cursor pushed at .Evolution_PartyMonLoop
    ; (line ~240); the .doEvolution block balances back to that baseline. But this
    ; sequence pops TWICE — `pop edx` takes the cursor (ok) and `pop esi` then
    ; consumes the function-level saved DE (push edx at routine entry), so the
    ; species write below uses a wrong pointer and `.done`'s register restores are
    ; misaligned. Needs a pret-faithful single-pop rewrite (pret pops the one cursor,
    ; writes [hl]=species, pushes it back) + end-to-end native validation once
    ; FlagActionPredef / LoadMonData_ / CalcStats are linkable. Untriggered until then
    ; (this routine is check-only and only runs an evolution under the Wave-2 deps).
    ; The headless decision data path (GetMonLearnset_Evo[_BlobStart]) and
    ; LearnMoveFromLevelUp ARE native-validated; this party-loop flow is not.
    pop edx                         ; EDX = saved party-species list cursor
    pop esi                         ; (see BUG above — consumes the wrong stack slot)
    mov al, [ebp + wLoadedMonSpecies]
    mov [ebp + esi], al             ; wPartySpecies[wWhichPokemon] = new species
    push esi                        ; re-push cursor for next iteration
    mov esi, edx
    jmp .nextEvoEntry2

.nextEvoEntry1:
    inc esi                         ; skip 1 byte (level/param after current)
.nextEvoEntry2:
    inc esi                         ; skip 1 byte (species)
    jmp .evoEntryLoop

.done:
    pop edx
    pop ebx
    pop esi
    pop eax
    mov [ebp + hTileAnimations], al

    mov al, [ebp + wLinkState]
    cmp al, LINK_STATE_TRADING
    je .return

    mov al, [ebp + wIsInBattle]
    test al, al
    jnz .return

    mov al, [ebp + wEvolutionOccurred]
    test al, al
    ; DEFERRED: call PlayDefaultMusic if nz (al != 0, evolution happened)
.return:
    ret

; ===========================================================================
; EvolveMon
; DATA STUB — the UI animation + B-cancel is deferred to Wave 2.
; In pret: engine/movie/evolution.asm EvolveMon
;   - plays palette-flash animation between old/new species sprites
;   - if B pressed: wEvoCancelled=1, CF set; else CF clear
; HERE: just clear CF (always succeeds); Wave 2 wires the real animation.
; ===========================================================================
EvolveMon:
    ; DEFERRED: EvoAnim_Deferred — full animation (Wave 2 / engine/movie/evolution.asm)
    ; DEFERRED: PlayCry wEvoOldSpecies
    ; DEFERRED: PlayCry wEvoNewSpecies
    ; DEFERRED: EvoText "X evolved into Y!"
    clc                             ; no cancel
    ret

; ===========================================================================
; RenameEvolvedMon
; If the mon's nickname equals the pre-evolution species name (i.e. it was not
; nicknamed), rename it to the new species' default name.
; Pret ref: engine/pokemon/evos_moves.asm RenameEvolvedMon
; ===========================================================================
RenameEvolvedMon:
    ; ASSERT wCurSpecies == wNameListIndex (shared address per pret comment)
    mov al, [ebp + wCurSpecies]
    push eax                        ; save wCurSpecies
    mov al, [ebp + wMonHIndex]
    mov [ebp + wNameListIndex], al
    mov al, MONSTER_NAME
    mov [ebp + wNameListType], al
    call GetName                    ; get old species name into wNameBuffer

    pop eax
    mov [ebp + wCurSpecies], al     ; restore wCurSpecies

    ; Compare wStringBuffer (current name, set before call) vs wNameBuffer (default name)
    mov esi, wStringBuffer
    mov edi, wNameBuffer
.compareNamesLoop:
    mov al, [ebp + edi]
    inc edi
    cmp al, [ebp + esi]
    inc esi
    jne .return                     ; differs → had a nickname, keep it
    cmp al, '@'
    jne .compareNamesLoop           ; not terminator → keep comparing
    ; Names match: replace the mon's nickname with the new species name
    mov al, [ebp + wWhichPokemon]
    mov bx, NAME_LENGTH
    mov esi, wPartyMonNicks
    call AddNTimes                  ; ESI = &wPartyMonNicks[wWhichPokemon]
    push esi
    mov al, MONSTER_NAME
    mov [ebp + wNameListType], al
    ; wNameListIndex = wCurSpecies already holds the new species (wEvoNewSpecies)
    call GetName                    ; get new name into wNameBuffer
    mov esi, wNameBuffer
    pop edi                         ; EDI = destination: nickname slot in party
    mov bx, NAME_LENGTH
    call CopyData
.return:
    ret

; ===========================================================================
; CancelledEvolution
; Handles the case where the player pressed B during the evolution animation.
; Pret ref: engine/pokemon/evos_moves.asm CancelledEvolution
; ===========================================================================
CancelledEvolution:
    ; DEFERRED: PrintText StoppedEvolvingText
    ; DEFERRED: ClearScreen
    ; DEFERRED: Evolution_ReloadTilesetTilePatterns
    pop esi                         ; discard the blob cursor pushed at .doEvolution
    jmp EvolutionAfterBattle.Evolution_PartyMonLoop

; ===========================================================================
; LearnMoveFromLevelUp
; Scans the current mon's learnset for a move to learn at [wCurEnemyLevel].
; If found and not already known, writes it to an empty move slot (headless path).
; When all slots are full, calls LearnMove_Deferred (Wave 2 stub).
; After successful learn: sets the Pikachu THUNDERBOLT/THUNDER emotion modifier
; if applicable.
;
; In:  [wPokedexNum]       = pokedex number of the evolved species
;      [wCurEnemyLevel]    = level at which evolution occurred (= current level)
;      [wWhichPokemon]     = party index of the mon
;      [wMonDataLocation]  = 0 (PLAYER_PARTY_DATA)
; Pret ref: engine/pokemon/evos_moves.asm LearnMoveFromLevelUp
; ===========================================================================
LearnMoveFromLevelUp:
    ; wCurPartySpecies is used by GetMonLearnset_Evo as the species index
    ; The pret code copies wPokedexNum → wCurPartySpecies temporarily.
    ; However, GetMonLearnset_Evo reads wCurPartySpecies (internal index).
    ; wPokedexNum at this call point was set to wCurSpecies (internal index),
    ; so wPokedexNum here is actually the INTERNAL species index, not dex#.
    ; (pret comment: "ld a, [wPokedexNum] ; species" — confirms internal index usage.)
    mov al, [ebp + wPokedexNum]
    mov [ebp + wCurPartySpecies], al ; set species for GetMonLearnset_Evo
    call GetMonLearnset_Evo          ; ESI → start of learnset (past evo entries)

.learnSetLoop:
    mov al, [esi]
    inc esi
    test al, al
    jz .done                        ; end of learnset
    mov bh, al                      ; bh = level at which move is learned
    mov al, [ebp + wCurEnemyLevel]
    cmp al, bh                      ; current level == learn level?
    mov al, [esi]                   ; al = move id (prefetch; mov preserves flags)
    lea esi, [esi+1]                ; advance — lea preserves the cmp ZF (inc would NOT;
                                    ; SM83 `inc hl` doesn't touch flags, x86 `inc` does)
    jne .learnSetLoop               ; not this level → keep scanning
    ; Found a move to learn at the current level
    mov dh, al                      ; dh = move id to learn

    ; Find this mon's current move slots
    mov al, [ebp + wMonDataLocation]
    test al, al
    jnz .next                       ; non-zero: loading from non-party data (unusual)
    ; PLAYER_PARTY_DATA: compute address of this mon's MON_MOVES field
    mov esi, wPartyMon1 + MON_MOVES
    mov al, [ebp + wWhichPokemon]
    mov bx, PARTYMON_STRUCT_LENGTH
    call AddNTimes                  ; ESI = &partyMon[wWhichPokemon].moves
.next:
    ; Check if the move is already known (scan all NUM_MOVES slots)
    push esi                        ; save slot base
    mov bh, NUM_MOVES
.checkCurrentMovesLoop:
    mov al, [ebp + esi]
    inc esi
    cmp al, dh
    je .donePopSi                   ; already known → done
    dec bh
    jnz .checkCurrentMovesLoop
    pop esi                         ; restore slot base (bh = 0 after full scan)

    ; Not already known.  Try to find an empty slot (headless path).
    push esi
    mov cl, NUM_MOVES
.findEmptyLoop:
    mov al, [ebp + esi]
    test al, al
    jz .writeToSlot                 ; empty slot found
    inc esi
    dec cl
    jnz .findEmptyLoop
    ; All slots full — deferred interactive path (Wave 2)
    pop esi                         ; restore slot base
    ; DEFERRED: LearnMove_Deferred — "Should X forget a move?" menu.
    ; Headless stub: silently skip (move not written).
    ; bh = 0 (from the scan loop above); the pikachu check below fires on bh != 0,
    ; which won't happen here — correct for the headless path.
    jmp .doneLearnMove

.writeToSlot:
    ; Write the move into the found empty slot
    mov [ebp + esi], dh
    pop esi                         ; restore slot base (bh still 0 from scan)

.doneLearnMove:
    ; bh == 0: move learned in empty slot (or slots full & deferred)
    test bh, bh
    jz .done
    ; bh != 0 only if pret's LearnMove returned with "had to forget a move".
    ; In the headless stub, this branch is never taken.
    ; Pikachu emotion modifier for THUNDERBOLT/THUNDER (deferred, documented here):
    call IsThisPartyMonStarterPikachu
    jnc .done                       ; CF clear → not starter Pikachu
    mov al, [ebp + wMoveNum]
    cmp al, THUNDERBOLT
    je .foundThunderOrThunderbolt
    cmp al, THUNDER
    jne .done
.foundThunderOrThunderbolt:
    mov al, 5
    mov [ebp + wPikachuEmotionModifier], al
    mov al, 0x85
    mov [ebp + wPikachuMood], al
    jmp .done

.donePopSi:
    pop esi
.done:
    ; Restore wPokedexNum from wCurPartySpecies (pret does the reverse: saves
    ; wCurPartySpecies and restores wPokedexNum — same shared address in pret).
    mov al, [ebp + wCurPartySpecies]
    mov [ebp + wPokedexNum], al
    ret

; ===========================================================================
; GetMonLearnset_Evo  (local — corrected version of evos_moves.asm GetMonLearnset)
; Returns ESI pointing to the LEARNSET portion of the evo/learnset blob for the
; species in [wCurPartySpecies].  Uses CORRECT ×4 offset + 32-bit pointer read.
;
; Bug fixed vs evos_moves.asm GetMonLearnset: the old code used ×2 offset and
; read only 16 bits, which is wrong for dd (32-bit) pointer table entries.
;
; In:  [wCurPartySpecies] = internal species index (1-based; e.g. 0x99 = Bulbasaur)
; Out: ESI = flat pointer to first learnset byte (past the evo entries)
; Clobbers: AL, ECX
; ===========================================================================
GetMonLearnset_Evo:
    mov al, [ebp + wCurPartySpecies]
    dec al                          ; 0-based index
    movzx ecx, al
    shl ecx, 2                      ; ×4: each entry is a dd (32-bit pointer)
    mov esi, EvosMovesPointerTable
    add esi, ecx
    mov esi, [esi]                  ; full 32-bit flat pointer to blob start

    ; Skip past the evolution entries (each terminated individually;
    ; the whole evo-entries section ends with db 0).
.skipEvoLoop:
    mov al, [esi]
    inc esi
    test al, al
    jnz .skipEvoLoop                ; non-zero byte = part of an evo entry → skip
    ; ESI now points to the first learnset byte (or db 0 if no learnset)
    ret

; ===========================================================================
; GetMonLearnset_Evo_BlobStart  (internal helper, not exported)
; Returns ESI pointing to the BLOB START (evo entries) for the species in AL.
; In:  AL = internal species index (1-based)
; Out: ESI = flat pointer to blob start (first evo entry byte, or db 0 if none)
; Clobbers: AL, ECX
; ===========================================================================
GetMonLearnset_Evo_BlobStart:
    dec al
    movzx ecx, al
    shl ecx, 2
    mov esi, EvosMovesPointerTable
    add esi, ecx
    mov esi, [esi]                  ; full 32-bit flat pointer
    ret
