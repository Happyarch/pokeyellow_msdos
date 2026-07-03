; knows_hm_move.asm — KnowsHMMove + HMMoveArray (pret engine/pokemon/bills_pc.asm).
;
; Split out of bills_pc.asm so it LINKS independently of the (still-blocked) Bill's
; PC UI: KnowsHMMove is pure logic over IsInArray, whereas the rest of bills_pc.asm
; depends on the draft _MoveMon closure and stays check-only. Its caller is the
; daycare script (pret scripts/Daycare.asm:KnowsHMMove — "can't accept a mon that
; knows an HM"); once the daycare script is ported it can `call KnowsHMMove`.
;
; Register map: A=AL, B=BH, C=BL (BC=EBX), D=DH, E=DL (DE=EDX), HL=ESI.
; GB memory at [EBP+addr]; flat program-image tables read via [label]/[esi].
;
; IsInArray is the shared home global in src/home/array.asm (AL=value, ESI=array,
; EDX=stride → CF=found, BH=index).

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

section .text

global KnowsHMMove

extern IsInArray                ; src/home/array.asm (shared home global)

; ---------------------------------------------------------------------------
; KnowsHMMove
; Returns whether the party mon at index [wWhichPokemon] knows any HM move.
; Sets C flag if yes; clears C flag if no.
; Faithful to pret, including the dead wBoxMon1Moves branch below .next.
;
; Inputs (WRAM): wWhichPokemon = 0-based party slot index.
; Clobbers: EAX, ECX, EDX, ESI, EBX.
; ---------------------------------------------------------------------------
KnowsHMMove:
    mov esi, W_PARTY_MON1_MOVES     ; ld hl, wPartyMon1Moves ($D172)
    mov ecx, PARTYMON_STRUCT_LENGTH  ; ld bc, PARTYMON_STRUCT_LENGTH (44)
    jmp .next
    ; --- unreachable — pret-faithful dead code (mirrors the original binary) ---
    mov esi, W_BOX_MON1_MOVES       ; ld hl, wBoxMon1Moves ($DA9D)
    mov ecx, BOXMON_STRUCT_LENGTH   ; ld bc, BOXMON_STRUCT_LENGTH (33)
.next:
    ; AddNTimes equivalent: esi += wWhichPokemon * ecx (stride)
    movzx eax, byte [ebp + wWhichPokemon]   ; ld a,[wWhichPokemon]
    imul ecx, eax                            ; ecx = index × stride
    add esi, ecx                             ; esi → moves[wWhichPokemon]

    mov bh, NUM_MOVES               ; ld b, NUM_MOVES (4)
.loop:
    mov al, byte [ebp + esi]        ; ld a,[hli]  — read move id from GB mem
    inc esi                         ; (hli post-increment)

    push esi                        ; push hl  (save GB pointer)
    push ebx                        ; push bc  (save B=move-counter, C=scratch)

    lea esi, [HMMoveArray]          ; ld hl, HMMoveArray  — flat program address
    mov edx, 1                      ; ld de, 1  (stride = 1 byte)
    call IsInArray                  ; C set if AL found in HMMoveArray

    pop ebx                         ; pop bc
    pop esi                         ; pop hl

    jc .done                        ; ret c → jump to ret-with-carry

    dec bh                          ; dec b
    jnz .loop

    clc                             ; and a  (clear carry = not found)
.done:
    ret

; ---------------------------------------------------------------------------
section .data

; HM move list — searched by KnowsHMMove via IsInArray.
; Matches data/moves/hm_moves.asm (pret); terminated by $FF (-1).
; Move IDs from gb_constants.inc: CUT=$0F FLY=$13 SURF=$39 STRENGTH=$46 FLASH=$94
HMMoveArray:
    db CUT
    db FLY
    db SURF
    db STRENGTH
    db FLASH
    db -1       ; terminator ($FF / -1); matches pret's "db -1"
