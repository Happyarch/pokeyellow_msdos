; pikachu.asm — Pokemon Yellow overworld Pikachu-follower FSM (Wave 9 / M9.1).
;
; Intended path: dos_port/src/engine/overworld/pikachu.asm
;
; Faithful translation of pret/pokeyellow home/pikachu.asm (the follower state
; plumbing + SpawnPikachu wrapper + movement-script accessors), plus the guard
; entry of engine/pikachu/pikachu_follow.asm:SpawnPikachu_ (here `_SpawnPikachu`).
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
;     dos_port/src/engine/overworld/pikachu.asm
;
; ============================================================================
; LINK/CHECK STATUS: CHECK-ONLY (do NOT add to the Makefile yet).
;   The Pikachu OVERWORLD SPRITE GRAPHICS are not staged (no LoadPlayerSprite-
;   Graphics-style Pikachu tile load), and the deep movement FSM (pret
;   PointerTable_fc710 state handlers, WillPikachuSpawnOnTheScreen, the
;   pikachu_follow/pikachu_movement subsystem) is not ported. Until that lands
;   the follower cannot actually be drawn, so per the M9.1 brief this stays
;   CHECK-only and the ret-stub `SpawnPikachu` in overworld_stubs.asm STAYS
;   (removing it now would leave the M6.2 $f0 dispatch calling nothing / would
;   duplicate the global if both were linked). See SUMMARY.md.
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

; BANK() of the engine-bank Pikachu routines. Cosmetic under the flat model:
; BankswitchCommon only records the requested bank in hLoadedROMBank (no MBC),
; so the exact numeric value is bookkeeping. pret assigns the "Overworld Pikachu"
; ROMX section bank $3F. Use a named constant.
BANK_PikachuOverworld                equ 0x3F  ; pret "Overworld Pikachu" bank; flat-model bookkeeping only

; ---------------------------------------------------------------------------
; Externs
; ---------------------------------------------------------------------------
extern BankswitchCommon                 ; dos_port/src/home/bankswitch.asm (M0.2)
extern IsStarterPikachuAliveInOurParty  ; dos_port/src/engine/pikachu/pikachu_status.asm
                                        ; (defined but currently UNLINKED — see SUMMARY)

; ---------------------------------------------------------------------------
; Globals
; ---------------------------------------------------------------------------
global SpawnPikachu                     ; called by the M6.2 _UpdateSprites $f0 dispatch
global Func_1510
global Func_151d
global EnablePikachuOverworldSpriteDrawing
global DisablePikachuOverworldSpriteDrawing
global DisablePikachuFollowingPlayer
global EnablePikachuFollowingPlayer
global CheckPikachuFollowingPlayer
global Pikachu_IsInArray
global GetPikachuMovementScriptByte
global ApplyPikachuMovementData

section .text

; ===========================================================================
; State plumbing — pret home/pikachu.asm
; wPikachuOverworldStateFlags bit meanings (from pret usage):
;   bit 1 = Pikachu is following the player
;   bit 2 = Pikachu moved this frame (Set/ResetPikachuOverworldStateFlag2)
;   bit 3 = overworld sprite drawing disabled
;   bit 5 / bit 7 = hide Pikachu
; The SM83 `push hl/pop hl` in each routine merely preserves HL; here we address
; the flags via [ebp+SYM] and never touch ESI, so no save/restore is needed.
; ===========================================================================

; Func_1510 — pret home/pikachu.asm:Func_1510. Set hide-bit 7 and blank the
; sprite image index ($ff = off screen).
Func_1510:
    or  byte [ebp + wPikachuOverworldStateFlags], 0x80          ; set 7, [hl]
    mov byte [ebp + wSpritePikachuStateData1ImageIndex], 0xFF   ; ld [hl], $ff
    ret

; Func_151d — pret home/pikachu.asm:Func_151d. Clear hide-bit 7.
Func_151d:
    and byte [ebp + wPikachuOverworldStateFlags], 0x7F          ; res 7, [hl]
    ret

; EnablePikachuOverworldSpriteDrawing — pret home/pikachu.asm. Clear draw-disable bit 3.
EnablePikachuOverworldSpriteDrawing:
    and byte [ebp + wPikachuOverworldStateFlags], 0xF7          ; res 3, [hl]
    ret

; DisablePikachuOverworldSpriteDrawing — pret home/pikachu.asm. Set draw-disable
; bit 3 and blank the image index.
DisablePikachuOverworldSpriteDrawing:
    or  byte [ebp + wPikachuOverworldStateFlags], 0x08          ; set 3, [hl]
    mov byte [ebp + wSpritePikachuStateData1ImageIndex], 0xFF   ; ld [hl], $ff
    ret

; DisablePikachuFollowingPlayer — pret home/pikachu.asm. Set following-disable bit 1.
DisablePikachuFollowingPlayer:
    or  byte [ebp + wPikachuOverworldStateFlags], 0x02          ; set 1, [hl]
    ret

; EnablePikachuFollowingPlayer — pret home/pikachu.asm. Clear bit 1 (Pikachu follows).
EnablePikachuFollowingPlayer:
    and byte [ebp + wPikachuOverworldStateFlags], 0xFD          ; res 1, [hl]
    ret

; CheckPikachuFollowingPlayer — pret home/pikachu.asm. Test bit 1; returns ZF as
; the SM83 `bit 1,[hl]` would (callers branch on jr z/nz). ZF set => not following.
CheckPikachuFollowingPlayer:
    test byte [ebp + wPikachuOverworldStateFlags], 0x02         ; bit 1, [hl]
    ret

; ===========================================================================
; SpawnPikachu — pret home/pikachu.asm:SpawnPikachu (the home wrapper the M6.2
; _UpdateSprites slot-$f0 dispatch calls). On entry hCurrentSpriteOffset == $f0
; (slot 15) and, in pret, HL points at wSpritePikachuStateData2ImageBaseOffset
; ($C2FE). We re-derive that field from hCurrentSpriteOffset (matching the port's
; UpdateNonPlayerSprite convention), compute the VRAM tile group into
; hTilePlayerStandingOn, then homecall the engine-bank body.
;
;   pret:
;     ld a, [hl]                 ; wSpritePikachuStateData2ImageBaseOffset
;     dec a
;     swap a
;     ldh [hTilePlayerStandingOn], a
;     homecall SpawnPikachu_
;     ret
; ===========================================================================
SpawnPikachu:
    movzx esi, byte [ebp + H_CURRENT_SPRITE_OFFSET]   ; esi = $f0 (slot 15 base offset)
    mov al, [ebp + esi + W_SPRITE_STATE_DATA_2 + SPRITESTATEDATA2_IMAGEBASEOFFSET] ; ld a,[hl]
    dec al                                             ; dec a
    ror al, 4                                          ; swap a (nibble swap)
    mov [ebp + H_TILE_PLAYER_STANDING_ON], al          ; ldh [hTilePlayerStandingOn], a
    ; --- homecall SpawnPikachu_  (macros/farcall.asm) ---
    mov al, [ebp + H_LOADED_ROM_BANK]                  ; ldh a,[hLoadedROMBank]
    push eax                                           ; push af
    mov al, BANK_PikachuOverworld                      ; ld a, BANK(SpawnPikachu_)
    call BankswitchCommon
    call _SpawnPikachu                                 ; call SpawnPikachu_
    pop eax                                            ; pop af (AL = saved bank)
    call BankswitchCommon
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

; ResetPikachuOverworldStateFlag2 — pret pikachu_follow.asm. Clear moved-flag bit 2.
ResetPikachuOverworldStateFlag2:
    and byte [ebp + wPikachuOverworldStateFlags], 0xFB ; res 2, [hl]
    ret

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
    mov al, [ebp + W_WALK_BIKE_SURF_STATE]                ; ld a,[wWalkBikeSurfState]
    and al, al
    jnz .hide
    stc                                                   ; scf
    ret
.hide:
    clc                                                   ; and a (clears carry)
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
; Pikachu_IsInArray — pret home/pikachu.asm:Pikachu_IsInArray.
; Search a $ff-terminated byte array [ESI..] for AL. On found: carry set, ESI at
; the matching entry, BH = 1-based match index. On miss: carry clear, ESI at the
; terminator, BH = count. NOTE: distinct from the linked home global IsInArray —
; this variant walks single bytes (stride 1) and reports the index in B.
; ===========================================================================
Pikachu_IsInArray:
    xor bh, bh                  ; ld b, $0
    mov bl, al                  ; ld c, a  (target)
.loop:
    inc bh                      ; inc b
    mov al, [ebp + esi]         ; ld a, [hli]
    inc esi
    cmp al, 0xFF
    je  .not_in_array           ; jr z, .not_in_array
    cmp al, bl                  ; cp c
    jne .loop                   ; jr nz, .loop
    dec bh                      ; dec b
    dec esi                     ; dec hl
    stc                         ; scf
    ret
.not_in_array:
    dec bh                      ; dec b
    dec esi                     ; dec hl
    clc                         ; and a (carry clear)
    ret

; ===========================================================================
; GetPikachuMovementScriptByte — pret home/pikachu.asm. Fetch the next byte of the
; active Pikachu movement script, advancing wPikachuMovementScriptAddress, under
; the script's ROM bank. Returns the byte in AL. Preserves the emulated BC (BX).
;
;   pret:
;     push hl / push bc
;     ldh a,[hLoadedROMBank] / push af
;     ld a,[wPikachuMovementScriptBank] / call BankswitchCommon
;     ld hl, wPikachuMovementScriptAddress
;     ld c,[hl] / inc hl / ld b,[hl]     ; bc = script cursor
;     ld a,[bc] / inc bc                 ; fetch, advance
;     ld [hl],b / dec hl / ld [hl],c     ; store cursor back (LE)
;     ld c,a
;     pop af / call BankswitchCommon
;     ld a,c / pop bc / pop hl / ret
; ===========================================================================
GetPikachuMovementScriptByte:
    push esi                                             ; push hl
    push ebx                                             ; push bc
    mov al, [ebp + H_LOADED_ROM_BANK]                    ; ldh a,[hLoadedROMBank]
    push eax                                             ; push af (save current bank)
    mov al, [ebp + wPikachuMovementScriptBank]           ; ld a,[wPikachuMovementScriptBank]
    call BankswitchCommon
    movzx ebx, word [ebp + wPikachuMovementScriptAddress]; bc = cursor (c=[hl], b=[hl+1], LE)
    ; ld a,[bc] — read emulated GB byte at address BX.
    ; TODO-HW: banked-ROM alias. Under the flat model a $4000-$7FFF cursor into a
    ; ROM bank is read as [ebp+bx]; correct only once the movement-script data is
    ; laid into that GB address (script system not staged). Inert today.
    movzx ecx, byte [ebp + ebx]                          ; hold fetched byte in ECX scratch
    inc bx                                               ; inc bc
    mov [ebp + wPikachuMovementScriptAddress], bx        ; store cursor back (ld[hl],b/ld[hl],c)
    pop eax                                              ; pop af (AL = saved bank)
    call BankswitchCommon                                ; restore bank
    mov al, cl                                           ; ld a, c (result byte)
    pop ebx                                              ; pop bc (caller's BC restored)
    pop esi                                              ; pop hl
    ret

; ===========================================================================
; ApplyPikachuMovementData — pret home/pikachu.asm. Home wrapper that banks to the
; engine routine and applies one step of Pikachu movement data.
;
;   pret:
;     ldh a,[hLoadedROMBank] / ld b,a / push af
;     ld a, BANK(ApplyPikachuMovementData_) / call BankswitchCommon
;     call ApplyPikachuMovementData_
;     pop af / call BankswitchCommon / ret
; ===========================================================================
ApplyPikachuMovementData:
    mov al, [ebp + H_LOADED_ROM_BANK]                    ; ldh a,[hLoadedROMBank]
    mov bh, al                                           ; ld b, a (pret sets B; unused after)
    push eax                                             ; push af (save current bank)
    mov al, BANK_PikachuOverworld                        ; ld a, BANK(ApplyPikachuMovementData_)
    call BankswitchCommon
    call ApplyPikachuMovementData_
    pop eax                                              ; pop af (AL = saved bank)
    call BankswitchCommon
    ret

; ApplyPikachuMovementData_ (pret engine/pikachu/pikachu_movement.asm) is a DEFERRED
; ret-stub relocated to overworld_stubs.asm (OW-A.11; stub convention — a ret-only body
; never lives in the file mirroring its pret source). Retire it there when the movement-
; data interpreter (wCurPikaMovementData union, step timers, sprite placement) is ported.
extern ApplyPikachuMovementData_        ; src/engine/overworld/overworld_stubs.asm (ret-stub)
