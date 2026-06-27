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
    src/home/copy_data.asm

HAL_SRCS := \
    src/ppu/ppu.asm \
    src/input/joypad.asm

# Phase 2: game-loop core
GAME_SRCS := \
    src/init/init.asm \
    src/video/lcd_control.asm \
    src/video/frame.asm \
    src/gfx/sprites.asm \
    src/gfx/sprite_oam.asm \
    src/gfx/load_font.asm \
    src/text/text.asm \
    src/text/auto_textbox.asm \
    src/movie/title.asm \
    src/engine/overworld/overworld.asm \
    src/engine/overworld/movement.asm \
    src/engine/overworld/map_sprites.asm \
    src/engine/overworld/run_map_script.asm \
    src/data/map_scripts.asm \
    src/scripts/pallet_town.asm \
    src/engine/math/random.asm \
    src/engine/menus/start_menu.asm \
    src/engine/menus/bag_menu.asm \
    src/engine/menus/party_menu.asm \
    src/engine/menus/field_moves.asm

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
    src/engine/pokemon/load_mon_data.asm \
    src/engine/pokemon/set_types.asm \
    src/engine/pokemon/remove_mon.asm \
    src/engine/pokemon/write_moves.asm

# Items layer (current_plan_items.md). Non-UI inventory/bag logic + item data.
ITEMS_SRCS := \
    src/data/item_data.asm \
    src/engine/items/inventory.asm \
    src/engine/items/item_effects.asm \
    src/engine/items/item_price.asm \
    src/engine/items/tm_prices.asm \
    src/engine/items/subtract_paid_money.asm \
    src/home/compare.asm \
    src/engine/math/bcd.asm

# Battle engine backend (current_plan_battle_engine.md). Damage pipeline + data.
# NOTE: the backend depends on UI/effect routines (JumpMoveEffect, CheckTarget-
# Substitute, …) that are still deferred, so this does not yet link into the
# final EXE — but every file assembles (make check) and the pure-math routines
# are validated by native ELF harnesses (see the plan's verification log).
BATTLE_SRCS := \
    src/data/battle_data.asm \
    src/home/names.asm \
    src/engine/battle/core_damage.asm \
    src/engine/battle/badge_boosts.asm \
    src/engine/battle/status_penalties.asm \
    src/engine/battle/decrement_pp.asm \
    src/engine/battle/get_trainer_name.asm \
    src/engine/battle/misc.asm \
    src/engine/battle/move_effects/conversion.asm \
    src/engine/battle/move_effects/drain_hp.asm \
    src/engine/battle/move_effects/focus_energy.asm \
    src/engine/battle/move_effects/haze.asm \
    src/engine/battle/move_effects/heal.asm \
    src/engine/battle/move_effects/leech_seed.asm \
    src/engine/battle/move_effects/mist.asm \
    src/engine/battle/move_effects/one_hit_ko.asm \
    src/engine/battle/move_effects/paralyze.asm \
    src/engine/battle/move_effects/pay_day.asm \
    src/engine/battle/move_effects/recoil.asm \
    src/engine/battle/move_effects/reflect_light_screen.asm \
    src/engine/battle/stat_mod_effects.asm \
    src/engine/battle/effects.asm \
    src/engine/battle/building_rage.asm \
    src/engine/battle/residual_damage.asm \
    src/engine/battle/get_current_move.asm \
    src/engine/battle/move_category.asm \
    src/engine/battle/animations.asm \
    src/data/wild_data.asm \
    src/engine/overworld/wild_mons.asm \
    src/engine/battle/wild_encounters.asm \
    src/engine/battle/experience.asm \
    src/engine/battle/trainer_ai.asm \
    src/engine/battle/read_trainer_party.asm
# experience.asm (GainExperience) is in BATTLE_SRCS (check-only) — assembles +
# native-validated, but stays out of LINK_SRCS until Wave 2 supplies its deferred
# UI/display externs (PrintText, PrintStatsBox, the CallBattleCore targets, …).

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
# Variant of DEBUG_BAGMENU that also overlays the toss YES/NO confirmation box
# (static, for a visual check of the confirm menu). make DEBUG_BAGMENU_CONFIRM=1
ifdef DEBUG_BAGMENU_CONFIRM
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_BAGMENU -D DEBUG_BAGMENU_CONFIRM
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
    src/engine/battle/init_battle.asm

LINK_SRCS := $(BOOT_SRCS) $(HOME_SRCS) $(HAL_SRCS) $(GAME_SRCS) $(POKEMON_SRCS) $(ITEMS_SRCS) $(FRONTEND_SRCS)
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

# ALL_SRCS = everything that must assemble cleanly (check) and be cleaned, incl.
# the not-yet-linked battle backend + check-only pokemon backend.
ALL_SRCS := $(LINK_SRCS) $(BATTLE_SRCS) $(POKEMON_CHECK_SRCS)
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

# Start menu checks EVENT_GOT_POKEDEX via events.inc → event_constants.inc, and
# %includes the generated menu_strings.inc label block.
src/engine/menus/start_menu.o: assets/event_constants.inc assets/menu_strings.inc

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

# Wild-encounter tables (static data, generated from data/wild/).
assets/wild_data.inc:
	python3 tools/gen_wild_encounters.py

src/data/wild_data.o: assets/wild_data.inc

assets: assets/overworld_gfx.inc assets/overworld_blocks.inc assets/pallet_town_blk.inc \
        assets/map_headers.inc assets/extra_includes.inc \
        assets/npc_sprite_data_table.inc assets/npc_dialogs/all_dialogs.inc \
        assets/toggleable_objects.inc assets/event_constants.inc \
        assets/base_stats.inc assets/growth_rates.inc \
        assets/moves.inc assets/evos_moves.inc assets/monster_names.inc \
        assets/items.inc assets/gb_charmap.txt assets/menu_strings.inc \
        assets/type_matchups.inc assets/move_names.inc assets/field_moves.inc \
        assets/effect_categories.inc \
        assets/wild_data.inc assets/map_scripts.inc

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
