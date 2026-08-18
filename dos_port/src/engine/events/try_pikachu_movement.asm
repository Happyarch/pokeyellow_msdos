; try_pikachu_movement.asm — mirror of pret engine/events/try_pikachu_movement.asm.
;
; That pret file holds exactly ONE label, TryApplyPikachuMovementData, and it is
; translated here in full; nothing from the file is left out.
;
; WHAT IT DOES (pret engine/events/try_pikachu_movement.asm:1)
;   A map script hands it a Pikachu movement-data pointer in HL and the facing
;   direction the script expects Pikachu to already be in, in B. The routine runs
;   the movement only when all three preconditions hold:
;     1. the starter Pikachu is out (wPikachuSpawnStateFlags bit
;        BIT_PIKACHU_SPAWN_STARTER = bit 7),
;     2. the player is on foot (wWalkBikeSurfState == 0),
;     3. Pikachu is actually standing where the script assumed
;        (GetPikachuFacingDirectionAndReturnToE's E == the caller's B).
;   Then it stages the ledge-hopping shadow tile into VRAM with sprite updates
;   suppressed (wUpdateSpritesEnabled = $ff across the load, restored after),
;   applies the movement data, and recomputes the follow command.
;
; Register map (CLAUDE.md): A→AL, B→BH, C→BL, D→DH, E→DL, HL→ESI, GB memory =
; [ebp + SYM]. `callfar` is a plain `call` under the flat model — the bank switch
; has no counterpart (same precedent as src/home/pikachu.asm and the rest of the
; Pikachu tier).
;
; Build (standalone check):
;   nasm -f coff -I include/ -I . -D BUG_FIX_LEVEL=0 \
;        src/engine/events/try_pikachu_movement.asm -o /tmp/chk.o

bits 32

%include "gb_memmap.inc"
%include "gb_macros.inc"

; ---------------------------------------------------------------------------
; WRAM symbol not yet carried by include/gb_memmap.inc.
;
; Address is pokeyellow.sym `00:d471 wPikachuSpawnStateFlags`, NOT inferred: it
; is consistent with the Pikachu block gb_memmap.inc already anchors
; (wPikachuOverworldStateFlags $D42F, wPikachuHappiness $D46F, wPikachuMood
; $D470). The same file-local `equ` already appears in eight transpiled map
; scripts under src/scripts/ (e.g. pokemon_fan_club.asm:78). gb_memmap.inc is
; maintainer-owned, so promotion of this symbol is left to its owner.
; ---------------------------------------------------------------------------

BIT_PIKACHU_SPAWN_STARTER       equ 7      ; constants/pikachu_emotion_constants.asm

; ---------------------------------------------------------------------------
; Externs
; ---------------------------------------------------------------------------
extern GetPikachuFacingDirectionAndReturnToE  ; src/engine/pikachu/pikachu_follow.asm
extern LoadPikachuShadowIntoVRAM              ; src/engine/pikachu/pikachu_movement.asm
extern ApplyPikachuMovementData               ; src/home/pikachu.asm
extern RefreshPikachuFollow                   ; src/engine/pikachu/pikachu_follow.asm

global TryApplyPikachuMovementData

section .text

; ---------------------------------------------------------------------------
; TryApplyPikachuMovementData — pret engine/events/try_pikachu_movement.asm.
;
; In:  ESI (HL) = movement-data pointer for ApplyPikachuMovementData
;      BH  (B)  = the SPRITE_FACING_* value the caller expects of Pikachu
; Out: nothing; returns early (doing nothing) if any precondition fails.
; ---------------------------------------------------------------------------
TryApplyPikachuMovementData:
    mov al, [ebp + wPikachuSpawnStateFlags]         ; ld a, [wPikachuSpawnStateFlags]
    test al, 1 << BIT_PIKACHU_SPAWN_STARTER         ; bit BIT_PIKACHU_SPAWN_STARTER, a
    jz .ret                                         ; ret z
    mov al, [ebp + wWalkBikeSurfState]              ; ld a, [wWalkBikeSurfState]
    and al, al
    jnz .ret                                        ; ret nz
    push esi                                        ; push hl
    push ebx                                        ; push bc
    call GetPikachuFacingDirectionAndReturnToE      ; callfar (flat: plain call)
    pop ebx                                         ; pop bc
    pop esi                                         ; pop hl
    mov al, bh                                      ; ld a, b
    cmp al, dl                                      ; cp e
    jne .ret                                        ; ret nz
    push esi                                        ; push hl
    mov al, [ebp + wUpdateSpritesEnabled]           ; ld a, [wUpdateSpritesEnabled]
    push eax                                        ; push af
    mov al, 0xFF                                    ; ld a, $ff
    mov [ebp + wUpdateSpritesEnabled], al           ; ld [wUpdateSpritesEnabled], a
    call LoadPikachuShadowIntoVRAM                  ; callfar (flat: plain call)
    pop eax                                         ; pop af
    mov [ebp + wUpdateSpritesEnabled], al           ; ld [wUpdateSpritesEnabled], a
    pop esi                                         ; pop hl
    call ApplyPikachuMovementData
    call RefreshPikachuFollow                       ; callfar (flat: plain call)
.ret:
    ret
