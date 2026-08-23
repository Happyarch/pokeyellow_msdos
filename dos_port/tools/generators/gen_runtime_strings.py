#!/usr/bin/env python3
"""Generate small runtime-owned rendered strings formerly embedded in .asm files."""
from pathlib import Path

from gen_battle_text import encode, load_charmap

ROOT = Path(__file__).resolve().parents[3]
ASSETS = ROOT / "dos_port" / "assets"


def db(label, parts, cm, aliases=(), emit_global=False):
    """Emit `label` (plus any extra names for the same bytes) and its data.

    `aliases` exists so a pret label can be the PRIMARY name of a generated
    string while extra port names, if any, ride along. The `global` goes in the
    .inc, NOT in the carrier .asm: a pret label defined in an .inc while its
    `global` sits in the includer is recorded is_global=0 in a file that is not
    the selected provider, which lint_pret_labels --strict-claims reports as
    `local_shadow` (measured 2026-08-22 on PTile). battle_text.inc is the
    standing precedent for doing it this way.

    Directives are emitted in order, so a part may also be a ("dd", "Label")
    tuple: pret's `text_far` operand is a pointer, and the port encodes it as one
    32-bit flat pointer (include/gb_text.inc `text_far`, and the TX_FAR handler in
    src/home/text.asm). A byte list cannot express a relocated label, so the
    emitter breaks the run and writes a `dd` line.
    """
    out = []
    if emit_global:
        for name in (label, *aliases):
            out.append(f"global {name}")
    for name in aliases:
        out.append(f"{name}:")

    prefix = f"{label}: "
    pending = []

    def flush():
        nonlocal prefix, pending
        if pending:
            out.append(prefix + "db " + ", ".join(f"0x{x:02X}" for x in pending))
            prefix = ""
            pending = []

    for part in parts:
        if isinstance(part, tuple):
            directive, operand = part
            flush()
            out.append(prefix + f"{directive} {operand}")
            prefix = ""
        else:
            pending.extend(encode(part, cm) if isinstance(part, str) else part)
    flush()
    if prefix:                      # label with no data of its own
        out.append(prefix.rstrip())
    return "\n".join(out)


FILES = {
    "battle_menu_runtime_strings.inc": [
        ("BattleMenuText", ["FIGHT ", "<PK><MN>", [0x4E], "ITEM  RUN", [0x50]]),
        ("str_gotaway", ["Got away safely!", [0x50]]),
        ("str_cantesc", ["Can't escape!", [0x50]]),
        ("str_norun1", ["No! There's no", [0x50]]),
        ("str_norun2", ["running from a", [0x50]]),
        ("str_norun3", ["trainer battle!", [0x50]]),
        ("str_attack", ["ATTACK", [0x50]]), ("str_defense", ["DEFENSE", [0x50]]),
        ("str_speed", ["SPEED", [0x50]]), ("str_special", ["SPECIAL", [0x50]]),
        # Tutorial-battle stand-in names (pret core.asm .oldManName/.profOakName,
        # copied over wPlayerName for the simulated battle menu so battle text
        # reads "PROF.OAK used ...").
        #
        # THE TAILS ARE NOT PADDING — they are what the hardware actually copies,
        # and this comment previously said the opposite ("the tail bytes past the
        # @ are incidental code in pret; the port pads with terminators instead
        # (render-identical)"). Render-identical is true and is NOT the whole
        # story: wPlayerName is a compared golden region (all NAME_LENGTH bytes,
        # lib/dump.lua), so padding is a measurable divergence.
        #
        # pret db's "OLD MAN@" (8 bytes) and "PROF.OAK@" (9) but copies
        # NAME_LENGTH = 11, so it reads past each literal. MEASURED from
        # pokeyellow.gbc at 0f:4fe7 = file offset 0x3CFE7:
        #     0003cfe7: 8e 8b 83 7f 8c 80 8d 50 8f 91 8e 85 e8 8e 80 8a
        #     0003cff7: 50 fa 2d ...
        #   .oldManName  + 11 -> "OLD MAN" 50 | 8F 91 8E   ("PRO", the start of
        #                        .profOakName immediately after it)
        #   .profOakName + 11 -> "PROF.OAK" 50 | FA 2D     (the first two bytes
        #                        of the FOLLOWING CODE, ld a,[wBattleAndStart-
        #                        SavedMenuItem] = fa 2d cc)
        #
        # ⚠ FRAGILITY, stated because it is real and someone will hit it: the
        # PROF.OAK tail is pret CODE, not data. If upstream ever moves or edits
        # DisplayBattleMenu.handleBattleMenuInput, those two bytes change and the
        # port silently diverges again. Re-measure at the offset above rather
        # than trusting FA 2D. The OLD MAN tail is data-adjacency and is stable
        # as long as .profOakName follows .oldManName.
        ("str_oldman_name", ["OLD MAN", [0x50, 0x8F, 0x91, 0x8E]]),
        ("str_profoak_name", ["PROF.OAK", [0x50, 0xFA, 0x2D]]),
        # Tutorial-battle one-item bag (pret SimulatedInputBattleItemList):
        # the box shows the single POKe BALL and its x1 quantity.
        ("str_pokeball", ["POKé BALL", [0x50]]),
        ("str_x1", [[0xF1, 0xF7, 0x50]]),  # ×1
    ],
    "battle_core_runtime_strings.inc": [
        ("str_used_grammar", [[0x4F], "used ", [0x50]]),
        ("str_miss_text", [[0x00], "Attack got no way!", [0x50, 0x50]]),
        ("str_rose", [" rose!", [0x58]]),
        ("str_greatly_rose", [[0x4C], "greatly rose!", [0x58]]),
        ("str_fell", [" fell!", [0x58]]),
        ("str_greatly_fell", [[0x4C], "greatly fell!", [0x58]]),
        # pret engine/battle/core.asm:SevenSpacesText — `ds PIC_WIDTH, " "` + "@".
        # SlideDownFaintedMonPic PlaceStrings it to blank the row the pic just
        # vacated. A rendered glyph run is Tier-1 data, so it is generated here
        # rather than hand-encoded (PIC_WIDTH = 7).
        ("SevenSpacesText", [" " * 7, [0x50]]),
    ],
    "effectiveness_runtime_strings.inc": [
        ("SuperEffectiveText", [[0x00], "It's super", [0x4F], "effective!", [0x58]]),
        ("NotVeryEffectiveText", [[0x00], "It's not very", [0x4F], "effective...", [0x58]]),
    ],
    # DEBUG_ANIM_SHOW labels. Rendered on screen, so Tier-1 data like every other
    # string — never hand-encoded charmap bytes in the harness. Moves are labelled
    # at runtime from the real MoveNames table; these five are the item-path
    # animations, whose ids are NOT move ids (TOSS_ANIM $C1 etc. sit past
    # NUM_ATTACKS, so GetMoveName would read off the end of the table).
    "anim_show_strings.inc": [
        ("as_lbl_ball_catch", ["BALL CATCH", [0x50]]),
        ("as_lbl_ball_break", ["BALL BREAK", [0x50]]),
        ("as_lbl_bait", ["SAFARI BAIT", [0x50]]),
        ("as_lbl_rock", ["SAFARI ROCK", [0x50]]),
        ("as_lbl_xitem", ["X ITEM", [0x50]]),
    ],
    "battle_intro_runtime_strings.inc": [
        ("intro_line1", ["Wild "]), ("intro_line2", ["appeared!"]),
        # pret engine/battle/init_battle.asm InitWildBattle.isGhost:
        #   ld hl, wEnemyMonNick / ld_hli_a_string "GHOST@"
        # The nick the ghost battle shows until the Silph Scope unveils it. A
        # rendered string is Tier-1 data, so it is generated rather than
        # hand-encoded; the trailing 0x50 is pret's "@" terminator, inside the
        # literal because pret copies the whole 6 bytes.
        ("ghost_nick", ["GHOST", [0x50]]),
    ],
    "stat_mod_runtime_strings.inc": [
        ("StatModTextStrings", ["ATTACK", [0x50], "DEFENSE", [0x50], "SPEED", [0x50],
                                "SPECIAL", [0x50], "ACCURACY", [0x50], "EVADE", [0x50]]),
    ],
    "item_runtime_strings.inc": [
        ("ti_msg_threw", ["Threw away", [0x50]]),
        ("ti_msg_isok", ["Is it OK to toss", [0x50]]),
        ("ti_msg_imp1", ["That's too impor-", [0x50]]),
        ("ti_msg_imp2", ["tant to toss!", [0x50]]),
    ],
    "status_ailment_runtime_strings.inc": [
        ("sa_psn", ["PSN"]), ("sa_brn", ["BRN"]), ("sa_frz", ["FRZ"]),
        ("sa_par", ["PAR"]), ("sa_slp", ["SLP"]),
    ],
    "home_names_runtime_strings.inc": [
        ("TechnicalPrefix", ["TM"]), ("HiddenPrefix", ["HM"]),
    ],
    # pret home/text.asm's inline substitution strings, under their PRET NAMES
    # (they were port-invented str_* until 2026-08-22; see
    # docs/current_plan_text_engine_realign.md Stage 1). pret writes them as
    # `db "TM@"` &c. immediately after PlaceCommandCharacter; the port keeps them
    # here because a rendered glyph run is Tier-1 data.
    "home_text_runtime_strings.inc": [
        ("PlacePOKeText", ["POKé", [0x50]]),
        ("PCCharText", ["PC", [0x50]]),
        ("TMCharText", ["TM", [0x50]]),
        ("TrainerCharText", ["TRAINER", [0x50]]),
        ("RocketCharText", ["ROCKET", [0x50]]),
        ("SixDotsCharText", [[0x75, 0x75, 0x50]]),
        ("PlacePKMNText", ["<PK><MN>", [0x50]]),
        ("EnemyText", ["Enemy ", [0x50]]),
        # The two `text_far` wrappers pret defines in home/text.asm, with their
        # far targets from data/text/text_3.asm. Stage 3b of
        # docs/current_plan_text_engine_realign.md; they land here rather than in
        # the .asm because _TextIDErrorText contains a rendered glyph run
        # (" error."), which is Tier-1 data.
        #
        # The wrapper operand is ONE 32-bit flat pointer, not pret's
        # addr_lo/addr_hi/bank triple — see the DEVIATION{class=banking} on
        # TextCommand_FAR in src/home/text.asm. TX_FAR = 0x17, TX_END = 0x50,
        # TX_NUM = 0x09, TX_START = 0x00, CHAR_DONE = 0x57, <_CONT> = 0x4B.
        #
        # _TextIDErrorText = `text_decimal hTextID, 1, 2` + `text " error."` +
        # `done`; hTextID is 0xFF8C (include/gb_memmap.inc:682), and the format
        # byte is (1 << 4) | 2 = 0x12.
        ("_TextIDErrorText", [[0x09, 0x8C, 0xFF, 0x12, 0x00], " error.", [0x57]]),
        ("TextIDErrorText", [[0x17], ("dd", "_TextIDErrorText"), [0x50]]),
        # _ContCharText = `text "<_CONT>@"` + `text_end`.
        ("_ContCharText", [[0x00, 0x4B, 0x50, 0x50]]),
        ("ContCharText", [[0x17], ("dd", "_ContCharText"), [0x50]]),
        # PORT-ONLY, no pret counterpart: pret's PlaceDexEnd writes the '.' with
        # `ld [hl], '.'`, but the port routes it through place_flat_str like the
        # other substitutions, so it needs a one-glyph string to point at.
        ("str_dot", [".", [0x50]]),
    ],
    "pallet_runtime_strings.inc": [
        ("oak_got_text", [[0x00], "OAK: That was", [0x4F], "close!", [0x57, 0x50]]),
        ("oak_default_text", [[0x00], "OAK: Hey! Wait!", [0x4F], "Don't go out!", [0x57, 0x50]]),
        ("oak_whew_text", [[0x00], "OAK: Whew!", [0x4F], "That was close!", [0x57, 0x50]]),
        ("oak_come_with_me_text", [[0x00], "OAK: It's unsafe!", [0x4F], "Come with me!", [0x57, 0x50]]),
    ],
}


# Files whose labels are declared `global` in the .inc itself. Opt-in, because a
# `global` is only needed where a pret label lives in the .inc — see db()'s
# docstring for why it must not go in the carrier .asm instead. Everything else
# keeps the historical file-local form so this pass adds no symbols it does not
# need to.
GLOBAL_IN_INC = {"home_text_runtime_strings.inc"}


def main():
    cm = load_charmap()
    for name, rows in FILES.items():
        lines = ["; DO NOT EDIT BY HAND — generated by tools/generators/gen_runtime_strings.py."]
        for row in rows:
            label, parts, aliases = (row if len(row) == 3 else (*row, ()))
            lines.append(db(label, parts, cm, aliases,
                            emit_global=name in GLOBAL_IN_INC))
            if label == "intro_line1":
                lines.append("INTRO_LINE1_LEN equ $ - intro_line1")
            elif label == "intro_line2":
                lines.append("INTRO_LINE2_LEN equ $ - intro_line2")
            elif label == "ghost_nick":
                lines.append("GHOST_NICK_LEN equ $ - ghost_nick")
            elif label.startswith("oak_"):
                lines.append(f"{label}_end:")
        (ASSETS / name).write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
