; respawn_overworld_pikachu.asm — pret engine/pikachu/respawn_overworld_pikachu.asm.
;
; Phase 3 Overworld Follower Pikachu Subsystem:
; If starter Pikachu is in our party and active, schedules Pikachu respawn by setting
; wPikachuSpawnState to 3.
;
; Register map (CLAUDE.md): A->AL, HL->ESI, BC->BX, DE->DX; GB mem = [ebp+SYM].

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

section .text

global RespawnOverworldPikachu

extern IsThisPartyMonStarterPikachu   ; src/engine/pikachu/pikachu_status.asm

; ---------------------------------------------------------------------------
; RespawnOverworldPikachu — pret engine/pikachu/respawn_overworld_pikachu.asm:1
; ---------------------------------------------------------------------------
RespawnOverworldPikachu:
    call IsThisPartyMonStarterPikachu
    jnc .done
    mov byte [ebp + wPikachuSpawnState], 3
.done:
    ret
