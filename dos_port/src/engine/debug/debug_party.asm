; dos_port/src/debug/debug_party.asm

%include "gb_macros.inc"
%include "gb_memmap.inc"

section .text

global SetDebugNewGameParty
global PrepareNewGameDebug
global SeedDeterministicPlayerIdentity
extern AddPartyMon
extern AddItemToInventory
extern GetMonHeader                ; home/pokemon.asm — base stats -> wMonHeader
extern CalcStats                   ; home/move_mon.asm — recompute the 5 stats
extern GetMonName                  ; home/names.asm — species default -> wNameBuffer
extern CopyData                    ; home/copy_data.asm

; Party-mon struct offsets (mirror gb_constants.inc). gb_constants.inc is NOT
; %included here: it defines CUT/FLY/SURF/STRENGTH via `equ`, which collides
; with this file's local move `%define`s. So the few offsets needed for the
; deterministic-stat recompute are redeclared locally.
%define MON_SPECIES_OFF 0x00
%define MON_HP_OFF      0x01        ; word (big-endian)
%define MON_HP_EXP_OFF  0x11        ; stat-exp base (CalcStats hl = base - 1)
%define MON_DVS_OFF     0x1B        ; word
%define MON_LEVEL_OFF   0x21
%define MON_MAXHP_OFF   0x22        ; first of the 5 big-endian stat words
%define PARTYMON_LEN    0x2C        ; 44
%define NAME_LEN        11

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
    ; AddPartyMon selects player storage from the low nibble, but only the
    ; whole-zero player value opens AskName.  The deterministic harness owns
    ; the nicknames it seeds and has no interactive naming input, so publish a
    ; nonzero player-path marker while constructing the party, then restore the
    ; shipping value before returning.
    mov byte [ebp + W_MON_DATA_LOCATION], 0x10
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
    
    push esi ; Save ESI across AddPartyMon + deterministic nickname copy
    call AddPartyMon

    ; The interactive AskName path normally copies the species default when the
    ; player declines.  This non-interactive harness performs that deterministic
    ; final step directly so its party bytes still match the golden seed.
    mov al, [ebp + W_CUR_PARTY_SPECIES]
    mov [ebp + wNamedObjectIndex], al
    call GetMonName
    movzx eax, byte [ebp + wPartyCount]
    dec eax
    imul eax, NAME_LEN
    lea edx, [eax + wPartyMonNicks]
    mov esi, wNameBuffer
    mov bx, NAME_LEN
    call CopyData
    pop esi
    
    jmp .loop
.done:
    mov byte [ebp + W_MON_DATA_LOCATION], 0
    ret

; -----------------------------------------------------------------------------
; PrepareNewGameDebug
; -----------------------------------------------------------------------------
PrepareNewGameDebug:
    ; Deterministic player identity FIRST — before the party is built, so
    ; _AddPartyMon copies "RED" into each mon's OT-name slot (add_party_mon.asm:
    ; OT source = wPlayerName).
    call SeedDeterministicPlayerIdentity

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

    ; --- Deterministic DVs + stat recompute (fidelity harness; converge to
    ; seed.lua, the byte-level spec). _AddPartyMon rolled random DVs via
    ; Random_; overwrite every mon with the spec DVs $98 $76 (Atk9/Def8/Spd7/
    ; Spc6 -> HP DV 10), zero stat exp, recompute the 5 stats with the real
    ; GetMonHeader + CalcStats (stat exp ignored), and refill HP to the new
    ; MaxHP — so party bytes equal seed.lua's by construction.
    movzx ecx, byte [ebp + wPartyCount]
    test ecx, ecx
    jz .dvDone
    mov edi, wPartyMon1                 ; GB offset of mon 0
.dvLoop:
    mov byte [ebp + edi + MON_DVS_OFF], 0x98
    mov byte [ebp + edi + MON_DVS_OFF + 1], 0x76
    ; stat exp = 0 (10 bytes)
    mov dword [ebp + edi + MON_HP_EXP_OFF], 0
    mov dword [ebp + edi + MON_HP_EXP_OFF + 4], 0
    mov word  [ebp + edi + MON_HP_EXP_OFF + 8], 0
    ; CalcStats inputs: wCurSpecies/wCurEnemyLevel from the struct itself
    mov al, [ebp + edi + MON_SPECIES_OFF]
    mov [ebp + wCurSpecies], al
    mov al, [ebp + edi + MON_LEVEL_OFF]
    mov [ebp + wCurEnemyLevel], al
    push ecx
    push edi
    call GetMonHeader                   ; base stats -> wMonHeader (regs preserved)
    xor bh, bh                          ; b = 0: ignore stat exp
    lea esi, [edi + MON_HP_EXP_OFF - 1] ; hl = stat-exp base - 1 (GB addr)
    lea edx, [edi + MON_MAXHP_OFF]      ; de = dest: MaxHP..Special (5 BE words)
    call CalcStats
    pop edi
    pop ecx
    ; current HP = new MaxHP (16-bit copy keeps the big-endian byte order)
    mov ax, [ebp + edi + MON_MAXHP_OFF]
    mov [ebp + edi + MON_HP_OFF], ax
    add edi, PARTYMON_LEN
    dec ecx
    jnz .dvLoop
.dvDone:

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
    ; Pokédex: the dex flags are two per-mon bitfields (binary DIP switches).
    ; Seed all 151 SEEN and a scattered ~half OWNED (deterministic pattern) so
    ; the CONTENTS list shows both pokéball-marked and unmarked entries, every
    ; DATA page is reachable, and IsPokemonBitSet gets exercised on both values.
    mov edi, W_POKEDEX_SEEN
    call DebugSetPokedexEntries
    mov edi, W_POKEDEX_OWNED
    call DebugSetPokedexOwnedScatter
    
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
; SeedDeterministicPlayerIdentity — fidelity harness (converge to seed.lua):
; wPlayerName = "RED", '@'-padded to NAME_LEN; wPlayerID = 0 (big-endian).
; Called by PrepareNewGameDebug and directly by DEBUG_* gates that skip the
; party seed (e.g. DEBUG_STARTMENU), so every harness screen shows the spec
; identity instead of the build-define name. Charmap bytes per
; constants/charmap.asm — matches this file's numeric-id debug-seed convention
; (not asset-pipeline text).
; -----------------------------------------------------------------------------
SeedDeterministicPlayerIdentity:
    mov byte [ebp + wPlayerName + 0], 0x91   ; R
    mov byte [ebp + wPlayerName + 1], 0x84   ; E
    mov byte [ebp + wPlayerName + 2], 0x83   ; D
    mov edi, wPlayerName + 3
    mov ecx, NAME_LEN - 3
    mov al, 0x50                             ; '@' terminator/pad
.padName:
    mov byte [ebp + edi], al
    inc edi
    dec ecx
    jnz .padName
    mov word [ebp + wPlayerID], 0            ; big-endian 0
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

; -----------------------------------------------------------------------------
; DebugSetPokedexOwnedScatter
; Fills the dex bitfield at EDI with a deterministic scattered pattern
; (~half the bits set) — "a random amount caught". Bits past NUM_POKEMON in
; the tail byte are masked off, matching DebugSetPokedexEntries.
; -----------------------------------------------------------------------------
DebugSetPokedexOwnedScatter:
    mov ecx, NUM_POKEMON / 8
    mov al, 0xB5                    ; pattern seed
.loop:
    mov [ebp + edi], al
    rol al, 3
    xor al, 0x5D                    ; cheap per-byte scramble
    inc edi
    dec ecx
    jnz .loop
    and al, (1 << (NUM_POKEMON % 8)) - 1
    mov [ebp + edi], al
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
