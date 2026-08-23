; gb_constants.inc — Pokémon data-structure offsets and engine constants.
;
; Emitted as %define (a preprocessor MACRO), not equ. NASM emits every `equ` as a
; local ABSOLUTE COFF symbol -- without `global`, and whether or not the file uses
; it -- so a shared constants header lands its whole contents in EVERY object that
; includes it. Measured 2026-08-19: that was ~2.05M symbol entries and 39 MB of a
; 41 MB PKMN.EXE, against ~2.4 MB of real .text+.data. A %define expands textually,
; emits no symbol, and generates byte-identical code. Constants are not code
; addresses: none of them ever appeared in pkmn.sym, so nothing debuggable is lost.
; Source of truth: constants/pokemon_data_constants.asm (repo root, pret spec).
; These mirror the rgbds `rsreset`/`rb`/`rw` struct definitions as plain NASM
; `equ`s so the translated Pokémon-engine routines (add_mon, load_mon_data,
; calc stats, …) can index party/box/base-stat structs by symbolic offset.
;
; NUM_STATS = 5 (HP, Atk, Def, Spd, Spc); NUM_MOVES = 4.

%ifndef GB_CONSTANTS_INC
%define GB_CONSTANTS_INC

%define NUM_STATS                    5
%define NUM_MOVES                    4   ; move slots per mon (not total moves in the game)

; --- mon-pic decompressor (constants/gfx_constants.asm) ---
%define TILE_1BPP_SIZE               8   ; TILE_SIZE/2 — bytes per 1bpp 8×8 tile
%define PIC_WIDTH                    7   ; max pic size in tiles
%define PIC_HEIGHT                   7
%define PIC_SIZE                     (PIC_WIDTH * PIC_HEIGHT)   ; 49 tiles (constants/gfx_constants.asm)
%define SPRITEBUFFERSIZE             (PIC_WIDTH * PIC_HEIGHT * TILE_1BPP_SIZE)   ; 392 = 0x188
%define NAME_LENGTH                  11   ; '@'-terminated fixed-width name field (mon names)
%define NAME_LENGTH_JP               6   ; JP name length (OT-name compare in pikachu_status)
%define NAME_BUFFER_LENGTH           20   ; wNameBuffer size (GetName dest; bounds the copy)
%define MOVE_NAME_LENGTH             14   ; constants/text_constants.asm (12 printed + '@' + prefix)
%define PARTY_LENGTH                 6
; Hall-of-Fame record layout (pret constants/pokemon_data_constants.asm:63-65),
; menus S6 package A (league_pc.asm).
%define HOF_MON                      0x10   ; 16 bytes per recorded mon
%define HOF_TEAM                     (PARTY_LENGTH * HOF_MON)   ; 96 bytes per recorded team
%define HOF_TEAM_CAPACITY            50   ; max HoF teams stored in SRAM
; palette-command id (pret constants/palette_constants.asm:17) — consumed only by
; league_pc's TODO-HW RunPaletteCommand no-op (Phase 5 palette HAL).
%define SET_PAL_POKEMON_WHOLE_SCREEN 0x0B
%define MONS_PER_BOX                 20
%define NUM_BOXES                    12
%define NUM_TMS                      50
%define NUM_HMS                      5
%define NUM_TM_HM                    (NUM_TMS + NUM_HMS)   ; 55

; --- base data struct (data/pokemon/base_stats/*.asm) ---
%define BASE_DEX_NO                  0x00
%define BASE_STATS                   0x01   ; 5 bytes
%define BASE_HP                      0x01
%define BASE_ATK                     0x02
%define BASE_DEF                     0x03
%define BASE_SPD                     0x04
%define BASE_SPC                     0x05
%define BASE_TYPE_1                  0x06
%define BASE_TYPE_2                  0x07
%define BASE_CATCH_RATE              0x08
%define BASE_EXP                     0x09
%define BASE_PIC_SIZE                0x0A
%define BASE_FRONTPIC                0x0B   ; word
%define BASE_BACKPIC                 0x0D   ; word
%define BASE_MOVES                   0x0F   ; 4 bytes
%define BASE_GROWTH_RATE             0x13
%define BASE_TMHM                    0x14   ; (NUM_TM_HM + 7) / 8 = 7 bytes
%define BASE_DATA_SIZE               0x1C   ; 28 bytes total (incl. 1 padding byte)

; --- party_struct / box_struct members (macros/ram.asm) ---
; GEN-2 FORWARD-COMPAT: these offsets and the struct lengths below
; (PARTYMON=44, BOXMON=33) must stay byte-identical to Gen 1. Gen 2's Time
; Capsule stores a traded mon's HELD ITEM in the MON_CATCH_RATE byte (+7), so
; that slot is load-bearing for the planned Gen 2 port — do NOT repurpose it or
; shrink/realign the struct. Party↔box conversion (deposit/withdraw, when added)
; must preserve +7 verbatim.
%define MON_SPECIES                  0x00
%define MON_HP                       0x01   ; word (big-endian)
%define MON_BOX_LEVEL                0x03
%define MON_STATUS                   0x04
%define MON_TYPE                     0x05
%define MON_TYPE1                    0x05
%define MON_TYPE2                    0x06
%define MON_CATCH_RATE               0x07
%define MON_MOVES                    0x08   ; 4 bytes
%define MON_OTID                     0x0C   ; word
%define MON_EXP                      0x0E   ; 3 bytes (big-endian)
%define MON_HP_EXP                   0x11   ; word
%define MON_ATK_EXP                  0x13   ; word
%define MON_DEF_EXP                  0x15   ; word
%define MON_SPD_EXP                  0x17   ; word
%define MON_SPC_EXP                  0x19   ; word
%define MON_DVS                      0x1B   ; word
%define MON_PP                       0x1D   ; 4 bytes
%define BOXMON_STRUCT_LENGTH         0x21   ; 33
%define MON_LEVEL                    0x21
%define MON_STATS                    0x22   ; 5 words
%define MON_MAXHP                    0x22
%define MON_ATK                      0x24
%define MON_DEF                      0x26
%define MON_SPD                      0x28
%define MON_SPC                      0x2A
%define PARTYMON_STRUCT_LENGTH       0x2C   ; 44

%define STARTER_PIKACHU              84   ; = PIKACHU internal index ($54); pikachu_status
%define MAGIKARP                     0x85   ; internal index (constants/pokemon_constants.asm); ItemUseOldRod's fixed catch

; --- Moves table record (data/moves/moves.asm; gen_moves.py) ---
%define MOVE_LENGTH                  6
%define MOVE_ANIM                    0x00
%define MOVE_EFFECT                  0x01
%define MOVE_POWER                   0x02
%define MOVE_TYPE                    0x03
%define MOVE_ACC                     0x04
%define MOVE_PP                      0x05
; (NUM_ATTACKS now comes from the generated battle_anim_constants.inc, included below)

%define BANK_MoveNames               0   ; flat model: ROM bank ignored (wPredefBank)

; --- name-list type ids (constants/list_constants.asm; NamePointers index) ---
%define MONSTER_NAME                 1
%define MOVE_NAME                    2
%define UNUSED_NAME                  3
%define ITEM_NAME                    4
%define PLAYEROT_NAME                5
%define ENEMYOT_NAME                 6
%define TRAINER_NAME                 7

; --- item inventory capacities (constants/menu_constants.asm) ---
%define BAG_ITEM_CAPACITY            20
%define PC_ITEM_CAPACITY             50

; --- item ids referenced by item-use effects (constants/item_constants.asm) ---
%define MASTER_BALL                  0x01   ; the four ball ids ItemUseBall's catch math keys on
%define ULTRA_BALL                   0x02
%define GREAT_BALL                   0x03
%define POKE_BALL                    0x04
%define SAFARI_BALL                  0x08
; SAFARI_ROCK is pret's deliberate OVERLOAD of the CASCADEBADGE item id
; (constants/item_constants.asm:34 — `DEF SAFARI_ROCK EQU CASCADEBADGE`, $16).
; PartyMenuOrRockOrRun stores it in wCurItem so UseBagItem runs the rock.
; SAFARI_BAIT is pret's matching overload of the BOULDERBADGE item id
; (constants/item_constants.asm:32 — `DEF SAFARI_BAIT EQU BOULDERBADGE`, $15).
; DisplayBattleMenu's ITEM slot stores it in wCurItem in a Safari battle.
%define SAFARI_BAIT                  0x15
%define SAFARI_ROCK                  0x16
%define HP_UP                        0x23   ; first vitamin (PROTEIN/IRON/CARBOS/CALCIUM follow)
%define PROTEIN                      0x24
%define IRON                         0x25
%define CARBOS                       0x26
%define CALCIUM                      0x27   ; last vitamin before RARE_CANDY
%define RARE_CANDY                   0x28
%define HM01                         0xC4   ; first HM; HMs $C4-$C8, TMs $C9-$FA
%define TM01                         0xC9   ; first TM (index into TechnicalMachinePrices)

; --- the TM/HM item ids, under their pret names -----------------------------
; constants/item_constants.asm `add_hm` (:141-) and `add_tm` (:161-) blocks, in
; pret's definition order. Scripts must use these NAMES rather than a literal or
; TM01+n arithmetic: pret writes `lb bc, TM_BUBBLEBEAM, 1`, and the name is the
; only form a reader can check against the disassembly without doing sums.
; Each id is expressed off HM01/TM01 so the sequence property stays visible and
; the base lives in exactly one place. Trailing comment = the TM/HM number the
; game shows the player, then the raw id.
%define HM_CUT                       (HM01 + 0)   ; HM01 = $C4
%define HM_FLY                       (HM01 + 1)   ; HM02 = $C5
%define HM_SURF                      (HM01 + 2)   ; HM03 = $C6
%define HM_STRENGTH                  (HM01 + 3)   ; HM04 = $C7
%define HM_FLASH                     (HM01 + 4)   ; HM05 = $C8

%define TM_MEGA_PUNCH                (TM01 + 0)   ; TM01 = $C9
%define TM_RAZOR_WIND                (TM01 + 1)   ; TM02 = $CA
%define TM_SWORDS_DANCE              (TM01 + 2)   ; TM03 = $CB
%define TM_WHIRLWIND                 (TM01 + 3)   ; TM04 = $CC
%define TM_MEGA_KICK                 (TM01 + 4)   ; TM05 = $CD
%define TM_TOXIC                     (TM01 + 5)   ; TM06 = $CE
%define TM_HORN_DRILL                (TM01 + 6)   ; TM07 = $CF
%define TM_BODY_SLAM                 (TM01 + 7)   ; TM08 = $D0
%define TM_TAKE_DOWN                 (TM01 + 8)   ; TM09 = $D1
%define TM_DOUBLE_EDGE               (TM01 + 9)   ; TM10 = $D2
%define TM_BUBBLEBEAM                (TM01 + 10)   ; TM11 = $D3
%define TM_WATER_GUN                 (TM01 + 11)   ; TM12 = $D4
%define TM_ICE_BEAM                  (TM01 + 12)   ; TM13 = $D5
%define TM_BLIZZARD                  (TM01 + 13)   ; TM14 = $D6
%define TM_HYPER_BEAM                (TM01 + 14)   ; TM15 = $D7
%define TM_PAY_DAY                   (TM01 + 15)   ; TM16 = $D8
%define TM_SUBMISSION                (TM01 + 16)   ; TM17 = $D9
%define TM_COUNTER                   (TM01 + 17)   ; TM18 = $DA
%define TM_SEISMIC_TOSS              (TM01 + 18)   ; TM19 = $DB
%define TM_RAGE                      (TM01 + 19)   ; TM20 = $DC
%define TM_MEGA_DRAIN                (TM01 + 20)   ; TM21 = $DD
%define TM_SOLARBEAM                 (TM01 + 21)   ; TM22 = $DE
%define TM_DRAGON_RAGE               (TM01 + 22)   ; TM23 = $DF
%define TM_THUNDERBOLT               (TM01 + 23)   ; TM24 = $E0 — Pikachu's mood bonus (ItemUseTMHM)
%define TM_THUNDER                   (TM01 + 24)   ; TM25 = $E1 — likewise
%define TM_EARTHQUAKE                (TM01 + 25)   ; TM26 = $E2
%define TM_FISSURE                   (TM01 + 26)   ; TM27 = $E3
%define TM_DIG                       (TM01 + 27)   ; TM28 = $E4
%define TM_PSYCHIC_M                 (TM01 + 28)   ; TM29 = $E5
%define TM_TELEPORT                  (TM01 + 29)   ; TM30 = $E6
%define TM_MIMIC                     (TM01 + 30)   ; TM31 = $E7
%define TM_DOUBLE_TEAM               (TM01 + 31)   ; TM32 = $E8
%define TM_REFLECT                   (TM01 + 32)   ; TM33 = $E9
%define TM_BIDE                      (TM01 + 33)   ; TM34 = $EA
%define TM_METRONOME                 (TM01 + 34)   ; TM35 = $EB
%define TM_SELFDESTRUCT              (TM01 + 35)   ; TM36 = $EC
%define TM_EGG_BOMB                  (TM01 + 36)   ; TM37 = $ED
%define TM_FIRE_BLAST                (TM01 + 37)   ; TM38 = $EE
%define TM_SWIFT                     (TM01 + 38)   ; TM39 = $EF
%define TM_SKULL_BASH                (TM01 + 39)   ; TM40 = $F0
%define TM_SOFTBOILED                (TM01 + 40)   ; TM41 = $F1
%define TM_DREAM_EATER               (TM01 + 41)   ; TM42 = $F2
%define TM_SKY_ATTACK                (TM01 + 42)   ; TM43 = $F3
%define TM_REST                      (TM01 + 43)   ; TM44 = $F4
%define TM_THUNDER_WAVE              (TM01 + 44)   ; TM45 = $F5
%define TM_PSYWAVE                   (TM01 + 45)   ; TM46 = $F6
%define TM_EXPLOSION                 (TM01 + 46)   ; TM47 = $F7
%define TM_ROCK_SLIDE                (TM01 + 47)   ; TM48 = $F8
%define TM_TRI_ATTACK                (TM01 + 48)   ; TM49 = $F9
%define TM_SUBSTITUTE                (TM01 + 49)   ; TM50 = $FA
%define ANTIDOTE                     0x0B
%define BURN_HEAL                    0x0C
%define ICE_HEAL                     0x0D
%define AWAKENING                    0x0E
%define PARLYZ_HEAL                  0x0F
%define HYPER_POTION                 0x12
%define FULL_HEAL                    0x34
%define REVIVE                       0x35
%define MAX_REVIVE                   0x36
%define SURFBOARD                    0x07   ; ItemUseSurfboard (the SURF field-move item)
; Key items the map scripts hand out (constants/item_constants.asm), named here
; for the same reason as the TM/HM block above: pret writes `lb bc, TOWN_MAP, 1`.
%define TOWN_MAP                     0x05   ; constants/item_constants.asm:14
%define OLD_AMBER                    0x1F   ; :43
%define BIKE_VOUCHER                 0x2D   ; :57
%define S_S_TICKET                   0x3F   ; :75
%define OAKS_PARCEL                  0x46   ; :82
%define POKE_FLUTE                   0x49   ; :85
%define COIN_CASE                    0x45   ; constants/item_constants.asm:81 — AbleToPlaySlotsCheck
%define OLD_ROD                      0x4C   ; constants/item_constants.asm — fishing rods
%define GOOD_ROD                     0x4D
%define SUPER_ROD                    0x4E
; The PP family is a contiguous run in pret constants/item_constants.asm — the
; adjacency is load-bearing: ItemUsePPRestore's .useElixir decrements the item id
; TWICE so ELIXER becomes ETHER and MAX_ELIXER becomes MAX_ETHER.
%define PP_UP                        0x4F
%define ETHER                        0x50
%define MAX_ETHER                    0x51
%define ELIXER                       0x52
%define MAX_ELIXER                   0x53

; --- move PP byte fields (constants/battle_constants.asm) ---
%define PP_UP_MASK                   0xC0   ; %11000000, PP Ups applied
%define PP_MASK                      0x3F   ; %00111111, remaining PP

; --- battle-animation ids + SE/subanim-type constants: GENERATED (Tier-1) ---
; The whole anim-id tail (STATUS_AFFECTED_ANIM..BAIT_ANIM), SE_* command ids,
; SUBANIMTYPE_*/FRAMEBLOCKMODE_*, ANIMATIONTYPE_* and NUM_* sizes come from
; gen_battle_anim_data.py; the hand equs that used to sit scattered through this
; file were removed when it landed (battle-animations plan Stage 1).
%include "assets/battle_anim_constants.inc"

; --- naming-screen types (constants/menu_constants.asm) ---
%define NAME_PLAYER_SCREEN           0
%define NAME_RIVAL_SCREEN            1
%define NAME_MON_SCREEN              2

; --- the ghost Marowak (constants/pokemon_constants.asm: RESTLESS_SOUL = MAROWAK) ---
%define MAROWAK                      0x91   ; internal species index
%define RESTLESS_SOUL                (MAROWAK)   ; Pokémon Tower 6F's uncatchable ghost
%define DITTO                        0x4C   ; internal index (Transform → assumed Ditto)

; --- Gen-2 forward-compat: held item carried in the catch-rate byte ---
; The party/box mon struct's MON_CATCH_RATE byte (offset 7) is Gen 2's held-item
; slot across the Time Capsule. Kadabra ships holding a TwistedSpoon (pret).
%define KADABRA                      0x26   ; internal species index
%define TWISTEDSPOON_GSC             0x60   ; Gen-2 held item id stored in the catch-rate byte

; --- mon data locations (wMonDataLocation values) ---
%define PLAYER_PARTY_DATA            0
%define ENEMY_PARTY_DATA             1
%define BOX_DATA                     2
%define DAYCARE_DATA                 3
%define BATTLE_MON_DATA              4

; --- growth rates (index into GrowthRateTable) ---
%define GROWTH_MEDIUM_FAST           0
%define GROWTH_SLIGHTLY_FAST         1
%define GROWTH_SLIGHTLY_SLOW         2
%define GROWTH_MEDIUM_SLOW           3
%define GROWTH_FAST                  4
%define GROWTH_SLOW                  5

%define MAX_STAT_VALUE               999
%define MAX_LEVEL                    100

; --- flag-action predef modes (constants/misc_constants.asm) ---
%define FLAG_RESET                   0
%define FLAG_SET                     1
%define FLAG_TEST                    2

; --- evolution trigger types (constants/pokemon_data_constants.asm) ---
%define EVOLVE_LEVEL                 1
%define EVOLVE_ITEM                  2
%define EVOLVE_TRADE                 3

; --- link/evolution ids (evolution.asm; promoted per pokemon_behavior Stage 0) ---
%define LINK_STATE_TRADING           0x32   ; constants/serial_constants.asm
%define THUNDER_STONE                0x21   ; item id (constants/item_constants.asm)
%define THUNDERBOLT                  0x55   ; move id 0x55 (constants/move_constants.asm ; 55 = hex). Was `equ 55` (=0x37): pret's hex comment misread as decimal — broke Pikachu's THUNDER/THUNDERBOLT mood boost (evos_moves.asm) and the anim-id dispatch. Fixed 2026-08-07.
%define THUNDER                      0x57   ; move id 0x57 (constants/move_constants.asm ; 57 = hex). Was `equ 57` (=0x39, collided with SURF): pret's hex comment misread as decimal — broke Pikachu's THUNDER mood boost (evos_moves.asm). Fixed 2026-08-07.

; --- move ids (constants/move_constants.asm) ---
%define ABSORB                       0x47   ; move #71 (Leech Seed drain anim source)

; --- misc menu / event constants ---
%define PIKAHAPPY_LEVELUP            1   ; constants/pikachu_emotion_constants.asm
%define PIKAHAPPY_USEDITEM           2   ; (ItemUseMedicine: a non-vitamin item was used on a mon)
%define PIKAHAPPY_USEDXITEM          3   ; (X Accuracy / X Attack&co / Dire Hit / Guard Spec)
%define PIKAHAPPY_GYMLEADER          4   ; (checks the WHOLE party, not the acted-on mon)
%define PIKAHAPPY_USEDTMHM           5   ; (ItemUseTMHM: a TM/HM was taught to a party mon)
%define PIKAHAPPY_WALKING            6   ; (checks the WHOLE party, not the acted-on mon)
%define PIKAHAPPY_DEPOSITED          7   ; (BillsPCDeposit: starter Pikachu was boxed)
%define PIKAHAPPY_FAINTED            8   ; (fainted in battle)
%define PIKAHAPPY_PSNFNT             9   ; (fainted to poison outside battle)
%define PIKAHAPPY_CARELESSTRAINER    10   ; (fainted to a mon 30+ levels higher)
%define PIKAHAPPY_TRADE              11   ; (traded away)
%define STATUS_SCREEN_STATS_BOX      0   ; constants/menu_constants.asm (PrintStatsBox d=0 → status-screen box)
%define LEVEL_UP_STATS_BOX           1   ; constants/menu_constants.asm (STATUS_SCREEN=0)
%define SET_PAL_BATTLE_BLACK         0x00   ; constants/palette_constants.asm (RunPaletteCommand id)
%define SET_PAL_BATTLE               0x01   ; constants/palette_constants.asm (RunPaletteCommand id)
%define SET_PAL_STATUS_SCREEN        0x03   ; constants/palette_constants.asm (RunPaletteCommand id)
%define SET_PAL_OVERWORLD            0x09   ; constants/palette_constants.asm (RunPaletteCommand id)
%define SET_PAL_TITLE_SCREEN         0x06   ; constants/palette_constants.asm (RunPaletteCommand id)
%define BIT_UNUSED_CARD_KEY          7   ; constants/ram_constants.asm (wStatusFlags1 bit; never read)
%define BIT_NO_AUDIO_FADE_OUT        1   ; constants/ram_constants.asm (wStatusFlags2 bit)
%define BIT_WILD_ENCOUNTER_COOLDOWN  0   ; constants/ram_constants.asm (wStatusFlags2 bit)
%define CHAN5                        4   ; constants/audio_constants.asm (5th sound channel index)
%define LEADING_ZEROES               0x80   ; PrintNumber flag (1<<BIT_LEADING_ZEROES): print '0' not space

; --- battle init / type (constants/battle_constants.asm, map_constants.asm) ---
%define BATTLE_TYPE_SAFARI           2
%define SAFARI_ZONE_EAST             0xD9
%define SAFARI_ZONE_CENTER_REST_HOUSE 0xDD

; --- trainer AI (src/engine/battle/trainer_ai.asm) ---
%define EFFECT_01                    0x01   ; unused sleep effect (StatusAilmentMoveEffects)
; (anim-id constants moved to the generated assets/battle_anim_constants.inc, included above)
; move ids referenced by move-effect handlers (constants/move_constants.asm)
%define POUND                        0x01
%define RAZOR_WIND                   0x0D
%define THRASH                       0x25
%define BIDE                         0x75
%define ROAR                         0x2E
%define SOLARBEAM                    0x4C
%define SKULL_BASH                   0x82
%define SKY_ATTACK                   0x8F
; move ids referenced by the battle-animation dispatch tables (SpecialEffectPointers /
; AnimationIdSpecialEffects) and interpreter (constants/move_constants.asm hex comments):
%define MEGA_PUNCH                   0x05
%define GUILLOTINE                   0x0C
%define MEGA_KICK                    0x19
%define HEADBUTT                     0x1D
%define TAIL_WHIP                    0x27
%define GROWL                        0x2D
%define DISABLE                      0x32
%define BLIZZARD                     0x3B
%define BUBBLEBEAM                   0x3D
%define HYPER_BEAM                   0x3F
%define REFLECT                      0x73
%define SELFDESTRUCT                 0x78
%define AMNESIA                      0x85
%define SPORE                        0x93
%define EXPLOSION                    0x99
%define REST 0x9C       ; move id 0x9C — %define, not equ: REST is a NASM-reserved token
%define ROCK_SLIDE                   0x9D
%define NUM_TRAINERS                 47   ; trainer_constants.asm (LANCE = 0x2F)

; --- item ids used by trainer-AI item use (constants/item_constants.asm) ---
; (HYPER_POTION=0x12 / FULL_HEAL=0x34 already defined above)
%define FULL_RESTORE                 0x10
%define SUPER_POTION                 0x13
%define POTION                       0x14
%define MAX_POTION                   0x11
%define FRESH_WATER                  0x3C
%define SODA_POP                     0x3D
%define LEMONADE                     0x3E
%define X_ACCURACY                   0x2E
%define GUARD_SPEC                   0x37
%define DIRE_HIT                     0x3A
%define X_ATTACK                     0x41
%define X_DEFEND                     0x42
%define X_SPEED                      0x43
%define X_SPECIAL                    0x44
%define ITEMFINDER                   0x47
%define BICYCLE                      0x06   ; StartMenu_Item special-cases it (skips the USE/TOSS box)

; --- wStatusFlags4/6 bits used by the START menu / bag (constants/ram_constants.asm) ---
%define BIT_TEXT_PREDEF              0   ; wTextPredefFlag: PrintPredefTextID table active
%define BIT_LINK_CONNECTED           6   ; wStatusFlags4: link session active (SAVE → RESET label)
%define BIT_ALWAYS_ON_BIKE           5   ; wStatusFlags6: map forbids dismounting (Cycling Road)

; --- joypad button masks (constants/hardware.inc:96-97) ---
%ifndef PAD_CTRL_PAD
%define PAD_CTRL_PAD                 0xF0   ; %1111_0000 — D-pad (down/up/left/right)
%endif
%ifndef PAD_BUTTONS
%define PAD_BUTTONS                  0x0F   ; %0000_1111 — A/B/SELECT/START
%endif

; --- wild encounter constants (constants/pokemon_data_constants.asm) ---
%define NUM_WILDMONS                 10
%define WILDDATA_LENGTH              (1 + NUM_WILDMONS * 2)   ; = 21 (rate + 10×(level,species))

; --- map / tileset constants used by wild-encounter generation ---
; FIRST_INDOOR_MAP = REDS_HOUSE_1F ($25); FOREST = Viridian Forest/Safari tileset.
%define FIRST_INDOOR_MAP             0x25
%define LAST_MAP                     0xFF   ; constants/map_constants.asm:406 — warp destination meaning
                                    ; "return to wLastMap" (the outside map you came from)
%define FOREST                       3

; --- MINIMIZE move id + stat-name length (stat-modifier effects, Stage 5) ---
%define MINIMIZE                     0x6B
%define STAT_NAME_LENGTH             10
%define RAGE                         0x63   ; move id 0x63 (HandleBuildingRage restores it; pret ; 63 = hex). Was `equ 63` (=0x3F): pret's hex comment misread as decimal — broke Rage move detection/name. Fixed 2026-08-07.
%define TOXIC                        0x5C   ; move id (PoisonEffect: badly-poison branch)

; --- DisplayTextID special text IDs (constants/text_constants.asm) ---
%define TEXT_MON_FAINTED             0xD0
%define TEXT_BLACKED_OUT             0xD1
%define TEXT_REPEL_WORE_OFF          0xD2
%define TEXT_SAFARI_GAME_OVER        0xD3
%define TEXT_PIKACHU_ANIM            0xD4

; --- DisplayTextID TX_SCRIPT sentinels (macros/scripts/text.asm) ---
%define TX_SCRIPT_POKECENTER_NURSE   0xFF
%define TX_SCRIPT_MART               0xFE
%define TX_SCRIPT_BILLS_PC           0xFD
%define TX_SCRIPT_PLAYERS_PC         0xFC
%define TX_SCRIPT_POKECENTER_PC      0xF9
%define TX_SCRIPT_PRIZE_VENDOR       0xF7
%define TX_SCRIPT_CABLE_CLUB_RECEPTIONIST 0xF6
%define TX_SCRIPT_VENDING_MACHINE    0xF5

; --- move record load (GetCurrentMove) ---
; (MOVE_LENGTH defined once in the Moves-table-record section above.)
%define BIT_TEST_BATTLE              0   ; wStatusFlags7 bit (debug TestBattle)

; --- auto text-box drawing control (EnableAutoTextBoxDrawing) ---
%define BIT_NO_AUTO_TEXT_BOX         0   ; wAutoTextBoxDrawingControl bit

; ===========================================================================
; Battle engine constants (current_plan_battle_engine.md)
; Sources: constants/battle_constants.asm, type_constants.asm,
;          move_effect_constants.asm, move_constants.asm.
; ===========================================================================

; --- significant stat values (stat-stage modifier range, base = 7) ---
%define BASE_STAT_LEVEL              7
%define MAX_STAT_LEVEL               13

; --- VitaminStats / stat indexes (1-based, see data/battle/stat_names.asm) ---
%define STAT_HEALTH                  1
%define STAT_ATTACK                  2
%define STAT_DEFENSE                 3
%define STAT_SPEED                   4
%define STAT_SPECIAL                 5

; --- StatModTextStrings indexes (0-based; wWhichStat / stat-mod handlers) ---
%define MOD_ATTACK                   0
%define MOD_DEFENSE                  1
%define MOD_SPEED                    2
%define MOD_SPECIAL                  3
%define MOD_ACCURACY                 4
%define MOD_EVASION                  5
%define NUM_STAT_MODS                8   ; const_value after const_skip 2

; --- battle type constants (wBattleType values) ---
%define BATTLE_TYPE_NORMAL           0
%define BATTLE_TYPE_OLD_MAN          1
%define BATTLE_TYPE_SAFARI           2
%define BATTLE_TYPE_RUN              3
%define BATTLE_TYPE_PIKACHU          4

; --- damage limits before type effectiveness ---
%define MIN_NEUTRAL_DAMAGE           2
%define MAX_NEUTRAL_DAMAGE           999

; --- fixed-damage move constants ---
%define SONICBOOM_DAMAGE             20
%define DRAGON_RAGE_DAMAGE           40

; --- move ids consumed by ApplyAttackTo*Pokemon special-damage dispatch ---
; (values from constants/move_constants.asm; canonical Gen-1 move indices)
%define SONICBOOM                    0x31   ; 49
%define SEISMIC_TOSS                 0x45   ; 69
%define DRAGON_RAGE                  0x52   ; 82
%define NIGHT_SHADE                  0x65   ; 101
%define PSYWAVE                      0x95   ; 149

; --- type effectiveness factors, scaled by 10 (TypeEffects table values) ---
%define SUPER_EFFECTIVE              20
%define MORE_EFFECTIVE               15
%define EFFECTIVE                    10
%define NOT_VERY_EFFECTIVE           5
%define NO_EFFECT                    0

; --- non-volatile status (wBattleMonStatus / MON_STATUS bits) ---
%define SLP_MASK                     0x07   ; %111, sleep counter 0-7 turns
%define PSN                          3
%define BRN                          4
%define FRZ                          5
%define PAR                          6
; status as single-bit masks (1 << n)
%define SLP                          7   ; counter region (any of bits 0-2)
%define PSN_MASK                     ((1 << PSN))   ; 0x08
%define BRN_MASK                     ((1 << BRN))   ; 0x10
%define FRZ_MASK                     ((1 << FRZ))   ; 0x20
%define PAR_MASK                     ((1 << PAR))   ; 0x40

; --- trainer DVs (read_trainer_party) ---
%define ATKDEFDV_TRAINER             0x98
%define SPDSPCDV_TRAINER             0x88

; --- wDamageMultipliers field ---
%define BIT_STAB_DAMAGE              7
%define EFFECTIVENESS_MASK           0x7F   ; %01111111

; --- wPlayerBattleStatus1 / wEnemyBattleStatus1 bit flags ---
%define STORING_ENERGY               0   ; Bide
%define THRASHING_ABOUT              1   ; Thrash, Petal Dance
%define ATTACKING_MULTIPLE_TIMES     2   ; Double Kick, Fury Attack, etc.
%define FLINCHED                     3
%define CHARGING_UP                  4   ; Solar Beam, Fly, etc.
%define USING_TRAPPING_MOVE          5   ; Wrap, etc.
%define INVULNERABLE                 6   ; charging Fly/Dig
%define CONFUSED                     7

; --- wPlayerBattleStatus2 / wEnemyBattleStatus2 bit flags ---
%define USING_X_ACCURACY             0
%define PROTECTED_BY_MIST            1
%define GETTING_PUMPED               2   ; Focus Energy
%define HAS_SUBSTITUTE_UP            4
%define NEEDS_TO_RECHARGE            5   ; Hyper Beam
%define USING_RAGE                   6
%define SEEDED                       7   ; Leech Seed

; --- wPlayerBattleStatus3 / wEnemyBattleStatus3 bit flags ---
%define BADLY_POISONED               0   ; Toxic
%define HAS_LIGHT_SCREEN_UP          1
%define HAS_REFLECT_UP               2
%define TRANSFORMED                  3

; --- type constants (constants/type_constants.asm) ---
%define PHYSICAL                     0x00   ; types < SPECIAL are physical
%define NORMAL                       0x00
%define FIGHTING                     0x01
%define FLYING                       0x02
%define POISON                       0x03
%define GROUND                       0x04
%define ROCK                         0x05
%define BIRD                         0x06
%define BUG                          0x07
%define GHOST                        0x08
%define SPECIAL                      0x14   ; types >= SPECIAL use Special stat
%define FIRE                         0x14
%define WATER                        0x15
%define GRASS                        0x16
%define ELECTRIC                     0x17
%define PSYCHIC_TYPE                 0x18
%define ICE                          0x19
%define DRAGON                       0x1A
%define NUM_TYPES                    0x1B

; --- move effect constants (MoveEffectPointerTable indexes) ---
%define NO_ADDITIONAL_EFFECT         0x00
%define POISON_SIDE_EFFECT1          0x02
%define DRAIN_HP_EFFECT              0x03
%define BURN_SIDE_EFFECT1            0x04
%define FREEZE_SIDE_EFFECT1          0x05
%define PARALYZE_SIDE_EFFECT1        0x06
%define EXPLODE_EFFECT               0x07
%define DREAM_EATER_EFFECT           0x08
%define MIRROR_MOVE_EFFECT           0x09
%define ATTACK_UP1_EFFECT            0x0A
%define DEFENSE_UP1_EFFECT           0x0B
%define SPEED_UP1_EFFECT             0x0C
%define SPECIAL_UP1_EFFECT           0x0D
%define ACCURACY_UP1_EFFECT          0x0E
%define EVASION_UP1_EFFECT           0x0F
%define PAY_DAY_EFFECT               0x10
%define SWIFT_EFFECT                 0x11
%define ATTACK_DOWN1_EFFECT          0x12
%define DEFENSE_DOWN1_EFFECT         0x13
%define SPEED_DOWN1_EFFECT           0x14
%define SPECIAL_DOWN1_EFFECT         0x15
%define ACCURACY_DOWN1_EFFECT        0x16
%define EVASION_DOWN1_EFFECT         0x17
%define CONVERSION_EFFECT            0x18
%define HAZE_EFFECT                  0x19
%define BIDE_EFFECT                  0x1A
%define THRASH_PETAL_DANCE_EFFECT    0x1B
%define SWITCH_AND_TELEPORT_EFFECT   0x1C
%define TWO_TO_FIVE_ATTACKS_EFFECT   0x1D
%define FLINCH_SIDE_EFFECT1          0x1F
%define SLEEP_EFFECT                 0x20
%define POISON_SIDE_EFFECT2          0x21
%define BURN_SIDE_EFFECT2            0x22
%define FREEZE_SIDE_EFFECT2          0x23
%define PARALYZE_SIDE_EFFECT2        0x24
%define FLINCH_SIDE_EFFECT2          0x25
%define OHKO_EFFECT                  0x26
%define CHARGE_EFFECT                0x27
%define SUPER_FANG_EFFECT            0x28
%define SPECIAL_DAMAGE_EFFECT        0x29
%define TRAPPING_EFFECT              0x2A
%define FLY_EFFECT                   0x2B
%define ATTACK_TWICE_EFFECT          0x2C
%define JUMP_KICK_EFFECT             0x2D
%define MIST_EFFECT                  0x2E
%define FOCUS_ENERGY_EFFECT          0x2F
%define RECOIL_EFFECT                0x30
%define CONFUSION_EFFECT             0x31
%define ATTACK_UP2_EFFECT            0x32
%define DEFENSE_UP2_EFFECT           0x33
%define SPEED_UP2_EFFECT             0x34
%define SPECIAL_UP2_EFFECT           0x35
%define ACCURACY_UP2_EFFECT          0x36
%define EVASION_UP2_EFFECT           0x37
%define HEAL_EFFECT                  0x38
%define TRANSFORM_EFFECT             0x39
%define ATTACK_DOWN2_EFFECT          0x3A
%define DEFENSE_DOWN2_EFFECT         0x3B
%define SPEED_DOWN2_EFFECT           0x3C
%define SPECIAL_DOWN2_EFFECT         0x3D
%define ACCURACY_DOWN2_EFFECT        0x3E
%define EVASION_DOWN2_EFFECT         0x3F
%define LIGHT_SCREEN_EFFECT          0x40
%define REFLECT_EFFECT               0x41
%define POISON_EFFECT                0x42
%define PARALYZE_EFFECT              0x43
%define ATTACK_DOWN_SIDE_EFFECT      0x44
%define DEFENSE_DOWN_SIDE_EFFECT     0x45
%define SPEED_DOWN_SIDE_EFFECT       0x46
%define SPECIAL_DOWN_SIDE_EFFECT     0x47
%define CONFUSION_SIDE_EFFECT        0x4C
%define TWINEEDLE_EFFECT             0x4D
%define SUBSTITUTE_EFFECT            0x4F
%define HYPER_BEAM_EFFECT            0x50
%define RAGE_EFFECT                  0x51
%define MIMIC_EFFECT                 0x52
%define METRONOME_EFFECT             0x53
%define LEECH_SEED_EFFECT            0x54
%define SPLASH_EFFECT                0x55
%define DISABLE_EFFECT               0x56
%define NUM_MOVE_EFFECTS             0x56

; --- move ids referenced by battle logic (constants/move_constants.asm) ---
; (Only the handful the engine name-checks; the Moves table is indexed by id.)
%define NO_MOVE                      0x00
%define KARATE_CHOP                  0x02
%define COUNTER                      0x44
%define RAZOR_LEAF                   0x4B
%define QUICK_ATTACK                 0x62   ; turn-order priority (ExecutePlayerTurn)
%define CRABHAMMER                   0x98
%define SLASH                        0xA3
%define STRUGGLE                     0xA5

; --- InitList selectors (constants/list_constants.asm, const_def 1) ---
%define INIT_ENEMYOT_LIST            1
%define INIT_BAG_ITEM_LIST           2
%define INIT_OTHER_ITEM_LIST         3
%define INIT_PLAYEROT_LIST           4
%define INIT_MON_LIST                5

; --- other move ids used by name (constants/move_constants.asm) ---
%define GUST                         0x10   ; the battle_blackout gate pins the wild
                                    ; enemy's 4 moves to it so its turn always
                                    ; damages (see src/debug/debug_dump.asm)

; --- field-move ids (data/moves/field_moves.asm; lifted out of party_menu.asm) ---
%define CUT                          0x0F
%define FLY                          0x13
%define SURF                         0x39
%define EXP_ALL                      0x4B   ; constants/item_constants.asm (was a file-local equ in core.asm)
%define PAY_DAY                      0x06   ; constants/move_constants.asm
%define WRAP                         0x23   ; constants/move_constants.asm (trapping move)
%define STRENGTH                     0x46
%define ULTRATOSS_ANIM               0xC6   ; constants/move_constants.asm; the toss
                                    ; animation pret picks for any ball that is
                                    ; not POKE_BALL/GREAT_BALL, i.e. the one the
                                    ; MASTER BALL route in ball_catch plays
%define THUNDERSHOCK                 0x54   ; constants/move_constants.asm; the Stage-6
                                    ; elemental animation gate pins it into the
                                    ; player's move slot 4 (see debug_dump.asm)
%define DIG                          0x5B
%define TELEPORT                     0x64
%define SOFTBOILED                   0x87
%define FLASH                        0x94

; --- serial / link state (battle RNG boundary) ---
%define LINK_STATE_BATTLING          0x04

; --- trainer class / species ids name-checked by AI (constants/*.asm) ---
%define LORELEI                      0x2C   ; trainer class
%define DEWGONG                      0x78   ; species

; --- battle-mon struct field offsets (battle_struct, macros/ram.asm) ---
; wBattleMon ($D013) and wEnemyMon ($CFE4) share this 29-byte layout. Direct
; per-field WRAM aliases are also defined in gb_memmap.inc; these offsets let
; code index a battle_struct generically (e.g. from a base pointer).
%define BMON_SPECIES                 0x00
%define BMON_HP                      0x01   ; word (big-endian)
%define BMON_BOXLEVEL                0x03   ; = PartyPos for player
%define BMON_STATUS                  0x04
%define BMON_TYPE1                   0x05
%define BMON_TYPE2                   0x06
%define BMON_CATCH_RATE              0x07
%define BMON_MOVES                   0x08   ; 4 bytes
%define BMON_DVS                     0x0C   ; word
%define BMON_LEVEL                   0x0E
%define BMON_MAXHP                   0x0F   ; word
%define BMON_ATTACK                  0x11   ; word
%define BMON_DEFENSE                 0x13   ; word
%define BMON_SPEED                   0x15   ; word
%define BMON_SPECIAL                 0x17   ; word
%define BMON_PP                      0x19   ; 4 bytes
%define BATTLE_STRUCT_LENGTH         0x1D   ; 29 bytes

; --- number/BCD printing flag bits (constants/text_constants.asm) ---
; Passed in the high bits of the flags byte to PrintNumber / PrintBCDNumber.
%define BIT_MONEY_SIGN               5   ; prepend '¥' currency glyph (BCD)
%define BIT_LEFT_ALIGN               6   ; left-justify (don't pad leading positions)
%define BIT_LEADING_ZEROES           7   ; print leading zeroes instead of spaces

; ---------------------------------------------------------------------------
; Wave 4 (home-rectification) — menu framework constants (pret constants/
; menu_constants.asm + list_constants.asm). Members carry identical-value local
; placeholders; these are canonical.
; ---------------------------------------------------------------------------
; wListMenuID values
%define PCPOKEMONLISTMENU            0x00
%define MOVESLISTMENU                0x01
%define PRICEDITEMLISTMENU           0x02
%define ITEMLISTMENU                 0x03
%define SPECIALLISTMENU              0x04   ; special "items": elevator floor list, badge list
; wTextBoxID (pret constants/menu_constants.asm text box IDs; JP_* templates
; omitted — the port ships the EN tables only, matching the S1 layout seeder)
%define MESSAGE_BOX                  0x01
%define MENU_TEMPLATE_03             0x03   ; unused in pret
%define FIELD_MOVE_MON_MENU          0x04
%define USE_TOSS_MENU_TEMPLATE       0x06
%define MENU_TEMPLATE_07             0x07   ; unused in pret
%define BATTLE_MENU_TEMPLATE         0x0B
%define SWITCH_STATS_CANCEL_MENU_TEMPLATE 0x0C
%define LIST_MENU_BOX                0x0D
%define BUY_SELL_QUIT_MENU_TEMPLATE  0x0E
%define MONEY_BOX_TEMPLATE           0x0F
%define MENU_TEMPLATE_10             0x10   ; unused in pret
%define MON_SPRITE_POPUP             0x11
%define TWO_OPTION_MENU              0x14
%define BUY_SELL_QUIT_MENU           0x15
%define SAFARI_BATTLE_MENU_TEMPLATE  0x1B
; wPartyMenuTypeOrMessageID values (pret constants/menu_constants.asm)
%define NORMAL_PARTY_MENU            0x00
%define USE_ITEM_PARTY_MENU          0x01
%define BATTLE_PARTY_MENU            0x02
%define TMHM_PARTY_MENU              0x03
%define SWAP_MONS_PARTY_MENU         0x04
%define EVO_STONE_PARTY_MENU         0x05
; wPartyMenuTypeOrMessageID message IDs — pret `const_next $F0` (menu_constants.asm).
; RedrawPartyMenu_ masks the id with $0F to index PartyMenuItemUseMessagePointers,
; so the base MUST be $F0 (it was 0x06 here — off by the const_next, harmless only
; while no message id was ever stored; ItemUseMedicine stores them).
%define FIRST_PARTY_MENU_TEXT_ID     0xF0   ; ids >= this select PartyMenuItemUseMessagePointers
%define ANTIDOTE_MSG                 0xF0
%define BURN_HEAL_MSG                0xF1
%define ICE_HEAL_MSG                 0xF2
%define AWAKENING_MSG                0xF3
%define PARALYZ_HEAL_MSG             0xF4
%define POTION_MSG                   0xF5
%define FULL_HEAL_MSG                0xF6
%define REVIVE_MSG                   0xF7
%define RARE_CANDY_MSG               0xF8
; hUILayoutFlags bit (pret constants/gfx_constants.asm; BIT_SINGLE_SPACED_LINES
; already lives in gb_memmap.inc's hUILayoutFlags block)
%define BIT_PARTY_MENU_HP_BAR        0   ; DrawHP_: HP fraction right of the bar, not below
; wTwoOptionMenuID variants
%define YES_NO_MENU                  0x00
%define NORTH_WEST_MENU              0x01
%define SOUTH_EAST_MENU              0x02
%define WIDE_YES_NO_MENU             0x03
%define NORTH_EAST_MENU              0x04
%define TRADE_CANCEL_MENU            0x05
%define HEAL_CANCEL_MENU             0x06
%define NO_YES_MENU                  0x07
%define BIT_SECOND_MENU_OPTION_DEFAULT 7
; wMenuExitMethod
%define CHOSE_MENU_ITEM              0x01
%define CHOSE_FIRST_ITEM             0x01
%define CHOSE_SECOND_ITEM            0x02
%define CANCELLED_MENU               0x02

; ---------------------------------------------------------------------------
; Wave 5 (home-rectification) — pokemon/item constants (pret menu_constants.asm /
; pokemon_constants.asm).
; ---------------------------------------------------------------------------
%define MONEY_BOX                    0x13   ; wTextBoxID: money display box
; wMonDataLocation move directions (menu_constants.asm)
%define BOX_TO_PARTY                 0x00
%define PARTY_TO_BOX                 0x01
%define DAYCARE_TO_PARTY             0x02
%define PARTY_TO_DAYCARE             0x03
; special sprite-ID mons with no BaseStats row (pokemon_constants.asm)
%define FOSSIL_KABUTOPS              0xB6
%define FOSSIL_AERODACTYL            0xB7
%define MON_GHOST                    0xB8

; PORT-ONLY front-pic handles for those same three mons. pret stores each pic's
; ROM address in wMonHFrontSprite (a 16-bit GB pointer) and UncompressMonSprite
; dereferences it; a GB ROM address means nothing here, so the port stores a
; small handle in the same field and UncompressMonSprite resolves it through the
; generated SpecialMonPics table (assets/mon_pics.inc, same order). 0 = "not a
; special pic, use the dex-keyed MonFrontPics table" — which is what every dex
; mon carries, because gen_base_stats.py zeroes the sprite-dim + both pic
; pointers in every BaseStats row, so the handle range can never collide with
; real data. See the DEVIATION at src/home/pokemon.asm:GetMonHeader.specialID.
%define SPECIAL_PIC_NONE             0
%define SPECIAL_PIC_FOSSIL_KABUTOPS  1
%define SPECIAL_PIC_GHOST            2
%define SPECIAL_PIC_FOSSIL_AERODACTYL 3

; ---------------------------------------------------------------------------
; Trainer classes and opponent ids (constants/trainer_constants.asm).
; Folded in 2026-07-27 from the retired include/m8_2_pending_symbols.inc scaffold.
; pret builds these with the `trainer_const` macro as OPP_x = OPP_ID_OFFSET + x,
; so they are written that way here rather than as bare decimals — the class id in
; each comment is pret's own $xx, which makes every line checkable against
; constants/trainer_constants.asm instead of trusted.
; ---------------------------------------------------------------------------
%define OPP_ID_OFFSET                200
%define ROCKET                       0x1E   ; trainer class $1E (IsFightingJessieJames)
%define RIVAL3                       0x2B   ; trainer class $2B (TrainerBattleVictory final rival)
%define OPP_LASS                     (OPP_ID_OFFSET + 0x03)
%define OPP_JR_TRAINER_F             (OPP_ID_OFFSET + 0x06)
%define OPP_UNUSED_JUGGLER           (OPP_ID_OFFSET + 0x0D)
%define OPP_GAMBLER                  (OPP_ID_OFFSET + 0x11)
%define OPP_BEAUTY                   (OPP_ID_OFFSET + 0x12)
%define OPP_ROCKER                   (OPP_ID_OFFSET + 0x14)
%define OPP_JUGGLER                  (OPP_ID_OFFSET + 0x15)
%define OPP_RIVAL1                   (OPP_ID_OFFSET + 0x19)
%define OPP_CHIEF                    (OPP_ID_OFFSET + 0x1B)
%define OPP_SCIENTIST                (OPP_ID_OFFSET + 0x1C)
%define OPP_GIOVANNI                 (OPP_ID_OFFSET + 0x1D)
%define OPP_ROCKET                   (OPP_ID_OFFSET + ROCKET)
%define OPP_COOLTRAINER_F            (OPP_ID_OFFSET + 0x20)
%define OPP_RIVAL2                   (OPP_ID_OFFSET + 0x2A)
%define OPP_RIVAL3                   (OPP_ID_OFFSET + 0x2B)
%define OPP_LANCE                    (OPP_ID_OFFSET + 0x2F)   ; plays the gym-leader battle theme

; Gym-leader name/city field width (constants/text_constants.asm:7).
%define GYM_CITY_LENGTH              17

; --- slot symbols (constants/script_constants.asm:13-18) ---
%define SLOTS7                       0x0200
%define SLOTSBAR                     0x0604
%define SLOTSCHERRY                  0x0A08
%define SLOTSFISH                    0x0E0C
%define SLOTSBIRD                    0x1210
%define SLOTSMOUSE                   0x1614

; --- Pikachu map script flags (wPikachuMapScriptFlags) ---
%define BIT_PIKACHU_MAP_SURF_SELECT  1

%endif ; GB_CONSTANTS_INC

; ---------------------------------------------------------------------------
; SRAM bank numbers, from the pret linker script layout.link:248-255
;   SRAM $0 "Sprite Buffers" | $1 "Save Data" | $2 "Saved Boxes 1" | $3 "Saved Boxes 2"
; These are bank NUMBERS, not addresses, which is why they live here and not in
; gb_memmap.inc — tools/audit_memmap.py reads that header as an address map and
; correctly rejects cartridge-space values (an earlier attempt to put the MBC
; registers there failed the build on rROMB $2000 colliding with a map blob).
; ---------------------------------------------------------------------------
%define SRAM_BANK_SPRITE_BUFFERS  0
%define SRAM_BANK_SAVE_DATA       1
%define SRAM_BANK_SAVED_BOXES_1   2
%define SRAM_BANK_SAVED_BOXES_2   3
