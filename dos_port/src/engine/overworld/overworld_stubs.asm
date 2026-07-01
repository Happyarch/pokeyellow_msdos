; overworld_stubs.asm — ret-only stubs for overworld sprite dispatch targets that
; are referenced (via jmp) by the live _UpdateSprites branches (Wave 6/M6.2) but
; not yet implemented. Keeping the faithful dispatch structure requires these
; symbols to resolve at link; each stub just returns, so the branch is inert until
; the real routine lands. Remove a stub when its wave provides the real one.
;
; Register map: A→AL, HL→ESI, BC→BX, DE→DX; GB mem = [ebp+SYM] (gb_memmap.inc).

bits 32

section .text

; SpawnPikachu — pret home/pikachu.asm:SpawnPikachu (Pikachu-follower FSM).
; TODO(home-rectify Wave 9/M9.1): replace this stub with the real follower spawn.
; Reached only when a sprite slot's offset == $f0 (slot 15), which no current map
; activates, so this is never called in the live build.
global SpawnPikachu
SpawnPikachu:
    ret

; DoScriptedNPCMovement — pret engine/overworld/movement.asm:DoScriptedNPCMovement
; (walk-a-scripted-NPC-in-sync stepper). TODO(home-rectify follow-up): implement the
; stepper consuming M3.3's wNPCMovementDirections + BIT_SCRIPTED_NPC_MOVEMENT (see
; M6.2 divergence note re: bit-0 vs pret's bit-7/wNPCMovementScriptSpriteOffset split).
; Reached only when BIT_SCRIPTED_NPC_MOVEMENT is set, whose only setter (MoveSprite)
; is check-only, so this is never called in the live build.
global DoScriptedNPCMovement
DoScriptedNPCMovement:
    ret
