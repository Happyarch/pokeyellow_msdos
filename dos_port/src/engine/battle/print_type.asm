; print_type.asm — mirror of pret engine/battle/print_type.asm.
;
; pret's file holds five labels: PrintMonType, PrintType, EraseType2Text,
; PrintMoveType, and the shared tail PrintType_. All five now live here, in
; pret's order (R-003 retirement, 2026-07-23): PrintMonType/EraseType2Text were
; previously fused into one routine in engine/pokemon/status_screen.asm, and
; before menu-fidelity row 22 the move-type half did not exist at all
; (battle_menu.asm's port-invented PrintMoveInfoBox indexed WideTypeNames
; itself instead of calling a predef).
;
; DEVIATION{class=data-model; pret=engine/battle/print_type.asm:PrintType; behavior=TypeNames uses flat 32-bit pointers instead of bank-local GB pointers; evidence=pret TypeNames indexing plus src/data/type_names.asm WideTypeNames; lifetime=permanent DOS memory model}
; pret's TypeNames is a GB table of GB pointers, walked
; with `add a / add hl,de / ld a,[hli]`; the port's equivalent is WideTypeNames
; (src/data/type_names.asm — the same table, one flat 32-bit pointer per entry, in
; type-id order including pret's NORMAL-aliased $09-$13 gap), because PlaceString
; takes a flat source pointer. Same table, same index, wider element.
;
; DEVIATION{class=banking; pret=engine/battle/print_type.asm:PrintMoveType; behavior=callers invoke PrintMoveType directly with ESI instead of using the banked predef dispatcher; evidence=pret predef call sites plus project_state:PrintMoveType linked provider; lifetime=permanent flat DOS build}
; pret reaches PrintMoveType through `predef PrintMoveType`,
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

global PrintMonType
global PrintType
global EraseType2Text
global PrintMoveType
global PrintType_

extern PlaceString                     ; text.asm — EAX = flat src, ESI = dest offset
extern WideTypeNames                   ; data/type_names.asm — type id → flat name ptr
extern GetMonHeader                    ; home/pokemon.asm — [wCurSpecies] → wMonHeader
extern FillMemory                      ; home/fill_memory.asm — ESI=dest, BX=count, AL=fill
extern text_row_stride                 ; home/text.asm — active W_TILEMAP row stride

T_SPACE     equ 0x7F                   ; pret ' ' (charmap $7F blank tile)

; ---------------------------------------------------------------------------
; PrintMonType — pret print_type.asm:PrintMonType. Prints the loaded mon's
; type name(s): type1 at ESI, type2 two rows below — or erases the "TYPE2/"
; label (EraseType2Text) when the mon has a single type.
; In: [wCurSpecies] = species id, ESI = type1 dest tilemap offset.
;
; DEVIATION{class=banking; pret=engine/battle/print_type.asm:PrintMonType; behavior=callers invoke PrintMonType directly with ESI instead of using the banked predef dispatcher; evidence=pret predef call sites plus flat DOS build with no predef table; lifetime=permanent flat DOS build}
; pret opens with `call GetPredefRegisters` to recover HL from the predef
; frame; the port has no predef table, so the destination arrives in ESI.
;
; pret's SCREEN_WIDTH*2 row step is taken from the runtime [text_row_stride]
; (20 menu scratch / 40 flat canvas) — same stride generalization as the
; DrawHP family (status_screen.asm); StatusScreen runs this at stride 40.
; ---------------------------------------------------------------------------
PrintMonType:
    ; call GetPredefRegisters — predef plumbing, collapsed in the flat port
    push esi                            ; push hl
    call GetMonHeader                   ; fills wMonHType1/2 from [wCurSpecies]
    pop esi                             ; pop hl
    push esi                            ; push hl
    mov al, [ebp + wMonHType1]          ; ld a, [wMonHType1]
    call PrintType                      ; type1 name (PlaceString clobbers ESI)
    mov al, [ebp + wMonHType1]          ; ld a, [wMonHType1]
    mov bh, al                          ; ld b, a
    mov al, [ebp + wMonHType2]          ; ld a, [wMonHType2]
    cmp al, bh                          ; cp b — ZF = single-typed
    pop esi                             ; pop hl (pop preserves flags)
    je EraseType2Text                   ; jr z, EraseType2Text
    mov ecx, [text_row_stride]          ; ld bc, SCREEN_WIDTH * 2
    lea esi, [esi + ecx * 2]            ; add hl, bc — type2 two rows down
    ; fall through into PrintType with AL = wMonHType2 (pret fallthrough)

; ---------------------------------------------------------------------------
; PrintType — pret print_type.asm:PrintType. In: AL = type id, ESI = dest.
; (pret pushes hl and jumps to PrintType_, which pops it back before PlaceString;
; the port keeps the destination in ESI throughout, so the push/pop pair is not
; needed and PrintType is a bare jump to the shared tail.)
; ---------------------------------------------------------------------------
PrintType:
    jmp PrintType_                      ; pret: push hl / jr PrintType_

; ---------------------------------------------------------------------------
; EraseType2Text — pret print_type.asm:EraseType2Text. Blanks the 6-tile
; "TYPE2/" label when the mon has one type. In: ESI = type1 dest.
; pret's $13 displacement is SCREEN_WIDTH - 1 (one row down, one column left);
; the port takes it from the runtime stride so the same routine is correct on
; the 20-wide menu scratch and the 40-wide flat canvas.
; ---------------------------------------------------------------------------
EraseType2Text:
    mov al, T_SPACE                     ; ld a, ' '
    mov ecx, [text_row_stride]          ; ld bc, $13 (= SCREEN_WIDTH - 1)
    lea esi, [esi + ecx - 1]            ; add hl, bc
    mov bx, 6                           ; ld bc, $6
    jmp FillMemory                      ; jp FillMemory (tail call)

; ---------------------------------------------------------------------------
; PrintMoveType — pret print_type.asm:PrintMoveType. Prints the name of the
; CURRENT move's type (wPlayerMoveType, set by GetCurrentMove) at ESI.
; In: ESI = dest tilemap offset. EBP = GB base.  (pret: `call GetPredefRegisters`
; then `ld a, [wPlayerMoveType]`, falling through into PrintType_.)
; ---------------------------------------------------------------------------
PrintMoveType:
    mov al, [ebp + wPlayerMoveType]
    ; fall through into PrintType_ (pret fallthrough)

; ---------------------------------------------------------------------------
; PrintType_ — pret print_type.asm:PrintType_, the shared tail. AL = type id.
; ---------------------------------------------------------------------------
PrintType_:
    movzx ecx, al
    mov eax, [WideTypeNames + ecx * 4]  ; ld hl,TypeNames / add a / add hl,de / deref
    jmp PlaceString                     ; pret: jp PlaceString (tail call)
