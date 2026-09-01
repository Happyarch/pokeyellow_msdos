; pikachu_follow.asm — mirror of pret engine/pikachu/pikachu_follow.asm.
;
; Full implementation of Phase 1 Overworld Follower Pikachu Subsystem:
; - Spawn calculation routines (CalculatePikachuPlacementCoords,
;   CalculatePikachuSpawnCoordsAndFacing, CalculatePikachuFacingDirection,
;   ComputePikachuFacingDirection, SchedulePikachuSpawnForAfterText,
;   ClearPikachuSpriteStateData)
; - Transition hooks & tables (SetPikachuSpawnOutside, SetPikachuSpawnWarpPad,
;   SetPikachuSpawnBackOutside, Pointer_fc64b, Pointer_fc653, Pointer_fc68e)
; - Spawn & visibility (SpawnPikachu_ / _SpawnPikachu, WillPikachuSpawnOnTheScreen,
;   Func_fc745, Func_fc76a)
; - 11-state follow state machine (PointerTable_fc710 and state handlers)
; - Step interpolation and pixel math (AddPikachuStepVector,
;   TryDoubleAddPikachuStepVectorToScreenPixelCoords,
;   DoubleAddPikachuStepVectorToScreenPixelCoords,
;   AddPikachuStepVectorToScreenPixelCoords, ResetPikachuStepVector,
;   GetPikachuWalkingAnimationSpeed, UpdatePikachuWalkingSprite)
; - Follow command FIFO buffer (Func_fcc08, Func_fcc23, Func_fcc42, Func_fcc64,
;   Func_fcc92, GetPikachuFollowCommand,
;   GetPikachuFollowCommandIfBufferSizeNonzero,
;   AreThereAtLeastTwoStepsInPikachuFollowCommandBuffer,
;   ComparePikachuHappinessTo80)
;
; Register map (CLAUDE.md): A→AL, HL→ESI, BC→BX (B=BH,C=BL), DE→DX; SM83 `swap a`
; = nibble swap = `ror al, 4`. GB memory = [ebp + SYM] (gb_memmap.inc).
;
; pret citations are given per routine as `pret <file>:<label>`.

bits 32

%include "gb_memmap.inc"
%include "assets/map_dims.inc"   ; map-id / tileset-id constants (Tier-1 generated)
%include "assets/script_constants.inc"; shared constants (%define: emits no COFF symbol)
%include "gb_constants.inc"
%include "gb_macros.inc"

; ---------------------------------------------------------------------------
; Map IDs for spawn locations (constants/map_constants.asm)
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; Pikachu WRAM & sprite offsets (mirror of pret usage)
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; Externs
; ---------------------------------------------------------------------------
extern IsStarterPikachuAliveInOurParty  ; src/engine/pikachu/pikachu_status.asm
extern FillMemory                       ; src/home/copy2.asm
extern EnablePikachuFollowingPlayer     ; src/home/pikachu.asm
extern CheckPikachuFollowingPlayer      ; src/home/pikachu.asm
extern Pikachu_IsInArray                ; src/home/pikachu.asm
extern InitializeSpriteScreenPosition   ; src/engine/overworld/movement.asm
extern Random                           ; src/home/random.asm
extern g_window_count          ; ppu.asm — window count
extern g_windows               ; ppu.asm — window array
extern g_bg_whiteout           ; ppu.asm — whiteout

; ---------------------------------------------------------------------------
; Globals
; ---------------------------------------------------------------------------
global ShouldPikachuSpawn
global SchedulePikachuSpawnForAfterText
global ClearPikachuSpriteStateData
global CalculatePikachuSpawnCoordsAndFacing
global CalculatePikachuPlacementCoords
global CalculatePikachuFacingDirection
global SetPikachuSpawnOutside
global Pointer_fc64b
global Pointer_fc653
global SetPikachuSpawnWarpPad
global Pointer_fc68e
global SetPikachuSpawnBackOutside
global SetPikachuOverworldStateFlag2
global ResetPikachuOverworldStateFlag2
global SpawnPikachu_
global _SpawnPikachu
global PointerTable_fc710
global Func_fc745
global Func_fc76a
global Func_fc793
global Func_fc7aa
global Pointer_fc7e3
global Func_fc803
global Func_fc82e
global Func_fc835
global Func_fc842
global PointerTable_fc85a
global Func_fc862
global asm_fc87f
global Func_fc8c7
global Pointer_fc8d6
global Func_fc8f8
global asm_fc904
global Func_fc92b
global asm_fc937
global Func_fc95d
global asm_fc969
global NormalPikachuFollow
global asm_fc9c3
global FastPikachuFollow
global asm_fc9ee
global Func_fca0a
global asm_fca1c
global AddPikachuStepVector
global TryDoubleAddPikachuStepVectorToScreenPixelCoords
global DoubleAddPikachuStepVectorToScreenPixelCoords
global AddPikachuStepVectorToScreenPixelCoords
global ResetPikachuStepVector
global GetPikachuWalkingAnimationSpeed
global UpdatePikachuWalkingSprite
global Func_fcae2
global IsPikachuRightNextToPlayer
global GetPikachuFacingDirectionAndReturnToE
global GetPikachuFacingDirection
global ClearPikachuFollowCommandBuffer
global AppendPikachuFollowCommandToBuffer
global RefreshPikachuFollow
global ComputePikachuFollowCommand
global CheckAbsoluteValueLessThan2
global Func_fcc08
global Func_fcc23
global Func_fcc42
global Func_fcc64
global Func_fcc92
global ComputePikachuFacingDirection
global GetPikachuFollowCommand
global GetPikachuFollowCommandIfBufferSizeNonzero
global AreThereAtLeastTwoStepsInPikachuFollowCommandBuffer
global WillPikachuSpawnOnTheScreen
global ComparePikachuHappinessTo80

section .text

; ===========================================================================
; ShouldPikachuSpawn — pret pikachu_follow.asm:ShouldPikachuSpawn. Carry set only
; if Pikachu should be visible: not hidden (bits 5,7 clear), starter Pikachu alive
; in party, and on foot (wWalkBikeSurfState == 0).
; ===========================================================================
ShouldPikachuSpawn:
    test byte [ebp + wPikachuOverworldStateFlags], 0x20  ; bit 5, a
    jnz .hide
    test byte [ebp + wPikachuOverworldStateFlags], 0x80  ; bit 7, a
    jnz .hide
    call IsStarterPikachuAliveInOurParty                  ; carry => alive
    jnc .hide
    mov al, [ebp + wWalkBikeSurfState]                ; ld a,[wWalkBikeSurfState]
    and al, al
    jnz .hide
    stc                                                   ; scf
    ret
.hide:
    clc                                                   ; and a (clears carry)
    ret

; ===========================================================================
; SchedulePikachuSpawnForAfterText — pret pikachu_follow.asm:SchedulePikachuSpawnForAfterText
; ===========================================================================
SchedulePikachuSpawnForAfterText:
    ; FLAG ORDER IS LOAD-BEARING. pret is `bit 4,[hl]` / `res 4,[hl]` / `jr nz`,
    ; and SM83 RES does NOT affect flags, so the branch reads the BIT result. x86
    ; AND *does* set ZF, so testing before the clear let the clear's ZF (is the
    ; whole byte zero once bit 4 is cleared?) reach the jump instead of "was bit 4
    ; set?" — a different condition entirely. Sample the byte first, clear second,
    ; test the sampled copy last, so the branch reads what pret's branch reads.
    mov al, [ebp + wPikachuOverworldStateFlags]         ; ld hl, wPikachuOverworldStateFlags
    and byte [ebp + wPikachuOverworldStateFlags], ~0x10 ; res 4, [hl]  (SM83: no flags)
    test al, 0x10                                       ; bit 4, [hl]  (the flag the branch reads)
    jnz .normal_spawn_state
    call EnablePikachuFollowingPlayer
    call ClearPikachuSpriteStateData
    mov byte [ebp + wSpritePikachuStateData1ImageIndex], 0xFF
    call ClearPikachuFollowCommandBuffer
    call CalculatePikachuFacingDirection
    ret

.normal_spawn_state:
    call CalculatePikachuPlacementCoords
    xor al, al
    mov [ebp + wPikachuSpawnState], al
    mov al, [ebp + wSpritePlayerStateData1FacingDirection]
    mov [ebp + wSpritePikachuStateData1FacingDirection], al
    ret

; ===========================================================================
; ClearPikachuSpriteStateData — pret pikachu_follow.asm:ClearPikachuSpriteStateData
; ===========================================================================
ClearPikachuSpriteStateData:
    mov esi, wSpritePikachuStateData1PictureID
    call .clear
    mov esi, wSpritePikachuStateData2
.clear:
    mov bx, 0x10
    xor al, al
    call FillMemory
    ret

; ===========================================================================
; CalculatePikachuSpawnCoordsAndFacing — pret pikachu_follow.asm:CalculatePikachuSpawnCoordsAndFacing
; ===========================================================================
CalculatePikachuSpawnCoordsAndFacing:
    call CalculatePikachuPlacementCoords
    call CalculatePikachuFacingDirection
    xor al, al
    mov [ebp + wPikachuSpawnState], al
    ret

; ===========================================================================
; CalculatePikachuPlacementCoords — pret pikachu_follow.asm:CalculatePikachuPlacementCoords
; ===========================================================================
CalculatePikachuPlacementCoords:
    mov ebx, wSpritePikachuStateData1PictureID
    mov al, [ebp + wYCoord]
    add al, 4
    mov dl, al                          ; e = y + 4
    mov al, [ebp + wXCoord]
    add al, 4
    mov dh, al                          ; d = x + 4
    mov al, [ebp + wPikachuSpawnState]
    and al, al
    jz .load_coords
    cmp al, 0x01
    jz .right_of_player
    cmp al, 0x02
    jz .check_player_facing2
    cmp al, 0x03
    jz .load_coords
    cmp al, 0x04
    jz .below_player
    cmp al, 0x05
    jz .above_player
    cmp al, 0x06
    jz .left_of_player
    cmp al, 0x07
    jz .check_player_facing
    jmp .right_of_player

.check_player_facing:
    mov al, [ebp + wSpritePlayerStateData1FacingDirection]
    and al, al                          ; SPRITE_FACING_DOWN (0)
    jz .below_player
    cmp al, SPRITE_FACING_UP
    jz .above_player
    cmp al, SPRITE_FACING_LEFT
    jz .left_of_player
    cmp al, SPRITE_FACING_RIGHT
    jz .right_of_player
.check_player_facing2:
    mov al, [ebp + wSpritePlayerStateData1FacingDirection]
    and al, al                          ; SPRITE_FACING_DOWN (0)
    jnz .check_up
    dec dl                              ; dec e
    jmp .load_coords

.check_up:
    cmp al, SPRITE_FACING_UP
    jnz .check_left
    inc dl                              ; inc e
    jmp .load_coords

.check_left:
    cmp al, SPRITE_FACING_LEFT
    jnz .left_of_player_2
    inc dh                              ; inc d
    jmp .load_coords

.left_of_player_2:
    dec dh                              ; dec d
    jmp .load_coords

.right_of_player:
    inc dh                              ; inc d
    jmp .load_coords

.left_of_player:
    dec dh                              ; dec d
    jmp .load_coords

.below_player:
    inc dl                              ; inc e
    jmp .load_coords

.above_player:
    dec dl                              ; dec e
    ; fallthrough to .load_coords

.load_coords:
    mov esi, (wSpriteStateData2 + SPRITESTATEDATA2_MAPY) - wSpriteStateData1
    add esi, ebx
    mov [ebp + esi], dl                 ; ld [hl], e
    inc esi
    mov [ebp + esi], dh                 ; ld [hl], d
    inc esi
    mov byte [ebp + esi], 0xFE          ; ld [hl], $fe
    or byte [ebp + wPikachuSpawnStateFlags], (1 << BIT_PIKACHU_SPAWN_FOLLOWING)
    ret

; ===========================================================================
; CalculatePikachuFacingDirection — pret pikachu_follow.asm:CalculatePikachuFacingDirection
; ===========================================================================
CalculatePikachuFacingDirection:
    mov byte [ebp + wSpritePikachuStateData1PictureID], 0x49
    mov byte [ebp + wSpritePikachuStateData1ImageIndex], 0xFF
    mov al, [ebp + wPikachuSpawnState]
    and al, al
    jz .copy_player_facing
    cmp al, 0x01
    jz .copy_player_facing
    cmp al, 0x03
    jz .force_facing_down
    cmp al, 0x04
    jz .copy_player_facing
    cmp al, 0x06
    jz .copy_player_facing
    cmp al, 0x07
    jz .face_the_other_way
    call ComputePikachuFacingDirection
    ret

.copy_player_facing:
    mov al, [ebp + wSpritePlayerStateData1FacingDirection]
    mov [ebp + wSpritePikachuStateData1FacingDirection], al
    ret

.force_facing_down:
    mov byte [ebp + wSpritePikachuStateData1FacingDirection], SPRITE_FACING_DOWN
    ret

.face_the_other_way:
    mov al, [ebp + wSpritePlayerStateData1FacingDirection]
    xor al, 0x04
    mov [ebp + wSpritePikachuStateData1FacingDirection], al
    ret

; ===========================================================================
; SetPikachuSpawnOutside — pret pikachu_follow.asm:SetPikachuSpawnOutside
; ===========================================================================
SetPikachuSpawnOutside:
    mov al, [ebp + wCurMap]
    cmp al, OAKS_LAB
    jz .oaks_lab
    cmp al, ROUTE_22_GATE
    jz .route_22_gate
    cmp al, MT_MOON_B1F
    jz .mt_moon_2
    cmp al, ROCK_TUNNEL_1F
    jz .rock_tunnel_1
    mov al, [ebp + wCurMap]
    mov esi, Pointer_fc64b
    sub esi, ebp                        ; Pass ESI so [ebp + esi] in Pikachu_IsInArray reads flat Pointer_fc64b
    call Pikachu_IsInArray
    jc .map_list_1
    mov al, [ebp + wCurMap]
    mov esi, Pointer_fc653
    sub esi, ebp                        ; Pass ESI so [ebp + esi] in Pikachu_IsInArray reads flat Pointer_fc653
    call Pikachu_IsInArray
    jnc .not_map_list_2
    mov al, [ebp + wSpritePlayerStateData1FacingDirection]
    and al, al
    jnz .not_map_list_2
    mov al, 0x03
    jmp .load

.route_22_gate:
    mov al, [ebp + wSpritePlayerStateData1FacingDirection]
    and al, al
    jz .rock_tunnel_1
    jmp .not_map_list_2

.mt_moon_2:
    mov al, 0x03
    jmp .load

.map_list_1:
    mov al, 0x04
    jmp .load

.oaks_lab:
    mov al, 0x06
    jmp .load

.not_map_list_2:
    mov al, 0x01
    jmp .load

.rock_tunnel_1:
    mov al, 0x03
.load:
    mov [ebp + wPikachuSpawnState], al
    ret

Pointer_fc64b:
    db VICTORY_ROAD_2F
    db ROUTE_7_GATE
    db ROUTE_8_GATE
    db ROUTE_16_GATE_1F
    db ROUTE_18_GATE_1F
    db ROUTE_15_GATE_1F
    db ROUTE_11_GATE_1F
    db 0xFF

Pointer_fc653:
    db VIRIDIAN_FOREST_NORTH_GATE
    db CERULEAN_BADGE_HOUSE
    db CERULEAN_TRASHED_HOUSE
    db VERMILION_DOCK
    db CELADON_MANSION_1F
    db ROUTE_2_GATE
    db FUCHSIA_GOOD_ROD_HOUSE
    db 0xFF

; ===========================================================================
; SetPikachuSpawnWarpPad — pret pikachu_follow.asm:SetPikachuSpawnWarpPad
; ===========================================================================
SetPikachuSpawnWarpPad:
    mov al, [ebp + wCurMap]
    cmp al, VIRIDIAN_FOREST_NORTH_GATE
    jz .viridian_forest_exit
    cmp al, VIRIDIAN_FOREST_SOUTH_GATE
    jz .viridian_forest_entrance
    mov al, [ebp + wCurMap]
    mov esi, Pointer_fc68e
    sub esi, ebp                        ; Pass ESI so [ebp + esi] in Pikachu_IsInArray reads flat Pointer_fc68e
    call Pikachu_IsInArray
    jc .in_array
    jmp .not_in_array

.viridian_forest_exit:
    mov al, [ebp + wSpritePlayerStateData1FacingDirection]
    cmp al, SPRITE_FACING_UP
    jz .in_array
    jmp .not_in_array

.viridian_forest_entrance:
    mov al, [ebp + wSpritePlayerStateData1FacingDirection]
    and al, al                          ; SPRITE_FACING_DOWN
    jz .not_in_array
    jmp .in_array

.not_in_array:
    mov al, 0x00
    jmp .load_spawn_state

.in_array:
    mov al, 0x01
.load_spawn_state:
    mov [ebp + wPikachuSpawnState], al
    ret

Pointer_fc68e:
    db VIRIDIAN_FOREST
    db SAFARI_ZONE_CENTER_REST_HOUSE
    db SAFARI_ZONE_WEST_REST_HOUSE
    db SAFARI_ZONE_EAST_REST_HOUSE
    db SAFARI_ZONE_NORTH_REST_HOUSE
    db SAFARI_ZONE_SECRET_HOUSE
    db SILPH_CO_ELEVATOR
    db CELADON_MART_ELEVATOR
    db CINNABAR_LAB_TRADE_ROOM
    db CINNABAR_LAB_METRONOME_ROOM
    db CINNABAR_LAB_FOSSIL_ROOM
    db 0xFF

; ===========================================================================
; SetPikachuSpawnBackOutside — pret pikachu_follow.asm:SetPikachuSpawnBackOutside
; ===========================================================================
SetPikachuSpawnBackOutside:
    mov al, [ebp + wCurMap]
    cmp al, ROUTE_22_GATE
    jz .asm_fc6a7
    cmp al, ROUTE_2_GATE
    jz .asm_fc6b0
    jmp .asm_fc6bd

.asm_fc6a7:
    mov al, [ebp + wSpritePlayerStateData1FacingDirection]
    cmp al, SPRITE_FACING_UP
    jz .asm_fc6b9
    jmp .asm_fc6bd

.asm_fc6b0:
    mov al, [ebp + wSpritePlayerStateData1FacingDirection]
    cmp al, SPRITE_FACING_UP
    jz .asm_fc6b9
    jmp .asm_fc6bd

.asm_fc6b9:
    mov al, 0x01
    jmp .asm_fc6c1

.asm_fc6bd:
    mov al, 0x03
    jmp .asm_fc6c1

.asm_fc6c1:
    mov [ebp + wPikachuSpawnState], al
    ret

; ===========================================================================
; SetPikachuOverworldStateFlag2 — pret pikachu_follow.asm:SetPikachuOverworldStateFlag2
; ===========================================================================
SetPikachuOverworldStateFlag2:
    or byte [ebp + wPikachuOverworldStateFlags], 0x04   ; set 2, [hl]
    ret

; ===========================================================================
; ResetPikachuOverworldStateFlag2 — pret pikachu_follow.asm:ResetPikachuOverworldStateFlag2
; ===========================================================================
ResetPikachuOverworldStateFlag2:
    and byte [ebp + wPikachuOverworldStateFlags], ~0x04 ; res 2, [hl]
    ret

; ===========================================================================
; SpawnPikachu_ / _SpawnPikachu — pret engine/pikachu/pikachu_follow.asm:SpawnPikachu_
; ===========================================================================
SpawnPikachu_:
    call ResetPikachuOverworldStateFlag2
    call TrySpawnPikachu
    jnc .ret
    push ebx
    call WillPikachuSpawnOnTheScreen
    pop ebx
    jc .ret

    mov ebx, wSpriteStateData1 + PIKACHU_SPRITE_INDEX * SPRITESTATEDATA_STRUCT_SIZE
    mov esi, wSpritePikachuStateData1MovementStatus - wSpritePikachuStateData1
    add esi, ebx
    test byte [ebp + esi], 0x80         ; bit 7, [hl]
    jnz Func_fc745
    mov al, [ebp + wFontLoaded]
    test al, (1 << BIT_FONT_LOADED)
    jnz Func_fc76a
    call CheckPikachuFollowingPlayer
    jnz Func_fc76a
    mov al, [ebp + esi]
    and al, 0x7F
    cmp al, 10
    jb .valid
    xor al, al
.valid:
    movzx eax, al
    jmp [PointerTable_fc710 + eax*4]
.ret:
    ret

_SpawnPikachu:
    jmp SpawnPikachu_

PointerTable_fc710:
    dd Func_fc793
    dd Func_fc7aa
    dd Func_fc803
    dd asm_fc9c3
    dd asm_fca1c
    dd asm_fc9ee
    dd asm_fc87f
    dd asm_fc904
    dd asm_fc937
    dd asm_fc969
    dd .nop

.nop:
    ret

; ===========================================================================
; TrySpawnPikachu — pret pikachu_follow.asm:TrySpawnPikachu
; ===========================================================================
TrySpawnPikachu:
    call ShouldPikachuSpawn
    jnc .dont_spawn
    mov al, [ebp + wSpritePikachuStateData1MovementStatus]
    and al, al
    jnz .already_spawned
    push ebx
    push esi
    call CalculatePikachuSpawnCoordsAndFacing
    pop esi
    pop ebx
.already_spawned:
    stc
    ret
.dont_spawn:
    mov byte [ebp + wSpritePikachuStateData1ImageIndex], 0xFF
    mov byte [ebp + wSpritePikachuStateData1MovementStatus], 0
    xor al, al
    ret

; ===========================================================================
; Func_fc745 — pret pikachu_follow.asm:Func_fc745
; ===========================================================================
Func_fc745:
    mov esi, wSpritePikachuStateData1MovementStatus - wSpritePikachuStateData1
    add esi, ebx
    and byte [ebp + esi], ~0x80         ; res 7, [hl]
    mov esi, (wSpriteStateData2 + SPRITESTATEDATA2_WALKANIMCOUNTER) - wSpriteStateData1
    add esi, ebx
    mov [ebp + esi], al                 ; ld [hl], a
    call CheckPikachuFollowingPlayer
    jnz .okay
    mov al, [ebp + wSpritePlayerStateData1FacingDirection]
    xor al, 0x04
    mov esi, wSpritePikachuStateData1FacingDirection - wSpritePikachuStateData1
    add esi, ebx
    mov [ebp + esi], al
.okay:
    xor al, al
    mov esi, wSpritePikachuStateData1IntraAnimFrameCounter - wSpritePikachuStateData1
    add esi, ebx
    mov [ebp + esi], al
    mov [ebp + esi + 1], al
    call UpdatePikachuWalkingSprite
    ret

; ===========================================================================
; Func_fc76a — pret pikachu_follow.asm:Func_fc76a
; ===========================================================================
Func_fc76a:
    xor al, al
    mov esi, wSpritePikachuStateData1IntraAnimFrameCounter - wSpritePikachuStateData1
    add esi, ebx
    mov [ebp + esi], al
    mov [ebp + esi + 1], al
    call UpdatePikachuWalkingSprite
    call Func_fc82e
    jc .skip
    push ebx
    movzx esi, byte [ebp + hCurrentSpriteOffset]
    call InitializeSpriteScreenPosition
    pop ebx
.skip:
    mov esi, wSpritePikachuStateData1MovementStatus - wSpritePikachuStateData1
    add esi, ebx
    mov byte [ebp + esi], 0x01
    mov esi, (wSpriteStateData2 + SPRITESTATEDATA2_WALKANIMCOUNTER) - wSpriteStateData1
    add esi, ebx
    mov byte [ebp + esi], 0x00
    call RefreshPikachuFollow
    ret

; ===========================================================================
; Func_fc793 — pret pikachu_follow.asm:Func_fc793 (State 0)
; ===========================================================================
Func_fc793:
    call RefreshPikachuFollow
    push ebx
    movzx esi, byte [ebp + hCurrentSpriteOffset]
    call InitializeSpriteScreenPosition
    pop ebx
    mov esi, wSpritePikachuStateData1ImageIndex - wSpritePikachuStateData1
    add esi, ebx
    mov byte [ebp + esi], 0xFF          ; ld [hl], $ff
    dec esi
    mov byte [ebp + esi], 0x01          ; dec hl; ld [hl], $1
    ret

; ===========================================================================
; Func_fc7aa — pret pikachu_follow.asm:Func_fc7aa (State 1)
; ===========================================================================
Func_fc7aa:
    call Func_fcc92
    jc Func_fc803
    dec al                              ; 0-based command index
    movzx edx, al
    shl edx, 2                          ; index * 4
    mov al, [Pointer_fc7e3 + edx]
    mov [ebp + ebx + SPRITESTATEDATA1_FACINGDIRECTION], al
    mov al, [Pointer_fc7e3 + edx + 1]
    mov [ebp + ebx + SPRITESTATEDATA1_XSTEPVECTOR], al
    mov al, [Pointer_fc7e3 + edx + 2]
    mov [ebp + ebx + SPRITESTATEDATA1_YSTEPVECTOR], al
    mov al, [Pointer_fc7e3 + edx + 3]
    mov [ebp + ebx + SPRITESTATEDATA1_MOVEMENTSTATUS], al
    cmp al, 0x04
    jz Func_fca0a
    call AreThereAtLeastTwoStepsInPikachuFollowCommandBuffer
    jc FastPikachuFollow
    jmp NormalPikachuFollow

Pointer_fc7e3:
    db  0,  0,  1,  3
    db  4,  0, -1,  3
    db  8, -1,  0,  3
    db 12,  1,  0,  3
    db  0,  0,  1,  4
    db  4,  0, -1,  4
    db  8, -1,  0,  4
    db 12,  1,  0,  4

; ===========================================================================
; Func_fc803 — pret pikachu_follow.asm:Func_fc803 (State 2)
; ===========================================================================
Func_fc803:
    call Func_fcae2
    jc .ret
    mov esi, (wSpriteStateData2 + SPRITESTATEDATA2_WALKANIMCOUNTER) - wSpriteStateData1
    add esi, ebx
    dec byte [ebp + esi]
    jnz .asm_fc823
    push esi
    call GetPikachuFollowCommand
    pop esi
    cmp al, 0x05
    jae Func_fc842
    mov byte [ebp + esi], 0x20
    call Random
    and al, 0x0C
    mov esi, wSpritePikachuStateData1FacingDirection - wSpritePikachuStateData1
    add esi, ebx
    mov [ebp + esi], al
.asm_fc823:
    xor al, al
    mov esi, wSpritePikachuStateData1IntraAnimFrameCounter - wSpritePikachuStateData1
    add esi, ebx
    mov [ebp + esi], al
    mov [ebp + esi + 1], al
    call UpdatePikachuWalkingSprite
.ret:
    ret

; ===========================================================================
; Func_fc82e — pret pikachu_follow.asm:Func_fc82e
; ===========================================================================
Func_fc82e:
    mov al, [ebp + wWalkCounter]
    and al, al
    jz .ret
    stc
.ret:
    ret

; ===========================================================================
; Func_fc835 — pret pikachu_follow.asm:Func_fc835
; ===========================================================================
Func_fc835:
    mov esi, (wSpriteStateData2 + SPRITESTATEDATA2_WALKANIMCOUNTER) - wSpriteStateData1
    add esi, ebx
    mov byte [ebp + esi], 0x10
    mov esi, wSpritePikachuStateData1MovementStatus - wSpritePikachuStateData1
    add esi, ebx
    mov byte [ebp + esi], 0x01
    ret

; ===========================================================================
; Func_fc842 — pret pikachu_follow.asm:Func_fc842
; ===========================================================================
Func_fc842:
    push eax
    call Random
    mov al, [ebp + hRandomAdd]
    and al, 0x03
    movzx edx, al
    pop eax
    jmp [PointerTable_fc85a + edx*4]

PointerTable_fc85a:
    dd Func_fc862
    dd Func_fc8f8
    dd Func_fc92b
    dd Func_fc95d

; ===========================================================================
; Func_fc862 & asm_fc87f & Func_fc8c7 — pret pikachu_follow.asm (State 6)
; ===========================================================================
Func_fc862:
    dec al
    add al, al
    add al, al
    and al, 0x0C
    mov esi, wSpritePikachuStateData1FacingDirection - wSpritePikachuStateData1
    add esi, ebx
    mov [ebp + esi], al
    mov esi, wSpritePikachuStateData1MovementStatus - wSpritePikachuStateData1
    add esi, ebx
    mov byte [ebp + esi], 0x06
    xor al, al
    mov [ebp + wd431], al
    mov [ebp + wd432], al
    mov esi, (wSpriteStateData2 + SPRITESTATEDATA2_WALKANIMCOUNTER) - wSpriteStateData1
    add esi, ebx
    mov byte [ebp + esi], 0x11
asm_fc87f:
    mov dl, [ebp + wd431]               ; e
    mov dh, [ebp + wd432]               ; d
    call Func_fc82e
    jc Func_fc8c7
    call SetPikachuOverworldStateFlag2
    mov al, [ebp + ebx + SPRITESTATEDATA1_YPIXELS]
    sub al, dl
    mov cl, al                          ; base Y
    mov al, [ebp + ebx + SPRITESTATEDATA1_XPIXELS]
    sub al, dh
    mov ch, al                          ; base X

    mov esi, (wSpriteStateData2 + SPRITESTATEDATA2_WALKANIMCOUNTER) - wSpriteStateData1
    add esi, ebx
    movzx edx, byte [ebp + esi]
    dec dl                              ; dec a
    mov al, [Pointer_fc8d6 + edx*2]
    mov [ebp + wd431], al
    add al, cl
    mov [ebp + ebx + SPRITESTATEDATA1_YPIXELS], al

    mov al, [Pointer_fc8d6 + edx*2 + 1]
    mov [ebp + wd432], al
    add al, ch
    mov [ebp + ebx + SPRITESTATEDATA1_XPIXELS], al

    dec byte [ebp + esi]
    jnz .ret
    jmp Func_fc835
.ret:
    ret

Func_fc8c7:
    mov al, [ebp + ebx + SPRITESTATEDATA1_YPIXELS]
    sub al, dl
    mov [ebp + ebx + SPRITESTATEDATA1_YPIXELS], al
    mov al, [ebp + ebx + SPRITESTATEDATA1_XPIXELS]
    sub al, dh
    mov [ebp + ebx + SPRITESTATEDATA1_XPIXELS], al
    jmp Func_fc835

Pointer_fc8d6:
    db  0,  0
    db -2,  1
    db -4,  2
    db -2,  3
    db  0,  4
    db -2,  3
    db -4,  2
    db -2,  1
    db  0,  0
    db -2, -1
    db -4, -2
    db -2, -3
    db  0, -4
    db -2, -3
    db -4, -2
    db -2, -1
    db  0,  0

; ===========================================================================
; Func_fc8f8 & asm_fc904 — pret pikachu_follow.asm (State 7)
; ===========================================================================
Func_fc8f8:
    mov esi, wSpritePikachuStateData1MovementStatus - wSpritePikachuStateData1
    add esi, ebx
    mov byte [ebp + esi], 0x07
    mov esi, (wSpriteStateData2 + SPRITESTATEDATA2_WALKANIMCOUNTER) - wSpriteStateData1
    add esi, ebx
    mov byte [ebp + esi], 0x30
asm_fc904:
    call Func_fc82e
    jc Func_fc835
    call SetPikachuOverworldStateFlag2
    mov esi, wSpritePikachuStateData1IntraAnimFrameCounter - wSpritePikachuStateData1
    add esi, ebx
    mov al, [ebp + esi]
    inc al
    cmp al, 0x08
    mov [ebp + esi], al
    jnz .asm_fc91f
    xor al, al
    mov [ebp + esi], al
    inc esi
    mov al, [ebp + esi]
    inc al
    and al, 0x03
    mov [ebp + esi], al
.asm_fc91f:
    call UpdatePikachuWalkingSprite
    mov esi, (wSpriteStateData2 + SPRITESTATEDATA2_WALKANIMCOUNTER) - wSpriteStateData1
    add esi, ebx
    dec byte [ebp + esi]
    jnz .ret
    jmp Func_fc835
.ret:
    ret

; ===========================================================================
; Func_fc92b & asm_fc937 — pret pikachu_follow.asm (State 8)
; ===========================================================================
Func_fc92b:
    mov esi, (wSpriteStateData2 + SPRITESTATEDATA2_WALKANIMCOUNTER) - wSpriteStateData1
    add esi, ebx
    mov byte [ebp + esi], 0x20
    mov esi, wSpritePikachuStateData1MovementStatus - wSpritePikachuStateData1
    add esi, ebx
    mov byte [ebp + esi], 0x08
asm_fc937:
    call Func_fc82e
    jc Func_fc835
    call SetPikachuOverworldStateFlag2
    mov esi, wSpritePikachuStateData1IntraAnimFrameCounter - wSpritePikachuStateData1
    add esi, ebx
    mov al, [ebp + esi]
    inc al
    cmp al, 0x08
    mov [ebp + esi], al
    jnz .asm_fc951
    xor al, al
    mov [ebp + esi], al
    inc esi
    mov al, [ebp + esi]
    xor al, 0x01
    mov [ebp + esi], al
.asm_fc951:
    call UpdatePikachuWalkingSprite
    mov esi, (wSpriteStateData2 + SPRITESTATEDATA2_WALKANIMCOUNTER) - wSpriteStateData1
    add esi, ebx
    dec byte [ebp + esi]
    jnz .ret
    jmp Func_fc835
.ret:
    ret

; ===========================================================================
; Func_fc95d & asm_fc969 — pret pikachu_follow.asm (State 9)
; ===========================================================================
Func_fc95d:
    mov esi, (wSpriteStateData2 + SPRITESTATEDATA2_WALKANIMCOUNTER) - wSpriteStateData1
    add esi, ebx
    mov byte [ebp + esi], 0x20
    mov esi, wSpritePikachuStateData1MovementStatus - wSpritePikachuStateData1
    add esi, ebx
    mov byte [ebp + esi], 0x09
asm_fc969:
    call Func_fc82e
    jc Func_fc835
    call SetPikachuOverworldStateFlag2
    mov esi, wSpritePikachuStateData1IntraAnimFrameCounter - wSpritePikachuStateData1
    add esi, ebx
    mov al, [ebp + esi]
    inc al
    cmp al, 0x08
    mov [ebp + esi], al
    jnz .skip
    xor al, al
    mov [ebp + esi], al
    mov esi, wSpritePikachuStateData1FacingDirection - wSpritePikachuStateData1
    add esi, ebx
    mov al, [ebp + esi]
    call .TurnClockwise
    mov [ebp + esi], al
.skip:
    call UpdatePikachuWalkingSprite
    mov esi, (wSpriteStateData2 + SPRITESTATEDATA2_WALKANIMCOUNTER) - wSpriteStateData1
    add esi, ebx
    dec byte [ebp + esi]
    jnz .ret
    jmp Func_fc835
.ret:
    ret

.TurnClockwise:
    push esi
    mov esi, .Facings
    mov dh, al
.loop:
    mov al, [esi]
    inc esi
    cmp al, dh
    jnz .loop
    mov al, [esi]
    pop esi
    ret

.TurnCounterclockwise:
    push esi
    mov esi, .Facings_End
    mov dh, al
.loop_:
    mov al, [esi]
    dec esi
    cmp al, dh
    jnz .loop_
    mov al, [esi]
    pop esi
    ret

.Facings:
    db SPRITE_FACING_DOWN, SPRITE_FACING_LEFT, SPRITE_FACING_UP, SPRITE_FACING_RIGHT
    db SPRITE_FACING_DOWN, SPRITE_FACING_LEFT, SPRITE_FACING_UP, SPRITE_FACING_RIGHT
.Facings_End: equ $ - 1

; ===========================================================================
; NormalPikachuFollow & asm_fc9c3 — pret pikachu_follow.asm (State 3)
; ===========================================================================
NormalPikachuFollow:
    mov esi, (wSpriteStateData2 + SPRITESTATEDATA2_WALKANIMCOUNTER) - wSpriteStateData1
    add esi, ebx
    mov byte [ebp + esi], 0x08
    mov esi, wSpritePikachuStateData1MovementStatus - wSpritePikachuStateData1
    add esi, ebx
    mov byte [ebp + esi], 0x03
    call AddPikachuStepVector
asm_fc9c3:
    call TryDoubleAddPikachuStepVectorToScreenPixelCoords
    call GetPikachuWalkingAnimationSpeed
    call UpdatePikachuWalkingSprite
    mov esi, (wSpriteStateData2 + SPRITESTATEDATA2_WALKANIMCOUNTER) - wSpriteStateData1
    add esi, ebx
    dec byte [ebp + esi]
    jnz .ret
    call ResetPikachuStepVector
    call ComputePikachuFacingDirection
    mov esi, wSpritePikachuStateData1MovementStatus - wSpritePikachuStateData1
    add esi, ebx
    mov byte [ebp + esi], 0x01
.ret:
    ret

; ===========================================================================
; FastPikachuFollow & asm_fc9ee — pret pikachu_follow.asm (State 5)
; ===========================================================================
FastPikachuFollow:
    mov esi, (wSpriteStateData2 + SPRITESTATEDATA2_WALKANIMCOUNTER) - wSpriteStateData1
    add esi, ebx
    mov byte [ebp + esi], 0x04
    mov esi, wSpritePikachuStateData1MovementStatus - wSpritePikachuStateData1
    add esi, ebx
    mov byte [ebp + esi], 0x05
    call AddPikachuStepVector
asm_fc9ee:
    call DoubleAddPikachuStepVectorToScreenPixelCoords
    call GetPikachuWalkingAnimationSpeed
    call UpdatePikachuWalkingSprite
    mov esi, (wSpriteStateData2 + SPRITESTATEDATA2_WALKANIMCOUNTER) - wSpriteStateData1
    add esi, ebx
    dec byte [ebp + esi]
    jnz .ret
    call ResetPikachuStepVector
    call ComputePikachuFacingDirection
    mov esi, wSpritePikachuStateData1MovementStatus - wSpritePikachuStateData1
    add esi, ebx
    mov byte [ebp + esi], 0x01
.ret:
    ret

; ===========================================================================
; Func_fca0a & asm_fca1c — pret pikachu_follow.asm (State 4)
; ===========================================================================
Func_fca0a:
    mov esi, (wSpriteStateData2 + SPRITESTATEDATA2_WALKANIMCOUNTER) - wSpriteStateData1
    add esi, ebx
    mov byte [ebp + esi], 0x08
    mov esi, wSpritePikachuStateData1MovementStatus - wSpritePikachuStateData1
    add esi, ebx
    mov byte [ebp + esi], 0x04
    call AddPikachuStepVector
    call AddPikachuStepVector
asm_fca1c:
    call DoubleAddPikachuStepVectorToScreenPixelCoords
    call GetPikachuWalkingAnimationSpeed
    call UpdatePikachuWalkingSprite
    mov esi, (wSpriteStateData2 + SPRITESTATEDATA2_WALKANIMCOUNTER) - wSpriteStateData1
    add esi, ebx
    dec byte [ebp + esi]
    jnz .ret
    call ResetPikachuStepVector
    call ComputePikachuFacingDirection
    mov esi, wSpritePikachuStateData1MovementStatus - wSpritePikachuStateData1
    add esi, ebx
    mov byte [ebp + esi], 0x01
.ret:
    ret

; ===========================================================================
; AddPikachuStepVector — pret pikachu_follow.asm:AddPikachuStepVector
; ===========================================================================
AddPikachuStepVector:
    mov dl, [ebp + ebx + SPRITESTATEDATA1_YSTEPVECTOR]
    mov dh, [ebp + ebx + SPRITESTATEDATA1_XSTEPVECTOR]
    mov esi, (wSpriteStateData2 + SPRITESTATEDATA2_MAPY) - wSpriteStateData1
    add esi, ebx
    mov al, [ebp + esi]
    add al, dl
    mov [ebp + esi], al
    inc esi
    mov al, [ebp + esi]
    add al, dh
    mov [ebp + esi], al
    ret

; ===========================================================================
; TryDoubleAddPikachuStepVectorToScreenPixelCoords / DoubleAdd / Add
; ===========================================================================
TryDoubleAddPikachuStepVectorToScreenPixelCoords:
    mov al, [ebp + wWalkBikeSurfState]
    cmp al, 0x01                        ; biking
    jnz AddPikachuStepVectorToScreenPixelCoords
    mov al, [ebp + wMovementFlags]
    test al, (1 << BIT_LEDGE_OR_FISHING)
    jnz AddPikachuStepVectorToScreenPixelCoords
DoubleAddPikachuStepVectorToScreenPixelCoords:
    mov al, [ebp + ebx + SPRITESTATEDATA1_YSTEPVECTOR]
    shl al, 2
    add al, [ebp + ebx + SPRITESTATEDATA1_YPIXELS]
    mov [ebp + ebx + SPRITESTATEDATA1_YPIXELS], al

    mov al, [ebp + ebx + SPRITESTATEDATA1_XSTEPVECTOR]
    shl al, 2
    add al, [ebp + ebx + SPRITESTATEDATA1_XPIXELS]
    mov [ebp + ebx + SPRITESTATEDATA1_XPIXELS], al
    ret

AddPikachuStepVectorToScreenPixelCoords:
    mov al, [ebp + ebx + SPRITESTATEDATA1_YSTEPVECTOR]
    add al, al
    add al, [ebp + ebx + SPRITESTATEDATA1_YPIXELS]
    mov [ebp + ebx + SPRITESTATEDATA1_YPIXELS], al

    mov al, [ebp + ebx + SPRITESTATEDATA1_XSTEPVECTOR]
    add al, al
    add al, [ebp + ebx + SPRITESTATEDATA1_XPIXELS]
    mov [ebp + ebx + SPRITESTATEDATA1_XPIXELS], al
    ret

; ===========================================================================
; ResetPikachuStepVector — pret pikachu_follow.asm:ResetPikachuStepVector
; ===========================================================================
ResetPikachuStepVector:
    mov byte [ebp + ebx + SPRITESTATEDATA1_YSTEPVECTOR], 0
    mov byte [ebp + ebx + SPRITESTATEDATA1_XSTEPVECTOR], 0
    ret

; ===========================================================================
; GetPikachuWalkingAnimationSpeed — pret pikachu_follow.asm:GetPikachuWalkingAnimationSpeed
; ===========================================================================
GetPikachuWalkingAnimationSpeed:
    call ComparePikachuHappinessTo80
    mov dh, 0x02
    jnc .happy
    mov dh, 0x05
.happy:
    mov esi, wSpritePikachuStateData1IntraAnimFrameCounter - wSpritePikachuStateData1
    add esi, ebx
    mov al, [ebp + esi]
    inc al
    cmp al, dh
    jnz .dont_reset
    xor al, al
.dont_reset:
    mov [ebp + esi], al
    jnz .ret
    inc esi
    mov al, [ebp + esi]
    inc al
    and al, 0x03
    mov [ebp + esi], al
.ret:
    ret

; ===========================================================================
; UpdatePikachuWalkingSprite — pret pikachu_follow.asm:UpdatePikachuWalkingSprite
; ===========================================================================
UpdatePikachuWalkingSprite:
    test byte [ebp + wPikachuOverworldStateFlags], 0x08 ; bit 3
    jnz .uninitialized
    mov esi, (wSpriteStateData2 + SPRITESTATEDATA2_IMAGEBASEOFFSET) - wSpriteStateData1
    add esi, ebx
    mov al, [ebp + esi]
    dec al
    ror al, 4                           ; swap a
    mov dh, al                          ; d = (ImageBaseOffset - 1) << 4
    mov al, [ebp + wMovementFlags]
    test al, (1 << BIT_SPINNING)
    jnz .copy_player
    mov esi, wSpritePikachuStateData1FacingDirection - wSpritePikachuStateData1
    add esi, ebx
    mov al, [ebp + esi]
    or dh, al                           ; d |= FacingDirection
    mov al, [ebp + wFontLoaded]
    test al, (1 << BIT_FONT_LOADED)
    jz .normal_get_sprite_index
    call Func_fcae2
    jc .ret
    jmp .load_sprite_index

.normal_get_sprite_index:
    mov esi, wSpritePikachuStateData1AnimFrameCounter - wSpritePikachuStateData1
    add esi, ebx
    mov al, [ebp + esi]
    or dh, al                           ; d |= AnimFrameCounter

.load_sprite_index:
    mov esi, wSpritePikachuStateData1ImageIndex - wSpritePikachuStateData1
    add esi, ebx
    mov [ebp + esi], dh                 ; ImageIndex = d
.ret:
    ret

.uninitialized:
    mov esi, wSpritePikachuStateData1ImageIndex - wSpritePikachuStateData1
    add esi, ebx
    mov byte [ebp + esi], 0xFF
    ret

.copy_player:
    mov al, [ebp + wSpritePlayerStateData1ImageIndex]
    and al, 0x0F
    or al, dh
    mov [ebp + wSpritePikachuStateData1ImageIndex], al
    ret

; ===========================================================================
; Func_fcae2 — pret pikachu_follow.asm:Func_fcae2
; ===========================================================================
Func_fcae2:
    mov esi, (wSpriteStateData2 + SPRITESTATEDATA2_MAPY) - wSpriteStateData1
    add esi, ebx
    mov al, [ebp + wYCoord]
    add al, 4
    cmp al, [ebp + esi]
    jnz .on_screen
    inc esi
    mov al, [ebp + wXCoord]
    add al, 4
    cmp al, [ebp + esi]
    jnz .on_screen
    mov esi, wSpritePikachuStateData1ImageIndex - wSpritePikachuStateData1
    add esi, ebx
    mov byte [ebp + esi], 0xFF
    stc
    ret

.on_screen:
    clc
    ret

; ===========================================================================
; IsPikachuRightNextToPlayer — pret pikachu_follow.asm:IsPikachuRightNextToPlayer
; ===========================================================================
IsPikachuRightNextToPlayer:
    push ebx
    push edx
    push esi
    mov ebx, wSpritePikachuStateData1PictureID
    mov al, [ebp + wXCoord]
    add al, 4
    mov dh, al                          ; d = wXCoord + 4
    mov al, [ebp + wYCoord]
    add al, 4
    mov dl, al                          ; e = wYCoord + 4
    mov esi, (wSpriteStateData2 + SPRITESTATEDATA2_MAPY) - wSpriteStateData1
    add esi, ebx
    mov al, [ebp + esi]
    sub al, dl
    jz .equal
    cmp al, 0xFF
    jz .one_away
    cmp al, 0x01
    jz .one_away
    jmp .bad

.one_away:
    mov esi, (wSpriteStateData2 + SPRITESTATEDATA2_MAPX) - wSpriteStateData1
    add esi, ebx
    mov al, [ebp + esi]
    sub al, dh
    jz .good
    jmp .bad

.equal:
    mov esi, (wSpriteStateData2 + SPRITESTATEDATA2_MAPX) - wSpriteStateData1
    add esi, ebx
    mov al, [ebp + esi]
    sub al, dh
    cmp al, 0xFF
    jz .good
    cmp al, 0x01
    jz .good
    and al, al
    jz .good
    jmp .bad

.good:
    pop esi
    pop edx
    pop ebx
    stc
    ret

.bad:
    pop esi
    pop edx
    pop ebx
    xor al, al
    clc
    ret

; ===========================================================================
; GetPikachuFacingDirectionAndReturnToE — pret pikachu_follow.asm:1110
; GetPikachuFacingDirection             — pret pikachu_follow.asm:1115
; ===========================================================================
GetPikachuFacingDirectionAndReturnToE:
    call GetPikachuFacingDirection
    mov dl, al                          ; ld e, a
    ret

GetPikachuFacingDirection:
    mov ebx, wSpritePikachuStateData1PictureID
    mov al, [ebp + wXCoord]
    add al, 4
    mov dh, al                          ; ld d, a
    mov al, [ebp + wYCoord]
    add al, 4
    mov dl, al                          ; ld e, a
    mov esi, (wSpriteStateData2 + SPRITESTATEDATA2_MAPY) - wSpriteStateData1
    add esi, ebx
    mov al, [ebp + esi]                 ; ld a, [hl] — Pikachu's map Y
    cmp al, dl                          ; cp e
    je .asm_fcb71
    jae .asm_fcb6e                      ; jr nc
    mov al, SPRITE_FACING_UP
    ret

.asm_fcb6e:
    mov al, SPRITE_FACING_DOWN
    ret

.asm_fcb71:
    mov esi, (wSpriteStateData2 + SPRITESTATEDATA2_MAPX) - wSpriteStateData1
    add esi, ebx
    mov al, [ebp + esi]                 ; ld a, [hl] — Pikachu's map X
    cmp al, dh                          ; cp d
    je .asm_fcb81
    jae .asm_fcb7e                      ; jr nc
    mov al, SPRITE_FACING_LEFT
    ret

.asm_fcb7e:
    mov al, SPRITE_FACING_RIGHT
    ret

.asm_fcb81:
    mov al, 0xFF                        ; ld a, $ff ; standing
    ret

; ===========================================================================
; ClearPikachuFollowCommandBuffer — pret pikachu_follow.asm:1154
; ===========================================================================
ClearPikachuFollowCommandBuffer:
    push ebx                                            ; push bc
    mov esi, wPikachuFollowCommandBufferSize            ; ld hl, ...
    mov byte [ebp + esi], 0xFF                          ; ld [hl], $ff
    inc esi                                             ; inc hl
    mov bx, 0x10                                        ; ld bc, $10
    xor al, al                                          ; xor a
    call FillMemory
    pop ebx                                             ; pop bc
    ret

; ===========================================================================
; AppendPikachuFollowCommandToBuffer — pret pikachu_follow.asm:1165
; ===========================================================================
AppendPikachuFollowCommandToBuffer:
    mov esi, wPikachuFollowCommandBufferSize            ; ld hl, wPikachuFollowCommandBufferSize
    inc byte [ebp + esi]                                ; inc [hl]
    mov dl, [ebp + esi]                                 ; ld e, [hl]
    mov dh, 0                                           ; ld d, 0
    movzx esi, dx                                       ; ld hl, buffer / add hl, de
    add esi, wPikachuFollowCommandBuffer
    mov [ebp + esi], al                                 ; ld [hl], a
    ret

; ===========================================================================
; RefreshPikachuFollow — pret pikachu_follow.asm:1175
; ===========================================================================
RefreshPikachuFollow:
    call ClearPikachuFollowCommandBuffer
    call ComputePikachuFollowCommand
    jc .ret                                             ; ret c
    call AppendPikachuFollowCommandToBuffer
.ret:
    ret

; ===========================================================================
; ComputePikachuFollowCommand — pret pikachu_follow.asm:1182
; ===========================================================================
ComputePikachuFollowCommand:
    mov ebx, wSpritePikachuStateData1PictureID
    mov esi, (wSpriteStateData2 + SPRITESTATEDATA2_MAPY) - wSpriteStateData1
    add esi, ebx
    mov al, [ebp + wYCoord]             ; ld a, [wYCoord]
    add al, 4                           ; add $4
    sub al, [ebp + esi]                 ; sub [hl]
    je .checkXCoord                     ; jr z
    jb .pikaAbovePlayer                 ; jr c
    call CheckAbsoluteValueLessThan2
    jb .return1                         ; jr c
    mov al, 0x05
    and al, al
    ret

.return1:
    mov al, 0x01
    and al, al
    ret

.pikaAbovePlayer:
    call CheckAbsoluteValueLessThan2
    jb .return2                         ; jr c
    mov al, 0x06
    and al, al
    ret

.return2:
    mov al, 0x02
    and al, al
    ret

.checkXCoord:
    mov esi, (wSpriteStateData2 + SPRITESTATEDATA2_MAPX) - wSpriteStateData1
    add esi, ebx
    mov al, [ebp + wXCoord]             ; ld a, [wXCoord]
    add al, 4                           ; add $4
    sub al, [ebp + esi]                 ; sub [hl]
    je .pikachuOnTopOfPlayer            ; jr z
    jb .pikaToLeftOfPlayer              ; jr c
    call CheckAbsoluteValueLessThan2
    jb .return4                         ; jr c
    mov al, 0x08
    and al, al
    ret

.return4:
    mov al, 0x04
    and al, al
    ret

.pikaToLeftOfPlayer:
    call CheckAbsoluteValueLessThan2
    jb .return3                         ; jr c
    mov al, 0x07
    and al, al
    ret

.return3:
    mov al, 0x03
    and al, al
    ret

.pikachuOnTopOfPlayer:
    stc                                 ; scf
    ret

; ===========================================================================
; CheckAbsoluteValueLessThan2 — pret pikachu_follow.asm:1249
; ===========================================================================
CheckAbsoluteValueLessThan2:
    jae .positive                       ; jr nc
    not al                              ; cpl
    inc al                              ; inc a
.positive:
    cmp al, 0x02                        ; cp $2
    ret

; ===========================================================================
; Func_fcc08 — pret pikachu_follow.asm:Func_fcc08
; ===========================================================================
Func_fcc08:
    call Func_fcc23
    jnc .ret
    mov al, [ebp + wMovementFlags]
    test al, (1 << BIT_LEDGE_OR_FISHING)
    jnz .asm_fcc1b
    call Func_fcc42
    jc .ret
    call AppendPikachuFollowCommandToBuffer
    ret

.asm_fcc1b:
    call Func_fcc64
    jc .ret
    call AppendPikachuFollowCommandToBuffer
.ret:
    ret

; ===========================================================================
; Func_fcc23 — pret pikachu_follow.asm:Func_fcc23
; ===========================================================================
Func_fcc23:
    test byte [ebp + wPikachuOverworldStateFlags], 0x20  ; bit 5
    jnz .asm_fcc40
    test byte [ebp + wPikachuOverworldStateFlags], 0x80  ; bit 7
    jnz .asm_fcc40
    test byte [ebp + wPikachuSpawnStateFlags], (1 << BIT_PIKACHU_SPAWN_STARTER)
    jz .asm_fcc40
    mov al, [ebp + wWalkBikeSurfState]
    and al, al
    jnz .asm_fcc40
    stc
    ret

.asm_fcc40:
    clc
    ret

; ===========================================================================
; Func_fcc42 — pret pikachu_follow.asm:Func_fcc42
; ===========================================================================
Func_fcc42:
    mov al, [ebp + wPlayerDirection]
    test al, (1 << PLAYER_DIR_BIT_UP)
    jnz .asm_fcc58
    test al, (1 << PLAYER_DIR_BIT_DOWN)
    jnz .asm_fcc5b
    test al, (1 << PLAYER_DIR_BIT_LEFT)
    jnz .asm_fcc5e
    test al, (1 << PLAYER_DIR_BIT_RIGHT)
    jnz .asm_fcc61
    stc
    ret

.asm_fcc58:
    mov al, 0x02
    clc
    ret

.asm_fcc5b:
    mov al, 0x01
    clc
    ret

.asm_fcc5e:
    mov al, 0x03
    clc
    ret

.asm_fcc61:
    mov al, 0x04
    clc
    ret

; ===========================================================================
; Func_fcc64 — pret pikachu_follow.asm:Func_fcc64
; ===========================================================================
Func_fcc64:
    test byte [ebp + wPikachuOverworldStateFlags], 0x40 ; bit 6
    jz .asm_fcc6e
    and byte [ebp + wPikachuOverworldStateFlags], ~0x40 ; res 6
    stc                                                 ; CF=1 so caller's ret c fires
    ret

.asm_fcc6e:
    or byte [ebp + wPikachuOverworldStateFlags], 0x40   ; set 6
    mov al, [ebp + wPlayerDirection]
    test al, (1 << PLAYER_DIR_BIT_UP)
    jnz .asm_fcc86
    test al, (1 << PLAYER_DIR_BIT_DOWN)
    jnz .asm_fcc89
    test al, (1 << PLAYER_DIR_BIT_LEFT)
    jnz .asm_fcc8c
    test al, (1 << PLAYER_DIR_BIT_RIGHT)
    jnz .asm_fcc8f
    stc
    ret

.asm_fcc86:
    mov al, 0x06
    clc
    ret

.asm_fcc89:
    mov al, 0x05
    clc
    ret

.asm_fcc8c:
    mov al, 0x07
    clc
    ret

.asm_fcc8f:
    mov al, 0x08
    clc
    ret

; ===========================================================================
; Func_fcc92 — pret pikachu_follow.asm:Func_fcc92
; ===========================================================================
Func_fcc92:
    mov esi, wPikachuFollowCommandBufferSize
    mov al, [ebp + esi]
    cmp al, 0xFF
    jz .asm_fccb0
    and al, al
    jz .asm_fccb0
    dec byte [ebp + esi]                ; dec [hl]
    movzx ecx, al                       ; ecx = old size
    mov dl, al                          ; dl = old size
    mov esi, wPikachuFollowCommandBuffer
    add esi, ecx                        ; esi = buffer + old size
    inc dl                              ; count = old size + 1
    mov al, 0xFF
.asm_fcca8:
    mov dh, [ebp + esi]                 ; d = [hl]
    mov [ebp + esi], al                 ; [hl] = a
    dec esi                             ; hld
    mov al, dh                          ; a = d
    dec dl                              ; dec e
    jnz .asm_fcca8
    and al, al                          ; clears CF
    ret

.asm_fccb0:
    stc
    ret

; ===========================================================================
; ComputePikachuFacingDirection — pret pikachu_follow.asm:ComputePikachuFacingDirection
; ===========================================================================
ComputePikachuFacingDirection:
    call GetPikachuFollowCommandIfBufferSizeNonzero
    and al, al
    jz .check_y
    dec al
    and al, 0x03
    shl al, 2                           ; add a; add a
    jmp .load

.check_y:
    mov al, [ebp + wYCoord]
    add al, 4
    mov dh, al                          ; d = wYCoord + 4
    mov al, [ebp + wXCoord]
    add al, 4
    mov dl, al                          ; e = wXCoord + 4
    mov al, [ebp + wSpritePikachuStateData2MapY]
    cmp al, dh
    jz .check_x
    jb .pika_facing_down                ; jr c
    mov al, SPRITE_FACING_UP
    jmp .load
.pika_facing_down:
    mov al, SPRITE_FACING_DOWN
    jmp .load

.check_x:
    mov al, [ebp + wSpritePikachuStateData2MapX]
    cmp al, dl
    jz .copy_from_player
    jb .pika_facing_right               ; jr c
    mov al, SPRITE_FACING_LEFT
    jmp .load
.pika_facing_right:
    mov al, SPRITE_FACING_RIGHT
    jmp .load

.copy_from_player:
    mov al, [ebp + wSpritePlayerStateData1FacingDirection]
.load:
    mov [ebp + wSpritePikachuStateData1FacingDirection], al
    ret

; ===========================================================================
; GetPikachuFollowCommand — pret pikachu_follow.asm:GetPikachuFollowCommand
; ===========================================================================
GetPikachuFollowCommand:
    mov al, [ebp + wPikachuFollowCommandBufferSize]
    cmp al, 0xFF
    jz .asm_fccff
    movzx edx, al
    mov al, [ebp + wPikachuFollowCommandBuffer + edx]
    ret
.asm_fccff:
    xor al, al
    ret

; ===========================================================================
; GetPikachuFollowCommandIfBufferSizeNonzero — pret pikachu_follow.asm
; ===========================================================================
GetPikachuFollowCommandIfBufferSizeNonzero:
    mov al, [ebp + wPikachuFollowCommandBufferSize]
    cmp al, 0xFF
    jz .default
    and al, al
    jz .default
    movzx edx, al
    mov al, [ebp + wPikachuFollowCommandBuffer + edx]
    ret
.default:
    xor al, al
    ret

; ===========================================================================
; AreThereAtLeastTwoStepsInPikachuFollowCommandBuffer — pret pikachu_follow.asm
; ===========================================================================
AreThereAtLeastTwoStepsInPikachuFollowCommandBuffer:
    mov al, [ebp + wPikachuFollowCommandBufferSize]
    cmp al, 0xFF
    jz .no_steps
    cmp al, 0x02
    jae .set_carry
.no_steps:
    clc
    ret
.set_carry:
    stc
    ret

; ===========================================================================
; WillPikachuSpawnOnTheScreen — pret pikachu_follow.asm:WillPikachuSpawnOnTheScreen
; ===========================================================================
WillPikachuSpawnOnTheScreen:
    movzx esi, byte [ebp + hCurrentSpriteOffset]        ; $F0
    mov bl, [ebp + esi + wSpriteStateData2 + SPRITESTATEDATA2_MAPY]
    mov al, [ebp + wYCoord]
    cmp al, bl
    jz .same_y
    jae .not_on_screen
    add al, (18 / 2) - 1                                ; 8 (SCREEN_HEIGHT / 2 - 1)
    cmp al, bl
    jb .not_on_screen

.same_y:
    mov bl, [ebp + esi + wSpriteStateData2 + SPRITESTATEDATA2_MAPX]
    mov al, [ebp + wXCoord]
    cmp al, bl
    jz .same_x
    jae .not_on_screen
    add al, (20 / 2) - 1                                ; 9 (SCREEN_WIDTH / 2 - 1)
    cmp al, bl
    jb .not_on_screen

.same_x:
    ; New window locations where those boxes are actually drawn (dialog 87,152,
    ; list 199,16 etc. as g_windows on 40×25), not old wTileMap >=$60 at 20×18.
    ; Pikachu hide at new constants: 16×16 YPIXELS/XPIXELS vs g_windows.
    push esi
    push edi
    push ebp
    cmp dword [g_bg_whiteout], 0
    jne .pika_win_visible
    cmp word [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR], 0
    je .pika_win_visible
    cmp dword [g_window_count], 0
    je .pika_win_visible
    movzx esi, byte [ebp + hCurrentSpriteOffset] ; 0xF0
    movzx eax, byte [ebp + esi + wSpriteStateData1 + SPRITESTATEDATA1_YPIXELS]
    movzx ecx, byte [ebp + esi + wSpriteStateData1 + SPRITESTATEDATA1_XPIXELS]
    ; ECX=left, EAX=top, +16 right/bottom
    mov edx, ecx
    add edx, 16                          ; right
    mov ebx, eax
    add ebx, 16                          ; bottom
    xor esi, esi                         ; i=0
.pika_win_loop:
    cmp esi, [g_window_count]
    jae .pika_win_visible
    imul edi, esi, 32
    add edi, g_windows
    mov ebp, [edi + 0]                   ; WIN_WX
    cmp edx, ebp
    jbe .pika_win_next
    mov ebp, [edi + 8]                   ; WIN_CLIP_W
    add ebp, [edi + 0]                   ; win right
    cmp ecx, ebp
    jae .pika_win_next
    mov ebp, [edi + 4]                   ; WIN_WY
    cmp ebx, ebp
    jbe .pika_win_next
    mov ebp, [edi + 12]                  ; WIN_MAX_Y
    cmp eax, ebp
    jae .pika_win_next
    ; overlap → hide
    pop ebp
    pop edi
    pop esi
    jmp .not_on_screen
.pika_win_next:
    inc esi
    jmp .pika_win_loop
.pika_win_visible:
    pop ebp
    pop edi
    pop esi
    ; Grass priority still needs tile at stand position (faithful PRET, now 40-wide)
    call .GetNPCCurrentTile              ; ESI = lower-left wTileMap 40
    mov al, [ebp + esi]
    mov dl, al                           ; ld e,a for .on_screen grass cmp
    jmp .on_screen

.not_on_screen:
    movzx esi, byte [ebp + hCurrentSpriteOffset]
    mov byte [ebp + esi + wSpriteStateData1 + SPRITESTATEDATA1_IMAGEINDEX], 0xFF
    stc
    ret

.on_screen:
    movzx esi, byte [ebp + hCurrentSpriteOffset]
    mov al, [ebp + wGrassTile]
    cmp al, dl                                          ; cp e
    mov al, 0
    jnz .priority
    mov al, 0x80
.priority:
    mov [ebp + esi + wSpriteStateData2 + SPRITESTATEDATA2_GRASSPRIORITY], al
    clc
    ret

.GetNPCCurrentTile:
    movzx esi, byte [ebp + hCurrentSpriteOffset]
    movzx eax, byte [ebp + esi + wSpriteStateData1 + SPRITESTATEDATA1_YPIXELS]
    add eax, 4
    and eax, 0xF0
    shr eax, 4                                          ; row = (YPixels + 4 & 0xF0) / 16
    imul eax, eax, SCREEN_WIDTH                         ; row * SCREEN_WIDTH

    movzx ecx, byte [ebp + esi + wSpriteStateData1 + SPRITESTATEDATA1_XPIXELS]
    add ecx, 2
    shr ecx, 3                                          ; col = (XPixels + 2) / 8
    add ecx, SCREEN_WIDTH                               ; + SCREEN_WIDTH (one row down)

    lea esi, [wTileMap + eax + ecx]
    ret

; ===========================================================================
; ComparePikachuHappinessTo80 — pret pikachu_follow.asm:ComparePikachuHappinessTo80
; ===========================================================================
ComparePikachuHappinessTo80:
    cmp byte [ebp + wPikachuHappiness], 80
    ret
