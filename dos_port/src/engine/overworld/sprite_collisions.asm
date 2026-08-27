; sprite_collisions.asm — the sprite dispatch loop and the sprite-vs-sprite
; collision engine.
;
; Mirror of pret engine/overworld/sprite_collisions.asm. It holds four of that
; file's six labels, in pret's order:
;
;   _UpdateSprites                 walk the 16 slots, dispatch each active one
;   UpdateNonPlayerSprite          per-slot scripted-vs-free-roam dispatcher
;   DetectCollisionBetweenSprites  the 16x16 collision scan
;   SetSpriteCollisionValues       step-vector -> pixel/nibble bias helper
;
; All four were carried by src/engine/overworld/movement.asm until chunk 17 of
; the relocated-label grind. movement.asm keeps pret movement.asm's own labels
; (UpdatePlayerSprite, UpdateNPCSprite, CanWalkOntoTile, TryWalking, ...), which
; is why the four externs below cross back and forth between the two files.
;
; NOTE ON ORDER: the port had SetSpriteCollisionValues BEFORE
; DetectCollisionBetweenSprites; pret has it after (and after Func_4d0a). This
; mirror is in pret order. The swap is inert — SetSpriteCollisionValues ends in
; `ret` on both arms, so nothing fell through into it.
;
; It now holds ALL SIX, still in pret's order — Func_4d0a and
; SpriteCollisionBitTable were de-inlined 2026-08-22 and DetectCollisionBetweenSprites
; is now a literal translation (HRAM temps as REAL [ebp+hX] bytes, HL->ESI cursor
; walk, big-endian SpriteCollisionBitTable pointer walk, literal
; SetSpriteCollisionValues ld a,0 quirk). Func_4d0a reads hCollidingSpriteTempX/Y
; directly — no DEVIATION.
;
; Register map: A=AL, B=BH, C=BL (BC=BX), D=DH, E=DL (DE=EDX), HL=ESI, EBP=GB base.
;
; Build: nasm -f coff -I include/ -I . -o sprite_collisions.o sprite_collisions.asm

bits 32

%include "gb_memmap.inc"

global _UpdateSprites
global Func_4d0a
global SpriteCollisionBitTable
global UpdateNonPlayerSprite
global DetectCollisionBetweenSprites

extern UpdatePlayerSprite        ; src/engine/overworld/movement.asm
extern UpdateNPCSprite           ; src/engine/overworld/movement.asm
extern DoScriptedNPCMovement     ; src/engine/overworld/movement.asm

; Wave-9 Pikachu-follower FSM — pret home/pikachu.asm:SpawnPikachu.
; _UpdateSprites dispatches slot 15 (hCurrentSpriteOffset == $f0) here, faithful to
; pret engine/overworld/sprite_collisions.asm:_UpdateSprites. Root must supply a link
; stub until Wave 9 lands (sprite_collisions.asm is a LIVE/linked source).
extern SpawnPikachu              ; home/pikachu.asm — real follower FSM (linked OW-7.2; was an overworld_stubs ret-stub)

section .text

; ---------------------------------------------------------------------------
; _UpdateSprites — iterate the 16 sprite slots, dispatch each active one.
; Pret ref: engine/overworld/sprite_collisions.asm:_UpdateSprites.
; A slot is active when its data2 image-base-offset field is non-zero.
; ---------------------------------------------------------------------------
_UpdateSprites:
    xor esi, esi                         ; ESI = slot byte offset
.loop:
    mov eax, esi
    mov [ebp + hCurrentSpriteOffset], al
    mov al, [ebp + esi + wSpriteStateData2 + SPRITESTATEDATA2_IMAGEBASEOFFSET]
    test al, al
    jz .skip                             ; inactive slot
    test esi, esi
    jnz .npc                             ; slots 1-15 are NPCs/Pikachu
    call UpdatePlayerSprite
    jmp .skip
.npc:
    ; pret: engine/overworld/sprite_collisions.asm:_UpdateSprites.updateCurrentSprite —
    ;   ldh a, [hCurrentSpriteOffset] / cp $f0 / jp z, SpawnPikachu
    ; Slot 15 (offset $f0) is reserved for Pikachu; dispatch to the Wave-9 follower FSM
    ; instead of the free-roam NPC machine. ESI already equals hCurrentSpriteOffset
    ; (set at .loop top), so compare it directly.
    ; GATED (byte-identical default): slot 15 is never populated, so this branch is
    ; never taken today. The reason given here used to be "SpawnPikachu is unported",
    ; which is FALSE — it is ported and linked (OW-7.2). The real reason is the slot
    ; itself: InitSprites fills slots 1..wNumSprites, and no map in the game has 15
    ; or more object_events (measured s16 over all 224 data/maps/objects/*.asm; the
    ; maximum is 14, in SaffronCity and PowerPlant). Slot 15 is reserved for Pikachu
    ; exactly as pret intends, and only the unported Pikachu spawn path would fill it.
    cmp esi, 0xF0
    je .pikachu
    call UpdateNonPlayerSprite
    jmp .skip
.pikachu:
    call SpawnPikachu                    ; pret: jp z, SpawnPikachu (Wave 9)
.skip:
    ; Re-derive ESI from hCurrentSpriteOffset: UpdateNonPlayerSprite reloads ESI
    ; from this field, so we must re-derive rather than trusting the pre-call value.
    movzx esi, byte [ebp + hCurrentSpriteOffset]
    add esi, 0x10
    cmp esi, 0x100
    jne .loop
    ret

; ---------------------------------------------------------------------------
; UpdateNonPlayerSprite — per-sprite dispatcher (scripted vs free-roam).
; pret: engine/overworld/sprite_collisions.asm:UpdateNonPlayerSprite.
;
; Sets hTilePlayerStandingOn = (imageBaseOffset-1)<<4, then routes the slot to the
; scripted-movement stepper (DoScriptedNPCMovement) or falls through to the free-roam
; walk machine (UpdateNPCSprite). pret gates the scripted branch on
; wNPCMovementScriptSpriteOffset == hCurrentSpriteOffset and tail-calls UpdateNPCSprite
; on the unequal path; the port's divergent gate is documented at the branch below.
;
; ESI is reloaded from hCurrentSpriteOffset at entry (clobbers the loop's ESI;
; the loop re-derives ESI after the call — see _UpdateSprites above).
; All other registers: caller pushad/popad, so free.
; ---------------------------------------------------------------------------
UpdateNonPlayerSprite:
    movzx esi, byte [ebp + hCurrentSpriteOffset]
    ; hTilePlayerStandingOn = (imageBaseOffset - 1) << 4 (VRAM tile-group high nibble).
    ; Func_4a7b reads this to find the sprite's tile base: group * 12.
    mov al, [ebp + esi + wSpriteStateData2 + SPRITESTATEDATA2_IMAGEBASEOFFSET]
    dec al
    ror al, 4                            ; nibble swap: (N-1) → (N-1)*16
    mov [ebp + hTilePlayerStandingOn], al

    ; pret: engine/overworld/sprite_collisions.asm:UpdateNonPlayerSprite (:38-45) —
    ; route the slot whose offset == wNPCMovementScriptSpriteOffset to the scripted
    ; stepper DoScriptedNPCMovement; every other slot falls to the free-roam machine.
    ; DoScriptedNPCMovement itself gates on BIT_SCRIPTED_MOVEMENT_STATE (wStatusFlags5
    ; bit 7). OW-2.1: this REPLACES the port's bespoke global BIT_SCRIPTED_NPC_MOVEMENT
    ; (bit-0) gate with pret's per-slot compare (the faithful model). Inert by default —
    ; wNPCMovementScriptSpriteOffset is 0 (the player slot) so it never matches an NPC
    ; slot (>= $10) until a script (pret MoveSprite, OW-2.2) sets it.
    mov al, [ebp + wNPCMovementScriptSpriteOffset]
    cmp al, byte [ebp + hCurrentSpriteOffset]    ; == hCurrentSpriteOffset?
    jne UpdateNPCSprite                  ; unequal → free-roam machine (pret: jp UpdateNPCSprite)
    jmp DoScriptedNPCMovement            ; pret: jp DoScriptedNPCMovement (tail call)
    ; --- end of UpdateNonPlayerSprite dispatcher ---

; ---------------------------------------------------------------------------
; DetectCollisionBetweenSprites — literal translation.
; Pret ref: engine/overworld/sprite_collisions.asm:DetectCollisionBetweenSprites
; Reads hCurrentSpriteOffset to identify sprite i (current slot). Loops all
; 16 slots j, writing YADJUSTED/XADJUSTED/COLLISIONDATA/COLLISIONBITMAP into
; sprite i's SPRITESTATEDATA1. HRAM temps hCollidingSpriteTempYValue/
; hCollidingSpriteTempXValue / hCollidingSpriteAdjustedDistance /
; hCollidingSpriteOffset are REAL [ebp+hX] bytes so every pret operand source
; exists literally (convention-sanctioned lowering: HL->ESI, DE->EDI).
; No-op when all NPC PictureIDs are 0, so safe before NPCs exist.
; All registers clobbered; caller wraps with pushad/popad.
; ---------------------------------------------------------------------------
DetectCollisionBetweenSprites:
    push ebx
    push ecx
    push edx
    push esi
    push edi

    ; ESI = base of sprite i's data1
    movzx esi, byte [ebp + hCurrentSpriteOffset]
    add   esi, wSpriteStateData1

    ; Return early if slot i is unused
    mov   al, byte [ebp + esi + SPRITESTATEDATA1_PICTUREID]
    test  al, al
    jz    .done

    ; Compute i.YAdj = (YPixels+4+B)&0xF0 | C
    movzx eax, byte [ebp + esi + SPRITESTATEDATA1_YSTEPVECTOR]
    call  SetSpriteCollisionValues
    movzx eax, byte [ebp + esi + SPRITESTATEDATA1_YPIXELS]
    add   al, 4
    add   al, bl
    and   al, 0xF0
    or    al, cl
    mov   byte [ebp + esi + SPRITESTATEDATA1_YADJUSTED], al

    ; Compute i.XAdj = (XPixels+B)&0xF0 | C
    movzx eax, byte [ebp + esi + SPRITESTATEDATA1_XSTEPVECTOR]
    call  SetSpriteCollisionValues
    movzx eax, byte [ebp + esi + SPRITESTATEDATA1_XPIXELS]
    add   al, bl
    and   al, 0xF0
    or    al, cl
    mov   byte [ebp + esi + SPRITESTATEDATA1_XADJUSTED], al

    ; OW-A.7: clear COLLISIONDATA (0x0C) and the unnamed 0x0D byte ONLY — pret
    ; (sprite_collisions.asm:104-106) zeros just these two here and NEVER resets
    ; COLLISIONBITMAP_HI/LO (0x0E/0x0F), which accumulate across calls via OR
    ; (see the `or [hl]` at pret :304). The old `dword` zero also wiped 0x0E/0x0F
    ; every call, discarding the accumulated per-sprite collision bitmap.
    mov  word [ebp + esi + SPRITESTATEDATA1_COLLISIONDATA], 0

    xor  edx, edx           ; DL=j=0; DH=direction accumulator (reset each j)

.loop_j:
    mov  [ebp + hCollidingSpriteOffset], dl  ; ldh [hCollidingSpriteOffset],a (pret loop counter store)
    xor  dh, dh

    ; EDI = base of sprite j's data1  (j * 0x10 + wSpriteStateData1)
    movzx edi, dl
    shl   edi, 4
    add   edi, wSpriteStateData1

    ; Skip if j == i
    cmp   edi, esi
    je    .next_j

    ; Skip if j's slot is unused
    mov   al, byte [ebp + edi + SPRITESTATEDATA1_PICTUREID]
    test  al, al
    jz    .next_j

    ; Skip if j is offscreen (IMAGEINDEX == 0xFF)
    movzx eax, byte [ebp + edi + SPRITESTATEDATA1_IMAGEINDEX]
    cmp   al, 0xFF
    je    .next_j

    ; --- Y axis ---
    ; Compute j.YAdj = (j.YPixels+4+B)&0xF0 | C
    movzx eax, byte [ebp + edi + SPRITESTATEDATA1_YSTEPVECTOR]
    call  SetSpriteCollisionValues
    movzx eax, byte [ebp + edi + SPRITESTATEDATA1_YPIXELS]
    add   al, 4
    add   al, bl
    and   al, 0xF0
    or    al, cl               ; AL = j.YAdj

    ; |j.YAdj - i.YAdj|; CF = (j.YAdj < i.YAdj) preserved through negate
    sub   al, byte [ebp + esi + SPRITESTATEDATA1_YADJUSTED]
    jnc   .y_pos
    not   al                   ; cpl
    inc   al                   ; inc a (preserves CF, as SM83 inc does)
.y_pos:
    mov   [ebp + hCollidingSpriteTempYValue], al ; ldh [hCollidingSpriteTempYValue],a (distance)
    ; Accumulate Y direction into DH[1:0].
    ; SM83: push af; rl c; pop af; ccf; rl c — x86 equivalent via setc/shl/or:
    ; DH[1]=CF (i.Y>j.Y → 1), DH[0]=!CF (j.Y>=i.Y → 1).
    setc  ch
    shl   dh, 1
    or    dh, ch
    shl   dh, 1
    xor   ch, 1
    or    dh, ch               ; DH[1:0] = CF_y : !CF_y here; the X block below shifts
                               ; these Y bits up to DH[3:2] (final: DH[3:2]=Y, DH[1:0]=X)

    ; threshold_i_y: low nibble of i.YAdj == 0 → 7, else 9
    mov   ch, byte [ebp + esi + SPRITESTATEDATA1_YADJUSTED]
    and   ch, 0x0F
    mov   bl, 7
    jz    .tiy_done
    mov   bl, 9
.tiy_done:
    mov   al, [ebp + hCollidingSpriteTempYValue] ; distance
    sub   al, bl               ; AL = |diffY| - thr_i_y
    mov   [ebp + hCollidingSpriteAdjustedDistance], al
    mov   [ebp + hCollidingSpriteTempYValue], bl ; store threshold (overwrites distance)
    jc    .check_x             ; |diffY| < thr_i_y: Y axis clear, check X

    ; Check j's Y threshold (j's step vector determines 7 or 9)
    movzx eax, byte [ebp + edi + SPRITESTATEDATA1_YSTEPVECTOR]
    test  al, al
    mov   bl, 7
    jz    .tjy_done
    mov   bl, 9
.tjy_done:
    mov   al, [ebp + hCollidingSpriteAdjustedDistance]
    sub   al, bl
    jz    .check_x             ; exactly 0: border collision, still check X
    jnc   .next_j              ; > 0: too far apart

.check_x:
    ; --- X axis ---
    movzx eax, byte [ebp + edi + SPRITESTATEDATA1_XSTEPVECTOR]
    call  SetSpriteCollisionValues
    movzx eax, byte [ebp + edi + SPRITESTATEDATA1_XPIXELS]
    add   al, bl
    and   al, 0xF0
    or    al, cl               ; AL = j.XAdj

    sub   al, byte [ebp + esi + SPRITESTATEDATA1_XADJUSTED]
    jnc   .x_pos
    not   al                   ; cpl
    inc   al                   ; inc a (preserves CF)
.x_pos:
    mov   [ebp + hCollidingSpriteTempXValue], al ; distance
    setc  ch
    shl   dh, 1
    or    dh, ch
    shl   dh, 1
    xor   ch, 1
    or    dh, ch               ; OW-A.7: FINAL layout DH[1:0] = CF_x:!CF_x (X axis);
                               ; the Y bits set above were shifted up to DH[3:2] by this
                               ; block's two `shl dh,1`. pret (sprite_collisions.asm:293):
                               ; bits 0-1 = X axis, bits 2-3 = Y axis.

    mov   ch, byte [ebp + esi + SPRITESTATEDATA1_XADJUSTED]
    and   ch, 0x0F
    mov   bl, 7
    jz    .tix_done
    mov   bl, 9
.tix_done:
    mov   al, [ebp + hCollidingSpriteTempXValue] ; distance
    sub   al, bl
    mov   [ebp + hCollidingSpriteAdjustedDistance], al
    mov   [ebp + hCollidingSpriteTempXValue], bl ; threshold
    jc    .collision

    movzx eax, byte [ebp + edi + SPRITESTATEDATA1_XSTEPVECTOR]
    test  al, al
    mov   bl, 7
    jz    .tjx_done
    mov   bl, 9
.tjx_done:
    mov   al, [ebp + hCollidingSpriteAdjustedDistance]
    sub   al, bl
    jz    .collision
    jnc   .next_j

.collision:
    ; --- Pikachu special case: i==player (slot 0) AND j==pikachu (slot 15) ---
    ; pret reaches this at its `ldh a,[hCollidingSpriteOffset] / cp $f / call Func_4d0a`.
    cmp   esi, wSpriteStateData1
    jne   .standard_col
    mov   byte [ebp + W_D433], 0
    cmp   dl, 15
    jne   .standard_col
    ; Func_4d0a now reads hCollidingSpriteTempX/YValue directly (literal HRAM)
    call  Func_4d0a
    jmp   .update_bitmap

.standard_col:
    ; Select direction bits from DH based on which axis threshold is larger.
    ; Larger threshold → that axis drives the collision direction.
    mov   al, [ebp + hCollidingSpriteTempYValue]
    mov   bl, [ebp + hCollidingSpriteTempXValue]
    cmp   al, bl
    jc    .use_xbits
    mov   bl, 0x0C             ; thr_i_y >= thr_i_x → Y bits DH[3:2]
    jmp   .apply_col
.use_xbits:
    mov   bl, 0x03             ; thr_i_y < thr_i_x  → X bits DH[1:0]
.apply_col:
    mov   al, dh
    and   al, bl
    or    al, byte [ebp + esi + SPRITESTATEDATA1_COLLISIONDATA]
    mov   byte [ebp + esi + SPRITESTATEDATA1_COLLISIONDATA], al

.update_bitmap:
    ; Set bit j in the 16-bit collision bitmap at [0x0E:0x0F] (MSB:LSB), through
    ; pret's own LUT rather than recomputing the mask:
    ;   ld de, SpriteCollisionBitTable / add a / add e / ld e,a ...
    ;   ld a,[de] / or [hl] / ld [hli],a      ; big-endian HIGH byte -> $0E
    ;   inc de / ld a,[de] / or [hl] / ld [hl],a  ; LOW byte -> $0F
    ; The inline `1 << (j & 7)` + hi/lo select that stood here computed the same
    ; sixteen values, but it left the pret data label with no port body.
    movzx ecx, dl
    mov   al, [SpriteCollisionBitTable + ecx*2]      ; big-endian HIGH byte
    or    byte [ebp + esi + SPRITESTATEDATA1_COLLISIONBITMAP_HI], al
    mov   al, [SpriteCollisionBitTable + ecx*2 + 1]  ; big-endian LOW byte
    or    byte [ebp + esi + SPRITESTATEDATA1_COLLISIONBITMAP_LO], al

.next_j:
    inc   dl
    cmp   dl, 16
    jl    .loop_j

.done:
    pop   edi
    pop   esi
    pop   edx
    pop   ecx
    pop   ebx
    ret

; ---------------------------------------------------------------------------
; Func_4d0a — literal translation.
; Pret ref: engine/overworld/sprite_collisions.asm:Func_4d0a (:341-359).
;
; Restored to pret's operand sources: reads hCollidingSpriteTempXValue/
; hCollidingSpriteTempYValue directly and walks HL via ESI inc l steps.
; Previous DEVIATION (thresholds in registers, missing inc l) retired —
; literal HRAM reads make it unnecessary.
; ---------------------------------------------------------------------------
Func_4d0a:
    push  esi                  ; preserve HL cursor (pret inc l steps are local)
    mov   al, [ebp + hCollidingSpriteTempXValue] ; ldh a,[hCollidingSpriteTempXValue]
    mov   bl, al
    mov   al, [ebp + hCollidingSpriteTempYValue] ; ldh a,[hCollidingSpriteTempYValue]
    ; pret inc l after ldh Y — advance HL cursor (local)
    add   esi, 1
    cmp   al, bl               ; cp b
    jc    .xbits               ; jr c, .asm_4d17
    mov   bl, 0x0C             ; thr_i_y >= thr_i_x: select DH[3:2]
    jmp   .apply
.xbits:
    mov   bl, 0x03             ; thr_i_y < thr_i_x: select DH[1:0]
.apply:
    mov   al, dh               ; ld a, c
    and   al, bl               ; and b
    mov   byte [ebp + W_D433], al  ; ld [wd433], a
    ; pret :357 ld a,c / inc l / inc l / ret — two inc l steps on HL cursor (local)
    add   esi, 2
    pop   esi
    ret

; ---------------------------------------------------------------------------
; SetSpriteCollisionValues
; Pret ref: engine/overworld/sprite_collisions.asm:SetSpriteCollisionValues
; In:  AL = step vector (0x00=standing, 0x01=moving+, 0xFF=moving-)
; Out: BL = pixel bias (0x00 or 0xFF); CL = nibble bias (0x00, 0x07, or 0x09)
; Clobbers: AL, BL, CL
; ---------------------------------------------------------------------------
SetSpriteCollisionValues:
    test al, al            ; and a
    jz   .zero             ; jr z,.done
    mov  cl, 9             ; ld c,9
    cmp  al, 0xFF          ; cp -1
    je   .setbl            ; jr z,.ok
    mov  cl, 7             ; ld c,7
    mov  al, 0             ; ld a,0 — quirk: xor a would also zero, but pret uses ld a,0
.setbl:
    mov  bl, al            ; ld b,a
    ret
.zero:
    xor  bl, bl            ; ld b,0
    xor  cl, cl            ; ld c,0
    ret

; ---------------------------------------------------------------------------
; SpriteCollisionBitTable — pret engine/overworld/sprite_collisions.asm:
;
;     SpriteCollisionBitTable:
;     FOR n, $10
;         bigdw 1 << n
;     ENDR
;
; Sixteen BIG-ENDIAN words, one per sprite slot, indexed by the colliding slot
; number. The high byte lands in SPRITESTATEDATA1_COLLISIONBITMAP_HI ($0E) and the
; low byte in ..._LO ($0F), which is why the order is big-endian and must stay so
; (CLAUDE.md, "Data is big-endian").
; ---------------------------------------------------------------------------
section .data
SpriteCollisionBitTable:
%assign n 0
%rep 16
    db (1 << n) >> 8, (1 << n) & 0xFF   ; bigdw 1 << n
%assign n n+1
%endrep
