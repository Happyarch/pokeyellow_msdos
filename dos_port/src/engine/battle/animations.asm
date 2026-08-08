; animations.asm — battle move-animation engine (pret engine/battle/animations.asm).
;
; battle_animations Stage 2 (docs/current_plan_battle_animations.md): the
; interpreter core. This mirror now carries the command-stream interpreter that
; walks the Tier-1 data in src/data/battle_anims.asm and paints frame blocks into
; wShadowOAM:
;   DrawFrameBlock, PlayAnimation, LoadSubanimation, GetSubanimationTransform1/2,
;   LoadMoveAnimationTiles, MoveAnimation, ShareMoveAnimations, PlaySubanimation,
;   AnimationCleanOAM, DoSpecialEffectByAnimationId, GetMoveSound, IsCryMove,
;   PlayApplyingAttackSound, AnimationDelay10, CallWithTurnFlipped, Func_78e98,
;   WriteLowerByteOfBGMapAndEnableBGTransfer, BattleAnimCopyTileMapToVRAM,
;   plus the hand-written dd dispatch tables (SpecialEffectPointers /
;   AnimationIdSpecialEffects) and the move-anim tilesets.
;
; The special-effect / mon-pic / palette / shake handlers the tables dispatch to
; are STUBs in core_stubs.asm (retired across Stages 3-5); the interpreter is
; faithful without them. At Stage 2 the interpreter is LINKED but reached only by
; the (deferred) DEBUG_ANIM_DEMO harness — the production battle path
; (core.asm PlayMoveAnimation) is unchanged, so the battle goldens stay green
; until the projection-publication wiring lands and is visually signed off.
;
; FLAT-POINTER MODEL (read this before touching pointer math). The Tier-1 tables
; in src/data/battle_anims.asm are emitted `dd` (32-bit flat program-image
; addresses), NOT pret's `dw` (16-bit GB ROM). So:
;   * command streams / subanim bodies / frame blocks / base-coord pairs /
;     MoveSoundTable / the dispatch tables are read FLAT ([esi]/[label+idx*N]),
;     never [ebp+..]; pret's ld l,a/ld h,0/add hl,hl (x2) index math becomes
;     *4 (dd) here, and the db-id+dd-ptr dispatch entries are 5 bytes (pret 3).
;   * wShadowOAM and every WRAM scratch stay GB-space ([ebp+addr]).
; DEVIATION{class=data-model; pret=engine/battle/animations.asm:LoadSubanimation; behavior=the subanimation and subentry cursors are held in port-local 32-bit .bss (wSubAnimAddrPtr32 / wSubAnimSubEntryAddr32) instead of the 2-byte GB WRAM slots wSubAnimAddrPtr $D093 / wSubAnimSubEntryAddr $D095; evidence=those pret slots hold 16-bit ROM pointers but the flat DPMI model needs 32-bit program-image addresses that do not fit in two WRAM bytes and would clobber the adjacent slot, and the GB slots are read only by this engine; lifetime=permanent, part of the flat-pointer port model}
;
; Register map: A=AL, BC=BX (B=BH, C=BL), DE=EDX, HL=ESI, EBP = GB base.
; GB memory at [EBP+addr]; flat program-image data via [label]/[esi].
bits 32

%include "gb_macros.inc"
%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "coords.inc"                    ; BCOORD — battle-frame tilemap projection (+10 col, +3 row)
%include "data_macros.inc"               ; dc — pret macros/data.asm "crumbs" (FlashScreenLong* tables)
%include "assets/audio_constants.inc"    ; SFX_DAMAGE / SFX_SUPER_EFFECTIVE / SFX_NOT_VERY_EFFECTIVE

%ifndef OBJ_SIZE
OBJ_SIZE                 equ 4     ; constants/hardware.inc — bytes per OAM entry
%endif
%ifndef SCREEN_HEIGHT_PX
SCREEN_HEIGHT_PX         equ 144   ; constants/hardware.inc
%endif
; WavyScreenLineOffsets entry count (pret's table before its $80 terminator).
; MUST be a power of two — WavyScreen_SetSCX wraps the phase with AND, not MOD.
WAVY_SCREEN_NUM_OFFSETS  equ 32
%ifndef wCoordAdjustmentAmount
wCoordAdjustmentAmount   equ 0xD089 ; golden 00:d089
%endif
; wOnSGB now comes from gb_memmap.inc (0xCF1A); it is 1 in the port — colour
; hardware, set at init like pret LoadSGB on CGB (memory battle-anim-cgb-obj-palette-model).

; --- Tier-1 data tables (src/data/battle_anims.asm; flat dd) ---
extern AttackAnimationPointers
extern SubanimationPointers
extern FrameBlockPointers
extern FrameBlockBaseCoords
extern MoveSoundTable
extern TileIDListPointerTable         ; src/data/tilemaps.asm (hand-written dd table, 5-byte rows)
extern DownscaledMonTiles_5x5         ; src/data/tilemaps.asm
extern DownscaledMonTiles_3x3         ; src/data/tilemaps.asm
extern SpecialEffectPointers          ; src/data/battle_anim_dispatch.asm (hand-written dd table)
extern AnimationIdSpecialEffects      ; src/data/battle_anim_dispatch.asm (hand-written dd table)

; --- home/engine backend ---
extern WaitForSoundToFinish          ; src/home/delay.asm
extern PlaySound                      ; src/home/audio.asm
extern GetCryData                     ; src/home/home_stubs.asm (STUB)
extern PredefShakeScreenVertically     ; src/engine/gfx/screen_effects.asm
extern PredefShakeScreenHorizontally   ; src/engine/gfx/screen_effects.asm
extern UpdateCGBPal_BGP               ; src/home/cgb_palettes.asm
extern UpdateCGBPal_OBP0              ; src/home/cgb_palettes.asm
extern UpdateCGBPal_OBP1              ; src/home/cgb_palettes.asm
extern DelayFrames                    ; src/home/delay.asm — BL = frame count
extern DelayFrame                     ; src/home/vblank.asm
extern ClearSprites                   ; src/home/clear_sprites.asm
extern ClearScreen                    ; src/home/copy2.asm
extern ClearScreenArea                ; src/home/copy2.asm — ESI dest, BH rows, BL cols
extern IsInArray                      ; src/home/array2.asm — AL val, ESI base, EDX stride
extern CopyVideoData                  ; src/home/copy2.asm — ESI dest VRAM, EDX flat src, BL tiles
extern SaveScreenTilesToBuffer2       ; src/home/tilemap.asm
extern LoadScreenTilesFromBuffer2     ; src/home/tilemap.asm
extern Delay3                         ; src/home/palettes.asm
extern PublishProjectedOAM            ; src/engine/gfx/sprite_oam.asm — wShadowOAM -> canvas at (EAX,EBX)
extern g_obj_clip                     ; src/ppu/ppu.asm — OBJ clip rectangle (x0,y0,x1,y1 dwords)
extern g_row_xoff_on                  ; src/ppu/ppu.asm — wavy-screen per-row HAL enable
extern g_row_xoff                     ; src/ppu/ppu.asm — signed per-screen-row BG X offset

; --- Stage 3-5 dispatch-target stubs (src/engine/battle/core_stubs.asm) ---
extern TossBallAnimation
extern AnimationWaterDropletsEverywhere
extern AnimationSlideMonUp
extern AnimationSlideMonDown
extern AnimationFlashMonPic
extern AnimationSlideMonOff
extern AnimationBlinkMon
extern AnimationMoveMonHorizontally
extern AnimationResetMonPosition
extern AnimationHideMonPic
extern AnimationSquishMonPic
extern AnimationShootBallsUpward
extern AnimationShootManyBallsUpward
extern AnimationBoundUpAndDown
extern AnimationMinimizeMon
extern AnimationSlideMonDownAndHide
extern AnimationTransformMon
extern AnimationLeavesFalling
extern AnimationPetalsFalling
extern AnimationSlideMonHalfOff
extern AnimationShakeEnemyHUD
extern AnimationSpiralBallsInward
extern AnimationFlashEnemyMonPic
extern AnimationHideEnemyMonPic
extern AnimationShowMonPic
extern AnimationShowEnemyMonPic
extern AnimationSlideEnemyMonOff
extern AnimationShakeBackAndForth
extern AnimationSubstitute
extern TailWhipAnimationUnused
extern DoGrowlSpecialEffects
extern DoBlizzardSpecialEffects
extern DoExplodeSpecialEffects
extern DoRockSlideSpecialEffects
extern TradeHidePokemon
extern TradeShakePokeball
extern TradeJumpPokeball
extern DoBallTossSpecialEffects
extern DoBallShakeSpecialEffects
extern DoPoofSpecialEffects

; --- routines this file defines ---
global DrawFrameBlock
global PlayAnimation
global LoadSubanimation
global GetSubanimationTransform1
global GetSubanimationTransform2
global LoadMoveAnimationTiles
global MoveAnimation
global ShareMoveAnimations
global Func_78e98
global WriteLowerByteOfBGMapAndEnableBGTransfer
global BattleAnimCopyTileMapToVRAM
global PlaySubanimation
global AnimationCleanOAM
global DoSpecialEffectByAnimationId
global AnimationDelay10
global CallWithTurnFlipped
global GetMoveSound
global IsCryMove
global SetAnimationPalette
global PlayApplyingAttackSound
global MoveAnimationTilesPointers
global MoveAnimationTiles0
global MoveAnimationTiles2
global MoveAnimationTiles1

; --- Stage 3: screen / palette special effects ---
global AnimationFlashScreen
global AnimationFlashScreenLong
global FlashScreenLongDelay
global FlashScreenUnused
global FlashScreenEveryFourFrameBlocks
global FlashScreenEveryEightFrameBlocks
global AnimationDarkScreenPalette
global AnimationDarkenMonPalette
global AnimationUnusedPalette1
global AnimationUnusedPalette2
global AnimationResetScreenPalette
global AnimationUnusedPalette3
global AnimationLightScreenPalette
global AnimationUnusedPalette4
global SetAnimationBGPalette
global FlashScreenLongMonochrome
global FlashScreenLongSGB

; --- Stage 3b: shake family + blink wrapper + applying-attack dispatch ---
global AnimationTypePointerTable
global ShakeScreenVertically
global ShakeScreenHorizontallyHeavy
global ShakeScreenHorizontallySlow
global ShakeScreenHorizontallySlow2
global ShakeScreenHorizontallyLight
global BlinkEnemyMonSprite
global AnimationShakeScreen
global AnimationShakeScreenVertically
global AnimationShakeScreenHorizontallyFast
global AnimationShakeScreenHorizontallySlow
global AnimationUnusedShakeScreen
global AnimationBlinkEnemyMon
global AnimationWavyScreen
global WavyScreen_SetSCX
global WavyScreenLineOffsets

; --- existing globals (retained below) ---
global PlayApplyingAttackAnimation
global AdjustOAMBlockXPos
global AdjustOAMBlockXPos2
global AdjustOAMBlockYPos
global AdjustOAMBlockYPos2

; %ifndef move-anim constants that might not be in gb_constants (defensive)
%ifndef B_OAM_XFLIP
B_OAM_XFLIP              equ 5     ; OAM_XFLIP = 1 << 5
%endif

section .text

; ===========================================================================
; DrawFrameBlock — pret engine/battle/animations.asm:DrawFrameBlock.
; Draws one frame block: a run of OAM entries assembled from GB-space deltas and
; the current wBaseCoordX/Y, applying the wSubAnimTransform (HVFLIP/HFLIP/
; COORDFLIP/none) mirrors, then paces the frame (wSubAnimFrameDelay) and either
; cleans, resets or advances the wShadowOAM write cursor per wFBMode.
; In:  EBX = frame block FLAT pointer (pret bc → hl; kept 32-bit here because a
;      flat pointer does not fit in BX). All OAM writes go to [ebp + de] where de
;      is the GB wShadowOAM cursor persisted in wFBDestAddr (big-endian word).
; ===========================================================================
DrawFrameBlock:
    mov esi, ebx                             ; ld l,c / ld h,b — hl = frame block ptr (flat)
    mov al, [esi]                            ; ld a,[hli] — tile count
    inc esi
    mov [ebp + wNumFBTiles], al
    movzx edx, byte [ebp + wFBDestAddr]      ; wFBDestAddr big-endian: [+0]=high
    shl edx, 8
    mov dl, [ebp + wFBDestAddr + 1]          ; [+1]=low  → edx = GB wShadowOAM cursor
    mov byte [ebp + wFBTileCounter], 0       ; xor a / ld [wFBTileCounter],a
.loop:
    mov al, [ebp + wFBTileCounter]
    inc al                                   ; 8-bit (frame-block count bound)
    mov [ebp + wFBTileCounter], al
    mov byte [ebp + wdef4], 2                ; ld a,$2 / ld [wdef4],a
    mov al, [ebp + wSubAnimTransform]
    dec al
    jz .flipHorizontalAndVertical            ; SUBANIMTYPE_HVFLIP
    dec al
    jz .flipHorizontalTranslateDown          ; SUBANIMTYPE_HFLIP
    dec al
    jz .flipBaseCoords                       ; SUBANIMTYPE_COORDFLIP
; no transformation
    mov al, [ebp + wBaseCoordY]
    add al, [esi]                            ; add [hl] — Y offset (flat)
    mov [ebp + edx], al                      ; ld [de],a — store Y
    inc esi
    inc edx
    mov al, [ebp + wBaseCoordX]
    jmp .finishCopying
.flipBaseCoords:
    mov al, [ebp + wBaseCoordY]
    mov bl, al                               ; ld b,a
    mov al, 136
    sub al, bl                               ; flip Y base coordinate
    add al, [esi]                            ; add [hl] Y offset
    mov [ebp + edx], al                      ; store Y
    inc esi
    inc edx
    mov al, [ebp + wBaseCoordX]
    mov bl, al
    mov al, 168
    sub al, bl                               ; flip X base coordinate
.finishCopying:
    add al, [esi]                            ; add [hl] X offset
    mov [ebp + edx], al                      ; store X
    cmp al, 88
    jb .noHalfAdjust1
    inc byte [ebp + wdef4]
.noHalfAdjust1:
    inc esi
    inc edx
    mov al, [esi]                            ; ld a,[hli] — tile delta
    inc esi
    add al, 0x31                             ; base tile ID for battle animations
    mov [ebp + edx], al                      ; store tile ID
    inc edx
    mov al, [esi]                            ; ld a,[hli] — attr flags
    inc esi
    mov bl, al                               ; ld b,a
    mov al, [ebp + wdef4]
    or al, bl
    mov [ebp + edx], al                      ; store flags
    inc edx
    jmp .nextTile
.flipHorizontalAndVertical:
    mov al, [ebp + wBaseCoordY]
    add al, [esi]                            ; Y offset
    mov bl, al
    mov al, 136
    sub al, bl                               ; flip Y coordinate
    mov [ebp + edx], al                      ; store Y
    inc esi
    inc edx
    mov al, [ebp + wBaseCoordX]
    add al, [esi]                            ; X offset
    mov bl, al
    mov al, 168
    sub al, bl                               ; flip X coordinate
    mov [ebp + edx], al                      ; store X
    cmp al, 88
    jb .noHalfAdjust2
    inc byte [ebp + wdef4]
.noHalfAdjust2:
    inc esi
    inc edx
    mov al, [esi]                            ; ld a,[hli] — tile
    inc esi
    add al, 0x31
    mov [ebp + edx], al                      ; store tile ID
    inc edx
; toggle horizontal and vertical flip
    mov al, [esi]                            ; ld a,[hli] — flags
    inc esi
    and al, al
    mov bl, OAM_YFLIP | OAM_XFLIP
    jz .storeFlags1
    cmp al, OAM_XFLIP
    mov bl, OAM_YFLIP
    jz .storeFlags1
    cmp al, OAM_YFLIP
    mov bl, OAM_XFLIP
    jz .storeFlags1
    mov bl, 0
.storeFlags1:
    mov al, [ebp + wdef4]
    or al, bl
    mov [ebp + edx], al
    inc edx
    jmp .nextTile
.flipHorizontalTranslateDown:
    mov al, [ebp + wBaseCoordY]
    add al, [esi]
    add al, 40                               ; translate Y coordinate downwards
    mov [ebp + edx], al                      ; store Y
    inc esi
    inc edx
    mov al, [ebp + wBaseCoordX]
    add al, [esi]
    mov bl, al
    mov al, 168
    sub al, bl                               ; flip X coordinate
    mov [ebp + edx], al                      ; store X
    cmp al, 88
    jb .noHalfAdjust3
    inc byte [ebp + wdef4]
.noHalfAdjust3:
    inc esi
    inc edx
    mov al, [esi]                            ; ld a,[hli] — tile
    inc esi
    add al, 0x31
    mov [ebp + edx], al
    inc edx
    mov al, [esi]                            ; ld a,[hli] — flags
    inc esi
    test al, OAM_XFLIP                       ; bit B_OAM_XFLIP,a
    jnz .disableHorizontalFlip
.enableHorizontalFlip:
    or al, OAM_XFLIP                         ; set B_OAM_XFLIP,a
    jmp .storeFlags2
.disableHorizontalFlip:
    and al, ~OAM_XFLIP & 0xFF                ; res B_OAM_XFLIP,a
.storeFlags2:
    mov bl, al
    mov al, [ebp + wdef4]
    or al, bl
    mov [ebp + edx], al
    inc edx
.nextTile:
    mov al, [ebp + wFBTileCounter]
    mov bl, al                               ; ld c,a
    mov al, [ebp + wNumFBTiles]
    cmp al, bl                               ; cp c
    jne .loop                                ; more tiles?
; after drawing tiles
    mov al, [ebp + wFBMode]
    cmp al, FRAMEBLOCKMODE_02
    jz .advanceFrameBlockDestAddr            ; skip delay and don't clean OAM buffer
; DEVIATION{class=projection; pret=engine/battle/animations.asm:DrawFrameBlock; behavior=before the per-frame-block delay the port publishes wShadowOAM to the renderer at the battle-frame origin (80,24) via PublishProjectedOAM, standing in for the GB's per-vblank OAM DMA of wShadowOAM to $FE00; evidence=the port has no hardware OAM DMA so the frame-block OAM the interpreter just wrote would never reach render_sprites otherwise, and (80,24) is the battle-frame projection origin per docs-ui_projection.md with offscreen entries hidden by g_obj_clip set at the MoveAnimation entry; lifetime=permanent, part of the battle-animation projection boundary}
    mov esi, W_SHADOW_OAM                     ; ESI = canonical OAM (GB offset)
    mov ecx, OAM_COUNT                        ; publish all 40 (cleared/offscreen hidden by g_obj_clip)
    mov eax, 80                               ; battle-frame origin X
    mov ebx, 24                               ; battle-frame origin Y
    call PublishProjectedOAM                  ; preserves EDX (the wShadowOAM cursor); all regs restored
    mov bl, [ebp + wSubAnimFrameDelay]       ; ld c,a → BL
    call DelayFrames
    mov al, [ebp + wFBMode]
    cmp al, FRAMEBLOCKMODE_03
    jz .advanceFrameBlockDestAddr            ; skip cleaning OAM buffer
    cmp al, FRAMEBLOCKMODE_04
    jz .done                                 ; skip cleaning + don't advance
    mov al, [ebp + wAnimationID]
    cmp al, GROWL
    jz .resetFrameBlockDestAddr
    call AnimationCleanOAM
.resetFrameBlockDestAddr:
    mov byte [ebp + wFBDestAddr + 1], (W_SHADOW_OAM & 0xFF)    ; ld a,l / ld [wFBDestAddr+1],a
    mov byte [ebp + wFBDestAddr], (W_SHADOW_OAM >> 8)          ; ld a,h / ld [wFBDestAddr],a
    ret
.advanceFrameBlockDestAddr:
    mov [ebp + wFBDestAddr + 1], dl          ; ld a,e / ld [wFBDestAddr+1],a
    mov [ebp + wFBDestAddr], dh              ; ld a,d / ld [wFBDestAddr],a
.done:
    ret

; ===========================================================================
; PlayAnimation — pret animations.asm:PlayAnimation. Walk the command stream for
; wAnimationID, playing each subanimation (with tileset/sound/palette setup) or
; special effect in turn until the -1 terminator.
; ===========================================================================
PlayAnimation:
    xor al, al
    mov [ebp + hROMBankTemp], al             ; faithful dead write (no ROM banking; union slot)
    mov [ebp + wSubAnimTransform], al
    movzx eax, byte [ebp + wAnimationID]     ; get animation number
    dec eax                                  ; id-1 = table index
    mov esi, [AttackAnimationPointers + eax*4]   ; esi = command stream (flat)
.animationLoop:
    mov al, [esi]                            ; ld a,[hli]
    inc esi
    cmp al, 0xFF                             ; cp -1
    jz .AnimationOver
    cmp al, FIRST_SE_ID                      ; subanimation or special effect?
    jb .playSubanimation                     ; jr c
; do special effect
    mov bl, al                               ; ld c,a — SE id
    mov edx, SpecialEffectPointers           ; ld de, table (flat)
.searchSpecialEffectTableLoop:
    mov al, [edx]                            ; ld a,[de]
    cmp al, bl                               ; cp c
    jz .foundMatch
    add edx, 5                               ; port entry stride (db id + dd ptr); pret 3
    jmp .searchSpecialEffectTableLoop
.foundMatch:
    mov al, [esi]                            ; ld a,[hli] — sound
    inc esi
    cmp al, NO_MOVE - 1                       ; is there a sound to play?
    jz .skipPlayingSound
    mov [ebp + wAnimSoundID], al
    push esi
    push edx
    call GetMoveSound
    call PlaySound
    pop edx
    pop esi
.skipPlayingSound:
    push esi                                 ; push hl (command stream, popped at .nextAnimationCommand)
    mov esi, [edx + 1]                        ; handler flat addr (pret inc de/ld l,a/inc de/ld h,a)
    push dword .nextAnimationCommand
    jmp esi                                  ; jp hl
.playSubanimation:
    mov bl, al                               ; ld c,a
    and al, 0x3F                             ; %00111111
    mov [ebp + wSubAnimFrameDelay], al
    xor al, al
    shl bl, 1                                ; sla c
    rcl al, 1                                ; rla
    shl bl, 1                                ; sla c
    rcl al, 1                                ; rla → top 2 bits of c = tileset
    mov [ebp + wWhichBattleAnimTileset], al
    mov al, [esi]                            ; ld a,[hli] — sound
    inc esi
    mov [ebp + wAnimSoundID], al
    movzx ecx, byte [esi]                    ; ld a,[hli] — subanimation ID
    inc esi
    lea ecx, [SubanimationPointers + ecx*4]  ; &entry (flat); pret stores &SubanimationPointers[id]
    mov [wSubAnimAddrPtr32], ecx
    push esi                                 ; push hl (command stream)
    mov al, [ebp + IO_OBP0]                  ; ldh a,[rOBP0]
    push eax                                 ; push af
    mov al, [ebp + wAnimPalette]
    mov [ebp + IO_OBP0], al                  ; ldh [rOBP0],a
    call UpdateCGBPal_OBP0
    call LoadMoveAnimationTiles
    call LoadSubanimation
    call PlaySubanimation
    pop eax                                  ; pop af
    mov [ebp + IO_OBP0], al                  ; ldh [rOBP0],a
    call UpdateCGBPal_OBP0
.nextAnimationCommand:
    pop esi                                  ; pop hl — restore command stream ptr
    jmp .animationLoop
.AnimationOver:
    ret

; ===========================================================================
; LoadSubanimation — pret animations.asm:LoadSubanimation. Read the subanim
; header (type<<5 | count), resolve the transform for this side, and set the
; subentry cursor (start, or end-of-list for a reversed subanimation).
; ===========================================================================
LoadSubanimation:
    mov esi, [wSubAnimAddrPtr32]             ; hl = stored entry addr (flat)
    mov edx, [esi]                           ; de = *entry = subanim body (flat)
    mov al, [edx]                            ; ld a,[de] — header
    mov bh, al                               ; ld b,a
    and al, 0x1F                             ; %00011111 — frame block count
    mov [ebp + wSubAnimCounter], al
    mov al, bh                               ; ld a,b
    and al, 0xE0                             ; %11100000 — type
    cmp al, SUBANIMTYPE_ENEMY << 5
    jnz .isNotTypeEnemy
    call GetSubanimationTransform2
    jmp .saveTransformation
.isNotTypeEnemy:
    call GetSubanimationTransform1
.saveTransformation:
; place the upper 3 bits of a into bits 0-2 of a before storing
    shr al, 1                                ; srl a
    ror al, 4                                ; swap a (nibble swap)
    mov [ebp + wSubAnimTransform], al
    cmp al, SUBANIMTYPE_REVERSE
    mov esi, 0                               ; ld hl, 0 — offset accumulator
    jnz .storeSubentryAddr
; reversed: place initial subentry at the END of the subentry list
    mov al, [ebp + wSubAnimCounter]
    dec al                                   ; a = count-1 (8-bit; pret's exact bound)
.reverseLoop:
    add esi, 3                               ; add hl, bc (bc = 3)
    dec al                                   ; dec a — 8-bit
    jnz .reverseLoop
.storeSubentryAddr:
    inc edx                                  ; inc de → first subentry (past header)
    add esi, edx                             ; add hl, de
    mov [wSubAnimSubEntryAddr32], esi
    ret

; called if the subanimation type is not SUBANIMTYPE_ENEMY
; In: AL = header type (top 3 bits). Out: AL = NORMAL(0) on player's turn else type.
GetSubanimationTransform1:
    mov bh, al                               ; ld b,a
    mov al, [ebp + hWhoseTurn]
    and al, al
    mov al, bh                               ; ld a,b (ZF from `and` survives)
    jnz .ret                                 ; ret nz — enemy turn keeps the type
    xor al, al                               ; SUBANIMTYPE_NORMAL << 5
.ret:
    ret

; called if the subanimation type is SUBANIMTYPE_ENEMY
GetSubanimationTransform2:
    mov al, [ebp + hWhoseTurn]
    and al, al
    mov al, SUBANIMTYPE_HFLIP << 5
    jz .ret                                  ; ret z — player turn → HFLIP
    xor al, al                               ; SUBANIMTYPE_NORMAL << 5
.ret:
    ret

; ===========================================================================
; LoadMoveAnimationTiles — pret animations.asm. Upload the selected move-anim
; tileset to OBJ VRAM (vSprites tile $31) via CopyVideoData (arms the tile cache).
; ===========================================================================
LoadMoveAnimationTiles:
    movzx eax, byte [ebp + wWhichBattleAnimTileset]
    lea esi, [eax + eax*2]                    ; *3
    shl esi, 1                                ; *6 — port entry stride (db count + dd ptr + db -1)
    add esi, MoveAnimationTilesPointers        ; flat
    mov al, [esi]                            ; ld a,[hli] — number of tiles
    inc esi
    mov [ebp + wTempTilesetNumTiles], al
    mov edx, [esi]                           ; dd — tileset source (flat)
    mov esi, GB_VCHARS0 + 0x31 * TILE_SIZE   ; vSprites tile $31 — dest VRAM
    xor bh, bh                               ; BANK(MoveAnimationTiles0) — no-op in flat model
    mov bl, [ebp + wTempTilesetNumTiles]     ; tile count → BL
    jmp CopyVideoData

; ===========================================================================
; MoveAnimation — pret animations.asm:MoveAnimation. Entry point (pret predef) for
; playing wAnimationID: wait for sound, set the anim palette, dispatch the Poke
; Ball toss specially, else run the subanimation stream (or a fixed delay when
; battle animations are disabled in the options), then the applying-attack shake.
; ===========================================================================
MoveAnimation:
    push esi                                 ; push hl
    push edx                                 ; push de
    push ebx                                 ; push bc
    push eax                                 ; push af
; DEVIATION{class=projection; pret=engine/battle/animations.asm:MoveAnimation; behavior=on entry the port narrows the OBJ clip rectangle g_obj_clip to the battle frame (80,24)..(240,168 exclusive) and restores it to the full canvas (0,0,RENDER_W,RENDER_H) at .animationFinished before returning; evidence=DrawFrameBlock publishes wShadowOAM at battle-frame origin (80,24) via PublishProjectedOAM, and GB off-screen OAM coords (X>=168, OAM_Y>=160) project to canvas positions still visible on the 320x200 canvas, so without this clip the GB's off-screen hiding semantics are lost and stray particles paint outside the frame, the rectangle being the 160x144 GB screen at the BCOORD (+10 col,+3 row) origin; lifetime=permanent, part of the battle-animation projection boundary}
    mov dword [g_obj_clip + 0], 10 * 8       ; x0 = 80  — battle frame origin (BCOORD +10 col)
    mov dword [g_obj_clip + 4], 3 * 8        ; y0 = 24  — BCOORD +3 row
    mov dword [g_obj_clip + 8], (10 + 20) * 8 ; x1 = 240 (exclusive) — +160px GB screen width
    mov dword [g_obj_clip + 12], (3 + 18) * 8 ; y1 = 168 (exclusive) — +144px GB screen height
    call WaitForSoundToFinish
    call SetAnimationPalette
    mov al, [ebp + wAnimationID]
    and al, al
    jz .animationFinished
    cmp al, TOSS_ANIM                        ; if throwing a Poke Ball, skip regular anim
    jnz .moveAnimation
    push dword .animationFinished
    jmp TossBallAnimation
.moveAnimation:
    mov al, [ebp + wOptions]                 ; are battle animations disabled?
    test al, 1 << BIT_BATTLE_ANIMATION
    jnz .animationsDisabled
    call ShareMoveAnimations
    call PlayAnimation
    jmp .next
.animationsDisabled:
    mov bl, 30                               ; ld c,30 → BL
    call DelayFrames
.next:
    call PlayApplyingAttackAnimation         ; shake/flash "to show damage"
.animationFinished:
    mov dword [g_obj_clip + 0], 0            ; restore full-canvas OBJ clip (see entry DEVIATION)
    mov dword [g_obj_clip + 4], 0
    mov dword [g_obj_clip + 8], RENDER_W
    mov dword [g_obj_clip + 12], RENDER_H
    call WaitForSoundToFinish
    mov dword [wSubAnimSubEntryAddr32], 0    ; pret clears wSubAnimSubEntryAddr; reset the flat cursor
    xor al, al
    mov [ebp + wUnusedMoveAnimByte], al
    mov [ebp + wSubAnimTransform], al
    dec al                                   ; NO_MOVE - 1
    mov [ebp + wAnimSoundID], al
    pop eax
    pop ebx
    pop edx
    pop esi
    ret

; ===========================================================================
; ShareMoveAnimations — pret animations.asm. On the opponent's turn, AMNESIA and
; REST reuse the CONF_ANIM / SLP_ANIM status animations.
; ===========================================================================
ShareMoveAnimations:
    mov al, [ebp + hWhoseTurn]
    and al, al
    jz .ret                                  ; ret z — player's turn
    mov al, [ebp + wAnimationID]
    cmp al, AMNESIA
    mov bh, CONF_ANIM                        ; ld b, CONF_ANIM
    jz .replaceAnim
    cmp al, REST
    mov bh, SLP_ANIM
    jnz .ret                                 ; ret nz
.replaceAnim:
    mov al, bh
    mov [ebp + wAnimationID], al
.ret:
    ret

; ===========================================================================
; PlayApplyingAttackAnimation — pret animations.asm:488. The generic post-move
; effect (shake screen / blink pic "to show damage"), dispatched by
; wAnimationType. The AnimationTypePointerTable dispatch (shake/blink) lands in
; Stage 3; the wAnimationType==0 early-out is faithful now.
; ---------------------------------------------------------------------------
; Generic animation shown after the move's individual animation. Which one
; depends on whether the move has an additional effect and on whose turn it is.
; pret's vc_hook line is a Virtual-Console marker with no runtime effect.
; The TODO-HW that stood here through Stage 2 is RETIRED: the dispatch is live.
PlayApplyingAttackAnimation:
    mov al, [ebp + wAnimationType]
    and al, al
    jz .done                                 ; ret z — no applying animation
    ; pret: dec a / add a / ld c,a / ld b,0 / ld hl,Table / add hl,bc /
    ;       ld a,[hli] / ld h,[hl] / ld l,a / jp hl  — a 2-byte dw index.
    ; AnimationTypePointerTable is dd here (flat program-image addresses, the
    ; file's standard model), so the index scales by 4 rather than 2.
    movzx ecx, al
    dec ecx                                  ; dec a — types are 1-based
    jmp [AnimationTypePointerTable + ecx*4]  ; jp hl
.done:
    ret

; ===========================================================================
; SCREEN SHAKE + BLINK — pret animations.asm (battle_animations Stage 3b).
;
; The shake bodies live in the mirror src/engine/gfx/screen_effects.asm (pret
; engine/gfx/screen_effects.asm) and displace the whole canvas through
; H_SCX/H_SCY; read the projection note at the top of that file before touching
; anything here. pret reaches them with `predef_jump`; the port jumps directly
; (it has no predef dispatcher), the same convention ReadTrainer uses for AddBCD.
; ===========================================================================

ShakeScreenVertically:
    call PlayApplyingAttackSound
    mov bh, 8                                ; ld b,8
    jmp AnimationShakeScreenVertically

ShakeScreenHorizontallyHeavy:
    call PlayApplyingAttackSound
    mov bh, 8
    jmp AnimationShakeScreenHorizontallyFast

ShakeScreenHorizontallySlow:
    mov bh, 6                                ; lb bc, 6, 2
    mov bl, 2
    jmp AnimationShakeScreenHorizontallySlow

BlinkEnemyMonSprite:
    call PlayApplyingAttackSound
    jmp AnimationBlinkEnemyMon

ShakeScreenHorizontallyLight:
    call PlayApplyingAttackSound
    mov bh, 2
    jmp AnimationShakeScreenHorizontallyFast

ShakeScreenHorizontallySlow2:
    mov bh, 3                                ; lb bc, 3, 2
    mov bl, 2
    ; falls through, as in pret

; ---------------------------------------------------------------------------
; AnimationShakeScreenHorizontallySlow — BH (b) = pixels per sweep, BL (c) =
; sweeps. Walks the canvas one pixel right per step and back again, c times.
; This one drives the displacement itself rather than going through the predef,
; so it carries the same projection: pret's rWX becomes the port's H_SCX.
;
; DEVIATION{class=projection; pret=engine/battle/animations.asm:AnimationShakeScreenHorizontallySlow; behavior=steps the BG scroll shadow H_SCX instead of the window register rWX, so the displacement is whole-canvas and its sense is inverted; evidence=the port draws the battle screen on the BG layer rather than the GB's full-screen window (rWY=0 in core.asm), and commit_shadow_regs rewrites IO_SCX from H_SCX every DelayFrame so the shadow is the only channel that survives a multi-frame effect; lifetime=permanent, part of the port's BG-layer battle-screen model}
;
; The `dec bh` counters stay 8-bit deliberately (pret's `dec b`): entry values
; are 6, 3, 8 and 2, never 0, and an 8-bit decrement reproduces the GB's bound
; exactly. Both pushes protect BL (pret c) from the `mov bl,2` delay argument.
; ---------------------------------------------------------------------------
AnimationShakeScreenHorizontallySlow:
    push ebx                                 ; push bc
    push ebx                                 ; push bc
.loop1:
    mov al, [ebp + H_SCX]                    ; ldh a,[rWX]
    inc al
    mov [ebp + H_SCX], al
    mov bl, 2                                ; ld c,2
    call DelayFrames
    dec bh                                   ; dec b
    jnz .loop1
    pop ebx                                  ; pop bc
.loop2:
    mov al, [ebp + H_SCX]
    dec al
    mov [ebp + H_SCX], al
    mov bl, 2
    call DelayFrames
    dec bh
    jnz .loop2
    pop ebx                                  ; pop bc
    dec bl                                   ; dec c
    jnz AnimationShakeScreenHorizontallySlow ; jr nz — self-recursion, as in pret
    ret

AnimationUnusedShakeScreen: ; unreferenced in pret
; Shakes the screen for a while.
    mov bh, 5                                ; ld b,$5
    ; falls through, as in pret

AnimationShakeScreenVertically:
    jmp PredefShakeScreenVertically          ; pret: predef_jump

AnimationShakeScreen:
; Shakes the screen for a while. Used in Earthquake/Fissure/etc. animations.
    mov bh, 8                                ; ld b,$8
    ; falls through, as in pret

AnimationShakeScreenHorizontallyFast:
    jmp PredefShakeScreenHorizontally        ; pret: predef_jump

AnimationBlinkEnemyMon:
; Make the enemy mon's sprite blink on and off for a second or two.
    mov esi, AnimationBlinkMon               ; ld hl, AnimationBlinkMon
    jmp CallWithTurnFlipped

; ===========================================================================
; AnimationWavyScreen — used in Psywave/Psychic/Confusion (Stage 3c).
;
; pret drives this per SCANLINE: it turns the window off, then spins on rSTAT
; waiting for H-blank and writes a fresh rSCX for EVERY line, so each line is
; displaced by its own entry from WavyScreenLineOffsets. The pattern also scrolls
; down one line per frame (the outer loop's `inc hl`), and the whole thing runs
; for 255 frames (`ld c, $ff`).
;
; The port composites a whole frame at once and has no scanline interrupt, so the
; inner rSTAT/rLY loop cannot be translated literally. Instead the renderer grew
; a per-row displacement table (g_row_xoff / g_row_xoff_on in src/ppu/ppu.asm)
; and this routine fills it once per frame from the same pret data, advancing the
; phase by one row per frame. Same visual, same duration, same source data —
; expressed per-row instead of per-scanline.
;
; DEVIATION{class=HAL; pret=engine/battle/animations.asm:AnimationWavyScreen; behavior=fills a per-row displacement table consulted by the BG blit once per frame instead of writing rSCX per scanline from an rSTAT H-blank spin, and a negative displacement clamps at the left edge instead of wrapping the 256px BG torus; evidence=the software compositor builds an entire frame in one pass and has no scanline interrupt or mid-frame register latch, and bg_surface is a flat 384px row with no horizontal wrap so a negative source X would sample the previous row and tear rather than wrap; lifetime=permanent, inherent to the whole-frame software compositor}
;
; WavyScreenLineOffsets is pret's own inline table in its engine/ file, so it
; stays in this mirror. It is 32 entries plus pret's $80 terminator; the port
; indexes it modulo 32 rather than scanning for the terminator, which is the same
; sequence — the terminator byte is retained so the data stays byte-identical to
; pret and a reader can check it against the disassembly.
; ===========================================================================
AnimationWavyScreen:
    mov esi, GB_TILEMAP0                     ; ld hl, vBGMap0
    call BattleAnimCopyTileMapToVRAM
    call Delay3
    mov byte [ebp + hAutoBGTransferEnabled], 0
    mov byte [ebp + H_WY], SCREEN_HEIGHT_PX  ; ldh [hWY],a — window off
    mov byte [wavy_phase], 0
    mov byte [g_row_xoff_on], 1              ; arm the per-row HAL
    ; BL is pret's c. DelayFrame opens with pushad and WavyScreen_SetSCX touches
    ; only EAX/ECX/EDX, so the counter survives the loop body. 8-bit dec, as on
    ; the GB: $FF gives exactly 255 frames.
    mov bl, 0xFF                             ; ld c,$ff
.frameLoop:
    call WavyScreen_SetSCX                   ; fill g_row_xoff for this frame
    call DelayFrame
    inc byte [wavy_phase]                    ; pret: inc hl — pattern scrolls 1 row/frame
    dec bl                                   ; dec c
    jnz .frameLoop
    mov byte [g_row_xoff_on], 0              ; disarm — restore the identity fast path
    mov byte [ebp + H_WY], 0                 ; xor a / ldh [hWY],a
    call SaveScreenTilesToBuffer2
    call ClearScreen
    mov byte [ebp + hAutoBGTransferEnabled], 1
    call Delay3
    call LoadScreenTilesFromBuffer2
    mov esi, GB_TILEMAP1                     ; ld hl, vBGMap1
    jmp BattleAnimCopyTileMapToVRAM          ; call + ret

; ---------------------------------------------------------------------------
; WavyScreen_SetSCX — pret writes ONE scanline's rSCX per call, spinning on rSTAT
; until H-blank. Here it publishes the whole frame's worth of displacements in one
; pass: g_row_xoff[row] = WavyScreenLineOffsets[(wavy_phase + row) % 32], which is
; the same line-to-entry mapping pret's per-scanline `inc hl` produces.
;
; The wave covers the WHOLE canvas, not just the projected 20x18 battle frame —
; consistent with the Stage 3b shake, where the maintainer's directive is that the
; matte moves with the scene rather than the frame being displaced inside a static
; border.
; Clobbers EAX, ECX, EDX, ESI.
; ---------------------------------------------------------------------------
WavyScreen_SetSCX:
    movzx ecx, byte [wavy_phase]
    xor edx, edx                             ; screen row
.row:
    mov eax, ecx
    add eax, edx
    and eax, WAVY_SCREEN_NUM_OFFSETS - 1     ; % 32 (power of two)
    mov al, [WavyScreenLineOffsets + eax]
    mov [g_row_xoff + edx], al
    inc edx
    cmp edx, RENDER_H
    jb .row
    ret

; ===========================================================================
; Func_78e98 / WriteLowerByteOfBGMapAndEnableBGTransfer — pret animations.asm.
; Clear the BG tilemap, copy to VRAM via the auto-BG-transfer HRAM staging, and
; restore. BG-transfer boundary: these drive hAutoBGTransferEnabled/Dest, which
; the port's vblank BG path consumes; faithful sequencing is preserved.
; ===========================================================================
Func_78e98:
    call SaveScreenTilesToBuffer2
    mov byte [ebp + hAutoBGTransferEnabled], 0   ; xor a / ldh [hAutoBGTransferEnabled],a
    call ClearScreen
    mov bh, GB_TILEMAP0 >> 8                  ; ld h, HIGH(vBGMap0)
    call WriteLowerByteOfBGMapAndEnableBGTransfer
    call Delay3
    mov byte [ebp + hAutoBGTransferEnabled], 0
    call LoadScreenTilesFromBuffer2
    mov bh, GB_TILEMAP1 >> 8                  ; ld h, HIGH(vBGMap1) → fall through
WriteLowerByteOfBGMapAndEnableBGTransfer:
    mov bl, GB_TILEMAP0 & 0xFF               ; ld l, LOW(vBGMap0) (0x00) → BX = hl
    call BattleAnimCopyTileMapToVRAM
    mov byte [ebp + hAutoBGTransferEnabled], 1
    ret

; In: BX = hl (BH=high, BL=low) of the BG map dest.
BattleAnimCopyTileMapToVRAM:
    mov [ebp + H_AUTO_BG_TRANSFER_DEST + 1], bh   ; ld a,h / ldh [hAutoBGTransferDest+1],a
    mov [ebp + H_AUTO_BG_TRANSFER_DEST], bl       ; ld a,l / ldh [hAutoBGTransferDest],a
    jmp Delay3

; ===========================================================================
; PlaySubanimation — pret animations.asm. Play each frame block of the loaded
; subanimation: resolve frame block / base coord / mode from the 3-byte subentry,
; draw it, run the per-animation-id special effect, then advance (or reverse) to
; the next subentry until wSubAnimCounter runs out.
; ===========================================================================
PlaySubanimation:
    mov al, [ebp + wAnimSoundID]
    cmp al, NO_MOVE - 1
    jz .skipPlayingSound
    call GetMoveSound
    call PlaySound
.skipPlayingSound:
    mov byte [ebp + wFBDestAddr + 1], (W_SHADOW_OAM & 0xFF)   ; wFBDestAddr = wShadowOAM (big-endian)
    mov byte [ebp + wFBDestAddr], (W_SHADOW_OAM >> 8)
    mov esi, [wSubAnimSubEntryAddr32]        ; hl = subentry addr (flat)
.loop:
    movzx ebx, byte [esi]                    ; ld c,[hl] — frame block ID; ld b,0
    mov ebx, [FrameBlockPointers + ebx*4]    ; bc = frame block addr (flat)
    movzx eax, byte [esi + 1]                ; base coordinate ID
    lea edi, [FrameBlockBaseCoords + eax*2]  ; &pair (flat)
    mov al, [edi]                            ; Y
    mov [ebp + wBaseCoordY], al
    mov al, [edi + 1]                        ; X
    mov [ebp + wBaseCoordX], al
    mov al, [esi + 2]                        ; frame block mode
    mov [ebp + wFBMode], al
    call DrawFrameBlock                      ; In: EBX = frame block flat ptr
    call DoSpecialEffectByAnimationId
    mov al, [ebp + wSubAnimCounter]
    dec al
    mov [ebp + wSubAnimCounter], al
    jz .done                                 ; ret z
    mov esi, [wSubAnimSubEntryAddr32]        ; reload (DrawFrameBlock clobbers ESI)
    mov al, [ebp + wSubAnimTransform]
    cmp al, SUBANIMTYPE_REVERSE
    jz .reverse
    add esi, 3                               ; ld bc,3 ; add hl,bc
    jmp .storeAndLoop
.reverse:
    sub esi, 3                               ; ld bc,-3 ; add hl,bc
.storeAndLoop:
    mov [wSubAnimSubEntryAddr32], esi
    jmp .loop
.done:
    ret

; ===========================================================================
; AnimationCleanOAM — pret animations.asm. Delay a frame, then clear all sprites.
; ===========================================================================
AnimationCleanOAM:
    push esi
    push edx
    push ebx
    push eax
    call DelayFrame
    call ClearSprites
    pop eax
    pop ebx
    pop edx
    pop esi
    ret

; ===========================================================================
; DoSpecialEffectByAnimationId — pret animations.asm. After each frame block, run
; the special-effect routine keyed by wAnimationID (if any).
; ===========================================================================
DoSpecialEffectByAnimationId:
    push esi
    push edx
    push ebx
    mov al, [ebp + wAnimationID]
    mov esi, AnimationIdSpecialEffects       ; ld hl, table (flat)
    mov edx, 5                               ; entry stride (port db id + dd ptr; pret 3)
    call IsInArray
    jnc .done
    inc esi                                  ; skip id byte
    mov esi, [esi]                           ; handler flat addr (dd)
    push dword .done
    jmp esi
.done:
    pop ebx
    pop edx
    pop esi
    ret

; ===========================================================================
; AnimationDelay10 — pret animations.asm. Wait 10 frames.
; ===========================================================================
AnimationDelay10:
    mov bl, 10                               ; ld c,10 → BL
    jmp DelayFrames

; ===========================================================================
; SetAnimationPalette — pret animations.asm:565. Set the animation OBJ palettes:
; wAnimPalette (PlayAnimation loads it into OBP0 around each subanimation) and
; OBP1. The SGB branch is LIVE: wOnSGB=1 in the port (colour hardware, set at
; init exactly as pret LoadSGB does on CGB), so wAnimPalette=$F0 — the measured
; real-hardware value (memory battle-anim-cgb-obj-palette-model). pret's
; vc_hook lines are Virtual-Console markers with no runtime effect — nothing
; to port.
; ===========================================================================
SetAnimationPalette:
    mov al, [ebp + wOnSGB]
    and al, al
    mov al, 0xE4                             ; ld a,$e4 (flags preserved)
    jz .notSGB                               ; jr z
    mov al, 0xF0
    mov [ebp + wAnimPalette], al
    mov bh, 0xE4                             ; ld b,$e4
    mov al, [ebp + wAnimationID]
    cmp al, TRADE_BALL_DROP_ANIM
    jb .next                                 ; jr c
    cmp al, TRADE_BALL_POOF_ANIM + 1
    jae .next                                ; jr nc
    mov bh, 0xF0
.next:
    mov al, bh                               ; ld a,b
    mov [ebp + IO_OBP0], al                  ; ldh [rOBP0],a
    mov al, 0x6C
    mov [ebp + IO_OBP1], al                  ; ldh [rOBP1],a
    call UpdateCGBPal_OBP0
    call UpdateCGBPal_OBP1
    ret
.notSGB:
    mov al, 0xE4
    mov [ebp + wAnimPalette], al
    mov [ebp + IO_OBP0], al                  ; ldh [rOBP0],a
    mov al, 0x6C
    mov [ebp + IO_OBP1], al                  ; ldh [rOBP1],a
    call UpdateCGBPal_OBP0
    call UpdateCGBPal_OBP1
    ret

; ===========================================================================
; CallWithTurnFlipped — pret animations.asm. Call a routine with hWhoseTurn
; flipped, then restore it.  In: ESI = routine address (pret hl).
; ===========================================================================
CallWithTurnFlipped:
    mov al, [ebp + hWhoseTurn]
    push eax                                 ; push af (save turn)
    xor al, 1
    mov [ebp + hWhoseTurn], al
    push dword .returnAddress
    jmp esi                                  ; jp hl
.returnAddress:
    pop eax                                  ; pop af
    mov [ebp + hWhoseTurn], al
    ret

; ===========================================================================
; GetMoveSound / IsCryMove — pret animations.asm. Resolve the SFX (and freq/tempo
; modifiers) for the current animation's sound id; cry moves (Growl/Roar) pull the
; species cry instead.  In: AL = MoveSoundTable index. Out: AL = SFX id.
; ===========================================================================
GetMoveSound:
    movzx ecx, al
    lea esi, [ecx + ecx*2]                    ; index*3
    add esi, MoveSoundTable                    ; flat
    mov al, [esi]                            ; ld a,[hli] — base sound
    inc esi
    mov bh, al                               ; ld b,a
    call IsCryMove
    jnc .NotCryMove
    mov al, [ebp + hWhoseTurn]
    and al, al
    jnz .enemyCry                            ; jr nz, .next
    mov al, [ebp + wBattleMonSpecies]
    jmp .Continue
.enemyCry:
    mov al, [ebp + wEnemyMonSpecies]
.Continue:
    push esi
    call GetCryData
    mov bh, al                               ; ld b,a
    pop esi
    mov al, [ebp + wFrequencyModifier]
    add al, [esi]                            ; add [hl]
    mov [ebp + wFrequencyModifier], al
    inc esi
    mov al, [ebp + wTempoModifier]
    add al, [esi]
    mov [ebp + wTempoModifier], al
    jmp .done
.NotCryMove:
    mov al, [esi]                            ; ld a,[hli] — freq modifier
    inc esi
    mov [ebp + wFrequencyModifier], al
    mov al, [esi]                            ; ld a,[hli] — tempo modifier
    inc esi
    mov [ebp + wTempoModifier], al
.done:
    mov al, bh                               ; ld a,b
    ret

IsCryMove:
; set carry if the move animation involves playing a monster cry
    mov al, [ebp + wAnimationID]
    cmp al, GROWL
    jz .CryMove
    cmp al, ROAR
    jz .CryMove
    and al, al                               ; clear carry
    ret
.CryMove:
    stc
    ret

; ===========================================================================
; PlayApplyingAttackSound — pret animations.asm. Play not-very/neutral/super-
; effective SFX (or nothing if the move was ineffective) based on wDamageMultipliers.
; ===========================================================================
PlayApplyingAttackSound:
    call WaitForSoundToFinish
    mov al, [ebp + wDamageMultipliers]
    and al, 0x7F
    jz .ret                                  ; ret z — ineffective, no sound
    cmp al, 10
    mov al, 0x20
    mov bh, 0x30
    mov bl, SFX_DAMAGE                       ; ld c, SFX_DAMAGE
    jz .playSound
    mov al, 0xE0
    mov bh, 0xFF
    mov bl, SFX_SUPER_EFFECTIVE
    jnc .playSound                           ; jr nc (CF from cmp al,10)
    mov al, 0x50
    mov bh, 0x01
    mov bl, SFX_NOT_VERY_EFFECTIVE
.playSound:
    mov [ebp + wFrequencyModifier], al
    mov al, bh
    mov [ebp + wTempoModifier], al
    mov al, bl
    jmp PlaySound
.ret:
    ret

; ---------------------------------------------------------------------------
; AdjustOAMBlock{X,Y}Pos / ...2 — pret engine/battle/animations.asm:1381-1426.
;
; Step a run of OAM entries along one axis by wCoordAdjustmentAmount, putting an
; entry off-screen once it leaves the visible area. Shared by the CUT animation
; (cut2.asm:AnimCut) and the Strength boulder-dust animation
; (dust_smoke.asm:AnimateBoulderDust).
;   AdjustOAMBlockXPos  — In: EDX (de) = OAM entry ptr; copies it to ESI
;   AdjustOAMBlockXPos2 — In: ESI (hl) = OAM entry ptr (callers that already hold it)
; In both: BL (pret c) = entry count; wCoordAdjustmentAmount = signed delta.
; ESI/EDX are GB offsets into wShadowOAM — read/write as [ebp + esi].
; Clobbers: AL, BH, ESI. Out: BL = 0.
; ---------------------------------------------------------------------------
AdjustOAMBlockXPos:
    mov esi, edx                             ; ld l, e / ld h, d
AdjustOAMBlockXPos2:
.loop:
    mov bh, [ebp + wCoordAdjustmentAmount]   ; ld a, [wCoordAdjustmentAmount] / ld b, a
    mov al, [ebp + esi]                      ; ld a, [hl] — this entry's X
    add al, bh                               ; add b
    cmp al, 168
    jb .skipPuttingEntryOffScreen            ; jr c — still on screen
; put off-screen if X >= 168. hl points at the X byte, so `dec hl` reaches THIS
; entry's Y byte: writing 160 there hides the entry.
    dec esi
    mov al, SCREEN_HEIGHT_PX + OAM_Y_OFS     ; 160 — below the visible area
    mov [ebp + esi], al                      ; ld [hli], a
    inc esi
.skipPuttingEntryOffScreen:
    mov [ebp + esi], al                      ; ld [hl], a
    add esi, OBJ_SIZE                        ; add hl, de (de = OBJ_SIZE in pret)
    dec bl                                   ; dec c
    jnz .loop
    ret

AdjustOAMBlockYPos:
    mov esi, edx                             ; ld l, e / ld h, d
AdjustOAMBlockYPos2:
.loop:
    mov bh, [ebp + wCoordAdjustmentAmount]
    mov al, [ebp + esi]                      ; ld a, [hl] — this entry's Y
    add al, bh
    cmp al, 112
    jb .skipSettingPreviousEntrysAttribute   ; jr c — still on screen
; BUG{class=data-model; pret=engine/battle/animations.asm:AdjustOAMBlockYPos; behavior=the off-screen path writes 160 to the PREVIOUS OAM entry's attribute byte as well as hiding this entry, flipping that sprite's palette/priority/flip bits; evidence=pret animations.asm:1419 carries the comment "bug, sets previous OAM entry's attribute" — hl already points at Y (offset 0) here, unlike the X routine where it points at X (offset 1), so dec hl lands one byte BEFORE this entry; lifetime=permanent Gen-1 behavior, fixed only at BUG_FIX_LEVEL >= 2}
;
; The intended effect still happens: AL is 160 when `ld [hl],a` writes this entry's
; Y below, hiding it. The stray write to the previous attribute is pure collateral.
%if BUG_FIX_LEVEL >= 2
    mov al, SCREEN_HEIGHT_PX + OAM_Y_OFS     ; fix: hide this entry without the stray write
%else
    dec esi                                  ; THE BUG: → previous entry's attribute
    mov al, SCREEN_HEIGHT_PX + OAM_Y_OFS     ; ld a, 160
    mov [ebp + esi], al                      ; ld [hli], a — clobbers prev attribute
    inc esi
%endif
.skipSettingPreviousEntrysAttribute:
    mov [ebp + esi], al                      ; ld [hl], a
    add esi, OBJ_SIZE                        ; add hl, de
    dec bl                                   ; dec c
    jnz .loop
    ret

; ===========================================================================
; SCREEN / PALETTE SPECIAL EFFECTS — pret animations.asm (battle_animations
; Stage 3). Every routine here is a plain BGP write plus DelayFrames, and in
; this port that is the WHOLE effect: the software PPU renders raw GB colour
; indices into the back buffer and commit_palette (boot/video.asm, called from
; DelayFrame via src/home/vblank.asm) re-maps the DAC whenever IO_BGP changes.
; So `mov [ebp+IO_BGP], al` + UpdateCGBPal_BGP is the literal translation with
; no HAL boundary — no ; TODO-HW is owed here.
;
; wOnSGB is 1 in this port (colour hardware — memory
; battle-anim-cgb-obj-palette-model), so the SGB column of every lb bc pair and
; FlashScreenLongSGB are the live paths, exactly as on real CGB hardware.
;
; GROUND TRUTH for this family (mGBA on the sha1-verified golden ROM, recorded
; in that memory as "the AnimationFlashScreenLong cycle"): BGP goes
; 6F,1B,00 x3 then E4. That trace is NOT AnimationFlashScreenLong — neither
; FlashScreenLong table contains $6F or $1B (they run F8,FC,FF,FC,F8,E4,90,40,
; 00,40,90,E4). It is AnimationDarkScreenPalette ($6F) followed by three
; AnimationFlashScreen calls ($1B invert, $00 white-out, restore $6F) and then
; AnimationResetScreenPalette ($E4) — i.e. the SE_DARK_SCREEN_PALETTE /
; SE_DARK_SCREEN_FLASH / SE_RESET_SCREEN_PALETTE stream shape that
; data/moves/animations.asm uses for Leer/Growl/Hyper Beam. So the trace
; validates these three routines, and the memory's attribution is corrected.
; ===========================================================================

; --- subanimation-counter gated flashes (pret animations.asm:836/843/873) ---
FlashScreenEveryEightFrameBlocks:
    mov al, [ebp + wSubAnimCounter]
    and al, 7                                ; is the counter a multiple of 8?
    jnz .done                                ; call z — skip unless zero
    call AnimationFlashScreen
.done:
    ret

FlashScreenEveryFourFrameBlocks:
    mov al, [ebp + wSubAnimCounter]
    and al, 3
    jnz .done
    call AnimationFlashScreen
.done:
    ret

; flashes the screen at 3 points in the subanimation — unreferenced in pret,
; translated for completeness (pret keeps it too).
FlashScreenUnused:
    mov al, [ebp + wSubAnimCounter]
    cmp al, 14
    je AnimationFlashScreen                  ; jp z
    cmp al, 9
    je AnimationFlashScreen
    cmp al, 2
    je AnimationFlashScreen
    ret

; ---------------------------------------------------------------------------
; AnimationFlashScreenLong — flashes the screen for an extended period
; (48 frames). ESI = pret hl (flat pointer into the palette table).
; ---------------------------------------------------------------------------
AnimationFlashScreenLong:
    mov byte [ebp + wFlashScreenLongCounter], 3  ; cycle through the palettes 3 times
    mov al, [ebp + wOnSGB]
    and al, al
    mov esi, FlashScreenLongMonochrome           ; ld hl,.. (mov preserves flags)
    jz .loop
    mov esi, FlashScreenLongSGB
.loop:
    push esi
.innerLoop:
    mov al, [esi]                            ; ld a,[hli] — flat table, not [ebp+..]
    inc esi
    cmp al, 1
    je .endOfPalettes
    mov [ebp + IO_BGP], al                   ; ldh [rBGP],a
    call UpdateCGBPal_BGP
    call FlashScreenLongDelay
    jmp .innerLoop
.endOfPalettes:
    mov al, [ebp + wFlashScreenLongCounter]
    dec al                                   ; sets ZF for the jnz below
    mov [ebp + wFlashScreenLongCounter], al  ; mov does not disturb ZF
    pop esi                                  ; pop hl — likewise flag-neutral
    jnz .loop
    ret

; causes a delay of 2 frames for the first cycle and 1 frame for the second and
; third. Every `mov bl,` below stands in for pret's flag-neutral `ld c,`, so the
; ZF from the preceding `cmp` survives to its `je` — see the flag-preservation
; rule in the asm-translation skill.
FlashScreenLongDelay:
    mov al, [ebp + wFlashScreenLongCounter]
    cmp al, 4                                ; never true: the counter starts at 3
    mov bl, 4
    je .delayFrames
    cmp al, 3
    mov bl, 2
    je .delayFrames
    cmp al, 2                                ; nothing is done with this
    mov bl, 1
.delayFrames:
    jmp DelayFrames                          ; jp DelayFrames (BL = pret c)

; ---------------------------------------------------------------------------
; AnimationFlashScreen — invert the BG palette, white it out, then restore.
; ---------------------------------------------------------------------------
AnimationFlashScreen:
    mov al, [ebp + IO_BGP]
    push eax                                 ; push af — save initial palette
    mov al, 0x1B                             ; %00011011 — 0,1,2,3 (inverted colors)
    mov [ebp + IO_BGP], al
    call UpdateCGBPal_BGP
    mov bl, 2
    call DelayFrames
    xor al, al                               ; white out background
    mov [ebp + IO_BGP], al
    call UpdateCGBPal_BGP
    mov bl, 2
    call DelayFrames
    pop eax                                  ; pop af
    mov [ebp + IO_BGP], al                   ; restore initial palette
    call UpdateCGBPal_BGP
    ret

; ---------------------------------------------------------------------------
; The lb bc palette pairs (b = non-SGB value, c = SGB value) and their shared
; setter. BH = pret b, BL = pret c.
; ---------------------------------------------------------------------------
AnimationDarkScreenPalette:
; Changes the screen's palette to a dark palette.
    mov bh, 0x6F
    mov bl, 0x6F
    jmp SetAnimationBGPalette

AnimationDarkenMonPalette:
; Darkens the mon sprite's palette.
    mov bh, 0xF9
    mov bl, 0xF4
    jmp SetAnimationBGPalette

AnimationUnusedPalette1:
    mov bh, 0xFE
    mov bl, 0xF8
    jmp SetAnimationBGPalette

AnimationUnusedPalette2:
    mov bh, 0xFF
    mov bl, 0xFF
    jmp SetAnimationBGPalette

AnimationResetScreenPalette:
; Restores the screen's palette to the normal palette.
    mov bh, 0xE4
    mov bl, 0xE4
    jmp SetAnimationBGPalette

AnimationUnusedPalette3:
    mov bh, 0x00
    mov bl, 0x00
    jmp SetAnimationBGPalette

AnimationLightScreenPalette:
; Changes the screen to use a palette with light colors.
    mov bh, 0x90
    mov bl, 0x90
    jmp SetAnimationBGPalette

AnimationUnusedPalette4:
    mov bh, 0x40
    mov bl, 0x40
    ; falls through, as in pret

SetAnimationBGPalette:
    mov al, [ebp + wOnSGB]
    and al, al
    mov al, bh                               ; ld a,b — flag-neutral, ZF still from `and`
    jz .next
    mov al, bl                               ; ld a,c
.next:
    mov [ebp + IO_BGP], al                   ; ldh [rBGP],a
    call UpdateCGBPal_BGP
    ret

; ===========================================================================
; MON-PIC TILEMAP HELPERS — pret animations.asm (battle_animations Stage 4).
;
; PROJECTION (docs/current_plan_battle_animations.md, geometry directive). These
; routines address wTileMap, so every pret COORDINATE is re-derived through
; BCOORD(x,y) (+10 col / +3 row) and every pret row STRIDE stays the literal
; SCREEN_WIDTH — which is 40 here and 20 in pret, each meaning "my tilemap's
; stride". The two roles are NOT interchangeable: pret writes the player-pic
; origin as `5 * SCREEN_WIDTH + 1`, which is the tile COORDINATE (1,5) and
; becomes BCOORD(1, 5); the enemy branch's bare `ld a, 12` is the coordinate
; (12,0) and becomes BCOORD(12, 0). Sites are tagged `; PROJ`.
;
; These write tilemap INDICES, never tile PATTERN bytes, so no
; g_tilecache_dirty arming is owed (contrast LoadMoveAnimationTiles, which goes
; through CopyVideoData).
;
; hAutoBGTransferEnabled is written verbatim. It is INERT in this port —
; do_bg_transfer was deleted from the DelayFrame pipeline (see the retirement
; note in src/home/vblank.asm) and render_bg reads W_TILEMAP directly — so the
; writes cost nothing and keep the routines byte-comparable against pret.
; ===========================================================================

; ---------------------------------------------------------------------------
; AnimationBlinkMon / AnimationShowMonPic and the enemy-side CallWithTurnFlipped
; wrappers — pret animations.asm.
; ---------------------------------------------------------------------------
global AnimationBlinkMon
AnimationBlinkMon:
; Make the mon's sprite blink on and off for a second or two.
    push eax                                 ; push af
    mov bl, 6                                ; ld c, 6 — pret leaves c = 0 on exit
.loop:
    push ebx
    call AnimationHideMonPic
    mov bl, 5
    call DelayFrames
    call AnimationShowMonPic
    mov bl, 5
    call DelayFrames
    pop ebx
    dec bl                                   ; 8-bit, as pret
    jnz .loop
    pop eax                                  ; pop af
    ret

global AnimationShowMonPic
AnimationShowMonPic:
    xor al, al                               ; TILEMAP_MON_PIC
    call GetTileIDList
    call GetMonSpriteTileMapPointerFromRowCount
    call CopyPicTiles
    jmp Delay3

global AnimationShowEnemyMonPic
AnimationShowEnemyMonPic:
; Shows the enemy mon's front sprite. Used in animations like Seismic Toss to
; make the mon's sprite reappear after it disappears offscreen.
    mov esi, AnimationShowMonPic
    jmp CallWithTurnFlipped

global AnimationHideEnemyMonPic
AnimationHideEnemyMonPic:
; Hides the enemy mon's sprite
    xor al, al
    mov [ebp + hAutoBGTransferEnabled], al
    mov esi, AnimationHideMonPic
    call CallWithTurnFlipped
    mov al, 1
    mov [ebp + hAutoBGTransferEnabled], al
    jmp Delay3

; ---------------------------------------------------------------------------
; AnimationHideMonPic / ClearMonPicFromTileMap — pret animations.asm.
; DEVIATION{class=projection; pret=engine/battle/animations.asm:ClearMonPicFromTileMap; behavior=the destination is passed as a full tilemap address in ESI instead of pret's 8-bit A offset from hlcoord 0 0; evidence=under the battle projection the player-pic origin BCOORD(1,5) is W_TILEMAP+331 and every other call site (AnimationResetMonPosition BCOORD(2,5) and BCOORD(11,0), TradeHidePokemon BCOORD(7,2)) is likewise past 255, so pret's single-byte parameter cannot represent them; lifetime=permanent, a consequence of the 40x25 canvas}
; ---------------------------------------------------------------------------
global AnimationHideMonPic
AnimationHideMonPic:
; Hides the mon's sprite.
    mov al, [ebp + hWhoseTurn]
    test al, al
    jz .playerTurn
    mov esi, BCOORD(12, 0)                   ; PROJ — pret `ld a, 12`
    jmp short ClearMonPicFromTileMap
.playerTurn:
    mov esi, BCOORD(1, 5)                    ; PROJ — pret `ld a, 5 * SCREEN_WIDTH + 1`
    ; fall through

; In: ESI = top-left tilemap address of the 7x7 pic (see the DEVIATION above)
global ClearMonPicFromTileMap
ClearMonPicFromTileMap:
    push esi
    push edx
    push ebx
    mov bh, PIC_HEIGHT                       ; lb bc, 7, 7 — b = rows
    mov bl, PIC_WIDTH                        ;              c = cols
    call ClearScreenArea
    pop ebx
    pop edx
    pop esi
    ret

; ---------------------------------------------------------------------------
; GetMonSpriteTileMapPointerFromRowCount — pret animations.asm.
; Puts the tilemap destination address of a mon sprite in ESI, given the row
; count in BH. The usual row count is 7, but it is smaller when sliding a mon
; sprite in/out, to show only part of the pic.
; pret brackets this with push de / pop de because it borrows de as the stride;
; the port needs no scratch, so EDX is preserved by construction.
; ---------------------------------------------------------------------------
global GetMonSpriteTileMapPointerFromRowCount
GetMonSpriteTileMapPointerFromRowCount:
    mov al, [ebp + hWhoseTurn]
    test al, al
    jnz .enemyTurn
    mov esi, BCOORD(1, 5)                    ; PROJ — pret `ld a, 5 * SCREEN_WIDTH + 1`
    jmp short .next
.enemyTurn:
    mov esi, BCOORD(12, 0)                   ; PROJ — pret `ld a, 12`
.next:
    mov al, PIC_HEIGHT
    sub al, bh                               ; ld a, 7 / sub b  (8-bit, as pret)
    jz .done
.loop:
    add esi, SCREEN_WIDTH                    ; stride, not a coordinate — 40 here
    dec al                                   ; 8-bit: bh > 7 wraps to <=255 passes, as on GB
    jnz .loop
.done:
    ret

; ---------------------------------------------------------------------------
; GetTileIDList — pret animations.asm.
; In:  AL  = tile ID list index (TILEMAP_*)
; Out: EDX = flat tile ID list pointer (pret de = 16-bit ROM pointer)
;      BH  = number of rows, BL = number of columns
;      ESI clobbered (pret clobbers hl walking the table), AL = row count
; Row stride is 5, not pret's 3 — see the layout note in src/data/tilemaps.asm.
; ---------------------------------------------------------------------------
global GetTileIDList
GetTileIDList:
    movzx eax, al
    lea esi, [TileIDListPointerTable + eax * 4 + eax]   ; table + 5*index
    mov edx, [esi]                           ; ld a,[hli] x2 -> de = list pointer
    movzx eax, byte [esi + 4]                ; ld a,[hli] -> the dn(height,width) byte
    add esi, 5                               ; pret leaves hl one past the row
    mov bl, al
    and bl, 0x0F                             ; c = number of columns (low nibble)
    shr al, 4                                ; swap a / and $f -> row count
    mov bh, al                               ; b = number of rows
    ret

; ---------------------------------------------------------------------------
; AnimCopyRowLeft / AnimCopyRowRight — pret animations.asm. Shift a row of BL
; tiles one tile left/right. ESI = row cursor (GB-space offset into W_TILEMAP).
; ---------------------------------------------------------------------------
global AnimCopyRowLeft
AnimCopyRowLeft:
; copy a row of c tiles 1 tile left
    mov al, [ebp + esi]                      ; ld a,[hld]
    dec esi
    mov [ebp + esi], al                      ; ld [hli],a
    inc esi
    inc esi                                  ; inc hl
    dec bl                                   ; 8-bit: c = 0 means 256 passes, as on GB
    jnz AnimCopyRowLeft
    ret

global AnimCopyRowRight
AnimCopyRowRight:
; copy a row of c tiles 1 tile right
    mov al, [ebp + esi]                      ; ld a,[hli]
    inc esi
    mov [ebp + esi], al                      ; ld [hld],a
    dec esi
    dec esi                                  ; dec hl
    dec bl                                   ; 8-bit, as above
    jnz AnimCopyRowRight
    ret

; ---------------------------------------------------------------------------
; CopyPicTiles / CopyDownscaledMonTiles / CopyTileIDs{,_NoBGTransfer} /
; CopyTileIDsFromList — pret animations.asm.
; ---------------------------------------------------------------------------
global CopyPicTiles
CopyPicTiles:
    mov al, [ebp + hWhoseTurn]
    test al, al
    mov al, 0x31                             ; base tile ID of player mon sprite
    jz .next
    xor al, al                               ; enemy turn: base tile ID 0
.next:
    mov [ebp + hBaseTileID], al
    jmp short CopyTileIDs_NoBGTransfer

; copy the tiles used when a mon is being sent out of or into a pokeball
; DEVIATION{class=HAL; pret=engine/battle/animations.asm:CopyDownscaledMonTiles; behavior=the leading call GetPredefRegisters is dropped and the arguments arrive in registers from a direct call; evidence=the port has no predef dispatcher so wPredefRegisters is never staged and GetPredefRegisters would load garbage over the live registers, the same convention as ReadTrainer calling AddBCD directly; lifetime=permanent, the port calls predef targets directly}
global CopyDownscaledMonTiles
CopyDownscaledMonTiles:
    mov al, [ebp + wDownscaledMonSize]
    test al, al
    jnz .smallerSize
    mov edx, DownscaledMonTiles_5x5
    jmp short CopyTileIDs_NoBGTransfer
.smallerSize:
    mov edx, DownscaledMonTiles_3x3
    ; fall through

global CopyTileIDs_NoBGTransfer
CopyTileIDs_NoBGTransfer:
    xor al, al
    mov [ebp + hAutoBGTransferEnabled], al
    ; fall through

; In: ESI = tilemap destination, EDX = flat tile ID list, BH = rows, BL = cols
global CopyTileIDs
CopyTileIDs:
    push esi
.rowLoop:
    push ebx
    push esi
    mov bh, [ebp + hBaseTileID]              ; ldh a,[hBaseTileID] / ld b,a
.columnLoop:
    mov al, [edx]                            ; ld a,[de] — flat, the list is program-image data
    add al, bh                               ; add b
    inc edx
    mov [ebp + esi], al                      ; ld [hli],a
    inc esi
    dec bl                                   ; 8-bit: cols = 0 means 256, as on GB
    jnz .columnLoop
    pop esi
    add esi, SCREEN_WIDTH                    ; stride, not a coordinate — 40 here
    pop ebx
    dec bh                                   ; 8-bit: rows = 0 means 256, as on GB
    jnz .rowLoop
    mov al, 1
    mov [ebp + hAutoBGTransferEnabled], al
    pop esi
    ret

; In: BH = tile ID list index, BL = base tile ID (pret b / c)
; DEVIATION{class=HAL; pret=engine/battle/animations.asm:CopyTileIDsFromList; behavior=the leading call GetPredefRegisters is dropped and the arguments arrive in registers from a direct call; evidence=the port has no predef dispatcher so wPredefRegisters is never staged and GetPredefRegisters would load garbage over the live registers, the same convention as ReadTrainer calling AddBCD directly; lifetime=permanent, the port calls predef targets directly}
global CopyTileIDsFromList
CopyTileIDsFromList:
    mov al, bl                               ; ld a,c
    mov [ebp + hBaseTileID], al
    mov al, bh                               ; ld a,b
    push esi
    call GetTileIDList
    pop esi
    jmp CopyTileIDs

; ===========================================================================
; DATA — move-animation tilesets (MoveAnimationTilesPointers is pret's own
; engine/battle/animations.asm inline table, so it stays in this mirror). The
; SpecialEffectPointers / AnimationIdSpecialEffects dispatch tables are pret
; data/battle_anims/*.asm data tables and live in the data layer
; (src/data/battle_anim_dispatch.asm) to satisfy the aux_misplaced rule, exactly
; as MoveEffectPointerTable does.
; ===========================================================================
section .data

; Sequence of horizontal line pixel offsets for the wavy screen animation.
; This sequence vaguely resembles a sine wave. pret's own inline table, so it
; stays in this mirror; byte-identical to pret including the $80 terminator,
; which the port keeps for cross-reference even though it indexes modulo 32.
WavyScreenLineOffsets:
    db 0, 0, 0, 0, 0,  1,  1,  1,  2,  2,  2,  2,  2,  1,  1,  1
    db 0, 0, 0, 0, 0, -1, -1, -1, -2, -2, -2, -2, -2, -1, -1, -1
    db 0x80 ; terminator

; PlayApplyingAttackAnimation's dispatch (pret animations.asm:506). pret's own
; inline table in its engine/ file, so it stays in this mirror; `dd` here rather
; than pret's `dw`, per the flat-pointer model at the top of this file.
AnimationTypePointerTable:
    dd ShakeScreenVertically        ; enemy mon has used a damaging move without a side effect
    dd ShakeScreenHorizontallyHeavy ; enemy mon has used a damaging move with a side effect
    dd ShakeScreenHorizontallySlow  ; enemy mon has used a non-damaging move
    dd BlinkEnemyMonSprite          ; player mon has used a damaging move without a side effect
    dd ShakeScreenHorizontallyLight ; player mon has used a damaging move with a side effect
    dd ShakeScreenHorizontallySlow2 ; player mon has used a non-damaging move

; AnimationFlashScreenLong's BG palette cycles (pret animations.asm:1034/1050).
; These are pret's own inline tables in engine/battle/animations.asm, so they
; stay in this mirror — same rule as MoveAnimationTilesPointers below. Read FLAT
; (pret `ld hl,..` / `ld a,[hli]`), never through [ebp+..]. `dc` is pret's
; crumbs macro (include/data_macros.inc), so the packed bytes are derived, not
; hand-transcribed: monochrome F9 FE FF FE F9 E4 90 40 00 40 90 E4, SGB
; F8 FC FF FC F8 E4 90 40 00 40 90 E4.
FlashScreenLongMonochrome:
    dc 3, 3, 2, 1
    dc 3, 3, 3, 2
    dc 3, 3, 3, 3
    dc 3, 3, 3, 2
    dc 3, 3, 2, 1
    dc 3, 2, 1, 0
    dc 2, 1, 0, 0
    dc 1, 0, 0, 0
    dc 0, 0, 0, 0
    dc 1, 0, 0, 0
    dc 2, 1, 0, 0
    dc 3, 2, 1, 0
    db 1 ; end

FlashScreenLongSGB:
    dc 3, 3, 2, 0
    dc 3, 3, 3, 0
    dc 3, 3, 3, 3
    dc 3, 3, 3, 0
    dc 3, 3, 2, 0
    dc 3, 2, 1, 0
    dc 2, 1, 0, 0
    dc 1, 0, 0, 0
    dc 0, 0, 0, 0
    dc 1, 0, 0, 0
    dc 2, 1, 0, 0
    dc 3, 2, 1, 0
    db 1 ; end

; move-anim tileset pointer table (pret anim_tileset db count/dw ptr/db -1; dd here)
MoveAnimationTilesPointers:
    db 79
    dd MoveAnimationTiles0
    db -1
    db 79
    dd MoveAnimationTiles1
    db -1
    db 64
    dd MoveAnimationTiles2
    db -1

MoveAnimationTiles0:
MoveAnimationTiles2:
    incbin "../gfx/battle/move_anim_0.2bpp"

; grass-leaf tile source — MoveAnimationTiles1 tile 6 (cut.asm) + Game Freak
; splash stars tiles 3/19 (splash.asm LoadShootingStarGraphics).
MoveAnimationTiles1:
    incbin "../gfx/battle/move_anim_1.2bpp"

; The generated battle-animation DATA (AttackAnimationPointers, subanimations,
; frame blocks, base coords, MoveSoundTable) lives in the data layer:
; src/data/battle_anims.asm <- assets/battle_anim_data.inc (Tier-1,
; gen_battle_anim_data.py). Externed above.

section .bss
align 4
; port-local 32-bit flat cursors — see the DEVIATION at the top of this file.
wSubAnimAddrPtr32:      resd 1   ; &SubanimationPointers[id] (pret wSubAnimAddrPtr $D093)
wSubAnimSubEntryAddr32: resd 1   ; current 3-byte subentry addr (pret wSubAnimSubEntryAddr $D095)
; AnimationWavyScreen phase — the index into WavyScreenLineOffsets that screen row
; 0 takes this frame. pret carries the same state as the live `hl` cursor it walks
; with `inc hl`; the port needs a named slot because its loop is per-frame, not
; per-scanline. Port-local (no GB address): pret's cursor is a register, not WRAM.
wavy_phase:             resb 1
