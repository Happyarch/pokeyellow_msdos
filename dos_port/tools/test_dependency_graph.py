#!/usr/bin/env python3
"""Fixture tests for dependency_graph.py."""
import hashlib
import importlib.util
import json
from pathlib import Path
import sqlite3
import tempfile
import threading
import unittest
from urllib.request import urlopen

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("dependency_graph", HERE / "dependency_graph.py")
dg = importlib.util.module_from_spec(spec); spec.loader.exec_module(dg)

SCHEMA = """
CREATE TABLE labels(name TEXT,pret_file TEXT,port_file TEXT,status TEXT,stub_file TEXT,scanned_at TEXT,git_hash TEXT);
CREATE TABLE calls(caller TEXT,callee TEXT,kind TEXT,side TEXT,file TEXT,line INTEGER,build_active INTEGER);
CREATE TABLE port_defs(name TEXT,file TEXT,line INTEGER,is_stub INTEGER,is_global INTEGER,defined_here INTEGER,instr_count INTEGER,has_call INTEGER,section TEXT);
"""


class GraphTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(); self.path = Path(self.tmp.name) / "fixture.db"
        self.con = sqlite3.connect(self.path); self.con.row_factory = sqlite3.Row; self.con.executescript(SCHEMA)
        rows = [
            ("Root","home/root.asm","dos_port/src/home/root.asm","translated",None,"now","abc"),
            ("Shared","home/shared.asm",None,"stub","dos_port/src/home/home_stubs.asm","now","abc"),
            ("CycleA","engine/a.asm","dos_port/src/engine/a.asm","relocated",None,"now","abc"),
            ("CycleB","engine/b.asm",None,"missing",None,"now","abc"),
            ("Isolated","engine/iso.asm",None,"missing",None,"now","abc"),
            ("PortOnly",None,"dos_port/src/debug.asm","port_only",None,"now","abc"),
        ]
        self.con.executemany("INSERT INTO labels VALUES (?,?,?,?,?,?,?)", rows)
        calls = [
            ("Root","Shared","call","pret","home/root.asm",10,None),
            ("Root","Shared","call","pret","home/root.asm",11,None),
            ("CycleA","CycleB","jp","pret","engine/a.asm",4,None),
            ("CycleB","CycleA","jr","pret","engine/b.asm",7,None),
            ("CycleA","CycleA","call","pret","engine/a.asm",8,None),
            ("Mystery","Shared","call","pret","x.asm",2,None),
            ("Root","Shared","call","port","dos_port/src/home/root.asm",20,1),
            ("PortOnly","Shared","fallthrough","port","dos_port/src/debug.asm",3,1),
            ("Root","UnknownPort","call","port","dos_port/check.asm",5,0),
        ]
        self.con.executemany("INSERT INTO calls VALUES (?,?,?,?,?,?,?)", calls)
        self.con.execute("INSERT INTO port_defs VALUES (?,?,?,?,?,?,?,?,?)", ("Root","dos_port/src/home/root.asm",1,0,1,1,3,1,".text"))
        self.con.commit()

    def tearDown(self):
        self.con.close(); self.tmp.cleanup()

    def test_scope_aggregation_cycles_unknown_and_isolated(self):
        annotation = {"Root": [{"kind":"BUG", "fields":{"class":"temporary"},
                                 "errors":[], "file":"dos_port/src/home/root.asm", "line":2}]}
        pret = dg.build_graph(self.con, "pret", annotation)
        port = dg.build_graph(self.con, "port")
        pn = {n["name"]: n for n in pret["nodes"]}; dn = {n["name"]: n for n in port["nodes"]}
        self.assertNotIn("PortOnly", pn); self.assertIn("PortOnly", dn)
        self.assertIn("Isolated", dn); self.assertEqual(dn["Isolated"]["position"]["region"], "isolated")
        self.assertEqual(pn["Mystery"]["status"], "unindexed"); self.assertIn("UnknownPort", dn)
        edge = next(e for e in pret["edges"] if (e["caller"],e["callee"]) == ("Root","Shared"))
        self.assertEqual(edge["count"], 2); self.assertEqual(len(edge["sites"]), 2)
        self.assertEqual(pn["Root"]["annotations"][0]["kind"], "BUG")
        self.assertTrue(any(e["caller"] == e["callee"] == "CycleA" for e in pret["edges"]))
        for graph in (pret, port):
            self.assertEqual(len({n["name"] for n in graph["nodes"]}), len(graph["nodes"]))
            for node in graph["nodes"]:
                self.assertTrue(all(isinstance(node["position"][k], (int,float)) for k in ("x","y")))

    def test_layout_is_deterministic(self):
        first = dg.build_graph(self.con, "pret")
        second = dg.build_graph(self.con, "pret")
        self.assertEqual([(n["name"],n["position"]) for n in first["nodes"]],
                         [(n["name"],n["position"]) for n in second["nodes"]])

    def test_validation_errors_are_actionable(self):
        bad = sqlite3.connect(":memory:"); bad.execute("CREATE TABLE labels(name TEXT)")
        with self.assertRaisesRegex(dg.DataError, "--scan"):
            dg.validate_db(bad)

    def test_annotation_uses_structured_pret_label(self):
        root = dg.ROOT; dg.ROOT = Path(self.tmp.name)
        try:
            source = dg.ROOT / "dos_port/src/home/root.asm"; source.parent.mkdir(parents=True)
            source.write_text("; BUG{class=temporary; pret=home/root.asm:Root; behavior=x; evidence=y; lifetime=z}\nRoot:\n ret\n", encoding="utf-8")
            found = dg.scan_annotations(["dos_port/src/home/root.asm"])
            self.assertEqual(found["Root"][0]["kind"], "BUG")
        finally:
            dg.ROOT = root

    def test_http_endpoints_and_static_resources(self):
        app = dg.App(self.path)
        server = dg.ThreadingHTTPServer(("127.0.0.1",0), dg.handler_for(app))
        thread = threading.Thread(target=server.serve_forever, daemon=True); thread.start()
        base = f"http://127.0.0.1:{server.server_port}"
        try:
            self.assertIn(b"<canvas", urlopen(base+"/").read())
            self.assertIn(b"requestAnimationFrame", urlopen(base+"/app.js").read())
            self.assertEqual(json.load(urlopen(base+"/api/graph/pret"))["side"], "pret")
            self.assertIn("status_counts", json.load(urlopen(base+"/api/meta")))
        finally:
            server.shutdown(); server.server_close(); thread.join(); app.close()

    def test_default_open_is_read_only(self):
        before = hashlib.sha256(self.path.read_bytes()).digest()
        app = dg.App(self.path); app.close()
        after = hashlib.sha256(self.path.read_bytes()).digest()
        self.assertEqual(before, after)

    def test_scan_uses_temporary_database(self):
        original = dg.DEFAULT_DB
        before = hashlib.sha256(original.read_bytes()).digest()
        temp, scanned = dg.scanned_db()
        try:
            self.assertTrue(scanned.is_file()); self.assertNotEqual(scanned.resolve(), original.resolve())
            con = sqlite3.connect(scanned); dg.validate_db(con); con.close()
        finally:
            temp.cleanup()
        self.assertEqual(before, hashlib.sha256(original.read_bytes()).digest())


if __name__ == "__main__": unittest.main()
