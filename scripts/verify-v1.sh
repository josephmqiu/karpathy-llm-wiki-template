#!/usr/bin/env bash
# verify-v1.sh — User's LLM Wiki integrity checks
#
# Run from anywhere; the script changes to the vault root automatically.
# Exit codes: 0 = pass (or pass-with-warnings), 1 = fail
#
# Checks:
#   1. Folder structure (required directories + files exist)
#   2. YAML frontmatter on wiki content pages (parseable + required fields)
#   3. Dead wikilink detection
#   4. Manifest reconciliation (raw/ files <-> raw/.manifest.json)
#   5. Log reconciliation (ingested manifest entries <-> log.md)
#   6. Log ordering (append-bottom, chronological)
#   7. Naming convention (kebab-case in wiki/)
#   8. Kill-switch metric (% of shared entities linked from 2+ MOCs)
#
# Requires: bash, python3 (stdlib only), grep, find, awk, sed, sort.

set -uo pipefail

# Find vault root (parent of scripts/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$VAULT_ROOT" || exit 1

# Colors (only if stdout is a terminal)
if [[ -t 1 ]]; then
    RED=$'\033[0;31m'
    GREEN=$'\033[0;32m'
    YELLOW=$'\033[1;33m'
    BLUE=$'\033[0;34m'
    BOLD=$'\033[1m'
    NC=$'\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' BOLD='' NC=''
fi

PASS=0
FAIL=0
WARN=0

pass() {
    echo "  ${GREEN}✓${NC} $1"
    PASS=$((PASS + 1))
}

fail() {
    echo "  ${RED}✗${NC} $1"
    FAIL=$((FAIL + 1))
}

warn() {
    echo "  ${YELLOW}!${NC} $1"
    WARN=$((WARN + 1))
}

section() {
    echo
    echo "${BLUE}${BOLD}==>${NC} ${BOLD}$1${NC}"
}

# ----------------------------------------------------------------------
# Check 1: folder structure + required files
# ----------------------------------------------------------------------
section "Check 1: folder structure"

required_dirs=(
    "raw" "raw/assets"
    "wiki" "wiki/shared/entities" "wiki/shared/concepts" "wiki/shared/sources"
    "wiki/domains" "wiki/synthesis" "wiki/meta"
    "scripts" "inbox"
)
missing_dirs=()
for dir in "${required_dirs[@]}"; do
    [[ -d "$dir" ]] || missing_dirs+=("$dir")
done
if [[ ${#missing_dirs[@]} -eq 0 ]]; then
    pass "all ${#required_dirs[@]} required folders exist"
else
    fail "missing folders: ${missing_dirs[*]}"
fi

required_files=("CLAUDE.md" "wiki/index.md" "wiki/log.md" "raw/.manifest.json" "wiki/meta/dashboard.md")
missing_files=()
for f in "${required_files[@]}"; do
    [[ -f "$f" ]] || missing_files+=("$f")
done
if [[ ${#missing_files[@]} -eq 0 ]]; then
    pass "all ${#required_files[@]} required files exist"
else
    fail "missing files: ${missing_files[*]}"
fi

# At least one MOC must exist
moc_count=$(find wiki/domains -name "*-moc.md" 2>/dev/null | wc -l | tr -d ' ')
if [[ "$moc_count" -ge 1 ]]; then
    pass "$moc_count MOC(s) found under wiki/domains/"
else
    fail "no MOC found under wiki/domains/*/*-moc.md"
fi

# ----------------------------------------------------------------------
# Check 2: YAML frontmatter on wiki content pages
# ----------------------------------------------------------------------
section "Check 2: YAML frontmatter on wiki content pages"

# Content pages: everything in wiki/ EXCEPT navigation/meta files
# - index.md and log.md are navigation (top-level wiki/)
# - wiki/meta/* are system docs (dashboards, user manuals, etc.) with their own format
content_pages=()
while IFS= read -r f; do
    base=$(basename "$f")
    [[ "$base" == "index.md" || "$base" == "log.md" ]] && continue
    [[ "$f" == wiki/meta/* ]] && continue
    content_pages+=("$f")
done < <(find wiki -name "*.md" 2>/dev/null)

bad_frontmatter=()
missing_required=()
required_fields=("id" "title" "type" "created" "updated")

for f in "${content_pages[@]}"; do
    first_line=$(head -1 "$f")
    if [[ "$first_line" != "---" ]]; then
        bad_frontmatter+=("$f (no opening ---)")
        continue
    fi
    fm_end=$(awk 'NR>1 && /^---$/{print NR; exit}' "$f")
    if [[ -z "$fm_end" ]]; then
        bad_frontmatter+=("$f (no closing ---)")
        continue
    fi
    fm=$(sed -n "2,$((fm_end - 1))p" "$f")
    for field in "${required_fields[@]}"; do
        if ! echo "$fm" | grep -q "^${field}:"; then
            missing_required+=("$f: missing $field")
        fi
    done
done

n_pages=${#content_pages[@]}
if [[ ${#bad_frontmatter[@]} -eq 0 && ${#missing_required[@]} -eq 0 ]]; then
    if [[ "$n_pages" -eq 0 ]]; then
        pass "no content pages yet (skeleton state)"
    else
        pass "all $n_pages content pages have valid frontmatter"
    fi
else
    for bf in "${bad_frontmatter[@]}"; do
        fail "bad frontmatter: $bf"
    done
    for mr in "${missing_required[@]}"; do
        fail "$mr"
    done
fi

# ----------------------------------------------------------------------
# Check 3: Dead wikilink detection
# ----------------------------------------------------------------------
section "Check 3: dead wikilink detection"

# Build a set of valid wikilink targets: every .md file's basename (without .md)
declare -a valid_targets=()
while IFS= read -r f; do
    valid_targets+=("$(basename "$f" .md)")
done < <(find wiki -name "*.md" 2>/dev/null)

# Also accept any file's id (from frontmatter) if different from basename — TODO future
# For v1, basename match is enough.

# Find all [[link]] occurrences in wiki/, extract targets
declare -a dead_links=()
total_links=0

while IFS= read -r raw_match; do
    # raw_match is like "wiki/foo.md:5:- [[bar|display]]"
    file_part="${raw_match%%:*}"
    rest="${raw_match#*:}"
    line_part="${rest%%:*}"
    # Extract all [[...]] patterns from the line, skipping those inside backtick code spans
    line_text="${rest#*:}"
    # Use python for safe extraction (strips inline `code` spans first)
    extracted=$(python3 -c '
import re, sys
text = sys.stdin.read()
# Strip inline code spans (single-backtick) so [[link]] inside them is ignored
text = re.sub(r"`[^`]*`", "", text)
for m in re.finditer(r"\[\[([^\]|#]+)", text):
    print(m.group(1).strip())
' <<<"$line_text")

    while IFS= read -r link; do
        [[ -z "$link" ]] && continue
        total_links=$((total_links + 1))
        # Skip URLs
        [[ "$link" == http* ]] && continue
        # Check if any valid target matches
        found=0
        for vt in "${valid_targets[@]}"; do
            if [[ "$vt" == "$link" ]]; then
                found=1
                break
            fi
        done
        if [[ "$found" -eq 0 ]]; then
            dead_links+=("$file_part:$line_part [[$link]]")
        fi
    done <<<"$extracted"
done < <(grep -rn '\[\[' wiki/ 2>/dev/null | grep -v '^Binary')

if [[ ${#dead_links[@]} -eq 0 ]]; then
    pass "no dead wikilinks ($total_links total wikilinks checked)"
else
    fail "${#dead_links[@]} dead wikilinks (of $total_links total):"
    for dl in "${dead_links[@]:0:10}"; do
        echo "      $dl"
    done
    [[ ${#dead_links[@]} -gt 10 ]] && echo "      ... and $((${#dead_links[@]} - 10)) more"
fi

# ----------------------------------------------------------------------
# Check 4: Manifest reconciliation
# ----------------------------------------------------------------------
section "Check 4: manifest reconciliation"

manifest_result=$(python3 - <<'PYEOF'
import json
import os
import sys

try:
    with open("raw/.manifest.json") as f:
        manifest = json.load(f)
except json.JSONDecodeError as e:
    print(f"FAIL: invalid JSON in raw/.manifest.json: {e}")
    sys.exit(0)
except FileNotFoundError:
    print("FAIL: raw/.manifest.json not found")
    sys.exit(0)

if not isinstance(manifest, list):
    print("FAIL: manifest must be a JSON array (got " + type(manifest).__name__ + ")")
    sys.exit(0)

# Files in raw/ (excluding .gitkeep, .manifest.json, assets/)
raw_files = set()
for entry in os.listdir("raw"):
    if entry in (".gitkeep", ".manifest.json"):
        continue
    full = f"raw/{entry}"
    if os.path.isfile(full):
        raw_files.add(full)

manifest_paths = set()
hashes_seen = {}
problems = []

for i, entry in enumerate(manifest):
    if not isinstance(entry, dict):
        problems.append(f"entry {i} is not an object")
        continue
    path = entry.get("source_path")
    h = entry.get("hash")
    status = entry.get("status", "unknown")
    if not path:
        problems.append(f"entry {i} has no source_path")
        continue
    manifest_paths.add(path)
    if h:
        if h in hashes_seen:
            problems.append(f"duplicate hash {h[:12]}... in {hashes_seen[h]} and {path}")
        hashes_seen[h] = path
    if status not in ("ingested", "deferred"):
        problems.append(f"{path}: invalid status '{status}' (must be 'ingested' or 'deferred')")
    if not os.path.exists(path):
        problems.append(f"manifest references missing file: {path}")
    if status == "ingested" and not h:
        problems.append(f"{path}: status=ingested but hash is null")

orphan_files = raw_files - manifest_paths
for f in sorted(orphan_files):
    problems.append(f"raw/ file not in manifest: {f}")

if problems:
    for p in problems:
        print(f"PROBLEM: {p}")
    print(f"FAIL: {len(problems)} reconciliation issue(s)")
else:
    n_ingested = sum(1 for e in manifest if e.get("status") == "ingested")
    n_deferred = sum(1 for e in manifest if e.get("status") == "deferred")
    print(f"PASS: {len(manifest)} manifest entries ({n_ingested} ingested, {n_deferred} deferred), {len(raw_files)} raw files, all reconciled")
PYEOF
)

if echo "$manifest_result" | head -1 | grep -q "^PASS"; then
    pass "$(echo "$manifest_result" | head -1 | sed 's/^PASS: //')"
else
    while IFS= read -r line; do
        if [[ "$line" == FAIL:* ]]; then
            fail "${line#FAIL: }"
        elif [[ "$line" == PROBLEM:* ]]; then
            echo "      ${line#PROBLEM: }"
        fi
    done <<<"$manifest_result"
fi

# ----------------------------------------------------------------------
# Check 5: Log reconciliation
# ----------------------------------------------------------------------
section "Check 5: log reconciliation"

log_result=$(python3 - <<'PYEOF'
import json
import re
import sys

try:
    with open("raw/.manifest.json") as f:
        manifest = json.load(f)
    with open("wiki/log.md") as f:
        log = f.read()
except Exception as e:
    print(f"FAIL: {e}")
    sys.exit(0)

ingested = [e for e in manifest if e.get("status") == "ingested"]

# For each ingested entry, look for an ingest log line.
# Loose check: there should be at least one "## [date] ingest |" line per ingested entry.
ingest_lines = re.findall(r"^## \[\d{4}-\d{2}-\d{2}\] ingest \|", log, re.MULTILINE)

if not ingested:
    print("PASS: no ingested entries yet (deferred entries don't require log presence)")
elif len(ingest_lines) < len(ingested):
    print(f"FAIL: {len(ingested)} ingested manifest entries but only {len(ingest_lines)} ingest log lines")
else:
    print(f"PASS: {len(ingested)} ingested entries with {len(ingest_lines)} log lines")
PYEOF
)

if echo "$log_result" | grep -q "^PASS"; then
    pass "$(echo "$log_result" | sed 's/^PASS: //')"
else
    fail "$(echo "$log_result" | sed 's/^FAIL: //')"
fi

# ----------------------------------------------------------------------
# Check 6: Log ordering (chronological, append-bottom)
# ----------------------------------------------------------------------
section "Check 6: log ordering (append-bottom)"

dates=$(grep -oE '^## \[[0-9]{4}-[0-9]{2}-[0-9]{2}\]' wiki/log.md 2>/dev/null | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}')
if [[ -z "$dates" ]]; then
    warn "log has no dated entries yet"
else
    sorted_dates=$(echo "$dates" | sort)
    if [[ "$dates" == "$sorted_dates" ]]; then
        n=$(echo "$dates" | wc -l | tr -d ' ')
        pass "log is sorted oldest-first ($n entries)"
    else
        fail "log is NOT sorted chronologically (append-bottom rule violated)"
    fi
fi

# ----------------------------------------------------------------------
# Check 7: Naming convention (kebab-case in wiki/)
# ----------------------------------------------------------------------
section "Check 7: naming convention (kebab-case)"

bad_names=()
while IFS= read -r f; do
    base=$(basename "$f" .md)
    # Allow lowercase alphanumerics, hyphens; reject uppercase, underscores, spaces, punctuation
    if [[ ! "$base" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
        bad_names+=("$f")
    fi
done < <(find wiki -name "*.md" 2>/dev/null | grep -v -E '/(index|log|dashboard)\.md$')

if [[ ${#bad_names[@]} -eq 0 ]]; then
    pass "all wiki content files follow kebab-case naming"
else
    fail "${#bad_names[@]} non-kebab-case file(s):"
    for bn in "${bad_names[@]}"; do
        echo "      $bn"
    done
fi

# ----------------------------------------------------------------------
# Check 8: Kill-switch metric (deferred until 2+ topics)
# ----------------------------------------------------------------------
section "Check 8: kill-switch metric"

if [[ "$moc_count" -lt 2 ]]; then
    warn "kill-switch metric deferred (only $moc_count MOC; need 2+ topics to compute)"
else
    total=$(find wiki/shared/entities -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$total" -eq 0 ]]; then
        warn "no shared entities yet"
    else
        multi=0
        for ent in wiki/shared/entities/*.md; do
            [[ -f "$ent" ]] || continue
            base=$(basename "$ent" .md)
            count=$(grep -l "\[\[$base" wiki/domains/*/*-moc.md 2>/dev/null | wc -l | tr -d ' ')
            [[ "$count" -ge 2 ]] && multi=$((multi + 1))
        done
        pct=$((multi * 100 / total))
        if [[ "$pct" -lt 20 ]]; then
            warn "kill-switch metric: $multi of $total shared entities ($pct%) linked from 2+ MOCs (below 20% threshold — consider migrating to domain-first placement)"
        else
            pass "kill-switch metric: $multi of $total shared entities ($pct%) linked from 2+ MOCs (type-first hybrid is working)"
        fi
    fi
fi

# ----------------------------------------------------------------------
# Summary
# ----------------------------------------------------------------------
echo
echo "${BLUE}${BOLD}==>${NC} ${BOLD}Summary${NC}"
echo "  ${GREEN}Passed:${NC}   $PASS"
echo "  ${YELLOW}Warnings:${NC} $WARN"
echo "  ${RED}Failed:${NC}   $FAIL"
echo

if [[ "$FAIL" -gt 0 ]]; then
    echo "${RED}${BOLD}verify-v1: FAIL${NC}"
    exit 1
elif [[ "$WARN" -gt 0 ]]; then
    echo "${YELLOW}${BOLD}verify-v1: PASS WITH WARNINGS${NC}"
    exit 0
else
    echo "${GREEN}${BOLD}verify-v1: PASS${NC}"
    exit 0
fi
