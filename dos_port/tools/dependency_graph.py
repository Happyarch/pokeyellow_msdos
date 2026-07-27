#!/usr/bin/env python3
"""Interactive, read-only pret / DOS-port dependency graph.

Usage: python3 dos_port/tools/dependency_graph.py [--scan] [--no-browser]
                                                  [--db PATH] [--host H] [--port N]

Serves a loopback-only canvas viewer plus a JSON API for agents:
    /api/graph/pret   modeled pret labels + unknown referenced endpoints
    /api/graph/port   the above plus port-only labels
    /api/meta         DB path/stamp/commit, HEAD mismatch, status counts

READING THE STATUS FIELD -- the one trap in this data
-----------------------------------------------------
`update_label_db` models pret home/ + engine/ ONLY. A faithful pret label whose
home is audio/, data/, gfx/, ram/ or scripts/ is invisible to that model, so it
is recorded as `status = "port_only"` BY ELIMINATION -- not because anyone
determined it is bespoke port code.

build_graph() corrects for this by joining the names-only `aux_labels` and
`script_labels` provenance tables. Such nodes get:
    display_status = "pret-unmodeled"
    aux_pret_file  = e.g. "audio/engine_1.asm"
    aux_pret_dir   = e.g. "audio"

    *** A node is genuinely port-only only when display_status == "port_only"
        AND aux_pret_file is null. ***

Measured 2026-07-27: 90 pret-unmodeled vs 337 genuinely port-only, so reading
raw `status` overstates the port's divergence by ~90 labels.

Provenance is names-only by design: pret-unmodeled nodes carry no status and no
call-graph edges. Absence of edges on them is not evidence of anything -- and
neither is absence of edges generally, since the scanner emits no edge for
`dd Label` dispatch tables or other address-taken targets (both ISRs and every
jump-table handler therefore appear disconnected while provably running).
"""

import argparse
import collections
import importlib.machinery
import importlib.util
import json
import math
import os
from pathlib import Path
import sqlite3
import subprocess
import sys
import tempfile
import threading
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
DEFAULT_DB = HERE / "translation.db"
STATUSES = {"translated", "relocated", "stub", "missing", "port_only", "pret-unmodeled"}
REQUIRED = {
    "labels": {"name", "pret_file", "port_file", "status", "stub_file", "scanned_at", "git_hash"},
    "calls": {"caller", "callee", "kind", "side", "file", "line", "build_active"},
    "port_defs": {"name", "file", "line", "is_stub", "is_global", "defined_here", "instr_count", "has_call", "section"},
}


class DataError(RuntimeError):
    pass


def _load_linter():
    path = HERE / "lint_pret_labels"
    loader = importlib.machinery.SourceFileLoader("dependency_graph_linter", str(path))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


def validate_db(con):
    tables = {r[0] for r in con.execute("SELECT name FROM sqlite_master WHERE type='table'")}
    problems = []
    for table, columns in REQUIRED.items():
        if table not in tables:
            problems.append(f"missing table {table}")
            continue
        actual = {r[1] for r in con.execute(f"PRAGMA table_info({table})")}
        missing = sorted(columns - actual)
        if missing:
            problems.append(f"{table} missing columns: {', '.join(missing)}")
    if not problems and "labels" in tables:
        values = {r[0] for r in con.execute("SELECT DISTINCT status FROM labels")}
        bad = sorted(values - STATUSES)
        if bad:
            problems.append("unsupported label statuses: " + ", ".join(bad))
    if problems:
        raise DataError("Incompatible translation database (" + "; ".join(problems) + "). Run with --scan.")


def scan_annotations(files):
    parse = _load_linter().parse_annotation
    result = collections.defaultdict(list)
    for rel in sorted({f for f in files if f and f.endswith((".asm", ".inc"))}):
        path = ROOT / rel
        try:
            lines = path.read_text(encoding="utf-8").splitlines()
        except (OSError, UnicodeError):
            continue
        current = None
        for number, text in enumerate(lines, 1):
            stripped = text.split(";", 1)[0].strip()
            if stripped.endswith(":") and not stripped.startswith("."):
                current = stripped[:-1].strip()
            parsed = parse(text)
            if parsed:
                kind, fields, errors = parsed
                label = fields.get("label")
                if not label and ":" in fields.get("pret", ""):
                    label = fields["pret"].rsplit(":", 1)[1]
                label = label or current
                if label:
                    result[label].append({"kind": kind, "fields": fields, "errors": errors,
                                          "file": rel, "line": number})
    return result


def tarjan(names, pairs):
    graph = {n: [] for n in names}
    for a, b in pairs:
        if a in graph and b in graph:
            graph[a].append(b)
    for values in graph.values():
        values.sort()
    index = 0
    stack, onstack, indices, low, components = [], set(), {}, {}, []

    def visit(v):
        nonlocal index
        indices[v] = low[v] = index
        index += 1
        stack.append(v); onstack.add(v)
        for w in graph[v]:
            if w not in indices:
                visit(w); low[v] = min(low[v], low[w])
            elif w in onstack:
                low[v] = min(low[v], indices[w])
        if low[v] == indices[v]:
            component = []
            while True:
                w = stack.pop(); onstack.remove(w); component.append(w)
                if w == v:
                    break
            components.append(sorted(component))

    for name in sorted(names):
        if name not in indices:
            visit(name)
    return sorted(components, key=lambda c: c[0])


def layout(nodes, edges):
    """Deterministic SCC-ranked layout; callers rank above dependencies."""
    names = sorted(nodes)
    connected = {n for e in edges for n in (e["caller"], e["callee"])}
    pairs = {(e["caller"], e["callee"]) for e in edges}
    comps = tarjan(connected, pairs) if connected else []
    owner = {n: i for i, comp in enumerate(comps) for n in comp}
    outgoing = {i: set() for i in range(len(comps))}
    incoming = {i: set() for i in range(len(comps))}
    for a, b in pairs:
        if a in owner and b in owner and owner[a] != owner[b]:
            outgoing[owner[a]].add(owner[b]); incoming[owner[b]].add(owner[a])
    rank = {}
    def calc(i):
        if i not in rank:
            rank[i] = 0 if not incoming[i] else 1 + max(calc(p) for p in incoming[i])
        return rank[i]
    for i in range(len(comps)):
        calc(i)
    layers = collections.defaultdict(list)
    for i, comp in enumerate(comps):
        layers[rank[i]].append(i)
    order = {}
    for r in sorted(layers):
        layer = layers[r]
        layer.sort(key=lambda i: (sum(order.get(p, 0) for p in incoming[i]) / max(1, len(incoming[i])), comps[i][0]))
        for j, i in enumerate(layer): order[i] = j
    result = {}
    xgap, ygap = 210, 92
    for r in sorted(layers):
        sequence = []
        for i in sorted(layers[r], key=lambda q: (order[q], comps[q][0])):
            sequence.extend(comps[i])
        width = max(0, len(sequence) - 1) * xgap
        for j, name in enumerate(sequence):
            result[name] = {"x": j * xgap - width / 2, "y": r * ygap, "region": "graph"}
    isolated = [n for n in names if n not in connected]
    groups = collections.defaultdict(list)
    for name in isolated:
        row = nodes[name]
        groups[row.get("pret_file") or row.get("port_file") or "referenced/unindexed"].append(name)
    y = (max(rank.values(), default=-1) + 2) * ygap
    for path in sorted(groups):
        for j, name in enumerate(sorted(groups[path])):
            result[name] = {"x": (j % 12) * xgap - 5.5 * xgap,
                            "y": y + (j // 12) * ygap, "region": "isolated", "group": path}
        y += (math.ceil(len(groups[path]) / 12) + 1) * ygap
    return result


def aggregate_edges(rows):
    grouped = {}
    for r in rows:
        key = (r["caller"], r["callee"])
        edge = grouped.setdefault(key, {"caller": key[0], "callee": key[1], "count": 0,
                                        "kinds": set(), "sites": [], "build_active": False})
        edge["count"] += 1; edge["kinds"].add(r["kind"])
        edge["build_active"] = edge["build_active"] or r["build_active"] is None or bool(r["build_active"])
        edge["sites"].append({"file": r["file"], "line": r["line"], "kind": r["kind"],
                              "build_active": r["build_active"]})
    answer = []
    for edge in grouped.values():
        edge["kinds"] = sorted(edge["kinds"])
        edge["sites"].sort(key=lambda s: (s["file"], s["line"] or 0, s["kind"]))
        answer.append(edge)
    return sorted(answer, key=lambda e: (e["caller"], e["callee"]))


def build_graph(con, side, annotations=None):
    if side not in ("pret", "port"):
        raise ValueError(side)
    label_rows = [dict(r) for r in con.execute("SELECT * FROM labels ORDER BY name")]
    nodes = {}
    for row in label_rows:
        if side == "pret" and row["pret_file"] is None:
            continue
        row["display_status"] = "unported" if row["status"] == "missing" else row["status"]
        row["providers"] = []
        nodes[row["name"]] = row
    defs = collections.defaultdict(list)
    for row in con.execute("SELECT * FROM port_defs ORDER BY name,file,line"):
        defs[row["name"]].append(dict(row))
    calls = [dict(r) for r in con.execute("SELECT * FROM calls WHERE side=? ORDER BY caller,callee,file,line", (side,))]
    for call in calls:
        for endpoint in (call["caller"], call["callee"]):
            if endpoint not in nodes:
                nodes[endpoint] = {"name": endpoint, "pret_file": None, "port_file": None,
                                   "status": "unindexed", "display_status": "unindexed", "stub_file": None}
    # Names-only provenance for pret dirs the label model does not cover
    # (audio/, data/, gfx/, ram/ via aux_labels; scripts/ via script_labels).
    # Without this a faithful pret label from one of those reads as `port_only`
    # BY ELIMINATION, and the graph repeats that misclassification as if it were
    # a measured fact. aux_pret_file is provenance ONLY -- no status, no edges.
    aux = {}
    for tbl, col in (("aux_labels", "pret_dir"), ("script_labels", "'scripts'")):
        try:
            for r in con.execute(f"SELECT name, pret_file, {col} AS d FROM {tbl}"):
                aux.setdefault(r["name"], (r["pret_file"], r["d"]))
        except sqlite3.OperationalError:
            pass  # older DB without the side table; provenance simply absent
    for name, node in nodes.items():
        node["providers"] = defs.get(name, [])
        node["annotations"] = (annotations or {}).get(name, [])
        prov = aux.get(name)
        node["aux_pret_file"], node["aux_pret_dir"] = prov if prov else (None, None)
        if prov and node.get("status") == "port_only":
            # Not a port addition: a faithful pret label outside the modeled
            # home/ + engine/ universe. Say so instead of implying it is bespoke.
            node["display_status"] = "pret-unmodeled"
    edges = aggregate_edges(calls)
    positions = layout(nodes, edges)
    result_nodes = []
    incoming, outgoing = collections.defaultdict(list), collections.defaultdict(list)
    for e in edges:
        outgoing[e["caller"]].append(e); incoming[e["callee"]].append(e)
    for name in sorted(nodes):
        node = nodes[name]
        node["position"] = positions[name]
        node["callers"] = incoming[name]
        node["callees"] = outgoing[name]
        result_nodes.append(node)
    return {"side": side, "nodes": result_nodes, "edges": edges,
            "coverage_note": "Modeled labels/calls only (pret home/ + engine/). dd dispatch tables and address-taken targets emit no edge; ISR and jump-table execution is not disproved by their absence. Nodes shown as pret-unmodeled are FAITHFUL PRET LABELS from audio/, data/, gfx/, ram/ or scripts/ that the label model does not cover: aux_pret_file gives their provenance, but they carry no status and no call-graph edges, so absence of edges on them means nothing. A node is only genuinely port-only if display_status is port_only AND aux_pret_file is null."}


def metadata(con, db_path):
    row = con.execute("SELECT scanned_at,git_hash FROM labels WHERE scanned_at IS NOT NULL LIMIT 1").fetchone()
    scanned_at, git_hash = (row if row else (None, None))
    try:
        head = subprocess.check_output(["git", "-C", str(ROOT), "rev-parse", "HEAD"], text=True).strip()
        dirty = subprocess.check_output(["git", "-C", str(ROOT), "status", "--porcelain", "--", "dos_port"], text=True).strip().splitlines()
    except (OSError, subprocess.CalledProcessError):
        head, dirty = None, []
    counts = dict(con.execute("SELECT status,COUNT(*) FROM labels GROUP BY status"))
    return {"db": str(db_path), "scanned_at": scanned_at, "db_commit": git_hash, "head": head,
            "commit_mismatch": bool(git_hash and head and git_hash != head), "source_dirty": bool(dirty),
            "dirty_paths": dirty[:30], "status_counts": counts}


CSS = r"""
:root{color-scheme:dark;font:13px system-ui;background:#10151d;color:#dbe4ef}*{box-sizing:border-box}body{margin:0;overflow:hidden}
header{height:52px;display:flex;align-items:center;gap:10px;padding:8px 12px;background:#182230;border-bottom:1px solid #314158}.tab,button,input{background:#243247;color:#e9f0f8;border:1px solid #40516a;border-radius:5px;padding:7px}.tab.active{background:#446fa5}.grow{flex:1}.warn{color:#ffc766}
#main{display:grid;grid-template-columns:1fr 330px;height:calc(100vh - 52px)}#stage{position:relative;overflow:hidden}canvas{width:100%;height:100%;display:block;background:#0d1219}
#hud{position:absolute;left:10px;top:10px;background:#141d29dd;padding:8px;border-radius:6px;max-width:520px}.legend span{margin-right:9px;white-space:nowrap}.dot{display:inline-block;width:9px;height:9px;border-radius:50%;margin-right:3px}
aside{overflow:auto;padding:12px;background:#141d29;border-left:1px solid #314158}h3{margin:8px 0}.badge{display:inline-block;margin:2px;padding:2px 5px;border-radius:8px;background:#33445c}.rows{font-size:12px}.rows div{padding:3px;border-bottom:1px solid #283548}.filters label{margin-right:8px}code{color:#9ed0ff}
"""

JS = r"""
'use strict';
const colors={translated:'#43c879',relocated:'#a873e8',stub:'#e7aa3b',missing:'#e45858',port_only:'#42cad5','pret-unmodeled':'#d98adf',unindexed:'#8491a3'};
const state={side:'pret',graphs:{},cams:{pret:{x:0,y:0,z:1,tx:0,ty:0,tz:1},port:{x:0,y:0,z:1,tx:0,ty:0,tz:1}},selected:null,query:'',enabled:new Set(Object.keys(colors)),drag:null};
const canvas=document.querySelector('canvas'),ctx=canvas.getContext('2d'),panel=document.querySelector('aside'),count=document.querySelector('#count');
function graph(){return state.graphs[state.side]} function cam(){return state.cams[state.side]}
function resize(){const d=devicePixelRatio||1,r=canvas.getBoundingClientRect();canvas.width=r.width*d;canvas.height=r.height*d;ctx.setTransform(d,0,0,d,0,0)} addEventListener('resize',resize);resize();
function screen(p){const c=cam(),r=canvas.getBoundingClientRect();return{x:(p.x-c.x)*c.z+r.width/2,y:(p.y-c.y)*c.z+r.height/2}}
function visible(n){return state.enabled.has(n.status)&&(!state.query||n.name.toLowerCase().includes(state.query)||((n.pret_file||'')+' '+(n.port_file||'')).toLowerCase().includes(state.query))}
function fit(){const ns=graph().nodes.filter(visible);if(!ns.length)return;let xs=ns.map(n=>n.position.x),ys=ns.map(n=>n.position.y),r=canvas.getBoundingClientRect(),c=cam();c.tx=(Math.min(...xs)+Math.max(...xs))/2;c.ty=(Math.min(...ys)+Math.max(...ys))/2;c.tz=Math.min(1.2,Math.max(.05,Math.min(r.width/(Math.max(...xs)-Math.min(...xs)+300),r.height/(Math.max(...ys)-Math.min(...ys)+160))))}
function detail(n){state.selected=n.name;const links=e=>`${e.caller} → ${e.callee} <small>${e.kinds.join(', ')} ×${e.count}</small>`;panel.innerHTML=`<h3>${n.name}</h3><div><span class=badge>${n.display_status}</span>${n.annotations.map(a=>`<span class=badge>${a.kind}</span>`).join('')}</div><p><b>Pret:</b> ${n.pret_file||n.aux_pret_file&&n.aux_pret_file+' (unmodeled '+n.aux_pret_dir+'/)'||'—'}<br><b>Port:</b> ${n.port_file||'—'}<br><b>Stub:</b> ${n.stub_file||'—'}</p><h3>Providers</h3><div class=rows>${n.providers.map(p=>`<div>${p.file}:${p.line||'?'}</div>`).join('')||'—'}</div><h3>Annotations</h3><div class=rows>${n.annotations.map(a=>`<div>${a.kind} ${a.file}:${a.line}<br>${Object.entries(a.fields).map(([k,v])=>`<b>${k}</b>=${v}`).join('<br>')}</div>`).join('')||'—'}</div><h3>Callers</h3><div class=rows>${n.callers.map(e=>`<div>${links(e)}<br>${e.sites.map(s=>`${s.file}:${s.line||'?'} (${s.kind})`).join('<br>')}</div>`).join('')||'—'}</div><h3>Callees</h3><div class=rows>${n.callees.map(e=>`<div>${links(e)}<br>${e.sites.map(s=>`${s.file}:${s.line||'?'} (${s.kind})`).join('<br>')}</div>`).join('')||'—'}</div>`}
function render(){const g=graph();if(!g){requestAnimationFrame(render);return}const c=cam();c.x+=(c.tx-c.x)*.18;c.y+=(c.ty-c.y)*.18;c.z+=(c.tz-c.z)*.18;ctx.clearRect(0,0,canvas.width,canvas.height);const map=new Map(g.nodes.map(n=>[n.name,n])),shown=new Set(g.nodes.filter(visible).map(n=>n.name));let hood=new Set;if(state.selected){hood.add(state.selected);for(const e of g.edges)if(e.caller===state.selected||e.callee===state.selected){hood.add(e.caller);hood.add(e.callee)}}ctx.lineWidth=1;for(const e of g.edges){if(!shown.has(e.caller)||!shown.has(e.callee))continue;let a=screen(map.get(e.caller).position),b=screen(map.get(e.callee).position);ctx.strokeStyle=hood.size&&(!hood.has(e.caller)||!hood.has(e.callee))?'#26313e':'#71839a';ctx.setLineDash(e.kinds.includes('fallthrough')?[2,4]:e.build_active?[]:[8,5]);ctx.beginPath();ctx.moveTo(a.x,a.y);ctx.lineTo(b.x,b.y);ctx.stroke();let t=.88,x=a.x+(b.x-a.x)*t,y=a.y+(b.y-a.y)*t,ang=Math.atan2(b.y-a.y,b.x-a.x);ctx.beginPath();ctx.moveTo(x,y);ctx.lineTo(x-7*Math.cos(ang-.45),y-7*Math.sin(ang-.45));ctx.lineTo(x-7*Math.cos(ang+.45),y-7*Math.sin(ang+.45));ctx.fillStyle=ctx.strokeStyle;ctx.fill()}ctx.setLineDash([]);let seen=0;const r=canvas.getBoundingClientRect();for(const n of g.nodes){if(!shown.has(n.name))continue;let p=screen(n.position);if(p.x<-100||p.y<-30||p.x>r.width+100||p.y>r.height+30)continue;seen++;let w=c.z>.38?Math.max(70,Math.min(180,ctx.measureText(n.name).width+18)):12,h=c.z>.38?25:12;ctx.fillStyle=colors[n.status];ctx.globalAlpha=hood.size&&!hood.has(n.name)?.25:1;ctx.fillRect(p.x-w/2,p.y-h/2,w,h);if(c.z>.38){ctx.fillStyle='#0c1118';ctx.textAlign='center';ctx.textBaseline='middle';ctx.fillText(n.name,p.x,p.y)}if(n.annotations.length){ctx.fillStyle='#fff';ctx.beginPath();ctx.arc(p.x+w/2-3,p.y-h/2+3,3,0,7);ctx.fill()}ctx.globalAlpha=1}count.textContent=`${seen} visible / ${shown.size} filtered / ${g.nodes.length} total`;requestAnimationFrame(render)}
canvas.onwheel=e=>{e.preventDefault();const c=cam(),r=canvas.getBoundingClientRect(),wx=(e.offsetX-r.width/2)/c.tz+c.tx,wy=(e.offsetY-r.height/2)/c.tz+c.ty,nz=Math.max(.03,Math.min(3,c.tz*Math.exp(-e.deltaY*.001)));c.tx=wx-(e.offsetX-r.width/2)/nz;c.ty=wy-(e.offsetY-r.height/2)/nz;c.tz=nz};
canvas.onpointerdown=e=>{canvas.setPointerCapture(e.pointerId);state.drag={x:e.clientX,y:e.clientY,cx:cam().tx,cy:cam().ty}};canvas.onpointermove=e=>{if(!state.drag)return;cam().tx=state.drag.cx-(e.clientX-state.drag.x)/cam().tz;cam().ty=state.drag.cy-(e.clientY-state.drag.y)/cam().tz};canvas.onpointerup=e=>state.drag=null;
canvas.onclick=e=>{if(state.drag)return;let best=null,bd=25;for(const n of graph().nodes.filter(visible)){let p=screen(n.position),d=Math.hypot(p.x-e.offsetX,p.y-e.offsetY);if(d<bd){best=n;bd=d}}if(best)detail(best)};
document.querySelectorAll('.tab').forEach(b=>b.onclick=()=>{document.querySelector('.tab.active').classList.remove('active');b.classList.add('active');state.side=b.dataset.side;state.selected=null;panel.innerHTML='<p>Select a node for details.</p>'});document.querySelector('#fit').onclick=fit;document.querySelector('#search').oninput=e=>state.query=e.target.value.toLowerCase();
document.querySelector('#search').onkeydown=e=>{if(e.key!=='Enter')return;const n=graph().nodes.find(visible);if(n){cam().tx=n.position.x;cam().ty=n.position.y;cam().tz=Math.max(cam().tz,.8);detail(n)}};
document.querySelectorAll('.filters input').forEach(x=>x.onchange=()=>x.checked?state.enabled.add(x.value):state.enabled.delete(x.value));addEventListener('keydown',e=>{let c=cam(),d=80/c.tz;if(e.key==='ArrowLeft')c.tx-=d;if(e.key==='ArrowRight')c.tx+=d;if(e.key==='ArrowUp')c.ty-=d;if(e.key==='ArrowDown')c.ty+=d;if(e.key==='0')fit()});
Promise.all(['pret','port'].map(s=>fetch('/api/graph/'+s).then(r=>r.json()).then(g=>state.graphs[s]=g))).then(()=>fit());fetch('/api/meta').then(r=>r.json()).then(m=>{if(m.commit_mismatch||m.source_dirty)document.querySelector('#warning').textContent='⚠ DB may be stale';document.querySelector('#stamp').textContent=(m.db_commit||'?').slice(0,8)+' @ '+(m.scanned_at||'?')});requestAnimationFrame(render);
"""

HTML = """<!doctype html><meta charset=utf-8><meta name=viewport content='width=device-width'><title>Pret / DOS Dependency Graph</title><style>""" + CSS + """</style><header><button class='tab active' data-side=pret>Pret</button><button class=tab data-side=port>DOS port</button><input id=search placeholder='Search label or path…'><button id=fit>Fit (0)</button><span class=grow></span><span id=warning class=warn></span><small id=stamp></small></header><div id=main><section id=stage><canvas></canvas><div id=hud><div id=count>Loading…</div><div class=filters>""" + "".join(f"<label><input type=checkbox checked value='{s}'>{'unported' if s=='missing' else s}</label>" for s in sorted(STATUSES | {'unindexed'})) + """</div><div class=legend>""" + "".join(f"<span><i class=dot style='background:{c}'></i>{'unported' if s=='missing' else s}</span>" for s,c in [("translated","#43c879"),("relocated","#a873e8"),("stub","#e7aa3b"),("missing","#e45858"),("port_only","#42cad5"),("pret-unmodeled","#d98adf"),("unindexed","#8491a3")]) + """<br>solid active · dashed inactive/check-only · dotted fall-through</div><small>Drag/trackpad pan · cursor wheel zoom · arrows pan · 0 fits. Isolated nodes are grouped below the connected graph.<br>Coverage caveat: dd/address-taken dispatch targets emit no edge; absent edges do not prove an ISR or jump-table handler is unexecuted.</small></div></section><aside><p>Select a node for details.</p></aside></div><script>""" + JS + """</script>"""


class App:
    def __init__(self, db_path):
        self.db_path = Path(db_path)
        uri = self.db_path.resolve().as_uri() + "?mode=ro"
        self.con = sqlite3.connect(uri, uri=True)
        self.con.row_factory = sqlite3.Row
        validate_db(self.con)
        files = [r[0] for r in self.con.execute("SELECT DISTINCT file FROM port_defs")]
        annotations = scan_annotations(files)
        self.graphs = {side: build_graph(self.con, side, annotations) for side in ("pret", "port")}
        self.meta = metadata(self.con, self.db_path)

    def close(self):
        self.con.close()

    def response(self, path):
        if path == "/" or path == "/index.html": return "text/html; charset=utf-8", HTML.encode()
        if path == "/app.js": return "text/javascript; charset=utf-8", JS.encode()
        if path == "/style.css": return "text/css; charset=utf-8", CSS.encode()
        if path == "/api/meta": return "application/json", json.dumps(self.meta).encode()
        if path in ("/api/graph/pret", "/api/graph/port"):
            return "application/json", json.dumps(self.graphs[path.rsplit('/',1)[1]], separators=(",", ":")).encode()
        return None


def handler_for(app):
    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            response = app.response(urlparse(self.path).path)
            if response is None:
                self.send_error(404); return
            mime, body = response
            self.send_response(200); self.send_header("Content-Type", mime)
            self.send_header("Content-Length", str(len(body))); self.send_header("Cache-Control", "no-store")
            self.end_headers(); self.wfile.write(body)
        def log_message(self, fmt, *args):
            pass
    return Handler


def scanned_db():
    temp = tempfile.TemporaryDirectory(prefix="pokeyellow-dependency-graph-")
    path = Path(temp.name) / "translation.db"
    subprocess.run([sys.executable, str(HERE / "update_label_db"), "--db", str(path)], cwd=ROOT, check=True)
    return temp, path


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", default=str(DEFAULT_DB)); parser.add_argument("--scan", action="store_true")
    parser.add_argument("--host", default="127.0.0.1"); parser.add_argument("--port", type=int, default=0)
    parser.add_argument("--no-browser", action="store_true")
    args = parser.parse_args(argv)
    temp = None
    try:
        if args.scan:
            temp, args.db = scanned_db()
        app = App(args.db)
    except (OSError, sqlite3.Error, DataError, subprocess.CalledProcessError) as exc:
        parser.error(str(exc))
    server = ThreadingHTTPServer((args.host, args.port), handler_for(app))
    host, port = server.server_address[:2]; url = f"http://{host}:{port}/"
    print(url, flush=True)
    if not args.no_browser:
        threading.Timer(.2, lambda: webbrowser.open(url)).start()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
        app.close()
        if temp: temp.cleanup()


if __name__ == "__main__":
    main()
