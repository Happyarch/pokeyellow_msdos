; pikachu_movement.asm — mirror of pret engine/pikachu/pikachu_movement.asm.
;
; Full implementation of Phase 2 Overworld Follower Pikachu Subsystem:
; - ApplyPikachuMovementData_, LoadPikachuMovementCommandData, ExecutePikachuMovementCommand
; - PikachuMovementDatabase (63 entries), PikaMovementFunc1Jumptable (24 handlers),
;   PikaMovementFunc2Jumptable (11 handlers)
; - Hopping shadow: GetCoordsForPikachuShadow, AnimatePikachuShadow, LoadPikachuShadowOAMData
; - VRAM loaders: LoadPikachuBallIconIntoVRAM, OverworldPikachuBallGFX, LoadPikachuSpriteIntoVRAM
; - Context checks and math: PikachuPewterPokecenterCheck, PikachuFanClubCheck,
;   PikachuBillsHouseCheck, Cosine_e, Sine_e, asm_fd908, GetSine, SineWave_3f
;
; Register map (CLAUDE.md): A→AL, HL→ESI, BC→BX (B=BH,C=BL), DE→DX (D=DH,E=DL);
; SM83 `swap a` = nibble swap = `ror al, 4`. GB memory = [ebp + SYM] (gb_memmap.inc).
;
; VRAM TILE CACHE: VRAM writes route through CopyVideoData / CopyVideoDataDouble /
; CopyVideoDataAlternate / CopyVideoDataDoubleAlternate which arm `g_tilecache_dirty`.

bits 32

%include "gb_memmap.inc"
%include "assets/map_dims.inc"   ; map-id / tileset-id constants (Tier-1 generated)
%include "assets/script_constants.inc"; shared constants (%define: emits no COFF symbol)
%include "gb_constants.inc"
%include "gb_macros.inc"

; ---------------------------------------------------------------------------
; VRAM & Map constants (pret constants/map_constants.asm, vram.asm)
; ---------------------------------------------------------------------------
vNPCSprites                     equ vChars0                     ; 0x8000

TILE_1BPP                       equ 8
TILE_2BPP                       equ 16


; wSpriteStateData offsets and helper aliases

; Pikachu WRAM variables
wd451                           equ 0xE21D   ; [WRAM-expansion shifted]

; ---------------------------------------------------------------------------
; Externs
; ---------------------------------------------------------------------------
extern DelayFrame                                       ; src/home/vblank.asm
extern Delay3                                           ; src/home/palettes.asm
extern GetPikachuMovementScriptByte                     ; src/home/pikachu.asm
extern CopyVideoDataAlternate                           ; src/home/copy.asm
extern CopyVideoDataDoubleAlternate                     ; src/home/copy.asm
extern EnablePikachuFollowingPlayer                     ; src/home/pikachu.asm
extern StarterPikachuEmotionCommand_turnawayfromplayer  ; src/engine/pikachu/pikachu_emotions.asm
extern LoadCurrentMapView                               ; src/home/overworld.asm
extern UpdateSprites                                    ; src/home/update_sprites.asm
extern PikachuSprite                                    ; src/engine/gfx/mon_icons.asm

; ---------------------------------------------------------------------------
; Globals
; ---------------------------------------------------------------------------
global ApplyPikachuMovementData_
global LoadPikachuMovementCommandData
global ExecutePikachuMovementCommand
global GetCoordsForPikachuShadow
global AnimatePikachuShadow
global PikachuMovementDatabase
global PikaMovementFunc1Jumptable
global PikaMovementFunc1_EndCommand
global PikaMovementFunc1_EndCommand_
global PikaMovementFunc1_LoadPikachuCurrentPosition
global PikaMovementFunc1_DelayFrames
global PikaMovementFunc1_WalkInCurrentFacingDirection
global PikaMovementFunc1_WalkInOppositeFacingDirection
global PikaMovementFunc1_StepTurningCounterclockwise
global PikaMovementFunc1_StepTurningClockwise
global PikaMovementFunc1_StepForwardLeft
global PikaMovementFunc1_StepForwardRight
global PikaMovementFunc1_StepBackwardLeft
global PikaMovementFunc1_StepBackwardRight
global PikaMovementFunc1_ApplyStepVector
global PikaMovementFunc1_GetNextFacing
global PikaMovementFunc1_MoveDown
global PikaMovementFunc1_MoveUp
global PikaMovementFunc1_MoveLeft
global PikaMovementFunc1_MoveRight
global PikaMovementFunc1_MoveDownLeft
global PikaMovementFunc1_MoveDownRight
global PikaMovementFunc1_MoveUpLeft
global PikaMovementFunc1_MoveUpRight
global PikaMovementFunc1_ApplyFacingAndMove
global PikaMovementFunc1_MoveDiagonally
global PikaMovementFunc1_LookDown
global PikaMovementFunc1_LookUp
global PikaMovementFunc1_LookLeft
global PikaMovementFunc1_LookRight
global PikaMovementFunc1_ApplyFacing
global UpdatePikachuPosition
global PikaMovementFunc2Jumptable
global PikaMovement_SetSpawnShadow
global PikaMovementFunc2_ResetFrameCounterAndFaceCurrent
global PikaMovementFunc2_nop
global PikaMovementFunc2_CopySpriteImageIdxDirectionToSpriteImageIdx
global PikaMovementFunc2_UpdateSpriteImageIdxWithFacing
global PikaMovementFunc2_UpdateSpriteImageIdxWithPreviousImageIdxDirection
global PikaMovementFunc2_UpdateSpriteImageIdx
global PikaMovementFunc2_UpdateJumpWithFacing
global PikaMovementFunc2_UpdateJumpWithPreviousImageIdxDirection
global PikaMovementFunc2_UpdateJump
global PikaMovementFunc2_CopyFacingToJump
global PikaMovementFunc2_TurnParameter
global PikaMovementFunc2_TurnClockwise
global PikaMovementFunc2_TurnCounterClockwise
global Data_fd731
global Data_fd731End
global PikaMovementFunc2_Timer
global PikaMovementFunc2_GetImageBaseOffset
global PikaMovementFunc2_GetSpriteImageIdxDirection
global GetPikachuFacing
global SetPikachuFacing
global CheckPikachuStepTimer1
global GetPikachuStepVectorMagnitude
global CheckPikachuStepTimer2
global PikaMovementFunc_Sine
global ApplyPikachuStepVector
global LoadPikachuShadowOAMData
global LoadPikachuShadowIntoVRAM
global LedgeHoppingShadowGFX_3F
global LedgeHoppingShadowGFX_3FEnd
global LoadPikachuBallIconIntoVRAM
global Func_fd851
global OverworldPikachuBallGFX
global LoadPikachuSpriteIntoVRAM
global PikachuPewterPokecenterCheck
global PikachuFanClubCheck
global PikachuBillsHouseCheck
global Pikachu_LoadCurrentMapViewUpdateSpritesAndDelay3
global Cosine_e
global Sine_e
global asm_fd908
global GetSine
global SineWave_3f

section .text

; ---------------------------------------------------------------------------
; ApplyPikachuMovementData_ — pret engine/pikachu/pikachu_movement.asm:1
; ---------------------------------------------------------------------------
ApplyPikachuMovementData_:
    mov [ebp + wPikachuMovementScriptBank], bh          ; ld a, b / ld [wPikachuMovementScriptBank], a
    mov [ebp + wPikachuMovementScriptAddress], si       ; ld a, l / ld [..], a / ld a, h / ld [..+1], a
    call .SwapSpriteStateData                           ; call .SwapSpriteStateData
.loop:
    call LoadPikachuMovementCommandData                 ; call LoadPikachuMovementCommandData
    jnc .done                                           ; jr nc, .done
    call ExecutePikachuMovementCommand                  ; call ExecutePikachuMovementCommand
    jmp .loop                                           ; jr .loop

.done:
    call .SwapSpriteStateData                           ; call .SwapSpriteStateData
    call DelayFrame                                     ; call DelayFrame
    ret

.SwapSpriteStateData:
    mov al, [ebp + wUpdateSpritesEnabled]               ; ld a, [wUpdateSpritesEnabled]
    push eax                                            ; push af
    mov byte [ebp + wUpdateSpritesEnabled], 0xFF        ; ld a, $ff / ld [wUpdateSpritesEnabled], a
    push esi                                            ; push hl
    push edx                                            ; push de
    push ecx                                            ; push bc

    mov esi, wSpritePlayerStateData1                    ; ld hl, wSpritePlayerStateData1
    mov edx, wSpritePikachuStateData1                   ; ld de, wSpritePikachuStateData1
    mov cl, 0x10                                        ; ld c, $10
    call .SwapBytes                                     ; call .SwapBytes

    mov esi, wSpritePlayerStateData2                    ; ld hl, wSpritePlayerStateData2
    mov edx, wSpritePikachuStateData2                   ; ld de, wSpritePikachuStateData2
    mov cl, 0x10                                        ; ld c, $10
    call .SwapBytes                                     ; call .SwapBytes

    pop ecx                                             ; pop bc
    pop edx                                             ; pop de
    pop esi                                             ; pop hl
    pop eax                                             ; pop af
    mov [ebp + wUpdateSpritesEnabled], al               ; ld [wUpdateSpritesEnabled], a
    ret

.SwapBytes:
    mov al, [ebp + esi]                                 ; ld b, [hl]
    mov ah, [ebp + edx]                                 ; ld a, [de]
    mov [ebp + esi], ah                                 ; ld [hli], a
    mov [ebp + edx], al                                 ; ld [de], a
    inc esi
    inc edx                                             ; inc de
    dec cl                                              ; dec c
    jnz .SwapBytes                                      ; jr nz, .SwapBytes
    ret

; ---------------------------------------------------------------------------
; LoadPikachuMovementCommandData — pret engine/pikachu/pikachu_movement.asm:57
; ---------------------------------------------------------------------------
LoadPikachuMovementCommandData:
    call GetPikachuMovementScriptByte                   ; call GetPikachuMovementScriptByte
    cmp al, 0x3F                                        ; cp $3f
    jne .not_end                                        ; ret z (with CF=0)
    clc
    ret
.not_end:
    movzx ecx, al                                       ; ld c, a / ld b, 0
    lea esi, [PikachuMovementDatabase + ecx * 4]        ; ld hl, PikachuMovementDatabase / add hl, bc x4
    lodsb                                               ; ld a, [hli]
    mov [ebp + wCurPikaMovementFunc1], al               ; ld [wCurPikaMovementFunc1], a
    lodsb                                               ; ld a, [hli]
    cmp al, 0x80                                        ; cp $80
    jne .no_param                                       ; jr nz, .no_param
    call GetPikachuMovementScriptByte                   ; call GetPikachuMovementScriptByte
.no_param:
    mov [ebp + wCurPikaMovementParam1], al              ; ld [wCurPikaMovementParam1], a
    lodsb                                               ; ld a, [hli]
    mov [ebp + wCurPikaMovementFunc2], al               ; ld [wCurPikaMovementFunc2], a
    lodsb                                               ; ld a, [hli]
    cmp al, 0x80                                        ; cp $80
    jne .no_param2                                      ; jr nz, .no_param2
    call GetPikachuMovementScriptByte                   ; call GetPikachuMovementScriptByte
.no_param2:
    mov [ebp + wCurPikaMovementParam2], al              ; ld [wCurPikaMovementParam2], a
    mov byte [ebp + wd451], 0                           ; xor a / ld [wd451], a
    stc                                                 ; scf
    ret

; ---------------------------------------------------------------------------
; ExecutePikachuMovementCommand — pret engine/pikachu/pikachu_movement.asm:89
; ---------------------------------------------------------------------------
ExecutePikachuMovementCommand:
    mov byte [ebp + wPikachuMovementFlags], 0           ; xor a / ld [wPikachuMovementFlags], a
    mov byte [ebp + wPikachuStepTimer], 0               ; ld [wPikachuStepTimer], a
    mov byte [ebp + wPikachuStepSubtimer], 0            ; ld [wPikachuStepSubtimer], a
    mov al, [ebp + wSpritePlayerStateData2GrassPriority]; ld a, [wSpritePlayerStateData2GrassPriority]
    push eax                                            ; push af
.loop:
    mov ebx, wSpritePlayerStateData1                    ; ld bc, wSpritePlayerStateData1
    movzx eax, byte [ebp + wCurPikaMovementFunc1]       ; ld a, [wCurPikaMovementFunc1]
    lea esi, [PikaMovementFunc1Jumptable]               ; ld hl, PikaMovementFunc1Jumptable
    call .JumpTable                                     ; call .JumpTable
    movzx eax, byte [ebp + wCurPikaMovementFunc2]       ; ld a, [wCurPikaMovementFunc2]
    lea esi, [PikaMovementFunc2Jumptable]               ; ld hl, PikaMovementFunc2Jumptable
    call .JumpTable                                     ; call .JumpTable
    call GetCoordsForPikachuShadow                      ; call GetCoordsForPikachuShadow
    call AnimatePikachuShadow                           ; call AnimatePikachuShadow
    call DelayFrame                                     ; call DelayFrame
    call DelayFrame                                     ; call DelayFrame
    test byte [ebp + wPikachuMovementFlags], 1 << 7     ; ld hl, wPikachuMovementFlags / bit 7, [hl]
    jz .loop                                            ; jr z, .loop
    pop eax                                             ; pop af
    mov [ebp + wSpritePlayerStateData2GrassPriority], al; ld [wSpritePlayerStateData2GrassPriority], a
    stc                                                 ; scf
    ret

.JumpTable:
    jmp [esi + eax * 4]

; ---------------------------------------------------------------------------
; GetCoordsForPikachuShadow — pret engine/pikachu/pikachu_movement.asm:126
; ---------------------------------------------------------------------------
GetCoordsForPikachuShadow:
    mov al, [ebp + wCurPikaMovementSpriteImageIdx]      ; ld a, [wCurPikaMovementSpriteImageIdx]
    mov [ebp + ebx + SPRITESTATEDATA1_IMAGEINDEX], al   ; ld [hl], a
    mov al, [ebp + wPikaSpriteY]                        ; ld a, [wPikaSpriteY]
    add al, [ebp + wPikachuMovementYOffset]             ; add d (wPikachuMovementYOffset)
    mov [ebp + ebx + SPRITESTATEDATA1_YPIXELS], al      ; ld [hl], a
    mov al, [ebp + wPikaSpriteX]                        ; ld a, [wPikaSpriteX]
    add al, [ebp + wPikachuMovementXOffset]             ; add d (wPikachuMovementXOffset)
    mov [ebp + ebx + SPRITESTATEDATA1_XPIXELS], al      ; ld [hl], a
    test byte [ebp + wPikachuMovementFlags], 1 << 6     ; bit 6, [hl]
    jz .done                                            ; ret z
    mov byte [ebp + ebx + (wSpriteStateData2 - wSpriteStateData1) + SPRITESTATEDATA2_GRASSPRIORITY], 0 ; ld [hl], 0
.done:
    ret

; ---------------------------------------------------------------------------
; AnimatePikachuShadow — pret engine/pikachu/pikachu_movement.asm:153
; ---------------------------------------------------------------------------
AnimatePikachuShadow:
    mov al, [ebp + wPikachuMovementFlags]               ; bit 6, [hl] (sample)
    and byte [ebp + wPikachuMovementFlags], ~(1 << 6)   ; res 6, [hl]
    and byte [ebp + wMovementFlags], ~(1 << BIT_LEDGE_OR_FISHING) ; res BIT_LEDGE_OR_FISHING, [hl]
    test al, 1 << 6                                     ; ret z if bit 6 was 0
    jz .done
    or byte [ebp + wMovementFlags], 1 << BIT_LEDGE_OR_FISHING ; set BIT_LEDGE_OR_FISHING, [hl]
    call LoadPikachuShadowOAMData                       ; call LoadPikachuShadowOAMData
.done:
    ret

; ---------------------------------------------------------------------------
; PikaMovementFunc1Jumptable — pret engine/pikachu/pikachu_movement.asm:238
; ---------------------------------------------------------------------------
PikaMovementFunc1Jumptable:
    dd PikaMovementFunc1_EndCommand_                    ; 00
    dd PikaMovementFunc1_LoadPikachuCurrentPosition      ; 01
    dd PikaMovementFunc1_DelayFrames                    ; 02
    dd PikaMovementFunc1_WalkInCurrentFacingDirection   ; 03
    dd PikaMovementFunc1_WalkInOppositeFacingDirection  ; 04
    dd PikaMovementFunc1_StepTurningCounterclockwise    ; 05
    dd PikaMovementFunc1_StepTurningClockwise           ; 06
    dd PikaMovementFunc1_StepForwardLeft                ; 07
    dd PikaMovementFunc1_StepForwardRight               ; 08
    dd PikaMovementFunc1_StepBackwardLeft               ; 09
    dd PikaMovementFunc1_StepBackwardRight              ; 0a
    dd PikaMovementFunc1_MoveDown                       ; 0b
    dd PikaMovementFunc1_MoveUp                         ; 0c
    dd PikaMovementFunc1_MoveLeft                       ; 0d
    dd PikaMovementFunc1_MoveRight                      ; 0e
    dd PikaMovementFunc1_MoveDownLeft                   ; 0f
    dd PikaMovementFunc1_MoveDownRight                  ; 10
    dd PikaMovementFunc1_MoveUpLeft                     ; 11
    dd PikaMovementFunc1_MoveUpRight                    ; 12
    dd PikaMovementFunc1_LookDown                       ; 13
    dd PikaMovementFunc1_LookUp                         ; 14
    dd PikaMovementFunc1_LookLeft                       ; 15
    dd PikaMovementFunc1_LookRight                      ; 16
    dd PikaMovementFunc1_EndCommand_                    ; 17

; ---------------------------------------------------------------------------
; PikaMovementFunc1 handlers — pret engine/pikachu/pikachu_movement.asm:264
; ---------------------------------------------------------------------------
PikaMovementFunc1_EndCommand:
    or byte [ebp + wPikachuMovementFlags], 1 << 7       ; ld a, [wPikachuMovementFlags] / set 7, a
    ret

PikaMovementFunc1_EndCommand_:
    call PikaMovementFunc1_EndCommand
    ret

PikaMovementFunc1_LoadPikachuCurrentPosition:
    mov al, [ebp + ebx + SPRITESTATEDATA1_YPIXELS]
    mov [ebp + wPikaSpriteY], al
    mov al, [ebp + ebx + SPRITESTATEDATA1_XPIXELS]
    mov [ebp + wPikaSpriteX], al
    mov byte [ebp + wPikachuMovementYOffset], 0
    mov byte [ebp + wPikachuMovementXOffset], 0
    call PikaMovementFunc1_EndCommand
    ret

PikaMovementFunc1_DelayFrames:
    call CheckPikachuStepTimer1
    jnz .not_expired
    call PikaMovementFunc1_EndCommand
.not_expired:
    ret

PikaMovementFunc1_WalkInCurrentFacingDirection:
    call GetPikachuFacing
    jmp PikaMovementFunc1_ApplyStepVector

PikaMovementFunc1_WalkInOppositeFacingDirection:
    call GetPikachuFacing
    xor al, 4                                           ; xor %100
    jmp PikaMovementFunc1_ApplyStepVector

PikaMovementFunc1_StepTurningCounterclockwise:
    call GetPikachuFacing
    lea esi, [.Data]
    call PikaMovementFunc1_GetNextFacing
    jmp PikaMovementFunc1_ApplyStepVector

.Data:
    db SPRITE_FACING_DOWN,  PIKASTEPDIR_RIGHT << 2
    db SPRITE_FACING_UP,    PIKASTEPDIR_LEFT << 2
    db SPRITE_FACING_LEFT,  PIKASTEPDIR_DOWN << 2
    db SPRITE_FACING_RIGHT, PIKASTEPDIR_UP << 2
    db 0xFF

PikaMovementFunc1_StepTurningClockwise:
    call GetPikachuFacing
    lea esi, [.Data]
    call PikaMovementFunc1_GetNextFacing
    jmp PikaMovementFunc1_ApplyStepVector

.Data:
    db SPRITE_FACING_DOWN,  PIKASTEPDIR_LEFT << 2
    db SPRITE_FACING_UP,    PIKASTEPDIR_RIGHT << 2
    db SPRITE_FACING_LEFT,  PIKASTEPDIR_UP << 2
    db SPRITE_FACING_RIGHT, PIKASTEPDIR_DOWN << 2
    db 0xFF

PikaMovementFunc1_StepForwardLeft:
    call GetPikachuFacing
    lea esi, [.Data]
    call PikaMovementFunc1_GetNextFacing
    jmp PikaMovementFunc1_ApplyStepVector

.Data:
    db SPRITE_FACING_DOWN,  PIKASTEPDIR_DOWN_RIGHT << 2
    db SPRITE_FACING_UP,    PIKASTEPDIR_UP_LEFT << 2
    db SPRITE_FACING_LEFT,  PIKASTEPDIR_DOWN_LEFT << 2
    db SPRITE_FACING_RIGHT, PIKASTEPDIR_UP_RIGHT << 2

PikaMovementFunc1_StepForwardRight:
    call GetPikachuFacing
    lea esi, [.Data]
    call PikaMovementFunc1_GetNextFacing
    jmp PikaMovementFunc1_ApplyStepVector

.Data:
    db SPRITE_FACING_DOWN,  PIKASTEPDIR_DOWN_LEFT << 2
    db SPRITE_FACING_UP,    PIKASTEPDIR_UP_RIGHT << 2
    db SPRITE_FACING_LEFT,  PIKASTEPDIR_UP_LEFT << 2
    db SPRITE_FACING_RIGHT, PIKASTEPDIR_DOWN_RIGHT << 2

PikaMovementFunc1_StepBackwardLeft:
    call GetPikachuFacing
    lea esi, [.Data]
    call PikaMovementFunc1_GetNextFacing
    jmp PikaMovementFunc1_ApplyStepVector

.Data:
    db SPRITE_FACING_DOWN,  PIKASTEPDIR_UP_RIGHT << 2
    db SPRITE_FACING_UP,    PIKASTEPDIR_DOWN_LEFT << 2
    db SPRITE_FACING_LEFT,  PIKASTEPDIR_DOWN_RIGHT << 2
    db SPRITE_FACING_RIGHT, PIKASTEPDIR_UP_LEFT << 2

PikaMovementFunc1_StepBackwardRight:
    call GetPikachuFacing
    lea esi, [.Data]
    call PikaMovementFunc1_GetNextFacing
    jmp PikaMovementFunc1_ApplyStepVector

.Data:
    db SPRITE_FACING_DOWN,  PIKASTEPDIR_UP_LEFT << 2
    db SPRITE_FACING_UP,    PIKASTEPDIR_DOWN_RIGHT << 2
    db SPRITE_FACING_LEFT,  PIKASTEPDIR_UP_RIGHT << 2
    db SPRITE_FACING_RIGHT, PIKASTEPDIR_DOWN_LEFT << 2

PikaMovementFunc1_ApplyStepVector:
    ror al, 2                                           ; rrca / rrca
    and al, 0x07                                        ; and $7
    mov dl, al                                          ; ld e, a
    call GetPikachuStepVectorMagnitude                  ; call GetPikachuStepVectorMagnitude
    mov dh, al                                          ; ld d, a
    call UpdatePikachuPosition                          ; call UpdatePikachuPosition
    call CheckPikachuStepTimer1                         ; call CheckPikachuStepTimer1
    jnz .not_done                                       ; ret nz
    call PikaMovementFunc1_EndCommand                   ; call PikaMovementFunc1_EndCommand
.not_done:
    ret

PikaMovementFunc1_GetNextFacing:
    push edx
    mov dl, al
.loop:
    lodsb
    cmp al, dl
    je .found
    inc esi
    cmp al, 0xFF
    jne .loop
    pop edx
    ret

.found:
    mov al, [esi]
    pop edx
    stc
    ret

PikaMovementFunc1_MoveDown:
    mov al, PIKASTEPDIR_DOWN
    jmp PikaMovementFunc1_ApplyFacingAndMove

PikaMovementFunc1_MoveUp:
    mov al, PIKASTEPDIR_UP
    jmp PikaMovementFunc1_ApplyFacingAndMove

PikaMovementFunc1_MoveLeft:
    mov al, PIKASTEPDIR_LEFT
    jmp PikaMovementFunc1_ApplyFacingAndMove

PikaMovementFunc1_MoveRight:
    mov al, PIKASTEPDIR_RIGHT
    jmp PikaMovementFunc1_ApplyFacingAndMove

PikaMovementFunc1_MoveDownLeft:
    mov dl, PIKASTEPDIR_DOWN_LEFT
    jmp PikaMovementFunc1_MoveDiagonally

PikaMovementFunc1_MoveDownRight:
    mov dl, PIKASTEPDIR_DOWN_RIGHT
    jmp PikaMovementFunc1_MoveDiagonally

PikaMovementFunc1_MoveUpLeft:
    mov dl, PIKASTEPDIR_UP_LEFT
    jmp PikaMovementFunc1_MoveDiagonally

PikaMovementFunc1_MoveUpRight:
    mov dl, PIKASTEPDIR_UP_RIGHT
    jmp PikaMovementFunc1_MoveDiagonally

PikaMovementFunc1_ApplyFacingAndMove:
    mov dl, al
    call SetPikachuFacing
PikaMovementFunc1_MoveDiagonally:
    call GetPikachuStepVectorMagnitude
    mov dh, al
    push edx
    call UpdatePikachuPosition
    pop edx
    call CheckPikachuStepTimer1
    jnz .not_done
    mov al, dl
    call ApplyPikachuStepVector
    call PikaMovementFunc1_EndCommand
.not_done:
    ret

PikaMovementFunc1_LookDown:
    mov al, PIKASTEPDIR_DOWN
    jmp PikaMovementFunc1_ApplyFacing

PikaMovementFunc1_LookUp:
    mov al, PIKASTEPDIR_UP
    jmp PikaMovementFunc1_ApplyFacing

PikaMovementFunc1_LookLeft:
    mov al, PIKASTEPDIR_LEFT
    jmp PikaMovementFunc1_ApplyFacing

PikaMovementFunc1_LookRight:
    mov al, PIKASTEPDIR_RIGHT
    jmp PikaMovementFunc1_ApplyFacing

PikaMovementFunc1_ApplyFacing:
    call SetPikachuFacing
    call PikaMovementFunc1_EndCommand
    ret

; ---------------------------------------------------------------------------
; UpdatePikachuPosition — pret engine/pikachu/pikachu_movement.asm:479
; ---------------------------------------------------------------------------
UpdatePikachuPosition:
    movzx eax, dl                                       ; direction index (0..7)
    mov al, dh                                          ; AL = magnitude
    jmp [.Jumptable + eax * 4]

.Jumptable:
    dd .Down                                            ; 0
    dd .Up                                              ; 1
    dd .Left                                            ; 2
    dd .Right                                           ; 3
    dd .DownLeft                                        ; 4
    dd .DownRight                                       ; 5
    dd .UpLeft                                          ; 6
    dd .UpRight                                         ; 7

.Down:
    mov dh, 0
    mov dl, al
    jmp .ApplyVector

.Up:
    mov dh, 0
    neg al
    mov dl, al
    jmp .ApplyVector

.Left:
    neg al
    mov dh, al
    mov dl, 0
    jmp .ApplyVector

.Right:
    mov dh, al
    mov dl, 0
    jmp .ApplyVector

.DownLeft:
    mov dl, al
    neg al
    mov dh, al
    jmp .ApplyVector

.DownRight:
    mov dl, al
    mov dh, al
    jmp .ApplyVector

.UpLeft:
    neg al
    mov dl, al
    mov dh, al
    jmp .ApplyVector

.UpRight:
    mov dh, al
    neg al
    mov dl, al
    jmp .ApplyVector

.ApplyVector:
    add [ebp + wPikaSpriteX], dh
    add [ebp + wPikaSpriteY], dl
    ret

; ---------------------------------------------------------------------------
; PikaMovementFunc2Jumptable — pret engine/pikachu/pikachu_movement.asm:561
; ---------------------------------------------------------------------------
PikaMovementFunc2Jumptable:
    dd PikaMovementFunc2_ResetFrameCounterAndFaceCurrent ; 0
    dd PikaMovementFunc2_UpdateSpriteImageIdxWithPreviousImageIdxDirection ; 1
    dd PikaMovementFunc2_UpdateSpriteImageIdxWithFacing  ; 2
    dd PikaMovementFunc2_TurnParameter                   ; 3
    dd PikaMovementFunc2_TurnClockwise                   ; 4
    dd PikaMovementFunc2_TurnCounterClockwise            ; 5
    dd PikaMovementFunc2_CopySpriteImageIdxDirectionToSpriteImageIdx ; 6
    dd PikaMovementFunc2_UpdateJumpWithPreviousImageIdxDirection ; 7
    dd PikaMovementFunc2_UpdateJumpWithFacing            ; 8
    dd PikaMovementFunc2_CopyFacingToJump                ; 9
    dd PikaMovementFunc2_nop                             ; 10

; ---------------------------------------------------------------------------
; PikaMovementFunc2 handlers — pret engine/pikachu/pikachu_movement.asm:574
; ---------------------------------------------------------------------------
PikaMovement_SetSpawnShadow:
    or byte [ebp + wPikachuMovementFlags], 1 << 6
    ret

PikaMovementFunc2_ResetFrameCounterAndFaceCurrent:
    mov byte [ebp + ebx + SPRITESTATEDATA1_INTRAANIMFRAMECOUNTER], 0
    mov byte [ebp + ebx + SPRITESTATEDATA1_ANIMFRAMECOUNTER], 0
    call PikaMovementFunc2_GetImageBaseOffset
    mov dh, al
    call GetPikachuFacing
    or al, dh
    mov [ebp + wCurPikaMovementSpriteImageIdx], al
    ret

PikaMovementFunc2_nop:
    ret

PikaMovementFunc2_CopySpriteImageIdxDirectionToSpriteImageIdx:
    call PikaMovementFunc2_GetImageBaseOffset
    mov dh, al
    call PikaMovementFunc2_GetSpriteImageIdxDirection
    or al, dh
    mov [ebp + wCurPikaMovementSpriteImageIdx], al
    ret

PikaMovementFunc2_UpdateSpriteImageIdxWithFacing:
    call PikaMovementFunc2_GetImageBaseOffset
    mov dh, al
    call GetPikachuFacing
    or al, dh
    mov dh, al
    jmp PikaMovementFunc2_UpdateSpriteImageIdx

PikaMovementFunc2_UpdateSpriteImageIdxWithPreviousImageIdxDirection:
    call PikaMovementFunc2_GetImageBaseOffset
    mov dh, al
    call PikaMovementFunc2_GetSpriteImageIdxDirection
    or al, dh
    mov dh, al
PikaMovementFunc2_UpdateSpriteImageIdx:
    call CheckPikachuStepTimer2
    jnz .skip
    inc byte [ebp + ebx + SPRITESTATEDATA1_ANIMFRAMECOUNTER]
.skip:
    mov al, [ebp + ebx + SPRITESTATEDATA1_ANIMFRAMECOUNTER]
    ror al, 2
    and al, 3
    or al, dh
    mov [ebp + wCurPikaMovementSpriteImageIdx], al
    ret

PikaMovementFunc2_UpdateJumpWithFacing:
    call GetPikachuFacing
    mov dh, al
    jmp PikaMovementFunc2_UpdateJump

PikaMovementFunc2_UpdateJumpWithPreviousImageIdxDirection:
    call PikaMovementFunc2_GetSpriteImageIdxDirection
    mov dh, al
PikaMovementFunc2_UpdateJump:
    call PikaMovementFunc2_GetImageBaseOffset
    or al, dh
    mov dh, al
    call PikaMovementFunc2_Timer
    or al, dh
    mov [ebp + wCurPikaMovementSpriteImageIdx], al
    call PikaMovementFunc_Sine
    mov [ebp + wPikachuMovementYOffset], al
    test al, al
    jz .done
    call PikaMovement_SetSpawnShadow
.done:
    ret

PikaMovementFunc2_CopyFacingToJump:
    call GetPikachuFacing
    mov dh, al
    call PikaMovementFunc2_GetImageBaseOffset
    or al, dh
    mov [ebp + wCurPikaMovementSpriteImageIdx], al
    call PikaMovementFunc_Sine
    mov [ebp + wPikachuMovementYOffset], al
    ret

PikaMovementFunc2_TurnParameter:
    test byte [ebp + wCurPikaMovementParam2], 0x40
    jnz PikaMovementFunc2_TurnClockwise
    jmp PikaMovementFunc2_TurnCounterClockwise

PikaMovementFunc2_TurnClockwise:
    call PikaMovementFunc2_GetSpriteImageIdxDirection
    mov dh, al
    call CheckPikachuStepTimer2
    jnz .skip
    lea esi, [Data_fd731]
.loop:
    lodsb
    cmp al, dh
    jne .loop
    mov dh, [esi]
.skip:
    call PikaMovementFunc2_GetImageBaseOffset
    or al, dh
    mov [ebp + wCurPikaMovementSpriteImageIdx], al
    ret

PikaMovementFunc2_TurnCounterClockwise:
    call PikaMovementFunc2_GetSpriteImageIdxDirection
    mov dh, al
    call CheckPikachuStepTimer2
    jnz .skip
    lea esi, [Data_fd731End - 1]
.loop:
    mov al, [esi]
    dec esi
    cmp al, dh
    jne .loop
    mov dh, [esi]
.skip:
    call PikaMovementFunc2_GetImageBaseOffset
    or al, dh
    mov [ebp + wCurPikaMovementSpriteImageIdx], al
    ret

Data_fd731:
    db SPRITE_FACING_DOWN
    db SPRITE_FACING_LEFT
    db SPRITE_FACING_UP
    db SPRITE_FACING_RIGHT
    db SPRITE_FACING_DOWN
Data_fd731End:

PikaMovementFunc2_Timer:
    mov al, [ebp + ebx + SPRITESTATEDATA1_INTRAANIMFRAMECOUNTER]
    inc al
    and al, 0x03
    mov [ebp + ebx + SPRITESTATEDATA1_INTRAANIMFRAMECOUNTER], al
    jnz .load
    inc byte [ebp + ebx + SPRITESTATEDATA1_ANIMFRAMECOUNTER]
    and byte [ebp + ebx + SPRITESTATEDATA1_ANIMFRAMECOUNTER], 0x03
.load:
    mov al, [ebp + ebx + SPRITESTATEDATA1_ANIMFRAMECOUNTER]
    ret

PikaMovementFunc2_GetImageBaseOffset:
    mov al, [ebp + ebx + (wSpriteStateData2 - wSpriteStateData1) + SPRITESTATEDATA2_IMAGEBASEOFFSET]
    dec al
    ror al, 4
    ret

PikaMovementFunc2_GetSpriteImageIdxDirection:
    mov al, [ebp + ebx + SPRITESTATEDATA1_IMAGEINDEX]
    and al, 0x0C
    ret

GetPikachuFacing:
    mov al, [ebp + ebx + SPRITESTATEDATA1_FACINGDIRECTION]
    and al, 0x0C
    ret

SetPikachuFacing:
    shl al, 2
    and al, 0x0C
    mov [ebp + ebx + SPRITESTATEDATA1_FACINGDIRECTION], al
    ret

CheckPikachuStepTimer1:
    inc byte [ebp + wPikachuStepTimer]
    mov al, [ebp + wCurPikaMovementParam1]
    and al, 0x1F
    inc al
    cmp al, [ebp + wPikachuStepTimer]
    jne .not_zero
    mov byte [ebp + wPikachuStepTimer], 0
.not_zero:
    ret

GetPikachuStepVectorMagnitude:
    mov al, [ebp + wCurPikaMovementParam1]
    shr al, 5
    and al, 0x03
    inc al
    ret

CheckPikachuStepTimer2:
    inc byte [ebp + wPikachuStepSubtimer]
    mov al, [ebp + wCurPikaMovementParam2]
    and al, 0x0F
    inc al
    cmp al, [ebp + wPikachuStepSubtimer]
    jne .not_zero
    mov byte [ebp + wPikachuStepSubtimer], 0
.not_zero:
    ret

PikaMovementFunc_Sine:
    call .GetArgument
    mov al, [ebp + wPikachuStepSubtimer]
    add al, dl
    mov [ebp + wPikachuStepSubtimer], al
    add al, 0x20
    mov dl, al
    push esi
    push ebx
    call Sine_e
    pop ebx
    pop esi
    ret

.GetArgument:
    mov al, [ebp + wCurPikaMovementParam2]
    and al, 0x0F
    inc al
    mov dh, al
    mov al, [ebp + wCurPikaMovementParam2]
    ror al, 4
    and al, 0x07
    mov cl, al
    mov al, 1
    test cl, cl
    jz .okay
.loop:
    add al, al
    dec cl
    jnz .loop
.okay:
    mov dl, al
    ret

ApplyPikachuStepVector:
    movzx eax, al
    mov dh, [.StepVectors + eax * 2]
    mov dl, [.StepVectors + eax * 2 + 1]
    add [ebp + ebx + (wSpriteStateData2 - wSpriteStateData1) + SPRITESTATEDATA2_MAPY], dl
    add [ebp + ebx + (wSpriteStateData2 - wSpriteStateData1) + SPRITESTATEDATA2_MAPX], dh
    ret

.StepVectors:
    db  0,  1
    db  0, -1
    db -1,  0
    db  1,  0
    db -1,  1
    db  1,  1
    db -1, -1
    db  1, -1

; ---------------------------------------------------------------------------
; LoadPikachuShadowOAMData — pret engine/pikachu/pikachu_movement.asm:865
; ---------------------------------------------------------------------------
LoadPikachuShadowOAMData:
    push ebx
    push edx
    push esi

    mov ebx, wShadowOAM + 36 * 4
    mov dh, [ebp + wPikaSpriteY]
    mov dl, [ebp + wPikaSpriteX]
    lea esi, [.OAMData]
    call .LoadOAMData

    pop esi
    pop edx
    pop ebx
    ret

.OAMData:
    db 2
    db 0x0C, 0x00, 0xFF, 0
    db 0x0C, 0x08, 0xFF, OAM_XFLIP

.LoadOAMData:
    add dh, 0x10
    add dl, 0x08
    lodsb
    mov cl, al
.loop:
    lodsb
    add al, dh
    mov [ebp + ebx], al
    inc ebx
    lodsb
    add al, dl
    mov [ebp + ebx], al
    inc ebx
    lodsb
    mov [ebp + ebx], al
    inc ebx
    lodsb
    mov [ebp + ebx], al
    inc ebx
    dec cl
    jnz .loop
    ret

; ---------------------------------------------------------------------------
; LoadPikachuShadowIntoVRAM — pret engine/pikachu/pikachu_movement.asm:917
; ---------------------------------------------------------------------------
LoadPikachuShadowIntoVRAM:
    mov esi, vNPCSprites2 + 0x7F * TILE_2BPP
    lea edx, [LedgeHoppingShadowGFX_3F]
    mov bh, 0
    mov bl, (LedgeHoppingShadowGFX_3FEnd - LedgeHoppingShadowGFX_3F) / TILE_1BPP
    jmp CopyVideoDataDoubleAlternate

; ---------------------------------------------------------------------------
; LoadPikachuBallIconIntoVRAM — pret engine/pikachu/pikachu_movement.asm:927
; ---------------------------------------------------------------------------
LoadPikachuBallIconIntoVRAM:
    mov esi, vNPCSprites2 + 0x7E * TILE_2BPP
    lea edx, [OverworldPikachuBallGFX]
    mov bh, 0
    mov bl, 1
    jmp CopyVideoDataDoubleAlternate

; ---------------------------------------------------------------------------
; Func_fd851 — pret engine/pikachu/pikachu_movement.asm:933
; ---------------------------------------------------------------------------
Func_fd851:
    mov esi, vNPCSprites + 0x0C * TILE_2BPP
    mov cl, 3
.loop:
    push ecx
    push esi
    lea edx, [OverworldPikachuBallGFX]
    mov bh, 0
    mov bl, 4
    call CopyVideoDataAlternate
    pop esi
    add esi, 4 * TILE_2BPP
    pop ecx
    dec cl
    jnz .loop
    ret

; ---------------------------------------------------------------------------
; LoadPikachuSpriteIntoVRAM — pret engine/pikachu/pikachu_movement.asm:953
; ---------------------------------------------------------------------------
LoadPikachuSpriteIntoVRAM:
    lea edx, [PikachuSprite]
    mov bh, 0
    mov bl, 12
    mov esi, vNPCSprites + 0x0C * TILE_2BPP
    push ebx
    call CopyVideoDataAlternate
    lea edx, [PikachuSprite + 0x0C * TILE_2BPP]
    mov esi, vNPCSprites2 + 0x0C * TILE_2BPP
    mov al, [ebp + hPikachuSpriteVRAMOffset]
    test al, al
    jz .load
    lea edx, [PikachuSprite + 0x0C * TILE_2BPP]
    mov esi, vNPCSprites2 + 0x4C * TILE_2BPP
.load:
    pop ebx
    call CopyVideoDataAlternate
    call LoadPikachuShadowIntoVRAM
    call LoadPikachuBallIconIntoVRAM
    ret

; ---------------------------------------------------------------------------
; PikachuPewterPokecenterCheck — pret engine/pikachu/pikachu_movement.asm:973
; ---------------------------------------------------------------------------
PikachuPewterPokecenterCheck:
    cmp byte [ebp + wCurMap], PEWTER_POKECENTER
    jne .done
    call EnablePikachuFollowingPlayer
    call StarterPikachuEmotionCommand_turnawayfromplayer
.done:
    ret

; ---------------------------------------------------------------------------
; PikachuFanClubCheck — pret engine/pikachu/pikachu_movement.asm:981
; ---------------------------------------------------------------------------
PikachuFanClubCheck:
    cmp byte [ebp + wCurMap], POKEMON_FAN_CLUB
    jne .done
    call EnablePikachuFollowingPlayer
    call StarterPikachuEmotionCommand_turnawayfromplayer
.done:
    ret

; ---------------------------------------------------------------------------
; PikachuBillsHouseCheck — pret engine/pikachu/pikachu_movement.asm:989
; ---------------------------------------------------------------------------
PikachuBillsHouseCheck:
    cmp byte [ebp + wCurMap], BILLS_HOUSE
    jne .done
    call EnablePikachuFollowingPlayer
.done:
    ret

; ---------------------------------------------------------------------------
; Pikachu_LoadCurrentMapViewUpdateSpritesAndDelay3 — pret engine/pikachu/pikachu_movement.asm:996
; ---------------------------------------------------------------------------
Pikachu_LoadCurrentMapViewUpdateSpritesAndDelay3:
    call LoadCurrentMapView
    call UpdateSprites
    call Delay3
    ret

; ---------------------------------------------------------------------------
; Cosine_e & Sine_e & GetSine — pret engine/pikachu/pikachu_movement.asm:1002
; ---------------------------------------------------------------------------
Cosine_e:
    mov al, dl
    add al, 0x10
    jmp asm_fd908

Sine_e:
    mov al, dl
asm_fd908:
    and al, 0x3F
    cmp al, 0x20
    jae .asm_fd913
    call GetSine
    mov al, ah
    ret

.asm_fd913:
    and al, 0x1F
    call GetSine
    mov al, ah
    neg al
    ret

GetSine:
    movzx ecx, al
    movzx eax, word [SineWave_3f + ecx * 2]
    movzx edx, dh
    imul eax, edx
    shr eax, 8
    mov ah, al
    ret

; ---------------------------------------------------------------------------
; Embedded Data Tables
; ---------------------------------------------------------------------------
section .data

PikachuMovementDatabase:
    db 0x01, 1 - 1, 0x00, 1 - 1                         ; 0x00 start

    db 0x03, 0x80, 0x01, 1 - 1                          ; 0x01
    db 0x04, 0x80, 0x01, 1 - 1                          ; 0x02
    db 0x05, 0x80, 0x01, 1 - 1                          ; 0x03
    db 0x06, 0x80, 0x01, 1 - 1                          ; 0x04
    db 0x07, 0x80, 0x01, 1 - 1                          ; 0x05
    db 0x08, 0x80, 0x01, 1 - 1                          ; 0x06
    db 0x09, 0x80, 0x01, 1 - 1                          ; 0x07
    db 0x0A, 0x80, 0x01, 1 - 1                          ; 0x08

    db 0x03, 0x80, 0x06, 1 - 1                          ; 0x09
    db 0x04, 0x80, 0x06, 1 - 1                          ; 0x0A
    db 0x05, 0x80, 0x06, 1 - 1                          ; 0x0B
    db 0x06, 0x80, 0x06, 1 - 1                          ; 0x0C
    db 0x07, 0x80, 0x06, 1 - 1                          ; 0x0D
    db 0x08, 0x80, 0x06, 1 - 1                          ; 0x0E
    db 0x09, 0x80, 0x06, 1 - 1                          ; 0x0F
    db 0x0A, 0x80, 0x06, 1 - 1                          ; 0x10

    db 0x03, 0x80, 0x03, 0x80                           ; 0x11
    db 0x04, 0x80, 0x03, 0x80                           ; 0x12
    db 0x05, 0x80, 0x03, 0x80                           ; 0x13
    db 0x06, 0x80, 0x03, 0x80                           ; 0x14
    db 0x07, 0x80, 0x03, 0x80                           ; 0x15
    db 0x08, 0x80, 0x03, 0x80                           ; 0x16
    db 0x09, 0x80, 0x03, 0x80                           ; 0x17
    db 0x0A, 0x80, 0x03, 0x80                           ; 0x18

    db 0x03, 0x80, 0x07, 0x80                           ; 0x19
    db 0x04, 0x80, 0x07, 0x80                           ; 0x1A
    db 0x05, 0x80, 0x07, 0x80                           ; 0x1B
    db 0x06, 0x80, 0x07, 0x80                           ; 0x1C

    db 0x0B, (1 << 5) | (8 - 1), 0x02, 1 - 1            ; 0x1D step down
    db 0x0C, (1 << 5) | (8 - 1), 0x02, 1 - 1            ; 0x1E step up
    db 0x0D, (1 << 5) | (8 - 1), 0x02, 1 - 1            ; 0x1F step left
    db 0x0E, (1 << 5) | (8 - 1), 0x02, 1 - 1            ; 0x20 step right
    db 0x0F, (1 << 5) | (8 - 1), 0x02, 1 - 1            ; 0x21 step down left
    db 0x10, (1 << 5) | (8 - 1), 0x02, 1 - 1            ; 0x22 step down right
    db 0x11, (1 << 5) | (8 - 1), 0x02, 1 - 1            ; 0x23 step up left
    db 0x12, (1 << 5) | (8 - 1), 0x02, 1 - 1            ; 0x24 step up right

    db 0x0B, 16 - 1, 0x02, 1 - 1                        ; 0x25 slide down
    db 0x0C, 16 - 1, 0x02, 1 - 1                        ; 0x26 slide up
    db 0x0D, 16 - 1, 0x02, 1 - 1                        ; 0x27 slide left
    db 0x0E, 16 - 1, 0x02, 1 - 1                        ; 0x28 slide right
    db 0x0F, 16 - 1, 0x02, 1 - 1                        ; 0x29 slide down left
    db 0x10, 16 - 1, 0x02, 1 - 1                        ; 0x2A slide down right
    db 0x11, 16 - 1, 0x02, 1 - 1                        ; 0x2B slide up left
    db 0x12, 16 - 1, 0x02, 1 - 1                        ; 0x2C slide up right

    db 0x0B, 16 - 1, 0x08, (1 << 4) | (8 - 1)           ; 0x2D hop down
    db 0x0C, 16 - 1, 0x08, (1 << 4) | (8 - 1)           ; 0x2E hop up
    db 0x0D, 16 - 1, 0x08, (1 << 4) | (8 - 1)           ; 0x2F hop left
    db 0x0E, 16 - 1, 0x08, (1 << 4) | (8 - 1)           ; 0x30 hop right
    db 0x0F, 16 - 1, 0x08, (1 << 4) | (8 - 1)           ; 0x31 hop down left
    db 0x10, 16 - 1, 0x08, (1 << 4) | (8 - 1)           ; 0x32 hop down right
    db 0x11, 16 - 1, 0x08, (1 << 4) | (8 - 1)           ; 0x33 hop up left
    db 0x12, 16 - 1, 0x08, (1 << 4) | (8 - 1)           ; 0x34 hop up right

    db 0x13, 16 - 1, 0x06, 1 - 1                        ; 0x35 look down
    db 0x14, 16 - 1, 0x06, 1 - 1                        ; 0x36 look up
    db 0x15, 16 - 1, 0x06, 1 - 1                        ; 0x37 look left
    db 0x16, 16 - 1, 0x06, 1 - 1                        ; 0x38 look right

    db 0x02, 0x80, 0x04, 1 - 1                          ; 0x39
    db 0x02, 0x80, 0x05, 1 - 1                          ; 0x3A
    db 0x02, 0x80, 0x03, 0x80                           ; 0x3B
    db 0x02, 0x80, 0x07, 0x80                           ; 0x3C
    db 0x02, 0x80, 0x09, 0x80                           ; 0x3D
    db 0x02, 0x80, 0x06, 1 - 1                          ; 0x3E

LedgeHoppingShadowGFX_3F:
    incbin "../gfx/overworld/shadow.1bpp"
LedgeHoppingShadowGFX_3FEnd:

OverworldPikachuBallGFX:
    incbin "../gfx/overworld/pikachu_ball.2bpp"

SineWave_3f:
    dw 0x0000, 0x0019, 0x0032, 0x004a, 0x0062, 0x0079, 0x008e, 0x00a2
    dw 0x00b5, 0x00c6, 0x00d5, 0x00e2, 0x00ed, 0x00f5, 0x00fb, 0x00ff
    dw 0x0100, 0x00ff, 0x00fb, 0x00f5, 0x00ed, 0x00e2, 0x00d5, 0x00c6
    dw 0x00b5, 0x00a2, 0x008e, 0x0079, 0x0062, 0x004a, 0x0032, 0x0019

