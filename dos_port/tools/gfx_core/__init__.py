"""gfx_core — shared GB graphics decoding/compositing for the layout tools.

One rendering core, three consumers (separate entry points):
  tools/ui_layout/   menus + battle box-model editor (schema/canvas stay there)
  tools/ui_layout/battle.py   battle-sidecar launcher (current_plan_battle_ui)
  tools/map_editor/  overworld map viewer/painter     (current_plan_map_tool)

Modules:
  tiles.py    TILE/DMG_PAL, PNG tile slicing, raw GB 2bpp/1bpp decode
  font.py     charmap font tiles (font.png/font_extra.png), BOX_* border codes
  surface.py  tile-grid -> PIL compose, TextBoxBorder frames, FRAME.BIN load

Nothing in here knows about sidecar schemas or projection math — those live
with their owning tool (ui_layout/schema.py, ui_layout/canvas.py).
"""
