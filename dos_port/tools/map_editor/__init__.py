"""map_editor — pygame overworld map viewer/editor (docs/current_plan_map_tool.md).

Built on tools/gfx_core (tile/blockset decode, pret map metadata). C1 ships
the read-only viewer: it composes each map exactly the way the runtime does —
border-block fill, then connection strips from the neighbours' real .blk via
gen_map_headers.get_connection(), then the map's own blocks — so what you see
is what LoadCurrentMapView will read out of wOverworldMap.

Entry point: python3 tools/map_editor/editor.py <MAP_CONST> [--zoom N]
"""
