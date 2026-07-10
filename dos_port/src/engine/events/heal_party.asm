; heal_party.asm — HealParty (pret engine/events/heal_party.asm).
;
; Restores every party mon's HP (= MaxHP) and PP (= each move's base PP, keeping
; the PP-Up bits), clears status, then re-applies the PP-Up bonuses via
; RestoreBonusPP. Reached from ResetStatusAndHalveMoneyOnBlackout's
; `predef_jump HealParty` tail (engine/events/black_out.asm) — i.e. this is what
; makes a blackout leave the player with a healed party. Also the Pokémon Center
; heal once that script lands.
;
; Register map (CLAUDE.md): A→AL, HL→ESI, BC→BX (B=BH, C=BL), DE→EDX;
; EBP = GB memory base; GB memory = [ebp + offset].
;
; ADDRESS-SPACE NOTE: pret's `hl` is used for two different things here — GB WRAM
; offsets (party structs) and a flat pointer into the `Moves` table. In the port
; those are distinct address spaces ([ebp+esi] vs [esi]), so ESI is saved around
; the Moves lookup and the table is read flat.
;
; DIVERGENCE (flat ROM, port-wide): pret copies the 6-byte move record into
; wMoveData with `ld a, BANK(Moves) / call FarCopyData` and then reads
; [wMoveData + MOVE_PP]. The port's `Moves` is a flat program-image label with no
; ROM bank, so the base-PP byte is read straight out of the table — the same
; documented divergence already carried by engine/pokemon/write_moves.asm
; (LoadMovePPs) and engine/pokemon/get_max_pp.asm. AddNTimes is retained: it is
; pure pointer arithmetic (ESI += AL*BX) and works on the flat pointer unchanged.
;
; Build: nasm -f coff -I include/ -I . -o heal_party.o heal_party.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

global HealParty

extern AddNTimes            ; home/array.asm (ESI += AL*BX; preserves BX)
extern Moves                ; data/moves.asm — flat move-data table
extern RestoreBonusPP       ; engine/items/item_effects.asm

section .text

; ---------------------------------------------------------------------------
; HealParty — pret engine/events/heal_party.asm:HealParty
; Clobbers AL, EBX, ECX, EDX, ESI.
; ---------------------------------------------------------------------------
HealParty:
    mov esi, wPartySpecies                   ; ld hl, wPartySpecies
    mov edx, wPartyMon1 + MON_HP             ; ld de, wPartyMon1HP
.healmon:
    mov al, [ebp + esi]                      ; ld a,[hli]
    inc esi
    cmp al, 0xFF                             ; end of the party list?
    je .done                                 ; jr z, .done

    push esi                                 ; push hl (species cursor)
    push edx                                 ; push de (this mon's HP ptr)

    ; clear status
    lea esi, [edx + MON_STATUS - MON_HP]     ; ld hl, MON_STATUS-MON_HP / add hl,de
    mov byte [ebp + esi], 0                  ; xor a / ld [hl],a

    push edx                                 ; push de — restored after the PP loop
    mov bh, NUM_MOVES                        ; ld b, NUM_MOVES
.pp:
    lea esi, [edx + MON_MOVES - MON_HP]      ; ld hl, MON_MOVES-MON_HP / add hl,de
    mov al, [ebp + esi]                      ; ld a,[hl] — move id
    test al, al
    jz .nextmove                             ; empty slot → nothing to restore
    dec al                                   ; move id - 1 = table index

    lea esi, [edx + MON_PP - MON_HP]         ; ld hl, MON_PP-MON_HP / add hl,de
    push esi                                 ; push hl (PP slot, GB offset)
    push edx                                 ; push de
    push ebx                                 ; push bc

    ; base PP = Moves[(id-1) * MOVE_LENGTH + MOVE_PP], read flat (see header)
    mov esi, Moves                           ; ld hl, Moves (FLAT pointer)
    mov bx, MOVE_LENGTH                      ; ld bc, MOVE_LENGTH
    call AddNTimes                           ; ESI += (id-1) * MOVE_LENGTH
    mov al, [esi + MOVE_PP]                  ; flat read (pret: FarCopyData → wMoveData)

    pop ebx                                  ; pop bc
    pop edx                                  ; pop de
    pop esi                                  ; pop hl (PP slot)

    inc edx                                  ; inc de — advance to the next move slot
    push ebx                                 ; push bc
    mov bl, al                               ; ld b, a — base PP
    mov al, [ebp + esi]                      ; ld a,[hl] — current PP byte
    and al, PP_UP_MASK                       ; keep only the PP-Up bits
    add al, bl                               ; add b
    mov [ebp + esi], al                      ; ld [hl],a
    pop ebx                                  ; pop bc

.nextmove:
    dec bh                                   ; dec b
    jnz .pp
    pop edx                                  ; pop de — back to this mon's HP ptr

    ; HP = MaxHP (big-endian: high byte first — GB data order, do not swap)
    lea esi, [edx + MON_MAXHP - MON_HP]      ; ld hl, MON_MAXHP-MON_HP / add hl,de
    mov al, [ebp + esi]                      ; ld a,[hli] — MaxHP high
    inc esi
    mov [ebp + edx], al                      ; ld [de],a  — HP high
    inc edx                                  ; inc de
    mov al, [ebp + esi]                      ; ld a,[hl]  — MaxHP low
    mov [ebp + edx], al                      ; ld [de],a  — HP low

    pop edx                                  ; pop de (this mon's HP ptr, pre-inc)
    pop esi                                  ; pop hl (species cursor)

    add edx, PARTYMON_STRUCT_LENGTH          ; de += 44 → next mon's HP ptr
    jmp .healmon

.done:
    xor al, al
    mov [ebp + wWhichPokemon], al
    mov [ebp + wUsingPPUp], al               ; 0 => RestoreBonusPP touches every move

    mov al, [ebp + wPartyCount]
    mov bh, al                               ; ld b, a
.ppup:
    push ebx                                 ; push bc
    call RestoreBonusPP
    pop ebx                                  ; pop bc
    inc byte [ebp + wWhichPokemon]           ; ld hl, wWhichPokemon / inc [hl]
    dec bh
    jnz .ppup
    ret
