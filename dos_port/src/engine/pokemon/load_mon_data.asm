; load_mon_data.asm — LoadMonData_ / GetMonSpecies (Pokémon data/stats plan,
; Stage 5 tail).
;
; Source: engine/pokemon/load_mon_data.asm (pret/pokeyellow).
;
; Loads mon [wWhichPokemon] from list [wMonDataLocation] (0=party, 1=enemy party,
; 2=current box, 3=daycare) into wLoadedMon, and its base stats into wMonHeader
; (via GetMonHeader). Returns its species id in [wCurPartySpecies].
;
; Register map: a=AL, e=DL, hl=ESI, de=EDX, bc=EBX. GB memory at [EBP+addr].
; Note: the data-location dispatch relies on `mov` not touching EFLAGS (faithful
; to SM83 `ld hl, …` between `cp` and the conditional `jr`).
;
; Build: nasm -f coff -I include/ -I . -o load_mon_data.o load_mon_data.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

global LoadMonData
global LoadMonData_
global GetMonSpecies

extern GetMonHeader
extern AddNTimes
extern CopyData

section .text

; LoadMonData — pret home/pokemon.asm wrapper (predef LoadMonData): bank-switch + call
; LoadMonData_ + return. In the flat DPMI port there is no bank to switch, so it is a
; direct tail-call. Caller sets wWhichPokemon + wMonDataLocation. (Replaces the former
; no-op stub in battle_exp_stubs.asm, which left wLoadedMon stale for GainExperience.)
LoadMonData:
    jmp LoadMonData_

LoadMonData_:
    mov al, [ebp + wDayCareMonSpecies]
    mov [ebp + wCurPartySpecies], al
    mov al, [ebp + wMonDataLocation]
    cmp al, DAYCARE_DATA
    jz .GetMonHeader

    mov al, [ebp + wWhichPokemon]
    mov dl, al                       ; ld e, a
    call GetMonSpecies

.GetMonHeader:
    mov al, [ebp + wCurPartySpecies]
    mov [ebp + wCurSpecies], al
    call GetMonHeader

    mov esi, wPartyMons
    mov bx, PARTYMON_STRUCT_LENGTH
    mov al, [ebp + wMonDataLocation]
    cmp al, ENEMY_PARTY_DATA
    jc .getMonEntry                  ; location 0 (party)

    mov esi, wEnemyMons
    jz .getMonEntry                  ; location 1 (enemy party); flags from cp above

    cmp al, BOX_DATA
    mov esi, wBoxMons
    mov bx, BOXMON_STRUCT_LENGTH
    jz .getMonEntry                  ; location 2 (box); flags from cp BOX_DATA

    mov esi, wDayCareMon             ; location 3 (daycare)
    jmp .copyMonData

.getMonEntry:
    mov al, [ebp + wWhichPokemon]
    call AddNTimes

.copyMonData:
    mov edx, wLoadedMon
    mov bx, PARTYMON_STRUCT_LENGTH
    jmp CopyData

; get species of mon e (DL) in list [wMonDataLocation] for LoadMonData
GetMonSpecies:
    mov esi, wPartySpecies
    mov al, [ebp + wMonDataLocation]
    test al, al
    jz .getSpecies
    dec al
    jz .enemyParty
    mov esi, wBoxSpecies
    jmp .getSpecies
.enemyParty:
    mov esi, wEnemyPartySpecies
.getSpecies:
    movzx edx, dl                    ; ld d, 0 / add hl, de
    add esi, edx
    mov al, [ebp + esi]
    mov [ebp + wCurPartySpecies], al
    ret
