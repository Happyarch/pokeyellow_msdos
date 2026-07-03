; dos_port/src/engine/pokemon/bills_pc.asm
; Bill's PC: deposit / withdraw / release backend.
;
; Source: engine/pokemon/bills_pc.asm (pret/pokeyellow).
; PC menu (UI) is deferred; only the data-manipulation backend is translated.
;
; KnowsHMMove (+ HMMoveArray) has been split out to knows_hm_move.asm so it links
; independently of this file's still-blocked _MoveMon draft closure.
;
; Register map: A=AL, B=BH, C=BL (BC=EBX), D=DH, E=DL (DE=EDX), HL=ESI.
; GB memory at [EBP+addr]; flat program-image tables read via [label] or [esi]
; (never [ebp+label]).
;
; Externs resolved:
;   _MoveMon       → dos_port/src/engine/pokemon/add_mon.asm:_MoveMon
;   _RemovePokemon → dos_port/src/engine/pokemon/remove_mon.asm:_RemovePokemon

bits 32

%include "gb_macros.inc"
%include "gb_memmap.inc"
%include "gb_constants.inc"

section .text

global BillsPCDepositLogic
global BillsPCWithdrawLogic
global BillsPCReleaseLogic

extern _MoveMon
extern _RemovePokemon

; wMoveMonType/wRemoveMonFromBox values (constants/pokemon_data_constants.asm).
; Both live at the same WRAM address (wMoveMonType = wRemoveMonFromBox = $CF94).
; Not in the shared .inc files; defined locally.
%define BOX_TO_PARTY  0
%define PARTY_TO_BOX  1

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
