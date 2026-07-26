#!/bin/sh
# Non-vacuity test for .githooks/prepare-commit-msg.
#
# Run it:   .githooks/test_prepare_commit_msg.sh
#
# WHY IT IS CHECKED IN. This repo's rule is that a gate step which cannot fail is
# worse than no gate, because it reads as coverage (see the stigmergy memory
# static-gate-and-ci-wiring). This hook's whole job is to stop a fabricated
# SHA-256 reaching a commit message, and two of its failure modes are silent:
# emitting nothing on an amend, or leaking the block onto unrelated commits.
# Both were REAL bugs caught by this test while the hook was being written; the
# amend case is the exact scenario that motivated the hook. Re-run it if you
# touch the hook.
#
# It builds a throwaway repo in a temp dir; it never touches this working tree.
set -e
hook=$(cd "$(dirname "$0")" && pwd)/prepare-commit-msg
[ -x "$hook" ] || { echo "missing or non-executable: $hook" >&2; exit 1; }

T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
mkdir -p "$T/dos_port/tools" "$T/.githooks"; cd "$T"
git init -q .; git config user.email t@t; git config user.name t
cp "$hook" .githooks/; chmod +x .githooks/prepare-commit-msg
git config core.hooksPath .githooks

p=0; f=0
chk(){ if [ "$2" = "$3" ]; then echo "  PASS $1"; p=$((p+1)); else echo "  FAIL $1 (got '$2' want '$3')"; f=$((f+1)); fi; }
blocks(){ git log -1 --format=%B | grep -cF 'registry approval (inserted' || true; }
has(){ git log -1 --format=%B | grep -cF "$1" || true; }

printf '{\n  "relocated_labels": {"A":1,"B":2,"C":3}\n}\n' > dos_port/tools/pret_label_allowlist.json
echo hi > other.txt

echo "[1] unrelated commit, allowlist never committed -> silent"
git add other.txt; git commit -q -m unrelated; chk "silent" "$(blocks)" "0"

echo "[2] retirement commit (clause A) -> block carries the MEASURED hash"
R=$(sha256sum dos_port/tools/pret_label_allowlist.json | cut -d' ' -f1)
git add dos_port/tools/pret_label_allowlist.json; git commit -q -m "registry: retire"
chk "one block" "$(blocks)" "1"; chk "real hash x2" "$(has "$R")" "2"

echo "[3] 'git commit --amend -m' reword (clause C) -> block MUST survive"
git commit -q --amend -m "registry: retire (reworded)"
chk "block survives" "$(blocks)" "1"; chk "hash survives" "$(has "$R")" "2"

echo "[4] 'git commit --amend --no-edit' (clause B) -> no duplication"
git commit -q --amend --no-edit; chk "still one block" "$(blocks)" "1"

echo "[5] reword again -> still no duplication"
git commit -q --amend -m "registry: retire (reworded twice)"; chk "still one block" "$(blocks)" "1"

echo "[6] next unrelated docs-only commit -> MUST NOT leak the block"
echo x >> other.txt; git add other.txt; git commit -q -m "docs: unrelated"
chk "no leak" "$(blocks)" "0"; chk "no hash leak" "$(has "$R")" "0"

echo "[7] amend of that unrelated commit -> still no leak"
git commit -q --amend -m "docs: unrelated (reworded)"; chk "no leak on amend" "$(blocks)" "0"

echo "[8] amend that EDITS the allowlist -> reports the NEW hash, drops the old"
printf '{\n  "relocated_labels": {"A":1}\n}\n' > dos_port/tools/pret_label_allowlist.json
N=$(sha256sum dos_port/tools/pret_label_allowlist.json | cut -d' ' -f1)
git add dos_port/tools/pret_label_allowlist.json
git commit -q --amend -m "registry: one more"
chk "new hash" "$(has "$N")" "2"; chk "old hash gone" "$(has "$R")" "0"
chk "row count re-measured" "$(has 'remaining: 1')" "1"

echo; echo "RESULT: $p passed, $f failed"; [ "$f" -eq 0 ]
