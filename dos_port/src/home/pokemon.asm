; pokemon.asm — GetMonHeader / GetPartyMonName (Pokémon data/stats plan).
;
; Source: home/pokemon.asm:GetMonHeader, GetPartyMonName2, GetPartyMonName +
;         engine/menus/pokedex.asm:IndexToPokedex (pret/pokeyellow).
;
; GetMonHeader copies the 28-byte base-stats record for the internal species
; index in [wCurSpecies] into wMonHeader, then overwrites byte 0 (the dex id)
; with the internal index — matching the original.
;
; DIVERGENCE FROM GB: the data tables (BaseStats, IndexToPokedex) live in the
; program image as flat labels, not in EBP-relative GB memory, so we index them
; directly and `rep movsb` into [ebp+wMonHeader] instead of going through the
; GB CopyData/AddNTimes (which assume EBP-relative source).
;
; FOSSIL/GHOST GUARD (M5.2): pret GetMonHeader special-cases the three sprite-only
; indices FOSSIL_KABUTOPS ($B6), FOSSIL_AERODACTYL ($B7) and MON_GHOST ($B8) —
; they have NO BaseStats entry, so it skips the copy and instead writes the sprite
; dimensions + front-pic pointer into wMonHSpriteDim. Without this guard the port
; would index BaseStats out of bounds (dex lookup returns 0) and copy garbage. The
; front-pic pointer is written as 0 for now — the fossil/ghost battle sprites are
; not ported yet (no battle sprite loader); TODO-HW below.
;
; Build: nasm -f coff -I include/ -I . -o pokemon.o pokemon.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

extern BaseStats
extern IndexToPokedex
extern SkipFixedLengthTextEntries
extern CopyData
extern PrintNumber

global GetMonHeader
global GetPartyMonName
global GetPartyMonName2
global PrintLevel
global PrintLevelFull
global PrintLevelCommon

CHAR_LV        equ 0x6E     ; '<LV>' ":L" tile (constants/charmap.asm:67)

section .text

; copies the base-stat data of a pokemon to wMonHeader
; INPUT: [wCurSpecies] = internal species index
GetMonHeader:
    pushad

    movzx eax, byte [ebp + wCurSpecies]

    ; --- fossil/ghost special sprite IDs (pret GetMonHeader .specialID) ---
    cmp al, FOSSIL_KABUTOPS
    je .kabutops
    cmp al, MON_GHOST
    je .ghost
    cmp al, FOSSIL_AERODACTYL
    je .aerodactyl

    ; normal path: src = BaseStats + (dex - 1) * BASE_DATA_SIZE
    ; dex = IndexToPokedex[wCurSpecies - 1]   (internal index -> national dex)
    dec eax
    movzx eax, byte [IndexToPokedex + eax]
    dec eax
    imul eax, eax, BASE_DATA_SIZE
    lea esi, [BaseStats + eax]        ; flat (program-image) source
    lea edi, [ebp + wMonHeader]       ; flat dest in GB memory
    mov ecx, BASE_DATA_SIZE
    rep movsb
    jmp .writeIndex

.kabutops:
    mov bl, 0x66                      ; size of Kabutops fossil sprite
    jmp .specialID
.ghost:
    mov bl, 0x66                      ; size of Ghost sprite
    jmp .specialID
.aerodactyl:
    mov bl, 0x77                      ; size of Aerodactyl fossil sprite
.specialID:
    mov [ebp + wMonHSpriteDim], bl    ; write sprite dimensions
    ; TODO-HW: front-pic pointer (FossilKabutops/Ghost/FossilAerodactylPic) —
    ; battle sprites not ported yet; write 0 so the OOB BaseStats read is skipped.
    mov word [ebp + wMonHFrontSprite], 0

.writeIndex:
    ; wMonHIndex = wCurSpecies (write internal index back over the dex byte)
    mov al, [ebp + wCurSpecies]
    mov [ebp + wMonHIndex], al

    popad
    ret

; copy party pokemon's name to wNameBuffer
; INPUT: [wWhichPokemon] = index within party
GetPartyMonName2:
    mov al, [ebp + wWhichPokemon]     ; index within party
    mov esi, wPartyMonNicks

; this is called more often; INPUT: AL = index, ESI (hl) = name list base
GetPartyMonName:
    push esi
    push ebx
    call SkipFixedLengthTextEntries   ; esi += NAME_LENGTH * al
    mov edx, wNameBuffer
    push edx
    mov bx, NAME_LENGTH
    call CopyData                      ; esi=src, edx=dest, bx=count
    pop edx                            ; edx = wNameBuffer (output)
    pop ebx
    pop esi
    ret

; prints the level of a mon, with the ":L" prefix dropped at level >= 100
; INPUT: ESI (hl) = destination tile-buffer cursor (EBP-relative),
;        [wLoadedMonLevel] = level
; pret ref: home/pokemon.asm:PrintLevel
PrintLevel:
    mov byte [ebp + esi], CHAR_LV      ; ld a, '<LV>' / ld [hli], a
    inc esi
    mov bl, 2                          ; c = 2 digits
    mov al, [ebp + wLoadedMonLevel]
    cmp al, 100
    jc PrintLevelCommon
    ; if level at least 100, write over the ":L" tile
    dec esi
    inc bl                             ; 3 digits
    jmp PrintLevelCommon

; prints the level without leaving off ":L" regardless of level
; pret ref: home/pokemon.asm:PrintLevelFull
PrintLevelFull:
    mov byte [ebp + esi], CHAR_LV
    inc esi
    mov bl, 3                          ; c = 3 digits
    mov al, [ebp + wLoadedMonLevel]
    ; fall through

; pret ref: home/pokemon.asm:PrintLevelCommon
PrintLevelCommon:
    mov [ebp + wTempByteValue], al
    mov edx, wTempByteValue            ; de = wTempByteValue
    mov bh, (1 << BIT_LEFT_ALIGN) | 1  ; b = LEFT_ALIGN | 1 byte
    jmp PrintNumber
