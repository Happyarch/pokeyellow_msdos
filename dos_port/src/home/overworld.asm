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
