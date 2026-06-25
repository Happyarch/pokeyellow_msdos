; remove_mon.asm — _RemovePokemon (Pokémon data/stats plan, Stage 5 tail).
;
; Source: home/move_mon.asm:RemovePokemon -> _RemovePokemon (pret/pokeyellow).
;
; Removes the mon at [wWhichPokemon] from the party (wRemoveMonFromBox == 0) or
; current box (!= 0), shifting every subsequent species/OT/struct/nick entry up
; one slot. Faithful to the original, including its documented quirk: when the
; last mon is removed only the species-list terminator is rewritten (the stale
; nick/struct bytes are left untouched, which is harmless — the species list
; decides which slots are live).
;
; Register map: a=AL, b=BH, c=BL (bc=EBX), d=DH, e=DL (de=EDX), hl=ESI.
; GB memory at [EBP+addr]. Helper contracts (must match the home routines):
;   SkipFixedLengthTextEntries: in AL=count, ESI=base; out ESI += NAME_LENGTH*AL.
;   AddNTimes:                  in AL=count, BX=stride, ESI=base; out ESI += AL*BX.
;   CopyDataUntil:              in ESI=src, EDX=dst, BX=end-of-src (exclusive).
; The original passes these strides/end-pointers in bc, so they go in BX here —
; the draft's use of ECX was a bug (the helpers read BX, ignoring ECX).
;
; Build: nasm -f coff -I include/ -I . -o remove_mon.o remove_mon.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

global _RemovePokemon

extern SkipFixedLengthTextEntries
extern CopyDataUntil
extern AddNTimes

section .text

_RemovePokemon:
    mov esi, wPartyCount
    mov al, [ebp + wRemoveMonFromBox]
    and al, al
    jz .gotCount
    mov esi, wBoxCount
.gotCount:
    mov al, [ebp + esi]
    dec al
    mov [ebp + esi], al              ; ld [hli], a (write decremented count)
    inc esi                          ; esi -> species list

    movzx ecx, byte [ebp + wWhichPokemon]   ; ld c,a / ld b,0
    add esi, ecx                     ; add hl, bc -> &species[which]
    mov edx, esi                     ; ld e,l / ld d,h
    inc edx                          ; inc de -> &species[which+1]

.shiftMonSpeciesLoop:
    mov al, [ebp + edx]
    inc edx
    mov [ebp + esi], al              ; ld [hli], a
    inc esi
    inc al                           ; reached terminator (0xFF)?
    jnz .shiftMonSpeciesLoop

    mov esi, wPartyMonOT
    mov dh, PARTY_LENGTH - 1         ; max mon index to shift
    mov al, [ebp + wRemoveMonFromBox]
    and al, al
    jz .gotOTsPointer
    mov esi, wBoxMonOT
    mov dh, MONS_PER_BOX - 1
.gotOTsPointer:
    mov al, [ebp + wWhichPokemon]
    call SkipFixedLengthTextEntries  ; esi -> &OT[which]

    mov al, [ebp + wWhichPokemon]
    cmp al, dh                       ; removing the last mon?
    jnz .notRemovingLastMon

    ; quirk (pret): should be '@' to blank the string, but only $ff is written;
    ; harmless since wPartySpecies/wBoxSpecies decide which slots are used.
    mov byte [ebp + esi], 0xFF
    ret

.notRemovingLastMon:
    mov edx, esi                     ; de = &OT[which] (dest)
    add esi, NAME_LENGTH             ; hl = &OT[which+1] (src); ld bc,NAME_LENGTH/add hl,bc
    mov bx, wPartyMonNicks           ; bc = end-of-OT region
    mov al, [ebp + wRemoveMonFromBox]
    and al, al
    jz .gotNicksPointer
    mov bx, wBoxMonNicks
.gotNicksPointer:
    call CopyDataUntil               ; shift OT names up one slot

    mov esi, wPartyMons
    mov bx, PARTYMON_STRUCT_LENGTH
    mov al, [ebp + wRemoveMonFromBox]
    and al, al
    jz .gotMonStructs
    mov esi, wBoxMons
    mov bx, BOXMON_STRUCT_LENGTH
.gotMonStructs:
    mov al, [ebp + wWhichPokemon]
    call AddNTimes                   ; esi -> &mon[which]

    mov edx, esi                     ; de = &mon[which] (dest)
    mov al, [ebp + wRemoveMonFromBox]
    and al, al
    jz .copyUntilPartyMonOT
    add esi, BOXMON_STRUCT_LENGTH    ; hl = &mon[which+1]
    mov bx, wBoxMonOT                ; bc = end-of-structs region
    jmp .shiftOTs
.copyUntilPartyMonOT:
    add esi, PARTYMON_STRUCT_LENGTH  ; hl = &mon[which+1]
    mov bx, wPartyMonOT
.shiftOTs:
    call CopyDataUntil               ; shift mon structs up one slot

    mov esi, wPartyMonNicks
    mov al, [ebp + wRemoveMonFromBox]
    and al, al
    jz .gotNicksPointer2
    mov esi, wBoxMonNicks
.gotNicksPointer2:
    mov bx, NAME_LENGTH
    mov al, [ebp + wWhichPokemon]
    call AddNTimes                   ; esi -> &nick[which]

    mov edx, esi                     ; de = &nick[which] (dest)
    add esi, NAME_LENGTH             ; hl = &nick[which+1] (src)
    mov bx, wPartyMonNicksEnd        ; bc = end-of-nicks region
    mov al, [ebp + wRemoveMonFromBox]
    and al, al
    jz .shiftMonNicks
    mov bx, wBoxMonNicksEnd
.shiftMonNicks:
    jmp CopyDataUntil                ; shift nicknames up one slot
