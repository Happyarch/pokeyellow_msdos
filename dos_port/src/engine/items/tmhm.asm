; tmhm.asm — faithful port of engine/items/tmhm.asm (pret).
; CheckIfMoveIsKnown: does the party mon in [wWhichPokemon] already know [wMoveNum]?
;
; Build: nasm -f coff -I include/ -I . -o /dev/null src/engine/items/tmhm.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_text.inc"

section .text

global CheckIfMoveIsKnown

extern AddNTimes            ; ESI += AL * BX; AL := 0  (hl += a*bc)
; AlreadyKnowsText ("<MON> knows <MOVE>!") is Tier-1 generated data — pret's
; text_far _AlreadyKnowsText (data/text/text_9.asm), flattened by tools/gen_item_text.py
; into assets/item_text.inc. <Label>_ref is its {dd stream, dd length} pair.
extern AlreadyKnowsText_ref     ; assets/item_text.inc
; CheckIfMoveIsKnown only runs out of battle (ItemUseTMHM refuses in-battle use), so
; its message goes through the item layer's overworld printer, not the battle box.
extern iu_print_text            ; item_effects.asm — ESI = flat stream, ECX = length

; wPartyMon1Moves = wPartyMon1 ($D16A) + MON_MOVES ($08) = $D172.

; ---------------------------------------------------------------------------
; CheckIfMoveIsKnown — CF set if the mon already knows the move (prints text).
; ---------------------------------------------------------------------------
CheckIfMoveIsKnown:
    mov al, [ebp + wWhichPokemon]
    mov esi, wPartyMon1 + MON_MOVES     ; ld hl, wPartyMon1Moves
    mov bx, PARTYMON_STRUCT_LENGTH      ; ld bc, PARTYMON_STRUCT_LENGTH
    call AddNTimes                      ; hl += [wWhichPokemon] * struct len
    mov al, [ebp + wMoveNum]
    mov bh, al                          ; ld b, a (move to match)
    mov bl, NUM_MOVES                   ; ld c, NUM_MOVES
.loop:
    mov al, [ebp + esi]                 ; ld a, [hli]
    inc esi
    cmp al, bh                          ; cp b
    je .alreadyKnown
    dec bl                              ; dec c
    jnz .loop
    and al, al                          ; and a — clear carry (not known)
    ret
.alreadyKnown:
    mov esi, [AlreadyKnowsText_ref]     ; ld hl, AlreadyKnowsText
    mov ecx, [AlreadyKnowsText_ref + 4]
    call iu_print_text
    stc                                 ; scf
    ret
