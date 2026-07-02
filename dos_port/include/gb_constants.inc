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
NUM_MOVES               equ 4       ; move slots per mon (not total moves in the game)

; --- mon-pic decompressor (constants/gfx_constants.asm) ---
TILE_1BPP_SIZE          equ 8       ; TILE_SIZE/2 — bytes per 1bpp 8×8 tile
PIC_WIDTH               equ 7       ; max pic size in tiles
PIC_HEIGHT              equ 7
SPRITEBUFFERSIZE        equ PIC_WIDTH * PIC_HEIGHT * TILE_1BPP_SIZE  ; 392 = 0x188
NAME_LENGTH             equ 11      ; '@'-terminated fixed-width name field (mon names)
NAME_BUFFER_LENGTH      equ 20      ; wNameBuffer size (GetName dest; bounds the copy)
MOVE_NAME_LENGTH        equ 14      ; constants/text_constants.asm (12 printed + '@' + prefix)
PARTY_LENGTH            equ 6
; Hall-of-Fame record layout (pret constants/pokemon_data_constants.asm:63-65),
; menus S6 package A (league_pc.asm).
HOF_MON                 equ 0x10                    ; 16 bytes per recorded mon
HOF_TEAM                equ PARTY_LENGTH * HOF_MON  ; 96 bytes per recorded team
HOF_TEAM_CAPACITY       equ 50                      ; max HoF teams stored in SRAM
; palette-command id (pret constants/palette_constants.asm:17) — consumed only by
; league_pc's TODO-HW RunPaletteCommand no-op (Phase 5 palette HAL).
SET_PAL_POKEMON_WHOLE_SCREEN equ 0x0B
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
NUM_ATTACKS             equ 165        ; total moves (constants/move_constants.asm)

BANK_MoveNames          equ 0          ; flat model: ROM bank ignored (wPredefBank)

; --- name-list type ids (constants/list_constants.asm; NamePointers index) ---
MONSTER_NAME            equ 1
MOVE_NAME               equ 2
UNUSED_NAME             equ 3
ITEM_NAME               equ 4
PLAYEROT_NAME           equ 5
ENEMYOT_NAME            equ 6
TRAINER_NAME            equ 7

; --- item inventory capacities (constants/menu_constants.asm) ---
BAG_ITEM_CAPACITY       equ 20
PC_ITEM_CAPACITY        equ 50

; --- item ids referenced by item-use effects (constants/item_constants.asm) ---
HP_UP                   equ 0x23    ; first vitamin (PROTEIN/IRON/CARBOS/CALCIUM follow)
RARE_CANDY              equ 0x28
HM01                    equ 0xC4    ; first HM; HMs $C4-$C8, TMs $C9-$FA
TM01                    equ 0xC9    ; first TM (index into TechnicalMachinePrices)
ANTIDOTE                equ 0x0B
BURN_HEAL               equ 0x0C
ICE_HEAL                equ 0x0D
AWAKENING               equ 0x0E
PARLYZ_HEAL             equ 0x0F
HYPER_POTION            equ 0x12
FULL_HEAL               equ 0x34
REVIVE                  equ 0x35
MAX_REVIVE              equ 0x36
MAX_ETHER               equ 0x51

; --- move PP byte fields (constants/battle_constants.asm) ---
PP_UP_MASK              equ 0xC0    ; %11000000, PP Ups applied
PP_MASK                 equ 0x3F    ; %00111111, remaining PP

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

; --- flag-action predef modes (constants/misc_constants.asm) ---
FLAG_RESET              equ 0
FLAG_SET               equ 1
FLAG_TEST              equ 2

; --- evolution trigger types (constants/pokemon_data_constants.asm) ---
EVOLVE_LEVEL           equ 1
EVOLVE_ITEM            equ 2
EVOLVE_TRADE           equ 3

; --- link/evolution ids (evolution.asm; promoted per pokemon_behavior Stage 0) ---
LINK_STATE_TRADING     equ 0x32    ; constants/serial_constants.asm
THUNDER_STONE          equ 0x21    ; item id (constants/item_constants.asm)
THUNDERBOLT            equ 55      ; move id (constants/move_constants.asm)
THUNDER                equ 57      ; move id (constants/move_constants.asm)

; --- move / battle-animation ids (constants/move_constants.asm) ---
ABSORB                 equ 0x47    ; move #71 (Leech Seed drain anim source)
BURN_PSN_ANIM          equ 0xBA    ; battle anim shown on burn/poison residual

; --- misc menu / event constants ---
PIKAHAPPY_LEVELUP      equ 1       ; constants/pikachu_emotion_constants.asm
LEVEL_UP_STATS_BOX     equ 1       ; constants/menu_constants.asm (STATUS_SCREEN=0)

; --- battle init / type (constants/battle_constants.asm, map_constants.asm) ---
BATTLE_TYPE_SAFARI     equ 2
SAFARI_ZONE_EAST       equ 0xD9
SAFARI_ZONE_CENTER_REST_HOUSE equ 0xDD

; --- trainer AI (src/engine/battle/trainer_ai.asm) ---
EFFECT_01              equ 0x01    ; unused sleep effect (StatusAilmentMoveEffects)
XSTATITEM_ANIM          equ 0xAE   ; constants/move_constants.asm line 188 (X Attack/Def/Speed/Special)
XSTATITEM_DUPLICATE_ANIM equ 0xAF  ; constants/move_constants.asm line 189
SHRINKING_SQUARE_ANIM   equ 0xB0   ; constants/move_constants.asm line 190
SLIDE_DOWN_ANIM         equ 0xC0   ; constants/move_constants.asm line 206
; status-condition anim ids (CheckPlayer/EnemyStatusConditions); contiguous const_def
ANIMATIONTYPE_BLINK_ENEMY_MON_SPRITE          equ 4   ; constants/battle_anim_constants.asm
ANIMATIONTYPE_SHAKE_SCREEN_HORIZONTALLY_LIGHT equ 5
STATUS_AFFECTED_ANIM    equ 0xA7   ; constants/move_constants.asm line 181
SLP_PLAYER_ANIM         equ 0xBC   ; line 202 (player sleeping)
SLP_ANIM                equ 0xBD   ; line 203 (enemy sleeping)
CONF_PLAYER_ANIM        equ 0xBE   ; line 204 (player confused)
CONF_ANIM               equ 0xBF   ; line 205 (enemy confused)
; move ids referenced by move-effect handlers (constants/move_constants.asm)
POUND                   equ 0x01
RAZOR_WIND              equ 0x0D
THRASH                  equ 0x25
BIDE                    equ 0x75
ROAR                    equ 0x2E
SOLARBEAM               equ 0x4C
SKULL_BASH              equ 0x82
SKY_ATTACK              equ 0x8F
NUM_TRAINERS           equ 47      ; trainer_constants.asm (LANCE = 0x2F)

; --- item ids used by trainer-AI item use (constants/item_constants.asm) ---
; (HYPER_POTION=0x12 / FULL_HEAL=0x34 already defined above)
FULL_RESTORE           equ 0x10
SUPER_POTION           equ 0x13
POTION                 equ 0x14
X_ACCURACY             equ 0x2E
GUARD_SPEC             equ 0x37
DIRE_HIT               equ 0x3A
X_ATTACK               equ 0x41
X_DEFEND               equ 0x42
X_SPEED                equ 0x43
X_SPECIAL              equ 0x44
BICYCLE                equ 0x06   ; StartMenu_Item special-cases it (skips the USE/TOSS box)

; --- wStatusFlags4/6 bits used by the START menu / bag (constants/ram_constants.asm) ---
BIT_LINK_CONNECTED     equ 6      ; wStatusFlags4: link session active (SAVE → RESET label)
BIT_ALWAYS_ON_BIKE     equ 5      ; wStatusFlags6: map forbids dismounting (Cycling Road)

; --- wild encounter constants (constants/pokemon_data_constants.asm) ---
NUM_WILDMONS            equ 10
WILDDATA_LENGTH         equ 1 + NUM_WILDMONS * 2   ; = 21 (rate + 10×(level,species))

; --- map / tileset constants used by wild-encounter generation ---
; FIRST_INDOOR_MAP = REDS_HOUSE_1F ($25); FOREST = Viridian Forest/Safari tileset.
FIRST_INDOOR_MAP        equ 0x25
FOREST                  equ 3

; --- MINIMIZE move id + stat-name length (stat-modifier effects, Stage 5) ---
MINIMIZE                equ 0x6B
STAT_NAME_LENGTH        equ 10
RAGE                    equ 63         ; move id (HandleBuildingRage restores it)
TOXIC                   equ 0x5C       ; move id (PoisonEffect: badly-poison branch)

; --- battle animation ids (constants/move_constants.asm; move-effect handlers) ---
ENEMY_HUD_SHAKE_ANIM    equ 0xA9
SHAKE_SCREEN_ANIM       equ 0xC7

; --- text id: "REPEL's effect wore off" (constants/text_constants.asm) ---
TEXT_REPEL_WORE_OFF     equ 0xD2

; --- move record load (GetCurrentMove) ---
; (MOVE_LENGTH defined once in the Moves-table-record section above.)
BIT_TEST_BATTLE         equ 0          ; wStatusFlags7 bit (debug TestBattle)

; --- auto text-box drawing control (EnableAutoTextBoxDrawing) ---
BIT_NO_AUTO_TEXT_BOX    equ 0          ; wAutoTextBoxDrawingControl bit

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

; --- move ids consumed by ApplyAttackTo*Pokemon special-damage dispatch ---
; (values from constants/move_constants.asm; canonical Gen-1 move indices)
SONICBOOM               equ 0x31    ; 49
SEISMIC_TOSS            equ 0x45    ; 69
DRAGON_RAGE             equ 0x52    ; 82
NIGHT_SHADE             equ 0x65    ; 101
PSYWAVE                 equ 0x95    ; 149

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
QUICK_ATTACK            equ 0x62       ; turn-order priority (ExecutePlayerTurn)
CRABHAMMER              equ 0x98
SLASH                   equ 0xA3
STRUGGLE                equ 0xA5

; --- field-move ids (data/moves/field_moves.asm; lifted out of party_menu.asm) ---
CUT                     equ 0x0F
FLY                     equ 0x13
SURF                    equ 0x39
STRENGTH                equ 0x46
DIG                     equ 0x5B
TELEPORT                equ 0x64
SOFTBOILED              equ 0x87
FLASH                   equ 0x94

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

; --- number/BCD printing flag bits (constants/text_constants.asm) ---
; Passed in the high bits of the flags byte to PrintNumber / PrintBCDNumber.
BIT_MONEY_SIGN          equ 5          ; prepend '¥' currency glyph (BCD)
BIT_LEFT_ALIGN          equ 6          ; left-justify (don't pad leading positions)
BIT_LEADING_ZEROES      equ 7          ; print leading zeroes instead of spaces

; ---------------------------------------------------------------------------
; Wave 4 (home-rectification) — menu framework constants (pret constants/
; menu_constants.asm + list_constants.asm). Members carry identical-value local
; placeholders; these are canonical.
; ---------------------------------------------------------------------------
; wListMenuID values
PCPOKEMONLISTMENU       equ 0x00
MOVESLISTMENU           equ 0x01
PRICEDITEMLISTMENU      equ 0x02
ITEMLISTMENU            equ 0x03
; wTextBoxID (pret constants/menu_constants.asm text box IDs; JP_* templates
; omitted — the port ships the EN tables only, matching the S1 layout seeder)
MESSAGE_BOX                       equ 0x01
MENU_TEMPLATE_03                  equ 0x03   ; unused in pret
FIELD_MOVE_MON_MENU               equ 0x04
USE_TOSS_MENU_TEMPLATE            equ 0x06
MENU_TEMPLATE_07                  equ 0x07   ; unused in pret
BATTLE_MENU_TEMPLATE              equ 0x0B
SWITCH_STATS_CANCEL_MENU_TEMPLATE equ 0x0C
LIST_MENU_BOX           equ 0x0D
BUY_SELL_QUIT_MENU_TEMPLATE       equ 0x0E
MONEY_BOX_TEMPLATE                equ 0x0F
MENU_TEMPLATE_10                  equ 0x10   ; unused in pret
MON_SPRITE_POPUP                  equ 0x11
TWO_OPTION_MENU         equ 0x14
BUY_SELL_QUIT_MENU                equ 0x15
SAFARI_BATTLE_MENU_TEMPLATE       equ 0x1B
; wPartyMenuTypeOrMessageID values (pret constants/menu_constants.asm)
NORMAL_PARTY_MENU       equ 0x00
USE_ITEM_PARTY_MENU     equ 0x01
BATTLE_PARTY_MENU       equ 0x02
TMHM_PARTY_MENU         equ 0x03
SWAP_MONS_PARTY_MENU    equ 0x04
EVO_STONE_PARTY_MENU    equ 0x05
FIRST_PARTY_MENU_TEXT_ID equ 0x06  ; ids >= this select PartyMenuItemUseMessagePointers
; hUILayoutFlags bit (pret constants/gfx_constants.asm; BIT_SINGLE_SPACED_LINES
; already lives in gb_memmap.inc's H_UI_LAYOUT_FLAGS block)
BIT_PARTY_MENU_HP_BAR   equ 0      ; DrawHP_: HP fraction right of the bar, not below
; wTwoOptionMenuID variants
YES_NO_MENU             equ 0x00
NORTH_WEST_MENU         equ 0x01
SOUTH_EAST_MENU         equ 0x02
WIDE_YES_NO_MENU        equ 0x03
NORTH_EAST_MENU         equ 0x04
TRADE_CANCEL_MENU       equ 0x05
HEAL_CANCEL_MENU        equ 0x06
NO_YES_MENU             equ 0x07
BIT_SECOND_MENU_OPTION_DEFAULT equ 7
; wMenuExitMethod
CHOSE_MENU_ITEM         equ 0x01
CHOSE_FIRST_ITEM        equ 0x01
CHOSE_SECOND_ITEM       equ 0x02
CANCELLED_MENU          equ 0x02

; ---------------------------------------------------------------------------
; Wave 5 (home-rectification) — pokemon/item constants (pret menu_constants.asm /
; pokemon_constants.asm).
; ---------------------------------------------------------------------------
MONEY_BOX               equ 0x13   ; wTextBoxID: money display box
; wMonDataLocation move directions (menu_constants.asm)
BOX_TO_PARTY            equ 0x00
PARTY_TO_BOX            equ 0x01
DAYCARE_TO_PARTY        equ 0x02
PARTY_TO_DAYCARE        equ 0x03
; special sprite-ID mons with no BaseStats row (pokemon_constants.asm)
FOSSIL_KABUTOPS         equ 0xB6
FOSSIL_AERODACTYL       equ 0xB7
MON_GHOST               equ 0xB8

%endif ; GB_CONSTANTS_INC
