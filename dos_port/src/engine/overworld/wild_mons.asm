; wild_mons.asm — LoadWildData (battle engine plan, Stage 9).
;
; Faithful translation of engine/overworld/wild_mons.asm:LoadWildData. Loads the
; current map's wild-encounter data from WildDataPointers into the wGrassRate/
; wGrassMons and wWaterRate/wWaterMons WRAM buffers, ready for TryDoWildEncounter.
;
; The blob layout per map (see tools/generators/gen_wild_encounters.py / data/wild/maps/):
;   [grass_rate]  (+ 20 mon bytes = 10×(level,species) iff grass_rate != 0)
;   [water_rate]  (+ 20 mon bytes iff water_rate != 0)
;
; In the port's flat model WildDataPointers is a dd (32-bit) table indexed by
; wCurMap (×4), each entry a flat program-image pointer to the blob — read with
; [esi] (no EBP bias), exactly like EvosMovesPointerTable. The destination
; buffers are EBP-relative GB WRAM. pret uses CopyData, but that biases the
; source by EBP too, so we copy flat→WRAM with a small inline loop instead.
;
; Register map: a=AL, hl=ESI (flat source), de=EDX (WRAM dest), bc/ecx=count.
;
; Build: nasm -f coff -I include/ -I . -o wild_mons.o wild_mons.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

extern WildDataPointers

section .text

global LoadWildData

LoadWildData:
    ; hl = WildDataPointers[wCurMap] (flat 32-bit pointer to this map's blob)
    movzx ecx, byte [ebp + wCurMap]
    mov esi, [WildDataPointers + ecx*4]

    ; grass rate (ld a,[hli]); esi now points at grass mons (or water rate if 0)
    mov al, [esi]
    inc esi
    mov [ebp + wGrassRate], al
    test al, al
    jz .noGrassData                  ; jr z — no grass data, esi already at water rate
    mov edx, wGrassMons
    mov ecx, WILDDATA_LENGTH - 1     ; 20 bytes
    call .copyFlatToWram             ; advances esi past the 20 grass bytes → water rate
.noGrassData:
    ; water rate (ld a,[hli])
    mov al, [esi]
    inc esi
    mov [ebp + wWaterRate], al
    test al, al
    jz .done                         ; ret z — no water data
    mov edx, wWaterMons
    mov ecx, WILDDATA_LENGTH - 1
    call .copyFlatToWram
.done:
    ret

; copy ECX bytes from flat [esi] to EBP-relative [edx]; advances esi and edx.
.copyFlatToWram:
    mov al, [esi]
    inc esi
    mov [ebp + edx], al
    inc edx
    dec ecx
    jnz .copyFlatToWram
    ret
