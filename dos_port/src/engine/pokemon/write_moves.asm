; write_moves.asm — GetMonLearnset / WriteMonMoves (Pokémon data/stats plan,
; Stage 6).
;
; Source: engine/pokemon/evos_moves.asm:GetMonLearnset, WriteMonMoves,
;         WriteMonMoves_ShiftMoveData (pret/pokeyellow).
;
; WriteMonMoves fills a mon's 4 move slots with the moves it would know by
; wCurEnemyLevel (the level-1 base moves are pre-written by the caller; this adds
; everything learned up to that level, shifting the oldest out when full).
;
; KEY DIVERGENCE — flat vs EBP-relative pointers. The learnset lives in the
; program image (EvosMovesPointerTable + the per-mon blobs are flat `dd`/`db`
; data), so the learnset cursor (ESI/hl) is a FLAT address read with `[esi]`.
; The mon's move slots are GB WRAM, addressed `[ebp+edx]` (de). Inside the
; "shift" branch ESI is briefly reloaded from EDX, so it is a WRAM offset there
; and the shift helper uses `[ebp+...]`. Mind which ESI you are looking at.
;
; The daycare branch (wLearningMovesFromDayCare != 0) is translated faithfully
; but unreachable from current callers (no day-care system yet); its PP write
; reads the flat Moves table directly (like GetMonHeader) rather than via the
; EBP-relative FarCopyData the original uses. Untested — see TODO-DAYCARE.
;
; Register map: a=AL, b=BH, c=BL (bc=EBX), d=DH, e=DL (de=EDX), hl=ESI.
;
; Build: nasm -f coff -I include/ -I . -o write_moves.o write_moves.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

global GetMonLearnset
global WriteMonMoves
global WriteMonMoves_ShiftMoveData

extern GetPredefRegisters
extern Moves
extern EvosMovesPointerTable

section .text

; In:  [wCurPartySpecies] = internal index.
; Out: ESI (hl) = flat pointer to the level-up learnset (past the evo data).
GetMonLearnset:
    movzx ecx, byte [ebp + wCurPartySpecies]
    dec ecx                                  ; index = species - 1
    mov esi, [EvosMovesPointerTable + ecx*4]  ; flat 32-bit pointer (dd table)
.skipEvolutionDataLoop:
    mov al, [esi]                            ; flat read of the blob
    inc esi
    test al, al
    jnz .skipEvolutionDataLoop               ; skip past evo data + its 0 terminator
    ret

; In (via GetPredefRegisters / wPredef*): EDX (de) = move-slot base (MON_MOVES)
;   in WRAM. [wCurPartySpecies], [wCurEnemyLevel], [wLearningMovesFromDayCare].
WriteMonMoves:
    call GetPredefRegisters          ; esi=hl, edx=de (move dest, WRAM), ebx=bc
    push esi
    push edx
    push ebx
    call GetMonLearnset              ; esi = learnset ptr (FLAT)
    jmp .firstMove
.nextMove:
    pop edx                          ; restore de (move-slot base)
.nextMove2:
    inc esi                          ; inc hl (skip the move id; FLAT)
.firstMove:
    mov al, [esi]                    ; ld a,[hli] — level of next learnset move
    inc esi
    test al, al
    jz .done                         ; 0 ⇒ end of learnset
    mov bh, al                       ; ld b,a (move level)
    mov al, [ebp + wCurEnemyLevel]
    cmp al, bh
    jc .done                         ; mon level < move level (sorted ⇒ done)
    mov al, [ebp + wLearningMovesFromDayCare]
    test al, al
    jz .skipMinLevelCheck
    mov al, [ebp + wDayCareStartLevel]
    cmp al, bh
    jnc .nextMove2                   ; min level >= move level (jr nc)
.skipMinLevelCheck:
    ; already known?  ESI points at the move id (FLAT); slots in WRAM via EDX.
    push edx
    mov bl, NUM_MOVES
.alreadyKnowsCheckLoop:
    mov al, [ebp + edx]              ; ld a,[de] (slot)
    inc edx
    cmp al, [esi]                    ; cp [hl] (learnset move id, FLAT)
    je .nextMove                     ; already known ⇒ skip (pop de in .nextMove)
    dec bl
    jnz .alreadyKnowsCheckLoop
    ; find an empty slot
    pop edx
    push edx
    mov bl, NUM_MOVES
.findEmptySlotLoop:
    mov al, [ebp + edx]
    test al, al
    jz .writeMoveToSlot2             ; empty slot found (de left on stack)
    inc edx
    dec bl
    jnz .findEmptySlotLoop
    ; no empty slot — shift moves up (drop move 1)
    pop edx
    push edx
    push esi                         ; save learnset ptr (FLAT)
    mov esi, edx                     ; ld h,d / ld l,e — hl = de (move dest, WRAM)
    call WriteMonMoves_ShiftMoveData
    mov al, [ebp + wLearningMovesFromDayCare]
    test al, al
    jz .writeMoveToSlot
    ; TODO-DAYCARE: shift PP up as well (unreachable: flag always 0 today)
    push edx
    add esi, MON_PP - (MON_MOVES + 3)
    mov edx, esi                     ; ld d,h / ld e,l
    call WriteMonMoves_ShiftMoveData
    pop edx
.writeMoveToSlot:
    pop esi                          ; restore learnset ptr (FLAT)
.writeMoveToSlot2:
    mov al, [esi]                    ; ld a,[hl] (move id, FLAT)
    mov [ebp + edx], al             ; ld [de],a (write into slot, WRAM)
    mov al, [ebp + wLearningMovesFromDayCare]
    test al, al
    jz .nextMove
    ; TODO-DAYCARE: write the move's base PP (unreachable today). DIVERGENCE:
    ; read PP straight from the flat Moves table instead of FarCopyData→wBuffer.
    movzx eax, byte [esi]            ; move id (FLAT)
    dec eax
    imul eax, eax, MOVE_LENGTH
    mov al, [Moves + eax + MOVE_PP]  ; base PP (flat)
    movzx ecx, dx                    ; PP slot = de + (MON_PP - MON_MOVES)
    add ecx, MON_PP - MON_MOVES
    mov [ebp + ecx], al
    jmp .nextMove
.done:
    pop ebx
    pop edx
    pop esi
    ret

; Shift NUM_MOVES-1 entries up by one, freeing the last slot. ESI(hl)=dest,
; EDX(de)=source, both WRAM. Clobbers AL, BL, advances ESI/EDX.
WriteMonMoves_ShiftMoveData:
    mov bl, NUM_MOVES - 1
.loop:
    inc edx                          ; inc de
    mov al, [ebp + edx]              ; ld a,[de]
    mov [ebp + esi], al              ; ld [hli],a
    inc esi
    dec bl
    jnz .loop
    ret
