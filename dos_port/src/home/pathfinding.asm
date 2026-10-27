; pathfinding.asm — scripted-NPC movement primitives (home-rectify M3.3).
;
; Repo path: dos_port/src/home/pathfinding.asm (mirror of pret home/pathfinding.asm).
;
; Translated from pret/pokeyellow:
;   home/pathfinding.asm : CalcDifference, MoveSprite, MoveSprite_, DivideBytes
;
; The engine/overworld/pathfinding.asm labels this file used to carry as an
; "engine section" — FindPathToPlayer, CalcPositionOfPlayerRelativeToNPC, the
; two ConvertNPCMovementDirection* routines and their table — now live in their
; own mirror, src/engine/overworld/pathfinding.asm. It still calls CalcDifference
; and DivideBytes from here.
; (the three home/map_objects.asm accessors this file used to carry —
;  SetSpriteMovementBytesToFF, GetSpriteMovementByte1Pointer,
;  GetSpriteMovementByte2Pointer — moved to src/home/map_objects.asm.)
;
; MoveSprite loads a $ff-terminated movement-direction stream into
; wNPCMovementDirections and arms BIT_SCRIPTED_NPC_MOVEMENT so the per-frame sprite
; updater (_UpdateSprites, M6.2) can step the NPC through it. CalcDifference /
; DivideBytes are the coord-delta helpers the higher-level path chooser uses.
;
; Register map (SM83 -> x86): A->AL, HL->ESI, B->BH, C->BL (see CLAUDE.md).
; RAM is EBP-relative; the movement-data source is a FLAT 32-bit host pointer (EDI).
;
; Sprite selector: [hSpriteIndex], a RAW slot number, exactly as pret. The port
; briefly used hCurrentSpriteOffset (slot*0x10) here instead; that was wrong —
; hCurrentSpriteOffset is the _UpdateSprites loop cursor and a separate live HRAM
; byte, and hSpriteIndex aliases hTextID so it cannot carry a shifted value.
; See the SELECTOR note on GetSpriteMovementByte1Pointer (src/home/map_objects.asm).
;
; Build (check): nasm -f coff -I include/ -I . -o pathfinding.o \
;                     src/engine/overworld/pathfinding.asm
; ---------------------------------------------------------------------------

%include "gb_memmap.inc"
%include "gb_macros.inc"

global CalcDifference
global MoveSprite
global MoveSprite_
global MoveSprite2
global IsMoveSprite2Done
global DivideBytes

; The three home/map_objects.asm sprite movement-byte accessors this file used to
; carry now live in their mirror, src/home/map_objects.asm (mirror rule). MoveSprite
; still calls two of them.
extern SetSpriteMovementBytesToFF     ; src/home/map_objects.asm
extern GetSpriteMovementByte1Pointer  ; src/home/map_objects.asm

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
; MoveSprite — move sprite [hSpriteIndex] with the movement stream at EDI.
; Copies the (RLE-free) $ff-terminated direction bytes to wNPCMovementDirections and
; arms scripted-NPC movement. Entry MoveSprite first resets the sprite's movement
; bytes; MoveSprite_ skips that (caller already did it).
;
; pret: home/pathfinding.asm:MoveSprite / MoveSprite_
; In:  EDI = flat pointer to $ff-terminated movement-direction bytes
;      hSpriteIndex = sprite slot number (raw, as pret — NOT slot*0x10)
; Out: wNPCMovementDirections filled; wNPCNumScriptedSteps = step count;
;      BIT_SCRIPTED_NPC_MOVEMENT set; sim-joypad override state reset.
; Clobbers: AL, ECX, ESI, EDI, flags
; ---------------------------------------------------------------------------
MoveSprite:
    call SetSpriteMovementBytesToFF
MoveSprite_:
    call GetSpriteMovementByte1Pointer        ; ESI = EBP-rel offset of movement byte 1
    mov byte [ebp + esi], 0                   ; clear movement byte 1
    mov esi, wNPCMovementDirections        ; ESI = GB offset of the output list
    xor ecx, ecx                              ; c = 0 (step counter)
.loop:
    mov al, [edi]
    mov [ebp + esi], al
    inc edi
    inc esi
    inc cl
    cmp al, 0xFF                              ; reached end of movement data?
    jne .loop

    mov [ebp + wNPCNumScriptedSteps], cl  ; number of steps taken
    or byte [ebp + wStatusFlags5], (1 << BIT_SCRIPTED_NPC_MOVEMENT)
    ; reset simulated-joypad override bookkeeping (pret tail of MoveSprite_)
    mov byte [ebp + wOverrideSimulatedJoypadStatesMask], 0
    mov byte [ebp + wSimulatedJoypadStatesEnd], 0
    mov byte [ebp + wJoyIgnore], 0xFF                          ; pret: dec a (0 -> $ff)
    mov byte [ebp + wUnusedOverrideSimulatedJoypadStatesIndex], 0xFF
    ret

; ---------------------------------------------------------------------------
; MoveSprite2 — dual-tick derivative of MoveSprite (pret's numbered-sibling
; convention, cf. LoadSAV / LoadSAV0-2, SaveSAVtoSRAM / SaveSAVtoSRAM2).
;
; Scope: the Jessie & James pair scenes — the only callers (Mt Moon B2F today;
; the same pair recurs later in the game).
;
; Two NPCs walk at once, one stream each, from the two 90-byte halves of pret's
; 180-byte wNPCMovementDirections allocation (see gb_memmap.inc). The first
; walker is armed exactly as MoveSprite arms it (+0, cursor 0, owns
; BIT_SCRIPTED_NPC_MOVEMENT and wNPCNumScriptedSteps); the second is armed on
; +90 with its cursor initialised to 90, so the existing per-sprite stepper
; advances both independently, one byte per ready tick, with no engine change.
;
; Both MOVEMENTSTATUS values are forced to 1 so the pair consumes its first
; byte on the same tick — a sprite left in the status-2 random-delay state
; could otherwise start up to 127 frames late.
;
; Pret ref: home/pathfinding.asm:MoveSprite (the first walker's half IS its
; body, called rather than copied).
; In:  hSpriteIndex = first walker (raw slot), EDI = first stream  ($FF-terminated)
;      BL           = second walker (raw slot), EDX = second stream ($FF-terminated)
; Out: second stream copied to wNPCMovementDirectionsSecond; both sprites at
;      MOVEMENTSTATUS 1 with their cursors set. hSpriteIndex = second walker.
; Clobbers: AL, ECX, ESI, EDI, flags (EBX/EDX preserved)
; ---------------------------------------------------------------------------
MoveSprite2:
    push ebx
    push edx
    mov bh, bl                                ; BH = second walker slot
    call MoveSprite                           ; first walker: pret-identical
    movzx eax, byte [ebp + hSpriteIndex]
    shl eax, 4
    mov byte [ebp + eax + wSpriteStateData1 + SPRITESTATEDATA1_MOVEMENTSTATUS], 1

    mov [ebp + hSpriteIndex], bh              ; second walker
    call SetSpriteMovementBytesToFF
    movzx eax, byte [ebp + hSpriteIndex]
    shl eax, 4
    mov byte [ebp + eax + wSpriteStateData2 + SPRITESTATEDATA2_MOVEMENTBYTE1], W_NPC_MOVEMENT_DIRECTIONS_HALF
    mov byte [ebp + eax + wSpriteStateData1 + SPRITESTATEDATA1_MOVEMENTSTATUS], 1

    mov esi, wNPCMovementDirectionsSecond     ; copy the second stream ($FF incl.)
.loop:
    mov al, [edx]
    mov [ebp + esi], al
    inc edx
    inc esi
    cmp al, 0xFF
    jne .loop

    pop edx
    pop ebx
    ret

; ---------------------------------------------------------------------------
; IsMoveSprite2Done — CF=1 once BOTH walkers of a MoveSprite2 pair consumed
; their terminator (MOVEMENTBYTE1 == $FF). The shared BIT_SCRIPTED_NPC_MOVEMENT
; flag cannot answer this: it clears when the FIRST walker finishes, which would
; cut a slower partner's script off early.
; In:  AL = first walker slot, BL = second walker slot
; Out: CF = 1 both done, 0 still walking
; Clobbers: ECX, flags (EAX/EBX preserved)
; ---------------------------------------------------------------------------
IsMoveSprite2Done:
    movzx ecx, al
    shl ecx, 4
    cmp byte [ebp + ecx + wSpriteStateData2 + SPRITESTATEDATA2_MOVEMENTBYTE1], 0xFF
    jne .no
    movzx ecx, bl
    shl ecx, 4
    cmp byte [ebp + ecx + wSpriteStateData2 + SPRITESTATEDATA2_MOVEMENTBYTE1], 0xFF
    jne .no
    stc
    ret
.no:
    clc
    ret

; ---------------------------------------------------------------------------
; DivideBytes — [hQuotient2] = [hDividend2] / [hDivisor2] (repeated subtraction).
; pret: home/pathfinding.asm:DivideBytes
; Clobbers: AL, flags (hl preserved as in pret)
; ---------------------------------------------------------------------------
DivideBytes:
    mov byte [ebp + hQuotient2], 0
    cmp byte [ebp + hDivisor2], 0
    je .done                                  ; divisor 0 -> quotient stays 0
    mov al, [ebp + hDividend2]
.loop:
    sub al, [ebp + hDivisor2]
    jc .done
    inc byte [ebp + hQuotient2]
    jmp .loop
.done:
    ret
