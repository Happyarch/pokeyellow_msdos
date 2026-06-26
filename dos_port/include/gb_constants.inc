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

; ===========================================================================
; Battle engine constants (current_plan_battle_engine.md)
; Sources: constants/battle_constants.asm, type_constants.asm,
;          move_effect_constants.asm, move_constants.asm.
; ===========================================================================

; --- significant stat values (stat-stage modifier range, base = 7) ---
BASE_STAT_LEVEL         equ 7
MAX_STAT_LEVEL          equ 13

; --- VitaminStats / stat indexes (1-based, see data/battle/stat_names.asm) ---
STAT_HEALTH             equ 1
STAT_ATTACK             equ 2
STAT_DEFENSE            equ 3
STAT_SPEED              equ 4
STAT_SPECIAL            equ 5

; --- StatModTextStrings indexes (0-based; wWhichStat / stat-mod handlers) ---
MOD_ATTACK              equ 0
MOD_DEFENSE             equ 1
MOD_SPEED               equ 2
MOD_SPECIAL             equ 3
MOD_ACCURACY            equ 4
MOD_EVASION             equ 5
NUM_STAT_MODS           equ 8          ; const_value after const_skip 2

; --- battle type constants (wBattleType values) ---
BATTLE_TYPE_NORMAL      equ 0
BATTLE_TYPE_OLD_MAN     equ 1
BATTLE_TYPE_SAFARI      equ 2
BATTLE_TYPE_RUN         equ 3
BATTLE_TYPE_PIKACHU     equ 4

; --- damage limits before type effectiveness ---
MIN_NEUTRAL_DAMAGE      equ 2
MAX_NEUTRAL_DAMAGE      equ 999

; --- fixed-damage move constants ---
SONICBOOM_DAMAGE        equ 20
DRAGON_RAGE_DAMAGE      equ 40

; --- type effectiveness factors, scaled by 10 (TypeEffects table values) ---
SUPER_EFFECTIVE         equ 20
MORE_EFFECTIVE          equ 15
EFFECTIVE               equ 10
NOT_VERY_EFFECTIVE      equ 5
NO_EFFECT               equ 0

; --- non-volatile status (wBattleMonStatus / MON_STATUS bits) ---
SLP_MASK                equ 0x07       ; %111, sleep counter 0-7 turns
PSN                     equ 3
BRN                     equ 4
FRZ                     equ 5
PAR                     equ 6
; status as single-bit masks (1 << n)
SLP                     equ 7          ; counter region (any of bits 0-2)
PSN_MASK                equ (1 << PSN) ; 0x08
BRN_MASK                equ (1 << BRN) ; 0x10
FRZ_MASK                equ (1 << FRZ) ; 0x20
PAR_MASK                equ (1 << PAR) ; 0x40

; --- trainer DVs (read_trainer_party) ---
ATKDEFDV_TRAINER        equ 0x98
SPDSPCDV_TRAINER        equ 0x88

; --- wDamageMultipliers field ---
BIT_STAB_DAMAGE         equ 7
EFFECTIVENESS_MASK      equ 0x7F       ; %01111111

; --- wPlayerBattleStatus1 / wEnemyBattleStatus1 bit flags ---
STORING_ENERGY          equ 0          ; Bide
THRASHING_ABOUT         equ 1          ; Thrash, Petal Dance
ATTACKING_MULTIPLE_TIMES equ 2         ; Double Kick, Fury Attack, etc.
FLINCHED                equ 3
CHARGING_UP             equ 4          ; Solar Beam, Fly, etc.
USING_TRAPPING_MOVE     equ 5          ; Wrap, etc.
INVULNERABLE            equ 6          ; charging Fly/Dig
CONFUSED                equ 7

; --- wPlayerBattleStatus2 / wEnemyBattleStatus2 bit flags ---
USING_X_ACCURACY        equ 0
PROTECTED_BY_MIST       equ 1
GETTING_PUMPED          equ 2          ; Focus Energy
HAS_SUBSTITUTE_UP       equ 4
NEEDS_TO_RECHARGE       equ 5          ; Hyper Beam
USING_RAGE              equ 6
SEEDED                  equ 7          ; Leech Seed

; --- wPlayerBattleStatus3 / wEnemyBattleStatus3 bit flags ---
BADLY_POISONED          equ 0          ; Toxic
HAS_LIGHT_SCREEN_UP     equ 1
HAS_REFLECT_UP          equ 2
TRANSFORMED             equ 3

; --- type constants (constants/type_constants.asm) ---
PHYSICAL                equ 0x00       ; types < SPECIAL are physical
NORMAL                  equ 0x00
FIGHTING                equ 0x01
FLYING                  equ 0x02
POISON                  equ 0x03
GROUND                  equ 0x04
ROCK                    equ 0x05
BIRD                    equ 0x06
BUG                     equ 0x07
GHOST                   equ 0x08
SPECIAL                 equ 0x14       ; types >= SPECIAL use Special stat
FIRE                    equ 0x14
WATER                   equ 0x15
GRASS                   equ 0x16
ELECTRIC                equ 0x17
PSYCHIC_TYPE            equ 0x18
ICE                     equ 0x19
DRAGON                  equ 0x1A
NUM_TYPES               equ 0x1B

; --- move effect constants (MoveEffectPointerTable indexes) ---
NO_ADDITIONAL_EFFECT       equ 0x00
POISON_SIDE_EFFECT1        equ 0x02
DRAIN_HP_EFFECT            equ 0x03
BURN_SIDE_EFFECT1          equ 0x04
FREEZE_SIDE_EFFECT1        equ 0x05
PARALYZE_SIDE_EFFECT1      equ 0x06
EXPLODE_EFFECT             equ 0x07
DREAM_EATER_EFFECT         equ 0x08
MIRROR_MOVE_EFFECT         equ 0x09
ATTACK_UP1_EFFECT          equ 0x0A
DEFENSE_UP1_EFFECT         equ 0x0B
SPEED_UP1_EFFECT           equ 0x0C
SPECIAL_UP1_EFFECT         equ 0x0D
ACCURACY_UP1_EFFECT        equ 0x0E
EVASION_UP1_EFFECT         equ 0x0F
PAY_DAY_EFFECT             equ 0x10
SWIFT_EFFECT               equ 0x11
ATTACK_DOWN1_EFFECT        equ 0x12
DEFENSE_DOWN1_EFFECT       equ 0x13
SPEED_DOWN1_EFFECT         equ 0x14
SPECIAL_DOWN1_EFFECT       equ 0x15
ACCURACY_DOWN1_EFFECT      equ 0x16
EVASION_DOWN1_EFFECT       equ 0x17
CONVERSION_EFFECT          equ 0x18
HAZE_EFFECT                equ 0x19
BIDE_EFFECT                equ 0x1A
THRASH_PETAL_DANCE_EFFECT  equ 0x1B
SWITCH_AND_TELEPORT_EFFECT equ 0x1C
TWO_TO_FIVE_ATTACKS_EFFECT equ 0x1D
FLINCH_SIDE_EFFECT1        equ 0x1F
SLEEP_EFFECT               equ 0x20
POISON_SIDE_EFFECT2        equ 0x21
BURN_SIDE_EFFECT2          equ 0x22
FREEZE_SIDE_EFFECT2        equ 0x23
PARALYZE_SIDE_EFFECT2      equ 0x24
FLINCH_SIDE_EFFECT2        equ 0x25
OHKO_EFFECT                equ 0x26
CHARGE_EFFECT              equ 0x27
SUPER_FANG_EFFECT          equ 0x28
SPECIAL_DAMAGE_EFFECT      equ 0x29
TRAPPING_EFFECT            equ 0x2A
FLY_EFFECT                 equ 0x2B
ATTACK_TWICE_EFFECT        equ 0x2C
JUMP_KICK_EFFECT           equ 0x2D
MIST_EFFECT                equ 0x2E
FOCUS_ENERGY_EFFECT        equ 0x2F
RECOIL_EFFECT              equ 0x30
CONFUSION_EFFECT           equ 0x31
ATTACK_UP2_EFFECT          equ 0x32
DEFENSE_UP2_EFFECT         equ 0x33
SPEED_UP2_EFFECT           equ 0x34
SPECIAL_UP2_EFFECT         equ 0x35
ACCURACY_UP2_EFFECT        equ 0x36
EVASION_UP2_EFFECT         equ 0x37
HEAL_EFFECT                equ 0x38
TRANSFORM_EFFECT           equ 0x39
ATTACK_DOWN2_EFFECT        equ 0x3A
DEFENSE_DOWN2_EFFECT       equ 0x3B
SPEED_DOWN2_EFFECT         equ 0x3C
SPECIAL_DOWN2_EFFECT       equ 0x3D
ACCURACY_DOWN2_EFFECT      equ 0x3E
EVASION_DOWN2_EFFECT       equ 0x3F
LIGHT_SCREEN_EFFECT        equ 0x40
REFLECT_EFFECT             equ 0x41
POISON_EFFECT              equ 0x42
PARALYZE_EFFECT            equ 0x43
ATTACK_DOWN_SIDE_EFFECT    equ 0x44
DEFENSE_DOWN_SIDE_EFFECT   equ 0x45
SPEED_DOWN_SIDE_EFFECT     equ 0x46
SPECIAL_DOWN_SIDE_EFFECT   equ 0x47
CONFUSION_SIDE_EFFECT      equ 0x4C
TWINEEDLE_EFFECT           equ 0x4D
SUBSTITUTE_EFFECT          equ 0x4F
HYPER_BEAM_EFFECT          equ 0x50
RAGE_EFFECT                equ 0x51
MIMIC_EFFECT               equ 0x52
METRONOME_EFFECT           equ 0x53
LEECH_SEED_EFFECT          equ 0x54
SPLASH_EFFECT              equ 0x55
DISABLE_EFFECT             equ 0x56
NUM_MOVE_EFFECTS           equ 0x56

; --- move ids referenced by battle logic (constants/move_constants.asm) ---
; (Only the handful the engine name-checks; the Moves table is indexed by id.)
NO_MOVE                 equ 0x00
KARATE_CHOP             equ 0x02
COUNTER                 equ 0x44
RAZOR_LEAF              equ 0x4B
CRABHAMMER              equ 0x98
SLASH                   equ 0xA3
STRUGGLE                equ 0xA5

; --- serial / link state (battle RNG boundary) ---
LINK_STATE_BATTLING     equ 0x04

; --- trainer class / species ids name-checked by AI (constants/*.asm) ---
LORELEI                 equ 0x2C       ; trainer class
DEWGONG                 equ 0x78       ; species

; --- battle-mon struct field offsets (battle_struct, macros/ram.asm) ---
; wBattleMon ($D013) and wEnemyMon ($CFE4) share this 29-byte layout. Direct
; per-field WRAM aliases are also defined in gb_memmap.inc; these offsets let
; code index a battle_struct generically (e.g. from a base pointer).
BMON_SPECIES            equ 0x00
BMON_HP                 equ 0x01       ; word (big-endian)
BMON_BOXLEVEL           equ 0x03       ; = PartyPos for player
BMON_STATUS             equ 0x04
BMON_TYPE1              equ 0x05
BMON_TYPE2              equ 0x06
BMON_CATCH_RATE         equ 0x07
BMON_MOVES              equ 0x08       ; 4 bytes
BMON_DVS                equ 0x0C       ; word
BMON_LEVEL              equ 0x0E
BMON_MAXHP              equ 0x0F       ; word
BMON_ATTACK             equ 0x11       ; word
BMON_DEFENSE            equ 0x13       ; word
BMON_SPEED             equ 0x15       ; word
BMON_SPECIAL            equ 0x17       ; word
BMON_PP                 equ 0x19       ; 4 bytes
BATTLE_STRUCT_LENGTH    equ 0x1D       ; 29 bytes

%endif ; GB_CONSTANTS_INC
