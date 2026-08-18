; pikachu_follow.asm — mirror of pret engine/pikachu/pikachu_follow.asm.
;
; Was src/engine/overworld/pikachu.asm until the mirror repair. Holds eleven of
; that pret file's labels, in pret order:
;   ShouldPikachuSpawn (:1), ResetPikachuOverworldStateFlag2 (:344),
;   SpawnPikachu_ (:351, see the naming note below), TrySpawnPikachu (:403),
;   GetPikachuFacingDirectionAndReturnToE (:1110), GetPikachuFacingDirection (:1115),
;   ClearPikachuFollowCommandBuffer (:1154), AppendPikachuFollowCommandToBuffer (:1165),
;   RefreshPikachuFollow (:1175), ComputePikachuFollowCommand (:1182),
;   CheckAbsoluteValueLessThan2 (:1249)
;
; The follow-command group (the last five) landed when
; TryApplyPikachuMovementData was ported (src/engine/events/try_pikachu_movement.asm),
; which tail-calls RefreshPikachuFollow.
;
; The remainder are unported, and all belong to the deferred follower FSM:
; SchedulePikachuSpawnForAfterText, ClearPikachuSpriteStateData,
; CalculatePikachuSpawnCoordsAndFacing, CalculatePikachuPlacementCoords,
; CalculatePikachuFacingDirection, SetPikachuSpawnOutside, Pointer_fc64b,
; Pointer_fc653, SetPikachuSpawnWarpPad, Pointer_fc68e, SetPikachuSpawnBackOutside,
; SetPikachuOverworldStateFlag2, Func_fcc08, ComputePikachuFacingDirection.
;
; *** NAMING DEBT, PRE-EXISTING AND NOT INTRODUCED HERE: pret's label is
; `SpawnPikachu_` and the port calls it `_SpawnPikachu` — a forked name, which
; CLAUDE.md's "Preserve pret Labels" rule forbids. It is left alone in this commit
; because renaming it is a behaviour-neutral but separate change touching its
; caller in src/home/pikachu.asm, and because it is why the label reads `port_only`
; rather than `translated` in the label DB. ***
;
; The home/pikachu.asm half — the state-flag plumbing, the SpawnPikachu wrapper,
; Pikachu_IsInArray and the movement-script accessors — lives in its own mirror,
; src/home/pikachu.asm.
;
; Yellow's starter Pikachu walks the overworld one tile behind the player. The
; whole subsystem is INERT unless the follower is enabled: nothing turns it on
; until a map/new-game path calls EnablePikachuFollowingPlayer AND the starter
; Pikachu is alive in the party (IsStarterPikachuAliveInOurParty). No port map
; does either today, so with this file linked the default overworld is byte-for-
; byte unchanged (SpawnPikachu → _SpawnPikachu → TrySpawnPikachu.dont_spawn →
; ret nc, drawing nothing).
;
; Register map (CLAUDE.md): A→AL, HL→ESI, BC→BX (B=BH,C=BL), DE→DX; SM83 `swap a`
; = nibble swap = `ror al, 4`. GB memory = [ebp + SYM] (gb_memmap.inc).
;
; pret citations are given per routine as `pret <file>:<label>`.
;
; Build (standalone check): nasm -f coff -I dos_port/include/ -o /dev/null \
;     dos_port/src/engine/pikachu/pikachu_follow.asm
;
; ============================================================================
; LINK/CHECK STATUS: LINKED (GAME_SRCS, since OW-7.2). The ret-stub `SpawnPikachu`
;   in overworld_stubs.asm was RETIRED when this file was promoted; the M6.2 $f0
;   dispatch now reaches the real follower FSM here.
;   The follower is nonetheless INERT in the live build: the Pikachu OVERWORLD
;   SPRITE GRAPHICS are not staged (no LoadPlayerSpriteGraphics-style Pikachu tile
;   load), and the deep movement FSM (pret PointerTable_fc710 state handlers,
;   WillPikachuSpawnOnTheScreen, the pikachu_follow/pikachu_movement subsystem) is
;   not ported. The only reachable path (follower disabled) is byte-faithful:
;   SpawnPikachu -> _SpawnPikachu -> TrySpawnPikachu.dont_spawn -> ret nc. See SUMMARY.md.
; ============================================================================

bits 32

%include "gb_memmap.inc"
%include "gb_macros.inc"

; ---------------------------------------------------------------------------
; Pikachu WRAM/sprite symbols now live in gb_memmap.inc (OW-A.11: promoted from a
; former file-local placeholder block that stranded them here). The values are
; pokeyellow-real and consistent with the existing gb_memmap Pikachu block
; (W_D433 $D433, wPikachuHappiness $D46F): wPikachuOverworldStateFlags,
; wPikachuMovementScriptBank, wPikachuMovementScriptAddress,
; wSpritePikachuStateData1MovementStatus, wSpritePikachuStateData1ImageIndex.
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; Externs
; ---------------------------------------------------------------------------
extern IsStarterPikachuAliveInOurParty  ; dos_port/src/engine/pikachu/pikachu_status.asm
                                        ; (defined but currently UNLINKED — see SUMMARY)
extern FillMemory                       ; dos_port/src/home/copy2.asm

; ---------------------------------------------------------------------------
; WRAM symbols not yet carried by include/gb_memmap.inc. Addresses are
; pokeyellow.sym `00:d436 wPikachuFollowCommandBufferSize` and
; `00:d437 wPikachuFollowCommandBuffer` — NOT inferred, and consistent with the
; Pikachu block gb_memmap.inc already anchors ($D42F..$D435 immediately below).
; gb_memmap.inc is maintainer-owned, so promoting these is left to its owner;
; the same file-local-`equ` pattern is already used across src/scripts/ and by
; src/home/lcd.asm.
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; Globals
; ---------------------------------------------------------------------------
global _SpawnPikachu                    ; pret SpawnPikachu_; called by the home wrapper
global RefreshPikachuFollow

section .text

; ShouldPikachuSpawn — pret pikachu_follow.asm:ShouldPikachuSpawn. Carry set only
; if Pikachu should be visible: not hidden (bits 5,7 clear), starter Pikachu alive
; in party, and on foot (wWalkBikeSurfState == 0).
ShouldPikachuSpawn:
    test byte [ebp + wPikachuOverworldStateFlags], 0x20  ; bit 5, a
    jnz .hide
    test byte [ebp + wPikachuOverworldStateFlags], 0x80  ; bit 7, a
    jnz .hide
    call IsStarterPikachuAliveInOurParty                  ; carry => alive
    jnc .hide
    mov al, [ebp + wWalkBikeSurfState]                ; ld a,[wWalkBikeSurfState]
    and al, al
    jnz .hide
    stc                                                   ; scf
    ret
.hide:
    clc                                                   ; and a (clears carry)
    ret

; ResetPikachuOverworldStateFlag2 — pret pikachu_follow.asm. Clear moved-flag bit 2.
ResetPikachuOverworldStateFlag2:
    and byte [ebp + wPikachuOverworldStateFlags], 0xFB ; res 2, [hl]
    ret

; ===========================================================================
; _SpawnPikachu — pret engine/pikachu/pikachu_follow.asm:SpawnPikachu_.
;
; ; SCAFFOLD: FAITHFUL GUARD ENTRY ONLY. The default/disabled path (the only one reachable
; today) is complete and byte-faithful: reset the moved-flag, run TrySpawnPikachu;
; if it declines (carry clear, the always-taken default), return having blanked
; the sprite. The enabled path (WillPikachuSpawnOnTheScreen + the PointerTable_
; fc710 movement-state machine + sprite drawing) is DEFERRED — it needs the
; Pikachu overworld sprite graphics and the pikachu_follow/pikachu_movement
; subsystem, neither staged. See SUMMARY.md.
;
;   pret:
;     call ResetPikachuOverworldStateFlag2
;     call TrySpawnPikachu
;     ret nc
;     ... (deferred FSM) ...
; ===========================================================================
_SpawnPikachu:
    call ResetPikachuOverworldStateFlag2
    call TrySpawnPikachu
    jnc .ret                                           ; ret nc (default path exits here)
    ; TODO(M9.1 follow-up): WillPikachuSpawnOnTheScreen + PointerTable_fc710 state
    ; handlers (RefreshPikachuFollow, UpdatePikachuWalkingSprite, Normal/Fast follow,
    ; ...). Requires staged Pikachu overworld sprite tiles. Unreachable while the
    ; follower is disabled, so the default overworld is unaffected.
.ret:
    ret

; TrySpawnPikachu — pret pikachu_follow.asm:TrySpawnPikachu. If Pikachu should not
; spawn, blank its sprite state and return carry clear. If it should and is not yet
; spawned, compute its spawn coords/facing (; SCAFFOLD: DEFERRED — the spawn-coord calc
; is unreachable while the follower is disabled); then return carry set.
TrySpawnPikachu:
    call ShouldPikachuSpawn
    jnc .dont_spawn
    mov al, [ebp + wSpritePikachuStateData1MovementStatus]
    and al, al
    jnz .already_spawned
    ; TODO(M9.1 follow-up): CalculatePikachuSpawnCoordsAndFacing (deep follow calc,
    ; unreachable while the follower is disabled).
.already_spawned:
    stc
    ret
.dont_spawn:
    ; ld hl, wSpritePikachuStateData1ImageIndex; ld [hl],$ff; dec hl; ld [hl],$0
    mov byte [ebp + wSpritePikachuStateData1ImageIndex], 0xFF
    mov byte [ebp + wSpritePikachuStateData1MovementStatus], 0 ; the byte before ImageIndex
    xor al, al                                                 ; xor a (carry clear)
    ret

; ===========================================================================
; GetPikachuFacingDirectionAndReturnToE — pret pikachu_follow.asm:1110
; GetPikachuFacingDirection             — pret pikachu_follow.asm:1115
;
; Answers "which way is Pikachu from the player?" as a SPRITE_FACING_* value
; ($ff when Pikachu is standing on the player's own square). Y is tested first:
; a Y mismatch decides the answer outright and X is never consulted, exactly as
; pret does it.
;
; Out: AL = SPRITE_FACING_UP/DOWN/LEFT/RIGHT, or $ff (standing).
;      GetPikachuFacingDirectionAndReturnToE additionally copies it to E (DL),
;      which is what its one caller (TryApplyPikachuMovementData) compares
;      against B.
; Clobbers: BX (pret loads BC), DX (pret loads D/E), ESI (pret's HL).
;
; SYMBOLS: pret names two WRAM symbols this port's gb_memmap.inc does not carry
; yet — wSpritePikachuStateData1PictureID and the
; wSpritePlayerStateData2Map{Y,X} - wSpritePlayerStateData1 deltas. Rather than
; invent a symbol or hard-code $C1F0/$104, both are written as arithmetic over
; the constants gb_memmap.inc already defines, so they track the struct
; definitions:
;   wSpritePikachuStateData1PictureID
;     = wSpriteStateData1 + PIKACHU_SPRITE_INDEX*SPRITESTATEDATA_STRUCT_SIZE
;       + SPRITESTATEDATA1_PICTUREID                                  (= $C1F0)
;   wSpritePlayerStateData2MapY - wSpritePlayerStateData1
;     = (wSpriteStateData2 + SPRITESTATEDATA2_MAPY) - wSpriteStateData1 (= $104)
;
; DEREFERENCES: every load is [ebp + ...] — wXCoord/wYCoord and the sprite state
; arrays are all emulated GB memory. There is no flat program-image pointer in
; this routine.
;
; FLAGS: pret's `cp e` / `jr z` / `jr nc` pair reads ZF then CF from the SAME
; compare; `je` does not write flags, so the following `jae` still sees the
; compare's CF. `cp` is unsigned on SM83, hence `jae` for `jr nc`.
; ===========================================================================
global GetPikachuFacingDirectionAndReturnToE

GetPikachuFacingDirectionAndReturnToE:
    call GetPikachuFacingDirection
    mov dl, al                          ; ld e, a
    ret

GetPikachuFacingDirection:
    ; ld bc, wSpritePikachuStateData1PictureID
    mov ebx, wSpriteStateData1 + PIKACHU_SPRITE_INDEX * SPRITESTATEDATA_STRUCT_SIZE + SPRITESTATEDATA1_PICTUREID
    mov al, [ebp + wXCoord]
    add al, 4
    mov dh, al                          ; ld d, a
    mov al, [ebp + wYCoord]
    add al, 4
    mov dl, al                          ; ld e, a
    ; ld hl, wSpritePlayerStateData2MapY - wSpritePlayerStateData1 / add hl, bc
    mov esi, (wSpriteStateData2 + SPRITESTATEDATA2_MAPY) - wSpriteStateData1
    add esi, ebx
    mov al, [ebp + esi]                 ; ld a, [hl] — Pikachu's map Y
    cmp al, dl                          ; cp e
    je .asm_fcb71
    jae .asm_fcb6e                      ; jr nc
    mov al, SPRITE_FACING_UP
    ret

.asm_fcb6e:
    mov al, SPRITE_FACING_DOWN
    ret

.asm_fcb71:
    ; ld hl, wSpritePlayerStateData2MapX - wSpritePlayerStateData1 / add hl, bc
    mov esi, (wSpriteStateData2 + SPRITESTATEDATA2_MAPX) - wSpriteStateData1
    add esi, ebx
    mov al, [ebp + esi]                 ; ld a, [hl] — Pikachu's map X
    cmp al, dh                          ; cp d
    je .asm_fcb81
    jae .asm_fcb7e                      ; jr nc
    mov al, SPRITE_FACING_LEFT
    ret

.asm_fcb7e:
    mov al, SPRITE_FACING_RIGHT
    ret

.asm_fcb81:
    mov al, 0xFF                        ; ld a, $ff ; standing
    ret

; ===========================================================================
; The follow-command buffer group — pret pikachu_follow.asm:1154-1255, in pret
; order: ClearPikachuFollowCommandBuffer, AppendPikachuFollowCommandToBuffer,
; RefreshPikachuFollow, ComputePikachuFollowCommand, CheckAbsoluteValueLessThan2.
;
; The "follow command" is a single byte describing where Pikachu is relative to
; the player (1/2/3/4 = adjacent up/down/left/right-ish, 5/6/7/8 = the same
; direction but two or more tiles away). RefreshPikachuFollow recomputes it and
; leaves it as the sole entry of the command buffer.
; ===========================================================================

; ---------------------------------------------------------------------------
; ClearPikachuFollowCommandBuffer — pret pikachu_follow.asm:1154.
;   push bc / ld hl, wPikachuFollowCommandBufferSize / ld [hl], $ff / inc hl
;   ld bc, $10 / xor a / call FillMemory / pop bc / ret
; Size starts at $ff so the first AppendPikachuFollowCommandToBuffer's `inc [hl]`
; makes it 0, i.e. index 0 of the buffer.
;
; NOTE: pret's FillMemory advances HL past the filled range; the port's does not
; (documented contract, src/home/copy2.asm). No caller of this routine reads HL
; afterwards, so the difference is unobservable here.
; ---------------------------------------------------------------------------
ClearPikachuFollowCommandBuffer:
    push ebx                                            ; push bc
    mov esi, wPikachuFollowCommandBufferSize            ; ld hl, ...
    mov byte [ebp + esi], 0xFF                          ; ld [hl], $ff
    inc esi                                             ; inc hl
    mov bx, 0x10                                        ; ld bc, $10
    xor al, al                                          ; xor a
    call FillMemory
    pop ebx                                             ; pop bc
    ret

; ---------------------------------------------------------------------------
; AppendPikachuFollowCommandToBuffer — pret pikachu_follow.asm:1165.
;   ld hl, wPikachuFollowCommandBufferSize / inc [hl] / ld e, [hl] / ld d, 0
;   ld hl, wPikachuFollowCommandBuffer / add hl, de / ld [hl], a / ret
; In: AL = the command byte. Clobbers DX (pret's DE) and ESI (pret's HL).
; No bounds check, exactly as pret: the buffer is 16 bytes and nothing here
; stops the index running past it.
; ---------------------------------------------------------------------------
AppendPikachuFollowCommandToBuffer:
    mov esi, wPikachuFollowCommandBufferSize            ; ld hl, wPikachuFollowCommandBufferSize
    inc byte [ebp + esi]                                ; inc [hl]
    mov dl, [ebp + esi]                                 ; ld e, [hl]
    mov dh, 0                                           ; ld d, 0
    movzx esi, dx                                       ; ld hl, buffer / add hl, de
    add esi, wPikachuFollowCommandBuffer
    mov [ebp + esi], al                                 ; ld [hl], a
    ret

; ---------------------------------------------------------------------------
; RefreshPikachuFollow — pret pikachu_follow.asm:1175.
;   call ClearPikachuFollowCommandBuffer
;   call ComputePikachuFollowCommand
;   ret c                       ; carry = "Pikachu is on the player's square"
;   call AppendPikachuFollowCommandToBuffer
;   ret
; ---------------------------------------------------------------------------
RefreshPikachuFollow:
    call ClearPikachuFollowCommandBuffer
    call ComputePikachuFollowCommand
    jc .ret                                             ; ret c
    call AppendPikachuFollowCommandToBuffer
.ret:
    ret

; ---------------------------------------------------------------------------
; ComputePikachuFollowCommand — pret pikachu_follow.asm:1182.
;
; Y is decided first and, unless the Y difference is exactly zero, X is never
; consulted — the same shape as GetPikachuFacingDirection above. The player's
; wYCoord/wXCoord are compared in sprite-map space by adding 4.
;
; Out: AL = 1..8 with carry CLEAR (`and a`), or carry SET (`scf`) when Pikachu
;      stands on the player's own square, in which case AL is undefined.
;
; SYMBOLS: same construction as GetPikachuFacingDirection — the pret symbol
; wSpritePikachuStateData1PictureID and the
; wSpritePlayerStateData2Map{Y,X} - wSpritePlayerStateData1 deltas are written
; as arithmetic over the constants gb_memmap.inc already defines.
;
; FLAGS: `sub al, [..]` sets both ZF and CF; `je` does not write flags, so the
; following `jb` still reads that same subtraction's CF, and so does
; CheckAbsoluteValueLessThan2 (an x86 `call` writes no flags). SM83 `sub` is
; unsigned, hence `jb` for `jr c`.
; ---------------------------------------------------------------------------
ComputePikachuFollowCommand:
    ; ld bc, wSpritePikachuStateData1PictureID
    mov ebx, wSpriteStateData1 + PIKACHU_SPRITE_INDEX * SPRITESTATEDATA_STRUCT_SIZE + SPRITESTATEDATA1_PICTUREID
    ; ld hl, wSpritePlayerStateData2MapY - wSpritePlayerStateData1 / add hl, bc
    mov esi, (wSpriteStateData2 + SPRITESTATEDATA2_MAPY) - wSpriteStateData1
    add esi, ebx
    mov al, [ebp + wYCoord]             ; ld a, [wYCoord]
    add al, 4                           ; add $4
    sub al, [ebp + esi]                 ; sub [hl]
    je .checkXCoord                     ; jr z
    jb .pikaAbovePlayer                 ; jr c
    call CheckAbsoluteValueLessThan2
    jb .return1                         ; jr c
    mov al, 0x5
    and al, al
    ret

.return1:
    mov al, 0x1
    and al, al
    ret

.pikaAbovePlayer:
    call CheckAbsoluteValueLessThan2
    jb .return2                         ; jr c
    mov al, 0x6
    and al, al
    ret

.return2:
    mov al, 0x2
    and al, al
    ret

.checkXCoord:
    ; ld hl, wSpritePlayerStateData2MapX - wSpritePlayerStateData1 / add hl, bc
    mov esi, (wSpriteStateData2 + SPRITESTATEDATA2_MAPX) - wSpriteStateData1
    add esi, ebx
    mov al, [ebp + wXCoord]             ; ld a, [wXCoord]
    add al, 4                           ; add $4
    sub al, [ebp + esi]                 ; sub [hl]
    je .pikachuOnTopOfPlayer            ; jr z
    jb .pikaToLeftOfPlayer              ; jr c
    call CheckAbsoluteValueLessThan2
    jb .return4                         ; jr c
    mov al, 0x8
    and al, al
    ret

.return4:
    mov al, 0x4
    and al, al
    ret

.pikaToLeftOfPlayer:
    call CheckAbsoluteValueLessThan2
    jb .return3                         ; jr c
    mov al, 0x7
    and al, al
    ret

.return3:
    mov al, 0x3
    and al, al
    ret

.pikachuOnTopOfPlayer:
    stc                                 ; scf
    ret

; ---------------------------------------------------------------------------
; CheckAbsoluteValueLessThan2 — pret pikachu_follow.asm:1249.
;   jr nc, .positive / cpl / inc a / .positive: cp $2 / ret
; In:  AL = a signed difference, CF = the borrow of the subtraction that made it.
; Out: CF set iff |AL| < 2. AL negated in place when it was negative.
; `not` writes no flags on x86 and `inc` preserves CF, so the sequence carries
; the same flag semantics as pret's `cpl` / `inc a`.
; ---------------------------------------------------------------------------
CheckAbsoluteValueLessThan2:
    jae .positive                       ; jr nc
    not al                              ; cpl
    inc al                              ; inc a
.positive:
    cmp al, 0x2                         ; cp $2
    ret
