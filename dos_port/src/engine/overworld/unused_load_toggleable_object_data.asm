; unused_load_toggleable_object_data.asm — UNREFERENCED completeness port (OW-7.1).
;
; Intended repo path: dos_port/src/engine/overworld/unused_load_toggleable_object_data.asm
; pret source: engine/overworld/unused_load_toggleable_object_data.asm
;
; UNREFERENCED (pret: unreferenced). Func_f0a54 is a bare ret; LoadToggleableObjectData
; is "farcalled by an unreferenced function" — dead in the original. Ported for
; byte-for-byte cross-reference completeness only; never linked into a live path.
;
; NB: it builds pret's `wToggleableObjectList`, which the port's flattened
; toggleable-object model (OW-3.2: gen_toggleable_objects.py + g_toggleable_flags)
; does NOT use — so even if it were live it would feed a list nothing reads. Kept
; faithful for the record. wToggleableObjectList is externed to its golden WRAM
; address for the dead copy target.
;
; Register map (SM83 -> x86): A->AL, B->BH, C->BL, HL->ESI. GB memory is
; [ebp+offset]. The map table is flat ROM: pret `toggleable_object_map`'s `dw <ptr>`
; becomes a `dd` flat pointer, so entries grow 4 -> 6 bytes (db map, db size,
; dd ptr) and the skip stride scales. The final copy's source is a flat ROM label,
; so an inline flat->WRAM rep movsb replaces CopyData (EBP-relative on both
; operands) — cf. map_sprites.asm:ShowTextStream.
;
; Check-only.
;
; Build (check): nasm -f coff -I include/ -I . -o /dev/null \
;                     src/engine/overworld/unused_load_toggleable_object_data.asm
; ---------------------------------------------------------------------------

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_macros.inc"

; --- symbols not yet in the shared headers (golden sym-verified) ---
%ifndef wCurMap
wCurMap               equ 0xD35D ; golden 00:d35d
%endif
%ifndef wToggleableObjectList
wToggleableObjectList equ 0xD5CD ; golden 00:d5cd (unused by the port's flat model)
%endif

; --- constants ---
%ifndef BLUES_HOUSE
BLUES_HOUSE                equ 0x27
%endif
%ifndef TOGGLE_DAISY_SITTING_COPY
TOGGLE_DAISY_SITTING_COPY  equ 0xEC
%endif
%ifndef TOGGLE_DAISY_WALKING_COPY
TOGGLE_DAISY_WALKING_COPY  equ 0xED
%endif
%ifndef TOGGLE_TOWN_MAP_COPY
TOGGLE_TOWN_MAP_COPY       equ 0xEE
%endif

global Func_f0a54
global LoadToggleableObjectData

section .text

; ---------------------------------------------------------------------------
; Func_f0a54 — UNREFERENCED (pret: unreferenced). Bare ret.
; ---------------------------------------------------------------------------
Func_f0a54:
    ret

; ---------------------------------------------------------------------------
; LoadToggleableObjectData — UNREFERENCED (farcalled by an unreferenced function).
; ---------------------------------------------------------------------------
LoadToggleableObjectData:
    mov esi, .ToggleableObjectsMaps
.loop:
    mov al, [esi]                          ; ld a,[hli] (map id, flat)
    inc esi
    cmp al, -1 & 0xFF
    je .ret                                 ; ret z (end)
    mov bh, al                              ; ld b, a
    mov al, [ebp + wCurMap]
    cmp al, bh                              ; cp b
    je .found
    add esi, 5                              ; skip size(1)+dd ptr(4) [pret inc hl x3: db+dw]
    jmp .loop
.found:
    movzx ecx, byte [esi]                  ; ld a,[hli]; ld c,a; ld b,0 -> count
    inc esi
    mov esi, [esi]                          ; ld a,[hli]; ld h,[hl]; ld l,a -> flat src ptr
    ; inline flat->WRAM copy (flat ROM src; CopyData is EBP-relative both operands)
    push edi
    lea edi, [ebp + wToggleableObjectList]  ; ld de, wToggleableObjectList (dead target)
    rep movsb
    pop edi
.ret:
    ret

section .data
; toggleable_object_map map, start, end -> db map, db (end-start), dd start (flat)
.ToggleableObjectsMaps:
    db BLUES_HOUSE
    db .BluesHouseEnd - .BluesHouse
    dd .BluesHouse
    db -1                                   ; end
.BluesHouse:
    db 1, TOGGLE_DAISY_SITTING_COPY
    db 2, TOGGLE_DAISY_WALKING_COPY
    db 3, TOGGLE_TOWN_MAP_COPY
    db -1                                   ; end
.BluesHouseEnd:
