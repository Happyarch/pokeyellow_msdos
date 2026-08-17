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
