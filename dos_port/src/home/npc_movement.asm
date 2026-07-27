; npc_movement.asm — home NPC-movement helpers (OW-A.6).
;
; Source: home/npc_movement.asm (pret/pokeyellow). This mirror currently holds
; IsPlayerCharacterBeingControlledByGame and RunNPCMovementScript. Pret's
; PlayerStepOutFromDoor half of the door-exit path lives in its own pret file,
; src/engine/overworld/auto_movement.asm (extern below).
;
; Register map: a=AL; EBP = GB memory base.
;
; Build: nasm -f coff -I include/ -I . -o npc_movement.o npc_movement.asm

bits 32

%include "gb_memmap.inc"

section .text

global IsPlayerCharacterBeingControlledByGame
global RunNPCMovementScript

extern PlayerStepOutFromDoor              ; src/engine/overworld/auto_movement.asm

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

; ---------------------------------------------------------------------------
; RunNPCMovementScript — dispatch door-exit auto-walk on warp arrival.
; Checks BIT_STANDING_ON_DOOR (set by .warpTransition), clears it, and calls
; PlayerStepOutFromDoor to inject one forced DOWN step and set BIT_EXITING_DOOR.
; Phase 2: door path only. Full NPC movement script dispatch deferred to Phase 3.
; Pret ref: home/npc_movement.asm:RunNPCMovementScript
; ---------------------------------------------------------------------------
RunNPCMovementScript:
    ; pret: home/npc_movement.asm:RunNPCMovementScript
    test byte [ebp + W_MOVEMENT_FLAGS], (1 << BIT_STANDING_ON_DOOR)
    jz .notDoor
    and byte [ebp + W_MOVEMENT_FLAGS], ~(1 << BIT_STANDING_ON_DOOR)
    call PlayerStepOutFromDoor
    ret
.notDoor:
    ; Scripted-NPC-movement dispatch half: index wNPCMovementScriptPointerTableNum
    ; (1-based) into a table of per-map movement-script pointer tables, then call
    ; function wNPCMovementScriptFunctionNum within it (pret: CallFunctionInTable).
    ; Bankswitching is a no-op under flat memory. UNGATED at OW-7.3 (2026-07-10):
    ; the NPC_MOVEMENT_SCRIPTS_LINKED %ifdef existed only because the per-map
    ; pointer tables (auto_movement.asm / pewter_guys chain) weren't linked; the
    ; OW-7.2 promotion linked them. Still inert until a script sets the table
    ; num nonzero (OW-2.5 Oak cutscene wires the first one).
    mov al, [ebp + wNPCMovementScriptPointerTableNum]
    test al, al
    jz .done
    dec al                                          ; table num is 1-based
    movzx eax, al
    mov esi, [NPCMovementScriptPointerTables + eax*4] ; ESI = flat per-map jumptable
    mov al, [ebp + W_NPC_MOVEMENT_SCRIPT_FUNCTION_NUM]
    call CallFunctionInTable                        ; call function AL within ESI
.done:
    ret

extern CallFunctionInTable                ; src/home/array2.asm
extern PalletMovementScriptPointerTable   ; src/engine/overworld/auto_movement.asm
extern PewterMuseumGuyMovementScriptPointerTable ; src/engine/overworld/auto_movement.asm
extern PewterGymGuyMovementScriptPointerTable ; src/engine/overworld/auto_movement.asm
; pret: RunNPCMovementScript.NPCMovementScriptPointerTables (flat dd in the port;
; read-only, lives in .text by placement — reads only, never written)
NPCMovementScriptPointerTables:
    dd PalletMovementScriptPointerTable
    dd PewterMuseumGuyMovementScriptPointerTable
    dd PewterGymGuyMovementScriptPointerTable

; pret order: EndNPCMovementScript follows RunNPCMovementScript. It does here too —
; the port-only NPCMovementScriptPointerTables blob sits between them, which pret
; keeps inside RunNPCMovementScript. Arrived in chunk 18 of the relocated-label
; grind from src/engine/overworld/auto_movement.asm.
global EndNPCMovementScript
extern _EndNPCMovementScript              ; src/engine/overworld/auto_movement.asm

; EndNPCMovementScript — pret home/npc_movement.asm wrapper (farjp _EndNPCMovementScript);
; banking is elided under flat memory, so it is a plain jump. Kept as its own pret
; label (the split mirrors pret's home/engine boundary).
EndNPCMovementScript:
    jmp _EndNPCMovementScript
