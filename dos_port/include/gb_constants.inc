; gb_constants.inc — Pokémon data-structure offsets and engine constants.
;
; Source of truth: constants/pokemon_data_constants.asm (repo root, pret spec).
; These mirror the rgbds `rsreset`/`rb`/`rw` struct definitions as plain NASM
; `equ`s so the translated Pokémon-engine routines (add_mon, load_mon_data,
; calc stats, …) can index party/box/base-stat structs by symbolic offset.
;
; NUM_STATS = 5 (HP, Atk, Def, Spd, Spc); NUM_MOVES = 4.

%ifndef GB_CONSTANTS_INC
%define GB_CONSTANTS_INC

NUM_STATS               equ 5
NUM_MOVES               equ 4
NAME_LENGTH             equ 11      ; '@'-terminated name field
PARTY_LENGTH            equ 6
MONS_PER_BOX            equ 20
NUM_BOXES               equ 12
NUM_TMS                 equ 50
NUM_HMS                 equ 5
NUM_TM_HM               equ NUM_TMS + NUM_HMS    ; 55

; --- base data struct (data/pokemon/base_stats/*.asm) ---
BASE_DEX_NO             equ 0x00
BASE_STATS              equ 0x01    ; 5 bytes
BASE_HP                 equ 0x01
BASE_ATK                equ 0x02
BASE_DEF                equ 0x03
BASE_SPD                equ 0x04
BASE_SPC                equ 0x05
BASE_TYPE_1             equ 0x06
BASE_TYPE_2             equ 0x07
BASE_CATCH_RATE         equ 0x08
BASE_EXP                equ 0x09
BASE_PIC_SIZE           equ 0x0A
BASE_FRONTPIC           equ 0x0B    ; word
BASE_BACKPIC            equ 0x0D    ; word
BASE_MOVES              equ 0x0F    ; 4 bytes
BASE_GROWTH_RATE        equ 0x13
BASE_TMHM               equ 0x14    ; (NUM_TM_HM + 7) / 8 = 7 bytes
BASE_DATA_SIZE          equ 0x1C    ; 28 bytes total (incl. 1 padding byte)

; --- party_struct / box_struct members (macros/ram.asm) ---
; GEN-2 FORWARD-COMPAT: these offsets and the struct lengths below
; (PARTYMON=44, BOXMON=33) must stay byte-identical to Gen 1. Gen 2's Time
; Capsule stores a traded mon's HELD ITEM in the MON_CATCH_RATE byte (+7), so
; that slot is load-bearing for the planned Gen 2 port — do NOT repurpose it or
; shrink/realign the struct. Party↔box conversion (deposit/withdraw, when added)
; must preserve +7 verbatim.
MON_SPECIES             equ 0x00
MON_HP                  equ 0x01    ; word (big-endian)
MON_BOX_LEVEL           equ 0x03
MON_STATUS              equ 0x04
MON_TYPE                equ 0x05
MON_TYPE1               equ 0x05
MON_TYPE2               equ 0x06
MON_CATCH_RATE          equ 0x07
MON_MOVES               equ 0x08    ; 4 bytes
MON_OTID                equ 0x0C    ; word
MON_EXP                 equ 0x0E    ; 3 bytes (big-endian)
MON_HP_EXP              equ 0x11    ; word
MON_ATK_EXP             equ 0x13    ; word
MON_DEF_EXP             equ 0x15    ; word
MON_SPD_EXP            equ 0x17    ; word
MON_SPC_EXP             equ 0x19    ; word
MON_DVS                 equ 0x1B    ; word
MON_PP                  equ 0x1D    ; 4 bytes
BOXMON_STRUCT_LENGTH    equ 0x21    ; 33
MON_LEVEL               equ 0x21
MON_STATS               equ 0x22    ; 5 words
MON_MAXHP               equ 0x22
MON_ATK                 equ 0x24
MON_DEF                 equ 0x26
MON_SPD                 equ 0x28
MON_SPC                 equ 0x2A
PARTYMON_STRUCT_LENGTH  equ 0x2C    ; 44

; --- Moves table record (data/moves/moves.asm; gen_moves.py) ---
MOVE_LENGTH             equ 6
MOVE_ANIM               equ 0x00
MOVE_EFFECT             equ 0x01
MOVE_POWER              equ 0x02
MOVE_TYPE               equ 0x03
MOVE_ACC                equ 0x04
MOVE_PP                 equ 0x05

; --- item inventory capacities (constants/menu_constants.asm) ---
BAG_ITEM_CAPACITY       equ 20
PC_ITEM_CAPACITY        equ 50

; --- Gen-2 forward-compat: held item carried in the catch-rate byte ---
; The party/box mon struct's MON_CATCH_RATE byte (offset 7) is Gen 2's held-item
; slot across the Time Capsule. Kadabra ships holding a TwistedSpoon (pret).
KADABRA                 equ 0x26    ; internal species index
TWISTEDSPOON_GSC        equ 0x60    ; Gen-2 held item id stored in the catch-rate byte

; --- mon data locations (wMonDataLocation values) ---
PLAYER_PARTY_DATA       equ 0
ENEMY_PARTY_DATA        equ 1
BOX_DATA                equ 2
DAYCARE_DATA            equ 3
BATTLE_MON_DATA         equ 4

; --- growth rates (index into GrowthRateTable) ---
GROWTH_MEDIUM_FAST      equ 0
GROWTH_SLIGHTLY_FAST    equ 1
GROWTH_SLIGHTLY_SLOW    equ 2
GROWTH_MEDIUM_SLOW      equ 3
GROWTH_FAST             equ 4
GROWTH_SLOW             equ 5

MAX_STAT_VALUE          equ 999
MAX_LEVEL               equ 100

%endif ; GB_CONSTANTS_INC
