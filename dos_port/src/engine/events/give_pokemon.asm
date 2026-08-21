; ===========================================================================
; engine/events/give_pokemon.asm — faithful port of pret engine/events/give_pokemon.asm
;
; Implements _GivePokemon (adds a Pokemon to the player's party or current box)
; and SetPokedexOwnedFlag (marks the given species as owned in the Pokedex and
; prints the "got <MON>!" fanfare text).
;
; Register map (SM83 -> x86):
;   A  -> AL
;   BC -> EBX (B -> BH, C -> BL)
;   DE -> EDX (D -> DH, E -> DL)
;   HL -> ESI
;   EBP = emulated GB memory base
; ===========================================================================

bits 32

%include "gb_macros.inc"
%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_text.inc"

; Box number constants
%define BOX_NUM_MASK  0x7F
CHAR_0      equ 0xF6            ; charmap '0'
CHAR_1      equ 0xF7            ; charmap '1'
CHAR_TERM   equ 0x50            ; charmap '@' terminator

section .text

global _GivePokemon
global SetPokedexOwnedFlag

; --- External routines ---
extern EnableAutoTextBoxDrawing          ; src/home/window.asm
extern LoadEnemyMonData                  ; src/engine/battle/core.asm
extern SendNewMonToBox                   ; src/engine/items/item_effects.asm
extern PrintText                         ; src/home/window.asm
extern AddPartyMon                       ; src/home/move_mon.asm
extern IndexToPokedex                    ; src/engine/menus/pokedex.asm
extern FlagAction                        ; src/engine/flag_action.asm
extern GetMonName                        ; src/home/names.asm

; ---------------------------------------------------------------------------
; _GivePokemon — pret engine/events/give_pokemon.asm:_GivePokemon
; returns success in carry (CF)
; and whether the mon was added to the party in [wAddedToParty]
; ---------------------------------------------------------------------------
_GivePokemon:
    call EnableAutoTextBoxDrawing               ; call EnableAutoTextBoxDrawing
    xor al, al                                  ; xor a
    mov [ebp + wAddedToParty], al               ; ld [wAddedToParty], a
    mov al, [ebp + wPartyCount]                 ; ld a, [wPartyCount]
    cmp al, PARTY_LENGTH                        ; cp PARTY_LENGTH
    jb .addToParty                              ; jr c, .addToParty
    mov al, [ebp + wBoxCount]                   ; ld a, [wBoxCount]
    cmp al, MONS_PER_BOX                        ; cp MONS_PER_BOX
    jnb .boxFull                                ; jr nc, .boxFull

; add to box
    xor al, al                                  ; xor a
    mov [ebp + wEnemyBattleStatus3], al         ; ld [wEnemyBattleStatus3], a
    mov al, [ebp + wCurPartySpecies]            ; ld a, [wCurPartySpecies]
    mov [ebp + wEnemyMonSpecies2], al           ; ld [wEnemyMonSpecies2], a
    call LoadEnemyMonData                       ; callfar LoadEnemyMonData
    call SetPokedexOwnedFlag                    ; call SetPokedexOwnedFlag
    call SendNewMonToBox                        ; callfar SendNewMonToBox
    mov esi, wStringBuffer                      ; ld hl, wStringBuffer
    mov al, [ebp + wCurrentBoxNum]              ; ld a, [wCurrentBoxNum]
    and al, BOX_NUM_MASK                        ; and BOX_NUM_MASK
    cmp al, 9                                   ; cp 9
    jb .singleDigitBoxNum                       ; jr c, .singleDigitBoxNum
    sub al, 9                                   ; sub 9
    mov byte [ebp + esi], CHAR_1                ; ld [hl], '1'
    inc esi                                     ; inc hl
    add al, CHAR_0                              ; add '0'
    jmp .next                                   ; jr .next

.singleDigitBoxNum:
    add al, CHAR_1                              ; add '1'

.next:
    mov [ebp + esi], al                         ; ld [hli], a
    inc esi
    mov byte [ebp + esi], CHAR_TERM             ; ld [hl], '@'
    mov esi, SentToBoxText                      ; ld hl, SentToBoxText
    call PrintText                              ; call PrintText
    stc                                         ; scf
    ret

.boxFull:
    mov esi, BoxIsFullText                      ; ld hl, BoxIsFullText
    call PrintText                              ; call PrintText
    clc                                         ; and a
    ret

.addToParty:
    call SetPokedexOwnedFlag                    ; call SetPokedexOwnedFlag
    mov esi, UnknownTerminator_f6794            ; ld hl, UnknownTerminator_f6794
    call PrintText                              ; call PrintText
    call AddPartyMon                            ; call AddPartyMon
    mov al, 1                                   ; ld a, 1
    mov [ebp + wDoNotWaitForButtonPressAfterDisplayingText], al ; ld [wDoNotWaitForButtonPressAfterDisplayingText], a
    mov [ebp + wAddedToParty], al               ; ld [wAddedToParty], a
    stc                                         ; scf
    ret

; ---------------------------------------------------------------------------
; SetPokedexOwnedFlag — pret engine/events/give_pokemon.asm:SetPokedexOwnedFlag
; ---------------------------------------------------------------------------
; DEVIATION{class=banking; pret=engine/events/give_pokemon.asm:SetPokedexOwnedFlag; behavior=call FlagAction directly instead of predef FlagActionPredef; evidence=port has no predef dispatcher so register-passing predefs call the leaf routine directly without clobbering registers via GetPredefRegisters; lifetime=permanent flat-code calling boundary}
SetPokedexOwnedFlag:
    mov al, [ebp + wCurPartySpecies]            ; ld a, [wCurPartySpecies]
    push eax                                    ; push af
    mov [ebp + wPokedexNum], al                 ; ld [wPokedexNum], a
    call IndexToPokedex                         ; predef IndexToPokedex
    mov al, [ebp + wPokedexNum]                 ; ld a, [wPokedexNum]
    dec al                                      ; dec a
    mov cl, al                                  ; ld c, a
    mov esi, wPokedexOwned                      ; ld hl, wPokedexOwned
    mov bh, FLAG_SET                            ; ld b, FLAG_SET
    call FlagAction                             ; predef FlagActionPredef
    pop eax                                     ; pop af
    mov [ebp + wNamedObjectIndex], al           ; ld [wNamedObjectIndex], a
    call GetMonName                             ; call GetMonName
    mov esi, GotMonText                         ; ld hl, GotMonText
    jmp PrintText                               ; jp PrintText

; ---------------------------------------------------------------------------
; Tier-1 generated text streams (gen_give_pokemon_text.py)
; ---------------------------------------------------------------------------
%include "assets/give_pokemon_text.inc"
