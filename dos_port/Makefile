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

# Real per-mon front sprites: pics.asm indexes MonFrontPics (src/data/mon_pics.asm,
# generated). Without this every mon draws the single embedded debug pic (pidgey).
NASMFLAGS += -D MON_FRONT_PICS

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

# Isolated-run disk image (see the `image` target below).
IMG          := PKMN.IMG
DPMI_HOST    := CWSDPMI.EXE
IMG_SLACK    := 5242880          # 5 MB of free space reserved for the .dsv save
IMG_PART_SEC := 2048             # partition start sector (1 MiB-aligned)
IMG_PART_OFF := 1048576          # = IMG_PART_SEC * 512 (byte offset for mtools)

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
    src/home/item.asm \
    src/home/count_set_bits.asm \
    src/home/reset_player_sprite.asm \
    src/home/map_text_pointer.asm \
    src/home/reload_tiles.asm

HAL_SRCS := \
    src/ppu/ppu.asm \
    src/input/joypad.asm \
    src/input/joypad_lowsens.asm

# Save HAL — .dsv file I/O (menus S7). DsvFileExists/DsvWriteSave/DsvReadSave;
# the SRAM-banking seam every pret save/load routine collapses onto.
SAVE_SRCS := \
    src/save/dsv_io.asm

# Audio subsystem (docs/current_plan_audio.md Phase A). The translated pret
# engine writes the virtual APU block at [ebp+rAUD*]; the DelayFrame tick +
# device shims (opl_shim) land in later Phase A tasks. Data blobs are
# generated by tools/audio/gen_audio_data.py (`make assets`).
AUDIO_SRCS := \
    src/data/audio_data.asm \
    src/home/audio.asm \
    src/audio/audio_hal.asm \
    src/audio/opl_shim.asm \
    src/audio/opl_enh.asm \
    src/audio/tandy_shim.asm \
    src/audio/spk_shim.asm \
    src/audio/mpu401.asm \
    src/audio/sb_pcm.asm \
    src/audio/spk_pcm.asm \
    src/engine/pikachu/pikachu_pcm.asm \
    src/audio/engine_1.asm \
    src/audio/engine_2.asm \
    src/audio/engine_3.asm \
    src/audio/engine_4.asm \
    src/audio/low_health_alarm.asm \
    src/audio/play_battle_music.asm \
    src/audio/pokedex_rating_sfx.asm \
    src/audio/poke_flute.asm \
    src/audio/alternate_tempo.asm

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
    src/engine/movie/oak_speech/init_player_data.asm \
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
    src/engine/menus/trainer_card.asm \
    src/engine/menus/pc.asm \
    src/engine/menus/pc_stubs.asm \
    src/engine/menus/oaks_pc.asm \
    src/engine/menus/league_pc.asm \
    src/engine/menus/league_pc_stubs.asm \
    src/engine/menus/options.asm \
    src/engine/menus/players_pc.asm \
    src/engine/menus/display_text_id_init.asm \
    src/engine/menus/main_menu.asm \
    src/engine/menus/main_menu_stubs.asm \
    src/engine/menus/save.asm \
    src/engine/menus/naming_screen.asm \
    src/engine/menus/pokedex.asm \
    src/engine/menus/pokedex_entry.asm \
    src/engine/menus/link_menu.asm \
    src/engine/menus/link_cups.asm \
    src/engine/overworld/reload_sprites.asm \
    src/engine/overworld/simulate_joypad.asm \
    src/engine/overworld/overworld_stubs.asm \
    src/engine/overworld/daycare_exp.asm \
    src/engine/overworld/is_player_just_outside_map.asm \
    src/engine/overworld/dungeon_warps.asm \
    src/engine/overworld/specific_script_flags.asm \
    src/engine/overworld/clear_variables.asm \
    src/engine/overworld/wild_encounter_check.asm \
    src/data/wild_data.asm \
    src/engine/overworld/wild_mons.asm \
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
    src/engine/gfx/hp_bar.asm \
    src/engine/pokemon/status_screen.asm \
    src/engine/pokemon/get_max_pp.asm \
    src/engine/pokemon/knows_hm_move.asm \
    src/engine/pikachu/pikachu_status.asm \
    src/engine/pokemon/evolution.asm \
    src/engine/pokemon/learn_move.asm

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
# read_trainer_party) still depend on deferred predefs/UI/text and are stubbed at
# link time by core_stubs.asm (JumpMoveEffect / HandlePoisonBurnLeechSeed / TrainerAI /
# FormatMovesString). Every file here still assembles (make check) and the pure-math
# routines are native-ELF-harness validated.
BATTLE_SRCS := \
    src/engine/battle/get_trainer_name.asm \
    src/engine/battle/misc.asm \
    src/engine/battle/move_category.asm \
    src/engine/battle/wild_encounters.asm
# trainer_ai.asm + read_trainer_party.asm MOVED to FRONTEND_SRCS (battle-swarm-C): the
# class-based enemy-move AI (AIEnemyTrainerChooseMoves) and trainer-party loader now link
# live — their closures resolve (AIGetTypeEffectiveness/Moves/Divide/IsInArray/Random +
# TrainerDataPointers/SpecialTrainerMoves/AddPartyMon/AddBCDPredef). wild_data.asm +
# wild_mons.asm (LoadWildData/WildDataPointers) MOVED to GAME_SRCS (OW-A.5): they form a
# self-contained 2-file unit (data table + inline flat→WRAM loader, no battle deps) and now
# link live so LoadMapHeader can populate per-map wGrassMons/wWaterMons. wild_encounters.asm
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
# Audio-engine gate: start BGM through the real gateway at boot, tick the
# engine, dump audio RAM + virtual APU to DUMP.BIN, exit. With the /LOOP exe
# flag (dos_port/run DEBUG_AUDIO=1 /LOOP) it instead plays the song forever.
# TRACK=<MUSIC_* constant> picks the song (default MUSIC_GAME_CORNER), e.g.
#   dos_port/run DEBUG_AUDIO=1 TRACK=MUSIC_CELADON /LOOP
ifdef DEBUG_AUDIO
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_AUDIO
NASMFLAGS += -D SKIP_TITLE
ifdef TRACK
NASMFLAGS += -D DEBUG_AUDIO_TRACK=$(TRACK)
endif
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
GAME_SRCS += src/engine/debug/debug_party.asm  # SeedDeterministicPlayerIdentity ("RED" menu row)
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
# Empty-inventory variant of the bag-menu gate (list = just CANCEL — the live
# worst-case border-corruption repro). make DEBUG_BAGMENU=1 DEBUG_BAGMENU_EMPTY=1
ifdef DEBUG_BAGMENU_EMPTY
NASMFLAGS += -D DEBUG_BAGMENU_EMPTY
endif
# Live, interactive bag test: seed a full bag + money and boot to the overworld;
# open the bag via START -> ITEM to drive the list / toss / YES-NO confirm by hand.
# make DEBUG_BAGMENU_LIVE=1 (then dos_port/run, or build + launch DOSBox-X).
ifdef DEBUG_BAGMENU_LIVE
NASMFLAGS += -D DEBUG_BAGMENU_LIVE
NASMFLAGS += -D SKIP_TITLE
GAME_SRCS += src/engine/debug/debug_party.asm
endif
# Plain playable build with a seeded party — NO frame dump, NO SKIP_TITLE. Boots
# the full path (title -> main menu -> NEW GAME -> overworld with a seeded party)
# so you can reach the stats screen the real way (START -> POKéMON -> mon -> STATS).
# make DEBUG_SEED_PARTY=1 (then dos_port/run).
ifdef DEBUG_SEED_PARTY
NASMFLAGS += -D DEBUG_SEED_PARTY
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
# Trainer-card gate (menus S9): boot to overworld, seed name/money/time/badges,
# draw the full TRAINER CARD (DrawTrainerInfo + DrawBadges + pic), composite it,
# dump FRAME.BIN, exit. make SKIP_TITLE=1 DEBUG_TRAINERCARD=1
ifdef DEBUG_TRAINERCARD
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_TRAINERCARD
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
# Main-menu gate (menus S7 package E): boot to overworld, seed a save (party +
# name/badges/dex/time + DsvWriteSave), draw the CONTINUE/NEW GAME box + info
# panel, dump FRAME.BIN, exit. make SKIP_TITLE=1 DEBUG_MAINMENU=1
ifdef DEBUG_MAINMENU
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_MAINMENU
NASMFLAGS += -D SKIP_TITLE
GAME_SRCS += src/engine/debug/debug_party.asm
endif
# Save gate (menus S7 package H): boot to overworld, seed party+bag+badges, run
# SaveGameData through the confirm (auto-YES), dump the "saved!" FRAME.BIN, exit.
# DEBUG_SAVE_ROUNDTRIP dumps a DsvWriteSave->DsvFileExists marker instead.
# make SKIP_TITLE=1 DEBUG_SAVE=1
ifdef DEBUG_SAVE
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_SAVE
NASMFLAGS += -D SKIP_TITLE
GAME_SRCS += src/engine/debug/debug_party.asm
endif
ifdef DEBUG_SAVE_ROUNDTRIP
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_SAVE
NASMFLAGS += -D DEBUG_SAVE_ROUNDTRIP
NASMFLAGS += -D SKIP_TITLE
GAME_SRCS += src/engine/debug/debug_party.asm
endif
# Naming-screen gate (menus S7 package C): boot to overworld, open the PLAYER
# naming screen, draw the uppercase letter grid, dump FRAME.BIN, exit.
# make SKIP_TITLE=1 DEBUG_NAMINGSCREEN=1
ifdef DEBUG_NAMINGSCREEN
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_NAMINGSCREEN
NASMFLAGS += -D SKIP_TITLE
endif
# Pokédex gates (menus S8 package G). G1: seed seen/owned, draw CONTENTS list.
# G2: open RHYDON dex data page (front pic + HT/WT). Dump FRAME.BIN, exit.
# make SKIP_TITLE=1 DEBUG_G1=1  /  DEBUG_G2=1
ifdef DEBUG_G1
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_G1
NASMFLAGS += -D SKIP_TITLE
endif
ifdef DEBUG_G2
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_G2
NASMFLAGS += -D SKIP_TITLE
endif
# Link-menu gates (menus S8 package I). I1: open the cup-select screen (serial
# stubbed to the no-partner timeout). I2: run the cup validators (a pass + a
# gated fail) and record result codes. Dump FRAME.BIN, exit.
# make SKIP_TITLE=1 DEBUG_I1=1  /  DEBUG_I2=1
ifdef DEBUG_I1
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_I1
NASMFLAGS += -D SKIP_TITLE
endif
ifdef DEBUG_I2
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_I2
NASMFLAGS += -D SKIP_TITLE
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
# Level-up move-learn gate (current_plan_pokemon_behavior Stage 3): force
# STARTER_PIKACHU (party slot 3) 5->6, call LearnMoveFromLevelUp directly (no
# battle/input needed), render one frame, dump FRAME.BIN, exit. make DEBUG_LEARNMOVE=1
ifdef DEBUG_LEARNMOVE
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_LEARNMOVE
NASMFLAGS += -D SKIP_TITLE
GAME_SRCS += src/engine/debug/debug_party.asm
endif
# Sub-flag of DEBUG_LEARNMOVE: fill all 4 move slots first, so the deferred
# all-slots-full (AbandonLearning) branch renders instead of the common path.
# make DEBUG_LEARNMOVE=1 DEBUG_LEARNMOVE_FULL=1
ifdef DEBUG_LEARNMOVE_FULL
NASMFLAGS += -D DEBUG_LEARNMOVE_FULL
endif
# Status-screen gate: seed the party, open the status/summary screen (page 1) for
# STARTER_PIKACHU (party slot 3), render one frame, dump FRAME.BIN, exit.
# make DEBUG_STATUS=1
# Sub-flag of DEBUG_STATUS: render summary-screen page 2 (moves/PP/EXP) instead of
# page 1. make DEBUG_STATUS=1 DEBUG_STATUS_PAGE2=1  (implies DEBUG_STATUS)
ifdef DEBUG_STATUS_PAGE2
DEBUG_STATUS := 1
NASMFLAGS += -D DEBUG_STATUS_PAGE2
endif
ifdef DEBUG_STATUS
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_STATUS
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
    src/data/mon_pics.asm \
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
    src/engine/battle/end_of_battle.asm \
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

LINK_SRCS := $(BOOT_SRCS) $(HOME_SRCS) $(HAL_SRCS) $(SAVE_SRCS) $(AUDIO_SRCS) $(GAME_SRCS) $(POKEMON_SRCS) $(ITEMS_SRCS) $(FRONTEND_SRCS) $(BATTLE_SUPPORT_SRCS)
# Stable de-dup: several DEBUG_* gates each append debug_party.asm, so combining two
# (e.g. DEBUG_SEED_PARTY + DEBUG_STATUS) would list its object twice → ld "multiple
# definition". Drop duplicates while preserving first-seen order (link layout unchanged).
uniq = $(if $1,$(firstword $1) $(call uniq,$(filter-out $(firstword $1),$1)))
LINK_OBJS := $(call uniq,$(LINK_SRCS:.asm=.o))

# Pokémon backend that assembles + is native-harness-validated but is NOT linked
# yet. bills_pc needs a link-ready _MoveMon (the draft in add_mon.asm has a
# duplicate AddPartyMon_WriteMovePP symbol + extern-constant errors and an
# unresolved dependency closure).
# (evolution.asm + pikachu_status.asm are now LINKED — moved to POKEMON_SRCS,
#  current_plan_pokemon_behavior Stage 2.)
POKEMON_CHECK_SRCS := \
    src/engine/pokemon/bills_pc.asm

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
    src/home/text_script.asm \
    src/home/predef_text.asm \
    src/home/give.asm \
    src/home/money.asm \
    src/home/oam.asm \
    src/home/vcopy.asm \
    src/engine/overworld/pikachu.asm \
    src/engine/overworld/player_gfx.asm \
    src/engine/overworld/overworld_text.asm \
    src/engine/overworld/ledges.asm \
    src/engine/overworld/pathfinding.asm \
    src/engine/overworld/trainer_engine.asm \
    src/engine/overworld/npc_movement_2.asm \
    src/engine/overworld/auto_movement.asm \
    src/engine/overworld/update_map.asm \
    src/engine/events/pewter_guys.asm \
    src/engine/overworld/push_boulder.asm \
    src/engine/overworld/dust_smoke.asm \
    src/engine/overworld/field_move_messages.asm \
    src/engine/overworld/toggleable_objects.asm \
    src/engine/overworld/player_state.asm
# player_state.asm (OW-1.8) is check-only: externs ForceBikeOrSurf (in check-only
# player_gfx.asm) and IsPlayerStandingOnDoorTile (linked in overworld.asm but not yet
# `global`). Promote to GAME_SRCS once both resolve (OW-A.3 adds the global; OW-7.2
# promotes player_gfx). Also: its H_WARP_DESTINATION_MAP placeholder wrongly aliases
# 0xFF8B (hPreviousTileset) — give it a distinct HRAM byte before linking.
# npc_movement_2.asm (OW-1.6) is check-only: its tail-jump SetSpriteMovementBytesToFF
# lives in pathfinding.asm (also check-only). Promote to GAME_SRCS with pathfinding (OW-7.2).
# reload_sprites.asm promoted to GAME_SRCS (menus S7): naming_screen.asm calls
# ReloadMapSpriteTilePatterns; its externs (DisableLCD/EnableLCD/InitMapSprites/
# LoadPlayerSpriteGraphics/LoadFontTilePatterns/UpdateSprites) are all linked.

# ALL_SRCS = everything that must assemble cleanly (check) and be cleaned, incl.
# the not-yet-linked battle backend + check-only pokemon/items/home backends.
ALL_SRCS := $(LINK_SRCS) $(BATTLE_SRCS) $(POKEMON_CHECK_SRCS) $(ITEMS_CHECK_SRCS) $(HOME_CHECK_SRCS)
ALL_OBJS := $(ALL_SRCS:.asm=.o)

# ---------------------------------------------------------------------------
# Targets
# ---------------------------------------------------------------------------

.PHONY: all clean clean-image image check assets regen goldens goldencheck fidelity
.DEFAULT_GOAL := all

# Regenerate the committed mGBA goldens (tests/goldens/) from the
# sha1-verified ROM in the pinned pret worktree. See the fidelity plan +
# tools/mgba_harness/make_goldens.sh for prerequisites (build_mgba.sh,
# ../pokeyellow_msdos-pret-golden).
goldens:
	tools/mgba_harness/make_goldens.sh

# Diff the port's GB state against an mGBA golden (fidelity plan Stage 1.4):
# build the scenario's DEBUG_* image, run it headless, extract GBSTATE.BIN,
# cell/slot-diff vs tests/goldens/<scenario>.  make goldencheck SCENARIO=status_p1
goldencheck:
	tools/goldencheck.sh $(SCENARIO)

# All golden scenarios (the port-vs-golden fidelity suite). Runs every
# scenario even if one fails; nonzero exit if any failed.
FIDELITY_SCENARIOS := status_p1 status_p2 start_menu overworld_pallet party_menu bag_menu
fidelity:
	@fail=0; for s in $(FIDELITY_SCENARIOS); do \
		tools/goldencheck.sh $$s || fail=1; \
	done; exit $$fail

# Generate all tileset gfx/blocks/coll + map blk inc files.
# Requires gfx/tilesets/*.2bpp, built by 'make' in the repo root.
# Authored map edits (assets/map_overrides/*.json, map-tool C5) are merged
# into the emitted <map>_blk.inc files.
assets/overworld_gfx.inc assets/overworld_blocks.inc assets/pallet_town_blk.inc: \
		$(wildcard assets/map_overrides/*.json)
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

# Per-map (music id, ROM bank) table — pret data/maps/songs.asm (gen_map_songs.py).
# LoadMapHeader loads it into wMapMusicSoundID/wMapMusicROMBank (OW-A.14).
assets/map_songs.inc: tools/gen_map_songs.py
	python3 tools/gen_map_songs.py

# Overworld object depends on all generated assets
src/engine/overworld/overworld.o: \
    assets/overworld_gfx.inc \
    assets/overworld_blocks.inc \
    assets/pallet_town_blk.inc \
    assets/map_headers.inc \
    assets/extra_includes.inc \
    assets/map_songs.inc

# NPC sprite sheets — all sprites used across all maps (generated by gen_all_assets.py)
assets/npc_sprite_data_table.inc:
	python3 tools/gen_all_assets.py

# Full-coverage sprite sheet pointer table (OW-A.2 P3a) — all NUM_SPRITES, incl.
# outside-map fillers the map-object scan misses. Consumed by the faithful
# map_sprites.asm sprite-set machinery from P3c on (self-contained include).
assets/sprite_sheet_pointers.inc:
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

# Fixed outside-map sprite sets (pret data/maps/sprite_sets.asm) — OW-A.2 sprite-set
# machinery in map_sprites.asm. Pure data (no gfx dep); consumed from Phase 3 onward.
assets/sprite_sets.inc: tools/gen_sprite_sets.py
	python3 tools/gen_sprite_sets.py

# map_sprites depends on the NPC tile asset table, all-maps dialog table, the
# toggleable-object (event) flag tables, and the event-flag constants (events.inc).
src/engine/overworld/map_sprites.o: \
    assets/sprite_sets.inc \
    assets/sprite_sheet_pointers.inc \
    assets/npc_dialogs/all_dialogs.inc \
    assets/toggleable_objects.inc \
    assets/event_constants.inc

# Pallet Town text_asm scripts include events.inc → event_constants.inc.
src/scripts/pallet_town.o: assets/event_constants.inc

# Per-map script dispatch table (generated from constants/map_constants.asm).
assets/map_scripts.inc:
	python3 tools/gen_map_scripts.py

src/data/map_scripts.o: assets/map_scripts.inc

src/data/audio_data.o: assets/audio_rom.inc assets/cry_data.inc
src/audio/opl_shim.o: assets/opl_patches.inc
src/audio/opl_enh.o: assets/enh_streams.inc assets/audio_constants.inc

src/audio/tandy_shim.o: assets/tandy_tables.inc
src/audio/mpu401.o: assets/music_streams.inc assets/mt32_sysex.inc \
                    assets/audio_constants.inc
src/engine/pikachu/pikachu_pcm.o: assets/pika_pcm.inc assets/pika_pcm.bin

# Pikachu voice clips (Phase C): pret's 1-bit 22 kHz streams -> low-pass-
# filtered 8-bit PCM blob + pointer table for sb_pcm/spk_pcm.
assets/pika_pcm.inc assets/pika_pcm.bin &: tools/audio/gen_pika_pcm.py \
                       $(wildcard ../audio/pikachu_cries/*.wav)
	python3 tools/audio/gen_pika_pcm.py

# MT-32 setup SysEx (LCD greeting, reverb/partial reserves, custom timbres)
# from the hand-editable tools/audio/mt32/timbres.yaml.
assets/mt32_sysex.inc: tools/audio/gen_mt32_patches.py \
                       tools/audio/mt32/timbres.yaml
	python3 tools/audio/gen_mt32_patches.py
assets/opl_patches.inc: tools/audio/gen_opl_patches.py
	python3 tools/audio/gen_opl_patches.py

# SN76489 attenuation tables for the Tandy shim.
assets/tandy_tables.inc: tools/audio/gen_tandy_tables.py
	python3 tools/audio/gen_tandy_tables.py
src/home/audio.o src/audio/engine_1.o src/audio/engine_2.o \
src/audio/engine_3.o src/audio/engine_4.o src/audio/low_health_alarm.o \
src/audio/play_battle_music.o src/audio/pokedex_rating_sfx.o \
src/audio/poke_flute.o src/audio/alternate_tempo.o \
src/init/init.o: assets/audio_constants.inc

# GB character map in the unicode_converter's format (single-char → byte), for
# the converter submodule + gb_text.py. Generated from constants/charmap.asm.
assets/gb_charmap.txt:
	python3 tools/gen_charmap.py

# START-menu item labels, encoded via the unicode_converter submodule (gb_text).
assets/menu_strings.inc: assets/gb_charmap.txt tools/gen_menu_strings.py tools/gb_text.py
	python3 tools/gen_menu_strings.py

# Status/summary-screen PlaceString labels (charmap-encoded via gb_text; two-tier rule).
assets/status_strings.inc: assets/gb_charmap.txt tools/gen_status_strings.py tools/gb_text.py
	python3 tools/gen_status_strings.py

assets/overworld_strings.inc assets/field_move_text.inc &: assets/gb_charmap.txt \
                            tools/gen_overworld_strings.py tools/gb_text.py \
                            tools/gen_battle_text.py ../data/text/text_8.asm ../constants/charmap.asm
	python3 tools/gen_overworld_strings.py

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
                            ../gfx/battle/battle_hud_3.png ../gfx/font/P.1bpp tools/gen_battle_hud_inc.py
	python3 tools/gen_battle_hud_inc.py

assets/trainer_pics.inc: ../gfx/pics.asm ../data/trainers/pic_pointers_money.asm \
                         tools/gen_trainer_pics.py
	python3 tools/gen_trainer_pics.py

# Pokémon front battle sprites (compressed .pic) + dex-ordered MonFrontPics
# pointer/length table for LoadFrontSpriteByMonIndex.
assets/mon_pics.inc: ../data/pokemon/base_stats.asm tools/gen_mon_pics.py
	python3 tools/gen_mon_pics.py

src/data/mon_pics.o: assets/mon_pics.inc

# Audio engine data: four GB audio-bank images (headers + music/sfx bytecode
# at true GB addresses), positional sound-ID constants, cry-modifier table.
# Generated from the pret audio sources; byte-exact vs the reference ROM
# (verify with tools/audio/test_audio_data.py — needs a golden pokeyellow.gbc).
assets/audio_rom.inc assets/audio_constants.inc assets/cry_data.inc: \
		tools/audio/gen_audio_data.py tools/audio/pret_audio.py \
		../audio.asm ../constants/music_constants.asm ../data/pokemon/cries.asm
	python3 tools/audio/gen_audio_data.py

# MIDI music streams (Phase B): engine simulation -> .mid per song (also the
# soundtrack-export side goal) -> flat 60 Hz frame-delta streams for the
# MPU-401 driver. Hand-tuning lives in tools/audio/overrides/*.yaml.
# A stamp file stands in for the 49 per-song .mid outputs.
assets/midi/.stamp-mt32: tools/audio/gb_to_midi.py tools/audio/pret_audio.py \
		tools/audio/gen_audio_data.py ../audio.asm \
		../constants/music_constants.asm \
		tools/audio/yaml_lint.py tools/audio/music_analysis.py \
		$(wildcard tools/audio/overrides/*.yaml) \
		$(wildcard tools/audio/enhancements/*.yaml)
	python3 tools/audio/gb_to_midi.py --target mt32
	@touch $@

assets/music_streams.inc: assets/midi/.stamp-mt32 tools/audio/midi_to_stream.py
	python3 tools/audio/midi_to_stream.py --target mt32

# Tier-1 OPL enhancement streams from the hand/LLM-authored (never
# generated) enhancements/*.yaml, lint-gated per song.
assets/enh_streams.inc: tools/audio/gen_enh_streams.py \
                        tools/audio/yaml_lint.py tools/audio/music_analysis.py \
                        $(wildcard tools/audio/enhancements/*.yaml)
	python3 tools/audio/gen_enh_streams.py

# Gym-leader face + badge tiles (2bpp passthrough of gfx/trainer_card/badges.2bpp)
# for the trainer-card status screen (draw_badges.asm, menus S6 package B).
assets/badge_tiles.inc: ../gfx/trainer_card/badges.2bpp \
                        ../constants/ram_constants.asm tools/gen_badge_tiles.py
	python3 tools/gen_badge_tiles.py

src/engine/menus/draw_badges.o: assets/badge_tiles.inc

# Overworld emotion-bubble tiles (2bpp passthrough of gfx/emotes/*.2bpp) for
# EmotionBubble (engine/overworld/emotion_bubbles.asm, folded into trainer_engine.asm).
assets/emotes.inc: ../gfx/emotes/shock.2bpp ../gfx/emotes/question.2bpp \
                   ../gfx/emotes/happy.2bpp ../gfx/emotes/skull.2bpp \
                   ../gfx/emotes/heart.2bpp ../gfx/emotes/bolt.2bpp \
                   ../gfx/emotes/zzz.2bpp ../gfx/emotes/fish.2bpp \
                   tools/gen_emotes.py
	python3 tools/gen_emotes.py

src/engine/overworld/trainer_engine.o: assets/emotes.inc

# Trainer-card tile graphics (box/bg/blank-names/badge-numbers/colon/circle),
# 2bpp passthrough of gfx/trainer_card/*.2bpp + gfx/font/font_extra.2bpp, for the
# TRAINER CARD screen (trainer_card.asm, menus S9). Faces/badges come from
# assets/badge_tiles.inc (package B) via LoadBadgeTiles.
assets/trainer_card_tiles.inc: ../gfx/trainer_card/trainer_info.2bpp \
                               ../gfx/trainer_card/blank_leader_names.2bpp \
                               ../gfx/trainer_card/badge_numbers.2bpp \
                               ../gfx/trainer_card/circle_tile.2bpp \
                               ../gfx/font/font_extra.2bpp \
                               tools/gen_trainer_card_tiles.py
	python3 tools/gen_trainer_card_tiles.py

src/engine/menus/trainer_card.o: assets/trainer_card_tiles.inc assets/ui_layout_menus.inc

# Pokédex interface tiles (2bpp passthrough of gfx/pokedex/pokedex.2bpp + the
# plain pokéball tile from gfx/battle/balls.2bpp) for LoadPokedexTilePatterns.
assets/pokedex_tiles.inc: ../gfx/pokedex/pokedex.2bpp ../gfx/battle/balls.2bpp \
                          tools/gen_pokedex_tiles.py
	python3 tools/gen_pokedex_tiles.py

# Start menu checks EVENT_GOT_POKEDEX via events.inc → event_constants.inc;
# DrawStartMenu %includes the generated menu_strings.inc labels and the
# UI_START_MENU_* equates; start_sub_menus needs the UI_USE_TOSS_* equates.
src/home/start_menu.o: assets/event_constants.inc
src/engine/menus/draw_start_menu.o: assets/event_constants.inc \
        assets/menu_strings.inc assets/ui_layout_menus.inc
src/engine/menus/start_sub_menus.o: assets/ui_layout_menus.inc
src/engine/menus/pc.o: assets/ui_layout_menus.inc assets/event_constants.inc
src/engine/items/item_effects.o: assets/ui_layout_menus.inc
src/engine/menus/main_menu.o src/engine/menus/save.o: assets/ui_layout_menus.inc
src/engine/menus/naming_screen.o: assets/ui_layout_menus.inc assets/alphabets.inc
src/engine/menus/pokedex.o: assets/ui_layout_menus.inc assets/pokedex_tiles.inc
src/engine/menus/pokedex_entry.o: assets/ui_layout_menus.inc assets/dex_entries.inc
src/engine/menus/link_menu.o: assets/ui_layout_menus.inc
src/engine/menus/link_cups.o: assets/dex_entries.inc

# Status screen %includes the generated status_strings.inc label block.
src/engine/pokemon/status_screen.o: assets/status_strings.inc

# player_state.asm (PrintSafariZoneSteps) %includes the generated Safari HUD strings.
src/engine/overworld/player_state.o: assets/overworld_strings.inc

# field_move_messages.asm %includes the generated field-move FAR text streams.
src/engine/overworld/field_move_messages.o: assets/field_move_text.inc

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

# Naming-screen letter grids + <ED> toggle tile (menus S7, package C). Generated
# from data/text/alphabets.asm + constants/charmap.asm + gfx/font/ED.1bpp.
assets/alphabets.inc: ../data/text/alphabets.asm ../constants/charmap.asm \
                      ../gfx/font/ED.1bpp tools/gen_alphabets.py
	python3 tools/gen_alphabets.py

# Pokédex entries (menus S8, package G2 / I2). dex_entries = PokedexEntryPointers
# (flat dd) + inlined per-mon name/height/weight/flavor blobs (text_far flavor
# inlined). NOTE: the index->dex order table pret keeps as PokedexOrder is NOT
# regenerated here — the port already ships that exact byte table as the global
# `IndexToPokedex` (base_stats.inc); pokedex.asm's PokedexToIndex walks it.
assets/dex_entries.inc: ../data/pokemon/dex_entries.asm ../data/pokemon/dex_text.asm \
                        ../constants/charmap.asm tools/gen_dex_entries.py
	python3 tools/gen_dex_entries.py

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
        assets/map_headers.inc assets/extra_includes.inc assets/map_songs.inc \
        assets/npc_sprite_data_table.inc assets/npc_dialogs/all_dialogs.inc \
        assets/toggleable_objects.inc assets/event_constants.inc \
        assets/base_stats.inc assets/growth_rates.inc \
        assets/moves.inc assets/evos_moves.inc assets/monster_names.inc \
        assets/items.inc assets/gb_charmap.txt assets/menu_strings.inc \
        assets/status_strings.inc assets/overworld_strings.inc assets/field_move_text.inc \
        assets/type_matchups.inc assets/move_names.inc assets/field_moves.inc \
        assets/effect_categories.inc \
        assets/wild_data.inc assets/map_scripts.inc assets/battle_hud_2bpp.inc \
        assets/trainer_pics.inc \
        assets/super_rod.inc assets/town_map_data.inc assets/town_map_gfx.inc \
        assets/ui_layout_menus.inc assets/ui_layout_battle.inc \
        assets/map_border_overrides.inc assets/badge_tiles.inc \
        assets/trainer_card_tiles.inc assets/emotes.inc \
        assets/alphabets.inc assets/dex_entries.inc assets/sprite_sets.inc \
        assets/sprite_sheet_pointers.inc assets/pokedex_tiles.inc \
        assets/mon_pics.inc \
        assets/audio_rom.inc assets/audio_constants.inc assets/cry_data.inc \
        assets/opl_patches.inc assets/music_streams.inc assets/mt32_sysex.inc \
        assets/pika_pcm.inc assets/tandy_tables.inc assets/enh_streams.inc

# Force-regenerate every generated asset, ignoring timestamps. The asset rules
# are timestamp-gated (an .inc newer than its generator/source is skipped), which
# is a pain when you just want to force a clean regen. `make regen` rebuilds them
# all unconditionally via -B, then `make` (or `make regen && make`) picks them up.
# Use GEN_MAP_HEADERS_FLAGS=... / DEBUG_WARPS=1 here just as with `make assets`.
regen:
	$(MAKE) -B assets

all: $(TARGET) image

$(TARGET): $(LINK_OBJS) link.ld
	$(LD) $(LDFLAGS) -Map=pkmn.map $(LINK_OBJS) -o $@
	@echo "Built: $@"

# ---------------------------------------------------------------------------
# image — bundle PKMN.EXE + the DPMI host into a self-contained, PARTITIONED
# FAT16 hard-disk image (PKMN.IMG) with ~5 MB of free space for the in-game .dsv
# save. Running from the image (dos_port/run) makes DOSBox-X mount ONLY this file
# as C:, so the host filesystem is never exposed: a buffer-overflow / OOB disk
# write in the game (at ANY BUG_FIX_LEVEL) can corrupt only the image, not the
# repo. (DOSBox-X's hdd imgmount needs a real MBR + partition — a bare "superfloppy"
# FAT image fails to mount; hence sfdisk + a partition at sector $(IMG_PART_SEC).)
#
# Built on every `make` (fast). The image is created once at size EXE + host +
# 5 MB; subsequent builds refresh PKMN.EXE *in place* (via mtools at the partition
# offset $(IMG_PART_OFF)) and PRESERVE any save already written inside it. Delete
# PKMN.IMG (or `make clean-image`) to reset.
#
# Needs host tools: sfdisk, mkfs.fat (dosfstools), mcopy (mtools).
# ---------------------------------------------------------------------------
image: $(TARGET) $(DPMI_HOST)
	@if [ ! -f $(IMG) ]; then \
	    exe_sz=$$(stat -c%s $(TARGET)); \
	    dpmi_sz=$$(stat -c%s $(DPMI_HOST)); \
	    img_sz=$$(( ($(IMG_PART_OFF) + exe_sz + dpmi_sz + $(IMG_SLACK) + 1048576 + 511) / 512 * 512 )); \
	    rm -f $(IMG); \
	    truncate -s $$img_sz $(IMG); \
	    printf 'label: dos\n$(IMG_PART_SEC),,6,*\n' | sfdisk -q $(IMG) >/dev/null 2>&1; \
	    mkfs.fat -F 16 -n PKMN --offset $(IMG_PART_SEC) $(IMG) >/dev/null; \
	    echo "Created $(IMG) ($$((img_sz/1048576)) MB, ~5 MB free for saves)"; \
	fi
	@mt=$$(mktemp); \
	 printf 'drive x: file="%s" offset=$(IMG_PART_OFF)\n' "$(CURDIR)/$(IMG)" > $$mt; \
	 MTOOLSRC=$$mt mcopy -D o $(TARGET) x:PKMN.EXE; \
	 MTOOLSRC=$$mt mcopy -D o $(DPMI_HOST) x:$(DPMI_HOST); \
	 rm -f $$mt
	@echo "Packaged $(TARGET) -> $(IMG) (isolated C: for dos_port/run)"

clean-image:
	rm -f $(IMG)

# --- Rebuild-on-flag-change guard --------------------------------------------
# GNU make tracks each .o only against its .asm, NOT against the -D flags in
# NASMFLAGS. Switching build configs without `make clean` (e.g. a normal build
# then `make DEBUG_STATUS=1`, or `dos_port/run DEBUG_*=1`) therefore silently
# reuses .o compiled with the OLD flags — an inconsistent EXE that boots the
# wrong path or crashes ("never trust the timestamps on objects"). Stamp the
# current NASMFLAGS into a file, rewritten only when it actually changes, and
# make every .o depend on it so any flag change forces a full rebuild.
NASMFLAGS_STAMP := .nasmflags.stamp
$(file >$(NASMFLAGS_STAMP).tmp,$(NASMFLAGS))
$(shell cmp -s $(NASMFLAGS_STAMP).tmp $(NASMFLAGS_STAMP) || cp $(NASMFLAGS_STAMP).tmp $(NASMFLAGS_STAMP); rm -f $(NASMFLAGS_STAMP).tmp)

%.o: %.asm $(NASMFLAGS_STAMP)
	$(NASM) $(NASMFLAGS) -o $@ $<

# Assemble-only check (no link): useful for syntax verification
check:
	@for src in $(ALL_SRCS); do \
	    echo "Checking: $$src"; \
	    $(NASM) $(NASMFLAGS) -o /dev/null $$src || exit 1; \
	done
	@echo "All files assembled successfully."

clean:
	rm -f $(ALL_OBJS) $(TARGET) $(NASMFLAGS_STAMP)
