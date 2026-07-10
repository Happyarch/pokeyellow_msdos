; dos_port/engine/pokemon/add_mon.asm — _AddEnemyMonToPlayerParty + _MoveMon.
;
; Source: engine/pokemon/add_mon.asm:_AddEnemyMonToPlayerParty, _MoveMon
;         (pret/pokeyellow). pret's _AddPartyMon half (and its
;         AddPartyMon_WriteMovePP PP helper) live in add_party_mon.asm in this
;         port; this file carries only the trade / box-move halves.
;
; DUP-SYMBOL RESOLUTION (M5.2): this file previously carried a stale, DIFFERENT
; `global AddPartyMon_WriteMovePP` (dest in EDI, FarCopyData→wMoveData) that
; duplicated the canonical global in write_moves.asm and the file-local copy in
; add_party_mon.asm. It was unreferenced here (pret's only caller, _AddPartyMon,
; is in add_party_mon.asm) so it is DELETED — dedup, not rename. The canonical
; PP writer stays in write_moves.asm.
;
; Register map: a=AL, b=BH, c=BL (bc=EBX), d=DH, e=DL (de=EDX), hl=ESI.
; GB WRAM is [ebp + sym]; data tables are flat program-image labels.
;
; Gen-2 forward-compat: every party↔box / enemy→party copy moves the FULL
; BOXMON_STRUCT_LENGTH (33) bytes in one CopyData, carrying struct offset 7
; (MON_CATCH_RATE / held item) through verbatim — see CLAUDE.md.
;
; Build: nasm -f coff -I include/ -I . -o add_mon.o add_mon.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

global _AddEnemyMonToPlayerParty
global _MoveMon

extern AddNTimes
extern CopyData
extern SkipFixedLengthTextEntries
extern FlagAction
extern IndexToPokedex
extern LoadMonData
extern CalcLevelFromExperience
extern CalcStats

section .text

_AddEnemyMonToPlayerParty:
    mov esi, wPartyCount
    mov al, [ebp + esi]
    cmp al, PARTY_LENGTH
    jz .partyFull
    
    inc al
    mov [ebp + esi], al
    mov cl, al
    movzx ecx, cl
    mov edx, esi
    add edx, ecx
    
    mov al, [ebp + wCurPartySpecies]
    mov [ebp + edx], al
    inc edx
    mov byte [ebp + edx], 0xff
    
    mov esi, wPartyMons
    mov al, [ebp + wPartyCount]
    dec al
    mov bx, PARTYMON_STRUCT_LENGTH
    call AddNTimes
    
    mov edx, esi
    mov esi, wLoadedMon
    mov bx, PARTYMON_STRUCT_LENGTH
    call CopyData
    
    mov esi, wPartyMonOT
    mov al, [ebp + wPartyCount]
    dec al
    call SkipFixedLengthTextEntries
    mov edx, esi
    
    mov esi, wEnemyMonOT
    mov al, [ebp + wWhichPokemon]
    call SkipFixedLengthTextEntries
    mov bx, NAME_LENGTH
    call CopyData
    
    mov esi, wPartyMonNicks
    mov al, [ebp + wPartyCount]
    dec al
    call SkipFixedLengthTextEntries
    mov edx, esi
    
    mov esi, wEnemyMonNicks
    mov al, [ebp + wWhichPokemon]
    call SkipFixedLengthTextEntries
    mov bx, NAME_LENGTH
    call CopyData
    
    ; pret does `predef IndexToPokedex` (species in wd11e → dex# in wd11e). In the
    ; PORT, IndexToPokedex is a flat DATA TABLE (byte[species-1]=national dex#), NOT
    ; a routine — index it directly. Calling it as code jumps into .data → page fault.
    movzx eax, byte [ebp + wCurPartySpecies]
    dec eax
    movzx eax, byte [IndexToPokedex + eax]  ; dex number (1-based)
    dec eax                             ; dex bit index (0-based)
    mov cl, al
    mov bh, FLAG_SET                    ; pret `ld b, FLAG_SET` (B=BH); FlagAction reads action in BH
    mov esi, wPokedexOwned
    push cx
    push bx
    call FlagAction
    pop bx
    pop cx
    mov esi, wPokedexSeen
    call FlagAction
    
    clc
    ret

.partyFull:
    stc
    ret

_MoveMon:
    mov al, [ebp + wMoveMonType]
    test al, al ; BOX_TO_PARTY
    jz .checkPartyMonSlots
    cmp al, DAYCARE_TO_PARTY
    jz .checkPartyMonSlots
    cmp al, PARTY_TO_DAYCARE
    mov esi, wDayCareMon
    jz .findMonDataSrc
    
    ; PARTY_TO_BOX
    mov esi, wBoxCount
    mov al, [ebp + esi]
    cmp al, MONS_PER_BOX
    jnz .partyOrBoxNotFull
    jmp .boxFull
    
.checkPartyMonSlots:
    mov esi, wPartyCount
    mov al, [ebp + esi]
    cmp al, PARTY_LENGTH
    jnz .partyOrBoxNotFull

.boxFull:
    stc
    ret

.partyOrBoxNotFull:
    inc al
    mov [ebp + esi], al
    mov cl, al
    movzx ecx, cl
    mov edx, esi
    add edx, ecx
    
    mov al, [ebp + wMoveMonType]
    cmp al, DAYCARE_TO_PARTY
    mov al, [ebp + wDayCareMon]
    jz .copySpecies
    mov al, [ebp + wCurPartySpecies]
.copySpecies:
    mov [ebp + edx], al
    inc edx
    mov byte [ebp + edx], 0xff
    
    mov al, [ebp + wMoveMonType]
    dec al
    mov esi, wPartyMons
    mov bx, PARTYMON_STRUCT_LENGTH
    mov al, [ebp + wPartyCount]
    jnz .addMonOffset
    
    mov esi, wBoxMons
    mov bx, BOXMON_STRUCT_LENGTH
    mov al, [ebp + wBoxCount]
.addMonOffset:
    dec al
    call AddNTimes
    
.findMonDataSrc:
    push esi
    mov edx, esi
    mov al, [ebp + wMoveMonType]
    test al, al
    mov esi, wBoxMons
    mov bx, BOXMON_STRUCT_LENGTH
    jz .addMonOffset2
    
    cmp al, DAYCARE_TO_PARTY
    mov esi, wDayCareMon
    jz .copyMonData
    
    mov esi, wPartyMons
    mov bx, PARTYMON_STRUCT_LENGTH
.addMonOffset2:
    mov al, [ebp + wWhichPokemon]
    call AddNTimes
    
.copyMonData:
    push esi
    push dx
    mov bx, BOXMON_STRUCT_LENGTH
    call CopyData
    pop dx
    pop esi
    
    mov al, [ebp + wMoveMonType]
    test al, al
    jz .findOTdest
    cmp al, DAYCARE_TO_PARTY
    jz .findOTdest
    
    mov eax, BOXMON_STRUCT_LENGTH        ; ld bc,BOXMON_STRUCT_LENGTH (const)
    add esi, eax
    mov al, [ebp + esi] ; Level
    
    add edx, 3
    mov [ebp + edx], al
    
.findOTdest:
    mov al, [ebp + wMoveMonType]
    cmp al, PARTY_TO_DAYCARE
    mov edx, wDayCareMonOT
    jz .findOTsrc
    
    dec al
    mov esi, wPartyMonOT
    mov al, [ebp + wPartyCount]
    jnz .addOToffset
    mov esi, wBoxMonOT
    mov al, [ebp + wBoxCount]
.addOToffset:
    dec al
    call SkipFixedLengthTextEntries
    mov edx, esi

.findOTsrc:
    mov esi, wBoxMonOT
    mov al, [ebp + wMoveMonType]
    test al, al
    jz .addOToffset2
    
    mov esi, wDayCareMonOT
    cmp al, DAYCARE_TO_PARTY
    jz .copyOT
    mov esi, wPartyMonOT
.addOToffset2:
    mov al, [ebp + wWhichPokemon]
    call SkipFixedLengthTextEntries
.copyOT:
    mov bx, NAME_LENGTH
    call CopyData
    
    mov al, [ebp + wMoveMonType]
    cmp al, PARTY_TO_DAYCARE
    mov edx, wDayCareMonName
    jz .findNickSrc
    
    dec al
    mov esi, wPartyMonNicks
    mov al, [ebp + wPartyCount]
    jnz .addNickOffset
    
    mov esi, wBoxMonNicks
    mov al, [ebp + wBoxCount]
.addNickOffset:
    dec al
    call SkipFixedLengthTextEntries
    mov edx, esi
    
.findNickSrc:
    mov esi, wBoxMonNicks
    mov al, [ebp + wMoveMonType]
    test al, al
    jz .addNickOffset2
    
    mov esi, wDayCareMonName
    cmp al, DAYCARE_TO_PARTY
    jz .copyNick
    mov esi, wPartyMonNicks
.addNickOffset2:
    mov al, [ebp + wWhichPokemon]
    call SkipFixedLengthTextEntries
.copyNick:
    mov bx, NAME_LENGTH
    call CopyData
    
    pop esi ; was saved at start of findMonDataSrc
    mov al, [ebp + wMoveMonType]
    cmp al, PARTY_TO_BOX
    jz .done
    cmp al, PARTY_TO_DAYCARE
    jz .done
    
    push esi
    shr al, 1
    add al, 2
    mov [ebp + wMonDataLocation], al
    call LoadMonData
    call CalcLevelFromExperience
    mov al, dh
    mov [ebp + wCurEnemyLevel], al
    pop esi
    
    mov ecx, BOXMON_STRUCT_LENGTH        ; ld bc,BOXMON_STRUCT_LENGTH (const)
    add esi, ecx
    mov [ebp + esi], al
    inc esi
    
    mov edx, esi
    
    mov ecx, (MON_HP_EXP - 1) - MON_STATS ; ld bc,-0x12 (sign-ext = 16-bit add hl,bc)
    add esi, ecx
    mov bl, 1
    call CalcStats
    
.done:
    clc
    ret
