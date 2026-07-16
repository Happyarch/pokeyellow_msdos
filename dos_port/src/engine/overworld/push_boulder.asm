; push_boulder.asm — Strength boulder pushing (OW-4.2).
;
; Intended repo path: dos_port/src/engine/overworld/push_boulder.asm
; pret source: engine/overworld/push_boulder.asm
;
; TryPushingBoulder: if Strength is active and no dust animation is playing, find
; the sprite in front of the player; if that sprite is a boulder (movement byte 2
; == BOULDER_MOVEMENT_BYTE_2) and the player has tried to push it twice while
; holding the control pad, move the boulder one step in the facing direction
; (unless CheckForCollisionWhenPushingBoulder reports a collision), play
; SFX_PUSH_BOULDER, and arm the dust animation. DoBoulderDustAnimation runs the
; dust animation and finishes the push. ResetBoulderPushFlags clears the two
; transient wMiscFlags bits.
;
; Register map (SM83 -> x86): A->AL, B->BH, C->BL, HL->ESI, EDI = movement-data
; pointer. GB memory is [ebp+offset]; GetSpriteMovementByte2Pointer returns a
; FLAT esi (write/read [esi], not [ebp+esi]) and MoveSprite takes a FLAT EDI.
;
; Sprite-selector convention: pret threads the sprite SLOT number through
; hSpriteIndex; the port's GetSpriteMovementByte2Pointer / MoveSprite instead
; read H_CURRENT_SPRITE_OFFSET = slot<<4. This file keeps H_SPRITE_INDEX (=pret
; hSpriteIndex, a slot number) purely as the interface to IsSpriteInFrontOfPlayer
; (unported — see extern) and derives H_CURRENT_SPRITE_OFFSET from it once for
; the downstream port sprite calls. H_CURRENT_SPRITE_OFFSET is set before the
; CheckForCollisionWhenPushingBoulder predef and reused by MoveSprite: none of
; that predef's callees (GetTileTwoStepsInFrontOfPlayer / IsTilePassable /
; CheckForTilePairCollisions2 / CheckForBoulderCollisionWithSprites) writes
; H_CURRENT_SPRITE_OFFSET, mirroring pret's reliance on hSpriteIndex surviving
; the predef.
;
; Build (check): nasm -f coff -I include/ -I . -o /dev/null \
;                     src/engine/overworld/push_boulder.asm
; ---------------------------------------------------------------------------

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_macros.inc"
%include "m8_2_pending_symbols.inc"        ; hJoyHeld, PAD_CTRL_PAD
%include "assets/audio_constants.inc"       ; SFX_PUSH_BOULDER, SFX_CUT

; --- symbols not yet in the shared headers (pret constants/*.asm, sym-verified) ---
%ifndef BIT_STRENGTH_ACTIVE
BIT_STRENGTH_ACTIVE     equ 0     ; wStatusFlags1 bit (constants/ram_constants.asm)
%endif
%ifndef BIT_BOULDER_DUST
BIT_BOULDER_DUST        equ 1     ; wMiscFlags bit (constants/ram_constants.asm)
%endif
%ifndef BIT_TRIED_PUSH_BOULDER
BIT_TRIED_PUSH_BOULDER  equ 6     ; wMiscFlags bit (constants/ram_constants.asm)
%endif
%ifndef BIT_PUSHED_BOULDER
BIT_PUSHED_BOULDER      equ 7     ; wMiscFlags bit (constants/ram_constants.asm)
%endif
%ifndef BOULDER_MOVEMENT_BYTE_2
BOULDER_MOVEMENT_BYTE_2 equ 0x10  ; constants/map_object_constants.asm
%endif
%ifndef H_SPRITE_INDEX
H_SPRITE_INDEX          equ 0xFF8C ; hSpriteIndex — sprite SLOT number; golden 00:ff8c
%endif
%ifndef wSpritePlayerStateData1MovementStatus
wSpritePlayerStateData1MovementStatus equ 0xC101 ; wSpriteStateData1+1; golden 00:c101
%endif
%ifndef wSpritePlayerStateData1FacingDirection
wSpritePlayerStateData1FacingDirection equ 0xC109 ; golden 00:c109 (= W_SPRITE_PLAYER_FACING_DIR)
%endif
%ifndef wTileInFrontOfBoulderAndBoulderCollisionResult
wTileInFrontOfBoulderAndBoulderCollisionResult equ 0xD71B ; golden 00:d71b
%endif

global TryPushingBoulder
global DoBoulderDustAnimation
global ResetBoulderPushFlags
global PushBoulderUpMovementData
global PushBoulderDownMovementData
global PushBoulderLeftMovementData
global PushBoulderRightMovementData

extern IsSpriteInFrontOfPlayer      ; src/engine/overworld/overworld.asm — sets H_SPRITE_INDEX to
                                    ; the slot in front of the player (ported, overworld-events
                                    ; Stage 4). NOTE the port's bespoke IsNPCAtTargetBlock is a
                                    ; SEPARATE realization of pret's sprite scan for collision and
                                    ; is NOT a drop-in here (different ABI) — see the STRUCTURAL
                                    ; SPLIT note on IsSpriteInFrontOfPlayer.
extern GetSpriteMovementByte2Pointer ; pathfinding.asm (reads H_CURRENT_SPRITE_OFFSET; ret flat ESI)
extern MoveSprite                   ; pathfinding.asm (In: EDI = flat movement-data ptr)
extern CheckForCollisionWhenPushingBoulder ; player_state.asm (pret predef; banking elided)
extern PlaySound                    ; home/audio.asm
extern DiscardButtonPresses         ; src/input/joypad.asm (returns AL = 0). RELOCATED from its
                                    ; pret home engine/joypad.asm, which is DEAD/unlisted — see
                                    ; that routine's header for why.
extern AnimateBoulderDust           ; src/engine/overworld/dust_smoke.asm — pret callfar target

section .text

; ---------------------------------------------------------------------------
; TryPushingBoulder — pret engine/overworld/push_boulder.asm:TryPushingBoulder
; ---------------------------------------------------------------------------
TryPushingBoulder:
    mov al, [ebp + W_STATUS_FLAGS_1]
    test al, (1 << BIT_STRENGTH_ACTIVE)
    jz .ret                                    ; ret z: Strength not active
    mov al, [ebp + wMiscFlags]
    test al, (1 << BIT_BOULDER_DUST)
    jnz .ret                                   ; ret nz: dust animation already running
    xor al, al
    mov [ebp + H_SPRITE_INDEX], al             ; xor a; ldh [hSpriteIndex],a
    call IsSpriteInFrontOfPlayer               ; sets H_SPRITE_INDEX = sprite slot in front
    mov al, [ebp + H_SPRITE_INDEX]
    mov [ebp + wBoulderSpriteIndex], al
    and al, al
    jz ResetBoulderPushFlags                   ; jp z: no sprite in front
    shl al, 4                                  ; slot<<4 (pret: swap a)
    mov [ebp + H_CURRENT_SPRITE_OFFSET], al    ; port sprite-selector for the calls below
    movzx esi, al                              ; e = slot<<4 (d = 0)
    add esi, wSpritePlayerStateData1MovementStatus
    and byte [ebp + esi], ~(1 << BIT_FACE_PLAYER)  ; res BIT_FACE_PLAYER, [hl]
    call GetSpriteMovementByte2Pointer         ; ESI = flat ptr to movement byte 2
    mov al, [esi]                              ; ld a,[hl] (flat read)
    cmp al, BOULDER_MOVEMENT_BYTE_2
    jne ResetBoulderPushFlags                  ; not a boulder
; the player must try pushing twice before the boulder moves
    mov al, [ebp + wMiscFlags]
    mov cl, al                                 ; save the prior TRIED_PUSH bit state (bit [hl])
    or al, (1 << BIT_TRIED_PUSH_BOULDER)
    mov [ebp + wMiscFlags], al                 ; set BIT_TRIED_PUSH_BOULDER, [hl]
    test cl, (1 << BIT_TRIED_PUSH_BOULDER)
    jz .ret                                    ; ret z: first attempt this button press
    mov al, [ebp + hJoyHeld]
    and al, PAD_CTRL_PAD
    jz .ret                                    ; ret z: control pad not held
    call CheckForCollisionWhenPushingBoulder   ; pret: predef (banking elided)
    mov al, [ebp + wTileInFrontOfBoulderAndBoulderCollisionResult]
    and al, al
    jnz ResetBoulderPushFlags                  ; jp nz: collision
    mov al, [ebp + hJoyHeld]
    mov bh, al                                 ; b = held buttons
    mov al, [ebp + wSpritePlayerStateData1FacingDirection]
    cmp al, SPRITE_FACING_UP
    je .pushBoulderUp
    cmp al, SPRITE_FACING_LEFT
    je .pushBoulderLeft
    cmp al, SPRITE_FACING_RIGHT
    je .pushBoulderRight
; push boulder down
    test bh, PAD_DOWN                          ; bit B_PAD_DOWN, b
    jz .ret
    mov edi, PushBoulderDownMovementData
    jmp .done
.pushBoulderUp:
    test bh, PAD_UP                            ; bit B_PAD_UP, b
    jz .ret
    mov edi, PushBoulderUpMovementData
    jmp .done
.pushBoulderLeft:
    test bh, PAD_LEFT                          ; bit B_PAD_LEFT, b
    jz .ret
    mov edi, PushBoulderLeftMovementData
    jmp .done
.pushBoulderRight:
    test bh, PAD_RIGHT                         ; bit B_PAD_RIGHT, b
    jz .ret
    mov edi, PushBoulderRightMovementData
.done:
    call MoveSprite
    mov al, SFX_PUSH_BOULDER
    call PlaySound
    or byte [ebp + wMiscFlags], (1 << BIT_BOULDER_DUST)  ; set BIT_BOULDER_DUST, [hl]
.ret:
    ret

; movement data — one direction step then $ff end (pret places these inline).
PushBoulderUpMovementData:
    db NPC_MOVEMENT_UP
    db -1                                       ; end
PushBoulderDownMovementData:
    db NPC_MOVEMENT_DOWN
    db -1
PushBoulderLeftMovementData:
    db NPC_MOVEMENT_LEFT
    db -1
PushBoulderRightMovementData:
    db NPC_MOVEMENT_RIGHT
    db -1

; ---------------------------------------------------------------------------
; DoBoulderDustAnimation — pret engine/overworld/push_boulder.asm:DoBoulderDustAnimation
; ---------------------------------------------------------------------------
DoBoulderDustAnimation:
    mov al, [ebp + W_STATUS_FLAGS_5]
    test al, (1 << BIT_SCRIPTED_NPC_MOVEMENT)
    jnz .ret                                   ; ret nz: scripted NPC movement in progress
    call AnimateBoulderDust                    ; pret: callfar (banking elided; OW-4.3 unported)
    call DiscardButtonPresses                  ; returns AL = 0
    mov [ebp + W_JOY_IGNORE], al               ; ld [wJoyIgnore], a  (a = 0)
    call ResetBoulderPushFlags                 ; leaves ESI = wMiscFlags (pret leaves hl)
    or byte [ebp + esi], (1 << BIT_PUSHED_BOULDER)  ; set BIT_PUSHED_BOULDER, [hl]
    mov al, [ebp + wBoulderSpriteIndex]
    shl al, 4                                  ; slot<<4 (pret: ldh [hSpriteIndex] → GetSprite… swap)
    mov [ebp + H_CURRENT_SPRITE_OFFSET], al
    call GetSpriteMovementByte2Pointer         ; ESI = flat ptr to movement byte 2
    mov byte [esi], 0x10                        ; ld [hl], $10
    mov al, SFX_CUT
    jmp PlaySound                              ; jp PlaySound (tail call)
.ret:
    ret

; ---------------------------------------------------------------------------
; ResetBoulderPushFlags — clear BIT_BOULDER_DUST + BIT_TRIED_PUSH_BOULDER.
; pret engine/overworld/push_boulder.asm:ResetBoulderPushFlags.
; Out: ESI = wMiscFlags (DoBoulderDustAnimation depends on this, as pret depends
; on hl surviving; TryPushingBoulder's tail jumps here and does not use ESI).
; ---------------------------------------------------------------------------
ResetBoulderPushFlags:
    mov esi, wMiscFlags
    and byte [ebp + esi], ~(1 << BIT_BOULDER_DUST)       ; res BIT_BOULDER_DUST, [hl]
    and byte [ebp + esi], ~(1 << BIT_TRIED_PUSH_BOULDER) ; res BIT_TRIED_PUSH_BOULDER, [hl]
    ret
