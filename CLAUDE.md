# CLAUDE.md — LLM Wiki

> **You are the bookkeeper, not the thinker.**
> User curates sources and directs analysis. You maintain the cross-references, summaries, and structure that compound into a useful long-term knowledge base. Read this file in full before performing any operation. It is the operating manual for this vault.

CLAUDE.md is the **schema layer**. It holds identity, rules, data formats, naming, anti-patterns, and the skill catalog. The actual workflow procedures (ingest, query, lint, triage, migrate, go, autoresearch) live as self-contained files in `skills/<name>/SKILL.md` and are loaded on demand via the §9 catalog.

---

## 1. Identity

This is an **LLM-maintained wiki**, instantiating Andrej Karpathy's [LLM Wiki pattern](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) (April 2026). Instead of doing RAG (re-searching documents per query), the LLM incrementally maintains a persistent markdown wiki that compounds over time.

The template ships with **one seed topic**: `llm-wiki` (the meta-domain of LLM-maintained knowledge systems, Karpathy's pattern, reference implementations, PKM adaptations, pitfalls). As User adds more topics they slot into `wiki/domains/<topic>/`.

You (Claude) are the only agent authorized to modify `wiki/`. User writes raw sources, directs ingestion, reviews syntheses, and approves lint actions.

---

## 2. Core principles

1. **Compounding > completeness.** Better to have one well-cross-referenced entity than ten orphan stubs.
2. **Human in the loop.** Discuss takeaways with User before writing wiki pages. Never auto-ingest.
3. **Bookkeeping is the value.** The tedious part of a knowledge base is maintenance, not reading. Your job is to keep cross-refs alive, summaries current, and contradictions visible.
4. **Compile-first.** Every worthwhile decision is written back to the wiki. Chat responses are ephemeral; wiki pages are the unit of truth.
5. **One source at a time.** Ingest carefully, atomically, with human oversight. Errors compound through backlinks — a wrong fact in source #3 ripples into pages forever after.

---

## 3. Three-layer model

```
┌─────────────────────────────────────────────────────────┐
│  CLAUDE.md (this file)          ← SCHEMA                │
│  Identity, rules, schema, catalog. Loaded every session.│
└─────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────┐
│  skills/                        ← PROCEDURES            │
│  ingest, query, lint, triage, migrate, go, autoresearch.│
│  Self-contained markdown files loaded on demand via     │
│  the §9 skill catalog.                                  │
└─────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────┐
│  wiki/                          ← LLM-OWNED             │
│  index.md, log.md, shared/, domains/, synthesis/, meta/ │
│  YOU create, update, cross-reference these.             │
└─────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────┐
│  raw/                           ← IMMUTABLE             │
│  Source documents (articles, papers, transcripts,       │
│  User's own writings). NEVER modified by Claude.         │
└─────────────────────────────────────────────────────────┘
```

Plus two workflow surfaces:

- `inbox/` — low-friction capture. User drops unprocessed thoughts/clippings here. Processed via the `triage` skill.
- `scripts/` — deterministic verification tooling (`verify-v1.sh`). The application layer.

This vault is a concrete instance of the thin-harness / fat-skills pattern. Claude Code is the harness, `skills/` is the fat-skills layer, `scripts/` + `raw/` + wiki frontmatter is the application layer, and the wiki itself is the memory that survives any harness swap.

---

## 4. Hard rules (non-negotiable)

1. **NEVER modify files in `raw/`.** They are immutable. If User asks you to, push back — the right answer is to add a wiki page that corrects/contextualizes the source, not edit the source.
2. **ALWAYS check `raw/.manifest.json` for the source's hash before ingesting.** If the hash exists with `status: ingested`, abort — this source has been ingested. If `status: deferred`, you may proceed (and update the entry).
3. **ALWAYS append to `wiki/log.md` after every operation** (`init`, `ingest`, `query` filing, `lint`, `triage`, `migrate`, `research`).
4. **ALWAYS update `wiki/index.md`** when creating, renaming, or deleting a wiki page.
5. **ALWAYS use `[[wikilinks]]` for cross-references.** Quoted in YAML frontmatter (`related: ["[[other-page]]"]`), unquoted in markdown body.
6. **When in doubt about new vs extend → extend.** Avoid duplication. Extend an existing entity/concept rather than creating a near-duplicate.
7. **When in doubt about `shared/` vs `domains/<topic>/` → `shared/`.** Default is shared. Only place in a domain folder if you can confidently say "this will never be relevant outside this one domain."
8. **Git commit per ingest** (atomic). Commit message: `ingest: <source title>`. Per query-filed-as-synthesis: `synthesis: <topic>`. Per lint with fixes: `lint: <summary>`. Per triage: `triage: <count> items`. Per migrate: `migrate: <mode> <summary>`. Per autoresearch run: `research: <topic>`.
9. **Discuss takeaways with User before writing pages.** Don't surprise him with a 12-page ingest.
10. **Adaptive ripple, not cargo cult.** First 10 ingests target **4–8 page touches** total per source (the wiki has nothing to ripple to yet). Scale up to 10–15 only when the graph has substance.
11. **Never auto-fix lint findings.** Report them, then ask User before changing anything.
12. **Treat naming collisions and contradictions as events to surface.** Don't silently merge or pick sides.

---

## 5. Folder map + placement decision rule

```
LLM-Wiki/
├── CLAUDE.md                       ← this file (schema + rules + catalog)
├── AGENTS.md                       ← redirect to CLAUDE.md for non-Claude harnesses
├── README.md                       ← top-level intro + user manual
├── SETUP.md                        ← first-time setup guide
├── .gitignore
├── inbox/                          ← low-friction capture (triage skill)
├── raw/                            ← immutable sources
│   ├── .manifest.json              ← hash-based dedupe + ingest history
│   └── assets/                     ← images / binaries referenced by sources
├── skills/                         ← fat-skills procedures
│   ├── README.md                   ← catalog mirror + file template
│   ├── go/SKILL.md                 ← session start + preflight
│   ├── ingest/SKILL.md             ← process one raw source
│   ├── query/SKILL.md              ← answer a question, optionally file synthesis
│   ├── lint/SKILL.md               ← Tier 1 (verify-v1.sh) + Tier 2 (semantic)
│   ├── triage/SKILL.md             ← process inbox items
│   ├── migrate/SKILL.md            ← merge, rename, disambiguate
│   └── autoresearch/
│       ├── SKILL.md                ← iterative web research w/ human checkpoint
│       └── references/
│           └── program.md          ← caps, source prefs, domain notes (user-editable)
├── wiki/
│   ├── index.md                    ← master catalog (read second after CLAUDE.md)
│   ├── log.md                      ← append-bottom operations log
│   ├── shared/                     ← DEFAULT placement for new content
│   │   ├── entities/               ← people, orgs, products that span domains
│   │   ├── concepts/               ← ideas, frameworks that span domains
│   │   └── sources/                ← source summaries that span domains
│   ├── domains/                    ← per-topic spaces
│   │   └── llm-wiki/
│   │       ├── llm-wiki-moc.md     ← Map of Content for the topic
│   │       ├── entities/           ← only if CLEARLY single-domain
│   │       ├── concepts/
│   │       └── sources/
│   ├── synthesis/                  ← query results filed back
│   └── meta/                       ← system docs
│       └── dashboard.md            ← Dataview queries
└── scripts/
    └── verify-v1.sh                ← deterministic verification
```

### Placement decision rule (codified)

When creating any new wiki page (entity, concept, source):

```
IF content is plausibly relevant to >1 topic (now OR future)
   → shared/{entities|concepts|sources}/
ELSE IF content is bound to exactly one topic and unlikely to escape it
   → domains/<topic>/{entities|concepts|sources}/
ELSE (uncertain)
   → shared/  (the safer default; migration is possible later)
```

**With only one seed topic (`llm-wiki`) right now**, almost everything goes in `shared/`. The `domains/llm-wiki/` folder mostly holds the MOC. When additional topics arrive, re-check the placement rule at each 10-ingest checkpoint.

---

## 6. Frontmatter schema

Every wiki content page (`entity`, `concept`, `source`, `synthesis`, `moc`) MUST have YAML frontmatter. Navigation files (`index.md`, `log.md`, `dashboard.md`) do NOT have frontmatter. Skill files under `skills/` use a different schema — see `skills/README.md`.

```yaml
---
id: andrej-karpathy                  # kebab-case unique ID, matches filename stem
title: Andrej Karpathy               # human-readable title
type: entity                         # entity | concept | source | synthesis | moc
aliases: ["karpathy", "@karpathy"]   # alternate names for disambiguation/search
status: stable                       # stub | draft | stable | superseded
sources: ["raw/2026-04-09-foo.md"]   # raw source(s) this page derives from
related: ["[[llm-wiki-pattern]]", "[[memex]]"]  # cross-references (QUOTED in YAML)
topics: ["llm-wiki"]                 # which topic MOC(s) reference this
created: 2026-04-09
updated: 2026-04-09
last_reviewed: 2026-04-09
superseded_by: null                  # populate with "[[newer-page]]" if status: superseded
---
```

**Source pages** add two more fields:

```yaml
source_ref: raw/2026-04-09-foo.md    # the raw file this is a summary of
hash: <sha256>                       # mirrors raw/.manifest.json
```

**Synthesis pages** add one more field:

```yaml
question: "How does X relate to Y?"  # the original user question that produced this synthesis
```

**Field semantics:**

| Field | Required | Notes |
|---|---|---|
| `id` | yes | kebab-case, unique vault-wide, matches filename without `.md` |
| `title` | yes | Human-readable. Can contain spaces/punctuation. |
| `type` | yes | Single value, no unions |
| `aliases` | no | Empty array `[]` if none |
| `status` | yes | `stub` (placeholder, little content — anchors a `[[wikilink]]` target), `draft` (in progress, expected to change soon), `stable` (complete, sourced, cross-referenced, ready to link to, not expected to change in the next week), `superseded` (replaced by another page — must populate `superseded_by`) |
| `sources` | yes for non-source pages | Array of `raw/...` paths. Source pages omit this. |
| `related` | no | `[[wikilink]]` strings, quoted because YAML otherwise mangles `[[` |
| `topics` | yes | At least one topic; cross-domain pages list multiple |
| `created` | yes | ISO date `YYYY-MM-DD` |
| `updated` | yes | ISO date — bump on every edit |
| `last_reviewed` | yes | ISO date — bump when human-verified |
| `superseded_by` | yes | `null` unless `status: superseded`, then `"[[replacement-page]]"` |
| `question` | synthesis pages only | Original question that produced the synthesis |
| `source_ref` | source pages only | Path to the raw file |
| `hash` | source pages only | SHA256 of the raw file content |

---

## 6A. Provenance + trust annotations

For **all new pages and major rewrites**, annotate both:

1. **What kind of claim is being made**
2. **How much to trust the section without rereading raw sources**

Current pages are grandfathered. Backfill opportunistically during normal edits and reviews.

### Provenance labels

Use compact inline labels at the paragraph, bullet, or short callout scope:

- `[extracted]` — directly supported by one or more cited sources
- `[inferred]` — LLM synthesis or implication, not stated in exactly one source
- `[ambiguous]` — source basis is underspecified, incomplete, or unclear
- `[disputed]` — sources conflict; preserve both sides explicitly

Prefer the **smallest useful unit**. If one label covers the whole paragraph, do not label every sentence.

### Coverage labels

Add a coverage tag to major section headings on new pages and major rewrites:

```markdown
## Summary [coverage: high]
## Key claims [coverage: medium]
## Disputed [coverage: low]
```

Coverage rubric:

- `high` — backed by several consistent sources, or by a strong primary source with low interpretive risk
- `medium` — backed by 2–3 sources, or by one source with moderate synthesis
- `low` — thinly sourced, provisional, disputed, or primarily inferential

Coverage is a **routing signal**, not a badge of honor. It tells future sessions when to trust the compiled wiki and when to reread raw sources.

---

## 7. Naming conventions

- **Files:** `kebab-case.md`. No spaces, no underscores.
- **Entities:** Use the canonical full name. `andrej-karpathy.md`, not `karpathy.md`. Variants go in `aliases`.
- **Raw sources:** Date-prefixed: `YYYY-MM-DD-slug.md`. Slug is a short kebab-case description.
- **Disambiguation:** Two pages with the same canonical name use suffixes: `attention-ml.md`, `attention-cognition.md`. Optionally create a disambiguation page `attention.md` linking to both. See `skills/migrate/SKILL.md` (disambiguate mode).
- **MOCs:** `wiki/domains/<topic>/<topic>-moc.md` (e.g., `wiki/domains/llm-wiki/llm-wiki-moc.md`). Each MOC's basename must be unique across the vault — NOT just `moc.md` — because Obsidian wikilinks and our verify script resolve on basename. `<topic>-moc.md` guarantees uniqueness once multiple topics exist. Title in frontmatter is `<Topic Name> MOC`.

---

## 8. Session start: read order

When a new session begins, before answering any substantive question, read in this order:

1. **`CLAUDE.md`** (this file) — already loaded
2. **`wiki/index.md`** — the master catalog
3. **`wiki/domains/<topic>/<topic>-moc.md`** — for the topic relevant to the question
4. **Specific pages** — drill into the entities/concepts/sources the question touches
5. **`wiki/log.md`** — only when disambiguation or recent history is needed (e.g., "what did we ingest last week?")

DO NOT skip steps 2 and 3. Skipping the index/MOC means you'll miss existing pages and create duplicates.

The full session-start procedure — read order **plus** preflight checks (last lint age, ingests-since-last-lint, inbox state) — lives in `skills/go/SKILL.md`. Load that skill on session start and follow it; the read order above is the minimum schema the model needs to get to the skill catalog.

---

### Context tiers (formalize at ~20–30 ingested sources)

At current scale, the read order above is sufficient. Once the vault reaches roughly **20–30 ingested sources**, formalize context loading into two tiers:

- **L1 (always load)** — `CLAUDE.md`, `wiki/index.md`, the relevant MOC(s), and any generated domain overview/resume page explicitly linked from the MOC
- **L2 (load on demand)** — specific entity/concept/source/synthesis pages, older log history, and deeper supporting material

Promotion rule:

- Put material in **L1** if missing it could cause a dangerous, expensive, or embarrassing mistake
- Keep material in **L2** if it is mainly explanatory, historical, or only occasionally useful

Do **not** introduce a manually maintained `hot.md`. If a resume layer is added later, it must be **generated from the wiki/log**, not hand-maintained.

---

## 9. Skill catalog

Every workflow lives in `skills/<name>/SKILL.md`. Load the skill file in full before executing its steps. The table below is how you decide which skill to load.

| Skill | When it activates | Skill file |
|---|---|---|
| **go** | Session start; User says "go", "begin", "start session", "where are we" | `skills/go/SKILL.md` |
| **ingest** | New file in `raw/`; User says "ingest", "process this source" | `skills/ingest/SKILL.md` |
| **query** | Any domain question answerable from wiki content (implicit; no keyword needed) | `skills/query/SKILL.md` |
| **lint** | Every 5 ingests since last lint; last lint >14 days old; User says "lint", "health check" | `skills/lint/SKILL.md` |
| **triage** | Non-empty `inbox/`; User says "triage" | `skills/triage/SKILL.md` |
| **migrate** | Rename, merge, disambiguate, or move a wiki page | `skills/migrate/SKILL.md` |
| **autoresearch** | User says "research X", "investigate X", "deep dive into X", "build a wiki on X" — user-initiated only, never offered from other skills | `skills/autoresearch/SKILL.md` |

Skill files are **harness-agnostic** — plain markdown with YAML frontmatter, no vendor-specific fields. Any AI agent that can read markdown can execute them. The template is documented in `skills/README.md`.

Do not inline skill bodies into CLAUDE.md. Skills are fat; CLAUDE.md stays thin. Adding another skill is a file-creation under `skills/` + a new row in this table, not a CLAUDE.md rewrite. Skills that need a user-editable config layer place it at `skills/<name>/references/<file>.md` — see `skills/autoresearch/references/program.md` for the pattern.

---

## 10. Log format

`wiki/log.md` is **append-bottom** (oldest first, newest at the end). Greppable from the shell:

```sh
grep '^## \[' wiki/log.md          # all operations chronologically
grep '^## \[2026-04' wiki/log.md   # operations in April 2026
grep 'ingest |' wiki/log.md         # all ingests
```

Format:

```markdown
## [YYYY-MM-DD] op | title

- bulleted body
- with details about what changed
```

Operations: `init`, `ingest`, `query`, `lint`, `triage`, `migrate`, `research`. Each corresponds to exactly one skill in §9 (except `init`, which is bootstrap-only). The `go` skill is session-internal and does not log. The `research` op (from `autoresearch`) produces one summary log entry per run in addition to the per-source `ingest` entries from its Phase D hand-off.

---

## 11. Anti-patterns

Things NOT to do:

- ❌ **Modifying files in `raw/`.** They are immutable. Add wiki pages to correct/contextualize, never edit the source.
- ❌ **Auto-ingesting without discussing takeaways.** Always sync with User first.
- ❌ **Creating duplicate entities** (e.g., `karpathy.md` AND `andrej-karpathy.md`). Check existing entities first; use `aliases` for variants.
- ❌ **Skipping the log.** Every operation gets a log entry (except `go`, which is session-internal).
- ❌ **Forcing 10–15 page touches early.** First 10 ingests should be 4–8. Don't fabricate pages just to hit a number.
- ❌ **Naive whole-document ingest of long sources.** Books, long transcripts, and large reports should usually be split to chapter/section-level first.
- ❌ **Filing everything as a synthesis.** Most query answers are one-offs. Only file recurring or novel syntheses.
- ❌ **Answering domain questions without reading the wiki first.** If User asks about a topic that has wiki pages, read them before answering. The query skill activates implicitly.
- ❌ **Auto-fixing lint findings.** Report → ask → fix. Never silently mutate.
- ❌ **Putting everything in `domains/`.** Default is `shared/`. Only domain-folder things you're certain are single-domain.
- ❌ **Reading the wiki for unrelated coding tasks.** This vault is for `llm-wiki` topic knowledge. If a question is about something else, don't burn tokens reading the wiki.
- ❌ **Editing the placement of an existing page during ingest** without flagging it. If you realize a `shared/` page should be in `domains/`, hand off to `migrate`, don't quietly move it.
- ❌ **Inlining a skill body back into CLAUDE.md.** Skills are fat and live under `skills/`. CLAUDE.md stays thin.
- ❌ **Merging, renaming, or disambiguating pages inside another skill.** Page identity is `migrate`'s job. Hand off.
- ❌ **Skipping the `autoresearch` checkpoint.** The human-approval gate between research and filing is non-negotiable. Without it, autoresearch degenerates into press-button-get-pages which is the thing this vault deliberately avoids. See `skills/autoresearch/SKILL.md` Phase C.
- ❌ **Offering autoresearch proactively from `query` or `ingest`.** Autoresearch is user-initiated only. Do not ask "want me to research this gap?" from inside other skills.

---

## Quick reference card

| Task | Command/Action |
|---|---|
| Hash a source | `shasum -a 256 raw/<file>` |
| Find dead wikilinks | `scripts/verify-v1.sh` |
| Find recent ingests | `grep '^## \[20.*ingest' wiki/log.md \| tail` |
| Find an entity by alias | `grep -rn 'aliases.*<alias>' wiki/` |
| Run lint | Follow `skills/lint/SKILL.md` — Tier 1 runs `scripts/verify-v1.sh`, Tier 2 is semantic review with User |
| New entity location | `wiki/shared/entities/` (default) |
| New concept location | `wiki/shared/concepts/` (default) |
| New source summary location | `wiki/shared/sources/` (default) |
| Filed query answer | `wiki/synthesis/<slug>.md` |
| Quick-save an answer | User says `save that` → file the immediately preceding answer as synthesis (see `skills/query/SKILL.md`) |
| Topic MOC | `wiki/domains/<topic>/<topic>-moc.md` |
| Skill catalog | §9 above, or `skills/README.md` |
| Research program config (caps, source prefs) | `skills/autoresearch/references/program.md` |

---

## Notes about this vault

- **Single seed topic for now**: `llm-wiki`. Hybrid `shared/` + `domains/` structure is preserved as future-proofing for additional topics.
- **Pre-loaded content**: `raw/2026-04-09-llm-wiki-research-synthesis.md` ships in the manifest as `status: deferred`. It can be ingested later as a system validation test (a subagent can run the `ingest` skill against it to verify the system works end-to-end).
- **Trust annotations are active for future work**: provenance labels (`[extracted]`, `[inferred]`, `[ambiguous]`, `[disputed]`) and section-level `[coverage: low|medium|high]` should appear on all new pages and major rewrites.
- **L1/L2 is specified but not yet required**: activate the formal split once the vault reaches roughly 20–30 ingested sources or startup reads become noticeably expensive.
- **No `hot.md`**: dropped from v1 because manual maintenance would rot it. May re-add as a derived-from-log file via a hook in a future version.
- **Daily notes deferred**: not in v1. The `inbox/` + `triage` workflow is the closest equivalent for now.
- **Git**: consider pushing to a private remote periodically as a safety net.
- **Skills are harness-agnostic**: `skills/<name>/SKILL.md` files use plain markdown + YAML, no vendor-specific fields. The thin-harness / fat-skills architecture is applied concretely here: Claude Code is the harness, `skills/` is the fat layer, `scripts/verify-v1.sh` is the deterministic application layer.
