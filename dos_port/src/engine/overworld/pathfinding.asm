; pathfinding.asm — scripted-NPC movement primitives (home-rectify M3.3).
;
; Intended repo path: dos_port/src/engine/overworld/pathfinding.asm
;
; Translated from pret/pokeyellow:
;   home/pathfinding.asm : CalcDifference, MoveSprite, MoveSprite_, DivideBytes
;   home/map_objects.asm : SetSpriteMovementBytesToFF,
;                          GetSpriteMovementByte1Pointer, GetSpriteMovementByte2Pointer
;
; MoveSprite loads a $ff-terminated movement-direction stream into
; wNPCMovementDirections and arms BIT_SCRIPTED_NPC_MOVEMENT so the per-frame sprite
; updater (_UpdateSprites, M6.2) can step the NPC through it. CalcDifference /
; DivideBytes are the coord-delta helpers the higher-level path chooser uses.
;
; Register map (SM83 -> x86): A->AL, HL->ESI, B->BH, C->BL (see CLAUDE.md).
; RAM is EBP-relative; the movement-data source is a FLAT 32-bit host pointer (EDI).
;
; Sprite selector: the port addresses a sprite slot by its byte offset (slot*0x10)
; held in hCurrentSpriteOffset (H_CURRENT_SPRITE_OFFSET) — the analog of pret's
; `hSpriteIndex` after `swap a`. Callers set it before MoveSprite, matching the
; _UpdateSprites loop convention (see movement.asm).
;
; Build (check): nasm -f coff -I include/ -I . -o pathfinding.o \
;                     src/engine/overworld/pathfinding.asm
; ---------------------------------------------------------------------------

%include "gb_memmap.inc"
%include "gb_macros.inc"

global CalcDifference
global MoveSprite
global MoveSprite_
global DivideBytes
global SetSpriteMovementBytesToFF
global GetSpriteMovementByte1Pointer
global GetSpriteMovementByte2Pointer

extern wMapSpriteData            ; map_sprites.asm — [movbyte2, textid] per slot (pret wMapSpriteData)

section .text

; ---------------------------------------------------------------------------
; CalcDifference — AL = |AL - BH|, setting CF if the original AL < BH.
; pret: home/pathfinding.asm:CalcDifference (a<b -> cpl+1, scf)
; In:  AL = a, BH = b   Out: AL = |a-b|, CF = (a < b)
; Clobbers: AL, flags
; ---------------------------------------------------------------------------
CalcDifference:
    sub al, bh
    jc .negate                                ; borrow -> a < b
    ret                                       ; a >= b: AL = a-b, CF=0
.negate:
    neg al                                    ; two's complement -> |a-b| (pret: cpl / add 1)
    stc                                       ; a < b
    ret

; ---------------------------------------------------------------------------
; MoveSprite — move sprite [hCurrentSpriteOffset] with the movement stream at EDI.
; Copies the (RLE-free) $ff-terminated direction bytes to wNPCMovementDirections and
; arms scripted-NPC movement. Entry MoveSprite first resets the sprite's movement
; bytes; MoveSprite_ skips that (caller already did it).
;
; pret: home/pathfinding.asm:MoveSprite / MoveSprite_
; In:  EDI = flat pointer to $ff-terminated movement-direction bytes
;      H_CURRENT_SPRITE_OFFSET = sprite slot*0x10
; Out: wNPCMovementDirections filled; wNPCNumScriptedSteps = step count;
;      BIT_SCRIPTED_NPC_MOVEMENT set; sim-joypad override state reset.
; Clobbers: AL, ECX, ESI, EDI, flags
; ---------------------------------------------------------------------------
MoveSprite:
    call SetSpriteMovementBytesToFF
MoveSprite_:
    call GetSpriteMovementByte1Pointer        ; ESI = EBP-rel offset of movement byte 1
    mov byte [ebp + esi], 0                   ; clear movement byte 1
    mov esi, W_NPC_MOVEMENT_DIRECTIONS        ; ESI = GB offset of the output list
    xor ecx, ecx                              ; c = 0 (step counter)
.loop:
    mov al, [edi]
    mov [ebp + esi], al
    inc edi
    inc esi
    inc cl
    cmp al, 0xFF                              ; reached end of movement data?
    jne .loop

    mov [ebp + W_NPC_NUM_SCRIPTED_STEPS], cl  ; number of steps taken
    or byte [ebp + W_STATUS_FLAGS_5], (1 << BIT_SCRIPTED_NPC_MOVEMENT)
    ; reset simulated-joypad override bookkeeping (pret tail of MoveSprite_)
    mov byte [ebp + W_OVERRIDE_SIMULATED_JOYPAD_STATES_MASK], 0
    mov byte [ebp + W_SIMULATED_JOYPAD_STATES_END], 0
    mov byte [ebp + W_JOY_IGNORE], 0xFF                          ; pret: dec a (0 -> $ff)
    mov byte [ebp + W_UNUSED_OVERRIDE_SIMULATED_JOYPAD_STATES_INDEX], 0xFF
    ret

; ---------------------------------------------------------------------------
; DivideBytes — [hQuotient2] = [hDividend2] / [hDivisor2] (repeated subtraction).
; pret: home/pathfinding.asm:DivideBytes
; Clobbers: AL, flags (hl preserved as in pret)
; ---------------------------------------------------------------------------
DivideBytes:
    mov byte [ebp + H_QUOTIENT2], 0
    cmp byte [ebp + H_DIVISOR2], 0
    je .done                                  ; divisor 0 -> quotient stays 0
    mov al, [ebp + H_DIVIDEND2]
.loop:
    sub al, [ebp + H_DIVISOR2]
    jc .done
    inc byte [ebp + H_QUOTIENT2]
    jmp .loop
.done:
    ret

; ---------------------------------------------------------------------------
; SetSpriteMovementBytesToFF — movement byte 1 = STAY ($ff), byte 2 = NONE ($00),
; for sprite [hCurrentSpriteOffset].
; pret: home/map_objects.asm:SetSpriteMovementBytesToFF
; Clobbers: ESI, flags
; ---------------------------------------------------------------------------
SetSpriteMovementBytesToFF:
    call GetSpriteMovementByte1Pointer
    mov byte [ebp + esi], 0xFF                ; STAY
    call GetSpriteMovementByte2Pointer
    mov byte [esi], 0x00                      ; NONE (ESI = flat wMapSpriteData ptr, not EBP-relative)
    ret

; ---------------------------------------------------------------------------
; GetSpriteMovementByte1Pointer — ESI = EBP-rel offset of sprite [hCurrentSpriteOffset]
; movement byte 1 (wSpriteStateData2 + slot*0x10 + 6).
; pret: home/map_objects.asm:GetSpriteMovementByte1Pointer (swap a / add 6)
; Out: ESI = offset   Clobbers: ESI
; ---------------------------------------------------------------------------
GetSpriteMovementByte1Pointer:
    movzx esi, byte [ebp + H_CURRENT_SPRITE_OFFSET]
    add esi, W_SPRITE_STATE_DATA_2 + SPRITESTATEDATA2_MOVEMENTBYTE1
    ret

; ---------------------------------------------------------------------------
; GetSpriteMovementByte2Pointer — ESI = EBP-rel offset of the sprite's movement
; byte 2 (direction constraint).
; pret: home/map_objects.asm:GetSpriteMovementByte2Pointer.
;
; pret stores byte 2 in wMapSpriteData[(slot-1)*2]; OW-A.2 P2 relocated the port's copy
; there too (it had been stashed in SPRITESTATEDATA2 offset 0x1). Since wMapSpriteData is
; a flat .bss array, this returns ESI = flat address (NOT an EBP-relative offset like
; GetSpriteMovementByte1Pointer); callers write [esi], not [ebp+esi].
; Out: ESI = flat wMapSpriteData ptr   Clobbers: ESI, flags
; ---------------------------------------------------------------------------
GetSpriteMovementByte2Pointer:
    movzx esi, byte [ebp + H_CURRENT_SPRITE_OFFSET]  ; slot byte offset (slot*0x10)
    shr esi, 4                                        ; slot number (1-15)
    dec esi
    add esi, esi                                      ; (slot-1)*2 -> wMapSpriteData index
    add esi, wMapSpriteData                           ; flat address; flags dead (ret follows)
    ret
