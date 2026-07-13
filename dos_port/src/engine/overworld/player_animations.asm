; player_animations.asm — overworld warp / fly / teleport / fishing animations
; (OW-5.1).
;
; Intended repo path: dos_port/src/engine/overworld/player_animations.asm
; pret source: engine/overworld/player_animations.asm
;
; EnterMapAnim / _LeaveMapAnim drive the map-entry and map-exit cutscenes: a
; fade, then one of three effects selected by status flags — teleport spin
; (PlayerSpinInPlace / PlayerSpinWhileMovingUpOrDown), the overworld Fly bird
; (DoFlyAnimation over a screen-coord list), or a hole-fall
; (LeaveMapThroughHoleAnim). FishingAnim plays the rod-cast / bite sequence.
; DoFlyAnimation, the spin primitives, InitFacingDirectionList / SpinPlayerSprite
; and RestoreFacingDirectionAndYScreenPos are the shared building blocks.
;
; Register map (SM83 -> x86): A->AL, B->BH, C->BL, D->DH, E->DL, HL->ESI.
; GB memory is [ebp+offset]. Adaptations from pret, all following established
; port precedent:
;   * DoFlyAnimation's coord cursor (pret DE) is a FLAT ROM pointer (EDX) —
;     the coord tables live in .data as flat labels, so `ld a,[de]/inc de`
;     becomes `mov al,[edx]/inc edx` (cf. the dw->dd flat-pointer adaptation).
;   * Copies whose SOURCE is a flat ROM label (PlayerSpinningFacingOrder,
;     FishingRodOAM) can't use CopyData (EBP-relative on both operands); they
;     become an inline `rep movsb` (flat src -> EBP-relative WRAM dst), the same
;     pattern as map_sprites.asm:ShowTextStream. WRAM->WRAM copies keep CopyData.
;   * PrintText takes a FLAT ESI to the text stream (cut.asm precedent).
;   * rOBP1/hardware scroll etc. are not touched here.
;
; Retires the EnterMapAnim ret-stub in overworld_stubs.asm (dup_def suppressed
; in the allowlist: the stub stays LINKED for EnterMap's caller until this file
; is promoted to GAME_SRCS at OW-7.2, exactly like SpawnPikachu/pikachu.asm).
; _HandleMidJump + PlayerJumpingYScreenCoords stay in ledges.asm (per ticket).
;
; Check-only (HOME_CHECK_SRCS): externs the unported StopMusic (home/overworld.asm)
; and LoadAnimSpriteGfx (battle-animation gfx loader). BirdSprite + fishing tiles
; are incbin'd here and allowlisted INTERIM (retire + extern when gfx/sprites.asm
; / gfx/fishing.asm land).
;
; Build (check): nasm -f coff -I include/ -I . -o /dev/null \
;                     src/engine/overworld/player_animations.asm
; ---------------------------------------------------------------------------

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_macros.inc"
%include "gb_text.inc"                        ; text_far / text_end
%include "gfx_macros.inc"                     ; dbsprite
%include "assets/audio_constants.inc"         ; SFX_TELEPORT_*/SFX_FLY

; --- symbols not yet in the shared headers (golden sym-verified) ---
%ifndef wSpritePlayerStateData1YPixels
wSpritePlayerStateData1YPixels      equ 0xC104 ; golden 00:c104
%endif
%ifndef wSpritePlayerStateData1XPixels
wSpritePlayerStateData1XPixels      equ 0xC106 ; golden 00:c106
%endif
%ifndef wSpritePlayerStateData1ImageIndex
wSpritePlayerStateData1ImageIndex   equ 0xC102 ; golden 00:c102
%endif
%ifndef wSavedPlayerScreenY
wSavedPlayerScreenY                 equ 0xCD4F ; golden 00:cd4f
%endif
%ifndef wSavedPlayerFacingDirection
wSavedPlayerFacingDirection         equ 0xCD50 ; golden 00:cd50
%endif
%ifndef wFacingDirectionList
wFacingDirectionList                equ 0xCD48 ; golden 00:cd48
%endif
; animation-scratch union at wFlyAnimUsingCoordList / wPlayerSpin*… (all 00:cd3d)
%ifndef wFlyAnimUsingCoordList
wFlyAnimUsingCoordList              equ 0xCD3D ; golden 00:cd3d
%endif
%ifndef wFlyAnimCounter
wFlyAnimCounter                    equ 0xCD3E ; golden 00:cd3e
%endif
%ifndef wFlyAnimBirdSpriteImageIndex
wFlyAnimBirdSpriteImageIndex       equ 0xCD3F ; golden 00:cd3f
%endif
%ifndef wPlayerSpinInPlaceAnimFrameDelay
wPlayerSpinInPlaceAnimFrameDelay          equ 0xCD3D
%endif
%ifndef wPlayerSpinInPlaceAnimFrameDelayDelta
wPlayerSpinInPlaceAnimFrameDelayDelta     equ 0xCD3E
%endif
%ifndef wPlayerSpinInPlaceAnimFrameDelayEndValue
wPlayerSpinInPlaceAnimFrameDelayEndValue  equ 0xCD3F
%endif
%ifndef wPlayerSpinInPlaceAnimSoundID
wPlayerSpinInPlaceAnimSoundID             equ 0xCD40
%endif
%ifndef wPlayerSpinWhileMovingUpOrDownAnimDeltaY
wPlayerSpinWhileMovingUpOrDownAnimDeltaY  equ 0xCD3D
%endif
%ifndef wPlayerSpinWhileMovingUpOrDownAnimMaxY
wPlayerSpinWhileMovingUpOrDownAnimMaxY    equ 0xCD3E
%endif
%ifndef wPlayerSpinWhileMovingUpOrDownAnimFrameDelay
wPlayerSpinWhileMovingUpOrDownAnimFrameDelay equ 0xCD3F
%endif
; wPikachuSpawnState promoted to gb_memmap.inc (0xD430) — OW-A.6.
%ifndef wCurMapTileset
wCurMapTileset                     equ 0xD366 ; golden 00:d366
%endif
%ifndef wStatusFlags6
wStatusFlags6                      equ 0xD731 ; golden 00:d731
%endif
%ifndef wStatusFlags7
wStatusFlags7                      equ 0xD732 ; golden 00:d732
%endif
%ifndef wMovementFlags
wMovementFlags                     equ 0xD735 ; golden 00:d735
%endif
%ifndef wRodResponse
wRodResponse                       equ 0xCD3D ; golden 00:cd3d
%endif
%ifndef wOnSGB
wOnSGB                             equ 0xCF1A ; golden 00:cf1a
%endif
%ifndef wEmotionBubbleSpriteIndex
wEmotionBubbleSpriteIndex          equ 0xCD4F ; golden 00:cd4f
%endif
%ifndef wStandingOnWarpPadOrHole
wStandingOnWarpPadOrHole           equ 0xCD5B ; golden 00:cd5b
%endif
%ifndef wUpdateSpritesEnabled
wUpdateSpritesEnabled              equ 0xCFCA ; golden 00:cfca
%endif
; shadow OAM (golden-verified; Y/TileID pairs)
%ifndef wShadowOAMSprite00YCoord
wShadowOAMSprite00YCoord equ 0xC300
%endif
%ifndef wShadowOAMSprite00TileID
wShadowOAMSprite00TileID equ 0xC302
%endif
%ifndef wShadowOAMSprite01YCoord
wShadowOAMSprite01YCoord equ 0xC304
%endif
%ifndef wShadowOAMSprite01TileID
wShadowOAMSprite01TileID equ 0xC306
%endif
%ifndef wShadowOAMSprite02YCoord
wShadowOAMSprite02YCoord equ 0xC308
%endif
%ifndef wShadowOAMSprite02TileID
wShadowOAMSprite02TileID equ 0xC30A
%endif
%ifndef wShadowOAMSprite03YCoord
wShadowOAMSprite03YCoord equ 0xC30C
%endif
%ifndef wShadowOAMSprite03TileID
wShadowOAMSprite03TileID equ 0xC30E
%endif
%ifndef wShadowOAMSprite39
wShadowOAMSprite39       equ 0xC39C
%endif
%ifndef wShadowOAMSprite39YCoord
wShadowOAMSprite39YCoord equ 0xC39C
%endif

; VRAM tile banks (overworld union — vNPCSprites=0x8000, vNPCSprites2=0x8800)
%ifndef vNPCSprites
vNPCSprites   equ 0x8000
%endif
%ifndef vNPCSprites2
vNPCSprites2  equ 0x8800
%endif

; --- misc constants ---
%ifndef BIT_USED_FLY
BIT_USED_FLY        equ 7   ; wStatusFlags7 bit 7
%endif
%ifndef BIT_ESCAPE_WARP
BIT_ESCAPE_WARP     equ 6   ; wStatusFlags6 bit 6
%endif
%ifndef BIT_DUNGEON_WARP
BIT_DUNGEON_WARP    equ 4   ; wStatusFlags6 bit 4
%endif
%ifndef BIT_LEDGE_OR_FISHING
BIT_LEDGE_OR_FISHING equ 6  ; wMovementFlags bit 6
%endif
%ifndef OBJ_SIZE
OBJ_SIZE            equ 4
%endif
%ifndef SCREEN_HEIGHT_PX
SCREEN_HEIGHT_PX    equ 144
%endif
%ifndef OAM_Y_OFS
OAM_Y_OFS           equ 16
%endif
%ifndef EXCLAMATION_BUBBLE
EXCLAMATION_BUBBLE  equ 0
%endif
; tileset ids for WarpPadAndHoleData
%ifndef INTERIOR
INTERIOR  equ 16
%endif
%ifndef CAVERN
CAVERN    equ 17
%endif
%ifndef FACILITY
FACILITY  equ 22
%endif

global EnterMapAnim
global _LeaveMapAnim
global LeaveMapThroughHoleAnim
global DoFlyAnimation
global LoadBirdSpriteGraphics
global InitFacingDirectionList
global SpinPlayerSprite
global PlayerSpinInPlace
global PlayerSpinWhileMovingUpOrDown
global PlayerSpinWhileMovingDown
global RestoreFacingDirectionAndYScreenPos
global GetPlayerTeleportAnimFrameDelay
global IsPlayerStandingOnWarpPadOrHole
global FishingAnim

extern Delay3                     ; video/frame.asm
extern DelayFrames                ; video/frame.asm
extern GBFadeInFromWhite          ; home/fade.asm
extern GBFadeOutToWhite           ; home/fade.asm
extern Func_151d                  ; engine/overworld/pikachu.asm
extern Func_1510                  ; engine/overworld/pikachu.asm
extern LoadPlayerSpriteGraphics   ; engine/overworld/overworld.asm
extern PlaySound                  ; home/audio.asm (LIVE)
extern PlayDefaultMusic           ; home/audio.asm (LIVE)
extern StopMusic                  ; UNPORTED (pret home/overworld.asm) — fade+StopAllMusic+StopAllSounds
extern CopyData                   ; home/copy_data.asm (WRAM->WRAM)
extern CopyVideoData              ; home/copy2.asm (ESI=VRAM dest, EDX=flat src, BL=count)
extern LoadFontTilePatterns       ; gfx/load_font.asm
extern PrintText                  ; engine/battle/move_effect_helpers.asm (ESI=flat text stream)
extern LoadAnimSpriteGfx          ; UNPORTED (battle-animation sprite-gfx loader)
extern EmotionBubble              ; engine/overworld/trainer_engine.asm (pret: predef)
extern player_sprite              ; engine/overworld/player_gfx.asm — == RedSprite (flat)
extern msgbox_dialog                    ; src/home/text.asm — overworld dialog projection
extern text_msgbox                      ; src/home/text.asm — active msgbox projection (msgbox.inc)

section .text

; ---------------------------------------------------------------------------
; EnterMapAnim — pret engine/overworld/player_animations.asm:EnterMapAnim
; ---------------------------------------------------------------------------
EnterMapAnim:
    call InitFacingDirectionList
    mov al, 0xec
    mov [ebp + wSpritePlayerStateData1YPixels], al
    call Delay3
    push esi                                 ; push hl
    call GBFadeInFromWhite
    ; bit BIT_USED_FLY,[wStatusFlags7] / res it / jr nz — preserve the bit's ZF
    ; across the res (x86 `and [mem]` sets flags), so test a saved copy after.
    mov al, [ebp + wStatusFlags7]
    mov ah, al                               ; saved copy for the test
    and byte [ebp + wStatusFlags7], ~(1 << BIT_USED_FLY) & 0xFF ; res BIT_USED_FLY
    test ah, 1 << BIT_USED_FLY
    jnz .flyAnimation
    mov al, SFX_TELEPORT_ENTER_1
    call PlaySound
    mov al, [ebp + wStatusFlags6]
    test al, 1 << BIT_DUNGEON_WARP           ; bit BIT_DUNGEON_WARP,[hl] (sets ZF)
    pop esi                                   ; pop hl (does not disturb ZF)
    jnz .dungeonWarpAnimation
    call PlayerSpinWhileMovingDown
    mov al, SFX_TELEPORT_ENTER_2
    call PlaySound
    call IsPlayerStandingOnWarpPadOrHole
    mov al, bh                                ; ld a, b
    and al, al
    jnz .done
; if the player is not standing on a warp pad or hole
    mov byte [ebp + wPlayerSpinInPlaceAnimFrameDelay], 0
    mov byte [ebp + wPlayerSpinInPlaceAnimFrameDelayDelta], 1
    mov byte [ebp + wPlayerSpinInPlaceAnimFrameDelayEndValue], 8
    mov byte [ebp + wPlayerSpinInPlaceAnimSoundID], 0xff
    mov esi, wFacingDirectionList
    call PlayerSpinInPlace
    mov byte [ebp + wPikachuSpawnState], 1
.restoreDefaultMusic:
    call PlayDefaultMusic
.done:
    call Func_151d
    jmp RestoreFacingDirectionAndYScreenPos
.dungeonWarpAnimation:
    mov bl, 50                                ; ld c, 50
    call DelayFrames
    call PlayerSpinWhileMovingDown
    mov byte [ebp + wPikachuSpawnState], 0
    jmp .done
.flyAnimation:
    pop esi                                   ; pop hl
    call LoadBirdSpriteGraphics
    mov al, SFX_FLY
    call PlaySound
    mov byte [ebp + wFlyAnimUsingCoordList], 0   ; is using coord list
    mov byte [ebp + wFlyAnimCounter], 12
    mov byte [ebp + wFlyAnimBirdSpriteImageIndex], 0x8 ; facing right
    mov edx, FlyAnimationEnterScreenCoords    ; ld de, ... (flat cursor)
    call DoFlyAnimation
    call LoadPlayerSpriteGraphics
    mov byte [ebp + wPikachuSpawnState], 1
    jmp .restoreDefaultMusic

section .data
FlyAnimationEnterScreenCoords:
; y, x pairs — Fly animation coords when the player is entering a map.
    db 0x05, 0x98
    db 0x0F, 0x90
    db 0x18, 0x88
    db 0x20, 0x80
    db 0x27, 0x78
    db 0x2D, 0x70
    db 0x32, 0x68
    db 0x36, 0x60
    db 0x39, 0x58
    db 0x3B, 0x50
    db 0x3C, 0x48
    db 0x3C, 0x40
section .text

; ---------------------------------------------------------------------------
; PlayerSpinWhileMovingDown
; ---------------------------------------------------------------------------
PlayerSpinWhileMovingDown:
    mov byte [ebp + wPlayerSpinWhileMovingUpOrDownAnimDeltaY], 0x10
    mov byte [ebp + wPlayerSpinWhileMovingUpOrDownAnimMaxY], 0x3c
    call GetPlayerTeleportAnimFrameDelay
    mov [ebp + wPlayerSpinWhileMovingUpOrDownAnimFrameDelay], al ; ld [hl], a
    jmp PlayerSpinWhileMovingUpOrDown

; ---------------------------------------------------------------------------
; _LeaveMapAnim — pret engine/overworld/player_animations.asm:_LeaveMapAnim
; ---------------------------------------------------------------------------
_LeaveMapAnim:
    call Func_1510
    call InitFacingDirectionList
    call IsPlayerStandingOnWarpPadOrHole
    mov al, bh                                ; ld a, b
    and al, al
    jz .playerNotStandingOnWarpPadOrHole
    dec al
    jnz LeaveMapThroughHoleAnim               ; jp nz
.spinWhileMovingUp:
    mov al, SFX_TELEPORT_EXIT_1
    call PlaySound
    mov byte [ebp + wPlayerSpinWhileMovingUpOrDownAnimDeltaY], -0x10 & 0xFF
    mov byte [ebp + wPlayerSpinWhileMovingUpOrDownAnimMaxY], 0xec
    call GetPlayerTeleportAnimFrameDelay
    mov [ebp + wPlayerSpinWhileMovingUpOrDownAnimFrameDelay], al
    call PlayerSpinWhileMovingUpOrDown
    call IsPlayerStandingOnWarpPadOrHole
    mov al, bh                                ; ld a, b
    dec al
    jz .playerStandingOnWarpPad
; if not standing on a warp pad, there is an extra delay
    mov bl, 10                                ; ld c, 10
    call DelayFrames
.playerStandingOnWarpPad:
    call GBFadeOutToWhite
    jmp RestoreFacingDirectionAndYScreenPos
.playerNotStandingOnWarpPadOrHole:
    mov al, 0x4
    call StopMusic
    mov al, [ebp + wStatusFlags6]
    test al, 1 << BIT_ESCAPE_WARP             ; bit BIT_ESCAPE_WARP, a
    jz .flyAnimation
; if going to the last used pokemon center
    mov byte [ebp + wPlayerSpinInPlaceAnimFrameDelay], 16
    mov byte [ebp + wPlayerSpinInPlaceAnimFrameDelayDelta], -1 & 0xFF
    mov byte [ebp + wPlayerSpinInPlaceAnimFrameDelayEndValue], 0
    mov byte [ebp + wPlayerSpinInPlaceAnimSoundID], SFX_TELEPORT_EXIT_2
    mov esi, wFacingDirectionList
    call PlayerSpinInPlace
    jmp .spinWhileMovingUp
.flyAnimation:
    call LoadBirdSpriteGraphics
    mov byte [ebp + wFlyAnimUsingCoordList], 0xff ; not using coord list (flap in place)
    mov byte [ebp + wFlyAnimCounter], 8
    mov byte [ebp + wFlyAnimBirdSpriteImageIndex], 0xc
    call DoFlyAnimation
    mov al, SFX_FLY
    call PlaySound
    mov byte [ebp + wFlyAnimUsingCoordList], 0    ; is using coord list
    mov byte [ebp + wFlyAnimCounter], 0xc
    mov byte [ebp + wFlyAnimBirdSpriteImageIndex], 0xc ; facing right
    mov edx, FlyAnimationScreenCoords1
    call DoFlyAnimation
    mov bl, 40                                ; ld c, 40
    call DelayFrames
    mov byte [ebp + wFlyAnimCounter], 11
    mov byte [ebp + wFlyAnimBirdSpriteImageIndex], 0x8 ; facing left
    mov edx, FlyAnimationScreenCoords2
    call DoFlyAnimation
    call GBFadeOutToWhite
    jmp RestoreFacingDirectionAndYScreenPos

section .data
FlyAnimationScreenCoords1:
; y, x pairs — first part of the Fly overworld animation.
    db 0x3C, 0x48
    db 0x3C, 0x50
    db 0x3B, 0x58
    db 0x3A, 0x60
    db 0x39, 0x68
    db 0x37, 0x70
    db 0x37, 0x78
    db 0x33, 0x80
    db 0x30, 0x88
    db 0x2D, 0x90
    db 0x2A, 0x98
    db 0x27, 0xA0
FlyAnimationScreenCoords2:
; y, x pairs — second part of the Fly overworld animation.
    db 0x1A, 0x90
    db 0x19, 0x80
    db 0x17, 0x70
    db 0x15, 0x60
    db 0x12, 0x50
    db 0x0F, 0x40
    db 0x0C, 0x30
    db 0x09, 0x20
    db 0x05, 0x10
    db 0x00, 0x00
    db 0xF0, 0x00
section .text

; ---------------------------------------------------------------------------
; LeaveMapThroughHoleAnim
; ---------------------------------------------------------------------------
LeaveMapThroughHoleAnim:
    mov byte [ebp + wUpdateSpritesEnabled], 0xff ; disable UpdateSprites
    ; shift upper half of player's sprite down 8px and hide lower half
    mov al, [ebp + wShadowOAMSprite00TileID]
    mov [ebp + wShadowOAMSprite02TileID], al
    mov al, [ebp + wShadowOAMSprite01TileID]
    mov [ebp + wShadowOAMSprite03TileID], al
    mov al, SCREEN_HEIGHT_PX + OAM_Y_OFS
    mov [ebp + wShadowOAMSprite00YCoord], al
    mov [ebp + wShadowOAMSprite01YCoord], al
    mov bl, 2                                 ; ld c, 2
    call DelayFrames
    ; hide upper half of player's sprite
    mov al, SCREEN_HEIGHT_PX + OAM_Y_OFS
    mov [ebp + wShadowOAMSprite02YCoord], al
    mov [ebp + wShadowOAMSprite03YCoord], al
    call GBFadeOutToWhite
    mov byte [ebp + wUpdateSpritesEnabled], 1 ; enable UpdateSprites
    jmp RestoreFacingDirectionAndYScreenPos

; ---------------------------------------------------------------------------
; DoFlyAnimation — pret engine/overworld/player_animations.asm:DoFlyAnimation
; EDX = flat ROM cursor into a screen-coord list (pret DE).
; ---------------------------------------------------------------------------
DoFlyAnimation:
    mov al, [ebp + wFlyAnimBirdSpriteImageIndex]
    xor al, 0x1                               ; make the bird flap its wings
    mov [ebp + wFlyAnimBirdSpriteImageIndex], al
    mov [ebp + wSpritePlayerStateData1ImageIndex], al
    call Delay3
    mov al, [ebp + wFlyAnimUsingCoordList]
    cmp al, 0xff
    je .skipCopyingCoords                     ; bird flapping in place
    mov al, [edx]                             ; ld a,[de] (y); flat cursor
    inc edx
    mov [ebp + wSpritePlayerStateData1YPixels], al ; ld [hli],a (y) + inc hl
    mov al, [edx]                             ; ld a,[de] (x)
    inc edx
    mov [ebp + wSpritePlayerStateData1XPixels], al ; ld [hl],a (x)
.skipCopyingCoords:
    mov al, [ebp + wFlyAnimCounter]
    dec al
    mov [ebp + wFlyAnimCounter], al
    jnz DoFlyAnimation
    ret

; ---------------------------------------------------------------------------
; LoadBirdSpriteGraphics
; ---------------------------------------------------------------------------
LoadBirdSpriteGraphics:
    mov edx, BirdSprite                       ; ld de, BirdSprite (flat src)
    mov bl, 0xc                               ; ld c, 0xc (count)
    mov esi, vNPCSprites                       ; ld hl, vNPCSprites (VRAM dest)
    call CopyVideoData
    mov edx, BirdSprite + 12 * TILE_SIZE       ; BirdSprite tile 12 (moving anim)
    mov bl, 12
    mov esi, vNPCSprites2
    jmp CopyVideoData

; ---------------------------------------------------------------------------
; InitFacingDirectionList
; Out: ESI (hl) = entry in wFacingDirectionList matching current facing.
; ---------------------------------------------------------------------------
InitFacingDirectionList:
    mov al, [ebp + wSpritePlayerStateData1ImageIndex]
    mov [ebp + wSavedPlayerFacingDirection], al
    mov al, [ebp + wSpritePlayerStateData1YPixels]
    mov [ebp + wSavedPlayerScreenY], al
    ; CopyData PlayerSpinningFacingOrder(flat ROM) -> wFacingDirectionList(WRAM):
    ; source is flat, so an inline flat->WRAM rep movsb replaces CopyData
    ; (map_sprites.asm:ShowTextStream precedent).
    push edi
    mov esi, PlayerSpinningFacingOrder        ; flat src
    lea edi, [ebp + wFacingDirectionList]     ; WRAM dst
    mov ecx, OBJ_SIZE
    rep movsb
    pop edi
    mov al, [ebp + wSpritePlayerStateData1ImageIndex]
    mov esi, wFacingDirectionList
; find the place in the list that matches the current facing direction
.loop:
    cmp al, [ebp + esi]                       ; cp [hl]
    inc esi                                    ; inc hl
    jne .loop
    dec esi                                    ; dec hl
    ret

section .data
PlayerSpinningFacingOrder:
; direction order the player's sprite faces when teleporting (spin effect).
    db SPRITE_FACING_DOWN, SPRITE_FACING_LEFT, SPRITE_FACING_UP, SPRITE_FACING_RIGHT
section .text

; ---------------------------------------------------------------------------
; SpinPlayerSprite — copy current list value into sprite data and rotate list.
; In: ESI (hl) = current list entry.
; ---------------------------------------------------------------------------
SpinPlayerSprite:
    mov al, [ebp + esi]                       ; ld a, [hl]
    mov [ebp + wSpritePlayerStateData1ImageIndex], al
    push esi
    ; CopyData wFacingDirectionList -> wFacingDirectionList-1 (WRAM->WRAM)
    mov esi, wFacingDirectionList
    mov edx, wFacingDirectionList - 1
    mov bx, OBJ_SIZE
    call CopyData
    mov al, [ebp + wFacingDirectionList - 1]
    mov [ebp + wFacingDirectionList + 3], al
    pop esi
    ret

; ---------------------------------------------------------------------------
; PlayerSpinInPlace
; ---------------------------------------------------------------------------
PlayerSpinInPlace:
    call SpinPlayerSprite
    mov al, [ebp + wPlayerSpinInPlaceAnimFrameDelay]
    mov bl, al                                ; ld c, a
    and al, 0x3
    jnz .skipPlayingSound
; when the last delay was a multiple of 4, play a sound if there is one
    mov al, [ebp + wPlayerSpinInPlaceAnimSoundID]
    cmp al, 0xff
    je .skipPlayingSound                       ; call nz, PlaySound
    call PlaySound
.skipPlayingSound:
    mov al, [ebp + wPlayerSpinInPlaceAnimFrameDelayDelta]
    add al, bl                                ; add c
    mov [ebp + wPlayerSpinInPlaceAnimFrameDelay], al
    mov bl, al                                ; ld c, a
    mov al, [ebp + wPlayerSpinInPlaceAnimFrameDelayEndValue]
    cmp al, bl                                ; cp c
    je .ret                                    ; ret z
    call DelayFrames                          ; c = delay
    jmp PlayerSpinInPlace
.ret:
    ret

; ---------------------------------------------------------------------------
; PlayerSpinWhileMovingUpOrDown
; ---------------------------------------------------------------------------
PlayerSpinWhileMovingUpOrDown:
    call SpinPlayerSprite
    mov al, [ebp + wPlayerSpinWhileMovingUpOrDownAnimDeltaY]
    mov bl, al                                ; ld c, a
    mov al, [ebp + wSpritePlayerStateData1YPixels]
    add al, bl                                ; add c
    mov [ebp + wSpritePlayerStateData1YPixels], al
    mov bl, al                                ; ld c, a
    mov al, [ebp + wPlayerSpinWhileMovingUpOrDownAnimMaxY]
    cmp al, bl                                ; cp c
    je .ret                                    ; ret z
    mov al, [ebp + wPlayerSpinWhileMovingUpOrDownAnimFrameDelay]
    mov bl, al                                ; ld c, a
    call DelayFrames
    jmp PlayerSpinWhileMovingUpOrDown
.ret:
    ret

; ---------------------------------------------------------------------------
; RestoreFacingDirectionAndYScreenPos
; ---------------------------------------------------------------------------
RestoreFacingDirectionAndYScreenPos:
    mov al, [ebp + wSavedPlayerScreenY]
    mov [ebp + wSpritePlayerStateData1YPixels], al
    mov al, [ebp + wSavedPlayerFacingDirection]
    mov [ebp + wSpritePlayerStateData1ImageIndex], al
    ret

; ---------------------------------------------------------------------------
; GetPlayerTeleportAnimFrameDelay — if SGB 2 frames, else 3.
; ; PROJ: wOnSGB reflects the SGB speed-up the Makefile TIMING mode also models;
; the frame count is faithful (SGB 2 / DMG 3) regardless of the PIT divisor.
; ---------------------------------------------------------------------------
GetPlayerTeleportAnimFrameDelay:
    mov al, [ebp + wOnSGB]
    xor al, 0x1
    inc al
    inc al
    ret

; ---------------------------------------------------------------------------
; IsPlayerStandingOnWarpPadOrHole — Out: BH (=b) and wStandingOnWarpPadOrHole.
; ; PROJ: pret `lda_coord 8, 9` reads the player's own STANDING tile; the port
; addresses it at W_TILEMAP + PLAYER_STANDING_ROW*SCREEN_TILES_W +
; PLAYER_STANDING_COL (same anchor as player_state.asm's standing-tile reads).
; WarpPadAndHoleData is a flat ROM table (ESI read flat, not [ebp+ESI]).
; ---------------------------------------------------------------------------
IsPlayerStandingOnWarpPadOrHole:
    mov bh, 0                                  ; ld b, 0
    mov esi, WarpPadAndHoleData                ; flat ROM table
    mov bl, [ebp + wCurMapTileset]             ; ld c, a  (c = BL)
.loop:
    mov al, [esi]                              ; ld a,[hli] (tileset id, flat)
    inc esi
    cmp al, 0xff
    je .done
    cmp al, bl                                 ; cp c
    jne .nextEntry
    ; standing tile (PROJ, see header)
    mov ah, [ebp + W_TILEMAP + PLAYER_STANDING_ROW * SCREEN_TILES_W + PLAYER_STANDING_COL]
    cmp ah, [esi]                              ; cp [hl] (entry tile id)
    je .foundMatch
.nextEntry:
    inc esi                                    ; skip tile id
    inc esi                                    ; skip value
    jmp .loop
.foundMatch:
    inc esi                                    ; -> value byte
    mov bh, [esi]                              ; ld b, [hl]
.done:
    mov al, bh                                 ; ld a, b
    mov [ebp + wStandingOnWarpPadOrHole], al
    ret

section .data
WarpPadAndHoleData:
; tileset id, tile id, value for [wStandingOnWarpPadOrHole]
    db FACILITY, 0x20, 1 ; warp pad
    db FACILITY, 0x11, 2 ; hole
    db CAVERN,   0x22, 2 ; hole
    db INTERIOR, 0x55, 1 ; warp pad
    db -1               ; end
section .text

; ---------------------------------------------------------------------------
; FishingAnim — pret engine/overworld/player_animations.asm:FishingAnim
; ---------------------------------------------------------------------------
FishingAnim:
    mov bl, 10                                ; ld c, 10
    call DelayFrames
    or byte [ebp + wMovementFlags], 1 << BIT_LEDGE_OR_FISHING ; set BIT_LEDGE_OR_FISHING,[hl]
    mov edx, player_sprite                     ; ld de, RedSprite (flat src)
    mov bl, 12                                 ; ld c, 12
    mov esi, vNPCSprites                        ; ld hl, vNPCSprites (VRAM dest)
    call CopyVideoData
    mov al, 0x4
    mov esi, RedFishingTiles                    ; ld hl, RedFishingTiles (flat table)
    call LoadAnimSpriteGfx                      ; UNPORTED
    ; FishingRodOAM[imageindex] (flat ROM) -> wShadowOAMSprite39 (WRAM): inline
    ; flat->WRAM copy replaces the flat-source CopyData.
    movzx ecx, byte [ebp + wSpritePlayerStateData1ImageIndex] ; c = image index
    push edi
    mov esi, FishingRodOAM
    add esi, ecx                               ; add hl, bc
    lea edi, [ebp + wShadowOAMSprite39]        ; WRAM dst
    mov ecx, OBJ_SIZE
    rep movsb
    pop edi
    mov bl, 100                                ; ld c, 100
    call DelayFrames
    mov al, [ebp + wRodResponse]
    and al, al
    mov esi, NoNibbleText                      ; ld hl, NoNibbleText
    jz .done
    cmp al, 0x2
    mov esi, NothingHereText
    je .done

; there was a bite — shake the player's sprite vertically
    mov bh, 10                                 ; ld b, 10
.loop:
    mov esi, wSpritePlayerStateData1YPixels
    call .ShakePlayerSprite
    mov esi, wShadowOAMSprite39
    call .ShakePlayerSprite
    call Delay3
    dec bh
    jnz .loop

; If the player is facing up, hide the fishing rod so it doesn't overlap with
; the exclamation bubble shown next.
    mov al, [ebp + wSpritePlayerStateData1ImageIndex]
    cmp al, SPRITE_FACING_UP
    jne .skipHidingFishingRod
    mov al, SCREEN_HEIGHT_PX + OAM_Y_OFS
    mov [ebp + wShadowOAMSprite39YCoord], al
.skipHidingFishingRod:
    mov byte [ebp + wEmotionBubbleSpriteIndex], 0        ; player's sprite
    mov byte [ebp + wEmotionBubbleSpriteIndex + 1], EXCLAMATION_BUBBLE
    call EmotionBubble                         ; pret: predef (predef-regs/banking elided)
; If the player is facing up, unhide the fishing rod.
    mov al, [ebp + wSpritePlayerStateData1ImageIndex]
    cmp al, SPRITE_FACING_UP
    jne .skipUnhidingFishingRod
    mov byte [ebp + wShadowOAMSprite39YCoord], 0x44
.skipUnhidingFishingRod:
    mov esi, ItsABiteText                      ; ld hl, ItsABiteText
.done:
    mov dword [text_msgbox], msgbox_dialog     ; overworld dialog projection
    call PrintText
    and byte [ebp + wMovementFlags], ~(1 << BIT_LEDGE_OR_FISHING) & 0xFF ; res BIT_LEDGE_OR_FISHING,[hl]
    call LoadFontTilePatterns
    ret

.ShakePlayerSprite:
    mov al, [ebp + esi]                        ; ld a, [hl]
    xor al, 0x1
    mov [ebp + esi], al                        ; ld [hl], a
    ret

; ---- fishing-result text wrappers (streams generated to player_anim_text.inc) ----
NoNibbleText:
    text_far _NoNibbleText
    text_end
NothingHereText:
    text_far _NothingHereText
    text_end
ItsABiteText:
    text_far _ItsABiteText
    text_end

section .data
FishingRodOAM:
; how the fishing rod is drawn (dbsprite x_tile,y_tile,x_pix,y_pix,tile,attr)
    dbsprite  9, 11,  4,  3, 0xfd, 0         ; down
    dbsprite  9,  8,  4,  4, 0xfd, 0         ; up
    dbsprite  8, 10,  0,  0, 0xfe, 0         ; left
    dbsprite 11, 10,  0,  0, 0xfe, OAM_XFLIP ; right

; fishing_gfx label,count,vtile: pret `dw label`->`dd` (flat), so entries are
; 8 bytes: dd ptr, db count, db bank, dw (vNPCSprites tile N) VRAM offset. The
; consumer LoadAnimSpriteGfx (UNPORTED) must match this flattened layout.
RedFishingTiles:
    dd RedFishingTilesFront
    db 2
    db 0
    dw vNPCSprites + 0x02 * TILE_SIZE
    dd RedFishingTilesBack
    db 2
    db 0
    dw vNPCSprites + 0x06 * TILE_SIZE
    dd RedFishingTilesSide
    db 2
    db 0
    dw vNPCSprites + 0x0a * TILE_SIZE
    dd RedFishingRodTiles
    db 3
    db 0
    dw vNPCSprites + 0xfd * TILE_SIZE

; --- embedded graphics (INTERIM: allowlisted; retire + extern when
;     gfx/sprites.asm / gfx/fishing.asm land) ---
BirdSprite:
    incbin "../gfx/sprites/bird.2bpp"
RedFishingTilesFront:
    incbin "../gfx/overworld/red_fish_front.2bpp"
RedFishingTilesBack:
    incbin "../gfx/overworld/red_fish_back.2bpp"
RedFishingTilesSide:
    incbin "../gfx/overworld/red_fish_side.2bpp"
RedFishingRodTiles:
    incbin "../gfx/overworld/fishing_rod.2bpp"

%include "assets/player_anim_text.inc"
