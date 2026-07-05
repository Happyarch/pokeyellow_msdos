; warp_check.asm — faithful ExtraWarpCheck function-1/function-2 dispatch.
;
; M7.4 (docs/current_plan_home_rectification.md, Wave 7). Restores pret's
; per-map dispatch that the port had collapsed into a hardcoded "facing DOWN on
; a warp" test in OverworldLoop's collision-exit path.
;
; Faithful translations (pret cross-reference maintained):
;   ExtraWarpCheck            home/overworld.asm:ExtraWarpCheck
;   IsPlayerFacingEdgeOfMap   engine/overworld/player_state.asm:IsPlayerFacingEdgeOfMap  (function 1)
;   IsWarpTileInFrontOfPlayer engine/overworld/player_state.asm:IsWarpTileInFrontOfPlayer (function 2)
;   CheckIfInOutsideMap       home/overworld.asm:CheckIfInOutsideMap
;   WarpTileListPointers/…    data/tilesets/warp_carpet_tile_ids.asm
;
; Build: nasm -f coff -I include/ -I . -o warp_check.o \
;              src/engine/overworld/warp_check.asm
;
; ---------------------------------------------------------------------------
; LINK status: LINK (live). Called by the collision-exit path in
; src/engine/overworld/overworld.asm (OverworldLoop .walkStart). Add to the
; Phase-2 SRCS list in dos_port/Makefile, right after overworld.asm:
;       src/engine/overworld/warp_check.asm \
; ---------------------------------------------------------------------------

bits 32

%include "gb_memmap.inc"

; --- Tileset IDs (constants/tileset_constants.asm) ------------------------
; The port's gb_constants.inc does not (yet) define these; kept local. OVERWORLD
; is 0 (tested via `test al,al`), so only the non-zero ones need symbols.
TILESET_SHIP        equ 13          ; S.S. Anne interior
TILESET_SHIP_PORT   equ 14          ; Vermilion Port
TILESET_PLATEAU     equ 23          ; Route 23 / Indigo Plateau

; --- Map IDs (constants/map_constants.asm) --------------------------------
; These maps are not yet in the port's map set, so their branches simply never
; match today — but wiring them now is faithful and future-proof.
MAP_ROCK_TUNNEL_1F      equ 0x52
MAP_SS_ANNE_3F          equ 0x61
MAP_ROCKET_HIDEOUT_B1F  equ 0xC7
MAP_ROCKET_HIDEOUT_B2F  equ 0xC8
MAP_ROCKET_HIDEOUT_B4F  equ 0xCA

extern IsInArray                    ; src/home/array.asm — $FF-terminated flat search

global ExtraWarpCheck
global CheckIfInOutsideMap

section .text

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

; ---------------------------------------------------------------------------
; IsPlayerFacingEdgeOfMap (function 1)
; pret: engine/overworld/player_state.asm:IsPlayerFacingEdgeOfMap
;   facingDown : (wCurMapHeight*2 - 1) == wYCoord  → carry
;   facingUp   : wYCoord == 0                       → carry
;   facingLeft : wXCoord == 0                       → carry
;   facingRight: (wCurMapWidth*2  - 1) == wXCoord  → carry
; Out: CF=1 at the outward-facing edge, else CF=0.
; ---------------------------------------------------------------------------
IsPlayerFacingEdgeOfMap:
    mov al, [ebp + W_SPRITE_PLAYER_FACING_DIR]
    cmp al, SPRITE_FACING_DOWN
    je .facingDown
    cmp al, SPRITE_FACING_UP
    je .facingUp
    cmp al, SPRITE_FACING_LEFT
    je .facingLeft
.facingRight:
    movzx eax, byte [ebp + W_CUR_MAP_WIDTH]
    add al, al                      ; width*2
    dec al                          ; width*2 - 1
    cmp al, [ebp + W_X_COORD]
    je .setCarry
    jmp .resetCarry
.facingDown:
    movzx eax, byte [ebp + W_CUR_MAP_HEIGHT]
    add al, al                      ; height*2
    dec al                          ; height*2 - 1
    cmp al, [ebp + W_Y_COORD]
    je .setCarry
    jmp .resetCarry
.facingUp:
    cmp byte [ebp + W_Y_COORD], 0
    je .setCarry
    jmp .resetCarry
.facingLeft:
    cmp byte [ebp + W_X_COORD], 0
    je .setCarry
    ; fall through
.resetCarry:
    clc
    ret
.setCarry:
    stc
    ret

; ---------------------------------------------------------------------------
; IsWarpTileInFrontOfPlayer (function 2)
; pret: engine/overworld/player_state.asm:IsWarpTileInFrontOfPlayer
;
; Selects the per-facing warp-carpet tile list and scans it for the tile in
; front of the player.
;
; ; PROJ: this routine reads the already-populated wTileInFrontOfPlayer instead
; of re-fetching it. pret's version opens with `call _GetTileAndCoordsInFrontOfPlayer`
; to (re)populate wTileInFrontOfPlayer; the port relies on CollisionCheckOnLand's
; GetTileInFrontOfPlayer call, which runs immediately before ExtraWarpCheck on the
; collision-exit path (the only caller today), so the var is guaranteed fresh here.
; Reading the WRAM var is equivalent at this call site and avoids re-exporting the
; file-local GetTileInFrontOfPlayer. If a second caller is ever added that does NOT
; pre-populate wTileInFrontOfPlayer, restore the pret _GetTileAndCoordsInFrontOfPlayer
; prime here first.
;
; ; DIVERGENCE: the SS_ANNE_BOW special case is omitted. pret branches to
; IsSSAnneBowWarpTileInFrontOfPlayer when wCurMap == SS_ANNE_BOW, which treats tile
; $15 as the (single) warp tile → CF (any other tile → no carry), bypassing the
; per-facing WarpTileListPointers scan entirely. SS Anne is not in the port's map
; set yet, so the branch is unreachable and dropped.
; ; TODO(SS-Anne): when MAP_SS_ANNE_BOW lands, add `cmp [wCurMap], SS_ANNE_BOW / je`
; at entry dispatching to a ported IsSSAnneBowWarpTileInFrontOfPlayer (tile $15 → CF).
;
; Out: CF=1 if the faced tile is a warp-carpet tile, else CF=0.
; ---------------------------------------------------------------------------
IsWarpTileInFrontOfPlayer:
    movzx eax, byte [ebp + W_SPRITE_PLAYER_FACING_DIR]  ; 0,4,8,12
    shr eax, 2                                          ; → 0,1,2,3 (down/up/left/right)
    mov esi, [WarpTileListPointers + eax*4]             ; flat list pointer
    mov al, [ebp + W_TILE_IN_FRONT_OF_PLAYER]
    mov edx, 1                                          ; entry stride
    jmp IsInArray                                       ; tail call; returns CF (and this routine's ret)

; ---------------------------------------------------------------------------
; CheckIfInOutsideMap — pret home/overworld.asm:CheckIfInOutsideMap
; Sets ZF if the player is in an outside map (a town or route): tileset
; OVERWORLD (0) or PLATEAU. Provided for the faithful WarpFound2 bookkeeping in
; the port's .warpTransition path (OverworldLoop body, M7.1 — out of this lane;
; that block currently uses an equivalent `W_CUR_MAP < FIRST_INDOOR_MAP_ID`
; inline test). Global so that consumer can switch to this when it is touched.
; Out: ZF=1 if outside, else ZF=0.  Clobbers AL only.
; ---------------------------------------------------------------------------
CheckIfInOutsideMap:
    mov al, [ebp + W_CUR_MAP_TILESET]
    test al, al                     ; OVERWORLD → ZF=1
    jz .ret
    cmp al, TILESET_PLATEAU         ; PLATEAU  → ZF=1
.ret:
    ret

; ---------------------------------------------------------------------------
; Warp-carpet tile IDs — data/tilesets/warp_carpet_tile_ids.asm
; Flat .data (IsInArray uses flat [ESI] reads), each list $FF(-1)-terminated.
; ---------------------------------------------------------------------------
section .data

WarpTileListPointers:
    dd .FacingDownWarpTiles
    dd .FacingUpWarpTiles
    dd .FacingLeftWarpTiles
    dd .FacingRightWarpTiles

.FacingDownWarpTiles:
    db 0x01, 0x12, 0x17, 0x3D, 0x04, 0x18, 0x33
    db 0xFF
.FacingUpWarpTiles:
    db 0x01, 0x5C
    db 0xFF
.FacingLeftWarpTiles:
    db 0x1A, 0x4B
    db 0xFF
.FacingRightWarpTiles:
    db 0x0F, 0x4E
    db 0xFF
