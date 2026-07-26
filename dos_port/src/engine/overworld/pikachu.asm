; pikachu.asm — Pokemon Yellow overworld Pikachu-follower FSM (Wave 9 / M9.1).
;
; Intended path: dos_port/src/engine/overworld/pikachu.asm
;
; The pret engine/pikachu/pikachu_follow.asm labels: the SpawnPikachu_ guard entry
; (here `_SpawnPikachu`), ShouldPikachuSpawn, TrySpawnPikachu and
; ResetPikachuOverworldStateFlag2. The home/pikachu.asm half — the state-flag
; plumbing, the SpawnPikachu wrapper, Pikachu_IsInArray and the movement-script
; accessors — now lives in its own mirror, src/home/pikachu.asm.
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

; ---------------------------------------------------------------------------
; Globals
; ---------------------------------------------------------------------------
global _SpawnPikachu                    ; pret SpawnPikachu_; called by the home wrapper

section .text

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
