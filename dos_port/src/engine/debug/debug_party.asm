; dos_port/src/debug/debug_party.asm

%include "gb_macros.inc"
%include "gb_memmap.inc"

section .text

global SetDebugNewGameParty
global PrepareNewGameDebug
extern AddPartyMon
extern AddItemToInventory

%define BIT_EARTHBADGE 7
%define SURF 57
%define FLY 19
%define CUT 15
%define STRENGTH 70

%define SNORLAX 132
%define PERSIAN 144        ; internal index (113 was wrong — that's KAKUNA; see data/pokemon/dex_order.asm)
%define JIGGLYPUFF 100
%define STARTER_PIKACHU 84
%define CHARIZARD 180      ; internal index (dex_order.asm line - 2)
%define LAPRAS 19

%define RIVAL_STARTER_JOLTEON 135
%define NUM_POKEMON 151

%define EVENT_GOT_POKEDEX 37

; -----------------------------------------------------------------------------
; SetDebugNewGameParty
; -----------------------------------------------------------------------------
SetDebugNewGameParty:
    lea esi, [DebugNewGameParty]

.loop:
    mov al, byte [esi]
    cmp al, 0xFF
    jz .done
    
    mov byte [ebp + W_CUR_PARTY_SPECIES], al
    inc esi
    
    mov al, byte [esi]
    mov byte [ebp + W_CUR_ENEMY_LEVEL], al
    inc esi
    
    push esi ; Save ESI across AddPartyMon
    call AddPartyMon
    pop esi
    
    jmp .loop
.done:
    ret

; -----------------------------------------------------------------------------
; PrepareNewGameDebug
; -----------------------------------------------------------------------------
PrepareNewGameDebug:
    ; W_MON_DATA_LOCATION = 0
    mov byte [ebp + W_MON_DATA_LOCATION], 0

    ; Fly anywhere
    mov byte [ebp + W_TOWN_VISITED_FLAG], 0xFF
    mov byte [ebp + W_TOWN_VISITED_FLAG + 1], 0xFF

    ; Get all badges except Earth Badge
    mov byte [ebp + W_OBTAINED_BADGES], ~(1 << BIT_EARTHBADGE)

    call SetDebugNewGameParty

    ; Pikachu gets Surf
    mov byte [ebp + W_PARTY_MON4_MOVES + 2], SURF

    ; Snorlax gets four HM moves
    mov byte [ebp + W_PARTY_MON1_MOVES + 0], FLY
    mov byte [ebp + W_PARTY_MON1_MOVES + 1], CUT
    mov byte [ebp + W_PARTY_MON1_MOVES + 2], SURF
    mov byte [ebp + W_PARTY_MON1_MOVES + 3], STRENGTH

    ; Get some debug items
    lea esi, [DebugNewGameItemsList]
.items_loop:
    mov al, byte [esi]
    cmp al, 0xFF
    jz .items_end
    
    mov byte [ebp + W_CUR_ITEM], al
    inc esi
    mov al, byte [esi]
    inc esi
    mov byte [ebp + W_ITEM_QUANTITY], al
    
    push esi
    mov esi, W_NUM_BAG_ITEMS
    call AddItemToInventory ; Note: AddItemToInventory takes ESI=inventory ptr
    pop esi
    
    jmp .items_loop

.items_end:
    ; Complete the Pokédex
    mov edi, W_POKEDEX_OWNED
    call DebugSetPokedexEntries
    mov edi, W_POKEDEX_SEEN
    call DebugSetPokedexEntries
    
    ; SetEvent EVENT_GOT_POKEDEX
    ; Event 37 is byte 4, bit 5
    or byte [ebp + W_EVENT_FLAGS + (EVENT_GOT_POKEDEX / 8)], (1 << (EVENT_GOT_POKEDEX % 8))

    ; Rival chose Jolteon
    mov byte [ebp + W_RIVAL_STARTER], RIVAL_STARTER_JOLTEON
    mov byte [ebp + W_RIVAL_STARTER + 1], NUM_POKEMON
    mov byte [ebp + W_RIVAL_STARTER + 2], STARTER_PIKACHU

    ; Give max money
    mov byte [ebp + W_PLAYER_MONEY], 0x99
    mov byte [ebp + W_PLAYER_MONEY + 1], 0x99
    mov byte [ebp + W_PLAYER_MONEY + 2], 0x99
    
    ret

; -----------------------------------------------------------------------------
; DebugSetPokedexEntries
; Fills the Pokedex buffer at EDI.
; -----------------------------------------------------------------------------
DebugSetPokedexEntries:
    mov ecx, NUM_POKEMON / 8
.loop:
    mov byte [ebp + edi], 0xFF
    inc edi
    dec ecx
    jnz .loop
    
    mov byte [ebp + edi], (1 << (NUM_POKEMON % 8)) - 1
    ret

section .data

DebugNewGameParty:
    db SNORLAX, 80
    db PERSIAN, 80
    db JIGGLYPUFF, 15
    db STARTER_PIKACHU, 5
    db CHARIZARD, 50
    db LAPRAS, 34
    db 0xFF ; end (-1)

; Debug items. We only use numeric values here.
; Item ids per constants/item_constants.asm (decimal). Several were hand-guessed
; wrong originally (TOWN_MAP/FULL_RESTORE/SECRET_KEY/CARD_KEY/S_S_TICKET/LIFT_KEY/
; PP_UP) — corrected here.
%define POTION 20         ; $14 (tossable, seeded qty 1 → skips the quantity chooser)
%define ANTIDOTE 11       ; $0B (tossable, low qty for an easy quantity-chooser test)
%define MASTER_BALL 1     ; $01
%define TOWN_MAP 5        ; $05 (was 4 = POKE_BALL)
%define BICYCLE 6         ; $06
%define FULL_RESTORE 16   ; $10 (was 17 = MAX_POTION)
%define ESCAPE_ROPE 29    ; $1D
%define RARE_CANDY 40     ; $28
%define SECRET_KEY 43     ; $2B (was 65)
%define CARD_KEY 48       ; $30 (was 74 = LIFT_KEY)
%define FULL_HEAL 52      ; $34
%define REVIVE 53         ; $35
%define FRESH_WATER 60    ; $3C
%define S_S_TICKET 63     ; $3F (was 69)
%define LIFT_KEY 74       ; $4A (was 76)
%define PP_UP 79          ; $4F (was 49)

DebugNewGameItemsList:
    db POTION, 1            ; qty-1 tossable: toss skips straight to YES/NO confirm
    db ANTIDOTE, 3         ; low qty: easy quantity-chooser exercise
    db MASTER_BALL, 99
    db TOWN_MAP, 1
    db BICYCLE, 1
    db FULL_RESTORE, 99
    db ESCAPE_ROPE, 99
    db RARE_CANDY, 99
    db SECRET_KEY, 1
    db CARD_KEY, 1
    db FULL_HEAL, 99
    db REVIVE, 99
    db FRESH_WATER, 99
    db S_S_TICKET, 1
    db LIFT_KEY, 1
    db PP_UP, 99
    db 0xFF ; end (-1)
