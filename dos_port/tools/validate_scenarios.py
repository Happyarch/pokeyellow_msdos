#!/usr/bin/env python3
"""Reject drift between the fidelity manifest and current scenario registries."""

import ast
import json
import re
import sys
from pathlib import Path

PORT = Path(__file__).resolve().parents[1]
ROOT = PORT.parent
MANIFEST = PORT / 'tools' / 'scenario_manifest.json'


def load_manifest(path=MANIFEST):
    data = json.loads(Path(path).read_text(encoding='utf-8'))
    if data.get('schema_version') != 1:
        raise ValueError('scenario manifest schema_version must be 1')
    required = {'name', 'id', 'tier', 'scenario_class', 'build_flags',
                'port_entry_gate', 'navigation_script', 'dump', 'must_hit',
                'comparison', 'verification'}
    scenarios = data.get('scenarios', [])
    errors, names, ids = [], set(), set()
    for item in scenarios:
        missing = required - item.keys()
        if missing:
            errors.append(f"{item.get('name', '?')}: missing {sorted(missing)}")
        if item.get('name') in names:
            errors.append(f"duplicate scenario name {item.get('name')}")
        if item.get('id') in ids:
            errors.append(f"duplicate scenario id {item.get('id')}")
        names.add(item.get('name')); ids.add(item.get('id'))
        if not item.get('must_hit'):
            errors.append(f"{item.get('name')}: must_hit may not be empty")
        dump = item.get('dump', {})
        for key in ('type', 'schema_version', 'artifact', 'timeout_seconds', 'terminal_marker'):
            if key not in dump:
                errors.append(f"{item.get('name')}: dump missing {key}")
    if errors:
        raise ValueError('\n'.join(errors))
    return scenarios


def golden_registry():
    tree = ast.parse((PORT / 'tools' / 'golden_diff.py').read_text(encoding='utf-8'))
    result = {}
    for node in tree.body:
        if not isinstance(node, ast.Assign) or not any(
                isinstance(t, ast.Name) and t.id == 'SCENARIOS' for t in node.targets):
            continue
        for key, value in zip(node.value.keys, node.value.values):
            name = ast.literal_eval(key)
            cfg = {'scenario_class': 'default'}
            for k, v in zip(value.keys, value.values):
                if isinstance(k, ast.Constant) and k.value in ('flags', 'class'):
                    cfg['build_flags' if k.value == 'flags' else 'scenario_class'] = ast.literal_eval(v)
            result[name] = cfg
    return result


def makefile_scenarios(variable):
    lines = (PORT / 'Makefile').read_text(encoding='utf-8').splitlines()
    words, collecting = [], False
    for line in lines:
        if not collecting:
            m = re.match(rf'^{re.escape(variable)}\s*:?=\s*(.*)$', line)
            if not m:
                continue
            tail, collecting = m.group(1), True
        else:
            tail = line.strip()
        words.extend(re.findall(r'[a-z][a-z0-9_]+', tail.rstrip('\\').strip()))
        if not line.rstrip().endswith('\\'):
            break
    return words


def debug_ids():
    text = (PORT / 'src' / 'debug' / 'debug_dump.asm').read_text(encoding='utf-8')
    pairs = re.findall(r'%(?:ifn?def|elifdef)\s+(DEBUG_[A-Z0-9_]+)\s*\nGBSTATE_SCENARIO\s+equ\s+(\d+)', text)
    return {gate: int(value) for gate, value in pairs}


def validate():
    scenarios = load_manifest()
    manifest = {x['name']: x for x in scenarios}
    errors = []
    registry = golden_registry()
    if set(manifest) != set(registry):
        errors.append(f"golden registry names differ: manifest-only={sorted(set(manifest)-set(registry))}, golden-only={sorted(set(registry)-set(manifest))}")
    for tier, variable in (("core", "FIDELITY_SCENARIOS_CORE"),
                           ("full", "FIDELITY_SCENARIOS_FULL")):
        expected = [x["name"] for x in scenarios
                    if tier == "full" or x["tier"] == "core"]
        make_names = makefile_scenarios(variable)
        if expected != make_names:
            errors.append(f"{variable} order differs: manifest={expected}, make={make_names}")
    ids = debug_ids()
    for name, item in manifest.items():
        cfg = registry.get(name, {})
        for key in ('build_flags', 'scenario_class'):
            if cfg.get(key) != item[key]:
                errors.append(f"{name}: {key} manifest={item[key]!r}, golden_diff={cfg.get(key)!r}")
        if ids.get(item['port_entry_gate']) != item['id']:
            errors.append(f"{name}: gate {item['port_entry_gate']} id manifest={item['id']}, asm={ids.get(item['port_entry_gate'])}")
        nav = PORT / item['navigation_script']
        if not nav.is_file():
            errors.append(f"{name}: missing navigation script {nav.relative_to(ROOT)}")
        for suffix in ('.bin', '.json'):
            artifact = PORT / 'tests' / 'goldens' / f'{name}{suffix}'
            if not artifact.is_file():
                errors.append(f"{name}: missing golden {artifact.relative_to(ROOT)}")
        sidecar = PORT / 'tests' / 'goldens' / f'{name}.json'
        if sidecar.is_file() and json.loads(sidecar.read_text()).get('scenario') != name:
            errors.append(f"{name}: sidecar scenario identity mismatch")
        sources = '\n'.join(path.read_text(encoding='utf-8', errors='replace')
                            for path in (PORT / 'src').rglob('*.asm'))
        for label in item['must_hit']:
            if not re.search(rf'(?m)^{re.escape(label)}:', sources):
                errors.append(f"{name}: must_hit label {label} is not defined")
    return errors


def main():
    errors = validate()
    if errors:
        print('\n'.join('ERROR: ' + e for e in errors))
        return 1
    print(f"validate_scenarios: {len(load_manifest())} scenarios consistent")
    return 0


if __name__ == '__main__':
    sys.exit(main())
