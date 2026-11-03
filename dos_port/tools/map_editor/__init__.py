"""map_editor — port-side overworld map and cutscene authoring.

Composes each map the way the runtime does (border fill, connection strips from
the neighbours' real .blk via gen_map_headers.get_connection(), then the map's
own blocks composed with its schema-2 sidecar), so what the GUI shows is what
LoadCurrentMapView reads out of wOverworldMap.

Pret's map/object/header sources are read-only specification. Writes go to
dos_port/assets/map_overrides/<Pascal>.json or to a port script under
dos_port/src/scripts/.

Front ends: editor.py (pygame) and cli.py (JSON). Both call commands.py, which
is the only mutation surface. See README.md for units, schema, CLI and limits.
"""
