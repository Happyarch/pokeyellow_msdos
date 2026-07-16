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
# djgpp objdump: extracts the EXE's COFF symbol table (incl. NASM local
# labels) for pkmn.sym — the debugger/MCP symbol source of truth.
OBJDUMP := i586-pc-msdosdjgpp-objdump

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

# Debug-only ownership/lifecycle contracts. Assertions trap with INT3 and are
# absent from production objects. make DEBUG_ASSERTIONS=1
ifdef DEBUG_ASSERTIONS
DEBUG_ASSERT_PROJECTION := 1
DEBUG_ASSERT_SCRATCH := 1
DEBUG_ASSERT_LIFECYCLE := 1
DEBUG_ASSERT_REENTRANCY := 1
endif
ifdef DEBUG_ASSERT_PROJECTION
NASMFLAGS += -D DEBUG_ASSERT_PROJECTION
endif
ifdef DEBUG_ASSERT_SCRATCH
NASMFLAGS += -D DEBUG_ASSERT_SCRATCH
endif
ifdef DEBUG_ASSERT_LIFECYCLE
NASMFLAGS += -D DEBUG_ASSERT_LIFECYCLE
endif
ifdef DEBUG_ASSERT_REENTRANCY
NASMFLAGS += -D DEBUG_ASSERT_REENTRANCY
endif

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

# Seam-crossing trace: spawn beside a map connection, walk into it with the real
# movement primitives, sample state every frame to SEAMLOG.BIN (+ FRAME.BIN), exit.
# Wild encounters are suppressed via wStatusFlags4 BIT_NO_BATTLES, not by de-wiring.
# Decode with tools/read_seamlog.py. Defaults to the Viridian City <-> Route 22 seam.
#   make image DEBUG_SEAM=1 [DEBUG_SEAM_MAP=0x01 DEBUG_SEAM_X=3 DEBUG_SEAM_Y=16 DEBUG_SEAM_STEPS=8]
ifdef DEBUG_SEAM
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_SEAM -D SKIP_TITLE
endif
# Plain PLAYABLE build seeded at an arbitrary map/coord — no trace, no dump, A stays
# a game button. Reuses the DEBUG_SEAM spawn seeding (EnterMap + SeamReseatView) with
# DEBUG_SEAM_NOLOG to suppress frame.asm's per-frame SeamLogRecord hook.
#   make run DEBUG_START_MAP=0x0D DEBUG_START_X=3 DEBUG_START_Y=45   (Route 2, below
#   the Viridian Forest south-gate warp)
ifdef DEBUG_START_MAP
NASMFLAGS += -D DEBUG_SEAM -D DEBUG_SEAM_LIVE -D DEBUG_SEAM_NOLOG -D SKIP_TITLE
NASMFLAGS += -D DEBUG_SEAM_MAP=$(DEBUG_START_MAP)
ifdef DEBUG_START_X
NASMFLAGS += -D DEBUG_SEAM_X=$(DEBUG_START_X)
endif
ifdef DEBUG_START_Y
NASMFLAGS += -D DEBUG_SEAM_Y=$(DEBUG_START_Y)
endif
NEED_DEBUG_DUMP := 1
endif
ifdef DEBUG_SEAM_MAP
NASMFLAGS += -D DEBUG_SEAM_MAP=$(DEBUG_SEAM_MAP)
endif
ifdef DEBUG_SEAM_X
NASMFLAGS += -D DEBUG_SEAM_X=$(DEBUG_SEAM_X)
endif
ifdef DEBUG_SEAM_Y
NASMFLAGS += -D DEBUG_SEAM_Y=$(DEBUG_SEAM_Y)
endif
ifdef DEBUG_SEAM_STEPS
NASMFLAGS += -D DEBUG_SEAM_STEPS=$(DEBUG_SEAM_STEPS)
endif
ifdef DEBUG_SEAM_DIR
NASMFLAGS += -D DEBUG_SEAM_DIR=$(DEBUG_SEAM_DIR)
endif

# Interactive variant: seed the spawn, then hand control to the real OverworldLoop
# (collision LIVE, keyboard driven). Every frame is sampled into a 2048-frame ring;
# press A to write SEAMLOG.BIN + FRAME.BIN and quit. Implies DEBUG_SEAM.
#   make run DEBUG_SEAM_LIVE=1 DEBUG_SEAM_MAP=0x21 DEBUG_SEAM_X=36 DEBUG_SEAM_Y=8
ifdef DEBUG_SEAM_LIVE
DEBUG_SEAM := 1
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_SEAM -D DEBUG_SEAM_LIVE -D SKIP_TITLE
endif

# Suppress wild encounters via the game's own wStatusFlags4 BIT_NO_BATTLES gate,
# re-set on every EnterMap. Fully normal boot otherwise (title screen intact,
# no other DEBUG_* implied); trainer/forced battles unaffected.
# make DEBUG_NO_WILD=1
ifdef DEBUG_NO_WILD
NASMFLAGS += -D DEBUG_NO_WILD
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
    src/home/home_stubs.asm \
    src/home/serial_stubs.asm \
    src/home/fill_memory.asm \
    src/home/copy_data.asm \
    src/home/bankswitch.asm \
    src/home/text_script.asm \
    src/home/textbox.asm \
    src/home/yes_no.asm \
    src/home/list_menu.asm \
    src/home/start_menu.asm \
    src/home/item.asm \
    src/home/count_set_bits.asm \
    src/home/reset_player_sprite.asm \
    src/home/map_text_pointer.asm \
    src/home/reload_tiles.asm \
    src/home/npc_movement.asm \
    src/home/vcopy.asm \
    src/home/give.asm \
    src/home/oam.asm

HAL_SRCS := \
    src/ppu/ppu.asm \
    src/input/joypad.asm \
    src/home/joypad_lowsens.asm

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
    src/home/init.asm \
    src/video/lcd_control.asm \
    src/video/frame.asm \
    src/video/bg_anim.asm \
    src/home/play_time.asm \
    src/home/sprites.asm \
    src/engine/gfx/sprite_oam.asm \
    src/engine/gfx/mon_icons.asm \
    src/engine/gfx/palettes.asm \
    src/home/load_font.asm \
    src/home/text.asm \
    src/home/print_num.asm \
    src/home/print_bcd.asm \
    src/home/window.asm \
    src/home/palettes.asm \
    src/home/cgb_palettes.asm \
    src/home/fade.asm \
    src/movie/title.asm \
    src/engine/movie/oak_speech/init_player_data.asm \
    src/engine/overworld/overworld.asm \
    src/engine/overworld/movement.asm \
    src/engine/overworld/map_sprites.asm \
    src/home/run_map_script.asm \
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
    src/engine/menus/oaks_pc_stubs.asm \
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
    src/engine/printer/printer_stubs.asm \
    src/engine/menus/link_menu.asm \
    src/engine/menus/link_cups.asm \
    src/home/reload_sprites.asm \
    src/home/simulate_joypad.asm \
    src/engine/overworld/overworld_stubs.asm \
    src/engine/overworld/player_animations.asm \
    src/engine/overworld/daycare_exp.asm \
    src/engine/overworld/is_player_just_outside_map.asm \
    src/engine/overworld/dungeon_warps.asm \
    src/engine/overworld/specific_script_flags.asm \
    src/engine/overworld/clear_variables.asm \
    src/home/wild_encounter_check.asm \
    src/data/wild_data.asm \
    src/engine/overworld/wild_mons.asm \
    src/engine/overworld/warp_check.asm \
    src/home/hidden_events.asm \
    src/data/hidden_events_data.asm \
    src/engine/overworld/hidden_object_stubs.asm \
    src/engine/menus/swap_items.asm \
    src/engine/link/cable_club.asm \
    src/engine/overworld/ledges.asm \
    src/home/pathfinding.asm \
    src/engine/overworld/npc_movement_2.asm \
    src/engine/overworld/auto_movement.asm \
    src/home/overworld_text.asm \
    src/engine/overworld/pikachu.asm \
    src/engine/events/pewter_guys.asm \
    src/engine/overworld/toggleable_objects.asm \
    src/engine/overworld/update_map.asm \
    src/engine/overworld/elevator.asm \
    src/engine/overworld/spinners.asm \
    src/engine/overworld/healing_machine.asm \
    src/engine/overworld/unused_load_toggleable_object_data.asm \
    src/home/player_gfx.asm \
    src/engine/overworld/player_state.asm \
    src/engine/overworld/field_move_messages.asm \
    src/engine/overworld/special_warps.asm \
    src/engine/battle/wild_encounters.asm \
    src/engine/events/black_out.asm \
    src/engine/events/heal_party.asm \
    src/engine/events/pick_up_item.asm \
    src/engine/events/give_pokemon_stubs.asm \
    src/data/pickup_text.asm \
    src/home/money.asm \
    src/engine/overworld/push_boulder.asm \
    src/engine/overworld/dust_smoke.asm \
    src/engine/overworld/cut.asm \
    src/engine/overworld/cut2.asm \
    src/engine/debug/debug_party.asm

# debug_party.asm is linked UNCONDITIONALLY, matching pret: main.asm:19 INCLUDEs
# engine/debug/debug_party.asm in every build, and PrepareNewGameDebug is a
# "dummy except in _DEBUG" ret that PrepareForSpecialWarp always calls
# (engine/overworld/special_warps.asm:13). It was previously appended by ~15
# separate DEBUG_* gates; that left PrepareNewGameDebug undefined in a normal
# build, which is what kept special_warps.asm check-only. The file assembles and
# resolves with no DEBUG defines (verified: zero unresolved externs), and its
# three globals are dead code unless a DEBUG_* harness calls them.

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
    src/engine/items/get_max_pp.asm \
    src/engine/pokemon/knows_hm_move.asm \
    src/engine/pikachu/pikachu_status.asm \
    src/engine/pokemon/evolution.asm \
    src/engine/pokemon/learn_move.asm

# Items layer (current_plan_items.md). Non-UI inventory/bag logic + item data.
ITEMS_SRCS := \
    src/data/item_data.asm \
    src/data/item_text.asm \
    src/engine/items/inventory.asm \
    src/engine/items/item_effects.asm \
    src/engine/items/itemfinder.asm \
    src/engine/items/town_map.asm \
    src/engine/items/tms.asm \
    src/engine/items/tmhm.asm \
    src/engine/items/item_use_stubs.asm \
    src/home/item_price.asm \
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
    src/engine/battle/move_category.asm
# wild_encounters.asm MOVED to GAME_SRCS (wild-live promotion): TryDoWildEncounter
# is the random-encounter roll NewBattle calls; its closure resolves now that
# player_state.asm (IsPlayerStandingOnDoorTileOrWarpTile) links and DisplayTextID
# has a documented ret-stub (src/home/home_stubs.asm).
# trainer_ai.asm + read_trainer_party.asm MOVED to FRONTEND_SRCS (battle-swarm-C): the
# class-based enemy-move AI (AIEnemyTrainerChooseMoves) and trainer-party loader now link
# live — their closures resolve (AIGetTypeEffectiveness/Moves/Divide/IsInArray/Random +
# TrainerDataPointers/SpecialTrainerMoves/AddPartyMon/AddBCDPredef). wild_data.asm +
# wild_mons.asm (LoadWildData/WildDataPointers) MOVED to GAME_SRCS (OW-A.5): they form a
# self-contained 2-file unit (data table + inline flat→WRAM loader, no battle deps) and now
# link live so LoadMapHeader can populate per-map wGrassMons/wWaterMons.
# WILD ENCOUNTERS ARE LIVE (2026-07-10): wild_encounters.asm is in GAME_SRCS, the
# WILD_ENCOUNTERS_LIVE gate is retired from overworld.asm + wild_encounter_check.asm,
# and the blackout tail (HandleBlackOut/StopMusic in overworld.asm, black_out.asm,
# heal_party.asm) is ported. See wild_encounter_check.asm's STATUS header.
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
endif
# Sign-text gate (fidelity plan Stage 1b — the streamed-text golden): spawn beside the
# Pallet Town sign facing it, run the real A-press dispatch
# (IsSpriteOrSignInFrontOfPlayer -> SignLoop -> DisplaySignText -> ShowTextStream),
# and dump FRAME.BIN + GBSTATE.BIN once the stream is printed and the box is waiting on
# its ▼ (the hook is inside npc_dialog_wait_impl, map_sprites.asm). It is the port half
# of the sign_pallet golden. make DEBUG_SIGNTEXT=1
ifdef DEBUG_SIGNTEXT
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_SIGNTEXT
NASMFLAGS += -D SKIP_TITLE
# Which sign to read. Defaults to the Pallet Town town sign (bg_event 7, 9), read from
# (Y=9, X=8) facing LEFT — the tile BELOW the sign is a flower ($03) the game will not
# let you stand on, so the golden cannot walk there and neither should the port.
# Override to drive any other map's sign headlessly, e.g. the Route 5 UNDERGROUND PATH
# sign (bg_event 17, 29), read from below:
#   make DEBUG_SIGNTEXT=1 SIGNTEXT_MAP=0x10 SIGNTEXT_Y=30 SIGNTEXT_X=17 \
#        SIGNTEXT_DIR=SPRITE_FACING_UP
SIGNTEXT_MAP ?= 0x00
SIGNTEXT_Y   ?= 9
SIGNTEXT_X   ?= 8
SIGNTEXT_DIR ?= SPRITE_FACING_LEFT
NASMFLAGS += -D SIGNTEXT_MAP=$(SIGNTEXT_MAP) -D SIGNTEXT_Y=$(SIGNTEXT_Y) \
             -D SIGNTEXT_X=$(SIGNTEXT_X) -D SIGNTEXT_DIR=$(SIGNTEXT_DIR)
# The Pallet Town sign's stream is "PALLET TOWN <line> Shades of your <cont> journey
# await!", and <cont> ($55) is a WAITING command (it scrolls, then blocks on A/B) —
# a headless run with no keyboard parks there forever. AUTOKEY answers it, exactly as
# it answers the message waits in DEBUG_ITEMTM / DEBUG_ITEMBALL.
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_APRESS
# AutoKeyDrive's own FRAME.BIN dump would exit the program at its default frame; the
# gate dumps itself (ShowTextStream's hook), so push it out of the way.
AUTOKEY_DUMP_FRAME ?= 999999
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
endif
# Oak intro state gate: seed Pallet's north-exit trigger, execute the Pallet
# state-machine/battle-seed boundary deterministically, and dump GBSTATE+FRAME.
ifdef DEBUG_OAK_INTRO
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_OAK_INTRO
NASMFLAGS += -D SKIP_TITLE
endif
# Party-seed gate: run the debug new-game seed (party + bag + Pokédex) at boot,
# dump party/bag WRAM to DUMP.BIN, exit. Verifies the pokemon/items engine runs
# inside the real binary. make DEBUG_PARTY=1
ifdef DEBUG_PARTY
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_PARTY
NASMFLAGS += -D SKIP_TITLE
endif
# Bag-menu gate: seed the bag, open the bag (ITEM) screen over the overworld,
# park in the real HandleMenuInput loop, and let AutoKeyDrive dump a pinned
# MORE-arrow blink phase. make DEBUG_BAGMENU=1 [BAGMENU_DUMP_FRAME=n]
ifdef DEBUG_BAGMENU
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_BAGMENU
NASMFLAGS += -D SKIP_TITLE
BAGMENU_DUMP_FRAME ?= 45
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_QUIET -D AUTOKEY_DUMP_FRAME=$(BAGMENU_DUMP_FRAME)
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
endif
# Item-USE gate (items-plan Stage 5): seeded party with mon 1 knocked to 1 HP, and
# a scripted joypad (AUTOKEY_ITEMUSE) that drives START -> ITEM -> POTION -> USE ->
# mon 1, then ANTIDOTE -> USE -> mon 1 (which must refuse). Headless; dumps
# FRAME.BIN at AUTOKEY_DUMP_FRAME (380 heal message / 620 refusal / 700 bag list).
# make DEBUG_ITEMUSE=1 AUTOKEY_DUMP_FRAME=380
# Ball-throw gate (items-plan Stage 6): seed a wild battle (the DEBUG_BATTLE path),
# throw ITEMBALL_ID (default MASTER_BALL) from bag slot ITEMBALL_SLOT, dump the
# capture WRAM to DUMP.BIN and exit. Headless; AUTOKEY answers the <PROMPT> waits in
# the caught/dex messages. make DEBUG_ITEMBALL=1 [ITEMBALL_ID=0x04 ITEMBALL_SLOT=n]
ifdef DEBUG_ITEMBALL
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_ITEMBALL -D DEBUG_BATTLE -D SKIP_TITLE
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_APRESS -D DEBUG_SEED_PARTY
ifdef ITEMBALL_ID
NASMFLAGS += -D ITEMBALL_ID=$(ITEMBALL_ID)
endif
ifdef ITEMBALL_SLOT
NASMFLAGS += -D ITEMBALL_SLOT=$(ITEMBALL_SLOT)
endif
# ITEMBALL_ATTACH_DELAY=1 waits ~4s before the throw, so a debugger can attach.
ifdef ITEMBALL_ATTACH_DELAY
NASMFLAGS += -D ITEMBALL_ATTACH_DELAY
endif
# AutoKeyDrive's own FRAME.BIN dump exits the program, and the ball capture runs long, so
# the dump frame must stay out of its way: DEFAULT 999999 (measured — see below).
# M-120: this was a hardcoded `-D AUTOKEY_DUMP_FRAME=160` that beat the `?=`, so an
# AUTOKEY_DUMP_FRAME passed on the command line was silently ignored. Overridable now.
AUTOKEY_DUMP_FRAME ?= 999999
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
endif
# Items-plan Stage 7 gate: teach the TM/HM in ITEMTM_ID (default TM06 TOXIC) to party
# slot ITEMTM_MON, headless, capturing the result to DUMP.BIN. AUTOKEY answers the
# yes/no box, the party menu and the messages.
# make DEBUG_ITEMTM=1 [ITEMTM_ID=0xC4 ITEMTM_MON=1]
ifdef DEBUG_ITEMSTONE
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_ITEMSTONE -D DEBUG_SEED_PARTY -D SKIP_TITLE
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_APRESS
ifdef ITEMSTONE_ID
NASMFLAGS += -D ITEMSTONE_ID=$(ITEMSTONE_ID)
endif
ifdef ITEMSTONE_INBATTLE
NASMFLAGS += -D ITEMSTONE_INBATTLE
endif
# ITEMSTONE_CAVERN: seed wCurMapTileset = CAVERN, so ItemUseEscapeRope's
# EscapeRopeTilesets guard passes (the harness boots into Pallet Town, whose
# OVERWORLD tileset is not on that list). Omit it to exercise the refusal path.
ifdef ITEMSTONE_CAVERN
NASMFLAGS += -D ITEMSTONE_CAVERN
endif
ifdef ITEMSTONE_SPECIES
NASMFLAGS += -D ITEMSTONE_SPECIES=$(ITEMSTONE_SPECIES)
endif
# AutoKeyDrive's own FRAME.BIN dump EXITS the program, so it must stay out of the way of
# this gate's DebugDumpMemory capture: DEFAULT 999999 (measured — at 160 this gate produced
# no DUMP.BIN at all). M-120: was a hardcoded `=160` that beat the `?=`, so an
# AUTOKEY_DUMP_FRAME passed on the command line was silently ignored. Overridable now.
AUTOKEY_DUMP_FRAME ?= 999999
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
endif

ifdef DEBUG_ITEMTM
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_ITEMTM -D DEBUG_SEED_PARTY -D SKIP_TITLE
ifdef ITEMTM_BISECT
NASMFLAGS += -D ITEMTM_BISECT
endif
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_APRESS
ifdef ITEMTM_ID
NASMFLAGS += -D ITEMTM_ID=$(ITEMTM_ID)
endif
ifdef ITEMTM_MON
NASMFLAGS += -D ITEMTM_MON=$(ITEMTM_MON)
endif
# AutoKeyDrive's own FRAME.BIN dump EXITS the program, so it must stay out of the way of
# this gate's DebugDumpMemory capture: DEFAULT 999999 (measured — at 160 this gate produced
# no DUMP.BIN at all). M-120: was a hardcoded `=160` that beat the `?=`, so an
# AUTOKEY_DUMP_FRAME passed on the command line was silently ignored. Overridable now.
AUTOKEY_DUMP_FRAME ?= 999999
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
endif
ifdef DEBUG_ITEMUSE
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_ITEMUSE -D DEBUG_SEED_PARTY -D SKIP_TITLE
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_ITEMUSE
# (This used to read `-D AUTOKEY_DUMP_FRAME=160` — a hardcode, so the documented
# "AUTOKEY_DUMP_FRAME=380 heal message / 620 refusal / 700 bag list" never worked:
# every DEBUG_ITEMUSE run photographed frame 160 whatever you asked for. Menu-
# fidelity row 24 needed the bag-list frame to see the ▼ blink; finding M-120.)
ifdef AUTOKEY_DUMP_FRAME
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
endif
endif
# Plain playable build with a seeded party — NO frame dump, NO SKIP_TITLE. Boots
# the full path (title -> main menu -> NEW GAME -> overworld with a seeded party)
# so you can reach the stats screen the real way (START -> POKéMON -> mon -> STATS).
# make DEBUG_SEED_PARTY=1 (then dos_port/run).
ifdef DEBUG_SEED_PARTY
NASMFLAGS += -D DEBUG_SEED_PARTY
endif
# Scripted-joypad harness: seeded party + SKIP_TITLE + AutoKeyDrive replaying a
# button sequence (frame.asm), so a keyboard-only live path (overworld -> START ->
# submenu) runs headless. make DEBUG_AUTOKEY=1
ifdef DEBUG_AUTOKEY
ifdef AUTOKEY_SEAM
NASMFLAGS += -D AUTOKEY_SEAM
endif
ifdef AUTOKEY_JOG_RIGHT
NASMFLAGS += -D AUTOKEY_JOG_RIGHT
endif
ifdef AUTOKEY_TALK
NASMFLAGS += -D AUTOKEY_TALK
endif
ifdef AUTOKEY_MENU_FIRST
NASMFLAGS += -D AUTOKEY_MENU_FIRST
endif
ifdef AUTOKEY_PAD
NASMFLAGS += -D AUTOKEY_PAD=$(AUTOKEY_PAD)
endif
ifdef AUTOKEY_TITLE
NASMFLAGS += -D AUTOKEY_TITLE
endif
ifdef AUTOKEY_DOWNS
NASMFLAGS += -D AUTOKEY_DOWNS=$(AUTOKEY_DOWNS)
endif
ifdef AUTOKEY_DUMP_FRAME
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=160
endif
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_AUTOKEY
# AUTOKEY_NO_PARTY=1 skips the party seed so the autokey run matches a plain
# DEBUG_START_MAP build (which seeds no party) byte-for-byte on game state.
ifndef AUTOKEY_NO_PARTY
NASMFLAGS += -D DEBUG_SEED_PARTY
endif
ifndef AUTOKEY_TITLE
NASMFLAGS += -D SKIP_TITLE
endif
endif
# Party-menu gate: seed the party, open the POKéMON screen over the overworld,
# render one frame, dump FRAME.BIN, exit. make DEBUG_PARTYMENU=1
ifdef DEBUG_PARTYMENU
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_PARTYMENU
NASMFLAGS += -D SKIP_TITLE
endif
# Text-box gate (menus S2): boot to overworld, switch to the flat canvas, draw
# the DisplayTextBoxID box with the given wTextBoxID, dump FRAME.BIN, exit.
# make DEBUG_TEXTBOXID=<id>  (id = hex/dec NASM literal, e.g. 0x01, 0x13)
# Text-engine oracle (docs/current_plan_text_engine.md Stage 0): run ONE probe
# stream through the real PrintText in the overworld dialog window, dump FRAME.BIN,
# exit. One case per TX_* command — no golden covers streamed text, so this is the
# only oracle the text engine has.
#   1 plain+<LINE>  2 <PARA>  3 TX_RAM  4 TX_NUM  5 TX_BCD  6 TX_FAR  7 TX_DOTS
# make DEBUG_TEXT=<n>       (AUTOKEY_APRESS answers the <PARA> page break)
ifdef DEBUG_TEXT
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_TEXT=$(DEBUG_TEXT) -D SKIP_TITLE
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_APRESS
AUTOKEY_DUMP_FRAME ?= 999999
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=160
endif

ifdef DEBUG_TEXTBOXID
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_TEXTBOXID=$(DEBUG_TEXTBOXID)
NASMFLAGS += -D SKIP_TITLE
endif
# List-menu gate (menus S3): boot to overworld, seed party+bag, drive the generic
# DisplayListMenuID driver input-free (Old-Man auto-select), dump FRAME.BIN, exit.
# make DEBUG_LISTMENU=<mode>  (0=PC mon list, 2=priced bag, 3=item bag)
ifdef DEBUG_LISTMENU
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_LISTMENU=$(DEBUG_LISTMENU)
NASMFLAGS += -D SKIP_TITLE
# DEBUG_LISTMENU_QTY=1 additionally stages DisplayChooseQuantityMenu on top of the
# list (the ×NN selector; with DEBUG_LISTMENU=2 this is the ONLY way to observe the
# priced quantity+price row — the Pokémart caller is still a stub). The routine
# never returns, so drive the dump from AutoKeyDrive's frame timer with a script
# that presses nothing.
ifdef DEBUG_LISTMENU_QTY
NASMFLAGS += -D DEBUG_LISTMENU_QTY -D DEBUG_AUTOKEY -D AUTOKEY_QUIET
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=160
endif
endif
# Two-option (YES/NO) gate — menu-fidelity row 5. The box has no golden and no other
# harness; it parks in HandleMenuInput, so the dump is driven by AutoKeyDrive's frame
# timer with a no-press script. make DEBUG_YESNO=1 (YES/NO) or =2 (PokeCenter HEAL/CANCEL)
ifdef DEBUG_YESNO
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_YESNO=$(DEBUG_YESNO) -D SKIP_TITLE
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_QUIET -D AUTOKEY_DUMP_FRAME=60
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
# Oak's-PC gate (menu-fidelity row 17 part 3): boot to overworld, call OpenOaksPC.
# It PrintTexts AccessedOaksPCText and blocks in the stream's page-break prompt;
# with no presses scripted, AutoKeyDrive photographs the open "Accessed PROF. /
# OAK's PC." dialog and exits. make SKIP_TITLE=1 DEBUG_OAKSPC=1
ifdef DEBUG_OAKSPC
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_OAKSPC
NASMFLAGS += -D SKIP_TITLE
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_QUIET -D AUTOKEY_DUMP_FRAME=90
endif
# Generic-PC gate (menu-fidelity row 17): boot to overworld, call ActivatePC. It plays
# SFX_TURN_ON_PC and PrintTexts TurnedOnPC1Text, then blocks in the stream's `prompt`
# wait; with no presses scripted, AutoKeyDrive photographs the open dialog and exits.
# make SKIP_TITLE=1 DEBUG_PC=1
ifdef DEBUG_PC
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_PC
NASMFLAGS += -D SKIP_TITLE
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_QUIET -D AUTOKEY_DUMP_FRAME=90
endif
# League-PC gate (menu-fidelity row 17 part 4): boot to overworld, call PKMNLeaguePC.
# It PrintTexts AccessedHoFPCText and blocks in the stream's page-break prompt; with
# no presses scripted, AutoKeyDrive photographs the open "Accessed #MON / LEAGUE's
# site." dialog and exits. make SKIP_TITLE=1 DEBUG_LEAGUEPC=1
ifdef DEBUG_LEAGUEPC
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_LEAGUEPC
NASMFLAGS += -D SKIP_TITLE
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_QUIET -D AUTOKEY_DUMP_FRAME=90
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
endif
# Main-menu gate (menus S7 package E): boot to overworld, seed a save (party +
# name/badges/dex/time + DsvWriteSave), draw the CONTINUE/NEW GAME box + info
# panel, dump FRAME.BIN, exit. make SKIP_TITLE=1 DEBUG_MAINMENU=1
ifdef DEBUG_MAINMENU
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_MAINMENU
NASMFLAGS += -D SKIP_TITLE
endif
# Save gate (menus S7 package H): boot to overworld, seed party+bag+badges, run
# SaveGameData through the confirm (auto-YES), dump the "saved!" FRAME.BIN, exit.
# DEBUG_SAVE_ROUNDTRIP dumps a DsvWriteSave->DsvFileExists marker instead.
# make SKIP_TITLE=1 DEBUG_SAVE=1
ifdef DEBUG_SAVE
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_SAVE
NASMFLAGS += -D DEBUG_AUTOKEY
NASMFLAGS += -D AUTOKEY_QUIET
# 200: at 90 the dialog is caught mid-typewriter; by 200 the question is complete
# with the TWO_OPTION_MENU YES/NO box above it (row 19 part 1's photographed frame).
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=200
NASMFLAGS += -D SKIP_TITLE
endif
ifdef DEBUG_SAVE_ROUNDTRIP
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_SAVE
NASMFLAGS += -D DEBUG_SAVE_ROUNDTRIP
NASMFLAGS += -D SKIP_TITLE
endif
# Change-box gate (menu-fidelity row 19 part 2): boot to overworld, run ChangeBox
# (the two-page "When you change a #MON BOX" text -> YES -> the box list +
# "BOX No." indicator), auto-press YES, dump FRAME.BIN, exit. Reuses the
# DEBUG_SAVE harness hook, so it defines DEBUG_SAVE too (save.asm branches on
# DEBUG_CHANGEBOX first).  make SKIP_TITLE=1 DEBUG_CHANGEBOX=1
ifdef DEBUG_CHANGEBOX
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_SAVE
NASMFLAGS += -D DEBUG_CHANGEBOX
NASMFLAGS += -D DEBUG_AUTOKEY
# AUTOKEY_TALK is the pulse-A script (A at 120/180/240/...): the press at 120
# resolves ChooseABoxText's <PROMPT>, and the menu is then up until the press at
# 180 accepts it — so 160 is the frame that photographs the box list + cursor.
NASMFLAGS += -D AUTOKEY_TALK
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=160
NASMFLAGS += -D SKIP_TITLE
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
# PDEX_AREA=1 makes the SAME G1 harness render the side menu's AREA option instead
# of the CONTENTS list: it calls LoadTownMap_Nest exactly as .choseArea now does.
# That path blocks in WaitForTextScrollButtonPress, so it needs the autokey driver
# to photograph the screen (AutoKeyDrive dumps at AUTOKEY_DUMP_FRAME and exits).
# make SKIP_TITLE=1 DEBUG_G1=1 PDEX_AREA=1
# AUTOKEY_QUIET: never press anything. The nest screen parks in its own key-wait
# (WaitForTextScrollButtonPress), so the default script's A-press would dismiss it
# via ExitTownMap and the frame-200 photo would catch the overworld behind it.
ifdef PDEX_AREA
NASMFLAGS += -D PDEX_AREA -D DEBUG_AUTOKEY -D AUTOKEY_QUIET
endif
endif
ifdef DEBUG_G2
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_G2
# The entry page prints its flavor atomically (the dex leaves the letter delay
# off) and parks at the <PAGE> ▼ — the only state the real game pauses in, and
# what the pokedex_entry golden captures. AUTOKEY_QUIET: never press anything
# (an A would advance to flavor page 2); AutoKeyDrive photographs the parked
# page at AUTOKEY_DUMP_FRAME and exits (PDEX_AREA / DEBUG_I1 pattern).
# `?=` + passthrough, not a hardcode — the M-120 lesson.
# 215, not 200: the parked ▼ blinks 30 ON / 8 OFF (gb_memmap.inc ARROW_*_FRAMES)
# and the golden dumps with it ON (just drawn); frame 200 landed in an OFF
# window (measured: the one-cell (16,18) first diff), 215 sits mid-ON.
AUTOKEY_DUMP_FRAME ?= 215
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_QUIET -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
NASMFLAGS += -D SKIP_TITLE
endif
# Link-menu gates (menus S8 package I). I1: run Func_f531b, the Colosseum cup-select
# screen (serial stubbed to the no-partner collapse). I1_LINK: run LinkMenu instead.
# I2: run the cup validators (a pass + a gated fail) and record result codes.
#
# Both menus park in HandleMenuInput waiting for A/B, which a headless run cannot
# press — so I1/I1_LINK build with AUTOKEY_QUIET (no presses, ever) and AutoKeyDrive
# writes FRAME.BIN from the joypad ISR at AUTOKEY_DUMP_FRAME (90 — late enough for
# the boxes, labels, rules panel and ▶ cursor) and exits. The harness calls the real
# routines; it draws nothing itself (menu-fidelity row 20 part 2).
# make DEBUG_I1=1  /  DEBUG_I1_LINK=1  /  DEBUG_I2=1
ifdef DEBUG_I1_LINK
DEBUG_I1 := 1
NASMFLAGS += -D DEBUG_I1_LINK
endif
ifdef DEBUG_I1
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_I1
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_QUIET -D AUTOKEY_DUMP_FRAME=90
NASMFLAGS += -D SKIP_TITLE
endif
ifdef DEBUG_I2
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_I2
NASMFLAGS += -D SKIP_TITLE
endif
# Battle golden gate (fidelity plan Stage 2): the REAL loaders (InitBattle →
# LoadEnemyMonData → LoadBattleMonFromParty) + the convergence-spec DV overwrite
# replace DEBUG_BATTLE's synthetic seed. Combine with DEBUG_BATTLE_INTRO /
# DEBUG_BATTLE_MENU / DEBUG_MOVEMENU to pick the dump point (the goldens are
# battle_intro / battle_menu / move_selection).
ifdef DEBUG_BATTLE_GOLDEN
DEBUG_BATTLE := 1
NASMFLAGS += -D DEBUG_BATTLE_GOLDEN
endif
# Battle-menu photograph (golden battle_menu): the real DisplayBattleMenu draws
# HUDs + boxes + the ▶ cursor and parks in HandleMenuInput; AUTOKEY_QUIET
# photographs it at AUTOKEY_DUMP_FRAME.
ifdef DEBUG_BATTLE_MENU
DEBUG_BATTLE := 1
NASMFLAGS += -D DEBUG_BATTLE_MENU
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_QUIET
AUTOKEY_DUMP_FRAME ?= 30
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
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
# Move-selection menu (menu-fidelity row 22): seed the DEBUG_BATTLE party, then run
# pret's MoveSelectionMenu — the move list, the cursor and the TYPE/PP box (PrintMenuItem).
# The menu blocks on input, so AUTOKEY_QUIET drives DelayFrame and photographs the screen
# at AUTOKEY_DUMP_FRAME. No golden covers the FIGHT sub-menu; this is its render check.
# make DEBUG_MOVEMENU=1 [DEBUG_MOVEMENU_TYPE=1|2 for the Mimic / relearn menus]
ifdef DEBUG_MOVEMENU
DEBUG_BATTLE := 1
NASMFLAGS += -D DEBUG_MOVEMENU
ifdef DEBUG_MOVEMENU_TYPE
NASMFLAGS += -D DEBUG_MOVEMENU_TYPE=$(DEBUG_MOVEMENU_TYPE)
endif
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_QUIET
AUTOKEY_DUMP_FRAME ?= 30
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
endif
# Battle gate (Wave 2): seed party + a wild enemy, enter battle (InitBattle),
# render one frame, dump FRAME.BIN, exit. make DEBUG_BATTLE=1
ifdef DEBUG_BATTLE
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_BATTLE
NASMFLAGS += -D SKIP_TITLE
endif
# Level-up move-learn gate (current_plan_pokemon_behavior Stage 3): force
# STARTER_PIKACHU (party slot 3) 5->6, call LearnMoveFromLevelUp directly (no
# battle/input needed), render one frame, dump FRAME.BIN, exit. make DEBUG_LEARNMOVE=1
ifdef DEBUG_LEARNMOVE
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_LEARNMOVE
NASMFLAGS += -D SKIP_TITLE
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
endif
ifdef NEED_DEBUG_DUMP
GAME_SRCS += src/debug/debug_dump.asm
endif

# Compositor profiler (docs/plans/compositor_perf.md Stage 0): latch PIT
# channel 0 around each DelayFrame stage, accumulate per-stage totals + worst
# frame, write PERF.BIN. Decode with tools/read_perf.py.
#   make DEBUG_PERF=1 SKIP_TITLE=1                 (play; Esc dumps PERF.BIN)
#   make DEBUG_PERF=1 DEBUG_PERF_FRAMES=600 ...    (auto-dump + exit after N frames)
# Does NOT imply SKIP_TITLE — the profiler is meant to run in any real scenario.
ifdef DEBUG_PERF
GAME_SRCS += src/debug/perf.asm
NASMFLAGS += -D DEBUG_PERF
ifdef DEBUG_PERF_FRAMES
NASMFLAGS += -D DEBUG_PERF_FRAMES=$(DEBUG_PERF_FRAMES)
endif
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
    src/engine/battle/print_type.asm \
    src/engine/battle/select_enemy_move.asm \
    src/engine/battle/load_enemy_moves.asm \
    src/engine/battle/pokeballs.asm \
    src/data/trainer_pics.asm \
    src/data/mon_pics.asm \
    src/engine/battle/battle_stubs.asm \
    src/home/uncompress.asm \
    src/home/pics.asm \
    src/engine/battle/experience.asm \
    src/engine/battle/battle_exp_stubs.asm \
    src/engine/battle/trainer_battle.asm \
    src/engine/battle/trainer_ai.asm \
    src/engine/battle/read_trainer_party.asm \
    src/engine/battle/faint_leaves.asm \
    src/engine/battle/faint_switch.asm \
    src/engine/battle/faint_enemy.asm \
    src/engine/battle/load_enemy_from_party.asm \
    src/engine/battle/load_enemy_mon_data.asm \
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
# engine, DisplayTextBoxID, _AlreadyKnowsText).
# NOTE: an older comment here said town_map was "intentionally kept dangling (not
# in the main loop)". STALE: town_map.asm is in ITEMS_SRCS, which is part of
# LINK_SRCS, so it has been linked all along — and LoadTownMap_Nest was a complete,
# reachable body that simply nobody called. The POKéDEX AREA option now calls it
# (menu-fidelity row 16 / M-64).
# swap_items.asm MOVED to GAME_SRCS (menus S3): SELECT-swap links live with
# the promoted list_menu.asm driver.
ITEMS_CHECK_SRCS := \
    src/engine/items/subtract_paid_money.asm \
    src/engine/items/super_rod.asm

# Home routines that assemble-validate but aren't linked yet. count_set_bits
# emits an undefined external for wNumSetBits (no memmap alias / no caller yet),
# so linking it would break the build — keep it check-only until a caller lands
# (then add wNumSetBits to gb_memmap.inc and move it to HOME_SRCS).
# yes_no.asm MOVED to HOME_SRCS (menus S2): DisplayTextBoxID_'s TWO_OPTION_MENU
# dispatch needs DisplayTwoOptionMenu live; all its externs already resolved.
# list_menu.asm MOVED to HOME_SRCS (menus S3): all former link-blockers resolve
# to linked code (PrintLevel added to home/pokemon.asm); links with swap_items.
# oam.asm MOVED to HOME_SRCS (overworld-events Stage 4): WriteOAMBlock is needed by
# cut.asm, promoted below. Its own closure was already satisfied.
# push_boulder/dust_smoke/cut/cut2 MOVED to GAME_SRCS (overworld-events Stage 4,
# boulder bullet): the boulder push + its dust animation are live. What unblocked
# them: AdjustOAMBlock{X,Y}Pos(2) ported into their pret home
# src/engine/battle/animations.asm, IsSpriteInFrontOfPlayer ported into
# overworld.asm, DiscardButtonPresses extracted into src/input/joypad.asm, and
# WriteOAMBlock + SaveScreenTilesToBuffer2/LoadScreenTilesFromBuffer2 now linked
# (the latter pair via the vcopy.asm promotion in Stage 3 — the old note claiming
# they blocked cut.asm was stale).
HOME_CHECK_SRCS := \
    src/home/predef_text.asm \
    src/engine/overworld/trainer_engine.asm
# B1 (2026-07-13) promoted player_animations.asm to GAME_SRCS: its link closure was
# already fully satisfied (nm -u resolves to translated/relocated symbols only), so
# the file was being assembled and thrown away while the overworld_stubs.asm
# EnterMapAnim ret-stub SHADOWED its real body. Retiring that stub gives the port the
# real fly/dungeon arrival animation, plus _LeaveMapAnim (needed by
# HandleFlyWarpOrDungeonWarp), DoFlyAnimation, and FishingAnim.
# OW-7.2 (2026-07-10) promoted 13 overworld files to GAME_SRCS (ledges,
# pathfinding, npc_movement_2, auto_movement, overworld_text, pikachu,
# pewter_guys, toggleable_objects, update_map, elevator, spinners,
# healing_machine, unused_load_toggleable_object_data) — closures verified by
# nm diff vs the linked build.
#
# Wild-live promotion (2026-07-10) promoted 3 more to GAME_SRCS:
# - player_gfx.asm: RedBikeSprite/SeelSprite/SurfingPikachuSprite are now
#   generated Tier-1 data (assets/*_sprite.inc, gen_all_assets.py) and included
#   by the file itself; player_sprite is exported from overworld.asm. Its
#   faithful LoadPlayerSpriteGraphics REPLACED the walking-only scaffold that
#   used to live in overworld.asm (which is now retired, not shadowed).
# - player_state.asm (OW-1.8): unblocked by player_gfx.asm's ForceBikeOrSurf.
#   NOTE: the old note here claimed its H_WARP_DESTINATION_MAP=0xFF8B aliasing
#   hPreviousTileset was a bug needing a distinct HRAM byte. That was WRONG:
#   pret unions hBaseTileID/hDexWeight/hWarpDestinationMap/hOAMTile/hROMBankTemp/
#   hPreviousTileset/hRLEByteValue at one byte (ram/hram.asm:8-19), and the
#   golden pokeyellow.sym confirms all of them resolve to $FF8B. The alias is
#   FAITHFUL; splitting it would have introduced a divergence.
# - special_warps.asm: PrepareNewGameDebug now has a %ifndef DEBUG_PARTY-guarded
#   ret-stub in special_warps.asm itself; LoadTilesetHeader is global. Its real
#   PrepareForSpecialWarp replaced the main_menu_stubs.asm ret-stub (deleted).
#
# Remaining check-only blockers (per-file):
# - cut.asm / cut2.asm / dust_smoke.asm: LINKED as of overworld-events Stage 4 —
#   all four former blockers are resolved (see the HOME_CHECK_SRCS note below).
#   NOTE cut.asm is linked for its OAM-animation primitives, which the boulder dust
#   shares; the Stage 4 CUT bullet still owns wiring UsedCut to the party-menu tail,
#   so UsedCut/AnimCut are linked but not yet reachable from the field-move menu.
# - field_move_messages.asm: LINKED as of menu-fidelity row 9 part 3. Its only
#   unresolved symbol was PlayCry (cry synth, still unported); that is now a
#   documented ret-stub in home_stubs.asm, which costs the STRENGTH cry and
#   nothing else. Linking it is what makes STRENGTH and SURF reachable from
#   the field-move menu.
# - player_animations.asm: EmotionBubble (trainer_engine), LoadAnimSpriteGfx.
#   (StopMusic is REAL now — ported into overworld.asm by the wild-live
#   promotion; player_sprite is exported from overworld.asm.)
# - trainer_engine.asm: GetTrainerName_/SaveTrainerName/_TrainerNameText/
#   JessieJamesPic unported; WriteOAMBlock (home/oam.asm). DisplayTextID is now
#   the linked home/text_script.asm dispatcher.
# - text_script.asm promoted to HOME_SRCS (overworld-events Stage 2): the real
#   DisplayTextID dispatcher links, uses the flat map text table for ordinary
#   map text, and owns the generated text_script_text.inc far streams. The
#   remaining mart / Pokémon Center / vending / cable club / Pikachu / Safari /
#   prize-service bodies are structured subsystem stubs until their service
#   bullets land.
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

.PHONY: all clean clean-image image check assets regen goldens goldens-verify goldencheck fidelity fidelity-full
.DEFAULT_GOAL := all

# Regenerate the committed mGBA goldens (tests/goldens/) from the
# sha1-verified ROM in the pinned pret worktree. See the fidelity plan +
# tools/mgba_harness/make_goldens.sh for prerequisites (build_mgba.sh,
# ../pokeyellow_msdos-pret-golden).
goldens:
	tools/mgba_harness/make_goldens.sh

# Regenerate every committed mGBA golden into a scratch directory and compare it
# against tests/goldens/. This is the drift check: it proves the checked-in
# goldens are exactly reproducible from the pinned pristine pret worktree.
goldens-verify:
	@set -eu; \
	repo_root=$$(cd .. && pwd); \
	pret_dir="$${PRET_GOLDEN_DIR:-$$(dirname "$$repo_root")/pokeyellow_msdos-pret-golden}"; \
	rom="$$pret_dir/pokeyellow.gbc"; \
	sym="$$pret_dir/pokeyellow.sym"; \
	runner="$$repo_root/dos_port/tools/mgba_build/mgba-lua-runner"; \
	out_dir=$$(mktemp -d "$${TMPDIR:-/tmp}/goldens-verify.XXXXXX"); \
	trap 'rm -rf "$$out_dir"' EXIT; \
	for f in "$$rom" "$$sym" "$$runner"; do \
		if [ ! -e "$$f" ]; then echo "goldens-verify: missing $$f" >&2; exit 2; fi; \
	done; \
	if [ ! -x "$$runner" ]; then echo "goldens-verify: $$runner is not executable" >&2; exit 2; fi; \
	want_sha1=$$(awk '/pokeyellow.gbc/ { print $$1 }' "$$repo_root/roms.sha1"); \
	have_sha1=$$(sha1sum "$$rom" | awk '{ print $$1 }'); \
	if [ "$$want_sha1" != "$$have_sha1" ]; then \
		echo "goldens-verify: $$rom sha1 $$have_sha1 != roms.sha1 $$want_sha1" >&2; exit 2; \
	fi; \
	status=0; \
	cd "$$repo_root"; \
	for scenario in dos_port/tools/mgba_harness/scenarios/*.lua; do \
		name=$$(basename "$$scenario" .lua); \
		echo "=== goldens-verify: $$name"; \
		log="$$out_dir/$$name.log"; \
		if GOLDEN_DIR="$$out_dir" PKMN_SYM="$$sym" "$$runner" -s "$$scenario" "$$rom" >"$$log" 2>&1; then \
			sed '/MBC5 unknown address/d' "$$log"; \
		else \
			sed '/MBC5 unknown address/d' "$$log"; \
			echo "goldens-verify: scenario $$name failed" >&2; status=1; continue; \
		fi; \
		for ext in bin json; do \
			committed="dos_port/tests/goldens/$$name.$$ext"; \
			regenerated="$$out_dir/$$name.$$ext"; \
			if [ ! -f "$$committed" ]; then echo "goldens-verify: missing committed $$name.$$ext" >&2; status=1; continue; fi; \
			if [ ! -f "$$regenerated" ]; then echo "goldens-verify: scenario $$name did not write $$name.$$ext" >&2; status=1; continue; fi; \
			if ! cmp -s "$$committed" "$$regenerated"; then \
				echo "goldens-verify: drift in $$name.$$ext" >&2; \
				if [ "$$ext" = json ]; then diff -u "$$committed" "$$regenerated" || true; \
				else cmp -l "$$committed" "$$regenerated" | sed -n '1,16p' || true; fi; \
				status=1; \
			fi; \
		done; \
	done; \
	exit $$status

# Diff the port's GB state against an mGBA golden (fidelity plan Stage 1.4):
# build the scenario's DEBUG_* image, run it headless, extract GBSTATE.BIN,
# cell/slot-diff vs tests/goldens/<scenario>.  make goldencheck SCENARIO=status_p1
goldencheck:
	tools/goldencheck.sh $(SCENARIO)

# Fast pre-commit tier: one representative from each fidelity surface, excluding
# slower/redundant exhaustive tails. Measured 2026-07-15 in this worktree:
# core ~2m50s, full ~4m45s.
FIDELITY_SCENARIOS_CORE := $(shell python3 tools/gen_scenario_registry.py --names core)
FIDELITY_SCENARIOS_FULL := $(shell python3 tools/gen_scenario_registry.py --names full)
FIDELITY_SCENARIOS ?= $(FIDELITY_SCENARIOS_CORE)

fidelity:
	@fail=0; for s in $(FIDELITY_SCENARIOS_CORE); do \
		tools/goldencheck.sh $$s || fail=1; \
	done; exit $$fail

fidelity-full:
	@fail=0; for s in $(FIDELITY_SCENARIOS_FULL); do \
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

# NB: these had NO prerequisites, so once the .inc files existed the rule never fired
# again — editing the generator or the pret map data silently shipped stale headers
# (this hid the border-6 connection-clamp bug for a month). Keep the inputs listed.
assets/map_headers.inc assets/extra_includes.inc assets/map_dims.inc assets/rom_window.inc: \
    tools/gen_map_headers.py \
    ../constants/map_constants.asm \
    $(wildcard ../data/maps/headers/*.asm) \
    $(wildcard ../data/maps/objects/*.asm)
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

# Alternate player sprite sheets (bike / surfing) — pret gfx/sprites.asm labels
# RedBikeSprite / SeelSprite / SurfingPikachuSprite. Consumed by player_gfx.asm's
# LoadPlayerSpriteGraphics dispatch (wild-live promotion).
assets/red_bike_sprite.inc assets/seel_sprite.inc assets/surfing_pikachu_sprite.inc:
	python3 tools/gen_all_assets.py

src/home/player_gfx.o: \
    assets/red_bike_sprite.inc \
    assets/seel_sprite.inc \
    assets/surfing_pikachu_sprite.inc

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

# Hidden-event data (generated from data/events/hidden_events.asm).
assets/hidden_events.inc:
	python3 tools/gen_hidden_events.py

# HiddenItemCoords data (generated from data/events/hidden_item_coords.asm) —
# overworld-events Stage 3 bullet 2, consumed by the items plan's itemfinder.
assets/hidden_item_coords.inc:
	python3 tools/gen_hidden_item_coords.py

# PickUpItem message streams (generated from engine/events/pick_up_item.asm).
assets/pickup_text.inc: assets/item_text.inc assets/battle_text.inc
	python3 tools/gen_pickup_text.py

src/data/hidden_events_data.o: assets/hidden_events.inc assets/hidden_item_coords.inc
src/data/pickup_text.o: assets/pickup_text.inc

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
src/home/init.o src/home/window.o: assets/audio_constants.inc

# GB character map in the unicode_converter's format (single-char → byte), for
# the converter submodule + gb_text.py. Generated from constants/charmap.asm.
assets/gb_charmap.txt:
	python3 tools/gen_charmap.py

# START-menu item labels, encoded via the unicode_converter submodule (gb_text),
# plus the START-sub-menu FAR message streams (menu_text.inc), flattened out of
# pret's data/text/*.asm by gen_battle_text.collect_far — hence the extra deps.
assets/menu_strings.inc assets/menu_text.inc assets/trainer_card_strings.inc \
        assets/party_menu_strings.inc assets/home_pokemon_strings.inc \
        assets/options_strings.inc assets/naming_strings.inc \
        assets/pokedex_strings.inc: \
        assets/gb_charmap.txt tools/gen_menu_strings.py \
        tools/gb_text.py tools/gen_battle_text.py
	python3 tools/gen_menu_strings.py

# Status/summary-screen PlaceString labels (charmap-encoded via gb_text; two-tier rule).
assets/status_strings.inc: assets/gb_charmap.txt tools/gen_status_strings.py tools/gb_text.py
	python3 tools/gen_status_strings.py

# Text-box menu strings (pret data/text_boxes.asm) — charmap-encoded via gb_text;
# two-tier rule. <NEXT>/<PK>/<MN> are emitted as named raw bytes by the generator.
assets/textbox_strings.inc: assets/gb_charmap.txt tools/gen_textbox_strings.py tools/gb_text.py
	python3 tools/gen_textbox_strings.py

# List-menu strings (pret home/list_menu.asm: CANCEL / ×01 / the qty-price spacer).
assets/list_menu_strings.inc: assets/gb_charmap.txt tools/gen_list_menu_strings.py tools/gb_text.py
	python3 tools/gen_list_menu_strings.py

# Two-option (YES/NO) menu options — pret data/yes_no_menu_strings.asm.
assets/yes_no_strings.inc: assets/gb_charmap.txt tools/gen_yes_no_strings.py tools/gb_text.py
	python3 tools/gen_yes_no_strings.py

# Text-engine oracle probe streams (DEBUG_TEXT). See docs/current_plan_text_engine.md.
assets/text_oracle.inc: assets/gb_charmap.txt tools/gen_text_oracle.py tools/gb_text.py
	python3 tools/gen_text_oracle.py

assets/overworld_strings.inc assets/field_move_text.inc assets/cut_text.inc assets/player_anim_text.inc &: \
                            assets/gb_charmap.txt tools/gen_overworld_strings.py tools/gb_text.py \
                            tools/gen_battle_text.py ../data/text/text_1.asm ../data/text/text_8.asm ../data/text/text_9.asm \
                            ../constants/charmap.asm
	python3 tools/gen_overworld_strings.py

# Battle message command streams (pret data/text + engine/battle wrappers, text_far
# flattened). %included by the battle core engine. Generated from the read-only spec.
assets/battle_text.inc: ../data/text/text_2.asm ../engine/battle/core.asm \
                        ../constants/charmap.asm include/gb_memmap.inc tools/gen_battle_text.py
	python3 tools/gen_battle_text.py

RUNTIME_STRING_ASSETS := assets/battle_menu_runtime_strings.inc \
	assets/battle_core_runtime_strings.inc assets/effectiveness_runtime_strings.inc \
	assets/battle_intro_runtime_strings.inc assets/stat_mod_runtime_strings.inc \
	assets/item_runtime_strings.inc assets/status_ailment_runtime_strings.inc \
	assets/home_names_runtime_strings.inc assets/home_text_runtime_strings.inc \
	assets/pallet_runtime_strings.inc
$(RUNTIME_STRING_ASSETS) &: assets/gb_charmap.txt tools/gen_runtime_strings.py \
		tools/gen_battle_text.py ../constants/charmap.asm
	python3 tools/gen_runtime_strings.py
src/engine/battle/battle_menu.o: assets/battle_menu_runtime_strings.inc
src/engine/battle/core.o: assets/battle_core_runtime_strings.inc
src/engine/battle/display_effectiveness.o: assets/effectiveness_runtime_strings.inc
src/engine/battle/init_battle.o: assets/battle_intro_runtime_strings.inc
src/engine/battle/move_effect_helpers.o: assets/stat_mod_runtime_strings.inc
src/engine/items/item_effects.o: assets/item_runtime_strings.inc
src/engine/pokemon/status_ailments.o: assets/status_ailment_runtime_strings.inc
src/home/names.o: assets/home_names_runtime_strings.inc
src/home/text.o: assets/home_text_runtime_strings.inc
src/scripts/pallet_town.o: assets/pallet_runtime_strings.inc

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

# CGB palette source data + human-authored colorization deltas.  The .inc is
# Tier-1 generated data; no runtime consumer is linked until colorization R1.
REPAINT_2BPP := $(wildcard assets/colors/repaint/*.2bpp)
assets/colors/palettes.inc: tools/gen_palettes.py tools/gfx_core/palettes.py \
		tools/colors/schema.py assets/colors/palettes.json \
		$(REPAINT_2BPP) \
		../data/sgb/sgb_palettes.asm ../data/sgb/sgb_packets.asm \
		../data/pokemon/palettes.asm ../constants/palette_constants.asm
	python3 tools/gen_palettes.py

src/home/palettes.o: assets/colors/palettes.inc $(REPAINT_2BPP)

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

# Party-mon icon tile patterns + the ICON_* enum + MonPartyData, for the OAM icon
# path (engine/gfx/mon_icons.asm). Was previously generated by hand and committed;
# it is Tier-1 data, so it is rule-driven now.
assets/mon_icons.inc: ../gfx/sprites/monster.2bpp ../gfx/sprites/poke_ball.2bpp \
                      ../gfx/sprites/fossil.2bpp ../gfx/sprites/fairy.2bpp \
                      ../gfx/sprites/bird.2bpp ../gfx/sprites/seel.2bpp \
                      ../gfx/sprites/pikachu.2bpp ../gfx/icons/bug.2bpp \
                      ../gfx/icons/plant.2bpp ../gfx/icons/snake.2bpp \
                      ../gfx/icons/quadruped.2bpp ../gfx/trade/bubble.2bpp \
                      ../data/pokemon/menu_icons.asm ../constants/icon_constants.asm \
                      tools/gen_mon_icons_inc.py
	python3 tools/gen_mon_icons_inc.py

src/engine/gfx/mon_icons.o: assets/mon_icons.inc

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

src/engine/menus/trainer_card.o: assets/trainer_card_tiles.inc assets/trainer_card_strings.inc \
                                 assets/ui_layout_menus.inc

# Pokédex interface tiles (2bpp passthrough of gfx/pokedex/pokedex.2bpp + the
# plain pokéball tile from gfx/battle/balls.2bpp) for LoadPokedexTilePatterns.
assets/pokedex_tiles.inc: ../gfx/pokedex/pokedex.2bpp ../gfx/battle/balls.2bpp \
                          tools/gen_pokedex_tiles.py
	python3 tools/gen_pokedex_tiles.py

# Start menu checks EVENT_GOT_POKEDEX via events.inc → event_constants.inc;
# DrawStartMenu %includes the generated menu_strings.inc labels and the
# UI_START_MENU_* equates; start_sub_menus needs the UI_USE_TOSS_* equates.
src/home/start_menu.o: assets/event_constants.inc assets/audio_constants.inc
src/engine/menus/draw_start_menu.o: assets/event_constants.inc \
        assets/menu_strings.inc assets/ui_layout_menus.inc
src/engine/menus/start_sub_menus.o: assets/ui_layout_menus.inc assets/audio_constants.inc \
        assets/menu_text.inc
src/engine/menus/pc.o: assets/event_constants.inc assets/audio_constants.inc \
        assets/pc_text.inc
src/engine/menus/players_pc.o: assets/ui_layout_menus.inc assets/audio_constants.inc \
        assets/players_pc_text.inc
src/engine/menus/oaks_pc.o: assets/oaks_pc_text.inc
src/engine/menus/league_pc.o: assets/league_pc_text.inc
src/engine/menus/main_menu.o: assets/main_menu_text.inc
src/engine/menus/save.o: assets/save_text.inc assets/audio_constants.inc
src/engine/items/item_effects.o: assets/ui_layout_menus.inc
src/engine/menus/main_menu.o src/engine/menus/save.o: assets/ui_layout_menus.inc
src/engine/menus/naming_screen.o: assets/ui_layout_menus.inc assets/alphabets.inc \
        assets/naming_strings.inc assets/audio_constants.inc
src/engine/menus/pokedex.o: assets/ui_layout_menus.inc assets/pokedex_tiles.inc \
        assets/pokedex_strings.inc assets/dex_entries.inc
src/engine/menus/link_menu.o: assets/ui_layout_menus.inc assets/link_text.inc
src/engine/menus/link_cups.o: assets/dex_entries.inc

# Status screen %includes the generated status_strings.inc label block.
src/engine/pokemon/status_screen.o: assets/status_strings.inc

# player_state.asm (PrintSafariZoneSteps) %includes the generated Safari HUD strings.
src/engine/overworld/player_state.o: assets/overworld_strings.inc

# field_move_messages.asm %includes the generated field-move FAR text streams.
src/engine/overworld/field_move_messages.o: assets/field_move_text.inc

# cut.asm %includes the generated cut FAR text streams.
src/engine/overworld/cut.o: assets/cut_text.inc
src/engine/overworld/player_animations.o: assets/player_anim_text.inc

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

# Item-use message streams (pret engine/items + engine/menus/party_menu wrappers,
# text_far flattened — same encoder as gen_battle_text.py). Consumed by the item
# USE dispatcher and the party menu's item-use result message.
assets/item_text.inc: ../engine/items/item_effects.asm ../engine/menus/party_menu.asm \
                      ../engine/items/tmhm.asm ../home/pokemon.asm \
                      ../constants/charmap.asm include/gb_memmap.inc \
                      tools/gen_battle_text.py tools/gen_item_text.py assets/battle_text.inc
	python3 tools/gen_item_text.py

src/data/item_data.o: assets/items.inc
src/data/item_text.o: assets/item_text.inc
src/engine/menus/party_menu.o: assets/item_text.inc assets/party_menu_strings.inc \
                               assets/evos_moves.inc
src/engine/items/item_effects.o: assets/item_text.inc assets/map_dims.inc
src/engine/items/tmhm.o: assets/item_text.inc
# PrintStatusCondition's "FNT" glyph run; PartyMenuText_12cc comes from item_text.inc.
src/home/pokemon.o: assets/home_pokemon_strings.inc

# The OPTION screen's row labels + value strings are generated (Tier-1 data;
# menu-fidelity row 14 migrated them out of hand-encoded charmap db bytes).
src/engine/menus/options.o: assets/options_strings.inc assets/ui_layout_menus.inc

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
src/engine/menus/text_box.o: assets/ui_layout_menus.inc assets/ui_layout_battle.inc \
        assets/textbox_strings.inc
src/home/list_menu.o: assets/list_menu_strings.inc
src/home/yes_no.o: assets/yes_no_strings.inc
src/debug/debug_dump.o: $(if $(DEBUG_TEXT),assets/text_oracle.inc)
src/debug/debug_dump.o: assets/scenario_registry.inc
src/engine/menus/display_text_id_init.o: assets/event_constants.inc

# UI layout geometry — projected menu-window coordinates. The sidecar JSON is
# hand-positioned via tools/ui_layout/editor.py (never hand-edited as text);
# the .inc is Tier-1 machine output keyed by element ID (docs/current_plan_menus.md).
assets/ui_layout_menus.inc: assets/ui_layout_menus_sidecar.json \
		tools/gen_ui_layout.py tools/ui_layout/canvas.py tools/ui_layout/schema.py
	python3 tools/gen_ui_layout.py menus

# Battle UI layout geometry (docs/plans/battle_ui.md). Sidecar seeded
# from the legacy battle %defines by tools/ui_layout/seed_from_battle.py
# (asserts byte-identical geometry); redesigned via tools/ui_layout/battle.py.
assets/ui_layout_battle.inc: assets/ui_layout_battle_sidecar.json \
		tools/gen_ui_layout.py tools/ui_layout/canvas.py tools/ui_layout/schema.py
	python3 tools/gen_ui_layout.py battle

src/engine/battle/battle_hud.o src/engine/battle/init_battle.o \
src/engine/battle/pokeballs.o src/home/pics.o \
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

assets: assets/scenario_registry.inc \
        assets/overworld_gfx.inc assets/overworld_blocks.inc assets/pallet_town_blk.inc \
        assets/map_headers.inc assets/extra_includes.inc assets/map_dims.inc \
        assets/map_songs.inc \
        assets/npc_sprite_data_table.inc assets/npc_dialogs/all_dialogs.inc \
        assets/red_bike_sprite.inc assets/seel_sprite.inc \
        assets/surfing_pikachu_sprite.inc \
        assets/toggleable_objects.inc assets/event_constants.inc \
        assets/base_stats.inc assets/growth_rates.inc \
        assets/moves.inc assets/evos_moves.inc assets/monster_names.inc \
        assets/items.inc assets/item_text.inc assets/gb_charmap.txt assets/menu_strings.inc \
        assets/naming_strings.inc assets/pokedex_strings.inc \
        assets/status_strings.inc assets/textbox_strings.inc assets/menu_text.inc \
		$(RUNTIME_STRING_ASSETS) \
        assets/list_menu_strings.inc assets/yes_no_strings.inc \
        assets/text_oracle.inc \
        assets/overworld_strings.inc assets/field_move_text.inc \
        assets/cut_text.inc assets/player_anim_text.inc \
        assets/type_matchups.inc assets/move_names.inc assets/field_moves.inc \
        assets/effect_categories.inc \
        assets/wild_data.inc assets/map_scripts.inc assets/hidden_events.inc \
        assets/hidden_item_coords.inc assets/pickup_text.inc \
        assets/battle_hud_2bpp.inc \
        assets/trainer_pics.inc \
        assets/super_rod.inc assets/town_map_data.inc assets/town_map_gfx.inc \
        assets/ui_layout_menus.inc assets/ui_layout_battle.inc \
        assets/map_border_overrides.inc assets/badge_tiles.inc \
        assets/trainer_card_tiles.inc assets/trainer_card_strings.inc \
        assets/party_menu_strings.inc assets/home_pokemon_strings.inc assets/emotes.inc \
        assets/options_strings.inc \
        assets/alphabets.inc assets/dex_entries.inc assets/sprite_sets.inc \
        assets/sprite_sheet_pointers.inc assets/pokedex_tiles.inc \
        assets/mon_pics.inc \
		assets/colors/palettes.inc \
        assets/audio_rom.inc assets/audio_constants.inc assets/cry_data.inc \
        assets/opl_patches.inc assets/music_streams.inc assets/mt32_sysex.inc \
        assets/pika_pcm.inc assets/tandy_tables.inc assets/enh_streams.inc \
        assets/mon_icons.inc
	python3 tools/audit_memmap.py

assets/scenario_registry.inc: tools/scenario_manifest.json tools/gen_scenario_registry.py
	python3 tools/gen_scenario_registry.py

# Standalone memory-map blast audit (also runs at the end of `make assets`):
# overlap/containment check of every sized region in gb_memmap.inc +
# rom_window.inc. Run after ANY edit that moves or grows a GB-space buffer.
.PHONY: audit_memmap
audit_memmap:
	python3 tools/audit_memmap.py

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
	$(OBJDUMP) -t $@ | python3 tools/gen_symfile.py > pkmn.sym
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
	@exe_sz=$$(stat -c%s $(TARGET)); \
	 dpmi_sz=$$(stat -c%s $(DPMI_HOST)); \
	 img_sz=$$(( ($(IMG_PART_OFF) + exe_sz + dpmi_sz + $(IMG_SLACK) + 1048576 + 511) / 512 * 512 )); \
	 if [ -f $(IMG) ] && [ $$(stat -c%s $(IMG)) -lt $$img_sz ]; then \
	    echo "Recreating $(IMG): $(TARGET) outgrew the existing image"; \
	    rm -f $(IMG); \
	 fi; \
	 if [ ! -f $(IMG) ]; then \
	    rm -f $(IMG); \
	    truncate -s $$img_sz $(IMG); \
	    printf 'label: dos\n$(IMG_PART_SEC),,6,*\n' | sfdisk -q $(IMG) >/dev/null 2>&1; \
	    mkfs.fat -F 16 -n PKMN --offset $(IMG_PART_SEC) $(IMG) >/dev/null; \
	    echo "Created $(IMG) ($$((img_sz/1048576)) MB, ~5 MB free for saves)"; \
	fi
	@set -e; \
	 mt=$$(mktemp); \
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

# Every .asm %includes from include/ (gb_memmap.inc at minimum). The stamp above
# only tracks the -D flags, NOT %include CONTENT — so editing e.g. MAP_BORDER or a
# W_* address in gb_memmap.inc used to rebuild nothing, leaving a binary whose
# objects disagreed about the memory map. That mixes two layouts in one image and
# faults at runtime. Depend on the headers themselves; a header edit is rare enough
# that a full rebuild is the right price.
#
# assets/*.inc: a dozen .asm files `%include "assets/..."` (mon_pics, load_font,
# pokemon_data, wild_data, map_scripts, ...). These are generated, and a
# content change (regen from an edited generator/pret source) used to NOT rebuild
# the consuming object — the exact stale-object class that has bitten us
# repeatedly. Asset regen is timestamp-gated, so listing them here only forces a
# rebuild when an asset input actually changed, not on every make. `wildcard`
# after `make assets` catches newly-created .inc names too, since the assets
# target runs in a separate make phase for `image`/`all`.
INC_DEPS := $(wildcard include/*.inc) $(wildcard assets/*.inc) \
            $(wildcard assets/npc_dialogs/*.inc) \
            src/data/maps/special_warps.asm

%.o: %.asm $(NASMFLAGS_STAMP) $(INC_DEPS)
	$(NASM) $(NASMFLAGS) -o $@ $<

# Assemble-only check (no link): useful for syntax verification
check:
	@for src in $(ALL_SRCS); do \
	    echo "Checking: $$src"; \
	    $(NASM) $(NASMFLAGS) -o /dev/null $$src || exit 1; \
	done
	@echo "All files assembled successfully."

clean:
	rm -f $(ALL_OBJS) $(TARGET) $(NASMFLAGS_STAMP) pkmn.sym
