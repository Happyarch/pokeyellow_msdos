; dos_port/src/engine/pokemon/bills_pc.asm
; Bill's PC: deposit / withdraw / release backend + KnowsHMMove.
;
; Source: engine/pokemon/bills_pc.asm (pret/pokeyellow).
; PC menu (UI) is deferred; only the data-manipulation backend is translated.
;
; Register map: A=AL, B=BH, C=BL (BC=EBX), D=DH, E=DL (DE=EDX), HL=ESI.
; GB memory at [EBP+addr]; flat program-image tables read via [label] or [esi]
; (never [ebp+label]).
;
; Externs resolved:
;   _MoveMon       → dos_port/src/engine/pokemon/add_mon.asm:_MoveMon
;   _RemovePokemon → dos_port/src/engine/pokemon/remove_mon.asm:_RemovePokemon
;
; IsInArray is now the shared home global in src/home/array.asm (same faithful
; flat-read semantics: AL=value, ESI=array, EDX=stride → CF=found, BH=index).
; KnowsHMMove already sets EDX=1 and saves ESI/EBX around the call.

bits 32

%include "gb_macros.inc"
%include "gb_memmap.inc"
%include "gb_constants.inc"

section .text

global KnowsHMMove
global BillsPCDepositLogic
global BillsPCWithdrawLogic
global BillsPCReleaseLogic

extern _MoveMon
extern _RemovePokemon
extern IsInArray                ; src/home/array.asm (shared home global)

; wMoveMonType/wRemoveMonFromBox values (constants/pokemon_data_constants.asm).
; Both live at the same WRAM address (wMoveMonType = wRemoveMonFromBox = $CF94).
; Not in the shared .inc files; defined locally.
%define BOX_TO_PARTY  0
%define PARTY_TO_BOX  1

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
; BillsPCDepositLogic
; Backend for depositing the party mon at [wWhichPokemon] into the current box.
; Sets wMoveMonType = PARTY_TO_BOX, calls _MoveMon (copy party→box),
; sets wRemoveMonFromBox = 0, calls _RemovePokemon (remove from party).
;
; MON_CATCH_RATE (struct offset 7, Gen-2 held-item slot) is preserved verbatim
; because _MoveMon copies all BOXMON_STRUCT_LENGTH (33) bytes of the party struct
; into the box entry unchanged.
;
; Inputs (WRAM): wWhichPokemon = party slot; wPartyCount, wBoxCount current.
; Returns: C clear on success; C set if party has only 1 mon, or box is full.
; ---------------------------------------------------------------------------
BillsPCDepositLogic:
    mov al, byte [ebp + wPartyCount]
    dec al
    jz .fail                        ; only 1 mon left — can't deposit last mon

    mov al, byte [ebp + wBoxCount]
    cmp al, MONS_PER_BOX
    je .fail                        ; box is full

    ; copy party[wWhichPokemon] → box, add to box species list, update wBoxCount
    mov byte [ebp + wMoveMonType], PARTY_TO_BOX
    call _MoveMon

    ; shift party entries up, decrement wPartyCount
    mov byte [ebp + wRemoveMonFromBox], 0   ; 0 = operate on party
    call _RemovePokemon

    clc
    ret
.fail:
    stc
    ret

; ---------------------------------------------------------------------------
; BillsPCWithdrawLogic
; Backend for withdrawing the box mon at [wWhichPokemon] into the party.
; Sets wMoveMonType = BOX_TO_PARTY, calls _MoveMon (copy box→party, recompute
; stats via CalcStats/CalcLevelFromExperience inside _MoveMon's BOX_TO_PARTY
; branch), sets wRemoveMonFromBox = 1, calls _RemovePokemon (remove from box).
;
; MON_CATCH_RATE (struct offset 7) is preserved: _MoveMon copies BOXMON_STRUCT_LENGTH
; bytes into the new party slot unchanged before the stat recompute overwrites
; only MON_STATS (offsets $22–$2B).
;
; Inputs (WRAM): wWhichPokemon = box slot; wBoxCount, wPartyCount current.
; Returns: C clear on success; C set if box is empty or party is full.
; ---------------------------------------------------------------------------
BillsPCWithdrawLogic:
    mov al, byte [ebp + wBoxCount]
    test al, al
    jz .fail                        ; box is empty

    mov al, byte [ebp + wPartyCount]
    cmp al, PARTY_LENGTH
    je .fail                        ; party is full

    ; copy box[wWhichPokemon] → party, rebuild party struct, recompute stats
    mov byte [ebp + wMoveMonType], BOX_TO_PARTY
    call _MoveMon

    ; shift box entries up, decrement wBoxCount
    mov byte [ebp + wRemoveMonFromBox], 1   ; 1 = operate on box
    call _RemovePokemon

    clc
    ret
.fail:
    stc
    ret

; ---------------------------------------------------------------------------
; BillsPCReleaseLogic
; Backend for releasing (permanently discarding) the box mon at [wWhichPokemon].
; Only calls _RemovePokemon — no copy is needed.
;
; Inputs (WRAM): wWhichPokemon = box slot; wBoxCount current.
; Returns: C clear on success; C set if box is empty.
; ---------------------------------------------------------------------------
BillsPCReleaseLogic:
    mov al, byte [ebp + wBoxCount]
    test al, al
    jz .fail                        ; box is empty

    mov byte [ebp + wRemoveMonFromBox], 1   ; 1 = operate on box
    call _RemovePokemon

    clc
    ret
.fail:
    stc
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
