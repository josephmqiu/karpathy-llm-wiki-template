#!/usr/bin/env bash
# verify-v1.sh — LLM Wiki integrity checks
#
# Run from anywhere; the script changes to the vault root automatically.
# Exit codes: 0 = pass (or pass-with-warnings), 1 = fail
#
# Checks:
#   1. Folder structure (required directories + files exist, including skills/)
#   2. YAML frontmatter on wiki content pages (parseable + required fields)
#   3. Dead wikilink detection
#   4. Manifest reconciliation (raw/ files <-> raw/.manifest.json)
#   5. Log reconciliation (ingested manifest entries <-> log.md)
#   6. Log ordering (append-bottom, chronological)
#   7. Naming convention (kebab-case in wiki/)
#   8. Kill-switch metric (% of shared entities linked from 2+ MOCs)
#   9. Orphan pages (zero inbound links from other content pages)
#  10. Stub-rot (status: stub older than 30 days)
#  11. Stale last_reviewed dates (>60 days old)
#  12. Alias/title collisions
#  13. Query/synthesis health
#  14. Skill catalog sync (CLAUDE.md §9 table <-> skills/ directory)
#  15. Skill frontmatter well-formed (required fields, id matches dir)
#  16. Log-op coverage (skill log_op values <-> CLAUDE.md §10 op tokens)
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
    "skills" "skills/ingest" "skills/query" "skills/lint" "skills/triage" "skills/migrate"
    "skills/autoresearch" "skills/autoresearch/references"
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

required_files=(
    "CLAUDE.md" "wiki/index.md" "wiki/log.md" "raw/.manifest.json" "wiki/meta/dashboard.md"
    "skills/README.md"
    "skills/ingest/SKILL.md" "skills/query/SKILL.md"
    "skills/lint/SKILL.md" "skills/triage/SKILL.md" "skills/migrate/SKILL.md"
    "skills/autoresearch/SKILL.md" "skills/autoresearch/references/program.md"
    "wiki/meta/obsidian-formatting.md"
)
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
# Check 2: YAML frontmatter + schema on wiki content pages
# ----------------------------------------------------------------------
section "Check 2: YAML frontmatter + schema on wiki content pages"

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

schema_result=$(python3 - <<'PYEOF'
import ast
import os
import re
import sys

content_pages = []
for root, _, files in os.walk("wiki"):
    for name in files:
        if not name.endswith(".md"):
            continue
        path = os.path.join(root, name)
        base = os.path.basename(path)
        if base in ("index.md", "log.md"):
            continue
        if path.startswith("wiki/meta/"):
            continue
        content_pages.append(path)

required_fields = ("id", "title", "type", "status", "topics", "created", "updated", "last_reviewed", "superseded_by")
valid_types = {"entity", "concept", "source", "synthesis", "moc"}
valid_status = {"stub", "draft", "stable", "superseded"}
date_re = re.compile(r"^\d{4}-\d{2}-\d{2}$")
hash_re = re.compile(r"^[0-9a-f]{64}$")
wikilink_re = re.compile(r"^\[\[[^\]]+\]\]$")

def strip_quotes(value):
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in ("'", '"'):
        return value[1:-1]
    return value

def parse_value(raw):
    raw = raw.strip()
    if raw == "":
        return ""
    if raw == "null":
        return None
    if raw.startswith("[") and raw.endswith("]"):
        try:
            return ast.literal_eval(raw.replace("null", "None"))
        except Exception:
            return raw
    if raw.startswith("- "):
        items = []
        for line in raw.splitlines():
            line = line.strip()
            if not line.startswith("- "):
                return raw
            items.append(strip_quotes(line[2:].strip()))
        return items
    return strip_quotes(raw)

def parse_frontmatter(block):
    data = {}
    current_key = None
    current_lines = []
    for line in block.splitlines():
        if re.match(r"^[A-Za-z_][A-Za-z0-9_]*:\s*", line):
            if current_key is not None:
                data[current_key] = parse_value("\n".join(current_lines))
            key, rest = line.split(":", 1)
            current_key = key.strip()
            current_lines = [rest.strip()] if rest.strip() else []
        else:
            if current_key is not None:
                current_lines.append(line)
    if current_key is not None:
        data[current_key] = parse_value("\n".join(current_lines))
    return data

problems = []

for path in sorted(content_pages):
    try:
        with open(path) as f:
            text = f.read()
    except Exception as e:
        problems.append(f"{path}: unreadable ({e})")
        continue

    if not text.startswith("---\n"):
        problems.append(f"{path}: no opening ---")
        continue

    match = re.search(r"\n---\n", text[4:])
    if not match:
        problems.append(f"{path}: no closing ---")
        continue

    fm_end = 4 + match.start()
    frontmatter = text[4:fm_end]
    data = parse_frontmatter(frontmatter)

    for field in required_fields:
        if field not in data:
            problems.append(f"{path}: missing {field}")

    if any(p.startswith(f"{path}: missing") for p in problems):
        continue

    stem = os.path.splitext(os.path.basename(path))[0]
    if data["id"] != stem:
        problems.append(f"{path}: id '{data['id']}' does not match filename '{stem}'")

    if data["type"] not in valid_types:
        problems.append(f"{path}: invalid type '{data['type']}'")

    if data["status"] not in valid_status:
        problems.append(f"{path}: invalid status '{data['status']}'")

    topics = data["topics"]
    if not isinstance(topics, list) or len(topics) == 0 or not all(isinstance(t, str) and t.strip() for t in topics):
        problems.append(f"{path}: topics must be a non-empty array of strings")

    for field in ("created", "updated", "last_reviewed"):
        if not isinstance(data[field], str) or not date_re.match(data[field]):
            problems.append(f"{path}: {field} must be ISO date YYYY-MM-DD")

    superseded_by = data["superseded_by"]
    if data["status"] == "superseded":
        if not isinstance(superseded_by, str) or not wikilink_re.match(superseded_by):
            problems.append(f"{path}: status=superseded requires superseded_by='[[replacement-page]]'")
    else:
        if superseded_by is not None:
            problems.append(f"{path}: superseded_by must be null unless status=superseded")

    page_type = data["type"]
    if page_type == "source":
        source_ref = data.get("source_ref")
        hash_value = data.get("hash")
        if not isinstance(source_ref, str) or not source_ref.startswith("raw/"):
            problems.append(f"{path}: source page must have source_ref under raw/")
        elif not os.path.exists(source_ref):
            problems.append(f"{path}: source_ref points to missing file {source_ref}")
        if not isinstance(hash_value, str) or not hash_re.match(hash_value):
            problems.append(f"{path}: source page hash must be 64 lowercase hex chars")
    else:
        if "sources" not in data:
            problems.append(f"{path}: non-source page missing sources")
        else:
            sources = data["sources"]
            if not isinstance(sources, list):
                problems.append(f"{path}: sources must be an array")
            else:
                for src in sources:
                    if not isinstance(src, str) or not src.startswith("raw/"):
                        problems.append(f"{path}: sources entries must be raw/ paths")
                        break
                    if not os.path.exists(src):
                        problems.append(f"{path}: sources references missing file {src}")
                        break

    if page_type == "synthesis":
        question = data.get("question")
        if not isinstance(question, str) or not question.strip():
            problems.append(f"{path}: synthesis page must have non-empty question")

if problems:
    for problem in problems:
        print(f"PROBLEM: {problem}")
    print(f"FAIL: {len(problems)} schema issue(s)")
else:
    print(f"PASS: all {len(content_pages)} content pages have valid frontmatter and schema")
PYEOF
)

if echo "$schema_result" | head -1 | grep -q "^PASS"; then
    pass "$(echo "$schema_result" | head -1 | sed 's/^PASS: //')"
else
    while IFS= read -r line; do
        if [[ "$line" == FAIL:* ]]; then
            fail "${line#FAIL: }"
        elif [[ "$line" == PROBLEM:* ]]; then
            echo "      ${line#PROBLEM: }"
        fi
    done <<<"$schema_result"
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
done < <(grep -rn '\[\[' wiki/ 2>/dev/null | grep -v '^Binary' | grep -v '^wiki/meta/')

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
    pass "kill-switch metric not applicable (only $moc_count MOC; metric computes once there are 2+ topics)"
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
# Check 9: orphan pages
# ----------------------------------------------------------------------
section "Check 9: orphan pages"

orphans_result=$(python3 - <<'PYEOF'
import os
import re

content_pages = []
for root, _, files in os.walk("wiki"):
    for name in files:
        if not name.endswith(".md"):
            continue
        path = os.path.join(root, name)
        base = os.path.basename(path)
        if base in ("index.md", "log.md"):
            continue
        if path.startswith("wiki/meta/"):
            continue
        content_pages.append(path)

targets = {os.path.splitext(os.path.basename(path))[0]: path for path in content_pages}
inbound = {target: 0 for target in targets}
link_re = re.compile(r"\[\[([^\]]+)\]\]")

for path in content_pages:
    try:
        with open(path) as f:
            text = f.read()
    except Exception:
        continue
    text = re.sub(r"\x60[^\x60]*\x60", "", text)
    for match in link_re.finditer(text):
        target = match.group(1).split("|", 1)[0].split("#", 1)[0].strip()
        if target in targets and targets[target] != path:
            inbound[target] += 1

orphans = sorted(
    target
    for target, count in inbound.items()
    if count == 0 and not targets[target].endswith("-moc.md")
)
if not orphans:
    print(f"PASS: no orphan content pages ({len(content_pages)} pages checked)")
else:
    for orphan in orphans:
        print(f"PROBLEM: {orphan}")
    print(f"WARN: {len(orphans)} orphan page(s)")
PYEOF
)

if echo "$orphans_result" | head -1 | grep -q "^PASS"; then
    pass "$(echo "$orphans_result" | head -1 | sed 's/^PASS: //')"
else
    while IFS= read -r line; do
        if [[ "$line" == WARN:* ]]; then
            warn "${line#WARN: }"
        elif [[ "$line" == PROBLEM:* ]]; then
            echo "      ${line#PROBLEM: }"
        fi
    done <<<"$orphans_result"
fi

# ----------------------------------------------------------------------
# Check 10: Stub-rot
# ----------------------------------------------------------------------
section "Check 10: stub-rot"

stub_result=$(python3 - <<'PYEOF'
import ast
import datetime as dt
import os
import re

def strip_quotes(value):
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in ("'", '"'):
        return value[1:-1]
    return value

def parse_value(raw):
    raw = raw.strip()
    if raw == "":
        return ""
    if raw == "null":
        return None
    if raw.startswith("[") and raw.endswith("]"):
        try:
            return ast.literal_eval(raw.replace("null", "None"))
        except Exception:
            return raw
    if raw.startswith("- "):
        items = []
        for line in raw.splitlines():
            line = line.strip()
            if not line.startswith("- "):
                return raw
            items.append(strip_quotes(line[2:].strip()))
        return items
    return strip_quotes(raw)

def parse_frontmatter(path):
    with open(path) as f:
        text = f.read()
    if not text.startswith("---\n"):
        return {}
    match = re.search(r"\n---\n", text[4:])
    if not match:
        return {}
    block = text[4:4 + match.start()]
    data = {}
    current_key = None
    current_lines = []
    for line in block.splitlines():
        if re.match(r"^[A-Za-z_][A-Za-z0-9_]*:\s*", line):
            if current_key is not None:
                data[current_key] = parse_value("\n".join(current_lines))
            key, rest = line.split(":", 1)
            current_key = key.strip()
            current_lines = [rest.strip()] if rest.strip() else []
        elif current_key is not None:
            current_lines.append(line)
    if current_key is not None:
        data[current_key] = parse_value("\n".join(current_lines))
    return data

today = dt.date.today()
stubs = []
for root, _, files in os.walk("wiki"):
    for name in files:
        if not name.endswith(".md"):
            continue
        path = os.path.join(root, name)
        base = os.path.basename(path)
        if base in ("index.md", "log.md") or path.startswith("wiki/meta/"):
            continue
        data = parse_frontmatter(path)
        if data.get("status") != "stub":
            continue
        created = data.get("created")
        try:
            age_days = (today - dt.date.fromisoformat(created)).days
        except Exception:
            continue
        if age_days > 30:
            stubs.append(f"{path} ({age_days} days old)")

if not stubs:
    print("PASS: no stale stub pages")
else:
    for stub in stubs:
        print(f"PROBLEM: {stub}")
    print(f"WARN: {len(stubs)} stale stub page(s)")
PYEOF
)

if echo "$stub_result" | head -1 | grep -q "^PASS"; then
    pass "$(echo "$stub_result" | head -1 | sed 's/^PASS: //')"
else
    while IFS= read -r line; do
        if [[ "$line" == WARN:* ]]; then
            warn "${line#WARN: }"
        elif [[ "$line" == PROBLEM:* ]]; then
            echo "      ${line#PROBLEM: }"
        fi
    done <<<"$stub_result"
fi

# ----------------------------------------------------------------------
# Check 11: stale last_reviewed
# ----------------------------------------------------------------------
section "Check 11: stale last_reviewed"

stale_result=$(python3 - <<'PYEOF'
import ast
import datetime as dt
import os
import re

def strip_quotes(value):
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in ("'", '"'):
        return value[1:-1]
    return value

def parse_value(raw):
    raw = raw.strip()
    if raw == "":
        return ""
    if raw == "null":
        return None
    if raw.startswith("[") and raw.endswith("]"):
        try:
            return ast.literal_eval(raw.replace("null", "None"))
        except Exception:
            return raw
    if raw.startswith("- "):
        items = []
        for line in raw.splitlines():
            line = line.strip()
            if not line.startswith("- "):
                return raw
            items.append(strip_quotes(line[2:].strip()))
        return items
    return strip_quotes(raw)

def parse_frontmatter(path):
    with open(path) as f:
        text = f.read()
    if not text.startswith("---\n"):
        return {}
    match = re.search(r"\n---\n", text[4:])
    if not match:
        return {}
    block = text[4:4 + match.start()]
    data = {}
    current_key = None
    current_lines = []
    for line in block.splitlines():
        if re.match(r"^[A-Za-z_][A-Za-z0-9_]*:\s*", line):
            if current_key is not None:
                data[current_key] = parse_value("\n".join(current_lines))
            key, rest = line.split(":", 1)
            current_key = key.strip()
            current_lines = [rest.strip()] if rest.strip() else []
        elif current_key is not None:
            current_lines.append(line)
    if current_key is not None:
        data[current_key] = parse_value("\n".join(current_lines))
    return data

today = dt.date.today()
stale = []
for root, _, files in os.walk("wiki"):
    for name in files:
        if not name.endswith(".md"):
            continue
        path = os.path.join(root, name)
        base = os.path.basename(path)
        if base in ("index.md", "log.md") or path.startswith("wiki/meta/"):
            continue
        data = parse_frontmatter(path)
        reviewed = data.get("last_reviewed")
        try:
            age_days = (today - dt.date.fromisoformat(reviewed)).days
        except Exception:
            continue
        if age_days > 60:
            stale.append(f"{path} ({age_days} days since review)")

if not stale:
    print("PASS: no pages older than 60 days since last_reviewed")
else:
    for item in stale:
        print(f"PROBLEM: {item}")
    print(f"WARN: {len(stale)} stale page(s)")
PYEOF
)

if echo "$stale_result" | head -1 | grep -q "^PASS"; then
    pass "$(echo "$stale_result" | head -1 | sed 's/^PASS: //')"
else
    while IFS= read -r line; do
        if [[ "$line" == WARN:* ]]; then
            warn "${line#WARN: }"
        elif [[ "$line" == PROBLEM:* ]]; then
            echo "      ${line#PROBLEM: }"
        fi
    done <<<"$stale_result"
fi

# ----------------------------------------------------------------------
# Check 12: Alias/title collisions
# ----------------------------------------------------------------------
section "Check 12: alias/title collisions"

collision_result=$(python3 - <<'PYEOF'
import ast
import os
import re

def strip_quotes(value):
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in ("'", '"'):
        return value[1:-1]
    return value

def parse_value(raw):
    raw = raw.strip()
    if raw == "":
        return ""
    if raw == "null":
        return None
    if raw.startswith("[") and raw.endswith("]"):
        try:
            return ast.literal_eval(raw.replace("null", "None"))
        except Exception:
            return raw
    if raw.startswith("- "):
        items = []
        for line in raw.splitlines():
            line = line.strip()
            if not line.startswith("- "):
                return raw
            items.append(strip_quotes(line[2:].strip()))
        return items
    return strip_quotes(raw)

def parse_frontmatter(path):
    with open(path) as f:
        text = f.read()
    if not text.startswith("---\n"):
        return {}
    match = re.search(r"\n---\n", text[4:])
    if not match:
        return {}
    block = text[4:4 + match.start()]
    data = {}
    current_key = None
    current_lines = []
    for line in block.splitlines():
        if re.match(r"^[A-Za-z_][A-Za-z0-9_]*:\s*", line):
            if current_key is not None:
                data[current_key] = parse_value("\n".join(current_lines))
            key, rest = line.split(":", 1)
            current_key = key.strip()
            current_lines = [rest.strip()] if rest.strip() else []
        elif current_key is not None:
            current_lines.append(line)
    if current_key is not None:
        data[current_key] = parse_value("\n".join(current_lines))
    return data

values = {}
for root, _, files in os.walk("wiki"):
    for name in files:
        if not name.endswith(".md"):
            continue
        path = os.path.join(root, name)
        base = os.path.basename(path)
        if base in ("index.md", "log.md") or path.startswith("wiki/meta/"):
            continue
        data = parse_frontmatter(path)
        entries = []
        title = data.get("title")
        if isinstance(title, str) and title.strip():
            entries.append(("title", title.strip().lower()))
        aliases = data.get("aliases", [])
        if isinstance(aliases, list):
            for alias in aliases:
                if isinstance(alias, str) and alias.strip():
                    entries.append(("alias", alias.strip().lower()))
        for kind, value in entries:
            values.setdefault(value, []).append((path, kind))

collisions = []
for value, entries in sorted(values.items()):
    pages = sorted({path for path, _ in entries})
    if len(pages) >= 2:
        details = ", ".join(f"{os.path.basename(path)} ({kind})" for path, kind in entries)
        collisions.append(f"'{value}': {details}")

if not collisions:
    print("PASS: no alias/title collisions")
else:
    for collision in collisions:
        print(f"PROBLEM: {collision}")
    print(f"WARN: {len(collisions)} alias/title collision(s)")
PYEOF
)

if echo "$collision_result" | head -1 | grep -q "^PASS"; then
    pass "$(echo "$collision_result" | head -1 | sed 's/^PASS: //')"
else
    while IFS= read -r line; do
        if [[ "$line" == WARN:* ]]; then
            warn "${line#WARN: }"
        elif [[ "$line" == PROBLEM:* ]]; then
            echo "      ${line#PROBLEM: }"
        fi
    done <<<"$collision_result"
fi

# ----------------------------------------------------------------------
# Check 13: query/synthesis health
# ----------------------------------------------------------------------
section "Check 13: query/synthesis health"

query_result=$(python3 - <<'PYEOF'
import os
import re

with open("wiki/log.md") as f:
    log = f.read()

ingest_count = len(re.findall(r"^## \[\d{4}-\d{2}-\d{2}\] ingest \|", log, re.MULTILINE))
query_count = len(re.findall(r"^## \[\d{4}-\d{2}-\d{2}\] query \|", log, re.MULTILINE))
synthesis_files = sorted(
    name for name in os.listdir("wiki/synthesis")
    if name.endswith(".md") and name != ".gitkeep"
)

filed_refs = re.findall(r"^- Filed as: \[\[([^\]]+)\]\]", log, re.MULTILINE)
missing = []
for ref in filed_refs:
    expected = os.path.join("wiki", "synthesis", f"{ref}.md")
    if not os.path.exists(expected):
        missing.append(f"{ref} -> {expected}")

if missing:
    for item in missing:
        print(f"PROBLEM: {item}")
    print(f"FAIL: {len(missing)} filed query reference(s) point to missing synthesis pages")
elif not synthesis_files and ingest_count >= 10:
    print(f"WARN: synthesis directory empty after {ingest_count} ingests; query workflow may not be activating")
elif not synthesis_files:
    print(f"PASS: no synthesis pages yet ({ingest_count} ingests, {query_count} queries logged; threshold not reached)")
else:
    print(f"PASS: {len(synthesis_files)} synthesis page(s), {query_count} query log entries, all filed references resolve")
PYEOF
)

if echo "$query_result" | head -1 | grep -q "^PASS"; then
    pass "$(echo "$query_result" | head -1 | sed 's/^PASS: //')"
elif echo "$query_result" | head -1 | grep -q "^WARN"; then
    warn "$(echo "$query_result" | head -1 | sed 's/^WARN: //')"
else
    while IFS= read -r line; do
        if [[ "$line" == FAIL:* ]]; then
            fail "${line#FAIL: }"
        elif [[ "$line" == PROBLEM:* ]]; then
            echo "      ${line#PROBLEM: }"
        fi
    done <<<"$query_result"
fi

# ----------------------------------------------------------------------
# Check 14: skill catalog sync (CLAUDE.md §9 table <-> skills/ directory)
# ----------------------------------------------------------------------
section "Check 14: skill catalog sync"

catalog_result=$(python3 - <<'PYEOF'
import os
import re

with open("CLAUDE.md") as f:
    claude = f.read()

# Extract §9 Skill catalog section (from "## 9. Skill catalog" to the next "## " heading)
section_match = re.search(
    r"^## 9\. Skill catalog\s*$(.*?)^## ",
    claude,
    re.MULTILINE | re.DOTALL,
)
if not section_match:
    print("PROBLEM: CLAUDE.md §9 Skill catalog section not found")
    print("FAIL: catalog section missing")
    raise SystemExit

section_text = section_match.group(1)

# Catalog rows look like: | **<name>** | <trigger desc> | `skills/<name>/SKILL.md` |
catalog_entries = re.findall(
    r"\|\s*\*\*([a-z][a-z0-9_-]*)\*\*\s*\|[^|]*\|\s*`(skills/[a-z][a-z0-9_-]*/SKILL\.md)`\s*\|",
    section_text,
)

if not catalog_entries:
    print("PROBLEM: no catalog rows parsed from CLAUDE.md §9")
    print("FAIL: catalog empty or malformed")
    raise SystemExit

# Scan skills/ for actual SKILL.md files
skill_dirs = []
for name in sorted(os.listdir("skills")):
    full = os.path.join("skills", name)
    if not os.path.isdir(full):
        continue
    if os.path.isfile(os.path.join(full, "SKILL.md")):
        skill_dirs.append(name)

catalog_names = {name for name, _ in catalog_entries}

missing_files = [
    (name, path) for name, path in catalog_entries
    if not os.path.isfile(path)
]
missing_rows = [name for name in skill_dirs if name not in catalog_names]
mismatched_paths = [
    (name, path) for name, path in catalog_entries
    if path != f"skills/{name}/SKILL.md"
]

problems = bool(missing_files or missing_rows or mismatched_paths)

if missing_files:
    for name, path in missing_files:
        print(f"PROBLEM: catalog row '{name}' points to missing file {path}")
if missing_rows:
    for name in missing_rows:
        print(f"PROBLEM: skills/{name}/SKILL.md exists but has no row in CLAUDE.md §9")
if mismatched_paths:
    for name, path in mismatched_paths:
        print(f"PROBLEM: catalog row '{name}' declares path {path} (expected skills/{name}/SKILL.md)")

if problems:
    print(f"FAIL: skill catalog out of sync ({len(missing_files)} missing files, {len(missing_rows)} missing rows, {len(mismatched_paths)} mismatched paths)")
else:
    print(f"PASS: {len(catalog_entries)} skill(s) in CLAUDE.md §9 match skills/ directory 1:1")
PYEOF
)

if echo "$catalog_result" | tail -1 | grep -q "^PASS"; then
    pass "$(echo "$catalog_result" | tail -1 | sed 's/^PASS: //')"
else
    while IFS= read -r line; do
        if [[ "$line" == FAIL:* ]]; then
            fail "${line#FAIL: }"
        elif [[ "$line" == PROBLEM:* ]]; then
            echo "      ${line#PROBLEM: }"
        fi
    done <<<"$catalog_result"
fi

# ----------------------------------------------------------------------
# Check 15: skill frontmatter well-formed
# ----------------------------------------------------------------------
section "Check 15: skill frontmatter well-formed"

skill_fm_result=$(python3 - <<'PYEOF'
import os
import re

def strip_quotes(value):
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in ("'", '"'):
        return value[1:-1]
    return value

def parse_skill_frontmatter(path):
    """
    Minimal skill frontmatter parser. Returns a dict of top-level keys.
    Complex values (inline lists, nested objects) are captured as raw
    strings — we only check field presence and simple scalar fields.
    """
    with open(path) as f:
        text = f.read()
    if not text.startswith("---\n"):
        return None
    end = re.search(r"\n---\n", text[4:])
    if not end:
        return None
    block = text[4:4 + end.start()]
    data = {}
    current_key = None
    current_lines = []
    for line in block.splitlines():
        if re.match(r"^[A-Za-z_][A-Za-z0-9_]*:\s*", line):
            if current_key is not None:
                joined = "\n".join(current_lines).strip()
                if joined == "null":
                    data[current_key] = None
                elif joined == "":
                    data[current_key] = ""
                else:
                    data[current_key] = strip_quotes(joined) if "\n" not in joined else joined
            key, rest = line.split(":", 1)
            current_key = key.strip()
            current_lines = [rest.strip()] if rest.strip() else []
        elif current_key is not None:
            current_lines.append(line)
    if current_key is not None:
        joined = "\n".join(current_lines).strip()
        if joined == "null":
            data[current_key] = None
        elif joined == "":
            data[current_key] = ""
        else:
            data[current_key] = strip_quotes(joined) if "\n" not in joined else joined
    return data

REQUIRED = ["id", "name", "title", "version", "status", "log_op", "inputs", "related_skills", "created", "updated"]
VALID_STATUS = {"draft", "stable", "deprecated"}

problems = []
skill_count = 0

for entry in sorted(os.listdir("skills")):
    skill_path = os.path.join("skills", entry, "SKILL.md")
    if not os.path.isfile(skill_path):
        continue
    skill_count += 1

    data = parse_skill_frontmatter(skill_path)
    if data is None:
        problems.append(f"{skill_path}: missing or malformed YAML frontmatter")
        continue

    for field in REQUIRED:
        if field not in data:
            problems.append(f"{skill_path}: missing required field '{field}'")

    id_value = data.get("id")
    if isinstance(id_value, str) and id_value != entry:
        problems.append(f"{skill_path}: id '{id_value}' does not match directory name '{entry}'")

    name_value = data.get("name")
    if isinstance(name_value, str) and name_value != entry:
        problems.append(f"{skill_path}: name '{name_value}' does not match directory name '{entry}'")

    status = data.get("status")
    if isinstance(status, str) and status not in VALID_STATUS:
        problems.append(f"{skill_path}: status '{status}' must be one of {sorted(VALID_STATUS)}")

    version = data.get("version")
    if isinstance(version, str) and version != "":
        if not re.fullmatch(r"\d+", version):
            problems.append(f"{skill_path}: version '{version}' must be an integer")

    log_op = data.get("log_op")
    if log_op is not None and not isinstance(log_op, str):
        problems.append(f"{skill_path}: log_op must be a string or null")

if skill_count == 0:
    print("PROBLEM: no SKILL.md files found under skills/")
    print("FAIL: no skills to validate")
elif problems:
    for problem in problems:
        print(f"PROBLEM: {problem}")
    print(f"FAIL: {len(problems)} skill frontmatter problem(s) across {skill_count} skill file(s)")
else:
    print(f"PASS: {skill_count} skill file(s) have well-formed frontmatter")
PYEOF
)

if echo "$skill_fm_result" | tail -1 | grep -q "^PASS"; then
    pass "$(echo "$skill_fm_result" | tail -1 | sed 's/^PASS: //')"
else
    while IFS= read -r line; do
        if [[ "$line" == FAIL:* ]]; then
            fail "${line#FAIL: }"
        elif [[ "$line" == PROBLEM:* ]]; then
            echo "      ${line#PROBLEM: }"
        fi
    done <<<"$skill_fm_result"
fi

# ----------------------------------------------------------------------
# Check 16: log-op coverage (skills <-> CLAUDE.md §10 op tokens)
# ----------------------------------------------------------------------
section "Check 16: log-op coverage"

logop_result=$(python3 - <<'PYEOF'
import os
import re

def strip_quotes(value):
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in ("'", '"'):
        return value[1:-1]
    return value

def get_log_op(path):
    """Extract only the log_op field from a skill frontmatter. Returns string, None, or 'MISSING'."""
    with open(path) as f:
        text = f.read()
    if not text.startswith("---\n"):
        return "MISSING"
    end = re.search(r"\n---\n", text[4:])
    if not end:
        return "MISSING"
    block = text[4:4 + end.start()]
    match = re.search(r"^log_op:\s*(.*)$", block, re.MULTILINE)
    if not match:
        return "MISSING"
    raw = match.group(1).strip()
    if raw == "null" or raw == "":
        return None
    return strip_quotes(raw)

# Parse CLAUDE.md for the declared operations in the Log format section.
with open("CLAUDE.md") as f:
    claude = f.read()

ops_line = re.search(r"Operations:\s*((?:`\w+`(?:,\s*)?)+)", claude)
if not ops_line:
    print("PROBLEM: could not find Operations: line in CLAUDE.md")
    print("FAIL: log format section missing or malformed")
    raise SystemExit

declared_ops = set(re.findall(r"`(\w+)`", ops_line.group(1)))

# Bootstrap-only ops don't need a skill
BOOTSTRAP_OPS = {"init"}

# Parse skill log_op values
skill_ops = {}
missing_log_op = []
for entry in sorted(os.listdir("skills")):
    skill_path = os.path.join("skills", entry, "SKILL.md")
    if not os.path.isfile(skill_path):
        continue
    op = get_log_op(skill_path)
    if op == "MISSING":
        missing_log_op.append(entry)
    else:
        skill_ops[entry] = op

non_null_skill_ops = {op for op in skill_ops.values() if op}

# Every skill's log_op must be in the declared ops (unless null for session-internal)
unknown_skill_ops = sorted(non_null_skill_ops - declared_ops)

# Every declared op (except bootstrap) must have a skill claiming it
uncovered_ops = sorted((declared_ops - non_null_skill_ops) - BOOTSTRAP_OPS)

# Check historical log entries for each skill (warn, not fail, if zero)
with open("wiki/log.md") as f:
    log = f.read()

skills_never_logged = []
for skill_name, op in sorted(skill_ops.items()):
    if not op:
        continue
    count = len(re.findall(rf"^## \[\d{{4}}-\d{{2}}-\d{{2}}\] {re.escape(op)} \|", log, re.MULTILINE))
    if count == 0:
        skills_never_logged.append(skill_name)

problems = bool(unknown_skill_ops or uncovered_ops or missing_log_op)

if missing_log_op:
    for name in missing_log_op:
        print(f"PROBLEM: skills/{name}/SKILL.md has no log_op field (use 'null' for session-internal skills)")
if unknown_skill_ops:
    for op in unknown_skill_ops:
        offenders = sorted(n for n, o in skill_ops.items() if o == op)
        print(f"PROBLEM: skill(s) {offenders} declare log_op '{op}' which is not in CLAUDE.md §10 Operations")
if uncovered_ops:
    for op in uncovered_ops:
        print(f"PROBLEM: CLAUDE.md §10 declares op '{op}' but no skill has log_op: {op}")

if problems:
    print(f"FAIL: log-op coverage mismatch ({len(unknown_skill_ops)} unknown, {len(uncovered_ops)} uncovered, {len(missing_log_op)} missing)")
else:
    summary_parts = [
        f"{len(declared_ops)} declared op(s)",
        f"{len(non_null_skill_ops)} covered by skills",
        f"{len(BOOTSTRAP_OPS)} bootstrap",
    ]
    if skills_never_logged:
        summary_parts.append(f"new (no log entries yet): {', '.join(skills_never_logged)}")
    print(f"PASS: {'; '.join(summary_parts)}")
PYEOF
)

if echo "$logop_result" | tail -1 | grep -q "^PASS"; then
    pass "$(echo "$logop_result" | tail -1 | sed 's/^PASS: //')"
else
    while IFS= read -r line; do
        if [[ "$line" == FAIL:* ]]; then
            fail "${line#FAIL: }"
        elif [[ "$line" == PROBLEM:* ]]; then
            echo "      ${line#PROBLEM: }"
        fi
    done <<<"$logop_result"
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
