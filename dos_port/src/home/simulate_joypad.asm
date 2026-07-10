; simulate_joypad.asm — faithful simulated-joypad framework (home-rectify M3.3).
;
; Intended repo path: dos_port/src/engine/overworld/simulate_joypad.asm
;
; Translated from pret/pokeyellow:
;   home/overworld.asm : AreInputsSimulated, GetSimulatedInput
;   home/map_objects.asm: StartSimulatingJoypadStates, DecodeRLEList,
;                         DecodeArrowMovementRLE
;
; Purpose: generalize the ad-hoc door-exit simulated-joypad hack (previously an
; inline read of wSimulatedJoypadStatesEnd in overworld.asm's OverworldLoop) into
; the real pret system. JoypadOverworld/OverworldLoop now routes idle input through
; AreInputsSimulated, which injects the next queued PAD_* byte into hJoyHeld while a
; scripted-movement buffer is active and self-terminates when it drains.
;
; Register map (SM83 -> x86): A->AL, HL->ESI, B->BH, C->BL, DE->DX (see CLAUDE.md).
; GB pointers that live in RAM are EBP-relative offsets ([ebp + SYM]); pointers into
; embedded data tables (movement/RLE data) are FLAT 32-bit host pointers held in a
; full register (EDI here), per the port convention (see map_sprites.asm).
;
; Build (check): nasm -f coff -I include/ -I . -o simulate_joypad.o \
;                     src/engine/overworld/simulate_joypad.asm
; ---------------------------------------------------------------------------

%include "gb_memmap.inc"
%include "gb_macros.inc"

global AreInputsSimulated
global GetSimulatedInput
global StartSimulatingJoypadStates
global DecodeRLEList
global DecodeArrowMovementRLE

extern FillMemory                 ; src/home/fill_memory.asm — ESI=dest, BX=count, AL=val (ESI preserved)

section .text

; ---------------------------------------------------------------------------
; AreInputsSimulated — if scripted movement is active, overwrite hJoyHeld with the
; next simulated button state; otherwise leave the real joypad state untouched.
; When the simulated buffer drains, tear down all scripted-movement state.
;
; pret: home/overworld.asm:AreInputsSimulated
; In:  (BIT_SCRIPTED_MOVEMENT_STATE of wStatusFlags5), hJoyHeld, override mask
; Out: hJoyHeld (and hJoyPressed/hJoyReleased on the zero-input edge) possibly rewritten
; Clobbers: AL, BL, ESI, flags
; ---------------------------------------------------------------------------
AreInputsSimulated:
    test byte [ebp + W_STATUS_FLAGS_5], (1 << BIT_SCRIPTED_MOVEMENT_STATE)
    jz .ret                                   ; pret: bit .../ ret z — not simulating

    ; if simulating: real presses in the override mask cancel the simulation this frame
    mov bl, [ebp + H_JOY_HELD]                ; b = hJoyHeld
    mov al, [ebp + W_OVERRIDE_SIMULATED_JOYPAD_STATES_MASK]
    and al, bl
    jnz .ret                                  ; overridden -> keep real input

    call GetSimulatedInput                    ; CF=1 -> AL = next simulated state
    jnc .doneSimulating                       ; CF=0 -> buffer drained

    mov [ebp + H_JOY_HELD], al                ; inject simulated press
    test al, al
    jnz .ret                                  ; nonzero press: leave pressed/released alone
    ; a == 0 (a queued "no buttons" frame): also clear pressed/released
    mov byte [ebp + H_JOY_PRESSED], 0
    mov byte [ebp + H_JOY_RELEASED], 0
.ret:
    ret

; if done simulating button presses (pret: .doneSimulating)
.doneSimulating:
    mov byte [ebp + W_UNUSED_OVERRIDE_SIMULATED_JOYPAD_STATES_INDEX], 0
    mov byte [ebp + W_SIMULATED_JOYPAD_STATES_INDEX], 0
    mov byte [ebp + W_SIMULATED_JOYPAD_STATES_END], 0
    mov byte [ebp + W_JOY_IGNORE], 0
    mov byte [ebp + H_JOY_HELD], 0
    ; preserve only movement-flag bits 7,6,5,4,3 (SPINNING|LEDGE_OR_FISHING|5|4|3),
    ; clearing STANDING_ON_DOOR|EXITING_DOOR|STANDING_ON_WARP (bits 2,1,0). pret mask 0xF8.
    and byte [ebp + W_MOVEMENT_FLAGS], (1 << BIT_SPINNING) | (1 << BIT_LEDGE_OR_FISHING) | (1 << 5) | (1 << 4) | (1 << 3)
    and byte [ebp + W_STATUS_FLAGS_5], ~(1 << BIT_SCRIPTED_MOVEMENT_STATE)
    ret

; ---------------------------------------------------------------------------
; GetSimulatedInput — pop the next simulated joypad state off the buffer.
;
; The buffer starts above wSimulatedJoypadStatesEnd and grows downward; the index
; counts remaining entries. Returns the byte at [wSimulatedJoypadStatesEnd + index-1].
;
; pret: home/overworld.asm:GetSimulatedInput
; Out: CF=1 and AL = simulated state, if any remain; CF=0 (and AL=0) when drained.
; Clobbers: AL, ESI, flags
; ---------------------------------------------------------------------------
GetSimulatedInput:
    dec byte [ebp + W_SIMULATED_JOYPAD_STATES_INDEX]
    mov al, [ebp + W_SIMULATED_JOYPAD_STATES_INDEX]
    cmp al, 0xFF                              ; wrapped past 0 -> end of simulated input
    je .endofsimulatedinputs
    movzx esi, al                             ; e = index (d = 0)
    add esi, W_SIMULATED_JOYPAD_STATES_END
    mov al, [ebp + esi]                       ; a = [wSimulatedJoypadStatesEnd + index]
    stc
    ret
.endofsimulatedinputs:
    xor al, al                               ; pret: and a — AL=0, CF=0
    ret

; ---------------------------------------------------------------------------
; StartSimulatingJoypadStates — arm scripted-movement input simulation.
; Zeroes the override mask and the player's (slot-0) movement byte 1, and sets
; BIT_SCRIPTED_MOVEMENT_STATE so AreInputsSimulated begins injecting queued states.
;
; pret: home/map_objects.asm:StartSimulatingJoypadStates
; Clobbers: nothing meaningful (writes RAM only)
; ---------------------------------------------------------------------------
StartSimulatingJoypadStates:
    mov byte [ebp + W_OVERRIDE_SIMULATED_JOYPAD_STATES_MASK], 0
    ; wSpritePlayerStateData2MovementByte1 = slot 0 movement byte 1
    mov byte [ebp + W_SPRITE_STATE_DATA_2 + SPRITESTATEDATA2_MOVEMENTBYTE1], 0
    or byte [ebp + W_STATUS_FLAGS_5], (1 << BIT_SCRIPTED_MOVEMENT_STATE)
    ret

; ---------------------------------------------------------------------------
; DecodeRLEList — expand a $ff-terminated run-length list into a byte buffer.
; Each source entry is <value> <count>; the final $ff is replicated to the output.
;
; pret: home/map_objects.asm:DecodeRLEList
; In:  EDI = flat pointer to the RLE source list
;      ESI = GB output offset (EBP-relative)
; Out: AL  = number of bytes written including the trailing $ff sentinel
;      ESI advanced to the sentinel; EDI advanced past the source terminator
; Clobbers: AL, EBX, ESI, EDI, flags
;
; NOTE(port): the port FillMemory *preserves* ESI (EDI is its scratch), so unlike
; pret — where FillMemory advances hl — we bump ESI by the run length manually.
; ---------------------------------------------------------------------------
DecodeRLEList:
    mov byte [ebp + W_RLE_BYTE_COUNT], 0      ; count written bytes here
.listLoop:
    mov al, [edi]
    cmp al, 0xFF
    je .endOfList
    mov [ebp + H_RLE_BYTE_VALUE], al          ; byte value to be written
    inc edi
    movzx ebx, byte [edi]                     ; BX = run length (C), BH=0
    add [ebp + W_RLE_BYTE_COUNT], bl          ; update total written bytes
    mov al, [ebp + H_RLE_BYTE_VALUE]
    call FillMemory                           ; write AL, BX times, at [ebp+ESI]
    add esi, ebx                              ; advance dest (port FillMemory keeps ESI)
    inc edi
    jmp .listLoop
.endOfList:
    mov byte [ebp + esi], 0xFF                ; write final $ff
    mov al, [ebp + W_RLE_BYTE_COUNT]
    inc al                                    ; include sentinel in the count
    ret

; ---------------------------------------------------------------------------
; DecodeArrowMovementRLE — if the player's coords match an arrow-movement tile,
; decode its RLE movement bytes into the simulated-joypad buffer.
;
; pret: home/map_objects.asm:DecodeArrowMovementRLE
; In:  ESI = flat pointer to the $ff-terminated arrow-movement-tile list
;      BH  = player Y (b), BL = player X (c)
; Out: on match, the simulated-joypad buffer is filled and the index set.
; Clobbers: AL, ESI, EDI, EBX, flags
;
; NOTE(port): a list entry is <Y> <X> <dd flat pointer to RLE data> (6-byte stride);
; pret stores the movement-data pointer as a GB 16-bit dw (4-byte stride). The
; producer arrow-movement tables are owned by map-script waves (deferred). This
; routine is CHECK-only until those tables exist.
; ---------------------------------------------------------------------------
DecodeArrowMovementRLE:
.scan:
    mov al, [esi]                             ; entry Y
    cmp al, 0xFF
    je .noMatch                               ; reached terminator: no match
    cmp al, bh
    jne .next
    mov al, [esi + 1]                         ; entry X
    cmp al, bl
    jne .next
    mov edi, [esi + 2]                        ; EDI = flat pointer to RLE movement data
    mov esi, W_SIMULATED_JOYPAD_STATES_END    ; output buffer offset
    call DecodeRLEList                        ; AL = bytes written incl. sentinel
    dec al
    mov [ebp + W_SIMULATED_JOYPAD_STATES_INDEX], al
    ret
.next:
    add esi, 6                                ; skip Y, X, dd pointer
    jmp .scan
.noMatch:
    ret
