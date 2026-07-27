; trainer_sight.asm — trainer sight-line + sprite-position accessors, at the
; pret mirror of engine/overworld/trainer_sight.asm.
;
; Moved here verbatim from the legacy trainer_engine.asm bundle (relocated-labels
; grind, 2026-07-24). Labels in pret's in-file order:
;   _GetSpritePosition1, _GetSpritePosition2, _SetSpritePosition1,
;   _SetSpritePosition2, TrainerWalkUpToPlayer, GetSpriteDataPointer,
;   TrainerEngage, ReadTrainerScreenPosition, CheckSpriteCanSeePlayer,
;   CheckPlayerIsInFrontOfSprite.
; CheckSpriteCanSeePlayer / CheckPlayerIsInFrontOfSprite are file-local, exactly
; as in pret (single-colon labels there). No routine here falls through into the
; next — every body is ret/jmp-terminated, matching pret.
;
; STATUS: LINKED (M8.2 promotion, 2026-07-24 — moved from HOME_CHECK_SRCS to
; the linked list with the full home/trainers.asm mirror). Nothing reaches these
; at runtime until the trainer-header data generator lands: linked, not
; executed. The pret home/trainers.asm bank trampolines (GetSpritePosition1/2,
; SetSpritePosition1/2, TrainerWalkUpToPlayer_Bank0) live with the rest of the
; home/trainers.asm material in src/home/trainers.asm and jmp here.
;
; Register map (CLAUDE.md): A=AL, BC=BX, DE=DX, HL=ESI, EBP = GB base.
;
; Build (check): nasm -f coff -I include/ -I . -o /dev/null \
;                     src/engine/overworld/trainer_sight.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "assets/map_dims.inc"        ; POWER_PLANT map id (generated; the two-tier source)

extern CalcDifference           ; src/home/pathfinding.asm
extern MoveSprite_              ; src/home/pathfinding.asm
extern FillMemory               ; home/copy2.asm  (ESI unchanged on return!)
extern EngageMapTrainer         ; src/home/trainers.asm (pret mirror, linked)

global _GetSpritePosition1
global _GetSpritePosition2
global _SetSpritePosition1
global _SetSpritePosition2
global TrainerWalkUpToPlayer
global GetSpriteDataPointer
global TrainerEngage
global ReadTrainerScreenPosition

; ----------------------------------------------------------------------------
; WRAM/HRAM scratch used by the position accessors (moved with them; see the
; derivation notes in the git history of trainer_engine.asm OW-1.7):
;   wSavedSprite* = pret ram/wram.asm:1837-1840 (link-corrected addresses);
;   hSprite*Coord = port-private HRAM allocation 0xFF82-0xFF85 (pret unions these
;   at 0xFFEB-0xFFEE, which the port's remapped HRAM uses otherwise).
;   TODO(root): fold into gb_memmap.inc when the canonical HRAM map lands. NOTE
;   these four are NOT in gb_memmap.inc, so they do not show in an HRAM occupancy
;   scan of that file alone — scan the tree.
; ----------------------------------------------------------------------------
%ifndef wSavedSpriteScreenY
wSavedSpriteScreenY equ 0xD12F
%endif
%ifndef wSavedSpriteScreenX
wSavedSpriteScreenX equ 0xD130
%endif
%ifndef wSavedSpriteMapY
wSavedSpriteMapY    equ 0xD131
%endif
%ifndef wSavedSpriteMapX
wSavedSpriteMapX    equ 0xD132
%endif
%ifndef hSpriteScreenYCoord
hSpriteScreenYCoord equ 0xFF82
%endif
%ifndef hSpriteScreenXCoord
hSpriteScreenXCoord equ 0xFF83
%endif
%ifndef hSpriteMapYCoord
hSpriteMapYCoord    equ 0xFF84
%endif
%ifndef hSpriteMapXCoord
hSpriteMapXCoord    equ 0xFF85
%endif

; Delta to hop from array1's XPIXELS[slot] to array2's MAPY[slot] (same slot).
; pret: `ld de, wSpritePlayerStateData2MapY - wSpritePlayerStateData1XPixels`
; — a 16-bit HL-wraparound trick specific to SM83 (wSpriteStateData2 is exactly
; wSpriteStateData1 + 0x100, page-aligned; see pret ram/wram.asm:139-142 ASSERTs).
; The port computes the identical byte delta as a plain positive x86 add
; (0x100 + SPRITESTATEDATA2_MAPY - SPRITESTATEDATA1_XPIXELS = 0xFE); no
; wraparound needed since ESI holds the full linear GB offset, not a 16-bit HL.
; PROJ: this replaces pret's two-instruction "ld de,const / add hl,de" with a
; single "add esi,const" (flags-neutral either way; nothing here branches on
; the result) — a 386+ simplification, not a behavior change.
SPRITE_XPIXELS_TO_MAPY_DELTA equ (W_SPRITE_STATE_DATA_2 + SPRITESTATEDATA2_MAPY) - (W_SPRITE_STATE_DATA_1 + SPRITESTATEDATA1_XPIXELS)

section .text

; ----------------------------------------------------------------------------
; _GetSpritePosition1 — read [wSpriteIndex]'s screen Y/X + map Y/X into the
; hSprite*Coord HRAM scratch bytes.
; pret: engine/overworld/trainer_sight.asm:_GetSpritePosition1
; ----------------------------------------------------------------------------
_GetSpritePosition1:
    mov al, [ebp + wSpriteIndex]
    mov [ebp + hSpriteIndex], al
    mov esi, W_SPRITE_STATE_DATA_1
    mov edx, SPRITESTATEDATA1_YPIXELS
    call GetSpriteDataPointer         ; ESI -> array1[slot].YPIXELS
    mov al, [ebp + esi]               ; SPRITESTATEDATA1_YPIXELS
    mov [ebp + hSpriteScreenYCoord], al
    mov al, [ebp + esi + 2]           ; SPRITESTATEDATA1_XPIXELS (YPIXELS+2)
    mov [ebp + hSpriteScreenXCoord], al
    add esi, 2                        ; ESI -> array1[slot].XPIXELS (pret's hl there)
    add esi, SPRITE_XPIXELS_TO_MAPY_DELTA  ; ESI -> array2[slot].MAPY (same slot)
    mov al, [ebp + esi]               ; SPRITESTATEDATA2_MAPY
    mov [ebp + hSpriteMapYCoord], al
    mov al, [ebp + esi + 1]           ; SPRITESTATEDATA2_MAPX (MAPY+1)
    mov [ebp + hSpriteMapXCoord], al
    ret

; ----------------------------------------------------------------------------
; _GetSpritePosition2 — same as _GetSpritePosition1 but into the wSavedSprite*
; WRAM scratch (stash a position, e.g. across a scripted-movement detour).
; pret: engine/overworld/trainer_sight.asm:_GetSpritePosition2
; ----------------------------------------------------------------------------
_GetSpritePosition2:
    mov al, [ebp + wSpriteIndex]
    mov [ebp + hSpriteIndex], al
    mov esi, W_SPRITE_STATE_DATA_1
    mov edx, SPRITESTATEDATA1_YPIXELS
    call GetSpriteDataPointer
    mov al, [ebp + esi]               ; SPRITESTATEDATA1_YPIXELS
    mov [ebp + wSavedSpriteScreenY], al
    mov al, [ebp + esi + 2]           ; SPRITESTATEDATA1_XPIXELS
    mov [ebp + wSavedSpriteScreenX], al
    add esi, 2
    add esi, SPRITE_XPIXELS_TO_MAPY_DELTA
    mov al, [ebp + esi]               ; SPRITESTATEDATA2_MAPY
    mov [ebp + wSavedSpriteMapY], al
    mov al, [ebp + esi + 1]           ; SPRITESTATEDATA2_MAPX
    mov [ebp + wSavedSpriteMapX], al
    ret

; ----------------------------------------------------------------------------
; _SetSpritePosition1 — write hSprite*Coord back into [wSpriteIndex]'s entry.
; pret: engine/overworld/trainer_sight.asm:_SetSpritePosition1
; ----------------------------------------------------------------------------
_SetSpritePosition1:
    mov al, [ebp + wSpriteIndex]
    mov [ebp + hSpriteIndex], al
    mov esi, W_SPRITE_STATE_DATA_1
    mov edx, SPRITESTATEDATA1_YPIXELS
    call GetSpriteDataPointer
    mov al, [ebp + hSpriteScreenYCoord]
    mov [ebp + esi], al               ; SPRITESTATEDATA1_YPIXELS
    mov al, [ebp + hSpriteScreenXCoord]
    mov [ebp + esi + 2], al           ; SPRITESTATEDATA1_XPIXELS
    add esi, 2
    add esi, SPRITE_XPIXELS_TO_MAPY_DELTA
    mov al, [ebp + hSpriteMapYCoord]
    mov [ebp + esi], al               ; SPRITESTATEDATA2_MAPY
    mov al, [ebp + hSpriteMapXCoord]
    mov [ebp + esi + 1], al           ; SPRITESTATEDATA2_MAPX
    ret

; ----------------------------------------------------------------------------
; _SetSpritePosition2 — write wSavedSprite* back into [wSpriteIndex]'s entry.
; pret: engine/overworld/trainer_sight.asm:_SetSpritePosition2
; ----------------------------------------------------------------------------
_SetSpritePosition2:
    mov al, [ebp + wSpriteIndex]
    mov [ebp + hSpriteIndex], al
    mov esi, W_SPRITE_STATE_DATA_1
    mov edx, SPRITESTATEDATA1_YPIXELS
    call GetSpriteDataPointer
    mov al, [ebp + wSavedSpriteScreenY]
    mov [ebp + esi], al               ; SPRITESTATEDATA1_YPIXELS
    mov al, [ebp + wSavedSpriteScreenX]
    mov [ebp + esi + 2], al           ; SPRITESTATEDATA1_XPIXELS
    add esi, 2
    add esi, SPRITE_XPIXELS_TO_MAPY_DELTA
    mov al, [ebp + wSavedSpriteMapY]
    mov [ebp + esi], al               ; SPRITESTATEDATA2_MAPY
    mov al, [ebp + wSavedSpriteMapX]
    mov [ebp + esi + 1], al           ; SPRITESTATEDATA2_MAPX
    ret

; ----------------------------------------------------------------------------
; TrainerWalkUpToPlayer — make the engaging trainer walk up to the player.
; pret: engine/overworld/trainer_sight.asm:TrainerWalkUpToPlayer
; Uses the port scripted-movement primitive MoveSprite_ (EDI=flat stream,
; H_CURRENT_SPRITE_OFFSET=slot*0x10).
; ----------------------------------------------------------------------------
TrainerWalkUpToPlayer:
    mov al, [ebp + wSpriteIndex]
    shl al, 4                       ; swap-nibble equiv for a<16 (slot*0x10)
    mov [ebp + wTrainerSpriteOffset], al
    call ReadTrainerScreenPosition
    mov al, [ebp + wTrainerFacingDirection]
    test al, al
    jz .facingDown                  ; SPRITE_FACING_DOWN
    cmp al, SPRITE_FACING_UP
    je .facingUp
    cmp al, SPRITE_FACING_LEFT
    je .facingLeft
    jmp .facingRight
.facingDown:
    mov al, [ebp + wTrainerScreenY]
    mov bh, al
    mov al, 0x3c                    ; fixed player screen Y
    call CalcDifference             ; AL = |screenY - 0x3c|
    cmp al, 0x10
    je .retEarly                    ; already right above player
    shr al, 4                       ; pret: swap a. Here AL is a block-aligned pixel
                                    ; distance (multiple of $10 from CalcDifference), so
                                    ; swap DIVIDES by 16 → block/step count. (Was shl,
                                    ; which overflowed AL to 0 → dec → $FF steps → 255-byte
                                    ; FillMemory into the 10-byte wNPCMovementDirections2.)
    dec al
    mov bl, al                      ; c = steps to go
    mov al, NPC_MOVEMENT_DOWN       ; 0x00
    jmp .writeWalkScript
.facingUp:
    mov al, [ebp + wTrainerScreenY]
    mov bh, al
    mov al, 0x3c
    call CalcDifference
    cmp al, 0x10
    je .retEarly
    shr al, 4                       ; pret: swap a = divide (block-aligned distance); see .facingDown
    dec al
    mov bl, al
    mov al, NPC_MOVEMENT_UP
    jmp .writeWalkScript
.facingRight:
    mov al, [ebp + wTrainerScreenX]
    mov bh, al
    mov al, 0x40                    ; fixed player screen X
    call CalcDifference
    cmp al, 0x10
    je .retEarly
    shr al, 4                       ; pret: swap a = divide (block-aligned distance); see .facingDown
    dec al
    mov bl, al
    mov al, NPC_MOVEMENT_RIGHT
    jmp .writeWalkScript
.facingLeft:
    mov al, [ebp + wTrainerScreenX]
    mov bh, al
    mov al, 0x40
    call CalcDifference
    cmp al, 0x10
    je .retEarly
    shr al, 4                       ; pret: swap a = divide (block-aligned distance); see .facingDown
    dec al
    mov bl, al
    mov al, NPC_MOVEMENT_LEFT
.writeWalkScript:
    ; pret: fill wNPCMovementDirections2 with `a` for `c` bytes, then $ff sentinel.
    ; Port FillMemory: In ESI=dst GB offset, BX=count, AL=value; ESI unchanged on return.
    ; So BL already holds the step count (c); BH still holds the CalcDifference operand —
    ; save the direction, set up regs.
    push eax                        ; save direction byte (AL)
    movzx ebx, bl                   ; count -> full BX (BH cleared)
    mov esi, wNPCMovementDirections2
    pop eax                         ; AL = direction
    call FillMemory                 ; fill BX dir bytes at [ebp+ESI]
    ; end-of-list sentinel. ESI==wNPCMovementDirections2 (const) here and is
    ; unchanged by FillMemory, so fold it into the displacement (x86 allows only
    ; base+index, not base+index+index).
    mov byte [ebp + ebx + wNPCMovementDirections2], 0xff
    mov al, [ebp + wSpriteIndex]
    shl al, 4
    mov [ebp + H_CURRENT_SPRITE_OFFSET], al  ; port MoveSprite_ selector (pret hSpriteIndex)
    lea edi, [ebp + wNPCMovementDirections2] ; flat stream ptr for MoveSprite_
    ; TODO(M8.2 follow-up): confirm MoveSprite_ EDI/hCurrentSpriteOffset contract at wiring.
    jmp MoveSprite_
.retEarly:
    ret

; ----------------------------------------------------------------------------
; GetSpriteDataPointer — form a pointer into a sprite's wSpriteStateData1/2
; entry from a caller-supplied member offset + [hSpriteIndex] (raw slot 0-15,
; set by the caller just before this call — NOT pre-shifted).
; pret: engine/overworld/trainer_sight.asm:GetSpriteDataPointer
; In:  ESI = base (e.g. W_SPRITE_STATE_DATA_1), EDX = member offset within entry
;      [ebp+hSpriteIndex] = raw slot (0-15)
; Out: ESI = base + member + slot*0x10
; ----------------------------------------------------------------------------
GetSpriteDataPointer:
    push edx                        ; pret: push de
    add esi, edx                    ; pret: add hl, de   (hl = base + member)
    mov al, [ebp + hSpriteIndex]    ; pret: ldh a, [hSpriteIndex]
    shl al, 4                       ; pret: swap a       (slot<16 => *0x10)
    movzx edx, al                   ; pret: ld d,0 / ld e,a
    add esi, edx                    ; pret: add hl, de   (hl = base+member+slot*0x10)
    pop edx                         ; pret: pop de
    ret

; ----------------------------------------------------------------------------
; TrainerEngage — is this trainer lined up + able to see the player? engage if so.
; pret: engine/overworld/trainer_sight.asm:TrainerEngage (predef in pret; direct call here)
; In: wTrainerSpriteOffset (slot*0x10), wTrainerEngageDistance set by caller.
; Out: wTrainerSpriteOffset = $ff if engaging, 0 otherwise.
; ----------------------------------------------------------------------------
TrainerEngage:
    ; sprite on screen? (IMAGEINDEX != $ff)
    movzx esi, byte [ebp + wTrainerSpriteOffset]
    mov al, [ebp + esi + W_SPRITE_STATE_DATA_1 + SPRITESTATEDATA1_IMAGEINDEX]
    cmp al, 0xff
    je .noEngage                    ; sprite off screen
    ; facing dir
    mov al, [ebp + esi + W_SPRITE_STATE_DATA_1 + SPRITESTATEDATA1_FACINGDIRECTION]
    mov [ebp + wTrainerFacingDirection], al
    call ReadTrainerScreenPosition
    ; lined up on Y? (screenY == $3c)
    mov al, [ebp + wTrainerScreenY]
    cmp al, 0x3c
    je .linedUpY
    mov al, [ebp + wTrainerScreenX]
    cmp al, 0x40
    je .linedUpX
    jmp .noEngage
.linedUpY:
    mov al, [ebp + wTrainerScreenX]
    mov bh, al
    mov al, 0x40
    call CalcDifference             ; AL = distance, ZF if equal
    jz .noEngage
    call CheckSpriteCanSeePlayer    ; CF=1 => can see
    jc .engage
    jmp .noEngage
.linedUpX:
    mov al, [ebp + wTrainerScreenY]
    mov bh, al
    mov al, 0x3c
    call CalcDifference
    jz .noEngage
    call CheckSpriteCanSeePlayer
    jc .engage
    jmp .noEngage
.engage:
    call CheckPlayerIsInFrontOfSprite  ; sets wTrainerSpriteOffset ($ff/0)
    mov al, [ebp + wTrainerSpriteOffset]
    test al, al
    jz .noEngage
    or byte [ebp + wMiscFlags], (1 << BIT_SEEN_BY_TRAINER)
    call EngageMapTrainer
    mov byte [ebp + wTrainerSpriteOffset], 0xff
    ret
.noEngage:
    mov byte [ebp + wTrainerSpriteOffset], 0
    ret

; ----------------------------------------------------------------------------
; ReadTrainerScreenPosition — wTrainerScreenY/X from the trainer's sprite slot.
; pret: engine/overworld/trainer_sight.asm:ReadTrainerScreenPosition
; Reads wSpriteStateData1[offset + YPIXELS/XPIXELS], offset = wTrainerSpriteOffset.
; ----------------------------------------------------------------------------
ReadTrainerScreenPosition:
    movzx esi, byte [ebp + wTrainerSpriteOffset]
    mov al, [ebp + esi + W_SPRITE_STATE_DATA_1 + SPRITESTATEDATA1_YPIXELS]
    mov [ebp + wTrainerScreenY], al
    mov al, [ebp + esi + W_SPRITE_STATE_DATA_1 + SPRITESTATEDATA1_XPIXELS]
    mov [ebp + wTrainerScreenX], al
    ret

; ----------------------------------------------------------------------------
; CheckSpriteCanSeePlayer — lined-up + within engage distance?  (file-local,
; single-colon in pret too)
; pret: engine/overworld/trainer_sight.asm:CheckSpriteCanSeePlayer
; In: AL = distance player<->sprite.  Out: CF=1 if in line & in range.
; ----------------------------------------------------------------------------
CheckSpriteCanSeePlayer:
    mov bh, al                      ; b = distance
    mov al, [ebp + wTrainerEngageDistance]
    cmp al, bh                      ; engageDist >= dist?  (CF=0 => can reach)
    jc .notInLine                   ; engageDist < dist => too far
    mov al, [ebp + wTrainerFacingDirection]
    cmp al, SPRITE_FACING_DOWN
    je .checkXCoord
    cmp al, SPRITE_FACING_UP
    je .checkXCoord
    cmp al, SPRITE_FACING_LEFT
    je .checkYCoord
    cmp al, SPRITE_FACING_RIGHT
    je .checkYCoord
    jmp .notInLine
.checkXCoord:
    mov al, [ebp + wTrainerScreenX]
    cmp al, 0x40
    je .inLine
    jmp .notInLine
.checkYCoord:
    mov al, [ebp + wTrainerScreenY]
    cmp al, 0x3c
    jne .notInLine
.inLine:
    stc
    ret
.notInLine:
    clc
    ret

; ----------------------------------------------------------------------------
; CheckPlayerIsInFrontOfSprite — is the player in front of (not behind) the
; sprite?  (file-local, single-colon in pret too)
; pret: engine/overworld/trainer_sight.asm:CheckPlayerIsInFrontOfSprite
; Out: wTrainerSpriteOffset = $ff (engage) or 0 (no engage).
; ----------------------------------------------------------------------------
CheckPlayerIsInFrontOfSprite:
    mov al, [ebp + wCurMap]
    cmp al, POWER_PLANT
    je .engage                      ; Power Plant bypass (fake-item Voltorbs)
    movzx esi, byte [ebp + wTrainerSpriteOffset]
    mov al, [ebp + esi + W_SPRITE_STATE_DATA_1 + SPRITESTATEDATA1_YPIXELS]
    cmp al, 0xfc                    ; topmost tile special-case
    jne .notOnTopmostTile
    mov al, 0x0c
.notOnTopmostTile:
    mov [ebp + wTrainerScreenY], al
    mov al, [ebp + esi + W_SPRITE_STATE_DATA_1 + SPRITESTATEDATA1_XPIXELS]
    mov [ebp + wTrainerScreenX], al
    mov al, [ebp + wTrainerFacingDirection]
    cmp al, SPRITE_FACING_DOWN
    jne .notFacingDown
    mov al, [ebp + wTrainerScreenY]
    cmp al, 0x3c
    jb .engage                      ; sprite above player
    jmp .noEngage
.notFacingDown:
    cmp al, SPRITE_FACING_UP
    jne .notFacingUp
    mov al, [ebp + wTrainerScreenY]
    cmp al, 0x3c
    jae .engage                     ; sprite below player
    jmp .noEngage
.notFacingUp:
    cmp al, SPRITE_FACING_LEFT
    jne .notFacingLeft
    mov al, [ebp + wTrainerScreenX]
    cmp al, 0x40
    jae .engage                     ; sprite right of player
    jmp .noEngage
.notFacingLeft:
    ; facing right
    mov al, [ebp + wTrainerScreenX]
    cmp al, 0x40
    jae .noEngage                   ; sprite right of player
.engage:
    mov byte [ebp + wTrainerSpriteOffset], 0xff
    ret
.noEngage:
    mov byte [ebp + wTrainerSpriteOffset], 0
    ret
