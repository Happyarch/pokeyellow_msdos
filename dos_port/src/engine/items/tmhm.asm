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
extern PrintText            ; ESI = text pointer
; _AlreadyKnowsText (the far text stream in data/text/text_9.asm) has no
; implementation in the tree and would halt a link. Commented out; AlreadyKnowsText
; below is a placeholder empty text until it's ported.
; TODO(unimplemented): extern _AlreadyKnowsText

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
    mov esi, AlreadyKnowsText           ; ld hl, AlreadyKnowsText
    call PrintText
    stc                                 ; scf
    ret

AlreadyKnowsText:
    ; TODO(unimplemented): text_far _AlreadyKnowsText  ("<MON> knows <MOVE>!")
    text_end
