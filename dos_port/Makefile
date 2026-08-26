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
OBJCOPY := i586-pc-msdosdjgpp-objcopy

NASMFLAGS := -f coff -I include/ -I . -O0

# ---------------------------------------------------------------------------
# Gate macros — the four shapes that 50 of this file's `ifdef` blocks repeated
# verbatim (deduplicated 2026-08-02; the file lost ~150 lines of copy-paste and
# not one flag changed — equivalence was proved by expanding NASMFLAGS for all
# 111 DEBUG_* gates before and after and diffing).
#
# Use one of these when a gate fits exactly. If a gate needs anything else —
# an extra -D, a nested ifdef, a default value — write the block out longhand
# rather than growing a fifth macro or bending one of these. The per-gate
# comments above each call are the documentation; keep writing them.
#
#   dump_gate   NEED_DEBUG_DUMP + -D NAME + -D SKIP_TITLE   (the harness shape)
#   flag_gate   -D NAME                                     (bare passthrough)
#   value_gate  -D NAME=$(NAME)                             (value passthrough)
#   battle_gate DEBUG_BATTLE + -D NAME                      (battle sub-gate)
#
# `$(eval $(call dump_gate,DEBUG_FOO))` is exactly:
#   ifdef DEBUG_FOO / NEED_DEBUG_DUMP := 1 / NASMFLAGS += -D DEBUG_FOO
#   NASMFLAGS += -D SKIP_TITLE / endif
# Order still matters: NASMFLAGS accumulates in file order, so a call sits
# where its longhand block sat.
define dump_gate
ifdef $(1)
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D $(1)
NASMFLAGS += -D SKIP_TITLE
endif
endef

# Stage-6 physical-animation checkpoint: reuse the real STRENGTH turn seeded by
# its real ExecutePlayerMove setup, but terminate at DrawFrameBlock's first
# published OAM. It reuses DEBUG_BATTLE_FAINT's setup; the generated registry
# declares this gate before that implied flag so it stamps id 74, not id 33.
ifdef DEBUG_BATTLE_ANIM_PHYSICAL
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_BATTLE_ANIM_PHYSICAL -D DEBUG_BATTLE_FAINT -D DEBUG_BATTLE_GOLDEN -D DEBUG_BATTLE -D SKIP_TITLE
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_APRESS -D DEBUG_SEED_PARTY
AUTOKEY_DUMP_FRAME ?= 999999
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
endif

# Stage-6 elemental-animation checkpoint: same shape as the physical gate above,
# but the selected move is an elemental one so the checkpoint lands on the
# subanimation/flash path rather than the physical frame blocks.
ifdef DEBUG_BATTLE_ANIM_ELEMENTAL
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_BATTLE_ANIM_ELEMENTAL -D DEBUG_BATTLE_FAINT -D DEBUG_BATTLE_GOLDEN -D DEBUG_BATTLE -D SKIP_TITLE
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_APRESS -D DEBUG_SEED_PARTY
AUTOKEY_DUMP_FRAME ?= 999999
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
endif

# Stage-6 option-off checkpoint: the shake/blink gate's landmark reached with
# wOptions BIT_BATTLE_ANIMATION SET, so MoveAnimation takes its
# .animationsDisabled arm (30-frame delay, no PlayAnimation) and only
# PlayApplyingAttackAnimation runs.
ifdef DEBUG_BATTLE_ANIM_OPTOFF
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_BATTLE_ANIM_OPTOFF -D DEBUG_BATTLE_FAINT -D DEBUG_BATTLE_GOLDEN -D DEBUG_BATTLE -D SKIP_TITLE
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_APRESS -D DEBUG_SEED_PARTY
AUTOKEY_DUMP_FRAME ?= 999999
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
endif

# Stage-6 shake/blink checkpoint: same real STRENGTH turn as the physical gate,
# but the landmark is the first hidden-pic instant of AnimationBlinkMon, i.e.
# PlayApplyingAttackAnimation's wAnimationType 4 arm, which runs AFTER the move
# animation and BEFORE damage is applied.
ifdef DEBUG_BATTLE_ANIM_BLINK
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_BATTLE_ANIM_BLINK -D DEBUG_BATTLE_FAINT -D DEBUG_BATTLE_GOLDEN -D DEBUG_BATTLE -D SKIP_TITLE
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_APRESS -D DEBUG_SEED_PARTY
AUTOKEY_DUMP_FRAME ?= 999999
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
endif

define flag_gate
ifdef $(1)
NASMFLAGS += -D $(1)
endif
endef

define value_gate
ifdef $(1)
NASMFLAGS += -D $(1)=$($(1))
endif
endef

define battle_gate
ifdef $(1)
DEBUG_BATTLE := 1
NASMFLAGS += -D $(1)
endif
endef
# ---------------------------------------------------------------------------

# Bug fix level (0=none, 1=critical, 2=all). Override: make BUG_FIX_LEVEL=1
BUG_FIX_LEVEL ?= 0
NASMFLAGS += -D BUG_FIX_LEVEL=$(BUG_FIX_LEVEL)

# Keyboard naming-screen input path (link cable plan Stage 5 step 4): an
# additive DOS-keyboard alternative to the joypad letter grid in
# src/engine/menus/naming_screen.asm, gated the same way BUG_FIX_LEVEL is
# above (%if value test, not %ifdef) so KBD_NAMING=0 (default) assembles the
# untouched pret-mirrored code path byte-for-byte. Override: make KBD_NAMING=1
KBD_NAMING ?= 0
NASMFLAGS += -D KBD_NAMING=$(KBD_NAMING)

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
$(eval $(call flag_gate,SKIP_TITLE))

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
DEBUG_ASSERT_BOXDIMS := 1
endif
$(eval $(call flag_gate,DEBUG_ASSERT_PROJECTION))
$(eval $(call flag_gate,DEBUG_ASSERT_SCRATCH))
$(eval $(call flag_gate,DEBUG_ASSERT_LIFECYCLE))
$(eval $(call flag_gate,DEBUG_ASSERT_REENTRANCY))
$(eval $(call flag_gate,DEBUG_ASSERT_BOXDIMS))

# Debug flag: dump GB memory windows to DUMP.BIN then exit. make DEBUG_DUMP=1
# (implies SKIP_TITLE path reaching the overworld). See src/debug/debug_dump.asm.
$(eval $(call flag_gate,DEBUG_DUMP))

# Debug flag: force a north map transition (Pallet Town -> Route 1) at boot so the
# post-crossing render can be screenshotted without keyboard input. make DEBUG_TRANSITION=1
$(eval $(call flag_gate,DEBUG_TRANSITION))

# Sub-flag of DEBUG_TRANSITION: skip the CheckMapConnections crossing so the
# DEBUG_TRANSITION reload path dumps a pristine (non-transitioned) current map.
# Use to capture a baseline frame for comparison. make DEBUG_TRANSITION=1 DEBUG_BASELINE=1
$(eval $(call flag_gate,DEBUG_BASELINE))

# Debug flag: simulate a northward walk to the map edge then dump FRAME.BIN, to
# inspect where the transition triggers relative to the visible edge.
# make DEBUG_WALK_NORTH=1 (optionally DEBUG_WALK_STEPS=N via NASM define).
$(eval $(call flag_gate,DEBUG_WALK_NORTH))

# Number of north steps for DEBUG_WALK_NORTH (default 8 in overworld.asm).
$(eval $(call value_gate,DEBUG_WALK_STEPS))

# Seam-crossing trace: spawn beside a map connection, walk into it with the real
# movement primitives, sample state every frame to SEAMLOG.BIN (+ FRAME.BIN), exit.
# Wild encounters are suppressed via wStatusFlags4 BIT_NO_BATTLES, not by de-wiring.
# ---------------------------------------------------------------------------
# CONFLICTING DEBUG FLAGS — fail the BUILD, do not produce a confusing binary.
#
# Every combination below was diagnosed the hard way, from a symptom that looked
# like a game bug: the harness produced a plausible-looking build that behaved
# wrongly in a way nothing announced. A build error costs seconds; "the trainer
# engages and then never fights" cost an evening on 2026-08-15.
#
# Keep the message actionable — say what to run INSTEAD, not just what is wrong.
# ---------------------------------------------------------------------------
ifdef DEBUG_START_MAP
ifdef DEBUG_TRAINER_ROUTE
$(error conflicting flags: DEBUG_START_MAP and DEBUG_TRAINER_ROUTE both seed a \
spawn (map, coords and party), and they disagree. Use ONE: DEBUG_START_MAP for \
an arbitrary map, or TRAINER_ROUTE_PILOT=1 for a hand-playable Route 3 trainer)
endif
endif
ifdef TRAINER_ROUTE_PILOT
ifdef DEBUG_AUTOKEY
$(error conflicting flags: TRAINER_ROUTE_PILOT means "the keyboard drives it" \
and DEBUG_AUTOKEY means "a script drives it". Drop one. For a scripted trainer \
battle use DEBUG_TRAINER_ROUTE=1 with the autokey flags instead)
endif
endif
ifdef DEBUG_SLOTS
ifdef DEBUG_START_MAP
$(error conflicting flags: DEBUG_SLOTS pins the spawn to the GAME CORNER slot \
machine at (17,15) and DEBUG_START_MAP sets its own, so DEBUG_SPAWN_MAP would be \
defined twice. Use ONE: DEBUG_SLOTS for the machine, or DEBUG_START_MAP plus \
DEBUG_SEED_PARTY to walk there yourself)
endif
endif
ifdef DEBUG_NO_WILD
ifdef DEBUG_SEAMWALK
$(error conflicting flags: DEBUG_NO_WILD and DEBUG_SEAMWALK both set wStatusFlags4 \
BIT_NO_BATTLES for different reasons. Use one)
endif
endif

# SEAM TRACE (DEBUG_SEAM=1): the original Viridian City <-> Route 22 investigation.
# Spawn beside the connection, walk across it with the real movement primitives on a
# SCRIPTED path, and sample state every frame into SEAMLOG.BIN.
# Decode with tools/read_seamlog.py.
#   make image DEBUG_SEAM=1 [DEBUG_SPAWN_MAP=0x01 DEBUG_SPAWN_X=3 DEBUG_SPAWN_Y=16 DEBUG_SEAM_STEPS=8]
#
# SPLIT FROM THE SPAWN, 2026-08-15. This flag used to be BOTH "spawn anywhere" and
# "run the seam experiment", so every playable seeded build advertised itself as a
# seam harness and silently inherited its behaviour — including battle suppression,
# which cost a maintainer an evening of hand-testing battles that could not fire.
# The spawn is now DEBUG_SPAWN; the two seam-specific halves are DEBUG_SEAMWALK
# (scripted walk, needs determinism, so IT suppresses battles) and DEBUG_SEAMLOG
# (the per-frame trace, which also claims the A button).
ifdef DEBUG_SEAM
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_SPAWN -D DEBUG_SEAMWALK -D DEBUG_SEAMLOG -D SKIP_TITLE
endif
# Plain PLAYABLE build seeded at an arbitrary map/coord — no trace, no scripted walk,
# BATTLES ON, and A stays a game button. This is the flag for hand-testing.
#   dos_port/run DEBUG_START_MAP=0x0D DEBUG_START_X=3 DEBUG_START_Y=45   (Route 2,
#   below the Viridian Forest south-gate warp)
ifdef DEBUG_START_MAP
NASMFLAGS += -D DEBUG_SPAWN -D SKIP_TITLE
NASMFLAGS += -D DEBUG_SPAWN_MAP=$(DEBUG_START_MAP)
ifdef DEBUG_START_X
NASMFLAGS += -D DEBUG_SPAWN_X=$(DEBUG_START_X)
endif
ifdef DEBUG_START_Y
NASMFLAGS += -D DEBUG_SPAWN_Y=$(DEBUG_START_Y)
endif
endif
# PLAYABLE slot machine: spawn in the GAME CORNER beside a working machine, with
# the coin case and coins the feature refuses to run without.
#   dos_port/run DEBUG_SLOTS=1        then face RIGHT and press A
#
# *** THE SCREEN IS NOT REACHABLE YET, AND NOT BECAUSE OF SLOTS. *** Measured
# 2026-08-16: this gate seeds correctly (COIN_CASE verified present in wBagItems
# via GBSTATE, coins set, spawn issued) but GAME_CORNER renders as a blank room,
# so there is no machine tile to face. GAME_CORNER's header is
# `map_header GameCorner, GAME_CORNER, LOBBY, 0` -- it needs the LOBBY tileset,
# and only overworld_gfx.inc is %included by any source
# (src/engine/overworld/overworld.asm), so only the OVERWORLD tileset reaches the
# binary. The .blk data IS resident and so are the GFX BLOBS -- gen_all_assets.py
# writes all 21 (cavern_gfx.inc, lobby_gfx.inc, ...) -- but nothing includes the
# other 20, so every block falls out of range and draws flat. What is missing is a
# per-map tileset dispatch, not the assets. That is backlog item 31's blocker, and
# it gates every interior, not just this one.
# The gate is kept because it is correct and will work unchanged the moment
# multi-tileset residency lands -- but do NOT read a blank room here as a slots
# defect. engine/slots is linked and assets/hidden_events.inc already carries 36
# `dd StartSlotMachine` rows for this map.
#
# engine/slots/ has been linked since the slots-port merge and the generated
# hidden-event table already carries 36 `dd StartSlotMachine` rows for this map,
# so nothing was missing except a way to STAND in front of one. (The dependency
# graph cannot see those rows: a `dd Label` dispatch table emits no call edge,
# which is why the routine reads as unreached.)
#
# THREE THINGS GATE AbleToPlaySlotsCheck, and all three are seeded here:
#   1. FACING. It tests wSpritePlayerStateData1ImageIndex bit 3, which is set for
#      LEFT ($08) and RIGHT ($0C) only -- a machine CANNOT be played facing UP or
#      DOWN. The spawn faces you DOWN, so press RIGHT before A.
#   2. COIN_CASE in the bag, and 3. wPlayerCoins nonzero -- both seeded by
#      DEBUG_SEED_PARTY under this flag (src/engine/debug/debug_party.asm).
#
# The spawn is (17,15) so the machine in front is (18,15). Hidden events store
# the OBJECT's tile, not the player's, and CheckForHiddenEvent matches the tile
# in FRONT of the player -- so the player tile is one west of the row in
# assets/hidden_events.inc. Machines at x=18 are reached from x=17, and the
# aisles are x = 2, 5, 8, 11, 14, 17.
# Avoid x=18 y=10 (SLOTS_SOMEONESKEYS), 13,12 (SLOTS_OUTTOLUNCH) and 6,12
# (SLOTS_OUTOFORDER): those machines refuse by design, not by defect.
ifdef DEBUG_SLOTS
NEED_DEBUG_DUMP := 1
# -D DEBUG_SLOTS itself is emitted by the flag_gate call below, not here.
NASMFLAGS += -D DEBUG_SEED_PARTY -D SKIP_TITLE
NASMFLAGS += -D DEBUG_SPAWN -D DEBUG_SPAWN_MAP=GAME_CORNER
NASMFLAGS += -D DEBUG_SPAWN_X=17 -D DEBUG_SPAWN_Y=15
# Headless witness: turn RIGHT, then interact. Without it this is a hand-piloted
# build and the keyboard drives it.
#   dos_port/run DEBUG_SLOTS=1                      (play it yourself)
#   make DEBUG_SLOTS=1 AUTOKEY_SLOTS=1 AUTOKEY_DUMP_FRAME=420 image
ifdef AUTOKEY_SLOTS
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_SLOTS
endif
endif
$(eval $(call value_gate,DEBUG_SPAWN_MAP))
$(eval $(call value_gate,DEBUG_SPAWN_X))
$(eval $(call value_gate,DEBUG_SPAWN_Y))
$(eval $(call flag_gate,DEBUG_SLOTS))
$(eval $(call value_gate,DEBUG_SEAM_STEPS))
$(eval $(call value_gate,DEBUG_SEAM_DIR))

# Interactive seam trace: seed the spawn, then hand control to the real OverworldLoop
# (collision LIVE, keyboard driven). Every frame is sampled into a 2048-frame ring;
# press A to write SEAMLOG.BIN + FRAME.BIN and quit. Spawn + trace, NO scripted walk.
#   dos_port/run DEBUG_SEAM_LIVE=1 DEBUG_SPAWN_MAP=0x21 DEBUG_SPAWN_X=36 DEBUG_SPAWN_Y=8
ifdef DEBUG_SEAM_LIVE
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_SPAWN -D DEBUG_SEAMLOG -D SKIP_TITLE
endif

# Suppress wild encounters via the game's own wStatusFlags4 BIT_NO_BATTLES gate,
# re-set on every EnterMap. Fully normal boot otherwise (title screen intact,
# no other DEBUG_* implied); trainer/forced battles unaffected.
# make DEBUG_NO_WILD=1
$(eval $(call flag_gate,DEBUG_NO_WILD))

# DEBUG_SEAM_KEEP_BATTLES: RETIRED 2026-08-15. It existed to undo battle
# suppression that a plain spawn should never have had. Battles are now ON by
# default and suppression belongs to DEBUG_SEAMWALK, so this flag has nothing to
# undo. Kept only as a loud error, because it appears in older notes and in
# scenarios that NEED their battle (the Pallet Oak
# Pikachu catch is silently skipped — not wedged — when the bit is set, because
# the Pallet script does not wait on the battle state).
ifdef DEBUG_SEAM_KEEP_BATTLES
$(error DEBUG_SEAM_KEEP_BATTLES is obsolete and no longer does anything. Battles \
are now ON by default in any DEBUG_START_MAP / DEBUG_SPAWN build; suppression moved \
to DEBUG_SEAMWALK, which is the scripted seam walk that actually needs determinism. \
Just drop the flag)
endif

# AUTOKEY_DUMP_ON_BATTLE=1: photograph the intro battle screen DETERMINISTICALLY.
# A fixed AUTOKEY_DUMP_FRAME cannot reliably catch the narrow intro-battle window
# because boot drift (~150 frames) shifts every absolute frame. This gate dumps
# FRAME.BIN AUTOKEY_BATTLE_DUMP_DELAY frames after wBattleType first goes non-zero
# (the OLD_MAN / PIKACHU intro battle), so it lands mid-battle regardless of drift.
# Battles run by default in a DEBUG_START_MAP build; nothing extra is needed.
#   make DEBUG_START_MAP=0x00 DEBUG_START_X=10 DEBUG_START_Y=0 DEBUG_AUTOKEY=1 \
#        AUTOKEY_APRESS=1 AUTOKEY_NO_PARTY=1 \
#        AUTOKEY_DUMP_ON_BATTLE=1 [AUTOKEY_BATTLE_DUMP_DELAY=90]
ifdef AUTOKEY_DUMP_ON_BATTLE
AUTOKEY_BATTLE_DUMP_DELAY ?= 90
NASMFLAGS += -D AUTOKEY_DUMP_ON_BATTLE -D AUTOKEY_BATTLE_DUMP_DELAY=$(AUTOKEY_BATTLE_DUMP_DELAY)
endif

# DEBUG_TRANSITION_DEMO=1: interactive visual check of ALL 8 battle-transition
# animations. Boots to the overworld (Pallet Town) and cycles ids 0..7 forever
# over the live map view, seeding the REAL selector inputs each round so the
# GetBattleTransitionID_* chain picks the effect. Order: DoubleCircle,
# InwardSpiral, Circle, OutwardSpiral, HorizStripes, Shrink, VertStripes, Split.
#   dos_port/run DEBUG_TRANSITION_DEMO=1
ifdef DEBUG_TRANSITION_DEMO
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_TRANSITION_DEMO -D DEBUG_SEED_PARTY -D SKIP_TITLE
endif
# Flat-canvas-switch regression probe (regression-battle-transition-player-teleport).
# Rides DEBUG_TRANSITION_DEMO; dumps FRAME.BIN either side of the switch and exits,
# so two headless runs cross-correlate to the switch's pixel shift (must be 0,0).
#   dos_port/tools/run_headless.sh "DEBUG_TRANSITION_DEMO=1 DEMO_SWITCH_PROBE=0" /tmp/a
#   dos_port/tools/run_headless.sh "DEBUG_TRANSITION_DEMO=1 DEMO_SWITCH_PROBE=1" /tmp/b
ifdef DEMO_SWITCH_PROBE
NASMFLAGS += -D DEMO_SWITCH_PROBE=$(DEMO_SWITCH_PROBE)
endif

# AUTOKEY_DUMP_ON_FOLLOW=1: state-gated Oak follow-stall probe. Dumps GBSTATE.BIN
# (+FRAME.BIN) and exits the FIRST frame the Pallet cutscene reaches
# PLAYER_FOLLOWS_OAK (script 7) — the instant PalletMovementScript_OakMoveLeft
# reads wXCoord. Robust against the slow A-press battle's frame drift (a fixed
# AUTOKEY_DUMP_FRAME cannot reliably land there). Battles run by default.
#   make DEBUG_START_MAP=0x00 DEBUG_START_X=10 DEBUG_START_Y=0 DEBUG_AUTOKEY=1 \
#        AUTOKEY_APRESS=1 AUTOKEY_NO_PARTY=1 AUTOKEY_DUMP_ON_FOLLOW=1
ifdef AUTOKEY_DUMP_ON_FOLLOW
NASMFLAGS += -D AUTOKEY_DUMP_ON_FOLLOW
# AUTOKEY_FOLLOW_SCRIPT=N: dump the first frame wPalletTownCurScript >= N, to
# bisect WHEN the cutscene coords drift (5=after-battle, 6=oak-not-safe, 7=follow).
ifdef AUTOKEY_FOLLOW_SCRIPT
NASMFLAGS += -D AUTOKEY_FOLLOW_SCRIPT=$(AUTOKEY_FOLLOW_SCRIPT)
endif
# AUTOKEY_FOLLOW_ON_YMOVE=1: dump the exact frame wYCoord first leaves row 0.
ifdef AUTOKEY_FOLLOW_ON_YMOVE
NASMFLAGS += -D AUTOKEY_FOLLOW_ON_YMOVE
endif
# AUTOKEY_FOLLOW_ON_STEP=1: dump the first frame a player step vector goes non-zero.
ifdef AUTOKEY_FOLLOW_ON_STEP
NASMFLAGS += -D AUTOKEY_FOLLOW_ON_STEP
endif
# AUTOKEY_FOLLOW_ON_FLYWARP=1: dump the first frame the fly/dungeon-warp bit arms.
ifdef AUTOKEY_FOLLOW_ON_FLYWARP
NASMFLAGS += -D AUTOKEY_FOLLOW_ON_FLYWARP
endif
# AUTOKEY_FOLLOW_ON_OAKSTEP=1: dump the first frame Oak's scripted-step cursor
# advances in Pallet (binary "did Oak walk?" test — no dump => Oak never moved).
ifdef AUTOKEY_FOLLOW_ON_OAKSTEP
NASMFLAGS += -D AUTOKEY_FOLLOW_ON_OAKSTEP
endif
endif

# Debug noclip: press W in-game to toggle walk-through-walls (disables collision).
# Useful for testing warps, map edges, and OOB behaviour without normal movement.
# Does NOT imply SKIP_TITLE — works at any point in the game.
# make SKIP_TITLE=1 DEBUG_NOCLIP=1
$(eval $(call flag_gate,DEBUG_NOCLIP))

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
    src/home/serial.asm \
    src/home/copy.asm \
    src/home/overworld.asm \
    src/home/pikachu.asm \
    src/home/bankswitch2.asm \
    src/home/bankswitch.asm \
    src/home/text_script.asm \
    src/home/predef_text.asm \
    src/home/textbox.asm \
    src/home/yes_no.asm \
    src/home/list_menu.asm \
    src/home/start_menu.asm \
    src/home/item.asm \
    src/home/count_set_bits.asm \
    src/home/reset_player_sprite.asm \
    src/home/reload_tiles.asm \
    src/home/tilemap.asm \
    src/home/npc_movement.asm \
    src/home/vcopy.asm \
    src/home/copy_string.asm \
    src/home/give.asm \
    src/home/oam.asm \
    src/home/joypad.asm \
    src/home/joypad2.asm \
    src/home/inventory.asm

HAL_SRCS := \
    src/ppu/ppu.asm \
    src/input/joypad.asm \
    src/input/kbd_text.asm \
    src/engine/joypad.asm

# Network/link-cable HAL (docs/current_plan_link_cable.md). Port-owned transport
# layer below the home/serial.asm HAL line: session state, framing/ARQ, and the
# per-transport drivers (null transport first; COM UART, IPX, TCP per plan stage).
# Uses only standard .text/.data/.bss — no link.ld change needed or allowed here.
# (NOT named LINK_SRCS: that var is the linker-input aggregate below.)
NET_SRCS := \
    src/net/net_hal.asm \
    src/net/link_book.asm \
    src/net/link_ui.asm \
    src/net/net_frame.asm \
    src/net/com_uart.asm \
    src/net/ipx_dos.asm \
    src/net/pktdrv.asm \
    src/net/net_ip.asm
ifdef DEBUG_NETTEST
NET_SRCS += src/net/net_test.asm
endif

# Save HAL — the battery. SramLoadImage/SramStoreImage move the emulated 32 KiB
# SRAM image between the resident banks and POKEMON.DSV (.dsv v2, raw image).
SAVE_SRCS := \
    src/save/dsv_io.asm

# Virtual Game Boy Printer device and page backend (docs/current_plan_printer.md)
PRINT_SRCS := \
    src/print/print_dev.asm \
    src/print/escp.asm \
    src/print/lpt_dos.asm

# Audio subsystem (docs/current_plan_audio.md Phase A). The translated pret
# engine writes the virtual APU block at [ebp+rAUD*]; the DelayFrame tick +
# device shims (opl_shim) land in later Phase A tasks. Data blobs are
# generated by tools/audio/gen_audio_data.py (`make assets`).
AUDIO_SRCS := \
    src/data/audio_data.asm \
    src/data/pokemon/cries.asm \
    src/data/pokemon/unknown_list.asm \
    src/home/audio.asm \
    src/home/fade_audio.asm \
    src/audio/audio_hal.asm \
    src/audio/opl_shim.asm \
    src/audio/opl_enh.asm \
    src/audio/tandy_shim.asm \
    src/audio/spk_shim.asm \
    src/audio/mpu401.asm \
    src/audio/sb_pcm.asm \
    src/audio/spk_pcm.asm \
    src/audio/pikachu_pcm.asm \
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
    src/home/lcd.asm \
    src/home/vblank.asm \
    src/home/delay.asm \
    src/home/play_time.asm \
    src/home/clear_sprites.asm \
    src/home/update_sprites.asm \
    src/engine/gfx/sprite_oam.asm \
    src/engine/gfx/animated_objects.asm \
    src/engine/movie/intro_yellow.asm \
    src/data/sprite_anims/intro_frames.asm \
    src/data/sprite_anims/intro_oam.asm \
    src/data/sprite_anims/surfing_pikachu_frames.asm \
    src/data/sprite_anims/surfing_pikachu_oam.asm \
    src/gfx/surfing_pikachu.asm \
    src/engine/minigame/surfing_pikachu.asm \
    src/engine/gfx/mon_icons.asm \
    src/engine/gfx/palettes.asm \
    src/engine/gfx/bg_map_attributes.asm \
    src/engine/gfx/load_pokedex_tiles.asm \
    src/home/load_font.asm \
    src/home/text.asm \
    src/home/print_num.asm \
    src/home/print_text.asm \
    src/home/print_bcd.asm \
    src/home/window.asm \
    src/home/palettes.asm \
    src/home/cgb_palettes.asm \
    src/home/fade.asm \
    src/engine/movie/movie_projection.asm \
    src/engine/movie/splash.asm \
    src/engine/movie/intro.asm \
    src/engine/movie/title.asm \
    src/engine/movie/title_yellow.asm \
    src/engine/movie/oak_speech/init_player_data.asm \
    src/engine/movie/oak_speech/oak_speech.asm \
    src/engine/movie/oak_speech/clear_save.asm \
    src/engine/movie/oak_speech/oak_speech2.asm \
    src/engine/overworld/overworld.asm \
    src/engine/overworld/advance_player_sprite.asm \
    src/engine/overworld/tilesets.asm \
    src/engine/overworld/doors.asm \
    src/engine/overworld/movement.asm \
    src/engine/overworld/sprite_collisions.asm \
    src/engine/overworld/map_sprites.asm \
    src/home/run_map_script.asm \
    src/data/map_scripts.asm \
    src/data/trainer_headers.asm \
    src/data/map_script_tables.asm \
    src/scripts/PalletTown.asm \
    src/scripts/PokemonTower2F.asm \
    src/scripts/PokemonTower7F.asm \
    src/scripts/SafariZoneGate.asm \
    src/scripts/CeruleanTrashedHouse.asm \
    src/scripts/Daycare.asm \
    src/scripts/OaksLab.asm \
    src/scripts/SeafoamIslandsB4F.asm \
    src/scripts/BikeShop.asm \
    src/scripts/MtMoonB2F.asm \
    src/scripts/PokemonTower5F.asm \
    src/scripts/PokemonTower6F.asm \
    src/scripts/RocketHideoutB4F.asm \
    src/scripts/SilphCo11F.asm \
    src/scripts/trainer_map_script.asm \
    src/scripts/CinnabarLabFossilRoom.asm \
    src/scripts/FightingDojo.asm \
    src/scripts/FuchsiaCity.asm \
    src/scripts/GameCorner.asm \
    src/scripts/SSAnne2FRooms.asm \
    src/scripts/AgathasRoom.asm \
    src/scripts/BillsHouse.asm \
    src/scripts/BluesHouse.asm \
    src/scripts/BrunosRoom.asm \
    src/scripts/CeladonChiefHouse.asm \
    src/scripts/CeladonCity.asm \
    src/scripts/CeladonDiner.asm \
    src/scripts/CeladonGym.asm \
    src/scripts/CeladonHotel.asm \
    src/scripts/CeladonMansion1F.asm \
    src/scripts/CeladonMansion2F.asm \
    src/scripts/CeladonMansion3F.asm \
    src/scripts/CeladonMansionRoof.asm \
    src/scripts/CeladonMansionRoofHouse.asm \
    src/scripts/CeladonMart1F.asm \
    src/scripts/CeladonMart2F.asm \
    src/scripts/CeladonMart3F.asm \
    src/scripts/CeladonMart4F.asm \
    src/scripts/CeladonMart5F.asm \
    src/scripts/CeladonMartElevator.asm \
    src/scripts/CeladonMartRoof.asm \
    src/scripts/CeladonPokecenter.asm \
    src/scripts/CeruleanBadgeHouse.asm \
    src/scripts/CeruleanCave1F.asm \
    src/scripts/CeruleanCave2F.asm \
    src/scripts/CeruleanCaveB1F.asm \
    src/scripts/CeruleanCity.asm \
    src/scripts/CeruleanGym.asm \
    src/scripts/CeruleanMart.asm \
    src/scripts/CeruleanMelaniesHouse.asm \
    src/scripts/CeruleanPokecenter.asm \
    src/scripts/ChampionsRoom.asm \
    src/scripts/CinnabarGym.asm \
    src/scripts/CinnabarIsland.asm \
    src/scripts/CinnabarLab.asm \
    src/scripts/CinnabarLabMetronomeRoom.asm \
    src/scripts/CinnabarLabTradeRoom.asm \
    src/scripts/CinnabarMart.asm \
    src/scripts/CinnabarPokecenter.asm \
    src/scripts/Colosseum.asm \
    src/scripts/CopycatsHouse1F.asm \
    src/scripts/CopycatsHouse2F.asm \
    src/scripts/DiglettsCave.asm \
    src/scripts/DiglettsCaveRoute11.asm \
    src/scripts/DiglettsCaveRoute2.asm \
    src/scripts/FuchsiaBillsGrandpasHouse.asm \
    src/scripts/FuchsiaGoodRodHouse.asm \
    src/scripts/FuchsiaGym.asm \
    src/scripts/FuchsiaMart.asm \
    src/scripts/FuchsiaMeetingRoom.asm \
    src/scripts/FuchsiaPokecenter.asm \
    src/scripts/GameCornerPrizeRoom.asm \
    src/scripts/IndigoPlateau.asm \
    src/scripts/IndigoPlateauLobby.asm \
    src/scripts/LancesRoom.asm \
    src/scripts/LavenderCuboneHouse.asm \
    src/scripts/LavenderMart.asm \
    src/scripts/LavenderPokecenter.asm \
    src/scripts/LavenderTown.asm \
    src/scripts/LoreleisRoom.asm \
    src/scripts/MrFujisHouse.asm \
    src/scripts/MrPsychicsHouse.asm \
    src/scripts/MtMoon1F.asm \
    src/scripts/MtMoonB1F.asm \
    src/scripts/MtMoonPokecenter.asm \
    src/scripts/Museum1F.asm \
    src/scripts/Museum2F.asm \
    src/scripts/NameRatersHouse.asm \
    src/scripts/PewterCity.asm \
    src/scripts/PewterGym.asm \
    src/scripts/PewterMart.asm \
    src/scripts/PewterNidoranHouse.asm \
    src/scripts/PewterPokecenter.asm \
    src/scripts/PewterSpeechHouse.asm \
    src/scripts/PokemonFanClub.asm \
    src/scripts/PokemonMansion1F.asm \
    src/scripts/PokemonMansion2F.asm \
    src/scripts/PokemonMansion3F.asm \
    src/scripts/PokemonMansionB1F.asm \
    src/scripts/PokemonTower1F.asm \
    src/scripts/PokemonTower3F.asm \
    src/scripts/PokemonTower4F.asm \
    src/scripts/PowerPlant.asm \
    src/scripts/RedsHouse1F.asm \
    src/scripts/RedsHouse2F.asm \
    src/scripts/RockTunnel1F.asm \
    src/scripts/RockTunnelB1F.asm \
    src/scripts/RockTunnelPokecenter.asm \
    src/scripts/RocketHideoutB1F.asm \
    src/scripts/RocketHideoutB2F.asm \
    src/scripts/RocketHideoutB3F.asm \
    src/scripts/RocketHideoutElevator.asm \
    src/scripts/Route1.asm \
    src/scripts/Route10.asm \
    src/scripts/Route11.asm \
    src/scripts/Route11Gate1F.asm \
    src/scripts/Route11Gate2F.asm \
    src/scripts/Route12.asm \
    src/scripts/Route12Gate1F.asm \
    src/scripts/Route12Gate2F.asm \
    src/scripts/Route12SuperRodHouse.asm \
    src/scripts/Route13.asm \
    src/scripts/Route14.asm \
    src/scripts/Route15.asm \
    src/scripts/Route15Gate1F.asm \
    src/scripts/Route15Gate2F.asm \
    src/scripts/Route16.asm \
    src/scripts/Route16FlyHouse.asm \
    src/scripts/Route16Gate1F.asm \
    src/scripts/Route16Gate2F.asm \
    src/scripts/Route17.asm \
    src/scripts/Route18.asm \
    src/scripts/Route18Gate1F.asm \
    src/scripts/Route18Gate2F.asm \
    src/scripts/Route19.asm \
    src/scripts/Route2.asm \
    src/scripts/Route20.asm \
    src/scripts/Route21.asm \
    src/scripts/Route22.asm \
    src/scripts/Route22Gate.asm \
    src/scripts/Route23.asm \
    src/scripts/Route24.asm \
    src/scripts/Route25.asm \
    src/scripts/Route2Gate.asm \
    src/scripts/Route2TradeHouse.asm \
    src/scripts/Route3.asm \
    src/scripts/Route4.asm \
    src/scripts/Route5.asm \
    src/scripts/Route5Gate.asm \
    src/scripts/Route6.asm \
    src/scripts/Route6Gate.asm \
    src/scripts/Route7.asm \
    src/scripts/Route7Gate.asm \
    src/scripts/Route8.asm \
    src/scripts/Route8Gate.asm \
    src/scripts/Route9.asm \
    src/scripts/SafariZoneCenter.asm \
    src/scripts/SafariZoneCenterRestHouse.asm \
    src/scripts/SafariZoneEast.asm \
    src/scripts/SafariZoneEastRestHouse.asm \
    src/scripts/SafariZoneNorth.asm \
    src/scripts/SafariZoneNorthRestHouse.asm \
    src/scripts/SafariZoneSecretHouse.asm \
    src/scripts/SafariZoneWest.asm \
    src/scripts/SafariZoneWestRestHouse.asm \
    src/scripts/SaffronCity.asm \
    src/scripts/SaffronGym.asm \
    src/scripts/SaffronMart.asm \
    src/scripts/SaffronPidgeyHouse.asm \
    src/scripts/SaffronPokecenter.asm \
    src/scripts/SeafoamIslands1F.asm \
    src/scripts/SeafoamIslandsB1F.asm \
    src/scripts/SeafoamIslandsB2F.asm \
    src/scripts/SeafoamIslandsB3F.asm \
    src/scripts/SilphCo10F.asm \
    src/scripts/SilphCo1F.asm \
    src/scripts/SilphCo2F.asm \
    src/scripts/SilphCo3F.asm \
    src/scripts/SilphCo4F.asm \
    src/scripts/SilphCo5F.asm \
    src/scripts/SilphCo6F.asm \
    src/scripts/SilphCo7F.asm \
    src/scripts/SilphCo8F.asm \
    src/scripts/SilphCo9F.asm \
    src/scripts/SilphCoElevator.asm \
    src/scripts/SSAnne1F.asm \
    src/scripts/SSAnne1FRooms.asm \
    src/scripts/SSAnne2F.asm \
    src/scripts/SSAnne3F.asm \
    src/scripts/SSAnneB1F.asm \
    src/scripts/SSAnneB1FRooms.asm \
    src/scripts/SSAnneBow.asm \
    src/scripts/SSAnneCaptainsRoom.asm \
    src/scripts/SSAnneKitchen.asm \
    src/scripts/SummerBeachHouse.asm \
    src/scripts/TradeCenter.asm \
    src/scripts/UndergroundPathNorthSouth.asm \
    src/scripts/UndergroundPathRoute5.asm \
    src/scripts/UndergroundPathRoute6.asm \
    src/scripts/UndergroundPathRoute7.asm \
    src/scripts/UndergroundPathRoute7Copy.asm \
    src/scripts/UndergroundPathRoute8.asm \
    src/scripts/UndergroundPathWestEast.asm \
    src/scripts/VermilionCity.asm \
    src/scripts/VermilionDock.asm \
    src/scripts/VermilionGym.asm \
    src/scripts/VermilionMart.asm \
    src/scripts/VermilionOldRodHouse.asm \
    src/scripts/VermilionPidgeyHouse.asm \
    src/scripts/VermilionPokecenter.asm \
    src/scripts/VermilionTradeHouse.asm \
    src/scripts/VictoryRoad1F.asm \
    src/scripts/VictoryRoad2F.asm \
    src/scripts/VictoryRoad3F.asm \
    src/scripts/ViridianCity.asm \
    src/scripts/ViridianForest.asm \
    src/scripts/ViridianForestNorthGate.asm \
    src/scripts/ViridianForestSouthGate.asm \
    src/scripts/ViridianGym.asm \
    src/scripts/ViridianMart.asm \
    src/scripts/ViridianNicknameHouse.asm \
    src/scripts/ViridianPokecenter.asm \
    src/scripts/ViridianSchoolHouse.asm \
    src/scripts/WardensHouse.asm \
    src/engine/math/random.asm \
    src/engine/menus/draw_start_menu.asm \
    src/engine/menus/start_sub_menus.asm \
    src/engine/menus/party_menu.asm \
    src/data/moves/field_moves.asm \
    src/data/moves/field_move_names.asm \
    src/engine/menus/text_box.asm \
    src/engine/menus/draw_badges.asm \
    src/engine/menus/pc.asm \
    src/engine/menus/oaks_pc.asm \
    src/engine/menus/league_pc.asm \
    src/engine/menus/league_pc_stubs.asm \
    src/engine/menus/options.asm \
    src/engine/menus/players_pc.asm \
    src/engine/menus/display_text_id_init.asm \
    src/engine/menus/unused_input.asm \
    src/engine/menus/main_menu.asm \
    src/engine/menus/main_menu_stubs.asm \
    src/engine/menus/save.asm \
    src/data/text/dakutens.asm \
    src/engine/menus/naming_screen.asm \
    src/engine/menus/pokedex.asm \
    src/home/printer.asm \
    src/engine/printer/printer.asm \
    src/engine/printer/printer2.asm \
    src/engine/printer/serial.asm \
    src/engine/menus/link_menu.asm \
    src/home/reload_sprites.asm \
    src/home/map_objects.asm \
    src/engine/overworld/overworld_stubs.asm \
    src/engine/overworld/player_animations.asm \
    src/engine/overworld/daycare_exp.asm \
    src/engine/overworld/is_player_just_outside_map.asm \
    src/engine/overworld/dungeon_warps.asm \
    src/engine/overworld/specific_script_flags.asm \
    src/engine/overworld/clear_variables.asm \
    src/data/wild/grass_water.asm \
    src/data/wild/probabilities.asm \
    src/data/maps/songs.asm \
    src/data/maps/map_headers.asm \
    src/data/maps/rest_house_maps.asm \
    src/data/tilesets/pair_collision_tile_ids.asm \
    src/data/tilesets/ledge_tiles.asm \
    src/data/sgb/sgb_packets.asm \
    src/data/tilesets/bike_riding_tilesets.asm \
    src/engine/overworld/wild_mons.asm \
    src/home/hidden_events.asm \
    src/engine/overworld/hidden_events.asm \
    src/data/hidden_events_data.asm \
    src/engine/overworld/hidden_object_stubs.asm \
    src/engine/slots/slot_machine.asm \
    src/engine/slots/game_corner_slots.asm \
    src/engine/slots/game_corner_slots2.asm \
    src/data/events/slot_machine_wheels.asm \
    src/engine/menus/swap_items.asm \
    src/engine/link/cable_club.asm \
    src/engine/link/cable_club_npc.asm \
    src/engine/link/print_waiting_text.asm \
    src/engine/overworld/ledges.asm \
    src/home/pathfinding.asm \
    src/engine/overworld/pathfinding.asm \
    src/engine/overworld/npc_movement_2.asm \
    src/engine/overworld/auto_movement.asm \
    src/home/overworld_text.asm \
    src/engine/pikachu/pikachu_follow.asm \
    src/engine/pikachu/pikachu_movement.asm \
    src/engine/events/try_pikachu_movement.asm \
    src/engine/events/diploma.asm \
    src/engine/events/diploma2.asm \
    src/engine/events/pewter_guys.asm \
    src/engine/events/pokecenter_chansey.asm \
    src/engine/events/oaks_aide.asm \
    src/engine/events/pokedex_rating.asm \
    src/engine/events/saffron_guards.asm \
    src/data/items/guard_drink_items.asm \
    src/data/items/marts.asm \
    src/data/events/trades.asm \
    src/engine/events/elevator.asm \
    src/engine/events/in_game_trades.asm \
    src/engine/events/pokemart.asm \
    src/engine/events/pokecenter.asm \
    src/engine/events/vending_machine.asm \
    src/data/items/vending_prices.asm \
    src/engine/events/prize_menu.asm \
    src/data/events/prizes.asm \
    src/data/events/prize_mon_levels.asm \
    src/engine/events/cinnabar_lab.asm \
    src/engine/events/display_pokedex.asm \
    src/engine/events/set_blackout_map.asm \
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
    src/engine/events/pikachu_happiness.asm \
    src/engine/events/give_pokemon.asm \
    src/data/pickup_text.asm \
    src/data/text_predef_pointers.asm \
    src/engine/events/hidden_events/hidden_events_stubs.asm \
    src/engine/events/hidden_events/bills_house_pc.asm \
    src/engine/events/hidden_events/reds_room.asm \
    src/engine/events/hidden_events/pokecenter_pc.asm \
    src/engine/events/hidden_events/bookshelves.asm \
    src/engine/events/hidden_items.asm \
    src/engine/events/starter_dex.asm \
    src/engine/events/hidden_events/school_blackboard.asm \
    src/engine/events/hidden_events/school_notebooks.asm \
    src/engine/events/hidden_events/cinnabar_gym_quiz.asm \
    src/engine/events/hidden_events/vermilion_gym_trash.asm \
    src/engine/events/hidden_events/vermilion_gym_trash2.asm \
    src/engine/events/hidden_events/bench_guys.asm \
    src/engine/events/hidden_events/book_or_sculpture.asm \
    src/engine/events/hidden_events/magazines.asm \
    src/engine/events/hidden_events/new_bike.asm \
    src/engine/events/hidden_events/route_15_binoculars.asm \
    src/engine/events/hidden_events/indigo_plateau_statues.asm \
    src/engine/events/hidden_events/indigo_plateau_hq.asm \
    src/engine/events/hidden_events/gym_statues.asm \
    src/engine/events/hidden_events/fighting_dojo.asm \
    src/engine/events/hidden_events/blues_room.asm \
    src/engine/events/hidden_events/oaks_lab_posters.asm \
    src/engine/events/hidden_events/oaks_lab_email.asm \
    src/engine/events/hidden_events/fanclub_pictures.asm \
    src/engine/events/hidden_events/museum_fossils.asm \
    src/engine/events/hidden_events/museum_fossils2.asm \
    src/engine/events/hidden_events/town_map.asm \
    src/engine/events/card_key.asm \
    src/engine/events/poison.asm \
    src/engine/events/hidden_events/safari_game.asm \
    src/home/money.asm \
    src/engine/overworld/push_boulder.asm \
    src/engine/overworld/dust_smoke.asm \
    src/engine/overworld/cut.asm \
    src/engine/overworld/cut2.asm \
    src/engine/debug/debug_party.asm \
    src/engine/debug/debug_menu.asm

# debug_menu.asm is the release ELSE arm of pret's file-wide IF DEF(_DEBUG) — one
# `ret`. Linked unconditionally for the same reason debug_party.asm is: pret's
# main.asm INCLUDEs it in every build, so the label exists in a retail ROM.
#
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
    src/data/pokemon/base_stats.asm \
    src/data/growth_rates.asm \
    src/data/moves/moves.asm \
    src/data/pokemon/evos_moves.asm \
    src/data/pokemon/names.asm \
    src/data/pokemon/dex_order.asm \
    src/data/pokemon/dex_entries.asm \
    src/home/math.asm \
    src/engine/math/multiply_divide.asm \
    src/home/array.asm \
    src/home/array2.asm \
    src/home/predef.asm \
    src/home/pokemon.asm \
    src/home/move_mon.asm \
    src/engine/pokemon/experience.asm \
    src/engine/pokemon/add_mon.asm \
    src/engine/pokemon/bills_pc.asm \
    src/engine/pokemon/load_mon_data.asm \
    src/engine/pokemon/set_types.asm \
    src/engine/pokemon/remove_mon.asm \
    src/engine/pokemon/evos_moves.asm \
    src/engine/pokemon/status_ailments.asm \
    src/engine/gfx/hp_bar.asm \
    src/engine/pokemon/status_screen.asm \
    src/engine/pikachu/pikachu_status.asm \
    src/data/pikachu/pikachu_emotions.asm \
    src/engine/pikachu/pikachu_emotions.asm \
    src/gfx/pikachu.asm \
    src/data/pikachu/pikachu_pic_tilemaps.asm \
    src/data/pikachu/pikachu_pic_objects.asm \
    src/data/pikachu/pikachu_pic_animation.asm \
    src/engine/pikachu/pikachu_pic_animation.asm \
    src/engine/pikachu/respawn_overworld_pikachu.asm \
    src/engine/pikachu/pikachu_stubs.asm \
    src/engine/movie/evolution.asm \
    src/engine/movie/hall_of_fame.asm \
    src/engine/movie/credits.asm \
    src/engine/movie/evolution_stubs.asm \
    src/engine/movie/trade.asm \
    src/engine/movie/trade2.asm \
    src/engine/pokemon/learn_move.asm

# Items layer (current_plan_items.md). Non-UI inventory/bag logic + item data.
ITEMS_SRCS := \
    src/data/items/names.asm \
    src/data/items/prices.asm \
    src/data/items/key_items.asm \
    src/data/item_data.asm \
    src/data/items/tm_prices.asm \
    src/data/moves/tmhm_moves.asm \
    src/data/events/card_key_coords.asm \
    src/data/item_text.asm \
    src/engine/items/inventory.asm \
    src/engine/items/item_effects.asm \
    src/engine/items/itemfinder.asm \
    src/engine/items/town_map.asm \
    src/engine/items/tms.asm \
    src/engine/items/tmhm.asm \
    src/engine/items/super_rod.asm \
    src/engine/items/subtract_paid_money.asm \
    src/home/item_price.asm \
    src/engine/items/tm_prices.asm \
    src/home/compare.asm \
    src/engine/math/bcd.asm

# Battle engine backend (current_plan_battle_engine.md). Damage pipeline + data.
# NOTE: this list is CHECK-ONLY (assembled by `make check`, not linked). The faithful
# battle loop (core.asm, FRONTEND_SRCS) needs only a curated subset of it, and that
# subset has been MOVED to FRONTEND_SRCS (decrement_pp, animations); the deeper closures
# here (effects + all move_effects, residual_damage, trainer_ai, names,
# read_trainer_party) still depend on deferred predefs/UI/text and are stubbed at
# link time by core_stubs.asm (JumpMoveEffect / HandlePoisonBurnLeechSeed /
# TrainerAI). Every file here still assembles (make check) and the pure-math
# routines are native-ELF-harness validated.
# (misc.asm / InitList / FormatMovesString were dropped from those two lists
# 2026-08-13: misc.asm now LINKS and its FormatMovesString stand-in is retired.)
# misc.asm PROMOTED to FRONTEND_SRCS 2026-08-13 (Stage-7 retirement sweep). Two
# claims had to fall first, both measured: core_stubs.asm's "GetName/names.asm is
# not yet link-ready (TrainerNames is undefined)" is FALSE (TrainerNames resolves
# in PKMN.EXE), and the REAL blocker -- the port's GetName not preserving
# BC/DE/HL where pret's does -- is fixed in src/home/names2.asm.
# BATTLE_SRCS is EMPTY as of 2026-08-15: its last member, move_category.asm
# (IsTypeSpecial/IsMoveSpecial — zero callers, never linked), was deleted in the
# port-only file remediation. The variable is kept so ALL_SRCS keeps its shape;
# the next check-only battle file (if any) goes here.
BATTLE_SRCS :=
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
$(eval $(call dump_gate,DEBUG_WALKSPEED))
$(eval $(call value_gate,DEBUG_WALKSPEED_FRAMES))
$(eval $(call dump_gate,DEBUG_DIALOG))
# Diagnostic: log every NPC walk-decision (dest tile, true tile, player view
# state) to NPCLOG.BIN while a scripted player walk runs in Pallet Town.
# Used to verify the walking-NPC wall-clipping bug. make DEBUG_NPC_WALK=1
$(eval $(call dump_gate,DEBUG_NPC_WALK))
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
$(eval $(call dump_gate,DEBUG_CALCSTATS))
# Start-menu gate: boot to overworld, force the START menu open, render one frame,
# dump FRAME.BIN, exit. make DEBUG_STARTMENU=1
$(eval $(call dump_gate,DEBUG_STARTMENU))
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
# DEBUG_SIGNTEXT_HOUSE is an ID SELECTOR, nothing more. It changes no behaviour —
# the coords above already do that — and exists because two golden scenarios cannot
# share one `port_entry_gate`: assets/scenario_registry.inc is a %ifdef chain keyed on
# the gate, so a second scenario declaring DEBUG_SIGNTEXT would take over
# GBSTATE_SCENARIO for sign_pallet as well. Defining a distinct symbol gives the
# sign_pallet_house golden (the <PLAYER>-substitution text gate) its own id while
# reusing the same harness. Ordering is automatic: the registry sorts gates by
# build-flag count descending, so the 5-flag house variant is tested first.
ifdef DEBUG_SIGNTEXT_HOUSE
NASMFLAGS += -D DEBUG_SIGNTEXT_HOUSE
endif
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
# Map-script trainer-sight gates (map-script fidelity plan Stage 3): spawn inside a
# trainer's view range on a driver-wired map, run the REAL per-frame map-script
# dispatch (RunMapScript -> MapScriptPointers[wCurMap] -> TrainerMapScript ->
# CheckFightingMapTrainers) until it engages, then dump GBSTATE.BIN + FRAME.BIN.
#
# They deliberately do NOT enter OverworldLoop: the port still carries a bespoke
# CheckTrainerSight/TrainerEncounterFlow hook that pret has no counterpart for, and
# running both would engage the trainer twice. See RunMapScriptSightTest's header in
# src/debug/debug_dump.asm.
#
# ONE GATE PER MAP, not one gate with overrides: golden_diff validates the scenario
# id stamped in the dump against the manifest, and gen_scenario_registry derives that
# id from the port_entry_gate define — so two scenarios sharing a gate would stamp the
# same id and one of them would always fail. Each gate below therefore sets the shared
# implementation define plus its own registry define, and the coords for its map.
# The trainer each one targets is chosen for COVERAGE, not convenience:
#   R3  ROUTE_3  (0x0E) — ROUTE3_YOUNGSTER1  (x=10,y=6)  faces RIGHT, view 2:
#                         horizontal sight, first header in the scan.
#   R6  ROUTE_6  (0x11) — ROUTE6_YOUNGSTER1  (x=0,y=15)  faces RIGHT, view 4, and it
#                         is header 2: headers 0 and 1 have view range 0, so this one
#                         only engages if the scan correctly skips non-seeing trainers.
#   R11 ROUTE_11 (0x16) — ROUTE11_GAMBLER1   (x=10,y=14) faces DOWN, view 3: VERTICAL
#                         sight, which takes TrainerEngage's other branch (linedUpX,
#                         screenX == $40) — untested by the two horizontal ones.
# Batch 2 (overworld-events Stage 5) continues on the same principle — each adds a
# branch or a magnitude the first three never reach:
#   R4  ROUTE_4  (0x0F) — ROUTE4_COOLTRAINER_F2 (x=63,y=3) faces RIGHT, view 3, on
#                         the WIDEST map in the set (45 blocks = 90 tiles). The sight
#                         tile is x=65, where the view pointer's (x >> 1) term and the
#                         sprite screen-X projection are an order of magnitude past
#                         every other gate (their x is 2..13) — the horizontal twin of
#                         R10's large-y case. Route 4 also has exactly ONE trainer
#                         header, so no other trainer can mask a failure by engaging
#                         in its place.
#                         NOT its rationale, though an earlier draft of this comment
#                         said so: `def_trainers 2` (header0 == object 2 rather than
#                         object 1) is NOT unique to Route 4 — scripts/Route3.asm
#                         declares it too, so R3 already covered that pairing. The
#                         goldens agree: both stamp wTrainerFlagBit = 2.
#   R8  ROUTE_8  (0x13) — ROUTE8_GAMBLER1 (x=13,y=9) faces UP, view 4, header 1:
#                         VERTICAL sight UPWARD, the mirror of R11's downward case,
#                         and header 1 rather than 0 or 2.
#   R9  ROUTE_9  (0x14) — ROUTE9_COOLTRAINER_F1 (x=13,y=10) faces LEFT, view 3:
#                         horizontal sight in the direction no other gate takes
#                         (R3 and R6 are both RIGHT).
#   R10 ROUTE_10 (0x15) — ROUTE10_HIKER1 (x=3,y=57) faces UP, view 3, on a TALL map
#                         (10 blocks wide, 36 high). The sight tile is y=55, where
#                         the view-pointer formula's (width + 6) * (y >> 1) term is
#                         an order of magnitude larger than on any other gate (whose
#                         y is 3..16) — the arithmetic none of the others exercises.
#   make DEBUG_MAPSCRIPT_SIGHT_R3=1   (or _R6 / _R11 / _R4 / _R8 / _R9 / _R10 / _VF)
ifdef DEBUG_MAPSCRIPT_SIGHT_R3
DEBUG_MAPSCRIPT_SIGHT := 1
NASMFLAGS += -D DEBUG_MAPSCRIPT_SIGHT_R3
MAPSCRIPT_MAP ?= 0x0E
MAPSCRIPT_Y   ?= 6
MAPSCRIPT_X   ?= 12
endif
# VIRIDIAN_FOREST (0x33): the first NON-ROUTE map on this gate, and the reason it
# was added — a maintainer hand-testing battles found the forest's trainers shout
# TRAINER! and never fight, because the map was table-only (parameter block
# generated, MapScriptPointers still DefaultMapScript) so CheckFightingMapTrainers
# never ran. ViridianForestTrainerHeader0 is YOUNGSTER2 at (x=30, y=33) facing LEFT
# with view range 4 (scripts/ViridianForest.asm), so the player sits at (Y=33,
# X=28): the second tile in its line of sight, same rule as Route 3.
ifdef DEBUG_MAPSCRIPT_SIGHT_VF
DEBUG_MAPSCRIPT_SIGHT := 1
NASMFLAGS += -D DEBUG_MAPSCRIPT_SIGHT_VF
MAPSCRIPT_MAP ?= 0x33
MAPSCRIPT_Y   ?= 33
MAPSCRIPT_X   ?= 28
endif
ifdef DEBUG_MAPSCRIPT_SIGHT_R6
DEBUG_MAPSCRIPT_SIGHT := 1
NASMFLAGS += -D DEBUG_MAPSCRIPT_SIGHT_R6
MAPSCRIPT_MAP ?= 0x11
MAPSCRIPT_Y   ?= 15
MAPSCRIPT_X   ?= 2
endif
ifdef DEBUG_MAPSCRIPT_SIGHT_R11
DEBUG_MAPSCRIPT_SIGHT := 1
NASMFLAGS += -D DEBUG_MAPSCRIPT_SIGHT_R11
MAPSCRIPT_MAP ?= 0x16
MAPSCRIPT_Y   ?= 16
MAPSCRIPT_X   ?= 10
endif
ifdef DEBUG_MAPSCRIPT_SIGHT_R4
DEBUG_MAPSCRIPT_SIGHT := 1
NASMFLAGS += -D DEBUG_MAPSCRIPT_SIGHT_R4
MAPSCRIPT_MAP ?= 0x0F
MAPSCRIPT_Y   ?= 3
MAPSCRIPT_X   ?= 65
endif
ifdef DEBUG_MAPSCRIPT_SIGHT_R8
DEBUG_MAPSCRIPT_SIGHT := 1
NASMFLAGS += -D DEBUG_MAPSCRIPT_SIGHT_R8
MAPSCRIPT_MAP ?= 0x13
MAPSCRIPT_Y   ?= 7
MAPSCRIPT_X   ?= 13
endif
ifdef DEBUG_MAPSCRIPT_SIGHT_R9
DEBUG_MAPSCRIPT_SIGHT := 1
NASMFLAGS += -D DEBUG_MAPSCRIPT_SIGHT_R9
MAPSCRIPT_MAP ?= 0x14
MAPSCRIPT_Y   ?= 10
MAPSCRIPT_X   ?= 11
endif
ifdef DEBUG_MAPSCRIPT_SIGHT_R10
DEBUG_MAPSCRIPT_SIGHT := 1
NASMFLAGS += -D DEBUG_MAPSCRIPT_SIGHT_R10
MAPSCRIPT_MAP ?= 0x15
MAPSCRIPT_Y   ?= 55
MAPSCRIPT_X   ?= 3
endif
# Batch 3 (overworld-events Stage 5a) — the seven OUTDOOR maps of the standard-shape
# remainder. Batch 2 had already covered every facing, so these gates were chosen for
# what a facing cannot test: the table walk, the range boundary, and magnitude.
#   R13 ROUTE_13 (0x18) — ROUTE13_COOLTRAINER_M3 (x=7,y=13) faces UP, view 4,
#                         HEADER 9: the last entry of a ten-header table, so the scan
#                         reaches offset 9 * TH_SIZE (198) and must stop at the db -1.
#                         Every older gate engages a header at index 0..4.
#   R14 ROUTE_14 (0x19) — ROUTE14_BIKER2 (x=4,y=30) faces RIGHT, view 4, header 7.
#                         The ONLY tile in the batch whose scan reaches a RANGE
#                         rejection: header 5 (x=6,y=49, UP, view 4) shares the
#                         player's column and faces them, and is rejected on distance
#                         alone (19 vs 4) two entries before the match. Every other
#                         gate's pre-match rejections are all lined-up rejections, so
#                         a port ignoring range still engages the right trainer there;
#                         here it engages the WRONG one and the golden records it.
#   R15 ROUTE_15 (0x1A) — ROUTE15_COOLTRAINER_F2 (x=53,y=10) faces LEFT, view 3,
#                         header 1, with the player at EXACTLY the view range (3
#                         tiles) rather than the 2 every other gate uses.
#                         CheckSpriteCanSeePlayer is cp b / jr nc — inclusive — so
#                         distance == range must engage; a strict > passes all seven
#                         older gates and fails only this one.
#   R17 ROUTE_17 (0x1C) — ROUTE17_BIKER10 (x=10,y=118) faces DOWN, view 4, header 9,
#                         on the game's TALLEST map (10 blocks wide, 72 high). The
#                         view-pointer term (width + 6) * (y >> 1) is 960 here,
#                         against 560 at R21 and 432 at R10. ALSO the acceptance
#                         gate for ForceBikeDown: this map auto-scrolls south, so
#                         the seeded tile is y=120 and the engaging position is
#                         y=121. Backed out in batch 3 when the port lacked
#                         ForceBikeDown; re-added in batch 4 with it.
#   R18 ROUTE_18 (0x1D) — ROUTE18_COOLTRAINER_M3 (x=42,y=13) faces LEFT, view 4,
#                         header 2 of a THREE-header table — the shortest of the
#                         seventeen. With R13's last-of-ten this brackets the table
#                         walk at both extremes.
#   R19 ROUTE_19 (0x1E) — ROUTE19_SWIMMER1 (x=13,y=25) faces LEFT, view 3, header 2.
#                         Breadth, plus the RIGHT map edge (x=11 of a 20-tile width);
#                         R6 covers the left edge at x=2.
#   R21 ROUTE_21 (0x20) — ROUTE21_SWIMMER4 (x=5,y=71) faces RIGHT, view 4, header 5.
#                         The weakest gate of the seven, recorded as such: breadth
#                         ("no scenario, no wire") plus magnitude (y=71 -> a 560
#                         view-pointer term). Its leading view-range-0 headers repeat
#                         R6's branch. It does NOT prove the scan stops after a match:
#                         the zero-range headers behind the match would engage nobody
#                         even if it ran on, so that state is unobservable here.
#   make DEBUG_MAPSCRIPT_SIGHT_R13=1  (or _R14 / _R15 / _R17 / _R18 / _R19 / _R21)
ifdef DEBUG_MAPSCRIPT_SIGHT_R13
DEBUG_MAPSCRIPT_SIGHT := 1
NASMFLAGS += -D DEBUG_MAPSCRIPT_SIGHT_R13
MAPSCRIPT_MAP ?= 0x18
MAPSCRIPT_Y   ?= 11
MAPSCRIPT_X   ?= 7
endif
ifdef DEBUG_MAPSCRIPT_SIGHT_R14
DEBUG_MAPSCRIPT_SIGHT := 1
NASMFLAGS += -D DEBUG_MAPSCRIPT_SIGHT_R14
MAPSCRIPT_MAP ?= 0x19
MAPSCRIPT_Y   ?= 30
MAPSCRIPT_X   ?= 6
endif
ifdef DEBUG_MAPSCRIPT_SIGHT_R15
DEBUG_MAPSCRIPT_SIGHT := 1
NASMFLAGS += -D DEBUG_MAPSCRIPT_SIGHT_R15
MAPSCRIPT_MAP ?= 0x1A
MAPSCRIPT_Y   ?= 10
MAPSCRIPT_X   ?= 50
endif
ifdef DEBUG_MAPSCRIPT_SIGHT_R18
DEBUG_MAPSCRIPT_SIGHT := 1
NASMFLAGS += -D DEBUG_MAPSCRIPT_SIGHT_R18
MAPSCRIPT_MAP ?= 0x1D
MAPSCRIPT_Y   ?= 13
MAPSCRIPT_X   ?= 40
endif
ifdef DEBUG_MAPSCRIPT_SIGHT_R19
DEBUG_MAPSCRIPT_SIGHT := 1
NASMFLAGS += -D DEBUG_MAPSCRIPT_SIGHT_R19
MAPSCRIPT_MAP ?= 0x1E
MAPSCRIPT_Y   ?= 25
MAPSCRIPT_X   ?= 11
endif
ifdef DEBUG_MAPSCRIPT_SIGHT_R21
DEBUG_MAPSCRIPT_SIGHT := 1
NASMFLAGS += -D DEBUG_MAPSCRIPT_SIGHT_R21
MAPSCRIPT_MAP ?= 0x20
MAPSCRIPT_Y   ?= 71
MAPSCRIPT_X   ?= 7
endif
ifdef DEBUG_MAPSCRIPT_SIGHT
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_MAPSCRIPT_SIGHT
NASMFLAGS += -D SKIP_TITLE
MAPSCRIPT_MAP ?= 0x0E
MAPSCRIPT_Y   ?= 6
MAPSCRIPT_X   ?= 12
# Frames of map-script dispatch before giving up and dumping an un-engaged state
# (which fails the diff loudly rather than passing silently).
MAPSCRIPT_SIGHT_FRAMES ?= 120
NASMFLAGS += -D MAPSCRIPT_MAP=$(MAPSCRIPT_MAP) -D MAPSCRIPT_Y=$(MAPSCRIPT_Y) \
             -D MAPSCRIPT_X=$(MAPSCRIPT_X) \
             -D MAPSCRIPT_SIGHT_FRAMES=$(MAPSCRIPT_SIGHT_FRAMES)
endif

# Continuous trainer-route gate (battle plan Stage 1b) — golden scenario
# `trainer_battle_route`, id 51. Spawns on Route 3 inside ROUTE3_YOUNGSTER1's
# sight line and then FALLS THROUGH into the real OverworldLoop: the map script
# engages, StartTrainerBattle seeds wCurOpponent, the loop's own battle-entry
# poll turns that into the battle, AUTOKEY_TRAINER_ROUTE answers the live menus,
# and .battleOccurred returns to the map where EndTrainerBattle runs at script
# index 2. This is the ONLY scenario in which the port's real loop drives a
# trainer battle end to end — 44/45/46 call StartTrainerBattle and InitBattle
# from a harness and never run the loop.
#
# Placed AFTER the generic DEBUG_MAPSCRIPT_SIGHT block deliberately: this gate
# sets no MAPSCRIPT_* variable (it seeds its spawn directly in the EnterMap block
# in src/home/overworld.asm), so it takes no part in that block's `?=`
# first-set-wins chain and cannot perturb the sight scenarios' defaults.
# battle_ai_switch (battle plan 1e): DEBUG_TRAINER_ROUTE's real Route 3 sight
# battle, with wTrainerClass pinned to COOLTRAINER_F and the enemy's HP pinned
# into CooltrainerFAI's switch band, so the trainer AI CHOOSES TO SWITCH. Nothing
# else in the suite reaches SwitchEnemyMon. Dumps on the latch, not on a frame.
ifdef DEBUG_BATTLE_AISWITCH
NEED_DEBUG_DUMP := 1
# AISWITCH_PROBE=1 loosens the latch to the first frame wEnemyMonPartyPos leaves
# 0 and adds three probe-only regions. Investigation aid; never registered.
ifdef AISWITCH_PROBE
NASMFLAGS += -D AISWITCH_PROBE
endif
NASMFLAGS += -D DEBUG_BATTLE_AISWITCH -D DEBUG_TRAINER_ROUTE
NASMFLAGS += -D DEBUG_SEED_PARTY -D SKIP_TITLE
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_TRAINER_ROUTE
AUTOKEY_DUMP_FRAME ?= 30000
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
endif

# make DEBUG_TRAINER_ROUTE=1 [AUTOKEY_DUMP_FRAME=1500]
# battle_ghost (battle plan 4c's witness, 2026-08-14): the ghost identity arm has
# no other witness. Seeds wCurOpponent = RESTLESS_SOUL on Route 1 and lets the
# REAL OverworldLoop take one step into it — NewBattle -> InitBattle ->
# InitOpponent -> InitWildBattle.isGhost. Needs no Pokemon Tower map and no
# absent Silph Scope: those gate IsGhostBattle and the .isMarowak unveil arm, not
# the identity. AUTOKEY_BATTLE_GHOST presses the one DOWN; the dump is frame
# based like battle_intro's because the faithful intro parks at its own prompt.
# battle_ghost_unveil: the .isMarowak UNVEIL arm, which needs the tower map AND
# the Silph Scope on top of the ghost gate's forced opponent. It is the only way
# to execute MarowakAnim, which has a caller but has never run.
ifdef DEBUG_BATTLE_UNVEIL
DEBUG_BATTLE_GHOST := 1
NASMFLAGS += -D DEBUG_BATTLE_UNVEIL
endif

ifdef DEBUG_BATTLE_GHOST
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_BATTLE_GHOST -D DEBUG_SEED_PARTY -D SKIP_TITLE
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_BATTLE_GHOST
# PARKED, like battle_safari_result / battle_run_type: this gate photographs on
# GAME STATE (120 in-battle frames after wBattleMonSpecies goes nonzero), not on
# a frame number. Measured 2026-08-14 — with a real value here the frame dump
# fires FIRST and photographs the parked intro, which is how a state-gated gate
# silently becomes a frame-gated one.
AUTOKEY_DUMP_FRAME ?= 999999
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
endif

ifdef DEBUG_TRAINER_ROUTE
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_TRAINER_ROUTE -D DEBUG_SEED_PARTY -D SKIP_TITLE
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_TRAINER_ROUTE
# MEASURED against the mGBA reference run: engagement lands ~frame 400 after map
# entry, the battle starts ~800, and the three roster mons take until ~6100 more
# frames to fall, after which the return choreography runs. The autokey cadence
# covers 240..18240; dump well after the battle has closed and the overworld has
# settled. This is deliberately generous — the dump is a fixed frame, so it must
# be later than the SLOWEST plausible battle, not the typical one.
AUTOKEY_DUMP_FRAME ?= 15000
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
# AK_ROUTE_SHIFT=<frames>: shift the whole autokey script (debugger-attach aid,
# same role as AK_LEDGE_SHIFT). Never set for a golden run.
ifdef AK_ROUTE_SHIFT
NASMFLAGS += -D AK_ROUTE_SHIFT=$(AK_ROUTE_SHIFT)
endif
# AK_ROUTE_CYCLES=<n>: number of 120-frame A,DOWNx3,A cycles (default 220 in
# debug_dump.asm, covering frames 240..26640; the DOWNs are state-gated to the
# move menu by AutoKeyDrive). A dump frame past that end needs this raised too,
# or the battle stalls unanswered once the presses run out.
ifdef AK_ROUTE_CYCLES
NASMFLAGS += -D AK_ROUTE_CYCLES=$(AK_ROUTE_CYCLES)
endif
# AUTOKEY_ROUTE_WALK=1: bug-B repro walk (regression-battle-second-trainer-
# wont-engage). Pre-battle scripted walk into ROUTE3_YOUNGSTER2's sight line
# (needs PILOT_NEUTRAL=1 so the spawn starts OUT of sight and the battle ends
# at a tile != the re-seed target), then a post-battle walk into
# ROUTE3_YOUNGSTER1's true line, then stand. Run with AK_ROUTE_CYCLES=72.
#   make DEBUG_TRAINER_ROUTE=1 PILOT_NEUTRAL=1 AUTOKEY_ROUTE_WALK=1 AK_ROUTE_CYCLES=72
ifdef AUTOKEY_ROUTE_WALK
NASMFLAGS += -D AUTOKEY_ROUTE_WALK
endif
ifdef AK_WALK_BASE
NASMFLAGS += -D AK_WALK_BASE=$(AK_WALK_BASE)
endif
endif

# make DEBUG_TRAINER_ROUTE17=1
# ROUTE_17 / ForceBikeDown witness (map-script fidelity plan, third attempt at
# wiring ROUTE_17). ForceBikeDown is ported and faithdiff-clean but has never had
# a runtime witness: RunMapScriptSightTest (the route*_sight family) never enters
# OverworldLoopLessDelay, where the routine lives, so it structurally cannot
# observe it (regression-overworld-forcebikedown-missing — measured twice, on
# BOTH earlier attempts to wire ROUTE_17). This gate is shaped like
# DEBUG_TRAINER_ROUTE: seed, then fall through into the REAL OverworldLoop, the
# only loop that ever calls ForceBikeDown.
#
# Like DEBUG_BATTLE_GHOST, the dump is STATE-GATED (wIsInBattle==2 AND
# wEnemyMonSpecies!=0, settled — see AUTOKEY_TRAINER_ROUTE17 in debug_dump.asm),
# not frame-gated, so AUTOKEY_DUMP_FRAME is pushed far out to guarantee the
# generic frame-based fallback dump in AutoKeyDrive never fires first.
ifdef DEBUG_TRAINER_ROUTE17
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_TRAINER_ROUTE17 -D DEBUG_SEED_PARTY -D SKIP_TITLE
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_TRAINER_ROUTE17
AUTOKEY_DUMP_FRAME ?= 999999
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
ifdef AK_ROUTE17_CYCLES
NASMFLAGS += -D AK_ROUTE17_CYCLES=$(AK_ROUTE17_CYCLES)
endif
endif

# Pallet Oak cutscene gate: seed Pallet's north-exit trigger, execute the Pallet
# state-machine/battle-seed boundary deterministically, and dump GBSTATE+FRAME.
# Drives RunOakIntroTest (src/debug/debug_dump.asm).
#
# RENAMED 2026-08-02 from DEBUG_OAK_INTRO. It sat one underscore away from
# DEBUG_OAKINTRO below (~line 1106), which is an entirely different gate: that
# one drives RunOakSpeechCheckpoint — Prof. Oak's OPENING SPEECH — and is the
# registered golden scenario `oak_intro` (id 29, scenario_manifest.json), owned
# by docs/current_plan_menu_intro.md.
#
# The near-collision was not hypothetical: docs/current_plan_overworld_events.md
# recorded THIS cutscene as covered by a passing golden, having matched on the
# scenario NAME. It was reading the other gate's scenario. This gate is still
# registered in no manifest row, so the Pallet cutscene has NO golden coverage —
# tracked as item #30 in docs/current_plan_backlog.md. A new golden here needs a
# distinct name (e.g. pallet_oak_cutscene), not a reuse of `oak_intro`.
$(eval $(call dump_gate,DEBUG_PALLET_OAK))
# Party-seed gate: run the debug new-game seed (party + bag + Pokédex) at boot,
# dump party/bag WRAM to DUMP.BIN, exit. Verifies the pokemon/items engine runs
# inside the real binary. make DEBUG_PARTY=1
$(eval $(call dump_gate,DEBUG_PARTY))
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
$(eval $(call flag_gate,DEBUG_BAGMENU_EMPTY))
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
# Stage-6 ball-animation checkpoint. It is a MODIFIER on the DEBUG_ITEMBALL gate
# below, not a gate of its own: the whole real ITEM -> MASTER BALL route is
# reused and only the stopping point moves earlier, to DrawFrameBlock's first
# published ULTRATOSS_ANIM frame block. So it is always passed ALONGSIDE
# DEBUG_ITEMBALL=1 (see the scenario's build_flags), which is also what keeps the
# generated registry from stamping it with ball_catch's id -- that generator
# orders gates by build_flags token count, descending.
ifdef DEBUG_BATTLE_ANIM_BALL
NASMFLAGS += -D DEBUG_BATTLE_ANIM_BALL
endif

# the caught/dex messages. make DEBUG_ITEMBALL=1 [ITEMBALL_ID=0x04 ITEMBALL_SLOT=n]
ifdef DEBUG_ITEMBALL
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_ITEMBALL -D DEBUG_BATTLE -D SKIP_TITLE
# AUTOKEY_ITEMBALL, not AUTOKEY_APRESS: since 2026-08-12 this gate drives the
# REAL battle menu (ITEM -> MASTER BALL) instead of presetting wCurItem and
# calling UseItem, so it needs the navigation presses, not just A-mashing.
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_ITEMBALL -D DEBUG_SEED_PARTY
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
# Turn-resolution / faint / EXP gate (battle_faint): the same seeded wild battle as
# DEBUG_ITEMBALL, but SNORLAX L80 actually swings STRENGTH at the spec PIDGEY L13 and
# knocks it out, so the real damage pipeline and the real FaintEnemyPokemon ->
# GainExperience chain execute. This is the gate session 8's coverage analysis asked
# for: before it, NO scenario resolved a turn or fainted a mon, so 49 of the 62 pret
# core.asm labels moved that session were never executed by a green suite.
# The matchup is chosen so nothing compared depends on an RNG roll -- see the gate's
# header in src/debug/debug_dump.asm for why one turn always suffices.
# make DEBUG_BATTLE_FAINT=1
ifdef DEBUG_BATTLE_FAINT
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_BATTLE_FAINT -D DEBUG_BATTLE_GOLDEN -D DEBUG_BATTLE -D SKIP_TITLE
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_APRESS -D DEBUG_SEED_PARTY
# The turn prints "SNORLAX used STRENGTH!", the faint message and the EXP messages,
# several of which block on a button; AUTOKEY_APRESS answers them. As with
# DEBUG_ITEMBALL, AutoKeyDrive's own FRAME.BIN dump would exit the program mid-flow,
# so push it past the end of the run.
AUTOKEY_DUMP_FRAME ?= 999999
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
endif
# Player-faint / black-out gate (battle_blackout): the other half of the faint
# coverage battle_faint opened. battle_faint kills the ENEMY; this one kills the
# PLAYER, so RemoveFaintedPlayerMon and HandlePlayerBlackOut finally execute.
# Leaves exactly one mon alive (slot 3, PIKACHU L5) at 1 HP so the black-out
# branch is reached without the interactive ChooseNextMon menu, and pins the
# enemy's moves so nothing compared depends on an RNG roll -- see the gate's
# header in src/debug/debug_dump.asm.
# make DEBUG_BATTLE_BLACKOUT=1
# Voluntary in-battle SWITCH gate (battle_switch golden, battle plan Stage 2):
# the DEBUG_BATTLE_GOLDEN scene, then the REAL DisplayBattleMenu driven
# PKMN -> party slot 1 -> SWITCH by the AUTOKEY_BATTLE_SWITCH script, then
# GBSTATE.BIN the instant DisplayBattleMenu returns. This is the only gate that
# executes PartyMenuOrRockOrRun / SwitchPlayerMon / RetreatMon /
# AnimateRetreatingPlayerMon at all -- nothing else in the scenario registry
# presses PKMN.
# AUTOKEY_DUMP_FRAME defaults past the end of the run so the gate's own dump
# wins; pass AUTOKEY_DUMP_FRAME=1500 to use it as a FRAME.BIN viewer instead.
#   dos_port/tools/run_headless.sh "DEBUG_BATTLE_SWITCH=1" /tmp/switch
ifdef DEBUG_BATTLE_SWITCH
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_BATTLE_SWITCH -D DEBUG_BATTLE_GOLDEN -D DEBUG_BATTLE -D SKIP_TITLE
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_BATTLE_SWITCH -D DEBUG_SEED_PARTY
AUTOKEY_DUMP_FRAME ?= 999999
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
# BATTLE_SWITCH_WINDOW_PROBE=1 adds the port-only window-layer diagnosis rows
# (g_window_count / g_windows / io_lcdc) to GBSTATE.BIN. NEVER for a scenario
# run: the differ joins regions by name and the golden has no counterpart.
ifdef BATTLE_SWITCH_WINDOW_PROBE
NASMFLAGS += -D BATTLE_SWITCH_WINDOW_PROBE
endif
# BATTLE_SWITCH_DESELECT=1 presses B instead of A on the SWITCH/STATS/CANCEL box,
# so .partyMonDeselected's erase runs. NEVER for a scenario run: the golden takes
# the switch. Photograph after the erase, e.g.
#   run_headless.sh "DEBUG_BATTLE_SWITCH=1 BATTLE_SWITCH_DESELECT=1 AUTOKEY_DUMP_FRAME=1000"
ifdef BATTLE_SWITCH_DESELECT
NASMFLAGS += -D BATTLE_SWITCH_DESELECT
endif
# BATTLE_SWITCH_STATS=1 takes STATS instead of SWITCH and returns to the battle
# screen, so the post-StatusScreen enemy-pic reload is observable. NEVER for a
# scenario run: the golden takes the switch. e.g.
#   run_headless.sh "DEBUG_BATTLE_SWITCH=1 BATTLE_SWITCH_STATS=1 AUTOKEY_DUMP_FRAME=1900"
ifdef BATTLE_SWITCH_STATS
NASMFLAGS += -D BATTLE_SWITCH_STATS
endif
endif
# In-battle ITEM gate (battle_item_potion golden, battle plan 2c): the
# DEBUG_BATTLE_GOLDEN scene with the active mon knocked to POTION_SEED_HP, then
# the REAL DisplayBattleMenu driven ITEM -> POTION -> the active mon by the
# AUTOKEY_BATTLE_ITEM script, then GBSTATE.BIN the instant DisplayBattleMenu
# returns. The only gate that opens the battle BAG: ball_catch presets wCurItem
# and calls UseItem directly, so it proves nothing about the menu leg 2c ported.
#   dos_port/tools/run_headless.sh "DEBUG_BATTLE_ITEM=1" /tmp/potion
ifdef DEBUG_BATTLE_ITEM
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_BATTLE_ITEM -D DEBUG_BATTLE_GOLDEN -D DEBUG_BATTLE -D SKIP_TITLE
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_BATTLE_ITEM -D DEBUG_SEED_PARTY
AUTOKEY_DUMP_FRAME ?= 999999
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
endif
# Forced-switch gate (battle_choose_next_mon, battle plan 2b): the third door out
# of HandlePlayerMonFainted. battle_faint kills the ENEMY, battle_blackout kills
# the player's LAST mon; this one kills the player's mon with ANOTHER ALIVE, so
# AnyPartyAlive succeeds and DoUseNextMonDialogue + ChooseNextMon finally run.
# Two mons alive: slot 3 (PIKACHU L5) at 1 HP as the active one, slot 5 (LAPRAS
# L34) at full as the replacement -- see the gate header for why the gap matters.
#   dos_port/tools/run_headless.sh "DEBUG_BATTLE_NEXTMON=1" /tmp/nextmon
# Failed in-battle ITEM gate (battle_item_no_effect, battle plan 2c): a POTION
# used on a FULL-HP mon, which takes ItemUseMedicine's .healingItemNoEffect
# branch. The dump is state-gated (AutoKeyDrive), because on failure UseBagItem
# loops back into the bag menu and DisplayBattleMenu never returns.
#   dos_port/tools/run_headless.sh "DEBUG_BATTLE_ITEM_FAIL=1" /tmp/itemfail
ifdef DEBUG_BATTLE_ITEM_FAIL
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_BATTLE_ITEM_FAIL -D DEBUG_BATTLE_GOLDEN -D DEBUG_BATTLE -D SKIP_TITLE
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_BATTLE_ITEM_FAIL -D DEBUG_SEED_PARTY
AUTOKEY_DUMP_FRAME ?= 999999
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
endif
ifdef DEBUG_BATTLE_NEXTMON
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_BATTLE_NEXTMON -D DEBUG_BATTLE_GOLDEN -D DEBUG_BATTLE -D SKIP_TITLE
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_BATTLE_NEXTMON -D DEBUG_SEED_PARTY
AUTOKEY_DUMP_FRAME ?= 999999
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
# BATTLE_NEXTMON_MENU_PROBE=1 adds the HandleMenuInput state block to
# GBSTATE.BIN. Diagnosis only; never for a scenario run.
ifdef BATTLE_NEXTMON_MENU_PROBE
NASMFLAGS += -D BATTLE_NEXTMON_MENU_PROBE
endif
ifdef AUTOKEY_NEXTMON_MENU_FRAME
NASMFLAGS += -D AUTOKEY_NEXTMON_MENU_FRAME=$(AUTOKEY_NEXTMON_MENU_FRAME)
endif
ifdef AUTOKEY_NEXTMON_DOWNS
NASMFLAGS += -D AUTOKEY_NEXTMON_DOWNS=$(AUTOKEY_NEXTMON_DOWNS)
endif
ifdef AUTOKEY_NEXTMON_APRESS_END
NASMFLAGS += -D AUTOKEY_NEXTMON_APRESS_END=$(AUTOKEY_NEXTMON_APRESS_END)
endif
endif
# Pay Day payout gate (battle_pay_day, battle plan 3b): SNORLAX L80 uses PAY_DAY
# on the spec wild PIDGEY L13, the KO ends the battle, and EndOfBattle pays the
# accumulated wTotalPayDayMoney into wPlayerMoney with AddBCD. The payout is
# level*2 in BCD, so the compared value has no RNG in it.
#   dos_port/tools/run_headless.sh "DEBUG_BATTLE_PAYDAY=1" /tmp/payday
# Trapping-counter gate (battle_wrap, battle plan 3a): SNORLAX L80 uses WRAP on
# the spec wild PIDGEY L13 and the REAL MainInBattleLoop runs the turns, which is
# the only way to reach CheckNumAttacksLeft. AutoKeyDrive pins the rolled attack
# count to 1 and dumps when the turn tail clears USING_TRAPPING_MOVE.
#   dos_port/tools/run_headless.sh "DEBUG_BATTLE_WRAP=1" /tmp/wrap
# Mutual-faint gate (battle_self_destruct, battle plan 3c): SNORLAX L80 uses
# SELFDESTRUCT on the spec wild PIDGEY L13, so both mons hit 0 HP in the same
# turn and FaintEnemyPokemon takes its player-also-fainted arm.
#   dos_port/tools/run_headless.sh "DEBUG_BATTLE_SELFDESTRUCT=1" /tmp/boom
# EXP ALL gate (battle_exp_all, battle plan 3e): the seeded bag's last slot is
# swapped to EXP_ALL, so FaintEnemyPokemon takes its whole-party EXP branch.
#   dos_port/tools/run_headless.sh "DEBUG_BATTLE_EXPALL=1" /tmp/expall
ifdef DEBUG_BATTLE_EXPALL
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_BATTLE_EXPALL -D DEBUG_BATTLE_GOLDEN -D DEBUG_BATTLE -D SKIP_TITLE
ifdef EXPALL_PARTY_COUNT
NASMFLAGS += -D EXPALL_PARTY_COUNT=$(EXPALL_PARTY_COUNT)
endif
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_APRESS -D DEBUG_SEED_PARTY
AUTOKEY_DUMP_FRAME ?= 999999
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
endif
ifdef DEBUG_BATTLE_SELFDESTRUCT
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_BATTLE_SELFDESTRUCT -D DEBUG_BATTLE_GOLDEN -D DEBUG_BATTLE -D SKIP_TITLE
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_APRESS -D DEBUG_SEED_PARTY
AUTOKEY_DUMP_FRAME ?= 999999
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
endif
ifdef DEBUG_BATTLE_WRAP
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_BATTLE_WRAP -D DEBUG_BATTLE_GOLDEN -D DEBUG_BATTLE -D SKIP_TITLE
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_APRESS -D DEBUG_SEED_PARTY
AUTOKEY_DUMP_FRAME ?= 999999
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
endif
# Bide store/release gate (battle_bide, battle plan 3a residue): SNORLAX L80 uses
# BIDE on the spec wild PIDGEY L13 and the REAL MainInBattleLoop runs the two
# turns, which is the only way to reach ExecutePlayerMove's .bideCheck and
# .unleashEnergy. AutoKeyDrive pins the rolled counter, the accumulator and
# wDamage, and dumps once the release has taken the enemy to 799 HP.
#   dos_port/tools/run_headless.sh "DEBUG_BATTLE_BIDE=1" /tmp/bide
ifdef DEBUG_BATTLE_BIDE
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_BATTLE_BIDE -D DEBUG_BATTLE_GOLDEN -D DEBUG_BATTLE -D SKIP_TITLE
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_APRESS -D DEBUG_SEED_PARTY
AUTOKEY_DUMP_FRAME ?= 999999
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
endif
# Thrash end gate (battle_thrash, battle plan 3a residue): SNORLAX L80 uses
# THRASH on the spec wild PIDGEY L13 and the REAL MainInBattleLoop runs the two
# turns, which is the only way to reach ExecutePlayerMove's .thrashingAboutCheck.
# The enemy is seeded to 65535 HP, not battle_wrap's 999 — THRASH is power 90 and
# two hits blow through 999, ending the thrash by KO instead of by the routine.
#   dos_port/tools/run_headless.sh "DEBUG_BATTLE_THRASH=1" /tmp/thrash
ifdef DEBUG_BATTLE_THRASH
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_BATTLE_THRASH -D DEBUG_BATTLE_GOLDEN -D DEBUG_BATTLE -D SKIP_TITLE
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_APRESS -D DEBUG_SEED_PARTY
AUTOKEY_DUMP_FRAME ?= 999999
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
endif
# battle_safari (battle plan 4d): the SAFARI battle menu, rendered. Unlike the
# two tutorial gates this uses AUTOKEY_QUIET + a fixed dump frame (battle_menu's
# shape), because the Safari menu parks in HandleMenuInput with nothing to poll.
#   dos_port/tools/run_headless.sh "DEBUG_BATTLE_SAFARI=1" /tmp/safari
# battle_run_type: the last battle type in box 2225. BATTLE_TYPE_RUN reaches the
# SAME special-battle loop as SAFARI (pret .checkAnyPartyAlive sends it to
# .specialBattle, which falls into .displaySafariZoneBattleMenu), so this gate
# enters through the same trampoline. AUTOKEY_BATTLERUN drives DOWN+RIGHT to the
# menu's RUN item — item 3, the only value .handleUnusedBattle acts on.
ifdef DEBUG_BATTLE_RUNTYPE
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_BATTLE_RUNTYPE -D DEBUG_BATTLE_GOLDEN -D DEBUG_BATTLE -D SKIP_TITLE
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_BATTLERUN -D DEBUG_SEED_PARTY
AUTOKEY_DUMP_FRAME ?= 999999
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
endif

# battle_safari_result: the RESULT/EXIT half for BATTLE_TYPE_SAFARI. Same
# staging as DEBUG_BATTLE_SAFARI (which it defines), but instead of calling
# DisplayBattleMenu directly it ENTERS the production special-battle loop at
# StartBattle.displaySafariZoneBattleMenu, so the Safari turn tail and flee roll
# run for real. AUTOKEY_SAFARI (not AUTOKEY_QUIET) drives RIGHT+A to BAIT.
ifdef DEBUG_BATTLE_SAFARI_RESULT
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_BATTLE_SAFARI_RESULT -D DEBUG_BATTLE_SAFARI
NASMFLAGS += -D DEBUG_BATTLE_GOLDEN -D DEBUG_BATTLE -D SKIP_TITLE
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_SAFARI -D DEBUG_SEED_PARTY
AUTOKEY_DUMP_FRAME ?= 999999
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
endif

ifdef DEBUG_BATTLE_SAFARI
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_BATTLE_SAFARI -D DEBUG_BATTLE_GOLDEN -D DEBUG_BATTLE -D SKIP_TITLE
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_QUIET -D DEBUG_SEED_PARTY
AUTOKEY_DUMP_FRAME ?= 300
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
endif
# battle_pikachu (battle plan 4a): the Prof. Oak / Pikachu SIMULATED battle
# menu — the same .doSimulatedMenuInput as the old-man gate, differing only in
# which name is copied over wPlayerName.
#   dos_port/tools/run_headless.sh "DEBUG_BATTLE_PIKACHU=1" /tmp/pika
# battle_pikachu_result: the RESULT/EXIT half for BATTLE_TYPE_PIKACHU. Same
# staging as DEBUG_BATTLE_PIKACHU (which it defines); the rename dump is compiled
# out and the gate runs the tutorial to its capture tail instead.
ifdef DEBUG_BATTLE_PIKACHU_RESULT
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_BATTLE_PIKACHU_RESULT -D DEBUG_BATTLE_PIKACHU
NASMFLAGS += -D DEBUG_BATTLE_GOLDEN -D DEBUG_BATTLE -D SKIP_TITLE
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_APRESS -D DEBUG_SEED_PARTY
AUTOKEY_DUMP_FRAME ?= 999999
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
endif

ifdef DEBUG_BATTLE_PIKACHU
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_BATTLE_PIKACHU -D DEBUG_BATTLE_GOLDEN -D DEBUG_BATTLE -D SKIP_TITLE
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_APRESS -D DEBUG_SEED_PARTY
AUTOKEY_DUMP_FRAME ?= 999999
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
endif
# battle_oldman (battle plan 4b): the old-man / Prof. Oak SIMULATED battle menu,
# DisplayBattleMenu.doSimulatedMenuInput. Same flag set as the gates above —
# DEBUG_AUTOKEY is required and not optional, because this gate's dump lives in
# AutoKeyDrive, which vblank.asm only calls under %ifdef DEBUG_AUTOKEY.
#   dos_port/tools/run_headless.sh "DEBUG_BATTLE_OLDMAN=1" /tmp/oldman
# battle_oldman_result: the RESULT/EXIT half of the per-battle-type box. Same
# staging as DEBUG_BATTLE_OLDMAN (it defines that flag), but the rename dump is
# compiled out and the gate runs the tutorial to its capture tail instead.
ifdef DEBUG_BATTLE_OLDMAN_RESULT
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_BATTLE_OLDMAN_RESULT -D DEBUG_BATTLE_OLDMAN
NASMFLAGS += -D DEBUG_BATTLE_GOLDEN -D DEBUG_BATTLE -D SKIP_TITLE
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_APRESS -D DEBUG_SEED_PARTY
AUTOKEY_DUMP_FRAME ?= 999999
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
endif

ifdef DEBUG_BATTLE_OLDMAN
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_BATTLE_OLDMAN -D DEBUG_BATTLE_GOLDEN -D DEBUG_BATTLE -D SKIP_TITLE
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_APRESS -D DEBUG_SEED_PARTY
AUTOKEY_DUMP_FRAME ?= 999999
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
endif
ifdef DEBUG_BATTLE_PAYDAY
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_BATTLE_PAYDAY -D DEBUG_BATTLE_GOLDEN -D DEBUG_BATTLE -D SKIP_TITLE
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_APRESS -D DEBUG_SEED_PARTY
AUTOKEY_DUMP_FRAME ?= 999999
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
endif
ifdef DEBUG_BATTLE_BLACKOUT
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_BATTLE_BLACKOUT -D DEBUG_BATTLE_GOLDEN -D DEBUG_BATTLE -D SKIP_TITLE
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_APRESS -D DEBUG_SEED_PARTY
AUTOKEY_DUMP_FRAME ?= 999999
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
endif
# Numerical damage oracle: player/enemy numerical spines stage their effective
# formula inputs and independently sampled damage rolls for semantic checking.
# make DEBUG_BATTLE_DAMAGE=1
ifdef DEBUG_BATTLE_DAMAGE
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_BATTLE_DAMAGE -D DEBUG_BATTLE_GOLDEN -D DEBUG_BATTLE -D SKIP_TITLE
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_APRESS -D DEBUG_SEED_PARTY
AUTOKEY_DUMP_FRAME ?= 999999
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
endif
# DEBUG_ANIM_DEMO=1: interactive visual check of an in-battle MOVE animation
# (battle_animations plan Stage 2b item 4 — the maintainer sign-off harness).
# Builds the battle_faint/battle_intro golden scene (real loaders, real enemy
# front pic + player back pic + HUDs), then calls the REAL PlayMoveAnimation ->
# MoveAnimation interpreter on one move id, over and over, with the screen live.
#   dos_port/run DEBUG_ANIM_DEMO=1 [ANIM=<MOVE_CONST>] /LOOP
# ANIM= takes any move constant from include/gb_constants.inc (default POUND —
# a plain OAM-particle move); /LOOP (the shared exe flag, g_cfg_musicloop) makes
# the loop run forever for watching. WITHOUT /LOOP the demo is BOUNDED: it runs
# DEBUG_ANIM_LOOPS (default 3) iterations, then dumps GBSTATE.BIN + DUMP.BIN and
# exits, so run_headless.sh can prove the harness executed.
# NOTE (Stages 3-5): every SE/mon-pic/palette/shake handler is still a ret-stub,
# so what you see is OAM particle frame blocks only — that is expected today.
# DEBUG_ANIM_SHOW=1: the Stage 4/5 animation SHOWCASE ("onslaught"). Same battle
# scene as DEBUG_ANIM_DEMO, but instead of one move it walks a curated list of
# real moves covering every animation family landed after Stage 3, printing each
# move's name (via the real GetMoveName -> MoveNames table) in the battle frame
# before playing it, so a viewer can tell what they are looking at.
#   dos_port/run DEBUG_ANIM_SHOW=1 /LOOP      <- the maintainer sign-off command
# /LOOP repeats the whole list forever. WITHOUT /LOOP it plays the list ONCE,
# then dumps GBSTATE.BIN + DUMP.BIN and exits, so run_headless.sh can prove it
# ran. ANIM_SHOW_HOLD sets the frames each name is held before its animation
# (default 40, ~0.65 s) and ANIM_SHOW_GAP the pause after (default 50).
ifdef DEBUG_ANIM_SHOW
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_ANIM_SHOW -D DEBUG_BATTLE_GOLDEN -D DEBUG_BATTLE -D SKIP_TITLE
NASMFLAGS += -D DEBUG_SEED_PARTY
ANIM_SHOW_HOLD ?= 40
ANIM_SHOW_GAP ?= 50
NASMFLAGS += -D ANIM_SHOW_HOLD=$(ANIM_SHOW_HOLD) -D ANIM_SHOW_GAP=$(ANIM_SHOW_GAP)
endif

ifdef DEBUG_ANIM_DEMO
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_ANIM_DEMO -D DEBUG_BATTLE_GOLDEN -D DEBUG_BATTLE -D SKIP_TITLE
NASMFLAGS += -D DEBUG_SEED_PARTY
ANIM ?= POUND
NASMFLAGS += -D DEBUG_ANIM_ID=$(ANIM)
DEBUG_ANIM_LOOPS ?= 3
NASMFLAGS += -D DEBUG_ANIM_LOOPS=$(DEBUG_ANIM_LOOPS)
endif
# Length of the AUTOKEY_APRESS button train (any AUTOKEY_APRESS gate), for a flow
# that raises more button waits than the 300-press default covers.
$(eval $(call value_gate,AUTOKEY_APRESS_COUNT))
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

# PP-family gate (items-plan Stage 11): seeded party + bag, RunPPRestoreTest drains
# one move's PP and drives the real UseItem dispatcher at a PP item, so
# ItemUsePPRestore runs its party menu -> type-2 move menu -> restore -> consume
# chain. AUTOKEY_APRESS answers both menus and every message.
# make DEBUG_ITEMPP=1 [ITEMPP_ID=0x51 ITEMPP_MON=0 ITEMPP_DRAIN=1]
ifdef DEBUG_ITEMPP
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_ITEMPP -D DEBUG_SEED_PARTY -D SKIP_TITLE
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_APRESS
ifdef ITEMPP_ID
NASMFLAGS += -D ITEMPP_ID=$(ITEMPP_ID)
endif
ifdef ITEMPP_MON
NASMFLAGS += -D ITEMPP_MON=$(ITEMPP_MON)
endif
ifdef ITEMPP_DRAIN
NASMFLAGS += -D ITEMPP_DRAIN=$(ITEMPP_DRAIN)
endif
# Same reason as DEBUG_ITEMTM above: AutoKeyDrive's own FRAME.BIN dump exits the
# program, so it must stay clear of this gate's DebugDumpMemory capture.
AUTOKEY_DUMP_FRAME ?= 999999
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
endif

# Predef-text gate (predef-text plan Stage 2 acceptance): stand on the SNES tile in
# Red's bedroom and run the REAL hidden-event A-press dispatch, so RedBedroomSNESText
# reaches the screen through PrintPredefTextID and DisplayTextID's TEXT_PREDEF branch.
# AUTOKEY_QUIET presses nothing (the dialog stays up); AutoKeyDrive photographs it.
# make DEBUG_PREDEFTEXT=1 [AUTOKEY_DUMP_FRAME=260]
ifdef DEBUG_PREDEFTEXT
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_PREDEFTEXT -D SKIP_TITLE
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_QUIET
AUTOKEY_DUMP_FRAME ?= 260
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
endif

# ---------------------------------------------------------------------------
# Hidden-object / bookshelf golden gates (2026-08-21).
#
# All of these share ONE port-side seed+dispatch gate, DEBUG_HIDDENOBJ (see
# EnterMap in src/home/overworld.asm): seed map/coords/facing, seed the A press
# into hJoyHeld, then call the REAL
# CheckForHiddenEventOrBookshelfOrCardKeyDoor. Each scenario still needs its own
# DEBUG_<X> symbol because assets/scenario_registry.inc dispatches GBSTATE_SCENARIO
# on the gate name — the seed is shared, the id cannot be.
#
# HIDDENOBJ_Y/X are the tile the PLAYER STANDS ON, which is NOT the prop's tile.
# CheckForHiddenEvent matches each row against CheckIfCoordsInFrontOfPlayerMatch —
# the tile IN FRONT of the player for the seeded facing — so a prop at (y,x) read
# facing UP requires the player at (y+1, x). Seeding the player onto the prop's own
# tile matches nothing and the dispatch silently finds no event: measured here as a
# correctly-rendered room with no dialog at all.
# The prop coordinates themselves are NOT invented: each is the prop's own
# `hidden_event` row in assets/hidden_events.inc (y, x, facing-arg), generated from
# pret's data/events/hidden_events.asm. HIDDENOBJ_DIR 0xFF = ANY_FACING.
define hiddenobj_gate
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D $(1) -D DEBUG_HIDDENOBJ -D SKIP_TITLE
NASMFLAGS += -D HIDDENOBJ_MAP=$(2) -D HIDDENOBJ_Y=$(3) -D HIDDENOBJ_X=$(4) -D HIDDENOBJ_DIR=$(5)
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_QUIET
AUTOKEY_DUMP_FRAME ?= 260
# $$ so the reference survives $(call)'s expansion and is resolved by $(eval),
# i.e. AFTER the ?= above has run. With a single $ it expands during the call,
# when AUTOKEY_DUMP_FRAME is still empty, and NASM dies on `cmp ecx,` with no
# operand (debug_dump.asm:5399) rather than on anything to do with this gate.
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$$(AUTOKEY_DUMP_FRAME)
endef

# Route 15 Gate 2F left binoculars. assets/hidden_events.inc:
#   HiddenEventsFor_ROUTE_15_GATE_2F: db 2, 1, 0x04 -> Route15GateLeftBinoculars
# prop (y=2,x=1) read facing UP -> player stands at (y=3,x=1)
# make DEBUG_BINOCULARS=1 [AUTOKEY_DUMP_FRAME=n]
ifdef DEBUG_BINOCULARS
$(eval $(call hiddenobj_gate,DEBUG_BINOCULARS,0xB9,3,1,0x04))
endif

# Oak's Lab LEFT poster. assets/hidden_events.inc:
#   HiddenEventsFor_OAKS_LAB: db 0, 4, 0x04 -> DisplayOakLabLeftPoster
#                             db 0, 5, 0x04 -> DisplayOakLabRightPoster
# OAKS_LAB_POSTER=right selects the x=5 tile instead, so the one gate covers both
# handlers; the scenario registers the LEFT one.
OAKS_LAB_POSTER ?= left
ifdef DEBUG_OAKSPOSTER
ifeq ($(OAKS_LAB_POSTER),right)
$(eval $(call hiddenobj_gate,DEBUG_OAKSPOSTER,0x28,1,5,0x04))
else
$(eval $(call hiddenobj_gate,DEBUG_OAKSPOSTER,0x28,1,4,0x04))
endif
endif

# Bill's House PC prop (the teleporter/cell-separator cutscene machine, NOT the box
# UI — see engine/events/hidden_events/bills_house_pc.asm). assets/hidden_events.inc:
#   HiddenEventsFor_BILLS_HOUSE: db 4, 1, 0x04 -> BillsHousePC
# BillsHousePC branches on event flags; the scenario seeds
# EVENT_BILL_SAID_USE_CELL_SEPARATOR to select .doCellSeparator, which is the branch
# the golden drives. That seeding is the scenario's job, not the gate's.
# make DEBUG_BILLSHOUSEPC=1 [AUTOKEY_DUMP_FRAME=n]
# Indigo Plateau statues. NOT a hidden_event: IndigoPlateauStatues is a BOOKSHELF
# TILE (data/tilesets/bookshelf_tile_ids.asm: `bookshelf_tile PLATEAU, $30`) and a
# predef_code TextPredefs row ($3C). The shared gate covers it because
# CheckForHiddenEventOrBookshelfOrCardKeyDoor falls through to
# GetTileAndCoordsInFrontOfPlayer -> PrintBookshelfText when no hidden event matches.
# Coordinates are the tile the player stands on, facing the statue tile.
# Gym statues (pret engine/events/hidden_events/gym_statues.asm:GymStatues).
# PEWTER_GYM ($36, 5x7, GYM tileset) is the easiest instance: two statues, an open
# floor in front of them, and no map script in the way.
# assets/hidden_events.inc:
#   HiddenEventsFor_PEWTER_GYM: db 10, 3, 0x04 -> GymStatues
#                               db 10, 6, 0x04 -> GymStatues
# The prop is (y=10, x=3) so the player stands at (y=11, x=3) facing UP.
# WALKABILITY VERIFIED, not assumed: decoding pewter_gym_blk through gym_blocks and
# gym_coll, all four GB tiles of player (11,3) are $11 and passable, while (10,3) is
# $22/$23/$32/$33 and impassable — i.e. the statue itself. An earlier revision of
# this gate aimed at INDIGO_PLATEAU and seeded the player INSIDE a statue pillar; a
# seeded spawn skips collision so the port still printed the text, but no player can
# stand there and the mGBA side, which walks, could never reproduce it.
STATUES_Y ?= 11
STATUES_X ?= 3
STATUES_DIR ?= 0x04
ifdef DEBUG_STATUES
$(eval $(call hiddenobj_gate,DEBUG_STATUES,0x36,$(STATUES_Y),$(STATUES_X),$(STATUES_DIR)))
# GymStatueText1 splices wGymCityName/wGymLeaderName out of WRAM, and the gym's own
# map script is what fills them (LoadGymLeaderAndCityName). Tick the script once so
# the port reaches the state the ROM's overworld loop has already reached.
NASMFLAGS += -D HIDDENOBJ_RUNSCRIPT
endif

# ---------------------------------------------------------------------------
# safari_game_over — the Safari Zone step countdown running out. THE WALKING GATE.
#
# Every other overworld gate seeds the player next to the thing under test and
# presses A. This one cannot: the subject is a COMPLETED STEP. SafariZoneCheckSteps
# is reached only from StepCountCheck's arm in OverworldLoopLessDelay, once per
# finished step, so the gate walks — spawn, fall through into the real loop, and
# let AUTOKEY_SAFARI_GAMEOVER hold PAD_DOWN.
#
# SAFARI_ZONE_CENTER is $DC (assets/map_dims.inc). (y=1, x=4) and the tiles below
# it are passable in forest_coll; the golden spawns on the same tile.
#
# AUTOKEY_DUMP_FRAME is a FRAME number, not a landmark, and this gate can afford
# that because the whole timeline is scripted and parks: after the single A that
# turns TimesUpText's `para` page, both sides sit at a `prompt` waiting for a
# button that never comes. Nothing moves between the page turn and the dump.
#   make DEBUG_SAFARI_GAMEOVER=1 [AK_SAFARI_WALK=n] [AK_SAFARI_PAGE=n] [AUTOKEY_DUMP_FRAME=n]
ifdef DEBUG_SAFARI_GAMEOVER
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_SAFARI_GAMEOVER -D SKIP_TITLE
NASMFLAGS += -D SAFARI_GAMEOVER_MAP=0xDC -D SAFARI_GAMEOVER_Y=1 -D SAFARI_GAMEOVER_X=4
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_SAFARI_GAMEOVER
AK_SAFARI_WALK ?= 60
AK_SAFARI_PAGE ?= 300
NASMFLAGS += -D AK_SAFARI_WALK=$(AK_SAFARI_WALK) -D AK_SAFARI_PAGE=$(AK_SAFARI_PAGE)
AUTOKEY_DUMP_FRAME ?= 420
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
endif

ifdef DEBUG_BILLSHOUSEPC
$(eval $(call hiddenobj_gate,DEBUG_BILLSHOUSEPC,0x58,5,1,0x04))
# BillsHousePC dispatches on event flags, and the branch choice decides whether this
# gate can be compared at all. EVENT_LEFT_BILLS_HOUSE_AFTER_HELPING selects
# .displayBillsHousePokemonList, which draws the Eevee-evolution menu and PARKS in
# HandleMenuInput — a stable state both sides hold indefinitely.
#
# NOT .doCellSeparator (EVENT_BILL_SAID_USE_CELL_SEPARATOR): that branch sets
# wDoNotWaitForButtonPressAfterDisplayingText and RETURNS, so it is not a state at
# all. The port's gate parks after the dispatch and freezes the dialog on screen,
# while the ROM's overworld loop resumes and redraws over it — the two sides settle
# in structurally different places, and no dump instant makes them comparable.
# Gating that branch needs a gate that falls back into OverworldLoop plus a
# scenario-local wEventFlags region to witness SetEvent
# EVENT_USED_CELL_SEPARATOR_ON_BILL. Not built; see the scenario header.
NASMFLAGS += -D HIDDENOBJ_EVENT=EVENT_LEFT_BILLS_HOUSE_AFTER_HELPING
endif


# Surfboard gate (items-plan Stage 11): spawn on the Pallet Town shore, seed a
# SURFBOARD into bag slot 0, then FALL THROUGH into the real OverworldLoop and let
# AUTOKEY_SURF's scripted joypad drive mount and dismount with live collision.
# AutoKeyDrive dumps FRAME.BIN + GBSTATE.BIN at AUTOKEY_DUMP_FRAME.
# make DEBUG_SURF=1 [AUTOKEY_DUMP_FRAME=1350]
ifdef DEBUG_SURF
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_SURF -D DEBUG_SEED_PARTY -D SKIP_TITLE
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_SURF
ifdef SURF_ITEM_ID
NASMFLAGS += -D SURF_ITEM_ID=$(SURF_ITEM_ID)
endif
# The scripted round trip ends at frame 1120 (the USE that dismounts); dump
# once it has settled, with the bag still open — see the AUTOKEY_SURF note.
AUTOKEY_DUMP_FRAME ?= 1220
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
endif

# Ledge-hop gate (regression-overworld-ledge-hop-never-advanced): spawn on Route 1
# one step above a south-facing ledge, seed the debug party, then FALL THROUGH into
# the real OverworldLoop. AUTOKEY_LEDGE presses DOWN to arm the hop (HandleLedges),
# the two simulated steps + HandleMidJump teardown run through the live loop, and a
# second DOWN proves input/collision work again after the teardown.
# make DEBUG_LEDGE=1 [AUTOKEY_DUMP_FRAME=420]
ifdef DEBUG_LEDGE
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_LEDGE -D DEBUG_SEED_PARTY -D SKIP_TITLE
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_LEDGE
# Arm press at 60, hop (2 simulated steps + teardown) done well before 240, the
# post-teardown step at 300; dump after everything settles.
AUTOKEY_DUMP_FRAME ?= 420
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
# AK_LEDGE_SHIFT=<frames>: shift the whole autokey script (debugger-attach aid).
# Never set for a golden run.
ifdef AK_LEDGE_SHIFT
NASMFLAGS += -D AK_LEDGE_SHIFT=$(AK_LEDGE_SHIFT)
endif
# DEBUG_LEDGE_TRACE=1: per-call HandleMidJump state ring in SRAM bank 3, added
# to GBSTATE.BIN as "ledgeTrace". Debug aid only — never set for a golden run.
ifdef DEBUG_LEDGE_TRACE
NASMFLAGS += -D DEBUG_LEDGE_TRACE
endif
endif

# Fishing-rod gate (items-plan Stage 11): spawn on the Pallet Town shore (the
# DEBUG_SURF tile map), seed an OLD ROD into bag slot 0, then FALL THROUGH into
# the real OverworldLoop. AUTOKEY_FISH drives one FishingInit FAILURE (front
# tile still 0 = not water) and then the deterministic OLD ROD bite (no RNG:
# MAGIKARP lv 5) through the live bag UI. Dump lands with the bag still open —
# wCurOpponent is armed and closing the menus would start the wild battle.
# make DEBUG_FISH=1 [AUTOKEY_DUMP_FRAME=2000]
ifdef DEBUG_FISH
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_FISH -D DEBUG_SEED_PARTY -D SKIP_TITLE
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_FISH
# 2000 -> 1800 (2026-08-14, with the PrintBeginningBattleText wiring). This gate
# photographs the bag OPEN with wCurOpponent armed and the battle NOT yet started
# — golden_diff.py says so in its own entry. The faithful intro changed how this
# flow's prompts consume the AUTOKEY_FISH train, and at 2000 the port had already
# entered the battle: the ONLY divergence was wLetterPrintingDelayFlags $03 vs
# $01, i.e. InitBattleCanvas' port-only BIT_FAST_TEXT_DELAY, with every other
# field still matching. Measured: PASS at 1700 and at 1850, FAIL at 2000/2160/2300.
# So this retimes the photograph back onto the instant the scenario documents,
# rather than masking a field it was never meant to capture.
AUTOKEY_DUMP_FRAME ?= 1800
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
endif

# Bill's-PC box-behaviour gate (sram plan stage 6): seeded party, RunBillsPCTest
# opens BillsPC_ directly as a generic-PC guest, and the AUTOKEY_BILLSPC script
# drives deposit(PERSIAN) → deposit(JIGGLYPUFF) → withdraw(PERSIAN) →
# release(JIGGLYPUFF) → SEE YA through the real UI, then AutoKeyDrive dumps
# FRAME.BIN + GBSTATE.BIN. make DEBUG_BILLSPC=1 [AUTOKEY_DUMP_FRAME=n]
ifdef DEBUG_BILLSPC
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_BILLSPC -D DEBUG_SEED_PARTY -D SKIP_TITLE
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_BILLSPC
# 1900 -> 3800 on 2026-08-12 with the AUTOKEY_BILLSPC cadence doubling: PlayCry
# stopped being a ret-stub, so the flow now really plays (and waits on) three
# cries. See the cadence note on the script in debug_dump.asm.
AUTOKEY_DUMP_FRAME ?= 3800
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
# BILLSPC_ATTACH_DELAY=<frames>: RunBillsPCTest idles that long before the flow
# so a debugger can attach; the autokey script shifts itself by the same amount
# (1800 ≈ 30 s). Debug aid only — never set for a golden run.
ifdef BILLSPC_ATTACH_DELAY
NASMFLAGS += -D BILLSPC_ATTACH_DELAY=$(BILLSPC_ATTACH_DELAY)
endif
# BILLSPC_MENU_PROBE=1 adds the wMenuState diagnosis region to GBSTATE.BIN.
ifdef BILLSPC_MENU_PROBE
NASMFLAGS += -D BILLSPC_MENU_PROBE
endif
endif
# Change-box round-trip gate (sram plan stage 6, SRAM banks 2/3): same harness
# (RunBillsPCTest), the AUTOKEY_BILLSPC_CHANGE script — deposit(PERSIAN) →
# CHANGE BOX → BOX12 → CHANGE BOX → BOX 1 → SEE YA, two real SaveGameData
# commits. make DEBUG_BILLSPC_CHANGEBOX=1 [AUTOKEY_DUMP_FRAME=n]
ifdef DEBUG_BILLSPC_CHANGEBOX
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_BILLSPC_CHANGEBOX -D DEBUG_SEED_PARTY -D SKIP_TITLE
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_BILLSPC_CHANGE
# 3800 -> 7600 on 2026-08-12, same reason as DEBUG_BILLSPC above.
AUTOKEY_DUMP_FRAME ?= 7600
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
ifdef BILLSPC_ATTACH_DELAY
NASMFLAGS += -D BILLSPC_ATTACH_DELAY=$(BILLSPC_ATTACH_DELAY)
endif
ifdef BILLSPC_MENU_PROBE
NASMFLAGS += -D BILLSPC_MENU_PROBE
endif
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
$(eval $(call flag_gate,DEBUG_SEED_PARTY))
# Scripted-joypad harness: seeded party + SKIP_TITLE + AutoKeyDrive replaying a
# button sequence (src/home/vblank.asm), so a keyboard-only live path (overworld -> START ->
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
# START -> <NAME> (trainer card) -> exit, then park in the reopened START menu.
# make DEBUG_AUTOKEY=1 AUTOKEY_TRAINERCARD=1 [AUTOKEY_DUMP_FRAME=n]
ifdef AUTOKEY_TRAINERCARD
NASMFLAGS += -D AUTOKEY_TRAINERCARD
AUTOKEY_DUMP_FRAME ?= 400
endif
# START -> <n DOWNs> -> A -> B -> B, photographing the OVERWORLD it returns to.
# The generic exit-path probe AUTOKEY_TRAINERCARD is the special case of: a
# submenu that runs a SET_PAL_* command and does not restore it leaves the map
# in the submenu's palette. n=1 POKéMON (party menu), n=5 OPTION.
# ⚠ render with PAL.BIN or the defect is invisible.
# make DEBUG_AUTOKEY=1 AUTOKEY_SUBMENU_EXIT=1 [AUTOKEY_DUMP_FRAME=n]
ifdef AUTOKEY_SUBMENU_EXIT
NASMFLAGS += -D AUTOKEY_SUBMENU_EXIT=$(AUTOKEY_SUBMENU_EXIT)
AUTOKEY_DUMP_FRAME ?= 500
endif
# Press NOTHING, ever — only AutoKeyDrive's AUTOKEY_DUMP_FRAME timer runs, so a
# screen that drives itself (or parks in its own key-wait) can be photographed
# without input. debug_dump.asm has had the AUTOKEY_QUIET script branch all along;
# this gate never forwarded it, so `AUTOKEY_QUIET=1` was SILENTLY IGNORED and the
# build fell through to the default START/DOWN/A script — which opens the party
# menu and looks like a plausible result. Measured 2026-08-05.
# make DEBUG_AUTOKEY=1 AUTOKEY_QUIET=1 [AUTOKEY_DUMP_FRAME=n]
ifdef AUTOKEY_QUIET
NASMFLAGS += -D AUTOKEY_QUIET
endif
# Long train of A presses — answer every <PROMPT>/button-wait a flow raises. Same
# forwarding gap as AUTOKEY_QUIET above: several dedicated gates pass -D AUTOKEY_APRESS
# themselves, but it could not be reached from a generic DEBUG_AUTOKEY build.
# make DEBUG_AUTOKEY=1 AUTOKEY_APRESS=1 [AUTOKEY_APRESS_COUNT=n] [AUTOKEY_DUMP_FRAME=n]
ifdef AUTOKEY_APRESS
NASMFLAGS += -D AUTOKEY_APRESS
endif
ifdef AUTOKEY_APRESS_COUNT
NASMFLAGS += -D AUTOKEY_APRESS_COUNT=$(AUTOKEY_APRESS_COUNT)
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
# Full-boot continue-from-save walk (Oak cutscene repro): keeps the title
# screen (see the SKIP_TITLE exemption below, shared with AUTOKEY_TITLE).
#   make DEBUG_AUTOKEY=1 AUTOKEY_CONTINUE_WALK=1 AUTOKEY_NO_PARTY=1 AUTOKEY_DUMP_FRAME=1100
ifdef AUTOKEY_CONTINUE_WALK
NASMFLAGS += -D AUTOKEY_CONTINUE_WALK
endif
ifdef AK_CONTINUE_MENU_FIRST
NASMFLAGS += -D AK_CONTINUE_MENU_FIRST
endif
# overworld-events Stage 4 Fly must-hit: drive START -> POKéMON -> SNORLAX -> FLY ->
# Town Map -> destination, then let OverworldLoop warp+arrive. Dump defaults to 900
# (well past arrival). make DEBUG_AUTOKEY=1 AUTOKEY_FLY=1 [AUTOKEY_DUMP_FRAME=n]
ifdef AUTOKEY_FLY
NASMFLAGS += -D AUTOKEY_FLY
AUTOKEY_DUMP_FRAME ?= 900
endif
ifdef AUTOKEY_DOWNS
NASMFLAGS += -D AUTOKEY_DOWNS=$(AUTOKEY_DOWNS)
endif
# M-120 class: this was a hardcoded `-D AUTOKEY_DUMP_FRAME=160` that ignored the
# value the caller (or an AUTOKEY_* block above) set. Forward the real value, so
# AUTOKEY_FLY's post-arrival default of 900 — and any command-line override — takes.
ifdef AUTOKEY_DUMP_FRAME
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
endif
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_AUTOKEY
# AUTOKEY_NO_PARTY=1 skips the party seed so the autokey run matches a plain
# DEBUG_START_MAP build (which seeds no party) byte-for-byte on game state.
ifndef AUTOKEY_NO_PARTY
NASMFLAGS += -D DEBUG_SEED_PARTY
endif
ifndef AUTOKEY_TITLE
ifndef AUTOKEY_CONTINUE_WALK
NASMFLAGS += -D SKIP_TITLE
endif
endif
endif
# PLAYABLE trainer battle: the DEBUG_TRAINER_ROUTE spawn + seed (Route 3, in
# ROUTE3_YOUNGSTER1's sight, party seeded by RunTrainerRouteTestSeed) with NO
# autokey and NO frame dump, so the keyboard drives it. Use this to pilot a
# trainer battle by hand.
#   dos_port/run TRAINER_ROUTE_PILOT=1
#
# THIS BLOCK MUST STAY OUTSIDE `ifdef DEBUG_AUTOKEY` (which closes just above).
# It was added INSIDE it (aaea024e) and was therefore SILENTLY IGNORED unless
# DEBUG_AUTOKEY happened to be set as well -- the whole point of the gate is that
# it has no autokey. Measured 2026-08-06: the build stamp carried none of the
# three defines and the run booted to a default Pallet Town with no party, which
# reads as "the harness spawned me somewhere odd", not as "the flag did nothing".
# Same failure mode as the AUTOKEY_QUIET/AUTOKEY_APRESS forwarding gaps the same
# commit fixed.
ifdef TRAINER_ROUTE_PILOT
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_TRAINER_ROUTE -D DEBUG_SEED_PARTY -D SKIP_TITLE
endif
# Pilot spawn clear of every Route 3 sight line (debugger-attach aid: the normal
# spawn engages trainer 0 before a breakpoint can be armed).
#   dos_port/run TRAINER_ROUTE_PILOT=1 PILOT_NEUTRAL=1
# MUST stay above the NASMFLAGS stamp machinery (bottom of this file): the stamp
# is $(file)-written at PARSE time, so an append placed after it is invisible to
# the stamp — toggling the flag then rebuilds NOTHING and ships a stale spawn.
# Measured 2026-08-06: the block sat after `clean:` and the built EXE carried no
# -D PILOT_NEUTRAL while the maintainer spawned at the default in-sight tile.
ifdef PILOT_NEUTRAL
NASMFLAGS += -D PILOT_NEUTRAL
endif
# Party-menu gate: seed the party, open the POKéMON screen over the overworld,
# render one frame, dump FRAME.BIN, exit. make DEBUG_PARTYMENU=1
$(eval $(call dump_gate,DEBUG_PARTYMENU))
# Text-box gate (menus S2): boot to overworld, switch to the flat canvas, draw
# the DisplayTextBoxID box with the given wTextBoxID, dump FRAME.BIN, exit.
# make DEBUG_TEXTBOXID=<id>  (id = hex/dec NASM literal, e.g. 0x01, 0x13)
# Text-engine oracle (docs/plans/text_engine.md Stage 0): run ONE probe
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
$(eval $(call dump_gate,DEBUG_DRAWBADGES))
# Trainer-card gate (menus S9): boot to overworld, seed name/money/time/badges,
# draw the full TRAINER CARD (DrawTrainerInfo + DrawBadges + pic), composite it,
# dump FRAME.BIN, exit. make SKIP_TITLE=1 DEBUG_TRAINERCARD=1
$(eval $(call dump_gate,DEBUG_TRAINERCARD))
# Cinematic projection/clipping/wrap marker harness (menu-intro A1.6). Builds the
# synthetic marker surface, applies MARKER_SX/MARKER_SY as fine source offsets,
# dumps FRAME.BIN, exits. This is the ONLY evidence that distinguishes correct
# GB mod-256 wrap sampling from a linear read — a register trace cannot, because
# it logs the value the game wrote, not the pixel the renderer sampled.
#   make image DEBUG_CINEMATIC_MARKERS=1 MARKER_SX=252
ifdef DEBUG_CINEMATIC_MARKERS
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_CINEMATIC_MARKERS
NASMFLAGS += -D SKIP_TITLE
NASMFLAGS += -D MARKER_SX=$(or $(MARKER_SX),0)
NASMFLAGS += -D MARKER_SY=$(or $(MARKER_SY),0)
endif
# Projected-title pixel gate (menu-intro A2.3/A2.6). Deliberately does NOT set
# SKIP_TITLE: the whole point is to boot the real title through the full bounce
# and photograph the stable checkpoint at .loop. GBSTATE goldens cannot observe
# any of this — they compare GB memory, and the projection lives in the
# compositor — so FRAME.BIN is the only binding evidence that the surface is
# centred, the matte is clean and the tilemap reached VRAM.
#   make image DEBUG_TITLE=1
# TITLE_DUMP_FRAME=0 (default) photographs the stable checkpoint; TITLE_DUMP_FRAME=N
# photographs the Nth frame of the logo bounce instead. The mid-bounce frames are
# the ONLY ones that can evidence pret's bounce window (hWY=64) — by the
# checkpoint pret has parked it off-screen again.
# main_menu scenario (A3): boot the REAL title, latch START at its idle loop so
# the genuine .go_to_main_menu exit runs, then photograph MainMenu with the box
# drawn and no input consumed. Deliberately no SKIP_TITLE — the routing is part
# of what this evidences.
#   make image DEBUG_MAINMENU_LIVE=1
ifdef DEBUG_MAINMENU_LIVE
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_MAINMENU_LIVE
NASMFLAGS += -D SKIP_INTRO       # B4 flip: boot the real title/menu, skip the boot cinematic
endif
# title_reentry scenario (A3): boot the real title, latch START -> MainMenu,
# B-cancel back to DisplayTitleScreen, dump the checkpoint on the 2nd visit.
# Proves the title round trip leaks no compositor state. make DEBUG_TITLE_REENTRY=1
ifdef DEBUG_TITLE_REENTRY
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_TITLE_REENTRY
NASMFLAGS += -D SKIP_INTRO       # B4 flip: boot the real title, skip the boot cinematic
endif
# title_timeout scenario (menu-intro B4): prove the title-screen timeout replays the
# boot movie (post-flip: title timeout -> jmp Init -> PlayIntro). Deliberately does NOT
# set SKIP_INTRO — the intro must play (to reach the title) and REPLAY (after the
# shortened timeout); PlayShootingStar dumps the replayed copyright via g_title_reset_replay.
ifdef DEBUG_TITLE_TIMEOUT
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_TITLE_TIMEOUT
endif
# soft_reset scenario (menu-intro B4): prove the title UP+SELECT+B reset-save combo
# replays the boot movie (post-flip: combo -> jmp Init -> PlayIntro). Like title_timeout,
# does NOT set SKIP_INTRO (intro plays to reach the title, then replays); the title
# latches the combo and PlayShootingStar dumps the replay via g_title_reset_replay.
ifdef DEBUG_SOFT_RESET
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_SOFT_RESET
endif
ifdef DEBUG_TITLE
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_TITLE
# menu-intro B4 flip: PlayIntro now runs on every normal boot; this piece-test boots
# the real title and must land on it immediately, so skip the ~20 s boot cinematic.
NASMFLAGS += -D SKIP_INTRO
NASMFLAGS += -D TITLE_DUMP_FRAME=$(or $(TITLE_DUMP_FRAME),0)
NASMFLAGS += -D TITLE_DUMP_SCENE=$(or $(TITLE_DUMP_SCENE),0)
NASMFLAGS += -D TITLE_DUMP_LOOP=$(or $(TITLE_DUMP_LOOP),0)
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
# Default: no presses, photograph the open TurnedOnPC1Text dialog at frame 90.
# PC_APRESS=1 swaps in the A-press train so the flow advances past the dialog —
# how the real DisplayPCMainMenu box gets photographed (it is drawn only after
# the prompt is answered). AUTOKEY_DUMP_FRAME is overridable (M-120 class: the
# hardcoded -D beat the command line here too).
ifdef PC_APRESS
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_APRESS
else
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_QUIET
endif
AUTOKEY_DUMP_FRAME ?= 90
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
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
# Hall of Fame gate: boot to the overworld with a seeded party, then run the real
# AnimateHallOfFame ceremony and photograph it. No golden scenario reaches the Hall
# of Fame (it is behind the Champion), so this is its only runtime evidence.
# make DEBUG_HOF=1 [AUTOKEY_DUMP_FRAME=<n>]   — the ceremony is minutes long, so the
# frame number chooses which moment you get; ~110 lands on the first mon's info box.
ifdef DEBUG_HOF
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_HOF -D DEBUG_SEED_PARTY -D SKIP_TITLE
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_QUIET
AUTOKEY_DUMP_FRAME ?= 260
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
endif
# Credits gate: boot to the overworld, then run the real Credits roll (skipping the
# Hall of Fame ceremony HallOfFamePC would play first) and photograph it. No golden
# scenario reaches the credits — they are behind the Hall of Fame, behind the
# Champion — so this is their only runtime evidence.
# make DEBUG_CREDITS=1 [AUTOKEY_DUMP_FRAME=<n>]
ifdef DEBUG_CREDITS
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_CREDITS -D SKIP_TITLE
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_QUIET
AUTOKEY_DUMP_FRAME ?= 200
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
endif
# Options gate (menus S6 package D): boot to overworld, open the OPTION menu via
# InitOptionsMenu (full-screen takeover), draw the cursor, dump FRAME.BIN, exit.
# make SKIP_TITLE=1 DEBUG_OPTIONS=1
$(eval $(call dump_gate,DEBUG_OPTIONS))
# Player's-PC gate (menus S6 package F): boot to overworld, seed party+bag+box,
# open PlayerPC as a generic PC; the parent-menu hook dumps FRAME.BIN, exits.
# make SKIP_TITLE=1 DEBUG_PLAYERSPC=1
$(eval $(call dump_gate,DEBUG_PLAYERSPC))
# Main-menu gate (menus S7 package E): boot to overworld, seed a save (party +
# name/badges/dex/time + DsvWriteSave), draw the CONTINUE/NEW GAME box + info
# panel, dump FRAME.BIN, exit. make SKIP_TITLE=1 DEBUG_MAINMENU=1
$(eval $(call dump_gate,DEBUG_MAINMENU))
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
# continue_seed gate (menu-intro A3): seed a deterministic save, clobber the live
# save WRAM, load it back via TryLoadSaveFile (the CONTINUE load), dump GBSTATE.
# make image DEBUG_CONTINUE_SEED=1
$(eval $(call dump_gate,DEBUG_CONTINUE_SEED))
# save_real_load gate: boot loads a REAL cartridge .sav staged as POKEMON.DSV by
# goldencheck.sh, then the gate clobbers the live save WRAM and reloads it via
# TryLoadSaveFile. Unlike continue_seed the data originates outside the port, so
# this catches offset/byte-order errors a self-round-trip cannot.
# make image DEBUG_REAL_SAVE=1
$(eval $(call dump_gate,DEBUG_REAL_SAVE))
# save_boxes_load gate: as DEBUG_REAL_SAVE, but the staged save has all 12 PC
# boxes full and the dump carries a SCENARIO-LOCAL wBoxData region (the current
# box block), which no other scenario compares. make image DEBUG_BOX_SAVE=1
$(eval $(call dump_gate,DEBUG_BOX_SAVE))
# Oak-pic pixel harness (menu-intro A4.1): display Prof. Oak on the centred
# cinematic surface and dump FRAME.BIN. make image DEBUG_OAKPIC=1
$(eval $(call dump_gate,DEBUG_OAKPIC))
# oak_intro checkpoint harness (menu-intro A4.3/A4.5): drive Oak pic + fade +
# PrintText(OakSpeechText1) into the surface canvas (msgbox_oak_speech), letting the
# text type page 1 and park at the <PARA> ▼-wait, then AUTOKEY_QUIET photographs the
# parked frame at AUTOKEY_DUMP_FRAME (default 260 — after page 1 is fully typed).
# make image DEBUG_OAKINTRO=1 [AUTOKEY_DUMP_FRAME=260]
ifdef DEBUG_OAKINTRO
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_OAKINTRO
NASMFLAGS += -D SKIP_TITLE
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_QUIET
AUTOKEY_DUMP_FRAME ?= 360
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
endif
# name-select menu harness (menu-intro A4.4): draw the projected default-name menu
# (DisplayIntroNameTextBox) on the cinematic surface and let HandleMenuInput park;
# AUTOKEY_QUIET photographs it at AUTOKEY_DUMP_FRAME. make image DEBUG_NAMEMENU=1
ifdef DEBUG_NAMEMENU
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_NAMEMENU
NASMFLAGS += -D SKIP_TITLE
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_QUIET
AUTOKEY_DUMP_FRAME ?= 120
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
endif
# picture-slide harness (menu-intro A4.4): display Oak, slide the pic right
# (OakSpeechSlidePicRight); AUTOKEY_QUIET photographs at AUTOKEY_DUMP_FRAME (low =
# pre-slide centred, high = slid). make image DEBUG_OAKSLIDE=1 AUTOKEY_DUMP_FRAME=N
ifdef DEBUG_OAKSLIDE
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_OAKSLIDE
NASMFLAGS += -D SKIP_TITLE
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_QUIET
AUTOKEY_DUMP_FRAME ?= 120
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
endif
# Game Freak splash harness (menu-intro B2): establish the surface, load the logo,
# run AnimateShootingStar; AUTOKEY_QUIET photographs a frame at AUTOKEY_DUMP_FRAME.
# make image DEBUG_CINEMATIC_SPLASH=1 AUTOKEY_DUMP_FRAME=N
ifdef DEBUG_CINEMATIC_SPLASH
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_CINEMATIC_SPLASH
NASMFLAGS += -D SKIP_TITLE
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_QUIET
AUTOKEY_DUMP_FRAME ?= 20
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
endif
# Boot-cinematic wiring harness (menu-intro B4): boot the REAL Init chain (NO
# SKIP_TITLE) with the gated `call PlayIntro` enabled, so PlayIntro runs from Init
# (Init -> PlayIntro splash+intro -> title). AUTOKEY_QUIET photographs a frame at
# AUTOKEY_DUMP_FRAME (~50 = the copyright screen, proving PlayIntro runs from Init).
# make image BOOT_CINEMATIC=1 AUTOKEY_DUMP_FRAME=N
# gamefreak_intro golden scenario (menu-intro B4): the real-boot copyright screen.
# A DEBUG_-prefixed gate (validate_scenarios requires it; it also tags the GBSTATE
# dump id via the generated scenario_registry.inc) that turns on the BOOT_CINEMATIC
# real-boot build below. Must precede the BOOT_CINEMATIC block so the `ifdef` sees it.
ifdef DEBUG_GAMEFREAK_INTRO
BOOT_CINEMATIC := 1
NASMFLAGS += -D DEBUG_GAMEFREAK_INTRO
endif
ifdef BOOT_CINEMATIC
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D BOOT_CINEMATIC
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_QUIET
AUTOKEY_DUMP_FRAME ?= 50
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
endif

# yellow_intro_s01 golden scenario (menu-intro B4): the Yellow intro's scene-1 hold.
# Real boot (-D BOOT_CINEMATIC so init.asm calls PlayIntro) but NO AUTOKEY — the
# state-triggered DumpBackbuffer hook in PlayIntroScene fires at scene-1 entry instead
# (frame-based dump can't align port↔ROM across the animated scenes). Uses -D (not the
# BOOT_CINEMATIC make var) so the AUTOKEY block above stays off.
ifdef DEBUG_YELLOW_S01
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D BOOT_CINEMATIC
NASMFLAGS += -D DEBUG_YELLOW_S01
endif
# Yellow scroll-evidence gate (menu-intro B3): dump FRAME.BIN/GBSTATE at a chosen scene +
# scene-timer, to photograph a SCROLLING scene at a specific hSCX. Two builds at two
# timers give the two-offset scroll pixel evidence.  make image YELLOW_DUMP_SCENE=7 YELLOW_DUMP_TIMER=38
ifdef YELLOW_DUMP_SCENE
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D BOOT_CINEMATIC
NASMFLAGS += -D YELLOW_DUMP_SCENE=$(YELLOW_DUMP_SCENE)
NASMFLAGS += -D YELLOW_DUMP_TIMER=$(or $(YELLOW_DUMP_TIMER),1)
endif
# Animated-object engine harness (menu-intro B1.3): establish the surface, stage
# the intro anim data, spawn one object, run RunObjectAnimations + publish OAM
# each frame; AUTOKEY_QUIET photographs a frame at AUTOKEY_DUMP_FRAME.
# make image DEBUG_CINEMATIC_ANIMOBJ=1 AUTOKEY_DUMP_FRAME=N
ifdef DEBUG_CINEMATIC_ANIMOBJ
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_CINEMATIC_ANIMOBJ
NASMFLAGS += -D SKIP_TITLE
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_QUIET
AUTOKEY_DUMP_FRAME ?= 30
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
endif
# Full Yellow-intro harness (menu-intro B3.2d): PlayIntroScene plays the 9 ported
# scenes (animated OBJ projected via UI_YELLOW_INTRO) + 9 auto-advance scaffolds.
# make image DEBUG_CINEMATIC_YELLOW=1 AUTOKEY_DUMP_FRAME=N
ifdef DEBUG_CINEMATIC_YELLOW
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_CINEMATIC_YELLOW
NASMFLAGS += -D SKIP_TITLE
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_QUIET
AUTOKEY_DUMP_FRAME ?= 40
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
endif
# name-selection end-to-end harness (menu-intro A4.5f): show the player pic, run
# ChoosePlayerName; AUTOKEY_CHOOSENAME taps DOWN+A to pick a default name (YELLOW),
# then photographs the "YOUR NAME IS ..." result. make image DEBUG_CHOOSENAME=1
ifdef DEBUG_CHOOSENAME
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_CHOOSENAME
NASMFLAGS += -D SKIP_TITLE
NASMFLAGS += -D DEBUG_AUTOKEY
ifdef CHOOSENAME_CUSTOM
# custom path: A -> naming screen -> enter a letter -> START submit -> re-establish
NASMFLAGS += -D AUTOKEY_CHOOSENAME_CUSTOM
AUTOKEY_DUMP_FRAME ?= 320
else
NASMFLAGS += -D AUTOKEY_CHOOSENAME
AUTOKEY_DUMP_FRAME ?= 260
endif
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
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
$(eval $(call dump_gate,DEBUG_NAMINGSCREEN))
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
$(eval $(call dump_gate,DEBUG_I2))
# Link-cable Stage 2: net_frame codec/ARQ RAM-pipe unit test (src/net/net_test.asm).
$(eval $(call dump_gate,DEBUG_NETTEST))
# Link-cable Stage 2 step 5: the two-instance nullmodem harness gate
# (tools/linkcheck.sh). RunLinkCheck loops the real CableClubNPC against the
# peer; AUTOKEY_LINKCHECK's A train answers the receptionist prompts and stops
# at LinkMenu entry (linkcheck_in_menu), where both instances park; the
# photograph at AUTOKEY_DUMP_FRAME writes GBSTATE/FRAME/PAL (+LINKLOG.BIN when
# the game runs with /LINKLOG) for the script's role/exchange-log assertions.
# 3600 default: late enough for a several-second boot stagger between the two
# instances plus the retry loop, well inside linkcheck.sh's run timeout.
ifdef DEBUG_LINKCHECK
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_LINKCHECK
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_LINKCHECK
AUTOKEY_DUMP_FRAME ?= 3600
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
# Parked-in-LinkMenu frames before the protocol-synchronized photograph
# (debug_dump.asm defaults it to 900; AUTOKEY_DUMP_FRAME stays the ceiling
# for runs that never reach the menu).
ifdef LINKCHECK_MENU_HOLD
NASMFLAGS += -D LINKCHECK_MENU_HOLD=$(LINKCHECK_MENU_HOLD)
endif
NASMFLAGS += -D SKIP_TITLE
endif
# Link-cable Stage 3 step 5: the two-instance trade harness gate
# (tools/tradecheck.sh). Clone of DEBUG_LINKCHECK: RunTradeCheck loops the real
# CableClubNPC against the peer exactly like RunLinkCheck, but AUTOKEY_TRADECHECK
# does NOT strip A at LinkMenu — it presses through the default TRADE CENTER
# selection, drives the one-tile walk to the role's table gameboy
# (CableClubLeftGameboy/RightGameboy, assets/hidden_events.inc), then both
# rounds of the trade-center menu (round 1: both sides pick party slot 0 and
# confirm; round 2: both sides navigate to CANCEL and confirm). AUTOKEY_DUMP_FRAME
# is far larger than linkcheck's: on top of the same rendezvous-skew retry loop,
# the harness also waits out the real trade animation and two full menu rounds.
# 14000 is a generous starting point (docs/current_plan_link_cable.md step 5) —
# tune against a real run once the maintainer's end-of-plan battery executes it.
# make DEBUG_TRADECHECK=1
ifdef DEBUG_TRADECHECK
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_TRADECHECK
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_TRADECHECK
AUTOKEY_DUMP_FRAME ?= 14000
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
NASMFLAGS += -D SKIP_TITLE
endif
# Link-cable Stage 4 step 3: the two-instance link BATTLE harness gate
# (tools/battlecheck.sh). Clone of DEBUG_TRADECHECK: RunBattleCheck loops the
# real CableClubNPC against the peer exactly like RunTradeCheck.
# AUTOKEY_BATTLECHECK carries two live-WRAM gates (debug_dump.asm): one DOWN
# strobe with A suppressed at LinkMenu to move the default cursor off item 0
# (TRADE CENTER) onto item 1 (COLOSSEUM), and the one-tile walk to the role's
# table gameboy — once COLOSSEUM is confirmed, the walk lands the player on
# CableClubLeftGameboy/RightGameboy (bills_pc.asm), which arms
# LINK_STATE_START_BATTLE and, via CableClub_Run's predef dispatch
# (home/joypad2.asm -> engine/link/cable_club.asm:CableClub_Run ->
# CableClub_DoBattleOrTrade -> DoBattleOrTradeAgain), runs the ENTIRE battle
# synchronously inside `predef InitOpponent` (InitBattleCommon's own
# `callfar StartBattle` / `callfar EndOfBattle`, engine/battle/init_battle.asm)
# before CableClub_Run's caller ever resumes — so a bare A-train that answers
# every prompt AND drives FIGHT/move-1 every turn is sufficient (see
# AUTOKEY_BATTLECHECK's header comment in debug_dump.asm for the full
# citation trace). AUTOKEY_DUMP_FRAME is larger than tradecheck's own 14000:
# on top of the same rendezvous-skew retry loop and the walk, a full link
# battle (turn-by-turn menu redraws, HP-bar animation, faint/switch handling)
# runs longer than a trade's two menu rounds. 20000 is a generous starting
# point (docs/current_plan_link_cable.md Stage 4 step 3) — unvalidated until
# the maintainer's end-of-plan dynamic battery runs it (this implementer's
# checks are static only, per that plan's directive).
# make DEBUG_BATTLECHECK=1
ifdef DEBUG_BATTLECHECK
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_BATTLECHECK
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_BATTLECHECK
AUTOKEY_DUMP_FRAME ?= 20000
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
NASMFLAGS += -D SKIP_TITLE
endif
# Link-receptionist no-link golden (cable_club_nolink — link cable plan Stage 2
# step 4): spawn on the Pewter Pokecenter talk tile facing the link receptionist
# (`object_event 11, 2, SPRITE_LINK_RECEPTIONIST, STAY, DOWN`; the player stands
# at y=3, x=11 facing UP — open floor per PewterPokecenter.blk decoded through
# Pokecenter_Coll), seed EVENT_GOT_POKEDEX, and let AUTOKEY_APRESS drive a REAL
# A press through OverworldLoop -> IsSpriteOrSignInFrontOfPlayer ->
# CheckNPCInteraction -> the generated SCRIPT entry ->
# CableClubReceptionistScript -> CableClubNPC. With no /COM1 there is no net
# session, the 90-frame establishment race expires, AUTOKEY_APRESS answers the
# failure text's two `cont` page waits, and the shim's DEBUG_CABLECLUB hook
# photographs the moment CableClubNPC returns (last page still on screen).
# make DEBUG_CABLECLUB=1
ifdef DEBUG_CABLECLUB
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_CABLECLUB
NASMFLAGS += -D SKIP_TITLE
CABLECLUB_MAP ?= 0x3A
CABLECLUB_Y   ?= 3
CABLECLUB_X   ?= 11
CABLECLUB_DIR ?= SPRITE_FACING_UP
NASMFLAGS += -D CABLECLUB_MAP=$(CABLECLUB_MAP) -D CABLECLUB_Y=$(CABLECLUB_Y) \
             -D CABLECLUB_X=$(CABLECLUB_X) -D CABLECLUB_DIR=$(CABLECLUB_DIR)
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_APRESS
# The gate dumps itself (the shim hook); keep AutoKeyDrive's own dump away.
AUTOKEY_DUMP_FRAME ?= 999999
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
endif
# Link-cable Stage 5 step 5, Deliverable 2: the single-instance connection-book
# persistence harness gate (tools/linkbookcheck.sh; `link_book_roundtrip` in
# tools/scenario_manifest.json, scenario_class "port_only" -- no ROM ground
# truth, so this is asserted directly against GBSTATE.BIN + LINKBOOK.DAT, not
# through goldencheck). UNLIKE DEBUG_LINKCHECK/TRADECHECK/BATTLECHECK above,
# there is NO nullmodem cable and no /COM1: RunLinkBookCheck (src/engine/
# link/cable_club_npc.asm) calls the real CableClubNPC exactly once, and with
# g_net_transport left at NET_TRANSPORT_NONE its LinkTransportSelect call
# opens the port-only transport-select/connection-book UI (src/net/link_ui.asm)
# instead of racing an establishment window against a peer. AUTOKEY_LINKBOOKCHECK
# (debug_dump.asm's AutoKeyDrive) drives pad-level menu navigation, phase-gated
# off live WRAM state; AUTOKEY_KBDSCRIPT drives the NAME?/ADDRESS? fields via a
# scripted (scancode,shift) table pushed through the new kbd_ring_push
# (src/input/joypad.asm) -- the same scancode-injection mechanism
# DEBUG_KBDNAMECHECK below shares.
#
# LBC_PHASE2 selects the SECOND run's navigation + typing script (EDIT the TCP
# entry's name, DELETE the IPX entry) instead of the first run's (NEW both);
# tools/linkbookcheck.sh builds this SAME gate twice, once per run, per its own
# header -- the underlying scenario/GBSTATE id stays DEBUG_LINKBOOKCHECK
# either way, LBC_PHASE2 only swaps which AUTOKEY_LINKBOOKCHECK[_PHASE2]
# navigation state machine and which kbdscript_table variant compile in.
#
# 3000 is an unmeasured starting point -- this implementer's checks are static
# only per the plan's directive (no DOSBox-X run happened here); tune against
# a real run once the maintainer's end-of-plan dynamic battery executes it.
# make DEBUG_LINKBOOKCHECK=1  [LBC_PHASE2=1]
ifdef DEBUG_LINKBOOKCHECK
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_LINKBOOKCHECK
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_LINKBOOKCHECK -D AUTOKEY_KBDSCRIPT
AUTOKEY_DUMP_FRAME ?= 3000
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
NASMFLAGS += -D SKIP_TITLE
ifdef LBC_PHASE2
NASMFLAGS += -D AUTOKEY_LINKBOOKCHECK_PHASE2
endif
endif
# Link-cable Stage 5 step 5, Deliverable 3: the KBD_NAMING naming-screen
# scancode-injection gate (tools/kbdnamecheck.sh; `kbd_naming_entry` in
# tools/scenario_manifest.json, scenario_class "port_only"). Requires
# KBD_NAMING=1 -- naming_screen.asm %errors at assemble time otherwise (see
# RunKbdNameCheckTest's header). RunKbdNameCheckTest clones
# RunNamingScreenTest's identity seed but then calls the REAL (blocking)
# DisplayNamingScreen instead of drawing the letter grid by hand, so this
# gate's scripted "Ab" + Tab (opens the picker) + Enter (picks index 0) +
# Enter (submits) sequence -- pushed through the SAME AUTOKEY_KBDSCRIPT
# mechanism DEBUG_LINKBOOKCHECK above shares -- actually drives the KBD_NAMING
# input path (%if KBD_NAMING in naming_screen.asm) end to end.
# AUTOKEY_QUIET: no pad presses at all -- kbd_text.asm/DisplayNamingScreen's
# KBD_NAMING branch reads only the keyboard ring, never pad state, so this
# scenario needs none of AUTOKEY_LINKBOOKCHECK's menu-navigation gate.
# 600 is an unmeasured starting point, same caveat as DEBUG_LINKBOOKCHECK's own.
# make KBD_NAMING=1 DEBUG_KBDNAMECHECK=1
ifdef DEBUG_KBDNAMECHECK
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_KBDNAMECHECK
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_QUIET -D AUTOKEY_KBDSCRIPT -D AUTOKEY_KBDNAMECHECK
AUTOKEY_DUMP_FRAME ?= 600
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
NASMFLAGS += -D SKIP_TITLE
endif
# in_game_trade golden (link cable plan Stage 3 step 4 — the trade.asm fidelity
# anchor): the Route 2 Trade House CLEFAIRY -> MR_MIME "MILES" trade
# (data/events/trades.asm index 1, TRADE_FOR_MILES; scripts/Route2TradeHouse.asm's
# GAMEBOY_KID). Same spawn shape as DEBUG_CABLECLUB: spawn beside
# `object_event 4, 1, SPRITE_GAMEBOY_KID, STAY, DOWN`
# (data/maps/objects/Route2TradeHouse.asm) at tile (y=2,x=4) facing UP — one
# tile south of the NPC, the standard shop-counter arrangement (matches every
# Mart/PC clerk in the game). DEBUG_SEED_PARTY seeds the debug party with ONE
# row swapped under DEBUG_TRADE_GOLDEN (JIGGLYPUFF -> CLEFAIRY, same slot —
# src/engine/debug/debug_party.asm), so the give-species is present. The whole
# dialogue/menu flow (WannaTrade1Text, the YES/NO confirm — cursor defaults
# YES, home/yes_no.asm — the party-menu CLEFAIRY pick, ConnectCableText,
# InternalClockTradeAnim, TradedForText/Thanks1Text) advances on a periodic A
# train (AUTOKEY_TRADE_GOLDEN, cloned from AUTOKEY_LINKCHECK/TRADECHECK's
# shape) plus a state-gated party-menu DOWN climb to CLEFAIRY's slot
# (debug_dump.asm's .apply, same rule as AUTOKEY_TRADECHECK's ROUND2
# DOWN-to-CANCEL gate). The dump itself is STATE-GATED, not frame-gated: the
# shim hook in src/scripts/Route2TradeHouse.asm fires the instant
# DoInGameTradeDialogue returns — which, because its tail is a `jp PrintText`
# into the LAST dialog box, is exactly "the closing dialog is dismissed, a
# stable idle overworld frame" (spec step 5). AUTOKEY_DUMP_FRAME is therefore
# only AutoKeyDrive's OWN fallback ceiling if that hook never fires (flow
# stall), same role DEBUG_CABLECLUB gives it — SPEC DEVIATION from "start 3600
# and measure": the DOSBox-side dynamic run that would measure a fixed frame
# is deferred (maintainer directive 2026-08-23), and a state gate needs no
# such measurement to be correct.
# make DEBUG_TRADE_GOLDEN=1
ifdef DEBUG_TRADE_GOLDEN
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_TRADE_GOLDEN
NASMFLAGS += -D SKIP_TITLE
NASMFLAGS += -D DEBUG_SEED_PARTY
TRADE_GOLDEN_MAP ?= 0x30
TRADE_GOLDEN_Y   ?= 2
TRADE_GOLDEN_X   ?= 4
TRADE_GOLDEN_DIR ?= SPRITE_FACING_UP
NASMFLAGS += -D TRADE_GOLDEN_MAP=$(TRADE_GOLDEN_MAP) -D TRADE_GOLDEN_Y=$(TRADE_GOLDEN_Y) \
             -D TRADE_GOLDEN_X=$(TRADE_GOLDEN_X) -D TRADE_GOLDEN_DIR=$(TRADE_GOLDEN_DIR)
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_TRADE_GOLDEN
AUTOKEY_DUMP_FRAME ?= 999999
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
endif
# print_surf_cancel golden (printer plan Stage 3): spawn in Summer Beach House
# facing the printer; AUTOKEY_APRESS answers dialogs and YES/NO choices, and B cancels printing.
# make DEBUG_PRINT_SURF_CANCEL=1
ifdef DEBUG_PRINT_SURF_CANCEL
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_PRINT_SURF_CANCEL
NASMFLAGS += -D SKIP_TITLE
NASMFLAGS += -D DEBUG_SEED_PARTY
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_APRESS
AUTOKEY_DUMP_FRAME ?= 999999
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
endif
# print_beach_house port-only print golden (printer plan Stage 4):
# make DEBUG_PRINT_BEACH_HOUSE=1
ifdef DEBUG_PRINT_BEACH_HOUSE
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_PRINT_BEACH_HOUSE -D DEBUG_PRINT_SURF_CANCEL
NASMFLAGS += -D SKIP_TITLE
NASMFLAGS += -D DEBUG_SEED_PARTY
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_APRESS
AUTOKEY_DUMP_FRAME ?= 999999
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
endif
# pokecenter_heal golden:
# make DEBUG_POKECENTER_HEAL=1
ifdef DEBUG_POKECENTER_HEAL
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_POKECENTER_HEAL
NASMFLAGS += -D SKIP_TITLE
NASMFLAGS += -D DEBUG_SEED_PARTY
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_POKECENTER_HEAL
AUTOKEY_DUMP_FRAME ?= 999999
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
endif
# vending_machine golden:
# make DEBUG_VENDING=1
ifdef DEBUG_VENDING
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_VENDING
NASMFLAGS += -D SKIP_TITLE
NASMFLAGS += -D DEBUG_SEED_PARTY
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_VENDING
AUTOKEY_DUMP_FRAME ?= 999999
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
endif
# prize_corner golden:
# make DEBUG_PRIZE_CORNER=1
ifdef DEBUG_PRIZE_CORNER
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_PRIZE_CORNER
NASMFLAGS += -D SKIP_TITLE
NASMFLAGS += -D DEBUG_SEED_PARTY
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_PRIZE_CORNER
AUTOKEY_DUMP_FRAME ?= 999999
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
endif
# pokemart_buy_sell golden:
# make DEBUG_POKEMART=1
ifdef DEBUG_POKEMART
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_POKEMART
NASMFLAGS += -D SKIP_TITLE
NASMFLAGS += -D DEBUG_SEED_PARTY
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_POKEMART
AUTOKEY_DUMP_FRAME ?= 999999
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
endif
# Battle golden gate (fidelity plan Stage 2): the REAL loaders (InitBattle →
# LoadEnemyMonData → LoadBattleMonFromParty) + the convergence-spec DV overwrite
# replace DEBUG_BATTLE's synthetic seed. Combine with DEBUG_BATTLE_INTRO /
# DEBUG_BATTLE_MENU / DEBUG_MOVEMENU to pick the dump point (the goldens are
# battle_intro / battle_menu / move_selection).
$(eval $(call battle_gate,DEBUG_BATTLE_GOLDEN))
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
# battle_low_hp (battle plan, 2026-08-13): the battle menu with the player's mon
# seeded to 20/362 HP -- inside GetHealthBarColor's RED band and still ALIVE.
# It is the only scenario that can observe wLowHealthAlarm SET: the bit is armed
# by DrawPlayerHUDAndHPBar's tail and cleared the instant the mon faints, and
# every other dump point is post-faint.
#   dos_port/tools/run_headless.sh "DEBUG_BATTLE_LOWHP=1" /tmp/lowhp
ifdef DEBUG_BATTLE_LOWHP
DEBUG_BATTLE := 1
NASMFLAGS += -D DEBUG_BATTLE_LOWHP
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_QUIET
AUTOKEY_DUMP_FRAME ?= 30
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
endif
# battle_short_nick: the same FIGHT menu, with party slot 0 renamed to a FOUR
# letter species name (ABRA, read from the generated MonsterNames table). It is
# the only scenario that leaves CenterMonName's UNSHIFTED bucket: every other
# battle mon is named 5+ characters, so the routine could be deleted and nothing
# in the suite would notice.
#   dos_port/tools/run_headless.sh "DEBUG_BATTLE_SHORTNICK=1" /tmp/shortnick
ifdef DEBUG_BATTLE_SHORTNICK
DEBUG_BATTLE := 1
NASMFLAGS += -D DEBUG_BATTLE_SHORTNICK
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_QUIET
AUTOKEY_DUMP_FRAME ?= 30
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
endif
# Live battle view: same setup as DEBUG_BATTLE but holds the screen (loops
# DelayFrame) so you can visually inspect it instead of dumping+exiting. Esc quits.
# make DEBUG_BATTLE_LIVE=1 (then dos_port/run).
$(eval $(call battle_gate,DEBUG_BATTLE_LIVE))
# Scripted enemy-hit ground-truth (Stage 2b): run one enemy attack with no input
# waits, then dump battle WRAM to DUMP.BIN. make DEBUG_BATTLE_ENEMYHIT=1
$(eval $(call battle_gate,DEBUG_BATTLE_ENEMYHIT))
# Battle intro screen dump (scene + "Wild <nick> appeared!", no menu) → FRAME.BIN.
# FRAME-DRIVEN since 2026-08-13, like DEBUG_BATTLE_MENU/SAFARI: the harness parks
# in a DelayFrame loop and AUTOKEY_QUIET photographs it at AUTOKEY_DUMP_FRAME.
# It was an INLINE dump, which cannot photograph a screen that blocks — and pret's
# intro box does block, on PrintBeginningBattleText's own prompt. Wiring that
# routine is unwitnessable until the dump is frame-driven (measured: the attempt
# TIMED OUT here with no dump while battle_menu/battle_safari compared normally).
ifdef DEBUG_BATTLE_INTRO
DEBUG_BATTLE := 1
NASMFLAGS += -D DEBUG_BATTLE_INTRO
NASMFLAGS += -D DEBUG_AUTOKEY -D AUTOKEY_QUIET
AUTOKEY_DUMP_FRAME ?= 30
NASMFLAGS += -D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)
endif
# Bug Catcher trainer test: seeds a trainer battle (enemy = trainer + ball row +
# party-status variety). Combine with DEBUG_BATTLE_INTRO (dump) or DEBUG_BATTLE_LIVE.
$(eval $(call battle_gate,DEBUG_BATTLE_TRAINER))
# Trainer initialization oracle: enter through StartTrainerBattle with Route 3's
# first BUG CATCHER and stop after the roster's first live mon is active.
ifdef DEBUG_TRAINER_INIT
DEBUG_BATTLE := 1
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_TRAINER_INIT -D SKIP_TITLE
endif
# Trainer terminal-state oracles: initialize Route 3's generated trainer party,
# drive one deterministic final turn, then exercise EndOfBattle + the map-script
# result consumer. These are deterministic state checkpoints, not the production
# route: they stand in for OverworldLoop's wCurOpponent poll by calling InitBattle
# directly, and stop before presentation and the interactive turn loop.
# (The -D TRAINER_BATTLE_LIVE these three blocks used to carry is GONE as of the
# Stage 1b reconciliation: trainer battles are live in the default build, entered
# by OverworldLoop's poll, and no %ifdef consumes that macro any more.)
ifdef DEBUG_TRAINER_WIN
DEBUG_BATTLE := 1
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_TRAINER_RESULT -D DEBUG_TRAINER_WIN -D SKIP_TITLE
endif
ifdef DEBUG_TRAINER_LOSS
DEBUG_BATTLE := 1
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_TRAINER_RESULT -D DEBUG_TRAINER_LOSS -D SKIP_TITLE
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
$(eval $(call dump_gate,DEBUG_BATTLE))
# Level-up move-learn gate (current_plan_pokemon_behavior Stage 3): force
# STARTER_PIKACHU (party slot 3) 5->6, call LearnMoveFromLevelUp directly (no
# battle/input needed), render one frame, dump FRAME.BIN, exit. make DEBUG_LEARNMOVE=1
$(eval $(call dump_gate,DEBUG_LEARNMOVE))
# Sub-flag of DEBUG_LEARNMOVE: fill all 4 move slots first, so the deferred
# all-slots-full (AbandonLearning) branch renders instead of the common path.
# make DEBUG_LEARNMOVE=1 DEBUG_LEARNMOVE_FULL=1
$(eval $(call flag_gate,DEBUG_LEARNMOVE_FULL))
# Status-screen gate: seed the party, open the status/summary screen (page 1) for
# STARTER_PIKACHU (party slot 3), render one frame, dump FRAME.BIN, exit.
# make DEBUG_STATUS=1
# Sub-flag of DEBUG_STATUS: render summary-screen page 2 (moves/PP/EXP) instead of
# page 1. make DEBUG_STATUS=1 DEBUG_STATUS_PAGE2=1  (implies DEBUG_STATUS)
ifdef DEBUG_STATUS_PAGE2
DEBUG_STATUS := 1
NASMFLAGS += -D DEBUG_STATUS_PAGE2
endif
$(eval $(call dump_gate,DEBUG_STATUS))
# pikapic (follower-Pikachu front-pic facial animation, phase 4) runtime witness:
# seed a valid party (PrepareNewGameDebug), then drive the same presentation
# choreography StarterPikachuEmotionCommand_pikapic runs
# (pikapic_window_enter -> PlacePikapicTextBoxBorder ->
# LoadOverworldPikachuFrontpicPalettes -> ResetPikaPicAnimBuffer ->
# LoadCurrentPikaPicAnimScriptPointer -> ExecutePikaPicAnimScript) directly from
# the harness rather than through StarterPikachuEmotionCommand_pikapic itself, so
# the dump lands BEFORE pikapic_window_exit tears the window down --
# StarterPikachuEmotionCommand_pikapic runs start-to-finish as one call with no
# natural mid-animation return point. No forced frame-count hook is needed the
# way the free-running surf minigame needs one: ExecutePikaPicAnimScript returns
# by itself once the chosen script's own animation timer (PikaPicAnimScript0's
# pikapic_setduration 40) expires.
# make DEBUG_PIKAPIC=1
$(eval $(call dump_gate,DEBUG_PIKAPIC))
# Surfing Pikachu minigame gate: boot directly into SurfingPikachuMinigame with
# seeded party (starter Pikachu with SURF) and script flags.
# make DEBUG_SURFING_PIKACHU=1
$(eval $(call dump_gate,DEBUG_SURFING_PIKACHU))
# Which loop iteration SurfingPikachuDebugFrameHook photographs. Overridable so a
# caller can capture a later phase:  make DEBUG_SURFING_PIKACHU=1 SURF_DUMP_FRAME=250
ifdef DEBUG_SURFING_PIKACHU
SURF_DUMP_FRAME ?= 90
NASMFLAGS += -D SURF_DUMP_FRAME=$(SURF_DUMP_FRAME)
endif
# Surfing Pikachu INTRO golden checkpoint (backlog item 34 / archived
# docs/plans/surfing_pikachu.md Stage 8): same RunSurfingPikachuTest entry as
# the gameplay capture gate above, but the frame hook lives on
# SurfingPikachuMinigameIntro.loop instead of the post-intro gameplay loop
# (SurfingPikachuLoop.DelayFrame), because the intro is the minigame's only
# RNG-free, input-free surface (see tools/mgba_harness/scenarios/
# surfing_pikachu_intro.lua's header). make DEBUG_SURFING_PIKACHU_INTRO=1
ifdef DEBUG_SURFING_PIKACHU_INTRO
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_SURFING_PIKACHU -D DEBUG_SURFING_PIKACHU_INTRO -D SKIP_TITLE
endif
# PLAYABLE Surfing Pikachu harness — the one to reach for when a human is at the
# keyboard, rather than the capture gate above.
#   dos_port/run DEBUG_SURFING_PIKACHU_LIVE=1
# Same entry as the capture gate (RunSurfingPikachuTest: seeded party, starter
# Pikachu with SURF, the SURF_SELECT script flag so SELECT quits), but it compiles
# SurfingPikachuDebugFrameHook's call site OUT, so the minigame is never
# photographed and never dump-and-exits — it just runs until you crash out or
# press SELECT. That is why this is a gate and not merely SURF_DUMP_FRAME=999999:
# a sentinel frame number leaves the hook counting every frame forever and still
# drags DumpBackbuffer/DumpGBState into the build.
#
# INPUT IS REAL, and always was — this gate adds no autokey and neither does the
# capture gate (dump_gate defines only the flag, NEED_DEBUG_DUMP and SKIP_TITLE).
# The chain is Joypad -> hJoyHeld -> hJoy5 -> SurfingMinigame_DPadAction for
# left/right, and hJoyPressed for A. Note the JUMP IS NOT A BUTTON:
# SurfingMinigame_TryStartJump fires on riding a wave crest
# (wSurfingMinigameBGMapReadBuffer == $14) at speed >= $0A on the right hSCX phase.
ifdef DEBUG_SURFING_PIKACHU_LIVE
NEED_DEBUG_DUMP := 1
NASMFLAGS += -D DEBUG_SURFING_PIKACHU -D DEBUG_SURFING_PIKACHU_LIVE -D SKIP_TITLE
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

# Save-commit measurement harness (sram plan stage 7): seeded new game, 32
# back-to-back real SaveGameData commits with the DEBUG_PERF event recorder
# lapping the four sub-spans, then DumpPerf writes PERF.BIN v3 and exits.
# Decode with tools/read_perf.py. Measurement only — no golden scenario.
#   make DEBUG_SAVEPERF=1
ifdef DEBUG_SAVEPERF
# (no DEBUG_SEED_PARTY: RunSavePerfTest calls PrepareNewGameDebug itself, the
# RunSaveTest pattern — the dispatch seed would double-seed.)
NASMFLAGS += -D DEBUG_SAVEPERF -D SKIP_TITLE
ifndef DEBUG_PERF
GAME_SRCS += src/debug/perf.asm
NASMFLAGS += -D DEBUG_PERF
endif
endif

# Test harness for event-gated dialog: force EVENT_GOT_POKEBALLS_FROM_OAK at map
# load so PalletTownOakText shows its "set" branch. make SKIP_TITLE=1 DEBUG_OAK_EVENT=1
$(eval $(call flag_gate,DEBUG_OAK_EVENT))

# LINK_SRCS = what actually goes into PKMN.EXE. BATTLE_SRCS is deliberately
# excluded: the battle backend depends on deferred UI/effect routines and does
# not yet link (see the BATTLE_SRCS note above). It is still assembled by
# `make check` and validated by native harnesses via ALL_SRCS below.
# Battle front-end (Wave 2). These DO link (no unresolved externs) — unlike the
# check-only BATTLE_SRCS backend. Grows per stage.
FRONTEND_SRCS := \
    src/engine/battle/init_battle_variables.asm \
    src/engine/battle/init_battle.asm \
    src/engine/battle/battle_transitions.asm \
    src/data/maps/dungeon_maps.asm \
    src/engine/battle/get_trainer_name.asm \
    src/engine/battle/save_trainer_name.asm \
    src/engine/battle/common_text.asm \
    src/engine/battle/scroll_draw_trainer_pic.asm \
    src/engine/battle/ghost_marowak_anim.asm \
    src/engine/battle/safari_zone.asm \
    src/engine/battle/unused_stats_functions.asm \
    src/engine/battle/scale_sprites.asm \
    src/engine/battle/pikachu_entrance_anim.asm \
    src/engine/battle/battle_menu.asm \
    src/engine/battle/core.asm \
    src/engine/battle/core_stubs.asm \
    src/engine/battle/display_effectiveness.asm \
    src/engine/battle/effects.asm \
    src/home/names.asm \
    src/home/names2.asm \
    src/engine/battle/move_effects/conversion.asm \
    src/engine/battle/move_effects/focus_energy.asm \
    src/engine/battle/move_effects/haze.asm \
    src/engine/battle/move_effects/leech_seed.asm \
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
    src/engine/battle/decrement_pp.asm \
    src/engine/battle/animations.asm \
    src/engine/gfx/screen_effects.asm \
    src/engine/battle/used_move_text.asm \
    src/data/types/type_matchups.asm \
    src/data/moves/names.asm \
    src/data/battle/residual_effects_1.asm \
    src/data/battle/residual_effects_2.asm \
    src/data/battle/special_effects.asm \
    src/data/battle/always_happen_effects.asm \
    src/data/battle/set_damage_effects.asm \
    src/data/battle/critical_hit_moves.asm \
    src/data/battle/stat_modifiers.asm \
    src/data/battle/stat_mod_names.asm \
    src/data/moves/animations.asm \
    src/data/battle_anims/subanimations.asm \
    src/data/battle_anims/frame_blocks.asm \
    src/data/battle_anims/base_coords.asm \
    src/data/moves/sfx.asm \
    src/data/battle_anims/special_effect_pointers.asm \
    src/data/battle_anims/special_effects.asm \
    src/data/tilemaps.asm \
    src/data/moves/effects_pointers.asm \
    src/data/trainer_data.asm \
    src/data/trainers/move_choices.asm \
    src/data/move_grammar.asm \
    src/data/type_names.asm \
    src/home/random.asm \
    src/engine/battle/print_type.asm \
    src/debug/debug_battle_moveset.asm \
    src/engine/battle/pokeballs.asm \
    src/engine/battle/draw_hud_pokeball_gfx.asm \
    src/engine/battle/link_battle_versus_text.asm \
    src/data/trainer_pics.asm \
    src/data/mon_pics.asm \
    src/engine/battle/battle_stubs.asm \
    src/home/uncompress.asm \
    src/home/pics.asm \
    src/engine/battle/experience.asm \
    src/engine/battle/battle_exp_stubs.asm \
    src/home/trainers.asm \
    src/home/trainers2.asm \
    src/engine/overworld/trainer_sight.asm \
    src/engine/overworld/emotion_bubbles.asm \
    src/engine/battle/trainer_ai.asm \
    src/engine/battle/read_trainer_party.asm \
    src/engine/battle/misc.asm \
    src/engine/battle/end_of_battle.asm \
    src/engine/flag_action.asm

# Home/item helpers promoted to the live build now that battle faint/EXP-ALL
# consumers (faint_enemy.asm: ClearScreenArea, IsItemInBag→GetQuantityOfItemInBag)
# reference them. Closures resolve: copy2→DelayFrame/g_tilecache_dirty;
# get_bag_item_quantity→GetPredefRegisters. Removed from HOME_CHECK_SRCS below.
# (item_predicates.asm was deleted by the relocated-labels grind: its labels were
# pret home/names.asm and home/item.asm ones and went to those two mirrors.)
BATTLE_SUPPORT_SRCS := \
    src/home/copy2.asm \
    src/engine/items/get_bag_item_quantity.asm

LINK_SRCS := $(BOOT_SRCS) $(HOME_SRCS) $(HAL_SRCS) $(NET_SRCS) $(SAVE_SRCS) $(PRINT_SRCS) $(AUDIO_SRCS) $(GAME_SRCS) $(POKEMON_SRCS) $(ITEMS_SRCS) $(FRONTEND_SRCS) $(BATTLE_SUPPORT_SRCS)
# Stable de-dup: several DEBUG_* gates each append debug_party.asm, so combining two
# (e.g. DEBUG_SEED_PARTY + DEBUG_STATUS) would list its object twice → ld "multiple
# definition". Drop duplicates while preserving first-seen order (link layout unchanged).
uniq = $(if $1,$(firstword $1) $(call uniq,$(filter-out $(firstword $1),$1)))
LINK_OBJS := $(call uniq,$(LINK_SRCS:.asm=.o))

# Pokémon backend that assembles + is native-harness-validated but is NOT linked
# yet. EMPTY as of the s16 mirror repair: bills_pc.asm was the last member, and
# its stated blocker had gone stale. This comment used to say it "needs a
# link-ready _MoveMon (the draft in add_mon.asm has a duplicate
# AddPartyMon_WriteMovePP symbol + extern-constant errors and an unresolved
# dependency closure)" — measured false: add_mon.asm has been linked since s14
# chunk 10 moved AddPartyMon_WriteMovePP into it, _MoveMon is global there, and
# bills_pc.asm links with exit 0. It was promoted to POKEMON_SRCS so that merging
# pret's KnowsHMMove + HMMoveArray back into their mirror did not quietly drop
# them out of the binary.
# (evolution.asm + pikachu_status.asm are now LINKED — moved to POKEMON_SRCS,
#  current_plan_pokemon_behavior Stage 2.)
POKEMON_CHECK_SRCS :=

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
# subtract_paid_money.asm MOVED to ITEMS_SRCS (services chunk 1 mart): called by pokemart.asm.
# The check-only tier is now the map scripts that cannot LINK yet: each one
# references a symbol nothing defines (transpiler BAIL regions + unported engine
# routines -- see docs/current_plan_script_linking.md). They assemble-validate
# here so a change that breaks them is still caught, and each graduates to
# SCRIPT_SRCS above as its blocking symbol lands.
ITEMS_CHECK_SRCS := \
    src/scripts/HallOfFame.asm \

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
# overworld.asm, DiscardButtonPresses extracted into src/input/joypad.asm (and
# moved on to src/engine/joypad.asm in chunk 18, when that file was repaired), and
# WriteOAMBlock + SaveScreenTilesToBuffer2/LoadScreenTilesFromBuffer2 now linked
# (the latter pair via the vcopy.asm promotion in Stage 3 — the old note claiming
# they blocked cut.asm was stale).
HOME_CHECK_SRCS :=
# predef_text.asm LEFT this list 2026-08-02: PrintPredefTextID now publishes a
# port-only flat table pointer (Option A) and links in HOME_SRCS.

# Generated data that assembles but has no consumer yet. EMPTY as of 2026-08-02:
# predef_text_data.asm (the 51 generated TextPredefs streams plus the hand-written
# 68-row TextPredefs table) is LINKED now that PrintPredefTextID and DisplayTextID's
# TEXT_PREDEF branch both speak flat pointers. The list is kept because the
# check-only tier is a useful place to prove generated bytes assemble before they
# have a consumer.
DATA_CHECK_SRCS :=
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
#   NOTE cut.asm first linked for its OAM-animation primitives, which the boulder
#   dust shares. StartMenu_Pokemon.cut now CALLS UsedCut for real (Stage 4 CUT
#   bullet), so UsedCut/AnimCut are reachable from the field-move menu. Still owed:
#   the cutscene has never EXECUTED — no reachable map has a cut tree and
#   CASCADEBADGE is unobtainable outside DEBUG_PARTY, so the animation +
#   tree-tile-replacement must-hit lands with the first reachable Cut map (Stage 5).
# - field_move_messages.asm: LINKED as of menu-fidelity row 9 part 3. Its only
#   unresolved symbol was PlayCry (cry synth, still unported); that is now a
#   documented ret-stub in home_stubs.asm, which costs the STRENGTH cry and
#   nothing else. Linking it is what makes STRENGTH and SURF reachable from
#   the field-move menu.
# - player_animations.asm: EmotionBubble is LINKED now (emotion_bubbles.asm
#   pret mirror, M8.2 promotion); LoadAnimSpriteGfx.
#   (StopMusic is REAL now — ported into overworld.asm by the wild-live
#   promotion; player_sprite is exported from overworld.asm.)
# - trainer_engine.asm: DISSOLVED (M8.2 promotion, 2026-07-24) — the pret
#   home/trainers.asm remainder went home to the linked src/home/trainers.asm
#   full mirror, the EmotionBubble family to src/engine/overworld/
#   emotion_bubbles.asm, and trainer_sight.asm joined the link. Only
#   trainers2.asm (GetTrainerInformation/GetTrainerName, blocked on
#   JessieJamesPic + trainer-pic data) stays check-only.
# - text_script.asm promoted to HOME_SRCS (overworld-events Stage 2): the real
#   DisplayTextID dispatcher links, uses the flat map text table for ordinary
#   map text, and owns the generated text_script_text.inc far streams. The
#   remaining mart / Pokémon Center / vending / cable club / Pikachu / Safari /
#   prize-service bodies are structured subsystem stubs until their service
#   bullets land.
# reload_sprites.asm promoted to GAME_SRCS (menus S7): naming_screen.asm calls
# ReloadMapSpriteTilePatterns; its externs (DisableLCD/EnableLCD/InitMapSprites/
# LoadPlayerSpriteGraphics/LoadFontTilePatterns/UpdateSprites) are all linked.

# Surfing Pikachu minigame (LINKED in Chunk 3)
MINIGAME_CHECK_SRCS :=

# Game Boy Printer tier (LINKED in Stage 2)
PRINTER_CHECK_SRCS :=

# ALL_SRCS = everything that must assemble cleanly (check) and be cleaned, incl.
# the not-yet-linked battle backend + check-only pokemon/items/home backends.
ALL_SRCS := $(LINK_SRCS) $(BATTLE_SRCS) $(POKEMON_CHECK_SRCS) $(ITEMS_CHECK_SRCS) $(HOME_CHECK_SRCS) $(DATA_CHECK_SRCS) $(MINIGAME_CHECK_SRCS) $(PRINTER_CHECK_SRCS)
ALL_OBJS := $(ALL_SRCS:.asm=.o)

# ---------------------------------------------------------------------------
# Targets
# ---------------------------------------------------------------------------

.PHONY: all clean clean-image image check assets regen goldens goldens-verify goldencheck fidelity fidelity-full static_gate install-hooks pixellock pixellock-bless
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
		case "$$name" in \
			*_trace) echo "=== goldens-verify: $$name (timing-trace recorder, no committed golden -- skipped)"; continue ;; \
		esac; \
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
# pixellock — ratchet over the COMPOSITED FRAME, which no other gate checks.
# The golden suite compares GB STATE (tilemap/VRAM/WRAM/OAM/palette RAM) and
# never the pixels the port draws; measured twice, that blind spot let a
# per-cell palette override sit unreachable for two commits while fidelity-full
# stayed 83/83. Self-referential (port-now vs port-when-blessed), NOT fidelity.
# Deliberately NOT wired into the pre-commit hook: five rebuilds + headless runs
# is minutes, not seconds. Run it when touching the compositor or a palette path.
pixellock:
	@tools/pixellock

# Re-record after an INTENDED rendering change. Say what changed in the commit.
pixellock-bless:
	@tools/pixellock --bless

goldencheck:
	tools/goldencheck.sh $(SCENARIO)

# Fast pre-commit tier: one representative from each fidelity surface, excluding
# slower/redundant exhaustive tails. Measured 2026-07-15 in this worktree:
# core ~2m50s, full ~4m45s.
FIDELITY_SCENARIOS_CORE := $(shell python3 tools/generators/gen_scenario_registry.py --names core)
FIDELITY_SCENARIOS_FULL := $(shell python3 tools/generators/gen_scenario_registry.py --names full)
FIDELITY_SCENARIOS ?= $(FIDELITY_SCENARIOS_CORE)

# BOTH TIERS RUN IN PARALLEL BY DEFAULT (2026-08-12, maintainer request).
#
# tools/pgate.sh gives each scenario its own tmpfs shadow copy, so the shared
# PKMN.EXE / PKMN.IMG contention that forced a serial loop does not exist. It
# was added 2026-08-08 (c27b3720e) but was never wired into these targets --
# `git log -S pgate -- Makefile` was empty until now -- so the documented gate
# commands stayed serial while a parallel runner sat unused next to them.
#
# MEASURED on a 96-thread host, same tree, same scenarios:
#   full   66 scenarios   serial ~1750 s   ->   parallel 378 s   (~4.6x)
# The stale "core ~2m50s, full ~4m45s" note above dated from the 17-scenario
# battery era and is why "fidelity-full is ~15 min" is still repeated; the
# registry is 66 now. Re-measure rather than quoting any of these numbers.
#
# The SERIAL recipes are kept verbatim as -serial targets: they are the
# reference semantics, they need no tmpfs, and if the two ever disagree the
# serial one is the arbiter.
#
# OUTDIR must be a path -- pgate rejects a bare word, because `pgate.sh full`
# once consumed the tier name as the outdir, ran zero scenarios and exited 0.
FIDELITY_PAR_OUT      ?= /tmp/pgate-out/core
FIDELITY_PAR_OUT_FULL ?= /tmp/pgate-out/full

fidelity:
	@mkdir -p $(FIDELITY_PAR_OUT)
	tools/pgate.sh $(FIDELITY_PAR_OUT) $(FIDELITY_SCENARIOS_CORE)

fidelity-full:
	@mkdir -p $(FIDELITY_PAR_OUT_FULL)
	tools/pgate.sh $(FIDELITY_PAR_OUT_FULL) $(FIDELITY_SCENARIOS_FULL)

# Alias kept because b24dcf744 introduced this name one commit ago.
fidelity-full-par: fidelity-full

fidelity-serial:
	@fail=0; for s in $(FIDELITY_SCENARIOS_CORE); do \
		tools/goldencheck.sh $$s || fail=1; \
	done; exit $$fail

fidelity-full-serial:
	@fail=0; for s in $(FIDELITY_SCENARIOS_FULL); do \
		tools/goldencheck.sh $$s || fail=1; \
	done; exit $$fail

# Generate all tileset gfx/blocks/coll + map blk inc files.
# Requires gfx/tilesets/*.2bpp, built by 'make' in the repo root.
# Authored map edits (assets/map_overrides/*.json, map-tool C5) are merged
# into the emitted <map>_blk.inc files.
# DECLARE WHAT THE CHAIN READS: gen_all_assets.py chains generators that CONSUME
# generated assets — gen_unknown_list + gen_credits_data read script_constants.inc,
# gen_battle_text reads pret_ram.inc. Neither is produced by this chain. Without
# these prerequisites make is free to run the consumer first: on a clean checkout
# that is a hard FileNotFoundError (CI 32646793945), while a developer tree hides
# it because gitignored assets/ accumulates. Do not rely on ordering in the
# `assets:` list -- that is racy under -j. See memory ci-clean-tree-generator-order-traps.
assets/overworld_gfx.inc assets/overworld_blocks.inc assets/pallet_town_blk.inc: \
		assets/script_constants.inc assets/pret_ram.inc \
		$(wildcard assets/map_overrides/*.json)
	python3 tools/generators/gen_all_assets.py

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
    tools/generators/gen_map_headers.py \
    ../constants/map_constants.asm \
    $(wildcard ../data/maps/headers/*.asm) \
    $(wildcard ../data/maps/objects/*.asm)
	python3 tools/generators/gen_map_headers.py $(GEN_MAP_HEADERS_FLAGS)

# Per-map (music id, ROM bank) table — pret data/maps/songs.asm (gen_map_songs.py).
# LoadMapHeader loads it into wMapMusicSoundID/wMapMusicROMBank (OW-A.14).
assets/map_songs.inc: tools/generators/gen_map_songs.py
	python3 tools/generators/gen_map_songs.py

# Overworld object depends on all generated assets
src/engine/overworld/overworld.o: \
    assets/overworld_gfx.inc \
    assets/overworld_blocks.inc \
    assets/pallet_town_blk.inc

# Map header region TU (pret data/maps) — hosts the generated tables + blobs
src/data/maps/map_headers.o: \
    assets/map_headers.inc \
    assets/extra_includes.inc

src/data/maps/songs.o: assets/map_songs.inc
src/data/sgb/sgb_packets.o: assets/sgb_packets.inc
src/data/tilesets/pair_collision_tile_ids.o: assets/pair_collision_tile_ids.inc assets/map_dims.inc
src/data/tilesets/ledge_tiles.o: assets/ledge_tiles.inc assets/map_dims.inc
src/data/tilesets/bike_riding_tilesets.o: assets/bike_riding_tilesets.inc assets/map_dims.inc
src/data/events/card_key_coords.o: assets/card_key_coords.inc assets/map_dims.inc

# Small pret static tables that were hand-transcribed into code files until
# 2026-08-02 (tileset pair-collisions / ledges / bike tilesets, Silph card keys).
assets/pair_collision_tile_ids.inc assets/ledge_tiles.inc \
assets/bike_riding_tilesets.inc assets/card_key_coords.inc \
assets/copyright_text.inc &: tools/generators/gen_static_tables.py
	python3 tools/generators/gen_static_tables.py

# The one SGB packet the port reads the BYTES of — see the carrier's header.
assets/sgb_packets.inc: tools/generators/gen_sgb_packets.py
	python3 tools/generators/gen_sgb_packets.py

assets/card_key_maps.inc: tools/generators/gen_card_key_maps.py
	python3 tools/generators/gen_card_key_maps.py

assets/vermilion_gym_trash_text.inc: tools/generators/gen_vermilion_gym_trash_text.py
	python3 tools/generators/gen_vermilion_gym_trash_text.py

# NPC sprite sheets — all sprites used across all maps (generated by gen_all_assets.py)
assets/npc_sprite_data_table.inc:
	python3 tools/generators/gen_all_assets.py

# Alternate player sprite sheets (bike / surfing) — pret gfx/sprites.asm labels
# RedBikeSprite / SeelSprite / SurfingPikachuSprite, hosted as data tables in
# player_gfx.asm and consumed by home/overworld.asm's LoadPlayerSpriteGraphics
# dispatch (wild-live promotion).
assets/red_bike_sprite.inc assets/seel_sprite.inc assets/surfing_pikachu_sprite.inc:
	python3 tools/generators/gen_all_assets.py

src/home/player_gfx.o: \
    assets/red_bike_sprite.inc \
    assets/seel_sprite.inc \
    assets/surfing_pikachu_sprite.inc

# Full-coverage sprite sheet pointer table (OW-A.2 P3a) — all NUM_SPRITES, incl.
# outside-map fillers the map-object scan misses. Consumed by the faithful
# map_sprites.asm sprite-set machinery from P3c on (self-contained include).
assets/sprite_sheet_pointers.inc:
	python3 tools/generators/gen_all_assets.py

# NPC dialog streams — all maps (generated by gen_npc_dialogs.py)
# NB: this rule had NO prerequisites, so once the files existed it never fired
# again — editing the generator silently shipped stale dialogs. Measured
# 2026-08-25: the overworld-services Stage 5 nurse overrides sat in
# gen_npc_dialogs.py while every Poké Center's generated table still carried the
# "..." placeholder row, because all_dialogs.inc predated the edit and nothing
# ever regenerated it. Keep the inputs listed (same rule as map_headers above).
assets/npc_dialogs/all_dialogs.inc: \
    tools/generators/gen_npc_dialogs.py \
    tools/generators/gen_map_headers.py \
    tools/generators/gen_map_script_tables.py \
    ../constants/map_constants.asm \
    ../constants/charmap.asm \
    $(wildcard ../scripts/*.asm) \
    $(wildcard ../text/*.asm) \
    $(wildcard ../data/maps/headers/*.asm) \
    $(wildcard ../data/maps/objects/*.asm)
	python3 tools/generators/gen_npc_dialogs.py

# Toggleable-object (event) flag tables — NPC spawn gating (gen_toggleable_objects.py)
assets/toggleable_objects.inc:
	python3 tools/generators/gen_toggleable_objects.py

# Event-flag bit-index constants (EVENT_*) for include/events.inc (gen_event_constants.py)
assets/event_constants.inc:
	python3 tools/generators/gen_event_constants.py

# pret constant NAMES for the translated map scripts (TOGGLE_*, species, items,
# FLOOR_*, TRADE_FOR_*, BIT_*) so a script line can be checked against the
# disassembly without resolving numbers by hand (gen_script_constants.py).
assets/script_constants.inc: tools/generators/gen_script_constants.py
	python3 tools/generators/gen_script_constants.py

# Far text streams for the translated map scripts, one .inc per map, from pret
# text/*.asm (gen_map_text.py). Each is %included by that map's own script, so a
# stream lives beside the only code that uses it — as pret keeps text/<Map>.asm
# beside scripts/<Map>.asm. The stamp file stands in for the 162 outputs.
assets/map_text/.stamp: tools/generators/gen_map_text.py \
                        tools/generators/gen_battle_text.py
	python3 tools/generators/gen_map_text.py
	@touch $@

# Fixed outside-map sprite sets (pret data/maps/sprite_sets.asm) — OW-A.2 sprite-set
# machinery in map_sprites.asm. Pure data (no gfx dep); consumed from Phase 3 onward.
assets/sprite_sets.inc: tools/generators/gen_sprite_sets.py
	python3 tools/generators/gen_sprite_sets.py

# map_sprites depends on the NPC tile asset table, all-maps dialog table, the
# toggleable-object (event) flag tables, and the event-flag constants (events.inc).
src/engine/overworld/map_sprites.o: \
    assets/sprite_sets.inc \
    assets/sprite_sheet_pointers.inc \
    assets/npc_dialogs/all_dialogs.inc \
    assets/toggleable_objects.inc \
    assets/event_constants.inc

# Pallet Town text_asm scripts include events.inc → event_constants.inc.
src/scripts/PalletTown.o: assets/event_constants.inc

# Per-map script dispatch table (generated from constants/map_constants.asm).
assets/map_scripts.inc: tools/generators/gen_map_script_tables.py
	python3 tools/generators/gen_map_scripts.py

src/data/map_scripts.o: assets/map_scripts.inc

# Per-map parameter blocks for the generic TrainerMapScript driver (map-script
# fidelity plan Stage 2). Derived from pret scripts/*.asm + ram/wram.asm; the
# dispatch table above reads its WIRED_MAPS list, so map_scripts.inc depends on
# this generator too.
assets/map_script_tables.inc: tools/generators/gen_map_script_tables.py
	python3 tools/generators/gen_map_script_tables.py

src/data/map_script_tables.o: assets/map_script_tables.inc

# Trainer-header tables + battle-text streams (generated from scripts/*.asm +
# text/*.asm; event bit indices via assets/event_constants.inc).
assets/trainer_headers.inc: assets/event_constants.inc \
        tools/generators/gen_trainer_headers.py tools/generators/gen_battle_text.py
	python3 tools/generators/gen_trainer_headers.py

src/data/trainer_headers.o: assets/trainer_headers.inc

# Hidden-event data (generated from data/events/hidden_events.asm).
assets/hidden_events.inc:
	python3 tools/generators/gen_hidden_events.py

# HiddenItemCoords data (generated from data/events/hidden_item_coords.asm) —
# overworld-events Stage 3 bullet 2, consumed by the items plan's itemfinder.
assets/hidden_item_coords.inc:
	python3 tools/generators/gen_hidden_item_coords.py

# HiddenCoinCoords data (generated from data/events/hidden_coins.asm) — the
# gen_hidden_item_coords.py sibling, consumed by
# src/engine/events/hidden_items.asm:FindHiddenItemOrCoinsIndex.
assets/hidden_coin_coords.inc:
	python3 tools/generators/gen_hidden_coin_coords.py

# FoundHiddenItemText's far intro (generated from data/text/text_2.asm's
# _FoundHiddenItemText), consumed by src/engine/events/hidden_items.asm.
assets/hidden_items_text.inc: tools/generators/gen_hidden_items_text.py tools/generators/gen_battle_text.py
	python3 tools/generators/gen_hidden_items_text.py

src/engine/events/hidden_items.o: assets/hidden_coin_coords.inc assets/hidden_items_text.inc \
    assets/predef_text_ids.inc include/predef.inc assets/script_constants.inc assets/audio_constants.inc
src/engine/events/hidden_events/pokecenter_pc.o: assets/predef_text_ids.inc include/predef.inc
src/engine/events/hidden_events/bookshelves.o: assets/predef_text_ids.inc include/predef.inc

# PickUpItem message streams (generated from engine/events/pick_up_item.asm).
assets/pickup_text.inc: assets/item_text.inc assets/battle_text.inc
	python3 tools/generators/gen_pickup_text.py

# GivePokemon message streams (generated from engine/events/give_pokemon.asm).
assets/give_pokemon_text.inc: tools/generators/gen_give_pokemon_text.py tools/generators/gen_battle_text.py
	python3 tools/generators/gen_give_pokemon_text.py

src/engine/events/give_pokemon.o: assets/give_pokemon_text.inc

assets/predef_text.inc: tools/generators/gen_predef_text.py tools/generators/gen_battle_text.py
	python3 tools/generators/gen_predef_text.py
assets/predef_text_ids.inc: assets/predef_text.inc

# Slots text strings (generated by gen_slots_text.py)
assets/slots_text.inc: tools/generators/gen_slots_text.py tools/generators/gen_battle_text.py
	python3 tools/generators/gen_slots_text.py

src/engine/slots/slot_machine.o: assets/slots_text.inc

# Oak-speech intro message streams (generated from oak_speech.asm wrappers +
# data/text/text_3.asm bodies).
assets/oak_speech_strings.inc: tools/generators/gen_oak_speech_strings.py tools/generators/gen_battle_text.py
	python3 tools/generators/gen_oak_speech_strings.py

src/engine/movie/oak_speech/oak_speech.o: assets/oak_speech_strings.inc

# Oak-speech default player/rival name data (menu-intro A4.4; pret data/player/
# names.asm + names_list.asm). Consumed by oak_speech2.asm (naming flow).
assets/default_names.inc: ../constants/player_constants.asm assets/gb_charmap.txt \
                          tools/generators/gen_default_names.py tools/generators/gb_text.py
	python3 tools/generators/gen_default_names.py

src/engine/movie/oak_speech/oak_speech2.o: assets/default_names.inc

# Debug new-game boot names (menu-intro A4.5e; pret DebugNewGame{Player,Rival}Name).
# Consumed by title.asm; must stay contiguous (the NAME_LENGTH copies overrun).
assets/debug_boot_names.inc: assets/gb_charmap.txt \
                             tools/generators/gen_debug_boot_names.py tools/generators/gb_text.py
	python3 tools/generators/gen_debug_boot_names.py

src/engine/movie/title.o: assets/debug_boot_names.inc \
    assets/title_copyright_2bpp.inc assets/gamefreak_inc_2bpp.inc \
    assets/nine_2bpp.inc assets/audio_constants.inc assets/pika_pcm.inc \
    assets/ui_layout_intro.inc assets/copyright_text.inc
src/engine/movie/title_yellow.o: assets/pokemon_logo_2bpp.inc \
    assets/pokemon_logo_corner_2bpp.inc assets/pikachu_bg_2bpp.inc \
    assets/pikachu_ob_2bpp.inc assets/pokemon_logo_tilemap.inc \
    assets/pikachu_tilemap.inc assets/pika_bubble_tilemap.inc \
    assets/ui_layout_intro.inc

# Yellow-intro gfx (menu-intro B3.2b) — committed incs from gen_intro_gfx_inc.py.
src/engine/movie/intro_yellow.o: assets/yellow_intro_1_2bpp.inc \
    assets/yellow_intro_2_2bpp.inc assets/yellow_intro_clouds_2bpp.inc \
    assets/yellow_intro_tilemaps.inc

src/data/hidden_events_data.o: assets/hidden_events.inc assets/hidden_item_coords.inc
src/data/pickup_text.o: assets/pickup_text.inc
src/data/text_predef_pointers.o: assets/predef_text.inc
src/engine/events/hidden_events/reds_room.o: assets/predef_text_ids.inc include/predef.inc
src/engine/events/hidden_events/bills_house_pc.o: assets/bills_house_pc_text.inc \
    assets/predef_text_ids.inc include/predef.inc assets/event_constants.inc \
    assets/audio_constants.inc assets/script_constants.inc
src/engine/events/hidden_events/school_notebooks.o: assets/school_notebooks_text.inc

# Bills House PC text data (the Eevee-list menu string, the 2 pure text_far
# wrappers, and the standalone _BillsHouseInitiatedText far body). Generated
# from engine/events/hidden_events/bills_house_pc.asm + data/text/text_2.asm.
assets/bills_house_pc_text.inc: ../engine/events/hidden_events/bills_house_pc.asm \
                         ../data/text/text_2.asm ../constants/charmap.asm \
                         tools/generators/gen_battle_text.py \
                         tools/generators/gen_bills_house_pc_text.py
	python3 tools/generators/gen_bills_house_pc_text.py

# School notebooks text strings (generated by gen_school_notebooks_text.py)
assets/school_notebooks_text.inc: tools/generators/gen_school_notebooks_text.py tools/generators/gen_battle_text.py
	python3 tools/generators/gen_school_notebooks_text.py
src/engine/events/hidden_events/cinnabar_gym_quiz.o: assets/predef_text_ids.inc include/predef.inc \
    assets/cinnabar_gym_quiz_text.inc assets/event_constants.inc assets/audio_constants.inc
src/engine/events/hidden_events/vermilion_gym_trash.o: assets/vermilion_gym_trash_text.inc \
    assets/event_constants.inc assets/predef_text_ids.inc assets/audio_constants.inc
src/engine/events/hidden_events/vermilion_gym_trash2.o: include/gb_macros.inc include/gb_memmap.inc
src/engine/events/hidden_events/bench_guys.o: assets/bench_guys_text.inc assets/predef_text_ids.inc \
    assets/event_constants.inc assets/map_dims.inc
src/engine/events/hidden_events/book_or_sculpture.o: assets/book_or_sculpture_text.inc
src/engine/events/hidden_events/magazines.o: assets/predef_text_ids.inc include/predef.inc
src/engine/events/hidden_events/new_bike.o: assets/predef_text_ids.inc include/predef.inc
src/engine/events/hidden_events/route_15_binoculars.o: assets/predef_text_ids.inc include/predef.inc
src/engine/events/hidden_events/indigo_plateau_statues.o: assets/indigo_plateau_statues_text.inc
src/engine/events/hidden_events/indigo_plateau_hq.o: assets/predef_text_ids.inc include/predef.inc
src/engine/events/hidden_events/gym_statues.o: assets/predef_text_ids.inc include/predef.inc \
    assets/badge_maps.inc
src/engine/events/hidden_events/fighting_dojo.o: assets/predef_text_ids.inc include/predef.inc
src/engine/events/hidden_events/blues_room.o: assets/predef_text_ids.inc include/predef.inc
src/engine/events/hidden_events/oaks_lab_posters.o: assets/predef_text_ids.inc include/predef.inc
src/engine/events/hidden_events/oaks_lab_email.o: assets/predef_text_ids.inc include/predef.inc
src/engine/events/hidden_events/fanclub_pictures.o: assets/predef_text_ids.inc include/predef.inc assets/script_constants.inc
src/engine/events/hidden_events/museum_fossils.o: assets/predef_text_ids.inc include/predef.inc
src/engine/events/hidden_events/museum_fossils2.o: include/coords.inc include/gb_constants.inc include/gb_memmap.inc
src/engine/events/hidden_events/town_map.o: assets/town_map_text.inc

# Wall Town Map text string (generated by gen_town_map_text.py)
assets/town_map_text.inc: tools/generators/gen_town_map_text.py tools/generators/gen_battle_text.py
	python3 tools/generators/gen_town_map_text.py

src/data/audio_data.o: assets/audio_rom.inc
src/data/pokemon/cries.o: assets/cry_data.inc
src/audio/opl_shim.o: assets/opl_patches.inc
src/audio/opl_enh.o: assets/enh_streams.inc assets/audio_constants.inc

src/audio/tandy_shim.o: assets/tandy_tables.inc
src/audio/mpu401.o: assets/music_streams.inc assets/mt32_sysex.inc \
                    assets/audio_constants.inc
src/audio/pikachu_pcm.o: assets/pika_pcm.inc assets/pika_pcm.bin

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
assets/gb_charmap.txt: ../constants/charmap.asm tools/generators/gen_charmap.py
	python3 tools/generators/gen_charmap.py

# START-menu item labels, encoded via the unicode_converter submodule (gb_text),
# plus the START-sub-menu FAR message streams (menu_text.inc), flattened out of
# pret's data/text/*.asm by gen_battle_text.collect_far — hence the extra deps.
# NOTE: every output of gen_menu_strings.py must be listed here. The seven from
# save_text.inc onward were added to the generator later and never added to this
# rule, so make did not know they existed: deleting one on its own did not bring
# it back (the recipe only fires when a LISTED target is stale). A clean tree was
# unaffected — menu_strings.inc is missing too, so the recipe runs and writes them
# all — but that is luck, not a dependency. Measured and fixed 2026-08-02.
# cable_club_text.inc was added to the generator by the link-cable Stage 3
# merge but never added here (same class of gap this note already warns
# about) — fixed alongside adding trade_text.inc/trade_mon_info_text.inc,
# which is the edit that caught it.
assets/menu_strings.inc assets/menu_text.inc assets/trainer_card_strings.inc \
        assets/party_menu_strings.inc assets/home_pokemon_strings.inc \
        assets/options_strings.inc assets/naming_strings.inc \
        assets/pokedex_strings.inc assets/bills_pc_text.inc \
        assets/save_text.inc assets/main_menu_text.inc assets/league_pc_text.inc \
        assets/players_pc_text.inc assets/link_text.inc assets/link_npc_text.inc assets/oaks_pc_text.inc \
        assets/pc_text.inc assets/cable_club_text.inc assets/trade_text.inc \
        assets/trade_mon_info_text.inc: \
        assets/gb_charmap.txt tools/generators/gen_menu_strings.py \
        tools/generators/gb_text.py tools/generators/gen_battle_text.py
	python3 tools/generators/gen_menu_strings.py

# Status/summary-screen PlaceString labels (charmap-encoded via gb_text; two-tier rule).
assets/status_strings.inc: assets/gb_charmap.txt tools/generators/gen_status_strings.py tools/generators/gb_text.py
	python3 tools/generators/gen_status_strings.py

# Trainer-engine FAR message streams (_TrainerNameText), flattened out of pret's
# data/text/*.asm by gen_battle_text.collect_far; %included by src/home/trainers.asm.
assets/trainer_text.inc: assets/gb_charmap.txt tools/generators/gen_trainer_text.py \
        tools/generators/gen_battle_text.py
	python3 tools/generators/gen_trainer_text.py

# Used-move FAR streams (_ActorNameText/_UsedMove{1,2}Text/_UsedInsteadText/
# _MoveNameText) — the text_asm chain's payloads; %included by
# src/engine/battle/used_move_text.asm. gen_battle_text.py cannot emit them: it
# inlines text_far into its wrapper and skips text_asm-bearing wrappers.
assets/used_move_text.inc: assets/gb_charmap.txt tools/generators/gen_used_move_text.py \
        tools/generators/gen_battle_text.py
	python3 tools/generators/gen_used_move_text.py

# Hall of Fame rendered strings — the four PlaceString literals plus the two
# text_far wrappers, all parsed out of pret's own source (two-tier rule).
assets/hall_of_fame_text.inc: assets/gb_charmap.txt tools/generators/gen_hall_of_fame_text.py \
        tools/generators/gen_battle_text.py ../engine/movie/hall_of_fame.asm
	python3 tools/generators/gen_hall_of_fame_text.py

# Pointer_3b0ee — pret data/pokemon/unknown_list.asm, read only by the unreferenced
# evos_moves.asm:Func_3b0a2. Transcribed so a 32-entry species list cannot drift.
assets/unknown_list.inc: ../data/pokemon/unknown_list.asm assets/script_constants.inc \
        tools/generators/gen_unknown_list.py
	python3 tools/generators/gen_unknown_list.py

# Credits roll data — command stream, parade species, the pointer table and the 86
# name strings, all transcribed out of pret (the names are rendered text, so they
# may never be hand-encoded).
assets/credits_data.inc: ../data/credits/credits_order.asm ../data/credits/credits_mons.asm \
        ../data/credits/credits_text.asm ../constants/credits_constants.asm \
        ../engine/movie/credits.asm assets/gb_charmap.txt assets/script_constants.inc \
        tools/generators/gen_credits_data.py tools/generators/gen_battle_text.py
	python3 tools/generators/gen_credits_data.py

# Text-box menu strings (pret data/text_boxes.asm) — charmap-encoded via gb_text;
# two-tier rule. <NEXT>/<PK>/<MN> are emitted as named raw bytes by the generator.
assets/textbox_strings.inc: assets/gb_charmap.txt tools/generators/gen_textbox_strings.py tools/generators/gb_text.py
	python3 tools/generators/gen_textbox_strings.py

# List-menu strings (pret home/list_menu.asm: CANCEL / ×01 / the qty-price spacer).
assets/list_menu_strings.inc: assets/gb_charmap.txt tools/generators/gen_list_menu_strings.py tools/generators/gb_text.py
	python3 tools/generators/gen_list_menu_strings.py

# Link-cable setup UI strings (docs/current_plan_link_cable.md Stage 5 step 2):
# the transport-select menu + connection-book screens. Port-only (LinkUIStr_*,
# no pret counterpart draws this UI); consumed by step 3's src/net/link_ui.asm.
assets/link_ui_strings.inc: assets/gb_charmap.txt tools/generators/gen_link_ui_strings.py tools/generators/gb_text.py
	python3 tools/generators/gen_link_ui_strings.py

# Two-option (YES/NO) menu options — pret data/yes_no_menu_strings.asm.
assets/yes_no_strings.inc: assets/gb_charmap.txt tools/generators/gen_yes_no_strings.py tools/generators/gb_text.py
	python3 tools/generators/gen_yes_no_strings.py

# Inline human-rendered strings from pret's map scripts (gym city/leader names,
# bike-shop menu, Game Corner labels, badge names, one unused Japanese run).
# Emitted as MACROS so each transpiled script keeps pret's own label; also writes
# tools/sm83xlat/tables/text_assets.json, which the transpiler reads.
SCRIPT_STRING_SRCS := $(wildcard ../scripts/*Gym.asm ../scripts/BikeShop.asm \
        ../scripts/GameCorner.asm ../scripts/Route23.asm \
        ../scripts/FuchsiaGoodRodHouse.asm)
assets/script_strings.inc: assets/gb_charmap.txt tools/generators/gen_script_strings.py tools/generators/gb_text.py $(SCRIPT_STRING_SRCS)
	python3 tools/generators/gen_script_strings.py

# Text-engine oracle probe streams (DEBUG_TEXT). See docs/plans/text_engine.md.
assets/text_oracle.inc: assets/gb_charmap.txt tools/generators/gen_text_oracle.py tools/generators/gb_text.py
	python3 tools/generators/gen_text_oracle.py

assets/overworld_strings.inc assets/field_move_text.inc assets/cut_text.inc assets/player_anim_text.inc assets/text_script_text.inc assets/pokemart_text.inc assets/overworld_sign_text.inc assets/pokecenter_chansey_text.inc assets/elevator_text.inc assets/oaks_aide_text.inc assets/in_game_trade_text.inc assets/vending_machine_text.inc assets/prize_menu_text.inc &: \
                            assets/gb_charmap.txt tools/generators/gen_overworld_strings.py tools/generators/gb_text.py \
                            tools/generators/gen_battle_text.py ../data/text/text_1.asm ../data/text/text_3.asm ../data/text/text_7.asm ../data/text/text_8.asm ../data/text/text_9.asm ../text/CeladonMartRoof.asm \
                            ../constants/charmap.asm
	python3 tools/generators/gen_overworld_strings.py

# Battle message command streams (pret data/text + engine/battle wrappers, text_far
# flattened). %included by the battle core engine. Generated from the read-only spec.
# The generator globs ../data/text/text_*.asm (TEXT_SRC) and scans every file in its
# BATTLE_SRC list, so depend on both sets — naming only text_2.asm/core.asm meant a
# change to any other source (e.g. text_5.asm, which holds _ChargeMoveEffectText)
# left a stale .inc behind.
assets/battle_text.inc: $(wildcard ../data/text/text_*.asm) \
                        ../engine/battle/core.asm ../engine/battle/effects.asm \
                        ../engine/battle/used_move_text.asm ../engine/battle/experience.asm \
                        ../engine/battle/misc.asm ../engine/battle/end_of_battle.asm \
                        ../engine/battle/print_type.asm ../engine/pokemon/evos_moves.asm \
                        ../constants/charmap.asm include/gb_memmap.inc tools/generators/gen_battle_text.py
	python3 tools/generators/gen_battle_text.py

RUNTIME_STRING_ASSETS := assets/battle_menu_runtime_strings.inc \
	assets/battle_core_runtime_strings.inc assets/effectiveness_runtime_strings.inc \
	assets/anim_show_strings.inc \
	assets/battle_intro_runtime_strings.inc assets/stat_mod_runtime_strings.inc \
	assets/item_runtime_strings.inc assets/status_ailment_runtime_strings.inc \
	assets/home_names_runtime_strings.inc assets/home_text_runtime_strings.inc \
	assets/pallet_runtime_strings.inc
$(RUNTIME_STRING_ASSETS) &: assets/gb_charmap.txt tools/generators/gen_runtime_strings.py \
		tools/generators/gen_battle_text.py ../constants/charmap.asm
	python3 tools/generators/gen_runtime_strings.py
src/engine/battle/battle_menu.o: assets/battle_menu_runtime_strings.inc
src/debug/debug_dump.o: assets/anim_show_strings.inc
src/engine/battle/core.o: assets/battle_core_runtime_strings.inc
src/engine/battle/display_effectiveness.o: assets/effectiveness_runtime_strings.inc
src/engine/battle/init_battle.o: assets/battle_intro_runtime_strings.inc
src/engine/battle/battle_transitions.o: assets/battle_transition_arcs.inc
src/data/battle/stat_mod_names.o: assets/stat_mod_runtime_strings.inc
src/engine/items/item_effects.o: assets/item_runtime_strings.inc
src/engine/pokemon/status_ailments.o: assets/status_ailment_runtime_strings.inc
src/home/names.o: assets/home_names_runtime_strings.inc
src/home/text.o: assets/home_text_runtime_strings.inc
src/scripts/PalletTown.o: assets/pallet_runtime_strings.inc

# Trainer rosters + class names (consumed by read_trainer_party.asm / GetName).
assets/trainer_parties.inc: ../data/trainers/parties.asm ../data/trainers/special_moves.asm \
                            ../constants/trainer_constants.asm tools/generators/gen_trainer_parties.py
	python3 tools/generators/gen_trainer_parties.py
assets/trainer_names.inc: ../data/trainers/names.asm ../constants/charmap.asm \
                          tools/generators/gen_trainer_names.py
	python3 tools/generators/gen_trainer_names.py
# Move-use sentence-grammar table (vestigial in English; carried for faithfulness).
assets/move_grammar.inc: ../data/moves/grammar.asm ../constants/move_constants.asm \
                         tools/generators/gen_move_grammar.py
	python3 tools/generators/gen_move_grammar.py
# Type names (raw-id-indexed pointer table, 0x09-0x13 gap -> NORMAL).
assets/type_names.inc: ../data/types/names.asm ../constants/type_constants.asm \
                       ../constants/charmap.asm tools/generators/gen_type_names.py
	python3 tools/generators/gen_type_names.py

# Wrapper objects depend on their generated includes.
src/data/trainer_data.o: assets/trainer_parties.inc assets/trainer_names.inc
src/data/move_grammar.o: assets/move_grammar.inc
src/data/type_names.o: assets/type_names.inc

assets/battle_hud_2bpp.inc: ../gfx/battle/battle_hud_1.png ../gfx/battle/battle_hud_2.png \
                            ../gfx/battle/battle_hud_3.png tools/generators/gen_battle_hud_inc.py
	python3 tools/generators/gen_battle_hud_inc.py

# ---------------------------------------------------------------------------
# The DPMI host. `image` needs it to build PKMN.IMG, but it is a third-party
# binary we deliberately do NOT commit (see the licensing note in
# tools/setup_toolchain.py), so a fresh clone has no copy and make used to stop
# with a bare
#     make: *** No rule to make target 'CWSDPMI.EXE', needed by 'image'.
# right after a successful "Built: PKMN.EXE" -- reported 2026-08-09.
#
# setup_toolchain.py fetches it into .toolchain/ on both Windows and Linux (it
# is a DOS binary; the host OS is irrelevant). Copy it from there if present,
# and otherwise say what to run rather than naming a file with no rule.
$(DPMI_HOST):
	@if [ -f ../.toolchain/cwsdpmi/bin/$(DPMI_HOST) ]; then \
	    echo "copying $(DPMI_HOST) from .toolchain/"; \
	    cp ../.toolchain/cwsdpmi/bin/$(DPMI_HOST) $@; \
	else \
	    echo "$(DPMI_HOST) is missing -- it is the DPMI host PKMN.EXE needs to run."; \
	    echo "Fetch it with:"; \
	    echo "    python3 tools/setup_toolchain.py"; \
	    echo "or download csdpmi7b.zip from"; \
	    echo "    http://www.delorie.com/pub/djgpp/current/v2misc/"; \
	    echo "and put $(DPMI_HOST) in dos_port/."; \
	    exit 1; \
	fi

# ---------------------------------------------------------------------------
# pret graphics as prerequisites (../gfx/**.1bpp / .2bpp).
#
# These are BUILD OUTPUTS of the root Makefile, not committed files: 585 of them
# exist after a root build and *zero* are tracked. 30 are prerequisites of
# targets in this file. Without a rule, a fresh clone dies with
#
#     make: *** No rule to make target '../gfx/font/P.1bpp',
#           needed by 'assets/ptile_2bpp.inc'.  Stop.
#
# which names the missing file but not the cause — the root `make` was never run,
# or (the common one) it stopped early because rgbds was not on PATH, so only the
# graphics it had reached before dying exist. Reported by a first-time builder
# 2026-08-09; the message sent them looking for a file to create by hand.
#
# Delegating to the root Makefile fixes both halves: if the tree is merely
# un-bootstrapped the file just gets built, and if the real problem is a missing
# rgbds then rgbgfx's own error surfaces instead of a misleading make error.
# `+` marks these as recursive make so -n/-j propagate correctly.
../gfx/%.1bpp:
	@echo "$@ is a pret build output and is missing — building it via the root Makefile"
	+$(MAKE) -C .. gfx/$*.1bpp

../gfx/%.2bpp:
	@echo "$@ is a pret build output and is missing — building it via the root Makefile"
	+$(MAKE) -C .. gfx/$*.2bpp

# .pic (pkmncompress-compressed sprites) are the same story -- 380 on disk after
# a root build, 0 tracked -- with one extra wrinkle: gen_trainer_pics.py and
# gen_mon_pics.py open them directly to measure st_size, so make never saw them
# as prerequisites and could not know to build them. A missing one surfaced as a
# raw Python traceback (FileNotFoundError on gfx/trainers/youngster.pic) rather
# than a build error. Declaring them turns that into something make can fix.
PRET_PICS := $(addprefix ../,$(shell sed -n 's/.*INCBIN "\(gfx\/[^"]*\.pic\)".*/\1/p' \
                                    ../gfx/pics.asm 2>/dev/null | sort -u))

../gfx/%.pic:
	@echo "$@ is a pret build output and is missing — building it via the root Makefile"
	+$(MAKE) -C .. gfx/$*.pic

# PTile (bold "P" of the status screen's "PP") is a separate blob from the battle
# HUD tiles above: pret loads it in StatusScreen, not in LoadHudTilePatterns. The
# split is what lets src/engine/battle/core.asm %include the HUD blob — which it
# must, since BATTLE_HUD_TILES*_SIZE is assembly-time arithmetic — without
# dragging the status screen's tile in with it.
assets/ptile_2bpp.inc: ../gfx/font/P.1bpp tools/generators/gen_ptile_inc.py
	python3 tools/generators/gen_ptile_inc.py

assets/trainer_pics.inc: ../gfx/pics.asm ../data/trainers/pic_pointers_money.asm \
                         tools/generators/gen_trainer_pics.py $(PRET_PICS)
	python3 tools/generators/gen_trainer_pics.py

# Pokémon front battle sprites (compressed .pic) + dex-ordered MonFrontPics
# pointer/length table for LoadFrontSpriteByMonIndex.
assets/mon_pics.inc: ../data/pokemon/base_stats.asm tools/generators/gen_mon_pics.py $(PRET_PICS)
	python3 tools/generators/gen_mon_pics.py

src/data/mon_pics.o: assets/mon_pics.inc

# CGB palette source data + human-authored colorization deltas.  The .inc is
# Tier-1 generated data; no runtime consumer is linked until colorization R1.
REPAINT_2BPP := $(wildcard assets/colors/repaint/*.2bpp)
assets/colors/palettes.inc: tools/generators/gen_palettes.py tools/gfx_core/palettes.py \
		tools/colors/schema.py assets/colors/palettes.json \
		$(REPAINT_2BPP) \
		../data/sgb/sgb_palettes.asm ../data/sgb/sgb_packets.asm \
		../data/pokemon/palettes.asm ../constants/palette_constants.asm
	python3 tools/generators/gen_palettes.py

src/home/palettes.o: assets/colors/palettes.inc $(REPAINT_2BPP)

assets/bg_map_attributes.inc: tools/generators/gen_bg_attributes.py \
		../data/cgb/bg_map_attributes.asm
	python3 tools/generators/gen_bg_attributes.py

src/engine/gfx/bg_map_attributes.o: assets/bg_map_attributes.inc

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
                        ../constants/ram_constants.asm tools/generators/gen_badge_tiles.py
	python3 tools/generators/gen_badge_tiles.py

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
                      tools/generators/gen_mon_icons_inc.py
	python3 tools/generators/gen_mon_icons_inc.py

src/engine/gfx/mon_icons.o: assets/mon_icons.inc

# Overworld emotion-bubble tiles (2bpp passthrough of gfx/emotes/*.2bpp) for
# EmotionBubble (src/engine/overworld/emotion_bubbles.asm pret mirror).
assets/emotes.inc: ../gfx/emotes/shock.2bpp ../gfx/emotes/question.2bpp \
                   ../gfx/emotes/happy.2bpp ../gfx/emotes/skull.2bpp \
                   ../gfx/emotes/heart.2bpp ../gfx/emotes/bolt.2bpp \
                   ../gfx/emotes/zzz.2bpp ../gfx/emotes/fish.2bpp \
                   tools/generators/gen_emotes.py
	python3 tools/generators/gen_emotes.py

src/engine/overworld/emotion_bubbles.o: assets/emotes.inc

# Ledge-hop shadow sprite (1bpp passthrough of gfx/overworld/shadow.1bpp + pret's
# two dbsprite OAM records) for LoadHoppingShadowOAM
# (src/engine/overworld/ledges.asm pret mirror).
assets/ledge_shadow.inc: ../gfx/overworld/shadow.1bpp \
                         tools/generators/gen_ledge_shadow.py
	python3 tools/generators/gen_ledge_shadow.py

src/engine/overworld/ledges.o: assets/ledge_shadow.inc

# Surfing Pikachu graphics and tilemaps (Tier-1 data from gen_surfing_pikachu.py)
assets/surfing_pikachu.inc assets/surfing_pikachu2.inc assets/surfing_pikachu_tilemaps.inc: ../gfx/surfing_pikachu/surfing_pikachu_1a.2bpp \
                            ../gfx/surfing_pikachu/surfing_pikachu_1b.2bpp \
                            ../gfx/surfing_pikachu/surfing_pikachu_1c.2bpp \
                            ../gfx/surfing_pikachu/surfing_pikachu_2.2bpp \
                            ../gfx/surfing_pikachu/beach_intro.tilemap \
                            ../gfx/surfing_pikachu/use_control_pad.tilemap \
                            ../gfx/surfing_pikachu/to_surf_rad.tilemap \
                            ../gfx/surfing_pikachu/title.tilemap \
                            ../gfx/surfing_pikachu/beach_outro.tilemap \
                            ../gfx/surfing_pikachu/high_score_1.tilemap \
                            ../gfx/surfing_pikachu/high_score_2.tilemap \
                            tools/generators/gen_surfing_pikachu.py tools/generators/gen_globals.py
	python3 tools/generators/gen_surfing_pikachu.py

src/gfx/surfing_pikachu.o: assets/surfing_pikachu.inc
src/engine/minigame/surfing_pikachu.o: assets/surfing_pikachu_tilemaps.inc
src/engine/printer/printer.o: assets/surfing_pikachu2.inc assets/printer_strings.inc
src/engine/printer/printer2.o: assets/printer_gfx.inc

# Game Boy Printer graphics (Tier-1 data from gen_printer_gfx_inc.py)
assets/printer_gfx.inc: ../gfx/printer/hp.1bpp \
                        ../gfx/printer/lv.1bpp \
                        ../gfx/printer/01.2bpp \
                        tools/generators/gen_printer_gfx_inc.py tools/generators/gen_globals.py
	python3 tools/generators/gen_printer_gfx_inc.py

# Game Boy Printer strings (Tier-1 data from gen_printer_strings.py)
assets/printer_strings.inc: ../engine/printer/printer.asm \
                            ../engine/printer/printer2.asm \
                            ../data/text/text_3.asm \
                            assets/gb_charmap.txt \
                            tools/generators/gen_printer_strings.py tools/generators/gen_globals.py tools/generators/gb_text.py
	python3 tools/generators/gen_printer_strings.py

# pikapic (follower Pikachu Phase 4) — Tier-1 data for the Pikachu front-pic
# facial animation engine.  One generated .inc per pret source file.
PIKAPIC_GFX_SRCS := $(wildcard ../gfx/pikachu/*.2bpp) $(wildcard ../gfx/pikachu/*.pic)
assets/pikachu_pic_gfx.inc assets/pikachu_pic_gfx_globals.inc \
assets/pikachu_pic_gfx_externs.inc assets/pikachu_pic_tilemaps.inc \
assets/pikachu_pic_objects.inc assets/pikachu_pic_animation.inc: \
                            ../gfx/pikachu.asm \
                            ../data/pikachu/pikachu_pic_tilemaps.asm \
                            ../data/pikachu/pikachu_pic_objects.asm \
                            ../data/pikachu/pikachu_pic_animation.asm \
                            $(PIKAPIC_GFX_SRCS) \
                            tools/generators/gen_pikachu_pic.py
	python3 tools/generators/gen_pikachu_pic.py

src/gfx/pikachu.o: assets/pikachu_pic_gfx.inc assets/pikachu_pic_gfx_globals.inc
src/data/pikachu/pikachu_pic_tilemaps.o: assets/pikachu_pic_tilemaps.inc
src/data/pikachu/pikachu_pic_objects.o: assets/pikachu_pic_objects.inc
src/data/pikachu/pikachu_pic_animation.o: assets/pikachu_pic_animation.inc \
                                          assets/pikachu_pic_gfx_externs.inc

# home/trainers.asm %includes the generated _TrainerNameText far stream +
# MUSIC_MEET_* ids.
src/home/trainers.o: assets/trainer_text.inc assets/audio_constants.inc
src/engine/battle/used_move_text.o: assets/used_move_text.inc
src/engine/movie/hall_of_fame.o: assets/hall_of_fame_text.inc assets/audio_constants.inc assets/event_constants.inc
src/data/pokemon/unknown_list.o: assets/unknown_list.inc
src/engine/movie/credits.o: assets/credits_data.inc assets/the_end_2bpp.inc assets/audio_constants.inc
src/engine/movie/oak_speech/clear_save.o: assets/clear_save_text.inc
src/engine/pokemon/evos_moves.o: assets/script_constants.inc

# Trainer-card tile graphics (box/bg/blank-names/badge-numbers/colon/circle),
# 2bpp passthrough of gfx/trainer_card/*.2bpp + gfx/font/font_extra.2bpp, for the
# TRAINER CARD screen (DrawTrainerInfo, start_sub_menus.asm). Faces/badges come from
# assets/badge_tiles.inc (package B) via LoadBadgeTiles.
assets/trainer_card_tiles.inc: ../gfx/trainer_card/trainer_info.2bpp \
                               ../gfx/trainer_card/blank_leader_names.2bpp \
                               ../gfx/trainer_card/badge_numbers.2bpp \
                               ../gfx/trainer_card/circle_tile.2bpp \
                               ../gfx/font/font_extra.2bpp \
                               tools/generators/gen_trainer_card_tiles.py
	python3 tools/generators/gen_trainer_card_tiles.py

# Trade-animation tile graphics (link cable / Game Boy pics / cable ball),
# 2bpp passthrough of gfx/trade/*.2bpp, for LoadTradingGFXAndMonNames
# (engine/movie/trade.asm). game_boy.2bpp is built with --remove-duplicates
# (see the root Makefile's tools/gfx rule for it) so its tile count is derived
# from the built file, not the source PNG's pixel dimensions.
assets/trade_tiles.inc: ../gfx/trade/game_boy.2bpp \
                        ../gfx/trade/link_cable.2bpp \
                        ../gfx/trade/cable_ball.2bpp \
                        tools/generators/gen_trade_tiles.py
	python3 tools/generators/gen_trade_tiles.py

# Pokédex interface tiles (2bpp passthrough of gfx/pokedex/pokedex.2bpp + the
# plain pokéball tile from gfx/battle/balls.2bpp) for LoadPokedexTilePatterns.
assets/pokedex_tiles.inc: ../gfx/pokedex/pokedex.2bpp ../gfx/battle/balls.2bpp \
                          tools/generators/gen_pokedex_tiles.py
	python3 tools/generators/gen_pokedex_tiles.py

# Start menu checks EVENT_GOT_POKEDEX via events.inc → event_constants.inc;
# DrawStartMenu %includes the generated menu_strings.inc labels and the
# UI_START_MENU_* equates; start_sub_menus needs the UI_USE_TOSS_* equates.
src/home/overworld_text.o: assets/overworld_sign_text.inc
src/engine/events/oaks_aide.o: assets/oaks_aide_text.inc assets/script_constants.inc
src/engine/events/elevator.o: assets/elevator_text.inc
src/engine/events/pokemart.o: assets/pokemart_text.inc assets/audio_constants.inc
src/engine/events/pokecenter.o: assets/map_text/event_pokecenter.inc assets/audio_constants.inc assets/map_dims.inc
src/engine/events/vending_machine.o: assets/vending_machine_text.inc assets/audio_constants.inc
src/engine/events/prize_menu.o: assets/prize_menu_text.inc
src/engine/events/cinnabar_lab.o: assets/map_text/.stamp
src/data/events/prizes.o: assets/script_constants.inc
src/data/events/prize_mon_levels.o: assets/script_constants.inc
src/engine/events/set_blackout_map.o: include/gb_memmap.inc
src/data/maps/rest_house_maps.o: assets/map_dims.inc
src/engine/events/card_key.o: assets/card_key_maps.inc assets/predef_text_ids.inc \
                              assets/script_constants.inc assets/audio_constants.inc
src/engine/events/poison.o: assets/script_constants.inc assets/audio_constants.inc \
                            include/gb_memmap.inc include/gb_constants.inc
src/engine/events/in_game_trades.o: assets/in_game_trade_text.inc \
                                     assets/trade_trainer_string.inc \
                                     assets/script_constants.inc
src/data/events/trades.o: assets/trades.inc assets/script_constants.inc
src/engine/events/diploma2.o: assets/diploma_text.inc assets/diploma_tiles.inc
src/engine/events/pokecenter_chansey.o: assets/pokecenter_chansey_text.inc \
                                        assets/script_constants.inc
src/home/start_menu.o: assets/event_constants.inc assets/audio_constants.inc
src/engine/menus/draw_start_menu.o: assets/event_constants.inc \
        assets/menu_strings.inc assets/ui_layout_menus.inc
src/engine/menus/start_sub_menus.o: assets/ui_layout_menus.inc assets/audio_constants.inc \
        assets/menu_text.inc assets/trainer_card_tiles.inc assets/trainer_card_strings.inc
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
src/engine/menus/pokedex.o: assets/ui_layout_menus.inc \
        assets/pokedex_strings.inc
src/data/pokemon/dex_entries.o: assets/dex_entries.inc
src/engine/gfx/load_pokedex_tiles.o: assets/pokedex_tiles.inc
src/engine/menus/link_menu.o: assets/ui_layout_menus.inc assets/link_text.inc
src/engine/link/cable_club_npc.o: assets/link_npc_text.inc assets/event_constants.inc assets/audio_constants.inc
src/net/link_ui.o: assets/ui_layout_menus.inc assets/link_ui_strings.inc

# Trade animation (link plan Stage 3 step 3): tile graphics + the 8 far text
# bodies (trade.asm), and the raw Trade_MonInfoText glyph run (trade2.asm).
src/engine/movie/trade.o: assets/trade_tiles.inc assets/trade_text.inc \
                          assets/battle_anim_constants.inc assets/audio_constants.inc \
                          assets/ui_layout_intro.inc
src/engine/movie/trade2.o: assets/trade_mon_info_text.inc assets/ui_layout_intro.inc

# Status screen %includes the generated status_strings.inc label block.
src/engine/pokemon/status_screen.o: assets/status_strings.inc

# player_state.asm (PrintSafariZoneSteps) %includes the generated Safari HUD strings.
src/engine/overworld/player_state.o: assets/overworld_strings.inc

# field_move_messages.asm %includes the generated field-move FAR text streams.
src/engine/overworld/field_move_messages.o: assets/field_move_text.inc

# cut.asm %includes the generated cut FAR text streams.
src/engine/overworld/cut.o: assets/cut_text.inc
src/engine/overworld/player_animations.o: assets/player_anim_text.inc

# Pokémon base stats + PokedexOrder (static data, generated from pret source).
assets/base_stats.inc assets/dex_order.inc:
	python3 tools/generators/gen_base_stats.py

src/data/pokemon/dex_order.o: assets/dex_order.inc

# GrowthRateTable (static data, generated from data/growth_rates.asm).
assets/growth_rates.inc:
	python3 tools/generators/gen_growth_rates.py

# Moves table (static data, generated from data/moves/moves.asm).
assets/moves.inc:
	python3 tools/generators/gen_moves.py

# Evolution + level-up learnset data (generated from data/pokemon/evos_moves.asm).
assets/evos_moves.inc:
	python3 tools/generators/gen_evos_moves.py

# Species names (generated from data/pokemon/names.asm via the GB charmap).
assets/monster_names.inc:
	python3 tools/generators/gen_monster_names.py

# Item tables (generated from data/items/ + data/moves/tmhm_moves.asm). One .inc
# per pret source file, plus items.inc for the tables with no single pret home
# (marts, VitaminStats, UsableItems_*) — docs/current_plan_data_path_mirror.md.
assets/items.inc assets/item_names.inc assets/item_prices.inc \
assets/key_item_flags.inc assets/tm_prices.inc assets/tmhm_moves.inc &:
	python3 tools/generators/gen_items.py

# Item-use message streams (pret engine/items + engine/menus/party_menu wrappers,
# text_far flattened — same encoder as gen_battle_text.py). Consumed by the item
# USE dispatcher and the party menu's item-use result message.
assets/item_text.inc: ../engine/items/item_effects.asm ../engine/menus/party_menu.asm \
                      ../engine/items/tmhm.asm ../home/pokemon.asm \
                      ../constants/charmap.asm include/gb_memmap.inc \
                      tools/generators/gen_battle_text.py tools/generators/gen_item_text.py assets/battle_text.inc
	python3 tools/generators/gen_item_text.py

assets/diploma_text.inc assets/diploma_tiles.inc &: ../engine/events/diploma2.asm \
                  ../gfx/diploma/diploma.2bpp ../gfx/diploma/diploma_pikachu.tilemap \
                  ../gfx/diploma/diploma_mew.tilemap ../constants/charmap.asm \
                  assets/gb_charmap.txt \
                  tools/generators/gen_diploma.py tools/generators/gb_text.py
	python3 tools/generators/gen_diploma.py

assets/trades.inc assets/trade_trainer_string.inc &: ../data/events/trades.asm ../constants/charmap.asm \
                   assets/gb_charmap.txt \
                   tools/generators/gen_trades.py tools/generators/gb_text.py
	python3 tools/generators/gen_trades.py

assets/marts.inc: ../data/items/marts.asm ../macros/scripts/text.asm \
                  tools/generators/gen_marts.py
	python3 tools/generators/gen_marts.py

src/data/item_data.o: assets/items.inc
src/data/items/marts.o: assets/marts.inc
src/data/items/names.o: assets/item_names.inc
src/data/items/prices.o: assets/item_prices.inc
src/data/items/key_items.o: assets/key_item_flags.inc
src/data/items/tm_prices.o: assets/tm_prices.inc
src/data/moves/tmhm_moves.o: assets/tmhm_moves.inc
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

src/data/pokemon/base_stats.o: assets/base_stats.inc
src/data/growth_rates.o: assets/growth_rates.inc
src/data/moves/moves.o: assets/moves.inc
src/data/pokemon/evos_moves.o: assets/evos_moves.inc
src/data/pokemon/names.o: assets/monster_names.inc

# Type effectiveness table (static data, generated from data/types/type_matchups.asm).
assets/type_matchups.inc:
	python3 tools/generators/gen_type_matchups.py

# Move names (generated from data/moves/names.asm via the GB charmap; '@'-terminated).
assets/move_names.inc:
	python3 tools/generators/gen_move_names.py

# Move-effect category lists (generated from data/battle/*.asm; $FF-terminated).
# One .inc per pret source file, so each carrier .asm can live at its mirrored
# path (docs/current_plan_data_path_mirror.md).
assets/residual_effects_1.inc assets/residual_effects_2.inc \
assets/special_effects.inc assets/always_happen_effects.inc \
assets/set_damage_effects.inc &:
	python3 tools/generators/gen_effect_categories.py

src/data/types/type_matchups.o: assets/type_matchups.inc
src/data/moves/names.o: assets/move_names.inc
src/data/battle/residual_effects_1.o: assets/residual_effects_1.inc
src/data/battle/residual_effects_2.o: assets/residual_effects_2.inc
src/data/battle/special_effects.o: assets/special_effects.inc
src/data/battle/always_happen_effects.o: assets/always_happen_effects.inc
src/data/battle/set_damage_effects.o: assets/set_damage_effects.inc

# Naming-screen letter grids + <ED> toggle tile (menus S7, package C). Generated
# from data/text/alphabets.asm + constants/charmap.asm + gfx/font/ED.1bpp.
assets/alphabets.inc: ../data/text/alphabets.asm ../constants/charmap.asm \
                      ../gfx/font/ED.1bpp tools/generators/gen_alphabets.py
	python3 tools/generators/gen_alphabets.py

# Keyboard text-entry scancode->charmap tables (link cable plan Stage 5 step
# 1: src/input/kbd_text.asm). Port-only US-keyboard layout data — no pret
# source, but the byte values still route through gb_text.encode() (the GB
# charmap), not hand-transcribed hex.
assets/kbd_scancode_map.inc: tools/generators/gen_kbd_naming.py assets/gb_charmap.txt
	python3 tools/generators/gen_kbd_naming.py

src/input/kbd_text.o: assets/kbd_scancode_map.inc

# Pikachu emotion-command text (ExpressionText). Generated from
# engine/pikachu/pikachu_emotions.asm + data/text/text_3.asm + constants/charmap.asm.
assets/pikachu_text.inc: ../engine/pikachu/pikachu_emotions.asm ../data/text/text_3.asm \
                         ../constants/charmap.asm tools/generators/gen_battle_text.py \
                         tools/generators/gen_pikachu_text.py
	python3 tools/generators/gen_pikachu_text.py

src/engine/pikachu/pikachu_emotions.o: assets/pikachu_text.inc

# School-blackboard hidden-event text (Viridian School blackboard + link-cable
# help). Generated from engine/events/hidden_events/school_blackboard.asm +
# data/text/text_2.asm + constants/charmap.asm.
assets/school_blackboard_text.inc: ../engine/events/hidden_events/school_blackboard.asm \
                         ../data/text/text_2.asm ../constants/charmap.asm \
                         assets/gb_charmap.txt tools/generators/gb_text.py \
                         tools/generators/gen_battle_text.py \
                         tools/generators/gen_school_blackboard_text.py
	python3 tools/generators/gen_school_blackboard_text.py

src/engine/events/hidden_events/school_blackboard.o: assets/school_blackboard_text.inc
# Cinnabar gym quiz message streams (the 10 pure text_far wrappers + the
# CinnabarGymQuizCorrectText far body). Generated from
# engine/events/hidden_events/cinnabar_gym_quiz.asm + data/text/text_2.asm.
assets/cinnabar_gym_quiz_text.inc: ../engine/events/hidden_events/cinnabar_gym_quiz.asm \
                         ../data/text/text_2.asm ../constants/charmap.asm \
                         tools/generators/gen_battle_text.py \
                         tools/generators/gen_cinnabar_gym_quiz_text.py
	python3 tools/generators/gen_cinnabar_gym_quiz_text.py

# Bench guys text streams and BenchGuyTextPointers table.
assets/bench_guys_text.inc: ../engine/events/hidden_events/bench_guys.asm \
                         ../data/events/bench_guys.asm ../data/text/text_2.asm \
                         ../constants/charmap.asm tools/generators/gen_battle_text.py \
                         tools/generators/gen_bench_guys_text.py
	python3 tools/generators/gen_bench_guys_text.py

# Book or sculpture text streams.
assets/book_or_sculpture_text.inc: ../engine/events/hidden_events/book_or_sculpture.asm \
                         ../data/text/text_2.asm ../constants/charmap.asm \
                         tools/generators/gen_battle_text.py \
                         tools/generators/gen_book_or_sculpture_text.py
	python3 tools/generators/gen_book_or_sculpture_text.py

# Indigo Plateau statues message streams (the 3 pure text_far wrappers). Generated from
# engine/events/hidden_events/indigo_plateau_statues.asm + data/text/text_2.asm.
assets/indigo_plateau_statues_text.inc: ../engine/events/hidden_events/indigo_plateau_statues.asm \
                         ../data/text/text_2.asm ../constants/charmap.asm \
                         tools/generators/gen_battle_text.py \
                         tools/generators/gen_indigo_plateau_statues_text.py
	python3 tools/generators/gen_indigo_plateau_statues_text.py

# Map badge flags table (MapBadgeFlags). Generated from data/maps/badge_maps.asm.
assets/badge_maps.inc: ../data/maps/badge_maps.asm tools/generators/gen_badge_maps.py
	python3 tools/generators/gen_badge_maps.py
# Pokédex-rating text (DexCompletionText + the 16 DexRatingText_Own<N>To<M>
# bands). Generated from engine/events/pokedex_rating.asm (the wrapper
# labels) + text/pokedex_ratings.asm (the far bodies, incl. the two
# text_decimal fields against hDexRatingNumMonsSeen/hDexRatingNumMonsOwned)
# + constants/charmap.asm.
assets/pokedex_rating_text.inc: ../engine/events/pokedex_rating.asm ../text/pokedex_ratings.asm \
                                ../constants/charmap.asm include/gb_memmap.inc \
                                tools/generators/gen_battle_text.py \
                                tools/generators/gen_pokedex_rating_text.py
	python3 tools/generators/gen_pokedex_rating_text.py

src/engine/events/pokedex_rating.o: assets/pokedex_rating_text.inc assets/event_constants.inc
# Safari Zone game over text (TimesUpText, GameOverText). Generated from
# engine/events/hidden_events/safari_game.asm + data/text/text_2.asm + constants/charmap.asm.
assets/safari_text.inc: ../engine/events/hidden_events/safari_game.asm ../data/text/text_2.asm \
                        ../constants/charmap.asm tools/generators/gen_battle_text.py \
                        tools/generators/gen_safari_text.py
	python3 tools/generators/gen_safari_text.py

src/engine/events/hidden_events/safari_game.o: assets/safari_text.inc

# Naming-screen kana voicing tables (Dakutens / Handakutens). Generated from
# data/text/dakutens.asm + constants/charmap.asm; carrier src/data/text/dakutens.asm.
assets/dakutens.inc: ../data/text/dakutens.asm ../constants/charmap.asm \
                     tools/generators/gen_alphabets.py tools/generators/gen_dakutens.py
	python3 tools/generators/gen_dakutens.py

src/data/text/dakutens.o: assets/dakutens.inc

# Pokédex entries (menus S8, package G2 / I2). dex_entries = PokedexEntryPointers
# (flat dd) + inlined per-mon name/height/weight/flavor blobs (text_far flavor
# inlined). NOTE: the index->dex order table pret keeps as PokedexOrder is NOT
# regenerated here — the port already ships that exact byte table as the global
# `PokedexOrder` (src/data/pokemon/dex_order.asm); pokedex.asm walks it.
assets/dex_entries.inc: ../data/pokemon/dex_entries.asm ../data/pokemon/dex_text.asm \
                        ../constants/charmap.asm tools/generators/gen_dex_entries.py
	python3 tools/generators/gen_dex_entries.py

# Field-move display data + names (generated from data/moves/{field_moves,
# field_move_names}.asm; resolves move ids via constants/move_constants.asm).
assets/field_moves.inc assets/field_move_names.inc &:
	python3 tools/generators/gen_field_moves.py

src/data/moves/field_moves.o: assets/field_moves.inc
src/data/moves/field_move_names.o: assets/field_move_names.inc

# DisplayTextBoxID_ tables embed the generated UI layout geometry (menus S2);
# the BATTLE/SAFARI template rows come from the battle layout (battle-UI B5).
# DisplayTextIDInit checks EVENT_GOT_POKEDEX via events.inc → event_constants.inc.
src/engine/menus/text_box.o: assets/ui_layout_menus.inc assets/ui_layout_battle.inc \
        assets/textbox_strings.inc assets/yes_no_strings.inc
src/home/list_menu.o: assets/list_menu_strings.inc
src/debug/debug_dump.o: $(if $(DEBUG_TEXT),assets/text_oracle.inc)
src/debug/debug_dump.o: assets/scenario_registry.inc
src/engine/menus/display_text_id_init.o: assets/event_constants.inc

# UI layout geometry — projected menu-window coordinates. The sidecar JSON is
# hand-positioned via tools/ui_layout/editor.py (never hand-edited as text);
# the .inc is Tier-1 machine output keyed by element ID (docs/plans/menus.md).
assets/ui_layout_menus.inc: assets/ui_layout_menus_sidecar.json \
		tools/generators/gen_ui_layout.py tools/ui_layout/canvas.py tools/ui_layout/schema.py
	python3 tools/generators/gen_ui_layout.py menus

# Battle UI layout geometry (docs/plans/battle_ui.md). Sidecar seeded
# from the legacy battle %defines by tools/ui_layout/seed_from_battle.py
# (asserts byte-identical geometry); redesigned via tools/ui_layout/battle.py.
assets/ui_layout_battle.inc: assets/ui_layout_battle_sidecar.json \
		tools/generators/gen_ui_layout.py tools/ui_layout/canvas.py tools/ui_layout/schema.py
	python3 tools/generators/gen_ui_layout.py battle

src/engine/battle/init_battle.o \
src/engine/battle/pokeballs.o src/home/pics.o \
src/engine/battle/core.o src/engine/battle/battle_menu.o: \
        assets/ui_layout_battle.inc

# Cinematic (boot movie) UI layout geometry — docs/current_plan_menu_intro.md.
# All four elements are the same full 160x144 GB surface centered on the 40x25
# canvas (COL=10 ROW=3, WX=87 -> screen x 80, WY=24, CLIP=160, MAXY=168); they
# are separate IDs so each screen owns and restores its own descriptor state.
# Deliberately NOT widescreen-expanded: cinematic framing, slide distances and
# screen-edge timing are authored against the GB viewport.
assets/ui_layout_intro.inc: assets/ui_layout_intro_sidecar.json \
		tools/generators/gen_ui_layout.py tools/ui_layout/canvas.py tools/ui_layout/schema.py
	python3 tools/generators/gen_ui_layout.py intro

# Authored map border-ring overrides (map-tool C3): painted in
# tools/map_editor/editor.py paint mode -> assets/map_borders/*.json ->
# this Tier-1 .inc, consumed by overworld.asm ApplyMapBorderOverrides.
assets/map_border_overrides.inc: $(wildcard assets/map_borders/*.json) \
		tools/generators/gen_map_borders.py tools/map_editor/borders.py \
		tools/map_editor/view.py tools/gfx_core/pret_maps.py
	python3 tools/generators/gen_map_borders.py

src/engine/overworld/overworld.o: assets/map_border_overrides.inc

# Wild-encounter tables (static data, generated from data/wild/).
assets/wild_grass_water.inc assets/wild_probabilities.inc &:
	python3 tools/generators/gen_wild_encounters.py

src/data/wild/grass_water.o: assets/wild_grass_water.inc
src/data/wild/probabilities.o: assets/wild_probabilities.inc

# Super Rod fishing slots + Good Rod pair (generated from data/wild/
# {super_rod,good_rod}.asm; internal-index species). super_rod.inc is embedded
# by super_rod.asm, good_rod.inc by item_effects.asm (ItemUseGoodRod).
assets/super_rod.inc assets/good_rod.inc &:
	python3 tools/generators/gen_super_rod.py

src/engine/items/super_rod.o: assets/super_rod.inc
src/engine/items/item_effects.o: assets/good_rod.inc

# Town-map data + graphics (generated from data/maps/{town_map_entries,
# town_map_order,names}.asm + gfx/town_map/). Consumed by town_map.asm.
assets/town_map_data.inc assets/town_map_gfx.inc:
	python3 tools/generators/gen_town_map.py

src/engine/items/town_map.o: assets/town_map_data.inc assets/town_map_gfx.inc

# CanLearnTM/TMToMove index TechnicalMachines (assets/tmhm_moves.inc, gen_items.py).
src/engine/items/tms.o: assets/tmhm_moves.inc

assets: assets/pret_ram.inc assets/scenario_registry.inc assets/gb_charmap.txt \
        assets/overworld_gfx.inc assets/overworld_blocks.inc assets/pallet_town_blk.inc \
        assets/map_headers.inc assets/extra_includes.inc assets/map_dims.inc \
        assets/map_songs.inc \
        assets/pair_collision_tile_ids.inc assets/ledge_tiles.inc \
        assets/bike_riding_tilesets.inc assets/card_key_coords.inc \
        assets/card_key_maps.inc \
        assets/sgb_packets.inc \
        assets/vermilion_gym_trash_text.inc \
        assets/town_map_text.inc \
        assets/copyright_text.inc \
        assets/npc_sprite_data_table.inc assets/npc_dialogs/all_dialogs.inc \
        assets/red_bike_sprite.inc assets/seel_sprite.inc \
        assets/surfing_pikachu_sprite.inc assets/surfing_pikachu.inc \
        assets/surfing_pikachu_tilemaps.inc \
        assets/printer_gfx.inc assets/printer_strings.inc \
        assets/pikachu_pic_gfx.inc assets/pikachu_pic_tilemaps.inc \
        assets/pikachu_pic_objects.inc assets/pikachu_pic_animation.inc \
        assets/toggleable_objects.inc assets/event_constants.inc \
        assets/script_constants.inc assets/map_text/.stamp \
        assets/base_stats.inc assets/growth_rates.inc \
        assets/moves.inc assets/evos_moves.inc assets/monster_names.inc \
        assets/items.inc assets/item_names.inc assets/item_prices.inc \
        assets/key_item_flags.inc assets/tm_prices.inc assets/tmhm_moves.inc \
        assets/marts.inc \
        assets/item_text.inc assets/menu_strings.inc \
        assets/naming_strings.inc assets/pokedex_strings.inc \
        assets/bills_pc_text.inc assets/bills_house_pc_text.inc \
        assets/status_strings.inc assets/textbox_strings.inc assets/menu_text.inc \
		$(RUNTIME_STRING_ASSETS) \
        assets/list_menu_strings.inc assets/yes_no_strings.inc \
        assets/script_strings.inc \
        assets/text_oracle.inc \
        assets/overworld_strings.inc assets/field_move_text.inc assets/overworld_sign_text.inc assets/pokecenter_chansey_text.inc \
        assets/elevator_text.inc assets/oaks_aide_text.inc \
        assets/in_game_trade_text.inc assets/trades.inc \
        assets/diploma_text.inc assets/diploma_tiles.inc \
        assets/trade_trainer_string.inc \
        assets/cut_text.inc assets/player_anim_text.inc \
        assets/type_matchups.inc assets/move_names.inc assets/field_moves.inc \
        assets/field_move_names.inc \
        assets/residual_effects_1.inc assets/residual_effects_2.inc \
        assets/special_effects.inc assets/always_happen_effects.inc \
        assets/set_damage_effects.inc \
        assets/wild_grass_water.inc assets/wild_probabilities.inc \
        assets/map_scripts.inc assets/trainer_headers.inc \
        assets/map_script_tables.inc \
        assets/hidden_events.inc \
        assets/hidden_item_coords.inc assets/pickup_text.inc \
        assets/hidden_coin_coords.inc assets/hidden_items_text.inc \
        assets/school_notebooks_text.inc \
        assets/bench_guys_text.inc \
        assets/book_or_sculpture_text.inc \
        assets/give_pokemon_text.inc \
        assets/predef_text.inc \
        assets/predef_text_ids.inc \
        assets/oak_speech_strings.inc \
        assets/default_names.inc \
        assets/debug_boot_names.inc \
        assets/battle_hud_2bpp.inc assets/ptile_2bpp.inc \
        assets/battle_transition_arcs.inc \
        assets/battle_anim_constants.inc assets/moves_animations.inc \
        assets/subanimations.inc assets/frame_blocks.inc \
        assets/base_coords.inc assets/move_sfx.inc \
        assets/trainer_pics.inc \
        assets/super_rod.inc assets/good_rod.inc \
        assets/town_map_data.inc assets/town_map_gfx.inc \
        assets/ui_layout_menus.inc assets/ui_layout_battle.inc \
        assets/ui_layout_intro.inc \
        assets/map_border_overrides.inc assets/badge_tiles.inc \
        assets/trainer_card_tiles.inc assets/trainer_card_strings.inc \
        assets/trainer_text.inc \
        assets/party_menu_strings.inc assets/home_pokemon_strings.inc assets/emotes.inc assets/ledge_shadow.inc \
        assets/options_strings.inc \
        assets/alphabets.inc assets/dakutens.inc assets/pikachu_text.inc assets/school_blackboard_text.inc assets/dex_entries.inc assets/sprite_sets.inc \
        assets/alphabets.inc assets/dakutens.inc assets/pikachu_text.inc assets/cinnabar_gym_quiz_text.inc assets/dex_entries.inc assets/sprite_sets.inc \
        assets/indigo_plateau_statues_text.inc assets/badge_maps.inc \
        assets/alphabets.inc assets/dakutens.inc assets/pikachu_text.inc assets/pokedex_rating_text.inc assets/dex_entries.inc assets/sprite_sets.inc \
        assets/sprite_sheet_pointers.inc assets/pokedex_tiles.inc \
        assets/mon_pics.inc \
		assets/colors/palettes.inc \
        assets/bg_map_attributes.inc \
        assets/audio_rom.inc assets/audio_constants.inc assets/cry_data.inc \
        assets/opl_patches.inc assets/music_streams.inc assets/mt32_sysex.inc \
        assets/pika_pcm.inc assets/tandy_tables.inc assets/enh_streams.inc \
        assets/mon_icons.inc \
        assets/save_text.inc assets/main_menu_text.inc assets/league_pc_text.inc \
        assets/players_pc_text.inc assets/link_text.inc assets/link_npc_text.inc assets/oaks_pc_text.inc \
        assets/pc_text.inc assets/slots_text.inc assets/safari_text.inc \
        assets/cable_club_text.inc assets/trade_tiles.inc assets/trade_text.inc \
        assets/trade_mon_info_text.inc \
        assets/kbd_scancode_map.inc assets/link_ui_strings.inc
	python3 tools/audit_memmap.py

assets/scenario_registry.inc: tools/scenario_manifest.json tools/generators/gen_scenario_registry.py
	python3 tools/generators/gen_scenario_registry.py

# Battle-transition circle-wipe arc tables (40x25 regeneration of pret's
# CircleData/HalfCircle tables; self-checked by an embedded Sub3 emulator).
assets/battle_transition_arcs.inc: tools/generators/gen_battle_transition_arcs.py
	python3 tools/generators/gen_battle_transition_arcs.py

# Battle move-animation data (command streams, subanimations, frame blocks,
# base coords, move sound table + the anim/SE constants). GB-space raw; the
# battle-frame projection is applied by code. ROM-cross-checked when the golden
# worktree is present. All six .incs come from one generator run; the data half
# is one .inc per pret source file (docs/current_plan_data_path_mirror.md).
assets/battle_anim_constants.inc assets/moves_animations.inc \
assets/subanimations.inc assets/frame_blocks.inc assets/base_coords.inc \
assets/move_sfx.inc &: \
		tools/generators/gen_battle_anim_data.py \
		../data/moves/animations.asm ../data/moves/sfx.asm \
		../data/battle_anims/subanimations.asm ../data/battle_anims/frame_blocks.asm \
		../data/battle_anims/base_coords.asm \
		../constants/move_constants.asm ../constants/move_animation_constants.asm \
		../constants/battle_anim_constants.asm ../constants/gfx_constants.asm
	python3 tools/generators/gen_battle_anim_data.py

src/data/moves/animations.o: assets/moves_animations.inc
src/data/battle_anims/subanimations.o: assets/subanimations.inc
src/data/battle_anims/frame_blocks.o: assets/frame_blocks.inc
src/data/battle_anims/base_coords.o: assets/base_coords.inc
src/data/moves/sfx.o: assets/move_sfx.inc assets/audio_constants.inc

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

# PKMN.EXE is stripped ONLY when STRIP=1. Every binary is a DEBUG binary until the
# port is complete (maintainer, 2026-08-19), so the default build keeps its symbol
# table. Stripping will be wanted at release; the recipe is kept working so it is
# not rediscovered then.
#
# NASM emits every `equ` as a local ABSOLUTE COFF symbol even without `global`, and
# essentially every file includes the big constant assets (event_constants.inc,
# script_constants.inc, gb_memmap.inc). The result was ~2.1 MILLION symbol entries:
# a 39 MB PKMN.EXE against ~2.4 MB of real .text+.data, i.e. 94% symbol table. A
# single map-script object was 143 KB carrying 78 BYTES of .text.
#
# That is pure file size -- the go32 stub loads only the section extents, so it cost
# no runtime memory -- but PKMN.IMG inherits it, and tools/pgate.sh copies the image
# PER SCENARIO across the 85-scenario suite.
#
# Ordering is load-bearing: gen_symfile runs BEFORE the strip, so pkmn.sym keeps
# every symbol (including NASM local labels like _AdvancePlayerSprite.scroll, which
# dosbox-mcp resolves against), while the shipped EXE carries none. The trailing
# `touch` keeps pkmn.sym NEWER than the EXE -- the MCP symbol server treats an EXE
# newer than its symbol file as stale and refuses to resolve.
$(TARGET): $(LINK_OBJS) link.ld
	$(LD) $(LDFLAGS) -Map=pkmn.map $(LINK_OBJS) -o $@
	$(OBJDUMP) -t $@ | python3 tools/generators/gen_symfile.py > pkmn.sym
ifeq ($(STRIP),1)
	$(OBJCOPY) --strip-all $@ $@.tmp && mv -f $@.tmp $@
	@touch pkmn.sym
endif
	@echo "Built: $@ ($$(stat -c%s $@) bytes)"

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
# rebuild when an asset input actually changed, not on every make.
#
# *** INC_DEPS CANNOT CREATE ORDERING, ONLY FRESHNESS. *** `$(wildcard ...)` is
# expanded when this Makefile is PARSED, so in a tree where assets/ has not been
# generated yet it expands to NOTHING and the objects end up with no dependency
# on the generated headers at all. Nothing then pulls the generator rules in, so
# `make` goes straight to assembling and dies on
#     error: unable to open include file `assets/battle_anim_constants.inc'
# This is NOT a parallelism race and `-j1` does not avoid it — measured
# 2026-08-15 on a fresh worktree: -j1 and -j96 both fail identically. It never
# bites a working tree because assets/ is already populated there, which is
# exactly why it survived: it is invisible to everyone who has built once.
#
# The order-only prerequisite below is what supplies the ordering. `assets` is
# .PHONY, so it is considered on every build, but its own prerequisites are real
# timestamped files, so it is a no-op once generated — and being order-only, it
# never forces an object to rebuild just because the phony target ran.
INC_DEPS := $(wildcard include/*.inc) $(wildcard assets/*.inc) \
            $(wildcard assets/npc_dialogs/*.inc) \
            src/data/maps/special_warps.asm

%.o: %.asm $(NASMFLAGS_STAMP) $(INC_DEPS) | assets
	$(NASM) $(NASMFLAGS) -o $@ $<

# Assemble-only check (no link): useful for syntax verification
# The STATIC gate (backlog item 4). Fast, no emulator, no ROM, no golden: the
# label linters against a checked-in per-class baseline, the label-DB pytest
# suite, and the scenario-manifest validator. Every one of these used to be
# manual and therefore skippable, which is exactly how the strict-claims counts
# in CLAUDE.md went stale and how two test_label_db.py tests stayed red for
# sessions. See tools/static_gate's docstring for the full reasoning.
# NOT tools/fidelity_gate — that is the per-change, per-label evidence chain.
#
# This is NOT a substitute for `make fidelity` / `fidelity-full`. It proves the
# absence of structural and bookkeeping drift; it proves nothing about
# behaviour. Run the runtime tier for anything that can move a pixel or a WRAM
# byte.
static_gate:
	@tools/static_gate $(GATEFLAGS)

# Point git at the tracked hook directory, so the static gate runs on every
# commit without anyone having to remember. Opt-in and reversible:
#   make install-hooks     -> git config core.hooksPath .githooks
#   git config --unset core.hooksPath   (to undo)
# A tracked .githooks/ beats .git/hooks/ because it is version-controlled and
# reviewable; .git/hooks/ is per-clone and invisible to everyone else.
install-hooks:
	@git -C .. config core.hooksPath .githooks
	@echo "core.hooksPath -> .githooks (pre-commit runs 'make -C dos_port static_gate')"
	@echo "Undo with: git config --unset core.hooksPath"
	@echo "Bypass one commit with: git commit --no-verify"

check:
	@for src in $(ALL_SRCS); do \
	    echo "Checking: $$src"; \
	    $(NASM) $(NASMFLAGS) -o /dev/null $$src || exit 1; \
	done
	@echo "All files assembled successfully."

clean:
	rm -f $(ALL_OBJS) $(TARGET) $(NASMFLAGS_STAMP) pkmn.sym

assets/pret_ram.inc: tools/generators/gen_pret_ram.py ../pokeyellow.sym
	python3 tools/generators/gen_pret_ram.py
