; wild_encounters.asm — TryDoWildEncounter (battle engine plan, Stage 9).
;
; Faithful translation of engine/battle/wild_encounters.asm:TryDoWildEncounter.
; Decides whether a wild encounter triggers on the current step and, if so, rolls
; the encounter slot (WildMonEncounterSlotChances) and writes the chosen wild
; mon's level/species to wCurEnemyLevel / wCurPartySpecies / wEnemyMonSpecies2.
;
; Return convention (as pret): ZF set (Z) ⇒ an encounter happens; ZF clear ⇒ no
; encounter this step. The data tables are loaded by LoadWildData (wild_mons.asm).
;
; SCOPE: this is the data/RNG core. Its *consumer* — the overworld step trigger
; (NewBattle, wild_encounter_check.asm + OverworldLoop's gated call sites,
; complete since OW-A.6) — waits on THIS file's link closure. Two extern deps
; still resolve only to check-only files:
;   IsPlayerStandingOnDoorTileOrWarpTile  → CF (carry ⇒ on a door/warp tile)
;     — check-only player_state.asm (see Makefile HOME_CHECK_SRCS notes)
;   DisplayTextID (repel-wore-off message) — check-only home/text_script.asm
; (IsPlayerJustOutsideMap and EnableAutoTextBoxDrawing are linked.) These keep
; the file from linking into the EXE yet ("wild-live promotion"), but it
; assembles (make check) and the RNG/slot/species core is native-validated with
; those externs stubbed.
;
; The player's standing tile is read at the fixed projected offset
; PLAYER_STANDING_TILE below (OW-A.6: real projection, no longer a placeholder);
; it is read identically in both spots, so the grass/water decision is
; internally consistent.
;
; Register map: a=AL, b=BH, c=BL (bc=BX), hl=ESI (flat table / WRAM offset).
;
; Build: nasm -f coff -I include/ -I . -o wild_encounters.o wild_encounters.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

; ; TODO-OVERWORLD: see header. GB hlcoord(8,9) → +188 on a 20-wide map; here the
; 40-wide port map. OW-A.6: fixed from the stride-20-formula-on-a-40-wide-map
; placeholder to the real projection.
; PROJ overworld-field: GB(8,9) player feet 1x1 --(+16col,+8row -> W_TILEMAP)-->
; (PLAYER_STANDING_COL=24, PLAYER_STANDING_ROW=17) — the registry row in
; docs/ui_projection.md ("overworld-field (tile reads)"); matches the
; standing-tile reads in overworld.asm / player_state.asm.
PLAYER_STANDING_TILE    equ W_TILEMAP + PLAYER_STANDING_ROW * SCREEN_TILES_W + PLAYER_STANDING_COL
WATER_TILE_ID           equ 0x14        ; water tile in every tileset that has one

extern WildMonEncounterSlotChances
extern IsPlayerStandingOnDoorTileOrWarpTile
extern IsPlayerJustOutsideMap
extern EnableAutoTextBoxDrawing
extern DisplayTextID

section .text

global TryDoWildEncounter

TryDoWildEncounter:
    mov al, [ebp + wNPCMovementScriptPointerTableNum]
    test al, al
    jz .checkMovementFlags
    ret                                  ; ret nz — NPC movement script active
.checkMovementFlags:
    mov al, [ebp + wMovementFlags]
    test al, al
    jz .checkDoorWarp
    ret                                  ; ret nz — exiting door / ledge / fishing
.checkDoorWarp:
    call IsPlayerStandingOnDoorTileOrWarpTile
    jnc .notStandingOnDoorOrWarpTile     ; jr nc
.cantEncounter:
    mov al, 1
    or al, al                            ; ZF = 0 (no encounter)
    ret
.notStandingOnDoorOrWarpTile:
    call IsPlayerJustOutsideMap
    jz .cantEncounter                    ; jr z — just outside map
    mov al, [ebp + wRepelRemainingSteps]
    test al, al
    jz .next
    dec al
    jz .lastRepelStep
    mov [ebp + wRepelRemainingSteps], al
.next:
; determine if a wild mon can appear in the half-block we're standing in
    movzx ebx, byte [ebp + PLAYER_STANDING_TILE]  ; c = [hl] standing tile id
    mov al, [ebp + wGrassTile]
    cmp al, bl
    mov al, [ebp + wGrassRate]
    je .canEncounter                     ; on tall grass → use grass rate
    mov al, WATER_TILE_ID
    cmp al, bl
    mov al, [ebp + wWaterRate]
    je .canEncounter                     ; on water → use water rate
; not grass/water: only indoor maps with wild data can still encounter,
; except Viridian Forest / Safari Zone (FOREST tileset).
    mov al, [ebp + wCurMap]
    cmp al, FIRST_INDOOR_MAP
    jb .cantEncounter2                   ; jr c — outdoor, not grass/water
    mov al, [ebp + wCurMapTileset]
    cmp al, FOREST
    je .cantEncounter2
    mov al, [ebp + wGrassRate]
.canEncounter:
    mov bh, al                           ; b = encounter rate
    mov al, [ebp + hRandomAdd]
    cmp al, bh
    jae .cantEncounter2                  ; jr nc — random >= rate, no encounter
    mov al, [ebp + hRandomSub]
    mov bh, al                           ; b = random slot selector
    mov esi, WildMonEncounterSlotChances ; flat table
.determineEncounterSlot:
    mov al, [esi]                        ; ld a,[hli] — cumulative chance
    inc esi
    cmp al, bh
    jae .gotEncounterSlot                ; jr nc — cumulative >= random
    inc esi                              ; inc hl — skip slot byte
    jmp .determineEncounterSlot
.gotEncounterSlot:
    mov bl, [esi]                        ; c = slot*2 (offset into mon list)
    mov esi, wGrassMons                  ; ld hl, wGrassMons (WRAM offset)
    movzx eax, byte [ebp + PLAYER_STANDING_TILE]  ; lda_coord 8,9
    cmp al, WATER_TILE_ID
    jne .gotWildEncounterType            ; jr nz — grass by default
    mov esi, wWaterMons
.gotWildEncounterType:
    mov bh, 0
    movzx ecx, bx                        ; bc = slot*2 (b=0, c=slot*2)
    add esi, ecx                         ; hl = &wXxxMons[slot*2]
    mov al, [ebp + esi]                  ; ld a,[hli] — wild level
    inc esi
    mov [ebp + wCurEnemyLevel], al
    mov al, [ebp + esi]                  ; ld a,[hl] — wild species (internal idx)
    mov [ebp + wCurPartySpecies], al
    mov [ebp + wEnemyMonSpecies2], al
    mov al, [ebp + wRepelRemainingSteps]
    test al, al
    jz .willEncounter
; repel: skip the encounter if the lead party mon out-levels the wild mon
    mov al, [ebp + wPartyMon1Level]
    mov bh, al
    mov al, [ebp + wCurEnemyLevel]
    cmp al, bh
    jb .cantEncounter2                   ; jr c — wild level < lead level
    jmp .willEncounter
.lastRepelStep:
    mov [ebp + wRepelRemainingSteps], al ; al = 0
    mov al, TEXT_REPEL_WORE_OFF
    mov [ebp + hTextID], al
    call EnableAutoTextBoxDrawing
    call DisplayTextID
.cantEncounter2:
    mov al, 1
    or al, al                            ; ZF = 0 (no encounter)
    ret
.willEncounter:
    xor al, al                           ; ZF = 1 (encounter!)
    ret
