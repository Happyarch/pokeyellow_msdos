# Party field-move pop-up menu + faithful cursor polish

Implements the A-press pop-up over the party menu (pret `FIELD_MOVE_MON_MENU` /
`DisplayFieldMoveMonMenu`) and the shared cursor polish. Designed so the battle
`SWITCH_STATS_CANCEL_MENU_TEMPLATE` can reuse the generic pop-up later.
See memory [[gen1-swap-and-popup-menus]] for the subsystem map.

## Spec (faithful to pret)

- **Trigger:** A on a party mon (party reorder is NOT SELECT — that's items/moves only).
- **Entries (top→bottom, dynamic):** the mon's field moves in slot order
  (CUT/FLY/SURF/STRENGTH/FLASH/DIG/TELEPORT/SOFTBOILED, from `FieldMoveDisplayData`),
  then fixed **STATS, SWITCH, CANCEL**. Box height auto-sizes to entry count.
- **Actions:**
  - field move → deferred no-op (badge gating + overworld effects not ported), close pop-up.
  - STATS → deferred no-op (StatusScreen not ported), close pop-up.
  - SWITCH → if party≥2, arm reorder: parent `▶`→`▷` on the chosen mon, return to
    party list; next A on a different mon completes the swap (full record swap:
    wPartySpecies, 44-byte wPartyMons, OT name, nickname); B cancels. If party<2, close.
  - CANCEL / B → close pop-up.

## Cursor polish (pret `PlaceMenuCursor` / `PlaceUnfilledArrowMenuCursor`)

- When the pop-up opens, the party list `▶` (on the selected mon) → hollow `▷`,
  visible beside the pop-up. Restored to `▶` when the pop-up closes.
- Same rule for the bag: when USE/TOSS / YES/NO / quantity sub-boxes open, the bag
  list `▶` → `▷`. (Separate small follow-up.)
- ▶ = $ed, ▷ = $ec.

## Stages

- [x] 1. Field-move detection helper (`.field_move_name` + `.build_popup`): scans the
      mon's 4 moves vs the 8 field-move ids, emits matched name ptrs in slot order.
- [x] 2. Generic vertical pop-up (`.draw_popup` / `.run_popup`): data-driven
      (`pm_menu_entries[]` ptrs + `pm_menu_count`), auto-sized box → free GB_TILEMAP1
      rows (18+), appended via `add_window` as window 1 over the panel (respects the
      multi-layer compositor), UP/DOWN/A/B loop, returns chosen index or -1.
- [x] 3. Wired party A-handler: build entries (fields + STATS/SWITCH/CANCEL), run pop-up,
      dispatch. SWITCH arms reorder (full record swap via `.complete_swap`/`.swap_bytes`);
      field/STATS = no-op stubs.
- [x] 4. Parent-cursor hollow polish: party `▶`→`▷` while pop-up is open and while a
      SWITCH is armed (`.render` + direct GB_TILEMAP1 write on open).
- [x] 4b. Contextual bottom message box (pret PartyMenuMessagePointers): persistent
      window 1 (panel=0, message=1, pop-up=2), 20×6 dialog at viewport bottom (rows
      12-17 of GB_TILEMAP1). Text by state: normal "Choose a POKéMON.", SWITCH armed
      "Move POKéMON / where?". `.draw_message` (called by `.render`) auto-updates it.
      Verified via DEBUG_PARTYMENU FRAME.BIN (normal state renders cleanly).
      NOTE: confirmed font_battle_extra carries box tiles $79-$7E (byte-identical to
      font_extra), so TextBoxBorder works during the party menu — the old "clobbers
      box tiles" comment was wrong; fixed it. Item-use/battle/TM messages deferred
      to those systems (table-extensible).
- [ ] 5. (follow-up) Bag list `▶`→`▷` under its sub-boxes; blinking `▼` (both menus).
- [~] 6. Verify: assembles + links + window geometry reviewed; INTERACTIVE test pending
      (DEBUG_BAGMENU_LIVE seeds Snorlax FLY/CUT/SURF/STRENGTH, Pikachu SURF).

## Open aesthetic note
Pop-up is bottom-right (wx=223, 104px); the centered party panel (px 80-239) overlaps
its right edge slightly for large parties. Acceptable; revisit placement if it looks off.

## Deferred / not in scope

- Field-move effects, StatusScreen, A/B sound (no audio HAL).
- Battle SWITCH/STATS/CANCEL menu (reuses stage-2 helper when battle UI lands).
