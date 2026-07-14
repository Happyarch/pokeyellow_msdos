; print_type.asm — mirror of pret engine/battle/print_type.asm.
;
; pret's file holds four labels: PrintMonType, PrintType, EraseType2Text,
; PrintMoveType (+ the shared tail PrintType_). Until menu-fidelity row 22 the
; port had NONE of them: PrintMonType lives (relocated) in
; engine/pokemon/status_screen.asm, with EraseType2Text inlined into it, and the
; move-type half simply did not exist — battle_menu.asm's port-invented
; PrintMoveInfoBox indexed WideTypeNames itself instead of calling a predef.
; This file is the move-type half, under pret's labels; PrintMonType stays where
; it is (see the note below and menu-fidelity finding M-117).
;
; DEVIATION(gb-memory-model): pret's TypeNames is a GB table of GB pointers, walked
; with `add a / add hl,de / ld a,[hli]`; the port's equivalent is WideTypeNames
; (src/data/type_names.asm — the same table, one flat 32-bit pointer per entry, in
; type-id order including pret's NORMAL-aliased $09-$13 gap), because PlaceString
; takes a flat source pointer. Same table, same index, wider element.
;
; DEVIATION(predef): pret reaches PrintMoveType through `predef PrintMoveType`,
; whose GetPredefRegisters hands the routine HL from the caller. The port has no
; predef table (no banks to switch), so callers `call PrintMoveType` directly with
; the destination already in ESI — the register the predef would have restored.
;
; Register map: A=AL, B=BH, C=BL (BC=BX), D=DH, E=DL (DE=EDX), HL=ESI, EBP = GB base.
;
; Build: nasm -f coff -I include/ -I . -o print_type.o print_type.asm
bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

section .text

global PrintMoveType
global PrintType
global PrintType_

extern PlaceString                     ; text.asm — EAX = flat src, ESI = dest offset
extern WideTypeNames                   ; data/type_names.asm — type id → flat name ptr

; ---------------------------------------------------------------------------
; PrintMoveType — pret print_type.asm:PrintMoveType. Prints the name of the
; CURRENT move's type (wPlayerMoveType, set by GetCurrentMove) at ESI.
; In: ESI = dest tilemap offset. EBP = GB base.  (pret: `call GetPredefRegisters`
; then `ld a, [wPlayerMoveType]`, falling through into PrintType_.)
; ---------------------------------------------------------------------------
PrintMoveType:
    mov al, [ebp + wPlayerMoveType]
    jmp PrintType_                      ; pret falls through

; ---------------------------------------------------------------------------
; PrintType — pret print_type.asm:PrintType. In: AL = type id, ESI = dest.
; (pret pushes hl and jumps to PrintType_, which pops it back before PlaceString;
; the port keeps the destination in ESI throughout, so the push/pop pair is not
; needed and the two labels collapse to a fallthrough.)
; ---------------------------------------------------------------------------
PrintType:
PrintType_:
    movzx ecx, al
    mov eax, [WideTypeNames + ecx * 4]  ; ld hl,TypeNames / add a / add hl,de / deref
    jmp PlaceString                     ; pret: jp PlaceString (tail call)
