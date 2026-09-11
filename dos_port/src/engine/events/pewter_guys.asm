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
; are 32-bit.
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
    mov al, [ebp + wSimulatedJoypadStatesIndex]
    dec al
    mov [ebp + wSimulatedJoypadStatesIndex], al
    movzx edi, al                              ; de = index-1 (d=0)
    add edi, wSimulatedJoypadStatesEnd     ; edi = dest EBP-offset

    movzx eax, byte [ebp + wWhichPewterGuy]
    cmp eax, 1
    ja .badGuyIndex                            ; union residue (this byte aliases dungeon-warp
                                               ; size/prize-window state): touch no table at all
    mov esi, [PewterGuysCoordsTable + eax*4]   ; hl = flat ptr to Pewter*GuyCoords
    ; Bound the entry scan: the museum table holds 4 entries, the gym table 5,
    ; and NEITHER carries a terminator — pret relies on the caller always
    ; standing on a listed tile plus a fully-mapped GB address space, so a scan
    ; miss still dereferences some dw. The port widened dw to flat dd: a miss
    ; walks into the movement bytes below the table and loads 4 of them as a
    ; code pointer, which faults. Talking to the gym guy from an unlisted
    ; adjacent tile (north or east of him) is exactly such a miss.
    ; DEVIATION{class=data-model; pret=engine/events/pewter_guys.asm:PewterGuys; behavior=bound the coord-entry scan to the table's entry count (4 museum, 5 gym) and no-op when no entry matches or the guy index is out of range, instead of scanning past the table end; evidence=neither coord list carries a terminator on either side and the flat dd load faults where the GB dw load only glitched, reachable by talking to the gym guy from an unlisted tile; lifetime=permanent}
    push ecx
    mov ecx, 5
    test eax, eax
    jnz .haveEntryCount
    mov ecx, 4
.haveEntryCount:
    mov bh, [ebp + wYCoord]                  ; b = player Y
    mov bl, [ebp + wXCoord]                  ; c = player X
.findMatchingCoordsLoop:
    mov al, [esi]                              ; entry Y
    inc esi
    cmp al, bh
    jne .nextEntry1
    mov al, [esi]                              ; entry X
    inc esi
    cmp al, bl
    jne .nextEntry2
    pop ecx                                    ; match: release the entry bound
    mov esi, [esi]                             ; hl = flat ptr to this entry's movement data
.copyMovementDataLoop:
    mov al, [esi]
    inc esi
    cmp al, 0xff
    je .done                                   ; ret z
    mov [ebp + edi], al                        ; ld [de], a
    inc edi
    mov al, [ebp + wSimulatedJoypadStatesIndex]
    inc al
    mov [ebp + wSimulatedJoypadStatesIndex], al
    jmp .copyMovementDataLoop
.nextEntry1:
    inc esi                                    ; skip entry X
.nextEntry2:
    add esi, 4                                 ; skip the 4-byte flat movement pointer
    dec ecx
    jnz .findMatchingCoordsLoop
    pop ecx                                    ; exhausted: no listed tile — leave the queued
                                               ; player movement alone and return
    jmp .done
.badGuyIndex:
    ret
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
