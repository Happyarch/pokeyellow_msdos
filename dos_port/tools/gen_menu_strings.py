#!/usr/bin/env python3
"""gen_menu_strings.py — generate dos_port/assets/menu_strings.inc + menu_text.inc.

Two kinds of Tier-1 menu data, both from pret:

  * menu_strings.inc — the START-menu item LABELS, encoded through the
    unicode_converter submodule (gb_text.encode) instead of hand-written charmap
    hex, emitted as NASM `db` lines with the '@' terminator ($50). Consumed by
    src/engine/menus/draw_start_menu.asm, which aliases each generated label to
    the pret name (StartMenuPokemonText equ sm_str_pokemon, ...).

  * menu_text.inc — the START-sub-menu MESSAGE STREAMS (full TX_* command
    streams, not bare glyph runs), flattened out of pret's data/text/*.asm by
    gen_battle_text.collect_far — the same authoritative parser the battle/item/
    overworld text generators use. These are the bodies behind the `text_far`
    wrappers in engine/menus/start_sub_menus.asm; the wrappers themselves stay
    Tier-2 code in the .asm (text_far + text_end), exactly as pret writes them.

The two are separate files because they are different data: a label is a glyph
run PlaceString draws, a message is a command stream PrintText executes.

The source column below is pret's `db` string VERBATIM, not the rendered text.
That distinction is load-bearing: pret writes "#MON@", where '#' is charmap $54 —
a text COMMAND that PlaceNextChar expands to "POKé" at print time (home/text.asm:
`dict '#', PlacePOKe`), not four literal glyphs. Encoding the rendered string
"POKéMON" instead produces the same seven tiles on screen but a different byte
stream, silently bypassing the $54 handler the port implements
(src/home/text.asm:.handle_poke → str_poke). Keep these strings as pret spells
them and let the engine expand them; gb_text.encode maps '#' → $54 for us.

Run from repo root or dos_port/.
"""
import os
import sys
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gb_text  # noqa: E402
import gen_battle_text  # noqa: E402  (reuse its pret data/text parser)

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "dos_port" / "assets"
TERMINATOR = 0x50

# FAR message streams printed by engine/menus/start_sub_menus.asm. pret defs:
# data/text/text_8.asm. The `_`-prefixed name is pret's own; the wrapper label
# (CannotUseItemsHereText) lives in the .asm as text_far + text_end.
MENU_FAR = [
    "_CannotUseItemsHereText",      # StartMenu_Item, inside a Cable Club room
    "_CannotGetOffHereText",        # the BICYCLE, while BIT_ALWAYS_ON_BIKE is set
    # StartMenu_Pokemon's field-move dispatch (.outOfBattleMovePointers):
    "_NewBadgeRequiredText",        # every badge-gated move, gate closed
    "_CannotFlyHereText",           # FLY, indoors
    "_FlashLightsAreaText",         # FLASH
    "_WarpToLastPokemonCenterText",  # TELEPORT
    "_CannotUseTeleportNowText",    # TELEPORT, indoors
    "_NotHealthyEnoughText",        # SOFTBOILED, HP <= maxHP/5
]

# FAR message streams printed by engine/menus/pc.asm (the generic PC spine). pret
# defs: data/text/text_3.asm. The port kept these as HAND-DRAWN pages of hand-encoded
# charmap bytes until the row-17 audit; they are ordinary text_far streams and
# PrintText prints them (menu-fidelity row 17 / M-81).
PC_FAR = [
    "_TurnedOnPC1Text",             # ActivatePC: "<PLAYER> turned on / the PC."
    "_AccessedBillsPCText",         # BillsPC, after EVENT_MET_BILL
    "_AccessedSomeonesPCText",      # BillsPC, before meeting Bill
    "_AccessedMyPCText",            # PCMainMenu.playersPC
]

# FAR message streams printed by engine/menus/players_pc.asm (the ITEM STORAGE PC).
# pret defs: data/text/text_3.asm. The port hand-drew these as pages of hand-encoded
# charmap glyph runs until the row-17 audit, which could not express the two RAM
# splices they contain (_ItemWasStoredText / _WithdrewItemText are `text_ram
# wNameBuffer` streams) — they are ordinary text_far streams and PrintText prints
# them (menu-fidelity row 17 part 2 / M-84).
PLAYERS_PC_FAR = [
    "_TurnedOnPC2Text",             # PlayerPC, accessed directly (not via the generic PC)
    "_WhatDoYouWantText",           # PlayerPCMenu, above the 4-entry menu
    "_WhatToDepositText",           # PlayerPCDeposit, above the bag list
    "_DepositHowManyText",
    "_ItemWasStoredText",           # text_ram wNameBuffer + " was / stored via PC."
    "_NothingToDepositText",
    "_NoRoomToStoreText",
    "_WhatToWithdrawText",          # PlayerPCWithdraw, above the box list
    "_WithdrawHowManyText",
    "_WithdrewItemText",            # "Withdrew / <wNameBuffer>."
    "_NothingStoredText",
    "_CantCarryMoreText",
    "_WhatToTossText",              # PlayerPCToss, above the box list
    "_TossHowManyText",
]

# FAR message streams printed by engine/menus/oaks_pc.asm (OAK's PC / dex rating).
# pret defs: data/text/text_3.asm. The port hand-drew these as pages of hand-encoded
# charmap glyph runs until the row-17 audit (menu-fidelity row 17 part 3 / M-87);
# they are ordinary text_far streams and PrintText prints them.
OAKS_PC_FAR = [
    "_AccessedOaksPCText",          # "Accessed PROF. / OAK's PC." + para page 2
    "_GetDexRatedText",             # "Want to get your / #DEX rated?" (before YesNoChoice)
    "_ClosedOaksPCText",            # "Closed link to / PROF.OAK's PC."
]

# --- raw control/graphic tiles that are not single-char charmap glyphs ---
NEXT = 0x4E     # "<NEXT>" — line break (double-spaced by default in PlaceString)
TERM = 0x50     # "@"      — string terminator
CIRCLE = 0x76   # "○"      — a raw TILE id, NOT a charmap glyph. pret writes this one
                #            as a byte too: `db $76,"BADGES",$76,"@"`.

# APOSTROPHE LIGATURES — a trap, read before adding any string with an apostrophe.
# RGBDS charmaps match LONGEST-FIRST, and constants/charmap.asm defines the two-char
# sequences "'d" $BB, "'l" $BC, "'s" $BD, "'t" $BE, "'v" $BF, "'r" $E4, "'m" $E5 as
# SINGLE glyphs (a bare "'" is $E0). So pret's `db "RIVAL's @"` assembles to 8 bytes
# with ONE glyph for "'s". gb_text.encode (unicode_converter submodule) matches one
# character at a time and has no longest-match pass — it returns $E0,$B2 ("'" then
# "s"), a NINE-byte string that renders as two glyphs and shifts everything after it.
# Until the encoder learns longest-match, spell these out as raw bytes (menu-fidelity
# row 15 / M-59). RivalsTextString below is the first generator input to hit this.
APOS_S = 0xBD   # "'s" — ONE glyph (charmap.asm:156), not "'" + "s"

# NAMING SCREEN strings (pret engine/menus/naming_screen.asm). All four are pret GLOBAL
# labels and keep their names exactly. They were HAND-ENCODED charmap `db` bytes in
# naming_screen.asm until 2026-07-14 (menu-fidelity row 15 / M-58); the generated bytes
# were byte-compared against the hand-written literals and are identical, all four.
NAMING = [
    ("YourTextString",     ["YOUR ", TERM]),                   # pret: db "YOUR @"
    ("RivalsTextString",   ["RIVAL", APOS_S, " ", TERM]),      # pret: db "RIVAL's @"
    ("NameTextString",     ["NAME?", TERM]),                   # pret: db "NAME?@"
    ("NicknameTextString", ["NICKNAME?", TERM]),               # pret: db "NICKNAME?@"
]

# The naming screen's one FAR message stream (pret: DoYouWantToNicknameText is a
# text_far wrapper around _DoYouWantToNicknameText in data/text/text_3.asm). Emitted
# into naming_strings.inc rather than menu_text.inc so naming_screen.asm can %include
# it without pulling in start_sub_menus.asm's streams.
NAMING_FAR = [
    "_DoYouWantToNicknameText",     # AskName: "Do you want to give a nickname to <mon>?"
]

# POKéDEX labels (pret engine/menus/pokedex.asm). All four are pret GLOBALs and keep
# pret's names. The fifth is pret's routine-LOCAL `Pokedex_PlacePokemonList.dashedLine`
# ("----------@", the placeholder drawn on the list row of an unseen mon): NASM lets a
# local label be defined by its full `Global.local` name from anywhere, so the generated
# .inc keeps pret's local name exactly rather than inventing a global alias for it.
#
# These were HAND-ENCODED charmap `db` bytes in pokedex.asm until 2026-07-14 (menu-
# fidelity row 16 / M-70), under a file comment that called them "Tier-2 hand-authored
# charmap bytes" — there is no such exemption; a rendered string is Tier-1 DATA whatever
# a comment calls it. The generated bytes were byte-compared against the old literals
# and are identical, all five ('-' → $E3 through the charmap; it is not special).
POKEDEX = [
    ("PokedexSeenText",      ["SEEN", TERM]),          # pret: db "SEEN@"
    ("PokedexOwnText",       ["OWN", TERM]),           # pret: db "OWN@"
    ("PokedexContentsText",  ["CONTENTS", TERM]),      # pret: db "CONTENTS@"
    ("PokedexMenuItemsText",                           # pret: "DATA" next "CRY" next …
     ["DATA", NEXT, "CRY", NEXT, "AREA", NEXT, "PRNT", NEXT, "QUIT", TERM]),
    ("Pokedex_PlacePokemonList.dashedLine",
     ["----------", TERM]),                            # pret: db "----------@"
    # --- the DATA (entry) page's three blobs (menu-fidelity row 16 part 2, M-77).
    # Hand-encoded charmap `db` bytes in the old pokedex_entry.asm (now merged into
    # src/engine/menus/pokedex.asm, matching pret's single file); the
    # generated bytes were byte-compared against those literals and are identical.
    # '′'/'″' ($60/$61, the dex-tileset height glyphs) and '#' ($54, the POKé text
    # COMMAND — not four glyphs; see the module docstring) all come straight out of
    # gb_text.encode, so no raw-byte escapes are needed for them.
    ("HeightWeightText",                                # pret: db "HT  ?′??″" next "WT   ???lb@"
     ["HT  ?′??″", NEXT, "WT   ???lb", TERM]),
    ("PokeText",                                       # pret: db "#@" — unreferenced JP leftover
     ["#", TERM]),
    # PokedexDataDividerLine is not text at all: pret writes it as raw `db` hex too,
    # because these are dex-TILESET ids ($68-$6B: the divider's corner/segment tiles),
    # not charmap glyphs. Emitted here as raw ints so all three entry-page blobs live
    # in one generated place; the trailing "@" is the PlaceString terminator.
    ("PokedexDataDividerLine",
     [0x68, 0x69, 0x6B, 0x69, 0x6B, 0x69, 0x6B, 0x69, 0x6B, 0x6B,
      0x6B, 0x6B, 0x69, 0x6B, 0x69, 0x6B, 0x69, 0x6B, 0x69, 0x6A, TERM]),
]

# TRAINER CARD labels (pret engine/menus/start_sub_menus.asm — the DrawTrainerInfo
# section the port hosts in engine/menus/trainer_card.asm). Same (label, [parts])
# shape as gen_status_strings.py: a part is a str (→ gb_text.encode) or an int (a raw
# tile byte), mirroring pret's `db`/`next` sequence.
#
# These were HAND-ENCODED charmap `db` bytes in trainer_card.asm until 2026-07-13 —
# a Tier-1 violation (CLAUDE.md: "Text strings are DATA — never hand-encode charmap
# bytes"). The generated bytes are byte-identical to the hand-written ones, verified
# against the old literals; '/' encodes to $F3 through the charmap, it is not special.
TRAINER_CARD = [
    ("TrainerInfo_NameMoneyTimeText",
     ["NAME/", NEXT, "MONEY/", NEXT, "TIME/", TERM]),   # pret: db "NAME/" next "MONEY/" next "TIME/@"
    ("TrainerInfo_BadgesText",
     [CIRCLE, "BADGES", CIRCLE, TERM]),                 # pret: db $76,"BADGES",$76,"@"
]


# The player's-PC parent menu (pret engine/menus/players_pc.asm:PlayersPCMenuEntries),
# a pret GLOBAL label keeping pret's name. One string with <NEXT> separators, which
# PlaceString renders double-spaced. Hand-encoded charmap `db` bytes in the port until
# 2026-07-14 (menu-fidelity row 17 part 2 / M-84); the generated bytes were byte-compared
# against the old literals and are identical.
PLAYERS_PC = [
    ("PlayersPCMenuEntries",                            # pret: db "WITHDRAW ITEM" next …
     ["WITHDRAW ITEM", NEXT, "DEPOSIT ITEM", NEXT, "TOSS ITEM", NEXT, "LOG OFF", TERM]),
]


# The POKéMON LEAGUE PC (pret engine/menus/league_pc.asm): its one FAR message
# stream plus HallOfFameNoText, a pret GLOBAL `db` string PlaceString renders above
# each Hall-of-Fame mon. Both were hand-encoded charmap bytes in the port until
# menu-fidelity row 17 part 4 (M-89/M-90); the generated HallOfFameNoText bytes were
# byte-compared against the old literal and are identical.
LEAGUE_PC_FAR = [
    "_AccessedHoFPCText",           # "Accessed #MON / LEAGUE's site." + para page 2
]

LEAGUE_PC = [
    ("HallOfFameNoText",            # pret: db "HALL OF FAME No   @"
     ["HALL OF FAME No   ", TERM]),
]


# PARTY MENU learnability labels (pret engine/menus/party_menu.asm — the four LOCAL
# labels .ableToLearnMoveText / .notAbleToLearnMoveText / .ableToEvolveText /
# .notAbleToEvolveText, which are two pairs of identical strings). RedrawPartyMenu_
# PlaceStrings one of them per mon in the TMHM and EVO_STONE party menus. pret's
# names are RGBDS locals with no global counterpart to preserve, so the port names
# them pm_str_{able,not_able} and maps them in a comment at the use site.
PARTY_MENU = [
    ("pm_str_able",     ["ABLE", TERM]),        # pret: db "ABLE@"
    ("pm_str_not_able", ["NOT ABLE", TERM]),    # pret: db "NOT ABLE@"
]


# home/pokemon.asm:PrintStatusCondition's fainted string. pret writes it with the
# `ld_hli_a_string "FNT"` macro (macros/code.asm:13) rather than a `db`, so there is
# no pret label to preserve — but the three bytes are still an encoded glyph run, i.e.
# Tier-1 data, and were hand-written as `mov byte [ebp+esi], 0x85/0x8D/0x93` until
# 2026-07-13. NOTE the macro's shape, which the port must mirror: it emits
# `ld [hli], a` for every char BUT the last, then `ld [hl], <last>` — so HL ends up
# advanced by len-1 (pointing AT the final glyph), not by len. There is NO terminator.
HOME_POKEMON = [
    ("hp_str_fnt", ["FNT"]),                    # pret: ld_hli_a_string "FNT"
]


# OPTION menu strings (pret engine/menus/options.asm). Two of these are pret GLOBAL
# labels and keep their names exactly: AllOptionsText (the five row labels, joined by
# <NEXT>) and OptionMenuCancelText. The rest are pret RGBDS locals (.Fast/.Mid/.Slow,
# .On/.Off, .Shift/.Set, .Mono/.Earphone1-3, .Lightest..Darkest) with no global name to
# preserve, so they keep the port's opt_* names — the same convention PARTY_MENU uses
# above — and the .Strings pointer tables in options.asm map them back to pret's locals.
#
# These were HAND-ENCODED charmap `db` bytes in options.asm until 2026-07-14, under a
# header calling them "Tier-2 code data" — they are not: they are rendered strings, i.e.
# Tier-1 DATA (CLAUDE.md). The generated bytes were byte-compared against the hand-written
# literals: identical, all 18. Note the trailing spaces are load-bearing — pret pads each
# value to a fixed width ("MID @", "SET  @", "MONO     @") so a shorter value overwrites
# the longer one it replaces in the same cells; do not "tidy" them.
OPTIONS = [
    ("AllOptionsText",                                  # pret GLOBAL label
     ["TEXT SPEED :", NEXT, "ANIMATION  :", NEXT, "BATTLESTYLE:", NEXT,
      "SOUND:", NEXT, "PRINT:", TERM]),
    ("OptionMenuCancelText", ["CANCEL", TERM]),         # pret GLOBAL label

    ("opt_ts_fast", ["FAST", TERM]),                    # pret: OptionsMenu_TextSpeed.Fast
    ("opt_ts_mid",  ["MID ", TERM]),                    # pret: .Mid
    ("opt_ts_slow", ["SLOW", TERM]),                    # pret: .Slow

    ("opt_ba_on",   ["ON ", TERM]),                     # pret: OptionsMenu_BattleAnimations.On
    ("opt_ba_off",  ["OFF", TERM]),                     # pret: .Off

    ("opt_bs_shift", ["SHIFT", TERM]),                  # pret: OptionsMenu_BattleStyle.Shift
    ("opt_bs_set",   ["SET  ", TERM]),                  # pret: .Set

    ("opt_snd_mono", ["MONO     ", TERM]),              # pret: OptionsMenu_SpeakerSettings.Mono
    ("opt_snd_ear1", ["EARPHONE1", TERM]),              # pret: .Earphone1
    ("opt_snd_ear2", ["EARPHONE2", TERM]),              # pret: .Earphone2
    ("opt_snd_ear3", ["EARPHONE3", TERM]),              # pret: .Earphone3

    ("opt_pr_lightest", ["LIGHTEST", TERM]),            # pret: OptionsMenu_GBPrinterBrightness.Lightest
    ("opt_pr_lighter",  ["LIGHTER ", TERM]),            # pret: .Lighter
    ("opt_pr_normal",   ["NORMAL  ", TERM]),            # pret: .Normal
    ("opt_pr_darker",   ["DARKER  ", TERM]),            # pret: .Darker
    ("opt_pr_darkest",  ["DARKEST ", TERM]),            # pret: .Darkest
]


def encode_parts(parts):
    """str → charmap-encoded run; int → one raw tile byte. (gen_status_strings.py)"""
    out = []
    for p in parts:
        if isinstance(p, int):
            out.append(p)
        else:
            out.extend(gb_text.encode(p))
    return out


# (NASM label, pret's `db` string verbatim, pret label) — the strings are copied
# from engine/menus/draw_start_menu.asm; see the module docstring on '#' ($54).
LABELS = [
    ("sm_str_pokedex", "POKéDEX", "StartMenuPokedexText"),
    ("sm_str_pokemon", "#MON",    "StartMenuPokemonText"),
    ("sm_str_item",    "ITEM",    "StartMenuItemText"),
    ("sm_str_save",    "SAVE",    "StartMenuSaveText"),
    ("sm_str_reset",   "RESET",   "StartMenuResetText"),
    ("sm_str_option",  "OPTION",  "StartMenuOptionText"),
    ("sm_str_exit",    "EXIT",    "StartMenuExitText"),
]


def main() -> int:
    out = [
        "; menu_strings.inc — generated by tools/gen_menu_strings.py. DO NOT EDIT BY HAND.",
        "; START-menu item labels, GB-charmap encoded via the unicode_converter",
        "; submodule (gb_text.encode) and '@'-terminated ($50). The comment on each",
        "; line is pret's `db` string verbatim — '#' is $54, the POKé text command,",
        "; expanded by PlaceNextChar at print time (NOT four literal glyphs).",
        "",
    ]
    for label, text, pret_label in LABELS:
        b = gb_text.encode(text) + [TERMINATOR]
        hexs = ", ".join(f"0x{x:02X}" for x in b)
        out.append(f'{label}: db {hexs}   ; {pret_label} "{text}@"')
    out.append("")

    ASSETS.mkdir(parents=True, exist_ok=True)
    dst = ASSETS / "menu_strings.inc"
    dst.write_text("\n".join(out))
    print(f"wrote {dst} ({len(LABELS)} labels)")

    # --- flattened FAR message streams (start_sub_menus.asm) -----------------
    far = gen_battle_text.collect_far(
        gen_battle_text.load_charmap(), gen_battle_text.load_memmap()
    )
    fout = [
        "; menu_text.inc — generated by tools/gen_menu_strings.py. DO NOT EDIT BY HAND.",
        "; START-sub-menu FAR message streams (data/text/text_8.asm), pret's text_far",
        "; indirection flattened via gen_battle_text.collect_far. section .data so the",
        "; labels never land in an orphaned section (see link.ld).",
        "",
        "section .data",
        "",
    ]
    for label in MENU_FAR:
        if label not in far:
            sys.stderr.write(f"gen_menu_strings: missing far label {label}\n")
            return 1
        rows = [
            "    db " + ", ".join(f"0x{b:02X}" for b in far[label][k:k + 16])
            for k in range(0, len(far[label]), 16)
        ]
        fout.append(f"{label}:\n" + "\n".join(rows))
    fout.append("")
    fdst = ASSETS / "menu_text.inc"
    fdst.write_text("\n".join(fout))
    print(f"wrote {fdst} ({len(MENU_FAR)} far labels)")

    # --- the generic PC's FAR message streams (pc.asm) -------------------------
    cout = [
        "; pc_text.inc — generated by tools/gen_menu_strings.py. DO NOT EDIT BY HAND.",
        "; The generic PC's four message streams (pret data/text/text_3.asm), text_far",
        "; flattened via gen_battle_text.collect_far. src/engine/menus/pc.asm %includes",
        "; this and keeps pret's own wrapper labels (TurnedOnPC1Text = text_far",
        "; _TurnedOnPC1Text + text_end), so PrintText prints them exactly as pret does.",
        "; section .data so the labels land in a loaded section (see link.ld).",
        "",
        "section .data",
        "",
    ]
    for label in PC_FAR:
        if label not in far:
            sys.stderr.write(f"gen_menu_strings: missing far label {label}\n")
            return 1
        rows = [
            "    db " + ", ".join(f"0x{b:02X}" for b in far[label][k:k + 16])
            for k in range(0, len(far[label]), 16)
        ]
        cout.append(f"{label}:\n" + "\n".join(rows))
    cout.append("")
    cdst = ASSETS / "pc_text.inc"
    cdst.write_text("\n".join(cout))
    print(f"wrote {cdst} ({len(PC_FAR)} far labels)")

    # --- the player's PC: menu entries + FAR streams (players_pc.asm) ----------
    ppout = [
        "; players_pc_text.inc — generated by tools/gen_menu_strings.py. DO NOT EDIT BY HAND.",
        "; The ITEM STORAGE PC's parent-menu entry string plus its fourteen message",
        "; streams (pret engine/menus/players_pc.asm + data/text/text_3.asm). The entry",
        "; string is GB-charmap encoded via gb_text.encode (<NEXT> $4E / '@' $50 raw); the",
        "; streams are pret's text_far bodies, flattened via gen_battle_text.collect_far —",
        "; two of them (_ItemWasStoredText / _WithdrewItemText) splice wNameBuffer with",
        "; TX_RAM, which no hand-written glyph run can express. src/engine/menus/",
        "; players_pc.asm %includes this and keeps pret's wrapper labels (ItemWasStoredText",
        "; = text_far _ItemWasStoredText + text_end). section .data (see link.ld).",
        "",
        "section .data",
        "",
    ]
    for label, parts in PLAYERS_PC:
        b = encode_parts(parts)
        hexs = ", ".join(f"0x{x:02X}" for x in b)
        ppout.append(f"{label}: db {hexs}")
    for label in PLAYERS_PC_FAR:
        if label not in far:
            sys.stderr.write(f"gen_menu_strings: missing far label {label}\n")
            return 1
        rows = [
            "    db " + ", ".join(f"0x{b:02X}" for b in far[label][k:k + 16])
            for k in range(0, len(far[label]), 16)
        ]
        ppout.append(f"{label}:\n" + "\n".join(rows))
    ppout.append("")
    ppdst = ASSETS / "players_pc_text.inc"
    ppdst.write_text("\n".join(ppout))
    print(f"wrote {ppdst} ({len(PLAYERS_PC)} labels + {len(PLAYERS_PC_FAR)} far)")

    # --- OAK's PC: the three FAR streams (oaks_pc.asm) -------------------------
    oout = [
        "; oaks_pc_text.inc — generated by tools/gen_menu_strings.py. DO NOT EDIT BY HAND.",
        "; OAK's PC's three message streams (pret data/text/text_3.asm), text_far bodies",
        "; flattened via gen_battle_text.collect_far. src/engine/menus/oaks_pc.asm",
        "; %includes this and keeps pret's wrapper labels (AccessedOaksPCText = text_far",
        "; _AccessedOaksPCText + text_end), so PrintText prints them exactly as pret does.",
        "; section .data so the labels land in a loaded section (see link.ld).",
        "",
        "section .data",
        "",
    ]
    for label in OAKS_PC_FAR:
        if label not in far:
            sys.stderr.write(f"gen_menu_strings: missing far label {label}\n")
            return 1
        rows = [
            "    db " + ", ".join(f"0x{b:02X}" for b in far[label][k:k + 16])
            for k in range(0, len(far[label]), 16)
        ]
        oout.append(f"{label}:\n" + "\n".join(rows))
    oout.append("")
    odst = ASSETS / "oaks_pc_text.inc"
    odst.write_text("\n".join(oout))
    print(f"wrote {odst} ({len(OAKS_PC_FAR)} far labels)")

    # --- the LEAGUE PC: HallOfFameNoText + its FAR stream (league_pc.asm) ------
    lout = [
        "; league_pc_text.inc — generated by tools/gen_menu_strings.py. DO NOT EDIT BY HAND.",
        "; The POKéMON LEAGUE PC's message stream (pret data/text/text_3.asm, text_far body",
        "; flattened via gen_battle_text.collect_far) and HallOfFameNoText (pret",
        "; engine/menus/league_pc.asm, GB-charmap encoded via gb_text.encode).",
        "; src/engine/menus/league_pc.asm %includes this and keeps pret's wrapper label",
        "; (AccessedHoFPCText = text_far _AccessedHoFPCText + text_end).",
        "; section .data so the labels land in a loaded section (see link.ld).",
        "",
        "section .data",
        "",
    ]
    for label, parts in LEAGUE_PC:
        b = encode_parts(parts)
        lout.append(f"{label}: db " + ", ".join(f"0x{x:02X}" for x in b))
    for label in LEAGUE_PC_FAR:
        if label not in far:
            sys.stderr.write(f"gen_menu_strings: missing far label {label}\n")
            return 1
        rows = [
            "    db " + ", ".join(f"0x{b:02X}" for b in far[label][k:k + 16])
            for k in range(0, len(far[label]), 16)
        ]
        lout.append(f"{label}:\n" + "\n".join(rows))
    lout.append("")
    ldst = ASSETS / "league_pc_text.inc"
    ldst.write_text("\n".join(lout))
    print(f"wrote {ldst} ({len(LEAGUE_PC)} labels + {len(LEAGUE_PC_FAR)} far)")

    # --- TRAINER CARD PlaceString labels (trainer_card.asm) -------------------
    tout = [
        "; trainer_card_strings.inc — generated by tools/gen_menu_strings.py. DO NOT EDIT BY HAND.",
        "; TRAINER CARD PlaceString labels (pret start_sub_menus.asm's DrawTrainerInfo",
        "; section). GB-charmap encoded via gb_text.encode (unicode_converter submodule);",
        "; <NEXT> $4E, '@' $50 and the ○ circle TILE $76 inserted as raw bytes, mirroring",
        "; pret's own `db $76,\"BADGES\",$76,\"@\"`. section .data so the labels land in a",
        "; loaded section (see link.ld).",
        "",
        "section .data",
        "",
    ]
    for label, parts in TRAINER_CARD:
        b = encode_parts(parts)
        hexs = ", ".join(f"0x{x:02X}" for x in b)
        tout.append(f"{label}: db {hexs}")
    tout.append("")
    tdst = ASSETS / "trainer_card_strings.inc"
    tdst.write_text("\n".join(tout))
    print(f"wrote {tdst} ({len(TRAINER_CARD)} labels)")

    # --- PARTY MENU PlaceString labels (party_menu.asm) ------------------------
    pout = [
        "; party_menu_strings.inc — generated by tools/gen_menu_strings.py. DO NOT EDIT BY HAND.",
        "; The TMHM / EVO_STONE party-menu learnability labels (pret's four local",
        "; .{not,}ableTo{LearnMove,Evolve}Text, two identical pairs). GB-charmap encoded",
        "; via gb_text.encode; '@' $50 is the raw terminator. section .data (see link.ld).",
        "",
        "section .data",
        "",
    ]
    for label, parts in PARTY_MENU:
        b = encode_parts(parts)
        hexs = ", ".join(f"0x{x:02X}" for x in b)
        pout.append(f"{label}: db {hexs}")
    pout.append("")
    pdst = ASSETS / "party_menu_strings.inc"
    pdst.write_text("\n".join(pout))
    print(f"wrote {pdst} ({len(PARTY_MENU)} labels)")

    # --- home/pokemon.asm glyph runs (PrintStatusCondition) --------------------
    hout = [
        "; home_pokemon_strings.inc — generated by tools/gen_menu_strings.py. DO NOT EDIT BY HAND.",
        "; Glyph runs written by src/home/pokemon.asm. GB-charmap encoded via gb_text.encode.",
        "; UNTERMINATED — pret writes these with ld_hli_a_string, not as '@'-terminated",
        "; strings; the routine copies a fixed byte count. section .data (see link.ld).",
        "",
        "section .data",
        "",
    ]
    for label, parts in HOME_POKEMON:
        b = encode_parts(parts)
        hexs = ", ".join(f"0x{x:02X}" for x in b)
        hout.append(f"{label}: db {hexs}")
    hout.append("")
    hdst = ASSETS / "home_pokemon_strings.inc"
    hdst.write_text("\n".join(hout))
    print(f"wrote {hdst} ({len(HOME_POKEMON)} labels)")

    # --- OPTION menu PlaceString labels (options.asm) --------------------------
    oout = [
        "; options_strings.inc — generated by tools/gen_menu_strings.py. DO NOT EDIT BY HAND.",
        "; The OPTION screen's row labels and value strings (pret engine/menus/options.asm).",
        "; GB-charmap encoded via gb_text.encode; <NEXT> $4E and '@' $50 are raw bytes.",
        "; AllOptionsText / OptionMenuCancelText are pret GLOBAL labels and keep their names;",
        "; the opt_* labels are pret RGBDS locals (.Fast, .On, .Mono, ...) mapped back to pret",
        "; by the .Strings pointer tables in options.asm. Trailing spaces are pret's own fixed",
        "; -width padding — a shorter value must fully overwrite the longer one it replaces.",
        "; section .data so the labels land in a loaded section (see link.ld).",
        "",
        "section .data",
        "",
    ]
    for label, parts in OPTIONS:
        b = encode_parts(parts)
        hexs = ", ".join(f"0x{x:02X}" for x in b)
        oout.append(f"{label}: db {hexs}")
    oout.append("")
    odst = ASSETS / "options_strings.inc"
    odst.write_text("\n".join(oout))
    print(f"wrote {odst} ({len(OPTIONS)} labels)")

    # --- NAMING SCREEN strings + its one far stream (naming_screen.asm) --------
    nout = [
        "; naming_strings.inc — generated by tools/gen_menu_strings.py. DO NOT EDIT BY HAND.",
        "; The naming screen's PlaceString labels and its one FAR message stream",
        "; (pret engine/menus/naming_screen.asm + data/text/text_3.asm). All four string",
        "; labels are pret GLOBALs and keep pret's names. \"RIVAL's \" carries the \"'s\"",
        "; LIGATURE ($BD, one glyph — charmap.asm matches longest-first); it is emitted as",
        "; a raw byte because gb_text.encode has no longest-match pass and would produce",
        "; \"'\"+\"s\" ($E0,$B2), a byte longer than pret's. See APOS_S in the generator.",
        "; section .data so the labels land in a loaded section (see link.ld).",
        "",
        "section .data",
        "",
    ]
    for label, parts in NAMING:
        b = encode_parts(parts)
        hexs = ", ".join(f"0x{x:02X}" for x in b)
        nout.append(f"{label}: db {hexs}")
    nout.append("")
    for label in NAMING_FAR:
        if label not in far:
            sys.stderr.write(f"gen_menu_strings: missing far label {label}\n")
            return 1
        rows = [
            "    db " + ", ".join(f"0x{b:02X}" for b in far[label][k:k + 16])
            for k in range(0, len(far[label]), 16)
        ]
        nout.append(f"{label}:\n" + "\n".join(rows))
    nout.append("")
    ndst = ASSETS / "naming_strings.inc"
    ndst.write_text("\n".join(nout))
    print(f"wrote {ndst} ({len(NAMING)} labels + {len(NAMING_FAR)} far)")

    # --- pokedex_strings.inc (engine/menus/pokedex.asm) ---------------------
    pout = [
        "; pokedex_strings.inc — generated by tools/gen_menu_strings.py. DO NOT EDIT BY HAND.",
        "; The POKéDEX PlaceString labels (pret engine/menus/pokedex.asm) — both the list",
        "; screen's four and the DATA page's three (HeightWeightText / PokeText /",
        "; PokedexDataDividerLine). All seven are pret GLOBALs and keep pret's names;",
        "; Pokedex_PlacePokemonList.dashedLine keeps pret's ROUTINE-LOCAL name via NASM's",
        "; Global.local form. GB-charmap encoded via gb_text.encode (unicode_converter",
        "; submodule); <NEXT> $4E, '@' $50 and the divider's dex-tileset ids are raw bytes.",
        "; section .data (see link.ld).",
        "",
        "section .data",
        "",
    ]
    for label, parts in POKEDEX:
        b = encode_parts(parts)
        hexs = ", ".join(f"0x{x:02X}" for x in b)
        pout.append(f"{label}: db {hexs}")
    pout.append("")
    pdst = ASSETS / "pokedex_strings.inc"
    pdst.write_text("\n".join(pout))
    print(f"wrote {pdst} ({len(POKEDEX)} labels)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
