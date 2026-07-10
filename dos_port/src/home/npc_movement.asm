; npc_movement.asm — home NPC-movement helpers (OW-A.6).
;
; Source: home/npc_movement.asm (pret/pokeyellow). This mirror currently holds
; only IsPlayerCharacterBeingControlledByGame. The file's other pret resident,
; RunNPCMovementScript (+ PlayerStepOutFromDoor), was translated earlier into
; src/engine/overworld/overworld.asm (documented relocation) and is NOT
; duplicated here.
;
; Register map: a=AL; EBP = GB memory base.
;
; Build: nasm -f coff -I include/ -I . -o npc_movement.o npc_movement.asm

bits 32

%include "gb_memmap.inc"

section .text

global IsPlayerCharacterBeingControlledByGame

; ---------------------------------------------------------------------------
; IsPlayerCharacterBeingControlledByGame — pret home/npc_movement.asm:3.
; Returns NZ (ZF=0) if the game, not the player, is driving the player
; character: an NPC movement script is running, the player is auto-stepping
; down from a door, or joypad states are being simulated. Returns Z otherwise.
; Callers read only ZF (pret: `jr nz, ...`). Clobbers AL.
; ---------------------------------------------------------------------------
IsPlayerCharacterBeingControlledByGame:
    mov al, [ebp + wNPCMovementScriptPointerTableNum]
    test al, al
    jnz .done                                   ; ret nz — movement script active
    mov al, [ebp + W_MOVEMENT_FLAGS]
    test al, (1 << BIT_EXITING_DOOR)            ; bit BIT_EXITING_DOOR, a
    jnz .done                                   ; ret nz — auto-walking off a door
    mov al, [ebp + W_STATUS_FLAGS_5]
    and al, (1 << BIT_SCRIPTED_MOVEMENT_STATE)  ; and 1 << BIT_SCRIPTED_MOVEMENT_STATE
.done:
    ret
