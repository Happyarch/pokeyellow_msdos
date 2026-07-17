; super_rod.asm — faithful port of engine/items/super_rod.asm (pret).
;   ReadSuperRodData             — find the current map's fishing slots.
;   GenerateRandomFishingEncounter — pick one (level, species) pair by RNG.
; Out (both): DX = de = (dh = level, dl = species); DX = 0 when the map has no
; super-rod encounters.
;
; SuperRodFishingSlots data is generated into assets/super_rod.inc by
; tools/generators/gen_super_rod.py and embedded below (standalone/dangling file).
;
; Build: nasm -f coff -I include/ -I . -o /dev/null src/engine/items/super_rod.asm

bits 32

%include "gb_macros.inc"
%include "gb_memmap.inc"

section .text

global ReadSuperRodData
global GenerateRandomFishingEncounter

extern Random               ; -> AL

; ---------------------------------------------------------------------------
; ReadSuperRodData
; ---------------------------------------------------------------------------
ReadSuperRodData:
    mov al, [ebp + W_CUR_MAP]
    mov bl, al                       ; ld c, a (map to match)
    lea esi, [SuperRodFishingSlots]
.loop:
    mov al, [esi]                    ; ld a, [hli]
    inc esi
    cmp al, 0xFF
    je .notfound
    cmp al, bl                       ; cp c
    je .found
    add esi, 8                       ; ld de, 8 / add hl, de (skip this map's 4 pairs)
    jmp .loop
.found:
    call GenerateRandomFishingEncounter
    ret
.notfound:
    xor edx, edx                     ; ld de, 0
    ret

; ---------------------------------------------------------------------------
; GenerateRandomFishingEncounter — ESI = first (species, level) pair of the map.
; ---------------------------------------------------------------------------
GenerateRandomFishingEncounter:
    call Random
    cmp al, 0x66
    jc .pick
    inc esi
    inc esi
    cmp al, 0xB2
    jc .pick
    inc esi
    inc esi
    cmp al, 0xE5
    jc .pick
    inc esi
    inc esi
.pick:
    mov dl, [esi]                    ; ld e, [hl] (species)
    inc esi
    mov dh, [esi]                    ; ld d, [hl] (level)
    ret

section .data
%include "assets/super_rod.inc"
