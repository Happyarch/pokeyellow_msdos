; dos_port/src/engine/pokemon/evos_moves.asm
; ============================================================
; Mirror of pret engine/pokemon/evos_moves.asm.
;
; Holds the pret labels in pret's own order:
;   TryEvolvingMon, EvolutionAfterBattle (with Evolution_PartyMonLoop as a local
;   label, since only this file and CancelledEvolution branch to it),
;   RenameEvolvedMon, CancelledEvolution, LearnMoveFromLevelUp, WriteMonMoves,
;   WriteMonMoves_ShiftMoveData, GetMonLearnset.
;
; pret labels of that file this port does NOT hold, so nobody thinks they were
; lost in the move:
;   EvolvedText / IntoText / StoppedEvolvingText / IsEvolvingText — generated
;     text-command streams, defined in assets/battle_text.inc (translated).
;   Evolution_FlagAction — pret's `predef_jump FlagActionPredef` trampoline; the
;     port has no predef dispatcher and calls FlagAction directly (see the note
;     in TryEvolvingMon).
;   Evolution_ReloadTilesetTilePatterns, Func_3b079, Func_3b0a2, Func_3b10f —
;     not translated.
;
; The two GetMonLearnset_Evo* helpers at the bottom are PORT-ONLY (no pret
; counterpart) and came here with EvolutionAfterBattle, their only caller.
;
; Register map: a=AL, b=BH, c=BL (bc=EBX), d=DH, e=DL (de=EDX), hl=ESI,
; EBP = GB memory base; GB memory = [EBP+addr]. The evo/learnset blobs
; (EvosMovesPointerTable, assets/evos_moves.inc) are FLAT program-image data and
; are read with a bare [esi] — mind which ESI you are looking at.

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
; Pret-name aliases for HRAM / WRAM symbols that use the H_ / W_ prefix in our
; includes, so the translation reads identically to the pret source.
hTileAnimations             equ hTileAnimations
hAutoBGTransferEnabled      equ hAutoBGTransferEnabled
wUpdateSpritesEnabled       equ wUpdateSpritesEnabled

global TryEvolvingMon
global EvolutionAfterBattle
global RenameEvolvedMon
global CancelledEvolution
global LearnMoveFromLevelUp
global WriteMonMoves
global WriteMonMoves_ShiftMoveData
global GetMonLearnset
global GetMonLearnset_Evo       ; local corrected version (×4 dd offset + 32-bit read)
global GetMonLearnset_Evo_BlobStart

; From engine/movie/evolution.asm (the animation half, still in its own file):
extern EvolveMon                ; src/engine/movie/evolution.asm — evo animation, CF = cancelled

; From pokemon_data.asm:
extern EvosMovesPointerTable
extern IndexToPokedex           ; engine/menus/pokedex.asm — predef, wPokedexNum in place
extern BaseStats                ; flat label: BASE_DATA_SIZE-byte structs, dex order
extern Moves

; From home/:
extern FlagAction
extern CalcStats                ; (ESI=stat-exp base-1, EDX=stat-out ptr, BH=consider-exp)
extern AddNTimes                ; (ESI=base, AL=count, BX=stride → ESI += AL*BX)
extern CopyData                 ; (ESI=src, EDI=dst, BX=len) — WRAM copy
extern GetName                  ; ([wNameListType],[wNameListIndex] → wNameBuffer)
extern GetPredefRegisters       ; restores ESI/EDX/EBX from wPredefHL/DE/BC
extern GetMoveName                   ; src/home/names.asm — move name -> wNameBuffer

; From engine/pokemon/:
extern LoadMonData_             ; loads party/enemy/box/daycare mon into wLoadedMon
extern SetPartyMonTypes         ; updates mon type bytes from wPokedexNum (uses wPredefHL)
extern LearnMove                     ; src/engine/pokemon/learn_move.asm — faithful teach flow

; From engine/battle/ and engine/pikachu/:
extern IsThisPartyMonStarterPikachu  ; src/engine/pikachu/pikachu_status.asm (mood bump)
extern lvl_mon_ptr              ; src/engine/battle/battle_menu.asm — PrintStatsBox scratch

; Text/display/input helpers:
extern PrintText                ; battle-scope text engine (ESI = flat text stream)
extern GetPartyMonName          ; (AL=index, ESI=nick list) → wNameBuffer (EDX out)
extern CopyToStringBuffer            ; src/home/copy_string.asm — wNameBuffer -> wStringBuffer
extern ClearScreenArea          ; (ESI=tilemap dst, BH=rows, BL=width)
extern ClearSprites             ; zero shadow OAM
extern ClearScreen              ; home/copy2.asm — blank tilemap + Delay3
extern DelayFrames              ; (BL = frame count)
extern ReloadTilesetTilePatterns ; home/reload_tiles.asm — restore map tileset after evo screen

; Evolution text command streams (generated into assets/battle_text.inc by
; tools/generators/gen_battle_text.py from engine/pokemon/evos_moves.asm wrappers):
extern IsEvolvingText           ; "<MON> is evolving!"
extern EvolvedText              ; "Congratulations! Your <MON> evolved into"
extern IntoText                 ; " <SPECIES>!"
extern StoppedEvolvingText      ; "Huh? <MON> stopped evolving!"
extern msgbox_centered                  ; src/engine/battle/core.asm — centered projection
extern text_msgbox                      ; src/home/text.asm — active msgbox projection (msgbox.inc)

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
    ; pret: `predef FlagActionPredef`. The port has no predef dispatcher, so it
    ; calls FlagAction directly with the registers set — FlagActionPredef's first
    ; act is GetPredefRegisters, which would OVERWRITE ESI/EBX from the (stale)
    ; wPredefHL/BC slots. Same convention as experience.asm's four call sites.
    call FlagAction
    ; NO `ret` HERE — pret's TryEvolvingMon FALLS THROUGH into EvolutionAfterBattle
    ; (engine/pokemon/evos_moves.asm: the two labels are contiguous). It sets the
    ; mon's wCanEvolveFlags bit and then runs the evolution loop for it. A `ret`
    ; here made every caller (Rare Candy's level-up evo, ItemUseEvoStone) merely
    ; mark the mon and evolve nothing.

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
    ; pret: `ld hl, wPartyCount` — the loop's first act is `inc hl`, which lands on
    ; species[0]. Starting at wPartySpecies (= species[0]) instead made that inc land
    ; on species[1], so every mon was tested against the NEXT mon's evolution data.
    mov esi, wPartyCount            ; HL = &wPartyCount (the loop incs to the species list)
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
    call FlagAction                 ; pret: predef FlagActionPredef — see TryEvolvingMon
    mov al, cl
    test al, al
    jz .Evolution_PartyMonLoop      ; flag not set → skip this mon

    ; Get evolution blob for this species (EvoOldSpecies is the internal index).
    ; pret resolves the blob pointer HERE — BEFORE LoadMonData — and pushes it
    ; across the call. Order matters: wEvoOldSpecies ($CEE9) is a union'd scratch
    ; slot (wHPBarMaxHP), and LoadMonData_ walks it, so reading it after the call
    ; yields garbage and the blob walk rejects every mon.
    mov al, [ebp + wEvoOldSpecies]
    call GetMonLearnset_Evo_BlobStart ; ESI = flat ptr to blob start (evo entries)
    push esi                        ; [E] blob cursor, saved across LoadMonData_

    ; Load this mon's data into wLoadedMon (sets wLoadedMonLevel, etc.)
    mov al, [ebp + wCurPartySpecies]
    push eax                        ; save wCurPartySpecies
    xor al, al
    mov [ebp + wMonDataLocation], al ; PLAYER_PARTY_DATA = 0
    call LoadMonData_
    pop eax
    mov [ebp + wCurPartySpecies], al ; restore wCurPartySpecies
    pop esi                         ; [E] blob cursor

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
    test al, al                     ; ZF is live all the way to the `jnz` below —
    mov al, [esi]                   ; pret's `ld a, [hli]` sits in the same gap and
    lea esi, [esi + 1]              ; leaves flags alone. `inc esi` would CLOBBER ZF
                                    ; (ESI != 0 → jnz always taken → every item evo
                                    ; skipped), so the pointer step must be `lea`.
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

    push esi                        ; [B] save blob cursor (species byte)
    mov al, [esi]
    mov [ebp + wEvoNewSpecies], al  ; store target species

    ; "<MON> is evolving!" — build the pre-evolution nickname into wStringBuffer
    ; (RenameEvolvedMon compares against it later), then show the intro text.
    mov al, [ebp + wWhichPokemon]
    mov esi, wPartyMonNicks
    call GetPartyMonName            ; → wNameBuffer; EDX = wNameBuffer
    call CopyToStringBuffer         ; EDX → wStringBuffer
    mov esi, IsEvolvingText
    mov dword [text_msgbox], msgbox_centered   ; centered box: keep this screen's window list
    call PrintText
    mov bl, 50
    call DelayFrames

    ; Clear the message area + sprites for the animation.
    xor al, al
    mov [ebp + hAutoBGTransferEnabled], al
    mov esi, W_TILEMAP
    mov bh, 12                      ; pret lb bc, 12, 20 (B = rows, C = width)
    mov bl, 20
    call ClearScreenArea
    mov al, 1
    mov [ebp + hAutoBGTransferEnabled], al
    mov al, 0xFF
    mov [ebp + wUpdateSpritesEnabled], al
    call ClearSprites

    ; The evolution animation. Now functional: the B-cancel loop is LIVE; the
    ; cries + palette-flash back-and-forth morph are [2b]/TODO-HW deferred.
    call EvolveMon                  ; pret: callfar EvolveMon
    jc CancelledEvolution           ; B pressed (and not forced) → cancel

    mov esi, EvolvedText
    mov dword [text_msgbox], msgbox_centered   ; centered box: keep this screen's window list
    call PrintText

    ; Restore blob cursor [B]; read the new species.
    pop esi                         ; [B] blob cursor
    mov al, [esi]
    mov [ebp + wCurSpecies], al     ; == wNameListIndex (shared addr) → new species
    mov [ebp + wLoadedMonSpecies], al
    mov [ebp + wEvoNewSpecies], al

    ; Fetch the new species' default name (→ wNameBuffer) for the "into <NAME>!"
    ; line. wNameListIndex aliases wCurSpecies (just set to the new species).
    mov al, MONSTER_NAME
    mov [ebp + wNameListType], al
    ; NOTE: pret sets wPredefBank = BANK(MonsterNames) here; monster names ignore
    ; the ROM bank in the flat model, so it is not needed.
    ; STACK FIX [C]: re-push the blob cursor here. pret pushes hl AFTER GetName
    ; (its GetName preserves hl), but the port's GetName clobbers ESI, so push
    ; before the call — functionally identical. This [C] is consumed by the
    ; `pop edx` on the success path below, so the following `pop esi` correctly
    ; takes the party-species cursor [G] instead of the routine-entry saved DE
    ; (which was the old stack-imbalance bug).
    push esi                        ; [C] blob cursor
    call GetName                    ; new species name → wNameBuffer

    mov esi, IntoText
    call PrintText                  ; TODO-HW: pret uses PrintText_NoCreatingTextBox +
                                    ; PlaySoundWaitForCurrent(SFX_GET_ITEM_2) +
                                    ; WaitForSoundToFinish — audio HAL (Phase 3)
    mov bl, 40
    call DelayFrames
    call ClearScreen
    call RenameEvolvedMon           ; keep the nickname, else adopt the new name

    ; predef IndexToPokedex: species → dex number (1-based; the `inc al` that
    ; once re-based it to dex+1 made a stone evolution read the NEXT species'
    ; BaseStats — NINETALES got JIGGLYPUFF's; caught by item_stone_evolve).
    push eax
    mov al, [ebp + wPokedexNum]
    push eax                        ; ld a, [wPokedexNum] / push af — save it
    mov al, [ebp + wCurSpecies]     ; ld a, [wCurSpecies]
    mov [ebp + wPokedexNum], al     ; ld [wPokedexNum], a
    call IndexToPokedex             ; predef IndexToPokedex

    ; Copy new species base stats into wMonHeader
    ; DEVIATION{class=data-model; pret=engine/pokemon/evos_moves.asm:EvolutionAfterBattle; behavior=copy BaseStats directly from flat data into wMonHeader instead of using GB-offset AddNTimes and CopyData; evidence=pret EvolveMon base-stat copy plus port flat BaseStats address and CopyData EBP-relative contract; lifetime=permanent flat-data boundary}
    ; pret is `ld hl, BaseStats / ld bc, BASE_DATA_SIZE /
    ; call AddNTimes / ld de, wMonHeader / call CopyData` — on the GB, CopyData's
    ; source may be a ROM address. In the port BaseStats is a flat .data table and
    ; CopyData reads its source EBP-relative ([ebp+esi]), so handing it the flat
    ; pointer reads ~4 MB past the GB allocation. Copy flat→GB directly, exactly as
    ; home/pokemon.asm:GetMonHeader does for the same table. Not a VRAM write, so no
    ; g_tilecache_dirty.
    mov al, [ebp + wPokedexNum]
    dec al
    movzx eax, al
    imul eax, BASE_DATA_SIZE
    push edi
    lea esi, [BaseStats + eax]      ; flat (program-image) source
    lea edi, [ebp + wMonHeader]     ; GB-memory destination
    mov ecx, BASE_DATA_SIZE
    rep movsb
    pop edi

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
    mov edx, edi                    ; CopyData dest is EDX (=DE), NOT EDI (the "save copy for
    mov bx, PARTYMON_STRUCT_LENGTH  ; CopyData dest later" push above targeted the wrong reg —
    call CopyData                   ; the 44-byte struct was landing at [ebp+stale DX]).

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

    ; Evolution_ReloadTilesetTilePatterns when not in battle (pret evos_moves.asm:
    ; `and a` / `call z, Evolution_ReloadTilesetTilePatterns`). The helper no-ops
    ; during a link trade, else reloads the map tileset over the evo-screen tiles.
    mov al, [ebp + wIsInBattle]
    test al, al
    jnz .skipTilesetReload           ; in battle: HUD/tiles managed by battle — skip
    mov al, [ebp + wLinkState]
    cmp al, LINK_STATE_TRADING
    je .skipTilesetReload             ; link trade: skip (pret `ret z`)
    call ReloadTilesetTilePatterns    ; pret `jp ReloadTilesetTilePatterns`
.skipTilesetReload:

    ; Mark pokedex seen/owned for the new species

    ; predef IndexToPokedex again to get the 0-based dex index for flag actions
    mov al, [ebp + wCurSpecies]
    mov [ebp + wPokedexNum], al     ; ld [wPokedexNum], a
    call IndexToPokedex             ; predef IndexToPokedex
    mov al, [ebp + wPokedexNum]     ; ld a, [wPokedexNum]
    dec al                          ; 1-based → 0-based
    mov cl, al
    mov bh, FLAG_SET
    mov esi, wPokedexOwned
    push ebx
    call FlagAction                 ; pret: predef FlagActionPredef — see TryEvolvingMon
    pop ebx
    mov esi, wPokedexSeen
    call FlagAction                 ; pret: predef FlagActionPredef — see TryEvolvingMon

    ; Update party species list entry. Stack top here is [C] (the blob cursor
    ; re-pushed in .doEvolution before GetName), then [G] (the per-iteration
    ; party-species cursor pushed at .Evolution_PartyMonLoop). pret's tail is
    ; `pop de` (blob cursor) / `pop hl` (species cursor) / write [hl] / `push hl`
    ; / `ld l,e; ld h,d` — mirrored below. (The pre-[C] version popped the species
    ; cursor into EDX and then wrongly ate the routine-entry saved DE; adding the
    ; [C] push realigns both pops to pret.)
    pop edx                         ; [C] EDX = blob cursor
    pop esi                         ; [G] ESI = party-species list cursor
    mov al, [ebp + wLoadedMonSpecies]
    mov [ebp + esi], al             ; wPartySpecies[wWhichPokemon] = new species
    push esi                        ; [G] re-push cursor for next iteration
    mov esi, edx                    ; ESI = blob cursor (pret: ld l,e / ld h,d)
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
    cmp al, 0x50                    ; charmap '@' = 0x50 terminator (NOT NASM ASCII 0x40)
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
    mov edx, edi                    ; CopyData dest is EDX (=DE), NOT EDI — the new name was
    mov bx, NAME_LENGTH             ; being written to [ebp+stale DX] instead of the nick slot.
    call CopyData
.return:
    ret

; ===========================================================================
; CancelledEvolution
; Handles the case where the player pressed B during the evolution animation.
; Pret ref: engine/pokemon/evos_moves.asm CancelledEvolution
; ===========================================================================
CancelledEvolution:
    mov esi, StoppedEvolvingText    ; "Huh? <MON> stopped evolving!"
    mov dword [text_msgbox], msgbox_centered   ; centered box: keep this screen's window list
    call PrintText
    call ClearScreen
    ; Reached from `jc CancelledEvolution` right after EvolveMon: the [C] blob
    ; re-push has not happened yet, so the stack top is [B] (pushed at
    ; .doEvolution before the intro text). Discard it, matching pret's `pop hl`.
    pop esi                         ; [B] discard blob cursor
    ; DEFERRED: Evolution_ReloadTilesetTilePatterns (reload_tiles.asm is
    ; HOME_CHECK-only; not linked yet).
    jmp EvolutionAfterBattle.Evolution_PartyMonLoop

; LearnMoveFromLevelUp — faithful pret evos_moves.asm:LearnMoveFromLevelUp. Scans the
; leveled mon's learnset for a move taught at wCurEnemyLevel; if unknown and a free slot
; exists, writes it + base PP and shows "<nick> learned <move>!". All-slots-full "forget
; a move?" menu DEFERRED. Called by GainExperience after the stats box.
LearnMoveFromLevelUp:
    mov al, [ebp + wPokedexNum]
    mov [ebp + wCurPartySpecies], al
    call GetMonLearnset
.scan:
    mov al, [esi]
    inc esi
    test al, al
    jz .restore
    mov dh, al
    mov al, [esi]
    inc esi
    mov dl, al
    cmp dh, [ebp + wCurEnemyLevel]
    jne .scan
    movzx eax, byte [ebp + wWhichPokemon]
    imul eax, eax, PARTYMON_STRUCT_LENGTH
    add eax, wPartyMon1
    mov [lvl_mon_ptr], eax
    lea edi, [eax + MON_MOVES]
    mov cl, NUM_MOVES
.known:
    mov al, [ebp + edi]
    cmp al, dl
    je .restore
    inc edi
    dec cl
    jnz .known
    ; pret LearnMoveFromLevelUp (evos_moves.asm) delegates slot-find/write/PP/
    ; battle-sync/display to `predef LearnMove` — the faithful teach-flow module
    ; (src/engine/pokemon/learn_move.asm). This replaces the old inline free-slot
    ; scan that silently dropped the move (no message at all) when all 4 slots
    ; were already full; LearnMove's DontAbandonLearning now handles that case
    ; too (see its header for the current deferred-UI scope).
    mov [ebp + wMoveNum], dl
    mov [ebp + wNamedObjectIndex], dl
    call GetMoveName
    mov edx, wNameBuffer
    call CopyToStringBuffer
    call LearnMove                      ; -> BH: 0 = not learned, 1 = learned
    test bh, bh
    jz .restore
    ; Yellow: if the leveling mon is the player's starter Pikachu and the move it
    ; just learned is THUNDER/THUNDERBOLT, bump its mood/emotion. Faithful to pret
    ; evos_moves.asm LearnMoveFromLevelUp (.foundThunderOrThunderbolt). Only the
    ; learned path reaches here — the "already known" / "slots full" paths jump
    ; straight to .restore and skip this.
    movzx eax, byte [ebp + wMoveNum]
    cmp al, THUNDERBOLT
    je .pikachuThunderMove
    cmp al, THUNDER
    jne .restore
.pikachuThunderMove:
    call IsThisPartyMonStarterPikachu   ; uses [wWhichPokemon]; CF set if starter
    jnc .restore
    mov al, 5
    mov [ebp + wPikachuEmotionModifier], al
    mov al, 0x85
    mov [ebp + wPikachuMood], al
.restore:
    mov al, [ebp + wCurPartySpecies]
    mov [ebp + wPokedexNum], al
    ret

; In (via GetPredefRegisters / wPredef*): EDX (de) = move-slot base (MON_MOVES)
;   in WRAM. [wCurPartySpecies], [wCurEnemyLevel], [wLearningMovesFromDayCare].
WriteMonMoves:
    call GetPredefRegisters          ; esi=hl, edx=de (move dest, WRAM), ebx=bc
    push esi
    push edx
    push ebx
    call GetMonLearnset              ; esi = learnset ptr (FLAT)
    jmp .firstMove
.nextMove:
    pop edx                          ; restore de (move-slot base)
.nextMove2:
    inc esi                          ; inc hl (skip the move id; FLAT)
.firstMove:
    mov al, [esi]                    ; ld a,[hli] — level of next learnset move
    inc esi
    test al, al
    jz .done                         ; 0 ⇒ end of learnset
    mov bh, al                       ; ld b,a (move level)
    mov al, [ebp + wCurEnemyLevel]
    cmp al, bh
    jc .done                         ; mon level < move level (sorted ⇒ done)
    mov al, [ebp + wLearningMovesFromDayCare]
    test al, al
    jz .skipMinLevelCheck
    mov al, [ebp + wDayCareStartLevel]
    cmp al, bh
    jnc .nextMove2                   ; min level >= move level (jr nc)
.skipMinLevelCheck:
    ; already known?  ESI points at the move id (FLAT); slots in WRAM via EDX.
    push edx
    mov bl, NUM_MOVES
.alreadyKnowsCheckLoop:
    mov al, [ebp + edx]              ; ld a,[de] (slot)
    inc edx
    cmp al, [esi]                    ; cp [hl] (learnset move id, FLAT)
    je .nextMove                     ; already known ⇒ skip (pop de in .nextMove)
    dec bl
    jnz .alreadyKnowsCheckLoop
    ; find an empty slot
    pop edx
    push edx
    mov bl, NUM_MOVES
.findEmptySlotLoop:
    mov al, [ebp + edx]
    test al, al
    jz .writeMoveToSlot2             ; empty slot found (de left on stack)
    inc edx
    dec bl
    jnz .findEmptySlotLoop
    ; no empty slot — shift moves up (drop move 1)
    pop edx
    push edx
    push esi                         ; save learnset ptr (FLAT)
    mov esi, edx                     ; ld h,d / ld l,e — hl = de (move dest, WRAM)
    call WriteMonMoves_ShiftMoveData
    mov al, [ebp + wLearningMovesFromDayCare]
    test al, al
    jz .writeMoveToSlot
    ; TODO-DAYCARE: shift PP up as well (unreachable: flag always 0 today)
    push edx
    add esi, MON_PP - (MON_MOVES + 3)
    mov edx, esi                     ; ld d,h / ld e,l
    call WriteMonMoves_ShiftMoveData
    pop edx
.writeMoveToSlot:
    pop esi                          ; restore learnset ptr (FLAT)
.writeMoveToSlot2:
    mov al, [esi]                    ; ld a,[hl] (move id, FLAT)
    mov [ebp + edx], al             ; ld [de],a (write into slot, WRAM)
    mov al, [ebp + wLearningMovesFromDayCare]
    test al, al
    jz .nextMove
    ; TODO-DAYCARE: write the move's base PP (unreachable today). DIVERGENCE:
    ; read PP straight from the flat Moves table instead of FarCopyData→wBuffer.
    movzx eax, byte [esi]            ; move id (FLAT)
    dec eax
    imul eax, eax, MOVE_LENGTH
    mov al, [Moves + eax + MOVE_PP]  ; base PP (flat)
    movzx ecx, dx                    ; PP slot = de + (MON_PP - MON_MOVES)
    add ecx, MON_PP - MON_MOVES
    mov [ebp + ecx], al
    jmp .nextMove
.done:
    pop ebx
    pop edx
    pop esi
    ret

; Shift NUM_MOVES-1 entries up by one, freeing the last slot. ESI(hl)=dest,
; EDX(de)=source, both WRAM. Clobbers AL, BL, advances ESI/EDX.
WriteMonMoves_ShiftMoveData:
    mov bl, NUM_MOVES - 1
.loop:
    inc edx                          ; inc de
    mov al, [ebp + edx]              ; ld a,[de]
    mov [ebp + esi], al              ; ld [hli],a
    inc esi
    dec bl
    jnz .loop
    ret

; ---------------------------------------------------------------------------

; In:  [wCurPartySpecies] = internal index.
; Out: ESI (hl) = flat pointer to the level-up learnset (past the evo data).
GetMonLearnset:
    movzx ecx, byte [ebp + wCurPartySpecies]
    dec ecx                                  ; index = species - 1
    mov esi, [EvosMovesPointerTable + ecx*4]  ; flat 32-bit pointer (dd table)
.skipEvolutionDataLoop:
    mov al, [esi]                            ; flat read of the blob
    inc esi
    test al, al
    jnz .skipEvolutionDataLoop               ; skip past evo data + its 0 terminator
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
