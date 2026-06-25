; set_types.asm — SetPartyMonTypes (Pokémon data/stats plan, Stage 5 tail).
;
; Source: engine/pokemon/set_types.asm:SetPartyMonTypes (pret/pokeyellow).
;
; Updates the two type bytes of a party mon (pointed to by HL/ESI) to the types
; of the species in [wPokedexNum]. Normally invoked via `predef SetPartyMonTypes`
; with HL = &partymon; GetPredefRegisters restores HL from wPredefHL.
;
; Register map: a=AL, bc=EBX, hl=ESI; GB memory at [EBP+addr]. MON_TYPE is a
; struct field offset (gb_constants.inc), not a GB address.
;
; Build: nasm -f coff -I include/ -I . -o set_types.o set_types.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

global SetPartyMonTypes

extern GetPredefRegisters
extern GetMonHeader

section .text

SetPartyMonTypes:
    call GetPredefRegisters          ; ESI (hl) = &partymon (from wPredefHL)
    lea esi, [esi + MON_TYPE]        ; ld bc, MON_TYPE / add hl, bc
    mov al, [ebp + wPokedexNum]
    mov [ebp + wCurSpecies], al
    push esi
    call GetMonHeader
    pop esi
    mov al, [ebp + wMonHType1]
    mov [ebp + esi], al              ; ld [hli], a
    inc esi
    mov al, [ebp + wMonHType2]
    mov [ebp + esi], al              ; ld [hl], a
    ret
