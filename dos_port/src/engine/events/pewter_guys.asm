; pewter_guys.asm — the Pewter City "guide" NPCs (museum guy / gym guy) that walk
; the player to their destination by queueing simulated-joypad states.
;
; Intended repo path: dos_port/src/engine/events/pewter_guys.asm
; pret source: engine/events/pewter_guys.asm
;
; PewterGuys appends a canned movement stream (chosen by the player's current
; Y/X coord) onto the simulated-joypad queue that grows downward from
; wSimulatedJoypadStatesEnd, bumping wSimulatedJoypadStatesIndex per byte.
;
; Register map (SM83 -> x86): A->AL, HL->ESI, B->BH, C->BL, DE->(dest offset, EDI).
; RAM is EBP-relative; the coord/movement tables are FLAT host data — pret's
; embedded `dw <label>` pointers become `dd` (4-byte flat host pointers), so the
; entry stride is db,db,dd = 6 bytes (pret: db,db,dw = 4) and the pointer loads
; are 32-bit. Check-only until the Pewter map scripts that call it are ported.
;
; Build (check): nasm -f coff -I include/ -I . -o pewter_guys.o \
;                     src/engine/events/pewter_guys.asm
; ---------------------------------------------------------------------------

%include "gb_memmap.inc"
%include "gb_macros.inc"

global PewterGuys

section .text

; ---------------------------------------------------------------------------
; PewterGuys — queue the guide movement for wWhichPewterGuy matching (wYCoord,
; wXCoord) onto the simulated-joypad states.
; pret: engine/events/pewter_guys.asm:PewterGuys
; Clobbers: AL, BX, ESI, EDI, flags
; ---------------------------------------------------------------------------
PewterGuys:
    ; dest = wSimulatedJoypadStatesEnd + (index-1); the pre-decrement makes the
    ; first copied byte overwrite the $ff terminator of the existing queue.
    mov al, [ebp + W_SIMULATED_JOYPAD_STATES_INDEX]
    dec al
    mov [ebp + W_SIMULATED_JOYPAD_STATES_INDEX], al
    movzx edi, al                              ; de = index-1 (d=0)
    add edi, W_SIMULATED_JOYPAD_STATES_END     ; edi = dest EBP-offset

    movzx eax, byte [ebp + wWhichPewterGuy]
    mov esi, [PewterGuysCoordsTable + eax*4]   ; hl = flat ptr to Pewter*GuyCoords
    mov bh, [ebp + W_Y_COORD]                  ; b = player Y
    mov bl, [ebp + W_X_COORD]                  ; c = player X
.findMatchingCoordsLoop:
    mov al, [esi]                              ; entry Y
    inc esi
    cmp al, bh
    jne .nextEntry1
    mov al, [esi]                              ; entry X
    inc esi
    cmp al, bl
    jne .nextEntry2
    mov esi, [esi]                             ; hl = flat ptr to this entry's movement data
.copyMovementDataLoop:
    mov al, [esi]
    inc esi
    cmp al, 0xff
    je .done                                   ; ret z
    mov [ebp + edi], al                        ; ld [de], a
    inc edi
    mov al, [ebp + W_SIMULATED_JOYPAD_STATES_INDEX]
    inc al
    mov [ebp + W_SIMULATED_JOYPAD_STATES_INDEX], al
    jmp .copyMovementDataLoop
.nextEntry1:
    inc esi                                    ; skip entry X
.nextEntry2:
    add esi, 4                                 ; skip the 4-byte flat movement pointer
    jmp .findMatchingCoordsLoop
.done:
    ret

section .rodata

; pret: engine/events/pewter_guys.asm — `dw` pointers flat-adapted to `dd`.
PewterGuysCoordsTable:
    dd PewterMuseumGuyCoords
    dd PewterGymGuyCoords

; The four coordinates of the spaces below/above/left/right of the museum guy,
; each with a pointer to the pre-positioning movement the player makes.
PewterMuseumGuyCoords:
    db 18, 27
    dd .down
    db 16, 27
    dd .up
    db 17, 26
    dd .left
    db 17, 28
    dd .right
.down:
    db PAD_UP, PAD_UP, 0xff
.up:
    db PAD_RIGHT, PAD_LEFT, 0xff
.left:
    db PAD_UP, PAD_RIGHT, 0xff
.right:
    db PAD_UP, PAD_LEFT, 0xff

; The five coordinates that trigger the gym guy and pointers to the player's
; pre-positioning movements. $00 is a pause.
PewterGymGuyCoords:
    db 16, 34
    dd .one
    db 17, 35
    dd .two
    db 18, 37
    dd .three
    db 19, 37
    dd .four
    db 17, 36
    dd .five
.one:
    db PAD_LEFT, PAD_DOWN, PAD_DOWN, PAD_RIGHT, 0xff
.two:
    db PAD_LEFT, PAD_DOWN, PAD_RIGHT, PAD_LEFT, 0xff
.three:
    db PAD_LEFT, PAD_LEFT, PAD_LEFT, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xff
.four:
    db PAD_LEFT, PAD_LEFT, PAD_UP, PAD_LEFT, 0xff
.five:
    db PAD_LEFT, PAD_DOWN, PAD_LEFT, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xff
