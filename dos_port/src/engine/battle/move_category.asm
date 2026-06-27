; move_category.asm — physical/special category predicate.
;
; Gen-1 has no per-move category field: a move is SPECIAL iff its type id is
; >= SPECIAL ($14), else PHYSICAL. The battle damage path
; (core_damage.asm:GetDamageVarsForPlayer/EnemyAttack) keeps this comparison
; inline — faithful to pret's `cp SPECIAL` / `jr nc`. These helpers expose the
; same test to menu/query callers (e.g. a move-list display) that hold a move or
; type id but aren't in the damage pipeline.
;
; Build: nasm -f coff -I include/ -I . -o move_category.o move_category.asm

bits 32

%include "gb_constants.inc"

global IsTypeSpecial
global IsMoveSpecial

extern Moves

section .text

; ---------------------------------------------------------------------------
; IsTypeSpecial — AL = type id.
;   Out: special  → AL = 1, CF = 1
;        physical → AL = 0, CF = 0
; ---------------------------------------------------------------------------
IsTypeSpecial:
    cmp al, SPECIAL
    jae .special
    xor al, al
    clc
    ret
.special:
    mov al, 1
    stc
    ret

; ---------------------------------------------------------------------------
; IsMoveSpecial — AL = move id (1-based). Reads the move's MOVE_TYPE from the
;   flat Moves table, then IsTypeSpecial. Clobbers ECX, ESI.
; ---------------------------------------------------------------------------
IsMoveSpecial:
    dec al
    movzx ecx, al
    imul ecx, ecx, MOVE_LENGTH
    mov esi, Moves
    movzx eax, byte [esi + ecx + MOVE_TYPE]
    jmp IsTypeSpecial
