; player_state.asm — engine/overworld/player_state.asm (part 1: getters).
;
; OW-1.8. Ports the "getter" half of pret's player_state.asm — the coordinate
; projection helpers, the warp/door/force-bike-or-surf predicates, and the
; Safari Zone step-counter HUD. The boulder-push half
; (CheckForCollisionWhenPushingBoulder / CheckForBoulderCollisionWithSprites)
; is explicitly OUT of scope here — deferred to OW-4.1.
;
; ALREADY PORTED ELSEWHERE — do not re-implement:
;   IsPlayerFacingEdgeOfMap    -> src/engine/overworld/warp_check.asm (function 1
;                                 of pret's ExtraWarpCheck dispatch)
;   IsWarpTileInFrontOfPlayer  -> src/engine/overworld/warp_check.asm (function 2).
;                                 Its SS_ANNE_BOW special case is intentionally
;                                 omitted there (SS Anne not yet in the port's
;                                 map set); see IsSSAnneBowWarpTileInFrontOfPlayer
;                                 below for the standalone equivalent pret ships
;                                 as a fallthrough target of that routine.
;   GetTileInFrontOfPlayer     -> src/engine/overworld/overworld.asm (simplified
;                                 translation of _GetTileAndCoordsInFrontOfPlayer's
;                                 tile-read half only, used by CollisionCheckOnLand
;                                 et al). NOT modified here. This file's
;                                 GetTileAndCoordsInFrontOfPlayer /
;                                 _GetTileAndCoordsInFrontOfPlayer are NEW
;                                 routines that reproduce pret's full behaviour
;                                 (tile read + D/E map-coord output), using the
;                                 IDENTICAL projected tile-read addresses as the
;                                 existing GetTileInFrontOfPlayer (verified below).
;   ForceBikeOrSurf            -> src/engine/overworld/player_gfx.asm (global,
;                                 but currently HOME_CHECK_SRCS / check-only —
;                                 see the CLOSURE note on CheckForceBikeOrSurf).
;   DoorTileTable / IsPlayerStandingOnDoorTile
;                              -> src/engine/overworld/overworld.asm. Reused by
;                                 IsPlayerStandingOnDoorTileOrWarpTile below via
;                                 `extern IsPlayerStandingOnDoorTile` — see the
;                                 CLOSURE note: that symbol is NOT currently
;                                 `global` in overworld.asm, so this is a link
;                                 blocker until root adds it there.
;
; Register map (asm-translation skill): A=AL, BC=BX (B=BH,C=BL), DE=DX (D=DH,
; E=DL), HL=ESI, EBP=GB memory base ([ebp+addr]). GB data is big-endian (not
; touched by anything in this file — all fields here are single bytes).
;
; Build (standalone check):
;   nasm -f coff -I dos_port/include -I dos_port -o /dev/null \
;        dos_port/src/engine/overworld/player_state.asm
;
; ===========================================================================

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

; ---------------------------------------------------------------------------
; ---- TODO(root): promote to gb_memmap.inc / gb_constants.inc ----
; Symbols not yet in the shared headers. Values verified against
; ram/wram.asm, constants/*.asm (pret, read-only spec) and cross-checked
; against `git show origin/symbols:pokeyellow.sym`.
; ---------------------------------------------------------------------------

; --- WRAM (ram/wram.asm) ---------------------------------------------------
%ifndef wSeafoamIslandsB3FCurScript
wSeafoamIslandsB3FCurScript equ 0xD665   ; ram/wram.asm:2291 (db); sym-verified
%endif
%ifndef wSeafoamIslandsB4FCurScript
wSeafoamIslandsB4FCurScript equ 0xD667   ; ram/wram.asm:2293 (db); sym-verified
%endif
%ifndef wTileInFrontOfBoulderAndBoulderCollisionResult
wTileInFrontOfBoulderAndBoulderCollisionResult equ 0xD71B ; sym-verified
%endif
%ifndef wSafariSteps
wSafariSteps                 equ 0xD70C ; ram/wram.asm (dw); sym-verified
%endif
%ifndef wNumSafariBalls
wNumSafariBalls              equ 0xDA46 ; ram/wram.asm (db); sym-verified
%endif

; --- HRAM (ram/hram.asm) — same EBP-relative space, just the $FF80-$FFFE
; window; sym-verified via `git show origin/symbols:pokeyellow.sym`.
%ifndef H_WARP_DESTINATION_MAP
H_WARP_DESTINATION_MAP       equ 0xFF8B ; hWarpDestinationMap (UNION w/ H_PREVIOUS_TILESET, same addr)
%endif
%ifndef H_PLAYER_FACING
H_PLAYER_FACING              equ 0xFFDB ; hPlayerFacing (UNION w/ hPlayerYCoord/hPlayerXCoord that follow)
%endif

; --- Map constants (constants/map_constants.asm) ---------------------------
%ifndef ROUTE_16
ROUTE_16                     equ 0x1B
%endif
%ifndef ROUTE_18
ROUTE_18                     equ 0x1D
%endif
%ifndef SEAFOAM_ISLANDS_B3F
SEAFOAM_ISLANDS_B3F          equ 0xA1
%endif
%ifndef SEAFOAM_ISLANDS_B4F
SEAFOAM_ISLANDS_B4F          equ 0xA2
%endif
%ifndef CERULEAN_CAVE_2F
CERULEAN_CAVE_2F             equ 0xE2
%endif
; SAFARI_ZONE_EAST already in gb_constants.inc (0xD9).

; --- Script-table indices (scripts/SeafoamIslandsB3F.asm / B4F.asm) ---------
; dw_const auto-increments from 0 per def_script_pointers block; both verified
; as literal `2` via `git show origin/symbols:pokeyellow.sym`
; (SCRIPT_SEAFOAMISLANDSB3F_MOVE_OBJECT / …B4F… both = 02). Presently inert:
; Seafoam Islands is not in the port's map set, so CheckForceBikeOrSurf's
; writes to wSeafoamIslandsB3FCurScript/B4FCurScript below are dead until that
; map + its _Script state machine land (docs/current_plan_script_engine.md).
%ifndef SCRIPT_SEAFOAMISLANDSB3F_MOVE_OBJECT
SCRIPT_SEAFOAMISLANDSB3F_MOVE_OBJECT equ 2
%endif
%ifndef SCRIPT_SEAFOAMISLANDSB4F_MOVE_OBJECT
SCRIPT_SEAFOAMISLANDSB4F_MOVE_OBJECT equ 2
%endif

; --- hPlayerFacing bits (pret: engine/overworld/player_state.asm, local
; const_def block right above GetTileTwoStepsInFrontOfPlayer) ---------------
BIT_FACING_DOWN  equ 0
BIT_FACING_UP    equ 1
BIT_FACING_LEFT  equ 2
BIT_FACING_RIGHT equ 3

; --- Charmap glyph (constants/charmap.asm) not yet in a shared header ------
%ifndef TILE_SPC
TILE_SPC equ 0x7F   ; space
%endif

; ---------------------------------------------------------------------------
; Externs
; ---------------------------------------------------------------------------
extern GetPredefRegisters   ; src/home/predef.asm — linked (POKEMON_SRCS)
extern IsInArray            ; src/home/array.asm — linked (POKEMON_SRCS)
extern TextBoxBorder        ; src/text/text.asm — linked (GAME_SRCS)
extern PlaceString          ; src/text/text.asm — linked (GAME_SRCS)
extern PrintNumber          ; src/home/print_num.asm — linked (GAME_SRCS)
extern text_row_stride      ; src/text/text.asm — linked (GAME_SRCS); active
                             ; W_TILEMAP row stride (20 overworld default / 40
                             ; when a caller writes W_TILEMAP directly)

; CLOSURE: ForceBikeOrSurf lives in src/engine/overworld/player_gfx.asm, which
; is `global`-exported there but the FILE sits in HOME_CHECK_SRCS (check-only,
; NOT in LINK_SRCS) per dos_port/Makefile. So this extern resolves for a
; standalone `nasm -f coff` check of THIS file (unresolved externs are fine
; per the ticket's verify step) but WOULD NOT resolve at final link time until
; player_gfx.asm (or at least ForceBikeOrSurf) is promoted to GAME_SRCS. Until
; then, this file must also be treated as check-only (or CheckForceBikeOrSurf
; carved out) — see the CLOSURE REPORT in the task write-up.
extern ForceBikeOrSurf       ; src/engine/overworld/player_gfx.asm — CHECK-ONLY (HOME_CHECK_SRCS)

; CLOSURE: IsPlayerStandingOnDoorTile is defined in src/engine/overworld/
; overworld.asm (a LINKED file, GAME_SRCS) but is NOT declared `global` there
; (verified: `grep '^global ' overworld.asm` lists no door/tile routines) — it
; is currently file-local. This extern will not resolve at final link until
; root adds `global IsPlayerStandingOnDoorTile` to overworld.asm. Flagged, not
; fixed here (hard rule: this ticket creates ONLY this file).
extern IsPlayerStandingOnDoorTile ; src/engine/overworld/overworld.asm — LINKED file, but NOT yet `global` there (link blocker; see CLOSURE)
; OW-4.1 CheckForCollisionWhenPushingBoulder deps:
extern IsTilePassable                    ; src/engine/overworld/overworld.asm — LINKED (returns CF)
extern CheckForTilePairCollisions2       ; src/engine/overworld/ledges.asm — CHECK-ONLY (ESI=flat table, returns CF)
extern TilePairCollisionsLand            ; src/engine/overworld/ledges.asm — CHECK-ONLY (flat tile-pair table)
extern CheckForBoulderCollisionWithSprites ; src/engine/overworld/push_boulder.asm — not yet ported (OW-4.2)

global IsPlayerStandingOnWarp
global CheckForceBikeOrSurf
global IsSSAnneBowWarpTileInFrontOfPlayer
global IsPlayerStandingOnDoorTileOrWarpTile
global PrintSafariZoneSteps
global GetTileAndCoordsInFrontOfPlayer
global _GetTileAndCoordsInFrontOfPlayer
global GetTileTwoStepsInFrontOfPlayer
global CheckForCollisionWhenPushingBoulder

section .text

; ---------------------------------------------------------------------------
; IsPlayerStandingOnWarp — pret: engine/overworld/player_state.asm:IsPlayerStandingOnWarp
; Only used for setting BIT_STANDING_ON_WARP of wMovementFlags upon entering a
; new map. Scans the $NumberOfWarps-entry wWarpEntries list (4 bytes/entry:
; Y, X, dest-warp-id, dest-map) for one matching the player's current tile.
; Clobbers AL, BL (warp counter, pret's C), ESI (pret's HL). No flag contract.
; ---------------------------------------------------------------------------
IsPlayerStandingOnWarp:
    mov bl, [ebp + W_NUMBER_OF_WARPS]
    test bl, bl
    jz .ret
    mov esi, W_WARP_ENTRIES
.loop:
    mov al, [ebp + W_Y_COORD]
    cmp al, [ebp + esi]
    jne .nextWarp1
    inc esi
    mov al, [ebp + W_X_COORD]
    cmp al, [ebp + esi]
    jne .nextWarp2
    inc esi
    mov al, [ebp + esi]                     ; target warp id
    inc esi
    mov [ebp + W_DESTINATION_WARP_ID], al
    mov al, [ebp + esi]                     ; target map
    mov [ebp + H_WARP_DESTINATION_MAP], al
    or byte [ebp + W_MOVEMENT_FLAGS], (1 << BIT_STANDING_ON_WARP)
    ret
.nextWarp1:
    inc esi
.nextWarp2:
    inc esi
    inc esi
    inc esi
    dec bl
    jnz .loop
.ret:
    ret

; ---------------------------------------------------------------------------
; CheckForceBikeOrSurf — pret: engine/overworld/player_state.asm:CheckForceBikeOrSurf
; Scans ForcedBikeOrSurfMaps (map,Y,X triples, $FF-terminated) for the player's
; current position; if matched, forces biking (or, on the two Seafoam Islands
; boulder-hole tiles, surfing) via ForceBikeOrSurf. Faithful translation incl.
; the pret quirk that wSeafoamIslandsB3F/B4FCurScript are written UNCONDITIONALLY
; once map/Y/X match (not gated on which Seafoam floor it actually is) — this is
; pret's own behaviour, not a bug introduced here.
; No push/pop here: pret's original doesn't save BC/DE/HL either.
; ---------------------------------------------------------------------------
CheckForceBikeOrSurf:
    test byte [ebp + W_STATUS_FLAGS_6], (1 << BIT_ALWAYS_ON_BIKE)
    jnz .ret                                ; ret nz
    mov esi, ForcedBikeOrSurfMaps
    mov bh, [ebp + W_Y_COORD]
    mov bl, [ebp + W_X_COORD]
    mov dh, [ebp + W_CUR_MAP]
.loop:
    mov al, [esi]
    inc esi
    cmp al, 0xFF
    je .ret                                 ; ret z — not part of the list
    cmp al, dh                              ; compare to current map
    jne .incorrectMap
    mov al, [esi]
    inc esi
    cmp al, bh                              ; compare y-coord
    jne .incorrectY
    mov al, [esi]
    inc esi
    cmp al, bl                              ; compare x-coord
    jne .loop                               ; incorrect x-coord, check next item
    mov al, [ebp + W_CUR_MAP]
    cmp al, SEAFOAM_ISLANDS_B3F
    mov byte [ebp + wSeafoamIslandsB3FCurScript], SCRIPT_SEAFOAMISLANDSB3F_MOVE_OBJECT
    je .forceSurfing
    mov al, [ebp + W_CUR_MAP]
    cmp al, SEAFOAM_ISLANDS_B4F
    mov byte [ebp + wSeafoamIslandsB4FCurScript], SCRIPT_SEAFOAMISLANDSB4F_MOVE_OBJECT
    je .forceSurfing
    or byte [ebp + W_STATUS_FLAGS_6], (1 << BIT_ALWAYS_ON_BIKE)
    mov byte [ebp + W_WALK_BIKE_SURF_STATE], 1
    mov byte [ebp + W_WALK_BIKE_SURF_STATE_COPY], 1
    call ForceBikeOrSurf
    ret
.incorrectMap:
    inc esi
.incorrectY:
    inc esi
    jmp .loop
.forceSurfing:
    mov byte [ebp + W_WALK_BIKE_SURF_STATE], 2
    mov byte [ebp + W_WALK_BIKE_SURF_STATE_COPY], 2
    call ForceBikeOrSurf
.ret:
    ret

; ---------------------------------------------------------------------------
; IsSSAnneBowWarpTileInFrontOfPlayer — pret: engine/overworld/player_state.asm
; :IsSSAnneBowWarpTileInFrontOfPlayer
;
; STRUCTURAL NOTE (not a PROJ/TODO-HW case — flagged plainly): in pret this is
; a fallthrough target reached from IsWarpTileInFrontOfPlayer (when wCurMap ==
; SS_ANNE_BOW) and it finishes by jumping into IsWarpTileInFrontOfPlayer.done
; (a shared pop-hl/de/bc + ret epilogue). The port's IsWarpTileInFrontOfPlayer
; (src/engine/overworld/warp_check.asm) has no such epilogue — it tail-calls
; IsInArray directly and its SS_ANNE_BOW branch is intentionally omitted there
; (SS Anne is not yet in the port's map set). So this is a standalone routine
; with the same CF contract (CF=1 iff the tile in front of the player is the
; SS Anne bow's warp tile $15) rather than a shared-epilogue jump target.
; Presently unreachable: nothing calls it yet — wire the SS_ANNE_BOW dispatch
; into warp_check.asm's IsWarpTileInFrontOfPlayer when SS Anne is implemented.
; ---------------------------------------------------------------------------
IsSSAnneBowWarpTileInFrontOfPlayer:
    cmp byte [ebp + W_TILE_IN_FRONT_OF_PLAYER], 0x15
    jne .notSSAnne5Warp
    stc
    ret
.notSSAnne5Warp:
    clc
    ret

; ---------------------------------------------------------------------------
; IsPlayerStandingOnDoorTileOrWarpTile — pret: engine/overworld/player_state.asm
; :IsPlayerStandingOnDoorTileOrWarpTile
;
; CF=1 (door/warp found) if the player's current tile is a door tile (delegates
; to IsPlayerStandingOnDoorTile) OR a warp-carpet tile for the current tileset
; (WarpTileIDPointers, indexed by wCurMapTileset, scanned via IsInArray against
; the tile the player is standing on). If it's a warp-carpet tile but NOT a door
; tile, BIT_STANDING_ON_WARP is cleared (pret's `res` — matches pret exactly).
; All registers preserved except returned CF.
;
; PROJ: pret's `lda_coord 8, 9` reads the tile the player is STANDING on (its
; own standing tile, not a "tile in front" projection) — same address as the
; existing GetTileInFrontOfPlayer's precedent for the player's feet:
; W_TILEMAP + PLAYER_STANDING_ROW*40 + PLAYER_STANDING_COL (row17,col24).
; ---------------------------------------------------------------------------
IsPlayerStandingOnDoorTileOrWarpTile:
    push eax
    push ebx
    push ecx
    push edx
    push esi
    call IsPlayerStandingOnDoorTile         ; sets CF
    jc .done
    movzx ebx, byte [ebp + W_CUR_MAP_TILESET]
    mov esi, [WarpTileIDPointers + ebx * 4] ; flat host ptr, table_width 2 in
                                             ; pret -> dd (4-byte) flat pointers here
    mov al, [ebp + W_TILEMAP + PLAYER_STANDING_ROW * SCREEN_TILES_W + PLAYER_STANDING_COL]
    mov edx, 1
    call IsInArray                          ; sets CF
    jnc .done
    and byte [ebp + W_MOVEMENT_FLAGS], ~(1 << BIT_STANDING_ON_WARP) & 0xFF
.done:
    ; POP does not affect CF (matches warp_check.asm:ExtraWarpCheck's note).
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

; ---------------------------------------------------------------------------
; PrintSafariZoneSteps — pret: engine/overworld/player_state.asm:PrintSafariZoneSteps
;
; PROJECTION (docs/ui_projection.md anchor rule): pret's box top-left is
; GB(0,0) — the doc's own worked example for a TOP-LEFT element ("translates
; neither axis"), so this uses the IDENTITY anchor (X+0/Y+0): our_row=gb_row,
; our_col=gb_col, written directly into W_TILEMAP at SCREEN_TILES_W(40) stride
; (`text_row_stride` is saved/restored around the writes, mirroring the
; save/restore pattern used throughout src/engine/menus/*.asm and battle_menu.asm
; for the same "direct 40-wide write" case), rather than through the
; stride-20-scratch + window-descriptor compositor (yes_no.asm/bag_menu.asm's
; mechanism for MODAL boxes). This box is a persistent HUD element, not a modal
; window, and — more importantly — is presently UNREACHABLE: Safari Zone /
; Cerulean Cave are not yet in the port's map set, so the SAFARI_ZONE_EAST /
; CERULEAN_CAVE_2F guard below never passes with today's map set. Wire it
; through the window compositor if/when it needs to coexist with other
; on-screen windows.
;
; ; PROJ overworld-ui (safari steps box):    GB(0,0) 7x3 --(anchor=top-left, X+0,Y+0)--> row=0 col=0
; ; PROJ overworld-ui (safari steps count):  GB(1,1)     --(identity)--> row=1 col=1
; ; PROJ overworld-ui (safari steps label):  GB(4,1)     --(identity)--> row=1 col=4
; ; PROJ overworld-ui (safari ball label):   GB(1,3)     --(identity)--> row=3 col=1
; ; PROJ overworld-ui (safari ball pad):     GB(5,3)     --(identity)--> row=3 col=5
; ; PROJ overworld-ui (safari ball count):   GB(6,3)     --(identity)--> row=3 col=6
;
; Divergence from pret: the final call is `call PrintNumber` (not pret's tail
; `jp PrintNumber`) so this routine can restore text_row_stride afterward —
; behaviourally identical (PrintNumber's own return address is irrelevant to
; observable behaviour), a necessary consequence of this port's stride model.
; ---------------------------------------------------------------------------
PrintSafariZoneSteps:
    mov al, [ebp + W_CUR_MAP]
    cmp al, SAFARI_ZONE_EAST
    jb .ret                                 ; ret c
    cmp al, CERULEAN_CAVE_2F
    jae .ret                                ; ret nc

    mov eax, [text_row_stride]
    push eax
    mov dword [text_row_stride], SCREEN_TILES_W

    mov esi, W_TILEMAP + 0 * SCREEN_TILES_W + 0
    mov bl, 7                               ; interior width  (pret lb bc, 3, 7 -> C)
    mov bh, 3                               ; interior height (pret lb bc, 3, 7 -> B)
    call TextBoxBorder

    mov esi, W_TILEMAP + 1 * SCREEN_TILES_W + 1
    mov edx, wSafariSteps
    mov bh, 2                               ; byte count  (pret lb bc, 2, 3 -> B)
    mov bl, 3                               ; digit count (pret lb bc, 2, 3 -> C)
    call PrintNumber

    mov esi, W_TILEMAP + 1 * SCREEN_TILES_W + 4
    mov eax, SafariSteps
    call PlaceString

    mov esi, W_TILEMAP + 3 * SCREEN_TILES_W + 1
    mov eax, SafariBallText
    call PlaceString

    mov al, [ebp + wNumSafariBalls]
    cmp al, 10
    jae .tenOrMore
    mov byte [ebp + W_TILEMAP + 3 * SCREEN_TILES_W + 5], TILE_SPC
.tenOrMore:
    mov esi, W_TILEMAP + 3 * SCREEN_TILES_W + 6
    mov edx, wNumSafariBalls
    mov bh, 1                               ; byte count  (pret lb bc, 1, 2 -> B)
    mov bl, 2                               ; digit count (pret lb bc, 1, 2 -> C)
    call PrintNumber

    pop eax
    mov [text_row_stride], eax
.ret:
    ret

; ---------------------------------------------------------------------------
; GetTileAndCoordsInFrontOfPlayer / _GetTileAndCoordsInFrontOfPlayer
; pret: engine/overworld/player_state.asm:GetTileAndCoordsInFrontOfPlayer /
;       engine/overworld/player_state.asm:_GetTileAndCoordsInFrontOfPlayer
;
; ══════ COORDINATE PROJECTION (read the ticket header twice) ══════
; The tile-read addresses below are IDENTICAL to the existing
; GetTileInFrontOfPlayer (src/engine/overworld/overworld.asm ~L1888):
;   Down  -> W_TILEMAP + (PLAYER_STANDING_ROW+2)*40 + PLAYER_STANDING_COL  (row19,col24)
;   Up    -> W_TILEMAP + (PLAYER_STANDING_ROW-2)*40 + PLAYER_STANDING_COL  (row15,col24)
;   Left  -> W_TILEMAP + PLAYER_STANDING_ROW*40 + (PLAYER_STANDING_COL-2)  (row17,col22)
;   Right -> W_TILEMAP + PLAYER_STANDING_ROW*40 + (PLAYER_STANDING_COL+2)  (row17,col26)
; This routine ADDS the D/E (DH/DL) map-coordinate output pret's version also
; produces (±1 to wYCoord/wXCoord per facing) — GetTileInFrontOfPlayer does not
; compute this half, hence this new routine rather than modifying it.
;
; GetTileAndCoordsInFrontOfPlayer is the `predef`-callable entry (pret restores
; b/c/d/e/h/l from wPredef* via GetPredefRegisters first); the fallthrough
; _GetTileAndCoordsInFrontOfPlayer is the direct-call entry other routines use
; (e.g. IsWarpTileInFrontOfPlayer, IsPlayerFacingEdgeOfMap's sibling calls in
; pret). Not yet called by anything in the port (no predef caller / boulder
; engine wired) — added per OW-1.8 scope for the getters half.
;
; In:  W_SPRITE_PLAYER_FACING_DIR (wSpritePlayerStateData1FacingDirection).
; Out: DH = map Y coord in front of player (wYCoord ±1), DL = map X coord
;      (wXCoord ±1), CL = tile ID (also stored to W_TILE_IN_FRONT_OF_PLAYER).
; Clobbers: AL, ESI, DH/DL, ECX.
; ---------------------------------------------------------------------------
GetTileAndCoordsInFrontOfPlayer:
    call GetPredefRegisters
    ; fall through — pret has no explicit jump either

_GetTileAndCoordsInFrontOfPlayer:
    mov dh, [ebp + W_Y_COORD]
    mov dl, [ebp + W_X_COORD]
    mov al, [ebp + W_SPRITE_PLAYER_FACING_DIR]
    cmp al, SPRITE_FACING_DOWN
    jne .notFacingDown
    mov esi, W_TILEMAP + (PLAYER_STANDING_ROW + 2) * SCREEN_TILES_W + PLAYER_STANDING_COL
    inc dh
    jmp .storeTile
.notFacingDown:
    cmp al, SPRITE_FACING_UP
    jne .notFacingUp
    mov esi, W_TILEMAP + (PLAYER_STANDING_ROW - 2) * SCREEN_TILES_W + PLAYER_STANDING_COL
    dec dh
    jmp .storeTile
.notFacingUp:
    cmp al, SPRITE_FACING_LEFT
    jne .notFacingLeft
    mov esi, W_TILEMAP + PLAYER_STANDING_ROW * SCREEN_TILES_W + (PLAYER_STANDING_COL - 2)
    dec dl
    jmp .storeTile
.notFacingLeft:
    ; SPRITE_FACING_RIGHT — unconditional fallthrough, matches pret
    mov esi, W_TILEMAP + PLAYER_STANDING_ROW * SCREEN_TILES_W + (PLAYER_STANDING_COL + 2)
    inc dl
.storeTile:
    movzx ecx, byte [ebp + esi]
    mov [ebp + W_TILE_IN_FRONT_OF_PLAYER], cl
    ret

; ---------------------------------------------------------------------------
; GetTileTwoStepsInFrontOfPlayer — pret: engine/overworld/player_state.asm
; :GetTileTwoStepsInFrontOfPlayer
;
; Same projection family, TWO blocks (±4 tiles) ahead instead of one:
;   Down  -> row = PLAYER_STANDING_ROW+4, col = PLAYER_STANDING_COL
;   Up    -> row = PLAYER_STANDING_ROW-4, col = PLAYER_STANDING_COL
;   Left  -> row = PLAYER_STANDING_ROW,   col = PLAYER_STANDING_COL-4
;   Right -> row = PLAYER_STANDING_ROW,   col = PLAYER_STANDING_COL+4
; (pret lda_coord 8,13 / 8,5 / 4,9 / 12,9 vs. the one-step 8,11 / 8,7 / 6,9 /
; 10,9 — each exactly double the ±row/col delta from the standing tile (8,9)).
;
; Also sets hPlayerFacing (H_PLAYER_FACING) bits BIT_FACING_DOWN/UP/LEFT/RIGHT
; and writes the tile to BOTH wTileInFrontOfBoulderAndBoulderCollisionResult
; and W_TILE_IN_FRONT_OF_PLAYER, exactly as pret does. Only this getter half is
; ported — CheckForCollisionWhenPushingBoulder / CheckForBoulderCollisionWithSprites
; (pret's only two callers of this routine) are deferred to OW-4.1, so this
; routine is presently unreachable from the port; it's included here per ticket
; scope ("GetTileAndCoordsInFrontOfPlayer + GetTileTwoStepsInFrontOfPlayer").
;
; Out: DH = map Y coord two steps ahead, DL = map X coord two steps ahead,
;      CL = tile ID. H_PLAYER_FACING set to the single matching facing bit.
; Clobbers: AL, ESI, DH/DL, ECX.
; ---------------------------------------------------------------------------
GetTileTwoStepsInFrontOfPlayer:
    mov byte [ebp + H_PLAYER_FACING], 0
    mov dh, [ebp + W_Y_COORD]
    mov dl, [ebp + W_X_COORD]
    mov al, [ebp + W_SPRITE_PLAYER_FACING_DIR]
    cmp al, SPRITE_FACING_DOWN
    jne .notFacingDown
    or byte [ebp + H_PLAYER_FACING], (1 << BIT_FACING_DOWN)
    mov esi, W_TILEMAP + (PLAYER_STANDING_ROW + 4) * SCREEN_TILES_W + PLAYER_STANDING_COL
    inc dh
    jmp .storeTile
.notFacingDown:
    cmp al, SPRITE_FACING_UP
    jne .notFacingUp
    or byte [ebp + H_PLAYER_FACING], (1 << BIT_FACING_UP)
    mov esi, W_TILEMAP + (PLAYER_STANDING_ROW - 4) * SCREEN_TILES_W + PLAYER_STANDING_COL
    dec dh
    jmp .storeTile
.notFacingUp:
    cmp al, SPRITE_FACING_LEFT
    jne .notFacingLeft
    or byte [ebp + H_PLAYER_FACING], (1 << BIT_FACING_LEFT)
    mov esi, W_TILEMAP + PLAYER_STANDING_ROW * SCREEN_TILES_W + (PLAYER_STANDING_COL - 4)
    dec dl
    jmp .storeTile
.notFacingLeft:
    ; SPRITE_FACING_RIGHT — unconditional fallthrough, matches pret
    or byte [ebp + H_PLAYER_FACING], (1 << BIT_FACING_RIGHT)
    mov esi, W_TILEMAP + PLAYER_STANDING_ROW * SCREEN_TILES_W + (PLAYER_STANDING_COL + 4)
    inc dl
.storeTile:
    movzx ecx, byte [ebp + esi]
    mov [ebp + wTileInFrontOfBoulderAndBoulderCollisionResult], cl
    mov [ebp + W_TILE_IN_FRONT_OF_PLAYER], cl
    ret

; ---------------------------------------------------------------------------
; CheckForCollisionWhenPushingBoulder (OW-4.1) — decide whether the boulder two
; steps ahead can be pushed. Result in wTileInFrontOfBoulderAndBoulderCollisionResult
; ($ff = blocked). pret: engine/overworld/player_state.asm.
; CheckForBoulderCollisionWithSprites lives in pret push_boulder.asm → extern
; (ported in OW-4.2); the sprite-collision result it returns in AL is stored at .done.
; ---------------------------------------------------------------------------
CheckForCollisionWhenPushingBoulder:
    call GetTileTwoStepsInFrontOfPlayer
    call IsTilePassable
    jc .done                                   ; not passable (AL = IsTilePassable's leftover, per pret)
    mov esi, TilePairCollisionsLand            ; flat host ptr to the tile-pair table
    call CheckForTilePairCollisions2
    mov al, 0xff
    jc .done                                   ; elevation difference between current tile and 2-ahead
    mov al, [ebp + wTileInFrontOfBoulderAndBoulderCollisionResult]
    cmp al, 0x15                               ; stairs tile
    mov al, 0xff                               ; (ld doesn't disturb ZF from cmp)
    jz .done                                   ; the tile two steps ahead is stairs
    call CheckForBoulderCollisionWithSprites   ; AL = collision result
.done:
    mov [ebp + wTileInFrontOfBoulderAndBoulderCollisionResult], al
    ret

; ===========================================================================
; Data
; ===========================================================================
section .data

; ---------------------------------------------------------------------------
; ForcedBikeOrSurfMaps — pret: data/maps/force_bike_surf.asm
; map id, Y, X triples ($FF-terminated). Byte order matches pret's
; `force_bike_surf` macro (`db \1, \3, \2` = map, Y, X).
; ---------------------------------------------------------------------------
ForcedBikeOrSurfMaps:
    db ROUTE_16,            17, 10
    db ROUTE_16,            17, 11
    db ROUTE_18,            33,  8
    db ROUTE_18,            33,  9
    db SEAFOAM_ISLANDS_B3F, 18,  7
    db SEAFOAM_ISLANDS_B3F, 19,  7
    db SEAFOAM_ISLANDS_B4F,  4, 14
    db SEAFOAM_ISLANDS_B4F,  5, 14
    db 0xFF

; ---------------------------------------------------------------------------
; WarpTileIDPointers / WarpTileIDLists — pret: data/tilesets/warp_tile_ids.asm
; 25 entries (NUM_TILESETS, constants/tileset_constants.asm order: OVERWORLD=0
; .. BEACH_HOUSE=24). pret's `table_width 2` (dw) becomes flat `dd` pointers
; here (IsInArray reads flat [ESI]), matching the WarpTileListPointers
; precedent in warp_check.asm. The byte-sharing fallthrough structure in
; WarpTileIDLists below is transcribed 1:1 from pret (several tileset labels
; alias into the MIDDLE of another tileset's list — faithful, not a mistake).
; ---------------------------------------------------------------------------
WarpTileIDPointers:
    dd WarpTileIDLists.OverworldWarpTileIDs    ; 0  OVERWORLD
    dd WarpTileIDLists.RedsHouse1WarpTileIDs   ; 1  REDS_HOUSE_1
    dd WarpTileIDLists.MartWarpTileIDs         ; 2  MART
    dd WarpTileIDLists.ForestWarpTileIDs       ; 3  FOREST
    dd WarpTileIDLists.RedsHouse2WarpTileIDs   ; 4  REDS_HOUSE_2 (= RedsHouse1)
    dd WarpTileIDLists.DojoWarpTileIDs         ; 5  DOJO (= Gym)
    dd WarpTileIDLists.PokecenterWarpTileIDs   ; 6  POKECENTER (= Mart)
    dd WarpTileIDLists.GymWarpTileIDs          ; 7  GYM
    dd WarpTileIDLists.HouseWarpTileIDs        ; 8  HOUSE
    dd WarpTileIDLists.ForestGateWarpTileIDs   ; 9  FOREST_GATE (= Gate/Museum)
    dd WarpTileIDLists.MuseumWarpTileIDs       ; 10 MUSEUM (= Gate/ForestGate)
    dd WarpTileIDLists.UndergroundWarpTileIDs  ; 11 UNDERGROUND
    dd WarpTileIDLists.GateWarpTileIDs         ; 12 GATE
    dd WarpTileIDLists.ShipWarpTileIDs         ; 13 SHIP
    dd WarpTileIDLists.ShipPortWarpTileIDs     ; 14 SHIP_PORT
    dd WarpTileIDLists.CemeteryWarpTileIDs     ; 15 CEMETERY
    dd WarpTileIDLists.InteriorWarpTileIDs     ; 16 INTERIOR
    dd WarpTileIDLists.CavernWarpTileIDs       ; 17 CAVERN
    dd WarpTileIDLists.LobbyWarpTileIDs        ; 18 LOBBY
    dd WarpTileIDLists.MansionWarpTileIDs      ; 19 MANSION
    dd WarpTileIDLists.LabWarpTileIDs          ; 20 LAB
    dd WarpTileIDLists.ClubWarpTileIDs         ; 21 CLUB (= ShipPort)
    dd WarpTileIDLists.FacilityWarpTileIDs     ; 22 FACILITY
    dd WarpTileIDLists.PlateauWarpTileIDs      ; 23 PLATEAU
    dd WarpTileIDLists.BeachHouseWarpTileIDs   ; 24 BEACH_HOUSE

WarpTileIDLists:
.OverworldWarpTileIDs:
    db 0x1B, 0x58, 0xFF

.ForestGateWarpTileIDs:
.MuseumWarpTileIDs:
.GateWarpTileIDs:
    db 0x3B
    ; fallthrough (faithful to pret)
.RedsHouse1WarpTileIDs:
.RedsHouse2WarpTileIDs:
    db 0x1A, 0x1C, 0xFF

.MartWarpTileIDs:
.PokecenterWarpTileIDs:
    db 0x5E, 0xFF

.ForestWarpTileIDs:
    db 0x5A, 0x5C, 0x3A, 0xFF

.DojoWarpTileIDs:
.GymWarpTileIDs:
    db 0x4A, 0xFF

.HouseWarpTileIDs:
    db 0x54, 0x5C, 0x32, 0xFF

.ShipWarpTileIDs:
    db 0x37, 0x39, 0x1E, 0x4A, 0xFF

.InteriorWarpTileIDs:
    db 0x15, 0x55, 0x04, 0xFF

.CavernWarpTileIDs:
    db 0x18, 0x1A, 0x22, 0xFF

.LobbyWarpTileIDs:
    db 0x1A, 0x1C, 0x38, 0xFF

.MansionWarpTileIDs:
    db 0x1A, 0x1C, 0x53, 0xFF

.LabWarpTileIDs:
    db 0x34, 0xFF

.FacilityWarpTileIDs:
    db 0x43, 0x58, 0x20
    ; fallthrough (faithful to pret)
.CemeteryWarpTileIDs:
    db 0x1B
    ; fallthrough (faithful to pret)
.UndergroundWarpTileIDs:
    db 0x13, 0xFF

.PlateauWarpTileIDs:
    db 0x1B, 0x3B
    ; fallthrough (faithful to pret)
.ShipPortWarpTileIDs:
.ClubWarpTileIDs:
    db 0xFF

.BeachHouseWarpTileIDs:
    db 0xFF

; ---------------------------------------------------------------------------
; SafariSteps / SafariBallText — Tier-1 text data (project-conventions: strings
; are DATA, generated, never hand-encoded charmap bytes). Produced by
; tools/gen_overworld_strings.py (gb_text.encode of the pret literals) into
; assets/overworld_strings.inc, %include'd below. pret: engine/overworld/player_state.asm.
; ---------------------------------------------------------------------------
%include "assets/overworld_strings.inc"
