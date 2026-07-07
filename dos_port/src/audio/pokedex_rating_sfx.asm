; pokedex_rating_sfx.asm — pret audio/pokedex_rating_sfx.asm translated to x86.
;
; Plays the fanfare matching Oak's pokédex rating. The (sfx id, bank) pairs
; are pret's BANK() values resolved against the golden ROM .sym: _1 labels
; live in bank $02, SFX_Level_Up/SFX_Caught_Mon in $08, SFX_Denied_3 in $1f.
;
; Register map: A=AL, BC=BX, DE=DX, HL=ESI, EBP = GB memory base.

%include "gb_memmap.inc"
%include "assets/audio_constants.inc"

global PlayPokedexRatingSfx

extern StopAllMusic               ; src/home/audio.asm
extern PlayMusic                  ; src/home/audio.asm
extern PlayDefaultMusic           ; src/home/audio.asm

section .text

PlayPokedexRatingSfx:
    mov al, [ebp + hDexRatingNumMonsOwned]
    mov bl, 0                           ; c = tier index
    mov esi, OwnedMonValues             ; (linear pointer; pret hl = ROM addr)
.getSfxPointer:
    cmp al, [esi]
    jc .gotSfxPointer
    inc bl
    inc esi
    jmp .getSfxPointer
.gotSfxPointer:
    push ebx
    call StopAllMusic
    pop ebx
    movzx esi, bl
    mov al, [PokedexRatingSfxPointers + esi*2]      ; sfx id
    mov bl, [PokedexRatingSfxPointers + esi*2 + 1]  ; c = audio ROM bank
    call PlayMusic
    jmp PlayDefaultMusic

section .data

PokedexRatingSfxPointers:
    db SFX_DENIED,         AUDIO_BANK_3 ; BANK(SFX_Denied_3)
    db SFX_POKEDEX_RATING, AUDIO_BANK_1 ; BANK(SFX_Pokedex_Rating_1)
    db SFX_GET_ITEM_1,     AUDIO_BANK_1 ; BANK(SFX_Get_Item1_1)
    db SFX_CAUGHT_MON,     AUDIO_BANK_2 ; BANK(SFX_Caught_Mon)
    db SFX_LEVEL_UP,       AUDIO_BANK_2 ; BANK(SFX_Level_Up)
    db SFX_GET_KEY_ITEM,   AUDIO_BANK_1 ; BANK(SFX_Get_Key_Item_1)
    db SFX_GET_ITEM_2,     AUDIO_BANK_1 ; BANK(SFX_Get_Item2_1)

OwnedMonValues:
    db 10, 40, 60, 90, 120, 150, 0xFF
