# Makefile for the Pokemon Yellow DOS Port
# Toolchain: NASM + binutils-djgpp (i386-pc-msdosdjgpp-ld)
# Output: pokeyellow_dos.exe (DJGPP coff-go32-exe format, CWSDPMI-loadable)
#
# Install toolchain (Debian/Ubuntu):
#   sudo apt install nasm binutils-djgpp
#
# Run in DOSBox:
#   Place pokeyellow_dos.exe in a directory with CWSDPMI.EXE
#   DOSBox config: [cpu] cputype=386, core=normal, cycles=50000

NASM    := nasm
LD      := i386-pc-msdosdjgpp-ld

NASMFLAGS := -f coff -I include/ -I . -O0

# Bug fix level (0=none, 1=critical, 2=all). Override: make BUG_FIX_LEVEL=1
BUG_FIX_LEVEL ?= 0
NASMFLAGS += -D BUG_FIX_LEVEL=$(BUG_FIX_LEVEL)

# ---------------------------------------------------------------------------
# Frame-timing mode — picks the PIT channel-0 divisor (the IRQ 0 / emulated
# vblank rate that paces the whole game). The Game Boy is NOT exactly 60 Hz, so
# this is an explicit, documented choice instead of a magic constant:
#
#   make TIMING=SGB    61.1685 Hz — Super Game Boy 1 (SNES-derived 4.2954 MHz
#                                   GB clock, ~+2.41% vs DMG). The authentic SGB
#                                   speed-up/pitch-up. DEFAULT.
#   make TIMING=DMG    59.7275 Hz — real DMG/CGB handheld (4194304 / 70224).
#   make TIMING=PC     60.0000 Hz — clean PC 60 Hz (the port's old fixed value).
#   make TIMING_HZ=61.17        — any custom refresh rate in Hz (overrides TIMING).
#   make TIMING_DIVISOR=19506   — raw PIT divisor (overrides TIMING and TIMING_HZ).
#
# PIT input clock = 1,193,181.666 Hz; divisor = round(clock / Hz). Changing the
# rate scales movement, animation, and (later) audio pitch uniformly — exactly
# how the real SGB ran fast. Verify a build with `make DEBUG_WALKSPEED=1`
# (ticks/tile is rate-invariant at 16; the real-time tiles/sec is what shifts).
PIT_CLOCK := 1193181.666
TIMING    ?= SGB
ifeq ($(TIMING),SGB)
TIMING_HZ ?= 61.1685
else ifeq ($(TIMING),DMG)
TIMING_HZ ?= 59.7275
else ifeq ($(TIMING),PC)
TIMING_HZ ?= 60.0
else
$(error TIMING must be SGB, DMG, or PC — or use TIMING_HZ=<hz> / TIMING_DIVISOR=<n>)
endif
ifdef TIMING_DIVISOR
PIT_DIVISOR := $(TIMING_DIVISOR)
else
PIT_DIVISOR := $(shell python3 -c "d=round($(PIT_CLOCK)/$(TIMING_HZ)); print(d if 1<=d<=65535 else '')")
endif
ifeq ($(PIT_DIVISOR),)
$(error TIMING_HZ=$(TIMING_HZ) yields a PIT divisor outside 1..65535)
endif
NASMFLAGS += -D PIT_DIVISOR=$(PIT_DIVISOR)

# Test flag: skip title screen, go straight to overworld. make SKIP_TITLE=1
ifdef SKIP_TITLE
NASMFLAGS += -D SKIP_TITLE
endif

# Default player / rival names for debug / SKIP_TITLE builds (title screen is
# bypassed, so these WRAM fields would otherwise be garbage). The engine's debug
# defaults are NINTEN / SONY. Letters only, <= 7 chars.
# Override: make SKIP_TITLE=1 PLAYER_NAME=ASH RIVAL_NAME=GARY
PLAYER_NAME ?= NINTEN
RIVAL_NAME  ?= SONY
NASMFLAGS += -D PLAYER_NAME="'$(PLAYER_NAME)'"
NASMFLAGS += -D RIVAL_NAME="'$(RIVAL_NAME)'"

# Debug flag: dump GB memory windows to DUMP.BIN then exit. make DEBUG_DUMP=1
# (implies SKIP_TITLE path reaching the overworld). See src/debug/debug_dump.asm.
ifdef DEBUG_DUMP
NASMFLAGS += -D DEBUG_DUMP
endif

# Debug flag: force a north map transition (Pallet Town -> Route 1) at boot so the
# post-crossing render can be screenshotted without keyboard input. make DEBUG_TRANSITION=1
ifdef DEBUG_TRANSITION
NASMFLAGS += -D DEBUG_TRANSITION
endif

# Sub-flag of DEBUG_TRANSITION: skip the CheckMapConnections crossing so the
# DEBUG_TRANSITION reload path dumps a pristine (non-transitioned) current map.
# Use to capture a baseline frame for comparison. make DEBUG_TRANSITION=1 DEBUG_BASELINE=1
ifdef DEBUG_BASELINE
NASMFLAGS += -D DEBUG_BASELINE
endif

# Debug flag: simulate a northward walk to the map edge then dump FRAME.BIN, to
# inspect where the transition triggers relative to the visible edge.
# make DEBUG_WALK_NORTH=1 (optionally DEBUG_WALK_STEPS=N via NASM define).
ifdef DEBUG_WALK_NORTH
NASMFLAGS += -D DEBUG_WALK_NORTH
endif

# Number of north steps for DEBUG_WALK_NORTH (default 8 in overworld.asm).
ifdef DEBUG_WALK_STEPS
NASMFLAGS += -D DEBUG_WALK_STEPS=$(DEBUG_WALK_STEPS)
endif

# Debug noclip: press W in-game to toggle walk-through-walls (disables collision).
# Useful for testing warps, map edges, and OOB behaviour without normal movement.
# Does NOT imply SKIP_TITLE — works at any point in the game.
# make SKIP_TITLE=1 DEBUG_NOCLIP=1
ifdef DEBUG_NOCLIP
NASMFLAGS += -D DEBUG_NOCLIP
endif

LDFLAGS := -T link.ld

TARGET  := PKMN.EXE

# Source files
BOOT_SRCS := \
    boot/entry.asm \
    boot/video.asm \
    boot/timing.asm

HOME_SRCS := \
    src/home/fill_memory.asm \
    src/home/copy_data.asm \
    src/home/bankswitch.asm \
    src/home/textbox.asm \
    src/home/yes_no.asm \
    src/home/list_menu.asm \
    src/home/start_menu.asm \
    src/home/item.asm

HAL_SRCS := \
    src/ppu/ppu.asm \
    src/input/joypad.asm \
    src/input/joypad_lowsens.asm

# Phase 2: game-loop core
GAME_SRCS := \
    src/init/init.asm \
    src/video/lcd_control.asm \
    src/video/frame.asm \
    src/video/bg_anim.asm \
    src/util/play_time.asm \
    src/gfx/sprites.asm \
    src/gfx/sprite_oam.asm \
    src/gfx/load_font.asm \
    src/text/text.asm \
    src/home/print_num.asm \
    src/home/print_bcd.asm \
    src/home/window.asm \
    src/home/fade.asm \
    src/text/auto_textbox.asm \
    src/movie/title.asm \
    src/engine/overworld/overworld.asm \
    src/engine/overworld/movement.asm \
    src/engine/overworld/map_sprites.asm \
    src/engine/overworld/run_map_script.asm \
    src/data/map_scripts.asm \
    src/scripts/pallet_town.asm \
    src/engine/math/random.asm \
    src/engine/menus/draw_start_menu.asm \
    src/engine/menus/start_sub_menus.asm \
    src/engine/menus/party_menu.asm \
    src/engine/menus/field_moves.asm \
    src/engine/menus/text_box.asm \
    src/engine/menus/draw_badges.asm \
    src/engine/menus/oaks_pc.asm \
    src/engine/menus/league_pc.asm \
    src/engine/menus/league_pc_stubs.asm \
    src/engine/menus/options.asm \
    src/engine/menus/players_pc.asm \
    src/engine/menus/display_text_id_init.asm \
    src/engine/overworld/simulate_joypad.asm \
    src/engine/overworld/overworld_stubs.asm \
    src/engine/overworld/wild_encounter_check.asm \
    src/engine/overworld/warp_check.asm \
    src/engine/overworld/hidden_events.asm \
    src/engine/menus/swap_items.asm \
    src/engine/link/cable_club.asm

# Pokémon data/stats engine (current_plan_pokemon_engine.md). Grows per stage.
POKEMON_SRCS := \
    src/data/pokemon_data.asm \
    src/home/math.asm \
    src/engine/math/multiply_divide.asm \
    src/home/array.asm \
    src/home/predef.asm \
    src/home/pokemon.asm \
    src/home/move_mon.asm \
    src/engine/pokemon/experience.asm \
    src/engine/pokemon/add_party_mon.asm \
    src/engine/pokemon/add_mon.asm \
    src/engine/pokemon/load_mon_data.asm \
    src/engine/pokemon/set_types.asm \
    src/engine/pokemon/remove_mon.asm \
    src/engine/pokemon/write_moves.asm \
    src/engine/pokemon/status_ailments.asm \
    src/engine/gfx/hp_bar.asm

# Items layer (current_plan_items.md). Non-UI inventory/bag logic + item data.
ITEMS_SRCS := \
    src/data/item_data.asm \
    src/engine/items/inventory.asm \
    src/engine/items/item_effects.asm \
    src/engine/items/item_price.asm \
    src/engine/items/tm_prices.asm \
    src/home/compare.asm \
    src/engine/math/bcd.asm

# Battle engine backend (current_plan_battle_engine.md). Damage pipeline + data.
# NOTE: this list is CHECK-ONLY (assembled by `make check`, not linked). The faithful
# battle loop (core.asm, FRONTEND_SRCS) needs only a curated subset of it, and that
# subset has been MOVED to FRONTEND_SRCS (decrement_pp, animations); the deeper closures
# here (effects + all move_effects, residual_damage, trainer_ai, misc/InitList, names,
# read_trainer_party, wild_*) still depend on deferred predefs/UI/text and are stubbed at
# link time by core_stubs.asm (JumpMoveEffect / HandlePoisonBurnLeechSeed / TrainerAI /
# FormatMovesString). Every file here still assembles (make check) and the pure-math
# routines are native-ELF-harness validated.
BATTLE_SRCS := \
    src/engine/battle/get_trainer_name.asm \
    src/engine/battle/misc.asm \
    src/engine/battle/move_category.asm \
    src/data/wild_data.asm \
    src/engine/overworld/wild_mons.asm \
    src/engine/battle/wild_encounters.asm
# trainer_ai.asm + read_trainer_party.asm MOVED to FRONTEND_SRCS (battle-swarm-C): the
# class-based enemy-move AI (AIEnemyTrainerChooseMoves) and trainer-party loader now link
# live — their closures resolve (AIGetTypeEffectiveness/Moves/Divide/IsInArray/Random +
# TrainerDataPointers/SpecialTrainerMoves/AddPartyMon/AddBCDPredef). wild_encounters.asm
# stays check-only (its TryDoWildEncounter still needs unresolved overworld externs, and
# the live overworld already triggers encounters via wild_encounter_check.asm).
# experience.asm (GainExperience) is now LINKED (FRONTEND_SRCS, Stage 3 victory→EXP):
# its validated EXP/stat/level math runs live; the deferred UI/display externs
# (PrintStatsBox, the CallBattleCore targets, the per-mon text) are satisfied by
# battle_exp_stubs.asm and the front end (battle_menu.asm) shows the gained-EXP text.

# Debug-only sources (linked only when the corresponding flag is set).
# Any debug flag implies SKIP_TITLE — debug harnesses boot straight to the overworld.
ifdef DEBUG_DUMP
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D SKIP_TITLE
endif
ifdef DEBUG_TRANSITION
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D SKIP_TITLE
endif
ifdef DEBUG_WALK_NORTH
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D SKIP_TITLE
endif
# Frame-rate probe: run a fixed number of DelayFrame calls in the loaded overworld
# and dump the tick_count delta to DUMP.BIN ($D1E0). delta < count proves the loop
# free-runs faster than 60 Hz (the "walks too fast" regression). make DEBUG_WALKSPEED=1
# Optional: DEBUG_WALKSPEED_FRAMES=N (default 180).
ifdef DEBUG_WALKSPEED
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_WALKSPEED
NASMFLAGS += -D SKIP_TITLE
endif
ifdef DEBUG_WALKSPEED_FRAMES
NASMFLAGS += -D DEBUG_WALKSPEED_FRAMES=$(DEBUG_WALKSPEED_FRAMES)
endif
ifdef DEBUG_DIALOG
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_DIALOG
NASMFLAGS += -D SKIP_TITLE
endif
# Diagnostic: log every NPC walk-decision (dest tile, true tile, player view
# state) to NPCLOG.BIN while a scripted player walk runs in Pallet Town.
# Used to verify the walking-NPC wall-clipping bug. make DEBUG_NPC_WALK=1
ifdef DEBUG_NPC_WALK
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_NPC_WALK
NASMFLAGS += -D SKIP_TITLE
endif
# CalcStats gate: compute known Bulbasaur stats at boot, dump DUMP.BIN, exit.
# make DEBUG_CALCSTATS=1
ifdef DEBUG_CALCSTATS
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_CALCSTATS
NASMFLAGS += -D SKIP_TITLE
endif
# Start-menu gate: boot to overworld, force the START menu open, render one frame,
# dump FRAME.BIN, exit. make DEBUG_STARTMENU=1
ifdef DEBUG_STARTMENU
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_STARTMENU
NASMFLAGS += -D SKIP_TITLE
endif
# Party-seed gate: run the debug new-game seed (party + bag + Pokédex) at boot,
# dump party/bag WRAM to DUMP.BIN, exit. Verifies the pokemon/items engine runs
# inside the real binary. make DEBUG_PARTY=1
ifdef DEBUG_PARTY
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_PARTY
NASMFLAGS += -D SKIP_TITLE
GAME_SRCS += src/engine/debug/debug_party.asm
endif
# Bag-menu gate: seed the bag, open the bag (ITEM) screen over the overworld,
# render one frame, dump FRAME.BIN, exit. make DEBUG_BAGMENU=1
ifdef DEBUG_BAGMENU
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_BAGMENU
NASMFLAGS += -D SKIP_TITLE
GAME_SRCS += src/engine/debug/debug_party.asm
endif
# Live, interactive bag test: seed a full bag + money and boot to the overworld;
# open the bag via START -> ITEM to drive the list / toss / YES-NO confirm by hand.
# make DEBUG_BAGMENU_LIVE=1 (then dos_port/run, or build + launch DOSBox-X).
ifdef DEBUG_BAGMENU_LIVE
NASMFLAGS += -D DEBUG_BAGMENU_LIVE
NASMFLAGS += -D SKIP_TITLE
GAME_SRCS += src/engine/debug/debug_party.asm
endif
# Party-menu gate: seed the party, open the POKéMON screen over the overworld,
# render one frame, dump FRAME.BIN, exit. make DEBUG_PARTYMENU=1
ifdef DEBUG_PARTYMENU
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_PARTYMENU
NASMFLAGS += -D SKIP_TITLE
GAME_SRCS += src/engine/debug/debug_party.asm
endif
# Text-box gate (menus S2): boot to overworld, switch to the flat canvas, draw
# the DisplayTextBoxID box with the given wTextBoxID, dump FRAME.BIN, exit.
# make DEBUG_TEXTBOXID=<id>  (id = hex/dec NASM literal, e.g. 0x01, 0x13)
ifdef DEBUG_TEXTBOXID
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_TEXTBOXID=$(DEBUG_TEXTBOXID)
NASMFLAGS += -D SKIP_TITLE
GAME_SRCS += src/engine/debug/debug_party.asm
endif
# List-menu gate (menus S3): boot to overworld, seed party+bag, drive the generic
# DisplayListMenuID driver input-free (Old-Man auto-select), dump FRAME.BIN, exit.
# make DEBUG_LISTMENU=<mode>  (0=PC mon list, 2=priced bag, 3=item bag)
ifdef DEBUG_LISTMENU
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_LISTMENU=$(DEBUG_LISTMENU)
NASMFLAGS += -D SKIP_TITLE
GAME_SRCS += src/engine/debug/debug_party.asm
endif
# Draw-badges gate (menus S6 package B): boot to overworld, seed a mixed badge
# set, load the badge tiles, draw the 4x2 grid + window it, dump FRAME.BIN, exit.
# The harness seeds wObtainedBadges itself, so no debug_party seed is needed.
# make SKIP_TITLE=1 DEBUG_DRAWBADGES=1
ifdef DEBUG_DRAWBADGES
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_DRAWBADGES
NASMFLAGS += -D SKIP_TITLE
endif
# Oak's-PC gate (menus S6 package A): boot to overworld, open OpenOaksPC; the
# in-routine hook dumps FRAME.BIN of the "Accessed PROF. OAK's PC." dialog before
# the first blocking wait. make SKIP_TITLE=1 DEBUG_OAKSPC=1
ifdef DEBUG_OAKSPC
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_OAKSPC
NASMFLAGS += -D SKIP_TITLE
endif
# League-PC gate (menus S6 package A): boot to overworld, draw the AccessedHoFPCText
# dialog (wNumHoFTeams==0 -> team loop skipped), dump FRAME.BIN, exit.
# make SKIP_TITLE=1 DEBUG_LEAGUEPC=1
ifdef DEBUG_LEAGUEPC
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_LEAGUEPC
NASMFLAGS += -D SKIP_TITLE
endif
# Options gate (menus S6 package D): boot to overworld, open the OPTION menu via
# InitOptionsMenu (full-screen takeover), draw the cursor, dump FRAME.BIN, exit.
# make SKIP_TITLE=1 DEBUG_OPTIONS=1
ifdef DEBUG_OPTIONS
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_OPTIONS
NASMFLAGS += -D SKIP_TITLE
endif
# Player's-PC gate (menus S6 package F): boot to overworld, seed party+bag+box,
# open PlayerPC as a generic PC; the parent-menu hook dumps FRAME.BIN, exits.
# make SKIP_TITLE=1 DEBUG_PLAYERSPC=1
ifdef DEBUG_PLAYERSPC
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_PLAYERSPC
NASMFLAGS += -D SKIP_TITLE
GAME_SRCS += src/engine/debug/debug_party.asm
endif
# Live battle view: same setup as DEBUG_BATTLE but holds the screen (loops
# DelayFrame) so you can visually inspect it instead of dumping+exiting. Esc quits.
# make DEBUG_BATTLE_LIVE=1 (then dos_port/run).
ifdef DEBUG_BATTLE_LIVE
DEBUG_BATTLE := 1
NASMFLAGS += -D DEBUG_BATTLE_LIVE
endif
# Scripted enemy-hit ground-truth (Stage 2b): run one enemy attack with no input
# waits, then dump battle WRAM to DUMP.BIN. make DEBUG_BATTLE_ENEMYHIT=1
ifdef DEBUG_BATTLE_ENEMYHIT
DEBUG_BATTLE := 1
NASMFLAGS += -D DEBUG_BATTLE_ENEMYHIT
endif
# Battle intro screen dump (scene + "Wild <nick> appeared!", no menu) → FRAME.BIN.
ifdef DEBUG_BATTLE_INTRO
DEBUG_BATTLE := 1
NASMFLAGS += -D DEBUG_BATTLE_INTRO
endif
# Bug Catcher trainer test: seeds a trainer battle (enemy = trainer + ball row +
# party-status variety). Combine with DEBUG_BATTLE_INTRO (dump) or DEBUG_BATTLE_LIVE.
ifdef DEBUG_BATTLE_TRAINER
DEBUG_BATTLE := 1
NASMFLAGS += -D DEBUG_BATTLE_TRAINER
endif
# Battle gate (Wave 2): seed party + a wild enemy, enter battle (InitBattle),
# render one frame, dump FRAME.BIN, exit. make DEBUG_BATTLE=1
ifdef DEBUG_BATTLE
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_BATTLE
NASMFLAGS += -D SKIP_TITLE
GAME_SRCS += src/engine/debug/debug_party.asm
endif
ifdef NEED_DEBUG_DUMP
GAME_SRCS += src/debug/debug_dump.asm
endif

# Test harness for event-gated dialog: force EVENT_GOT_POKEBALLS_FROM_OAK at map
# load so PalletTownOakText shows its "set" branch. make SKIP_TITLE=1 DEBUG_OAK_EVENT=1
ifdef DEBUG_OAK_EVENT
NASMFLAGS += -D DEBUG_OAK_EVENT
endif

# LINK_SRCS = what actually goes into PKMN.EXE. BATTLE_SRCS is deliberately
# excluded: the battle backend depends on deferred UI/effect routines and does
# not yet link (see the BATTLE_SRCS note above). It is still assembled by
# `make check` and validated by native harnesses via ALL_SRCS below.
# Battle front-end (Wave 2). These DO link (no unresolved externs) — unlike the
# check-only BATTLE_SRCS backend. Grows per stage.
FRONTEND_SRCS := \
    src/engine/battle/init_battle_variables.asm \
    src/engine/battle/init_battle.asm \
    src/engine/battle/battle_hud.asm \
    src/engine/battle/battle_menu.asm \
    src/engine/battle/core.asm \
    src/engine/battle/core_stubs.asm \
    src/engine/battle/counter.asm \
    src/engine/battle/mirror_move.asm \
    src/engine/battle/metronome.asm \
    src/engine/battle/print_critical_ohko.asm \
    src/engine/battle/display_effectiveness.asm \
    src/engine/battle/print_move_failure.asm \
    src/engine/battle/ghost.asm \
    src/engine/battle/exploding_animation.asm \
    src/engine/battle/residual_damage.asm \
    src/engine/battle/building_rage.asm \
    src/engine/battle/effects.asm \
    src/engine/battle/stat_mod_effects.asm \
    src/engine/battle/move_effect_helpers.asm \
    src/home/names.asm \
    src/engine/battle/move_effects/poison.asm \
    src/engine/battle/move_effects/splash.asm \
    src/engine/battle/move_effects/flinch_side.asm \
    src/engine/battle/move_effects/confusion.asm \
    src/engine/battle/move_effects/sleep.asm \
    src/engine/battle/move_effects/freeze_burn_paralyze.asm \
    src/engine/battle/move_effects/conversion.asm \
    src/engine/battle/move_effects/focus_energy.asm \
    src/engine/battle/move_effects/haze.asm \
    src/engine/battle/move_effects/leech_seed.asm \
    src/engine/battle/move_effects/rage.asm \
    src/engine/battle/move_effects/explode.asm \
    src/engine/battle/move_effects/bide.asm \
    src/engine/battle/move_effects/two_to_five_attacks.asm \
    src/engine/battle/move_effects/hyper_beam.asm \
    src/engine/battle/move_effects/thrash_petal_dance.asm \
    src/engine/battle/move_effects/disable.asm \
    src/engine/battle/move_effects/trapping.asm \
    src/engine/battle/move_effects/charge.asm \
    src/engine/battle/move_effects/mimic.asm \
    src/engine/battle/move_effects/switch_and_teleport.asm \
    src/engine/battle/move_effects/drain_hp.asm \
    src/engine/battle/move_effects/reflect_light_screen.asm \
    src/engine/battle/move_effects/recoil.asm \
    src/engine/battle/move_effects/pay_day.asm \
    src/engine/battle/move_effects/substitute.asm \
    src/engine/battle/move_effects/heal.asm \
    src/engine/battle/move_effects/transform.asm \
    src/engine/battle/move_effects/mist.asm \
    src/engine/battle/move_effects/one_hit_ko.asm \
    src/engine/battle/move_effects/paralyze.asm \
    src/engine/battle/badge_boosts.asm \
    src/engine/battle/status_penalties.asm \
    src/engine/battle/decrement_pp.asm \
    src/engine/battle/animations.asm \
    src/data/battle_data.asm \
    src/data/trainer_data.asm \
    src/data/move_grammar.asm \
    src/data/type_names.asm \
    src/home/random.asm \
    src/engine/battle/core_damage.asm \
    src/engine/battle/get_current_move.asm \
    src/engine/battle/select_enemy_move.asm \
    src/engine/battle/load_enemy_moves.asm \
    src/engine/battle/pokeballs.asm \
    src/data/trainer_pics.asm \
    src/engine/battle/battle_stubs.asm \
    src/gfx/uncompress.asm \
    src/gfx/pics.asm \
    src/engine/battle/experience.asm \
    src/engine/battle/battle_exp_stubs.asm \
    src/engine/battle/trainer_battle.asm \
    src/engine/battle/trainer_ai.asm \
    src/engine/battle/read_trainer_party.asm \
    src/engine/battle/faint_leaves.asm \
    src/engine/battle/faint_switch.asm \
    src/engine/battle/faint_enemy.asm \
    src/engine/battle/load_enemy_from_party.asm \
    src/engine/battle/faint_sendout.asm \
    src/engine/flag_action.asm

# Home/item helpers promoted to the live build now that battle faint/EXP-ALL
# consumers (faint_enemy.asm: ClearScreenArea, IsItemInBag→GetQuantityOfItemInBag)
# reference them. Closures resolve: copy2→DelayFrame/g_tilecache_dirty;
# item_predicates→FlagAction/IsInArray/KeyItemFlags/GetQuantityOfItemInBag;
# get_bag_item_quantity→GetPredefRegisters. Removed from HOME_CHECK_SRCS below.
BATTLE_SUPPORT_SRCS := \
    src/home/copy2.asm \
    src/home/item_predicates.asm \
    src/engine/items/get_bag_item_quantity.asm

LINK_SRCS := $(BOOT_SRCS) $(HOME_SRCS) $(HAL_SRCS) $(GAME_SRCS) $(POKEMON_SRCS) $(ITEMS_SRCS) $(FRONTEND_SRCS) $(BATTLE_SUPPORT_SRCS)
LINK_OBJS := $(LINK_SRCS:.asm=.o)

# Pokémon backend that assembles + is native-harness-validated but is NOT linked
# yet. bills_pc needs a link-ready _MoveMon (the draft in add_mon.asm has a
# duplicate AddPartyMon_WriteMovePP symbol + extern-constant errors and an
# unresolved dependency closure). evolution depends on GetName (check-only
# names.asm) / FlagActionPredef / pikachu — and its EvolutionAfterBattle party
# loop has a known stack bug (see the file) to fix+validate in Wave 2; its
# headless decision path + LearnMoveFromLevelUp are native-validated now.
POKEMON_CHECK_SRCS := \
    src/engine/pokemon/bills_pc.asm \
    src/engine/pokemon/evolution.asm

# Item routines that assemble-validate but aren't linked yet — either unwired
# (nothing calls them) or dependent on not-yet-ported deps (town-map palette/video
# engine, DisplayTextBoxID, _AlreadyKnowsText). town_map is intentionally kept
# dangling (not in the main loop) per its port note.
# swap_items.asm MOVED to GAME_SRCS (menus S3): SELECT-swap links live with
# the promoted list_menu.asm driver.
ITEMS_CHECK_SRCS := \
    src/engine/items/subtract_paid_money.asm \
    src/engine/items/tms.asm \
    src/engine/items/tmhm.asm \
    src/engine/items/super_rod.asm \
    src/engine/items/town_map.asm

# Home routines that assemble-validate but aren't linked yet. count_set_bits
# emits an undefined external for wNumSetBits (no memmap alias / no caller yet),
# so linking it would break the build — keep it check-only until a caller lands
# (then add wNumSetBits to gb_memmap.inc and move it to HOME_SRCS).
# yes_no.asm MOVED to HOME_SRCS (menus S2): DisplayTextBoxID_'s TWO_OPTION_MENU
# dispatch needs DisplayTwoOptionMenu live; all its externs already resolved.
# list_menu.asm MOVED to HOME_SRCS (menus S3): all former link-blockers resolve
# to linked code (PrintLevel added to home/pokemon.asm); links with swap_items.
HOME_CHECK_SRCS := \
    src/home/count_set_bits.asm \
    src/home/text_script.asm \
    src/home/predef_text.asm \
    src/home/give.asm \
    src/home/money.asm \
    src/home/oam.asm \
    src/home/reset_player_sprite.asm \
    src/home/reload_tiles.asm \
    src/home/vcopy.asm \
    src/engine/overworld/pikachu.asm \
    src/engine/overworld/reload_sprites.asm \
    src/engine/overworld/player_gfx.asm \
    src/engine/overworld/overworld_text.asm \
    src/engine/overworld/ledges.asm \
    src/engine/overworld/pathfinding.asm \
    src/engine/overworld/trainer_engine.asm

# ALL_SRCS = everything that must assemble cleanly (check) and be cleaned, incl.
# the not-yet-linked battle backend + check-only pokemon/items/home backends.
ALL_SRCS := $(LINK_SRCS) $(BATTLE_SRCS) $(POKEMON_CHECK_SRCS) $(ITEMS_CHECK_SRCS) $(HOME_CHECK_SRCS)
ALL_OBJS := $(ALL_SRCS:.asm=.o)

# ---------------------------------------------------------------------------
# Targets
# ---------------------------------------------------------------------------

.PHONY: all clean check assets
.DEFAULT_GOAL := all

# Generate all tileset gfx/blocks/coll + map blk inc files.
# Requires gfx/tilesets/*.2bpp, built by 'make' in the repo root.
assets/overworld_gfx.inc assets/overworld_blocks.inc assets/pallet_town_blk.inc:
	python3 tools/gen_all_assets.py

# Generate map headers blob, dispatch tables, and extra_includes.inc.
# Pass DEBUG_WARPS=1 to include IF DEF(_DEBUG) warp entries (e.g. REDS_HOUSE_2F
# debug teleport warps). Changing this flag requires 'make assets' to force-regen.
GEN_MAP_HEADERS_FLAGS :=
ifdef DEBUG_WARPS
GEN_MAP_HEADERS_FLAGS += --debug-warps
endif

assets/map_headers.inc assets/extra_includes.inc:
	python3 tools/gen_map_headers.py $(GEN_MAP_HEADERS_FLAGS)

# Overworld object depends on all generated assets
src/engine/overworld/overworld.o: \
    assets/overworld_gfx.inc \
    assets/overworld_blocks.inc \
    assets/pallet_town_blk.inc \
    assets/map_headers.inc \
    assets/extra_includes.inc

# NPC sprite sheets — all sprites used across all maps (generated by gen_all_assets.py)
assets/npc_sprite_data_table.inc:
	python3 tools/gen_all_assets.py

# NPC dialog streams — all maps (generated by gen_npc_dialogs.py)
assets/npc_dialogs/all_dialogs.inc:
	python3 tools/gen_npc_dialogs.py

# Toggleable-object (event) flag tables — NPC spawn gating (gen_toggleable_objects.py)
assets/toggleable_objects.inc:
	python3 tools/gen_toggleable_objects.py

# Event-flag bit-index constants (EVENT_*) for include/events.inc (gen_event_constants.py)
assets/event_constants.inc:
	python3 tools/gen_event_constants.py

# map_sprites depends on the NPC tile asset table, all-maps dialog table, the
# toggleable-object (event) flag tables, and the event-flag constants (events.inc).
src/engine/overworld/map_sprites.o: \
    assets/npc_sprite_data_table.inc \
    assets/npc_dialogs/all_dialogs.inc \
    assets/toggleable_objects.inc \
    assets/event_constants.inc

# Pallet Town text_asm scripts include events.inc → event_constants.inc.
src/scripts/pallet_town.o: assets/event_constants.inc

# Per-map script dispatch table (generated from constants/map_constants.asm).
assets/map_scripts.inc:
	python3 tools/gen_map_scripts.py

src/data/map_scripts.o: assets/map_scripts.inc

# GB character map in the unicode_converter's format (single-char → byte), for
# the converter submodule + gb_text.py. Generated from constants/charmap.asm.
assets/gb_charmap.txt:
	python3 tools/gen_charmap.py

# START-menu item labels, encoded via the unicode_converter submodule (gb_text).
assets/menu_strings.inc: assets/gb_charmap.txt tools/gen_menu_strings.py tools/gb_text.py
	python3 tools/gen_menu_strings.py

# Battle message command streams (pret data/text + engine/battle wrappers, text_far
# flattened). %included by the battle core engine. Generated from the read-only spec.
assets/battle_text.inc: ../data/text/text_2.asm ../engine/battle/core.asm \
                        ../constants/charmap.asm include/gb_memmap.inc tools/gen_battle_text.py
	python3 tools/gen_battle_text.py

# Trainer rosters + class names (consumed by read_trainer_party.asm / GetName).
assets/trainer_parties.inc: ../data/trainers/parties.asm ../data/trainers/special_moves.asm \
                            ../constants/trainer_constants.asm tools/gen_trainer_parties.py
	python3 tools/gen_trainer_parties.py
assets/trainer_names.inc: ../data/trainers/names.asm ../constants/charmap.asm \
                          tools/gen_trainer_names.py
	python3 tools/gen_trainer_names.py
# Move-use sentence-grammar table (vestigial in English; carried for faithfulness).
assets/move_grammar.inc: ../data/moves/grammar.asm ../constants/move_constants.asm \
                         tools/gen_move_grammar.py
	python3 tools/gen_move_grammar.py
# Type names (raw-id-indexed pointer table, 0x09-0x13 gap -> NORMAL).
assets/type_names.inc: ../data/types/names.asm ../constants/type_constants.asm \
                       ../constants/charmap.asm tools/gen_type_names.py
	python3 tools/gen_type_names.py

# Wrapper objects depend on their generated includes.
src/data/trainer_data.o: assets/trainer_parties.inc assets/trainer_names.inc
src/data/move_grammar.o: assets/move_grammar.inc
src/data/type_names.o: assets/type_names.inc

assets/battle_hud_2bpp.inc: ../gfx/battle/battle_hud_1.png ../gfx/battle/battle_hud_2.png \
                            ../gfx/battle/battle_hud_3.png tools/gen_battle_hud_inc.py
	python3 tools/gen_battle_hud_inc.py

assets/trainer_pics.inc: ../gfx/pics.asm ../data/trainers/pic_pointers_money.asm \
                         tools/gen_trainer_pics.py
	python3 tools/gen_trainer_pics.py

# Gym-leader face + badge tiles (2bpp passthrough of gfx/trainer_card/badges.2bpp)
# for the trainer-card status screen (draw_badges.asm, menus S6 package B).
assets/badge_tiles.inc: ../gfx/trainer_card/badges.2bpp \
                        ../constants/ram_constants.asm tools/gen_badge_tiles.py
	python3 tools/gen_badge_tiles.py

src/engine/menus/draw_badges.o: assets/badge_tiles.inc

# Start menu checks EVENT_GOT_POKEDEX via events.inc → event_constants.inc;
# DrawStartMenu %includes the generated menu_strings.inc labels and the
# UI_START_MENU_* equates; start_sub_menus needs the UI_USE_TOSS_* equates.
src/home/start_menu.o: assets/event_constants.inc
src/engine/menus/draw_start_menu.o: assets/event_constants.inc \
        assets/menu_strings.inc assets/ui_layout_menus.inc
src/engine/menus/start_sub_menus.o: assets/ui_layout_menus.inc
src/engine/items/item_effects.o: assets/ui_layout_menus.inc

# Pokémon base stats + IndexToPokedex (static data, generated from pret source).
assets/base_stats.inc:
	python3 tools/gen_base_stats.py

# GrowthRateTable (static data, generated from data/growth_rates.asm).
assets/growth_rates.inc:
	python3 tools/gen_growth_rates.py

# Moves table (static data, generated from data/moves/moves.asm).
assets/moves.inc:
	python3 tools/gen_moves.py

# Evolution + level-up learnset data (generated from data/pokemon/evos_moves.asm).
assets/evos_moves.inc:
	python3 tools/gen_evos_moves.py

# Species names (generated from data/pokemon/names.asm via the GB charmap).
assets/monster_names.inc:
	python3 tools/gen_monster_names.py

# Item names + prices (generated from data/items/{names,prices}.asm).
assets/items.inc:
	python3 tools/gen_items.py

src/data/item_data.o: assets/items.inc

src/data/pokemon_data.o: assets/base_stats.inc assets/growth_rates.inc \
                         assets/moves.inc assets/evos_moves.inc assets/monster_names.inc

# Type effectiveness table (static data, generated from data/types/type_matchups.asm).
assets/type_matchups.inc:
	python3 tools/gen_type_matchups.py

# Move names (generated from data/moves/names.asm via the GB charmap; '@'-terminated).
assets/move_names.inc:
	python3 tools/gen_move_names.py

# Move-effect category lists (generated from data/battle/*.asm; $FF-terminated).
assets/effect_categories.inc:
	python3 tools/gen_effect_categories.py

src/data/battle_data.o: assets/type_matchups.inc assets/move_names.inc \
                        assets/effect_categories.inc

# Field-move display data + names (generated from data/moves/{field_moves,
# field_move_names}.asm; resolves move ids via constants/move_constants.asm).
assets/field_moves.inc:
	python3 tools/gen_field_moves.py

src/engine/menus/field_moves.o: assets/field_moves.inc

# DisplayTextBoxID_ tables embed the generated UI layout geometry (menus S2);
# the BATTLE/SAFARI template rows come from the battle layout (battle-UI B5).
# DisplayTextIDInit checks EVENT_GOT_POKEDEX via events.inc → event_constants.inc.
src/engine/menus/text_box.o: assets/ui_layout_menus.inc assets/ui_layout_battle.inc
src/engine/menus/display_text_id_init.o: assets/event_constants.inc

# UI layout geometry — projected menu-window coordinates. The sidecar JSON is
# hand-positioned via tools/ui_layout/editor.py (never hand-edited as text);
# the .inc is Tier-1 machine output keyed by element ID (docs/current_plan_menus.md).
assets/ui_layout_menus.inc: assets/ui_layout_menus_sidecar.json \
		tools/gen_ui_layout.py tools/ui_layout/canvas.py tools/ui_layout/schema.py
	python3 tools/gen_ui_layout.py menus

# Battle UI layout geometry (docs/current_plan_battle_ui.md). Sidecar seeded
# from the legacy battle %defines by tools/ui_layout/seed_from_battle.py
# (asserts byte-identical geometry); redesigned via tools/ui_layout/battle.py.
assets/ui_layout_battle.inc: assets/ui_layout_battle_sidecar.json \
		tools/gen_ui_layout.py tools/ui_layout/canvas.py tools/ui_layout/schema.py
	python3 tools/gen_ui_layout.py battle

src/engine/battle/battle_hud.o src/engine/battle/init_battle.o \
src/engine/battle/pokeballs.o src/gfx/pics.o \
src/engine/battle/core.o src/engine/battle/battle_menu.o: \
        assets/ui_layout_battle.inc

# Authored map border-ring overrides (map-tool C3): painted in
# tools/map_editor/editor.py paint mode -> assets/map_borders/*.json ->
# this Tier-1 .inc, consumed by overworld.asm ApplyMapBorderOverrides.
assets/map_border_overrides.inc: $(wildcard assets/map_borders/*.json) \
		tools/gen_map_borders.py tools/map_editor/borders.py \
		tools/map_editor/view.py tools/gfx_core/pret_maps.py
	python3 tools/gen_map_borders.py

src/engine/overworld/overworld.o: assets/map_border_overrides.inc

# Wild-encounter tables (static data, generated from data/wild/).
assets/wild_data.inc:
	python3 tools/gen_wild_encounters.py

src/data/wild_data.o: assets/wild_data.inc

# Super Rod fishing slots (generated from data/wild/super_rod.asm; internal-index
# species). Embedded directly by super_rod.asm.
assets/super_rod.inc:
	python3 tools/gen_super_rod.py

src/engine/items/super_rod.o: assets/super_rod.inc

# Town-map data + graphics (generated from data/maps/{town_map_entries,
# town_map_order,names}.asm + gfx/town_map/). Consumed by town_map.asm.
assets/town_map_data.inc assets/town_map_gfx.inc:
	python3 tools/gen_town_map.py

src/engine/items/town_map.o: assets/town_map_data.inc assets/town_map_gfx.inc

# CanLearnTM/TMToMove index TechnicalMachines (added to items.inc by gen_items.py).
src/engine/items/tms.o: assets/items.inc

assets: assets/overworld_gfx.inc assets/overworld_blocks.inc assets/pallet_town_blk.inc \
        assets/map_headers.inc assets/extra_includes.inc \
        assets/npc_sprite_data_table.inc assets/npc_dialogs/all_dialogs.inc \
        assets/toggleable_objects.inc assets/event_constants.inc \
        assets/base_stats.inc assets/growth_rates.inc \
        assets/moves.inc assets/evos_moves.inc assets/monster_names.inc \
        assets/items.inc assets/gb_charmap.txt assets/menu_strings.inc \
        assets/type_matchups.inc assets/move_names.inc assets/field_moves.inc \
        assets/effect_categories.inc \
        assets/wild_data.inc assets/map_scripts.inc assets/battle_hud_2bpp.inc \
        assets/trainer_pics.inc \
        assets/super_rod.inc assets/town_map_data.inc assets/town_map_gfx.inc \
        assets/ui_layout_menus.inc assets/ui_layout_battle.inc \
        assets/map_border_overrides.inc assets/badge_tiles.inc

all: $(TARGET)

$(TARGET): $(LINK_OBJS) link.ld
	$(LD) $(LDFLAGS) -Map=pkmn.map $(LINK_OBJS) -o $@
	@echo "Built: $@"

%.o: %.asm
	$(NASM) $(NASMFLAGS) -o $@ $<

# Assemble-only check (no link): useful for syntax verification
check:
	@for src in $(ALL_SRCS); do \
	    echo "Checking: $$src"; \
	    $(NASM) $(NASMFLAGS) -o /dev/null $$src || exit 1; \
	done
	@echo "All files assembled successfully."

clean:
	rm -f $(ALL_OBJS) $(TARGET)
