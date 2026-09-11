# Interactive Dependency Graph & REST API

Detailed reference for the pret / DOS port call graph database (`tools/translation.db`), the web viewer (`dependency_graph.py`), and the agent-facing JSON REST API.

---

## Overview & Invocation

`dos_port/tools/dependency_graph.py` provides an interactive browser viewer and a loopback HTTP API for the modeled call graph.

```sh
# Launch browser viewer (automatically selects a free loopback port)
python3 dos_port/tools/dependency_graph.py

# Launch headless server for agent JSON queries
python3 dos_port/tools/dependency_graph.py --no-browser --port 8766

# Scan worktree into a temporary DB (does not modify tracked translation.db)
python3 dos_port/tools/dependency_graph.py --scan --no-browser --port 8766
```

### Viewer Scopes
- **Pret Scope**: Modeled pret labels plus unknown referenced endpoints. Excludes routines that exist only in the DOS port.
- **DOS Scope**: The complete modeled pret universe (including unported and isolated labels), port-only labels, and unknown endpoints.

---

## Provenance Rules: `display_status` vs `status`

> [!CRITICAL]
> **Read `display_status`, never raw `status`, to determine if code is port-only.**

- **Modeling Boundary**: `tools/update_label_db` only parses pret `home/` and `engine/`.
- **Pret-Unmodeled Labels**: Faithful pret labels from `audio/`, `data/`, `gfx/`, `ram/`, or `scripts/` land in `status = "port_only"` **by elimination**.
- **Provenance Tables**: The database cross-references the `aux_labels` and `script_labels` tables:
  - If a label exists in these tables, `display_status` is **`pret-unmodeled`**, and `aux_pret_file` / `aux_pret_dir` identifies the upstream pret file.
  - A label is genuinely bespoke only when `display_status == "port_only"` **AND** `aux_pret_file` is null.

### Address-Taken Dispatch Blindspot
The static call scanner cannot infer indirect calls through dispatch tables (`dd Label`) or ISR vectors. Jump table handlers and ISRs may execute while appearing disconnected in the graph. Never cite graph reachability as proof of unreachability.

---

## Agent-Facing REST JSON API

When automating caller/callee analysis or querying graph metadata, start the server headless and query the following endpoints.

### API Endpoints

| Endpoint | Method | Description |
|---|---|---|
| `/api/graph/pret` | `GET` | Modeled pret routines and external endpoints |
| `/api/graph/port` | `GET` | Complete DOS port graph, including unported and port-only labels |
| `/api/meta` | `GET` | Database commit, schema version, head mismatch warnings, and label status summary |

### Response Schemas

#### Graph Response (`/api/graph/port` and `/api/graph/pret`)
```json
{
  "side": "port",
  "coverage_note": "String describing modeling bounds and caveats",
  "nodes": {
    "OverworldLoop": {
      "name": "OverworldLoop",
      "status": "translated",
      "display_status": "translated",
      "pret_path": "home/overworld.asm",
      "port_path": "dos_port/src/home/overworld.asm",
      "stub_path": null,
      "providers": ["port"],
      "aux_pret_file": null,
      "annotations": [],
      "callers": ["start"],
      "callees": ["DelayFrame", "Joypad", "UpdateSprites"]
    }
  },
  "edges": [
    {
      "caller": "OverworldLoop",
      "callee": "DelayFrame",
      "kinds": ["call"],
      "build_active": true,
      "duplicate_count": 1,
      "source_sites": [
        {
          "file": "dos_port/src/home/overworld.asm",
          "line": 42,
          "kind": "call",
          "active": true
        }
      ]
    }
  ]
}
```

#### Metadata Response (`/api/meta`)
```json
{
  "db_path": "dos_port/tools/translation.db",
  "db_commit": "abc1234...",
  "head_commit": "abc1234...",
  "source_dirty": false,
  "label_counts": {
    "total": 1673,
    "translated": 1240,
    "unported": 342,
    "stub": 0,
    "pret_unmodeled": 91
  }
}
```

### Example Agent Queries
```sh
# Fetch callers of a routine from the active port graph
curl -s http://127.0.0.1:8766/api/graph/port | jq '.nodes["AdvancePlayerSprite"].callers'

# Check if a label is pret-unmodeled vs genuinely port-only
curl -s http://127.0.0.1:8766/api/graph/port | jq '.nodes["PlayPikachuSoundClip"] | {status, display_status, aux_pret_file}'
```
