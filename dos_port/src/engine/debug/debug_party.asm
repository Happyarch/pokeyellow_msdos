; dos_port/src/debug/debug_party.asm

%include "gb_macros.inc"
%include "gb_memmap.inc"

section .bss
; DEBUG_TRADECHECK harness flag: set by boot/entry.asm's /PARTYB parse (same
; ownership pattern as g_net_linklog, owned by net_hal.asm). Nonzero selects
; DebugNewGamePartyB in SetDebugNewGameParty and the BLUE/otid-66 identity in
; SeedDeterministicPlayerIdentity, so the two tradecheck instances seed
; distinguishable party/OT data for the round-trip byte-identity assertions.
g_cfg_partyb: resb 1

section .text

global SetDebugNewGameParty
global PrepareNewGameDebug
global SeedDeterministicPlayerIdentity
global g_cfg_partyb
extern AddPartyMon
extern AddItemToInventory            ; src/home/inventory.asm
extern GetMonHeader                ; home/pokemon.asm — base stats -> wMonHeader
extern CalcStats                   ; home/move_mon.asm — recompute the 5 stats
extern GetMonName                  ; home/names.asm — species default -> wNameBuffer
extern CopyData                    ; home/copy.asm

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

%define SNORLAX 0x84
%define PIDGEOTTO 0x96      ; internal index $96 (pret constants/pokemon_constants.asm)
%define PERSIAN 0x90        ; internal index (113 was wrong — that's KAKUNA; see data/pokemon/dex_order.asm)
%define JIGGLYPUFF 0x64
%define STARTER_PIKACHU 0x54
%define CHARIZARD 0xB4      ; internal index (dex_order.asm line - 2)
%define LAPRAS 0x13

; DEBUG_TRADECHECK /PARTYB table (constants/pokemon_constants.asm internal
; index, verified against the const_def list): every species here is disjoint
; from DebugNewGameParty above so a link-trade harness can tell the two sides'
; structs apart byte-for-byte.
%define ABRA 0x94
%define GEODUDE 0xA9
%define VULPIX 0x52
%define MACHOP 0x6A
%define EEVEE 0x66
%define ONIX 0x22

; LATENT BUG FIXED 2026-08-08: this was 135 (0x87 — a const_skip/MissingNo slot in
; the internal index list), so the debug seed marked the rival's starter as a
; glitch species. Jolteon's real internal index is $68 (pret pokemon_constants +
; Bulbapedia Gen-I index list, three-way verified). No golden impact: seed.lua
; does not mirror wRivalStarter and no compared region covers it.
%define RIVAL_STARTER_JOLTEON 0x68
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
    mov byte [ebp + wMonDataLocation], 0x10
    lea esi, [DebugNewGameParty]
    cmp byte [g_cfg_partyb], 0
    jz .loop
    lea esi, [DebugNewGamePartyB]   ; DEBUG_TRADECHECK: distinct per-side table

.loop:
    mov al, byte [esi]
    cmp al, 0xFF
    jz .done
    
    mov byte [ebp + wCurPartySpecies], al
    inc esi
    
    mov al, byte [esi]
    mov byte [ebp + wCurEnemyLevel], al
    inc esi
    
    push esi ; Save ESI across AddPartyMon + deterministic nickname copy
    call AddPartyMon

    ; The interactive AskName path normally copies the species default when the
    ; player declines.  This non-interactive harness performs that deterministic
    ; final step directly so its party bytes still match the golden seed.
    mov al, [ebp + wCurPartySpecies]
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
    mov byte [ebp + wMonDataLocation], 0
    ret

; -----------------------------------------------------------------------------
; PrepareNewGameDebug
; -----------------------------------------------------------------------------
PrepareNewGameDebug:
    ; Deterministic player identity FIRST — before the party is built, so
    ; _AddPartyMon copies "RED" into each mon's OT-name slot (add_mon.asm:
    ; OT source = wPlayerName).
    call SeedDeterministicPlayerIdentity

    ; wMonDataLocation = 0
    mov byte [ebp + wMonDataLocation], 0

    ; Fly anywhere
    mov byte [ebp + wTownVisitedFlag], 0xFF
    mov byte [ebp + wTownVisitedFlag + 1], 0xFF

    ; Get all badges except Earth Badge
    mov byte [ebp + wObtainedBadges], ~(1 << BIT_EARTHBADGE)

    call SetDebugNewGameParty

    ; Pikachu gets Surf
    mov byte [ebp + W_PARTY_MON4_MOVES + 2], SURF

    ; Snorlax gets four HM moves
    mov byte [ebp + wPartyMon1Moves + 0], FLY
    mov byte [ebp + wPartyMon1Moves + 1], CUT
    mov byte [ebp + wPartyMon1Moves + 2], SURF
    mov byte [ebp + wPartyMon1Moves + 3], STRENGTH

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
    
    mov byte [ebp + wCurItem], al
    inc esi
    mov al, byte [esi]
    inc esi
    mov byte [ebp + wItemQuantity], al
    
    push esi
    mov esi, wNumBagItems
    call AddItemToInventory ; Note: AddItemToInventory takes ESI=inventory ptr
    pop esi
    
    jmp .items_loop

.items_end:
%ifdef DEBUG_SLOTS
    ; The third gate in AbleToPlaySlotsCheck: it ORs the two wPlayerCoins bytes
    ; and refuses when both are zero. BCD and BIG-ENDIAN like every other
    ; multi-byte GB value, so 50 coins is 00 50 and NOT 50 00 — the low byte
    ; second. Enough to play but not enough to mask a payout bug.
    mov byte [ebp + wPlayerCoins],     0x00
    mov byte [ebp + wPlayerCoins + 1], 0x50
%endif
    ; Pokédex: the dex flags are two per-mon bitfields (binary DIP switches).
    ; Seed all 151 SEEN and a scattered ~half OWNED (deterministic pattern) so
    ; the CONTENTS list shows both pokéball-marked and unmarked entries, every
    ; DATA page is reachable, and IsPokemonBitSet gets exercised on both values.
    mov edi, wPokedexSeen
    call DebugSetPokedexEntries
    mov edi, wPokedexOwned
    call DebugSetPokedexOwnedScatter
    
    ; SetEvent EVENT_GOT_POKEDEX
    ; Event 37 is byte 4, bit 5
    or byte [ebp + wEventFlags + (EVENT_GOT_POKEDEX / 8)], (1 << (EVENT_GOT_POKEDEX % 8))

    ; Rival chose Jolteon
    mov byte [ebp + wRivalStarter], RIVAL_STARTER_JOLTEON
    mov byte [ebp + wRivalStarter + 1], NUM_POKEMON
    mov byte [ebp + wRivalStarter + 2], STARTER_PIKACHU

    ; Give max money
    mov byte [ebp + wPlayerMoney], 0x99
    mov byte [ebp + wPlayerMoney + 1], 0x99
    mov byte [ebp + wPlayerMoney + 2], 0x99
    
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
    cmp byte [g_cfg_partyb], 0
    jnz .partyB
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
.partyB:
    ; DEBUG_TRADECHECK /PARTYB side: "BLUE" + a nonzero OTID, so the trade
    ; harness can assert the received mon's OT name/id came from THIS side
    ; and not the RED default. Charmap per constants/charmap.asm (A=$80..Z=$99,
    ; matching this file's existing R/E/D numeric-id convention above).
    mov byte [ebp + wPlayerName + 0], 0x81   ; B
    mov byte [ebp + wPlayerName + 1], 0x8B   ; L
    mov byte [ebp + wPlayerName + 2], 0x94   ; U
    mov byte [ebp + wPlayerName + 3], 0x84   ; E
    mov edi, wPlayerName + 4
    mov ecx, NAME_LEN - 4
    mov al, 0x50                             ; '@' terminator/pad
.padNameB:
    mov byte [ebp + edi], al
    inc edi
    dec ecx
    jnz .padNameB
    ; OTID = 66 ($0042), big-endian (Data is big-endian hard rule): write the
    ; two bytes explicitly high-then-low rather than a native `mov word`,
    ; which would store the host's little-endian byte order instead.
    mov byte [ebp + wPlayerID], 0x00
    mov byte [ebp + wPlayerID + 1], 0x42
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
%ifdef DEBUG_ANIM_DEMO
    ; Anim-demo reference scene (maintainer request): lead = PIDGEOTTO L20,
    ; matching the real-game GUST reference frames (PIDGEOTTO vs ZUBAT).
    db PIDGEOTTO, 20
%else
    db SNORLAX, 80
%endif
    db PERSIAN, 80
    db JIGGLYPUFF, 15
    db STARTER_PIKACHU, 5
    db CHARIZARD, 50
    db LAPRAS, 34
    db 0xFF ; end (-1)

; DEBUG_TRADECHECK /PARTYB table: lead ABRA 30 + 5 more, every species AND
; level disjoint from DebugNewGameParty above (verified against
; constants/pokemon_constants.asm's const_def list) so a link-trade harness's
; struct-verbatim assertion has no byte that could coincidentally match by
; construction between the two sides.
DebugNewGamePartyB:
    db ABRA, 30
    db GEODUDE, 25
    db VULPIX, 22
    db MACHOP, 28
    db EEVEE, 20
    db ONIX, 35
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
; Declared locally like every other item id here, NOT taken from gb_constants.inc
; (which defines it as 0x45) — see this file's header: including that file would
; collide with the local CUT/FLY/SURF/STRENGTH move %defines.
%define COIN_CASE 0x45    ; $45, constants/item_constants.asm:81

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
%ifdef DEBUG_SLOTS
    ; AbleToPlaySlotsCheck (engine/slots/game_corner_slots2.asm) refuses unless
    ; GetQuantityOfItemInBag returns nonzero for COIN_CASE. Gated, not
    ; unconditional: wBagItems is a compared GBSTATE region, so adding an item to
    ; every debug build would move every datastruct scenario's bag.
    db COIN_CASE, 1
%endif
    db 0xFF ; end (-1)
