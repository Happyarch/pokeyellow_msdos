; battle_transitions.asm — mirror of pret engine/battle/battle_transitions.asm.
;
; The overworld→battle wipe animations, re-parameterized for the port's 40×25
; canvas per the maintainer's 2026-08-07 ruling (adjust the geometry, do not
; letterbox from 20×18). Every derived count is written as its FORMULA in
; SCREEN_WIDTH/SCREEN_HEIGHT terms — several pret literals were 20×18 dimension
; collisions (see docs/current_plan_battle_transitions.md, all parameters
; simulation-verified there).
;
; The wipe operates directly on W_TILEMAP (stride 40): the caller
; (DoBattleTransitionAndInitBattleVariables, core.asm) has already switched
; render_bg to its flat-canvas path, and W_TILEMAP holds the current overworld
; view (maintained by LoadCurrentMapView). hAutoBGTransferEnabled is inert in
; the port (the vblank auto-transfer was retired); its writes are kept as
; vestigial bookkeeping, and pacing comes entirely from DelayFrame — render_bg
; runs only from DelayFrame, so every DelayFrame publishes the whole canvas
; (pret's batching semantics fall out for free).
;
; Register map: A=AL, BC=BX (B=BH, C=BL), HL=ESI, EBP = GB memory base.
; Signed tilemap-step values are held in 32-bit registers (ECX/EDX) where pret
; used 16-bit bc/de arithmetic.

%include "gb_macros.inc"
%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "coords.inc"

bits 32

global BattleTransition
global BattleTransitions
global GetBattleTransitionID_WildOrTrainer
global GetBattleTransitionID_CompareLevels
global GetBattleTransitionID_IsDungeonMap
global LoadBattleTransitionTile
global BattleTransitionTile
global BattleTransition_BlackScreen
global BattleTransition_Spiral
global BattleTransition_InwardSpiral
global BattleTransition_InwardSpiral_
global BattleTransition_OutwardSpiral_
global FlashScreen
global BattleTransition_FlashScreen_
global BattleTransition_FlashScreenPalettes
global BattleTransition_Shrink
global BattleTransition_Split
global BattleTransition_CopyTiles1
global BattleTransition_CopyTiles2
global BattleTransition_VerticalStripes
global BattleTransition_VerticalStripes_
global BattleTransition_HorizontalStripes
global BattleTransition_HorizontalStripes_
global BattleTransition_Circle
global BattleTransition_FlashScreen
global BattleTransition_Circle_Sub1
global BattleTransition_TransferDelay3
global BattleTransition_DoubleCircle
global BattleTransition_Circle_Sub2
global BattleTransition_Circle_Sub3

extern Delay3                     ; src/home/palettes.asm
extern DelayFrame                 ; src/home/vblank.asm
extern DelayFrames                ; src/home/delay.asm (In: BL = frame count)
extern CopyData                   ; src/home/copy.asm (ESI src, EDX dst, BX count)
extern FillMemory                 ; src/home/copy2.asm (ESI dest, BX count, AL fill)
extern CopyVideoData              ; src/home/copy2.asm (ESI VRAM dest, EDX flat src, BL tiles)
extern UpdateCGBPal_BGP           ; src/home/cgb_palettes.asm
extern UpdateCGBPal_OBP0          ; src/home/cgb_palettes.asm
extern UpdateCGBPal_OBP1          ; src/home/cgb_palettes.asm
extern hide_window                ; src/ppu/ppu.asm
extern spr_dos_sy                 ; src/ppu/ppu.asm — per-OAM-entry DOS canvas Y
extern DungeonMaps1               ; src/data/maps/dungeon_maps.asm
extern DungeonMaps2               ; src/data/maps/dungeon_maps.asm

; the three GetBattleTransitionID functions set the first three bits of c
; bit 0: set if trainer battle
; bit 1: set if enemy is at least 3 levels higher than player
; bit 2: set if dungeon map
BIT_TRAINER_BATTLE_TRANSITION  equ 0
BIT_STRONGER_BATTLE_TRANSITION equ 1
BIT_DUNGEON_BATTLE_TRANSITION  equ 2

; D = the port's width/height excess. pret's inward-spiral leg arithmetic
; silently encodes W−H=2; every use below is written in terms of this.
BT_WH_DELTA equ SCREEN_WIDTH - SCREEN_HEIGHT   ; 15 (GB: 2)

section .data

; Battle-transition dispatch table (pret: dw entries indexed by 2*c).
BattleTransitions:
    dd BattleTransition_DoubleCircle      ; %000
    dd BattleTransition_Spiral            ; %001
    dd BattleTransition_Circle            ; %010
    dd BattleTransition_Spiral            ; %011
    dd BattleTransition_HorizontalStripes ; %100
    dd BattleTransition_Shrink            ; %101
    dd BattleTransition_VerticalStripes   ; %110
    dd BattleTransition_Split             ; %111

; Regenerated 40×25 arc tables + HALF_CIRCLE_STEPS / BT_ARC_ENTRY_SIZE /
; CIRCLE_LEFT / CIRCLE_RIGHT (Tier-1 data; replaces pret's hand-drawn
; BattleTransition_CircleData1-5 / HalfCircle1-2 20×18 tables).
%include "assets/battle_transition_arcs.inc"

BattleTransitionTile: incbin "../gfx/overworld/battle_transition.2bpp"

; pret's packed `dc 3,3,2,1`-style rows, precomputed to bytes (sanity anchor:
; dc 3,2,1,0 = $E4 = normal BGP).
BattleTransition_FlashScreenPalettes:
    db 0xF9, 0xFE, 0xFF, 0xFE, 0xF9, 0xE4
    db 0x90, 0x40, 0x00, 0x40, 0x90, 0xE4
    db 1 ; end

; Port-only: Bresenham row-step schedules for the decoupled-axis Shrink/Split
; (12/20 and 13/20 — columns step every iteration, rows only on these, so both
; axes reach center together; simulation-verified all-black exactly at iter 20).
ShrinkRowSchedule: db 0,1,0,1,1,0,1,0,1,1,0,1,0,1,1,0,1,0,1,1   ; 12 of 20
SplitRowSchedule:  db 0,1,0,1,1,0,1,1,0,1,1,0,1,1,0,1,1,0,1,1   ; 13 of 20

section .text

BattleTransition:
    mov byte [ebp + hAutoBGTransferEnabled], 1   ; vestigial (inert in the port)
    call Delay3
    xor al, al
    mov [ebp + H_WY], al
    ; DEVIATION{class=HAL; pret=engine/battle/battle_transitions.asm:BattleTransition; behavior=calls hide_window in addition to the hWY=0 write; evidence=the port has no GB window double-tilemap trick - the battle screen is the BG plane and a stale overworld dialog window descriptor would float above the wipe; lifetime=permanent, window-compositor HAL}
    call hide_window
    dec al                                        ; a = $ff
    mov [ebp + W_UPDATE_SPRITES_ENABLED], al
    call DelayFrame

; Determine which OAM block is being used by the enemy trainer sprite (if there
; is one). NOTE (faithful): with hSpriteIndex = 0 (wild battle) the 8-bit
; counter wraps and this loop runs 256 iterations reading up through ~$D0F2 —
; exactly pret's behavior (bounded, read-only).
    mov esi, W_SPRITE_PLAYER_IMAGE_INDEX
    mov cl, [ebp + hSpriteIndex]                  ; enemy trainer sprite index (0 if wild)
    xor bh, bh                                    ; b = 0
.loop1:
    mov al, [ebp + esi]
    cmp al, 0xFF
    je .skip1
    inc bh
.skip1:
    add esi, SPRITESTATEDATA1_LENGTH
    dec cl
    jnz .loop1

; Clear OAM except for the blocks used by the player and enemy trainer sprites.
; pret's `swap a / cp l` low-address-byte trick still works here: the low byte
; of the GB offset (W_SHADOW_OAM = $C300 is 256-aligned) equals block*16.
    mov esi, W_SHADOW_OAM + 4 * 4                 ; wShadowOAMSprite04
    mov cl, 9
.loop2:
    mov al, bh
    rol al, 4                                     ; swap a (b*16)
    mov edx, esi
    cmp al, dl                                    ; cp l
    je .skip2                                     ; skip the enemy trainer's block
    push esi
    push ebx
    mov bx, 4 * 4                                 ; OBJ_SIZE * 4
    xor al, al
    call FillMemory
    ; DEVIATION{class=HAL; pret=engine/battle/battle_transitions.asm:BattleTransition; behavior=additionally forces spr_dos_sy off-canvas for the cleared block's four OAM entries; evidence=wUpdateSpritesEnabled=$ff freezes PrepareOAMData AND the shadow-to-OAM DMA in this port (vblank.asm update_oam gate) so a cleared shadow OAM never reaches the compositor, unlike the GB where OAM DMA always runs; lifetime=permanent, OAM-publish HAL}
    mov ebx, esi
    sub ebx, W_SHADOW_OAM
    shr ebx, 2                                    ; first OAM entry index of this block
    mov dword [spr_dos_sy + ebx * 4 + 0], RENDER_H
    mov dword [spr_dos_sy + ebx * 4 + 4], RENDER_H
    mov dword [spr_dos_sy + ebx * 4 + 8], RENDER_H
    mov dword [spr_dos_sy + ebx * 4 + 12], RENDER_H
    pop ebx
    pop esi
.skip2:
    add esi, 4 * 4                                ; OBJ_SIZE * 4
    dec cl
    jnz .loop2

    call Delay3
    call LoadBattleTransitionTile
    xor ebx, ebx                                  ; ld bc, 0
    mov al, [ebp + wLinkState]
    cmp al, LINK_STATE_BATTLING
    je .linkBattle
    call GetBattleTransitionID_WildOrTrainer
    call GetBattleTransitionID_CompareLevels
    call GetBattleTransitionID_IsDungeonMap
.linkBattle:
    movzx eax, bl
    jmp [BattleTransitions + eax * 4]             ; pret: jp hl via the dw table

GetBattleTransitionID_WildOrTrainer:
    mov al, [ebp + wCurOpponent]
    cmp al, OPP_ID_OFFSET
    jae .trainer                                  ; jr nc
    and bl, ~(1 << BIT_TRAINER_BATTLE_TRANSITION)
    ret
.trainer:
    or bl, (1 << BIT_TRAINER_BATTLE_TRANSITION)
    ret

; BUG{class=data-model; pret=engine/battle/battle_transitions.asm:GetBattleTransitionID_CompareLevels; behavior=with no live party mon (the Oak-intro scripted Pikachu battle runs with an empty party) the fainted-scan walks past the party HP words into unrelated WRAM until a nonzero pair is found; evidence=docs/bugs_and_glitches.md:37 "Battle transitions fail to account for scripted battles" - pret has no bound on the .faintedLoop; lifetime=permanent latent Gen-1 behavior, fix under BUG_FIX_LEVEL >= 2 bounds the scan by wPartyCount}
GetBattleTransitionID_CompareLevels:
    mov esi, wPartyMon1HP
%if BUG_FIX_LEVEL >= 2
    movzx ecx, byte [ebp + wPartyCount]
%endif
.faintedLoop:
%if BUG_FIX_LEVEL >= 2
    test ecx, ecx
    jz .highLevelEnemy                            ; empty/all-fainted party: enemy is "stronger"
    dec ecx
%endif
    mov al, [ebp + esi]                           ; ld a, [hli]
    inc esi
    or al, [ebp + esi]                            ; or [hl]
    jnz .notFainted
    add esi, PARTYMON_STRUCT_LENGTH - 1
    jmp .faintedLoop
.notFainted:
    add esi, MON_LEVEL - (MON_HP + 1)
    mov al, [ebp + esi]
    add al, 3
    mov dl, al                                    ; ld e, a
    mov al, [ebp + wCurEnemyLevel]
    sub al, dl
    jnc .highLevelEnemy
    and bl, ~(1 << BIT_STRONGER_BATTLE_TRANSITION)
    mov byte [ebp + wBattleTransitionSpiralDirection], 1
    ret
.highLevelEnemy:
    or bl, (1 << BIT_STRONGER_BATTLE_TRANSITION)
    mov byte [ebp + wBattleTransitionSpiralDirection], 0
    ret

GetBattleTransitionID_IsDungeonMap:
    mov dl, [ebp + wCurMap]                       ; ld e, a
    mov esi, DungeonMaps1                         ; flat data pointer
.loop1:
    mov al, [esi]
    inc esi
    cmp al, 0xFF
    je .noMatch1
    cmp al, dl
    jne .loop1
.match:
    or bl, (1 << BIT_DUNGEON_BATTLE_TRANSITION)
    ret
.noMatch1:
    mov esi, DungeonMaps2
.loop2:
    mov al, [esi]
    inc esi
    cmp al, 0xFF
    je .noMatch2
    mov dh, al                                    ; ld d, a (range start)
    mov al, [esi]                                 ; range end
    inc esi
    cmp al, dl
    jb .loop2                                     ; end < map → next pair
    mov al, dl
    cmp al, dh
    jae .match                                    ; start <= map <= end
.noMatch2:
    and bl, ~(1 << BIT_DUNGEON_BATTLE_TRANSITION)
    ret

LoadBattleTransitionTile:
    ; pret: vChars1 tile $7f ($8FF0). Tile id $ff maps exactly there under the
    ; port's signed $8800 addressing; CopyVideoData arms g_tilecache_dirty.
    mov esi, GB_VFONT + 0x7F * TILE_SIZE
    mov edx, BattleTransitionTile
    mov bl, 1                                     ; 1 tile (BH bank = no-op)
    jmp CopyVideoData

BattleTransition_BlackScreen:
    mov al, 0xFF
    mov [ebp + IO_BGP], al
    mov [ebp + IO_OBP0], al
    mov [ebp + IO_OBP1], al
    call UpdateCGBPal_BGP
    call UpdateCGBPal_OBP0
    call UpdateCGBPal_OBP1
    ret

; for non-dungeon trainer battles
; called regardless of mon levels, but does an outward spiral if enemy is at
; least 3 levels higher than player and does an inward spiral otherwise
BattleTransition_Spiral:
    cmp byte [ebp + wBattleTransitionSpiralDirection], 0
    jz .outwardSpiral
    call BattleTransition_InwardSpiral
    jmp .done
.outwardSpiral:
    ; DEVIATION{class=projection; pret=engine/battle/battle_transitions.asm:BattleTransition_Spiral; behavior=start hlcoord 20,13 with b=125 frames x c=12 writes per frame instead of pret's 10,10 x 120 x 3; evidence=start = (W/2, H/2+1) generalized, and the 40x25 canvas needs 1500 steps - simulation measured full 1000/1000 coverage at step 1469 with the bounds-guarded FSM, 125 frames tracks pret's 120; lifetime=permanent, 40x25 geometry}
    hlcoord SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2 + 1
    mov byte [ebp + wOutwardSpiralCurrentDirection], 3
    ; DEVIATION{class=data-model; pret=engine/battle/battle_transitions.asm:BattleTransition_Spiral; behavior=wOutwardSpiralTileMapPointer stored as one 16-bit GB tilemap offset word instead of pret's split h/l byte stores; evidence=wMenuCursorLocation precedent (window.asm) - same 2-byte footprint at pret's address; lifetime=permanent, flat-pointer model}
    mov [ebp + wOutwardSpiralTileMapPointer], si
    mov bh, 125                                   ; pret: ld b, 120 (timing, see above)
.loop:
    mov bl, 12                                    ; pret: ld c, 3 (projection, see above)
.innerLoop:
    push ebx
    call BattleTransition_OutwardSpiral_
    pop ebx
    dec bl
    jnz .innerLoop
    call DelayFrame
    dec bh
    jnz .loop
.done:
    call BattleTransition_BlackScreen
    xor ax, ax
    mov [ebp + wOutwardSpiralTileMapPointer], ax
    ret

; DEVIATION{class=projection; pret=engine/battle/battle_transitions.asm:BattleTransition_InwardSpiral; behavior=leg arithmetic generalized with D=SCREEN_WIDTH-SCREEN_HEIGHT (pret's inc c/dec c pairs silently encode W-H=2), counter init 19 (pret 7), signed loop termination; evidence=simulation reproduces pret exactly on 20x18 (359/360, cell 8,9 unwritten - a real pret quirk) and covers 40x25 fully (1013 writes, 1000/1000, 0 OOB); lifetime=permanent, 40x25 geometry}
BattleTransition_InwardSpiral:
    mov byte [ebp + wInwardSpiralUpdateScreenCounter], 19   ; pret: 7
    hlcoord 0, 0
    mov ecx, SCREEN_HEIGHT - 1                    ; c (signed 32-bit — see termination)
    mov edx, SCREEN_WIDTH
    call BattleTransition_InwardSpiral_
    inc ecx
    jmp .skip
.loop:
    mov edx, SCREEN_WIDTH
    call BattleTransition_InwardSpiral_
.skip:
    add ecx, BT_WH_DELTA - 1                      ; pret: inc c (D-1 with D=2)
    mov edx, 1
    call BattleTransition_InwardSpiral_
    sub ecx, BT_WH_DELTA                          ; pret: dec c / dec c
    mov edx, -SCREEN_WIDTH
    call BattleTransition_InwardSpiral_
    add ecx, BT_WH_DELTA - 1                      ; pret: inc c
    mov edx, -1
    call BattleTransition_InwardSpiral_
    sub ecx, BT_WH_DELTA                          ; pret: dec c / dec c
    cmp ecx, 0
    jg .loop                                      ; pret: and a / jr nz (signed here)
    ret

BattleTransition_InwardSpiral_:
    ; Zero/negative-count legs are SKIPPED: the final degenerate lap has a
    ; 0-count leg, and pret's 8-bit `dec c` idiom would loop 256 times there
    ; (part of the projection DEVIATION above).
    test ecx, ecx
    jle .done
    push ecx
.loop:
    mov byte [ebp + esi], 0xFF
    add esi, edx
    push ecx
    mov al, [ebp + wInwardSpiralUpdateScreenCounter]
    dec al
    jnz .skip
    call BattleTransition_TransferDelay3
    mov al, 19                                    ; pret: ld a, 7
.skip:
    mov [ebp + wInwardSpiralUpdateScreenCounter], al
    pop ecx
    dec ecx
    jnz .loop
    pop ecx
.done:
    ret

; DEVIATION{class=projection; pret=engine/battle/battle_transitions.asm:BattleTransition_OutwardSpiral_; behavior=the FSM's neighbor reads and cell writes are bounds-guarded against [W_TILEMAP, W_TILEMAP+1000) - an OOB read reports not-$ff (forcing a turn) and an OOB write is dropped; evidence=pret's FSM is unsound at screen edges even on the GB (measured: 19 OOB writes, 341/360 cells at its 360-step cutoff, hidden by BlackScreen) and raw on 40x25 degrades to 800/1000 with 200 OOB writes that would land in W_SHADOW_OAM, which ends exactly at W_TILEMAP; lifetime=permanent, 40x25 geometry + OAM safety}
BattleTransition_OutwardSpiral_:
    movzx esi, word [ebp + wOutwardSpiralTileMapPointer]
    mov al, [ebp + wOutwardSpiralCurrentDirection]
    cmp al, 0
    je .up
    cmp al, 1
    je .left
    cmp al, 2
    je .down
    cmp al, 3
    je .right
.keepSameDirection:
    call .write
.done:
    mov [ebp + wOutwardSpiralTileMapPointer], si
    ret
.up:
    dec esi                                       ; probe the left neighbor
    call .read
    cmp al, 0xFF
    jne .changeDirection
    inc esi
    sub esi, SCREEN_WIDTH
    jmp .keepSameDirection
.left:
    add esi, SCREEN_WIDTH                         ; probe the below neighbor
    call .read
    cmp al, 0xFF
    jne .changeDirection
    sub esi, SCREEN_WIDTH
    dec esi
    jmp .keepSameDirection
.down:
    inc esi                                       ; probe the right neighbor
    call .read
    cmp al, 0xFF
    jne .changeDirection
    dec esi
    add esi, SCREEN_WIDTH
    jmp .keepSameDirection
.right:
    sub esi, SCREEN_WIDTH                         ; probe the above neighbor
    call .read
    cmp al, 0xFF
    jne .changeDirection
    add esi, SCREEN_WIDTH
    inc esi
    jmp .keepSameDirection
.changeDirection:
    call .write
    mov al, [ebp + wOutwardSpiralCurrentDirection]
    inc al
    cmp al, 4
    jne .skip
    xor al, al
.skip:
    mov [ebp + wOutwardSpiralCurrentDirection], al
    jmp .done
.write:                                           ; bounds-guarded [hl] = $ff
    cmp esi, W_TILEMAP
    jb .wdrop
    cmp esi, W_TILEMAP + W_TILEMAP_SIZE
    jae .wdrop
    mov byte [ebp + esi], 0xFF
.wdrop:
    ret
.read:                                            ; bounds-guarded a = [hl]
    cmp esi, W_TILEMAP
    jb .rout
    cmp esi, W_TILEMAP + W_TILEMAP_SIZE
    jae .rout
    mov al, [ebp + esi]
    ret
.rout:
    xor al, al                                    ; OOB reads as not-$ff → forces a turn
    ret

FlashScreen:
BattleTransition_FlashScreen_:
    mov esi, BattleTransition_FlashScreenPalettes ; flat data pointer
.loop:
    mov al, [esi]
    inc esi
    cmp al, 1
    je .done
    mov [ebp + IO_BGP], al
    call UpdateCGBPal_BGP
    push esi
    mov bl, 2                                     ; ld c, 2
    call DelayFrames
    pop esi
    jmp .loop
.done:
    dec bh                                        ; dec b
    jnz BattleTransition_FlashScreen_
    ret

; used for low level trainer dungeon battles
; DEVIATION{class=projection; pret=engine/battle/battle_transitions.asm:BattleTransition_Shrink; behavior=20 outer iterations (pret SCREEN_HEIGHT/2=9) with rows stepping only on the 12/20 Bresenham schedule while columns step every iteration, row copies converge on single center row 12 (odd height), columns on pair 19/20; evidence=simulation all-black exactly at iteration 20, and the same simulator reproduces GB all-black at 9/9 - the decoupled axes reach center together; lifetime=permanent, 40x25 geometry}
; DEVIATION{class=timing; pret=engine/battle/battle_transitions.asm:BattleTransition_Shrink; behavior=DelayFrames 3 per iteration (pret 6), total 60 frames vs GB 54; evidence=20 iterations x 3 tracks the GB duration where 20 x 6 would double it; lifetime=permanent, paired with the projection above}
BattleTransition_Shrink:
    mov bl, 20                                    ; pret: ld c, SCREEN_HEIGHT / 2
    xor bh, bh                                    ; port: iteration index (schedule lookup)
.loop:
    push ebx
    xor al, al
    mov [ebp + hAutoBGTransferEnabled], al
    movzx eax, bh
    cmp byte [ShrinkRowSchedule + eax], 0
    jz .cols
    hlcoord 0, (SCREEN_HEIGHT - 1) / 2 - 1        ; pret: hlcoord 0, 7
    decoord 0, (SCREEN_HEIGHT - 1) / 2            ; pret: decoord 0, 8
    mov ecx, -SCREEN_WIDTH * 2
    call BattleTransition_CopyTiles1
    hlcoord 0, (SCREEN_HEIGHT - 1) / 2 + 1        ; pret: hlcoord 0, 10
    decoord 0, (SCREEN_HEIGHT - 1) / 2            ; pret: decoord 0, 9
    mov ecx, SCREEN_WIDTH * 2
    call BattleTransition_CopyTiles1
.cols:
    hlcoord SCREEN_WIDTH / 2 - 2, 0               ; pret: hlcoord 8, 0
    decoord SCREEN_WIDTH / 2 - 1, 0               ; pret: decoord 9, 0
    mov ecx, -2
    call BattleTransition_CopyTiles2
    hlcoord SCREEN_WIDTH / 2 + 1, 0               ; pret: hlcoord 11, 0
    decoord SCREEN_WIDTH / 2, 0                   ; pret: decoord 10, 0
    mov ecx, 2
    call BattleTransition_CopyTiles2
    mov byte [ebp + hAutoBGTransferEnabled], 1
    mov bl, 3                                     ; pret: ld c, 6 (timing, see above)
    call DelayFrames
    pop ebx
    inc bh
    dec bl
    jnz .loop
    call BattleTransition_BlackScreen
    mov bl, 10
    jmp DelayFrames

; used for high level trainer dungeon battles
; DEVIATION{class=projection; pret=engine/battle/battle_transitions.asm:BattleTransition_Split; behavior=20 outer iterations (pret SCREEN_HEIGHT/2=9) with rows stepping only on the 13/20 Bresenham schedule, black seeding at center rows 12/13 and columns 19/20; evidence=simulation all-black exactly at iteration 20; lifetime=permanent, 40x25 geometry}
; DEVIATION{class=timing; pret=engine/battle/battle_transitions.asm:BattleTransition_Split; behavior=per-iteration delay is the TransferDelay3 equivalent only (3 frames, dropping pret's extra Delay3), total 60 frames vs GB 54; evidence=20 iterations x 3 tracks the GB duration where 20 x 6 would double it; lifetime=permanent, paired with the projection above}
BattleTransition_Split:
    mov bl, 20                                    ; pret: ld c, SCREEN_HEIGHT / 2
    xor bh, bh                                    ; port: iteration index (schedule lookup)
    mov byte [ebp + hAutoBGTransferEnabled], 0
.loop:
    push ebx
    movzx eax, bh
    cmp byte [SplitRowSchedule + eax], 0
    jz .cols
    hlcoord 0, SCREEN_HEIGHT - 2                  ; pret: hlcoord 0, 16
    decoord 0, SCREEN_HEIGHT - 1                  ; pret: decoord 0, 17
    mov ecx, -SCREEN_WIDTH * 2
    call BattleTransition_CopyTiles1
    hlcoord 0, 1
    decoord 0, 0
    mov ecx, SCREEN_WIDTH * 2
    call BattleTransition_CopyTiles1
.cols:
    hlcoord SCREEN_WIDTH - 2, 0                   ; pret: hlcoord 18, 0
    decoord SCREEN_WIDTH - 1, 0                   ; pret: decoord 19, 0
    mov ecx, -2
    call BattleTransition_CopyTiles2
    hlcoord 1, 0
    decoord 0, 0
    mov ecx, 2
    call BattleTransition_CopyTiles2
    call BattleTransition_TransferDelay3          ; pret: + call Delay3 (timing, see above)
    pop ebx
    inc bh
    dec bl
    jnz .loop
    call BattleTransition_BlackScreen
    mov bl, 10
    jmp DelayFrames

; Copies SCREEN_WIDTH-cell rows toward the destination, with pret's src/dst
; SWAP semantics (after each copy: new src = old dst + offset, new dst = old
; src; the final $ff fill lands at the last source row).
; In: ESI = src coord, EDI = dst coord, ECX = signed row offset (pret: bc)
BattleTransition_CopyTiles1:
    mov [ebp + wBattleTransitionCopyTilesOffset], cx
    mov cl, (SCREEN_HEIGHT - 1) / 2               ; 12 — pret's `ld c, 8` was (H-1)/2 (collision)
.loop1:
    push ecx
    push esi
    push edi
    mov edx, edi
    mov bx, SCREEN_WIDTH
    call CopyData
    pop esi                                       ; pret: pop hl (old DE — the swap)
    pop edi                                       ; pret: pop de (old HL)
    movsx ecx, word [ebp + wBattleTransitionCopyTilesOffset]
    add esi, ecx
    pop ecx
    dec cl
    jnz .loop1
    mov esi, edi                                  ; ld l, e / ld h, d
    mov al, 0xFF
    mov cl, SCREEN_WIDTH
.loop2:
    mov [ebp + esi], al
    inc esi
    dec cl
    jnz .loop2
    ret

; Column variant of the above, same swap semantics.
; In: ESI = src coord, EDI = dst coord, ECX = signed column offset (pret: bc)
BattleTransition_CopyTiles2:
    mov [ebp + wBattleTransitionCopyTilesOffset], cx
    mov cl, SCREEN_WIDTH / 2 - 1                  ; 19 — pret's `ld c, SCREEN_HEIGHT/2` was W/2-1 (collision)
.loop1:
    push ecx
    push esi
    push edi
    mov cl, SCREEN_HEIGHT                         ; 25 cells per column
.loop2:
    mov al, [ebp + esi]
    mov [ebp + edi], al
    add edi, SCREEN_WIDTH
    add esi, SCREEN_WIDTH
    dec cl
    jnz .loop2
    pop esi                                       ; pret: pop hl (old DE — the swap)
    pop edi                                       ; pret: pop de (old HL)
    movsx ecx, word [ebp + wBattleTransitionCopyTilesOffset]
    add esi, ecx
    pop ecx
    dec cl
    jnz .loop1
    mov esi, edi                                  ; ld l, e / ld h, d
    mov cl, SCREEN_HEIGHT
.loop3:
    mov byte [ebp + esi], 0xFF
    add esi, SCREEN_WIDTH
    dec cl
    jnz .loop3
    ret

; used for high level wild dungeon battles
; Verbatim translation — the counts scale (SCREEN_WIDTH/2 per row-pass,
; SCREEN_HEIGHT outer). 25 iters x 3 = 75 frames vs GB 54 (accepted:
; per-step pacing kept faithful).
; DEVIATION{class=timing; pret=engine/battle/battle_transitions.asm:BattleTransition_VerticalStripes; behavior=75 frames total vs GB 54; evidence=SCREEN_HEIGHT=25 outer iterations at pret's per-iteration 3-frame pacing - the per-step cadence is kept faithful over the taller canvas; lifetime=permanent, 40x25 geometry}
BattleTransition_VerticalStripes:
    mov bl, SCREEN_HEIGHT                         ; ld c, SCREEN_HEIGHT
    hlcoord 0, 0
    decoord 1, SCREEN_HEIGHT - 1                  ; pret: decoord 1, 17
    mov byte [ebp + hAutoBGTransferEnabled], 0
.loop:
    push ebx
    push esi
    push edi
    push edi
    call BattleTransition_VerticalStripes_
    pop esi                                       ; pret: pop hl (the pushed de)
    call BattleTransition_VerticalStripes_
    call BattleTransition_TransferDelay3
    pop edi
    sub edi, SCREEN_WIDTH
    pop esi
    add esi, SCREEN_WIDTH
    pop ebx
    dec bl
    jnz .loop
    jmp BattleTransition_BlackScreen

BattleTransition_VerticalStripes_:
    mov cl, SCREEN_WIDTH / 2                      ; 20
.loop:
    mov byte [ebp + esi], 0xFF
    add esi, 2                                    ; inc hl / inc hl
    dec cl
    jnz .loop
    ret

; used for low level wild dungeon battles
; DEVIATION{class=projection; pret=engine/battle/battle_transitions.asm:BattleTransition_HorizontalStripes; behavior=two columns per side per iteration (cols 2i,2i+1 even rows from the left, cols 39-2i,38-2i odd rows from the right) over SCREEN_WIDTH/2=20 iterations, and the per-column fill count is parameterized (13 even-row cells, 12 odd-row - pret's single SCREEN_HEIGHT/2 no longer serves both on odd height); evidence=20 x 3 = 60 frames = the GB duration with the same per-step coverage fraction; lifetime=permanent, 40x25 geometry}
BattleTransition_HorizontalStripes:
    mov bl, SCREEN_WIDTH / 2                      ; 20 iterations (pret: ld c, SCREEN_WIDTH)
    hlcoord 0, 0
    decoord SCREEN_WIDTH - 1, 1                   ; pret: decoord 19, 1
    mov byte [ebp + hAutoBGTransferEnabled], 0
.loop:
    push ebx
    push esi
    push edi
    ; left side: cols hl, hl+1 — even rows (13 cells)
    mov cl, (SCREEN_HEIGHT + 1) / 2
    call BattleTransition_HorizontalStripes_
    mov esi, [esp + 4]
    inc esi
    mov cl, (SCREEN_HEIGHT + 1) / 2
    call BattleTransition_HorizontalStripes_
    ; right side: cols de, de-1 — odd rows (12 cells)
    mov esi, [esp]
    mov cl, SCREEN_HEIGHT / 2
    call BattleTransition_HorizontalStripes_
    mov esi, [esp]
    dec esi
    mov cl, SCREEN_HEIGHT / 2
    call BattleTransition_HorizontalStripes_
    call BattleTransition_TransferDelay3
    pop edi
    pop esi
    pop ebx
    add esi, 2                                    ; pret: inc hl
    sub edi, 2                                    ; pret: dec de
    dec bl
    jnz .loop
    jmp BattleTransition_BlackScreen

; In: ESI = start cell, CL = fill count (port-parameterized — see the
; HorizontalStripes DEVIATION; pret hardcodes SCREEN_HEIGHT/2)
BattleTransition_HorizontalStripes_:
    mov edx, SCREEN_WIDTH * 2
.loop:
    mov byte [ebp + esi], 0xFF
    add esi, edx
    dec cl
    jnz .loop
    ret

; used for high level wild non-dungeon battles
; makes one full circle around the screen by animating each half circle one at
; a time
BattleTransition_Circle:
    call BattleTransition_FlashScreen
    xor bh, bh                                    ; lb bc, 0, HALF_CIRCLE_STEPS
    mov bl, HALF_CIRCLE_STEPS
    mov esi, BattleTransition_HalfCircle1
    call BattleTransition_Circle_Sub1
    mov bl, HALF_CIRCLE_STEPS
    mov bh, 1
    mov esi, BattleTransition_HalfCircle2
    call BattleTransition_Circle_Sub1
    jmp BattleTransition_BlackScreen

BattleTransition_FlashScreen:
    mov bh, 3                                     ; ld b, $3
    call BattleTransition_FlashScreen_
    mov byte [ebp + hAutoBGTransferEnabled], 0
    ret

BattleTransition_Circle_Sub1:
    push ebx
    push esi
    mov al, bh                                    ; ld a, b (quadrant Y)
    call BattleTransition_Circle_Sub2
    pop esi
    add esi, BT_ARC_ENTRY_SIZE                    ; pret: ld bc, 5 / add hl, bc
    call BattleTransition_TransferDelay3
    pop ebx
    dec bl
    jnz BattleTransition_Circle_Sub1
    ret

BattleTransition_TransferDelay3:
    mov byte [ebp + hAutoBGTransferEnabled], 1    ; vestigial (inert in the port)
    call Delay3
    mov byte [ebp + hAutoBGTransferEnabled], 0
    ret

; used for low level wild non-dungeon battles
; makes two half circles around the screen by animating both half circles at
; the same time
BattleTransition_DoubleCircle:
    call BattleTransition_FlashScreen
    mov bl, HALF_CIRCLE_STEPS                     ; ld c, SCREEN_WIDTH / 2 (collision)
    mov esi, BattleTransition_HalfCircle1
    mov edi, BattleTransition_HalfCircle2         ; ld de, ...
.loop:
    push ebx
    push esi
    push edi
    push edi
    xor al, al
    call BattleTransition_Circle_Sub2
    pop esi                                       ; pret: pop hl (the pushed de)
    mov al, 1
    call BattleTransition_Circle_Sub2
    pop edi
    add edi, BT_ARC_ENTRY_SIZE                    ; pret: ld bc, 5 advance
    pop esi
    add esi, BT_ARC_ENTRY_SIZE
    call BattleTransition_TransferDelay3
    pop ebx
    dec bl
    jnz .loop
    jmp BattleTransition_BlackScreen

; In: AL = quadrant Y, ESI = arc table entry (flat)
BattleTransition_Circle_Sub2:
    mov [ebp + wBattleTransitionCircleScreenQuadrantY], al
    mov al, [esi]
    mov [ebp + wBattleTransitionCircleScreenQuadrantX], al
    mov edx, [esi + 1]                            ; arc data (flat; pret: dw -> dd)
    mov esi, [esi + 5]                            ; target coord (GB tilemap offset)
    jmp BattleTransition_Circle_Sub3

; In: ESI = tilemap coord (GB offset), EDX = arc data (flat)
BattleTransition_Circle_Sub3:
    push esi
    mov cl, [edx]                                 ; run length
    inc edx
.loop1:
    mov byte [ebp + esi], 0xFF
    cmp byte [ebp + wBattleTransitionCircleScreenQuadrantX], 0
    jz .skip1
    inc esi
    jmp .skip2
.skip1:
    dec esi
.skip2:
    dec cl
    jnz .loop1
    pop esi
    mov ecx, SCREEN_WIDTH
    cmp byte [ebp + wBattleTransitionCircleScreenQuadrantY], 0
    jz .skip3
    neg ecx                                       ; ld bc, -SCREEN_WIDTH
.skip3:
    add esi, ecx
    mov al, [edx]
    inc edx
    cmp al, 0xFF                                  ; cp -1
    jne .notDone
    ret
.notDone:
    test al, al
    jz BattleTransition_Circle_Sub3
    mov cl, al
.loop2:
    cmp byte [ebp + wBattleTransitionCircleScreenQuadrantX], 0
    jz .skip4
    dec esi
    jmp .skip5
.skip4:
    inc esi
    jmp .skip5
.skip5:
    dec cl
    jnz .loop2
    jmp BattleTransition_Circle_Sub3
