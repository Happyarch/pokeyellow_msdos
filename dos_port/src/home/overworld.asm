; overworld.asm — home-bank overworld helpers, at their pret mirror.
;
; Source: home/overworld.asm (pret/pokeyellow). Started at the menu-intro review
; (2026-07-23) to retire relocations: CheckForUserInterruption (was a dedicated
; home/check_user_interruption.asm), IsSpriteInFrontOfPlayer/-2 (were in
; engine/overworld/overworld.asm), SwitchToMapRomBank (was in home/bankswitch.asm),
; and the complete IsSpriteOrSignInFrontOfPlayer (R-002 retirement, 2026-07-23 —
; sign branch + counter-range extension + fallthrough into the sprite scan;
; a sign-branch-only version previously lived in engine/overworld/overworld.asm).
; pret home/overworld.asm's REMAINING labels still live in
; engine/overworld/overworld.asm (the port's historical home for them — legacy
; relocation debt, see tools/pret_label_allowlist.json); move them here when
; touched.
;
; Register map (CLAUDE.md): A=AL, BC=BX, DE=DX, HL=ESI; GB mem = [ebp+SYM].
;
; Build: nasm -f coff -I include/ -o overworld.o overworld.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_macros.inc"
%include "assets/audio_constants.inc"   ; SFX_COLLISION / MUSIC_* (audio engine is live)
%include "assets/map_dims.inc"          ; map-id + tileset-id constants (OAKS_LAB/CINNABAR_GYM/SHIP_PORT, OW-A.6)
%include "assets/event_constants.inc"   ; EVENT_* bit indices (EVENT_2A7, OW-A.6)
%include "events.inc"                   ; CheckEvent/SetEvent/ResetEvent over W_EVENT_FLAGS

; file-local constants carried in with the routines that read them
BIT_DUNGEON_WARP           equ 4
BIT_NO_BATTLES                  equ 4        ; wStatusFlags4 bit 4
BIT_ON_DUNGEON_WARP             equ 4        ; wStatusFlags3 bit 4
BIT_PIKACHU_SPAWN_SURFING  equ 6
BIT_WILD_ENCOUNTER_COOLDOWN     equ 0        ; wStatusFlags2 bit 0
INDIGO_PLATEAU              equ 0x09
MAP_ROCKET_HIDEOUT_B1F  equ 0xC7
MAP_ROCKET_HIDEOUT_B2F  equ 0xC8
MAP_ROCKET_HIDEOUT_B4F  equ 0xCA
MAP_ROCK_TUNNEL_1F      equ 0x52
MAP_SS_ANNE_3F          equ 0x61
PLAYER_HALF_BYTES equ PLAYER_HALF_TILES * TILE_SIZE   ; 192 bytes ($C0)
PLAYER_HALF_TILES equ 12                       ; 12 tiles per VRAM half
ROUTE_23                   equ 0x22
STANDING_TILE_OFF   equ W_TILEMAP + PLAYER_STANDING_ROW * SCREEN_TILES_W + PLAYER_STANDING_COL
TILESET_PLATEAU     equ 23          ; Route 23 / Indigo Plateau
TILESET_SHIP        equ 13          ; S.S. Anne interior
TILESET_SHIP_PORT   equ 14          ; Vermilion Port
W_D472                      equ 0xD472
W_PIKACHU_SPAWN_STATE_FLAGS equ 0xD471
wStepCounter                    equ 0xD13A
CEMETERY                    equ 15
CONNECTION_NORTH           equ 1 << 3   ; wCurMapConnections bits (EAST=1,WEST=2,SOUTH=4,NORTH=8)
CONNECTION_SOUTH           equ 1 << 2
FACILITY                    equ 22
MAP_NO_CONNECTION           equ 0xFF
OVERWORLD_DOOR_TILE         equ 0x0B   ; pret: door tile in tileset 0 (PlayMapChangeSound)
wNumSprites equ 0xD4E0

extern DelayFrame                    ; video/frame.asm
extern JoypadLowSensitivity          ; home/joypad_lowsens.asm — writes hJoy5
extern BankswitchCommon              ; home/bankswitch2.asm — AL = bank (flat no-op)
extern GetTileAndCoordsInFrontOfPlayer ; engine/overworld/player_state.asm (predef
extern BikeRidingTilesets                    ; src/home/player_gfx.asm
extern DoBoulderDustAnimation       ; src/engine/overworld/push_boulder.asm
extern HandleBlackOut                        ; engine/overworld/overworld.asm (pret home/overworld.asm)
extern HandleLedges                    ; src/engine/overworld/ledges.asm
extern IsPlayerCharacterBeingControlledByGame ; src/home/npc_movement.asm (real, linked — OW-A.6)
extern IsPlayerFacingEdgeOfMap                    ; src/engine/overworld/warp_check.asm
extern IsWarpTileInFrontOfPlayer                    ; src/engine/overworld/warp_check.asm
extern MapScriptPointers
extern PlayDefaultMusic             ; src/home/audio.asm (real gateway)
extern RedBikeSprite                    ; src/home/player_gfx.asm
extern RunNPCMovementScript         ; src/engine/overworld/overworld.asm
extern SeelSprite                    ; src/home/player_gfx.asm
extern SurfingPikachuSprite                    ; src/home/player_gfx.asm
extern TryDoWildEncounter                    ; engine/battle/wild_encounters.asm (LINKED)
extern TryPushingBoulder            ; src/engine/overworld/push_boulder.asm
extern _HandleMidJump                    ; src/engine/overworld/ledges.asm
extern _InitBattleCommon                     ; init_battle.asm — full wild-battle orchestration
extern g_tilecache_dirty            ; src/ppu/ppu.asm — arm tile-cache re-decode
extern player_sprite                ; == RedSprite (walking)

; --- relocated from src/engine/overworld/overworld.asm (unit 6a) ---
extern ApplyMapBorderOverrides
extern DisableLCD
extern EnableLCD
extern FarCopyData
extern FillMemory
extern GBPalNormal
extern InitMapSprites
extern LoadTextBoxTilePatterns
extern LoadTilesetHeader
extern LoadWildData
extern MapTextTablePointers
extern PlayDefaultMusicFadeOutCurrent
extern PlaySound
extern RefreshCollisionTileMap
extern RunPaletteCommand
extern UpdateMusic6Times
extern h_load_sprite_temp1
extern h_load_sprite_temp2
extern hide_window
extern wMapSpriteData
extern wMapSpriteExtraData
extern w_map_text_table_ptr
extern MapHeaderPointers            ; src/engine/overworld/overworld.asm (assets/map_headers.inc)
extern MapSongBanks                 ; src/engine/overworld/overworld.asm (assets/map_songs.inc)
extern OVERWORLD_BLOCKS_SIZE        ; src/engine/overworld/overworld.asm (assets/overworld_blocks.inc)

section .text

; ---------------------------------------------------------------------------
; CheckForUserInterruption — return CF set if Up+Select+B, Start, or A are pressed
; within BL (pret C) frames; CF clear on timeout. The intro / title / Game Freak
; splash skip-check.
;
; DEVIATION{class=data-model; pret=home/overworld.asm:CheckForUserInterruption; behavior=the _DEBUG-only extra Select skip is dropped (release build); evidence=the port defines no _DEBUG, so pret's ELSE branch (Start|A) is the live one; lifetime=until a debug build defines _DEBUG}
;
; In:  BL = frame count (pret C). EBP = GB base.
; Out: CF = 1 if interrupted, 0 on timeout. Clobbers EAX; BL decremented to 0.
; ---------------------------------------------------------------------------
global CheckForUserInterruption

global StepCountCheck
global AllPokemonFainted
global NewBattle
global CheckIfInOutsideMap
global ExtraWarpCheck
global StopBikeSurf
global LoadPlayerSpriteGraphics
global IsBikeRidingAllowed
global SignLoop
global CheckForJumpingAndTilePairCollisions
global CheckForTilePairCollisions2
global CheckForTilePairCollisions
global AreInputsSimulated
global GetSimulatedInput
global RunMapScript
global LoadWalkingPlayerSpriteGraphics
global LoadSurfingPlayerSpriteGraphics2
global LoadSurfingPlayerSpriteGraphics
global LoadBikePlayerSpriteGraphics
global LoadPlayerSpriteGraphicsCommon
global CopySignData
global ForceBikeOrSurf
global HandleMidJump
global CheckMapConnections
global CopyMapConnectionHeader
global DrawTileBlock
global LoadCurrentMapView
global LoadDestinationWarpPosition
global LoadEastWestConnectionsTileMap
global LoadMapData
global LoadMapHeader
global LoadNorthSouthConnectionsTileMap
global LoadScreenRelatedData
global LoadTileBlockMap
global LoadTilesetTilePatternData
global PlayMapChangeSound
global ResetMapVariables

; --------------------------------------------------------------------------
; StepCountCheck — decrement the per-step counters (pret home/overworld.asm:298).
; If simulated joypad input is active (scripted movement) it does nothing, so
; scripted door-exit steps don't count. Otherwise it decrements wStepCounter, and
; — only while the post-battle "no random battle" cooldown is armed — decrements
; wNumberOfNoRandomBattleStepsLeft, clearing the cooldown bit when it hits 0.
; Touches WRAM only; safe to call unconditionally.
; --------------------------------------------------------------------------
StepCountCheck:
    test byte [ebp + W_STATUS_FLAGS_5], (1 << BIT_SCRIPTED_MOVEMENT_STATE)
    jnz .doneStepCounting                     ; jr nz — inputs simulated, don't count
    dec byte [ebp + wStepCounter]             ; dec [hl] (wStepCounter)
    test byte [ebp + W_STATUS_FLAGS_2], (1 << BIT_WILD_ENCOUNTER_COOLDOWN)
    jz .doneStepCounting                      ; cooldown not armed
    dec byte [ebp + wNumberOfNoRandomBattleStepsLeft]
    jnz .doneStepCounting                     ; still counting down
    and byte [ebp + W_STATUS_FLAGS_2], (~(1 << BIT_WILD_ENCOUNTER_COOLDOWN)) & 0xFF
.doneStepCounting:
    ret
AllPokemonFainted:
    mov byte [ebp + wIsInBattle], 0xFF         ; wIsInBattle = $ff (lost)
    call RunMapScript
    jmp HandleBlackOut
NewBattle:
    test byte [ebp + W_STATUS_FLAGS_3], (1 << BIT_ON_DUNGEON_WARP)
    jnz .noBattle                             ; on a dungeon warp — no battle
    call IsPlayerCharacterBeingControlledByGame
    jnz .noBattle                             ; player under game control — no battle
    test byte [ebp + W_STATUS_FLAGS_4], (1 << BIT_NO_BATTLES)
    jnz .noBattle                             ; battles suppressed — no battle
    ; --- pret InitBattle / DetermineWildOpponent gate (engine/battle/init_battle.asm) ---
    mov al, [ebp + wCurOpponent]
    test al, al
    jnz .forcedOpponent                       ; wCurOpponent != 0 => forced (InitOpponent)
    ; DetermineWildOpponent:
    mov al, [ebp + wNumberOfNoRandomBattleStepsLeft]
    test al, al
    jnz .noBattle                             ; ret nz — still in no-battle window
    call TryDoWildEncounter                    ; ZF set => encounter, ZF clear => none
    jnz .noBattle                             ; ret nz — no wild encounter this step
    jmp .startBattle
.forcedOpponent:
    mov [ebp + wCurPartySpecies], al          ; InitOpponent: wCurPartySpecies = opponent
    mov [ebp + wEnemyMonSpecies2], al
.startBattle:
    call _InitBattleCommon                      ; run the real battle (data + intro + loop)
    ; _InitBattleCommon returns CF=1 (pret _InitBattleCommon: scf). The post-battle
    ; re-entry (pret .battleOccurred → AnyPartyAlive → EnterMap full map reload) is built
    ; into OverworldLoop (overworld.asm), which the CF=1 return below drives.
    stc                                        ; scf — a battle occurred (belt-and-braces)
    ret
.noBattle:
    clc                                        ; and a — CF=0, no battle
    ret

; ---------------------------------------------------------------------------
; CheckMapConnections — faithful translation.
; Pret ref: home/overworld.asm:CheckMapConnections
; ---------------------------------------------------------------------------
CheckMapConnections:
    push ebx
    push edx

    ; Edge thresholds
    mov al, [ebp + W_CUR_MAP_HEIGHT]
    add al, al
    mov [ebp + W_CURRENT_MAP_HEIGHT_2], al
    mov al, [ebp + W_CUR_MAP_WIDTH]
    add al, al
    mov [ebp + W_CURRENT_MAP_WIDTH_2], al

    ; East connection check
    mov al, [ebp + W_X_COORD]
    cmp al, [ebp + W_CURRENT_MAP_WIDTH_2]
    jne .checkWest
    mov al, [ebp + W_EAST_CONNECTED_MAP]
    cmp al, MAP_NO_CONNECTION
    je .checkWest
    mov ebx, W_EAST_CONNECTED_MAP
    
    mov [ebp + W_CUR_MAP], al
    mov al, [ebp + W_EAST_CONNECTED_MAP + CONN_X_ALIGN]
    mov [ebp + W_X_COORD], al
    mov al, [ebp + W_Y_COORD]
    mov cl, al
    mov al, [ebp + W_EAST_CONNECTED_MAP + CONN_Y_ALIGN]
    add cl, al
    mov [ebp + W_Y_COORD], cl
    
    mov al, [ebp + W_EAST_CONNECTED_MAP + CONN_VIEW_PTR]
    mov dl, al
    mov al, [ebp + W_EAST_CONNECTED_MAP + CONN_VIEW_PTR + 1]
    mov dh, al
    
    shr cl, 1
    jz .savePointer2
    
.pointerAdjustmentLoop2:
    mov al, [ebp + W_EAST_CONNECTED_MAP + CONN_MAP_WIDTH]
    add al, MAP_BORDER * 2
    movzx eax, al
    add edx, eax
    dec cl
    jnz .pointerAdjustmentLoop2
.savePointer2:
    mov [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR], dx
    jmp .loadNewMap

.checkWest:
    mov al, [ebp + W_X_COORD]
    cmp al, 255
    jne .checkSouth
    mov al, [ebp + W_WEST_CONNECTED_MAP]
    cmp al, MAP_NO_CONNECTION
    je .checkSouth
    mov ebx, W_WEST_CONNECTED_MAP
    
    mov [ebp + W_CUR_MAP], al
    mov al, [ebp + W_WEST_CONNECTED_MAP + CONN_X_ALIGN]
    mov [ebp + W_X_COORD], al
    mov al, [ebp + W_Y_COORD]
    mov cl, al
    mov al, [ebp + W_WEST_CONNECTED_MAP + CONN_Y_ALIGN]
    add cl, al
    mov [ebp + W_Y_COORD], cl
    
    mov al, [ebp + W_WEST_CONNECTED_MAP + CONN_VIEW_PTR]
    mov dl, al
    mov al, [ebp + W_WEST_CONNECTED_MAP + CONN_VIEW_PTR + 1]
    mov dh, al
    
    shr cl, 1
    jz .savePointer1
    
.pointerAdjustmentLoop1:
    mov al, [ebp + W_WEST_CONNECTED_MAP + CONN_MAP_WIDTH]
    add al, MAP_BORDER * 2
    movzx eax, al
    add edx, eax
    dec cl
    jnz .pointerAdjustmentLoop1
.savePointer1:
    mov [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR], dx
    jmp .loadNewMap

.checkSouth:
    mov al, [ebp + W_Y_COORD]
    cmp al, [ebp + W_CURRENT_MAP_HEIGHT_2]
    jne .checkNorth
    mov al, [ebp + W_SOUTH_CONNECTED_MAP]
    cmp al, MAP_NO_CONNECTION
    je .checkNorth
    mov ebx, W_SOUTH_CONNECTED_MAP
    
    mov [ebp + W_CUR_MAP], al
    mov al, [ebp + W_SOUTH_CONNECTED_MAP + CONN_Y_ALIGN]
    mov [ebp + W_Y_COORD], al
    mov al, [ebp + W_X_COORD]
    mov cl, al
    mov al, [ebp + W_SOUTH_CONNECTED_MAP + CONN_X_ALIGN]
    add cl, al
    mov [ebp + W_X_COORD], cl
    
    mov al, [ebp + W_SOUTH_CONNECTED_MAP + CONN_VIEW_PTR]
    mov dl, al
    mov al, [ebp + W_SOUTH_CONNECTED_MAP + CONN_VIEW_PTR + 1]
    mov dh, al
    
    shr cl, 1
    jz .savePointer4
    movzx ecx, cl
    add edx, ecx
.savePointer4:
    mov [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR], dx
    jmp .loadNewMap

.checkNorth:
    mov al, [ebp + W_Y_COORD]
    cmp al, 255
    jne .done
    mov al, [ebp + W_NORTH_CONNECTED_MAP]
    cmp al, MAP_NO_CONNECTION
    je .done
    mov ebx, W_NORTH_CONNECTED_MAP
    
    mov [ebp + W_CUR_MAP], al
    mov al, [ebp + W_NORTH_CONNECTED_MAP + CONN_Y_ALIGN]
    mov [ebp + W_Y_COORD], al
    mov al, [ebp + W_X_COORD]
    mov cl, al
    mov al, [ebp + W_NORTH_CONNECTED_MAP + CONN_X_ALIGN]
    add cl, al
    mov [ebp + W_X_COORD], cl
    
    mov al, [ebp + W_NORTH_CONNECTED_MAP + CONN_VIEW_PTR]
    mov dl, al
    mov al, [ebp + W_NORTH_CONNECTED_MAP + CONN_VIEW_PTR + 1]
    mov dh, al
    
    shr cl, 1
    jz .savePointer3
    movzx ecx, cl
    add edx, ecx
.savePointer3:
    mov [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR], dx
    jmp .loadNewMap

.done:
    pop edx
    pop ebx
    clc                                        ; CF=0 → no transition
    ret

.loadNewMap:
    ; A connection was crossed. pret home/overworld.asm:.loadNewMap inlines the whole
    ; reload here — Pikachu spawn set, LoadMapHeader, PlayDefaultMusicFadeOutCurrent,
    ; RunPaletteCommand(SET_PAL_OVERWORLD), InitMapSprites, LoadTileBlockMap, then
    ; jp OverworldLoopLessDelay. The port instead returns CF=1 and the caller performs
    ; that reload at OverworldLoop.mapTransition, which now does LoadMapHeader +
    ; PlayDefaultMusicFadeOutCurrent (OW-A.14, real); palette reload still deferred.
    ; Only the coordinate/block sync stays inline here.
    ; First, synchronize block coordinates with the new tile coordinates.
    mov al, [ebp + W_X_COORD]
    and al, 1
    mov [ebp + W_X_BLOCK_COORD], al
    mov al, [ebp + W_Y_COORD]
    and al, 1
    mov [ebp + W_Y_BLOCK_COORD], al

    pop edx
    pop ebx
    stc                                        ; CF=1 → transition occurred
    ret


; ---------------------------------------------------------------------------
; PlayMapChangeSound — on a warp, play the "go inside" jingle if the player
; walked through an overworld door tile, else "go outside".
; Pret ref: home/overworld.asm:PlayMapChangeSound (:666). Called from WarpFound2
; (the port's .warpTransition) before EnterMap, so it reads the SOURCE map's
; tilemap (the door the player stepped on), not the destination.
; Preserves nothing pret doesn't (AL used); the caller has no live regs here.
; ---------------------------------------------------------------------------
PlayMapChangeSound:
    mov al, [ebp + W_CUR_MAP_TILESET]
    cmp al, FACILITY
    je .didNotGoThroughDoor
    cmp al, CEMETERY
    je .didNotGoThroughDoor
    ; pret lda_coord 8, 8 = upper-left tile of the player's block, one row above the
    ; standing tile (lda_coord 8, 9 → port PLAYER_STANDING). Port row scaling is 1:1
    ; (fronts are ±2 rows), so project to (PLAYER_STANDING_ROW - 1, PLAYER_STANDING_COL).
    ; ; PROJ: this door-tile row projection + the pre-EnterMap tilemap timing are
    ; unverified (no golden warp scenario) — the go-inside/go-outside SFX selection
    ; needs MCP live-warp verification. Wrong projection only mis-picks the jingle.
    movzx eax, byte [ebp + W_TILEMAP + (PLAYER_STANDING_ROW - 1) * SCREEN_TILES_W + PLAYER_STANDING_COL]
    cmp al, OVERWORLD_DOOR_TILE                  ; pret: cp $0b (door tile in tileset 0)
    jne .didNotGoThroughDoor
    mov al, SFX_GO_INSIDE
    jmp .playSound
.didNotGoThroughDoor:
    mov al, SFX_GO_OUTSIDE
.playSound:
    call PlaySound
    ; pret tail: if wMapPalOffset != 0 ret; else jp GBFadeOutToBlack.
    ; TODO-HW: palette/fade (Phase 5) — GBFadeOutToBlack deferred (DMG-green debug palette).
    ret

CheckIfInOutsideMap:
    mov al, [ebp + W_CUR_MAP_TILESET]
    test al, al                     ; OVERWORLD → ZF=1
    jz .ret
    cmp al, TILESET_PLATEAU         ; PLATEAU  → ZF=1
.ret:
    ret

; ---------------------------------------------------------------------------
; ExtraWarpCheck — pret home/overworld.asm:ExtraWarpCheck
;
; An extra check that sometimes must pass to warp, beyond standing on a warp.
; Depending on the map, either "function 1" or "function 2" is selected:
;   function 1 (IsPlayerFacingEdgeOfMap):    pass if the player is at the edge
;              of the map and facing outward  — used by interior maps (the
;              default) and, exceptionally, SS_ANNE_3F.
;   function 2 (IsWarpTileInFrontOfPlayer):  pass if the tile in front of the
;              player is a warp-carpet tile   — used by the OVERWORLD / SHIP /
;              SHIP_PORT / PLATEAU tilesets and the Rocket Hideout / Rock Tunnel
;              dungeon floors.
;
; Out: CF=1 if the check passes (a warp is possible), CF=0 otherwise.
; Register-safe: preserves EAX/EBX/ECX/EDX/ESI; returns only CF.
;
; NOTE (working-warps preservation): every interior map the port currently
; supports (Red's House, Blue's House, Oak's Lab, Marts, Poké Centers, …) puts
; its exit-door warp on the bottom tile row, i.e. wYCoord == wCurMapHeight*2-1.
; With the player facing DOWN there, function 1 returns carry exactly where the
; old hardcoded "facing DOWN" test did — so the live door exits keep working,
; while side/top-edge and warp-carpet warps now behave faithfully too. The data
; function 1 needs (height/width/coords/facing) is fully populated, and function
; 2 reads the already-populated wTileInFrontOfPlayer (see below), so no
; fallback to the old behavior is required.
; ---------------------------------------------------------------------------
ExtraWarpCheck:
    push eax
    push ebx
    push ecx
    push edx
    push esi

    mov al, [ebp + W_CUR_MAP]
    cmp al, MAP_SS_ANNE_3F
    je .useFunction1
    cmp al, MAP_ROCKET_HIDEOUT_B1F
    je .useFunction2
    cmp al, MAP_ROCKET_HIDEOUT_B2F
    je .useFunction2
    cmp al, MAP_ROCKET_HIDEOUT_B4F
    je .useFunction2
    cmp al, MAP_ROCK_TUNNEL_1F
    je .useFunction2

    mov al, [ebp + W_CUR_MAP_TILESET]
    test al, al                     ; OVERWORLD (0) → function 2
    jz .useFunction2
    cmp al, TILESET_SHIP
    je .useFunction2
    cmp al, TILESET_SHIP_PORT
    je .useFunction2
    cmp al, TILESET_PLATEAU
    je .useFunction2

.useFunction1:
    call IsPlayerFacingEdgeOfMap    ; sets CF
    jmp .done
.useFunction2:
    call IsWarpTileInFrontOfPlayer  ; sets CF
.done:
    ; POP does not affect CF, so the helper's CF is returned intact.
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret
StopBikeSurf:
    mov al, [ebp + W_WALK_BIKE_SURF_STATE]
    test al, al
    jz .done                                ; ret z (already walking)
    mov byte [ebp + W_WALK_BIKE_SURF_STATE], 0
    test byte [ebp + W_STATUS_FLAGS_6], (1 << BIT_DUNGEON_WARP)
    jz .done                                ; ret z
    call PlayDefaultMusic                    ; pret: call PlayDefaultMusic
.done:
    ret

; ---------------------------------------------------------------------------
; LoadPlayerSpriteGraphics — dispatcher.
; Pret ref: home/overworld.asm:LoadPlayerSpriteGraphics
; Loads standing/biking/surfing tiles based on wWalkBikeSurfState
; (0=standing, 1=biking, 2=surfing). If biking is not currently allowed the
; state is reset to standing first.
; ---------------------------------------------------------------------------
LoadPlayerSpriteGraphics:
    mov al, [ebp + W_WALK_BIKE_SURF_STATE]
    dec al
    jz .ridingBike                          ; state == 1

    ; standing (or surfing): honor hTileAnimations gate as pret does
    mov al, [ebp + H_TILE_ANIMATIONS]
    test al, al
    jnz .determineGraphics
    jmp .startWalking

.ridingBike:
    ; If the bike can't be used here, start walking instead.
    call IsBikeRidingAllowed                ; CF = biking allowed
    jc .determineGraphics

.startWalking:
    xor al, al
    mov [ebp + W_WALK_BIKE_SURF_STATE],      al
    mov [ebp + W_WALK_BIKE_SURF_STATE_COPY], al
    jmp LoadWalkingPlayerSpriteGraphics

.determineGraphics:
    mov al, [ebp + W_WALK_BIKE_SURF_STATE]
    test al, al
    jz LoadWalkingPlayerSpriteGraphics       ; 0 → walking
    dec al
    jz LoadBikePlayerSpriteGraphics          ; 1 → biking
    dec al
    jz LoadSurfingPlayerSpriteGraphics2      ; 2 → surfing
    jmp LoadWalkingPlayerSpriteGraphics      ; fallback
IsBikeRidingAllowed:
    mov al, [ebp + W_CUR_MAP]
    cmp al, ROUTE_23
    je .allowed
    cmp al, INDIGO_PLATEAU
    je .allowed

    mov bh, [ebp + W_CUR_MAP_TILESET]       ; B = BH
    mov esi, BikeRidingTilesets             ; HL → table
.loop:
    mov al, [esi]                           ; ld a,[hli]
    inc esi
    cmp al, bh
    je .allowed
    inc al                                  ; $FF terminator → 0 (ZF)
    jnz .loop
    clc                                     ; pret: `and a` → CF=0 (not allowed)
    ret
.allowed:
    stc
    ret

; ---------------------------------------------------------------------------
; LoadTilesetTilePatternData — faithful translation.
; Pret ref: home/overworld.asm:LoadTilesetTilePatternData
;
; Reads wTilesetGfxPtr (16-bit GB address) and copies $600 bytes (1536) from
; that ROM-window address to vTileset ($9000 = GB_VCHARS2).
; In the flat model wTilesetBank (FarCopyData bank arg) is ignored.
; ---------------------------------------------------------------------------
LoadTilesetTilePatternData:
    mov byte [g_tilecache_dirty], 1     ; VRAM tile data changes → rebuild decode cache
    ; ESI = wTilesetGfxPtr (16-bit GB address, LE word)
    movzx esi, word [ebp + W_TILESET_GFX_PTR]    ; ESI = HL = 0x4000
    mov edx, GB_VCHARS2                            ; EDX = DE = 0x9000 (vTileset)
    mov bx,  0x0600                                ; BX = BC = $600 bytes
    movzx eax, byte [ebp + W_TILESET_BANK]         ; AL = bank (ignored)
    jmp FarCopyData                                ; tail call


; ---------------------------------------------------------------------------
; LoadTileBlockMap — faithful translation.
; Pret ref: home/overworld.asm:LoadTileBlockMap
;
; 1. Fills wOverworldMap with wMapBackgroundTile (border block).
; 2. Copies PalletTown.blk data (from wCurMapDataPtr) into wOverworldMap,
;    offset by MAP_BORDER rows and MAP_BORDER columns.
; 3. Processes N/S/W/E connection strips (all $FF = none for Phase 2).
; ---------------------------------------------------------------------------
LoadTileBlockMap:
    push esi
    push edi
    push ebx
    push ecx

    ; Fill wOverworldMap..wOverworldMapEnd with wMapBackgroundTile
    mov esi, W_OVERWORLD_MAP
    mov bx,  W_OVERWORLD_MAP_SIZE & 0xFFFF
    movzx eax, byte [ebp + W_MAP_BACKGROUND_TILE]
    call FillMemory

    ; HL = ESI = wOverworldMap
    mov esi, W_OVERWORLD_MAP

    ; hMapWidth = wCurMapWidth; hMapStride = width + MAP_BORDER*2
    movzx ecx, byte [ebp + W_CUR_MAP_WIDTH]       ; ECX = width (= 10)
    mov byte [ebp + H_MAP_WIDTH], cl
    add cl, MAP_BORDER * 2                         ; CL = stride (= 16)
    mov byte [ebp + H_MAP_STRIDE], cl

    ; Skip MAP_BORDER rows: ESI += stride * MAP_BORDER
    movzx eax, cl                                  ; EAX = stride
    imul eax, MAP_BORDER                           ; EAX = stride * 3
    add esi, eax                                   ; ESI = row MAP_BORDER start

    ; Skip MAP_BORDER cols: ESI += MAP_BORDER
    add esi, MAP_BORDER                            ; ESI = first cell of map data

    ; DE = wCurMapDataPtr (source: .blk data in ROM window)
    movzx edx, word [ebp + W_CUR_MAP_DATA_PTR]    ; EDX = map .blk GB addr (rom_window.inc)

    ; B (BH) = wCurMapHeight (row count)
    movzx eax, byte [ebp + W_CUR_MAP_HEIGHT]
    mov bh, al

.row_loop:
    push esi                                       ; save row-start write ptr
    movzx ecx, byte [ebp + H_MAP_WIDTH]            ; CL = map width (without border)
.row_inner_loop:
    mov al, byte [ebp + edx]                       ; read block ID from .blk
    inc edx
    mov byte [ebp + esi], al                       ; write block ID to wOverworldMap
    inc esi
    dec cl
    jnz .row_inner_loop
    pop esi                                        ; restore row-start ptr
    movzx eax, byte [ebp + H_MAP_STRIDE]           ; EAX = stride
    add esi, eax                                   ; advance ESI to next row
    dec bh
    jnz .row_loop

    ; --- Border overrides (map-tool C3): hand-authored blocks for the border
    ;     ring, painted in tools/map_editor/editor.py and generated into
    ;     assets/map_border_overrides.inc. Applied BEFORE the connection
    ;     strips so connections always win (the generator also rejects any
    ;     cell inside a strip or the real map area).
    call ApplyMapBorderOverrides

    ; --- Connection strips: copy each connected map's edge into the wOverworldMap
    ;     border. SwitchToMapRomBank is a no-op in the flat model. The strip src
    ;     pointers (CONN_STRIP_SRC) index into the connected maps' block data
    ;     loaded at OW_ROUTE*_BLK_GBADDR. hNorthSouthConnectionStripWidth and the
    ;     connected-map width reuse H_MAP_STRIDE/H_MAP_WIDTH (they are HRAM unions).

.north_connection:
    cmp byte [ebp + W_NORTH_CONNECTED_MAP], MAP_NO_CONNECTION
    je  .south_connection
    movzx esi, word [ebp + W_NORTH_CONNECTED_MAP + CONN_STRIP_SRC]   ; HL = strip src
    movzx edx, word [ebp + W_NORTH_CONNECTED_MAP + CONN_STRIP_DEST]  ; DE = strip dest
    mov al, [ebp + W_NORTH_CONNECTED_MAP + CONN_STRIP_LENGTH]
    mov [ebp + H_MAP_STRIDE], al                                     ; hNSConnectionStripWidth
    mov al, [ebp + W_NORTH_CONNECTED_MAP + CONN_MAP_WIDTH]
    mov [ebp + H_MAP_WIDTH], al                                      ; hNSConnectedMapWidth
    call LoadNorthSouthConnectionsTileMap

.south_connection:
    cmp byte [ebp + W_SOUTH_CONNECTED_MAP], MAP_NO_CONNECTION
    je  .west_connection
    movzx esi, word [ebp + W_SOUTH_CONNECTED_MAP + CONN_STRIP_SRC]
    movzx edx, word [ebp + W_SOUTH_CONNECTED_MAP + CONN_STRIP_DEST]
    mov al, [ebp + W_SOUTH_CONNECTED_MAP + CONN_STRIP_LENGTH]
    mov [ebp + H_MAP_STRIDE], al
    mov al, [ebp + W_SOUTH_CONNECTED_MAP + CONN_MAP_WIDTH]
    mov [ebp + H_MAP_WIDTH], al
    call LoadNorthSouthConnectionsTileMap

.west_connection:
    cmp byte [ebp + W_WEST_CONNECTED_MAP], MAP_NO_CONNECTION
    je  .east_connection
    movzx esi, word [ebp + W_WEST_CONNECTED_MAP + CONN_STRIP_SRC]
    movzx edx, word [ebp + W_WEST_CONNECTED_MAP + CONN_STRIP_DEST]
    movzx ebx, byte [ebp + W_WEST_CONNECTED_MAP + CONN_STRIP_LENGTH] ; B = row count
    mov al, [ebp + W_WEST_CONNECTED_MAP + CONN_MAP_WIDTH]
    mov [ebp + H_MAP_WIDTH], al                                      ; hEWConnectedMapWidth
    call LoadEastWestConnectionsTileMap

.east_connection:
    cmp byte [ebp + W_EAST_CONNECTED_MAP], MAP_NO_CONNECTION
    je  .done
    movzx esi, word [ebp + W_EAST_CONNECTED_MAP + CONN_STRIP_SRC]
    movzx edx, word [ebp + W_EAST_CONNECTED_MAP + CONN_STRIP_DEST]
    movzx ebx, byte [ebp + W_EAST_CONNECTED_MAP + CONN_STRIP_LENGTH]
    mov al, [ebp + W_EAST_CONNECTED_MAP + CONN_MAP_WIDTH]
    mov [ebp + H_MAP_WIDTH], al
    call LoadEastWestConnectionsTileMap

.done:
    pop ecx
    pop ebx
    pop edi
    pop esi
    ret


; ---------------------------------------------------------------------------
; LoadNorthSouthConnectionsTileMap — faithful translation.
; Pret ref: home/overworld.asm:LoadNorthSouthConnectionsTileMap
;
; Copies MAP_BORDER (3) rows of the connected map's edge into the wOverworldMap
; border. Each row copies hNorthSouthConnectionStripWidth (=H_MAP_STRIDE) bytes;
; src advances by hNorthSouthConnectedMapWidth (=H_MAP_WIDTH), dest by the
; wOverworldMap stride (wCurMapWidth + 2*MAP_BORDER).
;
; In:  ESI = HL = strip src, EDX = DE = strip dest, [H_MAP_STRIDE] = strip width,
;      [H_MAP_WIDTH] = connected-map width. EBP = GB base.
; Clobbers: EAX, EBX, ECX, ESI, EDX.
; ---------------------------------------------------------------------------
LoadNorthSouthConnectionsTileMap:
    mov ecx, MAP_BORDER                  ; C = 3 rows
.row:
    push esi
    push edx
    movzx ebx, byte [ebp + H_MAP_STRIDE] ; B = strip width
.inner:
    mov al, [ebp + esi]
    mov [ebp + edx], al
    inc esi
    inc edx
    dec bl
    jnz .inner
    pop edx
    pop esi
    movzx eax, byte [ebp + H_MAP_WIDTH]  ; src += connected-map width
    add esi, eax
    movzx eax, byte [ebp + W_CUR_MAP_WIDTH]
    add eax, MAP_BORDER * 2
    add edx, eax                         ; dest += wOverworldMap stride
    dec ecx
    jnz .row
    ret


; ---------------------------------------------------------------------------
; LoadEastWestConnectionsTileMap — faithful translation.
; Pret ref: home/overworld.asm:LoadEastWestConnectionsTileMap
;
; Copies MAP_BORDER (3) columns of the connected map's edge into the
; wOverworldMap border, for B (strip length) rows. Each row copies 3 bytes; src
; advances by hEastWestConnectedMapWidth (=H_MAP_WIDTH), dest by the wOverworldMap
; stride. (Pallet Town has no E/W connection, but kept faithful for completeness.)
;
; In:  ESI = HL = strip src, EDX = DE = strip dest, BL = row count,
;      [H_MAP_WIDTH] = connected-map width. EBP = GB base.
; Clobbers: EAX, EBX(bl=counter), ECX, ESI, EDX.
; ---------------------------------------------------------------------------
LoadEastWestConnectionsTileMap:
.row:
    push esi
    push edx
    mov ecx, MAP_BORDER                  ; 3 columns
.inner:
    mov al, [ebp + esi]
    mov [ebp + edx], al
    inc esi
    inc edx
    dec ecx
    jnz .inner
    pop edx
    pop esi
    movzx eax, byte [ebp + H_MAP_WIDTH]  ; src += connected-map width
    add esi, eax
    movzx eax, byte [ebp + W_CUR_MAP_WIDTH]
    add eax, MAP_BORDER * 2
    add edx, eax                         ; dest += wOverworldMap stride
    dec bl
    jnz .row
    ret

IsSpriteOrSignInFrontOfPlayer:
    mov byte [ebp + hTextID], 0      ; xor a / ldh [hTextID], a
    mov al, [ebp + W_NUM_SIGNS]      ; ld a, [wNumSigns]
    test al, al                      ; and a
    jz .extendRangeOverCounter       ; jr z, .extendRangeOverCounter
; if there are signs
    call GetTileAndCoordsInFrontOfPlayer ; predef — front map coords in DH/DL
    call SignLoop                    ; CF=1 + [hTextID]=sign id on a match
    jnc .extendRangeOverCounter      ; ┐ pret `ret c`: return only when a sign
    ret                              ; ┘ matched (CF stays set for the caller)
.extendRangeOverCounter:
; counter tile in front? then extend the range at which the player can talk
    call GetTileAndCoordsInFrontOfPlayer ; predef — front tile id in CL
    mov esi, W_TILESET_TALKING_OVER_TILES ; ld hl, wTilesetTalkingOverTiles
    mov bh, 3                        ; ld b, 3 — the list is 3 bytes
    mov dh, 0x20                     ; ld d, $20 — long talking range, in pixels
.counterTilesLoop:
    mov al, [ebp + esi]              ; ld a, [hli]
    inc esi
    cmp al, cl                       ; cp c — is the front tile a counter tile?
    je IsSpriteInFrontOfPlayer2      ; jr z — long-range scan (DH = $20 survives)
    dec bh                           ; dec b
    jnz .counterTilesLoop            ; jr nz
    ; fall through into IsSpriteInFrontOfPlayer (which presets DH = $10)

IsSpriteInFrontOfPlayer:
    mov dh, 0x10                     ; ld d, $10 — normal talking range, in pixels
IsSpriteInFrontOfPlayer2:
    mov bh, 0x3c                     ; lb bc, $3c, $40 — the player sprite's fixed
    mov bl, 0x40                     ; screen Y ($3c) and X ($40)
    mov al, [ebp + W_SPRITE_PLAYER_FACING_DIR]
.checkIfPlayerFacingUp:
    cmp al, SPRITE_FACING_UP
    jne .checkIfPlayerFacingDown
    sub bh, dh                       ; ld a,b / sub d / ld b,a
    mov al, PLAYER_DIR_UP
    jmp .doneCheckingDirection
.checkIfPlayerFacingDown:
    cmp al, SPRITE_FACING_DOWN
    jne .checkIfPlayerFacingRight
    add bh, dh
    mov al, PLAYER_DIR_DOWN
    jmp .doneCheckingDirection
.checkIfPlayerFacingRight:
    cmp al, SPRITE_FACING_RIGHT
    jne .playerFacingLeft
    add bl, dh
    mov al, PLAYER_DIR_RIGHT
    jmp .doneCheckingDirection
.playerFacingLeft:
    sub bl, dh
    mov al, PLAYER_DIR_LEFT
.doneCheckingDirection:
    mov [ebp + W_PLAYER_DIRECTION], al
    mov esi, wSprite01StateData1     ; slot 1 (slot 0 is the player)
    mov dl, 0x01                     ; e = slot index, 1-based
    mov dh, 0x0f                     ; d = 15 slots to scan (range is dead from here)
; Yellow does not have Red's "if sprites are existent" check.
.spriteLoop:
    push esi
    mov al, [ebp + esi + SPRITESTATEDATA1_PICTUREID]
    test al, al
    jz .nextSprite                   ; 0 = no sprite in this slot
    mov al, [ebp + esi + SPRITESTATEDATA1_IMAGEINDEX]
    inc al
    jz .nextSprite                   ; $ff = sprite hidden (pret: inc a / jr z)
    mov al, [ebp + esi + SPRITESTATEDATA1_YPIXELS]
    cmp al, bh
    jne .nextSprite
    mov al, [ebp + esi + SPRITESTATEDATA1_XPIXELS]
    cmp al, bl
    je .foundSpriteInFrontOfPlayer
.nextSprite:
    pop esi
    ; pret does this as `ld a,l / add SPRITESTATEDATA1_LENGTH / ld l,a` — 8-bit math
    ; on L alone. Equivalent here: the scan runs slots 1-15 ($C110..$C1F0), so L never
    ; wraps before the counter ends the loop.
    add esi, SPRITESTATEDATA1_LENGTH
    inc dl
    dec dh                           ; sets the ZF the loop branch reads
    jnz .spriteLoop
    xor al, al                       ; also clears CF: no sprite in front
    ret
.foundSpriteInFrontOfPlayer:
    pop esi
    ; pret: ld a,l / and $f0 / inc a / ld l,a — mask back to the slot base, then +1.
    ; ESI is already the slot base (16-aligned), so the mask is a no-op here.
    add esi, SPRITESTATEDATA1_MOVEMENTSTATUS
    or byte [ebp + esi], (1 << BIT_FACE_PLAYER)  ; set BIT_FACE_PLAYER, [hl]
    mov al, dl
    mov [ebp + H_SPRITE_INDEX], al
    ; pret re-reads hSpriteIndex here ("possible useless read because a already has
    ; the value") — elided; AL already holds it.
    cmp al, PIKACHU_SPRITE_INDEX
    jne .dontwritetowd436            ; pret's label typo (.dontwritetowd436 → wd435) kept
    mov byte [ebp + wd435], 0xFF
.dontwritetowd436:
    stc                              ; scf: found
    ret

SignLoop:
    lea esi, [ebp + W_SIGN_COORDS]      ; hl = wSignCoords
    mov cl, [ebp + W_NUM_SIGNS]         ; CL = remaining count (b)
    xor ch, ch                          ; CH = 1-based index (c)
.signLoop:
    inc ch                              ; c++
    mov al, [esi]                       ; sign Y
    inc esi
    cmp al, dh
    je .yMatched
    inc esi                             ; skip X
    jmp .retry
.yMatched:
    mov al, [esi]                       ; sign X
    inc esi
    cmp al, dl
    jne .retry
    ; matched: text ID at wSignTextIDs[c-1]
    movzx eax, ch
    dec eax
    mov al, [ebp + eax + W_SIGN_TEXT_IDS]
    mov [ebp + hTextID], al
    stc
    ret
.retry:
    dec cl
    jnz .signLoop
    clc
    ret

; ---------------------------------------------------------------------------
; CheckForJumpingAndTilePairCollisions — pret home/overworld.asm.
;
; In:  ESI = flat host ptr to the directional tile-pair table (TilePairCollisionsLand
;            or ...Water); W_TILE_IN_FRONT_OF_PLAYER already set by the caller.
;            (pret re-runs GetTileAndCoordsInFrontOfPlayer here; the port's caller,
;            CollisionCheckOnLand, sets it via GetTileInFrontOfPlayer immediately
;            before — so this port keeps the value rather than re-deriving it, which
;            avoids exporting GetTileInFrontOfPlayer out of overworld.asm.)
; Out: CF = 1 if an illegal tile-pair boundary is crossed (movement blocked).
;      May arm a ledge hop (HandleLedges sets BIT_LEDGE_OR_FISHING + simulated joypad);
;      in that case CF = 0 (no tile-pair collision) and the caller allows the move.
; Clobbers: AL, BL, CL, DH, ESI, flags.
;
; SM83:
;   push hl / predef GetTileAndCoordsInFrontOfPlayer / farcall HandleLedges
;   and a / ld a,[wMovementFlags] / bit BIT_LEDGE_OR_FISHING,a / ret nz
;   (falls into CheckForTilePairCollisions2)
; ---------------------------------------------------------------------------
CheckForJumpingAndTilePairCollisions:
    push esi                                       ; preserve the table ptr across HandleLedges
    call HandleLedges                              ; may arm a ledge hop
    pop esi
    test byte [ebp + W_MOVEMENT_FLAGS], (1 << BIT_LEDGE_OR_FISHING)
    jz  CheckForTilePairCollisions2               ; not jumping a ledge → run the tile-pair scan
    clc                                            ; jumping a ledge → no tile-pair collision
    ret
CheckForTilePairCollisions2:
    mov dh, [ebp + STANDING_TILE_OFF]              ; DH = tile the player stands on (pret wTilePlayerStandingOn)
CheckForTilePairCollisions:
    mov cl, [ebp + W_TILE_IN_FRONT_OF_PLAYER]      ; c = tile in front
.loop:
    mov bl, [ebp + W_CUR_MAP_TILESET]              ; b = current tileset (pret re-reads each iter)
    mov al, [esi]                                  ; entry tileset (hl→tile1)
    inc esi
    cmp al, 0xFF
    je  .noMatch
    cmp al, bl
    je  .tilesetMatches
    inc esi                                        ; skip tile1 (hl→tile2)
.retry:
    inc esi                                        ; skip tile2 (hl→next entry)
    jmp .loop
.tilesetMatches:
    mov al, [esi]                                  ; tile1
    cmp al, dh
    je  .firstInPair
    inc esi                                        ; hl→tile2
    mov al, [esi]                                  ; tile2
    cmp al, dh
    je  .secondInPair
    jmp .retry
.firstInPair:
    inc esi                                        ; hl→tile2
    mov al, [esi]                                  ; tile2
    cmp al, cl
    je  .foundMatch
    jmp .loop                                      ; (faithful: ESI left at tile2)
.secondInPair:
    dec esi                                        ; hl→tile1
    mov al, [esi]                                  ; a = tile1 (hli)
    inc esi                                        ; hl→tile2
    cmp al, cl                                     ; compare tile1 vs front tile → sets ZF
    lea esi, [esi + 1]                             ; hl→next entry (flag-preserving inc)
    jne .loop
.foundMatch:
    stc
    ret
.noMatch:
    clc
    ret


; ---------------------------------------------------------------------------
; LoadCurrentMapView — faithful translation.
; Pret ref: home/overworld.asm:LoadCurrentMapView
;
; Reads SCREEN_BLOCK_HEIGHT×SCREEN_BLOCK_WIDTH blocks from wOverworldMap
; (starting at wCurrentTileBlockMapViewPointer) and expands each via
; DrawTileBlock into wSurroundingTiles (SURROUNDING_WIDTH×SURROUNDING_HEIGHT).
; Then adjusts for wYBlockCoord/wXBlockCoord and copies the 20×18 view to
; wTileMap.
;
; The bank-switch (BankswitchCommon) is a no-op in the flat model.
; ---------------------------------------------------------------------------
LoadCurrentMapView:
    push esi
    push edi
    push ebx
    push ecx

    ; ; TODO-HW: BankswitchCommon (flat model — no-op)

    ; DE = wCurrentTileBlockMapViewPointer (block map source ptr)
    movzx edx, word [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR]

    ; HL = ESI = wSurroundingTiles (tile write destination)
    mov esi, W_SURROUNDING_TILES

    ; B (BH) = SCREEN_BLOCK_HEIGHT outer loop count
    mov bh, SCREEN_BLOCK_HEIGHT

.row_loop:
    push esi                                       ; save row-start of wSurroundingTiles
    push edx                                       ; save row-start of block map

    mov cl, SCREEN_BLOCK_WIDTH                     ; CL = C = inner block count

.row_inner_loop:
    push ecx                                       ; push bc (saves CL=inner count)
    push edx                                       ; push de
    push esi                                       ; push hl

    ; STOPGAP (no GB equivalent — remove once map data is extended): the 40×25
    ; viewport is larger than the GB's 20×18, so a player-centered camera near a
    ; map edge reaches past wOverworldMap. wOverworldMap ($E580) sits directly
    ; above wSurroundingTiles ($E000) in WRAM, so reads above its top border land
    ; in the tile buffer and decode tile IDs as block IDs → a garbage band. Any
    ; read outside [wOverworldMap, wOverworldMapEnd) instead yields the map's
    ; border block, so the extended/out-of-map area renders as clean dummy tiles
    ; (matching the in-bounds border) rather than garbage. See CLAUDE.md / TODO.md:
    ; the real fix is to extend map data to fill the larger viewport.
    cmp edx, W_OVERWORLD_MAP
    jb  .oobBlock
    cmp edx, W_OVERWORLD_MAP + W_OVERWORLD_MAP_SIZE
    jae .oobBlock
    movzx eax, byte [ebp + edx]                   ; A = block ID from wOverworldMap
    jmp .haveBlock
.oobBlock:
    movzx eax, byte [ebp + W_MAP_BACKGROUND_TILE] ; dummy = map border block
.haveBlock:
    mov bl, al                                     ; BL = block ID arg to DrawTileBlock (C)
    call DrawTileBlock                             ; writes 4×4 tiles to [EBP+ESI..]
                                                   ; ECX preserved by DrawTileBlock

    pop esi                                        ; pop hl (restore wSurroundingTiles ptr)
    pop edx                                        ; pop de (restore block map ptr)
    pop ecx                                        ; pop bc (restores CL=inner count)

    add esi, BLOCK_WIDTH                           ; HL += 4 (next block column in wSurroundingTiles)
    inc edx                                        ; DE++ (next block in block-map row)
    dec cl                                         ; dec C (inner count, not block ID)
    jnz .row_inner_loop

    ; Advance block-map pointer to next row
    pop edx                                        ; restore row-start of block map
    movzx eax, byte [ebp + W_CUR_MAP_WIDTH]
    add al, MAP_BORDER * 2                         ; stride = width + 6
    add edx, eax                                   ; EDX += stride (next block-map row)

    ; Advance wSurroundingTiles pointer to next block row (4 tile rows down)
    pop esi                                        ; restore row-start of wSurroundingTiles
    add esi, SURROUNDING_WIDTH * BLOCK_HEIGHT      ; ESI += 96 (= 24 * 4)

    dec bh                                         ; dec B (outer row count)
    jnz .row_loop

    ; Copy the sub-block window of wSurroundingTiles into wTileMap (the collision
    ; grid). Factored out so AdvancePlayerSprite can refresh it every step.
    call RefreshCollisionTileMap

    ; ; TODO-HW: BankswitchCommon restore (flat model — no-op)

    pop ecx
    pop ebx
    pop edi
    pop esi
    ret


; ---------------------------------------------------------------------------
; DrawTileBlock — faithful translation.
; Pret ref: home/overworld.asm:DrawTileBlock
;
; Expands one 4×4 map block into tile IDs in wSurroundingTiles.
;
; In:  ESI = write ptr in wSurroundingTiles (HL)
;      BL  = block ID (C)
; Out: ESI advanced by 4*SURROUNDING_WIDTH (past all 4 tile rows of this block)
;      BL unchanged (saved/restored by caller via push/pop ecx before call)
; Clobbers: AL, ECX (internal row counter), EDX (tile data source ptr)
; ---------------------------------------------------------------------------
DrawTileBlock:
    push ecx
    push edx

    ; Compute tile data source: [EBP + wTilesetBlocksPtr + blockID*16]
    movzx edx, word [ebp + W_TILESET_BLOCKS_PTR]  ; EDX = OW_BLOCKS_GBADDR (DE in SM83)
    movzx eax, bl                                  ; EAX = blockID (C in SM83)
    shl eax, 4                                     ; EAX = blockID * 16
    add edx, eax                                   ; EDX = pointer into blockset

    ; TEMPORARY (no GB equivalent — remove once map data is extended): clamp
    ; out-of-range block IDs to block 0 (the black/border tile). The extended
    ; 40×25-tile draw can pull the camera viewport into uninitialized
    ; wOverworldMap padding, handing us a block ID past the embedded blockset;
    ; without this the tile read walks off the blockset and paints garbage. This
    ; is a stopgap: the plan is to extend the map data so those regions hold real
    ; blocks (no blank area exists), at which point this clamp is dead code and
    ; should be deleted. See TODO.md (Phase 2) and CLAUDE.md.
    cmp edx, OW_BLOCKS_GBADDR + OVERWORLD_BLOCKS_SIZE
    jb  .block_in_range
    mov edx, OW_BLOCKS_GBADDR
.block_in_range:

    mov cl, BLOCK_HEIGHT                           ; CL = 4 (row count)

.draw_row:
    push ecx
    ; Tiles 0–2: write to [ESI] with post-increment
    mov al, byte [ebp + edx]
    mov byte [ebp + esi], al
    inc esi
    inc edx
    mov al, byte [ebp + edx]
    mov byte [ebp + esi], al
    inc esi
    inc edx
    mov al, byte [ebp + edx]
    mov byte [ebp + esi], al
    inc esi
    inc edx
    ; Tile 3: write to [ESI] without incrementing ESI (SM83: ld [hl], a)
    mov al, byte [ebp + edx]
    mov byte [ebp + esi], al
    inc edx
    ; Advance ESI to start of next tile row: +45 = SURROUNDING_WIDTH - (BLOCK_WIDTH-1)
    add esi, SURROUNDING_WIDTH - BLOCK_WIDTH + 1   ; = 48 - 4 + 1 = 45
    pop ecx
    dec cl
    jnz .draw_row

    pop edx
    pop ecx
    ret

; ---------------------------------------------------------------------------
; AreInputsSimulated — if scripted movement is active, overwrite hJoyHeld with the
; next simulated button state; otherwise leave the real joypad state untouched.
; When the simulated buffer drains, tear down all scripted-movement state.
;
; pret: home/overworld.asm:AreInputsSimulated
; In:  (BIT_SCRIPTED_MOVEMENT_STATE of wStatusFlags5), hJoyHeld, override mask
; Out: hJoyHeld (and hJoyPressed/hJoyReleased on the zero-input edge) possibly rewritten
; Clobbers: AL, BL, ESI, flags
; ---------------------------------------------------------------------------
AreInputsSimulated:
    test byte [ebp + W_STATUS_FLAGS_5], (1 << BIT_SCRIPTED_MOVEMENT_STATE)
    jz .ret                                   ; pret: bit .../ ret z — not simulating

    ; if simulating: real presses in the override mask cancel the simulation this frame
    mov bl, [ebp + H_JOY_HELD]                ; b = hJoyHeld
    mov al, [ebp + W_OVERRIDE_SIMULATED_JOYPAD_STATES_MASK]
    and al, bl
    jnz .ret                                  ; overridden -> keep real input

    call GetSimulatedInput                    ; CF=1 -> AL = next simulated state
    jnc .doneSimulating                       ; CF=0 -> buffer drained

    mov [ebp + H_JOY_HELD], al                ; inject simulated press
    test al, al
    jnz .ret                                  ; nonzero press: leave pressed/released alone
    ; a == 0 (a queued "no buttons" frame): also clear pressed/released
    mov byte [ebp + H_JOY_PRESSED], 0
    mov byte [ebp + H_JOY_RELEASED], 0
.ret:
    ret

; if done simulating button presses (pret: .doneSimulating)
.doneSimulating:
    mov byte [ebp + W_UNUSED_OVERRIDE_SIMULATED_JOYPAD_STATES_INDEX], 0
    mov byte [ebp + W_SIMULATED_JOYPAD_STATES_INDEX], 0
    mov byte [ebp + W_SIMULATED_JOYPAD_STATES_END], 0
    mov byte [ebp + W_JOY_IGNORE], 0
    mov byte [ebp + H_JOY_HELD], 0
    ; preserve only movement-flag bits 7,6,5,4,3 (SPINNING|LEDGE_OR_FISHING|5|4|3),
    ; clearing STANDING_ON_DOOR|EXITING_DOOR|STANDING_ON_WARP (bits 2,1,0). pret mask 0xF8.
    and byte [ebp + W_MOVEMENT_FLAGS], (1 << BIT_SPINNING) | (1 << BIT_LEDGE_OR_FISHING) | (1 << 5) | (1 << 4) | (1 << 3)
    and byte [ebp + W_STATUS_FLAGS_5], ~(1 << BIT_SCRIPTED_MOVEMENT_STATE)
    ret
GetSimulatedInput:
    dec byte [ebp + W_SIMULATED_JOYPAD_STATES_INDEX]
    mov al, [ebp + W_SIMULATED_JOYPAD_STATES_INDEX]
    cmp al, 0xFF                              ; wrapped past 0 -> end of simulated input
    je .endofsimulatedinputs
    movzx esi, al                             ; e = index (d = 0)
    add esi, W_SIMULATED_JOYPAD_STATES_END
    mov al, [ebp + esi]                       ; a = [wSimulatedJoypadStatesEnd + index]
    stc
    ret
.endofsimulatedinputs:
    xor al, al                               ; pret: and a — AL=0, CF=0
    ret

RunMapScript:
    ; pret: push hl / push de / push bc around the boulder step, restored before
    ; RunNPCMovementScript. TryPushingBoulder and the dust animation clobber freely.
    push esi
    push edx
    push ebx
    call TryPushingBoulder                   ; pret: farcall (banking elided)
    mov al, [ebp + wMiscFlags]
    test al, (1 << BIT_BOULDER_DUST)
    jz .afterBoulderEffect                   ; jr z — no push happened this frame
    call DoBoulderDustAnimation              ; pret: farcall (banking elided)
.afterBoulderEffect:
    pop ebx
    pop edx
    pop esi
    call RunNPCMovementScript                ; pret home/overworld.asm:1725
    ; TODO-HW: SwitchToMapRomBank — no-op under the flat address model.
    movzx ecx, byte [ebp + wCurMap]
    call dword [MapScriptPointers + ecx*4]   ; run this map's _Script (flat ptr)
    ret
LoadWalkingPlayerSpriteGraphics:
    mov byte [ebp + W_D472], 0
    mov esi, player_sprite                  ; RedSprite (walking) — DE in pret
    jmp LoadPlayerSpriteGraphicsCommon
LoadSurfingPlayerSpriteGraphics2:
    mov al, [ebp + W_D472]
    test al, al
    jz .checkPikachu                        ; d472 == 0
    dec al
    jz LoadSurfingPlayerSpriteGraphics      ; d472 == 1
    dec al
    jz .surfPikachu                         ; d472 == 2
.checkPikachu:
    test byte [ebp + W_PIKACHU_SPAWN_STATE_FLAGS], (1 << BIT_PIKACHU_SPAWN_SURFING)
    jz LoadSurfingPlayerSpriteGraphics
.surfPikachu:
    mov esi, SurfingPikachuSprite
    jmp LoadPlayerSpriteGraphicsCommon
LoadSurfingPlayerSpriteGraphics:
    mov esi, SeelSprite
    jmp LoadPlayerSpriteGraphicsCommon
LoadBikePlayerSpriteGraphics:
    mov esi, RedBikeSprite
LoadPlayerSpriteGraphicsCommon:
    mov byte [g_tilecache_dirty], 1         ; VRAM tile data changes → re-decode cache

    ; standing tiles (0-11) → OBJ $00-$0B at $8000 (vNPCSprites)
    lea edi, [ebp + GB_VCHARS0]
    mov ecx, PLAYER_HALF_BYTES
    rep movsb

    ; walking tiles (12-23) → OBJ $80-$8B at $8800 (vChars1; shares vFont)
    ; ESI is already at source+$C0 after the first copy (pret: add e,$C0).
    lea edi, [ebp + GB_VFONT]
    mov ecx, PLAYER_HALF_BYTES
    rep movsb
    ret


; (IsTilePassable moved to its pret mirror home/copy2.asm as the trampoline to
;  _IsTilePassable, whose body now lives at ITS pret mirror
;  engine/gfx/sprite_oam.asm — relocated-labels grind, 2026-07-24.)

; ---------------------------------------------------------------------------
; LoadMapHeader — faithful translation.
; Pret ref: home/overworld.asm:LoadMapHeader
; ---------------------------------------------------------------------------
LoadMapHeader:
    push eax
    push ebx
    push ecx
    push esi
    push edi

    ; pret: farcall MarkTownVisitedAndLoadToggleableObjects (mark this town visited on
    ; the town map + load per-map toggleable-object visibility flags).
    ; TODO(faithful): not ported — the town-map visited-flag set and the hidden/toggleable
    ; object show-flag load aren't implemented yet (cf. InitToggleableObjectFlags scaffold,
    ; map_sprites.asm). Harmless for the current maps; restore with the town-map subsystem.

    ; pret: ld a,[wCurMapTileset] / ld b,a / res BIT_NO_PREVIOUS_MAP,a /
    ;       ld [wCurMapTileset],a / ldh [hPreviousTileset],a.
    ; Snapshot the previous map's tileset into hPreviousTileset BEFORE the header copy
    ; below overwrites wCurMapTileset (= wCurMapHeader first byte, 0xD366) with the new
    ; map's tileset. LoadTilesetHeader (tail of this routine) compares the two to decide
    ; whether to run the warp-arrival block-coord alignment: without this snapshot its
    ; "tileset unchanged" gate reads a stale value and the alignment fires on every load,
    ; shifting the sub-block viewport.
    ; BIT_NO_PREVIOUS_MAP (bit 7) is set by the save-load path (save.asm) to mean "this
    ; map is already loaded". pret res's it here and snapshots the CLEARED value; the
    ; res is zero-behavior on the current paths (the header copy below already overwrites
    ; wCurMapTileset), but keeping it faithful avoids a stale bit-7 leaking into
    ; hPreviousTileset. The 0xFF8B HRAM byte is a union with hMapStride/
    ; hNSConnectionStripWidth, written only later during LoadCurrentMapView / connection-
    ; strip drawing — never between here and the LoadTilesetHeader read — so it is safe.
    mov al, [ebp + W_CUR_MAP_TILESET]
    mov bl, al                              ; b = full tileset (incl. BIT_NO_PREVIOUS_MAP)
    and al, ~(1 << BIT_NO_PREVIOUS_MAP)     ; res BIT_NO_PREVIOUS_MAP
    mov [ebp + W_CUR_MAP_TILESET], al
    mov [ebp + H_PREVIOUS_TILESET], al
    ; pret: bit BIT_NO_PREVIOUS_MAP,b / ret nz — if the map is already loaded (bit was
    ; set), skip the whole header reload.
    ; TODO(OW-A.5/verify): the early return is DEFERRED. All 3 FRAME.BIN baselines exercise
    ; this routine with the bit CLEAR, so they cannot prove the bit-set path; that path is
    ; only reached after a continue-from-save, and skipping the header reload there would
    ; break the map if the port's .dsv restore does not repopulate wCurMapHeader (it does
    ; not today). Restore the `ret nz` once the save/continue flow can be driven live
    ; (MCP) and verified — same conservatism as OW-A.4(b). Faithful code:
    ;     test bl, (1 << BIT_NO_PREVIOUS_MAP)
    ;     jnz .noPreviousMapReturn   ; pop edi/esi/ecx/ebx/eax ; ret

    ; W_CUR_MAP_HEADER is a 10-byte buffer: tileset(1), h(1), w(1), blkptr(2), txtptr(2), scrptr(2), conn(1)
    movzx eax, byte [ebp + W_CUR_MAP]
    add eax, eax ; * 2 (MapHeaderPointers table is 2 bytes per entry)
    mov esi, MapHeaderPointers
    movzx ebx, word [esi + eax]
    add ebx, ebp ; EBX = address of map header in flat space (rom window)
    
    ; Copy 10 bytes to W_CUR_MAP_HEADER
    mov esi, ebx
    lea edi, [ebp + W_CUR_MAP_HEADER]
    mov ecx, W_CUR_MAP_HEADER_SIZE
    rep movsb
    
    ; Initialize all 4 connected maps to $FF (disabled) before loading actual values.
    ; Faithful to pret: home/overworld.asm line 1820-1825.
    ; Without this, stale connection data from the previous map persists.
    mov byte [ebp + W_NORTH_CONNECTED_MAP], MAP_NO_CONNECTION
    mov byte [ebp + W_SOUTH_CONNECTED_MAP], MAP_NO_CONNECTION
    mov byte [ebp + W_WEST_CONNECTED_MAP],  MAP_NO_CONNECTION
    mov byte [ebp + W_EAST_CONNECTED_MAP],  MAP_NO_CONNECTION
    
    ; ESI now points past the 10-byte header. Check connections bitmask.
    mov al, [ebp + W_CUR_MAP_CONNECTIONS]
    test al, CONNECTION_NORTH
    jz .noNorth
    mov edi, W_NORTH_CONNECTED_MAP
    call CopyMapConnectionHeader
.noNorth:
    mov al, [ebp + W_CUR_MAP_CONNECTIONS]
    test al, CONNECTION_SOUTH
    jz .noSouth
    mov edi, W_SOUTH_CONNECTED_MAP
    call CopyMapConnectionHeader
.noSouth:
    mov al, [ebp + W_CUR_MAP_CONNECTIONS]
    test al, CONNECTION_WEST
    jz .noWest
    mov edi, W_WEST_CONNECTED_MAP
    call CopyMapConnectionHeader
.noWest:
    mov al, [ebp + W_CUR_MAP_CONNECTIONS]
    test al, CONNECTION_EAST
    jz .noEast
    mov edi, W_EAST_CONNECTED_MAP
    call CopyMapConnectionHeader
.noEast:

    ; ESI now points to object_data_ptr
    movzx eax, word [esi]
    add eax, ebp ; EAX = object data flat address
    
    ; Read border block
    mov bl, [eax]
    mov [ebp + W_MAP_BACKGROUND_TILE], bl
    inc eax
    
    ; Copy warps to W_WARP_ENTRIES
    mov bl, [eax]
    mov [ebp + W_NUMBER_OF_WARPS], bl
    inc eax
    movzx ecx, bl
    shl ecx, 2                          ; * 4 bytes per warp entry
    mov esi, eax
    lea edi, [ebp + W_WARP_ENTRIES]
    rep movsb                           ; copy all warp entries to WRAM
    mov eax, esi                        ; advance EAX past copied warp bytes
    
    ; Signs: store the count, then copy the sign block into WRAM.
    ; Pret ref: home/overworld.asm:LoadMapHeader (.loadSignData) + CopySignData.
    ; Per sign (3 bytes): Y, X, textID.  Y/X -> wSignCoords (interleaved pairs),
    ; textID -> wSignTextIDs.  When wNumSigns == 0 the copy is skipped and the
    ; cursor advance adds 0, so a sign-less map is byte-identical to before.
    extern CopySignData                 ; src/home/hidden_events.asm
    mov bl, [eax]
    mov [ebp + W_NUM_SIGNS], bl
    inc eax                             ; EAX -> first sign entry (flat address)
    test bl, bl
    jz .noSigns
    mov esi, eax                        ; ESI = flat src of the sign block
    call CopySignData                   ; copies wNumSigns*3 bytes; preserves EAX
.noSigns:
    movzx ebx, byte [ebp + W_NUM_SIGNS]
    lea ebx, [ebx + ebx * 2]           ; * 3 bytes per sign
    add eax, ebx                        ; advance cursor past the sign block
    
    ; Save object data pointer temp
    sub eax, ebp
    mov [ebp + W_OBJECT_DATA_PTR_TEMP], ax

    ; pret home/overworld.asm:1888-1892 (.loadSpriteData): populate the NPC sprite
    ; slots from the map-object binary, UNLESS returning from a battle/blackout
    ; (that data survives a battle, so it isn't rebuilt). W_OBJECT_DATA_PTR_TEMP
    ; (just set above) points at the sprite_count byte = pret's HL on InitSprites entry.
    ; OW-A.2 P3b: this is the faithful home object-loader; the bespoke InitMapSprites
    ; (still the driver until P3c) clears+repopulates the same slots afterward in
    ; LoadMapData, so this is currently redundant-but-harmless (byte-identical).
    mov al, [ebp + W_STATUS_FLAGS_4]
    test al, (1 << BIT_BATTLE_OVER_OR_BLACKOUT)
    jnz .skipInitSprites
    call InitSprites
.skipInitSprites:

    call LoadTilesetHeader

    ; pret: (gated on !BIT_BATTLE_OVER_OR_BLACKOUT) callfar SchedulePikachuSpawnForAfterText —
    ; queue the Pikachu-follower spawn to appear after the next text box.
    ; TODO(faithful): not ported (Pikachu-follower subsystem absent; cf. SpawnPikachu stub).

    ; Load this map's wild-encounter data (pret home/overworld.asm:LoadMapHeader:1900,
    ; callfar LoadWildData). Populates wGrassRate/wGrassMons + wWaterRate/wWaterMons from
    ; WildDataPointers[wCurMap] for TryDoWildEncounter. OW-A.5: previously LoadWildData had
    ; ZERO call sites, so every map's wild slots were stale. LoadWildData clobbers only
    ; EAX/ECX/EDX/ESI (no banking, no I/O), all of which the pops below restore, so it is
    ; safe here.
    call LoadWildData

    ; pret next doubles wCurMapHeight/Width -> wCurrentMapHeight2/Width2 (:1902-1907).
    ; DIVERGENCE (verified safe): the port derives those in CheckMapConnections (its ONLY
    ; consumer), at the top of that routine (set-before-use) — every read of
    ; W_CURRENT_MAP_HEIGHT_2/WIDTH_2 is inside CheckMapConnections, after the set — so
    ; LoadMapHeader does not need to compute them here.
    ; pret LoadMapHeader:1908-1923: load this map's default music (id, ROM bank) from
    ; MapSongBanks[wCurMap] into wMapMusicSoundID/wMapMusicROMBank. PlayDefaultMusic (the
    ; LoadMapData tail + connection crossing) plays it. Real now (OW-A.14); the pops below
    ; restore eax/esi. Flat model: MapSongBanks is a host-address label, stride 2.
    movzx eax, byte [ebp + W_CUR_MAP]
    lea esi, [MapSongBanks + eax*2]
    mov al, [esi]
    mov [ebp + wMapMusicSoundID], al            ; music 1
    mov al, [esi + 1]
    mov [ebp + wMapMusicROMBank], al            ; music 2

    pop edi
    pop esi
    pop ecx
    pop ebx
    pop eax
    ret


CopyMapConnectionHeader:
    push ecx
    push edi
    add edi, ebp
    mov ecx, CONN_HEADER_SIZE
    rep movsb
    pop edi
    pop ecx
    ret

; ---------------------------------------------------------------------------
; CopySignData — copy the map header's sign block into WRAM.
; Pret ref: home/overworld.asm:CopySignData
;
; In:  ESI = flat (ebp-relative absolute) pointer to the sign block; each sign is
;            3 bytes: Y, X, textID.
;      [W_NUM_SIGNS] = number of signs (caller guarantees >= 1).
; Out: wSignCoords   <- interleaved (Y, X) pairs.
;      wSignTextIDs  <- one textID per sign.
;      ESI advanced past the block.
; Preserves EAX (LoadMapHeader keeps its header cursor there) + EBX/ECX/EDI.
; ---------------------------------------------------------------------------
CopySignData:
    push eax
    push ebx
    push ecx
    push edi
    lea edi, [ebp + W_SIGN_COORDS]      ; de = wSignCoords
    lea ebx, [ebp + W_SIGN_TEXT_IDS]    ; bc = wSignTextIDs
    movzx ecx, byte [ebp + W_NUM_SIGNS]
.loop:
    mov al, [esi]                       ; sign Y
    inc esi
    mov [edi], al
    inc edi
    mov al, [esi]                       ; sign X
    inc esi
    mov [edi], al
    inc edi
    mov al, [esi]                       ; sign textID
    inc esi
    mov [ebx], al
    inc ebx
    dec ecx
    jnz .loop
    pop edi
    pop ecx
    pop ebx
    pop eax
    ret

; ---------------------------------------------------------------------------
; LoadMapData — faithful translation.
; Pret ref: home/overworld.asm:LoadMapData
; ---------------------------------------------------------------------------
LoadMapData:
    call DisableLCD
    call ResetMapVariables
    call LoadTextBoxTilePatterns
    call LoadMapHeader
    ; Dispatch per-map text table: MapTextTablePointers[W_CUR_MAP] → w_map_text_table_ptr.
    movzx eax, byte [ebp + W_CUR_MAP]
    lea esi, [MapTextTablePointers]
    mov esi, [esi + eax*4]
    mov [w_map_text_table_ptr], esi
    call InitMapSprites                 ; pret: InitMapSprites (load sprite tile patterns)
    ; OW-A.5: pret calls LoadScreenRelatedData ONCE (home/overworld.asm:1967) then
    ; CopyMapViewToVRAM. The port's LoadScreenRelatedData (LoadTileBlockMap +
    ; LoadTilesetTilePatternData + LoadCurrentMapView) is idempotent and its
    ; LoadCurrentMapView is the native-render equivalent of pret's trailing
    ; CopyMapViewToVRAM, so one call covers both. (Removed a redundant second call.)
    call LoadScreenRelatedData

    mov byte [ebp + W_UPDATE_SPRITES_ENABLED], 1
    call EnableLCD
    call GBPalNormal
    mov bh, SET_PAL_OVERWORLD
    call RunPaletteCommand
    call LoadPlayerSpriteGraphics       ; pret: LoadPlayerSpriteGraphics (:1972)
    ; pret tail (:1975-1985): play this map's default music unless we entered via a
    ; dungeon/fly warp (DUNGEON_WARP|FLY_WARP) or the map suppresses it (NO_MAP_MUSIC).
    ; Bank save/restore around it is a no-op in the flat model. Real now (OW-A.14).
    test byte [ebp + W_STATUS_FLAGS_6], (1 << BIT_DUNGEON_WARP) | (1 << BIT_FLY_WARP)
    jnz .noMapMusic
    test byte [ebp + W_STATUS_FLAGS_7], (1 << BIT_NO_MAP_MUSIC)
    jnz .noMapMusic
    call UpdateMusic6Times
    call PlayDefaultMusicFadeOutCurrent
.noMapMusic:
    ret


; ---------------------------------------------------------------------------
; LoadScreenRelatedData — faithful translation.
; Pret ref: home/overworld.asm:LoadScreenRelatedData
; ---------------------------------------------------------------------------
LoadScreenRelatedData:
    call LoadTileBlockMap
    call LoadTilesetTilePatternData
    call LoadCurrentMapView
    ret


; LoadPlayerSpriteGraphics — RETIRED from this file (wild-live promotion).
; The Phase-2 scaffold that lived here (walking-only, standing tiles → $8000 /
; walking tiles → $8800, plus a `call ClearSprites`) is superseded by the
; faithful pret dispatcher now linked from engine/overworld/player_gfx.asm
; (LoadPlayerSpriteGraphics → Walking/Bike/Surfing → LoadPlayerSpriteGraphicsCommon).
; Same VRAM layout; the scaffold's extra ClearSprites is intentionally NOT carried
; over — pret's LoadPlayerSpriteGraphicsCommon (home/overworld.asm:1775) does not
; clear OAM, and neither does pret's LoadMapData. `player_sprite` (pret RedSprite)
; stays defined here and is exported for player_gfx.asm.

; ---------------------------------------------------------------------------
; ResetMapVariables — faithful translation.
; Pret ref: home/overworld.asm:ResetMapVariables
;
; Sets wMapViewVRAMPointer = vBGMap0 ($9800 → port GB_TILEMAP0), zeroes SCX/SCY
; and walk state.
; ---------------------------------------------------------------------------
ResetMapVariables:
    ; pret home/overworld.asm:2024-2027 — wMapViewVRAMPointer = vBGMap0. Vestigial under
    ; the native-width renderer (dropped/unused; the torus rings are gone), but kept in
    ; lockstep with the other reset sites (EnterMapBoot etc. write GB_TILEMAP0) so the
    ; pointer is never left stale, matching pret's byte-for-byte reset here.
    mov word [ebp + W_MAP_VIEW_VRAM_POINTER], GB_TILEMAP0
    xor al, al
    mov byte [ebp + H_SCY],                       al
    mov byte [ebp + H_SCX],                       al
    mov byte [ebp + W_WALK_COUNTER],              al
    mov byte [ebp + W_UNUSED_CUR_MAP_TILESET_COPY], al
    mov byte [ebp + W_SPRITE_SET_ID],             al
    mov byte [ebp + W_WALK_BIKE_SURF_STATE_COPY], al
    ; Empty the window list on map entry: visibility is count-driven now, so this
    ; guarantees no stale box leaks over the overworld (e.g. the title's
    ; go_to_main_menu path). Dialog/menu code re-populates the list when it opens a
    ; box. The rWY/rWX shadows are parked off-screen for faithfulness.
    call hide_window                    ; count=0; sets H_WY = RENDER_H
    mov byte [ebp + IO_WY], RENDER_H
    mov byte [ebp + IO_WX], 7
    ret

SwitchToMapRomBank:
    call BankswitchCommon                        ; record AL in hLoadedROMBank (flat no-op MBC)
    ret

global IsSpriteOrSignInFrontOfPlayer         ; A-press dispatch head (overworld.asm)
global IsSpriteInFrontOfPlayer               ; sprite scan — TryPushingBoulder (push_boulder.asm)
global IsSpriteInFrontOfPlayer2              ; long-range entry — counter branch above; Surf open

; ---------------------------------------------------------------------------
; IsSpriteInFrontOfPlayer / IsSpriteInFrontOfPlayer2 — detect-only sprite scan.
; Pret ref: home/overworld.asm:IsSpriteInFrontOfPlayer (:1084-1175)
;
; Finds the sprite (if any) standing at the pixel position the player faces, sets
; BIT_FACE_PLAYER on it, and reports its SLOT in [hSpriteIndex]. pret's two labels
; are one routine with two entry points: IsSpriteInFrontOfPlayer presets the normal
; $10-pixel talking range, IsSpriteInFrontOfPlayer2 expects the caller to have set
; DH (the long $20 range used over pokécenter/mart counter tiles). Both labels are
; kept, per CLAUDE.md's rule on structural splits.
;
; STRUCTURAL SPLIT — this is the SECOND realization of pret's sprite scan, and that
; is deliberate. The port already has IsNPCAtTargetBlock (map_sprites.asm), a
; bespoke MAPY/MAPX *block* scan used by CollisionCheckOnLand (see its note at
; pret :1234). The two are NOT interchangeable:
;   - IsNPCAtTargetBlock answers "is a block occupied" for collision, in map coords.
;   - This answers "which slot is at the faced PIXEL position", in screen coords,
;     with the BIT_FACE_PLAYER side effect and the hSpriteIndex hand-off that
;     TryPushingBoulder's boulder identification depends on.
; Rewiring CollisionCheckOnLand onto this routine is deliberately NOT done here: it
; would change live collision behavior, which this bullet does not own. The port
; therefore keeps pret's name on this half and IsNPCAtTargetBlock's on the other.
;
; CONSUMERS: TryPushingBoulder (push_boulder.asm), and the
; IsSpriteOrSignInFrontOfPlayer head above (counter branch → the -2 entry,
; no-counter fallthrough → the normal entry). ItemUseSurfboard's -2 check at
; pret engine/items/item_effects.asm:725 is still open (Stage 4 Surf bullet,
; which lists "supply IsSpriteInFrontOfPlayer2" as its dependency).
;
; Register map: a=AL, b=BH (player Y), c=BL (player X), d=DH, e=DL, hl=ESI.
; pret reuses D: it is the talking RANGE until .doneCheckingDirection, then the
; loop COUNTER. That reuse is preserved here rather than tidied away.
;
; Out: CF=1 and [hSpriteIndex] = slot (1-15) if a sprite faces the player;
;      CF=0 and AL=0 otherwise ([hSpriteIndex] is left alone — pret makes the
;      CALLER zero it first, and TryPushingBoulder does exactly that).
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; IsSpriteOrSignInFrontOfPlayer — pret home/overworld.asm:IsSpriteOrSignInFrontOfPlayer.
; The A-press interaction head: sign lookup first, then the counter-tile
; talking-range extension, then FALLS THROUGH into the sprite scan below —
; pret has no ret between the counter loop and IsSpriteInFrontOfPlayer, and
; that fallthrough is load-bearing: do not insert anything between them.
;
; Leaves the found id in [hTextID] (== [hSpriteIndex] — same HRAM byte, the
; linchpin of pret's contract): SignLoop stores the sign's text id, the sprite
; scan stores the slot number. Out: CF=1 if a sign or sprite faces the player;
; CF=0 and [hTextID]=0 otherwise. The caller distinguishes sign vs sprite by
; id <= [wNumSprites] (pret DisplayTextID's rule) and zeroes wd435 first
; (pret OverworldLoop does both).
;
; A counter-tile match enters the scan at IsSpriteInFrontOfPlayer2 with
; DH = $20 (two-tile range) still live — that is the entire effect of the
; counter branch: at a mart/center counter you can talk to the clerk one tile
; behind it. wTilesetTalkingOverTiles is loaded per-map by LoadTilesetHeader.
; ---------------------------------------------------------------------------
ForceBikeOrSurf:
    call LoadPlayerSpriteGraphics
    jmp PlayDefaultMusic                     ; pret: jp PlayDefaultMusic (tail call)
HandleMidJump:
    test byte [ebp + W_MOVEMENT_FLAGS], (1 << BIT_LEDGE_OR_FISHING)
    jz  .ret
    call _HandleMidJump
.ret:
    ret

global InitSprites
global ZeroSpriteStateData
global DisableRegularSprites
global LoadSprite

InitSprites:
    pushad
    ; A = [wNumSprites source] = sprite_count byte; ESI advances past it.
    ; W_OBJECT_DATA_PTR_TEMP holds the GB offset of the sprite_count byte.
    movzx esi, word [ebp + W_OBJECT_DATA_PTR_TEMP]   ; ESI = GB addr of sprite_count
    movzx eax, byte [ebp + esi]
    mov [ebp + wNumSprites], al                       ; wNumSprites = count
    inc esi                                            ; past the count byte
    call ZeroSpriteStateData
    call DisableRegularSprites
    ; zero wMapSpriteData ($20 bytes) — pret: ld hl,wMapSpriteData; ld bc,$20; FillMemory
    mov edi, wMapSpriteData
    xor al, al
    mov ecx, 0x20
    rep stosb
    ; any sprites?
    movzx eax, byte [ebp + wNumSprites]
    test al, al
    jz .done
    mov ebx, eax                                       ; EBX = count remaining (pret B)
    mov edx, 0x10                                       ; EDX = slot byte offset (slot 1)
    xor edi, edi                                        ; EDI = wMapSpriteData index (pret C): 0,2,4,...
.loadSpriteLoop:
    ; picture id -> x#SPRITESTATEDATA1_PICTUREID
    movzx eax, byte [ebp + esi]
    inc esi
    mov [ebp + edx + W_SPRITE_STATE_DATA_1 + SPRITESTATEDATA1_PICTUREID], al
    ; mapy -> x#SPRITESTATEDATA2_MAPY
    movzx eax, byte [ebp + esi]
    inc esi
    mov [ebp + edx + W_SPRITE_STATE_DATA_2 + SPRITESTATEDATA2_MAPY], al
    ; mapx -> x#SPRITESTATEDATA2_MAPX
    movzx eax, byte [ebp + esi]
    inc esi
    mov [ebp + edx + W_SPRITE_STATE_DATA_2 + SPRITESTATEDATA2_MAPX], al
    ; movement byte 1 -> x#SPRITESTATEDATA2_MOVEMENTBYTE1
    movzx eax, byte [ebp + esi]
    inc esi
    mov [ebp + edx + W_SPRITE_STATE_DATA_2 + SPRITESTATEDATA2_MOVEMENTBYTE1], al
    ; movement byte 2 -> temp1
    movzx eax, byte [ebp + esi]
    inc esi
    mov [h_load_sprite_temp1], al
    ; text id + flags -> temp2
    movzx eax, byte [ebp + esi]
    inc esi
    mov [h_load_sprite_temp2], al
    ; DIVERGENCE (port ext): set the per-slot ISTRAINER flag (SPRITESTATEDATA2 0x0A)
    ; that the port interaction stack (CheckNPCInteraction / CheckTrainerSight /
    ; TrainerEncounterFlow) reads. pret has no such field — it re-derives trainer-ness
    ; from the text-id flags at interaction time, in the SPRITE branch of
    ; IsSpriteOrSignInFrontOfPlayer (the branch the port realizes as CheckNPCInteraction;
    ; the sign branch itself is ported, below).
    ; The bespoke InitMapSprites used to set this; it is retired in P3c, so InitSprites
    ; (the slot populator) carries it. ZeroSpriteStateData already cleared the slot.
    test al, TRAINER_FLAG
    jz .not_trainer_slot
    mov byte [ebp + edx + W_SPRITE_STATE_DATA_2 + SPRITESTATEDATA2_ISTRAINER], 1
.not_trainer_slot:
    ; LoadSprite: ECX = wMapSpriteData index; ESI = read ptr (advanced past any
    ; trainer/item extra bytes on return). It preserves EBX/EDX/EDI and clobbers EAX.
    mov ecx, edi
    call LoadSprite
    ; advance to next sprite: slot offset += $10, wMapSpriteData index += 2, count--
    add edx, 0x10
    add edi, 2
    dec ebx
    jnz .loadSpriteLoop
.done:
    popad
    ret


; Zero sprite state data for slots 1-14 (slot 15 is Pikachu, left intact — pret).
ZeroSpriteStateData:
    push eax
    push ecx
    push edi
    xor al, al
    lea edi, [ebp + W_SPRITE_STATE_DATA_1 + 0x10]      ; slot 1
    mov ecx, 14 * 0x10
    rep stosb
    lea edi, [ebp + W_SPRITE_STATE_DATA_2 + 0x10]
    mov ecx, 14 * 0x10
    rep stosb
    pop edi
    pop ecx
    pop eax
    ret


; Disable regular sprites: SPRITESTATEDATA1_IMAGEINDEX for slots 1-14.
; DIVERGENCE (harness-only; zero real-game effect): pret writes $ff here — a
; "hidden until initialized" marker. This seed is IRRELEVANT to the running game:
; the first UpdateSprites frame calls InitializeSpriteStatus (movement.asm:727),
; which unconditionally overwrites IMAGEINDEX with $ff; the second frame's
; CheckSpriteAvailability → UpdateSpriteImage then computes the real facing index.
; So under the live game (EnterMap + OverworldLoop both run UpdateSprites) a $ff or
; a 0 seed here behave identically. The seed ONLY changes the STATIC pre-UpdateSprites
; DEBUG-harness snapshot (DEBUG_BASELINE etc. render without running UpdateSprites):
; $ff hides the NPCs there, 0 (the ZeroSpriteStateData value → facing-down anim-0)
; shows them. We keep 0 so that regression snapshot still exercises NPC rendering.
; Restoring the faithful $ff needs the DEBUG harness to run UpdateSprites like EnterMap
; — but on frame 2 the port's random-movement path makes a WALK NPC try to move
; immediately (no initial move-delay), so it also needs pret's move-delay/probability
; ported (movement-engine work, OW-A.7 territory) to keep the snapshot deterministic.
DisableRegularSprites:
    push ecx
    push esi
    mov esi, 0x10                                       ; slot 1
    mov ecx, 14
.loop:
    mov byte [ebp + esi + W_SPRITE_STATE_DATA_1 + SPRITESTATEDATA1_IMAGEINDEX], 0
    add esi, 0x10
    dec ecx
    jnz .loop
    pop esi
    pop ecx
    ret


; LoadSprite (pret home/overworld.asm:2218). In: ECX = wMapSpriteData/ExtraData byte
; index ((slot-1)*2); ESI = GB read ptr just past the text-id byte; temp1 = movement
; byte 2, temp2 = text id + flags. Out: ESI advanced past trainer/item extra bytes.
; Preserves EBX/ECX/EDX/EDI; clobbers EAX.
LoadSprite:
    push eax
    ; wMapSpriteData[C] = movement byte 2
    mov al, [h_load_sprite_temp1]
    mov [wMapSpriteData + ecx], al
    ; pret writes text id+flags to [C+1] here then immediately overwrites it with the
    ; masked value — kept for faithfulness ("this appears pointless").
    mov al, [h_load_sprite_temp2]
    mov [wMapSpriteData + ecx + 1], al
    mov al, [h_load_sprite_temp2]
    mov [h_load_sprite_temp1], al                       ; temp1 = text id+flags (save for flag test)
    and al, 0x3f
    mov [wMapSpriteData + ecx + 1], al                  ; wMapSpriteData[C+1] = masked text id
    ; branch on the raw (unmasked) text-id+flags byte
    mov al, [h_load_sprite_temp1]
    test al, TRAINER_FLAG
    jnz .trainerSprite
    test al, ITEM_FLAG
    jnz .itemBallSprite
    ; regular sprite: zero both wMapSpriteExtraData bytes
    mov word [wMapSpriteExtraData + ecx], 0
    pop eax
    ret
.trainerSprite:
    movzx eax, byte [ebp + esi]                         ; trainer class
    inc esi
    mov [h_load_sprite_temp1], al
    movzx eax, byte [ebp + esi]                         ; trainer number
    inc esi
    mov [h_load_sprite_temp2], al
    mov al, [h_load_sprite_temp1]
    mov [wMapSpriteExtraData + ecx], al                 ; ExtraData[C] = trainer class
    mov al, [h_load_sprite_temp2]
    mov [wMapSpriteExtraData + ecx + 1], al             ; ExtraData[C+1] = trainer number
    pop eax
    ret
.itemBallSprite:
    movzx eax, byte [ebp + esi]                         ; item number
    inc esi
    mov [h_load_sprite_temp1], al
    mov al, [h_load_sprite_temp1]
    mov [wMapSpriteExtraData + ecx], al                 ; ExtraData[C] = item number
    mov byte [wMapSpriteExtraData + ecx + 1], 0         ; ExtraData[C+1] = 0
    pop eax
    ret

CheckForUserInterruption:
    call DelayFrame
    push ebx                          ; pret push bc — preserve the frame counter
    call JoypadLowSensitivity
    pop ebx
    mov al, [ebp + H_JOY_HELD]        ; ldh a, [hJoyHeld]
    cmp al, PAD_UP + PAD_SELECT + PAD_B   ; exactly Up+Select+B (the skip combo)
    je .input
    mov al, [ebp + H_JOY5]            ; ldh a, [hJoy5]
    and al, PAD_START | PAD_A         ; release build (pret _DEBUG also allows Select)
    jnz .input
    dec bl                            ; dec c
    jnz CheckForUserInterruption      ; jr nz — loop for the remaining frames
    and al, al                        ; pret `and a` — clear CF (no interruption)
    ret
.input:
    stc                               ; scf
    ret

; ---------------------------------------------------------------------------
; SwitchToMapRomBank — set the ROM bank for the current map's data/scripts.
; pret home/overworld.asm:SwitchToMapRomBank: reads the map's bank from
; MapHeaderBanks and BankswitchCommon-s to it. Flat-model: record the requested
; bank (bookkeeping); the physical MBC write is a no-op. Consumers (reload_tiles,
; text_script, run_map_script) keep the pret call structure.
; In: AL = map bank id. All other registers preserved.
; ---------------------------------------------------------------------------
global SwitchToMapRomBank

; ---------------------------------------------------------------------------
; LoadDestinationWarpPosition — load spawn Y/X from the destination map's warp
; table entry selected by W_DESTINATION_WARP_ID.
; Pret ref: home/overworld.asm:LoadDestinationWarpPosition
; PROJ divergence: pret's predef version copies a 4-byte (block-view-pointer,
; Y, X) struct from an hl-indexed ROM table straight into
; wCurrentTileBlockMapViewPointer/wYCoord/wXCoord. The port has no parallel
; per-map view-pointer table; it reads Y/X directly out of the already-loaded
; W_WARP_ENTRIES (Y, X, dest_warp_id, dest_map_id per entry — see the
; `warp_event` macro / CheckWarpTile), and leaves wCurrentTileBlockMapViewPointer
; to LoadWarpDestination's explicit stride-math recompute, which replaces
; pret's ROM view-pointer lookup with an equivalent runtime computation.
; In:  W_DESTINATION_WARP_ID = 0-based warp index (destination map's table)
; Out: W_Y_COORD, W_X_COORD set. Preserves all other registers/flags.
; ---------------------------------------------------------------------------
LoadDestinationWarpPosition:
    push eax
    push esi

    movzx eax, byte [ebp + W_DESTINATION_WARP_ID]
    shl eax, 2                          ; * 4 bytes per warp entry
    lea esi, [ebp + W_WARP_ENTRIES]
    add esi, eax
    mov al, [esi]                       ; spawn Y tile
    mov [ebp + W_Y_COORD], al
    mov al, [esi+1]                     ; spawn X tile
    mov [ebp + W_X_COORD], al

    pop esi
    pop eax
    ret


