#!/usr/bin/env python3
"""gen_overworld_strings.py — generate dos_port/assets/overworld_strings.inc.

Overworld-engine field / HUD text strings, GB-charmap encoded through the
unicode_converter submodule (gb_text.encode) instead of hand-written charmap
hex, then emitted as '@'-terminated ($50) NASM `db` lines. Consumed via
%include by src/engine/overworld/player_state.asm (PrintSafariZoneSteps).

This is the Tier-1 home for overworld field/HUD strings (per project-conventions:
human-rendered text is DATA, never hand-encoded charmap bytes in a .asm). Seeded
with the Safari Zone step/ball-count HUD strings.

Two outputs:
  * overworld_strings.inc  — simple '@'-terminated HUD strings (Safari Zone),
    %included by src/engine/overworld/player_state.asm (PrintSafariZoneSteps).
  * field_move_text.inc    — the OW-4.x field-message FAR text streams
    (Strength/Surf/boulder), %included by
    src/engine/overworld/field_move_messages.asm. These are full pret text
    command streams (text_ram/line/prompt/text_end), so instead of re-deriving
    the parser we reuse gen_battle_text's authoritative pret-text parser
    (collect_far scans data/text/text_*.asm) and emit just the labels we want,
    with text_far indirection flattened for the flat model.
  * text_script_text.inc   — far text streams consumed by
    src/home/text_script.asm's text_far wrappers.

Run from repo root or dos_port/.
"""
import os
import sys
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gb_text  # noqa: E402
import gen_battle_text  # noqa: E402  (reuse its pret data/text parser)

ROOT = Path(__file__).resolve().parents[3]
ASSETS = ROOT / "dos_port" / "assets"
TERMINATOR = 0x50  # '@'

# (NASM label, Unicode text) — pret: engine/overworld/player_state.asm.
# The trailing '@' terminator is appended as $50; do NOT put it in the text.
# '×' is U+00D7 (charmap $F1); the trailing space in SafariBallText is significant.
LABELS = [
    ("SafariSteps",    "/500"),                # pret: db "/500@"
    ("SafariBallText", "BALL×× "),    # pret: db "BALL×× @"
]

# Far-text streams for engine/overworld/field_move_messages.asm (OW-4.4).
# Kept in their own .inc so they don't land in player_state.asm's TU (which
# %includes overworld_strings.inc) — avoids a duplicate-symbol at final link.
# pret defs live in data/text/text_8.asm.
FIELD_MOVE_FAR = [
    "_UsedStrengthText",
    "_CanMoveBouldersText",
    "_CurrentTooFastText",
    "_CyclingIsFunText",
]

# Far-text streams for engine/overworld/cut.asm (OW-3.4). Own .inc for the same
# TU-isolation reason as FIELD_MOVE_FAR. pret defs: data/text/text_9.asm.
CUT_FAR = [
    "_NothingToCutText",
    "_UsedCutText",
]

# Far-text streams for engine/overworld/player_animations.asm (OW-5.1) — the
# fishing-result messages. Own .inc for the same TU-isolation reason.
# pret defs: data/text/text_1.asm.
PLAYER_ANIM_FAR = [
    "_NoNibbleText",
    "_NothingHereText",
    "_ItsABiteText",
]

# Far-text streams for home/text_script.asm's special text IDs and mart greeting.
# pret defs: data/text/text_7.asm.
TEXT_SCRIPT_FAR = [
    "_PokemartGreetingText",
    "_PokemonFaintedText",
    "_PlayerBlackedOutText",
    "_RepelWoreOffText",
    # UnknownText_2812's payload. pret marks that wrapper `; unreferenced` and it
    # is — but it is a real pret label with a real stream, so it gets a real body.
    "_PokemonText",
]

# engine/events/elevator.asm's floor prompt.
ELEVATOR_FAR = [
    "_WhichFloorText",
]

# engine/events/oaks_aide.asm's six messages.
OAKS_AIDE_FAR = [
    "_OaksAideHiText",
    "_OaksAideUhOhText",
    "_OaksAideComeBackText",
    "_OaksAideHereYouGoText",
    "_OaksAideGotItemText",
    "_OaksAideNoRoomText",
]

# engine/events/in_game_trades.asm's 17 messages (all in data/text/text_9.asm):
# the two unconditional ones plus the 5 x 3 TradeTextPointers1/2/3 dialogset
# streams (WANNA_TRADE / NO_TRADE / WRONG_MON / THANKS / AFTER_TRADE).
IN_GAME_TRADE_FAR = [
    "_ConnectCableText",
    "_TradedForText",
    "_WannaTrade1Text",
    "_NoTrade1Text",
    "_WrongMon1Text",
    "_Thanks1Text",
    "_AfterTrade1Text",
    "_WannaTrade2Text",
    "_NoTrade2Text",
    "_WrongMon2Text",
    "_Thanks2Text",
    "_AfterTrade2Text",
    "_WannaTrade3Text",
    "_NoTrade3Text",
    "_WrongMon3Text",
    "_Thanks3Text",
    "_AfterTrade3Text",
]

# engine/events/pokecenter_chansey.asm's one message (data/text/text_1.asm).
POKECENTER_CHANSEY_FAR = [
    "_NurseChanseyText",
]

# Far-text streams for engine/events/pokemart.asm (mart transaction loop).
# pret defs: data/text/text_7.asm.
POKEMART_FAR = [
    "_PokemartBuyingGreetingText",
    "_PokemartTellBuyPriceText",
    "_PokemartBoughtItemText",
    "_PokemartNotEnoughMoneyText",
    "_PokemartItemBagFullText",
    "_PokemonSellingGreetingText",
    "_PokemartTellSellPriceText",
    "_PokemartItemBagEmptyText",
    "_PokemartUnsellableItemText",
    "_PokemartThankYouText",
    "_PokemartAnythingElseText",
]

# The five `text_far _XxxText / text_end` wrappers in pret home/overworld_text.asm
# (sign, boulder and ledge messages the map scripts extern). The port deferred all
# five for want of exactly this: their strings are Tier-1 DATA and had no generator.
OVERWORLD_SIGN_FAR = [
    "_ExclamationText",
    "_GroundRoseText",
    "_BoulderText",
    "_MartSignText",
    "_PokeCenterSignText",
]


# Vending machine message streams and drink menu text (engine/events/vending_machine.asm + text/CeladonMartRoof.asm)
VENDING_FAR = [
    "_VendingMachineText1",
    "_VendingMachineText4",
    "_VendingMachineText5",
    "_VendingMachineText6",
    "_VendingMachineText7",
]

NEXT = 0x4E
TERM = 0x50

VENDING_STRINGS = [
    ("DrinkText", ["FRESH WATER", NEXT, "SODA POP", NEXT, "LEMONADE", NEXT, "CANCEL", TERM]),
    ("DrinkPriceText", ["¥200", NEXT, "¥300", NEXT, "¥350", NEXT, TERM]),
]

# Celadon Prize Corner message streams and menu strings (engine/events/prize_menu.asm + data/text/text_3.asm)
PRIZE_MENU_FAR = [
    "_RequireCoinCaseText",
    "_ExchangeCoinsForPrizesText",
    "_WhichPrizeText",
    "_HereYouGoText",
    "_SoYouWantPrizeText",
    "_SorryNeedMoreCoinsText",
    "_OopsYouDontHaveEnoughRoomText",
    "_OhFineThenText",
]

PRIZE_MENU_STRINGS = [
    ("NoThanksText", ["NO THANKS", TERM]),
    ("PrizeCoinString", ["COIN", TERM]),
    ("PrizeSixSpacesString", ["      ", TERM]),
]


def fmt_bytes(label: str, data: list) -> str:
    rows = []
    for k in range(0, len(data), 16):
        rows.append("    db " + ", ".join(f"0x{b:02X}" for b in data[k:k + 16]))
    return f"{label}:\n" + "\n".join(rows)


def main() -> int:
    import re
    out = [
        "; overworld_strings.inc — generated by tools/generators/gen_overworld_strings.py. DO NOT EDIT BY HAND.",
        "; Overworld-engine field/HUD strings, GB-charmap encoded via the",
        "; unicode_converter submodule (gb_text.encode) and '@'-terminated ($50).",
        "; pret ref: engine/overworld/player_state.asm.",
        "",
    ]
    for label, text in LABELS:
        b = gb_text.encode(text) + [TERMINATOR]
        hexs = ", ".join(f"0x{x:02X}" for x in b)
        out.append(f'{label}: db {hexs}   ; "{text}@"')
    out.append("")

    ASSETS.mkdir(parents=True, exist_ok=True)
    dst = ASSETS / "overworld_strings.inc"
    dst.write_text("\n".join(out))
    print(f"wrote {dst} ({len(LABELS)} labels)")

    # --- flattened FAR text streams (OW-4.4 / OW-3.4) ------------------------
    cm = gen_battle_text.load_charmap()
    mem = gen_battle_text.load_memmap()
    far = gen_battle_text.collect_far(cm, mem)

    # Also scan text/CeladonMartRoof.asm for vending machine far text
    vending_text_path = ROOT / "text" / "CeladonMartRoof.asm"
    if vending_text_path.exists():
        vending_blocks = {}
        cur, buf = None, []
        for raw in vending_text_path.read_text(encoding="utf-8").splitlines():
            m = re.match(r'(\w+)::\s*$', raw.strip())
            if m:
                if cur:
                    vending_blocks[cur] = buf
                cur, buf = m.group(1), []
                continue
            if cur is not None:
                buf.append(raw)
        if cur:
            vending_blocks[cur] = buf
        for label, body in vending_blocks.items():
            if label in VENDING_FAR:
                try:
                    far[label] = gen_battle_text.parse_body(body, cm, mem, far)
                except Exception as e:
                    sys.stderr.write(f"gen_overworld_strings: error parsing {label}: {e}\n")

    # (output basename, label list, one-line description) — each its own .inc so
    # the streams stay isolated to their single consuming TU (no duplicate-symbol
    # at final link; player_state.asm already %includes overworld_strings.inc).
    far_files = [
        ("field_move_text", FIELD_MOVE_FAR,
         "Field-move message FAR text streams (Strength/Surf/boulder; data/text/text_8.asm)"),
        ("cut_text", CUT_FAR,
         "Cut field-move FAR text streams (data/text/text_9.asm)"),
        ("player_anim_text", PLAYER_ANIM_FAR,
         "Fishing-result FAR text streams (data/text/text_1.asm)"),
        ("text_script_text", TEXT_SCRIPT_FAR,
         "DisplayTextID FAR text streams (data/text/text_7.asm)"),
        ("pokemart_text", POKEMART_FAR,
         "Poké Mart FAR text streams (data/text/text_7.asm)"),
        ("overworld_sign_text", OVERWORLD_SIGN_FAR,
         "Sign / boulder / ledge FAR text streams for home/overworld_text.asm"),
        ("pokecenter_chansey_text", POKECENTER_CHANSEY_FAR,
         "Nurse's Chansey message for engine/events/pokecenter_chansey.asm"),
        ("elevator_text", ELEVATOR_FAR,
         "Elevator floor-prompt FAR text stream for engine/overworld/elevator.asm"),
        ("oaks_aide_text", OAKS_AIDE_FAR,
         "Oak's Aide FAR text streams for engine/events/oaks_aide.asm"),
        ("in_game_trade_text", IN_GAME_TRADE_FAR,
         "In-game trade FAR text streams for engine/events/in_game_trades.asm (data/text/text_9.asm)"),
    ]
    for base, labels, desc in far_files:
        fout = [
            f"; {base}.inc — generated by tools/generators/gen_overworld_strings.py. DO NOT EDIT BY HAND.",
            f"; {desc}, pret text_far indirection flattened via",
            "; gen_battle_text.collect_far. section .data so labels never land in an",
            "; orphaned section (see link.ld).",
            "",
            "section .data",
            "",
        ]
        for label in labels:
            if label not in far:
                sys.stderr.write(f"gen_overworld_strings: missing far label {label}\n")
                return 1
            fout.append(fmt_bytes(label, far[label]))
        fout.append("")
        fdst = ASSETS / f"{base}.inc"
        fdst.write_text("\n".join(fout))
        print(f"wrote {fdst} ({len(labels)} far labels)")

    # --- vending machine text + menu strings (vending_machine_text.inc) ------
    vout = [
        "; vending_machine_text.inc — generated by tools/generators/gen_overworld_strings.py. DO NOT EDIT BY HAND.",
        "; Vending machine FAR text streams (text/CeladonMartRoof.asm), pret text_far indirection flattened via",
        "; gen_battle_text.collect_far. section .data so labels never land in an",
        "; orphaned section (see link.ld).",
        "",
        "section .data",
        "",
    ]
    for label in VENDING_FAR:
        if label not in far:
            sys.stderr.write(f"gen_overworld_strings: missing far label {label}\n")
            return 1
        vout.append(fmt_bytes(label, far[label]))
    vout.append("")

    for label, parts in VENDING_STRINGS:
        b = []
        for p in parts:
            if isinstance(p, int):
                b.append(p)
            else:
                b.extend(gb_text.encode(p))
        vout.append(fmt_bytes(label, b))
    vout.append("")
    vdst = ASSETS / "vending_machine_text.inc"
    vdst.write_text("\n".join(vout))
    print(f"wrote {vdst} ({len(VENDING_FAR)} far labels + {len(VENDING_STRINGS)} strings)")

    # --- Celadon Prize Corner text + strings (prize_menu_text.inc) ----------
    pout = [
        "; prize_menu_text.inc — generated by tools/generators/gen_overworld_strings.py. DO NOT EDIT BY HAND.",
        "; Celadon Prize Corner FAR text streams (data/text/text_3.asm), pret text_far indirection flattened via",
        "; gen_battle_text.collect_far. section .data so labels never land in an",
        "; orphaned section (see link.ld).",
        "",
        "section .data",
        "",
    ]
    for label in PRIZE_MENU_FAR:
        if label not in far:
            sys.stderr.write(f"gen_overworld_strings: missing far label {label}\n")
            return 1
        pout.append(fmt_bytes(label, far[label]))
    pout.append("")

    for label, parts in PRIZE_MENU_STRINGS:
        b = []
        for p in parts:
            if isinstance(p, int):
                b.append(p)
            else:
                b.extend(gb_text.encode(p))
        pout.append(fmt_bytes(label, b))
    pout.append("")
    pdst = ASSETS / "prize_menu_text.inc"
    pdst.write_text("\n".join(pout))
    print(f"wrote {pdst} ({len(PRIZE_MENU_FAR)} far labels + {len(PRIZE_MENU_STRINGS)} strings)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
